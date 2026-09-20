// x86-64 — Fetch-Decode-Execute Loop
//
// Top-level entry point for the instruction cycle.
// Fetches and decodes one instruction from RIP, executes it,
// and advances RIP past the instruction bytes.

// Deliver the single-step trap at the end of an instruction (SDM Vol.3B
// §20.3.1.4).  DR6 reports BS; the processor clears B0-B3 on a debug
// exception and never clears the other bits (§20.2.3).  RIP has already
// been advanced, so the return address the delivery pushes is the next
// instruction, as for any trap; without an IDT the trap is reported like a
// fault, with that RIP.
val raise_single_step : unit -> unit
function raise_single_step() = {
  DR6 = (DR6 & 0xFFFFFFFFFFFFFFF0) | 0x0000000000004000;
  if system_mode then {
    try {
      deliver_exception(EXN_DB, 0x00000000, false)
    } catch {
      Fault(vec2, err2) => {
        fault_pending = true;
        fault_vector = vec2;
        fault_error_code = err2
      },
      VMExit(reason, qual) => complete_vm_exit(reason, qual),
    }
  } else {
    fault_pending = true;
    fault_vector = EXN_DB;
    fault_error_code = 0x00000000
  }
}

// Decode and execute one instruction.
// Sets fault_pending/fault_vector/fault_error_code on exception.
val step : unit -> unit
function step() = {
  fault_pending = false;
  event_delivered = false;

  // Check for pending SMI before anything else.
  // SDM §34.2: "The SMI takes precedence over [...] debug exceptions
  // and external interrupts." SMIs are non-maskable (not blocked by IF).
  if system_mode & ~(in_smm) & __check_pending_smi() then {
    deliver_smi();
    return ()
  };

  // Check for pending external interrupts before fetching.
  // Only deliver if IF=1 (interrupts enabled) and in system mode, and not
  // in the instruction following MOV SS/POP SS (SDM Vol.3A §7.8.3).
  if system_mode & IF_flag == 0b1 & ss_shadow == 0 then {
    let irq_vec = __check_pending_irq();
    if 0 <= irq_vec & irq_vec <= 255 then {
      let vec : exception_vector = irq_vec;
      // VMX: external interrupt exit (pin_based_controls bit 0)
      if in_vmx_non_root & vmcs.pin_based_controls[0] == 0b1 then {
        vmcs.exit_instr_length = 0x00000000;
        // NMI exit (pin_based_controls bit 3) — vector 2
        if vec == 2 & vmcs.pin_based_controls[3] == 0b1 then {
          complete_vm_exit(VMEXIT_EXCEPTION_NMI, 0x0000000000000202);
          return ()
        };
        complete_vm_exit(VMEXIT_EXTERNAL_INT, zero_extend(to_bits(32, vec)));
        return ()
      };
      try {
        deliver_exception(vec, 0x00000000, false);
        return ()
      } catch {
        Fault(vec2, err2) => {
          fault_pending = true;
          fault_vector = vec2;
          fault_error_code = err2;
          return ()
        },
        VMExit(reason, qual) => {
          complete_vm_exit(reason, qual);
          return ()
        },
      }
    }
  };

  // Set decode position to current RIP
  decode_pos = RIP;
  insn_start = RIP;
  rip_rel_pending = false;
  next_rip = None();

  // Save RSP and flags so we can restore them if the instruction faults.
  // x86 guarantees that a faulting instruction leaves architectural state
  // as if it never executed. RSP and flags are the registers most likely
  // to be modified before a memory op that can fault (e.g. PUSH modifies
  // RSP before the store; ALU-to-memory ops update flags before writeback).
  // Other registers (x87, segments) are handled by reordering the
  // individual instructions so that side effects follow memory ops.
  let saved_rsp = GPR[RSP];
  let saved_rflags = read_rflags();

  // TF is sampled before the instruction: the instruction that sets TF
  // (POPF, IRET) is not trapped, the one that clears it still is.
  let tf_at_start : bool = TF == 0b1;

  let faulted : bool =
    try {
      // Decode and execute one instruction
      decode_execute();
      false
    } catch {
      Fault(vec, err) => {
        GPR[RSP] = saved_rsp;
        write_rflags(saved_rflags);
        if system_mode then {
          // In system mode, deliver faults through the IDT.
          try {
            deliver_exception(vec, err, false);
            // RIP already set to handler by deliver_exception; skip normal advance
            return ()
          } catch {
            // deliver_exception itself faulted — double/triple fault
            Fault(vec2, err2) => {
              fault_pending = true;
              fault_vector = vec2;
              fault_error_code = err2;
              return ()
            },
            VMExit(_, _) => return (),
          }
        } else {
          fault_pending = true;
          fault_vector = vec;
          fault_error_code = err;
          true
        }
      },
      // VMX: VM exit from VMX non-root operation.
      // Save guest state, load host state, record exit info.
      VMExit(reason, qual) => {
        complete_vm_exit(reason, qual);
        return ()
      },
    };

  // Advance RIP unless we faulted or halted.
  // Control-flow instructions set next_rip to the branch target;
  // otherwise we fall through to the next instruction.
  if ~(faulted) & system_state == SysRunning then
    RIP = match next_rip { Some(t) => t, None() => decode_pos };

  // Single-step trap (SDM Vol.3B §20.3.1.4): after an instruction that ran
  // with TF set, unless the instruction delivered an event through the IDT
  // (INT n, INT3, INTO and INT1 clear TF as part of delivery), faulted, or
  // loaded SS (the trap following MOV SS/POP SS is suppressed, §7.8.3).
  if ~(faulted) & system_state == SysRunning & tf_at_start
     & ~(event_delivered) & ss_shadow != 2 then
    raise_single_step();

  // The SS-load shadow lasts through the following instruction.
  ss_shadow = match ss_shadow { 2 => 1, _ => 0 }
}

// Run instructions until a fault, halt, or step count reached.
val run : int -> unit
function run(max_steps) = {
  var remaining : int = max_steps;

  while remaining > 0 & ~(fault_pending) & system_state == SysRunning do {
    step();
    remaining = remaining - 1
  }
}

// Dummy main function required by the Sail C++ backend.
val main : unit -> unit
function main() = ()

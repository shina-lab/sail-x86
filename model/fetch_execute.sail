// x86-64 — Fetch-Decode-Execute Loop
//
// Top-level entry point for the instruction cycle.
// Fetches and decodes one instruction from RIP, executes it,
// and advances RIP past the instruction bytes.

// Decode and execute one instruction.
// Sets fault_pending/fault_vector/fault_error_code on exception.
val step : unit -> unit
function step() = {
  fault_pending = false;

  // Check for pending SMI before anything else.
  // SDM §34.2: "The SMI takes precedence over [...] debug exceptions
  // and external interrupts." SMIs are non-maskable (not blocked by IF).
  if system_mode & ~(in_smm) & __check_pending_smi() then {
    deliver_smi();
    return ()
  };

  // Check for pending external interrupts before fetching.
  // Only deliver if IF=1 (interrupts enabled) and in system mode.
  if system_mode & IF_flag == 0b1 then {
    let irq_vec = __check_pending_irq();
    if 0 <= irq_vec & irq_vec <= 255 then {
      let vec : exception_vector = irq_vec;
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
        VMExit(_, _) => return (),
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
      // Phase 2 will call complete_vm_exit(reason, qual) here.
      VMExit(reason, qual) => {
        GPR[RSP] = saved_rsp;
        write_rflags(saved_rflags);
        return ()
      },
    };

  // Advance RIP unless we faulted or halted.
  // Control-flow instructions set next_rip to the branch target;
  // otherwise we fall through to the next instruction.
  if ~(faulted) & system_state == SysRunning then
    RIP = match next_rip { Some(t) => t, None() => decode_pos }
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

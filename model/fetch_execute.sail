// x86-64 — Fetch-Decode-Execute Loop
//
// Top-level entry point for the instruction cycle.
// Fetches and decodes one instruction from RIP, executes it,
// and advances RIP past the instruction bytes.

// Raise #DB reporting the given DR6 status bits: the processor clears B0-B3
// and sets what it reports, never clearing the rest (SDM Vol.3B §20.2.3).
// With an IDT the exception is delivered with RIP as the return address:
// already advanced past the instruction for a trap (single step), still at
// the instruction for a fault (instruction breakpoint).  Without an IDT it
// is reported like any fault, with that RIP.
val raise_debug_exception : qword -> unit
function raise_debug_exception(status) = {
  DR6 = (DR6 & 0xFFFFFFFFFFFFFFF0) | status;
  if system_mode then {
    try {
      deliver_exception(EXN_DB, 0x00000000, EV_Exception)
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

// Instruction breakpoints matching a linear address (SDM Vol.3B §20.2.5):
// DRn enabled by Ln or Gn, R/Wn = 00 (execute) with LENn = 00 (any other
// length is undefined for instruction breakpoints), and DRn equal to the
// address of the instruction's first byte, prefixes included.
val insn_breakpoint_hits : qword -> bits(4)
function insn_breakpoint_hits(lin) = {
  var hits : bits(4) = 0x0;
  foreach (n from 0 to 3) {
    let enabled : bool = DR7[2 * n] == bitone | DR7[2 * n + 1] == bitone;
    let rw_len : bits(4) = DR7[(19 + 4 * n) .. (16 + 4 * n)];
    let dr : qword = match n { 0 => DR0, 1 => DR1, 2 => DR2, _ => DR3 };
    if enabled & rw_len == 0x0 & dr == lin then hits[n] = bitone
  };
  hits
}

// Decode and execute one instruction.
// Sets fault_pending/fault_vector/fault_error_code on exception.
val step : unit -> unit
function step() = {
  fault_pending = false;
  event_delivered = false;
  rep_trap_rf = false;
  // Data breakpoints hit by a MOV SS/POP SS are delivered after the
  // following instruction (SDM Vol.3B §20.3.1.2), so they survive one step.
  if ss_shadow != 1 then pending_dbp = 0x0;

  // Check for pending SMI before anything else.
  // SDM §34.2: "The SMI takes precedence over [...] debug exceptions
  // and external interrupts." SMIs are non-maskable (not blocked by IF).
  if system_mode & ~(in_smm) & __check_pending_smi() then {
    deliver_smi();
    return ()
  };

  // Check for pending external interrupts before fetching.
  // Only deliver if IF=1 (interrupts enabled) and in system mode, and not
  // in the instruction following STI or MOV SS/POP SS (SDM Vol.3A
  // §7.8.1 and §7.8.3).
  if system_mode & IF_flag == 0b1 & ss_shadow == 0 & sti_shadow == 0 then {
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
        deliver_exception(vec, 0x00000000, EV_ExternalInt);
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

  // Instruction breakpoint (SDM Vol.3B §20.3.1.1): the highest-priority
  // debug exception, a fault before the instruction.  The check is skipped
  // when RF is set (IRET restoring a handler's frame) and, on Intel, for
  // the instruction after MOV SS/POP SS (§7.8.3, "as if RF were 1"); AMD
  // Zen 4 takes that breakpoint (measured natively with a ptrace-armed DR0
  // on both hosts).  RF is then cleared, so it protects exactly one
  // instruction.
  if RF == 0b0 & ~(vendor == Vendor_Intel & ss_shadow == 1) then {
    let hits = insn_breakpoint_hits(RIP + get_seg_base(CS));
    if hits != 0x0 then {
      raise_debug_exception(zero_extend(hits));
      return ()
    }
  };
  RF = 0b0;

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
            deliver_exception(vec, err, EV_Exception);
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
          // RF as the pushed RFLAGS image would carry it (see
          // deliver_exception): 1 for a fault-class exception, but the
          // current value, cleared at the start of the instruction, for a
          // software interrupt whatever its vector (SDM Vol.3B §20.3.1.1).
          // INT n, INT3, INTO and INT1 set sw_return_rip before raising.
          match sw_return_rip {
            Some(_) => sw_return_rip = None(),
            None()  => if is_fault_class(vec) then RF = 0b1,
          };
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

  // Debug traps after the instruction, reported together in DR6:
  //   BS — single step (SDM Vol.3B §20.3.1.4): TF was set at the start,
  //        unless the instruction delivered an event through the IDT
  //        (INT n, INT3, INTO and INT1 clear TF as part of delivery);
  //   Bn — data breakpoints hit by the instruction's accesses (§20.3.1.2),
  //        which INT n does not discard;
  //   and on Intel the Bn of an instruction breakpoint matching the
  //   instruction a single-step trap is taken before ("when BS is set, any
  //   of the other debug status bits also may be set", §20.2.3; observed on
  //   Emerald Rapids, not on Zen 4).
  // A fault loses them (the early return above), and after MOV SS/POP SS
  // the single-step trap is suppressed and the data breakpoints wait for
  // the following instruction (§7.8.3, §20.3.1.2).
  if ~(faulted) & system_state == SysRunning & ss_shadow != 2 then {
    let bs : qword = if tf_at_start & ~(event_delivered) then 0x0000000000004000 else zeros();
    let code_hits : bits(4) =
      if vendor == Vendor_Intel & bs != zeros() then insn_breakpoint_hits(RIP + get_seg_base(CS)) else 0x0;
    let status : qword = bs | zero_extend(pending_dbp) | zero_extend(code_hits);
    if status != zeros() then {
      // A trap after a non-final iteration of a repeated string instruction
      // pushes RF = 1 (§20.3.1.1) on Intel; AMD Zen 4 pushes RF = 0 there
      // (observed with the pushed image compared under KVM, where SVM
      // delivers the #DB natively).
      if rep_trap_rf & vendor == Vendor_Intel then RF = 0b1;
      raise_debug_exception(status)
    }
  };

  // The SS-load shadow lasts through the following instruction.
  ss_shadow = match ss_shadow { 2 => 1, _ => 0 };
  sti_shadow = match sti_shadow { 2 => 1, _ => 0 }
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

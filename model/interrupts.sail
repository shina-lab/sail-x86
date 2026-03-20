// x86-64 — Exception and Interrupt Delivery
//
// In system mode, faults are delivered through the IDT:
//   1. Read 16-byte gate descriptor from IDTR_base + vector * 16
//   2. Read RSP0 from TSS if privilege change (ring 3 → ring 0)
//   3. Push interrupt frame: SS, RSP, RFLAGS, CS, RIP [, error code]
//   4. Set RIP to gate handler, CS to gate selector, CPL to 0
//   5. If interrupt gate (not trap gate), clear IF
//
// Double-fault escalation follows SDM Vol.3 Table 7-5:
//   - Contributory during contributory → #DF
//   - Contributory or #PF during #PF → #DF
//   - Contributory or #PF during #DF → Triple fault (shutdown)
//   - All other combinations → handle serially
//
// This mirrors sail-riscv's trap_handler() but is more complex because
// x86 pushes a stack frame through memory (which can itself fault).

// IDT gate descriptor (parsed from 16-byte raw descriptor)
struct IDTGate = {
  gate_offset  : qword,       // handler RIP (assembled from 3 fields)
  gate_sel     : word,         // target CS selector
  gate_ist     : range(0, 7),  // IST index (0 = legacy stack switching)
  gate_type    : bits(4),      // 0xE = interrupt gate, 0xF = trap gate
  gate_dpl     : range(0, 3),  // gate DPL
  gate_present : bool,
}

// Classify an exception vector for double-fault escalation.
// SDM Vol.3 Table 7-4.
val classify_exception : exception_vector -> ExceptionClass
function classify_exception(vec) =
  if vec == 0 | vec == 10 | vec == 11 | vec == 12 | vec == 13 then
    EC_Contributory
  else if vec == 14 then
    EC_PageFault
  else
    EC_Benign

// Read and parse a 16-byte IDT gate descriptor.
val read_idt_gate : exception_vector -> IDTGate
function read_idt_gate(vec) = {
  let vec_offset : qword = to_bits(64, vec * 16);
  let base : qword = IDTR_base + vec_offset;
  // IDT reads go through virtual address translation because the kernel
  // stores IDTR_base as a virtual address.
  let lo : qword = mem_read64(base);
  let hi : qword = mem_read64(base + 8);

  // Offset = hi[31:0] @ lo[63:48] @ lo[15:0]
  let offset_lo  : word  = lo[15..0];
  let offset_mid : word  = lo[63..48];
  let offset_hi  : dword = hi[31..0];
  let offset : qword = zero_extend(offset_hi) @ offset_mid @ offset_lo;

  // Selector = lo[31:16]
  let sel : word = lo[31..16];

  // IST = lo[34:32]
  let ist : range(0, 7) = unsigned(lo[34..32]);

  // Type = lo[43:40]
  let gtype : bits(4) = lo[43..40];

  // DPL = lo[46:45]
  let dpl : range(0, 3) = unsigned(lo[46..45]);

  // Present = lo[47]
  let present : bool = lo[47] == bitone;

  struct {
    gate_offset = offset,
    gate_sel = sel,
    gate_ist = ist,
    gate_type = gtype,
    gate_dpl = dpl,
    gate_present = present,
  }
}

// Read RSP0 from the TSS (for privilege-level changes).
val read_tss_rsp0 : unit -> qword
function read_tss_rsp0() = {
  // RSP0 is at offset 4 in the 64-bit TSS.
  // TR_base is a linear (virtual) address set by LTR.
  mem_read64(TR_base + 4)
}

// Read IST entry from the TSS.
val read_tss_ist : range(0, 7) -> qword
function read_tss_ist(ist_idx) = {
  // IST1 is at offset 36 (0x24) in the 64-bit TSS, each entry is 8 bytes.
  // TR_base is a linear (virtual) address.
  let offset : qword = to_bits(64, 36 + (ist_idx - 1) * 8);
  mem_read64(TR_base + offset)
}

// Check if an exception vector has an error code.
val has_error_code : exception_vector -> bool
function has_error_code(vec) =
  vec == EXN_DF | vec == EXN_TS | vec == EXN_NP |
  vec == EXN_SS | vec == EXN_GP | vec == EXN_PF | vec == EXN_AC

// Push a 64-bit value onto a stack at the given address.
// Returns the new stack pointer.
val push_to_stack : (qword, qword) -> qword
function push_to_stack(rsp, value) = {
  let new_rsp = rsp - 8;
  mem_write64(new_rsp, value);
  new_rsp
}

// Optional return address override for software interrupts (INT n, INT3).
// When Some(addr), deliver_exception_inner pushes addr instead of RIP.
// Reset to None() after each use.
register sw_return_rip : option(qword) = None()

// Inner delivery: read IDT gate, push interrupt frame, update CPU state.
// May throw Fault if gate is not present or stack push faults.
// software_int: true for INT n, INT3, INT1 — suppresses error code push
//               and enables gate DPL check (for INT n and INT3, not INT1).
val deliver_exception_inner : (exception_vector, dword, bool) -> unit
function deliver_exception_inner(vec, err_code, software_int) = {
  // Save old state before doing anything.
  let old_rip : qword = match sw_return_rip {
    Some(addr) => addr,
    None() => RIP,
  };
  sw_return_rip = None();
  let old_cs  : word  = read_segreg(CS);
  let old_rflags : qword = read_rflags();
  let old_rsp : qword = read_gpr64(RSP);
  let old_ss  : word  = read_segreg(SS);
  let old_cpl : cpl_t = cur_cpl;

  // Switch to supervisor mode immediately. All exception delivery memory
  // accesses (IDT gate read, TSS read, stack push) are implicit supervisor-
  // level accesses, even when the faulting instruction ran at CPL 3.
  // SDM Vol.3 §7.12.1: "the processor performs the following actions [in
  // order]: ... reads the interrupt gate, reads the TSS, pushes the frame."
  // All these accesses bypass U/S checks.
  cur_cpl = 0;

  let gate = read_idt_gate(vec);

  // 1. Check gate present — #GP if not
  if not_bool(gate.gate_present) then {
    throw Fault(EXN_GP, to_bits(32, vec * 8 + 2))
  };

  // 1b. Software interrupt DPL check: gate DPL must be >= CPL.
  // SDM Vol.3 §6.12.1.3: "If the DPL of the interrupt gate is less than
  // the CPL, a #GP(error_code) is generated."  This prevents ring-3 code
  // from invoking ring-0 interrupt handlers via INT n/INT3.
  // (INT1 bypasses this check — SDM says INT1 does not check DPL.)
  if software_int & gate.gate_dpl < old_cpl then {
    throw Fault(EXN_GP, to_bits(32, vec * 8 + 2))
  };

  // 2. Determine new stack
  let privilege_change : bool = old_cpl != 0;
  var new_rsp : qword = if gate.gate_ist != 0 then
    read_tss_ist(gate.gate_ist)
  else if privilege_change then
    read_tss_rsp0()
  else
    old_rsp;

  // Align stack to 16 bytes (architecturally required in IA-32e mode,
  // SDM Vol.3 §7.14.2).
  new_rsp = new_rsp & 0xFFFFFFFFFFFFFFF0;

  // 4. Push interrupt frame: SS, RSP, RFLAGS, CS, RIP
  new_rsp = push_to_stack(new_rsp, zero_extend(old_ss));
  new_rsp = push_to_stack(new_rsp, old_rsp);
  new_rsp = push_to_stack(new_rsp, old_rflags);
  new_rsp = push_to_stack(new_rsp, zero_extend(old_cs));
  new_rsp = push_to_stack(new_rsp, old_rip);

  // 5. Push error code if applicable.
  // SDM Vol.3 §6.13: "An error code is NOT pushed for exceptions that are
  // generated by software interrupts (INT n, INT3, or INT1)."
  if not_bool(software_int) & has_error_code(vec) then {
    new_rsp = push_to_stack(new_rsp, zero_extend(err_code))
  };

  // 6. Update RSP
  write_gpr64(RSP, new_rsp);

  // 7. Set SS to NULL selector with RPL = new CPL on privilege change
  //    or IST switch (SDM Vol.3 §7.14.4).
  if privilege_change | gate.gate_ist != 0 then {
    write_segreg(SS, 0x0000)
  };

  // 8. Load new CS (simplified: just set the selector, don't load full descriptor)
  write_segreg(CS, gate.gate_sel);

  // In IA-32e mode, all IDT gates reference 64-bit code segments.
  // Exception delivery always switches to 64-bit mode (SDM Vol.3 §12.17).
  cur_mode = LongMode;
  SegCache[CS].seg_l = bitone;
  SegCache[CS].seg_db = bitzero;

  // 9. Set new RIP to handler address
  RIP = gate.gate_offset;

  // 10. If interrupt gate (type 0xE), clear IF
  if gate.gate_type == 0xE then {
    IF_flag = bitzero
  };

  // 11. Clear TF, NT, RF (SDM Vol.3 §7.12.1.3: "the processor also
  //     clears the VM, RF, and NT flags after saving RFLAGS on the stack")
  TF = bitzero;
  NT = bitzero;
  RF = bitzero;
}

// Deliver an exception/interrupt through the IDT.
//
// Handles double-fault escalation per SDM Vol.3 Table 7-5:
//   exception_depth 0: normal delivery
//   exception_depth 1: delivering an exception (class tracked in delivering_exc_class)
//   exception_depth 2: delivering #DF
//
// If delivery itself faults, the fault is caught and re-entered through
// this function, which applies the escalation rules before retrying.
// Triple fault throws Fault(EXN_MC, 0) as an unrecoverable signal.
val deliver_exception : (exception_vector, dword, bool) -> unit
function deliver_exception(vec, err_code, software_int) = {
  let second_class = classify_exception(vec);

  // === Double-fault escalation (SDM Vol.3 Table 7-5) ===
  if exception_depth >= 2 then {
    // Currently delivering #DF
    match second_class {
      EC_Benign => (),  // Handle serially: deliver benign exception normally
      _ => {
        // Contributory or page fault during #DF → shutdown (triple fault)
        exception_depth = 0;
        throw Fault(EXN_MC, 0x00000000)
      },
    }
  } else if exception_depth == 1 then {
    // Currently delivering another exception — check escalation
    let escalate : bool = match delivering_exc_class {
      EC_Contributory => second_class == EC_Contributory,
      EC_PageFault    => second_class == EC_Contributory | second_class == EC_PageFault,
      EC_Benign       => false,
    };
    if escalate then {
      // Escalate to #DF
      exception_depth = 2;
      deliver_exception(EXN_DF, 0x00000000, false);
      return ()
    };
    // Handle serially: update class for further nesting checks
    delivering_exc_class = second_class;
  };

  // Set nesting state for the duration of this delivery
  if exception_depth == 0 then {
    exception_depth = 1;
    delivering_exc_class = second_class;
  };

  // Attempt delivery — catch faults and re-enter with escalation
  try {
    deliver_exception_inner(vec, err_code, software_int)
  } catch {
    Fault(vec2, err2) => {
      // Fault during delivery — re-enter with escalation logic (never software_int)
      deliver_exception(vec2, err2, false);
      return ()
    }
  };

  // Successful delivery — reset nesting
  exception_depth = 0;
}

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
  let lo : qword = mem_read(base);
  let hi : qword = mem_read(base + 8);

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
  let present : bool = lo[47] == 0b1;

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
  mem_read(TR_base + 4)
}

// Read IST entry from the TSS.
val read_tss_ist : range(0, 7) -> qword
function read_tss_ist(ist_idx) = {
  // IST1 is at offset 36 (0x24) in the 64-bit TSS, each entry is 8 bytes.
  // TR_base is a linear (virtual) address.
  let offset : qword = to_bits(64, 36 + (ist_idx - 1) * 8);
  mem_read(TR_base + offset)
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
  mem_write(new_rsp, value);
  new_rsp
}

// Optional return address override for software interrupts (INT n, INT3).
// When Some(addr), deliver_exception_inner pushes addr instead of RIP.
// Reset to None() after each use.
register sw_return_rip : option(qword) = None()

// Push a 32-bit value onto a stack at the given address.
// Returns the new stack pointer.
val push_to_stack_32 : (qword, dword) -> qword
function push_to_stack_32(esp, value) = {
  let new_esp = esp - 4;
  mem_write(new_esp, value);
  new_esp
}

// Push a 16-bit value onto the stack given as a linear address.
// Wraps the offset within 16 bits (SS.B=0) or 32 bits (SS.B=1)
// before adding SS.base, to avoid writing below the segment base
// when SP is near zero. Returns the new linear stack pointer.
val push_to_stack_16 : (qword, word) -> qword
function push_to_stack_16(sp, value) = {
  let base = get_seg_base(SS);
  let offset = sp - base;
  let new_offset : qword = if SegCache[SS].seg_db == 0b1
    then (offset - 2) & 0x00000000FFFFFFFF
    else (offset - 2) & 0x000000000000FFFF;
  let new_sp = base + new_offset;
  mem_write(new_sp, value);
  new_sp
}

// Read and parse an 8-byte IDT gate descriptor (protected mode).
// SDM Vol.3A §6.11: offset[31:16] @ offset[15:0], selector, type/DPL/P.
val read_idt_gate_32 : exception_vector -> IDTGate
function read_idt_gate_32(vec) = {
  let vec_offset : qword = to_bits(64, vec * 8);
  let base : qword = IDTR_base + vec_offset;
  let lo : dword = mem_read(base);
  let hi : dword = mem_read(base + 4);

  // Offset = hi[31:16] @ lo[15:0]
  let offset : dword = hi[31..16] @ lo[15..0];
  let sel : word = lo[31..16];
  let gtype : bits(4) = hi[11..8];
  let dpl : range(0, 3) = unsigned(hi[14..13]);
  let present : bool = hi[15] == 0b1;

  struct {
    gate_offset = zero_extend(offset),
    gate_sel = sel,
    gate_ist = 0,  // No IST in protected mode
    gate_type = gtype,
    gate_dpl = dpl,
    gate_present = present,
  }
}

// Read ESP0 and SS0 from the 32-bit TSS (for privilege-level changes).
// ESP0 is at offset 4, SS0 is at offset 8 (low 16 bits).
val read_tss_esp0_32 : unit -> (dword, word)
function read_tss_esp0_32() = {
  let esp0 : dword = mem_read(TR_base + 4);
  let ss0  : word  = mem_read(TR_base + 8);
  (esp0, ss0)
}

// Protected mode interrupt delivery (SDM Vol.3A §6.12).
// Reads 8-byte IDT gate, pushes 32-bit or 16-bit interrupt frame.
val deliver_exception_inner_32 : (exception_vector, dword, bool) -> unit
function deliver_exception_inner_32(vec, err_code, software_int) = {
  let old_eip : dword = match sw_return_rip {
    Some(addr) => addr[31..0],
    None() => RIP[31..0],
  };
  sw_return_rip = None();
  let old_cs     : word  = read_segreg(CS);
  let old_eflags : dword = read_rflags()[31..0];
  let old_esp    : dword = reg(RSP);
  let old_ss     : word  = read_segreg(SS);
  let old_cpl    : cpl_t = cur_cpl;

  cur_cpl = 0;

  let gate = read_idt_gate_32(vec);

  if ~(gate.gate_present) then {
    throw Fault(EXN_GP, to_bits(32, vec * 8 + 2))
  };

  if software_int & gate.gate_dpl < old_cpl then {
    throw Fault(EXN_GP, to_bits(32, vec * 8 + 2))
  };

  // Determine gate size: D bit (bit 3 of type field encodes 32 vs 16)
  // 0x0E/0x0F = 32-bit, 0x06/0x07 = 16-bit
  let is_32bit : bool = gate.gate_type[3] == 0b1;

  // Determine new stack
  let privilege_change : bool = old_cpl != 0;
  var new_esp : qword = zero_extend(old_esp);
  var new_ss : word = old_ss;
  if privilege_change then {
    let (esp0, ss0) = read_tss_esp0_32();
    new_esp = zero_extend(esp0);
    new_ss = ss0
  };

  if is_32bit then {
    // 32-bit gate: push 32-bit values
    if privilege_change then {
      new_esp = push_to_stack_32(new_esp, zero_extend(old_ss));
      new_esp = push_to_stack_32(new_esp, old_esp)
    };
    new_esp = push_to_stack_32(new_esp, old_eflags);
    new_esp = push_to_stack_32(new_esp, zero_extend(old_cs));
    new_esp = push_to_stack_32(new_esp, old_eip);
    if ~(software_int) & has_error_code(vec) then {
      new_esp = push_to_stack_32(new_esp, err_code)
    }
  } else {
    // 16-bit gate: push 16-bit values
    if privilege_change then {
      new_esp = push_to_stack_16(new_esp, old_ss);
      new_esp = push_to_stack_16(new_esp, old_esp[15..0])
    };
    new_esp = push_to_stack_16(new_esp, old_eflags[15..0]);
    new_esp = push_to_stack_16(new_esp, old_cs);
    new_esp = push_to_stack_16(new_esp, old_eip[15..0]);
    if ~(software_int) & has_error_code(vec) then {
      new_esp = push_to_stack_16(new_esp, err_code[15..0])
    }
  };

  // Update stack pointer and SS
  reg(RSP) = new_esp[31..0];
  if privilege_change then write_segreg(SS, new_ss);

  // Load CS with full descriptor cache update (sets CS.D/CS.L for handler)
  load_segment_register(CS, gate.gate_sel);
  RIP = gate.gate_offset;

  // If interrupt gate, clear IF
  if gate.gate_type == 0xE | gate.gate_type == 0x6 then {
    IF_flag = 0b0
  };

  TF = 0b0;
  NT = 0b0;
  RF = 0b0;
}

// Real mode interrupt delivery via IVT (SDM Vol.3A §7.9).
// IVT is at physical address 0, 256 × 4-byte entries (IP:CS, little-endian).
// Pushes FLAGS, CS, IP (16-bit each). Clears IF and TF.
// No error codes, no privilege checks.
val deliver_exception_real : (exception_vector) -> unit
function deliver_exception_real(vec) = {
  let old_ip  : word = match sw_return_rip {
    Some(addr) => addr[15..0],
    None() => RIP[15..0],
  };
  sw_return_rip = None();
  let old_cs    : word = read_segreg(CS);
  let old_flags : word = read_rflags()[15..0];

  // Read IVT entry: 2 bytes IP at vec*4, 2 bytes CS at vec*4+2
  let ivt_addr : qword = to_bits(64, vec * 4);
  let new_ip : word = phys_read(ivt_addr);
  let new_cs : word = phys_read(ivt_addr + 2);

  // Push FLAGS, CS, IP (16-bit each) onto SS:SP stack
  var sp : qword = read_stack_ptr();
  sp = push_to_stack_16(sp, old_flags);
  sp = push_to_stack_16(sp, old_cs);
  sp = push_to_stack_16(sp, old_ip);
  write_stack_ptr(sp - get_seg_base(SS));

  // Load new CS:IP
  load_segment_register(CS, new_cs);
  RIP = zero_extend(new_ip);

  // Clear IF and TF
  IF_flag = 0b0;
  TF = 0b0;
}

// Top-level inner delivery: dispatches by mode.
// May throw Fault if gate is not present or stack push faults.
// software_int: true for INT n, INT3, INT1 — suppresses error code push
//               and enables gate DPL check (for INT n and INT3, not INT1).
val deliver_exception_inner : (exception_vector, dword, bool) -> unit
function deliver_exception_inner(vec, err_code, software_int) = {
  // Dispatch by mode
  if cur_mode == RealMode then {
    deliver_exception_real(vec);
    return ()
  };
  if EFER[10] != 0b1 then {
    deliver_exception_inner_32(vec, err_code, software_int);
    return ()
  };

  // IA-32e mode below
  // Save old state before doing anything.
  let old_rip : qword = match sw_return_rip {
    Some(addr) => addr,
    None() => RIP,
  };
  sw_return_rip = None();
  let old_cs  : word  = read_segreg(CS);
  let old_rflags : qword = read_rflags();
  let old_rsp : qword = reg(RSP);
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
  if ~(gate.gate_present) then {
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
  if ~(software_int) & has_error_code(vec) then {
    new_rsp = push_to_stack(new_rsp, zero_extend(err_code))
  };

  // 6. Update RSP
  reg(RSP) = new_rsp;

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
  SegCache[CS].seg_l = 0b1;
  SegCache[CS].seg_db = 0b0;

  // 9. Set new RIP to handler address
  RIP = gate.gate_offset;

  // 10. If interrupt gate (type 0xE), clear IF
  if gate.gate_type == 0xE then {
    IF_flag = 0b0
  };

  // 11. Clear TF, NT, RF (SDM Vol.3 §7.12.1.3: "the processor also
  //     clears the VM, RF, and NT flags after saving RFLAGS on the stack")
  TF = 0b0;
  NT = 0b0;
  RF = 0b0;
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

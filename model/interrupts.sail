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
  gate_offset  : qword,        // handler RIP (assembled from 3 fields)
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

// Fault-class exceptions (SDM Vol.3A Table 7-1).  The RFLAGS image pushed
// for these carries RF = 1 so the instruction restarts past any instruction
// breakpoint (Vol.3B §20.3.1.1).  #DB is left out: its instruction-
// breakpoint fault pushes the current RF, like a trap.
val is_fault_class : exception_vector -> bool
function is_fault_class(vec) =
  vec == 0 | vec == 5 | vec == 6 | vec == 7 | vec == 10 | vec == 11 | vec == 12
  | vec == 13 | vec == 14 | vec == 16 | vec == 17 | vec == 19 | vec == 20 | vec == 21

// Read and parse a 16-byte IDT gate descriptor.
val read_idt_gate : exception_vector -> IDTGate
function read_idt_gate(vec) = {
  let vec_offset : qword = to_bits(64, vec * 16);
  let base : qword = IDTR_base + vec_offset;
  // IDT reads go through virtual address translation because the kernel
  // stores IDTR_base as a virtual address.  These are implicit supervisor
  // accesses (SDM Vol.3A §4.6) — they bypass U/S even though the CPU
  // may still be at CPL=3 for the first moment of fault delivery.
  let lo : qword = read_mem_implicit(base);
  let hi : qword = read_mem_implicit(base + 8);

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
// Implicit supervisor access (SDM Vol.3A §4.6): bypasses U/S regardless of CPL.
val read_tss_rsp0 : unit -> qword
function read_tss_rsp0() = {
  // RSP0 is at offset 4 in the 64-bit TSS.
  // TR_base is a linear (virtual) address set by LTR.
  read_mem_implicit(TR_base + 4)
}

// Read IST entry from the TSS.  Same implicit-access rule as RSP0.
val read_tss_ist : range(0, 7) -> qword
function read_tss_ist(ist_idx) = {
  // IST1 is at offset 36 (0x24) in the 64-bit TSS, each entry is 8 bytes.
  // TR_base is a linear (virtual) address.
  let offset : qword = to_bits(64, 36 + (ist_idx - 1) * 8);
  read_mem_implicit(TR_base + offset)
}

// Check if an exception vector has an error code.
val has_error_code : exception_vector -> bool
function has_error_code(vec) =
  vec == EXN_DF | vec == EXN_TS | vec == EXN_NP |
  vec == EXN_SS | vec == EXN_GP | vec == EXN_PF | vec == EXN_AC

// Push a value onto a stack given as a linear address.
// The caller is responsible for segmentation; this just decrements,
// writes, and returns the new linear stack pointer.
val push_to_stack : forall 'n, 8 <= 'n & 'n <= 64. (implicit('n), qword, bits('n)) -> qword
function push_to_stack(n, sp, value) = {
  let new_sp = sp - n / 8;
  write_mem(new_sp, value);
  new_sp
}

// Optional return address override for software interrupts (INT n, INT3).
// When Some(addr), deliver_exception_inner pushes addr instead of RIP.
// Reset to None() after each use.
register sw_return_rip : option(qword) = None()

// Read and parse an 8-byte IDT gate descriptor (protected mode).
// SDM Vol.3A §6.11: offset[31:16] @ offset[15:0], selector, type/DPL/P.
val read_idt_gate_32 : exception_vector -> IDTGate
function read_idt_gate_32(vec) = {
  let vec_offset : qword = to_bits(64, vec * 8);
  let base : qword = IDTR_base + vec_offset;
  let lo : dword = read_mem_implicit(base);
  let hi : dword = read_mem_implicit(base + 4);

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
  let esp0 : dword = read_mem_implicit(TR_base + 4);
  let ss0  : word  = read_mem_implicit(TR_base + 8);
  (esp0, ss0)
}

// Protected mode interrupt delivery (SDM Vol.3A §6.12).
// Reads 8-byte IDT gate, pushes 32-bit or 16-bit interrupt frame.
// Virtual-8086 delivery always enters a ring-0, nonconforming code segment
// and saves all six segment selectors (SDM Vol.3B §23.3.1.1; Vol.2 INT,
// INTERRUPT-FROM-VIRTUAL-8086-MODE). Validate before changing the mode or
// caches, so a fault in delivery can still build the virtual-8086 frame.
val deliver_exception_vm86 : (exception_vector, dword, EventKind) -> unit
function deliver_exception_vm86(vec, err_code, kind) = {
  let old_ip : qword = match sw_return_rip { Some(ip) => ip, None() => RIP };
  sw_return_rip = None();
  let ext : dword = if kind == EV_SoftwareInt then 0x00000000 else 0x00000001;
  let idt_err : dword = to_bits(32, vec * 8 + 2) | ext;
  if vec * 8 + 7 > unsigned(IDTR_limit) then raise_GP(idt_err);
  let gate = read_idt_gate_32(vec);
  if gate.gate_type != 0x6 & gate.gate_type != 0x7 &
     gate.gate_type != 0xE & gate.gate_type != 0xF then raise_GP(idt_err);
  if kind == EV_SoftwareInt & gate.gate_dpl < 3 then raise_GP(idt_err);
  if ~(gate.gate_present) then throw Fault(EXN_NP, idt_err);

  let cs_err = selector_error_code(gate.gate_sel) | ext;
  if gate.gate_sel[15..2] == zeros() then raise_GP(ext);
  let code_desc = read_descriptor(gate.gate_sel);
  if code_desc.seg_s == bitzero | code_desc.seg_type[3] == bitzero |
     code_desc.seg_type[2] == bitone | code_desc.seg_dpl != 0 then raise_GP(cs_err);
  if code_desc.seg_present == bitzero then throw Fault(EXN_NP, cs_err);
  let is_32bit = gate.gate_type[3] == bitone;
  let target = if is_32bit then gate.gate_offset else zero_extend(gate.gate_offset[15..0]);
  if unsigned(target) > unsigned(code_desc.seg_limit) then raise_GP(ext);

  if unsigned(TR_limit) < 9 then throw Fault(EXN_TS, selector_error_code(TR) | ext);
  let (esp0, ss0) = read_tss_esp0_32();
  let ss_err = selector_error_code(ss0) | ext;
  if ss0[15..2] == zeros() then throw Fault(EXN_TS, ext);
  let stack_desc : SegDescCache = try { read_descriptor(ss0) } catch {
    Fault(v, e) => {
      if v == EXN_GP then throw Fault(EXN_TS, e | ext) else throw Fault(v, e);
      exit()
    }
  };
  if ss0[1..0] != 0b00 | stack_desc.seg_dpl != 0 |
     stack_desc.seg_s == bitzero | stack_desc.seg_type[3] == bitone |
     stack_desc.seg_type[1] == bitzero then throw Fault(EXN_TS, ss_err);
  if stack_desc.seg_present == bitzero then throw Fault(EXN_SS, ss_err);

  let with_error = kind == EV_Exception & has_error_code(vec);
  let frame_bytes = (if is_32bit then 4 else 2) * (if with_error then 10 else 9);
  let sp : dword = if stack_desc.seg_db == bitone then esp0 else zero_extend(esp0[15..0]);
  let bottom = sp - frame_bytes;
  // An empty stack may use SP=0 to denote the top of its address range.
  // Expand-down segments accept offsets above, rather than below, limit.
  let top : int = if sp == zeros() then
                    (if stack_desc.seg_db == bitone then 4294967296 else 65536)
                  else unsigned(sp);
  let outside_limit : bool = if stack_desc.seg_type[2] == bitone then
                               top - frame_bytes <= unsigned(stack_desc.seg_limit)
                             else top - 1 > unsigned(stack_desc.seg_limit);
  if top < frame_bytes | outside_limit then
    throw Fault(EXN_SS, ss_err);
  let flags = read_rflags();
  let old_sp : dword = v(RSP);
  var addr : qword = stack_desc.seg_base + top;

  // The new stack is an implicit supervisor access, even though the
  // interrupted virtual-8086 program was running at CPL 3.
  cur_cpl = 0;
  try {
    foreach (j from 0 to 4) {
      let i : segreg_idx = match j { 0 => GS, 1 => FS, 2 => DS, 3 => ES, _ => SS };
      if is_32bit then addr = push_to_stack(addr, zero_extend(32, read_segreg(i)))
      else addr = push_to_stack(addr, read_segreg(i))
    };
    if is_32bit then {
      addr = push_to_stack(addr, old_sp);
      addr = push_to_stack(addr, flags[31..0]);
      addr = push_to_stack(addr, zero_extend(32, read_segreg(CS)));
      addr = push_to_stack(addr, old_ip[31..0]);
      if with_error then addr = push_to_stack(addr, err_code)
    } else {
      addr = push_to_stack(addr, old_sp[15..0]);
      addr = push_to_stack(addr, flags[15..0]);
      addr = push_to_stack(addr, read_segreg(CS));
      addr = push_to_stack(addr, old_ip[15..0]);
      if with_error then addr = push_to_stack(addr, err_code[15..0])
    }
  } catch {
    Fault(v, e) => { cur_cpl = 3; throw Fault(v, e) }
  };

  sw_return_rip = None();
  cur_mode = ProtectedMode;
  SegCache[CS] = code_desc;
  SegCache[SS] = stack_desc;
  write_segreg(CS, gate.gate_sel & 0xFFFC);
  write_segreg(SS, ss0);
  // A 16-bit monitor stack replaces SP only, preserving the interrupted
  // ESP's high half (confirmed on AMD and Intel).
  v(RSP) = if stack_desc.seg_db == bitone then bottom else old_sp[31..16] @ bottom[15..0];
  foreach (j from 0 to 3) {
    let i : segreg_idx = match j { 0 => ES, 1 => DS, 2 => FS, _ => GS };
    write_segreg(i, 0x0000);
    SegCache[i] = {default_seg_desc_cache() with seg_present = bitzero, seg_limit = zeros()}
  };
  RIP = target;
  if gate.gate_type == 0xE | gate.gate_type == 0x6 then IF_flag = bitzero;
  TF = bitzero;
  NT = bitzero;
  RF = bitzero
}

val deliver_exception_inner_32 : (exception_vector, dword, EventKind) -> unit
function deliver_exception_inner_32(vec, err_code, kind) = {
  let old_eip : dword = match sw_return_rip {
    Some(addr) => addr[31..0],
    None() => RIP[31..0],
  };
  sw_return_rip = None();
  let old_cs     : word  = read_segreg(CS);
  let old_eflags : dword = read_rflags()[31..0];
  let old_esp    : dword = v(RSP);
  let old_ss     : word  = read_segreg(SS);
  let old_cpl    : cpl_t = cur_cpl;

  cur_cpl = 0;

  let gate = read_idt_gate_32(vec);

  if ~(gate.gate_present) then {
    throw Fault(EXN_GP, to_bits(32, vec * 8 + 2))
  };

  if kind == EV_SoftwareInt & gate.gate_dpl < old_cpl then {
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
      new_esp = push_to_stack(new_esp, zero_extend(32, old_ss));
      new_esp = push_to_stack(new_esp, old_esp)
    };
    new_esp = push_to_stack(new_esp, old_eflags);
    new_esp = push_to_stack(new_esp, zero_extend(32, old_cs));
    new_esp = push_to_stack(new_esp, old_eip);
    if kind == EV_Exception & has_error_code(vec) then {
      new_esp = push_to_stack(new_esp, err_code)
    }
  } else {
    // 16-bit gate: push 16-bit values
    if privilege_change then {
      new_esp = push_to_stack(new_esp, old_ss);
      new_esp = push_to_stack(new_esp, old_esp[15..0])
    };
    new_esp = push_to_stack(new_esp, old_eflags[15..0]);
    new_esp = push_to_stack(new_esp, old_cs);
    new_esp = push_to_stack(new_esp, old_eip[15..0]);
    if kind == EV_Exception & has_error_code(vec) then {
      new_esp = push_to_stack(new_esp, err_code[15..0])
    }
  };

  // Update stack pointer and SS
  v(RSP) = new_esp[31..0];
  // SDM Vol.3A §§3.4.3, 7.12.1: a stack switch loads the hidden
  // descriptor state as well as the selector. Retaining the old base
  // makes the handler read its frame through the interrupted stack.
  if privilege_change then load_segment_register(SS, new_ss);

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
  push(old_flags);
  push(old_cs);
  push(old_ip);

  // Load new CS:IP
  load_segment_register(CS, new_cs);
  RIP = zero_extend(new_ip);

  // Clear IF and TF
  IF_flag = 0b0;
  TF = 0b0;
}

// Top-level inner delivery: dispatches by mode.
// May throw Fault if gate is not present or stack push faults.
// kind: EV_SoftwareInt for INT n, INT3 and INTO (gate DPL check, no error
//       code); EV_ExternalInt for an interrupt from the PIC/APIC (no error
//       code whatever the vector); EV_Exception otherwise, including INT1.
val deliver_exception_inner : (exception_vector, dword, EventKind) -> unit
function deliver_exception_inner(vec, err_code, kind) = {
  // Dispatch by mode
  if cur_mode == RealMode then {
    deliver_exception_real(vec);
    return ()
  };
  if cur_mode == Virtual8086Mode then {
    deliver_exception_vm86(vec, err_code, kind);
    return ()
  };
  if EFER[10] != 0b1 then {
    deliver_exception_inner_32(vec, err_code, kind);
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
  let old_rsp : qword = v(RSP);
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
  if kind == EV_SoftwareInt & gate.gate_dpl < old_cpl then {
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
  new_rsp = push_to_stack(new_rsp, zero_extend(64, old_ss));
  new_rsp = push_to_stack(new_rsp, old_rsp);
  new_rsp = push_to_stack(new_rsp, old_rflags);
  new_rsp = push_to_stack(new_rsp, zero_extend(64, old_cs));
  new_rsp = push_to_stack(new_rsp, old_rip);

  // 5. Push error code if applicable: only an exception has one (SDM
  // Vol.3A Table 7-1, §7.13); a software or external interrupt at the
  // same vector does not.
  if kind == EV_Exception & has_error_code(vec) then {
    new_rsp = push_to_stack(new_rsp, zero_extend(64, err_code))
  };

  // 6. Update RSP
  v(RSP) = new_rsp;

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
val deliver_exception : (exception_vector, dword, EventKind) -> unit
function deliver_exception(vec, err_code, kind) = {
  // Single-step bookkeeping (fetch_execute.sail): an event delivered during
  // an instruction means no single-step trap after it, and delivery ends
  // the MOV SS/POP SS shadow (SDM Vol.3A §7.8.3).
  event_delivered = true;
  ss_shadow = 0;
  sti_shadow = 0;

  // RF in the pushed RFLAGS image (SDM Vol.3B §20.3.1.1): 1 for a fault-
  // class exception, otherwise the current value (traps, software and
  // external interrupts, instruction-breakpoint #DB).  RF itself is cleared
  // again once the frame is pushed.
  if kind == EV_Exception & is_fault_class(vec) then RF = 0b1;

  // VMX exception bitmap check (SDM §25.2):
  // If in VMX non-root and the exception vector's bit is set in the
  // exception bitmap, cause a VM exit instead of delivering through IDT.
  if in_vmx_non_root & vec <= 31 then {
    if vmcs.exception_bitmap[vec] == 0b1 then {
      // Qualification: bits 31:0 encode vector (7:0), type (10:8),
      // error-code valid (bit 11), and NMI unblocking (bit 12).
      let has_ec : bool = has_error_code(vec);
      let int_type : bits(3) = if vec == 2 then 0b010 else 0b011; // NMI vs hardware exception
      let qual : qword = zero_extend(to_bits(32, vec))
                       | (zero_extend(int_type) << 8)
                       | (if has_ec then 0x0000000000000800 else 0x0000000000000000);
      // Also set exit_interruption_info and error code
      vmcs.exit_interruption_info = to_bits(32, vec) | (zero_extend(int_type) << 8)
                                  | (if has_ec then 0x00000800 else 0x00000000)
                                  | 0x80000000;
      if has_ec then vmcs.exit_interruption_errcode = err_code;
      vmcs.exit_instr_length = 0x00000000;
      throw VMExit(VMEXIT_EXCEPTION_NMI, qual)
    }
  };

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
      deliver_exception(EXN_DF, 0x00000000, EV_Exception);
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
    deliver_exception_inner(vec, err_code, kind)
  } catch {
    Fault(vec2, err2) => {
      // Fault during delivery — re-enter with escalation logic (always an exception)
      deliver_exception(vec2, err2, EV_Exception);
      return ()
    }
  };

  // Successful delivery — reset nesting
  exception_depth = 0;
}

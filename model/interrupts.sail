// x86-64 Sail Model — Exception and Interrupt Delivery
//
// In system mode, faults are delivered through the IDT:
//   1. Read 16-byte gate descriptor from IDTR_base + vector * 16
//   2. Read RSP0 from TSS if privilege change (ring 3 → ring 0)
//   3. Push interrupt frame: SS, RSP, RFLAGS, CS, RIP [, error code]
//   4. Set RIP to gate handler, CS to gate selector, CPL to 0
//   5. If interrupt gate (not trap gate), clear IF
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

// Read and parse a 16-byte IDT gate descriptor.
val read_idt_gate : exception_vector -> IDTGate
function read_idt_gate(vec) = {
  let vec_offset : qword = to_bits(64, vec * 16);
  let base : qword = IDTR_base + vec_offset;
  let lo : qword = phys_read64(base);
  let hi : qword = phys_read64(base + 8);

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
  // RSP0 is at offset 4 in the 64-bit TSS
  phys_read64(TR_base + 4)
}

// Read IST entry from the TSS.
val read_tss_ist : range(0, 7) -> qword
function read_tss_ist(ist_idx) = {
  // IST1 is at offset 36 (0x24) in the 64-bit TSS, each entry is 8 bytes
  let offset : qword = to_bits(64, 36 + (ist_idx - 1) * 8);
  phys_read64(TR_base + offset)
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
  // Write through paging (can itself fault — handled as double fault)
  mem_write64(new_rsp, value);
  new_rsp
}

// Deliver an exception/interrupt through the IDT.
// On success, updates RIP, RSP, CS, CPL, and IF as needed.
// On failure (e.g. gate not present), signals triple fault via should_exit.
val deliver_exception : (exception_vector, dword) -> unit
function deliver_exception(vec, err_code) = {
  let gate = read_idt_gate(vec);

  // 1. Check gate present
  if not_bool(gate.gate_present) then {
    // Gate not present — if this is already #DF, it's a triple fault
    if vec == EXN_DF then {
      // Triple fault: halt the CPU (handled by C++ loop)
      throw X86Fault(EXN_MC, 0x00000000)  // Use #MC as "triple fault" signal
    } else {
      // Try to deliver #GP instead
      deliver_exception(EXN_GP, to_bits(32, vec * 8 + 2));
      return ()
    }
  };

  // 2. Save old state
  let old_rip : qword = RIP;
  let old_cs  : word  = read_segreg(CS);
  let old_rflags : qword = read_rflags();
  let old_rsp : qword = read_gpr64(RSP);
  let old_ss  : word  = read_segreg(SS);
  let old_cpl : cpl_t = cur_cpl;

  // 3. Determine new stack
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

  // 5. Push error code if applicable
  if has_error_code(vec) then {
    new_rsp = push_to_stack(new_rsp, zero_extend(err_code))
  };

  // 6. Update RSP
  write_gpr64(RSP, new_rsp);

  // 7. Set SS to NULL selector with RPL = new CPL on privilege change
  //    or IST switch (SDM Vol.3 §7.14.4).
  if privilege_change | gate.gate_ist != 0 then {
    write_segreg(SS, 0x0000)  // NULL selector, RPL = 0 (target is ring 0)
  };

  // 8. Load new CS (simplified: just set the selector, don't load full descriptor)
  write_segreg(CS, gate.gate_sel);

  // 9. Set new RIP to handler address
  RIP = gate.gate_offset;

  // 10. Set CPL to 0 (kernel)
  cur_cpl = 0;

  // 11. If interrupt gate (type 0xE), clear IF
  if gate.gate_type == 0xE then {
    IF_flag = bitzero
  };

  // 12. Clear TF, NT, RF (SDM Vol.3 §7.12.1.3: "the processor also
  //     clears the VM, RF, and NT flags after saving RFLAGS on the stack")
  TF = bitzero;
  NT = bitzero;
  RF = bitzero;
}

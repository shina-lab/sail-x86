// x86-64 — System Management Mode (SMM)
//
// SDM Vol.3C Chapter 34: System Management Mode.
//
// SMM is entered via a System Management Interrupt (SMI). The processor
// saves its state to SMRAM at [SMBASE + 0x8000 + offset], switches to
// a real-address-like execution environment, and begins executing the
// SMI handler at SMBASE + 0x8000.
//
// The only way to exit SMM is the RSM instruction (0F AA), which
// restores the processor state from SMRAM and returns to the mode
// that was active when the SMI occurred.
//
// SMRAM state save map offsets for Intel 64 architecture (Table 34-3).
// All offsets are relative to SMBASE + 0x8000.

// =========================================================================
// SMI Delivery — save state to SMRAM and enter SMM
//
// SDM §34.3.1: "When the processor receives an SMI, it waits for all
// instructions to retire and for all stores to complete. The processor
// then saves its current context in SMRAM, enters SMM, and begins to
// execute the SMI handler."
//
// SDM §34.4.1: State save area at [SMBASE + 8000H + 7FFFH] down to
// [SMBASE + 8000H + 7C00H] for Intel 64.
//
// SDM §34.5.1 Table 34-4: Initial SMM execution environment.
// =========================================================================

// Helper: compute SMRAM state save address from offset.
// SDM: state save area at SMBASE + 0x8000 + offset.
// SMRAM helpers: read/write the state save area.
// Offset is from SDM Table 34-3, relative to SMBASE + 0x8000.
// We pass the offset as a bitvector to avoid Sail integer constraint issues.

val smram_save64 : (bits(16), qword) -> unit
function smram_save64(offset, v) = {
  let addr : qword = (0x00000000 @ smbase) + zero_extend(offset);
  phys_write(addr, v)
}

val smram_save32 : (bits(16), dword) -> unit
function smram_save32(offset, v) = {
  let addr : qword = (0x00000000 @ smbase) + zero_extend(offset);
  phys_write(addr, v)
}

val smram_save16 : (bits(16), word) -> unit
function smram_save16(offset, v) = {
  let addr : qword = (0x00000000 @ smbase) + zero_extend(offset);
  phys_write(addr, v)
}

val smram_load64 : bits(16) -> qword
function smram_load64(offset) = {
  let addr : qword = (0x00000000 @ smbase) + zero_extend(offset);
  phys_read(addr)
}

val smram_load32 : bits(16) -> dword
function smram_load32(offset) = {
  let addr : qword = (0x00000000 @ smbase) + zero_extend(offset);
  phys_read(addr)
}

val smram_load16 : bits(16) -> word
function smram_load16(offset) = {
  let addr : qword = (0x00000000 @ smbase) + zero_extend(offset);
  phys_read(addr)
}

val deliver_smi : unit -> unit
function deliver_smi() = {
  // Save general-purpose registers (Table 34-3, Intel 64 format)
  smram_save64(0x7F5C, v(RAX));
  smram_save64(0x7F64, v(RCX));
  smram_save64(0x7F6C, v(RDX));
  smram_save64(0x7F74, v(RBX));
  smram_save64(0x7F7C, v(RSP));
  smram_save64(0x7F84, v(RBP));
  smram_save64(0x7F8C, v(RSI));
  smram_save64(0x7F94, v(RDI));
  smram_save64(0x7F54, v(R8));
  smram_save64(0x7F4C, v(R9));
  smram_save64(0x7F44, v(R10));
  smram_save64(0x7F3C, v(R11));
  smram_save64(0x7F34, v(R12));
  smram_save64(0x7F2C, v(R13));
  smram_save64(0x7F24, v(R14));
  smram_save64(0x7F1C, v(R15));

  // Save RIP
  smram_save64(0x7FD8, RIP);

  // Save RFLAGS
  smram_save64(0x7FE8, read_rflags());

  // Save control registers
  smram_save64(0x7FF8, CR0);
  smram_save64(0x7FF0, CR3);
  smram_save64(0x7FE0, EFER);

  // Save CR4 (64 bits at offset 7E40H per Table 34-3)
  smram_save64(0x7E40, CR4);

  // Save debug registers
  smram_save64(0x7FD0, DR6);
  smram_save64(0x7FC8, DR7);

  // Save segment selectors (32-bit fields, upper 16 bits reserved)
  smram_save32(0x7FA8, zero_extend(read_segreg(ES)));
  smram_save32(0x7FAC, zero_extend(read_segreg(CS)));
  smram_save32(0x7FB0, zero_extend(read_segreg(SS)));
  smram_save32(0x7FB4, zero_extend(read_segreg(DS)));
  smram_save32(0x7FB8, zero_extend(read_segreg(FS)));
  smram_save32(0x7FBC, zero_extend(read_segreg(GS)));
  smram_save32(0x7FC0, zero_extend(LDTR));
  smram_save32(0x7FC4, zero_extend(TR));

  // Save GDTR/IDTR base (split: lower 32 at one offset, upper 32 at another)
  smram_save32(0x7E8C, GDTR_base[31..0]);
  smram_save32(0x7DD0, GDTR_base[63..32]);
  smram_save32(0x7E94, IDTR_base[31..0]);
  smram_save32(0x7DD8, IDTR_base[63..32]);

  // Save SMBASE (writable by SMI handler for relocation)
  smram_save32(0x7EF8, smbase);

  // Write SMM Revision Identifier (SDM §34.9)
  // Bits 17:16 indicate capabilities:
  //   Bit 17: SMBASE relocation supported
  //   Bit 16: I/O instruction restart supported
  // Lower 16 bits: revision ID. We use 0x0064 to indicate Intel 64 format.
  smram_save32(0x7EFC, 0x00030064);

  // Auto HALT Restart field (offset 7F02H)
  // Bit 0 = 1 if SMI was received while in HLT state
  smram_save16(0x7F02, if system_state == SysHalted then 0x0001 else 0x0000);

  // I/O Instruction Restart field (offset 7F00H) — set to 0 (no I/O restart)
  smram_save16(0x7F00, 0x0000);

  // === Set up initial SMM execution environment (Table 34-4) ===

  // CR0: clear PE (0), EM (2), TS (3), PG (31)
  // SDM Table 34-4: "PE, EM, TS, and PG flags in CR0 are cleared"
  CR0 = CR0 & ~(0x000000008000000B : qword);

  // CR4: cleared to zero
  CR4 = 0x0000000000000000;

  // EFLAGS: set to 00000002H (reserved bit 1 always 1)
  write_rflags(0x0000000000000002);

  // EFER: cleared (exits IA-32e mode if active)
  EFER = 0x0000000000000000;

  // EIP = 8000H (SMI handler entry point relative to SMBASE)
  RIP = 0x0000000000008000;

  // CS: selector = SMBASE >> 4, base = SMBASE
  write_segreg(CS, smbase[19..4]);
  SegCache[CS].seg_base = 0x00000000 @ smbase;
  SegCache[CS].seg_limit = 0xFFFFFFFF;
  SegCache[CS].seg_type = 0x3;
  SegCache[CS].seg_s = 0b1;
  SegCache[CS].seg_present = 0b1;
  SegCache[CS].seg_db = 0b0;  // 16-bit default
  SegCache[CS].seg_l = 0b0;
  SegCache[CS].seg_g = 0b0;

  // DS, ES, FS, GS, SS: selector = 0, base = 0, limit = 4GB
  // SDM Table 34-4: "Cleared to 0" for selectors, "000000000H" for bases,
  // "0FFFFFFFFH" for limits.
  foreach (seg from 0 to 5) {
    if seg != CS then {
      write_segreg(seg, 0x0000);
      SegCache[seg].seg_base = 0x0000000000000000;
      SegCache[seg].seg_limit = 0xFFFFFFFF;
      SegCache[seg].seg_type = 0x3;
      SegCache[seg].seg_s = 0b1;
      SegCache[seg].seg_present = 0b1;
      SegCache[seg].seg_db = 0b0;
      SegCache[seg].seg_l = 0b0;
      SegCache[seg].seg_g = 0b0;
    }
  };

  // DR7 = 00000400H (SDM Table 34-4)
  DR7 = 0x0000000000000400;

  // Enter SMM
  in_smm = true;
  cur_mode = RealMode;    // SMM execution environment is real-address-like
  cur_cpl = 0;
  system_state = SysRunning;
}

// =========================================================================
// RSM — Resume from System Management Mode (SDM Vol.2B §RSM)
//
// Opcode: 0F AA
// #UD if not in SMM.
//
// Restores processor state from SMRAM state save area.
// Reloads SMBASE from offset 7EF8H (for SMBASE relocation).
// Returns to the operating mode that was active when SMI occurred.
// =========================================================================

val exec_rsm : unit -> unit
function exec_rsm() = {
  if ~(in_smm) then raise_UD();

  // Restore SMBASE first (for relocation support)
  smbase = smram_load32(0x7EF8);

  // Restore control registers
  CR0 = smram_load64(0x7FF8);
  CR3 = smram_load64(0x7FF0);
  EFER = smram_load64(0x7FE0);
  CR4 = smram_load64(0x7E40);

  // Restore RFLAGS
  write_rflags(smram_load64(0x7FE8));

  // Restore RIP
  RIP = smram_load64(0x7FD8);

  // Restore debug registers
  DR6 = smram_load64(0x7FD0);
  DR7 = smram_load64(0x7FC8);

  // Restore general-purpose registers
  v(RAX) = smram_load64(0x7F5C);
  v(RCX) = smram_load64(0x7F64);
  v(RDX) = smram_load64(0x7F6C);
  v(RBX) = smram_load64(0x7F74);
  v(RSP) = smram_load64(0x7F7C);
  v(RBP) = smram_load64(0x7F84);
  v(RSI) = smram_load64(0x7F8C);
  v(RDI) = smram_load64(0x7F94);
  v(R8)  = smram_load64(0x7F54);
  v(R9)  = smram_load64(0x7F4C);
  v(R10) = smram_load64(0x7F44);
  v(R11) = smram_load64(0x7F3C);
  v(R12) = smram_load64(0x7F34);
  v(R13) = smram_load64(0x7F2C);
  v(R14) = smram_load64(0x7F24);
  v(R15) = smram_load64(0x7F1C);

  // Restore segment selectors
  // SDM §34.3.2: "The RSM instruction restores the processor's context
  // by loading the state save image from SMRAM back into the processor's
  // registers."
  // The hidden descriptor cache parts are also restored (saved/restored
  // automatically per SDM §34.4.1 note 1).
  load_segment_register(ES, smram_load32(0x7FA8)[15..0]);
  load_segment_register(CS, smram_load32(0x7FAC)[15..0]);
  load_segment_register(SS, smram_load32(0x7FB0)[15..0]);
  load_segment_register(DS, smram_load32(0x7FB4)[15..0]);
  load_segment_register(FS, smram_load32(0x7FB8)[15..0]);
  load_segment_register(GS, smram_load32(0x7FBC)[15..0]);

  // Restore GDTR/IDTR
  GDTR_base = (zero_extend(smram_load32(0x7DD0)) << 32)
              | zero_extend(smram_load32(0x7E8C));
  IDTR_base = (zero_extend(smram_load32(0x7DD8)) << 32)
              | zero_extend(smram_load32(0x7E94));

  // Determine operating mode from restored CR0/EFER
  // SDM §34.5.2: "Execution of the RSM instruction restores the pre-SMI
  // processor state from the SMRAM state-state map."
  if EFER[10] == 0b1 then {
    // IA-32e mode active (LMA=1)
    if SegCache[CS].seg_l == 0b1 then cur_mode = LongMode
    else cur_mode = CompatibilityMode
  } else if CR0[0] == 0b1 then {
    cur_mode = ProtectedMode
  } else {
    cur_mode = RealMode
  };

  cur_cpl = 0;  // Restored from segment selector RPL, but simplified here

  // Handle Auto HALT Restart (SDM §34.10)
  if smram_load16(0x7F02)[0] == 0b1 then {
    // SMI occurred during HLT — re-enter HALT state
    system_state = SysHalted
  };

  // Exit SMM
  in_smm = false;

  // RIP was already restored above; set next_rip so step() doesn't overwrite it
  next_rip = Some(RIP)
}

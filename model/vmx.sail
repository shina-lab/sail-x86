// x86-64 — VMX VM Entry, VM Exit, and Helpers
//
// SDM Vol.3C Chapter 25-28: VM Entries and VM Exits.
//
// VMfail/VMsucceed result helpers, vm_entry(), complete_vm_exit(),
// and VM-exit guard functions.
//
// Follows the SMM pattern (deliver_smi / exec_rsm) for bulk state
// save/restore.

// =========================================================================
// VMfail result helpers (SDM Vol.3C §31.2)
//
// VMX instructions set RFLAGS to indicate success/failure:
//   VMsucceed:     CF=0, PF=0, AF=0, ZF=0, SF=0, OF=0
//   VMfailValid:   ZF=1, all others 0; write error number to VMCS
//   VMfailInvalid: CF=1, all others 0 (no current VMCS)
// =========================================================================

val vmx_succeed : unit -> unit
function vmx_succeed() = {
  CF = 0b0; PF = 0b0; AF = 0b0; ZF = 0b0; SF = 0b0; OF = 0b0
}

val vmx_fail_valid : dword -> unit
function vmx_fail_valid(error_number) = {
  CF = 0b0; PF = 0b0; AF = 0b0; ZF = 0b1; SF = 0b0; OF = 0b0;
  vmcs.vm_instruction_error = error_number
}

val vmx_fail_invalid : unit -> unit
function vmx_fail_invalid() = {
  CF = 0b1; PF = 0b0; AF = 0b0; ZF = 0b0; SF = 0b0; OF = 0b0
}

// =========================================================================
// VM Entry (SDM Vol.3C Chapter 27)
//
// Called by VMLAUNCH/VMRESUME. Loads guest state from the current VMCS
// into architectural registers. Minimal entry checks for now (Phase 4
// will add full SDM Chapter 27 validation).
// =========================================================================

val vm_entry : bool -> unit
function vm_entry(is_launch) = {
  // Check launch state
  if is_launch then {
    if vmcs.launch_state != 0x00000000 then {
      vmx_fail_valid(VMXERR_VMLAUNCH_NONCLEAR);
      return ()
    }
  } else {
    if vmcs.launch_state != 0x00000001 then {
      vmx_fail_valid(VMXERR_VMRESUME_NONLAUNCHED);
      return ()
    }
  };

  // --- Load guest control registers ---
  CR0 = vmcs.guest_cr0;
  CR3 = vmcs.guest_cr3;
  CR4 = vmcs.guest_cr4;
  DR7 = vmcs.guest_dr7;
  EFER = vmcs.guest_efer;

  // --- Load guest RIP, RSP, RFLAGS ---
  RIP = vmcs.guest_rip;
  v(RSP) = vmcs.guest_rsp;
  write_rflags(vmcs.guest_rflags);

  // --- Load guest segment registers ---
  write_segreg(ES, vmcs.guest_es_selector);
  SegCache[ES].seg_base = vmcs.guest_es_base;
  SegCache[ES].seg_limit = vmcs.guest_es_limit;
  SegCache[ES].seg_type = vmcs.guest_es_access[3..0];
  SegCache[ES].seg_s = vmcs.guest_es_access[4];
  SegCache[ES].seg_dpl = unsigned(vmcs.guest_es_access[6..5]);
  SegCache[ES].seg_present = vmcs.guest_es_access[7];
  SegCache[ES].seg_db = vmcs.guest_es_access[14];
  SegCache[ES].seg_g = vmcs.guest_es_access[15];
  SegCache[ES].seg_l = vmcs.guest_es_access[13];

  write_segreg(CS, vmcs.guest_cs_selector);
  SegCache[CS].seg_base = vmcs.guest_cs_base;
  SegCache[CS].seg_limit = vmcs.guest_cs_limit;
  SegCache[CS].seg_type = vmcs.guest_cs_access[3..0];
  SegCache[CS].seg_s = vmcs.guest_cs_access[4];
  SegCache[CS].seg_dpl = unsigned(vmcs.guest_cs_access[6..5]);
  SegCache[CS].seg_present = vmcs.guest_cs_access[7];
  SegCache[CS].seg_db = vmcs.guest_cs_access[14];
  SegCache[CS].seg_g = vmcs.guest_cs_access[15];
  SegCache[CS].seg_l = vmcs.guest_cs_access[13];

  write_segreg(SS, vmcs.guest_ss_selector);
  SegCache[SS].seg_base = vmcs.guest_ss_base;
  SegCache[SS].seg_limit = vmcs.guest_ss_limit;
  SegCache[SS].seg_type = vmcs.guest_ss_access[3..0];
  SegCache[SS].seg_s = vmcs.guest_ss_access[4];
  SegCache[SS].seg_dpl = unsigned(vmcs.guest_ss_access[6..5]);
  SegCache[SS].seg_present = vmcs.guest_ss_access[7];
  SegCache[SS].seg_db = vmcs.guest_ss_access[14];
  SegCache[SS].seg_g = vmcs.guest_ss_access[15];
  SegCache[SS].seg_l = vmcs.guest_ss_access[13];

  write_segreg(DS, vmcs.guest_ds_selector);
  SegCache[DS].seg_base = vmcs.guest_ds_base;
  SegCache[DS].seg_limit = vmcs.guest_ds_limit;
  SegCache[DS].seg_type = vmcs.guest_ds_access[3..0];
  SegCache[DS].seg_s = vmcs.guest_ds_access[4];
  SegCache[DS].seg_dpl = unsigned(vmcs.guest_ds_access[6..5]);
  SegCache[DS].seg_present = vmcs.guest_ds_access[7];
  SegCache[DS].seg_db = vmcs.guest_ds_access[14];
  SegCache[DS].seg_g = vmcs.guest_ds_access[15];
  SegCache[DS].seg_l = vmcs.guest_ds_access[13];

  write_segreg(FS, vmcs.guest_fs_selector);
  SegCache[FS].seg_base = vmcs.guest_fs_base;
  SegCache[FS].seg_limit = vmcs.guest_fs_limit;
  SegCache[FS].seg_type = vmcs.guest_fs_access[3..0];
  SegCache[FS].seg_s = vmcs.guest_fs_access[4];
  SegCache[FS].seg_dpl = unsigned(vmcs.guest_fs_access[6..5]);
  SegCache[FS].seg_present = vmcs.guest_fs_access[7];
  SegCache[FS].seg_db = vmcs.guest_fs_access[14];
  SegCache[FS].seg_g = vmcs.guest_fs_access[15];
  SegCache[FS].seg_l = vmcs.guest_fs_access[13];

  write_segreg(GS, vmcs.guest_gs_selector);
  SegCache[GS].seg_base = vmcs.guest_gs_base;
  SegCache[GS].seg_limit = vmcs.guest_gs_limit;
  SegCache[GS].seg_type = vmcs.guest_gs_access[3..0];
  SegCache[GS].seg_s = vmcs.guest_gs_access[4];
  SegCache[GS].seg_dpl = unsigned(vmcs.guest_gs_access[6..5]);
  SegCache[GS].seg_present = vmcs.guest_gs_access[7];
  SegCache[GS].seg_db = vmcs.guest_gs_access[14];
  SegCache[GS].seg_g = vmcs.guest_gs_access[15];
  SegCache[GS].seg_l = vmcs.guest_gs_access[13];

  // LDTR and TR
  LDTR = vmcs.guest_ldtr_selector;
  TR = vmcs.guest_tr_selector;
  TR_base = vmcs.guest_tr_base;
  TR_limit = vmcs.guest_tr_limit;

  // GDTR and IDTR
  GDTR_base = vmcs.guest_gdtr_base;
  GDTR_limit = vmcs.guest_gdtr_limit[15..0];
  IDTR_base = vmcs.guest_idtr_base;
  IDTR_limit = vmcs.guest_idtr_limit[15..0];

  // --- Set processor mode from guest state ---
  if EFER[10] == 0b1 then {
    if SegCache[CS].seg_l == 0b1 then cur_mode = LongMode
    else cur_mode = CompatibilityMode
  } else if CR0[0] == 0b1 then {
    cur_mode = ProtectedMode
  } else {
    cur_mode = RealMode
  };

  // Guest CPL = CS selector RPL (SDM §27.2.2)
  cur_cpl = unsigned(vmcs.guest_cs_selector[1..0]);

  // --- Activity state ---
  if vmcs.guest_activity_state == 0x00000001 then
    system_state = SysHalted
  else
    system_state = SysRunning;

  // --- Switch to VMX non-root ---
  in_vmx_non_root = true;

  // Mark as launched (for VMRESUME)
  if is_launch then vmcs.launch_state = 0x00000001;

  // Set next_rip so step() transfers control to guest RIP
  next_rip = Some(RIP)
}

// =========================================================================
// VM Exit (SDM Vol.3C Chapter 28)
//
// Called when a VM exit occurs. Saves guest state to VMCS, loads host
// state from VMCS, records exit reason and qualification.
// =========================================================================

val complete_vm_exit : (dword, qword) -> unit
function complete_vm_exit(reason, qual) = {
  // --- Save guest state to VMCS ---
  vmcs.guest_cr0 = CR0;
  vmcs.guest_cr3 = CR3;
  vmcs.guest_cr4 = CR4;
  vmcs.guest_dr7 = DR7;
  vmcs.guest_efer = EFER;

  vmcs.guest_rip = RIP;
  vmcs.guest_rsp = v(64, RSP);
  vmcs.guest_rflags = read_rflags();

  // Save segment registers
  vmcs.guest_es_selector = read_segreg(ES);
  vmcs.guest_cs_selector = read_segreg(CS);
  vmcs.guest_ss_selector = read_segreg(SS);
  vmcs.guest_ds_selector = read_segreg(DS);
  vmcs.guest_fs_selector = read_segreg(FS);
  vmcs.guest_gs_selector = read_segreg(GS);

  vmcs.guest_es_base = SegCache[ES].seg_base;
  vmcs.guest_cs_base = SegCache[CS].seg_base;
  vmcs.guest_ss_base = SegCache[SS].seg_base;
  vmcs.guest_ds_base = SegCache[DS].seg_base;
  vmcs.guest_fs_base = SegCache[FS].seg_base;
  vmcs.guest_gs_base = SegCache[GS].seg_base;

  vmcs.guest_es_limit = SegCache[ES].seg_limit;
  vmcs.guest_cs_limit = SegCache[CS].seg_limit;
  vmcs.guest_ss_limit = SegCache[SS].seg_limit;
  vmcs.guest_ds_limit = SegCache[DS].seg_limit;
  vmcs.guest_fs_limit = SegCache[FS].seg_limit;
  vmcs.guest_gs_limit = SegCache[GS].seg_limit;

  vmcs.guest_gdtr_base = GDTR_base;
  vmcs.guest_gdtr_limit = zero_extend(GDTR_limit);
  vmcs.guest_idtr_base = IDTR_base;
  vmcs.guest_idtr_limit = zero_extend(IDTR_limit);

  vmcs.guest_tr_selector = TR;
  vmcs.guest_tr_base = TR_base;
  vmcs.guest_tr_limit = TR_limit;
  vmcs.guest_ldtr_selector = LDTR;

  // Save activity state
  vmcs.guest_activity_state = if system_state == SysHalted
    then 0x00000001 else 0x00000000;

  // --- Record exit information ---
  vmcs.exit_reason = reason;
  vmcs.exit_qualification = qual;
  // exit_instr_length is set by the throwing instruction when applicable

  // --- Load host state from VMCS ---
  CR0 = vmcs.host_cr0;
  CR3 = vmcs.host_cr3;
  CR4 = vmcs.host_cr4;
  EFER = vmcs.host_efer;

  v(RSP) = vmcs.host_rsp;
  RIP = vmcs.host_rip;

  // Host segment selectors (SDM §28.5.2)
  write_segreg(ES, vmcs.host_es_selector);
  write_segreg(CS, vmcs.host_cs_selector);
  write_segreg(SS, vmcs.host_ss_selector);
  write_segreg(DS, vmcs.host_ds_selector);
  write_segreg(FS, vmcs.host_fs_selector);
  write_segreg(GS, vmcs.host_gs_selector);
  TR = vmcs.host_tr_selector;

  // Host segment bases
  SegCache[FS].seg_base = vmcs.host_fs_base;
  SegCache[GS].seg_base = vmcs.host_gs_base;
  TR_base = vmcs.host_tr_base;

  // Host GDTR/IDTR
  GDTR_base = vmcs.host_gdtr_base;
  IDTR_base = vmcs.host_idtr_base;

  // Host CS/SS/DS/ES get flat segment descriptors (SDM §28.5.2)
  // "Selector value is loaded. [...] The segment is loaded as a data
  // segment" with base=0, limit=FFFFFFFF, G=1, D/B=1, P=1, DPL=0.
  foreach (seg from 0 to 3) {
    SegCache[seg].seg_base = 0x0000000000000000;
    SegCache[seg].seg_limit = 0xFFFFFFFF;
    SegCache[seg].seg_type = 0x3;
    SegCache[seg].seg_s = 0b1;
    SegCache[seg].seg_dpl = 0;
    SegCache[seg].seg_present = 0b1;
    SegCache[seg].seg_db = 0b1;
    SegCache[seg].seg_g = 0b1;
    SegCache[seg].seg_l = 0b0;
  };

  // CS gets code segment attributes; if host is IA-32e, set L=1
  SegCache[CS].seg_type = 0xB;  // code, execute/read, accessed
  if vmcs.host_efer[10] == 0b1 then SegCache[CS].seg_l = 0b1;

  // Determine host processor mode from EFER.LMA
  if vmcs.host_efer[10] == 0b1 then {
    cur_mode = LongMode
  } else if vmcs.host_cr0[0] == 0b1 then {
    cur_mode = ProtectedMode
  } else {
    cur_mode = RealMode
  };

  // Host is always CPL 0
  cur_cpl = 0;
  system_state = SysRunning;

  // --- Return to VMX root operation ---
  in_vmx_non_root = false;
  // in_vmx_root remains true

  // RFLAGS: SDM §28.5.5: "RFLAGS is cleared, except bit 1 (always 1)"
  write_rflags(0x0000000000000002);

  // Transfer control to host RIP
  next_rip = Some(RIP)
}

// =========================================================================
// VM-Exit Guard Functions
//
// One-liner guards inserted at the top of instructions that cause
// conditional or unconditional VM exits. No-ops when not in VMX
// non-root mode.
// =========================================================================

// Unconditional VM exit for CPUID (SDM §26.1.2: always exits).
val vmx_exit_cpuid : unit -> unit
function vmx_exit_cpuid() = {
  if in_vmx_non_root then {
    vmcs.exit_instr_length = (decode_pos - insn_start)[31..0];
    throw VMExit(VMEXIT_CPUID, 0x0000000000000000)
  }
}

// Unconditional VM exit for INVD (SDM §26.1.2).
val vmx_exit_invd : unit -> unit
function vmx_exit_invd() = {
  if in_vmx_non_root then {
    vmcs.exit_instr_length = (decode_pos - insn_start)[31..0];
    throw VMExit(VMEXIT_INVD, 0x0000000000000000)
  }
}

// Unconditional VM exit for XSETBV (SDM §26.1.2).
val vmx_exit_xsetbv : unit -> unit
function vmx_exit_xsetbv() = {
  if in_vmx_non_root then {
    vmcs.exit_instr_length = (decode_pos - insn_start)[31..0];
    throw VMExit(VMEXIT_XSETBV, 0x0000000000000000)
  }
}

// VMX instructions in non-root cause unconditional VM exit (SDM §26.1.2).
val vmx_exit_vmx_insn : dword -> unit
function vmx_exit_vmx_insn(reason) = {
  if in_vmx_non_root then {
    vmcs.exit_instr_length = (decode_pos - insn_start)[31..0];
    throw VMExit(reason, 0x0000000000000000)
  }
}

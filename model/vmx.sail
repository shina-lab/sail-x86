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
// VM-Entry Checks (SDM Vol.3C §27.1-27.3)
//
// Validate VMCS control fields and host/guest state before VM entry.
// Returns true if checks pass, false otherwise.
// =========================================================================

// Check VM-execution control fields, VM-exit controls, VM-entry controls.
// SDM §27.2.1: Checks on VMX Controls.
val check_vmentry_controls : unit -> bool
function check_vmentry_controls() = {
  let pin = vmcs.pin_based_controls;
  let proc1 = vmcs.primary_proc_controls;
  let exit_ctl = vmcs.exit_controls;
  let entry_ctl = vmcs.entry_controls;

  // Pin-based controls: bits 1, 2, 4-6 are reserved and must be 0
  // (simplified — real hardware checks against IA32_VMX_PINBASED_CTLS MSR)

  // If "activate secondary controls" (bit 31) is 0, secondary controls
  // must be treated as 0 (SDM §24.6.2).

  // VM-exit controls: "host address-space size" (bit 9) must be consistent
  // with IA-32e mode. If host EFER.LMA will be set, bit 9 must be 1.
  // (We check this in host state checks instead.)

  // VM-entry controls: "IA-32e mode guest" (bit 9) consistency checks.
  // If entry_ctl bit 9 = 1 (IA-32e mode guest), then guest CR0.PG and
  // CR4.PAE must both be set.
  if entry_ctl[9] == 0b1 then {
    if vmcs.guest_cr0[31] == 0b0 then return false;  // PG must be set
    if vmcs.guest_cr4[5] == 0b0 then return false     // PAE must be set
  };

  // If entry_ctl bit 9 = 0 (not IA-32e mode), guest CR4.PCIDE must be 0.
  if entry_ctl[9] == 0b0 then {
    if vmcs.guest_cr4[17] == 0b1 then return false    // PCIDE
  };

  // CR3-target count must not exceed 4 (SDM §27.2.1.1)
  if unsigned(vmcs.cr3_target_count) > 4 then return false;

  // If "use I/O bitmaps" (bit 25), bitmap addresses must be 4KB-aligned
  if proc1[25] == 0b1 then {
    if vmcs.io_bitmap_a[11..0] != 0x000 then return false;
    if vmcs.io_bitmap_b[11..0] != 0x000 then return false
  };

  // If "use MSR bitmaps" (bit 28), bitmap address must be 4KB-aligned
  if proc1[28] == 0b1 then {
    if vmcs.msr_bitmap[11..0] != 0x000 then return false
  };

  // VM-entry interruption info: if valid (bit 31), type must be consistent
  if vmcs.entry_interruption_info[31] == 0b1 then {
    let int_type : bits(3) = vmcs.entry_interruption_info[10..8];
    // Type 1 (reserved) is invalid
    if int_type == 0b001 then return false
  };

  // Guest CR0 fixed-bit checks (SDM §27.2.1.1)
  // With unrestricted guest (secondary bit 7), PE and PG are not required.
  let unrestricted : bool = proc1[31] == 0b1 & vmcs.secondary_proc_controls[7] == 0b1;
  let cr0_fixed0 : qword = if unrestricted then 0x0000000000000020  // only NE
                            else 0x0000000080000021;  // PE + NE + PG
  let cr0_fixed1 : qword = 0x00000000FFFFFFFF;
  if (vmcs.guest_cr0 & cr0_fixed0) != cr0_fixed0 then return false;
  if (vmcs.guest_cr0 & cr0_fixed1) != vmcs.guest_cr0 then return false;

  // Guest CR4 fixed-bit checks
  let cr4_fixed0 : qword = 0x0000000000002000;  // VMXE
  let cr4_fixed1 : qword = 0x00000000FFFFFFFF;
  if (vmcs.guest_cr4 & cr4_fixed0) != cr4_fixed0 then return false;
  if (vmcs.guest_cr4 & cr4_fixed1) != vmcs.guest_cr4 then return false;

  true
}

// Check guest-state area (SDM §27.2.3).
val check_vmentry_guest_state : unit -> bool
function check_vmentry_guest_state() = {
  let entry_ctl = vmcs.entry_controls;

  // CR0 fixed-bit checks — relaxed with unrestricted guest
  let unrestricted : bool = vmcs.primary_proc_controls[31] == 0b1
                          & vmcs.secondary_proc_controls[7] == 0b1;
  let cr0_fixed0 : qword = if unrestricted then 0x0000000000000020
                            else 0x0000000080000021;
  if (vmcs.guest_cr0 & cr0_fixed0) != cr0_fixed0 then return false;

  // CR4 fixed-bit checks
  let cr4_fixed0 : qword = 0x0000000000002000;
  if (vmcs.guest_cr4 & cr4_fixed0) != cr4_fixed0 then return false;

  // CR0.PG=1 requires CR0.PE=1 (SDM §27.2.3.1)
  if vmcs.guest_cr0[31] == 0b1 & vmcs.guest_cr0[0] == 0b0 then return false;

  // IA-32e mode consistency (SDM §27.2.3.1):
  // If entry controls bit 9 (IA-32e mode guest) = 1:
  //   guest EFER.LMA must be 1, CR0.PG must be 1
  // If entry controls bit 9 = 0:
  //   guest EFER.LMA must be 0
  if entry_ctl[9] == 0b1 then {
    if vmcs.guest_efer[10] == 0b0 then return false;  // LMA must be 1
    if vmcs.guest_cr0[31] == 0b0 then return false     // PG must be 1
  } else {
    if vmcs.guest_efer[10] == 0b1 then return false    // LMA must be 0
  };

  // RFLAGS checks (SDM §27.2.3.2):
  // Bit 1 must be 1 (reserved, always 1)
  if vmcs.guest_rflags[1] == 0b0 then return false;
  // Bits 63:22 must be 0
  if vmcs.guest_rflags[63..22] != zeros() then return false;

  // If IA-32e mode guest, VM flag (bit 17) must be 0
  if entry_ctl[9] == 0b1 & vmcs.guest_rflags[17] == 0b1 then return false;

  // Activity state checks (SDM §27.2.3.4):
  // Must be 0 (active) or 1 (HLT)
  if unsigned(vmcs.guest_activity_state) > 1 then return false;

  // CS type must be a code segment (type bit 3 = 1, S = 1)
  if vmcs.guest_cs_access[3] == 0b0 then return false;
  if vmcs.guest_cs_access[4] == 0b0 then return false;

  // VMCS link pointer: if not 0xFFFFFFFFFFFFFFFF, must be 4KB-aligned
  if vmcs.guest_vmcs_link_pointer != 0xFFFFFFFFFFFFFFFF then {
    if vmcs.guest_vmcs_link_pointer[11..0] != 0x000 then return false
  };

  true
}

// Check host-state area (SDM §27.2.2).
val check_vmentry_host_state : unit -> bool
function check_vmentry_host_state() = {
  // Host CR0: PE (bit 0) and NE (bit 5) must be set
  // (These are always-set bits per IA32_VMX_CR0_FIXED0)
  if vmcs.host_cr0[0] == 0b0 then return false;

  // Host CR4: reserved bits check (simplified)
  // VMXE (bit 13) must be set in host CR4
  if vmcs.host_cr4[13] == 0b0 then return false;

  // Host CS and TR selectors must not be 0x0000 (SDM §27.2.2)
  if vmcs.host_cs_selector == 0x0000 then return false;
  if vmcs.host_tr_selector == 0x0000 then return false;

  // Host SS selector must not be 0 unless "host address-space size" = 1
  // (64-bit host can have SS=0)
  if vmcs.exit_controls[9] == 0b0 & vmcs.host_ss_selector == 0x0000 then
    return false;

  // Selector RPL and TI must be 0 for all host segment selectors
  if vmcs.host_cs_selector[2..0] != 0b000 then return false;
  if vmcs.host_ss_selector[2..0] != 0b000 & vmcs.host_ss_selector != 0x0000 then
    return false;
  if vmcs.host_ds_selector[2..0] != 0b000 & vmcs.host_ds_selector != 0x0000 then
    return false;
  if vmcs.host_es_selector[2..0] != 0b000 & vmcs.host_es_selector != 0x0000 then
    return false;
  if vmcs.host_fs_selector[2..0] != 0b000 & vmcs.host_fs_selector != 0x0000 then
    return false;
  if vmcs.host_gs_selector[2..0] != 0b000 & vmcs.host_gs_selector != 0x0000 then
    return false;
  if vmcs.host_tr_selector[2..0] != 0b000 then return false;

  // Host address-space size (exit controls bit 9):
  // If 1 (64-bit host): host EFER.LMA and EFER.LME must be set,
  //   CS.L (implied) must be set.
  // If 0 (32-bit host): host EFER.LMA and EFER.LME must be clear.
  if vmcs.exit_controls[9] == 0b1 then {
    // 64-bit host
    if vmcs.host_efer[10] == 0b0 then return false;  // LMA
    if vmcs.host_efer[8] == 0b0 then return false     // LME
  } else {
    // 32-bit host — should not have LMA/LME
    if vmcs.host_efer[10] == 0b1 then return false;
    if vmcs.host_efer[8] == 0b1 then return false
  };

  // Host RIP must be canonical in 64-bit mode
  // (simplified: we trust the host to set valid values)

  true
}

// =========================================================================
// VM Entry (SDM Vol.3C Chapter 27)
//
// Called by VMLAUNCH/VMRESUME. Validates VMCS, loads guest state from
// the current VMCS into architectural registers, enters non-root.
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

  // --- VM-entry checks (SDM Vol.3C Chapter 27) ---
  // Validate control fields, guest state, and host state.
  // On failure, set VM-instruction error and return (VMfailValid).
  if ~(check_vmentry_controls()) then {
    vmx_fail_valid(VMXERR_VMENTRY_INVALID_CTRL);
    return ()
  };
  if ~(check_vmentry_host_state()) then {
    vmx_fail_valid(VMXERR_VMENTRY_INVALID_HOST);
    return ()
  };
  if ~(check_vmentry_guest_state()) then {
    vmx_fail_valid(VMXERR_VMENTRY_INVALID_CTRL);
    return ()
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

  // --- VM-entry MSR load (SDM §27.6) ---
  if unsigned(vmcs.entry_msr_load_count) > 0 then {
    var msr_off : qword = zeros();
    var msr_rem : dword = vmcs.entry_msr_load_count;
    while unsigned(msr_rem) > 0 do {
      let entry_addr : qword = vmcs.entry_msr_load_addr + msr_off;
      let msr_idx : dword = phys_read(entry_addr);
      let msr_val : qword = phys_read(entry_addr + 8);
      match msr_idx {
        0xC0000080 => EFER = msr_val,
        0xC0000100 => SegCache[FS].seg_base = msr_val,
        0xC0000101 => SegCache[GS].seg_base = msr_val,
        0xC0000102 => KERNEL_GS_BASE = msr_val,
        _ => __wrmsr(msr_idx, msr_val),
      };
      msr_off = msr_off + 16;
      msr_rem = msr_rem - 1
    }
  };

  // --- Switch to VMX non-root ---
  in_vmx_non_root = true;
  // Cache EPT-active flag for fast phys_read/phys_write path
  ept_active = vmcs.primary_proc_controls[31] == 0b1
             & vmcs.secondary_proc_controls[1] == 0b1;

  // Mark as launched (for VMRESUME)
  if is_launch then vmcs.launch_state = 0x00000001;

  // --- VM-entry event injection (SDM §27.6) ---
  // If entry_interruption_info[31] (valid) is set, inject the event.
  if vmcs.entry_interruption_info[31] == 0b1 then {
    let inj_vec : exception_vector = unsigned(vmcs.entry_interruption_info[7..0]);
    let inj_type : bits(3) = vmcs.entry_interruption_info[10..8];
    let has_ec : bool = vmcs.entry_interruption_info[11] == 0b1;
    let ec : dword = if has_ec then vmcs.entry_exception_errcode else 0x00000000;
    // Type 3 = hardware exception, type 4 = software interrupt, type 6 = software exception
    let is_sw : bool = inj_type == 0b100 | inj_type == 0b110;
    deliver_exception(inj_vec, ec, is_sw);
    // Clear valid bit after injection
    vmcs.entry_interruption_info = vmcs.entry_interruption_info & 0x7FFFFFFF
  };

  // Set next_rip so step() transfers control to guest RIP
  next_rip = Some(RIP)
}

// =========================================================================
// VM Exit (SDM Vol.3C Chapter 28)
//
// Called when a VM exit occurs. Saves guest state to VMCS, loads host
// state from VMCS, records exit reason and qualification.
// =========================================================================

// Encode segment access rights for VMCS save (SDM §24.4.1):
// Bits 3:0 = type, 4 = S, 6:5 = DPL, 7 = P, 13 = L, 14 = D/B, 15 = G
val encode_seg_access : segreg_idx -> dword
function encode_seg_access(seg) = {
  zero_extend(SegCache[seg].seg_type)
  | (zero_extend(SegCache[seg].seg_s) << 4)
  | (to_bits(32, SegCache[seg].seg_dpl) << 5)
  | (zero_extend(SegCache[seg].seg_present) << 7)
  | (zero_extend(SegCache[seg].seg_l) << 13)
  | (zero_extend(SegCache[seg].seg_db) << 14)
  | (zero_extend(SegCache[seg].seg_g) << 15)
}

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

  // Save segment access rights (SDM §28.3.1.2)
  vmcs.guest_es_access = encode_seg_access(ES);
  vmcs.guest_cs_access = encode_seg_access(CS);
  vmcs.guest_ss_access = encode_seg_access(SS);
  vmcs.guest_ds_access = encode_seg_access(DS);
  vmcs.guest_fs_access = encode_seg_access(FS);
  vmcs.guest_gs_access = encode_seg_access(GS);

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

  // --- VM-exit MSR store (SDM §28.4.2) ---
  // Save guest MSRs listed in the MSR-store area.
  if unsigned(vmcs.exit_msr_store_count) > 0 then {
    var msr_off : qword = zeros();
    var msr_rem : dword = vmcs.exit_msr_store_count;
    while unsigned(msr_rem) > 0 do {
      let entry_addr : qword = vmcs.exit_msr_store_addr + msr_off;
      let msr_idx : dword = phys_read(entry_addr);
      let msr_val : qword = match msr_idx {
        0xC0000080 => EFER,
        0xC0000100 => SegCache[FS].seg_base,
        0xC0000101 => SegCache[GS].seg_base,
        0xC0000102 => KERNEL_GS_BASE,
        _ => __rdmsr(msr_idx),
      };
      phys_write(64, entry_addr + 8, msr_val);
      msr_off = msr_off + 16;
      msr_rem = msr_rem - 1
    }
  };

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

  // --- VM-exit MSR load (SDM §28.5.4) ---
  // Load host MSRs from the MSR-load area.
  if unsigned(vmcs.exit_msr_load_count) > 0 then {
    var msr_off : qword = zeros();
    var msr_rem : dword = vmcs.exit_msr_load_count;
    while unsigned(msr_rem) > 0 do {
      let entry_addr : qword = vmcs.exit_msr_load_addr + msr_off;
      let msr_idx : dword = phys_read(entry_addr);
      let msr_val : qword = phys_read(entry_addr + 8);
      match msr_idx {
        0xC0000080 => EFER = msr_val,
        0xC0000100 => SegCache[FS].seg_base = msr_val,
        0xC0000101 => SegCache[GS].seg_base = msr_val,
        0xC0000102 => KERNEL_GS_BASE = msr_val,
        _ => __wrmsr(msr_idx, msr_val),
      };
      msr_off = msr_off + 16;
      msr_rem = msr_rem - 1
    }
  };

  // --- Return to VMX root operation ---
  in_vmx_non_root = false;
  ept_active = false;
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

// =========================================================================
// Conditional VM-Exit Guards (Phase 3)
//
// Each guard checks in_vmx_non_root and the relevant VMCS control bit.
// If both are set, throws VMExit with the appropriate reason/qualification.
// =========================================================================

// HLT exit: primary_proc_controls bit 7 (SDM §25.1, Table 25-6)
val vmx_exit_if_hlt : unit -> unit
function vmx_exit_if_hlt() = {
  if in_vmx_non_root & vmcs.primary_proc_controls[7] == 0b1 then {
    vmcs.exit_instr_length = (decode_pos - insn_start)[31..0];
    throw VMExit(VMEXIT_HLT, 0x0000000000000000)
  }
}

// INVLPG exit: primary_proc_controls bit 9 (SDM §25.1, Table 25-6)
val vmx_exit_if_invlpg : qword -> unit
function vmx_exit_if_invlpg(linear_addr) = {
  if in_vmx_non_root & vmcs.primary_proc_controls[9] == 0b1 then {
    vmcs.exit_instr_length = (decode_pos - insn_start)[31..0];
    throw VMExit(VMEXIT_INVLPG, linear_addr)
  }
}

// RDTSC exit: primary_proc_controls bit 12 (SDM §25.1, Table 25-6)
val vmx_exit_if_rdtsc : unit -> unit
function vmx_exit_if_rdtsc() = {
  if in_vmx_non_root & vmcs.primary_proc_controls[12] == 0b1 then {
    vmcs.exit_instr_length = (decode_pos - insn_start)[31..0];
    throw VMExit(VMEXIT_RDTSC, 0x0000000000000000)
  }
}

// MSR bitmap helper (SDM §25.1.3):
// Returns true if the bitmap indicates VM exit for the given MSR.
// The 4KB bitmap has 4 regions of 1KB each:
//   0x000: Read bitmap for MSRs 0x00000000–0x00001FFF
//   0x400: Read bitmap for MSRs 0xC0000000–0xC0001FFF
//   0x800: Write bitmap for MSRs 0x00000000–0x00001FFF
//   0xC00: Write bitmap for MSRs 0xC0000000–0xC0001FFF
val vmx_check_msr_bitmap : (dword, bool) -> bool
function vmx_check_msr_bitmap(msr_idx, is_write) = {
  // Determine region base offset and MSR-relative index
  var region_base : qword = zeros();
  var msr_rel : bits(13) = zeros();
  var in_range : bool = false;

  if msr_idx <=_u 0x00001FFF then {
    region_base = if is_write then 0x0000000000000800 else zeros();
    msr_rel = msr_idx[12..0];
    in_range = true
  } else if msr_idx >=_u 0xC0000000 & msr_idx <=_u 0xC0001FFF then {
    region_base = if is_write then 0x0000000000000C00 else 0x0000000000000400;
    msr_rel = msr_idx[12..0];
    in_range = true
  };

  if ~(in_range) then {
    // MSR not covered by bitmap → exit unconditionally
    true
  } else {
    // msr_rel[12:3] = byte offset, msr_rel[2:0] = bit within byte
    let addr : qword = vmcs.msr_bitmap + region_base + zero_extend(msr_rel[12..3]);
    let byte_val : bits(8) = phys_read(addr);
    let bit_in_byte : range(0, 7) = unsigned(msr_rel[2..0]);
    byte_val[bit_in_byte] == 0b1
  }
}

// RDMSR exit: primary_proc_controls bit 28 (use MSR bitmaps) (SDM §25.1)
// If bit 28 = 0, all RDMSR exit unconditionally.
// If bit 28 = 1, consult MSR bitmap for the specific MSR (in ECX).
val vmx_exit_if_rdmsr : unit -> unit
function vmx_exit_if_rdmsr() = {
  if in_vmx_non_root then {
    let should_exit : bool = if vmcs.primary_proc_controls[28] == 0b0 then
      true  // No MSR bitmaps → exit unconditionally
    else
      vmx_check_msr_bitmap(v(RCX), false);
    if should_exit then {
      vmcs.exit_instr_length = (decode_pos - insn_start)[31..0];
      throw VMExit(VMEXIT_RDMSR, 0x0000000000000000)
    }
  }
}

// WRMSR exit: same control bit 28 as RDMSR
val vmx_exit_if_wrmsr : unit -> unit
function vmx_exit_if_wrmsr() = {
  if in_vmx_non_root then {
    let should_exit : bool = if vmcs.primary_proc_controls[28] == 0b0 then
      true
    else
      vmx_check_msr_bitmap(v(RCX), true);
    if should_exit then {
      vmcs.exit_instr_length = (decode_pos - insn_start)[31..0];
      throw VMExit(VMEXIT_WRMSR, 0x0000000000000000)
    }
  }
}

// MOV DR exit: primary_proc_controls bit 23 (SDM §25.1, Table 25-6)
val vmx_exit_if_dr_access : unit -> unit
function vmx_exit_if_dr_access() = {
  if in_vmx_non_root & vmcs.primary_proc_controls[23] == 0b1 then {
    vmcs.exit_instr_length = (decode_pos - insn_start)[31..0];
    throw VMExit(VMEXIT_DR_ACCESS, 0x0000000000000000)
  }
}

// I/O bitmap helper (SDM §25.1.3):
// Bitmap A: ports 0x0000–0x7FFF (at vmcs.io_bitmap_a)
// Bitmap B: ports 0x8000–0xFFFF (at vmcs.io_bitmap_b)
// Returns true if any bit in the range [port, port+size-1] is set.
val vmx_check_io_bitmap : (word, operand_size) -> bool
function vmx_check_io_bitmap(port, size) = {
  let nbytes : bits(3) = match size {
    8  => 0b001,
    16 => 0b010,
    32 => 0b100,
    _  => 0b100,
  };
  var any_set : bool = false;
  foreach (i from 0 to 3) {
    if to_bits(3, i) <_u nbytes then {
      let p : bits(17) = zero_extend(port) + zero_extend(to_bits(3, i));
      if p[16] == 0b0 then {
        let port16 : word = p[15..0];
        let bitmap_base : qword = if port16[15] == 0b0 then vmcs.io_bitmap_a else vmcs.io_bitmap_b;
        // Bit index within the 32K-port region
        let bit_idx : bits(15) = port16[14..0];
        let addr : qword = bitmap_base + zero_extend(bit_idx[14..3]);
        let byte_val : bits(8) = phys_read(addr);
        let bit_in_byte : range(0, 7) = unsigned(bit_idx[2..0]);
        if byte_val[bit_in_byte] == 0b1 then any_set = true
      }
    }
  };
  any_set
}

// I/O exit: primary_proc_controls bit 24 (unconditional I/O exit) or
// bit 25 (use I/O bitmaps). SDM §25.1, Table 25-6.
// If bit 25 = 1, consult I/O bitmap.
// If bit 24 = 1, all IN/OUT exit unconditionally.
val vmx_exit_if_io : (word, operand_size, bool) -> unit
function vmx_exit_if_io(port, size, is_in) = {
  let should_exit : bool =
    if vmcs.primary_proc_controls[25] == 0b1 then
      vmx_check_io_bitmap(port, size)
    else
      vmcs.primary_proc_controls[24] == 0b1;
  if in_vmx_non_root & should_exit then {
    // Qualification: SDM Table 28-5
    // Bits 2:0 = size - 1 (0=byte,1=word,3=dword)
    // Bit 3 = direction (1=IN, 0=OUT)
    // Bit 4 = string (0 for IN/OUT)
    // Bits 31:16 = port number
    let size_enc : qword = match size {
      8  => 0x0000000000000000,
      16 => 0x0000000000000001,
      32 => 0x0000000000000003,
      64 => 0x0000000000000003,
    };
    let dir_bit : qword = if is_in then 0x0000000000000008 else 0x0000000000000000;
    let qual : qword = size_enc | dir_bit | (zero_extend(port) << 16);
    vmcs.exit_instr_length = (decode_pos - insn_start)[31..0];
    throw VMExit(VMEXIT_IO_INSTRUCTION, qual)
  }
}

// PAUSE exit: primary_proc_controls bit 30 (SDM §25.1, Table 25-6)
val vmx_exit_if_pause : unit -> unit
function vmx_exit_if_pause() = {
  if in_vmx_non_root & vmcs.primary_proc_controls[30] == 0b1 then {
    vmcs.exit_instr_length = (decode_pos - insn_start)[31..0];
    throw VMExit(VMEXIT_PAUSE, 0x0000000000000000)
  }
}

// WBINVD exit: secondary_proc_controls bit 6 (SDM §25.1, Table 25-7)
val vmx_exit_if_wbinvd : unit -> unit
function vmx_exit_if_wbinvd() = {
  if in_vmx_non_root then {
    // WBINVD exiting is controlled by secondary proc controls bit 6.
    // But also check activate-secondary (primary bit 31).
    if vmcs.primary_proc_controls[31] == 0b1 & vmcs.secondary_proc_controls[6] == 0b1 then {
      vmcs.exit_instr_length = (decode_pos - insn_start)[31..0];
      throw VMExit(VMEXIT_WBINVD, 0x0000000000000000)
    }
  }
}

// RDTSCP exit: secondary_proc_controls bit 3 (SDM §25.3)
val vmx_exit_if_rdtscp : unit -> unit
function vmx_exit_if_rdtscp() = {
  if in_vmx_non_root then {
    if vmcs.primary_proc_controls[31] == 0b1 & vmcs.secondary_proc_controls[3] == 0b1 then {
      vmcs.exit_instr_length = (decode_pos - insn_start)[31..0];
      throw VMExit(VMEXIT_RDTSCP, 0x0000000000000000)
    }
  }
}

// CR access exit: SDM §25.1 bits 15-16 (CR3-load/store exiting)
// and guest/host masks for CR0/CR4.
// Simplified: CR0/CR4 writes that change bits in the guest/host mask
// cause VM exit. CR3 exits are controlled by bits 15-16.
val vmx_exit_if_cr_write : (range(0, 15), qword) -> unit
function vmx_exit_if_cr_write(cr_idx, new_val) = {
  if in_vmx_non_root then {
    let should_exit : bool = match cr_idx {
      // CR0: exit if changing any bit in guest/host mask
      0 => (new_val & vmcs.cr0_guest_host_mask) != (CR0 & vmcs.cr0_guest_host_mask),
      // CR3: exit if bit 15 set and new value doesn't match any target
      3 => vmcs.primary_proc_controls[15] == 0b1,
      // CR4: exit if changing any bit in guest/host mask
      4 => (new_val & vmcs.cr4_guest_host_mask) != (CR4 & vmcs.cr4_guest_host_mask),
      _ => false,
    };
    if should_exit then {
      // Qualification: SDM Table 28-3
      // Bits 3:0 = CR number, Bits 5:4 = access type (0=MOV to CR),
      // Bits 11:8 = source register
      let qual : qword = zero_extend(to_bits(4, cr_idx));
      vmcs.exit_instr_length = (decode_pos - insn_start)[31..0];
      throw VMExit(VMEXIT_CR_ACCESS, qual)
    }
  }
}

// CR read: for CR0/CR4, return shadow value for masked bits (SDM §26.1.3).
// Returns true if the read was handled (caller should use returned value),
// false if no VMX interception needed.
val vmx_cr_read_shadow : range(0, 15) -> option(qword)
function vmx_cr_read_shadow(cr_idx) = {
  if in_vmx_non_root then {
    match cr_idx {
      0 => Some((CR0 & ~(vmcs.cr0_guest_host_mask)) | (vmcs.cr0_read_shadow & vmcs.cr0_guest_host_mask)),
      4 => Some((CR4 & ~(vmcs.cr4_guest_host_mask)) | (vmcs.cr4_read_shadow & vmcs.cr4_guest_host_mask)),
      _ => None(),
    }
  } else {
    None()
  }
}

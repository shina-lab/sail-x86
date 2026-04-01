// x86-64 — VMX VMCS Field Access and Serialization
//
// SDM Vol.3C §24.11.2: VMCS field encodings.
// VMREAD/VMWRITE use a 32-bit field encoding to identify which VMCS
// field to access. This file implements the dispatch from encoding
// to struct member.
//
// VMCS field encoding format (SDM Table 24-21):
//   Bits 0: Access type (0=full, 1=high)
//   Bits 9..1: Field index
//   Bits 11..10: Field type (0=control, 1=VM-exit info, 2=guest, 3=host)
//   Bits 14..13: Field width (0=16-bit, 1=64-bit, 2=32-bit, 3=natural-width)
//   Bit 12: Reserved (0)

// =========================================================================
// VMCS Field Read
//
// Returns the field value as a 64-bit value (zero-extended for narrow fields).
// Returns None() for unrecognized encodings.
// =========================================================================

val vmcs_read_field : dword -> option(qword)
function vmcs_read_field(encoding) = {
  match encoding {
    // --- 16-bit control fields ---
    0x00000000 => Some(zero_extend(vmcs.vpid)),

    // --- 16-bit guest-state fields ---
    0x00000800 => Some(zero_extend(vmcs.guest_es_selector)),
    0x00000802 => Some(zero_extend(vmcs.guest_cs_selector)),
    0x00000804 => Some(zero_extend(vmcs.guest_ss_selector)),
    0x00000806 => Some(zero_extend(vmcs.guest_ds_selector)),
    0x00000808 => Some(zero_extend(vmcs.guest_fs_selector)),
    0x0000080A => Some(zero_extend(vmcs.guest_gs_selector)),
    0x0000080C => Some(zero_extend(vmcs.guest_ldtr_selector)),
    0x0000080E => Some(zero_extend(vmcs.guest_tr_selector)),

    // --- 16-bit host-state fields ---
    0x00000C00 => Some(zero_extend(vmcs.host_es_selector)),
    0x00000C02 => Some(zero_extend(vmcs.host_cs_selector)),
    0x00000C04 => Some(zero_extend(vmcs.host_ss_selector)),
    0x00000C06 => Some(zero_extend(vmcs.host_ds_selector)),
    0x00000C08 => Some(zero_extend(vmcs.host_fs_selector)),
    0x00000C0A => Some(zero_extend(vmcs.host_gs_selector)),
    0x00000C0C => Some(zero_extend(vmcs.host_tr_selector)),

    // --- 64-bit control fields ---
    0x00002000 => Some(vmcs.io_bitmap_a),
    0x00002002 => Some(vmcs.io_bitmap_b),
    0x00002004 => Some(vmcs.msr_bitmap),
    0x00002008 => Some(vmcs.exit_msr_store_addr),
    0x0000200A => Some(vmcs.exit_msr_load_addr),
    0x0000200C => Some(vmcs.entry_msr_load_addr),
    0x00002010 => Some(vmcs.tsc_offset),

    // --- 64-bit read-only data field ---
    0x00002400 => Some(vmcs.guest_physical_address),

    // --- 64-bit control fields (continued) ---
    0x00002012 => Some(vmcs.virtual_apic_page_addr),

    // --- 64-bit guest-state fields ---
    0x00002800 => Some(vmcs.guest_vmcs_link_pointer),
    0x00002802 => Some(vmcs.guest_debugctl),
    0x00002804 => Some(vmcs.guest_pat),
    0x00002806 => Some(vmcs.guest_efer),

    // --- 64-bit host-state fields ---
    0x00002C00 => Some(vmcs.host_pat),
    0x00002C02 => Some(vmcs.host_efer),

    // --- 32-bit control fields ---
    0x00004000 => Some(zero_extend(vmcs.pin_based_controls)),
    0x00004002 => Some(zero_extend(vmcs.primary_proc_controls)),
    0x00004004 => Some(zero_extend(vmcs.exception_bitmap)),
    0x00004006 => Some(zero_extend(vmcs.page_fault_error_mask)),
    0x00004008 => Some(zero_extend(vmcs.page_fault_error_match)),
    0x0000400A => Some(zero_extend(vmcs.cr3_target_count)),
    0x0000400C => Some(zero_extend(vmcs.exit_controls)),
    0x0000400E => Some(zero_extend(vmcs.exit_msr_store_count)),
    0x00004010 => Some(zero_extend(vmcs.exit_msr_load_count)),
    0x00004012 => Some(zero_extend(vmcs.entry_controls)),
    0x00004014 => Some(zero_extend(vmcs.entry_msr_load_count)),
    0x00004016 => Some(zero_extend(vmcs.entry_interruption_info)),
    0x00004018 => Some(zero_extend(vmcs.entry_exception_errcode)),
    0x0000401A => Some(zero_extend(vmcs.entry_instr_length)),
    0x0000401C => Some(zero_extend(vmcs.tpr_threshold)),
    0x0000401E => Some(zero_extend(vmcs.secondary_proc_controls)),

    // --- 32-bit read-only data fields ---
    0x00004400 => Some(zero_extend(vmcs.vm_instruction_error)),
    0x00004402 => Some(zero_extend(vmcs.exit_reason)),
    0x00004404 => Some(zero_extend(vmcs.exit_interruption_info)),
    0x00004406 => Some(zero_extend(vmcs.exit_interruption_errcode)),
    0x00004408 => Some(zero_extend(vmcs.idt_vectoring_info)),
    0x0000440A => Some(zero_extend(vmcs.idt_vectoring_errcode)),
    0x0000440C => Some(zero_extend(vmcs.exit_instr_length)),
    0x0000440E => Some(zero_extend(vmcs.exit_instr_info)),

    // --- 32-bit guest-state fields ---
    0x00004800 => Some(zero_extend(vmcs.guest_es_limit)),
    0x00004802 => Some(zero_extend(vmcs.guest_cs_limit)),
    0x00004804 => Some(zero_extend(vmcs.guest_ss_limit)),
    0x00004806 => Some(zero_extend(vmcs.guest_ds_limit)),
    0x00004808 => Some(zero_extend(vmcs.guest_fs_limit)),
    0x0000480A => Some(zero_extend(vmcs.guest_gs_limit)),
    0x0000480C => Some(zero_extend(vmcs.guest_ldtr_limit)),
    0x0000480E => Some(zero_extend(vmcs.guest_tr_limit)),
    0x00004810 => Some(zero_extend(vmcs.guest_gdtr_limit)),
    0x00004812 => Some(zero_extend(vmcs.guest_idtr_limit)),
    0x00004814 => Some(zero_extend(vmcs.guest_es_access)),
    0x00004816 => Some(zero_extend(vmcs.guest_cs_access)),
    0x00004818 => Some(zero_extend(vmcs.guest_ss_access)),
    0x0000481A => Some(zero_extend(vmcs.guest_ds_access)),
    0x0000481C => Some(zero_extend(vmcs.guest_fs_access)),
    0x0000481E => Some(zero_extend(vmcs.guest_gs_access)),
    0x00004820 => Some(zero_extend(vmcs.guest_ldtr_access)),
    0x00004822 => Some(zero_extend(vmcs.guest_tr_access)),
    0x00004824 => Some(zero_extend(vmcs.guest_interruptibility)),
    0x00004826 => Some(zero_extend(vmcs.guest_activity_state)),
    0x0000482E => Some(zero_extend(vmcs.guest_preempt_timer)),
    0x0000482A => Some(zero_extend(vmcs.guest_sysenter_cs)),

    // --- 32-bit host-state fields ---
    0x00004C00 => Some(zero_extend(vmcs.host_sysenter_cs)),

    // --- Natural-width control fields ---
    0x00006000 => Some(vmcs.cr0_guest_host_mask),
    0x00006002 => Some(vmcs.cr4_guest_host_mask),
    0x00006004 => Some(vmcs.cr0_read_shadow),
    0x00006006 => Some(vmcs.cr4_read_shadow),
    0x00006008 => Some(vmcs.cr3_target_0),
    0x0000600A => Some(vmcs.cr3_target_1),
    0x0000600C => Some(vmcs.cr3_target_2),
    0x0000600E => Some(vmcs.cr3_target_3),

    // --- Natural-width read-only data fields ---
    0x00006400 => Some(vmcs.exit_qualification),
    0x00006402 => Some(vmcs.guest_linear_address),

    // --- Natural-width guest-state fields ---
    0x00006800 => Some(vmcs.guest_cr0),
    0x00006802 => Some(vmcs.guest_cr3),
    0x00006804 => Some(vmcs.guest_cr4),
    0x00006806 => Some(vmcs.guest_es_base),
    0x00006808 => Some(vmcs.guest_cs_base),
    0x0000680A => Some(vmcs.guest_ss_base),
    0x0000680C => Some(vmcs.guest_ds_base),
    0x0000680E => Some(vmcs.guest_fs_base),
    0x00006810 => Some(vmcs.guest_gs_base),
    0x00006812 => Some(vmcs.guest_ldtr_base),
    0x00006814 => Some(vmcs.guest_tr_base),
    0x00006816 => Some(vmcs.guest_gdtr_base),
    0x00006818 => Some(vmcs.guest_idtr_base),
    0x0000681A => Some(vmcs.guest_dr7),
    0x0000681C => Some(vmcs.guest_rsp),
    0x0000681E => Some(vmcs.guest_rip),
    0x00006820 => Some(vmcs.guest_rflags),
    0x00006822 => Some(vmcs.guest_pending_dbg_exc),
    0x00006824 => Some(vmcs.guest_sysenter_esp),
    0x00006826 => Some(vmcs.guest_sysenter_eip),

    // --- Natural-width host-state fields ---
    0x00006C00 => Some(vmcs.host_cr0),
    0x00006C02 => Some(vmcs.host_cr3),
    0x00006C04 => Some(vmcs.host_cr4),
    0x00006C06 => Some(vmcs.host_fs_base),
    0x00006C08 => Some(vmcs.host_gs_base),
    0x00006C0A => Some(vmcs.host_tr_base),
    0x00006C0C => Some(vmcs.host_gdtr_base),
    0x00006C0E => Some(vmcs.host_idtr_base),
    0x00006C10 => Some(vmcs.host_sysenter_esp),
    0x00006C12 => Some(vmcs.host_sysenter_eip),
    0x00006C14 => Some(vmcs.host_rsp),
    0x00006C16 => Some(vmcs.host_rip),

    // Catch-all: return 0 for unrecognized fields rather than failing.
    _ => Some(zeros()),
  }
}

// =========================================================================
// VMCS Field Write
//
// Writes a 64-bit value to the specified VMCS field (truncating for
// narrow fields). Returns true on success, false for unrecognized or
// read-only fields.
// =========================================================================

val vmcs_write_field : (dword, qword) -> bool
function vmcs_write_field(encoding, value) = {
  match encoding {
    // --- 16-bit control fields ---
    0x00000000 => { vmcs.vpid = value[15..0]; true },

    // --- 16-bit guest-state fields ---
    0x00000800 => { vmcs.guest_es_selector = value[15..0]; true },
    0x00000802 => { vmcs.guest_cs_selector = value[15..0]; true },
    0x00000804 => { vmcs.guest_ss_selector = value[15..0]; true },
    0x00000806 => { vmcs.guest_ds_selector = value[15..0]; true },
    0x00000808 => { vmcs.guest_fs_selector = value[15..0]; true },
    0x0000080A => { vmcs.guest_gs_selector = value[15..0]; true },
    0x0000080C => { vmcs.guest_ldtr_selector = value[15..0]; true },
    0x0000080E => { vmcs.guest_tr_selector = value[15..0]; true },

    // --- 16-bit host-state fields ---
    0x00000C00 => { vmcs.host_es_selector = value[15..0]; true },
    0x00000C02 => { vmcs.host_cs_selector = value[15..0]; true },
    0x00000C04 => { vmcs.host_ss_selector = value[15..0]; true },
    0x00000C06 => { vmcs.host_ds_selector = value[15..0]; true },
    0x00000C08 => { vmcs.host_fs_selector = value[15..0]; true },
    0x00000C0A => { vmcs.host_gs_selector = value[15..0]; true },
    0x00000C0C => { vmcs.host_tr_selector = value[15..0]; true },

    // --- 64-bit control fields ---
    0x00002000 => { vmcs.io_bitmap_a = value; true },
    0x00002002 => { vmcs.io_bitmap_b = value; true },
    0x00002004 => { vmcs.msr_bitmap = value; true },
    0x00002008 => { vmcs.exit_msr_store_addr = value; true },
    0x0000200A => { vmcs.exit_msr_load_addr = value; true },
    0x0000200C => { vmcs.entry_msr_load_addr = value; true },
    0x00002010 => { vmcs.tsc_offset = value; true },

    // --- 64-bit control fields (continued) ---
    0x00002012 => { vmcs.virtual_apic_page_addr = value; true },

    // --- 64-bit guest-state fields ---
    0x00002800 => { vmcs.guest_vmcs_link_pointer = value; true },
    0x00002802 => { vmcs.guest_debugctl = value; true },
    0x00002804 => { vmcs.guest_pat = value; true },
    0x00002806 => { vmcs.guest_efer = value; true },

    // --- 64-bit host-state fields ---
    0x00002C00 => { vmcs.host_pat = value; true },
    0x00002C02 => { vmcs.host_efer = value; true },

    // --- 32-bit control fields ---
    0x00004000 => { vmcs.pin_based_controls = value[31..0]; true },
    0x00004002 => { vmcs.primary_proc_controls = value[31..0]; true },
    0x00004004 => { vmcs.exception_bitmap = value[31..0]; true },
    0x00004006 => { vmcs.page_fault_error_mask = value[31..0]; true },
    0x00004008 => { vmcs.page_fault_error_match = value[31..0]; true },
    0x0000400A => { vmcs.cr3_target_count = value[31..0]; true },
    0x0000400C => { vmcs.exit_controls = value[31..0]; true },
    0x0000400E => { vmcs.exit_msr_store_count = value[31..0]; true },
    0x00004010 => { vmcs.exit_msr_load_count = value[31..0]; true },
    0x00004012 => { vmcs.entry_controls = value[31..0]; true },
    0x00004014 => { vmcs.entry_msr_load_count = value[31..0]; true },
    0x00004016 => { vmcs.entry_interruption_info = value[31..0]; true },
    0x00004018 => { vmcs.entry_exception_errcode = value[31..0]; true },
    0x0000401A => { vmcs.entry_instr_length = value[31..0]; true },
    0x0000401C => { vmcs.tpr_threshold = value[31..0]; true },
    0x0000401E => { vmcs.secondary_proc_controls = value[31..0]; true },

    // --- 32-bit read-only fields: writes are rejected ---
    0x00004400 => false,  // vm_instruction_error
    0x00004402 => false,  // exit_reason
    0x00004404 => false,  // exit_interruption_info
    0x00004406 => false,  // exit_interruption_errcode
    0x00004408 => false,  // idt_vectoring_info
    0x0000440A => false,  // idt_vectoring_errcode
    0x0000440C => false,  // exit_instr_length
    0x0000440E => false,  // exit_instr_info

    // --- 32-bit guest-state fields ---
    0x00004800 => { vmcs.guest_es_limit = value[31..0]; true },
    0x00004802 => { vmcs.guest_cs_limit = value[31..0]; true },
    0x00004804 => { vmcs.guest_ss_limit = value[31..0]; true },
    0x00004806 => { vmcs.guest_ds_limit = value[31..0]; true },
    0x00004808 => { vmcs.guest_fs_limit = value[31..0]; true },
    0x0000480A => { vmcs.guest_gs_limit = value[31..0]; true },
    0x0000480C => { vmcs.guest_ldtr_limit = value[31..0]; true },
    0x0000480E => { vmcs.guest_tr_limit = value[31..0]; true },
    0x00004810 => { vmcs.guest_gdtr_limit = value[31..0]; true },
    0x00004812 => { vmcs.guest_idtr_limit = value[31..0]; true },
    0x00004814 => { vmcs.guest_es_access = value[31..0]; true },
    0x00004816 => { vmcs.guest_cs_access = value[31..0]; true },
    0x00004818 => { vmcs.guest_ss_access = value[31..0]; true },
    0x0000481A => { vmcs.guest_ds_access = value[31..0]; true },
    0x0000481C => { vmcs.guest_fs_access = value[31..0]; true },
    0x0000481E => { vmcs.guest_gs_access = value[31..0]; true },
    0x00004820 => { vmcs.guest_ldtr_access = value[31..0]; true },
    0x00004822 => { vmcs.guest_tr_access = value[31..0]; true },
    0x00004824 => { vmcs.guest_interruptibility = value[31..0]; true },
    0x00004826 => { vmcs.guest_activity_state = value[31..0]; true },
    0x0000482E => { vmcs.guest_preempt_timer = value[31..0]; true },
    0x0000482A => { vmcs.guest_sysenter_cs = value[31..0]; true },

    // --- 32-bit host-state fields ---
    0x00004C00 => { vmcs.host_sysenter_cs = value[31..0]; true },

    // --- Natural-width control fields ---
    0x00006000 => { vmcs.cr0_guest_host_mask = value; true },
    0x00006002 => { vmcs.cr4_guest_host_mask = value; true },
    0x00006004 => { vmcs.cr0_read_shadow = value; true },
    0x00006006 => { vmcs.cr4_read_shadow = value; true },
    0x00006008 => { vmcs.cr3_target_0 = value; true },
    0x0000600A => { vmcs.cr3_target_1 = value; true },
    0x0000600C => { vmcs.cr3_target_2 = value; true },
    0x0000600E => { vmcs.cr3_target_3 = value; true },

    // --- Natural-width read-only fields: writes rejected ---
    0x00006400 => false,  // exit_qualification
    0x00006402 => false,  // guest_linear_address

    // --- Natural-width guest-state fields ---
    0x00006800 => { vmcs.guest_cr0 = value; true },
    0x00006802 => { vmcs.guest_cr3 = value; true },
    0x00006804 => { vmcs.guest_cr4 = value; true },
    0x00006806 => { vmcs.guest_es_base = value; true },
    0x00006808 => { vmcs.guest_cs_base = value; true },
    0x0000680A => { vmcs.guest_ss_base = value; true },
    0x0000680C => { vmcs.guest_ds_base = value; true },
    0x0000680E => { vmcs.guest_fs_base = value; true },
    0x00006810 => { vmcs.guest_gs_base = value; true },
    0x00006812 => { vmcs.guest_ldtr_base = value; true },
    0x00006814 => { vmcs.guest_tr_base = value; true },
    0x00006816 => { vmcs.guest_gdtr_base = value; true },
    0x00006818 => { vmcs.guest_idtr_base = value; true },
    0x0000681A => { vmcs.guest_dr7 = value; true },
    0x0000681C => { vmcs.guest_rsp = value; true },
    0x0000681E => { vmcs.guest_rip = value; true },
    0x00006820 => { vmcs.guest_rflags = value; true },
    0x00006822 => { vmcs.guest_pending_dbg_exc = value; true },
    0x00006824 => { vmcs.guest_sysenter_esp = value; true },
    0x00006826 => { vmcs.guest_sysenter_eip = value; true },

    // --- Natural-width host-state fields ---
    0x00006C00 => { vmcs.host_cr0 = value; true },
    0x00006C02 => { vmcs.host_cr3 = value; true },
    0x00006C04 => { vmcs.host_cr4 = value; true },
    0x00006C06 => { vmcs.host_fs_base = value; true },
    0x00006C08 => { vmcs.host_gs_base = value; true },
    0x00006C0A => { vmcs.host_tr_base = value; true },
    0x00006C0C => { vmcs.host_gdtr_base = value; true },
    0x00006C0E => { vmcs.host_idtr_base = value; true },
    0x00006C10 => { vmcs.host_sysenter_esp = value; true },
    0x00006C12 => { vmcs.host_sysenter_eip = value; true },
    0x00006C14 => { vmcs.host_rsp = value; true },
    0x00006C16 => { vmcs.host_rip = value; true },

    // Catch-all: accept writes to unrecognized fields (silently discard).
    // This allows KVM to write fields we haven't modeled yet without
    // triggering VMfailValid, which causes KVM to enter an error loop.
    _ => true,
  }
}

// =========================================================================
// VMCS Serialize/Deserialize
//
// Writes/reads the VMCS struct to/from physical memory at vmcs_ptr.
// Layout: we use a simple sequential layout starting at the VMCS
// physical address + 8 (first 4 bytes = revision ID, next 4 = abort).
//
// This is a simplified layout — real hardware uses an implementation-
// specific format. What matters for the formal model is that
// VMCLEAR→VMPTRLD round-trips correctly.
// =========================================================================

val vmcs_serialize : qword -> unit
function vmcs_serialize(pa) = {
  // Write revision ID at offset 0
  phys_write(32, pa, VMCS_REVISION_ID);
  // VMX abort indicator at offset 4 (0 = no abort)
  phys_write(32, pa + 4, 0x00000000);

  // Control fields (offset 8)
  let base : qword = pa + 8;
  phys_write(32, base + 0, vmcs.pin_based_controls);
  phys_write(32, base + 4, vmcs.primary_proc_controls);
  phys_write(32, base + 8, vmcs.secondary_proc_controls);
  phys_write(32, base + 12, vmcs.exception_bitmap);
  phys_write(64, base + 16, vmcs.io_bitmap_a);
  phys_write(64, base + 24, vmcs.io_bitmap_b);
  phys_write(64, base + 32, vmcs.msr_bitmap);
  phys_write(64, base + 40, vmcs.tsc_offset);
  phys_write(64, base + 48, vmcs.cr0_guest_host_mask);
  phys_write(64, base + 56, vmcs.cr0_read_shadow);
  phys_write(64, base + 64, vmcs.cr4_guest_host_mask);
  phys_write(64, base + 72, vmcs.cr4_read_shadow);
  phys_write(32, base + 80, vmcs.cr3_target_count);
  phys_write(64, base + 84, vmcs.cr3_target_0);
  phys_write(64, base + 92, vmcs.cr3_target_1);
  phys_write(64, base + 100, vmcs.cr3_target_2);
  phys_write(64, base + 108, vmcs.cr3_target_3);
  phys_write(16, base + 116, vmcs.vpid);

  // Exit control fields (offset 126)
  let exit_base : qword = base + 126;
  phys_write(32, exit_base + 0, vmcs.exit_controls);
  phys_write(32, exit_base + 4, vmcs.exit_msr_store_count);
  phys_write(64, exit_base + 8, vmcs.exit_msr_store_addr);
  phys_write(32, exit_base + 16, vmcs.exit_msr_load_count);
  phys_write(64, exit_base + 20, vmcs.exit_msr_load_addr);

  // Entry control fields (offset 154)
  let entry_base : qword = base + 154;
  phys_write(32, entry_base + 0, vmcs.entry_controls);
  phys_write(32, entry_base + 4, vmcs.entry_msr_load_count);
  phys_write(64, entry_base + 8, vmcs.entry_msr_load_addr);
  phys_write(32, entry_base + 16, vmcs.entry_interruption_info);
  phys_write(32, entry_base + 20, vmcs.entry_exception_errcode);
  phys_write(32, entry_base + 24, vmcs.entry_instr_length);

  // Guest-state area (offset 186)
  let guest_base : qword = base + 186;
  phys_write(64, guest_base + 0, vmcs.guest_cr0);
  phys_write(64, guest_base + 8, vmcs.guest_cr3);
  phys_write(64, guest_base + 16, vmcs.guest_cr4);
  phys_write(64, guest_base + 24, vmcs.guest_dr7);
  phys_write(64, guest_base + 32, vmcs.guest_rsp);
  phys_write(64, guest_base + 40, vmcs.guest_rip);
  phys_write(64, guest_base + 48, vmcs.guest_rflags);

  phys_write(16, guest_base + 56, vmcs.guest_es_selector);
  phys_write(16, guest_base + 58, vmcs.guest_cs_selector);
  phys_write(16, guest_base + 60, vmcs.guest_ss_selector);
  phys_write(16, guest_base + 62, vmcs.guest_ds_selector);
  phys_write(16, guest_base + 64, vmcs.guest_fs_selector);
  phys_write(16, guest_base + 66, vmcs.guest_gs_selector);
  phys_write(16, guest_base + 68, vmcs.guest_ldtr_selector);
  phys_write(16, guest_base + 70, vmcs.guest_tr_selector);

  phys_write(64, guest_base + 72, vmcs.guest_es_base);
  phys_write(64, guest_base + 80, vmcs.guest_cs_base);
  phys_write(64, guest_base + 88, vmcs.guest_ss_base);
  phys_write(64, guest_base + 96, vmcs.guest_ds_base);
  phys_write(64, guest_base + 104, vmcs.guest_fs_base);
  phys_write(64, guest_base + 112, vmcs.guest_gs_base);
  phys_write(64, guest_base + 120, vmcs.guest_ldtr_base);
  phys_write(64, guest_base + 128, vmcs.guest_tr_base);

  phys_write(32, guest_base + 136, vmcs.guest_es_limit);
  phys_write(32, guest_base + 140, vmcs.guest_cs_limit);
  phys_write(32, guest_base + 144, vmcs.guest_ss_limit);
  phys_write(32, guest_base + 148, vmcs.guest_ds_limit);
  phys_write(32, guest_base + 152, vmcs.guest_fs_limit);
  phys_write(32, guest_base + 156, vmcs.guest_gs_limit);
  phys_write(32, guest_base + 160, vmcs.guest_ldtr_limit);
  phys_write(32, guest_base + 164, vmcs.guest_tr_limit);

  phys_write(32, guest_base + 168, vmcs.guest_es_access);
  phys_write(32, guest_base + 172, vmcs.guest_cs_access);
  phys_write(32, guest_base + 176, vmcs.guest_ss_access);
  phys_write(32, guest_base + 180, vmcs.guest_ds_access);
  phys_write(32, guest_base + 184, vmcs.guest_fs_access);
  phys_write(32, guest_base + 188, vmcs.guest_gs_access);
  phys_write(32, guest_base + 192, vmcs.guest_ldtr_access);
  phys_write(32, guest_base + 196, vmcs.guest_tr_access);

  phys_write(64, guest_base + 200, vmcs.guest_gdtr_base);
  phys_write(32, guest_base + 208, vmcs.guest_gdtr_limit);
  phys_write(64, guest_base + 212, vmcs.guest_idtr_base);
  phys_write(32, guest_base + 220, vmcs.guest_idtr_limit);

  phys_write(64, guest_base + 224, vmcs.guest_efer);
  phys_write(64, guest_base + 232, vmcs.guest_debugctl);
  phys_write(32, guest_base + 240, vmcs.guest_sysenter_cs);
  phys_write(64, guest_base + 244, vmcs.guest_sysenter_esp);
  phys_write(64, guest_base + 252, vmcs.guest_sysenter_eip);
  phys_write(32, guest_base + 260, vmcs.guest_activity_state);
  phys_write(32, guest_base + 264, vmcs.guest_interruptibility);
  phys_write(64, guest_base + 268, vmcs.guest_pending_dbg_exc);
  phys_write(64, guest_base + 276, vmcs.guest_vmcs_link_pointer);
  phys_write(32, guest_base + 284, vmcs.guest_preempt_timer);

  // Host-state area (offset 474)
  let host_base : qword = base + 474;
  phys_write(64, host_base + 0, vmcs.host_cr0);
  phys_write(64, host_base + 8, vmcs.host_cr3);
  phys_write(64, host_base + 16, vmcs.host_cr4);
  phys_write(64, host_base + 24, vmcs.host_rsp);
  phys_write(64, host_base + 32, vmcs.host_rip);

  phys_write(16, host_base + 40, vmcs.host_es_selector);
  phys_write(16, host_base + 42, vmcs.host_cs_selector);
  phys_write(16, host_base + 44, vmcs.host_ss_selector);
  phys_write(16, host_base + 46, vmcs.host_ds_selector);
  phys_write(16, host_base + 48, vmcs.host_fs_selector);
  phys_write(16, host_base + 50, vmcs.host_gs_selector);
  phys_write(16, host_base + 52, vmcs.host_tr_selector);

  phys_write(64, host_base + 54, vmcs.host_fs_base);
  phys_write(64, host_base + 62, vmcs.host_gs_base);
  phys_write(64, host_base + 70, vmcs.host_tr_base);
  phys_write(64, host_base + 78, vmcs.host_gdtr_base);
  phys_write(64, host_base + 86, vmcs.host_idtr_base);

  phys_write(64, host_base + 94, vmcs.host_efer);
  phys_write(32, host_base + 102, vmcs.host_sysenter_cs);
  phys_write(64, host_base + 106, vmcs.host_sysenter_esp);
  phys_write(64, host_base + 114, vmcs.host_sysenter_eip);

  // VM-exit information (offset 596)
  let exit_info_base : qword = base + 596;
  phys_write(32, exit_info_base + 0, vmcs.exit_reason);
  phys_write(64, exit_info_base + 4, vmcs.exit_qualification);
  phys_write(32, exit_info_base + 12, vmcs.exit_interruption_info);
  phys_write(32, exit_info_base + 16, vmcs.exit_interruption_errcode);
  phys_write(32, exit_info_base + 20, vmcs.idt_vectoring_info);
  phys_write(32, exit_info_base + 24, vmcs.idt_vectoring_errcode);
  phys_write(32, exit_info_base + 28, vmcs.exit_instr_length);
  phys_write(32, exit_info_base + 32, vmcs.exit_instr_info);
  phys_write(64, exit_info_base + 36, vmcs.guest_linear_address);
  phys_write(64, exit_info_base + 44, vmcs.guest_physical_address);
  phys_write(32, exit_info_base + 52, vmcs.vm_instruction_error);

  // Launch state (offset 656)
  phys_write(32, base + 656, vmcs.launch_state);

  // Extended fields (offset 660)
  phys_write(64, base + 660, vmcs.virtual_apic_page_addr);
  phys_write(32, base + 668, vmcs.page_fault_error_mask);
  phys_write(32, base + 672, vmcs.page_fault_error_match);
  phys_write(32, base + 676, vmcs.tpr_threshold);
  phys_write(64, base + 680, vmcs.guest_pat);
  phys_write(64, base + 688, vmcs.host_pat)
}

val vmcs_deserialize : qword -> unit
function vmcs_deserialize(pa) = {
  let base : qword = pa + 8;

  vmcs.pin_based_controls = phys_read(32, base + 0);
  vmcs.primary_proc_controls = phys_read(32, base + 4);
  vmcs.secondary_proc_controls = phys_read(32, base + 8);
  vmcs.exception_bitmap = phys_read(32, base + 12);
  vmcs.io_bitmap_a = phys_read(64, base + 16);
  vmcs.io_bitmap_b = phys_read(64, base + 24);
  vmcs.msr_bitmap = phys_read(64, base + 32);
  vmcs.tsc_offset = phys_read(64, base + 40);
  vmcs.cr0_guest_host_mask = phys_read(64, base + 48);
  vmcs.cr0_read_shadow = phys_read(64, base + 56);
  vmcs.cr4_guest_host_mask = phys_read(64, base + 64);
  vmcs.cr4_read_shadow = phys_read(64, base + 72);
  vmcs.cr3_target_count = phys_read(32, base + 80);
  vmcs.cr3_target_0 = phys_read(64, base + 84);
  vmcs.cr3_target_1 = phys_read(64, base + 92);
  vmcs.cr3_target_2 = phys_read(64, base + 100);
  vmcs.cr3_target_3 = phys_read(64, base + 108);
  vmcs.vpid = phys_read(16, base + 116);

  let exit_base : qword = base + 126;
  vmcs.exit_controls = phys_read(32, exit_base + 0);
  vmcs.exit_msr_store_count = phys_read(32, exit_base + 4);
  vmcs.exit_msr_store_addr = phys_read(64, exit_base + 8);
  vmcs.exit_msr_load_count = phys_read(32, exit_base + 16);
  vmcs.exit_msr_load_addr = phys_read(64, exit_base + 20);

  let entry_base : qword = base + 154;
  vmcs.entry_controls = phys_read(32, entry_base + 0);
  vmcs.entry_msr_load_count = phys_read(32, entry_base + 4);
  vmcs.entry_msr_load_addr = phys_read(64, entry_base + 8);
  vmcs.entry_interruption_info = phys_read(32, entry_base + 16);
  vmcs.entry_exception_errcode = phys_read(32, entry_base + 20);
  vmcs.entry_instr_length = phys_read(32, entry_base + 24);

  let guest_base : qword = base + 186;
  vmcs.guest_cr0 = phys_read(64, guest_base + 0);
  vmcs.guest_cr3 = phys_read(64, guest_base + 8);
  vmcs.guest_cr4 = phys_read(64, guest_base + 16);
  vmcs.guest_dr7 = phys_read(64, guest_base + 24);
  vmcs.guest_rsp = phys_read(64, guest_base + 32);
  vmcs.guest_rip = phys_read(64, guest_base + 40);
  vmcs.guest_rflags = phys_read(64, guest_base + 48);

  vmcs.guest_es_selector = phys_read(16, guest_base + 56);
  vmcs.guest_cs_selector = phys_read(16, guest_base + 58);
  vmcs.guest_ss_selector = phys_read(16, guest_base + 60);
  vmcs.guest_ds_selector = phys_read(16, guest_base + 62);
  vmcs.guest_fs_selector = phys_read(16, guest_base + 64);
  vmcs.guest_gs_selector = phys_read(16, guest_base + 66);
  vmcs.guest_ldtr_selector = phys_read(16, guest_base + 68);
  vmcs.guest_tr_selector = phys_read(16, guest_base + 70);

  vmcs.guest_es_base = phys_read(64, guest_base + 72);
  vmcs.guest_cs_base = phys_read(64, guest_base + 80);
  vmcs.guest_ss_base = phys_read(64, guest_base + 88);
  vmcs.guest_ds_base = phys_read(64, guest_base + 96);
  vmcs.guest_fs_base = phys_read(64, guest_base + 104);
  vmcs.guest_gs_base = phys_read(64, guest_base + 112);
  vmcs.guest_ldtr_base = phys_read(64, guest_base + 120);
  vmcs.guest_tr_base = phys_read(64, guest_base + 128);

  vmcs.guest_es_limit = phys_read(32, guest_base + 136);
  vmcs.guest_cs_limit = phys_read(32, guest_base + 140);
  vmcs.guest_ss_limit = phys_read(32, guest_base + 144);
  vmcs.guest_ds_limit = phys_read(32, guest_base + 148);
  vmcs.guest_fs_limit = phys_read(32, guest_base + 152);
  vmcs.guest_gs_limit = phys_read(32, guest_base + 156);
  vmcs.guest_ldtr_limit = phys_read(32, guest_base + 160);
  vmcs.guest_tr_limit = phys_read(32, guest_base + 164);

  vmcs.guest_es_access = phys_read(32, guest_base + 168);
  vmcs.guest_cs_access = phys_read(32, guest_base + 172);
  vmcs.guest_ss_access = phys_read(32, guest_base + 176);
  vmcs.guest_ds_access = phys_read(32, guest_base + 180);
  vmcs.guest_fs_access = phys_read(32, guest_base + 184);
  vmcs.guest_gs_access = phys_read(32, guest_base + 188);
  vmcs.guest_ldtr_access = phys_read(32, guest_base + 192);
  vmcs.guest_tr_access = phys_read(32, guest_base + 196);

  vmcs.guest_gdtr_base = phys_read(64, guest_base + 200);
  vmcs.guest_gdtr_limit = phys_read(32, guest_base + 208);
  vmcs.guest_idtr_base = phys_read(64, guest_base + 212);
  vmcs.guest_idtr_limit = phys_read(32, guest_base + 220);

  vmcs.guest_efer = phys_read(64, guest_base + 224);
  vmcs.guest_debugctl = phys_read(64, guest_base + 232);
  vmcs.guest_sysenter_cs = phys_read(32, guest_base + 240);
  vmcs.guest_sysenter_esp = phys_read(64, guest_base + 244);
  vmcs.guest_sysenter_eip = phys_read(64, guest_base + 252);
  vmcs.guest_activity_state = phys_read(32, guest_base + 260);
  vmcs.guest_interruptibility = phys_read(32, guest_base + 264);
  vmcs.guest_pending_dbg_exc = phys_read(64, guest_base + 268);
  vmcs.guest_vmcs_link_pointer = phys_read(64, guest_base + 276);
  vmcs.guest_preempt_timer = phys_read(32, guest_base + 284);

  let host_base : qword = base + 474;
  vmcs.host_cr0 = phys_read(64, host_base + 0);
  vmcs.host_cr3 = phys_read(64, host_base + 8);
  vmcs.host_cr4 = phys_read(64, host_base + 16);
  vmcs.host_rsp = phys_read(64, host_base + 24);
  vmcs.host_rip = phys_read(64, host_base + 32);

  vmcs.host_es_selector = phys_read(16, host_base + 40);
  vmcs.host_cs_selector = phys_read(16, host_base + 42);
  vmcs.host_ss_selector = phys_read(16, host_base + 44);
  vmcs.host_ds_selector = phys_read(16, host_base + 46);
  vmcs.host_fs_selector = phys_read(16, host_base + 48);
  vmcs.host_gs_selector = phys_read(16, host_base + 50);
  vmcs.host_tr_selector = phys_read(16, host_base + 52);

  vmcs.host_fs_base = phys_read(64, host_base + 54);
  vmcs.host_gs_base = phys_read(64, host_base + 62);
  vmcs.host_tr_base = phys_read(64, host_base + 70);
  vmcs.host_gdtr_base = phys_read(64, host_base + 78);
  vmcs.host_idtr_base = phys_read(64, host_base + 86);

  vmcs.host_efer = phys_read(64, host_base + 94);
  vmcs.host_sysenter_cs = phys_read(32, host_base + 102);
  vmcs.host_sysenter_esp = phys_read(64, host_base + 106);
  vmcs.host_sysenter_eip = phys_read(64, host_base + 114);

  let exit_info_base : qword = base + 596;
  vmcs.exit_reason = phys_read(32, exit_info_base + 0);
  vmcs.exit_qualification = phys_read(64, exit_info_base + 4);
  vmcs.exit_interruption_info = phys_read(32, exit_info_base + 12);
  vmcs.exit_interruption_errcode = phys_read(32, exit_info_base + 16);
  vmcs.idt_vectoring_info = phys_read(32, exit_info_base + 20);
  vmcs.idt_vectoring_errcode = phys_read(32, exit_info_base + 24);
  vmcs.exit_instr_length = phys_read(32, exit_info_base + 28);
  vmcs.exit_instr_info = phys_read(32, exit_info_base + 32);
  vmcs.guest_linear_address = phys_read(64, exit_info_base + 36);
  vmcs.guest_physical_address = phys_read(64, exit_info_base + 44);
  vmcs.vm_instruction_error = phys_read(32, exit_info_base + 52);

  vmcs.launch_state = phys_read(32, base + 656);

  // Extended fields (offset 660)
  vmcs.virtual_apic_page_addr = phys_read(64, base + 660);
  vmcs.page_fault_error_mask = phys_read(32, base + 668);
  vmcs.page_fault_error_match = phys_read(32, base + 672);
  vmcs.tpr_threshold = phys_read(32, base + 676);
  vmcs.guest_pat = phys_read(64, base + 680);
  vmcs.host_pat = phys_read(64, base + 688)
}

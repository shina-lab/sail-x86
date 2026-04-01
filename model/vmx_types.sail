// x86-64 — VMX (VT-x) Types and Constants
//
// SDM Vol.3C Chapter 24-28: Virtual Machine Extensions.
// VMCS field encodings, exit reasons, and the VMCS data structure.

// =========================================================================
// VMX Exit Reasons (SDM Vol.3C Table C-1)
// =========================================================================

let VMEXIT_EXCEPTION_NMI      : dword = 0x00000000
let VMEXIT_EXTERNAL_INT       : dword = 0x00000001
let VMEXIT_TRIPLE_FAULT       : dword = 0x00000002
let VMEXIT_INIT_SIGNAL        : dword = 0x00000003
let VMEXIT_SIPI               : dword = 0x00000004
let VMEXIT_IO_SMI              : dword = 0x00000005
let VMEXIT_OTHER_SMI          : dword = 0x00000006
let VMEXIT_INTERRUPT_WINDOW   : dword = 0x00000007
let VMEXIT_NMI_WINDOW         : dword = 0x00000008
let VMEXIT_TASK_SWITCH        : dword = 0x00000009
let VMEXIT_CPUID              : dword = 0x0000000A
let VMEXIT_GETSEC             : dword = 0x0000000B
let VMEXIT_HLT                : dword = 0x0000000C
let VMEXIT_INVD               : dword = 0x0000000D
let VMEXIT_INVLPG             : dword = 0x0000000E
let VMEXIT_RDPMC              : dword = 0x0000000F
let VMEXIT_RDTSC              : dword = 0x00000010
let VMEXIT_RSM                : dword = 0x00000011
let VMEXIT_VMCALL             : dword = 0x00000012
let VMEXIT_VMCLEAR            : dword = 0x00000013
let VMEXIT_VMLAUNCH           : dword = 0x00000014
let VMEXIT_VMPTRLD            : dword = 0x00000015
let VMEXIT_VMPTRST            : dword = 0x00000016
let VMEXIT_VMREAD             : dword = 0x00000017
let VMEXIT_VMRESUME           : dword = 0x00000018
let VMEXIT_VMWRITE            : dword = 0x00000019
let VMEXIT_VMXOFF             : dword = 0x0000001A
let VMEXIT_VMXON              : dword = 0x0000001B
let VMEXIT_CR_ACCESS          : dword = 0x0000001C
let VMEXIT_DR_ACCESS          : dword = 0x0000001D
let VMEXIT_IO_INSTRUCTION     : dword = 0x0000001E
let VMEXIT_RDMSR              : dword = 0x0000001F
let VMEXIT_WRMSR              : dword = 0x00000020
let VMEXIT_ENTRY_FAIL_GUEST   : dword = 0x00000021
let VMEXIT_ENTRY_FAIL_MSR     : dword = 0x00000022
let VMEXIT_MWAIT              : dword = 0x00000024
let VMEXIT_MONITOR_TRAP       : dword = 0x00000025
let VMEXIT_MONITOR            : dword = 0x00000027
let VMEXIT_PAUSE              : dword = 0x00000028
let VMEXIT_ENTRY_FAIL_MC      : dword = 0x00000029
let VMEXIT_TPR_BELOW          : dword = 0x0000002B
let VMEXIT_APIC_ACCESS        : dword = 0x0000002C
let VMEXIT_VIRTUALIZED_EOI    : dword = 0x0000002D
let VMEXIT_GDTR_IDTR_ACCESS   : dword = 0x0000002E
let VMEXIT_LDTR_TR_ACCESS     : dword = 0x0000002F
let VMEXIT_EPT_VIOLATION      : dword = 0x00000030
let VMEXIT_EPT_MISCONFIG      : dword = 0x00000031
let VMEXIT_INVEPT             : dword = 0x00000032
let VMEXIT_RDTSCP             : dword = 0x00000033
let VMEXIT_PREEMPTION_TIMER   : dword = 0x00000034
let VMEXIT_INVVPID            : dword = 0x00000035
let VMEXIT_WBINVD             : dword = 0x00000036
let VMEXIT_XSETBV             : dword = 0x00000037
let VMEXIT_APIC_WRITE         : dword = 0x00000038
let VMEXIT_RDRAND             : dword = 0x00000039
let VMEXIT_INVPCID            : dword = 0x0000003A
let VMEXIT_VMFUNC             : dword = 0x0000003B
let VMEXIT_ENCLS              : dword = 0x0000003C
let VMEXIT_RDSEED             : dword = 0x0000003D
let VMEXIT_PML_FULL           : dword = 0x0000003E
let VMEXIT_XSAVES             : dword = 0x0000003F
let VMEXIT_XRSTORS            : dword = 0x00000040

// =========================================================================
// VMX Instruction Error Numbers (SDM Vol.3C Table 31-1)
// =========================================================================

let VMXERR_VMCALL_IN_ROOT              : dword = 0x00000001
let VMXERR_VMCLEAR_INVALID_ADDR        : dword = 0x00000002
let VMXERR_VMCLEAR_VMXON_PTR           : dword = 0x00000003
let VMXERR_VMLAUNCH_NONCLEAR           : dword = 0x00000004
let VMXERR_VMRESUME_NONLAUNCHED        : dword = 0x00000005
let VMXERR_VMRESUME_AFTER_VMXOFF       : dword = 0x00000006
let VMXERR_VMENTRY_INVALID_CTRL        : dword = 0x00000007
let VMXERR_VMENTRY_INVALID_HOST        : dword = 0x00000008
let VMXERR_VMPTRLD_INVALID_ADDR        : dword = 0x00000009
let VMXERR_VMPTRLD_VMXON_PTR           : dword = 0x0000000A
let VMXERR_VMPTRLD_WRONG_REV           : dword = 0x0000000B
let VMXERR_VMRW_UNSUPPORTED_FIELD      : dword = 0x0000000C
let VMXERR_VMWRITE_READONLY            : dword = 0x0000000D
let VMXERR_VMXON_IN_ROOT               : dword = 0x0000000F

// =========================================================================
// VMCS revision identifier
//
// The first 31 bits of a VMCS region hold the revision identifier.
// Software must write this value before VMPTRLD. We define a constant
// that our model recognizes.
// =========================================================================

let VMCS_REVISION_ID : dword = 0x00000001

// =========================================================================
// VMCS Data Structure
//
// SDM Vol.3C Chapter 24-25: VMCS field encodings.
// This struct holds all VMCS fields as typed members.
// The VMCS is cached in a Sail register; VMCLEAR serializes it to
// memory and VMPTRLD deserializes it.
// =========================================================================

struct VMCS_data = {
  // --- VM-execution control fields (SDM §24.6) ---
  pin_based_controls      : dword,   // Pin-based VM-execution controls
  primary_proc_controls   : dword,   // Primary processor-based VM-execution controls
  secondary_proc_controls : dword,   // Secondary processor-based VM-execution controls
  exception_bitmap        : dword,   // Exception bitmap (32 bits, one per exception vector)
  io_bitmap_a             : qword,   // I/O bitmap A physical address (ports 0000-7FFF)
  io_bitmap_b             : qword,   // I/O bitmap B physical address (ports 8000-FFFF)
  msr_bitmap              : qword,   // MSR bitmap physical address
  tsc_offset              : qword,   // TSC offset
  virtual_apic_page_addr  : qword,   // Virtual-APIC page address
  page_fault_error_mask   : dword,   // Page-fault error-code mask
  page_fault_error_match  : dword,   // Page-fault error-code match
  tpr_threshold           : dword,   // TPR threshold
  ept_pointer             : qword,   // EPT pointer (root of EPT page tables)
  cr0_guest_host_mask     : qword,   // CR0 guest/host mask
  cr0_read_shadow         : qword,   // CR0 read shadow
  cr4_guest_host_mask     : qword,   // CR4 guest/host mask
  cr4_read_shadow         : qword,   // CR4 read shadow
  cr3_target_count        : dword,   // CR3-target count
  cr3_target_0            : qword,   // CR3-target value 0
  cr3_target_1            : qword,   // CR3-target value 1
  cr3_target_2            : qword,   // CR3-target value 2
  cr3_target_3            : qword,   // CR3-target value 3
  vpid                    : word,    // Virtual-processor identifier

  // --- VM-exit control fields (SDM §24.7) ---
  exit_controls           : dword,   // VM-exit controls
  exit_msr_store_count    : dword,   // VM-exit MSR-store count
  exit_msr_store_addr     : qword,   // VM-exit MSR-store address
  exit_msr_load_count     : dword,   // VM-exit MSR-load count
  exit_msr_load_addr      : qword,   // VM-exit MSR-load address

  // --- VM-entry control fields (SDM §24.8) ---
  entry_controls          : dword,   // VM-entry controls
  entry_msr_load_count    : dword,   // VM-entry MSR-load count
  entry_msr_load_addr     : qword,   // VM-entry MSR-load address
  entry_interruption_info : dword,   // VM-entry interruption-information field
  entry_exception_errcode : dword,   // VM-entry exception error code
  entry_instr_length      : dword,   // VM-entry instruction length

  // --- Guest-state area (SDM §24.4) ---
  guest_cr0               : qword,
  guest_cr3               : qword,
  guest_cr4               : qword,
  guest_dr7               : qword,
  guest_rsp               : qword,
  guest_rip               : qword,
  guest_rflags            : qword,

  guest_es_selector       : word,
  guest_cs_selector       : word,
  guest_ss_selector       : word,
  guest_ds_selector       : word,
  guest_fs_selector       : word,
  guest_gs_selector       : word,
  guest_ldtr_selector     : word,
  guest_tr_selector       : word,

  guest_es_base           : qword,
  guest_cs_base           : qword,
  guest_ss_base           : qword,
  guest_ds_base           : qword,
  guest_fs_base           : qword,
  guest_gs_base           : qword,
  guest_ldtr_base         : qword,
  guest_tr_base           : qword,

  guest_es_limit          : dword,
  guest_cs_limit          : dword,
  guest_ss_limit          : dword,
  guest_ds_limit          : dword,
  guest_fs_limit          : dword,
  guest_gs_limit          : dword,
  guest_ldtr_limit        : dword,
  guest_tr_limit          : dword,

  guest_es_access         : dword,
  guest_cs_access         : dword,
  guest_ss_access         : dword,
  guest_ds_access         : dword,
  guest_fs_access         : dword,
  guest_gs_access         : dword,
  guest_ldtr_access       : dword,
  guest_tr_access         : dword,

  guest_gdtr_base         : qword,
  guest_gdtr_limit        : dword,
  guest_idtr_base         : qword,
  guest_idtr_limit        : dword,

  guest_efer              : qword,
  guest_pat               : qword,   // Guest IA32_PAT
  guest_debugctl          : qword,
  guest_sysenter_cs       : dword,
  guest_sysenter_esp      : qword,
  guest_sysenter_eip      : qword,
  guest_activity_state    : dword,   // 0=Active, 1=HLT, 2=Shutdown, 3=Wait-for-SIPI
  guest_interruptibility  : dword,   // Interruptibility state
  guest_pending_dbg_exc   : qword,   // Pending debug exceptions
  guest_vmcs_link_pointer : qword,   // VMCS link pointer (for VMCS shadowing)
  guest_preempt_timer     : dword,   // VMX-preemption timer value

  // --- Host-state area (SDM §24.5) ---
  host_cr0                : qword,
  host_cr3                : qword,
  host_cr4                : qword,
  host_rsp                : qword,
  host_rip                : qword,

  host_es_selector        : word,
  host_cs_selector        : word,
  host_ss_selector        : word,
  host_ds_selector        : word,
  host_fs_selector        : word,
  host_gs_selector        : word,
  host_tr_selector        : word,

  host_fs_base            : qword,
  host_gs_base            : qword,
  host_tr_base            : qword,
  host_gdtr_base          : qword,
  host_idtr_base          : qword,

  host_efer               : qword,
  host_pat                : qword,   // Host IA32_PAT
  host_sysenter_cs        : dword,
  host_sysenter_esp       : qword,
  host_sysenter_eip       : qword,

  // --- VM-exit information fields (SDM §24.9) — read-only ---
  exit_reason             : dword,
  exit_qualification      : qword,
  exit_interruption_info  : dword,
  exit_interruption_errcode : dword,
  idt_vectoring_info      : dword,
  idt_vectoring_errcode   : dword,
  exit_instr_length       : dword,
  exit_instr_info         : dword,
  guest_linear_address    : qword,
  guest_physical_address  : qword,
  vm_instruction_error    : dword,

  // --- VMCS launch state ---
  launch_state            : dword,   // 0=clear, 1=launched
}

// Default (all-zeros) VMCS.
val default_vmcs : unit -> VMCS_data
function default_vmcs() = struct {
  pin_based_controls      = zeros(),
  primary_proc_controls   = zeros(),
  secondary_proc_controls = zeros(),
  exception_bitmap        = zeros(),
  io_bitmap_a             = zeros(),
  io_bitmap_b             = zeros(),
  msr_bitmap              = zeros(),
  tsc_offset              = zeros(),
  virtual_apic_page_addr  = zeros(),
  page_fault_error_mask   = zeros(),
  page_fault_error_match  = zeros(),
  tpr_threshold           = zeros(),
  ept_pointer             = zeros(),
  cr0_guest_host_mask     = zeros(),
  cr0_read_shadow         = zeros(),
  cr4_guest_host_mask     = zeros(),
  cr4_read_shadow         = zeros(),
  cr3_target_count        = zeros(),
  cr3_target_0            = zeros(),
  cr3_target_1            = zeros(),
  cr3_target_2            = zeros(),
  cr3_target_3            = zeros(),
  vpid                    = zeros(),

  exit_controls           = zeros(),
  exit_msr_store_count    = zeros(),
  exit_msr_store_addr     = zeros(),
  exit_msr_load_count     = zeros(),
  exit_msr_load_addr      = zeros(),

  entry_controls          = zeros(),
  entry_msr_load_count    = zeros(),
  entry_msr_load_addr     = zeros(),
  entry_interruption_info = zeros(),
  entry_exception_errcode = zeros(),
  entry_instr_length      = zeros(),

  guest_cr0               = zeros(),
  guest_cr3               = zeros(),
  guest_cr4               = zeros(),
  guest_dr7               = zeros(),
  guest_rsp               = zeros(),
  guest_rip               = zeros(),
  guest_rflags            = zeros(),

  guest_es_selector       = zeros(),
  guest_cs_selector       = zeros(),
  guest_ss_selector       = zeros(),
  guest_ds_selector       = zeros(),
  guest_fs_selector       = zeros(),
  guest_gs_selector       = zeros(),
  guest_ldtr_selector     = zeros(),
  guest_tr_selector       = zeros(),

  guest_es_base           = zeros(),
  guest_cs_base           = zeros(),
  guest_ss_base           = zeros(),
  guest_ds_base           = zeros(),
  guest_fs_base           = zeros(),
  guest_gs_base           = zeros(),
  guest_ldtr_base         = zeros(),
  guest_tr_base           = zeros(),

  guest_es_limit          = zeros(),
  guest_cs_limit          = zeros(),
  guest_ss_limit          = zeros(),
  guest_ds_limit          = zeros(),
  guest_fs_limit          = zeros(),
  guest_gs_limit          = zeros(),
  guest_ldtr_limit        = zeros(),
  guest_tr_limit          = zeros(),

  guest_es_access         = zeros(),
  guest_cs_access         = zeros(),
  guest_ss_access         = zeros(),
  guest_ds_access         = zeros(),
  guest_fs_access         = zeros(),
  guest_gs_access         = zeros(),
  guest_ldtr_access       = zeros(),
  guest_tr_access         = zeros(),

  guest_gdtr_base         = zeros(),
  guest_gdtr_limit        = zeros(),
  guest_idtr_base         = zeros(),
  guest_idtr_limit        = zeros(),

  guest_efer              = zeros(),
  guest_pat               = zeros(),
  guest_debugctl          = zeros(),
  guest_sysenter_cs       = zeros(),
  guest_sysenter_esp      = zeros(),
  guest_sysenter_eip      = zeros(),
  guest_activity_state    = zeros(),
  guest_interruptibility  = zeros(),
  guest_pending_dbg_exc   = zeros(),
  guest_vmcs_link_pointer = 0xFFFFFFFFFFFFFFFF,
  guest_preempt_timer     = zeros(),

  host_cr0                = zeros(),
  host_cr3                = zeros(),
  host_cr4                = zeros(),
  host_rsp                = zeros(),
  host_rip                = zeros(),

  host_es_selector        = zeros(),
  host_cs_selector        = zeros(),
  host_ss_selector        = zeros(),
  host_ds_selector        = zeros(),
  host_fs_selector        = zeros(),
  host_gs_selector        = zeros(),
  host_tr_selector        = zeros(),

  host_fs_base            = zeros(),
  host_gs_base            = zeros(),
  host_tr_base            = zeros(),
  host_gdtr_base          = zeros(),
  host_idtr_base          = zeros(),

  host_efer               = zeros(),
  host_pat                = zeros(),
  host_sysenter_cs        = zeros(),
  host_sysenter_esp       = zeros(),
  host_sysenter_eip       = zeros(),

  exit_reason             = zeros(),
  exit_qualification      = zeros(),
  exit_interruption_info  = zeros(),
  exit_interruption_errcode = zeros(),
  idt_vectoring_info      = zeros(),
  idt_vectoring_errcode   = zeros(),
  exit_instr_length       = zeros(),
  exit_instr_info         = zeros(),
  guest_linear_address    = zeros(),
  guest_physical_address  = zeros(),
  vm_instruction_error    = zeros(),

  launch_state            = zeros(),
}

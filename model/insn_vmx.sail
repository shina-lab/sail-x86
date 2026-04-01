// x86-64 — VMX Instruction Implementations
//
// SDM Vol.3C Chapter 31: VMX Instructions.
// VMXON, VMXOFF, VMPTRLD, VMPTRST, VMCLEAR, VMREAD, VMWRITE,
// VMLAUNCH, VMRESUME, VMCALL.

// VMfail/VMsucceed helpers are defined in vmx.sail (compiled before this file).

// =========================================================================
// Common VMX instruction checks
// =========================================================================

// Check common preconditions for VMX instructions (other than VMXON).
// SDM §31.2: #UD if not in VMX operation, #GP(0) if CPL > 0.
// In VMX non-root, VMX instructions cause unconditional VM exit.
val vmx_check_preconditions : unit -> unit
function vmx_check_preconditions() = {
  if ~(in_vmx_root) & ~(in_vmx_non_root) then raise_UD();
  if cur_cpl != 0 then raise_GP0()
}

// =========================================================================
// VMXON — Enter VMX Operation (SDM Vol.3C §24.11.5, §31.2.1)
//
// Encoding: F3 0F C7 /6 mem
// Operand: m64 containing physical address of VMXON region.
//
// Checks: CPL=0, CR4.VMXE=1, CR0.PE=1, not in V8086, not already in VMX,
//         IA32_FEATURE_CONTROL (simplified), VMXON region revision ID.
// =========================================================================

val exec_vmxon : qword -> unit
function exec_vmxon(addr) = {
  // #GP(0) if CPL != 0
  if cur_cpl != 0 then raise_GP0();

  // #UD if CR4.VMXE (bit 13) is not set
  if CR4[13] == 0b0 then raise_UD();

  // #GP(0) if not in protected mode (CR0.PE must be set)
  if CR0[0] == 0b0 then raise_GP0();

  // #GP(0) if EFLAGS.VM = 1 (V8086 mode)
  // (In our model, LongMode implies not V8086, and we check CR0.PE)

  // IA32_FEATURE_CONTROL checks (SDM §24.11.5):
  // Lock bit (bit 0) must be set, and VMX-outside-SMX (bit 2) must be enabled.
  if ia32_feature_control[0] == 0b0 then raise_GP0();
  if ia32_feature_control[2] == 0b0 then raise_GP0();

  // CR0 fixed-bit enforcement (SDM §24.8):
  // (CR0 & CR0_FIXED0) == CR0_FIXED0 and (CR0 | ~CR0_FIXED1) == CR0
  let cr0_fixed0 : qword = 0x0000000080000021;  // PE + NE + PG
  let cr0_fixed1 : qword = 0x00000000FFFFFFFF;
  if (CR0 & cr0_fixed0) != cr0_fixed0 then raise_GP0();
  if (CR0 & cr0_fixed1) != CR0 then raise_GP0();

  // CR4 fixed-bit enforcement:
  let cr4_fixed0 : qword = 0x0000000000002000;  // VMXE
  let cr4_fixed1 : qword = 0x00000000003727FF;
  if (CR4 & cr4_fixed0) != cr4_fixed0 then raise_GP0();
  if (CR4 & cr4_fixed1) != CR4 then raise_GP0();

  // Already in VMX operation? VMfailValid if in root, #GP if in non-root.
  if in_vmx_root then {
    vmx_fail_valid(VMXERR_VMXON_IN_ROOT);
    return ()
  };

  // Read the 64-bit physical address from the operand memory location
  let vmxon_pa : qword = read_mem(addr);

  // Check alignment: VMXON region must be 4KB-aligned
  if vmxon_pa[11..0] != 0x000 then {
    vmx_fail_invalid();
    return ()
  };

  // Check revision ID at the VMXON region
  let rev_id : dword = phys_read(32, vmxon_pa);
  if rev_id[30..0] != VMCS_REVISION_ID[30..0] then {
    vmx_fail_invalid();
    return ()
  };

  // Enter VMX root operation
  in_vmx_root = true;
  in_vmx_non_root = false;
  vmxon_region_pa = vmxon_pa;
  vmcs_ptr = None();

  vmx_succeed()
}

// =========================================================================
// VMXOFF — Leave VMX Operation (SDM Vol.3C §31.2.2)
//
// Encoding: 0F 01 C4
// =========================================================================

val exec_vmxoff : unit -> unit
function exec_vmxoff() = {
  vmx_check_preconditions();

  // Must be in VMX root operation
  if ~(in_vmx_root) then {
    vmx_fail_invalid();
    return ()
  };

  in_vmx_root = false;
  in_vmx_non_root = false;
  vmcs_ptr = None();

  // Clear CR4.VMXE is NOT done by VMXOFF per SDM — software must do it.
  vmx_succeed()
}

// =========================================================================
// VMPTRLD — Load Pointer to VMCS (SDM Vol.3C §31.2.3.1)
//
// Encoding: NP 0F C7 /6 mem
// Operand: m64 containing physical address of VMCS region.
//
// Loads the specified VMCS as the current VMCS. Deserializes from memory.
// =========================================================================

val exec_vmptrld : qword -> unit
function exec_vmptrld(addr) = {
  vmx_check_preconditions();

  let new_vmcs_pa : qword = read_mem(addr);

  // Check 4KB alignment
  if new_vmcs_pa[11..0] != 0x000 then {
    vmx_fail_valid(VMXERR_VMPTRLD_INVALID_ADDR);
    return ()
  };

  // Cannot VMPTRLD the VMXON region
  if new_vmcs_pa == vmxon_region_pa then {
    vmx_fail_valid(VMXERR_VMPTRLD_VMXON_PTR);
    return ()
  };

  // Check revision ID
  let rev_id : dword = phys_read(32, new_vmcs_pa);
  if rev_id[30..0] != VMCS_REVISION_ID[30..0] then {
    vmx_fail_valid(VMXERR_VMPTRLD_WRONG_REV);
    return ()
  };

  // If there's already a current VMCS, serialize it first
  match vmcs_ptr {
    Some(old_pa) => vmcs_serialize(old_pa),
    None() => (),
  };

  // Load the new VMCS
  vmcs_ptr = Some(new_vmcs_pa);
  vmcs_deserialize(new_vmcs_pa);

  vmx_succeed()
}

// =========================================================================
// VMCLEAR — Clear VMCS (SDM Vol.3C §31.2.3.2)
//
// Encoding: 66 0F C7 /6 mem
// Operand: m64 containing physical address of VMCS region.
//
// Sets the launch state to "clear" and serializes to memory.
// If the operand is the current VMCS, also invalidates vmcs_ptr.
// =========================================================================

val exec_vmclear : qword -> unit
function exec_vmclear(addr) = {
  vmx_check_preconditions();

  let clear_pa : qword = read_mem(addr);

  // Check 4KB alignment
  if clear_pa[11..0] != 0x000 then {
    vmx_fail_valid(VMXERR_VMCLEAR_INVALID_ADDR);
    return ()
  };

  // Cannot VMCLEAR the VMXON region
  if clear_pa == vmxon_region_pa then {
    vmx_fail_valid(VMXERR_VMCLEAR_VMXON_PTR);
    return ()
  };

  match vmcs_ptr {
    Some(cur_pa) => {
      if cur_pa == clear_pa then {
        // Clearing the current VMCS: set to "clear" state, serialize, invalidate
        vmcs.launch_state = 0x00000000;
        vmcs_serialize(clear_pa);
        vmcs_ptr = None()
      } else {
        // Clearing a non-current VMCS: write launch_state=clear directly
        // We read the VMCS from memory, clear launch_state, write back
        phys_write(32, clear_pa + 8 + 656, 0x00000000 : dword)
      }
    },
    None() => {
      // No current VMCS; just clear the launch state in memory
      phys_write(32, clear_pa + 8 + 656, 0x00000000 : dword)
    },
  };

  vmx_succeed()
}

// =========================================================================
// VMPTRST — Store Pointer to VMCS (SDM Vol.3C §31.2.3.3)
//
// Encoding: 0F C7 /7 mem
// Operand: m64 destination for the current VMCS pointer.
//
// Stores the physical address of the current VMCS to the destination.
// If no current VMCS, stores FFFFFFFFFFFFFFFF.
// =========================================================================

val exec_vmptrst : qword -> unit
function exec_vmptrst(addr) = {
  vmx_check_preconditions();

  let result : qword = match vmcs_ptr {
    Some(pa) => pa,
    None() => 0xFFFFFFFFFFFFFFFF,
  };
  write_mem(addr, result);

  vmx_succeed()
}

// =========================================================================
// VMREAD — Read Field from VMCS (SDM Vol.3C §31.2.4)
//
// Encoding: 0F 78 (modrm)
// Operands: reg/m64 destination, reg source (field encoding in source).
// In 64-bit mode, operand size is always 64 bits.
// =========================================================================

val exec_vmread : (Prefixes, RM, gpr_idx) -> unit
function exec_vmread(pfx, dest, src_reg) = {
  vmx_check_preconditions();

  // Must have a current VMCS
  match vmcs_ptr {
    None() => { vmx_fail_invalid(); return () },
    Some(_) => (),
  };

  let encoding : dword = v(32, src_reg);

  match vmcs_read_field(encoding) {
    Some(value) => {
      match dest {
        RM_reg(r) => v(64, r) = value,
        RM_mem(m) => write_mem(m, value),
      };
      vmx_succeed()
    },
    None() => vmx_fail_valid(VMXERR_VMRW_UNSUPPORTED_FIELD),
  }
}

// =========================================================================
// VMWRITE — Write Field to VMCS (SDM Vol.3C §31.2.5)
//
// Encoding: 0F 79 (modrm)
// Operands: reg source (field encoding), reg/m64 source (value).
// In 64-bit mode, operand size is always 64 bits.
// =========================================================================

val exec_vmwrite : (Prefixes, RM, gpr_idx) -> unit
function exec_vmwrite(pfx, src, reg) = {
  vmx_check_preconditions();

  // Must have a current VMCS
  match vmcs_ptr {
    None() => { vmx_fail_invalid(); return () },
    Some(_) => (),
  };

  let encoding : dword = v(32, reg);
  let value : qword = match src {
    RM_reg(r) => v(64, r),
    RM_mem(m) => read_mem(m),
  };

  // Check if the field is recognized and writable
  if vmcs_write_field(encoding, value) then
    vmx_succeed()
  else {
    // Distinguish: is the field recognized-but-read-only, or unknown?
    match vmcs_read_field(encoding) {
      Some(_) => vmx_fail_valid(VMXERR_VMWRITE_READONLY),
      None() => vmx_fail_valid(VMXERR_VMRW_UNSUPPORTED_FIELD),
    }
  }
}

// =========================================================================
// VMLAUNCH — Launch Virtual Machine (SDM Vol.3C §31.2.7)
//
// Encoding: 0F 01 C2
// Requires current VMCS with launch_state = "clear" (0).
// Performs VM entry: validates VMCS, loads guest state, enters non-root.
// =========================================================================

val exec_vmlaunch : unit -> unit
function exec_vmlaunch() = {
  vmx_check_preconditions();

  // Must be in VMX root
  if ~(in_vmx_root) then { vmx_fail_invalid(); return () };

  // Must have a current VMCS
  match vmcs_ptr {
    None() => { vmx_fail_invalid(); return () },
    Some(_) => (),
  };

  vm_entry(true)
}

// =========================================================================
// VMRESUME — Resume Virtual Machine (SDM Vol.3C §31.2.7)
//
// Encoding: 0F 01 C3
// Requires current VMCS with launch_state = "launched" (1).
// =========================================================================

val exec_vmresume : unit -> unit
function exec_vmresume() = {
  vmx_check_preconditions();

  if ~(in_vmx_root) then { vmx_fail_invalid(); return () };

  match vmcs_ptr {
    None() => { vmx_fail_invalid(); return () },
    Some(_) => (),
  };

  vm_entry(false)
}

// =========================================================================
// VMCALL — Call to VM Monitor (SDM Vol.3C §31.2.6)
//
// Encoding: 0F 01 C1
// In VMX root: #UD (simplified; full behavior requires dual-monitor).
// In VMX non-root: unconditional VM exit with reason VMEXIT_VMCALL.
// =========================================================================

val exec_vmcall : unit -> unit
function exec_vmcall() = {
  if ~(in_vmx_root) & ~(in_vmx_non_root) then raise_UD();
  if cur_cpl != 0 then raise_GP0();

  if in_vmx_non_root then {
    vmcs.exit_instr_length = (decode_pos - insn_start)[31..0];
    throw VMExit(VMEXIT_VMCALL, 0x0000000000000000)
  };

  // In VMX root without dual-monitor treatment: VMfailValid
  vmx_fail_valid(VMXERR_VMCALL_IN_ROOT)
}

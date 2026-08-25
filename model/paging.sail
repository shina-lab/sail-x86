// x86-64 — 4-Level and 5-Level Paging (Long Mode)
//
// Implements the IA-32e paging mechanism:
//   4-level (default):  Virtual address → PML4 → PDPT → PD → PT → Physical address
//   5-level (CR4.LA57): Virtual address → PML5 → PML4 → PDPT → PD → PT → Physical address
//
// Page table walks use phys_read to avoid recursion through mem_read.
// Follows the sail-riscv pattern: translate_addr() returns physical address
// or throws Fault(EXN_PF, error_code) on failure.

// Apply A20 gate masking: when A20 is disabled, bit 20 of the physical
// address is forced to zero, wrapping the address space at 1MB.
val a20_mask : qword -> qword
function a20_mask(addr) =
  if ~(a20_enabled) & system_mode then addr & 0xFFFFFFFFFFEFFFFF
  else addr

// =========================================================================
// EPT (Extended Page Tables) Translation — SDM Vol.3C §29.3
//
// When in VMX non-root with EPT enabled (secondary proc controls bit 1),
// guest-physical addresses go through a second translation layer:
//   Guest Physical Address (GPA) → EPT walk → Host Physical Address (HPA)
//
// The EPT page table format mirrors the standard 4-level paging:
//   EPT PML4 → EPT PDPT → EPT PD → EPT PT
// Entries use R/W/X permission bits (bits 2:0) instead of P/R-W/U-S.
// The EPT root pointer is in vmcs.ept_pointer[51:12].
// =========================================================================

// Check if EPT is active (fast path: just read the cached register).
// ept_active is declared in regs.sail, set by vm_entry/complete_vm_exit.
val ept_enabled : unit -> bool
function ept_enabled() = ept_active

// Build EPT violation exit qualification
val ept_violation_qual : (PTAccess, bool) -> qword
function ept_violation_qual(access, present) = {
  var qual : qword = zeros();
  // Implicit accesses surface as reads at the EPT level.
  if access == PT_Read | access == PT_Implicit then qual[0] = 0b1;
  if access == PT_Write then qual[1] = 0b1;
  if access == PT_Execute then qual[2] = 0b1;
  if present then {
    qual[3] = 0b1;
    qual[4] = 0b1;
    qual[5] = 0b1
  };
  qual
}

// Walk the EPT page table hierarchy. Uses __read_mem directly (not phys_read)
// to avoid recursion since phys_read calls ept_translate.
// On violation, throws VMExit(VMEXIT_EPT_VIOLATION, qualification).
val ept_walk : (qword, PTAccess, qword, range(0, 3)) -> qword
function ept_walk(gpa, access, table_base, level) = {
  let index : qword = match level {
    3 => zero_extend((gpa[47..39]) : bits(9)),  // PML4
    2 => zero_extend((gpa[38..30]) : bits(9)),  // PDPT
    1 => zero_extend((gpa[29..21]) : bits(9)),  // PD
    0 => zero_extend((gpa[20..12]) : bits(9)),  // PT
  };
  let epte_addr : qword = table_base + (index << 3);
  let epte : qword = __read_mem(epte_addr, 64);

  // Check R/W/X permissions (bits 2:0). If all zero, entry not present.
  let r = epte[0];
  let w = epte[1];
  let x = epte[2];
  if (r | w | x) == 0b0 then {
    // EPT violation: not present
    let qual : qword = ept_violation_qual(access, false);
    vmcs.guest_physical_address = gpa;
    vmcs.exit_instr_length = 0x00000000;
    throw VMExit(VMEXIT_EPT_VIOLATION, qual)
  };

  // Check for large page (PS bit = bit 7)
  let is_leaf : bool = if level == 0 then true
    else if (level == 1 | level == 2) & epte[7] == 0b1 then true
    else false;

  if is_leaf then {
    // Permission check.  Implicit (descriptor-table) accesses are reads
    // at the EPT level — R must be set on the leaf EPTE.
    let denied : bool = match access {
      PT_Read     => r == 0b0,
      PT_Write    => w == 0b0,
      PT_Execute  => x == 0b0,
      PT_Implicit => r == 0b0,
    };
    if denied then {
      let qual : qword = ept_violation_qual(access, true);
      vmcs.guest_physical_address = gpa;
      vmcs.exit_instr_length = 0x00000000;
      throw VMExit(VMEXIT_EPT_VIOLATION, qual)
    };

    // Compute host physical address
    let ppn : qword = epte & 0x000FFFFFFFFFF000;
    match level {
      0 => ppn | (gpa & 0x0000000000000FFF),            // 4KB
      1 => (ppn & 0x000FFFFFFFE00000) | (gpa & 0x00000000001FFFFF), // 2MB
      _ => (ppn & 0x000FFFFFC0000000) | (gpa & 0x000000003FFFFFFF), // 1GB
    }
  } else if level > 0 then {
    let next_base : qword = epte & 0x000FFFFFFFFFF000;
    ept_walk(gpa, access, next_base, level - 1)
  } else {
    // Unreachable: level==0 is always a leaf
    vmcs.guest_physical_address = gpa;
    throw VMExit(VMEXIT_EPT_VIOLATION, ept_violation_qual(access, false))
  }
}
termination_measure ept_walk(_, _, _, level) = level

// EPT-translate a guest physical address to host physical address.
// Only active when EPT is enabled; otherwise returns gpa unchanged.
val ept_translate : (qword, PTAccess) -> qword
function ept_translate(gpa, access) = {
  if ept_enabled() then {
    let ept_root : qword = vmcs.ept_pointer & 0x000FFFFFFFFFF000;
    ept_walk(gpa, access, ept_root, 3)
  } else {
    gpa
  }
}

// Physical memory access (bypass virtual address translation).
// Used by page table walks and by mem_read/mem_write when paging is off.
// When EPT is active, translates guest-physical to host-physical first.
// Size parameter 'n is in bits.
val phys_read : forall 'n, 'n > 0. (implicit('n), qword) -> bits('n)
function phys_read(n, addr) = {
  let pa = a20_mask(addr);
  if ept_active then __read_mem(ept_translate(pa, PT_Read), n)
  else __read_mem(pa, n)
}

val phys_write : forall 'n, 'n > 0. (implicit('n), qword, bits('n)) -> unit
function phys_write(n, addr, data) = {
  let pa = a20_mask(addr);
  if ept_active then __write_mem(ept_translate(pa, PT_Write), n, data)
  else __write_mem(pa, n, data)
}

// Build a #PF error code from access type and fault cause.
val mk_pf_error : (PTAccess, bool, bool) -> dword
function mk_pf_error(access, present, reserved) = {
  var ec : dword = 0x00000000;
  // Bit 0: P — page was present (permission violation vs not-present)
  if present then ec[0] = 0b1;
  // Bit 1: W/R — write access caused the fault
  if access == PT_Write then ec[1] = 0b1;
  // Bit 2: U/S — user-mode access caused the fault.
  // Implicit (descriptor-table) accesses are supervisor regardless of CPL.
  if cur_cpl == 3 & access != PT_Implicit then ec[2] = 0b1;
  // Bit 3: RSVD — reserved bit set in PTE
  if reserved then ec[3] = 0b1;
  // Bit 4: I/D — instruction fetch caused the fault.  Hardware sets it
  // only when the paging mode can express execute permission: CR4.SMEP=1,
  // or NXE-capable paging (PAE/4-level/5-level, i.e. CR4.PAE=1) with
  // IA32_EFER.NXE=1 (SDM Vol.3A §4.7).
  if access == PT_Execute &
     (CR4[20] == 0b1 | (CR4[5] == 0b1 & EFER[11] == 0b1))
  then ec[4] = 0b1;
  ec
}

// Check permissions on a leaf PTE. Returns true if access is allowed.
val check_pte_permissions : (qword, PTAccess) -> bool
function check_pte_permissions(pte, access) = {
  let rw    = pte[1];  // Read/Write bit
  let us    = pte[2];  // User/Supervisor bit
  let xd    = pte[63]; // Execute-Disable bit (if EFER.NXE=1)

  // Implicit accesses (GDT/LDT/IDT/TSS reads by the CPU itself) always
  // execute at supervisor privilege regardless of CPL, and don't cause
  // an NX fault (they're not instruction fetches).  Writes of this class
  // (e.g. A/D-bit updates, TSS busy-bit set) still respect WP.
  if access == PT_Implicit then true
  // User-mode access to supervisor page: always denied
  else if cur_cpl == 3 & us == 0b0 then false
  // Write to read-only page:
  // - In user mode: always denied
  // - In kernel mode: denied if CR0.WP=1, allowed if WP=0
  else if access == PT_Write & rw == 0b0 then {
    if cur_cpl == 3 then false
    else CR0[16] == 0b0  // WP=0 → allowed, WP=1 → denied
  }
  // Execute from XD page: denied if EFER.NXE=1
  else if access == PT_Execute & xd == 0b1 & EFER[11] == 0b1 then
    false
  else
    true
}

// Update Accessed and Dirty bits in the PTE if needed.
val update_accessed_dirty : (qword, qword, PTAccess) -> unit
function update_accessed_dirty(pte_addr, pte, access) = {
  var new_pte = pte;
  var changed : bool = false;
  // Set Accessed bit if not already set
  if pte[5] == 0b0 then {
    new_pte[5] = 0b1;
    changed = true
  };
  // Set Dirty bit for writes if not already set
  if access == PT_Write & pte[6] == 0b0 then {
    new_pte[6] = 0b1;
    changed = true
  };
  if changed then phys_write(pte_addr, new_pte)
}

// Page table walk.
// Walks PML5 → PML4 → PDPT → PD → PT to translate a 64-bit linear address.
// On success, returns the physical address.
// On failure, throws Fault(EXN_PF, error_code).
//
// The `level` parameter counts down:
//   4=PML5 (5-level only), 3=PML4, 2=PDPT, 1=PD, 0=PT.
val pt_walk : (qword, PTAccess, qword, range(0, 4)) -> qword
function pt_walk(linear, access, table_base, level) = {
  // 1. Compute index: 9 bits per level
  //    PML5: bits[56:48], PML4: bits[47:39], PDPT: bits[38:30],
  //    PD: bits[29:21], PT: bits[20:12]
  let index : qword = match level {
    4 => zero_extend((linear[56..48]) : bits(9)),  // PML5 index
    3 => zero_extend((linear[47..39]) : bits(9)),  // PML4 index
    2 => zero_extend((linear[38..30]) : bits(9)),  // PDPT index
    1 => zero_extend((linear[29..21]) : bits(9)),  // PD index
    0 => zero_extend((linear[20..12]) : bits(9)),  // PT index
  };
  let pte_addr : qword = table_base + (index << 3);

  // 2. Read PTE from physical memory (bypasses translation)
  let pte : qword = phys_read(pte_addr);

  // 3. Check Present bit
  if pte[0] == 0b0 then {
    CR2 = linear;
    throw Fault(EXN_PF, mk_pf_error(access, false, false))
  };

  // 4. Check reserved bits
  //    PML5E and PML4E: PS (bit 7) must be 0 (reserved)
  //    PDPTE/PDE: PS=1 allowed for huge pages
  if (level == 4 | level == 3) & pte[7] == 0b1 then {
    CR2 = linear;
    throw Fault(EXN_PF, mk_pf_error(access, true, true))
  };

  // 5. Check if this is a leaf entry
  let is_leaf : bool = if level == 0 then true
    else if 1 <= level & level <= 2 & pte[7] == 0b1 then true  // PS=1
    else false;

  if is_leaf then {
    // 6. Permission check
    if ~(check_pte_permissions(pte, access)) then {
      CR2 = linear;
      throw Fault(EXN_PF, mk_pf_error(access, true, false))
    };

    // 7. Update A/D bits
    update_accessed_dirty(pte_addr, pte, access);

    // 8. Compute physical address
    let ppn : qword = pte & 0x000FFFFFFFFFF000;  // bits[51:12]
    match level {
      // 4KB page: PPN[51:12] | offset[11:0]
      0 => ppn | (linear & 0x0000000000000FFF),
      // 2MB page: PPN[51:21] | offset[20:0]
      1 => (ppn & 0x000FFFFFFFE00000) | (linear & 0x00000000001FFFFF),
      // 1GB page: PPN[51:30] | offset[29:0]
      _ => (ppn & 0x000FFFFFC0000000) | (linear & 0x000000003FFFFFFF),
    }
  } else if level > 0 then {
    // 9. Non-leaf: recurse to next level
    let next_base : qword = pte & 0x000FFFFFFFFFF000;
    // Update Accessed bit on non-leaf entries too
    if pte[5] == 0b0 then phys_write(pte_addr, pte | 0x0000000000000020);
    pt_walk(linear, access, next_base, level - 1)
  } else {
    // level 0 non-leaf = impossible (always leaf)
    CR2 = linear;
    throw Fault(EXN_PF, mk_pf_error(access, true, true))
  }
}
termination_measure pt_walk(_, _, _, level) = level

// =========================================================================
// 32-bit non-PAE paging (SDM Vol.3A §4.3)
//
// 2-level walk: CR3 → Page Directory (1024 × 4-byte PDEs) → Page Table
// Linear address split: [31:22]=PDE index, [21:12]=PTE index, [11:0]=offset
// CR4.PSE=1 enables 4MB pages when PDE.PS=1.
// =========================================================================

val pt_walk_32 : (qword, PTAccess) -> qword
function pt_walk_32(linear, access) = {
  let pd_base : qword = CR3 & 0x00000000FFFFF000;

  // 1. PDE lookup: index = linear[31:22]
  let pde_index : qword = zero_extend((linear[31..22]) : bits(10));
  let pde_addr : qword = pd_base + (pde_index << 2);
  let pde : dword = phys_read(pde_addr);

  // Check present
  if pde[0] == 0b0 then {
    CR2 = linear;
    throw Fault(EXN_PF, mk_pf_error(access, false, false))
  };

  // Check permissions (R/W, U/S).  Implicit (descriptor-table) accesses
  // run at supervisor and bypass the U/S check regardless of CPL.
  if access == PT_Write & pde[1] == 0b0 then {
    if (cur_cpl == 3 & access != PT_Implicit) | CR0[16] == 0b1 then {
      CR2 = linear;
      throw Fault(EXN_PF, mk_pf_error(access, true, false))
    }
  };
  if cur_cpl == 3 & access != PT_Implicit & pde[2] == 0b0 then {
    CR2 = linear;
    throw Fault(EXN_PF, mk_pf_error(access, true, false))
  };

  // 4MB page (CR4.PSE=1 and PDE.PS=1)
  if CR4[4] == 0b1 & pde[7] == 0b1 then {
    // Update A/D bits
    var new_pde = pde;
    var changed : bool = false;
    if pde[5] == 0b0 then { new_pde[5] = 0b1; changed = true };
    if access == PT_Write & pde[6] == 0b0 then {
      new_pde[6] = 0b1; changed = true
    };
    if changed then phys_write(pde_addr, new_pde);
    // Physical address: PDE[31:22] @ linear[21:0]
    let ppn : dword = pde & 0xFFC00000;
    zero_extend(ppn | zero_extend(linear[21..0]))
  } else {
    // 2. PTE lookup: index = linear[21:12]
    let pt_base : qword = zero_extend(pde & 0xFFFFF000);
    let pte_index : qword = zero_extend((linear[21..12]) : bits(10));
    let pte_addr : qword = pt_base + (pte_index << 2);
    let pte : dword = phys_read(pte_addr);

    // Check present
    if pte[0] == 0b0 then {
      CR2 = linear;
      throw Fault(EXN_PF, mk_pf_error(access, false, false))
    };

    // Check permissions.  Implicit (descriptor-table) accesses bypass U/S.
    if access == PT_Write & pte[1] == 0b0 then {
      if (cur_cpl == 3 & access != PT_Implicit) | CR0[16] == 0b1 then {
        CR2 = linear;
        throw Fault(EXN_PF, mk_pf_error(access, true, false))
      }
    };
    if cur_cpl == 3 & access != PT_Implicit & pte[2] == 0b0 then {
      CR2 = linear;
      throw Fault(EXN_PF, mk_pf_error(access, true, false))
    };

    // Update A/D bits on PDE and PTE
    if pde[5] == 0b0 then phys_write(pde_addr, pde | 0x00000020);
    var new_pte = pte;
    var pte_changed : bool = false;
    if pte[5] == 0b0 then { new_pte[5] = 0b1; pte_changed = true };
    if access == PT_Write & pte[6] == 0b0 then {
      new_pte[6] = 0b1; pte_changed = true
    };
    if pte_changed then phys_write(pte_addr, new_pte);

    // Physical address: PTE[31:12] @ linear[11:0]
    zero_extend((pte & 0xFFFFF000) | zero_extend(linear[11..0]))
  }
}

// =========================================================================
// PAE paging (SDM Vol.3A §4.4)
//
// 3-level walk: CR3 → PDPT (4 × 64-bit entries) → PD → PT
// Linear address split: [31:30]=PDPTE, [29:21]=PDE, [20:12]=PTE, [11:0]=offset
// PDE/PTE are 64-bit. Supports 2MB pages when PDE.PS=1.
// =========================================================================

val pt_walk_pae : (qword, PTAccess) -> qword
function pt_walk_pae(linear, access) = {
  // 1. PDPTE lookup: index = linear[31:30] (2 bits, 4 entries)
  let pdpt_base : qword = CR3 & 0x00000000FFFFFFE0;
  let pdpte_index : qword = zero_extend((linear[31..30]) : bits(2));
  let pdpte_addr : qword = pdpt_base + (pdpte_index << 3);
  let pdpte : qword = phys_read(pdpte_addr);

  if pdpte[0] == 0b0 then {
    CR2 = linear;
    throw Fault(EXN_PF, mk_pf_error(access, false, false))
  };

  // 2. PDE lookup: index = linear[29:21]
  let pd_base : qword = pdpte & 0x000FFFFFFFFFF000;
  let pde_index : qword = zero_extend((linear[29..21]) : bits(9));
  let pde_addr : qword = pd_base + (pde_index << 3);
  let pde : qword = phys_read(pde_addr);

  if pde[0] == 0b0 then {
    CR2 = linear;
    throw Fault(EXN_PF, mk_pf_error(access, false, false))
  };

  // Permission checks
  if ~(check_pte_permissions(pde, access)) then {
    CR2 = linear;
    throw Fault(EXN_PF, mk_pf_error(access, true, false))
  };

  // 2MB page (PDE.PS=1)
  if pde[7] == 0b1 then {
    update_accessed_dirty(pde_addr, pde, access);
    let ppn : qword = pde & 0x000FFFFFFFE00000;
    ppn | zero_extend(linear[20..0])
  } else {
    // 3. PTE lookup: index = linear[20:12]
    let pt_base : qword = pde & 0x000FFFFFFFFFF000;
    let pte_index : qword = zero_extend((linear[20..12]) : bits(9));
    let pte_addr : qword = pt_base + (pte_index << 3);
    let pte : qword = phys_read(pte_addr);

    if pte[0] == 0b0 then {
      CR2 = linear;
      throw Fault(EXN_PF, mk_pf_error(access, false, false))
    };

    if ~(check_pte_permissions(pte, access)) then {
      CR2 = linear;
      throw Fault(EXN_PF, mk_pf_error(access, true, false))
    };

    // Update A/D on PDE and PTE
    if pde[5] == 0b0 then phys_write(pde_addr, pde | 0x0000000000000020);
    update_accessed_dirty(pte_addr, pte, access);

    let ppn : qword = pte & 0x000FFFFFFFFFF000;
    ppn | zero_extend(linear[11..0])
  }
}

// Top-level address translation.
// Dispatches to the appropriate paging mode based on CR0.PG, EFER.LMA,
// and CR4.PAE (SDM Vol.3A §4.1.1).
val translate_addr : (qword, PTAccess) -> qword
function translate_addr(linear, access) = {
  if CR0[31] == 0b0 then {
    linear  // Paging disabled: linear = physical
  } else if EFER[10] == 0b1 then {
    // IA-32e mode (long mode): 4-level or 5-level paging
    let is_write = access == PT_Write;
    match __tlb_lookup(linear, is_write) {
      Some(paddr) => paddr,
      None() => {
        let table_base : qword = CR3 & 0x000FFFFFFFFFF000;
        let start_level : range(0, 4) =
          if CR4[12] == 0b1 then 4 else 3;
        let paddr = pt_walk(linear, access, table_base, start_level);
        __tlb_insert(linear, paddr, is_write);
        paddr
      },
    }
  } else if CR4[5] == 0b1 then {
    // PAE paging (CR4.PAE=1, EFER.LMA=0)
    pt_walk_pae(linear, access)
  } else {
    // 32-bit non-PAE paging
    pt_walk_32(linear, access)
  }
}

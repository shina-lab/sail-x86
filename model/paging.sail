// x86-64 Sail Model — 4-Level Paging (Long Mode)
//
// Implements the IA-32e paging mechanism:
//   Virtual address → PML4 → PDPT → PD → PT → Physical address
//
// Page table walks use phys_read64 to avoid recursion through mem_read.
// Follows the sail-riscv pattern: translate_addr() returns physical address
// or throws Fault(EXN_PF, error_code) on failure.

// Raw physical memory read/write primitives.
// These are external functions provided by the execution environment.
val __read_mem : forall 'n, 'n > 0. (qword, int('n)) -> bits(8 * 'n)
val __write_mem : forall 'n, 'n > 0. (qword, int('n), bits(8 * 'n)) -> unit

// Physical memory access (bypass translation).
// Used by page table walks and by mem_read/mem_write when paging is off.
val phys_read : forall 'n, 'n > 0. (qword, int('n)) -> bits(8 * 'n)
function phys_read(addr, n) = __read_mem(addr, n)

val phys_write : forall 'n, 'n > 0. (qword, int('n), bits(8 * 'n)) -> unit
function phys_write(addr, n, data) = __write_mem(addr, n, data)

val phys_read64 : qword -> qword
function phys_read64(addr) = phys_read(addr, 8)

val phys_write64 : (qword, qword) -> unit
function phys_write64(addr, v) = phys_write(addr, 8, v)

// Access type for page table permission checks.
enum PTAccess = { PT_Read, PT_Write, PT_Execute }

// Build a #PF error code from access type and fault cause.
val mk_pf_error : (PTAccess, bool, bool) -> dword
function mk_pf_error(access, present, reserved) = {
  var ec : dword = 0x00000000;
  // Bit 0: P — page was present (permission violation vs not-present)
  if present then ec[0] = bitone;
  // Bit 1: W/R — write access caused the fault
  if access == PT_Write then ec[1] = bitone;
  // Bit 2: U/S — user-mode access caused the fault
  if cur_cpl == 3 then ec[2] = bitone;
  // Bit 3: RSVD — reserved bit set in PTE
  if reserved then ec[3] = bitone;
  // Bit 4: I/D — instruction fetch caused the fault
  if access == PT_Execute then ec[4] = bitone;
  ec
}

// Check permissions on a leaf PTE. Returns true if access is allowed.
val check_pte_permissions : (qword, PTAccess) -> bool
function check_pte_permissions(pte, access) = {
  let rw    = pte[1];  // Read/Write bit
  let us    = pte[2];  // User/Supervisor bit
  let xd    = pte[63]; // Execute-Disable bit (if EFER.NXE=1)

  // User-mode access to supervisor page: always denied
  if cur_cpl == 3 & us == bitzero then false
  // Write to read-only page:
  // - In user mode: always denied
  // - In kernel mode: denied if CR0.WP=1, allowed if WP=0
  else if access == PT_Write & rw == bitzero then {
    if cur_cpl == 3 then false
    else CR0[16] == bitzero  // WP=0 → allowed, WP=1 → denied
  }
  // Execute from XD page: denied if EFER.NXE=1
  else if access == PT_Execute & xd == bitone & EFER[11] == bitone then
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
  if pte[5] == bitzero then {
    new_pte[5] = bitone;
    changed = true
  };
  // Set Dirty bit for writes if not already set
  if access == PT_Write & pte[6] == bitzero then {
    new_pte[6] = bitone;
    changed = true
  };
  if changed then phys_write64(pte_addr, new_pte)
}

// 4-level page table walk.
// Walks PML4 → PDPT → PD → PT to translate a 64-bit linear address.
// On success, returns the physical address.
// On failure, throws Fault(EXN_PF, error_code).
//
// The `level` parameter counts down: 3=PML4, 2=PDPT, 1=PD, 0=PT.
val pt_walk : (qword, PTAccess, qword, range(0, 3)) -> qword
function pt_walk(linear, access, table_base, level) = {
  // 1. Compute index: 9 bits per level
  //    PML4: bits[47:39], PDPT: bits[38:30], PD: bits[29:21], PT: bits[20:12]
  let index : qword = match level {
    3 => zero_extend((linear[47..39]) : bits(9)),  // PML4 index
    2 => zero_extend((linear[38..30]) : bits(9)),  // PDPT index
    1 => zero_extend((linear[29..21]) : bits(9)),  // PD index
    0 => zero_extend((linear[20..12]) : bits(9)),  // PT index
  };
  let pte_addr : qword = table_base + (index << 3);

  // 2. Read PTE from physical memory (bypasses translation)
  let pte : qword = phys_read64(pte_addr);

  // 3. Check Present bit
  if pte[0] == bitzero then {
    CR2 = linear;
    throw Fault(EXN_PF, mk_pf_error(access, false, false))
  };

  // 4. Check reserved bits
  //    For non-leaf entries at levels 3,2,1: bits[12:51] are the next table base
  //    For leaf entries: PS=1 at level 1 (2MB) or level 2 (1GB)

  // 5. Check if this is a leaf entry
  let is_leaf : bool = if level == 0 then true
    else if 1 <= level & level <= 2 & pte[7] == bitone then true  // PS=1
    else false;

  if is_leaf then {
    // 6. Permission check
    if not_bool(check_pte_permissions(pte, access)) then {
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
    if pte[5] == bitzero then phys_write64(pte_addr, pte | 0x0000000000000020);
    pt_walk(linear, access, next_base, level - 1)
  } else {
    // level 0 non-leaf = impossible (always leaf)
    CR2 = linear;
    throw Fault(EXN_PF, mk_pf_error(access, true, true))
  }
}
termination_measure pt_walk(_, _, _, level) = level

// Simple software TLB for performance.
// 256-entry direct-mapped cache: VPN → PPN for 4KB pages.
// Each entry stores the full virtual page number (bits[63:12]) and
// the translated physical page number, plus a valid bit and write
// permission.  Flushed on CR3 write (in insn_baseline.sail).
//
// This is purely an optimization; removing it does not affect correctness.

val __tlb_lookup : (qword, bool) -> option(qword)
val __tlb_insert : (qword, qword, bool) -> unit
val __tlb_flush : unit -> unit

// Top-level address translation.
// If paging is disabled (CR0.PG=0), returns the linear address as-is.
// Otherwise, checks TLB first, then walks the page table starting from CR3.
val translate_addr : (qword, PTAccess) -> qword
function translate_addr(linear, access) = {
  if CR0[31] == bitzero then
    linear  // Paging disabled: linear = physical
  else {
    let is_write = access == PT_Write;
    match __tlb_lookup(linear, is_write) {
      Some(paddr) => paddr,
      None() => {
        let pml4_base : qword = CR3 & 0x000FFFFFFFFFF000;
        let paddr = pt_walk(linear, access, pml4_base, 3);
        // Only cache 4KB-aligned translations (common case)
        __tlb_insert(linear, paddr, is_write);
        paddr
      },
    }
  }
}

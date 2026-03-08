# Plan: Extending Sail x86 to Boot Linux

## Implementation Status

| Feature | Status | Notes |
|---------|--------|-------|
| System-emu directory skeleton | **Done** | `system-emu/` with separate binary |
| PhysicalMemory manager | **Done** | mmap-backed flat array, 512MB default |
| Control registers (CR0-CR4, EFER) | **Done** | Added to `regs.sail` with bit constants |
| Descriptor table registers (GDTR, IDTR, TR, LDTR) | **Done** | Added to `regs.sail` |
| KERNEL_GS_BASE register | **Done** | For SWAPGS |
| system_mode flag | **Done** | Selects fault delivery mode |
| Identity-mapped page tables | **Done** | 2MB pages, set up by C++ loader |
| Basic instruction execution on phys mem | **Done** | 10 tests passing |
| MSR register file | **Done** | EFER/FS_BASE/GS_BASE in Sail, rest in C++ map |
| Privileged instructions (MOV CR, LGDT, etc.) | **Done** | 12 instructions, 20 tests passing |
| Paging (page table walk in Sail) | **Done** | 4-level walk, A/D bits, WP, 4KB/2MB/1GB pages |
| Exception delivery via IDT | **Done** | IDT gate parsing, interrupt frame push, IF/TF/NT/RF clearing, SS←NULL, 7 tests |
| Device emulation (UART, PIC, PIT) | Not started | |
| Linux boot protocol loader | Not started | |

## Current State

The Sail x86 model is a **user-mode 64-bit** specification:

- **30K lines of Sail** covering ALU, SSE/AVX/AVX-512, x87, string ops, BMI, etc.
- **3K lines of C++** for the emulator (ELF loader, syscall emulation, main loop)
- **Flat memory model**: `mem_read`/`mem_write` go directly to host memory, no
  paging or segmentation
- **Single mode**: `cur_mode` is always `LongMode`, `cur_cpl` is always 3
- **No exception delivery**: faults return `Fault(vec, err)` to the emulator loop,
  which prints and exits
- **No system registers**: no CR0-CR4, no MSRs, no GDT/IDT/TSS

To boot Linux, the model must become a full **system-level** x86-64 specification.

### Development Philosophy

This project is a **formal specification** of x86-64, not just another emulator.
Every implementation detail must be verified against the Intel SDM (`~/sdm/`,
`~/sdm.pdf`). The SDM is the golden reference — never implement from memory alone.

### Reference: sail-riscv

The sail-riscv model (at `~/sail-riscv`) is a mature system-level Sail
specification that boots Linux. Its virtual memory subsystem totals ~1500 lines
of Sail across 5 files:

| File | Lines | Role |
|------|-------|------|
| `sys/vmem.sail` | ~430 | Top-level `translateAddr`, `pt_walk`, SATP handling |
| `sys/vmem_pte.sail` | ~180 | PTE bitfield parsing, permission checks |
| `sys/vmem_tlb.sail` | ~170 | 64-entry direct-mapped TLB |
| `sys/vmem_utils.sail` | ~50 | Type definitions |
| `sys/sys_control.sail` | ~420 | `trap_handler`, `exception_handler`, interrupt dispatch |

Key architectural patterns we should follow:

1. **Two-layer memory model**: `vmem_read`/`vmem_write` (virtual, called by
   instructions) → `translateAddr` → `mem_read`/`mem_write` (physical, also
   used directly by page table walks). We should adopt the same split.

2. **Translation as a standalone function**: `translateAddr(vaddr, access_type)`
   returns `Result(physaddr, ExceptionType)`. Identity mapping when paging is
   off (Bare mode) or in Machine mode. Our equivalent checks CR0.PG.

3. **Recursive page table walk**: `pt_walk()` is a recursive Sail function with
   `termination_measure` on the level counter. Reads PTEs via physical memory
   access (bypassing translation). Checks validity, permissions, superpage
   alignment at each level.

4. **TLB is explicit but optional**: A simple direct-mapped TLB modeled in Sail.
   Comments emphasize "not part of the architecture spec" but needed for (a)
   testing SFENCE.VMA/INVLPG and (b) performance — reduces Linux boot from
   tens of minutes to a few minutes. Code is structured so TLB can be ignored
   on first reading.

5. **Exception delivery is entirely in Sail**: `trap_handler()` saves
   PC/cause/tval to CSRs, computes new PC from the trap vector register
   (`mtvec`/`stvec`), and changes privilege level. No exit to the C++ harness.
   This is critical: the x86 equivalent must read the IDT and push a stack
   frame entirely within the Sail model.

6. **PTE A/D bit writeback**: After a successful walk, checks if Accessed/Dirty
   bits need updating. If so, writes the updated PTE back to physical memory
   and updates the TLB entry. Controlled by a platform flag
   (`plat_enable_dirty_update`).

---

## Phase 1: System Registers and Privileged Instructions

**Goal**: Model the system register file and basic privileged instructions so we
can represent a kernel's view of the CPU.

### 1.1 Control Registers (Sail)

Add to `regs.sail`:

```
register CR0 : qword   // PE, PG, WP, etc.
register CR2 : qword   // Page Fault Linear Address
register CR3 : qword   // Page table base
register CR4 : qword   // PAE, PSE, OSFXSR, OSXSAVE, etc.
register EFER : qword  // LME, LMA, SCE, NXE
```

Bit-field accessors for commonly tested bits:
- CR0: PE (0), MP (1), EM (2), TS (3), ET (4), NE (5), WP (16), AM (18),
  NW (29), CD (30), PG (31)
- CR4: VME (0), PVI (1), TSD (2), DE (3), PSE (4), PAE (5), MCE (6),
  PGE (7), PCE (8), OSFXSR (9), OSXMMEXCPT (10), FSGSBASE (16),
  PCIDE (17), OSXSAVE (18), LA57 (12)
- EFER: SCE (0), LME (8), LMA (10), NXE (11)

**Estimated effort**: 1-2 days

### 1.2 MSR Register File (Sail + C++)

Model MSRs as a key-value store (most are rarely accessed):

```
// In Sail: external functions
val __rdmsr : qword -> qword
val __wrmsr : (qword, qword) -> unit
```

Minimum MSRs needed for Linux boot:
- `IA32_EFER` (0xC0000080) — aliases EFER register
- `IA32_STAR` (0xC0000081) — SYSCALL target CS/SS
- `IA32_LSTAR` (0xC0000082) — SYSCALL 64-bit entry point
- `IA32_CSTAR` (0xC0000083) — SYSCALL compat entry point
- `IA32_FMASK` (0xC0000084) — SYSCALL RFLAGS mask
- `IA32_FS_BASE` (0xC0000100) — FS segment base
- `IA32_GS_BASE` (0xC0000101) — GS segment base
- `IA32_KERNEL_GS_BASE` (0xC0000102) — SWAPGS target
- `IA32_TSC` (0x10) — Timestamp counter
- `IA32_APIC_BASE` (0x1B) — APIC base address
- `IA32_PAT` (0x277) — Page Attribute Table
- `IA32_MISC_ENABLE` (0x1A0) — Miscellaneous enables
- `IA32_TSC_AUX` (0xC0000103) — RDTSCP auxiliary

Implement `RDMSR` and `WRMSR` instructions in `insn_dispatch.sail` (opcode 0F 32
and 0F 30). Both require CPL=0.

**Estimated effort**: 2-3 days

### 1.3 Privileged Instructions (Sail)

New instructions to add:

| Instruction | Opcode | Notes |
|-------------|--------|-------|
| MOV CR, reg | 0F 20/22 | Read/write CR0/CR2/CR3/CR4 |
| MOV DR, reg | 0F 21/23 | Debug registers (stub: store/load) |
| LGDT | 0F 01 /2 | Load GDT register |
| LIDT | 0F 01 /3 | Load IDT register |
| LLDT | 0F 00 /2 | Load LDT register |
| LTR | 0F 00 /3 | Load Task Register |
| SGDT | 0F 01 /0 | Store GDT register |
| SIDT | 0F 01 /1 | Store IDT register |
| SLDT | 0F 00 /0 | Store LDT register |
| STR | 0F 00 /1 | Store Task Register |
| LMSW | 0F 01 /6 | Load Machine Status Word |
| CLTS | 0F 06 | Clear TS flag in CR0 |
| INVLPG | 0F 01 /7 | Invalidate TLB entry |
| SWAPGS | 0F 01 F8 | Swap GS base with KernelGSBase MSR |
| WBINVD | 0F 09 | Write-back and invalidate cache (NOP) |
| HLT | F4 | Halt (already handled as `Halt`) |
| CLI/STI | FA/FB | Clear/set interrupt flag |
| RDMSR | 0F 32 | Read MSR |
| WRMSR | 0F 30 | Write MSR |
| IRET/IRETQ | CF | Return from interrupt |
| SYSRET | 0F 07 | Return from SYSCALL |

Add descriptor table registers:

```
register GDTR_base  : qword
register GDTR_limit : word
register IDTR_base  : qword
register IDTR_limit : word
register LDTR       : word    // selector
register TR         : word    // task register selector
```

All of these instructions must check `cur_cpl == 0` and raise #GP(0) otherwise.

**Estimated effort**: 1-2 weeks

### 1.4 CPL Enforcement

Add privilege checks to existing instructions:
- `IN`/`OUT`: check IOPL or I/O permission bitmap
- `CLI`/`STI`: check IOPL
- `HLT`: check CPL=0
- `INT n`: check IDT gate DPL vs CPL

Add to `step()` or as a helper:

```
val require_cpl0 : unit -> ExecutionResult
function require_cpl0() =
  if cur_cpl != 0 then raise_GP0() else Ok()
```

**Estimated effort**: 2-3 days

---

## Phase 2: Memory Model Restructuring

**Goal**: Split the flat memory model into virtual → linear → physical layers,
following the sail-riscv two-layer pattern.

### 2.1 Rename Current Memory Functions

The current `mem_read`/`mem_write` in `mem.sail` operate on linear addresses and
go directly to host memory. Rename them:

```
// Before (current names):
val mem_read  : forall 'n, 'n > 0. (qword, int('n)) -> bits(8 * 'n)
val mem_write : forall 'n, 'n > 0. (qword, int('n), bits(8 * 'n)) -> unit

// After (new names — same implementation):
val phys_read  : forall 'n, 'n > 0. (qword, int('n)) -> bits(8 * 'n)
val phys_write : forall 'n, 'n > 0. (qword, int('n), bits(8 * 'n)) -> unit
```

This is a mechanical rename across the codebase. The external C++ functions
`__read_mem`/`__write_mem` remain unchanged; only the Sail wrappers are renamed.

### 2.2 Add Virtual Memory Access Layer

New `mem_read`/`mem_write` functions that go through address translation:

```
// New mem_read: virtual address → translate → physical read
val mem_read : forall 'n, 'n > 0. (qword, int('n)) -> bits(8 * 'n)
function mem_read(vaddr, n) = {
  let paddr = translate_addr(vaddr, false, false);  // not write, not fetch
  phys_read(paddr, n)
}
```

This mirrors sail-riscv's `vmem_read` → `translateAddr` → `mem_read` chain.
All existing instruction code continues to call `mem_read`/`mem_write` unchanged.

### 2.3 Faulting Memory Access

Currently `mem_read` cannot fail. With paging, any memory access can trigger #PF.
We need a faulting variant:

```
union MemResult('n : Int) = {
  MR_Ok    : bits(8 * 'n),
  MR_Fault : (exception_vector, dword),  // e.g. #PF with error code
}

val mem_read_checked : forall 'n, 'n > 0. (qword, int('n)) -> MemResult('n)
```

In sail-riscv, memory faults bubble up as `Memory_Exception(vaddr, e)` in the
`ExecutionResult` type, caught by `try_step()`. We should do the same: add a
`MemFault` variant to our `ExecutionResult` union, or use Sail's exception
mechanism to throw faults from within `mem_read`.

**Recommended approach**: Use Sail exceptions (like we already do for the
15-byte instruction length check). A page fault during `mem_read` throws
`X86Fault(EXN_PF, error_code)`, which is caught by `step()`'s `try` block
and converted to `Fault(EXN_PF, error_code)`.

```
val mem_read : forall 'n, 'n > 0. (qword, int('n)) -> bits(8 * 'n)
function mem_read(vaddr, n) = {
  let paddr = translate_addr(vaddr, /*write=*/false, /*fetch=*/false);
  match paddr {
    TR_Ok(pa)       => phys_read(pa, n),
    TR_Fault(ec)    => { CR2 = vaddr; throw X86Fault(EXN_PF, ec) },
  }
}
```

This keeps all existing instruction code unchanged — `mem_read` still looks
like a non-faulting function to the caller, but the fault is caught at the
`step()` level. Same pattern sail-riscv uses.

### 2.4 Segment Translation (64-bit Only for MVP)

In 64-bit long mode, segmentation is mostly flat:
- DS/ES/CS/SS bases are forced to 0
- Only FS/GS have non-zero bases

We already handle FS/GS base addition in `insn_modrm.sail` during address
computation. No additional work is needed for the MVP path. Full segmentation
(Phase 5 below) is only needed for 32-bit mode.

**Estimated effort**: 3-5 days (mostly mechanical renaming + adding the
translate hook)

---

## Phase 3: Paging

**Goal**: Translate linear addresses to physical addresses through 4-level
(optionally 5-level) page tables.

### 3.1 Page Table Walk

Following the sail-riscv pattern, implement as a recursive function with a
`termination_measure` on the level:

```
union TranslateResult = {
  TR_Ok    : qword,         // physical address
  TR_Fault : dword,         // #PF error code
}

// Access type for page table permission checks
enum PTAccess = { PT_Read, PT_Write, PT_Execute }

val translate_addr : (qword, PTAccess) -> TranslateResult
function translate_addr(linear, access) =
  if CR0[31] == bitzero then  // PG bit
    TR_Ok(linear)             // paging disabled: linear = physical
  else
    pt_walk_4level(linear, access)

// Recursive 4-level page walk: PML4 → PDPT → PD → PT
val pt_walk : (qword, PTAccess, qword, range(0, 4)) -> TranslateResult
function pt_walk(linear, access, table_base, level) = {
  // 1. Compute index: 9 bits per level
  let shift = 12 + level * 9;
  let index = (linear >> shift) & 0x1FF;
  let pte_addr = table_base + index * 8;

  // 2. Read PTE from physical memory (bypasses translation, like sail-riscv)
  let pte = phys_read64(pte_addr);

  // 3. Check Present bit
  if pte[0] == bitzero then
    return TR_Fault(mk_pf_error(access, /*present=*/false));

  // 4. Check reserved bits
  ...

  // 5. If leaf (PS=1 for level 1/2, or level 0): check permissions, return
  if is_leaf_pte(pte, level) then {
    check_pte_permissions(pte, access, ...);
    update_accessed_dirty(pte_addr, pte, access);
    let ppn = extract_ppn(pte, level);
    let offset = linear & page_offset_mask(level);
    TR_Ok(ppn | offset)
  }
  // 6. Non-leaf: recurse to next level
  else if level > 0 then
    pt_walk(linear, access, pte & PTE_ADDR_MASK, level - 1)
  else
    TR_Fault(mk_pf_error(access, /*present=*/true))  // level 0 non-leaf = invalid
}

termination_measure pt_walk(_, _, _, level) = level
```

This is structurally identical to sail-riscv's `pt_walk()`, adapted for x86's
4-level page tables with 9-bit indices per level.

### 3.2 Page Table Entry Format

```
// PML4E / PDPTE / PDE / PTE share the same basic format:
// Bit  0: Present (P)
// Bit  1: Read/Write (R/W)
// Bit  2: User/Supervisor (U/S)
// Bit  3: Page-level Write-Through (PWT)
// Bit  4: Page-level Cache-Disable (PCD)
// Bit  5: Accessed (A)
// Bit  6: Dirty (D) — PTE/large page only
// Bit  7: Page Size (PS) — PDE=2MB, PDPTE=1GB; PAT for 4KB PTE
// Bits 12-51: Physical address of next level / page frame
// Bit 63: Execute-Disable (XD) — if EFER.NXE=1
```

### 3.3 PTE Permission Checks

```
val check_pte_permissions : (qword, PTAccess) -> TranslateResult
// - Write to read-only page: fault if CR0.WP=1 or CPL=3
// - User access to supervisor page: fault
// - Execute from XD page: fault if EFER.NXE=1
// - Supervisor access to user page: always allowed for read/write
//   (SMAP/SMEP can be deferred)
```

#PF error code bits:
- Bit 0 (P): 1 if page was present (permission violation), 0 if not present
- Bit 1 (W/R): 1 if write access caused fault
- Bit 2 (U/S): 1 if user-mode access caused fault
- Bit 3 (RSVD): 1 if reserved bit set in PTE
- Bit 4 (I/D): 1 if instruction fetch caused fault (requires EFER.NXE)

### 3.4 Accessed/Dirty Bit Updates

Following sail-riscv's pattern: after a successful permission check, update
A and D bits in the PTE if not already set, writing back to physical memory:

```
val update_accessed_dirty : (qword, qword, PTAccess) -> unit
function update_accessed_dirty(pte_addr, pte, access) = {
  var new_pte = pte;
  if pte[5] == bitzero then new_pte[5] = bitone;  // Set Accessed
  if access == PT_Write & pte[6] == bitzero then
    new_pte[6] = bitone;  // Set Dirty
  if new_pte != pte then
    phys_write64(pte_addr, new_pte)
}
```

### 3.5 Physical Memory Manager (C++)

Replace the current identity-mapped host memory with a dedicated guest physical
address space:

```cpp
class PhysicalMemory {
  uint8_t *ram;         // guest RAM (e.g. 512MB)
  size_t ram_size;

  // MMIO regions (Phase 6)
  struct MMIORegion {
    uint64_t base, size;
    Device *handler;
  };
  std::vector<MMIORegion> mmio;

  uint8_t read8(uint64_t paddr);
  void write8(uint64_t paddr, uint8_t val);
  // ... 16/32/64-bit variants
};
```

The `__read_mem`/`__write_mem` external functions in the C++ backend dispatch
to this instead of raw host pointers.

**Option A (simple)**: Single `mmap`-ed 512MB array. Physical addresses index
directly into it. Out-of-range reads return 0xFF, writes are ignored.

**Option B (sparse)**: Page-granularity allocation. More memory-efficient but
adds a layer of indirection. Not needed for MVP.

Recommend **Option A** for simplicity. sail-riscv also uses a simple flat array
for physical memory.

### 3.6 TLB (Optional Performance Optimization)

Following sail-riscv: a direct-mapped TLB of 64 entries, modeled in Sail.

```
struct TLBEntry = {
  vpn   : qword,    // virtual page number (linear >> 12)
  ppn   : qword,    // physical page number
  pte   : qword,    // cached PTE (for permission re-checks)
  level : range(0, 4),  // page size level (0=4KB, 1=2MB, 2=1GB)
  global : bool,    // PTE.G bit (survives CR3 switch)
  pcid  : word,     // Process Context ID (if CR4.PCIDE)
}

register tlb : vector(64, option(TLBEntry)) = vector_init(None())
```

sail-riscv reports a **~10x speedup** for Linux boot with their 64-entry TLB.
Their approach:

- `lookup_TLB`: hash VPN to get index, check tag match + ASID/global
- `add_to_TLB`: insert after successful page walk
- `flush_TLB`: iterate all entries, selectively invalidate by ASID/address
- On `INVLPG`: flush matching entry
- On `MOV CR3`: flush all non-global entries

We can start without TLB (walk page tables every access) and add it later.
The code should be structured so TLB is clearly separable, as sail-riscv does.

**Estimated effort**: 3-4 weeks (walk + integration; TLB adds ~1 week on top)

---

## Phase 4: Exception and Interrupt Delivery

**Goal**: When a fault/trap/interrupt occurs, deliver it to the OS handler
entirely within the Sail model, following the sail-riscv pattern where
`trap_handler()` updates CSRs and redirects PC without exiting to C++.

### 4.1 IDT Lookup

```
struct IDTGate = {
  offset    : qword,        // handler RIP (16 + 16 + 32 bits assembled)
  selector  : word,         // target CS selector
  ist       : range(0, 7),  // IST index (0 = use legacy stack switching)
  gate_type : bits(4),      // 0xE = 64-bit interrupt gate, 0xF = trap gate
  dpl       : range(0, 3),  // gate DPL (for software INT privilege check)
  present   : bool,
}

val read_idt_gate : exception_vector -> option(IDTGate)
// Read 16-byte gate descriptor from IDTR_base + vector * 16
// Parse the scattered offset field: bits[15:0] @ bits[31:16] @ bits[63:32]
```

### 4.2 Exception Delivery (x86 vs RISC-V)

In sail-riscv, `trap_handler()` is simple:
1. Save PC to `mepc`/`sepc`
2. Save cause to `mcause`/`scause`
3. Save trap value to `mtval`/`stval`
4. Compute new PC from `mtvec`/`stvec`
5. Update privilege level and `mstatus` bits

x86 exception delivery is more complex because it pushes a stack frame:

```
val deliver_exception : (exception_vector, dword) -> ExecutionResult
function deliver_exception(vec, err_code) = {
  let gate = read_idt_gate(vec);

  // 1. Check gate present; if not, #GP(vector * 8 + 2)
  // 2. If software INT (INT n), check gate.dpl >= CPL; if not, #GP

  // 3. Determine new stack
  let new_rsp = if gate.ist != 0 then
    read_tss_ist(gate.ist)     // IST stack from TSS
  else if privilege_change then
    read_tss_rsp0()            // RSP0 from TSS
  else
    read_gpr64(RSP);           // same stack

  // 4. Push interrupt frame onto new stack (using phys_write through paging)
  //    Old SS, Old RSP, RFLAGS, CS, RIP
  //    If exception has error code, push that too
  push_to_stack(new_rsp, old_ss);
  push_to_stack(new_rsp, old_rsp);
  push_to_stack(new_rsp, rflags);
  push_to_stack(new_rsp, old_cs);
  push_to_stack(new_rsp, old_rip);
  if has_error_code(vec) then
    push_to_stack(new_rsp, err_code);

  // 5. Load new CS from gate.selector (load segment descriptor cache)
  // 6. Load new RIP from gate.offset
  // 7. If interrupt gate (not trap gate), clear IF
  // 8. Set CPL = gate.selector.DPL (typically 0 for kernel)

  Ok()
}
```

Note the critical difference from sail-riscv: x86 must **write to the new stack
through the paging mechanism**. This means the stack push itself can fault
(double fault → triple fault). sail-riscv doesn't have this problem because
trap delivery only writes to CSRs, not memory.

### 4.3 Double Fault and Triple Fault

If exception delivery itself causes a fault:
- Most exceptions during delivery → #DF (double fault, vector 8)
- Fault during #DF delivery → triple fault (CPU reset/halt)

For MVP, we can simplify: if exception delivery faults, halt the emulator with
a "triple fault" message. Full double-fault handling can come later.

### 4.4 IRET/IRETQ

Return from interrupt — reverse of exception delivery:
- Pop RIP, CS, RFLAGS from stack
- If returning to different privilege level, also pop RSP, SS
- Validate CS descriptor, check DPL
- Restore IF from saved RFLAGS (if was trap gate)

### 4.5 Modify step() Loop

Currently:

```
match result {
  Ok(_)            => RIP = ...,
  Fault(vec, err)  => (),           // return fault to C++ emulator
  Halt(_)          => (),           // SYSCALL trap to C++
}
```

Change to (in system mode):

```
match result {
  Ok(_)            => RIP = ...,
  Fault(vec, err)  => {
    // Deliver exception entirely in Sail, like sail-riscv's trap_handler()
    deliver_exception(vec, err);
    // RIP now points to the OS handler
  },
  Halt(_)          => ...,          // HLT instruction: wait for interrupt
}
```

In user-mode emulation, `Fault` continues to exit to C++ as before.
The behavior is selected by a mode flag (system vs user-mode emulation).

### 4.6 Interrupt Injection

External interrupts (timer, I/O) are checked between instructions, similar to
sail-riscv's `dispatchInterrupt()`:

```
// At the top of step(), before fetching:
if IF_flag & pending_interrupt() then {
  let vec = acknowledge_interrupt();
  deliver_exception(vec, 0x00000000);
  return Ok()  // skip normal fetch-decode-execute
}
```

The C++ emulator sets a flag when a device raises an interrupt. The Sail model
checks this flag at the start of each step.

**Estimated effort**: 3-4 weeks

---

## Phase 5: Segmentation and Mode Switching (Deferrable)

**Goal**: Support transitions between real mode, protected mode, and long mode
so the Linux boot sequence works. **Not needed for MVP** if we use the 64-bit
direct boot protocol.

### 5.1 Segment Descriptor Cache

Each segment register has a hidden "descriptor cache" that holds the decoded
descriptor:

```
struct SegDescCache = {
  base   : qword,   // segment base address
  limit  : dword,   // segment limit (in bytes, after granularity)
  access : byte,    // access byte (P, DPL, S, type)
  flags  : byte,    // flags (G, D/B, L, AVL)
  sel    : word,    // the selector value
}

register SegCache : vector(6, SegDescCache)
```

### 5.2 Descriptor Table Access

```
val load_descriptor : word -> option(SegDescCache)
// Reads 8-byte descriptor from GDTR_base + (selector & 0xFFF8)
// Parses base, limit, access, flags
// Returns None if selector is null or out of bounds
```

### 5.3 Segment Loading

When `MOV segreg, val` or far JMP/CALL/RET loads a segment:
- Look up descriptor in GDT/LDT
- Check DPL vs CPL vs RPL
- Check segment type (code vs data, readable, writable)
- Load descriptor cache
- Mark segment present

### 5.4 Mode Transitions

**Real Mode → Protected Mode**: Set CR0.PE = 1
**Protected Mode → Long Mode**: Set CR4.PAE=1, EFER.LME=1, CR0.PG=1

### 5.5 Decoder Mode Awareness

| Mode | Default opsize | Default addrsize | REX available |
|------|---------------|-------------------|---------------|
| Real | 16-bit | 16-bit | No |
| Protected (CS.D=0) | 16-bit | 16-bit | No |
| Protected (CS.D=1) | 32-bit | 32-bit | No |
| Compatibility | 32-bit | 32-bit | No |
| Long (64-bit) | 32-bit | 64-bit | Yes |

Changes needed in `scan_prefixes()` and `dispatch_opcode_1byte()`:
- 16-bit mode: opcodes 0x40-0x4F are INC/DEC, not REX
- 16-bit address mode: ModR/M uses BX+SI, BX+DI, BP+SI, BP+DI (no SIB)
- Operand size defaults change

**Estimated effort**: 4-6 weeks (16-bit mode is the bulk of the work)

---

## Phase 6: Device Emulation (C++)

**Goal**: Provide the minimal hardware devices needed for Linux to boot.

### 6.1 Serial Port (UART 16550A)

Minimum for console output. Linux uses `earlycon=uart8250,io,0x3f8`:

```cpp
class UART {
  uint8_t rbr, thr, ier, iir, lcr, mcr, lsr, msr, scr;
  uint8_t dll, dlm;  // divisor latch
  bool dlab;

  uint8_t read(uint16_t port);
  void write(uint16_t port, uint8_t val);
};
```

Only need TX (output) for initial bring-up. RX (input) can come later.

Port range: 0x3F8-0x3FF (COM1).

### 6.2 Interrupt Controller

**Option A (simpler): Legacy 8259 PIC**
- Two cascaded PICs: master (ports 0x20-0x21), slave (ports 0xA0-0xA1)
- ICW1-ICW4 initialization, OCW1-OCW3 operation
- IRQ masking, in-service register, priority rotation

**Option B (modern): Local APIC + I/O APIC**
- Local APIC: MMIO at 0xFEE00000 (timer, IPI, EOI)
- I/O APIC: MMIO at 0xFEC00000 (interrupt routing)
- MSR-based APIC access (x2APIC)

Linux boots with PIC first, then switches to APIC. Need at least PIC for early
boot. APIC can be added incrementally.

### 6.3 Timer

**PIT 8253/8254** (ports 0x40-0x43):
- Channel 0: system timer (IRQ 0)
- Modes 0, 2, 3 are commonly used
- Linux reads PIT for initial calibration

Later: **Local APIC timer** (for proper scheduling).

### 6.4 Keyboard Controller (8042)

Minimal stub for boot:
- Port 0x64: status register (report "no data available")
- Port 0x60: data register
- Linux probes this during boot; must not hang

### 6.5 Disk Controller

Use **initramfs** (load ramdisk into memory at boot, no disk device needed).
Recommend this for MVP: embed the initramfs in guest memory and pass it via
boot protocol. No disk driver needed.

### 6.6 Port I/O and MMIO Dispatch

The Sail model already has external stubs for `__port_in*`/`__port_out*`. The
C++ emulator must route these to device handlers:

```cpp
uint8_t port_in8(uint16_t port) {
  if (0x3F8 <= port && port <= 0x3FF) return uart.read(port);
  if (0x20 <= port && port <= 0x21)   return pic_master.read(port);
  if (0xA0 <= port && port <= 0xA1)   return pic_slave.read(port);
  if (0x40 <= port && port <= 0x43)   return pit.read(port);
  if (port == 0x60 || port == 0x64)   return kbd.read(port);
  return 0xFF;  // default: empty bus
}
```

For MMIO (APIC, etc.), the `PhysicalMemory` class dispatches accesses to
registered MMIO regions before falling through to RAM, following the
sail-riscv pattern in `checked_mem_read`/`checked_mem_write` where
`within_mmio_readable` → `mmio_read`, else `read_ram`.

**Estimated effort**: 4-6 weeks

---

## Phase 7: Boot Protocol

**Goal**: Load and start a Linux kernel image.

### 7.1 Direct Boot (Linux Boot Protocol)

Instead of implementing a full BIOS/UEFI, use the Linux x86 boot protocol
directly:

1. Load `bzImage` into guest memory following the boot protocol:
   - Real-mode code at 0x10000 (or skip it)
   - Protected-mode kernel at 0x100000
   - Initramfs at a high address (e.g. above kernel)
2. Set up the boot parameters struct at a known address:
   - `struct boot_params` (documented in `Documentation/x86/boot.rst`)
   - Command line, initramfs location/size, memory map (E820)
   - Hardware info (video mode = text mode, boot loader ID)
3. Jump to the 32-bit or 64-bit kernel entry point directly

This **skips real-mode entirely** if we use the 64-bit boot protocol
(boot protocol version 2.12+, entry point at `startup_64`).

### 7.2 Minimal Boot (Skip 16-bit Mode)

If we skip real mode / BIOS:
1. Set up identity-mapped page tables in guest memory
2. Set CR3, enable paging, set EFER.LME+LMA
3. Start in long mode at kernel's 64-bit entry point
4. Provide `struct boot_params` in RSI

This avoids implementing 16-bit mode entirely (Phase 5 becomes optional for
the initial boot).

### 7.3 E820 Memory Map

Linux expects an E820 memory map in boot_params. Provide a simple one:

```
[0x00000000 - 0x0009FFFF] : usable (640K conventional)
[0x000A0000 - 0x000FFFFF] : reserved (VGA + ROM)
[0x00100000 - 0x1FFFFFFF] : usable (511MB)
[0xFEC00000 - 0xFECFFFFF] : reserved (I/O APIC)
[0xFEE00000 - 0xFEEFFFFF] : reserved (Local APIC)
```

**Estimated effort**: 1-2 weeks

---

## Phase 8: Integration and Debugging

### 8.1 Instruction Tracing

Add a verbose trace mode that logs:
- RIP, instruction bytes, disassembly (via external disassembler)
- Register state changes
- Memory accesses (linear → physical translation)
- Exceptions and interrupt delivery

### 8.2 GDB Stub

Implement a GDB remote protocol stub so we can attach GDB to the emulator:
- Set breakpoints at kernel addresses
- Inspect registers and memory
- Single-step through boot code

### 8.3 Comparison with QEMU

Run the same kernel+initramfs in QEMU with `-d in_asm,int` tracing and compare
instruction-by-instruction against our emulator. This is the system-level
equivalent of our KVM differential testing.

### 8.4 Common Boot Failures

Expected issues and how to debug them:
- **Triple fault at boot**: usually missing IDT setup or bad page table
- **Hang at calibration**: timer device not ticking
- **Panic "unable to mount root"**: initramfs not provided or at wrong address
- **Panic "unknown MSR"**: kernel probing unsupported MSR → add stub
- **Silent hang**: serial port not working → check port I/O dispatch

**Estimated effort**: 4-8 weeks (ongoing throughout development)

---

## Recommended Implementation Order

The phases above can be partially parallelized and some can be deferred:

### MVP Path (minimum to boot Linux to a shell)

```
Phase 1  (system regs)          ████░░░░░░░░  2 weeks
Phase 2  (memory restructure)   ░██░░░░░░░░░  1 week
Phase 3  (paging)               ░░████░░░░░░  3 weeks
Phase 4  (exceptions)           ░░░░░████░░░  3 weeks
Phase 6  (devices)              ░░░░░░░████░  3 weeks
Phase 7  (boot protocol)        ░░░░░░░░░██░  1 week
Phase 8  (debugging)            ░░░░████████  ongoing
                                ──────────────────────
                                ~13 weeks of focused work
```

**Key shortcut**: Use the 64-bit direct boot protocol (Phase 7.2) to skip
real mode and 16-bit protected mode entirely. This eliminates Phase 5 from
the critical path.

### What can be deferred

- **16-bit real mode** (Phase 5): not needed if using direct boot
- **32-bit protected mode** (Phase 5): not needed if using 64-bit entry
- **Full segmentation** (Phase 5): 64-bit mode only needs FS/GS base (already done)
- **APIC** (Phase 6.2 Option B): PIC is enough for single-core boot
- **TLB** (Phase 3.6): correctness first, performance later
- **SMP**: boot with `maxcpus=1`
- **Disk I/O**: use initramfs instead

### What cannot be deferred

- **Paging**: Linux requires it from the first instruction
- **Exception delivery**: every page fault must invoke the kernel handler
- **Timer interrupt**: Linux needs timer ticks for scheduling
- **Serial output**: otherwise you can't see what's happening
- **MSRs**: Linux reads/writes many MSRs during early boot

---

## Estimated Total Effort

| Path | Effort | Result |
|------|--------|--------|
| MVP (64-bit direct boot) | ~3-4 months | Boot to shell with initramfs |
| Full modes (add 16/32-bit) | +2-3 months | Support real BIOS/UEFI boot |
| SMP support | +1-2 months | Multi-core Linux |
| Full device model | +2-3 months | Disk, network, display |

The MVP path is achievable in **3-4 months** of focused single-person work.
The largest individual pieces are paging (~3 weeks) and exception delivery
(~3 weeks), both of which are architecturally invasive changes to the model.

---

## Impact on Existing Code

### Sail model changes

- `mem.sail`: Rename `mem_read`/`mem_write` to `phys_read`/`phys_write`. New
  `mem_read`/`mem_write` call `translate_addr` then `phys_*`. Page table walks
  use `phys_*` directly (same pattern as sail-riscv). Page faults throw Sail
  exceptions caught by `step()`.
- `regs.sail`: Add CR0-CR4, EFER, GDTR, IDTR, TR, LDTR, segment descriptor
  caches.
- `exceptions.sail`: Add `deliver_exception` with IDT lookup and stack frame
  push.
- `fetch_execute.sail`: `step()` must call `deliver_exception` on `Fault`
  instead of returning it (in system mode).
- `insn_dispatch.sail`: Add privileged instruction opcodes (0F 00-09, 0F 20-23,
  0F 30-32).
- New file `paging.sail` (~500 lines): Page table walk, PTE parsing, permission
  checks. Follows sail-riscv's `vmem.sail` + `vmem_pte.sail` structure.
- New file `tlb.sail` (~200 lines): Optional TLB, following sail-riscv's
  `vmem_tlb.sail`.
- New file `interrupts.sail` (~300 lines): IDT lookup, exception delivery,
  IRET, interrupt injection.
- New file `sysregs.sail` (~200 lines): CR/MSR read/write logic, mode
  transition validation.

### C++ emulator changes

- `x86_sim.cpp`: Add system-mode entry point (load kernel instead of ELF),
  separate from user-mode.
- New `x86_phys_mem.cpp`: Physical memory manager with MMIO dispatch.
  Replaces raw host-memory access in `__read_mem`/`__write_mem`.
- New `x86_devices.cpp`: UART, PIC, PIT, keyboard controller stubs.
- New `x86_boot.cpp`: Linux boot protocol loader.
- `x86_platform_impl.h`: Wire `__read_mem`/`__write_mem` through physical
  memory manager in system mode.

### KVM test harness

The existing KVM tests continue to work unchanged (they test user-mode
instruction semantics in a flat-memory environment). New system-level tests
can be added for:
- Page table walk correctness
- Exception delivery (vector, error code, stack frame)
- Privilege level transitions
- MSR read/write behavior

### Backward compatibility

The user-mode emulator continues to work as-is. The system-mode emulator is
a separate binary or a command-line flag (`--system` vs default user-mode).
In user mode, `mem_read`/`mem_write` bypass paging (CR0.PG=0), so the rename
from Phase 2 is transparent.

---

## Appendix: Comparative Analysis (sail-riscv and sail-arm)

This section documents findings from studying sail-riscv (`~/sail-riscv`) and
sail-arm (`~/sail-arm/arm-v9.4-a`), both of which successfully boot Linux.

### Missing Tasks Identified

The following tasks are **not in the plan above** but are present in both
reference implementations and likely needed:

1. **Instruction fetch through paging**: sail-riscv's `fetch.sail` calls
   `translateAddr(PC, InstructionFetch())` to fetch instructions through the
   page table. Our Phase 3 only discusses data access translation. The `step()`
   function must also translate RIP before fetching instruction bytes, and an
   instruction fetch that crosses a page boundary needs two translations. This
   is more complex than RISC-V (fixed 2/4-byte instructions) because x86
   instructions can be up to 15 bytes and straddle pages.

2. **Timer tick integration**: Both implementations have a `tick_clock()` or
   `__UpdateSystemCounter()` function called after each instruction (or every
   N instructions). sail-riscv's `tick_clock()` increments `mtime` and calls
   `clint_dispatch()` which sets timer interrupt pending bits. sail-arm's
   `__CycleEnd()` calls `__UpdateSystemCounter()` → `GenericCounterTick()`.
   Our plan mentions "timer interrupt" but doesn't describe the tick mechanism.
   The C++ main loop must increment a cycle counter and check timer expiry to
   set IRQ pending.

3. **Init/reset sequence**: sail-riscv has a structured `init_model()` →
   `init_platform()` → `reset()` → `reset_sys()` → `reset_vmem()` sequence.
   sail-arm has `__InitSystem()`. Our Phase 7 describes loading the kernel but
   not the CPU initialization sequence: setting default register values (CR0
   initial state, segment registers, IDTR, etc.) before the first instruction.
   x86 has a well-defined RESET state (real mode, CS:IP = F000:FFF0) though
   we bypass this with direct boot.

4. **MMIO dispatch in Sail vs C++**: Both sail-riscv and sail-arm model MMIO
   devices **in Sail**, not in C++. sail-riscv's `platform.sail` has CLINT and
   HTIF entirely in Sail with `mmio_read`/`mmio_write` dispatching by physical
   address range. sail-arm's `mem.sail` dispatches to `__ReadGIC`/`__WriteGIC`
   and `__ReadUART`/`__WriteUART` based on physical address. Our Phase 6
   proposes devices in C++, which works but means device behavior isn't
   formally specified. Consider: at minimum, the MMIO **dispatch** logic should
   be in Sail (`phys_read`/`phys_write` check address ranges), even if device
   implementations call external C++ functions.

5. **WFI/HLT handling**: sail-riscv has explicit `Hart_Waiting` state for WFI
   (Wait For Interrupt). The main loop checks if the hart is waiting and only
   advances the timer without executing instructions. Our plan mentions HLT
   but doesn't describe the waiting state. The C++ loop must: on HLT, spin
   advancing the timer until an interrupt becomes pending.

6. **Interrupt priority and masking**: sail-riscv's `dispatchInterrupt()`
   checks interrupt enable bits (mie/sie), delegation (mideleg), and priority.
   sail-arm checks `IRQPending()`, `FIQPending()` in `TakePendingInterrupts()`.
   Our Phase 4.6 sketch is too simple — x86 has RFLAGS.IF, PIC IMR (interrupt
   mask register), and NMI vs maskable interrupt priority. The PIC model needs
   interrupt priority resolution.

7. **Tracing/debugging callbacks**: sail-riscv has a `PlatformInterface` C++
   class with virtual methods for every significant event: fetch, mem_read,
   mem_write, register_write, ptw_step, trap. Extensible tracing via
   `--trace-instr`, `--trace-mem`, `--trace-ptw`, etc. Our Phase 8 mentions
   tracing but doesn't describe the infrastructure. Having structured callbacks
   from the start will save enormous debugging time.

### Useful Techniques to Adopt

1. **sail-riscv's `termination_measure`**: The recursive page table walk uses
   `termination_measure pt_walk(_, _, _, level) = level` to prove termination
   to Sail's type checker. We must do the same for our 4-level walk.

2. **TLB as correctness feature, not just performance**: sail-riscv's TLB
   enables testing `SFENCE.VMA` (our `INVLPG`). Without a TLB, INVLPG is a
   no-op and we can't test that the kernel correctly invalidates stale mappings.
   Consider adding TLB earlier than "optional optimization."

3. **sail-arm's exception-based control flow**: sail-arm uses Sail exceptions
   extensively for control flow — `IsExceptionTaken(exn)`, `IsSEE(exn)`,
   `IsUNDEFINED(exn)` caught in try/catch blocks. We already use this pattern
   for `X86Fault`. Extend it: exception delivery itself should use the same
   mechanism (throw `X86Fault` from within `deliver_exception` if the stack
   push faults → caught at outer level for double fault handling).

4. **sail-riscv's phys_mem separation**: Physical memory reads during page
   table walks use `mem_read_priv(PRV_M, ...)` which bypasses virtual address
   translation (Machine mode = no paging). Our `phys_read`/`phys_write` serve
   the same role. Important: page table walks must NEVER go through
   `translate_addr` or we get infinite recursion.

5. **Platform configuration**: sail-riscv uses a JSON config system
   (`config.json`) with `register pma_regions : list(PMA_Region) = config
   memory.regions` to configure memory regions at load time. For our MVP, this
   is over-engineering, but keeping memory region definitions (RAM range, MMIO
   ranges) in a single configuration struct will help.

6. **sail-riscv's `init_boot_requirements()`**: Sets `a0 = mhartid`,
   `a1 = &dtb` per Linux boot convention. Our equivalent: set RSI to point to
   `struct boot_params` per the x86 boot protocol.

### Architectural Differences: x86 vs RISC-V

These differences make the x86 implementation harder than sail-riscv in
specific areas:

| Aspect | RISC-V | x86-64 | Impact |
|--------|--------|--------|--------|
| **Exception delivery** | Write 4 CSRs (mepc, mcause, mtval, mstatus) | Read IDT (memory), push stack frame (memory), load TSS for RSP0 (memory) | x86 is 10x more complex; stack push can itself fault |
| **Page table format** | Sv39/Sv48: 3-4 levels, uniform 8-byte PTEs | 4-5 levels, 8-byte PTEs but with PS (huge page) at different levels | Similar complexity, but x86 has more edge cases (PSE, PAT, PCID) |
| **Instruction fetch** | Fixed 2/4-byte, always aligned or at most spans 2 bytes | Variable 1-15 bytes, can cross page boundaries | x86 needs split-page fetch with two translations |
| **Segmentation** | None | Full segmentation (mostly flat in 64-bit, but CS/SS still checked) | Extra layer; segment loads during exception delivery |
| **I/O model** | Memory-mapped only | Port I/O + memory-mapped | Two dispatch mechanisms needed |
| **Privilege levels** | M/S/U (3 levels, simple nesting) | Ring 0-3 (4 levels) + IOPL + CPL/DPL/RPL checks | More complex privilege checks |
| **Stack switching** | Write `sscratch` CSR (no memory access) | Read RSP0 from TSS (memory access) | TSS is another memory structure to parse |
| **TLB invalidation** | `SFENCE.VMA` with optional ASID/addr | `INVLPG` (single page), `MOV CR3` (flush all), `INVPCID` | More invalidation variants |
| **Timer** | `mtime` register + `mtimecmp` comparison | PIT (port I/O, counter modes) or APIC timer (MMIO) | x86 timers are more complex devices |
| **Interrupt controller** | PLIC/CLINT: simple priority + enable bits | 8259 PIC: edge/level, cascade, rotation, specific EOI | PIC has more states and modes |

### Key Risk: Exception Delivery Complexity

The single biggest difference is exception delivery. In sail-riscv, it's ~50
lines of Sail that write CSRs. In x86, it requires:

1. Reading a 16-byte IDT gate descriptor from memory (through paging)
2. If privilege change: reading RSP0/IST from the TSS (through paging)
3. Pushing 5-6 qwords onto the new stack (through paging)
4. Loading a new CS segment (reading GDT, through paging)
5. If any of steps 1-4 fault: double fault (#DF) handling
6. If #DF delivery faults: triple fault (reset)

Each of the "through paging" steps can itself cause a page fault, creating a
re-entrant situation that sail-riscv never faces. The double/triple fault
logic must be carefully designed.

**Recommendation**: Implement exception delivery in layers:
- Layer 1 (MVP): Assume kernel stacks are always mapped. If exception delivery
  faults, print diagnostic and halt (treat as triple fault). This is sufficient
  for initial Linux boot since the kernel keeps its stacks mapped.
- Layer 2: Proper double fault → #DF with IST stack.
- Layer 3: Triple fault → CPU reset.

### Organizational Patterns

**sail-riscv file organization** (relevant subset):
```
model/
  prelude/         # types, bitfield helpers
  sys/             # system-level: paging, traps, platform
    vmem.sail      # virtual memory translation
    vmem_pte.sail  # PTE format and checks
    vmem_tlb.sail  # TLB model
    sys_control.sail  # trap/exception delivery
    platform.sail  # CLINT, HTIF devices
    pma.sail       # physical memory attributes
    mem.sail       # vmem_read/vmem_write (virtual layer)
  postlude/
    step.sail      # main loop, fetch-decode-execute
    fetch.sail     # instruction fetch (through paging)
    model.sail     # init, reset
```

**sail-arm file organization** (relevant subset):
```
src/
  devices.sail     # GIC, UART (all in Sail)
  mem.sail         # MMIO dispatch + physical read/write
  fetch.sail       # fetch + decode + execute + exception handling
  elfmain.sail     # main loop
  reset.sail       # CPU reset state
```

**Recommended organization for sail-x86** (new files):
```
model/
  paging.sail      # translate_addr, pt_walk, PTE checks (~500 lines)
  tlb.sail         # TLB model (~200 lines)
  interrupts.sail  # IDT lookup, deliver_exception, IRET (~400 lines)
  sysregs.sail     # CR/MSR/descriptor table logic (~300 lines)
  privileged.sail  # privileged instructions (~500 lines)
```

### Summary of Recommendations

1. **Add instruction fetch paging** to Phase 3 (not just data access)
2. **Add timer tick mechanism** to Phase 6 (C++ loop increments counter, checks
   timer expiry, sets IRQ pending)
3. **Add CPU init/reset sequence** to Phase 7 (set CR0/EFER/segment initial
   values before first instruction)
4. **Move MMIO dispatch to Sail** or at least have Sail dispatch to external
   C++ device functions (hybrid approach, like sail-arm)
5. **Add WFI/HLT waiting state** to Phase 4 (C++ loop spins on timer until
   interrupt pending)
6. **Add tracing callbacks** early (Phase 1-2) — will save weeks of debugging
7. **Implement exception delivery in layers** (MVP: halt on delivery fault;
   later: proper double/triple fault)
8. **Plan for TLB early** in the code structure even if implementation is
   deferred (keep translate_addr → TLB lookup → pt_walk separation from day 1)
9. **Add interrupt priority/masking** detail to Phase 4 (RFLAGS.IF, PIC IMR,
   NMI handling)

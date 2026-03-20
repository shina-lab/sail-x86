// Tests for 4-level and 5-level paging (page table walk, permission checks, A/D bits).

#include "sail_x86_model.h"
#include "x86-helpers.h"
#include <cassert>
#include <cstdio>
#include <cstring>

static void init_model(x86::Model &model, u64 ram_size = 16 * 1024 * 1024) {
  model.model_init();
  model.zinitializze_registers(UNIT);
  enable_all_features(model);

  // Paging tests use system_mode=false so faults are returned to C++
  // for inspection (no IDT setup needed).
  model.zsystem_mode = false;
  model.zcur_mode = x86::zLongMode;
  model.zcur_cpl = 0;
  model.zSegCache.data[x86::SEG_CS].zseg_l = 1;

  model.zCR0 = (1UL << 0) | (1UL << 4) | (1UL << 5) | (1UL << 16) | (1UL << 31);
  model.zCR4 = (1UL << 5) | (1UL << 9);
  model.zEFER = (1UL << 0) | (1UL << 8) | (1UL << 10) | (1UL << 11);

  assert(model.phys_mem.init(ram_size));

  for (int i = 0; i < 16; i++)
    model.zGPR.data[i] = 0;
  model.zGPR.data[4] = 0x80000;

  model.zGDTR_base = 0;
  model.zGDTR_limit = 0;
  model.zIDTR_base = 0;
  model.zIDTR_limit = 0;
  model.zKERNEL_GS_BASE = 0;
}

// Set up a basic identity-mapped page table covering ram_size using 4KB pages.
// PML4 at pml4_addr, allocating subsequent tables from alloc_addr.
static u64 setup_4kb_pages(PhysicalMemory &mem, u64 pml4_addr, u64 alloc_base,
                           u64 vaddr, u64 paddr, u64 flags) {
  u64 alloc = alloc_base;

  // PML4 entry
  u64 pdpt_addr = alloc; alloc += 0x1000;
  mem.write64(pml4_addr + ((vaddr >> 39) & 0x1FF) * 8,
              pdpt_addr | 0x03); // Present + R/W

  // PDPT entry
  u64 pd_addr = alloc; alloc += 0x1000;
  mem.write64(pdpt_addr + ((vaddr >> 30) & 0x1FF) * 8,
              pd_addr | 0x03);

  // PD entry
  u64 pt_addr = alloc; alloc += 0x1000;
  mem.write64(pd_addr + ((vaddr >> 21) & 0x1FF) * 8,
              pt_addr | 0x03);

  // PT entry — map vaddr to paddr with given flags
  mem.write64(pt_addr + ((vaddr >> 12) & 0x1FF) * 8,
              (paddr & 0x000FFFFFFFFFF000ULL) | flags);

  return alloc;
}

enum RunResult { RUN_OK = 0, RUN_HALTED = 1, RUN_FAULTED = 2 };

static int run_code(x86::Model &model, u64 code_addr, const u8 *code, size_t len,
                    u64 max_insns = 1000) {
  model.phys_mem.write_bytes(code_addr, code, len);
  model.zRIP = code_addr;

  u64 count = 0;
  while (count < max_insns) {
    model.zstep(UNIT);
    if (model.zfault_pending) return RUN_FAULTED;
    if (model.zsystem_state == x86::zSysHalted) return RUN_HALTED;
    count++;
  }
  return RUN_OK;
}

static int tests_passed = 0;
static int tests_failed = 0;

#define TEST(name) \
  static void test_##name(); \
  static void run_test_##name() { \
    printf("  %-50s", #name); \
    test_##name(); \
    printf("PASS\n"); \
    tests_passed++; \
  } \
  static void test_##name()

#define ASSERT_EQ(a, b) do { \
  auto _a = (a); auto _b = (b); \
  if (_a != _b) { \
    printf("FAIL\n    %s:%d: %s == 0x%lx, expected 0x%lx\n", \
           __FILE__, __LINE__, #a, (u64)_a, (u64)_b); \
    tests_failed++; \
    return; \
  } \
} while(0)

// =========================================================================
// Paging tests
// =========================================================================

TEST(identity_map_2mb) {
  // Test that identity-mapped 2MB pages work (same setup as system_sim)
  x86::Model model;
  init_model(model);

  // Set up 2MB identity mapping
  u64 pml4_addr = 0x10000;
  model.phys_mem.write64(pml4_addr, 0x11000 | 0x03);
  model.phys_mem.write64(0x11000,   0x12000 | 0x03);
  for (u64 j = 0; j < 8; j++)
    model.phys_mem.write64(0x12000 + j * 8, (j << 21) | 0x83); // 2MB, P+RW+PS
  model.zCR3 = pml4_addr;

  // mov rax, 0x42; hlt
  u8 code[] = { 0xB8, 0x42, 0x00, 0x00, 0x00, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[0], 0x42UL);

  model.model_fini();
}

TEST(non_identity_4kb_mapping) {
  // Map virtual address 0x400000 to physical address 0x200000 using 4KB pages
  x86::Model model;
  init_model(model);

  u64 pml4_addr = 0x10000;
  model.zCR3 = pml4_addr;

  // First set up identity mapping for code area (0x100000)
  u64 alloc = setup_4kb_pages(model.phys_mem, pml4_addr, 0x20000,
                              0x100000, 0x100000, 0x03); // P+RW

  // Map virtual 0x400000 to physical 0x200000
  // Need a separate PDPT/PD/PT since it's a different PML4 region
  // Actually both are in PML4[0], PDPT[0] — need different PD entry
  // 0x100000 >> 21 = 0 (PD index 0), 0x400000 >> 21 = 2 (PD index 2)
  // They share the same PML4[0] and PDPT[0], so add a PD entry
  // The PD was created by setup_4kb_pages at alloc-0x1000
  u64 pt_for_data = alloc; alloc += 0x1000;
  // Get PD address: PML4[0] -> PDPT[0] -> PD
  u64 pdpt_addr = model.phys_mem.read64(pml4_addr) & ~0xFFFULL;
  u64 pd_addr = model.phys_mem.read64(pdpt_addr) & ~0xFFFULL;
  model.phys_mem.write64(pd_addr + 2 * 8, pt_for_data | 0x03); // PD[2] -> new PT
  // PT entry: map page at 0x400000 to phys 0x200000
  model.phys_mem.write64(pt_for_data + 0 * 8, 0x200000 | 0x03); // P+RW

  // Write data at physical 0x200000
  model.phys_mem.write64(0x200000, 0xDEADBEEFCAFEBABEULL);

  // Code: mov rax, [0x400000]; hlt
  // Use RDI to hold the address
  model.zGPR.data[7] = 0x400000;
  u8 code[] = {
    0x48, 0x8B, 0x07,  // mov rax, [rdi]
    0xF4,              // hlt
  };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[0], 0xDEADBEEFCAFEBABEULL);

  model.model_fini();
}

TEST(page_fault_not_present) {
  // Access an unmapped page → should get #PF
  x86::Model model;
  init_model(model);

  u64 pml4_addr = 0x10000;
  model.zCR3 = pml4_addr;

  // Set up identity map for code at 0x100000
  setup_4kb_pages(model.phys_mem, pml4_addr, 0x20000,
                  0x100000, 0x100000, 0x03);

  // Also identity map 0x80000 for stack
  // PD[0] already exists (covers 0-2MB), just add a PT entry
  u64 pdpt_addr = model.phys_mem.read64(pml4_addr) & ~0xFFFULL;
  u64 pd_addr = model.phys_mem.read64(pdpt_addr) & ~0xFFFULL;
  u64 pt_addr = model.phys_mem.read64(pd_addr) & ~0xFFFULL;
  // 0x80000 >> 12 = 0x80, so PT[0x80]
  model.phys_mem.write64(pt_addr + 0x80 * 8, 0x80000 | 0x03);

  // Try to read from 0x500000 which has no mapping (PD[2] not present)
  model.zGPR.data[7] = 0x500000;
  u8 code[] = {
    0x48, 0x8B, 0x07,  // mov rax, [rdi]
    0xF4,              // hlt
  };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_FAULTED);
  // CR2 should contain the faulting address
  ASSERT_EQ((u64)model.zCR2, 0x500000UL);

  model.model_fini();
}

TEST(accessed_dirty_bits) {
  // Verify that A and D bits are set after read/write
  x86::Model model;
  init_model(model);

  u64 pml4_addr = 0x10000;
  model.zCR3 = pml4_addr;

  // Identity map code at 0x100000
  u64 alloc = setup_4kb_pages(model.phys_mem, pml4_addr, 0x20000,
                              0x100000, 0x100000, 0x03);

  // Map 0x300000 to itself with P+RW but no A/D bits
  u64 pdpt_addr = model.phys_mem.read64(pml4_addr) & ~0xFFFULL;
  u64 pd_addr = model.phys_mem.read64(pdpt_addr) & ~0xFFFULL;
  u64 pt_for_data = alloc;
  model.phys_mem.write64(pd_addr + 1 * 8, pt_for_data | 0x03); // PD[1] -> PT
  // Map 0x300000 page — note A=0, D=0
  u64 pte_addr = pt_for_data + ((0x300000 >> 12) & 0x1FF) * 8;
  model.phys_mem.write64(pte_addr, 0x300000 | 0x03); // P+RW, A=0, D=0

  // Write something to 0x300000
  model.zGPR.data[7] = 0x300000;
  u8 code[] = {
    0x48, 0xC7, 0x07, 0x42, 0x00, 0x00, 0x00,  // mov qword [rdi], 0x42
    0xF4,                                        // hlt
  };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);

  // Check that A (bit 5) and D (bit 6) are now set in the PTE
  u64 updated_pte = model.phys_mem.read64(pte_addr);
  ASSERT_EQ((updated_pte >> 5) & 1, 1UL); // Accessed
  ASSERT_EQ((updated_pte >> 6) & 1, 1UL); // Dirty

  model.model_fini();
}

TEST(write_protect) {
  // With CR0.WP=1, kernel write to read-only page should fault
  x86::Model model;
  init_model(model);

  u64 pml4_addr = 0x10000;
  model.zCR3 = pml4_addr;

  // Identity map code at 0x100000 (RW)
  u64 alloc = setup_4kb_pages(model.phys_mem, pml4_addr, 0x20000,
                              0x100000, 0x100000, 0x03);

  // Map 0x300000 as read-only (P, no RW bit)
  u64 pdpt_addr = model.phys_mem.read64(pml4_addr) & ~0xFFFULL;
  u64 pd_addr = model.phys_mem.read64(pdpt_addr) & ~0xFFFULL;
  u64 pt_for_data = alloc;
  model.phys_mem.write64(pd_addr + 1 * 8, pt_for_data | 0x03);
  u64 pte_addr = pt_for_data + ((0x300000 >> 12) & 0x1FF) * 8;
  model.phys_mem.write64(pte_addr, 0x300000 | 0x01); // P only, no RW

  // Try to write to read-only page
  model.zGPR.data[7] = 0x300000;
  u8 code[] = {
    0x48, 0xC7, 0x07, 0x42, 0x00, 0x00, 0x00,  // mov qword [rdi], 0x42
    0xF4,
  };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_FAULTED);
  ASSERT_EQ((u64)model.zCR2, 0x300000UL);

  model.model_fini();
}

TEST(huge_page_1gb) {
  // Test 1GB huge pages (PS=1 at PDPT level)
  x86::Model model;
  init_model(model);

  u64 pml4_addr = 0x10000;
  u64 pdpt_addr = 0x11000;
  model.zCR3 = pml4_addr;

  // PML4[0] -> PDPT
  model.phys_mem.write64(pml4_addr, pdpt_addr | 0x03);
  // PDPT[0] = 1GB page mapping physical 0 (PS=1, P+RW)
  model.phys_mem.write64(pdpt_addr, 0x00000000 | 0x83); // PS=1, P+RW

  // mov rax, 0x42; hlt (code at 0x100000, which is within the 1GB page)
  u8 code[] = { 0xB8, 0x42, 0x00, 0x00, 0x00, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[0], 0x42UL);

  model.model_fini();
}

TEST(store_through_paging) {
  // Write through paging and verify physical memory is updated
  x86::Model model;
  init_model(model);

  u64 pml4_addr = 0x10000;
  u64 pdpt_addr = 0x11000;
  model.zCR3 = pml4_addr;

  // 1GB identity map
  model.phys_mem.write64(pml4_addr, pdpt_addr | 0x03);
  model.phys_mem.write64(pdpt_addr, 0x00000000 | 0x83);

  model.zGPR.data[7] = 0x200000;
  u8 code[] = {
    0x48, 0xC7, 0x07, 0xBE, 0xBA, 0xFE, 0xCA,  // mov qword [rdi], 0xCAFEBABE (sign-ext)
    0xF4,
  };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);

  // Verify physical memory
  u64 stored = model.phys_mem.read64(0x200000);
  // mov qword [rdi], imm32 sign-extends: 0xCAFEBABE → 0xFFFFFFFFCAFEBABE
  ASSERT_EQ(stored, 0xFFFFFFFFCAFEBABEULL);

  model.model_fini();
}

// =========================================================================
// 5-Level Paging (LA57) tests
// =========================================================================

// Set up a 5-level page table: PML5 → PML4 → PDPT → PD → PT → 4KB page.
// Returns the next free allocation address.
static u64 setup_5level_4kb(PhysicalMemory &mem, u64 pml5_addr, u64 alloc_base,
                            u64 vaddr, u64 paddr, u64 flags) {
  u64 alloc = alloc_base;

  // PML5 entry: index from bits[56:48]
  u64 pml4_addr = alloc; alloc += 0x1000;
  mem.write64(pml5_addr + ((vaddr >> 48) & 0x1FF) * 8,
              pml4_addr | 0x03); // Present + R/W

  // PML4 entry: index from bits[47:39]
  u64 pdpt_addr = alloc; alloc += 0x1000;
  mem.write64(pml4_addr + ((vaddr >> 39) & 0x1FF) * 8,
              pdpt_addr | 0x03);

  // PDPT entry: index from bits[38:30]
  u64 pd_addr = alloc; alloc += 0x1000;
  mem.write64(pdpt_addr + ((vaddr >> 30) & 0x1FF) * 8,
              pd_addr | 0x03);

  // PD entry: index from bits[29:21]
  u64 pt_addr = alloc; alloc += 0x1000;
  mem.write64(pd_addr + ((vaddr >> 21) & 0x1FF) * 8,
              pt_addr | 0x03);

  // PT entry: map vaddr to paddr with given flags
  mem.write64(pt_addr + ((vaddr >> 12) & 0x1FF) * 8,
              (paddr & 0x000FFFFFFFFFF000ULL) | flags);

  return alloc;
}

TEST(la57_identity_map_4kb) {
  // 5-level paging with CR4.LA57=1, identity-mapped 4KB page at low address
  x86::Model model;
  init_model(model);

  // Enable LA57
  model.zCR4 = model.zCR4 | (1ULL << 12);

  u64 pml5_addr = 0x10000;
  model.zCR3 = pml5_addr;

  // Identity map 0x100000 through 5-level page tables
  setup_5level_4kb(model.phys_mem, pml5_addr, 0x20000,
                   0x100000, 0x100000, 0x03);

  // Also identity map stack area 0x80000
  // Reuse existing PML5[0]→PML4[0]→PDPT[0]→PD[0] chain
  u64 pml4_addr = model.phys_mem.read64(pml5_addr) & ~0xFFFULL;
  u64 pdpt_addr = model.phys_mem.read64(pml4_addr) & ~0xFFFULL;
  u64 pd_addr = model.phys_mem.read64(pdpt_addr) & ~0xFFFULL;
  u64 pt_addr = model.phys_mem.read64(pd_addr) & ~0xFFFULL;
  // 0x80000 >> 12 = 0x80, so PT[0x80]
  model.phys_mem.write64(pt_addr + 0x80 * 8, 0x80000 | 0x03);

  // mov rax, 0x42; hlt
  u8 code[] = { 0xB8, 0x42, 0x00, 0x00, 0x00, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[0], 0x42UL);

  model.model_fini();
}

TEST(la57_non_identity_4kb) {
  // 5-level paging: map vaddr 0x400000 to paddr 0x200000
  x86::Model model;
  init_model(model);

  model.zCR4 = model.zCR4 | (1ULL << 12);

  u64 pml5_addr = 0x10000;
  model.zCR3 = pml5_addr;

  // Identity map code at 0x100000
  u64 alloc = setup_5level_4kb(model.phys_mem, pml5_addr, 0x20000,
                               0x100000, 0x100000, 0x03);

  // Map 0x400000 → 0x200000 (shares PML5[0]→PML4[0]→PDPT[0], different PD entry)
  u64 pml4_addr = model.phys_mem.read64(pml5_addr) & ~0xFFFULL;
  u64 pdpt_addr = model.phys_mem.read64(pml4_addr) & ~0xFFFULL;
  u64 pd_addr = model.phys_mem.read64(pdpt_addr) & ~0xFFFULL;
  u64 pt_for_data = alloc; alloc += 0x1000;
  model.phys_mem.write64(pd_addr + 2 * 8, pt_for_data | 0x03); // PD[2]
  model.phys_mem.write64(pt_for_data, 0x200000 | 0x03); // PT[0]

  // Write data at physical 0x200000
  model.phys_mem.write64(0x200000, 0xDEADBEEFCAFEBABEULL);

  // mov rax, [rdi]; hlt
  model.zGPR.data[7] = 0x400000;
  u8 code[] = { 0x48, 0x8B, 0x07, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[0], 0xDEADBEEFCAFEBABEULL);

  model.model_fini();
}

TEST(la57_1gb_huge_page) {
  // 5-level paging with 1GB huge page (PS=1 at PDPT level)
  x86::Model model;
  init_model(model);

  model.zCR4 = model.zCR4 | (1ULL << 12);

  u64 pml5_addr = 0x10000;
  u64 pml4_addr = 0x11000;
  u64 pdpt_addr = 0x12000;
  model.zCR3 = pml5_addr;

  // PML5[0] → PML4
  model.phys_mem.write64(pml5_addr, pml4_addr | 0x03);
  // PML4[0] → PDPT
  model.phys_mem.write64(pml4_addr, pdpt_addr | 0x03);
  // PDPT[0] = 1GB page mapping physical 0 (PS=1, P+RW)
  model.phys_mem.write64(pdpt_addr, 0x00000000 | 0x83);

  // mov rax, 0x42; hlt
  u8 code[] = { 0xB8, 0x42, 0x00, 0x00, 0x00, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[0], 0x42UL);

  model.model_fini();
}

TEST(la57_accessed_dirty) {
  // 5-level paging: verify A/D bits set through all 5 levels
  x86::Model model;
  init_model(model);

  model.zCR4 = model.zCR4 | (1ULL << 12);

  u64 pml5_addr = 0x10000;
  model.zCR3 = pml5_addr;

  // Identity map code at 0x100000
  u64 alloc = setup_5level_4kb(model.phys_mem, pml5_addr, 0x20000,
                               0x100000, 0x100000, 0x03);

  // Map 0x300000 with P+RW but A=0, D=0
  u64 pml4_addr = model.phys_mem.read64(pml5_addr) & ~0xFFFULL;
  u64 pdpt_addr = model.phys_mem.read64(pml4_addr) & ~0xFFFULL;
  u64 pd_addr = model.phys_mem.read64(pdpt_addr) & ~0xFFFULL;
  u64 pt_for_data = alloc; alloc += 0x1000;
  model.phys_mem.write64(pd_addr + 1 * 8, pt_for_data | 0x03);
  u64 pte_addr = pt_for_data + ((0x300000 >> 12) & 0x1FF) * 8;
  model.phys_mem.write64(pte_addr, 0x300000 | 0x03); // P+RW, A=0, D=0

  // Write to 0x300000
  model.zGPR.data[7] = 0x300000;
  u8 code[] = {
    0x48, 0xC7, 0x07, 0x42, 0x00, 0x00, 0x00,  // mov qword [rdi], 0x42
    0xF4,
  };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);

  // Check A and D bits on leaf PTE
  u64 updated_pte = model.phys_mem.read64(pte_addr);
  ASSERT_EQ((updated_pte >> 5) & 1, 1UL); // Accessed
  ASSERT_EQ((updated_pte >> 6) & 1, 1UL); // Dirty

  // Check Accessed bit on PML5 entry (non-leaf entries get A bit set too)
  u64 pml5e = model.phys_mem.read64(pml5_addr);
  ASSERT_EQ((pml5e >> 5) & 1, 1UL); // Accessed

  model.model_fini();
}

// =========================================================================
// 32-bit paging tests (non-PAE and PAE)
// =========================================================================

// Init for 32-bit protected mode with paging
static void init_model_32(x86::Model &model, u64 ram_size = 16 * 1024 * 1024) {
  model.model_init();
  model.zinitializze_registers(UNIT);
  enable_all_features(model);

  model.zsystem_mode = false;
  model.zcur_mode = x86::zProtectedMode;
  model.zcur_cpl = 0;

  // CR0: PE + ET + NE + WP + PG
  model.zCR0 = (1UL << 0) | (1UL << 4) | (1UL << 5) | (1UL << 16) | (1UL << 31);
  // CR4: PSE + OSFXSR (no PAE, no LA57)
  model.zCR4 = (1UL << 4) | (1UL << 9);
  // EFER: no LME, no LMA
  model.zEFER = 0;

  assert(model.phys_mem.init(ram_size));

  for (int i = 0; i < 16; i++)
    model.zGPR.data[i] = 0;
  model.zGPR.data[4] = 0x80000; // ESP

  // Flat 4GB segments: CS.D=1 (32-bit code), SS.B=1 (32-bit stack)
  for (int i = 0; i < 6; i++) {
    model.zSegCache.data[i].zseg_base = 0;
    model.zSegCache.data[i].zseg_limit = 0xFFFFFFFF;
    model.zSegCache.data[i].zseg_present = 1;
    model.zSegCache.data[i].zseg_s = 1;
    model.zSegCache.data[i].zseg_g = 1;
    model.zSegCache.data[i].zseg_db = 1;
  }

  model.zGDTR_base = 0;
  model.zGDTR_limit = 0;
  model.zIDTR_base = 0;
  model.zIDTR_limit = 0;
  model.zKERNEL_GS_BASE = 0;
}

TEST(paging_32bit_identity_4kb) {
  // 32-bit non-PAE paging: identity map using 4KB pages
  x86::Model model;
  init_model_32(model);

  // Set up 2-level page table: PD at 0x10000, PT at 0x11000
  u64 pd_addr = 0x10000;
  u64 pt_addr = 0x11000;
  model.zCR3 = pd_addr;

  // PD[0] -> PT (covers 0-4MB, 1024 × 4KB entries)
  model.phys_mem.write32(pd_addr + 0 * 4, pt_addr | 0x03); // P+RW
  for (u32 i = 0; i < 1024; i++)
    model.phys_mem.write32(pt_addr + i * 4, (i << 12) | 0x03);

  model.phys_mem.write32(0x200000, 0xCAFE1234);

  // 32-bit code: mov eax, [0x200000]; hlt
  // Use [edi] since direct disp32 with mod=00 rm=5 works in 32-bit mode
  model.zGPR.data[7] = 0x200000; // EDI
  u8 code[] = {
    0x8B, 0x07,  // mov eax, [edi]
    0xF4,        // hlt
  };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[0], 0xCAFE1234UL);

  model.model_fini();
}

TEST(paging_32bit_4mb_page) {
  // 32-bit non-PAE paging with 4MB pages (CR4.PSE=1, PDE.PS=1)
  x86::Model model;
  init_model_32(model);

  u64 pd_addr = 0x10000;
  model.zCR3 = pd_addr;

  // PD[0] = 4MB page mapping physical 0 (PS=1, P+RW)
  model.phys_mem.write32(pd_addr + 0 * 4, 0x00000083); // PS=1, P+RW

  // Write known value
  model.phys_mem.write32(0x100010, 0xDEADBEEF);

  // mov eax, [edi]; hlt
  model.zGPR.data[7] = 0x100010;
  u8 code[] = { 0x8B, 0x07, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[0], 0xDEADBEEFUL);

  model.model_fini();
}

TEST(paging_32bit_fault_not_present) {
  // 32-bit paging: access unmapped page → #PF
  x86::Model model;
  init_model_32(model);

  u64 pd_addr = 0x10000;
  model.zCR3 = pd_addr;

  // Only map PD[0] with a 4MB page for code area
  model.phys_mem.write32(pd_addr + 0 * 4, 0x00000083);
  // PD[1] not present — accessing 0x400000 should fault

  model.zGPR.data[7] = 0x400000;
  u8 code[] = { 0x8B, 0x07, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_FAULTED);
  ASSERT_EQ((u64)model.zCR2, 0x400000UL);

  model.model_fini();
}

TEST(paging_pae_identity_2mb) {
  // PAE paging with 2MB pages
  x86::Model model;
  init_model_32(model);

  // Enable PAE
  model.zCR4 = model.zCR4 | (1UL << 5);

  u64 pdpt_addr = 0x10000; // Must be 32-byte aligned
  u64 pd_addr   = 0x11000;
  model.zCR3 = pdpt_addr;

  // PDPTE[0] -> PD (covers 0-1GB)
  model.phys_mem.write64(pdpt_addr + 0 * 8, pd_addr | 0x01); // P only

  // PD[0] = 2MB page, identity-mapped (PS=1, P+RW)
  model.phys_mem.write64(pd_addr + 0 * 8, 0x0000000000000083ULL);

  model.phys_mem.write32(0x100010, 0x12345678);

  model.zGPR.data[7] = 0x100010;
  u8 code[] = { 0x8B, 0x07, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[0], 0x12345678UL);

  model.model_fini();
}

TEST(paging_pae_4kb) {
  // PAE paging with 4KB pages
  x86::Model model;
  init_model_32(model);

  model.zCR4 = model.zCR4 | (1UL << 5);

  u64 pdpt_addr = 0x10000;
  u64 pd_addr   = 0x11000;
  u64 pt_addr   = 0x12000;
  model.zCR3 = pdpt_addr;

  // PDPTE[0] -> PD
  model.phys_mem.write64(pdpt_addr + 0 * 8, pd_addr | 0x01);
  // PD[0] -> PT (covers 0-2MB)
  model.phys_mem.write64(pd_addr + 0 * 8, pt_addr | 0x03ULL);
  // PT entries: identity map first 2MB
  for (u32 i = 0; i < 512; i++)
    model.phys_mem.write64(pt_addr + i * 8, ((u64)i << 12) | 0x03ULL);

  model.phys_mem.write32(0x100010, 0xABCD0000);

  model.zGPR.data[7] = 0x100010;
  u8 code[] = { 0x8B, 0x07, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[0], 0xABCD0000UL);

  model.model_fini();
}

// =========================================================================

int main() {
  printf("Paging tests:\n");

  run_test_identity_map_2mb();
  run_test_non_identity_4kb_mapping();
  run_test_page_fault_not_present();
  run_test_accessed_dirty_bits();
  run_test_write_protect();
  run_test_huge_page_1gb();
  run_test_store_through_paging();

  // 5-level paging (LA57) tests
  run_test_la57_identity_map_4kb();
  run_test_la57_non_identity_4kb();
  run_test_la57_1gb_huge_page();
  run_test_la57_accessed_dirty();

  // 32-bit paging tests
  run_test_paging_32bit_identity_4kb();
  run_test_paging_32bit_4mb_page();
  run_test_paging_32bit_fault_not_present();

  // PAE paging tests
  run_test_paging_pae_identity_2mb();
  run_test_paging_pae_4kb();

  printf("\n%d passed, %d failed\n", tests_passed, tests_failed);
  return tests_failed > 0 ? 1 : 0;
}

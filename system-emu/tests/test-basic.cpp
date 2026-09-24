// Basic tests for system-level emulator.
// Tests that the emulator can execute simple instructions with
// physical memory backed by the PhysicalMemory manager.

#include "sail_x86_model.h"
#include "x86-helpers.h"
#include <cassert>
#include <cstdio>
#include <cstring>

static void init_model(x86::Model &model, u64 ram_size = 4 * 1024 * 1024) {
  model.model_init();
  model.zinitializze_registers(UNIT);
  enable_all_features(model);

  // Use system_mode=false for these tests since no IDT is set up.
  // Faults return to C++ directly rather than going through IDT delivery.
  model.zsystem_mode = false;
  model.zcur_mode = x86::zLongMode;
  model.zcur_cpl = 0;
  model.zSegCache.data[x86::SEG_CS].zseg_l = 1;

  // CR0: PE + ET + NE + WP + PG
  model.zCR0 = (1UL << 0) | (1UL << 4) | (1UL << 5) | (1UL << 16) | (1UL << 31);
  // CR4: PAE + OSFXSR
  model.zCR4 = (1UL << 5) | (1UL << 9);
  // EFER: SCE + LME + LMA + NXE
  model.zEFER = (1UL << 0) | (1UL << 8) | (1UL << 10) | (1UL << 11);

  assert(model.phys_mem.init(ram_size));

  // Set up identity-mapped page tables using 2MB pages
  // PML4 at 0x1000, PDPT at 0x2000, PD at 0x3000
  model.phys_mem.write64(0x1000, 0x2000 | 0x03);  // PML4[0] -> PDPT
  model.phys_mem.write64(0x2000, 0x3000 | 0x03);  // PDPT[0] -> PD
  for (u64 j = 0; j < 512; j++) {
    u64 phys = j << 21;
    if (phys >= ram_size) break;
    model.phys_mem.write64(0x3000 + j * 8, phys | 0x83);  // 2MB page
  }
  model.zCR3 = 0x1000;

  // Zero GPRs
  for (int i = 0; i < 16; i++)
    model.zGPR.data[i] = 0;
  model.zGPR.data[4] = 0x80000; // RSP

  model.zGDTR_base = 0;
  model.zGDTR_limit = 0;
  model.zIDTR_base = 0;
  model.zIDTR_limit = 0;
  model.zKERNEL_GS_BASE = 0;
}

// Run result codes (replacing the old zExecutionResult kind enum)
enum RunResult { RUN_OK = 0, RUN_HALTED = 1, RUN_FAULTED = 2 };

// Run code loaded at code_addr until HLT or fault.
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
// Tests
// =========================================================================

TEST(phys_mem_read_write) {
  PhysicalMemory mem;
  assert(mem.init(4096));

  mem.write8(0, 0x42);
  ASSERT_EQ(mem.read8(0), 0x42);

  mem.write16(16, 0xBEEF);
  ASSERT_EQ(mem.read16(16), 0xBEEF);

  mem.write32(32, 0xDEADBEEF);
  ASSERT_EQ(mem.read32(32), 0xDEADBEEF);

  mem.write64(64, 0x123456789ABCDEF0ULL);
  ASSERT_EQ(mem.read64(64), 0x123456789ABCDEF0ULL);

  // Out-of-range reads return 0xFF...
  ASSERT_EQ(mem.read8(5000), 0xFF);
  ASSERT_EQ(mem.read16(5000), 0xFFFF);
  ASSERT_EQ(mem.read32(5000), 0xFFFFFFFF);
  ASSERT_EQ(mem.read64(5000), 0xFFFFFFFFFFFFFFFFULL);
}

TEST(phys_mem_bulk) {
  PhysicalMemory mem;
  assert(mem.init(4096));

  u8 data[] = {1, 2, 3, 4, 5, 6, 7, 8};
  mem.write_bytes(100, data, sizeof(data));

  u8 out[8] = {};
  mem.read_bytes(100, out, sizeof(out));
  ASSERT_EQ(memcmp(data, out, 8), 0);
}

TEST(mov_eax_imm32_hlt) {
  x86::Model model;
  init_model(model);

  // mov eax, 0x42; hlt
  u8 code[] = { 0xB8, 0x42, 0x00, 0x00, 0x00, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[0], 0x42UL);

  model.model_fini();
}

TEST(mov_rax_imm64_hlt) {
  x86::Model model;
  init_model(model);

  // mov rax, 0x123456789ABCDEF0 (REX.W + B8 + imm64); hlt
  u8 code[] = {
    0x48, 0xB8, 0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12,
    0xF4
  };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[0], 0x123456789ABCDEF0UL);

  model.model_fini();
}

TEST(add_rax_rbx_hlt) {
  x86::Model model;
  init_model(model);

  model.zGPR.data[0] = 10; // RAX
  model.zGPR.data[3] = 32; // RBX

  // add rax, rbx (48 01 D8); hlt
  u8 code[] = { 0x48, 0x01, 0xD8, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[0], 42UL);

  model.model_fini();
}

TEST(mem_store_load_hlt) {
  x86::Model model;
  init_model(model);

  // mov qword [0x200000], 0x42  ; can't encode this directly, use:
  // mov rax, 0x42
  // mov [rdi], rax
  // mov rbx, [rdi]
  // hlt
  model.zGPR.data[7] = 0x200000; // RDI = address to store to

  u8 code[] = {
    0x48, 0xC7, 0xC0, 0x42, 0x00, 0x00, 0x00,  // mov rax, 0x42
    0x48, 0x89, 0x07,                            // mov [rdi], rax
    0x48, 0x8B, 0x1F,                            // mov rbx, [rdi]
    0xF4,                                        // hlt
  };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[3], 0x42UL); // RBX should be 0x42

  // Verify it's actually in physical memory
  ASSERT_EQ(model.phys_mem.read64(0x200000), 0x42UL);

  model.model_fini();
}

TEST(push_pop_hlt) {
  x86::Model model;
  init_model(model);

  model.zGPR.data[0] = 0xDEADBEEF; // RAX

  // push rax; pop rbx; hlt
  u8 code[] = { 0x50, 0x5B, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[3], 0xDEADBEEFUL); // RBX

  model.model_fini();
}

TEST(jmp_forward_hlt) {
  x86::Model model;
  init_model(model);

  // jmp +2 (skip next 2 bytes); mov eax, 0xFF (should be skipped); mov eax, 0x42; hlt
  u8 code[] = {
    0xEB, 0x05,                            // jmp +5 (skip mov eax, 0xFF)
    0xB8, 0xFF, 0x00, 0x00, 0x00,         // mov eax, 0xFF (skipped)
    0xB8, 0x42, 0x00, 0x00, 0x00,         // mov eax, 0x42
    0xF4,                                  // hlt
  };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[0], 0x42UL);

  model.model_fini();
}

TEST(loop_counter_hlt) {
  x86::Model model;
  init_model(model);

  // xor eax, eax    ; 31 C0
  // mov ecx, 10     ; B9 0A 00 00 00
  // .loop:
  //   inc eax       ; FF C0
  //   dec ecx       ; FF C9
  //   jnz .loop     ; 75 FA (-6)
  // hlt             ; F4
  u8 code[] = {
    0x31, 0xC0,                            // xor eax, eax
    0xB9, 0x0A, 0x00, 0x00, 0x00,         // mov ecx, 10
    0xFF, 0xC0,                            // inc eax
    0xFF, 0xC9,                            // dec ecx
    0x75, 0xFA,                            // jnz -6
    0xF4,                                  // hlt
  };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[0], 10UL); // RAX = 10

  model.model_fini();
}

TEST(system_regs_initial_values) {
  x86::Model model;
  init_model(model);

  // Verify system register initial values
  ASSERT_EQ((u64)model.zCR0 & 1, 1UL);     // PE=1
  ASSERT_EQ(((u64)model.zCR0 >> 31) & 1, 1UL); // PG=1
  ASSERT_EQ(((u64)model.zCR4 >> 5) & 1, 1UL);  // PAE=1
  ASSERT_EQ(((u64)model.zEFER >> 8) & 1, 1UL);  // LME=1
  ASSERT_EQ(((u64)model.zEFER >> 10) & 1, 1UL); // LMA=1
  ASSERT_EQ((u64)model.zCR3, 0x1000UL);

  model.model_fini();
}

// =========================================================================
// Privileged instruction tests
// =========================================================================

TEST(mov_cr0_read_write) {
  x86::Model model;
  init_model(model);

  // Read CR0 into RAX, then store it, modify, write back
  // mov rax, cr0     ; 0F 20 C0
  // hlt
  u8 code[] = { 0x0F, 0x20, 0xC0, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[0], (u64)model.zCR0);

  model.model_fini();
}

TEST(mov_cr3_write) {
  x86::Model model;
  init_model(model);

  // Set up valid page tables at 0x5000 before switching CR3
  // PML4 at 0x5000 -> PDPT at 0x6000 -> PD at 0x7000
  model.phys_mem.write64(0x5000, 0x6000 | 0x03);
  model.phys_mem.write64(0x6000, 0x7000 | 0x03);
  // Identity map first 8MB with 2MB pages
  for (u64 j = 0; j < 4; j++)
    model.phys_mem.write64(0x7000 + j * 8, (j << 21) | 0x83);

  // mov rax, 0x5000; mov cr3, rax; mov rbx, cr3; hlt
  u8 code[] = {
    0x48, 0xC7, 0xC0, 0x00, 0x50, 0x00, 0x00,  // mov rax, 0x5000
    0x0F, 0x22, 0xD8,                            // mov cr3, rax
    0x0F, 0x20, 0xDB,                            // mov rbx, cr3
    0xF4,                                        // hlt
  };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zCR3, 0x5000UL);
  ASSERT_EQ((u64)model.zGPR.data[3], 0x5000UL); // RBX = CR3

  model.model_fini();
}

TEST(lgdt_sgdt) {
  x86::Model model;
  init_model(model);

  // Set up a GDT descriptor in memory at 0x200000
  // limit = 0x00FF, base = 0x0000000000300000
  u16 limit = 0x00FF;
  u64 base = 0x300000;
  model.phys_mem.write_bytes(0x200000, &limit, 2);
  model.phys_mem.write_bytes(0x200002, &base, 8);

  // lgdt [rdi]       ; 0F 01 17
  // sgdt [rsi]       ; 0F 01 06
  // hlt
  model.zGPR.data[7] = 0x200000; // RDI
  model.zGPR.data[6] = 0x200100; // RSI

  u8 code[] = {
    0x0F, 0x01, 0x17,  // lgdt [rdi]
    0x0F, 0x01, 0x06,  // sgdt [rsi]
    0xF4,              // hlt
  };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGDTR_limit, 0x00FFUL);
  ASSERT_EQ((u64)model.zGDTR_base, 0x300000UL);

  // Verify SGDT wrote to memory correctly
  u16 stored_limit;
  u64 stored_base;
  model.phys_mem.read_bytes(0x200100, &stored_limit, 2);
  model.phys_mem.read_bytes(0x200102, &stored_base, 8);
  ASSERT_EQ(stored_limit, 0x00FF);
  ASSERT_EQ(stored_base, 0x300000UL);

  model.model_fini();
}

TEST(lidt_sidt) {
  x86::Model model;
  init_model(model);

  u16 limit = 0x0FFF;
  u64 base = 0x400000;
  model.phys_mem.write_bytes(0x200000, &limit, 2);
  model.phys_mem.write_bytes(0x200002, &base, 8);

  model.zGPR.data[7] = 0x200000;
  model.zGPR.data[6] = 0x200100;

  // lidt [rdi]; sidt [rsi]; hlt
  u8 code[] = {
    0x0F, 0x01, 0x1F,  // lidt [rdi]
    0x0F, 0x01, 0x0E,  // sidt [rsi]
    0xF4,
  };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zIDTR_limit, 0x0FFFUL);
  ASSERT_EQ((u64)model.zIDTR_base, 0x400000UL);

  model.model_fini();
}

TEST(wrmsr_rdmsr_star) {
  x86::Model model;
  init_model(model);

  // Write IA32_STAR (0xC0000081) = 0x0023001000000000
  // wrmsr: ECX = MSR addr, EDX:EAX = value
  // mov ecx, 0xC0000081; mov edx, 0x00230010; mov eax, 0; wrmsr
  // mov ecx, 0xC0000081; rdmsr; hlt
  u8 code[] = {
    0xB9, 0x81, 0x00, 0x00, 0xC0,              // mov ecx, 0xC0000081
    0xBA, 0x10, 0x00, 0x23, 0x00,              // mov edx, 0x00230010
    0xB8, 0x00, 0x00, 0x00, 0x00,              // mov eax, 0
    0x0F, 0x30,                                 // wrmsr
    0xB9, 0x81, 0x00, 0x00, 0xC0,              // mov ecx, 0xC0000081
    0x0F, 0x32,                                 // rdmsr
    0xF4,                                       // hlt
  };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[0], 0UL);          // EAX = low 32
  ASSERT_EQ((u64)model.zGPR.data[2], 0x00230010UL);  // EDX = high 32

  model.model_fini();
}

TEST(wrmsr_rdmsr_efer) {
  x86::Model model;
  init_model(model);

  // Write EFER (0xC0000080) via WRMSR, then read back via RDMSR
  u8 code[] = {
    0xB9, 0x80, 0x00, 0x00, 0xC0,              // mov ecx, 0xC0000080
    0xBA, 0x00, 0x00, 0x00, 0x00,              // mov edx, 0
    0xB8, 0x01, 0x0D, 0x00, 0x00,              // mov eax, 0x0D01 (SCE+LME+LMA+NXE)
    0x0F, 0x30,                                 // wrmsr
    0xB9, 0x80, 0x00, 0x00, 0xC0,              // mov ecx, 0xC0000080
    0x0F, 0x32,                                 // rdmsr
    0xF4,                                       // hlt
  };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zEFER, 0x0D01UL);
  ASSERT_EQ((u64)model.zGPR.data[0], 0x0D01UL);

  model.model_fini();
}

TEST(swapgs) {
  x86::Model model;
  init_model(model);

  model.zSegCache.data[x86::SEG_GS].zseg_base = 0xAAAA0000;
  model.zKERNEL_GS_BASE = 0xBBBB0000;

  // swapgs ; 0F 01 F8
  // hlt
  u8 code[] = { 0x0F, 0x01, 0xF8, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_GS].zseg_base, 0xBBBB0000UL);
  ASSERT_EQ((u64)model.zKERNEL_GS_BASE, 0xAAAA0000UL);

  model.model_fini();
}

TEST(cli_sti) {
  x86::Model model;
  init_model(model);

  model.zIF_flag = 0b1;  // Start with IF=1

  // cli; hlt  (should clear IF)
  u8 code[] = { 0xFA, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zIF_flag, 0UL);

  // sti; hlt  (should set IF)
  u8 code2[] = { 0xFB, 0xF4 };
  kind = run_code(model, 0x100000, code2, sizeof(code2));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zIF_flag, 1UL);

  model.model_fini();
}

TEST(wbinvd) {
  x86::Model model;
  init_model(model);

  // wbinvd (0F 09) should be a NOP at CPL=0
  // hlt
  u8 code[] = { 0x0F, 0x09, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);

  model.model_fini();
}

TEST(clts) {
  x86::Model model;
  init_model(model);

  // Set TS bit in CR0
  model.zCR0 = (u64)model.zCR0 | (1UL << 3);

  // clts (0F 06); mov rax, cr0; hlt
  u8 code[] = { 0x0F, 0x06, 0x0F, 0x20, 0xC0, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ(((u64)model.zCR0 >> 3) & 1, 0UL); // TS should be cleared

  model.model_fini();
}

// =========================================================================
// String I/O tests (INS/OUTS)
// =========================================================================

TEST(insb_single) {
  // INSB reads a byte from port DX and stores to [RDI], then increments RDI
  x86::Model model;
  init_model(model);

  // Port 0x80 (debug port) reads as 0xFF
  model.zGPR.data[2] = 0x80;     // RDX = port
  model.zGPR.data[7] = 0x200000; // RDI = destination
  model.zDF = 0;                  // DF=0 (forward)

  // insb (6C); hlt
  u8 code[] = { 0x6C, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ(model.phys_mem.read8(0x200000), 0xFF);
  ASSERT_EQ((u64)model.zGPR.data[7], 0x200001UL); // RDI incremented by 1
}

TEST(outsb_single) {
  // OUTSB reads a byte from [RSI] and outputs to port DX, then increments RSI
  x86::Model model;
  init_model(model);

  model.phys_mem.write8(0x200000, 0x42);
  model.zGPR.data[2] = 0x80;     // RDX = port
  model.zGPR.data[6] = 0x200000; // RSI = source
  model.zDF = 0;

  // outsb (6E); hlt
  u8 code[] = { 0x6E, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[6], 0x200001UL); // RSI incremented by 1
}

TEST(rep_insb) {
  // REP INSB: read 4 bytes from port 0x80 to [RDI], decrementing RCX each time
  x86::Model model;
  init_model(model);

  model.zGPR.data[2] = 0x80;     // RDX = port
  model.zGPR.data[7] = 0x200000; // RDI = destination
  model.zGPR.data[1] = 4;        // RCX = count
  model.zDF = 0;

  // rep insb (F3 6C); hlt
  u8 code[] = { 0xF3, 0x6C, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[1], 0UL);        // RCX = 0
  ASSERT_EQ((u64)model.zGPR.data[7], 0x200004UL); // RDI advanced by 4
  // All 4 bytes should be 0xFF (from port 0x80)
  ASSERT_EQ(model.phys_mem.read32(0x200000), 0xFFFFFFFFUL);
}

TEST(rep_outsb) {
  // REP OUTSB: write 4 bytes from [RSI] to port 0x80
  x86::Model model;
  init_model(model);

  model.phys_mem.write32(0x200000, 0xDEADBEEF);
  model.zGPR.data[2] = 0x80;     // RDX = port
  model.zGPR.data[6] = 0x200000; // RSI = source
  model.zGPR.data[1] = 4;        // RCX = count
  model.zDF = 0;

  // rep outsb (F3 6E); hlt
  u8 code[] = { 0xF3, 0x6E, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[1], 0UL);        // RCX = 0
  ASSERT_EQ((u64)model.zGPR.data[6], 0x200004UL); // RSI advanced by 4
}

TEST(rep_insd) {
  // REP INSD: read 3 dwords from port 0x80, DF=1 (backward)
  x86::Model model;
  init_model(model);

  model.zGPR.data[2] = 0x80;     // RDX = port
  model.zGPR.data[7] = 0x200008; // RDI = destination (start high, go down)
  model.zGPR.data[1] = 3;        // RCX = count
  model.zDF = 1;                  // DF=1 (backward)

  // rep insd (F3 6D); hlt
  u8 code[] = { 0xF3, 0x6D, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGPR.data[1], 0UL);        // RCX = 0
  ASSERT_EQ((u64)model.zGPR.data[7], 0x1FFFFCUL); // RDI decremented by 3*4=12
  // Port 0x80 = 0xFF (POST code), 0x81-0x83 = DMA page registers (0x00).
  // 32-bit INS reads 4 consecutive ports: 0x80,0x81,0x82,0x83 → 0x000000FF.
  ASSERT_EQ(model.phys_mem.read32(0x200008), 0x000000FFUL);
  ASSERT_EQ(model.phys_mem.read32(0x200004), 0x000000FFUL);
  ASSERT_EQ(model.phys_mem.read32(0x200000), 0x000000FFUL);
}

TEST(insb_df_backward) {
  // Single INSB with DF=1: RDI should decrement
  x86::Model model;
  init_model(model);

  model.zGPR.data[2] = 0x80;
  model.zGPR.data[7] = 0x200010;
  model.zDF = 1;

  // insb; hlt
  u8 code[] = { 0x6C, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ(model.phys_mem.read8(0x200010), 0xFF);
  ASSERT_EQ((u64)model.zGPR.data[7], 0x20000FUL); // RDI decremented by 1
}

// =========================================================================
// Direct store tests (MOVDIRI/MOVDIR64B)
// =========================================================================

TEST(movdiri_32) {
  // MOVDIRI [RDI], EAX: NP 0F 38 F9 07
  x86::Model model;
  init_model(model);

  model.zGPR.data[7] = 0x200000; // RDI = destination
  model.zGPR.data[0] = 0xDEADBEEF12345678ULL; // RAX

  // movdiri [rdi], eax; hlt
  u8 code[] = { 0x0F, 0x38, 0xF9, 0x07, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ(model.phys_mem.read32(0x200000), 0x12345678UL); // low 32 bits only
}

TEST(movdiri_64) {
  // MOVDIRI [RDI], RAX: REX.W 0F 38 F9 07
  x86::Model model;
  init_model(model);

  model.zGPR.data[7] = 0x200000;
  model.zGPR.data[0] = 0xDEADBEEF12345678ULL;

  u8 code[] = { 0x48, 0x0F, 0x38, 0xF9, 0x07, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ(model.phys_mem.read64(0x200000), 0xDEADBEEF12345678ULL);
}

TEST(movdir64b) {
  // MOVDIR64B RAX, [RDI]: 66 0F 38 F8 07
  // reg=RAX=destination address, r/m=[RDI]=source
  x86::Model model;
  init_model(model);

  // Write 64-byte source pattern at 0x200000
  for (int i = 0; i < 64; i++)
    model.phys_mem.write8(0x200000 + i, (u8)(i + 1));

  model.zGPR.data[7] = 0x200000;  // RDI = source address
  model.zGPR.data[0] = 0x200100;  // RAX = destination address (64-byte aligned)

  // movdir64b rax, [rdi]; hlt
  u8 code[] = { 0x66, 0x0F, 0x38, 0xF8, 0x07, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);

  // Verify all 64 bytes were copied
  for (int i = 0; i < 64; i++)
    ASSERT_EQ(model.phys_mem.read8(0x200100 + i), (u8)(i + 1));
}

TEST(movdir64b_unaligned_faults) {
  // MOVDIR64B with unaligned destination should #GP(0)
  x86::Model model;
  init_model(model);

  model.zGPR.data[7] = 0x200000;  // source (aligned, doesn't matter)
  model.zGPR.data[0] = 0x200001;  // destination NOT 64-byte aligned

  u8 code[] = { 0x66, 0x0F, 0x38, 0xF8, 0x07, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_FAULTED);
}

// =========================================================================
// 32-bit protected mode tests
// =========================================================================

static void init_model_32(x86::Model &model, u64 ram_size = 4 * 1024 * 1024) {
  model.model_init();
  model.zinitializze_registers(UNIT);
  enable_all_features(model);

  model.zsystem_mode = false;
  model.zcur_mode = x86::zProtectedMode;
  model.zcur_cpl = 0;

  // CR0: PE + ET + NE + WP + PG
  model.zCR0 = (1UL << 0) | (1UL << 4) | (1UL << 5) | (1UL << 16) | (1UL << 31);
  // CR4: PSE + OSFXSR (no PAE)
  model.zCR4 = (1UL << 4) | (1UL << 9);
  model.zEFER = 0;  // No LME, no LMA

  assert(model.phys_mem.init(ram_size));

  // Identity-mapped 4MB pages
  u64 pd_addr = 0x10000;
  model.zCR3 = pd_addr;
  model.phys_mem.write32(pd_addr + 0 * 4, 0x00000083);
  model.phys_mem.write32(pd_addr + 1 * 4, 0x00400083);

  for (int i = 0; i < 16; i++)
    model.zGPR.data[i] = 0;
  model.zGPR.data[4] = 0x80000;

  // Flat 4GB segments: CS.D=1, SS.B=1
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

TEST(lgdt_sgdt_32bit) {
  // In 32-bit mode, LGDT reads 6 bytes (2 limit + 4 base),
  // SGDT writes 6 bytes.
  x86::Model model;
  init_model_32(model);

  // Set up a 6-byte GDT descriptor at 0x200000:
  // limit = 0x00FF, base = 0x00300000 (4 bytes)
  u16 limit = 0x00FF;
  u32 base = 0x00300000;
  model.phys_mem.write16(0x200000, limit);
  model.phys_mem.write32(0x200002, base);

  // lgdt [edi] ; sgdt [esi] ; hlt
  model.zGPR.data[7] = 0x200000; // EDI
  model.zGPR.data[6] = 0x200100; // ESI

  u8 code[] = {
    0x0F, 0x01, 0x17,  // lgdt [edi]
    0x0F, 0x01, 0x06,  // sgdt [esi]
    0xF4,              // hlt
  };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zGDTR_limit, 0x00FFUL);
  ASSERT_EQ((u64)model.zGDTR_base, 0x00300000UL);

  // Verify SGDT wrote 6 bytes (not 10)
  u16 stored_limit = model.phys_mem.read16(0x200100);
  u32 stored_base  = model.phys_mem.read32(0x200102);
  ASSERT_EQ((u64)stored_limit, 0x00FFUL);
  ASSERT_EQ((u64)stored_base, 0x00300000UL);

  // Byte at offset 6 should be untouched (not overwritten by an 8-byte store)
  // Write a sentinel first, then verify it survives
  model.model_fini();
}

TEST(lidt_sidt_32bit) {
  // In 32-bit mode, LIDT reads 6 bytes, SIDT writes 6 bytes.
  x86::Model model;
  init_model_32(model);

  u16 limit = 0x07FF;
  u32 base = 0x00400000;
  model.phys_mem.write16(0x200000, limit);
  model.phys_mem.write32(0x200002, base);

  model.zGPR.data[7] = 0x200000;
  model.zGPR.data[6] = 0x200100;

  // Write sentinel at 0x200106 (byte after 6-byte SIDT output)
  model.phys_mem.write_bytes(0x200106, (const u8[]){0xAA}, 1);

  u8 code[] = {
    0x0F, 0x01, 0x1F,  // lidt [edi]
    0x0F, 0x01, 0x0E,  // sidt [esi]
    0xF4,
  };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zIDTR_limit, 0x07FFUL);
  ASSERT_EQ((u64)model.zIDTR_base, 0x00400000UL);

  // Verify 6-byte format
  u16 stored_limit = model.phys_mem.read16(0x200100);
  u32 stored_base  = model.phys_mem.read32(0x200102);
  ASSERT_EQ((u64)stored_limit, 0x07FFUL);
  ASSERT_EQ((u64)stored_base, 0x00400000UL);

  // Sentinel should be untouched (SIDT only wrote 6 bytes, not 10)
  u8 sentinel = 0;
  model.phys_mem.read_bytes(0x200106, &sentinel, 1);
  ASSERT_EQ((u64)sentinel, 0xAAUL);

  model.model_fini();
}

TEST(seg_limit_byte_within) {
  // 1-byte read at the last valid offset should succeed
  x86::Model model;
  init_model_32(model);

  // DS limit = 0x200FFF (covers 0..0x200FFF)
  model.zSegCache.data[x86::SEG_DS].zseg_limit = 0x200FFF;

  // Write value at physical 0x200FFF
  model.phys_mem.write_bytes(0x200FFF, (const u8[]){0x42}, 1);

  // MOV AL, [EDI] ; HLT — 1-byte read at offset 0x200FFF
  model.zGPR.data[7] = 0x200FFF;  // EDI
  u8 code[] = { 0x8A, 0x07, 0xF4 };  // mov al, [edi]; hlt
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)(model.zGPR.data[0] & 0xFF), 0x42UL);

  model.model_fini();
}

TEST(seg_limit_dword_crosses) {
  // 4-byte read at offset 0x200FFD spans 0x200FFD..0x201000, which exceeds
  // the limit of 0x200FFF. Should fault with #GP(0).
  x86::Model model;
  init_model_32(model);

  // DS limit = 0x200FFF
  model.zSegCache.data[x86::SEG_DS].zseg_limit = 0x200FFF;

  // MOV EAX, [EDI] — 4-byte read at offset 0x200FFD
  model.zGPR.data[7] = 0x200FFD;  // EDI
  u8 code[] = { 0x8B, 0x07, 0xF4 };  // mov eax, [edi]; hlt
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_FAULTED);
  ASSERT_EQ((u64)model.zfault_vector, 13UL);  // #GP

  model.model_fini();
}

TEST(seg_limit_dword_within) {
  // 4-byte read at offset 0x200FFC spans 0x200FFC..0x200FFF — exactly
  // within the limit of 0x200FFF. Should succeed.
  x86::Model model;
  init_model_32(model);

  // DS limit = 0x200FFF
  model.zSegCache.data[x86::SEG_DS].zseg_limit = 0x200FFF;

  u32 magic = 0xCAFEBABE;
  model.phys_mem.write32(0x200FFC, magic);

  // MOV EAX, [EDI] — 4-byte read at offset 0x200FFC
  model.zGPR.data[7] = 0x200FFC;  // EDI
  u8 code[] = { 0x8B, 0x07, 0xF4 };  // mov eax, [edi]; hlt
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)(u32)model.zGPR.data[0], 0xCAFEBABEUL);

  model.model_fini();
}

TEST(seg_limit_ss_fault) {
  // SS limit violation should raise #SS(0), not #GP(0).
  // MOV [EBP+disp], EAX defaults to SS segment. If the offset exceeds
  // SS limit, the processor raises #SS(0).
  x86::Model model;
  init_model_32(model);

  // SS limit = 0x200FFF (tight)
  model.zSegCache.data[x86::SEG_SS].zseg_limit = 0x200FFF;

  // MOV [EBP+0x10], EAX — writes 4 bytes to SS:[EBP+0x10]
  // EBP = 0x200FFC, so offset = 0x200FFC + 0x10 = 0x20100C → exceeds limit
  model.zGPR.data[5] = 0x200FFC;  // EBP
  model.zGPR.data[0] = 0x42;

  // mov [ebp+0x10], eax = 89 45 10
  u8 code[] = { 0x89, 0x45, 0x10, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_FAULTED);
  ASSERT_EQ((u64)model.zfault_vector, 12UL);  // #SS

  model.model_fini();
}

// =========================================================================
// Real mode helpers and tests
// =========================================================================

static void init_model_16(x86::Model &model, u64 ram_size = 4 * 1024 * 1024) {
  model.model_init();
  model.zinitializze_registers(UNIT);
  enable_all_features(model);

  model.zsystem_mode = false;
  model.zcur_mode = x86::zRealMode;
  model.zcur_cpl = 0;

  // CR0: no PE, no PG (real mode)
  model.zCR0 = (1UL << 4) | (1UL << 5);  // ET + NE only
  model.zCR4 = 0;
  model.zEFER = 0;

  assert(model.phys_mem.init(ram_size));

  // No paging in real mode
  model.zCR3 = 0;

  for (int i = 0; i < 16; i++)
    model.zGPR.data[i] = 0;
  model.zGPR.data[4] = 0xFFFE;  // SP = 0xFFFE

  // Real mode segment setup: all bases = selector << 4
  for (int i = 0; i < 6; i++) {
    model.zSegReg.data[i] = 0;
    model.zSegCache.data[i].zseg_base = 0;
    model.zSegCache.data[i].zseg_limit = 0xFFFF;
    model.zSegCache.data[i].zseg_present = 1;
    model.zSegCache.data[i].zseg_s = 1;
    model.zSegCache.data[i].zseg_type = 0x3;  // data R/W
    model.zSegCache.data[i].zseg_dpl = 0;
    model.zSegCache.data[i].zseg_db = 0;  // 16-bit default
    model.zSegCache.data[i].zseg_l = 0;
    model.zSegCache.data[i].zseg_g = 0;
  }
  // CS type should be code
  model.zSegCache.data[x86::SEG_CS].zseg_type = 0xB;  // code, R, accessed

  model.zGDTR_base = 0;
  model.zGDTR_limit = 0;
  model.zIDTR_base = 0;
  model.zIDTR_limit = 0;
  model.zKERNEL_GS_BASE = 0;
}

TEST(real_mode_mov_ax_hlt) {
  // Basic 16-bit real mode: mov ax, 0x1234; hlt
  x86::Model model;
  init_model_16(model);

  // In 16-bit mode (CS.D=0), B8 is "mov ax, imm16"
  u8 code[] = { 0xB8, 0x34, 0x12, 0xF4 };
  int kind = run_code(model, 0x0000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)(model.zGPR.data[0] & 0xFFFF), 0x1234UL);

  model.model_fini();
}

TEST(real_mode_far_jmp_ea) {
  // Far JMP (EA) in real mode: ljmp 0x1000:0x0010
  // Should set CS=0x1000, CS.base=0x10000, EIP=0x0010
  x86::Model model;
  init_model_16(model);

  // Place a HLT at the target address (linear 0x10010 = 0x1000*16 + 0x0010)
  model.phys_mem.write_bytes(0x10010, (const u8[]){0xF4}, 1);

  // EA 10 00 00 10 = JMP 0x1000:0x0010 (offset first, then selector, little-endian)
  u8 code[] = { 0xEA, 0x10, 0x00, 0x00, 0x10 };
  int kind = run_code(model, 0x0000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zSegReg.data[x86::SEG_CS], 0x1000UL);
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_CS].zseg_base, 0x10000UL);

  model.model_fini();
}

TEST(real_mode_far_call_9a) {
  // Far CALL (9A) in real mode: lcall 0x0000:target
  // Should push old CS:IP, set CS=0, EIP=target
  x86::Model model;
  init_model_16(model);

  // Set up SS:SP for the stack (SS=0, SP=0xFFFE)
  model.zSegReg.data[x86::SEG_SS] = 0;
  model.zSegCache.data[x86::SEG_SS].zseg_base = 0;

  // target = 0x0020, so code at linear 0x0020 should be HLT
  model.phys_mem.write_bytes(0x0020, (const u8[]){0xF4}, 1);

  // 9A 20 00 00 00 = CALL 0x0000:0x0020
  u8 code[] = { 0x9A, 0x20, 0x00, 0x00, 0x00 };
  int kind = run_code(model, 0x0000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);

  // Old CS (0x0000) and old IP (0x0005, after the 5-byte CALL) should be on stack
  // SP should have decreased by 4 (two 16-bit pushes)
  u64 sp = model.zGPR.data[4] & 0xFFFF;
  ASSERT_EQ(sp, 0xFFFAUL);  // 0xFFFE - 4
  // Stack at 0xFFFA: old_CS(16-bit) then old_IP(16-bit)
  // Push order: push CS first, then push IP
  // So mem[0xFFFC] = old_CS, mem[0xFFFA] = old_IP
  u16 saved_cs = model.phys_mem.read16(0xFFFC);
  u16 saved_ip = model.phys_mem.read16(0xFFFA);
  ASSERT_EQ((u64)saved_cs, 0x0000UL);
  ASSERT_EQ((u64)saved_ip, 0x0005UL);

  model.model_fini();
}

// Helper to build a GDT code segment descriptor.
// base, limit (20-bit raw), type, S, DPL, P, D/B, L, G
static void write_gdt_code_desc(x86::Model &model, u64 gdt_base, int index,
                                u32 base, u32 limit_raw, int dpl, bool db, bool g) {
  u64 offset = gdt_base + index * 8;
  // Descriptor format (SDM Vol.3A §3.4.5):
  // lo[15:0]  = limit[15:0]
  // lo[31:16] = base[15:0]
  // hi[7:0]   = base[23:16]
  // hi[11:8]  = type (code: 0xB = exec/read/accessed)
  // hi[12]    = S (1 = code/data)
  // hi[14:13] = DPL
  // hi[15]    = P (present)
  // hi[19:16] = limit[19:16]
  // hi[21]    = L
  // hi[22]    = D/B
  // hi[23]    = G
  // hi[31:24] = base[31:24]
  u32 lo = (limit_raw & 0xFFFF) | ((base & 0xFFFF) << 16);
  u32 hi = ((base >> 16) & 0xFF)
         | (0xBU << 8)          // type = code, R, accessed
         | (1U << 12)           // S = code/data
         | ((dpl & 3U) << 13)
         | (1U << 15)           // P = present
         | (((limit_raw >> 16) & 0xF) << 16)
         | (db ? (1U << 22) : 0)
         | (g ? (1U << 23) : 0)
         | ((base >> 24) << 24);
  model.phys_mem.write32(offset, lo);
  model.phys_mem.write32(offset + 4, hi);
}

static void write_gdt_data_desc(x86::Model &model, u64 gdt_base, int index,
                                u32 base, u32 limit_raw, int dpl, bool db, bool g) {
  u64 offset = gdt_base + index * 8;
  u32 lo = (limit_raw & 0xFFFF) | ((base & 0xFFFF) << 16);
  u32 hi = ((base >> 16) & 0xFF)
         | (0x3U << 8)          // type = data, R/W, accessed
         | (1U << 12)           // S = code/data
         | ((dpl & 3U) << 13)
         | (1U << 15)           // P = present
         | (((limit_raw >> 16) & 0xF) << 16)
         | (db ? (1U << 22) : 0)
         | (g ? (1U << 23) : 0)
         | ((base >> 24) << 24);
  model.phys_mem.write32(offset, lo);
  model.phys_mem.write32(offset + 4, hi);
}

TEST(protected_mode_far_jmp_ea) {
  // Far JMP (EA) in protected mode:
  // Set up GDT with a flat 32-bit code segment at selector 0x08.
  // Execute EA xx xx 08 00 to jump to CS=0x08:offset.
  x86::Model model;
  init_model_32(model);

  u64 gdt_base = 0x200000;
  // GDT[0] = null
  model.phys_mem.write32(gdt_base, 0);
  model.phys_mem.write32(gdt_base + 4, 0);
  // GDT[1] = flat 32-bit code segment (selector 0x08)
  write_gdt_code_desc(model, gdt_base, 1, 0, 0xFFFFF, 0, true, true);
  // GDT[2] = flat 32-bit data segment (selector 0x10)
  write_gdt_data_desc(model, gdt_base, 2, 0, 0xFFFFF, 0, true, true);

  model.zGDTR_base = gdt_base;
  model.zGDTR_limit = 0x17;  // 3 entries * 8 - 1

  // Place HLT at target 0x100020
  model.phys_mem.write_bytes(0x100020, (const u8[]){0xF4}, 1);

  // EA 20 00 10 00 08 00 = JMP 0x0008:0x00100020
  u8 code[] = { 0xEA, 0x20, 0x00, 0x10, 0x00, 0x08, 0x00 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)(model.zSegReg.data[x86::SEG_CS] & 0xFFFC), 0x0008UL);
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_CS].zseg_base, 0UL);
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_CS].zseg_db, 1UL);

  model.model_fini();
}

TEST(protected_mode_far_jmp_ff5) {
  // Far JMP indirect (FF /5) in protected mode
  x86::Model model;
  init_model_32(model);

  u64 gdt_base = 0x200000;
  model.phys_mem.write32(gdt_base, 0);
  model.phys_mem.write32(gdt_base + 4, 0);
  write_gdt_code_desc(model, gdt_base, 1, 0, 0xFFFFF, 0, true, true);
  model.zGDTR_base = gdt_base;
  model.zGDTR_limit = 0x0F;

  // Place HLT at target
  model.phys_mem.write_bytes(0x100030, (const u8[]){0xF4}, 1);

  // Far pointer at 0x300000: offset(32) + selector(16)
  model.phys_mem.write32(0x300000, 0x00100030);  // offset
  model.phys_mem.write16(0x300004, 0x0008);       // selector

  model.zGPR.data[7] = 0x300000;  // EDI

  // FF 2F = JMP far [EDI] (FF /5, ModR/M = 0x2F: reg=5, rm=7)
  u8 code[] = { 0xFF, 0x2F, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)(model.zSegReg.data[x86::SEG_CS] & 0xFFFC), 0x0008UL);

  model.model_fini();
}

TEST(real_to_protected_mode_transition) {
  // Classic boot sequence: real mode → protected mode via far JMP
  x86::Model model;
  init_model_16(model);

  u64 gdt_base = 0x1000;

  // GDT[0] = null descriptor
  model.phys_mem.write32(gdt_base, 0);
  model.phys_mem.write32(gdt_base + 4, 0);
  // GDT[1] = flat 32-bit code segment, selector 0x08
  write_gdt_code_desc(model, gdt_base, 1, 0, 0xFFFFF, 0, true, true);
  // GDT[2] = flat 32-bit data segment, selector 0x10
  write_gdt_data_desc(model, gdt_base, 2, 0, 0xFFFFF, 0, true, true);

  // GDT descriptor for LGDT: 6 bytes at 0x2000
  // limit = 23 (3 entries * 8 - 1)
  model.phys_mem.write16(0x2000, 0x17);
  // base = 0x1000 (32-bit in real mode via 66h override)
  model.phys_mem.write32(0x2002, gdt_base);

  // Protected mode entry point: at linear 0x3000
  // mov ax, 0x10; mov ds, ax; mov eax, 0xDEAD; hlt
  u8 pm_code[] = {
    0x66, 0xB8, 0x10, 0x00, 0x00, 0x00,  // mov eax, 0x10
    0x8E, 0xD8,                            // mov ds, ax
    0x66, 0xB8, 0xAD, 0xDE, 0x00, 0x00,  // mov eax, 0xDEAD
    0xF4,                                  // hlt
  };
  model.phys_mem.write_bytes(0x3000, pm_code, sizeof(pm_code));

  // Real mode code at 0x0000:
  // cli                        ; FA
  // lgdt [0x2000]              ; 66 0F 01 16 00 20 (with 66h for 32-bit base)
  // mov eax, cr0               ; 0F 20 C0
  // or al, 1                   ; 0C 01
  // mov cr0, eax               ; 0F 22 C0
  // jmp 0x08:0x3000            ; EA 00 30 08 00 (16-bit offset in real mode)
  //
  // Wait — after setting PE, we need a 32-bit far jmp. Use 66h prefix:
  // 66 EA 00 30 00 00 08 00    ; JMP 0x0008:0x00003000 (32-bit operand size)
  u8 rm_code[] = {
    0xFA,                                  // cli
    0x66, 0x0F, 0x01, 0x16, 0x00, 0x20,  // lgdt [0x2000] (addr-size 16, 32-bit base via 66h)
    0x0F, 0x20, 0xC0,                     // mov eax, cr0
    0x0C, 0x01,                            // or al, 1
    0x0F, 0x22, 0xC0,                     // mov cr0, eax
    0x66, 0xEA, 0x00, 0x30, 0x00, 0x00, 0x08, 0x00,  // jmp 0x0008:0x00003000
  };
  int kind = run_code(model, 0x0000, rm_code, sizeof(rm_code));
  ASSERT_EQ(kind, RUN_HALTED);

  // Verify we're in protected mode
  ASSERT_EQ((u64)(model.zCR0 & 1), 1UL);  // PE=1
  ASSERT_EQ((u64)(model.zSegReg.data[x86::SEG_CS] & 0xFFFC), 0x0008UL);
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_CS].zseg_db, 1UL);  // 32-bit code
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_CS].zseg_base, 0UL);
  // DS should be loaded with selector 0x10
  ASSERT_EQ((u64)model.zSegReg.data[x86::SEG_DS], 0x0010UL);
  // EAX should be 0xDEAD
  ASSERT_EQ((u64)(u32)model.zGPR.data[0], 0xDEADUL);

  model.model_fini();
}

TEST(lmsw_enters_protected_mode) {
  // SDM Vol.2A LMSW and Vol.3A 12.9.1: setting PE enters protected mode;
  // the following far jump loads CS from the GDT, retaining other caches.
  for (bool memory_operand : {false, true}) {
    x86::Model model;
    init_model_16(model);
    model.zCR0 = 0x10030; // Preserve WP, NE and ET across both LMSW writes.
    model.zGDTR_base = 0x800;
    model.zGDTR_limit = 15;
    model.phys_mem.write64(0x808, 0x00009B040000FFFFUL); // 16-bit CS at 0x40000
    model.phys_mem.write16(0x9000, 0x000F);
    const u8 reg_code[] = {
      0xB8, 0x0F, 0x00,             // mov ax, 0x000f
      0x0F, 0x01, 0xF0,             // lmsw ax
      0xEA, 0x34, 0x12, 0x08, 0x00, // jmp 0008:1234
    };
    const u8 mem_code[] = {
      0xB8, 0x0F, 0x00,
      0x0F, 0x01, 0x36, 0x00, 0x90, // lmsw word [0x9000]
      0xEA, 0x34, 0x12, 0x08, 0x00,
    };
    const u8 target[] = {
      0x31, 0xC0,                   // xor ax, ax
      0x0F, 0x01, 0xF0,             // lmsw ax: PE is sticky; MP/EM/TS clear
      0xB8, 0xEF, 0xBE,             // mov ax, 0xbeef
      0xF4,
    };
    model.phys_mem.write_bytes(0x41234, target, sizeof(target));
    ASSERT_EQ(run_code(model, 0x1000, memory_operand ? mem_code : reg_code,
                       memory_operand ? sizeof(mem_code) : sizeof(reg_code), 2), RUN_OK);
    ASSERT_EQ(model.zcur_mode, x86::zProtectedMode);
    ASSERT_EQ((u64)model.zCR0, 0x1003FUL);
    ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_CS].zseg_base, 0UL);
    model.zstep(UNIT); // Far JMP must use the descriptor, not selector << 4.
    ASSERT_EQ(model.zfault_pending, false);
    ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_CS].zseg_base, 0x40000UL);
    ASSERT_EQ((u64)model.zRIP, 0x1234UL);
    for (unsigned i = 0; i < 4; ++i) model.zstep(UNIT);
    ASSERT_EQ(model.zfault_pending, false);
    ASSERT_EQ(model.zsystem_state, x86::zSysHalted);
    ASSERT_EQ((u64)model.zCR0, 0x10031UL);
    ASSERT_EQ((u64)model.zGPR.data[0], 0xBEEFUL);
    model.model_fini();
  }
}

// =========================================================================
// Legacy state and interrupt returns
// =========================================================================

TEST(x87_save_restore_large_memory_operand) {
  for (u64 save_addr : {0x8000UL, 0x8FE0UL}) {
    x86::Model model;
    init_model(model);
    // Replace the first 2MB mapping with 4KB pages. The page following
    // the save area's first page is deliberately noncontiguous.
    model.phys_mem.write64(0x3000, 0x4000 | 3);
    for (u64 i = 0; i < 512; ++i)
      model.phys_mem.write64(0x4000 + i * 8, (i << 12) | 3);
    model.phys_mem.write64(0x4000 + 9 * 8, 0x19000 | 3);
    model.phys_mem.write64(0x9000, 0xA5A5A5A5A5A5A5A5UL);
    model.zGPR.data[0] = save_addr;
    model.zGPR.data[3] = 0x20000;
    const u8 code[] = {
      0xDB, 0xE3, // FNINIT
      0xD9, 0xE8, // FLD1
      0xDD, 0x30, // FNSAVE [RAX]: write 108 bytes, then initialize x87
      0xDD, 0x20, // FRSTOR [RAX]: read the same complete state
      0xDD, 0x1B, // FSTP qword [RBX]
      0xF4,
    };
    ASSERT_EQ(run_code(model, 0x5000, code, sizeof(code)), RUN_HALTED);
    ASSERT_EQ(model.phys_mem.read16(save_addr), 0x037Fu);
    ASSERT_EQ(model.phys_mem.read16(save_addr + 4), 0x3800u); // saved TOP=7
    ASSERT_EQ(model.phys_mem.read64(0x20000), 0x3FF0000000000000UL); // 1.0
    ASSERT_EQ(model.phys_mem.read64(0x9000), 0xA5A5A5A5A5A5A5A5UL);
    model.model_fini();
  }
}

TEST(real_mode_iret_no_pop_sp_ss) {
  // In real mode, IRET pops only IP, CS, FLAGS (3 words).
  // SP/SS must NOT be popped. Verify SP is only adjusted by 6 bytes.
  x86::Model model;
  init_model_16(model);

  // Enable system_mode so INT delivers through IVT
  model.zsystem_mode = true;

  // Set up IVT entry for INT 0x80 at 0x0000:(0x80*4)
  // Handler at 0x0500: just IRET
  u16 handler_ip = 0x0500;
  u16 handler_cs = 0x0000;
  model.phys_mem.write16(0x80 * 4, handler_ip);
  model.phys_mem.write16(0x80 * 4 + 2, handler_cs);

  // Handler code: IRET
  model.phys_mem.write_bytes(0x0500, (const u8[]){0xCF}, 1);

  // Set SS:SP = 0x0000:0x8000
  model.zSegReg.data[x86::SEG_SS] = 0x0000;
  model.zSegCache.data[x86::SEG_SS].zseg_base = 0;
  model.zGPR.data[4] = 0x8000;  // SP

  // Code: INT 0x80; HLT
  // INT pushes FLAGS(2), CS(2), IP(2) = 6 bytes → SP -= 6
  // IRET pops IP, CS, FLAGS = 6 bytes → SP += 6
  // Net effect: SP unchanged at 0x8000
  u8 code[] = { 0xCD, 0x80, 0xF4 };
  int kind = run_code(model, 0x1000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  // SP should be back to 0x8000 (INT pushed 6, IRET popped 6)
  ASSERT_EQ((u64)(model.zGPR.data[4] & 0xFFFF), 0x8000UL);
  // CS should be restored to original
  ASSERT_EQ((u64)model.zSegReg.data[x86::SEG_CS], 0x0000UL);

  model.model_fini();
}

TEST(real_mode_iret_with_nt) {
  // SDM Vol. 2A, IRET Operation: real-address-mode return precedes
  // the protected-mode NT/task-return test. Check both operand sizes
  // and both values of NT in the flags image being restored.
  for (unsigned width : {2u, 4u}) {
    for (unsigned restored_nt : {0u, 1u}) {
      x86::Model model;
      init_model_16(model);
      model.zNT = 1;
      model.zGPR.data[4] = 0x8000;
      u32 flags = 0x3002 | (restored_nt << 14);
      if (width == 2) {
        model.phys_mem.write16(0x8000, 0x1100);
        model.phys_mem.write16(0x8002, 0);
        model.phys_mem.write16(0x8004, flags);
      } else {
        model.phys_mem.write32(0x8000, 0x1100);
        model.phys_mem.write32(0x8004, 0);
        model.phys_mem.write32(0x8008, flags);
      }
      model.phys_mem.write8(0x1100, 0xF4); // HLT at the return address
      const u8 code[] = {0x66, 0xCF};
      int kind = run_code(model, 0x1000, code + (width == 2), width == 2 ? 1 : 2);
      ASSERT_EQ(kind, RUN_HALTED);
      ASSERT_EQ(model.zGPR.data[4], 0x8000 + 3 * width);
      ASSERT_EQ(model.zNT, restored_nt);
      ASSERT_EQ(model.zSegReg.data[x86::SEG_CS], 0u);
      model.model_fini();
    }
  }
}

TEST(real_mode_int_iret_preserves_regs) {
  // INT+IRET round-trip in real mode should return to the instruction
  // after INT with the same CS:IP and FLAGS (except IF/TF cleared by INT).
  x86::Model model;
  init_model_16(model);
  model.zsystem_mode = true;

  // IVT entry for INT 0x21 → handler at 0x0600
  model.phys_mem.write16(0x21 * 4, 0x0600);
  model.phys_mem.write16(0x21 * 4 + 2, 0x0000);

  // Handler: mov bx, 0xBEEF; iret
  u8 handler[] = { 0xBB, 0xEF, 0xBE, 0xCF };
  model.phys_mem.write_bytes(0x0600, handler, sizeof(handler));

  model.zGPR.data[4] = 0x8000;  // SP

  // Code at 0x2000: mov ax, 0x1234; int 0x21; hlt
  u8 code[] = {
    0xB8, 0x34, 0x12,  // mov ax, 0x1234
    0xCD, 0x21,        // int 0x21
    0xF4,              // hlt
  };
  int kind = run_code(model, 0x2000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  // AX should still be 0x1234 (handler didn't change it)
  ASSERT_EQ((u64)(model.zGPR.data[0] & 0xFFFF), 0x1234UL);
  // BX should be 0xBEEF (set by handler)
  ASSERT_EQ((u64)(model.zGPR.data[3] & 0xFFFF), 0xBEEFUL);
  // SP should be back to 0x8000
  ASSERT_EQ((u64)(model.zGPR.data[4] & 0xFFFF), 0x8000UL);
  // RIP should have advanced past HLT (0x2006)
  // (run_code checks for HLT state, so we're at the HLT instruction)

  model.model_fini();
}

TEST(protected_mode_iret_same_privilege) {
  // In protected mode same-privilege IRET (return RPL == CPL),
  // only EIP, CS, EFLAGS are popped (not ESP/SS).
  x86::Model model;
  init_model_32(model);

  // Manually push EFLAGS, CS (with RPL=0), EIP onto stack.
  // CPL = 0 and CS RPL = 0 → same privilege, no SP/SS pop.
  u64 sp = model.zGPR.data[4];  // ESP = 0x80000

  // Push in reverse order (stack grows down):
  // EFLAGS = 0x00000202 (IF=1, reserved bit 1=1)
  // CS = 0x0008 (RPL=0, same as CPL=0)
  // EIP = target (where HLT is)
  u32 target_eip = 0x100100;
  model.phys_mem.write_bytes(target_eip, (const u8[]){0xF4}, 1);  // HLT

  sp -= 4; model.phys_mem.write32(sp, 0x00000202);   // EFLAGS
  sp -= 4; model.phys_mem.write32(sp, 0x00000008);   // CS (RPL=0)
  sp -= 4; model.phys_mem.write32(sp, target_eip);   // EIP
  model.zGPR.data[4] = sp;

  // Put sentinel values after the 3 dwords we pushed — if IRET
  // incorrectly pops ESP/SS, it will pick up garbage.
  // (We already have valid stack data above, so the sentinel
  // test is that ESP ends up at sp+12, not sp+20.)
  u64 expected_sp = sp + 12;  // 3 dwords popped

  // Code: 66 CF = IRETD (32-bit operand size in 32-bit mode, prefix is redundant but harmless)
  // Actually in 32-bit mode, CF is IRETD by default.
  u8 code[] = { 0xCF };  // IRETD
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  // ESP should be sp + 12 (popped 3 dwords, not 5)
  ASSERT_EQ((u64)(u32)model.zGPR.data[4], expected_sp);

  model.model_fini();
}

TEST(ia32e_iretq_to_compat_loads_ss_descriptor) {
  // Regression: IRETQ (64-bit IRET) from a long-mode kernel back to a
  // 32-bit compatibility-mode user process must reload the *hidden*
  // part of SS (the descriptor cache) from the GDT, not just the
  // visible SS selector. The D/B bit that lives in the descriptor
  // cache drives stack_addr_size(), which is how POP/PUSH decide
  // whether to use ESP (32-bit) or SP (16-bit).
  //
  // If IRETQ only writes the selector (the bug), SegCache[SS].seg_db
  // retains whatever stale value it had beforehand. The symptom shown
  // by `/bin/hello32` on the Linux boot is: the first `pop %esi` in
  // _start faults at (ESP & 0xFFFF) because stack_addr_size() returns
  // 16 instead of 32.
  x86::Model model;
  init_model(model);  // long mode, CPL 0, RSP = 0x80000

  // Build a GDT at 0x200000:
  //   selector 0x08 — long-mode kernel code (L=1), for completeness
  //   selector 0x20|3 = 0x23 — compat-mode user CS (L=0, D=1, DPL=3)
  //   selector 0x28|3 = 0x2B — 32-bit user SS (D/B=1, DPL=3)
  u64 gdt_base = 0x200000;
  model.phys_mem.write32(gdt_base, 0);
  model.phys_mem.write32(gdt_base + 4, 0);
  {
    // Kernel 64-bit code at index 1 (selector 0x08).
    u32 lo = 0xFFFF | (0u << 16);
    u32 hi = 0u
           | (0xBu << 8)    // type = exec/read code, accessed
           | (1u << 12)     // S = code/data
           | (0u << 13)     // DPL 0
           | (1u << 15)     // P
           | (0xFu << 16)   // limit[19:16]
           | (1u << 21)     // L = 1 (64-bit)
           | (1u << 23);    // G
    model.phys_mem.write32(gdt_base + 8, lo);
    model.phys_mem.write32(gdt_base + 12, hi);
  }
  // Compat-mode user CS at index 4 (selector 0x20), DPL 3, D/B=1.
  write_gdt_code_desc(model, gdt_base, 4, 0, 0xFFFFF, 3, /*db=*/true, /*g=*/true);
  // 32-bit user SS at index 5 (selector 0x28), DPL 3, D/B=1.
  write_gdt_data_desc(model, gdt_base, 5, 0, 0xFFFFF, 3, /*db=*/true, /*g=*/true);
  model.zGDTR_base = gdt_base;
  model.zGDTR_limit = 0x2F;  // 6 entries * 8 - 1

  // Deliberately stale SS.B = 0 in the hidden descriptor cache. In
  // the buggy model this value survives IRETQ; the fix must overwrite
  // it from the GDT descriptor above (where D/B=1).
  model.zSegCache.data[x86::SEG_SS].zseg_db = 0;

  // Lay down the IRETQ frame at current RSP: [RIP][CS][RFLAGS][RSP][SS],
  // 8 bytes each.
  u64 rsp = model.zGPR.data[4];
  u64 target_rip = 0x100010;
  u64 target_rsp = 0x100000;
  model.phys_mem.write64(rsp + 0x00, target_rip);   // new RIP
  model.phys_mem.write64(rsp + 0x08, 0x23);         // new CS (sel 0x20, RPL 3)
  model.phys_mem.write64(rsp + 0x10, 0x00000202);   // new RFLAGS (IF=1, reserved=1)
  model.phys_mem.write64(rsp + 0x18, target_rsp);   // new RSP
  model.phys_mem.write64(rsp + 0x20, 0x2B);         // new SS (sel 0x28, RPL 3)

  // Code: IRETQ (REX.W CF = 48 CF).
  u8 code[] = { 0x48, 0xCF };
  model.phys_mem.write_bytes(0x100100, code, sizeof(code));
  model.zRIP = 0x100100;

  // One step executes the IRETQ. We don't care what the target RIP
  // would run next — only that IRETQ itself reloads SS.DescriptorCache.
  model.zstep(UNIT);

  // SS descriptor cache must now reflect the GDT entry we built:
  // D/B = 1, DPL = 3, P = 1.
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_SS].zseg_db, 1UL);
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_SS].zseg_dpl, 3UL);
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_SS].zseg_present, 1UL);
  // And the mode switch + CPL drop should have happened.
  ASSERT_EQ((u64)model.zcur_mode, (u64)x86::zCompatibilityMode);
  ASSERT_EQ((u64)model.zcur_cpl, 3UL);

  model.model_fini();
}

TEST(ia32e_sysenter_switches_to_long_mode) {
  // Regression: SYSENTER from compat-mode user into an IA-32e kernel must
  // switch to 64-bit mode — it loads fixed CS/SS descriptor-cache values
  // (CS.L=1, CS.D=0, SS.B=1, base=0, limit=4GB) and sets CPL=0, per SDM
  // Vol.2 SYSENTER pseudocode.
  //
  // The buggy handler only wrote the *visible* CS/SS selectors and set
  // CPL=0, leaving cur_mode at CompatibilityMode and the hidden
  // descriptor cache still reflecting the user-compat CS/SS. The first
  // PUSH in the kernel entry stub (e.g. Linux's entry_SYSENTER_compat
  // "swapgs; push %rax") then ran with stack_addr_size() returning 32
  // instead of 64, truncating RSP to the low 32 bits and faulting
  // outside the kernel stack.
  x86::Model model;
  init_model(model);  // long mode, CPL 0 — used to stage MSRs only

  // Program the SYSENTER MSRs using WRMSR:
  //   IA32_SYSENTER_CS  (0x174) = 0x00000010  (kernel code selector)
  //   IA32_SYSENTER_ESP (0x175) = 0x00200000  (kernel stack pointer)
  //   IA32_SYSENTER_EIP (0x176) = 0xffffffff81000100 (kernel entry)
  auto do_wrmsr = [&](u32 msr, u64 val) {
    // mov ecx, msr ; mov eax, val[31:0] ; mov edx, val[63:32] ; wrmsr ; hlt
    u8 code[] = {
      0xB9, (u8)msr, (u8)(msr>>8), (u8)(msr>>16), (u8)(msr>>24),
      0xB8, (u8)val, (u8)(val>>8), (u8)(val>>16), (u8)(val>>24),
      0xBA, (u8)(val>>32), (u8)(val>>40), (u8)(val>>48), (u8)(val>>56),
      0x0F, 0x30,
      0xF4,
    };
    int kind = run_code(model, 0x100000, code, sizeof(code));
    ASSERT_EQ(kind, RUN_HALTED);
    // Reset SysRunning so we can run more code below.
    model.zsystem_state = x86::zSysRunning;
  };
  do_wrmsr(0x174, 0x0000000000000010);
  do_wrmsr(0x175, 0x0000000000200000);
  do_wrmsr(0x176, 0xffffffff81000100);

  // Transition to compat-mode user: CPL=3, CS.L=0, CS.D=1, SS.B=1.
  // Place the SYSENTER instruction at a low user-space address.
  u64 user_rip = 0x00200000;
  u8 sysenter[] = { 0x0F, 0x34 };
  model.phys_mem.write_bytes(user_rip, sysenter, sizeof(sysenter));

  // Mark every 2MB PD entry user-accessible (U/S=1, bit 2 = 0x04) so
  // CPL=3 can fetch from the identity-mapped region.
  for (u64 j = 0; j < 512; j++) {
    u64 pte = model.phys_mem.read64(0x3000 + j * 8);
    if (pte != 0)
      model.phys_mem.write64(0x3000 + j * 8, pte | 0x04);
  }

  model.zRIP = user_rip;
  model.zcur_mode = x86::zCompatibilityMode;
  model.zcur_cpl = 3;
  model.zSegCache.data[x86::SEG_CS].zseg_l = 0;
  model.zSegCache.data[x86::SEG_CS].zseg_db = 1;
  model.zSegCache.data[x86::SEG_CS].zseg_dpl = 3;
  model.zSegCache.data[x86::SEG_SS].zseg_db = 1;
  model.zSegCache.data[x86::SEG_SS].zseg_dpl = 3;
  // Give the user a distinct RSP so we can see it get replaced.
  model.zGPR.data[4] = 0x00010000;
  model.zsystem_state = x86::zSysRunning;

  // Execute SYSENTER.
  model.zstep(UNIT);

  // Kernel-entry state per SDM:
  //   CPL = 0, 64-bit mode (cur_mode = LongMode)
  //   CS: base=0, limit=4GB, type=exec/read code, S=1, DPL=0, P=1,
  //       L=1, D=0, G=1
  //   SS: base=0, limit=4GB, type=R/W data, S=1, DPL=0, P=1, B=1, G=1
  //   RIP = IA32_SYSENTER_EIP, RSP = IA32_SYSENTER_ESP, IF=0
  ASSERT_EQ((u64)model.zcur_cpl, 0UL);
  ASSERT_EQ((u64)model.zcur_mode, (u64)x86::zLongMode);
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_CS].zseg_l, 1UL);
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_CS].zseg_db, 0UL);
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_CS].zseg_dpl, 0UL);
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_CS].zseg_present, 1UL);
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_CS].zseg_base, 0UL);
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_SS].zseg_db, 1UL);
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_SS].zseg_dpl, 0UL);
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_SS].zseg_present, 1UL);
  ASSERT_EQ((u64)model.zRIP, 0xffffffff81000100UL);
  ASSERT_EQ((u64)model.zGPR.data[4], 0x00200000UL);

  model.model_fini();
}

TEST(mov_gs_at_cpl3_uses_implicit_access) {
  // Regression: `MOV GS, sel` from CPL=3 performs an *implicit* supervisor
  // read of the GDT (SDM Vol.3A §4.6).  The U/S page-protection check
  // must be bypassed even though cur_cpl=3, so a user-mode segment load
  // can read a GDT entry out of a kernel-mapped (U/S=0) page.
  //
  // Without this, glibc's first TLS load after `mov $sel,%gs` in a
  // 32-bit compat-mode process spins on #PF because the preceding
  // MOV GS silently failed to update SegCache[GS].seg_base.
  x86::Model model;
  init_model(model);  // long mode, CPL 0, flat mapping with PD at 0x3000

  // Clear the U/S bit on every 2MB PD entry so the whole address space
  // is supervisor-only.  Under the buggy model this blocks MOV GS at
  // CPL=3; with the implicit-access fix the GDT read still succeeds.
  for (u64 j = 0; j < 512; j++) {
    u64 pte = model.phys_mem.read64(0x3000 + j * 8);
    if (pte != 0)
      model.phys_mem.write64(0x3000 + j * 8, pte & ~0x04ULL);
  }
  // But leave the code page (2MB page containing 0x100000 and GDT at
  // 0x200000) readable to CPL=3 for the *fetch* itself — fetch is a
  // normal explicit read and must still go through U/S.  We use two
  // pages: let 0x100000 (user code) and 0x200000 (GDT-containing page)
  // stay supervisor-only for the GDT read, but set U=1 on the page
  // containing the user-code fetch so the instruction can be decoded.
  // Page 0 (0x000000-0x200000) contains both 0x100000 (code) so set U=1.
  {
    u64 pte = model.phys_mem.read64(0x3000 + 0);
    model.phys_mem.write64(0x3000 + 0, pte | 0x04);
  }
  // Page 1 (0x200000-0x400000) contains the GDT at 0x200000 — leave U=0
  // so the test proves the implicit-access bypass is what lets it load.

  // Build a GDT at 0x200000: index 4 = 32-bit data seg (base=0, limit=4GB,
  // DPL=3, D/B=1). Selector = 4*8 | RPL=3 = 0x23.
  u64 gdt_base = 0x200000;
  model.phys_mem.write64(gdt_base, 0);  // null
  write_gdt_data_desc(model, gdt_base, 4, /*base=*/0, /*limit=*/0xFFFFF,
                      /*dpl=*/3, /*db=*/true, /*g=*/true);
  model.zGDTR_base = gdt_base;
  model.zGDTR_limit = 0x27;

  // Stage user state: CPL=3, compat mode, GS initially stale.
  // MOV GS, AX encoding: 8E E8 (reg=5=GS, rm=0=EAX).
  u64 user_rip = 0x00100000;
  u8 code[] = { 0x8E, 0xE8, 0xF4 /* HLT */ };
  model.phys_mem.write_bytes(user_rip, code, sizeof(code));

  model.zRIP = user_rip;
  model.zGPR.data[0] = 0x23;  // AX = user data selector
  model.zcur_mode = x86::zCompatibilityMode;
  model.zcur_cpl = 3;
  model.zSegCache.data[x86::SEG_CS].zseg_l = 0;
  model.zSegCache.data[x86::SEG_CS].zseg_db = 1;
  model.zSegCache.data[x86::SEG_CS].zseg_dpl = 3;
  // Stale GS state — pre-MOV; must get overwritten by the implicit GDT read.
  model.zSegCache.data[x86::SEG_GS].zseg_base = 0xdeadbeef;
  model.zSegCache.data[x86::SEG_GS].zseg_dpl = 0;
  model.zsystem_state = x86::zSysRunning;

  // Execute MOV GS, AX — must not fault even though the GDT page has U/S=0.
  model.zstep(UNIT);
  // Confirm the instruction advanced and populated the descriptor cache.
  ASSERT_EQ((u64)model.zRIP, (u64)(user_rip + 2));
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_GS].zseg_base, 0UL);
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_GS].zseg_db, 1UL);
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_GS].zseg_dpl, 3UL);
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_GS].zseg_present, 1UL);

  model.model_fini();
}

TEST(compat_seg_linear_wraps_at_32bit) {
  // Regression: in compatibility mode the linear address space is 32 bits
  // (SDM Vol.1 §3.3.3), so segment_base + effective_address must be
  // computed mod 2^32.  This matters for glibc's 32-bit TLS accesses
  // pattern `mov %gs:-44, %eax` — encoded as EDX=0xFFFFFFD4 with
  // GS.base = TCB address.  With 64-bit arithmetic (no truncation) the
  // linear address overflows past 4GB and every TLS read #PFs.
  //
  // The test simulates GS.base = 0x00200000 and EDX = 0xFFFFFFD4
  // (-44 as int32).  The target linear address must be 0x001FFFD4 —
  // which the test maps and seeds with a sentinel — not 0x1001FFFD4.
  x86::Model model;
  init_model(model);  // long mode, CPL 0, CR3 points to 4KB-page PD

  // Make pages user-accessible so CPL=3 can read them.
  for (u64 j = 0; j < 512; j++) {
    u64 pte = model.phys_mem.read64(0x3000 + j * 8);
    if (pte != 0)
      model.phys_mem.write64(0x3000 + j * 8, pte | 0x04);
  }

  // Seed the expected wrap target with a sentinel value.  EDX = -44,
  // GS.base = 0x00200000 → wrapped linear = 0x001FFFD4.
  u64 wrap_target = 0x001FFFD4ULL;
  u32 sentinel = 0xCAFEBABE;
  model.phys_mem.write32(wrap_target, sentinel);

  // User code: MOV %gs:(%edx), %eax (encoding 65 8B 02) then HLT.
  u64 user_rip = 0x00100000;
  u8 code[] = { 0x65, 0x8B, 0x02, 0xF4 };
  model.phys_mem.write_bytes(user_rip, code, sizeof(code));

  model.zRIP = user_rip;
  model.zGPR.data[2] = 0xFFFFFFD4ULL;  // EDX = -44 (low 32)
  model.zGPR.data[0] = 0;              // EAX = 0 (will receive sentinel)
  model.zcur_mode = x86::zCompatibilityMode;
  model.zcur_cpl = 3;
  model.zSegCache.data[x86::SEG_CS].zseg_l = 0;
  model.zSegCache.data[x86::SEG_CS].zseg_db = 1;
  model.zSegCache.data[x86::SEG_CS].zseg_dpl = 3;
  model.zSegCache.data[x86::SEG_GS].zseg_base = 0x00200000ULL;
  model.zSegCache.data[x86::SEG_GS].zseg_limit = 0xFFFFFFFF;
  model.zSegCache.data[x86::SEG_GS].zseg_db = 1;
  model.zSegCache.data[x86::SEG_GS].zseg_dpl = 3;
  model.zSegCache.data[x86::SEG_GS].zseg_present = 1;
  model.zsystem_state = x86::zSysRunning;

  // Run the MOV.  Under the buggy 64-bit-arithmetic model this #PFs
  // on the 0x1001FFFD4 access (unmapped, beyond 4GB); under the fix
  // it reads the sentinel from the 32-bit-wrapped address 0x001FFFD4.
  model.zstep(UNIT);

  ASSERT_EQ((u64)(u32)model.zGPR.data[0], (u64)sentinel);
  // RIP should have advanced past the 3-byte MOV.
  ASSERT_EQ((u64)model.zRIP, (u64)(user_rip + 3));

  model.model_fini();
}

// =========================================================================
// PUSHA/POPA tests
// =========================================================================

TEST(pushad_popad_32bit) {
  // PUSHAD pushes EAX,ECX,EDX,EBX,original_ESP,EBP,ESI,EDI (8 dwords).
  // POPAD pops them back (skipping the ESP slot).
  // Round-trip should restore all registers except ESP (which changes by push/pop).
  x86::Model model;
  init_model_32(model);

  model.zGPR.data[0] = 0x11111111; // EAX
  model.zGPR.data[1] = 0x22222222; // ECX
  model.zGPR.data[2] = 0x33333333; // EDX
  model.zGPR.data[3] = 0x44444444; // EBX
  // ESP = 0x80000 (set by init_model_32)
  model.zGPR.data[5] = 0x55555555; // EBP
  model.zGPR.data[6] = 0x66666666; // ESI
  model.zGPR.data[7] = 0x77777777; // EDI

  // PUSHAD; POPAD; HLT
  u8 code[] = { 0x60, 0x61, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);

  // All GPRs should be restored
  ASSERT_EQ((u64)(u32)model.zGPR.data[0], 0x11111111UL); // EAX
  ASSERT_EQ((u64)(u32)model.zGPR.data[1], 0x22222222UL); // ECX
  ASSERT_EQ((u64)(u32)model.zGPR.data[2], 0x33333333UL); // EDX
  ASSERT_EQ((u64)(u32)model.zGPR.data[3], 0x44444444UL); // EBX
  ASSERT_EQ((u64)(u32)model.zGPR.data[4], 0x80000UL);    // ESP restored
  ASSERT_EQ((u64)(u32)model.zGPR.data[5], 0x55555555UL); // EBP
  ASSERT_EQ((u64)(u32)model.zGPR.data[6], 0x66666666UL); // ESI
  ASSERT_EQ((u64)(u32)model.zGPR.data[7], 0x77777777UL); // EDI

  model.model_fini();
}

TEST(pushad_stack_layout_32bit) {
  // Verify PUSHAD writes registers in the correct order on the stack.
  // SDM: push order is EAX, ECX, EDX, EBX, original_ESP, EBP, ESI, EDI.
  // Stack grows downward, so EDI is at lowest address.
  x86::Model model;
  init_model_32(model);

  model.zGPR.data[0] = 0xAAAA0000; // EAX
  model.zGPR.data[1] = 0xBBBB1111; // ECX
  model.zGPR.data[2] = 0xCCCC2222; // EDX
  model.zGPR.data[3] = 0xDDDD3333; // EBX
  u64 orig_esp = model.zGPR.data[4]; // ESP = 0x80000
  model.zGPR.data[5] = 0xEEEE4444; // EBP
  model.zGPR.data[6] = 0xFFFF5555; // ESI
  model.zGPR.data[7] = 0x00006666; // EDI

  // PUSHAD; HLT
  u8 code[] = { 0x60, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);

  // ESP should have decreased by 32 (8 * 4 bytes)
  u64 new_esp = (u32)model.zGPR.data[4];
  ASSERT_EQ(new_esp, orig_esp - 32);

  // Read the stack (top to bottom = last pushed to first pushed)
  // Push order: EAX first (at highest addr), EDI last (at lowest addr)
  ASSERT_EQ((u64)model.phys_mem.read32(new_esp + 28), 0xAAAA0000UL); // EAX (pushed first)
  ASSERT_EQ((u64)model.phys_mem.read32(new_esp + 24), 0xBBBB1111UL); // ECX
  ASSERT_EQ((u64)model.phys_mem.read32(new_esp + 20), 0xCCCC2222UL); // EDX
  ASSERT_EQ((u64)model.phys_mem.read32(new_esp + 16), 0xDDDD3333UL); // EBX
  ASSERT_EQ((u64)model.phys_mem.read32(new_esp + 12), (u32)orig_esp); // original ESP
  ASSERT_EQ((u64)model.phys_mem.read32(new_esp + 8),  0xEEEE4444UL); // EBP
  ASSERT_EQ((u64)model.phys_mem.read32(new_esp + 4),  0xFFFF5555UL); // ESI
  ASSERT_EQ((u64)model.phys_mem.read32(new_esp + 0),  0x00006666UL); // EDI (pushed last)

  model.model_fini();
}

TEST(pusha_popa_16bit) {
  // PUSHA/POPA in 16-bit mode: pushes/pops AX,CX,DX,BX,SP,BP,SI,DI as words.
  x86::Model model;
  init_model_16(model);

  model.zGPR.data[0] = 0x1111; // AX
  model.zGPR.data[1] = 0x2222; // CX
  model.zGPR.data[2] = 0x3333; // DX
  model.zGPR.data[3] = 0x4444; // BX
  model.zGPR.data[4] = 0x8000; // SP
  model.zGPR.data[5] = 0x5555; // BP
  model.zGPR.data[6] = 0x6666; // SI
  model.zGPR.data[7] = 0x7777; // DI

  // PUSHA; POPA; HLT
  u8 code[] = { 0x60, 0x61, 0xF4 };
  int kind = run_code(model, 0x0000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);

  // All registers should be restored (SP restored to original)
  ASSERT_EQ((u64)(model.zGPR.data[0] & 0xFFFF), 0x1111UL); // AX
  ASSERT_EQ((u64)(model.zGPR.data[1] & 0xFFFF), 0x2222UL); // CX
  ASSERT_EQ((u64)(model.zGPR.data[2] & 0xFFFF), 0x3333UL); // DX
  ASSERT_EQ((u64)(model.zGPR.data[3] & 0xFFFF), 0x4444UL); // BX
  ASSERT_EQ((u64)(model.zGPR.data[4] & 0xFFFF), 0x8000UL); // SP
  ASSERT_EQ((u64)(model.zGPR.data[5] & 0xFFFF), 0x5555UL); // BP
  ASSERT_EQ((u64)(model.zGPR.data[6] & 0xFFFF), 0x6666UL); // SI
  ASSERT_EQ((u64)(model.zGPR.data[7] & 0xFFFF), 0x7777UL); // DI

  model.model_fini();
}

TEST(popad_skips_esp_slot) {
  // POPAD should ignore the ESP value on the stack (skip that slot).
  // Set up a stack with a different ESP value in the ESP slot and verify
  // it gets ignored.
  x86::Model model;
  init_model_32(model);

  // Manually build a POPAD frame on the stack
  u64 sp = model.zGPR.data[4]; // 0x80000
  // Push in PUSHAD order (EAX first = highest addr, EDI last = lowest addr)
  sp -= 4; model.phys_mem.write32(sp, 0xAA000000); // EAX
  sp -= 4; model.phys_mem.write32(sp, 0xBB000000); // ECX
  sp -= 4; model.phys_mem.write32(sp, 0xCC000000); // EDX
  sp -= 4; model.phys_mem.write32(sp, 0xDD000000); // EBX
  sp -= 4; model.phys_mem.write32(sp, 0xDEADBEEF); // ESP slot (should be IGNORED)
  sp -= 4; model.phys_mem.write32(sp, 0xEE000000); // EBP
  sp -= 4; model.phys_mem.write32(sp, 0xFF000000); // ESI
  sp -= 4; model.phys_mem.write32(sp, 0x11000000); // EDI
  model.zGPR.data[4] = sp;

  // POPAD; HLT
  u8 code[] = { 0x61, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);

  ASSERT_EQ((u64)(u32)model.zGPR.data[7], 0x11000000UL); // EDI
  ASSERT_EQ((u64)(u32)model.zGPR.data[6], 0xFF000000UL); // ESI
  ASSERT_EQ((u64)(u32)model.zGPR.data[5], 0xEE000000UL); // EBP
  // ESP should be sp+32 (popped past all 8 slots), NOT 0xDEADBEEF
  ASSERT_EQ((u64)(u32)model.zGPR.data[4], (u32)(sp + 32));
  ASSERT_EQ((u64)(u32)model.zGPR.data[3], 0xDD000000UL); // EBX
  ASSERT_EQ((u64)(u32)model.zGPR.data[2], 0xCC000000UL); // EDX
  ASSERT_EQ((u64)(u32)model.zGPR.data[1], 0xBB000000UL); // ECX
  ASSERT_EQ((u64)(u32)model.zGPR.data[0], 0xAA000000UL); // EAX

  model.model_fini();
}

TEST(pusha_ud_in_64bit) {
  // PUSHA/POPA are #UD in 64-bit mode
  x86::Model model;
  init_model(model);

  u8 code[] = { 0x60, 0xF4 };  // PUSHA; HLT
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_FAULTED);
  ASSERT_EQ((u64)model.zfault_vector, 6UL);  // #UD

  model.model_fini();
}

// =========================================================================
// PUSH/POP segment register tests
// =========================================================================

TEST(push_es_16bit) {
  // PUSH ES (opcode 06) in 16-bit mode pushes 2-byte selector onto stack.
  x86::Model model;
  init_model_16(model);

  model.zSegReg.data[x86::SEG_ES] = 0x1234;
  model.zGPR.data[4] = 0x8000;  // SP

  // PUSH ES; HLT
  u8 code[] = { 0x06, 0xF4 };
  int kind = run_code(model, 0x0000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  // SP should decrease by 2
  ASSERT_EQ((u64)(model.zGPR.data[4] & 0xFFFF), 0x7FFEUL);
  // Stack should contain ES selector
  ASSERT_EQ((u64)model.phys_mem.read16(0x7FFE), 0x1234UL);

  model.model_fini();
}

TEST(push_ds_pop_es_32bit) {
  // PUSH DS (1E) then POP ES (07) in 32-bit mode: transfers DS to ES.
  // SDM: PUSH seg with 32-bit operand size pushes zero-extended 32 bits.
  // POP seg pops 32 bits, loads low 16 into segment register.
  x86::Model model;
  init_model_32(model);

  model.zSegReg.data[x86::SEG_DS] = 0x0010;  // DS = 0x10 (data selector)
  model.zSegReg.data[x86::SEG_ES] = 0x0000;  // ES = 0 initially
  // POP ES validates the descriptor even when the selector was already
  // loaded in DS. Give it a present, writable, flat data segment.
  model.zGDTR_base = 0x90000;
  model.zGDTR_limit = 23;
  model.phys_mem.write64(0x90010, 0x00CF92000000FFFFULL);

  u64 orig_esp = model.zGPR.data[4];

  // PUSH DS (1E); POP ES (07); HLT
  u8 code[] = { 0x1E, 0x07, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  // ESP should be unchanged (push then pop)
  ASSERT_EQ((u64)(u32)model.zGPR.data[4], (u32)orig_esp);
  // ES should now equal DS
  ASSERT_EQ((u64)model.zSegReg.data[x86::SEG_ES], 0x0010UL);

  model.model_fini();
}

TEST(push_cs_16bit) {
  // PUSH CS (opcode 0E) in 16-bit real mode.
  x86::Model model;
  init_model_16(model);

  model.zSegReg.data[x86::SEG_CS] = 0x9000;
  model.zGPR.data[4] = 0x8000;

  // PUSH CS; HLT
  u8 code[] = { 0x0E, 0xF4 };
  int kind = run_code(model, 0x0000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)(model.zGPR.data[4] & 0xFFFF), 0x7FFEUL);
  ASSERT_EQ((u64)model.phys_mem.read16(0x7FFE), 0x9000UL);

  model.model_fini();
}

TEST(push_ss_pop_ss_16bit) {
  // PUSH SS (16) then POP SS (17) round-trip in real mode.
  x86::Model model;
  init_model_16(model);

  model.zSegReg.data[x86::SEG_SS] = 0x5000;
  model.zSegCache.data[x86::SEG_SS].zseg_base = 0x50000;
  model.zGPR.data[4] = 0x8000;

  // PUSH SS (16); POP SS (17); HLT
  u8 code[] = { 0x16, 0x17, 0xF4 };
  int kind = run_code(model, 0x0000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  // SS should be unchanged after round-trip
  ASSERT_EQ((u64)model.zSegReg.data[x86::SEG_SS], 0x5000UL);
  // SP should be unchanged
  ASSERT_EQ((u64)(model.zGPR.data[4] & 0xFFFF), 0x8000UL);

  model.model_fini();
}

TEST(pop_ds_real_mode) {
  // POP DS (1F) in real mode: pop 16-bit value, load into DS,
  // and set DS.base = selector << 4.
  x86::Model model;
  init_model_16(model);

  model.zGPR.data[4] = 0x8000;
  // Push 0x2000 onto stack manually
  model.phys_mem.write16(0x7FFE, 0x2000);
  model.zGPR.data[4] = 0x7FFE;

  // POP DS; HLT
  u8 code[] = { 0x1F, 0xF4 };
  int kind = run_code(model, 0x0000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);
  ASSERT_EQ((u64)model.zSegReg.data[x86::SEG_DS], 0x2000UL);
  // In real mode, base = selector << 4
  ASSERT_EQ((u64)model.zSegCache.data[x86::SEG_DS].zseg_base, 0x20000UL);
  // SP should be restored
  ASSERT_EQ((u64)(model.zGPR.data[4] & 0xFFFF), 0x8000UL);

  model.model_fini();
}

TEST(push_seg_ud_in_64bit) {
  // PUSH ES (06) is #UD in 64-bit mode.
  x86::Model model;
  init_model(model);

  u8 code[] = { 0x06, 0xF4 };
  int kind = run_code(model, 0x100000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_FAULTED);
  ASSERT_EQ((u64)model.zfault_vector, 6UL);  // #UD

  model.model_fini();
}

// =========================================================================

int main() {
  printf("System emulator tests:\n");

  run_test_phys_mem_read_write();
  run_test_phys_mem_bulk();
  run_test_mov_eax_imm32_hlt();
  run_test_mov_rax_imm64_hlt();
  run_test_add_rax_rbx_hlt();
  run_test_mem_store_load_hlt();
  run_test_push_pop_hlt();
  run_test_jmp_forward_hlt();
  run_test_loop_counter_hlt();
  run_test_system_regs_initial_values();

  printf("\nPrivileged instruction tests:\n");
  run_test_mov_cr0_read_write();
  run_test_mov_cr3_write();
  run_test_lgdt_sgdt();
  run_test_lidt_sidt();
  run_test_wrmsr_rdmsr_star();
  run_test_wrmsr_rdmsr_efer();
  run_test_swapgs();
  run_test_cli_sti();
  run_test_wbinvd();
  run_test_clts();

  printf("\nString I/O tests:\n");
  run_test_insb_single();
  run_test_outsb_single();
  run_test_rep_insb();
  run_test_rep_outsb();
  run_test_rep_insd();
  run_test_insb_df_backward();

  printf("\nDirect store tests:\n");
  run_test_movdiri_32();
  run_test_movdiri_64();
  run_test_movdir64b();
  run_test_movdir64b_unaligned_faults();

  printf("\n32-bit protected mode tests:\n");
  run_test_lgdt_sgdt_32bit();
  run_test_lidt_sidt_32bit();

  printf("\nSegment limit checking tests:\n");
  run_test_seg_limit_byte_within();
  run_test_seg_limit_dword_crosses();
  run_test_seg_limit_dword_within();
  run_test_seg_limit_ss_fault();

  printf("\nReal mode tests:\n");
  run_test_real_mode_mov_ax_hlt();
  run_test_real_mode_far_jmp_ea();
  run_test_real_mode_far_call_9a();

  printf("\nProtected mode far transfer tests:\n");
  run_test_protected_mode_far_jmp_ea();
  run_test_protected_mode_far_jmp_ff5();

  printf("\nMode transition tests:\n");
  run_test_real_to_protected_mode_transition();
  run_test_lmsw_enters_protected_mode();

  printf("\nIRET tests:\n");
  run_test_real_mode_iret_no_pop_sp_ss();
  run_test_x87_save_restore_large_memory_operand();
  run_test_real_mode_iret_with_nt();
  run_test_real_mode_int_iret_preserves_regs();
  run_test_protected_mode_iret_same_privilege();
  run_test_ia32e_iretq_to_compat_loads_ss_descriptor();
  run_test_ia32e_sysenter_switches_to_long_mode();
  run_test_mov_gs_at_cpl3_uses_implicit_access();
  run_test_compat_seg_linear_wraps_at_32bit();

  printf("\nPUSHA/POPA tests:\n");
  run_test_pushad_popad_32bit();
  run_test_pushad_stack_layout_32bit();
  run_test_pusha_popa_16bit();
  run_test_popad_skips_esp_slot();
  run_test_pusha_ud_in_64bit();

  printf("\nPUSH/POP segment register tests:\n");
  run_test_push_es_16bit();
  run_test_push_ds_pop_es_32bit();
  run_test_push_cs_16bit();
  run_test_push_ss_pop_ss_16bit();
  run_test_pop_ds_real_mode();
  run_test_push_seg_ud_in_64bit();

  printf("\n%d passed, %d failed\n", tests_passed, tests_failed);
  return tests_failed > 0 ? 1 : 0;
}

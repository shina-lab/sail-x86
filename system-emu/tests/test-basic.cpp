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
  // Each dword should be 0xFFFFFFFF
  ASSERT_EQ(model.phys_mem.read32(0x200008), 0xFFFFFFFFUL);
  ASSERT_EQ(model.phys_mem.read32(0x200004), 0xFFFFFFFFUL);
  ASSERT_EQ(model.phys_mem.read32(0x200000), 0xFFFFFFFFUL);
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

  printf("\n%d passed, %d failed\n", tests_passed, tests_failed);
  return tests_failed > 0 ? 1 : 0;
}

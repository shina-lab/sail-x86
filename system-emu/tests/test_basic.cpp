// Basic tests for system-level emulator.
// Tests that the emulator can execute simple instructions with
// physical memory backed by the PhysicalMemory manager.

#include "sail_x86_model.h"
#include <cassert>
#include <cstdio>
#include <cstring>

static void init_model(x86::Model &model, u64 ram_size = 4 * 1024 * 1024) {
  model.model_init();
  model.zinitializze_registers(UNIT);

  model.zsystem_mode = true;
  model.zcur_mode = x86::zLongMode;
  model.zcur_cpl = 0;

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
  model.zFS_BASE = 0;
  model.zGS_BASE = 0;
  model.zKERNEL_GS_BASE = 0;
}

// Run code loaded at code_addr until HLT or fault.
// Returns the ExecutionResult kind.
static int run_code(x86::Model &model, u64 code_addr, const u8 *code, size_t len,
                    u64 max_insns = 1000) {
  model.phys_mem.write_bytes(code_addr, code, len);
  model.zRIP = code_addr;

  x86::zExecutionResult result = {};
  result.kind = x86::Kind_zOk;

  u64 count = 0;
  while (count < max_insns) {
    model.zstep(&result, UNIT);
    if (result.kind != x86::Kind_zOk)
      break;
    count++;
  }
  return result.kind;
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
  ASSERT_EQ(kind, x86::Kind_zHalt);
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
  ASSERT_EQ(kind, x86::Kind_zHalt);
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
  ASSERT_EQ(kind, x86::Kind_zHalt);
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
  ASSERT_EQ(kind, x86::Kind_zHalt);
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
  ASSERT_EQ(kind, x86::Kind_zHalt);
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
  ASSERT_EQ(kind, x86::Kind_zHalt);
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
  ASSERT_EQ(kind, x86::Kind_zHalt);
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

  printf("\n%d passed, %d failed\n", tests_passed, tests_failed);
  return tests_failed > 0 ? 1 : 0;
}

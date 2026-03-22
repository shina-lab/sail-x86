// Tests for A20 gate emulation.
//
// The A20 gate controls whether physical address bit 20 is masked to zero.
// When disabled (reset default), addresses wrap at 1MB: physical 0x100000
// aliases to 0x000000.  When enabled, the full address space is accessible.

#include "sail_x86_model.h"
#include "x86-helpers.h"
#include <cassert>
#include <cstdio>
#include <cstring>

// Initialize model in real mode with paging off (linear = physical).
static void init_model_real(x86::Model &model, u64 ram_size = 4 * 1024 * 1024) {
  model.model_init();
  model.zinitializze_registers(UNIT);
  enable_all_features(model);

  model.zsystem_mode = true;
  model.zcur_mode = x86::zRealMode;
  model.zcur_cpl = 0;

  // CR0: no PE, no PG (real mode). ET + NE set.
  model.zCR0 = (1UL << 4) | (1UL << 5);
  model.zCR4 = 0;
  model.zEFER = 0;

  assert(model.phys_mem.init(ram_size));

  for (int i = 0; i < 16; i++)
    model.zGPR.data[i] = 0;
  model.zGPR.data[4] = 0x8000; // SP

  // Real mode segments: base = sel << 4, limit = 0xFFFF
  for (int i = 0; i < 6; i++) {
    model.zSegReg.data[i] = 0;
    model.zSegCache.data[i].zseg_base = 0;
    model.zSegCache.data[i].zseg_limit = 0xFFFF;
    model.zSegCache.data[i].zseg_present = 1;
    model.zSegCache.data[i].zseg_s = 1;
    model.zSegCache.data[i].zseg_type = 0x3;
    model.zSegCache.data[i].zseg_dpl = 0;
    model.zSegCache.data[i].zseg_db = 0;
    model.zSegCache.data[i].zseg_l = 0;
    model.zSegCache.data[i].zseg_g = 0;
  }
  model.zSegCache.data[x86::SEG_CS].zseg_type = 0xB;

  model.zGDTR_base = 0;
  model.zGDTR_limit = 0;
  model.zIDTR_base = 0;
  model.zIDTR_limit = 0x3FF;
  model.zKERNEL_GS_BASE = 0;

  // A20 disabled on reset
  model.za20_enabled = false;
  model.kbd.a20_gate = &model.za20_enabled;
}

// Initialize model in long mode with identity-mapped paging.
static void init_model_long(x86::Model &model, u64 ram_size = 4 * 1024 * 1024) {
  model.model_init();
  model.zinitializze_registers(UNIT);
  enable_all_features(model);

  model.zsystem_mode = true;
  model.zcur_mode = x86::zLongMode;
  model.zcur_cpl = 0;
  model.zSegCache.data[x86::SEG_CS].zseg_l = 1;

  model.zCR0 = (1UL << 0) | (1UL << 4) | (1UL << 5) | (1UL << 16) | (1UL << 31);
  model.zCR4 = (1UL << 5) | (1UL << 9);
  model.zEFER = (1UL << 0) | (1UL << 8) | (1UL << 10) | (1UL << 11);

  assert(model.phys_mem.init(ram_size));

  // Identity-mapped 2MB pages
  model.phys_mem.write64(0x1000, 0x2000 | 0x03);
  model.phys_mem.write64(0x2000, 0x3000 | 0x03);
  for (u64 j = 0; j < 512 && (j << 21) < ram_size; j++)
    model.phys_mem.write64(0x3000 + j * 8, (j << 21) | 0x83);
  model.zCR3 = 0x1000;

  for (int i = 0; i < 16; i++)
    model.zGPR.data[i] = 0;
  model.zGPR.data[4] = 0x80000;

  model.zGDTR_base = 0;
  model.zGDTR_limit = 0;
  model.zIDTR_base = 0;
  model.zIDTR_limit = 0;
  model.zKERNEL_GS_BASE = 0;

  // A20 enabled (typical for long mode)
  model.za20_enabled = true;
  model.kbd.a20_gate = &model.za20_enabled;
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
// Direct physical memory tests (no code execution)
// =========================================================================

TEST(a20_disabled_aliases_1mb) {
  // With A20 disabled, writing to physical 0x100000 should be visible
  // at physical 0x000000 (bit 20 masked).
  x86::Model model;
  init_model_real(model);

  // Write a known pattern at physical 0x100000 via the raw backing store
  // (bypass Sail, which would mask the address).
  model.phys_mem.write32(0x100000, 0xDEADBEEF);
  model.phys_mem.write32(0x000000, 0x00000000);

  // Now read via the Sail phys_read path (which applies A20 masking).
  // With A20 disabled, reading 0x100000 should get the value at 0x000000.
  // The Sail model's phys_read masks bit 20, so addr 0x100000 → 0x000000.
  // Physical 0x000000 was set to 0x00000000.
  //
  // Conversely, writing 0x100000 through Sail lands at 0x000000.

  // Use Sail's __write_mem to write 0xCAFEBABE at address 0x100000.
  // With A20 disabled, this should actually write to 0x000000.
  model.phys_mem.write32(0x000000, 0x11111111); // sentinel
  model.phys_mem.write32(0x100000, 0x22222222); // sentinel

  // Execute: mov dword [0], 0; mov eax, 0x100000 as addr...
  // Actually, let's just test through direct Sail model calls.
  // phys_read/phys_write go through a20_mask in the Sail model,
  // but those are Sail functions. In the C++ emulator, __read_mem/__write_mem
  // are the raw calls that do NOT apply A20 — A20 is applied in the Sail
  // phys_read/phys_write wrappers.
  //
  // For a C++ unit test, we can run real-mode code instead.

  // Real-mode code at CS:IP = 0x0000:0x7C00 (linear 0x7C00).
  // Use "unreal mode" segment trick: DS = 0xFFFF, offset = 0x0010
  // gives linear address 0xFFFF * 16 + 0x0010 = 0xFFFF0 + 0x10 = 0x100000.
  // With A20 disabled, this wraps to 0x000000.
  //
  // Code:
  //   mov ax, 0xFFFF
  //   mov ds, ax         ; DS.base = 0xFFFF0
  //   mov word [0x10], 0xBEEF  ; DS:0x10 = linear 0x100000 → phys 0x000000
  //   mov ax, 0
  //   mov ds, ax         ; DS.base = 0
  //   mov ax, [0]        ; read from linear 0x000000
  //   hlt
  u8 code[] = {
    0xB8, 0xFF, 0xFF,             // mov ax, 0xFFFF
    0x8E, 0xD8,                   // mov ds, ax
    0xC7, 0x06, 0x10, 0x00,       // mov word [0x10], 0xBEEF
      0xEF, 0xBE,
    0xB8, 0x00, 0x00,             // mov ax, 0
    0x8E, 0xD8,                   // mov ds, ax
    0xA1, 0x00, 0x00,             // mov ax, [0x0000]
    0xF4,                         // hlt
  };

  // Clear target addresses
  model.phys_mem.write16(0x000000, 0x0000);
  model.phys_mem.write16(0x100000, 0x0000);

  // Set CS:IP to 0x0000:0x7C00
  model.zSegReg.data[x86::SEG_CS] = 0x0000;
  model.zSegCache.data[x86::SEG_CS].zseg_base = 0;

  int kind = run_code(model, 0x7C00, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);

  // AX should contain 0xBEEF: the write to linear 0x100000 wrapped to 0x000000,
  // so reading linear 0x000000 returns the written value.
  ASSERT_EQ((u64)model.zGPR.data[0] & 0xFFFF, 0xBEEFUL);

  // Physical memory at 0x000000 should have been modified
  ASSERT_EQ((u64)model.phys_mem.read16(0x000000), 0xBEEFUL);
  // Physical memory at 0x100000 should be untouched (A20 masked the write)
  ASSERT_EQ((u64)model.phys_mem.read16(0x100000), 0x0000UL);

  model.model_fini();
}

TEST(a20_enabled_no_wrap) {
  // With A20 enabled, writing to 0x100000 should NOT alias to 0x000000.
  x86::Model model;
  init_model_real(model);

  // Enable A20
  model.za20_enabled = true;

  // Same code as above: DS=0xFFFF, write to [0x10] → linear 0x100000
  u8 code[] = {
    0xB8, 0xFF, 0xFF,             // mov ax, 0xFFFF
    0x8E, 0xD8,                   // mov ds, ax
    0xC7, 0x06, 0x10, 0x00,       // mov word [0x10], 0xBEEF
      0xEF, 0xBE,
    0xB8, 0x00, 0x00,             // mov ax, 0
    0x8E, 0xD8,                   // mov ds, ax
    0xA1, 0x00, 0x00,             // mov ax, [0x0000]
    0xF4,                         // hlt
  };

  model.phys_mem.write16(0x000000, 0x0000);
  model.phys_mem.write16(0x100000, 0x0000);

  model.zSegReg.data[x86::SEG_CS] = 0x0000;
  model.zSegCache.data[x86::SEG_CS].zseg_base = 0;

  int kind = run_code(model, 0x7C00, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);

  // AX should be 0x0000: the write went to real 0x100000, not 0x000000
  ASSERT_EQ((u64)model.zGPR.data[0] & 0xFFFF, 0x0000UL);

  // Physical 0x100000 should have the value
  ASSERT_EQ((u64)model.phys_mem.read16(0x100000), 0xBEEFUL);
  // Physical 0x000000 should be untouched
  ASSERT_EQ((u64)model.phys_mem.read16(0x000000), 0x0000UL);

  model.model_fini();
}

TEST(a20_port92_enable) {
  // Enable A20 via port 0x92 (fast A20 gate).
  x86::Model model;
  init_model_real(model);

  // Verify A20 starts disabled
  ASSERT_EQ((u64)model.za20_enabled, 0UL);

  // Real-mode code:
  //   in al, 0x92       ; read System Control Port A
  //   or al, 0x02       ; set A20 bit
  //   out 0x92, al      ; write back
  //   ; now write via FFFF:0010 (linear 0x100000) — should NOT wrap
  //   mov ax, 0xFFFF
  //   mov ds, ax
  //   mov word [0x10], 0xCAFE
  //   mov ax, 0
  //   mov ds, ax
  //   mov ax, [0]       ; read linear 0x000000 — should be 0
  //   hlt
  u8 code[] = {
    0xE4, 0x92,                   // in al, 0x92
    0x0C, 0x02,                   // or al, 0x02
    0xE6, 0x92,                   // out 0x92, al
    0xB8, 0xFF, 0xFF,             // mov ax, 0xFFFF
    0x8E, 0xD8,                   // mov ds, ax
    0xC7, 0x06, 0x10, 0x00,       // mov word [0x10], 0xCAFE
      0xFE, 0xCA,
    0xB8, 0x00, 0x00,             // mov ax, 0
    0x8E, 0xD8,                   // mov ds, ax
    0xA1, 0x00, 0x00,             // mov ax, [0x0000]
    0xF4,                         // hlt
  };

  model.phys_mem.write16(0x000000, 0x0000);
  model.phys_mem.write16(0x100000, 0x0000);

  model.zSegReg.data[x86::SEG_CS] = 0x0000;
  model.zSegCache.data[x86::SEG_CS].zseg_base = 0;

  int kind = run_code(model, 0x7C00, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);

  // A20 should now be enabled
  ASSERT_EQ((u64)model.za20_enabled, 1UL);

  // Write went to real 0x100000, not wrapped to 0x000000
  ASSERT_EQ((u64)model.zGPR.data[0] & 0xFFFF, 0x0000UL);
  ASSERT_EQ((u64)model.phys_mem.read16(0x100000), 0xCAFEUL);
  ASSERT_EQ((u64)model.phys_mem.read16(0x000000), 0x0000UL);

  model.model_fini();
}

TEST(a20_port92_disable) {
  // Disable A20 via port 0x92 after it was enabled.
  x86::Model model;
  init_model_real(model);

  // Start with A20 enabled
  model.za20_enabled = true;

  // Real-mode code:
  //   in al, 0x92
  //   and al, 0xFD      ; clear A20 bit
  //   out 0x92, al
  //   ; write via FFFF:0010 → should wrap to 0x000000
  //   mov ax, 0xFFFF
  //   mov ds, ax
  //   mov word [0x10], 0x1234
  //   mov ax, 0
  //   mov ds, ax
  //   mov ax, [0]
  //   hlt
  u8 code[] = {
    0xE4, 0x92,                   // in al, 0x92
    0x24, 0xFD,                   // and al, 0xFD
    0xE6, 0x92,                   // out 0x92, al
    0xB8, 0xFF, 0xFF,             // mov ax, 0xFFFF
    0x8E, 0xD8,                   // mov ds, ax
    0xC7, 0x06, 0x10, 0x00,       // mov word [0x10], 0x1234
      0x34, 0x12,
    0xB8, 0x00, 0x00,             // mov ax, 0
    0x8E, 0xD8,                   // mov ds, ax
    0xA1, 0x00, 0x00,             // mov ax, [0x0000]
    0xF4,                         // hlt
  };

  model.phys_mem.write16(0x000000, 0x0000);
  model.phys_mem.write16(0x100000, 0x0000);

  model.zSegReg.data[x86::SEG_CS] = 0x0000;
  model.zSegCache.data[x86::SEG_CS].zseg_base = 0;

  int kind = run_code(model, 0x7C00, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);

  ASSERT_EQ((u64)model.za20_enabled, 0UL);
  // Write wrapped to 0x000000
  ASSERT_EQ((u64)model.zGPR.data[0] & 0xFFFF, 0x1234UL);
  ASSERT_EQ((u64)model.phys_mem.read16(0x000000), 0x1234UL);

  model.model_fini();
}

TEST(a20_kbd_controller_enable) {
  // Enable A20 via keyboard controller (cmd 0xD1 to port 0x64,
  // then data 0xDF to port 0x60 — bit 1 = A20).
  x86::Model model;
  init_model_real(model);

  ASSERT_EQ((u64)model.za20_enabled, 0UL);

  // Real-mode code:
  //   mov al, 0xD1      ; "write output port" command
  //   out 0x64, al
  //   mov al, 0xDF      ; bit 1 set = A20 enabled (0xDF = all bits set except bit 5)
  //   out 0x60, al
  //   ; write to FFFF:0010 (linear 0x100000) — should NOT wrap
  //   mov ax, 0xFFFF
  //   mov ds, ax
  //   mov word [0x10], 0xABCD
  //   mov ax, 0
  //   mov ds, ax
  //   mov ax, [0]
  //   hlt
  u8 code[] = {
    0xB0, 0xD1,                   // mov al, 0xD1
    0xE6, 0x64,                   // out 0x64, al
    0xB0, 0xDF,                   // mov al, 0xDF
    0xE6, 0x60,                   // out 0x60, al
    0xB8, 0xFF, 0xFF,             // mov ax, 0xFFFF
    0x8E, 0xD8,                   // mov ds, ax
    0xC7, 0x06, 0x10, 0x00,       // mov word [0x10], 0xABCD
      0xCD, 0xAB,
    0xB8, 0x00, 0x00,             // mov ax, 0
    0x8E, 0xD8,                   // mov ds, ax
    0xA1, 0x00, 0x00,             // mov ax, [0x0000]
    0xF4,                         // hlt
  };

  model.phys_mem.write16(0x000000, 0x0000);
  model.phys_mem.write16(0x100000, 0x0000);

  model.zSegReg.data[x86::SEG_CS] = 0x0000;
  model.zSegCache.data[x86::SEG_CS].zseg_base = 0;

  int kind = run_code(model, 0x7C00, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);

  ASSERT_EQ((u64)model.za20_enabled, 1UL);
  // Write went to real 0x100000
  ASSERT_EQ((u64)model.zGPR.data[0] & 0xFFFF, 0x0000UL);
  ASSERT_EQ((u64)model.phys_mem.read16(0x100000), 0xABCDUL);
  ASSERT_EQ((u64)model.phys_mem.read16(0x000000), 0x0000UL);

  model.model_fini();
}

TEST(a20_affects_paging) {
  // A20 masking applies to physical addresses after paging translation.
  // With paging enabled and A20 disabled, a page table that maps
  // virtual 0x200000 to physical 0x100000 should actually access 0x000000.
  x86::Model model;
  init_model_long(model);

  // Disable A20
  model.za20_enabled = false;

  // Write known values at physical 0x000000 and 0x100000
  model.phys_mem.write64(0x000000, 0xAAAAAAAAAAAAAAAAULL);
  model.phys_mem.write64(0x100000, 0xBBBBBBBBBBBBBBBBULL);

  // Code reads from virtual 0x100000 (identity-mapped to physical 0x100000).
  // With A20 disabled, the physical address 0x100000 gets masked to 0x000000.
  // Note: the code itself lives at 0x200000, whose physical address 0x200000
  // has bit 20 = 0, so it's unaffected by A20 masking.
  model.zGPR.data[7] = 0x100000; // RDI

  // But wait — code fetch from 0x200000 also goes through phys_read which
  // applies A20. 0x200000 has bit 20 = 0, so it's fine.
  // However, our identity-mapped page table entries and PML4/PDPT/PD at
  // 0x1000/0x2000/0x3000 all have bit 20 = 0, so they're also fine.
  // The TLB may cache translations, so flush it.
  model.z__tlb_flush(UNIT);

  u8 code[] = {
    0x48, 0x8B, 0x07,   // mov rax, [rdi]  ; read from virtual 0x100000
    0xF4,               // hlt
  };

  int kind = run_code(model, 0x200000, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);

  // Should read from physical 0x000000 (bit 20 masked), not 0x100000
  ASSERT_EQ((u64)model.zGPR.data[0], 0xAAAAAAAAAAAAAAAAULL);

  model.model_fini();
}

TEST(a20_bit20_only) {
  // A20 masking should only affect bit 20, not other address bits.
  // Writing to physical 0x200000 (bit 21 set, bit 20 clear) should
  // NOT be affected by A20 gating.
  x86::Model model;
  init_model_real(model);

  // A20 disabled
  ASSERT_EQ((u64)model.za20_enabled, 0UL);

  // Use "unreal mode" to access higher addresses.
  // Set DS to a segment with a large limit (cheat by setting cache directly).
  model.zSegReg.data[x86::SEG_DS] = 0;
  model.zSegCache.data[x86::SEG_DS].zseg_base = 0;
  model.zSegCache.data[x86::SEG_DS].zseg_limit = 0xFFFFFFFF;
  model.zSegCache.data[x86::SEG_DS].zseg_db = 1;
  model.zSegCache.data[x86::SEG_DS].zseg_g = 1;

  // Write 0xDEAD at physical 0x200000 directly
  model.phys_mem.write16(0x200000, 0x0000);

  // 32-bit address-size override (67h) in real mode to use 32-bit addressing.
  // mov word [0x200000], 0xDEAD  (with 67h prefix for 32-bit addr)
  // mov ax, [0x200000]
  // hlt
  u8 code[] = {
    0x67, 0xC7, 0x05,                         // mov word [disp32], imm16
      0x00, 0x00, 0x20, 0x00,                 // disp32 = 0x200000
      0xAD, 0xDE,                             // imm16 = 0xDEAD
    0x67, 0xA1, 0x00, 0x00, 0x20, 0x00,       // mov ax, [0x200000]
    0xF4,                                      // hlt
  };

  model.zSegReg.data[x86::SEG_CS] = 0x0000;
  model.zSegCache.data[x86::SEG_CS].zseg_base = 0;

  int kind = run_code(model, 0x7C00, code, sizeof(code));
  ASSERT_EQ(kind, RUN_HALTED);

  // 0x200000 has bit 20 = 0, so A20 masking does not affect it.
  // The value should be written and read back correctly.
  ASSERT_EQ((u64)model.zGPR.data[0] & 0xFFFF, 0xDEADUL);
  ASSERT_EQ((u64)model.phys_mem.read16(0x200000), 0xDEADUL);

  model.model_fini();
}

// =========================================================================

int main() {
  printf("A20 gate tests:\n");

  run_test_a20_disabled_aliases_1mb();
  run_test_a20_enabled_no_wrap();
  run_test_a20_port92_enable();
  run_test_a20_port92_disable();
  run_test_a20_kbd_controller_enable();
  run_test_a20_affects_paging();
  run_test_a20_bit20_only();

  printf("\n%d passed, %d failed\n", tests_passed, tests_failed);
  return tests_failed > 0 ? 1 : 0;
}

// System Management Mode tests.  An SMI (here a write to the APM control
// port 0B2H) saves the processor state in the SMRAM state save map, whose
// fields lie at SMBASE + 8000H + offset (SDM Vol.3C §34.4.1 and Table 34-3;
// §34.3.1: "from [SMBASE + FE00H] to [SMBASE + FFFFH]"), and starts the SMI
// handler at SMBASE + 8000H; RSM restores the saved state.  A new value
// written to the SMBASE field (offset 7EF8H) by the handler relocates both
// the handler and the state save area (§34.11).

#include "sail_x86_model.h"
#include "x86-helpers.h"
#include <cassert>
#include <cstdio>
#include <cstring>

static const u64 SMBASE_DEFAULT = 0x30000;  // the reset value
static const u64 CODE_ADDR = 0x10000;       // CS 1000H, offset 0

// Real mode with 4 MiB of RAM.  The SMI handler runs in SMM's real-address
// environment, and RSM's return to real mode reloads the segment bases from
// the saved selectors.
static void init_model(x86::Model &model) {
  model.model_init();
  model.zinitializze_registers(UNIT);
  enable_all_features(model);

  model.zsystem_mode = true;
  model.za20_enabled = true;
  model.zcur_mode = x86::zRealMode;
  model.zcur_cpl = 0;
  model.zCR0 = (1UL << 4);  // ET
  model.zCR4 = 0;
  model.zEFER = 0;
  assert(model.phys_mem.init(4 * 1024 * 1024));

  for (int i = 0; i < 16; i++)
    model.zGPR.data[i] = 0;
  model.zGPR.data[4] = 0x8000;  // SP

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
  model.zSegReg.data[x86::SEG_CS] = CODE_ADDR >> 4;
  model.zSegCache.data[x86::SEG_CS].zseg_base = CODE_ADDR;
  model.zSegCache.data[x86::SEG_CS].zseg_type = 0xB;

  model.zGDTR_base = 0;
  model.zGDTR_limit = 0;
  model.zIDTR_base = 0;
  model.zIDTR_limit = 0x3FF;
  model.zsmbase = SMBASE_DEFAULT;

  // This platform gates APMC SMIs through both PIIX4 enables. Firmware
  // normally programs these before using port B2; the test has no BIOS.
  model.z__port_out32(0xCF8, 0x80000B58);
  model.z__port_out32(0xCFC, 0x02000000);  // DEVACTB.APMC_EN
  model.z__port_out8(model.pci.pm_base() + 0x28, 1);  // GLBCTL.SMI_EN
}

enum RunResult { RUN_OK = 0, RUN_HALTED = 1, RUN_FAULTED = 2 };

// Run code at CS:0 until HLT or a fault.
static int run_code(x86::Model &model, const u8 *code, size_t len, u64 max_insns = 100) {
  model.phys_mem.write_bytes(CODE_ADDR, code, len);
  model.zRIP = 0;
  for (u64 count = 0; count < max_insns; count++) {
    model.zstep(UNIT);
    if (model.zfault_pending) return RUN_FAULTED;
    if (model.zsystem_state == x86::zSysHalted) return RUN_HALTED;
  }
  return RUN_OK;
}

static int tests_passed = 0;
static int tests_failed = 0;

#define TEST(name) \
  static void test_##name(); \
  static void run_test_##name() { \
    printf("  %-50s", #name); \
    fflush(stdout); \
    test_##name(); \
    printf("PASS\n"); \
    tests_passed++; \
  } \
  static void test_##name()

#define ASSERT_EQ(a, b) do { \
  auto _a = (a); auto _b = (b); \
  if (_a != _b) { \
    printf("FAIL\n    %s:%d: %s == 0x%lx, expected 0x%lx\n", \
           __FILE__, __LINE__, #a, (unsigned long)_a, (unsigned long)_b); \
    tests_failed++; \
    return; \
  } \
} while(0)

// =========================================================================
// Tests
// =========================================================================

TEST(smi_saves_state_at_smbase_plus_8000h) {
  x86::Model model;
  init_model(model);

  // SMI handler at SMBASE + 8000H: RSM
  static const u8 handler[] = { 0x0F, 0xAA };
  model.phys_mem.write_bytes(SMBASE_DEFAULT + 0x8000, handler, sizeof(handler));

  static const u8 code[] = {
    0xB8, 0x34, 0x12,   // mov ax, 1234h
    0xE6, 0xB2,         // out 0B2h, al      (SMI before the next instruction)
    0xBB, 0x78, 0x56,   // mov bx, 5678h
    0xF4,               // hlt
  };
  ASSERT_EQ(run_code(model, code, sizeof(code)), RUN_HALTED);

  // The program resumed after the handler's RSM and ran to the HLT.
  ASSERT_EQ((u64)model.zGPR.data[0], 0x1234UL);
  ASSERT_EQ((u64)model.zGPR.data[3], 0x5678UL);
  ASSERT_EQ((u64)model.zin_smm, 0UL);
  ASSERT_EQ((u64)model.zsmbase, SMBASE_DEFAULT);

  // The state save map lies at SMBASE + 8000H + offset (Table 34-3): the
  // RIP of the instruction after OUT, RAX, CS, the SMM revision identifier
  // (Intel 64 format) and the SMBASE field.
  const u64 state = SMBASE_DEFAULT + 0x8000;
  ASSERT_EQ(model.phys_mem.read64(state + 0x7FD8), 5UL);
  ASSERT_EQ(model.phys_mem.read64(state + 0x7F5C), 0x1234UL);
  ASSERT_EQ(model.phys_mem.read32(state + 0x7FAC) & 0xFFFF, CODE_ADDR >> 4);
  ASSERT_EQ(model.phys_mem.read32(state + 0x7EFC) & 0xFFFF, 0x0064UL);
  ASSERT_EQ(model.phys_mem.read32(state + 0x7EF8), SMBASE_DEFAULT);

  // Nothing was written at SMBASE + offset, the 32-KByte-lower location the
  // model used to save to.
  ASSERT_EQ(model.phys_mem.read64(SMBASE_DEFAULT + 0x7FD8), 0UL);
  ASSERT_EQ(model.phys_mem.read64(SMBASE_DEFAULT + 0x7F5C), 0UL);
}

TEST(smbase_relocation_moves_handler_and_save_area) {
  x86::Model model;
  init_model(model);

  const u64 NEW_SMBASE = 0x40000;
  // First handler (at 30000H + 8000H): store 40000H in the SMBASE field at
  // CS:FEF8H (CS base is SMBASE in SMM) and RSM.  Second handler (at
  // 40000H + 8000H): RSM.
  static const u8 handler1[] = {
    0x2E, 0xC7, 0x06, 0xF8, 0xFE, 0x00, 0x00,   // mov word [cs:0FEF8h], 0000h
    0x2E, 0xC7, 0x06, 0xFA, 0xFE, 0x04, 0x00,   // mov word [cs:0FEFAh], 0004h
    0x0F, 0xAA,                                 // rsm
  };
  static const u8 handler2[] = { 0x0F, 0xAA };
  model.phys_mem.write_bytes(SMBASE_DEFAULT + 0x8000, handler1, sizeof(handler1));
  model.phys_mem.write_bytes(NEW_SMBASE + 0x8000, handler2, sizeof(handler2));

  static const u8 code[] = {
    0xB8, 0x34, 0x12,   // mov ax, 1234h
    0xE6, 0xB2,         // out 0B2h, al      (first SMI: relocates SMBASE)
    0xB8, 0xCD, 0xAB,   // mov ax, 0ABCDh
    0xE6, 0xB2,         // out 0B2h, al      (second SMI: handler at the new base)
    0xBB, 0x78, 0x56,   // mov bx, 5678h
    0xF4,               // hlt
  };
  ASSERT_EQ(run_code(model, code, sizeof(code)), RUN_HALTED);

  ASSERT_EQ((u64)model.zGPR.data[0], 0xABCDUL);
  ASSERT_EQ((u64)model.zGPR.data[3], 0x5678UL);
  ASSERT_EQ((u64)model.zin_smm, 0UL);
  ASSERT_EQ((u64)model.zsmbase, NEW_SMBASE);

  // The first SMI saved at the default base, the second at the new one.
  ASSERT_EQ(model.phys_mem.read64(SMBASE_DEFAULT + 0x8000 + 0x7F5C), 0x1234UL);
  ASSERT_EQ(model.phys_mem.read64(SMBASE_DEFAULT + 0x8000 + 0x7FD8), 5UL);
  ASSERT_EQ(model.phys_mem.read64(NEW_SMBASE + 0x8000 + 0x7F5C), 0xABCDUL);
  ASSERT_EQ(model.phys_mem.read64(NEW_SMBASE + 0x8000 + 0x7FD8), 10UL);
  ASSERT_EQ(model.phys_mem.read32(NEW_SMBASE + 0x8000 + 0x7EF8), NEW_SMBASE);
}

TEST(rsm_restores_virtual_8086_context) {
  x86::Model model;
  init_model(model);
  model.zcur_mode = x86::zVirtual8086Mode;
  model.zcur_cpl = 3;
  model.zCR0 |= 1;
  model.zCR4 = 1;
  model.zRF = 1;
  model.zVIF = 1;
  model.zVIP = 1;
  model.zRIP = 0x1234;
  for (int i = 0; i < 6; i++) {
    model.zSegReg.data[i] = 0x1201 + i * 0x100;
    model.zSegCache.data[i].zseg_base = model.zSegReg.data[i] * 16;
    model.zSegCache.data[i].zseg_dpl = 3;
    model.zSegCache.data[i].zseg_type = 3;
  }
  const u64 flags = model.zread_rflags(UNIT);
  model.zdeliver_smi(UNIT);
  ASSERT_EQ(model.phys_mem.read64(SMBASE_DEFAULT + 0xffe8), flags);
  ASSERT_EQ((u64)model.zread_rflags(UNIT), 2UL);
  ASSERT_EQ(model.zcur_cpl, 0L);

  static const u8 rsm[] = {0x0f, 0xaa};
  model.phys_mem.write_bytes(SMBASE_DEFAULT + 0x8000, rsm, sizeof(rsm));
  model.zstep(UNIT);
  ASSERT_EQ(model.zfault_pending, false);
  ASSERT_EQ(model.zcur_mode, x86::zVirtual8086Mode);
  ASSERT_EQ(model.zcur_cpl, 3L);
  ASSERT_EQ((u64)model.zRIP, 0x1234UL);
  ASSERT_EQ((u64)model.zread_rflags(UNIT), flags);
  for (int i = 0; i < 6; i++) {
    const auto &seg = model.zSegCache.data[i];
    ASSERT_EQ(model.zSegReg.data[i], u64(0x1201 + i * 0x100));
    ASSERT_EQ(seg.zseg_base, u64(0x1201 + i * 0x100) * 16);
    ASSERT_EQ(seg.zseg_limit, 0xffffUL);
    ASSERT_EQ(seg.zseg_type, 3UL);
    ASSERT_EQ(seg.zseg_dpl, 3L);
    ASSERT_EQ(seg.zseg_db, 0UL);
  }
  model.model_fini();
}

int main() {
  printf("SMM tests:\n");
  run_test_smi_saves_state_at_smbase_plus_8000h();
  run_test_smbase_relocation_moves_handler_and_save_area();
  run_test_rsm_restores_virtual_8086_context();
  printf("\n%d passed, %d failed\n", tests_passed, tests_failed);
  return tests_failed ? 1 : 0;
}

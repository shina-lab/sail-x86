// VMX (VT-x) tests for the Sail x86 model.
//
// Tests the VMX instruction lifecycle: VMXON, VMCLEAR, VMPTRLD,
// VMWRITE, VMREAD, VMLAUNCH/VMRESUME, VM exits.
// Runs entirely within the Sail model (no KVM).

#include "sail_x86_model.h"
#include "x86-helpers.h"
#include <cassert>
#include <cstdio>
#include <cstring>

// Memory layout
static constexpr u64 CODE_ADDR     = 0x100000;  // 1MB
static constexpr u64 VMXON_REGION  = 0x200000;  // 2MB — VMXON region (4KB aligned)
static constexpr u64 VMCS_REGION   = 0x201000;  // VMCS region (4KB aligned)
static constexpr u64 DATA_ADDR     = 0x202000;  // scratch data
static constexpr u64 STACK_TOP     = 0x280000;
static constexpr u64 GUEST_CODE    = 0x300000;  // guest code runs here
static constexpr u64 GUEST_STACK   = 0x380000;

static void init_vmx_model(x86::Model &model) {
  model.model_init();
  model.zinitializze_registers(UNIT);
  x86::enable_all_features(model);

  model.zsystem_mode = false;
  model.zcur_mode = x86::zLongMode;
  model.zcur_cpl = 0;
  model.zSegCache.data[x86::SEG_CS].zseg_l = 1;
  model.zSegCache.data[x86::SEG_CS].zseg_db = 0;
  for (int i = 0; i < 6; i++) {
    model.zSegCache.data[i].zseg_base = 0;
    model.zSegCache.data[i].zseg_limit = 0xFFFFFFFF;
    model.zSegCache.data[i].zseg_present = 1;
    model.zSegCache.data[i].zseg_s = 1;
    model.zSegCache.data[i].zseg_g = 1;
    model.zSegCache.data[i].zseg_db = 1;
  }
  model.zSegCache.data[x86::SEG_CS].zseg_db = 0;
  model.zSegCache.data[x86::SEG_CS].zseg_l = 1;

  // CR0: PE + ET + NE + WP + PG
  model.zCR0 = (1UL << 0) | (1UL << 4) | (1UL << 5) | (1UL << 16) | (1UL << 31);
  // CR4: PAE + OSFXSR + VMXE
  model.zCR4 = (1UL << 5) | (1UL << 9) | (1UL << 13);
  // EFER: SCE + LME + LMA + NXE
  model.zEFER = (1UL << 0) | (1UL << 8) | (1UL << 10) | (1UL << 11);

  // Enable VMX
  model.zhas_vmx = true;

  assert(model.phys_mem.init(8 * 1024 * 1024));  // 8MB RAM

  // Identity-map first 8MB with 2MB pages
  model.phys_mem.write64(0x1000, 0x2000 | 0x03);  // PML4[0] -> PDPT
  model.phys_mem.write64(0x2000, 0x3000 | 0x03);  // PDPT[0] -> PD
  for (u64 j = 0; j < 4; j++)
    model.phys_mem.write64(0x3000 + j * 8, (j << 21) | 0x83);  // 2MB pages
  model.zCR3 = 0x1000;

  for (int i = 0; i < 16; i++)
    model.zGPR.data[i] = 0;
  model.zGPR.data[4] = STACK_TOP; // RSP

  // Write VMCS revision ID at the start of VMXON and VMCS regions
  model.phys_mem.write32(VMXON_REGION, 1);  // VMCS_REVISION_ID = 1
  model.phys_mem.write32(VMCS_REGION, 1);
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

#define ASSERT_TRUE(a) do { \
  if (!(a)) { \
    printf("FAIL\n    %s:%d: %s is false\n", __FILE__, __LINE__, #a); \
    tests_failed++; \
    return; \
  } \
} while(0)

// =========================================================================
// Test: VMXON succeeds with valid setup
// =========================================================================
TEST(vmxon_basic) {
  x86::Model model;
  init_vmx_model(model);

  // Write the VMXON region address at DATA_ADDR (operand for VMXON)
  model.phys_mem.write64(DATA_ADDR, VMXON_REGION);

  // F3 0F C7 /6 mem: VMXON [DATA_ADDR]
  // ModR/M: mod=00, reg=6, rm=100 (SIB) -> 0x34
  // SIB: scale=0, index=4(none), base=5(disp32) -> 0x25
  // disp32 = DATA_ADDR (little-endian)
  u8 code[] = {
    0xF3, 0x0F, 0xC7, 0x34, 0x25,
    (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
    (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
    0xF4,  // HLT
  };

  int result = run_code(model, CODE_ADDR, code, sizeof(code));
  ASSERT_EQ(result, RUN_HALTED);
  ASSERT_TRUE(model.zin_vmx_root);
  // CF=0, ZF=0 (VMsucceed)
  ASSERT_EQ(model.zCF, 0UL);
  ASSERT_EQ(model.zZF, 0UL);

  model.model_fini();
}

// =========================================================================
// Test: VMXON fails without CR4.VMXE
// =========================================================================
TEST(vmxon_no_vmxe) {
  x86::Model model;
  init_vmx_model(model);
  model.zCR4 &= ~(1UL << 13);  // Clear VMXE

  model.phys_mem.write64(DATA_ADDR, VMXON_REGION);

  u8 code[] = {
    0xF3, 0x0F, 0xC7, 0x34, 0x25,
    (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
    (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
    0xF4,
  };

  // Should #UD because CR4.VMXE=0
  int result = run_code(model, CODE_ADDR, code, sizeof(code));
  ASSERT_EQ(result, RUN_FAULTED);
  ASSERT_EQ(model.zfault_vector, 6L);  // #UD

  model.model_fini();
}

// =========================================================================
// Test: VMCLEAR + VMPTRLD + VMWRITE + VMREAD round-trip
// =========================================================================
TEST(vmcs_write_read) {
  x86::Model model;
  init_vmx_model(model);

  // VMXON first
  model.phys_mem.write64(DATA_ADDR, VMXON_REGION);
  u8 vmxon[] = {
    0xF3, 0x0F, 0xC7, 0x34, 0x25,
    (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
    (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
    0xF4,
  };
  run_code(model, CODE_ADDR, vmxon, sizeof(vmxon));
  ASSERT_TRUE(model.zin_vmx_root);

  // VMCLEAR the VMCS region
  model.phys_mem.write64(DATA_ADDR, VMCS_REGION);
  u8 vmclear[] = {
    0x66, 0x0F, 0xC7, 0x34, 0x25,
    (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
    (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
    0xF4,
  };
  run_code(model, CODE_ADDR, vmclear, sizeof(vmclear));
  ASSERT_EQ(model.zCF, 0UL);
  ASSERT_EQ(model.zZF, 0UL);

  // VMPTRLD the VMCS region
  u8 vmptrld[] = {
    0x0F, 0xC7, 0x34, 0x25,
    (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
    (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
    0xF4,
  };
  run_code(model, CODE_ADDR, vmptrld, sizeof(vmptrld));
  ASSERT_EQ(model.zCF, 0UL);
  ASSERT_EQ(model.zZF, 0UL);

  // VMWRITE: write 0xDEAD to guest RIP field (encoding 0x681E)
  // 0F 79 /r: VMWRITE r64, r/m64
  // reg = field encoding (in RAX), src = value (in RCX)
  // Actually: VMWRITE reg(encoding), r/m(value)
  // ModR/M: mod=11, reg=RAX(0), rm=RCX(1) -> 0xC1
  model.zGPR.data[0] = 0x681E;       // RAX = guest RIP encoding
  model.zGPR.data[1] = 0xDEADUL;     // RCX = value to write
  u8 vmwrite[] = {
    0x0F, 0x79, 0xC1,  // VMWRITE RAX, RCX
    0xF4,
  };
  run_code(model, CODE_ADDR, vmwrite, sizeof(vmwrite));
  ASSERT_EQ(model.zCF, 0UL);
  ASSERT_EQ(model.zZF, 0UL);

  // VMREAD: read back guest RIP field
  // 0F 78 /r: VMREAD r/m64, r64
  // ModR/M: mod=11, reg=RAX(0), rm=RCX(1) -> 0xC1
  // Reads field (in RAX) to dest (RCX)
  model.zGPR.data[0] = 0x681E;  // RAX = field encoding
  model.zGPR.data[1] = 0;       // Clear RCX
  u8 vmread[] = {
    0x0F, 0x78, 0xC1,  // VMREAD RCX, RAX
    0xF4,
  };
  run_code(model, CODE_ADDR, vmread, sizeof(vmread));
  ASSERT_EQ(model.zCF, 0UL);
  ASSERT_EQ(model.zZF, 0UL);
  ASSERT_EQ(model.zGPR.data[1], 0xDEADUL);  // RCX = read-back value

  model.model_fini();
}

// =========================================================================
// Test: VMLAUNCH -> guest CPUID -> VM exit with reason 0xA
// =========================================================================
TEST(vmlaunch_cpuid_exit) {
  x86::Model model;
  init_vmx_model(model);

  // --- VMXON ---
  model.phys_mem.write64(DATA_ADDR, VMXON_REGION);
  u8 vmxon[] = {
    0xF3, 0x0F, 0xC7, 0x34, 0x25,
    (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
    (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
    0xF4,
  };
  run_code(model, CODE_ADDR, vmxon, sizeof(vmxon));
  ASSERT_TRUE(model.zin_vmx_root);

  // --- VMCLEAR ---
  model.phys_mem.write64(DATA_ADDR, VMCS_REGION);
  u8 vmclear[] = {
    0x66, 0x0F, 0xC7, 0x34, 0x25,
    (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
    (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
    0xF4,
  };
  run_code(model, CODE_ADDR, vmclear, sizeof(vmclear));

  // --- VMPTRLD ---
  u8 vmptrld[] = {
    0x0F, 0xC7, 0x34, 0x25,
    (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
    (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
    0xF4,
  };
  run_code(model, CODE_ADDR, vmptrld, sizeof(vmptrld));

  // --- Set up VMCS via direct struct access (much simpler than VMWRITE) ---
  // Guest state
  model.zvmcs.zguest_cr0 = model.zCR0;
  model.zvmcs.zguest_cr3 = model.zCR3;
  model.zvmcs.zguest_cr4 = model.zCR4;
  model.zvmcs.zguest_dr7 = 0x400;
  model.zvmcs.zguest_rip = GUEST_CODE;
  model.zvmcs.zguest_rsp = GUEST_STACK;
  model.zvmcs.zguest_rflags = 0x2;  // reserved bit 1
  model.zvmcs.zguest_efer = model.zEFER;

  // Guest segments: flat 64-bit
  model.zvmcs.zguest_cs_selector = 0x08;
  model.zvmcs.zguest_cs_base = 0;
  model.zvmcs.zguest_cs_limit = 0xFFFFFFFF;
  model.zvmcs.zguest_cs_access = 0xA09B;  // L=1, D=0, P=1, S=1, type=0xB (exec/read)

  model.zvmcs.zguest_ss_selector = 0x10;
  model.zvmcs.zguest_ss_base = 0;
  model.zvmcs.zguest_ss_limit = 0xFFFFFFFF;
  model.zvmcs.zguest_ss_access = 0xC093;  // D=1, P=1, S=1, type=0x3 (data r/w)

  model.zvmcs.zguest_ds_selector = 0x10;
  model.zvmcs.zguest_ds_base = 0;
  model.zvmcs.zguest_ds_limit = 0xFFFFFFFF;
  model.zvmcs.zguest_ds_access = 0xC093;

  model.zvmcs.zguest_es_selector = 0x10;
  model.zvmcs.zguest_es_base = 0;
  model.zvmcs.zguest_es_limit = 0xFFFFFFFF;
  model.zvmcs.zguest_es_access = 0xC093;

  model.zvmcs.zguest_fs_selector = 0;
  model.zvmcs.zguest_fs_base = 0;
  model.zvmcs.zguest_fs_limit = 0xFFFFFFFF;
  model.zvmcs.zguest_fs_access = 0x0093;

  model.zvmcs.zguest_gs_selector = 0;
  model.zvmcs.zguest_gs_base = 0;
  model.zvmcs.zguest_gs_limit = 0xFFFFFFFF;
  model.zvmcs.zguest_gs_access = 0x0093;

  model.zvmcs.zguest_tr_selector = 0;
  model.zvmcs.zguest_tr_base = 0;
  model.zvmcs.zguest_tr_limit = 0xFF;
  model.zvmcs.zguest_tr_access = 0x008B;  // busy TSS

  model.zvmcs.zguest_ldtr_selector = 0;
  model.zvmcs.zguest_ldtr_base = 0;
  model.zvmcs.zguest_ldtr_limit = 0;
  model.zvmcs.zguest_ldtr_access = 0x0082;

  model.zvmcs.zguest_gdtr_base = 0;
  model.zvmcs.zguest_gdtr_limit = 0;
  model.zvmcs.zguest_idtr_base = 0;
  model.zvmcs.zguest_idtr_limit = 0;

  model.zvmcs.zguest_vmcs_link_pointer = 0xFFFFFFFFFFFFFFFFULL;
  model.zvmcs.zguest_activity_state = 0;

  // Host state: return to CODE_ADDR + 3 (after VMLAUNCH instruction)
  model.zvmcs.zhost_cr0 = model.zCR0;
  model.zvmcs.zhost_cr3 = model.zCR3;
  model.zvmcs.zhost_cr4 = model.zCR4;
  model.zvmcs.zhost_efer = model.zEFER;
  model.zvmcs.zhost_rip = CODE_ADDR + 3;  // resume after VMLAUNCH
  model.zvmcs.zhost_rsp = STACK_TOP;
  model.zvmcs.zhost_cs_selector = 0x08;
  model.zvmcs.zhost_ss_selector = 0x10;
  model.zvmcs.zhost_ds_selector = 0x10;
  model.zvmcs.zhost_es_selector = 0x10;
  model.zvmcs.zhost_fs_selector = 0;
  model.zvmcs.zhost_gs_selector = 0;
  model.zvmcs.zhost_tr_selector = 0x18;
  model.zvmcs.zhost_gdtr_base = 0;
  model.zvmcs.zhost_idtr_base = 0;

  // VM-exit controls: host address-space size = 64-bit (bit 9)
  model.zvmcs.zexit_controls = (1U << 9);

  // VM-entry controls: IA-32e mode guest (bit 9)
  model.zvmcs.zentry_controls = (1U << 9);

  // Write guest code: CPUID (causes unconditional VM exit)
  u8 guest_code[] = {
    0x0F, 0xA2,  // CPUID
  };
  model.phys_mem.write_bytes(GUEST_CODE, guest_code, sizeof(guest_code));

  // --- VMLAUNCH ---
  // After VM exit, host resumes at host_rip (CODE_ADDR + 3).
  // We put HLT there.
  u8 launch_code[] = {
    0x0F, 0x01, 0xC2,  // VMLAUNCH
    0xF4,              // HLT (host resumes here after VM exit)
  };
  int result = run_code(model, CODE_ADDR, launch_code, sizeof(launch_code));
  ASSERT_EQ(result, RUN_HALTED);

  // After VM exit: we should be back in VMX root, not non-root
  ASSERT_TRUE(model.zin_vmx_root);
  ASSERT_TRUE(!model.zin_vmx_non_root);

  // Check exit reason: CPUID = 0x0A
  ASSERT_EQ(model.zvmcs.zexit_reason, 0x0AU);

  // Check that guest RIP was saved (should be at CPUID instruction)
  ASSERT_EQ(model.zvmcs.zguest_rip, (u64)GUEST_CODE);

  model.model_fini();
}

// =========================================================================
// Test: VMCALL from non-root causes VM exit
// =========================================================================
TEST(vmcall_exit) {
  x86::Model model;
  init_vmx_model(model);

  // --- VMXON ---
  model.phys_mem.write64(DATA_ADDR, VMXON_REGION);
  u8 vmxon[] = {
    0xF3, 0x0F, 0xC7, 0x34, 0x25,
    (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
    (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
    0xF4,
  };
  run_code(model, CODE_ADDR, vmxon, sizeof(vmxon));

  // --- VMCLEAR + VMPTRLD ---
  model.phys_mem.write64(DATA_ADDR, VMCS_REGION);
  u8 vmclear[] = {
    0x66, 0x0F, 0xC7, 0x34, 0x25,
    (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
    (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
    0xF4,
  };
  run_code(model, CODE_ADDR, vmclear, sizeof(vmclear));

  u8 vmptrld[] = {
    0x0F, 0xC7, 0x34, 0x25,
    (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
    (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
    0xF4,
  };
  run_code(model, CODE_ADDR, vmptrld, sizeof(vmptrld));

  // --- Set up VMCS (same as vmlaunch test but guest runs VMCALL) ---
  model.zvmcs.zguest_cr0 = model.zCR0;
  model.zvmcs.zguest_cr3 = model.zCR3;
  model.zvmcs.zguest_cr4 = model.zCR4;
  model.zvmcs.zguest_dr7 = 0x400;
  model.zvmcs.zguest_rip = GUEST_CODE;
  model.zvmcs.zguest_rsp = GUEST_STACK;
  model.zvmcs.zguest_rflags = 0x2;
  model.zvmcs.zguest_efer = model.zEFER;

  model.zvmcs.zguest_cs_selector = 0x08;
  model.zvmcs.zguest_cs_base = 0;
  model.zvmcs.zguest_cs_limit = 0xFFFFFFFF;
  model.zvmcs.zguest_cs_access = 0xA09B;

  model.zvmcs.zguest_ss_selector = 0x10;
  model.zvmcs.zguest_ss_base = 0;
  model.zvmcs.zguest_ss_limit = 0xFFFFFFFF;
  model.zvmcs.zguest_ss_access = 0xC093;

  model.zvmcs.zguest_ds_selector = 0x10;
  model.zvmcs.zguest_ds_base = 0;
  model.zvmcs.zguest_ds_limit = 0xFFFFFFFF;
  model.zvmcs.zguest_ds_access = 0xC093;

  model.zvmcs.zguest_es_selector = 0x10;
  model.zvmcs.zguest_es_base = 0;
  model.zvmcs.zguest_es_limit = 0xFFFFFFFF;
  model.zvmcs.zguest_es_access = 0xC093;

  model.zvmcs.zguest_fs_selector = 0;
  model.zvmcs.zguest_fs_base = 0;
  model.zvmcs.zguest_fs_limit = 0xFFFFFFFF;
  model.zvmcs.zguest_fs_access = 0x0093;

  model.zvmcs.zguest_gs_selector = 0;
  model.zvmcs.zguest_gs_base = 0;
  model.zvmcs.zguest_gs_limit = 0xFFFFFFFF;
  model.zvmcs.zguest_gs_access = 0x0093;

  model.zvmcs.zguest_tr_selector = 0;
  model.zvmcs.zguest_tr_base = 0;
  model.zvmcs.zguest_tr_limit = 0xFF;
  model.zvmcs.zguest_tr_access = 0x008B;

  model.zvmcs.zguest_ldtr_selector = 0;
  model.zvmcs.zguest_ldtr_base = 0;
  model.zvmcs.zguest_ldtr_limit = 0;
  model.zvmcs.zguest_ldtr_access = 0x0082;

  model.zvmcs.zguest_gdtr_base = 0;
  model.zvmcs.zguest_gdtr_limit = 0;
  model.zvmcs.zguest_idtr_base = 0;
  model.zvmcs.zguest_idtr_limit = 0;
  model.zvmcs.zguest_vmcs_link_pointer = 0xFFFFFFFFFFFFFFFFULL;
  model.zvmcs.zguest_activity_state = 0;

  model.zvmcs.zhost_cr0 = model.zCR0;
  model.zvmcs.zhost_cr3 = model.zCR3;
  model.zvmcs.zhost_cr4 = model.zCR4;
  model.zvmcs.zhost_efer = model.zEFER;
  model.zvmcs.zhost_rip = CODE_ADDR + 3;
  model.zvmcs.zhost_rsp = STACK_TOP;
  model.zvmcs.zhost_cs_selector = 0x08;
  model.zvmcs.zhost_ss_selector = 0x10;
  model.zvmcs.zhost_ds_selector = 0x10;
  model.zvmcs.zhost_es_selector = 0x10;
  model.zvmcs.zhost_fs_selector = 0;
  model.zvmcs.zhost_gs_selector = 0;
  model.zvmcs.zhost_tr_selector = 0x18;
  model.zvmcs.zhost_gdtr_base = 0;
  model.zvmcs.zhost_idtr_base = 0;

  model.zvmcs.zexit_controls = (1U << 9);
  model.zvmcs.zentry_controls = (1U << 9);

  // Guest code: VMCALL
  u8 guest_code[] = {
    0x0F, 0x01, 0xC1,  // VMCALL
  };
  model.phys_mem.write_bytes(GUEST_CODE, guest_code, sizeof(guest_code));

  u8 launch_code[] = {
    0x0F, 0x01, 0xC2,  // VMLAUNCH
    0xF4,              // HLT
  };
  int result = run_code(model, CODE_ADDR, launch_code, sizeof(launch_code));
  ASSERT_EQ(result, RUN_HALTED);
  ASSERT_TRUE(model.zin_vmx_root);
  ASSERT_TRUE(!model.zin_vmx_non_root);

  // VMCALL exit reason = 0x12
  ASSERT_EQ(model.zvmcs.zexit_reason, 0x12U);

  model.model_fini();
}

// =========================================================================
// Test: VMCALL from root mode gives VMfailValid
// =========================================================================
TEST(vmcall_in_root) {
  x86::Model model;
  init_vmx_model(model);

  // VMXON
  model.phys_mem.write64(DATA_ADDR, VMXON_REGION);
  u8 vmxon[] = {
    0xF3, 0x0F, 0xC7, 0x34, 0x25,
    (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
    (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
    0xF4,
  };
  run_code(model, CODE_ADDR, vmxon, sizeof(vmxon));
  ASSERT_TRUE(model.zin_vmx_root);

  // VMCALL in root mode: should set ZF=1 (VMfailValid), error=1
  u8 vmcall[] = {
    0x0F, 0x01, 0xC1,  // VMCALL
    0xF4,
  };
  // Need a current VMCS for VMfailValid to write error
  model.phys_mem.write64(DATA_ADDR, VMCS_REGION);
  u8 vmclear[] = {
    0x66, 0x0F, 0xC7, 0x34, 0x25,
    (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
    (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
    0xF4,
  };
  run_code(model, CODE_ADDR, vmclear, sizeof(vmclear));
  u8 vmptrld[] = {
    0x0F, 0xC7, 0x34, 0x25,
    (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
    (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
    0xF4,
  };
  run_code(model, CODE_ADDR, vmptrld, sizeof(vmptrld));

  int result = run_code(model, CODE_ADDR, vmcall, sizeof(vmcall));
  ASSERT_EQ(result, RUN_HALTED);
  ASSERT_EQ(model.zZF, 1UL);  // VMfailValid
  ASSERT_EQ(model.zvmcs.zvm_instruction_error, 1U);  // VMCALL in root

  model.model_fini();
}

// =========================================================================
// Test: VMXOFF
// =========================================================================
TEST(vmxoff) {
  x86::Model model;
  init_vmx_model(model);

  // VMXON
  model.phys_mem.write64(DATA_ADDR, VMXON_REGION);
  u8 vmxon[] = {
    0xF3, 0x0F, 0xC7, 0x34, 0x25,
    (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
    (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
    0xF4,
  };
  run_code(model, CODE_ADDR, vmxon, sizeof(vmxon));
  ASSERT_TRUE(model.zin_vmx_root);

  // VMXOFF
  u8 vmxoff[] = {
    0x0F, 0x01, 0xC4,  // VMXOFF
    0xF4,
  };
  int result = run_code(model, CODE_ADDR, vmxoff, sizeof(vmxoff));
  ASSERT_EQ(result, RUN_HALTED);
  ASSERT_TRUE(!model.zin_vmx_root);
  ASSERT_TRUE(!model.zin_vmx_non_root);

  model.model_fini();
}

// =========================================================================

int main() {
  printf("VMX tests:\n");
  run_test_vmxon_basic();
  run_test_vmxon_no_vmxe();
  run_test_vmcs_write_read();
  run_test_vmlaunch_cpuid_exit();
  run_test_vmcall_exit();
  run_test_vmcall_in_root();
  run_test_vmxoff();
  printf("\n%d passed, %d failed\n", tests_passed, tests_failed);
  return tests_failed > 0 ? 1 : 0;
}

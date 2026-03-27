#include "kvm-harness.h"
#include <cstring>

// =========================================================================
// EVEX instruction encoder for test generation
// =========================================================================

// EVEX prefix fields
struct Evex {
  int mm = 1;       // map: 1=0F, 2=0F38, 3=0F3A
  int pp = 0;       // prefix: 0=NP, 1=66, 2=F3, 3=F2
  bool W = false;   // REX.W
  int LL = 0;       // vector length: 0=128, 1=256, 2=512
  int aaa = 0;      // mask register k0-k7
  bool z = false;   // zeroing masking
  int reg = 0;      // modrm.reg (destination, 0-31)
  int vvvv = 0;     // vvvvv source register (0-31, NOT inverted)
  int rm = 0;       // modrm.rm (source, 0-31)
  u8 opcode = 0;

  std::vector<u8> encode_rr() const {
    // EVEX 4-byte prefix + opcode + modrm (reg-reg)
    u8 R  = (reg < 8)  ? 1 : 0;   // inverted
    u8 X  = 1;                      // not used for reg-reg
    u8 B  = (rm < 8)   ? 1 : 0;   // inverted
    u8 Rp = (reg < 16) ? 1 : 0;   // inverted (R' for regs 16-31)
    u8 Vp = (vvvv < 16) ? 1 : 0;  // inverted (V' for vvvvv 16-31)

    u8 p0 = (R << 7) | (X << 6) | (B << 5) | (Rp << 4) | (mm & 0x3);
    u8 p1 = ((W ? 1 : 0) << 7) | ((~vvvv & 0xF) << 3) | (1 << 2) | (pp & 0x3);
    u8 p2 = ((z ? 1 : 0) << 7) | ((LL & 0x3) << 5) | (Vp << 3) | (aaa & 0x7);
    u8 modrm = 0xC0 | ((reg & 7) << 3) | (rm & 7);

    return {0x62, p0, p1, p2, opcode, modrm};
  }
};

// Helper: encode "MOV eax, imm32; KMOVW k1, eax" to set mask register k1
static std::vector<u8> set_kmask(u32 mask_val) {
  std::vector<u8> code;
  // MOV eax, imm32
  code.push_back(0xB8);
  code.push_back(mask_val & 0xFF);
  code.push_back((mask_val >> 8) & 0xFF);
  code.push_back((mask_val >> 16) & 0xFF);
  code.push_back((mask_val >> 24) & 0xFF);
  // KMOVW k1, eax (VEX.L0.0F.W0 92 /r → C5 F8 92 C8)
  code.push_back(0xC5);
  code.push_back(0xF8);
  code.push_back(0x92);
  code.push_back(0xC8);
  return code;
}

// Helper: concatenate code sequences
static std::vector<u8> concat(std::vector<u8> a, const std::vector<u8> &b) {
  a.insert(a.end(), b.begin(), b.end());
  return a;
}

// =========================================================================
// Test generation helpers
// =========================================================================

// Add a test for a reg-reg EVEX instruction at all three VLs (128/256/512)
// with no mask, zeroing mask, and merging mask.
static void add_evex_rr_tests(
    std::vector<TestCase> &tests,
    const std::string &cat_name,
    const char *mnemonic,
    Evex base,          // base encoding (LL/aaa/z will be overridden)
    ArchState init,     // initial state (xmm[reg] = dst, xmm[rm] = src2, xmm[vvvv] = src1)
    u32 xmm_cmp,       // which registers to compare
    u32 kmask_val = 0   // mask value for writemask tests (0 = skip mask tests)
) {
  std::string cat = cat_name;

  // Test all three VLs
  const char *vl_name[] = {"xmm", "ymm", "zmm"};
  const int vl_bits[] = {128, 256, 512};
  for (int ll = 0; ll <= 2; ll++) {
    std::string suffix = std::string(vl_name[ll]) + " (VL" + std::to_string(vl_bits[ll]) + ")";
    base.LL = ll;

    // No mask
    base.aaa = 0;
    base.z = false;
    auto code = base.encode_rr();
    tests.push_back({
      std::string(mnemonic) + " " + suffix,
      cat_name, code, init, FL_NONE, xmm_cmp, false
    });

    // Zeroing mask (if kmask_val provided)
    if (kmask_val) {
      base.aaa = 1;  // k1
      base.z = true;
      auto masked_code = concat(set_kmask(kmask_val), base.encode_rr());
      tests.push_back({
        std::string(mnemonic) + " " + suffix + " {k1}{z}",
        cat_name, masked_code, init, FL_NONE, xmm_cmp, false
      });
    }

    // Merging mask (if kmask_val provided)
    if (kmask_val) {
      base.aaa = 1;  // k1
      base.z = false;
      auto masked_code = concat(set_kmask(kmask_val), base.encode_rr());
      tests.push_back({
        std::string(mnemonic) + " " + suffix + " {k1}",
        cat_name, masked_code, init, FL_NONE, xmm_cmp, false
      });
    }
  }
}

// =========================================================================
// Comprehensive AVX test suite
// =========================================================================

void add_avx_comprehensive_tests(std::vector<TestCase> &tests) {
  // ----- Packed FP arithmetic (EVEX.66.0F) -----
  // VADDPD: EVEX.66.0F.W1 58 /r
  {
    ArchState s;
    s.rflags = 0x2;
    // dst=zmm0 (will be overwritten), src1=zmm1 (vvvv), src2=zmm2 (rm)
    // Use distinct values in each 64-bit lane so VL128/256/512 produce different results
    s.xmm[0] = xmm_from_u64(0xDEADDEADDEADDEAD, 0xDEADDEADDEADDEAD);  // dst (for merge test)
    s.xmm[1] = xmm_from_f64(1.0, 2.0);
    s.xmm[1].q[2] = s.xmm[1].q[0];  // lane 2 = 3.0
    s.xmm[1].q[3] = s.xmm[1].q[1];  // lane 3 = 4.0
    // Fill all 8 qwords for ZMM
    double vals1[] = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0};
    double vals2[] = {10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0};
    memcpy(s.xmm[1].q, vals1, 64);
    memcpy(s.xmm[2].q, vals2, 64);

    Evex e;
    e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0x58;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX FP arith", "VADDPD", e, s, 0x7, 0x5);
  }

  // VADDPS: EVEX.NP.0F.W0 58 /r
  {
    ArchState s;
    s.rflags = 0x2;
    float vals1[] = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f,
                     9.0f, 10.0f, 11.0f, 12.0f, 13.0f, 14.0f, 15.0f, 16.0f};
    float vals2[] = {100.0f, 200.0f, 300.0f, 400.0f, 500.0f, 600.0f, 700.0f, 800.0f,
                     900.0f, 1000.0f, 1100.0f, 1200.0f, 1300.0f, 1400.0f, 1500.0f, 1600.0f};
    memcpy(s.xmm[1].q, vals1, 64);
    memcpy(s.xmm[2].q, vals2, 64);

    Evex e;
    e.mm = 1; e.pp = 0; e.W = false; e.opcode = 0x58;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX FP arith", "VADDPS", e, s, 0x7, 0xA);
  }

  // VSUBPD: EVEX.66.0F.W1 5C /r
  {
    ArchState s;
    s.rflags = 0x2;
    double vals1[] = {100.0, 200.0, 300.0, 400.0, 500.0, 600.0, 700.0, 800.0};
    double vals2[] = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0};
    memcpy(s.xmm[1].q, vals1, 64);
    memcpy(s.xmm[2].q, vals2, 64);

    Evex e;
    e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0x5C;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX FP arith", "VSUBPD", e, s, 0x7, 0x5);
  }

  // VSUBPS: EVEX.NP.0F.W0 5C /r
  {
    ArchState s;
    s.rflags = 0x2;
    float vals1[] = {100.0f, 200.0f, 300.0f, 400.0f, 500.0f, 600.0f, 700.0f, 800.0f,
                     900.0f, 1000.0f, 1100.0f, 1200.0f, 1300.0f, 1400.0f, 1500.0f, 1600.0f};
    float vals2[] = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f,
                     9.0f, 10.0f, 11.0f, 12.0f, 13.0f, 14.0f, 15.0f, 16.0f};
    memcpy(s.xmm[1].q, vals1, 64);
    memcpy(s.xmm[2].q, vals2, 64);

    Evex e;
    e.mm = 1; e.pp = 0; e.W = false; e.opcode = 0x5C;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX FP arith", "VSUBPS", e, s, 0x7, 0xA);
  }

  // VMULPD: EVEX.66.0F.W1 59 /r
  {
    ArchState s;
    s.rflags = 0x2;
    double vals1[] = {2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0};
    double vals2[] = {10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0};
    memcpy(s.xmm[1].q, vals1, 64);
    memcpy(s.xmm[2].q, vals2, 64);

    Evex e;
    e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0x59;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX FP arith", "VMULPD", e, s, 0x7, 0x5);
  }

  // VMULPS: EVEX.NP.0F.W0 59 /r
  {
    ArchState s;
    s.rflags = 0x2;
    float vals1[] = {2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f, 9.0f,
                     10.0f, 11.0f, 12.0f, 13.0f, 14.0f, 15.0f, 16.0f, 17.0f};
    float vals2[] = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f,
                     9.0f, 10.0f, 11.0f, 12.0f, 13.0f, 14.0f, 15.0f, 16.0f};
    memcpy(s.xmm[1].q, vals1, 64);
    memcpy(s.xmm[2].q, vals2, 64);

    Evex e;
    e.mm = 1; e.pp = 0; e.W = false; e.opcode = 0x59;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX FP arith", "VMULPS", e, s, 0x7, 0xA);
  }

  // VDIVPD: EVEX.66.0F.W1 5E /r
  {
    ArchState s;
    s.rflags = 0x2;
    double vals1[] = {100.0, 200.0, 300.0, 400.0, 500.0, 600.0, 700.0, 800.0};
    double vals2[] = {10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0};
    memcpy(s.xmm[1].q, vals1, 64);
    memcpy(s.xmm[2].q, vals2, 64);

    Evex e;
    e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0x5E;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX FP arith", "VDIVPD", e, s, 0x7, 0x5);
  }

  // VDIVPS: EVEX.NP.0F.W0 5E /r
  {
    ArchState s;
    s.rflags = 0x2;
    float vals1[] = {100.0f, 200.0f, 300.0f, 400.0f, 500.0f, 600.0f, 700.0f, 800.0f,
                     900.0f, 1000.0f, 1100.0f, 1200.0f, 1300.0f, 1400.0f, 1500.0f, 1600.0f};
    float vals2[] = {10.0f, 20.0f, 30.0f, 40.0f, 50.0f, 60.0f, 70.0f, 80.0f,
                     90.0f, 100.0f, 110.0f, 120.0f, 130.0f, 140.0f, 150.0f, 160.0f};
    memcpy(s.xmm[1].q, vals1, 64);
    memcpy(s.xmm[2].q, vals2, 64);

    Evex e;
    e.mm = 1; e.pp = 0; e.W = false; e.opcode = 0x5E;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX FP arith", "VDIVPS", e, s, 0x7, 0xA);
  }

  // VMINPD: EVEX.66.0F.W1 5D /r
  {
    ArchState s;
    s.rflags = 0x2;
    double vals1[] = {1.0, 200.0, 3.0, 400.0, 5.0, 600.0, 7.0, 800.0};
    double vals2[] = {100.0, 2.0, 300.0, 4.0, 500.0, 6.0, 700.0, 8.0};
    memcpy(s.xmm[1].q, vals1, 64);
    memcpy(s.xmm[2].q, vals2, 64);

    Evex e;
    e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0x5D;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX FP arith", "VMINPD", e, s, 0x7, 0x5);
  }

  // VMAXPD: EVEX.66.0F.W1 5F /r
  {
    ArchState s;
    s.rflags = 0x2;
    double vals1[] = {1.0, 200.0, 3.0, 400.0, 5.0, 600.0, 7.0, 800.0};
    double vals2[] = {100.0, 2.0, 300.0, 4.0, 500.0, 6.0, 700.0, 8.0};
    memcpy(s.xmm[1].q, vals1, 64);
    memcpy(s.xmm[2].q, vals2, 64);

    Evex e;
    e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0x5F;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX FP arith", "VMAXPD", e, s, 0x7, 0x5);
  }

  // VMINPS: EVEX.NP.0F.W0 5D /r
  {
    ArchState s;
    s.rflags = 0x2;
    float vals1[] = {1.0f, 200.0f, 3.0f, 400.0f, 5.0f, 600.0f, 7.0f, 800.0f,
                     9.0f, 1000.0f, 11.0f, 1200.0f, 13.0f, 1400.0f, 15.0f, 1600.0f};
    float vals2[] = {100.0f, 2.0f, 300.0f, 4.0f, 500.0f, 6.0f, 700.0f, 8.0f,
                     900.0f, 10.0f, 1100.0f, 12.0f, 1300.0f, 14.0f, 1500.0f, 16.0f};
    memcpy(s.xmm[1].q, vals1, 64);
    memcpy(s.xmm[2].q, vals2, 64);

    Evex e;
    e.mm = 1; e.pp = 0; e.W = false; e.opcode = 0x5D;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX FP arith", "VMINPS", e, s, 0x7, 0xAAAA);
  }

  // VMAXPS: EVEX.NP.0F.W0 5F /r
  {
    ArchState s;
    s.rflags = 0x2;
    float vals1[] = {1.0f, 200.0f, 3.0f, 400.0f, 5.0f, 600.0f, 7.0f, 800.0f,
                     9.0f, 1000.0f, 11.0f, 1200.0f, 13.0f, 1400.0f, 15.0f, 1600.0f};
    float vals2[] = {100.0f, 2.0f, 300.0f, 4.0f, 500.0f, 6.0f, 700.0f, 8.0f,
                     900.0f, 10.0f, 1100.0f, 12.0f, 1300.0f, 14.0f, 1500.0f, 16.0f};
    memcpy(s.xmm[1].q, vals1, 64);
    memcpy(s.xmm[2].q, vals2, 64);

    Evex e;
    e.mm = 1; e.pp = 0; e.W = false; e.opcode = 0x5F;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX FP arith", "VMAXPS", e, s, 0x7, 0xAAAA);
  }

  // VSQRTPD: EVEX.66.0F.W1 51 /r (unary: dst = sqrt(src), vvvv must be 1111)
  {
    ArchState s;
    s.rflags = 0x2;
    double vals[] = {4.0, 9.0, 16.0, 25.0, 36.0, 49.0, 64.0, 81.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e;
    e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0x51;
    e.reg = 0; e.vvvv = 0; e.rm = 1;

    add_evex_rr_tests(tests, "AVX FP arith", "VSQRTPD", e, s, 0x3, 0x5);
  }

  // VSQRTPS: EVEX.NP.0F.W0 51 /r
  {
    ArchState s;
    s.rflags = 0x2;
    float vals[] = {4.0f, 9.0f, 16.0f, 25.0f, 36.0f, 49.0f, 64.0f, 81.0f,
                    100.0f, 121.0f, 144.0f, 169.0f, 196.0f, 225.0f, 256.0f, 289.0f};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e;
    e.mm = 1; e.pp = 0; e.W = false; e.opcode = 0x51;
    e.reg = 0; e.vvvv = 0; e.rm = 1;

    add_evex_rr_tests(tests, "AVX FP arith", "VSQRTPS", e, s, 0x3, 0xAAAA);
  }

  // ----- Packed integer arithmetic (EVEX.66.0F) -----

  // VPADDB: EVEX.66.0F.WIG FC /r
  {
    ArchState s;
    s.rflags = 0x2;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = i;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = 64 + i;

    Evex e;
    e.mm = 1; e.pp = 1; e.W = false; e.opcode = 0xFC;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX int arith", "VPADDB", e, s, 0x7, 0xAAAAAAAA);
  }

  // VPADDW: EVEX.66.0F.WIG FD /r
  {
    ArchState s;
    s.rflags = 0x2;
    for (int i = 0; i < 32; i++) ((u16 *)s.xmm[1].q)[i] = i * 100;
    for (int i = 0; i < 32; i++) ((u16 *)s.xmm[2].q)[i] = i * 200;

    Evex e;
    e.mm = 1; e.pp = 1; e.W = false; e.opcode = 0xFD;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX int arith", "VPADDW", e, s, 0x7, 0x55555555);
  }

  // VPADDD: EVEX.66.0F.W0 FE /r
  {
    ArchState s;
    s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[1].q)[i] = 0x10000000 * i;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[2].q)[i] = 0x01000000 * i;

    Evex e;
    e.mm = 1; e.pp = 1; e.W = false; e.opcode = 0xFE;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX int arith", "VPADDD", e, s, 0x7, 0xA);
  }

  // VPADDQ: EVEX.66.0F.W1 D4 /r
  {
    ArchState s;
    s.rflags = 0x2;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x100000000ULL * (i + 1);
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = 0x200000000ULL * (i + 1);

    Evex e;
    e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0xD4;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX int arith", "VPADDQ", e, s, 0x7, 0x5);
  }

  // VPSUBB: EVEX.66.0F.WIG F8 /r
  {
    ArchState s;
    s.rflags = 0x2;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = 200;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = i;

    Evex e;
    e.mm = 1; e.pp = 1; e.W = false; e.opcode = 0xF8;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX int arith", "VPSUBB", e, s, 0x7, 0xAAAAAAAA);
  }

  // VPSUBW: EVEX.66.0F.WIG F9 /r
  {
    ArchState s;
    s.rflags = 0x2;
    for (int i = 0; i < 32; i++) ((u16 *)s.xmm[1].q)[i] = 50000;
    for (int i = 0; i < 32; i++) ((u16 *)s.xmm[2].q)[i] = i * 100;

    Evex e;
    e.mm = 1; e.pp = 1; e.W = false; e.opcode = 0xF9;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX int arith", "VPSUBW", e, s, 0x7, 0x55555555);
  }

  // VPSUBD: EVEX.66.0F.W0 FA /r
  {
    ArchState s;
    s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[1].q)[i] = 0x80000000 + i;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[2].q)[i] = i * 3;

    Evex e;
    e.mm = 1; e.pp = 1; e.W = false; e.opcode = 0xFA;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX int arith", "VPSUBD", e, s, 0x7, 0xA);
  }

  // VPSUBQ: EVEX.66.0F.W1 FB /r
  {
    ArchState s;
    s.rflags = 0x2;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x8000000000000000ULL + i;
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = i * 7;

    Evex e;
    e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0xFB;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX int arith", "VPSUBQ", e, s, 0x7, 0x5);
  }

  // ----- Packed integer logical (EVEX.66.0F) -----

  // VPANDD: EVEX.66.0F.W0 DB /r
  {
    ArchState s;
    s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[1].q)[i] = 0xFF00FF00 + i;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[2].q)[i] = 0x0F0F0F0F;

    Evex e;
    e.mm = 1; e.pp = 1; e.W = false; e.opcode = 0xDB;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX int logical", "VPANDD", e, s, 0x7, 0xA);
  }

  // VPANDQ: EVEX.66.0F.W1 DB /r
  {
    ArchState s;
    s.rflags = 0x2;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0xFF00FF00FF00FF00ULL + i;
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = 0x0F0F0F0F0F0F0F0FULL;

    Evex e;
    e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0xDB;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX int logical", "VPANDQ", e, s, 0x7, 0x5);
  }

  // VPORD: EVEX.66.0F.W0 EB /r
  {
    ArchState s;
    s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[1].q)[i] = 0xF0000000 + i;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[2].q)[i] = 0x0000000F;

    Evex e;
    e.mm = 1; e.pp = 1; e.W = false; e.opcode = 0xEB;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX int logical", "VPORD", e, s, 0x7, 0xA);
  }

  // VPORQ: EVEX.66.0F.W1 EB /r
  {
    ArchState s;
    s.rflags = 0x2;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0xF000000000000000ULL + i;
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = 0x000000000000000FULL;

    Evex e;
    e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0xEB;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX int logical", "VPORQ", e, s, 0x7, 0x5);
  }

  // VPXORD: EVEX.66.0F.W0 EF /r
  {
    ArchState s;
    s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[1].q)[i] = 0xAAAAAAAA + i;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[2].q)[i] = 0x55555555;

    Evex e;
    e.mm = 1; e.pp = 1; e.W = false; e.opcode = 0xEF;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX int logical", "VPXORD", e, s, 0x7, 0xA);
  }

  // VPXORQ: EVEX.66.0F.W1 EF /r
  {
    ArchState s;
    s.rflags = 0x2;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0xAAAAAAAAAAAAAAAAULL + i;
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = 0x5555555555555555ULL;

    Evex e;
    e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0xEF;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX int logical", "VPXORQ", e, s, 0x7, 0x5);
  }

  // VPANDND: EVEX.66.0F.W0 DF /r
  {
    ArchState s;
    s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[1].q)[i] = 0xFF00FF00;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[2].q)[i] = 0xFFFFFFFF - i;

    Evex e;
    e.mm = 1; e.pp = 1; e.W = false; e.opcode = 0xDF;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX int logical", "VPANDND", e, s, 0x7, 0xA);
  }

  // VPANDNQ: EVEX.66.0F.W1 DF /r
  {
    ArchState s;
    s.rflags = 0x2;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0xFF00FF00FF00FF00ULL;
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = 0xFFFFFFFFFFFFFFFFULL - i;

    Evex e;
    e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0xDF;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_evex_rr_tests(tests, "AVX int logical", "VPANDNQ", e, s, 0x7, 0x5);
  }
}

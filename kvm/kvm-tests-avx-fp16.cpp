#include "kvm-avx-encoder.h"
#include <cmath>
#include <cstdint>
#include <cstring>

// AVX-512 FP16 (EVEX opcode maps 5 and 6, plus the FP16 forms in map 3).
//
// The AMD development host has no FP16, so the harness skips this category
// there (CPUID.(7,0):EDX[23]); the templates were run against an Intel Xeon
// Platinum 8562Y+ (Emerald Rapids).  Inputs are chosen so that the exact
// result is representable in binary16: the model computes FP16 arithmetic
// in the host's float and rounds once at the end, which agrees with a
// single rounding of the exact result only when no double rounding can
// occur.  Approximate instructions (VRCPPH, VRSQRTPH) are left out because
// the harness's tolerance comparison supports 32- and 64-bit elements only.

namespace {

uint16_t h16(float f) {
  _Float16 h = (_Float16)f;
  uint16_t r;
  memcpy(&r, &h, 2);
  return r;
}

// Fill a 512-bit register with 32 halves taken cyclically from vals[0..n).
void set_ph(ZmmVal &v, const float *vals, int n) {
  uint16_t h[32];
  for (int i = 0; i < 32; i++) h[i] = h16(vals[i % n]);
  memcpy(v.q, h, 64);
}

// Fill with a generated sequence.
template <class F> void gen_ph(ZmmVal &v, F f) {
  uint16_t h[32];
  for (int i = 0; i < 32; i++) h[i] = h16(f(i));
  memcpy(v.q, h, 64);
}

std::vector<u8> zmm_bytes(const ZmmVal &v) {
  std::vector<u8> d(64);
  memcpy(d.data(), v.q, 64);
  return d;
}

std::vector<u8> half_bytes(float f) {
  std::vector<u8> d(64, 0);
  uint16_t h = h16(f);
  memcpy(d.data(), &h, 2);
  return d;
}

void sentinel(ZmmVal &v) {
  for (u64 &w : v.q) w = 0xDEADDEADDEADDEADULL;
}

// Scalar state (LIG forms, tested at VL128): dst xmm0 holds 99.0 under a
// sentinel, src1 xmm1 holds a under a different sentinel, src2 xmm2 holds b.
ArchState make_sh_state(float a, float b) {
  ArchState s;
  s.rflags = 0x2;
  s.rdi = DATA_ADDR;
  uint16_t h;
  sentinel(s.xmm[0]);
  h = h16(99.0f); memcpy(&s.xmm[0].q[0], &h, 2);
  s.xmm[1].q[0] = 0xAAAAAAAAAAAA0000ULL;
  h = h16(a); memcpy(&s.xmm[1].q[0], &h, 2);
  s.xmm[1].q[1] = 0xBBBBBBBBCCCCCCCCULL;
  s.xmm[2].q[0] = 0x1111111111110000ULL;
  h = h16(b); memcpy(&s.xmm[2].q[0], &h, 2);
  return s;
}

// A scalar instruction with no mask, zeroing mask (k1[0] = 1 and 0) and
// merging mask (k1[0] = 0).  inputs: registers whose contents are inputs
// (bit i = xmm i).
void add_scalar(std::vector<TestCase> &tests, const std::string &cat,
                const char *name, Evex e, ArchState s, u32 inputs) {
  ArchState merge = s;
  s = with_vector_inputs(s, inputs);
  e.LL = 0;
  e.aaa = 0; e.z = false;
  tests.push_back({std::string(name) + " xmm", cat, e.encode_rr(), s, FL_ALL, 0x7, false});
  e.aaa = 1; e.z = true;
  tests.push_back({std::string(name) + " xmm {k1}{z} mask=1", cat,
                   concat(set_kmask(1), e.encode_rr()), s, FL_ALL, 0x7, false});
  tests.push_back({std::string(name) + " xmm {k1}{z} mask=0", cat,
                   concat(set_kmask(0), e.encode_rr()), s, FL_ALL, 0x7, false});
  e.aaa = 1; e.z = false;
  tests.push_back({std::string(name) + " xmm {k1} mask=0", cat,
                   concat(set_kmask(0), e.encode_rr()), merge, FL_ALL, 0x7, false});
}

const char *const vl_name[] = {"xmm", "ymm", "zmm"};

}  // namespace

void add_avx_fp16_tests(std::vector<TestCase> &tests) {
  std::string cat = "AVX-512 FP16";

  // @@BLOCK packed_arith
  // Packed binary arithmetic, EVEX.NP.MAP5.W0: VADDPH 58, VMULPH 59,
  // VSUBPH 5C, VMINPH 5D, VDIVPH 5E, VMAXPH 5F.  src2 is a power of two so
  // that products and quotients are exact.
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    gen_ph(s.xmm[1], [](int i) {
      static const float specials[] = {-3.5f, 0.0f, 1000.0f, -0.001f};
      return (i % 8 == 7) ? specials[(i / 8) % 4] : float(i) + 1.5f;
    });
    gen_ph(s.xmm[2], [](int i) { return float(1 << ((i % 4) + 1)) * ((i % 5 == 4) ? -1.0f : 1.0f); });
    sentinel(s.xmm[0]);
    std::vector<u8> mem = zmm_bytes(s.xmm[2]);

    struct Op { const char *name; u8 op; } ops[] = {
      {"VADDPH", 0x58}, {"VMULPH", 0x59}, {"VSUBPH", 0x5C},
      {"VMINPH", 0x5D}, {"VDIVPH", 0x5E}, {"VMAXPH", 0x5F},
    };
    for (auto &o : ops) {
      Evex e; e.mm = 5; e.pp = 0; e.W = false; e.opcode = o.op;
      e.reg = 0; e.vvvv = 1; e.rm = 2;
      add_evex_rr_tests(tests, cat, o.name, e, s, 0x6, 0xAAAA);
      add_evex_rm_tests(tests, cat, o.name, e, s, 0x2, mem, 0xAAAA);
      add_evex_bcast_tests(tests, cat, o.name, e, s, 0x2, half_bytes(4.0f));
    }
  }

  // VSQRTPH: EVEX.NP.MAP5.W0 51 /r (unary), perfect squares.
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    gen_ph(s.xmm[1], [](int i) { float k = float(i % 16 + 1); return k * k; });
    sentinel(s.xmm[0]);
    Evex e; e.mm = 5; e.pp = 0; e.W = false; e.opcode = 0x51;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VSQRTPH", e, s, 0x2, 0xAAAA);
    add_evex_rm_tests(tests, cat, "VSQRTPH", e, s, 0x0, zmm_bytes(s.xmm[1]), 0xAAAA);
  }
  // @@END

  // @@BLOCK scalar_arith
  // Scalar SH arithmetic: EVEX.LIG.F3.MAP5.W0.
  {
    Evex e; e.mm = 5; e.pp = 2; e.W = false; e.reg = 0; e.vvvv = 1; e.rm = 2;
    ArchState s = make_sh_state(3.0f, 8.0f);
    e.opcode = 0x58; add_scalar(tests, cat, "VADDSH", e, s, 0x6);
    e.opcode = 0x5C; add_scalar(tests, cat, "VSUBSH", e, s, 0x6);
    e.opcode = 0x59; add_scalar(tests, cat, "VMULSH", e, s, 0x6);
    e.opcode = 0x5E; add_scalar(tests, cat, "VDIVSH", e, s, 0x6);
    e.opcode = 0x5D; add_scalar(tests, cat, "VMINSH", e, s, 0x6);
    e.opcode = 0x5F; add_scalar(tests, cat, "VMAXSH", e, s, 0x6);
    ArchState sq = make_sh_state(0.0f, 25.0f);
    e.opcode = 0x51; add_scalar(tests, cat, "VSQRTSH", e, sq, 0x6);
    ArchState neg = make_sh_state(-2.5f, 0.0f);
    e.opcode = 0x5E; add_scalar(tests, cat, "VDIVSH by zero", e, neg, 0x6);
  }
  // @@END

  // @@BLOCK comis
  // VCOMISH / VUCOMISH: EVEX.LIG.NP.MAP5.W0 2F / 2E, set ZF/PF/CF.
  {
    struct C { const char *name; float a, b; } cases[] = {
      {"lt", 3.0f, 7.0f}, {"gt", 7.0f, 3.0f}, {"eq", 5.0f, 5.0f},
      {"nan", NAN, 1.0f}, {"-0 vs +0", -0.0f, 0.0f},
    };
    for (auto &c : cases) {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      uint16_t h = h16(c.a); memcpy(&s.xmm[1].q[0], &h, 2);
      h = h16(c.b); memcpy(&s.xmm[2].q[0], &h, 2);
      Evex e; e.mm = 5; e.pp = 0; e.W = false; e.reg = 1; e.vvvv = 0; e.rm = 2; e.LL = 0;
      e.opcode = 0x2F;
      tests.push_back({std::string("VCOMISH ") + c.name, cat, e.encode_rr(), s, FL_ALL, 0, false});
      e.opcode = 0x2E;
      tests.push_back({std::string("VUCOMISH ") + c.name, cat, e.encode_rr(), s, FL_ALL, 0, false});
    }
  }
  // @@END

  // @@BLOCK vmovw
  // VMOVW: EVEX.128.66.MAP5.W0 6E (load), 7E (store).
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    sentinel(s.xmm[0]);
    uint16_t h = h16(-1.25f);
    memcpy(&s.xmm[2].q[0], &h, 2);
    s.xmm[2].q[0] |= 0x5555666677770000ULL;
    std::vector<u8> mem = half_bytes(2.75f);
    for (int i = 2; i < 64; i++) mem[i] = u8(0x80 + i);

    Evex e; e.mm = 5; e.pp = 1; e.W = false; e.LL = 0;
    e.opcode = 0x6E; e.reg = 0; e.vvvv = 0; e.rm = 7;
    {
      TestCase tc = {"VMOVW xmm, [mem]", cat, e.encode_rm_mem(), s, FL_ALL, 0x7, false};
      tc.init_data = mem;
      tests.push_back(std::move(tc));
    }
    e.opcode = 0x7E; e.reg = 2;
    {
      TestCase tc = {"VMOVW [mem], xmm", cat, e.encode_mr_mem(), s, FL_ALL, 0x7, false};
      tc.init_data = std::vector<u8>(64, 0);
      tc.compare_data_len = 64;
      tests.push_back(std::move(tc));
    }
  }
  // @@END

  // @@BLOCK vmovsh
  // VMOVSH: EVEX.LIG.F3.MAP5.W0 10 (load / reg-reg), 11 (store), with the
  // writemask on the low element.
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    sentinel(s.xmm[0]);
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x1111222233334444ULL + i;
    uint16_t h = h16(-1.25f);
    memcpy(&s.xmm[2].q[0], &h, 2);
    s.xmm[2].q[0] |= 0x5555666677770000ULL;
    std::vector<u8> mem = half_bytes(2.75f);
    for (int i = 2; i < 64; i++) mem[i] = u8(0x80 + i);

    Evex e; e.mm = 5; e.pp = 2; e.W = false; e.LL = 0;
    // VMOVSH xmm0, [rdi]: low half from memory, rest zero.
    e.opcode = 0x10; e.reg = 0; e.vvvv = 0; e.rm = 7;
    {
      TestCase tc = {"VMOVSH xmm, [mem]", cat, e.encode_rm_mem(), s, FL_ALL, 0x7, false};
      tc.init_data = mem;
      tests.push_back(std::move(tc));
      e.aaa = 1; e.z = true;
      TestCase tz = {"VMOVSH xmm, [mem] {k1}{z} mask=0", cat,
                     concat(set_kmask(0), e.encode_rm_mem()), s, FL_ALL, 0x7, false};
      tz.init_data = mem;
      tests.push_back(std::move(tz));
      e.aaa = 0; e.z = false;
    }
    // VMOVSH xmm0, xmm1, xmm2: dst = xmm1[127:16] : xmm2[15:0].
    e.opcode = 0x10; e.reg = 0; e.vvvv = 1; e.rm = 2;
    tests.push_back({"VMOVSH xmm, xmm, xmm", cat, e.encode_rr(), s, FL_ALL, 0x7, false});
    e.aaa = 1; e.z = false;
    tests.push_back({"VMOVSH xmm, xmm, xmm {k1} mask=0", cat,
                     concat(set_kmask(0), e.encode_rr()), s, FL_ALL, 0x7, false});
    e.aaa = 0;
    // VMOVSH [rdi], xmm2, and the masked store with k1[0] = 0 (no write).
    e.opcode = 0x11; e.reg = 2; e.vvvv = 0;
    {
      TestCase tc = {"VMOVSH [mem], xmm", cat, e.encode_mr_mem(), s, FL_ALL, 0x7, false};
      tc.init_data = std::vector<u8>(64, 0);
      tc.compare_data_len = 64;
      tests.push_back(std::move(tc));
      e.aaa = 1;
      TestCase tm = {"VMOVSH [mem], xmm {k1} mask=0", cat,
                     concat(set_kmask(0), e.encode_mr_mem()), s, FL_ALL, 0x7, false};
      tm.init_data = std::vector<u8>(64, 0x5A);
      tm.compare_data_len = 64;
      tests.push_back(std::move(tm));
      e.aaa = 0;
    }
  }
  // @@END

  // @@BLOCK conv_pass
  // Conversions from FP16 to wider formats: VCVTPH2PSX (66.MAP6.W0 13),
  // VCVTPH2PD (NP.MAP5.W0 5A), VCVTPH2DQ (66.MAP5.W0 5B), VCVTTPH2DQ
  // (F3.MAP5.W0 5B).
  {
    static const float halves[] = {1.5f, -2.75f, 1000.0f, 0.1f, 65504.0f, -0.0f,
                                   0.00006f, 3.140625f, -7.0f, 0.333f, 12.0f, -1e-5f,
                                   255.0f, 256.5f, -100.25f, 2.0f};
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    set_ph(s.xmm[1], halves, 16);
    sentinel(s.xmm[0]);
    struct Cv { const char *name; int mm; int pp; u8 op; } from_ph[] = {
      {"VCVTPH2PSX", 6, 1, 0x13}, {"VCVTPH2PD", 5, 0, 0x5A},
      {"VCVTPH2DQ", 5, 1, 0x5B}, {"VCVTTPH2DQ", 5, 2, 0x5B},
    };
    for (auto &c : from_ph) {
      Evex e; e.mm = c.mm; e.pp = c.pp; e.W = false; e.opcode = c.op;
      e.reg = 0; e.vvvv = 0; e.rm = 1;
      add_evex_rr_tests(tests, cat, c.name, e, s, 0x2, 0xAAAA);
    }
  }
  // int16 -> FP16 (VCVTW2PH F3.MAP5.W0 7D), uint16 -> FP16 (VCVTUW2PH
  // F2.MAP5.W0 7D).
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    sentinel(s.xmm[0]);
    int16_t w[32];
    for (int i = 0; i < 32; i++) w[i] = int16_t((i * 977) % 4001 - 2000);
    memcpy(s.xmm[1].q, w, 64);
    Evex e; e.mm = 5; e.pp = 2; e.W = false; e.opcode = 0x7D;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VCVTW2PH", e, s, 0x2, 0xAAAA);
    e.pp = 3;
    add_evex_rr_tests(tests, cat, "VCVTUW2PH", e, s, 0x2, 0xAAAA);
  }
  // VCVTSS2SH NP.MAP5.W0 1D: dst = src1[127:16] : f16(src2 float).
  {
    ArchState s = make_sh_state(3.0f, -2.75f);
    float f = 100.9f;
    memcpy(&s.xmm[2].q[0], &f, 4);
    Evex e; e.mm = 5; e.pp = 0; e.W = false; e.opcode = 0x1D;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_scalar(tests, cat, "VCVTSS2SH", e, s, 0x6);
  }
  // @@END


  // @@BLOCK conv_narrow
  // Conversions to FP16 whose result is narrower than the source vector:
  // FP32 -> FP16 (VCVTPS2PHX 66.MAP5.W0 1D), FP64 -> FP16 (VCVTPD2PH
  // 66.MAP5.W1 5A), int32 -> FP16 (VCVTDQ2PH NP.MAP5.W0 5B).  The merging
  // variants check that the bits above the result are zeroed.
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    float f[16] = {1.5f, -2.7f, 3.0f, 100.9f, -0.5f, 255.1f, 0.0f, -1.0f,
                   70000.0f, 1e-8f, 0.1f, 65519.0f, 65520.0f, 3.14159f, -1e30f, 2.0f};
    memcpy(s.xmm[1].q, f, 64);
    sentinel(s.xmm[0]);
    Evex e; e.mm = 5; e.pp = 1; e.W = false; e.opcode = 0x1D;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VCVTPS2PHX", e, s, 0x2, 0xAAAA);
  }
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    double d[8] = {1.5, -2.7, 3.0, 100.9, -0.5, 255.1, 1e-9, 70000.0};
    memcpy(s.xmm[1].q, d, 64);
    sentinel(s.xmm[0]);
    Evex e; e.mm = 5; e.pp = 1; e.W = true; e.opcode = 0x5A;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VCVTPD2PH", e, s, 0x2, 0xAAAA);
  }
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    int32_t d[16] = {0, 1, -1, 7, -1000, 2048, 2049, 65504, 70000, -70000, 100000, 12345, 3, -3, 4096, 4097};
    memcpy(s.xmm[1].q, d, 64);
    sentinel(s.xmm[0]);
    Evex e; e.mm = 5; e.pp = 0; e.W = false; e.opcode = 0x5B;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VCVTDQ2PH", e, s, 0x2, 0xAAAA);
  }
  // @@END

  // @@BLOCK cvtsh2ss
  // VCVTSH2SS NP.MAP6.W0 13: dst = src1[127:32] : f32(src2 half), under
  // the writemask.
  {
    ArchState s = make_sh_state(3.0f, -2.75f);
    Evex e; e.mm = 6; e.pp = 0; e.W = false; e.opcode = 0x13;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_scalar(tests, cat, "VCVTSH2SS", e, s, 0x6);
  }
  // @@END

  // @@BLOCK fma_packed
  // FMA, EVEX.66.MAP6.W0: dst is an input.  Small integers keep every
  // intermediate exact.
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    gen_ph(s.xmm[0], [](int i) { return float(i % 8 + 1) * ((i % 3 == 2) ? -1.0f : 1.0f); });
    gen_ph(s.xmm[1], [](int i) { return 0.5f * float(i % 16 + 1); });
    gen_ph(s.xmm[2], [](int i) { return float(i % 6 + 2); });
    std::vector<u8> mem = zmm_bytes(s.xmm[2]);
    struct Op { const char *name; u8 op; } ops[] = {
      {"VFMADD132PH", 0x98}, {"VFMADD213PH", 0xA8}, {"VFMADD231PH", 0xB8},
      {"VFMSUB213PH", 0xAA}, {"VFNMADD213PH", 0xAC}, {"VFNMSUB213PH", 0xAE},
      {"VFMADDSUB213PH", 0xA6}, {"VFMSUBADD213PH", 0xA7},
      {"VFMADDSUB132PH", 0x96}, {"VFMSUBADD231PH", 0xB7},
    };
    for (auto &o : ops) {
      Evex e; e.mm = 6; e.pp = 1; e.W = false; e.opcode = o.op;
      e.reg = 0; e.vvvv = 1; e.rm = 2;
      add_evex_rr_tests(tests, cat, o.name, e, s, 0x7, 0xAAAA);
    }
    Evex e; e.mm = 6; e.pp = 1; e.W = false; e.opcode = 0xA8;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rm_tests(tests, cat, "VFMADD213PH", e, s, 0x3, mem, 0xAAAA);
    add_evex_bcast_tests(tests, cat, "VFMADD213PH", e, s, 0x3, half_bytes(3.0f));
  }
  // @@END

  // @@BLOCK fma_scalar
  // Scalar FMA: VFMADD213SH 66.MAP6.W0 A9, VFNMADD213SH AD, VFMSUB231SH BB.
  // DEST[127:16] must stay as it was (not src1's).
  {
    ArchState s = make_sh_state(3.0f, 8.0f);
    uint16_t h = h16(1.5f);
    memcpy(&s.xmm[0].q[0], &h, 2);
    Evex e; e.mm = 6; e.pp = 1; e.W = false; e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.opcode = 0xA9; add_scalar(tests, cat, "VFMADD213SH", e, s, 0x7);
    e.opcode = 0xAD; add_scalar(tests, cat, "VFNMADD213SH", e, s, 0x7);
    e.opcode = 0xBB; add_scalar(tests, cat, "VFMSUB231SH", e, s, 0x7);
  }
  // @@END

  // @@BLOCK getexp
  // VGETEXPPH EVEX.66.MAP6.W0 42 (unary).
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    static const float v1[] = {1.5f, 8.0f, 0.25f, 1000.0f, -2.0f, 0.001f, 3.0f, 65504.0f};
    set_ph(s.xmm[1], v1, 8);
    sentinel(s.xmm[0]);
    Evex e; e.mm = 6; e.pp = 1; e.W = false;
    e.opcode = 0x42; e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VGETEXPPH", e, s, 0x2, 0xAAAA);
  }
  // @@END


  // Map 3 (0F3A) FP16 forms with an immediate, EVEX.NP.MAP3.W0, share
  // these inputs (with NaN, zero, -0 and the largest finite value).
  static const float map3_v1[] = {1.5f, -2.5f, 2.25f, -0.75f, 100.7f, 0.0f, 7.0f, -7.0f,
                                  NAN, 0.001f, 65504.0f, -0.0f, 1.0f, 2.0f, 3.0f, 4.0f};
  static const float map3_v2[] = {1.5f, 2.5f, 2.0f, -0.75f, 100.0f, -0.0f, 8.0f, -7.0f,
                                  1.0f, NAN, 65504.0f, 0.0f, 1.0f, 2.0f, 3.0f, 4.0f};
  auto map3_state = []() {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    set_ph(s.xmm[1], map3_v1, 16);
    set_ph(s.xmm[2], map3_v2, 16);
    sentinel(s.xmm[0]);
    return s;
  };





  // @@BLOCK fpclass
  // VFPCLASSPH k1, xmm1, imm (66): 0x81 = QNaN or +0; 0x66 = +/-inf, +/-zero,
  // denormal.
  {
    ArchState s = map3_state();
    for (u8 imm : {u8(0x81), u8(0x66)}) {
      Evex e; e.mm = 3; e.pp = 0; e.W = false; e.opcode = 0x66;
      e.reg = 1; e.vvvv = 0; e.rm = 1;
      for (int ll = 0; ll <= 2; ll++) {
        e.LL = ll;
        tests.push_back({std::string("VFPCLASSPH imm=") + std::to_string(imm) + " " + vl_name[ll], cat,
                         e.encode_rr_imm(imm), s, FL_ALL, 0, false});
      }
    }
  }
  // @@END

  // @@BLOCK complex_packed
  // Complex FP16: VFMADDCPH F3.MAP6.W0 56, VFCMADDCPH F2.MAP6.W0 56 (packed).
  // dst is an input.
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    gen_ph(s.xmm[0], [](int i) { return 0.5f * float(i % 4); });
    gen_ph(s.xmm[1], [](int i) { return float(i % 8 + 1); });
    gen_ph(s.xmm[2], [](int i) { return float((i * 3) % 5) - 2.0f; });
    Evex e; e.mm = 6; e.W = false; e.opcode = 0x56;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.pp = 2; add_evex_rr_tests(tests, cat, "VFMADDCPH", e, s, 0x7, 0xAAAA);
    e.pp = 3; add_evex_rr_tests(tests, cat, "VFCMADDCPH", e, s, 0x7, 0xAAAA);
  }
  // @@END

  // @@BLOCK complex_scalar
  // Scalar complex FP16: VFMADDCSH F3.MAP6.W0 57, VFCMADDCSH F2.MAP6.W0 57.
  // The 32-bit pair is under the writemask.
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    gen_ph(s.xmm[0], [](int i) { return 0.5f * float(i % 4); });
    gen_ph(s.xmm[1], [](int i) { return float(i % 8 + 1); });
    gen_ph(s.xmm[2], [](int i) { return float((i * 3) % 5) - 2.0f; });
    s.xmm[1].q[1] = 0xBBBBBBBBCCCCCCCCULL;
    Evex e; e.mm = 6; e.W = false; e.opcode = 0x57;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.pp = 2; add_scalar(tests, cat, "VFMADDCSH", e, s, 0x7);
    e.pp = 3; add_scalar(tests, cat, "VFCMADDCSH", e, s, 0x7);
  }
  // @@END
}

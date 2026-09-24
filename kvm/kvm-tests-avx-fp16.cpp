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

  // @@BLOCK conv_ph2w
  // FP16 -> int16 (VCVTPH2W 66.MAP5.W0 7D, VCVTTPH2W 66.MAP5.W0 7C) and
  // FP16 -> uint16 (VCVTPH2UW NP.MAP5.W0 7D, VCVTTPH2UW NP.MAP5.W0 7C).
  // The input set has 65504 (does not fit int16) and negative values (do
  // not fit uint16), which must give the integer indefinite values.
  {
    static const float halves[] = {1.5f, -2.75f, 1000.0f, 0.1f, 65504.0f, -0.0f,
                                   0.00006f, 3.140625f, -7.0f, 0.333f, 12.0f, -1e-5f,
                                   255.0f, 256.5f, -100.25f, 2.0f};
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    set_ph(s.xmm[1], halves, 16);
    sentinel(s.xmm[0]);
    struct Cv { const char *name; int pp; u8 op; } to_int[] = {
      {"VCVTPH2W", 1, 0x7D}, {"VCVTTPH2W", 1, 0x7C},
      {"VCVTPH2UW", 0, 0x7D}, {"VCVTTPH2UW", 0, 0x7C},
    };
    for (auto &c : to_int) {
      Evex e; e.mm = 5; e.pp = c.pp; e.W = false; e.opcode = c.op;
      e.reg = 0; e.vvvv = 0; e.rm = 1;
      add_evex_rr_tests(tests, cat, c.name, e, s, 0x2, 0xAAAA);
    }
    // Non-negative inputs for the unsigned conversions, so that no lane is
    // out of range.
    ArchState su = s;
    gen_ph(su.xmm[1], [](int i) { return float(i * 37 % 300) + 0.5f * float(i % 3); });
    {
      Evex e; e.mm = 5; e.pp = 0; e.W = false; e.reg = 0; e.vvvv = 0; e.rm = 1;
      e.opcode = 0x7D; add_evex_rr_tests(tests, cat, "VCVTPH2UW in range", e, su, 0x2, 0xAAAA);
      e.opcode = 0x7C; add_evex_rr_tests(tests, cat, "VCVTTPH2UW in range", e, su, 0x2, 0xAAAA);
    }
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

  // @@BLOCK scalef
  // VSCALEFPH EVEX.66.MAP6.W0 2C (binary): src1 * 2^floor(src2), with a
  // negative non-integer scale among the inputs.
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    static const float v1[] = {1.5f, 8.0f, 0.25f, 1000.0f, -2.0f, 0.001f, 3.0f, 65504.0f};
    static const float v2[] = {1.0f, 2.0f, -1.0f, 0.5f, 3.0f, -2.5f, 0.0f, 4.0f};
    set_ph(s.xmm[1], v1, 8);
    set_ph(s.xmm[2], v2, 8);
    sentinel(s.xmm[0]);
    Evex e; e.mm = 6; e.pp = 1; e.W = false;
    e.opcode = 0x2C; e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VSCALEFPH", e, s, 0x6, 0xAAAA);
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

  // @@BLOCK vcmpph
  // VCMPPH k1, xmm1, xmm2, imm (C2): predicates EQ_OQ 0, LT_OS 1, UNORD_Q 3,
  // NEQ_UQ 4, NLT_US 5, GT_OQ 0x1E; the NaN lanes exercise the ordered
  // and unordered variants.
  {
    ArchState s = map3_state();
    struct P { const char *name; u8 imm; } preds[] = {
      {"eq", 0x00}, {"lt", 0x01}, {"unord", 0x03}, {"neq", 0x04}, {"nlt", 0x05}, {"gt", 0x1E},
    };
    for (auto &p : preds) {
      Evex e; e.mm = 3; e.pp = 0; e.W = false; e.opcode = 0xC2;
      e.reg = 1; e.vvvv = 1; e.rm = 2;
      for (int ll = 0; ll <= 2; ll++) {
        e.LL = ll;
        tests.push_back({std::string("VCMPPH k1 ") + p.name + " " + vl_name[ll], cat,
                         e.encode_rr_imm(p.imm), s, FL_ALL, 0, false});
      }
    }
  }
  // @@END

  // @@BLOCK rndscale
  // VRNDSCALEPH (08) with the four rounding modes and a scale of 2^2.
  {
    ArchState s = map3_state();
    struct R { const char *name; u8 imm; } rnd[] = {
      {"nearest", 0x00}, {"down", 0x01}, {"up", 0x02}, {"trunc", 0x03}, {"nearest/4", 0x20},
    };
    for (auto &r : rnd) {
      Evex e; e.mm = 3; e.pp = 0; e.W = false; e.opcode = 0x08;
      e.reg = 0; e.vvvv = 0; e.rm = 1;
      for (int ll = 0; ll <= 2; ll++) {
        e.LL = ll;
        tests.push_back({std::string("VRNDSCALEPH ") + r.name + " " + vl_name[ll], cat,
                         e.encode_rr_imm(r.imm), s, FL_ALL, 0, false});
      }
    }
  }
  // @@END

  // @@BLOCK reduce
  // VREDUCEPH (56) imm 0 (fraction) and 0x10 (fraction at scale 2).
  {
    ArchState s = map3_state();
    for (u8 imm : {u8(0x00), u8(0x10)}) {
      Evex e; e.mm = 3; e.pp = 0; e.W = false; e.opcode = 0x56;
      e.reg = 0; e.vvvv = 0; e.rm = 1;
      for (int ll = 0; ll <= 2; ll++) {
        e.LL = ll;
        tests.push_back({std::string("VREDUCEPH imm=") + std::to_string(imm) + " " + vl_name[ll], cat,
                         e.encode_rr_imm(imm), s, FL_ALL, 0, false});
      }
    }
  }
  // @@END

  // @@BLOCK getmant
  // VGETMANTPH (26) imm 0 (interval [1,2)) and 1 ([1/2,2)); the inputs
  // include zero and NaN.
  {
    ArchState s = map3_state();
    for (u8 imm : {u8(0x00), u8(0x01)}) {
      Evex e; e.mm = 3; e.pp = 0; e.W = false; e.opcode = 0x26;
      e.reg = 0; e.vvvv = 0; e.rm = 1;
      for (int ll = 0; ll <= 2; ll++) {
        e.LL = ll;
        tests.push_back({std::string("VGETMANTPH imm=") + std::to_string(imm) + " " + vl_name[ll], cat,
                         e.encode_rr_imm(imm), s, FL_ALL, 0, false});
      }
    }
  }
  // @@END

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
      // VFPCLASSSH k1, xmm1, imm (67): the low element only, from a
      // register and from m16.
      Evex sh; sh.mm = 3; sh.pp = 0; sh.W = false; sh.opcode = 0x67; sh.LL = 0;
      sh.reg = 1; sh.vvvv = 0; sh.rm = 1;
      tests.push_back({std::string("VFPCLASSSH imm=") + std::to_string(imm), cat,
                       sh.encode_rr_imm(imm), with_vector_inputs(s, 0x2), FL_ALL, 0, false});
      sh.rm = 7;
      TestCase tm = {std::string("VFPCLASSSH imm=") + std::to_string(imm) + " [m16]", cat,
                     sh.encode_rm_mem_imm(imm), with_vector_inputs(s, 0), FL_ALL, 0, false};
      tm.init_data = half_bytes(0.0f);
      tests.push_back(std::move(tm));
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

  // @@BLOCK cvt_gpr_to_sh
  // Integer GPR to scalar FP16: VCVTSI2SH F3.MAP5 2A (signed) and VCVTUSI2SH
  // F3.MAP5 7B (unsigned); W0 reads a 32-bit source, W1 a 64-bit one, from
  // EBX/RBX or [rdi].  DEST[127:16] comes from src1.  Integers below 2^24
  // are exact in the model's float intermediate, so it rounds once; larger
  // ones overflow binary16 to infinity either way.  2051 lies halfway
  // between 2050 and 2052, so {rd-sae}, {ru-sae} and {rz-sae} on the
  // register form distinguish the embedded rounding control from MXCSR.
  {
    struct In { const char *name; u64 v; bool is_signed; } ins[] = {
      {"100", 100, true}, {"-7", u64(-7), true}, {"2051", 2051, true},
      {"65519", 65519, true}, {"65520", 65520, true}, {"-70000", u64(-70000), true},
      {"0", 0, true}, {"-2^40", u64(-(1LL << 40)), true},
      {"100", 100, false}, {"4294967295", 0xFFFFFFFFULL, false}, {"65504", 65504, false},
      {"3000000000", 3000000000ULL, false}, {"2^40", 1ULL << 40, false}, {"7", 7, false},
    };
    for (auto &in : ins) {
      for (bool w : {false, true}) {
        ArchState s = with_vector_inputs(make_sh_state(3.0f, 0.0f), 0x2);
        // A 32-bit source reads EBX only; its upper half follows the background.
        s.rbx = w ? in.v : (initial_register_fill & ~0xFFFFFFFFULL) | (in.v & 0xFFFFFFFF);
        Evex e; e.mm = 5; e.pp = 2; e.W = w; e.LL = 0;
        e.opcode = in.is_signed ? 0x2A : 0x7B;
        e.reg = 0; e.vvvv = 1; e.rm = 3;  // rbx
        std::string mn = in.is_signed ? "VCVTSI2SH" : "VCVTUSI2SH";
        std::string src = w ? " rbx=" : " ebx=";
        tests.push_back({mn + src + in.name, cat, e.encode_rr(),
                         with_gpr_inputs(s, {&ArchState::rbx}), FL_ALL, 0x3, false});
        // Memory source: the same integer at [rdi].
        ArchState m = with_gpr_inputs(s, {&ArchState::rdi});
        std::vector<u8> mem(64, 0xEE);
        memcpy(mem.data(), &in.v, w ? 8 : 4);
        TestCase tc = {mn + (w ? " [m64]=" : " [m32]=") + in.name, cat, e.encode_rm_mem(), m, FL_ALL, 0x3, false};
        tc.init_data = mem;
        tests.push_back(std::move(tc));
      }
    }
    struct Rc { const char *name; int ll; u64 v; } rcs[] = {
      {"{rn-sae}", 0, 2051}, {"{rd-sae}", 1, 2051}, {"{ru-sae}", 2, 2051}, {"{rz-sae}", 3, u64(-2051)},
    };
    for (auto &rc : rcs) {
      ArchState s = with_vector_inputs(make_sh_state(3.0f, 0.0f), 0x2);
      s.rbx = (initial_register_fill & ~0xFFFFFFFFULL) | (rc.v & 0xFFFFFFFF);
      Evex e; e.mm = 5; e.pp = 2; e.W = false; e.b = true; e.LL = rc.ll;
      e.reg = 0; e.vvvv = 1; e.rm = 3;
      s = with_gpr_inputs(s, {&ArchState::rbx});
      e.opcode = 0x2A;
      tests.push_back({std::string("VCVTSI2SH ") + rc.name + " ebx=" + std::to_string(int64_t(int32_t(rc.v))),
                       cat, e.encode_rr(), s, FL_ALL, 0x3, false});
      e.opcode = 0x7B;
      tests.push_back({std::string("VCVTUSI2SH ") + rc.name + " ebx=" + std::to_string(uint32_t(rc.v)),
                       cat, e.encode_rr(), s, FL_ALL, 0x3, false});
    }
  }
  // @@END

  // @@BLOCK cvt_sh_to_gpr
  // Scalar FP16 to integer GPR, F3.MAP5: VCVTSH2SI 2D and VCVTTSH2SI 2C
  // (signed), VCVTSH2USI 79 and VCVTTSH2USI 78 (unsigned); W0 writes a
  // zero-extended 32-bit result, W1 a 64-bit one.  Out-of-range values and
  // NaN give the integer indefinite.  2.5 and 3.5 are ties for the rounding
  // forms; {rd-sae} and {ru-sae} on 2.75 check the embedded rounding
  // control.
  {
    struct In { const char *name; float v; } ins[] = {
      {"2.75", 2.75f}, {"-2.5", -2.5f}, {"3.5", 3.5f}, {"0.5", 0.5f}, {"-0.0", -0.0f},
      {"65504", 65504.0f}, {"-7", -7.0f}, {"nan", NAN}, {"-inf", -INFINITY}, {"0.001", 0.001f},
    };
    struct Op { const char *name; u8 op; } ops[] = {
      {"VCVTSH2SI", 0x2D}, {"VCVTTSH2SI", 0x2C}, {"VCVTSH2USI", 0x79}, {"VCVTTSH2USI", 0x78},
    };
    for (auto &o : ops) {
      for (auto &in : ins) {
        for (bool w : {false, true}) {
          ArchState s;
          s.rflags = 0x2;
          s.rdi = DATA_ADDR;
          s.xmm[1].q[0] = 0xAAAAAAAAAAAA0000ULL;
          uint16_t h = h16(in.v); memcpy(&s.xmm[1].q[0], &h, 2);
          s.xmm[1].q[1] = 0xBBBBBBBBCCCCCCCCULL;
          Evex e; e.mm = 5; e.pp = 2; e.W = w; e.LL = 0; e.opcode = o.op;
          e.reg = 3; e.vvvv = 0; e.rm = 1;  // rbx <- xmm1
          std::string dst = w ? " rbx, " : " ebx, ";
          tests.push_back({std::string(o.name) + dst + in.name, cat, e.encode_rr(),
                           with_gpr_inputs(s, {}), FL_ALL, 0, false});
        }
      }
      // Memory source [rdi] (m16), 32-bit destination.
      ArchState m;
      m.rflags = 0x2;
      m.rdi = DATA_ADDR;
      Evex e; e.mm = 5; e.pp = 2; e.W = false; e.LL = 0; e.opcode = o.op;
      e.reg = 3; e.vvvv = 0; e.rm = 7;
      TestCase tc = {std::string(o.name) + " ebx, [m16]=2.75", cat, e.encode_rm_mem(), m, FL_ALL, 0, false};
      tc.init_data = half_bytes(2.75f);
      tests.push_back(std::move(tc));
    }
    struct Rc { const char *name; int ll; } rcs[] = {
      {"{rn-sae}", 0}, {"{rd-sae}", 1}, {"{ru-sae}", 2}, {"{rz-sae}", 3},
    };
    for (auto &rc : rcs) {
      for (float v : {2.75f, -2.75f}) {
        ArchState s;
        s.rflags = 0x2;
        s.rdi = DATA_ADDR;
        uint16_t h = h16(v); memcpy(&s.xmm[1].q[0], &h, 2);
        Evex e; e.mm = 5; e.pp = 2; e.W = false; e.b = true; e.LL = rc.ll;
        e.reg = 3; e.vvvv = 0; e.rm = 1;
        e.opcode = 0x2D;
        tests.push_back({std::string("VCVTSH2SI ") + rc.name + " ebx, " + std::to_string(v), cat,
                         e.encode_rr(), with_gpr_inputs(s, {}), FL_ALL, 0, false});
        if (v > 0) {
          e.opcode = 0x79;
          tests.push_back({std::string("VCVTSH2USI ") + rc.name + " ebx, " + std::to_string(v), cat,
                           e.encode_rr(), with_gpr_inputs(s, {}), FL_ALL, 0, false});
        }
      }
    }
  }
  // @@END

  // @@BLOCK cvt_ph_unsigned_quad
  // Packed FP16 to 32/64-bit integers, MAP5: VCVTTPH2UDQ NP 78, VCVTPH2UDQ
  // NP 79, VCVTTPH2UQQ 66 78, VCVTPH2UQQ 66 79, VCVTTPH2QQ 66 7A, VCVTPH2QQ
  // 66 7B.  The source is half (dword results) or a quarter (qword results)
  // of the destination width.  The inputs hold a negative value and a NaN
  // in the low lanes so every vector length sees an indefinite result, and
  // ties (2.5, 3.5) for the rounding forms.
  {
    static const float halves[] = {2.75f, -7.0f, NAN, 3.5f, 1000.0f, 2.5f, 65504.0f, -0.0f,
                                   0.5f, 255.0f, 256.5f, 0.001f, 12.0f, 100.25f, 4096.0f, 7.0f};
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    set_ph(s.xmm[1], halves, 16);
    sentinel(s.xmm[0]);
    struct Cv { const char *name; int pp; u8 op; bool er; } to_int[] = {
      {"VCVTTPH2UDQ", 0, 0x78, false}, {"VCVTPH2UDQ", 0, 0x79, true},
      {"VCVTTPH2UQQ", 1, 0x78, false}, {"VCVTPH2UQQ", 1, 0x79, true},
      {"VCVTTPH2QQ", 1, 0x7A, false}, {"VCVTPH2QQ", 1, 0x7B, true},
    };
    for (auto &c : to_int) {
      Evex e; e.mm = 5; e.pp = c.pp; e.W = false; e.opcode = c.op;
      e.reg = 0; e.vvvv = 0; e.rm = 1;
      add_evex_rr_tests(tests, cat, c.name, e, s, 0x2, 0xAAAA);
      add_evex_rm_tests(tests, cat, c.name, e, s, 0x0, zmm_bytes(s.xmm[1]));
      if (c.er) {
        // {rd-sae} and {ru-sae}: EVEX.b with a register source selects the
        // rounding and the 512-bit length.
        e.b = true;
        e.LL = 1;
        tests.push_back({std::string(c.name) + " zmm {rd-sae}", cat, e.encode_rr(),
                         with_vector_inputs(s, 0x2), FL_ALL, 0, false});
        e.LL = 2;
        tests.push_back({std::string(c.name) + " zmm {ru-sae}", cat, e.encode_rr(),
                         with_vector_inputs(s, 0x2), FL_ALL, 0, false});
      }
    }
  }
  // Unsigned 32/64-bit integers to packed FP16: VCVTUDQ2PH F2.MAP5.W0 7A
  // and VCVTUQQ2PH F2.MAP5.W1 7A.  The result is half or a quarter of the
  // source width; the merging variants check the zeroed upper bits.  2049
  // and 4097 are ties in binary16; values above 65520 overflow.
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    uint32_t d[16] = {0, 1, 7, 1000, 2048, 2049, 65504, 65520, 70000, 0xFFFFFFFFu,
                      12345, 3, 4096, 4097, 100000, 2};
    memcpy(s.xmm[1].q, d, 64);
    sentinel(s.xmm[0]);
    Evex e; e.mm = 5; e.pp = 3; e.W = false; e.opcode = 0x7A;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VCVTUDQ2PH", e, s, 0x2, 0xAAAA);
    add_evex_rm_tests(tests, cat, "VCVTUDQ2PH", e, s, 0x0, zmm_bytes(s.xmm[1]));
    e.b = true; e.LL = 1;
    tests.push_back({"VCVTUDQ2PH zmm {rd-sae}", cat, e.encode_rr(), with_vector_inputs(s, 0x2), FL_ALL, 0, false});
    e.LL = 2;
    tests.push_back({"VCVTUDQ2PH zmm {ru-sae}", cat, e.encode_rr(), with_vector_inputs(s, 0x2), FL_ALL, 0, false});
  }
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    uint64_t q[8] = {0, 1, 7, 65504, 1ULL << 40, ~0ULL, 2049, 3};
    memcpy(s.xmm[1].q, q, 64);
    sentinel(s.xmm[0]);
    Evex e; e.mm = 5; e.pp = 3; e.W = true; e.opcode = 0x7A;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VCVTUQQ2PH", e, s, 0x2, 0xAAAA);
    add_evex_rm_tests(tests, cat, "VCVTUQQ2PH", e, s, 0x0, zmm_bytes(s.xmm[1]));
    e.b = true; e.LL = 1;
    tests.push_back({"VCVTUQQ2PH zmm {rd-sae}", cat, e.encode_rr(), with_vector_inputs(s, 0x2), FL_ALL, 0, false});
  }
  // @@END

  // @@BLOCK fma_packed_rest
  // The remaining packed FMA forms, EVEX.66.MAP6.W0: VFMSUB132PH 9A,
  // VFMSUB231PH BA, VFNMADD132PH 9C, VFNMADD231PH BC, VFNMSUB132PH 9E,
  // VFNMSUB231PH BE, VFMSUBADD132PH 97, VFMADDSUB231PH B6.  Same inputs as
  // the first FMA block: small integers and halves, every intermediate
  // exact.
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    gen_ph(s.xmm[0], [](int i) { return float(i % 8 + 1) * ((i % 3 == 2) ? -1.0f : 1.0f); });
    gen_ph(s.xmm[1], [](int i) { return 0.5f * float(i % 16 + 1); });
    gen_ph(s.xmm[2], [](int i) { return float(i % 6 + 2); });
    std::vector<u8> mem = zmm_bytes(s.xmm[2]);
    struct Op { const char *name; u8 op; } ops[] = {
      {"VFMSUB132PH", 0x9A}, {"VFMSUB231PH", 0xBA},
      {"VFNMADD132PH", 0x9C}, {"VFNMADD231PH", 0xBC},
      {"VFNMSUB132PH", 0x9E}, {"VFNMSUB231PH", 0xBE},
      {"VFMSUBADD132PH", 0x97}, {"VFMADDSUB231PH", 0xB6},
    };
    for (auto &o : ops) {
      Evex e; e.mm = 6; e.pp = 1; e.W = false; e.opcode = o.op;
      e.reg = 0; e.vvvv = 1; e.rm = 2;
      add_evex_rr_tests(tests, cat, o.name, e, s, 0x7, 0xAAAA);
      add_evex_rm_tests(tests, cat, o.name, e, s, 0x3, mem);
    }
  }
  // @@END

  // @@BLOCK fma_scalar_rest
  // The remaining scalar FMA forms, EVEX.LIG.66.MAP6.W0: VFMADD132SH 99,
  // VFMSUB132SH 9B, VFNMADD132SH 9D, VFNMSUB132SH 9F, VFMSUB213SH AB,
  // VFNMSUB213SH AF, VFMADD231SH B9, VFNMADD231SH BD, VFNMSUB231SH BF.
  // dst = 1.5 under its sentinel, src1 = 3.0, src2 = 8.0; DEST[127:16]
  // must stay as it was.
  {
    ArchState s = make_sh_state(3.0f, 8.0f);
    uint16_t h = h16(1.5f);
    memcpy(&s.xmm[0].q[0], &h, 2);
    struct Op { const char *name; u8 op; } ops[] = {
      {"VFMADD132SH", 0x99}, {"VFMSUB132SH", 0x9B}, {"VFNMADD132SH", 0x9D},
      {"VFNMSUB132SH", 0x9F}, {"VFMSUB213SH", 0xAB}, {"VFNMSUB213SH", 0xAF},
      {"VFMADD231SH", 0xB9}, {"VFNMADD231SH", 0xBD}, {"VFNMSUB231SH", 0xBF},
    };
    for (auto &o : ops) {
      Evex e; e.mm = 6; e.pp = 1; e.W = false; e.reg = 0; e.vvvv = 1; e.rm = 2;
      e.opcode = o.op;
      add_scalar(tests, cat, o.name, e, s, 0x7);
    }
    // Memory source for one 132 form and one 231 form (m16 at [rdi]).
    ArchState m = with_vector_inputs(s, 0x3);
    for (auto &o : {Op{"VFMADD132SH", 0x99}, Op{"VFNMSUB231SH", 0xBF}}) {
      Evex e; e.mm = 6; e.pp = 1; e.W = false; e.LL = 0; e.reg = 0; e.vvvv = 1; e.rm = 7;
      e.opcode = o.op;
      TestCase tc = {std::string(o.name) + " xmm, xmm, [m16]", cat, e.encode_rm_mem(), m, FL_ALL, 0x7, false};
      tc.init_data = half_bytes(8.0f);
      tests.push_back(std::move(tc));
    }
  }
  // @@END

  // @@BLOCK scalef_getexp_sh
  // VSCALEFSH 66.MAP6.W0 2D: src1 * 2^floor(src2), with a negative
  // non-integer scale; VGETEXPSH 66.MAP6.W0 43: floor(log2 |src2|), with
  // zero (-inf) and a denormal-range input.  DEST[127:16] comes from src1.
  {
    Evex e; e.mm = 6; e.pp = 1; e.W = false; e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.opcode = 0x2D;
    add_scalar(tests, cat, "VSCALEFSH 3*2^2", e, make_sh_state(3.0f, 2.0f), 0x6);
    add_scalar(tests, cat, "VSCALEFSH 3*2^floor(-2.5)", e, make_sh_state(3.0f, -2.5f), 0x6);
    add_scalar(tests, cat, "VSCALEFSH 65504*2^1", e, make_sh_state(65504.0f, 1.0f), 0x6);
    e.opcode = 0x43;
    add_scalar(tests, cat, "VGETEXPSH 8", e, make_sh_state(3.0f, 8.0f), 0x6);
    add_scalar(tests, cat, "VGETEXPSH 0.001", e, make_sh_state(3.0f, 0.001f), 0x6);
    add_scalar(tests, cat, "VGETEXPSH 0", e, make_sh_state(3.0f, 0.0f), 0x6);
    add_scalar(tests, cat, "VGETEXPSH -1.5", e, make_sh_state(3.0f, -1.5f), 0x6);
    add_scalar(tests, cat, "VGETEXPSH 6e-5 (denormal)", e, make_sh_state(3.0f, 0.00003f), 0x6);
  }
  // @@END

  // @@BLOCK rcp_rsqrt
  // VRCPPH 66.MAP6.W0 4C, VRSQRTPH 4E (packed) and VRCPSH 4D, VRSQRTSH 4F
  // (scalar; DEST[127:16] from src1).  The SDM bounds the relative error
  // by 2^-11 + 2^-14, so computed elements are compared under that
  // tolerance; elements that are exact by definition (zero, infinity) or
  // copied must match exactly.  The reciprocal inputs include negative
  // values; the reciprocal square root inputs are positive.
  {
    static const float rcp_in[] = {1.0f, 3.0f, -0.75f, 1000.0f, 0.125f, -7.0f, 65504.0f, 0.001f,
                                   2.0f, -1.5f, 100.0f, 0.3f, 12.0f, -256.0f, 5.0f, 9.0f};
    static const float rsq_in[] = {1.0f, 3.0f, 0.75f, 1000.0f, 0.125f, 7.0f, 65504.0f, 0.001f,
                                   4.0f, 1.5f, 100.0f, 0.3f, 12.0f, 256.0f, 5.0f, 9.0f};
    const double tol = 6.2e-4;  // 2^-11 + 2^-14 = 5.5e-4, with slack
    struct Op { const char *name; u8 op; const float *in; } ops[] = {
      {"VRCPPH", 0x4C, rcp_in}, {"VRSQRTPH", 0x4E, rsq_in},
    };
    for (auto &o : ops) {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      set_ph(s.xmm[1], o.in, 16);
      sentinel(s.xmm[0]);
      s = with_vector_inputs(s, 0x2);
      for (int ll = 0; ll <= 2; ll++) {
        Evex e; e.mm = 6; e.pp = 1; e.W = false; e.opcode = o.op; e.LL = ll;
        e.reg = 0; e.vvvv = 0; e.rm = 1;
        TestCase tc = {std::string(o.name) + " " + vl_name[ll], cat, e.encode_rr(), s, FL_ALL, 0, false};
        tc.approx_rel_tol = tol;
        tc.approx_elem_bits = 16;
        tc.approx_result_bits = 128 << ll;
        tc.approx_reg = 0;
        tests.push_back(std::move(tc));
        e.rm = 7;
        TestCase tm = {std::string(o.name) + " " + vl_name[ll] + " [mem]", cat, e.encode_rm_mem(),
                       with_vector_inputs(s, 0), FL_ALL, 0, false};
        tm.init_data = zmm_bytes(s.xmm[1]);
        tm.approx_rel_tol = tol;
        tm.approx_elem_bits = 16;
        tm.approx_result_bits = 128 << ll;
        tm.approx_reg = 0;
        tests.push_back(std::move(tm));
      }
    }
    // Exact cases: reciprocal of zero and infinity, reciprocal square root
    // of zero and of a negative (QNaN indefinite).
    {
      static const float specials[] = {0.0f, -0.0f, INFINITY, -INFINITY, 0.0f, -0.0f, INFINITY, -4.0f};
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      set_ph(s.xmm[1], specials, 8);
      sentinel(s.xmm[0]);
      s = with_vector_inputs(s, 0x2);
      Evex e; e.mm = 6; e.pp = 1; e.W = false; e.LL = 0; e.reg = 0; e.vvvv = 0; e.rm = 1;
      e.opcode = 0x4C;
      tests.push_back({"VRCPPH xmm specials", cat, e.encode_rr(), s, FL_ALL, 0, false});
      e.opcode = 0x4E;
      tests.push_back({"VRSQRTPH xmm specials", cat, e.encode_rr(), s, FL_ALL, 0, false});
    }
    struct Sc { const char *name; u8 op; float v; } scalars[] = {
      {"VRCPSH 3", 0x4D, 3.0f}, {"VRCPSH -0.75", 0x4D, -0.75f}, {"VRCPSH 1000", 0x4D, 1000.0f},
      {"VRSQRTSH 3", 0x4F, 3.0f}, {"VRSQRTSH 0.125", 0x4F, 0.125f}, {"VRSQRTSH 1000", 0x4F, 1000.0f},
    };
    for (auto &sc : scalars) {
      ArchState s = with_vector_inputs(make_sh_state(3.0f, sc.v), 0x6);
      Evex e; e.mm = 6; e.pp = 1; e.W = false; e.LL = 0; e.opcode = sc.op;
      e.reg = 0; e.vvvv = 1; e.rm = 2;
      TestCase tc = {sc.name, cat, e.encode_rr(), s, FL_ALL, 0, false};
      tc.approx_rel_tol = tol;
      tc.approx_elem_bits = 16;
      tc.approx_result_bits = 16;
      tc.approx_reg = 0;
      tests.push_back(std::move(tc));
    }
    // Exact scalar cases: reciprocal of +0 (+inf) and of infinity (+0).
    {
      Evex e; e.mm = 6; e.pp = 1; e.W = false; e.LL = 0; e.opcode = 0x4D;
      e.reg = 0; e.vvvv = 1; e.rm = 2;
      tests.push_back({"VRCPSH 0", cat, e.encode_rr(), with_vector_inputs(make_sh_state(3.0f, 0.0f), 0x6), FL_ALL, 0, false});
      tests.push_back({"VRCPSH inf", cat, e.encode_rr(), with_vector_inputs(make_sh_state(3.0f, INFINITY), 0x6), FL_ALL, 0, false});
      e.opcode = 0x4F;
      tests.push_back({"VRSQRTSH -4", cat, e.encode_rr(), with_vector_inputs(make_sh_state(3.0f, -4.0f), 0x6), FL_ALL, 0, false});
    }
  }
  // @@END

  // @@BLOCK complex_mul
  // Complex FP16 multiply: VFMULCPH F3.MAP6.W0 D6, VFCMULCPH F2.MAP6.W0 D6
  // (packed; dst is not an input) and VFMULCSH F3 D7, VFCMULCSH F2 D7
  // (scalar; the 32-bit pair under the writemask, DEST[127:32] from
  // src1).  Small integer parts keep every product and sum exact.
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    gen_ph(s.xmm[1], [](int i) { return float(i % 8 + 1) * ((i % 5 == 3) ? -1.0f : 1.0f); });
    gen_ph(s.xmm[2], [](int i) { return float((i * 3) % 5) - 2.0f; });
    sentinel(s.xmm[0]);
    std::vector<u8> mem = zmm_bytes(s.xmm[2]);
    Evex e; e.mm = 6; e.W = false; e.opcode = 0xD6;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.pp = 2;
    add_evex_rr_tests(tests, cat, "VFMULCPH", e, s, 0x6, 0xAAAA);
    add_evex_rm_tests(tests, cat, "VFMULCPH", e, s, 0x2, mem);
    e.pp = 3;
    add_evex_rr_tests(tests, cat, "VFCMULCPH", e, s, 0x6, 0xAAAA);
    add_evex_rm_tests(tests, cat, "VFCMULCPH", e, s, 0x2, mem);
    e.opcode = 0xD7;
    ArchState sc = s;
    sc.xmm[1].q[1] = 0xBBBBBBBBCCCCCCCCULL;
    e.pp = 2; add_scalar(tests, cat, "VFMULCSH", e, sc, 0x6);
    e.pp = 3; add_scalar(tests, cat, "VFCMULCSH", e, sc, 0x6);
  }
  // @@END
}

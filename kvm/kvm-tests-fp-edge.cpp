#include "kvm-harness.h"

void add_fp_edge_tests(std::vector<TestCase> &tests) {
  std::string cat;

  auto add_xmm = [&](const std::string &name, std::vector<u8> code, ArchState init,
                      u32 xmm_cmp) {
    tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
  };

  // =====================================================================
  // AVX Edge Cases — VEX-encoded FP/integer boundary values
  //
  // Comprehensive edge-case testing for VEX-encoded instructions:
  // NaN propagation, Inf arithmetic, denormals, signed zeros,
  // 256-bit operations, upper-128 clearing, conversion edges.
  // =====================================================================
  cat = "AVX Edge";

  // --- A. VEX FP boundary-value matrix (f32) ---
  {
    const u32 POS_ZERO  = 0x00000000;
    const u32 NEG_ZERO  = 0x80000000;
    const u32 POS_INF   = 0x7F800000;
    const u32 NEG_INF   = 0xFF800000;
    const u32 QNAN      = 0x7FC00000;
    const u32 F32_SNAN  = u32(0x7F800001);
    const u32 QNAN2     = 0x7FC00042;
    const u32 DENORM    = 0x00000001;
    const u32 DENORM2   = 0x007FFFFF;
    const u32 NEG_DENORM = 0x80000001;
    const u32 ONE       = 0x3F800000;
    const u32 NEG_ONE   = 0xBF800000;
    const u32 MAX_NORM  = 0x7F7FFFFF;

    struct FPPair { u32 a; u32 b; const char *desc; };
    FPPair pairs[] = {
      {POS_ZERO, NEG_ZERO, "pz_nz"},
      {NEG_ZERO, POS_ZERO, "nz_pz"},
      {POS_INF, ONE, "pinf_1"},
      {NEG_INF, ONE, "ninf_1"},
      {POS_INF, NEG_INF, "pinf_ninf"},
      {POS_INF, POS_INF, "pinf_pinf"},
      {QNAN, ONE, "qnan_1"},
      {ONE, QNAN, "1_qnan"},
      {QNAN, QNAN2, "qnan_qnan2"},
      {F32_SNAN, ONE, "snan_1"},
      {ONE, F32_SNAN, "1_snan"},
      {F32_SNAN, QNAN, "snan_qnan"},
      {DENORM, ONE, "denorm_1"},
      {ONE, DENORM, "1_denorm"},
      {DENORM, DENORM, "denorm_denorm"},
      {NEG_DENORM, ONE, "ndenorm_1"},
      {DENORM2, DENORM2, "maxdenorm2"},
      {MAX_NORM, ONE, "maxnorm_1"},
      {MAX_NORM, MAX_NORM, "maxnorm2"},
      {NEG_ONE, POS_ZERO, "n1_pz"},
      {POS_ZERO, POS_ZERO, "pz_pz"},
      {NEG_ZERO, NEG_ZERO, "nz_nz"},
      {POS_INF, QNAN, "pinf_qnan"},
      {QNAN, POS_INF, "qnan_pinf"},
    };
    int npairs = sizeof(pairs) / sizeof(pairs[0]);

    // VADDPS xmm0, xmm1, xmm2: C5 F0 58 C2
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(pairs[i].a, pairs[i].a, pairs[i].a, pairs[i].a);
      s.xmm[2] = xmm_from_u32(pairs[i].b, pairs[i].b, pairs[i].b, pairs[i].b);
      std::string n = std::format("vaddps {}", pairs[i].desc);
      add_xmm(n, {0xC5, 0xF0, 0x58, 0xC2}, s, 0x7);
    }

    // VSUBPS xmm0, xmm1, xmm2: C5 F0 5C C2
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(pairs[i].a, pairs[i].a, pairs[i].a, pairs[i].a);
      s.xmm[2] = xmm_from_u32(pairs[i].b, pairs[i].b, pairs[i].b, pairs[i].b);
      std::string n = std::format("vsubps {}", pairs[i].desc);
      add_xmm(n, {0xC5, 0xF0, 0x5C, 0xC2}, s, 0x7);
    }

    // VMULPS xmm0, xmm1, xmm2: C5 F0 59 C2
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(pairs[i].a, pairs[i].a, pairs[i].a, pairs[i].a);
      s.xmm[2] = xmm_from_u32(pairs[i].b, pairs[i].b, pairs[i].b, pairs[i].b);
      std::string n = std::format("vmulps {}", pairs[i].desc);
      add_xmm(n, {0xC5, 0xF0, 0x59, 0xC2}, s, 0x7);
    }

    // VDIVPS xmm0, xmm1, xmm2: C5 F0 5E C2
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(pairs[i].a, pairs[i].a, pairs[i].a, pairs[i].a);
      s.xmm[2] = xmm_from_u32(pairs[i].b, pairs[i].b, pairs[i].b, pairs[i].b);
      std::string n = std::format("vdivps {}", pairs[i].desc);
      add_xmm(n, {0xC5, 0xF0, 0x5E, 0xC2}, s, 0x7);
    }

    // VMINPS xmm0, xmm1, xmm2: C5 F0 5D C2
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(pairs[i].a, pairs[i].a, pairs[i].a, pairs[i].a);
      s.xmm[2] = xmm_from_u32(pairs[i].b, pairs[i].b, pairs[i].b, pairs[i].b);
      std::string n = std::format("vminps {}", pairs[i].desc);
      add_xmm(n, {0xC5, 0xF0, 0x5D, 0xC2}, s, 0x7);
    }

    // VMAXPS xmm0, xmm1, xmm2: C5 F0 5F C2
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(pairs[i].a, pairs[i].a, pairs[i].a, pairs[i].a);
      s.xmm[2] = xmm_from_u32(pairs[i].b, pairs[i].b, pairs[i].b, pairs[i].b);
      std::string n = std::format("vmaxps {}", pairs[i].desc);
      add_xmm(n, {0xC5, 0xF0, 0x5F, 0xC2}, s, 0x7);
    }

    // VCMPPS with all 8 predicates: C5 F0 C2 C2 imm8
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(pairs[i].a, pairs[i].a, pairs[i].a, pairs[i].a);
      s.xmm[2] = xmm_from_u32(pairs[i].b, pairs[i].b, pairs[i].b, pairs[i].b);
      for (int pred = 0; pred < 8; pred++) {
        std::string n = std::format("vcmpps p{} {}", pred, pairs[i].desc);
        add_xmm(n, {0xC5, 0xF0, 0xC2, 0xC2, (u8)pred}, s, 0x7);
      }
    }

    // --- C (part 1). VEX scalar FP edge cases (f32) ---
    // VADDSS xmm0, xmm1, xmm2: C5 F2 58 C2 (pp=10 for F3 prefix)
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(pairs[i].a, 0x11111111, 0x22222222, 0x33333333);
      s.xmm[2] = xmm_from_u32(pairs[i].b, 0x44444444, 0x55555555, 0x66666666);
      std::string n = std::format("vaddss {}", pairs[i].desc);
      add_xmm(n, {0xC5, 0xF2, 0x58, 0xC2}, s, 0x7);
    }
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(pairs[i].a, 0x11111111, 0x22222222, 0x33333333);
      s.xmm[2] = xmm_from_u32(pairs[i].b, 0x44444444, 0x55555555, 0x66666666);
      std::string n = std::format("vsubss {}", pairs[i].desc);
      add_xmm(n, {0xC5, 0xF2, 0x5C, 0xC2}, s, 0x7);
    }
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(pairs[i].a, 0x11111111, 0x22222222, 0x33333333);
      s.xmm[2] = xmm_from_u32(pairs[i].b, 0x44444444, 0x55555555, 0x66666666);
      std::string n = std::format("vmulss {}", pairs[i].desc);
      add_xmm(n, {0xC5, 0xF2, 0x59, 0xC2}, s, 0x7);
    }
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(pairs[i].a, 0x11111111, 0x22222222, 0x33333333);
      s.xmm[2] = xmm_from_u32(pairs[i].b, 0x44444444, 0x55555555, 0x66666666);
      std::string n = std::format("vdivss {}", pairs[i].desc);
      add_xmm(n, {0xC5, 0xF2, 0x5E, 0xC2}, s, 0x7);
    }
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(pairs[i].a, 0x11111111, 0x22222222, 0x33333333);
      s.xmm[2] = xmm_from_u32(pairs[i].b, 0x44444444, 0x55555555, 0x66666666);
      std::string n = std::format("vminss {}", pairs[i].desc);
      add_xmm(n, {0xC5, 0xF2, 0x5D, 0xC2}, s, 0x7);
    }
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(pairs[i].a, 0x11111111, 0x22222222, 0x33333333);
      s.xmm[2] = xmm_from_u32(pairs[i].b, 0x44444444, 0x55555555, 0x66666666);
      std::string n = std::format("vmaxss {}", pairs[i].desc);
      add_xmm(n, {0xC5, 0xF2, 0x5F, 0xC2}, s, 0x7);
    }
  }

  // --- B. VEX FP boundary-value matrix (f64) ---
  {
    const u64 POS_ZERO_D  = 0x0000000000000000ULL;
    const u64 NEG_ZERO_D  = 0x8000000000000000ULL;
    const u64 POS_INF_D   = 0x7FF0000000000000ULL;
    const u64 NEG_INF_D   = 0xFFF0000000000000ULL;
    const u64 QNAN_D      = 0x7FF8000000000000ULL;
    const u64 SNAN_D      = 0x7FF0000000000001ULL;
    const u64 DENORM_D    = 0x0000000000000001ULL;
    const u64 ONE_D       = 0x3FF0000000000000ULL;
    const u64 NEG_ONE_D   = 0xBFF0000000000000ULL;
    const u64 MAX_NORM_D  = 0x7FEFFFFFFFFFFFFFULL;

    struct FP64Pair { u64 a; u64 b; const char *desc; };
    FP64Pair dpairs[] = {
      {POS_ZERO_D, NEG_ZERO_D, "pz_nz"},
      {NEG_ZERO_D, POS_ZERO_D, "nz_pz"},
      {POS_INF_D, ONE_D, "pinf_1"},
      {NEG_INF_D, ONE_D, "ninf_1"},
      {POS_INF_D, NEG_INF_D, "pinf_ninf"},
      {POS_INF_D, POS_INF_D, "pinf_pinf"},
      {QNAN_D, ONE_D, "qnan_1"},
      {ONE_D, QNAN_D, "1_qnan"},
      {SNAN_D, ONE_D, "snan_1"},
      {ONE_D, SNAN_D, "1_snan"},
      {SNAN_D, QNAN_D, "snan_qnan"},
      {DENORM_D, ONE_D, "denorm_1"},
      {ONE_D, DENORM_D, "1_denorm"},
      {DENORM_D, DENORM_D, "denorm_denorm"},
      {MAX_NORM_D, ONE_D, "maxnorm_1"},
      {MAX_NORM_D, MAX_NORM_D, "maxnorm2"},
      {NEG_ONE_D, POS_ZERO_D, "n1_pz"},
      {POS_ZERO_D, POS_ZERO_D, "pz_pz"},
      {NEG_ZERO_D, NEG_ZERO_D, "nz_nz"},
      {POS_INF_D, QNAN_D, "pinf_qnan"},
    };
    int ndpairs = sizeof(dpairs) / sizeof(dpairs[0]);

    // VADDPD xmm0, xmm1, xmm2: C5 F1 58 C2 (pp=01 for 66 prefix)
    for (int i = 0; i < ndpairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(dpairs[i].a, dpairs[i].a);
      s.xmm[2] = xmm_from_u64(dpairs[i].b, dpairs[i].b);
      std::string n = std::format("vaddpd {}", dpairs[i].desc);
      add_xmm(n, {0xC5, 0xF1, 0x58, 0xC2}, s, 0x7);
    }
    for (int i = 0; i < ndpairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(dpairs[i].a, dpairs[i].a);
      s.xmm[2] = xmm_from_u64(dpairs[i].b, dpairs[i].b);
      std::string n = std::format("vsubpd {}", dpairs[i].desc);
      add_xmm(n, {0xC5, 0xF1, 0x5C, 0xC2}, s, 0x7);
    }
    for (int i = 0; i < ndpairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(dpairs[i].a, dpairs[i].a);
      s.xmm[2] = xmm_from_u64(dpairs[i].b, dpairs[i].b);
      std::string n = std::format("vmulpd {}", dpairs[i].desc);
      add_xmm(n, {0xC5, 0xF1, 0x59, 0xC2}, s, 0x7);
    }
    for (int i = 0; i < ndpairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(dpairs[i].a, dpairs[i].a);
      s.xmm[2] = xmm_from_u64(dpairs[i].b, dpairs[i].b);
      std::string n = std::format("vdivpd {}", dpairs[i].desc);
      add_xmm(n, {0xC5, 0xF1, 0x5E, 0xC2}, s, 0x7);
    }
    for (int i = 0; i < ndpairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(dpairs[i].a, dpairs[i].a);
      s.xmm[2] = xmm_from_u64(dpairs[i].b, dpairs[i].b);
      std::string n = std::format("vminpd {}", dpairs[i].desc);
      add_xmm(n, {0xC5, 0xF1, 0x5D, 0xC2}, s, 0x7);
    }
    for (int i = 0; i < ndpairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(dpairs[i].a, dpairs[i].a);
      s.xmm[2] = xmm_from_u64(dpairs[i].b, dpairs[i].b);
      std::string n = std::format("vmaxpd {}", dpairs[i].desc);
      add_xmm(n, {0xC5, 0xF1, 0x5F, 0xC2}, s, 0x7);
    }

    // --- C (part 2). VEX scalar FP edge cases (f64) ---
    // VADDSD xmm0, xmm1, xmm2: C5 F3 58 C2 (pp=11 for F2 prefix)
    for (int i = 0; i < ndpairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(dpairs[i].a, 0x1111111122222222ULL);
      s.xmm[2] = xmm_from_u64(dpairs[i].b, 0x3333333344444444ULL);
      std::string n = std::format("vaddsd {}", dpairs[i].desc);
      add_xmm(n, {0xC5, 0xF3, 0x58, 0xC2}, s, 0x7);
    }
    for (int i = 0; i < ndpairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(dpairs[i].a, 0x1111111122222222ULL);
      s.xmm[2] = xmm_from_u64(dpairs[i].b, 0x3333333344444444ULL);
      std::string n = std::format("vsubsd {}", dpairs[i].desc);
      add_xmm(n, {0xC5, 0xF3, 0x5C, 0xC2}, s, 0x7);
    }
    for (int i = 0; i < ndpairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(dpairs[i].a, 0x1111111122222222ULL);
      s.xmm[2] = xmm_from_u64(dpairs[i].b, 0x3333333344444444ULL);
      std::string n = std::format("vmulsd {}", dpairs[i].desc);
      add_xmm(n, {0xC5, 0xF3, 0x59, 0xC2}, s, 0x7);
    }
    for (int i = 0; i < ndpairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(dpairs[i].a, 0x1111111122222222ULL);
      s.xmm[2] = xmm_from_u64(dpairs[i].b, 0x3333333344444444ULL);
      std::string n = std::format("vdivsd {}", dpairs[i].desc);
      add_xmm(n, {0xC5, 0xF3, 0x5E, 0xC2}, s, 0x7);
    }
    for (int i = 0; i < ndpairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(dpairs[i].a, 0x1111111122222222ULL);
      s.xmm[2] = xmm_from_u64(dpairs[i].b, 0x3333333344444444ULL);
      std::string n = std::format("vminsd {}", dpairs[i].desc);
      add_xmm(n, {0xC5, 0xF3, 0x5D, 0xC2}, s, 0x7);
    }
    for (int i = 0; i < ndpairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(dpairs[i].a, 0x1111111122222222ULL);
      s.xmm[2] = xmm_from_u64(dpairs[i].b, 0x3333333344444444ULL);
      std::string n = std::format("vmaxsd {}", dpairs[i].desc);
      add_xmm(n, {0xC5, 0xF3, 0x5F, 0xC2}, s, 0x7);
    }
  }

  // --- D. VEX upper-128 clearing verification ---
  {
    ArchState s;
    s.rflags = 0x2;
    // Pre-load xmm0 with all-ones (simulating dirty YMM upper half)
    s.xmm[0] = xmm_from_u64(0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF);
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);
    // VADDPS xmm0, xmm1, xmm2 should produce clean result
    add_xmm("vaddps upper clear", {0xC5, 0xF0, 0x58, 0xC2}, with_vector_inputs(s, 0x6), 0x7);
    // VMOVAPS xmm0, xmm1: C5 F8 28 C1 (vvvv=1111, pp=00)
    add_xmm("vmovaps upper clear", {0xC5, 0xF8, 0x28, 0xC1}, with_vector_inputs(s, 0x2), 0x3);
    // VPXOR xmm0, xmm1, xmm2: C5 F1 EF C2 (pp=01 for 66)
    add_xmm("vpxor upper clear", {0xC5, 0xF1, 0xEF, 0xC2}, with_vector_inputs(s, 0x6), 0x7);
    // VMOVDQA xmm0, xmm1: C5 F9 6F C1 (66, 0F 6F)
    add_xmm("vmovdqa upper clear", {0xC5, 0xF9, 0x6F, 0xC1}, with_vector_inputs(s, 0x2), 0x3);
    // VXORPS xmm0, xmm0, xmm0: C5 F8 57 C0 (self-xor = zero)
    s.xmm[0] = xmm_from_u64(0xDEADBEEFCAFEBABE, 0x123456789ABCDEF0);
    add_xmm("vxorps self upper clear", {0xC5, 0xF8, 0x57, 0xC0}, with_vector_inputs(s, 0x0), 0x1);
  }

  // --- E. VEX 256-bit arithmetic ---
  // 256-bit packed float
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);
    // VADDPS ymm0, ymm1, ymm2: C5 F4 58 C2 (L=1)
    add_xmm("vaddps ymm", {0xC5, 0xF4, 0x58, 0xC2}, s, 0x7);
    add_xmm("vsubps ymm", {0xC5, 0xF4, 0x5C, 0xC2}, s, 0x7);
    add_xmm("vmulps ymm", {0xC5, 0xF4, 0x59, 0xC2}, s, 0x7);
    add_xmm("vdivps ymm", {0xC5, 0xF4, 0x5E, 0xC2}, s, 0x7);
    add_xmm("vminps ymm", {0xC5, 0xF4, 0x5D, 0xC2}, s, 0x7);
    add_xmm("vmaxps ymm", {0xC5, 0xF4, 0x5F, 0xC2}, s, 0x7);
    // VSQRTPS ymm0, ymm1: C5 FC 51 C1 (vvvv=1111, L=1, pp=00)
    add_xmm("vsqrtps ymm", {0xC5, 0xFC, 0x51, 0xC1}, with_vector_inputs(s, 0x2), 0x3);
    add_xmm("vandps ymm", {0xC5, 0xF4, 0x54, 0xC2}, s, 0x7);
    add_xmm("vorps ymm", {0xC5, 0xF4, 0x56, 0xC2}, s, 0x7);
    add_xmm("vxorps ymm", {0xC5, 0xF4, 0x57, 0xC2}, s, 0x7);
    // VSHUFPS ymm: C5 F4 C6 C2 1B
    add_xmm("vshufps ymm", {0xC5, 0xF4, 0xC6, 0xC2, 0x1B}, s, 0x7);
    add_xmm("vunpcklps ymm", {0xC5, 0xF4, 0x14, 0xC2}, s, 0x7);
    add_xmm("vunpckhps ymm", {0xC5, 0xF4, 0x15, 0xC2}, s, 0x7);
  }

  // 256-bit packed double
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f64(1.5, 2.5);
    s.xmm[2] = xmm_from_f64(3.0, 4.0);
    // VADDPD ymm: C5 F5 58 C2 (66, L=1)
    add_xmm("vaddpd ymm", {0xC5, 0xF5, 0x58, 0xC2}, s, 0x7);
    add_xmm("vsubpd ymm", {0xC5, 0xF5, 0x5C, 0xC2}, s, 0x7);
    add_xmm("vmulpd ymm", {0xC5, 0xF5, 0x59, 0xC2}, s, 0x7);
    add_xmm("vdivpd ymm", {0xC5, 0xF5, 0x5E, 0xC2}, s, 0x7);
    add_xmm("vminpd ymm", {0xC5, 0xF5, 0x5D, 0xC2}, s, 0x7);
    add_xmm("vmaxpd ymm", {0xC5, 0xF5, 0x5F, 0xC2}, s, 0x7);
    add_xmm("vshufpd ymm", {0xC5, 0xF5, 0xC6, 0xC2, 0x05}, s, 0x7);
    add_xmm("vunpcklpd ymm", {0xC5, 0xF5, 0x14, 0xC2}, s, 0x7);
    add_xmm("vunpckhpd ymm", {0xC5, 0xF5, 0x15, 0xC2}, s, 0x7);
  }

  // 256-bit packed integer
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);
    // VPADDB ymm: C5 F5 FC C2 (66, L=1)
    add_xmm("vpaddb ymm", {0xC5, 0xF5, 0xFC, 0xC2}, s, 0x7);
    add_xmm("vpaddw ymm", {0xC5, 0xF5, 0xFD, 0xC2}, s, 0x7);
    add_xmm("vpaddd ymm", {0xC5, 0xF5, 0xFE, 0xC2}, s, 0x7);
    add_xmm("vpaddq ymm", {0xC5, 0xF5, 0xD4, 0xC2}, s, 0x7);
    add_xmm("vpsubb ymm", {0xC5, 0xF5, 0xF8, 0xC2}, s, 0x7);
    add_xmm("vpsubw ymm", {0xC5, 0xF5, 0xF9, 0xC2}, s, 0x7);
    add_xmm("vpsubd ymm", {0xC5, 0xF5, 0xFA, 0xC2}, s, 0x7);
    add_xmm("vpsubq ymm", {0xC5, 0xF5, 0xFB, 0xC2}, s, 0x7);
    add_xmm("vpand ymm", {0xC5, 0xF5, 0xDB, 0xC2}, s, 0x7);
    add_xmm("vpor ymm", {0xC5, 0xF5, 0xEB, 0xC2}, s, 0x7);
    add_xmm("vpxor ymm", {0xC5, 0xF5, 0xEF, 0xC2}, s, 0x7);
    add_xmm("vpandn ymm", {0xC5, 0xF5, 0xDF, 0xC2}, s, 0x7);
  }

  // --- F. VEX integer SIMD boundary values ---
  {
    struct IntPair { u32 a; u32 b; const char *desc; };
    IntPair int_pairs[] = {
      {0x00000000, 0x00000000, "zero_zero"},
      {0xFFFFFFFF, 0x00000001, "max_1"},
      {0x7FFFFFFF, 0x00000001, "smax_1"},
      {0x80000000, 0xFFFFFFFF, "smin_neg1"},
      {0x80000000, 0x80000000, "smin_smin"},
      {0x7FFFFFFF, 0x7FFFFFFF, "smax_smax"},
      {0x00000001, 0xFFFFFFFF, "1_max"},
      {0xAAAAAAAA, 0x55555555, "alt_alt"},
      {0xFF00FF00, 0x00FF00FF, "byte_alt"},
      {0x0000FFFF, 0x00010000, "boundary16"},
    };
    int nint_pairs = sizeof(int_pairs) / sizeof(int_pairs[0]);

    // VPADDD xmm0, xmm1, xmm2: C5 F1 FE C2 (66 prefix)
    for (int i = 0; i < nint_pairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(int_pairs[i].a, int_pairs[i].a,
                                int_pairs[i].a, int_pairs[i].a);
      s.xmm[2] = xmm_from_u32(int_pairs[i].b, int_pairs[i].b,
                                int_pairs[i].b, int_pairs[i].b);
      std::string n = std::format("vpaddd {}", int_pairs[i].desc);
      add_xmm(n, {0xC5, 0xF1, 0xFE, 0xC2}, s, 0x7);
    }
    // VPSUBD: C5 F1 FA C2
    for (int i = 0; i < nint_pairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(int_pairs[i].a, int_pairs[i].a,
                                int_pairs[i].a, int_pairs[i].a);
      s.xmm[2] = xmm_from_u32(int_pairs[i].b, int_pairs[i].b,
                                int_pairs[i].b, int_pairs[i].b);
      std::string n = std::format("vpsubd {}", int_pairs[i].desc);
      add_xmm(n, {0xC5, 0xF1, 0xFA, 0xC2}, s, 0x7);
    }
    // VPADDB: C5 F1 FC C2
    for (int i = 0; i < nint_pairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(int_pairs[i].a, int_pairs[i].a,
                                int_pairs[i].a, int_pairs[i].a);
      s.xmm[2] = xmm_from_u32(int_pairs[i].b, int_pairs[i].b,
                                int_pairs[i].b, int_pairs[i].b);
      std::string n = std::format("vpaddb {}", int_pairs[i].desc);
      add_xmm(n, {0xC5, 0xF1, 0xFC, 0xC2}, s, 0x7);
    }
    // VPSUBB: C5 F1 F8 C2
    for (int i = 0; i < nint_pairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(int_pairs[i].a, int_pairs[i].a,
                                int_pairs[i].a, int_pairs[i].a);
      s.xmm[2] = xmm_from_u32(int_pairs[i].b, int_pairs[i].b,
                                int_pairs[i].b, int_pairs[i].b);
      std::string n = std::format("vpsubb {}", int_pairs[i].desc);
      add_xmm(n, {0xC5, 0xF1, 0xF8, 0xC2}, s, 0x7);
    }
    // VPADDW: C5 F1 FD C2
    for (int i = 0; i < nint_pairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(int_pairs[i].a, int_pairs[i].a,
                                int_pairs[i].a, int_pairs[i].a);
      s.xmm[2] = xmm_from_u32(int_pairs[i].b, int_pairs[i].b,
                                int_pairs[i].b, int_pairs[i].b);
      std::string n = std::format("vpaddw {}", int_pairs[i].desc);
      add_xmm(n, {0xC5, 0xF1, 0xFD, 0xC2}, s, 0x7);
    }
    // VPSUBW: C5 F1 F9 C2
    for (int i = 0; i < nint_pairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(int_pairs[i].a, int_pairs[i].a,
                                int_pairs[i].a, int_pairs[i].a);
      s.xmm[2] = xmm_from_u32(int_pairs[i].b, int_pairs[i].b,
                                int_pairs[i].b, int_pairs[i].b);
      std::string n = std::format("vpsubw {}", int_pairs[i].desc);
      add_xmm(n, {0xC5, 0xF1, 0xF9, 0xC2}, s, 0x7);
    }
  }

  // --- G. VCMPPS full predicate coverage with mixed operands ---
  {
    const u32 ONE  = 0x3F800000;
    const u32 TWO  = 0x40000000;
    const u32 FOUR = 0x40800000;
    const u32 THREE = 0x40400000;
    const u32 QNAN = 0x7FC00000;
    // Elements: 1.0==1.0 (EQ), 2.0<3.0 (LT), 4.0>3.0 (GT), NaN (unordered)
    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u32(ONE, TWO, FOUR, QNAN);
    s.xmm[2] = xmm_from_u32(ONE, THREE, THREE, ONE);
    for (int pred = 0; pred < 8; pred++) {
      std::string n = std::format("vcmpps mixed pred{}", pred);
      add_xmm(n, {0xC5, 0xF0, 0xC2, 0xC2, (u8)pred}, s, 0x7);
    }
  }

  // --- 256-bit VCMPPS/VCMPPD ---
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 3.0f, 2.0f, 4.0f);
    // VCMPPS ymm0,ymm1,ymm2,0 (EQ): C5 F4 C2 C2 00
    add_xmm("vcmpps ymm eq", {0xC5, 0xF4, 0xC2, 0xC2, 0x00}, s, 0x7);
    // VCMPPS ymm0,ymm1,ymm2,1 (LT): C5 F4 C2 C2 01
    add_xmm("vcmpps ymm lt", {0xC5, 0xF4, 0xC2, 0xC2, 0x01}, s, 0x7);
    // VCMPPS ymm0,ymm1,ymm2,6 (NLE): C5 F4 C2 C2 06
    add_xmm("vcmpps ymm nle", {0xC5, 0xF4, 0xC2, 0xC2, 0x06}, s, 0x7);
  }
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f64(1.5, 2.5);
    s.xmm[2] = xmm_from_f64(1.5, 3.0);
    // VCMPPD ymm0,ymm1,ymm2,0 (EQ): C5 F5 C2 C2 00
    add_xmm("vcmppd ymm eq", {0xC5, 0xF5, 0xC2, 0xC2, 0x00}, s, 0x7);
    add_xmm("vcmppd ymm lt", {0xC5, 0xF5, 0xC2, 0xC2, 0x01}, s, 0x7);
  }

  // --- H. VEX conversion edge cases ---
  {
    const u32 POS_INF  = 0x7F800000;
    const u32 NEG_INF  = 0xFF800000;
    const u32 QNAN     = 0x7FC00000;
    const u32 MAX_NORM = 0x7F7FFFFF;

    // VCVTDQ2PS with boundary integers
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(0x7FFFFFFF, 0x80000000, 0x00000000, 0xFFFFFFFF);
      // VCVTDQ2PS xmm0, xmm1: C5 F8 5B C1 (NP, 0F 5B)
      add_xmm("vcvtdq2ps boundary", {0xC5, 0xF8, 0x5B, 0xC1}, s, 0x3);
    }
    // VCVTPS2DQ with FP edge cases
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(POS_INF, NEG_INF, QNAN, MAX_NORM);
      // VCVTPS2DQ xmm0, xmm1: C5 F9 5B C1 (66, 0F 5B)
      add_xmm("vcvtps2dq edge", {0xC5, 0xF9, 0x5B, 0xC1}, s, 0x3);
    }
    // VCVTTPS2DQ with FP edge cases
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(POS_INF, NEG_INF, QNAN, MAX_NORM);
      // VCVTTPS2DQ xmm0, xmm1: C5 FA 5B C1 (F3, 0F 5B)
      add_xmm("vcvttps2dq edge", {0xC5, 0xFA, 0x5B, 0xC1}, s, 0x3);
    }
    // VCVTDQ2PS with small values and powers of 2
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(1, 0xFFFFFFFF, 0x01000000, 0x00FFFFFF);
      add_xmm("vcvtdq2ps small", {0xC5, 0xF8, 0x5B, 0xC1}, s, 0x3);
    }
  }

  // =====================================================================
  // FP Edge Cases — NaN, Inf, denormals, signed zeros
  //
  // These test corner cases that are often incorrectly implemented.
  // Hardware is ground truth. Any mismatch reveals a model bug.
  // =====================================================================
  cat = "FP Edge";
  {
    // Special f32 bit patterns
    const u32 POS_ZERO  = 0x00000000;
    const u32 NEG_ZERO  = 0x80000000;
    const u32 POS_INF   = 0x7F800000;
    const u32 NEG_INF   = 0xFF800000;
    const u32 QNAN      = 0x7FC00000;  // quiet NaN
    const u32 F32_SNAN      = u32(0x7F800001);  // signaling NaN
    const u32 QNAN2     = 0x7FC00042;  // different QNaN payload
    const u32 DENORM    = 0x00000001;  // smallest positive denormal
    const u32 DENORM2   = 0x007FFFFF;  // largest denormal
    const u32 NEG_DENORM = 0x80000001; // smallest negative denormal
    const u32 ONE       = 0x3F800000;  // 1.0f
    const u32 NEG_ONE   = 0xBF800000;  // -1.0f
    const u32 TWO       = 0x40000000;  // 2.0f
    const u32 MAX_NORM  = 0x7F7FFFFF;  // largest finite f32

    // Test pairs: each pair {src1_elem, src2_elem}
    struct FPPair { u32 a; u32 b; const char *desc; };
    FPPair pairs[] = {
      {POS_ZERO, NEG_ZERO, "pz_nz"},
      {NEG_ZERO, POS_ZERO, "nz_pz"},
      {POS_INF, ONE, "pinf_1"},
      {NEG_INF, ONE, "ninf_1"},
      {POS_INF, NEG_INF, "pinf_ninf"},
      {POS_INF, POS_INF, "pinf_pinf"},
      {QNAN, ONE, "qnan_1"},
      {ONE, QNAN, "1_qnan"},
      {QNAN, QNAN2, "qnan_qnan2"},
      {F32_SNAN, ONE, "snan_1"},
      {ONE, F32_SNAN, "1_snan"},
      {F32_SNAN, QNAN, "snan_qnan"},
      {DENORM, ONE, "denorm_1"},
      {ONE, DENORM, "1_denorm"},
      {DENORM, DENORM, "denorm_denorm"},
      {NEG_DENORM, ONE, "ndenorm_1"},
      {DENORM2, DENORM2, "maxdenorm2"},
      {MAX_NORM, ONE, "maxnorm_1"},
      {MAX_NORM, MAX_NORM, "maxnorm2"},
      {NEG_ONE, POS_ZERO, "n1_pz"},
      {POS_ZERO, POS_ZERO, "pz_pz"},
      {NEG_ZERO, NEG_ZERO, "nz_nz"},
      {POS_INF, QNAN, "pinf_qnan"},
      {QNAN, POS_INF, "qnan_pinf"},
    };
    int npairs = sizeof(pairs) / sizeof(pairs[0]);

    // ADDPS with edge cases
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u32(pairs[i].a, pairs[i].a, pairs[i].a, pairs[i].a);
      s.xmm[1] = xmm_from_u32(pairs[i].b, pairs[i].b, pairs[i].b, pairs[i].b);
      std::string n = std::format("addps {}", pairs[i].desc);
      // ADDPS xmm0, xmm1: 0F 58 C1
      add_xmm(n, {0x0F, 0x58, 0xC1}, s, 0x3);
    }

    // SUBPS with edge cases
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u32(pairs[i].a, pairs[i].a, pairs[i].a, pairs[i].a);
      s.xmm[1] = xmm_from_u32(pairs[i].b, pairs[i].b, pairs[i].b, pairs[i].b);
      std::string n = std::format("subps {}", pairs[i].desc);
      // SUBPS xmm0, xmm1: 0F 5C C1
      add_xmm(n, {0x0F, 0x5C, 0xC1}, s, 0x3);
    }

    // MULPS with edge cases
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u32(pairs[i].a, pairs[i].a, pairs[i].a, pairs[i].a);
      s.xmm[1] = xmm_from_u32(pairs[i].b, pairs[i].b, pairs[i].b, pairs[i].b);
      std::string n = std::format("mulps {}", pairs[i].desc);
      // MULPS xmm0, xmm1: 0F 59 C1
      add_xmm(n, {0x0F, 0x59, 0xC1}, s, 0x3);
    }

    // DIVPS with edge cases
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u32(pairs[i].a, pairs[i].a, pairs[i].a, pairs[i].a);
      s.xmm[1] = xmm_from_u32(pairs[i].b, pairs[i].b, pairs[i].b, pairs[i].b);
      std::string n = std::format("divps {}", pairs[i].desc);
      // DIVPS xmm0, xmm1: 0F 5E C1
      add_xmm(n, {0x0F, 0x5E, 0xC1}, s, 0x3);
    }

    // MINPS with edge cases — particularly interesting for signed zero
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u32(pairs[i].a, pairs[i].a, pairs[i].a, pairs[i].a);
      s.xmm[1] = xmm_from_u32(pairs[i].b, pairs[i].b, pairs[i].b, pairs[i].b);
      std::string n = std::format("minps {}", pairs[i].desc);
      // MINPS xmm0, xmm1: 0F 5D C1
      add_xmm(n, {0x0F, 0x5D, 0xC1}, s, 0x3);
    }

    // MAXPS with edge cases
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u32(pairs[i].a, pairs[i].a, pairs[i].a, pairs[i].a);
      s.xmm[1] = xmm_from_u32(pairs[i].b, pairs[i].b, pairs[i].b, pairs[i].b);
      std::string n = std::format("maxps {}", pairs[i].desc);
      // MAXPS xmm0, xmm1: 0F 5F C1
      add_xmm(n, {0x0F, 0x5F, 0xC1}, s, 0x3);
    }

    // CMPPS with edge cases — test various predicates
    u8 cmppreds[] = {0, 1, 2, 3, 4, 5, 6, 7}; // EQ,LT,LE,UNORD,NEQ,NLT,NLE,ORD
    for (int p = 0; p < 8; p++) {
      for (int i = 0; i < npairs; i++) {
        ArchState s;
        s.rflags = 0x2;
        s.xmm[0] = xmm_from_u32(pairs[i].a, pairs[i].a, pairs[i].a, pairs[i].a);
        s.xmm[1] = xmm_from_u32(pairs[i].b, pairs[i].b, pairs[i].b, pairs[i].b);
        std::string n = std::format("cmpps p{} {}", p, pairs[i].desc);
        // CMPPS xmm0, xmm1, imm8: 0F C2 C1 pp
        add_xmm(n, {0x0F, 0xC2, 0xC1, cmppreds[p]}, s, 0x3);
      }
    }

    // UCOMISS with edge cases — tests flag setting with NaN/Inf
    for (int i = 0; i < npairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u32(pairs[i].a, 0, 0, 0);
      s.xmm[1] = xmm_from_u32(pairs[i].b, 0, 0, 0);
      std::string n = std::format("ucomiss {}", pairs[i].desc);
      // UCOMISS xmm0, xmm1: 0F 2E C1
      add_xmm(n, {0x0F, 0x2E, 0xC1}, s, 0x3);
    }

    // SQRTPS with edge cases (single-operand)
    u32 sqrt_vals[] = {POS_ZERO, NEG_ZERO, POS_INF, NEG_INF, QNAN, F32_SNAN,
                       DENORM, NEG_ONE, ONE, TWO, MAX_NORM};
    for (auto v : sqrt_vals) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u32(v, v, v, v);
      std::string n = std::format("sqrtps 0x{:08x}", v);
      // SQRTPS xmm0, xmm0: 0F 51 C0
      add_xmm(n, {0x0F, 0x51, 0xC0}, s, 0x1);
    }

    // CVTPS2DQ with edge cases — float to int conversion
    u32 cvt_vals[] = {POS_ZERO, NEG_ZERO, POS_INF, NEG_INF, QNAN, F32_SNAN,
                      ONE, NEG_ONE, MAX_NORM, DENORM, 0x4F000000 /*2^31*/,
                      0xCF000000 /*-2^31*/, 0x4F800000 /*2^32*/};
    for (auto v : cvt_vals) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u32(v, v, v, v);
      std::string n = std::format("cvtps2dq 0x{:08x}", v);
      // CVTPS2DQ xmm0, xmm0: 66 0F 5B C0
      add_xmm(n, {0x66, 0x0F, 0x5B, 0xC0}, s, 0x1);
    }

    // CVTTPS2DQ — truncation conversion
    for (auto v : cvt_vals) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u32(v, v, v, v);
      std::string n = std::format("cvttps2dq 0x{:08x}", v);
      // CVTTPS2DQ xmm0, xmm0: F3 0F 5B C0
      add_xmm(n, {0xF3, 0x0F, 0x5B, 0xC0}, s, 0x1);
    }
  }

  // =====================================================================
  // FP Edge f64 — NaN, Inf, signed zeros in double precision
  // =====================================================================
  cat = "FP Edge";
  {
    const u64 POS_ZERO_D = 0x0000000000000000;
    const u64 NEG_ZERO_D = 0x8000000000000000;
    const u64 POS_INF_D  = 0x7FF0000000000000;
    const u64 NEG_INF_D  = 0xFFF0000000000000;
    const u64 QNAN_D     = 0x7FF8000000000000;
    const u64 SNAN_D     = 0x7FF0000000000001;
    const u64 DENORM_D   = 0x0000000000000001;
    const u64 ONE_D      = 0x3FF0000000000000;

    struct FPPairD { u64 a; u64 b; const char *desc; };
    FPPairD dpairs[] = {
      {POS_ZERO_D, NEG_ZERO_D, "pz_nz"},
      {NEG_ZERO_D, POS_ZERO_D, "nz_pz"},
      {POS_INF_D, ONE_D, "pinf_1"},
      {NEG_INF_D, ONE_D, "ninf_1"},
      {POS_INF_D, NEG_INF_D, "pinf_ninf"},
      {QNAN_D, ONE_D, "qnan_1"},
      {ONE_D, QNAN_D, "1_qnan"},
      {SNAN_D, ONE_D, "snan_1"},
      {DENORM_D, ONE_D, "denorm_1"},
      {DENORM_D, DENORM_D, "denorm2"},
    };
    int ndpairs = sizeof(dpairs) / sizeof(dpairs[0]);

    // ADDPD with edge cases
    for (int i = 0; i < ndpairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(dpairs[i].a, dpairs[i].a);
      s.xmm[1] = xmm_from_u64(dpairs[i].b, dpairs[i].b);
      std::string n = std::format("addpd {}", dpairs[i].desc);
      // ADDPD xmm0, xmm1: 66 0F 58 C1
      add_xmm(n, {0x66, 0x0F, 0x58, 0xC1}, s, 0x3);
    }

    // MINPD — signed zero ordering
    for (int i = 0; i < ndpairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(dpairs[i].a, dpairs[i].a);
      s.xmm[1] = xmm_from_u64(dpairs[i].b, dpairs[i].b);
      std::string n = std::format("minpd {}", dpairs[i].desc);
      // MINPD xmm0, xmm1: 66 0F 5D C1
      add_xmm(n, {0x66, 0x0F, 0x5D, 0xC1}, s, 0x3);
    }

    // MAXPD
    for (int i = 0; i < ndpairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(dpairs[i].a, dpairs[i].a);
      s.xmm[1] = xmm_from_u64(dpairs[i].b, dpairs[i].b);
      std::string n = std::format("maxpd {}", dpairs[i].desc);
      // MAXPD xmm0, xmm1: 66 0F 5F C1
      add_xmm(n, {0x66, 0x0F, 0x5F, 0xC1}, s, 0x3);
    }

    // UCOMISD
    for (int i = 0; i < ndpairs; i++) {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(dpairs[i].a, 0);
      s.xmm[1] = xmm_from_u64(dpairs[i].b, 0);
      std::string n = std::format("ucomisd {}", dpairs[i].desc);
      // UCOMISD xmm0, xmm1: 66 0F 2E C1
      add_xmm(n, {0x66, 0x0F, 0x2E, 0xC1}, s, 0x3);
    }
  }

  // =====================================================================
  // FP Edge — MXCSR rounding mode tests
  // =====================================================================
  // CVTPS2DQ uses MXCSR rounding mode (bits 14:13).
  // Test with values where rounding mode matters: 1.5, 2.5, -1.5, -0.5, 0.7
  {
    const char *rc_names[] = {"RN", "RD", "RU", "RZ"};
    // MXCSR: default 0x1F80, RC bits at 14:13
    for (int rc = 0; rc < 4; rc++) {
      u32 mxcsr = 0x1F80 | (rc << 13);
      float test_vals[] = {1.5f, 2.5f, -1.5f, -2.5f, -0.5f, 0.7f, 3.3f, -3.7f};
      for (int i = 0; i < 8; i++) {
        ArchState s;
        s.rflags = 0x2;
        s.mxcsr = mxcsr;
        s.xmm[0] = xmm_from_f32(test_vals[i], test_vals[i],
                                  test_vals[i], test_vals[i]);
        std::string n = std::format("cvtps2dq RC={} {:.1f}", rc_names[rc], test_vals[i]);
        // CVTPS2DQ xmm0, xmm0: 66 0F 5B C0
        add_xmm(n, {0x66, 0x0F, 0x5B, 0xC0}, s, 0x1);
      }

      // Also test CVTSS2SI (scalar f32 -> i32 with rounding)
      for (int i = 0; i < 8; i++) {
        ArchState s;
        s.rflags = 0x2;
        s.mxcsr = mxcsr;
        s.xmm[0] = xmm_from_f32(test_vals[i], 0.0f, 0.0f, 0.0f);
        std::string n = std::format("cvtss2si RC={} {:.1f}", rc_names[rc], test_vals[i]);
        // CVTSS2SI eax, xmm0: F3 0F 2D C0
        add_xmm(n, {0xF3, 0x0F, 0x2D, 0xC0}, s, 0x0);
      }
    }

    // CVTPD2DQ with rounding modes
    for (int rc = 0; rc < 4; rc++) {
      u32 mxcsr = 0x1F80 | (rc << 13);
      double dvals[] = {1.5, 2.5, -1.5, -2.5};
      for (int i = 0; i < 4; i++) {
        ArchState s;
        s.rflags = 0x2;
        s.mxcsr = mxcsr;
        s.xmm[0] = xmm_from_f64(dvals[i], dvals[i]);
        std::string n = std::format("cvtpd2dq RC={} {:.1f}", rc_names[rc], dvals[i]);
        // CVTPD2DQ xmm0, xmm0: F2 0F E6 C0
        add_xmm(n, {0xF2, 0x0F, 0xE6, 0xC0}, s, 0x1);
      }
    }

    // ADDPS with rounding modes (test with values that produce different results)
    for (int rc = 0; rc < 4; rc++) {
      u32 mxcsr = 0x1F80 | (rc << 13);
      // 1.0f + 2^-24 = 1.0000000596... — depends on rounding
      u32 one = 0x3F800000;       // 1.0f
      u32 tiny = 0x33800000;      // 2^-24
      ArchState s;
      s.rflags = 0x2;
      s.mxcsr = mxcsr;
      s.xmm[0] = xmm_from_u32(one, one, one, one);
      s.xmm[1] = xmm_from_u32(tiny, tiny, tiny, tiny);
      std::string n = std::format("addps RC={} 1+ulp", rc_names[rc]);
      add_xmm(n, {0x0F, 0x58, 0xC1}, s, 0x3);
    }
  }

  // =====================================================================
  // FP Edge — SNaN quieting, div-by-zero, scalar MIN/MAX, COMISS
  // =====================================================================
  {
    // SNaN should be quieted to QNaN in arithmetic output
    // SNaN + 0 → QNaN (SNaN with quiet bit set)
    {
      ArchState s;
      s.rflags = 0x2;
      u32 snan = 0x7F800042;  // custom SNaN payload
      s.xmm[0] = xmm_from_u32(snan, snan, snan, snan);
      s.xmm[1] = xmm_from_u32(0, 0, 0, 0);  // +0.0
      add_xmm("addps snan+0 quiet", {0x0F, 0x58, 0xC1}, s, 0x3);
    }

    // Division by zero: 1.0 / 0.0 → +Inf, -1.0 / 0.0 → -Inf
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_f32(1.0f, -1.0f, 0.0f, 1.0f);
      u32 pz = 0x00000000;
      u32 nz = 0x80000000;
      s.xmm[1] = xmm_from_u32(pz, pz, pz, nz);
      add_xmm("divps by zero", {0x0F, 0x5E, 0xC1}, s, 0x3);
    }

    // MINSS/MAXSS scalar — only lowest element, upper 3 preserved from dst
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_f32(5.0f, 11.0f, 22.0f, 33.0f);
      s.xmm[1] = xmm_from_f32(3.0f, 99.0f, 88.0f, 77.0f);
      // MINSS xmm0, xmm1: F3 0F 5D C1
      add_xmm("minss scalar", {0xF3, 0x0F, 0x5D, 0xC1}, s, 0x3);
      // MAXSS xmm0, xmm1: F3 0F 5F C1
      add_xmm("maxss scalar", {0xF3, 0x0F, 0x5F, 0xC1}, s, 0x3);
    }

    // MINSS/MAXSS with NaN in scalar position
    {
      ArchState s;
      s.rflags = 0x2;
      u32 qnan = 0x7FC00000;
      s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      s.xmm[1] = xmm_from_u32(qnan, 0x41200000, 0x41200000, 0x41200000);
      add_xmm("minss nan src2", {0xF3, 0x0F, 0x5D, 0xC1}, s, 0x3);
      add_xmm("maxss nan src2", {0xF3, 0x0F, 0x5F, 0xC1}, s, 0x3);
    }

    // COMISS vs UCOMISS with QNaN — COMISS raises #IE (masked → sets flags same way)
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_f32(1.0f, 0.0f, 0.0f, 0.0f);
      u32 qnan = 0x7FC00000;
      s.xmm[1] = xmm_from_u32(qnan, 0, 0, 0);
      // COMISS xmm0, xmm1: 0F 2F C1
      add_xmm("comiss 1_qnan", {0x0F, 0x2F, 0xC1}, s, 0x0);
      // UCOMISS xmm0, xmm1: 0F 2E C1
      add_xmm("ucomiss 1_qnan", {0x0F, 0x2E, 0xC1}, s, 0x0);
    }

    // COMISS with equal values and signed zeros
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u32(0x80000000, 0, 0, 0);  // -0.0
      s.xmm[1] = xmm_from_u32(0x00000000, 0, 0, 0);  // +0.0
      add_xmm("comiss -0_+0", {0x0F, 0x2F, 0xC1}, s, 0x0);
    }

    // SUBPS: Inf - Inf → NaN, 0 - 0 with same sign → +0.0 (not -0.0)
    {
      ArchState s;
      s.rflags = 0x2;
      u32 pinf = 0x7F800000;
      u32 ninf = 0xFF800000;
      u32 pz = 0x00000000;
      u32 nz = 0x80000000;
      s.xmm[0] = xmm_from_u32(pinf, ninf, pz, nz);
      s.xmm[1] = xmm_from_u32(pinf, ninf, pz, nz);
      add_xmm("subps self", {0x0F, 0x5C, 0xC1}, s, 0x3);
    }

    // MULPS: 0 * Inf → NaN
    {
      ArchState s;
      s.rflags = 0x2;
      u32 pz = 0x00000000;
      u32 pinf = 0x7F800000;
      s.xmm[0] = xmm_from_u32(pz, pinf, pz, pinf);
      s.xmm[1] = xmm_from_u32(pinf, pz, pinf, pz);
      add_xmm("mulps 0*inf", {0x0F, 0x59, 0xC1}, s, 0x3);
    }

    // ROUNDPS with imm8 bit 2 = 0 → use MXCSR rounding
    for (int rc = 0; rc < 4; rc++) {
      u32 mxcsr = 0x1F80 | (rc << 13);
      ArchState s;
      s.rflags = 0x2;
      s.mxcsr = mxcsr;
      s.xmm[0] = xmm_from_f32(1.5f, 2.5f, -1.5f, -2.5f);
      const char *rc_names[] = {"RN", "RD", "RU", "RZ"};
      std::string n = std::format("roundps mxcsr RC={}", rc_names[rc]);
      // ROUNDPS xmm0, xmm0, 0x04: 66 0F 3A 08 C0 04
      // imm8=0x04: bit 2=1 means use imm8 RC, bit 1:0=00 means RN
      // Actually for MXCSR test, imm8 bit 2=0: 66 0F 3A 08 C0 00
      // Wait: imm8[2]=0 means use MXCSR RC. imm8[1:0] ignored when bit2=0.
      add_xmm(n, {0x66, 0x0F, 0x3A, 0x08, 0xC0, 0x00}, s, 0x1);
    }

    // CVTDQ2PS: int→float (exact for small values, rounding for large)
    {
      ArchState s;
      s.rflags = 0x2;
      // INT32_MAX = 2147483647, not exactly representable as f32
      s.xmm[0] = xmm_from_u32(0x7FFFFFFF, 0x80000001, 0x01000001, 0xFEFFFFFF);
      // CVTDQ2PS xmm0, xmm0: 0F 5B C0
      add_xmm("cvtdq2ps large", {0x0F, 0x5B, 0xC0}, s, 0x1);
    }

    // CVTDQ2PS with MXCSR rounding modes for large values
    for (int rc = 0; rc < 4; rc++) {
      u32 mxcsr = 0x1F80 | (rc << 13);
      ArchState s;
      s.rflags = 0x2;
      s.mxcsr = mxcsr;
      s.xmm[0] = xmm_from_u32(0x7FFFFFFF, 0x80000001, 0x01000001, 0xFEFFFFFF);
      const char *rc_names[] = {"RN", "RD", "RU", "RZ"};
      std::string n = std::format("cvtdq2ps RC={} large", rc_names[rc]);
      add_xmm(n, {0x0F, 0x5B, 0xC0}, s, 0x1);
    }
  }

  // =====================================================================
  // FP Edge — shuffle/blend edge cases and additional SSE corner cases
  // =====================================================================
  {
    // SHUFPS with all-same source (broadcast-like): imm8=0x00
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);
      // SHUFPS xmm0, xmm1, 0x00: 0F C6 C1 00
      add_xmm("shufps 0x00", {0x0F, 0xC6, 0xC1, 0x00}, s, 0x3);
      add_xmm("shufps 0xFF", {0x0F, 0xC6, 0xC1, 0xFF}, s, 0x3);
      add_xmm("shufps 0x1B", {0x0F, 0xC6, 0xC1, 0x1B}, s, 0x3);  // reverse
      add_xmm("shufps 0xE4", {0x0F, 0xC6, 0xC1, 0xE4}, s, 0x3);  // identity
    }

    // SHUFPD: 2 bits select from 2 sources
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_f64(1.0, 2.0);
      s.xmm[1] = xmm_from_f64(3.0, 4.0);
      // SHUFPD xmm0, xmm1, imm: 66 0F C6 C1 imm
      add_xmm("shufpd 0x00", {0x66, 0x0F, 0xC6, 0xC1, 0x00}, s, 0x3);
      add_xmm("shufpd 0x01", {0x66, 0x0F, 0xC6, 0xC1, 0x01}, s, 0x3);
      add_xmm("shufpd 0x02", {0x66, 0x0F, 0xC6, 0xC1, 0x02}, s, 0x3);
      add_xmm("shufpd 0x03", {0x66, 0x0F, 0xC6, 0xC1, 0x03}, s, 0x3);
    }

    // PSHUFD with various immediates
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u32(0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC, 0xDDDDDDDD);
      // PSHUFD xmm0, xmm0, imm: 66 0F 70 C0 imm
      add_xmm("pshufd 0x00", {0x66, 0x0F, 0x70, 0xC0, 0x00}, s, 0x1);  // broadcast [0]
      add_xmm("pshufd 0xFF", {0x66, 0x0F, 0x70, 0xC0, 0xFF}, s, 0x1);  // broadcast [3]
      add_xmm("pshufd 0x1B", {0x66, 0x0F, 0x70, 0xC0, 0x1B}, s, 0x1);  // reverse
      add_xmm("pshufd 0xE4", {0x66, 0x0F, 0x70, 0xC0, 0xE4}, s, 0x1);  // identity
      add_xmm("pshufd 0x55", {0x66, 0x0F, 0x70, 0xC0, 0x55}, s, 0x1);  // broadcast [1]
    }

    // PSHUFB with high-bit-set control (zeros the element)
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u32(0x04030201, 0x08070605, 0x0C0B0A09, 0x100F0E0D);
      // Control: 0x80 = zero, 0x00 = byte 0, 0x0F = byte 15
      s.xmm[1] = xmm_from_u32(0x80000180, 0x0F0E0D0C, 0x03020100, 0x80808080);
      // PSHUFB xmm0, xmm1: 66 0F 38 00 C1
      add_xmm("pshufb zeros", {0x66, 0x0F, 0x38, 0x00, 0xC1}, s, 0x3);
    }

    // BLENDVPS: XMM0 as implicit mask (high bit of each dword selects)
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u32(0x80000000, 0x00000000, 0x80000000, 0x00000000);
      s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
      s.xmm[2] = xmm_from_f32(50.0f, 60.0f, 70.0f, 80.0f);
      // BLENDVPS xmm1, xmm2: 66 0F 38 14 CA (dst=xmm1, src=xmm2, mask=xmm0)
      add_xmm("blendvps mask", {0x66, 0x0F, 0x38, 0x14, 0xCA}, s, 0x7);
    }

    // DPPS (dot product) with various masks
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);
      // DPPS xmm0, xmm1, imm: 66 0F 3A 40 C1 imm
      // imm8 high 4 bits: which elements to multiply. Low 4: which elements to write.
      add_xmm("dpps 0xFF", {0x66, 0x0F, 0x3A, 0x40, 0xC1, 0xFF}, s, 0x3);  // all mul, all write
      add_xmm("dpps 0xF1", {0x66, 0x0F, 0x3A, 0x40, 0xC1, 0xF1}, s, 0x3);  // all mul, write [0] only
      add_xmm("dpps 0x71", {0x66, 0x0F, 0x3A, 0x40, 0xC1, 0x71}, s, 0x3);  // mul [0,1,2], write [0]
    }

    // DPPD (dot product double)
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_f64(3.0, 4.0);
      s.xmm[1] = xmm_from_f64(5.0, 6.0);
      // DPPD xmm0, xmm1, imm: 66 0F 3A 41 C1 imm
      add_xmm("dppd 0x33", {0x66, 0x0F, 0x3A, 0x41, 0xC1, 0x33}, s, 0x3);  // both mul, both write
      add_xmm("dppd 0x31", {0x66, 0x0F, 0x3A, 0x41, 0xC1, 0x31}, s, 0x3);  // both mul, write [0]
    }

    // INSERTPS — insert from xmm, zero selected positions
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
      // INSERTPS xmm0, xmm1, imm: 66 0F 3A 21 C1 imm
      // imm8[7:6]=count_s (src index), [5:4]=count_d (dst index), [3:0]=zmask
      add_xmm("insertps 0x00", {0x66, 0x0F, 0x3A, 0x21, 0xC1, 0x00}, s, 0x3); // src[0]→dst[0]
      add_xmm("insertps 0x30", {0x66, 0x0F, 0x3A, 0x21, 0xC1, 0x30}, s, 0x3); // src[0]→dst[3]
      add_xmm("insertps 0xC0", {0x66, 0x0F, 0x3A, 0x21, 0xC1, 0xC0}, s, 0x3); // src[3]→dst[0]
      add_xmm("insertps 0x0D", {0x66, 0x0F, 0x3A, 0x21, 0xC1, 0x0D}, s, 0x3); // src[0]→dst[0], zero [0,2,3]
      add_xmm("insertps 0x0F", {0x66, 0x0F, 0x3A, 0x21, 0xC1, 0x0F}, s, 0x3); // zero all
    }

    // EXTRACTPS — extract f32 element to GPR
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      // EXTRACTPS eax, xmm0, imm: 66 0F 3A 17 C0 imm
      add_xmm("extractps 0", {0x66, 0x0F, 0x3A, 0x17, 0xC0, 0x00}, s, 0x0);
      add_xmm("extractps 1", {0x66, 0x0F, 0x3A, 0x17, 0xC0, 0x01}, s, 0x0);
      add_xmm("extractps 2", {0x66, 0x0F, 0x3A, 0x17, 0xC0, 0x02}, s, 0x0);
      add_xmm("extractps 3", {0x66, 0x0F, 0x3A, 0x17, 0xC0, 0x03}, s, 0x0);
    }

    // MOVHLPS / MOVLHPS — move high/low between registers
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      s.xmm[1] = xmm_from_u32(0x55555555, 0x66666666, 0x77777777, 0x88888888);
      // MOVHLPS xmm0, xmm1: 0F 12 C1
      add_xmm("movhlps", {0x0F, 0x12, 0xC1}, s, 0x3);
      // MOVLHPS xmm0, xmm1: 0F 16 C1
      add_xmm("movlhps", {0x0F, 0x16, 0xC1}, s, 0x3);
    }

    // UNPCKLPS / UNPCKHPS — interleave elements
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u32(0xAA, 0xBB, 0xCC, 0xDD);
      s.xmm[1] = xmm_from_u32(0x11, 0x22, 0x33, 0x44);
      // UNPCKLPS xmm0, xmm1: 0F 14 C1
      add_xmm("unpcklps", {0x0F, 0x14, 0xC1}, s, 0x3);
      // UNPCKHPS xmm0, xmm1: 0F 15 C1
      add_xmm("unpckhps", {0x0F, 0x15, 0xC1}, s, 0x3);
    }

    // UNPCKLPD / UNPCKHPD
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(0xAAAAAAAAAAAAAAAA, 0xBBBBBBBBBBBBBBBB);
      s.xmm[1] = xmm_from_u64(0x1111111111111111, 0x2222222222222222);
      // UNPCKLPD xmm0, xmm1: 66 0F 14 C1
      add_xmm("unpcklpd", {0x66, 0x0F, 0x14, 0xC1}, s, 0x3);
      // UNPCKHPD xmm0, xmm1: 66 0F 15 C1
      add_xmm("unpckhpd", {0x66, 0x0F, 0x15, 0xC1}, s, 0x3);
    }

    // HADDPS / HSUBPS — horizontal add/subtract
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);
      // HADDPS xmm0, xmm1: F2 0F 7C C1
      add_xmm("haddps", {0xF2, 0x0F, 0x7C, 0xC1}, s, 0x3);
      // HSUBPS xmm0, xmm1: F2 0F 7D C1
      add_xmm("hsubps", {0xF2, 0x0F, 0x7D, 0xC1}, s, 0x3);
    }

    // HADDPD / HSUBPD
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_f64(1.0, 2.0);
      s.xmm[1] = xmm_from_f64(3.0, 4.0);
      // HADDPD xmm0, xmm1: 66 0F 7C C1
      add_xmm("haddpd", {0x66, 0x0F, 0x7C, 0xC1}, s, 0x3);
      // HSUBPD xmm0, xmm1: 66 0F 7D C1
      add_xmm("hsubpd", {0x66, 0x0F, 0x7D, 0xC1}, s, 0x3);
    }

    // ADDSUBPS / ADDSUBPD — alternating add/subtract
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
      s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      // ADDSUBPS xmm0, xmm1: F2 0F D0 C1
      add_xmm("addsubps", {0xF2, 0x0F, 0xD0, 0xC1}, s, 0x3);
    }
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_f64(10.0, 20.0);
      s.xmm[1] = xmm_from_f64(1.0, 2.0);
      // ADDSUBPD xmm0, xmm1: 66 0F D0 C1
      add_xmm("addsubpd", {0x66, 0x0F, 0xD0, 0xC1}, s, 0x3);
    }
  }

  // =====================================================================
  // FP Edge — bit manipulation and misc edge cases
  // =====================================================================
  {
    // POPCNT with edge values
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0;
      // POPCNT eax, ecx: F3 0F B8 C1
      add_xmm("popcnt 0", {0xF3, 0x0F, 0xB8, 0xC1}, s, 0x0);

      s.rcx = 0xFFFFFFFF;
      add_xmm("popcnt -1", {0xF3, 0x0F, 0xB8, 0xC1}, s, 0x0);

      s.rcx = 0x80000000;
      add_xmm("popcnt 0x80000000", {0xF3, 0x0F, 0xB8, 0xC1}, s, 0x0);

      s.rcx = 1;
      add_xmm("popcnt 1", {0xF3, 0x0F, 0xB8, 0xC1}, s, 0x0);

      // POPCNT rax, rcx (64-bit): F3 48 0F B8 C1
      s.rcx = 0xFFFFFFFFFFFFFFFF;
      add_xmm("popcnt64 -1", {0xF3, 0x48, 0x0F, 0xB8, 0xC1}, s, 0x0);

      s.rcx = 0x8000000000000000;
      add_xmm("popcnt64 msb", {0xF3, 0x48, 0x0F, 0xB8, 0xC1}, s, 0x0);
    }

    // LZCNT with edge values
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0;
      // LZCNT eax, ecx: F3 0F BD C1
      add_xmm("lzcnt 0", {0xF3, 0x0F, 0xBD, 0xC1}, s, 0x0);

      s.rcx = 1;
      add_xmm("lzcnt 1", {0xF3, 0x0F, 0xBD, 0xC1}, s, 0x0);

      s.rcx = 0x80000000;
      add_xmm("lzcnt msb", {0xF3, 0x0F, 0xBD, 0xC1}, s, 0x0);

      s.rcx = 0xFFFFFFFF;
      add_xmm("lzcnt -1", {0xF3, 0x0F, 0xBD, 0xC1}, s, 0x0);

      // LZCNT rax, rcx (64-bit): F3 48 0F BD C1
      s.rcx = 0;
      add_xmm("lzcnt64 0", {0xF3, 0x48, 0x0F, 0xBD, 0xC1}, s, 0x0);

      s.rcx = 1;
      add_xmm("lzcnt64 1", {0xF3, 0x48, 0x0F, 0xBD, 0xC1}, s, 0x0);
    }

    // TZCNT with edge values
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0;
      // TZCNT eax, ecx: F3 0F BC C1
      add_xmm("tzcnt 0", {0xF3, 0x0F, 0xBC, 0xC1}, s, 0x0);

      s.rcx = 0x80000000;
      add_xmm("tzcnt msb", {0xF3, 0x0F, 0xBC, 0xC1}, s, 0x0);

      s.rcx = 1;
      add_xmm("tzcnt 1", {0xF3, 0x0F, 0xBC, 0xC1}, s, 0x0);

      s.rcx = 0xFFFFFFFF;
      add_xmm("tzcnt -1", {0xF3, 0x0F, 0xBC, 0xC1}, s, 0x0);

      // TZCNT rax, rcx (64-bit): F3 48 0F BC C1
      s.rcx = 0x8000000000000000;
      add_xmm("tzcnt64 msb", {0xF3, 0x48, 0x0F, 0xBC, 0xC1}, s, 0x0);
    }

    // PCLMULQDQ — carry-less multiplication
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(0x0000000000000001, 0x0000000000000003);
      s.xmm[1] = xmm_from_u64(0x0000000000000001, 0x0000000000000007);
      // PCLMULQDQ xmm0, xmm1, imm8: 66 0F 3A 44 C1 imm
      // imm8[0] selects xmm0 qword (0=low, 1=high)
      // imm8[4] selects xmm1 qword (0=low, 1=high)
      add_xmm("pclmulqdq 0x00", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x00}, s, 0x3); // low×low
      add_xmm("pclmulqdq 0x01", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x01}, s, 0x3); // high×low
      add_xmm("pclmulqdq 0x10", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x10}, s, 0x3); // low×high
      add_xmm("pclmulqdq 0x11", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x11}, s, 0x3); // high×high
    }
    // PCLMULQDQ with larger values
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(0x8000000000000000, 0xFFFFFFFFFFFFFFFF);
      s.xmm[1] = xmm_from_u64(0x8000000000000000, 0x0000000000000002);
      add_xmm("pclmulqdq big 0x00", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x00}, s, 0x3);
      add_xmm("pclmulqdq big 0x11", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x11}, s, 0x3);
    }

    // PCMPISTRI — implicit-length string comparison, result in ECX
    {
      ArchState s;
      s.rflags = 0x2;
      // "ABCD" (null-terminated in bytes)
      s.xmm[0] = xmm_from_u32(0x44434241, 0x00000000, 0x00000000, 0x00000000);
      // "ABCE" (differs at byte 3)
      s.xmm[1] = xmm_from_u32(0x45434241, 0x00000000, 0x00000000, 0x00000000);
      // PCMPISTRI xmm0, xmm1, imm8: 66 0F 3A 63 C1 imm8
      // imm8=0x18: unsigned bytes, equal each, polarity positive, LSB index
      add_xmm("pcmpistri eq_each", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x18}, s, 0x0);
      // imm8=0x0C: unsigned bytes, equal ordered (substring search), LSB index
      add_xmm("pcmpistri eq_ord", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x0C}, s, 0x0);
    }

    // PCMPISTRI — equal strings
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u32(0x44434241, 0x00000000, 0x00000000, 0x00000000);
      s.xmm[1] = xmm_from_u32(0x44434241, 0x00000000, 0x00000000, 0x00000000);
      add_xmm("pcmpistri equal", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x18}, s, 0x0);
    }

    // PCMPISTRM — result in XMM0 as bitmask
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u32(0x44434241, 0x00000000, 0x00000000, 0x00000000);
      s.xmm[1] = xmm_from_u32(0x41414141, 0x42424242, 0x00000000, 0x00000000);
      // PCMPISTRM xmm0, xmm1, imm8: 66 0F 3A 62 C1 imm8
      // imm8=0x00: unsigned bytes, equal any, positive polarity, bitmask in xmm0
      add_xmm("pcmpistrm eq_any", {0x66, 0x0F, 0x3A, 0x62, 0xC1, 0x00}, s, 0x3);
    }

    // MOVBE — byte-swap load/store (test via register encoding)
    // We'll test BSWAP instead which is simpler
    {
      ArchState s;
      s.rflags = 0x2;
      s.rax = 0x0102030405060708;
      // BSWAP eax: 0F C8
      add_xmm("bswap eax", {0x0F, 0xC8}, s, 0x0);
      // BSWAP rax: 48 0F C8
      s.rax = 0x0102030405060708;
      add_xmm("bswap rax", {0x48, 0x0F, 0xC8}, with_gpr_inputs(s, {&ArchState::rax}), 0x0);
    }

    // BMI1: ANDN, BLSI, BLSMSK, BLSR, BEXTR
    // BMI flags: SF, ZF, CF defined; OF=0; PF, AF undefined
    {
      const u64 FL_BMI = FL_SF | FL_ZF | FL_OF | FL_CF;
      const u64 FL_BEXTR = FL_ZF | FL_OF | FL_CF;
      ArchState s;
      s.rflags = 0x2;
      s.rax = 0xAAAAAAAA55555555;
      s.rcx = 0x5555555500FF00FF;

      // ANDN eax, eax, ecx
      tests.push_back({"andn eax", cat, {0xC4, 0xE2, 0x78, 0xF2, 0xC1}, s, FL_BMI, 0x0, false});
      // ANDN rax, rax, rcx
      tests.push_back({"andn rax", cat, {0xC4, 0xE2, 0xF8, 0xF2, 0xC1}, s, FL_BMI, 0x0, false});

      // BLSI eax, ecx
      tests.push_back({"blsi eax", cat, {0xC4, 0xE2, 0x78, 0xF3, 0xD9},
          with_gpr_inputs(s, {&ArchState::rcx}), FL_BMI, 0x0, false});
      // BLSMSK eax, ecx
      tests.push_back({"blsmsk eax", cat, {0xC4, 0xE2, 0x78, 0xF3, 0xD1},
          with_gpr_inputs(s, {&ArchState::rcx}), FL_BMI, 0x0, false});
      // BLSR eax, ecx
      tests.push_back({"blsr eax", cat, {0xC4, 0xE2, 0x78, 0xF3, 0xC9},
          with_gpr_inputs(s, {&ArchState::rcx}), FL_BMI, 0x0, false});

      // Zero input edge cases
      s.rcx = 0;
      tests.push_back({"blsi 0", cat, {0xC4, 0xE2, 0x78, 0xF3, 0xD9},
          with_gpr_inputs(s, {&ArchState::rcx}), FL_BMI, 0x0, false});
      tests.push_back({"blsmsk 0", cat, {0xC4, 0xE2, 0x78, 0xF3, 0xD1},
          with_gpr_inputs(s, {&ArchState::rcx}), FL_BMI, 0x0, false});
      tests.push_back({"blsr 0", cat, {0xC4, 0xE2, 0x78, 0xF3, 0xC9},
          with_gpr_inputs(s, {&ArchState::rcx}), FL_BMI, 0x0, false});

      // BEXTR eax, ecx, eax
      s.rcx = 0xDEADBEEF;
      s.rax = 0x0810;  // start=16, len=8 → extract bits 23:16 = 0xAD
      tests.push_back({"bextr 16:8", cat, {0xC4, 0xE2, 0x78, 0xF7, 0xC1}, s, FL_BEXTR, 0x0, false});
      s.rax = 0x2000;  // start=0, len=32 → extract all 32 bits
      tests.push_back({"bextr 0:32", cat, {0xC4, 0xE2, 0x78, 0xF7, 0xC1}, s, FL_BEXTR, 0x0, false});
      s.rax = 0x0400;  // start=0, len=4 → extract bits 3:0 = 0xF
      tests.push_back({"bextr 0:4", cat, {0xC4, 0xE2, 0x78, 0xF7, 0xC1}, s, FL_BEXTR, 0x0, false});
    }

    // ADCX/ADOX: multi-precision add instructions
    // ADCX only modifies CF (preserves OF, SF, ZF, PF, AF)
    // ADOX only modifies OF (preserves CF, SF, ZF, PF, AF)
    // Encoding: 66 0F 38 F6 /r = ADCX; F3 0F 38 F6 /r = ADOX
    {
      cat = "ADCX/ADOX";

      // ADCX r32, r32: 66 0F 38 F6 modrm
      // ADCX eax, ecx: modrm = C1 (reg=0, rm=1)
      // ADOX r32, r32: F3 0F 38 F6 modrm
      // ADOX eax, ecx: modrm = C1

      // Test 1: simple add without carry, no overflow
      {
        ArchState s;
        s.rflags = 0x2;  // CF=0, OF=0
        s.rax = 100;
        s.rcx = 200;
        // ADCX eax, ecx (CF=0 in, result=300, CF=0 out)
        tests.push_back({"adcx eax no carry", cat, {0x66, 0x0F, 0x38, 0xF6, 0xC1}, s, FL_ALL, 0x0, false});
        // ADOX eax, ecx (OF=0 in, result=300, OF=0 out)
        tests.push_back({"adox eax no carry", cat, {0xF3, 0x0F, 0x38, 0xF6, 0xC1}, s, FL_ALL, 0x0, false});
      }

      // Test 2: carry-in = 1 for ADCX (set CF)
      {
        ArchState s;
        s.rflags = 0x2 | FL_CF;  // CF=1
        s.rax = 100;
        s.rcx = 200;
        // ADCX eax, ecx (CF=1 in, result=301, CF=0 out)
        tests.push_back({"adcx eax CF=1 in", cat, {0x66, 0x0F, 0x38, 0xF6, 0xC1}, s, FL_ALL, 0x0, false});
      }

      // Test 3: carry-in = 1 for ADOX (set OF)
      {
        ArchState s;
        s.rflags = 0x2 | FL_OF;  // OF=1
        s.rax = 100;
        s.rcx = 200;
        // ADOX eax, ecx (OF=1 in, result=301, OF=0 out)
        tests.push_back({"adox eax OF=1 in", cat, {0xF3, 0x0F, 0x38, 0xF6, 0xC1}, s, FL_ALL, 0x0, false});
      }

      // Test 4: 32-bit overflow (produces carry-out)
      {
        ArchState s;
        s.rflags = 0x2;
        s.rax = 0xFFFFFFFF;
        s.rcx = 1;
        // ADCX eax, ecx: 0xFFFFFFFF + 1 + 0 = 0x100000000 → eax=0, CF=1
        tests.push_back({"adcx eax overflow", cat, {0x66, 0x0F, 0x38, 0xF6, 0xC1}, s, FL_ALL, 0x0, false});
        // ADOX eax, ecx: same math but OF=1 out
        tests.push_back({"adox eax overflow", cat, {0xF3, 0x0F, 0x38, 0xF6, 0xC1}, s, FL_ALL, 0x0, false});
      }

      // Test 5: 32-bit overflow with carry-in = 1
      {
        ArchState s;
        s.rflags = 0x2 | FL_CF | FL_OF;  // both CF=1, OF=1
        s.rax = 0xFFFFFFFF;
        s.rcx = 0xFFFFFFFF;
        // ADCX eax, ecx: 0xFFFFFFFF + 0xFFFFFFFF + 1(CF) = 0x1FFFFFFFF → eax=0xFFFFFFFF, CF=1
        tests.push_back({"adcx eax max+max+1", cat, {0x66, 0x0F, 0x38, 0xF6, 0xC1}, s, FL_ALL, 0x0, false});
        // ADOX eax, ecx: same but uses OF
        tests.push_back({"adox eax max+max+1", cat, {0xF3, 0x0F, 0x38, 0xF6, 0xC1}, s, FL_ALL, 0x0, false});
      }

      // Test 6: 64-bit ADCX/ADOX (REX.W)
      // ADCX rax, rcx: 66 48 0F 38 F6 C1
      // ADOX rax, rcx: F3 48 0F 38 F6 C1
      {
        ArchState s;
        s.rflags = 0x2;
        s.rax = 0xFFFFFFFFFFFFFFFF;
        s.rcx = 1;
        // 64-bit overflow
        tests.push_back({"adcx rax overflow", cat, {0x66, 0x48, 0x0F, 0x38, 0xF6, 0xC1}, s, FL_ALL, 0x0, false});
        tests.push_back({"adox rax overflow", cat, {0xF3, 0x48, 0x0F, 0x38, 0xF6, 0xC1}, s, FL_ALL, 0x0, false});
      }

      // Test 7: ADCX preserves OF, ADOX preserves CF
      // Set both CF and OF, then run ADCX (should modify CF, preserve OF)
      {
        ArchState s;
        s.rflags = 0x2 | FL_CF | FL_OF;  // CF=1, OF=1
        s.rax = 100;
        s.rcx = 200;
        // ADCX: CF=1 in → 100+200+1=301, CF=0 out; OF should stay 1
        tests.push_back({"adcx preserves OF", cat, {0x66, 0x0F, 0x38, 0xF6, 0xC1}, s, FL_ALL, 0x0, false});
        // ADOX: OF=1 in → 100+200+1=301, OF=0 out; CF should stay 1
        tests.push_back({"adox preserves CF", cat, {0xF3, 0x0F, 0x38, 0xF6, 0xC1}, s, FL_ALL, 0x0, false});
      }

      // Test 8: ADCX/ADOX preserve SF, ZF, PF (set them before, check after)
      {
        ArchState s;
        s.rflags = 0x2 | FL_SF | FL_ZF | FL_PF;  // SF=1, ZF=1, PF=1
        s.rax = 100;
        s.rcx = 200;
        tests.push_back({"adcx preserves SZPF", cat, {0x66, 0x0F, 0x38, 0xF6, 0xC1}, s, FL_ALL, 0x0, false});
        tests.push_back({"adox preserves SZPF", cat, {0xF3, 0x0F, 0x38, 0xF6, 0xC1}, s, FL_ALL, 0x0, false});
      }

      // Test 9: chain ADCX then ADOX (both in one sequence)
      // ADCX eax, ecx; ADOX ebx, edx
      {
        ArchState s;
        s.rflags = 0x2 | FL_CF;  // CF=1, OF=0
        s.rax = 0xFFFFFFFF;
        s.rcx = 0xFFFFFFFF;
        s.rbx = 100;
        s.rdx = 200;
        // ADCX: 0xFFFFFFFF + 0xFFFFFFFF + 1 → eax=0xFFFFFFFF, CF=1
        // ADOX: 100 + 200 + 0(OF) → ebx=300, OF=0
        tests.push_back({"adcx+adox chain", cat,
          {0x66, 0x0F, 0x38, 0xF6, 0xC1,   // ADCX eax, ecx
           0xF3, 0x0F, 0x38, 0xF6, 0xDA},  // ADOX ebx, edx
          s, FL_ALL, 0x0, false});
      }

      // Test 10: 64-bit no overflow
      {
        ArchState s;
        s.rflags = 0x2;
        s.rax = 0x123456789ABCDEF0;
        s.rcx = 0x0000000000000001;
        tests.push_back({"adcx rax simple", cat, {0x66, 0x48, 0x0F, 0x38, 0xF6, 0xC1}, s, FL_ALL, 0x0, false});
        tests.push_back({"adox rax simple", cat, {0xF3, 0x48, 0x0F, 0x38, 0xF6, 0xC1}, s, FL_ALL, 0x0, false});
      }
    }

    // DAZ/FTZ: MXCSR Denormals-Are-Zeros and Flush-To-Zero modes
    {
      cat = "DAZ/FTZ";

      const u32 MXCSR_DAZ = 0x0040;  // bit 6: Denormals-Are-Zeros
      const u32 MXCSR_FTZ = 0x8000;  // bit 15: Flush-To-Zero
      const u32 MXCSR_DEFAULT = 0x1F80;  // default: all exceptions masked

      // Denormal f32 values
      const u32 F32_DENORM_MIN = 0x00000001;  // smallest positive denormal
      const u32 F32_DENORM_MAX = 0x007FFFFF;  // largest positive denormal
      const u32 F32_NEG_DENORM = 0x80000001;  // smallest negative denormal
      const u32 F32_ZERO = 0x00000000;         // +0.0f
      const u32 F32_NEG_ZERO = 0x80000000;    // -0.0f
      const u32 F32_ONE = 0x3F800000;         // 1.0f
      const u32 F32_TWO = 0x40000000;         // 2.0f
      const u32 F32_SMALL = 0x00800000;       // smallest positive normal (1.17549435e-38)

      // Helper: create XMM from raw u32 values
      auto xmm_raw = [](u32 a, u32 b, u32 c, u32 d) -> XmmVal {
        XmmVal v;
        v.lo = (u64)a | ((u64)b << 32);
        v.hi = (u64)c | ((u64)d << 32);
        return v;
      };

      // --- FTZ mode: denormal results get flushed to zero ---

      // ADDPS with FTZ: normal + normal that produces denormal result → flushed to ±0
      // smallest_normal - smallest_normal = 0 (exact), not a good test
      // Instead: smallest_normal * 0.5 → denormal result → flushed to zero
      // MULPS xmm0, xmm1: 0F 59 C1
      {
        ArchState s;
        s.rflags = 0x2;
        s.mxcsr = MXCSR_DEFAULT | MXCSR_FTZ;
        // smallest normal * 0.5 = denormal → should flush to +0
        const u32 F32_HALF = 0x3F000000;  // 0.5f
        s.xmm[0] = xmm_raw(F32_SMALL, F32_SMALL, F32_SMALL, F32_SMALL);
        s.xmm[1] = xmm_raw(F32_HALF, F32_HALF, F32_HALF, F32_HALF);
        tests.push_back({"mulps FTZ flush", cat, {0x0F, 0x59, 0xC1}, s, FL_ALL, 0x3, true});
      }

      // SUBPS with FTZ: two close normals → denormal result → flushed
      // SUBPS xmm0, xmm1: 0F 5C C1
      {
        ArchState s;
        s.rflags = 0x2;
        s.mxcsr = MXCSR_DEFAULT | MXCSR_FTZ;
        // Two very close small normals, difference is denormal
        const u32 F32_SMALL_PLUS1 = F32_SMALL + 1;  // next representable after smallest normal
        s.xmm[0] = xmm_raw(F32_SMALL_PLUS1, F32_SMALL_PLUS1, F32_SMALL_PLUS1, F32_SMALL_PLUS1);
        s.xmm[1] = xmm_raw(F32_SMALL, F32_SMALL, F32_SMALL, F32_SMALL);
        tests.push_back({"subps FTZ flush", cat, {0x0F, 0x5C, 0xC1}, s, FL_ALL, 0x3, true});
      }

      // Without FTZ, same operation should produce a denormal
      {
        ArchState s;
        s.rflags = 0x2;
        s.mxcsr = MXCSR_DEFAULT;  // FTZ=0
        const u32 F32_SMALL_PLUS1 = F32_SMALL + 1;
        s.xmm[0] = xmm_raw(F32_SMALL_PLUS1, F32_SMALL_PLUS1, F32_SMALL_PLUS1, F32_SMALL_PLUS1);
        s.xmm[1] = xmm_raw(F32_SMALL, F32_SMALL, F32_SMALL, F32_SMALL);
        tests.push_back({"subps no FTZ denorm", cat, {0x0F, 0x5C, 0xC1}, s, FL_ALL, 0x3, true});
      }

      // --- DAZ mode: denormal inputs treated as zero ---

      // ADDPS with DAZ: denormal + 1.0 → should produce 1.0 (denormal treated as 0)
      // ADDPS xmm0, xmm1: 0F 58 C1
      {
        ArchState s;
        s.rflags = 0x2;
        s.mxcsr = MXCSR_DEFAULT | MXCSR_DAZ;
        s.xmm[0] = xmm_raw(F32_DENORM_MIN, F32_DENORM_MAX, F32_NEG_DENORM, F32_DENORM_MIN);
        s.xmm[1] = xmm_raw(F32_ONE, F32_ONE, F32_ONE, F32_TWO);
        tests.push_back({"addps DAZ denorm+1", cat, {0x0F, 0x58, 0xC1}, s, FL_ALL, 0x3, true});
      }

      // Without DAZ, denormal + 1.0 → 1.0 + tiny (slightly more than 1.0)
      {
        ArchState s;
        s.rflags = 0x2;
        s.mxcsr = MXCSR_DEFAULT;  // DAZ=0
        s.xmm[0] = xmm_raw(F32_DENORM_MIN, F32_DENORM_MAX, F32_NEG_DENORM, F32_DENORM_MIN);
        s.xmm[1] = xmm_raw(F32_ONE, F32_ONE, F32_ONE, F32_TWO);
        tests.push_back({"addps no DAZ denorm+1", cat, {0x0F, 0x58, 0xC1}, s, FL_ALL, 0x3, true});
      }

      // MULPS with DAZ: denormal * 2.0 → should produce 0 (denormal treated as 0)
      {
        ArchState s;
        s.rflags = 0x2;
        s.mxcsr = MXCSR_DEFAULT | MXCSR_DAZ;
        s.xmm[0] = xmm_raw(F32_DENORM_MIN, F32_DENORM_MAX, F32_NEG_DENORM, F32_DENORM_MAX);
        s.xmm[1] = xmm_raw(F32_TWO, F32_TWO, F32_TWO, F32_TWO);
        tests.push_back({"mulps DAZ denorm*2", cat, {0x0F, 0x59, 0xC1}, s, FL_ALL, 0x3, true});
      }

      // MINPS with DAZ: denormal vs 0 → both treated as 0
      // MINPS xmm0, xmm1: 0F 5D C1
      {
        ArchState s;
        s.rflags = 0x2;
        s.mxcsr = MXCSR_DEFAULT | MXCSR_DAZ;
        s.xmm[0] = xmm_raw(F32_DENORM_MIN, F32_ZERO, F32_NEG_DENORM, F32_DENORM_MAX);
        s.xmm[1] = xmm_raw(F32_ZERO, F32_DENORM_MIN, F32_ZERO, F32_NEG_ZERO);
        tests.push_back({"minps DAZ denorm vs 0", cat, {0x0F, 0x5D, 0xC1}, s, FL_ALL, 0x3, true});
      }

      // MAXPS with DAZ
      {
        ArchState s;
        s.rflags = 0x2;
        s.mxcsr = MXCSR_DEFAULT | MXCSR_DAZ;
        s.xmm[0] = xmm_raw(F32_DENORM_MIN, F32_DENORM_MAX, F32_NEG_DENORM, F32_DENORM_MIN);
        s.xmm[1] = xmm_raw(F32_ZERO, F32_ZERO, F32_ZERO, F32_ONE);
        tests.push_back({"maxps DAZ denorm vs 0", cat, {0x0F, 0x5F, 0xC1}, s, FL_ALL, 0x3, true});
      }

      // CMPPS with DAZ: denormal == 0? (both treated as zero → true)
      // CMPPS xmm0, xmm1, 0 (EQ): 0F C2 C1 00
      {
        ArchState s;
        s.rflags = 0x2;
        s.mxcsr = MXCSR_DEFAULT | MXCSR_DAZ;
        s.xmm[0] = xmm_raw(F32_DENORM_MIN, F32_DENORM_MAX, F32_NEG_DENORM, F32_ZERO);
        s.xmm[1] = xmm_raw(F32_ZERO, F32_ZERO, F32_ZERO, F32_DENORM_MIN);
        tests.push_back({"cmpps DAZ eq denorm==0", cat, {0x0F, 0xC2, 0xC1, 0x00}, s, FL_ALL, 0x3, true});
      }

      // SQRTPS with DAZ: sqrt(denormal) → sqrt(0) = 0
      // SQRTPS xmm0, xmm1: 0F 51 C1
      {
        ArchState s;
        s.rflags = 0x2;
        s.mxcsr = MXCSR_DEFAULT | MXCSR_DAZ;
        s.xmm[1] = xmm_raw(F32_DENORM_MIN, F32_DENORM_MAX, F32_ZERO, F32_ONE);
        tests.push_back({"sqrtps DAZ denorm", cat, {0x0F, 0x51, 0xC1}, s, FL_ALL, 0x3, true});
      }

      // CVTPS2DQ with DAZ: denormal → treated as 0 → converts to integer 0
      // CVTPS2DQ xmm0, xmm1: 66 0F 5B C1
      {
        ArchState s;
        s.rflags = 0x2;
        s.mxcsr = MXCSR_DEFAULT | MXCSR_DAZ;
        s.xmm[1] = xmm_raw(F32_DENORM_MIN, F32_DENORM_MAX, F32_NEG_DENORM, F32_ONE);
        tests.push_back({"cvtps2dq DAZ denorm", cat, {0x66, 0x0F, 0x5B, 0xC1}, s, FL_ALL, 0x3, true});
      }

      // DAZ + FTZ combined
      {
        ArchState s;
        s.rflags = 0x2;
        s.mxcsr = MXCSR_DEFAULT | MXCSR_DAZ | MXCSR_FTZ;
        const u32 F32_HALF = 0x3F000000;
        s.xmm[0] = xmm_raw(F32_DENORM_MAX, F32_SMALL, F32_DENORM_MIN, F32_ONE);
        s.xmm[1] = xmm_raw(F32_TWO, F32_HALF, F32_ONE, F32_HALF);
        // lane 0: denorm(→0)*2=0, lane 1: smallest_normal*0.5=denorm→flush to 0
        // lane 2: denorm(→0)*1=0, lane 3: 1.0*0.5=0.5 (normal, no flush)
        tests.push_back({"mulps DAZ+FTZ", cat, {0x0F, 0x59, 0xC1}, s, FL_ALL, 0x3, true});
      }

      // UCOMISS with DAZ: denormal vs 0 → equal (both treated as 0)
      // UCOMISS xmm0, xmm1: 0F 2E C1
      {
        ArchState s;
        s.rflags = 0x2;
        s.mxcsr = MXCSR_DEFAULT | MXCSR_DAZ;
        s.xmm[0] = xmm_raw(F32_DENORM_MAX, 0, 0, 0);
        s.xmm[1] = xmm_raw(F32_ZERO, 0, 0, 0);
        tests.push_back({"ucomiss DAZ denorm==0", cat, {0x0F, 0x2E, 0xC1}, s, FL_ALL, 0x0, true});
      }

      // DIVPS with FTZ: very small / very large → denormal → flush to 0
      // DIVPS xmm0, xmm1: 0F 5E C1
      {
        ArchState s;
        s.rflags = 0x2;
        s.mxcsr = MXCSR_DEFAULT | MXCSR_FTZ;
        s.xmm[0] = xmm_raw(F32_SMALL, F32_SMALL, F32_ONE, F32_ONE);
        const u32 F32_LARGE = 0x7E800000;  // 8.507059e37 (large normal)
        s.xmm[1] = xmm_raw(F32_LARGE, F32_LARGE, F32_ONE, F32_TWO);
        tests.push_back({"divps FTZ flush", cat, {0x0F, 0x5E, 0xC1}, s, FL_ALL, 0x3, true});
      }

      // f64 denormals with DAZ
      // ADDPD xmm0, xmm1: 66 0F 58 C1
      {
        ArchState s;
        s.rflags = 0x2;
        s.mxcsr = MXCSR_DEFAULT | MXCSR_DAZ;
        const u64 F64_DENORM = 0x0000000000000001;  // smallest positive denormal
        const u64 F64_ONE    = 0x3FF0000000000000;   // 1.0
        s.xmm[0] = xmm_from_u64(F64_DENORM, F64_DENORM);
        s.xmm[1] = xmm_from_u64(F64_ONE, F64_ONE);
        tests.push_back({"addpd DAZ denorm+1", cat, {0x66, 0x0F, 0x58, 0xC1}, s, FL_ALL, 0x3, true});
      }
    }

    // Operand size edge cases: 16-bit operand size prefix (0x66)
    {
      cat = "OpSize Edge";

      // 16-bit ADD: 66 01 C8 = ADD AX, CX
      {
        ArchState s;
        s.rflags = 0x2;
        s.rax = 0xDEAD0000BEEF7FFF;
        s.rcx = 0x1234567800000001;
        // ADD AX, CX: AX=0x7FFF+0x0001=0x8000 (16-bit overflow), upper bits of RAX preserved
        tests.push_back({"add ax,cx overflow", cat, {0x66, 0x01, 0xC8}, s, FL_ALL, 0x0, false});
      }

      // 16-bit SUB: 66 29 C8 = SUB AX, CX
      {
        ArchState s;
        s.rflags = 0x2;
        s.rax = 0xDEAD0000BEEF0000;
        s.rcx = 0x1234567800000001;
        // SUB AX, CX: AX=0x0000-0x0001=0xFFFF (borrow), upper bits preserved
        tests.push_back({"sub ax,cx borrow", cat, {0x66, 0x29, 0xC8}, s, FL_ALL, 0x0, false});
      }

      // 16-bit IMUL r16, r/m16: 66 0F AF C1 = IMUL AX, CX
      {
        ArchState s;
        s.rflags = 0x2;
        s.rax = 0xDEAD0000BEEF0100;  // AX=0x0100 (256)
        s.rcx = 0x1234567800000100;  // CX=0x0100 (256)
        // IMUL AX, CX: 256*256=65536 → AX=0x0000 (low 16 bits), CF=OF=1
        tests.push_back({"imul ax,cx 16b ovfl", cat, {0x66, 0x0F, 0xAF, 0xC1}, s, FL_CF | FL_OF, 0x0, false});
      }

      // 16-bit MOVZX r16, r/m8: 66 0F B6 C1 = MOVZX AX, CL
      {
        ArchState s;
        s.rflags = 0x2;
        s.rax = 0xDEAD0000BEEFAAAA;
        s.rcx = 0x00000000000000FF;
        // MOVZX AX, CL: AX=0x00FF, upper bits of RAX preserved
        tests.push_back({"movzx ax,cl 16b", cat, {0x66, 0x0F, 0xB6, 0xC1},
            with_gpr_inputs(s, {&ArchState::rcx}), FL_ALL, 0x0, false});
      }

      // 16-bit SHL: 66 D1 E0 = SHL AX, 1
      {
        ArchState s;
        s.rflags = 0x2;
        s.rax = 0xDEAD0000BEEFC000;  // AX=0xC000
        // SHL AX, 1: AX = 0x8000, CF=1 (bit 15 shifted out), OF=1 (sign changed)
        // AF is undefined for SHL
        tests.push_back({"shl ax,1 16b", cat, {0x66, 0xD1, 0xE0}, s, FL_NO_AF, 0x0, false});
      }

      // 16-bit CMP: 66 39 C8 = CMP AX, CX
      {
        ArchState s;
        s.rflags = 0x2;
        s.rax = 0xDEAD0000BEEF8000;  // AX=0x8000 (-32768 signed)
        s.rcx = 0x1234567800007FFF;  // CX=0x7FFF (+32767 signed)
        // CMP AX, CX: 0x8000-0x7FFF → flags from 16-bit comparison
        tests.push_back({"cmp ax,cx 16b sign", cat, {0x66, 0x39, 0xC8}, s, FL_ALL, 0x0, false});
      }

      // 16-bit INC/DEC: 66 FF C0 = INC AX
      {
        ArchState s;
        s.rflags = 0x2 | FL_CF;  // CF=1, should be preserved
        s.rax = 0xDEAD0000BEEFFFFF;  // AX=0xFFFF
        // INC AX: 0xFFFF+1=0x0000 (16-bit wrap), CF preserved
        tests.push_back({"inc ax 16b wrap", cat, {0x66, 0xFF, 0xC0}, s, FL_ALL, 0x0, false});
      }

      // 16-bit XCHG: 66 91 = XCHG AX, CX
      {
        ArchState s;
        s.rflags = 0x2;
        s.rax = 0xDEAD0000BEEF1234;  // AX=0x1234
        s.rcx = 0x1234567800005678;  // CX=0x5678
        tests.push_back({"xchg ax,cx 16b", cat, {0x66, 0x91}, s, FL_ALL, 0x0, false});
      }
    }
  }
}

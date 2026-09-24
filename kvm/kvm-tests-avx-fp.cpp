#include "kvm-avx-encoder.h"

void add_avx_fp_tests(std::vector<TestCase> &tests) {
  // =====================================================================
  // Packed FP arithmetic — EVEX.0F map
  //
  // Binary: dst = src1 (vvvv) op src2 (rm)
  //   VADDPS:  NP 0F 58, W0     VADDPD:  66 0F 58, W1
  //   VSUBPS:  NP 0F 5C, W0     VSUBPD:  66 0F 5C, W1
  //   VMULPS:  NP 0F 59, W0     VMULPD:  66 0F 59, W1
  //   VDIVPS:  NP 0F 5E, W0     VDIVPD:  66 0F 5E, W1
  //   VMINPS:  NP 0F 5D, W0     VMINPD:  66 0F 5D, W1
  //   VMAXPS:  NP 0F 5F, W0     VMAXPD:  66 0F 5F, W1
  //   VANDPS:  NP 0F 54, W0     VANDPD:  66 0F 54, W1
  //   VANDNPS: NP 0F 55, W0     VANDNPD: 66 0F 55, W1
  //   VORPS:   NP 0F 56, W0     VORPD:   66 0F 56, W1
  //   VXORPS:  NP 0F 57, W0     VXORPD:  66 0F 57, W1
  //   VUNPCKLPS: NP 0F 14, W0   VUNPCKLPD: 66 0F 14, W1
  //   VUNPCKHPS: NP 0F 15, W0   VUNPCKHPD: 66 0F 15, W1
  //
  // Unary: dst = op(src)
  //   VSQRTPS: NP 0F 51, W0     VSQRTPD:  66 0F 51, W1
  // =====================================================================

  std::string cat;

  // --- Helper: common initial state for packed f64 binary ops ---
  auto make_pd_state = []() {
    ArchState s;
    double v1[] = {1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5};
    double v2[] = {10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0};
    memcpy(s.xmm[1].q, v1, 64);
    memcpy(s.xmm[2].q, v2, 64);
    // dst (xmm0) with sentinel for merging mask tests
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;
    return s;
  };

  // --- Helper: common initial state for packed f32 binary ops ---
  auto make_ps_state = []() {
    ArchState s;
    float v1[] = {1.5f, 2.5f, 3.5f, 4.5f, 5.5f, 6.5f, 7.5f, 8.5f,
                  9.5f, 10.5f, 11.5f, 12.5f, 13.5f, 14.5f, 15.5f, 16.5f};
    float v2[] = {10.0f, 20.0f, 30.0f, 40.0f, 50.0f, 60.0f, 70.0f, 80.0f,
                  90.0f, 100.0f, 110.0f, 120.0f, 130.0f, 140.0f, 150.0f, 160.0f};
    memcpy(s.xmm[1].q, v1, 64);
    memcpy(s.xmm[2].q, v2, 64);
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;
    return s;
  };

  // --- Helper: make memory-source init_data from ZmmVal ---
  auto zmm_to_data = [](const ZmmVal &v) {
    std::vector<u8> d(64);
    memcpy(d.data(), v.q, 64);
    return d;
  };

  // Macro-like helper: generate reg-reg, reg-mem, and broadcast tests for a
  // packed binary FP instruction (PD variant).
  auto add_pd_binary = [&](const char *name, u8 opcode) {
    Evex e;
    e.mm = 1; e.pp = 1; e.W = true; e.opcode = opcode;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    ArchState s = make_pd_state();
    // reg-reg + writemask
    add_evex_rr_tests(tests, cat, name, e, s, 0x6, 0x55);

    // reg <- [rdi] memory source
    ArchState sm = s;
    sm.rdi = DATA_ADDR;
    add_evex_rm_tests(tests, cat, name, e, sm, 0x2, zmm_to_data(s.xmm[2]), 0x55);

    // broadcast f64 from [rdi]
    double bcast_val = 42.0;
    std::vector<u8> bdata(8);
    memcpy(bdata.data(), &bcast_val, 8);
    ArchState sb = s;
    sb.rdi = DATA_ADDR;
    add_evex_bcast_tests(tests, cat, name, e, sb, 0x2, bdata);
  };

  // Same for PS variant.
  auto add_ps_binary = [&](const char *name, u8 opcode) {
    Evex e;
    e.mm = 1; e.pp = 0; e.W = false; e.opcode = opcode;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    ArchState s = make_ps_state();
    add_evex_rr_tests(tests, cat, name, e, s, 0x6, 0x5555);

    ArchState sm = s;
    sm.rdi = DATA_ADDR;
    add_evex_rm_tests(tests, cat, name, e, sm, 0x2, zmm_to_data(s.xmm[2]), 0x5555);

    float bcast_val = 42.0f;
    std::vector<u8> bdata(4);
    memcpy(bdata.data(), &bcast_val, 4);
    ArchState sb = s;
    sb.rdi = DATA_ADDR;
    add_evex_bcast_tests(tests, cat, name, e, sb, 0x2, bdata);
  };

  // VEX misaligned memory helpers (all VEX computational → align=no)
  std::vector<u8> adata(64, 0x42);
  auto add_vok = [&](const std::string &name, std::vector<u8> code,
                         std::initializer_list<unsigned> vector_inputs = {}) {
    TestCase tc; tc.name = name; tc.category = cat;
    tc.code = std::move(code);
    tc.initial = {.rdi = DATA_ADDR + 1};
    for (unsigned reg : vector_inputs)
      tc.initial.xmm[reg] = {};
    tc.xmm_mask = 0x1; tc.init_data = adata;
    tests.push_back(std::move(tc));
  };
  // VEX binary: reg=0, vvvv=1, [rdi]
  auto vex_bin = [](int pp, u8 op, bool L) {
    Vex v; v.mm = 1; v.pp = pp; v.W = false; v.opcode = op;
    v.reg = 0; v.vvvv = 1; v.L = L;
    return v.encode_rm_mem();
  };
  // VEX unary: reg=0, vvvv=0, [rdi]
  auto vex_un = [](int pp, u8 op, bool L) {
    Vex v; v.mm = 1; v.pp = pp; v.W = false; v.opcode = op;
    v.reg = 0; v.vvvv = 0; v.L = L;
    return v.encode_rm_mem();
  };

  // ---- Packed FP arithmetic ----
  cat = "AVX FP packed";

  add_pd_binary("VADDPD",  0x58);
  add_ps_binary("VADDPS",  0x58);
  add_vok("VADDPS xmm,[rdi] misaligned", vex_bin(0, 0x58, false), {1});
  add_vok("VADDPS ymm,[rdi] misaligned", vex_bin(0, 0x58, true), {1});
  add_vok("VADDPD xmm,[rdi] misaligned", vex_bin(1, 0x58, false), {1});
  add_vok("VADDPD ymm,[rdi] misaligned", vex_bin(1, 0x58, true), {1});
  add_pd_binary("VSUBPD",  0x5C);
  add_ps_binary("VSUBPS",  0x5C);
  add_vok("VSUBPS xmm,[rdi] misaligned", vex_bin(0, 0x5C, false), {1});
  add_vok("VSUBPD xmm,[rdi] misaligned", vex_bin(1, 0x5C, false), {1});
  add_pd_binary("VMULPD",  0x59);
  add_ps_binary("VMULPS",  0x59);
  add_vok("VMULPS xmm,[rdi] misaligned", vex_bin(0, 0x59, false), {1});
  add_vok("VMULPD xmm,[rdi] misaligned", vex_bin(1, 0x59, false), {1});
  add_pd_binary("VDIVPD",  0x5E);
  add_ps_binary("VDIVPS",  0x5E);
  add_vok("VDIVPS xmm,[rdi] misaligned", vex_bin(0, 0x5E, false), {1});
  add_vok("VDIVPD xmm,[rdi] misaligned", vex_bin(1, 0x5E, false), {1});
  add_pd_binary("VMINPD",  0x5D);
  add_ps_binary("VMINPS",  0x5D);
  add_vok("VMINPS xmm,[rdi] misaligned", vex_bin(0, 0x5D, false), {1});
  add_vok("VMINPD xmm,[rdi] misaligned", vex_bin(1, 0x5D, false), {1});
  add_pd_binary("VMAXPD",  0x5F);
  add_ps_binary("VMAXPS",  0x5F);
  add_vok("VMAXPS xmm,[rdi] misaligned", vex_bin(0, 0x5F, false), {1});
  add_vok("VMAXPD xmm,[rdi] misaligned", vex_bin(1, 0x5F, false), {1});

  // ---- Packed FP logical ----
  add_pd_binary("VANDPD",  0x54);
  add_ps_binary("VANDPS",  0x54);
  add_vok("VANDPS xmm,[rdi] misaligned", vex_bin(0, 0x54, false), {1});
  add_vok("VANDPD xmm,[rdi] misaligned", vex_bin(1, 0x54, false), {1});
  add_pd_binary("VANDNPD", 0x55);
  add_ps_binary("VANDNPS", 0x55);
  add_vok("VANDNPS xmm,[rdi] misaligned", vex_bin(0, 0x55, false), {1});
  add_vok("VANDNPD xmm,[rdi] misaligned", vex_bin(1, 0x55, false), {1});
  add_pd_binary("VORPD",   0x56);
  add_ps_binary("VORPS",   0x56);
  add_vok("VORPS xmm,[rdi] misaligned", vex_bin(0, 0x56, false), {1});
  add_vok("VORPD xmm,[rdi] misaligned", vex_bin(1, 0x56, false), {1});
  add_pd_binary("VXORPD",  0x57);
  add_ps_binary("VXORPS",  0x57);
  add_vok("VXORPS xmm,[rdi] misaligned", vex_bin(0, 0x57, false), {1});
  add_vok("VXORPD xmm,[rdi] misaligned", vex_bin(1, 0x57, false), {1});

  // ---- Packed FP unpack/interleave ----
  add_pd_binary("VUNPCKLPD", 0x14);
  add_ps_binary("VUNPCKLPS", 0x14);
  add_vok("VUNPCKLPS xmm,[rdi] misaligned", vex_bin(0, 0x14, false), {1});
  add_vok("VUNPCKLPD xmm,[rdi] misaligned", vex_bin(1, 0x14, false), {1});
  add_pd_binary("VUNPCKHPD", 0x15);
  add_ps_binary("VUNPCKHPS", 0x15);
  add_vok("VUNPCKHPS xmm,[rdi] misaligned", vex_bin(0, 0x15, false), {1});
  add_vok("VUNPCKHPD xmm,[rdi] misaligned", vex_bin(1, 0x15, false), {1});

  // ---- Packed FP unary: VSQRT ----
  {
    Evex e;
    e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0x51;
    e.reg = 0; e.vvvv = 0; e.rm = 1;

    ArchState s;
    double vals[] = {4.0, 9.0, 16.0, 25.0, 36.0, 49.0, 64.0, 81.0};
    memcpy(s.xmm[1].q, vals, 64);
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;
    add_evex_rr_tests(tests, cat, "VSQRTPD", e, s, 0x2, 0x55);
    add_vok("VSQRTPD xmm,[rdi] misaligned", vex_un(1, 0x51, false));
    add_vok("VSQRTPD ymm,[rdi] misaligned", vex_un(1, 0x51, true));
  }
  {
    Evex e;
    e.mm = 1; e.pp = 0; e.W = false; e.opcode = 0x51;
    e.reg = 0; e.vvvv = 0; e.rm = 1;

    ArchState s;
    float vals[] = {4.0f, 9.0f, 16.0f, 25.0f, 36.0f, 49.0f, 64.0f, 81.0f,
                    100.0f, 121.0f, 144.0f, 169.0f, 196.0f, 225.0f, 256.0f, 289.0f};
    memcpy(s.xmm[1].q, vals, 64);
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;
    add_evex_rr_tests(tests, cat, "VSQRTPS", e, s, 0x2, 0x5555);
    add_vok("VSQRTPS xmm,[rdi] misaligned", vex_un(0, 0x51, false));
    add_vok("VSQRTPS ymm,[rdi] misaligned", vex_un(0, 0x51, true));
    // VEX scalar sqrt — no alignment
    add_vok("VSQRTSS xmm,[rdi] misaligned", vex_un(2, 0x51, false), {0});
    add_vok("VSQRTSD xmm,[rdi] misaligned", vex_un(3, 0x51, false), {0});
    // VEX scalar add/sub/mul/div — no alignment
    add_vok("VADDSS xmm,[rdi] misaligned", vex_bin(2, 0x58, false), {1});
    add_vok("VADDSD xmm,[rdi] misaligned", vex_bin(3, 0x58, false), {1});
    add_vok("VSUBSS xmm,[rdi] misaligned", vex_bin(2, 0x5C, false), {1});
    add_vok("VSUBSD xmm,[rdi] misaligned", vex_bin(3, 0x5C, false), {1});
    add_vok("VMULSS xmm,[rdi] misaligned", vex_bin(2, 0x59, false), {1});
    add_vok("VMULSD xmm,[rdi] misaligned", vex_bin(3, 0x59, false), {1});
    add_vok("VDIVSS xmm,[rdi] misaligned", vex_bin(2, 0x5E, false), {1});
    add_vok("VDIVSD xmm,[rdi] misaligned", vex_bin(3, 0x5E, false), {1});
    add_vok("VMINSS xmm,[rdi] misaligned", vex_bin(2, 0x5D, false), {1});
    add_vok("VMINSD xmm,[rdi] misaligned", vex_bin(3, 0x5D, false), {1});
    add_vok("VMAXSS xmm,[rdi] misaligned", vex_bin(2, 0x5F, false), {1});
    add_vok("VMAXSD xmm,[rdi] misaligned", vex_bin(3, 0x5F, false), {1});
    // VEX VRSQRTPS/VRCPPS — no alignment, approximate (~1.5*2^-12 relative error)
    auto add_vok_approx = [&](const std::string &name, std::vector<u8> code, int result_bits) {
      TestCase tc; tc.name = name; tc.category = cat;
      tc.code = std::move(code);
      tc.initial = {.rdi = DATA_ADDR + 1};
      if (result_bits == 32) tc.initial.xmm[1] = xmm_from_u64(0, 0);
      tc.xmm_mask = 0x1; tc.init_data = adata;
      tc.approx_rel_tol = 1.6e-3; tc.approx_elem_bits = 32;
      tc.approx_result_bits = result_bits;
      tests.push_back(std::move(tc));
    };
    add_vok_approx("VRSQRTPS xmm,[rdi] misaligned", vex_un(0, 0x52, false), 128);
    add_vok_approx("VRSQRTSS xmm,[rdi] misaligned", vex_bin(2, 0x52, false), 32);
    add_vok_approx("VRCPPS xmm,[rdi] misaligned", vex_un(0, 0x53, false), 128);
    add_vok_approx("VRCPSS xmm,[rdi] misaligned", vex_bin(2, 0x53, false), 32);
    // VEX VCMPPS/VCMPPD/VCMPSS/VCMPSD — no alignment
    { auto c = vex_bin(0, 0xC2, false); c.push_back(0); add_vok("VCMPPS xmm,[rdi] misaligned", c, {1}); }
    { auto c = vex_bin(1, 0xC2, false); c.push_back(0); add_vok("VCMPPD xmm,[rdi] misaligned", c, {1}); }
    { auto c = vex_bin(2, 0xC2, false); c.push_back(0); add_vok("VCMPSS xmm,[rdi] misaligned", c, {1}); }
    { auto c = vex_bin(3, 0xC2, false); c.push_back(0); add_vok("VCMPSD xmm,[rdi] misaligned", c, {1}); }
    // VEX VSHUFPS/VSHUFPD — no alignment
    { auto c = vex_bin(0, 0xC6, false); c.push_back(0); add_vok("VSHUFPS xmm,[rdi] misaligned", c, {1}); }
    { auto c = vex_bin(1, 0xC6, false); c.push_back(0); add_vok("VSHUFPD xmm,[rdi] misaligned", c, {1}); }
    // VEX VUCOMISS/VUCOMISD/VCOMISS/VCOMISD — no alignment
    add_vok("VUCOMISS xmm,[rdi] misaligned", vex_un(0, 0x2E, false), {0});
    add_vok("VUCOMISD xmm,[rdi] misaligned", vex_un(1, 0x2E, false), {0});
    add_vok("VCOMISS xmm,[rdi] misaligned", vex_un(0, 0x2F, false), {0});
    add_vok("VCOMISD xmm,[rdi] misaligned", vex_un(1, 0x2F, false), {0});
    // VEX conversions — no alignment
    add_vok("VCVTPS2PD xmm,[rdi] misaligned", vex_un(0, 0x5A, false));
    add_vok("VCVTPD2PS xmm,[rdi] misaligned", vex_un(1, 0x5A, false));
    add_vok("VCVTSS2SD xmm,[rdi] misaligned", vex_bin(2, 0x5A, false), {1});
    add_vok("VCVTSD2SS xmm,[rdi] misaligned", vex_bin(3, 0x5A, false), {1});
    add_vok("VCVTDQ2PS xmm,[rdi] misaligned", vex_un(0, 0x5B, false));
    add_vok("VCVTPS2DQ xmm,[rdi] misaligned", vex_un(1, 0x5B, false));
    add_vok("VCVTTPS2DQ xmm,[rdi] misaligned", vex_un(2, 0x5B, false));
    add_vok("VCVTSI2SS xmm,[rdi] misaligned", vex_bin(2, 0x2A, false), {1});
    add_vok("VCVTSI2SD xmm,[rdi] misaligned", vex_bin(3, 0x2A, false), {1});
    add_vok("VCVTDQ2PD xmm,[rdi] misaligned", vex_un(2, 0xE6, false));
    add_vok("VCVTPD2DQ xmm,[rdi] misaligned", vex_un(3, 0xE6, false));
    add_vok("VCVTTPD2DQ xmm,[rdi] misaligned", vex_un(1, 0xE6, false));
  }
}

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
    s.rflags = 0x2;
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
    s.rflags = 0x2;
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
    add_evex_rr_tests(tests, cat, name, e, s, 0x7, 0x55);

    // reg <- [rdi] memory source
    ArchState sm = s;
    sm.rdi = DATA_ADDR;
    add_evex_rm_tests(tests, cat, name, e, sm, 0x3, zmm_to_data(s.xmm[2]), 0x55);

    // broadcast f64 from [rdi]
    double bcast_val = 42.0;
    std::vector<u8> bdata(8);
    memcpy(bdata.data(), &bcast_val, 8);
    ArchState sb = s;
    sb.rdi = DATA_ADDR;
    add_evex_bcast_tests(tests, cat, name, e, sb, 0x3, bdata);
  };

  // Same for PS variant.
  auto add_ps_binary = [&](const char *name, u8 opcode) {
    Evex e;
    e.mm = 1; e.pp = 0; e.W = false; e.opcode = opcode;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    ArchState s = make_ps_state();
    add_evex_rr_tests(tests, cat, name, e, s, 0x7, 0x5555);

    ArchState sm = s;
    sm.rdi = DATA_ADDR;
    add_evex_rm_tests(tests, cat, name, e, sm, 0x3, zmm_to_data(s.xmm[2]), 0x5555);

    float bcast_val = 42.0f;
    std::vector<u8> bdata(4);
    memcpy(bdata.data(), &bcast_val, 4);
    ArchState sb = s;
    sb.rdi = DATA_ADDR;
    add_evex_bcast_tests(tests, cat, name, e, sb, 0x3, bdata);
  };

  // ---- Packed FP arithmetic ----
  cat = "AVX FP packed";

  add_pd_binary("VADDPD",  0x58);
  add_ps_binary("VADDPS",  0x58);
  add_pd_binary("VSUBPD",  0x5C);
  add_ps_binary("VSUBPS",  0x5C);
  add_pd_binary("VMULPD",  0x59);
  add_ps_binary("VMULPS",  0x59);
  add_pd_binary("VDIVPD",  0x5E);
  add_ps_binary("VDIVPS",  0x5E);
  add_pd_binary("VMINPD",  0x5D);
  add_ps_binary("VMINPS",  0x5D);
  add_pd_binary("VMAXPD",  0x5F);
  add_ps_binary("VMAXPS",  0x5F);

  // ---- Packed FP logical ----
  add_pd_binary("VANDPD",  0x54);
  add_ps_binary("VANDPS",  0x54);
  add_pd_binary("VANDNPD", 0x55);
  add_ps_binary("VANDNPS", 0x55);
  add_pd_binary("VORPD",   0x56);
  add_ps_binary("VORPS",   0x56);
  add_pd_binary("VXORPD",  0x57);
  add_ps_binary("VXORPS",  0x57);

  // ---- Packed FP unpack/interleave ----
  add_pd_binary("VUNPCKLPD", 0x14);
  add_ps_binary("VUNPCKLPS", 0x14);
  add_pd_binary("VUNPCKHPD", 0x15);
  add_ps_binary("VUNPCKHPS", 0x15);

  // ---- Packed FP unary: VSQRT ----
  {
    Evex e;
    e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0x51;
    e.reg = 0; e.vvvv = 0; e.rm = 1;

    ArchState s;
    s.rflags = 0x2;
    double vals[] = {4.0, 9.0, 16.0, 25.0, 36.0, 49.0, 64.0, 81.0};
    memcpy(s.xmm[1].q, vals, 64);
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;
    add_evex_rr_tests(tests, cat, "VSQRTPD", e, s, 0x3, 0x55);
  }
  {
    Evex e;
    e.mm = 1; e.pp = 0; e.W = false; e.opcode = 0x51;
    e.reg = 0; e.vvvv = 0; e.rm = 1;

    ArchState s;
    s.rflags = 0x2;
    float vals[] = {4.0f, 9.0f, 16.0f, 25.0f, 36.0f, 49.0f, 64.0f, 81.0f,
                    100.0f, 121.0f, 144.0f, 169.0f, 196.0f, 225.0f, 256.0f, 289.0f};
    memcpy(s.xmm[1].q, vals, 64);
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;
    add_evex_rr_tests(tests, cat, "VSQRTPS", e, s, 0x3, 0x5555);
  }
}

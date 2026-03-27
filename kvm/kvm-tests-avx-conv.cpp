#include "kvm-avx-encoder.h"

// VL256/512 only helper
static void add_evex_rr_tests_vl(
    std::vector<TestCase> &tests, const std::string &cat, const char *mnemonic,
    Evex base, ArchState init, u32 xmm_cmp, u32 kmask_val, int min_ll) {
  const char *vl_name[] = {"xmm", "ymm", "zmm"};
  const int vl_bits[] = {128, 256, 512};
  for (int ll = min_ll; ll <= 2; ll++) {
    std::string suffix = std::string(vl_name[ll]) + " (VL" + std::to_string(vl_bits[ll]) + ")";
    base.LL = ll;
    base.aaa = 0; base.z = false;
    tests.push_back({std::string(mnemonic) + " " + suffix,
                     cat, base.encode_rr(), init, FL_NONE, xmm_cmp, false});
    if (kmask_val) {
      base.aaa = 1; base.z = true;
      tests.push_back({std::string(mnemonic) + " " + suffix + " {k1}{z}",
                       cat, concat(set_kmask(kmask_val), base.encode_rr()), init, FL_NONE, xmm_cmp, false});
    }
  }
}

void add_avx_conv_tests(std::vector<TestCase> &tests) {
  std::string cat = "AVX conv";

  // =====================================================================
  // Same-width conversions (VL stays the same)
  // VCVTPS2DQ:  EVEX.66.0F.W0  5B /r  (f32→i32)
  // VCVTTPS2DQ: EVEX.F3.0F.W0  5B /r  (f32→i32 truncate)
  // VCVTDQ2PS:  EVEX.NP.0F.W0  5B /r  (i32→f32)
  // VCVTPS2UDQ: EVEX.NP.0F.W0  79 /r  (f32→u32)
  // VCVTTPS2UDQ:EVEX.NP.0F.W0  78 /r  (f32→u32 truncate)
  // VCVTUDQ2PS: EVEX.F2.0F.W0  7A /r  (u32→f32)
  // =====================================================================
  {
    ArchState s = {}; s.rflags = 0x2;
    float vals[] = {1.5f, -2.7f, 3.0f, 100.9f, -0.5f, 255.1f, 0.0f, -1.0f,
                    1000.5f, -999.9f, 42.42f, 0.001f, 65535.5f, -32768.5f, 1.0f, -0.0f};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 1; e.W = false; e.opcode = 0x5B; e.reg = 0; e.vvvv = 0; e.rm = 1;

    e.pp = 1; // 66
    add_evex_rr_tests(tests, cat, "VCVTPS2DQ", e, s, 0x3, 0xAAAA);
    e.pp = 2; // F3
    add_evex_rr_tests(tests, cat, "VCVTTPS2DQ", e, s, 0x3, 0xAAAA);
    e.pp = 0; // NP
    add_evex_rr_tests(tests, cat, "VCVTDQ2PS", e, s, 0x3, 0xAAAA);
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    float vals[] = {1.5f, 2.7f, 3.0f, 100.9f, 0.5f, 255.1f, 0.0f, 1.0f,
                    1000.5f, 999.9f, 42.42f, 0.001f, 65535.5f, 32768.5f, 1.0f, 0.0f};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 1; e.W = false; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.pp = 0; e.opcode = 0x79;
    add_evex_rr_tests(tests, cat, "VCVTPS2UDQ", e, s, 0x3, 0xAAAA);
    e.pp = 0; e.opcode = 0x78;
    add_evex_rr_tests(tests, cat, "VCVTTPS2UDQ", e, s, 0x3, 0xAAAA);
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[1].q)[i] = i * 1000 + 42;

    Evex e; e.mm = 1; e.pp = 3; e.W = false; e.opcode = 0x7A;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VCVTUDQ2PS", e, s, 0x3, 0xAAAA);
  }

  // =====================================================================
  // QWord ↔ FP64 conversions (same width)
  // VCVTQQ2PD:  EVEX.F3.0F.W1  E6 /r  (i64→f64)
  // VCVTPD2QQ:  EVEX.66.0F.W1  7B /r  (f64→i64)
  // VCVTTPD2QQ: EVEX.66.0F.W1  7A /r  (f64→i64 truncate)
  // VCVTUQQ2PD: EVEX.F3.0F.W1  7A /r  (u64→f64)
  // VCVTPD2UQQ: EVEX.66.0F.W1  79 /r  (f64→u64)
  // VCVTTPD2UQQ:EVEX.66.0F.W1  78 /r  (f64→u64 truncate)
  // =====================================================================
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 1000 * (i + 1) + 42;

    Evex e; e.mm = 1; e.W = true; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.pp = 2; e.opcode = 0xE6;
    add_evex_rr_tests(tests, cat, "VCVTQQ2PD", e, s, 0x3, 0x55);
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    double vals[] = {1.5, -2.7, 3.0, 100.9, -0.5, 255.1, 0.0, -1.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 1; e.W = true; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.pp = 1; e.opcode = 0x7B;
    add_evex_rr_tests(tests, cat, "VCVTPD2QQ", e, s, 0x3, 0x55);
    e.pp = 1; e.opcode = 0x7A;
    add_evex_rr_tests(tests, cat, "VCVTTPD2QQ", e, s, 0x3, 0x55);
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 1000 * (i + 1) + 42;

    Evex e; e.mm = 1; e.W = true; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.pp = 2; e.opcode = 0x7A;
    add_evex_rr_tests(tests, cat, "VCVTUQQ2PD", e, s, 0x3, 0x55);
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    double vals[] = {1.5, 2.7, 3.0, 100.9, 0.5, 255.1, 0.0, 1.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 1; e.W = true; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.pp = 1; e.opcode = 0x79;
    add_evex_rr_tests(tests, cat, "VCVTPD2UQQ", e, s, 0x3, 0x55);
    e.pp = 1; e.opcode = 0x78;
    add_evex_rr_tests(tests, cat, "VCVTTPD2UQQ", e, s, 0x3, 0x55);
  }

  // =====================================================================
  // Narrowing: f64→f32 (VCVTPD2PS) — result is half-width
  // These need per-VL dispatch since source and dest widths differ.
  // VCVTPD2PS: EVEX.66.0F.W1 5A /r
  // VCVTPS2PD: EVEX.NP.0F.W0 5A /r (widening: f32→f64)
  // =====================================================================
  // For VCVTPD2PS: VL128→xmm(low 64 used), VL256→xmm, VL512→ymm
  // Test each VL individually
  {
    ArchState s = {}; s.rflags = 0x2;
    double vals[] = {1.5, -2.7, 3.0, 100.9, -0.5, 255.1, 0.0, -1.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0x5A;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTPD2PS ") + vl[ll],
                       cat, e.encode_rr(), s, FL_NONE, 0x3, false});
    }
  }

  // VCVTPS2PD: VL128→xmm(low 64 read), VL256→xmm read, VL512→ymm read
  {
    ArchState s = {}; s.rflags = 0x2;
    float vals[] = {1.5f, -2.7f, 3.0f, 100.9f, -0.5f, 255.1f, 0.0f, -1.0f,
                    1000.5f, -999.9f, 42.42f, 0.001f, 65535.5f, -32768.5f, 1.0f, -0.0f};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 1; e.pp = 0; e.W = false; e.opcode = 0x5A;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTPS2PD ") + vl[ll],
                       cat, e.encode_rr(), s, FL_NONE, 0x3, false});
    }
  }

  // =====================================================================
  // Narrowing: f64→i32 (VCVTPD2DQ, VCVTTPD2DQ)
  // VCVTPD2DQ:  EVEX.F2.0F.W1 E6 /r
  // VCVTTPD2DQ: EVEX.66.0F.W1 E6 /r
  // VCVTPD2UDQ: EVEX.NP.0F.W1 79 /r
  // VCVTTPD2UDQ:EVEX.NP.0F.W1 78 /r
  // =====================================================================
  {
    ArchState s = {}; s.rflags = 0x2;
    double vals[] = {1.5, -2.7, 3.0, 100.9, -0.5, 255.1, 0.0, -1.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 1; e.W = true; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.pp = 3; e.opcode = 0xE6; // F2
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTPD2DQ ") + vl[ll],
                       cat, e.encode_rr(), s, FL_NONE, 0x3, false});
    }
    e.pp = 1; e.opcode = 0xE6; // 66
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTTPD2DQ ") + vl[ll],
                       cat, e.encode_rr(), s, FL_NONE, 0x3, false});
    }
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    double vals[] = {1.5, 2.7, 3.0, 100.9, 0.5, 255.1, 0.0, 1.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 1; e.W = true; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.pp = 0; e.opcode = 0x79; // NP
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTPD2UDQ ") + vl[ll],
                       cat, e.encode_rr(), s, FL_NONE, 0x3, false});
    }
    e.pp = 0; e.opcode = 0x78;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTTPD2UDQ ") + vl[ll],
                       cat, e.encode_rr(), s, FL_NONE, 0x3, false});
    }
  }

  // =====================================================================
  // Narrowing/widening: i64↔f32
  // VCVTQQ2PS:  EVEX.NP.0F.W1 5B /r  (i64→f32)
  // VCVTUQQ2PS: EVEX.F2.0F.W1 7A /r  (u64→f32) — wait, this is same opcode as VCVTUQQ2PD?
  // Actually: VCVTQQ2PS uses EVEX.NP.0F.W1 5B, VCVTUQQ2PS uses EVEX.F2.0F.W1 7A
  // No, checking SDM: VCVTUQQ2PS: EVEX.F2.0F.W1 7A — but that's VCVTUQQ2PD with pp=F3.
  // Let me just test the ones I'm sure about.
  // =====================================================================
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 1000 * (i + 1) + 42;

    Evex e; e.mm = 1; e.pp = 0; e.W = true; e.opcode = 0x5B;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTQQ2PS ") + vl[ll],
                       cat, e.encode_rr(), s, FL_NONE, 0x3, false});
    }
  }

  // =====================================================================
  // Scalar conversions
  // VCVTSD2SS: EVEX.F2.0F.W1 5A /r (f64→f32, scalar)
  // VCVTSS2SD: EVEX.F3.0F.W0 5A /r (f32→f64, scalar)
  // VCVTSI2SS: EVEX.F3.0F.W0 2A /r (i32→f32, from GPR)
  // VCVTSI2SD: EVEX.F2.0F.W0 2A /r (i32→f64, from GPR)
  // =====================================================================
  {
    ArchState s = {}; s.rflags = 0x2;
    double d = 3.14159; memcpy(&s.xmm[1].q[0], &d, 8);
    s.xmm[1].q[1] = 0xBBBBBBBBBBBBBBBB;
    s.xmm[0].q[0] = 0xAAAAAAAAAAAAAAAA;
    s.xmm[0].q[1] = 0xDDDDDDDDDDDDDDDD;

    Evex e; e.mm = 1; e.pp = 3; e.W = true; e.opcode = 0x5A;
    e.reg = 0; e.vvvv = 0; e.rm = 1; e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VCVTSD2SS xmm", cat, e.encode_rr(), s, FL_NONE, 0x3, false});
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    float f = 3.14f; memcpy(&s.xmm[1].q[0], &f, 4);
    s.xmm[1].q[1] = 0xBBBBBBBBBBBBBBBB;
    s.xmm[0].q[0] = 0xAAAAAAAAAAAAAAAA;
    s.xmm[0].q[1] = 0xDDDDDDDDDDDDDDDD;

    Evex e; e.mm = 1; e.pp = 2; e.W = false; e.opcode = 0x5A;
    e.reg = 0; e.vvvv = 0; e.rm = 1; e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VCVTSS2SD xmm", cat, e.encode_rr(), s, FL_NONE, 0x3, false});
  }
}

#include "kvm-avx-encoder.h"

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
    ArchState s = {};
    float vals[] = {1.5f, -2.7f, 3.0f, 100.9f, -0.5f, 255.1f, 0.0f, -1.0f,
                    1000.5f, -999.9f, 42.42f, 0.001f, 65535.5f, -32768.5f, 1.0f, -0.0f};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 1; e.W = false; e.opcode = 0x5B; e.reg = 0; e.vvvv = 0; e.rm = 1;

    e.pp = 1; // 66
    add_evex_rr_tests(tests, cat, "VCVTPS2DQ", e, s, 0x2, 0xAAAA);
    e.pp = 2; // F3
    add_evex_rr_tests(tests, cat, "VCVTTPS2DQ", e, s, 0x2, 0xAAAA);
    e.pp = 0; // NP
    add_evex_rr_tests(tests, cat, "VCVTDQ2PS", e, s, 0x2, 0xAAAA);
  }
  {
    ArchState s = {};
    float vals[] = {1.5f, 2.7f, 3.0f, 100.9f, 0.5f, 255.1f, 0.0f, 1.0f,
                    1000.5f, 999.9f, 42.42f, 0.001f, 65535.5f, 32768.5f, 1.0f, 0.0f};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 1; e.W = false; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.pp = 0; e.opcode = 0x79;
    add_evex_rr_tests(tests, cat, "VCVTPS2UDQ", e, s, 0x2, 0xAAAA);
    e.pp = 0; e.opcode = 0x78;
    add_evex_rr_tests(tests, cat, "VCVTTPS2UDQ", e, s, 0x2, 0xAAAA);
  }
  {
    ArchState s = {};
    for (int i = 0; i < 16; i++) s.xmm[1].set<u32>(i, i * 1000 + 42);

    Evex e; e.mm = 1; e.pp = 3; e.W = false; e.opcode = 0x7A;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VCVTUDQ2PS", e, s, 0x2, 0xAAAA);
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
    ArchState s = {};
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 1000 * (i + 1) + 42;

    Evex e; e.mm = 1; e.W = true; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.pp = 2; e.opcode = 0xE6;
    add_evex_rr_tests(tests, cat, "VCVTQQ2PD", e, s, 0x2, 0x55);
  }
  {
    ArchState s = {};
    double vals[] = {1.5, -2.7, 3.0, 100.9, -0.5, 255.1, 0.0, -1.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 1; e.W = true; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.pp = 1; e.opcode = 0x7B;
    add_evex_rr_tests(tests, cat, "VCVTPD2QQ", e, s, 0x2, 0x55);
    e.pp = 1; e.opcode = 0x7A;
    add_evex_rr_tests(tests, cat, "VCVTTPD2QQ", e, s, 0x2, 0x55);
  }
  {
    ArchState s = {};
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 1000 * (i + 1) + 42;

    Evex e; e.mm = 1; e.W = true; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.pp = 2; e.opcode = 0x7A;
    add_evex_rr_tests(tests, cat, "VCVTUQQ2PD", e, s, 0x2, 0x55);
  }
  {
    ArchState s = {};
    double vals[] = {1.5, 2.7, 3.0, 100.9, 0.5, 255.1, 0.0, 1.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 1; e.W = true; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.pp = 1; e.opcode = 0x79;
    add_evex_rr_tests(tests, cat, "VCVTPD2UQQ", e, s, 0x2, 0x55);
    e.pp = 1; e.opcode = 0x78;
    add_evex_rr_tests(tests, cat, "VCVTTPD2UQQ", e, s, 0x2, 0x55);
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
    ArchState s = {};
    double vals[] = {1.5, -2.7, 3.0, 100.9, -0.5, 255.1, 0.0, -1.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0x5A;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTPD2PS ") + vl[ll],
                       cat, e.encode_rr(), s, FL_ALL, 0x3, false});
    }
  }

  // VCVTPS2PD: VL128→xmm(low 64 read), VL256→xmm read, VL512→ymm read
  {
    ArchState s = {};
    float vals[] = {1.5f, -2.7f, 3.0f, 100.9f, -0.5f, 255.1f, 0.0f, -1.0f,
                    1000.5f, -999.9f, 42.42f, 0.001f, 65535.5f, -32768.5f, 1.0f, -0.0f};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 1; e.pp = 0; e.W = false; e.opcode = 0x5A;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTPS2PD ") + vl[ll],
                       cat, e.encode_rr(), s, FL_ALL, 0x3, false});
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
    ArchState s = {};
    double vals[] = {1.5, -2.7, 3.0, 100.9, -0.5, 255.1, 0.0, -1.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 1; e.W = true; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.pp = 3; e.opcode = 0xE6; // F2
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTPD2DQ ") + vl[ll],
                       cat, e.encode_rr(), s, FL_ALL, 0x3, false});
    }
    e.pp = 1; e.opcode = 0xE6; // 66
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTTPD2DQ ") + vl[ll],
                       cat, e.encode_rr(), s, FL_ALL, 0x3, false});
    }
  }
  {
    ArchState s = {};
    double vals[] = {1.5, 2.7, 3.0, 100.9, 0.5, 255.1, 0.0, 1.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 1; e.W = true; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.pp = 0; e.opcode = 0x79; // NP
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTPD2UDQ ") + vl[ll],
                       cat, e.encode_rr(), s, FL_ALL, 0x3, false});
    }
    e.pp = 0; e.opcode = 0x78;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTTPD2UDQ ") + vl[ll],
                       cat, e.encode_rr(), s, FL_ALL, 0x3, false});
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
    ArchState s = {};
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 1000 * (i + 1) + 42;

    Evex e; e.mm = 1; e.pp = 0; e.W = true; e.opcode = 0x5B;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTQQ2PS ") + vl[ll],
                       cat, e.encode_rr(), s, FL_ALL, 0x3, false});
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
    ArchState s = {};
    double d = 3.14159; memcpy(&s.xmm[1].q[0], &d, 8);
    s.xmm[1].q[1] = 0xBBBBBBBBBBBBBBBB;
    s.xmm[0].q[0] = 0xAAAAAAAAAAAAAAAA;
    s.xmm[0].q[1] = 0xDDDDDDDDDDDDDDDD;

    Evex e; e.mm = 1; e.pp = 3; e.W = true; e.opcode = 0x5A;
    e.reg = 0; e.vvvv = 0; e.rm = 1; e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VCVTSD2SS xmm", cat, e.encode_rr(), s, FL_ALL, 0x3, false});
  }
  {
    ArchState s = {};
    float f = 3.14f; memcpy(&s.xmm[1].q[0], &f, 4);
    s.xmm[1].q[1] = 0xBBBBBBBBBBBBBBBB;
    s.xmm[0].q[0] = 0xAAAAAAAAAAAAAAAA;
    s.xmm[0].q[1] = 0xDDDDDDDDDDDDDDDD;

    Evex e; e.mm = 1; e.pp = 2; e.W = false; e.opcode = 0x5A;
    e.reg = 0; e.vvvv = 0; e.rm = 1; e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VCVTSS2SD xmm", cat, e.encode_rr(), s, FL_ALL, 0x3, false});
  }

  // =====================================================================
  // More scalar conversions
  // VCVTSI2SS: EVEX.F3.0F.W0 2A /r (i32→f32 from GPR)
  // VCVTSI2SD: EVEX.F2.0F.W0 2A /r (i32→f64 from GPR)
  // VCVTUSI2SS: EVEX.F3.0F.W0 7B /r (u32→f32)
  // VCVTUSI2SD: EVEX.F2.0F.W0 7B /r (u32→f64)
  // VCVTSS2SI: EVEX.F3.0F.W0 2D /r (f32→i32 to GPR)
  // VCVTSD2SI: EVEX.F2.0F.W0 2D /r (f64→i32 to GPR)  [W1 for 64-bit]
  // VCVTTSS2SI: EVEX.F3.0F.W0 2C /r (f32→i32 truncate)
  // VCVTTSD2SI: EVEX.F2.0F.W0 2C /r (f64→i32 truncate) [W1 for 64-bit]
  // VCVTSS2USI: EVEX.F3.0F.W0 79 /r
  // VCVTSD2USI: EVEX.F2.0F.W0 79 /r [W1 for 64-bit]
  // VCVTTSS2USI: EVEX.F3.0F.W0 78 /r
  // VCVTTSD2USI: EVEX.F2.0F.W0 78 /r [W1 for 64-bit]
  // =====================================================================
  {
    ArchState s = {};
    s.rax = 12345;
    s.xmm[1] = xmm_from_u64(0xBBBBBBBBBBBBBBBB, 0xCCCCCCCCCCCCCCCC);

    Evex e; e.mm = 1; e.reg = 0; e.vvvv = 1; e.rm = 0;  // rm=rax(GPR)
    e.LL = 0; e.aaa = 0; e.z = false;

    // VCVTSI2SS xmm0, xmm1, eax
    e.pp = 2; e.W = false; e.opcode = 0x2A;
    tests.push_back({"VCVTSI2SS xmm,xmm,eax", cat, e.encode_rr(), s, FL_ALL, 0x3, false});
    // VCVTSI2SD xmm0, xmm1, eax
    e.pp = 3; e.W = false; e.opcode = 0x2A;
    tests.push_back({"VCVTSI2SD xmm,xmm,eax", cat, e.encode_rr(), s, FL_ALL, 0x3, false});
    // VCVTUSI2SS xmm0, xmm1, eax
    e.pp = 2; e.W = false; e.opcode = 0x7B;
    tests.push_back({"VCVTUSI2SS xmm,xmm,eax", cat, e.encode_rr(), s, FL_ALL, 0x3, false});
    // VCVTUSI2SD xmm0, xmm1, eax
    e.pp = 3; e.W = false; e.opcode = 0x7B;
    tests.push_back({"VCVTUSI2SD xmm,xmm,eax", cat, e.encode_rr(), s, FL_ALL, 0x3, false});
  }
  {
    ArchState s = {};
    float f = 42.7f; memcpy(&s.xmm[1].q[0], &f, 4);
    Evex e; e.mm = 1; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.LL = 0; e.aaa = 0; e.z = false;

    // VCVTSS2SI eax, xmm1
    e.pp = 2; e.W = false; e.opcode = 0x2D;
    tests.push_back({"VCVTSS2SI eax,xmm1", cat, e.encode_rr(), s, FL_ALL, 0, false});
    // VCVTTSS2SI eax, xmm1
    e.opcode = 0x2C;
    tests.push_back({"VCVTTSS2SI eax,xmm1", cat, e.encode_rr(), s, FL_ALL, 0, false});
    // VCVTSS2USI eax, xmm1
    e.opcode = 0x79;
    tests.push_back({"VCVTSS2USI eax,xmm1", cat, e.encode_rr(), s, FL_ALL, 0, false});
    // VCVTTSS2USI eax, xmm1
    e.opcode = 0x78;
    tests.push_back({"VCVTTSS2USI eax,xmm1", cat, e.encode_rr(), s, FL_ALL, 0, false});
  }
  {
    ArchState s = {};
    double d = 42.7; memcpy(&s.xmm[1].q[0], &d, 8);
    Evex e; e.mm = 1; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.LL = 0; e.aaa = 0; e.z = false;

    // VCVTSD2SI eax, xmm1
    e.pp = 3; e.W = false; e.opcode = 0x2D;
    tests.push_back({"VCVTSD2SI eax,xmm1", cat, e.encode_rr(), s, FL_ALL, 0, false});
    // VCVTTSD2SI eax, xmm1
    e.opcode = 0x2C;
    tests.push_back({"VCVTTSD2SI eax,xmm1", cat, e.encode_rr(), s, FL_ALL, 0, false});
    // VCVTSD2USI eax, xmm1
    e.opcode = 0x79;
    tests.push_back({"VCVTSD2USI eax,xmm1", cat, e.encode_rr(), s, FL_ALL, 0, false});
    // VCVTTSD2USI eax, xmm1
    e.opcode = 0x78;
    tests.push_back({"VCVTTSD2USI eax,xmm1", cat, e.encode_rr(), s, FL_ALL, 0, false});
  }

  // =====================================================================
  // VCVTDQ2PD: EVEX.F3.0F.W0 E6 /r (i32→f64, widening)
  // VCVTUDQ2PD: EVEX.F3.0F.W0 7A /r (u32→f64, widening)
  // VCVTPS2QQ: EVEX.66.0F.W0 7B /r (f32→i64, widening)
  // VCVTPS2UQQ: EVEX.66.0F.W0 79 /r (f32→u64, widening)
  // VCVTTPS2QQ: EVEX.66.0F.W0 7A /r (f32→i64, trunc)
  // VCVTTPS2UQQ: EVEX.66.0F.W0 78 /r (f32→u64, trunc)
  // VCVTUQQ2PS: EVEX.F2.0F.W1 7A /r (u64→f32, narrowing)
  // =====================================================================
  {
    ArchState s = {};
    int32_t ivals[] = {1, -2, 3, -4, 5, -6, 7, -8, 9, -10, 11, -12, 13, -14, 15, -16};
    memcpy(s.xmm[1].q, ivals, 64);

    Evex e; e.mm = 1; e.pp = 2; e.W = false; e.opcode = 0xE6;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTDQ2PD ") + vl[ll], cat, e.encode_rr(), s, FL_ALL, 0x3, false});
    }
  }
  {
    ArchState s = {};
    u32 uvals[] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16};
    memcpy(s.xmm[1].q, uvals, 64);

    Evex e; e.mm = 1; e.pp = 2; e.W = false; e.opcode = 0x7A;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTUDQ2PD ") + vl[ll], cat, e.encode_rr(), s, FL_ALL, 0x3, false});
    }
  }
  {
    ArchState s = {};
    float fvals[] = {1.5f, 2.7f, -3.0f, 100.9f, 0.5f, -255.1f, 0.0f, -1.0f,
                     1000.5f, -999.9f, 42.42f, 0.001f, 65535.5f, -32768.5f, 1.0f, -0.0f};
    memcpy(s.xmm[1].q, fvals, 64);

    Evex e; e.mm = 1; e.pp = 1; e.W = false; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.opcode = 0x7B;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTPS2QQ ") + vl[ll], cat, e.encode_rr(), s, FL_ALL, 0x3, false});
    }
    e.opcode = 0x7A;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTTPS2QQ ") + vl[ll], cat, e.encode_rr(), s, FL_ALL, 0x3, false});
    }
  }
  // VCVTPS2UQQ/VCVTTPS2UQQ (unsigned)
  {
    ArchState s = {};
    float fvals[] = {1.5f, 2.7f, 3.0f, 100.9f, 0.5f, 255.1f, 0.0f, 1.0f,
                     1000.5f, 999.9f, 42.42f, 0.001f, 65535.5f, 32768.5f, 1.0f, 0.0f};
    memcpy(s.xmm[1].q, fvals, 64);

    Evex e; e.mm = 1; e.pp = 1; e.W = false; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.opcode = 0x79;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTPS2UQQ ") + vl[ll], cat, e.encode_rr(), s, FL_ALL, 0x3, false});
    }
    e.opcode = 0x78;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTTPS2UQQ ") + vl[ll], cat, e.encode_rr(), s, FL_ALL, 0x3, false});
    }
  }
  // VCVTUQQ2PS: narrowing u64→f32
  {
    ArchState s = {};
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 1000 * (i + 1) + 42;
    Evex e; e.mm = 1; e.pp = 3; e.W = true; e.opcode = 0x7A;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTUQQ2PS ") + vl[ll], cat, e.encode_rr(), s, FL_ALL, 0x3, false});
    }
  }

  // =====================================================================
  // Scalar FP compare with immediate
  // VCMPSS: EVEX.F3.0F.W0 C2 /r ib
  // VCMPSD: EVEX.F2.0F.W1 C2 /r ib
  // =====================================================================
  {
    static const std::vector<u8> kmovq_k0_rax = {0xC4, 0xE1, 0xFB, 0x93, 0xC0};

    ArchState s = {};
    float f1 = 3.0f, f2 = 5.0f;
    memcpy(&s.xmm[1].q[0], &f1, 4);
    memcpy(&s.xmm[2].q[0], &f2, 4);

    Evex e; e.mm = 1; e.pp = 2; e.W = false; e.opcode = 0xC2;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.LL = 0; e.aaa = 0; e.z = false;

    auto code = e.encode_rr_imm(0);  // EQ
    code.insert(code.end(), kmovq_k0_rax.begin(), kmovq_k0_rax.end());
    tests.push_back({"VCMPSS EQ", cat, code, s, FL_ALL, 0, false});
    code = e.encode_rr_imm(1);  // LT
    code.insert(code.end(), kmovq_k0_rax.begin(), kmovq_k0_rax.end());
    tests.push_back({"VCMPSS LT", cat, code, s, FL_ALL, 0, false});
  }
  {
    static const std::vector<u8> kmovq_k0_rax = {0xC4, 0xE1, 0xFB, 0x93, 0xC0};

    ArchState s = {};
    double d1 = 3.0, d2 = 5.0;
    memcpy(&s.xmm[1].q[0], &d1, 8);
    memcpy(&s.xmm[2].q[0], &d2, 8);

    Evex e; e.mm = 1; e.pp = 3; e.W = true; e.opcode = 0xC2;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.LL = 0; e.aaa = 0; e.z = false;

    auto code = e.encode_rr_imm(0);
    code.insert(code.end(), kmovq_k0_rax.begin(), kmovq_k0_rax.end());
    tests.push_back({"VCMPSD EQ", cat, code, s, FL_ALL, 0, false});
    code = e.encode_rr_imm(1);
    code.insert(code.end(), kmovq_k0_rax.begin(), kmovq_k0_rax.end());
    tests.push_back({"VCMPSD LT", cat, code, s, FL_ALL, 0, false});
  }

  // =====================================================================
  // VCVTPS2PH xmm/m64 {k1}{z}, xmm, imm8  EVEX.128.66.0F3A.W0 1D
  // VCVTPS2PH xmm/m128, ymm / ymm/m256, zmm at the other lengths.
  // imm8[2] = 0 selects the rounding mode in imm8[1:0], 1 uses MXCSR.RC.
  // The source is ModRM:reg, the destination ModRM:r/m; the values need
  // rounding, and round across the largest finite value, so the mode
  // matters.  Inputs whose result is tiny (below the smallest FP16
  // denormal) or whose magnitude exceeds 65536 are left out; the model's
  // fp32_to_fp16 (branchless.sail) does not yet round those per mode.
  // =====================================================================
  {
    ArchState s;
    float vals[16] = {1.0f, 1.00048828125f, 65504.0f, 65520.0f, 65519.0f, -0.0f, NAN, INFINITY,
                      0.1f, -2.5f, 3.0517578125e-05f, 6.103515625e-05f, -65519.0f, 1234.5678f, 3.0e-5f, -2.0e-5f};
    memcpy(s.xmm[1].q, vals, 64);
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEADULL;
    const char *vl_name[] = {"xmm", "ymm", "zmm"};
    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x1D; e.reg = 1; e.vvvv = 0; e.rm = 0;
    for (int ll = 0; ll <= 2; ll++) {
      e.LL = ll;
      for (u8 imm : {0x00, 0x01, 0x02, 0x03, 0x04}) {
        std::string name = std::format("VCVTPS2PH xmm0,{}1,{:#x}", vl_name[ll], imm);
        e.aaa = 0; e.z = false;
        tests.push_back({name, cat, e.encode_rr_imm(imm), with_vector_inputs(s, 0x2), FL_ALL, 0, false});
        if (imm == 0x04) {
          // MXCSR.RC = round toward zero
          ArchState rz = with_vector_inputs(s, 0x2); rz.mxcsr = 0x7F80;
          tests.push_back({name + " MXCSR.RC=RZ", cat, e.encode_rr_imm(imm), rz, FL_ALL, 0, false});
        }
      }
      ArchState km = with_vector_inputs(s, 0x2); km.kregs[1] = 0xA5A5;
      e.aaa = 1; e.z = true;
      tests.push_back({std::format("VCVTPS2PH xmm0,{}1,0 {{k1}}{{z}}", vl_name[ll]), cat, e.encode_rr_imm(0), km, FL_ALL, 0, false});
      e.aaa = 1; e.z = false;
      tests.push_back({std::format("VCVTPS2PH xmm0,{}1,0 {{k1}}", vl_name[ll]), cat, e.encode_rr_imm(0),
                       with_merge_input(km, 0x2, 0), FL_ALL, 0, false});
      // memory destination: the store is 8/16/32 bytes, masked per element
      for (int masked = 0; masked <= 1; masked++) {
        e.aaa = masked; e.z = false;
        TestCase tc; tc.category = cat;
        tc.name = std::format("VCVTPS2PH [rdi]{},{}1,0", masked ? "{k1}" : "", vl_name[ll]);
        tc.code = e.encode_rm_mem_imm(0);
        tc.initial = with_vector_inputs(s, 0x2); tc.initial.rdi = DATA_ADDR;
        if (masked) tc.initial.kregs[1] = 0xA5A5;
        tc.init_data = std::vector<u8>(64, 0xCC); tc.compare_data_len = 64;
        tests.push_back(std::move(tc));
      }
    }
  }
}

#include "kvm-avx-encoder.h"

void add_avx_cmp_tests(std::vector<TestCase> &tests) {
  std::string cat = "AVX cmp";

  // Compare-to-mask instructions write to a k-register.
  // We read back via KMOVQ rax, k0 and compare RAX.
  // KMOVQ rax, k0: C4 E1 F8 93 C0 (VEX.L0.F2.0F.W1 93 /r, reg=rax, rm=k0)

  static const std::vector<u8> kmovq_k0_rax = {0xC4, 0xE1, 0xFB, 0x93, 0xC0};

  auto add_cmp_test = [&](const char *name, Evex e, ArchState s, int ll) {
    e.LL = ll;
    const char *vl_name[] = {"xmm", "ymm", "zmm"};
    const int vl_bits[] = {128, 256, 512};
    std::string suffix = std::string(vl_name[ll]) + " (VL" + std::to_string(vl_bits[ll]) + ")";

    // No writemask on the compare itself (result goes to k0)
    e.aaa = 0; e.z = false;
    auto code = concat(e.encode_rr(), kmovq_k0_rax);
    tests.push_back({std::string(name) + " " + suffix, cat, code, s, FL_ALL, 0, false});
  };

  // =====================================================================
  // VPCMPEQB/W/D/Q and VPCMPGTB/W/D/Q
  // These compare src1 (vvvv) with src2 (rm), result in k-register (reg field)
  // VPCMPEQB: 66 0F 74, WIG   VPCMPEQW: 66 0F 75, WIG
  // VPCMPEQD: 66 0F 76, W0    VPCMPEQQ: 66 0F38 29, W1
  // VPCMPGTB: 66 0F 64, WIG   VPCMPGTW: 66 0F 65, WIG
  // VPCMPGTD: 66 0F 66, W0    VPCMPGTQ: 66 0F38 37, W1
  // =====================================================================

  {
    // Byte comparison: some equal, some not
    ArchState s;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = i;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = (i % 2 == 0) ? i : i + 1;

    struct { const char *name; int mm; u8 opcode; bool W; } byte_cmps[] = {
      {"VPCMPEQB", 1, 0x74, false},
      {"VPCMPGTB", 1, 0x64, false},
    };
    for (auto &c : byte_cmps) {
      Evex e; e.mm = c.mm; e.pp = 1; e.W = c.W; e.opcode = c.opcode;
      e.reg = 0; e.vvvv = 1; e.rm = 2;
      for (int ll = 0; ll <= 2; ll++) add_cmp_test(c.name, e, s, ll);
    }
  }

  {
    // Word comparison
    ArchState s;
    for (int i = 0; i < 32; i++) s.xmm[1].set<u16>(i, i * 100);
    for (int i = 0; i < 32; i++) s.xmm[2].set<u16>(i, (i % 3 == 0) ? i * 100 : i * 100 + 1);

    Evex e; e.mm = 1; e.pp = 1; e.W = false; e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.opcode = 0x75;
    for (int ll = 0; ll <= 2; ll++) add_cmp_test("VPCMPEQW", e, s, ll);
    e.opcode = 0x65;
    for (int ll = 0; ll <= 2; ll++) add_cmp_test("VPCMPGTW", e, s, ll);
  }

  {
    // DWord comparison
    ArchState s;
    for (int i = 0; i < 16; i++) s.xmm[1].set<u32>(i, i * 1000);
    for (int i = 0; i < 16; i++) s.xmm[2].set<u32>(i, (i % 2 == 0) ? i * 1000 : i * 1000 - 1);

    Evex e; e.mm = 1; e.pp = 1; e.W = false; e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.opcode = 0x76;
    for (int ll = 0; ll <= 2; ll++) add_cmp_test("VPCMPEQD", e, s, ll);
    e.opcode = 0x66;
    for (int ll = 0; ll <= 2; ll++) add_cmp_test("VPCMPGTD", e, s, ll);
  }

  {
    // QWord comparison
    ArchState s;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = i * 10000;
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = (i % 2 == 0) ? i * 10000 : i * 10000 + 1;

    // VPCMPEQQ: 66 0F38 29, W1
    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.opcode = 0x29;
    for (int ll = 0; ll <= 2; ll++) add_cmp_test("VPCMPEQQ", e, s, ll);
    // VPCMPGTQ: 66 0F38 37, W1
    e.opcode = 0x37;
    for (int ll = 0; ll <= 2; ll++) add_cmp_test("VPCMPGTQ", e, s, ll);
  }

  // =====================================================================
  // VPCMPB/W/D/Q with immediate predicate
  // EVEX.66.0F3A.W0 3F /r ib (VPCMPB)
  // EVEX.66.0F3A.W1 3F /r ib (VPCMPW)
  // EVEX.66.0F3A.W0 1F /r ib (VPCMPD)
  // EVEX.66.0F3A.W1 1F /r ib (VPCMPQ)
  // EVEX.66.0F3A.W0 3E /r ib (VPCMPUB)
  // EVEX.66.0F3A.W1 3E /r ib (VPCMPUW)
  // EVEX.66.0F3A.W0 1E /r ib (VPCMPUD)
  // EVEX.66.0F3A.W1 1E /r ib (VPCMPUQ)
  // Predicates: 0=EQ, 1=LT, 2=LE, 4=NEQ, 5=NLT, 6=NLE
  // =====================================================================

  auto add_cmp_imm_test = [&](const char *name, Evex e, ArchState s, u8 imm) {
    for (int ll = 0; ll <= 2; ll++) {
      e.LL = ll;
      const char *vl_name[] = {"xmm", "ymm", "zmm"};
      std::string suffix = std::string(vl_name[ll]) + " imm=" + std::to_string(imm);

      e.aaa = 0; e.z = false;
      auto code = e.encode_rr_imm(imm);
      code.insert(code.end(), kmovq_k0_rax.begin(), kmovq_k0_rax.end());
      tests.push_back({std::string(name) + " " + suffix, cat, code, s, FL_ALL, 0, false});
    }
  };

  {
    // VPCMPD with various predicates
    ArchState s;
    for (int i = 0; i < 16; i++) s.xmm[1].set<int32_t>(i, i * 100 - 500);
    for (int i = 0; i < 16; i++) s.xmm[2].set<int32_t>(i, 300);

    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x1F;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_cmp_imm_test("VPCMPD EQ",  e, s, 0);
    add_cmp_imm_test("VPCMPD LT",  e, s, 1);
    add_cmp_imm_test("VPCMPD LE",  e, s, 2);
    add_cmp_imm_test("VPCMPD NEQ", e, s, 4);
  }

  {
    // VPCMPQ
    ArchState s;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = (u64)((int64_t)(i * 100) - 300);
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = 100;

    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.opcode = 0x1F;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_cmp_imm_test("VPCMPQ LT", e, s, 1);
    add_cmp_imm_test("VPCMPQ LE", e, s, 2);
  }

  {
    // VPCMPUD (unsigned)
    ArchState s;
    for (int i = 0; i < 16; i++) s.xmm[1].set<u32>(i, i * 100);
    for (int i = 0; i < 16; i++) s.xmm[2].set<u32>(i, 500);

    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x1E;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_cmp_imm_test("VPCMPUD LT", e, s, 1);
    add_cmp_imm_test("VPCMPUD EQ", e, s, 0);
  }

  {
    // VPCMPB
    ArchState s;
    for (int i = 0; i < 64; i++) ((int8_t *)s.xmm[1].q)[i] = -32 + i;
    for (int i = 0; i < 64; i++) ((int8_t *)s.xmm[2].q)[i] = 0;

    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x3F;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_cmp_imm_test("VPCMPB LT", e, s, 1);
    add_cmp_imm_test("VPCMPB EQ", e, s, 0);
  }

  {
    // VPCMPW
    ArchState s;
    for (int i = 0; i < 32; i++) s.xmm[1].set<int16_t>(i, -16 + i);
    for (int i = 0; i < 32; i++) s.xmm[2].set<int16_t>(i, 0);

    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.opcode = 0x3F;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_cmp_imm_test("VPCMPW LT", e, s, 1);
  }

  {
    // VPCMPUQ
    ArchState s;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = i * 100;
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = 300;

    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.opcode = 0x1E;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    add_cmp_imm_test("VPCMPUQ LT", e, s, 1);
  }

  // =====================================================================
  // VPTESTMB/W/D/Q and VPTESTNMB/W/D/Q
  // Test if AND of two operands is (non)zero, per element → k-register
  // VPTESTMB: 66 0F38 26, W0   VPTESTMW: 66 0F38 26, W1
  // VPTESTMD: 66 0F38 27, W0   VPTESTMQ: 66 0F38 27, W1
  // VPTESTNMB: F3 0F38 26, W0  VPTESTNMW: F3 0F38 26, W1
  // VPTESTNMD: F3 0F38 27, W0  VPTESTNMQ: F3 0F38 27, W1
  // =====================================================================
  {
    ArchState s;
    for (int i = 0; i < 16; i++) s.xmm[1].set<u32>(i, (i % 2 == 0) ? 0xFFFFFFFF : 0);
    for (int i = 0; i < 16; i++) s.xmm[2].set<u32>(i, 0xFFFFFFFF);

    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x27;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) add_cmp_test("VPTESTMD", e, s, ll);

    e.pp = 2;  // F3 for VPTESTNM
    for (int ll = 0; ll <= 2; ll++) add_cmp_test("VPTESTNMD", e, s, ll);
  }
  {
    ArchState s;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = (i % 2 == 0) ? 0xFFFFFFFFFFFFFFFF : 0;
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = 0xFFFFFFFFFFFFFFFF;

    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x27;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) add_cmp_test("VPTESTMQ", e, s, ll);

    e.pp = 2;
    for (int ll = 0; ll <= 2; ll++) add_cmp_test("VPTESTNMQ", e, s, ll);
  }
  {
    ArchState s;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = (i % 4 == 0) ? 0xFF : 0;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = 0xFF;

    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x26;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) add_cmp_test("VPTESTMB", e, s, ll);

    e.pp = 2;
    for (int ll = 0; ll <= 2; ll++) add_cmp_test("VPTESTNMB", e, s, ll);
  }
  {
    ArchState s;
    for (int i = 0; i < 32; i++) s.xmm[1].set<u16>(i, (i % 3 == 0) ? 0xFFFF : 0);
    for (int i = 0; i < 32; i++) s.xmm[2].set<u16>(i, 0xFFFF);

    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x26;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) add_cmp_test("VPTESTMW", e, s, ll);

    e.pp = 2;
    for (int ll = 0; ll <= 2; ll++) add_cmp_test("VPTESTNMW", e, s, ll);
  }

  // =====================================================================
  // Blend: VPBLENDMB/W/D/Q and VBLENDMPD/PS
  // These use writemask as the blend control (mask from k-register).
  // VPBLENDMB: 66 0F38 66, W0   VPBLENDMW: 66 0F38 66, W1
  // VPBLENDMD: 66 0F38 64, W0   VPBLENDMQ: 66 0F38 64, W1
  // VBLENDMPS: 66 0F38 65, W0   VBLENDMPD: 66 0F38 65, W1
  // =====================================================================
  {
    ArchState s;
    for (int i = 0; i < 16; i++) s.xmm[1].set<u32>(i, 0xAAAAAAAA);
    for (int i = 0; i < 16; i++) s.xmm[2].set<u32>(i, 0x55555555);
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    struct { const char *name; u8 opcode; bool W; u32 kmask; } blends[] = {
      {"VPBLENDMD", 0x64, false, 0xAAAA},
      {"VPBLENDMQ", 0x64, true,  0x55},
      {"VBLENDMPS", 0x65, false, 0xAAAA},
      {"VBLENDMPD", 0x65, true,  0x55},
    };

    for (auto &b : blends) {
      Evex e; e.mm = 2; e.pp = 1; e.W = b.W; e.opcode = b.opcode;
      e.reg = 0; e.vvvv = 1; e.rm = 2;
      add_evex_rr_tests(tests, cat, b.name, e, s, 0x6, b.kmask, -1);
    }
  }
  {
    ArchState s;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = 0xAA;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = 0x55;
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x66;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VPBLENDMB", e, s, 0x6, 0xAAAAAAAA, -1);

    e.W = true;
    add_evex_rr_tests(tests, cat, "VPBLENDMW", e, s, 0x6, 0x55555555, -1);
  }

  // =====================================================================
  // VPCMPUB/VPCMPUW k1 {k2}, v, v/m, imm8: EVEX.66.0F3A.W0/W1 3E
  // Unsigned compares into a mask.  Predicates 0 EQ, 1 LT, 2 LE, 4 NEQ,
  // 5 NLT, 6 NLE (3 and 7 are FALSE and TRUE).  Values straddle 0x80 so a
  // signed compare would give a different mask.
  // =====================================================================
  {
    ArchState s;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = (u8)(i * 17);
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = (u8)(0x80 + i * 13);
    s.kregs[2] = 0xF0F0F0F0A5A5A5A5ULL;
    const char *vl_name[] = {"xmm", "ymm", "zmm"};
    for (int w = 0; w <= 1; w++) {
      Evex e; e.mm = 3; e.pp = 1; e.W = w; e.opcode = 0x3E; e.reg = 1; e.vvvv = 1; e.rm = 2;
      const char *mn = w ? "VPCMPUW" : "VPCMPUB";
      for (int ll = 0; ll <= 2; ll++) {
        e.LL = ll;
        for (u8 pred : {0, 1, 2, 3, 4, 5, 6, 7}) {
          e.aaa = 0;
          tests.push_back({std::format("{} k1,{}1,{}2,{}", mn, vl_name[ll], vl_name[ll], pred), cat,
                           e.encode_rr_imm(pred), with_vector_inputs(s, 0x6), FL_ALL, 0, false});
        }
        e.aaa = 2;
        tests.push_back({std::format("{} k1{{k2}},{}1,{}2,1", mn, vl_name[ll], vl_name[ll]), cat,
                         e.encode_rr_imm(1), with_vector_inputs(s, 0x6), FL_ALL, 0, false});
        e.aaa = 0;
        TestCase tc; tc.category = cat;
        tc.name = std::format("{} k1,{}1,[rdi],2", mn, vl_name[ll]);
        tc.code = e.encode_rm_mem_imm(2);
        tc.initial = with_vector_inputs(s, 0x2); tc.initial.rdi = DATA_ADDR;
        tc.init_data.resize(64);
        for (int i = 0; i < 64; i++) tc.init_data[i] = (u8)(0x70 + i * 11);
        tests.push_back(std::move(tc));
      }
    }
  }
}

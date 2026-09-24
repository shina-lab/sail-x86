#include "kvm-avx-encoder.h"

// Helper: add reg-reg tests starting from a specific VL
static void add_evex_rr_tests_vl(
    std::vector<TestCase> &tests, const std::string &cat, const char *mnemonic,
    Evex base, ArchState init, u32 xmm_inputs, u32 kmask_val, int min_ll) {
  init = with_vector_inputs(init, xmm_inputs);
  const char *vl_name[] = {"xmm", "ymm", "zmm"};
  const int vl_bits[] = {128, 256, 512};
  for (int ll = min_ll; ll <= 2; ll++) {
    std::string suffix = std::string(vl_name[ll]) + " (VL" + std::to_string(vl_bits[ll]) + ")";
    base.LL = ll;
    base.aaa = 0; base.z = false;
    tests.push_back({std::string(mnemonic) + " " + suffix,
                     cat, base.encode_rr(), init, FL_ALL, ~0U, false});
    if (kmask_val) {
      base.aaa = 1; base.z = true;
      tests.push_back({std::string(mnemonic) + " " + suffix + " {k1}{z}",
                       cat, concat(set_kmask(kmask_val), base.encode_rr()), init, FL_ALL, ~0U, false});
      base.aaa = 1; base.z = false;
      tests.push_back({std::string(mnemonic) + " " + suffix + " {k1}",
                       cat, concat(set_kmask(kmask_val), base.encode_rr()),
                       with_merge_input(init, xmm_inputs, base.reg), FL_ALL, ~0U, false});
    }
  }
}

void add_avx_perm_tests(std::vector<TestCase> &tests) {
  std::string cat = "AVX perm";

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

  // VPSHUFD: EVEX.66.0F.W0 70 /r ib (all VLs)
  {
    ArchState s = {};
    for (int i = 0; i < 16; i++) s.xmm[1].set<u32>(i, 0x10 * (i + 1));
    Evex e; e.mm = 1; e.pp = 1; e.W = false; e.opcode = 0x70;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VPSHUFD ") + vl[ll],
                       cat, e.encode_rr_imm(0x1B), s, FL_ALL, 0x3, false});
    }
    // VEX VPSHUFD misaligned — no alignment
    { Vex v; v.mm = 1; v.pp = 1; v.W = false; v.opcode = 0x70;
      v.reg = 0; v.vvvv = 0; v.L = false;
      auto c = v.encode_rm_mem(); c.push_back(0x1B);
      add_vok("VPSHUFD xmm,[rdi] misaligned", c); }
  }

  // VPSHUFHW/VPSHUFLW (all VLs)
  {
    ArchState s = {};
    for (int i = 0; i < 32; i++) s.xmm[1].set<u16>(i, 0x100 * (i + 1));
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      Evex e; e.mm = 1; e.W = false; e.opcode = 0x70;
      e.reg = 0; e.vvvv = 0; e.rm = 1; e.LL = ll; e.aaa = 0; e.z = false;
      e.pp = 2;
      tests.push_back({std::string("VPSHUFHW ") + vl[ll],
                       cat, e.encode_rr_imm(0x1B), s, FL_ALL, 0x3, false});
      e.pp = 3;
      tests.push_back({std::string("VPSHUFLW ") + vl[ll],
                       cat, e.encode_rr_imm(0x1B), s, FL_ALL, 0x3, false});
    }
    // VEX VPSHUFHW/VPSHUFLW misaligned
    { Vex v; v.mm = 1; v.pp = 2; v.W = false; v.opcode = 0x70;
      v.reg = 0; v.vvvv = 0; v.L = false;
      auto c = v.encode_rm_mem(); c.push_back(0x1B);
      add_vok("VPSHUFHW xmm,[rdi] misaligned", c); }
    { Vex v; v.mm = 1; v.pp = 3; v.W = false; v.opcode = 0x70;
      v.reg = 0; v.vvvv = 0; v.L = false;
      auto c = v.encode_rm_mem(); c.push_back(0x1B);
      add_vok("VPSHUFLW xmm,[rdi] misaligned", c); }
  }

  // VPERMD: VL256/512 only
  {
    ArchState s = {};
    for (int i = 0; i < 16; i++) s.xmm[2].set<u32>(i, 0xA0 + i);
    for (int i = 0; i < 16; i++) s.xmm[1].set<u32>(i, (15 - i) % 16);
    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x36;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests_vl(tests, cat, "VPERMD", e, s, 0x6, 0xAAAA, 1);
    { Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x36;
      v.reg = 0; v.vvvv = 1; v.L = true;
      add_vok("VPERMD ymm,[rdi] misaligned", v.encode_rm_mem(), {1}); }
  }

  // VPERMQ: VL256/512 only
  {
    ArchState s = {};
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = 0xA0 + i;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = (7 - i) % 8;
    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x36;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests_vl(tests, cat, "VPERMQ", e, s, 0x6, 0x55, 1);
    // VEX VPERMQ imm: VEX.256.66.0F3A.W1 00 /r ib
    { Vex v; v.mm = 3; v.pp = 1; v.W = true; v.opcode = 0x00;
      v.reg = 0; v.vvvv = 0; v.L = true;
      auto c = v.encode_rm_mem(); c.push_back(0x1B);
      add_vok("VPERMQ ymm,[rdi] misaligned", c); }
  }

  // VPERMILPS/PD (all VLs)
  {
    ArchState s = {};
    for (int i = 0; i < 16; i++) s.xmm[1].set<u32>(i, 0x10 * (i + 1));
    for (int i = 0; i < 16; i++) s.xmm[2].set<u32>(i, (3 - (i % 4)));
    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x0C;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VPERMILPS", e, s, 0x6, 0xAAAA);
    { Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x0C;
      v.reg = 0; v.vvvv = 1; v.L = false;
      add_vok("VPERMILPS xmm,[rdi] (reg) misaligned", v.encode_rm_mem(), {1}); }
  }
  {
    ArchState s = {};
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x100 * (i + 1);
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = (1 - (i % 2));
    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x0D;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VPERMILPD", e, s, 0x6, 0x55);
    { Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x0D;
      v.reg = 0; v.vvvv = 1; v.L = false;
      add_vok("VPERMILPD xmm,[rdi] (reg) misaligned", v.encode_rm_mem(), {1}); }
  }

  // VPALIGNR (all VLs)
  {
    ArchState s = {};
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = 0xA0 + (i % 16);
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = 0x10 + (i % 16);
    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x0F;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VPALIGNR ") + vl[ll],
                       cat, e.encode_rr_imm(4), s, FL_ALL, 0x7, false});
    }
    { Vex v; v.mm = 3; v.pp = 1; v.W = false; v.opcode = 0x0F;
      v.reg = 0; v.vvvv = 1; v.L = false;
      auto c = v.encode_rm_mem(); c.push_back(4);
      add_vok("VPALIGNR xmm,[rdi] misaligned", c, {1}); }
  }

  // VALIGND/Q (all VLs)
  {
    ArchState s = {};
    for (int i = 0; i < 16; i++) s.xmm[1].set<u32>(i, 0xA0 + i);
    for (int i = 0; i < 16; i++) s.xmm[2].set<u32>(i, 0x10 + i);
    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x03;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VALIGND ") + vl[ll],
                       cat, e.encode_rr_imm(2), s, FL_ALL, 0x7, false});
    }
  }
  {
    ArchState s = {};
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0xA0 + i;
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = 0x10 + i;
    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.opcode = 0x03;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VALIGNQ ") + vl[ll],
                       cat, e.encode_rr_imm(1), s, FL_ALL, 0x7, false});
    }
  }

  // VPBROADCASTD/Q/B/W (all VLs)
  {
    ArchState s = {};
    s.xmm[1] = xmm_from_u64(0xDEADBEEFCAFEBABE, 0x1234567890ABCDEF);
    struct { const char *name; u8 opcode; bool W; u32 kmask; } bcasts[] = {
      {"VPBROADCASTD", 0x58, false, 0xAAAA},
      {"VPBROADCASTQ", 0x59, true,  0x55},
      {"VPBROADCASTB", 0x78, false, 0xAAAAAAAA},
      {"VPBROADCASTW", 0x79, false, 0x55555555},
    };
    for (const auto &b : bcasts) {
      Evex e; e.mm = 2; e.pp = 1; e.W = b.W; e.opcode = b.opcode;
      e.reg = 0; e.vvvv = 0; e.rm = 1;
      add_evex_rr_tests(tests, cat, b.name, e, s, 0x2, b.kmask);
    }
    // VEX broadcast from memory — no alignment
    { Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x58;
      v.reg = 0; v.vvvv = 0; v.L = false;
      add_vok("VPBROADCASTD xmm,[rdi] misaligned", v.encode_rm_mem()); }
    { Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x59;
      v.reg = 0; v.vvvv = 0; v.L = false;
      add_vok("VPBROADCASTQ xmm,[rdi] misaligned", v.encode_rm_mem()); }
    { Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x78;
      v.reg = 0; v.vvvv = 0; v.L = false;
      add_vok("VPBROADCASTB xmm,[rdi] misaligned", v.encode_rm_mem()); }
    { Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x79;
      v.reg = 0; v.vvvv = 0; v.L = false;
      add_vok("VPBROADCASTW xmm,[rdi] misaligned", v.encode_rm_mem()); }
  }

  // VBROADCASTSS (all VLs)
  {
    ArchState s = {};
    float f = 3.14f; memcpy(&s.xmm[1].q[0], &f, 4);
    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x18;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VBROADCASTSS", e, s, 0x2, 0xAAAA);
    { Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x18;
      v.reg = 0; v.vvvv = 0; v.L = false;
      add_vok("VBROADCASTSS xmm,[rdi] misaligned", v.encode_rm_mem()); }
  }

  // VBROADCASTSD: VL256/512 only
  {
    ArchState s = {};
    double d = 2.718; memcpy(&s.xmm[1].q[0], &d, 8);
    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x19;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests_vl(tests, cat, "VBROADCASTSD", e, s, 0x2, 0x55, 1);
    { Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x19;
      v.reg = 0; v.vvvv = 0; v.L = true;
      add_vok("VBROADCASTSD ymm,[rdi] misaligned", v.encode_rm_mem()); }
    // VBROADCASTF128: VEX.256.66.0F38 1A
    { Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x1A;
      v.reg = 0; v.vvvv = 0; v.L = true;
      add_vok("VBROADCASTF128 ymm,[rdi] misaligned", v.encode_rm_mem()); }
    // VBROADCASTI128: VEX.256.66.0F38 5A
    { Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x5A;
      v.reg = 0; v.vvvv = 0; v.L = true;
      add_vok("VBROADCASTI128 ymm,[rdi] misaligned", v.encode_rm_mem()); }
  }

  // VMOVDDUP/VMOVSHDUP/VMOVSLDUP (all VLs)
  {
    ArchState s = {};
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x1000 * (i + 1) + i;
    Evex e; e.mm = 1; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.pp = 3; e.W = true; e.opcode = 0x12;
    add_evex_rr_tests(tests, cat, "VMOVDDUP", e, s, 0x2, 0x55);
    e.pp = 2; e.W = false; e.opcode = 0x16;
    add_evex_rr_tests(tests, cat, "VMOVSHDUP", e, s, 0x2, 0xAAAA);
    e.pp = 2; e.W = false; e.opcode = 0x12;
    add_evex_rr_tests(tests, cat, "VMOVSLDUP", e, s, 0x2, 0xAAAA);
  }

  // VSHUFPS/PD (all VLs)
  {
    ArchState s = {};
    for (int i = 0; i < 16; i++) s.xmm[1].set<u32>(i, 0x10 * (i + 1));
    for (int i = 0; i < 16; i++) s.xmm[2].set<u32>(i, 0xA0 + i);
    Evex e; e.mm = 1; e.pp = 0; e.W = false; e.opcode = 0xC6;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VSHUFPS ") + vl[ll],
                       cat, e.encode_rr_imm(0x1B), s, FL_ALL, 0x7, false});
    }
  }
  {
    ArchState s = {};
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x100 * (i + 1);
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = 0xA00 + i;
    Evex e; e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0xC6;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VSHUFPD ") + vl[ll],
                       cat, e.encode_rr_imm(0x05), s, FL_ALL, 0x7, false});
    }
  }

  // VPERMW/VPERMB (all VLs)
  {
    ArchState s = {};
    for (int i = 0; i < 32; i++) s.xmm[2].set<u16>(i, 0x100 * (i + 1));
    for (int i = 0; i < 32; i++) s.xmm[1].set<u16>(i, (31 - i));
    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x8D;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VPERMW", e, s, 0x6, 0x55555555);
  }
  {
    ArchState s = {};
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = i + 1;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = (63 - i);
    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x8D;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VPERMB", e, s, 0x6, 0xAAAAAAAA);
  }

  // VPERMPS: EVEX.66.0F38.W0 16 /r (VL256/512 only)
  {
    ArchState s = {};
    for (int i = 0; i < 16; i++) s.xmm[2].set<u32>(i, 0xA0 + i);
    for (int i = 0; i < 16; i++) s.xmm[1].set<u32>(i, (15 - i) % 16);
    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x16;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests_vl(tests, cat, "VPERMPS", e, s, 0x6, 0xAAAA, 1);
    { Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x16;
      v.reg = 0; v.vvvv = 1; v.L = true;
      add_vok("VPERMPS ymm,[rdi] misaligned", v.encode_rm_mem(), {1}); }
  }

  // VPERMPD: EVEX.66.0F38.W1 16 /r (VL256/512 only)
  {
    ArchState s = {};
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = 0xA0 + i;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = (7 - i) % 8;
    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x16;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests_vl(tests, cat, "VPERMPD", e, s, 0x6, 0x55, 1);
    // VEX VPERMPD imm: VEX.256.66.0F3A.W1 01 /r ib
    { Vex v; v.mm = 3; v.pp = 1; v.W = true; v.opcode = 0x01;
      v.reg = 0; v.vvvv = 0; v.L = true;
      auto c = v.encode_rm_mem(); c.push_back(0x1B);
      add_vok("VPERMPD ymm,[rdi] misaligned", c); }
  }

  // VPERMI2D: EVEX.66.0F38.W0 76 /r
  // VPERMI2Q: EVEX.66.0F38.W1 76 /r
  // VPERMI2PS: EVEX.66.0F38.W0 77 /r
  // VPERMI2PD: EVEX.66.0F38.W1 77 /r
  // VPERMI2B: EVEX.66.0F38.W0 75 /r
  // VPERMI2W: EVEX.66.0F38.W1 75 /r
  {
    ArchState s = {};
    // dst = indices, src1(vvvv) = table0, src2(rm) = table1
    for (int i = 0; i < 16; i++) s.xmm[0].set<u32>(i, i);  // indices
    for (int i = 0; i < 16; i++) s.xmm[1].set<u32>(i, 0xA0 + i);
    for (int i = 0; i < 16; i++) s.xmm[2].set<u32>(i, 0xB0 + i);

    Evex e; e.mm = 2; e.pp = 1; e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.W = false; e.opcode = 0x76;
    add_evex_rr_tests(tests, cat, "VPERMI2D", e, s, 0x7, 0xAAAA);
    e.W = true;
    add_evex_rr_tests(tests, cat, "VPERMI2Q", e, s, 0x7, 0x55);
    e.W = false; e.opcode = 0x77;
    add_evex_rr_tests(tests, cat, "VPERMI2PS", e, s, 0x7, 0xAAAA);
    e.W = true;
    add_evex_rr_tests(tests, cat, "VPERMI2PD", e, s, 0x7, 0x55);
  }
  {
    ArchState s = {};
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[0].q)[i] = i;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = 0xA0 + i;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = 0xB0 + i;

    Evex e; e.mm = 2; e.pp = 1; e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.W = false; e.opcode = 0x75;
    add_evex_rr_tests(tests, cat, "VPERMI2B", e, s, 0x7, 0xAAAAAAAA);
    e.W = true;
    add_evex_rr_tests(tests, cat, "VPERMI2W", e, s, 0x7, 0x55555555);
  }

  // VPERMT2D: EVEX.66.0F38.W0 7E /r
  // VPERMT2Q: EVEX.66.0F38.W1 7E /r
  // VPERMT2PS: EVEX.66.0F38.W0 7F /r
  // VPERMT2PD: EVEX.66.0F38.W1 7F /r
  // VPERMT2B: EVEX.66.0F38.W0 7D /r
  // VPERMT2W: EVEX.66.0F38.W1 7D /r
  {
    ArchState s = {};
    for (int i = 0; i < 16; i++) s.xmm[0].set<u32>(i, 0xA0 + i);  // table0
    for (int i = 0; i < 16; i++) s.xmm[1].set<u32>(i, i);  // indices (vvvv)
    for (int i = 0; i < 16; i++) s.xmm[2].set<u32>(i, 0xB0 + i);  // table1

    Evex e; e.mm = 2; e.pp = 1; e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.W = false; e.opcode = 0x7E;
    add_evex_rr_tests(tests, cat, "VPERMT2D", e, s, 0x7, 0xAAAA);
    e.W = true;
    add_evex_rr_tests(tests, cat, "VPERMT2Q", e, s, 0x7, 0x55);
    e.W = false; e.opcode = 0x7F;
    add_evex_rr_tests(tests, cat, "VPERMT2PS", e, s, 0x7, 0xAAAA);
    e.W = true;
    add_evex_rr_tests(tests, cat, "VPERMT2PD", e, s, 0x7, 0x55);
  }
  {
    ArchState s = {};
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[0].q)[i] = 0xA0 + i;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = i;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = 0xB0 + i;

    Evex e; e.mm = 2; e.pp = 1; e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.W = false; e.opcode = 0x7D;
    add_evex_rr_tests(tests, cat, "VPERMT2B", e, s, 0x7, 0xAAAAAAAA);
    e.W = true;
    add_evex_rr_tests(tests, cat, "VPERMT2W", e, s, 0x7, 0x55555555);
  }

  // =====================================================================
  // Broadcasts from general-purpose and mask registers, the bit shuffle
  // into a mask, the immediate in-lane qword permute, the 128-bit lane
  // shuffles, and the insert/extract family:
  //   VPBROADCASTW v {k}{z}, r32        EVEX.66.0F38.W0 7B
  //   VPBROADCASTD/Q v {k}{z}, r32/r64  EVEX.66.0F38.W0/W1 7C
  //   VPBROADCASTMB2Q v, k              EVEX.F3.0F38.W1 2A
  //   VPSHUFBITQMB k {k}, v, v/m        EVEX.66.0F38.W0 8F
  //   VPERMILPD v {k}{z}, v/m/bcst, imm8            EVEX.66.0F3A.W1 05
  //   VSHUFF32X4/F64X2, VSHUFI32X4/I64X2, imm8      EVEX.66.0F3A.W0/W1 23, 43
  //   VINSERTF32X4/F64X2 18, VEXTRACTF32X4/F64X2 19, VINSERTF32X8/F64X4 1A,
  //   VEXTRACTF32X8/F64X4 1B, and the integer twins 38, 39, 3A, 3B
  //   VINSERTPS xmm, xmm, xmm/m32, imm8             EVEX.66.0F3A.W0 21
  // =====================================================================
  {
    const char *vl_name[] = {"xmm", "ymm", "zmm"};
    std::vector<u8> mem(64);
    for (int i = 0; i < 64; i++) mem[i] = 0xC0 + i;

    // reg-reg with imm8 at the given VLs: no mask, zeroing, merging; the
    // merging destination gets a sentinel.  The mask is loaded through the
    // initial k1 so 32- and 64-bit masks work too.
    auto add_imm_vls = [&](const std::string &name, Evex e, ArchState init,
                           u32 inputs, u8 imm, u64 kmask, int min_ll, int max_ll) {
      init = with_vector_inputs(init, inputs);
      for (int ll = min_ll; ll <= max_ll; ll++) {
        e.LL = ll;
        std::string sfx = std::format(" {} imm={:#x}", vl_name[ll], imm);
        e.aaa = 0; e.z = false;
        tests.push_back({name + sfx, cat, e.encode_rr_imm(imm), init, FL_ALL, 0, false});
        if (!kmask) continue;
        ArchState km = init; km.kregs[1] = kmask;
        e.aaa = 1; e.z = true;
        tests.push_back({name + sfx + " {k1}{z}", cat, e.encode_rr_imm(imm), km, FL_ALL, 0, false});
        e.aaa = 1; e.z = false;
        tests.push_back({name + sfx + " {k1}", cat, e.encode_rr_imm(imm),
                         with_merge_input(km, inputs, e.reg), FL_ALL, 0, false});
      }
    };
    // memory source [rdi] (and the broadcast form when bcast is set)
    auto add_imm_mem = [&](const std::string &name, Evex e, ArchState init, u32 inputs,
                           u8 imm, int min_ll, int max_ll, bool bcast) {
      init = with_vector_inputs(init, inputs);
      init.rdi = DATA_ADDR;
      for (int ll = min_ll; ll <= max_ll; ll++) {
        e.LL = ll; e.aaa = 0; e.z = false;
        TestCase tc; tc.category = cat; tc.initial = init; tc.init_data = mem;
        tc.name = std::format("{} {} [rdi] imm={:#x}", name, vl_name[ll], imm);
        tc.code = e.encode_rm_mem_imm(imm);
        tests.push_back(std::move(tc));
        if (bcast) {
          TestCase tb; tb.category = cat; tb.initial = init; tb.init_data = mem;
          tb.name = std::format("{} {} [rdi]{{1toN}} imm={:#x}", name, vl_name[ll], imm);
          tb.code = e.encode_rm_bcast_imm(imm);
          tests.push_back(std::move(tb));
        }
      }
    };

    // VPBROADCASTW/D/Q from a GPR, from rax and from r9.
    {
      ArchState s; s.rax = 0x0123456789ABCDEF; s.r9 = 0xFEDCBA9876543210;
      for (int gpr : {0, 9}) {
        ArchState in = with_gpr_inputs(s, {gpr ? &ArchState::r9 : &ArchState::rax});
        std::string src = gpr ? "r9" : "rax";
        Evex e; e.mm = 2; e.pp = 1; e.reg = 0; e.vvvv = 0; e.rm = gpr;
        e.W = false; e.opcode = 0x7B;
        add_evex_rr_tests(tests, cat, ("VPBROADCASTW " + src).c_str(), e, in, 0, 0xA5A5);
        e.opcode = 0x7C;
        add_evex_rr_tests(tests, cat, ("VPBROADCASTD " + src).c_str(), e, in, 0, 0xAAAA);
        e.W = true;
        add_evex_rr_tests(tests, cat, ("VPBROADCASTQ " + src).c_str(), e, in, 0, 0x55);
      }
    }

    // VPBROADCASTMB2Q: the low byte of the mask register named by ModRM.r/m.
    {
      ArchState s; s.kregs[1] = 0xFFFF00A5C3; s.kregs[7] = 0x3C;
      Evex e; e.mm = 2; e.pp = 2; e.W = true; e.opcode = 0x2A; e.reg = 0; e.vvvv = 0;
      for (int k : {1, 7}) {
        e.rm = k;
        for (int ll = 0; ll <= 2; ll++) {
          e.LL = ll;
          tests.push_back({std::format("VPBROADCASTMB2Q {}0,k{}", vl_name[ll], k),
                           cat, e.encode_rr(), s, FL_ALL, 0, false});
        }
      }
    }

    // VPSHUFBITQMB k1{k2}, v(vvvv), v/m(rm): bit m of SRC1.qword[i] where
    // m is byte j of SRC2.qword[i] & 63.  Distinct operands so a swap shows.
    {
      ArchState s;
      for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x8000000000000001ULL << (i * 3) | (0x00FF00FF00FF00FFULL >> i);
      for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = (u8)((i * 37 + 5) & 0xFF);  // indices, some >= 64
      s.kregs[2] = 0x5A5A5A5AF0F0F0F0ULL;
      Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x8F; e.reg = 1; e.vvvv = 1; e.rm = 2;
      for (int ll = 0; ll <= 2; ll++) {
        e.LL = ll;
        e.aaa = 0;
        tests.push_back({std::format("VPSHUFBITQMB k1,{}1,{}2", vl_name[ll], vl_name[ll]),
                         cat, e.encode_rr(), with_vector_inputs(s, 0x6), FL_ALL, 0, false});
        e.aaa = 2;
        tests.push_back({std::format("VPSHUFBITQMB k1{{k2}},{}1,{}2", vl_name[ll], vl_name[ll]),
                         cat, e.encode_rr(), with_vector_inputs(s, 0x6), FL_ALL, 0, false});
        e.aaa = 0;
        TestCase tc; tc.category = cat;
        tc.name = std::format("VPSHUFBITQMB k1,{}1,[rdi]", vl_name[ll]);
        tc.code = e.encode_rm_mem();
        tc.initial = with_vector_inputs(s, 0x2); tc.initial.rdi = DATA_ADDR;
        tc.init_data = mem;
        tests.push_back(std::move(tc));
      }
    }

    // VPERMILPD with imm8: bit i selects the low or high qword of the
    // 128-bit lane for element i.
    {
      ArchState s;
      for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x1010101010101010ULL * (i + 1);
      Evex e; e.mm = 3; e.pp = 1; e.W = true; e.opcode = 0x05; e.reg = 0; e.vvvv = 0; e.rm = 1;
      for (u8 imm : {0x00, 0x5A, 0xFF})
        add_imm_vls("VPERMILPD", e, s, 0x2, imm, 0x55, 0, 2);
      add_imm_mem("VPERMILPD", e, s, 0, 0x5A, 0, 2, true);
    }

    // VSHUFF32X4/F64X2 and VSHUFI32X4/I64X2: 128-bit lanes from src1 (low
    // half) and src2 (high half) selected by imm8; 256- and 512-bit only.
    {
      ArchState s;
      for (int i = 0; i < 16; i++) { s.xmm[1].set<u32>(i, 0xA0000000 + i); s.xmm[2].set<u32>(i, 0xB0000000 + i); }
      for (u8 op : {0x23, 0x43}) {
        std::string f = op == 0x23 ? "VSHUFF" : "VSHUFI";
        Evex e; e.mm = 3; e.pp = 1; e.opcode = op; e.reg = 0; e.vvvv = 1; e.rm = 2;
        e.W = false;
        for (u8 imm : {0x4E, 0x1B, 0xFF})
          add_imm_vls(f + "32X4", e, s, 0x6, imm, 0xAAAA, 1, 2);
        add_imm_mem(f + "32X4", e, s, 0x2, 0x4E, 1, 2, true);
        e.W = true;
        for (u8 imm : {0x4E, 0x03})
          add_imm_vls(f + "64X2", e, s, 0x6, imm, 0x55, 1, 2);
        add_imm_mem(f + "64X2", e, s, 0x2, 0x4E, 1, 2, true);
      }
    }

    // Insert/extract of 128- and 256-bit pieces.
    {
      ArchState s;
      for (int i = 0; i < 16; i++) { s.xmm[1].set<u32>(i, 0xA0000000 + i); s.xmm[2].set<u32>(i, 0xB0000000 + i); }
      struct { const char *name; u8 op; bool W; int min_ll; } ins[] = {
        {"VINSERTF32X4", 0x18, false, 1}, {"VINSERTF64X2", 0x18, true, 1},
        {"VINSERTI32X4", 0x38, false, 1}, {"VINSERTI64X2", 0x38, true, 1},
        {"VINSERTF32X8", 0x1A, false, 2}, {"VINSERTF64X4", 0x1A, true, 2},
        {"VINSERTI32X8", 0x3A, false, 2}, {"VINSERTI64X4", 0x3A, true, 2},
      };
      for (auto &in : ins) {
        Evex e; e.mm = 3; e.pp = 1; e.W = in.W; e.opcode = in.op; e.reg = 0; e.vvvv = 1; e.rm = 2;
        for (u8 imm : {0, 1, 2, 3})
          add_imm_vls(in.name, e, s, 0x6, imm, in.W ? 0x55 : 0xAAAA, in.min_ll, 2);
        add_imm_mem(in.name, e, s, 0x2, 1, in.min_ll, 2, false);
      }

      // Extract: ModRM.reg is the source vector, r/m the xmm/ymm or memory
      // destination.  Memory destinations honour the writemask per element.
      struct { const char *name; u8 op; bool W; int min_ll; } ext[] = {
        {"VEXTRACTF32X4", 0x19, false, 1}, {"VEXTRACTF64X2", 0x19, true, 1},
        {"VEXTRACTI32X4", 0x39, false, 1}, {"VEXTRACTI64X2", 0x39, true, 1},
        {"VEXTRACTF32X8", 0x1B, false, 2}, {"VEXTRACTF64X4", 0x1B, true, 2},
        {"VEXTRACTI32X8", 0x3B, false, 2}, {"VEXTRACTI64X4", 0x3B, true, 2},
      };
      for (auto &ex : ext) {
        Evex e; e.mm = 3; e.pp = 1; e.W = ex.W; e.opcode = ex.op; e.reg = 1; e.vvvv = 0; e.rm = 0;
        ArchState in = with_vector_inputs(s, 0x2);
        for (int ll = ex.min_ll; ll <= 2; ll++) {
          e.LL = ll;
          for (u8 imm : {0, 1, 3}) {
            std::string sfx = std::format(" xmm0,{}1 imm={}", vl_name[ll], imm);
            e.aaa = 0; e.z = false;
            tests.push_back({ex.name + sfx, cat, e.encode_rr_imm(imm), in, FL_ALL, 0, false});
            ArchState km = in; km.kregs[1] = ex.W ? 0x5 : 0x55;
            e.aaa = 1; e.z = true;
            tests.push_back({ex.name + sfx + " {k1}{z}", cat, e.encode_rr_imm(imm), km, FL_ALL, 0, false});
            e.aaa = 1; e.z = false;
            tests.push_back({ex.name + sfx + " {k1}", cat, e.encode_rr_imm(imm),
                             with_merge_input(km, 0x2, 0), FL_ALL, 0, false});
          }
          // to memory, unmasked and masked
          for (int masked = 0; masked <= 1; masked++) {
            e.aaa = masked; e.z = false;
            TestCase tc; tc.category = cat;
            tc.name = std::format("{} [rdi]{},{}1 imm=1", ex.name, masked ? "{k1}" : "", vl_name[ll]);
            tc.code = e.encode_rm_mem_imm(1);
            tc.initial = in; tc.initial.rdi = DATA_ADDR;
            if (masked) tc.initial.kregs[1] = ex.W ? 0x9 : 0x69;
            tc.init_data = std::vector<u8>(64, 0xCC); tc.compare_data_len = 64;
            tests.push_back(std::move(tc));
          }
        }
      }

      // EVEX.128 is not a defined vector length for these: #UD.
      for (u8 op : {0x18, 0x19, 0x1A, 0x1B}) {
        Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = op; e.reg = 0; e.vvvv = 1; e.rm = 2; e.LL = 0;
        TestCase tc; tc.category = cat;
        tc.name = std::format("VINSERT/VEXTRACT opcode {:#x} with L'L=0 #UD", op);
        tc.code = e.encode_rr_imm(0);
        tc.initial = with_vector_inputs(s, 0x6);
        tc.expect_fault = true; tc.expected_vector = 6;
        tests.push_back(std::move(tc));
      }
      for (u8 op : {0x1A, 0x1B}) {
        Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = op; e.reg = 0; e.vvvv = 1; e.rm = 2; e.LL = 1;
        TestCase tc; tc.category = cat;
        tc.name = std::format("VINSERT/VEXTRACT opcode {:#x} with L'L=1 #UD", op);
        tc.code = e.encode_rr_imm(0);
        tc.initial = with_vector_inputs(s, 0x6);
        tc.expect_fault = true; tc.expected_vector = 6;
        tests.push_back(std::move(tc));
      }
    }

    // VINSERTPS: imm8[7:6] selects the source element (register form),
    // [5:4] the destination position, [3:0] zeroes elements.
    {
      ArchState s;
      for (int i = 0; i < 4; i++) { s.xmm[1].set<u32>(i, 0xA0 + i); s.xmm[2].set<u32>(i, 0xB0 + i); }
      Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x21; e.reg = 0; e.vvvv = 1; e.rm = 2; e.LL = 0;
      for (u8 imm : {0x00, 0x10, 0xC8, 0x0F, 0xE9, 0x36})
        tests.push_back({std::format("VINSERTPS xmm0,xmm1,xmm2,{:#x}", imm), cat,
                         e.encode_rr_imm(imm), with_vector_inputs(s, 0x6), FL_ALL, 0, false});
      for (u8 imm : {0x00, 0x30, 0xC5}) {
        TestCase tc; tc.category = cat;
        tc.name = std::format("VINSERTPS xmm0,xmm1,[rdi],{:#x}", imm);
        tc.code = e.encode_rm_mem_imm(imm);
        tc.initial = with_vector_inputs(s, 0x2); tc.initial.rdi = DATA_ADDR;
        tc.init_data = mem;
        tests.push_back(std::move(tc));
      }
    }
  }
}

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
    tc.initial = {.rdi = DATA_ADDR + 1, .rflags = 0x2};
    for (unsigned reg : vector_inputs)
      tc.initial.xmm[reg] = {};
    tc.xmm_mask = 0x1; tc.init_data = adata;
    tests.push_back(std::move(tc));
  };

  // VPSHUFD: EVEX.66.0F.W0 70 /r ib (all VLs)
  {
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 32; i++) s.xmm[2].set<u16>(i, 0x100 * (i + 1));
    for (int i = 0; i < 32; i++) s.xmm[1].set<u16>(i, (31 - i));
    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x8D;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VPERMW", e, s, 0x6, 0x55555555);
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = i + 1;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = (63 - i);
    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x8D;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VPERMB", e, s, 0x6, 0xAAAAAAAA);
  }

  // VPERMPS: EVEX.66.0F38.W0 16 /r (VL256/512 only)
  {
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[0].q)[i] = 0xA0 + i;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = i;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = 0xB0 + i;

    Evex e; e.mm = 2; e.pp = 1; e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.W = false; e.opcode = 0x7D;
    add_evex_rr_tests(tests, cat, "VPERMT2B", e, s, 0x7, 0xAAAAAAAA);
    e.W = true;
    add_evex_rr_tests(tests, cat, "VPERMT2W", e, s, 0x7, 0x55555555);
  }
}

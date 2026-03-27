#include "kvm-avx-encoder.h"

// Helper: add reg-reg tests starting from a specific VL
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
      base.aaa = 1; base.z = false;
      tests.push_back({std::string(mnemonic) + " " + suffix + " {k1}",
                       cat, concat(set_kmask(kmask_val), base.encode_rr()), init, FL_NONE, xmm_cmp, false});
    }
  }
}

void add_avx_perm_tests(std::vector<TestCase> &tests) {
  std::string cat = "AVX perm";

  // VPSHUFD: EVEX.66.0F.W0 70 /r ib (all VLs)
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[1].q)[i] = 0x10 * (i + 1);
    Evex e; e.mm = 1; e.pp = 1; e.W = false; e.opcode = 0x70;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VPSHUFD ") + vl[ll],
                       cat, e.encode_rr_imm(0x1B), s, FL_NONE, 0x3, false});
    }
  }

  // VPSHUFHW/VPSHUFLW (all VLs)
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 32; i++) ((u16 *)s.xmm[1].q)[i] = 0x100 * (i + 1);
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      Evex e; e.mm = 1; e.W = false; e.opcode = 0x70;
      e.reg = 0; e.vvvv = 0; e.rm = 1; e.LL = ll; e.aaa = 0; e.z = false;
      e.pp = 2;
      tests.push_back({std::string("VPSHUFHW ") + vl[ll],
                       cat, e.encode_rr_imm(0x1B), s, FL_NONE, 0x3, false});
      e.pp = 3;
      tests.push_back({std::string("VPSHUFLW ") + vl[ll],
                       cat, e.encode_rr_imm(0x1B), s, FL_NONE, 0x3, false});
    }
  }

  // VPERMD: VL256/512 only
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[2].q)[i] = 0xA0 + i;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[1].q)[i] = (15 - i) % 16;
    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x36;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests_vl(tests, cat, "VPERMD", e, s, 0x7, 0xAAAA, 1);
  }

  // VPERMQ: VL256/512 only
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = 0xA0 + i;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = (7 - i) % 8;
    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x36;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests_vl(tests, cat, "VPERMQ", e, s, 0x7, 0x55, 1);
  }

  // VPERMILPS/PD (all VLs)
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[1].q)[i] = 0x10 * (i + 1);
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[2].q)[i] = (3 - (i % 4));
    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x0C;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VPERMILPS", e, s, 0x7, 0xAAAA);
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x100 * (i + 1);
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = (1 - (i % 2));
    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x0D;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VPERMILPD", e, s, 0x7, 0x55);
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
                       cat, e.encode_rr_imm(4), s, FL_NONE, 0x7, false});
    }
  }

  // VALIGND/Q (all VLs)
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[1].q)[i] = 0xA0 + i;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[2].q)[i] = 0x10 + i;
    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x03;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VALIGND ") + vl[ll],
                       cat, e.encode_rr_imm(2), s, FL_NONE, 0x7, false});
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
                       cat, e.encode_rr_imm(1), s, FL_NONE, 0x7, false});
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
      add_evex_rr_tests(tests, cat, b.name, e, s, 0x3, b.kmask);
    }
  }

  // VBROADCASTSS (all VLs)
  {
    ArchState s = {}; s.rflags = 0x2;
    float f = 3.14f; memcpy(&s.xmm[1].q[0], &f, 4);
    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x18;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VBROADCASTSS", e, s, 0x3, 0xAAAA);
  }

  // VBROADCASTSD: VL256/512 only
  {
    ArchState s = {}; s.rflags = 0x2;
    double d = 2.718; memcpy(&s.xmm[1].q[0], &d, 8);
    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x19;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests_vl(tests, cat, "VBROADCASTSD", e, s, 0x3, 0x55, 1);
  }

  // VMOVDDUP/VMOVSHDUP/VMOVSLDUP (all VLs)
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x1000 * (i + 1) + i;
    Evex e; e.mm = 1; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.pp = 3; e.W = true; e.opcode = 0x12;
    add_evex_rr_tests(tests, cat, "VMOVDDUP", e, s, 0x3, 0x55);
    e.pp = 2; e.W = false; e.opcode = 0x16;
    add_evex_rr_tests(tests, cat, "VMOVSHDUP", e, s, 0x3, 0xAAAA);
    e.pp = 2; e.W = false; e.opcode = 0x12;
    add_evex_rr_tests(tests, cat, "VMOVSLDUP", e, s, 0x3, 0xAAAA);
  }

  // VSHUFPS/PD (all VLs)
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[1].q)[i] = 0x10 * (i + 1);
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[2].q)[i] = 0xA0 + i;
    Evex e; e.mm = 1; e.pp = 0; e.W = false; e.opcode = 0xC6;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VSHUFPS ") + vl[ll],
                       cat, e.encode_rr_imm(0x1B), s, FL_NONE, 0x7, false});
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
                       cat, e.encode_rr_imm(0x05), s, FL_NONE, 0x7, false});
    }
  }

  // VPERMW/VPERMB (all VLs)
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 32; i++) ((u16 *)s.xmm[2].q)[i] = 0x100 * (i + 1);
    for (int i = 0; i < 32; i++) ((u16 *)s.xmm[1].q)[i] = (31 - i);
    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x8D;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VPERMW", e, s, 0x7, 0x55555555);
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = i + 1;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = (63 - i);
    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x8D;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VPERMB", e, s, 0x7, 0xAAAAAAAA);
  }
}

#include "kvm-avx-encoder.h"

void add_avx_fma_tests(std::vector<TestCase> &tests) {
  std::string cat = "AVX FMA";

  // FMA3 instructions: EVEX.66.0F38.W0/W1 opcode /r
  // All are ternary: dst = op(src1, src2, src3) where the three operands
  // are mapped differently for 132/213/231 orderings.
  //
  // Opcode table:
  //   VFMADD:    132=0x98, 213=0xA8, 231=0xB8
  //   VFMSUB:    132=0x9A, 213=0xAA, 231=0xBA
  //   VFNMADD:   132=0x9C, 213=0xAC, 231=0xBC
  //   VFNMSUB:   132=0x9E, 213=0xAE, 231=0xBE
  //   VFMADDSUB: 132=0x96, 213=0xA6, 231=0xB6
  //   VFMSUBADD: 132=0x97, 213=0xA7, 231=0xB7
  //
  // PS: pp=66, W=0   PD: pp=66, W=1

  struct FmaOp {
    const char *name;
    u8 opc_132, opc_213, opc_231;
  };

  static const FmaOp ops[] = {
    {"VFMADD",    0x98, 0xA8, 0xB8},
    {"VFMSUB",    0x9A, 0xAA, 0xBA},
    {"VFNMADD",   0x9C, 0xAC, 0xBC},
    {"VFNMSUB",   0x9E, 0xAE, 0xBE},
    {"VFMADDSUB", 0x96, 0xA6, 0xB6},
    {"VFMSUBADD", 0x97, 0xA7, 0xB7},
  };

  static const struct {
    const char *suffix;
    u8 opc_offset;  // 132=0, 213=1, 231=2
  } orderings[] = {
    {"132", 0}, {"213", 1}, {"231", 2},
  };

  // Packed f32 state
  ArchState sps;
  sps.rflags = 0x2;
  float ps0[] = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f,
                 9.0f, 10.0f, 11.0f, 12.0f, 13.0f, 14.0f, 15.0f, 16.0f};
  float ps1[] = {0.5f, 1.5f, 2.5f, 3.5f, 4.5f, 5.5f, 6.5f, 7.5f,
                 8.5f, 9.5f, 10.5f, 11.5f, 12.5f, 13.5f, 14.5f, 15.5f};
  float ps2[] = {100.0f, 200.0f, 300.0f, 400.0f, 500.0f, 600.0f, 700.0f, 800.0f,
                 900.0f, 1000.0f, 1100.0f, 1200.0f, 1300.0f, 1400.0f, 1500.0f, 1600.0f};
  memcpy(sps.xmm[0].q, ps0, 64);
  memcpy(sps.xmm[1].q, ps1, 64);
  memcpy(sps.xmm[2].q, ps2, 64);

  // Packed f64 state
  ArchState spd;
  spd.rflags = 0x2;
  double pd0[] = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0};
  double pd1[] = {0.5, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5};
  double pd2[] = {100.0, 200.0, 300.0, 400.0, 500.0, 600.0, 700.0, 800.0};
  memcpy(spd.xmm[0].q, pd0, 64);
  memcpy(spd.xmm[1].q, pd1, 64);
  memcpy(spd.xmm[2].q, pd2, 64);

  std::vector<u8> adata(64, 0x42);
  auto add_vok = [&](const std::string &name, std::vector<u8> code) {
    TestCase tc; tc.name = name; tc.category = cat;
    tc.code = std::move(code);
    tc.initial = {.rdi = DATA_ADDR + 1, .rflags = 0x2};
    tc.xmm_mask = 0x1; tc.init_data = adata;
    tests.push_back(std::move(tc));
  };

  for (const auto &op : ops) {
    u8 opcodes[] = {op.opc_132, op.opc_213, op.opc_231};

    for (const auto &ord : orderings) {
      u8 opc = opcodes[ord.opc_offset];

      // PS variant
      {
        std::string name = std::string(op.name) + ord.suffix + "PS";
        Evex e;
        e.mm = 2; e.pp = 1; e.W = false; e.opcode = opc;
        e.reg = 0; e.vvvv = 1; e.rm = 2;
        add_evex_rr_tests(tests, cat, name.c_str(), e, sps, 0x7, 0x5555);
        // VEX misaligned — no alignment required
        Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = opc;
        v.reg = 0; v.vvvv = 1; v.L = false;
        add_vok(name + " xmm,[rdi] misaligned", v.encode_rm_mem());
      }

      // PD variant
      {
        std::string name = std::string(op.name) + ord.suffix + "PD";
        Evex e;
        e.mm = 2; e.pp = 1; e.W = true; e.opcode = opc;
        e.reg = 0; e.vvvv = 1; e.rm = 2;
        add_evex_rr_tests(tests, cat, name.c_str(), e, spd, 0x7, 0x55);
        Vex v; v.mm = 2; v.pp = 1; v.W = true; v.opcode = opc;
        v.reg = 0; v.vvvv = 1; v.L = false;
        add_vok(name + " xmm,[rdi] misaligned", v.encode_rm_mem());
      }
    }
  }

  // Scalar FMA variants: SS (W=0) and SD (W=1)
  // Same opcodes as packed, but with NP/F3 prefix for SS and 66 for SD
  // Actually scalar FMA uses the same 66 prefix — scalar vs packed is
  // determined by the LIG (length-ignored) encoding and only operates
  // on the lowest element.
  // Scalar SS: EVEX.LIG.66.0F38.W0 opcode /r
  // Scalar SD: EVEX.LIG.66.0F38.W1 opcode /r
  // The opcodes are +1 from packed: e.g. VFMADD132SS = 0x99, VFMADD213SS = 0xA9

  ArchState sss;
  sss.rflags = 0x2;
  float ss0 = 1.5f, ss1 = 2.5f, ss2 = 100.0f;
  memcpy(&sss.xmm[0].q[0], &ss0, 4);
  sss.xmm[0].q[1] = 0xDEADDEADDEADDEAD;  // upper sentinel
  memcpy(&sss.xmm[1].q[0], &ss1, 4);
  sss.xmm[1].q[1] = 0xCAFECAFECAFECAFE;
  memcpy(&sss.xmm[2].q[0], &ss2, 4);
  sss.xmm[2].q[1] = 0xBEEFBEEFBEEFBEEF;

  ArchState ssd;
  ssd.rflags = 0x2;
  double sd0 = 1.5, sd1 = 2.5, sd2 = 100.0;
  memcpy(&ssd.xmm[0].q[0], &sd0, 8);
  ssd.xmm[0].q[1] = 0xDEADDEADDEADDEAD;
  memcpy(&ssd.xmm[1].q[0], &sd1, 8);
  ssd.xmm[1].q[1] = 0xCAFECAFECAFECAFE;
  memcpy(&ssd.xmm[2].q[0], &sd2, 8);
  ssd.xmm[2].q[1] = 0xBEEFBEEFBEEFBEEF;

  // Only test VFMADD/VFMSUB/VFNMADD/VFNMSUB scalar (no ADDSUB scalar)
  for (int i = 0; i < 4; i++) {  // first 4 ops only
    const auto &op = ops[i];
    u8 opcodes[] = {(u8)(op.opc_132 + 1), (u8)(op.opc_213 + 1), (u8)(op.opc_231 + 1)};

    for (const auto &ord : orderings) {
      u8 opc = opcodes[ord.opc_offset];

      // SS
      {
        std::string name = std::string(op.name) + ord.suffix + "SS";
        Evex e;
        e.mm = 2; e.pp = 1; e.W = false; e.opcode = opc;
        e.reg = 0; e.vvvv = 1; e.rm = 2;
        // Scalar: only test VL128 (LIG), no mask and with mask
        e.LL = 0; e.aaa = 0; e.z = false;
        tests.push_back({name + " xmm", cat, e.encode_rr(), sss, FL_NONE, 0x7, false});
        e.aaa = 1; e.z = true;
        tests.push_back({name + " xmm {k1}{z}", cat,
                         concat(set_kmask(1), e.encode_rr()), sss, FL_NONE, 0x7, false});
        Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = opc;
        v.reg = 0; v.vvvv = 1; v.L = false;
        add_vok(name + " xmm,[rdi] misaligned", v.encode_rm_mem());
      }

      // SD
      {
        std::string name = std::string(op.name) + ord.suffix + "SD";
        Evex e;
        e.mm = 2; e.pp = 1; e.W = true; e.opcode = opc;
        e.reg = 0; e.vvvv = 1; e.rm = 2;
        e.LL = 0; e.aaa = 0; e.z = false;
        tests.push_back({name + " xmm", cat, e.encode_rr(), ssd, FL_NONE, 0x7, false});
        e.aaa = 1; e.z = true;
        tests.push_back({name + " xmm {k1}{z}", cat,
                         concat(set_kmask(1), e.encode_rr()), ssd, FL_NONE, 0x7, false});
        Vex v; v.mm = 2; v.pp = 1; v.W = true; v.opcode = opc;
        v.reg = 0; v.vvvv = 1; v.L = false;
        add_vok(name + " xmm,[rdi] misaligned", v.encode_rm_mem());
      }
    }
  }
}

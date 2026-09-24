#include "kvm-avx-encoder.h"
#include <cpuid.h>

void add_avx_special_tests(std::vector<TestCase> &tests) {
  std::string cat = "AVX special";

  // =====================================================================
  // VPTERNLOGD/Q: ternary logic with immediate truth table
  // EVEX.66.0F3A.W0 25 /r ib (VPTERNLOGD)
  // EVEX.66.0F3A.W1 25 /r ib (VPTERNLOGQ)
  // dst = ternop(dst, src1, src2, imm8) per element
  // =====================================================================
  {
    ArchState s = {};
    for (int i = 0; i < 16; i++) s.xmm[0].set<u32>(i, 0xFF00FF00);
    for (int i = 0; i < 16; i++) s.xmm[1].set<u32>(i, 0x0F0F0F0F);
    for (int i = 0; i < 16; i++) s.xmm[2].set<u32>(i, 0x33333333);

    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x25;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    // imm8 = 0xFE: A | B | C
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VPTERNLOGD ") + vl[ll] + " OR",
                       cat, e.encode_rr_imm(0xFE), s, FL_ALL, 0x7, false});
      // imm8 = 0x80: A & B & C
      tests.push_back({std::string("VPTERNLOGD ") + vl[ll] + " AND",
                       cat, e.encode_rr_imm(0x80), s, FL_ALL, 0x7, false});
      // imm8 = 0x96: A ^ B ^ C
      tests.push_back({std::string("VPTERNLOGD ") + vl[ll] + " XOR3",
                       cat, e.encode_rr_imm(0x96), s, FL_ALL, 0x7, false});
      // With mask
      e.aaa = 1; e.z = true;
      tests.push_back({std::string("VPTERNLOGD ") + vl[ll] + " OR {k1}{z}",
                       cat, concat(set_kmask(0xAAAA), e.encode_rr_imm(0xFE)), s, FL_ALL, 0x7, false});
    }
  }
  {
    ArchState s = {};
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xFF00FF00FF00FF00ULL;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x0F0F0F0F0F0F0F0FULL;
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = 0x3333333333333333ULL;

    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.opcode = 0x25;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VPTERNLOGQ ") + vl[ll] + " XOR3",
                       cat, e.encode_rr_imm(0x96), s, FL_ALL, 0x7, false});
    }
  }

  // =====================================================================
  // VNNI: VPDPBUSD/VPDPBUSDS/VPDPWSSD/VPDPWSSDS
  // EVEX.66.0F38 W0:
  //   VPDPBUSD:  50    VPDPBUSDS: 51
  //   VPDPWSSD:  52    VPDPWSSDS: 53
  // =====================================================================
  {
    ArchState s = {};
    // dst (accumulator)
    for (int i = 0; i < 16; i++) s.xmm[0].set<u32>(i, 100);
    // src1 (unsigned bytes for BUSD, signed words for WSSD)
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = 2;
    // src2 (signed bytes for BUSD, signed words for WSSD)
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = 3;

    struct { const char *name; u8 opcode; } vnni[] = {
      {"VPDPBUSD",  0x50}, {"VPDPBUSDS", 0x51},
      {"VPDPWSSD",  0x52}, {"VPDPWSSDS", 0x53},
    };
    for (const auto &v : vnni) {
      Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = v.opcode;
      e.reg = 0; e.vvvv = 1; e.rm = 2;
      add_evex_rr_tests(tests, cat, v.name, e, s, 0x7, 0xAAAA);
    }
  }

  // =====================================================================
  // BF16: VDPBF16PS, VCVTNEPS2BF16, VCVTNE2PS2BF16
  // VDPBF16PS:    EVEX.F3.0F38.W0 52 /r  (BF16 dot product → f32)
  // VCVTNEPS2BF16: EVEX.F3.0F38.W0 72 /r  (f32 → BF16, narrowing)
  // VCVTNE2PS2BF16: EVEX.F2.0F38.W0 72 /r (2×f32 → BF16 per lane)
  // =====================================================================
  {
    ArchState s = {};
    for (int i = 0; i < 16; i++) s.xmm[0].set<u32>(i, 0);  // accumulator
    float ones = 1.0f;
    u32 ones_u; memcpy(&ones_u, &ones, 4);
    // BF16 value 1.0 = 0x3F80 (upper 16 bits of float 1.0)
    for (int i = 0; i < 32; i++) s.xmm[1].set<u16>(i, 0x3F80);
    for (int i = 0; i < 32; i++) s.xmm[2].set<u16>(i, 0x3F80);

    Evex e; e.mm = 2; e.pp = 2; e.W = false; e.opcode = 0x52;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VDPBF16PS", e, s, 0x7, 0xAAAA);
  }
  {
    ArchState s = {};
    float vals[] = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f,
                    9.0f, 10.0f, 11.0f, 12.0f, 13.0f, 14.0f, 15.0f, 16.0f};
    memcpy(s.xmm[1].q, vals, 64);

    // VCVTNEPS2BF16: narrowing, per VL
    Evex e; e.mm = 2; e.pp = 2; e.W = false; e.opcode = 0x72;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VCVTNEPS2BF16 ") + vl[ll],
                       cat, e.encode_rr(), s, FL_ALL, 0x3, false});
    }
  }
  {
    ArchState s = {};
    float v1[] = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f,
                  9.0f, 10.0f, 11.0f, 12.0f, 13.0f, 14.0f, 15.0f, 16.0f};
    float v2[] = {10.0f, 20.0f, 30.0f, 40.0f, 50.0f, 60.0f, 70.0f, 80.0f,
                  90.0f, 100.0f, 110.0f, 120.0f, 130.0f, 140.0f, 150.0f, 160.0f};
    memcpy(s.xmm[1].q, v1, 64);
    memcpy(s.xmm[2].q, v2, 64);

    Evex e; e.mm = 2; e.pp = 3; e.W = false; e.opcode = 0x72;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VCVTNE2PS2BF16", e, s, 0x6, 0x55555555);
  }

  // =====================================================================
  // VAES: VAESENC/VAESENCLAST/VAESDEC/VAESDECLAST
  // EVEX.66.0F38.WIG DC/DD/DE/DF /r (VAES + AVX512VL/F)
  // One AES round per 128-bit lane; no opmask, so only unmasked forms.
  // Only run where the host has VAES (CPUID.7.0:ECX[9]).
  // =====================================================================
  {
    u32 eax7, ebx7, ecx7, edx7;
    __cpuid_count(7, 0, eax7, ebx7, ecx7, edx7);
    if (ecx7 & (1u << 9)) {
      ArchState s = {};
      for (int i = 0; i < 8; i++) {
        s.xmm[1].q[i] = 0x0123456789ABCDEFULL * (2 * i + 1);
        s.xmm[2].q[i] = 0x0F0E0D0C0B0A0908ULL + 0x1010101010101010ULL * i;
      }
      struct { const char *name; u8 opcode; } aes[] = {
        {"VAESENC",     0xDC}, {"VAESENCLAST", 0xDD},
        {"VAESDEC",     0xDE}, {"VAESDECLAST", 0xDF},
      };
      for (const auto &a : aes) {
        Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = a.opcode;
        e.reg = 0; e.vvvv = 1; e.rm = 2;
        add_evex_rr_tests(tests, cat, a.name, e, s, 0x6, 0);
      }
    }
  }

  // =====================================================================
  // VPCONFLICTD/Q: detect conflicts (duplicate indices) in each element
  // EVEX.66.0F38.W0 C4 /r (VPCONFLICTD)
  // EVEX.66.0F38.W1 C4 /r (VPCONFLICTQ)
  // =====================================================================
  {
    ArchState s = {};
    // Put some duplicate values to create conflicts
    u32 dvals[] = {1, 2, 1, 3, 2, 1, 4, 5, 1, 2, 3, 4, 5, 6, 7, 8};
    memcpy(s.xmm[1].q, dvals, 64);

    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0xC4;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VPCONFLICTD", e, s, 0x2, 0xAAAA);
  }
  {
    ArchState s = {};
    u64 qvals[] = {10, 20, 10, 30, 20, 10, 40, 50};
    memcpy(s.xmm[1].q, qvals, 64);

    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0xC4;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VPCONFLICTQ", e, s, 0x2, 0x55);
  }

  // =====================================================================
  // VPMADD52LUQ/HUQ: multiply-add unsigned 52-bit integers
  // EVEX.66.0F38.W1 B4 /r (VPMADD52LUQ)
  // EVEX.66.0F38.W1 B5 /r (VPMADD52HUQ)
  // =====================================================================
  {
    ArchState s = {};
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 100;  // accumulator
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x1000 * (i + 1);
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = 0x2000 * (i + 1);

    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.opcode = 0xB4;
    add_evex_rr_tests(tests, cat, "VPMADD52LUQ", e, s, 0x7, 0x55);
    e.opcode = 0xB5;
    add_evex_rr_tests(tests, cat, "VPMADD52HUQ", e, s, 0x7, 0x55);
  }

  // =====================================================================
  // GF2P8: Galois Field operations
  // VGF2P8MULB:       EVEX.66.0F38.W0 CF /r
  // VGF2P8AFFINEQB:   EVEX.66.0F3A.W1 CE /r ib
  // VGF2P8AFFINEINVQB: EVEX.66.0F3A.W1 CF /r ib
  // =====================================================================
  {
    ArchState s = {};
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = i + 1;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = 0x53;

    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0xCF;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VGF2P8MULB", e, s, 0x6, 0xAAAAAAAA);
  }
  {
    ArchState s = {};
    // Matrix in qword-granularity per lane
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x0102030405060708ULL;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = i + 1;

    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.opcode = 0xCE;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VGF2P8AFFINEQB ") + vl[ll],
                       cat, e.encode_rr_imm(0x00), s, FL_ALL, 0x7, false});
    }
    e.opcode = 0xCF;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VGF2P8AFFINEINVQB ") + vl[ll],
                       cat, e.encode_rr_imm(0x00), s, FL_ALL, 0x7, false});
    }
  }

  // =====================================================================
  // VPMULTISHIFTQB: multishift bytes from qword
  // EVEX.66.0F38.W1 83 /r
  // =====================================================================
  {
    ArchState s = {};
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x0706050403020100ULL + i * 8;
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = 0xFEDCBA9876543210ULL;

    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x83;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VPMULTISHIFTQB", e, s, 0x6, 0xAAAAAAAA);
  }

  // =====================================================================
  // VDBPSADBW: double block packed sum of absolute differences
  // EVEX.66.0F3A.W0 42 /r ib
  // =====================================================================
  {
    ArchState s = {};
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = i;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = 64 + i;

    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x42;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VDBPSADBW ") + vl[ll],
                       cat, e.encode_rr_imm(0), s, FL_ALL, 0x7, false});
    }
  }

  // =====================================================================
  // VPSHLDW/D/Q: concatenate and shift left (with immediate)
  // EVEX.66.0F3A.W1 70 /r ib (VPSHLDW)
  // EVEX.66.0F3A.W0 71 /r ib (VPSHLDD)
  // EVEX.66.0F3A.W1 71 /r ib (VPSHLDQ)
  // VPSHRDW/D/Q: concatenate and shift right
  // EVEX.66.0F3A.W1 72 /r ib (VPSHRDW)
  // EVEX.66.0F3A.W0 73 /r ib (VPSHRDD)
  // EVEX.66.0F3A.W1 73 /r ib (VPSHRDQ)
  // =====================================================================
  {
    ArchState s = {};
    for (int i = 0; i < 32; i++) s.xmm[1].set<u16>(i, 0x1234);
    for (int i = 0; i < 32; i++) s.xmm[2].set<u16>(i, 0x5678);

    Evex e; e.mm = 3; e.pp = 1; e.reg = 0; e.vvvv = 1; e.rm = 2;

    struct { const char *name; u8 opcode; bool W; } shld_shrd[] = {
      {"VPSHLDW", 0x70, true},  {"VPSHRDW", 0x72, true},
      {"VPSHLDD", 0x71, false}, {"VPSHRDD", 0x73, false},
      {"VPSHLDQ", 0x71, true},  {"VPSHRDQ", 0x73, true},
    };
    for (const auto &ss : shld_shrd) {
      e.W = ss.W; e.opcode = ss.opcode;
      for (int ll = 0; ll <= 2; ll++) {
        const char *vl[] = {"xmm", "ymm", "zmm"};
        e.LL = ll; e.aaa = 0; e.z = false;
        tests.push_back({std::string(ss.name) + " " + vl[ll],
                         cat, e.encode_rr_imm(4), s, FL_ALL, 0x7, false});
      }
    }
  }

  // =====================================================================
  // VPSHLDVW/D/Q: variable concatenate-shift-left
  // EVEX.66.0F38.W1 70 /r (VPSHLDVW)
  // EVEX.66.0F38.W0 71 /r (VPSHLDVD)
  // EVEX.66.0F38.W1 71 /r (VPSHLDVQ)
  // VPSHRDVW/D/Q: variable concatenate-shift-right
  // EVEX.66.0F38.W1 72 /r (VPSHRDVW)
  // EVEX.66.0F38.W0 73 /r (VPSHRDVD)
  // EVEX.66.0F38.W1 73 /r (VPSHRDVQ)
  // =====================================================================
  {
    ArchState s = {};
    for (int i = 0; i < 32; i++) s.xmm[0].set<u16>(i, 0x1234);
    for (int i = 0; i < 32; i++) s.xmm[1].set<u16>(i, 0x5678);
    for (int i = 0; i < 32; i++) s.xmm[2].set<u16>(i, 4);

    Evex e; e.mm = 2; e.pp = 1; e.reg = 0; e.vvvv = 1; e.rm = 2;

    struct { const char *name; u8 opcode; bool W; } shldv[] = {
      {"VPSHLDVW", 0x70, true},  {"VPSHRDVW", 0x72, true},
      {"VPSHLDVD", 0x71, false}, {"VPSHRDVD", 0x73, false},
      {"VPSHLDVQ", 0x71, true},  {"VPSHRDVQ", 0x73, true},
    };
    for (const auto &ss : shldv) {
      e.W = ss.W; e.opcode = ss.opcode;
      add_evex_rr_tests(tests, cat, ss.name, e, s, 0x7, 0x55555555);
    }
  }

  // =====================================================================
  // VCOMPRESSPD/PS: compress packed elements using writemask
  // EVEX.66.0F38.W1 8A /r (VCOMPRESSPD)
  // EVEX.66.0F38.W0 8A /r (VCOMPRESSPS)
  // VPCOMPRESSD: EVEX.66.0F38.W0 8B /r
  // VPCOMPRESSQ: EVEX.66.0F38.W1 8B /r
  // VPCOMPRESSB: EVEX.66.0F38.W0 63 /r
  // VPCOMPRESSW: EVEX.66.0F38.W1 63 /r
  // =====================================================================
  {
    ArchState s = {};
    for (int i = 0; i < 16; i++) s.xmm[1].set<u32>(i, 0x100 * (i + 1));

    struct { const char *name; u8 opcode; bool W; u32 kmask; } compress[] = {
      {"VCOMPRESSPS",  0x8A, false, 0xAAAA},
      {"VCOMPRESSPD",  0x8A, true,  0x55},
      {"VPCOMPRESSD",  0x8B, false, 0xAAAA},
      {"VPCOMPRESSQ",  0x8B, true,  0x55},
      {"VPCOMPRESSB",  0x63, false, 0xAAAAAAAA},
      {"VPCOMPRESSW",  0x63, true,  0x55555555},
    };
    for (const auto &c : compress) {
      Evex e; e.mm = 2; e.pp = 1; e.W = c.W; e.opcode = c.opcode;
      e.reg = 1; e.vvvv = 0; e.rm = 0;  // src=reg(xmm1), dst=rm(xmm0)
      add_evex_rr_tests(tests, cat, c.name, e, s, 0x2, c.kmask);
    }
  }

  // =====================================================================
  // VEXPANDPD/PS: expand packed elements using writemask
  // EVEX.66.0F38.W1 88 /r (VEXPANDPD)
  // EVEX.66.0F38.W0 88 /r (VEXPANDPS)
  // VPEXPANDD: EVEX.66.0F38.W0 89 /r
  // VPEXPANDQ: EVEX.66.0F38.W1 89 /r
  // VPEXPANDB: EVEX.66.0F38.W0 62 /r
  // VPEXPANDW: EVEX.66.0F38.W1 62 /r
  // =====================================================================
  {
    ArchState s = {};
    for (int i = 0; i < 16; i++) s.xmm[1].set<u32>(i, 0x100 * (i + 1));

    struct { const char *name; u8 opcode; bool W; u32 kmask; } expand[] = {
      {"VEXPANDPS",  0x88, false, 0xAAAA},
      {"VEXPANDPD",  0x88, true,  0x55},
      {"VPEXPANDD",  0x89, false, 0xAAAA},
      {"VPEXPANDQ",  0x89, true,  0x55},
      {"VPEXPANDB",  0x62, false, 0xAAAAAAAA},
      {"VPEXPANDW",  0x62, true,  0x55555555},
    };
    for (const auto &x : expand) {
      Evex e; e.mm = 2; e.pp = 1; e.W = x.W; e.opcode = x.opcode;
      e.reg = 0; e.vvvv = 0; e.rm = 1;
      add_evex_rr_tests(tests, cat, x.name, e, s, 0x2, x.kmask);
    }
  }

  // =====================================================================
  // VCMPPS/PD: packed FP compare with immediate predicate → k-register
  // EVEX.NP.0F.W0 C2 /r ib (VCMPPS)
  // EVEX.66.0F.W1 C2 /r ib (VCMPPD)
  // =====================================================================
  {
    static const std::vector<u8> kmovq_k0_rax = {0xC4, 0xE1, 0xFB, 0x93, 0xC0};

    ArchState s = {};
    float ps1[] = {1.0f, 5.0f, 3.0f, 5.0f, 5.0f, 2.0f, 7.0f, 5.0f,
                   1.0f, 5.0f, 3.0f, 5.0f, 5.0f, 2.0f, 7.0f, 5.0f};
    float ps2[] = {5.0f, 5.0f, 5.0f, 5.0f, 5.0f, 5.0f, 5.0f, 5.0f,
                   5.0f, 5.0f, 5.0f, 5.0f, 5.0f, 5.0f, 5.0f, 5.0f};
    memcpy(s.xmm[1].q, ps1, 64);
    memcpy(s.xmm[2].q, ps2, 64);

    Evex e; e.mm = 1; e.pp = 0; e.W = false; e.opcode = 0xC2;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      // imm=0: EQ
      auto code = e.encode_rr_imm(0);
      code.insert(code.end(), kmovq_k0_rax.begin(), kmovq_k0_rax.end());
      tests.push_back({std::string("VCMPPS EQ ") + vl[ll], cat, code, s, FL_ALL, 0, false});
      // imm=1: LT
      code = e.encode_rr_imm(1);
      code.insert(code.end(), kmovq_k0_rax.begin(), kmovq_k0_rax.end());
      tests.push_back({std::string("VCMPPS LT ") + vl[ll], cat, code, s, FL_ALL, 0, false});
    }
  }
  {
    static const std::vector<u8> kmovq_k0_rax = {0xC4, 0xE1, 0xFB, 0x93, 0xC0};

    ArchState s = {};
    double pd1[] = {1.0, 5.0, 3.0, 5.0, 5.0, 2.0, 7.0, 5.0};
    double pd2[] = {5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0};
    memcpy(s.xmm[1].q, pd1, 64);
    memcpy(s.xmm[2].q, pd2, 64);

    Evex e; e.mm = 1; e.pp = 1; e.W = true; e.opcode = 0xC2;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      auto code = e.encode_rr_imm(0);
      code.insert(code.end(), kmovq_k0_rax.begin(), kmovq_k0_rax.end());
      tests.push_back({std::string("VCMPPD EQ ") + vl[ll], cat, code, s, FL_ALL, 0, false});
      code = e.encode_rr_imm(1);
      code.insert(code.end(), kmovq_k0_rax.begin(), kmovq_k0_rax.end());
      tests.push_back({std::string("VCMPPD LT ") + vl[ll], cat, code, s, FL_ALL, 0, false});
    }
  }

  // =====================================================================
  // VGETEXPPS/PD: extract FP exponents
  // EVEX.66.0F38.W0 42 /r (VGETEXPPS)
  // EVEX.66.0F38.W1 42 /r (VGETEXPPD)
  // VSCALEFPS/PD: scale FP by integer exponents
  // EVEX.66.0F38.W0 2C /r (VSCALEFPS)
  // EVEX.66.0F38.W1 2C /r (VSCALEFPD)
  // =====================================================================
  {
    ArchState s = {};
    float vals[] = {1.0f, 2.0f, 4.0f, 8.0f, 0.5f, 0.25f, 16.0f, 64.0f,
                    1.0f, 2.0f, 4.0f, 8.0f, 0.5f, 0.25f, 16.0f, 64.0f};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x42;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VGETEXPPS", e, s, 0x2, 0xAAAA);
  }
  {
    ArchState s = {};
    double vals[] = {1.0, 2.0, 4.0, 8.0, 0.5, 0.25, 16.0, 64.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x42;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VGETEXPPD", e, s, 0x2, 0x55);
  }
  {
    ArchState s = {};
    float vals[] = {1.0f, 2.0f, 0.5f, 4.0f, 1.0f, 2.0f, 0.5f, 4.0f,
                    1.0f, 2.0f, 0.5f, 4.0f, 1.0f, 2.0f, 0.5f, 4.0f};
    float exps[] = {2.0f, 3.0f, -1.0f, 0.0f, 2.0f, 3.0f, -1.0f, 0.0f,
                    2.0f, 3.0f, -1.0f, 0.0f, 2.0f, 3.0f, -1.0f, 0.0f};
    memcpy(s.xmm[1].q, vals, 64);
    memcpy(s.xmm[2].q, exps, 64);

    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x2C;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VSCALEFPS", e, s, 0x6, 0xAAAA);
  }
  {
    ArchState s = {};
    double vals[] = {1.0, 2.0, 0.5, 4.0, 1.0, 2.0, 0.5, 4.0};
    double exps[] = {2.0, 3.0, -1.0, 0.0, 2.0, 3.0, -1.0, 0.0};
    memcpy(s.xmm[1].q, vals, 64);
    memcpy(s.xmm[2].q, exps, 64);

    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x2C;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VSCALEFPD", e, s, 0x6, 0x55);
  }

  // =====================================================================
  // VRCP14PS/PD: approximate reciprocal
  // EVEX.66.0F38.W0 4C /r (VRCP14PS)
  // EVEX.66.0F38.W1 4C /r (VRCP14PD)
  // VRSQRT14PS/PD: approximate reciprocal square root
  // EVEX.66.0F38.W0 4E /r (VRSQRT14PS)
  // EVEX.66.0F38.W1 4E /r (VRSQRT14PD)
  // =====================================================================
  {
    ArchState s = {};
    float vals[] = {1.0f, 2.0f, 4.0f, 8.0f, 0.5f, 0.25f, 16.0f, 64.0f,
                    1.0f, 2.0f, 4.0f, 8.0f, 0.5f, 0.25f, 16.0f, 64.0f};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 2; e.pp = 1; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.W = false; e.opcode = 0x4C;
    add_evex_rr_tests(tests, cat, "VRCP14PS", e, s, 0x2, 0xAAAA);
    e.W = false; e.opcode = 0x4E;
    add_evex_rr_approx_tests(tests, cat, "VRSQRT14PS", e, s, 0x2, 32);
  }
  // VRCP14PD/VRSQRT14PD need f64 source data
  {
    ArchState s = {};
    double vals[] = {1.0, 2.0, 4.0, 8.0, 0.5, 0.25, 16.0, 64.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 2; e.pp = 1; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.W = true; e.opcode = 0x4C;
    add_evex_rr_approx_tests(tests, cat, "VRCP14PD", e, s, 0x2, 64);
    e.W = true; e.opcode = 0x4E;
    add_evex_rr_approx_tests(tests, cat, "VRSQRT14PD", e, s, 0x2, 64);
  }

  // VRNDSCALEPS: EVEX.66.0F3A.W0 08 /r ib
  // VRNDSCALEPD: EVEX.66.0F3A.W1 09 /r ib
  {
    ArchState s = {};
    float vals[] = {1.3f, 2.7f, -1.5f, 3.9f, -0.1f, 4.5f, -2.2f, 8.8f,
                    1.3f, 2.7f, -1.5f, 3.9f, -0.1f, 4.5f, -2.2f, 8.8f};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x08;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VRNDSCALEPS ") + vl[ll],
                       cat, e.encode_rr_imm(0x00), s, FL_ALL, 0x3, false});
    }
  }
  {
    ArchState s = {};
    double vals[] = {1.3, 2.7, -1.5, 3.9, -0.1, 4.5, -2.2, 8.8};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.opcode = 0x09;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VRNDSCALEPD ") + vl[ll],
                       cat, e.encode_rr_imm(0x00), s, FL_ALL, 0x3, false});
    }
  }

  // VREDUCEPS: EVEX.66.0F3A.W0 56 /r ib
  // VREDUCEPD: EVEX.66.0F3A.W1 56 /r ib
  {
    ArchState s = {};
    float vals[] = {3.14f, 6.28f, -1.5f, 100.9f, 0.5f, -255.1f, 0.0f, -1.0f,
                    3.14f, 6.28f, -1.5f, 100.9f, 0.5f, -255.1f, 0.0f, -1.0f};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x56;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VREDUCEPS ") + vl[ll],
                       cat, e.encode_rr_imm(0x08), s, FL_ALL, 0x3, false});
    }
  }
  {
    ArchState s = {};
    double vals[] = {3.14, 6.28, -1.5, 100.9, 0.5, -255.1, 0.0, -1.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.opcode = 0x56;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VREDUCEPD ") + vl[ll],
                       cat, e.encode_rr_imm(0x08), s, FL_ALL, 0x3, false});
    }
  }

  // VRANGEPS: EVEX.66.0F3A.W0 50 /r ib
  // VRANGEPD: EVEX.66.0F3A.W1 50 /r ib
  {
    ArchState s = {};
    float v1[] = {1.0f, 5.0f, -3.0f, 10.0f, 1.0f, 5.0f, -3.0f, 10.0f,
                  1.0f, 5.0f, -3.0f, 10.0f, 1.0f, 5.0f, -3.0f, 10.0f};
    float v2[] = {3.0f, 2.0f, -1.0f, 7.0f, 3.0f, 2.0f, -1.0f, 7.0f,
                  3.0f, 2.0f, -1.0f, 7.0f, 3.0f, 2.0f, -1.0f, 7.0f};
    memcpy(s.xmm[1].q, v1, 64);
    memcpy(s.xmm[2].q, v2, 64);

    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x50;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VRANGEPS ") + vl[ll],
                       cat, e.encode_rr_imm(0), s, FL_ALL, 0x7, false});
    }
  }
  {
    ArchState s = {};
    double v1[] = {1.0, 5.0, -3.0, 10.0, 1.0, 5.0, -3.0, 10.0};
    double v2[] = {3.0, 2.0, -1.0, 7.0, 3.0, 2.0, -1.0, 7.0};
    memcpy(s.xmm[1].q, v1, 64);
    memcpy(s.xmm[2].q, v2, 64);

    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.opcode = 0x50;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VRANGEPD ") + vl[ll],
                       cat, e.encode_rr_imm(0), s, FL_ALL, 0x7, false});
    }
  }

  // VGETMANTPS: EVEX.66.0F3A.W0 26 /r ib
  // VGETMANTPD: EVEX.66.0F3A.W1 26 /r ib
  {
    ArchState s = {};
    float vals[] = {1.5f, 2.5f, 4.0f, 8.0f, 0.5f, 0.25f, 16.0f, 64.0f,
                    1.5f, 2.5f, 4.0f, 8.0f, 0.5f, 0.25f, 16.0f, 64.0f};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x26;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VGETMANTPS ") + vl[ll],
                       cat, e.encode_rr_imm(0), s, FL_ALL, 0x3, false});
    }
  }
  {
    ArchState s = {};
    double vals[] = {1.5, 2.5, 4.0, 8.0, 0.5, 0.25, 16.0, 64.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.opcode = 0x26;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VGETMANTPD ") + vl[ll],
                       cat, e.encode_rr_imm(0), s, FL_ALL, 0x3, false});
    }
  }

  // =====================================================================
  // VPCLMULQDQ: EVEX.66.0F3A.WIG 44 /r ib (VPCLMULQDQ + AVX512VL/F)
  // Carry-less multiply of one quadword per 128-bit lane; imm8[0] and
  // imm8[4] select the quadwords.  No opmask, so only unmasked forms.
  // Only run where the host has the VPCLMULQDQ extension (CPUID.7.0:ECX[10]).
  // =====================================================================
  {
    u32 eax7, ebx7, ecx7, edx7;
    __cpuid_count(7, 0, eax7, ebx7, ecx7, edx7);
    if (ecx7 & (1u << 10)) {
      ArchState s = {};
      for (int i = 0; i < 8; i++) {
        s.xmm[1].q[i] = 0x0123456789ABCDEFULL * (2 * i + 1);
        s.xmm[2].q[i] = 0x8000000000000001ULL >> i;
      }
      Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x44;
      e.reg = 0; e.vvvv = 1; e.rm = 2;
      const char *vl[] = {"xmm", "ymm", "zmm"};
      for (int ll = 0; ll <= 2; ll++) {
        e.LL = ll; e.aaa = 0; e.z = false;
        tests.push_back({std::string("VPCLMULQDQ ") + vl[ll] + " imm=0x00",
                         cat, e.encode_rr_imm(0x00), s, FL_ALL, 0x7, false});
        tests.push_back({std::string("VPCLMULQDQ ") + vl[ll] + " imm=0x01",
                         cat, e.encode_rr_imm(0x01), s, FL_ALL, 0x7, false});
        tests.push_back({std::string("VPCLMULQDQ ") + vl[ll] + " imm=0x10",
                         cat, e.encode_rr_imm(0x10), s, FL_ALL, 0x7, false});
        tests.push_back({std::string("VPCLMULQDQ ") + vl[ll] + " imm=0x11",
                         cat, e.encode_rr_imm(0x11), s, FL_ALL, 0x7, false});
      }
    }
  }

  // =====================================================================
  // VBROADCASTI32X2: EVEX.66.0F38.W0 59 /r (xmm/ymm/zmm) and
  // VBROADCASTF32X2: EVEX.66.0F38.W0 19 /r (ymm/zmm only) [AVX512DQ]
  // Broadcast the low dword pair of xmm/m64; writemask per dword.
  // =====================================================================
  {
    ArchState s = {};
    s.xmm[1] = xmm_from_u64(0x2222222211111111, 0x4444444433333333);
    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.opcode = 0x59;
    add_evex_rr_tests(tests, cat, "VBROADCASTI32X2", e, s, 0x2, 0xAAAA);
    e.opcode = 0x19;
    const char *vl[] = {"xmm", "ymm", "zmm"};
    for (int ll = 1; ll <= 2; ll++) {
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VBROADCASTF32X2 ") + vl[ll], cat, e.encode_rr(), s, FL_ALL, 0x3, false});
      e.aaa = 1; e.z = true;
      tests.push_back({std::string("VBROADCASTF32X2 ") + vl[ll] + " {k1}{z}", cat,
                       concat(set_kmask(0x5555), e.encode_rr()), s, FL_ALL, 0x3, false});
    }
  }

  // =====================================================================
  // VP2INTERSECTD/Q: EVEX.F2.0F38.W0/W1 68 /r -> even/odd mask-register pair
  // Only where the host has AVX512_VP2INTERSECT (CPUID.7.0:EDX[8]); neither
  // current oracle host does, so these wait for one that does.
  // =====================================================================
  {
    u32 eax7, ebx7, ecx7, edx7;
    __cpuid_count(7, 0, eax7, ebx7, ecx7, edx7);
    if (edx7 & (1u << 8)) {
      ArchState s = {};
      for (int i = 0; i < 16; i++) {
        s.xmm[1].set<u32>(i, (i * 5) % 11);
        s.xmm[2].set<u32>(i, (i * 3 + 1) % 9);
      }
      const char *vl[] = {"xmm", "ymm", "zmm"};
      for (int w = 0; w <= 1; w++) {
        for (int ll = 0; ll <= 2; ll++) {
          Evex e; e.mm = 2; e.pp = 3; e.W = w; e.opcode = 0x68;
          e.reg = 3; e.vvvv = 1; e.rm = 2; e.LL = ll;  // k3 encodes the k2/k3 pair
          TestCase tc = {std::string(w ? "VP2INTERSECTQ " : "VP2INTERSECTD ") + vl[ll] + " -> k2/k3",
                         cat, e.encode_rr(), s, FL_ALL, 0x0, false};
          tc.kreg_mask = (1 << 2) | (1 << 3);
          tests.push_back(std::move(tc));
        }
      }
    }
  }

  // =====================================================================
  // VFIXUPIMMPS/PD v {k}{z}, v, v/m/bcst, imm8    EVEX.66.0F3A.W0/W1 54
  // VFPCLASSSS/SD k {k}, xmm/m32/m64, imm8         EVEX.66.0F3A.W0/W1 67
  // Scatters (EVEX.66.0F38 A0-A3) and gathers (90-93) with VSIB addressing
  // =====================================================================
  {
    const char *vl_name[] = {"xmm", "ymm", "zmm"};

    // VFIXUPIMM: the destination is also an input (response 0 keeps it), the
    // first source supplies the values to classify, and the second source is
    // the response table with one nibble per token type.  The lanes of src1
    // cover all eight token types; the table maps each type to a different
    // response, and a second table exercises the remaining responses.
    {
      ArchState s;
      float f32[16] = {0};
      double f64[8];
      u32 fq, fs;
      fq = 0x7FC00001; memcpy(&f32[0], &fq, 4);          // QNaN
      fs = 0x7F800001; memcpy(&f32[1], &fs, 4);          // SNaN
      f32[2] = 0.0f; f32[3] = 1.0f; f32[4] = -INFINITY; f32[5] = INFINITY;
      f32[6] = -3.5f; f32[7] = 2.25f; f32[8] = -0.0f; f32[9] = 100.0f;
      u32 fd = 0x00000001; memcpy(&f32[10], &fd, 4);     // denormal
      f32[11] = -1.0f; f32[12] = 1.0f; f32[13] = -1e30f; f32[14] = 0.5f; f32[15] = -0.0f;
      u64 dq = 0x7FF8000000000001ULL, ds = 0x7FF0000000000001ULL, dd = 1;
      memcpy(&f64[0], &dq, 8); memcpy(&f64[1], &ds, 8);
      f64[2] = 0.0; f64[3] = 1.0; f64[4] = -INFINITY; f64[5] = INFINITY; f64[6] = -3.5; f64[7] = 2.25;
      (void)dd;
      // token order: QNAN, SNAN, ZERO, POS_ONE, NEG_INF, POS_INF, NEG_VALUE, POS_VALUE
      // Response 2, QNaN(tsrc), is used only for NaN tokens: the SDM does
      // not define QNaN() of a non-NaN input.
      const u32 table_a = 0xFEDCBA98u;  // responses F..8 for tokens 7..0
      const u32 table_b = 0x76543102u;  // responses 7..3 for tokens 7..3, then 1, 0, 2
      const u32 table_c = 0x61D3C0A4u;  // a mixed table

      for (int w = 0; w <= 1; w++) {
        ArchState in = s;
        if (w) {
          memcpy(in.xmm[1].q, f64, 64);
          for (int i = 0; i < 8; i++) in.xmm[0].q[i] = 0x4000000000000000ULL + i;  // dst input: 2.0 + i ulp
        } else {
          memcpy(in.xmm[1].q, f32, 64);
          for (int i = 0; i < 16; i++) in.xmm[0].set<u32>(i, 0x40000000u + i);
        }
        Evex e; e.mm = 3; e.pp = 1; e.W = w; e.opcode = 0x54; e.reg = 0; e.vvvv = 1; e.rm = 2;
        for (u32 table : {table_a, table_b, table_c}) {
          ArchState t = in;
          if (w) for (int i = 0; i < 8; i++) t.xmm[2].q[i] = table;
          else for (int i = 0; i < 16; i++) t.xmm[2].set<u32>(i, table);
          t = with_vector_inputs(t, 0x7);
          for (int ll = 0; ll <= 2; ll++) {
            e.LL = ll;
            std::string name = std::format("{} {} table={:#x}", w ? "VFIXUPIMMPD" : "VFIXUPIMMPS", vl_name[ll], table);
            e.aaa = 0; e.z = false;
            tests.push_back({name, cat, e.encode_rr_imm(0), t, FL_ALL, 0, false});
            // imm8 bits only select which exceptions to signal; with all
            // SIMD exceptions masked they change MXCSR flags at most.
            tests.push_back({name + " imm=0xff", cat, e.encode_rr_imm(0xFF), t, FL_ALL, 0, false});
            ArchState km = t; km.kregs[1] = w ? 0x5A : 0xA5A5;
            e.aaa = 1; e.z = true;
            tests.push_back({name + " {k1}{z}", cat, e.encode_rr_imm(0), km, FL_ALL, 0, false});
            e.aaa = 1; e.z = false;
            tests.push_back({name + " {k1}", cat, e.encode_rr_imm(0), km, FL_ALL, 0, false});
          }
        }
        // table from memory, and broadcast from memory
        {
          std::vector<u8> mem(64);
          for (int i = 0; i < 64; i += 4) memcpy(&mem[i], &table_c, 4);
          ArchState t = with_vector_inputs(in, 0x3); t.rdi = DATA_ADDR;
          for (int ll = 0; ll <= 2; ll++) {
            e.LL = ll; e.aaa = 0; e.z = false;
            TestCase tc; tc.category = cat; tc.initial = t; tc.init_data = mem;
            tc.name = std::format("{} {} [rdi]", w ? "VFIXUPIMMPD" : "VFIXUPIMMPS", vl_name[ll]);
            tc.code = e.encode_rm_mem_imm(0);
            tests.push_back(std::move(tc));
            TestCase tb; tb.category = cat; tb.initial = t; tb.init_data = mem;
            tb.name = std::format("{} {} [rdi]{{1toN}}", w ? "VFIXUPIMMPD" : "VFIXUPIMMPS", vl_name[ll]);
            tb.code = e.encode_rm_bcast_imm(0);
            tests.push_back(std::move(tb));
          }
        }
      }
    }

    // VFPCLASSSS/SD: imm8 bit 0 qNaN, 1 +0, 2 -0, 3 +inf, 4 -inf, 5 denormal,
    // 6 finite negative, 7 sNaN.  Result bit 0 of k1, under the k2 mask.
    {
      u32 v32[] = {0x7FC00000, 0x7F800001, 0x00000000, 0x80000000, 0x7F800000, 0xFF800000,
                   0x00400000, 0x80000003, 0xC0200000, 0x40400000};
      u64 v64[] = {0x7FF8000000000000ULL, 0x7FF0000000000001ULL, 0, 0x8000000000000000ULL,
                   0x7FF0000000000000ULL, 0xFFF0000000000000ULL, 0x0008000000000000ULL,
                   0x8000000000000003ULL, 0xC004000000000000ULL, 0x4008000000000000ULL};
      const u8 imms[] = {0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x66, 0xFF};
      for (int w = 0; w <= 1; w++) {
        Evex e; e.mm = 3; e.pp = 1; e.W = w; e.opcode = 0x67; e.reg = 1; e.vvvv = 0; e.rm = 1; e.LL = 0;
        for (int vi = 0; vi < 10; vi++) {
          ArchState s;
          s.xmm[1].q[1] = 0xDEADDEADDEADDEADULL;  // upper qword must be ignored
          if (w) s.xmm[1].q[0] = v64[vi];
          else { s.xmm[1].q[0] = 0xDEADDEAD00000000ULL; s.xmm[1].set<u32>(0, v32[vi]); }
          for (u8 imm : imms) {
            std::string name = std::format("{} k1,xmm1,{:#x} value#{}", w ? "VFPCLASSSD" : "VFPCLASSSS", imm, vi);
            e.aaa = 0;
            tests.push_back({name, cat, e.encode_rr_imm(imm), with_vector_inputs(s, 0x2), FL_ALL, 0, false});
            if (imm == 0xFF) {
              ArchState km = with_vector_inputs(s, 0x2); km.kregs[2] = 0xFE;  // bit 0 clear: result masked to 0
              e.aaa = 2;
              tests.push_back({name + " {k2}", cat, e.encode_rr_imm(imm), km, FL_ALL, 0, false});
            }
          }
        }
        // memory operand
        e.aaa = 0;
        for (int vi : {0, 5, 6}) {
          std::vector<u8> mem(64, 0xCC);
          if (w) memcpy(mem.data(), &v64[vi], 8); else memcpy(mem.data(), &v32[vi], 4);
          TestCase tc; tc.category = cat;
          tc.name = std::format("{} k1,[rdi],0xff value#{}", w ? "VFPCLASSSD" : "VFPCLASSSS", vi);
          tc.code = e.encode_rm_mem_imm(0xFF);
          tc.initial = {.rdi = DATA_ADDR}; tc.init_data = mem;
          tests.push_back(std::move(tc));
        }
      }
    }

    // Scatters and gathers.  The index vector (zmm2) holds signed element
    // offsets; the base is the middle of the data page so negative indices
    // are exercised; one index is duplicated so the LSB-to-MSB write order
    // of the SDM shows.  The mask (k1) is required and is cleared by the
    // instruction; a partial mask leaves the unselected elements alone.
    {
      auto scatter_state = [&](bool qidx) {
        ArchState s;
        s.rdi = DATA_ADDR + 0x800;
        for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x1111111111111111ULL * (i + 1) + 0x0F0E0D0C0B0A0908ULL;
        int32_t idx32[16] = {0, 3, -5, 8, 12, -20, 7, 3, 30, -33, 40, 45, -50, 55, 60, -63};
        int64_t idx64[8] = {0, 3, -5, 8, 12, -20, 7, 3};
        if (qidx) memcpy(s.xmm[2].q, idx64, 64); else memcpy(s.xmm[2].q, idx32, 64);
        return s;
      };
      struct { const char *name; u8 op; bool W; bool qidx; int scale; } sc[] = {
        {"VPSCATTERDD", 0xA0, false, false, 4}, {"VPSCATTERDQ", 0xA0, true, false, 8},
        {"VPSCATTERQD", 0xA1, false, true, 4},  {"VPSCATTERQQ", 0xA1, true, true, 8},
        {"VSCATTERDPS", 0xA2, false, false, 4}, {"VSCATTERDPD", 0xA2, true, false, 8},
        {"VSCATTERQPS", 0xA3, false, true, 4},  {"VSCATTERQPD", 0xA3, true, true, 8},
        {"VPSCATTERDD scale 1", 0xA0, false, false, 1}, {"VPSCATTERQQ scale 2", 0xA1, true, true, 2},
      };
      for (auto &c : sc) {
        Evex e; e.mm = 2; e.pp = 1; e.W = c.W; e.opcode = c.op; e.reg = 1;
        for (int ll = 0; ll <= 2; ll++) {
          e.LL = ll;
          for (u64 mask : {~0ULL, 0x5AULL, 0x3ULL}) {
            ArchState s = with_vector_inputs(scatter_state(c.qidx), 0x6);
            s.kregs[1] = mask;
            e.aaa = 1;
            TestCase tc; tc.category = cat;
            tc.name = std::format("{} [rdi+{}*{}]{{k1}},{}1 mask={:#x}", c.name, vl_name[ll], c.scale, vl_name[ll], mask & 0xFFFF);
            tc.code = e.encode_vsib(2, c.scale);
            tc.initial = s;
            tc.init_data = std::vector<u8>(4096, 0xCC); tc.compare_data_len = 4096;
            tests.push_back(std::move(tc));
          }
        }
      }
      // An index register above 7 (zmm9) exercises EVEX.X.  Index registers
      // above 15 are left out: the model's VSIB decoder takes bit 4 of the
      // index from EVEX.R' rather than EVEX.V' (SDM Table 1-33), and the
      // resulting wild address is not survivable in this harness.
      {
        Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0xA0; e.reg = 1; e.LL = 2; e.aaa = 1;
        ArchState s = scatter_state(false);
        s.xmm[9] = s.xmm[2];
        s = with_vector_inputs(s, 0x2 | (1u << 9));
        s.kregs[1] = ~0ULL;
        TestCase tc; tc.category = cat;
        tc.name = "VPSCATTERDD [rdi+zmm9*4]{k1},zmm1";
        tc.code = e.encode_vsib(9, 4);
        tc.initial = s;
        tc.init_data = std::vector<u8>(4096, 0xCC); tc.compare_data_len = 4096;
        tests.push_back(std::move(tc));
      }

      // Gathers read the same layout back; masked-off elements keep the
      // destination's value, so the destination is an input.
      std::vector<u8> gmem(4096);
      for (int i = 0; i < 4096; i++) gmem[i] = (u8)(i * 7 + 3);
      struct { const char *name; u8 op; bool W; bool qidx; int scale; } ga[] = {
        {"VPGATHERDD", 0x90, false, false, 4}, {"VPGATHERDQ", 0x90, true, false, 8},
        {"VPGATHERQD", 0x91, false, true, 4},  {"VPGATHERQQ", 0x91, true, true, 8},
        {"VGATHERDPS", 0x92, false, false, 4}, {"VGATHERDPD", 0x92, true, false, 8},
        {"VGATHERQPS", 0x93, false, true, 4},  {"VGATHERQPD", 0x93, true, true, 8},
      };
      for (auto &g : ga) {
        Evex e; e.mm = 2; e.pp = 1; e.W = g.W; e.opcode = g.op; e.reg = 0;
        for (int ll = 0; ll <= 2; ll++) {
          e.LL = ll;
          for (u64 mask : {~0ULL, 0xA5ULL}) {
            ArchState s = scatter_state(g.qidx);
            for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEADULL;
            s = with_vector_inputs(s, 0x5);
            s.kregs[1] = mask;
            e.aaa = 1;
            TestCase tc; tc.category = cat;
            tc.name = std::format("{} {}0{{k1}},[rdi+{}*{}] mask={:#x}", g.name, vl_name[ll], vl_name[ll], g.scale, mask & 0xFFFF);
            tc.code = e.encode_vsib(2, g.scale);
            tc.initial = s; tc.init_data = gmem;
            tests.push_back(std::move(tc));
          }
        }
      }
    }
  }
}

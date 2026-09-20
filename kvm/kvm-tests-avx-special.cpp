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
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[0].q)[i] = 0xFF00FF00;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[1].q)[i] = 0x0F0F0F0F;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[2].q)[i] = 0x33333333;

    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x25;
    e.reg = 0; e.vvvv = 1; e.rm = 2;

    // imm8 = 0xFE: A | B | C
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VPTERNLOGD ") + vl[ll] + " OR",
                       cat, e.encode_rr_imm(0xFE), s, FL_NONE, 0x7, false});
      // imm8 = 0x80: A & B & C
      tests.push_back({std::string("VPTERNLOGD ") + vl[ll] + " AND",
                       cat, e.encode_rr_imm(0x80), s, FL_NONE, 0x7, false});
      // imm8 = 0x96: A ^ B ^ C
      tests.push_back({std::string("VPTERNLOGD ") + vl[ll] + " XOR3",
                       cat, e.encode_rr_imm(0x96), s, FL_NONE, 0x7, false});
      // With mask
      e.aaa = 1; e.z = true;
      tests.push_back({std::string("VPTERNLOGD ") + vl[ll] + " OR {k1}{z}",
                       cat, concat(set_kmask(0xAAAA), e.encode_rr_imm(0xFE)), s, FL_NONE, 0x7, false});
    }
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xFF00FF00FF00FF00ULL;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x0F0F0F0F0F0F0F0FULL;
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = 0x3333333333333333ULL;

    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.opcode = 0x25;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VPTERNLOGQ ") + vl[ll] + " XOR3",
                       cat, e.encode_rr_imm(0x96), s, FL_NONE, 0x7, false});
    }
  }

  // =====================================================================
  // VNNI: VPDPBUSD/VPDPBUSDS/VPDPWSSD/VPDPWSSDS
  // EVEX.66.0F38 W0:
  //   VPDPBUSD:  50    VPDPBUSDS: 51
  //   VPDPWSSD:  52    VPDPWSSDS: 53
  // =====================================================================
  {
    ArchState s = {}; s.rflags = 0x2;
    // dst (accumulator)
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[0].q)[i] = 100;
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
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[0].q)[i] = 0;  // accumulator
    float ones = 1.0f;
    u32 ones_u; memcpy(&ones_u, &ones, 4);
    // BF16 value 1.0 = 0x3F80 (upper 16 bits of float 1.0)
    for (int i = 0; i < 32; i++) ((u16 *)s.xmm[1].q)[i] = 0x3F80;
    for (int i = 0; i < 32; i++) ((u16 *)s.xmm[2].q)[i] = 0x3F80;

    Evex e; e.mm = 2; e.pp = 2; e.W = false; e.opcode = 0x52;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VDPBF16PS", e, s, 0x7, 0xAAAA);
  }
  {
    ArchState s = {}; s.rflags = 0x2;
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
                       cat, e.encode_rr(), s, FL_NONE, 0x3, false});
    }
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    float v1[] = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f,
                  9.0f, 10.0f, 11.0f, 12.0f, 13.0f, 14.0f, 15.0f, 16.0f};
    float v2[] = {10.0f, 20.0f, 30.0f, 40.0f, 50.0f, 60.0f, 70.0f, 80.0f,
                  90.0f, 100.0f, 110.0f, 120.0f, 130.0f, 140.0f, 150.0f, 160.0f};
    memcpy(s.xmm[1].q, v1, 64);
    memcpy(s.xmm[2].q, v2, 64);

    Evex e; e.mm = 2; e.pp = 3; e.W = false; e.opcode = 0x72;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VCVTNE2PS2BF16", e, s, 0x7, 0x55555555);
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
      ArchState s = {}; s.rflags = 0x2;
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
        add_evex_rr_tests(tests, cat, a.name, e, s, 0x7, 0);
      }
    }
  }

  // =====================================================================
  // VPCONFLICTD/Q: detect conflicts (duplicate indices) in each element
  // EVEX.66.0F38.W0 C4 /r (VPCONFLICTD)
  // EVEX.66.0F38.W1 C4 /r (VPCONFLICTQ)
  // =====================================================================
  {
    ArchState s = {}; s.rflags = 0x2;
    // Put some duplicate values to create conflicts
    u32 dvals[] = {1, 2, 1, 3, 2, 1, 4, 5, 1, 2, 3, 4, 5, 6, 7, 8};
    memcpy(s.xmm[1].q, dvals, 64);

    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0xC4;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VPCONFLICTD", e, s, 0x3, 0xAAAA);
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    u64 qvals[] = {10, 20, 10, 30, 20, 10, 40, 50};
    memcpy(s.xmm[1].q, qvals, 64);

    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0xC4;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VPCONFLICTQ", e, s, 0x3, 0x55);
  }

  // =====================================================================
  // VPMADD52LUQ/HUQ: multiply-add unsigned 52-bit integers
  // EVEX.66.0F38.W1 B4 /r (VPMADD52LUQ)
  // EVEX.66.0F38.W1 B5 /r (VPMADD52HUQ)
  // =====================================================================
  {
    ArchState s = {}; s.rflags = 0x2;
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
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = i + 1;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = 0x53;

    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0xCF;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VGF2P8MULB", e, s, 0x7, 0xAAAAAAAA);
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    // Matrix in qword-granularity per lane
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x0102030405060708ULL;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = i + 1;

    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.opcode = 0xCE;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VGF2P8AFFINEQB ") + vl[ll],
                       cat, e.encode_rr_imm(0x00), s, FL_NONE, 0x7, false});
    }
    e.opcode = 0xCF;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VGF2P8AFFINEINVQB ") + vl[ll],
                       cat, e.encode_rr_imm(0x00), s, FL_NONE, 0x7, false});
    }
  }

  // =====================================================================
  // VPMULTISHIFTQB: multishift bytes from qword
  // EVEX.66.0F38.W1 83 /r
  // =====================================================================
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x0706050403020100ULL + i * 8;
    for (int i = 0; i < 8; i++) s.xmm[2].q[i] = 0xFEDCBA9876543210ULL;

    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x83;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VPMULTISHIFTQB", e, s, 0x7, 0xAAAAAAAA);
  }

  // =====================================================================
  // VDBPSADBW: double block packed sum of absolute differences
  // EVEX.66.0F3A.W0 42 /r ib
  // =====================================================================
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = i;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = 64 + i;

    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x42;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VDBPSADBW ") + vl[ll],
                       cat, e.encode_rr_imm(0), s, FL_NONE, 0x7, false});
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
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 32; i++) ((u16 *)s.xmm[1].q)[i] = 0x1234;
    for (int i = 0; i < 32; i++) ((u16 *)s.xmm[2].q)[i] = 0x5678;

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
                         cat, e.encode_rr_imm(4), s, FL_NONE, 0x7, false});
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
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 32; i++) ((u16 *)s.xmm[0].q)[i] = 0x1234;
    for (int i = 0; i < 32; i++) ((u16 *)s.xmm[1].q)[i] = 0x5678;
    for (int i = 0; i < 32; i++) ((u16 *)s.xmm[2].q)[i] = 4;

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
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[1].q)[i] = 0x100 * (i + 1);

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
      add_evex_rr_tests(tests, cat, c.name, e, s, 0x3, c.kmask);
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
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[1].q)[i] = 0x100 * (i + 1);

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
      add_evex_rr_tests(tests, cat, x.name, e, s, 0x3, x.kmask);
    }
  }

  // =====================================================================
  // VCMPPS/PD: packed FP compare with immediate predicate → k-register
  // EVEX.NP.0F.W0 C2 /r ib (VCMPPS)
  // EVEX.66.0F.W1 C2 /r ib (VCMPPD)
  // =====================================================================
  {
    static const std::vector<u8> kmovq_k0_rax = {0xC4, 0xE1, 0xFB, 0x93, 0xC0};

    ArchState s = {}; s.rflags = 0x2;
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
      tests.push_back({std::string("VCMPPS EQ ") + vl[ll], cat, code, s, FL_NONE, 0, false});
      // imm=1: LT
      code = e.encode_rr_imm(1);
      code.insert(code.end(), kmovq_k0_rax.begin(), kmovq_k0_rax.end());
      tests.push_back({std::string("VCMPPS LT ") + vl[ll], cat, code, s, FL_NONE, 0, false});
    }
  }
  {
    static const std::vector<u8> kmovq_k0_rax = {0xC4, 0xE1, 0xFB, 0x93, 0xC0};

    ArchState s = {}; s.rflags = 0x2;
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
      tests.push_back({std::string("VCMPPD EQ ") + vl[ll], cat, code, s, FL_NONE, 0, false});
      code = e.encode_rr_imm(1);
      code.insert(code.end(), kmovq_k0_rax.begin(), kmovq_k0_rax.end());
      tests.push_back({std::string("VCMPPD LT ") + vl[ll], cat, code, s, FL_NONE, 0, false});
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
    ArchState s = {}; s.rflags = 0x2;
    float vals[] = {1.0f, 2.0f, 4.0f, 8.0f, 0.5f, 0.25f, 16.0f, 64.0f,
                    1.0f, 2.0f, 4.0f, 8.0f, 0.5f, 0.25f, 16.0f, 64.0f};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x42;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VGETEXPPS", e, s, 0x3, 0xAAAA);
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    double vals[] = {1.0, 2.0, 4.0, 8.0, 0.5, 0.25, 16.0, 64.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x42;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    add_evex_rr_tests(tests, cat, "VGETEXPPD", e, s, 0x3, 0x55);
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    float vals[] = {1.0f, 2.0f, 0.5f, 4.0f, 1.0f, 2.0f, 0.5f, 4.0f,
                    1.0f, 2.0f, 0.5f, 4.0f, 1.0f, 2.0f, 0.5f, 4.0f};
    float exps[] = {2.0f, 3.0f, -1.0f, 0.0f, 2.0f, 3.0f, -1.0f, 0.0f,
                    2.0f, 3.0f, -1.0f, 0.0f, 2.0f, 3.0f, -1.0f, 0.0f};
    memcpy(s.xmm[1].q, vals, 64);
    memcpy(s.xmm[2].q, exps, 64);

    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x2C;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VSCALEFPS", e, s, 0x7, 0xAAAA);
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    double vals[] = {1.0, 2.0, 0.5, 4.0, 1.0, 2.0, 0.5, 4.0};
    double exps[] = {2.0, 3.0, -1.0, 0.0, 2.0, 3.0, -1.0, 0.0};
    memcpy(s.xmm[1].q, vals, 64);
    memcpy(s.xmm[2].q, exps, 64);

    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x2C;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, "VSCALEFPD", e, s, 0x7, 0x55);
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
    ArchState s = {}; s.rflags = 0x2;
    float vals[] = {1.0f, 2.0f, 4.0f, 8.0f, 0.5f, 0.25f, 16.0f, 64.0f,
                    1.0f, 2.0f, 4.0f, 8.0f, 0.5f, 0.25f, 16.0f, 64.0f};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 2; e.pp = 1; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.W = false; e.opcode = 0x4C;
    add_evex_rr_tests(tests, cat, "VRCP14PS", e, s, 0x3, 0xAAAA);
    e.W = false; e.opcode = 0x4E;
    add_evex_rr_approx_tests(tests, cat, "VRSQRT14PS", e, s, 0x3, 32);
  }
  // VRCP14PD/VRSQRT14PD need f64 source data
  {
    ArchState s = {}; s.rflags = 0x2;
    double vals[] = {1.0, 2.0, 4.0, 8.0, 0.5, 0.25, 16.0, 64.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 2; e.pp = 1; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.W = true; e.opcode = 0x4C;
    add_evex_rr_approx_tests(tests, cat, "VRCP14PD", e, s, 0x3, 64);
    e.W = true; e.opcode = 0x4E;
    add_evex_rr_approx_tests(tests, cat, "VRSQRT14PD", e, s, 0x3, 64);
  }

  // VRNDSCALEPS: EVEX.66.0F3A.W0 08 /r ib
  // VRNDSCALEPD: EVEX.66.0F3A.W1 09 /r ib
  {
    ArchState s = {}; s.rflags = 0x2;
    float vals[] = {1.3f, 2.7f, -1.5f, 3.9f, -0.1f, 4.5f, -2.2f, 8.8f,
                    1.3f, 2.7f, -1.5f, 3.9f, -0.1f, 4.5f, -2.2f, 8.8f};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x08;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VRNDSCALEPS ") + vl[ll],
                       cat, e.encode_rr_imm(0x00), s, FL_NONE, 0x3, false});
    }
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    double vals[] = {1.3, 2.7, -1.5, 3.9, -0.1, 4.5, -2.2, 8.8};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.opcode = 0x09;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VRNDSCALEPD ") + vl[ll],
                       cat, e.encode_rr_imm(0x00), s, FL_NONE, 0x3, false});
    }
  }

  // VREDUCEPS: EVEX.66.0F3A.W0 56 /r ib
  // VREDUCEPD: EVEX.66.0F3A.W1 56 /r ib
  {
    ArchState s = {}; s.rflags = 0x2;
    float vals[] = {3.14f, 6.28f, -1.5f, 100.9f, 0.5f, -255.1f, 0.0f, -1.0f,
                    3.14f, 6.28f, -1.5f, 100.9f, 0.5f, -255.1f, 0.0f, -1.0f};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x56;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VREDUCEPS ") + vl[ll],
                       cat, e.encode_rr_imm(0x08), s, FL_NONE, 0x3, false});
    }
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    double vals[] = {3.14, 6.28, -1.5, 100.9, 0.5, -255.1, 0.0, -1.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.opcode = 0x56;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VREDUCEPD ") + vl[ll],
                       cat, e.encode_rr_imm(0x08), s, FL_NONE, 0x3, false});
    }
  }

  // VRANGEPS: EVEX.66.0F3A.W0 50 /r ib
  // VRANGEPD: EVEX.66.0F3A.W1 50 /r ib
  {
    ArchState s = {}; s.rflags = 0x2;
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
                       cat, e.encode_rr_imm(0), s, FL_NONE, 0x7, false});
    }
  }
  {
    ArchState s = {}; s.rflags = 0x2;
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
                       cat, e.encode_rr_imm(0), s, FL_NONE, 0x7, false});
    }
  }

  // VGETMANTPS: EVEX.66.0F3A.W0 26 /r ib
  // VGETMANTPD: EVEX.66.0F3A.W1 26 /r ib
  {
    ArchState s = {}; s.rflags = 0x2;
    float vals[] = {1.5f, 2.5f, 4.0f, 8.0f, 0.5f, 0.25f, 16.0f, 64.0f,
                    1.5f, 2.5f, 4.0f, 8.0f, 0.5f, 0.25f, 16.0f, 64.0f};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x26;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VGETMANTPS ") + vl[ll],
                       cat, e.encode_rr_imm(0), s, FL_NONE, 0x3, false});
    }
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    double vals[] = {1.5, 2.5, 4.0, 8.0, 0.5, 0.25, 16.0, 64.0};
    memcpy(s.xmm[1].q, vals, 64);

    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.opcode = 0x26;
    e.reg = 0; e.vvvv = 0; e.rm = 1;
    for (int ll = 0; ll <= 2; ll++) {
      const char *vl[] = {"xmm", "ymm", "zmm"};
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VGETMANTPD ") + vl[ll],
                       cat, e.encode_rr_imm(0), s, FL_NONE, 0x3, false});
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
      ArchState s = {}; s.rflags = 0x2;
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
                         cat, e.encode_rr_imm(0x00), s, FL_NONE, 0x7, false});
        tests.push_back({std::string("VPCLMULQDQ ") + vl[ll] + " imm=0x01",
                         cat, e.encode_rr_imm(0x01), s, FL_NONE, 0x7, false});
        tests.push_back({std::string("VPCLMULQDQ ") + vl[ll] + " imm=0x10",
                         cat, e.encode_rr_imm(0x10), s, FL_NONE, 0x7, false});
        tests.push_back({std::string("VPCLMULQDQ ") + vl[ll] + " imm=0x11",
                         cat, e.encode_rr_imm(0x11), s, FL_NONE, 0x7, false});
      }
    }
  }

  // =====================================================================
  // VBROADCASTI32X2: EVEX.66.0F38.W0 59 /r (xmm/ymm/zmm) and
  // VBROADCASTF32X2: EVEX.66.0F38.W0 19 /r (ymm/zmm only) [AVX512DQ]
  // Broadcast the low dword pair of xmm/m64; writemask per dword.
  // =====================================================================
  {
    ArchState s = {}; s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x2222222211111111, 0x4444444433333333);
    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.reg = 0; e.vvvv = 0; e.rm = 1;
    e.opcode = 0x59;
    add_evex_rr_tests(tests, cat, "VBROADCASTI32X2", e, s, 0x3, 0xAAAA);
    e.opcode = 0x19;
    const char *vl[] = {"xmm", "ymm", "zmm"};
    for (int ll = 1; ll <= 2; ll++) {
      e.LL = ll; e.aaa = 0; e.z = false;
      tests.push_back({std::string("VBROADCASTF32X2 ") + vl[ll], cat, e.encode_rr(), s, FL_NONE, 0x3, false});
      e.aaa = 1; e.z = true;
      tests.push_back({std::string("VBROADCASTF32X2 ") + vl[ll] + " {k1}{z}", cat,
                       concat(set_kmask(0x5555), e.encode_rr()), s, FL_NONE, 0x3, false});
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
      ArchState s = {}; s.rflags = 0x2;
      for (int i = 0; i < 16; i++) {
        ((u32 *)s.xmm[1].q)[i] = (i * 5) % 11;
        ((u32 *)s.xmm[2].q)[i] = (i * 3 + 1) % 9;
      }
      const char *vl[] = {"xmm", "ymm", "zmm"};
      for (int w = 0; w <= 1; w++) {
        for (int ll = 0; ll <= 2; ll++) {
          Evex e; e.mm = 2; e.pp = 3; e.W = w; e.opcode = 0x68;
          e.reg = 3; e.vvvv = 1; e.rm = 2; e.LL = ll;  // k3 encodes the k2/k3 pair
          TestCase tc = {std::string(w ? "VP2INTERSECTQ " : "VP2INTERSECTD ") + vl[ll] + " -> k2/k3",
                         cat, e.encode_rr(), s, FL_NONE, 0x0, false};
          tc.kreg_mask = (1 << 2) | (1 << 3);
          tests.push_back(std::move(tc));
        }
      }
    }
  }
}

#include "kvm-avx-encoder.h"

void add_avx_narrow_tests(std::vector<TestCase> &tests) {
  std::string cat = "AVX narrow";

  auto zmm_to_data = [](const ZmmVal &v) {
    std::vector<u8> d(64); memcpy(d.data(), v.q, 64); return d;
  };

  // =====================================================================
  // VPMOV narrowing (18 variants): truncation, signed sat, unsigned sat
  // These write to reg or memory. For reg: writemask applies.
  // Encoding: EVEX.F3.0F38.W0 opcode /r (src=reg field, dst=r/m)
  //
  // Trunc:   VPMOVWB=30, VPMOVDB=31, VPMOVQB=32, VPMOVDW=33, VPMOVQW=34, VPMOVQD=35
  // SatS:    VPMOVSWB=20, VPMOVSDB=21, VPMOVSQB=22, VPMOVSDW=23, VPMOVSQW=24, VPMOVSQD=25
  // SatU:    VPMOVUSWB=10, VPMOVUSDB=11, VPMOVUSQB=12, VPMOVUSDW=13, VPMOVUSQW=14, VPMOVUSQD=15
  //
  // Note: src is in modrm.reg, dst is in modrm.rm (reversed from usual).
  // =====================================================================

  struct NarrowEntry {
    const char *name;
    u8 opcode;
    int src_eb;  // for filling source data
  };

  // Word→Byte
  static const NarrowEntry wb_entries[] = {
    {"VPMOVWB",   0x30, 16}, {"VPMOVSWB",  0x20, 16}, {"VPMOVUSWB", 0x10, 16},
  };
  // DWord→Byte
  static const NarrowEntry db_entries[] = {
    {"VPMOVDB",   0x31, 32}, {"VPMOVSDB",  0x21, 32}, {"VPMOVUSDB", 0x11, 32},
  };
  // QWord→Byte
  static const NarrowEntry qb_entries[] = {
    {"VPMOVQB",   0x32, 64}, {"VPMOVSQB",  0x22, 64}, {"VPMOVUSQB", 0x12, 64},
  };
  // DWord→Word
  static const NarrowEntry dw_entries[] = {
    {"VPMOVDW",   0x33, 32}, {"VPMOVSDW",  0x23, 32}, {"VPMOVUSDW", 0x13, 32},
  };
  // QWord→Word
  static const NarrowEntry qw_entries[] = {
    {"VPMOVQW",   0x34, 64}, {"VPMOVSQW",  0x24, 64}, {"VPMOVUSQW", 0x14, 64},
  };
  // QWord→DWord
  static const NarrowEntry qd_entries[] = {
    {"VPMOVQD",   0x35, 64}, {"VPMOVSQD",  0x25, 64}, {"VPMOVUSQD", 0x15, 64},
  };

  auto add_narrow = [&](const NarrowEntry *entries, int count, ArchState s, u32 kmask) {
    for (int e = 0; e < count; e++) {
      // VPMOV: src is reg field, dst is rm field (reversed)
      // EVEX.F3.0F38.W0
      Evex ev;
      ev.mm = 2; ev.pp = 2; ev.W = false; ev.opcode = entries[e].opcode;
      ev.reg = 1;   // src = zmm1
      ev.vvvv = 0;  // unused (must be 0)
      ev.rm = 0;    // dst = zmm0

      // reg-reg: test all VLs with writemask
      add_evex_rr_tests(tests, cat, entries[e].name, ev, s, 0x3, kmask);
    }
  };

  // Word→Byte sources: mix values to exercise saturation
  {
    ArchState s; s.rflags = 0x2;
    for (int i = 0; i < 32; i++) ((u16 *)s.xmm[1].q)[i] = i * 17;  // 0..527
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;
    add_narrow(wb_entries, 3, s, 0xAAAAAAAA);
  }
  // DWord→Byte
  {
    ArchState s; s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[1].q)[i] = i * 37;
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;
    add_narrow(db_entries, 3, s, 0xAAAA);
  }
  // QWord→Byte
  {
    ArchState s; s.rflags = 0x2;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = i * 47;
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;
    add_narrow(qb_entries, 3, s, 0x55);
  }
  // DWord→Word
  {
    ArchState s; s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u32 *)s.xmm[1].q)[i] = i * 5000;
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;
    add_narrow(dw_entries, 3, s, 0xAAAA);
  }
  // QWord→Word
  {
    ArchState s; s.rflags = 0x2;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = i * 10000;
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;
    add_narrow(qw_entries, 3, s, 0x55);
  }
  // QWord→DWord
  {
    ArchState s; s.rflags = 0x2;
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x100000000ULL * (i + 1);
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;
    add_narrow(qd_entries, 3, s, 0x55);
  }

  // =====================================================================
  // VPMOVSXBW..DQ / VPMOVZXBW..DQ (widening)
  // EVEX.66.0F38.WIG opcode /r
  //   VPMOVSXBW=20 VPMOVSXBD=21 VPMOVSXBQ=22 VPMOVSXWD=23 VPMOVSXWQ=24 VPMOVSXDQ=25
  //   VPMOVZXBW=30 VPMOVZXBD=31 VPMOVZXBQ=32 VPMOVZXWD=33 VPMOVZXWQ=34 VPMOVZXDQ=35
  // =====================================================================
  {
    struct WidenEntry { const char *name; u8 opcode; bool W; };
    static const WidenEntry widen[] = {
      {"VPMOVSXBW", 0x20, false}, {"VPMOVSXBD", 0x21, false}, {"VPMOVSXBQ", 0x22, false},
      {"VPMOVSXWD", 0x23, false}, {"VPMOVSXWQ", 0x24, false}, {"VPMOVSXDQ", 0x25, false},
      {"VPMOVZXBW", 0x30, false}, {"VPMOVZXBD", 0x31, false}, {"VPMOVZXBQ", 0x32, false},
      {"VPMOVZXWD", 0x33, false}, {"VPMOVZXWQ", 0x34, false}, {"VPMOVZXDQ", 0x35, false},
    };

    ArchState s; s.rflags = 0x2;
    // Source with mix of positive and negative values (for sign-extension tests)
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = 0x70 + i;  // wraps to negative in signed
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    for (const auto &w : widen) {
      Evex e;
      e.mm = 2; e.pp = 1; e.W = w.W; e.opcode = w.opcode;
      e.reg = 0; e.vvvv = 0; e.rm = 1;
      // Determine mask based on output element count
      u32 kmask = 0x55555555;  // default
      if (w.opcode == 0x22 || w.opcode == 0x32) kmask = 0x55;  // BQ: 8 qwords max
      else if (w.opcode == 0x21 || w.opcode == 0x31 || w.opcode == 0x24 || w.opcode == 0x34)
        kmask = 0xAAAA;  // BD,WQ: 16 dwords/qwords max
      else if (w.opcode == 0x25 || w.opcode == 0x35) kmask = 0x55;  // DQ: 8 qwords max

      add_evex_rr_tests(tests, cat, w.name, e, s, 0x3, kmask);
    }
  }

  // =====================================================================
  // PACK: VPACKSSWB/VPACKUSWB/VPACKSSDW/VPACKUSDW
  // Per 128-bit lane: pack src1 and src2 with saturation
  // VPACKSSWB: 66 0F 63, WIG    VPACKUSWB: 66 0F 67, WIG
  // VPACKSSDW: 66 0F 6B, W0     VPACKUSDW: 66 0F38 2B, W0
  // =====================================================================
  {
    // VPACKSSWB / VPACKUSWB: word → byte
    ArchState s; s.rflags = 0x2;
    for (int i = 0; i < 32; i++) ((int16_t *)s.xmm[1].q)[i] = -200 + i * 15;
    for (int i = 0; i < 32; i++) ((int16_t *)s.xmm[2].q)[i] = 50 + i * 10;
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    Evex e; e.mm = 1; e.pp = 1; e.W = false; e.reg = 0; e.vvvv = 1; e.rm = 2;

    e.opcode = 0x63;
    add_evex_rr_tests(tests, cat, "VPACKSSWB", e, s, 0x7, 0xAAAAAAAA);
    e.opcode = 0x67;
    add_evex_rr_tests(tests, cat, "VPACKUSWB", e, s, 0x7, 0xAAAAAAAA);
  }
  {
    // VPACKSSDW: dword → word
    ArchState s; s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((int32_t *)s.xmm[1].q)[i] = -50000 + i * 8000;
    for (int i = 0; i < 16; i++) ((int32_t *)s.xmm[2].q)[i] = 10000 + i * 5000;
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    Evex e; e.mm = 1; e.pp = 1; e.W = false; e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.opcode = 0x6B;
    add_evex_rr_tests(tests, cat, "VPACKSSDW", e, s, 0x7, 0x55555555);
  }
  {
    // VPACKUSDW: 66 0F38 2B, W0
    ArchState s; s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((int32_t *)s.xmm[1].q)[i] = -1000 + i * 5000;
    for (int i = 0; i < 16; i++) ((int32_t *)s.xmm[2].q)[i] = 60000 + i * 1000;
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.opcode = 0x2B;
    add_evex_rr_tests(tests, cat, "VPACKUSDW", e, s, 0x7, 0x55555555);
  }

  // =====================================================================
  // VPUNPCKL/H: interleave low/high elements
  // VPUNPCKLBW: 66 0F 60   VPUNPCKHBW: 66 0F 68
  // VPUNPCKLWD: 66 0F 61   VPUNPCKHWD: 66 0F 69
  // VPUNPCKLDQ: 66 0F 62   VPUNPCKHDQ: 66 0F 6A
  // VPUNPCKLQDQ: 66 0F 6C  VPUNPCKHQDQ: 66 0F 6D
  // =====================================================================
  {
    ArchState s; s.rflags = 0x2;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = i;
    for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = 128 + i;
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    struct { const char *name; u8 opcode; bool W; u32 kmask; } unpck[] = {
      {"VPUNPCKLBW",  0x60, false, 0xAAAAAAAA},
      {"VPUNPCKHBW",  0x68, false, 0xAAAAAAAA},
      {"VPUNPCKLWD",  0x61, false, 0x55555555},
      {"VPUNPCKHWD",  0x69, false, 0x55555555},
      {"VPUNPCKLDQ",  0x62, false, 0xAAAA},
      {"VPUNPCKHDQ",  0x6A, false, 0xAAAA},
      {"VPUNPCKLQDQ", 0x6C, true,  0x55},
      {"VPUNPCKHQDQ", 0x6D, true,  0x55},
    };

    for (const auto &u : unpck) {
      Evex e; e.mm = 1; e.pp = 1; e.W = u.W; e.opcode = u.opcode;
      e.reg = 0; e.vvvv = 1; e.rm = 2;
      add_evex_rr_tests(tests, cat, u.name, e, s, 0x7, u.kmask);
    }
  }
}

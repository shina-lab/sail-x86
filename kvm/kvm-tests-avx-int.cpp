#include "kvm-avx-encoder.h"

void add_avx_int_tests(std::vector<TestCase> &tests) {
  std::string cat;

  // Helper: fill ZMM with byte pattern
  auto fill_bytes = [](ZmmVal &v, u8 start) {
    for (int i = 0; i < 64; i++) ((u8 *)v.q)[i] = start + i;
  };

  // Helper: fill ZMM with word pattern
  auto fill_words = [](ZmmVal &v, u16 start, u16 step) {
    for (int i = 0; i < 32; i++) ((u16 *)v.q)[i] = start + i * step;
  };

  // Helper: fill ZMM with dword pattern
  auto fill_dwords = [](ZmmVal &v, u32 start, u32 step) {
    for (int i = 0; i < 16; i++) ((u32 *)v.q)[i] = start + i * step;
  };

  // Helper: fill ZMM with qword pattern
  auto fill_qwords = [](ZmmVal &v, u64 start, u64 step) {
    for (int i = 0; i < 8; i++) v.q[i] = start + i * step;
  };

  auto zmm_to_data = [](const ZmmVal &v) {
    std::vector<u8> d(64);
    memcpy(d.data(), v.q, 64);
    return d;
  };

  // Generic binary int test: reg-reg + reg-mem + writemask
  auto add_int_binary = [&](const char *name, int mm, int pp, bool W, u8 opcode,
                             ArchState s, u32 kmask, u32 xmm_cmp = 0x7) {
    Evex e;
    e.mm = mm; e.pp = pp; e.W = W; e.opcode = opcode;
    e.reg = 0; e.vvvv = 1; e.rm = 2;
    add_evex_rr_tests(tests, cat, name, e, s, xmm_cmp, kmask);

    // reg-mem
    ArchState sm = s;
    sm.rdi = DATA_ADDR;
    add_evex_rm_tests(tests, cat, name, e, sm, 0x3, zmm_to_data(s.xmm[2]), kmask);
  };

  // VEX misaligned memory helpers (VEX computational → align=no)
  std::vector<u8> adata(64, 0x42);
  auto add_vok = [&](const std::string &name, std::vector<u8> code) {
    TestCase tc; tc.name = name; tc.category = cat;
    tc.code = std::move(code);
    tc.initial = {.rdi = DATA_ADDR + 1, .rflags = 0x2};
    tc.xmm_mask = 0x1; tc.init_data = adata;
    tests.push_back(std::move(tc));
  };
  auto vex_bin = [](int pp, u8 op, bool L) {
    Vex v; v.mm = 1; v.pp = pp; v.W = false; v.opcode = op;
    v.reg = 0; v.vvvv = 1; v.L = L;
    return v.encode_rm_mem();
  };
  auto vex38_bin = [](int pp, u8 op, bool L) {
    Vex v; v.mm = 2; v.pp = pp; v.W = false; v.opcode = op;
    v.reg = 0; v.vvvv = 1; v.L = L;
    return v.encode_rm_mem();
  };
  auto vex38_un = [](int pp, u8 op, bool L) {
    Vex v; v.mm = 2; v.pp = pp; v.W = false; v.opcode = op;
    v.reg = 0; v.vvvv = 0; v.L = L;
    return v.encode_rm_mem();
  };

  // =====================================================================
  cat = "AVX int";
  // =====================================================================
  {
    // --- VPADD/VPSUB byte/word ---
    // VPADDB: 66 0F FC, WIG   VPADDW: 66 0F FD, WIG
    // VPSUBB: 66 0F F8, WIG   VPSUBW: 66 0F F9, WIG
    {
      ArchState s; s.rflags = 0x2;
      fill_bytes(s.xmm[1], 0);
      fill_bytes(s.xmm[2], 64);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_int_binary("VPADDB", 1, 1, false, 0xFC, s, 0xAAAAAAAA);
      add_vok("VPADDB xmm,[rdi] misaligned", vex_bin(1, 0xFC, false));
      add_int_binary("VPSUBB", 1, 1, false, 0xF8, s, 0xAAAAAAAA);
      add_vok("VPSUBB xmm,[rdi] misaligned", vex_bin(1, 0xF8, false));
    }
    {
      ArchState s; s.rflags = 0x2;
      fill_words(s.xmm[1], 100, 100);
      fill_words(s.xmm[2], 200, 200);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_int_binary("VPADDW", 1, 1, false, 0xFD, s, 0x55555555);
      add_vok("VPADDW xmm,[rdi] misaligned", vex_bin(1, 0xFD, false));
      add_int_binary("VPSUBW", 1, 1, false, 0xF9, s, 0x55555555);
      add_vok("VPSUBW xmm,[rdi] misaligned", vex_bin(1, 0xF9, false));
    }

    // --- VPADD/VPSUB dword/qword ---
    // VPADDD: 66 0F FE, W0    VPADDQ: 66 0F D4, W1
    // VPSUBD: 66 0F FA, W0    VPSUBQ: 66 0F FB, W1
    {
      ArchState s; s.rflags = 0x2;
      fill_dwords(s.xmm[1], 0x10000000, 0x10000000);
      fill_dwords(s.xmm[2], 0x01000000, 0x01000000);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_int_binary("VPADDD", 1, 1, false, 0xFE, s, 0xAAAA);
      add_vok("VPADDD xmm,[rdi] misaligned", vex_bin(1, 0xFE, false));
      add_int_binary("VPSUBD", 1, 1, false, 0xFA, s, 0xAAAA);
      add_vok("VPSUBD xmm,[rdi] misaligned", vex_bin(1, 0xFA, false));
    }
    {
      ArchState s; s.rflags = 0x2;
      fill_qwords(s.xmm[1], 0x100000000ULL, 0x100000000ULL);
      fill_qwords(s.xmm[2], 0x200000000ULL, 0x200000000ULL);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_int_binary("VPADDQ", 1, 1, true, 0xD4, s, 0x55);
      add_vok("VPADDQ xmm,[rdi] misaligned", vex_bin(1, 0xD4, false));
      add_int_binary("VPSUBQ", 1, 1, true, 0xFB, s, 0x55);
      add_vok("VPSUBQ xmm,[rdi] misaligned", vex_bin(1, 0xFB, false));
    }

    // --- Saturating add/sub ---
    // VPADDSB: 66 0F EC, WIG   VPADDSW: 66 0F ED, WIG
    // VPSUBSB: 66 0F E8, WIG   VPSUBSW: 66 0F E9, WIG
    // VPADDUSB: 66 0F DC, WIG  VPADDUSW: 66 0F DD, WIG
    // VPSUBUSB: 66 0F D8, WIG  VPSUBUSW: 66 0F D9, WIG
    {
      ArchState s; s.rflags = 0x2;
      // Test saturation: values near boundaries
      for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = 120 + (i % 16);  // near 127
      for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = 10 + (i % 8);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_int_binary("VPADDSB",  1, 1, false, 0xEC, s, 0xAAAAAAAA);
      add_vok("VPADDSB xmm,[rdi] misaligned", vex_bin(1, 0xEC, false));
      add_int_binary("VPSUBSB",  1, 1, false, 0xE8, s, 0xAAAAAAAA);
      add_vok("VPSUBSB xmm,[rdi] misaligned", vex_bin(1, 0xE8, false));
      add_int_binary("VPADDUSB", 1, 1, false, 0xDC, s, 0xAAAAAAAA);
      add_vok("VPADDUSB xmm,[rdi] misaligned", vex_bin(1, 0xDC, false));
      add_int_binary("VPSUBUSB", 1, 1, false, 0xD8, s, 0xAAAAAAAA);
      add_vok("VPSUBUSB xmm,[rdi] misaligned", vex_bin(1, 0xD8, false));
    }
    {
      ArchState s; s.rflags = 0x2;
      for (int i = 0; i < 32; i++) ((u16 *)s.xmm[1].q)[i] = 32000 + i * 100;
      for (int i = 0; i < 32; i++) ((u16 *)s.xmm[2].q)[i] = 1000 + i * 50;
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_int_binary("VPADDSW",  1, 1, false, 0xED, s, 0x55555555);
      add_vok("VPADDSW xmm,[rdi] misaligned", vex_bin(1, 0xED, false));
      add_int_binary("VPSUBSW",  1, 1, false, 0xE9, s, 0x55555555);
      add_vok("VPSUBSW xmm,[rdi] misaligned", vex_bin(1, 0xE9, false));
      add_int_binary("VPADDUSW", 1, 1, false, 0xDD, s, 0x55555555);
      add_vok("VPADDUSW xmm,[rdi] misaligned", vex_bin(1, 0xDD, false));
      add_int_binary("VPSUBUSW", 1, 1, false, 0xD9, s, 0x55555555);
      add_vok("VPSUBUSW xmm,[rdi] misaligned", vex_bin(1, 0xD9, false));
    }

    // --- Average ---
    // VPAVGB: 66 0F E0, WIG   VPAVGW: 66 0F E3, WIG
    {
      ArchState s; s.rflags = 0x2;
      fill_bytes(s.xmm[1], 10);
      fill_bytes(s.xmm[2], 20);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_int_binary("VPAVGB", 1, 1, false, 0xE0, s, 0xAAAAAAAA);
      add_vok("VPAVGB xmm,[rdi] misaligned", vex_bin(1, 0xE0, false));
    }
    {
      ArchState s; s.rflags = 0x2;
      fill_words(s.xmm[1], 1000, 100);
      fill_words(s.xmm[2], 2000, 200);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_int_binary("VPAVGW", 1, 1, false, 0xE3, s, 0x55555555);
      add_vok("VPAVGW xmm,[rdi] misaligned", vex_bin(1, 0xE3, false));
    }

    // --- Multiply ---
    // VPMULLW:  66 0F D5, WIG (word * word → low word)
    // VPMULHW:  66 0F E5, WIG (signed word * word → high word)
    // VPMULHUW: 66 0F E4, WIG (unsigned word * word → high word)
    // VPMULHRSW: 66 0F38 0B, WIG (signed word multiply, round, high)
    // VPMULLD:  66 0F38 40, W0 (dword * dword → low dword)
    // VPMULLQ:  66 0F38 40, W1 (qword * qword → low qword)
    // VPMULUDQ: 66 0F F4, W1 (unsigned dword → qword)
    // VPMULDQ:  66 0F38 28, W1 (signed dword → qword)
    {
      ArchState s; s.rflags = 0x2;
      fill_words(s.xmm[1], 100, 7);
      fill_words(s.xmm[2], 200, 11);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_int_binary("VPMULLW",   1, 1, false, 0xD5, s, 0x55555555);
      add_vok("VPMULLW xmm,[rdi] misaligned", vex_bin(1, 0xD5, false));
      add_int_binary("VPMULHW",   1, 1, false, 0xE5, s, 0x55555555);
      add_vok("VPMULHW xmm,[rdi] misaligned", vex_bin(1, 0xE5, false));
      add_int_binary("VPMULHUW",  1, 1, false, 0xE4, s, 0x55555555);
      add_vok("VPMULHUW xmm,[rdi] misaligned", vex_bin(1, 0xE4, false));
      add_int_binary("VPMULHRSW", 2, 1, false, 0x0B, s, 0x55555555);  // 0F38 map
      add_vok("VPMULHRSW xmm,[rdi] misaligned", vex38_bin(1, 0x0B, false));
    }
    {
      ArchState s; s.rflags = 0x2;
      fill_dwords(s.xmm[1], 100, 7);
      fill_dwords(s.xmm[2], 200, 11);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_int_binary("VPMULLD",  2, 1, false, 0x40, s, 0xAAAA);       // 0F38 map
      add_vok("VPMULLD xmm,[rdi] misaligned", vex38_bin(1, 0x40, false));
    }
    {
      ArchState s; s.rflags = 0x2;
      fill_qwords(s.xmm[1], 100, 7);
      fill_qwords(s.xmm[2], 200, 11);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_int_binary("VPMULLQ",  2, 1, true, 0x40, s, 0x55);          // 0F38 W1
      add_int_binary("VPMULUDQ", 1, 1, true, 0xF4, s, 0x55);
      add_vok("VPMULUDQ xmm,[rdi] misaligned", vex_bin(1, 0xF4, false));
      add_int_binary("VPMULDQ",  2, 1, true, 0x28, s, 0x55);          // 0F38 W1
      add_vok("VPMULDQ xmm,[rdi] misaligned", vex38_bin(1, 0x28, false));
    }

    // --- MADD ---
    // VPMADDWD:  66 0F F5, WIG (pairs of words → dwords)
    // VPMADDUBSW: 66 0F38 04, WIG (unsigned*signed byte pairs → words with sat)
    {
      ArchState s; s.rflags = 0x2;
      fill_words(s.xmm[1], 10, 3);
      fill_words(s.xmm[2], 20, 5);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_int_binary("VPMADDWD", 1, 1, false, 0xF5, s, 0xAAAA);
      add_vok("VPMADDWD xmm,[rdi] misaligned", vex_bin(1, 0xF5, false));
    }
    {
      ArchState s; s.rflags = 0x2;
      fill_bytes(s.xmm[1], 1);
      fill_bytes(s.xmm[2], 2);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_int_binary("VPMADDUBSW", 2, 1, false, 0x04, s, 0x55555555); // 0F38 map
      add_vok("VPMADDUBSW xmm,[rdi] misaligned", vex38_bin(1, 0x04, false));
    }

    // --- VPSADBW: 66 0F F6, WIG ---
    {
      ArchState s; s.rflags = 0x2;
      fill_bytes(s.xmm[1], 10);
      fill_bytes(s.xmm[2], 20);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_int_binary("VPSADBW", 1, 1, false, 0xF6, s, 0);  // no writemask for BW
      add_vok("VPSADBW xmm,[rdi] misaligned", vex_bin(1, 0xF6, false));
    }
  }

  // =====================================================================
  cat = "AVX int";
  // =====================================================================
  {
    // VPANDD: 66 0F DB, W0    VPANDQ: 66 0F DB, W1
    // VPORD:  66 0F EB, W0    VPORQ:  66 0F EB, W1
    // VPXORD: 66 0F EF, W0    VPXORQ: 66 0F EF, W1
    // VPANDND: 66 0F DF, W0   VPANDNQ: 66 0F DF, W1
    ArchState sd; sd.rflags = 0x2;
    fill_dwords(sd.xmm[1], 0xFF00FF00, 1);
    fill_dwords(sd.xmm[2], 0x0F0F0F0F, 0);
    for (int i = 0; i < 8; i++) sd.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    add_int_binary("VPANDD",  1, 1, false, 0xDB, sd, 0xAAAA);
    add_vok("VPAND xmm,[rdi] misaligned", vex_bin(1, 0xDB, false));
    add_int_binary("VPORD",   1, 1, false, 0xEB, sd, 0xAAAA);
    add_vok("VPOR xmm,[rdi] misaligned", vex_bin(1, 0xEB, false));
    add_int_binary("VPXORD",  1, 1, false, 0xEF, sd, 0xAAAA);
    add_vok("VPXOR xmm,[rdi] misaligned", vex_bin(1, 0xEF, false));
    add_int_binary("VPANDND", 1, 1, false, 0xDF, sd, 0xAAAA);
    add_vok("VPANDN xmm,[rdi] misaligned", vex_bin(1, 0xDF, false));

    ArchState sq; sq.rflags = 0x2;
    fill_qwords(sq.xmm[1], 0xFF00FF00FF00FF00ULL, 1);
    fill_qwords(sq.xmm[2], 0x0F0F0F0F0F0F0F0FULL, 0);
    for (int i = 0; i < 8; i++) sq.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    add_int_binary("VPANDQ",  1, 1, true, 0xDB, sq, 0x55);
    add_int_binary("VPORQ",   1, 1, true, 0xEB, sq, 0x55);
    add_int_binary("VPXORQ",  1, 1, true, 0xEF, sq, 0x55);
    add_int_binary("VPANDNQ", 1, 1, true, 0xDF, sq, 0x55);
  }

  // =====================================================================
  cat = "AVX int";
  // =====================================================================
  {
    // VPMINSB: 66 0F38 38, WIG   VPMINUB: 66 0F DA, WIG
    // VPMAXSB: 66 0F38 3C, WIG   VPMAXUB: 66 0F DE, WIG
    {
      ArchState s; s.rflags = 0x2;
      for (int i = 0; i < 64; i++) ((u8 *)s.xmm[1].q)[i] = i * 3;
      for (int i = 0; i < 64; i++) ((u8 *)s.xmm[2].q)[i] = 100 + i;
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_int_binary("VPMINSB", 2, 1, false, 0x38, s, 0xAAAAAAAA);
      add_vok("VPMINSB xmm,[rdi] misaligned", vex38_bin(1, 0x38, false));
      add_int_binary("VPMAXSB", 2, 1, false, 0x3C, s, 0xAAAAAAAA);
      add_vok("VPMAXSB xmm,[rdi] misaligned", vex38_bin(1, 0x3C, false));
      add_int_binary("VPMINUB", 1, 1, false, 0xDA, s, 0xAAAAAAAA);
      add_vok("VPMINUB xmm,[rdi] misaligned", vex_bin(1, 0xDA, false));
      add_int_binary("VPMAXUB", 1, 1, false, 0xDE, s, 0xAAAAAAAA);
      add_vok("VPMAXUB xmm,[rdi] misaligned", vex_bin(1, 0xDE, false));
    }

    // VPMINSW: 66 0F EA, WIG   VPMINUW: 66 0F38 3A, WIG
    // VPMAXSW: 66 0F EE, WIG   VPMAXUW: 66 0F38 3E, WIG
    {
      ArchState s; s.rflags = 0x2;
      fill_words(s.xmm[1], 100, 50);
      fill_words(s.xmm[2], 1000, 30);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_int_binary("VPMINSW", 1, 1, false, 0xEA, s, 0x55555555);
      add_vok("VPMINSW xmm,[rdi] misaligned", vex_bin(1, 0xEA, false));
      add_int_binary("VPMAXSW", 1, 1, false, 0xEE, s, 0x55555555);
      add_vok("VPMAXSW xmm,[rdi] misaligned", vex_bin(1, 0xEE, false));
      add_int_binary("VPMINUW", 2, 1, false, 0x3A, s, 0x55555555);
      add_vok("VPMINUW xmm,[rdi] misaligned", vex38_bin(1, 0x3A, false));
      add_int_binary("VPMAXUW", 2, 1, false, 0x3E, s, 0x55555555);
      add_vok("VPMAXUW xmm,[rdi] misaligned", vex38_bin(1, 0x3E, false));
    }

    // VPMINSD: 66 0F38 39, W0   VPMINUD: 66 0F38 3B, W0
    // VPMAXSD: 66 0F38 3D, W0   VPMAXUD: 66 0F38 3F, W0
    {
      ArchState s; s.rflags = 0x2;
      fill_dwords(s.xmm[1], 100, 1000);
      fill_dwords(s.xmm[2], 8000, 500);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_int_binary("VPMINSD", 2, 1, false, 0x39, s, 0xAAAA);
      add_vok("VPMINSD xmm,[rdi] misaligned", vex38_bin(1, 0x39, false));
      add_int_binary("VPMAXSD", 2, 1, false, 0x3D, s, 0xAAAA);
      add_vok("VPMAXSD xmm,[rdi] misaligned", vex38_bin(1, 0x3D, false));
      add_int_binary("VPMINUD", 2, 1, false, 0x3B, s, 0xAAAA);
      add_vok("VPMINUD xmm,[rdi] misaligned", vex38_bin(1, 0x3B, false));
      add_int_binary("VPMAXUD", 2, 1, false, 0x3F, s, 0xAAAA);
      add_vok("VPMAXUD xmm,[rdi] misaligned", vex38_bin(1, 0x3F, false));
    }

    // VPMINSQ: 66 0F38 39, W1   VPMINUQ: 66 0F38 3B, W1
    // VPMAXSQ: 66 0F38 3D, W1   VPMAXUQ: 66 0F38 3F, W1
    {
      ArchState s; s.rflags = 0x2;
      fill_qwords(s.xmm[1], 100, 1000);
      fill_qwords(s.xmm[2], 4000, 500);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_int_binary("VPMINSQ", 2, 1, true, 0x39, s, 0x55);
      add_int_binary("VPMAXSQ", 2, 1, true, 0x3D, s, 0x55);
      add_int_binary("VPMINUQ", 2, 1, true, 0x3B, s, 0x55);
      add_int_binary("VPMAXUQ", 2, 1, true, 0x3F, s, 0x55);
    }
  }

  // =====================================================================
  cat = "AVX int";
  // =====================================================================
  {
    // VPABSB: 66 0F38 1C, WIG   (unary: vvvv must be 1111)
    // VPABSW: 66 0F38 1D, WIG
    // VPABSD: 66 0F38 1E, W0
    // VPABSQ: 66 0F38 1F, W1
    auto add_unary = [&](const char *name, int mm, int pp, bool W, u8 opcode,
                          ArchState s, u32 kmask) {
      Evex e;
      e.mm = mm; e.pp = pp; e.W = W; e.opcode = opcode;
      e.reg = 0; e.vvvv = 0; e.rm = 1;  // unary: no vvvv source
      add_evex_rr_tests(tests, cat, name, e, s, 0x3, kmask);
    };

    {
      ArchState s; s.rflags = 0x2;
      // Mix of positive and negative values
      for (int i = 0; i < 64; i++) ((int8_t *)s.xmm[1].q)[i] = -64 + i;
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;
      add_unary("VPABSB", 2, 1, false, 0x1C, s, 0xAAAAAAAA);
      add_vok("VPABSB xmm,[rdi] misaligned", vex38_un(1, 0x1C, false));
    }
    {
      ArchState s; s.rflags = 0x2;
      for (int i = 0; i < 32; i++) ((int16_t *)s.xmm[1].q)[i] = -16000 + i * 1000;
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;
      add_unary("VPABSW", 2, 1, false, 0x1D, s, 0x55555555);
      add_vok("VPABSW xmm,[rdi] misaligned", vex38_un(1, 0x1D, false));
    }
    {
      ArchState s; s.rflags = 0x2;
      for (int i = 0; i < 16; i++) ((int32_t *)s.xmm[1].q)[i] = -8000 + i * 1000;
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;
      add_unary("VPABSD", 2, 1, false, 0x1E, s, 0xAAAA);
      add_vok("VPABSD xmm,[rdi] misaligned", vex38_un(1, 0x1E, false));
    }
    {
      ArchState s; s.rflags = 0x2;
      for (int i = 0; i < 8; i++) s.xmm[1].q[i] = (u64)((int64_t)(-4000) + i * 1000);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;
      add_unary("VPABSQ", 2, 1, true, 0x1F, s, 0x55);
    }

    // VPOPCNTB: 66 0F38 54, W0  VPOPCNTW: 66 0F38 54, W1
    // VPOPCNTD: 66 0F38 55, W0  VPOPCNTQ: 66 0F38 55, W1
    {
      ArchState s; s.rflags = 0x2;
      fill_bytes(s.xmm[1], 0);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_unary("VPOPCNTB", 2, 1, false, 0x54, s, 0xAAAAAAAA);
      add_unary("VPOPCNTW", 2, 1, true,  0x54, s, 0x55555555);
    }
    {
      ArchState s; s.rflags = 0x2;
      fill_dwords(s.xmm[1], 0, 0x11111111);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

      add_unary("VPOPCNTD", 2, 1, false, 0x55, s, 0xAAAA);
      add_unary("VPOPCNTQ", 2, 1, true,  0x55, s, 0x55);
    }

    // VPLZCNTD: 66 0F38 44, W0  VPLZCNTQ: 66 0F38 44, W1
    {
      ArchState s; s.rflags = 0x2;
      fill_dwords(s.xmm[1], 1, 0x100);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;
      add_unary("VPLZCNTD", 2, 1, false, 0x44, s, 0xAAAA);
    }
    {
      ArchState s; s.rflags = 0x2;
      fill_qwords(s.xmm[1], 1, 0x10000);
      for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;
      add_unary("VPLZCNTQ", 2, 1, true, 0x44, s, 0x55);
    }
  }
}

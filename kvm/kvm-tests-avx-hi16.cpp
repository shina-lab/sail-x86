#include "kvm-avx-encoder.h"

// Differential tests that read and write ZMM16-31 directly.
//
// The upper sixteen ZMM registers are reachable only through the EVEX
// extension bits (R', X-for-rm, V') and live in XSAVE component 7
// (Hi16_ZMM).  Every other template family selects ZMM0-15, so results
// landing in the high registers used to be checked only through stores
// to the compared memory window; these cases compare the registers
// themselves, on both the source and the destination side.
void add_avx_hi16_tests(std::vector<TestCase> &tests) {
  std::string cat = "AVX-512 hi16";

  auto fill_qwords = [](ZmmVal &v, u64 start, u64 step) {
    for (int i = 0; i < 8; i++) v.q[i] = start + i * step;
  };
  auto fill_floats = [](ZmmVal &v, float start, float step) {
    for (int i = 0; i < 16; i++) {
      float f = start + step * i;
      memcpy((u8 *)v.q + i * 4, &f, 4);
    }
  };

  // One shared initial state: distinctive patterns in every high register,
  // plus a few low registers for cross-half cases.
  ArchState s = {.rflags = 0x2};
  for (int i = 16; i < 32; i++)
    fill_qwords(s.xmm[i], 0x0101010101010101ULL * (i - 15),
                0x1000100010001000ULL + i);
  fill_qwords(s.xmm[2], 0x00FEDCBA98765432ULL, 0x1111111111111111ULL);
  fill_qwords(s.xmm[3], 0x0F0F0F0F0F0F0F0FULL, 3);
  fill_qwords(s.xmm[4], 0xDEADBEEFCAFEF00DULL, 0x0102030405060708ULL);
  fill_floats(s.xmm[22], 1.5f, 0.25f);
  fill_floats(s.xmm[23], -3.75f, 1.5f);

  auto add_rr = [&](const char *name, int pp, bool W, u8 opcode, int LL,
                    int reg, int vvvv, int rm, u64 kval = 0, bool z = false) {
    Evex e;
    e.mm = 1; e.pp = pp; e.W = W; e.opcode = opcode; e.LL = LL;
    e.reg = reg; e.vvvv = vvvv; e.rm = rm;
    if (kval) { e.aaa = 1; e.z = z; }
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = kval ? concat(set_kmask((u32)kval), e.encode_rr())
                   : e.encode_rr();
    tc.initial = s;
    tc.flags_mask = FL_ALL;
    tc.xmm_mask = (1u << reg) | (1u << vvvv) | (1u << rm);
    tc.kreg_mask = kval ? 0x2 : 0;
    tests.push_back(std::move(tc));
  };

  // Dest and both sources above ZMM15 (exercises R', V', and X-for-rm).
  add_rr("vpaddq zmm16,zmm17,zmm18", 1, true, 0xD4, 2, 16, 17, 18);
  add_rr("vpxord zmm31,zmm30,zmm29", 1, false, 0xEF, 2, 31, 30, 29);
  add_rr("vpaddd zmm24,zmm25,zmm26", 1, false, 0xFE, 2, 24, 25, 26);

  // Cross-half: low destination from high sources and vice versa.
  add_rr("vpaddq zmm5,zmm16,zmm31", 1, true, 0xD4, 2, 5, 16, 31);
  add_rr("vpaddq zmm19,zmm2,zmm3", 1, true, 0xD4, 2, 19, 2, 3);
  add_rr("vmovdqa64 zmm19,zmm4", 1, true, 0x6F, 2, 19, 0, 4);
  add_rr("vmovdqa64 zmm6,zmm28", 1, true, 0x6F, 2, 6, 0, 28);

  // Masking with a high destination (merge and zero forms).
  add_rr("vpaddd zmm20{k1},zmm21,zmm22", 1, false, 0xFE, 2, 20, 21, 22,
         0x5A5A);
  add_rr("vpaddd zmm20{k1}{z},zmm21,zmm22", 1, false, 0xFE, 2, 20, 21, 22,
         0xA5A5, true);

  // Narrower vector lengths must zero the untouched upper bits of a
  // high destination; comparing the full 512-bit register checks that.
  add_rr("vpaddq xmm18,xmm17,xmm16 (VL128)", 1, true, 0xD4, 0, 18, 17, 16);
  add_rr("vpxord ymm27,ymm26,ymm25 (VL256)", 1, false, 0xEF, 1, 27, 26, 25);

  // FP through high registers.
  add_rr("vaddps zmm21,zmm22,zmm23", 0, false, 0x58, 2, 21, 22, 23);

  // Memory traffic from/to a high register.
  {
    // vmovdqu64 [rdi], zmm27
    Evex e;
    e.mm = 1; e.pp = 2; e.W = true; e.opcode = 0x7F; e.LL = 2; e.reg = 27;
    TestCase tc;
    tc.name = "vmovdqu64 [rdi],zmm27";
    tc.category = cat;
    tc.code = e.encode_mr_mem();
    tc.initial = s;
    tc.initial.rdi = DATA_ADDR;
    tc.flags_mask = FL_ALL;
    tc.xmm_mask = 1u << 27;
    tc.compare_data_len = 64;
    tests.push_back(std::move(tc));
  }
  {
    // vmovdqu64 zmm23, [rdi]
    Evex e;
    e.mm = 1; e.pp = 2; e.W = true; e.opcode = 0x6F; e.LL = 2; e.reg = 23;
    TestCase tc;
    tc.name = "vmovdqu64 zmm23,[rdi]";
    tc.category = cat;
    tc.code = e.encode_rm_mem();
    tc.initial = s;
    tc.initial.rdi = DATA_ADDR;
    tc.flags_mask = FL_ALL;
    tc.xmm_mask = 1u << 23;
    std::vector<u8> data(64);
    for (int i = 0; i < 64; i++) data[i] = (u8)(0xC0 + i);
    tc.init_data = std::move(data);
    tests.push_back(std::move(tc));
  }
}

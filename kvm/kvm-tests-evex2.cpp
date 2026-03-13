#include "kvm-harness.h"

void add_evex_tests_2(std::vector<TestCase> &tests) {
  std::string cat;

  auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                      u32 xmm_cmp) {
    tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
  };

  // =====================================================================
  // EVEX VPMOVDB/DW/QB (0F38 31/33/32) — truncating narrowing stores
  // =====================================================================
  cat = "EVEX VPMOV narrow";
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = {};  // destination
    // VPMOVDB xmm0, xmm1: truncate dwords to bytes (low 8 bits of each dword)
    // src=xmm1, dst=xmm0: modrm reg=1(src) r/m=0(dst) → 11_001_000 = 0xC8
    // EVEX.128.F3.0F38.W0: P0=0xF2(mm=10), P1=0x7E(W=0,vvvv=1111,pp=10), P2=0x08
    s.xmm[1] = xmm_from_u32(0x000000FF, 0x00000100, 0x12345678, 0xDEADBEEF);
    add_xmm("vpmovdb xmm0,xmm1: truncate",
            {0x62, 0xF2, 0x7E, 0x08, 0x31, 0xC8}, s, 0x3);

    // VPMOVDW xmm0, xmm1: truncate dwords to words (low 16 bits)
    // EVEX.128.F3.0F38.W0 33 /r
    s.xmm[1] = xmm_from_u32(0x0000FFFF, 0x00010000, 0x12345678, 0xDEADBEEF);
    add_xmm("vpmovdw xmm0,xmm1: truncate",
            {0x62, 0xF2, 0x7E, 0x08, 0x33, 0xC8}, s, 0x3);

    // VPMOVSDB xmm0, xmm1: signed-saturate dwords to bytes
    // EVEX.128.F3.0F38.W0 21 /r
    // 0x50 → 0x50 (within [-128,127]), 0x200 → 0x7F (saturate), -1→0xFF(-1), -200→0x80(-128)
    s.xmm[1] = xmm_from_u32(0x00000050, 0x00000200, 0xFFFFFFFF, 0xFFFFFF38);
    add_xmm("vpmovsdb xmm0,xmm1: signed sat",
            {0x62, 0xF2, 0x7E, 0x08, 0x21, 0xC8}, s, 0x3);

    // VPMOVUSDB xmm0, xmm1: unsigned-saturate dwords to bytes
    // EVEX.128.F3.0F38.W0 11 /r
    // 0x50→0x50, 0x200→0xFF(sat), 0→0, 0xFFFFFFFF→0xFF(sat)
    s.xmm[1] = xmm_from_u32(0x00000050, 0x00000200, 0x00000000, 0xFFFFFFFF);
    add_xmm("vpmovusdb xmm0,xmm1: unsigned sat",
            {0x62, 0xF2, 0x7E, 0x08, 0x11, 0xC8}, s, 0x3);

    // VPMOVQD xmm0, xmm1: truncate qwords to dwords
    // EVEX.128.F3.0F38.W0 35 /r
    s.xmm[1] = xmm_from_u64(0x123456789ABCDEF0ULL, 0xFEDCBA9876543210ULL);
    add_xmm("vpmovqd xmm0,xmm1: truncate",
            {0x62, 0xF2, 0x7E, 0x08, 0x35, 0xC8}, s, 0x3);
  }

  // =====================================================================
  // EVEX VPDPBUSD (0F38 50) — unsigned*signed byte dot product → dword
  // =====================================================================
  cat = "EVEX VNNI";
  {
    ArchState s;
    s.rflags = 0x2;
    // VPDPBUSD xmm0, xmm1, xmm2: dst += u8(s1)*s8(s2) per dword
    // dst (xmm0) = accumulator, vvvv (xmm1) = unsigned bytes, r/m (xmm2) = signed bytes
    s.xmm[0] = xmm_from_u32(0, 0, 0, 0);  // zero accumulator
    // s1 = {1,2,3,4} per dword (unsigned), s2 = {1,1,1,1} per dword (signed)
    // Product per dword = 1*1 + 2*1 + 3*1 + 4*1 = 10
    s.xmm[1] = xmm_from_u32(0x04030201, 0x04030201, 0x04030201, 0x04030201);
    s.xmm[2] = xmm_from_u32(0x01010101, 0x01010101, 0x01010101, 0x01010101);
    // EVEX.NDS.128.66.0F38.W0 50 /r
    add_xmm("vpdpbusd xmm0,xmm1,xmm2: basic",
            {0x62, 0xF2, 0x75, 0x08, 0x50, 0xC2}, s, 0x7);

    // Test with signed negatives: s2 = {-1,-1,-1,-1}
    // Product = 1*(-1) + 2*(-1) + 3*(-1) + 4*(-1) = -10
    s.xmm[2] = xmm_from_u32(0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF);
    add_xmm("vpdpbusd xmm0,xmm1,xmm2: signed neg",
            {0x62, 0xF2, 0x75, 0x08, 0x50, 0xC2}, s, 0x7);

    // VPDPBUSDS (0F38 51) — same but with signed saturation
    s.xmm[0] = xmm_from_u32(0x7FFFFFF0, 0, 0, 0);  // near INT32_MAX
    s.xmm[1] = xmm_from_u32(0xFF0A0A0A, 0x04030201, 0x04030201, 0x04030201);
    s.xmm[2] = xmm_from_u32(0x7F7F7F7F, 0x01010101, 0x01010101, 0x01010101);
    add_xmm("vpdpbusds xmm0,xmm1,xmm2: near saturation",
            {0x62, 0xF2, 0x75, 0x08, 0x51, 0xC2}, s, 0x7);

    // VPDPWSSD (0F38 52) — signed word dot product → dword
    // dst += s16(s1[0])*s16(s2[0]) + s16(s1[1])*s16(s2[1]) per dword
    s.xmm[0] = xmm_from_u32(0, 0, 0, 0);
    // s1 = {3, 4} per dword as signed words; s2 = {10, 20}
    // Product = 3*10 + 4*20 = 30 + 80 = 110
    s.xmm[1] = xmm_from_u32(0x00040003, 0x00040003, 0x00040003, 0x00040003);
    s.xmm[2] = xmm_from_u32(0x0014000A, 0x0014000A, 0x00140000, 0x00000000);
    add_xmm("vpdpwssd xmm0,xmm1,xmm2: basic",
            {0x62, 0xF2, 0x75, 0x08, 0x52, 0xC2}, s, 0x7);

    // VPDPWSSDS (0F38 53) — word dot product with signed saturation
    s.xmm[0] = xmm_from_u32(0x7FFFFFF0, 0, 0, 0);  // near INT32_MAX
    s.xmm[1] = xmm_from_u32(0x7FFF7FFF, 0x00040003, 0x00040003, 0x00040003);
    s.xmm[2] = xmm_from_u32(0x7FFF7FFF, 0x00140000, 0x00000000, 0x00000000);
    add_xmm("vpdpwssds xmm0,xmm1,xmm2: saturation",
            {0x62, 0xF2, 0x75, 0x08, 0x53, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // EVEX VGETEXPPS (0F38 42) — extract biased exponent from float32
  // =====================================================================
  cat = "EVEX VGETEXPPS";
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = {};
    // VGETEXPPS xmm0, xmm1
    // Returns floor(log2(|src|)) for each float32 element
    // 1.0 → 0.0, 2.0 → 1.0, 4.0 → 2.0, 0.5 → -1.0
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 4.0f, 0.5f);
    // EVEX.128.66.0F38.W0 42 /r  modrm=C1 (xmm0,xmm1)
    // P0=0xF2(0F38), P1=0x7D(W=0,vvvv=~0=1111,pp=01), P2=0x08
    add_xmm("vgetexpps xmm0,xmm1: 1,2,4,0.5",
            {0x62, 0xF2, 0x7D, 0x08, 0x42, 0xC1}, s, 0x3);

    // 8.0 → 3.0, 0.25 → -2.0, denormal, inf
    s.xmm[1] = xmm_from_f32(8.0f, 0.25f, 1.0e-40f, INFINITY);
    add_xmm("vgetexpps xmm0,xmm1: 8,0.25,denorm,inf",
            {0x62, 0xF2, 0x7D, 0x08, 0x42, 0xC1}, s, 0x3);
  }

  // =====================================================================
  // EVEX VSCALEFPS (0F38 2C) — scale float32 by integer power of 2
  // =====================================================================
  cat = "EVEX VSCALEFPS";
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = {};
    // VSCALEFPS xmm0, xmm1, xmm2: dst = src1 * 2^floor(src2)
    // 1.0 * 2^2 = 4.0, 3.0 * 2^0 = 3.0, 0.5 * 2^3 = 4.0, 1.0 * 2^(-1) = 0.5
    s.xmm[1] = xmm_from_f32(1.0f, 3.0f, 0.5f, 1.0f);
    s.xmm[2] = xmm_from_f32(2.0f, 0.0f, 3.0f, -1.0f);
    // EVEX.NDS.128.66.0F38.W0 2C /r  modrm=C2 (xmm0,xmm2), vvvv=xmm1
    add_xmm("vscalefps xmm0,xmm1,xmm2: basic",
            {0x62, 0xF2, 0x75, 0x08, 0x2C, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // EVEX VRNDSCALEPS (0F3A 08) — round to fixed fraction bits
  // =====================================================================
  cat = "EVEX VRNDSCALEPS";
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = {};
    s.xmm[1] = xmm_from_f32(1.5f, 2.3f, -1.7f, 3.0f);
    // VRNDSCALEPS xmm0, xmm1, imm8
    // imm8[3:0] = rounding mode: 0=nearest, 1=floor, 2=ceil, 3=truncate
    // (when imm8[2]=0, uses imm8[1:0] for rounding mode)
    // EVEX.128.66.0F3A.W0 08 /r imm8
    // P0=0xF3(0F3A), P1=0x7D(W=0,vvvv=~0,pp=01), P2=0x08, modrm=C1, imm8
    // Round nearest (0x00): 1.5→2.0, 2.3→2.0, -1.7→-2.0, 3.0→3.0
    add_xmm("vrndscaleps xmm0,xmm1,0: nearest",
            {0x62, 0xF3, 0x7D, 0x08, 0x08, 0xC1, 0x00}, s, 0x3);
    // Round floor (0x01): 1.5→1.0, 2.3→2.0, -1.7→-2.0, 3.0→3.0
    add_xmm("vrndscaleps xmm0,xmm1,1: floor",
            {0x62, 0xF3, 0x7D, 0x08, 0x08, 0xC1, 0x01}, s, 0x3);
    // Round ceil (0x02): 1.5→2.0, 2.3→3.0, -1.7→-1.0, 3.0→3.0
    add_xmm("vrndscaleps xmm0,xmm1,2: ceil",
            {0x62, 0xF3, 0x7D, 0x08, 0x08, 0xC1, 0x02}, s, 0x3);
    // Round truncate (0x03): 1.5→1.0, 2.3→2.0, -1.7→-1.0, 3.0→3.0
    add_xmm("vrndscaleps xmm0,xmm1,3: truncate",
            {0x62, 0xF3, 0x7D, 0x08, 0x08, 0xC1, 0x03}, s, 0x3);
  }

  // =====================================================================
  // EVEX VFIXUPIMMPS (0F3A 54) — fix up special float32 values
  // =====================================================================
  cat = "EVEX VFIXUPIMMPS";
  {
    ArchState s;
    s.rflags = 0x2;
    // VFIXUPIMMPS xmm0, xmm1, xmm2, imm8
    // dst=xmm0, src1(vvvv)=xmm1 (values to classify), src2(r/m)=xmm2 (lookup table)
    // Table format: each dword has 8 4-bit entries indexed by token type:
    //   [3:0]=QNAN, [7:4]=SNAN, [11:8]=ZERO, [15:12]=POS_ONE,
    //   [19:16]=NEG_INF, [23:20]=POS_INF, [27:24]=NEG_VALUE, [31:28]=POS_VALUE
    // Response 0x1 = pass through src1, 0x5 = +INF, 0xA = +1.0

    // Test: all positive values → token=POS_VALUE(7), response at bits[31:28]
    // Table = 0x10000000 → POS_VALUE response = 0x1 (pass through)
    s.xmm[0] = xmm_from_f32(99.0f, 99.0f, 99.0f, 99.0f);  // dst (not used for resp=1)
    s.xmm[1] = xmm_from_f32(1.5f, 2.5f, 3.5f, 4.5f);  // src1 to classify
    s.xmm[2] = xmm_from_u32(0x10000000, 0x10000000, 0x10000000, 0x10000000);
    // EVEX.NDS.128.66.0F3A.W0 54 /r imm8
    // P0=0xF3(0F3A), P1=0x75(W=0,vvvv=~1,pp=01), P2=0x08, modrm=0xC2, imm=0
    add_xmm("vfixupimmps: pos values pass-through",
            {0x62, 0xF3, 0x75, 0x08, 0x54, 0xC2, 0x00}, s, 0x7);

    // Test: zero input → token=ZERO(2), response at bits[11:8]
    // Table = 0x00000500 → ZERO response = 0x5 (+INF)
    s.xmm[1] = xmm_from_f32(0.0f, -0.0f, 1.0f, -1.0f);
    // For 0.0→+INF, -0.0→+INF, 1.0→pass(POS_ONE resp=0x0=preserve dst), -1.0→pass(NEG_VALUE)
    // Table: ZERO=5(+INF), POS_ONE=0(preserve dst), NEG_VALUE=1(pass src1), POS_VALUE=1(pass src1)
    s.xmm[2] = xmm_from_u32(0x11010500, 0x11010500, 0x11010500, 0x11010500);
    s.xmm[0] = xmm_from_f32(42.0f, 42.0f, 42.0f, 42.0f);
    add_xmm("vfixupimmps: zero→+INF, one→preserve, neg→pass",
            {0x62, 0xF3, 0x75, 0x08, 0x54, 0xC2, 0x00}, s, 0x7);
  }

  // =====================================================================
  // EVEX VREDUCEPS (0F3A 56) — reduce float range
  // =====================================================================
  cat = "EVEX VREDUCEPS";
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = {};
    // VREDUCEPS: dst = src - round(src) * 2^(-M), where M = imm8[7:4]
    // For imm8=0x00 (M=0, nearest): reduces to src - round_nearest(src)
    // This gives the fractional part (nearest rounding)
    s.xmm[1] = xmm_from_f32(1.5f, 2.3f, -1.7f, 3.0f);
    // EVEX.128.66.0F3A.W0 56 /r imm8
    add_xmm("vreduceps xmm0,xmm1,0: basic",
            {0x62, 0xF3, 0x7D, 0x08, 0x56, 0xC1, 0x00}, s, 0x3);
    // imm8=0x03 (M=0, RS=0, RC=11=truncate): src - trunc(src) = fractional part
    add_xmm("vreduceps xmm0,xmm1,0x03: truncate frac",
            {0x62, 0xF3, 0x7D, 0x08, 0x56, 0xC1, 0x03}, s, 0x3);
  }

  // =====================================================================
  // EVEX VRANGEPS (0F3A 50) — range restriction
  // VRANGEPS xmm0, xmm1, xmm2, imm8
  // EVEX.128.66.0F3A.W0: P0=0xF3(mm=11), P1=0x75(W=0,vvvv=~1,pp=01), P2=0x08
  // opcode=0x50, modrm=0xC2 (reg=xmm0, rm=xmm2)
  // imm8[1:0]=CmpOpCtl: 0=min, 1=max, 2=abs_min, 3=abs_max
  // imm8[3:2]=SignSelCtl: 0=src1_sign, 1=result_sign, 2=force+, 3=force-
  // =====================================================================
  cat = "EVEX VRANGEPS";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = {};
    // src1 (xmm1): mixed positive/negative values
    s.xmm[1] = xmm_from_f32(3.0f, -5.0f, 1.0f, -2.0f);
    // src2 (xmm2): different values for comparison
    s.xmm[2] = xmm_from_f32(4.0f, 2.0f, -3.0f, 7.0f);

    // imm8=0x00: min, preserve src1 sign
    add_xmm("vrangeps: min, src1 sign",
            {0x62, 0xF3, 0x75, 0x08, 0x50, 0xC2, 0x00}, s, 0x3);
    // imm8=0x01: max, preserve src1 sign
    add_xmm("vrangeps: max, src1 sign",
            {0x62, 0xF3, 0x75, 0x08, 0x50, 0xC2, 0x01}, s, 0x3);
    // imm8=0x02: abs_min, preserve src1 sign
    // |3|=3 vs |4|=4 → src1(3.0); |-5|=5 vs |2|=2 → src2(2.0) but sign=src1=-
    add_xmm("vrangeps: abs_min, src1 sign",
            {0x62, 0xF3, 0x75, 0x08, 0x50, 0xC2, 0x02}, s, 0x3);
    // imm8=0x03: abs_max, preserve src1 sign
    add_xmm("vrangeps: abs_max, src1 sign",
            {0x62, 0xF3, 0x75, 0x08, 0x50, 0xC2, 0x03}, s, 0x3);

    // imm8=0x05: max, preserve result sign (signCtl=01)
    add_xmm("vrangeps: max, result sign",
            {0x62, 0xF3, 0x75, 0x08, 0x50, 0xC2, 0x05}, s, 0x3);
    // imm8=0x08: min, force positive (signCtl=10)
    add_xmm("vrangeps: min, force positive",
            {0x62, 0xF3, 0x75, 0x08, 0x50, 0xC2, 0x08}, s, 0x3);
    // imm8=0x0D: max, force negative (signCtl=11)
    add_xmm("vrangeps: max, force negative",
            {0x62, 0xF3, 0x75, 0x08, 0x50, 0xC2, 0x0D}, s, 0x3);
    // imm8=0x0A: abs_min, force positive (signCtl=10)
    add_xmm("vrangeps: abs_min, force positive",
            {0x62, 0xF3, 0x75, 0x08, 0x50, 0xC2, 0x0A}, s, 0x3);

    // VRANGESS xmm0, xmm1, xmm2, imm8 (scalar, W=0, opcode=0x51)
    // Only element 0 is computed; elements 1-3 come from xmm1 (src1)
    // imm8=0x01: max, preserve src1 sign
    add_xmm("vrangess: max, src1 sign",
            {0x62, 0xF3, 0x75, 0x08, 0x51, 0xC2, 0x01}, s, 0x3);
    // imm8=0x0A: abs_min, force positive
    add_xmm("vrangess: abs_min, force positive",
            {0x62, 0xF3, 0x75, 0x08, 0x51, 0xC2, 0x0A}, s, 0x3);
  }

  // =====================================================================
  // EVEX VFPCLASSPD/PS — classify float → opmask
  // VFPCLASSPS k1, xmm1, imm8
  // EVEX.128.66.0F3A.W0 66 /r ib
  // P0=0xF3, P1=0x7D(W=0,vvvv=1111b,pp=01), P2=0x08
  // modrm: reg=k1(001), rm=xmm1(001), mod=11 → 0xC9
  // Then: KMOVW eax, k1: C5 F8 93 C1
  // =====================================================================
  cat = "EVEX VFPCLASS";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = {};
    // Set up test values: +0.0, -0.0, +INF, QNAN
    uint32_t pos_zero = 0x00000000;
    uint32_t neg_zero = 0x80000000;
    uint32_t pos_inf  = 0x7F800000;
    uint32_t qnan     = 0x7FC00001;
    s.xmm[1] = xmm_from_u32(pos_zero | (neg_zero << 0),
                              pos_inf, qnan, 0x3F800000);  // +0, +INF, QNAN, 1.0
    // Actually use xmm_from_u32 properly: it takes 4 dwords
    s.xmm[1] = xmm_from_u32(pos_zero, neg_zero, pos_inf, qnan);

    // imm8=0x02: test for +zero (bit 1)
    // elem0=+0→match, elem1=-0→no, elem2=+INF→no, elem3=QNAN→no → k1=0001b=1
    {
      TestCase tc;
      tc.name = "vfpclassps k1,xmm1,0x02: +zero → k1=1";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0x7D, 0x08, 0x66, 0xC9, 0x02,
                 0xC5, 0xF8, 0x93, 0xC1};  // kmovw eax, k1
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // imm8=0x04: test for -zero (bit 2)
    // elem0=+0→no, elem1=-0→match, elem2=+INF→no, elem3=QNAN→no → k1=0010b=2
    {
      TestCase tc;
      tc.name = "vfpclassps k1,xmm1,0x04: -zero → k1=2";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0x7D, 0x08, 0x66, 0xC9, 0x04,
                 0xC5, 0xF8, 0x93, 0xC1};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // imm8=0x08: test for +INF (bit 3)
    // elem2=+INF→match → k1=0100b=4
    {
      TestCase tc;
      tc.name = "vfpclassps k1,xmm1,0x08: +INF → k1=4";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0x7D, 0x08, 0x66, 0xC9, 0x08,
                 0xC5, 0xF8, 0x93, 0xC1};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // imm8=0x01: test for QNAN (bit 0)
    // elem3=QNAN→match → k1=1000b=8
    {
      TestCase tc;
      tc.name = "vfpclassps k1,xmm1,0x01: QNAN → k1=8";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0x7D, 0x08, 0x66, 0xC9, 0x01,
                 0xC5, 0xF8, 0x93, 0xC1};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // imm8=0x06: test for any zero (+zero | -zero, bits 1+2)
    // elem0=+0→match, elem1=-0→match → k1=0011b=3
    {
      TestCase tc;
      tc.name = "vfpclassps k1,xmm1,0x06: any zero → k1=3";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0x7D, 0x08, 0x66, 0xC9, 0x06,
                 0xC5, 0xF8, 0x93, 0xC1};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // Test with negative values and denormals
    uint32_t neg_val   = 0xBF800000;  // -1.0
    uint32_t denorm    = 0x00000001;  // smallest positive denormal
    uint32_t snan      = 0x7F800001;  // SNAN (quiet bit clear)
    uint32_t pos_val   = 0x40000000;  // 2.0
    s.xmm[1] = xmm_from_u32(neg_val, denorm, snan, pos_val);

    // imm8=0x40: test for negative finite (bit 6)
    // elem0=-1.0→match → k1=0001b=1
    {
      TestCase tc;
      tc.name = "vfpclassps k1,xmm1,0x40: neg finite → k1=1";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0x7D, 0x08, 0x66, 0xC9, 0x40,
                 0xC5, 0xF8, 0x93, 0xC1};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // imm8=0x20: test for denormal (bit 5)
    // elem1=denorm→match → k1=0010b=2
    {
      TestCase tc;
      tc.name = "vfpclassps k1,xmm1,0x20: denormal → k1=2";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0x7D, 0x08, 0x66, 0xC9, 0x20,
                 0xC5, 0xF8, 0x93, 0xC1};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // imm8=0x80: test for SNAN (bit 7)
    // elem2=SNAN→match → k1=0100b=4
    {
      TestCase tc;
      tc.name = "vfpclassps k1,xmm1,0x80: SNAN → k1=4";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0x7D, 0x08, 0x66, 0xC9, 0x80,
                 0xC5, 0xF8, 0x93, 0xC1};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // EVEX VGETMANTPS (0F3A 26) — extract normalized mantissa
  // VGETMANTPS xmm0, xmm1, imm8
  // EVEX.128.66.0F3A.W0: P0=0xF3, P1=0x7D(W=0,vvvv=1111b,pp=01), P2=0x08
  // opcode=0x26, modrm=0xC1 (reg=xmm0, rm=xmm1)
  // imm8[1:0]=interval: 0=[1,2), 1=[1/2,2), 2=[1/2,1), 3=[3/4,3/2)
  // imm8[3:2]=sign control: 0=src sign, 1=force+
  // =====================================================================
  cat = "EVEX VGETMANTPS";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = {};
    // Test values: 4.0 (mantissa=1.0), 6.0 (mantissa=1.5), -8.0 (mantissa=1.0), 0.75
    s.xmm[1] = xmm_from_f32(4.0f, 6.0f, -8.0f, 0.75f);

    // imm8=0x00: interval [1,2), preserve src sign
    // 4.0 → 1.0, 6.0 → 1.5, -8.0 → -1.0, 0.75 → 1.5
    add_xmm("vgetmantps: interval [1,2) src sign",
            {0x62, 0xF3, 0x7D, 0x08, 0x26, 0xC1, 0x00}, s, 0x3);
    // imm8=0x04: interval [1,2), force positive (signCtl=01)
    // Same mantissas but all positive
    add_xmm("vgetmantps: interval [1,2) force+",
            {0x62, 0xF3, 0x7D, 0x08, 0x26, 0xC1, 0x04}, s, 0x3);
  }

  // =====================================================================
  // EVEX VCOMPRESS/VEXPAND — compress and expand packed dwords
  // VCOMPRESSPS: EVEX.128.66.0F38.W0 8A /r (reg=src, rm=dst)
  // VEXPANDPS:   EVEX.128.66.0F38.W0 88 /r (reg=dst, rm=src)
  // =====================================================================
  cat = "EVEX compress/expand";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = {};
    s.xmm[1] = xmm_from_u32(0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC, 0xDDDDDDDD);

    // VCOMPRESSPS xmm0, xmm1 (no mask): all 4 elements → contiguous
    // P2=0x08 (aaa=000, no mask)
    // modrm: reg=xmm1(001), rm=xmm0(000), mod=11 → 0xC8
    // Expected: same as src (all elements pass through)
    add_xmm("vcompressps: no mask",
            {0x62, 0xF2, 0x7D, 0x08, 0x8A, 0xC8}, s, 0x3);

    // VCOMPRESSPS xmm0{k1}, xmm1 with k1=0b0101 → elements 0,2 compress to positions 0,1
    // Expected xmm0 = {0xAAAAAAAA, 0xCCCCCCCC, 0, 0}
    add_xmm("vcompressps: k1=0101b",
            {0xB8, 0x05, 0x00, 0x00, 0x00,        // MOV eax, 5
             0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
             0x62, 0xF2, 0x7D, 0x09, 0x8A, 0xC8},  // VCOMPRESSPS xmm0{k1}, xmm1
            s, 0x3);

    // VCOMPRESSPS xmm0{k1}, xmm1 with k1=0b1010 → elements 1,3 compress to positions 0,1
    // Expected xmm0 = {0xBBBBBBBB, 0xDDDDDDDD, 0, 0}
    add_xmm("vcompressps: k1=1010b",
            {0xB8, 0x0A, 0x00, 0x00, 0x00,        // MOV eax, 0xA
             0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
             0x62, 0xF2, 0x7D, 0x09, 0x8A, 0xC8},  // VCOMPRESSPS xmm0{k1}, xmm1
            s, 0x3);

    // VEXPANDPS xmm0{k1}, xmm1 with k1=0b0101 → src[0] → dst[0], src[1] → dst[2]
    // xmm1 = {0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC, 0xDDDDDDDD}
    // Expected xmm0 = {0xAAAAAAAA, 0, 0xBBBBBBBB, 0}
    add_xmm("vexpandps: k1=0101b",
            {0xB8, 0x05, 0x00, 0x00, 0x00,        // MOV eax, 5
             0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
             0x62, 0xF2, 0x7D, 0x09, 0x88, 0xC1},  // VEXPANDPS xmm0{k1}, xmm1
            s, 0x3);

    // VEXPANDPS xmm0{k1}, xmm1 with k1=0b1010 → src[0] → dst[1], src[1] → dst[3]
    // Expected xmm0 = {0, 0xAAAAAAAA, 0, 0xBBBBBBBB}
    add_xmm("vexpandps: k1=1010b",
            {0xB8, 0x0A, 0x00, 0x00, 0x00,        // MOV eax, 0xA
             0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
             0x62, 0xF2, 0x7D, 0x09, 0x88, 0xC1},  // VEXPANDPS xmm0{k1}, xmm1
            s, 0x3);

    // VEXPANDPS ymm0{k1}{z}, ymm1: 256-bit, zero masking
    // EVEX.256.66.0F38.W0 88 /r
    // P2=0xA9 (z=1, L'L=01, aaa=001)
    // k1=0b01010101 → expand src[0..3] into positions 0,2,4,6
    add_xmm("vexpandps ymm: k1=55h",
            {0xB8, 0x55, 0x00, 0x00, 0x00,        // MOV eax, 0x55
             0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
             0x62, 0xF2, 0x7D, 0xA9, 0x88, 0xC1},  // VEXPANDPS ymm0{k1}{z}, ymm1
            s, 0x3);

    // VEXPANDPS zmm0{k1}{z}, zmm1: 512-bit, zero masking
    // EVEX.512.66.0F38.W0 88 /r
    // P2=0xC9 (z=1, L'L=10, aaa=001)
    // k1=0b0000000000000101 → expand src[0..1] into positions 0,2
    add_xmm("vexpandps zmm: k1=0005h",
            {0xB8, 0x05, 0x00, 0x00, 0x00,        // MOV eax, 5
             0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
             0x62, 0xF2, 0x7D, 0xC9, 0x88, 0xC1},  // VEXPANDPS zmm0{k1}{z}, zmm1
            s, 0x3);

    // VEXPANDPD xmm0{k1}{z}, xmm1: 128-bit double, zero masking
    // EVEX.128.66.0F38.W1 88 /r
    // P2=0x89 (z=1, L'L=00, aaa=001)
    // k1=0b01 → expand src[0] into position 0
    add_xmm("vexpandpd xmm: k1=01h",
            {0xB8, 0x01, 0x00, 0x00, 0x00,        // MOV eax, 1
             0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
             0x62, 0xF2, 0xFD, 0x89, 0x88, 0xC1},  // VEXPANDPD xmm0{k1}{z}, xmm1
            s, 0x3);

    // VEXPANDPD xmm0{k1}{z}, xmm1: k1=0b11 → all elements
    add_xmm("vexpandpd xmm: k1=03h",
            {0xB8, 0x03, 0x00, 0x00, 0x00,        // MOV eax, 3
             0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
             0x62, 0xF2, 0xFD, 0x89, 0x88, 0xC1},  // VEXPANDPD xmm0{k1}{z}, xmm1
            s, 0x3);

    // VEXPANDPD ymm0{k1}{z}, ymm1: 256-bit double, zero masking
    // EVEX.256.66.0F38.W1 88 /r
    // P2=0xA9 (z=1, L'L=01, aaa=001)
    // k1=0b0101 → expand src[0..1] into positions 0,2
    add_xmm("vexpandpd ymm: k1=05h",
            {0xB8, 0x05, 0x00, 0x00, 0x00,        // MOV eax, 5
             0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
             0x62, 0xF2, 0xFD, 0xA9, 0x88, 0xC1},  // VEXPANDPD ymm0{k1}{z}, ymm1
            s, 0x3);

    // VEXPANDPD zmm0{k1}{z}, zmm1: 512-bit double, zero masking
    // EVEX.512.66.0F38.W1 88 /r
    // P2=0xC9 (z=1, L'L=10, aaa=001)
    // k1=0b10100101 → expand src[0..3] into positions 0,2,5,7
    add_xmm("vexpandpd zmm: k1=A5h",
            {0xB8, 0xA5, 0x00, 0x00, 0x00,        // MOV eax, 0xA5
             0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
             0x62, 0xF2, 0xFD, 0xC9, 0x88, 0xC1},  // VEXPANDPD zmm0{k1}{z}, zmm1
            s, 0x3);

    // VCOMPRESSPS [rdi]{k1}, xmm1: memory store form, writes only compressed elements
    // EVEX.128.66.0F38.W0 8A /r: reg=xmm1(src), rm=[rdi](dst)
    // modrm: mod=00, reg=001, rm=111 → 0x0F
    // k1=0b0101 → elements 0,2 written contiguously (8 bytes total)
    // xmm1 = {0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC, 0xDDDDDDDD}
    // Expected memory: 0xAAAAAAAA, 0xCCCCCCCC at [rdi]
    {
      ArchState ms = {};
      ms.rflags = 0x2;
      ms.xmm[1] = xmm_from_u32(0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC, 0xDDDDDDDD);
      ms.rdi = DATA_ADDR;
      TestCase tc;
      tc.name = "vcompressps mem: k1=0101b";
      tc.category = cat;
      tc.code = {0xB8, 0x05, 0x00, 0x00, 0x00,        // MOV eax, 5
                 0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
                 0x62, 0xF2, 0x7D, 0x09, 0x8A, 0x0F};  // VCOMPRESSPS [rdi]{k1}, xmm1
      tc.initial = ms;
      tc.flags_mask = FL_NONE;
      tc.init_data = std::vector<u8>(16, 0xFF);  // fill with 0xFF to detect partial writes
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // VCOMPRESSPS [rdi], xmm1: no mask, writes all 4 elements (16 bytes)
    {
      ArchState ms = {};
      ms.rflags = 0x2;
      ms.xmm[1] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      ms.rdi = DATA_ADDR;
      TestCase tc;
      tc.name = "vcompressps mem: no mask";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0x7D, 0x08, 0x8A, 0x0F};  // VCOMPRESSPS [rdi], xmm1
      tc.initial = ms;
      tc.flags_mask = FL_NONE;
      tc.init_data = std::vector<u8>(16, 0);
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // VPCOMPRESSD [rdi]{k1}, xmm1: integer dword compress to memory
    // EVEX.128.66.0F38.W0 8B /r: reg=xmm1(src), rm=[rdi](dst)
    // modrm: mod=00, reg=001, rm=111 → 0x0F
    // k1=0b1010 → elements 1,3 written contiguously
    {
      ArchState ms = {};
      ms.rflags = 0x2;
      ms.xmm[1] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      ms.rdi = DATA_ADDR;
      TestCase tc;
      tc.name = "vpcompressd mem: k1=1010b";
      tc.category = cat;
      tc.code = {0xB8, 0x0A, 0x00, 0x00, 0x00,        // MOV eax, 0xA
                 0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
                 0x62, 0xF2, 0x7D, 0x09, 0x8B, 0x0F};  // VPCOMPRESSD [rdi]{k1}, xmm1
      tc.initial = ms;
      tc.flags_mask = FL_NONE;
      tc.init_data = std::vector<u8>(16, 0xFF);
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // EVEX VPERMI2B — 2-source byte permute with index in dest
  // VPERMI2B xmm0, xmm1, xmm2: EVEX.128.66.0F38.W0 75 /r
  // P0=0xF2, P1=0x75(W=0,vvvv=~1,pp=01), P2=0x08
  // modrm: reg=xmm0(dst/idx), rm=xmm2 → 0xC2
  // =====================================================================
  cat = "EVEX VPERMI2B";
  {
    ArchState s = {};
    s.rflags = 0x2;
    // xmm0 = indices (dst, also acts as index register)
    // Indices: select byte 0 from t1, byte 1 from t2 (idx 16), byte 15 from t1, byte 31 from t2
    s.xmm[0] = xmm_from_u32(
      0x1F0F0100,  // bytes: 0x00, 0x01, 0x0F, 0x1F
      0x10000000,  // bytes: 0x00, 0x00, 0x00, 0x10
      0x00000000,
      0x00000000
    );
    // xmm1 = table 1 (vvvv) — bytes 0-15
    s.xmm[1] = xmm_from_u32(0x04030201, 0x08070605, 0x0C0B0A09, 0x100F0E0D);
    // xmm2 = table 2 (rm) — bytes 16-31
    s.xmm[2] = xmm_from_u32(0x14131211, 0x18171615, 0x1C1B1A19, 0x201F1E1D);

    add_xmm("vpermi2b: byte permute",
            {0x62, 0xF2, 0x75, 0x08, 0x75, 0xC2}, s, 0x3);
  }

  // =====================================================================
  // EVEX VPBLENDMD — mask-controlled dword blend
  // VPBLENDMD xmm0{k1}, xmm2, xmm1: EVEX.128.66.0F38.W0 64 /r
  // P0=0xF2(mmm=010), P1=0x6D(W=0,vvvv=~2,pp=01), P2=0x09(aaa=001)
  // modrm: mod=11,reg=xmm0(000),rm=xmm1(001) → 0xC1
  // =====================================================================
  cat = "EVEX VPBLENDMD";
  {
    ArchState s = {};
    s.rflags = 0x2;
    // dst (xmm0) = sentinel values that should NOT appear in merge result
    s.xmm[0] = xmm_from_u32(0xDEAD0000, 0xDEAD0001, 0xDEAD0002, 0xDEAD0003);
    // SRC2 (xmm1)
    s.xmm[1] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
    // SRC1/vvvv (xmm2)
    s.xmm[2] = xmm_from_u32(0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC, 0xDDDDDDDD);

    // No mask (aaa=0): all elements from SRC2
    // P2=0x08 (z=0,LL=00,b=0,V'=1,aaa=000)
    // Expected: {0x11111111, 0x22222222, 0x33333333, 0x44444444}
    add_xmm("vpblendmd: no mask (all SRC2)",
            {0x62, 0xF2, 0x6D, 0x08, 0x64, 0xC1}, s, 0x3);

    // Merge masking: k1=0x5 (0101b) → elem 0,2 from SRC2, elem 1,3 from SRC1
    // MOV eax, 5; KMOVW k1, eax; VPBLENDMD xmm0{k1}, xmm2, xmm1
    // Expected: {0x11111111, 0xBBBBBBBB, 0x33333333, 0xDDDDDDDD}
    add_xmm("vpblendmd: merge mask k1=0101b",
            {0xB8, 0x05, 0x00, 0x00, 0x00,        // MOV eax, 5
             0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
             0x62, 0xF2, 0x6D, 0x09, 0x64, 0xC1},  // VPBLENDMD xmm0{k1}, xmm2, xmm1
            s, 0x3);

    // Zero masking: k1=0x5 (0101b), z=1 → elem 0,2 from SRC2, elem 1,3 = 0
    // P2=0x89 (z=1,LL=00,b=0,V'=1,aaa=001)
    // Expected: {0x11111111, 0x00000000, 0x33333333, 0x00000000}
    add_xmm("vpblendmd: zero mask k1=0101b",
            {0xB8, 0x05, 0x00, 0x00, 0x00,        // MOV eax, 5
             0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
             0x62, 0xF2, 0x6D, 0x89, 0x64, 0xC1},  // VPBLENDMD xmm0{k1}{z}, xmm2, xmm1
            s, 0x3);

    // Merge masking: k1=0xA (1010b) → elem 1,3 from SRC2, elem 0,2 from SRC1
    // Expected: {0xAAAAAAAA, 0x22222222, 0xCCCCCCCC, 0x44444444}
    add_xmm("vpblendmd: merge mask k1=1010b",
            {0xB8, 0x0A, 0x00, 0x00, 0x00,        // MOV eax, 0xA
             0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
             0x62, 0xF2, 0x6D, 0x09, 0x64, 0xC1},  // VPBLENDMD xmm0{k1}, xmm2, xmm1
            s, 0x3);

    // All-zeros mask: k1=0x0 → all elements from SRC1
    // Expected: {0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC, 0xDDDDDDDD}
    add_xmm("vpblendmd: merge mask k1=0000b",
            {0xB8, 0x00, 0x00, 0x00, 0x00,        // MOV eax, 0
             0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
             0x62, 0xF2, 0x6D, 0x09, 0x64, 0xC1},  // VPBLENDMD xmm0{k1}, xmm2, xmm1
            s, 0x3);
  }

  // =====================================================================
  // EVEX VPALIGNR — byte-granularity concatenate + shift right
  // EVEX.128.66.0F3A.WIG 0F /r ib
  // P0: R=1,X=1,B=1,R'=1,mmm=011 → 0xF3
  // P1: W=0,~vvvv=1110(xmm1),1,pp=01 → 0x7D
  // P2: z=0,LL=00,b=0,V'=1,aaa=000 → 0x08
  // modrm: mod=11, reg=000(dst), rm=010(xmm2) → 0xC2
  // =====================================================================
  cat = "EVEX VPALIGNR";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    ArchState s = {};
    s.rflags = 0x2;
    // xmm1 = high part, xmm2 = low part in (xmm1:xmm2) >> shift
    s.xmm[1] = xmm_from_u32(0x04030201, 0x08070605, 0x0C0B0A09, 0x100F0E0D);
    s.xmm[2] = xmm_from_u32(0x14131211, 0x18171615, 0x1C1B1A19, 0x201F1E1D);

    // VPALIGNR xmm0, xmm1, xmm2, 4: shift right by 4 bytes
    // Concat xmm1:xmm2 = 256 bits, shift right 4 bytes, take low 128 bits
    add_xmm("vpalignr xmm0,xmm1,xmm2,4",
            {0x62, 0xF3, 0x75, 0x08, 0x0F, 0xC2, 0x04}, s, 0x7);

    // VPALIGNR xmm0, xmm1, xmm2, 0: no shift (result = xmm2)
    add_xmm("vpalignr xmm0,xmm1,xmm2,0",
            {0x62, 0xF3, 0x75, 0x08, 0x0F, 0xC2, 0x00}, s, 0x7);

    // VPALIGNR xmm0, xmm1, xmm2, 16: shift right 16 bytes (result = xmm1)
    add_xmm("vpalignr xmm0,xmm1,xmm2,16",
            {0x62, 0xF3, 0x75, 0x08, 0x0F, 0xC2, 0x10}, s, 0x7);

    // VPALIGNR xmm0, xmm1, xmm2, 32: shift right 32 bytes (result = 0)
    add_xmm("vpalignr xmm0,xmm1,xmm2,32",
            {0x62, 0xF3, 0x75, 0x08, 0x0F, 0xC2, 0x20}, s, 0x7);
  }

  // =====================================================================
  // EVEX VPEXTRB/VPEXTRD/VPEXTRQ — extract to GPR/memory
  // VPEXTRB: EVEX.128.66.0F3A.WIG 14 /r ib (src=reg, dst=r/m)
  // VPEXTRD: EVEX.128.66.0F3A.W0  16 /r ib
  // VPEXTRQ: EVEX.128.66.0F3A.W1  16 /r ib
  // =====================================================================
  cat = "EVEX VPEXTR";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u32(0xAABBCCDD, 0x11223344, 0x55667788, 0x99AABBCC);
    s.rdi = DATA_ADDR;

    // VPEXTRB [rdi], xmm1, 0: extract byte 0 to memory
    // P0=0xF3(mmm=011), P1=0x7D(W=0,vvvv=1111,pp=01), P2=0x08
    // modrm: mod=00, reg=001(xmm1), rm=111(rdi) → 0x0F
    {
      TestCase tc;
      tc.name = "vpextrb [rdi],xmm1,0";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0x7D, 0x08, 0x14, 0x0F, 0x00};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.init_data = std::vector<u8>(8, 0xFF);
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }

    // VPEXTRB [rdi], xmm1, 5: extract byte 5
    {
      TestCase tc;
      tc.name = "vpextrb [rdi],xmm1,5";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0x7D, 0x08, 0x14, 0x0F, 0x05};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.init_data = std::vector<u8>(8, 0xFF);
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }

    // VPEXTRD [rdi], xmm1, 2: extract dword 2 to memory
    // EVEX.128.66.0F3A.W0 16: reg=xmm1(001), rm=[rdi](111) → modrm=0x0F
    {
      TestCase tc;
      tc.name = "vpextrd [rdi],xmm1,2";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0x7D, 0x08, 0x16, 0x0F, 0x02};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.init_data = std::vector<u8>(8, 0xFF);
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }

    // VPEXTRQ [rdi], xmm1, 1: extract qword 1 to memory
    // EVEX.128.66.0F3A.W1 16: P1 needs W=1 → 0xFD
    {
      TestCase tc;
      tc.name = "vpextrq [rdi],xmm1,1";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0xFD, 0x08, 0x16, 0x0F, 0x01};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.init_data = std::vector<u8>(16, 0xFF);
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // VPEXTRD to register: xmm1 dword 0 → eax
    // modrm: mod=11, reg=001(xmm1), rm=000(eax) → 0xC8
    {
      ArchState rs = s;
      rs.rax = 0;
      tests.push_back({"vpextrd eax,xmm1,0", cat,
        {0x62, 0xF3, 0x7D, 0x08, 0x16, 0xC8, 0x00},
        rs, FL_NONE, 0, false});
    }
  }

  // =====================================================================
  // EVEX VPSRAQ — arithmetic right shift qwords (AVX-512 new)
  // VPSRAQ: EVEX.128.66.0F.W1 72 /4 ib
  // =====================================================================
  cat = "EVEX VPSRAQ";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    ArchState s = {};
    s.rflags = 0x2;
    // xmm1: two qwords: one positive (0x7000000000000001), one negative (0x8000000000000004)
    s.xmm[1] = xmm_from_u64(0x8000000000000004, 0x7000000000000001);

    // VPSRAQ xmm0, xmm1, 4: arithmetic right shift by 4
    // P0=0xF1, P1=0xFD(W=1,vvvv=~0=1111,pp=01), P2=0x08
    // modrm: mod=11, reg=100(/4), rm=001(xmm1) → 0xE1
    // Expected: low qword → 0x0700000000000000, high qword → 0xF800000000000000
    add_xmm("vpsraq xmm0,xmm1,4",
            {0x62, 0xF1, 0xFD, 0x08, 0x72, 0xE1, 0x04}, s, 0x3);

    // VPSRAQ xmm0, xmm1, 63: shift right by 63 (should leave sign bit only)
    // Expected: low qword → 0x0, high qword → 0xFFFFFFFFFFFFFFFF
    add_xmm("vpsraq xmm0,xmm1,63",
            {0x62, 0xF1, 0xFD, 0x08, 0x72, 0xE1, 0x3F}, s, 0x3);

    // VPSRAQ xmm0, xmm1, 0: no shift
    add_xmm("vpsraq xmm0,xmm1,0",
            {0x62, 0xF1, 0xFD, 0x08, 0x72, 0xE1, 0x00}, s, 0x3);

    // Test VPSRAQ by xmm count: EVEX.128.66.0F.W1 E2 /r
    // VPSRAQ xmm0, xmm1, xmm2 where xmm2 low qword = shift count
    // P0=0xF1, P1=0xF5(W=1,vvvv=~1=1110,pp=01), P2=0x08
    // modrm: mod=11, reg=000(dst), rm=010(xmm2) → 0xC2
    {
      ArchState ss = s;
      ss.xmm[2] = xmm_from_u64(0, 8);  // shift count = 8 (low qword only matters)
      add_xmm("vpsraq xmm0,xmm1,xmm2 (count=8)",
              {0x62, 0xF1, 0xF5, 0x08, 0xE2, 0xC2}, ss, 0x7);
    }
  }

  // =====================================================================
  // EVEX VPINSRB/VPINSRD/VPINSRQ — insert from GPR/memory
  // VPINSRB: EVEX.128.66.0F3A.WIG 20 /r ib
  // VPINSRD: EVEX.128.66.0F3A.W0  22 /r ib
  // =====================================================================
  cat = "EVEX VPINSR";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
    s.rax = 0xDEADBEEF;

    // VPINSRD xmm0, xmm1, eax, 2: insert eax into dword 2
    // EVEX.128.66.0F3A.W0 22: P0=0xF3, P1=0x75(vvvv=~1), P2=0x08
    // modrm: mod=11, reg=000(dst), rm=000(eax) → 0xC0
    add_xmm("vpinsrd xmm0,xmm1,eax,2",
            {0x62, 0xF3, 0x75, 0x08, 0x22, 0xC0, 0x02}, s, 0x3);

    // VPINSRD xmm0, xmm1, eax, 0: insert eax into dword 0
    add_xmm("vpinsrd xmm0,xmm1,eax,0",
            {0x62, 0xF3, 0x75, 0x08, 0x22, 0xC0, 0x00}, s, 0x3);

    // VPINSRB xmm0, xmm1, eax, 3: insert low byte of eax into byte 3
    // EVEX.128.66.0F3A.WIG 20: P0=0xF3, P1=0x75, P2=0x08
    // modrm: mod=11, reg=000(dst), rm=000(eax) → 0xC0
    add_xmm("vpinsrb xmm0,xmm1,eax,3",
            {0x62, 0xF3, 0x75, 0x08, 0x20, 0xC0, 0x03}, s, 0x3);
  }

  // =====================================================================
  // VPCOMPRESSB / VPEXPANDB (EVEX.66.0F38.W0 63/62)
  // =====================================================================
  cat = "EVEX VPCOMPRESSB/W";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };
    // Source xmm1 = bytes 0x00,0x11,0x22,...,0xFF
    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0F0E0D0C0B0A0908ULL, 0x0706050403020100ULL);
    s.xmm[0] = {};  // clear dest

    // VPCOMPRESSB xmm0, xmm1, no mask (k0): all 16 bytes written
    // EVEX.128.66.0F38.W0 63: P0=62, P1=F2, P2=7D(W0,vvvv=1111,pp=01), P3=08
    // modrm: mod=11, reg=001(src=xmm1), rm=000(dst=xmm0) → 0xC8
    add_xmm("vpcompressb xmm0,xmm1 no mask",
            {0x62, 0xF2, 0x7D, 0x08, 0x63, 0xC8}, s, 0x3);

    // VPCOMPRESSB xmm0, xmm1, k1=0xAAAA (even bits 0, odd bits 1)
    // mask=1010_1010_1010_1010 → compress bytes 1,3,5,7,9,11,13,15
    // P3: z=0, L'L=00, b=0, V'=1, aaa=001(k1) → 0x09
    {
      ArchState sk = s;
      sk.kregs[1] = 0xAAAA;
      add_xmm("vpcompressb xmm0,xmm1 k1=0xAAAA",
              {0x62, 0xF2, 0x7D, 0x09, 0x63, 0xC8}, sk, 0x3);
    }

    // VPCOMPRESSB xmm0, xmm1, k1=0x000F (first 4 bits set)
    // compress bytes 0,1,2,3 → result: 0x00,0x01,0x02,0x03,0,0,...
    {
      ArchState sk = s;
      sk.kregs[1] = 0x000F;
      add_xmm("vpcompressb xmm0,xmm1 k1=0x000F",
              {0x62, 0xF2, 0x7D, 0x09, 0x63, 0xC8}, sk, 0x3);
    }

    // VPEXPANDB xmm0, xmm1, k1=0xAAAA
    // Expand: for each dest byte j where k1[j]=1, copy src[k++]
    // mask=1010_1010_1010_1010 → 8 active positions at 1,3,5,7,9,11,13,15
    // modrm: mod=11, reg=000(dst=xmm0), rm=001(src=xmm1) → 0xC1
    {
      ArchState sk = s;
      sk.kregs[1] = 0xAAAA;
      add_xmm("vpexpandb xmm0,xmm1 k1=0xAAAA",
              {0x62, 0xF2, 0x7D, 0x09, 0x62, 0xC1}, sk, 0x3);
    }

    // VPEXPANDB xmm0, xmm1, no mask: should be identity
    // modrm: mod=11, reg=000(dst=xmm0), rm=001(src=xmm1) → 0xC1
    add_xmm("vpexpandb xmm0,xmm1 no mask",
            {0x62, 0xF2, 0x7D, 0x08, 0x62, 0xC1}, s, 0x3);

    // VPCOMPRESSW xmm0, xmm1, k1=0x05 (words 0,2 active)
    // EVEX.128.66.0F38.W1 63: W1 → P2=0xFD
    {
      ArchState sk = s;
      sk.kregs[1] = 0x05;
      add_xmm("vpcompressw xmm0,xmm1 k1=0x05",
              {0x62, 0xF2, 0xFD, 0x09, 0x63, 0xC8}, sk, 0x3);
    }

    // VPCOMPRESSB to memory: xmm1 → [rdi], k1=0x0F0F
    // compress bytes 0-3 and 8-11 → 8 bytes written
    {
      ArchState sk = s;
      sk.kregs[1] = 0x0F0F;
      sk.rdi = DATA_ADDR;
      TestCase tc = {"vpcompressb [rdi],xmm1 k1=0x0F0F", cat,
                     {0x62, 0xF2, 0x7D, 0x09, 0x63, 0x0F}, sk,
                     FL_NONE, 0x0, false};
      tc.init_data = std::vector<u8>(64, 0xCC);
      tc.compare_data_len = 16;
      tests.push_back(tc);
    }

    // VPEXPANDW xmm0, xmm1, k1=0x0A (words 1,3 active)
    // expand: dest[1]=src[0], dest[3]=src[1], others=0
    // EVEX.128.66.0F38.W1 62: P2=0xFD
    // modrm: mod=11, reg=000(dst=xmm0), rm=001(src=xmm1) → 0xC1
    {
      ArchState sk = s;
      sk.kregs[1] = 0x0A;
      add_xmm("vpexpandw xmm0,xmm1 k1=0x0A",
              {0x62, 0xF2, 0xFD, 0x09, 0x62, 0xC1}, sk, 0x3);
    }
  }

  // =====================================================================
  // EVEX VXORPS/VANDPS/VORPS/VANDNPS (EVEX.0F 54-57)
  // =====================================================================
  cat = "EVEX FP logical";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0xFFFFFFFF00000000ULL, 0x0000FFFF0000FFFFULL);
    s.xmm[2] = xmm_from_u64(0x1234567890ABCDEFULL, 0xFEDCBA9876543210ULL);

    // EVEX.128.0F.W0 57 /r: VXORPS xmm0{k0}, xmm1, xmm2
    // P0=62, P1=F1(R̄=1,X̄=1,B̄=1,R̄'=1,mmm=001), P2=74(W=0,vvvv=~1=1110,pp=00=NP)
    // Wait — VXORPS uses NP (no mandatory prefix), not 66.
    // P2: W=0, vvvv=1110(~1), 1, pp=00(NP) = 0.1110.1.00 = 0x74
    // P3: z=0, L'L=00, b=0, V'=1, aaa=000 = 0x08
    // modrm: mod=11, reg=000(dst=xmm0), rm=010(src2=xmm2) → 0xC2
    add_xmm("vxorps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x57, 0xC2}, s, 0x7);

    // EVEX.128.0F.W0 54 /r: VANDPS xmm0{k0}, xmm1, xmm2
    add_xmm("vandps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x54, 0xC2}, s, 0x7);

    // EVEX.128.0F.W0 56 /r: VORPS xmm0{k0}, xmm1, xmm2
    add_xmm("vorps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x56, 0xC2}, s, 0x7);

    // EVEX.128.0F.W0 55 /r: VANDNPS xmm0{k0}, xmm1, xmm2 — NOT(src1) AND src2
    add_xmm("vandnps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x55, 0xC2}, s, 0x7);

    // EVEX.128.66.0F.W1 57 /r: VXORPD xmm0{k0}, xmm1, xmm2
    // P1=F1(mmm=001), P2=F5(W=1,vvvv=1110,pp=01(66))
    // W=1 → 0xF5 = 1.1110.1.01
    add_xmm("vxorpd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0x57, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // EVEX BW-class integer: VPADDB/W, VPSUBB/W, VPANDND/Q, VPACKSSWB,
  // VPACKUSWB, VPAVGB/W, VPMADDWD, VPSADBW, saturating add/sub
  // All use EVEX.128.66.0F encoding, reg-reg xmm0←xmm1,xmm2
  // P0=0xF1(mmm=001), P1=0x75(W=0,vvvv=~1,pp=01), P2=0x08(no mask)
  // modrm=0xC2(mod=11,reg=000,rm=010)
  // =====================================================================
  cat = "EVEX BW int";
  {
    ArchState s = {};
    s.rflags = 0x2;
    // xmm1: byte pattern 0x01..0x10
    s.xmm[1] = {0x0807060504030201, 0x100F0E0D0C0B0A09};
    // xmm2: byte pattern 0x10,0x20,...
    s.xmm[2] = {0x8070605040302010, 0x00F0E0D0C0B0A090};

    // EVEX VPADDB xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG FC /r
    add_xmm("evex vpaddb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xFC, 0xC2}, s, 0x7);

    // EVEX VPADDW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG FD /r
    add_xmm("evex vpaddw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xFD, 0xC2}, s, 0x7);

    // EVEX VPSUBB xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG F8 /r
    add_xmm("evex vpsubb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xF8, 0xC2}, s, 0x7);

    // EVEX VPSUBW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG F9 /r
    add_xmm("evex vpsubw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xF9, 0xC2}, s, 0x7);

    // EVEX VPANDND xmm0, xmm1, xmm2: EVEX.128.66.0F.W0 DF /r
    add_xmm("evex vpandnd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xDF, 0xC2}, s, 0x7);

    // EVEX VPANDNQ xmm0, xmm1, xmm2: EVEX.128.66.0F.W1 DF /r
    // P1=0xF5 (W=1,vvvv=1110,pp=01)
    add_xmm("evex vpandnq xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0xDF, 0xC2}, s, 0x7);

    // EVEX VPACKSSWB xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG 63 /r
    add_xmm("evex vpacksswb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0x63, 0xC2}, s, 0x7);

    // EVEX VPACKUSWB xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG 67 /r
    add_xmm("evex vpackuswb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0x67, 0xC2}, s, 0x7);

    // EVEX VPAVGB xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG E0 /r
    add_xmm("evex vpavgb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xE0, 0xC2}, s, 0x7);

    // EVEX VPAVGW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG E3 /r
    add_xmm("evex vpavgw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xE3, 0xC2}, s, 0x7);

    // EVEX VPMADDWD xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG F5 /r
    add_xmm("evex vpmaddwd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xF5, 0xC2}, s, 0x7);

    // EVEX VPSADBW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG F6 /r
    add_xmm("evex vpsadbw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xF6, 0xC2}, s, 0x7);

    // Saturating arithmetic
    // EVEX VPADDSB xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG EC /r
    add_xmm("evex vpaddsb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xEC, 0xC2}, s, 0x7);

    // EVEX VPADDSW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG ED /r
    add_xmm("evex vpaddsw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xED, 0xC2}, s, 0x7);

    // EVEX VPADDUSB xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG DC /r
    add_xmm("evex vpaddusb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xDC, 0xC2}, s, 0x7);

    // EVEX VPADDUSW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG DD /r
    add_xmm("evex vpaddusw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xDD, 0xC2}, s, 0x7);

    // EVEX VPSUBSB xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG E8 /r
    add_xmm("evex vpsubsb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xE8, 0xC2}, s, 0x7);

    // EVEX VPSUBSW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG E9 /r
    add_xmm("evex vpsubsw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xE9, 0xC2}, s, 0x7);

    // EVEX VPSUBUSB xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG D8 /r
    add_xmm("evex vpsubusb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xD8, 0xC2}, s, 0x7);

    // EVEX VPSUBUSW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG D9 /r
    add_xmm("evex vpsubusw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xD9, 0xC2}, s, 0x7);

    // EVEX VPMULLW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG D5 /r
    add_xmm("evex vpmullw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xD5, 0xC2}, s, 0x7);

    // EVEX VPMULHW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG E5 /r
    add_xmm("evex vpmulhw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xE5, 0xC2}, s, 0x7);

    // EVEX VPMULHUW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG E4 /r
    add_xmm("evex vpmulhuw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xE4, 0xC2}, s, 0x7);

    // EVEX VPMULUDQ xmm0, xmm1, xmm2: EVEX.128.66.0F.W1 F4 /r
    // W=1 → P1=0xF5
    add_xmm("evex vpmuludq xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0xF4, 0xC2}, s, 0x7);

    // Unpack/interleave
    // EVEX VPUNPCKLBW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG 60 /r
    add_xmm("evex vpunpcklbw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0x60, 0xC2}, s, 0x7);

    // EVEX VPUNPCKHBW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG 68 /r
    add_xmm("evex vpunpckhbw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0x68, 0xC2}, s, 0x7);

    // EVEX VPUNPCKLWD xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG 61 /r
    add_xmm("evex vpunpcklwd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0x61, 0xC2}, s, 0x7);

    // EVEX VPUNPCKHWD xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG 69 /r
    add_xmm("evex vpunpckhwd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0x69, 0xC2}, s, 0x7);

    // Min/max byte/word
    // EVEX VPMINUB xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG DA /r
    add_xmm("evex vpminub xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xDA, 0xC2}, s, 0x7);

    // EVEX VPMINSW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG EA /r
    add_xmm("evex vpminsw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xEA, 0xC2}, s, 0x7);

    // EVEX VPMAXUB xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG DE /r
    add_xmm("evex vpmaxub xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xDE, 0xC2}, s, 0x7);

    // EVEX VPMAXSW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG EE /r
    add_xmm("evex vpmaxsw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xEE, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // EVEX shift-by-immediate (Group 12/13/14)
  // Encoding: dst=vvvv, src=ModRM.rm, /digit=ModRM.reg
  // P0=0xF1(mmm=001), P1=0x7D(W=0,vvvv=~0=1111,pp=01), P2=0x08
  // modrm: mod=11, reg=/digit, rm=001(xmm1)
  // =====================================================================
  cat = "EVEX shift imm";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = {0x8000400020001000, 0xFF00800040002000};

    // VPSRLW xmm0, xmm1, 4: EVEX.128.66.0F 71 /2 ib
    // modrm: mod=11, reg=010(/2), rm=001 → 0xD1
    add_xmm("evex vpsrlw xmm0,xmm1,4",
            {0x62, 0xF1, 0x7D, 0x08, 0x71, 0xD1, 0x04}, s, 0x7);

    // VPSRAW xmm0, xmm1, 4: EVEX.128.66.0F 71 /4 ib
    // modrm: mod=11, reg=100(/4), rm=001 → 0xE1
    add_xmm("evex vpsraw xmm0,xmm1,4",
            {0x62, 0xF1, 0x7D, 0x08, 0x71, 0xE1, 0x04}, s, 0x7);

    // VPSLLW xmm0, xmm1, 4: EVEX.128.66.0F 71 /6 ib
    // modrm: mod=11, reg=110(/6), rm=001 → 0xF1
    add_xmm("evex vpsllw xmm0,xmm1,4",
            {0x62, 0xF1, 0x7D, 0x08, 0x71, 0xF1, 0x04}, s, 0x7);

    // VPSRLD xmm0, xmm1, 4: EVEX.128.66.0F.W0 72 /2 ib
    // modrm: mod=11, reg=010(/2), rm=001 → 0xD1
    add_xmm("evex vpsrld xmm0,xmm1,4",
            {0x62, 0xF1, 0x7D, 0x08, 0x72, 0xD1, 0x04}, s, 0x7);

    // VPSRAD xmm0, xmm1, 4: EVEX.128.66.0F.W0 72 /4 ib
    add_xmm("evex vpsrad xmm0,xmm1,4",
            {0x62, 0xF1, 0x7D, 0x08, 0x72, 0xE1, 0x04}, s, 0x7);

    // VPSLLD xmm0, xmm1, 4: EVEX.128.66.0F.W0 72 /6 ib
    add_xmm("evex vpslld xmm0,xmm1,4",
            {0x62, 0xF1, 0x7D, 0x08, 0x72, 0xF1, 0x04}, s, 0x7);

    // VPSRLQ xmm0, xmm1, 4: EVEX.128.66.0F.W1 73 /2 ib
    // P1=0xFD(W=1,vvvv=1111,pp=01)
    // modrm: mod=11, reg=010(/2), rm=001 → 0xD1
    add_xmm("evex vpsrlq xmm0,xmm1,4",
            {0x62, 0xF1, 0xFD, 0x08, 0x73, 0xD1, 0x04}, s, 0x7);

    // VPSRAQ xmm0, xmm1, 4: EVEX.128.66.0F.W1 72 /4 ib
    add_xmm("evex vpsraq xmm0,xmm1,4",
            {0x62, 0xF1, 0xFD, 0x08, 0x72, 0xE1, 0x04}, s, 0x7);

    // VPSLLQ xmm0, xmm1, 4: EVEX.128.66.0F.W1 73 /6 ib
    add_xmm("evex vpsllq xmm0,xmm1,4",
            {0x62, 0xF1, 0xFD, 0x08, 0x73, 0xF1, 0x04}, s, 0x7);

    // VPROLD xmm0, xmm1, 7: EVEX.128.66.0F.W0 72 /1 ib
    // modrm: mod=11, reg=001(/1), rm=001 → 0xC9
    add_xmm("evex vprold xmm0,xmm1,7",
            {0x62, 0xF1, 0x7D, 0x08, 0x72, 0xC9, 0x07}, s, 0x7);

    // VPRORD xmm0, xmm1, 7: EVEX.128.66.0F.W0 72 /0 ib
    // modrm: mod=11, reg=000(/0), rm=001 → 0xC1
    add_xmm("evex vprord xmm0,xmm1,7",
            {0x62, 0xF1, 0x7D, 0x08, 0x72, 0xC1, 0x07}, s, 0x7);

    // VPROLQ xmm0, xmm1, 7: EVEX.128.66.0F.W1 72 /1 ib
    add_xmm("evex vprolq xmm0,xmm1,7",
            {0x62, 0xF1, 0xFD, 0x08, 0x72, 0xC9, 0x07}, s, 0x7);

    // VPRORQ xmm0, xmm1, 7: EVEX.128.66.0F.W1 72 /0 ib
    add_xmm("evex vprorq xmm0,xmm1,7",
            {0x62, 0xF1, 0xFD, 0x08, 0x72, 0xC1, 0x07}, s, 0x7);
  }

  // =====================================================================
  // EVEX 0F38 integer: abs, min/max signed, sign/zero extend
  // P0=0xF2(mmm=010), P2=0x08
  // 2-operand: P1=0x7D(W=0,vvvv=1111,pp=01), modrm=0xC1(dst=xmm0,src=xmm1)
  // 3-operand: P1=0x75(W=0,vvvv=~1=1110,pp=01), modrm=0xC2(dst=xmm0,src=xmm2)
  // =====================================================================
  cat = "EVEX 0F38 int";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = {0x80FE0102FF030405, 0x7F00FFFE00010003};
    s.xmm[2] = {0x81FF0201FE040503, 0x7E01FFFD00020004};

    // VPABSB xmm0, xmm1: EVEX.128.66.0F38.WIG 1C /r
    add_xmm("evex vpabsb xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x1C, 0xC1}, s, 0x7);

    // VPABSW xmm0, xmm1: EVEX.128.66.0F38.WIG 1D /r
    add_xmm("evex vpabsw xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x1D, 0xC1}, s, 0x7);

    // VPABSD xmm0, xmm1: EVEX.128.66.0F38.W0 1E /r
    add_xmm("evex vpabsd xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x1E, 0xC1}, s, 0x7);

    // VPMINSB xmm0, xmm1, xmm2: EVEX.128.66.0F38.WIG 38 /r
    add_xmm("evex vpminsb xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x38, 0xC2}, s, 0x7);

    // VPMINSD xmm0, xmm1, xmm2: EVEX.128.66.0F38.W0 39 /r
    add_xmm("evex vpminsd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x39, 0xC2}, s, 0x7);

    // VPMAXSB xmm0, xmm1, xmm2: EVEX.128.66.0F38.WIG 3C /r
    add_xmm("evex vpmaxsb xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x3C, 0xC2}, s, 0x7);

    // VPMAXSD xmm0, xmm1, xmm2: EVEX.128.66.0F38.W0 3D /r
    add_xmm("evex vpmaxsd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x3D, 0xC2}, s, 0x7);

    // VPMINUD xmm0, xmm1, xmm2: EVEX.128.66.0F38.W0 3B /r
    add_xmm("evex vpminud xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x3B, 0xC2}, s, 0x7);

    // VPMAXUD xmm0, xmm1, xmm2: EVEX.128.66.0F38.W0 3F /r
    add_xmm("evex vpmaxud xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x3F, 0xC2}, s, 0x7);

    // Sign-extend
    // VPMOVSXBW xmm0, xmm1: EVEX.128.66.0F38.WIG 20 /r
    add_xmm("evex vpmovsxbw xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x20, 0xC1}, s, 0x7);

    // VPMOVSXBD xmm0, xmm1: EVEX.128.66.0F38.WIG 21 /r
    add_xmm("evex vpmovsxbd xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x21, 0xC1}, s, 0x7);

    // VPMOVSXBQ xmm0, xmm1: EVEX.128.66.0F38.WIG 22 /r
    add_xmm("evex vpmovsxbq xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x22, 0xC1}, s, 0x7);

    // VPMOVSXWD xmm0, xmm1: EVEX.128.66.0F38.WIG 23 /r
    add_xmm("evex vpmovsxwd xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x23, 0xC1}, s, 0x7);

    // VPMOVSXWQ xmm0, xmm1: EVEX.128.66.0F38.WIG 24 /r
    add_xmm("evex vpmovsxwq xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x24, 0xC1}, s, 0x7);

    // VPMOVSXDQ xmm0, xmm1: EVEX.128.66.0F38.W0 25 /r
    add_xmm("evex vpmovsxdq xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x25, 0xC1}, s, 0x7);

    // Zero-extend
    // VPMOVZXBW xmm0, xmm1: EVEX.128.66.0F38.WIG 30 /r
    add_xmm("evex vpmovzxbw xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x30, 0xC1}, s, 0x7);

    // VPMOVZXBD xmm0, xmm1: EVEX.128.66.0F38.WIG 31 /r
    add_xmm("evex vpmovzxbd xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x31, 0xC1}, s, 0x7);

    // VPMOVZXBQ xmm0, xmm1: EVEX.128.66.0F38.WIG 32 /r
    add_xmm("evex vpmovzxbq xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x32, 0xC1}, s, 0x7);

    // VPMOVZXWD xmm0, xmm1: EVEX.128.66.0F38.WIG 33 /r
    add_xmm("evex vpmovzxwd xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x33, 0xC1}, s, 0x7);

    // VPMOVZXWQ xmm0, xmm1: EVEX.128.66.0F38.WIG 34 /r
    add_xmm("evex vpmovzxwq xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x34, 0xC1}, s, 0x7);

    // VPMOVZXDQ xmm0, xmm1: EVEX.128.66.0F38.W0 35 /r
    add_xmm("evex vpmovzxdq xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x35, 0xC1}, s, 0x7);

    // VPMULDQ xmm0, xmm1, xmm2: EVEX.128.66.0F38.W1 28 /r
    // P1=0xF5(W=1,vvvv=1110,pp=01)
    add_xmm("evex vpmuldq xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0xF5, 0x08, 0x28, 0xC2}, s, 0x7);

    // VPMULLD xmm0, xmm1, xmm2: EVEX.128.66.0F38.W0 40 /r
    add_xmm("evex vpmulld xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x40, 0xC2}, s, 0x7);

    // VPACKUSDW xmm0, xmm1, xmm2: EVEX.128.66.0F38.W0 2B /r
    add_xmm("evex vpackusdw xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x2B, 0xC2}, s, 0x7);

    // VPMADDUBSW xmm0, xmm1, xmm2: EVEX.128.66.0F38.WIG 04 /r
    add_xmm("evex vpmaddubsw xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x04, 0xC2}, s, 0x7);

    // VPMULHRSW xmm0, xmm1, xmm2: EVEX.128.66.0F38.WIG 0B /r
    add_xmm("evex vpmulhrsw xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x0B, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // EVEX FMA packed (all 3 orderings, PS and PD)
  // EVEX.128.66.0F38, modrm=0xC2(dst=xmm0,src3=xmm2)
  // P0=0xF2(mmm=010)
  // PS: P1=0x75(W=0,vvvv=~1,pp=01) — src2=xmm1
  // PD: P1=0xF5(W=1,vvvv=~1,pp=01) — src2=xmm1
  // P2=0x08(no mask)
  // =====================================================================
  cat = "EVEX FMA packed";
  {
    ArchState s = {};
    s.rflags = 0x2;
    // Use simple float values for predictable FMA results
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);
    s.xmm[2] = xmm_from_f32(9.0f, 10.0f, 11.0f, 12.0f);

    // VFMADD132PS xmm0,xmm1,xmm2: dst = dst*src3 + src2 = xmm0*xmm2 + xmm1
    add_xmm("evex vfmadd132ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x98, 0xC2}, s, 0x7);

    // VFMADD213PS xmm0,xmm1,xmm2: dst = src2*dst + src3 = xmm1*xmm0 + xmm2
    add_xmm("evex vfmadd213ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xA8, 0xC2}, s, 0x7);

    // VFMADD231PS xmm0,xmm1,xmm2: dst = src2*src3 + dst = xmm1*xmm2 + xmm0
    add_xmm("evex vfmadd231ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xB8, 0xC2}, s, 0x7);

    // VFMSUB132PS: dst = dst*src3 - src2 = xmm0*xmm2 - xmm1
    add_xmm("evex vfmsub132ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x9A, 0xC2}, s, 0x7);

    // VFNMADD213PS: dst = -(src2*dst) + src3 = -(xmm1*xmm0) + xmm2
    add_xmm("evex vfnmadd213ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xAC, 0xC2}, s, 0x7);

    // VFNMSUB231PS: dst = -(src2*src3) - dst = -(xmm1*xmm2) - xmm0
    add_xmm("evex vfnmsub231ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xBE, 0xC2}, s, 0x7);

    // PD variants (W=1)
    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(1.5, 2.5);
    sd.xmm[1] = xmm_from_f64(3.0, 4.0);
    sd.xmm[2] = xmm_from_f64(5.0, 6.0);

    // VFMADD132PD xmm0,xmm1,xmm2: dst = dst*src3 + src2
    add_xmm("evex vfmadd132pd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0xF5, 0x08, 0x98, 0xC2}, sd, 0x7);

    // VFMADD213PD xmm0,xmm1,xmm2: dst = src2*dst + src3
    add_xmm("evex vfmadd213pd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0xF5, 0x08, 0xA8, 0xC2}, sd, 0x7);

    // VFMADD231PD xmm0,xmm1,xmm2: dst = src2*src3 + dst
    add_xmm("evex vfmadd231pd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0xF5, 0x08, 0xB8, 0xC2}, sd, 0x7);

    // VFMADDSUB132PS xmm0,xmm1,xmm2: even=dst*src3-src2, odd=dst*src3+src2
    add_xmm("evex vfmaddsub132ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x96, 0xC2}, s, 0x7);

    // VFMSUBADD213PS xmm0,xmm1,xmm2: even=src2*dst+src3, odd=src2*dst-src3
    add_xmm("evex vfmsubadd213ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xA7, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // EVEX shift-by-register (count from low 64 bits of xmm)
  // EVEX.128.66.0F, src1=xmm1(vvvv), count=xmm2(rm)
  // P0=0xF1, P1=0x75(W=0,vvvv=~1,pp=01), P2=0x08
  // modrm=0xC2(mod=11,reg=000(dst),rm=010(count))
  // =====================================================================
  cat = "EVEX shift reg";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = {0x8000400020001000, 0xFF00800040002000};
    // Shift count in low 64 bits of xmm2 (count=4)
    s.xmm[2] = {0x0000000000000004, 0x0000000000000000};

    // VPSRLW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG D1 /r
    add_xmm("evex vpsrlw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xD1, 0xC2}, s, 0x7);

    // VPSRLD xmm0, xmm1, xmm2: EVEX.128.66.0F.W0 D2 /r
    add_xmm("evex vpsrld xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xD2, 0xC2}, s, 0x7);

    // VPSRLQ xmm0, xmm1, xmm2: EVEX.128.66.0F.W1 D3 /r
    add_xmm("evex vpsrlq xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0xD3, 0xC2}, s, 0x7);

    // VPSRAW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG E1 /r
    add_xmm("evex vpsraw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xE1, 0xC2}, s, 0x7);

    // VPSRAD xmm0, xmm1, xmm2: EVEX.128.66.0F.W0 E2 /r
    add_xmm("evex vpsrad xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xE2, 0xC2}, s, 0x7);

    // VPSRAQ xmm0, xmm1, xmm2: EVEX.128.66.0F.W1 E2 /r
    add_xmm("evex vpsraq xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0xE2, 0xC2}, s, 0x7);

    // VPSLLW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG F1 /r
    add_xmm("evex vpsllw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xF1, 0xC2}, s, 0x7);

    // VPSLLD xmm0, xmm1, xmm2: EVEX.128.66.0F.W0 F2 /r
    add_xmm("evex vpslld xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xF2, 0xC2}, s, 0x7);

    // VPSLLQ xmm0, xmm1, xmm2: EVEX.128.66.0F.W1 F3 /r
    add_xmm("evex vpsllq xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0xF3, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // EVEX VMOVUPS/VMOVUPD writemask test (xmm width)
  // Tests merge-masking and zero-masking for 128-bit VMOVUPS
  // =====================================================================
  cat = "EVEX VMOV mask";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u32(0xDEAD0000, 0xDEAD0001, 0xDEAD0002, 0xDEAD0003);
    s.xmm[1] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);

    // VMOVUPS xmm0, xmm1 — no mask (aaa=0): all elements copied
    // EVEX.128.0F.W0 10 /r: P0=0xF1, P1=0x78(W=0,vvvv=1111,NP), P2=0x08
    // Wait, NP means pp=00. P1 = 0.1111.1.00 = 0x7C
    // modrm: mod=11, reg=000(dst), rm=001(src) → 0xC1
    add_xmm("vmovups xmm0,xmm1 no mask",
            {0x62, 0xF1, 0x7C, 0x08, 0x10, 0xC1}, s, 0x7);

    // VMOVUPS xmm0{k1}, xmm1 — merge mask k1=0x5 (0101b)
    // Elements 0,2 from src, elements 1,3 from old dst
    // P2=0x09(z=0,LL=00,b=0,V'=1,aaa=001)
    add_xmm("vmovups xmm0{k1},xmm1 merge k1=0x5",
            {0xB8, 0x05, 0x00, 0x00, 0x00,        // MOV eax, 5
             0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
             0x62, 0xF1, 0x7C, 0x09, 0x10, 0xC1},  // VMOVUPS xmm0{k1}, xmm1
            s, 0x7);

    // VMOVUPS xmm0{k1}{z}, xmm1 — zero mask k1=0x5 (0101b)
    // Elements 0,2 from src, elements 1,3 = 0
    // P2=0x89(z=1,LL=00,b=0,V'=1,aaa=001)
    add_xmm("vmovups xmm0{k1}{z},xmm1 zero k1=0x5",
            {0xB8, 0x05, 0x00, 0x00, 0x00,        // MOV eax, 5
             0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
             0x62, 0xF1, 0x7C, 0x89, 0x10, 0xC1},  // VMOVUPS xmm0{k1}{z}, xmm1
            s, 0x7);

    // VMOVUPD xmm0{k1}, xmm1 — merge mask k1=0x1 (01b)
    // Element 0 from src, element 1 from old dst
    // EVEX.128.66.0F.W1 10 /r: P1=0xF9(W=1,vvvv=1111,pp=01(66))
    // P2=0x09(z=0,LL=00,b=0,V'=1,aaa=001)
    add_xmm("vmovupd xmm0{k1},xmm1 merge k1=0x1",
            {0xB8, 0x01, 0x00, 0x00, 0x00,        // MOV eax, 1
             0xC5, 0xF8, 0x92, 0xC8,               // KMOVW k1, eax
             0x62, 0xF1, 0xFD, 0x09, 0x10, 0xC1},  // VMOVUPD xmm0{k1}, xmm1
            s, 0x7);

    // VMOVUPD xmm0{k1}{z}, xmm1 — zero mask k1=0x2 (10b)
    // Element 0 = 0, element 1 from src
    add_xmm("vmovupd xmm0{k1}{z},xmm1 zero k1=0x2",
            {0xB8, 0x02, 0x00, 0x00, 0x00,
             0xC5, 0xF8, 0x92, 0xC8,
             0x62, 0xF1, 0xFD, 0x89, 0x10, 0xC1},
            s, 0x7);
  }

  // =====================================================================
  // BF16: VCVTNEPS2BF16, VCVTNE2PS2BF16, VDPBF16PS
  // =====================================================================
  cat = "BF16";
  {
    ArchState s = {};
    s.rflags = 0x2;

    // --- VCVTNEPS2BF16 xmm0, xmm1 (EVEX.128.F3.0F38.W0 72) ---
    // src: 1.0f (0x3F800000), 2.0f (0x40000000), -1.0f (0xBF800000), 0.5f (0x3F000000)
    // BF16: 0x3F80, 0x4000, 0xBF80, 0x3F00 → xmm0[63:0], upper qword = 0
    s.xmm[1] = {0x3F000000BF800000, 0x3F80000040000000};
    add_xmm("vcvtneps2bf16 xmm0,xmm1 basic",
            {// P0=0xF2(~R:~X:~B:~R'=1111,0,mmm=010), P1=0x7E(W=0,~vvvv=1111,1,pp=10=F3),
             // P2=0x08(z=0,LL=00,b=0,V'=1,aaa=000), op=72, modrm=C1(dst=xmm0,src=xmm1)
             0x62, 0xF2, 0x7E, 0x08, 0x72, 0xC1},
            s, 0x7);

    // --- VCVTNEPS2BF16 with NaN input ---
    // NaN (0x7FC00000) → BF16 should be 0x7FC0|0x0040 = 0x7FC0 (already QNaN)
    // SNaN (0x7F800001) → BF16 should have bit 6 set: 0x7F80|0x0040 = 0x7FC0
    s.xmm[1] = {0x7F8000017FC00000, 0x0000000000000000};
    add_xmm("vcvtneps2bf16 xmm0,xmm1 NaN",
            {0x62, 0xF2, 0x7E, 0x08, 0x72, 0xC1},
            s, 0x7);

    // --- VCVTNEPS2BF16 with infinity ---
    // +Inf (0x7F800000) → 0x7F80, -Inf (0xFF800000) → 0xFF80
    s.xmm[1] = {0xFF8000007F800000, 0x0000000000000000};
    add_xmm("vcvtneps2bf16 xmm0,xmm1 inf",
            {0x62, 0xF2, 0x7E, 0x08, 0x72, 0xC1},
            s, 0x7);

    // --- VCVTNEPS2BF16 rounding test ---
    // 1.0009765625f = 0x3F800200 → BF16 rounds to 0x3F80 (round down, LSB=0)
    // 1.0078125f = 0x3F810000 → BF16 = 0x3F81 (exact)
    s.xmm[1] = {0x3F8100003F800200, 0x0000000000000000};
    add_xmm("vcvtneps2bf16 xmm0,xmm1 rounding",
            {0x62, 0xF2, 0x7E, 0x08, 0x72, 0xC1},
            s, 0x7);

    // --- VCVTNE2PS2BF16 xmm0, xmm1, xmm2 (EVEX.128.F2.0F38.W0 72) ---
    // src1 (xmm1): 3.0f (0x40400000), 4.0f (0x40800000), 5.0f (0x40A00000), 6.0f (0x40C00000)
    // src2 (xmm2): 1.0f (0x3F800000), 2.0f (0x40000000), -1.0f (0xBF800000), 0.5f (0x3F000000)
    // Result: upper half from src1, lower half from src2
    // [0x4040,0x4080,0x40A0,0x40C0, 0x3F80,0x4000,0xBF80,0x3F00]
    s.xmm[1] = {0x40A0000040400000, 0x40C0000040800000};  // src1: 3,5,4,6
    s.xmm[2] = {0xBF8000003F800000, 0x3F00000040000000};  // src2: 1,-1,2,0.5
    add_xmm("vcvtne2ps2bf16 xmm0,xmm1,xmm2 basic",
            {// EVEX P0=0xF2(R=1,X=1,B=1,R'=0,mmm=010), wait that's wrong...
             // F2 prefix: pp=11 in EVEX P1
             // P0=0xF2(00,mmm=010), P1=0x6F(W=0,vvvv=~1=1101,pp=11), P2=0x08, op=72, modrm=C2
             // Actually: P0 = R:X:B:R':00:mmm = 1:1:1:1:00:010 = 0xF2? No...
             // P0[7:4] = ~R:~X:~B:~R' (inverted)
             // For reg-reg with xmm0-xmm2: R=0,X=0,B=0,R'=0 → ~bits = 1,1,1,1
             // P0 = 1111:0:mmm = 1111:0:010 = 0xF2
             // P1 = W:~vvvv:1:pp = 0:~0001:1:11 = 0:1110:1:11 = 0x77
             // Wait, vvvv encodes src1 (xmm1), so vvvv=0001, ~vvvv=1110
             // P1 = 0:1110:1:11 = 0111_0111 = 0x77
             // P2 = z:LL:b:V':aaa = 0:00:0:1:000 = 0x08
             0x62, 0xF2, 0x77, 0x08, 0x72, 0xC2},
            s, 0x7);

    // --- VDPBF16PS xmm0, xmm1, xmm2 (EVEX.128.F3.0F38.W0 52) ---
    // dst (xmm0): all zeros
    // src1 (xmm1): [1.0_bf16, 2.0_bf16, 3.0_bf16, 4.0_bf16, ...]
    //   = [0x3F80, 0x4000, 0x4040, 0x4080, ...]
    // src2 (xmm2): [1.0_bf16, 1.0_bf16, 1.0_bf16, 1.0_bf16, ...]
    //   = [0x3F80, 0x3F80, 0x3F80, 0x3F80, ...]
    // Per dword element: dst += bf16_hi*bf16_hi + bf16_lo*bf16_lo
    // Element 0: (0x3F80→1.0) * (0x3F80→1.0) + (0x4000→2.0) * (0x3F80→1.0) = 1+2 = 3.0
    //   But wait: lo=bits[15:0], hi=bits[31:16]
    //   dword[0] of src1 = 0x40003F80 → lo=0x3F80(1.0), hi=0x4000(2.0)
    //   dword[0] of src2 = 0x3F803F80 → lo=0x3F80(1.0), hi=0x3F80(1.0)
    //   result = 0 + 2.0*1.0 + 1.0*1.0 = 3.0 (0x40400000)
    // Element 1: src1 dword[1] = 0x40804040 → lo=0x4040(3.0), hi=0x4080(4.0)
    //   result = 0 + 4.0*1.0 + 3.0*1.0 = 7.0 (0x40E00000)
    s.xmm[0] = {0x0000000000000000, 0x0000000000000000};
    s.xmm[1] = {0x40003F80, 0x40804040};  // [bf16: 1.0,2.0 | 3.0,4.0] as lo,hi pairs
    s.xmm[2] = {0x3F803F80, 0x3F803F80};  // [bf16: 1.0,1.0 | 1.0,1.0]
    add_xmm("vdpbf16ps xmm0,xmm1,xmm2 basic",
            {// EVEX.128.F3.0F38.W0 52
             // P0=0xF2(mmm=010), P1=0x76(W=0,~vvvv=1110,1,pp=10=F3), P2=0x08
             0x62, 0xF2, 0x76, 0x08, 0x52, 0xC2},
            s, 0x7);

    // --- VDPBF16PS with accumulation (nonzero dst) ---
    // dst = {10.0f, 20.0f, 0, 0}
    // src1 = {1.0_bf16, 1.0_bf16 | 2.0_bf16, 2.0_bf16 | 0,0 | 0,0}
    // src2 = {1.0_bf16, 1.0_bf16 | 1.0_bf16, 1.0_bf16 | 0,0 | 0,0}
    // Element 0: 10.0 + 1.0*1.0 + 1.0*1.0 = 12.0 (0x41400000)
    // Element 1: 20.0 + 2.0*1.0 + 2.0*1.0 = 24.0 (0x41C00000)
    s.xmm[0] = {0x41A0000041200000, 0x0000000000000000};  // 10.0f, 20.0f, 0, 0
    s.xmm[1] = {0x3F803F80, 0x40004000};  // [1.0,1.0 | 2.0,2.0]
    s.xmm[2] = {0x3F803F80, 0x3F803F80};  // [1.0,1.0 | 1.0,1.0]
    add_xmm("vdpbf16ps xmm0,xmm1,xmm2 accum",
            {0x62, 0xF2, 0x76, 0x08, 0x52, 0xC2},
            s, 0x7);

  }

  // =====================================================================
  // EVEX FP writemask at ymm width (ba301f6: added writemask to xmm/ymm FP)
  // =====================================================================
  cat = "EVEX FP mask ymm";
  {
    // VADDPS ymm0{k1}, ymm1, ymm2 — merge masking, 256-bit
    // EVEX.NDS.256.NP.0F.W0 58 /r
    // P0=0xF1(mmm=001), P1=0x74(W=0,~vvvv=1110,V'=1,pp=00), P2=0x29(z=0,L'L=01,b=0,V'=1,aaa=001)
    // k1 = 0b10100101 → elements 0,2,5,7 updated, rest preserved
    {
      TestCase tc;
      tc.name = "vaddps ymm merge k1=A5h";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x74, 0x29, 0x58, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_f32(-1.0f, -1.0f, -1.0f, -1.0f);
      tc.initial.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      tc.initial.xmm[2] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
      tc.initial.kregs[1] = 0xA5;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VADDPS ymm0{k1}{z}, ymm1, ymm2 — zero masking, 256-bit
    // P2=0xA9(z=1,L'L=01,b=0,V'=1,aaa=001)
    {
      TestCase tc;
      tc.name = "vaddps ymm zero k1=A5h";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x74, 0xA9, 0x58, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_f32(-1.0f, -1.0f, -1.0f, -1.0f);
      tc.initial.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      tc.initial.xmm[2] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
      tc.initial.kregs[1] = 0xA5;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VMULPS ymm0{k2}, ymm1, ymm2 — merge masking, 256-bit
    // EVEX.NDS.256.NP.0F.W0 59 /r
    // P2=0x2A(z=0,L'L=01,b=0,V'=1,aaa=010)
    // k2 = 0b00001111 → only lower 4 elements updated
    {
      TestCase tc;
      tc.name = "vmulps ymm merge k2=0Fh";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x74, 0x2A, 0x59, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_f32(-1.0f, -1.0f, -1.0f, -1.0f);
      tc.initial.xmm[1] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
      tc.initial.xmm[2] = xmm_from_f32(10.0f, 10.0f, 10.0f, 10.0f);
      tc.initial.kregs[2] = 0x0F;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VADDPD ymm0{k1}, ymm1, ymm2 — merge masking, 256-bit double
    // EVEX.NDS.256.66.0F.W1 58 /r
    // P1=0xF5(W=1,~vvvv=1110,V'=1,pp=01), P2=0x29
    // k1 = 0b0101 → elements 0,2 updated (qword granularity, 4 elements in ymm)
    {
      TestCase tc;
      tc.name = "vaddpd ymm merge k1=5h";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0xF5, 0x29, 0x58, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_f64(-1.0, -1.0);
      tc.initial.xmm[1] = xmm_from_f64(1.5, 2.5);
      tc.initial.xmm[2] = xmm_from_f64(100.0, 200.0);
      tc.initial.kregs[1] = 0x5;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VSUBPS xmm0{k1}, xmm1, xmm2 — merge masking, 128-bit (xmm FP writemask)
    // EVEX.NDS.128.NP.0F.W0 5C /r
    // P2=0x09(z=0,L'L=00,b=0,V'=1,aaa=001)
    // k1 = 0b1001 → elements 0,3 updated
    {
      TestCase tc;
      tc.name = "vsubps xmm merge k1=9h";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x74, 0x09, 0x5C, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_f32(99.0f, 99.0f, 99.0f, 99.0f);
      tc.initial.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
      tc.initial.xmm[2] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      tc.initial.kregs[1] = 0x9;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VDIVPS xmm0{k1}{z}, xmm1, xmm2 — zero masking, 128-bit
    // EVEX.NDS.128.NP.0F.W0 5E /r
    // P2=0x89(z=1,L'L=00,b=0,V'=1,aaa=001)
    // k1 = 0b0110 → elements 1,2 get result, elements 0,3 zeroed
    {
      TestCase tc;
      tc.name = "vdivps xmm zero k1=6h";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x74, 0x89, 0x5E, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_f32(99.0f, 99.0f, 99.0f, 99.0f);
      tc.initial.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
      tc.initial.xmm[2] = xmm_from_f32(2.0f, 4.0f, 5.0f, 8.0f);
      tc.initial.kregs[1] = 0x6;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // EVEX broadcast on FP conversions (ed9581a)
  // =====================================================================
  cat = "EVEX bcast conv";
  {
    // VCVTDQ2PS xmm0, [rdi]{1to4} — broadcast dword, convert int32→float32
    // EVEX.128.NP.0F.W0 5B /r with EVEX.b=1
    // P0=0xF1, P1=0x7C(W=0,~vvvv=1111,V'=1,pp=00), P2=0x18(b=1,L'L=00)
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      int32_t val = 42;
      std::vector<u8> data(4);
      memcpy(data.data(), &val, 4);

      TestCase tc;
      tc.name = "vcvtdq2ps xmm0,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x7C, 0x18, 0x5B, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x1;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VCVTPS2PD xmm0, [rdi]{1to2} — broadcast f32, convert to f64
    // EVEX.128.NP.0F.W0 5A /r with EVEX.b=1
    // Note: broadcast is 1to2 for 128-bit (2 qwords from 1 dword)
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      float val = 3.14f;
      std::vector<u8> data(4);
      memcpy(data.data(), &val, 4);

      TestCase tc;
      tc.name = "vcvtps2pd xmm0,[rdi]{1to2}";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x7C, 0x18, 0x5A, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x1;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VCVTDQ2PS ymm0, [rdi]{1to8} — broadcast dword to 256-bit, convert
    // EVEX.256.NP.0F.W0 5B /r, P2=0x38(b=1,L'L=01)
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      int32_t val = -7;
      std::vector<u8> data(4);
      memcpy(data.data(), &val, 4);

      TestCase tc;
      tc.name = "vcvtdq2ps ymm0,[rdi]{1to8}";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x7C, 0x38, 0x5B, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x1;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VCVTDQ2PD xmm0, [rdi]{1to2} — broadcast dword, convert int32→float64
    // EVEX.128.F3.0F.W0 E6 /r with EVEX.b=1
    // P0=0xF1, P1=0x7E(W=0,~vvvv=1111,V'=1,pp=10=F3), P2=0x18
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      int32_t val = 999;
      std::vector<u8> data(4);
      memcpy(data.data(), &val, 4);

      TestCase tc;
      tc.name = "vcvtdq2pd xmm0,[rdi]{1to2}";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x7E, 0x18, 0xE6, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x1;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // EVEX broadcast on integer operations (14f530b, 291d9e6)
  // =====================================================================
  cat = "EVEX bcast int";
  {
    // VPSUBD xmm0, xmm1, [rdi]{1to4} — broadcast dword, integer subtract
    // EVEX.NDS.128.66.0F.W0 FA /r with EVEX.b=1
    // P0=0xF1, P1=0x75(W=0,~vvvv=1110,V'=1,pp=01), P2=0x18
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_u32(100, 200, 300, 400);
      uint32_t val = 50;
      std::vector<u8> data(4);
      memcpy(data.data(), &val, 4);

      TestCase tc;
      tc.name = "vpsubd xmm0,xmm1,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x75, 0x18, 0xFA, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VPMAXSD xmm0, xmm1, [rdi]{1to4} — broadcast dword, signed max
    // EVEX.NDS.128.66.0F38.W0 3D /r with EVEX.b=1
    // P0=0xF2(mmm=010), P1=0x75, P2=0x18
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_u32(5, 15, 25, 35);
      int32_t val = 20;
      std::vector<u8> data(4);
      memcpy(data.data(), &val, 4);

      TestCase tc;
      tc.name = "vpmaxsd xmm0,xmm1,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0x75, 0x18, 0x3D, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VPANDD xmm0, xmm1, [rdi]{1to4} — broadcast dword, bitwise AND
    // EVEX.NDS.128.66.0F.W0 DB /r with EVEX.b=1
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_u32(0xFF00FF00, 0x12345678, 0xAAAAAAAA, 0x0F0F0F0F);
      uint32_t val = 0x0F0F0F0F;
      std::vector<u8> data(4);
      memcpy(data.data(), &val, 4);

      TestCase tc;
      tc.name = "vpandd xmm0,xmm1,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x75, 0x18, 0xDB, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VPSUBQ xmm0, xmm1, [rdi]{1to2} — broadcast qword, integer subtract
    // EVEX.NDS.128.66.0F.W1 FB /r with EVEX.b=1
    // P1=0xF5(W=1), P2=0x18
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_u64(1000, 2000);
      uint64_t val = 500;
      std::vector<u8> data(8);
      memcpy(data.data(), &val, 8);

      TestCase tc;
      tc.name = "vpsubq xmm0,xmm1,[rdi]{1to2}";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0xF5, 0x18, 0xFB, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VPSLLVD xmm0, xmm1, [rdi]{1to4} — broadcast shift count, variable left shift
    // EVEX.NDS.128.66.0F38.W0 47 /r with EVEX.b=1
    // P0=0xF2, P1=0x75, P2=0x18
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_u32(1, 0xFF, 0x12345678, 0x80000000);
      uint32_t val = 4;  // shift all by 4
      std::vector<u8> data(4);
      memcpy(data.data(), &val, 4);

      TestCase tc;
      tc.name = "vpsllvd xmm0,xmm1,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0x75, 0x18, 0x47, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // EVEX scalar FP (5323b7d) and embedded rounding (da3ff9e, c217130)
  // =====================================================================
  cat = "EVEX scalar FP";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(99.0f, 88.0f, 77.0f, 66.0f);
    s.xmm[1] = xmm_from_f32(1.5f, 2.5f, 3.5f, 4.5f);
    s.xmm[2] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);

    // VADDSS xmm0, xmm1, xmm2 (EVEX)
    // EVEX.NDS.LIG.F3.0F.W0 58 /r
    // P0=0xF1, P1=0x76(W=0,~vvvv=1110,V'=1,pp=10=F3), P2=0x08
    add_xmm("vaddss xmm0,xmm1,xmm2 evex",
      {0x62, 0xF1, 0x76, 0x08, 0x58, 0xC2}, s, 0x7);

    // VMULSS xmm0, xmm1, xmm2 (EVEX)
    add_xmm("vmulss xmm0,xmm1,xmm2 evex",
      {0x62, 0xF1, 0x76, 0x08, 0x59, 0xC2}, s, 0x7);

    // VSUBSS xmm0, xmm1, xmm2 (EVEX)
    add_xmm("vsubss xmm0,xmm1,xmm2 evex",
      {0x62, 0xF1, 0x76, 0x08, 0x5C, 0xC2}, s, 0x7);

    // VDIVSS xmm0, xmm1, xmm2 (EVEX)
    add_xmm("vdivss xmm0,xmm1,xmm2 evex",
      {0x62, 0xF1, 0x76, 0x08, 0x5E, 0xC2}, s, 0x7);

    // EVEX scalar double
    s.xmm[0] = xmm_from_f64(99.0, 88.0);
    s.xmm[1] = xmm_from_f64(1.5, 2.5);
    s.xmm[2] = xmm_from_f64(10.0, 20.0);

    // VADDSD xmm0, xmm1, xmm2 (EVEX)
    // EVEX.NDS.LIG.F2.0F.W1 58 /r
    // P1=0xF7(W=1,~vvvv=1110,V'=1,pp=11=F2)
    add_xmm("vaddsd xmm0,xmm1,xmm2 evex",
      {0x62, 0xF1, 0xF7, 0x08, 0x58, 0xC2}, s, 0x7);

    // VMULSD xmm0, xmm1, xmm2 (EVEX)
    add_xmm("vmulsd xmm0,xmm1,xmm2 evex",
      {0x62, 0xF1, 0xF7, 0x08, 0x59, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // EVEX embedded rounding (VADDPS zmm with {rn-sae}, {rd-sae}, etc.)
  // EVEX.b=1 with register operand = embedded rounding
  // =====================================================================
  cat = "EVEX ER";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp, bool cmp_mxcsr = false) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, cmp_mxcsr});
    };

    // VADDPS zmm0, zmm1, zmm2, {rn-sae}
    // EVEX.512.NP.0F.W0 58 /r with b=1, L'L=00 (rn-sae)
    // P2: z=0, L'L=00, b=1, V'=1, aaa=000 → 0x18
    // But for ER: L'L encodes the rounding mode, and b=1
    // rn-sae: L'L=00, b=1 → P2 = 0x18
    // rd-sae: L'L=01, b=1 → P2 = 0x38
    // ru-sae: L'L=10, b=1 → P2 = 0x58
    // rz-sae: L'L=11, b=1 → P2 = 0x78
    {
      ArchState s;
      s.rflags = 0x2;
      // Use a value that rounds differently depending on mode
      // 1.5 + 0.0 = 1.5 (exact), but for integer conversion, rounding matters
      // Let's use VCVTPS2DQ which converts float→int and is affected by rounding
      // VCVTPS2DQ zmm0, zmm1, {rn-sae}
      // EVEX.512.66.0F.W0 5B /r, b=1
      // P0=0xF1, P1=0x7D(W=0,~vvvv=1111,V'=1,pp=01=66), P2=0x18(rn)
      s.xmm[1] = xmm_from_f32(1.5f, 2.5f, -1.5f, -2.5f);

      // {rn-sae}: round to nearest even → 2, 2, -2, -2
      add_xmm("vcvtps2dq zmm {rn-sae}",
        {0x62, 0xF1, 0x7D, 0x18, 0x5B, 0xC1}, s, 0x1);

      // {rd-sae}: round down → 1, 2, -2, -3
      add_xmm("vcvtps2dq zmm {rd-sae}",
        {0x62, 0xF1, 0x7D, 0x38, 0x5B, 0xC1}, s, 0x1);

      // {ru-sae}: round up → 2, 3, -1, -2
      add_xmm("vcvtps2dq zmm {ru-sae}",
        {0x62, 0xF1, 0x7D, 0x58, 0x5B, 0xC1}, s, 0x1);

      // {rz-sae}: round toward zero → 1, 2, -1, -2
      add_xmm("vcvtps2dq zmm {rz-sae}",
        {0x62, 0xF1, 0x7D, 0x78, 0x5B, 0xC1}, s, 0x1);
    }

    // VFMADD132PS zmm0, zmm1, zmm2, {rn-sae}
    // EVEX.512.66.0F38.W0 98 /r, b=1
    // Exercises embedded rounding on FMA
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      s.xmm[1] = xmm_from_f32(0.5f, 0.5f, 0.5f, 0.5f);
      s.xmm[2] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);

      // VFMADD132PS: dst = dst*src2 + vvvv = xmm0*xmm2 + xmm1
      // P0=0xF2(mmm=010), P1=0x75(W=0,~vvvv=1110,V'=1,pp=01), P2=0x18(rn)
      add_xmm("vfmadd132ps zmm {rn-sae}",
        {0x62, 0xF2, 0x75, 0x18, 0x98, 0xC2}, s, 0x7);
    }
  }

  // =====================================================================
  // VPCMPW/VPCMPUW (b9f3e23: word compare producing k-register)
  // =====================================================================
  cat = "EVEX VPCMPW";
  {
    // VPCMPW k0, xmm1, xmm2, 1 (LT)
    // EVEX.128.66.0F3A.W1 3F /r ib
    // P0=0xF3(mmm=011), P1=0xFD(W=1,~vvvv=1110,V'=1,pp=01), P2=0x08
    {
      TestCase tc;
      tc.name = "vpcmpw k0,xmm1,xmm2,LT";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0xFD, 0x08, 0x3F, 0xC2, 0x01};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      // Signed words: {-5, 10, 0, 32767, -32768, 100, -1, 0}
      tc.initial.xmm[1] = xmm_from_u64(0x7FFF0000000AFFFB, 0x0000FFFF00648000);
      // Comparison target: {0, 0, 0, 0, 0, 0, 0, 0}
      tc.initial.xmm[2] = {};
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.kreg_mask = 0x1;  // compare k0
      tests.push_back(std::move(tc));
    }

    // VPCMPUW k0, xmm1, xmm2, 5 (GE unsigned)
    // EVEX.128.66.0F3A.W1 3E /r ib
    {
      TestCase tc;
      tc.name = "vpcmpuw k0,xmm1,xmm2,GE";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0xFD, 0x08, 0x3E, 0xC2, 0x05};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[1] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
      tc.initial.xmm[2] = xmm_from_u64(0x0004000300020001, 0x0008000700060005);
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.kreg_mask = 0x1;
      tests.push_back(std::move(tc));
    }

    // VPCMPW k0, ymm1, ymm2, 0 (EQ) — 256-bit
    // P2 = 0x28 (L'L=01)
    {
      TestCase tc;
      tc.name = "vpcmpw k0,ymm1,ymm2,EQ";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0xFD, 0x28, 0x3F, 0xC2, 0x00};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[1] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
      tc.initial.xmm[2] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.kreg_mask = 0x1;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // VCVTQQ2PS (2d6eac6: convert packed int64 to float32)
  // =====================================================================
  cat = "EVEX VCVTQQ2PS";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    ArchState s;
    s.rflags = 0x2;

    // VCVTQQ2PS xmm0, xmm1
    // EVEX.128.NP.0F.W1 5B /r
    // P0=0xF1, P1=0xFC(W=1,~vvvv=1111,V'=1,pp=00), P2=0x08
    s.xmm[1] = xmm_from_u64(42, 1000000);
    add_xmm("vcvtqq2ps xmm0,xmm1",
      {0x62, 0xF1, 0xFC, 0x08, 0x5B, 0xC1}, s, 0x7);

    // VCVTQQ2PS xmm0, ymm1
    // P2=0x28 (L'L=01 for 256-bit source, 128-bit dest)
    s.xmm[1] = xmm_from_u64(100, -100);
    add_xmm("vcvtqq2ps xmm0,ymm1",
      {0x62, 0xF1, 0xFC, 0x28, 0x5B, 0xC1}, s, 0x7);

    // Large values that lose precision
    s.xmm[1] = xmm_from_u64(0x7FFFFFFFFFFFFFFF, -1);
    add_xmm("vcvtqq2ps xmm0,xmm1 large",
      {0x62, 0xF1, 0xFC, 0x08, 0x5B, 0xC1}, s, 0x7);
  }
}

#include "kvm-harness.h"

void add_evex_tests(std::vector<TestCase> &tests) {
  std::string cat;

  auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                      u32 xmm_cmp) {
    tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
  };

  // =====================================================================
  // EVEX writemask (k-register masking) tests
  //
  // EVEX P2 byte: z.L'L.b.V'.aaa
  // aaa = mask register index (0=no mask, 1=k1, etc.)
  // z = 0: merge masking (preserve dest elements), z = 1: zero masking
  //
  // For 128-bit with k1 merge: P2 = 0.00.0.1.001 = 0x09
  // For 128-bit with k1 zero:  P2 = 1.00.0.1.001 = 0x89
  // =====================================================================
  cat = "EVEX mask";
  {
    // VPADDD xmm0{k1}, xmm1, xmm2 — merge masking, partial mask
    // k1 = 0b0101 → elements 0,2 updated, elements 1,3 preserved from dest
    // P2 = 0x09 (z=0, L'L=00, b=0, V'=1, aaa=001)
    {
      TestCase tc;
      tc.name = "vpaddd xmm merge k1=0101b";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x75, 0x09, 0xFE, 0xC2};  // VPADDD xmm0{k1}, xmm1, xmm2
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_u32(0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF);
      tc.initial.xmm[1] = xmm_from_u32(1, 2, 3, 4);
      tc.initial.xmm[2] = xmm_from_u32(10, 20, 30, 40);
      tc.initial.kregs[1] = 0x5;  // k1 = 0101b
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VPADDD xmm0{k1}{z}, xmm1, xmm2 — zero masking
    // k1 = 0b0101 → elements 0,2 get result, elements 1,3 zeroed
    // P2 = 0x89 (z=1, L'L=00, b=0, V'=1, aaa=001)
    {
      TestCase tc;
      tc.name = "vpaddd xmm zero k1=0101b";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x75, 0x89, 0xFE, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_u32(0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF);
      tc.initial.xmm[1] = xmm_from_u32(1, 2, 3, 4);
      tc.initial.xmm[2] = xmm_from_u32(10, 20, 30, 40);
      tc.initial.kregs[1] = 0x5;  // k1 = 0101b
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VPADDD xmm0{k1}, xmm1, xmm2 — full mask (k1=0xF = all ones for 4 dwords)
    // Should behave like no masking
    {
      TestCase tc;
      tc.name = "vpaddd xmm merge k1=full";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x75, 0x09, 0xFE, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[1] = xmm_from_u32(1, 2, 3, 4);
      tc.initial.xmm[2] = xmm_from_u32(10, 20, 30, 40);
      tc.initial.kregs[1] = 0xF;  // all dword elements active
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VPADDD xmm0{k1}, xmm1, xmm2 — empty mask (k1=0)
    // Merge: all elements preserved from dest (no operation)
    {
      TestCase tc;
      tc.name = "vpaddd xmm merge k1=0";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x75, 0x09, 0xFE, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_u32(0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC, 0xDDDDDDDD);
      tc.initial.xmm[1] = xmm_from_u32(1, 2, 3, 4);
      tc.initial.xmm[2] = xmm_from_u32(10, 20, 30, 40);
      tc.initial.kregs[1] = 0;  // empty mask
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VPADDD xmm0{k1}{z}, xmm1, xmm2 — empty mask, zero masking
    // All elements zeroed
    {
      TestCase tc;
      tc.name = "vpaddd xmm zero k1=0";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x75, 0x89, 0xFE, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_u32(0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF);
      tc.initial.xmm[1] = xmm_from_u32(1, 2, 3, 4);
      tc.initial.xmm[2] = xmm_from_u32(10, 20, 30, 40);
      tc.initial.kregs[1] = 0;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VADDPS xmm0{k2}, xmm1, xmm2 — FP with merge mask
    // k2 = 0b1010 → elements 1,3 updated, elements 0,2 preserved
    // P2 = 0x0A (z=0, aaa=010=k2)
    {
      TestCase tc;
      tc.name = "vaddps xmm merge k2=1010b";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x74, 0x0A, 0x58, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_f32(-1.0f, -1.0f, -1.0f, -1.0f);
      tc.initial.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      tc.initial.xmm[2] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
      tc.initial.kregs[2] = 0xA;  // 1010b
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VADDPS xmm0{k2}{z}, xmm1, xmm2 — FP with zero mask
    // P2 = 0x8A (z=1, aaa=010=k2)
    {
      TestCase tc;
      tc.name = "vaddps xmm zero k2=1010b";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x74, 0x8A, 0x58, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_f32(-1.0f, -1.0f, -1.0f, -1.0f);
      tc.initial.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      tc.initial.xmm[2] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
      tc.initial.kregs[2] = 0xA;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VPXORD xmm0{k1}, xmm1, xmm2 — logical with mask
    // k1 = 0b0011 → only elements 0,1 updated
    {
      TestCase tc;
      tc.name = "vpxord xmm merge k1=0011b";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x75, 0x09, 0xEF, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      tc.initial.xmm[1] = xmm_from_u32(0xFF00FF00, 0x00FF00FF, 0xAAAAAAAA, 0x55555555);
      tc.initial.xmm[2] = xmm_from_u32(0x0F0F0F0F, 0xF0F0F0F0, 0x12345678, 0x9ABCDEF0);
      tc.initial.kregs[1] = 0x3;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // 256-bit EVEX with mask: VPADDD ymm0{k1}, ymm1, ymm2
    // P2 = 0x29 (z=0, L'L=01=256-bit, b=0, V'=1, aaa=001)
    // k1 = 0b01010101 → alternate elements
    {
      TestCase tc;
      tc.name = "vpaddd ymm merge k1=55h";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x75, 0x29, 0xFE, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_u32(0xDEAD0000, 0xDEAD0001, 0xDEAD0002, 0xDEAD0003);
      tc.initial.xmm[1] = xmm_from_u32(1, 2, 3, 4);
      tc.initial.xmm[2] = xmm_from_u32(100, 200, 300, 400);
      tc.initial.kregs[1] = 0x55;  // 01010101b
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // EVEX immediate rotate — VPROLD/Q, VPRORD/Q
  // EVEX.128.66.0F.W0 72 /1 ib = VPROLD xmm(vvvv), xmm(r/m), imm8
  // EVEX.128.66.0F.W1 72 /1 ib = VPROLQ xmm(vvvv), xmm(r/m), imm8
  // EVEX.128.66.0F.W0 72 /0 ib = VPRORD xmm(vvvv), xmm(r/m), imm8
  // EVEX.128.66.0F.W1 72 /0 ib = VPRORQ xmm(vvvv), xmm(r/m), imm8
  // =====================================================================
  cat = "EVEX rotate imm";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    ArchState s;
    s.rflags = 0x2;
    s.xmm[2] = xmm_from_u32(0x12345678, 0x9ABCDEF0, 0x0F0F0F0F, 0x80000001);

    // VPROLD xmm0, xmm2, 4
    // P0=F1(mm=01), P1=7D(W=0,vvvv=~0=1111,pp=01), P2=08(128,no mask)
    // ModRM: mod=11, reg=001(/1), rm=010(xmm2) = 0xCA, imm=4
    add_xmm("vprold xmm0,xmm2,4",
      {0x62, 0xF1, 0x7D, 0x08, 0x72, 0xCA, 0x04}, s, 0x7);

    // VPROLD xmm0, xmm2, 0 (no rotation)
    add_xmm("vprold xmm0,xmm2,0",
      {0x62, 0xF1, 0x7D, 0x08, 0x72, 0xCA, 0x00}, s, 0x7);

    // VPROLD xmm0, xmm2, 16
    add_xmm("vprold xmm0,xmm2,16",
      {0x62, 0xF1, 0x7D, 0x08, 0x72, 0xCA, 0x10}, s, 0x7);

    // VPRORD xmm0, xmm2, 4
    // ModRM: mod=11, reg=000(/0), rm=010(xmm2) = 0xC2
    add_xmm("vprord xmm0,xmm2,4",
      {0x62, 0xF1, 0x7D, 0x08, 0x72, 0xC2, 0x04}, s, 0x7);

    // VPRORD xmm0, xmm2, 16
    add_xmm("vprord xmm0,xmm2,16",
      {0x62, 0xF1, 0x7D, 0x08, 0x72, 0xC2, 0x10}, s, 0x7);

    // VPROLQ xmm0, xmm2, 7
    // P1=FD(W=1), same P0/P2
    s.xmm[2] = xmm_from_u64(0x123456789ABCDEF0, 0x8000000000000001);
    add_xmm("vprolq xmm0,xmm2,7",
      {0x62, 0xF1, 0xFD, 0x08, 0x72, 0xCA, 0x07}, s, 0x7);

    // VPRORQ xmm0, xmm2, 7
    add_xmm("vprorq xmm0,xmm2,7",
      {0x62, 0xF1, 0xFD, 0x08, 0x72, 0xC2, 0x07}, s, 0x7);

    // VPROLQ xmm0, xmm2, 32 (rotate by half)
    add_xmm("vprolq xmm0,xmm2,32",
      {0x62, 0xF1, 0xFD, 0x08, 0x72, 0xCA, 0x20}, s, 0x7);
  }

  // =====================================================================
  // VEX GFNI — VGF2P8MULB, VGF2P8AFFINEQB, VGF2P8AFFINEINVQB
  // =====================================================================
  cat = "VEX GFNI";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x1020304050607080, 0x90A0B0C0D0E0F001);

    // VGF2P8MULB xmm0, xmm1, xmm2 (VEX.128.66.0F38.W0 CF /r)
    // 3-byte VEX: C4 [RXB.mmmmm] [W.vvvv.L.pp]
    // R̄=1,X̄=1,B̄=1,mmmmm=00010 → E2
    // W=0, vvvv=~1=1110, L=0, pp=01(66) → 0.1110.0.01 = 0x71
    // Wait: vvvv is inverted. xmm1=1, ~1=0b1110. P1=0.1110.0.01
    // Hmm: W.~vvvv.L.pp = 0.1110.0.01 = 0x71
    // C4 E2 71 CF C2: VGF2P8MULB xmm0, xmm1, xmm2 (modrm=11.000.010=0xC2)
    add_xmm("vgf2p8mulb xmm0,xmm1,xmm2",
      {0xC4, 0xE2, 0x71, 0xCF, 0xC2}, s, 0x7);

    // VGF2P8AFFINEQB xmm0, xmm1, xmm2, 0x00 (VEX.128.66.0F3A.W1 CE /r ib)
    // C4 E3 F1 CE C2 00
    // mmmmm=00011(0F3A) → P0: 1.1.1.00011 = 0xE3
    // W=1, vvvv=~1=1110, L=0, pp=01 → 1.1110.0.01 = 0xF1
    add_xmm("vgf2p8affineqb xmm0,xmm1,xmm2,0x00",
      {0xC4, 0xE3, 0xF1, 0xCE, 0xC2, 0x00}, s, 0x7);

    // VGF2P8AFFINEINVQB xmm0, xmm1, xmm2, 0x00 (VEX.128.66.0F3A.W1 CF /r ib)
    add_xmm("vgf2p8affineinvqb xmm0,xmm1,xmm2,0x00",
      {0xC4, 0xE3, 0xF1, 0xCF, 0xC2, 0x00}, s, 0x7);

    // VGF2P8AFFINEQB with non-zero imm
    add_xmm("vgf2p8affineqb xmm0,xmm1,xmm2,0x55",
      {0xC4, 0xE3, 0xF1, 0xCE, 0xC2, 0x55}, s, 0x7);
  }

  // =====================================================================
  // EVEX FP conv — VCVTQQ2PS (signed int64 → float32, narrowing)
  // EVEX.NP.0F.W1 5B /r
  // =====================================================================
  cat = "EVEX FP conv";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    // VCVTQQ2PS xmm0, xmm2 (128-bit: 2 int64 → 2 float32, zero upper)
    // EVEX: P0=F1(mm=01), P1=FC(W=1,vvvv=1111,pp=00 NP)→11111100, P2=08(128)
    // Wait: P1 = W.~vvvv.1.pp = 1.1111.1.00 = 0xFC
    // Opcode 0x5B, ModRM: mod=11, reg=000(xmm0), rm=010(xmm2) = 0xC2
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[2] = xmm_from_u64(42, (uint64_t)-100);
      add_xmm("vcvtqq2ps xmm0,xmm2 (128)",
        {0x62, 0xF1, 0xFC, 0x08, 0x5B, 0xC2}, s, 0x7);
    }

    // VCVTQQ2PS xmm0, ymm2 (256-bit: 4 int64 → 4 float32)
    // P2=28(256-bit: L'L=01) → 0.01.0.1.000 = 0x28
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[2] = xmm_from_u64(1000000, (uint64_t)-999999);
      // ymm2 upper 128 = xmm[18] in our test infra
      // Actually, in the KVM harness, we set ymm by writing to xmm[i] for low 128
      // and the upper 128 is zero by default.
      // For simplicity, just test 128-bit form (already above) and a basic 256-bit.
      add_xmm("vcvtqq2ps xmm0,ymm2 (256)",
        {0x62, 0xF1, 0xFC, 0x28, 0x5B, 0xC2}, s, 0x7);
    }

    // VCVTPS2UDQ xmm0, xmm1 — unsigned float→int conversion edge cases
    // EVEX.128.NP.0F.W0 79 /r (note: NP prefix, not 66!)
    // P0=0xF1(mmm=001), P1=0x7C(W=0,vvvv=1111,pp=00 NP), P2=0x08
    // modrm: mod=11,reg=000(xmm0),rm=001(xmm1) → 0xC1
    {
      // Positive values: 1.5 → 2 (round nearest), 100.0 → 100
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_f32(0.0f, 100.0f, 1.5f, 3000000000.0f);
      add_xmm("vcvtps2udq: positive values",
        {0x62, 0xF1, 0x7C, 0x08, 0x79, 0xC1}, s, 0x3);
    }
    {
      // Edge cases: negative (-1.0) → 0xFFFFFFFF per SDM, NaN → 0xFFFFFFFF
      // UINT_MAX+1 (4294967296.0) → 0xFFFFFFFF
      ArchState s;
      s.rflags = 0x2;
      uint32_t qnan = 0x7FC00000;
      uint32_t neg1_bits, overflow_bits;
      float neg1 = -1.0f, overflow = 4294967296.0f;
      memcpy(&neg1_bits, &neg1, 4);
      memcpy(&overflow_bits, &overflow, 4);
      s.xmm[1] = xmm_from_u32(qnan, overflow_bits, neg1_bits, 0);
      add_xmm("vcvtps2udq: negative/NaN/overflow",
        {0x62, 0xF1, 0x7C, 0x08, 0x79, 0xC1}, s, 0x3);
    }

    // VCVTTPS2UDQ xmm0, xmm1 — truncating unsigned conversion
    // EVEX.128.NP.0F.W0 78 /r
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_f32(0.0f, 2.9f, 1000000.5f, 4294967000.0f);
      add_xmm("vcvttps2udq: truncation",
        {0x62, 0xF1, 0x7C, 0x08, 0x78, 0xC1}, s, 0x3);
    }
  }

  // =====================================================================
  // EVEX Embedded Rounding Control ({rn-sae}, {rd-sae}, {ru-sae}, {rz-sae})
  // =====================================================================
  cat = "EVEX rounding";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    // Test VCVTPS2DQ with embedded rounding: convert 2.5f to int32
    // MXCSR is set to default (RN=round nearest even), but the EVEX encoding
    // overrides the rounding mode via LL when EVEX.b=1 for reg-reg.
    //
    // VCVTPS2DQ zmm0, zmm2, {rc-sae}:
    //   EVEX.512.66.0F.W0 5B /r with EVEX.b=1
    //   P0: R̄=1,X̄=1,B̄=1,R'̄=1,0,mmm=001 → 0xF1
    //   P1: W=0,~vvvv=1111,1,pp=01(66) → 0x7D
    //   P2: z=0, L'L=RC, b=1, V'=1, aaa=000
    //     {rn-sae}: LL=00 → 0x18
    //     {rd-sae}: LL=01 → 0x38
    //     {ru-sae}: LL=10 → 0x58
    //     {rz-sae}: LL=11 → 0x78
    //   Opcode: 0x5B
    //   ModRM: mod=11, reg=000(zmm0), rm=010(zmm2) → 0xC2

    // 2.5f = 0x40200000, with RN → 2 (banker's rounding to even)
    // 2.5f, with RD → 2
    // 2.5f, with RU → 3
    // 2.5f, with RZ → 2
    {
      ArchState s;
      s.rflags = 0x2;
      float f = 2.5f;
      u32 fbits;
      memcpy(&fbits, &f, 4);
      s.xmm[2] = xmm_from_u32(fbits, fbits, fbits, fbits);

      // {rn-sae}: 2.5 → 2 (round to nearest even)
      add_xmm("vcvtps2dq {rn-sae} zmm, 2.5",
        {0x62, 0xF1, 0x7D, 0x18, 0x5B, 0xC2}, s, 0x7);

      // {rd-sae}: 2.5 → 2 (round down)
      add_xmm("vcvtps2dq {rd-sae} zmm, 2.5",
        {0x62, 0xF1, 0x7D, 0x38, 0x5B, 0xC2}, s, 0x7);

      // {ru-sae}: 2.5 → 3 (round up)
      add_xmm("vcvtps2dq {ru-sae} zmm, 2.5",
        {0x62, 0xF1, 0x7D, 0x58, 0x5B, 0xC2}, s, 0x7);

      // {rz-sae}: 2.5 → 2 (round toward zero)
      add_xmm("vcvtps2dq {rz-sae} zmm, 2.5",
        {0x62, 0xF1, 0x7D, 0x78, 0x5B, 0xC2}, s, 0x7);
    }

    // Test with -1.7f to differentiate all four modes clearly:
    // -1.7f, RN → -2, RD → -2, RU → -1, RZ → -1
    {
      ArchState s;
      s.rflags = 0x2;
      float f = -1.7f;
      u32 fbits;
      memcpy(&fbits, &f, 4);
      s.xmm[2] = xmm_from_u32(fbits, fbits, fbits, fbits);

      add_xmm("vcvtps2dq {rn-sae} zmm, -1.7",
        {0x62, 0xF1, 0x7D, 0x18, 0x5B, 0xC2}, s, 0x7);

      add_xmm("vcvtps2dq {rd-sae} zmm, -1.7",
        {0x62, 0xF1, 0x7D, 0x38, 0x5B, 0xC2}, s, 0x7);

      add_xmm("vcvtps2dq {ru-sae} zmm, -1.7",
        {0x62, 0xF1, 0x7D, 0x58, 0x5B, 0xC2}, s, 0x7);

      add_xmm("vcvtps2dq {rz-sae} zmm, -1.7",
        {0x62, 0xF1, 0x7D, 0x78, 0x5B, 0xC2}, s, 0x7);
    }

    // Test VADDPS with embedded rounding: add values that differ by rounding
    // 1.0f + 2^-24 (just above 1.0f): exact result is 1 + epsilon
    // Result in f32 depends on rounding: RN/RD/RZ → 1.0f, RU → nextafter(1.0f)
    //
    // VADDPS zmm0, zmm1, zmm2, {rc-sae}:
    //   EVEX.512.NP.0F.W0 58 /r with EVEX.b=1
    //   P1: W=0,~vvvv=1110(zmm1),1,pp=00 → 0x7C
    //   ModRM: mod=11, reg=000, rm=010 → 0xC2
    {
      ArchState s;
      s.rflags = 0x2;
      // 1.0f = 0x3F800000
      float one = 1.0f;
      u32 one_bits;
      memcpy(&one_bits, &one, 4);
      s.xmm[1] = xmm_from_u32(one_bits, one_bits, one_bits, one_bits);
      // 2^-24 = 0x33800000 (smallest f32 that, added to 1.0, should round)
      float eps = 5.960464477539063e-08f; // 2^-24
      u32 eps_bits;
      memcpy(&eps_bits, &eps, 4);
      s.xmm[2] = xmm_from_u32(eps_bits, eps_bits, eps_bits, eps_bits);

      // {rn-sae}: 1.0 + 2^-24 → 1.0 (round to nearest even, ties to even → 1.0)
      add_xmm("vaddps {rn-sae} zmm, 1+eps",
        {0x62, 0xF1, 0x7C, 0x18, 0x58, 0xC2}, s, 0x7);

      // {ru-sae}: 1.0 + 2^-24 → nextafter(1.0) = 0x3F800001
      add_xmm("vaddps {ru-sae} zmm, 1+eps",
        {0x62, 0xF1, 0x7C, 0x58, 0x58, 0xC2}, s, 0x7);

      // {rd-sae}: 1.0 + 2^-24 → 1.0 (round down)
      add_xmm("vaddps {rd-sae} zmm, 1+eps",
        {0x62, 0xF1, 0x7C, 0x38, 0x58, 0xC2}, s, 0x7);

      // {rz-sae}: 1.0 + 2^-24 → 1.0 (round toward zero)
      add_xmm("vaddps {rz-sae} zmm, 1+eps",
        {0x62, 0xF1, 0x7C, 0x78, 0x58, 0xC2}, s, 0x7);
    }
  }

  // =====================================================================
  // EVEX Scalar FP operations (VADDSS/SD, VMULSS/SD, etc.)
  // =====================================================================
  cat = "EVEX scalar FP";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    // EVEX.NDS.LIG.F3.0F.W0 58 /r: VADDSS xmm0, xmm1, xmm2
    //   P0: 0xF1 (R=1,X=1,B=1,R'=1,mmm=001)
    //   P1: W=0,~vvvv=1110(xmm1),1,pp=10(F3) → 0.1110.1.10 = 0x7A
    //   P2: z=0,LL=00,b=0,V'=1,aaa=000 → 0x08
    //   ModRM: mod=11, reg=000, rm=010 → 0xC2
    {
      ArchState s;
      s.rflags = 0x2;
      float a = 1.5f, b = 2.25f;
      u32 abits, bbits;
      memcpy(&abits, &a, 4);
      memcpy(&bbits, &b, 4);
      s.xmm[1] = xmm_from_u32(0xDEAD0001, 0xDEAD0002, 0xDEAD0003, abits);
      s.xmm[2] = xmm_from_u32(0, 0, 0, bbits);

      // VADDSS: result[31:0] = 1.5+2.25=3.75, result[127:32] = xmm1[127:32] preserved
      add_xmm("evex vaddss xmm0,xmm1,xmm2",
        {0x62, 0xF1, 0x76, 0x08, 0x58, 0xC2}, s, 0x7);

      // VMULSS: result[31:0] = 1.5*2.25=3.375
      // P1 for F3: 0x76 (wait, same encoding as above — the F3 is in pp=10)
      // Actually, checking: P1 = W.~vvvv.1.pp where pp=10 for F3
      // W=0, ~vvvv=1110, 1, pp=10 → 01110110 = 0x76
      add_xmm("evex vmulss xmm0,xmm1,xmm2",
        {0x62, 0xF1, 0x76, 0x08, 0x59, 0xC2}, s, 0x7);

      // VSUBSS: result[31:0] = 1.5-2.25=-0.75
      add_xmm("evex vsubss xmm0,xmm1,xmm2",
        {0x62, 0xF1, 0x76, 0x08, 0x5C, 0xC2}, s, 0x7);

      // VDIVSS: result[31:0] = 1.5/2.25=0.666...
      add_xmm("evex vdivss xmm0,xmm1,xmm2",
        {0x62, 0xF1, 0x76, 0x08, 0x5E, 0xC2}, s, 0x7);

      // VSQRTSS: result[31:0] = sqrt(2.25)=1.5
      // VSQRTSS xmm0, xmm1, xmm2: src1=xmm1(merge upper), src2=xmm2(sqrt input)
      add_xmm("evex vsqrtss xmm0,xmm1,xmm2",
        {0x62, 0xF1, 0x76, 0x08, 0x51, 0xC2}, s, 0x7);

      // VMINSS: result[31:0] = min(1.5, 2.25) = 1.5
      add_xmm("evex vminss xmm0,xmm1,xmm2",
        {0x62, 0xF1, 0x76, 0x08, 0x5D, 0xC2}, s, 0x7);

      // VMAXSS: result[31:0] = max(1.5, 2.25) = 2.25
      add_xmm("evex vmaxss xmm0,xmm1,xmm2",
        {0x62, 0xF1, 0x76, 0x08, 0x5F, 0xC2}, s, 0x7);
    }

    // EVEX.NDS.LIG.F2.0F.W1 58 /r: VADDSD xmm0, xmm1, xmm2
    //   P1: W=1,~vvvv=1110,1,pp=11(F2) → 1.1110.1.11 = 0xFB
    //   P2: 0x08
    {
      ArchState s;
      s.rflags = 0x2;
      double a = 1.5, b = 2.25;
      u64 abits, bbits;
      memcpy(&abits, &a, sizeof(abits));
      memcpy(&bbits, &b, sizeof(bbits));
      s.xmm[1] = xmm_from_u64(0xDEADBEEFCAFEBABE, abits);
      s.xmm[2] = xmm_from_u64(0, bbits);

      // VADDSD: result[63:0] = 1.5+2.25=3.75, result[127:64] = xmm1[127:64] preserved
      add_xmm("evex vaddsd xmm0,xmm1,xmm2",
        {0x62, 0xF1, 0xF7, 0x08, 0x58, 0xC2}, s, 0x7);

      // VMULSD: 1.5*2.25=3.375
      // P1 for F2+W1: W=1,~vvvv=1110,1,pp=11 → 11110111 = 0xF7
      // Wait, xmm1 is vvvv: ~vvvv = ~0001 = 1110
      // P1 = 1.1110.1.11 = 0xF7
      add_xmm("evex vmulsd xmm0,xmm1,xmm2",
        {0x62, 0xF1, 0xF7, 0x08, 0x59, 0xC2}, s, 0x7);

      // VSUBSD: 1.5-2.25=-0.75
      add_xmm("evex vsubsd xmm0,xmm1,xmm2",
        {0x62, 0xF1, 0xF7, 0x08, 0x5C, 0xC2}, s, 0x7);

      // VDIVSD: 1.5/2.25
      add_xmm("evex vdivsd xmm0,xmm1,xmm2",
        {0x62, 0xF1, 0xF7, 0x08, 0x5E, 0xC2}, s, 0x7);
    }

    // Test EVEX VADDSS with embedded rounding: {rz-sae}
    // EVEX.NDS.LIG.F3.0F.W0 58 /r with EVEX.b=1, LL=11(RZ)
    //   P2: z=0, LL=11, b=1, V'=1, aaa=000 → 0.11.1.1.000 = 0x78
    {
      ArchState s;
      s.rflags = 0x2;
      float one = 1.0f;
      float eps = 5.960464477539063e-08f; // 2^-24
      u32 one_bits, eps_bits;
      memcpy(&one_bits, &one, 4);
      memcpy(&eps_bits, &eps, 4);
      s.xmm[1] = xmm_from_u32(0, 0, 0, one_bits);
      s.xmm[2] = xmm_from_u32(0, 0, 0, eps_bits);

      // {rz-sae}: 1.0 + 2^-24 → 1.0 (truncate toward zero)
      add_xmm("evex vaddss {rz-sae} xmm, 1+eps",
        {0x62, 0xF1, 0x76, 0x78, 0x58, 0xC2}, s, 0x7);

      // {ru-sae}: 1.0 + 2^-24 → nextafter(1.0)
      // P2: LL=10, b=1 → 0.10.1.1.000 = 0x58
      add_xmm("evex vaddss {ru-sae} xmm, 1+eps",
        {0x62, 0xF1, 0x76, 0x58, 0x58, 0xC2}, s, 0x7);
    }
  }

  // =====================================================================
  // EVEX VMOVSS/VMOVSD — scalar move (load/store, reg-reg merge)
  // =====================================================================
  cat = "EVEX VMOVSS/SD";
  {
    // --- VMOVSS reg-reg load (opcode 10, F3) ---
    // EVEX.NDS.LIG.F3.0F.W0 10 /r: VMOVSS xmm0, xmm1, xmm2
    //   P0: 0xF1  P1: W=0,~vvvv=1110,1,pp=10 = 0x76  P2: 0x08
    //   ModRM: mod=11, reg=000(dst=xmm0), rm=010(src=xmm2) → 0xC2
    // Result: xmm0[31:0]=xmm2[31:0], xmm0[127:32]=xmm1[127:32], upper zeroed
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(0xAABBCCDD, 0x11223344, 0x55667788, 0x00000000);
      s.xmm[2] = xmm_from_u32(0, 0, 0, 0xDEADBEEF);
      tests.push_back({"evex vmovss xmm0,xmm1,xmm2 (reg-reg load)",
        cat, {0x62, 0xF1, 0x76, 0x08, 0x10, 0xC2}, s, FL_NONE, 0x7, false});
    }

    // --- VMOVSS mem load (opcode 10, F3) ---
    // EVEX.LIG.F3.0F.W0 10 /r: VMOVSS xmm0, [rdi]
    //   P1: W=0,~vvvv=1111(no vvvv for mem),1,pp=10 = 0x7E
    //   ModRM: mod=00, reg=000(dst=xmm0), rm=111(rdi) → 0x07
    // Result: xmm0 = zero_extend(m32)
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      float val = 3.14f;
      u32 vbits;
      memcpy(&vbits, &val, 4);
      std::vector<u8> data(16, 0);
      memcpy(data.data(), &vbits, 4);
      // Fill upper bytes with garbage to verify zero-extension
      data[4] = 0xFF; data[5] = 0xFF; data[6] = 0xFF; data[7] = 0xFF;

      TestCase tc;
      tc.name = "evex vmovss xmm0,[rdi] (mem load)";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x7E, 0x08, 0x10, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // --- VMOVSS reg-reg store (opcode 11, F3) ---
    // EVEX.NDS.LIG.F3.0F.W0 11 /r: VMOVSS xmm0, xmm1, xmm2
    //   ModRM: mod=11, reg=010(src=xmm2), rm=000(dst=xmm0) → 0xD0
    //   P1: W=0,~vvvv=1110(xmm1),1,pp=10 = 0x76
    // Result: xmm0[31:0]=xmm2[31:0], xmm0[127:32]=xmm1[127:32], upper zeroed
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(0x12345678, 0x9ABCDEF0, 0xFEDCBA98, 0x00000000);
      s.xmm[2] = xmm_from_u32(0, 0, 0, 0xCAFEBABE);
      tests.push_back({"evex vmovss xmm0,xmm1,xmm2 (reg-reg store)",
        cat, {0x62, 0xF1, 0x76, 0x08, 0x11, 0xD0}, s, FL_NONE, 0x7, false});
    }

    // --- VMOVSS mem store (opcode 11, F3) ---
    // EVEX.LIG.F3.0F.W0 11 /r: VMOVSS [rdi], xmm1
    //   P1: W=0,~vvvv=1111,1,pp=10 = 0x7E
    //   ModRM: mod=00, reg=001(src=xmm1), rm=111(rdi) → 0x0F
    // Result: m32 = xmm1[31:0]
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      float val = 2.718f;
      u32 vbits;
      memcpy(&vbits, &val, 4);
      s.xmm[1] = xmm_from_u32(0xDEADBEEF, 0xCAFEBABE, 0x12345678, vbits);

      TestCase tc;
      tc.name = "evex vmovss [rdi],xmm1 (mem store)";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x7E, 0x08, 0x11, 0x0F};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // --- VMOVSD reg-reg load (opcode 10, F2, W=1) ---
    // EVEX.NDS.LIG.F2.0F.W1 10 /r: VMOVSD xmm0, xmm1, xmm2
    //   P1: W=1,~vvvv=1110,1,pp=11 = 0xF7  P2: 0x08
    //   ModRM: mod=11, reg=000, rm=010 → 0xC2
    // Result: xmm0[63:0]=xmm2[63:0], xmm0[127:64]=xmm1[127:64], upper zeroed
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(0xAABBCCDDEEFF0011, 0x0000000000000000);
      s.xmm[2] = xmm_from_u64(0, 0x123456789ABCDEF0);
      tests.push_back({"evex vmovsd xmm0,xmm1,xmm2 (reg-reg load)",
        cat, {0x62, 0xF1, 0xF7, 0x08, 0x10, 0xC2}, s, FL_NONE, 0x7, false});
    }

    // --- VMOVSD mem load (opcode 10, F2, W=1) ---
    // EVEX.LIG.F2.0F.W1 10 /r: VMOVSD xmm0, [rdi]
    //   P1: W=1,~vvvv=1111,1,pp=11 = 0xFF  P2: 0x08
    //   ModRM: mod=00, reg=000, rm=111 → 0x07
    // Result: xmm0 = zero_extend(m64)
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      double val = 1.414;
      u64 vbits;
      memcpy(&vbits, &val, 8);
      std::vector<u8> data(16, 0xFF); // fill with FF
      memcpy(data.data(), &vbits, 8);

      TestCase tc;
      tc.name = "evex vmovsd xmm0,[rdi] (mem load)";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0xFF, 0x08, 0x10, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // --- VMOVSD reg-reg store (opcode 11, F2, W=1) ---
    // EVEX.NDS.LIG.F2.0F.W1 11 /r: VMOVSD xmm0, xmm1, xmm2
    //   ModRM: mod=11, reg=010(src=xmm2), rm=000(dst=xmm0) → 0xD0
    //   P1: W=1,~vvvv=1110,1,pp=11 = 0xF7
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(0xFEDCBA9876543210, 0x0000000000000000);
      s.xmm[2] = xmm_from_u64(0, 0xDEADCAFEBEEF1234);
      tests.push_back({"evex vmovsd xmm0,xmm1,xmm2 (reg-reg store)",
        cat, {0x62, 0xF1, 0xF7, 0x08, 0x11, 0xD0}, s, FL_NONE, 0x7, false});
    }

    // --- VMOVSD mem store (opcode 11, F2, W=1) ---
    // EVEX.LIG.F2.0F.W1 11 /r: VMOVSD [rdi], xmm1
    //   P1: W=1,~vvvv=1111,1,pp=11 = 0xFF  P2: 0x08
    //   ModRM: mod=00, reg=001(src=xmm1), rm=111(rdi) → 0x0F
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      double val = 2.71828;
      u64 vbits;
      memcpy(&vbits, &val, 8);
      s.xmm[1] = xmm_from_u64(0xCAFEBABEDEADBEEF, vbits);

      TestCase tc;
      tc.name = "evex vmovsd [rdi],xmm1 (mem store)";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0xFF, 0x08, 0x11, 0x0F};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // EVEX FMA rounding — VFMADD213PS with {er}
  // =====================================================================
  cat = "EVEX FMA rounding";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    // VFMADD213PS zmm0, zmm1, zmm2: result = zmm1 * zmm0 + zmm2
    // EVEX.NDS.512.66.0F38.W0 A8 /r
    //   P0: R̄=1,X̄=1,B̄=1,R'̄=1,0,mmm=010 → 0xF2
    //   P1: W=0,~vvvv=1110(zmm1),1,pp=01(66) → 0x75
    //   ModRM: mod=11, reg=000(zmm0), rm=010(zmm2) → 0xC2
    //
    // src2(zmm1) = 1.0f, dst(zmm0) = 1.0f, src3(zmm2) = 2^-24 (eps)
    // FMA: 1.0 * 1.0 + eps = 1.0 + eps (inexact in f32)
    {
      ArchState s;
      s.rflags = 0x2;
      float one = 1.0f;
      float eps = 5.960464477539063e-08f; // 2^-24
      u32 one_bits, eps_bits;
      memcpy(&one_bits, &one, 4);
      memcpy(&eps_bits, &eps, 4);
      s.xmm[0] = xmm_from_u32(one_bits, one_bits, one_bits, one_bits);
      s.xmm[1] = xmm_from_u32(one_bits, one_bits, one_bits, one_bits);
      s.xmm[2] = xmm_from_u32(eps_bits, eps_bits, eps_bits, eps_bits);

      // {rn-sae}: 1+eps → 1.0 (round nearest, ties to even)
      // P2: LL=00, b=1 → 0x18
      add_xmm("evex vfmadd213ps {rn-sae}",
        {0x62, 0xF2, 0x75, 0x18, 0xA8, 0xC2}, s, 0x7);

      // {ru-sae}: 1+eps → nextafter(1.0f) = 1.0000001192...
      // P2: LL=10, b=1 → 0x58
      add_xmm("evex vfmadd213ps {ru-sae}",
        {0x62, 0xF2, 0x75, 0x58, 0xA8, 0xC2}, s, 0x7);

      // {rz-sae}: 1+eps → 1.0 (truncate toward zero)
      // P2: LL=11, b=1 → 0x78
      add_xmm("evex vfmadd213ps {rz-sae}",
        {0x62, 0xF2, 0x75, 0x78, 0xA8, 0xC2}, s, 0x7);

      // {rd-sae}: 1+eps → 1.0 (round down)
      // P2: LL=01, b=1 → 0x38
      add_xmm("evex vfmadd213ps {rd-sae}",
        {0x62, 0xF2, 0x75, 0x38, 0xA8, 0xC2}, s, 0x7);
    }

    // VFMADD213SS xmm0, xmm1, xmm2: scalar result = xmm1[0] * xmm0[0] + xmm2[0]
    // EVEX.NDS.LIG.66.0F38.W0 A9 /r
    //   P0: 0xF2, P1: 0x75, ModRM: 0xC2
    // Same setup as above but scalar — upper bits preserved from xmm1
    {
      ArchState s;
      s.rflags = 0x2;
      float one = 1.0f;
      float eps = 5.960464477539063e-08f;
      u32 one_bits, eps_bits;
      memcpy(&one_bits, &one, 4);
      memcpy(&eps_bits, &eps, 4);
      s.xmm[0] = xmm_from_u32(0xDEAD0001, 0xDEAD0002, 0xDEAD0003, one_bits);
      s.xmm[1] = xmm_from_u32(0xCAFE0001, 0xCAFE0002, 0xCAFE0003, one_bits);
      s.xmm[2] = xmm_from_u32(0, 0, 0, eps_bits);

      // {ru-sae}: scalar FMA → nextafter(1.0f); upper preserved from xmm1
      add_xmm("evex vfmadd213ss {ru-sae}",
        {0x62, 0xF2, 0x75, 0x58, 0xA9, 0xC2}, s, 0x7);

      // {rz-sae}: scalar FMA → 1.0f; upper preserved from xmm1
      add_xmm("evex vfmadd213ss {rz-sae}",
        {0x62, 0xF2, 0x75, 0x78, 0xA9, 0xC2}, s, 0x7);
    }

    // VCVTPS2UDQ with {er}: convert f32 → u32 with rounding override
    // EVEX.512.0F.W0 79 /r — P0: 0xF1(mmm=001), P1: W=0,~vvvv=1111,1,pp=00 = 0x7C
    //   ModRM: mod=11, reg=000(zmm0), rm=001(zmm1) → 0xC1
    //
    // xmm1[0] = 2.7f → {rn}=3, {rd}=2, {ru}=3, {rz}=2
    {
      ArchState s;
      s.rflags = 0x2;
      float val = 2.7f;
      u32 vbits;
      memcpy(&vbits, &val, 4);
      s.xmm[1] = xmm_from_u32(vbits, vbits, vbits, vbits);

      // {rn-sae}: 2.7 → 3  (P2: LL=00, b=1 → 0x18)
      add_xmm("evex vcvtps2udq {rn-sae} 2.7",
        {0x62, 0xF1, 0x7C, 0x18, 0x79, 0xC1}, s, 0x7);

      // {rd-sae}: 2.7 → 2  (P2: LL=01, b=1 → 0x38)
      add_xmm("evex vcvtps2udq {rd-sae} 2.7",
        {0x62, 0xF1, 0x7C, 0x38, 0x79, 0xC1}, s, 0x7);

      // {ru-sae}: 2.7 → 3  (P2: LL=10, b=1 → 0x58)
      add_xmm("evex vcvtps2udq {ru-sae} 2.7",
        {0x62, 0xF1, 0x7C, 0x58, 0x79, 0xC1}, s, 0x7);

      // {rz-sae}: 2.7 → 2  (P2: LL=11, b=1 → 0x78)
      add_xmm("evex vcvtps2udq {rz-sae} 2.7",
        {0x62, 0xF1, 0x7C, 0x78, 0x79, 0xC1}, s, 0x7);
    }
  }

  // =====================================================================
  // VPTERNLOGD — ternary bitwise logic with 8-bit truth table
  // =====================================================================
  cat = "VPTERNLOGD";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    // VPTERNLOGD xmm0, xmm1, xmm2, imm8
    // EVEX.NDS.128.66.0F3A.W0 25 /r ib
    //   P0: 0xF3(mmm=011), P1: 0x75(W=0,~vvvv=1110,1,pp=01), P2: 0x08(128)
    //   ModRM: mod=11, reg=000(xmm0=a), rm=010(xmm2=c) → 0xC2
    //   vvvv=0001(xmm1=b)
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0xFFFF0000FFFF0000, 0xF0F0F0F00F0F0F0F);
    s.xmm[1] = xmm_from_u64(0xFF00FF00FF00FF00, 0xCC33CC33CC33CC33);
    s.xmm[2] = xmm_from_u64(0xF0F0F0F0F0F0F0F0, 0xAAAA5555AAAA5555);

    // imm=0xF0: result = a (pass-through dst)
    add_xmm("vpternlogd 0xF0 (a)",
      {0x62, 0xF3, 0x75, 0x08, 0x25, 0xC2, 0xF0}, s, 0x7);

    // imm=0xCC: result = b (copy vvvv)
    add_xmm("vpternlogd 0xCC (b)",
      {0x62, 0xF3, 0x75, 0x08, 0x25, 0xC2, 0xCC}, s, 0x7);

    // imm=0xAA: result = c (copy src)
    add_xmm("vpternlogd 0xAA (c)",
      {0x62, 0xF3, 0x75, 0x08, 0x25, 0xC2, 0xAA}, s, 0x7);

    // imm=0xFF: all ones
    add_xmm("vpternlogd 0xFF (ones)",
      {0x62, 0xF3, 0x75, 0x08, 0x25, 0xC2, 0xFF}, s, 0x7);

    // imm=0x00: all zeros
    add_xmm("vpternlogd 0x00 (zeros)",
      {0x62, 0xF3, 0x75, 0x08, 0x25, 0xC2, 0x00}, s, 0x7);

    // imm=0xC0: a AND b
    add_xmm("vpternlogd 0xC0 (a AND b)",
      {0x62, 0xF3, 0x75, 0x08, 0x25, 0xC2, 0xC0}, s, 0x7);

    // imm=0xFC: a OR b
    add_xmm("vpternlogd 0xFC (a OR b)",
      {0x62, 0xF3, 0x75, 0x08, 0x25, 0xC2, 0xFC}, s, 0x7);

    // imm=0x3C: a XOR b
    add_xmm("vpternlogd 0x3C (a XOR b)",
      {0x62, 0xF3, 0x75, 0x08, 0x25, 0xC2, 0x3C}, s, 0x7);

    // imm=0x96: a XOR b XOR c (3-way XOR — parity)
    add_xmm("vpternlogd 0x96 (a XOR b XOR c)",
      {0x62, 0xF3, 0x75, 0x08, 0x25, 0xC2, 0x96}, s, 0x7);

    // imm=0x80: a AND b AND c
    add_xmm("vpternlogd 0x80 (a AND b AND c)",
      {0x62, 0xF3, 0x75, 0x08, 0x25, 0xC2, 0x80}, s, 0x7);
  }

  // =====================================================================
  // VCVTPS2PH / VCVTPH2PS — F16C float32 ↔ float16 conversion
  // =====================================================================
  cat = "F16C";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    // VCVTPS2PH xmm1, xmm0, 0 (4 × f32 → 4 × f16, round nearest)
    // VEX.128.66.0F3A.W0 1D /r ib
    // C4 E3 79 1D C1 00: reg=0(xmm0=src), rm=1(xmm1=dst), imm=0
    // xmm0 = [1.0f, 2.0f, -0.5f, 65504.0f] → [0x3C00, 0x4000, 0xB800, 0x7BFF] in fp16
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_f32(65504.0f, -0.5f, 2.0f, 1.0f);
      // Result in xmm1: low 64 bits = 4 fp16 values, upper zeroed
      add_xmm("vcvtps2ph xmm1,xmm0,0 (4xf32→4xf16)",
        {0xC4, 0xE3, 0x79, 0x1D, 0xC1, 0x00}, s, 0x3);
    }

    // VCVTPH2PS xmm0, xmm1 (4 × f16 → 4 × f32)
    // VEX.128.66.0F38.W0 13 /r
    // C4 E2 79 13 C1: reg=0(xmm0=dst), rm=1(xmm1=src)
    // xmm1 low 64 = [0x3C00(1.0), 0x4000(2.0), 0xB800(-0.5), 0x7BFF(65504.0)]
    {
      ArchState s;
      s.rflags = 0x2;
      // Pack 4 fp16 values into low 64 bits of xmm1
      u64 fp16_vals = ((u64)0x7BFF << 48) | ((u64)0xB800 << 32) |
                      ((u64)0x4000 << 16) | (u64)0x3C00;
      s.xmm[1] = xmm_from_u64(0, fp16_vals);
      add_xmm("vcvtph2ps xmm0,xmm1 (4xf16→4xf32)",
        {0xC4, 0xE2, 0x79, 0x13, 0xC1}, s, 0x7);
    }

    // Round-trip: VCVTPS2PH then VCVTPH2PS for denorm f16 (6.0e-8 ≈ 0x0001 in fp16)
    // f32 value 5.960464477539063e-08 is the smallest positive fp16 normal = 2^-14
    // Actually smallest fp16 subnormal = 2^-24 ≈ 5.96e-8
    {
      ArchState s;
      s.rflags = 0x2;
      float val = 5.960464477539063e-08f; // 2^-24 = smallest fp16 subnormal
      s.xmm[0] = xmm_from_f32(0.0f, 0.0f, 0.0f, val);
      add_xmm("vcvtps2ph xmm1,xmm0,0 (subnorm f16)",
        {0xC4, 0xE3, 0x79, 0x1D, 0xC1, 0x00}, s, 0x3);
    }

    // VCVTPS2PH with imm8=4 (round toward zero/truncation)
    // Value 1.5f: with round-nearest → 1.5 (exact in fp16)
    // Value 1.001f: truncation should give 1.0 in fp16 (0x3C00)
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_f32(0.0f, 0.0f, 0.0f, 1.001f);
      add_xmm("vcvtps2ph xmm1,xmm0,3 (truncate 1.001)",
        {0xC4, 0xE3, 0x79, 0x1D, 0xC1, 0x03}, s, 0x3);
    }

    // EVEX VCVTPS2PH memory form: store to [rdi]
    // Tests that imm8 is fetched AFTER the memory operand (modrm+disp) not before
    // EVEX.128.66.0F3A.W0 1D /r ib
    // 62 F3 7D 08 1D 07 00: VCVTPS2PH [rdi], xmm0, 0
    // xmm0 = [1.0f, 2.0f, -0.5f, 65504.0f] → fp16: [0x3C00, 0x4000, 0xB800, 0x7BFF]
    // Memory store = 8 bytes (4 × fp16)
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[0] = xmm_from_f32(65504.0f, -0.5f, 2.0f, 1.0f);
      tests.push_back({"evex vcvtps2ph [rdi],xmm0,0 (mem store)", cat,
        {0x62, 0xF3, 0x7D, 0x08, 0x1D, 0x07, 0x00},
        s, FL_NONE, 0, false, {}, 8});
    }
  }

  // =====================================================================
  // FP precision conversions — VCVTPD2PS, VCVTPS2PD, VCVTSD2SS, VCVTSS2SD
  // =====================================================================
  cat = "FP conv prec";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    // VCVTPD2PS xmm0, xmm1 (128: 2×f64→2×f32, zero upper)
    // VEX.128.66.0F.WIG 5A /r: C5 F9 5A C1
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_f64(2.5, 1.25);
      add_xmm("vcvtpd2ps xmm0,xmm1 (128)",
        {0xC5, 0xF9, 0x5A, 0xC1}, s, 0x7);
    }

    // VCVTPD2PS xmm0, ymm1 (256: 4×f64→4×f32)
    // VEX.256.66.0F.WIG 5A /r: C5 FD 5A C1
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_f64(-3.75, 100.0);
      // upper ymm1 is zero → 0.0f, 0.0f in high floats
      add_xmm("vcvtpd2ps xmm0,ymm1 (256)",
        {0xC5, 0xFD, 0x5A, 0xC1}, s, 0x7);
    }

    // VCVTPS2PD xmm0, xmm1 (128: 2×f32→2×f64)
    // VEX.128.0F.WIG 5A /r: C5 F8 5A C1
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_f32(0.0f, 0.0f, -1.5f, 3.25f);
      add_xmm("vcvtps2pd xmm0,xmm1 (128)",
        {0xC5, 0xF8, 0x5A, 0xC1}, s, 0x7);
    }

    // VCVTSD2SS xmm0, xmm1, xmm2 (scalar f64→f32, preserve upper from xmm1)
    // VEX.LIG.F2.0F.WIG 5A /r: C5 F3 5A C2
    //   vvvv=0001(xmm1)
    {
      ArchState s;
      s.rflags = 0x2;
      double val = 2.718281828;
      u64 dbits;
      memcpy(&dbits, &val, 8);
      s.xmm[1] = xmm_from_u32(0xDEAD0001, 0xDEAD0002, 0xDEAD0003, 0xDEAD0004);
      s.xmm[2] = xmm_from_u64(0, dbits);
      add_xmm("vcvtsd2ss xmm0,xmm1,xmm2",
        {0xC5, 0xF3, 0x5A, 0xC2}, s, 0x7);
    }

    // VCVTSS2SD xmm0, xmm1, xmm2 (scalar f32→f64, preserve upper from xmm1)
    // VEX.LIG.F3.0F.WIG 5A /r: C5 F2 5A C2
    {
      ArchState s;
      s.rflags = 0x2;
      float val = 3.14159f;
      u32 fbits;
      memcpy(&fbits, &val, 4);
      s.xmm[1] = xmm_from_u64(0xBEEFCAFE12345678, 0x0000000000000000);
      s.xmm[2] = xmm_from_u32(0, 0, 0, fbits);
      add_xmm("vcvtss2sd xmm0,xmm1,xmm2",
        {0xC5, 0xF2, 0x5A, 0xC2}, s, 0x7);
    }
  }

  // =====================================================================
  // EVEX memory broadcast — EVEX.b=1 for memory operand
  // =====================================================================
  cat = "EVEX bcast mem";
  {
    // VADDPS xmm0, xmm1, [rdi]{1to4} — broadcast f32 from memory
    // EVEX.NDS.128.NP.0F.W0 58 /r with EVEX.b=1
    //   P1: W=0,~vvvv=1110,1,pp=00(NP) → 0x74
    //   P2: b=1 → 0x18
    //   Opcode: 0x58 (VADDPS)
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      float bcast_val = 10.0f;
      std::vector<u8> data(4);
      memcpy(data.data(), &bcast_val, 4);

      TestCase tc;
      tc.name = "vaddps xmm0,xmm1,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x74, 0x18, 0x58, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VADDPD xmm0, xmm1, [rdi]{1to2} — broadcast f64 from memory
    // EVEX.NDS.128.66.0F.W1 58 /r with EVEX.b=1
    //   P1: W=1,~vvvv=1110,1,pp=01(66) → 0xF5
    //   P2: b=1 → 0x18
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_f64(1.5, 2.5);
      double bcast_val = 100.0;
      std::vector<u8> data(8);
      memcpy(data.data(), &bcast_val, 8);

      TestCase tc;
      tc.name = "vaddpd xmm0,xmm1,[rdi]{1to2}";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0xF5, 0x18, 0x58, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VADDPS ymm0, ymm1, [rdi]{1to8} — broadcast f32 to 256-bit
    // EVEX.NDS.256.NP.0F.W0 58 /r with EVEX.b=1
    //   P2: L'L=01(256), b=1 → 0x38
    // ymm1 lower half set via xmm[1], upper half is zero
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      float bcast_val = 10.0f;
      std::vector<u8> data(4);
      memcpy(data.data(), &bcast_val, 4);

      TestCase tc;
      tc.name = "vaddps ymm0,ymm1,[rdi]{1to8}";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x74, 0x38, 0x58, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VMULPS xmm0, xmm1, [rdi]{1to4} — broadcast f32, multiply
    // EVEX.NDS.128.NP.0F.W0 59 /r with EVEX.b=1
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      float bcast_val = 3.0f;
      std::vector<u8> data(4);
      memcpy(data.data(), &bcast_val, 4);

      TestCase tc;
      tc.name = "vmulps xmm0,xmm1,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x74, 0x18, 0x59, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VSUBPS xmm0, xmm1, [rdi]{1to4} — broadcast f32, subtract
    // EVEX.NDS.128.NP.0F.W0 5C /r with EVEX.b=1
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
      float bcast_val = 1.5f;
      std::vector<u8> data(4);
      memcpy(data.data(), &bcast_val, 4);

      TestCase tc;
      tc.name = "vsubps xmm0,xmm1,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x74, 0x18, 0x5C, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VMINPS xmm0, xmm1, [rdi]{1to4} — broadcast f32, min
    // EVEX.NDS.128.NP.0F.W0 5D /r with EVEX.b=1
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_f32(1.0f, 5.0f, 2.0f, 8.0f);
      float bcast_val = 3.0f;
      std::vector<u8> data(4);
      memcpy(data.data(), &bcast_val, 4);

      TestCase tc;
      tc.name = "vminps xmm0,xmm1,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x74, 0x18, 0x5D, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VMAXPS xmm0, xmm1, [rdi]{1to4} — broadcast f32, max
    // EVEX.NDS.128.NP.0F.W0 5F /r with EVEX.b=1
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_f32(1.0f, 5.0f, 2.0f, 8.0f);
      float bcast_val = 3.0f;
      std::vector<u8> data(4);
      memcpy(data.data(), &bcast_val, 4);

      TestCase tc;
      tc.name = "vmaxps xmm0,xmm1,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x74, 0x18, 0x5F, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VDIVPD xmm0, xmm1, [rdi]{1to2} — broadcast f64, divide
    // EVEX.NDS.128.66.0F.W1 5E /r with EVEX.b=1
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_f64(10.0, 20.0);
      double bcast_val = 4.0;
      std::vector<u8> data(8);
      memcpy(data.data(), &bcast_val, 8);

      TestCase tc;
      tc.name = "vdivpd xmm0,xmm1,[rdi]{1to2}";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0xF5, 0x18, 0x5E, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VPADDD xmm0, xmm1, [rdi]{1to4} — broadcast dword, integer add
    // EVEX.NDS.128.66.0F.W0 FE /r with EVEX.b=1
    //   P1: W=0,~vvvv=1110,1,pp=01(66) → 0x75
    //   P2: b=1 → 0x18
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_u32(1, 2, 3, 4);
      uint32_t bcast_val = 100;
      std::vector<u8> data(4);
      memcpy(data.data(), &bcast_val, 4);

      TestCase tc;
      tc.name = "vpaddd xmm0,xmm1,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x75, 0x18, 0xFE, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VPXORD xmm0, xmm1, [rdi]{1to4} — broadcast dword, integer XOR
    // EVEX.NDS.128.66.0F.W0 EF /r with EVEX.b=1
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_u32(0xAAAAAAAA, 0x55555555, 0x12345678, 0xDEADBEEF);
      uint32_t bcast_val = 0xFF00FF00;
      std::vector<u8> data(4);
      memcpy(data.data(), &bcast_val, 4);

      TestCase tc;
      tc.name = "vpxord xmm0,xmm1,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x75, 0x18, 0xEF, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VPADDQ xmm0, xmm1, [rdi]{1to2} — broadcast qword, integer add
    // EVEX.NDS.128.66.0F.W1 D4 /r with EVEX.b=1
    //   P1: W=1,~vvvv=1110,1,pp=01(66) → 0xF5
    //   P2: b=1 → 0x18
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_u64(10, 20);
      uint64_t bcast_val = 1000;
      std::vector<u8> data(8);
      memcpy(data.data(), &bcast_val, 8);

      TestCase tc;
      tc.name = "vpaddq xmm0,xmm1,[rdi]{1to2}";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0xF5, 0x18, 0xD4, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VPMINSD xmm0, xmm1, [rdi]{1to4} — broadcast dword, signed min
    // EVEX.NDS.128.66.0F38.W0 39 /r with EVEX.b=1
    //   P1: R=1,X=1,B=1,R'=1,00,mm=10(0F38) → 0xF2
    //   P2: W=0,~vvvv=1110,1,pp=01(66) → 0x75
    //   P3: z=0,L'L=00,b=1,V'=1,aaa=000 → 0x18
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_u32(5, (uint32_t)-3, 10, 1);
      int32_t bcast_val = 3;
      std::vector<u8> data(4);
      memcpy(data.data(), &bcast_val, 4);

      TestCase tc;
      tc.name = "vpminsd xmm0,xmm1,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0x75, 0x18, 0x39, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VPMAXUD xmm0, xmm1, [rdi]{1to4} — broadcast dword, unsigned max
    // EVEX.NDS.128.66.0F38.W0 3F /r with EVEX.b=1
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_u32(1, 200, 50, 300);
      uint32_t bcast_val = 100;
      std::vector<u8> data(4);
      memcpy(data.data(), &bcast_val, 4);

      TestCase tc;
      tc.name = "vpmaxud xmm0,xmm1,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0x75, 0x18, 0x3F, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VPMULLD xmm0, xmm1, [rdi]{1to4} — broadcast dword, multiply low
    // EVEX.NDS.128.66.0F38.W0 40 /r with EVEX.b=1
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_u32(3, 7, 11, 13);
      uint32_t bcast_val = 5;
      std::vector<u8> data(4);
      memcpy(data.data(), &bcast_val, 4);

      TestCase tc;
      tc.name = "vpmulld xmm0,xmm1,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0x75, 0x18, 0x40, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VPABSD xmm0, [rdi]{1to4} — broadcast dword, absolute value (unary)
    // EVEX.128.66.0F38.W0 1E /r with EVEX.b=1
    //   vvvv=1111 (no src1 for unary) → P2: W=0,~vvvv=1111,1,pp=01 → 0x7D
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      int32_t bcast_val = -42;
      std::vector<u8> data(4);
      memcpy(data.data(), &bcast_val, 4);

      TestCase tc;
      tc.name = "vpabsd xmm0,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0x7D, 0x18, 0x1E, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VPMULDQ xmm0, xmm1, [rdi]{1to2} — broadcast qword, signed dword multiply
    // EVEX.NDS.128.66.0F38.W1 28 /r with EVEX.b=1
    //   P2: W=1,~vvvv=1110,1,pp=01 → 0xF5
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_u32(7, 0, 11, 0); // even dwords: 7, 11
      int64_t bcast_val = 3;
      std::vector<u8> data(8);
      memcpy(data.data(), &bcast_val, 8);

      TestCase tc;
      tc.name = "vpmuldq xmm0,xmm1,[rdi]{1to2}";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0xF5, 0x18, 0x28, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VPSRLVD xmm0, xmm1, [rdi]{1to4} — broadcast dword shift count, variable right shift
    // EVEX.NDS.128.66.0F38.W0 45 /r with EVEX.b=1
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_u32(0xFF00, 0xFF000, 0xFF0000, 0xFF000000);
      uint32_t bcast_val = 4; // shift all by 4
      std::vector<u8> data(4);
      memcpy(data.data(), &bcast_val, 4);

      TestCase tc;
      tc.name = "vpsrlvd xmm0,xmm1,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0x75, 0x18, 0x45, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VPMINUD xmm0, xmm1, [rdi]{1to4} — broadcast dword, unsigned min
    // EVEX.NDS.128.66.0F38.W0 3B /r with EVEX.b=1
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[1] = xmm_from_u32(50, 200, 10, 500);
      uint32_t bcast_val = 100;
      std::vector<u8> data(4);
      memcpy(data.data(), &bcast_val, 4);

      TestCase tc;
      tc.name = "vpminud xmm0,xmm1,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0x75, 0x18, 0x3B, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VFMADD132PS xmm0, xmm1, [rdi]{1to4} — broadcast f32, FMA
    // EVEX.NDS.128.66.0F38.W0 98 /r with EVEX.b=1
    //   P1: mm=10(0F38) → 0xF2
    //   P2: W=0,~vvvv=1110,1,pp=01(66) → 0x75
    //   P3: b=1 → 0x18
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[0] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
      s.xmm[1] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);
      float bcast_val = 10.0f;
      std::vector<u8> data(4);
      memcpy(data.data(), &bcast_val, 4);

      TestCase tc;
      tc.name = "vfmadd132ps xmm0,xmm1,[rdi]{1to4}";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0x75, 0x18, 0x98, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VPTERNLOGD xmm0, xmm1, [rdi]{1to4}, 0xFE — broadcast dword, ternary logic (OR)
    // EVEX.NDS.128.66.0F3A.W0 25 /r ib with EVEX.b=1
    //   P1: mm=11(0F3A) → 0xF3
    //   P2: W=0,~vvvv=1110,1,pp=01(66) → 0x75
    //   P3: b=1 → 0x18
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      s.xmm[0] = xmm_from_u32(0xF0F0F0F0, 0x0F0F0F0F, 0x00FF00FF, 0xFF00FF00);
      s.xmm[1] = xmm_from_u32(0x12345678, 0x9ABCDEF0, 0x11223344, 0x55667788);
      uint32_t bcast_val = 0xAAAAAAAA;
      std::vector<u8> data(4);
      memcpy(data.data(), &bcast_val, 4);

      TestCase tc;
      tc.name = "vpternlogd xmm0,xmm1,[rdi]{1to4},0xFE";
      tc.category = cat;
      // 0x25=opcode, 0x07=modrm [rdi], 0xFE=imm8 (a|b|c)
      tc.code = {0x62, 0xF3, 0x75, 0x18, 0x25, 0x07, 0xFE};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }

    // VRNDSCALEPS xmm0, [rdi]{1to4}, 0x00 — broadcast f32, round to nearest
    // EVEX.128.66.0F3A.W0 08 /r ib with EVEX.b=1
    //   P1: mm=11(0F3A) → 0xF3
    //   P2: W=0,~vvvv=1111,1,pp=01(66) → 0x7D (no vvvv src)
    //   P3: b=1 → 0x18
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdi = DATA_ADDR;
      float bcast_val = 3.7f;
      std::vector<u8> data(4);
      memcpy(data.data(), &bcast_val, 4);

      TestCase tc;
      tc.name = "vrndscaleps xmm0,[rdi]{1to4},0x00";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0x7D, 0x18, 0x08, 0x07, 0x00};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = std::move(data);
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // EVEX VPCMPD/VPCMPUD/VPCMPQ/VPCMPUQ — packed integer compare → kmask
  // =====================================================================
  cat = "EVEX VPCMP D/Q";
  {
    // Test signed vs unsigned dword compare — they should give different results.
    // xmm1 = [0xFFFFFFFF(-1), 2, 0x80000000(-2^31), 0x7FFFFFFF(2^31-1)]
    // xmm2 = [1, 2, 1, 0x80000000(-2^31)]
    //
    // VPCMPD (signed LT, pred=1):
    //   elem0: -1 < 1 = true, elem1: 2 < 2 = false,
    //   elem2: -2^31 < 1 = true, elem3: 2^31-1 < -2^31 = false
    //   → k0 = 0101b = 5
    //
    // VPCMPUD (unsigned LT, pred=1):
    //   elem0: 0xFFFFFFFF < 1 = false, elem1: 2 < 2 = false,
    //   elem2: 0x80000000 < 1 = false, elem3: 0x7FFFFFFF < 0x80000000 = true
    //   → k0 = 1000b = 8

    ArchState s = {};
    s.rflags = 0x2;
    // xmm1: dwords [0]=0xFFFFFFFF [1]=2 [2]=0x80000000 [3]=0x7FFFFFFF
    s.xmm[1] = xmm_from_u32(0xFFFFFFFF, 0x00000002, 0x80000000, 0x7FFFFFFF);
    // xmm2: dwords [0]=1 [1]=2 [2]=1 [3]=0x80000000
    s.xmm[2] = xmm_from_u32(0x00000001, 0x00000002, 0x00000001, 0x80000000);

    // VPCMPD k0, xmm1, xmm2, 1 (signed LT)
    // EVEX.128.66.0F3A.W0: P1=0xF3(mm=11), P2=0x75(W=0,vvvv=~1=1110,pp=01), P3=0x08(xmm)
    // opcode=0x1F, modrm=0xC2(k0,xmm2), imm=0x01
    // Then KMOVW eax, k0: C5 F8 93 C0
    {
      TestCase tc;
      tc.name = "vpcmpd k0,xmm1,xmm2,LT: signed dword LT → k0=5";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0x75, 0x08, 0x1F, 0xC2, 0x01,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // VPCMPUD k0, xmm1, xmm2, 1 (unsigned LT)
    // opcode=0x1E, rest same
    {
      TestCase tc;
      tc.name = "vpcmpud k0,xmm1,xmm2,LT: unsigned dword LT → k0=8";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0x75, 0x08, 0x1E, 0xC2, 0x01,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // VPCMPD k0, xmm1, xmm2, 0 (EQ)
    // Elements 1 are equal → k0 = 0010b = 2
    {
      TestCase tc;
      tc.name = "vpcmpd k0,xmm1,xmm2,EQ: dword equal → k0=2";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0x75, 0x08, 0x1F, 0xC2, 0x00,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // VPCMPD k0, xmm1, xmm2, 6 (NLE = GT signed)
    // elem0: -1 > 1 = false, elem1: 2 > 2 = false,
    // elem2: -2^31 > 1 = false, elem3: 2^31-1 > -2^31 = true
    // → k0 = 1000b = 8
    {
      TestCase tc;
      tc.name = "vpcmpd k0,xmm1,xmm2,NLE: signed dword GT → k0=8";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0x75, 0x08, 0x1F, 0xC2, 0x06,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // VPCMPUD k0, xmm1, xmm2, 6 (NLE = GT unsigned)
    // elem0: 0xFFFFFFFF > 1 = true, elem1: 2 > 2 = false,
    // elem2: 0x80000000 > 1 = true, elem3: 0x7FFFFFFF > 0x80000000 = false
    // → k0 = 0101b = 5
    {
      TestCase tc;
      tc.name = "vpcmpud k0,xmm1,xmm2,NLE: unsigned dword GT → k0=5";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0x75, 0x08, 0x1E, 0xC2, 0x06,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // VPCMPD with writemask: k1 as writemask, result in k0
    // VPCMPD k0{k1}, xmm1, xmm2, 1 (signed LT) with k1=0xA (1010b)
    // Without mask: k0 = 0101b, with mask 1010b: k0 = 0101 & 1010 = 0000b = 0
    // P3 = 0x09 (aaa=001 → k1 writemask)
    {
      TestCase tc;
      tc.name = "vpcmpd k0{k1},xmm1,xmm2,LT: writemask k1=0xA → k0=0";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0x75, 0x09, 0x1F, 0xC2, 0x01,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = s;
      tc.initial.kregs[1] = 0xA;  // mask: 1010b
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // Now test qword compares
    // xmm1 = [qword0=0xFFFFFFFFFFFFFFFF(-1), qword1=2]
    // xmm2 = [qword0=1, qword1=2]
    //
    // VPCMPQ (signed LT): -1 < 1 = true, 2 < 2 = false → k0 = 01b = 1
    // VPCMPUQ (unsigned LT): 0xFFFF... < 1 = false, 2 < 2 = false → k0 = 00b = 0

    ArchState sq = {};
    sq.rflags = 0x2;
    sq.xmm[1] = xmm_from_u64(0xFFFFFFFFFFFFFFFF, 0x0000000000000002);
    sq.xmm[2] = xmm_from_u64(0x0000000000000001, 0x0000000000000002);

    // VPCMPQ k0, xmm1, xmm2, 1 (signed LT)
    // P2=0xF5 (W=1, vvvv=~1=1110, pp=01)
    {
      TestCase tc;
      tc.name = "vpcmpq k0,xmm1,xmm2,LT: signed qword LT → k0=1";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0xF5, 0x08, 0x1F, 0xC2, 0x01,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = sq;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // VPCMPUQ k0, xmm1, xmm2, 1 (unsigned LT)
    {
      TestCase tc;
      tc.name = "vpcmpuq k0,xmm1,xmm2,LT: unsigned qword LT → k0=0";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0xF5, 0x08, 0x1E, 0xC2, 0x01,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = sq;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // VPCMPQ k0, xmm1, xmm2, 0 (EQ): only qword1 equal → k0 = 10b = 2
    {
      TestCase tc;
      tc.name = "vpcmpq k0,xmm1,xmm2,EQ: qword equal → k0=2";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0xF5, 0x08, 0x1F, 0xC2, 0x00,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = sq;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // VPCMPUQ k0, xmm1, xmm2, 6 (NLE = GT unsigned)
    // elem0: 0xFFFF... > 1 = true, elem1: 2 > 2 = false → k0 = 01b = 1
    {
      TestCase tc;
      tc.name = "vpcmpuq k0,xmm1,xmm2,NLE: unsigned qword GT → k0=1";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0xF5, 0x08, 0x1E, 0xC2, 0x06,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = sq;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // Test word compares (VPCMPW / VPCMPUW)
    // xmm1 words: [0xFFFF(-1), 0x0002, 0x8000(-32768), 0x7FFF(32767), 0x0001, 0x0005, 0x0003, 0x0003]
    // xmm2 words: [0x0001,     0x0002, 0x0001,          0x8000(-32768),0x0001, 0x0005, 0x0003, 0x0004]
    //
    // VPCMPW (signed LT, pred=1):
    //   w0: -1<1=T, w1: 2<2=F, w2: -32768<1=T, w3: 32767<-32768=F,
    //   w4: 1<1=F, w5: 5<5=F, w6: 3<3=F, w7: 3<4=T
    //   → k0 = 10000101b = 0x85
    //
    // VPCMPUW (unsigned LT, pred=1):
    //   w0: 0xFFFF<1=F, w1: 2<2=F, w2: 0x8000<1=F, w3: 0x7FFF<0x8000=T,
    //   w4: 1<1=F, w5: 5<5=F, w6: 3<3=F, w7: 3<4=T
    //   → k0 = 10001000b = 0x88

    ArchState sw = {};
    sw.rflags = 0x2;
    // xmm1: words [0]=0xFFFF [1]=2 [2]=0x8000 [3]=0x7FFF [4]=1 [5]=5 [6]=3 [7]=3
    sw.xmm[1] = xmm_from_u32(0x0002FFFF, 0x7FFF8000, 0x00050001, 0x00030003);
    // xmm2: words [0]=1 [1]=2 [2]=1 [3]=0x8000 [4]=1 [5]=5 [6]=3 [7]=4
    sw.xmm[2] = xmm_from_u32(0x00020001, 0x80000001, 0x00050001, 0x00040003);

    // VPCMPW k0, xmm1, xmm2, 1 (signed LT)
    // EVEX.128.66.0F3A.W1: P1=0xF3, P2=0xF5(W=1,vvvv=~1,pp=01), P3=0x08
    // opcode=0x3F, modrm=0xC2(k0,xmm2), imm=0x01
    {
      TestCase tc;
      tc.name = "vpcmpw k0,xmm1,xmm2,LT: signed word LT → k0=0x85";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0xF5, 0x08, 0x3F, 0xC2, 0x01,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = sw;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // VPCMPUW k0, xmm1, xmm2, 1 (unsigned LT)
    // opcode=0x3E
    {
      TestCase tc;
      tc.name = "vpcmpuw k0,xmm1,xmm2,LT: unsigned word LT → k0=0x88";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0xF5, 0x08, 0x3E, 0xC2, 0x01,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = sw;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // VPCMPW k0, xmm1, xmm2, 0 (EQ)
    // Equal words: w1(2=2), w4(1=1), w5(5=5), w6(3=3) → k0 = 01110010b = 0x72
    {
      TestCase tc;
      tc.name = "vpcmpw k0,xmm1,xmm2,EQ: word equal → k0=0x72";
      tc.category = cat;
      tc.code = {0x62, 0xF3, 0xF5, 0x08, 0x3F, 0xC2, 0x00,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = sw;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // VPMINUQ — unsigned qword min (was missing, W=1 variant of VPMINUD)
  // =====================================================================
  cat = "EVEX VPMINUQ";
  {
    // xmm1 = [qword0=0xFFFFFFFFFFFFFFFF, qword1=5]
    // xmm2 = [qword0=1, qword1=10]
    // VPMINUQ xmm0, xmm1, xmm2 → [min(0xFFFF...,1)=1, min(5,10)=5]

    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0xFFFFFFFFFFFFFFFF, 0x0000000000000005);
    s.xmm[2] = xmm_from_u64(0x0000000000000001, 0x000000000000000A);

    // VPMINUQ xmm0, xmm1, xmm2
    // EVEX.128.66.0F38.W1: P1=0xF2(mm=10), P2=0xF5(W=1,vvvv=~1,pp=01), P3=0x08(xmm)
    // opcode=0x3B, modrm=0xC2(reg=xmm0,rm=xmm2)
    {
      TestCase tc;
      tc.name = "vpminuq xmm0,xmm1,xmm2: unsigned qword min";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0xF5, 0x08, 0x3B, 0xC2};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VPMINUD xmm0, xmm1, xmm2 (W=0, same opcode) for comparison
    // P2=0x75(W=0), same data but treated as dword min
    // xmm1 dwords: [0xFFFFFFFF, 0xFFFFFFFF, 5, 0]
    // xmm2 dwords: [1, 0, 10, 0]
    // → [min(0xFFFFFFFF,1)=1, min(0xFFFFFFFF,0)=0, min(5,10)=5, min(0,0)=0]
    {
      TestCase tc;
      tc.name = "vpminud xmm0,xmm1,xmm2: unsigned dword min (same opcode, W=0)";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0x75, 0x08, 0x3B, 0xC2};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // VPTESTMQ/VPTESTMW — test mask (was missing W=1 variants)
  // =====================================================================
  cat = "EVEX VPTESTM W1";
  {
    // VPTESTMQ k0, xmm1, xmm2 — qword AND test
    // xmm1 = [qword0=0xFF00FF00FF00FF00, qword1=0x0000000000000000]
    // xmm2 = [qword0=0x00FF00FF00000000, qword1=0x0000000000000001]
    // AND q0 = 0x0000000000000000 → 0 (not set), AND q1 = 0 → 0
    // Wait, let me use better values.
    // xmm1 = [qword0=0x0000000000000001, qword1=0x0000000000000000]
    // xmm2 = [qword0=0x0000000000000003, qword1=0x0000000000000002]
    // AND q0 = 1 (nonzero) → bit set, AND q1 = 0 → bit clear
    // → k0 = 01b = 1

    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0000000000000001, 0x0000000000000000);
    s.xmm[2] = xmm_from_u64(0x0000000000000003, 0x0000000000000002);

    // VPTESTMQ k0, xmm1, xmm2
    // EVEX.128.66.0F38.W1: P1=0xF2(mm=10), P2=0xF5(W=1,vvvv=~1,pp=01), P3=0x08
    // opcode=0x27, modrm=0xC2(k0,xmm2)
    // Then KMOVW eax, k0: C5 F8 93 C0
    {
      TestCase tc;
      tc.name = "vptestmq k0,xmm1,xmm2: qword AND test → k0=1";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0xF5, 0x08, 0x27, 0xC2,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // VPTESTMD k0, xmm1, xmm2 (W=0, same opcode) — dword test
    // dwords: [1, 0, 0, 0] AND [3, 0, 2, 0] = [1, 0, 0, 0]
    // → k0 = 0001b = 1
    {
      TestCase tc;
      tc.name = "vptestmd k0,xmm1,xmm2: dword AND test (W=0) → k0=1";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0x75, 0x08, 0x27, 0xC2,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // VPTESTMW k0, xmm1, xmm2 — word AND test
    // xmm1 = [words: 0x00FF, 0x0000, 0xFF00, 0x0000, 0x0001, 0x0000, 0x0000, 0x0000]
    // xmm2 = [words: 0x00FF, 0x1111, 0x00FF, 0x2222, 0x0002, 0x3333, 0x0000, 0x4444]
    // AND:     0x00FF  0x0000  0x0000  0x0000  0x0000  0x0000  0x0000  0x0000
    // Nonzero: w0=yes  w1=no   w2=no   w3=no   w4=no   w5=no   w6=no   w7=no
    // → k0 = 00000001b = 1

    ArchState sw = {};
    sw.rflags = 0x2;
    sw.xmm[1] = xmm_from_u32(0x000000FF, 0x0000FF00, 0x00000001, 0x00000000);
    sw.xmm[2] = xmm_from_u32(0x111100FF, 0x222200FF, 0x33330002, 0x44440000);

    // VPTESTMW k0, xmm1, xmm2
    // EVEX.128.66.0F38.W1: P1=0xF2, P2=0xF5(W=1), P3=0x08
    // opcode=0x26, modrm=0xC2
    {
      TestCase tc;
      tc.name = "vptestmw k0,xmm1,xmm2: word AND test → k0=1";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0xF5, 0x08, 0x26, 0xC2,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = sw;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // VPCMPEQQ/VPCMPGTQ xmm — 128-bit (was raising #UD, now fixed)
  // =====================================================================
  cat = "EVEX VPCMPEQQ/GTQQ xmm";
  {
    // xmm1 = [qword0=100, qword1=200]
    // xmm2 = [qword0=100, qword1=300]
    // VPCMPEQQ k0, xmm1, xmm2: q0 eq → bit0=1, q1 neq → bit1=0 → k0=1
    // VPCMPGTQ k0, xmm1, xmm2: q0 100>100=F, q1 200>300=F → k0=0

    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(100, 200);
    s.xmm[2] = xmm_from_u64(100, 300);

    // VPCMPEQQ k0, xmm1, xmm2
    // EVEX.128.66.0F38.W1: P1=0xF2, P2=0xF5(W=1,vvvv=~1,pp=01), P3=0x08
    // opcode=0x29, modrm=0xC2
    {
      TestCase tc;
      tc.name = "vpcmpeqq k0,xmm1,xmm2: qword equal xmm → k0=1";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0xF5, 0x08, 0x29, 0xC2,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // VPCMPGTQ k0, xmm1, xmm2 (q0: 100>100=F, q1: 200>300=F) → k0=0
    // opcode=0x37
    {
      TestCase tc;
      tc.name = "vpcmpgtq k0,xmm1,xmm2: qword GT xmm → k0=0";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0xF5, 0x08, 0x37, 0xC2,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // VPCMPGTQ with reversed operands (vvvv=xmm2, rm=xmm1)
    // k0, xmm2, xmm1: q0: 100>100=F, q1: 300>200=T → k0=2
    // P2 = W=1, vvvv=~2=1101, pp=01 = 0b1_1101_1_01 = 0xED
    // modrm = 11_000_001 = 0xC1 (k0, xmm1)
    {
      TestCase tc;
      tc.name = "vpcmpgtq k0,xmm2,xmm1: qword GT reversed → k0=2";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0xED, 0x08, 0x37, 0xC1,
                 0xC5, 0xF8, 0x93, 0xC0};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // EVEX VPMINUW (0F38 3A) — packed unsigned word minimum
  // =====================================================================
  cat = "EVEX VPMINUW";
  {
    ArchState s;
    s.rflags = 0x2;
    // Words (little-endian): lo={0x0010,0xFF00,0x0005,0x8000}, hi={0x0001,0x7FFF,0x1234,0xABCD}
    s.xmm[1] = xmm_from_u64(0x8000'0005'FF00'0010ULL, 0xABCD'1234'7FFF'0001ULL);
    // Words: lo={0x0020,0x00FF,0x0003,0x7FFF}, hi={0x0002,0x8000,0x1234,0x5678}
    s.xmm[2] = xmm_from_u64(0x7FFF'0003'00FF'0020ULL, 0x5678'1234'8000'0002ULL);
    // Expected min: lo={0x0010,0x00FF,0x0003,0x7FFF}, hi={0x0001,0x7FFF,0x1234,0x5678}

    // EVEX.128.66.0F38.WIG 3A /r: VPMINUW xmm0, xmm1, xmm2
    // P1=0xF2 (mm=10), P2=0x75 (W=0,vvvv=~1,pp=01), P3=0x08 (xmm)
    // modrm = 11_000_010 = 0xC2 (xmm0, xmm2)
    add_xmm("vpminuw xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x3A, 0xC2}, s, 0x7);

    // Test with all-equal words to verify equality case picks first operand
    ArchState s2;
    s2.rflags = 0x2;
    s2.xmm[1] = xmm_from_u64(0x1111222233334444ULL, 0x5555666677778888ULL);
    s2.xmm[2] = xmm_from_u64(0x1111222233334444ULL, 0x5555666677778888ULL);
    add_xmm("vpminuw xmm0,xmm1,xmm2: equal words",
            {0x62, 0xF2, 0x75, 0x08, 0x3A, 0xC2}, s2, 0x7);
  }

  // =====================================================================
  // EVEX VPMULLD/VPMULLQ (0F38 40) — packed multiply low dword/qword
  // =====================================================================
  cat = "EVEX VPMULLD/Q";
  {
    ArchState s;
    s.rflags = 0x2;
    // xmm1 = dwords: {7, 0x80000000, 100, 0xFFFFFFFF}
    s.xmm[1] = xmm_from_u64(0x80000000'00000007ULL, 0xFFFFFFFF'00000064ULL);
    // xmm2 = dwords: {3, 2, 5, 0xFFFFFFFF}
    s.xmm[2] = xmm_from_u64(0x00000002'00000003ULL, 0xFFFFFFFF'00000005ULL);

    // EVEX.128.66.0F38.W0 40 /r: VPMULLD xmm0, xmm1, xmm2
    // P1=0xF2 (mm=10), P2=0x75 (W=0,vvvv=~1,pp=01), P3=0x08 (xmm)
    // Expected: {7*3=21, 0x80000000*2=0 (low32), 100*5=500, 0xFFFFFFFF*0xFFFFFFFF=1 (low32)}
    add_xmm("vpmulld xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x40, 0xC2}, s, 0x7);

    // EVEX.128.66.0F38.W1 40 /r: VPMULLQ xmm0, xmm1, xmm2
    // P2=0xF5 (W=1,vvvv=~1,pp=01)
    // With same data interpreted as qwords:
    //   q0 = 0x80000000_00000007 * 0x00000002_00000003 = low64
    //   q1 = 0xFFFFFFFF_00000064 * 0xFFFFFFFF_00000005 = low64
    ArchState s2;
    s2.rflags = 0x2;
    s2.xmm[1] = xmm_from_u64(0x0000000000000007ULL, 0x0000000000000064ULL);
    s2.xmm[2] = xmm_from_u64(0x0000000000000003ULL, 0x0000000000000005ULL);
    // Expected: q0=7*3=21, q1=100*5=500
    add_xmm("vpmullq xmm0,xmm1,xmm2: small values",
            {0x62, 0xF2, 0xF5, 0x08, 0x40, 0xC2}, s2, 0x7);

    // VPMULLQ with large values to test low-64 truncation
    ArchState s3;
    s3.rflags = 0x2;
    s3.xmm[1] = xmm_from_u64(0xFFFFFFFFFFFFFFFFULL, 0x0000000100000000ULL);
    s3.xmm[2] = xmm_from_u64(0xFFFFFFFFFFFFFFFFULL, 0x0000000100000000ULL);
    // q0: (-1)*(-1) = 1 (low 64 bits)
    // q1: 2^32 * 2^32 = 2^64 → low 64 bits = 0
    add_xmm("vpmullq xmm0,xmm1,xmm2: overflow",
            {0x62, 0xF2, 0xF5, 0x08, 0x40, 0xC2}, s3, 0x7);
  }

  // =====================================================================
  // EVEX VPTERNLOGQ (0F3A 25, W=1) — qword ternary logic
  // Verify W=1 dispatch (VPTERNLOGQ) vs W=0 (VPTERNLOGD, already tested)
  // =====================================================================
  cat = "EVEX VPTERNLOGQ";
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0xFFFF0000FFFF0000ULL, 0xF0F0F0F00F0F0F0FULL);
    s.xmm[1] = xmm_from_u64(0xFF00FF00FF00FF00ULL, 0xCC33CC33CC33CC33ULL);
    s.xmm[2] = xmm_from_u64(0xF0F0F0F0F0F0F0F0ULL, 0xAAAA5555AAAA5555ULL);

    // VPTERNLOGQ xmm0, xmm1, xmm2, imm8
    // EVEX.NDS.128.66.0F3A.W1 25 /r ib
    // P0=0xF3(mmm=011), P1=0xF5(W=1,~vvvv=1110,1,pp=01), P2=0x08(128)
    // modrm=0xC2 (xmm0,xmm2), vvvv=xmm1

    // imm=0xF0: result = a (pass-through dst)
    add_xmm("vpternlogq 0xF0 (a)",
      {0x62, 0xF3, 0xF5, 0x08, 0x25, 0xC2, 0xF0}, s, 0x7);

    // imm=0x96: 3-way XOR: a ^ b ^ c
    add_xmm("vpternlogq 0x96 (a^b^c)",
      {0x62, 0xF3, 0xF5, 0x08, 0x25, 0xC2, 0x96}, s, 0x7);

    // imm=0x00: all zeros
    add_xmm("vpternlogq 0x00 (zeros)",
      {0x62, 0xF3, 0xF5, 0x08, 0x25, 0xC2, 0x00}, s, 0x7);
  }

  // =====================================================================
  // EVEX VPABSQ (0F38 1F, W=1) — absolute value of packed qwords
  // =====================================================================
  cat = "EVEX VPABSQ";
  {
    ArchState s;
    s.rflags = 0x2;
    // qword0 = -1 (0xFFFFFFFFFFFFFFFF), qword1 = -0x7FFFFFFFFFFFFFFF
    s.xmm[1] = xmm_from_u64(0xFFFFFFFFFFFFFFFFULL, 0x8000000000000001ULL);

    // EVEX.128.66.0F38.W1 1F /r: VPABSQ xmm0, xmm1
    // P1=0xF2(mm=10), P2=0xFD(W=1,vvvv=~0=1111,1,pp=01), P3=0x08(xmm)
    // modrm=11_000_001=0xC1 (xmm0, xmm1)
    add_xmm("vpabsq xmm0,xmm1: -1 and near-min",
            {0x62, 0xF2, 0xFD, 0x08, 0x1F, 0xC1}, s, 0x7);

    // Test with positive values (should be unchanged)
    ArchState s2;
    s2.rflags = 0x2;
    s2.xmm[1] = xmm_from_u64(42, 0x7FFFFFFFFFFFFFFFULL);
    add_xmm("vpabsq xmm0,xmm1: positive values",
            {0x62, 0xF2, 0xFD, 0x08, 0x1F, 0xC1}, s2, 0x7);

    // Test with INT64_MIN (0x8000000000000000) - result should be 0x8000000000000000
    // (same as PABSD with INT32_MIN, abs overflows)
    ArchState s3;
    s3.rflags = 0x2;
    s3.xmm[1] = xmm_from_u64(0x8000000000000000ULL, 0ULL);
    add_xmm("vpabsq xmm0,xmm1: INT64_MIN",
            {0x62, 0xF2, 0xFD, 0x08, 0x1F, 0xC1}, s3, 0x7);
  }

  // =====================================================================
  // EVEX VPROLVD/VPRORVD (0F38 15/14) — variable rotate dwords
  // =====================================================================
  cat = "EVEX variable rotate";
  {
    ArchState s;
    s.rflags = 0x2;
    // src dwords: {0x12345678, 0x80000001, 0xFF00FF00, 0x00000001}
    s.xmm[1] = xmm_from_u32(0x12345678, 0x80000001, 0xFF00FF00, 0x00000001);
    // rotate counts: {4, 1, 8, 0}
    s.xmm[2] = xmm_from_u32(4, 1, 8, 0);

    // EVEX.NDS.128.66.0F38.W0 15 /r: VPROLVD xmm0, xmm1, xmm2
    // P1=0xF2(mm=10), P2=0x75(W=0,vvvv=~1,pp=01), P3=0x08(xmm)
    // modrm=11_000_010=0xC2 (xmm0, xmm2)
    add_xmm("vprolvd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x15, 0xC2}, s, 0x7);

    // EVEX.NDS.128.66.0F38.W0 14 /r: VPRORVD xmm0, xmm1, xmm2
    add_xmm("vprorvd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x14, 0xC2}, s, 0x7);

    // VPROLVQ: W=1 variant
    // P2=0xF5(W=1,vvvv=~1,pp=01)
    ArchState s2;
    s2.rflags = 0x2;
    s2.xmm[1] = xmm_from_u64(0x123456789ABCDEF0ULL, 0x8000000000000001ULL);
    s2.xmm[2] = xmm_from_u64(4, 1);
    add_xmm("vprolvq xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0xF5, 0x08, 0x15, 0xC2}, s2, 0x7);

    // VPRORVQ: W=1 variant
    add_xmm("vprorvq xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0xF5, 0x08, 0x14, 0xC2}, s2, 0x7);
  }

  // =====================================================================
  // EVEX VPMADD52LUQ/HUQ (0F38 B4/B5) — 52-bit integer FMA
  // =====================================================================
  cat = "EVEX VPMADD52";
  {
    ArchState s;
    s.rflags = 0x2;
    // dst(xmm0) = accumulator: {100, 200}
    s.xmm[0] = xmm_from_u64(100, 200);
    // src1(xmm1) = first multiplicand: {3, 7}
    s.xmm[1] = xmm_from_u64(3, 7);
    // src2(xmm2) = second multiplicand: {10, 20}
    s.xmm[2] = xmm_from_u64(10, 20);

    // VPMADD52LUQ xmm0, xmm1, xmm2
    // EVEX.NDS.128.66.0F38.W1 B4 /r
    // P1=0xF2(mm=10), P2=0xF5(W=1,vvvv=~1,pp=01), P3=0x08(xmm)
    // modrm=11_000_010=0xC2 (xmm0,xmm2), vvvv=xmm1
    // Expected: q0 = 100 + low52(3*10) = 100+30 = 130
    //           q1 = 200 + low52(7*20) = 200+140 = 340
    add_xmm("vpmadd52luq xmm0,xmm1,xmm2: small",
            {0x62, 0xF2, 0xF5, 0x08, 0xB4, 0xC2}, s, 0x7);

    // VPMADD52HUQ xmm0, xmm1, xmm2
    // Expected: q0 = 100 + high52(3*10) = 100 + 0 = 100 (product < 2^52)
    //           q1 = 200 + high52(7*20) = 200 + 0 = 200
    add_xmm("vpmadd52huq xmm0,xmm1,xmm2: small (high=0)",
            {0x62, 0xF2, 0xF5, 0x08, 0xB5, 0xC2}, s, 0x7);

    // Test with larger values to exercise non-zero high part
    ArchState s2;
    s2.rflags = 0x2;
    s2.xmm[0] = xmm_from_u64(0, 0);
    // src1 = {2^51, 1}  src2 = {2, 1}
    // Product of 2^51 * 2 = 2^52, so low52 = 0, high52 = 1
    s2.xmm[1] = xmm_from_u64(1ULL << 51, 1);
    s2.xmm[2] = xmm_from_u64(2, 1);
    add_xmm("vpmadd52luq xmm0,xmm1,xmm2: 2^51*2",
            {0x62, 0xF2, 0xF5, 0x08, 0xB4, 0xC2}, s2, 0x7);
    add_xmm("vpmadd52huq xmm0,xmm1,xmm2: 2^51*2",
            {0x62, 0xF2, 0xF5, 0x08, 0xB5, 0xC2}, s2, 0x7);
  }

  // =====================================================================
  // EVEX VPOPCNTD/Q (0F38 55) — per-element population count
  // =====================================================================
  cat = "EVEX VPOPCNTD/Q";
  {
    ArchState s;
    s.rflags = 0x2;
    // VPOPCNTD xmm0, xmm1 (W=0)
    // 0xFF = 8 bits, 0x01 = 1 bit, 0x00 = 0 bits, 0x80000001 = 2 bits
    s.xmm[0] = {};
    s.xmm[1] = xmm_from_u32(0xFF, 0x01, 0x00, 0x80000001);
    // EVEX.128.66.0F38.W0 55 /r  modrm=C1 (xmm0,xmm1)
    add_xmm("vpopcntd xmm0,xmm1: basic",
            {0x62, 0xF2, 0x7D, 0x08, 0x55, 0xC1}, s, 0x3);

    // VPOPCNTQ xmm0, xmm1 (W=1)
    s.xmm[1] = xmm_from_u64(0xFFFFFFFFFFFFFFFFULL, 0x0000000100000001ULL);
    // EVEX.128.66.0F38.W1 55 /r
    add_xmm("vpopcntq xmm0,xmm1: all-1s and sparse",
            {0x62, 0xF2, 0xFD, 0x08, 0x55, 0xC1}, s, 0x3);
  }

  // =====================================================================
  // EVEX VPLZCNTD/Q (0F38 44) — per-element leading zero count
  // =====================================================================
  cat = "EVEX VPLZCNTD/Q";
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = {};
    // VPLZCNTD xmm0, xmm1 (W=0)
    // 0x00000001 → 31 leading zeros, 0x80000000 → 0, 0x00000000 → 32, 0x0000FFFF → 16
    s.xmm[1] = xmm_from_u32(0x00000001, 0x80000000, 0x00000000, 0x0000FFFF);
    // EVEX.128.66.0F38.W0 44 /r  modrm=C1
    add_xmm("vplzcntd xmm0,xmm1: basic",
            {0x62, 0xF2, 0x7D, 0x08, 0x44, 0xC1}, s, 0x3);

    // VPLZCNTQ xmm0, xmm1 (W=1)
    s.xmm[1] = xmm_from_u64(0x0000000000000001ULL, 0x0000000000000000ULL);
    // EVEX.128.66.0F38.W1 44 /r
    add_xmm("vplzcntq xmm0,xmm1: 1 and 0",
            {0x62, 0xF2, 0xFD, 0x08, 0x44, 0xC1}, s, 0x3);
  }

  // =====================================================================
  // EVEX VPCONFLICTD/Q (0F38 C4) — conflict detection
  // =====================================================================
  cat = "EVEX VPCONFLICTD/Q";
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = {};
    // VPCONFLICTD xmm0, xmm1 (W=0)
    // For each element, result is bitmask of *earlier* elements with same value
    // {5, 3, 5, 3} → d0=0(no earlier), d1=0(no earlier match), d2=1(matches d0), d3=2(matches d1)
    s.xmm[1] = xmm_from_u32(5, 3, 5, 3);
    // EVEX.128.66.0F38.W0 C4 /r  modrm=C1
    add_xmm("vpconflictd xmm0,xmm1: duplicates",
            {0x62, 0xF2, 0x7D, 0x08, 0xC4, 0xC1}, s, 0x3);

    // All unique: {1, 2, 3, 4} → all zeros
    s.xmm[1] = xmm_from_u32(1, 2, 3, 4);
    add_xmm("vpconflictd xmm0,xmm1: all unique",
            {0x62, 0xF2, 0x7D, 0x08, 0xC4, 0xC1}, s, 0x3);

    // VPCONFLICTQ xmm0, xmm1 (W=1)
    // {42, 42} → q0=0, q1=1(matches q0)
    s.xmm[1] = xmm_from_u64(42, 42);
    // EVEX.128.66.0F38.W1 C4 /r
    add_xmm("vpconflictq xmm0,xmm1: duplicate pair",
            {0x62, 0xF2, 0xFD, 0x08, 0xC4, 0xC1}, s, 0x3);
  }

  // =====================================================================
  // EVEX VPSHLDD/Q (0F3A 71) — immediate concatenate and shift left
  // =====================================================================
  cat = "EVEX VPSHLD";
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = {};
    // VPSHLDD xmm0, xmm1, xmm2, imm8 (W=0)
    // Concatenates src1:src2 as 64-bit pairs, shifts left by imm8, takes high 32 bits
    // For shift=0: result = src1 (identity)
    s.xmm[1] = xmm_from_u32(0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC, 0xDDDDDDDD);
    s.xmm[2] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
    // EVEX.NDS.128.66.0F3A.W0 71 /r imm8
    // P0=0xF3(mm=11), P1=0x75(W=0,vvvv=~1,pp=01), P2=0x08(xmm), modrm=0xC2, imm=0
    add_xmm("vpshldd xmm0,xmm1,xmm2,0: shift=0",
            {0x62, 0xF3, 0x75, 0x08, 0x71, 0xC2, 0x00}, s, 0x7);

    // shift=1: shifts the concatenated pair left by 1, so high bit of src2 enters low of result
    add_xmm("vpshldd xmm0,xmm1,xmm2,1: shift=1",
            {0x62, 0xF3, 0x75, 0x08, 0x71, 0xC2, 0x01}, s, 0x7);

    // VPSHLDQ xmm0, xmm1, xmm2, imm8 (W=1)
    // Concatenates src1:src2 as 128-bit pairs, shifts left by imm8, takes high 64 bits
    s.xmm[1] = xmm_from_u64(0xAAAAAAAABBBBBBBBULL, 0xCCCCCCCCDDDDDDDDULL);
    s.xmm[2] = xmm_from_u64(0x1111111122222222ULL, 0x3333333344444444ULL);
    // EVEX.NDS.128.66.0F3A.W1 71 /r imm8
    add_xmm("vpshldq xmm0,xmm1,xmm2,0: shift=0",
            {0x62, 0xF3, 0xF5, 0x08, 0x71, 0xC2, 0x00}, s, 0x7);
    add_xmm("vpshldq xmm0,xmm1,xmm2,4: shift=4",
            {0x62, 0xF3, 0xF5, 0x08, 0x71, 0xC2, 0x04}, s, 0x7);
  }

  // =====================================================================
  // EVEX VPSHRDD/Q (0F3A 73) — immediate concatenate and shift right
  // =====================================================================
  cat = "EVEX VPSHRD";
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = {};
    s.xmm[1] = xmm_from_u32(0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC, 0xDDDDDDDD);
    s.xmm[2] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
    // VPSHRDD xmm0, xmm1, xmm2, 0 (W=0)
    // EVEX.NDS.128.66.0F3A.W0 73 /r imm8
    add_xmm("vpshrdd xmm0,xmm1,xmm2,0: shift=0",
            {0x62, 0xF3, 0x75, 0x08, 0x73, 0xC2, 0x00}, s, 0x7);
    add_xmm("vpshrdd xmm0,xmm1,xmm2,1: shift=1",
            {0x62, 0xF3, 0x75, 0x08, 0x73, 0xC2, 0x01}, s, 0x7);

    // VPSHRDQ xmm0, xmm1, xmm2, 0 (W=1)
    s.xmm[1] = xmm_from_u64(0xAAAAAAAABBBBBBBBULL, 0xCCCCCCCCDDDDDDDDULL);
    s.xmm[2] = xmm_from_u64(0x1111111122222222ULL, 0x3333333344444444ULL);
    add_xmm("vpshrdq xmm0,xmm1,xmm2,0: shift=0",
            {0x62, 0xF3, 0xF5, 0x08, 0x73, 0xC2, 0x00}, s, 0x7);
    add_xmm("vpshrdq xmm0,xmm1,xmm2,4: shift=4",
            {0x62, 0xF3, 0xF5, 0x08, 0x73, 0xC2, 0x04}, s, 0x7);
  }

  // =====================================================================
  // EVEX VDBPSADBW (0F3A 42) — double block packed SAD
  // =====================================================================
  cat = "EVEX VDBPSADBW";
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = {};
    // All same bytes: SAD = 0 for all words
    s.xmm[1] = xmm_from_u64(0x0101010101010101ULL, 0x0101010101010101ULL);
    s.xmm[2] = xmm_from_u64(0x0101010101010101ULL, 0x0101010101010101ULL);
    // EVEX.NDS.128.66.0F3A.W0 42 /r imm8
    // P0=0xF3(mm=11), P1=0x75(W=0,vvvv=~1,pp=01), P2=0x08(xmm), modrm=0xC2, imm=0
    add_xmm("vdbpsadbw xmm0,xmm1,xmm2,0: equal",
            {0x62, 0xF3, 0x75, 0x08, 0x42, 0xC2, 0x00}, s, 0x7);

    // Different bytes
    s.xmm[1] = xmm_from_u64(0x0807060504030201ULL, 0x100F0E0D0C0B0A09ULL);
    s.xmm[2] = xmm_from_u64(0x0102030405060708ULL, 0x090A0B0C0D0E0F10ULL);
    add_xmm("vdbpsadbw xmm0,xmm1,xmm2,0: sequential",
            {0x62, 0xF3, 0x75, 0x08, 0x42, 0xC2, 0x00}, s, 0x7);
  }

  // =====================================================================
  // EVEX VPSHLDVD/Q (0F38 71) — variable concatenate and shift left
  // =====================================================================
  cat = "EVEX VPSHLDV";
  {
    ArchState s;
    s.rflags = 0x2;
    // VPSHLDVD xmm0, xmm1, xmm2 (W=0)
    // dst=xmm0 (accumulator), vvvv=xmm1 (src), r/m=xmm2 (shift counts)
    // Each dword: result = (dst:src1) << (count % 32), take upper 32 bits
    s.xmm[0] = xmm_from_u32(0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC, 0xDDDDDDDD);
    s.xmm[1] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
    s.xmm[2] = xmm_from_u32(0, 1, 4, 16);
    // EVEX.NDS.128.66.0F38.W0 71 /r
    add_xmm("vpshldvd xmm0,xmm1,xmm2: var shifts",
            {0x62, 0xF2, 0x75, 0x08, 0x71, 0xC2}, s, 0x7);

    // VPSHLDVQ xmm0, xmm1, xmm2 (W=1)
    s.xmm[0] = xmm_from_u64(0xAAAAAAAABBBBBBBBULL, 0xCCCCCCCCDDDDDDDDULL);
    s.xmm[1] = xmm_from_u64(0x1111111122222222ULL, 0x3333333344444444ULL);
    s.xmm[2] = xmm_from_u64(0, 4);
    add_xmm("vpshldvq xmm0,xmm1,xmm2: var shifts",
            {0x62, 0xF2, 0xF5, 0x08, 0x71, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // EVEX VPSHRDVD/Q (0F38 73) — variable concatenate and shift right
  // =====================================================================
  cat = "EVEX VPSHRDV";
  {
    ArchState s;
    s.rflags = 0x2;
    // VPSHRDVD xmm0, xmm1, xmm2 (W=0)
    s.xmm[0] = xmm_from_u32(0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC, 0xDDDDDDDD);
    s.xmm[1] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
    s.xmm[2] = xmm_from_u32(0, 1, 4, 16);
    // EVEX.NDS.128.66.0F38.W0 73 /r
    add_xmm("vpshrdvd xmm0,xmm1,xmm2: var shifts",
            {0x62, 0xF2, 0x75, 0x08, 0x73, 0xC2}, s, 0x7);

    // VPSHRDVQ xmm0, xmm1, xmm2 (W=1)
    s.xmm[0] = xmm_from_u64(0xAAAAAAAABBBBBBBBULL, 0xCCCCCCCCDDDDDDDDULL);
    s.xmm[1] = xmm_from_u64(0x1111111122222222ULL, 0x3333333344444444ULL);
    s.xmm[2] = xmm_from_u64(0, 4);
    add_xmm("vpshrdvq xmm0,xmm1,xmm2: var shifts",
            {0x62, 0xF2, 0xF5, 0x08, 0x73, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // EVEX VPMULTISHIFTQB (0F38 83) — per-byte multishift within qwords
  // =====================================================================
  cat = "EVEX VPMULTISHIFTQB";
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = {};
    // src (xmm2) = data qwords, ctrl (xmm1 via vvvv) = byte shift indices
    // Each byte in ctrl: take low 6 bits as bit index, extract 8 bits from src qword
    s.xmm[1] = xmm_from_u64(0x0000000000000000ULL, 0x0808080808080808ULL);  // ctrl: 0s then 8s
    s.xmm[2] = xmm_from_u64(0x0123456789ABCDEFULL, 0xFEDCBA9876543210ULL);  // data
    // EVEX.NDS.128.66.0F38.W1 83 /r
    // modrm=C2: dst=xmm0, r/m=xmm2, vvvv=xmm1
    add_xmm("vpmultishiftqb xmm0,xmm1,xmm2: shift=0,8",
            {0x62, 0xF2, 0xF5, 0x08, 0x83, 0xC2}, s, 0x3);

    // All shift indices = 0 (extract low byte repeated)
    s.xmm[1] = xmm_from_u64(0, 0);
    add_xmm("vpmultishiftqb xmm0,xmm1,xmm2: all shift=0",
            {0x62, 0xF2, 0xF5, 0x08, 0x83, 0xC2}, s, 0x3);
  }

  // =====================================================================
  // Basic EVEX 128-bit operations
  // =====================================================================
  {
    cat = "EVEX basic";

    auto add_xmm = [&](const std::string &name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    // VPADDD XMM0, XMM1, XMM2 (EVEX 128-bit integer add)
    // EVEX.128.66.0F.W0 FE /r
    // 62 F1 75 08 FE C2: L'L=00(128)
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(1, 2, 3, 4);
      s.xmm[2] = xmm_from_u32(10, 20, 30, 40);
      add_xmm("vpaddd xmm0,xmm1,xmm2 evex", {0x62, 0xF1, 0x75, 0x08, 0xFE, 0xC2}, s, 0x1);
    }

    // VPXORD XMM0, XMM1, XMM2 (EVEX 128-bit XOR)
    // EVEX.128.66.0F.W0 EF /r: 62 F1 75 08 EF C2
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF);
      s.xmm[2] = xmm_from_u64(0xAAAAAAAAAAAAAAAA, 0xAAAAAAAAAAAAAAAA);
      add_xmm("vpxord xmm0,xmm1,xmm2 evex", {0x62, 0xF1, 0x75, 0x08, 0xEF, 0xC2}, s, 0x1);
    }
  }

  // =====================================================================
  // EVEX writemask tests for instructions that were previously missing it
  // =====================================================================
  cat = "EVEX mask";
  {
    // VPABSD xmm0{k1}, xmm1 — merge masking with k1 = 0b0101
    // EVEX.128.66.0F38.W0 1E /r: 62 F2 7D 09 1E C1
    // P0=62, P1=F2(R=1,X=1,B=1,R'=1,mm=10), P2[vvvv]=7D(W=0,vvvv=1111,pp=01)
    // P3=09(z=0,L'L=00,b=0,V'=1,aaa=001)
    // opcode=1E, modrm=C1(mod=11,reg=xmm0,rm=xmm1)
    {
      TestCase tc;
      tc.name = "vpabsd xmm merge k1=0101b";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0x7D, 0x09, 0x1E, 0xC1};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_u32(0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF);
      tc.initial.xmm[1] = xmm_from_u32(0xFFFFFFF6, 0xFFFFFFF7, 0xFFFFFFF8, 0xFFFFFFF9);
      tc.initial.kregs[1] = 0x5;  // k1 = 0b0101
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x1;
      tc.kreg_mask = 0;
      tests.push_back(std::move(tc));
      // Expected: elem0=abs(-10)=10, elem1=preserved(0xDEADBEEF),
      //           elem2=abs(-8)=8, elem3=preserved(0xDEADBEEF)
    }

    // VPABSD xmm0{k1}{z}, xmm1 — zero masking with k1 = 0b0101
    // P3=89(z=1,L'L=00,b=0,V'=1,aaa=001)
    {
      TestCase tc;
      tc.name = "vpabsd xmm zero k1=0101b";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0x7D, 0x89, 0x1E, 0xC1};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_u32(0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF);
      tc.initial.xmm[1] = xmm_from_u32(0xFFFFFFF6, 0xFFFFFFF7, 0xFFFFFFF8, 0xFFFFFFF9);
      tc.initial.kregs[1] = 0x5;  // k1 = 0b0101
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x1;
      tc.kreg_mask = 0;
      tests.push_back(std::move(tc));
      // Expected: elem0=10, elem1=0, elem2=8, elem3=0
    }

    // VPMAXSD xmm0{k1}, xmm1, xmm2 — merge masking
    // EVEX.128.66.0F38.W0 3D /r: 62 F2 75 09 3D C2
    {
      TestCase tc;
      tc.name = "vpmaxsd xmm merge k1=0011b";
      tc.category = cat;
      tc.code = {0x62, 0xF2, 0x75, 0x09, 0x3D, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_u32(0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC, 0xDDDDDDDD);
      tc.initial.xmm[1] = xmm_from_u32(5, 10, 15, 20);
      tc.initial.xmm[2] = xmm_from_u32(3, 12, 8, 25);
      tc.initial.kregs[1] = 0x3;  // k1 = 0b0011
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x1;
      tc.kreg_mask = 0;
      tests.push_back(std::move(tc));
      // Expected: elem0=max(5,3)=5, elem1=max(10,12)=12,
      //           elem2=preserved, elem3=preserved
    }
  }

}

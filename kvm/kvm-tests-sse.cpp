#include "kvm-harness.h"

void add_sse_tests(std::vector<TestCase> &tests) {
  std::string cat;

  auto add_xmm = [&](const std::string &name, std::vector<u8> code, ArchState init,
                      u32 xmm_cmp) {
    tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
  };

  // =====================================================================
  // 23. SSE/SSE2 — packed and scalar floating-point operations
  // =====================================================================
  cat = "SSE";

  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // ADDPS XMM0, XMM1: 0F 58 C1
    add_xmm("addps xmm0,xmm1", {0x0F, 0x58, 0xC1}, s, 0x3);
    // SUBPS XMM0, XMM1: 0F 5C C1
    add_xmm("subps xmm0,xmm1", {0x0F, 0x5C, 0xC1}, s, 0x3);
    // MULPS XMM0, XMM1: 0F 59 C1
    add_xmm("mulps xmm0,xmm1", {0x0F, 0x59, 0xC1}, s, 0x3);
    // DIVPS XMM0, XMM1: 0F 5E C1
    add_xmm("divps xmm0,xmm1", {0x0F, 0x5E, 0xC1}, s, 0x3);
    // MINPS XMM0, XMM1: 0F 5D C1
    add_xmm("minps xmm0,xmm1", {0x0F, 0x5D, 0xC1}, s, 0x3);
    // MAXPS XMM0, XMM1: 0F 5F C1
    add_xmm("maxps xmm0,xmm1", {0x0F, 0x5F, 0xC1}, s, 0x3);

    // MOVAPS XMM2, XMM0: 0F 28 D0
    add_xmm("movaps xmm2,xmm0", {0x0F, 0x28, 0xD0}, s, 0x4);
    // MOVUPS XMM2, XMM0: 0F 10 D0
    add_xmm("movups xmm2,xmm0", {0x0F, 0x10, 0xD0}, s, 0x4);
  }

  // ADDPD/SUBPD/MULPD/DIVPD — packed double
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f64(1.5, 2.5);
    s.xmm[1] = xmm_from_f64(3.0, 4.0);

    // ADDPD XMM0, XMM1: 66 0F 58 C1
    add_xmm("addpd xmm0,xmm1", {0x66, 0x0F, 0x58, 0xC1}, s, 0x3);
    // SUBPD XMM0, XMM1: 66 0F 5C C1
    add_xmm("subpd xmm0,xmm1", {0x66, 0x0F, 0x5C, 0xC1}, s, 0x3);
    // MULPD XMM0, XMM1: 66 0F 59 C1
    add_xmm("mulpd xmm0,xmm1", {0x66, 0x0F, 0x59, 0xC1}, s, 0x3);
    // DIVPD XMM0, XMM1: 66 0F 5E C1
    add_xmm("divpd xmm0,xmm1", {0x66, 0x0F, 0x5E, 0xC1}, s, 0x3);
  }

  // ADDSS/SUBSS/MULSS/DIVSS — scalar single
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);

    // ADDSS XMM0, XMM1: F3 0F 58 C1
    add_xmm("addss xmm0,xmm1", {0xF3, 0x0F, 0x58, 0xC1}, s, 0x3);
    // SUBSS XMM0, XMM1: F3 0F 5C C1
    add_xmm("subss xmm0,xmm1", {0xF3, 0x0F, 0x5C, 0xC1}, s, 0x3);
    // MULSS XMM0, XMM1: F3 0F 59 C1
    add_xmm("mulss xmm0,xmm1", {0xF3, 0x0F, 0x59, 0xC1}, s, 0x3);
    // DIVSS XMM0, XMM1: F3 0F 5E C1
    add_xmm("divss xmm0,xmm1", {0xF3, 0x0F, 0x5E, 0xC1}, s, 0x3);
  }

  // ADDSD/SUBSD/MULSD/DIVSD — scalar double
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f64(1.5, 100.0);
    s.xmm[1] = xmm_from_f64(2.5, 200.0);

    // ADDSD XMM0, XMM1: F2 0F 58 C1
    add_xmm("addsd xmm0,xmm1", {0xF2, 0x0F, 0x58, 0xC1}, s, 0x3);
    // SUBSD XMM0, XMM1: F2 0F 5C C1
    add_xmm("subsd xmm0,xmm1", {0xF2, 0x0F, 0x5C, 0xC1}, s, 0x3);
    // MULSD XMM0, XMM1: F2 0F 59 C1
    add_xmm("mulsd xmm0,xmm1", {0xF2, 0x0F, 0x59, 0xC1}, s, 0x3);
    // DIVSD XMM0, XMM1: F2 0F 5E C1
    add_xmm("divsd xmm0,xmm1", {0xF2, 0x0F, 0x5E, 0xC1}, s, 0x3);
  }

  // SSE2 integer — PADDB/PADDW/PADDD/PADDQ, PSUBB, PAND/POR/PXOR
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x1011121314151617, 0x18191A1B1C1D1E1F);

    // PADDB XMM0, XMM1: 66 0F FC C1
    add_xmm("paddb xmm0,xmm1", {0x66, 0x0F, 0xFC, 0xC1}, s, 0x3);
    // PADDW XMM0, XMM1: 66 0F FD C1
    add_xmm("paddw xmm0,xmm1", {0x66, 0x0F, 0xFD, 0xC1}, s, 0x3);
    // PADDD XMM0, XMM1: 66 0F FE C1
    add_xmm("paddd xmm0,xmm1", {0x66, 0x0F, 0xFE, 0xC1}, s, 0x3);
    // PADDQ XMM0, XMM1: 66 0F D4 C1
    add_xmm("paddq xmm0,xmm1", {0x66, 0x0F, 0xD4, 0xC1}, s, 0x3);
    // PSUBB XMM0, XMM1: 66 0F F8 C1
    add_xmm("psubb xmm0,xmm1", {0x66, 0x0F, 0xF8, 0xC1}, s, 0x3);
    // PAND XMM0, XMM1: 66 0F DB C1
    add_xmm("pand xmm0,xmm1", {0x66, 0x0F, 0xDB, 0xC1}, s, 0x3);
    // POR XMM0, XMM1: 66 0F EB C1
    add_xmm("por xmm0,xmm1", {0x66, 0x0F, 0xEB, 0xC1}, s, 0x3);
    // PXOR XMM0, XMM1: 66 0F EF C1
    add_xmm("pxor xmm0,xmm1", {0x66, 0x0F, 0xEF, 0xC1}, s, 0x3);
  }

  // SSE2 shuffle/unpack
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // SHUFPS XMM0, XMM1, 0x1B: 0F C6 C1 1B (reverse order)
    add_xmm("shufps xmm0,xmm1,0x1b", {0x0F, 0xC6, 0xC1, 0x1B}, s, 0x3);
    // UNPCKLPS XMM0, XMM1: 0F 14 C1
    add_xmm("unpcklps xmm0,xmm1", {0x0F, 0x14, 0xC1}, s, 0x3);
    // UNPCKHPS XMM0, XMM1: 0F 15 C1
    add_xmm("unpckhps xmm0,xmm1", {0x0F, 0x15, 0xC1}, s, 0x3);
  }

  // SSE conversions
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.5f, 2.7f, -3.2f, 4.9f);

    // CVTPS2DQ XMM1, XMM0: 66 0F 5B C8 (ModRM: reg=1, rm=0)
    add_xmm("cvtps2dq xmm1,xmm0", {0x66, 0x0F, 0x5B, 0xC8}, s, 0x2);

    // CVTTPS2DQ XMM1, XMM0: F3 0F 5B C8
    add_xmm("cvttps2dq xmm1,xmm0", {0xF3, 0x0F, 0x5B, 0xC8}, s, 0x2);

    // CVTDQ2PS XMM1, XMM0: 0F 5B C8 (with integer input)
    ArchState si = {};
    si.rflags = 0x2;
    si.xmm[0] = xmm_from_u32(1, 2, 0xFFFFFFFF, 100);
    add_xmm("cvtdq2ps xmm1,xmm0", {0x0F, 0x5B, 0xC8}, si, 0x2);
  }

  // MOVD/MOVQ — GPR ↔ XMM
  {
    ArchState s;
    s.rflags = 0x2;
    s.rax = 0x123456789ABCDEF0;

    // MOVQ XMM0, RAX: 66 48 0F 6E C0
    add_xmm("movq xmm0,rax", {0x66, 0x48, 0x0F, 0x6E, 0xC0}, s, 0x1);

    // MOVD XMM0, EAX: 66 0F 6E C0
    add_xmm("movd xmm0,eax", {0x66, 0x0F, 0x6E, 0xC0}, s, 0x1);

    // MOVQ RAX, XMM1: 66 48 0F 7E C8 (reg=1, rm=0 → XMM1 to RAX)
    ArchState s2 = {};
    s2.rflags = 0x2;
    s2.xmm[1] = xmm_from_u64(0xDEADBEEFCAFEBABE, 0x1234567890ABCDEF);
    // MOVQ RAX, XMM1: 66 REX.W 0F 7E C8 (ModRM: reg=xmm1=1, rm=rax=0)
    tests.push_back({"movq rax,xmm1", cat, {0x66, 0x48, 0x0F, 0x7E, 0xC8},
                      s2, FL_ALL, 0x0, false});
  }

  // SSE compare — UCOMISS sets EFLAGS
  {
    ArchState s;
    s.rflags = 0x2;

    // Equal
    s.xmm[0] = xmm_from_f32(1.0f, 0, 0, 0);
    s.xmm[1] = xmm_from_f32(1.0f, 0, 0, 0);
    // UCOMISS XMM0, XMM1: 0F 2E C1
    add_xmm("ucomiss eq", {0x0F, 0x2E, 0xC1}, s, 0x0);

    // Less
    s.xmm[0] = xmm_from_f32(1.0f, 0, 0, 0);
    s.xmm[1] = xmm_from_f32(2.0f, 0, 0, 0);
    add_xmm("ucomiss lt", {0x0F, 0x2E, 0xC1}, s, 0x0);

    // Greater
    s.xmm[0] = xmm_from_f32(3.0f, 0, 0, 0);
    s.xmm[1] = xmm_from_f32(2.0f, 0, 0, 0);
    add_xmm("ucomiss gt", {0x0F, 0x2E, 0xC1}, s, 0x0);

    // UCOMISD XMM0, XMM1: 66 0F 2E C1
    s.xmm[0] = xmm_from_f64(1.5, 0);
    s.xmm[1] = xmm_from_f64(1.5, 0);
    add_xmm("ucomisd eq", {0x66, 0x0F, 0x2E, 0xC1}, s, 0x0);

    s.xmm[0] = xmm_from_f64(1.0, 0);
    s.xmm[1] = xmm_from_f64(2.0, 0);
    add_xmm("ucomisd lt", {0x66, 0x0F, 0x2E, 0xC1}, s, 0x0);
  }

  // Upper registers (XMM8+) via REX prefix
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[8]  = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[9]  = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);

    // ADDPS XMM8, XMM9: 45 0F 58 C1 (REX.R+B)
    add_xmm("addps xmm8,xmm9", {0x45, 0x0F, 0x58, 0xC1}, s, 0x300);
  }

  // SSE logical — ANDPS/ANDNPS/ORPS/XORPS
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0xFF00FF00FF00FF00, 0x0F0F0F0F0F0F0F0F);
    s.xmm[1] = xmm_from_u64(0x00FF00FF00FF00FF, 0xF0F0F0F0F0F0F0F0);

    // ANDPS XMM0, XMM1: 0F 54 C1
    add_xmm("andps xmm0,xmm1", {0x0F, 0x54, 0xC1}, s, 0x3);
    // ANDNPS XMM0, XMM1: 0F 55 C1  (NOT(xmm0) AND xmm1)
    add_xmm("andnps xmm0,xmm1", {0x0F, 0x55, 0xC1}, s, 0x3);
    // ORPS XMM0, XMM1: 0F 56 C1
    add_xmm("orps xmm0,xmm1", {0x0F, 0x56, 0xC1}, s, 0x3);
    // XORPS XMM0, XMM1: 0F 57 C1
    add_xmm("xorps xmm0,xmm1", {0x0F, 0x57, 0xC1}, s, 0x3);

    // ANDPD XMM0, XMM1: 66 0F 54 C1
    add_xmm("andpd xmm0,xmm1", {0x66, 0x0F, 0x54, 0xC1}, s, 0x3);
    // ANDNPD XMM0, XMM1: 66 0F 55 C1
    add_xmm("andnpd xmm0,xmm1", {0x66, 0x0F, 0x55, 0xC1}, s, 0x3);
    // ORPD XMM0, XMM1: 66 0F 56 C1
    add_xmm("orpd xmm0,xmm1", {0x66, 0x0F, 0x56, 0xC1}, s, 0x3);
    // XORPD XMM0, XMM1: 66 0F 57 C1
    add_xmm("xorpd xmm0,xmm1", {0x66, 0x0F, 0x57, 0xC1}, s, 0x3);
  }

  // SSE SQRT — SQRTPS/SQRTPD/SQRTSS/SQRTSD
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(4.0f, 9.0f, 16.0f, 25.0f);

    // SQRTPS XMM1, XMM0: 0F 51 C8
    add_xmm("sqrtps xmm1,xmm0", {0x0F, 0x51, 0xC8}, s, 0x2);
    // SQRTSS XMM1, XMM0: F3 0F 51 C8
    add_xmm("sqrtss xmm1,xmm0", {0xF3, 0x0F, 0x51, 0xC8}, s, 0x2);

    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(4.0, 9.0);

    // SQRTPD XMM1, XMM0: 66 0F 51 C8
    add_xmm("sqrtpd xmm1,xmm0", {0x66, 0x0F, 0x51, 0xC8}, sd, 0x2);
    // SQRTSD XMM1, XMM0: F2 0F 51 C8
    add_xmm("sqrtsd xmm1,xmm0", {0xF2, 0x0F, 0x51, 0xC8}, sd, 0x2);
  }

  // SSE MIN/MAX — remaining variants (MINPD/MAXPD/MINSS/MAXSS/MINSD/MAXSD)
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 8.0f, 3.0f, 6.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 2.0f, 7.0f, 4.0f);

    // MINSS XMM0, XMM1: F3 0F 5D C1
    add_xmm("minss xmm0,xmm1", {0xF3, 0x0F, 0x5D, 0xC1}, s, 0x3);
    // MAXSS XMM0, XMM1: F3 0F 5F C1
    add_xmm("maxss xmm0,xmm1", {0xF3, 0x0F, 0x5F, 0xC1}, s, 0x3);

    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(1.5, 8.5);
    sd.xmm[1] = xmm_from_f64(5.5, 2.5);

    // MINPD XMM0, XMM1: 66 0F 5D C1
    add_xmm("minpd xmm0,xmm1", {0x66, 0x0F, 0x5D, 0xC1}, sd, 0x3);
    // MAXPD XMM0, XMM1: 66 0F 5F C1
    add_xmm("maxpd xmm0,xmm1", {0x66, 0x0F, 0x5F, 0xC1}, sd, 0x3);
    // MINSD XMM0, XMM1: F2 0F 5D C1
    add_xmm("minsd xmm0,xmm1", {0xF2, 0x0F, 0x5D, 0xC1}, sd, 0x3);
    // MAXSD XMM0, XMM1: F2 0F 5F C1
    add_xmm("maxsd xmm0,xmm1", {0xF2, 0x0F, 0x5F, 0xC1}, sd, 0x3);
  }

  // SSE comparison — CMPPS/CMPPD
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 5.0f, 3.0f, 3.0f);
    s.xmm[1] = xmm_from_f32(2.0f, 5.0f, 1.0f, 4.0f);

    // CMPPS XMM0, XMM1, 0 (EQ): 0F C2 C1 00
    add_xmm("cmpps eq", {0x0F, 0xC2, 0xC1, 0x00}, s, 0x3);
    // CMPPS XMM0, XMM1, 1 (LT): 0F C2 C1 01
    add_xmm("cmpps lt", {0x0F, 0xC2, 0xC1, 0x01}, s, 0x3);
    // CMPPS XMM0, XMM1, 2 (LE): 0F C2 C1 02
    add_xmm("cmpps le", {0x0F, 0xC2, 0xC1, 0x02}, s, 0x3);

    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(1.0, 5.0);
    sd.xmm[1] = xmm_from_f64(2.0, 5.0);

    // CMPPD XMM0, XMM1, 0 (EQ): 66 0F C2 C1 00
    add_xmm("cmppd eq", {0x66, 0x0F, 0xC2, 0xC1, 0x00}, sd, 0x3);
    // CMPPD XMM0, XMM1, 1 (LT): 66 0F C2 C1 01
    add_xmm("cmppd lt", {0x66, 0x0F, 0xC2, 0xC1, 0x01}, sd, 0x3);

    // CMPSS XMM0, XMM1, 0 (EQ): F3 0F C2 C1 00
    add_xmm("cmpss eq", {0xF3, 0x0F, 0xC2, 0xC1, 0x00}, s, 0x3);
    // CMPSD XMM0, XMM1, 1 (LT): F2 0F C2 C1 01
    add_xmm("cmpsd lt", {0xF2, 0x0F, 0xC2, 0xC1, 0x01}, sd, 0x3);
  }

  // SSE2 integer — PSUBW/PSUBD/PSUBQ, PANDN, PCMPEQB/PCMPEQW/PCMPEQD, PCMPGTB
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x0001020304050607, 0x08090A0B0C0D0E0F);

    // PSUBW XMM0, XMM1: 66 0F F9 C1
    add_xmm("psubw xmm0,xmm1", {0x66, 0x0F, 0xF9, 0xC1}, s, 0x3);
    // PSUBD XMM0, XMM1: 66 0F FA C1
    add_xmm("psubd xmm0,xmm1", {0x66, 0x0F, 0xFA, 0xC1}, s, 0x3);
    // PSUBQ XMM0, XMM1: 66 0F FB C1
    add_xmm("psubq xmm0,xmm1", {0x66, 0x0F, 0xFB, 0xC1}, s, 0x3);
    // PANDN XMM0, XMM1: 66 0F DF C1
    add_xmm("pandn xmm0,xmm1", {0x66, 0x0F, 0xDF, 0xC1}, s, 0x3);

    // PCMPEQB XMM0, XMM1: 66 0F 74 C1
    add_xmm("pcmpeqb xmm0,xmm1", {0x66, 0x0F, 0x74, 0xC1}, s, 0x3);
    // PCMPEQW XMM0, XMM1: 66 0F 75 C1
    add_xmm("pcmpeqw xmm0,xmm1", {0x66, 0x0F, 0x75, 0xC1}, s, 0x3);
    // PCMPEQD XMM0, XMM1: 66 0F 76 C1
    add_xmm("pcmpeqd xmm0,xmm1", {0x66, 0x0F, 0x76, 0xC1}, s, 0x3);
    // PCMPGTB XMM0, XMM1: 66 0F 64 C1
    add_xmm("pcmpgtb xmm0,xmm1", {0x66, 0x0F, 0x64, 0xC1}, s, 0x3);
    // PCMPGTW XMM0, XMM1: 66 0F 65 C1
    add_xmm("pcmpgtw xmm0,xmm1", {0x66, 0x0F, 0x65, 0xC1}, s, 0x3);
    // PCMPGTD XMM0, XMM1: 66 0F 66 C1
    add_xmm("pcmpgtd xmm0,xmm1", {0x66, 0x0F, 0x66, 0xC1}, s, 0x3);
  }

  // SSE2 shuffle — PSHUFD, SHUFPD, UNPCKLPD, UNPCKHPD
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);

    // PSHUFD XMM1, XMM0, 0x1B (reverse): 66 0F 70 C8 1B
    add_xmm("pshufd xmm1,xmm0,0x1b", {0x66, 0x0F, 0x70, 0xC8, 0x1B}, s, 0x2);
    // PSHUFD XMM1, XMM0, 0x00 (broadcast low): 66 0F 70 C8 00
    add_xmm("pshufd xmm1,xmm0,0x00", {0x66, 0x0F, 0x70, 0xC8, 0x00}, s, 0x2);

    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(1.0, 2.0);
    sd.xmm[1] = xmm_from_f64(3.0, 4.0);

    // SHUFPD XMM0, XMM1, 0x01: 66 0F C6 C1 01
    add_xmm("shufpd xmm0,xmm1,0x01", {0x66, 0x0F, 0xC6, 0xC1, 0x01}, sd, 0x3);
    // UNPCKLPD XMM0, XMM1: 66 0F 14 C1
    add_xmm("unpcklpd xmm0,xmm1", {0x66, 0x0F, 0x14, 0xC1}, sd, 0x3);
    // UNPCKHPD XMM0, XMM1: 66 0F 15 C1
    add_xmm("unpckhpd xmm0,xmm1", {0x66, 0x0F, 0x15, 0xC1}, sd, 0x3);
  }

  // SSE2 data movement — MOVAPD/MOVUPD/MOVDQA/MOVDQU
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0xDEADBEEFCAFEBABE, 0x123456789ABCDEF0);

    // MOVAPD XMM2, XMM0: 66 0F 28 D0
    add_xmm("movapd xmm2,xmm0", {0x66, 0x0F, 0x28, 0xD0}, s, 0x4);
    // MOVUPD XMM2, XMM0: 66 0F 10 D0
    add_xmm("movupd xmm2,xmm0", {0x66, 0x0F, 0x10, 0xD0}, s, 0x4);
    // MOVDQA XMM2, XMM0: 66 0F 6F D0
    add_xmm("movdqa xmm2,xmm0", {0x66, 0x0F, 0x6F, 0xD0}, s, 0x4);
    // MOVDQU XMM2, XMM0: F3 0F 6F D0
    add_xmm("movdqu xmm2,xmm0", {0xF3, 0x0F, 0x6F, 0xD0}, s, 0x4);
  }

  // SSE2 pack/unpack integer
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u32(0x00010002, 0x00030004, 0x00050006, 0x00070008);
    s.xmm[1] = xmm_from_u32(0x000A000B, 0x000C000D, 0x000E000F, 0x00100011);

    // PACKSSWB XMM0, XMM1: 66 0F 63 C1
    add_xmm("packsswb xmm0,xmm1", {0x66, 0x0F, 0x63, 0xC1}, s, 0x3);
    // PACKUSWB XMM0, XMM1: 66 0F 67 C1
    add_xmm("packuswb xmm0,xmm1", {0x66, 0x0F, 0x67, 0xC1}, s, 0x3);
    // PACKSSDW XMM0, XMM1: 66 0F 6B C1
    add_xmm("packssdw xmm0,xmm1", {0x66, 0x0F, 0x6B, 0xC1}, s, 0x3);

    // PUNPCKLBW XMM0, XMM1: 66 0F 60 C1
    add_xmm("punpcklbw xmm0,xmm1", {0x66, 0x0F, 0x60, 0xC1}, s, 0x3);
    // PUNPCKLWD XMM0, XMM1: 66 0F 61 C1
    add_xmm("punpcklwd xmm0,xmm1", {0x66, 0x0F, 0x61, 0xC1}, s, 0x3);
    // PUNPCKLDQ XMM0, XMM1: 66 0F 62 C1
    add_xmm("punpckldq xmm0,xmm1", {0x66, 0x0F, 0x62, 0xC1}, s, 0x3);
    // PUNPCKLQDQ XMM0, XMM1: 66 0F 6C C1
    add_xmm("punpcklqdq xmm0,xmm1", {0x66, 0x0F, 0x6C, 0xC1}, s, 0x3);
    // PUNPCKHBW XMM0, XMM1: 66 0F 68 C1
    add_xmm("punpckhbw xmm0,xmm1", {0x66, 0x0F, 0x68, 0xC1}, s, 0x3);
    // PUNPCKHWD XMM0, XMM1: 66 0F 69 C1
    add_xmm("punpckhwd xmm0,xmm1", {0x66, 0x0F, 0x69, 0xC1}, s, 0x3);
    // PUNPCKHDQ XMM0, XMM1: 66 0F 6A C1
    add_xmm("punpckhdq xmm0,xmm1", {0x66, 0x0F, 0x6A, 0xC1}, s, 0x3);
    // PUNPCKHQDQ XMM0, XMM1: 66 0F 6D C1
    add_xmm("punpckhqdq xmm0,xmm1", {0x66, 0x0F, 0x6D, 0xC1}, s, 0x3);
  }

  // SSE2 shift — PSLLW/PSLLD/PSLLQ/PSRLW/PSRLD/PSRLQ/PSRAW/PSRAD (imm8)
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);

    // PSLLW XMM0, 4: 66 0F 71 F0 04
    add_xmm("psllw xmm0,4", {0x66, 0x0F, 0x71, 0xF0, 0x04}, s, 0x1);
    // PSLLD XMM0, 4: 66 0F 72 F0 04
    add_xmm("pslld xmm0,4", {0x66, 0x0F, 0x72, 0xF0, 0x04}, s, 0x1);
    // PSLLQ XMM0, 4: 66 0F 73 F0 04
    add_xmm("psllq xmm0,4", {0x66, 0x0F, 0x73, 0xF0, 0x04}, s, 0x1);
    // PSRLW XMM0, 4: 66 0F 71 D0 04
    add_xmm("psrlw xmm0,4", {0x66, 0x0F, 0x71, 0xD0, 0x04}, s, 0x1);
    // PSRLD XMM0, 4: 66 0F 72 D0 04
    add_xmm("psrld xmm0,4", {0x66, 0x0F, 0x72, 0xD0, 0x04}, s, 0x1);
    // PSRLQ XMM0, 4: 66 0F 73 D0 04
    add_xmm("psrlq xmm0,4", {0x66, 0x0F, 0x73, 0xD0, 0x04}, s, 0x1);
    // PSRAW XMM0, 4: 66 0F 71 E0 04
    add_xmm("psraw xmm0,4", {0x66, 0x0F, 0x71, 0xE0, 0x04}, s, 0x1);
    // PSRAD XMM0, 4: 66 0F 72 E0 04
    add_xmm("psrad xmm0,4", {0x66, 0x0F, 0x72, 0xE0, 0x04}, s, 0x1);
  }

  // SSE2 multiply — PMULLW/PMULHW/PMULHUW/PMULUDQ/PMADDWD
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
    s.xmm[1] = xmm_from_u64(0x0010002000300040, 0x0050006000700080);

    // PMULLW XMM0, XMM1: 66 0F D5 C1
    add_xmm("pmullw xmm0,xmm1", {0x66, 0x0F, 0xD5, 0xC1}, s, 0x3);
    // PMULHW XMM0, XMM1: 66 0F E5 C1
    add_xmm("pmulhw xmm0,xmm1", {0x66, 0x0F, 0xE5, 0xC1}, s, 0x3);
    // PMULHUW XMM0, XMM1: 66 0F E4 C1
    add_xmm("pmulhuw xmm0,xmm1", {0x66, 0x0F, 0xE4, 0xC1}, s, 0x3);
    // PMULUDQ XMM0, XMM1: 66 0F F4 C1
    add_xmm("pmuludq xmm0,xmm1", {0x66, 0x0F, 0xF4, 0xC1}, s, 0x3);
    // PMADDWD XMM0, XMM1: 66 0F F5 C1
    add_xmm("pmaddwd xmm0,xmm1", {0x66, 0x0F, 0xF5, 0xC1}, s, 0x3);
  }

  // SSE2 saturating arithmetic — PADDSB/PADDSW/PADDUSB/PADDUSW/PSUBSB/PSUBSW/PSUBUSB/PSUBUSW
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x7F80FF01FE027E81, 0x7FFF800100FEFF01);
    s.xmm[1] = xmm_from_u64(0x0180017F01FE8001, 0x00017FFF01010101);

    // PADDSB XMM0, XMM1: 66 0F EC C1
    add_xmm("paddsb xmm0,xmm1", {0x66, 0x0F, 0xEC, 0xC1}, s, 0x3);
    // PADDSW XMM0, XMM1: 66 0F ED C1
    add_xmm("paddsw xmm0,xmm1", {0x66, 0x0F, 0xED, 0xC1}, s, 0x3);
    // PADDUSB XMM0, XMM1: 66 0F DC C1
    add_xmm("paddusb xmm0,xmm1", {0x66, 0x0F, 0xDC, 0xC1}, s, 0x3);
    // PADDUSW XMM0, XMM1: 66 0F DD C1
    add_xmm("paddusw xmm0,xmm1", {0x66, 0x0F, 0xDD, 0xC1}, s, 0x3);
    // PSUBSB XMM0, XMM1: 66 0F E8 C1
    add_xmm("psubsb xmm0,xmm1", {0x66, 0x0F, 0xE8, 0xC1}, s, 0x3);
    // PSUBSW XMM0, XMM1: 66 0F E9 C1
    add_xmm("psubsw xmm0,xmm1", {0x66, 0x0F, 0xE9, 0xC1}, s, 0x3);
    // PSUBUSB XMM0, XMM1: 66 0F D8 C1
    add_xmm("psubusb xmm0,xmm1", {0x66, 0x0F, 0xD8, 0xC1}, s, 0x3);
    // PSUBUSW XMM0, XMM1: 66 0F D9 C1
    add_xmm("psubusw xmm0,xmm1", {0x66, 0x0F, 0xD9, 0xC1}, s, 0x3);
  }

  // SSE2 average/SAD — PAVGB/PAVGW/PSADBW
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x1011121314151617, 0x18191A1B1C1D1E1F);

    // PAVGB XMM0, XMM1: 66 0F E0 C1
    add_xmm("pavgb xmm0,xmm1", {0x66, 0x0F, 0xE0, 0xC1}, s, 0x3);
    // PAVGW XMM0, XMM1: 66 0F E3 C1
    add_xmm("pavgw xmm0,xmm1", {0x66, 0x0F, 0xE3, 0xC1}, s, 0x3);
    // PSADBW XMM0, XMM1: 66 0F F6 C1
    add_xmm("psadbw xmm0,xmm1", {0x66, 0x0F, 0xF6, 0xC1}, s, 0x3);
  }

  // NOTE: RCPPS/RCPSS/RSQRTPS/RSQRTSS are approximate instructions with
  // implementation-defined precision, so we cannot do exact comparison.

  // SSE conversions — remaining variants
  {
    // CVTDQ2PD: F3 0F E6 C8 (xmm1,xmm0)
    ArchState si = {};
    si.rflags = 0x2;
    si.xmm[0] = xmm_from_u32(1, 0xFFFFFFFF, 100, 0);  // low 2 dwords used
    add_xmm("cvtdq2pd xmm1,xmm0", {0xF3, 0x0F, 0xE6, 0xC8}, si, 0x2);

    // CVTPD2DQ: F2 0F E6 C8 (xmm1,xmm0)
    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(1.5, -2.5);
    add_xmm("cvtpd2dq xmm1,xmm0", {0xF2, 0x0F, 0xE6, 0xC8}, sd, 0x2);

    // CVTTPD2DQ: 66 0F E6 C8 (xmm1,xmm0)
    add_xmm("cvttpd2dq xmm1,xmm0", {0x66, 0x0F, 0xE6, 0xC8}, sd, 0x2);

    // CVTPS2PD: 0F 5A C8 (xmm1,xmm0)
    ArchState sp = {};
    sp.rflags = 0x2;
    sp.xmm[0] = xmm_from_f32(1.5f, -2.5f, 3.0f, 4.0f);
    add_xmm("cvtps2pd xmm1,xmm0", {0x0F, 0x5A, 0xC8}, sp, 0x2);

    // CVTPD2PS: 66 0F 5A C8 (xmm1,xmm0)
    add_xmm("cvtpd2ps xmm1,xmm0", {0x66, 0x0F, 0x5A, 0xC8}, sd, 0x2);

    // CVTSS2SD: F3 0F 5A C8 (xmm1,xmm0)
    add_xmm("cvtss2sd xmm1,xmm0", {0xF3, 0x0F, 0x5A, 0xC8}, sp, 0x2);

    // CVTSD2SS: F2 0F 5A C8 (xmm1,xmm0)
    add_xmm("cvtsd2ss xmm1,xmm0", {0xF2, 0x0F, 0x5A, 0xC8}, sd, 0x2);

    // CVTSI2SS: F3 0F 2A C0 (xmm0,eax)
    ArchState sg = {};
    sg.rflags = 0x2;
    sg.rax = 42;
    add_xmm("cvtsi2ss xmm0,eax", {0xF3, 0x0F, 0x2A, 0xC0}, sg, 0x1);

    // CVTSI2SD: F2 0F 2A C0 (xmm0,eax)
    add_xmm("cvtsi2sd xmm0,eax", {0xF2, 0x0F, 0x2A, 0xC0}, sg, 0x1);

    // CVTSI2SS with REX.W (64-bit): F3 48 0F 2A C0 (xmm0,rax)
    ArchState sg64 = {};
    sg64.rflags = 0x2;
    sg64.rax = 0x100000042;
    add_xmm("cvtsi2ss xmm0,rax", {0xF3, 0x48, 0x0F, 0x2A, 0xC0}, sg64, 0x1);

    // CVTSI2SD with REX.W: F2 48 0F 2A C0 (xmm0,rax)
    add_xmm("cvtsi2sd xmm0,rax", {0xF2, 0x48, 0x0F, 0x2A, 0xC0}, sg64, 0x1);

    // CVTSS2SI: F3 0F 2D C0 (eax,xmm0) — result in RAX
    ArchState sf = {};
    sf.rflags = 0x2;
    sf.xmm[0] = xmm_from_f32(42.5f, 0, 0, 0);
    tests.push_back({"cvtss2si eax,xmm0", cat, {0xF3, 0x0F, 0x2D, 0xC0},
                      sf, FL_ALL, 0x0, false});

    // CVTSD2SI: F2 0F 2D C0 (eax,xmm0)
    ArchState sfd = {};
    sfd.rflags = 0x2;
    sfd.xmm[0] = xmm_from_f64(42.5, 0);
    tests.push_back({"cvtsd2si eax,xmm0", cat, {0xF2, 0x0F, 0x2D, 0xC0},
                      sfd, FL_ALL, 0x0, false});

    // CVTTSS2SI: F3 0F 2C C0 (eax,xmm0)
    tests.push_back({"cvttss2si eax,xmm0", cat, {0xF3, 0x0F, 0x2C, 0xC0},
                      sf, FL_ALL, 0x0, false});

    // CVTTSD2SI: F2 0F 2C C0 (eax,xmm0)
    tests.push_back({"cvttsd2si eax,xmm0", cat, {0xF2, 0x0F, 0x2C, 0xC0},
                      sfd, FL_ALL, 0x0, false});
  }

  // COMISS/COMISD — ordered compare, set EFLAGS
  {
    ArchState s;
    s.rflags = 0x2;

    s.xmm[0] = xmm_from_f32(1.0f, 0, 0, 0);
    s.xmm[1] = xmm_from_f32(2.0f, 0, 0, 0);
    // COMISS XMM0, XMM1: 0F 2F C1
    add_xmm("comiss lt", {0x0F, 0x2F, 0xC1}, s, 0x0);

    s.xmm[1] = xmm_from_f32(1.0f, 0, 0, 0);
    add_xmm("comiss eq", {0x0F, 0x2F, 0xC1}, s, 0x0);

    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(3.0, 0);
    sd.xmm[1] = xmm_from_f64(1.0, 0);
    // COMISD XMM0, XMM1: 66 0F 2F C1
    add_xmm("comisd gt", {0x66, 0x0F, 0x2F, 0xC1}, sd, 0x0);
  }

  // PSLLDQ/PSRLDQ — byte shift
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);

    // PSLLDQ XMM0, 3: 66 0F 73 F8 03 (ModRM /7, rm=xmm0)
    add_xmm("pslldq xmm0,3", {0x66, 0x0F, 0x73, 0xF8, 0x03}, s, 0x1);
    // PSRLDQ XMM0, 3: 66 0F 73 D8 03 (ModRM /3, rm=xmm0)
    add_xmm("psrldq xmm0,3", {0x66, 0x0F, 0x73, 0xD8, 0x03}, s, 0x1);
  }

  // MOVHLPS/MOVLHPS — reg-reg forms
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // MOVHLPS XMM0, XMM1: 0F 12 C1 (move high half of xmm1 to low half of xmm0)
    add_xmm("movhlps xmm0,xmm1", {0x0F, 0x12, 0xC1}, s, 0x3);
    // MOVLHPS XMM0, XMM1: 0F 16 C1 (move low half of xmm1 to high half of xmm0)
    add_xmm("movlhps xmm0,xmm1", {0x0F, 0x16, 0xC1}, s, 0x3);
  }

  // MOVSS/MOVSD — reg-reg forms (merge into low element)
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);

    // MOVSS XMM0, XMM1: F3 0F 10 C1 (merge low dword of xmm1 into xmm0)
    add_xmm("movss xmm0,xmm1", {0xF3, 0x0F, 0x10, 0xC1}, s, 0x3);

    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(1.5, 2.5);
    sd.xmm[1] = xmm_from_f64(10.5, 20.5);

    // MOVSD XMM0, XMM1: F2 0F 10 C1 (merge low qword of xmm1 into xmm0)
    add_xmm("movsd xmm0,xmm1", {0xF2, 0x0F, 0x10, 0xC1}, sd, 0x3);
  }

  // PINSRW/PEXTRW
  {
    ArchState s;
    s.rflags = 0x2;
    s.rax = 0x1234;
    s.xmm[0] = xmm_from_u64(0, 0);

    // PINSRW XMM0, EAX, 3: 66 0F C4 C0 03
    add_xmm("pinsrw xmm0,eax,3", {0x66, 0x0F, 0xC4, 0xC0, 0x03}, s, 0x1);

    // PEXTRW EAX, XMM1, 2: 66 0F C5 C1 02
    ArchState s2 = {};
    s2.rflags = 0x2;
    s2.xmm[1] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
    tests.push_back({"pextrw eax,xmm1,2", cat, {0x66, 0x0F, 0xC5, 0xC1, 0x02},
                      s2, FL_ALL, 0x0, false});
  }

  // SSE2 PSHUFHW/PSHUFLW
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);

    // PSHUFHW XMM1, XMM0, 0x1B: F3 0F 70 C8 1B
    add_xmm("pshufhw xmm1,xmm0,0x1b", {0xF3, 0x0F, 0x70, 0xC8, 0x1B}, s, 0x2);
    // PSHUFLW XMM1, XMM0, 0x1B: F2 0F 70 C8 1B
    add_xmm("pshuflw xmm1,xmm0,0x1b", {0xF2, 0x0F, 0x70, 0xC8, 0x1B}, s, 0x2);
  }

  // =====================================================================
  // 24. SSSE3 — supplemental SSE3 integer instructions
  // =====================================================================
  cat = "SSSE3";

  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x0003020100070605, 0x0403020108070605);

    // PSHUFB XMM0, XMM1: 66 0F 38 00 C1
    add_xmm("pshufb xmm0,xmm1", {0x66, 0x0F, 0x38, 0x00, 0xC1}, s, 0x3);
  }

  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
    s.xmm[1] = xmm_from_u64(0x0010002000300040, 0x0050006000700080);

    // PHADDW XMM0, XMM1: 66 0F 38 01 C1
    add_xmm("phaddw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x01, 0xC1}, s, 0x3);
    // PHADDD XMM0, XMM1: 66 0F 38 02 C1
    add_xmm("phaddd xmm0,xmm1", {0x66, 0x0F, 0x38, 0x02, 0xC1}, s, 0x3);
    // PHADDSW XMM0, XMM1: 66 0F 38 03 C1
    add_xmm("phaddsw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x03, 0xC1}, s, 0x3);
    // PHSUBW XMM0, XMM1: 66 0F 38 05 C1
    add_xmm("phsubw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x05, 0xC1}, s, 0x3);
    // PHSUBD XMM0, XMM1: 66 0F 38 06 C1
    add_xmm("phsubd xmm0,xmm1", {0x66, 0x0F, 0x38, 0x06, 0xC1}, s, 0x3);
    // PHSUBSW XMM0, XMM1: 66 0F 38 07 C1
    add_xmm("phsubsw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x07, 0xC1}, s, 0x3);

    // PMADDUBSW XMM0, XMM1: 66 0F 38 04 C1
    add_xmm("pmaddubsw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x04, 0xC1}, s, 0x3);
    // PMULHRSW XMM0, XMM1: 66 0F 38 0B C1
    add_xmm("pmulhrsw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x0B, 0xC1}, s, 0x3);
  }

  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x01FF037F05816082, 0x7FFFFFFF80000001);

    // PABSB XMM1, XMM0: 66 0F 38 1C C8
    add_xmm("pabsb xmm1,xmm0", {0x66, 0x0F, 0x38, 0x1C, 0xC8}, s, 0x2);
    // PABSW XMM1, XMM0: 66 0F 38 1D C8
    add_xmm("pabsw xmm1,xmm0", {0x66, 0x0F, 0x38, 0x1D, 0xC8}, s, 0x2);
    // PABSD XMM1, XMM0: 66 0F 38 1E C8
    add_xmm("pabsd xmm1,xmm0", {0x66, 0x0F, 0x38, 0x1E, 0xC8}, s, 0x2);
  }

  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x01FF037F05816082, 0x7FFFFFFF80000001);
    s.xmm[1] = xmm_from_u64(0x0001000100010001, 0xFFFF0000FFFF0000);

    // PSIGNB XMM0, XMM1: 66 0F 38 08 C1
    add_xmm("psignb xmm0,xmm1", {0x66, 0x0F, 0x38, 0x08, 0xC1}, s, 0x3);
    // PSIGNW XMM0, XMM1: 66 0F 38 09 C1
    add_xmm("psignw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x09, 0xC1}, s, 0x3);
    // PSIGND XMM0, XMM1: 66 0F 38 0A C1
    add_xmm("psignd xmm0,xmm1", {0x66, 0x0F, 0x38, 0x0A, 0xC1}, s, 0x3);
  }

  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // PALIGNR XMM0, XMM1, 4: 66 0F 3A 0F C1 04
    add_xmm("palignr xmm0,xmm1,4", {0x66, 0x0F, 0x3A, 0x0F, 0xC1, 0x04}, s, 0x3);
  }

  // =====================================================================
  // 25. SSE4.1 instructions
  // =====================================================================
  cat = "SSE4.1";

  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x01FF037F05816082, 0x7FFFFFFF80000001);
    s.xmm[1] = xmm_from_u64(0x02FE027E04806183, 0x80000000FFFFFFFF);

    // PMAXSB XMM0, XMM1: 66 0F 38 3C C1
    add_xmm("pmaxsb xmm0,xmm1", {0x66, 0x0F, 0x38, 0x3C, 0xC1}, s, 0x3);
    // PMAXSD XMM0, XMM1: 66 0F 38 3D C1
    add_xmm("pmaxsd xmm0,xmm1", {0x66, 0x0F, 0x38, 0x3D, 0xC1}, s, 0x3);
    // PMAXUW XMM0, XMM1: 66 0F 38 3E C1
    add_xmm("pmaxuw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x3E, 0xC1}, s, 0x3);
    // PMAXUD XMM0, XMM1: 66 0F 38 3F C1
    add_xmm("pmaxud xmm0,xmm1", {0x66, 0x0F, 0x38, 0x3F, 0xC1}, s, 0x3);

    // PMINSB XMM0, XMM1: 66 0F 38 38 C1
    add_xmm("pminsb xmm0,xmm1", {0x66, 0x0F, 0x38, 0x38, 0xC1}, s, 0x3);
    // PMINSD XMM0, XMM1: 66 0F 38 39 C1
    add_xmm("pminsd xmm0,xmm1", {0x66, 0x0F, 0x38, 0x39, 0xC1}, s, 0x3);
    // PMINUW XMM0, XMM1: 66 0F 38 3A C1
    add_xmm("pminuw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x3A, 0xC1}, s, 0x3);
    // PMINUD XMM0, XMM1: 66 0F 38 3B C1
    add_xmm("pminud xmm0,xmm1", {0x66, 0x0F, 0x38, 0x3B, 0xC1}, s, 0x3);

    // PMAXSW (SSE2): 66 0F EE C1
    add_xmm("pmaxsw xmm0,xmm1", {0x66, 0x0F, 0xEE, 0xC1}, s, 0x3);
    // PMINSW (SSE2): 66 0F EA C1
    add_xmm("pminsw xmm0,xmm1", {0x66, 0x0F, 0xEA, 0xC1}, s, 0x3);
    // PMAXUB (SSE2): 66 0F DE C1
    add_xmm("pmaxub xmm0,xmm1", {0x66, 0x0F, 0xDE, 0xC1}, s, 0x3);
    // PMINUB (SSE2): 66 0F DA C1
    add_xmm("pminub xmm0,xmm1", {0x66, 0x0F, 0xDA, 0xC1}, s, 0x3);

    // PMULLD XMM0, XMM1: 66 0F 38 40 C1
    add_xmm("pmulld xmm0,xmm1", {0x66, 0x0F, 0x38, 0x40, 0xC1}, s, 0x3);

    // PACKUSDW XMM0, XMM1: 66 0F 38 2B C1
    add_xmm("packusdw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x2B, 0xC1}, s, 0x3);

    // PCMPEQQ XMM0, XMM1: 66 0F 38 29 C1
    add_xmm("pcmpeqq xmm0,xmm1", {0x66, 0x0F, 0x38, 0x29, 0xC1}, s, 0x3);
  }

  // PINSRB/PINSRD/PEXTRB/PEXTRD
  {
    ArchState s;
    s.rflags = 0x2;
    s.rax = 0x42;
    s.xmm[0] = xmm_from_u64(0, 0);

    // PINSRB XMM0, EAX, 5: 66 0F 3A 20 C0 05
    add_xmm("pinsrb xmm0,eax,5", {0x66, 0x0F, 0x3A, 0x20, 0xC0, 0x05}, s, 0x1);
    // PINSRD XMM0, EAX, 2: 66 0F 3A 22 C0 02
    add_xmm("pinsrd xmm0,eax,2", {0x66, 0x0F, 0x3A, 0x22, 0xC0, 0x02}, s, 0x1);

    ArchState s2 = {};
    s2.rflags = 0x2;
    s2.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);

    // PEXTRB EAX, XMM0, 5: 66 0F 3A 14 C0 05
    tests.push_back({"pextrb eax,xmm0,5", cat, {0x66, 0x0F, 0x3A, 0x14, 0xC0, 0x05},
                      s2, FL_ALL, 0x0, false});
    // PEXTRD EAX, XMM0, 2: 66 0F 3A 16 C0 02
    tests.push_back({"pextrd eax,xmm0,2", cat, {0x66, 0x0F, 0x3A, 0x16, 0xC0, 0x02},
                      s2, FL_ALL, 0x0, false});
  }

  // EXTRACTPS/INSERTPS
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);

    // EXTRACTPS EAX, XMM0, 2: 66 0F 3A 17 C0 02
    tests.push_back({"extractps eax,xmm0,2", cat, {0x66, 0x0F, 0x3A, 0x17, 0xC0, 0x02},
                      s, FL_ALL, 0x0, false});

    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    // INSERTPS XMM0, XMM1, 0x1A: 66 0F 3A 21 C1 1A (src[1] -> dst[2], zero mask=0b1010)
    add_xmm("insertps xmm0,xmm1,0x1a", {0x66, 0x0F, 0x3A, 0x21, 0xC1, 0x1A}, s, 0x3);
  }

  // BLENDPS/BLENDPD/PBLENDW
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);

    // BLENDPS XMM0, XMM1, 0x0A: 66 0F 3A 0C C1 0A (blend elements 1,3)
    add_xmm("blendps xmm0,xmm1,0x0a", {0x66, 0x0F, 0x3A, 0x0C, 0xC1, 0x0A}, s, 0x3);

    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(1.0, 2.0);
    sd.xmm[1] = xmm_from_f64(10.0, 20.0);

    // BLENDPD XMM0, XMM1, 0x02: 66 0F 3A 0D C1 02 (blend element 1)
    add_xmm("blendpd xmm0,xmm1,0x02", {0x66, 0x0F, 0x3A, 0x0D, 0xC1, 0x02}, sd, 0x3);

    ArchState si = {};
    si.rflags = 0x2;
    si.xmm[0] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
    si.xmm[1] = xmm_from_u64(0x0010002000300040, 0x0050006000700080);

    // PBLENDW XMM0, XMM1, 0xAA: 66 0F 3A 0E C1 AA (blend alternate words)
    add_xmm("pblendw xmm0,xmm1,0xaa", {0x66, 0x0F, 0x3A, 0x0E, 0xC1, 0xAA}, si, 0x3);
  }

  // ROUNDPS/ROUNDPD/ROUNDSS/ROUNDSD
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.3f, 2.7f, -1.5f, -2.5f);

    // ROUNDPS XMM1, XMM0, 0 (round nearest): 66 0F 3A 08 C8 00
    add_xmm("roundps nearest", {0x66, 0x0F, 0x3A, 0x08, 0xC8, 0x00}, s, 0x2);
    // ROUNDPS XMM1, XMM0, 1 (floor): 66 0F 3A 08 C8 01
    add_xmm("roundps floor", {0x66, 0x0F, 0x3A, 0x08, 0xC8, 0x01}, s, 0x2);
    // ROUNDPS XMM1, XMM0, 2 (ceil): 66 0F 3A 08 C8 02
    add_xmm("roundps ceil", {0x66, 0x0F, 0x3A, 0x08, 0xC8, 0x02}, s, 0x2);
    // ROUNDPS XMM1, XMM0, 3 (truncate): 66 0F 3A 08 C8 03
    add_xmm("roundps trunc", {0x66, 0x0F, 0x3A, 0x08, 0xC8, 0x03}, s, 0x2);

    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(1.3, -2.7);

    // ROUNDPD XMM1, XMM0, 0: 66 0F 3A 09 C8 00
    add_xmm("roundpd nearest", {0x66, 0x0F, 0x3A, 0x09, 0xC8, 0x00}, sd, 0x2);
    // ROUNDPD XMM1, XMM0, 1: 66 0F 3A 09 C8 01
    add_xmm("roundpd floor", {0x66, 0x0F, 0x3A, 0x09, 0xC8, 0x01}, sd, 0x2);

    // ROUNDSS XMM1, XMM0, 0: 66 0F 3A 0A C8 00
    add_xmm("roundss nearest", {0x66, 0x0F, 0x3A, 0x0A, 0xC8, 0x00}, s, 0x2);
    // ROUNDSD XMM1, XMM0, 1: 66 0F 3A 0B C8 01
    add_xmm("roundsd floor", {0x66, 0x0F, 0x3A, 0x0B, 0xC8, 0x01}, sd, 0x2);
  }

  // PTEST — sets ZF and CF in EFLAGS
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0xFF00FF00FF00FF00, 0x00FF00FF00FF00FF);
    s.xmm[1] = xmm_from_u64(0x00FF00FF00FF00FF, 0xFF00FF00FF00FF00);

    // PTEST XMM0, XMM1: 66 0F 38 17 C1 (AND is zero → ZF=1)
    add_xmm("ptest zero", {0x66, 0x0F, 0x38, 0x17, 0xC1}, s, 0x0);

    s.xmm[1] = s.xmm[0];
    // PTEST XMM0, XMM0: same bits → ZF=0
    add_xmm("ptest nonzero", {0x66, 0x0F, 0x38, 0x17, 0xC1}, s, 0x0);
  }

  // PMOVZX — zero-extend packed integers
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0);

    // PMOVZXBW XMM1, XMM0: 66 0F 38 30 C8
    add_xmm("pmovzxbw xmm1,xmm0", {0x66, 0x0F, 0x38, 0x30, 0xC8}, s, 0x2);
    // PMOVZXBD XMM1, XMM0: 66 0F 38 31 C8
    add_xmm("pmovzxbd xmm1,xmm0", {0x66, 0x0F, 0x38, 0x31, 0xC8}, s, 0x2);
    // PMOVZXBQ XMM1, XMM0: 66 0F 38 32 C8
    add_xmm("pmovzxbq xmm1,xmm0", {0x66, 0x0F, 0x38, 0x32, 0xC8}, s, 0x2);
    // PMOVZXWD XMM1, XMM0: 66 0F 38 33 C8
    add_xmm("pmovzxwd xmm1,xmm0", {0x66, 0x0F, 0x38, 0x33, 0xC8}, s, 0x2);
    // PMOVZXWQ XMM1, XMM0: 66 0F 38 34 C8
    add_xmm("pmovzxwq xmm1,xmm0", {0x66, 0x0F, 0x38, 0x34, 0xC8}, s, 0x2);
    // PMOVZXDQ XMM1, XMM0: 66 0F 38 35 C8
    add_xmm("pmovzxdq xmm1,xmm0", {0x66, 0x0F, 0x38, 0x35, 0xC8}, s, 0x2);
  }

  // PMOVSX — sign-extend packed integers
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x01FF037F05816082, 0);

    // PMOVSXBW XMM1, XMM0: 66 0F 38 20 C8
    add_xmm("pmovsxbw xmm1,xmm0", {0x66, 0x0F, 0x38, 0x20, 0xC8}, s, 0x2);
    // PMOVSXBD XMM1, XMM0: 66 0F 38 21 C8
    add_xmm("pmovsxbd xmm1,xmm0", {0x66, 0x0F, 0x38, 0x21, 0xC8}, s, 0x2);
    // PMOVSXBQ XMM1, XMM0: 66 0F 38 22 C8
    add_xmm("pmovsxbq xmm1,xmm0", {0x66, 0x0F, 0x38, 0x22, 0xC8}, s, 0x2);
    // PMOVSXWD XMM1, XMM0: 66 0F 38 23 C8
    add_xmm("pmovsxwd xmm1,xmm0", {0x66, 0x0F, 0x38, 0x23, 0xC8}, s, 0x2);
    // PMOVSXWQ XMM1, XMM0: 66 0F 38 24 C8
    add_xmm("pmovsxwq xmm1,xmm0", {0x66, 0x0F, 0x38, 0x24, 0xC8}, s, 0x2);
    // PMOVSXDQ XMM1, XMM0: 66 0F 38 25 C8
    add_xmm("pmovsxdq xmm1,xmm0", {0x66, 0x0F, 0x38, 0x25, 0xC8}, s, 0x2);
  }

  // DPPS/DPPD — dot product
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // DPPS XMM0, XMM1, 0xFF: 66 0F 3A 40 C1 FF (all elements, broadcast result)
    add_xmm("dpps xmm0,xmm1,0xff", {0x66, 0x0F, 0x3A, 0x40, 0xC1, 0xFF}, s, 0x3);
    // DPPS XMM0, XMM1, 0x71: first 3 elements, result to element 0 only
    add_xmm("dpps xmm0,xmm1,0x71", {0x66, 0x0F, 0x3A, 0x40, 0xC1, 0x71}, s, 0x3);

    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(1.5, 2.5);
    sd.xmm[1] = xmm_from_f64(3.0, 4.0);

    // DPPD XMM0, XMM1, 0x33: 66 0F 3A 41 C1 33 (both elements, broadcast)
    add_xmm("dppd xmm0,xmm1,0x33", {0x66, 0x0F, 0x3A, 0x41, 0xC1, 0x33}, sd, 0x3);
  }

  // MPSADBW
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // MPSADBW XMM0, XMM1, 0: 66 0F 3A 42 C1 00
    add_xmm("mpsadbw xmm0,xmm1,0", {0x66, 0x0F, 0x3A, 0x42, 0xC1, 0x00}, s, 0x3);
  }

  // =====================================================================
  // INSERTPS memory form — imm8[7:6] forced to 0, reads 32 bits
  // =====================================================================
  {
    cat = "SSE";

    // INSERTPS XMM0, [RDI], imm8: 66 0F 3A 21 07 imm8
    // Memory form reads 32 bits only; imm8[7:6] (count_s) is ignored.
    // imm8 = 0xC0: count_s=3 (ignored for mem), count_d=0, zmask=0
    // Should insert the 32-bit value at [RDI] into XMM0[31:0].
    {
      ArchState s = {.rdi = DATA_ADDR, .rflags = 0x2};
      s.xmm[0] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      std::vector<u8> data = {0xAA, 0xBB, 0xCC, 0xDD, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
      tests.push_back({"insertps xmm,m32 count_s=3", cat,
        {0x66, 0x0F, 0x3A, 0x21, 0x07, 0xC0},
        s, FL_NONE, 0x1, false, data, 0});
    }

    // INSERTPS XMM0, [RDI], 0x10: count_s=0, count_d=1, zmask=0
    // Insert 32-bit [RDI] into XMM0[63:32]
    {
      ArchState s = {.rdi = DATA_ADDR, .rflags = 0x2};
      s.xmm[0] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      std::vector<u8> data = {0xEE, 0xFF, 0x00, 0x11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
      tests.push_back({"insertps xmm,m32 dst=1", cat,
        {0x66, 0x0F, 0x3A, 0x21, 0x07, 0x10},
        s, FL_NONE, 0x1, false, data, 0});
    }
  }

  // =====================================================================
  // VEX 0F 12/16 variants: VMOVLPD, VMOVSLDUP, VMOVDDUP, VMOVHPD, VMOVSHDUP
  // =====================================================================
  {
    cat = "SSE";

    // VMOVLPD xmm0, xmm1, [rdi]: VEX.128.66.0F.WIG 12 /r
    // C5 F1 12 07: VEX pp=01(66), vvvv=xmm1, opcode=12, modrm=07([rdi])
    // SDM: DEST[63:0] := SRC2[63:0]; DEST[127:64] := SRC1[127:64]; upper zeroed
    {
      ArchState s = {.rdi = DATA_ADDR, .rflags = 0x2};
      s.xmm[1] = xmm_from_u64(0xAAAAAAAAAAAAAAAA, 0xBBBBBBBBBBBBBBBB);
      std::vector<u8> data = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88};
      tests.push_back({"vmovlpd xmm0,xmm1,[rdi]", cat,
        {0xC5, 0xF1, 0x12, 0x07}, s, FL_NONE, 0x1, false, data, 0});
    }

    // VMOVSLDUP xmm0, xmm1: VEX.128.F3.0F.WIG 12 /r
    // C5 FA 12 C1: VEX pp=10(F3), vvvv=1111, opcode=12, modrm=C1(xmm1)
    // SDM: DEST = [src[95:64], src[95:64], src[31:0], src[31:0]]
    {
      ArchState s = {.rflags = 0x2};
      s.xmm[1] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      tests.push_back({"vmovsldup xmm0,xmm1", cat,
        {0xC5, 0xFA, 0x12, 0xC1}, s, FL_NONE, 0x1});
    }

    // VMOVDDUP xmm0, xmm1: VEX.128.F2.0F.WIG 12 /r
    // C5 FB 12 C1: VEX pp=11(F2), vvvv=1111, opcode=12, modrm=C1(xmm1)
    // SDM: DEST[63:0] := SRC[63:0]; DEST[127:64] := SRC[63:0]
    {
      ArchState s = {.rflags = 0x2};
      s.xmm[1] = xmm_from_u64(0x1234567890ABCDEF, 0xFEDCBA0987654321);
      tests.push_back({"vmovddup xmm0,xmm1", cat,
        {0xC5, 0xFB, 0x12, 0xC1}, s, FL_NONE, 0x1});
    }

    // VMOVHPD xmm0, xmm1, [rdi]: VEX.128.66.0F.WIG 16 /r
    // C5 F1 16 07: VEX pp=01(66), vvvv=xmm1, opcode=16, modrm=07([rdi])
    // SDM: DEST[63:0] := SRC1[63:0]; DEST[127:64] := SRC2[63:0]; upper zeroed
    {
      ArchState s = {.rdi = DATA_ADDR, .rflags = 0x2};
      s.xmm[1] = xmm_from_u64(0xAAAAAAAAAAAAAAAA, 0xBBBBBBBBBBBBBBBB);
      std::vector<u8> data = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88};
      tests.push_back({"vmovhpd xmm0,xmm1,[rdi]", cat,
        {0xC5, 0xF1, 0x16, 0x07}, s, FL_NONE, 0x1, false, data, 0});
    }

    // VMOVSHDUP xmm0, xmm1: VEX.128.F3.0F.WIG 16 /r
    // C5 FA 16 C1: VEX pp=10(F3), vvvv=1111, opcode=16, modrm=C1(xmm1)
    // SDM: DEST = [src[127:96], src[127:96], src[63:32], src[63:32]]
    {
      ArchState s = {.rflags = 0x2};
      s.xmm[1] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      tests.push_back({"vmovshdup xmm0,xmm1", cat,
        {0xC5, 0xFA, 0x16, 0xC1}, s, FL_NONE, 0x1});
    }
  }

  // =====================================================================
  // PEXTRW SSE4.1 memory form (66 0F 3A 15)
  // =====================================================================
  {
    cat = "SSE";

    // PEXTRW [RDI], XMM0, 2: 66 0F 3A 15 07 02
    // Extract word at index 2 from XMM0, store to memory
    {
      ArchState s = {.rdi = DATA_ADDR, .rflags = 0x2};
      s.xmm[0] = xmm_from_u32(0x11112222, 0x33334444, 0x55556666, 0x77778888);
      tests.push_back({"pextrw [rdi],xmm0,2", cat,
        {0x66, 0x0F, 0x3A, 0x15, 0x07, 0x02}, s, FL_NONE, 0, false, {}, 2});
    }
  }

  // =====================================================================
  // MOVQ2DQ: move MMX register to low 64 bits of XMM, zero upper
  // =====================================================================
  {
    cat = "SSE";

    // MOVQ2DQ XMM0, MM0: F3 0F D6 C0
    // SDM: DEST[63:0] := SRC[63:0]; DEST[127:64] := 0
    // First load MM0 via MOVD MM0,EAX (0F 6E C0), then MOVQ2DQ
    {
      ArchState s = {.rax = 0x1234567890ABCDEF, .rflags = 0x2};
      tests.push_back({"movd mm0,eax; movq2dq xmm0,mm0", cat,
        {0x0F, 0x6E, 0xC0,        // MOVD MM0, EAX (loads low 32 bits)
         0xF3, 0x0F, 0xD6, 0xC0,  // MOVQ2DQ XMM0, MM0
         0x0F, 0x77},             // EMMS
        s, FL_NONE, 0x1});
    }
  }

  // =====================================================================
  // VEX VCVTDQ2PS/VCVTPS2DQ/VCVTTPS2DQ
  // =====================================================================
  {
    cat = "SSE";

    // VCVTDQ2PS xmm0, xmm1: VEX.128.NP.0F.WIG 5B /r
    // C5 F8 5B C1: convert packed dword integers to packed f32
    {
      ArchState s = {.rflags = 0x2};
      s.xmm[1] = xmm_from_u32(1, 2, 3, 4);
      tests.push_back({"vcvtdq2ps xmm0,xmm1", cat,
        {0xC5, 0xF8, 0x5B, 0xC1}, s, FL_NONE, 0x1});
    }

    // VCVTPS2DQ xmm0, xmm1: VEX.128.66.0F.WIG 5B /r
    // C5 F9 5B C1: convert packed f32 to packed dword integers (MXCSR rounding)
    {
      ArchState s = {.rflags = 0x2};
      s.xmm[1] = xmm_from_u32(0x3F800000, 0x40000000, 0x40400000, 0x40800000); // 1,2,3,4
      tests.push_back({"vcvtps2dq xmm0,xmm1", cat,
        {0xC5, 0xF9, 0x5B, 0xC1}, s, FL_NONE, 0x1});
    }

    // VCVTTPS2DQ xmm0, xmm1: VEX.128.F3.0F.WIG 5B /r
    // C5 FA 5B C1: convert packed f32 to packed dword integers (truncation)
    {
      ArchState s = {.rflags = 0x2};
      s.xmm[1] = xmm_from_u32(0x40490FDB, 0x40C90FDB, 0x41200000, 0xC1200000); // pi,2pi,10,-10
      tests.push_back({"vcvttps2dq xmm0,xmm1", cat,
        {0xC5, 0xFA, 0x5B, 0xC1}, s, FL_NONE, 0x1});
    }

    // VCVTDQ2PS ymm0, ymm1: VEX.256.NP.0F.WIG 5B /r
    // C5 FC 5B C1: 256-bit convert packed dword integers to packed f32
    {
      ArchState s = {.rflags = 0x2};
      s.xmm[1] = xmm_from_u32(1, 2, 3, 4);  // low 128
      // Need to set ymm1 upper half too — but test harness only sets xmm
      // Just test that the instruction doesn't fault
      tests.push_back({"vcvtdq2ps ymm0,ymm1 256", cat,
        {0xC5, 0xFC, 0x5B, 0xC1}, s, FL_NONE, 0x1});
    }
  }

  // =====================================================================
  // VCMPPS 5-bit predicates (predicates 8-15 test NaN-aware comparisons)
  // =====================================================================
  {
    cat = "SSE";

    auto add_xmm = [&](const std::string &name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    // VCMPPS XMM0, XMM1, XMM2, imm8: VEX.128.0F.WIG C2 /r ib
    // C5 F0 C2 C2 xx: VEX.128.NP L=0 pp=00, vvvv=xmm1, C2 /r=xmm2, imm8=xx
    // Use 1.0 vs 2.0 (ordered, 1<2)
    const u32 ONE = 0x3F800000;   // 1.0f
    const u32 TWO = 0x40000000;   // 2.0f
    const u32 QNAN = 0x7FC00000;  // quiet NaN

    // pred 8: EQ_UQ — equal, unordered quiet (true for NaN)
    // 1.0 vs 2.0 → not equal, ordered → false
    {
      ArchState s = {.rflags = 0x2};
      s.xmm[1] = xmm_from_u32(ONE, 0, 0, 0);
      s.xmm[2] = xmm_from_u32(TWO, 0, 0, 0);
      add_xmm("vcmpps pred8 eq_uq ord", {0xC5, 0xF0, 0xC2, 0xC2, 0x08}, s, 0x1);
    }
    // 1.0 vs NaN → unordered → true (EQ_UQ returns true for unordered)
    {
      ArchState s = {.rflags = 0x2};
      s.xmm[1] = xmm_from_u32(ONE, 0, 0, 0);
      s.xmm[2] = xmm_from_u32(QNAN, 0, 0, 0);
      add_xmm("vcmpps pred8 eq_uq nan", {0xC5, 0xF0, 0xC2, 0xC2, 0x08}, s, 0x1);
    }

    // pred 11: FALSE_OQ — always false
    {
      ArchState s = {.rflags = 0x2};
      s.xmm[1] = xmm_from_u32(ONE, ONE, ONE, ONE);
      s.xmm[2] = xmm_from_u32(ONE, ONE, ONE, ONE);
      add_xmm("vcmpps pred11 false", {0xC5, 0xF0, 0xC2, 0xC2, 0x0B}, s, 0x1);
    }

    // pred 12: NEQ_OQ — not equal, ordered (false for NaN)
    {
      ArchState s = {.rflags = 0x2};
      s.xmm[1] = xmm_from_u32(ONE, 0, 0, 0);
      s.xmm[2] = xmm_from_u32(QNAN, 0, 0, 0);
      add_xmm("vcmpps pred12 neq_oq nan", {0xC5, 0xF0, 0xC2, 0xC2, 0x0C}, s, 0x1);
    }

    // pred 15: TRUE_UQ — always true
    {
      ArchState s = {.rflags = 0x2};
      s.xmm[1] = xmm_from_u32(0, 0, 0, 0);
      s.xmm[2] = xmm_from_u32(ONE, TWO, QNAN, 0);
      add_xmm("vcmpps pred15 true", {0xC5, 0xF0, 0xC2, 0xC2, 0x0F}, s, 0x1);
    }
  }

  // =====================================================================
  // Legacy SSE loads must preserve YMM upper bits (write_xmm_legacy)
  // Strategy: VMOVDQU YMM0,[RDI] to set upper bits, then legacy SSE
  // load into XMM0, then VEXTRACTI128 XMM1,YMM0,1 to read upper 128.
  // XMM1 should retain the pattern if upper bits are preserved.
  // =====================================================================
  {
    cat = "SSE Legacy Upper";

    // Data layout at DATA_ADDR:
    //   [0..15]  = YMM0[127:0] initial (don't care, will be overwritten)
    //   [16..31] = YMM0[255:128] initial = 0xAA pattern (must survive)
    //   [32..47] = SSE load source data = 0xBB pattern
    std::vector<u8> data(64, 0);
    for (int i = 16; i < 32; i++) data[i] = 0xAA;  // upper YMM
    for (int i = 32; i < 48; i++) data[i] = 0xBB;  // load source

    // MOVUPS XMM0, [RDI+32]: legacy SSE 128-bit load
    // Code: VMOVDQU YMM0,[RDI]      = C5 FE 6F 07        (4 bytes)
    //       MOVUPS XMM0,[RDI+0x20]  = 0F 10 47 20        (4 bytes)
    //       VEXTRACTI128 XMM1,YMM0,1= C4 E3 7D 39 C1 01  (6 bytes)
    tests.push_back({"movups xmm,m preserves upper", cat,
      {0xC5, 0xFE, 0x6F, 0x07,
       0x0F, 0x10, 0x47, 0x20,
       0xC4, 0xE3, 0x7D, 0x39, 0xC1, 0x01},
      {.rdi = DATA_ADDR, .rflags = 0x2},
      FL_NONE, 0x3, false, data, 0});

    // MOVAPS XMM0, [RDI+32]: legacy SSE aligned 128-bit load
    // Code: VMOVDQU YMM0,[RDI]      = C5 FE 6F 07
    //       MOVAPS XMM0,[RDI+0x20]  = 0F 28 47 20
    //       VEXTRACTI128 XMM1,YMM0,1= C4 E3 7D 39 C1 01
    // DATA_ADDR+32 = 0x11020, 0x11020 % 16 == 0 (aligned)
    tests.push_back({"movaps xmm,m preserves upper", cat,
      {0xC5, 0xFE, 0x6F, 0x07,
       0x0F, 0x28, 0x47, 0x20,
       0xC4, 0xE3, 0x7D, 0x39, 0xC1, 0x01},
      {.rdi = DATA_ADDR, .rflags = 0x2},
      FL_NONE, 0x3, false, data, 0});

    // MOVDQU XMM0, [RDI+32]: legacy SSE integer 128-bit load (F3 0F 6F)
    // Code: VMOVDQU YMM0,[RDI]       = C5 FE 6F 07
    //       MOVDQU XMM0,[RDI+0x20]   = F3 0F 6F 47 20
    //       VEXTRACTI128 XMM1,YMM0,1 = C4 E3 7D 39 C1 01
    tests.push_back({"movdqu xmm,m preserves upper", cat,
      {0xC5, 0xFE, 0x6F, 0x07,
       0xF3, 0x0F, 0x6F, 0x47, 0x20,
       0xC4, 0xE3, 0x7D, 0x39, 0xC1, 0x01},
      {.rdi = DATA_ADDR, .rflags = 0x2},
      FL_NONE, 0x3, false, data, 0});

    // MOVSS XMM0, [RDI+32]: legacy SSE scalar float load (F3 0F 10)
    // Code: VMOVDQU YMM0,[RDI]       = C5 FE 6F 07
    //       MOVSS XMM0,[RDI+0x20]    = F3 0F 10 47 20
    //       VEXTRACTI128 XMM1,YMM0,1 = C4 E3 7D 39 C1 01
    tests.push_back({"movss xmm,m preserves upper", cat,
      {0xC5, 0xFE, 0x6F, 0x07,
       0xF3, 0x0F, 0x10, 0x47, 0x20,
       0xC4, 0xE3, 0x7D, 0x39, 0xC1, 0x01},
      {.rdi = DATA_ADDR, .rflags = 0x2},
      FL_NONE, 0x3, false, data, 0});

    // MOVSD XMM0, [RDI+32]: legacy SSE scalar double load (F2 0F 10)
    // Code: VMOVDQU YMM0,[RDI]       = C5 FE 6F 07
    //       MOVSD XMM0,[RDI+0x20]    = F2 0F 10 47 20
    //       VEXTRACTI128 XMM1,YMM0,1 = C4 E3 7D 39 C1 01
    tests.push_back({"movsd xmm,m preserves upper", cat,
      {0xC5, 0xFE, 0x6F, 0x07,
       0xF2, 0x0F, 0x10, 0x47, 0x20,
       0xC4, 0xE3, 0x7D, 0x39, 0xC1, 0x01},
      {.rdi = DATA_ADDR, .rflags = 0x2},
      FL_NONE, 0x3, false, data, 0});

    // MOVUPD XMM0, [RDI+32]: legacy SSE 128-bit double load (66 0F 10)
    // Code: VMOVDQU YMM0,[RDI]       = C5 FE 6F 07
    //       MOVUPD XMM0,[RDI+0x20]   = 66 0F 10 47 20
    //       VEXTRACTI128 XMM1,YMM0,1 = C4 E3 7D 39 C1 01
    tests.push_back({"movupd xmm,m preserves upper", cat,
      {0xC5, 0xFE, 0x6F, 0x07,
       0x66, 0x0F, 0x10, 0x47, 0x20,
       0xC4, 0xE3, 0x7D, 0x39, 0xC1, 0x01},
      {.rdi = DATA_ADDR, .rflags = 0x2},
      FL_NONE, 0x3, false, data, 0});

    // MOVDDUP XMM0, [RDI+32]: legacy SSE double duplicate (F2 0F 12)
    // Code: VMOVDQU YMM0,[RDI]       = C5 FE 6F 07
    //       MOVDDUP XMM0,[RDI+0x20]  = F2 0F 12 47 20
    //       VEXTRACTI128 XMM1,YMM0,1 = C4 E3 7D 39 C1 01
    tests.push_back({"movddup xmm,m preserves upper", cat,
      {0xC5, 0xFE, 0x6F, 0x07,
       0xF2, 0x0F, 0x12, 0x47, 0x20,
       0xC4, 0xE3, 0x7D, 0x39, 0xC1, 0x01},
      {.rdi = DATA_ADDR, .rflags = 0x2},
      FL_NONE, 0x3, false, data, 0});
  }

  // =====================================================================
  // SSE4.2 string operations — PCMPISTRI/PCMPISTRM
  // =====================================================================
  {
    cat = "SSE4.2 str";

    auto add_xmm = [&](const std::string &name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    // PCMPISTRI xmm1, xmm2, imm8: 66 0F 3A 63 /r ib
    // Mode 0x00: unsigned bytes, equal any, LSB index
    // XMM0 = "abcd\0...", XMM1 = "xxbx\0..." -> find 'b' at index 2
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(0x0000000064636261, 0);  // "abcd\0..."
      s.xmm[1] = xmm_from_u64(0x0000000078627878, 0);  // "xxbx\0..."
      // 66 0F 3A 63 C1 00: PCMPISTRI XMM0, XMM1, 0x00
      add_xmm("pcmpistri eq_any", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x00}, s, 0);
    }

    // PCMPISTRI: equal each (mode 0x08) -- byte-by-byte compare
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(0x00006F6C6C6568, 0);  // "hello\0..."
      s.xmm[1] = xmm_from_u64(0x00006F6C6C6568, 0);  // "hello\0..."
      add_xmm("pcmpistri eq_each match", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x08}, s, 0);
    }

    // PCMPISTRI: equal each with difference at byte 2
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(0x0000000044434241, 0);  // "ABCD\0..."
      s.xmm[1] = xmm_from_u64(0x0000000044584241, 0);  // "AB\x58D\0..."
      add_xmm("pcmpistri eq_each diff@2", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x08}, s, 0);
    }

    // PCMPISTRM: equal each (mode 0x08), returns mask in XMM0
    // 66 0F 3A 62 C1 08: PCMPISTRM XMM0, XMM1, 0x08
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(0x0000000044434241, 0);  // "ABCD\0..."
      s.xmm[1] = xmm_from_u64(0x00000000FF43FF41, 0);  // "A\xffC\xff\0..."
      add_xmm("pcmpistrm eq_each", {0x66, 0x0F, 0x3A, 0x62, 0xC1, 0x08}, s, 0x1);
    }

    // PCMPESTRI: explicit length -- 66 0F 3A 61 C1 imm8
    // EAX=length of xmm0 string, EDX=length of xmm1 string
    {
      ArchState s;
      s.rflags = 0x2;
      s.rax = 3;  // length of needle
      s.rdx = 4;  // length of haystack
      s.xmm[0] = xmm_from_u64(0x0000000000434241, 0);  // "ABC\0..."
      s.xmm[1] = xmm_from_u64(0x0000000044434241, 0);  // "ABCD\0..."
      add_xmm("pcmpestri eq_each", {0x66, 0x0F, 0x3A, 0x61, 0xC1, 0x08}, s, 0);
    }
  }
}


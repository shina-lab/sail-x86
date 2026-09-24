#include "kvm-harness.h"

void add_sse_tests(std::vector<TestCase> &tests) {
  std::string cat;

  auto add_xmm = [&](const std::string &name, std::vector<u8> code, ArchState init,
                      u32 xmm_cmp) {
    tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
  };

  std::vector<u8> align_data(64, 0x42);

  // Misaligned memory test: expects #GP(0) fault (vector 13)
  auto add_misalign_fault = [&](const std::string &name, std::vector<u8> code,
                                  std::initializer_list<unsigned> xmm_inputs = {}) {
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = std::move(code);
    tc.initial = {.rdi = DATA_ADDR + 1};
    for (unsigned reg : xmm_inputs)
      tc.initial.xmm[reg] = xmm_from_u64(0, 0);
    tc.flags_mask = FL_ALL;
    tc.expect_fault = true;
    tc.expected_vector = 13;
    tc.init_data = align_data;
    tests.push_back(std::move(tc));
  };

  // Misaligned memory test: must NOT fault, compare xmm0
  auto add_misalign_ok = [&](const std::string &name, std::vector<u8> code,
                                  std::initializer_list<unsigned> xmm_inputs = {}) {
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = std::move(code);
    tc.initial = {.rdi = DATA_ADDR + 1};
    for (unsigned reg : xmm_inputs)
      tc.initial.xmm[reg] = xmm_from_u64(0, 0);
    tc.flags_mask = FL_ALL;
    tc.xmm_mask = 0x1;
    tc.init_data = align_data;
    tests.push_back(std::move(tc));
  };

  // Misaligned store test: expects #GP(0) fault
  auto add_misalign_fault_st = [&](const std::string &name, std::vector<u8> code) {
    ArchState init = {.rdi = DATA_ADDR + 1};
    init.xmm[0] = xmm_from_u64(0x1111111111111111, 0x2222222222222222);
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = std::move(code);
    tc.initial = init;
    tc.flags_mask = FL_ALL;
    tc.expect_fault = true;
    tc.expected_vector = 13;
    tc.init_data = align_data;
    tests.push_back(std::move(tc));
  };

  // Misaligned store test: must NOT fault, compare written data
  auto add_misalign_ok_st = [&](const std::string &name, std::vector<u8> code,
                                 size_t cmp_len = 16) {
    ArchState init = {.rdi = DATA_ADDR + 1};
    init.xmm[0] = xmm_from_u64(0x1111111111111111, 0x2222222222222222);
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = std::move(code);
    tc.initial = init;
    tc.flags_mask = FL_ALL;
    tc.init_data = align_data;
    tc.compare_data_len = cmp_len;
    tests.push_back(std::move(tc));
  };

  // Misaligned test for GPR-result instructions (no xmm compare)
  auto add_misalign_ok_gpr = [&](const std::string &name, std::vector<u8> code,
                                  std::initializer_list<unsigned> xmm_inputs = {}) {
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = std::move(code);
    tc.initial = {.rdi = DATA_ADDR + 1};
    for (unsigned reg : xmm_inputs)
      tc.initial.xmm[reg] = xmm_from_u64(0, 0);
    tc.flags_mask = FL_ALL;
    tc.init_data = align_data;
    tests.push_back(std::move(tc));
  };

  // =====================================================================
  // 23. SSE/SSE2 — packed and scalar floating-point operations
  // =====================================================================
  cat = "SSE";

  {
    ArchState s;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // ADDPS XMM0, XMM1: 0F 58 C1
    add_xmm("addps xmm0,xmm1", {0x0F, 0x58, 0xC1}, s, 0x3);
    add_misalign_fault("addps xmm0,[rdi] misaligned", {0x0F, 0x58, 0x07}, {0});
    // SUBPS XMM0, XMM1: 0F 5C C1
    add_xmm("subps xmm0,xmm1", {0x0F, 0x5C, 0xC1}, s, 0x3);
    add_misalign_fault("subps xmm0,[rdi] misaligned", {0x0F, 0x5C, 0x07}, {0});
    // MULPS XMM0, XMM1: 0F 59 C1
    add_xmm("mulps xmm0,xmm1", {0x0F, 0x59, 0xC1}, s, 0x3);
    add_misalign_fault("mulps xmm0,[rdi] misaligned", {0x0F, 0x59, 0x07}, {0});
    // DIVPS XMM0, XMM1: 0F 5E C1
    add_xmm("divps xmm0,xmm1", {0x0F, 0x5E, 0xC1}, s, 0x3);
    add_misalign_fault("divps xmm0,[rdi] misaligned", {0x0F, 0x5E, 0x07}, {0});
    // MINPS XMM0, XMM1: 0F 5D C1
    add_xmm("minps xmm0,xmm1", {0x0F, 0x5D, 0xC1}, s, 0x3);
    add_misalign_fault("minps xmm0,[rdi] misaligned", {0x0F, 0x5D, 0x07}, {0});
    // MAXPS XMM0, XMM1: 0F 5F C1
    add_xmm("maxps xmm0,xmm1", {0x0F, 0x5F, 0xC1}, s, 0x3);
    add_misalign_fault("maxps xmm0,[rdi] misaligned", {0x0F, 0x5F, 0x07}, {0});

    // MOVAPS XMM2, XMM0: 0F 28 D0
    add_xmm("movaps xmm2,xmm0", {0x0F, 0x28, 0xD0}, with_vector_inputs(s, 0x1), 0x4);
    add_misalign_fault("movaps xmm0,[rdi] misaligned", {0x0F, 0x28, 0x07});
    // MOVUPS XMM2, XMM0: 0F 10 D0
    add_xmm("movups xmm2,xmm0", {0x0F, 0x10, 0xD0}, with_vector_inputs(s, 0x1), 0x4);
    add_misalign_ok("movups xmm0,[rdi] misaligned", {0x0F, 0x10, 0x07});
  }

  // ADDPD/SUBPD/MULPD/DIVPD — packed double
  {
    ArchState s;
    s.xmm[0] = xmm_from_f64(1.5, 2.5);
    s.xmm[1] = xmm_from_f64(3.0, 4.0);

    // ADDPD XMM0, XMM1: 66 0F 58 C1
    add_xmm("addpd xmm0,xmm1", {0x66, 0x0F, 0x58, 0xC1}, s, 0x3);
    add_misalign_fault("addpd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x58, 0x07}, {0});
    // SUBPD XMM0, XMM1: 66 0F 5C C1
    add_xmm("subpd xmm0,xmm1", {0x66, 0x0F, 0x5C, 0xC1}, s, 0x3);
    add_misalign_fault("subpd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x5C, 0x07}, {0});
    // MULPD XMM0, XMM1: 66 0F 59 C1
    add_xmm("mulpd xmm0,xmm1", {0x66, 0x0F, 0x59, 0xC1}, s, 0x3);
    add_misalign_fault("mulpd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x59, 0x07}, {0});
    // DIVPD XMM0, XMM1: 66 0F 5E C1
    add_xmm("divpd xmm0,xmm1", {0x66, 0x0F, 0x5E, 0xC1}, s, 0x3);
    add_misalign_fault("divpd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x5E, 0x07}, {0});
  }

  // ADDSS/SUBSS/MULSS/DIVSS — scalar single
  {
    ArchState s;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);

    // ADDSS XMM0, XMM1: F3 0F 58 C1
    add_xmm("addss xmm0,xmm1", {0xF3, 0x0F, 0x58, 0xC1}, s, 0x3);
    add_misalign_ok("addss xmm0,[rdi] misaligned", {0xF3, 0x0F, 0x58, 0x07}, {0});
    // SUBSS XMM0, XMM1: F3 0F 5C C1
    add_xmm("subss xmm0,xmm1", {0xF3, 0x0F, 0x5C, 0xC1}, s, 0x3);
    add_misalign_ok("subss xmm0,[rdi] misaligned", {0xF3, 0x0F, 0x5C, 0x07}, {0});
    // MULSS XMM0, XMM1: F3 0F 59 C1
    add_xmm("mulss xmm0,xmm1", {0xF3, 0x0F, 0x59, 0xC1}, s, 0x3);
    add_misalign_ok("mulss xmm0,[rdi] misaligned", {0xF3, 0x0F, 0x59, 0x07}, {0});
    // DIVSS XMM0, XMM1: F3 0F 5E C1
    add_xmm("divss xmm0,xmm1", {0xF3, 0x0F, 0x5E, 0xC1}, s, 0x3);
    add_misalign_ok("divss xmm0,[rdi] misaligned", {0xF3, 0x0F, 0x5E, 0x07}, {0});
  }

  // ADDSD/SUBSD/MULSD/DIVSD — scalar double
  {
    ArchState s;
    s.xmm[0] = xmm_from_f64(1.5, 100.0);
    s.xmm[1] = xmm_from_f64(2.5, 200.0);

    // ADDSD XMM0, XMM1: F2 0F 58 C1
    add_xmm("addsd xmm0,xmm1", {0xF2, 0x0F, 0x58, 0xC1}, s, 0x3);
    add_misalign_ok("addsd xmm0,[rdi] misaligned", {0xF2, 0x0F, 0x58, 0x07}, {0});
    // SUBSD XMM0, XMM1: F2 0F 5C C1
    add_xmm("subsd xmm0,xmm1", {0xF2, 0x0F, 0x5C, 0xC1}, s, 0x3);
    add_misalign_ok("subsd xmm0,[rdi] misaligned", {0xF2, 0x0F, 0x5C, 0x07}, {0});
    // MULSD XMM0, XMM1: F2 0F 59 C1
    add_xmm("mulsd xmm0,xmm1", {0xF2, 0x0F, 0x59, 0xC1}, s, 0x3);
    add_misalign_ok("mulsd xmm0,[rdi] misaligned", {0xF2, 0x0F, 0x59, 0x07}, {0});
    // DIVSD XMM0, XMM1: F2 0F 5E C1
    add_xmm("divsd xmm0,xmm1", {0xF2, 0x0F, 0x5E, 0xC1}, s, 0x3);
    add_misalign_ok("divsd xmm0,[rdi] misaligned", {0xF2, 0x0F, 0x5E, 0x07}, {0});
  }

  // SSE2 integer — PADDB/PADDW/PADDD/PADDQ, PSUBB, PAND/POR/PXOR
  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x1011121314151617, 0x18191A1B1C1D1E1F);

    // PADDB XMM0, XMM1: 66 0F FC C1
    add_xmm("paddb xmm0,xmm1", {0x66, 0x0F, 0xFC, 0xC1}, s, 0x3);
    add_misalign_fault("paddb xmm0,[rdi] misaligned", {0x66, 0x0F, 0xFC, 0x07}, {0});
    // PADDW XMM0, XMM1: 66 0F FD C1
    add_xmm("paddw xmm0,xmm1", {0x66, 0x0F, 0xFD, 0xC1}, s, 0x3);
    add_misalign_fault("paddw xmm0,[rdi] misaligned", {0x66, 0x0F, 0xFD, 0x07}, {0});
    // PADDD XMM0, XMM1: 66 0F FE C1
    add_xmm("paddd xmm0,xmm1", {0x66, 0x0F, 0xFE, 0xC1}, s, 0x3);
    add_misalign_fault("paddd xmm0,[rdi] misaligned", {0x66, 0x0F, 0xFE, 0x07}, {0});
    // PADDQ XMM0, XMM1: 66 0F D4 C1
    add_xmm("paddq xmm0,xmm1", {0x66, 0x0F, 0xD4, 0xC1}, s, 0x3);
    add_misalign_fault("paddq xmm0,[rdi] misaligned", {0x66, 0x0F, 0xD4, 0x07}, {0});
    // PSUBB XMM0, XMM1: 66 0F F8 C1
    add_xmm("psubb xmm0,xmm1", {0x66, 0x0F, 0xF8, 0xC1}, s, 0x3);
    add_misalign_fault("psubb xmm0,[rdi] misaligned", {0x66, 0x0F, 0xF8, 0x07}, {0});
    // PAND XMM0, XMM1: 66 0F DB C1
    add_xmm("pand xmm0,xmm1", {0x66, 0x0F, 0xDB, 0xC1}, s, 0x3);
    add_misalign_fault("pand xmm0,[rdi] misaligned", {0x66, 0x0F, 0xDB, 0x07}, {0});
    // POR XMM0, XMM1: 66 0F EB C1
    add_xmm("por xmm0,xmm1", {0x66, 0x0F, 0xEB, 0xC1}, s, 0x3);
    add_misalign_fault("por xmm0,[rdi] misaligned", {0x66, 0x0F, 0xEB, 0x07}, {0});
    // PXOR XMM0, XMM1: 66 0F EF C1
    add_xmm("pxor xmm0,xmm1", {0x66, 0x0F, 0xEF, 0xC1}, s, 0x3);
    add_misalign_fault("pxor xmm0,[rdi] misaligned", {0x66, 0x0F, 0xEF, 0x07}, {0});
  }

  // SSE2 shuffle/unpack
  {
    ArchState s;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // SHUFPS XMM0, XMM1, 0x1B: 0F C6 C1 1B (reverse order)
    add_xmm("shufps xmm0,xmm1,0x1b", {0x0F, 0xC6, 0xC1, 0x1B}, s, 0x3);
    add_misalign_fault("shufps xmm0,[rdi],0 misaligned", {0x0F, 0xC6, 0x07, 0x00}, {0});
    // UNPCKLPS XMM0, XMM1: 0F 14 C1
    add_xmm("unpcklps xmm0,xmm1", {0x0F, 0x14, 0xC1}, s, 0x3);
    add_misalign_fault("unpcklps xmm0,[rdi] misaligned", {0x0F, 0x14, 0x07}, {0});
    // UNPCKHPS XMM0, XMM1: 0F 15 C1
    add_xmm("unpckhps xmm0,xmm1", {0x0F, 0x15, 0xC1}, s, 0x3);
    add_misalign_fault("unpckhps xmm0,[rdi] misaligned", {0x0F, 0x15, 0x07}, {0});
  }

  // SSE conversions
  {
    ArchState s;
    s.xmm[0] = xmm_from_f32(1.5f, 2.7f, -3.2f, 4.9f);

    // CVTPS2DQ XMM1, XMM0: 66 0F 5B C8 (ModRM: reg=1, rm=0)
    add_xmm("cvtps2dq xmm1,xmm0", {0x66, 0x0F, 0x5B, 0xC8}, s, 0x2);
    add_misalign_fault("cvtps2dq xmm0,[rdi] misaligned", {0x66, 0x0F, 0x5B, 0x07});

    // CVTTPS2DQ XMM1, XMM0: F3 0F 5B C8
    add_xmm("cvttps2dq xmm1,xmm0", {0xF3, 0x0F, 0x5B, 0xC8}, s, 0x2);
    add_misalign_fault("cvttps2dq xmm0,[rdi] misaligned", {0xF3, 0x0F, 0x5B, 0x07});

    // CVTDQ2PS XMM1, XMM0: 0F 5B C8 (with integer input)
    ArchState si = {};
    si.xmm[0] = xmm_from_u32(1, 2, 0xFFFFFFFF, 100);
    add_xmm("cvtdq2ps xmm1,xmm0", {0x0F, 0x5B, 0xC8}, si, 0x2);
    add_misalign_fault("cvtdq2ps xmm0,[rdi] misaligned", {0x0F, 0x5B, 0x07});
  }

  // MOVD/MOVQ — GPR ↔ XMM
  {
    ArchState s;
    s.rax = 0x123456789ABCDEF0;

    // MOVQ XMM0, RAX: 66 48 0F 6E C0
    add_xmm("movq xmm0,rax", {0x66, 0x48, 0x0F, 0x6E, 0xC0}, s, 0x1);
    add_misalign_ok("movq xmm0,[rdi] misaligned", {0xF3, 0x0F, 0x7E, 0x07});

    // MOVD XMM0, EAX: 66 0F 6E C0
    add_xmm("movd xmm0,eax", {0x66, 0x0F, 0x6E, 0xC0}, s, 0x1);
    add_misalign_ok("movd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x6E, 0x07});

    // MOVQ RAX, XMM1: 66 48 0F 7E C8 (reg=1, rm=0 → XMM1 to RAX)
    ArchState s2 = {};
    s2.xmm[1] = xmm_from_u64(0xDEADBEEFCAFEBABE, 0x1234567890ABCDEF);
    // MOVQ RAX, XMM1: 66 REX.W 0F 7E C8 (ModRM: reg=xmm1=1, rm=rax=0)
    tests.push_back({"movq rax,xmm1", cat, {0x66, 0x48, 0x0F, 0x7E, 0xC8},
                      s2, FL_ALL, 0x0, false});
  }

  // SSE compare — UCOMISS sets EFLAGS
  {
    ArchState s;

    // Equal
    s.xmm[0] = xmm_from_f32(1.0f, 0, 0, 0);
    s.xmm[1] = xmm_from_f32(1.0f, 0, 0, 0);
    // UCOMISS XMM0, XMM1: 0F 2E C1
    add_xmm("ucomiss eq", {0x0F, 0x2E, 0xC1}, s, 0x0);
    add_misalign_ok_gpr("ucomiss xmm0,[rdi] misaligned", {0x0F, 0x2E, 0x07}, {0});

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
    add_misalign_ok_gpr("ucomisd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x2E, 0x07}, {0});

    s.xmm[0] = xmm_from_f64(1.0, 0);
    s.xmm[1] = xmm_from_f64(2.0, 0);
    add_xmm("ucomisd lt", {0x66, 0x0F, 0x2E, 0xC1}, s, 0x0);
  }

  // Upper registers (XMM8+) via REX prefix
  {
    ArchState s;
    s.xmm[8]  = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[9]  = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);

    // ADDPS XMM8, XMM9: 45 0F 58 C1 (REX.R+B)
    add_xmm("addps xmm8,xmm9", {0x45, 0x0F, 0x58, 0xC1}, s, 0x300);
  }

  // SSE logical — ANDPS/ANDNPS/ORPS/XORPS
  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0xFF00FF00FF00FF00, 0x0F0F0F0F0F0F0F0F);
    s.xmm[1] = xmm_from_u64(0x00FF00FF00FF00FF, 0xF0F0F0F0F0F0F0F0);

    // ANDPS XMM0, XMM1: 0F 54 C1
    add_xmm("andps xmm0,xmm1", {0x0F, 0x54, 0xC1}, s, 0x3);
    add_misalign_fault("andps xmm0,[rdi] misaligned", {0x0F, 0x54, 0x07}, {0});
    // ANDNPS XMM0, XMM1: 0F 55 C1  (NOT(xmm0) AND xmm1)
    add_xmm("andnps xmm0,xmm1", {0x0F, 0x55, 0xC1}, s, 0x3);
    add_misalign_fault("andnps xmm0,[rdi] misaligned", {0x0F, 0x55, 0x07}, {0});
    // ORPS XMM0, XMM1: 0F 56 C1
    add_xmm("orps xmm0,xmm1", {0x0F, 0x56, 0xC1}, s, 0x3);
    add_misalign_fault("orps xmm0,[rdi] misaligned", {0x0F, 0x56, 0x07}, {0});
    // XORPS XMM0, XMM1: 0F 57 C1
    add_xmm("xorps xmm0,xmm1", {0x0F, 0x57, 0xC1}, s, 0x3);
    add_misalign_fault("xorps xmm0,[rdi] misaligned", {0x0F, 0x57, 0x07}, {0});

    // ANDPD XMM0, XMM1: 66 0F 54 C1
    add_xmm("andpd xmm0,xmm1", {0x66, 0x0F, 0x54, 0xC1}, s, 0x3);
    add_misalign_fault("andpd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x54, 0x07}, {0});
    // ANDNPD XMM0, XMM1: 66 0F 55 C1
    add_xmm("andnpd xmm0,xmm1", {0x66, 0x0F, 0x55, 0xC1}, s, 0x3);
    add_misalign_fault("andnpd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x55, 0x07}, {0});
    // ORPD XMM0, XMM1: 66 0F 56 C1
    add_xmm("orpd xmm0,xmm1", {0x66, 0x0F, 0x56, 0xC1}, s, 0x3);
    add_misalign_fault("orpd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x56, 0x07}, {0});
    // XORPD XMM0, XMM1: 66 0F 57 C1
    add_xmm("xorpd xmm0,xmm1", {0x66, 0x0F, 0x57, 0xC1}, s, 0x3);
    add_misalign_fault("xorpd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x57, 0x07}, {0});
  }

  // SSE SQRT — SQRTPS/SQRTPD/SQRTSS/SQRTSD
  {
    ArchState s;
    s.xmm[0] = xmm_from_f32(4.0f, 9.0f, 16.0f, 25.0f);

    // SQRTPS XMM1, XMM0: 0F 51 C8
    add_xmm("sqrtps xmm1,xmm0", {0x0F, 0x51, 0xC8}, s, 0x2);
    add_misalign_fault("sqrtps xmm0,[rdi] misaligned", {0x0F, 0x51, 0x07});
    // SQRTSS XMM1, XMM0: F3 0F 51 C8
    add_xmm("sqrtss xmm1,xmm0", {0xF3, 0x0F, 0x51, 0xC8}, s, 0x2);
    add_misalign_ok("sqrtss xmm0,[rdi] misaligned", {0xF3, 0x0F, 0x51, 0x07});

    ArchState sd = {};
    sd.xmm[0] = xmm_from_f64(4.0, 9.0);

    // SQRTPD XMM1, XMM0: 66 0F 51 C8
    add_xmm("sqrtpd xmm1,xmm0", {0x66, 0x0F, 0x51, 0xC8}, sd, 0x2);
    add_misalign_fault("sqrtpd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x51, 0x07});
    // SQRTSD XMM1, XMM0: F2 0F 51 C8
    add_xmm("sqrtsd xmm1,xmm0", {0xF2, 0x0F, 0x51, 0xC8}, sd, 0x2);
    add_misalign_ok("sqrtsd xmm0,[rdi] misaligned", {0xF2, 0x0F, 0x51, 0x07});
  }

  // SSE MIN/MAX — remaining variants (MINPD/MAXPD/MINSS/MAXSS/MINSD/MAXSD)
  {
    ArchState s;
    s.xmm[0] = xmm_from_f32(1.0f, 8.0f, 3.0f, 6.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 2.0f, 7.0f, 4.0f);

    // MINSS XMM0, XMM1: F3 0F 5D C1
    add_xmm("minss xmm0,xmm1", {0xF3, 0x0F, 0x5D, 0xC1}, s, 0x3);
    add_misalign_ok("minss xmm0,[rdi] misaligned", {0xF3, 0x0F, 0x5D, 0x07}, {0});
    // MAXSS XMM0, XMM1: F3 0F 5F C1
    add_xmm("maxss xmm0,xmm1", {0xF3, 0x0F, 0x5F, 0xC1}, s, 0x3);
    add_misalign_ok("maxss xmm0,[rdi] misaligned", {0xF3, 0x0F, 0x5F, 0x07}, {0});

    ArchState sd = {};
    sd.xmm[0] = xmm_from_f64(1.5, 8.5);
    sd.xmm[1] = xmm_from_f64(5.5, 2.5);

    // MINPD XMM0, XMM1: 66 0F 5D C1
    add_xmm("minpd xmm0,xmm1", {0x66, 0x0F, 0x5D, 0xC1}, sd, 0x3);
    add_misalign_fault("minpd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x5D, 0x07}, {0});
    // MAXPD XMM0, XMM1: 66 0F 5F C1
    add_xmm("maxpd xmm0,xmm1", {0x66, 0x0F, 0x5F, 0xC1}, sd, 0x3);
    add_misalign_fault("maxpd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x5F, 0x07}, {0});
    // MINSD XMM0, XMM1: F2 0F 5D C1
    add_xmm("minsd xmm0,xmm1", {0xF2, 0x0F, 0x5D, 0xC1}, sd, 0x3);
    add_misalign_ok("minsd xmm0,[rdi] misaligned", {0xF2, 0x0F, 0x5D, 0x07}, {0});
    // MAXSD XMM0, XMM1: F2 0F 5F C1
    add_xmm("maxsd xmm0,xmm1", {0xF2, 0x0F, 0x5F, 0xC1}, sd, 0x3);
    add_misalign_ok("maxsd xmm0,[rdi] misaligned", {0xF2, 0x0F, 0x5F, 0x07}, {0});
  }

  // SSE comparison — CMPPS/CMPPD
  {
    ArchState s;
    s.xmm[0] = xmm_from_f32(1.0f, 5.0f, 3.0f, 3.0f);
    s.xmm[1] = xmm_from_f32(2.0f, 5.0f, 1.0f, 4.0f);

    // CMPPS XMM0, XMM1, 0 (EQ): 0F C2 C1 00
    add_xmm("cmpps eq", {0x0F, 0xC2, 0xC1, 0x00}, s, 0x3);
    add_misalign_fault("cmpps xmm0,[rdi],0 misaligned", {0x0F, 0xC2, 0x07, 0x00}, {0});
    // CMPPS XMM0, XMM1, 1 (LT): 0F C2 C1 01
    add_xmm("cmpps lt", {0x0F, 0xC2, 0xC1, 0x01}, s, 0x3);
    // CMPPS XMM0, XMM1, 2 (LE): 0F C2 C1 02
    add_xmm("cmpps le", {0x0F, 0xC2, 0xC1, 0x02}, s, 0x3);

    ArchState sd = {};
    sd.xmm[0] = xmm_from_f64(1.0, 5.0);
    sd.xmm[1] = xmm_from_f64(2.0, 5.0);

    // CMPPD XMM0, XMM1, 0 (EQ): 66 0F C2 C1 00
    add_xmm("cmppd eq", {0x66, 0x0F, 0xC2, 0xC1, 0x00}, sd, 0x3);
    add_misalign_fault("cmppd xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0xC2, 0x07, 0x00}, {0});
    // CMPPD XMM0, XMM1, 1 (LT): 66 0F C2 C1 01
    add_xmm("cmppd lt", {0x66, 0x0F, 0xC2, 0xC1, 0x01}, sd, 0x3);

    // CMPSS XMM0, XMM1, 0 (EQ): F3 0F C2 C1 00
    add_xmm("cmpss eq", {0xF3, 0x0F, 0xC2, 0xC1, 0x00}, s, 0x3);
    add_misalign_ok("cmpss xmm0,[rdi],0 misaligned", {0xF3, 0x0F, 0xC2, 0x07, 0x00}, {0});
    // CMPSD XMM0, XMM1, 1 (LT): F2 0F C2 C1 01
    add_xmm("cmpsd lt", {0xF2, 0x0F, 0xC2, 0xC1, 0x01}, sd, 0x3);
    add_misalign_ok("cmpsd xmm0,[rdi],0 misaligned", {0xF2, 0x0F, 0xC2, 0x07, 0x00}, {0});
  }

  // SSE2 integer — PSUBW/PSUBD/PSUBQ, PANDN, PCMPEQB/PCMPEQW/PCMPEQD, PCMPGTB
  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x0001020304050607, 0x08090A0B0C0D0E0F);

    // PSUBW XMM0, XMM1: 66 0F F9 C1
    add_xmm("psubw xmm0,xmm1", {0x66, 0x0F, 0xF9, 0xC1}, s, 0x3);
    add_misalign_fault("psubw xmm0,[rdi] misaligned", {0x66, 0x0F, 0xF9, 0x07}, {0});
    // PSUBD XMM0, XMM1: 66 0F FA C1
    add_xmm("psubd xmm0,xmm1", {0x66, 0x0F, 0xFA, 0xC1}, s, 0x3);
    add_misalign_fault("psubd xmm0,[rdi] misaligned", {0x66, 0x0F, 0xFA, 0x07}, {0});
    // PSUBQ XMM0, XMM1: 66 0F FB C1
    add_xmm("psubq xmm0,xmm1", {0x66, 0x0F, 0xFB, 0xC1}, s, 0x3);
    add_misalign_fault("psubq xmm0,[rdi] misaligned", {0x66, 0x0F, 0xFB, 0x07}, {0});
    // PANDN XMM0, XMM1: 66 0F DF C1
    add_xmm("pandn xmm0,xmm1", {0x66, 0x0F, 0xDF, 0xC1}, s, 0x3);
    add_misalign_fault("pandn xmm0,[rdi] misaligned", {0x66, 0x0F, 0xDF, 0x07}, {0});

    // PCMPEQB XMM0, XMM1: 66 0F 74 C1
    add_xmm("pcmpeqb xmm0,xmm1", {0x66, 0x0F, 0x74, 0xC1}, s, 0x3);
    add_misalign_fault("pcmpeqb xmm0,[rdi] misaligned", {0x66, 0x0F, 0x74, 0x07}, {0});
    // PCMPEQW XMM0, XMM1: 66 0F 75 C1
    add_xmm("pcmpeqw xmm0,xmm1", {0x66, 0x0F, 0x75, 0xC1}, s, 0x3);
    add_misalign_fault("pcmpeqw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x75, 0x07}, {0});
    // PCMPEQD XMM0, XMM1: 66 0F 76 C1
    add_xmm("pcmpeqd xmm0,xmm1", {0x66, 0x0F, 0x76, 0xC1}, s, 0x3);
    add_misalign_fault("pcmpeqd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x76, 0x07}, {0});
    // PCMPGTB XMM0, XMM1: 66 0F 64 C1
    add_xmm("pcmpgtb xmm0,xmm1", {0x66, 0x0F, 0x64, 0xC1}, s, 0x3);
    add_misalign_fault("pcmpgtb xmm0,[rdi] misaligned", {0x66, 0x0F, 0x64, 0x07}, {0});
    // PCMPGTW XMM0, XMM1: 66 0F 65 C1
    add_xmm("pcmpgtw xmm0,xmm1", {0x66, 0x0F, 0x65, 0xC1}, s, 0x3);
    add_misalign_fault("pcmpgtw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x65, 0x07}, {0});
    // PCMPGTD XMM0, XMM1: 66 0F 66 C1
    add_xmm("pcmpgtd xmm0,xmm1", {0x66, 0x0F, 0x66, 0xC1}, s, 0x3);
    add_misalign_fault("pcmpgtd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x66, 0x07}, {0});
  }

  // SSE2 shuffle — PSHUFD, SHUFPD, UNPCKLPD, UNPCKHPD
  {
    ArchState s;
    s.xmm[0] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);

    // PSHUFD XMM1, XMM0, 0x1B (reverse): 66 0F 70 C8 1B
    add_xmm("pshufd xmm1,xmm0,0x1b", {0x66, 0x0F, 0x70, 0xC8, 0x1B}, s, 0x2);
    add_misalign_fault("pshufd xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0x70, 0x07, 0x00});
    // PSHUFD XMM1, XMM0, 0x00 (broadcast low): 66 0F 70 C8 00
    add_xmm("pshufd xmm1,xmm0,0x00", {0x66, 0x0F, 0x70, 0xC8, 0x00}, s, 0x2);

    ArchState sd = {};
    sd.xmm[0] = xmm_from_f64(1.0, 2.0);
    sd.xmm[1] = xmm_from_f64(3.0, 4.0);

    // SHUFPD XMM0, XMM1, 0x01: 66 0F C6 C1 01
    add_xmm("shufpd xmm0,xmm1,0x01", {0x66, 0x0F, 0xC6, 0xC1, 0x01}, sd, 0x3);
    add_misalign_fault("shufpd xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0xC6, 0x07, 0x00}, {0});
    // UNPCKLPD XMM0, XMM1: 66 0F 14 C1
    add_xmm("unpcklpd xmm0,xmm1", {0x66, 0x0F, 0x14, 0xC1}, sd, 0x3);
    add_misalign_fault("unpcklpd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x14, 0x07}, {0});
    // UNPCKHPD XMM0, XMM1: 66 0F 15 C1
    add_xmm("unpckhpd xmm0,xmm1", {0x66, 0x0F, 0x15, 0xC1}, sd, 0x3);
    add_misalign_fault("unpckhpd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x15, 0x07}, {0});
  }

  // SSE2 data movement — MOVAPD/MOVUPD/MOVDQA/MOVDQU
  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0xDEADBEEFCAFEBABE, 0x123456789ABCDEF0);

    // MOVAPD XMM2, XMM0: 66 0F 28 D0
    add_xmm("movapd xmm2,xmm0", {0x66, 0x0F, 0x28, 0xD0}, s, 0x4);
    add_misalign_fault("movapd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x28, 0x07});
    // MOVUPD XMM2, XMM0: 66 0F 10 D0
    add_xmm("movupd xmm2,xmm0", {0x66, 0x0F, 0x10, 0xD0}, s, 0x4);
    add_misalign_ok("movupd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x10, 0x07});
    // MOVDQA XMM2, XMM0: 66 0F 6F D0
    add_xmm("movdqa xmm2,xmm0", {0x66, 0x0F, 0x6F, 0xD0}, s, 0x4);
    add_misalign_fault("movdqa xmm0,[rdi] misaligned", {0x66, 0x0F, 0x6F, 0x07});
    // MOVDQU XMM2, XMM0: F3 0F 6F D0
    add_xmm("movdqu xmm2,xmm0", {0xF3, 0x0F, 0x6F, 0xD0}, s, 0x4);
    add_misalign_ok("movdqu xmm0,[rdi] misaligned", {0xF3, 0x0F, 0x6F, 0x07});
    // Store direction: aligned → fault, unaligned → ok
    add_misalign_fault_st("movaps [rdi],xmm0 misaligned", {0x0F, 0x29, 0x07});
    add_misalign_ok_st("movups [rdi],xmm0 misaligned", {0x0F, 0x11, 0x07});
    add_misalign_fault_st("movapd [rdi],xmm0 misaligned", {0x66, 0x0F, 0x29, 0x07});
    add_misalign_ok_st("movupd [rdi],xmm0 misaligned", {0x66, 0x0F, 0x11, 0x07});
    add_misalign_fault_st("movdqa [rdi],xmm0 misaligned", {0x66, 0x0F, 0x7F, 0x07});
    add_misalign_ok_st("movdqu [rdi],xmm0 misaligned", {0xF3, 0x0F, 0x7F, 0x07});
    add_misalign_ok_st("movq [rdi],xmm0 misaligned", {0x66, 0x0F, 0xD6, 0x07}, 8);
    add_misalign_ok_st("movd [rdi],xmm0 misaligned", {0x66, 0x0F, 0x7E, 0x07}, 4);
    add_misalign_fault_st("movntps [rdi],xmm0 misaligned", {0x0F, 0x2B, 0x07});
    add_misalign_fault_st("movntpd [rdi],xmm0 misaligned", {0x66, 0x0F, 0x2B, 0x07});
    add_misalign_fault_st("movntdq [rdi],xmm0 misaligned", {0x66, 0x0F, 0xE7, 0x07});
  }

  // SSE2 pack/unpack integer
  {
    ArchState s;
    s.xmm[0] = xmm_from_u32(0x00010002, 0x00030004, 0x00050006, 0x00070008);
    s.xmm[1] = xmm_from_u32(0x000A000B, 0x000C000D, 0x000E000F, 0x00100011);

    // PACKSSWB XMM0, XMM1: 66 0F 63 C1
    add_xmm("packsswb xmm0,xmm1", {0x66, 0x0F, 0x63, 0xC1}, s, 0x3);
    add_misalign_fault("packsswb xmm0,[rdi] misaligned", {0x66, 0x0F, 0x63, 0x07}, {0});
    // PACKUSWB XMM0, XMM1: 66 0F 67 C1
    add_xmm("packuswb xmm0,xmm1", {0x66, 0x0F, 0x67, 0xC1}, s, 0x3);
    add_misalign_fault("packuswb xmm0,[rdi] misaligned", {0x66, 0x0F, 0x67, 0x07}, {0});
    // PACKSSDW XMM0, XMM1: 66 0F 6B C1
    add_xmm("packssdw xmm0,xmm1", {0x66, 0x0F, 0x6B, 0xC1}, s, 0x3);
    add_misalign_fault("packssdw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x6B, 0x07}, {0});

    // PUNPCKLBW XMM0, XMM1: 66 0F 60 C1
    add_xmm("punpcklbw xmm0,xmm1", {0x66, 0x0F, 0x60, 0xC1}, s, 0x3);
    add_misalign_fault("punpcklbw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x60, 0x07}, {0});
    // PUNPCKLWD XMM0, XMM1: 66 0F 61 C1
    add_xmm("punpcklwd xmm0,xmm1", {0x66, 0x0F, 0x61, 0xC1}, s, 0x3);
    add_misalign_fault("punpcklwd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x61, 0x07}, {0});
    // PUNPCKLDQ XMM0, XMM1: 66 0F 62 C1
    add_xmm("punpckldq xmm0,xmm1", {0x66, 0x0F, 0x62, 0xC1}, s, 0x3);
    add_misalign_fault("punpckldq xmm0,[rdi] misaligned", {0x66, 0x0F, 0x62, 0x07}, {0});
    // PUNPCKLQDQ XMM0, XMM1: 66 0F 6C C1
    add_xmm("punpcklqdq xmm0,xmm1", {0x66, 0x0F, 0x6C, 0xC1}, s, 0x3);
    add_misalign_fault("punpcklqdq xmm0,[rdi] misaligned", {0x66, 0x0F, 0x6C, 0x07}, {0});
    // PUNPCKHBW XMM0, XMM1: 66 0F 68 C1
    add_xmm("punpckhbw xmm0,xmm1", {0x66, 0x0F, 0x68, 0xC1}, s, 0x3);
    add_misalign_fault("punpckhbw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x68, 0x07}, {0});
    // PUNPCKHWD XMM0, XMM1: 66 0F 69 C1
    add_xmm("punpckhwd xmm0,xmm1", {0x66, 0x0F, 0x69, 0xC1}, s, 0x3);
    add_misalign_fault("punpckhwd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x69, 0x07}, {0});
    // PUNPCKHDQ XMM0, XMM1: 66 0F 6A C1
    add_xmm("punpckhdq xmm0,xmm1", {0x66, 0x0F, 0x6A, 0xC1}, s, 0x3);
    add_misalign_fault("punpckhdq xmm0,[rdi] misaligned", {0x66, 0x0F, 0x6A, 0x07}, {0});
    // PUNPCKHQDQ XMM0, XMM1: 66 0F 6D C1
    add_xmm("punpckhqdq xmm0,xmm1", {0x66, 0x0F, 0x6D, 0xC1}, s, 0x3);
    add_misalign_fault("punpckhqdq xmm0,[rdi] misaligned", {0x66, 0x0F, 0x6D, 0x07}, {0});
  }

  // SSE2 shift — PSLLW/PSLLD/PSLLQ/PSRLW/PSRLD/PSRLQ/PSRAW/PSRAD (imm8)
  {
    ArchState s;
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
    // Shift by XMM count from memory (128-bit, align=16)
    add_misalign_fault("psrlw xmm0,[rdi] misaligned", {0x66, 0x0F, 0xD1, 0x07}, {0});
    add_misalign_fault("psrld xmm0,[rdi] misaligned", {0x66, 0x0F, 0xD2, 0x07}, {0});
    add_misalign_fault("psrlq xmm0,[rdi] misaligned", {0x66, 0x0F, 0xD3, 0x07}, {0});
    add_misalign_fault("psraw xmm0,[rdi] misaligned", {0x66, 0x0F, 0xE1, 0x07}, {0});
    add_misalign_fault("psrad xmm0,[rdi] misaligned", {0x66, 0x0F, 0xE2, 0x07}, {0});
    add_misalign_fault("psllw xmm0,[rdi] misaligned", {0x66, 0x0F, 0xF1, 0x07}, {0});
    add_misalign_fault("pslld xmm0,[rdi] misaligned", {0x66, 0x0F, 0xF2, 0x07}, {0});
    add_misalign_fault("psllq xmm0,[rdi] misaligned", {0x66, 0x0F, 0xF3, 0x07}, {0});
  }

  // SSE2 multiply — PMULLW/PMULHW/PMULHUW/PMULUDQ/PMADDWD
  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
    s.xmm[1] = xmm_from_u64(0x0010002000300040, 0x0050006000700080);

    // PMULLW XMM0, XMM1: 66 0F D5 C1
    add_xmm("pmullw xmm0,xmm1", {0x66, 0x0F, 0xD5, 0xC1}, s, 0x3);
    add_misalign_fault("pmullw xmm0,[rdi] misaligned", {0x66, 0x0F, 0xD5, 0x07}, {0});
    // PMULHW XMM0, XMM1: 66 0F E5 C1
    add_xmm("pmulhw xmm0,xmm1", {0x66, 0x0F, 0xE5, 0xC1}, s, 0x3);
    add_misalign_fault("pmulhw xmm0,[rdi] misaligned", {0x66, 0x0F, 0xE5, 0x07}, {0});
    // PMULHUW XMM0, XMM1: 66 0F E4 C1
    add_xmm("pmulhuw xmm0,xmm1", {0x66, 0x0F, 0xE4, 0xC1}, s, 0x3);
    add_misalign_fault("pmulhuw xmm0,[rdi] misaligned", {0x66, 0x0F, 0xE4, 0x07}, {0});
    // PMULUDQ XMM0, XMM1: 66 0F F4 C1
    add_xmm("pmuludq xmm0,xmm1", {0x66, 0x0F, 0xF4, 0xC1}, s, 0x3);
    add_misalign_fault("pmuludq xmm0,[rdi] misaligned", {0x66, 0x0F, 0xF4, 0x07}, {0});
    // PMADDWD XMM0, XMM1: 66 0F F5 C1
    add_xmm("pmaddwd xmm0,xmm1", {0x66, 0x0F, 0xF5, 0xC1}, s, 0x3);
    add_misalign_fault("pmaddwd xmm0,[rdi] misaligned", {0x66, 0x0F, 0xF5, 0x07}, {0});
  }

  // SSE2 saturating arithmetic — PADDSB/PADDSW/PADDUSB/PADDUSW/PSUBSB/PSUBSW/PSUBUSB/PSUBUSW
  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0x7F80FF01FE027E81, 0x7FFF800100FEFF01);
    s.xmm[1] = xmm_from_u64(0x0180017F01FE8001, 0x00017FFF01010101);

    // PADDSB XMM0, XMM1: 66 0F EC C1
    add_xmm("paddsb xmm0,xmm1", {0x66, 0x0F, 0xEC, 0xC1}, s, 0x3);
    add_misalign_fault("paddsb xmm0,[rdi] misaligned", {0x66, 0x0F, 0xEC, 0x07}, {0});
    // PADDSW XMM0, XMM1: 66 0F ED C1
    add_xmm("paddsw xmm0,xmm1", {0x66, 0x0F, 0xED, 0xC1}, s, 0x3);
    add_misalign_fault("paddsw xmm0,[rdi] misaligned", {0x66, 0x0F, 0xED, 0x07}, {0});
    // PADDUSB XMM0, XMM1: 66 0F DC C1
    add_xmm("paddusb xmm0,xmm1", {0x66, 0x0F, 0xDC, 0xC1}, s, 0x3);
    add_misalign_fault("paddusb xmm0,[rdi] misaligned", {0x66, 0x0F, 0xDC, 0x07}, {0});
    // PADDUSW XMM0, XMM1: 66 0F DD C1
    add_xmm("paddusw xmm0,xmm1", {0x66, 0x0F, 0xDD, 0xC1}, s, 0x3);
    add_misalign_fault("paddusw xmm0,[rdi] misaligned", {0x66, 0x0F, 0xDD, 0x07}, {0});
    // PSUBSB XMM0, XMM1: 66 0F E8 C1
    add_xmm("psubsb xmm0,xmm1", {0x66, 0x0F, 0xE8, 0xC1}, s, 0x3);
    add_misalign_fault("psubsb xmm0,[rdi] misaligned", {0x66, 0x0F, 0xE8, 0x07}, {0});
    // PSUBSW XMM0, XMM1: 66 0F E9 C1
    add_xmm("psubsw xmm0,xmm1", {0x66, 0x0F, 0xE9, 0xC1}, s, 0x3);
    add_misalign_fault("psubsw xmm0,[rdi] misaligned", {0x66, 0x0F, 0xE9, 0x07}, {0});
    // PSUBUSB XMM0, XMM1: 66 0F D8 C1
    add_xmm("psubusb xmm0,xmm1", {0x66, 0x0F, 0xD8, 0xC1}, s, 0x3);
    add_misalign_fault("psubusb xmm0,[rdi] misaligned", {0x66, 0x0F, 0xD8, 0x07}, {0});
    // PSUBUSW XMM0, XMM1: 66 0F D9 C1
    add_xmm("psubusw xmm0,xmm1", {0x66, 0x0F, 0xD9, 0xC1}, s, 0x3);
    add_misalign_fault("psubusw xmm0,[rdi] misaligned", {0x66, 0x0F, 0xD9, 0x07}, {0});
  }

  // SSE2 average/SAD — PAVGB/PAVGW/PSADBW
  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x1011121314151617, 0x18191A1B1C1D1E1F);

    // PAVGB XMM0, XMM1: 66 0F E0 C1
    add_xmm("pavgb xmm0,xmm1", {0x66, 0x0F, 0xE0, 0xC1}, s, 0x3);
    add_misalign_fault("pavgb xmm0,[rdi] misaligned", {0x66, 0x0F, 0xE0, 0x07}, {0});
    // PAVGW XMM0, XMM1: 66 0F E3 C1
    add_xmm("pavgw xmm0,xmm1", {0x66, 0x0F, 0xE3, 0xC1}, s, 0x3);
    add_misalign_fault("pavgw xmm0,[rdi] misaligned", {0x66, 0x0F, 0xE3, 0x07}, {0});
    // PSADBW XMM0, XMM1: 66 0F F6 C1
    add_xmm("psadbw xmm0,xmm1", {0x66, 0x0F, 0xF6, 0xC1}, s, 0x3);
    add_misalign_fault("psadbw xmm0,[rdi] misaligned", {0x66, 0x0F, 0xF6, 0x07}, {0});
  }

  // NOTE: RCPPS/RCPSS/RSQRTPS/RSQRTSS are approximate instructions with
  // implementation-defined precision (~1.5*2^-12 relative error per SDM),
  // so we use tolerance-based XMM comparison for the scalar misalign tests.
  add_misalign_fault("rsqrtps xmm0,[rdi] misaligned", {0x0F, 0x52, 0x07});
  {
    TestCase tc;
    tc.name = "rsqrtss xmm0,[rdi] misaligned"; tc.category = cat;
    tc.code = {0xF3, 0x0F, 0x52, 0x07};
    tc.initial = {.rdi = DATA_ADDR + 1};
    tc.flags_mask = FL_ALL; tc.xmm_mask = 0x1; tc.init_data = align_data;
    tc.approx_rel_tol = 1.6e-3; tc.approx_elem_bits = 32;
    tc.approx_result_bits = 32;
    tests.push_back(std::move(tc));
  }
  add_misalign_fault("rcpps xmm0,[rdi] misaligned", {0x0F, 0x53, 0x07});
  {
    TestCase tc;
    tc.name = "rcpss xmm0,[rdi] misaligned"; tc.category = cat;
    tc.code = {0xF3, 0x0F, 0x53, 0x07};
    tc.initial = {.rdi = DATA_ADDR + 1};
    tc.flags_mask = FL_ALL; tc.xmm_mask = 0x1; tc.init_data = align_data;
    tc.approx_rel_tol = 1.6e-3; tc.approx_elem_bits = 32;
    tc.approx_result_bits = 32;
    tests.push_back(std::move(tc));
  }

  // SSE conversions — remaining variants
  {
    // CVTDQ2PD: F3 0F E6 C8 (xmm1,xmm0)
    ArchState si = {};
    si.xmm[0] = xmm_from_u32(1, 0xFFFFFFFF, 100, 0);  // low 2 dwords used
    add_xmm("cvtdq2pd xmm1,xmm0", {0xF3, 0x0F, 0xE6, 0xC8}, si, 0x2);
    add_misalign_ok("cvtdq2pd xmm0,[rdi] misaligned", {0xF3, 0x0F, 0xE6, 0x07});

    // CVTPD2DQ: F2 0F E6 C8 (xmm1,xmm0)
    ArchState sd = {};
    sd.xmm[0] = xmm_from_f64(1.5, -2.5);
    add_xmm("cvtpd2dq xmm1,xmm0", {0xF2, 0x0F, 0xE6, 0xC8}, sd, 0x2);
    add_misalign_fault("cvtpd2dq xmm0,[rdi] misaligned", {0xF2, 0x0F, 0xE6, 0x07});

    // CVTTPD2DQ: 66 0F E6 C8 (xmm1,xmm0)
    add_xmm("cvttpd2dq xmm1,xmm0", {0x66, 0x0F, 0xE6, 0xC8}, sd, 0x2);
    add_misalign_fault("cvttpd2dq xmm0,[rdi] misaligned", {0x66, 0x0F, 0xE6, 0x07});

    // CVTPS2PD: 0F 5A C8 (xmm1,xmm0)
    ArchState sp = {};
    sp.xmm[0] = xmm_from_f32(1.5f, -2.5f, 3.0f, 4.0f);
    add_xmm("cvtps2pd xmm1,xmm0", {0x0F, 0x5A, 0xC8}, sp, 0x2);
    add_misalign_ok("cvtps2pd xmm0,[rdi] misaligned", {0x0F, 0x5A, 0x07});

    // CVTPD2PS: 66 0F 5A C8 (xmm1,xmm0)
    add_xmm("cvtpd2ps xmm1,xmm0", {0x66, 0x0F, 0x5A, 0xC8}, sd, 0x2);
    add_misalign_fault("cvtpd2ps xmm0,[rdi] misaligned", {0x66, 0x0F, 0x5A, 0x07});

    // CVTSS2SD: F3 0F 5A C8 (xmm1,xmm0)
    add_xmm("cvtss2sd xmm1,xmm0", {0xF3, 0x0F, 0x5A, 0xC8}, sp, 0x2);
    add_misalign_ok("cvtss2sd xmm0,[rdi] misaligned", {0xF3, 0x0F, 0x5A, 0x07});

    // CVTSD2SS: F2 0F 5A C8 (xmm1,xmm0)
    add_xmm("cvtsd2ss xmm1,xmm0", {0xF2, 0x0F, 0x5A, 0xC8}, sd, 0x2);
    add_misalign_ok("cvtsd2ss xmm0,[rdi] misaligned", {0xF2, 0x0F, 0x5A, 0x07});

    // CVTSI2SS: F3 0F 2A C0 (xmm0,eax)
    ArchState sg = {};
    sg.rax = 42;
    add_xmm("cvtsi2ss xmm0,eax", {0xF3, 0x0F, 0x2A, 0xC0}, sg, 0x1);
    add_misalign_ok("cvtsi2ss xmm0,[rdi] misaligned", {0xF3, 0x0F, 0x2A, 0x07});

    // CVTSI2SD: F2 0F 2A C0 (xmm0,eax)
    add_xmm("cvtsi2sd xmm0,eax", {0xF2, 0x0F, 0x2A, 0xC0}, sg, 0x1);
    add_misalign_ok("cvtsi2sd xmm0,[rdi] misaligned", {0xF2, 0x0F, 0x2A, 0x07});

    // CVTSI2SS with REX.W (64-bit): F3 48 0F 2A C0 (xmm0,rax)
    ArchState sg64 = {};
    sg64.rax = 0x100000042;
    add_xmm("cvtsi2ss xmm0,rax", {0xF3, 0x48, 0x0F, 0x2A, 0xC0}, sg64, 0x1);

    // CVTSI2SD with REX.W: F2 48 0F 2A C0 (xmm0,rax)
    add_xmm("cvtsi2sd xmm0,rax", {0xF2, 0x48, 0x0F, 0x2A, 0xC0}, sg64, 0x1);

    // CVTSS2SI: F3 0F 2D C0 (eax,xmm0) — result in RAX
    ArchState sf = {};
    sf.xmm[0] = xmm_from_f32(42.5f, 0, 0, 0);
    tests.push_back({"cvtss2si eax,xmm0", cat, {0xF3, 0x0F, 0x2D, 0xC0},
                      sf, FL_ALL, 0x0, false});
    add_misalign_ok_gpr("cvtss2si eax,[rdi] misaligned", {0xF3, 0x0F, 0x2D, 0x07});

    // CVTSD2SI: F2 0F 2D C0 (eax,xmm0)
    ArchState sfd = {};
    sfd.xmm[0] = xmm_from_f64(42.5, 0);
    tests.push_back({"cvtsd2si eax,xmm0", cat, {0xF2, 0x0F, 0x2D, 0xC0},
                      sfd, FL_ALL, 0x0, false});
    add_misalign_ok_gpr("cvtsd2si eax,[rdi] misaligned", {0xF2, 0x0F, 0x2D, 0x07});

    // CVTTSS2SI: F3 0F 2C C0 (eax,xmm0)
    tests.push_back({"cvttss2si eax,xmm0", cat, {0xF3, 0x0F, 0x2C, 0xC0},
                      sf, FL_ALL, 0x0, false});
    add_misalign_ok_gpr("cvttss2si eax,[rdi] misaligned", {0xF3, 0x0F, 0x2C, 0x07});

    // CVTTSD2SI: F2 0F 2C C0 (eax,xmm0)
    tests.push_back({"cvttsd2si eax,xmm0", cat, {0xF2, 0x0F, 0x2C, 0xC0},
                      sfd, FL_ALL, 0x0, false});
    add_misalign_ok_gpr("cvttsd2si eax,[rdi] misaligned", {0xF2, 0x0F, 0x2C, 0x07});
  }

  // COMISS/COMISD — ordered compare, set EFLAGS
  {
    ArchState s;

    s.xmm[0] = xmm_from_f32(1.0f, 0, 0, 0);
    s.xmm[1] = xmm_from_f32(2.0f, 0, 0, 0);
    // COMISS XMM0, XMM1: 0F 2F C1
    add_xmm("comiss lt", {0x0F, 0x2F, 0xC1}, s, 0x0);
    add_misalign_ok_gpr("comiss xmm0,[rdi] misaligned", {0x0F, 0x2F, 0x07}, {0});

    s.xmm[1] = xmm_from_f32(1.0f, 0, 0, 0);
    add_xmm("comiss eq", {0x0F, 0x2F, 0xC1}, s, 0x0);

    ArchState sd = {};
    sd.xmm[0] = xmm_from_f64(3.0, 0);
    sd.xmm[1] = xmm_from_f64(1.0, 0);
    // COMISD XMM0, XMM1: 66 0F 2F C1
    add_xmm("comisd gt", {0x66, 0x0F, 0x2F, 0xC1}, sd, 0x0);
    add_misalign_ok_gpr("comisd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x2F, 0x07}, {0});
  }

  // PSLLDQ/PSRLDQ — byte shift
  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);

    // PSLLDQ XMM0, 3: 66 0F 73 F8 03 (ModRM /7, rm=xmm0)
    add_xmm("pslldq xmm0,3", {0x66, 0x0F, 0x73, 0xF8, 0x03}, s, 0x1);
    // PSRLDQ XMM0, 3: 66 0F 73 D8 03 (ModRM /3, rm=xmm0)
    add_xmm("psrldq xmm0,3", {0x66, 0x0F, 0x73, 0xD8, 0x03}, s, 0x1);
  }

  // MOVHLPS/MOVLHPS — reg-reg forms
  {
    ArchState s;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // MOVHLPS XMM0, XMM1: 0F 12 C1 (move high half of xmm1 to low half of xmm0)
    add_xmm("movhlps xmm0,xmm1", {0x0F, 0x12, 0xC1}, s, 0x3);
    // MOVLHPS XMM0, XMM1: 0F 16 C1 (move low half of xmm1 to high half of xmm0)
    add_xmm("movlhps xmm0,xmm1", {0x0F, 0x16, 0xC1}, s, 0x3);
    // MOVLPS/MOVLPD/MOVHPS/MOVHPD memory forms — no alignment required
    add_misalign_ok("movlps xmm0,[rdi] misaligned", {0x0F, 0x12, 0x07});
    add_misalign_ok_st("movlps [rdi],xmm0 misaligned", {0x0F, 0x13, 0x07}, 8);
    add_misalign_ok("movlpd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x12, 0x07});
    add_misalign_ok_st("movlpd [rdi],xmm0 misaligned", {0x66, 0x0F, 0x13, 0x07}, 8);
    add_misalign_ok("movhps xmm0,[rdi] misaligned", {0x0F, 0x16, 0x07});
    add_misalign_ok_st("movhps [rdi],xmm0 misaligned", {0x0F, 0x17, 0x07}, 8);
    add_misalign_ok("movhpd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x16, 0x07});
    add_misalign_ok_st("movhpd [rdi],xmm0 misaligned", {0x66, 0x0F, 0x17, 0x07}, 8);
  }

  // MOVSS/MOVSD — reg-reg forms (merge into low element)
  {
    ArchState s;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);

    // MOVSS XMM0, XMM1: F3 0F 10 C1 (merge low dword of xmm1 into xmm0)
    add_xmm("movss xmm0,xmm1", {0xF3, 0x0F, 0x10, 0xC1}, s, 0x3);
    add_misalign_ok("movss xmm0,[rdi] misaligned", {0xF3, 0x0F, 0x10, 0x07});
    add_misalign_ok_st("movss [rdi],xmm0 misaligned", {0xF3, 0x0F, 0x11, 0x07}, 4);

    ArchState sd = {};
    sd.xmm[0] = xmm_from_f64(1.5, 2.5);
    sd.xmm[1] = xmm_from_f64(10.5, 20.5);

    // MOVSD XMM0, XMM1: F2 0F 10 C1 (merge low qword of xmm1 into xmm0)
    add_xmm("movsd xmm0,xmm1", {0xF2, 0x0F, 0x10, 0xC1}, sd, 0x3);
    add_misalign_ok("movsd xmm0,[rdi] misaligned", {0xF2, 0x0F, 0x10, 0x07});
    add_misalign_ok_st("movsd [rdi],xmm0 misaligned", {0xF2, 0x0F, 0x11, 0x07}, 8);
  }

  // PINSRW/PEXTRW
  {
    ArchState s;
    s.rax = 0x1234;
    s.xmm[0] = xmm_from_u64(0, 0);

    // PINSRW XMM0, EAX, 3: 66 0F C4 C0 03
    add_xmm("pinsrw xmm0,eax,3", {0x66, 0x0F, 0xC4, 0xC0, 0x03}, s, 0x1);
    add_misalign_ok("pinsrw xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0xC4, 0x07, 0x00}, {0});

    // PEXTRW EAX, XMM1, 2: 66 0F C5 C1 02
    ArchState s2 = {};
    s2.xmm[1] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
    tests.push_back({"pextrw eax,xmm1,2", cat, {0x66, 0x0F, 0xC5, 0xC1, 0x02},
                      s2, FL_ALL, 0x0, false});
    add_misalign_ok_st("pextrw [rdi],xmm0,0 misaligned", {0x66, 0x0F, 0x3A, 0x15, 0x07, 0x00}, 2);
    add_misalign_ok("pinsrq xmm0,[rdi],0 misaligned", {0x66, 0x48, 0x0F, 0x3A, 0x22, 0x07, 0x00}, {0});
    add_misalign_ok_st("pextrq [rdi],xmm0,0 misaligned", {0x66, 0x48, 0x0F, 0x3A, 0x16, 0x07, 0x00}, 8);
  }

  // SSE2 PSHUFHW/PSHUFLW
  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);

    // PSHUFHW XMM1, XMM0, 0x1B: F3 0F 70 C8 1B
    add_xmm("pshufhw xmm1,xmm0,0x1b", {0xF3, 0x0F, 0x70, 0xC8, 0x1B}, s, 0x2);
    add_misalign_fault("pshufhw xmm0,[rdi],0 misaligned", {0xF3, 0x0F, 0x70, 0x07, 0x00});
    // PSHUFLW XMM1, XMM0, 0x1B: F2 0F 70 C8 1B
    add_xmm("pshuflw xmm1,xmm0,0x1b", {0xF2, 0x0F, 0x70, 0xC8, 0x1B}, s, 0x2);
    add_misalign_fault("pshuflw xmm0,[rdi],0 misaligned", {0xF2, 0x0F, 0x70, 0x07, 0x00});
  }

  // =====================================================================
  // 24. SSSE3 — supplemental SSE3 integer instructions
  // =====================================================================
  cat = "SSSE3";

  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x0003020100070605, 0x0403020108070605);

    // PSHUFB XMM0, XMM1: 66 0F 38 00 C1
    add_xmm("pshufb xmm0,xmm1", {0x66, 0x0F, 0x38, 0x00, 0xC1}, s, 0x3);
    add_misalign_fault("pshufb xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x00, 0x07}, {0});
  }

  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
    s.xmm[1] = xmm_from_u64(0x0010002000300040, 0x0050006000700080);

    // PHADDW XMM0, XMM1: 66 0F 38 01 C1
    add_xmm("phaddw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x01, 0xC1}, s, 0x3);
    add_misalign_fault("phaddw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x01, 0x07}, {0});
    // PHADDD XMM0, XMM1: 66 0F 38 02 C1
    add_xmm("phaddd xmm0,xmm1", {0x66, 0x0F, 0x38, 0x02, 0xC1}, s, 0x3);
    add_misalign_fault("phaddd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x02, 0x07}, {0});
    // PHADDSW XMM0, XMM1: 66 0F 38 03 C1
    add_xmm("phaddsw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x03, 0xC1}, s, 0x3);
    add_misalign_fault("phaddsw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x03, 0x07}, {0});
    // PHSUBW XMM0, XMM1: 66 0F 38 05 C1
    add_xmm("phsubw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x05, 0xC1}, s, 0x3);
    add_misalign_fault("phsubw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x05, 0x07}, {0});
    // PHSUBD XMM0, XMM1: 66 0F 38 06 C1
    add_xmm("phsubd xmm0,xmm1", {0x66, 0x0F, 0x38, 0x06, 0xC1}, s, 0x3);
    add_misalign_fault("phsubd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x06, 0x07}, {0});
    // PHSUBSW XMM0, XMM1: 66 0F 38 07 C1
    add_xmm("phsubsw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x07, 0xC1}, s, 0x3);
    add_misalign_fault("phsubsw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x07, 0x07}, {0});

    // PMADDUBSW XMM0, XMM1: 66 0F 38 04 C1
    add_xmm("pmaddubsw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x04, 0xC1}, s, 0x3);
    add_misalign_fault("pmaddubsw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x04, 0x07}, {0});
    // PMULHRSW XMM0, XMM1: 66 0F 38 0B C1
    add_xmm("pmulhrsw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x0B, 0xC1}, s, 0x3);
    add_misalign_fault("pmulhrsw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x0B, 0x07}, {0});
  }

  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0x01FF037F05816082, 0x7FFFFFFF80000001);

    // PABSB XMM1, XMM0: 66 0F 38 1C C8
    add_xmm("pabsb xmm1,xmm0", {0x66, 0x0F, 0x38, 0x1C, 0xC8}, s, 0x2);
    add_misalign_fault("pabsb xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x1C, 0x07});
    // PABSW XMM1, XMM0: 66 0F 38 1D C8
    add_xmm("pabsw xmm1,xmm0", {0x66, 0x0F, 0x38, 0x1D, 0xC8}, s, 0x2);
    add_misalign_fault("pabsw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x1D, 0x07});
    // PABSD XMM1, XMM0: 66 0F 38 1E C8
    add_xmm("pabsd xmm1,xmm0", {0x66, 0x0F, 0x38, 0x1E, 0xC8}, s, 0x2);
    add_misalign_fault("pabsd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x1E, 0x07});
  }

  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0x01FF037F05816082, 0x7FFFFFFF80000001);
    s.xmm[1] = xmm_from_u64(0x0001000100010001, 0xFFFF0000FFFF0000);

    // PSIGNB XMM0, XMM1: 66 0F 38 08 C1
    add_xmm("psignb xmm0,xmm1", {0x66, 0x0F, 0x38, 0x08, 0xC1}, s, 0x3);
    add_misalign_fault("psignb xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x08, 0x07}, {0});
    // PSIGNW XMM0, XMM1: 66 0F 38 09 C1
    add_xmm("psignw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x09, 0xC1}, s, 0x3);
    add_misalign_fault("psignw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x09, 0x07}, {0});
    // PSIGND XMM0, XMM1: 66 0F 38 0A C1
    add_xmm("psignd xmm0,xmm1", {0x66, 0x0F, 0x38, 0x0A, 0xC1}, s, 0x3);
    add_misalign_fault("psignd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x0A, 0x07}, {0});
  }

  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // PALIGNR XMM0, XMM1, 4: 66 0F 3A 0F C1 04
    add_xmm("palignr xmm0,xmm1,4", {0x66, 0x0F, 0x3A, 0x0F, 0xC1, 0x04}, s, 0x3);
    add_misalign_fault("palignr xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0x3A, 0x0F, 0x07, 0x00}, {0});
  }

  // =====================================================================
  // 25. SSE4.1 instructions
  // =====================================================================
  cat = "SSE4.1";

  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0x01FF037F05816082, 0x7FFFFFFF80000001);
    s.xmm[1] = xmm_from_u64(0x02FE027E04806183, 0x80000000FFFFFFFF);

    // PMAXSB XMM0, XMM1: 66 0F 38 3C C1
    add_xmm("pmaxsb xmm0,xmm1", {0x66, 0x0F, 0x38, 0x3C, 0xC1}, s, 0x3);
    add_misalign_fault("pmaxsb xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x3C, 0x07}, {0});
    // PMAXSD XMM0, XMM1: 66 0F 38 3D C1
    add_xmm("pmaxsd xmm0,xmm1", {0x66, 0x0F, 0x38, 0x3D, 0xC1}, s, 0x3);
    add_misalign_fault("pmaxsd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x3D, 0x07}, {0});
    // PMAXUW XMM0, XMM1: 66 0F 38 3E C1
    add_xmm("pmaxuw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x3E, 0xC1}, s, 0x3);
    add_misalign_fault("pmaxuw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x3E, 0x07}, {0});
    // PMAXUD XMM0, XMM1: 66 0F 38 3F C1
    add_xmm("pmaxud xmm0,xmm1", {0x66, 0x0F, 0x38, 0x3F, 0xC1}, s, 0x3);
    add_misalign_fault("pmaxud xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x3F, 0x07}, {0});

    // PMINSB XMM0, XMM1: 66 0F 38 38 C1
    add_xmm("pminsb xmm0,xmm1", {0x66, 0x0F, 0x38, 0x38, 0xC1}, s, 0x3);
    add_misalign_fault("pminsb xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x38, 0x07}, {0});
    // PMINSD XMM0, XMM1: 66 0F 38 39 C1
    add_xmm("pminsd xmm0,xmm1", {0x66, 0x0F, 0x38, 0x39, 0xC1}, s, 0x3);
    add_misalign_fault("pminsd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x39, 0x07}, {0});
    // PMINUW XMM0, XMM1: 66 0F 38 3A C1
    add_xmm("pminuw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x3A, 0xC1}, s, 0x3);
    add_misalign_fault("pminuw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x3A, 0x07}, {0});
    // PMINUD XMM0, XMM1: 66 0F 38 3B C1
    add_xmm("pminud xmm0,xmm1", {0x66, 0x0F, 0x38, 0x3B, 0xC1}, s, 0x3);
    add_misalign_fault("pminud xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x3B, 0x07}, {0});

    // PMAXSW (SSE2): 66 0F EE C1
    add_xmm("pmaxsw xmm0,xmm1", {0x66, 0x0F, 0xEE, 0xC1}, s, 0x3);
    add_misalign_fault("pmaxsw xmm0,[rdi] misaligned", {0x66, 0x0F, 0xEE, 0x07}, {0});
    // PMINSW (SSE2): 66 0F EA C1
    add_xmm("pminsw xmm0,xmm1", {0x66, 0x0F, 0xEA, 0xC1}, s, 0x3);
    add_misalign_fault("pminsw xmm0,[rdi] misaligned", {0x66, 0x0F, 0xEA, 0x07}, {0});
    // PMAXUB (SSE2): 66 0F DE C1
    add_xmm("pmaxub xmm0,xmm1", {0x66, 0x0F, 0xDE, 0xC1}, s, 0x3);
    add_misalign_fault("pmaxub xmm0,[rdi] misaligned", {0x66, 0x0F, 0xDE, 0x07}, {0});
    // PMINUB (SSE2): 66 0F DA C1
    add_xmm("pminub xmm0,xmm1", {0x66, 0x0F, 0xDA, 0xC1}, s, 0x3);
    add_misalign_fault("pminub xmm0,[rdi] misaligned", {0x66, 0x0F, 0xDA, 0x07}, {0});

    // PMULLD XMM0, XMM1: 66 0F 38 40 C1
    add_xmm("pmulld xmm0,xmm1", {0x66, 0x0F, 0x38, 0x40, 0xC1}, s, 0x3);
    add_misalign_fault("pmulld xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x40, 0x07}, {0});

    // PACKUSDW XMM0, XMM1: 66 0F 38 2B C1
    add_xmm("packusdw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x2B, 0xC1}, s, 0x3);
    add_misalign_fault("packusdw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x2B, 0x07}, {0});

    // PCMPEQQ XMM0, XMM1: 66 0F 38 29 C1
    add_xmm("pcmpeqq xmm0,xmm1", {0x66, 0x0F, 0x38, 0x29, 0xC1}, s, 0x3);
    add_misalign_fault("pcmpeqq xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x29, 0x07}, {0});
    // PMULDQ XMM0, XMM1: 66 0F 38 28 C1 — align=16
    add_misalign_fault("pmuldq xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x28, 0x07}, {0});
    // MOVNTDQA XMM0, [RDI]: 66 0F 38 2A 07 — align=16
    add_misalign_fault("movntdqa xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x2A, 0x07});
    // PHMINPOSUW XMM0, [RDI]: 66 0F 38 41 07 — align=16
    add_misalign_fault("phminposuw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x41, 0x07});
    // PCMPGTQ XMM0, [RDI]: 66 0F 38 37 07 — align=16
    add_misalign_fault("pcmpgtq xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x37, 0x07}, {0});
    // PBLENDVB/BLENDVPS/BLENDVPD (implicit XMM0 mask, align=16)
    add_misalign_fault("pblendvb xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x10, 0x07}, {0});
    add_misalign_fault("blendvps xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x14, 0x07}, {0});
    add_misalign_fault("blendvpd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x15, 0x07}, {0});
  }

  // PINSRB/PINSRD/PEXTRB/PEXTRD
  {
    ArchState s;
    s.rax = 0x42;
    s.xmm[0] = xmm_from_u64(0, 0);

    // PINSRB XMM0, EAX, 5: 66 0F 3A 20 C0 05
    add_xmm("pinsrb xmm0,eax,5", {0x66, 0x0F, 0x3A, 0x20, 0xC0, 0x05}, s, 0x1);
    add_misalign_ok("pinsrb xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0x3A, 0x20, 0x07, 0x00}, {0});
    // PINSRD XMM0, EAX, 2: 66 0F 3A 22 C0 02
    add_xmm("pinsrd xmm0,eax,2", {0x66, 0x0F, 0x3A, 0x22, 0xC0, 0x02}, s, 0x1);
    add_misalign_ok("pinsrd xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0x3A, 0x22, 0x07, 0x00}, {0});

    ArchState s2 = {};
    s2.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);

    // PEXTRB EAX, XMM0, 5: 66 0F 3A 14 C0 05
    tests.push_back({"pextrb eax,xmm0,5", cat, {0x66, 0x0F, 0x3A, 0x14, 0xC0, 0x05},
                      s2, FL_ALL, 0x0, false});
    add_misalign_ok_st("pextrb [rdi],xmm0,0 misaligned", {0x66, 0x0F, 0x3A, 0x14, 0x07, 0x00}, 1);
    // PEXTRD EAX, XMM0, 2: 66 0F 3A 16 C0 02
    tests.push_back({"pextrd eax,xmm0,2", cat, {0x66, 0x0F, 0x3A, 0x16, 0xC0, 0x02},
                      s2, FL_ALL, 0x0, false});
    add_misalign_ok_st("pextrd [rdi],xmm0,0 misaligned", {0x66, 0x0F, 0x3A, 0x16, 0x07, 0x00}, 4);
  }

  // EXTRACTPS/INSERTPS
  {
    ArchState s;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);

    // EXTRACTPS EAX, XMM0, 2: 66 0F 3A 17 C0 02
    tests.push_back({"extractps eax,xmm0,2", cat, {0x66, 0x0F, 0x3A, 0x17, 0xC0, 0x02},
                      s, FL_ALL, 0x0, false});
    add_misalign_ok_st("extractps [rdi],xmm0,0 misaligned", {0x66, 0x0F, 0x3A, 0x17, 0x07, 0x00}, 4);

    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    // INSERTPS XMM0, XMM1, 0x1A: 66 0F 3A 21 C1 1A (src[1] -> dst[2], zero mask=0b1010)
    add_xmm("insertps xmm0,xmm1,0x1a", {0x66, 0x0F, 0x3A, 0x21, 0xC1, 0x1A}, s, 0x3);
    add_misalign_ok("insertps xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0x3A, 0x21, 0x07, 0x00}, {0});
  }

  // BLENDPS/BLENDPD/PBLENDW
  {
    ArchState s;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);

    // BLENDPS XMM0, XMM1, 0x0A: 66 0F 3A 0C C1 0A (blend elements 1,3)
    add_xmm("blendps xmm0,xmm1,0x0a", {0x66, 0x0F, 0x3A, 0x0C, 0xC1, 0x0A}, s, 0x3);
    add_misalign_fault("blendps xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0x3A, 0x0C, 0x07, 0x00}, {0});

    ArchState sd = {};
    sd.xmm[0] = xmm_from_f64(1.0, 2.0);
    sd.xmm[1] = xmm_from_f64(10.0, 20.0);

    // BLENDPD XMM0, XMM1, 0x02: 66 0F 3A 0D C1 02 (blend element 1)
    add_xmm("blendpd xmm0,xmm1,0x02", {0x66, 0x0F, 0x3A, 0x0D, 0xC1, 0x02}, sd, 0x3);
    add_misalign_fault("blendpd xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0x3A, 0x0D, 0x07, 0x00}, {0});

    ArchState si = {};
    si.xmm[0] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
    si.xmm[1] = xmm_from_u64(0x0010002000300040, 0x0050006000700080);

    // PBLENDW XMM0, XMM1, 0xAA: 66 0F 3A 0E C1 AA (blend alternate words)
    add_xmm("pblendw xmm0,xmm1,0xaa", {0x66, 0x0F, 0x3A, 0x0E, 0xC1, 0xAA}, si, 0x3);
    add_misalign_fault("pblendw xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0x3A, 0x0E, 0x07, 0x00}, {0});
  }

  // ROUNDPS/ROUNDPD/ROUNDSS/ROUNDSD
  {
    ArchState s;
    s.xmm[0] = xmm_from_f32(1.3f, 2.7f, -1.5f, -2.5f);

    // ROUNDPS XMM1, XMM0, 0 (round nearest): 66 0F 3A 08 C8 00
    add_xmm("roundps nearest", {0x66, 0x0F, 0x3A, 0x08, 0xC8, 0x00}, s, 0x2);
    add_misalign_fault("roundps xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0x3A, 0x08, 0x07, 0x00});
    // ROUNDPS XMM1, XMM0, 1 (floor): 66 0F 3A 08 C8 01
    add_xmm("roundps floor", {0x66, 0x0F, 0x3A, 0x08, 0xC8, 0x01}, s, 0x2);
    // ROUNDPS XMM1, XMM0, 2 (ceil): 66 0F 3A 08 C8 02
    add_xmm("roundps ceil", {0x66, 0x0F, 0x3A, 0x08, 0xC8, 0x02}, s, 0x2);
    // ROUNDPS XMM1, XMM0, 3 (truncate): 66 0F 3A 08 C8 03
    add_xmm("roundps trunc", {0x66, 0x0F, 0x3A, 0x08, 0xC8, 0x03}, s, 0x2);

    ArchState sd = {};
    sd.xmm[0] = xmm_from_f64(1.3, -2.7);

    // ROUNDPD XMM1, XMM0, 0: 66 0F 3A 09 C8 00
    add_xmm("roundpd nearest", {0x66, 0x0F, 0x3A, 0x09, 0xC8, 0x00}, sd, 0x2);
    add_misalign_fault("roundpd xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0x3A, 0x09, 0x07, 0x00});
    // ROUNDPD XMM1, XMM0, 1: 66 0F 3A 09 C8 01
    add_xmm("roundpd floor", {0x66, 0x0F, 0x3A, 0x09, 0xC8, 0x01}, sd, 0x2);

    // ROUNDSS XMM1, XMM0, 0: 66 0F 3A 0A C8 00
    add_xmm("roundss nearest", {0x66, 0x0F, 0x3A, 0x0A, 0xC8, 0x00}, s, 0x2);
    add_misalign_ok("roundss xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0x3A, 0x0A, 0x07, 0x00});
    // ROUNDSD XMM1, XMM0, 1: 66 0F 3A 0B C8 01
    add_xmm("roundsd floor", {0x66, 0x0F, 0x3A, 0x0B, 0xC8, 0x01}, sd, 0x2);
    add_misalign_ok("roundsd xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0x3A, 0x0B, 0x07, 0x00});
  }

  // PTEST — sets ZF and CF in EFLAGS
  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0xFF00FF00FF00FF00, 0x00FF00FF00FF00FF);
    s.xmm[1] = xmm_from_u64(0x00FF00FF00FF00FF, 0xFF00FF00FF00FF00);

    // PTEST XMM0, XMM1: 66 0F 38 17 C1 (AND is zero → ZF=1)
    add_xmm("ptest zero", {0x66, 0x0F, 0x38, 0x17, 0xC1}, s, 0x0);
    add_misalign_fault("ptest xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x17, 0x07}, {0});

    s.xmm[1] = s.xmm[0];
    // PTEST XMM0, XMM0: same bits → ZF=0
    add_xmm("ptest nonzero", {0x66, 0x0F, 0x38, 0x17, 0xC1}, s, 0x0);
  }

  // PMOVZX — zero-extend packed integers
  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0);

    // PMOVZXBW XMM1, XMM0: 66 0F 38 30 C8
    add_xmm("pmovzxbw xmm1,xmm0", {0x66, 0x0F, 0x38, 0x30, 0xC8}, s, 0x2);
    add_misalign_ok("pmovzxbw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x30, 0x07});
    // PMOVZXBD XMM1, XMM0: 66 0F 38 31 C8
    add_xmm("pmovzxbd xmm1,xmm0", {0x66, 0x0F, 0x38, 0x31, 0xC8}, s, 0x2);
    add_misalign_ok("pmovzxbd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x31, 0x07});
    // PMOVZXBQ XMM1, XMM0: 66 0F 38 32 C8
    add_xmm("pmovzxbq xmm1,xmm0", {0x66, 0x0F, 0x38, 0x32, 0xC8}, s, 0x2);
    add_misalign_ok("pmovzxbq xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x32, 0x07});
    // PMOVZXWD XMM1, XMM0: 66 0F 38 33 C8
    add_xmm("pmovzxwd xmm1,xmm0", {0x66, 0x0F, 0x38, 0x33, 0xC8}, s, 0x2);
    add_misalign_ok("pmovzxwd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x33, 0x07});
    // PMOVZXWQ XMM1, XMM0: 66 0F 38 34 C8
    add_xmm("pmovzxwq xmm1,xmm0", {0x66, 0x0F, 0x38, 0x34, 0xC8}, s, 0x2);
    add_misalign_ok("pmovzxwq xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x34, 0x07});
    // PMOVZXDQ XMM1, XMM0: 66 0F 38 35 C8
    add_xmm("pmovzxdq xmm1,xmm0", {0x66, 0x0F, 0x38, 0x35, 0xC8}, s, 0x2);
    add_misalign_ok("pmovzxdq xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x35, 0x07});
  }

  // PMOVSX — sign-extend packed integers
  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0x01FF037F05816082, 0);

    // PMOVSXBW XMM1, XMM0: 66 0F 38 20 C8
    add_xmm("pmovsxbw xmm1,xmm0", {0x66, 0x0F, 0x38, 0x20, 0xC8}, s, 0x2);
    add_misalign_ok("pmovsxbw xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x20, 0x07});
    // PMOVSXBD XMM1, XMM0: 66 0F 38 21 C8
    add_xmm("pmovsxbd xmm1,xmm0", {0x66, 0x0F, 0x38, 0x21, 0xC8}, s, 0x2);
    add_misalign_ok("pmovsxbd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x21, 0x07});
    // PMOVSXBQ XMM1, XMM0: 66 0F 38 22 C8
    add_xmm("pmovsxbq xmm1,xmm0", {0x66, 0x0F, 0x38, 0x22, 0xC8}, s, 0x2);
    add_misalign_ok("pmovsxbq xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x22, 0x07});
    // PMOVSXWD XMM1, XMM0: 66 0F 38 23 C8
    add_xmm("pmovsxwd xmm1,xmm0", {0x66, 0x0F, 0x38, 0x23, 0xC8}, s, 0x2);
    add_misalign_ok("pmovsxwd xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x23, 0x07});
    // PMOVSXWQ XMM1, XMM0: 66 0F 38 24 C8
    add_xmm("pmovsxwq xmm1,xmm0", {0x66, 0x0F, 0x38, 0x24, 0xC8}, s, 0x2);
    add_misalign_ok("pmovsxwq xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x24, 0x07});
    // PMOVSXDQ XMM1, XMM0: 66 0F 38 25 C8
    add_xmm("pmovsxdq xmm1,xmm0", {0x66, 0x0F, 0x38, 0x25, 0xC8}, s, 0x2);
    add_misalign_ok("pmovsxdq xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0x25, 0x07});
  }

  // DPPS/DPPD — dot product
  {
    ArchState s;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // DPPS XMM0, XMM1, 0xFF: 66 0F 3A 40 C1 FF (all elements, broadcast result)
    add_xmm("dpps xmm0,xmm1,0xff", {0x66, 0x0F, 0x3A, 0x40, 0xC1, 0xFF}, s, 0x3);
    add_misalign_fault("dpps xmm0,[rdi],0xFF misaligned", {0x66, 0x0F, 0x3A, 0x40, 0x07, 0xFF}, {0});
    // DPPS XMM0, XMM1, 0x71: first 3 elements, result to element 0 only
    add_xmm("dpps xmm0,xmm1,0x71", {0x66, 0x0F, 0x3A, 0x40, 0xC1, 0x71}, s, 0x3);

    ArchState sd = {};
    sd.xmm[0] = xmm_from_f64(1.5, 2.5);
    sd.xmm[1] = xmm_from_f64(3.0, 4.0);

    // DPPD XMM0, XMM1, 0x33: 66 0F 3A 41 C1 33 (both elements, broadcast)
    add_xmm("dppd xmm0,xmm1,0x33", {0x66, 0x0F, 0x3A, 0x41, 0xC1, 0x33}, sd, 0x3);
    add_misalign_fault("dppd xmm0,[rdi],0x33 misaligned", {0x66, 0x0F, 0x3A, 0x41, 0x07, 0x33}, {0});
  }

  // MPSADBW — test all 8 imm8[2:0] combinations
  {
    ArchState s;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // MPSADBW XMM0, XMM1, imm8: 66 0F 3A 42 C1 imm8
    for (u8 imm = 0; imm < 8; imm++) {
      add_xmm("mpsadbw imm=" + std::to_string(imm),
              {0x66, 0x0F, 0x3A, 0x42, 0xC1, imm}, s, 0x3);
    }
    add_misalign_fault("mpsadbw xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0x3A, 0x42, 0x07, 0x00}, {0});

    // MPSADBW with identical operands (all SADs should be 0)
    ArchState s2;
    s2.xmm[0] = xmm_from_u64(0xAABBCCDDEEFF0011, 0x2233445566778899);
    s2.xmm[1] = s2.xmm[0];
    add_xmm("mpsadbw identical", {0x66, 0x0F, 0x3A, 0x42, 0xC1, 0x00}, s2, 0x3);

    // MPSADBW with max contrast (0x00 vs 0xFF)
    ArchState s3;
    s3.xmm[0] = xmm_from_u64(0x0000000000000000, 0x0000000000000000);
    s3.xmm[1] = xmm_from_u64(0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF);
    add_xmm("mpsadbw max contrast", {0x66, 0x0F, 0x3A, 0x42, 0xC1, 0x00}, s3, 0x3);
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
      ArchState s = {.rdi = DATA_ADDR};
      s.xmm[0] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      std::vector<u8> data = {0xAA, 0xBB, 0xCC, 0xDD, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
      tests.push_back({"insertps xmm,m32 count_s=3", cat,
        {0x66, 0x0F, 0x3A, 0x21, 0x07, 0xC0},
        s, FL_ALL, 0x1, false, data, 0});
    }

    // INSERTPS XMM0, [RDI], 0x10: count_s=0, count_d=1, zmask=0
    // Insert 32-bit [RDI] into XMM0[63:32]
    {
      ArchState s = {.rdi = DATA_ADDR};
      s.xmm[0] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      std::vector<u8> data = {0xEE, 0xFF, 0x00, 0x11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
      tests.push_back({"insertps xmm,m32 dst=1", cat,
        {0x66, 0x0F, 0x3A, 0x21, 0x07, 0x10},
        s, FL_ALL, 0x1, false, data, 0});
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
      ArchState s = {.rdi = DATA_ADDR};
      s.xmm[1] = xmm_from_u64(0xAAAAAAAAAAAAAAAA, 0xBBBBBBBBBBBBBBBB);
      std::vector<u8> data = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88};
      tests.push_back({"vmovlpd xmm0,xmm1,[rdi]", cat,
        {0xC5, 0xF1, 0x12, 0x07}, s, FL_ALL, 0x1, false, data, 0});
    }

    // VMOVSLDUP xmm0, xmm1: VEX.128.F3.0F.WIG 12 /r
    // C5 FA 12 C1: VEX pp=10(F3), vvvv=1111, opcode=12, modrm=C1(xmm1)
    // SDM: DEST = [src[95:64], src[95:64], src[31:0], src[31:0]]
    {
      ArchState s = {};
      s.xmm[1] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      tests.push_back({"vmovsldup xmm0,xmm1", cat,
        {0xC5, 0xFA, 0x12, 0xC1}, s, FL_ALL, 0x1});
    }
    add_misalign_fault("movsldup xmm0,[rdi] misaligned", {0xF3, 0x0F, 0x12, 0x07});

    // VMOVDDUP xmm0, xmm1: VEX.128.F2.0F.WIG 12 /r
    // C5 FB 12 C1: VEX pp=11(F2), vvvv=1111, opcode=12, modrm=C1(xmm1)
    // SDM: DEST[63:0] := SRC[63:0]; DEST[127:64] := SRC[63:0]
    {
      ArchState s = {};
      s.xmm[1] = xmm_from_u64(0x1234567890ABCDEF, 0xFEDCBA0987654321);
      tests.push_back({"vmovddup xmm0,xmm1", cat,
        {0xC5, 0xFB, 0x12, 0xC1}, s, FL_ALL, 0x1});
    }
    add_misalign_ok("movddup xmm0,[rdi] misaligned", {0xF2, 0x0F, 0x12, 0x07});

    // VMOVHPD xmm0, xmm1, [rdi]: VEX.128.66.0F.WIG 16 /r
    // C5 F1 16 07: VEX pp=01(66), vvvv=xmm1, opcode=16, modrm=07([rdi])
    // SDM: DEST[63:0] := SRC1[63:0]; DEST[127:64] := SRC2[63:0]; upper zeroed
    {
      ArchState s = {.rdi = DATA_ADDR};
      s.xmm[1] = xmm_from_u64(0xAAAAAAAAAAAAAAAA, 0xBBBBBBBBBBBBBBBB);
      std::vector<u8> data = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88};
      tests.push_back({"vmovhpd xmm0,xmm1,[rdi]", cat,
        {0xC5, 0xF1, 0x16, 0x07}, s, FL_ALL, 0x1, false, data, 0});
    }

    // VMOVSHDUP xmm0, xmm1: VEX.128.F3.0F.WIG 16 /r
    // C5 FA 16 C1: VEX pp=10(F3), vvvv=1111, opcode=16, modrm=C1(xmm1)
    // SDM: DEST = [src[127:96], src[127:96], src[63:32], src[63:32]]
    {
      ArchState s = {};
      s.xmm[1] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      tests.push_back({"vmovshdup xmm0,xmm1", cat,
        {0xC5, 0xFA, 0x16, 0xC1}, s, FL_ALL, 0x1});
    }
    add_misalign_fault("movshdup xmm0,[rdi] misaligned", {0xF3, 0x0F, 0x16, 0x07});
    add_misalign_ok("lddqu xmm0,[rdi] misaligned", {0xF2, 0x0F, 0xF0, 0x07});
  }

  // =====================================================================
  // MMX↔SSE conversions: CVTPI2PS, CVTPS2PI, etc.
  // =====================================================================
  {
    cat = "SSE";

    // CVTPI2PS: NP 0F 2A /r — convert 2 packed dwords from MM to low 2 floats in XMM
    // Load MM0 with [3, 7] via MOVD+PUNPCKLDQ, then CVTPI2PS XMM0, MM0, EMMS
    // MOVD MM0, EAX (0F 6E C0) loads 3 into low dword
    // We just test a simple case: MM0 has {3, 0} after MOVD
    {
      ArchState s = {.rax = 3};
      s.xmm[0] = xmm_from_u64(0xDEADDEADDEADDEAD, 0xBBBBBBBBBBBBBBBB);
      tests.push_back({"cvtpi2ps xmm0,mm0", cat,
        {0x0F, 0x6E, 0xC0,        // MOVD MM0, EAX (MM0 = {0, 3})
         0x0F, 0x2A, 0xC0,        // CVTPI2PS XMM0, MM0
         0x0F, 0x77},             // EMMS
        s, FL_ALL, 0x1});
      // XMM0 low 64 = {f32(0), f32(3)}, high 64 = preserved (0xBBBB...)
    }

    // CVTPI2PD: 66 0F 2A /r — convert 2 packed dwords from MM to 2 doubles in XMM
    {
      ArchState s = {.rax = 5};
      tests.push_back({"cvtpi2pd xmm0,mm0", cat,
        {0x0F, 0x6E, 0xC0,        // MOVD MM0, EAX (MM0 = {0, 5})
         0x66, 0x0F, 0x2A, 0xC0,  // CVTPI2PD XMM0, MM0
         0x0F, 0x77},             // EMMS
        s, FL_ALL, 0x1});
    }

    // CVTPS2PI: NP 0F 2D /r — convert 2 floats from low XMM to 2 dwords in MM
    // Then MOVD EAX,MM0 to read result; compare via RAX
    {
      ArchState s = {};
      s.xmm[0] = xmm_from_u32(0x40400000, 0x40A00000, 0, 0); // 3.0f, 5.0f
      tests.push_back({"cvtps2pi mm0,xmm0; movd eax,mm0", cat,
        {0x0F, 0x2D, 0xC0,        // CVTPS2PI MM0, XMM0
         0x0F, 0x7E, 0xC0,        // MOVD EAX, MM0
         0x0F, 0x77},             // EMMS
        s, FL_ALL});
      // EAX should be 3 (low dword of MM0)
    }

    // CVTTPS2PI: NP 0F 2C /r — truncate 2 floats to 2 dwords in MM
    {
      ArchState s = {};
      s.xmm[0] = xmm_from_u32(0x40490FDB, 0x40C90FDB, 0, 0); // pi, 2*pi
      tests.push_back({"cvttps2pi mm0,xmm0; movd eax,mm0", cat,
        {0x0F, 0x2C, 0xC0,        // CVTTPS2PI MM0, XMM0
         0x0F, 0x7E, 0xC0,        // MOVD EAX, MM0
         0x0F, 0x77},             // EMMS
        s, FL_ALL});
      // EAX should be 3 (trunc(pi))
    }

    // CVTPD2PI: 66 0F 2D /r — round 2 doubles to 2 dwords in MM
    {
      ArchState s = {};
      s.xmm[0] = xmm_from_u64(0x4008000000000000, 0x4014000000000000); // 3.0, 5.0
      tests.push_back({"cvtpd2pi mm0,xmm0; movd eax,mm0", cat,
        {0x66, 0x0F, 0x2D, 0xC0,  // CVTPD2PI MM0, XMM0
         0x0F, 0x7E, 0xC0,        // MOVD EAX, MM0
         0x0F, 0x77},             // EMMS
        s, FL_ALL});
      // EAX should be 3 (low dword of MM0 = round(3.0))
    }

    // CVTTPD2PI: 66 0F 2C /r — truncate 2 doubles to 2 dwords in MM
    {
      ArchState s = {};
      s.xmm[0] = xmm_from_u64(0x400921FB54442D18, 0x4019000000000000); // pi, 6.25
      tests.push_back({"cvttpd2pi mm0,xmm0; movd eax,mm0", cat,
        {0x66, 0x0F, 0x2C, 0xC0,  // CVTTPD2PI MM0, XMM0
         0x0F, 0x7E, 0xC0,        // MOVD EAX, MM0
         0x0F, 0x77},             // EMMS
        s, FL_ALL});
      // EAX should be 3 (trunc(pi))
    }
  }

  // =====================================================================
  // VCVTPS2PH rounding control
  // =====================================================================
  {
    cat = "SSE";

    // VCVTPS2PH XMM0, XMM1, 0x03: VEX.128.66.0F3A.WIG 1D /r ib
    // C4 E3 79 1D C8 03: imm8=0x03 → truncation mode (imm8[2]=0, imm8[1:0]=11)
    // XMM1 = [1.6, 2.5, 3.7, 4.9] → truncated to [1.0, 2.0, 3.0, 4.0] as FP16
    {
      ArchState s = {};
      s.xmm[1] = xmm_from_u32(0x3FCCCCCD, 0x40200000, 0x406CCCCD, 0x409CCCCD);
      // C4 E3 79 1D C8 03: VEX.128.66.0F3A W=0 vvvv=1111, 1D, modrm=C8(reg=xmm1,rm=xmm0), imm=03
      tests.push_back({"vcvtps2ph xmm0,xmm1,trunc", cat,
        {0xC4, 0xE3, 0x79, 0x1D, 0xC8, 0x03}, s, FL_ALL, 0x1});
    }
    // VCVTPH2PS: VEX.128.66.0F38 13 — no alignment
    // C4 E2 79 13 07: 3-byte VEX, mm=2(0F38), pp=01(66), reg=0, [rdi]
    add_misalign_ok("vcvtph2ps xmm,[rdi] misaligned", {0xC4, 0xE2, 0x79, 0x13, 0x07});
    // VCVTPS2PH store: VEX.128.66.0F3A 1D — no alignment
    // C4 E3 79 1D 07 03: mm=3(0F3A), pp=01(66), reg=0, [rdi], imm=03
    add_misalign_ok_st("vcvtps2ph [rdi],xmm,trunc misaligned", {0xC4, 0xE3, 0x79, 0x1D, 0x07, 0x03}, 8);
  }

  // =====================================================================
  // PEXTRW SSE4.1 memory form (66 0F 3A 15)
  // =====================================================================
  {
    cat = "SSE";

    // PEXTRW [RDI], XMM0, 2: 66 0F 3A 15 07 02
    // Extract word at index 2 from XMM0, store to memory
    {
      ArchState s = {.rdi = DATA_ADDR};
      s.xmm[0] = xmm_from_u32(0x11112222, 0x33334444, 0x55556666, 0x77778888);
      tests.push_back({"pextrw [rdi],xmm0,2", cat,
        {0x66, 0x0F, 0x3A, 0x15, 0x07, 0x02}, s, FL_ALL, 0, false, {}, 2});
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
      ArchState s = {.rax = 0x1234567890ABCDEF};
      tests.push_back({"movd mm0,eax; movq2dq xmm0,mm0", cat,
        {0x0F, 0x6E, 0xC0,        // MOVD MM0, EAX (loads low 32 bits)
         0xF3, 0x0F, 0xD6, 0xC0,  // MOVQ2DQ XMM0, MM0
         0x0F, 0x77},             // EMMS
        s, FL_ALL, 0x1});
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
      ArchState s = {};
      s.xmm[1] = xmm_from_u32(1, 2, 3, 4);
      tests.push_back({"vcvtdq2ps xmm0,xmm1", cat,
        {0xC5, 0xF8, 0x5B, 0xC1}, s, FL_ALL, 0x1});
    }

    // VCVTPS2DQ xmm0, xmm1: VEX.128.66.0F.WIG 5B /r
    // C5 F9 5B C1: convert packed f32 to packed dword integers (MXCSR rounding)
    {
      ArchState s = {};
      s.xmm[1] = xmm_from_u32(0x3F800000, 0x40000000, 0x40400000, 0x40800000); // 1,2,3,4
      tests.push_back({"vcvtps2dq xmm0,xmm1", cat,
        {0xC5, 0xF9, 0x5B, 0xC1}, s, FL_ALL, 0x1});
    }

    // VCVTTPS2DQ xmm0, xmm1: VEX.128.F3.0F.WIG 5B /r
    // C5 FA 5B C1: convert packed f32 to packed dword integers (truncation)
    {
      ArchState s = {};
      s.xmm[1] = xmm_from_u32(0x40490FDB, 0x40C90FDB, 0x41200000, 0xC1200000); // pi,2pi,10,-10
      tests.push_back({"vcvttps2dq xmm0,xmm1", cat,
        {0xC5, 0xFA, 0x5B, 0xC1}, s, FL_ALL, 0x1});
    }

    // VCVTDQ2PS ymm0, ymm1: VEX.256.NP.0F.WIG 5B /r
    // C5 FC 5B C1: 256-bit convert packed dword integers to packed f32
    {
      ArchState s = {};
      s.xmm[1] = xmm_from_u32(1, 2, 3, 4);  // low 128
      // Need to set ymm1 upper half too — but test harness only sets xmm
      // Just test that the instruction doesn't fault
      tests.push_back({"vcvtdq2ps ymm0,ymm1 256", cat,
        {0xC5, 0xFC, 0x5B, 0xC1}, s, FL_ALL, 0x1});
    }
  }

  // =====================================================================
  // VCMPPS 5-bit predicates (predicates 8-15 test NaN-aware comparisons)
  // =====================================================================
  {
    cat = "SSE";

    auto add_xmm = [&](const std::string &name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
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
      ArchState s = {};
      s.xmm[1] = xmm_from_u32(ONE, 0, 0, 0);
      s.xmm[2] = xmm_from_u32(TWO, 0, 0, 0);
      add_xmm("vcmpps pred8 eq_uq ord", {0xC5, 0xF0, 0xC2, 0xC2, 0x08}, s, 0x1);
    }
    // 1.0 vs NaN → unordered → true (EQ_UQ returns true for unordered)
    {
      ArchState s = {};
      s.xmm[1] = xmm_from_u32(ONE, 0, 0, 0);
      s.xmm[2] = xmm_from_u32(QNAN, 0, 0, 0);
      add_xmm("vcmpps pred8 eq_uq nan", {0xC5, 0xF0, 0xC2, 0xC2, 0x08}, s, 0x1);
    }

    // pred 11: FALSE_OQ — always false
    {
      ArchState s = {};
      s.xmm[1] = xmm_from_u32(ONE, ONE, ONE, ONE);
      s.xmm[2] = xmm_from_u32(ONE, ONE, ONE, ONE);
      add_xmm("vcmpps pred11 false", {0xC5, 0xF0, 0xC2, 0xC2, 0x0B}, s, 0x1);
    }

    // pred 12: NEQ_OQ — not equal, ordered (false for NaN)
    {
      ArchState s = {};
      s.xmm[1] = xmm_from_u32(ONE, 0, 0, 0);
      s.xmm[2] = xmm_from_u32(QNAN, 0, 0, 0);
      add_xmm("vcmpps pred12 neq_oq nan", {0xC5, 0xF0, 0xC2, 0xC2, 0x0C}, s, 0x1);
    }

    // pred 15: TRUE_UQ — always true
    {
      ArchState s = {};
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
      {.rdi = DATA_ADDR},
      FL_ALL, 0x3, false, data, 0});

    // MOVAPS XMM0, [RDI+32]: legacy SSE aligned 128-bit load
    // Code: VMOVDQU YMM0,[RDI]      = C5 FE 6F 07
    //       MOVAPS XMM0,[RDI+0x20]  = 0F 28 47 20
    //       VEXTRACTI128 XMM1,YMM0,1= C4 E3 7D 39 C1 01
    // DATA_ADDR+32 = 0x11020, 0x11020 % 16 == 0 (aligned)
    tests.push_back({"movaps xmm,m preserves upper", cat,
      {0xC5, 0xFE, 0x6F, 0x07,
       0x0F, 0x28, 0x47, 0x20,
       0xC4, 0xE3, 0x7D, 0x39, 0xC1, 0x01},
      {.rdi = DATA_ADDR},
      FL_ALL, 0x3, false, data, 0});

    // MOVDQU XMM0, [RDI+32]: legacy SSE integer 128-bit load (F3 0F 6F)
    // Code: VMOVDQU YMM0,[RDI]       = C5 FE 6F 07
    //       MOVDQU XMM0,[RDI+0x20]   = F3 0F 6F 47 20
    //       VEXTRACTI128 XMM1,YMM0,1 = C4 E3 7D 39 C1 01
    tests.push_back({"movdqu xmm,m preserves upper", cat,
      {0xC5, 0xFE, 0x6F, 0x07,
       0xF3, 0x0F, 0x6F, 0x47, 0x20,
       0xC4, 0xE3, 0x7D, 0x39, 0xC1, 0x01},
      {.rdi = DATA_ADDR},
      FL_ALL, 0x3, false, data, 0});

    // MOVSS XMM0, [RDI+32]: legacy SSE scalar float load (F3 0F 10)
    // Code: VMOVDQU YMM0,[RDI]       = C5 FE 6F 07
    //       MOVSS XMM0,[RDI+0x20]    = F3 0F 10 47 20
    //       VEXTRACTI128 XMM1,YMM0,1 = C4 E3 7D 39 C1 01
    tests.push_back({"movss xmm,m preserves upper", cat,
      {0xC5, 0xFE, 0x6F, 0x07,
       0xF3, 0x0F, 0x10, 0x47, 0x20,
       0xC4, 0xE3, 0x7D, 0x39, 0xC1, 0x01},
      {.rdi = DATA_ADDR},
      FL_ALL, 0x3, false, data, 0});

    // MOVSD XMM0, [RDI+32]: legacy SSE scalar double load (F2 0F 10)
    // Code: VMOVDQU YMM0,[RDI]       = C5 FE 6F 07
    //       MOVSD XMM0,[RDI+0x20]    = F2 0F 10 47 20
    //       VEXTRACTI128 XMM1,YMM0,1 = C4 E3 7D 39 C1 01
    tests.push_back({"movsd xmm,m preserves upper", cat,
      {0xC5, 0xFE, 0x6F, 0x07,
       0xF2, 0x0F, 0x10, 0x47, 0x20,
       0xC4, 0xE3, 0x7D, 0x39, 0xC1, 0x01},
      {.rdi = DATA_ADDR},
      FL_ALL, 0x3, false, data, 0});

    // MOVUPD XMM0, [RDI+32]: legacy SSE 128-bit double load (66 0F 10)
    // Code: VMOVDQU YMM0,[RDI]       = C5 FE 6F 07
    //       MOVUPD XMM0,[RDI+0x20]   = 66 0F 10 47 20
    //       VEXTRACTI128 XMM1,YMM0,1 = C4 E3 7D 39 C1 01
    tests.push_back({"movupd xmm,m preserves upper", cat,
      {0xC5, 0xFE, 0x6F, 0x07,
       0x66, 0x0F, 0x10, 0x47, 0x20,
       0xC4, 0xE3, 0x7D, 0x39, 0xC1, 0x01},
      {.rdi = DATA_ADDR},
      FL_ALL, 0x3, false, data, 0});

    // MOVDDUP XMM0, [RDI+32]: legacy SSE double duplicate (F2 0F 12)
    // Code: VMOVDQU YMM0,[RDI]       = C5 FE 6F 07
    //       MOVDDUP XMM0,[RDI+0x20]  = F2 0F 12 47 20
    //       VEXTRACTI128 XMM1,YMM0,1 = C4 E3 7D 39 C1 01
    tests.push_back({"movddup xmm,m preserves upper", cat,
      {0xC5, 0xFE, 0x6F, 0x07,
       0xF2, 0x0F, 0x12, 0x47, 0x20,
       0xC4, 0xE3, 0x7D, 0x39, 0xC1, 0x01},
      {.rdi = DATA_ADDR},
      FL_ALL, 0x3, false, data, 0});
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
      s.xmm[0] = xmm_from_u64(0x0000000064636261, 0);  // "abcd\0..."
      s.xmm[1] = xmm_from_u64(0x0000000078627878, 0);  // "xxbx\0..."
      // 66 0F 3A 63 C1 00: PCMPISTRI XMM0, XMM1, 0x00
      add_xmm("pcmpistri eq_any", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x00}, s, 0);
    }
    // PCMPxSTRx do NOT require 16-byte alignment (SDM exception class 4)

    // PCMPISTRI: equal each (mode 0x08) -- byte-by-byte compare
    {
      ArchState s;
      s.xmm[0] = xmm_from_u64(0x00006F6C6C6568, 0);  // "hello\0..."
      s.xmm[1] = xmm_from_u64(0x00006F6C6C6568, 0);  // "hello\0..."
      add_xmm("pcmpistri eq_each match", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x08}, s, 0);
    }

    // PCMPISTRI: equal each with difference at byte 2
    {
      ArchState s;
      s.xmm[0] = xmm_from_u64(0x0000000044434241, 0);  // "ABCD\0..."
      s.xmm[1] = xmm_from_u64(0x0000000044584241, 0);  // "AB\x58D\0..."
      add_xmm("pcmpistri eq_each diff@2", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x08}, s, 0);
    }

    // PCMPISTRM: equal each (mode 0x08), returns mask in XMM0
    // 66 0F 3A 62 C1 08: PCMPISTRM XMM0, XMM1, 0x08
    {
      ArchState s;
      s.xmm[0] = xmm_from_u64(0x0000000044434241, 0);  // "ABCD\0..."
      s.xmm[1] = xmm_from_u64(0x00000000FF43FF41, 0);  // "A\xffC\xff\0..."
      add_xmm("pcmpistrm eq_each", {0x66, 0x0F, 0x3A, 0x62, 0xC1, 0x08}, s, 0x1);
    }

    // PCMPESTRI: explicit length -- 66 0F 3A 61 C1 imm8
    // EAX=length of xmm0 string, EDX=length of xmm1 string
    {
      ArchState s;
      s.rax = 3;  // length of needle
      s.rdx = 4;  // length of haystack
      s.xmm[0] = xmm_from_u64(0x0000000000434241, 0);  // "ABC\0..."
      s.xmm[1] = xmm_from_u64(0x0000000044434241, 0);  // "ABCD\0..."
      add_xmm("pcmpestri eq_each", {0x66, 0x0F, 0x3A, 0x61, 0xC1, 0x08}, s, 0);
    }

    // ---- Additional PCMPISTRI tests covering all aggregation modes ----

    // PCMPISTRI: ranges (mode 0x04) — check if chars in xmm1 fall in [A-Z] range
    // xmm0 = range pair "AZ" (0x41, 0x5A), xmm1 = "Hello" (mixed case)
    {
      ArchState s;
      s.xmm[0] = xmm_from_u64(0x000000000000005A41, 0);  // "AZ\0..."
      s.xmm[1] = xmm_from_u64(0x000000006F6C6C6548, 0);  // "Hello\0..."
      add_xmm("pcmpistri ranges", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x04}, s, 0);
    }

    // PCMPISTRI: equal ordered (mode 0x0C) — substring search
    // Search for "BC" in "ABCD"
    {
      ArchState s;
      s.xmm[0] = xmm_from_u64(0x0000000000004342, 0);  // "BC\0..."
      s.xmm[1] = xmm_from_u64(0x0000000044434241, 0);  // "ABCD\0..."
      add_xmm("pcmpistri eq_ord substr", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x0C}, s, 0);
    }

    // PCMPISTRI: equal ordered — no match
    {
      ArchState s;
      s.xmm[0] = xmm_from_u64(0x0000000000005958, 0);  // "XY\0..."
      s.xmm[1] = xmm_from_u64(0x0000000044434241, 0);  // "ABCD\0..."
      add_xmm("pcmpistri eq_ord nomatch", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x0C}, s, 0);
    }

    // PCMPISTRI: negative polarity (mode 0x18) — inverts result
    {
      ArchState s;
      s.xmm[0] = xmm_from_u64(0x0000000044434241, 0);  // "ABCD\0..."
      s.xmm[1] = xmm_from_u64(0x0000000044434241, 0);  // "ABCD\0..."
      // equal each + negative polarity: finds first non-matching byte
      add_xmm("pcmpistri neg_pol", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x18}, s, 0);
    }

    // PCMPISTRI: MSB index (imm8[6]=1, mode 0x48)
    {
      ArchState s;
      s.xmm[0] = xmm_from_u64(0x0000000064636261, 0);  // "abcd\0..."
      s.xmm[1] = xmm_from_u64(0x0000000078627878, 0);  // "xxbx\0..."
      add_xmm("pcmpistri eq_any MSB", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x40}, s, 0);
    }

    // PCMPISTRI: word mode (imm8[0]=1, mode 0x01) — unsigned words, equal any
    {
      ArchState s;
      s.xmm[0] = xmm_from_u64(0x0000000200000001, 0);  // words: 1, 2, 0, 0
      s.xmm[1] = xmm_from_u64(0x0003000100040002, 0);  // words: 2, 4, 1, 3
      add_xmm("pcmpistri word eq_any", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x01}, s, 0);
    }

    // PCMPISTRI: signed bytes, equal each (mode 0x0A)
    {
      ArchState s;
      s.xmm[0] = xmm_from_u64(0x00000000807F0102, 0);  // bytes: 2,1,127,-128,0...
      s.xmm[1] = xmm_from_u64(0x00000000807F0102, 0);  // same
      add_xmm("pcmpistri signed eq_each", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x0A}, s, 0);
    }

    // PCMPISTRI: full 16-byte strings (no nulls in first 16 bytes)
    {
      ArchState s;
      s.xmm[0] = xmm_from_u64(0x4847464544434241, 0x504F4E4D4C4B4A49);  // "ABCDEFGHIJKLMNOP"
      s.xmm[1] = xmm_from_u64(0x4847464544434241, 0x504F4E4D4C4B4A49);  // same
      add_xmm("pcmpistri full16 eq_each", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x08}, s, 0);
    }

    // PCMPISTRI: full 16-byte strings that differ at last byte
    {
      ArchState s;
      s.xmm[0] = xmm_from_u64(0x4847464544434241, 0x504F4E4D4C4B4A49);  // "ABCDEFGHIJKLMNOP"
      s.xmm[1] = xmm_from_u64(0x4847464544434241, 0x5A4F4E4D4C4B4A49);  // "ABCDEFGHIJKLMNOZ"
      add_xmm("pcmpistri full16 diff@15", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x08}, s, 0);
    }

    // ---- Additional PCMPISTRM tests ----

    // PCMPISTRM: equal any, byte-expand mask (imm8[6]=1, mode 0x40)
    {
      ArchState s;
      s.xmm[0] = xmm_from_u64(0x0000000064636261, 0);  // "abcd\0..."
      s.xmm[1] = xmm_from_u64(0x0000000078627878, 0);  // "xxbx\0..."
      // equal any, byte-expand: each matching byte → 0xFF in XMM0
      add_xmm("pcmpistrm eq_any expand", {0x66, 0x0F, 0x3A, 0x62, 0xC1, 0x40}, s, 0x1);
    }

    // PCMPISTRM: equal each, bitmask (mode 0x08)
    {
      ArchState s;
      s.xmm[0] = xmm_from_u64(0x4847464544434241, 0x504F4E4D4C4B4A49);
      s.xmm[1] = xmm_from_u64(0x4847464544434241, 0x5A4F4E4D4C4B4A49);
      add_xmm("pcmpistrm eq_each full16", {0x66, 0x0F, 0x3A, 0x62, 0xC1, 0x08}, s, 0x1);
    }

    // PCMPISTRM: ranges, bitmask (mode 0x04)
    {
      ArchState s;
      s.xmm[0] = xmm_from_u64(0x000000000000007A61, 0);  // "az\0..." (lowercase range)
      s.xmm[1] = xmm_from_u64(0x000000006F6C6C6548, 0);  // "Hello\0..."
      add_xmm("pcmpistrm ranges", {0x66, 0x0F, 0x3A, 0x62, 0xC1, 0x04}, s, 0x1);
    }

    // ---- Additional PCMPESTRI tests ----

    // PCMPESTRI: equal any with explicit lengths
    {
      ArchState s;
      s.rax = 4;  // length of charset
      s.rdx = 5;  // length of string
      s.xmm[0] = xmm_from_u64(0x00000000666F6F62, 0);  // "boof\0..." (chars to search for)
      s.xmm[1] = xmm_from_u64(0x000000006F6C6C6568, 0);  // "hello\0..."
      add_xmm("pcmpestri eq_any explicit", {0x66, 0x0F, 0x3A, 0x61, 0xC1, 0x00}, s, 0);
    }

    // PCMPESTRI: negative length (treated as unsigned, saturated to 16)
    {
      ArchState s;
      s.rax = -1LL;  // abs(-1) = 1? No, SDM says abs value, saturated to 16
      s.rdx = 4;
      s.xmm[0] = xmm_from_u64(0x0000000044434241, 0);
      s.xmm[1] = xmm_from_u64(0x0000000044434241, 0);
      add_xmm("pcmpestri neg_len", {0x66, 0x0F, 0x3A, 0x61, 0xC1, 0x08}, s, 0);
    }

    // PCMPESTRM: equal each with explicit lengths
    {
      ArchState s;
      s.rax = 3;
      s.rdx = 3;
      s.xmm[0] = xmm_from_u64(0xFF00FF00FF434241, 0);  // "ABC" + garbage
      s.xmm[1] = xmm_from_u64(0xFF00FF00FF434241, 0);  // "ABC" + garbage
      // Only first 3 bytes should matter
      add_xmm("pcmpestrm eq_each len=3", {0x66, 0x0F, 0x3A, 0x60, 0xC1, 0x08}, s, 0x1);
    }

    // PCMPESTRM: zero-length operands
    {
      ArchState s;
      s.rax = 0;
      s.rdx = 0;
      s.xmm[0] = xmm_from_u64(0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF);
      s.xmm[1] = xmm_from_u64(0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF);
      add_xmm("pcmpestrm zero_len", {0x66, 0x0F, 0x3A, 0x60, 0xC1, 0x08}, s, 0x1);
    }

    // ---- PCLMULQDQ tests ----

    // PCLMULQDQ XMM0, XMM1, imm8: 66 0F 3A 44 C1 imm8
    {
      ArchState s;

      // Simple: 1 × 1 = 1
      s.xmm[0] = xmm_from_u64(0x0000000000000001, 0x0000000000000001);
      s.xmm[1] = xmm_from_u64(0x0000000000000001, 0x0000000000000001);
      add_xmm("pclmulqdq 1x1 00", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x00}, s, 0x3);

      // 3 × 3 = 5 (polynomial: (x+1)*(x+1) = x^2+1 = 0b101)
      s.xmm[0] = xmm_from_u64(0x0000000000000003, 0x0000000000000003);
      s.xmm[1] = xmm_from_u64(0x0000000000000003, 0x0000000000000003);
      add_xmm("pclmulqdq 3x3 00", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x00}, s, 0x3);

      // 7 × 7 = 0x15 (x^2+x+1)^2 = x^4+x^2+1 = 0b10101
      s.xmm[0] = xmm_from_u64(0x0000000000000007, 0x0000000000000007);
      s.xmm[1] = xmm_from_u64(0x0000000000000007, 0x0000000000000007);
      add_xmm("pclmulqdq 7x7 00", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x00}, s, 0x3);

      // Test all 4 imm8 selector combinations
      s.xmm[0] = xmm_from_u64(0x123456789ABCDEF0, 0xFEDCBA9876543210);
      s.xmm[1] = xmm_from_u64(0x0F0F0F0F0F0F0F0F, 0xF0F0F0F0F0F0F0F0);
      add_xmm("pclmulqdq sel 00", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x00}, s, 0x3);
      add_xmm("pclmulqdq sel 01", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x01}, s, 0x3);
      add_xmm("pclmulqdq sel 10", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x10}, s, 0x3);
      add_xmm("pclmulqdq sel 11", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x11}, s, 0x3);

      // Edge: multiply by zero
      s.xmm[0] = xmm_from_u64(0x0000000000000000, 0);
      s.xmm[1] = xmm_from_u64(0xFFFFFFFFFFFFFFFF, 0);
      add_xmm("pclmulqdq 0xall", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x00}, s, 0x3);

      // Edge: all-ones × all-ones
      s.xmm[0] = xmm_from_u64(0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF);
      s.xmm[1] = xmm_from_u64(0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF);
      add_xmm("pclmulqdq FxF 00", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x00}, s, 0x3);
      add_xmm("pclmulqdq FxF 11", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x11}, s, 0x3);
      add_misalign_fault("pclmulqdq xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0x3A, 0x44, 0x07, 0x00}, {0});

      // GFNI: GF2P8MULB (66 0F 38 CF, align=16)
      add_misalign_fault("gf2p8mulb xmm0,[rdi] misaligned", {0x66, 0x0F, 0x38, 0xCF, 0x07}, {0});
      // GF2P8AFFINEQB (66 0F 3A CE, align=16)
      add_misalign_fault("gf2p8affineqb xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0x3A, 0xCE, 0x07, 0x00}, {0});
      // GF2P8AFFINEINVQB (66 0F 3A CF, align=16)
      add_misalign_fault("gf2p8affineinvqb xmm0,[rdi],0 misaligned", {0x66, 0x0F, 0x3A, 0xCF, 0x07, 0x00}, {0});

      // MSB set: 0x8000000000000000 × 0x8000000000000000
      s.xmm[0] = xmm_from_u64(0x8000000000000000, 0);
      s.xmm[1] = xmm_from_u64(0x8000000000000000, 0);
      add_xmm("pclmulqdq MSB", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x00}, s, 0x3);
    }

    // ---- MASKMOVDQU test ----
    // MASKMOVDQU xmm0, xmm1: 66 0F F7 C1 (stores to [RDI])
    {
      ArchState s;
      s.rdi = DATA_ADDR;
      // src data in xmm0
      s.xmm[0] = xmm_from_u64(0x1111111111111111, 0x2222222222222222);
      // mask in xmm1: high bit of each byte controls write
      // 0x80 = write, 0x00 = no write
      s.xmm[1] = xmm_from_u64(0x8000800080008000, 0x0080008000800080);

      // Pre-fill data area with 0xCC pattern
      std::vector<u8> data(16, 0xCC);
      tests.push_back({"maskmovdqu partial",
        cat, {0x66, 0x0F, 0xF7, 0xC1}, s, FL_ALL, 0x0, false, data, 16});

      // All mask bits set — full write
      s.xmm[1] = xmm_from_u64(0x8080808080808080, 0x8080808080808080);
      tests.push_back({"maskmovdqu full",
        cat, {0x66, 0x0F, 0xF7, 0xC1}, s, FL_ALL, 0x0, false, data, 16});

      // No mask bits set — no write at all
      s.xmm[1] = xmm_from_u64(0x0000000000000000, 0x0000000000000000);
      tests.push_back({"maskmovdqu none",
        cat, {0x66, 0x0F, 0xF7, 0xC1}, s, FL_ALL, 0x0, false, data, 16});

      // MASKMOVDQU misaligned — no alignment required (DS:RDI)
      {
        ArchState ms = {};
        ms.rdi = DATA_ADDR + 1;
        ms.rflags = initial_flags();
        ms.xmm[0] = xmm_from_u64(0x1111111111111111, 0x2222222222222222);
        ms.xmm[1] = xmm_from_u64(0x8080808080808080, 0x8080808080808080);
        tests.push_back({"maskmovdqu misaligned",
          cat, {0x66, 0x0F, 0xF7, 0xC1}, ms, FL_ALL, 0x0, false, align_data, 16});
      }
    }
  }
}

#include "kvm-harness.h"

void add_x87_avx_tests(std::vector<TestCase> &tests) {
  std::string cat;

  auto add = [&](const std::string &name, std::vector<u8> code, ArchState init,
                 u64 mask = FL_ALL) {
    tests.push_back({name, cat, std::move(code), init, mask});
  };

  auto add_mem = [&](const std::string &name, std::vector<u8> code, ArchState init,
                     u64 mask, std::vector<u8> data, size_t cmp_len) {
    tests.push_back({name, cat, std::move(code), init, mask, 0, false, std::move(data), cmp_len});
  };

  auto add_xmm = [&](const std::string &name, std::vector<u8> code, ArchState init,
                      u32 xmm_cmp) {
    tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
  };

  // =====================================================================
  cat = "x87";
  {
    // FLDZ + FSTP m64fp: push 0.0 then store to [RDI]
    // D9 EE (FLDZ) + DD 1F (FSTP m64fp [RDI])
    ArchState s;
    s.rdi = DATA_ADDR;
    tests.push_back({"fldz; fstp [rdi]", cat, {0xD9, 0xEE, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FLD1 + FSTP m64fp: push 1.0 then store
    // D9 E8 (FLD1) + DD 1F (FSTP m64fp [RDI])
    tests.push_back({"fld1; fstp [rdi]", cat, {0xD9, 0xE8, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FLDPI + FSTP m64fp: push pi then store
    // D9 EB (FLDPI) + DD 1F (FSTP m64fp [RDI])
    tests.push_back({"fldpi; fstp [rdi]", cat, {0xD9, 0xEB, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FLDL2E + FSTP m64fp: push log2(e) then store
    // D9 EA (FLDL2E) + DD 1F (FSTP m64fp)
    tests.push_back({"fldl2e; fstp [rdi]", cat, {0xD9, 0xEA, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FLDLN2 + FSTP m64fp: push ln(2) then store
    // D9 ED (FLDLN2) + DD 1F
    tests.push_back({"fldln2; fstp [rdi]", cat, {0xD9, 0xED, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FILD m32int + FISTP m32int: load int, store int back
    // DB 07 (FILD m32 [RDI]) + DB 1F (FISTP m32 [RDI])
    u8 int_val[] = {42, 0, 0, 0};
    tests.push_back({"fild [rdi]; fistp [rdi]", cat,
                      {0xDB, 0x07, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {int_val, int_val + 4}, 4});

    // FADD: FILD 10 + FILD 32 + FADDP + FISTP → 42
    // Load 10 at [RDI], 32 at [RDI+4]
    u8 add_data[] = {10, 0, 0, 0, 32, 0, 0, 0};
    // FILD [RDI] (DB 07) + FILD [RDI+4] (DB 47 04) + FADDP (DE C1) + FISTP [RDI] (DB 1F)
    tests.push_back({"fild+fild+faddp+fistp", cat,
                      {0xDB, 0x07, 0xDB, 0x47, 0x04, 0xDE, 0xC1, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {add_data, add_data + 8}, 4});

    // FSUB: FILD 42 + FILD 10 + FSUBRP + FISTP → 32
    // FILD [RDI] (DB 07) + FILD [RDI+4] (DB 47 04) + FSUBRP (DE E1) + FISTP [RDI] (DB 1F)
    u8 sub_data[] = {42, 0, 0, 0, 10, 0, 0, 0};
    tests.push_back({"fild+fild+fsubrp+fistp", cat,
                      {0xDB, 0x07, 0xDB, 0x47, 0x04, 0xDE, 0xE1, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {sub_data, sub_data + 8}, 4});

    // FMUL: FILD 6 + FILD 7 + FMULP + FISTP → 42
    u8 mul_data[] = {6, 0, 0, 0, 7, 0, 0, 0};
    // FILD [RDI] (DB 07) + FILD [RDI+4] (DB 47 04) + FMULP (DE C9) + FISTP [RDI] (DB 1F)
    tests.push_back({"fild+fild+fmulp+fistp", cat,
                      {0xDB, 0x07, 0xDB, 0x47, 0x04, 0xDE, 0xC9, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {mul_data, mul_data + 8}, 4});

    // FCHS: FILD 42 + FCHS + FISTP → -42
    u8 chs_data[] = {42, 0, 0, 0};
    // FILD [RDI] (DB 07) + FCHS (D9 E0) + FISTP [RDI] (DB 1F)
    tests.push_back({"fild+fchs+fistp", cat,
                      {0xDB, 0x07, 0xD9, 0xE0, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {chs_data, chs_data + 4}, 4});

    // FABS: FILD -5 + FABS + FISTP → 5
    u8 abs_data[] = {0xFB, 0xFF, 0xFF, 0xFF};  // -5 as int32
    // FILD [RDI] (DB 07) + FABS (D9 E1) + FISTP [RDI] (DB 1F)
    tests.push_back({"fild+fabs+fistp", cat,
                      {0xDB, 0x07, 0xD9, 0xE1, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {abs_data, abs_data + 4}, 4});

    // FXCH: FLD1 + FLDZ + FXCH + FSTP m64fp → should store 1.0 (was on top after FXCH)
    // D9 E8 (FLD1) + D9 EE (FLDZ) + D9 C9 (FXCH ST(1)) + DD 1F (FSTP [RDI])
    tests.push_back({"fld1+fldz+fxch+fstp", cat,
                      {0xD9, 0xE8, 0xD9, 0xEE, 0xD9, 0xC9, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FSTCW/FLDCW: store control word, load it back
    // D9 3F (FSTCW [RDI]) — stores the FPU control word
    tests.push_back({"fstcw [rdi]", cat, {0xD9, 0x3F},
                      s, FL_ALL, 0, false, {}, 2});

    // FINIT + FSTSW AX: initialize FPU, store status word to AX
    // DB E3 (FNINIT) + DF E0 (FNSTSW AX)
    tests.push_back({"finit+fstsw ax", cat, {0xDB, 0xE3, 0xDF, 0xE0},
                      with_gpr_inputs(s, {}), FL_ALL, 0, false, {}, 0});

    // FUCOMI: compare ST(0) with ST(1), set EFLAGS
    // FLD1 + FLDZ + DB E9 (FUCOMI ST,ST(1)) — compares 0.0 vs 1.0
    tests.push_back({"fld1+fldz+fucomi", cat,
                      {0xD9, 0xE8, 0xD9, 0xEE, 0xDB, 0xE9},
                      with_gpr_inputs(s, {}), FL_ALL, 0, false, {}, 0});
  }

  // =====================================================================
  // 44. ENTER
  // =====================================================================
  cat = "ENTER";
  {
    ArchState s = {.rbp = 0x1F000, .rsp = 0x20000};

    // ENTER 0x10, 0: C8 10 00 00 (allocate 16 bytes, nesting=0)
    // Then LEAVE to restore: C9
    add("enter 0x10,0; leave", {0xC8, 0x10, 0x00, 0x00, 0xC9}, s, FL_ALL);

    // ENTER 0x00, 0: C8 00 00 00 (allocate 0 bytes, nesting=0)
    add("enter 0x00,0; leave", {0xC8, 0x00, 0x00, 0x00, 0xC9}, s, FL_ALL);
  }

  // =====================================================================
  // 45. More x87 — transcendental/rounding ops
  // =====================================================================
  cat = "x87";
  {
    ArchState s;
    s.rdi = DATA_ADDR;

    // FSQRT: FLD1 + FLD1 + FADDP (=2.0) + FSQRT + FSTP
    // D9 E8 (FLD1) + D9 E8 (FLD1) + DE C1 (FADDP) + D9 FA (FSQRT) + DD 1F (FSTP [RDI])
    tests.push_back({"fld1+fld1+faddp+fsqrt+fstp", cat,
                      {0xD9, 0xE8, 0xD9, 0xE8, 0xDE, 0xC1, 0xD9, 0xFA, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FRNDINT: FLD constant + FRNDINT + FISTP
    // Load 3.7 via FILD 37 / FILD 10 / FDIVP
    u8 rnd_data[] = {37, 0, 0, 0, 10, 0, 0, 0};
    // FILD [RDI] (DB 07) + FILD [RDI+4] (DB 47 04) + DE F9 (FDIVRP) + D9 FC (FRNDINT) + DB 1F (FISTP [RDI])
    tests.push_back({"fild 37/fild 10/fdivrp/frndint/fistp", cat,
                      {0xDB, 0x07, 0xDB, 0x47, 0x04, 0xDE, 0xF9, 0xD9, 0xFC, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {rnd_data, rnd_data + 8}, 4});

    // FSIN: FLD PI/2 ≈ push PI, divide by FILD 2
    // Rather than complex setup, just test FLDZ + FSIN + FSTP (sin(0)=0)
    // D9 EE (FLDZ) + D9 FE (FSIN) + DD 1F (FSTP [RDI])
    tests.push_back({"fldz+fsin+fstp", cat,
                      {0xD9, 0xEE, 0xD9, 0xFE, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FCOS: cos(0)=1
    // D9 EE (FLDZ) + D9 FF (FCOS) + DD 1F (FSTP [RDI])
    tests.push_back({"fldz+fcos+fstp", cat,
                      {0xD9, 0xEE, 0xD9, 0xFF, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FLD m64fp + FSTP m64fp: load double, store back
    // DD 07 (FLD m64fp [RDI]) + DD 1F (FSTP m64fp [RDI])
    u8 dbl_val[8];
    double dv = 3.14159;
    memcpy(dbl_val, &dv, 8);
    tests.push_back({"fld m64; fstp m64", cat,
                      {0xDD, 0x07, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {dbl_val, dbl_val + 8}, 8});

    // FLD m32fp + FSTP m32fp: load float, store back
    // D9 07 (FLD m32fp [RDI]) + D9 1F (FSTP m32fp [RDI])
    u8 flt_val[4];
    float fv = 2.71828f;
    memcpy(flt_val, &fv, 4);
    tests.push_back({"fld m32; fstp m32", cat,
                      {0xD9, 0x07, 0xD9, 0x1F},
                      s, FL_ALL, 0, false, {flt_val, flt_val + 4}, 4});

    // FIST m16: FILD 100 + FIST m16 [RDI]
    u8 i100[] = {100, 0, 0, 0};
    // DB 07 (FILD m32 [RDI]) + DF 17 (FIST m16 [RDI])
    tests.push_back({"fild+fist m16", cat,
                      {0xDB, 0x07, 0xDF, 0x17},
                      s, FL_ALL, 0, false, {i100, i100 + 4}, 2});

    // FISTP m64: FILD 12345 + FISTP m64 [RDI]
    u8 i12345[] = {0x39, 0x30, 0, 0};  // 12345
    // DB 07 (FILD m32 [RDI]) + DF 3F (FISTP m64 [RDI])
    tests.push_back({"fild+fistp m64", cat,
                      {0xDB, 0x07, 0xDF, 0x3F},
                      s, FL_ALL, 0, false, {i12345, i12345 + 4}, 8});

    // FILD m64int + FISTP m64int
    u8 i64_val[] = {0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
    // DF 2F (FILD m64 [RDI]) + DF 3F (FISTP m64 [RDI])
    tests.push_back({"fild m64; fistp m64", cat,
                      {0xDF, 0x2F, 0xDF, 0x3F},
                      s, FL_ALL, 0, false, {i64_val, i64_val + 8}, 8});

    // FILD m16int + FISTP m32int
    u8 i16_val[] = {0x0A, 0x00};  // 10
    // DF 07 (FILD m16 [RDI]) + DB 1F (FISTP m32 [RDI])
    tests.push_back({"fild m16; fistp m32", cat,
                      {0xDF, 0x07, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {i16_val, i16_val + 2}, 4});

    // FUCOMIP: compare and set EFLAGS, pop
    // FLD1 + FLDZ + DF E9 (FUCOMIP ST, ST(1)) — compares 0.0 vs 1.0
    tests.push_back({"fld1+fldz+fucomip", cat,
                      {0xD9, 0xE8, 0xD9, 0xEE, 0xDF, 0xE9},
                      with_gpr_inputs(s, {}), FL_ALL, 0, false, {}, 0});
  }

  // =====================================================================
  // 46. CMPXCHG16B
  // =====================================================================
  cat = "CMPXCHG16B";
  {
    // CMPXCHG16B [RDI]: REX.W 0F C7 0F (mod=00, reg=1, rm=rdi)
    // Compare RDX:RAX with m128. If equal, set ZF and store RCX:RBX.

    // Case 1: match
    ArchState s;
    s.rdi = DATA_ADDR;  // DATA_ADDR is 0x11000, 4K-aligned
    s.rax = 0x44332211AABBCCDD;
    s.rdx = 0x88776655EEFF0011;
    s.rbx = 0xDDCCBBAA11223344;
    s.rcx = 0x1122334455667788;
    s.rflags = initial_flags();
    u8 val[] = {0xDD, 0xCC, 0xBB, 0xAA, 0x11, 0x22, 0x33, 0x44,
                0x11, 0x00, 0xFF, 0xEE, 0x55, 0x66, 0x77, 0x88};
    add_mem("cmpxchg16b match", {0x48, 0x0F, 0xC7, 0x0F}, s, FL_ALL,
            {val, val + 16}, 16);

    // Case 2: no match
    s.rax = 0x0000000000000000;
    s.rdx = 0x0000000000000000;
    add_mem("cmpxchg16b no match", {0x48, 0x0F, 0xC7, 0x0F}, s, FL_ALL,
            {val, val + 16}, 16);
  }

  // =====================================================================
  // 47. AVX (VEX-encoded 128-bit) — packed/scalar FP and integer
  //
  // VEX 2-byte encoding: C5 [R̄.vvvv.L.pp] opcode ModRM
  //   R̄=1 for xmm0-7, vvvv = ~src1 (inverted), L=0 for 128-bit
  //   pp: 00=NP, 01=66, 10=F3, 11=F2
  //
  // Example: VADDPS xmm0, xmm1, xmm2 → C5 F0 58 C2
  //   R̄=1, vvvv=~1=1110=0xE, L=0, pp=00 → byte = 0xF0
  //   opcode=0x58, ModRM=0xC2 (mod=11, reg=0, rm=2)
  // =====================================================================
  cat = "AVX";
  {
    ArchState s;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // VEX 2-byte: C5 [R̄.vvvv.L.pp]
    // For xmm0 = xmm1 op xmm2: vvvv=~1=0xE, L=0, pp=00 → 0xF0
    // ModRM: mod=11, reg=xmm0=0, rm=xmm2=2 → 0xC2

    // VADDPS xmm0, xmm1, xmm2: C5 F0 58 C2
    add_xmm("vaddps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x58, 0xC2}, s, 0x7);
    // VSUBPS xmm0, xmm1, xmm2: C5 F0 5C C2
    add_xmm("vsubps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x5C, 0xC2}, s, 0x7);
    // VMULPS xmm0, xmm1, xmm2: C5 F0 59 C2
    add_xmm("vmulps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x59, 0xC2}, s, 0x7);
    // VDIVPS xmm0, xmm1, xmm2: C5 F0 5E C2
    add_xmm("vdivps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x5E, 0xC2}, s, 0x7);
    // VMINPS xmm0, xmm1, xmm2: C5 F0 5D C2
    add_xmm("vminps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x5D, 0xC2}, s, 0x7);
    // VMAXPS xmm0, xmm1, xmm2: C5 F0 5F C2
    add_xmm("vmaxps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x5F, 0xC2}, s, 0x7);

    // VSQRTPS xmm0, xmm1: C5 F8 51 C1  (vvvv=1111=unused, pp=00)
    add_xmm("vsqrtps xmm0,xmm1", {0xC5, 0xF8, 0x51, 0xC1}, with_vector_inputs(s, 0x2), 0x3);

    // VANDPS xmm0, xmm1, xmm2: C5 F0 54 C2
    add_xmm("vandps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x54, 0xC2}, s, 0x7);
    // VANDNPS xmm0, xmm1, xmm2: C5 F0 55 C2
    add_xmm("vandnps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x55, 0xC2}, s, 0x7);
    // VORPS xmm0, xmm1, xmm2: C5 F0 56 C2
    add_xmm("vorps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x56, 0xC2}, s, 0x7);
    // VXORPS xmm0, xmm1, xmm2: C5 F0 57 C2
    add_xmm("vxorps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x57, 0xC2}, s, 0x7);

    // VSHUFPS xmm0, xmm1, xmm2, 0x1B: C5 F0 C6 C2 1B
    add_xmm("vshufps xmm0,xmm1,xmm2,0x1B", {0xC5, 0xF0, 0xC6, 0xC2, 0x1B}, s, 0x7);

    // VUNPCKLPS xmm0, xmm1, xmm2: C5 F0 14 C2
    add_xmm("vunpcklps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x14, 0xC2}, s, 0x7);
    // VUNPCKHPS xmm0, xmm1, xmm2: C5 F0 15 C2
    add_xmm("vunpckhps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x15, 0xC2}, s, 0x7);
  }

  // AVX packed double
  {
    ArchState s;
    s.xmm[1] = xmm_from_f64(1.5, 2.5);
    s.xmm[2] = xmm_from_f64(3.0, 4.0);

    // pp=01 (66 prefix): vvvv=~1=0xE, L=0, pp=01 → 0xF1
    // VADDPD xmm0, xmm1, xmm2: C5 F1 58 C2
    add_xmm("vaddpd xmm0,xmm1,xmm2", {0xC5, 0xF1, 0x58, 0xC2}, s, 0x7);
    // VSUBPD xmm0, xmm1, xmm2: C5 F1 5C C2
    add_xmm("vsubpd xmm0,xmm1,xmm2", {0xC5, 0xF1, 0x5C, 0xC2}, s, 0x7);
    // VMULPD xmm0, xmm1, xmm2: C5 F1 59 C2
    add_xmm("vmulpd xmm0,xmm1,xmm2", {0xC5, 0xF1, 0x59, 0xC2}, s, 0x7);
    // VDIVPD xmm0, xmm1, xmm2: C5 F1 5E C2
    add_xmm("vdivpd xmm0,xmm1,xmm2", {0xC5, 0xF1, 0x5E, 0xC2}, s, 0x7);

    // VANDPD xmm0, xmm1, xmm2: C5 F1 54 C2
    add_xmm("vandpd xmm0,xmm1,xmm2", {0xC5, 0xF1, 0x54, 0xC2}, s, 0x7);
    // VXORPD xmm0, xmm1, xmm2: C5 F1 57 C2
    add_xmm("vxorpd xmm0,xmm1,xmm2", {0xC5, 0xF1, 0x57, 0xC2}, s, 0x7);

    // VSHUFPD xmm0, xmm1, xmm2, 0x01: C5 F1 C6 C2 01
    add_xmm("vshufpd xmm0,xmm1,xmm2,0x01", {0xC5, 0xF1, 0xC6, 0xC2, 0x01}, s, 0x7);

    // VUNPCKLPD xmm0, xmm1, xmm2: C5 F1 14 C2
    add_xmm("vunpcklpd xmm0,xmm1,xmm2", {0xC5, 0xF1, 0x14, 0xC2}, s, 0x7);
    // VUNPCKHPD xmm0, xmm1, xmm2: C5 F1 15 C2
    add_xmm("vunpckhpd xmm0,xmm1,xmm2", {0xC5, 0xF1, 0x15, 0xC2}, s, 0x7);
  }

  // AVX scalar
  {
    ArchState s;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);

    // pp=10 (F3 prefix): vvvv=~1=0xE, L=0, pp=10 → 0xF2
    // VADDSS xmm0, xmm1, xmm2: C5 F2 58 C2
    add_xmm("vaddss xmm0,xmm1,xmm2", {0xC5, 0xF2, 0x58, 0xC2}, s, 0x7);
    // VSUBSS xmm0, xmm1, xmm2: C5 F2 5C C2
    add_xmm("vsubss xmm0,xmm1,xmm2", {0xC5, 0xF2, 0x5C, 0xC2}, s, 0x7);
    // VMULSS xmm0, xmm1, xmm2: C5 F2 59 C2
    add_xmm("vmulss xmm0,xmm1,xmm2", {0xC5, 0xF2, 0x59, 0xC2}, s, 0x7);
    // VDIVSS xmm0, xmm1, xmm2: C5 F2 5E C2
    add_xmm("vdivss xmm0,xmm1,xmm2", {0xC5, 0xF2, 0x5E, 0xC2}, s, 0x7);

    // pp=11 (F2 prefix): vvvv=~1=0xE, L=0, pp=11 → 0xF3
    s.xmm[1] = xmm_from_f64(1.5, 2.5);
    s.xmm[2] = xmm_from_f64(3.0, 4.0);
    // VADDSD xmm0, xmm1, xmm2: C5 F3 58 C2
    add_xmm("vaddsd xmm0,xmm1,xmm2", {0xC5, 0xF3, 0x58, 0xC2}, s, 0x7);
    // VSUBSD xmm0, xmm1, xmm2: C5 F3 5C C2
    add_xmm("vsubsd xmm0,xmm1,xmm2", {0xC5, 0xF3, 0x5C, 0xC2}, s, 0x7);
    // VMULSD xmm0, xmm1, xmm2: C5 F3 59 C2
    add_xmm("vmulsd xmm0,xmm1,xmm2", {0xC5, 0xF3, 0x59, 0xC2}, s, 0x7);
    // VDIVSD xmm0, xmm1, xmm2: C5 F3 5E C2
    add_xmm("vdivsd xmm0,xmm1,xmm2", {0xC5, 0xF3, 0x5E, 0xC2}, s, 0x7);
  }

  // AVX data movement
  {
    ArchState s;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);

    // VMOVAPS xmm0, xmm1: C5 F8 28 C1  (vvvv=1111, pp=00)
    add_xmm("vmovaps xmm0,xmm1", {0xC5, 0xF8, 0x28, 0xC1}, s, 0x3);
    // VMOVUPS xmm0, xmm1: C5 F8 10 C1
    add_xmm("vmovups xmm0,xmm1", {0xC5, 0xF8, 0x10, 0xC1}, s, 0x3);
    // VMOVAPD xmm0, xmm1: C5 F9 28 C1  (pp=01)
    add_xmm("vmovapd xmm0,xmm1", {0xC5, 0xF9, 0x28, 0xC1}, s, 0x3);
    // VMOVDQA xmm0, xmm1: C5 F9 6F C1  (pp=01)
    add_xmm("vmovdqa xmm0,xmm1", {0xC5, 0xF9, 0x6F, 0xC1}, s, 0x3);
    // VMOVDQU xmm0, xmm1: C5 FA 6F C1  (pp=10)
    add_xmm("vmovdqu xmm0,xmm1", {0xC5, 0xFA, 0x6F, 0xC1}, s, 0x3);
  }

  // AVX packed integer
  {
    ArchState s;
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // pp=01 (66), vvvv=~1=0xE, L=0 → 0xF1
    // VPADDB xmm0, xmm1, xmm2: C5 F1 FC C2
    add_xmm("vpaddb xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xFC, 0xC2}, s, 0x7);
    // VPADDW xmm0, xmm1, xmm2: C5 F1 FD C2
    add_xmm("vpaddw xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xFD, 0xC2}, s, 0x7);
    // VPADDD xmm0, xmm1, xmm2: C5 F1 FE C2
    add_xmm("vpaddd xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xFE, 0xC2}, s, 0x7);
    // VPADDQ xmm0, xmm1, xmm2: C5 F1 D4 C2
    add_xmm("vpaddq xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xD4, 0xC2}, s, 0x7);
    // VPSUBB xmm0, xmm1, xmm2: C5 F1 F8 C2
    add_xmm("vpsubb xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xF8, 0xC2}, s, 0x7);

    // VPAND xmm0, xmm1, xmm2: C5 F1 DB C2
    add_xmm("vpand xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xDB, 0xC2}, s, 0x7);
    // VPOR xmm0, xmm1, xmm2: C5 F1 EB C2
    add_xmm("vpor xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xEB, 0xC2}, s, 0x7);
    // VPXOR xmm0, xmm1, xmm2: C5 F1 EF C2
    add_xmm("vpxor xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xEF, 0xC2}, s, 0x7);
    // VPANDN xmm0, xmm1, xmm2: C5 F1 DF C2
    add_xmm("vpandn xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xDF, 0xC2}, s, 0x7);
  }

  // AVX VCMPPS/VCMPPD
  {
    ArchState s;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 3.0f, 2.0f, 4.0f);

    // VCMPPS xmm0, xmm1, xmm2, 0 (EQ): C5 F0 C2 C2 00
    add_xmm("vcmpps eq", {0xC5, 0xF0, 0xC2, 0xC2, 0x00}, s, 0x7);
    // VCMPPS xmm0, xmm1, xmm2, 1 (LT): C5 F0 C2 C2 01
    add_xmm("vcmpps lt", {0xC5, 0xF0, 0xC2, 0xC2, 0x01}, s, 0x7);
  }

  // AVX conversion: VCVTDQ2PS, VCVTPS2DQ
  {
    ArchState s;
    s.xmm[1] = xmm_from_u32(1, 2, 0xFFFFFFFF, 100);  // ints: 1, 2, -1, 100

    // VCVTDQ2PS xmm0, xmm1: C5 F8 5B C1 (NP)
    add_xmm("vcvtdq2ps xmm0,xmm1", {0xC5, 0xF8, 0x5B, 0xC1}, s, 0x3);

    s.xmm[1] = xmm_from_f32(1.7f, -2.3f, 100.5f, 0.0f);
    // VCVTPS2DQ xmm0, xmm1: C5 F9 5B C1 (66)
    add_xmm("vcvtps2dq xmm0,xmm1", {0xC5, 0xF9, 0x5B, 0xC1}, s, 0x3);
    // VCVTTPS2DQ xmm0, xmm1: C5 FA 5B C1 (F3)
    add_xmm("vcvttps2dq xmm0,xmm1", {0xC5, 0xFA, 0x5B, 0xC1}, s, 0x3);
  }

  // =====================================================================
  // 48. AVX VBROADCAST, VINSERTF128/VEXTRACTF128
  // =====================================================================
  cat = "AVX";
  {
    ArchState s;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);

    // VBROADCASTSS xmm0, xmm1: VEX.128.66.0F38.W0 18 /r
    // 3-byte VEX: C4 [R̄.X̄.B̄.mmmmm] [W.vvvv.L.pp]
    // R̄=1, X̄=1, B̄=1, mmmmm=00010 (0F38) → byte1 = 0b_111_00010 = 0xE2
    // W=0, vvvv=1111 (unused), L=0, pp=01 (66) → byte2 = 0b_0_1111_0_01 = 0x79
    // ModRM: mod=11, reg=xmm0=0, rm=xmm1=1 → 0xC1
    add_xmm("vbroadcastss xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x18, 0xC1}, s, 0x3);
  }

  // =====================================================================
  // FSTP ST(i): must write before pop (off-by-one test)
  // =====================================================================
  cat = "x87";
  {
    ArchState s;
    s.rdi = DATA_ADDR;

    // FLD1, FLDZ, FLDPI, FSTP ST(2), FSTP [RDI], FSTP [RDI+8]
    // After FSTP ST(2): ST(0)=0.0, ST(1)=pi (pi was copied to ST(2) pre-pop)
    // After FSTP [RDI]: mem[0..7]=0.0, ST(0)=pi
    // After FSTP [RDI+8]: mem[8..15]=pi
    tests.push_back({"fstp st(2) order", cat,
      {0xD9, 0xE8,           // FLD1
       0xD9, 0xEE,           // FLDZ
       0xD9, 0xEB,           // FLDPI
       0xDD, 0xDA,           // FSTP ST(2)
       0xDD, 0x1F,           // FSTP [RDI] (m64fp)
       0xDD, 0x5F, 0x08},    // FSTP [RDI+8] (m64fp)
      s, FL_ALL, 0, false, {}, 16});
  }

  // =====================================================================
  // 49. More x87 transcendental/special operations
  // =====================================================================
  cat = "x87";
  {
    ArchState s;
    s.rdi = DATA_ADDR;

    // FLDL2T + FSTP: log2(10)
    tests.push_back({"fldl2t; fstp [rdi]", cat, {0xD9, 0xE9, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FLDLG2 + FSTP: log10(2)
    tests.push_back({"fldlg2; fstp [rdi]", cat, {0xD9, 0xEC, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FTST: compare ST(0) with 0.0
    // FLD1 + FTST → C1 should be clear (ST(0)>0)
    // D9 E8 (FLD1) + D9 E4 (FTST) + DF E0 (FNSTSW AX) to read result
    tests.push_back({"fld1+ftst+fstsw", cat,
                      {0xD9, 0xE8, 0xD9, 0xE4, 0xDF, 0xE0},
                      with_gpr_inputs(s, {}), FL_ALL, 0, false, {}, 0});

    // FINCSTP/FDECSTP: adjust FPU stack pointer
    // D9 F7 (FINCSTP) + DF E0 (FNSTSW AX)
    tests.push_back({"fincstp+fstsw", cat,
                      {0xD9, 0xF7, 0xDF, 0xE0},
                      with_gpr_inputs(s, {}), FL_ALL, 0, false, {}, 0});

    // D9 F6 (FDECSTP) + DF E0 (FNSTSW AX)
    tests.push_back({"fdecstp+fstsw", cat,
                      {0xD9, 0xF6, 0xDF, 0xE0},
                      with_gpr_inputs(s, {}), FL_ALL, 0, false, {}, 0});

    // FCOM: compare ST(0) and ST(1)
    // FLD1 + FLDZ + D8 D1 (FCOM ST(1)) + DF E0 (FNSTSW AX)
    tests.push_back({"fld1+fldz+fcom+fstsw", cat,
                      {0xD9, 0xE8, 0xD9, 0xEE, 0xD8, 0xD1, 0xDF, 0xE0},
                      with_gpr_inputs(s, {}), FL_ALL, 0, false, {}, 0});

    // FCOMP: compare ST(0) and ST(1), pop
    // FLD1 + FLDZ + D8 D9 (FCOMP ST(1)) + DF E0 (FNSTSW AX)
    tests.push_back({"fld1+fldz+fcomp+fstsw", cat,
                      {0xD9, 0xE8, 0xD9, 0xEE, 0xD8, 0xD9, 0xDF, 0xE0},
                      with_gpr_inputs(s, {}), FL_ALL, 0, false, {}, 0});

    // FXAM: examine ST(0) classification
    // FLD1 + D9 E5 (FXAM) + DF E0 (FNSTSW AX)
    tests.push_back({"fld1+fxam+fstsw", cat,
                      {0xD9, 0xE8, 0xD9, 0xE5, 0xDF, 0xE0},
                      with_gpr_inputs(s, {}), FL_ALL, 0, false, {}, 0});

    // FLDZ + FXAM (examine zero)
    tests.push_back({"fldz+fxam+fstsw", cat,
                      {0xD9, 0xEE, 0xD9, 0xE5, 0xDF, 0xE0},
                      with_gpr_inputs(s, {}), FL_ALL, 0, false, {}, 0});
  }

  // =====================================================================
  // 50. More string instruction sizes
  // =====================================================================
  cat = "String";
  {
    ArchState s;
    s.rdi = DATA_ADDR;

    // REP STOSW: fill with 16-bit values
    s.rax = 0xABCD;
    s.rcx = 4;
    // 66 F3 AB (REP STOSW)
    tests.push_back({"rep stosw", cat, {0x66, 0xF3, 0xAB},
                      s, FL_ALL, 0, false, {}, 8});

    // REP MOVSQ: copy 8-byte units
    u8 src_data[] = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88};
    s.rsi = DATA_ADDR;
    s.rdi = DATA_ADDR + 32;
    s.rcx = 1;
    // F3 48 A5 (REP MOVSQ)
    tests.push_back({"rep movsq", cat, {0xF3, 0x48, 0xA5},
                      with_gpr_inputs(s, {&ArchState::rcx, &ArchState::rdi, &ArchState::rsi}), FL_ALL, 0, false, {src_data, src_data + 8}, 40});

    // LODSB: load byte from [RSI] into AL
    s.rsi = DATA_ADDR;
    s.rdi = 0;
    s.rcx = 0;
    s.rax = 0;
    // AC (LODSB)
    tests.push_back({"lodsb", cat, {0xAC},
                      with_gpr_inputs(s, {&ArchState::rsi}), FL_ALL, 0, false, {src_data, src_data + 8}, 0});

    // LODSD: load dword from [RSI] into EAX
    // AD (LODSD — no REX.W, so 32-bit)
    tests.push_back({"lodsd", cat, {0xAD},
                      with_gpr_inputs(s, {&ArchState::rsi}), FL_ALL, 0, false, {src_data, src_data + 8}, 0});

    // SCASD: compare EAX with [RDI]
    s.rdi = DATA_ADDR;
    s.rax = 0x44332211;
    // AF (SCASD)
    tests.push_back({"scasd (match)", cat, {0xAF},
                      with_gpr_inputs(s, {&ArchState::rax, &ArchState::rdi}), FL_ALL, 0, false, {src_data, src_data + 8}, 0});
  }

  // =====================================================================
  // 51. AVX-512 (EVEX-encoded 128-bit) — basic tests
  //
  // EVEX 4-byte prefix: 62 [P0] [P1] [P2] opcode ModRM
  // P0 = R̄.X̄.B̄.R̄'.00.mm  (mm=01 for 0F map)
  // P1 = W.vvvv.1.pp      (pp=01 for 66 prefix)
  // P2 = z.L'L.b.V̄'.aaa   (L'L=00 for 128, aaa=000 for no mask)
  //
  // For xmm0 = xmm1 op xmm2: R̄=X̄=B̄=R̄'=1, vvvv=~1=1110, V̄'=1
  //   P0 = 0xF1, P1 = 0x75 (W=0,66), P2 = 0x08 (128,no mask)
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s;
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // VPADDD xmm0, xmm1, xmm2: 62 F1 75 08 FE C2
    add_xmm("evex vpaddd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xFE, 0xC2}, s, 0x7);

    // VPSUBD xmm0, xmm1, xmm2: 62 F1 75 08 FA C2
    add_xmm("evex vpsubd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xFA, 0xC2}, s, 0x7);

    // VPAND xmm0, xmm1, xmm2 (VPANDD): 62 F1 75 08 DB C2
    add_xmm("evex vpandd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xDB, 0xC2}, s, 0x7);

    // VPOR xmm0, xmm1, xmm2 (VPORD): 62 F1 75 08 EB C2
    add_xmm("evex vpord xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xEB, 0xC2}, s, 0x7);

    // VPXOR xmm0, xmm1, xmm2 (VPXORD): 62 F1 75 08 EF C2
    add_xmm("evex vpxord xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xEF, 0xC2}, s, 0x7);
  }
  {
    ArchState s;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // VADDPS xmm0, xmm1, xmm2 (EVEX.128.NP.0F W0):
    // P0=0xF1, P1=0x70 (W=0,vvvv=1110,1,pp=00), P2=0x08
    add_xmm("evex vaddps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x58, 0xC2}, s, 0x7);

    // VSUBPS xmm0, xmm1, xmm2
    add_xmm("evex vsubps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x5C, 0xC2}, s, 0x7);

    // VMULPS xmm0, xmm1, xmm2
    add_xmm("evex vmulps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x59, 0xC2}, s, 0x7);

    // VMOVAPS xmm0, xmm1 (EVEX.128.NP.0F W0):
    // P0=0xF1, P1=0x7C (vvvv=1111,1,pp=00), P2=0x08
    add_xmm("evex vmovaps xmm0,xmm1",
            {0x62, 0xF1, 0x7C, 0x08, 0x28, 0xC1}, with_vector_inputs(s, 0x2), 0x3);
  }
  {
    ArchState s;
    s.xmm[1] = xmm_from_f64(1.5, 2.5);
    s.xmm[2] = xmm_from_f64(3.0, 4.0);

    // VADDPD xmm0, xmm1, xmm2 (EVEX.128.66.0F W1):
    // P0=0xF1, P1=0xF5 (W=1,vvvv=1110,1,pp=01), P2=0x08
    add_xmm("evex vaddpd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0x58, 0xC2}, s, 0x7);

    // VMULPD xmm0, xmm1, xmm2
    add_xmm("evex vmulpd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0x59, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 52. VEX FMA instructions
  // VEX.128.66.0F38.W0: 3-byte VEX C4 E2 71 xx C2
  //   P0: R̄=1,X̄=1,B̄=1, mmmmm=00010 (0F38) → 0xE2
  //   P1: W=0, vvvv=~1=1110, L=0, pp=01 (66) → 0x71
  // =====================================================================
  cat = "AVX";
  {
    ArchState s;
    s.xmm[0] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);

    // VFMADD132PS xmm0, xmm1, xmm2: C4 E2 71 98 C2
    add_xmm("vex vfmadd132ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0x98, 0xC2}, s, 0x7);

    // VFMADD213PS xmm0, xmm1, xmm2: C4 E2 71 A8 C2
    add_xmm("vex vfmadd213ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xA8, 0xC2}, s, 0x7);

    // VFMADD231PS xmm0, xmm1, xmm2: C4 E2 71 B8 C2
    s.xmm[0] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    add_xmm("vex vfmadd231ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xB8, 0xC2}, s, 0x7);

    // VFMSUB132PS xmm0, xmm1, xmm2: C4 E2 71 9A C2
    s.xmm[0] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);
    add_xmm("vex vfmsub132ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0x9A, 0xC2}, s, 0x7);

    // VFNMADD132PS xmm0, xmm1, xmm2: C4 E2 71 9C C2
    add_xmm("vex vfnmadd132ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0x9C, 0xC2}, s, 0x7);

    // VFNMSUB132PS xmm0, xmm1, xmm2: C4 E2 71 9E C2
    add_xmm("vex vfnmsub132ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0x9E, 0xC2}, s, 0x7);

    // VFMADD132SS xmm0, xmm1, xmm2: C4 E2 71 99 C2
    add_xmm("vex vfmadd132ss xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0x99, 0xC2}, s, 0x7);

    // VFMADD213SS xmm0, xmm1, xmm2: C4 E2 71 A9 C2
    add_xmm("vex vfmadd213ss xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xA9, 0xC2}, s, 0x7);

    // VFMADD231SS xmm0, xmm1, xmm2: C4 E2 71 B9 C2
    add_xmm("vex vfmadd231ss xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xB9, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 53. VINSERTF128 / VEXTRACTF128
  // VINSERTF128 ymm, ymm, xmm, imm8: VEX.256.66.0F3A.W0 18 /r ib
  //   C4 E3 75 18 C2 01 → insert xmm2 into upper 128 of ymm0 (vvvv=ymm1)
  // VEXTRACTF128 xmm, ymm, imm8: VEX.256.66.0F3A.W0 19 /r ib
  //   C4 E3 7D 19 C2 01 → extract upper 128 of ymm0 into xmm2
  // =====================================================================
  cat = "AVX";
  {
    ArchState s;
    s.xmm[1] = xmm_from_u64(0x1111111122222222, 0x3333333344444444);
    s.xmm[2] = xmm_from_u64(0xAAAAAAAABBBBBBBB, 0xCCCCCCCCDDDDDDDD);

    // VINSERTF128 ymm0, ymm1, xmm2, 0 (insert into lower 128)
    // C4 E3 [R̄.X̄.B̄.mmmmm=11.00011] [W.vvvv.L.pp = 0.1110.1.01] 18 C2 00
    // P0=0xE3, P1=0x75 (vvvv=1110,L=1,pp=01), opcode=0x18, ModRM=0xC2, imm=0x00
    add_xmm("vinsertf128 ymm0,ymm1,xmm2,0",
            {0xC4, 0xE3, 0x75, 0x18, 0xC2, 0x00}, s, 0x7);

    // VINSERTF128 ymm0, ymm1, xmm2, 1 (insert into upper 128)
    add_xmm("vinsertf128 ymm0,ymm1,xmm2,1",
            {0xC4, 0xE3, 0x75, 0x18, 0xC2, 0x01}, s, 0x7);

    ArchState extract = {};
    extract.xmm[0] = xmm_from_u64(0x1111111122222222, 0x3333333344444444);
    extract.xmm[0].q[2] = 0x5555555566666666;
    extract.xmm[0].q[3] = 0x7777777788888888;
    // VEXTRACTF128 xmm2, ymm0, 0 (extract lower 128)
    // VEX.256.66.0F3A.W0 19 /r ib
    // C4 E3 7D 19 C2 00 → vvvv=1111 (unused), L=1
    add_xmm("vextractf128 xmm2,ymm0,0",
            {0xC4, 0xE3, 0x7D, 0x19, 0xC2, 0x00}, extract, 0x7);

    // VEXTRACTF128 xmm2, ymm0, 1 (extract upper 128)
    add_xmm("vextractf128 xmm2,ymm0,1",
            {0xC4, 0xE3, 0x7D, 0x19, 0xC2, 0x01}, extract, 0x7);
  }

  // =====================================================================
  // 54. More x87 transcendental/special
  // =====================================================================
  cat = "x87";
  {
    ArchState s;
    s.rdi = DATA_ADDR;

    // FPTAN: tan(ST(0)), push 1.0
    // FLD1 (D9 E8) + FPTAN (D9 F2) + FSTP [RDI] (DD 1F) + FSTP [RDI+8] (DD 5F 08)
    // ST(0) = 1.0, FPTAN pushes result: ST(0)=1.0, ST(1)=tan(1.0)
    tests.push_back({"fld1+fptan+fstp+fstp", cat,
                      {0xD9, 0xE8, 0xD9, 0xF2, 0xDD, 0x1F, 0xDD, 0x5F, 0x08},
                      s, FL_ALL, 0, false, {}, 16});

    // FPATAN: atan2(ST(1), ST(0)), pop
    // FLD1 (D9 E8) + FLD1 (D9 E8) + FPATAN (D9 F3) + FSTP [RDI] (DD 1F)
    // atan2(1.0, 1.0) = pi/4
    tests.push_back({"fld1+fld1+fpatan+fstp", cat,
                      {0xD9, 0xE8, 0xD9, 0xE8, 0xD9, 0xF3, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // F2XM1: 2^ST(0) - 1
    // FLDZ (D9 EE) + F2XM1 (D9 F0) + FSTP [RDI] (DD 1F)
    // 2^0 - 1 = 0.0
    tests.push_back({"fldz+f2xm1+fstp", cat,
                      {0xD9, 0xEE, 0xD9, 0xF0, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FYL2X: ST(1) * log2(ST(0)), pop
    // FLD1 (D9 E8) + FLD1 (D9 E8) + FYL2X (D9 F1) + FSTP [RDI]
    // 1.0 * log2(1.0) = 0.0
    tests.push_back({"fld1+fld1+fyl2x+fstp", cat,
                      {0xD9, 0xE8, 0xD9, 0xE8, 0xD9, 0xF1, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FYL2XP1: ST(1) * log2(ST(0) + 1), pop
    // FLDZ (D9 EE) + FLD1 (D9 E8) + FYL2XP1 (D9 F9) + FSTP [RDI]
    // log2(0 + 1) = 0 → 1.0 * 0 = 0.0
    // Note: ST(1)=FLDZ=0, ST(0)=FLD1=1, but fyl2xp1: ST(1)*log2(ST(0)+1)
    // Actually: push 0, push 1 → ST(0)=1, ST(1)=0 → 0*log2(1+1)=0
    tests.push_back({"fldz+fld1+fyl2xp1+fstp", cat,
                      {0xD9, 0xEE, 0xD9, 0xE8, 0xD9, 0xF9, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FPREM: ST(0) = ST(0) mod ST(1)
    // Push 3.0 then push 10.0: FILD [mem(3)] + FILD [mem(10)]
    // Use constants: FLD1 + FLD1 + FADDP → 2.0, then FPREM
    // Actually simpler: use FLDPI + FLD1 + FPREM + FSTP
    // pi mod 1.0
    tests.push_back({"fldpi+fld1+fprem+fstp+fstp", cat,
                      {0xD9, 0xEB, 0xD9, 0xE8, 0xD9, 0xF8, 0xDD, 0x1F, 0xDD, 0x5F, 0x08},
                      s, FL_ALL, 0, false, {}, 16});

    // FPREM1: IEEE remainder
    tests.push_back({"fldpi+fld1+fprem1+fstp+fstp", cat,
                      {0xD9, 0xEB, 0xD9, 0xE8, 0xD9, 0xF5, 0xDD, 0x1F, 0xDD, 0x5F, 0x08},
                      s, FL_ALL, 0, false, {}, 16});

    // FSCALE: ST(0) = ST(0) * 2^trunc(ST(1))
    // FLD1 + FLD1 + FSCALE + FSTP → 1.0 * 2^1 = 2.0
    tests.push_back({"fld1+fld1+fscale+fstp+fstp", cat,
                      {0xD9, 0xE8, 0xD9, 0xE8, 0xD9, 0xFD, 0xDD, 0x1F, 0xDD, 0x5F, 0x08},
                      s, FL_ALL, 0, false, {}, 16});

    // FXTRACT: split into exponent + significand
    // FLDPI + FXTRACT + FSTP + FSTP → exponent and significand of pi
    tests.push_back({"fldpi+fxtract+fstp+fstp", cat,
                      {0xD9, 0xEB, 0xD9, 0xF4, 0xDD, 0x1F, 0xDD, 0x5F, 0x08},
                      s, FL_ALL, 0, false, {}, 16});

    // FUCOM ST(1): compare ST(0) and ST(1) without pop
    // FLD1 + FLDPI + DD E1 (FUCOM ST(1)) + DF E0 (FNSTSW AX)
    tests.push_back({"fld1+fldpi+fucom+fstsw", cat,
                      {0xD9, 0xE8, 0xD9, 0xEB, 0xDD, 0xE1, 0xDF, 0xE0},
                      with_gpr_inputs(s, {}), FL_ALL, 0, false, {}, 0});

    // FUCOMP ST(1): compare ST(0) and ST(1), pop
    tests.push_back({"fld1+fldpi+fucomp+fstsw", cat,
                      {0xD9, 0xE8, 0xD9, 0xEB, 0xDD, 0xE9, 0xDF, 0xE0},
                      with_gpr_inputs(s, {}), FL_ALL, 0, false, {}, 0});
  }

  // =====================================================================
  // 55. More string instruction sizes
  // =====================================================================
  cat = "String";
  {
    ArchState s;
    s.rdi = DATA_ADDR;

    // LODSW: load word from [RSI] into AX (66 prefix)
    u8 src_data2[] = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88};
    s.rsi = DATA_ADDR;
    s.rax = 0;
    // 66 AD (LODSW)
    tests.push_back({"lodsw", cat, {0x66, 0xAD},
                      with_gpr_inputs(s, {&ArchState::rsi}), FL_ALL, 0, false,
                      {src_data2, src_data2 + 8}, 0});

    // REP MOVSD: copy 4-byte units
    s.rsi = DATA_ADDR;
    s.rdi = DATA_ADDR + 32;
    s.rcx = 2;
    // F3 A5 (REP MOVSD — no REX.W so 32-bit)
    tests.push_back({"rep movsd", cat, {0xF3, 0xA5},
                      with_gpr_inputs(s, {&ArchState::rcx, &ArchState::rdi, &ArchState::rsi}), FL_ALL, 0, false,
                      {src_data2, src_data2 + 8}, 40});

    // REP MOVSW: copy 2-byte units
    s.rsi = DATA_ADDR;
    s.rdi = DATA_ADDR + 32;
    s.rcx = 4;
    // F3 66 A5 (REP MOVSW)
    tests.push_back({"rep movsw", cat, {0x66, 0xF3, 0xA5},
                      with_gpr_inputs(s, {&ArchState::rcx, &ArchState::rdi, &ArchState::rsi}), FL_ALL, 0, false,
                      {src_data2, src_data2 + 8}, 40});

    // SCASW: compare AX with [RDI]
    s.rdi = DATA_ADDR;
    s.rax = 0x2211;
    s.rcx = 0;
    s.rsi = 0;
    // 66 AF (SCASW)
    tests.push_back({"scasw (match)", cat, {0x66, 0xAF},
                      with_gpr_inputs(s, {&ArchState::rax, &ArchState::rdi}), FL_ALL, 0, false,
                      {src_data2, src_data2 + 8}, 0});

    // SCASQ: compare RAX with [RDI]
    s.rax = 0x8877665544332211;
    // 48 AF (SCASQ)
    tests.push_back({"scasq (match)", cat, {0x48, 0xAF},
                      with_gpr_inputs(s, {&ArchState::rax, &ArchState::rdi}), FL_ALL, 0, false,
                      {src_data2, src_data2 + 8}, 0});

    // CMPSW: compare [RSI] with [RDI]
    s.rsi = DATA_ADDR;
    s.rdi = DATA_ADDR;
    s.rax = 0;
    // 66 A7 (CMPSW)
    tests.push_back({"cmpsw (equal)", cat, {0x66, 0xA7},
                      with_gpr_inputs(s, {&ArchState::rsi, &ArchState::rdi}), FL_ALL, 0, false,
                      {src_data2, src_data2 + 8}, 0});

    // CMPSD (string): compare [RSI] dword with [RDI] dword
    // A7 (CMPSD)
    tests.push_back({"cmpsd (equal)", cat, {0xA7},
                      with_gpr_inputs(s, {&ArchState::rsi, &ArchState::rdi}), FL_ALL, 0, false,
                      {src_data2, src_data2 + 8}, 0});

    // CMPSQ: compare [RSI] qword with [RDI] qword
    // 48 A7 (CMPSQ)
    tests.push_back({"cmpsq (equal)", cat, {0x48, 0xA7},
                      with_gpr_inputs(s, {&ArchState::rsi, &ArchState::rdi}), FL_ALL, 0, false,
                      {src_data2, src_data2 + 8}, 0});
  }

  // =====================================================================
  // 56. XGETBV test
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s = {.rcx = 0};  // XCR0 selector
    // XGETBV: 0F 01 D0
    add_xmm("xgetbv ecx=0", {0x0F, 0x01, 0xD0}, s, 0x0);
  }

  // =====================================================================
  // 57. More EVEX integer operations
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s;
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // VPADDQ xmm0, xmm1, xmm2: 62 F1 F5 08 D4 C2 (66,W=1)
    add_xmm("evex vpaddq xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0xD4, 0xC2}, s, 0x7);

    // VPSUBQ xmm0, xmm1, xmm2: 62 F1 F5 08 FB C2
    add_xmm("evex vpsubq xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0xFB, 0xC2}, s, 0x7);

    // VPSUBB xmm0, xmm1, xmm2: 62 F1 75 08 F8 C2 (66,W=0)
    add_xmm("evex vpsubb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xF8, 0xC2}, s, 0x7);

    // VPMINUB xmm0, xmm1, xmm2: 62 F1 75 08 DA C2
    add_xmm("evex vpminub xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xDA, 0xC2}, s, 0x7);

    // VPSLLD xmm0, xmm1, imm8(4): EVEX.128.66.0F W0 72 /6 ib
    // 62 F1 75 08 72 F1 04
    // Here reg=xmm1 (in vvvv for shift-imm), rm=xmm1, dst written to vvvv
    // Actually for VPSLLD by immediate, encoding is:
    // EVEX prefix + 72 + ModRM(/6=reg field 6, r/m=src) + imm8
    // dst = vvvv, src = r/m
    // 62 [F1] [75] [08] 72 [mod=11,reg=6,rm=1=0xF1] 04
    add_xmm("evex vpslld xmm0,xmm1,4",
            {0x62, 0xF1, 0x7D, 0x08, 0x72, 0xF1, 0x04}, with_vector_inputs(s, 0x2), 0x7);

    // VPSRLD xmm0, xmm1, imm8(4): 62 F1 7D 08 72 D1 04 (/2)
    add_xmm("evex vpsrld xmm0,xmm1,4",
            {0x62, 0xF1, 0x7D, 0x08, 0x72, 0xD1, 0x04}, with_vector_inputs(s, 0x2), 0x7);
  }

  // =====================================================================
  // 58. More EVEX FP operations
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s;
    s.xmm[1] = xmm_from_f32(1.0f, 4.0f, 9.0f, 16.0f);
    s.xmm[2] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);

    // VDIVPS xmm0, xmm1, xmm2: 62 F1 74 08 5E C2
    add_xmm("evex vdivps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x5E, 0xC2}, s, 0x7);

    // VMINPS xmm0, xmm1, xmm2: 62 F1 74 08 5D C2
    add_xmm("evex vminps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x5D, 0xC2}, s, 0x7);

    // VMAXPS xmm0, xmm1, xmm2: 62 F1 74 08 5F C2
    add_xmm("evex vmaxps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x5F, 0xC2}, s, 0x7);

    // VSQRTPS xmm0, xmm1: 62 F1 7C 08 51 C1 (NP,W=0,vvvv=1111)
    add_xmm("evex vsqrtps xmm0,xmm1",
            {0x62, 0xF1, 0x7C, 0x08, 0x51, 0xC1}, with_vector_inputs(s, 0x2), 0x3);
  }
  {
    ArchState s;
    s.xmm[1] = xmm_from_f64(1.5, 4.0);
    s.xmm[2] = xmm_from_f64(3.0, 2.0);

    // VSUBPD xmm0, xmm1, xmm2: 62 F1 F5 08 5C C2 (66,W=1)
    add_xmm("evex vsubpd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0x5C, 0xC2}, s, 0x7);

    // VDIVPD xmm0, xmm1, xmm2: 62 F1 F5 08 5E C2
    add_xmm("evex vdivpd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0x5E, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 59. EVEX FMA (more variants)
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s;
    s.xmm[0] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);

    // VFMSUB132PS: 62 F2 75 08 9A C2
    add_xmm("evex vfmsub132ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x9A, 0xC2}, s, 0x7);

    // VFNMADD132PS: 62 F2 75 08 9C C2
    add_xmm("evex vfnmadd132ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x9C, 0xC2}, s, 0x7);

    // VFNMSUB132PS: 62 F2 75 08 9E C2
    add_xmm("evex vfnmsub132ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x9E, 0xC2}, s, 0x7);

    // VFMSUB213PS: 62 F2 75 08 AA C2
    add_xmm("evex vfmsub213ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xAA, 0xC2}, s, 0x7);

    // VFNMADD213PS: 62 F2 75 08 AC C2
    add_xmm("evex vfnmadd213ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xAC, 0xC2}, s, 0x7);

    // VFNMSUB213PS: 62 F2 75 08 AE C2
    add_xmm("evex vfnmsub213ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xAE, 0xC2}, s, 0x7);

    // VFMSUB231PS: 62 F2 75 08 BA C2
    s.xmm[0] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    add_xmm("evex vfmsub231ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xBA, 0xC2}, s, 0x7);

    // VFNMADD231PS: 62 F2 75 08 BC C2
    add_xmm("evex vfnmadd231ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xBC, 0xC2}, s, 0x7);

    // VFNMSUB231PS: 62 F2 75 08 BE C2
    add_xmm("evex vfnmsub231ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xBE, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 60. EVEX FMA instructions (PD and scalar)
  //
  // VFMADD132PS: dst = dst * src3 + vvvv
  // EVEX.128.66.0F38.W0: P0=0xF2 (mm=10), P1=0x75, P2=0x08
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s;
    s.xmm[0] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);   // dst (a)
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f); // vvvv (c)
    s.xmm[2] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);    // src3 (b)
    // Result: a*b + c = {12, 23, 34, 45}

    // VFMADD132PS xmm0, xmm1, xmm2: 62 F2 75 08 98 C2
    add_xmm("evex vfmadd132ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x98, 0xC2}, s, 0x7);

    // VFMADD213PS: dst = vvvv * dst + src3 → xmm1 * xmm0 + xmm2
    // Opcode 0xA8: 62 F2 75 08 A8 C2
    s.xmm[0] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);
    // Result: xmm1 * xmm0 + xmm2 = {21, 61, 121, 201}
    add_xmm("evex vfmadd213ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xA8, 0xC2}, s, 0x7);

    // VFMADD231PS: dst = vvvv * src3 + dst → xmm1 * xmm2 + xmm0
    // Opcode 0xB8: 62 F2 75 08 B8 C2
    s.xmm[0] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    // Result: xmm1 * xmm2 + xmm0 = {21, 61, 121, 201}
    add_xmm("evex vfmadd231ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xB8, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 61. EVEX FMA PD and scalar SS/SD
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s;
    s.xmm[0] = xmm_from_f64(2.0, 3.0);
    s.xmm[1] = xmm_from_f64(10.0, 20.0);
    s.xmm[2] = xmm_from_f64(1.0, 1.0);

    // VFMADD132PD xmm0, xmm1, xmm2: EVEX.128.66.0F38.W1
    // P0=0xF2 (mm=10), P1=0xF5 (W=1,vvvv=1110,1,pp=01), P2=0x08
    add_xmm("evex vfmadd132pd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0xF5, 0x08, 0x98, 0xC2}, s, 0x7);

    // VFMADD213PD: 62 F2 F5 08 A8 C2
    add_xmm("evex vfmadd213pd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0xF5, 0x08, 0xA8, 0xC2}, s, 0x7);

    // VFMADD231PD: 62 F2 F5 08 B8 C2
    s.xmm[0] = xmm_from_f64(1.0, 1.0);
    s.xmm[1] = xmm_from_f64(10.0, 20.0);
    s.xmm[2] = xmm_from_f64(2.0, 3.0);
    add_xmm("evex vfmadd231pd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0xF5, 0x08, 0xB8, 0xC2}, s, 0x7);
  }
  {
    // Scalar FMA: VFMADD132SS, VFMADD132SD
    ArchState s;
    s.xmm[0] = xmm_from_f32(2.0f, 99.0f, 99.0f, 99.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 88.0f, 88.0f, 88.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 77.0f, 77.0f, 77.0f);

    // VFMADD132SS: EVEX.LIG.66.0F38.W0 99 /r
    // 62 F2 75 08 99 C2
    add_xmm("evex vfmadd132ss xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x99, 0xC2}, s, 0x7);

    // VFMADD213SS: 62 F2 75 08 A9 C2
    add_xmm("evex vfmadd213ss xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xA9, 0xC2}, s, 0x7);

    // VFMADD231SS: 62 F2 75 08 B9 C2
    add_xmm("evex vfmadd231ss xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xB9, 0xC2}, s, 0x7);

    s.xmm[0] = xmm_from_f64(2.0, 99.0);
    s.xmm[1] = xmm_from_f64(10.0, 88.0);
    s.xmm[2] = xmm_from_f64(1.0, 77.0);

    // VFMADD132SD: EVEX.LIG.66.0F38.W1 99 /r
    // 62 F2 F5 08 99 C2
    add_xmm("evex vfmadd132sd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0xF5, 0x08, 0x99, 0xC2}, s, 0x7);

    // VFMADD213SD: 62 F2 F5 08 A9 C2
    add_xmm("evex vfmadd213sd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0xF5, 0x08, 0xA9, 0xC2}, s, 0x7);

    // VFMADD231SD: 62 F2 F5 08 B9 C2
    add_xmm("evex vfmadd231sd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0xF5, 0x08, 0xB9, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 62. FBLD/FBSTP (BCD load/store)
  // =====================================================================
  cat = "x87";
  {
    ArchState s;
    s.rdi = DATA_ADDR;

    // FBLD loads a 10-byte packed BCD from memory
    // FBSTP stores to 10-byte packed BCD and pops
    // BCD encoding: 10 bytes, each nibble is a digit, byte 9 bit 7 = sign
    // Value 12345: stored as 45 23 01 00 00 00 00 00 00 00
    u8 bcd_data[10] = {0x45, 0x23, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

    // FBLD [RDI]: DF /4 → DF 27 (mod=00, reg=4, rm=7=RDI)
    // then FBSTP [RDI+16]: DF /6 → DF 6F 10
    tests.push_back({"fbld+fbstp", cat,
                      {0xDF, 0x27, 0xDF, 0x6F, 0x10},
                      s, FL_ALL, 0, false,
                      {bcd_data, bcd_data + 10}, 26});
  }

  // =====================================================================
  // x87 expanded: D8 memory forms (FADD/FSUB/FMUL/FDIV m32fp)
  // =====================================================================
  cat = "x87 mem";
  {
    ArchState s;
    s.rdi = DATA_ADDR;

    // FADD m32fp: FILD 10 + FADD [RDI+4] (m32fp 3.0) + FISTP [RDI]
    // D8 07 = FADD m32fp [RDI]
    float f3 = 3.0f;
    u8 fadd_data[8] = {};
    // [RDI+0..3] = int 10, [RDI+4..7] = float 3.0
    fadd_data[0] = 10;
    memcpy(fadd_data + 4, &f3, 4);
    // FILD m32 [RDI] (DB 07) + FADD m32fp [RDI+4] (D8 47 04) + FISTP m32 [RDI] (DB 1F)
    // 10 + 3.0 = 13.0 → FISTP → 13
    tests.push_back({"fild+fadd m32fp+fistp", cat,
                      {0xDB, 0x07, 0xD8, 0x47, 0x04, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {fadd_data, fadd_data + 8}, 4});

    // FSUB m32fp: FILD 10 + FSUB [RDI+4] (m32fp 3.0) + FISTP [RDI]
    // D8 27 = FSUB m32fp [RDI], D8 67 04 = FSUB m32fp [RDI+4]
    // 10 - 3.0 = 7.0 → 7
    tests.push_back({"fild+fsub m32fp+fistp", cat,
                      {0xDB, 0x07, 0xD8, 0x67, 0x04, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {fadd_data, fadd_data + 8}, 4});

    // FMUL m32fp: FILD 10 + FMUL [RDI+4] (m32fp 3.0) + FISTP [RDI]
    // D8 0F = FMUL m32fp [RDI], D8 4F 04 = FMUL m32fp [RDI+4]
    // 10 * 3.0 = 30.0 → 30
    tests.push_back({"fild+fmul m32fp+fistp", cat,
                      {0xDB, 0x07, 0xD8, 0x4F, 0x04, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {fadd_data, fadd_data + 8}, 4});

    // FDIV m32fp: FILD 10 + FDIV [RDI+4] (m32fp 2.0) + FISTP [RDI]
    float f2 = 2.0f;
    u8 fdiv_data[8] = {};
    fdiv_data[0] = 10;
    memcpy(fdiv_data + 4, &f2, 4);
    // D8 77 04 = FDIV m32fp [RDI+4]
    // 10 / 2.0 = 5.0 → 5
    tests.push_back({"fild+fdiv m32fp+fistp", cat,
                      {0xDB, 0x07, 0xD8, 0x77, 0x04, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {fdiv_data, fdiv_data + 8}, 4});

    // DC memory forms (m64fp): FADD/FSUB/FMUL/FDIV
    double d5 = 5.0;
    u8 dc_data[16] = {};
    // [RDI+0..3] = int 20, [RDI+8..15] = double 5.0
    dc_data[0] = 20;
    memcpy(dc_data + 8, &d5, 8);

    // FILD m32 [RDI] + FADD m64fp [RDI+8] + FISTP m32 [RDI]
    // DC 47 08 = FADD m64fp [RDI+8], 20+5=25
    tests.push_back({"fild+fadd m64fp+fistp", cat,
                      {0xDB, 0x07, 0xDC, 0x47, 0x08, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {dc_data, dc_data + 16}, 4});

    // FILD m32 [RDI] + FSUB m64fp [RDI+8] + FISTP m32 [RDI]
    // DC 67 08 = FSUB m64fp [RDI+8], 20-5=15
    tests.push_back({"fild+fsub m64fp+fistp", cat,
                      {0xDB, 0x07, 0xDC, 0x67, 0x08, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {dc_data, dc_data + 16}, 4});

    // FILD m32 [RDI] + FMUL m64fp [RDI+8] + FISTP m32 [RDI]
    // DC 4F 08 = FMUL m64fp [RDI+8], 20*5=100
    tests.push_back({"fild+fmul m64fp+fistp", cat,
                      {0xDB, 0x07, 0xDC, 0x4F, 0x08, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {dc_data, dc_data + 16}, 4});

    // FILD m32 [RDI] + FDIV m64fp [RDI+8] + FISTP m32 [RDI]
    // DC 77 08 = FDIV m64fp [RDI+8], 20/5=4
    tests.push_back({"fild+fdiv m64fp+fistp", cat,
                      {0xDB, 0x07, 0xDC, 0x77, 0x08, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {dc_data, dc_data + 16}, 4});

    // DA integer ops (FIADD/FISUB/FIMUL/FIDIV m32int)
    u8 ia_data[8] = {};
    ia_data[0] = 10;
    ia_data[4] = 3;

    // FILD m32 [RDI] + FIADD m32 [RDI+4] + FISTP m32 [RDI]
    // DA 47 04 = FIADD m32int [RDI+4], 10+3=13
    tests.push_back({"fild+fiadd m32+fistp", cat,
                      {0xDB, 0x07, 0xDA, 0x47, 0x04, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {ia_data, ia_data + 8}, 4});

    // DA 67 04 = FISUB m32int [RDI+4], 10-3=7
    tests.push_back({"fild+fisub m32+fistp", cat,
                      {0xDB, 0x07, 0xDA, 0x67, 0x04, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {ia_data, ia_data + 8}, 4});

    // DA 4F 04 = FIMUL m32int [RDI+4], 10*3=30
    tests.push_back({"fild+fimul m32+fistp", cat,
                      {0xDB, 0x07, 0xDA, 0x4F, 0x04, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {ia_data, ia_data + 8}, 4});

    // FIDIV: use 10 / 2 = 5
    u8 idiv_data[8] = {};
    idiv_data[0] = 10;
    idiv_data[4] = 2;
    // DA 77 04 = FIDIV m32int [RDI+4], 10/2=5
    tests.push_back({"fild+fidiv m32+fistp", cat,
                      {0xDB, 0x07, 0xDA, 0x77, 0x04, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {idiv_data, idiv_data + 8}, 4});

    // DE integer ops with pop (i16): FIADD/FISUB/FIMUL/FIDIV m16int
    u8 de_data[4] = {};
    de_data[0] = 10;  // int16 = 10
    de_data[2] = 3;   // int16 = 3

    // FILD m16 [RDI+2] + FILD m16 [RDI] + DE 47 02 (FIADD m16 [RDI+2]) + FISTP m32 [RDI]
    // Actually simpler: FILD m16 [RDI] → 10 on stack, FIADD m16 [RDI+2] → 10+3=13
    // DF 07 (FILD m16 [RDI]) + DE 47 02 (FIADD m16 [RDI+2]) + DB 1F (FISTP m32)
    tests.push_back({"fild m16+fiadd m16+fistp", cat,
                      {0xDF, 0x07, 0xDE, 0x47, 0x02, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {de_data, de_data + 4}, 4});

    // FSINCOS: push sin and cos simultaneously
    // D9 EE (FLDZ) + D9 FB (FSINCOS) + DD 1F (FSTP [RDI]) + DD 5F 08 (FSTP [RDI+8])
    // sin(0)=0, cos(0)=1 → FSINCOS pushes: ST(0)=cos(0)=1.0, ST(1)=sin(0)=0.0
    // FSTP [RDI] stores cos=1.0, FSTP [RDI+8] stores sin=0.0
    tests.push_back({"fldz+fsincos+fstp+fstp", cat,
                      {0xD9, 0xEE, 0xD9, 0xFB, 0xDD, 0x1F, 0xDD, 0x5F, 0x08},
                      s, FL_ALL, 0, false, {}, 16});

    // FCMOVB: conditional move if CF=1
    // Set CF via STC (F9), then FLD1 + FLDZ + FCMOVB ST(0),ST(1) + FSTP
    // FLDZ → ST(0)=0, FLD1 → ST(0)=1, ST(1)=0
    // Wait, FCMOVB moves ST(i) to ST(0) if below (CF=1)
    // FLD1 + FLDZ → ST(0)=0, ST(1)=1
    // STC sets CF, FCMOVB ST(0),ST(1) → ST(0) = ST(1) = 1.0
    // DA C1 = FCMOVB ST(0), ST(1)
    ArchState sc = {};
    sc.rdi = DATA_ADDR;
    tests.push_back({"fld1+fldz+stc+fcmovb+fstp", cat,
                      {0xD9, 0xE8, 0xD9, 0xEE, 0xF9, 0xDA, 0xC1, 0xDD, 0x1F},
                      sc, FL_ALL, 0, false, {}, 8});

    // FCMOVNB: conditional move if CF=0 (no carry)
    // CLC (F8), FLD1 + FLDZ + FCMOVNB ST(0),ST(1) + FSTP
    // DB C1 = FCMOVNB ST(0), ST(1)
    tests.push_back({"fld1+fldz+clc+fcmovnb+fstp", cat,
                      {0xD9, 0xE8, 0xD9, 0xEE, 0xF8, 0xDB, 0xC1, 0xDD, 0x1F},
                      sc, FL_ALL, 0, false, {}, 8});

    // FCMOVE: conditional move if ZF=1
    // Set ZF: XOR EAX,EAX (31 C0), then FLD1 + FLDZ + FCMOVE + FSTP
    // DA C9 = FCMOVE ST(0), ST(1)
    tests.push_back({"fld1+fldz+xor eax+fcmove+fstp", cat,
                      {0xD9, 0xE8, 0xD9, 0xEE, 0x31, 0xC0, 0xDA, 0xC9, 0xDD, 0x1F},
                      sc, FL_ALL, 0, false, {}, 8});

    // FISTTP (SSE3 truncation store): FLDPI + FISTTP m32 [RDI]
    // DB 0F = FISTTP m32int [RDI]
    // pi truncated = 3
    tests.push_back({"fldpi+fisttp m32", cat,
                      {0xD9, 0xEB, 0xDB, 0x0F},
                      sc, FL_ALL, 0, false, {}, 4});

    // FISTTP m64: FLDPI + FISTTP m64int [RDI]
    // DD 0F = FISTTP m64int [RDI]
    tests.push_back({"fldpi+fisttp m64", cat,
                      {0xD9, 0xEB, 0xDD, 0x0F},
                      sc, FL_ALL, 0, false, {}, 8});

    // FISTTP m16: FLDPI + FISTTP m16int [RDI]
    // DF 0F = FISTTP m16int [RDI]
    tests.push_back({"fldpi+fisttp m16", cat,
                      {0xD9, 0xEB, 0xDF, 0x0F},
                      sc, FL_ALL, 0, false, {}, 2});

    // FCOMIP: compare and pop, setting EFLAGS
    // FLD1 + FLDPI + DF F1 (FCOMIP ST, ST(1)) — pi > 1, so CF=0, ZF=0
    tests.push_back({"fld1+fldpi+fcomip", cat,
                      {0xD9, 0xE8, 0xD9, 0xEB, 0xDF, 0xF1},
                      with_gpr_inputs(sc, {}), FL_ALL, 0, false, {}, 0});

    // FCOMIP equal case
    // FLD1 + FLD1 + FCOMIP → equal, ZF=1, CF=0, PF=0
    tests.push_back({"fld1+fld1+fcomip eq", cat,
                      {0xD9, 0xE8, 0xD9, 0xE8, 0xDF, 0xF1},
                      with_gpr_inputs(sc, {}), FL_ALL, 0, false, {}, 0});

    // FSUBR m32fp: FILD 3 + FSUBR [RDI+4] (m32fp 10.0) + FISTP [RDI]
    // D8 2F = FSUBR m32fp [RDI], D8 6F 04 = FSUBR m32fp [RDI+4]
    // FSUBR: ST(0) = mem - ST(0) = 10.0 - 3.0 = 7.0
    float f10 = 10.0f;
    u8 fsubr_data[8] = {};
    fsubr_data[0] = 3;
    memcpy(fsubr_data + 4, &f10, 4);
    tests.push_back({"fild+fsubr m32fp+fistp", cat,
                      {0xDB, 0x07, 0xD8, 0x6F, 0x04, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {fsubr_data, fsubr_data + 8}, 4});

    // FDIVR m32fp: FILD 3 + FDIVR [RDI+4] (m32fp 12.0) + FISTP [RDI]
    // D8 3F = FDIVR m32fp [RDI], D8 7F 04 = FDIVR m32fp [RDI+4]
    // FDIVR: ST(0) = mem / ST(0) = 12.0 / 3.0 = 4.0
    float f12 = 12.0f;
    u8 fdivr_data[8] = {};
    fdivr_data[0] = 3;
    memcpy(fdivr_data + 4, &f12, 4);
    tests.push_back({"fild+fdivr m32fp+fistp", cat,
                      {0xDB, 0x07, 0xD8, 0x7F, 0x04, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {fdivr_data, fdivr_data + 8}, 4});
  }

  // =====================================================================
  // 63. EVEX 256-bit (YMM) operations
  //
  // P2: z=0, L'L=01 (256-bit), b=0, V'=1, aaa=000
  //   → P2 = 0b_0_01_0_1_000 = 0x28
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // YMM upper halves (xmm indices 17, 18 in our model — but KVM uses
    // xsave area). For register-to-register, we set initial YMM state.
    // Our harness only sets XMM[0..15], not YMM upper halves.
    // Let's use 128-bit tests that are already well-covered and add
    // a few 256-bit integer tests.

    // VPADDD ymm0, ymm1, ymm2 (EVEX.256.66.0F.W0):
    // P0=0xF1 (mm=01), P1=0x75, P2=0x28 (L'L=01)
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);
    add_xmm("evex vpaddd ymm0,ymm1,ymm2 (256)",
            {0x62, 0xF1, 0x75, 0x28, 0xFE, 0xC2}, s, 0x7);

    // VADDPS ymm0, ymm1, ymm2 (EVEX.256.NP.0F.W0):
    // P1=0x74 (vvvv=1110,pp=00), P2=0x28
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);
    add_xmm("evex vaddps ymm0,ymm1,ymm2 (256)",
            {0x62, 0xF1, 0x74, 0x28, 0x58, 0xC2}, s, 0x7);

    // VPXORD ymm0, ymm1, ymm2 (EVEX.256.66.0F.W0):
    s.xmm[1] = xmm_from_u64(0xFFFFFFFF00000000, 0x12345678ABCDEF01);
    s.xmm[2] = xmm_from_u64(0x0F0F0F0FF0F0F0F0, 0xFEDCBA9876543210);
    add_xmm("evex vpxord ymm0,ymm1,ymm2 (256)",
            {0x62, 0xF1, 0x75, 0x28, 0xEF, 0xC2}, s, 0x7);

    // VMULPS ymm0, ymm1, ymm2 (EVEX.256.NP.0F.W0):
    s.xmm[1] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    s.xmm[2] = xmm_from_f32(10.0f, 10.0f, 10.0f, 10.0f);
    add_xmm("evex vmulps ymm0,ymm1,ymm2 (256)",
            {0x62, 0xF1, 0x74, 0x28, 0x59, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 64. EVEX shuffle/permutation
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // VSHUFPS xmm0, xmm1, xmm2, imm8: EVEX.128.NP.0F.W0 C6 /r ib
    // 62 F1 74 08 C6 C2 0x1B (select 3,2,1,0 → reverse)
    add_xmm("evex vshufps xmm0,xmm1,xmm2,0x1B",
            {0x62, 0xF1, 0x74, 0x08, 0xC6, 0xC2, 0x1B}, s, 0x7);

    // VUNPCKLPS xmm0, xmm1, xmm2: EVEX.128.NP.0F.W0 14 /r
    add_xmm("evex vunpcklps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x14, 0xC2}, s, 0x7);

    // VUNPCKHPS xmm0, xmm1, xmm2: EVEX.128.NP.0F.W0 15 /r
    add_xmm("evex vunpckhps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x15, 0xC2}, s, 0x7);

    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // VPUNPCKLDQ xmm0, xmm1, xmm2: EVEX.128.66.0F.W0 62 /r
    add_xmm("evex vpunpckldq xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0x62, 0xC2}, s, 0x7);

    // VPUNPCKLQDQ xmm0, xmm1, xmm2: EVEX.128.66.0F.W1 6C /r
    add_xmm("evex vpunpcklqdq xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0x6C, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 65. EVEX conversion instructions
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s;
    s.xmm[1] = xmm_from_f32(1.5f, 2.7f, -3.2f, 4.9f);

    // VCVTPS2DQ xmm0, xmm1: EVEX.128.66.0F.W0 5B /r
    // 62 F1 7D 08 5B C1 (vvvv=1111 unused)
    add_xmm("evex vcvtps2dq xmm0,xmm1",
            {0x62, 0xF1, 0x7D, 0x08, 0x5B, 0xC1}, s, 0x3);

    // VCVTTPS2DQ xmm0, xmm1: EVEX.128.F3.0F.W0 5B /r
    // 62 F1 7E 08 5B C1
    add_xmm("evex vcvttps2dq xmm0,xmm1",
            {0x62, 0xF1, 0x7E, 0x08, 0x5B, 0xC1}, s, 0x3);

    // VCVTDQ2PS xmm0, xmm1: EVEX.128.NP.0F.W0 5B /r
    s.xmm[1] = xmm_from_u64(0x0000000100000002, 0x00000003FFFFFFFE);
    add_xmm("evex vcvtdq2ps xmm0,xmm1",
            {0x62, 0xF1, 0x7C, 0x08, 0x5B, 0xC1}, s, 0x3);
  }

  // =====================================================================
  // 66. EVEX VFMADDSUB / VFMSUBADD
  //
  // VFMADDSUB132PS: even elements use subtract, odd use add
  // (result[i] = a*b+c for odd i, a*b-c for even i)
  // EVEX.128.66.0F38.W0: opcode 0x96
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s;
    s.xmm[0] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);

    // VFMADDSUB132PS: 62 F2 75 08 96 C2
    add_xmm("evex vfmaddsub132ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x96, 0xC2}, s, 0x7);

    // VFMADDSUB213PS: 62 F2 75 08 A6 C2
    add_xmm("evex vfmaddsub213ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xA6, 0xC2}, s, 0x7);

    // VFMADDSUB231PS: 62 F2 75 08 B6 C2
    s.xmm[0] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    add_xmm("evex vfmaddsub231ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xB6, 0xC2}, s, 0x7);

    // VFMSUBADD132PS: 62 F2 75 08 97 C2
    s.xmm[0] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);
    add_xmm("evex vfmsubadd132ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x97, 0xC2}, s, 0x7);

    // VFMSUBADD213PS: 62 F2 75 08 A7 C2
    add_xmm("evex vfmsubadd213ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xA7, 0xC2}, s, 0x7);

    // VFMSUBADD231PS: 62 F2 75 08 B7 C2
    s.xmm[0] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    add_xmm("evex vfmsubadd231ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xB7, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 67. EVEX 0F38 arithmetic/comparison
  // EVEX.128.66.0F38: P0=0xF2 (mm=10), P1=0x75 (W=0,66), P2=0x08
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s;
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x0807060504030201, 0x100F0E0D0C0B0A09);

    // VPMINSB xmm0, xmm1, xmm2: 62 F2 75 08 38 C2
    add_xmm("evex vpminsb xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x38, 0xC2}, s, 0x7);

    // VPMINSD xmm0, xmm1, xmm2: 62 F2 75 08 39 C2
    add_xmm("evex vpminsd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x39, 0xC2}, s, 0x7);

    // VPMAXSB xmm0, xmm1, xmm2: 62 F2 75 08 3C C2
    add_xmm("evex vpmaxsb xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x3C, 0xC2}, s, 0x7);

    // VPMAXSD xmm0, xmm1, xmm2: 62 F2 75 08 3D C2
    add_xmm("evex vpmaxsd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x3D, 0xC2}, s, 0x7);

    // VPMINUD xmm0, xmm1, xmm2: 62 F2 75 08 3B C2
    add_xmm("evex vpminud xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x3B, 0xC2}, s, 0x7);

    // VPMAXUD xmm0, xmm1, xmm2: 62 F2 75 08 3F C2
    add_xmm("evex vpmaxud xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x3F, 0xC2}, s, 0x7);

    // VPACKUSDW xmm0, xmm1, xmm2: 62 F2 75 08 2B C2
    add_xmm("evex vpackusdw xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x2B, 0xC2}, s, 0x7);

    // VPMULLD xmm0, xmm1, xmm2: 62 F2 75 08 40 C2
    add_xmm("evex vpmulld xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x40, 0xC2}, s, 0x7);

    // VPMULUDQ xmm0, xmm1, xmm2: 62 F1 F5 08 F4 C2 (66,W=1)
    add_xmm("evex vpmuludq xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0xF4, 0xC2}, s, 0x7);

    // VPMULLW xmm0, xmm1, xmm2: 62 F1 75 08 D5 C2 (0F map)
    add_xmm("evex vpmullw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xD5, 0xC2}, s, 0x7);

    // VPABSB xmm0, xmm1: EVEX.128.66.0F38.W0 1C /r
    // 62 F2 7D 08 1C C1 (vvvv=1111 unused)
    s.xmm[1] = xmm_from_u64(0x80FF01027F00FE03, 0x0405060708090A0B);
    add_xmm("evex vpabsb xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x1C, 0xC1}, with_vector_inputs(s, 0x2), 0x3);

    // VPABSD xmm0, xmm1: 62 F2 7D 08 1E C1
    add_xmm("evex vpabsd xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x1E, 0xC1}, with_vector_inputs(s, 0x2), 0x3);
  }

  // =====================================================================
  // 68. EVEX permutation/shuffle
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s;
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    // Control: element i selects src[ctrl[i][1:0]]
    // 0x03020100 → select [0,1,2,3] (identity)
    // 0x00010203 → select [3,2,1,0] (reverse)
    s.xmm[2] = xmm_from_u64(0x0000000300000002, 0x0000000100000000);

    // VPERMILPS xmm0, xmm1, xmm2: EVEX.128.66.0F38.W0 0C /r
    // 62 F2 75 08 0C C2
    add_xmm("evex vpermilps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x0C, 0xC2}, s, 0x7);

    // Reverse: ctrl=[3,2,1,0]
    s.xmm[2] = xmm_from_u64(0x0000000000000001, 0x0000000200000003);
    add_xmm("evex vpermilps rev xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x0C, 0xC2}, s, 0x7);

    // VPERMILPS with immediate: EVEX.128.66.0F3A.W0 04 /r ib
    // 62 F3 7D 08 04 C1 1B → VPERMILPS xmm0, xmm1, 0x1B (reverse)
    add_xmm("evex vpermilps xmm0,xmm1,0x1B",
            {0x62, 0xF3, 0x7D, 0x08, 0x04, 0xC1, 0x1B}, with_vector_inputs(s, 0x2), 0x3);

    // VPSHUFB xmm0, xmm1, xmm2: EVEX.128.66.0F38.W0 00 /r
    // 62 F2 75 08 00 C2
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    // Control: byte shuffle. High bit = zero out, otherwise idx&0xF selects byte.
    s.xmm[2] = xmm_from_u64(0x0001020380040506, 0x0708090A0B0C0D0E);
    add_xmm("evex vpshufb xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x00, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 69. EVEX immediate instructions (0F3A map)
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s;
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // VPALIGNR xmm0, xmm1, xmm2, 4: EVEX.128.66.0F3A.WIG 0F /r ib
    // 62 F3 75 08 0F C2 04
    add_xmm("evex vpalignr xmm0,xmm1,xmm2,4",
            {0x62, 0xF3, 0x75, 0x08, 0x0F, 0xC2, 0x04}, s, 0x7);

    // VPEXTRB ecx, xmm1, 3: EVEX.128.66.0F3A.WIG 14 /r ib
    // 62 F3 7D 08 14 C9 03 (reg=xmm1, r/m=ecx)
    add_xmm("evex vpextrb ecx,xmm1,3",
            {0x62, 0xF3, 0x7D, 0x08, 0x14, 0xC9, 0x03}, with_vector_inputs(s, 0x2), 0x3);

    // VPEXTRD ecx, xmm1, 2: EVEX.128.66.0F3A.W0 16 /r ib
    // 62 F3 7D 08 16 C9 02
    add_xmm("evex vpextrd ecx,xmm1,2",
            {0x62, 0xF3, 0x7D, 0x08, 0x16, 0xC9, 0x02}, with_vector_inputs(s, 0x2), 0x3);

    // VPINSRB xmm0, xmm1, ecx, 5: EVEX.128.66.0F3A.WIG 20 /r ib
    // 62 F3 75 08 20 C1 05
    s.rcx = 0x42;
    add_xmm("evex vpinsrb xmm0,xmm1,ecx,5",
            {0x62, 0xF3, 0x75, 0x08, 0x20, 0xC1, 0x05}, with_vector_inputs(s, 0x2), 0x7);

    // VPINSRD xmm0, xmm1, ecx, 1: EVEX.128.66.0F3A.W0 22 /r ib
    // 62 F3 75 08 22 C1 01
    s.rcx = 0xDEADBEEF;
    add_xmm("evex vpinsrd xmm0,xmm1,ecx,1",
            {0x62, 0xF3, 0x75, 0x08, 0x22, 0xC1, 0x01}, with_vector_inputs(s, 0x2), 0x7);

    // VPSHUFD xmm0, xmm1, 0x1B: EVEX.128.66.0F.W0 70 /r ib
    // 62 F1 7D 08 70 C1 1B
    add_xmm("evex vpshufd xmm0,xmm1,0x1B",
            {0x62, 0xF1, 0x7D, 0x08, 0x70, 0xC1, 0x1B},
                with_vector_inputs(with_gpr_inputs(s, {}), 0x2), 0x3);

    // VPSHUFHW xmm0, xmm1, 0x1B: EVEX.128.F3.0F.WIG 70 /r ib
    // 62 F1 7E 08 70 C1 1B
    add_xmm("evex vpshufhw xmm0,xmm1,0x1B",
            {0x62, 0xF1, 0x7E, 0x08, 0x70, 0xC1, 0x1B},
                with_vector_inputs(with_gpr_inputs(s, {}), 0x2), 0x3);

    // VPSHUFLW xmm0, xmm1, 0x1B: EVEX.128.F2.0F.WIG 70 /r ib
    // 62 F1 7F 08 70 C1 1B
    add_xmm("evex vpshuflw xmm0,xmm1,0x1B",
            {0x62, 0xF1, 0x7F, 0x08, 0x70, 0xC1, 0x1B},
                with_vector_inputs(with_gpr_inputs(s, {}), 0x2), 0x3);
  }

  // =====================================================================
  // 70. EVEX more arithmetic (0F38 map)
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s;
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x0807060504030201, 0x100F0E0D0C0B0A09);

    // VPMAXUW xmm0, xmm1, xmm2: 62 F2 75 08 3E C2
    add_xmm("evex vpmaxuw xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x3E, 0xC2}, s, 0x7);

    // VPABSW xmm0, xmm1: 62 F2 7D 08 1D C1
    s.xmm[1] = xmm_from_u64(0x80007FFF00010002, 0xFFFE000300040005);
    add_xmm("evex vpabsw xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x1D, 0xC1}, with_vector_inputs(s, 0x2), 0x3);

    // VPABSQ xmm0, xmm1: 62 F2 FD 08 1F C1 (W=1)
    s.xmm[1] = xmm_from_u64(0xFFFFFFFFFFFFFFFF, 0x0000000000000001);
    add_xmm("evex vpabsq xmm0,xmm1",
            {0x62, 0xF2, 0xFD, 0x08, 0x1F, 0xC1}, with_vector_inputs(s, 0x2), 0x3);

    // VPMADDUBSW xmm0, xmm1, xmm2: 62 F2 75 08 04 C2
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    add_xmm("evex vpmaddubsw xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x04, 0xC2}, s, 0x7);

    // VPMULHRSW xmm0, xmm1, xmm2: 62 F2 75 08 0B C2
    add_xmm("evex vpmulhrsw xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x0B, 0xC2}, s, 0x7);

    // VPMADDWD xmm0, xmm1, xmm2: EVEX.128.66.0F.W0 F5 /r
    // 62 F1 75 08 F5 C2
    add_xmm("evex vpmaddwd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xF5, 0xC2}, s, 0x7);

    // VPSADBW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG F6 /r
    // 62 F1 75 08 F6 C2
    add_xmm("evex vpsadbw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xF6, 0xC2}, s, 0x7);

    // VPMULHUW xmm0, xmm1, xmm2: EVEX.128.66.0F.W0 E4 /r
    // 62 F1 75 08 E4 C2
    add_xmm("evex vpmulhuw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xE4, 0xC2}, s, 0x7);

    // VPMULHW xmm0, xmm1, xmm2: EVEX.128.66.0F.W0 E5 /r
    // 62 F1 75 08 E5 C2
    add_xmm("evex vpmulhw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xE5, 0xC2}, s, 0x7);

    // VPAVGB xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG E0 /r
    // 62 F1 75 08 E0 C2
    add_xmm("evex vpavgb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xE0, 0xC2}, s, 0x7);

    // VPAVGW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG E3 /r
    // 62 F1 75 08 E3 C2
    add_xmm("evex vpavgw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xE3, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 71. EVEX data movement and more integer
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s;
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // VMOVDQA32 xmm0, xmm1: EVEX.128.66.0F.W0 6F /r
    // 62 F1 7D 08 6F C1
    add_xmm("evex vmovdqa32 xmm0,xmm1",
            {0x62, 0xF1, 0x7D, 0x08, 0x6F, 0xC1}, with_vector_inputs(s, 0x2), 0x3);

    // VMOVD xmm0, ecx: EVEX.128.66.0F.W0 6E /r
    // 62 F1 7D 08 6E C1 (reg=xmm0, r/m=ecx)
    s.rcx = 0xDEADBEEF;
    add_xmm("evex vmovd xmm0,ecx",
            {0x62, 0xF1, 0x7D, 0x08, 0x6E, 0xC1}, with_vector_inputs(s, 0x0), 0x3);

    // VMOVQ xmm0, rcx: EVEX.128.66.0F.W1 6E /r
    // 62 F1 FD 08 6E C1
    s.rcx = 0x123456789ABCDEF0;
    add_xmm("evex vmovq xmm0,rcx",
            {0x62, 0xF1, 0xFD, 0x08, 0x6E, 0xC1}, with_vector_inputs(s, 0x0), 0x3);

    // VPADDB xmm0, xmm1, xmm2: 62 F1 75 08 FC C2
    add_xmm("evex vpaddb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xFC, 0xC2}, with_gpr_inputs(s, {}), 0x7);

    // VPADDW xmm0, xmm1, xmm2: 62 F1 75 08 FD C2
    add_xmm("evex vpaddw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xFD, 0xC2}, with_gpr_inputs(s, {}), 0x7);

    // VPSUBW xmm0, xmm1, xmm2: 62 F1 75 08 F9 C2
    add_xmm("evex vpsubw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xF9, 0xC2}, with_gpr_inputs(s, {}), 0x7);

    // VPANDND xmm0, xmm1, xmm2: 62 F1 75 08 DF C2
    add_xmm("evex vpandnd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xDF, 0xC2}, with_gpr_inputs(s, {}), 0x7);

    // VPADDSB xmm0, xmm1, xmm2: 62 F1 75 08 EC C2
    add_xmm("evex vpaddsb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xEC, 0xC2}, with_gpr_inputs(s, {}), 0x7);

    // VPADDUSB xmm0, xmm1, xmm2: 62 F1 75 08 DC C2
    add_xmm("evex vpaddusb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xDC, 0xC2}, with_gpr_inputs(s, {}), 0x7);

    // VPSUBSB xmm0, xmm1, xmm2: 62 F1 75 08 E8 C2
    add_xmm("evex vpsubsb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xE8, 0xC2}, with_gpr_inputs(s, {}), 0x7);

    // VPSUBUSB xmm0, xmm1, xmm2: 62 F1 75 08 D8 C2
    add_xmm("evex vpsubusb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xD8, 0xC2}, with_gpr_inputs(s, {}), 0x7);
  }

  // =====================================================================
  // 72. EVEX FP comparison
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(4.0f, 2.0f, 1.0f, 5.0f);

    // VCMPPS xmm0, xmm1, xmm2, 0 (EQ): EVEX.128.NP.0F.W0 C2 /r ib
    // Result goes to k register in AVX-512, but if no masking, still
    // writes to register. Actually VCMPPS in EVEX writes to k register.
    // Let me use VUCOMISS instead which writes to RFLAGS.

    // VUCOMISS xmm1, xmm2: EVEX.LIG.NP.0F.W0 2E /r
    // 62 F1 7C 08 2E CA (reg=xmm1, r/m=xmm2)
    add_xmm("evex vucomiss xmm1,xmm2",
            {0x62, 0xF1, 0x7C, 0x08, 0x2E, 0xCA}, s, 0x3);

    s.xmm[1] = xmm_from_f64(1.5, 2.5);
    s.xmm[2] = xmm_from_f64(3.0, 2.5);

    // VUCOMISD xmm1, xmm2: EVEX.LIG.66.0F.W1 2E /r
    // 62 F1 FD 08 2E CA
    add_xmm("evex vucomisd xmm1,xmm2",
            {0x62, 0xF1, 0xFD, 0x08, 0x2E, 0xCA}, s, 0x3);
  }

  // =====================================================================
  // 73. VEX VFMADDSUB / VFMSUBADD
  // =====================================================================
  cat = "AVX";
  {
    ArchState s;
    s.xmm[0] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);

    // VFMADDSUB132PS: C4 E2 71 96 C2
    add_xmm("vex vfmaddsub132ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0x96, 0xC2}, s, 0x7);

    // VFMADDSUB213PS: C4 E2 71 A6 C2
    add_xmm("vex vfmaddsub213ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xA6, 0xC2}, s, 0x7);

    // VFMSUBADD132PS: C4 E2 71 97 C2
    add_xmm("vex vfmsubadd132ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0x97, 0xC2}, s, 0x7);

    // VFMSUBADD213PS: C4 E2 71 A7 C2
    add_xmm("vex vfmsubadd213ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xA7, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // x87 forms the differential suite had not exercised (found by measuring
  // which decoder arms the suite reaches): the register-operand arithmetic
  // of D8/DC/DE, the remaining memory forms, the environment and state
  // images, and the reserved encodings.  Operands are exact in binary64, so
  // results do not depend on rounding unless a test says so.
  //
  // Data page layout unless noted: [rdi] = a, [rdi+8] = b (binary64),
  // results from [rdi+16].  The status word is read through FNSTSW AX.
  // =====================================================================
  {
    auto f64b = [](double d) { std::vector<u8> v(8); memcpy(v.data(), &d, 8); return v; };
    auto f32b = [](float f) { std::vector<u8> v(4); memcpy(v.data(), &f, 4); return v; };
    auto i32b = [](int32_t i) { std::vector<u8> v(4); memcpy(v.data(), &i, 4); return v; };
    auto i16b = [](int16_t i) { std::vector<u8> v(2); memcpy(v.data(), &i, 2); return v; };
    auto f80b = [](long double d) { std::vector<u8> v(10); memcpy(v.data(), &d, 10); return v; };
    auto pad = [](std::vector<u8> v, size_t n) { v.resize(n, 0); return v; };
    auto join = [](std::initializer_list<std::vector<u8>> parts) {
      std::vector<u8> v;
      for (auto &p : parts) v.insert(v.end(), p.begin(), p.end());
      return v;
    };
    auto ab = [&](double a, double b) { return join({f64b(a), f64b(b)}); };
    const double qnan = __builtin_nan("");

    const std::vector<u8> FLD_A = {0xDD, 0x07};          // fld qword [rdi]
    const std::vector<u8> FLD_B = {0xDD, 0x47, 0x08};    // fld qword [rdi+8]
    const std::vector<u8> FSTP_16 = {0xDD, 0x5F, 0x10};  // fstp qword [rdi+16]
    const std::vector<u8> FSTP_24 = {0xDD, 0x5F, 0x18};
    const std::vector<u8> FSTP_32 = {0xDD, 0x5F, 0x20};
    const std::vector<u8> FLD1 = {0xD9, 0xE8};
    const std::vector<u8> FNSTSW_AX = {0xDF, 0xE0};

    ArchState s;
    s.rdi = DATA_ADDR;

    auto add_ud = [&](const std::string &name, std::vector<u8> code) {
      TestCase tc;
      tc.name = name;
      tc.category = cat;
      tc.code = std::move(code);
      tc.initial = s;
      tc.flags_mask = FL_ALL;
      tc.expect_fault = true;
      tc.expected_vector = 6;
      tests.push_back(std::move(tc));
    };

    cat = "x87 reg";
    {
      // D8 C0+i..F8+i: ST(0) := ST(0) op ST(i)
      struct { const char *name; u8 modrm; } d8[] = {
        {"fadd st(0),st(1)", 0xC1}, {"fmul st(0),st(1)", 0xC9},
        {"fsub st(0),st(1)", 0xE1}, {"fsubr st(0),st(1)", 0xE9},
        {"fdiv st(0),st(1)", 0xF1}, {"fdivr st(0),st(1)", 0xF9},
      };
      for (auto &op : d8)
        add_mem(std::string("fld a; fld b; ") + op.name + "; fstp; fstp",
                join({FLD_A, FLD_B, {0xD8, op.modrm}, FSTP_16, FSTP_24}),
                s, FL_ALL, ab(3.0, 1.5), 32);
      // ST(2) as the source: after fld a; fld b; fld1, ST(2) = a
      add_mem("fld a; fld b; fld1; fadd st(0),st(2); fstp x3",
              join({FLD_A, FLD_B, FLD1, {0xD8, 0xC2}, FSTP_16, FSTP_24, FSTP_32}),
              s, FL_ALL, ab(3.0, 1.5), 40);
      add_mem("fld a; fld b; fld1; fdivr st(0),st(2); fstp x3",
              join({FLD_A, FLD_B, FLD1, {0xD8, 0xFA}, FSTP_16, FSTP_24, FSTP_32}),
              s, FL_ALL, ab(3.0, 1.5), 40);

      // DC C0+i..F8+i: ST(i) := ST(i) op ST(0); the SUB and DIV pairs are
      // reversed relative to D8 (DC E0+i is FSUBR, DC E8+i is FSUB)
      struct { const char *name; u8 modrm; } dc[] = {
        {"fadd st(1),st(0)", 0xC1}, {"fmul st(1),st(0)", 0xC9},
        {"fsubr st(1),st(0)", 0xE1}, {"fsub st(1),st(0)", 0xE9},
        {"fdivr st(1),st(0)", 0xF1}, {"fdiv st(1),st(0)", 0xF9},
      };
      for (auto &op : dc)
        add_mem(std::string("fld a; fld b; ") + op.name + "; fstp; fstp",
                join({FLD_A, FLD_B, {0xDC, op.modrm}, FSTP_16, FSTP_24}),
                s, FL_ALL, ab(3.0, 1.5), 32);
      add_mem("fld a; fld b; fld1; fsub st(2),st(0); fstp x3",
              join({FLD_A, FLD_B, FLD1, {0xDC, 0xEA}, FSTP_16, FSTP_24, FSTP_32}),
              s, FL_ALL, ab(3.0, 1.5), 40);

      // DE E8+i FSUBP and DE F0+i FDIVRP: ST(i) := ST(i) - ST(0) / ST(0) / ST(i), pop
      add_mem("fld a; fld b; fsubp st(1),st(0); fstp",
              join({FLD_A, FLD_B, {0xDE, 0xE9}, FSTP_16}), s, FL_ALL, ab(3.0, 1.5), 24);
      add_mem("fld a; fld b; fdivrp st(1),st(0); fstp",
              join({FLD_A, FLD_B, {0xDE, 0xF1}, FSTP_16}), s, FL_ALL, ab(3.0, 1.5), 24);
      add_mem("fld a; fld b; fld1; fsubp st(2),st(0); fstp; fstp",
              join({FLD_A, FLD_B, FLD1, {0xDE, 0xEA}, FSTP_16, FSTP_24}),
              s, FL_ALL, ab(3.0, 1.5), 32);
      add_mem("fld a; fld b; fld1; fdivrp st(2),st(0); fstp; fstp",
              join({FLD_A, FLD_B, FLD1, {0xDE, 0xF2}, FSTP_16, FSTP_24}),
              s, FL_ALL, ab(4.0, 1.5), 32);

      // DE D9 FCOMPP and DA E9 FUCOMPP: condition codes, two pops
      struct { const char *rel; double a, b; } cmps[] = {
        {"lt", 3.0, 1.5}, {"eq", 3.0, 3.0}, {"gt", 1.5, 3.0},
      };
      for (auto &c : cmps) {
        add_mem(std::string("fld a; fld b; fcompp; fnstsw ax (b ") + c.rel + " a)",
                join({FLD_A, FLD_B, {0xDE, 0xD9}, FNSTSW_AX}), s, FL_ALL, ab(c.a, c.b), 0);
        add_mem(std::string("fld a; fld b; fucompp; fnstsw ax (b ") + c.rel + " a)",
                join({FLD_A, FLD_B, {0xDA, 0xE9}, FNSTSW_AX}), s, FL_ALL, ab(c.a, c.b), 0);
      }
      add_mem("fld a; fld qnan; fucompp; fnstsw ax (unordered)",
              join({FLD_A, FLD_B, {0xDA, 0xE9}, FNSTSW_AX}), s, FL_ALL, ab(3.0, qnan), 0);

      // DA D0+i FCMOVBE, DA D8+i FCMOVU, DB C8+i FCMOVNE, DB D0+i FCMOVNBE,
      // DB D8+i FCMOVNU: ST(0) := ST(1) when the condition holds
      struct { const char *name; u8 op, modrm; u64 flags; bool taken; } moves[] = {
        {"fcmovbe", 0xDA, 0xD1, FL_CF, true}, {"fcmovbe", 0xDA, 0xD1, FL_ZF, true},
        {"fcmovbe", 0xDA, 0xD1, 0, false},
        {"fcmovu", 0xDA, 0xD9, FL_PF, true}, {"fcmovu", 0xDA, 0xD9, 0, false},
        {"fcmovne", 0xDB, 0xC9, 0, true}, {"fcmovne", 0xDB, 0xC9, FL_ZF, false},
        {"fcmovnbe", 0xDB, 0xD1, 0, true}, {"fcmovnbe", 0xDB, 0xD1, FL_CF, false},
        {"fcmovnbe", 0xDB, 0xD1, FL_ZF, false},
        {"fcmovnu", 0xDB, 0xD9, 0, true}, {"fcmovnu", 0xDB, 0xD9, FL_PF, false},
      };
      for (auto &m : moves) {
        ArchState f = s;
        f.rflags = initial_flags(FL_CF | FL_ZF | FL_PF, m.flags);
        add_mem(std::format("fld a; fld b; {} st(0),st(1); fstp ({}, flags {:#x})",
                            m.name, m.taken ? "taken" : "not taken", m.flags),
                join({FLD_A, FLD_B, {m.op, m.modrm}, FSTP_16}), f, FL_ALL, ab(3.0, 1.5), 24);
      }

      // DB F0+i FCOMI: ZF, PF, CF from the comparison
      for (auto &c : cmps)
        add_mem(std::string("fld a; fld b; fcomi st(0),st(1) (b ") + c.rel + " a)",
                join({FLD_A, FLD_B, {0xDB, 0xF1}}), s, FL_ALL, ab(c.a, c.b), 0);
      add_mem("fld a; fld qnan; fcomi st(0),st(1) (unordered)",
              join({FLD_A, FLD_B, {0xDB, 0xF1}}), s, FL_ALL, ab(3.0, qnan), 0);

      // D9 C0+i FLD ST(i), DD D0+i FST ST(i), DD C0+i FFREE ST(i), D9 D0 FNOP
      add_mem("fld a; fld b; fld st(1); fstp x3",
              join({FLD_A, FLD_B, {0xD9, 0xC1}, FSTP_16, FSTP_24, FSTP_32}),
              s, FL_ALL, ab(3.0, 1.5), 40);
      add_mem("fld a; fld b; fst st(1); fstp; fstp",
              join({FLD_A, FLD_B, {0xDD, 0xD1}, FSTP_16, FSTP_24}), s, FL_ALL, ab(3.0, 1.5), 32);
      add_mem("fld a; fld b; fst st(2) (empty register); fstp x3",
              join({FLD_A, FLD_B, {0xDD, 0xD2}, FSTP_16, FSTP_24, FSTP_32}),
              s, FL_ALL, ab(3.0, 1.5), 40);
      // FXAM classifies the freed register as empty, with C1 its sign
      add_mem("fld a; fld b; ffree st(0); fxam; fnstsw ax",
              join({FLD_A, FLD_B, {0xDD, 0xC0, 0xD9, 0xE5}, FNSTSW_AX}),
              s, FL_ALL, ab(3.0, -1.5), 0);
      add_mem("fld a; fld b; ffree st(1); fincstp; fxam; fnstsw ax",
              join({FLD_A, FLD_B, {0xDD, 0xC1, 0xD9, 0xF7, 0xD9, 0xE5}, FNSTSW_AX}),
              s, FL_ALL, ab(-3.0, 1.5), 0);
      add_mem("fld a; fnop; fstp", join({FLD_A, {0xD9, 0xD0}, FSTP_16}),
              s, FL_ALL, ab(3.0, 1.5), 24);
    }

    cat = "x87 mem";
    {
      // FCOM/FCOMP m32fp (D8 /2 /3), m64fp (DC /2 /3), FICOM/FICOMP m32int
      // (DA /2 /3), m16int (DE /2 /3): ST(0) = 3.0 against [rdi+8]
      struct { const char *rel; double b; } rels[] = {{"gt", 1.5}, {"eq", 3.0}, {"lt", 4.5}};
      struct { const char *name; u8 op, modrm; int kind; } cmps[] = {
        {"fcom m32", 0xD8, 0x57, 32}, {"fcomp m32", 0xD8, 0x5F, 32},
        {"fcom m64", 0xDC, 0x57, 64}, {"fcomp m64", 0xDC, 0x5F, 64},
        {"ficom m32int", 0xDA, 0x57, 132}, {"ficomp m32int", 0xDA, 0x5F, 132},
        {"ficom m16int", 0xDE, 0x57, 116}, {"ficomp m16int", 0xDE, 0x5F, 116},
      };
      for (auto &c : cmps)
        for (auto &r : rels) {
          std::vector<u8> src = c.kind == 32 ? f32b((float)r.b) : c.kind == 64 ? f64b(r.b)
                              : c.kind == 132 ? i32b((int32_t)r.b) : i16b((int16_t)r.b);
          add_mem(std::string("fld a; ") + c.name + " [rdi+8]; fnstsw ax (a " + r.rel + " b)",
                  join({FLD_A, {c.op, c.modrm, 0x08}, FNSTSW_AX}), s, FL_ALL,
                  join({f64b(3.0), src}), 0);
        }

      // The remaining arithmetic memory forms: ST(0) op [rdi+8] -> [rdi+16]
      struct { const char *name; u8 op, modrm; int kind; } ariths[] = {
        {"fisubr m32int", 0xDA, 0x6F, 132}, {"fidivr m32int", 0xDA, 0x7F, 132},
        {"fimul m16int", 0xDE, 0x4F, 116}, {"fisub m16int", 0xDE, 0x67, 116},
        {"fisubr m16int", 0xDE, 0x6F, 116}, {"fidiv m16int", 0xDE, 0x77, 116},
        {"fidivr m16int", 0xDE, 0x7F, 116},
        {"fsubr m64", 0xDC, 0x6F, 64}, {"fdivr m64", 0xDC, 0x7F, 64},
      };
      for (auto &c : ariths) {
        std::vector<u8> src = c.kind == 64 ? f64b(12.0) : c.kind == 132 ? i32b(12) : i16b(12);
        add_mem(std::string("fld 3.0; ") + c.name + " [rdi+8] = 12; fstp",
                join({FLD_A, {c.op, c.modrm, 0x08}, FSTP_16}), s, FL_ALL,
                pad(join({f64b(3.0), src}), 16), 24);
        src = c.kind == 64 ? f64b(-0.5) : c.kind == 132 ? i32b(-7) : i16b(-7);
        add_mem(std::string("fld -1.5; ") + c.name + " [rdi+8] negative; fstp",
                join({FLD_A, {c.op, c.modrm, 0x08}, FSTP_16}), s, FL_ALL,
                pad(join({f64b(-1.5), src}), 16), 24);
      }

      // D9 /2 FST m32fp and DD /2 FST m64fp keep ST(0); a pop follows
      for (double v : {1.5, -2.25, 0.1})
        add_mem(std::format("fld {}; fst m32 [rdi+8]; fstp", v),
                join({FLD_A, {0xD9, 0x57, 0x08}, FSTP_16}), s, FL_ALL, f64b(v), 24);
      for (float v : {2.5f, -7.75f})
        add_mem(std::format("fld m32 {}; fst m64 [rdi+8]; fstp", v),
                join({{0xD9, 0x07}, {0xDD, 0x57, 0x08}, FSTP_16}), s, FL_ALL, f32b(v), 24);
      // DB /2 FIST m32int rounds to nearest even and keeps ST(0)
      for (double v : {2.5, 3.5, -2.5, 1234567.0})
        add_mem(std::format("fld {}; fist m32int [rdi+8]; fstp", v),
                join({FLD_A, {0xDB, 0x57, 0x08}, FSTP_16}), s, FL_ALL, f64b(v), 24);
      // DF /3 FISTP m16int
      for (double v : {1234.5, -7.5, 32767.0, -32768.0})
        add_mem(std::format("fld {}; fistp m16int [rdi+8]", v),
                join({FLD_A, {0xDF, 0x5F, 0x08}}), s, FL_ALL, f64b(v), 10);
      // DB /5 FLD m80fp and DB /7 FSTP m80fp
      for (long double v : {1.5L, -3.75L, 1.0L / 3.0L})
        add_mem(std::format("fld m80 {}; fstp m64", (double)v),
                join({{0xDB, 0x2F}, FSTP_16}), s, FL_ALL, f80b(v), 24);
      for (double v : {1.5, -3.75, 0.1})
        add_mem(std::format("fld {}; fstp m80 [rdi+16]", v),
                join({FLD_A, {0xDB, 0x7F, 0x10}}), s, FL_ALL, f64b(v), 26);
      // DF /6 FBSTP m80bcd: 18 packed digits and a sign byte, rounded first
      for (double v : {123456789.0, -42.0, 2.5, 3.5, 0.0})
        add_mem(std::format("fld {}; fbstp [rdi+8]", v),
                join({FLD_A, {0xDF, 0x77, 0x08}}), s, FL_ALL, f64b(v), 18);
      // DD /7 FNSTSW m16
      add_mem("fld a; fld b; fnstsw m16 [rdi+16]",
              join({FLD_A, FLD_B, {0xDD, 0x7F, 0x10}}), s, FL_ALL, ab(3.0, 1.5), 18);
    }

    cat = "x87 env";
    {
      // D9 /5 FLDCW, read back with FNSTCW after FRNDINT, which rounds per
      // the RC field (SDM FRNDINT).
      struct { double v; u16 cw; const char *rc; } rcs[] = {
        {2.7, 0x037F, "nearest"}, {2.5, 0x037F, "nearest even"}, {-2.5, 0x037F, "nearest even, negative"},
        {2.7, 0x077F, "down"}, {-2.7, 0x077F, "down, negative"}, {2.5, 0x077F, "down, tie"},
        {2.2, 0x0B7F, "up"}, {-2.2, 0x0B7F, "up, negative"}, {-2.5, 0x0B7F, "up, tie"},
        {2.7, 0x0F7F, "toward zero"}, {-2.7, 0x0F7F, "toward zero, negative"},
      };
      for (auto &r : rcs)
        add_mem(std::format("fldcw {:#06x} ({}); fld {}; frndint; fstp; fnstcw", r.cw, r.rc, r.v),
                join({{0xD9, 0x6F, 0x08}, FLD_A, {0xD9, 0xFC}, FSTP_16, {0xD9, 0x7F, 0x18}}),
                s, FL_ALL, pad(join({f64b(r.v), i16b((int16_t)r.cw)}), 16), 26);
      // The precision-control field rounds the significand of FADD, FSUB,
      // FMUL, FDIV and FSQRT results to 24 or 53 bits (SDM Vol.1 §8.1.5.2);
      // stored as binary64, the 24-bit results show trailing zeros.
      add_mem("fldcw 0x027f (double precision); fld1; fld 3; fdivp; fstp",
              join({{0xD9, 0x6F, 0x08}, FLD1, FLD_A, {0xDE, 0xF9}, FSTP_16}),
              s, FL_ALL, pad(join({f64b(3.0), i16b(0x027F)}), 16), 24);
      add_mem("fldcw 0x007f (single precision); fld1; fld 3; fdivp; fstp",
              join({{0xD9, 0x6F, 0x08}, FLD1, FLD_A, {0xDE, 0xF9}, FSTP_16}),
              s, FL_ALL, pad(join({f64b(3.0), i16b(0x007F)}), 16), 24);
      add_mem("fldcw 0x007f (single precision); fld 1.1; fld 1.1; fmulp; fstp",
              join({{0xD9, 0x6F, 0x08}, FLD_A, FLD_A, {0xDE, 0xC9}, FSTP_16}),
              s, FL_ALL, pad(join({f64b(1.1), i16b(0x007F)}), 16), 24);
      add_mem("fldcw 0x007f (single precision); fld 2; fsqrt; fstp",
              join({{0xD9, 0x6F, 0x08}, FLD_A, {0xD9, 0xFA}, FSTP_16}),
              s, FL_ALL, pad(join({f64b(2.0), i16b(0x007F)}), 16), 24);
      add_mem("fldcw 0x007f (single precision); fld 0.1; fld 0.2; faddp; fstp",
              join({{0xD9, 0x6F, 0x10}, FLD_A, FLD_B, {0xDE, 0xC1}, FSTP_24}),
              s, FL_ALL, pad(join({ab(0.1, 0.2), i16b(0x007F)}), 24), 32);
      // FST/FSTP m32fp and m64fp round per the RC field as well
      for (u16 cw : {0x077F, 0x0B7F, 0x0F7F})
        add_mem(std::format("fldcw {:#06x}; fld 0.1; fld 0.2; faddp; fstp m64 (rounded per RC)", cw),
                join({{0xD9, 0x6F, 0x10}, FLD_A, FLD_B, {0xDE, 0xC1}, FSTP_24}),
                s, FL_ALL, pad(join({ab(0.1, 0.2), i16b((int16_t)cw)}), 24), 32);
      for (u16 cw : {0x037F, 0x077F, 0x0B7F, 0x0F7F})
        add_mem(std::format("fldcw {:#06x}; fld 0.1; fstp m32 (rounded per RC)", cw),
                join({{0xD9, 0x6F, 0x08}, FLD_A, {0xD9, 0x5F, 0x10}}),
                s, FL_ALL, pad(join({f64b(0.1), i16b((int16_t)cw)}), 16), 20);
      add_mem("fldcw 0x0c7f (single precision, toward zero); fld1; fld 3; fdivp; fstp",
              join({{0xD9, 0x6F, 0x08}, FLD1, FLD_A, {0xDE, 0xF9}, FSTP_16}),
              s, FL_ALL, pad(join({f64b(3.0), i16b(0x0C7F)}), 16), 24);
      // Integer stores of values outside the destination's range, of NaN
      // and of infinity store the integer indefinite 100..00B when #IA is
      // masked (SDM FIST/FISTP and FISTTP; Vol.1 §8.2.1).
      for (double v : {70000.0, -40000.0, 3.0e9, -3.0e9, 1.0e19, -1.0e19, qnan, __builtin_inf(), -__builtin_inf()}) {
        add_mem(std::format("fld {}; fistp m16int [rdi+8]", v),
                join({FLD_A, {0xDF, 0x5F, 0x08}}), s, FL_ALL, f64b(v), 10);
        add_mem(std::format("fld {}; fistp m32int [rdi+8]", v),
                join({FLD_A, {0xDB, 0x5F, 0x08}}), s, FL_ALL, f64b(v), 12);
        add_mem(std::format("fld {}; fistp m64int [rdi+8]", v),
                join({FLD_A, {0xDF, 0x7F, 0x08}}), s, FL_ALL, f64b(v), 16);
        add_mem(std::format("fld {}; fisttp m16int [rdi+8]", v),
                join({FLD_A, {0xDF, 0x4F, 0x08}}), s, FL_ALL, f64b(v), 10);
        add_mem(std::format("fld {}; fisttp m32int [rdi+8]", v),
                join({FLD_A, {0xDB, 0x4F, 0x08}}), s, FL_ALL, f64b(v), 12);
        add_mem(std::format("fld {}; fisttp m64int [rdi+8]", v),
                join({FLD_A, {0xDD, 0x4F, 0x08}}), s, FL_ALL, f64b(v), 16);
      }
      // In-range values just inside the limits, rounded per RC or truncated
      for (double v : {32767.4, -32768.4, 2147483647.4, -2147483648.4, 9.0e18, -9.0e18}) {
        add_mem(std::format("fld {}; fistp m16int [rdi+8] (in range?)", v),
                join({FLD_A, {0xDF, 0x5F, 0x08}}), s, FL_ALL, f64b(v), 10);
        add_mem(std::format("fld {}; fistp m32int [rdi+8] (in range?)", v),
                join({FLD_A, {0xDB, 0x5F, 0x08}}), s, FL_ALL, f64b(v), 12);
        add_mem(std::format("fld {}; fisttp m64int [rdi+8] (in range?)", v),
                join({FLD_A, {0xDD, 0x4F, 0x08}}), s, FL_ALL, f64b(v), 16);
      }

      // D9 /6 FNSTENV, 32-bit protected-mode layout at [rdi+8].  The control,
      // status, and tag words are read through GPRs: the pointer fields are
      // not modeled, and the upper halves of the first three doublewords are
      // reserved in the SDM's Figure 8-9.
      const std::vector<u8> ENV_WORDS = {
        0x0F, 0xB7, 0x47, 0x08,  // movzx eax, word [rdi+8]   (FCW)
        0x0F, 0xB7, 0x5F, 0x0C,  // movzx ebx, word [rdi+12]  (FSW)
        0x0F, 0xB7, 0x4F, 0x10,  // movzx ecx, word [rdi+16]  (FTW)
      };
      add_mem("fld a; fld b; fnstenv [rdi+8]; read FCW/FSW/FTW",
              join({FLD_A, FLD_B, {0xD9, 0x77, 0x08}, ENV_WORDS}), s, FL_ALL, ab(3.0, 1.5), 0);
      add_mem("fld a; fld b; fstp st(1); fnstenv [rdi+8]; read FCW/FSW/FTW",
              join({FLD_A, FLD_B, {0xDD, 0xD9, 0xD9, 0x77, 0x08}, ENV_WORDS}),
              s, FL_ALL, ab(3.0, 1.5), 0);
      // The tag word classifies each non-empty register (SDM Vol.1 §8.1.7,
      // Figure 8-7): valid, zero, special (infinity, NaN, denormal), empty.
      // FST ST(i) into an empty register makes it non-empty.
      add_mem("fldz; fnstenv [rdi+8]; read FTW (zero tag)",
              join({{0xD9, 0xEE}, {0xD9, 0x77, 0x08}, ENV_WORDS}), s, FL_ALL, ab(3.0, 1.5), 0);
      add_mem("fld inf; fld nan; fldz; fld a; fnstenv [rdi+8]; read FTW (special tags)",
              join({FLD_B, {0xDD, 0x47, 0x10}, {0xD9, 0xEE}, FLD_A, {0xD9, 0x77, 0x08}, ENV_WORDS}),
              s, FL_ALL, join({f64b(3.0), f64b(__builtin_inf()), f64b(qnan)}), 0);
      add_mem("fld a; fld b; fst st(3); fnstenv [rdi+8]; read FTW (FST marks non-empty)",
              join({FLD_A, FLD_B, {0xDD, 0xD3}, {0xD9, 0x77, 0x08}, ENV_WORDS}), s, FL_ALL, ab(3.0, 1.5), 0);
      add_mem("fld a; fld b; ffree st(1); fnstenv [rdi+8]; read FTW",
              join({FLD_A, FLD_B, {0xDD, 0xC1}, {0xD9, 0x77, 0x08}, ENV_WORDS}), s, FL_ALL, ab(3.0, 1.5), 0);

      // DD /6 FNSAVE writes the 108-byte state image and reinitializes the
      // FPU; DD /4 FRSTOR loads one.  The registers follow the 28-byte
      // environment in stack order, ST(0) first (SDM FSAVE/FNSAVE and
      // FRSTOR, Operation).  The image goes to [rdi+0x100]; its control,
      // status and tag words are read into GPRs and its 80 register bytes
      // are copied to [rdi] for comparison, since the pointer fields are not
      // modeled.
      {
        const std::vector<u8> SAVE_AND_COPY = {
          0xDD, 0xB7, 0x00, 0x01, 0x00, 0x00,        // fnsave [rdi+0x100]
          0x0F, 0xB7, 0x87, 0x00, 0x01, 0x00, 0x00,  // movzx eax, word [rdi+0x100]  (FCW)
          0x0F, 0xB7, 0x9F, 0x04, 0x01, 0x00, 0x00,  // movzx ebx, word [rdi+0x104]  (FSW)
          0x0F, 0xB7, 0x97, 0x08, 0x01, 0x00, 0x00,  // movzx edx, word [rdi+0x108]  (FTW)
          0x48, 0x8D, 0xB7, 0x1C, 0x01, 0x00, 0x00,  // lea rsi, [rdi+0x11c]        (ST(0) image)
          0xB9, 0x50, 0x00, 0x00, 0x00,              // mov ecx, 80
          0xF3, 0xA4,                                // rep movsb
        };
        add_mem("fld a; fld b; fnsave [rdi+0x100]; read FCW/FSW/FTW and the registers",
                join({FLD_A, FLD_B, SAVE_AND_COPY}), s, FL_ALL, ab(3.0, 1.5), 80);
        add_mem("fld a; fld b; fld1; fst st(4); fnsave [rdi+0x100]; read the image",
                join({FLD_A, FLD_B, FLD1, {0xDD, 0xD4}, SAVE_AND_COPY}), s, FL_ALL, ab(3.0, 1.5), 80);
        add_mem("fldz; fnsave [rdi+0x100]; fnstsw ax after (reinitialized); read the image",
                join({{0xD9, 0xEE}, SAVE_AND_COPY}), s, FL_ALL, {}, 80);
        // FRSTOR of a built image: TOP = 6, ST(0) = 1.5, ST(1) = -3.75, the
        // rest empty; observed through FNSTSW and two pops
        std::vector<u8> image(108, 0);
        u16 cw = 0x037F, sw = 0x3000, tw = 0x0FFF;
        memcpy(&image[0], &cw, 2);
        memcpy(&image[4], &sw, 2);
        memcpy(&image[8], &tw, 2);
        auto st0 = f80b(1.5L), st1 = f80b(-3.75L);
        memcpy(&image[28], st0.data(), 10);
        memcpy(&image[38], st1.data(), 10);
        add_mem("frstor [rdi+0x100] (TOP 6); fnstsw ax; fstp [rdi]; fstp [rdi+8]",
                join({{0xDD, 0xA7, 0x00, 0x01, 0x00, 0x00}, FNSTSW_AX, {0xDD, 0x1F}, {0xDD, 0x5F, 0x08}}),
                s, FL_ALL, join({std::vector<u8>(0x100, 0), image}), 16);
        // FNSAVE then FRSTOR restores the stack
        add_mem("fld a; fld b; fnsave; frstor; fnstsw ax; fstp [rdi+16]; fstp [rdi+24]",
                join({FLD_A, FLD_B, {0xDD, 0xB7, 0x00, 0x01, 0x00, 0x00}, {0xDD, 0xA7, 0x00, 0x01, 0x00, 0x00},
                      FNSTSW_AX, FSTP_16, FSTP_24}), s, FL_ALL, ab(3.0, 1.5), 32);
      }
      // FNSTENV then masks all exceptions in the control word
      add_mem("fldcw 0x0340; fnstenv [rdi+16]; fnstcw [rdi+48]; read both control words",
              join({{0xD9, 0x6F, 0x08}, {0xD9, 0x77, 0x10}, {0xD9, 0x7F, 0x30},
                    {0x0F, 0xB7, 0x47, 0x10,     // movzx eax, word [rdi+16] (image FCW)
                     0x0F, 0xB7, 0x5F, 0x30}}),  // movzx ebx, word [rdi+48] (FCW after)
              s, FL_ALL, pad(join({f64b(0), i16b(0x0340)}), 16), 0);

      // D9 /4 FLDENV: RC = truncate, TOP = 5 with C3 and ZE set, all registers
      // empty; observed through FNSTSW, FNSTCW, and a load/store at the new TOP
      {
        std::vector<u8> env(28, 0);
        u16 cw = 0x0F7F, sw = 0x6804, tw = 0xFFFF;
        memcpy(&env[0], &cw, 2);
        memcpy(&env[4], &sw, 2);
        memcpy(&env[8], &tw, 2);
        add_mem("fldenv [rdi+8]; fnstsw ax; fnstcw [rdi+40]; fld a; fstp [rdi+48]",
                join({{0xD9, 0x67, 0x08}, FNSTSW_AX, {0xD9, 0x7F, 0x28}, FLD_A, {0xDD, 0x5F, 0x30}}),
                s, FL_ALL, join({f64b(2.7), env}), 56);
      }
    }

    // Reserved x87 encodings raise #UD.  Not included: DC D0+i, DC D8+i,
    // DD C8+i, and DE D0+i (i != 1), which the SDM leaves blank but the
    // processors execute as aliases of FCOM, FCOMP, FXCH, and FCOMP.
    cat = "x87 invalid";
    {
      add_ud("d9 /1 mem (reserved)", {0xD9, 0x0F});
      add_ud("db /4 mem (reserved)", {0xDB, 0x27});
      add_ud("db /6 mem (reserved)", {0xDB, 0x37});
      add_ud("dd /5 mem (reserved)", {0xDD, 0x2F});
      add_ud("d9 d1 (reserved)", {0xD9, 0xD1});
      add_ud("db f8 (reserved)", {0xDB, 0xF8});
      add_ud("dd f1 (reserved)", {0xDD, 0xF1});
      add_ud("dd f9 (reserved)", {0xDD, 0xF9});
      add_ud("de d8 (reserved)", {0xDE, 0xD8});
    }
  }
}


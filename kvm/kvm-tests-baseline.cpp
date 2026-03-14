#include "kvm-harness.h"

void add_baseline_tests(std::vector<TestCase> &tests) {
  std::string cat;

  auto add = [&](const std::string &name, std::vector<u8> code, ArchState init,
                 u64 mask = FL_ALL) {
    tests.push_back({name, cat, std::move(code), init, mask});
  };

  auto add_mem = [&](const std::string &name, std::vector<u8> code, ArchState init,
                     u64 mask, std::vector<u8> data, size_t cmp_len) {
    tests.push_back({name, cat, std::move(code), init, mask, 0, false, std::move(data), cmp_len});
  };

  // =====================================================================
  // 1. ALU reg,reg — all 8 operations at 64-bit
  //    Exercises: exec_add_reg_reg, exec_or, exec_adc_reg_reg, exec_sbb_reg_reg,
  //    exec_and, exec_sub, exec_xor, exec_cmp through decode_alu.sail
  // =====================================================================
  cat = "Baseline/ALU reg,reg";
  ArchState alu = {};
  alu.rax = 0x0000000000000037;  // 55
  alu.rbx = 0x000000000000001E;  // 30
  alu.rcx = 7;
  alu.rflags = 0x2;

  // op RAX, RBX (64-bit): REX.W=48, opcode, ModRM=D8 (mod=11,reg=rbx,rm=rax)
  add("add rax,rbx",  {0x48, 0x01, 0xD8}, alu);
  add("or rax,rbx",   {0x48, 0x09, 0xD8}, alu);
  add("and rax,rbx",  {0x48, 0x21, 0xD8}, alu);
  add("sub rax,rbx",  {0x48, 0x29, 0xD8}, alu);
  add("xor rax,rbx",  {0x48, 0x31, 0xD8}, alu);
  add("cmp rax,rbx",  {0x48, 0x39, 0xD8}, alu);

  // ADC/SBB need CF set to exercise the carry-in path
  ArchState alu_cf = alu;
  alu_cf.rflags = 0x3;  // CF=1
  add("adc rax,rbx cf=1",  {0x48, 0x11, 0xD8}, alu_cf);
  add("sbb rax,rbx cf=1",  {0x48, 0x19, 0xD8}, alu_cf);

  // ADC/SBB with CF=0
  add("adc rax,rbx cf=0",  {0x48, 0x11, 0xD8}, alu);
  add("sbb rax,rbx cf=0",  {0x48, 0x19, 0xD8}, alu);

  // =====================================================================
  // 2. ALU operand sizes — exercises all 4 OperandSize branches
  //    32-bit should zero-extend upper 32 bits of dest.
  //    16-bit and 8-bit should preserve upper bits.
  // =====================================================================
  cat = "Baseline/ALU operand sizes";
  ArchState sz = {};
  sz.rax = 0xFFFFFFFF00000005;
  sz.rbx = 0xFFFFFFFF00000003;
  sz.rflags = 0x2;

  // ADD EAX, EBX (32-bit, no REX.W): zeroes upper 32 bits
  add("add eax,ebx (32)",  {0x01, 0xD8}, sz);
  // ADD AX, BX (16-bit, 66h prefix): preserves upper 48 bits
  add("add ax,bx (16)",    {0x66, 0x01, 0xD8}, sz);
  // ADD AL, BL (8-bit): preserves upper 56 bits
  add("add al,bl (8)",     {0x00, 0xD8}, sz);

  // SUB in different sizes
  add("sub eax,ebx (32)",  {0x29, 0xD8}, sz);
  add("sub ax,bx (16)",    {0x66, 0x29, 0xD8}, sz);
  add("sub al,bl (8)",     {0x28, 0xD8}, sz);

  // AND/OR/XOR at 32-bit (test zero-extension)
  add("and eax,ebx (32)",  {0x21, 0xD8}, sz);
  add("or eax,ebx (32)",   {0x09, 0xD8}, sz);
  add("xor eax,ebx (32)",  {0x31, 0xD8}, sz);

  // =====================================================================
  // 3. ALU reg,imm — exercises immediate operand fetch paths
  //    Group 1: 83 /op imm8 (sign-extended), 81 /op imm32
  // =====================================================================
  cat = "Baseline/ALU reg,imm";
  ArchState imm = {};
  imm.rax = 100;
  imm.rflags = 0x2;

  // ADD RAX, imm8:  48 83 C0 imm8 (ModRM=C0: /0=ADD, rm=rax)
  add("add rax,imm8",   {0x48, 0x83, 0xC0, 0x2A}, imm);  // +42
  // SUB RAX, imm8:  48 83 E8 imm8 (ModRM=E8: /5=SUB, rm=rax)
  add("sub rax,imm8",   {0x48, 0x83, 0xE8, 0x0A}, imm);  // -10
  // AND RAX, imm8:  48 83 E0 imm8 (ModRM=E0: /4=AND, rm=rax)
  add("and rax,imm8",   {0x48, 0x83, 0xE0, 0x0F}, imm);  // & 0xF
  // XOR RAX, imm8:  48 83 F0 imm8 (ModRM=F0: /6=XOR, rm=rax)
  add("xor rax,imm8",   {0x48, 0x83, 0xF0, 0xFF}, imm);  // ^ (-1)
  // CMP RAX, imm8:  48 83 F8 imm8 (ModRM=F8: /7=CMP, rm=rax)
  add("cmp rax,imm8",   {0x48, 0x83, 0xF8, 0x64}, imm);  // cmp 100
  // ADC RAX, imm8 with CF=1:
  ArchState imm_cf = imm;
  imm_cf.rflags = 0x3;
  add("adc rax,imm8 cf=1", {0x48, 0x83, 0xD0, 0x05}, imm_cf);  // +5+CF
  // SBB RAX, imm8 with CF=1:
  add("sbb rax,imm8 cf=1", {0x48, 0x83, 0xD8, 0x05}, imm_cf);  // -5-CF

  // ADD RAX, imm32:  48 81 C0 imm32 (sign-extended to 64)
  add("add rax,imm32",  {0x48, 0x81, 0xC0, 0x00, 0x01, 0x00, 0x00}, imm);  // +256

  // Negative imm8 (sign extension): ADD RAX, -1
  add("add rax,-1 (imm8)", {0x48, 0x83, 0xC0, 0xFF}, imm);  // +(-1)

  // =====================================================================
  // 4. ALU corner cases — overflow, zero, MAX/MIN
  // =====================================================================
  cat = "Baseline/ALU corner cases";
  ArchState ov = {};
  ov.rflags = 0x2;

  // Signed overflow: MAX + 1
  ov.rax = 0x7FFFFFFFFFFFFFFF;
  ov.rbx = 1;
  add("add signed overflow", {0x48, 0x01, 0xD8}, ov);

  // Unsigned carry: MAX + 1
  ov.rax = 0xFFFFFFFFFFFFFFFF;
  ov.rbx = 1;
  add("add unsigned carry", {0x48, 0x01, 0xD8}, ov);

  // SUB underflow
  ov.rax = 0;
  ov.rbx = 1;
  add("sub underflow", {0x48, 0x29, 0xD8}, ov);

  // XOR self = 0
  ov.rax = 0xDEADBEEFCAFEBABE;
  add("xor rax,rax", {0x48, 0x31, 0xC0}, ov);

  // CMP equal
  ov.rax = 42;
  ov.rbx = 42;
  add("cmp equal", {0x48, 0x39, 0xD8}, ov);

  // CMP less (unsigned)
  ov.rax = 1;
  ov.rbx = 0xFFFFFFFFFFFFFFFF;
  add("cmp less unsigned", {0x48, 0x39, 0xD8}, ov);

  // TEST RAX, RAX (AND without writing result)
  ov.rax = 0;
  add("test zero", {0x48, 0x85, 0xC0}, ov);
  ov.rax = 0x8000000000000000;
  add("test negative", {0x48, 0x85, 0xC0}, ov);
  ov.rax = 1;
  add("test positive", {0x48, 0x85, 0xC0}, ov);

  // =====================================================================
  // 5. Shift operations — exercises all ShiftOp branches
  //    Group 2: D1 /op (by 1), D3 /op (by CL), C1 /op imm8
  //    ModRM reg field: 0=ROL,1=ROR,2=RCL,3=RCR,4=SHL,5=SHR,7=SAR
  // =====================================================================
  cat = "Baseline/Shift operations";
  ArchState sh = {};
  sh.rax = 0x123456789ABCDEF0;
  sh.rcx = 7;
  sh.rflags = 0x3;  // CF=1 (matters for RCL/RCR)

  // --- By CL (count=7 > 1): AF undefined, OF undefined ---
  // REX.W D3 /op: shift RAX by CL
  add("shl rax,cl",  {0x48, 0xD3, 0xE0}, sh, FL_NO_AF_OF);  // /4
  add("shr rax,cl",  {0x48, 0xD3, 0xE8}, sh, FL_NO_AF_OF);  // /5
  add("sar rax,cl",  {0x48, 0xD3, 0xF8}, sh, FL_NO_AF_OF);  // /7
  add("rol rax,cl",  {0x48, 0xD3, 0xC0}, sh, FL_CF);         // /0, only CF defined (SF/ZF/PF unaffected, OF undef)
  add("ror rax,cl",  {0x48, 0xD3, 0xC8}, sh, FL_CF);         // /1
  add("rcl rax,cl",  {0x48, 0xD3, 0xD0}, sh, FL_CF);         // /2
  add("rcr rax,cl",  {0x48, 0xD3, 0xD8}, sh, FL_CF);         // /3

  // --- By 1: OF is defined ---
  // REX.W D1 /op
  add("shl rax,1",  {0x48, 0xD1, 0xE0}, sh, FL_NO_AF);
  add("shr rax,1",  {0x48, 0xD1, 0xE8}, sh, FL_NO_AF);
  add("sar rax,1",  {0x48, 0xD1, 0xF8}, sh, FL_NO_AF);
  add("rol rax,1",  {0x48, 0xD1, 0xC0}, sh, FL_CF | FL_OF);
  add("ror rax,1",  {0x48, 0xD1, 0xC8}, sh, FL_CF | FL_OF);
  add("rcl rax,1",  {0x48, 0xD1, 0xD0}, sh, FL_CF | FL_OF);
  add("rcr rax,1",  {0x48, 0xD1, 0xD8}, sh, FL_CF | FL_OF);

  // --- By imm8: SHL RAX, 4
  add("shl rax,imm4", {0x48, 0xC1, 0xE0, 0x04}, sh, FL_NO_AF_OF);

  // --- Count = 0: no flags modified (all flags should match initial) ---
  ArchState sh0 = sh;
  sh0.rcx = 0;
  add("shl rax,cl=0", {0x48, 0xD3, 0xE0}, sh0, FL_ALL);
  add("rol rax,cl=0", {0x48, 0xD3, 0xC0}, sh0, FL_ALL);

  // --- Different sizes for shifts ---
  ArchState sh32 = {};
  sh32.rax = 0xFFFFFFFF80000001;
  sh32.rcx = 1;
  sh32.rflags = 0x2;
  // SHL EAX, CL (32-bit, no REX.W): should zero-extend upper 32 bits
  add("shl eax,cl (32)", {0xD3, 0xE0}, sh32, FL_NO_AF);
  // SHR EAX, CL (32-bit)
  add("shr eax,cl (32)", {0xD3, 0xE8}, sh32, FL_NO_AF);
  // SAR EAX, CL (32-bit): sign extends within 32 bits, then zero-extends to 64
  add("sar eax,cl (32)", {0xD3, 0xF8}, sh32, FL_NO_AF);

  // 8-bit shift
  ArchState sh8 = {};
  sh8.rax = 0xFF;
  sh8.rcx = 4;
  sh8.rflags = 0x2;
  add("shl al,cl (8)", {0xD2, 0xE0}, sh8, FL_NO_AF_OF);
  add("shr al,cl (8)", {0xD2, 0xE8}, sh8, FL_NO_AF_OF);

  // =====================================================================
  // 6. Multiply — MUL, IMUL (1/2/3-operand forms)
  //    MUL/IMUL 1-op: SF, ZF, AF, PF undefined; only CF, OF defined
  //    IMUL 2/3-op: SF, ZF, AF, PF undefined; only CF, OF defined
  // =====================================================================
  cat = "Baseline/Multiply";
  ArchState mul = {};
  mul.rflags = 0x2;

  // MUL RBX (64-bit): RAX * RBX -> RDX:RAX
  // F7 /4, rm=3(rbx)
  mul.rax = 7;
  mul.rbx = 6;
  add("mul rbx (small)",  {0x48, 0xF7, 0xE3}, mul, FL_CF_OF);

  // MUL with overflow into RDX
  mul.rax = 0xFFFFFFFFFFFFFFFF;
  mul.rbx = 2;
  add("mul rbx (overflow)", {0x48, 0xF7, 0xE3}, mul, FL_CF_OF);

  // MUL 32-bit: EAX * EBX -> EDX:EAX (F7 /4 without REX.W)
  mul.rax = 100000;
  mul.rbx = 100000;
  add("mul ebx (32)", {0xF7, 0xE3}, mul, FL_CF_OF);

  // MUL 8-bit: AL * BL -> AX (F6 /4, rm=3)
  mul.rax = 200;
  mul.rbx = 200;
  add("mul bl (8)", {0xF6, 0xE3}, mul, FL_CF_OF);

  // IMUL 1-operand (signed): RAX * RBX -> RDX:RAX
  // F7 /5
  mul.rax = (u64)(i64)(-7);
  mul.rbx = 6;
  add("imul1 rbx (neg)", {0x48, 0xF7, 0xEB}, mul, FL_CF_OF);

  // IMUL 2-operand: RAX := RAX * RBX (truncated)
  // 0F AF /r (ModRM: mod=11, reg=rax=0, rm=rbx=3 = C3)
  mul.rax = 42;
  mul.rbx = 100;
  add("imul2 rax,rbx", {0x48, 0x0F, 0xAF, 0xC3}, mul, FL_CF_OF);

  // IMUL 3-operand: RAX := RBX * imm8
  // 6B /r imm8 (ModRM: mod=11, reg=rax=0, rm=rbx=3 = C3)
  mul.rbx = 42;
  add("imul3 rax,rbx,imm8", {0x48, 0x6B, 0xC3, 0x0A}, mul, FL_CF_OF);  // *10

  // IMUL 3-operand with imm32: 69 /r imm32
  add("imul3 rax,rbx,imm32", {0x48, 0x69, 0xC3, 0xE8, 0x03, 0x00, 0x00}, mul, FL_CF_OF);  // *1000

  // =====================================================================
  // 7. Divide — DIV, IDIV (all flags undefined)
  // =====================================================================
  cat = "Baseline/Divide";
  ArchState dv = {};
  dv.rflags = 0x2;

  // DIV RBX (64-bit): RDX:RAX / RBX -> RAX=quot, RDX=rem
  dv.rax = 100;
  dv.rdx = 0;
  dv.rbx = 7;
  add("div rbx (64)",  {0x48, 0xF7, 0xF3}, dv, FL_NONE);

  // DIV with nonzero RDX
  dv.rax = 0;
  dv.rdx = 1;  // dividend = 0x10000000000000000 = 2^64
  dv.rbx = 3;
  add("div rbx (large)", {0x48, 0xF7, 0xF3}, dv, FL_NONE);

  // DIV 32-bit: EDX:EAX / EBX -> EAX=quot, EDX=rem
  dv.rax = 1000;
  dv.rdx = 0;
  dv.rbx = 7;
  add("div ebx (32)", {0xF7, 0xF3}, dv, FL_NONE);

  // IDIV RBX (signed)
  dv.rax = (u64)(i64)(-100);
  dv.rdx = 0xFFFFFFFFFFFFFFFF;  // sign extension of negative dividend
  dv.rbx = 7;
  add("idiv rbx (neg)", {0x48, 0xF7, 0xFB}, dv, FL_NONE);

  // IDIV positive
  dv.rax = 100;
  dv.rdx = 0;
  dv.rbx = 7;
  add("idiv rbx (pos)", {0x48, 0xF7, 0xFB}, dv, FL_NONE);

  // IDIV 8-bit: AX / src8 -> AL=quot, AH=rem
  // F6 /7
  dv.rax = 100;  // dividend in AX (low 16 bits)
  dv.rbx = 7;
  add("idiv bl (8)", {0xF6, 0xFB}, dv, FL_NONE);

  // =====================================================================
  // 8. INC/DEC/NEG/NOT — unary operations
  //    INC/DEC: all flags except CF. NEG: all flags. NOT: no flags.
  // =====================================================================
  cat = "Baseline/INC/DEC/NEG/NOT";
  ArchState un = {};
  un.rflags = 0x3;  // CF=1 (INC/DEC should preserve CF)

  un.rax = 42;
  add("inc rax", {0x48, 0xFF, 0xC0}, un);  // FF /0
  add("dec rax", {0x48, 0xFF, 0xC8}, un);  // FF /1
  add("neg rax", {0x48, 0xF7, 0xD8}, un);  // F7 /3
  add("not rax", {0x48, 0xF7, 0xD0}, un, FL_ALL);  // F7 /2, no flag changes

  // INC/DEC corner cases
  un.rax = 0xFFFFFFFFFFFFFFFF;
  add("inc -1", {0x48, 0xFF, 0xC0}, un);  // -1 -> 0
  un.rax = 0;
  add("dec 0", {0x48, 0xFF, 0xC8}, un);   // 0 -> -1
  un.rax = 0x7FFFFFFFFFFFFFFF;
  add("inc max_signed", {0x48, 0xFF, 0xC0}, un);  // overflow

  // NEG 0 (CF should be 0) and NEG MIN (overflow)
  un.rax = 0;
  add("neg 0", {0x48, 0xF7, 0xD8}, un);
  un.rax = 0x8000000000000000;
  add("neg min_signed", {0x48, 0xF7, 0xD8}, un);

  // 32-bit INC (zero-extends)
  un.rax = 0xFFFFFFFF;
  add("inc eax (32)", {0xFF, 0xC0}, un);

  // =====================================================================
  // 9. Conditional operations — SETcc, CMOVcc
  //    Tests all 16 condition codes via eval_cc
  // =====================================================================
  cat = "Baseline/SETcc/CMOVcc";

  // Set up flags to create interesting condition states.
  // State A: CF=1, ZF=0, SF=0, OF=0, PF=0 (carry set, positive nonzero)
  ArchState ccA = {};
  ccA.rax = 0;
  ccA.rbx = 42;
  ccA.rflags = 0x2 | FL_CF;  // CF=1 only

  // State B: CF=0, ZF=1, SF=0, OF=0, PF=1 (zero result)
  ArchState ccB = {};
  ccB.rax = 0;
  ccB.rbx = 42;
  ccB.rflags = 0x2 | FL_ZF | FL_PF;

  // State C: CF=0, ZF=0, SF=1, OF=0 (negative, no overflow)
  ArchState ccC = {};
  ccC.rax = 0;
  ccC.rbx = 42;
  ccC.rflags = 0x2 | FL_SF;

  // State D: CF=0, ZF=0, SF=1, OF=1 (SF!=OF, so L=true but GE=false)
  ArchState ccD = {};
  ccD.rax = 0;
  ccD.rbx = 42;
  ccD.rflags = 0x2 | FL_SF | FL_OF;

  // SETcc AL: 0F 9x C0 (ModRM=C0: /0, rm=rax)
  // Test all 16 condition codes with state A (CF=1)
  static const char *cc_names[] = {"o","no","b","ae","e","ne","be","a",
                                   "s","ns","p","np","l","ge","le","g"};
  std::string ccbuf;

  for (int cc = 0; cc < 16; cc++) {
    ccbuf = std::format("set{} al (cf=1)", cc_names[cc]);
    add(ccbuf, {0x0F, (u8)(0x90 + cc), 0xC0}, ccA, FL_ALL);
  }

  // Test SETcc with state B (ZF=1)
  for (int cc : {4, 5, 6, 7}) {  // E, NE, BE, A — all involve ZF
    ccbuf = std::format("set{} al (zf=1)", cc_names[cc]);
    add(ccbuf, {0x0F, (u8)(0x90 + cc), 0xC0}, ccB, FL_ALL);
  }

  // Test SETcc with state D (SF=1, OF=1 — GE should be true since SF==OF)
  for (int cc : {12, 13, 14, 15}) {  // L, GE, LE, G
    ccbuf = std::format("set{} al (sf=of=1)", cc_names[cc]);
    add(ccbuf, {0x0F, (u8)(0x90 + cc), 0xC0}, ccD, FL_ALL);
  }

  // CMOVcc RAX, RBX (64-bit): 48 0F 4x C3 (ModRM=C3: reg=rax, rm=rbx)
  // Test taken (condition true) and not-taken
  add("cmove rax,rbx (taken)",     {0x48, 0x0F, 0x44, 0xC3}, ccB, FL_ALL);  // ZF=1 → taken
  add("cmove rax,rbx (not taken)", {0x48, 0x0F, 0x44, 0xC3}, ccA, FL_ALL);  // ZF=0 → not taken
  add("cmovb rax,rbx (taken)",     {0x48, 0x0F, 0x42, 0xC3}, ccA, FL_ALL);  // CF=1 → taken
  add("cmovb rax,rbx (not taken)", {0x48, 0x0F, 0x42, 0xC3}, ccB, FL_ALL);  // CF=0 → not taken
  add("cmovl rax,rbx (taken)",     {0x48, 0x0F, 0x4C, 0xC3}, ccC, FL_ALL);  // SF!=OF → taken
  add("cmovl rax,rbx (not taken)", {0x48, 0x0F, 0x4C, 0xC3}, ccD, FL_ALL);  // SF==OF → not taken
  add("cmovg rax,rbx (taken)",     {0x48, 0x0F, 0x4F, 0xC3}, ccA, FL_ALL);  // ZF=0 & SF==OF → taken
  add("cmovg rax,rbx (not taken)", {0x48, 0x0F, 0x4F, 0xC3}, ccB, FL_ALL);  // ZF=1 → not taken

  // =====================================================================
  // 10. Branch — Jcc (tests decode_pos + offset calculation)
  // =====================================================================
  cat = "Baseline/Branch";

  // JE rel8: 74 xx. If taken, skip a MOV instruction.
  // Layout: JE +3 (skip 3 bytes) | MOV EAX,1 (B8 01 00 00 00 = 5 bytes, but
  // we use a 3-byte: XOR EAX,EAX = 31 C0 ... no, let's be precise)
  // JE +2 skips 2 bytes: the next 2-byte instruction (XOR EAX,EAX) is skipped.
  //
  // Code: 74 02 | 48 FF C0 (INC RAX) | [HLT auto-appended]
  // If ZF=1: jump over INC RAX, RAX stays 0.
  // If ZF=0: execute INC RAX, RAX becomes 1.
  ArchState br = {};
  br.rax = 0;
  br.rflags = 0x2 | FL_ZF;  // ZF=1
  add("je taken (skip inc)",     {0x74, 0x03, 0x48, 0xFF, 0xC0}, br, FL_ALL);

  br.rflags = 0x2;  // ZF=0
  add("je not taken (exec inc)", {0x74, 0x03, 0x48, 0xFF, 0xC0}, br, FL_ALL);

  // JL rel8: 7C xx
  br.rflags = 0x2 | FL_SF;  // SF=1, OF=0 → SF!=OF → L is true
  add("jl taken",     {0x7C, 0x03, 0x48, 0xFF, 0xC0}, br, FL_ALL);
  br.rflags = 0x2;  // SF=0, OF=0 → SF==OF → L is false
  add("jl not taken", {0x7C, 0x03, 0x48, 0xFF, 0xC0}, br, FL_ALL);

  // JMP rel8: EB xx (unconditional short jump)
  add("jmp rel8",     {0xEB, 0x03, 0x48, 0xFF, 0xC0}, br, FL_ALL);

  // =====================================================================
  // 11. Data movement — MOVSX, MOVZX, MOVSXD, BSWAP, CBW, CWD, XCHG
  // =====================================================================
  cat = "Baseline/Data movement";
  ArchState mv = {};
  mv.rflags = 0x2;

  // MOVSX RAX, BL: sign-extend byte to 64
  mv.rbx = 0xFF;  // -1 as byte
  add("movsx rax,bl",  {0x48, 0x0F, 0xBE, 0xC3}, mv, FL_ALL);
  mv.rbx = 0x7F;  // +127
  add("movsx rax,bl pos", {0x48, 0x0F, 0xBE, 0xC3}, mv, FL_ALL);

  // MOVSX RAX, BX: sign-extend word to 64
  mv.rbx = 0x8000;  // -32768 as word
  add("movsx rax,bx",  {0x48, 0x0F, 0xBF, 0xC3}, mv, FL_ALL);

  // MOVSXD RAX, EBX: sign-extend dword to 64 (REX.W 63 /r)
  mv.rbx = 0x80000000;  // -2^31 as dword
  add("movsxd rax,ebx", {0x48, 0x63, 0xC3}, mv, FL_ALL);
  mv.rbx = 0x7FFFFFFF;
  add("movsxd rax,ebx pos", {0x48, 0x63, 0xC3}, mv, FL_ALL);

  // MOVZX RAX, BL: zero-extend byte to 64
  mv.rbx = 0xFF;
  add("movzx rax,bl",  {0x48, 0x0F, 0xB6, 0xC3}, mv, FL_ALL);

  // MOVZX RAX, BX: zero-extend word to 64
  mv.rbx = 0xFFFF;
  add("movzx rax,bx",  {0x48, 0x0F, 0xB7, 0xC3}, mv, FL_ALL);

  // BSWAP RAX: 48 0F C8
  mv.rax = 0x0102030405060708;
  add("bswap rax",  {0x48, 0x0F, 0xC8}, mv, FL_ALL);

  // BSWAP EAX (32-bit): 0F C8
  mv.rax = 0xFFFFFFFF01020304;
  add("bswap eax (32)", {0x0F, 0xC8}, mv, FL_ALL);  // upper 32 bits zeroed

  // CBW: 66 98 (sign-extend AL -> AX)
  mv.rax = 0x123456789ABCDE80;  // AL = 0x80
  add("cbw", {0x66, 0x98}, mv, FL_ALL);

  // CWDE: 98 (sign-extend AX -> EAX)
  mv.rax = 0x123456789ABC8000;  // AX = 0x8000
  add("cwde", {0x98}, mv, FL_ALL);

  // CDQE: 48 98 (sign-extend EAX -> RAX)
  mv.rax = 0x1234567880000000;  // EAX = 0x80000000
  add("cdqe", {0x48, 0x98}, mv, FL_ALL);

  // CWD: 66 99 (sign-extend AX -> DX:AX)
  mv.rax = 0x8000;  // AX = 0x8000 (negative)
  mv.rdx = 0;
  add("cwd", {0x66, 0x99}, mv, FL_ALL);

  // CDQ: 99 (sign-extend EAX -> EDX:EAX)
  mv.rax = 0x80000000;
  mv.rdx = 0;
  add("cdq", {0x99}, mv, FL_ALL);

  // CQO: 48 99 (sign-extend RAX -> RDX:RAX)
  mv.rax = 0x8000000000000000;
  mv.rdx = 0;
  add("cqo neg", {0x48, 0x99}, mv, FL_ALL);
  mv.rax = 0x7FFFFFFFFFFFFFFF;
  add("cqo pos", {0x48, 0x99}, mv, FL_ALL);

  // XCHG RAX, RBX: 48 93
  mv.rax = 0xAAAAAAAAAAAAAAAA;
  mv.rbx = 0xBBBBBBBBBBBBBBBB;
  add("xchg rax,rbx", {0x48, 0x93}, mv, FL_ALL);

  // XCHG RCX, RDX: 48 87 CA (ModRM=CA: mod=11, reg=rcx=1, rm=rdx=2)
  mv.rcx = 0xCCCCCCCCCCCCCCCC;
  mv.rdx = 0xDDDDDDDDDDDDDDDD;
  add("xchg rcx,rdx", {0x48, 0x87, 0xCA}, mv, FL_ALL);

  // =====================================================================
  // 12. Bit operations — BT, BTS, BTR, BTC, BSF, BSR, POPCNT, LZCNT, TZCNT
  // =====================================================================
  cat = "Baseline/Bit operations";
  ArchState bt = {};
  bt.rflags = 0x2;

  // BT RAX, RBX: test bit RBX of RAX. CF = selected bit.
  // 0F A3 /r (ModRM: reg=rbx=3, rm=rax=0 = D8)
  bt.rax = 0x80;  // bit 7 set
  bt.rbx = 7;
  add("bt rax,rbx (set)",   {0x48, 0x0F, 0xA3, 0xD8}, bt, FL_CF);
  bt.rbx = 6;
  add("bt rax,rbx (clear)", {0x48, 0x0F, 0xA3, 0xD8}, bt, FL_CF);

  // BTS RAX, RBX: CF = old bit, then set bit. 0F AB /r
  bt.rax = 0;
  bt.rbx = 5;
  add("bts rax,rbx", {0x48, 0x0F, 0xAB, 0xD8}, bt, FL_CF);

  // BTR RAX, RBX: CF = old bit, then clear bit. 0F B3 /r
  bt.rax = 0xFF;
  bt.rbx = 3;
  add("btr rax,rbx", {0x48, 0x0F, 0xB3, 0xD8}, bt, FL_CF);

  // BTC RAX, RBX: CF = old bit, then complement bit. 0F BB /r
  bt.rax = 0xFF;
  bt.rbx = 0;
  add("btc rax,rbx", {0x48, 0x0F, 0xBB, 0xD8}, bt, FL_CF);

  // BT reg, imm8: 0F BA /4 imm8
  bt.rax = 0x100;  // bit 8 set
  add("bt rax,imm8", {0x48, 0x0F, 0xBA, 0xE0, 0x08}, bt, FL_CF);

  // BSF RAX, RBX: find lowest set bit. ZF=1 if source=0.
  // 0F BC /r (ModRM: reg=rax=0, rm=rbx=3 = C3)
  bt.rbx = 0x100;  // bit 8 set → result = 8
  add("bsf rax,rbx", {0x48, 0x0F, 0xBC, 0xC3}, bt, FL_ZF_ONLY);
  bt.rbx = 0;  // ZF=1
  add("bsf rax,rbx zero", {0x48, 0x0F, 0xBC, 0xC3}, bt, FL_ZF_ONLY);

  // BSR RAX, RBX: find highest set bit.
  // 0F BD /r
  bt.rbx = 0x100;  // bit 8 = highest → result = 8
  add("bsr rax,rbx", {0x48, 0x0F, 0xBD, 0xC3}, bt, FL_ZF_ONLY);
  bt.rbx = 0;
  add("bsr rax,rbx zero", {0x48, 0x0F, 0xBD, 0xC3}, bt, FL_ZF_ONLY);

  // POPCNT RAX, RBX: F3 48 0F B8 C3
  bt.rbx = 0xFF00FF00FF00FF00;  // 32 bits set
  add("popcnt rax,rbx", {0xF3, 0x48, 0x0F, 0xB8, 0xC3}, bt, FL_ALL);
  bt.rbx = 0;
  add("popcnt rax,rbx zero", {0xF3, 0x48, 0x0F, 0xB8, 0xC3}, bt, FL_ALL);

  // LZCNT RAX, RBX: F3 48 0F BD C3
  bt.rbx = 0x0000000100000000;  // bit 32 set → lzcnt = 31
  add("lzcnt rax,rbx", {0xF3, 0x48, 0x0F, 0xBD, 0xC3}, bt, FL_CF_ZF);
  bt.rbx = 0;
  add("lzcnt rax,rbx zero", {0xF3, 0x48, 0x0F, 0xBD, 0xC3}, bt, FL_CF_ZF);
  bt.rbx = 0x8000000000000000;  // highest bit → lzcnt = 0, ZF=1
  add("lzcnt rax,rbx msb", {0xF3, 0x48, 0x0F, 0xBD, 0xC3}, bt, FL_CF_ZF);

  // TZCNT RAX, RBX: F3 48 0F BC C3
  bt.rbx = 0x100;  // bit 8 → tzcnt = 8
  add("tzcnt rax,rbx", {0xF3, 0x48, 0x0F, 0xBC, 0xC3}, bt, FL_CF_ZF);
  bt.rbx = 0;
  add("tzcnt rax,rbx zero", {0xF3, 0x48, 0x0F, 0xBC, 0xC3}, bt, FL_CF_ZF);
  bt.rbx = 1;  // tzcnt = 0, ZF=1
  add("tzcnt rax,rbx lsb", {0xF3, 0x48, 0x0F, 0xBC, 0xC3}, bt, FL_CF_ZF);

  // =====================================================================
  // 13. Stack operations — PUSH, POP, CALL+RET
  // =====================================================================
  cat = "Baseline/Stack operations";

  // PUSH RBX (53) + POP RAX (58): RAX should get RBX's value
  ArchState stk = {};
  stk.rbx = 0xDEADBEEFCAFEBABE;
  stk.rflags = 0x2;
  add("push rbx; pop rax", {0x53, 0x58}, stk, FL_ALL);

  // PUSH imm8 (6A imm8) + POP RAX: test sign-extension
  stk.rax = 0;
  add("push imm8(-1); pop rax", {0x6A, 0xFF, 0x58}, stk, FL_ALL);

  // PUSH imm32 (68 imm32) + POP RAX
  add("push imm32; pop rax", {0x68, 0x78, 0x56, 0x34, 0x12, 0x58}, stk, FL_ALL);

  // CALL rel32 + RET: tests stack push/pop of return address
  // Layout: E8 01 00 00 00 | F4 | C3
  //   offset 0: CALL +1 → target = offset 6
  //   offset 5: HLT (return point)
  //   offset 6: RET
  stk.rax = 0;
  add("call+ret", {0xE8, 0x01, 0x00, 0x00, 0x00, 0xF4, 0xC3}, stk, FL_ALL);

  // CALL + RET with operations in callee
  // E8 02 00 00 00 | F4 | 48 FF C0 | C3
  //   offset 0: CALL +2 → target = offset 7
  //   offset 5: HLT (return point, after RET pops here... wait)
  // Actually: CALL pushes return address = offset 5, jumps to offset 7.
  // Wait, the CALL is 5 bytes (E8 + 4-byte offset). Return addr = CODE_ADDR + 5.
  // Target = CODE_ADDR + 5 + 2 = CODE_ADDR + 7.
  // Offset 5: F4 = HLT (this is where RET returns to)
  // Offset 6: padding (need 1 byte before target at offset 7)
  // Let me redo: CALL offset = 2 means skip 2 bytes after the CALL.
  // Return addr = CODE_ADDR + 5. Target = CODE_ADDR + 5 + 2 = CODE_ADDR + 7.
  // So bytes 5,6 = F4, 90 (HLT, NOP as padding). Byte 7+ = INC RAX + RET.
  // After RET, execution continues at offset 5 = HLT.
  stk.rax = 0;
  add("call+inc+ret", {0xE8, 0x02, 0x00, 0x00, 0x00, 0xF4, 0x90,
                        0x48, 0xFF, 0xC0, 0xC3}, stk, FL_ALL);

  // =====================================================================
  // 14. LEA — exercises addressing mode computation without memory access
  // =====================================================================
  cat = "Baseline/LEA";
  ArchState lea = {};
  lea.rbx = 100;
  lea.rcx = 7;
  lea.rsi = 0x1000;
  lea.rflags = 0x2;

  // LEA RAX, [RBX + RCX*2]: 48 8D 04 4B
  add("lea [rbx+rcx*2]", {0x48, 0x8D, 0x04, 0x4B}, lea, FL_ALL);

  // LEA RAX, [RBX + RCX*8 + 0x10]: 48 8D 44 CB 10
  add("lea [rbx+rcx*8+disp8]", {0x48, 0x8D, 0x44, 0xCB, 0x10}, lea, FL_ALL);

  // LEA RAX, [RSI + 0x100]: 48 8D 86 00 01 00 00
  add("lea [rsi+disp32]", {0x48, 0x8D, 0x86, 0x00, 0x01, 0x00, 0x00}, lea, FL_ALL);

  // LEA EAX, [EBX + ECX*4] (32-bit, with 67h prefix): zero-extends to 64
  // 67 8D 04 8B
  add("lea eax,[ebx+ecx*4] (32)", {0x67, 0x8D, 0x04, 0x8B}, lea, FL_ALL);

  // =====================================================================
  // 15. Memory operands — exercises RM_mem paths in read_rm_val/write_rm_val
  //     RDI = DATA_ADDR, initial data placed there
  // =====================================================================
  cat = "Baseline/Memory operands";

  // MOV RAX, [RDI]: 48 8B 07 (load 8 bytes)
  {
    ArchState mem = {};
    mem.rdi = DATA_ADDR;
    mem.rflags = 0x2;
    std::vector<u8> data = {0x78, 0x56, 0x34, 0x12, 0xEF, 0xCD, 0xAB, 0x90};
    add_mem("mov rax,[rdi]", {0x48, 0x8B, 0x07}, mem, FL_ALL, data, 0);
  }

  // MOV EAX, [RDI]: 8B 07 (load 4 bytes, zero-extends)
  {
    ArchState mem = {};
    mem.rax = 0xFFFFFFFFFFFFFFFF;
    mem.rdi = DATA_ADDR;
    mem.rflags = 0x2;
    std::vector<u8> data = {0x78, 0x56, 0x34, 0x12, 0, 0, 0, 0};
    add_mem("mov eax,[rdi] (32)", {0x8B, 0x07}, mem, FL_ALL, data, 0);
  }

  // MOV [RDI], RAX: 48 89 07 (store 8 bytes)
  {
    ArchState mem = {};
    mem.rax = 0x123456789ABCDEF0;
    mem.rdi = DATA_ADDR;
    mem.rflags = 0x2;
    add_mem("mov [rdi],rax", {0x48, 0x89, 0x07}, mem, FL_ALL, {}, 8);
  }

  // ADD RAX, [RDI]: 48 03 07
  {
    ArchState mem = {};
    mem.rax = 100;
    mem.rdi = DATA_ADDR;
    mem.rflags = 0x2;
    u8 val[] = {42, 0, 0, 0, 0, 0, 0, 0};
    add_mem("add rax,[rdi]", {0x48, 0x03, 0x07}, mem, FL_ALL,
            {val, val + 8}, 0);
  }

  // ADD [RDI], RAX: 48 01 07 (read-modify-write to memory)
  {
    ArchState mem = {};
    mem.rax = 100;
    mem.rdi = DATA_ADDR;
    mem.rflags = 0x2;
    u8 val[] = {42, 0, 0, 0, 0, 0, 0, 0};
    add_mem("add [rdi],rax", {0x48, 0x01, 0x07}, mem, FL_ALL,
            {val, val + 8}, 8);
  }

  // CMP RAX, [RDI]: 48 3B 07 (compare reg with memory)
  {
    ArchState mem = {};
    mem.rax = 42;
    mem.rdi = DATA_ADDR;
    mem.rflags = 0x2;
    u8 val[] = {42, 0, 0, 0, 0, 0, 0, 0};
    add_mem("cmp rax,[rdi] equal", {0x48, 0x3B, 0x07}, mem, FL_ALL,
            {val, val + 8}, 0);
  }

  // MOV [RDI+8], RBX using displacement: 48 89 5F 08
  {
    ArchState mem = {};
    mem.rbx = 0xCAFEBABE;
    mem.rdi = DATA_ADDR;
    mem.rflags = 0x2;
    add_mem("mov [rdi+8],rbx", {0x48, 0x89, 0x5F, 0x08}, mem, FL_ALL, {}, 16);
  }

  // SHL QWORD [RDI], CL: 48 D3 27 (shift memory operand)
  {
    ArchState mem = {};
    mem.rcx = 4;
    mem.rdi = DATA_ADDR;
    mem.rflags = 0x2;
    u8 val[] = {0xFF, 0, 0, 0, 0, 0, 0, 0};
    add_mem("shl [rdi],cl", {0x48, 0xD3, 0x27}, mem, FL_NO_AF_OF,
            {val, val + 8}, 8);
  }

  // INC QWORD [RDI]: 48 FF 07
  {
    ArchState mem = {};
    mem.rdi = DATA_ADDR;
    mem.rflags = 0x2;
    u8 val[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F};
    add_mem("inc [rdi]", {0x48, 0xFF, 0x07}, mem, FL_ALL, {val, val + 8}, 8);
  }

  // =====================================================================
  // 16. Double-precision shifts — SHLD, SHRD
  // =====================================================================
  cat = "Baseline/SHLD/SHRD";
  ArchState ds = {};
  ds.rax = 0x123456789ABCDEF0;
  ds.rbx = 0xFEDCBA9876543210;
  ds.rcx = 8;
  ds.rflags = 0x2;

  // SHLD RAX, RBX, CL: 48 0F A5 D8 (reg=rbx, rm=rax)
  add("shld rax,rbx,cl", {0x48, 0x0F, 0xA5, 0xD8}, ds, FL_NO_AF_OF);

  // SHRD RAX, RBX, CL: 48 0F AD D8
  add("shrd rax,rbx,cl", {0x48, 0x0F, 0xAD, 0xD8}, ds, FL_NO_AF_OF);

  // SHLD with count=1 (OF defined)
  ds.rcx = 1;
  add("shld rax,rbx,1", {0x48, 0x0F, 0xA5, 0xD8}, ds, FL_NO_AF);

  // SHRD with count=1
  add("shrd rax,rbx,1", {0x48, 0x0F, 0xAD, 0xD8}, ds, FL_NO_AF);

  // SHLD with imm8: 48 0F A4 D8 imm8
  ds.rcx = 0;  // CL unused, imm8 used
  add("shld rax,rbx,imm4", {0x48, 0x0F, 0xA4, 0xD8, 0x04}, ds, FL_NO_AF_OF);
  add("shrd rax,rbx,imm4", {0x48, 0x0F, 0xAC, 0xD8, 0x04}, ds, FL_NO_AF_OF);

  // =====================================================================
  // 17. MOV reg,imm — tests fetch_imm_v paths
  // =====================================================================
  cat = "Baseline/MOV reg,imm";
  ArchState mi = {};
  mi.rflags = 0x2;

  // MOV RAX, imm64: 48 B8 imm64 (REX.W + B8+rd)
  add("mov rax,imm64", {0x48, 0xB8, 0x01, 0x02, 0x03, 0x04,
                         0x05, 0x06, 0x07, 0x08}, mi, FL_ALL);

  // MOV EAX, imm32: B8 imm32 (zero-extends to 64)
  mi.rax = 0xFFFFFFFFFFFFFFFF;
  add("mov eax,imm32", {0xB8, 0x78, 0x56, 0x34, 0x12}, mi, FL_ALL);

  // MOV AX, imm16: 66 B8 imm16 (preserves upper bits)
  mi.rax = 0xFFFFFFFFFFFF0000;
  add("mov ax,imm16", {0x66, 0xB8, 0xAB, 0xCD}, mi, FL_ALL);

  // =====================================================================
  // 18. XADD — exchange and add
  // =====================================================================
  cat = "Baseline/XADD";
  ArchState xa = {};
  xa.rax = 10;
  xa.rbx = 20;
  xa.rflags = 0x2;
  // XADD RAX, RBX: 48 0F C1 D8 (reg=rbx, rm=rax)
  // RAX := RAX + RBX, RBX := old RAX
  add("xadd rax,rbx", {0x48, 0x0F, 0xC1, 0xD8}, xa);

  // =====================================================================
  // 19. CMPXCHG — compare and exchange
  // =====================================================================
  cat = "Baseline/CMPXCHG";
  // CMPXCHG RBX, RCX: 48 0F B1 CB (reg=rcx, rm=rbx)
  // If RAX == RBX: ZF=1, RBX := RCX
  // If RAX != RBX: ZF=0, RAX := RBX

  // Case 1: equal
  ArchState cx = {};
  cx.rax = 42;
  cx.rbx = 42;
  cx.rcx = 99;
  cx.rflags = 0x2;
  add("cmpxchg equal", {0x48, 0x0F, 0xB1, 0xCB}, cx);

  // Case 2: not equal
  cx.rax = 42;
  cx.rbx = 100;
  cx.rcx = 99;
  add("cmpxchg not equal", {0x48, 0x0F, 0xB1, 0xCB}, cx);

  // =====================================================================
  // 20. Multi-instruction sequences — tests instruction interaction
  // =====================================================================
  cat = "Baseline/Multi-instruction";

  // ADD + ADC chain (tests carry propagation across instructions)
  // ADD RAX, RBX; ADC RDX, RCX
  ArchState chain = {};
  chain.rax = 0xFFFFFFFFFFFFFFFF;
  chain.rbx = 2;
  chain.rcx = 0;
  chain.rdx = 0;
  chain.rflags = 0x2;
  add("add+adc chain", {0x48, 0x01, 0xD8,   // ADD RAX, RBX
                         0x48, 0x11, 0xCA}, chain);  // ADC RDX, RCX

  // CMP + CMOVL (conditional based on previous comparison)
  ArchState cmpseq = {};
  cmpseq.rax = 10;
  cmpseq.rbx = 20;
  cmpseq.rcx = 99;
  cmpseq.rflags = 0x2;
  // CMP RAX, RBX; CMOVL RAX, RCX (if RAX < RBX, RAX := RCX)
  add("cmp+cmovl taken", {0x48, 0x39, 0xD8,               // CMP RAX, RBX
                           0x48, 0x0F, 0x4C, 0xC1}, cmpseq, FL_ALL);  // CMOVL RAX, RCX

  cmpseq.rax = 30;
  add("cmp+cmovl not taken", {0x48, 0x39, 0xD8,
                               0x48, 0x0F, 0x4C, 0xC1}, cmpseq, FL_ALL);

  // SHL + OR (construct value through shifts)
  ArchState shift_or = {};
  shift_or.rax = 0xFF;
  shift_or.rbx = 0x01;
  shift_or.rcx = 8;
  shift_or.rflags = 0x2;
  // SHL RAX, CL; OR RAX, RBX → RAX = 0xFF01 (if CL=8)
  add("shl+or construct", {0x48, 0xD3, 0xE0,        // SHL RAX, CL
                            0x48, 0x09, 0xD8}, shift_or, FL_ALL);

  // =====================================================================
  // 21. REX prefix variations — tests REX.R, REX.B for upper registers
  // =====================================================================
  cat = "Baseline/REX prefix";
  ArchState rex = {};
  rex.r8  = 0x1111111111111111;
  rex.r9  = 0x2222222222222222;
  rex.r12 = 0x3333333333333333;
  rex.r15 = 0x4444444444444444;
  rex.rflags = 0x2;

  // ADD R8, R9: 4D 01 C8 (REX.W+R+B=4D, 01, ModRM=C8: reg=r9=1, rm=r8=0)
  add("add r8,r9", {0x4D, 0x01, 0xC8}, rex);

  // MOV R12, R15: 4D 89 FC (REX.W+R+B, 89, ModRM=FC: reg=r15=7, rm=r12=4)
  add("mov r12,r15", {0x4D, 0x89, 0xFC}, rex, FL_ALL);

  // INC R8: 49 FF C0
  add("inc r8", {0x49, 0xFF, 0xC0}, rex);

  // =====================================================================
  // 22. Flag manipulation — CLC, STC, CLD, STD, CMC, LAHF, SAHF
  // =====================================================================
  cat = "Baseline/Flag manipulation";

  // CLC: F8
  ArchState fl = {};
  fl.rflags = 0x2 | FL_CF;
  add("clc", {0xF8}, fl, FL_ALL);

  // STC: F9
  fl.rflags = 0x2;
  add("stc", {0xF9}, fl, FL_ALL);

  // CMC (complement CF): F5
  fl.rflags = 0x2;
  add("cmc cf=0", {0xF5}, fl, FL_ALL);
  fl.rflags = 0x2 | FL_CF;
  add("cmc cf=1", {0xF5}, fl, FL_ALL);

  // CLD: FC
  fl.rflags = 0x2 | FL_DF;
  add("cld", {0xFC}, fl, FL_ALL);

  // STD: FD
  fl.rflags = 0x2;
  add("std", {0xFD}, fl, FL_ALL);

  // LAHF: load AH from flags (9F). AH = SF:ZF:0:AF:0:PF:1:CF
  // Test all individual flags to catch bit-ordering bugs
  fl.rflags = 0x2 | FL_CF | FL_ZF | FL_SF;
  fl.rax = 0;
  add("lahf all", {0x9F}, fl, FL_ALL);

  // LAHF with only CF set — distinguishes CF (bit 0) from SF (bit 7)
  fl.rflags = 0x2 | FL_CF;
  fl.rax = 0;
  add("lahf cf", {0x9F}, fl, FL_ALL);

  // LAHF with only SF set
  fl.rflags = 0x2 | FL_SF;
  fl.rax = 0;
  add("lahf sf", {0x9F}, fl, FL_ALL);

  // LAHF with only PF set — distinguishes PF (bit 2) from ZF (bit 6)
  fl.rflags = 0x2 | FL_PF;
  fl.rax = 0;
  add("lahf pf", {0x9F}, fl, FL_ALL);

  // LAHF with only ZF set
  fl.rflags = 0x2 | FL_ZF;
  fl.rax = 0;
  add("lahf zf", {0x9F}, fl, FL_ALL);

  // LAHF with only AF set
  fl.rflags = 0x2 | FL_AF;
  fl.rax = 0;
  add("lahf af", {0x9F}, fl, FL_ALL);

  // LAHF with no flags set (reserved bit 1 should be 1 in AH)
  fl.rflags = 0x2;
  fl.rax = 0;
  add("lahf none", {0x9F}, fl, FL_ALL);

  // LAHF with all status flags set
  fl.rflags = 0x2 | FL_CF | FL_PF | FL_AF | FL_ZF | FL_SF;
  fl.rax = 0xDEADBEEF00000000;  // non-zero rax to verify only AH changes
  add("lahf all2", {0x9F}, fl, FL_ALL);

  // SAHF: store AH into flags (9E). Test with various AH values.
  // AH = 0xD5 = 1101_0101 → SF=1 ZF=1 AF=1 PF=1 CF=1
  fl.rflags = 0x2;
  fl.rax = 0x000000000000D500;
  add("sahf d5", {0x9E}, fl, FL_ALL);

  // AH = 0x00 → SF=0 ZF=0 AF=0 PF=0 CF=0
  fl.rflags = 0x2 | FL_CF | FL_SF | FL_ZF | FL_PF | FL_AF;
  fl.rax = 0x0000000000000000;
  add("sahf 00", {0x9E}, fl, FL_ALL);

  // AH = 0x01 → only CF=1
  fl.rflags = 0x2;
  fl.rax = 0x0000000000000100;
  add("sahf 01", {0x9E}, fl, FL_ALL);

  // AH = 0x80 → only SF=1
  fl.rflags = 0x2;
  fl.rax = 0x0000000000008000;
  add("sahf 80", {0x9E}, fl, FL_ALL);

  // LAHF then SAHF round-trip: LAHF (9F) then SAHF (9E) — flags preserved
  fl.rflags = 0x2 | FL_CF | FL_PF | FL_SF;
  fl.rax = 0;
  add("lahf+sahf", {0x9F, 0x9E}, fl, FL_ALL);

  // =====================================================================
  // LEA — basic and address-size override (67h prefix)
  // =====================================================================
  cat = "LEA";

  // LEA RAX, [RBX + RCX]  =>  48 8D 04 0B
  {
    ArchState s = {};
    s.rbx = 0x1000;
    s.rcx = 0x200;
    add("lea rax,[rbx+rcx]", {0x48, 0x8D, 0x04, 0x0B}, s, FL_NONE);
    // expect RAX = 0x1200
  }

  // LEA EAX, [RBX + RCX]  =>  8D 04 0B  (32-bit operand size, 64-bit address)
  {
    ArchState s = {};
    s.rbx = 0x100000000;
    s.rcx = 0x200000000;
    add("lea eax,[rbx+rcx]", {0x8D, 0x04, 0x0B}, s, FL_NONE);
    // expect RAX = low32(0x300000000) = 0x00000000, zero-extended
  }

  // LEA RAX, [EBX + ECX]  =>  67 48 8D 04 0B  (64-bit operand, 32-bit address)
  // Address computed using 32-bit registers, truncated to 32 bits, zero-extended
  {
    ArchState s = {};
    s.rbx = 0x0000000100001000;  // EBX = 0x00001000
    s.rcx = 0x0000000200000200;  // ECX = 0x00000200
    add("lea rax,[ebx+ecx] 67h", {0x67, 0x48, 0x8D, 0x04, 0x0B}, s, FL_NONE);
    // expect RAX = zero_extend(EBX + ECX) = 0x00001200
    // NOT 0x0000000300001200 (which would happen without truncation)
  }

  // LEA EAX, [EBX + ECX]  =>  67 8D 04 0B  (32-bit operand, 32-bit address)
  {
    ArchState s = {};
    s.rbx = 0xFFFFFFFF00001000;
    s.rcx = 0xFFFFFFFF00000200;
    add("lea eax,[ebx+ecx] 67h", {0x67, 0x8D, 0x04, 0x0B}, s, FL_NONE);
    // expect RAX = zero_extend(0x00001200) = 0x00001200
  }

  // LEA RAX, [EBX + ECX] with overflow in 32-bit address calculation
  // EBX=0xFFFFFF00, ECX=0x00000200 => 32-bit sum wraps to 0x00000100
  {
    ArchState s = {};
    s.rbx = 0xFFFFFF00;
    s.rcx = 0x00000200;
    add("lea rax,[ebx+ecx] 67h wrap", {0x67, 0x48, 0x8D, 0x04, 0x0B}, s, FL_NONE);
    // expect RAX = 0x00000100 (wrapped at 32 bits)
  }

  // LEA RAX, [EBX + ECX*4 + 0x10]  =>  67 48 8D 44 8B 10
  {
    ArchState s = {};
    s.rbx = 0x0000000100000100;  // EBX = 0x00000100
    s.rcx = 0x0000000200000008;  // ECX = 0x00000008
    add("lea rax,[ebx+ecx*4+0x10] 67h", {0x67, 0x48, 0x8D, 0x44, 0x8B, 0x10}, s, FL_NONE);
    // expect RAX = zero_extend(0x100 + 0x008*4 + 0x10) = 0x130
  }

  // =====================================================================
  // LOOP / LOOPcc — counter decrement + conditional branch
  // =====================================================================
  cat = "LOOP";

  // LOOP with RCX=2: decrements to 1, branches back (but we just execute 1 iteration
  // by jumping to the HLT). Use rel8=-2 to jump back to the LOOP itself for one iteration.
  // Actually, simpler: LOOP with RCX=1 → decrement to 0, no branch taken (fall through to HLT)
  {
    ArchState s = {};
    s.rcx = 1;
    // E2 00 = LOOP +0 (rel8=0, points to next insn = HLT; loop falls through)
    add("loop rcx=1 fallthru", {0xE2, 0x00}, s, FL_NONE);
    // expect RCX = 0
  }

  // LOOP with RCX=2, rel8=0 means branch target is the HLT right after
  // Decrements to 1, count!=0, but branch target is next insn anyway
  {
    ArchState s = {};
    s.rcx = 2;
    add("loop rcx=2 branch to hlt", {0xE2, 0x00}, s, FL_NONE);
    // expect RCX = 1
  }

  // LOOPE (E1) with RCX=2, ZF=1: decrement to 1, count!=0 and ZF=1 → branch
  {
    ArchState s = {};
    s.rcx = 2;
    s.rflags = 0x2 | FL_ZF;  // ZF=1
    add("loope rcx=2 zf=1", {0xE1, 0x00}, s, FL_NONE);
    // expect RCX = 1
  }

  // LOOPE (E1) with RCX=2, ZF=0: decrement to 1, count!=0 but ZF=0 → no branch
  {
    ArchState s = {};
    s.rcx = 2;
    s.rflags = 0x2;  // ZF=0
    add("loope rcx=2 zf=0", {0xE1, 0x00}, s, FL_NONE);
    // expect RCX = 1 (decremented regardless of branch)
  }

  // LOOPNE (E0) with RCX=2, ZF=0: decrement to 1, count!=0 and ZF=0 → branch
  {
    ArchState s = {};
    s.rcx = 2;
    s.rflags = 0x2;  // ZF=0
    add("loopne rcx=2 zf=0", {0xE0, 0x00}, s, FL_NONE);
    // expect RCX = 1
  }

  // LOOPNE (E0) with RCX=2, ZF=1: decrement to 1, count!=0 but ZF=1 → no branch
  {
    ArchState s = {};
    s.rcx = 2;
    s.rflags = 0x2 | FL_ZF;  // ZF=1
    add("loopne rcx=2 zf=1", {0xE0, 0x00}, s, FL_NONE);
    // expect RCX = 1
  }

  // LOOP with 67h prefix: uses ECX instead of RCX
  // RCX=0x100000001, 67h LOOP: ECX=1, decrement to 0, no branch
  {
    ArchState s = {};
    s.rcx = 0x100000001;
    // 67 E2 00 = LOOP with 32-bit address size
    add("loop 67h ecx=1", {0x67, 0xE2, 0x00}, s, FL_NONE);
    // expect RCX = 0x100000000 (ECX becomes 0, upper 32 bits preserved? No — write_gpr32 zeroes upper)
    // Actually write_gpr32 zero-extends, so RCX = 0x00000000
  }

  // =====================================================================
  // XLAT/XLATB — table lookup: AL := [RBX + ZeroExtend(AL)]
  // =====================================================================
  cat = "XLAT";

  // XLATB: read byte at [RBX + AL] into AL
  // Set up RBX = DATA_ADDR, AL = 5, DATA[5] = 0x42
  {
    ArchState s = {};
    s.rbx = DATA_ADDR;
    s.rax = 5;  // AL = 5
    std::vector<u8> data(256, 0);
    data[5] = 0x42;
    tests.push_back({"xlatb basic", cat,
      {0xD7},  // XLATB
      s, FL_NONE, 0, false, std::move(data), 0});
    // expect AL = 0x42, upper RAX bits preserved (RAX was 5, so RAX becomes 0x42)
  }

  // XLATB: AL = 0xFF (max index), DATA[255] = 0xAB
  {
    ArchState s = {};
    s.rbx = DATA_ADDR;
    s.rax = 0xFF00000000FF;  // AL = 0xFF, upper bits should be preserved
    std::vector<u8> data(256, 0);
    data[255] = 0xAB;
    tests.push_back({"xlatb al=0xff", cat,
      {0xD7},
      s, FL_NONE, 0, false, std::move(data), 0});
    // expect RAX = 0xFF000000AB (only AL changed)
  }

  // =====================================================================
  // ENTER — create stack frame
  // =====================================================================
  cat = "ENTER";

  // ENTER 0, 0: push RBP, mov RBP,RSP (no allocation)
  // C8 0000 00
  {
    ArchState s = {};
    s.rbp = 0xDEADBEEF;
    s.rsp = STACK_TOP;
    add("enter 0,0", {0xC8, 0x00, 0x00, 0x00}, s, FL_NONE);
    // expect RSP = STACK_TOP - 8, RBP = STACK_TOP - 8
  }

  // ENTER 16, 0: push RBP, mov RBP,RSP, sub RSP,16
  {
    ArchState s = {};
    s.rbp = 0xDEADBEEF;
    s.rsp = STACK_TOP;
    add("enter 16,0", {0xC8, 0x10, 0x00, 0x00}, s, FL_NONE);
    // expect RSP = STACK_TOP - 8 - 16 = STACK_TOP - 24, RBP = STACK_TOP - 8
  }

  // ENTER 0, 1: push RBP, frame_temp=RSP, push frame_temp, RBP=frame_temp
  {
    ArchState s = {};
    s.rbp = 0xDEADBEEF;
    s.rsp = STACK_TOP;
    add("enter 0,1", {0xC8, 0x00, 0x00, 0x01}, s, FL_NONE);
    // push RBP: RSP = STACK_TOP - 8
    // frame_temp = STACK_TOP - 8
    // push frame_temp: RSP = STACK_TOP - 16
    // RBP = frame_temp = STACK_TOP - 8
    // expect RSP = STACK_TOP - 16, RBP = STACK_TOP - 8
  }

  // =====================================================================
  // LEAVE — destroy stack frame (RSP := RBP, POP RBP)
  // =====================================================================
  cat = "LEAVE";

  // LEAVE: RSP = RBP, then POP RBP
  // We need [RBP] to contain the old RBP value we want to restore
  // Set RBP = DATA_ADDR, put 0x1234 at DATA_ADDR as the saved RBP
  {
    ArchState s = {};
    s.rbp = DATA_ADDR;
    s.rsp = 0x1000;  // will be overwritten by LEAVE
    std::vector<u8> data(16, 0);
    // Store 0x0000000000001234 at DATA_ADDR (little-endian)
    data[0] = 0x34; data[1] = 0x12;
    tests.push_back({"leave basic", cat,
      {0xC9},  // LEAVE
      s, FL_NONE, 0, false, std::move(data), 0});
    // RSP = RBP = DATA_ADDR, then POP RBP reads [DATA_ADDR] = 0x1234
    // expect RSP = DATA_ADDR + 8, RBP = 0x1234
  }

  // 66h LEAVE: operand-size prefix makes POP write BP (16-bit),
  // but StackAddrSize is always 64 in long mode, so RSP := RBP must
  // use the full 64-bit RBP, not just the low 16 bits.
  {
    ArchState s = {};
    s.rbp = DATA_ADDR;
    s.rsp = 0x1000;         // will be overwritten by LEAVE
    std::vector<u8> data(16, 0);
    data[0] = 0x78; data[1] = 0x56;  // saved BP = 0x5678
    tests.push_back({"leave 66h prefix", cat,
      {0x66, 0xC9},  // 66h LEAVE
      s, FL_NONE, 0, false, std::move(data), 0});
    // RSP = RBP = DATA_ADDR (full 64-bit), POP BP reads 16-bit
    // expect RSP = DATA_ADDR + 2, RBP low 16 = 0x5678
  }

  // =====================================================================
  // PUSH/POP FS/GS (0F A0/A1/A8/A9)
  // In 64-bit mode, PUSH pushes 64-bit (zero-extended selector),
  // POP pops 64-bit and loads low 16 bits into segment register.
  // =====================================================================
  cat = "PUSH/POP mem";
  {
    // PUSH FS; POP FS — round-trip, RSP should return to original
    // 0F A0 = PUSH FS, 0F A1 = POP FS
    tests.push_back({"push fs; pop fs", cat, {0x0F, 0xA0, 0x0F, 0xA1},
                      {.rflags = 0x2}, FL_NONE});

    // PUSH GS; POP GS — round-trip
    // 0F A8 = PUSH GS, 0F A9 = POP GS
    tests.push_back({"push gs; pop gs", cat, {0x0F, 0xA8, 0x0F, 0xA9},
                      {.rflags = 0x2}, FL_NONE});

    // PUSH FS; PUSH GS; POP GS; POP FS — verify both round-trip
    tests.push_back({"push fs; push gs; pop gs; pop fs", cat,
                      {0x0F, 0xA0, 0x0F, 0xA8, 0x0F, 0xA9, 0x0F, 0xA1},
                      {.rflags = 0x2}, FL_NONE});
  }

  // =====================================================================
  // CALL/RET — verify near call/return in 64-bit mode
  // =====================================================================
  cat = "CALL/RET";

  // CALL rel32 then RET: CALL pushes return addr, jumps forward, RET pops and returns
  // Code: CALL +2 (skip 2 bytes after the 5-byte CALL), NOP, NOP, RET, <fall through to HLT>
  // Actually simpler: CALL +0 means target = next_insn. So CALL +1 skips 1 byte.
  // E8 01000000 = CALL +1, then CC (int3, skipped), C3 = RET
  // After CALL: pushes addr of CC (CODE_ADDR+5), RIP = CODE_ADDR+6 (the C3)
  // RET: pops CODE_ADDR+5, executes CC... that's not great.
  // Better: CALL forward to RET, which returns back past the CALL.
  // E8 00000000 = CALL rel32=0 → target = next_insn (CODE_ADDR+5)
  // At CODE_ADDR+5: C3 (RET) → pops return addr = CODE_ADDR+5, goes there again...infinite loop
  // Let me use a different approach: just test that CALL pushes return address correctly
  // by examining RSP after CALL+RET.
  //
  // CALL rel32=+1, INT3 (skipped), RET
  // E8 01 00 00 00  CC  C3
  // CALL target = CODE_ADDR+5+1 = CODE_ADDR+6 = the C3 byte
  // Pushes return addr = CODE_ADDR+5 (addr of CC)
  // RET pops CODE_ADDR+5, executes CC=INT3... hmm.
  //
  // Simplest: CALL +2, followed by 2 bytes of HLT, then RET. RET returns to the first HLT.
  // E8 02 00 00 00  F4  F4  C3
  // CALL target = CODE_ADDR+5+2 = CODE_ADDR+7 = the C3 byte
  // Pushes return addr = CODE_ADDR+5 (first HLT)
  // RET pops CODE_ADDR+5, executes HLT. Done!
  {
    ArchState s = {};
    s.rsp = STACK_TOP;
    // E8 02000000 F4 F4 C3
    add("call rel32 + ret", {0xE8, 0x02, 0x00, 0x00, 0x00, 0xF4, 0xF4, 0xC3}, s, FL_NONE);
    // After: RSP = STACK_TOP (pushed then popped 8 bytes), RIP at first HLT
  }

  // CALL indirect: FF /2 via register
  // Load target address into RAX, then CALL RAX (FF D0), target code does RET
  // Sequence: MOV RAX, target_addr; CALL RAX; HLT; <target>: RET
  // But we can't easily compute target_addr as an immediate since CODE_ADDR is fixed.
  // Simpler: use LEA to compute target, then CALL.
  // Actually, let's just use CALL rel32 which we know works, and verify RSP is restored.

  // CALL indirect via register: FF D0 = CALL RAX
  // RAX = address of a RET (C3) instruction we place after the HLT
  // Sequence: FF D0 (CALL RAX), F4 (HLT, return here), C3 (RET, the target)
  // RAX must point to CODE_ADDR+3 (the C3)
  // CALL pushes return addr CODE_ADDR+2 (the F4), jumps to CODE_ADDR+3
  // RET pops CODE_ADDR+2, executes F4 (HLT). Done.
  {
    ArchState s = {};
    s.rsp = STACK_TOP;
    s.rax = CODE_ADDR + 3;  // address of the C3 (RET) byte
    add("call rax indirect + ret", {0xFF, 0xD0, 0xF4, 0xC3}, s, FL_NONE);
    // After: RSP = STACK_TOP (pushed then popped), halts at CODE_ADDR+2
  }

  // =====================================================================
  // CRC32 — SSE4.2 CRC-32C (Castagnoli) accumulation
  // Encoding: F2 0F 38 F0 /r = CRC32 r32, r/m8
  //           F2 0F 38 F1 /r = CRC32 r32, r/m16/32/64
  // =====================================================================
  cat = "CRC32";
  {
    // CRC32 eax, cl (8-bit source): F2 0F 38 F0 C1
    // CRC32(0, 0x01) — basic test
    ArchState s = {};
    s.rax = 0;
    s.rcx = 0x01;
    add("crc32 eax,cl init=0", {0xF2, 0x0F, 0x38, 0xF0, 0xC1}, s, FL_NONE);
  }
  {
    // CRC32 eax, cl with non-zero accumulator
    ArchState s = {};
    s.rax = 0xDEADBEEF;
    s.rcx = 0x42;
    add("crc32 eax,cl accum", {0xF2, 0x0F, 0x38, 0xF0, 0xC1}, s, FL_NONE);
  }
  {
    // CRC32 eax, cx (16-bit source): 66 F2 0F 38 F1 C1
    ArchState s = {};
    s.rax = 0;
    s.rcx = 0x1234;
    add("crc32 eax,cx", {0x66, 0xF2, 0x0F, 0x38, 0xF1, 0xC1}, s, FL_NONE);
  }
  {
    // CRC32 eax, ecx (32-bit source): F2 0F 38 F1 C1
    ArchState s = {};
    s.rax = 0;
    s.rcx = 0xDEADBEEF;
    add("crc32 eax,ecx", {0xF2, 0x0F, 0x38, 0xF1, 0xC1}, s, FL_NONE);
  }
  {
    // CRC32 rax, rcx (64-bit source): F2 48 0F 38 F1 C1
    ArchState s = {};
    s.rax = 0;
    s.rcx = 0x123456789ABCDEF0ULL;
    add("crc32 rax,rcx 64-bit", {0xF2, 0x48, 0x0F, 0x38, 0xF1, 0xC1}, s, FL_NONE);
  }
  {
    // CRC32 rax, cl (8-bit source, 64-bit dest): F2 48 0F 38 F0 C1
    // REX.W + 8-bit source — upper 32 bits of RAX should be zeroed
    ArchState s = {};
    s.rax = 0xFFFFFFFF00000000ULL;
    s.rcx = 0x55;
    add("crc32 rax,cl zero-ext", {0xF2, 0x48, 0x0F, 0x38, 0xF0, 0xC1}, s, FL_NONE);
  }
  {
    // CRC32 with known test vector: CRC32C("123456789") = 0xE3069283
    // Feed bytes one at a time: '1' = 0x31, etc.
    // CRC32 eax, cl eight times, then CRC32 eax, cl one more
    ArchState s = {};
    s.rax = 0;
    s.rcx = 0x34333231;  // "1234" in little-endian
    s.rdx = 0x38373635;  // "5678" in little-endian
    // CRC32 eax, ecx; CRC32 eax, edx; CRC32 eax, bl
    s.rbx = 0x39;  // '9'
    add("crc32 known vector",
        {0xF2, 0x0F, 0x38, 0xF1, 0xC1,        // CRC32 eax, ecx (32-bit)
         0xF2, 0x0F, 0x38, 0xF1, 0xC2,        // CRC32 eax, edx (32-bit)
         0xF2, 0x0F, 0x38, 0xF0, 0xC3},       // CRC32 eax, bl (8-bit)
        s, FL_NONE);
  }

  // =====================================================================
  // String ops — REP MOVS/STOS/SCAS/CMPS/LODS with DF, zero-length
  // =====================================================================
  {
    cat = "String ops";

    // REP MOVSB: F3 A4 -- copy RCX bytes from [RSI] to [RDI]
    // Forward (DF=0), 8 bytes
    {
      std::vector<u8> data(512, 0);
      for (int i = 0; i < 8; i++)
        data[i] = 0x10 + i;
      tests.push_back({"rep movsb fwd 8", cat, {0xF3, 0xA4},
                        {.rcx = 8, .rsi = DATA_ADDR, .rdi = DATA_ADDR + 256, .rflags = 0x2},
                        FL_ALL, 0, false, data, 512});
    }

    // REP MOVSB: backward (DF=1), 4 bytes -- start pointers at end
    {
      std::vector<u8> data(512, 0);
      data[0] = 0xAA;
      data[1] = 0xBB;
      data[2] = 0xCC;
      data[3] = 0xDD;
      tests.push_back({"rep movsb bwd 4", cat, {0xF3, 0xA4},
                        {.rcx = 4, .rsi = DATA_ADDR + 3, .rdi = DATA_ADDR + 256 + 3,
                         .rflags = 0x2 | FL_DF},
                        FL_ALL, 0, false, data, 512});
    }

    // REP MOVSB: zero count -- no-op
    {
      std::vector<u8> data(512, 0);
      data[0] = 0xFF;  // should not be copied
      tests.push_back({"rep movsb zero", cat, {0xF3, 0xA4},
                        {.rsi = DATA_ADDR, .rdi = DATA_ADDR + 256, .rflags = 0x2},
                        FL_ALL, 0, false, data, 512});
    }

    // REP MOVSQ: F3 48 A5 -- copy 2 qwords
    {
      std::vector<u8> data(512, 0);
      for (int i = 0; i < 16; i++)
        data[i] = 0x10 + i;
      tests.push_back({"rep movsq fwd 2", cat, {0xF3, 0x48, 0xA5},
                        {.rcx = 2, .rsi = DATA_ADDR, .rdi = DATA_ADDR + 256, .rflags = 0x2},
                        FL_ALL, 0, false, data, 512});
    }

    // REP STOSB: F3 AA -- fill RCX bytes at [RDI] with AL
    tests.push_back({"rep stosb 8", cat, {0xF3, 0xAA},
                      {.rax = 0x42, .rcx = 8, .rdi = DATA_ADDR, .rflags = 0x2},
                      FL_ALL, 0, false, {}, 8});

    // REP STOSD: F3 AB -- fill with EAX
    tests.push_back({"rep stosd 2", cat, {0xF3, 0xAB},
                      {.rax = 0xDEADBEEF, .rcx = 2, .rdi = DATA_ADDR, .rflags = 0x2},
                      FL_ALL, 0, false, {}, 8});

    // REP STOSQ: F3 48 AB
    tests.push_back({"rep stosq 1", cat, {0xF3, 0x48, 0xAB},
                      {.rax = 0x0102030405060708, .rcx = 1, .rdi = DATA_ADDR, .rflags = 0x2},
                      FL_ALL, 0, false, {}, 8});

    // LODSB: AC -- load byte from [RSI] into AL
    {
      std::vector<u8> data = {0x42};
      tests.push_back({"lodsb", cat, {0xAC},
                        {.rax = 0xDEADDEADDEADDEAD, .rsi = DATA_ADDR, .rflags = 0x2},
                        FL_ALL, 0, false, data, 0});
    }

    // LODSQ: 48 AD -- load qword from [RSI] into RAX
    {
      std::vector<u8> data = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08};
      tests.push_back({"lodsq", cat, {0x48, 0xAD},
                        {.rsi = DATA_ADDR, .rflags = 0x2},
                        FL_ALL, 0, false, data, 0});
    }

    // REPE CMPSB: F3 A6 -- compare while equal
    // Equal strings of length 4
    {
      std::vector<u8> data(512, 0);
      data[0]   = 0x11;
      data[1]   = 0x22;
      data[2]   = 0x33;
      data[3]   = 0x44;
      data[256] = 0x11;
      data[257] = 0x22;
      data[258] = 0x33;
      data[259] = 0x44;
      tests.push_back({"repe cmpsb equal", cat, {0xF3, 0xA6},
                        {.rcx = 4, .rsi = DATA_ADDR, .rdi = DATA_ADDR + 256, .rflags = 0x2},
                        FL_ALL, 0, false, data, 0});
    }

    // REPE CMPSB: differ at byte 2
    {
      std::vector<u8> data(512, 0);
      data[0]   = 0x11;
      data[1]   = 0x22;
      data[2]   = 0x33;
      data[3]   = 0x44;
      data[256] = 0x11;
      data[257] = 0x22;
      data[258] = 0xFF;
      data[259] = 0x44;
      tests.push_back({"repe cmpsb diff@2", cat, {0xF3, 0xA6},
                        {.rcx = 4, .rsi = DATA_ADDR, .rdi = DATA_ADDR + 256, .rflags = 0x2},
                        FL_ALL, 0, false, data, 0});
    }

    // REPNE SCASB: F2 AE -- scan for AL in [RDI]
    {
      std::vector<u8> data = {0x00, 0x01, 0x02, 0x42, 0x04, 0x05, 0x06, 0x07};
      tests.push_back({"repne scasb found", cat, {0xF2, 0xAE},
                        {.rax = 0x42, .rcx = 8, .rdi = DATA_ADDR, .rflags = 0x2},
                        FL_ALL, 0, false, data, 0});
    }

    // REPNE SCASB: not found
    {
      std::vector<u8> data = {0x00, 0x01, 0x02, 0x03};
      tests.push_back({"repne scasb notfound", cat, {0xF2, 0xAE},
                        {.rax = 0xFF, .rcx = 4, .rdi = DATA_ADDR, .rflags = 0x2},
                        FL_ALL, 0, false, data, 0});
    }
  }

  // =====================================================================
  // ENTER with nesting levels
  // =====================================================================
  {
    cat = "ENTER";

    // ENTER 0, 0: just push RBP and set RBP=RSP (like push rbp; mov rbp,rsp)
    // C8 00 00 00
    tests.push_back({"enter 0,0", cat, {0xC8, 0x00, 0x00, 0x00},
                      {.rbp = 0xAAAAAAAAAAAAAAAA, .rflags = 0x2}, FL_NONE});

    // ENTER 16, 0: allocate 16 bytes of local space
    tests.push_back({"enter 16,0", cat, {0xC8, 0x10, 0x00, 0x00},
                      {.rbp = 0xBBBBBBBBBBBBBBBB, .rflags = 0x2}, FL_NONE});

    // ENTER 0, 1: nesting level 1 -- pushes old RBP, then pushes frame_temp
    // RBP must point to valid stack memory since nesting copies prior frames
    tests.push_back({"enter 0,1", cat, {0xC8, 0x00, 0x00, 0x01},
                      {.rbp = STACK_TOP - 64, .rflags = 0x2}, FL_NONE});

    // ENTER 8, 2: nesting level 2 -- pushes old RBP, copies 1 prior frame ptr, pushes frame_temp
    tests.push_back({"enter 8,2", cat, {0xC8, 0x08, 0x00, 0x02},
                      {.rbp = STACK_TOP - 64, .rflags = 0x2}, FL_NONE});
  }
}


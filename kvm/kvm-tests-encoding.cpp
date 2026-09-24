#include "kvm-harness.h"

void add_encoding_tests(std::vector<TestCase> &tests) {
  std::string cat;

  // =====================================================================
  // REX R/B/X bit interactions
  // Tests that REX.R, REX.B, and REX.X correctly select extended registers.
  // =====================================================================
  {
    cat = "REX R/B/X";

    // REX.B selects R8 as rm: ADD R8, RAX
    // 49 01 C0: REX.W+B(49), ADD r/m64,r64(01), ModRM C0(mod=11,reg=rax=0,rm=0+B=r8)
    tests.push_back({"add r8,rax (REX.B)", cat, {0x49, 0x01, 0xC0},
                      {.rax = 0x100, .r8 = 0x200, .rflags = 0x2}, FL_ALL});

    // REX.R selects R8 as reg: ADD RAX, R8
    // 4C 01 C0: REX.W+R(4C), ADD r/m64,r64(01), ModRM C0(mod=11,reg=0+R=r8,rm=rax=0)
    tests.push_back({"add rax,r8 (REX.R)", cat, {0x4C, 0x01, 0xC0},
                      {.rax = 0x100, .r8 = 0x200, .rflags = 0x2}, FL_ALL});

    // REX.R+B: ADD R9, R10
    // 4D 01 D1: REX.W+R+B(4D), ADD r/m64,r64(01), ModRM D1(mod=11,reg=2+R=r10,rm=1+B=r9)
    tests.push_back({"add r9,r10 (REX.R+B)", cat, {0x4D, 0x01, 0xD1},
                      {.r9 = 0xAAAAAAAAAAAAAAAA, .r10 = 0x5555555555555555, .rflags = 0x2}, FL_ALL});

    // REX.B with 32-bit op: ADD R8D, EAX (should zero-extend into R8)
    // 41 01 C0: REX.B(41), ADD r/m32,r32(01), ModRM C0
    {
      ArchState s = {.rax = 1, .r8 = 0xFFFFFFFF00000001, .rflags = 0x2};
      tests.push_back({"add r8d,eax (32b REX.B)", cat, {0x41, 0x01, 0xC0}, s, FL_ALL});
    }

    // REX.R with 32-bit op: ADD EAX, R8D (should zero-extend into RAX)
    // 44 01 C0: REX.R(44), ADD r/m32,r32(01), ModRM C0(reg=0+R=r8d,rm=eax=0)
    tests.push_back({"add eax,r8d (32b REX.R)", cat, {0x44, 0x01, 0xC0},
                      {.rax = 0xFFFFFFFF00000001, .r8 = 1, .rflags = 0x2}, FL_ALL});

    // REX.B with memory base: MOV RAX, [R8]
    // 49 8B 00: REX.W+B(49), MOV r64,r/m64(8B), ModRM 00(mod=00,reg=rax=0,rm=0+B=r8)
    {
      std::vector<u8> data = {0x78, 0x56, 0x34, 0x12, 0xAA, 0xBB, 0xCC, 0xDD};
      tests.push_back({"mov rax,[r8] (REX.B base)", cat, {0x49, 0x8B, 0x00},
                        {.rax = 0xDEADDEADDEADDEAD, .r8 = DATA_ADDR, .rflags = 0x2},
                        FL_ALL, 0, false, data, 0});
    }

    // REX.X with SIB index: MOV RAX, [RDI + R8*2]
    // 4A 8B 04 47: REX.W+X(4A), MOV(8B), ModRM 04(mod=00,reg=rax,rm=100=SIB),
    //              SIB 47(scale=01=*2,index=0+X=r8,base=rdi=7)
    {
      std::vector<u8> data(16, 0);
      data[8]  = 0x11;
      data[9]  = 0x22;
      data[10] = 0x33;
      data[11] = 0x44;
      data[12] = 0x55;
      data[13] = 0x66;
      data[14] = 0x77;
      data[15] = 0x88;
      tests.push_back({"mov rax,[rdi+r8*2] (REX.X)", cat, {0x4A, 0x8B, 0x04, 0x47},
                        {.rax = 0xDEADDEADDEADDEAD, .rdi = DATA_ADDR, .r8 = 4, .rflags = 0x2},
                        FL_ALL, 0, false, data, 0});
    }

    // REX.B with SIB base: MOV RAX, [R13 + RCX*1]
    // 49 8B 44 0D 00: REX.W+B(49), MOV(8B), ModRM 44(mod=01,reg=rax,rm=100=SIB),
    //                 SIB 0D(scale=00,index=rcx=1,base=5+B=r13), disp8=0
    // Note: R13 as SIB base requires mod!=00, using mod=01 with disp8=0
    {
      std::vector<u8> data(16, 0);
      data[8]  = 0xAA;
      data[9]  = 0xBB;
      data[10] = 0xCC;
      data[11] = 0xDD;
      data[12] = 0xEE;
      data[13] = 0xFF;
      data[14] = 0x11;
      data[15] = 0x22;
      tests.push_back({"mov rax,[r13+rcx] (REX.B SIB base)", cat,
                        {0x49, 0x8B, 0x44, 0x0D, 0x00},
                        {.rax = 0xDEADDEADDEADDEAD, .rcx = 8, .r13 = DATA_ADDR, .rflags = 0x2},
                        FL_ALL, 0, false, data, 0});
    }

    // REX.X+B with SIB: MOV RAX, [R13 + R8*4]
    // 4B 8B 44 85 00: REX.W+X+B(4B), MOV(8B), ModRM 44(mod=01,reg=rax,rm=100=SIB),
    //                 SIB 85(scale=10=*4,index=0+X=r8,base=5+B=r13), disp8=0
    {
      std::vector<u8> data(16, 0);
      data[8]  = 0x12;
      data[9]  = 0x34;
      data[10] = 0x56;
      data[11] = 0x78;
      data[12] = 0x9A;
      data[13] = 0xBC;
      data[14] = 0xDE;
      data[15] = 0xF0;
      tests.push_back({"mov rax,[r13+r8*4] (REX.X+B)", cat,
                        {0x4B, 0x8B, 0x44, 0x85, 0x00},
                        {.rax = 0xDEADDEADDEADDEAD, .r8 = 2, .r13 = DATA_ADDR, .rflags = 0x2},
                        FL_ALL, 0, false, data, 0});
    }

    // REX.R+X+B: ADD [R13 + R8*1], R9
    // 4F 01 4C 05 00: REX.W+R+X+B(4F), ADD(01), ModRM 4C(mod=01,reg=1+R=r9,rm=100=SIB),
    //                 SIB 05(scale=00,index=0+X=r8,base=5+B=r13), disp8=0
    {
      std::vector<u8> data(16, 0);
      data[8] = 0x42;
      tests.push_back({"add [r13+r8],r9 (REX.R+X+B)", cat,
                        {0x4F, 0x01, 0x4C, 0x05, 0x00},
                        {.r8 = 8, .r9 = 0x100, .r13 = DATA_ADDR, .rflags = 0x2},
                        FL_ALL, 0, false, data, 16});
    }

    // REX prefix 0x40 (no R/W/B/X) — should not change operand size
    // 40 01 D8: REX(40), ADD r/m32,r32(01), ModRM D8(reg=ebx,rm=eax)
    // This is a 32-bit ADD, not 64-bit
    tests.push_back({"add eax,ebx (bare REX 0x40)", cat, {0x40, 0x01, 0xD8},
                      {.rax = 0xFFFFFFFF00000001, .rbx = 1, .rflags = 0x2}, FL_ALL});

    // REX.B with opcode-register: MOV R8, imm64
    // 49 B8 ...: REX.W+B(49), MOV r64,imm64 (B8+0=B8, but B extends to R8)
    tests.push_back({"mov r8,imm64 (REX.B opcode reg)", cat,
                      {0x49, 0xB8, 0xEF, 0xCD, 0xAB, 0x89, 0x67, 0x45, 0x23, 0x01},
                      {.rflags = 0x2}, FL_ALL});

    // REX.B with PUSH/POP opcode-register: PUSH R8; POP R9
    // 41 50: REX.B(41), PUSH r64 (50+0, B extends to R8)
    // 41 59: REX.B(41), POP r64 (58+1, B extends to R9)
    tests.push_back({"push r8; pop r9 (REX.B)", cat,
                      {0x41, 0x50, 0x41, 0x59},
                      {.r8 = 0x123456789ABCDEF0, .rflags = 0x2}, FL_ALL});

    // MOV R12, [RIP+disp32] — REX.R with RIP-relative addressing
    // 4C 8B 25 00 00 00 00: REX.W+R(4C), MOV(8B), ModRM 25(mod=00,reg=4+R=r12,rm=101=RIP)
    // disp32=0 means address is RIP+0, which points to byte after this instruction
    // Instead use [RDI] to keep it simple
  }

  // =====================================================================
  // Multi-byte NOP — verify all lengths leave state unchanged
  // =====================================================================
  {
    cat = "NOP";

    ArchState s = {
      .rax = 0x123456789ABCDEF0,
      .rbx = 0xFEDCBA9876543210,
      .rcx = 0xAAAAAAAABBBBBBBB,
      .rdx = 0xCCCCCCCCDDDDDDDD,
      .rdi = DATA_ADDR,  // safe base for SIB addressing in NOP
      .r8  = 0x1111111122222222,
      .r9  = 0x3333333344444444,
      .rflags = 0x2,
    };

    // 1-byte NOP: 90
    tests.push_back({"nop (1B)", cat, {0x90}, s, FL_ALL});

    // 2-byte NOP: 66 90
    tests.push_back({"nop (2B)", cat, {0x66, 0x90}, s, FL_ALL});

    // 3-byte NOP: 0F 1F 00
    tests.push_back({"nop (3B)", cat, {0x0F, 0x1F, 0x00}, s, FL_ALL});

    // 4-byte NOP: 0F 1F 40 00
    tests.push_back({"nop (4B)", cat, {0x0F, 0x1F, 0x40, 0x00}, s, FL_ALL});

    // 5-byte NOP: 0F 1F 44 00 00
    tests.push_back({"nop (5B)", cat, {0x0F, 0x1F, 0x44, 0x00, 0x00}, s, FL_ALL});

    // 6-byte NOP: 66 0F 1F 44 00 00
    tests.push_back({"nop (6B)", cat, {0x66, 0x0F, 0x1F, 0x44, 0x00, 0x00}, s, FL_ALL});

    // 7-byte NOP: 0F 1F 80 00 00 00 00
    tests.push_back({"nop (7B)", cat, {0x0F, 0x1F, 0x80, 0x00, 0x00, 0x00, 0x00}, s, FL_ALL});

    // 8-byte NOP: 0F 1F 84 00 00 00 00 00
    tests.push_back({"nop (8B)", cat, {0x0F, 0x1F, 0x84, 0x00, 0x00, 0x00, 0x00, 0x00}, s, FL_ALL});

    // 9-byte NOP: 66 0F 1F 84 00 00 00 00 00
    tests.push_back({"nop (9B)", cat, {0x66, 0x0F, 0x1F, 0x84, 0x00, 0x00, 0x00, 0x00, 0x00}, s, FL_ALL});

    // Chained: 3B + 5B + 1B NOPs in sequence
    tests.push_back({"nop chain (3+5+1)", cat,
                      {0x0F, 0x1F, 0x00,
                       0x0F, 0x1F, 0x44, 0x00, 0x00,
                       0x90}, s, FL_ALL});
  }

  // =====================================================================
  // Redundant prefix stacking
  // Tests interactions of multiple/redundant prefixes.
  // =====================================================================
  {
    cat = "Prefix";

    // 66 + REX.W: REX.W overrides the 66 operand-size prefix for non-mandatory-prefix insns
    // 66 48 01 D8: 66, REX.W(48), ADD r/m64,r64(01), ModRM D8(reg=rbx,rm=rax)
    // Should be 64-bit ADD (REX.W wins over 66)
    tests.push_back({"add rax,rbx (66+REX.W)", cat, {0x66, 0x48, 0x01, 0xD8},
                      {.rax = 0x100000000, .rbx = 0x200000000, .rflags = 0x2}, FL_ALL});

    // Double 66 prefix: 66 66 01 D8 = ADD AX, BX (redundant 66 should behave same as single)
    tests.push_back({"add ax,bx (double 66)", cat, {0x66, 0x66, 0x01, 0xD8},
                      {.rax = 0xDEAD0000BEEF7FFF, .rbx = 0x1234567800000001, .rflags = 0x2},
                      FL_ALL});

    // Address-size override (67) with memory operand: MOV EAX, [EDI]
    // 67 8B 07: 67 prefix, MOV r32,r/m32(8B), ModRM 07(mod=00,reg=eax,rm=edi)
    // Uses 32-bit address (truncates RDI to EDI)
    {
      std::vector<u8> data = {0x42, 0x43, 0x44, 0x45, 0, 0, 0, 0};
      tests.push_back({"mov eax,[edi] (67 prefix)", cat, {0x67, 0x8B, 0x07},
                        {.rax = 0xDEADDEADDEADDEAD, .rdi = DATA_ADDR, .rflags = 0x2},
                        FL_ALL, 0, false, data, 0});
    }

    // 67 + REX.W: 64-bit operand with 32-bit address
    // 67 48 8B 07: 67, REX.W(48), MOV r64,r/m64(8B), ModRM 07
    {
      std::vector<u8> data = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88};
      tests.push_back({"mov rax,[edi] (67+REX.W)", cat, {0x67, 0x48, 0x8B, 0x07},
                        {.rax = 0xDEADDEADDEADDEAD, .rdi = DATA_ADDR, .rflags = 0x2},
                        FL_ALL, 0, false, data, 0});
    }

    // REX prefix (no bits set) with byte register encoding:
    // 40 88 E0: REX(40), MOV r/m8,r8(88), ModRM E0(reg=ah->spl, rm=al->al)
    // Without REX: reg=4 means AH. With REX: reg=4 means SPL.
    // This tests that bare REX changes byte register mapping.
    // MOV AL, SPL -- copies low byte of RSP into AL
    // RSP is set by the harness, but we need a known value.
    // Instead, test with MOV to a register we control.
    // Use: 40 0F B6 C4 = REX MOVZX EAX, SPL
    // Actually, MOVZX is better: 40 0F B6 C4 (REX, MOVZX r32,r/m8, ModRM C4=reg=eax,rm=4=spl)
    // Hmm, SPL value depends on stack setup. Let's use BPL instead.
    // 40 0F B6 C5: REX MOVZX EAX, BPL (rm=5=bpl with REX)
    tests.push_back({"movzx eax,bpl (REX byte reg)", cat,
                      {0x40, 0x0F, 0xB6, 0xC5},
                      {.rax = 0xDEAD0000BEEF0000, .rbp = 0xABCDEF0123456789, .rflags = 0x2},
                      FL_ALL});

    // Without REX, same ModRM accesses CH:
    // 0F B6 C5: MOVZX EAX, CH (rm=5=ch without REX)
    tests.push_back({"movzx eax,ch (no REX byte reg)", cat,
                      {0x0F, 0xB6, 0xC5},
                      {.rax = 0xDEAD0000BEEF0000, .rcx = 0x123456789ABC00DE, .rflags = 0x2},
                      FL_ALL});
  }

  // =====================================================================
  // LZCNT / TZCNT — F3 mandatory prefix, all operand sizes, flag semantics
  // =====================================================================
  {
    cat = "LZCNT/TZCNT";

    // LZCNT: F3 0F BD /r
    // CF=1 if source is zero, ZF=1 if result is zero (i.e., MSB is set)

    // LZCNT 32-bit: value with MSB set -> result=0, ZF=1
    // F3 0F BD C0: LZCNT EAX, EAX
    tests.push_back({"lzcnt eax,eax msb", cat, {0xF3, 0x0F, 0xBD, 0xC0},
                      {.rax = 0x80000000, .rflags = 0x2}, FL_CF | FL_ZF});

    // LZCNT 32-bit: zero -> result=32, CF=1
    tests.push_back({"lzcnt eax,eax zero", cat, {0xF3, 0x0F, 0xBD, 0xC0},
                      {.rflags = 0x2}, FL_CF | FL_ZF});

    // LZCNT 32-bit: 1 -> result=31
    tests.push_back({"lzcnt eax,eax one", cat, {0xF3, 0x0F, 0xBD, 0xC0},
                      {.rax = 1, .rflags = 0x2}, FL_CF | FL_ZF});

    // LZCNT 64-bit: F3 REX.W 0F BD C0
    // bit 32 set -> lzcnt=31
    tests.push_back({"lzcnt rax,rax bit32", cat, {0xF3, 0x48, 0x0F, 0xBD, 0xC0},
                      {.rax = 0x0000000100000000, .rflags = 0x2}, FL_CF | FL_ZF});

    // LZCNT 64-bit: zero -> result=64, CF=1
    tests.push_back({"lzcnt rax,rax zero", cat, {0xF3, 0x48, 0x0F, 0xBD, 0xC0},
                      {.rflags = 0x2}, FL_CF | FL_ZF});

    // LZCNT 16-bit: 66 F3 0F BD C0
    // AX=0x0001, lzcnt16=15
    tests.push_back({"lzcnt ax,ax one", cat, {0x66, 0xF3, 0x0F, 0xBD, 0xC0},
                      {.rax = 0xDEAD000000000001, .rflags = 0x2}, FL_CF | FL_ZF});

    // LZCNT 16-bit: zero -> result=16, CF=1
    // AX=0x0000
    tests.push_back({"lzcnt ax,ax zero", cat, {0x66, 0xF3, 0x0F, 0xBD, 0xC0},
                      {.rax = 0xDEAD000000000000, .rflags = 0x2}, FL_CF | FL_ZF});

    // TZCNT: F3 0F BC /r
    // CF=1 if source is zero, ZF=1 if result is zero (i.e., LSB is set)

    // TZCNT 32-bit: LSB set -> result=0, ZF=1
    tests.push_back({"tzcnt eax,eax lsb", cat, {0xF3, 0x0F, 0xBC, 0xC0},
                      {.rax = 1, .rflags = 0x2}, FL_CF | FL_ZF});

    // TZCNT 32-bit: zero -> result=32, CF=1
    tests.push_back({"tzcnt eax,eax zero", cat, {0xF3, 0x0F, 0xBC, 0xC0},
                      {.rflags = 0x2}, FL_CF | FL_ZF});

    // TZCNT 32-bit: 0x80000000 -> result=31
    tests.push_back({"tzcnt eax,eax msb", cat, {0xF3, 0x0F, 0xBC, 0xC0},
                      {.rax = 0x80000000, .rflags = 0x2}, FL_CF | FL_ZF});

    // TZCNT 64-bit: bit 63 only -> result=63
    tests.push_back({"tzcnt rax,rax bit63", cat, {0xF3, 0x48, 0x0F, 0xBC, 0xC0},
                      {.rax = 0x8000000000000000, .rflags = 0x2}, FL_CF | FL_ZF});

    // TZCNT 16-bit: AX=0x8000 -> result=15
    tests.push_back({"tzcnt ax,ax msb16", cat, {0x66, 0xF3, 0x0F, 0xBC, 0xC0},
                      {.rax = 0xDEAD000000008000, .rflags = 0x2}, FL_CF | FL_ZF});

    // TZCNT with different src/dst regs: TZCNT EAX, EBX
    // F3 0F BC C3: TZCNT EAX, EBX (reg=eax, rm=ebx)
    // tzcnt=8
    tests.push_back({"tzcnt eax,ebx 0x100", cat, {0xF3, 0x0F, 0xBC, 0xC3},
                      {.rax = 0xFFFFFFFFFFFFFFFF, .rbx = 0x100, .rflags = 0x2}, FL_CF | FL_ZF});

    // --- Memory operand tests ---

    // LZCNT EAX, [RDI]: F3 0F BD 07
    // Memory contains 0x00010000 -> lzcnt32 = 15
    tests.push_back({"lzcnt eax,[rdi]", cat, {0xF3, 0x0F, 0xBD, 0x07},
                      {.rax = 0xDEADDEADDEADDEAD, .rdi = DATA_ADDR, .rflags = 0x2},
                      FL_CF | FL_ZF, 0, false,
                      {0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00}, 0});

    // LZCNT RAX, [RDI]: F3 48 0F BD 07
    // Memory contains 0x0000000100000000 -> lzcnt64 = 31
    tests.push_back({"lzcnt rax,[rdi]", cat, {0xF3, 0x48, 0x0F, 0xBD, 0x07},
                      {.rax = 0xDEADDEADDEADDEAD, .rdi = DATA_ADDR, .rflags = 0x2},
                      FL_CF | FL_ZF, 0, false,
                      {0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00}, 0});

    // TZCNT EAX, [RDI]: F3 0F BC 07
    // Memory contains 0x00000100 -> tzcnt32 = 8
    tests.push_back({"tzcnt eax,[rdi]", cat, {0xF3, 0x0F, 0xBC, 0x07},
                      {.rax = 0xDEADDEADDEADDEAD, .rdi = DATA_ADDR, .rflags = 0x2},
                      FL_CF | FL_ZF, 0, false,
                      {0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}, 0});

    // TZCNT RAX, [RDI]: F3 48 0F BC 07
    // Memory contains 0x8000000000000000 -> tzcnt64 = 63
    tests.push_back({"tzcnt rax,[rdi]", cat, {0xF3, 0x48, 0x0F, 0xBC, 0x07},
                      {.rax = 0xDEADDEADDEADDEAD, .rdi = DATA_ADDR, .rflags = 0x2},
                      FL_CF | FL_ZF, 0, false,
                      {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80}, 0});
  }

  // =====================================================================
  // POPCNT — F3 mandatory prefix, all operand sizes, flag semantics
  // =====================================================================
  {
    cat = "POPCNT";

    // POPCNT clears OF, SF, AF, CF, PF and sets ZF=1 if count==0
    // F3 0F B8 C0: POPCNT EAX, EAX

    // Zero input -> count=0, ZF=1
    tests.push_back({"popcnt eax,eax zero", cat, {0xF3, 0x0F, 0xB8, 0xC0},
                      {.rflags = 0x2 | FL_CF | FL_SF | FL_OF}, FL_ALL});

    // All bits set (32-bit) -> count=32
    tests.push_back({"popcnt eax,eax allones", cat, {0xF3, 0x0F, 0xB8, 0xC0},
                      {.rax = 0xFFFFFFFF, .rflags = 0x2}, FL_ALL});

    // Single bit -> count=1
    tests.push_back({"popcnt eax,eax msb", cat, {0xF3, 0x0F, 0xB8, 0xC0},
                      {.rax = 0x80000000, .rflags = 0x2}, FL_ALL});

    // Alternating bits (32-bit) -> count=16
    tests.push_back({"popcnt eax,eax alt", cat, {0xF3, 0x0F, 0xB8, 0xC0},
                      {.rax = 0x55555555, .rflags = 0x2}, FL_ALL});

    // 64-bit: F3 REX.W 0F B8 C0, count=64
    tests.push_back({"popcnt rax,rax allones64", cat, {0xF3, 0x48, 0x0F, 0xB8, 0xC0},
                      {.rax = 0xFFFFFFFFFFFFFFFF, .rflags = 0x2}, FL_ALL});

    // 16-bit: 66 F3 0F B8 C0, AX=0xFFFF, count=16
    tests.push_back({"popcnt ax,ax allones16", cat, {0x66, 0xF3, 0x0F, 0xB8, 0xC0},
                      {.rax = 0xDEAD00000000FFFF, .rflags = 0x2}, FL_ALL});

    // Different src/dst: POPCNT EAX, EBX, 3 bits set -> count=3
    tests.push_back({"popcnt eax,ebx 0x7", cat, {0xF3, 0x0F, 0xB8, 0xC3},
                      {.rax = 0xDEADDEADDEADDEAD, .rbx = 0x7, .rflags = 0x2}, FL_ALL});
  }

  // =====================================================================
  // BSF / BSR — zero input, flag semantics, all operand sizes
  // =====================================================================
  {
    cat = "BSF/BSR";

    // BSF: 0F BC /r -- scan forward (LSB to MSB)
    // The SDM defines only ZF (set if the source is zero) and leaves CF,
    // OF, SF, AF, PF and, for a zero source, the destination undefined.
    // The model fixes the de-facto behavior (see insn_baseline.sail):
    // CF/OF/SF/AF cleared, PF from the result's parity, destination
    // unchanged on a zero source.  These cases compare all of it.

    // BSF 32-bit: value=1 -> result=0
    // 0F BC C3: BSF EAX, EBX
    // Set all flags initially to verify they get cleared.
    tests.push_back({"bsf eax,ebx lsb", cat, {0x0F, 0xBC, 0xC3},
                      {.rbx = 1, .rflags = 0x2 | FL_CF | FL_OF | FL_SF | FL_AF}, FL_ALL});

    // BSF 32-bit: value=0x80000000 -> result=31
    tests.push_back({"bsf eax,ebx msb", cat, {0x0F, 0xBC, 0xC3},
                      {.rbx = 0x80000000, .rflags = 0x2 | FL_CF | FL_OF}, FL_ALL});

    // BSF 32-bit: zero -> ZF=1, dest should be unchanged
    tests.push_back({"bsf eax,ebx zero", cat, {0x0F, 0xBC, 0xC3},
                      {.rax = 0xDEADDEAD, .rflags = 0x2 | FL_CF | FL_SF}, FL_ALL});

    // BSF 32-bit: zero source with a nonzero upper half in the destination.
    // Both differential hosts (AMD Zen 4, Intel Emerald Rapids) leave the
    // whole 64-bit register untouched, upper half included, and the model
    // follows.  Linux's ffs() comment describes Intel as rewriting the old
    // value, which would clear the upper half; the Intel run shows it
    // does not.
    tests.push_back({"bsf eax,ebx zero hi32", cat, {0x0F, 0xBC, 0xC3},
                      {.rax = 0xFFFFFFFFDEADDEAD, .rflags = 0x2}, FL_ALL});

    // BSF 64-bit: bit 32 only
    // 48 0F BC C3: BSF RAX, RBX
    tests.push_back({"bsf rax,rbx bit32", cat, {0x48, 0x0F, 0xBC, 0xC3},
                      {.rbx = 0x0000000100000000, .rflags = 0x2 | FL_AF}, FL_ALL});

    // BSF 16-bit: 66 0F BC C3, BX=0x0100, bsf=8
    tests.push_back({"bsf ax,bx 0x100", cat, {0x66, 0x0F, 0xBC, 0xC3},
                      {.rbx = 0xDEAD000000000100, .rflags = 0x2 | FL_CF | FL_OF | FL_AF}, FL_ALL});

    // BSR: 0F BD /r -- scan reverse (MSB to LSB)
    // Same flag and destination rules as BSF.

    // BSR 32-bit: value=1 -> result=0
    // 0F BD C3: BSR EAX, EBX
    tests.push_back({"bsr eax,ebx lsb", cat, {0x0F, 0xBD, 0xC3},
                      {.rbx = 1, .rflags = 0x2 | FL_CF | FL_OF | FL_SF | FL_AF}, FL_ALL});

    // BSR 32-bit: value=0x80000000 -> result=31
    tests.push_back({"bsr eax,ebx msb", cat, {0x0F, 0xBD, 0xC3},
                      {.rbx = 0x80000000, .rflags = 0x2 | FL_CF | FL_OF}, FL_ALL});

    // BSR 32-bit: zero -> ZF=1
    tests.push_back({"bsr eax,ebx zero", cat, {0x0F, 0xBD, 0xC3},
                      {.rax = 0xDEADDEAD, .rflags = 0x2 | FL_CF | FL_SF}, FL_ALL});

    // BSR 32-bit: zero source, nonzero upper half in the destination
    tests.push_back({"bsr eax,ebx zero hi32", cat, {0x0F, 0xBD, 0xC3},
                      {.rax = 0xFFFFFFFFDEADDEAD, .rflags = 0x2}, FL_ALL});

    // BSR 64-bit
    tests.push_back({"bsr rax,rbx bit63", cat, {0x48, 0x0F, 0xBD, 0xC3},
                      {.rbx = 0x8000000000000000, .rflags = 0x2 | FL_AF}, FL_ALL});

    // BSR 32-bit: 0xFF -> result=7
    tests.push_back({"bsr eax,ebx 0xFF", cat, {0x0F, 0xBD, 0xC3},
                      {.rbx = 0xFF, .rflags = 0x2 | FL_CF | FL_OF | FL_AF}, FL_ALL});
  }

  // =====================================================================
  // BSWAP — 32-bit vs 64-bit, zero-extension
  // =====================================================================
  {
    cat = "BSWAP";

    // BSWAP EAX: 0F C8
    // 32-bit BSWAP: 12345678 -> 78563412, zero-extended to 64-bit
    tests.push_back({"bswap eax", cat, {0x0F, 0xC8},
                      {.rax = 0xDEADDEAD12345678, .rflags = 0x2}, FL_ALL});

    // BSWAP RAX: 48 0F C8
    tests.push_back({"bswap rax", cat, {0x48, 0x0F, 0xC8},
                      {.rax = 0x0102030405060708, .rflags = 0x2}, FL_ALL});

    // BSWAP with extended register R8: 49 0F C8 (REX.W+B, 0F C8+0=R8)
    tests.push_back({"bswap r8", cat, {0x49, 0x0F, 0xC8},
                      {.r8 = 0xAABBCCDDEEFF0011, .rflags = 0x2}, FL_ALL});

    // BSWAP R15D: 41 0F CF (REX.B, 0F C8+7)
    // 32-bit swap AABBCCDD -> DDCCBBAA, zero-extended
    tests.push_back({"bswap r15d", cat, {0x41, 0x0F, 0xCF},
                      {.r15 = 0xDEADDEADAABBCCDD, .rflags = 0x2}, FL_ALL});

    // BSWAP EAX where value is 0 -> stays 0
    tests.push_back({"bswap eax zero", cat, {0x0F, 0xC8},
                      {.rax = 0xDEADDEAD00000000, .rflags = 0x2}, FL_ALL});

    // BSWAP with value 0x01000000 -> 0x00000001
    tests.push_back({"bswap eax endian", cat, {0x0F, 0xC8},
                      {.rax = 0x01000000, .rflags = 0x2}, FL_ALL});

    // BSWAP AX (16-bit, 66h prefix): 66 0F C8
    // The result is undefined. Clear it before comparison, keeping all
    // unrelated register bits and flags observable.
    tests.push_back({"bswap ax (r16 undefined)", cat, {0x66, 0x0F, 0xC8},
                      {.rax = 0x0123456789ABCDEF, .rflags = 0x2}, FL_ALL});
    tests.back().code.insert(tests.back().code.end(), {0x66, 0xB8, 0, 0}); // mov ax,0

    // BSWAP R8W (16-bit, 66 REX.B): 66 41 0F C8
    tests.push_back({"bswap r8w (r16 undefined)", cat, {0x66, 0x41, 0x0F, 0xC8},
                      {.r8 = 0xFEDCBA9876543210, .rflags = 0x2}, FL_ALL});
    tests.back().code.insert(tests.back().code.end(), {0x66, 0x41, 0xB8, 0, 0}); // mov r8w,0
  }

  // =====================================================================
  // XCHG — register sizes, implicit RAX forms, extended registers
  // =====================================================================
  {
    cat = "XCHG";

    // XCHG EAX, EBX: 93 (opcode 90+3)
    // 32-bit: swaps and zero-extends both
    tests.push_back({"xchg eax,ebx", cat, {0x93},
                      {.rax = 0xDEAD000011111111, .rbx = 0xBEEF000022222222, .rflags = 0x2}, FL_ALL});

    // XCHG RAX, RBX: 48 93 (REX.W + 90+3)
    tests.push_back({"xchg rax,rbx", cat, {0x48, 0x93},
                      {.rax = 0x1111111111111111, .rbx = 0x2222222222222222, .rflags = 0x2}, FL_ALL});

    // XCHG AX, BX: 66 93
    // 16-bit: only swaps low 16 bits
    tests.push_back({"xchg ax,bx", cat, {0x66, 0x93},
                      {.rax = 0xDEAD0000BEEF1111, .rbx = 0x1234567800002222, .rflags = 0x2}, FL_ALL});

    // XCHG R8D, EAX: 41 90 (REX.B extends opcode register)
    tests.push_back({"xchg r8d,eax", cat, {0x41, 0x90},
                      {.rax = 0xDEAD000011111111, .r8 = 0xBEEF000022222222, .rflags = 0x2}, FL_ALL});

    // XCHG RAX, R8: 49 90 (REX.W+B)
    tests.push_back({"xchg rax,r8", cat, {0x49, 0x90},
                      {.rax = 0xAAAAAAAAAAAAAAAA, .r8 = 0xBBBBBBBBBBBBBBBB, .rflags = 0x2}, FL_ALL});

    // XCHG r/m form: 87 C3 = XCHG EBX, EAX (ModRM)
    tests.push_back({"xchg ebx,eax modrm", cat, {0x87, 0xC3},
                      {.rax = 0x11111111, .rbx = 0x22222222, .rflags = 0x2}, FL_ALL});

    // XCHG r/m8: 86 D8 = XCHG AL, BL
    tests.push_back({"xchg al,bl", cat, {0x86, 0xD8},
                      {.rax = 0xDEAD0000BEEF00AA, .rbx = 0x1234567800000055, .rflags = 0x2}, FL_ALL});
  }

  // =====================================================================
  // MOVSX / MOVSXD — sign-extension edge cases
  // =====================================================================
  {
    cat = "MOVSX/MOVSXD";

    // MOVSX EAX, BL: 0F BE C3 (sign-extend byte to dword)
    // BL=0x80 -> EAX=0xFFFFFF80, zero-extended to 64-bit
    tests.push_back({"movsx eax,bl neg", cat, {0x0F, 0xBE, 0xC3},
                      {.rax = 0xDEADDEADDEADDEAD, .rbx = 0x0000000000000080, .rflags = 0x2}, FL_ALL});

    // MOVSX EAX, BL: BL=0x7F -> EAX=0x0000007F
    tests.push_back({"movsx eax,bl pos", cat, {0x0F, 0xBE, 0xC3},
                      {.rax = 0xDEADDEADDEADDEAD, .rbx = 0x000000000000007F, .rflags = 0x2}, FL_ALL});

    // MOVSX RAX, BL: 48 0F BE C3 (sign-extend byte to qword)
    // -1 signed byte
    tests.push_back({"movsx rax,bl neg", cat, {0x48, 0x0F, 0xBE, 0xC3},
                      {.rax = 0xDEADDEADDEADDEAD, .rbx = 0x00000000000000FF, .rflags = 0x2}, FL_ALL});

    // MOVSX EAX, BX: 0F BF C3 (sign-extend word to dword)
    // -32768 signed word
    tests.push_back({"movsx eax,bx neg", cat, {0x0F, 0xBF, 0xC3},
                      {.rax = 0xDEADDEADDEADDEAD, .rbx = 0x0000000000008000, .rflags = 0x2}, FL_ALL});

    // MOVSX RAX, BX: 48 0F BF C3 (sign-extend word to qword)
    tests.push_back({"movsx rax,bx neg", cat, {0x48, 0x0F, 0xBF, 0xC3},
                      {.rax = 0xDEADDEADDEADDEAD, .rbx = 0x0000000000008000, .rflags = 0x2}, FL_ALL});

    // MOVSXD RAX, EBX: 48 63 C3 (sign-extend dword to qword)
    // -2147483648 signed dword
    tests.push_back({"movsxd rax,ebx neg", cat, {0x48, 0x63, 0xC3},
                      {.rax = 0xDEADDEADDEADDEAD, .rbx = 0x0000000080000000, .rflags = 0x2}, FL_ALL});

    // MOVSXD RAX, EBX: positive value
    tests.push_back({"movsxd rax,ebx pos", cat, {0x48, 0x63, 0xC3},
                      {.rax = 0xDEADDEADDEADDEAD, .rbx = 0x000000007FFFFFFF, .rflags = 0x2}, FL_ALL});

    // MOVSXD without REX.W (63 C3): acts as MOV EBX, EBX (no sign extend)
    tests.push_back({"movsxd eax,ebx no-rex.w", cat, {0x63, 0xC3},
                      {.rax = 0xDEADDEADDEADDEAD, .rbx = 0x0000000080000000, .rflags = 0x2}, FL_ALL});

    // MOVSX with R8-R15: 41 0F BE C0 = MOVSX EAX, R8B
    // -2 signed byte
    // Actually: 41 0F BE C0: REX.B, MOVSX EAX, r/m8 where rm=0+B=R8B
    tests.push_back({"movsx eax,r8b neg", cat, {0x41, 0x0F, 0xBE, 0xC0},
                      {.rax = 0xDEADDEADDEADDEAD, .r8 = 0x00000000000000FE, .rflags = 0x2}, FL_ALL});
  }

  // =====================================================================
  // BT/BTS/BTR/BTC — register and immediate forms
  // =====================================================================
  {
    cat = "BT/BTC";

    // BT r64, r64: 48 0F A3 D8 = BT RAX, RBX (test bit RBX in RAX)
    // Sets CF = bit at position (RBX mod 64)
    tests.push_back({"bt rax,rbx bit0 set", cat, {0x48, 0x0F, 0xA3, 0xD8},
                      {.rax = 0x0000000000000001, .rflags = 0x2}, FL_CF_ZF});

    // test bit 1 (not set)
    tests.push_back({"bt rax,rbx bit1 clear", cat, {0x48, 0x0F, 0xA3, 0xD8},
                      {.rax = 0x0000000000000001, .rbx = 1, .rflags = 0x2}, FL_CF_ZF});

    // BT r32, r32: 0F A3 D8 = BT EAX, EBX (bit index mod 32)
    tests.push_back({"bt eax,ebx bit31 set", cat, {0x0F, 0xA3, 0xD8},
                      {.rax = 0x80000000, .rbx = 31, .rflags = 0x2}, FL_CF_ZF});

    // BTS r64, r64: 48 0F AB D8 = BTS RAX, RBX (set bit)
    tests.push_back({"bts rax,rbx bit5", cat, {0x48, 0x0F, 0xAB, 0xD8},
                      {.rbx = 5, .rflags = 0x2}, FL_CF_ZF});

    // BTR r64, r64: 48 0F B3 D8 = BTR RAX, RBX (reset bit)
    tests.push_back({"btr rax,rbx bit63", cat, {0x48, 0x0F, 0xB3, 0xD8},
                      {.rax = 0xFFFFFFFFFFFFFFFF, .rbx = 63, .rflags = 0x2}, FL_CF_ZF});

    // BTC r64, r64: 48 0F BB D8 = BTC RAX, RBX (complement bit)
    tests.push_back({"btc rax,rbx bit10", cat, {0x48, 0x0F, 0xBB, 0xD8},
                      {.rbx = 10, .rflags = 0x2}, FL_CF_ZF});

    // BT r/m, imm8 (Group 8): 0F BA /4 ib
    // 48 0F BA E0 3F: BT RAX, 63
    tests.push_back({"bt rax,63 imm", cat, {0x48, 0x0F, 0xBA, 0xE0, 0x3F},
                      {.rax = 0x8000000000000000, .rflags = 0x2}, FL_CF_ZF});

    // BTS r/m, imm8: 48 0F BA E8 00 = BTS RAX, 0
    tests.push_back({"bts rax,0 imm", cat, {0x48, 0x0F, 0xBA, 0xE8, 0x00},
                      {.rflags = 0x2}, FL_CF_ZF});

    // BTR r/m, imm8: 48 0F BA F0 1F = BTR RAX, 31
    tests.push_back({"btr rax,31 imm", cat, {0x48, 0x0F, 0xBA, 0xF0, 0x1F},
                      {.rax = 0xFFFFFFFFFFFFFFFF, .rflags = 0x2}, FL_CF_ZF});

    // BTC r/m, imm8: 0F BA F8 07 = BTC EAX, 7
    tests.push_back({"btc eax,7 imm", cat, {0x0F, 0xBA, 0xF8, 0x07},
                      {.rax = 0x80, .rflags = 0x2}, FL_CF_ZF});

    // BT with bit index >= operand size (wraps via mod): BT EAX, EBX where EBX=32
    // Should test bit 32 mod 32 = bit 0
    tests.push_back({"bt eax,ebx wrap32", cat, {0x0F, 0xA3, 0xD8},
                      {.rax = 0x00000001, .rbx = 32, .rflags = 0x2}, FL_CF_ZF});
  }

  // =====================================================================
  // MOVBE — byte-swap load/store (0F 38 F0/F1)
  // =====================================================================
  {
    cat = "MOVBE";

    // MOVBE EAX, [RDI]: 0F 38 F0 07 (load 32-bit, byte-swap)
    // Memory: 01 02 03 04 -> EAX = 0x01020304 (big-endian to little-endian)
    {
      std::vector<u8> data = {0x01, 0x02, 0x03, 0x04, 0, 0, 0, 0};
      tests.push_back({"movbe eax,[rdi]", cat, {0x0F, 0x38, 0xF0, 0x07},
                        {.rax = 0xDEADDEADDEADDEAD, .rdi = DATA_ADDR, .rflags = 0x2},
                        FL_ALL, 0, false, data, 0});
    }

    // MOVBE RAX, [RDI]: 48 0F 38 F0 07 (load 64-bit, byte-swap)
    {
      std::vector<u8> data = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08};
      tests.push_back({"movbe rax,[rdi]", cat, {0x48, 0x0F, 0x38, 0xF0, 0x07},
                        {.rdi = DATA_ADDR, .rflags = 0x2},
                        FL_ALL, 0, false, data, 0});
    }

    // MOVBE AX, [RDI]: 66 0F 38 F0 07 (load 16-bit, byte-swap)
    {
      std::vector<u8> data = {0xAB, 0xCD, 0, 0, 0, 0, 0, 0};
      tests.push_back({"movbe ax,[rdi]", cat, {0x66, 0x0F, 0x38, 0xF0, 0x07},
                        {.rax = 0xDEADDEADDEADDEAD, .rdi = DATA_ADDR, .rflags = 0x2},
                        FL_ALL, 0, false, data, 0});
    }

    // MOVBE [RDI], EAX: 0F 38 F1 07 (store 32-bit, byte-swap)
    // Should store 04 03 02 01
    tests.push_back({"movbe [rdi],eax", cat, {0x0F, 0x38, 0xF1, 0x07},
                      {.rax = 0x01020304, .rdi = DATA_ADDR, .rflags = 0x2},
                      FL_ALL, 0, false, {}, 4});

    // MOVBE [RDI], RAX: 48 0F 38 F1 07 (store 64-bit, byte-swap)
    tests.push_back({"movbe [rdi],rax", cat, {0x48, 0x0F, 0x38, 0xF1, 0x07},
                      {.rax = 0x0102030405060708, .rdi = DATA_ADDR, .rflags = 0x2},
                      FL_ALL, 0, false, {}, 8});

    // MOVBE [RDI], AX: 66 0F 38 F1 07 (store 16-bit, byte-swap)
    tests.push_back({"movbe [rdi],ax", cat, {0x66, 0x0F, 0x38, 0xF1, 0x07},
                      {.rax = 0xDEADDEAD0000ABCD, .rdi = DATA_ADDR, .rflags = 0x2},
                      FL_ALL, 0, false, {}, 2});
  }

}

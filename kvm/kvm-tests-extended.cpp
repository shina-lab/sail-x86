#include "kvm-harness.h"

void add_extended_instruction_tests(std::vector<TestCase> &tests) {
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
    // SDM: ZF set if source is zero. CF, OF, SF, AF cleared.
    // PF set from source operand parity (low 8 bits).

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

    // BSF 64-bit: bit 32 only
    // 48 0F BC C3: BSF RAX, RBX
    tests.push_back({"bsf rax,rbx bit32", cat, {0x48, 0x0F, 0xBC, 0xC3},
                      {.rbx = 0x0000000100000000, .rflags = 0x2 | FL_AF}, FL_ALL});

    // BSF 16-bit: 66 0F BC C3, BX=0x0100, bsf=8
    tests.push_back({"bsf ax,bx 0x100", cat, {0x66, 0x0F, 0xBC, 0xC3},
                      {.rbx = 0xDEAD000000000100, .rflags = 0x2 | FL_CF | FL_OF | FL_AF}, FL_ALL});

    // BSR: 0F BD /r -- scan reverse (MSB to LSB)
    // SDM: same flag behavior as BSF.

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

    // BSR 64-bit
    tests.push_back({"bsr rax,rbx bit63", cat, {0x48, 0x0F, 0xBD, 0xC3},
                      {.rbx = 0x8000000000000000, .rflags = 0x2 | FL_AF}, FL_ALL});

    // BSR 32-bit: 0xFF -> result=7
    tests.push_back({"bsr eax,ebx 0xFF", cat, {0x0F, 0xBD, 0xC3},
                      {.rbx = 0xFF, .rflags = 0x2 | FL_CF | FL_OF | FL_AF}, FL_ALL});
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
  // BSWAP — 32-bit vs 64-bit, zero-extension
  // =====================================================================
  {
    cat = "BSWAP";

    // BSWAP EAX: 0F C8
    // 32-bit BSWAP: 12345678 -> 78563412, zero-extended to 64-bit
    tests.push_back({"bswap eax", cat, {0x0F, 0xC8},
                      {.rax = 0xDEADDEAD12345678, .rflags = 0x2}, FL_NONE});

    // BSWAP RAX: 48 0F C8
    tests.push_back({"bswap rax", cat, {0x48, 0x0F, 0xC8},
                      {.rax = 0x0102030405060708, .rflags = 0x2}, FL_NONE});

    // BSWAP with extended register R8: 49 0F C8 (REX.W+B, 0F C8+0=R8)
    tests.push_back({"bswap r8", cat, {0x49, 0x0F, 0xC8},
                      {.r8 = 0xAABBCCDDEEFF0011, .rflags = 0x2}, FL_NONE});

    // BSWAP R15D: 41 0F CF (REX.B, 0F C8+7)
    // 32-bit swap AABBCCDD -> DDCCBBAA, zero-extended
    tests.push_back({"bswap r15d", cat, {0x41, 0x0F, 0xCF},
                      {.r15 = 0xDEADDEADAABBCCDD, .rflags = 0x2}, FL_NONE});

    // BSWAP EAX where value is 0 -> stays 0
    tests.push_back({"bswap eax zero", cat, {0x0F, 0xC8},
                      {.rax = 0xDEADDEAD00000000, .rflags = 0x2}, FL_NONE});

    // BSWAP with value 0x01000000 -> 0x00000001
    tests.push_back({"bswap eax endian", cat, {0x0F, 0xC8},
                      {.rax = 0x01000000, .rflags = 0x2}, FL_NONE});
  }

  // =====================================================================
  // XCHG — register sizes, implicit RAX forms, extended registers
  // =====================================================================
  {
    cat = "XCHG";

    // XCHG EAX, EBX: 93 (opcode 90+3)
    // 32-bit: swaps and zero-extends both
    tests.push_back({"xchg eax,ebx", cat, {0x93},
                      {.rax = 0xDEAD000011111111, .rbx = 0xBEEF000022222222, .rflags = 0x2}, FL_NONE});

    // XCHG RAX, RBX: 48 93 (REX.W + 90+3)
    tests.push_back({"xchg rax,rbx", cat, {0x48, 0x93},
                      {.rax = 0x1111111111111111, .rbx = 0x2222222222222222, .rflags = 0x2}, FL_NONE});

    // XCHG AX, BX: 66 93
    // 16-bit: only swaps low 16 bits
    tests.push_back({"xchg ax,bx", cat, {0x66, 0x93},
                      {.rax = 0xDEAD0000BEEF1111, .rbx = 0x1234567800002222, .rflags = 0x2}, FL_NONE});

    // XCHG R8D, EAX: 41 90 (REX.B extends opcode register)
    tests.push_back({"xchg r8d,eax", cat, {0x41, 0x90},
                      {.rax = 0xDEAD000011111111, .r8 = 0xBEEF000022222222, .rflags = 0x2}, FL_NONE});

    // XCHG RAX, R8: 49 90 (REX.W+B)
    tests.push_back({"xchg rax,r8", cat, {0x49, 0x90},
                      {.rax = 0xAAAAAAAAAAAAAAAA, .r8 = 0xBBBBBBBBBBBBBBBB, .rflags = 0x2}, FL_NONE});

    // XCHG r/m form: 87 C3 = XCHG EBX, EAX (ModRM)
    tests.push_back({"xchg ebx,eax modrm", cat, {0x87, 0xC3},
                      {.rax = 0x11111111, .rbx = 0x22222222, .rflags = 0x2}, FL_NONE});

    // XCHG r/m8: 86 D8 = XCHG AL, BL
    tests.push_back({"xchg al,bl", cat, {0x86, 0xD8},
                      {.rax = 0xDEAD0000BEEF00AA, .rbx = 0x1234567800000055, .rflags = 0x2}, FL_NONE});
  }

  // =====================================================================
  // MOVSX / MOVSXD — sign-extension edge cases
  // =====================================================================
  {
    cat = "MOVSX/MOVSXD";

    // MOVSX EAX, BL: 0F BE C3 (sign-extend byte to dword)
    // BL=0x80 -> EAX=0xFFFFFF80, zero-extended to 64-bit
    tests.push_back({"movsx eax,bl neg", cat, {0x0F, 0xBE, 0xC3},
                      {.rax = 0xDEADDEADDEADDEAD, .rbx = 0x0000000000000080, .rflags = 0x2}, FL_NONE});

    // MOVSX EAX, BL: BL=0x7F -> EAX=0x0000007F
    tests.push_back({"movsx eax,bl pos", cat, {0x0F, 0xBE, 0xC3},
                      {.rax = 0xDEADDEADDEADDEAD, .rbx = 0x000000000000007F, .rflags = 0x2}, FL_NONE});

    // MOVSX RAX, BL: 48 0F BE C3 (sign-extend byte to qword)
    // -1 signed byte
    tests.push_back({"movsx rax,bl neg", cat, {0x48, 0x0F, 0xBE, 0xC3},
                      {.rax = 0xDEADDEADDEADDEAD, .rbx = 0x00000000000000FF, .rflags = 0x2}, FL_NONE});

    // MOVSX EAX, BX: 0F BF C3 (sign-extend word to dword)
    // -32768 signed word
    tests.push_back({"movsx eax,bx neg", cat, {0x0F, 0xBF, 0xC3},
                      {.rax = 0xDEADDEADDEADDEAD, .rbx = 0x0000000000008000, .rflags = 0x2}, FL_NONE});

    // MOVSX RAX, BX: 48 0F BF C3 (sign-extend word to qword)
    tests.push_back({"movsx rax,bx neg", cat, {0x48, 0x0F, 0xBF, 0xC3},
                      {.rax = 0xDEADDEADDEADDEAD, .rbx = 0x0000000000008000, .rflags = 0x2}, FL_NONE});

    // MOVSXD RAX, EBX: 48 63 C3 (sign-extend dword to qword)
    // -2147483648 signed dword
    tests.push_back({"movsxd rax,ebx neg", cat, {0x48, 0x63, 0xC3},
                      {.rax = 0xDEADDEADDEADDEAD, .rbx = 0x0000000080000000, .rflags = 0x2}, FL_NONE});

    // MOVSXD RAX, EBX: positive value
    tests.push_back({"movsxd rax,ebx pos", cat, {0x48, 0x63, 0xC3},
                      {.rax = 0xDEADDEADDEADDEAD, .rbx = 0x000000007FFFFFFF, .rflags = 0x2}, FL_NONE});

    // MOVSXD without REX.W (63 C3): acts as MOV EBX, EBX (no sign extend)
    tests.push_back({"movsxd eax,ebx no-rex.w", cat, {0x63, 0xC3},
                      {.rax = 0xDEADDEADDEADDEAD, .rbx = 0x0000000080000000, .rflags = 0x2}, FL_NONE});

    // MOVSX with R8-R15: 41 0F BE C0 = MOVSX EAX, R8B
    // -2 signed byte
    // Actually: 41 0F BE C0: REX.B, MOVSX EAX, r/m8 where rm=0+B=R8B
    tests.push_back({"movsx eax,r8b neg", cat, {0x41, 0x0F, 0xBE, 0xC0},
                      {.rax = 0xDEADDEADDEADDEAD, .r8 = 0x00000000000000FE, .rflags = 0x2}, FL_NONE});
  }

  // =====================================================================
  // BT/BTS/BTR/BTC — register and immediate forms
  // =====================================================================
  {
    cat = "BT/BTC";

    // BT r64, r64: 48 0F A3 D8 = BT RAX, RBX (test bit RBX in RAX)
    // Sets CF = bit at position (RBX mod 64)
    tests.push_back({"bt rax,rbx bit0 set", cat, {0x48, 0x0F, 0xA3, 0xD8},
                      {.rax = 0x0000000000000001, .rflags = 0x2}, FL_CF});

    // test bit 1 (not set)
    tests.push_back({"bt rax,rbx bit1 clear", cat, {0x48, 0x0F, 0xA3, 0xD8},
                      {.rax = 0x0000000000000001, .rbx = 1, .rflags = 0x2}, FL_CF});

    // BT r32, r32: 0F A3 D8 = BT EAX, EBX (bit index mod 32)
    tests.push_back({"bt eax,ebx bit31 set", cat, {0x0F, 0xA3, 0xD8},
                      {.rax = 0x80000000, .rbx = 31, .rflags = 0x2}, FL_CF});

    // BTS r64, r64: 48 0F AB D8 = BTS RAX, RBX (set bit)
    tests.push_back({"bts rax,rbx bit5", cat, {0x48, 0x0F, 0xAB, 0xD8},
                      {.rbx = 5, .rflags = 0x2}, FL_CF});

    // BTR r64, r64: 48 0F B3 D8 = BTR RAX, RBX (reset bit)
    tests.push_back({"btr rax,rbx bit63", cat, {0x48, 0x0F, 0xB3, 0xD8},
                      {.rax = 0xFFFFFFFFFFFFFFFF, .rbx = 63, .rflags = 0x2}, FL_CF});

    // BTC r64, r64: 48 0F BB D8 = BTC RAX, RBX (complement bit)
    tests.push_back({"btc rax,rbx bit10", cat, {0x48, 0x0F, 0xBB, 0xD8},
                      {.rbx = 10, .rflags = 0x2}, FL_CF});

    // BT r/m, imm8 (Group 8): 0F BA /4 ib
    // 48 0F BA E0 3F: BT RAX, 63
    tests.push_back({"bt rax,63 imm", cat, {0x48, 0x0F, 0xBA, 0xE0, 0x3F},
                      {.rax = 0x8000000000000000, .rflags = 0x2}, FL_CF});

    // BTS r/m, imm8: 48 0F BA E8 00 = BTS RAX, 0
    tests.push_back({"bts rax,0 imm", cat, {0x48, 0x0F, 0xBA, 0xE8, 0x00},
                      {.rflags = 0x2}, FL_CF});

    // BTR r/m, imm8: 48 0F BA F0 1F = BTR RAX, 31
    tests.push_back({"btr rax,31 imm", cat, {0x48, 0x0F, 0xBA, 0xF0, 0x1F},
                      {.rax = 0xFFFFFFFFFFFFFFFF, .rflags = 0x2}, FL_CF});

    // BTC r/m, imm8: 0F BA F8 07 = BTC EAX, 7
    tests.push_back({"btc eax,7 imm", cat, {0x0F, 0xBA, 0xF8, 0x07},
                      {.rax = 0x80, .rflags = 0x2}, FL_CF});

    // BT with bit index >= operand size (wraps via mod): BT EAX, EBX where EBX=32
    // Should test bit 32 mod 32 = bit 0
    tests.push_back({"bt eax,ebx wrap32", cat, {0x0F, 0xA3, 0xD8},
                      {.rax = 0x00000001, .rbx = 32, .rflags = 0x2}, FL_CF});
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
                        FL_NONE, 0, false, data, 0});
    }

    // MOVBE RAX, [RDI]: 48 0F 38 F0 07 (load 64-bit, byte-swap)
    {
      std::vector<u8> data = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08};
      tests.push_back({"movbe rax,[rdi]", cat, {0x48, 0x0F, 0x38, 0xF0, 0x07},
                        {.rdi = DATA_ADDR, .rflags = 0x2},
                        FL_NONE, 0, false, data, 0});
    }

    // MOVBE AX, [RDI]: 66 0F 38 F0 07 (load 16-bit, byte-swap)
    {
      std::vector<u8> data = {0xAB, 0xCD, 0, 0, 0, 0, 0, 0};
      tests.push_back({"movbe ax,[rdi]", cat, {0x66, 0x0F, 0x38, 0xF0, 0x07},
                        {.rax = 0xDEADDEADDEADDEAD, .rdi = DATA_ADDR, .rflags = 0x2},
                        FL_NONE, 0, false, data, 0});
    }

    // MOVBE [RDI], EAX: 0F 38 F1 07 (store 32-bit, byte-swap)
    // Should store 04 03 02 01
    tests.push_back({"movbe [rdi],eax", cat, {0x0F, 0x38, 0xF1, 0x07},
                      {.rax = 0x01020304, .rdi = DATA_ADDR, .rflags = 0x2},
                      FL_NONE, 0, false, {}, 4});

    // MOVBE [RDI], RAX: 48 0F 38 F1 07 (store 64-bit, byte-swap)
    tests.push_back({"movbe [rdi],rax", cat, {0x48, 0x0F, 0x38, 0xF1, 0x07},
                      {.rax = 0x0102030405060708, .rdi = DATA_ADDR, .rflags = 0x2},
                      FL_NONE, 0, false, {}, 8});

    // MOVBE [RDI], AX: 66 0F 38 F1 07 (store 16-bit, byte-swap)
    tests.push_back({"movbe [rdi],ax", cat, {0x66, 0x0F, 0x38, 0xF1, 0x07},
                      {.rax = 0xDEADDEAD0000ABCD, .rdi = DATA_ADDR, .rflags = 0x2},
                      FL_NONE, 0, false, {}, 2});
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
    // XMM0 = "abcd\0...", XMM1 = "xxbx\0..." → find 'b' at index 2
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(0x0000000064636261, 0);  // "abcd\0..."
      s.xmm[1] = xmm_from_u64(0x0000000078627878, 0);  // "xxbx\0..."
      // 66 0F 3A 63 C1 00: PCMPISTRI XMM0, XMM1, 0x00
      add_xmm("pcmpistri eq_any", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x00}, s, 0);
    }

    // PCMPISTRI: equal each (mode 0x08) — byte-by-byte compare
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

    // PCMPESTRI: explicit length — 66 0F 3A 61 C1 imm8
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

  // =====================================================================
  // EVEX 512-bit operations
  // =====================================================================
  {
    cat = "EVEX";

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
  // XSAVE / XRSTOR
  //   XSAVE [RDI]: 0F AE /4 → ModRM 00 100 111 = 0x27
  //   XRSTOR [RDI]: 0F AE /5 → ModRM 00 101 111 = 0x2F
  //   EDX:EAX = component mask (bit 0 = x87, bit 1 = SSE)
  // =====================================================================
  cat = "XSAVE/XRSTOR";
  {
    // Round-trip: XSAVE then PXOR to clear XMMs, then XRSTOR to restore.
    // Verifies XMM0 and XMM1 survive the round-trip.
    {
      ArchState s;
      s.rax = 3;
      s.rdi = DATA_ADDR;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(0x1234567890ABCDEF, 0xFEDCBA0987654321);
      s.xmm[1] = xmm_from_u64(0xAAAABBBBCCCCDDDD, 0xEEEEFFFF00001111);
      std::vector<u8> code = {
        0x0F, 0xAE, 0x27,             // XSAVE [RDI]
        0x66, 0x0F, 0xEF, 0xC0,       // PXOR XMM0, XMM0
        0x66, 0x0F, 0xEF, 0xC9,       // PXOR XMM1, XMM1
        0x0F, 0xAE, 0x2F,             // XRSTOR [RDI]
      };
      TestCase tc;
      tc.name = "xsave+xrstor round-trip (mask=3)";
      tc.category = cat;
      tc.code = std::move(code);
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x3;
      tc.cmp_mxcsr = true;
      tc.init_data = std::vector<u8>(576, 0);
      tests.push_back(std::move(tc));
    }

    // Round-trip with mask=2 (SSE only): XMM regs should survive.
    {
      ArchState s;
      s.rax = 2;
      s.rdi = DATA_ADDR;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(0xCAFEBABE12345678, 0x9876543210FEDCBA);
      s.xmm[5] = xmm_from_u64(0xDEADBEEFDEADBEEF, 0xFACEFACEFACEFACE);
      std::vector<u8> code = {
        0x0F, 0xAE, 0x27,             // XSAVE [RDI]
        0x66, 0x0F, 0xEF, 0xC0,       // PXOR XMM0, XMM0
        0x66, 0x0F, 0xEF, 0xED,       // PXOR XMM5, XMM5
        0x0F, 0xAE, 0x2F,             // XRSTOR [RDI]
      };
      TestCase tc;
      tc.name = "xsave+xrstor round-trip (mask=2, SSE only)";
      tc.category = cat;
      tc.code = std::move(code);
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = (1 << 0) | (1 << 5);
      tc.cmp_mxcsr = true;
      tc.init_data = std::vector<u8>(576, 0);
      tests.push_back(std::move(tc));
    }

    // XRSTOR with XSTATE_BV=3: load XMM0 from pre-built XSAVE area.
    {
      ArchState s;
      s.rax = 3;
      s.rdi = DATA_ADDR;
      s.rflags = 0x2;
      std::vector<u8> init_data(576, 0);
      // FCW = 0x037F
      init_data[0] = 0x7F;
      init_data[1] = 0x03;
      // MXCSR = 0x1F80
      init_data[0x18] = 0x80;
      init_data[0x19] = 0x1F;
      // MXCSR_MASK = 0x0002FFFF
      init_data[0x1C] = 0xFF;
      init_data[0x1D] = 0xFF;
      init_data[0x1E] = 0x02;
      // XMM0 at offset 0xA0
      u64 xmm0_lo = 0xCAFEBABE12345678;
      u64 xmm0_hi = 0x9876543210FEDCBA;
      memcpy(init_data.data() + 0xA0, &xmm0_lo, 8);
      memcpy(init_data.data() + 0xA8, &xmm0_hi, 8);
      // XSTATE_BV = 3
      init_data[0x200] = 3;
      TestCase tc;
      tc.name = "xrstor restore (xstate_bv=3)";
      tc.category = cat;
      tc.code = {0x0F, 0xAE, 0x2F};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x1;
      tc.cmp_mxcsr = true;
      tc.init_data = std::move(init_data);
      tests.push_back(std::move(tc));
    }

    // XRSTOR with XSTATE_BV=0: SSE init path should zero XMM regs.
    {
      ArchState s;
      s.rax = 3;
      s.rdi = DATA_ADDR;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(0xDEADBEEFDEADBEEF, 0xDEADBEEFDEADBEEF);
      std::vector<u8> init_data(576, 0);
      // XSTATE_BV = 0 (all init)
      TestCase tc;
      tc.name = "xrstor init (xstate_bv=0)";
      tc.category = cat;
      tc.code = {0x0F, 0xAE, 0x2F};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x1;  // XMM0 should become zero
      tc.init_data = std::move(init_data);
      tests.push_back(std::move(tc));
    }

    // XRSTOR with XSTATE_BV=1 (x87 only): SSE init, XMMs zeroed.
    {
      ArchState s;
      s.rax = 3;
      s.rdi = DATA_ADDR;
      s.rflags = 0x2;
      s.xmm[0] = xmm_from_u64(0x1111111111111111, 0x2222222222222222);
      std::vector<u8> init_data(576, 0);
      init_data[0] = 0x7F;
      init_data[1] = 0x03;
      init_data[0x18] = 0x80;
      init_data[0x19] = 0x1F;
      init_data[0x1C] = 0xFF;
      init_data[0x1D] = 0xFF;
      init_data[0x1E] = 0x02;
      // XSTATE_BV = 1 (x87 valid, SSE not)
      init_data[0x200] = 1;
      TestCase tc;
      tc.name = "xrstor partial (xstate_bv=1, SSE init)";
      tc.category = cat;
      tc.code = {0x0F, 0xAE, 0x2F};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x1;  // XMM0 should become zero
      tc.init_data = std::move(init_data);
      tests.push_back(std::move(tc));
    }

    // Round-trip with high XMM registers (XMM8-XMM15, needs REX).
    {
      ArchState s;
      s.rax = 3;
      s.rdi = DATA_ADDR;
      s.rflags = 0x2;
      s.xmm[8] = xmm_from_u64(0x8888888888888888, 0x9999999999999999);
      s.xmm[15] = xmm_from_u64(0xAAAAAAAAAAAAAAAA, 0xBBBBBBBBBBBBBBBB);
      // PXOR XMM8,XMM8: 66 45 0F EF C0
      // PXOR XMM15,XMM15: 66 45 0F EF FF
      std::vector<u8> code = {
        0x0F, 0xAE, 0x27,                   // XSAVE [RDI]
        0x66, 0x45, 0x0F, 0xEF, 0xC0,       // PXOR XMM8, XMM8
        0x66, 0x45, 0x0F, 0xEF, 0xFF,       // PXOR XMM15, XMM15
        0x0F, 0xAE, 0x2F,                   // XRSTOR [RDI]
      };
      TestCase tc;
      tc.name = "xsave+xrstor round-trip (high XMM regs)";
      tc.category = cat;
      tc.code = std::move(code);
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = (1 << 8) | (1 << 15);
      tc.init_data = std::vector<u8>(576, 0);
      tests.push_back(std::move(tc));
    }
  }
}


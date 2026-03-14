#include "kvm-harness.h"

void add_exception_tests(std::vector<TestCase> &tests) {
  std::string cat;

  auto add_fault = [&](const std::string &name, std::vector<u8> code, ArchState init,
                       int vec) {
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = std::move(code);
    tc.initial = init;
    tc.flags_mask = 0;
    tc.expect_fault = true;
    tc.expected_vector = vec;
    tests.push_back(std::move(tc));
  };

  // =====================================================================
  // Exception/Fault tests
  // =====================================================================

  // ---- #DE (vector 0): Division error ----
  cat = "Exception #DE";

  // DIV by zero — all sizes
  add_fault("div rcx (div by zero, 64-bit)", {0x48, 0xF7, 0xF1},
            {.rax = 42, .rflags = 0x2}, 0);
  add_fault("div ecx (div by zero, 32-bit)", {0xF7, 0xF1},
            {.rax = 42, .rflags = 0x2}, 0);
  add_fault("div cx (div by zero, 16-bit)", {0x66, 0xF7, 0xF1},
            {.rax = 42, .rflags = 0x2}, 0);
  add_fault("div cl (div by zero, 8-bit)", {0xF6, 0xF1},
            {.rax = 42, .rflags = 0x2}, 0);

  // IDIV by zero — all sizes
  add_fault("idiv rcx (div by zero, 64-bit)", {0x48, 0xF7, 0xF9},
            {.rax = 42, .rflags = 0x2}, 0);
  add_fault("idiv ecx (div by zero, 32-bit)", {0xF7, 0xF9},
            {.rax = 42, .rflags = 0x2}, 0);
  add_fault("idiv cx (div by zero, 16-bit)", {0x66, 0xF7, 0xF9},
            {.rax = 42, .rflags = 0x2}, 0);
  add_fault("idiv cl (div by zero, 8-bit)", {0xF6, 0xF9},
            {.rax = 42, .rflags = 0x2}, 0);

  // DIV quotient overflow

  // 8-bit: AX=0x100, CL=1 → quotient 256 doesn't fit in AL
  add_fault("div cl (quotient overflow, 8-bit)", {0xF6, 0xF1},
            {.rax = 0x100, .rcx = 1, .rflags = 0x2}, 0);

  // 32-bit: EDX:EAX = 0x1_00000000, ECX=1 → quotient overflows 32 bits
  add_fault("div ecx (quotient overflow, 32-bit)", {0xF7, 0xF1},
            {.rcx = 1, .rdx = 1, .rflags = 0x2}, 0);

  // 64-bit: RDX:RAX = 2^64, RCX=1 → quotient overflows 64 bits
  add_fault("div rcx (quotient overflow, 64-bit)", {0x48, 0xF7, 0xF1},
            {.rcx = 1, .rdx = 1, .rflags = 0x2}, 0);

  // DIV quotient overflow — 16-bit
  // DX:AX = 0x10000, CX=1 → quotient 65536 > UINT16_MAX
  add_fault("div cx (quotient overflow, 16-bit)", {0x66, 0xF7, 0xF1},
            {.rcx = 1, .rdx = 1, .rflags = 0x2}, 0);

  // IDIV quotient overflow

  // 8-bit: AX=0x80, CL=1 → quotient 128 > INT8_MAX (127)
  add_fault("idiv cl (quotient overflow, 8-bit)", {0xF6, 0xF9},
            {.rax = 0x80, .rcx = 1, .rflags = 0x2}, 0);

  // 32-bit: EDX=0, EAX=0x80000000, ECX=1 → quotient 0x80000000 > INT32_MAX
  add_fault("idiv ecx (quotient overflow, 32-bit)", {0xF7, 0xF9},
            {.rax = 0x80000000, .rcx = 1, .rflags = 0x2}, 0);

  // 64-bit: RDX=0, RAX=0x8000000000000000, RCX=1
  add_fault("idiv rcx (quotient overflow, 64-bit)", {0x48, 0xF7, 0xF9},
            {.rax = 0x8000000000000000ULL, .rcx = 1, .rflags = 0x2}, 0);

  // IDIV by -1 overflow: most negative / -1 overflows
  // 32-bit: EDX:EAX = 0xFFFFFFFF:80000000 (-2147483648), ECX=0xFFFFFFFF (-1)
  // quotient would be INT32_MIN / -1 = 2147483648 > INT32_MAX
  add_fault("idiv ecx (INT32_MIN / -1 overflow)", {0xF7, 0xF9},
            {.rax = 0x80000000, .rcx = 0xFFFFFFFF, .rdx = 0xFFFFFFFF, .rflags = 0x2}, 0);

  // ---- #UD (vector 6): Invalid opcode ----
  cat = "Exception #UD";

  add_fault("ud2", {0x0F, 0x0B}, {.rflags = 0x2}, 6);

  // UD1 (0F B9): explicit undefined instruction with ModRM
  add_fault("ud1 (0F B9)", {0x0F, 0xB9, 0xC0}, {.rflags = 0x2}, 6);

  // LOCK ADD RAX, RBX: F0 48 01 D8 — register destination, #UD
  add_fault("lock add rax,rbx (reg dest → #UD)", {0xF0, 0x48, 0x01, 0xD8},
            {.rax = 1, .rbx = 2, .rflags = 0x2}, 6);

  // LOCK CMP [RDI], RAX: F0 48 39 07 — CMP doesn't write, #UD even with mem
  add_fault("lock cmp [rdi],rax (CMP not lockable → #UD)", {0xF0, 0x48, 0x39, 0x07},
            {.rdi = DATA_ADDR, .rflags = 0x2}, 6);

  // LOCK MOV RAX, RBX: F0 48 89 D8 — MOV is not lockable, #UD
  add_fault("lock mov rax,rbx (non-lockable → #UD)", {0xF0, 0x48, 0x89, 0xD8},
            {.rflags = 0x2}, 6);

  // LOCK NOP: F0 90 — NOP is not lockable, #UD
  add_fault("lock nop (non-lockable → #UD)", {0xF0, 0x90},
            {.rflags = 0x2}, 6);

  // ---- #GP (vector 13): General protection fault ----
  cat = "Exception #GP";

  // SSE MOVAPS/MOVAPD load unaligned
  add_fault("movaps xmm0,[rdi] load (unaligned → #GP)", {0x0F, 0x28, 0x07},
            {.rdi = DATA_ADDR + 1, .rflags = 0x2}, 13);
  add_fault("movapd xmm0,[rdi] load (unaligned → #GP)", {0x66, 0x0F, 0x28, 0x07},
            {.rdi = DATA_ADDR + 3, .rflags = 0x2}, 13);

  // SSE MOVAPS/MOVAPD store unaligned
  // MOVAPS [RDI], XMM0: 0F 29 07
  add_fault("movaps [rdi],xmm0 store (unaligned → #GP)", {0x0F, 0x29, 0x07},
            {.rdi = DATA_ADDR + 1, .rflags = 0x2}, 13);

  // MOVAPD [RDI], XMM0: 66 0F 29 07
  add_fault("movapd [rdi],xmm0 store (unaligned → #GP)", {0x66, 0x0F, 0x29, 0x07},
            {.rdi = DATA_ADDR + 5, .rflags = 0x2}, 13);

  // VEX VMOVAPS load unaligned (128-bit)
  // VMOVAPS XMM0, [RDI]: C5 F8 28 07
  add_fault("vmovaps xmm0,[rdi] load (unaligned → #GP)", {0xC5, 0xF8, 0x28, 0x07},
            {.rdi = DATA_ADDR + 1, .rflags = 0x2}, 13);

  // VEX VMOVAPS store unaligned (128-bit)
  // VMOVAPS [RDI], XMM0: C5 F8 29 07
  add_fault("vmovaps [rdi],xmm0 store (unaligned → #GP)", {0xC5, 0xF8, 0x29, 0x07},
            {.rdi = DATA_ADDR + 7, .rflags = 0x2}, 13);

  // VEX VMOVAPD load unaligned (128-bit)
  // VMOVAPD XMM0, [RDI]: C5 F9 28 07
  add_fault("vmovapd xmm0,[rdi] load (unaligned → #GP)", {0xC5, 0xF9, 0x28, 0x07},
            {.rdi = DATA_ADDR + 2, .rflags = 0x2}, 13);

  // VEX VMOVAPS load unaligned (256-bit, 32-byte alignment required)
  // VMOVAPS YMM0, [RDI]: C5 FC 28 07 (VEX.256.NP)
  add_fault("vmovaps ymm0,[rdi] load (16-aligned, not 32 → #GP)", {0xC5, 0xFC, 0x28, 0x07},
            {.rdi = DATA_ADDR + 16, .rflags = 0x2}, 13);  // 16-byte aligned but not 32-byte aligned

  // VEX VMOVAPD store unaligned (128-bit)
  // VMOVAPD [RDI], XMM0: C5 F9 29 07
  add_fault("vmovapd [rdi],xmm0 store (unaligned → #GP)", {0xC5, 0xF9, 0x29, 0x07},
            {.rdi = DATA_ADDR + 3, .rflags = 0x2}, 13);

  // VEX VMOVAPD load unaligned (256-bit, 32-byte alignment required)
  // VMOVAPD YMM0, [RDI]: C5 FD 28 07
  add_fault("vmovapd ymm0,[rdi] load (16-aligned, not 32 → #GP)", {0xC5, 0xFD, 0x28, 0x07},
            {.rdi = DATA_ADDR + 16, .rflags = 0x2}, 13);  // 16-byte aligned but not 32-byte aligned

  // VEX VMOVAPS store unaligned (256-bit)
  // VMOVAPS [RDI], YMM0: C5 FC 29 07
  add_fault("vmovaps [rdi],ymm0 store (16-aligned, not 32 → #GP)", {0xC5, 0xFC, 0x29, 0x07},
            {.rdi = DATA_ADDR + 16, .rflags = 0x2}, 13);

  // VEX VMOVAPD store unaligned (256-bit)
  // VMOVAPD [RDI], YMM0: C5 FD 29 07
  add_fault("vmovapd [rdi],ymm0 store (16-aligned, not 32 → #GP)", {0xC5, 0xFD, 0x29, 0x07},
            {.rdi = DATA_ADDR + 16, .rflags = 0x2}, 13);

  // VEX VMOVDQA load unaligned (128-bit)
  // VMOVDQA XMM0, [RDI]: C5 F9 6F 07
  add_fault("vmovdqa xmm0,[rdi] load (unaligned → #GP)", {0xC5, 0xF9, 0x6F, 0x07},
            {.rdi = DATA_ADDR + 1, .rflags = 0x2}, 13);

  // VEX VMOVDQA store unaligned (128-bit)
  // VMOVDQA [RDI], XMM0: C5 F9 7F 07
  add_fault("vmovdqa [rdi],xmm0 store (unaligned → #GP)", {0xC5, 0xF9, 0x7F, 0x07},
            {.rdi = DATA_ADDR + 1, .rflags = 0x2}, 13);

  // VEX VMOVNTDQ store unaligned (128-bit)
  // VMOVNTDQ [RDI], XMM0: C5 F9 E7 07
  add_fault("vmovntdq [rdi],xmm0 store (unaligned → #GP)", {0xC5, 0xF9, 0xE7, 0x07},
            {.rdi = DATA_ADDR + 1, .rflags = 0x2}, 13);

  // VEX VMOVNTPS store unaligned (128-bit)
  // VMOVNTPS [RDI], XMM0: C5 F8 2B 07
  add_fault("vmovntps [rdi],xmm0 store (unaligned → #GP)", {0xC5, 0xF8, 0x2B, 0x07},
            {.rdi = DATA_ADDR + 1, .rflags = 0x2}, 13);

  // ---- More #UD tests: LOCK on 2-byte opcodes ----
  cat = "Exception #UD";

  // LOCK MOVZX EAX, BL: F0 0F B6 C3 — MOVZX not lockable, #UD
  add_fault("lock movzx eax,bl (2-byte non-lockable → #UD)", {0xF0, 0x0F, 0xB6, 0xC3},
            {.rbx = 0x42, .rflags = 0x2}, 6);

  // LOCK BSF EAX, EBX: F0 0F BC C3 — BSF not lockable, #UD
  add_fault("lock bsf eax,ebx (2-byte non-lockable → #UD)", {0xF0, 0x0F, 0xBC, 0xC3},
            {.rbx = 0x100, .rflags = 0x2}, 6);

  // LOCK CMPXCHG EAX, EBX: F0 0F B1 D8 — reg dest on lockable 2-byte, #UD
  // CMPXCHG r/m, r: ModRM D8 = 11 011 000 = reg, reg=EBX, rm=EAX
  add_fault("lock cmpxchg eax,ebx (reg dest → #UD)", {0xF0, 0x0F, 0xB1, 0xD8},
            {.rax = 1, .rbx = 2, .rflags = 0x2}, 6);

  // LOCK XADD EAX, EBX: F0 0F C1 D8 — reg dest on lockable 2-byte, #UD
  add_fault("lock xadd eax,ebx (reg dest → #UD)", {0xF0, 0x0F, 0xC1, 0xD8},
            {.rax = 1, .rbx = 2, .rflags = 0x2}, 6);

  // LOCK INC EAX: F0 FF C0 — INC with register dest, #UD
  // FF C0 = ModRM 11 000 000 = /0, rm=EAX (register)
  add_fault("lock inc eax (reg dest → #UD)", {0xF0, 0xFF, 0xC0},
            {.rax = 42, .rflags = 0x2}, 6);

  // LOCK NEG EAX: F0 F7 D8 — NEG with register dest, #UD
  // F7 D8 = ModRM 11 011 000 = /3, rm=EAX (register)
  add_fault("lock neg eax (reg dest → #UD)", {0xF0, 0xF7, 0xD8},
            {.rax = 42, .rflags = 0x2}, 6);

  // LOCK MUL EAX: F0 F7 E0 — MUL (/4) not lockable even as Group 3, #UD
  // F7 E0 = ModRM 11 100 000 = /4, rm=EAX
  add_fault("lock mul eax (MUL not lockable → #UD)", {0xF0, 0xF7, 0xE0},
            {.rax = 2, .rflags = 0x2}, 6);

  // LOCK DIV ECX: F0 F7 F1 — DIV (/6) not lockable, #UD
  add_fault("lock div ecx (DIV not lockable → #UD)", {0xF0, 0xF7, 0xF1},
            {.rax = 42, .rcx = 7, .rflags = 0x2}, 6);

  // LOCK PUSH RAX: F0 50 — PUSH not lockable, #UD
  add_fault("lock push rax (non-lockable → #UD)", {0xF0, 0x50},
            {.rax = 42, .rflags = 0x2}, 6);

  // ---- VEX.L=1 on 128-bit-only instructions → #UD ----
  // VEX 2-byte prefix byte2: R̃ vvvv L pp
  // L=0: F8(NP), F9(66), FA(F3), FB(F2)
  // L=1: FC(NP), FD(66), FE(F3), FF(F2)

  // VPINSRW xmm0,xmm0,ecx,0 with VEX.L=1: C5 FD C4 C1 00
  // Normal (L=0): C5 F9 C4 C1 00
  add_fault("vpinsrw L=1 (128-bit only → #UD)", {0xC5, 0xFD, 0xC4, 0xC1, 0x00},
            {.rcx = 0x1234, .rflags = 0x2}, 6);

  {
    // VPEXTRW eax,xmm1,0 with VEX.L=1: C5 FD C5 C1 00
    // Normal (L=0): C5 F9 C5 C1 00
    ArchState s = {.rflags = 0x2};
    s.xmm[1] = xmm_from_u64(0x0011223344556677, 0x8899AABBCCDDEEFF);
    add_fault("vpextrw L=1 (128-bit only → #UD)", {0xC5, 0xFD, 0xC5, 0xC1, 0x00}, s, 6);
  }

  // VMOVD xmm0,ecx with VEX.L=1: C5 FD 6E C1
  // Normal (L=0): C5 F9 6E C1
  add_fault("vmovd xmm,r32 L=1 (128-bit only → #UD)", {0xC5, 0xFD, 0x6E, 0xC1},
            {.rcx = 0x12345678, .rflags = 0x2}, 6);

  {
    // VMOVD ecx,xmm0 with VEX.L=1: C5 FD 7E C1
    // Normal (L=0): C5 F9 7E C1
    ArchState s = {.rflags = 0x2};
    s.xmm[0] = xmm_from_u64(0x12345678, 0);
    add_fault("vmovd r32,xmm L=1 (128-bit only → #UD)", {0xC5, 0xFD, 0x7E, 0xC1}, s, 6);
  }

  // NOTE: Scalar instructions (VUCOMISS, VCVTSI2SS, VCVTTSS2SI, etc.)
  // do NOT #UD with VEX.L=1 on real hardware — the L bit is ignored.

  // ---- VEX.vvvv reserved (must be 1111b) → #UD ----
  // VEX byte2: R̃ vvvv L pp
  // vvvv=1111 → reserved OK (byte2 upper nibble F)
  // vvvv=1110 → register 1, not reserved (byte2 upper nibble E + R̃ bit)
  // C5 F8 = R̃=1 vvvv=1111 L=0 pp=00(NP)  → valid
  // C5 F0 = R̃=1 vvvv=1110 L=0 pp=00(NP)  → vvvv not reserved
  // C5 F1 = R̃=1 vvvv=1110 L=0 pp=01(66)  → vvvv not reserved

  // VMOVAPS xmm0,[mem] with vvvv!=1111: C5 F0 28 07 (via [rdi])
  add_fault("vmovaps load vvvv!=0 → #UD", {0xC5, 0xF0, 0x28, 0x07},
            {.rdi = DATA_ADDR, .rflags = 0x2}, 6);

  // VMOVAPD xmm0,[mem] with vvvv!=1111: C5 F1 28 07
  add_fault("vmovapd load vvvv!=0 → #UD", {0xC5, 0xF1, 0x28, 0x07},
            {.rdi = DATA_ADDR, .rflags = 0x2}, 6);

  // VMOVAPS [mem],xmm0 with vvvv!=1111: C5 F0 29 07
  add_fault("vmovaps store vvvv!=0 → #UD", {0xC5, 0xF0, 0x29, 0x07},
            {.rdi = DATA_ADDR, .rflags = 0x2}, 6);

  // VMOVDQA xmm0,[mem] with vvvv!=1111: C5 F1 6F 07
  add_fault("vmovdqa load vvvv!=0 → #UD", {0xC5, 0xF1, 0x6F, 0x07},
            {.rdi = DATA_ADDR, .rflags = 0x2}, 6);

  // VMOVDQU xmm0,[mem] with vvvv!=1111: C5 F2 6F 07 (pp=F3)
  // C5 FA = R̃=1 vvvv=1111 L=0 pp=10(F3); C5 F2 = vvvv=1110
  add_fault("vmovdqu load vvvv!=0 → #UD", {0xC5, 0xF2, 0x6F, 0x07},
            {.rdi = DATA_ADDR, .rflags = 0x2}, 6);

  // VMOVDQA [mem],xmm0 with vvvv!=1111: C5 F1 7F 07
  add_fault("vmovdqa store vvvv!=0 → #UD", {0xC5, 0xF1, 0x7F, 0x07},
            {.rdi = DATA_ADDR, .rflags = 0x2}, 6);

  // VMOVDQU [mem],xmm0 with vvvv!=1111: C5 F2 7F 07
  add_fault("vmovdqu store vvvv!=0 → #UD", {0xC5, 0xF2, 0x7F, 0x07},
            {.rdi = DATA_ADDR, .rflags = 0x2}, 6);

  // VUCOMISS xmm0,xmm1 with vvvv!=1111: C5 F0 2E C1
  add_fault("vucomiss vvvv!=0 → #UD", {0xC5, 0xF0, 0x2E, 0xC1},
            {.rflags = 0x2}, 6);

  // VUCOMISD xmm0,xmm1 with vvvv!=1111: C5 F1 2E C1
  add_fault("vucomisd vvvv!=0 → #UD", {0xC5, 0xF1, 0x2E, 0xC1},
            {.rflags = 0x2}, 6);

  // VCOMISS xmm0,xmm1 with vvvv!=1111: C5 F0 2F C1
  add_fault("vcomiss vvvv!=0 → #UD", {0xC5, 0xF0, 0x2F, 0xC1},
            {.rflags = 0x2}, 6);

  // VCOMISD xmm0,xmm1 with vvvv!=1111: C5 F1 2F C1
  add_fault("vcomisd vvvv!=0 → #UD", {0xC5, 0xF1, 0x2F, 0xC1},
            {.rflags = 0x2}, 6);

  // VCVTPS2PD xmm0,xmm1 with vvvv!=1111: C5 F0 5A C1
  add_fault("vcvtps2pd vvvv!=0 → #UD", {0xC5, 0xF0, 0x5A, 0xC1},
            {.rflags = 0x2}, 6);

  // VCVTPD2PS xmm0,xmm1 with vvvv!=1111: C5 F1 5A C1
  add_fault("vcvtpd2ps vvvv!=0 → #UD", {0xC5, 0xF1, 0x5A, 0xC1},
            {.rflags = 0x2}, 6);

  // VZEROUPPER with vvvv!=1111: C5 F0 77
  // Normal: C5 F8 77
  add_fault("vzeroupper vvvv!=0 → #UD", {0xC5, 0xF0, 0x77},
            {.rflags = 0x2}, 6);

  // VBROADCASTSS xmm0,[mem] with vvvv!=1111: C4 E2 F1 18 07
  // 3-byte VEX: C4 E2 [W vvvv L pp]
  // Normal: C4 E2 79 18 07 (W=0 vvvv=1111 L=0 pp=01)
  // Bad:    C4 E2 71 18 07 (W=0 vvvv=1110 L=0 pp=01)
  add_fault("vbroadcastss vvvv!=0 → #UD", {0xC4, 0xE2, 0x71, 0x18, 0x07},
            {.rdi = DATA_ADDR, .rflags = 0x2}, 6);

  // VMOVUPS xmm0,[mem] with vvvv!=1111: C5 F0 10 07
  // Normal: C5 F8 10 07
  add_fault("vmovups load vvvv!=0 → #UD", {0xC5, 0xF0, 0x10, 0x07},
            {.rdi = DATA_ADDR, .rflags = 0x2}, 6);

  // VMOVUPS [mem],xmm0 with vvvv!=1111: C5 F0 11 07
  add_fault("vmovups store vvvv!=0 → #UD", {0xC5, 0xF0, 0x11, 0x07},
            {.rdi = DATA_ADDR, .rflags = 0x2}, 6);

  // VCVTDQ2PS xmm0,xmm1 with vvvv!=1111: C5 F0 5B C1
  // Normal: C5 F8 5B C1 (NP = VCVTDQ2PS)
  add_fault("vcvtdq2ps vvvv!=0 → #UD", {0xC5, 0xF0, 0x5B, 0xC1},
            {.rflags = 0x2}, 6);

  // VCVTPS2DQ xmm0,xmm1 with vvvv!=1111: C5 F1 5B C1
  // Normal: C5 F9 5B C1 (66 = VCVTPS2DQ)
  add_fault("vcvtps2dq vvvv!=0 → #UD", {0xC5, 0xF1, 0x5B, 0xC1},
            {.rflags = 0x2}, 6);

  // VBROADCASTSD ymm0,[mem] with vvvv!=1111: C4 E2 71 19 07
  // Normal: C4 E2 7D 19 07 (W=0 vvvv=1111 L=1 pp=01)
  // Bad:    C4 E2 75 19 07 (W=0 vvvv=1110 L=1 pp=01)
  add_fault("vbroadcastsd vvvv!=0 → #UD", {0xC4, 0xE2, 0x75, 0x19, 0x07},
            {.rdi = DATA_ADDR, .rflags = 0x2}, 6);

  // VPBROADCASTD xmm0,xmm1 with vvvv!=1111: C4 E2 71 58 C1
  // Normal: C4 E2 79 58 C1 (W=0 vvvv=1111 L=0 pp=01)
  add_fault("vpbroadcastd vvvv!=0 → #UD", {0xC4, 0xE2, 0x71, 0x58, 0xC1},
            {.rflags = 0x2}, 6);

  // VCVTPH2PS xmm0,xmm1 with vvvv!=1111: C4 E2 71 13 C1
  // Normal: C4 E2 79 13 C1 (W=0 vvvv=1111 L=0 pp=01)
  add_fault("vcvtph2ps vvvv!=0 → #UD", {0xC4, 0xE2, 0x71, 0x13, 0xC1},
            {.rflags = 0x2}, 6);

  // ---- Memory-only instructions with register form → #UD ----

  // VBROADCASTF128 ymm0,xmm0 (register form): C4 E2 7D 1A C0
  // 3-byte VEX: C4 [R̃XB=E2] [W=0 vvvv=1111 L=1 pp=01 = 7D]
  // ModRM C0 = mod=11 (reg), reg=0, rm=0
  add_fault("vbroadcastf128 reg form → #UD", {0xC4, 0xE2, 0x7D, 0x1A, 0xC0},
            {.rflags = 0x2}, 6);

  // VBROADCASTSD xmm0,xmm0 (VEX.128, L=0): C4 E2 79 19 C0
  // VBROADCASTSD requires VEX.256 (L=1); L=0 → #UD
  add_fault("vbroadcastsd L=0 (256-only → #UD)", {0xC4, 0xE2, 0x79, 0x19, 0xC0},
            {.rflags = 0x2}, 6);

  // VEXTRACTF128 xmm0,xmm1,0 with VEX.L=0: C4 E3 79 19 C8 00
  // 3-byte VEX: C4 [R̃XB=E3] [W=0 vvvv=1111 L=0 pp=01 = 79]
  // VEXTRACTF128 requires VEX.256 (L=1); L=0 → #UD
  add_fault("vextractf128 L=0 (256-only → #UD)", {0xC4, 0xE3, 0x79, 0x19, 0xC8, 0x00},
            {.rflags = 0x2}, 6);

  // VINSERTF128 xmm0,xmm0,xmm1,0 with VEX.L=0: C4 E3 79 18 C1 00
  // VINSERTF128 requires VEX.256 (L=1); L=0 → #UD
  add_fault("vinsertf128 L=0 (256-only → #UD)", {0xC4, 0xE3, 0x79, 0x18, 0xC1, 0x00},
            {.rflags = 0x2}, 6);

  // ---- Instruction length limit (>15 bytes → #GP(0)) ----
  cat = "Exception #GP";

  // 15 redundant 66 prefixes + NOP (0x90) = 16 bytes total → #GP(0)
  add_fault("16-byte insn (15x 66 + NOP) → #GP",
            {0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66,
             0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x90},
            {.rflags = 0x2}, 13);

  // 14x 66 + 3-byte NOP (0F 1F 00) = 17 bytes → #GP(0)
  add_fault("17-byte insn (14x 66 + 3-byte NOP) → #GP",
            {0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66,
             0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x0F, 0x1F, 0x00},
            {.rflags = 0x2}, 13);

  // 15x F3 + 90 = 16 bytes → #GP(0)
  add_fault("16-byte insn (15x F3 + NOP) → #GP",
            {0xF3, 0xF3, 0xF3, 0xF3, 0xF3, 0xF3, 0xF3, 0xF3,
             0xF3, 0xF3, 0xF3, 0xF3, 0xF3, 0xF3, 0xF3, 0x90},
            {.rflags = 0x2}, 13);
}

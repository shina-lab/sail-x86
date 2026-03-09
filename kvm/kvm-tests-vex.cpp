#include "kvm-harness.h"

void add_vex_tests(std::vector<TestCase> &tests) {
  std::string cat;

  auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                      u32 xmm_cmp) {
    tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
  };

  // =====================================================================
  // MOVQ store (66 0F D6) + VMOVQ store (VEX.128.66.0F D6)
  // =====================================================================
  cat = "MOVQ store";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0xDEADBEEFCAFEBABE, 0x1234567890ABCDEF);

    // 66 0F D6 C8: MOVQ xmm0, xmm1 (reg-reg: store low qword of xmm1 to xmm0, zero upper)
    // ModRM: mod=11, reg=1(src), rm=0(dst) → 0xC8
    add_xmm("movq xmm0,xmm1 (66 0F D6)", {0x66, 0x0F, 0xD6, 0xC8}, s, 0x3);

    // VEX.128.66.0F D6: VMOVQ xmm0, xmm1
    // 2-byte VEX: C5 [R̄.vvvv.L.pp]
    // R̄=1, vvvv=1111, L=0, pp=01(66) → 0xF9
    // C5 F9 D6 C8: VMOVQ xmm0, xmm1
    // reg=xmm1(1), rm=xmm0(0): ModRM = mod=11, reg=001, rm=000 → 0xC8
    add_xmm("vmovq xmm0,xmm1 (VEX D6)", {0xC5, 0xF9, 0xD6, 0xC8}, s, 0x3);
  }

  // =====================================================================
  // VEX 0F3A — blend, extract, insert, align, carry-less multiply
  // =====================================================================
  cat = "VEX 0F3A";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    // VBLENDPS xmm0, xmm1, xmm2, 0x05
    // VEX.128.66.0F3A 0C /r ib — C4 E3 71 0C C2 05
    // imm=0x05: select elements 0,2 from src2(xmm2), 1,3 from src1(xmm1)
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      s.xmm[2] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);
      add_xmm("vblendps xmm0,xmm1,xmm2,0x05",
              {0xC4, 0xE3, 0x71, 0x0C, 0xC2, 0x05}, s, 0x7);
    }

    // VBLENDPD xmm0, xmm1, xmm2, 0x01
    // VEX.128.66.0F3A 0D /r ib — C4 E3 71 0D C2 01
    // imm=0x01: select element 0 from src2(xmm2), element 1 from src1(xmm1)
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_f64(1.0, 2.0);
      s.xmm[2] = xmm_from_f64(3.0, 4.0);
      add_xmm("vblendpd xmm0,xmm1,xmm2,0x01",
              {0xC4, 0xE3, 0x71, 0x0D, 0xC2, 0x01}, s, 0x7);
    }

    // VPBLENDW xmm0, xmm1, xmm2, 0xAA
    // VEX.128.66.0F3A 0E /r ib — C4 E3 71 0E C2 AA
    // imm=0xAA: alternating words from src2
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
      s.xmm[2] = xmm_from_u64(0x1011101210131014, 0x1015101610171018);
      add_xmm("vpblendw xmm0,xmm1,xmm2,0xAA",
              {0xC4, 0xE3, 0x71, 0x0E, 0xC2, 0xAA}, s, 0x7);
    }

    // VPALIGNR xmm0, xmm1, xmm2, 4
    // VEX.128.66.0F3A 0F /r ib — C4 E3 71 0F C2 04
    // Shift right 4 bytes: concatenate xmm1:xmm2 and extract 16 bytes at offset 4
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
      s.xmm[2] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);
      add_xmm("vpalignr xmm0,xmm1,xmm2,4",
              {0xC4, 0xE3, 0x71, 0x0F, 0xC2, 0x04}, s, 0x7);
    }

    // VPEXTRB eax, xmm1, 2
    // VEX.128.66.0F3A 14 /r ib — C4 E3 79 14 C8 02
    // ModRM: mod=11, reg=1(xmm1 src), rm=0(eax dest) → 0xC8
    // vvvv=1111 (unused), byte2=0x79 (W=0,vvvv=1111,L=0,pp=01)
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(0xDEADBEEFCAFE0102, 0x1234567890ABCDEF);
      tests.push_back({"vpextrb eax,xmm1,2", cat,
                       {0xC4, 0xE3, 0x79, 0x14, 0xC8, 0x02}, s, FL_ALL, 0x3});
    }

    // VPEXTRD eax, xmm1, 1
    // VEX.128.66.0F3A 16 /r ib — C4 E3 79 16 C8 01
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      tests.push_back({"vpextrd eax,xmm1,1", cat,
                       {0xC4, 0xE3, 0x79, 0x16, 0xC8, 0x01}, s, FL_ALL, 0x3});
    }

    // VEXTRACTPS eax, xmm1, 2
    // VEX.128.66.0F3A 17 /r ib — C4 E3 79 17 C8 02
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      tests.push_back({"vextractps eax,xmm1,2", cat,
                       {0xC4, 0xE3, 0x79, 0x17, 0xC8, 0x02}, s, FL_ALL, 0x3});
    }

    // VPINSRB xmm0, xmm1, eax, 3
    // VEX.128.66.0F3A 20 /r ib — C4 E3 71 20 C0 03
    // ModRM: mod=11, reg=0(xmm0 dest), rm=0(eax src) → 0xC0
    // vvvv=~1=1110, byte2=0x71
    {
      ArchState s;
      s.rflags = 0x2;
      s.rax = 0x42;
      s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
      add_xmm("vpinsrb xmm0,xmm1,eax,3",
              {0xC4, 0xE3, 0x71, 0x20, 0xC0, 0x03}, s, 0x3);
    }

    // VPINSRD xmm0, xmm1, eax, 2
    // VEX.128.66.0F3A 22 /r ib — C4 E3 71 22 C0 02
    {
      ArchState s;
      s.rflags = 0x2;
      s.rax = 0xDEADBEEF;
      s.xmm[1] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      add_xmm("vpinsrd xmm0,xmm1,eax,2",
              {0xC4, 0xE3, 0x71, 0x22, 0xC0, 0x02}, s, 0x3);
    }

    // VPCLMULQDQ xmm0, xmm1, xmm2, 0x00
    // VEX.128.66.0F3A 44 /r ib — C4 E3 71 44 C2 00
    // Carry-less multiply low qwords
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(0x0000000000000007, 0x0000000000000000);
      s.xmm[2] = xmm_from_u64(0x000000000000000B, 0x0000000000000000);
      add_xmm("vpclmulqdq xmm0,xmm1,xmm2,0x00",
              {0xC4, 0xE3, 0x71, 0x44, 0xC2, 0x00}, s, 0x7);
    }

    // VPCLMULQDQ xmm0, xmm1, xmm2, 0x11
    // Carry-less multiply high qwords
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(0x0000000000000000, 0x0123456789ABCDEF);
      s.xmm[2] = xmm_from_u64(0x0000000000000000, 0x00000000000000FF);
      add_xmm("vpclmulqdq xmm0,xmm1,xmm2,0x11",
              {0xC4, 0xE3, 0x71, 0x44, 0xC2, 0x11}, s, 0x7);
    }

    // VPBLENDD xmm0, xmm1, xmm2, 0x05
    // VEX.128.66.0F3A 02 /r ib — C4 E3 71 02 C2 05
    // imm=0x05: select dwords 0,2 from src2
    {
      ArchState s;
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      s.xmm[2] = xmm_from_u32(0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC, 0xDDDDDDDD);
      add_xmm("vpblendd xmm0,xmm1,xmm2,0x05",
              {0xC4, 0xE3, 0x71, 0x02, 0xC2, 0x05}, s, 0x7);
    }
  }

  // =====================================================================
  // BMI2 — bit manipulation instructions (GPR tests)
  // =====================================================================
  cat = "BMI2";
  {
    // BZHI eax, ecx, edx — zero high bits in ecx starting at bit position in edx
    // VEX.NDS.LZ.0F38.W0 F5 /r — C4 E2 68 F5 C1
    // reg=0(eax dest), rm=1(ecx src), vvvv=~2=1101(edx index)
    // byte2: W=0,vvvv=1101,L=0,pp=00 → 0x68
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0xDEADBEEF12345678;
      s.rdx = 16;
      // 32-bit: eax = ecx[31:0] with bits above 16 cleared = 0x5678
      tests.push_back({"bzhi eax,ecx,edx bit16", cat,
                       {0xC4, 0xE2, 0x68, 0xF5, 0xC1}, s,
                       FL_ZF | FL_SF | FL_CF | FL_OF});
    }
    // BZHI with zero index → result=0, ZF=1
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0xFFFFFFFF;
      s.rdx = 0;
      tests.push_back({"bzhi eax,ecx,edx bit0", cat,
                       {0xC4, 0xE2, 0x68, 0xF5, 0xC1}, s,
                       FL_ZF | FL_SF | FL_CF | FL_OF});
    }
    // BZHI 64-bit: rax, rcx, rdx
    // W=1: byte2 = 0b1_1101_0_00 = 0xE8
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0xFFFFFFFFFFFFFFFF;
      s.rdx = 32;
      tests.push_back({"bzhi rax,rcx,rdx bit32", cat,
                       {0xC4, 0xE2, 0xE8, 0xF5, 0xC1}, s,
                       FL_ZF | FL_SF | FL_CF | FL_OF});
    }
    // BZHI with index >= operand size → CF=1, result unchanged
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x12345678;
      s.rdx = 40;  // >= 32 for W0
      tests.push_back({"bzhi eax,ecx,edx overflow", cat,
                       {0xC4, 0xE2, 0x68, 0xF5, 0xC1}, s,
                       FL_ZF | FL_SF | FL_CF | FL_OF});
    }

    // PDEP eax, ecx, edx — parallel bit deposit
    // VEX.NDS.LZ.F2.0F38.W0 F5 /r — C4 E2 73 F5 C2
    // reg=0(eax dest), vvvv=~1=1110(ecx src), rm=2(edx mask)
    // byte2: W=0,vvvv=1110,L=0,pp=11(F2) → 0x73
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x000000FF;  // source bits
      s.rdx = 0x55555555;  // mask: every other bit
      tests.push_back({"pdep eax,ecx,edx", cat,
                       {0xC4, 0xE2, 0x73, 0xF5, 0xC2}, s, FL_NONE});
    }
    // PDEP 64-bit
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x00000000000000FF;
      s.rdx = 0x5555555555555555;
      // W=1: byte2 = 0b1_1110_0_11 = 0xF3
      tests.push_back({"pdep rax,rcx,rdx 64", cat,
                       {0xC4, 0xE2, 0xF3, 0xF5, 0xC2}, s, FL_NONE});
    }

    // PEXT eax, ecx, edx — parallel bit extract
    // VEX.NDS.LZ.F3.0F38.W0 F5 /r — C4 E2 72 F5 C2
    // byte2: W=0,vvvv=1110,L=0,pp=10(F3) → 0x72
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0xAAAAAAAA;  // source
      s.rdx = 0x55555555;  // mask: every other bit
      tests.push_back({"pext eax,ecx,edx", cat,
                       {0xC4, 0xE2, 0x72, 0xF5, 0xC2}, s, FL_NONE});
    }
    // PEXT 64-bit
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0xAAAAAAAAAAAAAAAA;
      s.rdx = 0x5555555555555555;
      // W=1: byte2 = 0b1_1110_0_10 = 0xF2
      tests.push_back({"pext rax,rcx,rdx 64", cat,
                       {0xC4, 0xE2, 0xF2, 0xF5, 0xC2}, s, FL_NONE});
    }

    // MULX ebx, eax, ecx — unsigned multiply EDX * ECX → EBX:EAX
    // VEX.NDD.LZ.F2.0F38.W0 F6 /r — C4 E2 7B F6 D9
    // reg=3(ebx hi), vvvv=~0=1111(eax lo), rm=1(ecx src)
    // byte2: W=0,vvvv=1111,L=0,pp=11(F2) → 0x7B
    // ModRM: mod=11, reg=011, rm=001 → 0xD9
    // Implicit src1 = EDX
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdx = 100;
      s.rcx = 200;
      tests.push_back({"mulx ebx,eax,ecx 100*200", cat,
                       {0xC4, 0xE2, 0x7B, 0xF6, 0xD9}, s, FL_NONE});
    }
    // MULX with large values to produce high part
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdx = 0xFFFFFFFF;
      s.rcx = 0xFFFFFFFF;
      tests.push_back({"mulx ebx,eax,ecx max32", cat,
                       {0xC4, 0xE2, 0x7B, 0xF6, 0xD9}, s, FL_NONE});
    }
    // MULX 64-bit: W=1, byte2 = 0b1_1111_0_11 = 0xFB
    {
      ArchState s;
      s.rflags = 0x2;
      s.rdx = 0x100000000;
      s.rcx = 0x100000000;
      tests.push_back({"mulx rbx,rax,rcx 64", cat,
                       {0xC4, 0xE2, 0xFB, 0xF6, 0xD9}, s, FL_NONE});
    }

    // SARX eax, ecx, edx — arithmetic shift right without flags
    // VEX.NDS.LZ.F3.0F38.W0 F7 /r — C4 E2 6A F7 C1
    // reg=0(eax dest), rm=1(ecx src), vvvv=~2=1101(edx count)
    // byte2: W=0,vvvv=1101,L=0,pp=10(F3) → 0x6A
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x80000000;  // negative when treated as signed 32-bit
      s.rdx = 4;
      tests.push_back({"sarx eax,ecx,edx", cat,
                       {0xC4, 0xE2, 0x6A, 0xF7, 0xC1}, s, FL_NONE});
    }

    // SHLX eax, ecx, edx — logical shift left without flags
    // VEX.NDS.LZ.66.0F38.W0 F7 /r — C4 E2 69 F7 C1
    // byte2: W=0,vvvv=1101,L=0,pp=01(66) → 0x69
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x12345678;
      s.rdx = 8;
      tests.push_back({"shlx eax,ecx,edx", cat,
                       {0xC4, 0xE2, 0x69, 0xF7, 0xC1}, s, FL_NONE});
    }

    // SHRX eax, ecx, edx — logical shift right without flags
    // VEX.NDS.LZ.F2.0F38.W0 F7 /r — C4 E2 6B F7 C1
    // byte2: W=0,vvvv=1101,L=0,pp=11(F2) → 0x6B
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x12345678;
      s.rdx = 8;
      tests.push_back({"shrx eax,ecx,edx", cat,
                       {0xC4, 0xE2, 0x6B, 0xF7, 0xC1}, s, FL_NONE});
    }

    // SARX 64-bit: W=1, byte2 = 0b1_1101_0_10 = 0xEA
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x8000000000000000;
      s.rdx = 16;
      tests.push_back({"sarx rax,rcx,rdx 64", cat,
                       {0xC4, 0xE2, 0xEA, 0xF7, 0xC1}, s, FL_NONE});
    }

    // SHLX 64-bit: W=1, byte2 = 0b1_1101_0_01 = 0xE9
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x0000000000000001;
      s.rdx = 63;
      tests.push_back({"shlx rax,rcx,rdx 64", cat,
                       {0xC4, 0xE2, 0xE9, 0xF7, 0xC1}, s, FL_NONE});
    }

    // SHRX 64-bit: W=1, byte2 = 0b1_1101_0_11 = 0xEB
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x8000000000000000;
      s.rdx = 32;
      tests.push_back({"shrx rax,rcx,rdx 64", cat,
                       {0xC4, 0xE2, 0xEB, 0xF7, 0xC1}, s, FL_NONE});
    }

    // RORX eax, ecx, 4 — rotate right without flags
    // VEX.LZ.F2.0F3A.W0 F0 /r ib — C4 E3 7B F0 C1 04
    // byte1=0xE3 (mmmmm=00011=0F3A), byte2: W=0,vvvv=1111,L=0,pp=11(F2) → 0x7B
    // reg=0(eax dest), rm=1(ecx src), imm=4
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x12345678;
      tests.push_back({"rorx eax,ecx,4", cat,
                       {0xC4, 0xE3, 0x7B, 0xF0, 0xC1, 0x04}, s, FL_NONE});
    }
    // RORX 64-bit: W=1, byte2 = 0b1_1111_0_11 = 0xFB
    {
      ArchState s;
      s.rflags = 0x2;
      s.rcx = 0x123456789ABCDEF0;
      tests.push_back({"rorx rax,rcx,8 64", cat,
                       {0xC4, 0xE3, 0xFB, 0xF0, 0xC1, 0x08}, s, FL_NONE});
    }
  }

  // =====================================================================
  // VEX AES-NI — AES encryption/decryption rounds
  // =====================================================================
  cat = "VEX AES-NI";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    // Common AES test state — non-trivial data in xmm registers
    ArchState aes = {};
    aes.rflags = 0x2;
    aes.xmm[1] = xmm_from_u64(0x0123456789ABCDEF, 0xFEDCBA9876543210);
    aes.xmm[2] = xmm_from_u64(0x0F0E0D0C0B0A0908, 0x0706050403020100);

    // VAESENC xmm0, xmm1, xmm2 — one AES encryption round
    // VEX.128.66.0F38.WIG DC /r — C4 E2 71 DC C2
    // vvvv=~1=1110, byte2: W=0,vvvv=1110,L=0,pp=01 → 0x71
    add_xmm("vaesenc xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xDC, 0xC2}, aes, 0x7);

    // VAESENCLAST xmm0, xmm1, xmm2 — last AES encryption round
    // VEX.128.66.0F38.WIG DD /r — C4 E2 71 DD C2
    add_xmm("vaesenclast xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xDD, 0xC2}, aes, 0x7);

    // VAESDEC xmm0, xmm1, xmm2 — one AES decryption round
    // VEX.128.66.0F38.WIG DE /r — C4 E2 71 DE C2
    add_xmm("vaesdec xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xDE, 0xC2}, aes, 0x7);

    // VAESDECLAST xmm0, xmm1, xmm2 — last AES decryption round
    // VEX.128.66.0F38.WIG DF /r — C4 E2 71 DF C2
    add_xmm("vaesdeclast xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xDF, 0xC2}, aes, 0x7);

    // VAESIMC xmm0, xmm1 — AES InvMixColumns
    // VEX.128.66.0F38.WIG DB /r — C4 E2 79 DB C1
    // vvvv=1111 (unary), byte2=0x79
    add_xmm("vaesimc xmm0,xmm1",
            {0xC4, 0xE2, 0x79, 0xDB, 0xC1}, aes, 0x3);

    // VAESKEYGENASSIST xmm0, xmm1, 0x01 — AES key expansion assist
    // VEX.128.66.0F3A.WIG DF /r ib — C4 E3 79 DF C1 01
    // vvvv=1111 (unary), byte1=0xE3 (0F3A), byte2=0x79
    add_xmm("vaeskeygenassist xmm0,xmm1,0x01",
            {0xC4, 0xE3, 0x79, 0xDF, 0xC1, 0x01}, aes, 0x3);

    // VAESKEYGENASSIST with different round constant
    add_xmm("vaeskeygenassist xmm0,xmm1,0x02",
            {0xC4, 0xE3, 0x79, 0xDF, 0xC1, 0x02}, aes, 0x3);

    // Second set of AES data to increase coverage
    ArchState aes2 = {};
    aes2.rflags = 0x2;
    aes2.xmm[1] = xmm_from_u64(0x00112233AABBCCDD, 0xEEFF001122334455);
    aes2.xmm[2] = xmm_from_u64(0x5A5A5A5A5A5A5A5A, 0xA5A5A5A5A5A5A5A5);

    add_xmm("vaesenc xmm0,xmm1,xmm2 v2",
            {0xC4, 0xE2, 0x71, 0xDC, 0xC2}, aes2, 0x7);
    add_xmm("vaesenclast xmm0,xmm1,xmm2 v2",
            {0xC4, 0xE2, 0x71, 0xDD, 0xC2}, aes2, 0x7);
    add_xmm("vaesdec xmm0,xmm1,xmm2 v2",
            {0xC4, 0xE2, 0x71, 0xDE, 0xC2}, aes2, 0x7);
    add_xmm("vaesdeclast xmm0,xmm1,xmm2 v2",
            {0xC4, 0xE2, 0x71, 0xDF, 0xC2}, aes2, 0x7);
  }

  // =====================================================================
  // 74. VEX SSSE3 — VEX-encoded SSSE3 integer instructions (0F38 map)
  // =====================================================================
  cat = "VEX SSSE3";

  // 3-operand VEX SSSE3 tests: dst=xmm0, src1=xmm1, src2=xmm2
  // VEX.128.66.0F38: C4 E2 71 <op> C2
  //   E2 = R̄=1,X̄=1,B̄=1,mmmmm=00010(0F38)
  //   71 = W=0,vvvv=1110(~xmm1),L=0,pp=01(66)
  {
    ArchState s;
    s.rflags = 0x2;
    // Shuffle source: bytes 0x00..0x0F
    s.xmm[1] = xmm_from_u64(0x0F0E0D0C0B0A0908, 0x0706050403020100);
    // Shuffle control: mix of indices and high-bit-set (zeroing) entries
    s.xmm[2] = xmm_from_u64(0x830201008F060504, 0x0302010083020100);

    // VPSHUFB xmm0, xmm1, xmm2: C4 E2 71 00 C2
    add_xmm("vpshufb xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x00, 0xC2}, s, 0x7);
  }

  {
    ArchState s;
    s.rflags = 0x2;
    // Words for horizontal add/sub: distinct values to verify lane pairing
    s.xmm[1] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
    s.xmm[2] = xmm_from_u64(0x0010002000300040, 0x0050006000700080);

    // VPHADDW xmm0, xmm1, xmm2: C4 E2 71 01 C2
    add_xmm("vphaddw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x01, 0xC2}, s, 0x7);
    // VPHADDD xmm0, xmm1, xmm2: C4 E2 71 02 C2
    add_xmm("vphaddd xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x02, 0xC2}, s, 0x7);
    // VPHADDSW xmm0, xmm1, xmm2: C4 E2 71 03 C2
    add_xmm("vphaddsw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x03, 0xC2}, s, 0x7);
    // VPMADDUBSW xmm0, xmm1, xmm2: C4 E2 71 04 C2
    add_xmm("vpmaddubsw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x04, 0xC2}, s, 0x7);
    // VPHSUBW xmm0, xmm1, xmm2: C4 E2 71 05 C2
    add_xmm("vphsubw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x05, 0xC2}, s, 0x7);
    // VPHSUBD xmm0, xmm1, xmm2: C4 E2 71 06 C2
    add_xmm("vphsubd xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x06, 0xC2}, s, 0x7);
    // VPHSUBSW xmm0, xmm1, xmm2: C4 E2 71 07 C2
    add_xmm("vphsubsw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x07, 0xC2}, s, 0x7);
    // VPMULHRSW xmm0, xmm1, xmm2: C4 E2 71 0B C2
    add_xmm("vpmulhrsw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x0B, 0xC2}, s, 0x7);
  }

  // VPSIGN — sign/zero/negate paths
  {
    ArchState s;
    s.rflags = 0x2;
    // Mix of positive, negative, zero values
    s.xmm[1] = xmm_from_u64(0x01FF037F05816082, 0x7FFFFFFF80000001);
    // Control: positive (keep), negative (negate), zero (zero out)
    s.xmm[2] = xmm_from_u64(0x0001000100010001, 0xFFFF0000FFFF0000);

    // VPSIGNB xmm0, xmm1, xmm2: C4 E2 71 08 C2
    add_xmm("vpsignb xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x08, 0xC2}, s, 0x7);
    // VPSIGNW xmm0, xmm1, xmm2: C4 E2 71 09 C2
    add_xmm("vpsignw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x09, 0xC2}, s, 0x7);
    // VPSIGND xmm0, xmm1, xmm2: C4 E2 71 0A C2
    add_xmm("vpsignd xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x0A, 0xC2}, s, 0x7);
  }

  // VPABS — unary, vvvv=1111b → byte2=0x79
  // VEX.128.66.0F38 with vvvv=1111: C4 E2 79 <op> C1
  {
    ArchState s;
    s.rflags = 0x2;
    // Values with negative/positive/zero/min to exercise abs paths
    s.xmm[1] = xmm_from_u64(0x01FF037F05816082, 0x7FFFFFFF80000001);

    // VPABSB xmm0, xmm1: C4 E2 79 1C C1
    add_xmm("vpabsb xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x1C, 0xC1}, s, 0x3);
    // VPABSW xmm0, xmm1: C4 E2 79 1D C1
    add_xmm("vpabsw xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x1D, 0xC1}, s, 0x3);
    // VPABSD xmm0, xmm1: C4 E2 79 1E C1
    add_xmm("vpabsd xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x1E, 0xC1}, s, 0x3);
  }

  // =====================================================================
  // 75. VEX SSE4.1 — VEX-encoded SSE4.1 integer instructions (0F38 map)
  // =====================================================================
  cat = "VEX SSE4.1";

  // Sign-extend instructions (unary, vvvv=1111b → byte2=0x79)
  // Use data with bit 7 set to verify sign extension
  {
    ArchState s;
    s.rflags = 0x2;
    // Bytes with mix of positive (0x07, 0x03, 0x05, 0x04, 0x02, 0x7F)
    // and negative (0x80, 0xFF, 0xFB, 0xFA, 0xFC, 0xFE) to test sign extension
    s.xmm[1] = xmm_from_u64(0x0180FF7F02FE0300, 0x04FC0580FB06FA07);

    // VPMOVSXBW xmm0, xmm1: C4 E2 79 20 C1
    add_xmm("vpmovsxbw xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x20, 0xC1}, s, 0x3);
    // VPMOVSXBD xmm0, xmm1: C4 E2 79 21 C1
    add_xmm("vpmovsxbd xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x21, 0xC1}, s, 0x3);
    // VPMOVSXBQ xmm0, xmm1: C4 E2 79 22 C1
    add_xmm("vpmovsxbq xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x22, 0xC1}, s, 0x3);
    // VPMOVSXWD xmm0, xmm1: C4 E2 79 23 C1
    add_xmm("vpmovsxwd xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x23, 0xC1}, s, 0x3);
    // VPMOVSXWQ xmm0, xmm1: C4 E2 79 24 C1
    add_xmm("vpmovsxwq xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x24, 0xC1}, s, 0x3);
    // VPMOVSXDQ xmm0, xmm1: C4 E2 79 25 C1
    add_xmm("vpmovsxdq xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x25, 0xC1}, s, 0x3);
  }

  // Zero-extend instructions (unary, vvvv=1111b → byte2=0x79)
  {
    ArchState s;
    s.rflags = 0x2;
    // Same data as sign-extend to cross-check
    s.xmm[1] = xmm_from_u64(0x0180FF7F02FE0300, 0x04FC0580FB06FA07);

    // VPMOVZXBW xmm0, xmm1: C4 E2 79 30 C1
    add_xmm("vpmovzxbw xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x30, 0xC1}, s, 0x3);
    // VPMOVZXBD xmm0, xmm1: C4 E2 79 31 C1
    add_xmm("vpmovzxbd xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x31, 0xC1}, s, 0x3);
    // VPMOVZXBQ xmm0, xmm1: C4 E2 79 32 C1
    add_xmm("vpmovzxbq xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x32, 0xC1}, s, 0x3);
    // VPMOVZXWD xmm0, xmm1: C4 E2 79 33 C1
    add_xmm("vpmovzxwd xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x33, 0xC1}, s, 0x3);
    // VPMOVZXWQ xmm0, xmm1: C4 E2 79 34 C1
    add_xmm("vpmovzxwq xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x34, 0xC1}, s, 0x3);
    // VPMOVZXDQ xmm0, xmm1: C4 E2 79 35 C1
    add_xmm("vpmovzxdq xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x35, 0xC1}, s, 0x3);
  }

  // 3-operand SSE4.1: dst=xmm0, src1=xmm1, src2=xmm2
  // VEX.128.66.0F38 with vvvv=xmm1: C4 E2 71 <op> C2
  {
    ArchState s;
    s.rflags = 0x2;
    // Values where signed and unsigned orderings differ
    // Signed: 0x80=-128 < 0x7F=127; Unsigned: 0x80=128 > 0x7F=127
    s.xmm[1] = xmm_from_u64(0x01FF037F05816082, 0x7FFFFFFF80000001);
    s.xmm[2] = xmm_from_u64(0x02FE027E04806183, 0x80000000FFFFFFFF);

    // VPMULDQ xmm0, xmm1, xmm2: C4 E2 71 28 C2
    // Multiplies dwords at positions 0 and 2 (signed) → qword results
    add_xmm("vpmuldq xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x28, 0xC2}, s, 0x7);
    // VPCMPEQQ xmm0, xmm1, xmm2: C4 E2 71 29 C2
    add_xmm("vpcmpeqq xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x29, 0xC2}, s, 0x7);
    // VPACKUSDW xmm0, xmm1, xmm2: C4 E2 71 2B C2
    add_xmm("vpackusdw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x2B, 0xC2}, s, 0x7);

    // VPMINSB xmm0, xmm1, xmm2: C4 E2 71 38 C2
    add_xmm("vpminsb xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x38, 0xC2}, s, 0x7);
    // VPMINSD xmm0, xmm1, xmm2: C4 E2 71 39 C2
    add_xmm("vpminsd xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x39, 0xC2}, s, 0x7);
    // VPMINUW xmm0, xmm1, xmm2: C4 E2 71 3A C2
    add_xmm("vpminuw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x3A, 0xC2}, s, 0x7);
    // VPMINUD xmm0, xmm1, xmm2: C4 E2 71 3B C2
    add_xmm("vpminud xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x3B, 0xC2}, s, 0x7);

    // VPMAXSB xmm0, xmm1, xmm2: C4 E2 71 3C C2
    add_xmm("vpmaxsb xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x3C, 0xC2}, s, 0x7);
    // VPMAXSD xmm0, xmm1, xmm2: C4 E2 71 3D C2
    add_xmm("vpmaxsd xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x3D, 0xC2}, s, 0x7);
    // VPMAXUW xmm0, xmm1, xmm2: C4 E2 71 3E C2
    add_xmm("vpmaxuw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x3E, 0xC2}, s, 0x7);
    // VPMAXUD xmm0, xmm1, xmm2: C4 E2 71 3F C2
    add_xmm("vpmaxud xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x3F, 0xC2}, s, 0x7);

    // VPMULLD xmm0, xmm1, xmm2: C4 E2 71 40 C2
    add_xmm("vpmulld xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x40, 0xC2}, s, 0x7);
  }

  // VPHMINPOSUW — unary, 128-bit only (vvvv=1111b → byte2=0x79)
  {
    ArchState s;
    s.rflags = 0x2;
    // 8 unsigned words: find the minimum and its index
    // Words: 0x0040, 0x0003, 0x0080, 0x0001, 0x00FF, 0x0002, 0x0050, 0x0010
    s.xmm[1] = xmm_from_u64(0x00100050000200FF, 0x0001008000030040);

    // VPHMINPOSUW xmm0, xmm1: C4 E2 79 41 C1
    add_xmm("vphminposuw xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x41, 0xC1}, s, 0x3);
  }

  // VPMULDQ with interesting dword positions 0 and 2
  {
    ArchState s;
    s.rflags = 0x2;
    // dword[0]=0xFFFFFFFE (-2), dword[1]=junk, dword[2]=0x7FFFFFFF (INT_MAX), dword[3]=junk
    s.xmm[1] = xmm_from_u64(0xDEAD7FFFFFFFDEAD, 0xFFFFFFFE);
    // dword[0]=0x00000003 (3), dword[1]=junk, dword[2]=0xFFFFFFFF (-1), dword[3]=junk
    s.xmm[2] = xmm_from_u64(0xBEEFFFFFFFFFBEEF, 0x00000003);

    // VPMULDQ xmm0, xmm1, xmm2: C4 E2 71 28 C2
    add_xmm("vpmuldq xmm0,xmm1,xmm2 (edge)", {0xC4, 0xE2, 0x71, 0x28, 0xC2}, s, 0x7);
  }

  // VPCMPEQQ with equal and unequal qwords
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0xDEADBEEFCAFEBABE, 0x0123456789ABCDEF);
    s.xmm[2] = xmm_from_u64(0xDEADBEEFCAFEBABE, 0xFEDCBA9876543210);

    // VPCMPEQQ: qword[0] matches → 0xFFFF..., qword[1] differs → 0x0000...
    add_xmm("vpcmpeqq xmm0,xmm1,xmm2 (mixed)", {0xC4, 0xE2, 0x71, 0x29, 0xC2}, s, 0x7);
  }

  // ── VEX pack/unpack/compare (VEX 0F) ──
  cat = "VEX pack/unpack";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
    s.xmm[2] = xmm_from_u64(0x000A000B000C000D, 0x000E000F00100011);

    // VPUNPCKLBW xmm0,xmm1,xmm2: C5 F1 60 C2
    add_xmm("vpunpcklbw", {0xC5, 0xF1, 0x60, 0xC2}, s, 0x7);
    // VPUNPCKLWD: C5 F1 61 C2
    add_xmm("vpunpcklwd", {0xC5, 0xF1, 0x61, 0xC2}, s, 0x7);
    // VPUNPCKLDQ: C5 F1 62 C2
    add_xmm("vpunpckldq", {0xC5, 0xF1, 0x62, 0xC2}, s, 0x7);
    // VPACKSSWB: C5 F1 63 C2
    add_xmm("vpacksswb", {0xC5, 0xF1, 0x63, 0xC2}, s, 0x7);
    // VPCMPGTB: C5 F1 64 C2
    add_xmm("vpcmpgtb", {0xC5, 0xF1, 0x64, 0xC2}, s, 0x7);
    // VPCMPGTW: C5 F1 65 C2
    add_xmm("vpcmpgtw", {0xC5, 0xF1, 0x65, 0xC2}, s, 0x7);
    // VPCMPGTD: C5 F1 66 C2
    add_xmm("vpcmpgtd", {0xC5, 0xF1, 0x66, 0xC2}, s, 0x7);
    // VPACKUSWB: C5 F1 67 C2
    add_xmm("vpackuswb", {0xC5, 0xF1, 0x67, 0xC2}, s, 0x7);
    // VPUNPCKHBW: C5 F1 68 C2
    add_xmm("vpunpckhbw", {0xC5, 0xF1, 0x68, 0xC2}, s, 0x7);
    // VPUNPCKHWD: C5 F1 69 C2
    add_xmm("vpunpckhwd", {0xC5, 0xF1, 0x69, 0xC2}, s, 0x7);
    // VPUNPCKHDQ: C5 F1 6A C2
    add_xmm("vpunpckhdq", {0xC5, 0xF1, 0x6A, 0xC2}, s, 0x7);
    // VPACKSSDW: C5 F1 6B C2
    add_xmm("vpackssdw", {0xC5, 0xF1, 0x6B, 0xC2}, s, 0x7);
    // VPUNPCKLQDQ: C5 F1 6C C2
    add_xmm("vpunpcklqdq", {0xC5, 0xF1, 0x6C, 0xC2}, s, 0x7);
    // VPUNPCKHQDQ: C5 F1 6D C2
    add_xmm("vpunpckhqdq", {0xC5, 0xF1, 0x6D, 0xC2}, s, 0x7);

    // VPCMPEQB: C5 F1 74 C2
    add_xmm("vpcmpeqb", {0xC5, 0xF1, 0x74, 0xC2}, s, 0x7);
    // VPCMPEQW: C5 F1 75 C2
    add_xmm("vpcmpeqw", {0xC5, 0xF1, 0x75, 0xC2}, s, 0x7);
  }

  // ── VEX multiply/SAD/avg (VEX 0F) ──
  cat = "VEX multiply";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0064FFCE00050003, 0x7FFF80000002FFFE);
    s.xmm[2] = xmm_from_u64(0x000AFFEC00020004, 0x0001FFFF00037FFF);

    // VPMULLW: C5 F1 D5 C2
    add_xmm("vpmullw", {0xC5, 0xF1, 0xD5, 0xC2}, s, 0x7);
    // VPMULHUW: C5 F1 E4 C2
    add_xmm("vpmulhuw", {0xC5, 0xF1, 0xE4, 0xC2}, s, 0x7);
    // VPMULHW: C5 F1 E5 C2
    add_xmm("vpmulhw", {0xC5, 0xF1, 0xE5, 0xC2}, s, 0x7);
    // VPMULUDQ: C5 F1 F4 C2
    add_xmm("vpmuludq", {0xC5, 0xF1, 0xF4, 0xC2}, s, 0x7);
    // VPMADDWD: C5 F1 F5 C2
    add_xmm("vpmaddwd", {0xC5, 0xF1, 0xF5, 0xC2}, s, 0x7);
    // VPSADBW: C5 F1 F6 C2
    add_xmm("vpsadbw", {0xC5, 0xF1, 0xF6, 0xC2}, s, 0x7);
    // VPAVGB: C5 F1 E0 C2
    add_xmm("vpavgb", {0xC5, 0xF1, 0xE0, 0xC2}, s, 0x7);
    // VPAVGW: C5 F1 E3 C2
    add_xmm("vpavgw", {0xC5, 0xF1, 0xE3, 0xC2}, s, 0x7);
  }

  // ── VEX saturating arithmetic (VEX 0F) ──
  cat = "VEX saturating arith";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x7F80FF00FE01F0E0, 0x7FFF8000FFFE0001);
    s.xmm[2] = xmm_from_u64(0x0180FF007F01F0E0, 0x0001FFFF00020001);

    // VPADDSB: C5 F1 EC C2
    add_xmm("vpaddsb", {0xC5, 0xF1, 0xEC, 0xC2}, s, 0x7);
    // VPADDSW: C5 F1 ED C2
    add_xmm("vpaddsw", {0xC5, 0xF1, 0xED, 0xC2}, s, 0x7);
    // VPADDUSB: C5 F1 DC C2
    add_xmm("vpaddusb", {0xC5, 0xF1, 0xDC, 0xC2}, s, 0x7);
    // VPADDUSW: C5 F1 DD C2
    add_xmm("vpaddusw", {0xC5, 0xF1, 0xDD, 0xC2}, s, 0x7);
    // VPSUBSB: C5 F1 E8 C2
    add_xmm("vpsubsb", {0xC5, 0xF1, 0xE8, 0xC2}, s, 0x7);
    // VPSUBSW: C5 F1 E9 C2
    add_xmm("vpsubsw", {0xC5, 0xF1, 0xE9, 0xC2}, s, 0x7);
    // VPSUBUSB: C5 F1 D8 C2
    add_xmm("vpsubusb", {0xC5, 0xF1, 0xD8, 0xC2}, s, 0x7);
    // VPSUBUSW: C5 F1 D9 C2
    add_xmm("vpsubusw", {0xC5, 0xF1, 0xD9, 0xC2}, s, 0x7);
    // VPMINUB: C5 F1 DA C2
    add_xmm("vpminub", {0xC5, 0xF1, 0xDA, 0xC2}, s, 0x7);
    // VPMAXUB: C5 F1 DE C2
    add_xmm("vpmaxub", {0xC5, 0xF1, 0xDE, 0xC2}, s, 0x7);
    // VPMINSW: C5 F1 EA C2
    add_xmm("vpminsw", {0xC5, 0xF1, 0xEA, 0xC2}, s, 0x7);
  }

  // ── VEX shifts by XMM (VEX 0F) ──
  cat = "VEX shifts";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0xFF00FF00ABCD1234, 0x8000000012345678);
    s.xmm[2] = xmm_from_u64(0x0000000000000004, 0x0000000000000000); // shift count = 4

    // VPSRLW: C5 F1 D1 C2
    add_xmm("vpsrlw by xmm", {0xC5, 0xF1, 0xD1, 0xC2}, s, 0x7);
    // VPSRLD: C5 F1 D2 C2
    add_xmm("vpsrld by xmm", {0xC5, 0xF1, 0xD2, 0xC2}, s, 0x7);
    // VPSRLQ: C5 F1 D3 C2
    add_xmm("vpsrlq by xmm", {0xC5, 0xF1, 0xD3, 0xC2}, s, 0x7);
    // VPSRAW: C5 F1 E1 C2
    add_xmm("vpsraw by xmm", {0xC5, 0xF1, 0xE1, 0xC2}, s, 0x7);
    // VPSRAD: C5 F1 E2 C2
    add_xmm("vpsrad by xmm", {0xC5, 0xF1, 0xE2, 0xC2}, s, 0x7);
    // VPSLLW: C5 F1 F1 C2
    add_xmm("vpsllw by xmm", {0xC5, 0xF1, 0xF1, 0xC2}, s, 0x7);
    // VPSLLD: C5 F1 F2 C2
    add_xmm("vpslld by xmm", {0xC5, 0xF1, 0xF2, 0xC2}, s, 0x7);
    // VPSLLQ: C5 F1 F3 C2
    add_xmm("vpsllq by xmm", {0xC5, 0xF1, 0xF3, 0xC2}, s, 0x7);
  }

  // ── VEX immediate shifts (VEX 0F groups 71/72/73) ──
  cat = "VEX imm shifts";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0xFF00FF00ABCD1234, 0x8000000012345678);

    // VPSRLW xmm0, xmm1, 4: C5 F9 71 D1 04
    add_xmm("vpsrlw imm", {0xC5, 0xF9, 0x71, 0xD1, 0x04}, s, 0x3);
    // VPSRAW xmm0, xmm1, 4: C5 F9 71 E1 04 (reg=4)
    add_xmm("vpsraw imm", {0xC5, 0xF9, 0x71, 0xE1, 0x04}, s, 0x3);
    // VPSLLW xmm0, xmm1, 4: C5 F9 71 F1 04 (reg=6)
    add_xmm("vpsllw imm", {0xC5, 0xF9, 0x71, 0xF1, 0x04}, s, 0x3);
    // VPSRLD xmm0, xmm1, 4: C5 F9 72 D1 04
    add_xmm("vpsrld imm", {0xC5, 0xF9, 0x72, 0xD1, 0x04}, s, 0x3);
    // VPSRAD xmm0, xmm1, 4: C5 F9 72 E1 04
    add_xmm("vpsrad imm", {0xC5, 0xF9, 0x72, 0xE1, 0x04}, s, 0x3);
    // VPSLLD xmm0, xmm1, 4: C5 F9 72 F1 04
    add_xmm("vpslld imm", {0xC5, 0xF9, 0x72, 0xF1, 0x04}, s, 0x3);
    // VPSRLQ xmm0, xmm1, 4: C5 F9 73 D1 04
    add_xmm("vpsrlq imm", {0xC5, 0xF9, 0x73, 0xD1, 0x04}, s, 0x3);
    // VPSLLQ xmm0, xmm1, 4: C5 F9 73 F1 04
    add_xmm("vpsllq imm", {0xC5, 0xF9, 0x73, 0xF1, 0x04}, s, 0x3);
    // VPSRLDQ xmm0, xmm1, 4: C5 F9 73 D9 04 (reg=3)
    add_xmm("vpsrldq imm", {0xC5, 0xF9, 0x73, 0xD9, 0x04}, s, 0x3);
    // VPSLLDQ xmm0, xmm1, 4: C5 F9 73 F9 04 (reg=7)
    add_xmm("vpslldq imm", {0xC5, 0xF9, 0x73, 0xF9, 0x04}, s, 0x3);
  }

  // ── AVX2 variable shifts (VEX 0F38) ──
  cat = "AVX2 var shifts";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0xFF000000ABCD1234, 0x8000000012345678);
    s.xmm[2] = xmm_from_u64(0x0000000400000008, 0x0000001000000001); // shift counts per dword

    // VPSRLVD xmm0, xmm1, xmm2: C4 E2 71 45 C2 (VEX.128.66.0F38.W0)
    add_xmm("vpsrlvd", {0xC4, 0xE2, 0x71, 0x45, 0xC2}, s, 0x7);
    // VPSRAVD xmm0, xmm1, xmm2: C4 E2 71 46 C2
    add_xmm("vpsravd", {0xC4, 0xE2, 0x71, 0x46, 0xC2}, s, 0x7);
    // VPSLLVD xmm0, xmm1, xmm2: C4 E2 71 47 C2
    add_xmm("vpsllvd", {0xC4, 0xE2, 0x71, 0x47, 0xC2}, s, 0x7);

    // VPSRLVQ xmm0, xmm1, xmm2: C4 E2 F1 45 C2 (W=1 for qword)
    s.xmm[2] = xmm_from_u64(0x0000000000000004, 0x0000000000000010); // shift counts per qword
    add_xmm("vpsrlvq", {0xC4, 0xE2, 0xF1, 0x45, 0xC2}, s, 0x7);
    // VPSLLVQ xmm0, xmm1, xmm2: C4 E2 F1 47 C2
    add_xmm("vpsllvq", {0xC4, 0xE2, 0xF1, 0x47, 0xC2}, s, 0x7);
  }

  // ── VEX VTESTPS/VTESTPD (VEX 0F38) ──
  cat = "VEX test";
  {
    auto add_test = [&](const char *name, std::vector<u8> code, ArchState init, u64 mask) {
      tests.push_back({name, cat, std::move(code), init, mask});
    };

    ArchState s;
    s.rflags = 0x2;
    // Use values where AND and ANDNOT give different zero/non-zero results
    s.xmm[1] = xmm_from_u64(0x8000000080000000, 0x0000000000000000); // sign bits set in low half
    s.xmm[2] = xmm_from_u64(0x8000000080000000, 0x8000000080000000); // all sign bits set

    // VTESTPS xmm1, xmm2: C4 E2 79 0E CA
    add_test("vtestps", {0xC4, 0xE2, 0x79, 0x0E, 0xCA}, s, FL_ZF | FL_CF);

    s.xmm[1] = xmm_from_u64(0x0000000000000000, 0x0000000000000000);
    // src1=0, src2=anything → AND=0 → ZF=1; ANDNOT=src2 → CF=0 (if src2 nonzero)
    add_test("vtestps zf=1", {0xC4, 0xE2, 0x79, 0x0E, 0xCA}, s, FL_ZF | FL_CF);

    // VTESTPD: C4 E2 79 0F CA
    s.xmm[1] = xmm_from_u64(0x8000000000000000, 0x8000000000000000);
    s.xmm[2] = xmm_from_u64(0x8000000000000000, 0x8000000000000000);
    add_test("vtestpd all match", {0xC4, 0xE2, 0x79, 0x0F, 0xCA}, s, FL_ZF | FL_CF);
  }

  // =====================================================================
  // VEX 0F misc — VMOVMSKPS/PD, VPMOVMSKB, VCVT*, VRSQRTPS, VRCPPS, etc.
  // =====================================================================
  cat = "VEX 0F misc";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };
    auto add_gpr = [&](const char *name, std::vector<u8> code, ArchState init,
                        u64 flags_mask = FL_NONE) {
      tests.push_back({name, cat, std::move(code), init, flags_mask});
    };

    ArchState s;
    s.rflags = 0x2;

    // VMOVMSKPS: C5 F8 50 C1 = vmovmskps eax, xmm1 (NP, L=0)
    s.xmm[1] = xmm_from_u64(0x80000000FF000000, 0x00000000F0000000);
    add_gpr("vmovmskps eax,xmm1", {0xC5, 0xF8, 0x50, 0xC1}, s);

    // VMOVMSKPD: C5 F9 50 C1 = vmovmskpd eax, xmm1 (66, L=0)
    s.xmm[1] = xmm_from_u64(0x8000000000000000, 0x0000000000000001);
    add_gpr("vmovmskpd eax,xmm1", {0xC5, 0xF9, 0x50, 0xC1}, s);

    // VPMOVMSKB: C5 F9 D7 C1 = vpmovmskb eax, xmm1 (66, L=0)
    s.xmm[1] = xmm_from_u64(0xFF00FF00FF00FF00, 0x00FF00FF00FF00FF);
    add_gpr("vpmovmskb eax,xmm1", {0xC5, 0xF9, 0xD7, 0xC1}, s);

    // VCVTSS2SI: C5 FA 2D C1 = vcvtss2si eax, xmm1 (F3, L=0)
    // xmm1[31:0] = 0x41200000 = 10.0f
    s.xmm[1] = xmm_from_u64(0, 0x0000000041200000);
    add_gpr("vcvtss2si eax,xmm1", {0xC5, 0xFA, 0x2D, 0xC1}, s);

    // VCVTSD2SI: C5 FB 2D C1 = vcvtsd2si eax, xmm1 (F2, L=0)
    // xmm1[63:0] = 0x4024000000000000 = 10.0
    s.xmm[1] = xmm_from_u64(0, 0x4024000000000000);
    add_gpr("vcvtsd2si eax,xmm1", {0xC5, 0xFB, 0x2D, 0xC1}, s);

    // VCVTDQ2PD: C5 FA E6 C1 = vcvtdq2pd xmm0, xmm1 (F3, L=0)
    s.xmm[1] = xmm_from_u64(0, 0x0000000A00000005); // 10, 5
    add_xmm("vcvtdq2pd xmm0,xmm1", {0xC5, 0xFA, 0xE6, 0xC1}, s, 0x3);

    // VCVTPD2DQ: C5 FB E6 C1 = vcvtpd2dq xmm0, xmm1 (F2, L=0)
    // xmm1 = 3.0 (0x4008000000000000), 7.0 (0x401C000000000000)
    s.xmm[1] = xmm_from_u64(0x401C000000000000, 0x4008000000000000);
    add_xmm("vcvtpd2dq xmm0,xmm1", {0xC5, 0xFB, 0xE6, 0xC1}, s, 0x3);

    // VCVTTPD2DQ: C5 F9 E6 C1 = vcvttpd2dq xmm0, xmm1 (66, L=0)
    s.xmm[1] = xmm_from_u64(0x401C000000000000, 0x4008000000000000);
    add_xmm("vcvttpd2dq xmm0,xmm1", {0xC5, 0xF9, 0xE6, 0xC1}, s, 0x3);

    // VPMAXSW: C5 F1 EE C2 = vpmaxsw xmm0, xmm1, xmm2 (66, L=0)
    s.xmm[1] = xmm_from_u64(0x0001FFFF00038000, 0x7FFF00050003FFFE);
    s.xmm[2] = xmm_from_u64(0xFFFF0002800000FF, 0x0006FFFF7FFF0001);
    add_xmm("vpmaxsw xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xEE, 0xC2}, s, 0x7);

    // Note: VRSQRTPS, VRCPPS, VRSQRTSS, VRCPSS are approximate instructions.
    // Real hardware returns approximations (within 1.5*2^-12 relative error)
    // while our Sail model returns exact results, so we skip exact-match KVM tests.

    // VMOVLPS store: C5 F8 13 07 = vmovlps [rdi], xmm0 (NP, L=0)
    s.xmm[0] = xmm_from_u64(0xAAAABBBBCCCCDDDD, 0x1234567890ABCDEF);
    s.rdi = DATA_ADDR;
    {
      TestCase tc;
      tc.name = "vmovlps [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xC5, 0xF8, 0x13, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.compare_data_len = 8;
      tc.init_data = std::vector<u8>(16, 0);
      tests.push_back(std::move(tc));
    }

    // VMOVHPS store: C5 F8 17 07 = vmovhps [rdi], xmm0 (NP, L=0)
    {
      TestCase tc;
      tc.name = "vmovhps [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xC5, 0xF8, 0x17, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.compare_data_len = 8;
      tc.init_data = std::vector<u8>(16, 0);
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // VEX gather — AVX2 VGATHER instructions
  // =====================================================================
  cat = "VEX gather";
  {
    // Set up a data array at DATA_ADDR with known 32-bit values
    // data[0..31] = 0x10, 0x20, 0x30, 0x40 at dword offsets
    std::vector<u8> gather_data(64, 0);
    for (int i = 0; i < 8; i++) {
      uint32_t val = (uint32_t)(i + 1) * 0x11111111u;
      memcpy(&gather_data[i * 4], &val, 4);
    }

    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR; // base address

    // VPGATHERDD xmm0, [rdi + xmm2*1], xmm1
    // Indices: xmm2 = {0, 4, 8, 12} (dword offsets 0,1,2,3)
    // Mask: xmm1 = all sign bits set (all active)
    s.xmm[0] = xmm_from_u64(0, 0);
    s.xmm[1] = xmm_from_u64(0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF); // mask all set
    s.xmm[2] = xmm_from_u64(0x0000000C00000008, 0x0000000400000000); // indices

    // VEX.128.66.0F38.W0 90: C4 E2 71 90 04 17
    // But VSIB encoding: modrm=04 (mod=00, reg=0, rm=100=SIB), SIB=17 (scale=0, idx=2, base=7=rdi)
    // Actually: C4 E2 71 90 04 17
    {
      TestCase tc;
      tc.name = "vpgatherdd xmm0,[rdi+xmm2*1],xmm1";
      tc.category = cat;
      tc.code = {0xC4, 0xE2, 0x71, 0x90, 0x04, 0x17};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7; // xmm0, xmm1 (zeroed), xmm2
      tc.init_data = gather_data;
      tests.push_back(std::move(tc));
    }

    // VPGATHERDD with partial mask: only gather elements 0 and 2
    s.xmm[1] = xmm_from_u64(0x8000000000000000, 0x0000000080000000); // mask bits 0,2
    {
      TestCase tc;
      tc.name = "vpgatherdd partial mask";
      tc.category = cat;
      tc.code = {0xC4, 0xE2, 0x71, 0x90, 0x04, 0x17};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = gather_data;
      tests.push_back(std::move(tc));
    }

    // VGATHERDPS (same encoding as VPGATHERDD but FP interpretation)
    // C4 E2 71 92 04 17
    s.xmm[1] = xmm_from_u64(0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF);
    s.xmm[0] = xmm_from_u64(0, 0);
    {
      TestCase tc;
      tc.name = "vgatherdps xmm0,[rdi+xmm2*1],xmm1";
      tc.category = cat;
      tc.code = {0xC4, 0xE2, 0x71, 0x92, 0x04, 0x17};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = gather_data;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // K-register ops — KANDNW, KORW, KXNORW, KUNPCKBW, KORTESTW, KTESTW
  // =====================================================================
  cat = "K-register ops";
  {
    auto add_flags = [&](const char *name, std::vector<u8> code, ArchState init) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL});
    };

    ArchState s;
    s.rflags = 0x2;

    // Set up k1=0xAAAA, k2=0x5555 via KMOVW from GPR
    // We pre-load k-registers using KMOV r32->k then do the operation and read back with KMOV k->r32
    // Since KVM runs all code together, we encode a sequence.

    // Test KORW k3, k1, k2 then KMOVW eax, k3
    // Load k1=0xAAAA: mov eax, 0xAAAA / kmovw k1, eax
    // Load k2=0x5555: mov eax, 0x5555 / kmovw k2, eax
    // KORW k3, k1, k2: C5 EC 45 DB (VEX.256.NP.0F 45: k3=modrm.reg(011), k1=vvvv(001), k2=rm(011))
    // Actually: VEX.NDS.LZ.0F. Let me encode properly.
    // KORW uses VEX.L1.NP.0F.W0 45 /r
    // k3, k1, k2: modrm = 0xCB (mod=11, reg=001(k1), rm=011(k3)) wait...
    // Encoding: KORW k1, k2, k3: reg=dst, vvvv=src1, rm=src2
    // VEX byte1: R̄=1, vvvv=~k1, L=1, pp=00 → 1.1100.1.00 = 0xE4
    // C5 E4 45 D9 = KORW k3, k3, k1? No, need to be more careful.

    // Let me use a simpler approach: just test KORTESTW since it sets flags
    // Load k1=0x5555 via mov eax, 0x5555 / C5 F8 92 C8 (kmovw k1, eax)
    // Load k2=0xAAAA via mov eax, 0xAAAA / C5 F8 92 D0 (kmovw k2, eax)
    // KORTESTW k1, k2: C5 F8 98 CA (VEX.LZ.NP.0F.W0 98, modrm=CA: reg=k1(001), rm=k2(010))
    s.rax = 0x5555;
    s.rdx = 0xAAAA;
    // mov eax, 0x5555 already set. Use: C5 F8 92 C8 = kmovw k1, eax
    // C5 F8 92 D2 = kmovw k2, edx
    // C5 F8 98 CA = kortestw k1, k2
    add_flags("kortestw k1(5555),k2(AAAA) -> k1|k2=FFFF",
      {0xC5, 0xF8, 0x92, 0xC8,  // kmovw k1, eax (0x5555)
       0xC5, 0xF8, 0x92, 0xD2,  // kmovw k2, edx (0xAAAA)
       0xC5, 0xF8, 0x98, 0xCA}, // kortestw k1, k2
      s);

    // KORTESTW with zero result
    s.rax = 0;
    s.rdx = 0;
    add_flags("kortestw k1(0),k2(0) -> ZF=1",
      {0xC5, 0xF8, 0x92, 0xC8,
       0xC5, 0xF8, 0x92, 0xD2,
       0xC5, 0xF8, 0x98, 0xCA},
      s);

    // KTESTW: k1&k2 and ~k1&k2
    s.rax = 0xFFFF;
    s.rdx = 0x00FF;
    add_flags("ktestw k1(FFFF),k2(00FF)",
      {0xC5, 0xF8, 0x92, 0xC8,
       0xC5, 0xF8, 0x92, 0xD2,
       0xC5, 0xF8, 0x99, 0xCA},
      s);

    s.rax = 0x0000;
    s.rdx = 0xFFFF;
    add_flags("ktestw k1(0),k2(FFFF) -> ZF=1",
      {0xC5, 0xF8, 0x92, 0xC8,
       0xC5, 0xF8, 0x92, 0xD2,
       0xC5, 0xF8, 0x99, 0xCA},
      s);

    // --- K-register logical operations ---
    // All use k1, k2 as inputs (loaded via XSAVE), k3 as output (read via KMOVW eax, k3).
    // KMOVW eax, k3 = C5 F8 93 C3

    // KANDW k3, k1, k2: VEX.L1.0F.W0 41 /r
    // k3=reg(011), vvvv=~k1=1110, k2=rm(010) → C5 EC 41 DA
    {
      TestCase tc;
      tc.name = "kandw k3,k1,k2: AAAA & 5555 = 0";
      tc.category = cat;
      tc.code = {0xC5, 0xF4, 0x41, 0xDA,   // kandw k3, k1, k2
                 0xC5, 0xF8, 0x93, 0xC3};   // kmovw eax, k3
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xAAAA;
      tc.initial.kregs[2] = 0x5555;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KANDW — overlapping bits
    {
      TestCase tc;
      tc.name = "kandw k3,k1,k2: FF00 & 0FF0 = 0F00";
      tc.category = cat;
      tc.code = {0xC5, 0xF4, 0x41, 0xDA,
                 0xC5, 0xF8, 0x93, 0xC3};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xFF00;
      tc.initial.kregs[2] = 0x0FF0;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KORW k3, k1, k2: VEX.L1.0F.W0 45 /r → C5 EC 45 DA
    {
      TestCase tc;
      tc.name = "korw k3,k1,k2: AAAA | 5555 = FFFF";
      tc.category = cat;
      tc.code = {0xC5, 0xF4, 0x45, 0xDA,
                 0xC5, 0xF8, 0x93, 0xC3};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xAAAA;
      tc.initial.kregs[2] = 0x5555;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KXORW k3, k1, k2: VEX.L1.0F.W0 47 /r → C5 EC 47 DA
    {
      TestCase tc;
      tc.name = "kxorw k3,k1,k2: FFFF ^ 00FF = FF00";
      tc.category = cat;
      tc.code = {0xC5, 0xF4, 0x47, 0xDA,
                 0xC5, 0xF8, 0x93, 0xC3};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xFFFF;
      tc.initial.kregs[2] = 0x00FF;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KANDNW k3, k1, k2: VEX.L1.0F.W0 42 /r → C5 EC 42 DA
    // result = ~k1 & k2
    {
      TestCase tc;
      tc.name = "kandnw k3,k1,k2: ~FF00 & 0FF0 = 00F0";
      tc.category = cat;
      tc.code = {0xC5, 0xF4, 0x42, 0xDA,
                 0xC5, 0xF8, 0x93, 0xC3};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xFF00;
      tc.initial.kregs[2] = 0x0FF0;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KXNORW k3, k1, k2: VEX.L1.0F.W0 46 /r → C5 EC 46 DA
    // result = ~(k1 ^ k2)
    {
      TestCase tc;
      tc.name = "kxnorw k3,k1,k2: ~(FF00^00FF) = 00FF (lower 16)";
      tc.category = cat;
      tc.code = {0xC5, 0xF4, 0x46, 0xDA,
                 0xC5, 0xF8, 0x93, 0xC3};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xFF00;
      tc.initial.kregs[2] = 0x00FF;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KNOTW k3, k1: VEX.L0.0F.W0 44 /r → C5 F8 44 D9
    // dst=k3(011), src=k1(001), vvvv=1111
    {
      TestCase tc;
      tc.name = "knotw k3,k1: ~AAAA = 5555";
      tc.category = cat;
      tc.code = {0xC5, 0xF8, 0x44, 0xD9,
                 0xC5, 0xF8, 0x93, 0xC3};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xAAAA;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KUNPCKBW k3, k1, k2: VEX.L1.0F.W0 4B /r → C5 F4 4B DA
    // result = k1[7:0] : k2[7:0] (concatenate low bytes)
    // Use KMOVW preamble to load k1, k2 (XSAVE may not load reliably for this).
    {
      TestCase tc;
      tc.name = "kunpckbw k3,k1,k2: AB:CD = ABCD";
      tc.category = cat;
      tc.code = {0xC5, 0xF8, 0x92, 0xC8,   // kmovw k1, eax (0xAB)
                 0xC5, 0xF8, 0x92, 0xD2,   // kmovw k2, edx (0xCD)
                 0xC5, 0xF5, 0x4B, 0xDA,   // kunpckbw k3, k1, k2 (VEX.L1.66.0F.W0)
                 0xC5, 0xF8, 0x93, 0xC3};  // kmovw eax, k3
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = 0xAB;
      tc.initial.rdx = 0xCD;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KMOVW k1, m16: VEX.L0.0F.W0 90 /r (memory load)
    // Load k1 from [DATA_ADDR] containing 0x1234
    {
      TestCase tc;
      tc.name = "kmovw k1,m16: load 1234h";
      tc.category = cat;
      // mov rdi, DATA_ADDR; kmovw k1, [rdi]; kmovw eax, k1
      tc.code = {0x48, 0xBF, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,  // mov rdi, 0x10000 (DATA_ADDR)
                 0xC5, 0xF8, 0x90, 0x0F,   // kmovw k1, [rdi]
                 0xC5, 0xF8, 0x93, 0xC1};  // kmovw eax, k1
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.init_data = {0x34, 0x12};  // 0x1234 in little-endian
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KMOVW m16, k1: VEX.L0.0F.W0 91 /r (memory store)
    {
      TestCase tc;
      tc.name = "kmovw m16,k1: store BEEF to mem";
      tc.category = cat;
      // mov rdi, DATA_ADDR; kmovw [rdi], k1
      tc.code = {0x48, 0xBF, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,  // mov rdi, DATA_ADDR
                 0xC5, 0xF8, 0x91, 0x0F};  // kmovw [rdi], k1
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xBEEF;
      tc.flags_mask = FL_NONE;
      tc.compare_data_len = 2;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // EVEX blend — VPBLENDMD/Q, VBLENDMPS/PD
  // =====================================================================
  cat = "EVEX blend";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    ArchState s;
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x1111111122222222, 0x3333333344444444);
    s.xmm[2] = xmm_from_u64(0xAAAAAAAABBBBBBBB, 0xCCCCCCCCDDDDDDDD);

    // VPBLENDMD xmm0, xmm1, xmm2 (no mask = blend all from src2)
    // EVEX.128.66.0F38.W0 64 /r, aaa=000 (no mask)
    // EVEX: 62 [P0][P1][P2] 64 modrm
    // P0: R̄=1, X̄=1, B̄=1, R'̄=1, 00, mm=10 → 0xF2
    // P1: W=0, vvvv=~1=1110, 1, pp=01 → 0.1110.1.01 = 0x75
    // Wait, vvvv is inverted. xmm1 = 0001, inverted = 1110
    // P1: W=0, ~vvvv=1110, 1, pp=01 → 0111.0101 = 0x75
    // P2: z=0, L'L=00, b=0, V'̄=1, aaa=000 → 0.00.0.1.000 = 0x08
    // modrm: mod=11, reg=000(xmm0), rm=010(xmm2) → 0xC2
    add_xmm("vpblendmd xmm0,xmm1,xmm2 (no mask)",
      {0x62, 0xF2, 0x75, 0x08, 0x64, 0xC2}, s, 0x7);

    // VBLENDMPS xmm0, xmm1, xmm2 (no mask) — same as above but opcode 65
    add_xmm("vblendmps xmm0,xmm1,xmm2 (no mask)",
      {0x62, 0xF2, 0x75, 0x08, 0x65, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // VLDDQU — VEX 0F F0 unaligned load
  // =====================================================================
  cat = "VLDDQU";
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;

    // VLDDQU xmm0, [rdi]: C5 FB F0 07 (VEX.128.F2.0F F0, modrm=[rdi])
    std::vector<u8> lddqu_data(32, 0);
    for (int i = 0; i < 16; i++)
      lddqu_data[i] = 0x10 + i;
    {
      TestCase tc;
      tc.name = "vlddqu xmm0,[rdi]";
      tc.category = cat;
      tc.code = {0xC5, 0xFB, 0xF0, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x1;
      tc.init_data = lddqu_data;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // VHADDPS/VHSUBPS/VADDSUBPS — VEX horizontal FP
  // =====================================================================
  cat = "VEX horiz FP";
  {
    auto add_test = [&](const char *name, std::vector<u8> code, ArchState init, u64 mask) {
      tests.push_back({name, cat, std::move(code), init, mask, 0xFFFF});
    };

    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // VHADDPS xmm2, xmm0, xmm1: C5 FB 7C D1
    add_test("vhaddps xmm", {0xC5, 0xFB, 0x7C, 0xD1}, s, FL_NONE);

    // VHSUBPS xmm3, xmm0, xmm1: C5 FB 7D D9
    add_test("vhsubps xmm", {0xC5, 0xFB, 0x7D, 0xD9}, s, FL_NONE);

    // VADDSUBPS xmm4, xmm0, xmm1: C5 FB D0 E1
    add_test("vaddsubps xmm", {0xC5, 0xFB, 0xD0, 0xE1}, s, FL_NONE);

    // VHADDPD xmm5, xmm0, xmm1 (66.0F 7C)
    s.xmm[0] = xmm_from_f64(1.0, 3.0);
    s.xmm[1] = xmm_from_f64(5.0, 7.0);
    add_test("vhaddpd xmm", {0xC5, 0xF9, 0x7C, 0xE9}, s, FL_NONE);
  }

  // =====================================================================
  // VPTEST — VEX 0F38 17
  // =====================================================================
  cat = "VPTEST";
  {
    auto add_test = [&](const char *name, std::vector<u8> code, ArchState init, u64 mask) {
      tests.push_back({name, cat, std::move(code), init, mask});
    };

    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0xFFFFFFFFFFFFFFFFULL, 0xFFFFFFFFFFFFFFFFULL);
    s.xmm[1] = xmm_from_u64(0xFFFFFFFFFFFFFFFFULL, 0xFFFFFFFFFFFFFFFFULL);
    // VPTEST xmm0, xmm1: C4 E2 79 17 C1
    add_test("vptest all-ones", {0xC4, 0xE2, 0x79, 0x17, 0xC1}, s, FL_ZF | FL_CF);

    s.xmm[0] = xmm_from_u64(0, 0);
    add_test("vptest zero,ones", {0xC4, 0xE2, 0x79, 0x17, 0xC1}, s, FL_ZF | FL_CF);

    s.xmm[0] = xmm_from_u64(0xFFFFFFFFFFFFFFFFULL, 0xFFFFFFFFFFFFFFFFULL);
    s.xmm[1] = xmm_from_u64(0, 0);
    add_test("vptest ones,zero", {0xC4, 0xE2, 0x79, 0x17, 0xC1}, s, FL_ZF | FL_CF);
  }

  // =====================================================================
  // VPCMPGTQ — VEX 0F38 37
  // =====================================================================
  cat = "VPCMPGTQ";
  {
    auto add_test = [&](const char *name, std::vector<u8> code, ArchState init, u64 mask) {
      tests.push_back({name, cat, std::move(code), init, mask, 0xFFFF});
    };

    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(10, 5);
    s.xmm[1] = xmm_from_u64(3, 8);
    // VPCMPGTQ xmm2, xmm0, xmm1: C4 E2 79 37 D1
    add_test("vpcmpgtq", {0xC4, 0xE2, 0x79, 0x37, 0xD1}, s, FL_NONE);
  }

  // =====================================================================
  // VPERMILPS/PD — VEX permute
  // =====================================================================
  cat = "VPERMIL";
  {
    auto add_test = [&](const char *name, std::vector<u8> code, ArchState init, u64 mask) {
      tests.push_back({name, cat, std::move(code), init, mask, 0xFFFF});
    };

    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);

    // VPERMILPS xmm1, xmm0, imm8=0x1B (reverse)
    // VEX.128.66.0F3A 04 /r ib: C4 E3 79 04 C8 1B
    add_test("vpermilps imm reverse", {0xC4, 0xE3, 0x79, 0x04, 0xC8, 0x1B}, s, FL_NONE);

    // VPERMILPS xmm1, xmm0, imm8=0x00 (broadcast element 0)
    add_test("vpermilps imm bcast", {0xC4, 0xE3, 0x79, 0x04, 0xC8, 0x00}, s, FL_NONE);

    // VPERMILPD xmm1, xmm0, imm8=0x01 (swap qwords)
    s.xmm[0] = xmm_from_f64(1.0, 2.0);
    add_test("vpermilpd imm swap", {0xC4, 0xE3, 0x79, 0x05, 0xC8, 0x01}, s, FL_NONE);
  }

  // =====================================================================
  // VMOVNTDQ — VEX non-temporal store
  // =====================================================================
  cat = "VMOVNTDQ";
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    s.xmm[0] = xmm_from_u64(0x8877665544332211ULL, 0x01FFEEDDCCBBAA99ULL);

    // VMOVNTDQ [rdi], xmm0: C5 F9 E7 07
    {
      TestCase tc;
      tc.name = "vmovntdq [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xC5, 0xF9, 0xE7, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // Vector memory stores — verify memory output
  // =====================================================================
  cat = "Vec stores";
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    s.xmm[0] = xmm_from_u64(0x1122334455667788ULL, 0x99AABBCCDDEEFF00ULL);
    s.xmm[1] = xmm_from_u64(0xAAAABBBBCCCCDDDDULL, 0xEEEEFFFF00001111ULL);

    // MOVAPS [rdi], xmm0: 0F 29 07
    {
      TestCase tc;
      tc.name = "movaps [rdi],xmm0";
      tc.category = cat;
      tc.code = {0x0F, 0x29, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // MOVUPS [rdi], xmm0: 0F 11 07
    {
      TestCase tc;
      tc.name = "movups [rdi],xmm0";
      tc.category = cat;
      tc.code = {0x0F, 0x11, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // MOVDQU [rdi], xmm0: F3 0F 7F 07
    {
      TestCase tc;
      tc.name = "movdqu [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xF3, 0x0F, 0x7F, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // MOVDQA [rdi], xmm0: 66 0F 7F 07
    {
      TestCase tc;
      tc.name = "movdqa [rdi],xmm0";
      tc.category = cat;
      tc.code = {0x66, 0x0F, 0x7F, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // MOVLPS [rdi], xmm0: 0F 13 07 (store low 64 bits)
    {
      TestCase tc;
      tc.name = "movlps [rdi],xmm0";
      tc.category = cat;
      tc.code = {0x0F, 0x13, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }

    // MOVHPS [rdi], xmm0: 0F 17 07 (store high 64 bits)
    {
      TestCase tc;
      tc.name = "movhps [rdi],xmm0";
      tc.category = cat;
      tc.code = {0x0F, 0x17, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }

    // MOVSS [rdi], xmm0: F3 0F 11 07 (store 32 bits)
    {
      TestCase tc;
      tc.name = "movss [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xF3, 0x0F, 0x11, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // MOVSD [rdi], xmm0: F2 0F 11 07 (store 64 bits)
    {
      TestCase tc;
      tc.name = "movsd [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xF2, 0x0F, 0x11, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }

    // VMOVAPS [rdi], xmm0: C5 F8 29 07
    {
      TestCase tc;
      tc.name = "vmovaps [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xC5, 0xF8, 0x29, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // VMOVDQU [rdi], xmm0: C5 FA 7F 07
    {
      TestCase tc;
      tc.name = "vmovdqu [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xC5, 0xFA, 0x7F, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // VMOVAPS [rdi], ymm0: need to set up ymm0 first
    // Use VINSERTF128 ymm0, ymm0, xmm1, 1 (C4 E3 7D 18 C1 01) to set hi half
    {
      TestCase tc;
      tc.name = "vmovaps [rdi],ymm0 (32 bytes)";
      tc.category = cat;
      tc.code = {0xC4, 0xE3, 0x7D, 0x18, 0xC1, 0x01,  // vinsertf128 ymm0,ymm0,xmm1,1
                 0xC5, 0xFC, 0x29, 0x07};               // vmovaps [rdi], ymm0
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 32;
      tests.push_back(std::move(tc));
    }

    // VMOVDQU [rdi], ymm0: C5 FE 7F 07
    {
      TestCase tc;
      tc.name = "vmovdqu [rdi],ymm0 (32 bytes)";
      tc.category = cat;
      tc.code = {0xC4, 0xE3, 0x7D, 0x18, 0xC1, 0x01,  // vinsertf128 ymm0,ymm0,xmm1,1
                 0xC5, 0xFE, 0x7F, 0x07};               // vmovdqu [rdi], ymm0
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 32;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // Indirect JMP/CALL — register and memory operands
  // =====================================================================
  cat = "Indirect JMP";
  {
    // JMP rax: FF E0 — jump to rax (CODE_ADDR + 2 = right after the JMP)
    {
      TestCase tc;
      tc.name = "jmp rax";
      tc.category = cat;
      tc.code = {0xFF, 0xE0};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = CODE_ADDR + 2;  // target = after JMP
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // JMP rax skipping bytes: FF E0 CC CC (jump over INT3s)
    {
      TestCase tc;
      tc.name = "jmp rax (skip INT3)";
      tc.category = cat;
      tc.code = {0xFF, 0xE0, 0xCC, 0xCC};  // JMP rax, INT3, INT3
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = CODE_ADDR + 4;  // skip the INT3 bytes
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // JMP [rdi]: FF 27 — indirect through memory
    {
      TestCase tc;
      tc.name = "jmp [rdi]";
      tc.category = cat;
      tc.code = {0xFF, 0x27, 0xCC, 0xCC};  // JMP [rdi], INT3, INT3
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      // [DATA_ADDR] = CODE_ADDR + 4 (skip JMP and INT3s)
      u64 target = CODE_ADDR + 4;
      tc.init_data.resize(8);
      memcpy(tc.init_data.data(), &target, 8);
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // CALL rax: FF D0 — push return addr, jump to rax
    // target = CODE_ADDR + 2 (right after CALL), so RET addr = CODE_ADDR+2
    // RSP should decrease by 8
    {
      TestCase tc;
      tc.name = "call rax";
      tc.category = cat;
      tc.code = {0xFF, 0xD0};  // CALL rax
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = CODE_ADDR + 2;  // target = right after CALL (then HLT)
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // CALL [rdi]: FF 17 — indirect call through memory
    {
      TestCase tc;
      tc.name = "call [rdi]";
      tc.category = cat;
      tc.code = {0xFF, 0x17, 0xCC, 0xCC};  // CALL [rdi], INT3, INT3
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      u64 target2 = CODE_ADDR + 4;
      tc.init_data.resize(8);
      memcpy(tc.init_data.data(), &target2, 8);
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // CALL rax + RET: call to a RET instruction, verify round-trip.
    // Layout: CALL rax; NOP; NOP; NOP; HLT; RET
    // CALL pushes CODE_ADDR+2, jumps to CODE_ADDR+6 (RET).
    // RET pops CODE_ADDR+2, jumps there. NOPs then HLT.
    {
      TestCase tc;
      tc.name = "call rax + ret";
      tc.category = cat;
      tc.code = {0xFF, 0xD0,           // 0: CALL rax (2 bytes)
                 0x90, 0x90, 0x90,     // 2: NOP NOP NOP (landing pad)
                 0xF4,                 // 5: HLT (stop after return)
                 0xC3};                // 6: RET (target of CALL)
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = CODE_ADDR + 6;  // point to the RET
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // FP conversion edge cases
  // =====================================================================
  cat = "FP conv edge";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp = 0x1) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    ArchState s;
    s.rflags = 0x2;
    s.mxcsr = 0x1F80;  // default MXCSR

    // CVTPS2PD xmm0, xmm1: 0F 5A C1 (convert 2 floats → 2 doubles)
    // Denormal float: 0x00000001 = smallest subnormal
    s.xmm[1] = xmm_from_u32(0x00000001, 0x80000001, 0, 0);  // +denorm, -denorm
    add_xmm("cvtps2pd denormals", {0x0F, 0x5A, 0xC1}, s);

    // CVTPS2PD with NaN: 0x7FC00000 = quiet NaN, 0x7F800001 = signaling NaN
    s.xmm[1] = xmm_from_u32(0x7FC00000, 0x7F800001, 0, 0);
    add_xmm("cvtps2pd NaN", {0x0F, 0x5A, 0xC1}, s);

    // CVTPS2PD with Inf: 0x7F800000 = +Inf, 0xFF800000 = -Inf
    s.xmm[1] = xmm_from_u32(0x7F800000, 0xFF800000, 0, 0);
    add_xmm("cvtps2pd Inf", {0x0F, 0x5A, 0xC1}, s);

    // CVTPS2PD with -0: 0x80000000
    s.xmm[1] = xmm_from_u32(0x80000000, 0x00000000, 0, 0);  // -0, +0
    add_xmm("cvtps2pd neg zero", {0x0F, 0x5A, 0xC1}, s);

    // CVTPD2PS xmm0, xmm1: 66 0F 5A C1 (convert 2 doubles → 2 floats)
    // Large double that loses precision: 1.0 + 2^-24 (just beyond float precision)
    {
      double d1 = 1.0 + ldexp(1.0, -24);  // 1.0000000596... rounds to 1.0f
      double d2 = 1.0e38;                   // large but representable as float
      u64 b1, b2;
      memcpy(&b1, &d1, 8);
      memcpy(&b2, &d2, 8);
      s.xmm[1] = xmm_from_u64(b1, b2);
    }
    add_xmm("cvtpd2ps precision loss", {0x66, 0x0F, 0x5A, 0xC1}, s);

    // CVTSD2SS xmm0, xmm1: F2 0F 5A C1 (convert scalar double → scalar float)
    // Double that's too large for float: ~3.5e38 → +Inf
    {
      double big = 3.5e38;
      u64 bbig;
      memcpy(&bbig, &big, 8);
      s.xmm[0] = xmm_from_u32(0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF);
      s.xmm[1] = xmm_from_u64(bbig, 0);
    }
    add_xmm("cvtsd2ss overflow to inf", {0xF2, 0x0F, 0x5A, 0xC1}, s);

    // CVTSI2SS xmm0, eax: F3 0F 2A C0 (convert int32 → float)
    // Large integer that can't be exactly represented: 2^24 + 1 = 16777217
    s.xmm[0] = {};
    s.rax = 16777217;  // 2^24+1: rounds to 16777216.0f or 16777218.0f
    add_xmm("cvtsi2ss large int", {0xF3, 0x0F, 0x2A, 0xC0}, s);

    // CVTSI2SS xmm0, rax: F3 48 0F 2A C0 (convert int64 → float)
    s.rax = (1ULL << 53) + 1;  // just beyond double precision
    add_xmm("cvtsi2ss int64 rounding", {0xF3, 0x48, 0x0F, 0x2A, 0xC0}, s);

    // CVTSD2SS round-trip: double → float → double
    // Start with a double that's exactly representable as float
    {
      float f = 1.5f;
      double d = (double)f;
      u64 bd;
      memcpy(&bd, &d, 8);
      s.xmm[1] = xmm_from_u64(bd, 0);
      s.xmm[0] = {};
    }
    // CVTSD2SS xmm0, xmm1; CVTSS2SD xmm0, xmm0
    add_xmm("cvtsd2ss+cvtss2sd round-trip",
             {0xF2, 0x0F, 0x5A, 0xC1,   // cvtsd2ss xmm0, xmm1
              0xF3, 0x0F, 0x5A, 0xC0},  // cvtss2sd xmm0, xmm0
             s);
  }

  // =====================================================================
  // PUSH/POP memory operands
  // =====================================================================
  cat = "PUSH/POP mem";
  {
    // PUSH qword [rdi]: FF 37 — push value at [rdi] onto stack
    // Stack is verified by comparing RSP and the value pushed (read via POP rax)
    {
      TestCase tc;
      tc.name = "push qword [rdi]";
      tc.category = cat;
      // push qword [rdi]; pop rax (verify stack content)
      tc.code = {0xFF, 0x37,  // push qword [rdi]
                 0x58};        // pop rax
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      u64 val = 0xDEADBEEFCAFEBABEULL;
      tc.init_data.resize(8);
      memcpy(tc.init_data.data(), &val, 8);
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // POP qword [rdi]: 8F 07 — pop from stack into memory
    {
      TestCase tc;
      tc.name = "pop qword [rdi]";
      tc.category = cat;
      // push rax; pop qword [rdi]
      tc.code = {0x50,         // push rax
                 0x8F, 0x07};  // pop qword [rdi]
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0x123456789ABCDEF0ULL;
      tc.flags_mask = FL_NONE;
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }

    // PUSH imm16: 66 68 imm16 — push 16-bit immediate
    // Verify stack content via pop
    {
      TestCase tc;
      tc.name = "push imm16 0x1234";
      tc.category = cat;
      // push 0x1234; pop rax
      tc.code = {0x66, 0x68, 0x34, 0x12,  // push 0x1234
                 0x66, 0x58};               // pop ax (16-bit)
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = 0;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // PUSH imm8: 6A imm8 — push sign-extended 8-bit immediate
    {
      TestCase tc;
      tc.name = "push imm8 0xFF (-1)";
      tc.category = cat;
      // push -1; pop rax
      tc.code = {0x6A, 0xFF,  // push -1 (sign-extended to 64-bit)
                 0x58};        // pop rax
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // PUSH imm32: 68 imm32 — push sign-extended 32-bit immediate
    {
      TestCase tc;
      tc.name = "push imm32 0x80000000";
      tc.category = cat;
      // push 0x80000000; pop rax (sign-extends to 0xFFFFFFFF80000000)
      tc.code = {0x68, 0x00, 0x00, 0x00, 0x80,  // push 0x80000000
                 0x58};                            // pop rax
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // LOCK prefix memory operations — read-modify-write on memory
  // =====================================================================
  cat = "LOCK mem";
  {
    // LOCK ADD [rdi], eax: F0 01 07  (32-bit)
    {
      TestCase tc;
      tc.name = "lock add [rdi],eax 32";
      tc.category = cat;
      tc.code = {0xF0, 0x01, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0x100;
      tc.init_data = {0x34, 0x12, 0x00, 0x00};  // [rdi] = 0x1234
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK ADD [rdi], rax: F0 48 01 07  (64-bit)
    {
      TestCase tc;
      tc.name = "lock add [rdi],rax 64";
      tc.category = cat;
      tc.code = {0xF0, 0x48, 0x01, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0x1000000000ULL;
      tc.init_data = {0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00};
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }

    // LOCK SUB [rdi], ecx: F0 29 0F  (32-bit)
    {
      TestCase tc;
      tc.name = "lock sub [rdi],ecx 32";
      tc.category = cat;
      tc.code = {0xF0, 0x29, 0x0F};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rcx = 1;
      tc.init_data = {0x00, 0x00, 0x00, 0x00};  // 0 - 1 = underflow
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK OR [rdi], eax: F0 09 07  (32-bit)
    {
      TestCase tc;
      tc.name = "lock or [rdi],eax 32";
      tc.category = cat;
      tc.code = {0xF0, 0x09, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0xFF00FF00;
      tc.init_data = {0x0F, 0x0F, 0x0F, 0x0F};
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK AND [rdi], eax: F0 21 07  (32-bit)
    {
      TestCase tc;
      tc.name = "lock and [rdi],eax 32";
      tc.category = cat;
      tc.code = {0xF0, 0x21, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0xFF00FF00;
      tc.init_data = {0xAB, 0xCD, 0xEF, 0x12};
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK XOR [rdi], eax: F0 31 07  (32-bit)
    {
      TestCase tc;
      tc.name = "lock xor [rdi],eax 32";
      tc.category = cat;
      tc.code = {0xF0, 0x31, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0xFFFFFFFF;
      tc.init_data = {0xAA, 0x55, 0xAA, 0x55};
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK INC dword [rdi]: F0 FF 07
    {
      TestCase tc;
      tc.name = "lock inc dword [rdi]";
      tc.category = cat;
      tc.code = {0xF0, 0xFF, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.init_data = {0xFF, 0xFF, 0xFF, 0x7F};  // 0x7FFFFFFF → overflow
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK DEC dword [rdi]: F0 FF 0F
    {
      TestCase tc;
      tc.name = "lock dec dword [rdi]";
      tc.category = cat;
      tc.code = {0xF0, 0xFF, 0x0F};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.init_data = {0x00, 0x00, 0x00, 0x00};  // 0 → underflow
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK XADD [rdi], eax: F0 0F C1 07
    // Swaps src and dst, then adds. [rdi] += eax, eax gets old [rdi].
    {
      TestCase tc;
      tc.name = "lock xadd [rdi],eax 32";
      tc.category = cat;
      tc.code = {0xF0, 0x0F, 0xC1, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 10;
      tc.init_data = {0x05, 0x00, 0x00, 0x00};  // [rdi] = 5
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK BTS [rdi], eax: F0 0F AB 07
    // Set bit eax in [rdi], CF = old bit value
    {
      TestCase tc;
      tc.name = "lock bts [rdi],eax (bit 3)";
      tc.category = cat;
      tc.code = {0xF0, 0x0F, 0xAB, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 3;  // set bit 3
      tc.init_data = {0x00, 0x00, 0x00, 0x00};  // bit 3 was 0
      tc.flags_mask = FL_CF;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK BTR [rdi], eax: F0 0F B3 07
    // Reset bit eax in [rdi], CF = old bit value
    {
      TestCase tc;
      tc.name = "lock btr [rdi],eax (bit 7)";
      tc.category = cat;
      tc.code = {0xF0, 0x0F, 0xB3, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 7;  // reset bit 7
      tc.init_data = {0xFF, 0x00, 0x00, 0x00};  // bit 7 was 1
      tc.flags_mask = FL_CF;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK BTC [rdi], eax: F0 0F BB 07
    // Complement bit eax in [rdi], CF = old bit value
    {
      TestCase tc;
      tc.name = "lock btc [rdi],eax (bit 0)";
      tc.category = cat;
      tc.code = {0xF0, 0x0F, 0xBB, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0;  // toggle bit 0
      tc.init_data = {0x01, 0x00, 0x00, 0x00};  // bit 0 was 1 → 0
      tc.flags_mask = FL_CF;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // VPERM2F128 — 256-bit lane permute (use VINSERTF128 to set up YMM state)
  // =====================================================================
  cat = "VPERM2F128";
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);
    s.xmm[2] = xmm_from_f32(9.0f, 10.0f, 11.0f, 12.0f);
    // Use VINSERTF128 to set up ymm0 = {hi:xmm1, lo:xmm0}, then VPERM2F128
    // VINSERTF128 ymm0, ymm0, xmm1, 1: C4 E3 7D 18 C1 01
    // Then VPERM2F128 ymm3, ymm0, ymm0, 0x01: swap halves
    // C4 E3 7D 06 D8 01 (dst=ymm3, vvvv=ymm0, src2=ymm0, imm=0x01)
    {
      TestCase tc;
      tc.name = "vperm2f128 swap";
      tc.category = cat;
      // Setup: vinsertf128 ymm0, ymm0, xmm1, 1
      // Then: vperm2f128 ymm3, ymm0, ymm0, 0x01
      tc.code = {0xC4, 0xE3, 0x7D, 0x18, 0xC1, 0x01,   // vinsertf128
                 0xC4, 0xE3, 0x7D, 0x06, 0xD8, 0x01};  // vperm2f128
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0xFFFF;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // VINSERTI128/VEXTRACTI128 — AVX2 lane insert/extract
  // =====================================================================
  cat = "VEX insert/extract i128";
  {
    auto add_test = [&](const char *name, std::vector<u8> code, ArchState init, u64 mask) {
      tests.push_back({name, cat, std::move(code), init, mask, 0xFFFF});
    };

    ArchState s;
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x1111111111111111ULL, 0x2222222222222222ULL);
    s.xmm[1] = xmm_from_u64(0xAAAAAAAAAAAAAAAAULL, 0xBBBBBBBBBBBBBBBBULL);

    // VINSERTI128 ymm2, ymm0, xmm1, 1
    add_test("vinserti128 hi", {0xC4, 0xE3, 0x7D, 0x38, 0xD1, 0x01}, s, FL_NONE);

    // VINSERTI128 ymm2, ymm0, xmm1, 0
    add_test("vinserti128 lo", {0xC4, 0xE3, 0x7D, 0x38, 0xD1, 0x00}, s, FL_NONE);

    // VEXTRACTI128 xmm3, ymm0, 1
    add_test("vextracti128 hi", {0xC4, 0xE3, 0x7D, 0x39, 0xC3, 0x01}, s, FL_NONE);

    // VEXTRACTI128 xmm3, ymm0, 0
    add_test("vextracti128 lo", {0xC4, 0xE3, 0x7D, 0x39, 0xC3, 0x00}, s, FL_NONE);
  }

  // =====================================================================
  // VPMASKMOVD — VEX masked load/store
  // =====================================================================
  cat = "VPMASKMOVD";
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;

    // Set mask in xmm1: sign bits set for elements 0 and 2
    s.xmm[1] = xmm_from_u32(0x80000000u, 0x00000000u, 0x80000000u, 0x00000000u);

    // Memory data: 0x11111111, 0x22222222, 0x33333333, 0x44444444
    std::vector<u8> data(16);
    for (int i = 0; i < 4; i++) {
      uint32_t v = (uint32_t)(i + 1) * 0x11111111u;
      memcpy(data.data() + i * 4, &v, 4);
    }

    // VPMASKMOVD xmm0, xmm1, [rdi]: VEX.NDS.128.66.0F38 8C /r
    // C4 E2 71 8C 07 (vvvv=xmm1=~0001=1110 → 0111_0001 = 0x71, modrm=07=[rdi])
    {
      TestCase tc;
      tc.name = "vpmaskmovd load partial";
      tc.category = cat;
      tc.code = {0xC4, 0xE2, 0x71, 0x8C, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x1;
      tc.init_data = data;
      tests.push_back(std::move(tc));
    }
  }

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
  }
}

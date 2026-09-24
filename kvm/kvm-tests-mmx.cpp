#include "kvm-harness.h"

void add_mmx_tests(std::vector<TestCase> &tests) {
  std::string cat;

  // MMX results are read back to GPRs via REX.W 0F 7E (MOVQ r64, mm).
  // MM registers are loaded via REX.W 0F 6E (MOVQ mm, r/m64).
  //
  // Encoding helpers:
  //   REX.W 0F 6E /r: MOVQ mm, r/m64  (modrm reg=mm, rm=gpr)
  //   REX.W 0F 7E /r: MOVQ r/m64, mm  (modrm reg=mm, rm=gpr)
  //   modrm mod=11, reg=mm, rm=gpr
  //
  //   MOVQ mm0, rax: REX.W=48, 0F 6E, modrm=C0 (reg=0, rm=0)
  //   MOVQ mm1, rbx: REX.W=48, 0F 6E, modrm=CB (reg=1, rm=3)
  //   MOVQ rax, mm0: REX.W=48, 0F 7E, modrm=C0 (reg=0, rm=0)
  //   MOVQ rbx, mm1: REX.W=48, 0F 7E, modrm=C8 (reg=1, rm=0) -> rax
  //     Actually: MOVQ r/m64, mm means modrm reg=mm, rm=dest_gpr
  //     MOVQ rax, mm1: 48 0F 7E C8 (reg=1, rm=0=rax)

  // Helper: load mm0 from rax, mm1 from rbx, do op, read mm0 to rax
  // Prefix bytes: 48 0F 6E C0 = MOVQ mm0, rax
  //               48 0F 6E CB = MOVQ mm1, rbx
  //               48 0F 7E C0 = MOVQ rax, mm0

  auto add = [&](const char *name, std::vector<u8> code, ArchState init) {
    tests.push_back({name, cat, std::move(code), init, FL_ALL, 0, false});
  };

  // =====================================================================
  // MMX Arithmetic
  // =====================================================================
  cat = "MMX arith";
  {
    // PADDB mm0, mm1
    {
      ArchState s;
      s.rax = 0x0102030405060708;
      s.rbx = 0x1020304050607080;
      add("paddb mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,  // MOVQ mm0, rax
        0x48, 0x0F, 0x6E, 0xCB,  // MOVQ mm1, rbx
        0x0F, 0xFC, 0xC1,        // PADDB mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,  // MOVQ rax, mm0
        0x0F, 0x77,              // EMMS
      }, s);
    }

    // PADDW mm0, mm1
    {
      ArchState s;
      s.rax = 0x0001000200030004;
      s.rbx = 0x0010002000300040;
      add("paddw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xFD, 0xC1,        // PADDW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PADDD mm0, mm1
    {
      ArchState s;
      s.rax = 0x0000000100000002;
      s.rbx = 0x0000001000000020;
      add("paddd mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xFE, 0xC1,        // PADDD mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PADDQ mm0, mm1
    {
      ArchState s;
      s.rax = 0x00000000FFFFFFFF;
      s.rbx = 0x0000000000000001;
      add("paddq mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xD4, 0xC1,        // PADDQ mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PSUBB mm0, mm1
    {
      ArchState s;
      s.rax = 0x1020304050607080;
      s.rbx = 0x0102030405060708;
      add("psubb mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xF8, 0xC1,        // PSUBB mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PSUBW mm0, mm1
    {
      ArchState s;
      s.rax = 0x0100020003000400;
      s.rbx = 0x0010002000300040;
      add("psubw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xF9, 0xC1,        // PSUBW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PSUBD mm0, mm1
    {
      ArchState s;
      s.rax = 0x0000001000000020;
      s.rbx = 0x0000000100000002;
      add("psubd mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xFA, 0xC1,        // PSUBD mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PSUBQ mm0, mm1
    {
      ArchState s;
      s.rax = 0x0000000100000000;
      s.rbx = 0x0000000000000001;
      add("psubq mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xFB, 0xC1,        // PSUBQ mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PMULLW mm0, mm1
    {
      ArchState s;
      s.rax = 0x0003000400050006;
      s.rbx = 0x0007000800090002;
      add("pmullw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xD5, 0xC1,        // PMULLW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PMULHW mm0, mm1
    {
      ArchState s;
      s.rax = 0x7FFF800000010064;
      s.rbx = 0x7FFF800000020064;
      add("pmulhw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xE5, 0xC1,        // PMULHW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PMULHUW mm0, mm1
    {
      ArchState s;
      s.rax = 0xFFFF800000010064;
      s.rbx = 0xFFFF800000020064;
      add("pmulhuw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xE4, 0xC1,        // PMULHUW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PMULUDQ mm0, mm1
    {
      ArchState s;
      s.rax = 0x00000000FFFFFFFF;
      s.rbx = 0x00000000FFFFFFFF;
      add("pmuludq mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xF4, 0xC1,        // PMULUDQ mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PMADDWD mm0, mm1
    {
      ArchState s;
      s.rax = 0x0003FFFD00020005;
      s.rbx = 0x000400040003FFFE;
      add("pmaddwd mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xF5, 0xC1,        // PMADDWD mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PSADBW mm0, mm1
    {
      ArchState s;
      s.rax = 0x0102030405060708;
      s.rbx = 0x0807060504030201;
      add("psadbw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xF6, 0xC1,        // PSADBW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PAVGB mm0, mm1
    {
      ArchState s;
      s.rax = 0x0102030405060708;
      s.rbx = 0x0807060504030201;
      add("pavgb mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xE0, 0xC1,        // PAVGB mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PAVGW mm0, mm1
    {
      ArchState s;
      s.rax = 0x0001000200030004;
      s.rbx = 0x0005000600070008;
      add("pavgw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xE3, 0xC1,        // PAVGW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }
  }

  // =====================================================================
  // MMX Saturating Arithmetic
  // =====================================================================
  cat = "MMX saturate";
  {
    // PADDSB mm0, mm1 (signed saturating add bytes)
    {
      ArchState s;
      s.rax = 0x7F01FE80007F8001;
      s.rbx = 0x0101FF800180FF01;
      add("paddsb mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xEC, 0xC1,        // PADDSB mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PADDSW mm0, mm1
    {
      ArchState s;
      s.rax = 0x7FFF000180000001;
      s.rbx = 0x00010001FFFF8000;
      add("paddsw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xED, 0xC1,        // PADDSW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PADDUSB mm0, mm1 (unsigned saturating add bytes)
    {
      ArchState s;
      s.rax = 0xFF01FE80007F8001;
      s.rbx = 0x0101FF800180FF01;
      add("paddusb mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xDC, 0xC1,        // PADDUSB mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PADDUSW mm0, mm1
    {
      ArchState s;
      s.rax = 0xFFFF000180000001;
      s.rbx = 0x00010001FFFF8000;
      add("paddusw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xDD, 0xC1,        // PADDUSW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PSUBSB mm0, mm1
    {
      ArchState s;
      s.rax = 0x7F01FE80007F8001;
      s.rbx = 0xFF01017F0180FF01;
      add("psubsb mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xE8, 0xC1,        // PSUBSB mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PSUBSW mm0, mm1
    {
      ArchState s;
      s.rax = 0x7FFF000180000001;
      s.rbx = 0xFFFF00017FFF8000;
      add("psubsw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xE9, 0xC1,        // PSUBSW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PSUBUSB mm0, mm1
    {
      ArchState s;
      s.rax = 0xFF01FE80007F8001;
      s.rbx = 0x0101FF800180FF01;
      add("psubusb mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xD8, 0xC1,        // PSUBUSB mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PSUBUSW mm0, mm1
    {
      ArchState s;
      s.rax = 0xFFFF000180000001;
      s.rbx = 0x00010001FFFF8000;
      add("psubusw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xD9, 0xC1,        // PSUBUSW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }
  }

  // =====================================================================
  // MMX Logical
  // =====================================================================
  cat = "MMX logical";
  {
    // PAND mm0, mm1
    {
      ArchState s;
      s.rax = 0xFF00FF00FF00FF00;
      s.rbx = 0x0F0F0F0F0F0F0F0F;
      add("pand mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xDB, 0xC1,        // PAND mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PANDN mm0, mm1
    {
      ArchState s;
      s.rax = 0xFF00FF00FF00FF00;
      s.rbx = 0x0F0F0F0F0F0F0F0F;
      add("pandn mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xDF, 0xC1,        // PANDN mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // POR mm0, mm1
    {
      ArchState s;
      s.rax = 0xFF00FF00FF00FF00;
      s.rbx = 0x0F0F0F0F0F0F0F0F;
      add("por mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xEB, 0xC1,        // POR mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PXOR mm0, mm1
    {
      ArchState s;
      s.rax = 0xFF00FF00FF00FF00;
      s.rbx = 0x0F0F0F0F0F0F0F0F;
      add("pxor mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xEF, 0xC1,        // PXOR mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }
  }

  // =====================================================================
  // MMX Comparison
  // =====================================================================
  cat = "MMX compare";
  {
    // PCMPEQB mm0, mm1
    {
      ArchState s;
      s.rax = 0x0102030405060708;
      s.rbx = 0x0100030005000700;
      add("pcmpeqb mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0x74, 0xC1,        // PCMPEQB mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PCMPEQW mm0, mm1
    {
      ArchState s;
      s.rax = 0x0001000200030004;
      s.rbx = 0x0001000000030000;
      add("pcmpeqw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0x75, 0xC1,        // PCMPEQW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PCMPEQD mm0, mm1
    {
      ArchState s;
      s.rax = 0x0000000100000002;
      s.rbx = 0x0000000100000000;
      add("pcmpeqd mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0x76, 0xC1,        // PCMPEQD mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PCMPGTB mm0, mm1
    {
      ArchState s;
      s.rax = 0x0508FF7F80000102;
      s.rbx = 0x0307FE7E81010001;
      add("pcmpgtb mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0x64, 0xC1,        // PCMPGTB mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PCMPGTW mm0, mm1
    {
      ArchState s;
      s.rax = 0x0005FFFF80000001;
      s.rbx = 0x0003FFFE7FFF0001;
      add("pcmpgtw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0x65, 0xC1,        // PCMPGTW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PCMPGTD mm0, mm1
    {
      ArchState s;
      s.rax = 0x0000000580000000;
      s.rbx = 0x000000037FFFFFFF;
      add("pcmpgtd mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0x66, 0xC1,        // PCMPGTD mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }
  }

  // =====================================================================
  // MMX Shifts
  // =====================================================================
  cat = "MMX shift";
  {
    // PSLLW mm0, imm8 (shift left words by 4)
    {
      ArchState s;
      s.rax = 0x0001000200030004;
      add("psllw mm0,4", {
        0x48, 0x0F, 0x6E, 0xC0,        // MOVQ mm0, rax
        0x0F, 0x71, 0xF0, 0x04,        // PSLLW mm0, 4
        0x48, 0x0F, 0x7E, 0xC0,        // MOVQ rax, mm0
        0x0F, 0x77,
      }, s);
    }

    // PSRLW mm0, imm8 (shift right words by 4)
    {
      ArchState s;
      s.rax = 0x0010002000300040;
      add("psrlw mm0,4", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x0F, 0x71, 0xD0, 0x04,        // PSRLW mm0, 4
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PSRAW mm0, imm8 (arithmetic shift right words by 4)
    {
      ArchState s;
      s.rax = 0x8000FFF000100020;
      add("psraw mm0,4", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x0F, 0x71, 0xE0, 0x04,        // PSRAW mm0, 4
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PSLLD mm0, imm8
    {
      ArchState s;
      s.rax = 0x0000000100000002;
      add("pslld mm0,8", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x0F, 0x72, 0xF0, 0x08,        // PSLLD mm0, 8
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PSRLD mm0, imm8
    {
      ArchState s;
      s.rax = 0x0000010000000200;
      add("psrld mm0,8", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x0F, 0x72, 0xD0, 0x08,        // PSRLD mm0, 8
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PSRAD mm0, imm8
    {
      ArchState s;
      s.rax = 0x80000000FFF00000;
      add("psrad mm0,8", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x0F, 0x72, 0xE0, 0x08,        // PSRAD mm0, 8
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PSLLQ mm0, imm8
    {
      ArchState s;
      s.rax = 0x0000000000000001;
      add("psllq mm0,32", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x0F, 0x73, 0xF0, 0x20,        // PSLLQ mm0, 32
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PSRLQ mm0, imm8
    {
      ArchState s;
      s.rax = 0x8000000000000000;
      add("psrlq mm0,32", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x0F, 0x73, 0xD0, 0x20,        // PSRLQ mm0, 32
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PSLLW mm0, mm1 (variable shift)
    {
      ArchState s;
      s.rax = 0x0001000200030004;
      s.rbx = 0x0000000000000004;  // shift count from low 64 bits of mm1
      add("psllw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xF1, 0xC1,        // PSLLW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PSRLQ mm0, mm1 (variable shift)
    {
      ArchState s;
      s.rax = 0x8000000000000000;
      s.rbx = 0x0000000000000020;  // shift by 32
      add("psrlq mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xD3, 0xC1,        // PSRLQ mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }
  }

  // =====================================================================
  // MMX Pack/Unpack
  // =====================================================================
  cat = "MMX pack";
  {
    // PACKSSWB mm0, mm1
    {
      ArchState s;
      s.rax = 0x007FFFFF80000001;
      s.rbx = 0x0080FF7F00000100;
      add("packsswb mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0x63, 0xC1,        // PACKSSWB mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PACKSSDW mm0, mm1
    {
      ArchState s;
      s.rax = 0x00007FFF00000001;
      s.rbx = 0xFFFF8000FFFFFFFF;
      add("packssdw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0x6B, 0xC1,        // PACKSSDW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PACKUSWB mm0, mm1
    {
      ArchState s;
      s.rax = 0x00FF0100FFFF0000;
      s.rbx = 0x00800001007F0000;
      add("packuswb mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0x67, 0xC1,        // PACKUSWB mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PUNPCKLBW mm0, mm1
    {
      ArchState s;
      s.rax = 0x0000000011223344;
      s.rbx = 0x00000000AABBCCDD;
      add("punpcklbw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0x60, 0xC1,        // PUNPCKLBW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PUNPCKLWD mm0, mm1
    {
      ArchState s;
      s.rax = 0x0000000011112222;
      s.rbx = 0x00000000AAAABBBB;
      add("punpcklwd mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0x61, 0xC1,        // PUNPCKLWD mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PUNPCKLDQ mm0, mm1
    {
      ArchState s;
      s.rax = 0x0000000011111111;
      s.rbx = 0x00000000AAAAAAAA;
      add("punpckldq mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0x62, 0xC1,        // PUNPCKLDQ mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PUNPCKHBW mm0, mm1
    {
      ArchState s;
      s.rax = 0x1122334400000000;
      s.rbx = 0xAABBCCDD00000000;
      add("punpckhbw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0x68, 0xC1,        // PUNPCKHBW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PUNPCKHWD mm0, mm1
    {
      ArchState s;
      s.rax = 0x1111222200000000;
      s.rbx = 0xAAAABBBB00000000;
      add("punpckhwd mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0x69, 0xC1,        // PUNPCKHWD mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PUNPCKHDQ mm0, mm1
    {
      ArchState s;
      s.rax = 0x1111111100000000;
      s.rbx = 0xAAAAAAAA00000000;
      add("punpckhdq mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0x6A, 0xC1,        // PUNPCKHDQ mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }
  }

  // =====================================================================
  // MMX Min/Max
  // =====================================================================
  cat = "MMX minmax";
  {
    // PMINUB mm0, mm1
    {
      ArchState s;
      s.rax = 0xFF01FE80007F8001;
      s.rbx = 0x0101FF800180FF01;
      add("pminub mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xDA, 0xC1,        // PMINUB mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PMAXUB mm0, mm1
    {
      ArchState s;
      s.rax = 0xFF01FE80007F8001;
      s.rbx = 0x0101FF800180FF01;
      add("pmaxub mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xDE, 0xC1,        // PMAXUB mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PMINSW mm0, mm1
    {
      ArchState s;
      s.rax = 0x7FFF800000010064;
      s.rbx = 0x8000000200007FFF;
      add("pminsw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xEA, 0xC1,        // PMINSW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }

    // PMAXSW mm0, mm1
    {
      ArchState s;
      s.rax = 0x7FFF800000010064;
      s.rbx = 0x8000000200007FFF;
      add("pmaxsw mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xC0,
        0x48, 0x0F, 0x6E, 0xCB,
        0x0F, 0xEE, 0xC1,        // PMAXSW mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,
        0x0F, 0x77,
      }, s);
    }
  }

  // =====================================================================
  // MMX Move and Shuffle
  // =====================================================================
  cat = "MMX move";
  {
    // MOVD mm0, eax (32-bit, zero-extended)
    {
      ArchState s;
      s.rax = 0xDEADBEEFCAFEBABE;
      add("movd mm0,eax", {
        0x0F, 0x6E, 0xC0,              // MOVD mm0, eax (no REX.W)
        0x48, 0x0F, 0x7E, 0xC0,        // MOVQ rax, mm0
        0x0F, 0x77,
      }, s);
    }

    // MOVQ mm0, rax (64-bit with REX.W)
    {
      ArchState s;
      s.rax = 0xDEADBEEFCAFEBABE;
      add("movq mm0,rax", {
        0x48, 0x0F, 0x6E, 0xC0,        // MOVQ mm0, rax
        0x48, 0x0F, 0x7E, 0xC0,        // MOVQ rax, mm0
        0x0F, 0x77,
      }, s);
    }

    // MOVD eax, mm0 (store 32-bit)
    {
      ArchState s;
      s.rax = 0xDEADBEEFCAFEBABE;
      add("movd eax,mm0", {
        0x48, 0x0F, 0x6E, 0xC0,        // MOVQ mm0, rax
        0x31, 0xC0,                     // XOR eax, eax
        0x0F, 0x7E, 0xC0,              // MOVD eax, mm0 (no REX.W)
        0x0F, 0x77,
      }, s);
    }

    // MOVQ mm0, mm1 (via MOVQ 0F 6F)
    {
      ArchState s;
      s.rbx = 0x123456789ABCDEF0;
      add("movq mm0,mm1", {
        0x48, 0x0F, 0x6E, 0xCB,        // MOVQ mm1, rbx
        0x0F, 0x6F, 0xC1,              // MOVQ mm0, mm1
        0x48, 0x0F, 0x7E, 0xC0,        // MOVQ rax, mm0
        0x0F, 0x77,
      }, s);
    }

    // PSHUFW mm0, mm1, imm8
    {
      ArchState s;
      s.rbx = 0x0001000200030004;  // w3=1, w2=2, w1=3, w0=4
      add("pshufw mm0,mm1,0x1B", {
        0x48, 0x0F, 0x6E, 0xCB,        // MOVQ mm1, rbx
        0x0F, 0x70, 0xC1, 0x1B,        // PSHUFW mm0, mm1, 0x1B (reverse: 00 01 10 11)
        0x48, 0x0F, 0x7E, 0xC0,        // MOVQ rax, mm0
        0x0F, 0x77,
      }, s);
    }

    // PINSRW mm0, ecx, imm8
    {
      ArchState s;
      s.rax = 0x1111222233334444;
      s.rcx = 0x00000000DEADBEEF;
      add("pinsrw mm0,ecx,2", {
        0x48, 0x0F, 0x6E, 0xC0,        // MOVQ mm0, rax
        0x0F, 0xC4, 0xC1, 0x02,        // PINSRW mm0, ecx, 2
        0x48, 0x0F, 0x7E, 0xC0,        // MOVQ rax, mm0
        0x0F, 0x77,
      }, s);
    }

    // PEXTRW ecx, mm0, imm8
    {
      ArchState s;
      s.rax = 0x1111222233334444;
      add("pextrw ecx,mm0,1", {
        0x48, 0x0F, 0x6E, 0xC0,        // MOVQ mm0, rax
        0x0F, 0xC5, 0xC0, 0x01,        // PEXTRW ecx, mm0, 1
        0x0F, 0x77,
      }, s);
    }

    // PMOVMSKB ecx, mm0
    {
      ArchState s;
      s.rax = 0x80FF0180FE00FF80;
      add("pmovmskb ecx,mm0", {
        0x48, 0x0F, 0x6E, 0xC0,        // MOVQ mm0, rax
        0x0F, 0xD7, 0xC8,              // PMOVMSKB ecx, mm0
        0x0F, 0x77,
      }, s);
    }
  }

  // =====================================================================
  // MMX Memory operations
  // =====================================================================
  cat = "MMX mem";
  {
    // MOVQ mm0, [mem] (0F 6F /r with mem)
    {
      ArchState s;
      std::vector<u8> data(8);
      u64 val = 0xDEADBEEFCAFEBABE;
      memcpy(data.data(), &val, 8);
      // Load RDI with DATA_ADDR, then MOVQ mm0, [rdi]
      // MOV rdi, imm64: 48 BF <8 bytes>
      // MOVQ mm0, [rdi]: 0F 6F 07 (modrm: mod=00, reg=0, rm=7=rdi)
      tests.push_back({"movq mm0,[mem]", cat, {
        0x48, 0xBF,
        (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
        (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
        (u8)(DATA_ADDR >> 32), (u8)(DATA_ADDR >> 40),
        (u8)(DATA_ADDR >> 48), (u8)(DATA_ADDR >> 56),
        0x0F, 0x6F, 0x07,              // MOVQ mm0, [rdi]
        0x48, 0x0F, 0x7E, 0xC0,        // MOVQ rax, mm0
        0x0F, 0x77,
      }, s, FL_ALL, 0, false, data});
    }

    // MOVQ [mem], mm0 (0F 7F /r with mem)
    {
      ArchState s;
      s.rax = 0x123456789ABCDEF0;
      tests.push_back({"movq [mem],mm0", cat, {
        0x48, 0xBF,
        (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
        (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
        (u8)(DATA_ADDR >> 32), (u8)(DATA_ADDR >> 40),
        (u8)(DATA_ADDR >> 48), (u8)(DATA_ADDR >> 56),
        0x48, 0x0F, 0x6E, 0xC0,        // MOVQ mm0, rax
        0x0F, 0x7F, 0x07,              // MOVQ [rdi], mm0
        0x0F, 0x77,
      }, s, FL_ALL, 0, false, std::vector<u8>(8, 0), 8});
    }

    // MOVNTQ [mem], mm0 (0F E7 /r)
    {
      ArchState s;
      s.rax = 0xFEDCBA9876543210;
      tests.push_back({"movntq [mem],mm0", cat, {
        0x48, 0xBF,
        (u8)(DATA_ADDR), (u8)(DATA_ADDR >> 8),
        (u8)(DATA_ADDR >> 16), (u8)(DATA_ADDR >> 24),
        (u8)(DATA_ADDR >> 32), (u8)(DATA_ADDR >> 40),
        (u8)(DATA_ADDR >> 48), (u8)(DATA_ADDR >> 56),
        0x48, 0x0F, 0x6E, 0xC0,        // MOVQ mm0, rax
        0x0F, 0xE7, 0x07,              // MOVNTQ [rdi], mm0
        0x0F, 0x77,
      }, s, FL_ALL, 0, false, std::vector<u8>(8, 0), 8});
    }
  }

  // =====================================================================
  // Shift by the count in an MMX register or m64: 0F D1/D2 PSRLW/PSRLD,
  // 0F E1/E2 PSRAW/PSRAD, 0F F2/F3 PSLLD/PSLLQ.  The count is the whole
  // 64-bit source; a count of the element width or more shifts every bit
  // out (sign fill for PSRA).  The immediate forms are tested above.
  // =====================================================================
  cat = "MMX shift";
  {
    struct Shift { const char *name; u8 opcode; u64 value; };
    static const Shift shifts[] = {
      {"psrlw", 0xD1, 0x8000FFF000100020},
      {"psrld", 0xD2, 0x80000000FFF00000},
      {"psraw", 0xE1, 0x8000FFF000100020},
      {"psrad", 0xE2, 0x80000000FFF00000},
      {"pslld", 0xF2, 0x8000000100000002},
      {"psllq", 0xF3, 0x8000000100000002},
    };
    static const u64 counts[] = {0, 3, 15, 16, 17, 31, 32, 33, 63, 64, 65, 255, 65536,
                                 1ULL << 32, 1ULL << 63, ~0ULL};
    for (const Shift &sh : shifts) {
      for (u64 c : counts) {
        ArchState s;
        s.rax = sh.value;
        s.rbx = c;
        tests.push_back({std::format("{} mm0,mm1 count={:#x}", sh.name, c), cat, {
          0x48, 0x0F, 0x6E, 0xC0,        // MOVQ mm0, rax
          0x48, 0x0F, 0x6E, 0xCB,        // MOVQ mm1, rbx
          0x0F, sh.opcode, 0xC1,         // op mm0, mm1
          0x48, 0x0F, 0x7E, 0xC0,        // MOVQ rax, mm0
          0x0F, 0x77,                    // EMMS
        }, s});
      }
      // Count from memory: op mm0, [rdi]
      ArchState s;
      s.rax = sh.value;
      s.rdi = DATA_ADDR;
      std::vector<u8> data(8);
      u64 c = 5;
      memcpy(data.data(), &c, 8);
      tests.push_back({std::format("{} mm0,[rdi]", sh.name), cat, {
        0x48, 0x0F, 0x6E, 0xC0,        // MOVQ mm0, rax
        0x0F, sh.opcode, 0x07,         // op mm0, [rdi]
        0x48, 0x0F, 0x7E, 0xC0,        // MOVQ rax, mm0
        0x0F, 0x77,
      }, s, FL_ALL, 0, false, data});
    }
  }

  // =====================================================================
  // 0F F7: MASKMOVQ mm, mm — byte store to [RDI] under the mask's sign bits.
  // =====================================================================
  cat = "MMX mem";
  {
    struct Mask { const char *name; u64 mask; u64 rdi_offset; };
    static const Mask masks[] = {
      {"partial", 0x8000800080008000ULL, 0},
      {"full", 0x8080808080808080ULL, 0},
      {"none", 0x7F7F7F7F7F7F7F7FULL, 0},
      {"misaligned", 0x80FF807F80008000ULL, 3},
    };
    for (const Mask &m : masks) {
      ArchState s;
      s.rax = 0x1122334455667788;
      s.rbx = m.mask;
      s.rdi = DATA_ADDR + m.rdi_offset;
      tests.push_back({std::string("maskmovq mm0,mm1 ") + m.name, cat, {
        0x48, 0x0F, 0x6E, 0xC0,        // MOVQ mm0, rax
        0x48, 0x0F, 0x6E, 0xCB,        // MOVQ mm1, rbx
        0x0F, 0xF7, 0xC1,              // MASKMOVQ mm0, mm1
        0x0F, 0x77,
      }, s, FL_ALL, 0, false, std::vector<u8>(16, 0xCC), 16});
    }
  }

  // =====================================================================
  // SSSE3 with mm operands: NP 0F 38 00-0B, 1C-1E and NP 0F 3A 0F, the
  // "With 64-bit Operands" forms of the SDM's Operation sections
  // =====================================================================
  cat = "MMX SSSE3";
  {
    // op mm0, mm1 with mm0 from rax and mm1 from rbx; the result comes
    // back in rax.
    auto op_rr = [&](const std::string &name, std::vector<u8> op, u64 a, u64 b) {
      std::vector<u8> code = {0x48, 0x0F, 0x6E, 0xC0,   // MOVQ mm0, rax
                              0x48, 0x0F, 0x6E, 0xCB};  // MOVQ mm1, rbx
      code.insert(code.end(), op.begin(), op.end());
      code.insert(code.end(), {0x48, 0x0F, 0x7E, 0xC0,  // MOVQ rax, mm0
                               0x0F, 0x77});            // EMMS
      ArchState s;
      s.rax = a;
      s.rbx = b;
      tests.push_back({name, cat, std::move(code), s, FL_ALL, 0, false});
    };
    // op mm0, [rdi] with the source in memory
    auto op_rm = [&](const std::string &name, std::vector<u8> op, u64 a, u64 b) {
      std::vector<u8> code = {0x48, 0x0F, 0x6E, 0xC0};  // MOVQ mm0, rax
      code.insert(code.end(), op.begin(), op.end());
      code.insert(code.end(), {0x48, 0x0F, 0x7E, 0xC0, 0x0F, 0x77});
      ArchState s;
      s.rax = a;
      s.rdi = DATA_ADDR;
      std::vector<u8> data(8);
      memcpy(data.data(), &b, 8);
      tests.push_back({name, cat, std::move(code), s, FL_ALL, 0, false, data});
    };
    // Words -2, 1, 32767, -32768 and 256, 255, -32768, 32767: sums and
    // differences that saturate, products that round, bytes of both signs
    const u64 A = 0x80007FFF0001FFFEULL;
    const u64 B = 0x7FFF800000FF0100ULL;
    struct { const char *name; u8 op; } ops[] = {
      {"pshufb", 0x00}, {"phaddw", 0x01}, {"phaddd", 0x02}, {"phaddsw", 0x03},
      {"pmaddubsw", 0x04}, {"phsubw", 0x05}, {"phsubd", 0x06}, {"phsubsw", 0x07},
      {"psignb", 0x08}, {"psignw", 0x09}, {"psignd", 0x0A}, {"pmulhrsw", 0x0B},
      {"pabsb", 0x1C}, {"pabsw", 0x1D}, {"pabsd", 0x1E},
    };
    for (auto &o : ops) {
      op_rr(std::format("{} mm0,mm1", o.name), {0x0F, 0x38, o.op, 0xC1}, A, B);
      op_rr(std::format("{} mm0,mm1 (operands swapped)", o.name), {0x0F, 0x38, o.op, 0xC1}, B, A);
      op_rm(std::format("{} mm0,[rdi]", o.name), {0x0F, 0x38, o.op, 0x07}, A, B);
    }
    // PSHUFB: every index, then zeroing (bit 7) and ignored bits 6:3
    op_rr("pshufb mm0,mm1 (control 07..00)", {0x0F, 0x38, 0x00, 0xC1},
          0x1122334455667788ULL, 0x0001020304050607ULL);
    op_rr("pshufb mm0,mm1 (control with bit 7 and bits 6:3)", {0x0F, 0x38, 0x00, 0xC1},
          0x1122334455667788ULL, 0x80FF0F17E0080910ULL);
    // PSIGN: negative, zero and positive control lanes
    op_rr("psignb mm0,mm1 (mixed signs)", {0x0F, 0x38, 0x08, 0xC1}, 0x8001FF7F00801234ULL, 0xFF00017F80FF0001ULL);
    op_rr("psignw mm0,mm1 (mixed signs)", {0x0F, 0x38, 0x09, 0xC1}, 0x8000000112347FFFULL, 0xFFFF00000001FFFFULL);
    op_rr("psignd mm0,mm1 (zero control)", {0x0F, 0x38, 0x0A, 0xC1}, 0x8000000012345678ULL, 0);
    op_rr("psignd mm0,mm1 (mixed signs)", {0x0F, 0x38, 0x0A, 0xC1}, 0x8000000012345678ULL, 0xFFFFFFFF00000001ULL);
    // PMULHRSW: -32768 * -32768 rounds to 0x8000
    op_rr("pmulhrsw mm0,mm1 (0x8000 squared)", {0x0F, 0x38, 0x0B, 0xC1}, 0x8000400040007FFFULL, 0x8000C00040000001ULL);
    // PMADDUBSW: 255*127 + 255*127 fits, 255*-128 + 255*-128 saturates
    op_rr("pmaddubsw mm0,mm1 (saturating)", {0x0F, 0x38, 0x04, 0xC1}, 0xFFFFFFFF80FF017FULL, 0x80807F7F7F7F0102ULL);
    // PABS of the most negative values stays as is
    op_rr("pabsb mm0,mm1 (0x80 lanes)", {0x0F, 0x38, 0x1C, 0xC1}, 0, 0x80FF7F0180FF7F01ULL);
    op_rr("pabsw mm0,mm1 (0x8000 lanes)", {0x0F, 0x38, 0x1D, 0xC1}, 0, 0x8000FFFF7FFF0001ULL);
    op_rr("pabsd mm0,mm1 (0x80000000 lane)", {0x0F, 0x38, 0x1E, 0xC1}, 0, 0x80000000FFFFFFFFULL);
    // PALIGNR mm0, mm1, imm8: counts within the 16 concatenated bytes, at
    // the edge and beyond (a count above 16 gives 0)
    for (u8 imm : {0, 1, 3, 7, 8, 9, 15, 16, 17, 255}) {
      op_rr(std::format("palignr mm0,mm1,{}", imm), {0x0F, 0x3A, 0x0F, 0xC1, imm},
            0x1122334455667788ULL, 0x99AABBCCDDEEFF00ULL);
    }
    op_rm("palignr mm0,[rdi],5", {0x0F, 0x3A, 0x0F, 0x07, 0x05},
          0x1122334455667788ULL, 0x99AABBCCDDEEFF00ULL);
  }
}

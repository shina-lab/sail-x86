#include "kvm-avx-encoder.h"

void add_avx_vex_only_tests(std::vector<TestCase> &tests) {
  std::string cat = "AVX VEX-only";

  // =====================================================================
  // VEX-only instructions (no EVEX form)
  // =====================================================================

  // VADDSUBPS: VEX.F2.0F.WIG D0 /r
  // VADDSUBPD: VEX.66.0F.WIG D0 /r
  {
    ArchState s = {}; s.rflags = 0x2;
    float ps1[] = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f};
    float ps2[] = {10.0f, 20.0f, 30.0f, 40.0f, 50.0f, 60.0f, 70.0f, 80.0f};
    memcpy(s.xmm[1].q, ps1, 32);
    memcpy(s.xmm[2].q, ps2, 32);

    Vex v; v.mm = 1; v.pp = 3; v.W = false; v.opcode = 0xD0;
    v.reg = 0; v.vvvv = 1; v.rm = 2;
    v.L = false;
    tests.push_back({"VADDSUBPS xmm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
    v.L = true;
    tests.push_back({"VADDSUBPS ymm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});

    v.pp = 1; // 66 for PD
    double pd1[] = {1.0, 2.0, 3.0, 4.0};
    double pd2[] = {10.0, 20.0, 30.0, 40.0};
    memcpy(s.xmm[1].q, pd1, 32);
    memcpy(s.xmm[2].q, pd2, 32);
    v.L = false;
    tests.push_back({"VADDSUBPD xmm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
    v.L = true;
    tests.push_back({"VADDSUBPD ymm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
  }

  // VHADDPS: VEX.F2.0F.WIG 7C /r   VHADDPD: VEX.66.0F.WIG 7C /r
  // VHSUBPS: VEX.F2.0F.WIG 7D /r   VHSUBPD: VEX.66.0F.WIG 7D /r
  {
    ArchState s = {}; s.rflags = 0x2;
    float ps1[] = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f};
    float ps2[] = {10.0f, 20.0f, 30.0f, 40.0f, 50.0f, 60.0f, 70.0f, 80.0f};
    memcpy(s.xmm[1].q, ps1, 32);
    memcpy(s.xmm[2].q, ps2, 32);

    Vex v; v.mm = 1; v.pp = 3; v.W = false; v.reg = 0; v.vvvv = 1; v.rm = 2;

    v.opcode = 0x7C; v.L = false;
    tests.push_back({"VHADDPS xmm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
    v.L = true;
    tests.push_back({"VHADDPS ymm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
    v.opcode = 0x7D; v.L = false;
    tests.push_back({"VHSUBPS xmm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
    v.L = true;
    tests.push_back({"VHSUBPS ymm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});

    double pd1[] = {1.0, 2.0, 3.0, 4.0};
    double pd2[] = {10.0, 20.0, 30.0, 40.0};
    memcpy(s.xmm[1].q, pd1, 32);
    memcpy(s.xmm[2].q, pd2, 32);
    v.pp = 1;
    v.opcode = 0x7C; v.L = false;
    tests.push_back({"VHADDPD xmm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
    v.L = true;
    tests.push_back({"VHADDPD ymm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
    v.opcode = 0x7D; v.L = false;
    tests.push_back({"VHSUBPD xmm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
    v.L = true;
    tests.push_back({"VHSUBPD ymm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
  }

  // VBLENDPS: VEX.66.0F3A.WIG 0C /r ib
  // VBLENDPD: VEX.66.0F3A.WIG 0D /r ib
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 8; i++) ((u32 *)s.xmm[1].q)[i] = 0xAAAAAAAA;
    for (int i = 0; i < 8; i++) ((u32 *)s.xmm[2].q)[i] = 0x55555555;

    Vex v; v.mm = 3; v.pp = 1; v.W = false; v.reg = 0; v.vvvv = 1; v.rm = 2;
    v.opcode = 0x0C; v.L = false;
    tests.push_back({"VBLENDPS xmm imm=0x5", cat, v.encode_rr_imm(0x5), s, FL_NONE, 0x7, false});
    v.L = true;
    tests.push_back({"VBLENDPS ymm imm=0x55", cat, v.encode_rr_imm(0x55), s, FL_NONE, 0x7, false});
    v.opcode = 0x0D; v.L = false;
    tests.push_back({"VBLENDPD xmm imm=0x1", cat, v.encode_rr_imm(0x1), s, FL_NONE, 0x7, false});
    v.L = true;
    tests.push_back({"VBLENDPD ymm imm=0x5", cat, v.encode_rr_imm(0x5), s, FL_NONE, 0x7, false});
  }

  // VROUNDPS: VEX.66.0F3A.WIG 08 /r ib
  // VROUNDPD: VEX.66.0F3A.WIG 09 /r ib
  // VROUNDSS: VEX.66.0F3A.WIG 0A /r ib
  // VROUNDSD: VEX.66.0F3A.WIG 0B /r ib
  {
    ArchState s = {}; s.rflags = 0x2;
    float ps[] = {1.3f, 2.7f, -1.5f, 3.9f, -0.1f, 4.5f, -2.2f, 8.8f};
    memcpy(s.xmm[1].q, ps, 32);

    Vex v; v.mm = 3; v.pp = 1; v.W = false; v.reg = 0; v.vvvv = 0; v.rm = 1;
    // imm8=0: round to nearest even
    v.opcode = 0x08; v.L = false;
    tests.push_back({"VROUNDPS xmm RNE", cat, v.encode_rr_imm(0), s, FL_NONE, 0x3, false});
    v.L = true;
    tests.push_back({"VROUNDPS ymm RNE", cat, v.encode_rr_imm(0), s, FL_NONE, 0x3, false});
    // imm8=3: round toward zero (truncate)
    v.L = false;
    tests.push_back({"VROUNDPS xmm trunc", cat, v.encode_rr_imm(3), s, FL_NONE, 0x3, false});

    double pd[] = {1.3, 2.7, -1.5, 3.9};
    memcpy(s.xmm[1].q, pd, 32);
    v.opcode = 0x09; v.L = false;
    tests.push_back({"VROUNDPD xmm RNE", cat, v.encode_rr_imm(0), s, FL_NONE, 0x3, false});
    v.L = true;
    tests.push_back({"VROUNDPD ymm RNE", cat, v.encode_rr_imm(0), s, FL_NONE, 0x3, false});
  }

  // VDPPS: VEX.66.0F3A.WIG 40 /r ib
  {
    ArchState s = {}; s.rflags = 0x2;
    float ps1[] = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f};
    float ps2[] = {2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f, 9.0f};
    memcpy(s.xmm[1].q, ps1, 32);
    memcpy(s.xmm[2].q, ps2, 32);

    Vex v; v.mm = 3; v.pp = 1; v.W = false; v.opcode = 0x40;
    v.reg = 0; v.vvvv = 1; v.rm = 2;
    // imm8=0xFF: multiply all 4 elements, write result to all 4 positions
    v.L = false;
    tests.push_back({"VDPPS xmm imm=0xFF", cat, v.encode_rr_imm(0xFF), s, FL_NONE, 0x7, false});
    v.L = true;
    tests.push_back({"VDPPS ymm imm=0xFF", cat, v.encode_rr_imm(0xFF), s, FL_NONE, 0x7, false});
  }

  // VLDDQU: VEX.F2.0F.WIG F0 /r (load unaligned from memory)
  // Needs memory operand — test with [rdi]
  {
    ArchState s = {}; s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    std::vector<u8> data(32);
    for (int i = 0; i < 32; i++) data[i] = 0x10 + i;

    Vex v; v.mm = 1; v.pp = 3; v.W = false; v.opcode = 0xF0;
    v.reg = 0; v.vvvv = 0; v.rm = 0;

    v.L = false;
    {
      TestCase tc = {"VLDDQU xmm", cat, v.encode_rm_mem(), s, FL_NONE, 0x3, false};
      tc.init_data = data;
      tests.push_back(std::move(tc));
    }
    v.L = true;
    {
      TestCase tc = {"VLDDQU ymm", cat, v.encode_rm_mem(), s, FL_NONE, 0x3, false};
      tc.init_data = data;
      tests.push_back(std::move(tc));
    }
  }

  // VPERM2F128: VEX.256.66.0F3A.W0 06 /r ib
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 4; i++) s.xmm[1].q[i] = 0x1111111111111111ULL * (i + 1);
    for (int i = 0; i < 4; i++) s.xmm[2].q[i] = 0xAAAAAAAAAAAAAAAAULL + i;

    Vex v; v.mm = 3; v.pp = 1; v.W = false; v.opcode = 0x06;
    v.reg = 0; v.vvvv = 1; v.rm = 2; v.L = true;
    // imm8=0x31: low lane from src2[lane 1], high lane from src1[lane 1]
    tests.push_back({"VPERM2F128 ymm imm=0x31", cat, v.encode_rr_imm(0x31), s, FL_NONE, 0x3, false});
    // imm8=0x20: low lane from src1[lane 0], high lane from src2[lane 0]
    tests.push_back({"VPERM2F128 ymm imm=0x20", cat, v.encode_rr_imm(0x20), s, FL_NONE, 0x3, false});
  }

  // VINSERTF128: VEX.256.66.0F3A.W0 18 /r ib
  // VEXTRACTF128: VEX.256.66.0F3A.W0 19 /r ib
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 4; i++) s.xmm[1].q[i] = 0x1111111111111111ULL * (i + 1);
    s.xmm[2] = xmm_from_u64(0xAAAAAAAAAAAAAAAA, 0xBBBBBBBBBBBBBBBB);

    Vex v; v.mm = 3; v.pp = 1; v.W = false; v.L = true;
    v.reg = 0; v.vvvv = 1; v.rm = 2;
    // VINSERTF128 ymm0, ymm1, xmm2, 1 (insert xmm2 into upper lane)
    v.opcode = 0x18;
    tests.push_back({"VINSERTF128 ymm,ymm,xmm,1", cat, v.encode_rr_imm(1), s, FL_NONE, 0x3, false});
    tests.push_back({"VINSERTF128 ymm,ymm,xmm,0", cat, v.encode_rr_imm(0), s, FL_NONE, 0x3, false});

    // VEXTRACTF128 xmm0, ymm1, 1 (extract upper lane)
    v.opcode = 0x19; v.reg = 1; v.vvvv = 0; v.rm = 0;
    tests.push_back({"VEXTRACTF128 xmm,ymm,1", cat, v.encode_rr_imm(1), s, FL_NONE, 0x3, false});
    tests.push_back({"VEXTRACTF128 xmm,ymm,0", cat, v.encode_rr_imm(0), s, FL_NONE, 0x3, false});
  }

  // VZEROALL: VEX.256.0F.WIG 77
  // VZEROUPPER: VEX.128.0F.WIG 77
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 16; i++) {
      s.xmm[i] = xmm_from_u64(0xDEADDEADDEADDEAD, 0xCAFECAFECAFECAFE);
      s.xmm[i].q[2] = 0xAAAAAAAAAAAAAAAA;
      s.xmm[i].q[3] = 0xBBBBBBBBBBBBBBBB;
    }

    // VZEROALL: C5 FC 77
    tests.push_back({"VZEROALL", cat,
                     {0xC5, 0xFC, 0x77}, s, FL_NONE, 0xFFFF, false});
    // VZEROUPPER: C5 F8 77
    tests.push_back({"VZEROUPPER", cat,
                     {0xC5, 0xF8, 0x77}, s, FL_NONE, 0xFFFF, false});
  }

  // VMOVMSKPS: VEX.NP.0F.WIG 50 /r (extract sign bits → GPR)
  // VMOVMSKPD: VEX.66.0F.WIG 50 /r
  {
    ArchState s = {}; s.rflags = 0x2;
    float ps[] = {-1.0f, 2.0f, -3.0f, 4.0f, -5.0f, 6.0f, -7.0f, 8.0f};
    memcpy(s.xmm[1].q, ps, 32);

    Vex v; v.mm = 1; v.pp = 0; v.W = false; v.opcode = 0x50;
    v.reg = 0; v.vvvv = 0; v.rm = 1;
    v.L = false;
    tests.push_back({"VMOVMSKPS xmm", cat, v.encode_rr(), s, FL_NONE, 0, false});
    v.L = true;
    tests.push_back({"VMOVMSKPS ymm", cat, v.encode_rr(), s, FL_NONE, 0, false});

    double pd[] = {-1.0, 2.0, -3.0, 4.0};
    memcpy(s.xmm[1].q, pd, 32);
    v.pp = 1;
    v.L = false;
    tests.push_back({"VMOVMSKPD xmm", cat, v.encode_rr(), s, FL_NONE, 0, false});
    v.L = true;
    tests.push_back({"VMOVMSKPD ymm", cat, v.encode_rr(), s, FL_NONE, 0, false});
  }

  // VPMOVMSKB: VEX.66.0F.WIG D7 /r (byte sign bits → GPR)
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 32; i++) ((u8 *)s.xmm[1].q)[i] = (i % 3 == 0) ? 0x80 : 0x01;

    Vex v; v.mm = 1; v.pp = 1; v.W = false; v.opcode = 0xD7;
    v.reg = 0; v.vvvv = 0; v.rm = 1;
    v.L = false;
    tests.push_back({"VPMOVMSKB xmm", cat, v.encode_rr(), s, FL_NONE, 0, false});
    v.L = true;
    tests.push_back({"VPMOVMSKB ymm", cat, v.encode_rr(), s, FL_NONE, 0, false});
  }

  // VTESTPS: VEX.66.0F38.W0 0E /r    VTESTPD: VEX.66.0F38.W0 0F /r
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 8; i++) ((u32 *)s.xmm[1].q)[i] = 0x80000000;  // all negative
    for (int i = 0; i < 8; i++) ((u32 *)s.xmm[2].q)[i] = 0x80000000;

    Vex v; v.mm = 2; v.pp = 1; v.W = false; v.reg = 0; v.vvvv = 0; v.rm = 2;
    v.opcode = 0x0E; v.L = false;
    tests.push_back({"VTESTPS xmm", cat, v.encode_rr(), s, FL_CF | FL_ZF, 0, false});
    v.L = true;
    tests.push_back({"VTESTPS ymm", cat, v.encode_rr(), s, FL_CF | FL_ZF, 0, false});
    v.opcode = 0x0F; v.L = false;
    tests.push_back({"VTESTPD xmm", cat, v.encode_rr(), s, FL_CF | FL_ZF, 0, false});
    v.L = true;
    tests.push_back({"VTESTPD ymm", cat, v.encode_rr(), s, FL_CF | FL_ZF, 0, false});
  }
}

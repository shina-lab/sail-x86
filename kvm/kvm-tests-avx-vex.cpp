#include "kvm-avx-encoder.h"
#include <cpuid.h>

void add_avx_vex_only_tests(std::vector<TestCase> &tests) {
  std::string cat = "AVX VEX-only";

  std::vector<u8> adata(64, 0x42);
  auto add_vok = [&](const std::string &name, std::vector<u8> code) {
    TestCase tc; tc.name = name; tc.category = cat;
    tc.code = std::move(code);
    tc.initial = {.rdi = DATA_ADDR + 1, .rflags = 0x2};
    tc.xmm_mask = 0x1; tc.init_data = adata;
    tests.push_back(std::move(tc));
  };
  auto add_vok_flags = [&](const std::string &name, std::vector<u8> code) {
    TestCase tc; tc.name = name; tc.category = cat;
    tc.code = std::move(code);
    tc.initial = {.rdi = DATA_ADDR + 1, .rflags = 0x2};
    tc.flags_mask = FL_CF | FL_ZF; tc.init_data = adata;
    tests.push_back(std::move(tc));
  };

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
    add_vok("VADDSUBPS xmm,[rdi] misaligned", v.encode_rm_mem());
    v.L = true;
    tests.push_back({"VADDSUBPS ymm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
    add_vok("VADDSUBPS ymm,[rdi] misaligned", v.encode_rm_mem());

    v.pp = 1; // 66 for PD
    double pd1[] = {1.0, 2.0, 3.0, 4.0};
    double pd2[] = {10.0, 20.0, 30.0, 40.0};
    memcpy(s.xmm[1].q, pd1, 32);
    memcpy(s.xmm[2].q, pd2, 32);
    v.L = false;
    tests.push_back({"VADDSUBPD xmm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
    add_vok("VADDSUBPD xmm,[rdi] misaligned", v.encode_rm_mem());
    v.L = true;
    tests.push_back({"VADDSUBPD ymm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
    add_vok("VADDSUBPD ymm,[rdi] misaligned", v.encode_rm_mem());
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
    add_vok("VHADDPS xmm,[rdi] misaligned", v.encode_rm_mem());
    v.L = true;
    tests.push_back({"VHADDPS ymm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
    add_vok("VHADDPS ymm,[rdi] misaligned", v.encode_rm_mem());
    v.opcode = 0x7D; v.L = false;
    tests.push_back({"VHSUBPS xmm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
    add_vok("VHSUBPS xmm,[rdi] misaligned", v.encode_rm_mem());
    v.L = true;
    tests.push_back({"VHSUBPS ymm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
    add_vok("VHSUBPS ymm,[rdi] misaligned", v.encode_rm_mem());

    double pd1[] = {1.0, 2.0, 3.0, 4.0};
    double pd2[] = {10.0, 20.0, 30.0, 40.0};
    memcpy(s.xmm[1].q, pd1, 32);
    memcpy(s.xmm[2].q, pd2, 32);
    v.pp = 1;
    v.opcode = 0x7C; v.L = false;
    tests.push_back({"VHADDPD xmm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
    add_vok("VHADDPD xmm,[rdi] misaligned", v.encode_rm_mem());
    v.L = true;
    tests.push_back({"VHADDPD ymm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
    add_vok("VHADDPD ymm,[rdi] misaligned", v.encode_rm_mem());
    v.opcode = 0x7D; v.L = false;
    tests.push_back({"VHSUBPD xmm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
    add_vok("VHSUBPD xmm,[rdi] misaligned", v.encode_rm_mem());
    v.L = true;
    tests.push_back({"VHSUBPD ymm", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
    add_vok("VHSUBPD ymm,[rdi] misaligned", v.encode_rm_mem());
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
    { auto c = v.encode_rm_mem(); c.push_back(0x5); add_vok("VBLENDPS xmm,[rdi] misaligned", c); }
    v.L = true;
    tests.push_back({"VBLENDPS ymm imm=0x55", cat, v.encode_rr_imm(0x55), s, FL_NONE, 0x7, false});
    { auto c = v.encode_rm_mem(); c.push_back(0x55); add_vok("VBLENDPS ymm,[rdi] misaligned", c); }
    v.opcode = 0x0D; v.L = false;
    tests.push_back({"VBLENDPD xmm imm=0x1", cat, v.encode_rr_imm(0x1), s, FL_NONE, 0x7, false});
    { auto c = v.encode_rm_mem(); c.push_back(0x1); add_vok("VBLENDPD xmm,[rdi] misaligned", c); }
    v.L = true;
    tests.push_back({"VBLENDPD ymm imm=0x5", cat, v.encode_rr_imm(0x5), s, FL_NONE, 0x7, false});
    { auto c = v.encode_rm_mem(); c.push_back(0x5); add_vok("VBLENDPD ymm,[rdi] misaligned", c); }
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
    { auto c = v.encode_rm_mem(); c.push_back(0); add_vok("VROUNDPS xmm,[rdi] misaligned", c); }
    v.L = true;
    tests.push_back({"VROUNDPS ymm RNE", cat, v.encode_rr_imm(0), s, FL_NONE, 0x3, false});
    { auto c = v.encode_rm_mem(); c.push_back(0); add_vok("VROUNDPS ymm,[rdi] misaligned", c); }
    // imm8=3: round toward zero (truncate)
    v.L = false;
    tests.push_back({"VROUNDPS xmm trunc", cat, v.encode_rr_imm(3), s, FL_NONE, 0x3, false});

    double pd[] = {1.3, 2.7, -1.5, 3.9};
    memcpy(s.xmm[1].q, pd, 32);
    v.opcode = 0x09; v.L = false;
    tests.push_back({"VROUNDPD xmm RNE", cat, v.encode_rr_imm(0), s, FL_NONE, 0x3, false});
    { auto c = v.encode_rm_mem(); c.push_back(0); add_vok("VROUNDPD xmm,[rdi] misaligned", c); }
    v.L = true;
    tests.push_back({"VROUNDPD ymm RNE", cat, v.encode_rr_imm(0), s, FL_NONE, 0x3, false});
    { auto c = v.encode_rm_mem(); c.push_back(0); add_vok("VROUNDPD ymm,[rdi] misaligned", c); }
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
    { auto c = v.encode_rm_mem(); c.push_back(0xFF); add_vok("VDPPS xmm,[rdi] misaligned", c); }
    v.L = true;
    tests.push_back({"VDPPS ymm imm=0xFF", cat, v.encode_rr_imm(0xFF), s, FL_NONE, 0x7, false});
    { auto c = v.encode_rm_mem(); c.push_back(0xFF); add_vok("VDPPS ymm,[rdi] misaligned", c); }
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
    { auto c = v.encode_rm_mem(); c.push_back(0x31); add_vok("VPERM2F128 ymm,[rdi] misaligned", c); }
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
    { auto c = v.encode_rm_mem(); c.push_back(1); add_vok("VINSERTF128 ymm,[rdi] misaligned", c); }

    // VEXTRACTF128 xmm0, ymm1, 1 (extract upper lane)
    v.opcode = 0x19; v.reg = 1; v.vvvv = 0; v.rm = 0;
    tests.push_back({"VEXTRACTF128 xmm,ymm,1", cat, v.encode_rr_imm(1), s, FL_NONE, 0x3, false});
    tests.push_back({"VEXTRACTF128 xmm,ymm,0", cat, v.encode_rr_imm(0), s, FL_NONE, 0x3, false});
    // VEXTRACTF128 store to memory — no alignment
    { Vex vs; vs.mm = 3; vs.pp = 1; vs.W = false; vs.opcode = 0x19;
      vs.reg = 1; vs.vvvv = 0; vs.L = true;
      auto c = vs.encode_rm_mem(); c.push_back(1);
      add_vok("VEXTRACTF128 [rdi],ymm,1 misaligned", std::move(c)); }
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
    add_vok_flags("VTESTPS xmm,[rdi] misaligned", v.encode_rm_mem());
    v.L = true;
    tests.push_back({"VTESTPS ymm", cat, v.encode_rr(), s, FL_CF | FL_ZF, 0, false});
    add_vok_flags("VTESTPS ymm,[rdi] misaligned", v.encode_rm_mem());
    v.opcode = 0x0F; v.L = false;
    tests.push_back({"VTESTPD xmm", cat, v.encode_rr(), s, FL_CF | FL_ZF, 0, false});
    add_vok_flags("VTESTPD xmm,[rdi] misaligned", v.encode_rm_mem());
    v.L = true;
    tests.push_back({"VTESTPD ymm", cat, v.encode_rr(), s, FL_CF | FL_ZF, 0, false});
    add_vok_flags("VTESTPD ymm,[rdi] misaligned", v.encode_rm_mem());
  }

  // VDPPD: VEX.66.0F3A.WIG 41 /r ib (double dot product)
  {
    ArchState s = {}; s.rflags = 0x2;
    double pd1[] = {2.0, 3.0};
    double pd2[] = {4.0, 5.0};
    memcpy(s.xmm[1].q, pd1, 16);
    memcpy(s.xmm[2].q, pd2, 16);

    Vex v; v.mm = 3; v.pp = 1; v.W = false; v.opcode = 0x41;
    v.reg = 0; v.vvvv = 1; v.rm = 2; v.L = false;
    tests.push_back({"VDPPD xmm imm=0x31", cat, v.encode_rr_imm(0x31), s, FL_NONE, 0x3, false});
    { auto c = v.encode_rm_mem(); c.push_back(0x31); add_vok("VDPPD xmm,[rdi] misaligned", c); }
  }

  // VPBLENDD: VEX.66.0F3A.W0 02 /r ib
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 8; i++) ((u32 *)s.xmm[1].q)[i] = 0xAAAAAAAA;
    for (int i = 0; i < 8; i++) ((u32 *)s.xmm[2].q)[i] = 0x55555555;

    Vex v; v.mm = 3; v.pp = 1; v.W = false; v.opcode = 0x02;
    v.reg = 0; v.vvvv = 1; v.rm = 2;
    v.L = false;
    tests.push_back({"VPBLENDD xmm imm=0x5", cat, v.encode_rr_imm(0x5), s, FL_NONE, 0x3, false});
    { auto c = v.encode_rm_mem(); c.push_back(0x5); add_vok("VPBLENDD xmm,[rdi] misaligned", c); }
    v.L = true;
    tests.push_back({"VPBLENDD ymm imm=0x55", cat, v.encode_rr_imm(0x55), s, FL_NONE, 0x3, false});
    { auto c = v.encode_rm_mem(); c.push_back(0x55); add_vok("VPBLENDD ymm,[rdi] misaligned", c); }
  }

  // VPBLENDW: VEX.66.0F3A.WIG 0E /r ib
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((u16 *)s.xmm[1].q)[i] = 0xAAAA;
    for (int i = 0; i < 16; i++) ((u16 *)s.xmm[2].q)[i] = 0x5555;

    Vex v; v.mm = 3; v.pp = 1; v.W = false; v.opcode = 0x0E;
    v.reg = 0; v.vvvv = 1; v.rm = 2;
    v.L = false;
    tests.push_back({"VPBLENDW xmm imm=0x55", cat, v.encode_rr_imm(0x55), s, FL_NONE, 0x3, false});
    { auto c = v.encode_rm_mem(); c.push_back(0x55); add_vok("VPBLENDW xmm,[rdi] misaligned", c); }
    v.L = true;
    tests.push_back({"VPBLENDW ymm imm=0x55", cat, v.encode_rr_imm(0x55), s, FL_NONE, 0x3, false});
    { auto c = v.encode_rm_mem(); c.push_back(0x55); add_vok("VPBLENDW ymm,[rdi] misaligned", c); }
  }

  // VMOVHLPS: VEX.NP.0F.WIG 12 /r (move high to low)
  // VMOVLHPS: VEX.NP.0F.WIG 16 /r (move low to high)
  {
    ArchState s = {}; s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0xAAAAAAAAAAAAAAAA, 0xBBBBBBBBBBBBBBBB);
    s.xmm[2] = xmm_from_u64(0xCCCCCCCCCCCCCCCC, 0xDDDDDDDDDDDDDDDD);

    Vex v; v.mm = 1; v.pp = 0; v.W = false; v.reg = 0; v.vvvv = 1; v.rm = 2; v.L = false;
    v.opcode = 0x12;
    tests.push_back({"VMOVHLPS xmm", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    v.opcode = 0x16;
    tests.push_back({"VMOVLHPS xmm", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
  }

  // VPERM2I128: VEX.256.66.0F3A.W0 46 /r ib
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 4; i++) s.xmm[1].q[i] = 0x1111111111111111ULL * (i + 1);
    for (int i = 0; i < 4; i++) s.xmm[2].q[i] = 0xAAAAAAAAAAAAAAAAULL + i;

    Vex v; v.mm = 3; v.pp = 1; v.W = false; v.opcode = 0x46;
    v.reg = 0; v.vvvv = 1; v.rm = 2; v.L = true;
    tests.push_back({"VPERM2I128 ymm imm=0x31", cat, v.encode_rr_imm(0x31), s, FL_NONE, 0x3, false});
    tests.push_back({"VPERM2I128 ymm imm=0x20", cat, v.encode_rr_imm(0x20), s, FL_NONE, 0x3, false});
    { auto c = v.encode_rm_mem(); c.push_back(0x31); add_vok("VPERM2I128 ymm,[rdi] misaligned", c); }
  }

  // VINSERTPS: VEX.66.0F3A.WIG 21 /r ib
  {
    ArchState s = {}; s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0xAAAAAAAABBBBBBBB, 0xCCCCCCCCDDDDDDDD);
    s.xmm[2] = xmm_from_u64(0x1111111122222222, 0x3333333344444444);

    Vex v; v.mm = 3; v.pp = 1; v.W = false; v.opcode = 0x21;
    v.reg = 0; v.vvvv = 1; v.rm = 2; v.L = false;
    // imm8=0x10: take src2[0], insert at dst[1], no zero
    tests.push_back({"VINSERTPS xmm imm=0x10", cat, v.encode_rr_imm(0x10), s, FL_NONE, 0x3, false});
  }

  // VEXTRACTPS: VEX.66.0F3A.WIG 17 /r ib (extract f32 to GPR)
  {
    ArchState s = {}; s.rflags = 0x2;
    s.xmm[1] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);

    Vex v; v.mm = 3; v.pp = 1; v.W = false; v.opcode = 0x17;
    v.reg = 1; v.vvvv = 0; v.rm = 0; v.L = false;
    tests.push_back({"VEXTRACTPS eax,xmm1,2", cat, v.encode_rr_imm(2), s, FL_NONE, 0, false});
  }

  // VEXTRACTI128: VEX.256.66.0F3A.W0 39 /r ib
  // VINSERTI128: VEX.256.66.0F3A.W0 38 /r ib
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 4; i++) s.xmm[1].q[i] = 0x1111111111111111ULL * (i + 1);
    s.xmm[2] = xmm_from_u64(0xAAAAAAAAAAAAAAAA, 0xBBBBBBBBBBBBBBBB);

    Vex v; v.mm = 3; v.pp = 1; v.W = false; v.L = true;
    v.reg = 0; v.vvvv = 1; v.rm = 2;
    v.opcode = 0x38;
    tests.push_back({"VINSERTI128 ymm,ymm,xmm,1", cat, v.encode_rr_imm(1), s, FL_NONE, 0x3, false});
    { auto c = v.encode_rm_mem(); c.push_back(1); add_vok("VINSERTI128 ymm,[rdi] misaligned", c); }
    v.opcode = 0x39; v.reg = 1; v.vvvv = 0; v.rm = 0;
    tests.push_back({"VEXTRACTI128 xmm,ymm,1", cat, v.encode_rr_imm(1), s, FL_NONE, 0x3, false});
    // VEXTRACTI128 store to memory — no alignment
    { Vex vs; vs.mm = 3; vs.pp = 1; vs.W = false; vs.opcode = 0x39;
      vs.reg = 1; vs.vvvv = 0; vs.L = true;
      auto c = vs.encode_rm_mem(); c.push_back(1);
      add_vok("VEXTRACTI128 [rdi],ymm,1 misaligned", std::move(c)); }
  }

  // VMPSADBW: VEX.66.0F3A.WIG 42 /r ib
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 32; i++) ((u8 *)s.xmm[1].q)[i] = i;
    for (int i = 0; i < 32; i++) ((u8 *)s.xmm[2].q)[i] = 32 + i;

    Vex v; v.mm = 3; v.pp = 1; v.W = false; v.opcode = 0x42;
    v.reg = 0; v.vvvv = 1; v.rm = 2;
    v.L = false;
    tests.push_back({"VMPSADBW xmm imm=0", cat, v.encode_rr_imm(0), s, FL_NONE, 0x3, false});
    { auto c = v.encode_rm_mem(); c.push_back(0); add_vok("VMPSADBW xmm,[rdi] misaligned", c); }
    v.L = true;
    tests.push_back({"VMPSADBW ymm imm=0", cat, v.encode_rr_imm(0), s, FL_NONE, 0x3, false});
    { auto c = v.encode_rm_mem(); c.push_back(0); add_vok("VMPSADBW ymm,[rdi] misaligned", c); }
  }

  // VPTEST: VEX.66.0F38.WIG 17 /r (already tested, but let's confirm VEX encoding)
  // VEX AES-NI (VEX encoding, not EVEX)
  // VAESENC: VEX.66.0F38.WIG DC /r
  // VAESENCLAST: VEX.66.0F38.WIG DD /r
  // VAESDEC: VEX.66.0F38.WIG DE /r
  // VAESDECLAST: VEX.66.0F38.WIG DF /r
  {
    ArchState s = {}; s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0123456789ABCDEF, 0xFEDCBA9876543210);
    s.xmm[2] = xmm_from_u64(0x0F0E0D0C0B0A0908, 0x0706050403020100);

    Vex v; v.mm = 2; v.pp = 1; v.W = false; v.reg = 0; v.vvvv = 1; v.rm = 2; v.L = false;

    v.opcode = 0xDC;
    tests.push_back({"VAESENC xmm (VEX)", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VAESENC xmm,[rdi] misaligned", v.encode_rm_mem());
    v.opcode = 0xDD;
    tests.push_back({"VAESENCLAST xmm (VEX)", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VAESENCLAST xmm,[rdi] misaligned", v.encode_rm_mem());
    v.opcode = 0xDE;
    tests.push_back({"VAESDEC xmm (VEX)", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VAESDEC xmm,[rdi] misaligned", v.encode_rm_mem());
    v.opcode = 0xDF;
    tests.push_back({"VAESDECLAST xmm (VEX)", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VAESDECLAST xmm,[rdi] misaligned", v.encode_rm_mem());

    // VEX.256 needs the VAES extension (CPUID.7.0:ECX[9]); each 128-bit
    // lane is one round on its own state and round key.
    u32 eax7, ebx7, ecx7, edx7;
    __cpuid_count(7, 0, eax7, ebx7, ecx7, edx7);
    if (ecx7 & (1u << 9)) {
      s.xmm[1].q[2] = 0x8000000000000001; s.xmm[1].q[3] = 0x00FF00FF00FF00FF;
      s.xmm[2].q[2] = 0x1F1E1D1C1B1A1918; s.xmm[2].q[3] = 0x1716151413121110;
      v.L = true;
      v.opcode = 0xDC;
      tests.push_back({"VAESENC ymm (VEX)", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
      add_vok("VAESENC ymm,[rdi] misaligned", v.encode_rm_mem());
      v.opcode = 0xDD;
      tests.push_back({"VAESENCLAST ymm (VEX)", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
      v.opcode = 0xDE;
      tests.push_back({"VAESDEC ymm (VEX)", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
      v.opcode = 0xDF;
      tests.push_back({"VAESDECLAST ymm (VEX)", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
      add_vok("VAESDECLAST ymm,[rdi] misaligned", v.encode_rm_mem());
    }
  }

  // VAESIMC: VEX.66.0F38.WIG DB /r
  {
    ArchState s = {}; s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0123456789ABCDEF, 0xFEDCBA9876543210);

    Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0xDB;
    v.reg = 0; v.vvvv = 0; v.rm = 1; v.L = false;
    tests.push_back({"VAESIMC xmm (VEX)", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VAESIMC xmm,[rdi] misaligned", v.encode_rm_mem());
  }

  // VAESKEYGENASSIST: VEX.66.0F3A.WIG DF /r ib
  {
    ArchState s = {}; s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0123456789ABCDEF, 0xFEDCBA9876543210);

    Vex v; v.mm = 3; v.pp = 1; v.W = false; v.opcode = 0xDF;
    v.reg = 0; v.vvvv = 0; v.rm = 1; v.L = false;
    tests.push_back({"VAESKEYGENASSIST xmm imm=1", cat, v.encode_rr_imm(1), s, FL_NONE, 0x3, false});
    { auto c = v.encode_rm_mem(); c.push_back(1); add_vok("VAESKEYGENASSIST xmm,[rdi] misaligned", c); }
  }

  // VEX SSSE3: VPHADDD/W/SW, VPHSUBD/W/SW, VPSIGNB/D/W
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 8; i++) ((int32_t *)s.xmm[1].q)[i] = i * 100 - 300;
    for (int i = 0; i < 8; i++) ((int32_t *)s.xmm[2].q)[i] = i * 50 + 100;

    Vex v; v.mm = 2; v.pp = 1; v.W = false; v.reg = 0; v.vvvv = 1; v.rm = 2;

    // VPHADDD: VEX.66.0F38.WIG 02 /r
    v.opcode = 0x02; v.L = false;
    tests.push_back({"VPHADDD xmm", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VPHADDD xmm,[rdi] misaligned", v.encode_rm_mem());
    v.L = true;
    tests.push_back({"VPHADDD ymm", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VPHADDD ymm,[rdi] misaligned", v.encode_rm_mem());

    // VPHSUBD: VEX.66.0F38.WIG 06 /r
    v.opcode = 0x06; v.L = false;
    tests.push_back({"VPHSUBD xmm", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VPHSUBD xmm,[rdi] misaligned", v.encode_rm_mem());
    v.L = true;
    tests.push_back({"VPHSUBD ymm", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VPHSUBD ymm,[rdi] misaligned", v.encode_rm_mem());
  }
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 16; i++) ((int16_t *)s.xmm[1].q)[i] = i * 100 - 700;
    for (int i = 0; i < 16; i++) ((int16_t *)s.xmm[2].q)[i] = i * 50 + 100;

    Vex v; v.mm = 2; v.pp = 1; v.W = false; v.reg = 0; v.vvvv = 1; v.rm = 2;

    // VPHADDW: VEX.66.0F38.WIG 01 /r
    v.opcode = 0x01; v.L = false;
    tests.push_back({"VPHADDW xmm", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VPHADDW xmm,[rdi] misaligned", v.encode_rm_mem());
    v.L = true;
    tests.push_back({"VPHADDW ymm", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VPHADDW ymm,[rdi] misaligned", v.encode_rm_mem());

    // VPHADDSW: VEX.66.0F38.WIG 03 /r
    v.opcode = 0x03; v.L = false;
    tests.push_back({"VPHADDSW xmm", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VPHADDSW xmm,[rdi] misaligned", v.encode_rm_mem());

    // VPHSUBW: VEX.66.0F38.WIG 05 /r
    v.opcode = 0x05; v.L = false;
    tests.push_back({"VPHSUBW xmm", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VPHSUBW xmm,[rdi] misaligned", v.encode_rm_mem());
    v.L = true;
    tests.push_back({"VPHSUBW ymm", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VPHSUBW ymm,[rdi] misaligned", v.encode_rm_mem());

    // VPHSUBSW: VEX.66.0F38.WIG 07 /r
    v.opcode = 0x07; v.L = false;
    tests.push_back({"VPHSUBSW xmm", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VPHSUBSW xmm,[rdi] misaligned", v.encode_rm_mem());
  }
  {
    // VPSIGNB/D/W
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 32; i++) ((int8_t *)s.xmm[1].q)[i] = i - 16;
    for (int i = 0; i < 32; i++) ((int8_t *)s.xmm[2].q)[i] = (i % 3) - 1;  // -1, 0, 1 pattern

    Vex v; v.mm = 2; v.pp = 1; v.W = false; v.reg = 0; v.vvvv = 1; v.rm = 2;
    // VPSIGNB: VEX.66.0F38.WIG 08 /r
    v.opcode = 0x08; v.L = false;
    tests.push_back({"VPSIGNB xmm", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VPSIGNB xmm,[rdi] misaligned", v.encode_rm_mem());
    v.L = true;
    tests.push_back({"VPSIGNB ymm", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VPSIGNB ymm,[rdi] misaligned", v.encode_rm_mem());
    // VPSIGNW: VEX.66.0F38.WIG 09 /r
    v.opcode = 0x09; v.L = false;
    tests.push_back({"VPSIGNW xmm", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VPSIGNW xmm,[rdi] misaligned", v.encode_rm_mem());
    // VPSIGND: VEX.66.0F38.WIG 0A /r
    v.opcode = 0x0A; v.L = false;
    tests.push_back({"VPSIGND xmm", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VPSIGND xmm,[rdi] misaligned", v.encode_rm_mem());
  }

  // VPTEST: VEX.66.0F38.WIG 17 /r
  {
    ArchState s = {}; s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0xFFFFFFFF00000000, 0x00000000FFFFFFFF);
    s.xmm[2] = xmm_from_u64(0xFFFFFFFF00000000, 0x00000000FFFFFFFF);

    Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x17;
    v.reg = 0; v.vvvv = 0; v.rm = 2; // src1=xmm1 in reg field? No, VPTEST uses reg as src1, rm as src2
    // Actually VPTEST modrm: reg=src1, rm=src2. But vvvv must be 1111.
    v.reg = 1; v.rm = 2;
    v.L = false;
    tests.push_back({"VPTEST xmm", cat, v.encode_rr(), s, FL_CF | FL_ZF, 0, false});
    add_vok_flags("VPTEST xmm,[rdi] misaligned", v.encode_rm_mem());
    v.L = true;
    tests.push_back({"VPTEST ymm", cat, v.encode_rr(), s, FL_CF | FL_ZF, 0, false});
    add_vok_flags("VPTEST ymm,[rdi] misaligned", v.encode_rm_mem());
  }

  // VPHMINPOSUW: VEX.66.0F38.WIG 41 /r
  {
    ArchState s = {}; s.rflags = 0x2;
    u16 vals[] = {5, 3, 7, 1, 9, 2, 4, 6};
    memcpy(s.xmm[1].q, vals, 16);

    Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x41;
    v.reg = 0; v.vvvv = 0; v.rm = 1; v.L = false;
    tests.push_back({"VPHMINPOSUW xmm", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VPHMINPOSUW xmm,[rdi] misaligned", v.encode_rm_mem());
  }

  // VEX VRCPPS: VEX.NP.0F.WIG 53 /r
  // VEX VRSQRTPS: VEX.NP.0F.WIG 52 /r
  // VEX VRCPSS: VEX.F3.0F.WIG 53 /r
  // VEX VRSQRTSS: VEX.F3.0F.WIG 52 /r
  {
    ArchState s = {}; s.rflags = 0x2;
    float vals[] = {1.0f, 4.0f, 9.0f, 16.0f, 25.0f, 36.0f, 49.0f, 64.0f};
    memcpy(s.xmm[1].q, vals, 32);

    Vex v; v.mm = 1; v.pp = 0; v.W = false; v.reg = 0; v.vvvv = 0; v.rm = 1;

    // These are approximate — use approx comparison
    v.opcode = 0x53; v.L = false;
    {
      TestCase tc = {"VRCPPS xmm", cat, v.encode_rr(), s, FL_NONE, 0x3, false};
      tc.approx_rel_tol = 1.6e-3;  // RCPPS has ~1.5*2^-12 precision
      tc.approx_elem_bits = 32;
      tests.push_back(std::move(tc));
    }
    v.opcode = 0x52; v.L = false;
    {
      TestCase tc = {"VRSQRTPS xmm", cat, v.encode_rr(), s, FL_NONE, 0x3, false};
      tc.approx_rel_tol = 1.6e-3;
      tc.approx_elem_bits = 32;
      tests.push_back(std::move(tc));
    }

    // Scalar versions
    v.pp = 2; v.vvvv = 1;  // F3, merge upper from vvvv
    v.opcode = 0x53;
    {
      TestCase tc = {"VRCPSS xmm", cat, v.encode_rr(), s, FL_NONE, 0x3, false};
      tc.approx_rel_tol = 1.6e-3;
      tc.approx_elem_bits = 32;
      tests.push_back(std::move(tc));
    }
    v.opcode = 0x52;
    {
      TestCase tc = {"VRSQRTSS xmm", cat, v.encode_rr(), s, FL_NONE, 0x3, false};
      tc.approx_rel_tol = 1.6e-3;
      tc.approx_elem_bits = 32;
      tests.push_back(std::move(tc));
    }
  }

  // VPSHUFB VEX: VEX.66.0F38.WIG 00 /r
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 32; i++) ((u8 *)s.xmm[1].q)[i] = i + 1;
    for (int i = 0; i < 32; i++) ((u8 *)s.xmm[2].q)[i] = 15 - (i % 16);

    Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x00;
    v.reg = 0; v.vvvv = 1; v.rm = 2;
    v.L = false;
    tests.push_back({"VPSHUFB xmm (VEX)", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VPSHUFB xmm,[rdi] misaligned", v.encode_rm_mem());
    v.L = true;
    tests.push_back({"VPSHUFB ymm (VEX)", cat, v.encode_rr(), s, FL_NONE, 0x3, false});
    add_vok("VPSHUFB ymm,[rdi] misaligned", v.encode_rm_mem());
  }

  // VPSHUFHW VEX: VEX.F3.0F.WIG 70 /r ib
  // VPSHUFLW VEX: VEX.F2.0F.WIG 70 /r ib
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 32; i++) ((u16 *)s.xmm[1].q)[i] = 0x100 * (i + 1);

    Vex v; v.mm = 1; v.W = false; v.opcode = 0x70;
    v.reg = 0; v.vvvv = 0; v.rm = 1;

    // VPSHUFHW (F3)
    v.pp = 2;
    v.L = false;
    tests.push_back({"VPSHUFHW xmm (VEX)", cat, v.encode_rr_imm(0x1B), s, FL_NONE, 0x3, false});
    v.L = true;
    tests.push_back({"VPSHUFHW ymm (VEX)", cat, v.encode_rr_imm(0x1B), s, FL_NONE, 0x3, false});

    // VPSHUFLW (F2)
    v.pp = 3;
    v.L = false;
    tests.push_back({"VPSHUFLW xmm (VEX)", cat, v.encode_rr_imm(0x1B), s, FL_NONE, 0x3, false});
    v.L = true;
    tests.push_back({"VPSHUFLW ymm (VEX)", cat, v.encode_rr_imm(0x1B), s, FL_NONE, 0x3, false});

    // Memory forms
    s.rdi = DATA_ADDR;
    std::vector<u8> data(32);
    for (int i = 0; i < 32; i++) data[i] = ((u8 *)s.xmm[1].q)[i];
    v.pp = 2; v.reg = 0;
    v.L = false;
    { TestCase tc = {"VPSHUFHW xmm [rdi] (VEX)", cat, v.encode_rm_mem_imm(0x1B), s, FL_NONE, 0x3, false};
      tc.init_data = data; tests.push_back(std::move(tc)); }
    v.L = true;
    { TestCase tc = {"VPSHUFHW ymm [rdi] (VEX)", cat, v.encode_rm_mem_imm(0x1B), s, FL_NONE, 0x3, false};
      tc.init_data = data; tests.push_back(std::move(tc)); }
    v.pp = 3;
    v.L = false;
    { TestCase tc = {"VPSHUFLW xmm [rdi] (VEX)", cat, v.encode_rm_mem_imm(0x1B), s, FL_NONE, 0x3, false};
      tc.init_data = data; tests.push_back(std::move(tc)); }
    v.L = true;
    { TestCase tc = {"VPSHUFLW ymm [rdi] (VEX)", cat, v.encode_rm_mem_imm(0x1B), s, FL_NONE, 0x3, false};
      tc.init_data = data; tests.push_back(std::move(tc)); }
  }

  // AVX-VNNI: VEX.66.0F38.W0 50-53 /r (VPDPBUSD/VPDPBUSDS/VPDPWSSD/VPDPWSSDS)
  // Only run where the host has it (CPUID.(7,1):EAX[4]).  Odd accumulator
  // dwords start near saturation so the "s" forms differ from the wrapping
  // ones; byte and word lanes mix signs.
  {
    u32 eax71, ebx71, ecx71, edx71;
    __cpuid_count(7, 1, eax71, ebx71, ecx71, edx71);
    if (eax71 & (1u << 4)) {
      ArchState s = {}; s.rflags = 0x2;
      for (int i = 0; i < 8; i++) {
        ((u32 *)s.xmm[0].q)[i] = (i & 1) ? 0x7FFFFF00u : 1000u * i;
        ((u32 *)s.xmm[1].q)[i] = 0xFF7F0102u + 0x01010101u * i;
        ((u32 *)s.xmm[2].q)[i] = 0x7F80FE01u - 0x01010101u * i;
      }
      struct { const char *name; u8 opcode; } vnni[] = {
        {"VPDPBUSD", 0x50}, {"VPDPBUSDS", 0x51}, {"VPDPWSSD", 0x52}, {"VPDPWSSDS", 0x53},
      };
      for (const auto &t : vnni) {
        Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = t.opcode;
        v.reg = 0; v.vvvv = 1; v.rm = 2;
        v.L = false;
        tests.push_back({std::string(t.name) + " xmm (VEX)", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
        v.L = true;
        tests.push_back({std::string(t.name) + " ymm (VEX)", cat, v.encode_rr(), s, FL_NONE, 0x7, false});
        add_vok(std::string(t.name) + " ymm,[rdi] misaligned", v.encode_rm_mem());
      }
    }
  }

  // VPCLMULQDQ VEX: VEX.66.0F3A.WIG 44 /r ib
  {
    ArchState s = {}; s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0123456789ABCDEF, 0xFEDCBA9876543210);
    s.xmm[2] = xmm_from_u64(0x5A5A5A5A5A5A5A5A, 0xA5A5A5A5A5A5A5A5);

    Vex v; v.mm = 3; v.pp = 1; v.W = false; v.opcode = 0x44;
    v.reg = 0; v.vvvv = 1; v.rm = 2; v.L = false;
    tests.push_back({"VPCLMULQDQ xmm imm=0x00", cat, v.encode_rr_imm(0x00), s, FL_NONE, 0x3, false});
    tests.push_back({"VPCLMULQDQ xmm imm=0x11", cat, v.encode_rr_imm(0x11), s, FL_NONE, 0x3, false});
    { auto c = v.encode_rm_mem(); c.push_back(0x00); add_vok("VPCLMULQDQ xmm,[rdi] misaligned", c); }

    // VEX.256 needs the VPCLMULQDQ extension (CPUID.7.0:ECX[10]); both
    // 128-bit lanes use the same quadword selectors.
    u32 eax7, ebx7, ecx7, edx7;
    __cpuid_count(7, 0, eax7, ebx7, ecx7, edx7);
    if (ecx7 & (1u << 10)) {
      s.xmm[1].q[2] = 0x8000000000000001; s.xmm[1].q[3] = 0x0000000000000003;
      s.xmm[2].q[2] = 0x0123456789ABCDEF; s.xmm[2].q[3] = 0xFFFFFFFFFFFFFFFF;
      v.L = true;
      tests.push_back({"VPCLMULQDQ ymm imm=0x00", cat, v.encode_rr_imm(0x00), s, FL_NONE, 0x3, false});
      tests.push_back({"VPCLMULQDQ ymm imm=0x01", cat, v.encode_rr_imm(0x01), s, FL_NONE, 0x3, false});
      tests.push_back({"VPCLMULQDQ ymm imm=0x10", cat, v.encode_rr_imm(0x10), s, FL_NONE, 0x3, false});
      tests.push_back({"VPCLMULQDQ ymm imm=0x11", cat, v.encode_rr_imm(0x11), s, FL_NONE, 0x3, false});
      { auto c = v.encode_rm_mem(); c.push_back(0x00); add_vok("VPCLMULQDQ ymm,[rdi] misaligned", c); }
    }
  }

  // VMASKMOVPS load: VEX.66.0F38 2C /r
  {
    ArchState s = {}; s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    // mask in xmm1: high bit of each dword selects
    for (int i = 0; i < 4; i++) ((u32 *)s.xmm[1].q)[i] = (i % 2) ? 0x80000000 : 0;
    std::vector<u8> data(16); for (int i = 0; i < 16; i++) data[i] = 0x10 + i;
    Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x2C;
    v.reg = 0; v.vvvv = 1; v.L = false;
    tests.push_back({"VMASKMOVPS xmm (ld)", cat, v.encode_rm_mem(), s, FL_NONE, 0x1, false, data, 0});
    add_vok("VMASKMOVPS xmm,[rdi] (ld) misaligned", v.encode_rm_mem());
  }

  // VMASKMOVPD load: VEX.66.0F38 2D /r
  {
    ArchState s = {}; s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    s.xmm[1].q[0] = 0x8000000000000000ULL; s.xmm[1].q[1] = 0;
    std::vector<u8> data(16); for (int i = 0; i < 16; i++) data[i] = 0x20 + i;
    Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x2D;
    v.reg = 0; v.vvvv = 1; v.L = false;
    tests.push_back({"VMASKMOVPD xmm (ld)", cat, v.encode_rm_mem(), s, FL_NONE, 0x1, false, data, 0});
    add_vok("VMASKMOVPD xmm,[rdi] (ld) misaligned", v.encode_rm_mem());
  }

  // VMASKMOVPS store: VEX.66.0F38 2E /r
  {
    ArchState s = {}; s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    s.xmm[0] = xmm_from_u64(0x1111111122222222, 0x3333333344444444);
    for (int i = 0; i < 4; i++) ((u32 *)s.xmm[1].q)[i] = (i % 2) ? 0x80000000 : 0;
    Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x2E;
    v.reg = 0; v.vvvv = 1; v.L = false;
    tests.push_back({"VMASKMOVPS xmm (st)", cat, v.encode_rm_mem(), s, FL_NONE, 0, false, std::vector<u8>(16, 0xCC), 16});
    add_vok("VMASKMOVPS [rdi],xmm (st) misaligned", v.encode_rm_mem());
  }

  // VMASKMOVPD store: VEX.66.0F38 2F /r
  {
    ArchState s = {}; s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    s.xmm[0] = xmm_from_u64(0xAAAAAAAAAAAAAAAA, 0xBBBBBBBBBBBBBBBB);
    s.xmm[1].q[0] = 0x8000000000000000ULL; s.xmm[1].q[1] = 0;
    Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x2F;
    v.reg = 0; v.vvvv = 1; v.L = false;
    tests.push_back({"VMASKMOVPD xmm (st)", cat, v.encode_rm_mem(), s, FL_NONE, 0, false, std::vector<u8>(16, 0xCC), 16});
    add_vok("VMASKMOVPD [rdi],xmm (st) misaligned", v.encode_rm_mem());
  }

  // VPMASKMOVD load: VEX.66.0F38 8C /r
  {
    ArchState s = {}; s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    for (int i = 0; i < 4; i++) ((u32 *)s.xmm[1].q)[i] = (i % 2) ? 0x80000000 : 0;
    std::vector<u8> data(16); for (int i = 0; i < 16; i++) data[i] = 0x30 + i;
    Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x8C;
    v.reg = 0; v.vvvv = 1; v.L = false;
    tests.push_back({"VPMASKMOVD xmm (ld)", cat, v.encode_rm_mem(), s, FL_NONE, 0x1, false, data, 0});
    add_vok("VPMASKMOVD xmm,[rdi] (ld) misaligned", v.encode_rm_mem());
  }

  // VPMASKMOVD store: VEX.66.0F38 8E /r
  {
    ArchState s = {}; s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    s.xmm[0] = xmm_from_u64(0x1111111122222222, 0x3333333344444444);
    for (int i = 0; i < 4; i++) ((u32 *)s.xmm[1].q)[i] = (i % 2) ? 0x80000000 : 0;
    Vex v; v.mm = 2; v.pp = 1; v.W = false; v.opcode = 0x8E;
    v.reg = 0; v.vvvv = 1; v.L = false;
    tests.push_back({"VPMASKMOVD xmm (st)", cat, v.encode_rm_mem(), s, FL_NONE, 0, false, std::vector<u8>(16, 0xCC), 16});
    add_vok("VPMASKMOVD [rdi],xmm (st) misaligned", v.encode_rm_mem());
  }

  // VPMASKMOVQ load: VEX.66.0F38.W1 8C /r
  {
    ArchState s = {}; s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    s.xmm[1].q[0] = 0x8000000000000000ULL; s.xmm[1].q[1] = 0;
    std::vector<u8> data(16); for (int i = 0; i < 16; i++) data[i] = 0x40 + i;
    Vex v; v.mm = 2; v.pp = 1; v.W = true; v.opcode = 0x8C;
    v.reg = 0; v.vvvv = 1; v.L = false;
    tests.push_back({"VPMASKMOVQ xmm (ld)", cat, v.encode_rm_mem(), s, FL_NONE, 0x1, false, data, 0});
    add_vok("VPMASKMOVQ xmm,[rdi] (ld) misaligned", v.encode_rm_mem());
  }

  // VPMASKMOVQ store: VEX.66.0F38.W1 8E /r
  {
    ArchState s = {}; s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    s.xmm[0] = xmm_from_u64(0xAAAAAAAAAAAAAAAA, 0xBBBBBBBBBBBBBBBB);
    s.xmm[1].q[0] = 0x8000000000000000ULL; s.xmm[1].q[1] = 0;
    Vex v; v.mm = 2; v.pp = 1; v.W = true; v.opcode = 0x8E;
    v.reg = 0; v.vvvv = 1; v.L = false;
    tests.push_back({"VPMASKMOVQ xmm (st)", cat, v.encode_rm_mem(), s, FL_NONE, 0, false, std::vector<u8>(16, 0xCC), 16});
    add_vok("VPMASKMOVQ [rdi],xmm (st) misaligned", v.encode_rm_mem());
  }

  // VBLENDVPS: VEX.66.0F3A.W0 4A /r is4
  // VBLENDVPD: VEX.66.0F3A.W0 4B /r is4
  // VPBLENDVB: VEX.66.0F3A.W0 4C /r is4
  // 4-operand variable blend: imm8[7:4] = mask register index
  {
    ArchState s = {}; s.rflags = 0x2;
    for (int i = 0; i < 8; i++) ((u32 *)s.xmm[1].q)[i] = 0xAAAAAAAA;
    for (int i = 0; i < 8; i++) ((u32 *)s.xmm[2].q)[i] = 0x55555555;
    // xmm3 mask: sign bit set for even dwords
    for (int i = 0; i < 8; i++) ((u32 *)s.xmm[3].q)[i] = (i % 2 == 0) ? 0x80000000 : 0;

    Vex v; v.mm = 3; v.pp = 1; v.W = false; v.opcode = 0x4A;
    v.reg = 0; v.vvvv = 1; v.rm = 2;
    // imm8 = 0x30: mask from xmm3 (index 3 << 4)
    v.L = false;
    tests.push_back({"VBLENDVPS xmm", cat, v.encode_rr_imm(0x30), s, FL_NONE, 0x7, false});
    { auto c = v.encode_rm_mem(); c.push_back(0x30); add_vok("VBLENDVPS xmm,[rdi] misaligned", c); }
    v.L = true;
    tests.push_back({"VBLENDVPS ymm", cat, v.encode_rr_imm(0x30), s, FL_NONE, 0x7, false});
    { auto c = v.encode_rm_mem(); c.push_back(0x30); add_vok("VBLENDVPS ymm,[rdi] misaligned", c); }

    // All mask bits set
    for (int i = 0; i < 8; i++) ((u32 *)s.xmm[3].q)[i] = 0x80000000;
    v.L = false;
    tests.push_back({"VBLENDVPS xmm all-b", cat, v.encode_rr_imm(0x30), s, FL_NONE, 0x7, false});
    v.L = true;
    tests.push_back({"VBLENDVPS ymm all-b", cat, v.encode_rr_imm(0x30), s, FL_NONE, 0x7, false});

    // VBLENDVPD
    s.xmm[1].q[0] = 0x1111111111111111; s.xmm[1].q[1] = 0x2222222222222222;
    s.xmm[1].q[2] = 0x3333333333333333; s.xmm[1].q[3] = 0x4444444444444444;
    s.xmm[2].q[0] = 0xAAAAAAAAAAAAAAAA; s.xmm[2].q[1] = 0xBBBBBBBBBBBBBBBB;
    s.xmm[2].q[2] = 0xCCCCCCCCCCCCCCCC; s.xmm[2].q[3] = 0xDDDDDDDDDDDDDDDD;
    s.xmm[3].q[0] = 0x8000000000000000ULL; s.xmm[3].q[1] = 0;
    s.xmm[3].q[2] = 0x8000000000000000ULL; s.xmm[3].q[3] = 0;
    v.opcode = 0x4B;
    v.L = false;
    tests.push_back({"VBLENDVPD xmm", cat, v.encode_rr_imm(0x30), s, FL_NONE, 0x7, false});
    { auto c = v.encode_rm_mem(); c.push_back(0x30); add_vok("VBLENDVPD xmm,[rdi] misaligned", c); }
    v.L = true;
    tests.push_back({"VBLENDVPD ymm", cat, v.encode_rr_imm(0x30), s, FL_NONE, 0x7, false});
    { auto c = v.encode_rm_mem(); c.push_back(0x30); add_vok("VBLENDVPD ymm,[rdi] misaligned", c); }

    // VPBLENDVB
    for (int i = 0; i < 32; i++) ((u8 *)s.xmm[1].q)[i] = i + 1;
    for (int i = 0; i < 32; i++) ((u8 *)s.xmm[2].q)[i] = 0x80 + i;
    for (int i = 0; i < 32; i++) ((u8 *)s.xmm[3].q)[i] = (i % 2 == 0) ? 0x80 : 0x00;
    v.opcode = 0x4C;
    v.L = false;
    tests.push_back({"VPBLENDVB xmm", cat, v.encode_rr_imm(0x30), s, FL_NONE, 0x7, false});
    { auto c = v.encode_rm_mem(); c.push_back(0x30); add_vok("VPBLENDVB xmm,[rdi] misaligned", c); }
    v.L = true;
    tests.push_back({"VPBLENDVB ymm", cat, v.encode_rr_imm(0x30), s, FL_NONE, 0x7, false});
    { auto c = v.encode_rm_mem(); c.push_back(0x30); add_vok("VPBLENDVB ymm,[rdi] misaligned", c); }
  }

  // VPCMPESTRM: VEX.66.0F3A.WIG 60 /r ib  VPCMPESTRI: 61
  // VPCMPISTRM: VEX.66.0F3A.WIG 62 /r ib  VPCMPISTRI: 63
  {
    ArchState s = {}; s.rflags = 0x2;
    s.rax = 4; s.rdx = 4;
    s.xmm[1] = xmm_from_u64(0x0000000061616161, 0);  // "aaaa\0..."
    s.xmm[2] = xmm_from_u64(0x0000000062616261, 0);  // "abab\0..."

    Vex v; v.mm = 3; v.pp = 1; v.W = false; v.L = false;
    v.reg = 1; v.vvvv = 0; v.rm = 2;

    v.opcode = 0x60;
    tests.push_back({"VPCMPESTRM eq_any", cat, v.encode_rr_imm(0x00), s, FL_ALL, 0x1, false});
    tests.push_back({"VPCMPESTRM eq_each", cat, v.encode_rr_imm(0x08), s, FL_ALL, 0x1, false});

    v.opcode = 0x61;
    s.xmm[1] = xmm_from_u64(0x0000000064636261, 0);  // "abcd\0..."
    s.xmm[2] = xmm_from_u64(0x000000007A796278, 0);  // "xbyz\0..."
    tests.push_back({"VPCMPESTRI eq_any", cat, v.encode_rr_imm(0x00), s, FL_ALL, 0, false});
    tests.push_back({"VPCMPESTRI eq_each", cat, v.encode_rr_imm(0x08), s, FL_ALL, 0, false});

    // Implicit-length forms (RAX/RDX not used)
    s.xmm[1] = xmm_from_u64(0x0000000061616161, 0);
    s.xmm[2] = xmm_from_u64(0x0000000062616261, 0);
    v.opcode = 0x62;
    tests.push_back({"VPCMPISTRM eq_any", cat, v.encode_rr_imm(0x00), s, FL_ALL, 0x1, false});
    tests.push_back({"VPCMPISTRM eq_each", cat, v.encode_rr_imm(0x08), s, FL_ALL, 0x1, false});

    v.opcode = 0x63;
    s.xmm[1] = xmm_from_u64(0x0000000064636261, 0);
    s.xmm[2] = xmm_from_u64(0x000000007A796278, 0);
    tests.push_back({"VPCMPISTRI eq_any", cat, v.encode_rr_imm(0x00), s, FL_ALL, 0, false});
    tests.push_back({"VPCMPISTRI eq_ordered", cat, v.encode_rr_imm(0x0C), s, FL_ALL, 0, false});
  }
}

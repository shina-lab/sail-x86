#include "kvm-avx-encoder.h"

void add_avx_mov_tests(std::vector<TestCase> &tests) {
  std::string cat = "AVX mov";

  std::vector<u8> adata(64, 0x42);
  auto vex_ld = [](int pp, u8 op, bool L) {
    Vex v; v.mm = 1; v.pp = pp; v.W = false; v.opcode = op;
    v.reg = 0; v.vvvv = 0; v.L = L;
    return v.encode_rm_mem();
  };
  auto add_vfault = [&](const std::string &name, std::vector<u8> code) {
    TestCase tc; tc.name = name; tc.category = cat;
    tc.code = std::move(code);
    tc.initial = {.rdi = DATA_ADDR + 1};
    tc.expect_fault = true; tc.expected_vector = 13;
    tc.init_data = adata;
    tests.push_back(std::move(tc));
  };
  auto add_vok = [&](const std::string &name, std::vector<u8> code,
                         std::initializer_list<unsigned> vector_inputs = {}) {
    TestCase tc; tc.name = name; tc.category = cat;
    tc.code = std::move(code);
    tc.initial = {.rdi = DATA_ADDR + 1};
    for (unsigned reg : vector_inputs)
      tc.initial.xmm[reg] = {};
    tc.xmm_mask = 0x1; tc.init_data = adata;
    tests.push_back(std::move(tc));
  };
  auto add_vok_st = [&](const std::string &name, std::vector<u8> code) {
    ArchState init = {.rdi = DATA_ADDR + 1};
    init.xmm[0] = xmm_from_u64(0x1111111111111111, 0x2222222222222222);
    TestCase tc; tc.name = name; tc.category = cat;
    tc.code = std::move(code); tc.initial = init;
    tc.init_data = adata; tc.compare_data_len = 32;
    tests.push_back(std::move(tc));
  };
  auto add_vfault_st = [&](const std::string &name, std::vector<u8> code) {
    ArchState init = {.rdi = DATA_ADDR + 1};
    init.xmm[0] = xmm_from_u64(0x1111111111111111, 0x2222222222222222);
    TestCase tc; tc.name = name; tc.category = cat;
    tc.code = std::move(code); tc.initial = init;
    tc.expect_fault = true; tc.expected_vector = 13;
    tc.init_data = adata;
    tests.push_back(std::move(tc));
  };

  // =====================================================================
  // Packed FP moves
  // VMOVAPS: EVEX.NP.0F.W0 28 /r (load), 29 /r (store reg-reg)
  // VMOVAPD: EVEX.66.0F.W1 28 /r (load), 29 /r (store)
  // VMOVUPS: EVEX.NP.0F.W0 10 /r (load), 11 /r (store)
  // VMOVUPD: EVEX.66.0F.W1 10 /r (load), 11 /r (store)
  // =====================================================================
  {
    ArchState s = {};
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0x1111111111111111ULL * (i + 1);
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    struct { const char *name; int pp; bool W; u8 opcode; } moves[] = {
      {"VMOVAPS", 0, false, 0x28},
      {"VMOVAPD", 1, true,  0x28},
      {"VMOVUPS", 0, false, 0x10},
      {"VMOVUPD", 1, true,  0x10},
    };
    for (const auto &m : moves) {
      Evex e; e.mm = 1; e.pp = m.pp; e.W = m.W; e.opcode = m.opcode;
      e.reg = 0; e.vvvv = 0; e.rm = 1;
      add_evex_rr_tests(tests, cat, m.name, e, s, 0x2, m.W ? 0x55 : 0xAAAA);
    }

    // VEX misaligned memory tests for packed FP moves
    // VMOVAPS load: VEX.NP.0F 28 — aligned, must fault
    add_vfault("VMOVAPS xmm,[rdi] misaligned", vex_ld(0, 0x28, false));
    add_vfault("VMOVAPS ymm,[rdi] misaligned", vex_ld(0, 0x28, true));
    // VMOVAPD load: VEX.66.0F 28
    add_vfault("VMOVAPD xmm,[rdi] misaligned", vex_ld(1, 0x28, false));
    add_vfault("VMOVAPD ymm,[rdi] misaligned", vex_ld(1, 0x28, true));
    // VMOVAPS store: VEX.NP.0F 29
    add_vfault_st("VMOVAPS [rdi],xmm misaligned", vex_ld(0, 0x29, false));
    add_vfault_st("VMOVAPS [rdi],ymm misaligned", vex_ld(0, 0x29, true));
    // VMOVAPD store: VEX.66.0F 29
    add_vfault_st("VMOVAPD [rdi],xmm misaligned", vex_ld(1, 0x29, false));
    add_vfault_st("VMOVAPD [rdi],ymm misaligned", vex_ld(1, 0x29, true));
    // VMOVUPS load: VEX.NP.0F 10 — unaligned, must NOT fault
    add_vok("VMOVUPS xmm,[rdi] misaligned", vex_ld(0, 0x10, false));
    add_vok("VMOVUPS ymm,[rdi] misaligned", vex_ld(0, 0x10, true));
    // VMOVUPD load: VEX.66.0F 10
    add_vok("VMOVUPD xmm,[rdi] misaligned", vex_ld(1, 0x10, false));
    add_vok("VMOVUPD ymm,[rdi] misaligned", vex_ld(1, 0x10, true));
    // VMOVUPS store: VEX.NP.0F 11
    add_vok_st("VMOVUPS [rdi],xmm misaligned", vex_ld(0, 0x11, false));
    add_vok_st("VMOVUPS [rdi],ymm misaligned", vex_ld(0, 0x11, true));
    // VMOVUPD store: VEX.66.0F 11
    add_vok_st("VMOVUPD [rdi],xmm misaligned", vex_ld(1, 0x11, false));
    add_vok_st("VMOVUPD [rdi],ymm misaligned", vex_ld(1, 0x11, true));
    // VMOVSS load/store: VEX.F3.0F 10/11
    add_vok("VMOVSS xmm,[rdi] misaligned", vex_ld(2, 0x10, false));
    add_vok_st("VMOVSS [rdi],xmm misaligned", vex_ld(2, 0x11, false));
    // VMOVSD load/store: VEX.F2.0F 10/11
    add_vok("VMOVSD xmm,[rdi] misaligned", vex_ld(3, 0x10, false));
    add_vok_st("VMOVSD [rdi],xmm misaligned", vex_ld(3, 0x11, false));
    // VMOVNTPS store: VEX.NP.0F 2B — aligned
    add_vfault_st("VMOVNTPS [rdi],xmm misaligned", vex_ld(0, 0x2B, false));
    add_vfault_st("VMOVNTPS [rdi],ymm misaligned", vex_ld(0, 0x2B, true));
    // VMOVNTPD store: VEX.66.0F 2B
    add_vfault_st("VMOVNTPD [rdi],xmm misaligned", vex_ld(1, 0x2B, false));
    add_vfault_st("VMOVNTPD [rdi],ymm misaligned", vex_ld(1, 0x2B, true));
    // VMOVNTDQ store: VEX.66.0F E7
    add_vfault_st("VMOVNTDQ [rdi],xmm misaligned", vex_ld(1, 0xE7, false));
    add_vfault_st("VMOVNTDQ [rdi],ymm misaligned", vex_ld(1, 0xE7, true));
  }

  // =====================================================================
  // Integer moves
  // VMOVDQA32: EVEX.66.0F.W0 6F /r (load)
  // VMOVDQA64: EVEX.66.0F.W1 6F /r (load)
  // VMOVDQU8:  EVEX.F2.0F.W0 6F /r (load)
  // VMOVDQU16: EVEX.F2.0F.W1 6F /r (load)
  // VMOVDQU32: EVEX.F3.0F.W0 6F /r (load)
  // VMOVDQU64: EVEX.F3.0F.W1 6F /r (load)
  // =====================================================================
  {
    ArchState s = {};
    for (int i = 0; i < 8; i++) s.xmm[1].q[i] = 0xAAAABBBBCCCCDDDDULL + i;
    for (int i = 0; i < 8; i++) s.xmm[0].q[i] = 0xDEADDEADDEADDEAD;

    struct { const char *name; int pp; bool W; u32 kmask; } imoves[] = {
      {"VMOVDQA32", 1, false, 0xAAAA},
      {"VMOVDQA64", 1, true,  0x55},
      {"VMOVDQU8",  3, false, 0xAAAAAAAA},
      {"VMOVDQU16", 3, true,  0x55555555},
      {"VMOVDQU32", 2, false, 0xAAAA},
      {"VMOVDQU64", 2, true,  0x55},
    };
    for (const auto &m : imoves) {
      Evex e; e.mm = 1; e.pp = m.pp; e.W = m.W; e.opcode = 0x6F;
      e.reg = 0; e.vvvv = 0; e.rm = 1;
      add_evex_rr_tests(tests, cat, m.name, e, s, 0x2, m.kmask);
    }
    // VEX VMOVDQA load: VEX.66.0F 6F — aligned
    add_vfault("VMOVDQA xmm,[rdi] misaligned", vex_ld(1, 0x6F, false));
    add_vfault("VMOVDQA ymm,[rdi] misaligned", vex_ld(1, 0x6F, true));
    // VEX VMOVDQA store: VEX.66.0F 7F
    add_vfault_st("VMOVDQA [rdi],xmm misaligned", vex_ld(1, 0x7F, false));
    add_vfault_st("VMOVDQA [rdi],ymm misaligned", vex_ld(1, 0x7F, true));
    // VEX VMOVDQU load: VEX.F3.0F 6F — unaligned
    add_vok("VMOVDQU xmm,[rdi] misaligned", vex_ld(2, 0x6F, false));
    add_vok("VMOVDQU ymm,[rdi] misaligned", vex_ld(2, 0x6F, true));
    // VEX VMOVDQU store: VEX.F3.0F 7F
    add_vok_st("VMOVDQU [rdi],xmm misaligned", vex_ld(2, 0x7F, false));
    add_vok_st("VMOVDQU [rdi],ymm misaligned", vex_ld(2, 0x7F, true));
  }

  // =====================================================================
  // VMOVD: move dword between GPR and XMM
  // EVEX.66.0F.W0 6E /r (GPR→XMM), 7E /r (XMM→GPR)
  // VMOVQ: move qword
  // EVEX.66.0F.W1 6E /r (GPR→XMM), 7E /r (XMM→GPR)
  // =====================================================================
  {
    ArchState s = {};
    s.rax = 0xDEADBEEFCAFEBABE;
    s.xmm[0].q[0] = 0x1111111111111111;
    s.xmm[0].q[1] = 0x2222222222222222;

    // VMOVD xmm0, eax: reg=0(xmm0), rm=0(eax) — but modrm encodes GPR in rm
    // EVEX.66.0F.W0 6E /r: modrm=C0 (mod=11, reg=0, rm=0)
    Evex e; e.mm = 1; e.pp = 1; e.W = false; e.opcode = 0x6E;
    e.reg = 0; e.vvvv = 0; e.rm = 0;
    e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VMOVD xmm0,eax", cat, e.encode_rr(), s, FL_ALL, 0x3, false});

    // VMOVQ xmm0, rax: EVEX.66.0F.W1 6E
    e.W = true;
    tests.push_back({"VMOVQ xmm0,rax", cat, e.encode_rr(), s, FL_ALL, 0x3, false});

    // VMOVD eax, xmm1: EVEX.66.0F.W0 7E /r (reg=xmm1, rm=eax)
    s.xmm[1] = xmm_from_u64(0x12345678ABCDEF01, 0);
    e.W = false; e.opcode = 0x7E; e.reg = 1; e.rm = 0;
    tests.push_back({"VMOVD eax,xmm1", cat, e.encode_rr(), with_gpr_inputs(s, {}), FL_ALL, 0, false});

    // VMOVQ rax, xmm1
    e.W = true;
    tests.push_back({"VMOVQ rax,xmm1", cat, e.encode_rr(), with_gpr_inputs(s, {}), FL_ALL, 0, false});
    // VEX VMOVD/VMOVQ memory — no alignment required
    add_vok("VMOVD xmm,[rdi] misaligned", vex_ld(1, 0x6E, false));
    add_vok("VMOVQ xmm,[rdi] (W1) misaligned", vex_ld(1, 0x6E, false)); // W set below
    {
      Vex v; v.mm = 1; v.pp = 1; v.W = true; v.opcode = 0x6E;
      v.reg = 0; v.vvvv = 0; v.L = false;
      add_vok("VMOVQ xmm,[rdi] (66.W1) misaligned", v.encode_rm_mem());
    }
    add_vok("VMOVQ xmm,[rdi] (F3) misaligned", vex_ld(2, 0x7E, false));
    add_vok_st("VMOVD [rdi],xmm misaligned", vex_ld(1, 0x7E, false));
    {
      Vex v; v.mm = 1; v.pp = 1; v.W = true; v.opcode = 0x7E;
      v.reg = 0; v.vvvv = 0; v.L = false;
      add_vok_st("VMOVQ [rdi],xmm (66.W1) misaligned", v.encode_rm_mem());
    }
    add_vok_st("VMOVQ [rdi],xmm (D6) misaligned", vex_ld(1, 0xD6, false));
    // VEX VMOVLPS/LPD/HPS/HPD — no alignment
    {
      auto vex_vvvv = [](int pp, u8 op) {
        Vex v; v.mm = 1; v.pp = pp; v.W = false; v.opcode = op;
        v.reg = 0; v.vvvv = 1; v.L = false;
        return v.encode_rm_mem();
      };
      add_vok("VMOVLPS xmm,[rdi] misaligned", vex_vvvv(0, 0x12), {1});
      add_vok("VMOVLPD xmm,[rdi] misaligned", vex_vvvv(1, 0x12), {1});
      add_vok_st("VMOVLPS [rdi],xmm misaligned", vex_ld(0, 0x13, false));
      add_vok_st("VMOVLPD [rdi],xmm misaligned", vex_ld(1, 0x13, false));
      add_vok("VMOVHPS xmm,[rdi] misaligned", vex_vvvv(0, 0x16), {1});
      add_vok("VMOVHPD xmm,[rdi] misaligned", vex_vvvv(1, 0x16), {1});
      add_vok_st("VMOVHPS [rdi],xmm misaligned", vex_ld(0, 0x17, false));
      add_vok_st("VMOVHPD [rdi],xmm misaligned", vex_ld(1, 0x17, false));
    }
    // VEX VMOVSLDUP/VMOVDDUP/VMOVSHDUP — no alignment (VEX relaxed)
    add_vok("VMOVSLDUP xmm,[rdi] misaligned", vex_ld(2, 0x12, false));
    add_vok("VMOVSLDUP ymm,[rdi] misaligned", vex_ld(2, 0x12, true));
    add_vok("VMOVDDUP xmm,[rdi] misaligned", vex_ld(3, 0x12, false));
    add_vok("VMOVDDUP ymm,[rdi] misaligned", vex_ld(3, 0x12, true));
    add_vok("VMOVSHDUP xmm,[rdi] misaligned", vex_ld(2, 0x16, false));
    add_vok("VMOVSHDUP ymm,[rdi] misaligned", vex_ld(2, 0x16, true));
    // VEX VLDDQU: VEX.F2.0F F0 — no alignment
    add_vok("VLDDQU xmm,[rdi] misaligned", vex_ld(3, 0xF0, false));
    add_vok("VLDDQU ymm,[rdi] misaligned", vex_ld(3, 0xF0, true));
    // VEX VMOVNTDQA: VEX.66.0F38 2A — aligned
    {
      auto vex38 = [](int pp, u8 op, bool L) {
        Vex v; v.mm = 2; v.pp = pp; v.W = false; v.opcode = op;
        v.reg = 0; v.vvvv = 0; v.L = L;
        return v.encode_rm_mem();
      };
      add_vfault("VMOVNTDQA xmm,[rdi] misaligned", vex38(1, 0x2A, false));
      add_vfault("VMOVNTDQA ymm,[rdi] misaligned", vex38(1, 0x2A, true));
    }
  }

  // =====================================================================
  // VMOVW: move word between GPR/mem and XMM (AVX-512 FP16)
  // EVEX.66.MAP5.W0 6E /r (GPR→XMM)
  // EVEX.66.MAP5.W0 7E /r (XMM→GPR)
  // Note: MAP5 is mm=5, but our encoder only supports mm=1,2,3.
  // Skip for now — requires encoder extension for MAP5/MAP6.
  // =====================================================================

  // =====================================================================
  // VPEXTRB/W/D/Q: extract element to GPR
  // EVEX.66.0F3A.WIG 14 /r ib (VPEXTRB)
  // EVEX.66.0F3A.WIG 15 /r ib (VPEXTRW — actually uses 0F C5 for reg form)
  // EVEX.66.0F3A.W0 16 /r ib (VPEXTRD)
  // EVEX.66.0F3A.W1 16 /r ib (VPEXTRQ)
  // =====================================================================
  {
    ArchState s = {};
    s.xmm[1] = xmm_from_u64(0x0807060504030201, 0x100F0E0D0C0B0A09);

    // VPEXTRB eax, xmm1, 5: extract byte 5
    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x14;
    e.reg = 1; e.vvvv = 0; e.rm = 0;  // reg=src(xmm1), rm=dst(eax)
    e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VPEXTRB eax,xmm1,5", cat, e.encode_rr_imm(5), s, FL_ALL, 0, false});

    // VPEXTRD eax, xmm1, 2
    e.opcode = 0x16; e.W = false;
    tests.push_back({"VPEXTRD eax,xmm1,2", cat, e.encode_rr_imm(2), s, FL_ALL, 0, false});
    // VEX VPEXTRD store to memory — no alignment
    { Vex v; v.mm = 3; v.pp = 1; v.W = false; v.opcode = 0x16;
      v.reg = 0; v.vvvv = 0; v.L = false;
      auto c = v.encode_rm_mem(); c.push_back(0);
      add_vok_st("VPEXTRD [rdi],xmm,0 misaligned", std::move(c)); }

    // VPEXTRQ rax, xmm1, 1
    e.W = true;
    tests.push_back({"VPEXTRQ rax,xmm1,1", cat, e.encode_rr_imm(1), s, FL_ALL, 0, false});
    // VEX VPEXTRQ store to memory — no alignment
    { Vex v; v.mm = 3; v.pp = 1; v.W = true; v.opcode = 0x16;
      v.reg = 0; v.vvvv = 0; v.L = false;
      auto c = v.encode_rm_mem(); c.push_back(0);
      add_vok_st("VPEXTRQ [rdi],xmm,0 misaligned", std::move(c)); }
  }

  // =====================================================================
  // VPINSRB/W/D/Q: insert element from GPR
  // EVEX.66.0F3A.WIG 20 /r ib (VPINSRB)
  // EVEX.66.0F.WIG C4 /r ib (VPINSRW)
  // EVEX.66.0F3A.W0 22 /r ib (VPINSRD)
  // EVEX.66.0F3A.W1 22 /r ib (VPINSRQ)
  // =====================================================================
  {
    ArchState s = {};
    s.xmm[1] = xmm_from_u64(0xAAAAAAAAAAAAAAAA, 0xBBBBBBBBBBBBBBBB);
    s.rax = 0x42;

    // VPINSRD xmm0, xmm1, eax, 2: insert eax into dword position 2
    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x22;
    e.reg = 0; e.vvvv = 1; e.rm = 0;  // rm=eax(GPR)
    e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VPINSRD xmm0,xmm1,eax,2", cat, e.encode_rr_imm(2), s, FL_ALL, 0x3, false});
    // VEX VPINSRD from memory — no alignment
    { Vex v; v.mm = 3; v.pp = 1; v.W = false; v.opcode = 0x22;
      v.reg = 0; v.vvvv = 1; v.L = false;
      auto c = v.encode_rm_mem(); c.push_back(0);
      add_vok("VPINSRD xmm,[rdi],0 misaligned", std::move(c), {1}); }

    // VPINSRQ xmm0, xmm1, rax, 1
    e.W = true;
    tests.push_back({"VPINSRQ xmm0,xmm1,rax,1", cat, e.encode_rr_imm(1), s, FL_ALL, 0x3, false});
    // VEX VPINSRQ from memory — no alignment
    { Vex v; v.mm = 3; v.pp = 1; v.W = true; v.opcode = 0x22;
      v.reg = 0; v.vvvv = 1; v.L = false;
      auto c = v.encode_rm_mem(); c.push_back(0);
      add_vok("VPINSRQ xmm,[rdi],0 misaligned", std::move(c), {1}); }

    // VPINSRB xmm0, xmm1, eax, 7
    e.opcode = 0x20; e.W = false;
    tests.push_back({"VPINSRB xmm0,xmm1,eax,7", cat, e.encode_rr_imm(7), s, FL_ALL, 0x3, false});

    // VPINSRW xmm0, xmm1, eax, 3: EVEX.66.0F.WIG C4 /r ib
    Evex ew; ew.mm = 1; ew.pp = 1; ew.W = false; ew.opcode = 0xC4;
    ew.reg = 0; ew.vvvv = 1; ew.rm = 0;
    ew.LL = 0; ew.aaa = 0; ew.z = false;
    tests.push_back({"VPINSRW xmm0,xmm1,eax,3", cat, ew.encode_rr_imm(3), s, FL_ALL, 0x3, false});
  }
}

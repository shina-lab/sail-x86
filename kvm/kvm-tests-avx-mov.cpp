#include "kvm-avx-encoder.h"

void add_avx_mov_tests(std::vector<TestCase> &tests) {
  std::string cat = "AVX mov";

  // =====================================================================
  // Packed FP moves
  // VMOVAPS: EVEX.NP.0F.W0 28 /r (load), 29 /r (store reg-reg)
  // VMOVAPD: EVEX.66.0F.W1 28 /r (load), 29 /r (store)
  // VMOVUPS: EVEX.NP.0F.W0 10 /r (load), 11 /r (store)
  // VMOVUPD: EVEX.66.0F.W1 10 /r (load), 11 /r (store)
  // =====================================================================
  {
    ArchState s = {}; s.rflags = 0x2;
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
      add_evex_rr_tests(tests, cat, m.name, e, s, 0x3, m.W ? 0x55 : 0xAAAA);
    }
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
    ArchState s = {}; s.rflags = 0x2;
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
      add_evex_rr_tests(tests, cat, m.name, e, s, 0x3, m.kmask);
    }
  }

  // =====================================================================
  // VMOVD: move dword between GPR and XMM
  // EVEX.66.0F.W0 6E /r (GPR→XMM), 7E /r (XMM→GPR)
  // VMOVQ: move qword
  // EVEX.66.0F.W1 6E /r (GPR→XMM), 7E /r (XMM→GPR)
  // =====================================================================
  {
    ArchState s = {}; s.rflags = 0x2;
    s.rax = 0xDEADBEEFCAFEBABE;
    s.xmm[0].q[0] = 0x1111111111111111;
    s.xmm[0].q[1] = 0x2222222222222222;

    // VMOVD xmm0, eax: reg=0(xmm0), rm=0(eax) — but modrm encodes GPR in rm
    // EVEX.66.0F.W0 6E /r: modrm=C0 (mod=11, reg=0, rm=0)
    Evex e; e.mm = 1; e.pp = 1; e.W = false; e.opcode = 0x6E;
    e.reg = 0; e.vvvv = 0; e.rm = 0;
    e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VMOVD xmm0,eax", cat, e.encode_rr(), s, FL_NONE, 0x3, false});

    // VMOVQ xmm0, rax: EVEX.66.0F.W1 6E
    e.W = true;
    tests.push_back({"VMOVQ xmm0,rax", cat, e.encode_rr(), s, FL_NONE, 0x3, false});

    // VMOVD eax, xmm1: EVEX.66.0F.W0 7E /r (reg=xmm1, rm=eax)
    s.xmm[1] = xmm_from_u64(0x12345678ABCDEF01, 0);
    e.W = false; e.opcode = 0x7E; e.reg = 1; e.rm = 0;
    tests.push_back({"VMOVD eax,xmm1", cat, e.encode_rr(), s, FL_NONE, 0, false});

    // VMOVQ rax, xmm1
    e.W = true;
    tests.push_back({"VMOVQ rax,xmm1", cat, e.encode_rr(), s, FL_NONE, 0, false});
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
    ArchState s = {}; s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0807060504030201, 0x100F0E0D0C0B0A09);

    // VPEXTRB eax, xmm1, 5: extract byte 5
    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x14;
    e.reg = 1; e.vvvv = 0; e.rm = 0;  // reg=src(xmm1), rm=dst(eax)
    e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VPEXTRB eax,xmm1,5", cat, e.encode_rr_imm(5), s, FL_NONE, 0, false});

    // VPEXTRD eax, xmm1, 2
    e.opcode = 0x16; e.W = false;
    tests.push_back({"VPEXTRD eax,xmm1,2", cat, e.encode_rr_imm(2), s, FL_NONE, 0, false});

    // VPEXTRQ rax, xmm1, 1
    e.W = true;
    tests.push_back({"VPEXTRQ rax,xmm1,1", cat, e.encode_rr_imm(1), s, FL_NONE, 0, false});
  }

  // =====================================================================
  // VPINSRB/W/D/Q: insert element from GPR
  // EVEX.66.0F3A.WIG 20 /r ib (VPINSRB)
  // EVEX.66.0F.WIG C4 /r ib (VPINSRW)
  // EVEX.66.0F3A.W0 22 /r ib (VPINSRD)
  // EVEX.66.0F3A.W1 22 /r ib (VPINSRQ)
  // =====================================================================
  {
    ArchState s = {}; s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0xAAAAAAAAAAAAAAAA, 0xBBBBBBBBBBBBBBBB);
    s.rax = 0x42;

    // VPINSRD xmm0, xmm1, eax, 2: insert eax into dword position 2
    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x22;
    e.reg = 0; e.vvvv = 1; e.rm = 0;  // rm=eax(GPR)
    e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VPINSRD xmm0,xmm1,eax,2", cat, e.encode_rr_imm(2), s, FL_NONE, 0x3, false});

    // VPINSRQ xmm0, xmm1, rax, 1
    e.W = true;
    tests.push_back({"VPINSRQ xmm0,xmm1,rax,1", cat, e.encode_rr_imm(1), s, FL_NONE, 0x3, false});

    // VPINSRB xmm0, xmm1, eax, 7
    e.opcode = 0x20; e.W = false;
    tests.push_back({"VPINSRB xmm0,xmm1,eax,7", cat, e.encode_rr_imm(7), s, FL_NONE, 0x3, false});

    // VPINSRW xmm0, xmm1, eax, 3: EVEX.66.0F.WIG C4 /r ib
    Evex ew; ew.mm = 1; ew.pp = 1; ew.W = false; ew.opcode = 0xC4;
    ew.reg = 0; ew.vvvv = 1; ew.rm = 0;
    ew.LL = 0; ew.aaa = 0; ew.z = false;
    tests.push_back({"VPINSRW xmm0,xmm1,eax,3", cat, ew.encode_rr_imm(3), s, FL_NONE, 0x3, false});
  }
}

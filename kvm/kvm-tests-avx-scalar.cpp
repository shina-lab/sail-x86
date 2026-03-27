#include "kvm-avx-encoder.h"

void add_avx_scalar_tests(std::vector<TestCase> &tests) {
  std::string cat = "AVX scalar";

  // Scalar FP instructions operate on the lowest element only.
  // Upper elements of dst are copied from src1 (vvvv).
  // VL is LIG (length-ignored), we test at VL=128.
  // Writemask: bit 0 only.

  // Helper: scalar test with no mask + zeroing mask + merging mask
  auto add_scalar = [&](const char *name, Evex e, ArchState s) {
    e.LL = 0;
    // No mask
    e.aaa = 0; e.z = false;
    tests.push_back({std::string(name) + " xmm", cat, e.encode_rr(), s, FL_NONE, 0x7, false});
    // Zeroing mask (k1, bit 0 = 1)
    e.aaa = 1; e.z = true;
    tests.push_back({std::string(name) + " xmm {k1}{z} mask=1", cat,
                     concat(set_kmask(1), e.encode_rr()), s, FL_NONE, 0x7, false});
    // Zeroing mask (k1, bit 0 = 0 — element zeroed)
    e.aaa = 1; e.z = true;
    tests.push_back({std::string(name) + " xmm {k1}{z} mask=0", cat,
                     concat(set_kmask(0), e.encode_rr()), s, FL_NONE, 0x7, false});
    // Merging mask (k1, bit 0 = 0 — element preserved from dst)
    e.aaa = 1; e.z = false;
    tests.push_back({std::string(name) + " xmm {k1} mask=0", cat,
                     concat(set_kmask(0), e.encode_rr()), s, FL_NONE, 0x7, false});
  };

  // Helper: scalar compare (sets RFLAGS, no vector result)
  auto add_scalar_cmp = [&](const char *name, Evex e, ArchState s) {
    e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({std::string(name) + " xmm", cat, e.encode_rr(), s, FL_CF | FL_ZF | FL_PF, 0, false});
  };

  // --- Setup states with sentinels in upper lanes ---
  auto make_ss_state = [](float a, float b) {
    ArchState s;
    s.rflags = 0x2;
    // dst (xmm0): sentinel in upper, scalar in low
    float dst_val = 99.0f;
    memcpy(&s.xmm[0].q[0], &dst_val, 4);
    s.xmm[0].q[0] |= 0xDEADBEEF00000000ULL;
    s.xmm[0].q[1] = 0xDEADDEAD11111111;
    // src1 (xmm1/vvvv): upper lanes preserved in dst
    memcpy(&s.xmm[1].q[0], &a, 4);
    s.xmm[1].q[0] |= 0xAAAAAAAA00000000ULL;
    s.xmm[1].q[1] = 0xBBBBBBBBCCCCCCCC;
    // src2 (xmm2/rm)
    memcpy(&s.xmm[2].q[0], &b, 4);
    return s;
  };

  auto make_sd_state = [](double a, double b) {
    ArchState s;
    s.rflags = 0x2;
    double dst_val = 99.0;
    memcpy(&s.xmm[0].q[0], &dst_val, 8);
    s.xmm[0].q[1] = 0xDEADDEAD11111111;
    memcpy(&s.xmm[1].q[0], &a, 8);
    s.xmm[1].q[1] = 0xBBBBBBBBCCCCCCCC;
    memcpy(&s.xmm[2].q[0], &b, 8);
    return s;
  };

  // ---- Scalar SS (f32): EVEX.LIG.NP.0F.W0 ----
  // VADDSS: F3 0F 58   VSUBSS: F3 0F 5C   VMULSS: F3 0F 59   VDIVSS: F3 0F 5E
  // VMINSS: F3 0F 5D   VMAXSS: F3 0F 5F   VSQRTSS: F3 0F 51
  {
    ArchState s = make_ss_state(3.0f, 7.0f);
    Evex e; e.mm = 1; e.pp = 2; e.W = false; e.reg = 0; e.vvvv = 1; e.rm = 2;

    e.opcode = 0x58; add_scalar("VADDSS", e, s);
    e.opcode = 0x5C; add_scalar("VSUBSS", e, s);
    e.opcode = 0x59; add_scalar("VMULSS", e, s);
    e.opcode = 0x5E; add_scalar("VDIVSS", e, s);
    e.opcode = 0x5D; add_scalar("VMINSS", e, s);
    e.opcode = 0x5F; add_scalar("VMAXSS", e, s);
  }
  // VSQRTSS (unary-ish: dst = src1[127:32] : sqrt(src2[31:0]))
  {
    ArchState s = make_ss_state(0.0f, 25.0f);
    Evex e; e.mm = 1; e.pp = 2; e.W = false; e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.opcode = 0x51; add_scalar("VSQRTSS", e, s);
  }

  // ---- Scalar SD (f64): EVEX.LIG.F2.0F.W1 ----
  // VADDSD: F2 0F 58   VSUBSD: F2 0F 5C   VMULSD: F2 0F 59   VDIVSD: F2 0F 5E
  // VMINSD: F2 0F 5D   VMAXSD: F2 0F 5F   VSQRTSD: F2 0F 51
  {
    ArchState s = make_sd_state(3.0, 7.0);
    Evex e; e.mm = 1; e.pp = 3; e.W = true; e.reg = 0; e.vvvv = 1; e.rm = 2;

    e.opcode = 0x58; add_scalar("VADDSD", e, s);
    e.opcode = 0x5C; add_scalar("VSUBSD", e, s);
    e.opcode = 0x59; add_scalar("VMULSD", e, s);
    e.opcode = 0x5E; add_scalar("VDIVSD", e, s);
    e.opcode = 0x5D; add_scalar("VMINSD", e, s);
    e.opcode = 0x5F; add_scalar("VMAXSD", e, s);
  }
  {
    ArchState s = make_sd_state(0.0, 25.0);
    Evex e; e.mm = 1; e.pp = 3; e.W = true; e.reg = 0; e.vvvv = 1; e.rm = 2;
    e.opcode = 0x51; add_scalar("VSQRTSD", e, s);
  }

  // ---- Scalar compare: VCOMISS/VCOMISD/VUCOMISS/VUCOMISD ----
  // VCOMISS:  NP 0F 2F, W0    VCOMISD:  66 0F 2F, W1
  // VUCOMISS: NP 0F 2E, W0    VUCOMISD: 66 0F 2E, W1
  {
    // Test: a < b, a == b, a > b
    float vals_a[] = {1.0f, 5.0f, 10.0f};
    float vals_b[] = {5.0f, 5.0f, 1.0f};
    for (int i = 0; i < 3; i++) {
      ArchState s;
      s.rflags = 0x2;
      memcpy(&s.xmm[0].q[0], &vals_a[i], 4);
      memcpy(&s.xmm[1].q[0], &vals_b[i], 4);
      const char *rel[] = {"lt", "eq", "gt"};
      Evex e; e.mm = 1; e.pp = 0; e.W = false; e.reg = 0; e.vvvv = 0; e.rm = 1;
      e.opcode = 0x2F;
      add_scalar_cmp((std::string("VCOMISS ") + rel[i]).c_str(), e, s);
      e.opcode = 0x2E;
      add_scalar_cmp((std::string("VUCOMISS ") + rel[i]).c_str(), e, s);
    }
  }
  {
    double vals_a[] = {1.0, 5.0, 10.0};
    double vals_b[] = {5.0, 5.0, 1.0};
    for (int i = 0; i < 3; i++) {
      ArchState s;
      s.rflags = 0x2;
      memcpy(&s.xmm[0].q[0], &vals_a[i], 8);
      memcpy(&s.xmm[1].q[0], &vals_b[i], 8);
      const char *rel[] = {"lt", "eq", "gt"};
      Evex e; e.mm = 1; e.pp = 1; e.W = true; e.reg = 0; e.vvvv = 0; e.rm = 1;
      e.opcode = 0x2F;
      add_scalar_cmp((std::string("VCOMISD ") + rel[i]).c_str(), e, s);
      e.opcode = 0x2E;
      add_scalar_cmp((std::string("VUCOMISD ") + rel[i]).c_str(), e, s);
    }
  }

  // ---- VMOVSS / VMOVSD (reg-reg form: merge low element) ----
  // VMOVSS reg,reg,reg: EVEX.LIG.F3.0F.W0 10 /r
  // VMOVSD reg,reg,reg: EVEX.LIG.F2.0F.W1 10 /r
  {
    ArchState s;
    s.rflags = 0x2;
    s.xmm[0].q[0] = 0xDEADDEADDEADDEAD;
    s.xmm[0].q[1] = 0x1111111111111111;
    s.xmm[1].q[0] = 0xAAAAAAAAAAAAAAAA;
    s.xmm[1].q[1] = 0xBBBBBBBBBBBBBBBB;
    s.xmm[2].q[0] = 0xCCCCCCCCCCCCCCCC;
    s.xmm[2].q[1] = 0xDDDDDDDDDDDDDDDD;

    Evex e; e.mm = 1; e.reg = 0; e.vvvv = 1; e.rm = 2;
    // VMOVSS
    e.pp = 2; e.W = false; e.opcode = 0x10;
    add_scalar("VMOVSS", e, s);
    // VMOVSD
    e.pp = 3; e.W = true; e.opcode = 0x10;
    add_scalar("VMOVSD", e, s);
  }

  // ---- Scalar immediate-operand instructions ----

  // VRNDSCALESS: EVEX.66.0F3A.W0 0A /r ib
  // VRNDSCALESD: EVEX.66.0F3A.W1 0B /r ib
  {
    ArchState ss = make_ss_state(3.7f, 0.0f);  // value to round
    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x0A;
    e.reg = 0; e.vvvv = 1; e.rm = 2; e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VRNDSCALESS xmm", cat, e.encode_rr_imm(0), ss, FL_NONE, 0x7, false});
  }
  {
    ArchState sd = make_sd_state(3.7, 0.0);
    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.opcode = 0x0B;
    e.reg = 0; e.vvvv = 1; e.rm = 2; e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VRNDSCALESD xmm", cat, e.encode_rr_imm(0), sd, FL_NONE, 0x7, false});
  }

  // VGETEXPSS: EVEX.66.0F38.W0 43 /r
  // VGETEXPSD: EVEX.66.0F38.W1 43 /r
  {
    ArchState ss = make_ss_state(0.0f, 8.0f);  // getexp(8.0) = 3.0
    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x43;
    e.reg = 0; e.vvvv = 1; e.rm = 2; e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VGETEXPSS xmm", cat, e.encode_rr(), ss, FL_NONE, 0x7, false});
  }
  {
    ArchState sd = make_sd_state(0.0, 8.0);
    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x43;
    e.reg = 0; e.vvvv = 1; e.rm = 2; e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VGETEXPSD xmm", cat, e.encode_rr(), sd, FL_NONE, 0x7, false});
  }

  // VSCALEFSS: EVEX.66.0F38.W0 2D /r
  // VSCALEFSD: EVEX.66.0F38.W1 2D /r
  {
    ArchState ss = make_ss_state(2.0f, 3.0f);  // scalef(2.0, 3.0) = 2.0 * 2^3 = 16.0
    Evex e; e.mm = 2; e.pp = 1; e.W = false; e.opcode = 0x2D;
    e.reg = 0; e.vvvv = 1; e.rm = 2; e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VSCALEFSS xmm", cat, e.encode_rr(), ss, FL_NONE, 0x7, false});
  }
  {
    ArchState sd = make_sd_state(2.0, 3.0);
    Evex e; e.mm = 2; e.pp = 1; e.W = true; e.opcode = 0x2D;
    e.reg = 0; e.vvvv = 1; e.rm = 2; e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VSCALEFSD xmm", cat, e.encode_rr(), sd, FL_NONE, 0x7, false});
  }

  // VGETMANTSS: EVEX.66.0F3A.W0 27 /r ib
  // VGETMANTSD: EVEX.66.0F3A.W1 27 /r ib
  {
    ArchState ss = make_ss_state(0.0f, 8.0f);
    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x27;
    e.reg = 0; e.vvvv = 1; e.rm = 2; e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VGETMANTSS xmm", cat, e.encode_rr_imm(0), ss, FL_NONE, 0x7, false});
  }
  {
    ArchState sd = make_sd_state(0.0, 8.0);
    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.opcode = 0x27;
    e.reg = 0; e.vvvv = 1; e.rm = 2; e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VGETMANTSD xmm", cat, e.encode_rr_imm(0), sd, FL_NONE, 0x7, false});
  }

  // VREDUCESS: EVEX.66.0F3A.W0 57 /r ib
  // VREDUCESD: EVEX.66.0F3A.W1 57 /r ib
  {
    ArchState ss = make_ss_state(0.0f, 3.14f);
    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x57;
    e.reg = 0; e.vvvv = 1; e.rm = 2; e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VREDUCESS xmm", cat, e.encode_rr_imm(0x08), ss, FL_NONE, 0x7, false});
  }
  {
    ArchState sd = make_sd_state(0.0, 3.14);
    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.opcode = 0x57;
    e.reg = 0; e.vvvv = 1; e.rm = 2; e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VREDUCESD xmm", cat, e.encode_rr_imm(0x08), sd, FL_NONE, 0x7, false});
  }

  // VRANGESS: EVEX.66.0F3A.W0 51 /r ib
  // VRANGESD: EVEX.66.0F3A.W1 51 /r ib
  {
    ArchState ss = make_ss_state(3.0f, 5.0f);
    Evex e; e.mm = 3; e.pp = 1; e.W = false; e.opcode = 0x51;
    e.reg = 0; e.vvvv = 1; e.rm = 2; e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VRANGESS xmm", cat, e.encode_rr_imm(0), ss, FL_NONE, 0x7, false});
  }
  {
    ArchState sd = make_sd_state(3.0, 5.0);
    Evex e; e.mm = 3; e.pp = 1; e.W = true; e.opcode = 0x51;
    e.reg = 0; e.vvvv = 1; e.rm = 2; e.LL = 0; e.aaa = 0; e.z = false;
    tests.push_back({"VRANGESD xmm", cat, e.encode_rr_imm(0), sd, FL_NONE, 0x7, false});
  }
}

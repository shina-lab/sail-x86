#include "kvm-avx-encoder.h"
#include <cpuid.h>

// VEX and EVEX outside 64-bit mode, in compatibility mode (CS.L = 0, CS.D =
// 1).  Only eight registers of each kind exist there, and the prefixes'
// extension bits and W are reinterpreted (SDM Vol.2A §2.3.5 for VEX, §2.7.11
// Tables 2-40 to 2-42 for EVEX):
//   - C4h/C5h are VEX only if the next byte's bits 7:6 are 11b, and 62h EVEX
//     only if they are 11b, otherwise LES/LDS/BOUND: VEX.R̄X̄ and EVEX.R̄X̄
//     are always 1.
//   - VEX.B̄, EVEX.B̄ and EVEX.R'̄, and the top bit of a VEX.vvvv or an
//     EVEX.vvvv that names a register, are ignored.  EVEX.V'̄ must be 1,
//     and an EVEX.vvvv that names nothing 1111b.
//   - VEX.W1 and EVEX.W1 of the instructions where W is REX.W for a
//     general-purpose operand are ignored: BMI1/BMI2, VMOVQ, VPEXTRQ,
//     VPINSRQ, VCVTSI2SS/SD and the other conversions to and from a GPR.
//   - VSIB addresses are 32 bits, and 16 bits (67h) are #UD (§2.3.12).
// The registers and memory hold distinct values in their upper halves and
// at the register numbers 8 above the encoded ones, so that reading either
// shows.
//
// Each case expects what the manuals give for it, on every host: that it
// completes, or #UD.  Where they leave the outcome open, a case accepts
// either (EITHER):
//   - the SDM contradicts itself: VPINSRQ is "#UD" in non-64-bit mode on
//     its page, but "VEX.W/EVEX.W in non-64 bit is ignored" in its table
//     notes;
//   - the APM does not define the encoding: VEX.W1 where its rows outside
//     64-bit mode have W0 (VCVTSI2SS) or disagree (VMOVD, whose store row
//     there has W1 and the opcode of the load, 6E), KMOVQ with a GPR,
//     whose rows are "only available in 64-bit mode", and EVEX.W1 of
//     VPINSRD, whose row there is W0: "Undefined cases of a value of
//     VEX.W" (and EVEX.W) "may cause a #UD" (Vol.4 §3.2.4, §3.2.5);
//   - the top bit of a VEX.vvvv that names a register, which the SDM
//     ignores (§2.3.5.6) and of which the APM says "Values 0000h to 0111h
//     are not valid in 32-bit modes" (Vol.3 Table 1-21).
// Where the SDM defines an outcome and the APM has no rule (EVEX.V'̄ and
// P[14] where EVEX.vvvv names a register), the case expects the SDM's.
// The hosts' known differences are in kvm-deviations.cpp.
void add_compat_avx_tests(std::vector<TestCase> &tests) {
  std::string cat;
  enum Outcome { DONE, UD, EITHER };
  auto add = [&](const std::string &name, std::vector<u8> code, const ArchState &init,
                 u64 flags = FL_ALL, std::vector<u8> data = {}, Outcome outcome = DONE) {
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = std::move(code);
    tc.initial = init;
    tc.flags_mask = flags;
    tc.init_data = std::move(data);
    tc.compat_mode = true;
    if (outcome == UD) {
      tc.expect_fault = true;
      tc.expected_vector = 6;
    } else if (outcome == EITHER) {
      tc.allowed_outcomes = {6, -1};
    }
    tests.push_back(std::move(tc));
  };

  // GPR operands with nonzero upper halves.  EDX is BEXTR's control (start
  // 4, length 40) and MULX's implicit source; ESI is BZHI's index and the
  // SARX/SHLX/SHRX count (40): each means something else in 32 bits than in
  // 64.  EDI points at the data page.
  ArchState g;
  g.rax = 0x13579BDF2468ACE0;
  g.rbx = 0x0123ABCD80000001;
  g.rcx = 0xFEDC00008421F00F;
  g.rdx = 0x0000000300002804;
  g.rsi = 0xFFFF000000000028;
  g.rdi = 0x5A5A5A5A00000000 | DATA_ADDR;
  g.rbp = 0x2222222233333333;
  g.rflags = initial_flags();
  // Distinct vector registers: xmm0-xmm15 (and their upper halves).
  for (int i = 0; i < 32; i++)
    for (int j = 0; j < 8; j++)
      g.xmm[i].q[j] = 0x0101010101010101ULL * (i + 1) ^ 0x1000200030004000ULL * (j + 1);
  // Data: 64-bit words whose halves differ.  An FP source in memory reads
  // 3e9 from every double (fpd) or float (fps) instead, which converts to
  // an integer without a special value whatever the operand size.
  std::vector<u8> data(64), fpd(64), fps(64);
  for (int i = 0; i < 8; i++) {
    u64 w = 0x89ABCDEF76543210ULL + 0x0102030405060708ULL * i;
    memcpy(&data[i * 8], &w, 8);
    double x = 3e9;
    memcpy(&fpd[i * 8], &x, 8);
  }
  for (int i = 0; i < 16; i++) {
    float x = 3e9f;
    memcpy(&fps[i * 4], &x, 4);
  }

  // =====================================================================
  // VEX
  // =====================================================================
  cat = "Compat VEX";
  {
    // BMI1/BMI2 (VEX-encoded GPR instructions, SDM Vol.2A §2.6): "VEX.W1 is
    // ignored in non-64-bit modes" on each page.  reg/vvvv/rm are register
    // numbers: ModR/M.reg (or the /digit), VEX.vvvv and ModR/M.r/m.
    const u64 FL_BMI = FL_ALL & ~(FL_AF | FL_PF);
    const u64 FL_BEXTR = FL_ZF | FL_OF | FL_CF | FL_DF;
    struct Bmi { const char *name; int mm, pp; u8 op; int reg, vvvv, rm, imm; u64 flags; };
    static const Bmi bmis[] = {
      {"andn eax,ebx,ecx", 2, 0, 0xF2, 0, 3, 1, -1, FL_BMI},
      {"blsr ebx,ecx", 2, 0, 0xF3, 1, 3, 1, -1, FL_BMI},
      {"blsmsk ebx,ecx", 2, 0, 0xF3, 2, 3, 1, -1, FL_BMI},
      {"blsi ebx,ecx", 2, 0, 0xF3, 3, 3, 1, -1, FL_BMI},
      {"bextr eax,ecx,edx", 2, 0, 0xF7, 0, 2, 1, -1, FL_BEXTR},
      {"bzhi eax,ecx,esi", 2, 0, 0xF5, 0, 6, 1, -1, FL_BMI},
      {"pdep eax,ebx,ecx", 2, 3, 0xF5, 0, 3, 1, -1, FL_ALL},
      {"pext eax,ebx,ecx", 2, 2, 0xF5, 0, 3, 1, -1, FL_ALL},
      {"mulx eax,ebx,ecx", 2, 3, 0xF6, 0, 3, 1, -1, FL_ALL},
      {"sarx eax,ecx,esi", 2, 2, 0xF7, 0, 6, 1, -1, FL_ALL},
      {"shlx eax,ecx,esi", 2, 1, 0xF7, 0, 6, 1, -1, FL_ALL},
      {"shrx eax,ecx,esi", 2, 3, 0xF7, 0, 6, 1, -1, FL_ALL},
      {"rorx eax,ecx,40", 3, 3, 0xF0, 0, 0, 1, 40, FL_ALL},
    };
    for (const Bmi &b : bmis) {
      auto encode = [&](const Vex &v, bool mem) {
        if (b.imm >= 0) return mem ? v.encode_rm_mem_imm(b.imm) : v.encode_rr_imm(b.imm);
        return mem ? v.encode_rm_mem() : v.encode_rr();
      };
      Vex v; v.mm = b.mm; v.pp = b.pp; v.opcode = b.op; v.reg = b.reg; v.vvvv = b.vvvv; v.rm = b.rm;
      for (bool w : {false, true}) {
        v.W = w;
        add(std::format("{} W{}", b.name, int(w)), encode(v, false), g, b.flags);
        add(std::format("{} W{} [edi]", b.name, int(w)), encode(v, true), g, b.flags, data);
      }
      v.W = false;
      // VEX.B̄ = 0: r/m is ecx, not r9, and the base edi, not r15.
      Vex vb = v; vb.rm = b.rm + 8;
      add(std::format("{} VEX.B̄=0", b.name), encode(vb, false), g, b.flags);
      std::vector<u8> code = encode(v, true);
      code[1] &= ~0x20;
      add(std::format("{} [edi] VEX.B̄=0", b.name), code, g, b.flags, data);
      // The top bit of VEX.vvvv clear: the register is one of the low eight,
      // or for RORX, whose vvvv is reserved (1111b), the field is 0111b,
      // #UD in any mode (SDM Vol.2A Table 2-41: "Otherwise | If != 1111b |
      // If != 1111b"; APM Vol.4 §3.2.5: "VEX.vvvv != 1111b | Single source
      // operand instructions | #UD | #UD").
      Vex vv = v; vv.vvvv = b.vvvv + 8;
      add(std::format("{} vvvv bit 3", b.name), encode(vv, false), g, b.flags, {},
          b.imm >= 0 ? UD : EITHER);
    }

    // VPADDD xmm0, xmm1, xmm2 with the extension bits that are ignored.
    Vex p; p.mm = 1; p.pp = 1; p.opcode = 0xFE; p.reg = 0; p.vvvv = 1; p.rm = 2;
    add("vpaddd xmm0,xmm1,xmm2", p.encode_rr(), g);
    {
      Vex q = p; q.rm = 10;
      add("vpaddd xmm0,xmm1,xmm2 VEX.B̄=0", q.encode_rr(), g);
      q = p; q.vvvv = 9; q.W = true;  // WIG; the 2-byte form would be LDS
      add("vpaddd xmm0,xmm1,xmm2 vvvv bit 3", q.encode_rr(), g, FL_ALL, {}, EITHER);
      q = p; q.L = true; q.vvvv = 9; q.rm = 10;
      add("vpaddd ymm0,ymm1,ymm2 VEX.B̄=0 vvvv bit 3", q.encode_rr(), g, FL_ALL, {}, EITHER);
      q = p; q.mm = 1; q.W = true;  // forces the 3-byte form
      std::vector<u8> code = q.encode_rm_mem();
      code[1] &= ~0x20;
      add("vpaddd xmm0,xmm1,[edi] VEX.B̄=0", code, g, FL_ALL, data);
    }
    // An unused VEX.vvvv (VMOVDQA xmm0, xmm1) with its top bit clear, and
    // with a low bit clear: #UD in any mode, as for RORX.
    {
      Vex m; m.mm = 1; m.pp = 1; m.opcode = 0x6F; m.reg = 0; m.vvvv = 8; m.rm = 1; m.W = true;
      add("vmovdqa xmm0,xmm1 vvvv=0111b", m.encode_rr(), g, FL_ALL, {}, UD);
      m.vvvv = 1;
      add("vmovdqa xmm0,xmm1 vvvv=1110b", m.encode_rr(), g, FL_ALL, {}, UD);
    }
    // W is an opcode extension or element size for vector instructions and
    // stays meaningful: VPSLLVQ (W1) vs. VPSLLVD (W0).
    {
      ArchState s = g;
      for (int j = 0; j < 4; j++) s.xmm[2].q[j] = 5 + j;  // dword counts 5+j and 0
      Vex q; q.mm = 2; q.pp = 1; q.opcode = 0x47; q.reg = 0; q.vvvv = 1; q.rm = 2;
      for (bool w : {false, true}) {
        q.W = w;
        add(std::format("vpsllv{} xmm0,xmm1,xmm2", w ? 'q' : 'd'), q.encode_rr(), s);
      }
    }

    // VEX instructions with a GPR operand whose size VEX.W selects in 64-bit
    // mode: "VEX.W1/EVEX.W1 in non-64 bit is ignored; the instructions
    // behaves as if the W0 version is used" (VMOVD/VMOVQ, VPEXTRD/Q,
    // VPINSRD/Q, CVTSI2SS/SD, CVTSS2SI, CVTSD2SI ...).  The APM's rows
    // outside 64-bit mode have "x" for W, but W0 for VCVTSI2SS ("0.src.X.10")
    // and W1 with opcode 6E for the VMOVD store; VPINSRQ is the SDM's
    // conflict (EITHER, above).
    {
      ArchState s = g;
      s.rax = 0x0000000180000000;  // a negative EAX, a positive RAX
      s.xmm[1].set<double>(0, 3e9);  // fits in 64 bits, not in 32
      s.xmm[3].set<float>(0, 3e9f);
      struct Gpr { const char *name; int mm, pp; u8 op; int reg, vvvv, rm, imm; Outcome outcome; };
      static const Gpr gprs[] = {
        {"vmovq xmm0,eax", 1, 1, 0x6E, 0, 0, 0, -1, EITHER},
        {"vmovq eax,xmm1", 1, 1, 0x7E, 1, 0, 0, -1, EITHER},
        {"vpextrq eax,xmm1,1", 3, 1, 0x16, 1, 0, 0, 1, DONE},
        {"vpextrq eax,xmm1,3", 3, 1, 0x16, 1, 0, 0, 3, DONE},
        {"vpinsrq xmm0,xmm1,eax,1", 3, 1, 0x22, 0, 1, 0, 1, EITHER},
        {"vpinsrq xmm0,xmm1,eax,3", 3, 1, 0x22, 0, 1, 0, 3, EITHER},
        {"vcvtsi2sd xmm0,xmm1,eax", 1, 3, 0x2A, 0, 1, 0, -1, DONE},
        {"vcvtsi2ss xmm0,xmm1,eax", 1, 2, 0x2A, 0, 1, 0, -1, EITHER},
        {"vcvtsd2si eax,xmm1", 1, 3, 0x2D, 0, 0, 1, -1, DONE},
        {"vcvttsd2si eax,xmm1", 1, 3, 0x2C, 0, 0, 1, -1, DONE},
        {"vcvtss2si eax,xmm3", 1, 2, 0x2D, 0, 0, 3, -1, DONE},
        {"vcvttss2si eax,xmm3", 1, 2, 0x2C, 0, 0, 3, -1, DONE},
      };
      for (const Gpr &c : gprs) {
        Vex v; v.mm = c.mm; v.pp = c.pp; v.opcode = c.op; v.reg = c.reg; v.vvvv = c.vvvv;
        v.rm = c.rm; v.W = true;
        auto encode = [&](bool mem) {
          if (c.imm >= 0) return mem ? v.encode_rm_mem_imm(c.imm) : v.encode_rr_imm(c.imm);
          return mem ? v.encode_rm_mem() : v.encode_rr();
        };
        bool from_fp = c.op == 0x2C || c.op == 0x2D;
        add(std::format("{} W1", c.name), encode(false), s, FL_ALL, {}, c.outcome);
        add(std::format("{} W1 [edi]", c.name), encode(true), s, FL_ALL,
            from_fp ? (c.pp == 3 ? fpd : fps) : data, c.outcome);
      }
    }

    // VEX gathers: VSIB with 32-bit addresses (EDI, not RDI), the mask
    // register in VEX.vvvv with its top bit ignored (EITHER, as for VPADDD),
    // VEX.B̄ ignored for the base, and #UD with the 67h prefix: "In 32-bit
    // mode, VSIB addressing is not supported when address size attribute is
    // overridden to 16 bits" (SDM Vol.2A §2.3.12); "VSIB addressing is only
    // valid in 32-bit or 64-bit effective addressing mode" (APM Vol.4
    // §1.3.2).
    {
      ArchState s = g;
      s.rdi = 0x5A5A5A5A00000000 | (DATA_ADDR + 16);
      for (int j = 0; j < 8; j++) s.xmm[2].set<int32_t>(j, (j * 5) % 8 - 4);
      for (int j = 0; j < 8; j++) s.xmm[1].set<u32>(j, j == 3 ? 0 : 0x80000000u);
      Vex v; v.mm = 2; v.pp = 1; v.opcode = 0x90; v.reg = 0; v.vvvv = 1;
      for (bool l : {false, true}) {
        v.L = l;
        const char *x = l ? "ymm" : "xmm";
        add(std::format("vpgatherdd {0}0,[edi+{0}2*4],{0}1", x), v.encode_vsib(2, 4), s, FL_ALL, data);
        Vex m = v; m.vvvv = 9;
        add(std::format("vpgatherdd {0}0,[edi+{0}2*4],{0}1 vvvv bit 3", x), m.encode_vsib(2, 4), s,
            FL_ALL, data, EITHER);
        std::vector<u8> code = v.encode_vsib(2, 4);
        code[1] &= ~0x20;
        add(std::format("vpgatherdd {0}0,[edi+{0}2*4],{0}1 VEX.B̄=0", x), code, s, FL_ALL, data);
        code = v.encode_vsib(2, 4);
        code.insert(code.begin(), 0x67);
        add(std::format("vpgatherdd {0}0,[di+{0}2*4],{0}1 (67h)", x), code, s, FL_ALL, data, UD);
      }
    }

    // Opmask instructions: KANDW k1, k2, k3 with vvvv's top bit clear (#UD
    // in 64-bit mode, where it would name k10: SDM Vol.2A Table 2-42, "If
    // vvvv = 0xxxb | None"; EITHER here, as for VPADDD), and KMOVQ with a
    // GPR, "V/I" (64-bit only) on its page: "VEX.W can only be used to
    // modify the size of the GPR operand in 64b mode", so W1 is KMOVD
    // (EITHER, the APM's rows being "only available in 64-bit mode").
    {
      ArchState s = g;
      for (int k = 0; k < 8; k++) s.kregs[k] = 0x0123456789ABCDEFULL * (k + 1);
      Vex k; k.mm = 1; k.pp = 0; k.opcode = 0x41; k.L = true; k.reg = 1; k.vvvv = 2; k.rm = 3;
      add("kandw k1,k2,k3", k.encode_rr(), s);
      std::vector<u8> code = {0xC4, 0xE1, 0x2C, 0x41, 0xCB};  // vvvv = ~0101b
      add("kandw k1,k2,k3 vvvv bit 3", code, s, FL_ALL, {}, EITHER);
      add("kmovd k1,eax", {0xC5, 0xFB, 0x92, 0xC8}, s);
      add("kmovq k1,eax W1", {0xC4, 0xE1, 0xFB, 0x92, 0xC8}, s, FL_ALL, {}, EITHER);
      add("kmovd eax,k1", {0xC5, 0xFB, 0x93, 0xC1}, s);
      add("kmovq eax,k1 W1", {0xC4, 0xE1, 0xFB, 0x93, 0xC1}, s, FL_ALL, {}, EITHER);
    }

    // C4h/C5h with bits 7:6 of the next byte other than 11b are LES/LDS
    // (SDM Vol.2A §2.3.5.2-3, §2.3.5.6): VEX.R̄ or VEX.X̄ = 0, or for C5h
    // the top bit of vvvv.  The far pointer is 0x0010:0x12345678.
    {
      std::vector<u8> fp = {0x78, 0x56, 0x34, 0x12, 0x10, 0x00};
      ArchState s;
      s.rcx = DATA_ADDR;
      s.rdi = DATA_ADDR;
      add("les eax,[ecx+0] (C4h, VEX.R̄=0)", {0xC4, 0x41, 0x00}, s, FL_ALL, fp);
      add("les eax,[edi+disp32] (C4h, VEX.X̄=0)", {0xC4, 0x87, 0, 0, 0, 0}, s, FL_ALL, fp);
      add("lds eax,[edi] (C5h, VEX.R̄=0)", {0xC5, 0x07}, s, FL_ALL, fp);
      add("lds eax,[edi+disp32] (C5h, vvvv bit 3)", {0xC5, 0x87, 0, 0, 0, 0}, s, FL_ALL, fp);
    }
  }

  // =====================================================================
  // EVEX
  // =====================================================================
  cat = "Compat EVEX";
  {
    ArchState s = g;
    s.kregs[1] = 0xFFFFFFFFFFFFFFF5ULL;
    // VPXORD xmm0, xmm1, xmm2 (62 F1 75 08 EF C2) with EVEX.V'̄ = 0, which
    // Table 2-41 makes #UD outside 64-bit mode ("EVEX.V' | Encodes
    // ZMM/YMM/XMM | None (valid) | If 0"; the APM has no rule for it), with
    // the top bit of vvvv (P[14]) clear too, with that bit alone clear
    // ("P[14] ignored"), and EVEX.R'̄ = 0, which names no register there
    // (Table 2-34, "REG | modrm.reg"; APM Vol.4 §3.2.4, "EVEX.R' == 0 | All
    // other instructions | - | Ign").
    add("vpxord xmm0,xmm1,xmm2 EVEX.V'̄=0", {0x62, 0xF1, 0x75, 0x00, 0xEF, 0xC2}, s, FL_ALL, {},
        UD);
    add("vpxord zmm0,zmm1,zmm2 EVEX.V'̄=0", {0x62, 0xF1, 0x75, 0x40, 0xEF, 0xC2}, s, FL_ALL, {},
        UD);
    add("vpxord xmm0,xmm1,xmm2 EVEX.V'̄=0 vvvv bit 3", {0x62, 0xF1, 0x35, 0x00, 0xEF, 0xC2}, s,
        FL_ALL, {}, UD);
    add("vpxord xmm0,xmm1,xmm2 vvvv bit 3", {0x62, 0xF1, 0x35, 0x08, 0xEF, 0xC2}, s);
    add("vpxord xmm0,xmm1,xmm2 EVEX.R'̄=0", {0x62, 0xE1, 0x75, 0x08, 0xEF, 0xC2}, s);
    add("vpxord xmm0,xmm1,[edi] EVEX.B̄=0", {0x62, 0xD1, 0x75, 0x08, 0xEF, 0x07}, s, FL_ALL, data);
    // An unused EVEX.vvvv (VMOVDQA32 xmm0, xmm1: 62 F1 7D 08 6F C1) must be
    // 1111b with V'̄ = 1 in either mode; its top bit is not exempt (Table
    // 2-41: "Otherwise | If != 1111b | If != 1111b", "Otherwise | If 0 | If
    // 0"; APM Vol.4 §3.2.4: "EVEX.vvvv != 1111b | Single source operand
    // instructions | #UD | #UD", "EVEX.V' != 1 | ... | #UD | #UD").
    add("vmovdqa32 xmm0,xmm1", {0x62, 0xF1, 0x7D, 0x08, 0x6F, 0xC1}, s);
    add("vmovdqa32 xmm0,xmm1 EVEX.V'̄=0", {0x62, 0xF1, 0x7D, 0x00, 0x6F, 0xC1}, s, FL_ALL, {},
        UD);
    add("vmovdqa32 xmm0,xmm1 vvvv=0111b", {0x62, 0xF1, 0x3D, 0x08, 0x6F, 0xC1}, s, FL_ALL, {},
        UD);
    // EVEX.R'̄ = 0 for an opmask destination (VPCMPEQD k1, xmm1, xmm2) and a
    // GPR destination (VCVTSS2SI eax, xmm1): #UD in 64-bit mode, ignored
    // outside it (Table 2-41).  EVEX.B̄ = 0 for a GPR source (VMOVD xmm0,
    // eax) and an opmask source (VPMOVM2D xmm0, k1): ignored.
    add("vpcmpeqd k1,xmm1,xmm2 EVEX.R'̄=0", {0x62, 0xE1, 0x75, 0x08, 0x76, 0xCA}, s);
    add("vcvtss2si eax,xmm1 EVEX.R'̄=0", {0x62, 0xE1, 0x7E, 0x08, 0x2D, 0xC1}, s);
    add("vmovd xmm0,eax EVEX.B̄=0", {0x62, 0xD1, 0x7D, 0x08, 0x6E, 0xC0}, s);
    add("vpmovm2d xmm0,k1 EVEX.B̄=0", {0x62, 0xD2, 0x7E, 0x08, 0x38, 0xC1}, s);

    // EVEX.W1 forms with a GPR operand, "EVEX.W1 in non-64 bit is ignored;
    // the instructions behaves as if the W0 version is used" (VMOVQ,
    // VPEXTRQ, VPINSRQ, VCVTSI2SD/SS, VCVTUSI2SD/SS, VCVT[T]SD2[U]SI,
    // VCVT[T]SS2[U]SI, VPBROADCASTQ from a GPR).  The APM's EVEX rows
    // outside 64-bit mode have "x" for W, but W0 for VPINSRD ("0.vvvv.01"),
    // and VPINSRQ is the SDM's conflict (EITHER, above).  The memory forms
    // use disp8 = 1, which the Tuple1 Scalar N of the operand size scales.
    ArchState c = s;
    c.rax = 0x0000000180000000;
    c.xmm[1].set<double>(0, 3e9);
    c.xmm[3].set<float>(0, 3e9f);
    struct Gpr { const char *name; int mm, pp; u8 op; int reg, vvvv, rm, imm; Outcome outcome; };
    static const Gpr gprs[] = {
      {"vmovq xmm0,eax", 1, 1, 0x6E, 0, 0, 0, -1, DONE},
      {"vmovq eax,xmm1", 1, 1, 0x7E, 1, 0, 0, -1, DONE},
      {"vpextrq eax,xmm1,1", 3, 1, 0x16, 1, 0, 0, 1, DONE},
      {"vpextrq eax,xmm1,3", 3, 1, 0x16, 1, 0, 0, 3, DONE},
      {"vpinsrq xmm0,xmm1,eax,1", 3, 1, 0x22, 0, 1, 0, 1, EITHER},
      {"vpinsrq xmm0,xmm1,eax,3", 3, 1, 0x22, 0, 1, 0, 3, EITHER},
      {"vcvtsi2sd xmm0,xmm1,eax", 1, 3, 0x2A, 0, 1, 0, -1, DONE},
      {"vcvtsi2ss xmm0,xmm1,eax", 1, 2, 0x2A, 0, 1, 0, -1, DONE},
      {"vcvtusi2sd xmm0,xmm1,eax", 1, 3, 0x7B, 0, 1, 0, -1, DONE},
      {"vcvtusi2ss xmm0,xmm1,eax", 1, 2, 0x7B, 0, 1, 0, -1, DONE},
      {"vcvtsd2si eax,xmm1", 1, 3, 0x2D, 0, 0, 1, -1, DONE},
      {"vcvttsd2si eax,xmm1", 1, 3, 0x2C, 0, 0, 1, -1, DONE},
      {"vcvtsd2usi eax,xmm1", 1, 3, 0x79, 0, 0, 1, -1, DONE},
      {"vcvttsd2usi eax,xmm1", 1, 3, 0x78, 0, 0, 1, -1, DONE},
      {"vcvtss2si eax,xmm3", 1, 2, 0x2D, 0, 0, 3, -1, DONE},
      {"vcvttss2si eax,xmm3", 1, 2, 0x2C, 0, 0, 3, -1, DONE},
      {"vcvtss2usi eax,xmm3", 1, 2, 0x79, 0, 0, 3, -1, DONE},
      {"vcvttss2usi eax,xmm3", 1, 2, 0x78, 0, 0, 3, -1, DONE},
      {"vpbroadcastq xmm0,eax", 2, 1, 0x7C, 0, 0, 0, -1, DONE},
    };
    for (const Gpr &g1 : gprs) {
      Evex e; e.mm = g1.mm; e.pp = g1.pp; e.opcode = g1.op; e.reg = g1.reg; e.vvvv = g1.vvvv;
      e.rm = g1.rm; e.W = true;
      std::vector<u8> code = g1.imm >= 0 ? e.encode_rr_imm(g1.imm) : e.encode_rr();
      add(std::format("{} W1", g1.name), code, c, FL_ALL, {}, g1.outcome);
      // [edi+1*N]: mod = 01, disp8 = 1, before any imm8.
      std::vector<u8> mem = e.encode_rm_mem();
      mem[5] |= 0x40;
      mem.push_back(1);
      if (g1.imm >= 0) mem.push_back(g1.imm);
      bool from_fp = g1.mm == 1 && (g1.op == 0x2C || g1.op == 0x2D || g1.op == 0x78 || g1.op == 0x79);
      // VPBROADCASTQ from a GPR has no memory form (#UD).
      bool no_mem = g1.mm == 2 && g1.op == 0x7C;
      add(std::format("{} W1 [edi+1*N]", g1.name), mem, c, FL_ALL,
          from_fp ? (g1.pp == 3 ? fpd : fps) : data, no_mem ? UD : g1.outcome);
    }
    // VCVTSI2SD W1 with {rn-sae} in the register form.
    add("vcvtsi2sd xmm0,xmm1,eax,{rn-sae} W1", {0x62, 0xF1, 0xF7, 0x18, 0x2A, 0xC0}, c);

    // The AVX512-FP16 conversions to and from a GPR (map 5).  An FP16 -2.0
    // converts to a signed 32-bit value whose zero extension differs from
    // the 64-bit one (an unsigned conversion gets +2.0, as a negative one
    // would be invalid), and an EAX or a dword in memory of 2 or 3 converts
    // to FP16 exactly, whereas RAX or the qword would overflow FP16.
    {
      ArchState h = c;
      h.rax = 0x0000000100000002;
      std::vector<u8> ints(64), neg(64), pos(64);
      for (int i = 0; i < 16; i++) {
        u32 x = i + 2;
        memcpy(&ints[i * 4], &x, 4);
      }
      for (int i = 0; i < 32; i++) {
        neg[i * 2 + 1] = 0xC0;  // -2.0
        pos[i * 2 + 1] = 0x40;  // +2.0
      }
      static const Gpr fp16[] = {
        {"vcvtsi2sh xmm0,xmm1,eax", 5, 2, 0x2A, 0, 1, 0, -1, DONE},
        {"vcvtusi2sh xmm0,xmm1,eax", 5, 2, 0x7B, 0, 1, 0, -1, DONE},
        {"vcvtsh2si eax,xmm3", 5, 2, 0x2D, 0, 0, 3, -1, DONE},
        {"vcvttsh2si eax,xmm3", 5, 2, 0x2C, 0, 0, 3, -1, DONE},
        {"vcvtsh2usi eax,xmm3", 5, 2, 0x79, 0, 0, 3, -1, DONE},
        {"vcvttsh2usi eax,xmm3", 5, 2, 0x78, 0, 0, 3, -1, DONE},
      };
      for (const Gpr &g1 : fp16) {
        Evex e; e.mm = g1.mm; e.pp = g1.pp; e.opcode = g1.op; e.reg = g1.reg; e.vvvv = g1.vvvv;
        e.rm = g1.rm; e.W = true;
        bool to_int = g1.op != 0x2A && g1.op != 0x7B, is_unsigned = g1.op >= 0x78;
        ArchState hs = h;
        hs.xmm[3].set<u16>(0, is_unsigned ? 0x4000 : 0xC000);
        add(std::format("{} W1", g1.name), e.encode_rr(), hs);
        std::vector<u8> mem = e.encode_rm_mem();
        mem[5] |= 0x40;
        mem.push_back(1);
        add(std::format("{} W1 [edi+1*N]", g1.name), mem, hs, FL_ALL,
            !to_int ? ints : is_unsigned ? pos : neg);
      }
    }

    // EVEX gathers and scatters: VSIB with 32-bit addresses, EVEX.V'̄ = 0,
    // which would extend the index register in 64-bit mode (#UD: Table 2-41,
    // "EVEX.V' | Encodes ZMM/YMM/XMM | None (valid) | If 0"; APM Vol.4
    // §3.2.4, "EVEX.V' != 1 | ... | #UD3 | #UD", note 3 exempting VSIB in
    // 64-bit mode only), and 67h (16-bit addresses, #UD, as for the VEX
    // gathers above).  The guest's data segments are all flat, so a segment
    // override shows only in 64-bit mode, with the FS and GS bases (the VSIB
    // cases of kvm-tests-avx-vex.cpp and kvm-tests-avx-special.cpp).
    {
      ArchState v = s;
      v.rdi = 0x5A5A5A5A00000000 | (DATA_ADDR + 64);
      for (int j = 0; j < 16; j++) v.xmm[2].set<int32_t>(j, (j * 7) % 16 - 8);
      v.kregs[1] = 0xFFFF;
      Evex e; e.mm = 2; e.pp = 1; e.opcode = 0x90; e.reg = 0; e.aaa = 1; e.LL = 2;
      std::vector<u8> code = e.encode_vsib(2, 4);
      add("vpgatherdd zmm0{k1},[edi+zmm2*4]", code, v, FL_ALL, data);
      code[3] &= ~0x08;
      add("vpgatherdd zmm0{k1},[edi+zmm2*4] EVEX.V'̄=0", code, v, FL_ALL, data, UD);
      code = e.encode_vsib(2, 4);
      code.insert(code.begin(), 0x67);
      add("vpgatherdd zmm0{k1},[di+zmm2*4] (67h)", code, v, FL_ALL, data, UD);
      e.opcode = 0xA0; e.reg = 1;
      code = e.encode_vsib(2, 4);
      add("vpscatterdd [edi+zmm2*4]{k1},zmm1", code, v, FL_ALL, data);
    }
  }
}

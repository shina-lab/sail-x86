#include "kvm-avx-encoder.h"

// VEX outside 64-bit mode, in compatibility mode (CS.L = 0, CS.D = 1).  Only
// eight registers of each kind exist there, and the prefix's extension bits
// and W are reinterpreted (SDM Vol.2A §2.3.5):
//   - C4h/C5h are VEX only if the next byte's bits 7:6 are 11b, otherwise
//     LES/LDS: VEX.R̄X̄ are always 1.
//   - VEX.B̄ and the top bit of a VEX.vvvv that names a register are
//     ignored.
//   - VEX.W1 of the instructions where W is REX.W for a general-purpose
//     operand is ignored: BMI1/BMI2, VMOVQ, VPEXTRQ, VPINSRQ, VCVTSI2SS/SD
//     and the other conversions to and from a GPR.
// The registers and memory hold distinct values in their upper halves and
// at the register numbers 8 above the encoded ones, so that reading either
// shows.  The SDM's statements disagree in places (VPINSRQ is "#UD in
// non-64-bit mode" on its page but W1 "ignored" in its table notes; KMOVQ
// with a GPR is "I" in 32-bit mode), and the vendors may too, so every case
// lets the hardware decide between faulting and completing (may_fault).
void add_compat_avx_tests(std::vector<TestCase> &tests) {
  std::string cat;
  auto add = [&](const std::string &name, std::vector<u8> code, const ArchState &init,
                 u64 flags = FL_ALL, std::vector<u8> data = {}) {
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = std::move(code);
    tc.initial = init;
    tc.flags_mask = flags;
    tc.init_data = std::move(data);
    tc.compat_mode = true;
    tc.may_fault = true;
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
      // or for RORX, whose vvvv is reserved (1111b), the field is 0111b.
      Vex vv = v; vv.vvvv = b.vvvv + 8;
      add(std::format("{} vvvv bit 3", b.name), encode(vv, false), g, b.flags);
    }

    // VPADDD xmm0, xmm1, xmm2 with the extension bits that are ignored.
    Vex p; p.mm = 1; p.pp = 1; p.opcode = 0xFE; p.reg = 0; p.vvvv = 1; p.rm = 2;
    add("vpaddd xmm0,xmm1,xmm2", p.encode_rr(), g);
    {
      Vex q = p; q.rm = 10;
      add("vpaddd xmm0,xmm1,xmm2 VEX.B̄=0", q.encode_rr(), g);
      q = p; q.vvvv = 9; q.W = true;  // WIG; the 2-byte form would be LDS
      add("vpaddd xmm0,xmm1,xmm2 vvvv bit 3", q.encode_rr(), g);
      q = p; q.L = true; q.vvvv = 9; q.rm = 10;
      add("vpaddd ymm0,ymm1,ymm2 VEX.B̄=0 vvvv bit 3", q.encode_rr(), g);
      q = p; q.mm = 1; q.W = true;  // forces the 3-byte form
      std::vector<u8> code = q.encode_rm_mem();
      code[1] &= ~0x20;
      add("vpaddd xmm0,xmm1,[edi] VEX.B̄=0", code, g, FL_ALL, data);
    }
    // An unused VEX.vvvv (VMOVDQA xmm0, xmm1) with its top bit clear, and
    // with a low bit clear (#UD in any mode).
    {
      Vex m; m.mm = 1; m.pp = 1; m.opcode = 0x6F; m.reg = 0; m.vvvv = 8; m.rm = 1; m.W = true;
      add("vmovdqa xmm0,xmm1 vvvv=0111b", m.encode_rr(), g);
      m.vvvv = 1;
      add("vmovdqa xmm0,xmm1 vvvv=1110b", m.encode_rr(), g);
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
    // VPINSRD/Q, CVTSI2SS/SD, CVTSS2SI, CVTSD2SI ...).
    {
      ArchState s = g;
      s.rax = 0x0000000180000000;  // a negative EAX, a positive RAX
      s.xmm[1].set<double>(0, 3e9);  // fits in 64 bits, not in 32
      s.xmm[3].set<float>(0, 3e9f);
      struct Gpr { const char *name; int mm, pp; u8 op; int reg, vvvv, rm, imm; };
      static const Gpr gprs[] = {
        {"vmovq xmm0,eax", 1, 1, 0x6E, 0, 0, 0, -1},
        {"vmovq eax,xmm1", 1, 1, 0x7E, 1, 0, 0, -1},
        {"vpextrq eax,xmm1,1", 3, 1, 0x16, 1, 0, 0, 1},
        {"vpextrq eax,xmm1,3", 3, 1, 0x16, 1, 0, 0, 3},
        {"vpinsrq xmm0,xmm1,eax,1", 3, 1, 0x22, 0, 1, 0, 1},
        {"vpinsrq xmm0,xmm1,eax,3", 3, 1, 0x22, 0, 1, 0, 3},
        {"vcvtsi2sd xmm0,xmm1,eax", 1, 3, 0x2A, 0, 1, 0, -1},
        {"vcvtsi2ss xmm0,xmm1,eax", 1, 2, 0x2A, 0, 1, 0, -1},
        {"vcvtsd2si eax,xmm1", 1, 3, 0x2D, 0, 0, 1, -1},
        {"vcvttsd2si eax,xmm1", 1, 3, 0x2C, 0, 0, 1, -1},
        {"vcvtss2si eax,xmm3", 1, 2, 0x2D, 0, 0, 3, -1},
        {"vcvttss2si eax,xmm3", 1, 2, 0x2C, 0, 0, 3, -1},
      };
      for (const Gpr &c : gprs) {
        Vex v; v.mm = c.mm; v.pp = c.pp; v.opcode = c.op; v.reg = c.reg; v.vvvv = c.vvvv;
        v.rm = c.rm; v.W = true;
        auto encode = [&](bool mem) {
          if (c.imm >= 0) return mem ? v.encode_rm_mem_imm(c.imm) : v.encode_rr_imm(c.imm);
          return mem ? v.encode_rm_mem() : v.encode_rr();
        };
        bool from_fp = c.op == 0x2C || c.op == 0x2D;
        add(std::format("{} W1", c.name), encode(false), s);
        add(std::format("{} W1 [edi]", c.name), encode(true), s, FL_ALL,
            from_fp ? (c.pp == 3 ? fpd : fps) : data);
      }
    }

    // Opmask instructions: KANDW k1, k2, k3 with vvvv's top bit clear (#UD
    // on Intel in 64-bit mode, where it would name k10), and KMOVQ with a
    // GPR, "V/I" (64-bit only) on its page.
    {
      ArchState s = g;
      for (int k = 0; k < 8; k++) s.kregs[k] = 0x0123456789ABCDEFULL * (k + 1);
      Vex k; k.mm = 1; k.pp = 0; k.opcode = 0x41; k.L = true; k.reg = 1; k.vvvv = 2; k.rm = 3;
      add("kandw k1,k2,k3", k.encode_rr(), s);
      std::vector<u8> code = {0xC4, 0xE1, 0x2C, 0x41, 0xCB};  // vvvv = ~0101b
      add("kandw k1,k2,k3 vvvv bit 3", code, s);
      add("kmovd k1,eax", {0xC5, 0xFB, 0x92, 0xC8}, s);
      add("kmovq k1,eax W1", {0xC4, 0xE1, 0xFB, 0x92, 0xC8}, s);
      add("kmovd eax,k1", {0xC5, 0xFB, 0x93, 0xC1}, s);
      add("kmovq eax,k1 W1", {0xC4, 0xE1, 0xFB, 0x93, 0xC1}, s);
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
}

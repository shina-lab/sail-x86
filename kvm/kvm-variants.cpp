// Variants of the constructed test cases.
//
// A template states an instruction sequence, its inputs, and the result
// the harness compares, and in doing so picks one point in each of several
// dimensions that the hardware and the model must agree on everywhere: the
// form of a memory operand, the immediate, the rounding mode, the register
// numbers, and the operand values.  The variants vary those dimensions
// mechanically, for every case whose code they can decode, so that coverage
// does not depend on each template choosing the points that matter.  (Every
// EVEX memory operand in the templates was [rdi], for example, so the model
// could scale disp8 by the wrong N, or decode a SIB byte twice, unseen.)
//
// The code is decoded into instructions, changed, and encoded again; a
// case whose code does not decode, or does not encode back to the same
// bytes, has no variants.  Each variant runs with may_fault: a changed
// encoding may fault where the case did not, so the model's outcome, which
// follows the manuals, is the expected one, and a host that differs is a
// failure or a known deviation (kvm-deviations.cpp).
// A variant that moves an operand to an address the case did not use
// keeps it inside the data page, the memory the harness compares (and
// where a store cannot overwrite the code).

#include "kvm-harness.h"
#include <cpuid.h>
#include <unordered_set>

namespace {

enum class Enc { Legacy, Vex, Evex };

// One instruction, decoded far enough to change its operands and encode it
// again.  Extension bits are logical (set selects registers 8-15 or 16-31)
// whichever way the encoding stores them.
struct Insn {
  std::vector<u8> prefixes;  // legacy prefixes, in order
  Enc enc = Enc::Legacy;
  bool rex = false;          // legacy: a REX prefix, possibly 40h
  bool vex3 = false;         // VEX: the three-byte form
  bool W = false, R = false, X = false, B = false;
  bool R2 = false, V2 = false;  // EVEX.R' and EVEX.V'
  int vvvv = 0;
  int L = 0;                 // VEX.L or EVEX.L'L
  int pp = 0;
  u8 evex_zbaaa = 0;         // EVEX.z, EVEX.b and EVEX.aaa in their P2 positions
  bool evex_p0_bit3 = false, evex_p1_bit2 = true;
  int map = 0;               // 0: one-byte; 1: 0F; 2: 0F 38; 3: 0F 3A; EVEX 5 and 6
  u8 op = 0;
  bool has_modrm = false;
  bool modrm_reg_only = false;  // MOV to or from CR/DR: mod is ignored
  u8 modrm = 0;
  bool has_sib = false;
  u8 sib = 0;
  int disp_len = 0;
  i32 disp = 0;
  std::vector<u8> imm;

  int mod() const { return modrm >> 6; }
  int reg() const { return ((modrm >> 3) & 7) | R << 3; }
  int rm() const { return (modrm & 7) | B << 3; }
  bool has_mem() const { return has_modrm && !modrm_reg_only && mod() != 3; }
  bool rip_relative() const { return has_mem() && mod() == 0 && (modrm & 7) == 5; }
  // A memory operand [base] or [base + disp], without SIB.
  bool simple_base() const { return has_mem() && (modrm & 7) != 4 && !rip_relative(); }
  bool has_prefix(u8 p) const {
    for (u8 x : prefixes) if (x == p) return true;
    return false;
  }
  bool legacy(int m, int o) const { return enc == Enc::Legacy && map == m && op == o; }
};

bool is_legacy_prefix(u8 b) {
  switch (b) {
  case 0x26: case 0x2E: case 0x36: case 0x3E: case 0x64: case 0x65:
  case 0x66: case 0x67: case 0xF0: case 0xF2: case 0xF3:
    return true;
  }
  return false;
}

// One-byte opcodes that are invalid in 64-bit mode (or are VEX/EVEX there).
bool invalid_in_64(u8 op) {
  switch (op) {
  case 0x06: case 0x07: case 0x0E: case 0x16: case 0x17: case 0x1E: case 0x1F:
  case 0x27: case 0x2F: case 0x37: case 0x3F: case 0x60: case 0x61: case 0x82:
  case 0x9A: case 0xCE: case 0xD4: case 0xD5: case 0xD6: case 0xEA:
    return true;
  }
  return false;
}

bool one_byte_has_modrm(u8 op) {
  if (op < 0x40) return (op & 7) < 4;
  switch (op) {
  case 0x63: case 0x69: case 0x6B: case 0xC0: case 0xC1: case 0xC6: case 0xC7:
  case 0xD0: case 0xD1: case 0xD2: case 0xD3: case 0xF6: case 0xF7: case 0xFE: case 0xFF:
    return true;
  }
  return (op >= 0x80 && op <= 0x8F) || (op >= 0xD8 && op <= 0xDF);
}

int one_byte_imm_len(const Insn &in) {
  u8 op = in.op;
  int z = in.has_prefix(0x66) && !in.W ? 2 : 4;  // REX.W overrides 66h
  if (op < 0x40) return (op & 7) == 4 ? 1 : (op & 7) == 5 ? z : 0;
  if ((op >= 0x70 && op <= 0x7F) || (op >= 0xB0 && op <= 0xB7) || (op >= 0xE0 && op <= 0xE7))
    return 1;
  if (op >= 0xB8 && op <= 0xBF) return in.W ? 8 : z;
  if (op >= 0xA0 && op <= 0xA3) return in.has_prefix(0x67) ? 4 : 8;
  switch (op) {
  case 0x68: case 0x69: case 0x81: case 0xA9: case 0xC7: return z;
  case 0x6A: case 0x6B: case 0x80: case 0x83: case 0xA8: case 0xC0: case 0xC1:
  case 0xC6: case 0xCD: case 0xEB: return 1;
  case 0xC2: case 0xCA: return 2;
  case 0xC8: return 3;
  case 0xE8: case 0xE9: return 4;
  case 0xF6: return (in.modrm >> 3 & 7) < 2 ? 1 : 0;
  case 0xF7: return (in.modrm >> 3 & 7) < 2 ? z : 0;
  }
  return 0;
}

bool map1_has_modrm(u8 op) {
  switch (op) {
  case 0x05: case 0x06: case 0x07: case 0x08: case 0x09: case 0x0B: case 0x0E:
  case 0x30: case 0x31: case 0x32: case 0x33: case 0x34: case 0x35: case 0x37:
  case 0x77: case 0xA0: case 0xA1: case 0xA2: case 0xA8: case 0xA9: case 0xAA:
    return false;
  }
  return !(op >= 0x80 && op <= 0x8F) && !(op >= 0xC8 && op <= 0xCF);
}

int map1_imm_len(const Insn &in) {
  u8 op = in.op;
  if ((op >= 0x70 && op <= 0x73) || (op >= 0x80 && op <= 0x8F)) return op < 0x80 ? 1 : 4;
  switch (op) {
  case 0x0F: case 0xA4: case 0xAC: case 0xBA: case 0xC2: case 0xC4: case 0xC5: case 0xC6:
    return 1;
  case 0x78:  // EXTRQ and INSERTQ with immediates; without a prefix, VMREAD
    return in.has_prefix(0x66) || in.has_prefix(0xF2) ? 2 : 0;
  }
  return 0;
}

// Decodes the 64-bit-mode instruction at code[pos].  Returns its length,
// or 0 for one the variants do not handle: an opcode invalid in 64-bit
// mode, a REX prefix not adjacent to the opcode, VEX or EVEX after a
// prefix that makes it #UD, XOP, an unknown map.
size_t decode(const std::vector<u8> &code, size_t pos, Insn *out) {
  Insn in;
  size_t p = pos;
  auto next = [&](u8 *b) {
    if (p >= code.size()) return false;
    *b = code[p++];
    return true;
  };
  u8 b;
  if (!next(&b)) return 0;
  while (is_legacy_prefix(b)) {
    in.prefixes.push_back(b);
    if (!next(&b)) return 0;
  }
  if ((b & 0xF0) == 0x40) {
    in.rex = true;
    in.W = b & 8; in.R = b & 4; in.X = b & 2; in.B = b & 1;
    if (!next(&b) || is_legacy_prefix(b) || (b & 0xF0) == 0x40) return 0;
  }

  int imm_len = 0;
  if (b == 0xC4 || b == 0xC5 || b == 0x62) {
    if (in.rex) return 0;
    for (u8 x : in.prefixes)
      if (x == 0x66 || x == 0xF0 || x == 0xF2 || x == 0xF3) return 0;
    u8 p0, p1, p2;
    if (b == 0xC5) {
      if (!next(&p0)) return 0;
      in.enc = Enc::Vex;
      in.R = !(p0 & 0x80);
      in.vvvv = ~p0 >> 3 & 15; in.L = p0 >> 2 & 1; in.pp = p0 & 3;
      in.map = 1;
    } else if (b == 0xC4) {
      if (!next(&p0) || !next(&p1)) return 0;
      in.enc = Enc::Vex;
      in.vex3 = true;
      in.R = !(p0 & 0x80); in.X = !(p0 & 0x40); in.B = !(p0 & 0x20);
      in.map = p0 & 0x1F;
      in.W = p1 & 0x80; in.vvvv = ~p1 >> 3 & 15; in.L = p1 >> 2 & 1; in.pp = p1 & 3;
      if (in.map < 1 || in.map > 3) return 0;
    } else {
      if (!next(&p0) || !next(&p1) || !next(&p2)) return 0;
      in.enc = Enc::Evex;
      in.R = !(p0 & 0x80); in.X = !(p0 & 0x40); in.B = !(p0 & 0x20); in.R2 = !(p0 & 0x10);
      in.evex_p0_bit3 = p0 & 0x08;
      in.map = p0 & 7;
      in.W = p1 & 0x80; in.vvvv = ~p1 >> 3 & 15; in.evex_p1_bit2 = p1 & 0x04; in.pp = p1 & 3;
      in.evex_zbaaa = p2 & 0x97; in.L = p2 >> 5 & 3; in.V2 = !(p2 & 0x08);
      if (in.map == 0 || in.map == 4 || in.map == 7) return 0;
    }
    if (!next(&in.op)) return 0;
    in.has_modrm = !(in.map == 1 && in.op == 0x77);
    bool map1_imm = (in.op >= 0x70 && in.op <= 0x73) ||
                    in.op == 0xC2 || (in.op >= 0xC4 && in.op <= 0xC6);
    imm_len = in.map == 3 || (in.map == 1 && map1_imm) ? 1 : 0;
  } else if (b == 0x0F) {
    if (!next(&b)) return 0;
    if (b == 0x38 || b == 0x3A) {
      in.map = b == 0x38 ? 2 : 3;
      if (!next(&in.op)) return 0;
      in.has_modrm = true;
      imm_len = in.map == 3 ? 1 : 0;
    } else {
      in.map = 1;
      in.op = b;
      in.has_modrm = map1_has_modrm(b);
      in.modrm_reg_only = b >= 0x20 && b <= 0x23;
    }
  } else {
    if (invalid_in_64(b)) return 0;
    in.op = b;
    in.has_modrm = one_byte_has_modrm(b);
    if (b == 0x8F && (p >= code.size() || (code[p] & 0x38) != 0)) return 0;  // XOP
  }

  if (in.has_modrm) {
    if (!next(&in.modrm)) return 0;
    if (in.has_mem()) {
      if ((in.modrm & 7) == 4) {
        in.has_sib = true;
        if (!next(&in.sib)) return 0;
      }
      if (in.mod() == 1)
        in.disp_len = 1;
      else if (in.mod() == 2 || in.rip_relative() || (in.has_sib && in.mod() == 0 && (in.sib & 7) == 5))
        in.disp_len = 4;
      u32 d = 0;
      for (int i = 0; i < in.disp_len; i++) {
        if (!next(&b)) return 0;
        d |= u32(b) << (8 * i);
      }
      in.disp = in.disp_len == 1 ? i8(d) : i32(d);
    }
  }
  if (in.enc == Enc::Legacy)
    imm_len = in.map == 0 ? one_byte_imm_len(in) : in.map == 1 ? map1_imm_len(in) : imm_len;
  for (int i = 0; i < imm_len; i++) {
    if (!next(&b)) return 0;
    in.imm.push_back(b);
  }
  *out = in;
  return p - pos;
}

std::vector<u8> encode(const Insn &in) {
  std::vector<u8> v(in.prefixes);
  switch (in.enc) {
  case Enc::Legacy:
    if (in.rex || in.W || in.R || in.X || in.B)
      v.push_back(u8(0x40 | in.W << 3 | in.R << 2 | in.X << 1 | in.B));
    if (in.map >= 1) v.push_back(0x0F);
    if (in.map == 2) v.push_back(0x38);
    if (in.map == 3) v.push_back(0x3A);
    break;
  case Enc::Vex:
    if (!in.vex3 && !in.X && !in.B && !in.W && in.map == 1) {
      v.push_back(0xC5);
      v.push_back(u8(!in.R << 7 | (~in.vvvv & 15) << 3 | in.L << 2 | in.pp));
    } else {
      v.push_back(0xC4);
      v.push_back(u8(!in.R << 7 | !in.X << 6 | !in.B << 5 | in.map));
      v.push_back(u8(in.W << 7 | (~in.vvvv & 15) << 3 | in.L << 2 | in.pp));
    }
    break;
  case Enc::Evex:
    v.push_back(0x62);
    v.push_back(u8(!in.R << 7 | !in.X << 6 | !in.B << 5 | !in.R2 << 4 |
                   in.evex_p0_bit3 << 3 | in.map));
    v.push_back(u8(in.W << 7 | (~in.vvvv & 15) << 3 | in.evex_p1_bit2 << 2 | in.pp));
    v.push_back(u8(in.evex_zbaaa | in.L << 5 | !in.V2 << 3));
    break;
  }
  v.push_back(in.op);
  if (in.has_modrm) v.push_back(in.modrm);
  if (in.has_sib) v.push_back(in.sib);
  for (int i = 0; i < in.disp_len; i++) v.push_back(u8(u32(in.disp) >> (8 * i)));
  v.insert(v.end(), in.imm.begin(), in.imm.end());
  return v;
}

// Decodes a whole case.  Fails unless every instruction decodes and the
// sequence encodes back to the same bytes.
bool decode_all(const std::vector<u8> &code, std::vector<Insn> *insns) {
  std::vector<u8> again;
  for (size_t pos = 0; pos < code.size();) {
    Insn in;
    size_t len = decode(code, pos, &in);
    if (len == 0) return false;
    insns->push_back(in);
    auto bytes = encode(in);
    again.insert(again.end(), bytes.begin(), bytes.end());
    pos += len;
  }
  return again == code;
}

// Code whose meaning depends on where its instructions are, which a variant
// that changes the length of an instruction would alter: a RIP-relative
// operand, and any transfer of control, whose target is a distance or an
// address the case computed for the original code.
bool position_dependent(const Insn &in) {
  if (in.rip_relative()) return true;
  if (in.enc != Enc::Legacy) return false;
  u8 op = in.op;
  if (in.map == 1)
    return (op >= 0x80 && op <= 0x8F) || op == 0x05 || op == 0x07 || op == 0x34 || op == 0x35;
  if (in.map != 0) return false;
  return (op >= 0x70 && op <= 0x7F) || (op >= 0xE0 && op <= 0xE3) || (op >= 0xE8 && op <= 0xEB) ||
         op == 0xC2 || op == 0xC3 || op == 0xCA || op == 0xCB || op == 0xCF ||
         (op == 0xFF && (in.modrm >> 3 & 7) >= 2 && (in.modrm >> 3 & 7) <= 5) ||
         (op == 0xC7 && in.modrm == 0xF8);  // XBEGIN
}

// Gathers, scatters and their prefetches, whose SIB index is a vector.
bool vsib(const Insn &in) {
  if (in.enc == Enc::Legacy || in.map != 2) return false;
  return (in.op >= 0x90 && in.op <= 0x93) ||
         (in.enc == Enc::Evex && ((in.op >= 0xA0 && in.op <= 0xA3) || in.op == 0xC6 || in.op == 0xC7));
}

// Instructions that operate on SSE, AVX or MMX state.
bool simd(const Insn &in) {
  if (in.enc != Enc::Legacy) return true;
  if (in.map == 2 || in.map == 3) return true;
  if (in.map != 1) return false;
  u8 op = in.op;
  return (op >= 0x10 && op <= 0x17) || (op >= 0x28 && op <= 0x2F) || (op >= 0x50 && op <= 0x7F) ||
         op == 0xC2 || (op >= 0xC4 && op <= 0xC6) || op >= 0xD0 ||
         (op == 0xAE && in.has_mem() && (in.modrm >> 3 & 7) <= 3);
}

// The mandatory prefix of an SSE/AVX instruction: 0 none, 1 66, 2 F3, 3 F2.
int mandatory_prefix(const Insn &in) {
  if (in.enc != Enc::Legacy) return in.pp;
  return in.has_prefix(0xF2) ? 3 : in.has_prefix(0xF3) ? 2 : in.has_prefix(0x66) ? 1 : 0;
}

// Floating-point arithmetic, conversions, comparisons and classification,
// which the model leaves to externs.  Their special values and rounding are
// not what the variants are for, so the variants that change operand
// values, the rounding mode or the immediate leave them out.
bool fp_arithmetic(const Insn &in) {
  u8 op = in.op;
  int mp = mandatory_prefix(in);
  bool evex = in.enc == Enc::Evex;
  switch (in.map) {
  case 0:
    return in.enc == Enc::Legacy && op >= 0xD8 && op <= 0xDF;  // x87
  case 1:
    return (op >= 0x2A && op <= 0x2F && op != 0x2B) || (op >= 0x51 && op <= 0x53) ||
           (op >= 0x58 && op <= 0x5F) || op == 0xC2 ||
           ((op == 0x7C || op == 0x7D || op == 0xD0 || op == 0xE6) && mp != 0) ||
           (evex && op >= 0x78 && op <= 0x7B);
  case 2:
    return op == 0x13 || (op >= 0x96 && op <= 0x9F) || (op >= 0xA6 && op <= 0xAF) ||
           (op >= 0xB6 && op <= 0xBF) ||
           (evex && (op == 0x2C || op == 0x2D || op == 0x42 || op == 0x43 ||
                     (op >= 0x4C && op <= 0x4F) || (op >= 0xC8 && op <= 0xCD) ||
                     (op == 0x52 && mp == 2) || (op == 0x72 && mp >= 2)));
  case 3:
    return (op >= 0x08 && op <= 0x0B) || op == 0x1D || op == 0x26 || op == 0x27 ||
           op == 0x40 || op == 0x41 || (op >= 0x50 && op <= 0x57 && op != 0x52 && op != 0x53) ||
           op == 0x66 || op == 0x67 || op == 0xC2;
  case 5:
  case 6:
    return true;  // AVX512-FP16
  }
  return false;
}

// The general-purpose registers an instruction writes without naming them
// in a register field.
u32 implicit_gpr_writes(const Insn &in) {
  constexpr u32 RAX = 1, RCX = 2, RDX = 4, RBX = 8, RSP = 16, RBP = 32, RSI = 64, RDI = 128;
  if (in.enc != Enc::Legacy) return 0;
  u8 op = in.op;
  if (in.map == 0) {
    if ((op == 0xF6 || op == 0xF7) && (in.modrm >> 3 & 7) >= 4) return RAX | RDX;
    if (op == 0x98 || op == 0x99) return RAX | RDX;
    if ((op >= 0xA4 && op <= 0xA7) || (op >= 0xAA && op <= 0xAF) || (op >= 0x6C && op <= 0x6F))
      return RCX | RSI | RDI;
    if (op >= 0xE0 && op <= 0xE3) return RCX;
    if (op == 0xC8 || op == 0xC9) return RSP | RBP;
    if (op == 0xD7) return RAX;
    if ((op >= 0x50 && op <= 0x5F) || op == 0x9C || op == 0x9D || op == 0x8F || op == 0xFF ||
        op == 0xC2 || op == 0xC3 || op == 0xE8 || op == 0x68 || op == 0x6A || op == 0xCF)
      return RSP;
    return 0;
  }
  if (in.map == 1) {
    if (op == 0xA2) return RAX | RCX | RDX | RBX;
    if (op == 0x31 || op == 0x32 || op == 0x33) return RAX | RDX;
    if (op == 0x05 || op == 0x07) return RCX | (1u << 11);
    if (op == 0xB0 || op == 0xB1) return RAX;
    if (op == 0xC7) return RAX | RDX;
    if (op == 0x01) return RAX | RCX | RDX;
    if (op == 0xA0 || op == 0xA1 || op == 0xA8 || op == 0xA9) return RSP;
  }
  return 0;
}

// Instructions that address memory through a register they do not name in
// a field: the string instructions, XLAT, MASKMOVQ/MASKMOVDQU, MONITOR,
// MONITORX and CLZERO.
bool implicit_memory(const Insn &in) {
  if (in.enc == Enc::Legacy && in.map == 0)
    return (in.op >= 0xA4 && in.op <= 0xA7) || (in.op >= 0xAA && in.op <= 0xAF) ||
           (in.op >= 0x6C && in.op <= 0x6F) || in.op == 0xD7;
  if (in.map == 1 && in.op == 0xF7) return true;
  return in.legacy(1, 0x01) && (in.modrm == 0xC8 || in.modrm == 0xFA || in.modrm == 0xFC);
}

// Opcodes whose embedded low three bits name a register (with REX.B).
bool opcode_register(const Insn &in) {
  if (in.enc != Enc::Legacy) return false;
  if (in.map == 1) return in.op >= 0xC8 && in.op <= 0xCF;
  if (in.map != 0) return false;
  return (in.op >= 0x50 && in.op <= 0x5F) || (in.op >= 0x91 && in.op <= 0x97) ||
         (in.op >= 0xB0 && in.op <= 0xBF);
}

// Whether the instruction might write general-purpose register r.  Without
// operand types the decoder cannot tell a GPR from a vector or mask
// register in a field, so any field holding r counts.
bool may_write_gpr(const Insn &in, int r) {
  if (implicit_gpr_writes(in) & (1u << r)) return true;
  if (opcode_register(in) && ((in.op & 7) | in.B << 3) == r) return true;
  if (in.has_modrm && (in.reg() == r || (in.mod() == 3 && in.rm() == r))) return true;
  return in.enc != Enc::Legacy && in.vvvv == r;
}

// ModRM.reg does not name a register: an opcode extension (/digit).
bool reg_is_opcode_extension(const Insn &in) {
  u8 op = in.op;
  if (in.enc == Enc::Legacy && in.map == 0)
    return (op >= 0x80 && op <= 0x83) || op == 0x8F || op == 0xC0 || op == 0xC1 ||
           op == 0xC6 || op == 0xC7 || (op >= 0xD0 && op <= 0xD3) || (op >= 0xD8 && op <= 0xDF) ||
           op == 0xF6 || op == 0xF7 || op == 0xFE || op == 0xFF;
  if (in.map == 1)
    return op == 0x00 || op == 0x01 || op == 0x0D || (op >= 0x18 && op <= 0x1F) ||
           (op >= 0x71 && op <= 0x73) || op == 0xAE || op == 0xBA || op == 0xC7;
  if (in.map == 2 && in.enc != Enc::Legacy)
    return op == 0xF3 || op == 0xC6 || op == 0xC7 || op == 0x49;
  return false;
}

// Mask-register operands, which have three-bit numbers.
enum KFields { K_NONE = 0, K_REG = 1, K_RM = 2, K_VVVV = 4 };

int mask_register_fields(const Insn &in) {
  u8 op = in.op;
  if (in.enc == Enc::Vex) {
    if (in.map == 1 && ((op >= 0x41 && op <= 0x4B) || op == 0x98 || op == 0x99))
      return K_REG | K_RM | K_VVVV;
    if (in.map == 1 && (op == 0x90 || op == 0x91)) return K_REG | K_RM;
    if (in.map == 1 && op == 0x92) return K_REG;
    if (in.map == 1 && op == 0x93) return K_RM;
    if (in.map == 3 && op >= 0x30 && op <= 0x33) return K_REG | K_RM;
    return K_NONE;
  }
  if (in.enc != Enc::Evex) return K_NONE;
  if ((in.map == 1 && (op == 0xC2 || (op >= 0x64 && op <= 0x66) || (op >= 0x74 && op <= 0x76))) ||
      (in.map == 2 && (op == 0x26 || op == 0x27 || op == 0x29 || op == 0x37 || op == 0x68 ||
                       op == 0x8F || (op == 0x39 && in.pp == 2))) ||
      (in.map == 3 && (op == 0x1E || op == 0x1F || op == 0x3E || op == 0x3F ||
                       op == 0x66 || op == 0x67 || op == 0xC2)))
    return K_REG;
  if (in.map == 2 && in.pp == 2 && (op == 0x28 || op == 0x38 || op == 0x2A || op == 0x3A))
    return K_RM;
  return K_NONE;
}

// EVEX instructions with a general-purpose register operand, whose number
// has no fifth bit.
bool evex_gpr_operand(const Insn &in) {
  u8 op = in.op;
  switch (in.map) {
  case 1:
    return op == 0x2A || op == 0x2C || op == 0x2D || op == 0x6E || op == 0xC4 || op == 0xC5 ||
           (op == 0x7E && in.pp == 1) || (op >= 0x78 && op <= 0x7B && in.pp >= 2);
  case 2:
    return op >= 0x7A && op <= 0x7C;
  case 3:
    return (op >= 0x14 && op <= 0x17) || op == 0x20 || op == 0x22;
  case 5:
    return op == 0x2A || op == 0x2C || op == 0x2D || op == 0x6E || op == 0x7E ||
           (op >= 0x78 && op <= 0x7B);
  }
  return false;
}

// The register in imm8[7:4] of the VEX four-operand blends.
bool is4_operand(const Insn &in) {
  return in.enc == Enc::Vex && in.map == 3 && in.op >= 0x4A && in.op <= 0x4C;
}

// ---- Code construction ----

void append(std::vector<u8> &v, const std::vector<u8> &w) { v.insert(v.end(), w.begin(), w.end()); }

void append32(std::vector<u8> &v, u32 x) {
  for (int i = 0; i < 4; i++) v.push_back(u8(x >> (8 * i)));
}

// LEA dst, [src + d]: changes no flags.
std::vector<u8> lea(int dst, int src, i32 d) {
  std::vector<u8> v = {u8(0x48 | (dst >> 3) << 2 | src >> 3), 0x8D,
                       u8(0x80 | (dst & 7) << 3 | (src & 7))};
  if ((src & 7) == 4) v.push_back(0x24);
  append32(v, u32(d));
  return v;
}

std::vector<u8> push(int r) {
  std::vector<u8> v;
  if (r >= 8) v.push_back(0x41);
  v.push_back(u8(0x50 | (r & 7)));
  return v;
}

std::vector<u8> pop(int r) {
  std::vector<u8> v;
  if (r >= 8) v.push_back(0x41);
  v.push_back(u8(0x58 | (r & 7)));
  return v;
}

std::vector<u8> mov32(int r, u32 imm) {
  std::vector<u8> v;
  if (r >= 8) v.push_back(0x41);
  v.push_back(u8(0xB8 | (r & 7)));
  append32(v, imm);
  return v;
}

// A rewritten instruction with the code to run around it.
struct Piece {
  std::vector<u8> before;
  Insn insn;
  std::vector<u8> after;
};

u64 gpr(const ArchState &s, int r) {
  static constexpr u64 ArchState::*regs[16] = {
    &ArchState::rax, &ArchState::rcx, &ArchState::rdx, &ArchState::rbx,
    &ArchState::rsp, &ArchState::rbp, &ArchState::rsi, &ArchState::rdi,
    &ArchState::r8,  &ArchState::r9,  &ArchState::r10, &ArchState::r11,
    &ArchState::r12, &ArchState::r13, &ArchState::r14, &ArchState::r15,
  };
  return s.*regs[r];
}

void set_gpr(ArchState &s, int r, u64 v) {
  static constexpr u64 ArchState::*regs[16] = {
    &ArchState::rax, &ArchState::rcx, &ArchState::rdx, &ArchState::rbx,
    &ArchState::rsp, &ArchState::rbp, &ArchState::rsi, &ArchState::rdi,
    &ArchState::r8,  &ArchState::r9,  &ArchState::r10, &ArchState::r11,
    &ArchState::r12, &ArchState::r13, &ArchState::r14, &ArchState::r15,
  };
  s.*regs[r] = v;
}

// ---- The variant kinds ----

// A case to derive variants from.
struct Base {
  const TestCase &tc;
  const std::vector<Insn> &insns;
  bool movable;  // no relative branch or RIP-relative operand
  u64 seed;      // for pseudo-random inputs, from the case's name
  std::unordered_set<std::string> *seen;  // the kind's variants of single instructions so far
};

// Marks what the manuals leave undefined in the results of an instruction
// that a variant made, which its case could not mark:
// - EXTRQ and INSERTQ (66 and F2 0F 78/79, register operands), which an
//   SSE4A host runs where a variant adds 66h or F2h to VMREAD or VMWRITE:
//   bits 127:64 of the destination are undefined, and bits 63:0 are too
//   where "the sum of the bit index + length field is greater than 64" or
//   the length is 0 with a nonzero index (AMD APM Vol.4 EXTRQ p.172,
//   INSERTQ p.195).  A register form takes its field from a register that
//   the code before it may have changed, so its whole destination is left
//   out.
void mark_undefined(TestCase &v) {
  std::vector<Insn> insns;
  if (!decode_all(v.code, &insns)) return;
  for (const Insn &in : insns) {
    int mp = mandatory_prefix(in);
    if ((in.legacy(1, 0x78) || in.legacy(1, 0x79)) && (mp == 1 || mp == 3) && in.mod() == 3) {
      int dst = in.op == 0x78 && mp == 1 ? in.rm() : in.reg();
      bool in_range = false;
      if (in.op == 0x78 && in.imm.size() == 2) {
        int len = in.imm[0] & 63, idx = in.imm[1] & 63;
        in_range = len == 0 ? idx == 0 : idx + len <= 64;
      }
      v.undefined.zmm[dst][1] = ~0ULL;
      if (!in_range) v.undefined.zmm[dst][0] = ~0ULL;
    }
  }
}

// Names a variant and passes it on.
struct Emit {
  const std::string &category;
  const std::function<void(TestCase &&)> &fn;

  void operator()(const Base &b, const std::string &detail, TestCase v) const {
    // The fill suffix ends every name; the detail goes before it.
    size_t p = b.tc.name.rfind(" [initial fill=");
    if (p == std::string::npos) p = b.tc.name.size();
    v.name = b.tc.name.substr(0, p) + " [" + detail + "]" + b.tc.name.substr(p);
    v.category = category;
    // An encoding that an extension of the host defines and the model
    // does not implement.
    if (host_unimplemented_extension(v)) return;
    mark_undefined(v);
    fn(std::move(v));
  }
};

struct Kind {
  const char *name;  // the category of the kind's variants
  bool sweeps_imm;   // the kind replaces the immediate
  void (*make)(const Base &b, const Emit &emit);
};

// What a case's code consists of, less the choices a variant replaces: per
// instruction, the encoding, map, opcode, prefixes, W, vector length,
// masking, and the form of each operand, but not register numbers or
// displacements, nor the immediate for a kind that sweeps it.  Cases with
// the same forms would get variants that test the same thing, so only the
// first gets them; the cases' other differences (values, masks, the
// register fill) are the business of the cases themselves.
std::string forms(const std::vector<Insn> &insns, bool with_imm) {
  std::string key;
  for (const Insn &in : insns) {
    key += std::format("{}.{}.{:02x}.{}.{:d}.{}.{:02x}.", int(in.enc), in.map, in.op, in.pp,
                       in.W, in.L, (in.evex_zbaaa & 0x90) | ((in.evex_zbaaa & 7) != 0));
    for (u8 p : in.prefixes) key += std::format("{:02x}", p);
    if (in.has_modrm) {
      key += in.mod() == 3 ? 'r' : in.rip_relative() ? 'p' : in.has_sib ? 's' : 'm';
      // Where ModRM selects the instruction rather than its operands.
      bool selects = in.mod() == 3 && (in.legacy(1, 0x01) ||
                                       (in.enc == Enc::Legacy && in.map == 0 && in.op >= 0xD8 &&
                                        in.op <= 0xDF));
      if (selects)
        key += std::format("{:02x}", in.modrm);
      else if (reg_is_opcode_extension(in))
        key += char('0' + (in.modrm >> 3 & 7));
    }
    if (with_imm)
      for (u8 b : in.imm) key += std::format("{:02x}", b);
    key += ';';
  }
  return key;
}

// A variant runs with the model translating through the guest's identity
// map of the low 2MB (less the pages below CODE_ADDR), so that an access
// outside it faults on both sides.
// A variant that faults after the instructions leaving the case's
// undefined flags pushes them in its RFLAGS image.
TestCase derive(const TestCase &tc) {
  TestCase v = tc;
  v.expect_fault = false;
  v.expected_vector = -1;
  v.may_fault = true;
  v.enable_paging = true;
  v.rflags_image_ignore |= FL_ARITH & ~tc.flags_mask;
  return v;
}

std::vector<u8> assemble(const std::vector<Piece> &pieces, size_t rip_piece = SIZE_MAX,
                         u64 rip_target = 0) {
  std::vector<u8> code;
  for (size_t i = 0; i < pieces.size(); i++) {
    append(code, pieces[i].before);
    Insn in = pieces[i].insn;
    std::vector<u8> bytes = encode(in);
    if (i == rip_piece) {
      // [RIP + disp32]: relative to the end of the instruction, past any
      // immediate.
      u64 next_rip = CODE_ADDR + code.size() + bytes.size();
      in.disp = i32(rip_target - next_rip);
      bytes = encode(in);
    }
    append(code, bytes);
    append(code, pieces[i].after);
  }
  return code;
}

// The address a memory operand starts from, when the code before it cannot
// have changed its base register: the initial value plus the displacement.
bool static_address(const Base &b, size_t at, u64 *addr) {
  const Insn &in = b.insns[at];
  int base = in.rm();
  // Too many instructions write RAX-RBX implicitly; RSP and RBP hold the stack.
  if (base < 6) return false;
  for (size_t i = 0; i < at; i++)
    if (may_write_gpr(b.insns[i], base)) return false;
  *addr = gpr(b.tc.initial, base) + in.disp;
  return true;
}

// A data page that differs at every offset, so that an access at the wrong
// place reads different data.  For floating-point arithmetic every byte is
// 40h-4Fh: whatever the element size and alignment, an element is then a
// positive normal number, not a special value for the externs.
std::vector<u8> distinct_page(bool fp, u64 seed) {
  std::mt19937_64 rng(seed);
  std::vector<u8> page(0x1000);
  for (u8 &byte : page) byte = fp ? u8(0x40 | (rng() & 0x0F)) : u8(rng());
  return page;
}

// VFIXUPIMM, whose memory operand is no number but a table of responses,
// most of them special values: no data page keeps it from them.
bool fixupimm(const Insn &in) {
  return in.enc == Enc::Evex && in.map == 3 && (in.op == 0x54 || in.op == 0x55);
}

// The approximate reciprocals and reciprocal square roots: RCPPS/SS and
// RSQRTPS/SS (0F 52, 53) in their legacy and VEX forms, VRCP14 and
// VRSQRT14 (EVEX 0F 38 4C-4F), and VRCPPH/SH and VRSQRTPH/SH (EVEX MAP6
// 4C-4F).  The SDM bounds their relative error but leaves the results to
// the implementation; the model computes the exact value.  A case compares
// them only on inputs whose results are exact (powers of two), or within a
// tolerance for its own instruction and vector length, and other data or
// another form of the instruction would test the approximation, not the
// decoding.
bool approximation(const Insn &in) {
  if (in.enc != Enc::Evex) return in.map == 1 && (in.op == 0x52 || in.op == 0x53);
  return (in.map == 2 || in.map == 6) && in.op >= 0x4C && in.op <= 0x4F;
}

// Memory operands: the same address through other encodings of it.  The
// base register is adjusted around the instruction where the encoding adds
// a displacement, so the operand stays where the case put it.
enum class MemForm { Disp8, Disp32, Sib, Rip, Addr32, ScaledUp, ScaledDown };

void mem_variant(const Base &b, const Emit &emit, MemForm form) {
  if (!b.movable) return;
  std::vector<Piece> pieces;
  size_t rip_piece = SIZE_MAX;
  u64 rip_target = 0;
  bool changed = false;
  for (size_t i = 0; i < b.insns.size(); i++) {
    Piece p{{}, b.insns[i], {}};
    Insn &in = p.insn;
    bool evex = in.enc == Enc::Evex;
    int base = in.rm();
    // The operand's base register must hold the address throughout the
    // instruction, which must not move the stack (the SIB form saves
    // registers there) or transfer control past the code after it.
    bool eligible = in.simple_base() && !vsib(in) && !(evex && in.mod() != 0) &&
                    !(in.legacy(0, 0xFF) && (in.modrm >> 3 & 7) >= 2) &&
                    !(implicit_gpr_writes(in) & (1u << 4)) && !may_write_gpr(in, base);
    if (!eligible) {
      pieces.push_back(p);
      continue;
    }
    u64 addr = 0;
    switch (form) {
    case MemForm::Disp8:
      // EVEX scales disp8 by an N this code does not know; disp8 = 0 keeps
      // the address, and the scaled forms below probe N.
      if (evex) {
        in.modrm = u8(0x40 | (in.modrm & 0x3F));
        in.disp_len = 1;
        in.disp = 0;
      } else {
        if (in.disp < 0 || in.disp > 255) break;
        p.before = lea(base, base, 128);
        in.modrm = u8(0x40 | (in.modrm & 0x3F));
        in.disp_len = 1;
        in.disp -= 128;
        p.after = lea(base, base, -128);
      }
      changed = true;
      break;
    case MemForm::Disp32:
      p.before = lea(base, base, 0x1000);
      in.modrm = u8(0x80 | (in.modrm & 0x3F));
      in.disp_len = 4;
      in.disp -= 0x1000;
      p.after = lea(base, base, -0x1000);
      changed = true;
      break;
    case MemForm::Sib: {
      // [t_base + t_index*8 + 0]: R13 as the base needs a displacement, and
      // R12 as the index needs SIB.index = 100b with X set.
      int t_base = 13, t_index = 12;
      auto names = [&](int r) { return base == r || may_write_gpr(in, r); };
      if (names(13) || names(12)) {
        t_base = 5;
        t_index = 9;
        if (names(5) || names(9)) break;
      }
      append(p.before, push(t_base));
      append(p.before, push(t_index));
      append(p.before, lea(t_base, base, in.disp - 64));
      append(p.before, mov32(t_index, 8));
      in.modrm = u8(0x44 | (in.modrm & 0x38));
      in.has_sib = true;
      in.sib = u8(0xC0 | (t_index & 7) << 3 | (t_base & 7));
      in.X = t_index >> 3;
      in.B = t_base >> 3;
      in.disp_len = 1;
      in.disp = 0;
      append(p.after, pop(t_index));
      append(p.after, pop(t_base));
      changed = true;
      break;
    }
    case MemForm::Rip:
      if (rip_piece != SIZE_MAX || !static_address(b, i, &addr)) break;
      if (addr < CODE_ADDR || addr >= STACK_TOP) break;
      in.modrm = u8(0x05 | (in.modrm & 0x38));
      in.B = false;
      in.X = false;
      in.disp_len = 4;
      rip_piece = i;
      rip_target = addr;
      changed = true;
      break;
    case MemForm::Addr32:
      if (in.has_prefix(0x67) || !static_address(b, i, &addr)) break;
      if (addr < CODE_ADDR || addr >= STACK_TOP) break;
      in.prefixes.insert(in.prefixes.begin(), 0x67);
      changed = true;
      break;
    case MemForm::ScaledUp:
    case MemForm::ScaledDown:
      // [base + 1*N] or [base - 1*N]: the operand moves by the instruction's
      // disp8 scale, within 128 bytes of where the case put it.  It reads
      // other data, so not for an approximate result, whose tolerance is
      // meant for the case's inputs.
      if (!evex || !static_address(b, i, &addr) || b.tc.approx_rel_tol > 0) break;
      if (addr < DATA_ADDR || addr > DATA_ADDR + 0xE00) break;
      in.modrm = u8(0x40 | (in.modrm & 0x3F));
      in.disp_len = 1;
      in.disp = form == MemForm::ScaledUp ? 1 : -1;
      if (form == MemForm::ScaledDown) {
        p.before = lea(base, base, 128);
        p.after = lea(base, base, -128);
      }
      changed = true;
      break;
    }
    pieces.push_back(p);
  }
  if (!changed) return;
  TestCase v = derive(b.tc);
  v.code = assemble(pieces, rip_piece, rip_target);
  if (v.code.size() > 0xF00) return;
  const char *detail = "";
  switch (form) {
  case MemForm::Disp8: detail = "disp8"; break;
  case MemForm::Disp32: detail = "disp32"; break;
  case MemForm::Sib: detail = "SIB"; break;
  case MemForm::Rip: detail = "RIP-relative"; break;
  case MemForm::Addr32: detail = "67h"; break;
  case MemForm::ScaledUp: detail = "disp8*N = +N"; break;
  case MemForm::ScaledDown: detail = "disp8*N = -N"; break;
  }
  if (form == MemForm::ScaledUp || form == MemForm::ScaledDown) {
    bool fp = false;
    for (const Insn &in : b.insns) {
      if (fixupimm(in) || approximation(in)) return;
      fp |= fp_arithmetic(in);
    }
    v.init_data = distinct_page(fp, b.seed);
  }
  emit(b, detail, std::move(v));
}

void make_disp8(const Base &b, const Emit &e) { mem_variant(b, e, MemForm::Disp8); }
void make_disp32(const Base &b, const Emit &e) { mem_variant(b, e, MemForm::Disp32); }
void make_sib(const Base &b, const Emit &e) { mem_variant(b, e, MemForm::Sib); }
void make_rip(const Base &b, const Emit &e) { mem_variant(b, e, MemForm::Rip); }
void make_addr32(const Base &b, const Emit &e) { mem_variant(b, e, MemForm::Addr32); }
void make_scaled(const Base &b, const Emit &e) {
  mem_variant(b, e, MemForm::ScaledUp);
  mem_variant(b, e, MemForm::ScaledDown);
}

// The imm8 control byte of the last SSE/AVX instruction that takes one,
// with every value of each field it may hold: the values of the low five
// bits, of the high nibble, and all ones.
void make_imm8(const Base &b, const Emit &emit) {
  size_t at = SIZE_MAX;
  for (size_t i = 0; i < b.insns.size(); i++) {
    const Insn &in = b.insns[i];
    bool control = in.imm.size() == 1 && simd(in) &&
                   !(in.enc == Enc::Legacy && in.map == 1 && in.op == 0x0F);  // 3DNow! suffix
    if (control) at = i;
  }
  if (at == SIZE_MAX || fp_arithmetic(b.insns[at])) return;
  // The immediate is the last byte of the instruction.
  size_t end = 0;
  for (size_t i = 0; i <= at; i++) end += encode(b.insns[i]).size();
  u8 original = b.tc.code[end - 1];
  for (int imm = 0; imm < 256; imm++) {
    bool field_value = imm < 0x20 || (imm & 0x0F) == 0 || imm == 0xFF;
    if (!field_value || imm == original) continue;
    TestCase v = derive(b.tc);
    v.code[end - 1] = u8(imm);
    emit(b, std::format("imm8={:#04x}", imm), std::move(v));
  }
}

// The three rounding modes besides the default, for SSE/AVX code other
// than floating-point arithmetic: MXCSR.RC must change nothing but MXCSR,
// as its saved images show.
void make_rounding(const Base &b, const Emit &emit) {
  if (b.tc.initial.mxcsr != 0x1F80) return;
  bool any = false;
  for (const Insn &in : b.insns) {
    if (fp_arithmetic(in)) return;
    any |= simd(in);
  }
  if (!any) return;
  static const char *names[] = {"RN", "RD", "RU", "RZ"};
  for (u32 rc = 1; rc < 4; rc++) {
    TestCase v = derive(b.tc);
    v.initial.mxcsr = 0x1F80 | rc << 13;
    emit(b, std::format("MXCSR.RC={}", names[rc]), std::move(v));
  }
}

// Register numbers: every register an instruction names, renumbered by
// flipping bit 3 (or, for EVEX-only code, bit 4), with the initial state
// permuted to match.  The extension bits that carry the flipped bit are
// REX.R/X/B, their VEX and EVEX forms, EVEX.R'/V', and EVEX.X for a
// register r/m operand.
// Instructions whose results are the host's own: RDTSC, RDPMC, RDTSCP,
// RDRAND and RDSEED differ from run to run, and CPUID, RDMSR, WRMSR and
// XGETBV act on what EAX or ECX selects, which for most selectors (which
// leaves and MSRs exist, what they hold) the model and the host need not
// agree on.  A case keeps such results out of its comparison (by shifting
// them away, or by its choice of selector), which renumbering the
// registers, or changing an instruction, would undo.
bool host_specific(const Insn &in) {
  if (in.enc != Enc::Legacy || in.map != 1) return false;
  return (in.op >= 0x30 && in.op <= 0x33) || in.op == 0xA2 ||
         (in.op == 0x01 && (in.modrm == 0xF9 || in.modrm == 0xD0)) ||
         (in.op == 0xC7 && in.mod() == 3 && (in.modrm >> 3 & 7) >= 6 && !in.has_prefix(0xF3));
}

// Whether a register field of the instruction holds 4 or 12.  Renumbering
// would turn R12 into RSP, or RSP into R12, and the stack with it.
bool names_rsp_or_r12(const Insn &in) {
  auto bad = [](int r) { return (r & 7) == 4 && r < 16; };
  if (in.has_modrm && bad(in.reg())) return true;
  if (in.has_modrm && in.mod() == 3 && bad(in.rm())) return true;
  if (in.has_sib && ((in.sib & 7) == 4 || ((in.sib >> 3 & 7) == 4 && in.X))) return true;
  if (in.enc != Enc::Legacy && bad(in.vvvv)) return true;
  if (opcode_register(in) && bad((in.op & 7) | in.B << 3)) return true;
  return is4_operand(in) && bad(in.imm[0] >> 4);
}

void permute_registers(const Base &b, const Emit &emit, int bit) {
  if (!b.movable || b.tc.category.starts_with("AMX")) return;
  bool evex = false, other_simd = false;
  for (const Insn &in : b.insns) {
    // An implicit address register keeps its number but not its value.
    if (implicit_memory(in) || host_specific(in)) return;
    if (bit == 8 && names_rsp_or_r12(in)) return;
    evex |= in.enc == Enc::Evex;
    other_simd |= in.enc != Enc::Evex && simd(in) && mask_register_fields(in) == K_NONE;
  }
  if (bit == 16 && (!evex || other_simd)) return;

  std::vector<Piece> pieces;
  for (Insn in : b.insns) {
    int k = mask_register_fields(in);
    bool reg_field = in.has_modrm && !in.modrm_reg_only && !(k & K_REG) &&
                     !reg_is_opcode_extension(in);
    bool rm_field = in.has_modrm && in.mod() == 3 && !(k & K_RM);
    if (bit == 8) {
      if (reg_field) in.R = !in.R;
      if (rm_field) in.B = !in.B;
      if (in.has_mem() && !in.rip_relative()) {
        if (!in.has_sib || !(in.mod() == 0 && (in.sib & 7) == 5)) in.B = !in.B;
        if (in.has_sib && (vsib(in) || (in.sib >> 3 & 7) != 4)) in.X = !in.X;
      }
      // VEX.vvvv = 0 is either register 0 or no operand; leave it.
      if (in.enc != Enc::Legacy && in.vvvv != 0 && !(k & K_VVVV)) in.vvvv ^= 8;
      if (opcode_register(in)) in.B = !in.B;
      if (is4_operand(in)) in.imm[0] ^= 0x80;
    } else if (in.enc == Enc::Evex && !evex_gpr_operand(in)) {
      if (reg_field) in.R2 = !in.R2;
      if (rm_field) in.X = !in.X;
      if (in.has_mem() && vsib(in))
        in.V2 = !in.V2;  // the index register's bit 4
      else if (in.vvvv != 0 || in.V2)
        in.V2 = !in.V2;
    }
    pieces.push_back({{}, in, {}});
  }
  TestCase v = derive(b.tc);
  v.code = assemble(pieces);
  if (v.code == b.tc.code) return;
  // The registers' undefined bits move with their contents.
  for (int i = 0; i < 32; i++)
    if (!(i & bit)) {
      std::swap(v.initial.xmm[i], v.initial.xmm[i | bit]);
      std::swap(v.undefined.zmm[i], v.undefined.zmm[i | bit]);
    }
  if (v.approx_rel_tol > 0) v.approx_reg ^= bit;
  if (bit == 8) {
    for (int r = 0; r < 8; r++) {
      if (r == 4) continue;
      u64 lo = gpr(v.initial, r), hi = gpr(v.initial, r + 8);
      set_gpr(v.initial, r, hi);
      set_gpr(v.initial, r + 8, lo);
      std::swap(v.undefined.gpr[r], v.undefined.gpr[r + 8]);
    }
  }
  emit(b, std::format("register numbers ^ {}", bit), std::move(v));
}

void make_regs8(const Base &b, const Emit &e) { permute_registers(b, e, 8); }
void make_regs16(const Base &b, const Emit &e) { permute_registers(b, e, 16); }

// The extension bits of opmask register fields, which have three bits.
// With an opmask in ModR/M.reg, EVEX.R, EVEX.R' and VEX.R set are #UD, and
// so is bit 3 of a VEX.vvvv that names one (SDM Vol.2A Table 2-41,
// "ModRM.reg encodes k-reg | If EVEX.R = 0", note 1 "This table also
// represents VEX restrictions"; Table 2-42, "K-regs are instruction
// operands not mask control | If vvvv = 0xxxb"; APM Vol.4 §3.2.4-5, "When
// ModR/M.reg specifies a K register | #UD").  With one in ModR/M.r/m,
// EVEX.X, EVEX.B and VEX.B are ignored ("ModRM.r/m encodes k-reg | None
// (ignored)"; APM "When ModRM.bbb specifies a K Register | Ign").  The
// renumbering above leaves these fields alone.
void make_kmask_bits(const Base &b, const Emit &emit) {
  if (!b.movable) return;
  for (int bit : {8, 16}) {
    std::vector<Piece> pieces;
    for (Insn in : b.insns) {
      int k = mask_register_fields(in);
      bool evex = in.enc == Enc::Evex;
      if (k && (bit == 8 || evex)) {
        bool &reg_bit = bit == 8 ? in.R : in.R2;
        bool &rm_bit = bit == 8 ? in.B : in.X;
        if (k & K_REG) reg_bit = !reg_bit;
        if ((k & K_RM) && in.mod() == 3) rm_bit = !rm_bit;
        if ((k & K_VVVV) && !evex) in.vvvv ^= 8;
      }
      pieces.push_back({{}, in, {}});
    }
    TestCase v = derive(b.tc);
    v.code = assemble(pieces);
    if (v.code != b.tc.code)
      emit(b, std::format("opmask field bit {} set", bit == 8 ? 3 : 4), std::move(v));
  }
}

// ---- Variants of one instruction at a time ----
//
// The kinds below change a single instruction of a case, and one case per
// instruction form gets each change (Base::seen): what is tested is the
// instruction's decoding, not the rest of the case.  A case with results
// of the host's own gets none, as the instruction that keeps them out of
// the comparison may be the one changed, and nor does an approximation.

bool claim(const Base &b, const Insn &in, const std::string &detail) {
  if (approximation(in)) return false;
  for (const Insn &i : b.insns)
    if (host_specific(i)) return false;
  return b.seen->insert(forms({in}, false) + detail).second;
}

// The arithmetic flags that a VEX-encoded general-purpose instruction
// leaves undefined (SDM Vol.2, "Flags Affected"): ANDN, BLSI, BLSMSK,
// BLSR and BZHI leave AF and PF, BEXTR AF, SF and PF.  A change of pp
// turns PDEP, PEXT, SARX, SHLX and SHRX, which leave the flags alone,
// into BZHI or BEXTR.
u64 undefined_flags(const Insn &in) {
  if (in.enc != Enc::Vex || in.map != 2 || in.pp != 0) return 0;
  switch (in.op) {
  case 0xF2: case 0xF3: case 0xF5: return FL_AF | FL_PF;
  case 0xF7: return FL_AF | FL_SF | FL_PF;
  }
  return 0;
}

// The case with instruction `at` replaced by `in`, whose undefined flags
// are as undefined as the case's own.  Where the change makes
// floating-point arithmetic read its operands as another element type (a
// change of W or of the mandatory prefix, as from PD to PS or from SD to
// SS), the values the case chose are no longer the ones it reads, and the
// vector registers and the data page get values whose elements of any size
// are positive normal numbers instead (see distinct_page).
TestCase replace_insn(const Base &b, size_t at, const Insn &in) {
  const Insn &orig = b.insns[at];
  TestCase v = derive(b.tc);
  std::vector<Piece> pieces;
  for (size_t i = 0; i < b.insns.size(); i++)
    pieces.push_back({{}, i == at ? in : b.insns[i], {}});
  v.code = assemble(pieces);
  v.flags_mask &= ~undefined_flags(in);
  v.rflags_image_ignore |= undefined_flags(in);
  // (x87 instructions have no element types: there a prefix selects the
  // format of an environment image, whose control word the case chose.)
  if (in.map != 0 && (fp_arithmetic(orig) || fp_arithmetic(in)) &&
      (orig.W != in.W || mandatory_prefix(orig) != mandatory_prefix(in))) {
    std::mt19937_64 rng(b.seed);
    for (auto &reg : v.initial.xmm)
      for (u64 &q : reg.q) q = (rng() & 0x0F0F0F0F0F0F0F0F) | 0x4040404040404040;
    if (in.has_mem()) v.init_data = distinct_page(true, b.seed);
  }
  return v;
}

// Whether an instruction may address memory through general-purpose
// register r: as a base or index, or implicitly.
bool addresses_through(const Insn &in, int r) {
  if (implicit_memory(in) && (r == 6 || r == 7)) return true;
  if (!in.has_mem() || in.rip_relative()) return false;
  if (!in.has_sib) return in.rm() == r;
  bool no_base = in.mod() == 0 && (in.sib & 7) == 5;
  return (!no_base && ((in.sib & 7) | in.B << 3) == r) || ((in.sib >> 3 & 7) | in.X << 3) == r;
}

// Whether an instruction may use general-purpose register r in any way:
// in a register field, as a base or index, or implicitly.
bool names_gpr(const Insn &in, int r) {
  return may_write_gpr(in, r) || addresses_through(in, r) ||
         (is4_operand(in) && (in.imm[0] >> 4) == r);
}

// Whether instruction i may write a general-purpose register through which
// a later instruction addresses memory.  A prefix that changes its operand
// size would move that access to an address the case did not use, which
// need not be in the data page.
bool feeds_address(const std::vector<Insn> &insns, size_t i) {
  if (simd(insns[i])) return false;
  for (int r = 0; r < 16; r++) {
    if (!may_write_gpr(insns[i], r)) continue;
    for (size_t j = i + 1; j < insns.size(); j++)
      if (addresses_through(insns[j], r)) return true;
  }
  return false;
}

// A register the code does not use, to hold an address, or -1.  RAX-RBX
// and RSI/RDI come last or not at all: too many instructions use them
// implicitly.
int free_gpr(const std::vector<Insn> &insns) {
  for (int r : {11, 10, 9, 8, 15, 14, 7, 6}) {
    bool used = false;
    for (const Insn &in : insns) used |= names_gpr(in, r);
    if (!used) return r;
  }
  return -1;
}

// 0F 00 and 0F 01, whose memory forms load and store descriptor tables:
// a variant there would change how the guest delivers exceptions.
bool system_group(const Insn &in) {
  return in.enc == Enc::Legacy && in.map == 1 && in.op <= 0x01;
}

// UMONITOR (F3 0F AE /6, mod = 11), which an F3h prefix makes of MFENCE
// and TPAUSE (and of UMWAIT, but F3h is not added beside its F2h:
// defined_prefix).  Its address is then whatever the register holds,
// usually 0, where the guest maps nothing, and an unmapped address is no
// case (kvm-tests-waitpkg.cpp): the model raises the #PF of the SDM's
// byte load, the Xeon Platinum 8562Y+ under KVM completes.
bool umonitor(const Insn &in) {
  if (!in.legacy(1, 0xAE) || in.mod() != 3 || (in.modrm >> 3 & 7) != 6) return false;
  for (size_t i = in.prefixes.size(); i-- > 0;)
    if (in.prefixes[i] == 0xF2 || in.prefixes[i] == 0xF3) return in.prefixes[i] == 0xF3;
  return false;
}

bool amd_host() {
  static const bool amd = [] {
    u32 a, b, c, d;
    __get_cpuid(0, &a, &b, &c, &d);
    return b == 0x68747541;  // "Auth" of AuthenticAMD
  }();
  return amd;
}

// LSS, LFS and LGS (0F B2, B4, B5) with REX.W on an AMD host.  The SDM has
// "REX.W + 0F B2 /r LSS r64,m16:64" (Vol.2A p.3-540); the APM lists no such
// form, "A 64-bit operand is not supported" (Vol.3 LDS-LSS p.216), and
// leaves what the processor does with it open.
bool amd_far_load_w(const Insn &in) {
  return amd_host() && in.W && (in.legacy(1, 0xB2) || in.legacy(1, 0xB4) || in.legacy(1, 0xB5));
}

// The instruction with its r/m operand as [r + disp] (no SIB).
Insn as_memory(Insn in, int r, int disp_len, i32 disp) {
  in.modrm = u8((disp_len == 0 ? 0x00 : disp_len == 1 ? 0x40 : 0x80) | (in.modrm & 0x38) | (r & 7));
  in.B = r >> 3;
  in.X = false;
  in.has_sib = false;
  in.disp_len = disp_len;
  in.disp = disp;
  return in;
}

// The x87 memory forms that load a number: FLD, FILD, FBLD, and the
// arithmetic and comparisons with a memory operand.
bool x87_loads_number(const Insn &in) {
  if (in.enc != Enc::Legacy || in.map != 0) return false;
  int digit = in.modrm >> 3 & 7;
  switch (in.op) {
  case 0xD8: case 0xDA: case 0xDC: case 0xDE: return true;
  case 0xD9: case 0xDD: return digit == 0;
  case 0xDB: return digit == 0 || digit == 5;
  case 0xDF: return digit == 0 || digit == 4 || digit == 5;
  }
  return false;
}

// FLDENV, FNSTENV, FRSTOR and FNSAVE (D9 /4, /6, DD /4, /6) with a 16-bit
// operand size, 66h without REX.W: the image is in the 16-bit format (SDM
// Vol.1 §8.1.10; APM Vol.2 §11.4.4.2), its fields at other offsets.
bool x87_image16(const Insn &in) {
  int digit = in.modrm >> 3 & 7;
  return in.has_mem() && (in.legacy(0, 0xD9) || in.legacy(0, 0xDD)) && (digit == 4 || digit == 6) &&
         in.has_prefix(0x66) && !in.W;
}

// Register operands as memory operands: an r/m register operand becomes
// [r] for a register r the code does not use, pointing at 800h in the data
// page, which holds the initial value of the register the operand named.
// An instruction without a memory form raises #UD instead.  EVEX forms
// also get EVEX.b, which with a memory operand is broadcast.  An x87
// register form whose memory form loads a number is left alone: it would
// load the bytes of a general-purpose register, values no case chose, for
// the externs' floating-point arithmetic.
void make_reg_to_mem(const Base &b, const Emit &emit) {
  if (!b.movable || b.tc.init_data.size() > 0x800) return;
  int r = free_gpr(b.insns);
  if (r < 0) return;
  for (size_t i = 0; i < b.insns.size(); i++) {
    const Insn &orig = b.insns[i];
    if (!orig.has_modrm || orig.mod() != 3 || orig.modrm_reg_only || system_group(orig) ||
        x87_loads_number(orig))
      continue;
    for (bool bcast : {false, true}) {
      if (bcast && orig.enc != Enc::Evex) continue;
      const char *detail = bcast ? "register r/m as broadcast memory" : "register r/m as memory";
      if (!claim(b, orig, detail)) continue;
      Insn in = as_memory(orig, r, 0, 0);
      in.evex_zbaaa = u8((in.evex_zbaaa & ~0x10) | (bcast ? 0x10 : 0));
      TestCase v = replace_insn(b, i, in);
      set_gpr(v.initial, r, DATA_ADDR + 0x800);
      v.init_data.resize(0x840);
      int reg = orig.rm() | (orig.enc == Enc::Evex ? orig.X << 4 : 0);
      if (simd(orig))
        memcpy(&v.init_data[0x800], v.initial.xmm[reg].q, 64);
      else
        for (int j = 0; j < 8; j++) v.init_data[0x800 + j] = u8(gpr(v.initial, reg & 15) >> (8 * j));
      // D9 F0-FF and DD F0-F7 become FNSTENV, FNSTCW and FNSAVE (D9 /6,
      // D9 /7, DD /6), whose images hold what no case set up to compare:
      // the reserved fields, the pointers (x87_env_undefined), and
      // condition codes the instructions before may leave undefined.
      int digit = in.modrm >> 3 & 7;
      bool d9 = in.legacy(0, 0xD9), dd = in.legacy(0, 0xDD);
      if ((d9 || dd) && digit == 6) {
        bool o16 = x87_image16(in);
        x87_env_undefined(v, 0x800, X87_CW_LOADED | X87_NO_DATA | X87_LONG_MODE, o16);
        v.data_undefined.push_back({u16(o16 ? 0x803 : 0x805), 0x47});  // C3, C2, C1, C0
      }
      if (d9 && digit == 7)
        x87_cw_undefined(v, 0x800);
      emit(b, detail, std::move(v));
    }
  }
}

// The same for EVEX with disp8 = +1 and -1, with and without broadcast:
// the access moves by the disp8*N of the instruction's tuple type, which
// the existing memory forms may not cover (half-vector conversions,
// byte and word broadcasts, ...).
void make_reg_to_scaled_mem(const Base &b, const Emit &emit) {
  if (!b.movable || b.tc.approx_rel_tol > 0) return;
  int r = free_gpr(b.insns);
  if (r < 0) return;
  for (size_t i = 0; i < b.insns.size(); i++) {
    const Insn &orig = b.insns[i];
    if (orig.enc != Enc::Evex || orig.mod() != 3 || fixupimm(orig)) continue;
    for (bool bcast : {false, true}) {
      for (int d : {1, -1}) {
        std::string detail = std::format("register r/m as {}[r{}N]", bcast ? "broadcast " : "",
                                         d > 0 ? "+" : "-");
        if (!claim(b, orig, detail)) continue;
        Insn in = as_memory(orig, r, 1, d);
        in.evex_zbaaa = u8((in.evex_zbaaa & ~0x10) | (bcast ? 0x10 : 0));
        TestCase v = replace_insn(b, i, in);
        set_gpr(v.initial, r, DATA_ADDR + 0x800);
        v.init_data = distinct_page(fp_arithmetic(orig), b.seed);
        emit(b, detail, std::move(v));
      }
    }
  }
}

// The x87 memory forms DA /0-/3 (FIADD, FIMUL, FICOM, FICOMP m32int) and
// DB /0-/3 (FILD, FISTTP, FIST, FISTP m32int), whose register forms are
// FCMOVcc.
bool x87_fcmov_form(const Insn &in) {
  return in.enc == Enc::Legacy && in.map == 0 && (in.op == 0xDA || in.op == 0xDB) &&
         (in.modrm >> 3 & 7) <= 3;
}

// Memory operands as register operands (mod = 11b, numbered as the base
// was).  An instruction without a register form raises #UD instead:
// gathers and scatters, non-temporal stores, LEA, CMPXCHG8B, ...  The x87
// forms whose register form is FCMOVcc are left alone: with ST(i) empty
// and the condition false, the manuals leave open whether there is a
// stack underflow (SDM Vol.2A FCMOVcc, p.3-322: "IF condition TRUE THEN
// ST(0) := ST(i); FI;" and "#IS Stack underflow occurred."), which a case
// written for the memory form does not choose ST(i) and the flags to avoid.
void make_mem_to_reg(const Base &b, const Emit &emit) {
  if (!b.movable) return;
  for (size_t i = 0; i < b.insns.size(); i++) {
    const Insn &orig = b.insns[i];
    if (!orig.has_mem() || system_group(orig) || x87_fcmov_form(orig) ||
        !claim(b, orig, "memory r/m as register"))
      continue;
    Insn in = orig;
    in.modrm = u8(0xC0 | (in.modrm & 0x3F));
    in.X = false;
    in.has_sib = false;
    in.disp_len = 0;
    in.disp = 0;
    TestCase v = replace_insn(b, i, in);
    emit(b, "memory r/m as register", std::move(v));
  }
}

// The EVEX scalar forms, whose rows give the vector length as LLIG.
bool evex_scalar(const Insn &in) {
  auto any = [&](std::initializer_list<u8> ops) {
    for (u8 op : ops)
      if (op == in.op) return true;
    return false;
  };
  auto fma = [&] {
    return any({0x99, 0x9B, 0x9D, 0x9F, 0xA9, 0xAB, 0xAD, 0xAF, 0xB9, 0xBB, 0xBD, 0xBF});
  };
  switch (in.map) {
  case 1:
    return in.pp >= 2 ? any({0x10, 0x11, 0x2A, 0x2C, 0x2D, 0x51, 0x58, 0x59, 0x5A, 0x5C, 0x5D,
                             0x5E, 0x5F, 0x78, 0x79, 0x7B, 0xC2})
                      : any({0x2E, 0x2F});
  case 2:
    return (in.pp == 1 && (fma() || any({0x2D, 0x43, 0x4D, 0x4F, 0xCB, 0xCD}))) ||
           (in.pp == 3 && any({0x9B, 0xAB}));
  case 3:
    return (in.pp <= 1 && any({0x0A, 0x27, 0x57, 0x67})) ||
           (in.pp == 1 && any({0x0B, 0x51, 0x55})) || (in.pp == 2 && in.op == 0xC2);
  case 5:
    return (in.pp == 2 && any({0x10, 0x11, 0x2A, 0x2C, 0x2D, 0x51, 0x58, 0x59, 0x5A, 0x5C, 0x5D,
                               0x5E, 0x5F, 0x78, 0x79, 0x7B})) ||
           (in.pp == 0 && any({0x1D, 0x2E, 0x2F})) || (in.pp == 3 && in.op == 0x5A);
  case 6:
    return (in.pp == 0 && in.op == 0x13) ||
           (in.pp == 1 && (fma() || any({0x2D, 0x43, 0x4D, 0x4F}))) ||
           (in.pp >= 2 && any({0x57, 0xD7}));
  }
  return false;
}

// Whether the manuals leave open if a change of one field is #UD:
//   - EVEX.L'L = 11b of a scalar form, which Table 2-38 of the SDM reserves
//     ("11b: Reserved (#UD)") and the APM makes #UD for all instructions
//     (Vol.4 §3.2.4, "EVEX.L'L == 11b | Memory instructions | #UD | #UD"),
//     but of which the SDM also says "When EVEX is used to encode scalar
//     instructions, L'L is generally ignored" (Vol.2A §2.7.10);
//   - VEX.W0 of VPERMQ and VPERMPD (VEX.256.66.0F3A 00 and 01), whose rows
//     are W1 in both manuals, where the APM says "Undefined cases of a
//     value of VEX.W" "may cause a #UD" (Vol.4 §3.2.5).
// The model raises #UD for both.
bool open_encoding(const Insn &orig, const Insn &in) {
  if (in.enc == Enc::Evex)
    return in.L == 3 && orig.L != 3 && evex_scalar(in);
  return in.map == 3 && in.pp == 1 && (in.op == 0x00 || in.op == 0x01) && !in.W && orig.W;
}

// Whether the host has Intel AVX10 of version 2 or later: CPUID.(07H,1):
// EDX[19] and the version in CPUID.24H.00H:EBX[7:0] (SDM Vol.1 Table 16-1).
// The SDM describes version 1, which is the AVX-512 instructions.  Version
// 2 defines EVEX encodings across the maps that the model does not
// implement (VADDBF16, EVEX.66.MAP5 58, is a pp flip of VADDPH), so on
// such a host the EVEX fields are not flipped.
bool host_has_avx10_2() {
  static const bool has = [] {
    if (!host_has(7, 1, CPUID_EDX, 19)) return false;
    u32 a, b, c, d;
    __cpuid_count(0x24, 0, a, b, c, d);
    return (b & 0xFF) >= 2;
  }();
  return has;
}

// The fields of VEX and EVEX prefixes, one at a time: W, vvvv and V' (1111b
// and 1 where there is no such operand), L or L'L, pp, EVEX.b, z and aaa,
// and the bits EVEX fixes (P0[3] = 0, P1[2] = 1).  The result is another
// instruction, or #UD, or where the manuals leave that open (open_encoding)
// either.
void make_fields(const Base &b, const Emit &emit) {
  if (!b.movable) return;
  for (size_t i = 0; i < b.insns.size(); i++) {
    const Insn &orig = b.insns[i];
    if (orig.enc == Enc::Legacy || (orig.enc == Enc::Evex && host_has_avx10_2())) continue;
    bool evex = orig.enc == Enc::Evex;
    std::vector<std::pair<std::string, Insn>> flips;
    auto flip = [&](std::string detail, auto change) {
      Insn in = orig;
      change(in);
      flips.push_back({std::move(detail), in});
    };
    flip("W", [](Insn &in) { in.W = !in.W; });
    flip("vvvv ^ 1", [](Insn &in) { in.vvvv ^= 1; });
    for (int pp = 0; pp < 4; pp++)
      if (pp != orig.pp) flip(std::format("pp={}", pp), [pp](Insn &in) { in.pp = pp; });
    if (evex) {
      for (int ll = 0; ll < 4; ll++)
        if (ll != orig.L) flip(std::format("L'L={}", ll), [ll](Insn &in) { in.L = ll; });
      flip("V'", [](Insn &in) { in.V2 = !in.V2; });
      flip("EVEX.b", [](Insn &in) { in.evex_zbaaa ^= 0x10; });
      flip("EVEX.z", [](Insn &in) { in.evex_zbaaa ^= 0x80; });
      flip("EVEX.aaa", [](Insn &in) {
        in.evex_zbaaa = u8((in.evex_zbaaa & ~7) | ((in.evex_zbaaa & 7) ? 0 : 1));
      });
      flip("EVEX P0[3]", [](Insn &in) { in.evex_p0_bit3 = !in.evex_p0_bit3; });
      flip("EVEX P1[2]", [](Insn &in) { in.evex_p1_bit2 = !in.evex_p1_bit2; });
    } else {
      flip("VEX.L", [](Insn &in) { in.L ^= 1; });
    }
    for (auto &[detail, in] : flips) {
      if (!claim(b, orig, detail)) continue;
      TestCase v = replace_insn(b, i, in);
      if (open_encoding(orig, in))
        v.allowed_outcomes = {6, b.tc.expect_fault ? b.tc.expected_vector : -1};
      emit(b, detail, std::move(v));
    }
  }
}

// The immediate size where a prefix decides it (66h for an operand-size
// immediate, REX.W for MOV r64, imm64, 66h for EXTRQ/INSERTQ): an
// immediate the change makes longer is zero-extended, a shorter one cut.
void resize_immediate(Insn &in) {
  if (in.enc != Enc::Legacy || in.map > 1) return;
  in.imm.resize(in.map == 0 ? one_byte_imm_len(in) : map1_imm_len(in), 0);
}

// Whether the manuals define the instruction with prefix p added:
// - "An instruction encoding may include a maximum of one prefix from each
//   of the five groups ... The result of using multiple prefixes from a
//   single group is undefined" (AMD APM Vol.3 §1.2.1, p.6): no F2h with
//   F3h, nor FS with GS.  In 64-bit mode the CS, DS, ES and SS overrides
//   "are not treated as segment-override prefixes for the purposes of
//   multiple-prefix rules" (§1.2.4, p.11).
// - Beside the F2h or F3h of an SSE instruction a 66h is "Other use of the
//   66H prefix", which "is reserved; such use may cause unpredictable
//   behavior" (SDM Vol.2A §2.1.1, p.2-2), as it is when F2h or F3h joins
//   the 66h of one.  Row F of the 0F 38 map takes 66h as an operand size
//   (APM Vol.3 §A.1.1, p.538), as do POPCNT, LZCNT and TZCNT.
bool defined_prefix(const Insn &in, u8 p) {
  bool repeat = in.has_prefix(0xF2) || in.has_prefix(0xF3);
  if ((p == 0xF2 || p == 0xF3) && repeat) return false;
  if (p == 0x64 && in.has_prefix(0x65)) return false;
  bool sse = in.enc == Enc::Legacy && simd(in) && !(in.map == 2 && in.op >= 0xF0);
  if (sse && p == 0x66 && repeat) return false;
  if (sse && (p == 0xF2 || p == 0xF3) && in.has_prefix(0x66)) return false;
  return true;
}

// The hosts on which a variant that adds 66h, F2h or F3h to a legacy
// instruction compares: those whose manual defines what the prefixes of the
// result do, as the model implements it.  Both manuals define the repeat
// prefixes of the string and I/O instructions, the mandatory prefixes their
// opcode tables list, and 66h as the operand size of a general-purpose
// instruction, which leaves an operand of fixed size alone (SDM Vol.2D
// Table B-6, p.B-4: w = 0 is 8 bits for either operand-size attribute; APM
// Vol.3 Appendix A, p.523: operand type b is "A byte, irrespective of the
// effective operand size").  The SDM reserves the other uses: "Use of
// repeat prefixes and/or undefined opcodes with other Intel 64 or IA-32
// instructions is reserved; such use may cause unpredictable behavior", and
// "Other use of the 66H prefix is reserved" (Vol.2A §2.1.1, p.2-2).  The
// APM defines more:
// - "Repeat Prefixes—These prefixes affect only certain string
//   instructions" (Vol.3 §1.2.1, p.6), and "The following prefixes are
//   ignored by x87 instructions: REP—The F3h and F2h prefixes" (Vol.1
//   §6.6.2, p.327); 66h "is ignored by all other x87 instructions" than
//   FLDENV, FNSTENV, FNSAVE and FRSTOR (Vol.3 §1.2.2, p.9).  The model
//   leaves the instruction as it is on both vendors, so the expectation is
//   the same on both hosts; the Intel host only compares less, because the
//   SDM leaves the result open (Hosts::Amd).
// - Where the APM's maps form the opcode with them (SSE and MMX, the 0F 38
//   and 0F 3A maps, Groups 9 and 15, MOVNTI), a cell that lists no
//   instruction is a reserved opcode: "cells shaded gray represent reserved
//   opcodes" (Vol.3 §A.1, p.524), and "#UD ... Execution of any reserved or
//   undefined opcode" (Vol.2 §8.2.7, p.251).  The SDM marks most of those
//   instructions NP: other prefixes "will either cause an invalid-opcode
//   exception (#UD) or result in the encoding for a different instruction"
//   (Vol.2A §3.1.1.1, p.3-2).  Where it does, both hosts compare; where it
//   does not, the AMD host alone.  The SDM marks NOP 90 NP as well, which
//   would make F2 90 #UD, there being no such instruction; the APM's
//   primary map forms no opcode with F2h, and the model ignores it there,
//   as the APM does.  The hint opcodes: hint_nop.
// No host compares:
// - REPNE with MOVS, LODS, STOS, INS and OUTS: it "can be added to the CMPS
//   and SCAS instructions" (SDM Vol.2B REPNE p.4-567), and "The prefix can
//   only be used with the CMPSx and SCASx instructions" (APM Vol.1
//   §3.5.1.4, p.79).  The model repeats as for REP.
// - 66h beside the F3h of RDFSBASE, RDGSBASE, WRFSBASE, WRGSBASE and ADOX,
//   whose pages in both manuals list 32- and 64-bit forms only, and 66h on
//   CMPXCHG8B, which APM Table A-7 makes CMPXCHG16B (p.536) and neither
//   manual's instruction page mentions.
// - F2h and F3h on 0F BA (BT, BTS, BTR, BTC with an immediate), 0F BB
//   (BTC) and MOVSX, F2h on BSF and BSR, and both on CMPXCHG8B: reserved
//   opcodes in APM Tables A-4 (p.532) and A-7 (p.536), for which the model,
//   ignoring the prefix on both vendors, raises no #UD.
// 66h on MOVDIRI compares on Intel only: NP, so #UD, which the model
// raises; the APM's MOVDIRI stores "4 bytes in all other cases" than REX.W
// (Vol.3 p.249), which the model does not.
enum class Hosts { None, Intel, Amd, Both };

// The hint opcodes, 0F 0D and 0F 18-1F but MPX's 0F 1A and 0F 1B, which do
// with 66h, F2h or F3h what they do without them in both manuals.  The
// SDM: "Instructions encoded with the opcode 0F0DH or with the opcodes 0F18H
// through 0F1FH result in the behavior of the NOP (No Operation)
// instruction, except for those opcodes defined in" Vol.2, and they "are
// decoded with a ModR/M byte and typical instruction prefix options but
// still result in the behavior of the NOP instruction" (Vol.3B §25.15,
// p.25-6).  The encodings Vol.2 defines there change no architectural state
// either: PREFETCHW, PREFETCHh, CLDEMOTE and NOP, and RDSSP and ENDBR,
// which are NOPs with CET off (RDSSP: "This opcode is a NOP when CET shadow
// stacks are not enabled", Vol.2B p.4-558).  The APM's map takes no
// prefixes in these rows ("n/a", Table A-4, p.531) but RDSSP's F3h, so
// they leave the instruction as it is (Vol.3 §1.2.1).
bool hint_nop(const Insn &in) {
  return in.enc == Enc::Legacy && in.map == 1 &&
         (in.op == 0x0D || (in.op >= 0x18 && in.op <= 0x1F && in.op != 0x1A && in.op != 0x1B));
}

Hosts prefix_hosts(const Insn &in) {
  u8 op = in.op;
  int reg = in.modrm >> 3 & 7;
  bool mem = in.has_mem();
  bool os = in.has_prefix(0x66);
  u8 rep = 0;  // the last of F2h and F3h
  for (u8 p : in.prefixes)
    if (p == 0xF2 || p == 0xF3) rep = p;

  if (in.map == 0 && ((op >= 0x6C && op <= 0x6F) || (op >= 0xA4 && op <= 0xA7) ||
                      (op >= 0xAA && op <= 0xAF))) {
    bool cmps_scas = op == 0xA6 || op == 0xA7 || op == 0xAE || op == 0xAF;
    return rep == 0xF2 && !cmps_scas ? Hosts::None : Hosts::Both;
  }
  if (hint_nop(in)) return Hosts::Both;

  if (!rep) {
    // 66h: the operand size of a general-purpose instruction, or part of
    // the opcode, as above.
    if (in.map == 0 && ((op >= 0xD8 && op <= 0xDF) || op == 0x9B))
      return mem && (op == 0xD9 || op == 0xDD) && (reg == 4 || reg == 6) ? Hosts::Both
                                                                         : Hosts::Amd;
    if (in.legacy(1, 0xC7) && reg == 1) return Hosts::None;
    if (in.map == 2 && op == 0xF9) return Hosts::Intel;
    return Hosts::Both;
  }

  bool opcode = (simd(in) && !(in.map == 2 && op >= 0xF0)) || in.legacy(1, 0xAE) ||
                in.legacy(1, 0xC3) || (in.legacy(1, 0xC7) && reg != 1);
  if (opcode) {
    if (!os) return Hosts::Both;
    // 66h beside the F2h or F3h of a Group 9 or 15 instruction: RDPID,
    // where "Normal operand size prefixes do not apply" (APM Vol.3 RDPID
    // p.307) and "do not affect the behavior" (SDM Vol.2B RDPID), and
    // PTWRITE, #UD "If 66H prefix is used" (SDM Vol.2B PTWRITE p.4-500)
    // and a reserved opcode on AMD.  UMONITOR, UMWAIT and SENDUIPI are
    // reserved opcodes on AMD, #UD.
    if (in.legacy(1, 0xC7) && reg == 7 && !mem) return Hosts::Both;
    if (in.legacy(1, 0xAE) && reg == 4 && rep == 0xF3) return Hosts::Both;
    if (in.legacy(1, 0xAE) && reg <= 3 && !mem && rep == 0xF3) return Hosts::None;
    return Hosts::Amd;
  }
  if (in.map == 1 && op >= 0xB8 && op <= 0xBF) {
    // POPCNT, TZCNT and LZCNT, where 66h is the operand size; UD1 is #UD.
    if (rep == 0xF3 && (op == 0xB8 || op == 0xBC || op == 0xBD)) return Hosts::Both;
    return op == 0xB9 ? Hosts::Amd : Hosts::None;
  }
  if (in.legacy(1, 0xC7)) return Hosts::None;  // CMPXCHG8B, CMPXCHG16B
  if (in.map == 2) {
    // Row F of the 0F 38 map, where 66h is an operand size (APM Vol.3
    // §A.1.1, p.538): CRC32, ADOX, ENQCMD and ENQCMDS, and MOVDIRI (NP).
    // The SDM reserves 66h beside the F2h of ENQCMD and the F3h of ENQCMDS,
    // F3h on MOVBE and F2h on ADCX; on AMD they are reserved opcodes, #UD.
    if (op == 0xF0 || op == 0xF1) return rep == 0xF2 ? Hosts::Both : Hosts::Amd;
    if (op == 0xF6 && rep == 0xF3) return os ? Hosts::None : Hosts::Both;
    if (op == 0xF8) return os ? Hosts::Amd : Hosts::Both;
    return op == 0xF9 ? Hosts::Both : Hosts::Amd;
  }
  // PAUSE and WBNOINVD.  66h beside their F3h the SDM reserves, and to the
  // APM it is the operand size of an instruction without operands.
  if (rep == 0xF3 && !os && ((in.legacy(0, 0x90) && !in.B) || in.legacy(1, 0x09)))
    return Hosts::Both;
  return Hosts::Amd;
}

bool compares_here(Hosts h) {
  return h == Hosts::Both || h == (amd_host() ? Hosts::Amd : Hosts::Intel);
}

// Prefixes added to one instruction at a time: operand size, REPNE/REP,
// LOCK, CS and FS segment overrides, and for legacy instructions REX, a
// flipped REX.W, and 66h with REX.W, each where the manuals define the
// result (defined_prefix, amd_far_load_w) for the host (prefix_hosts).  VEX
// and EVEX after any of them but a segment override are #UD.
void make_prefixes(const Base &b, const Emit &emit) {
  if (!b.movable) return;
  for (size_t i = 0; i < b.insns.size(); i++) {
    const Insn &orig = b.insns[i];
    if (system_group(orig) || orig.modrm_reg_only || feeds_address(b.insns, i)) continue;
    bool legacy = orig.enc == Enc::Legacy;
    std::vector<std::pair<std::string, Insn>> changed;
    for (u8 p : {0x66, 0xF2, 0xF3, 0xF0, 0x2E, 0x64}) {
      if (orig.has_prefix(p) || !defined_prefix(orig, p)) continue;
      Insn in = orig;
      in.prefixes.push_back(p);
      resize_immediate(in);
      if (legacy && (p == 0x66 || p == 0xF2 || p == 0xF3) && !compares_here(prefix_hosts(in)))
        continue;
      changed.push_back({std::format("prefix {:02X}h", p), in});
    }
    Insn in = orig;
    if (!legacy) {
      in.prefixes.push_back(0x40);
      changed.push_back({"REX before VEX/EVEX", in});
    } else {
      if (!orig.rex) {
        in.rex = true;
        changed.push_back({"REX", in});
      }
      in = orig;
      in.W = !in.W;
      resize_immediate(in);
      changed.push_back({"REX.W flipped", in});
      if (!orig.W && !orig.has_prefix(0x66) && defined_prefix(orig, 0x66)) {
        in = orig;
        in.prefixes.push_back(0x66);
        in.W = true;
        resize_immediate(in);
        if (compares_here(prefix_hosts(in))) changed.push_back({"66h and REX.W", in});
      }
    }
    for (auto &[detail, in] : changed) {
      if ((umonitor(in) && !umonitor(orig)) || amd_far_load_w(in))
        continue;
      // An x87 image keeps the format of its case, whose masks of the open
      // fields (x87_env_undefined, which depend on the host) and reads of
      // the image are for that format; in the other one other fields are
      // there.  Each format has cases of its own.
      if (x87_image16(in) != x87_image16(orig))
        continue;
      if (!claim(b, orig, detail))
        continue;
      TestCase v = replace_insn(b, i, in);
      emit(b, detail, std::move(v));
    }
  }
}

// Operand values: every vector and mask register, and the data page, as
// pseudo-random bits.  Templates often give every element the same value,
// which hides an element taken from the wrong position.
void make_values(const Base &b, const Emit &emit) {
  // Approximate results are compared with a tolerance meant for the
  // template's chosen inputs.
  if (b.tc.approx_rel_tol > 0 || b.tc.category.starts_with("AMX")) return;
  // Random data must not become an address: no gathers or scatters, whose
  // indices are vector elements, and nothing besides SIMD instructions but
  // the MOV r, imm that loads a mask.  Nor floating-point arithmetic.
  bool any = false;
  for (const Insn &in : b.insns) {
    if (vsib(in) || fp_arithmetic(in)) return;
    bool mov_imm = in.enc == Enc::Legacy && in.map == 0 && in.op >= 0xB8 && in.op <= 0xBF;
    if (!simd(in) && !mov_imm) return;
    any |= simd(in);
  }
  if (!any) return;
  for (u32 seed = 1; seed <= 2; seed++) {
    std::mt19937_64 rng(b.seed + seed);
    TestCase v = derive(b.tc);
    for (auto &reg : v.initial.xmm)
      for (u64 &q : reg.q) q = rng();
    for (u64 &k : v.initial.kregs) k = rng();
    v.init_data.resize(0x1000);
    for (u8 &byte : v.init_data) byte = u8(rng());
    emit(b, std::format("random values #{}", seed), std::move(v));
  }
}

const Kind KINDS[] = {
  {"Variant mem scaled disp8", false, make_scaled},
  {"Variant mem disp8", false, make_disp8},
  {"Variant mem disp32", false, make_disp32},
  {"Variant mem SIB", false, make_sib},
  {"Variant mem RIP", false, make_rip},
  {"Variant mem 67h", false, make_addr32},
  {"Variant imm8", true, make_imm8},
  {"Variant MXCSR.RC", false, make_rounding},
  {"Variant regs bit3", false, make_regs8},
  {"Variant regs bit4", false, make_regs16},
  {"Variant regs kmask", false, make_kmask_bits},
  {"Variant reg to mem", false, make_reg_to_mem},
  {"Variant reg to scaled mem", false, make_reg_to_scaled_mem},
  {"Variant mem to reg", false, make_mem_to_reg},
  {"Variant fields", false, make_fields},
  {"Variant prefixes", false, make_prefixes},
  {"Variant values", false, make_values},
};

}  // namespace

void for_each_variant(const std::vector<TestCase> &tests,
                      bool (*wanted)(const std::string &category),
                      const std::function<void(TestCase &&)> &fn) {
  for (const Kind &k : KINDS) {
    std::string cat = k.name;
    if (!wanted(cat)) continue;
    Emit emit{cat, fn};
    std::unordered_set<std::string> seen, seen_insns;
    for (const TestCase &tc : tests) {
      // System-mode cases set up their own descriptor tables and handlers.
      if (tc.compat_mode || tc.system_mode) continue;
      std::vector<Insn> insns;
      if (!decode_all(tc.code, &insns) || !seen.insert(forms(insns, !k.sweeps_imm)).second)
        continue;
      bool movable = true;
      for (const Insn &in : insns) movable &= !position_dependent(in);
      k.make(Base{tc, insns, movable, std::hash<std::string>{}(tc.name), &seen_insns}, emit);
    }
  }
}

// ---- The CPUID features of the instructions ----
//
// Which cases a host runs, from the encodings of their instructions: one
// of AVX-512 instructions where the host has the features they need, and
// one of an encoding that an extension the model does not implement
// defines where the host lacks that extension (build_suite in
// kvm-harness.cpp; a variant likewise, Emit above).

namespace {

// The instructions at the start of a case's code, up to the first that
// does not decode.  In compatibility mode 40h-4Fh are INC and DEC, and
// C4h, C5h and 62h are VEX and EVEX only where the next byte's bits 7:6
// are 11b (SDM Vol.2A §2.3.5, §2.7.1); the decoder knows 64-bit mode.
std::vector<Insn> leading_insns(const std::vector<u8> &code, bool compat_mode) {
  std::vector<Insn> insns;
  for (size_t pos = 0; pos < code.size();) {
    u8 b = code[pos];
    if (compat_mode && b >= 0x40 && b <= 0x4F) {
      pos++;
      continue;
    }
    if (compat_mode && (b == 0xC4 || b == 0xC5 || b == 0x62) &&
        (pos + 1 >= code.size() || (code[pos + 1] & 0xC0) != 0xC0))
      break;
    Insn in;
    size_t len = decode(code, pos, &in);
    if (len == 0) break;
    insns.push_back(in);
    pos += len;
  }
  return insns;
}

bool one_of(u8 op, std::initializer_list<u8> ops) {
  for (u8 x : ops)
    if (x == op) return true;
  return false;
}

// The AVX-512 extension of an EVEX instruction: the feature its row in the
// SDM names besides AVX512VL (the "CPUID Feature Flag" column, Vol.2A-2D).
// AVX512F where it names no other, and for the encodings it does not
// define.
Avx512Feature evex_extension(const Insn &in) {
  u8 op = in.op;
  bool W = in.W;
  int digit = in.modrm >> 3 & 7;
  switch (in.map) {
  case 1:
    switch (in.pp) {
    case 0:
      return one_of(op, {0x54, 0x55, 0x56, 0x57}) || (op == 0x5B && W) ? AVX512DQ : AVX512F;
    case 1:
      if (one_of(op, {0x60, 0x61, 0x63, 0x64, 0x65, 0x67, 0x68, 0x69, 0x6B, 0x71, 0x74, 0x75,
                      0xC4, 0xC5, 0xD1, 0xD5, 0xD8, 0xD9, 0xDA, 0xDC, 0xDD, 0xDE, 0xE0, 0xE1,
                      0xE3, 0xE4, 0xE5, 0xE8, 0xE9, 0xEA, 0xEC, 0xED, 0xEE, 0xF1, 0xF5, 0xF6,
                      0xF8, 0xF9, 0xFC, 0xFD}) ||
          (op == 0x73 && (digit == 3 || digit == 7)))
        return AVX512BW;
      return one_of(op, {0x54, 0x55, 0x56, 0x57, 0x78, 0x79, 0x7A, 0x7B}) ? AVX512DQ : AVX512F;
    case 2:
      if (op == 0x70) return AVX512BW;
      return (op == 0x7A || op == 0xE6) && W ? AVX512DQ : AVX512F;
    default:
      if (one_of(op, {0x6F, 0x70, 0x7F})) return AVX512BW;
      return op == 0x7A && W ? AVX512DQ : AVX512F;
    }
  case 2:
    switch (in.pp) {
    case 1:
      if (one_of(op, {0x00, 0x04, 0x0B, 0x10, 0x11, 0x12, 0x1C, 0x1D, 0x20, 0x26, 0x2B, 0x30,
                      0x38, 0x3A, 0x3C, 0x3E, 0x66, 0x78, 0x79, 0x7A, 0x7B}) ||
          (one_of(op, {0x75, 0x7D, 0x8D}) && W))
        return AVX512BW;
      if (one_of(op, {0x75, 0x7D, 0x8D, 0x83})) return AVX512_VBMI;
      if ((one_of(op, {0x19, 0x1B, 0x59, 0x5B}) && !W) || (one_of(op, {0x1A, 0x40, 0x5A}) && W))
        return AVX512DQ;
      if (op == 0x44 || op == 0xC4) return AVX512CD;
      if (op >= 0x50 && op <= 0x53) return AVX512_VNNI;
      if (op == 0x54 || op == 0x8F) return AVX512_BITALG;
      if (op == 0x55) return AVX512_VPOPCNTDQ;
      if (one_of(op, {0x62, 0x63, 0x70, 0x71, 0x72, 0x73})) return AVX512_VBMI2;
      if (op == 0xB4 || op == 0xB5) return AVX512_IFMA;
      if (op == 0xC6 || op == 0xC7) return AVX512PF;
      if (op >= 0xC8 && op <= 0xCD) return AVX512ER;
      if (op == 0xCF) return GFNI;
      if (op >= 0xDC && op <= 0xDF) return VAES;
      return AVX512F;
    case 2:
      if (one_of(op, {0x10, 0x20, 0x26, 0x28, 0x29, 0x30})) return AVX512BW;
      if (op == 0x38 || op == 0x39) return AVX512DQ;
      if (op == 0x2A || op == 0x3A) return AVX512CD;
      return op == 0x52 || op == 0x72 ? AVX512_BF16 : AVX512F;
    case 3:
      if (op == 0x68) return AVX512_VP2INTERSECT;
      return op == 0x72 ? AVX512_BF16 : AVX512F;
    }
    return AVX512F;
  case 3:
    if (in.pp == 0 || (in.pp == 2 && op == 0xC2)) return AVX512_FP16;
    if (one_of(op, {0x0F, 0x14, 0x15, 0x20, 0x3E, 0x3F, 0x42})) return AVX512BW;
    if (one_of(op, {0x16, 0x22, 0x50, 0x51, 0x56, 0x57, 0x66, 0x67}) ||
        (one_of(op, {0x18, 0x19, 0x38, 0x39}) && W) || (one_of(op, {0x1A, 0x1B, 0x3A, 0x3B}) && !W))
      return AVX512DQ;
    if (op == 0x44) return VPCLMULQDQ;
    if (op >= 0x70 && op <= 0x73) return AVX512_VBMI2;
    return op == 0xCE || op == 0xCF ? GFNI : AVX512F;
  }
  return AVX512_FP16;  // maps 5 and 6
}

// The EVEX forms that are 128-bit only: the moves of one or two elements
// to and from general-purpose registers and memory (VMOVD, VMOVQ, VMOVW,
// VMOVLPS ... VMOVHPD, VPINSR*, VPEXTR*, VINSERTPS, VEXTRACTPS).
bool evex_128_only(const Insn &in) {
  u8 op = in.op;
  switch (in.map) {
  case 1:
    return (in.pp <= 1 && one_of(op, {0x12, 0x13, 0x16, 0x17})) ||
           (in.pp == 1 && one_of(op, {0x6E, 0x7E, 0xC4, 0xC5, 0xD6})) || (in.pp == 2 && op == 0x7E);
  case 3:
    return in.pp == 1 && ((op >= 0x14 && op <= 0x17) || (op >= 0x20 && op <= 0x22));
  case 5:
    return in.pp == 1 && (op == 0x6E || op == 0x7E);
  }
  return false;
}

// The features an EVEX instruction needs: AVX512F and its extension, and
// AVX512VL for a 128- or 256-bit form of an instruction that has a 512-bit
// one, the procedure of SDM Vol.1 §15.3 and §15.4 (Figure 15-4, "Check
// AVX512F and a sibling 512-bit flag"; Table 15-2, "AVX512F & AVX512CD &
// AVX512VL").  A register form with EVEX.b set and a rounding control or
// SAE runs at 512 bits.
u32 evex_features(const Insn &in) {
  bool short_form = in.L < 2 && !(in.mod() == 3 && (in.evex_zbaaa & 0x10)) && !evex_scalar(in) &&
                    !evex_128_only(in);
  return 1u << AVX512F | 1u << evex_extension(in) | (short_form ? 1u << AVX512VL : 0);
}

// The features of a VEX opmask instruction, AVX512F and: AVX512F for the
// word forms (no prefix and W0, and W1 of KSHIFTRW and KSHIFTLW) and
// KUNPCKBW, AVX512DQ for the byte forms (66 and W0), KADDW and KTESTW,
// AVX512BW for the doubleword and quadword forms (W1, and F2 for KMOVD and
// KMOVQ with a general-purpose register), KUNPCKWD and KUNPCKDQ (SDM
// Vol.2A-2B, KADDW-KXORW).
u32 opmask_features(const Insn &in) {
  Avx512Feature ext;
  if (in.map == 3)
    ext = in.op & 1 ? AVX512BW : in.W ? AVX512F : AVX512DQ;
  else if (in.op == 0x4B)
    ext = in.pp == 1 ? AVX512F : AVX512BW;
  else if (in.pp == 3 || in.W)
    ext = AVX512BW;
  else if (in.pp == 1 || in.op == 0x4A || in.op == 0x99)
    ext = AVX512DQ;
  else
    ext = AVX512F;
  return 1u << AVX512F | 1u << ext;
}

// The encodings of extensions that the model does not implement: their
// opcodes in their map with their prefixes, whatever W and L.
struct Unimplemented {
  const char *name;
  u32 leaf, subleaf;
  CpuidReg reg;
  unsigned bit;
  bool (*defines)(const Insn &in);
};

bool vex_map(const Insn &in, int map) { return in.enc == Enc::Vex && in.map == map; }
bool evex_map(const Insn &in, int map) { return in.enc == Enc::Evex && in.map == map; }

const Unimplemented UNIMPLEMENTED[] = {
  // Intel APX makes EVEX P0[3] and P1[2], which are 0 and 1 in the SDM
  // ("P[3] | if > 0", "P[10] | if 0": Vol.2A Table 2-40, #UD), the fifth
  // bits of the B and X register fields (CPUID.(07H,1):EDX[21], Intel APX
  // Architecture Specification).
  {"APX_F", 7, 1, CPUID_EDX, 21,
   [](const Insn &in) { return in.enc == Enc::Evex && (in.evex_p0_bit3 || !in.evex_p1_bit2); }},
  // The Intel Xeon Phi extensions (SDM Vol.2D Chapter 8; Vol.1 Table
  // 21-21): VP4DPWSSD, VP4DPWSSDS (EVEX.F2.0F38 52, 53) and V4FMADDPS,
  // V4FMADDSS, V4FNMADDPS, V4FNMADDSS (EVEX.F2.0F38 9A, 9B, AA, AB).
  {"AVX512_4VNNIW", 7, 0, CPUID_EDX, 2,
   [](const Insn &in) { return evex_map(in, 2) && in.pp == 3 && (in.op == 0x52 || in.op == 0x53); }},
  {"AVX512_4FMAPS", 7, 0, CPUID_EDX, 3,
   [](const Insn &in) { return evex_map(in, 2) && in.pp == 3 && one_of(in.op, {0x9A, 0x9B, 0xAA, 0xAB}); }},
  // The VEX extensions of Vol.1 Tables 21-22 and 21-25: VPDPBSSD ...
  // VPDPBUUDS (F2, F3 and NP 0F38 50, 51), the AVX-NE-CONVERT loads and
  // conversions (0F38 B0, 66 and F3 B1, F3 72), VPDPWSUD ... VPDPWUUDS
  // (F3, 66 and NP 0F38 D2, D3), VSHA512MSG1, VSHA512MSG2, VSHA512RNDS2
  // (F2 0F38 CC, CD, CB), VSM3MSG1, VSM3MSG2 (NP and 66 0F38 DA), VSM3RNDS2
  // (66 0F3A DE), VSM4KEY4, VSM4RNDS4 (F3 and F2 0F38 DA), CMPccXADD (66
  // 0F38 E0-EF), TDPFP16PS (F2 0F38 5C) and VPMADD52LUQ, VPMADD52HUQ (66
  // 0F38 B4, B5).
  {"AVX_VNNI_INT8", 7, 1, CPUID_EDX, 4,
   [](const Insn &in) { return vex_map(in, 2) && in.pp != 1 && (in.op == 0x50 || in.op == 0x51); }},
  {"AVX_NE_CONVERT", 7, 1, CPUID_EDX, 5,
   [](const Insn &in) {
     return vex_map(in, 2) && (in.op == 0xB0 || (in.op == 0xB1 && (in.pp == 1 || in.pp == 2)) ||
                           (in.op == 0x72 && in.pp == 2));
   }},
  {"AVX_VNNI_INT16", 7, 1, CPUID_EDX, 10,
   [](const Insn &in) { return vex_map(in, 2) && in.pp <= 2 && (in.op == 0xD2 || in.op == 0xD3); }},
  {"SHA512", 7, 1, CPUID_EAX, 0,
   [](const Insn &in) { return vex_map(in, 2) && in.pp == 3 && in.op >= 0xCB && in.op <= 0xCD; }},
  {"SM3", 7, 1, CPUID_EAX, 1,
   [](const Insn &in) {
     return (vex_map(in, 2) && in.pp <= 1 && in.op == 0xDA) || (vex_map(in, 3) && in.pp == 1 && in.op == 0xDE);
   }},
  {"SM4", 7, 1, CPUID_EAX, 2,
   [](const Insn &in) { return vex_map(in, 2) && in.pp >= 2 && in.op == 0xDA; }},
  {"CMPCCXADD", 7, 1, CPUID_EAX, 7,
   [](const Insn &in) { return vex_map(in, 2) && in.pp == 1 && (in.op & 0xF0) == 0xE0; }},
  {"AMX_FP16", 7, 1, CPUID_EAX, 21,
   [](const Insn &in) { return vex_map(in, 2) && in.pp == 3 && in.op == 0x5C; }},
  {"AVX_IFMA", 7, 1, CPUID_EAX, 23,
   [](const Insn &in) { return vex_map(in, 2) && in.pp == 1 && (in.op == 0xB4 || in.op == 0xB5); }},
};

}  // namespace

u32 avx512_case_features(const TestCase &tc) {
  u32 needs = 0;
  for (const Insn &in : leading_insns(tc.code, tc.compat_mode)) {
    if (in.enc == Enc::Evex)
      needs |= evex_features(in);
    else if (in.enc == Enc::Vex && mask_register_fields(in) != K_NONE)
      needs |= opmask_features(in);
  }
  return needs;
}

const char *host_unimplemented_extension(const TestCase &tc) {
  static const std::vector<const Unimplemented *> host = [] {
    std::vector<const Unimplemented *> v;
    for (const Unimplemented &u : UNIMPLEMENTED)
      if (host_has(u.leaf, u.subleaf, u.reg, u.bit)) v.push_back(&u);
    return v;
  }();
  if (host.empty()) return nullptr;
  for (const Insn &in : leading_insns(tc.code, tc.compat_mode))
    for (const Unimplemented *u : host)
      if (u->defines(in)) return u->name;
  return nullptr;
}

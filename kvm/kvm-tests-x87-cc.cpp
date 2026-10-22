// x87 condition codes that report on the operation rather than compare:
// C2 of FSIN, FCOS, FSINCOS and FPTAN for a source out of range, and the
// quotient bits and C2 (partial remainder) of FPREM and FPREM1.
//
// Each case loads an explicit x87 state with FRSTOR (TOP = 3, the
// condition codes all clear or C3, C2, C1 and C0 all set, so that a code
// the instruction leaves is told from one it sets or clears), executes the
// instruction, and reads the status word with FNSTSW AX.  AX is then
// masked to what the model defines there: the condition codes the SDM
// leaves undefined go, and so do the exception flags of floating-point
// arithmetic, which the externs compute without reporting them (the
// trigonometric instructions raise none for a source out of range, so
// there they stay).  The harness compares TOP, the tags and the registers
// that are left valid; a result that the externs compute other than the
// hardware does (sin(2^63 - ulp): the hardware reduces with its own
// approximation of pi) is freed after FNSTSW, so that only its tag is.

#include "kvm-harness.h"
#include <optional>

namespace {

struct F80 {
  u64 m;   // significand, integer bit 63
  u16 se;  // sign and biased exponent
};

constexpr u64 INT_BIT = 1ull << 63;

// A value the host's long double holds exactly.
F80 f80(long double x) {
  F80 v;
  memcpy(&v.m, &x, 8);
  memcpy(&v.se, reinterpret_cast<const u8 *>(&x) + 8, 2);
  return v;
}

// The tag of a non-empty register (SDM Vol.1 §8.1.7, Figure 8-7).
u16 tag_of(F80 v) {
  u16 exp = v.se & 0x7FFF;
  if (exp == 0) return v.m == 0 ? 1 : 2;
  if (exp == 0x7FFF || !(v.m & INT_BIT)) return 2;
  return 0;
}

// The 108-byte FRSTOR image (32-bit protected-mode layout, SDM Vol.1
// Figure 8-9) with TOP = 3 and st[i] in ST(i); an empty optional is an
// empty register.
std::vector<u8> x87_image(u16 cw, u16 cc, const std::vector<std::optional<F80>> &st) {
  constexpr unsigned TOP = 3;
  std::vector<u8> image(108, 0);
  u16 sw = (TOP << 11) | cc, tw = 0xFFFF;
  for (unsigned i = 0; i < st.size(); i++) {
    if (!st[i]) continue;
    unsigned phys = (TOP + i) & 7;
    tw = (tw & ~(3u << (2 * phys))) | (tag_of(*st[i]) << (2 * phys));
    memcpy(&image[28 + 10 * i], &st[i]->m, 8);
    memcpy(&image[28 + 10 * i + 8], &st[i]->se, 2);
  }
  memcpy(&image[0], &cw, 2);
  memcpy(&image[4], &sw, 2);
  memcpy(&image[8], &tw, 2);
  return image;
}

// frstor [rdi+0x100]; insn; fnstsw ax; and eax, ~unmodeled & 0xFFFF; after
// An insn that ends having read the status word into AX itself sets
// read_sw = false: FNSTSW leaves the condition codes undefined.
TestCase x87_case(const std::string &category, const std::string &name, std::vector<u8> image,
                  const std::vector<u8> &insn, u16 unmodeled, const std::vector<u8> &after,
                  bool read_sw = true) {
  u32 keep = 0xFFFFu & ~u32(unmodeled);
  TestCase tc;
  tc.name = name;
  tc.category = category;
  tc.code = {0xDD, 0xA7, 0x00, 0x01, 0x00, 0x00};
  tc.code.insert(tc.code.end(), insn.begin(), insn.end());
  if (read_sw) tc.code.insert(tc.code.end(), {0xDF, 0xE0});
  tc.code.insert(tc.code.end(), {0x25, u8(keep), u8(keep >> 8), 0, 0});
  tc.code.insert(tc.code.end(), after.begin(), after.end());
  tc.initial.rdi = DATA_ADDR;
  tc.flags_mask = FL_NO_AF;  // AND leaves AF undefined
  tc.init_data = std::vector<u8>(0x100, 0);
  tc.init_data.insert(tc.init_data.end(), image.begin(), image.end());
  return tc;
}

// The status word's exception flags, ES and B, and its condition codes.
constexpr u16 SW_EXCEPTIONS = 0x003F;
constexpr u16 C0 = 0x0100, C1 = 0x0200, C3 = 0x4000;
const std::vector<u8> FFREE_ST0 = {0xDD, 0xC0}, FFREE_ST1 = {0xDD, 0xC1};

}  // namespace

void add_x87_cc_tests(std::vector<TestCase> &tests) {
  const F80 five = {0xA000000000000000ull, 0x4001};
  const F80 seven = {0xE000000000000000ull, 0x4001};

  // FSIN, FCOS, FSINCOS and FPTAN take a source in -2^63 < x < 2^63.
  // Outside it, "the C2 flag in the FPU status word is set, and the value
  // in register ST(0) remains unchanged.  The instruction does not raise
  // an exception"; FSINCOS and FPTAN push nothing.  Inside it, C2 := 0
  // (SDM Vol.2A, each instruction's Description and Operation).  C0 and C3
  // are undefined, and C1 is undefined when C2 is 1 (Vol.1 Table 8-1,
  // "Undefined if C2 = 1").  Infinities, NaNs and unsupported formats are
  // not out of range but invalid (#IA) or propagated, with C2 = 0.
  {
    const std::string cat = "x87 trig range";
    struct Op { const char *name; u8 modrm; bool pushes; };
    const Op ops[] = {{"fsin", 0xFE, false}, {"fcos", 0xFF, false},
                      {"fsincos", 0xFB, true}, {"fptan", 0xF2, true}};
    // exact: the result is exact (sin, tan 0 = 0, cos 0 = 1); inexact and
    // the special values are freed, and C1 (roundup) and the exception
    // flags are not compared there.
    enum Kind { EXACT, INEXACT, OUT_OF_RANGE, SPECIAL };
    struct Src { const char *name; F80 v; Kind kind; };
    const Src srcs[] = {
      {"+0", {0, 0x0000}, EXACT},
      {"-0", {0, 0x8000}, EXACT},
      {"2^63 - ulp", {~0ull, 0x403D}, INEXACT},
      {"-(2^63 - ulp)", {~0ull, 0xC03D}, INEXACT},
      {"2^63", {INT_BIT, 0x403E}, OUT_OF_RANGE},
      {"-2^63", {INT_BIT, 0xC03E}, OUT_OF_RANGE},
      {"2^63 + ulp", {INT_BIT | 1, 0x403E}, OUT_OF_RANGE},
      {"2^64", {INT_BIT, 0x403F}, OUT_OF_RANGE},
      {"-2^64", {INT_BIT, 0xC03F}, OUT_OF_RANGE},
      {"1e300", {0xBE2DE0F1B0B0E5EAull, 0x43E3}, OUT_OF_RANGE},
      {"largest finite", {~0ull, 0x7FFE}, OUT_OF_RANGE},
      {"-largest finite", {~0ull, 0xFFFE}, OUT_OF_RANGE},
      {"+inf", {INT_BIT, 0x7FFF}, SPECIAL},
      {"-inf", {INT_BIT, 0xFFFF}, SPECIAL},
      {"QNaN", {0xC000000000000001ull, 0x7FFF}, SPECIAL},
      {"unnormal, exponent 403EH", {1, 0x403E}, SPECIAL},
    };
    for (const Op &op : ops) {
      for (const Src &src : srcs) {
        for (u16 cc : {0x0000, 0x4700}) {
          u16 unmodeled = C0 | C3;
          std::vector<u8> after;
          if (src.kind == OUT_OF_RANGE) unmodeled |= C1;
          if (src.kind == INEXACT || src.kind == SPECIAL) {
            unmodeled |= C1 | SW_EXCEPTIONS;
            after = FFREE_ST0;
            if (op.pushes) after.insert(after.end(), FFREE_ST1.begin(), FFREE_ST1.end());
          }
          tests.push_back(x87_case(cat, std::format("{} {} (SW={:04x})", op.name, src.name, cc),
                                   x87_image(0x037F, cc, {src.v, five}), {0xD9, op.modrm},
                                   unmodeled, after));
        }
      }
    }
    // A stack fault comes before the range check, which an out-of-range
    // source then does not pass: FSINCOS and FPTAN with ST(7) full write
    // the indefinite to both results (masked) or change nothing but the
    // status word (unmasked), with C2 = 0 either way; an empty ST(0) is
    // the same for all four.  Unmasked, the instruction ends before it
    // would change C0 and C3, and the model leaves them.
    const F80 big = {INT_BIT, 0x403E};
    for (const Op &op : ops) {
      for (u16 cw : {0x037F, 0x037E}) {
        const char *how = cw == 0x037F ? "masked" : "unmasked";
        u16 unmodeled = cw == 0x037F ? C0 | C3 : 0;
        if (op.pushes)
          tests.push_back(x87_case(cat, std::format("{} 2^63, ST(7) full ({} overflow)", op.name, how),
                                   x87_image(cw, 0x4700, {big, five, {}, {}, {}, {}, {}, seven}),
                                   {0xD9, op.modrm}, unmodeled, {}));
        tests.push_back(x87_case(cat, std::format("{} ST(0) empty ({} underflow)", op.name, how),
                                 x87_image(cw, 0x4700, {std::nullopt, five}), {0xD9, op.modrm},
                                 unmodeled, {}));
      }
    }
  }

  // FPREM and FPREM1: C2 = 0 and C0, C3, C1 = Q2, Q1, Q0 of the quotient
  // for a complete reduction (exponents less than 64 apart), C2 = 1 for a
  // partial remainder, which the instruction reduces by 32 to 63 in the
  // exponent and which software reduces further by executing it again
  // (SDM Vol.2A FPREM and FPREM1, Description and Operation).  The results
  // are exact, so ST(0) is compared, and so are the exception flags but
  // where an operand is a denormal or NaN, or invalid.  ST(1) = b.
  {
    const std::string cat = "x87 fprem";
    struct Op { const char *name; u8 modrm; bool nearest; };
    const Op ops[] = {{"fprem", 0xF8, false}, {"fprem1", 0xF5, true}};
    auto add = [&](const Op &op, const std::string &what, F80 a, F80 b, u16 cc,
                   u16 unmodeled = 0, u16 cw = 0x037F) {
      tests.push_back(x87_case(cat, std::format("{} {} (SW={:04x})", op.name, what, cc),
                               x87_image(cw, cc, {a, b}), {0xD9, op.modrm}, unmodeled, {}));
    };
    for (const Op &op : ops) {
      for (u16 cc : {0x0000, 0x4700}) {
        // Every value of the quotient's low three bits, from a truncated
        // (FPREM) and a rounded (FPREM1) quotient: q + 1/4 rounds down,
        // q + 3/4 up (a negative remainder), q + 1/2 to even.
        for (int q = 0; q <= 8; q++)
          for (double f : {0.25, 0.5, 0.75})
            add(op, std::format("{} / 1", q + f), f80(q + f), f80(1.0), cc);
        // Signs: the quotient bits are those of |Q|; the remainder has the
        // dividend's sign, less a rounded-up quotient's.
        for (double a : {7.25, -7.25})
          for (double b : {2.0, -2.0})
            add(op, std::format("{} / {}", a, b), f80(a), f80(b), cc);
        add(op, "-6 / 3 (zero remainder)", f80(-6.0), f80(3.0), cc);
        add(op, "10 / 3", f80(10.0), f80(3.0), cc);
        add(op, "-11 / 3", f80(-11.0), f80(3.0), cc);
        add(op, "-0 / 3", f80(-0.0), f80(3.0), cc);
        add(op, "5 / +inf", f80(5.0), {INT_BIT, 0x7FFF}, cc);
        add(op, "1e18 / 3", f80(1e18), f80(3.0), cc);
        // Exponents 62 to 127 apart: complete below 64, partial from 64
        const F80 b = {0xADF85458A2B5A3EBull, 0x3FFF};
        for (int d : {62, 63, 64, 65, 95, 96, 100, 127})
          add(op, std::format("exponents {} apart", d),
              {0xC90FDAA22168C234ull, u16(0x3FFF + d)}, b, cc);
        // Denormal operands, and a pseudo-denormal dividend, which the
        // result normalizes (exponent 1).  #D and #U are not modeled.
        const F80 tiny3 = {3, 0}, tiny2 = {2, 0}, pseudo = {INT_BIT | 1, 0};
        add(op, "denormal 3 / denormal 2", tiny3, tiny2, cc, SW_EXCEPTIONS);
        add(op, "1 / denormal (partial)", f80(1.0), tiny2, cc, SW_EXCEPTIONS);
        add(op, "pseudo-denormal / 1", pseudo, f80(1.0), cc, SW_EXCEPTIONS);
        add(op, "denormal / 3", tiny3, f80(3.0), cc, SW_EXCEPTIONS);
        // No quotient: C2 and C1 cleared, C0 and C3 left.  #IA is not
        // modeled for these.
        add(op, "1 / 0", f80(1.0), f80(0.0), cc, SW_EXCEPTIONS);
        add(op, "+inf / 1", {INT_BIT, 0x7FFF}, f80(1.0), cc, SW_EXCEPTIONS);
        add(op, "QNaN / 1", {0xC000000000000005ull, 0x7FFF}, f80(1.0), cc, SW_EXCEPTIONS);
        add(op, "1 / -SNaN", f80(1.0), {0x8000000000000003ull, 0xFFFF}, cc, SW_EXCEPTIONS);
        add(op, "QNaN / QNaN (larger significand)", {0xC000000000000005ull, 0x7FFF},
            {0xC000000000000009ull, 0xFFFF}, cc, SW_EXCEPTIONS);
        // Stack underflow: the indefinite, C1 = 0 (masked); nothing but the
        // status word (unmasked); C2 cleared either way.
        for (u16 cw : {0x037F, 0x037E})
          tests.push_back(x87_case(cat, std::format("{} ST(1) empty ({}, SW={:04x})", op.name,
                                                    cw == 0x037F ? "masked" : "unmasked", cc),
                                   x87_image(cw, cc, {f80(7.0)}), {0xD9, op.modrm}, 0, {}));
      }
      // Repeated until the reduction is complete, counting the executions
      // in ECX: xor ecx, ecx; 1: fprem; inc ecx; fnstsw ax; test ah, 4;
      // jnz 1b.  The last FNSTSW gives the status word.  (The harness runs
      // the model for at most 1000 instructions.)
      for (int d : {64, 100, 1000, 5000}) {
        std::vector<u8> loop = {0x31, 0xC9, 0xD9, op.modrm, 0xFF, 0xC1,
                                0xDF, 0xE0, 0xF6, 0xC4, 0x04, 0x75, 0xF5};
        tests.push_back(x87_case(cat, std::format("{} loop, exponents {} apart", op.name, d),
                                 x87_image(0x037F, 0x4700,
                                           {F80{0xC90FDAA22168C234ull, u16(0x3FFF + d)},
                                            F80{0xADF85458A2B5A3EBull, 0x3FFF}}),
                                 loop, 0, {}, false));
      }
    }
  }
}

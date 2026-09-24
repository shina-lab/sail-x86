#include "kvm-harness.h"

// 30 values chosen to hit: zero, one, -1, signed min/max at each operand
// size (8/16/32/64), unsigned max at each size, just-past-boundary values,
// near-boundary ±1 values, alternating bit patterns, and sign-extension edges.
static const u64 VALS[] = {
    0x0000000000000000,  // zero
    0x0000000000000001,  // one
    0xFFFFFFFFFFFFFFFF,  // -1 / all bits set
    0x7FFFFFFFFFFFFFFF,  // INT64_MAX
    0x8000000000000000,  // INT64_MIN
    0x00000000FFFFFFFF,  // UINT32_MAX / lower half set
    0x0000000080000000,  // INT32_MIN (sign bit of dword)
    0x000000007FFFFFFF,  // INT32_MAX
    0x000000000000FFFF,  // UINT16_MAX
    0x0000000000008000,  // INT16_MIN (sign bit of word)
    0x0000000000007FFF,  // INT16_MAX
    0x00000000000000FF,  // UINT8_MAX
    0x0000000000000080,  // INT8_MIN (sign bit of byte)
    0x000000000000007F,  // INT8_MAX
    0x5555555555555555,  // alternating 01
    0xAAAAAAAAAAAAAAAA,  // alternating 10
    0x0000000100000000,  // bit 32 (dword/qword boundary)
    0x0000000000000002,  // two
    0xFFFFFFFFFFFFFFFE,  // -2
    0x7FFFFFFFFFFFFFFE,  // INT64_MAX - 1
    0x8000000000000001,  // INT64_MIN + 1
    0x123456789ABCDEF0,  // non-trivial mixed pattern
    // --- off-by-one / cross-boundary additions ---
    0x0000000000000100,  // UINT8_MAX + 1 (256): 8→16 bit overflow boundary
    0x0000000000010000,  // UINT16_MAX + 1 (65536): 16→32 bit overflow boundary
    0x00000000FFFFFFFE,  // UINT32_MAX - 1: near 32-bit unsigned wrap
    0x00000000000000FE,  // UINT8_MAX - 1: near 8-bit unsigned wrap
    0x000000000000FFFE,  // UINT16_MAX - 1: near 16-bit unsigned wrap
    0xFFFFFFFF00000000,  // upper dword set: sign-extension edge (32-bit ops see 0)
    0x000000007FFFFFFE,  // INT32_MAX - 1: near 32-bit signed overflow
    0x0000000080000001,  // INT32_MIN + 1: near 32-bit signed underflow
};
constexpr int NVALS = sizeof(VALS) / sizeof(u64);

static const u64 SHIFT_COUNTS[] = {0, 1, 2, 7, 8, 15, 16, 31, 32, 33, 63};
constexpr int NSHIFTS = sizeof(SHIFT_COUNTS) / sizeof(u64);

static const char *GPR_NAMES[] = {
    "rax","rcx","rdx","rbx","rsp","rbp","rsi","rdi",
    "r8","r9","r10","r11","r12","r13","r14","r15"
};

static void set_gpr(ArchState &s, int reg, u64 val) {
  switch (reg) {
  case 0:  s.rax = val; break;
  case 1:  s.rcx = val; break;
  case 2:  s.rdx = val; break;
  case 3:  s.rbx = val; break;
  case 4:  s.rsp = val; break;
  case 5:  s.rbp = val; break;
  case 6:  s.rsi = val; break;
  case 7:  s.rdi = val; break;
  case 8:  s.r8  = val; break;
  case 9:  s.r9  = val; break;
  case 10: s.r10 = val; break;
  case 11: s.r11 = val; break;
  case 12: s.r12 = val; break;
  case 13: s.r13 = val; break;
  case 14: s.r14 = val; break;
  case 15: s.r15 = val; break;
  }
}

// Encode ALU reg,reg: OP r/m, reg  (reg field = src, r/m = dst)
// base: base opcode (0x00=ADD, 0x08=OR, 0x10=ADC, 0x18=SBB,
//        0x20=AND, 0x28=SUB, 0x30=XOR, 0x38=CMP, 0x84=TEST)
// 8-bit uses base, 16/32/64-bit uses base+1.
static std::vector<u8> encode_alu_rr(u8 base, int sz, int dst, int src) {
  u8 modrm = 0xC0 | ((src & 7) << 3) | (dst & 7);
  bool need_rex = (sz == 64) || src >= 8 || dst >= 8;
  u8 rex = 0x40 | ((sz == 64) ? 8 : 0)
               | ((src >= 8) ? 4 : 0) | ((dst >= 8) ? 1 : 0);
  std::vector<u8> code;
  if (sz == 16) code.push_back(0x66);
  if (need_rex) code.push_back(rex);
  code.push_back(sz == 8 ? base : (u8)(base + 1));
  code.push_back(modrm);
  return code;
}

// Encode shift by CL: D2/D3 /digit
static std::vector<u8> encode_shift_cl(int digit, int sz, int reg) {
  u8 modrm = 0xC0 | (digit << 3) | (reg & 7);
  bool need_rex = (sz == 64) || reg >= 8;
  u8 rex = 0x40 | ((sz == 64) ? 8 : 0) | ((reg >= 8) ? 1 : 0);
  std::vector<u8> code;
  if (sz == 16) code.push_back(0x66);
  if (need_rex) code.push_back(rex);
  code.push_back(sz == 8 ? (u8)0xD2 : (u8)0xD3);
  code.push_back(modrm);
  return code;
}

// Encode unary: FE/FF /digit (INC/DEC) or F6/F7 /digit (NEG/NOT)
static std::vector<u8> encode_unary(u8 op8, u8 op, int digit, int sz, int reg) {
  u8 modrm = 0xC0 | (digit << 3) | (reg & 7);
  bool need_rex = (sz == 64) || reg >= 8;
  u8 rex = 0x40 | ((sz == 64) ? 8 : 0) | ((reg >= 8) ? 1 : 0);
  std::vector<u8> code;
  if (sz == 16) code.push_back(0x66);
  if (need_rex) code.push_back(rex);
  code.push_back(sz == 8 ? op8 : op);
  code.push_back(modrm);
  return code;
}

void add_systematic_tests(std::vector<TestCase> &tests) {
  std::string name;
  int sizes[] = {8, 16, 32, 64};
  const char *sz_sfx[] = {"8", "16", "32", "64"};
  std::string cat;

  auto add = [&](const std::string &n, std::vector<u8> code, ArchState init,
                 u64 mask) {
    tests.push_back({n, cat, std::move(code), init, mask});
  };

  // ================================================================
  // 1. ALU reg,reg — 8 ops × 4 sizes × NVALS × NVALS
  //    Tests all flag-setting ALU operations with boundary values.
  // ================================================================
  cat = "ALU reg,reg";
  struct AluOp { const char *name; u8 base; u64 mask; };
  AluOp alu_ops[] = {
    {"add", 0x00, FL_ALL}, {"or",  0x08, FL_NO_AF},
    {"adc", 0x10, FL_ALL}, {"sbb", 0x18, FL_ALL},
    {"and", 0x20, FL_NO_AF}, {"sub", 0x28, FL_ALL},
    {"xor", 0x30, FL_NO_AF}, {"cmp", 0x38, FL_ALL},
  };

  for (int si = 0; si < 4; si++) {
    for (auto &op : alu_ops) {
      name = std::format("ALU {} {}", op.name, sz_sfx[si]);
      cat = name;
      for (int i = 0; i < NVALS; i++) {
        for (int j = 0; j < NVALS; j++) {
          ArchState init = {.rax = VALS[i], .rbx = VALS[j], .rflags = 0x2};
          name = std::format("S {}{} {},{}", op.name, sz_sfx[si], i, j);
          add(name, encode_alu_rr(op.base, sizes[si], 0, 3),
              init, op.mask);
        }
      }
    }
  }

  // ADC/SBB with CF=1 — exercises carry-in path with all value pairs
  for (int oi : {2, 3}) {
    auto &op = alu_ops[oi];
    for (int si = 0; si < 4; si++) {
      name = std::format("ADC/SBB CF=1 {} {}", op.name, sz_sfx[si]);
      cat = name;
      for (int i = 0; i < NVALS; i++) {
        for (int j = 0; j < NVALS; j++) {
          ArchState init = {.rax = VALS[i], .rbx = VALS[j], .rflags = 0x3};  // CF=1
          name = std::format("S {}{} cf {},{}", op.name, sz_sfx[si], i, j);
          add(name, encode_alu_rr(op.base, sizes[si], 0, 3),
              init, op.mask);
        }
      }
    }
  }

  // TEST reg,reg — like AND but only sets flags, doesn't write result
  for (int si = 0; si < 4; si++) {
    name = std::format("TEST {}", sz_sfx[si]);
    cat = name;
    for (int i = 0; i < NVALS; i++) {
      for (int j = 0; j < NVALS; j++) {
        ArchState init = {.rax = VALS[i], .rbx = VALS[j], .rflags = 0x2};
        name = std::format("S test{} {},{}", sz_sfx[si], i, j);
        add(name, encode_alu_rr(0x84, sizes[si], 0, 3),
            init, FL_NO_AF);
      }
    }
  }

  // ================================================================
  // 2. Shifts by CL — 7 ops × 4 sizes × NSHIFTS × NVALS
  //    Tests shift/rotate with boundary counts and values.
  //    Check every defined flag, including preserved flags at zero count.
  // ================================================================
  struct ShiftOp { const char *name; int digit; bool needs_cf; };
  ShiftOp shift_ops[] = {
    {"shl", 4, false},
    {"shr", 5, false},
    {"sar", 7, false},
    {"rol", 0, false},
    {"ror", 1, false},
    {"rcl", 2, true},
    {"rcr", 3, true},
  };

  for (auto &op : shift_ops) {
    for (int si = 0; si < 4; si++) {
      cat = std::format("Shift {} {}", op.name, sz_sfx[si]);
      for (int ci = 0; ci < NSHIFTS; ci++) {
        for (int vi = 0; vi < NVALS; vi++) {
          ArchState init = {.rax = VALS[vi], .rcx = SHIFT_COUNTS[ci], .rflags = 0x2};
          name = std::format("S {}{} c{} {}", op.name, sz_sfx[si], (int)SHIFT_COUNTS[ci], vi);
          add(name, encode_shift_cl(op.digit, sizes[si], 0),
              init, shift_flags_mask(op.digit, sizes[si], SHIFT_COUNTS[ci]));
        }
      }
    }

    // RCL/RCR with CF=1 — carry is rotated through the value
    if (op.needs_cf) {
      for (int si = 0; si < 4; si++) {
        cat = std::format("Shift {} CF=1 {}", op.name, sz_sfx[si]);
        for (int ci = 0; ci < NSHIFTS; ci++) {
          for (int vi = 0; vi < NVALS; vi++) {
            ArchState init = {.rax = VALS[vi], .rcx = SHIFT_COUNTS[ci], .rflags = 0x3};  // CF=1
            name = std::format("S {}{} cf c{} {}", op.name, sz_sfx[si], (int)SHIFT_COUNTS[ci], vi);
            add(name, encode_shift_cl(op.digit, sizes[si], 0),
                init, shift_flags_mask(op.digit, sizes[si], SHIFT_COUNTS[ci]));
          }
        }
      }
    }
  }

  // ================================================================
  // 3. Unary ops — INC/DEC/NEG/NOT × 4 sizes × NVALS
  //    CF=1 initially to verify INC/DEC preserve carry flag.
  // ================================================================
  cat = "Unary ops";
  struct UnaryOp { const char *name; u8 op8; u8 op; int digit; u64 mask; };
  UnaryOp unary_ops[] = {
    {"inc", 0xFE, 0xFF, 0, FL_ALL},
    {"dec", 0xFE, 0xFF, 1, FL_ALL},
    {"neg", 0xF6, 0xF7, 3, FL_ALL},
    {"not", 0xF6, 0xF7, 2, FL_ALL},
  };

  for (auto &op : unary_ops) {
    for (int si = 0; si < 4; si++) {
      for (int vi = 0; vi < NVALS; vi++) {
        ArchState init = {.rax = VALS[vi], .rflags = 0x3};  // CF=1
        name = std::format("S {}{} {}", op.name, sz_sfx[si], vi);
        add(name, encode_unary(op.op8, op.op, op.digit, sizes[si], 0),
            init, op.mask);
      }
    }
  }

  // ================================================================
  // 4. MUL/IMUL 1-operand (64-bit) — NVALS × NVALS
  //    RAX * RBX -> RDX:RAX. Only CF and OF are defined.
  // ================================================================
  cat = "MUL";
  for (int i = 0; i < NVALS; i++) {
    for (int j = 0; j < NVALS; j++) {
      ArchState init = {.rax = VALS[i], .rbx = VALS[j], .rflags = 0x2};
      name = std::format("S mul64 {},{}", i, j);
      add(name, {0x48, 0xF7, 0xE3}, init, FL_CF_OF);
    }
  }

  cat = "IMUL";
  for (int i = 0; i < NVALS; i++) {
    for (int j = 0; j < NVALS; j++) {
      ArchState init = {.rax = VALS[i], .rbx = VALS[j], .rflags = 0x2};
      name = std::format("S imul64 {},{}", i, j);
      add(name, {0x48, 0xF7, 0xEB}, init, FL_CF_OF);
    }
  }

  // ================================================================
  // 5. DIV/IDIV (64-bit) — NVALS × NVALS (skip div-by-zero / overflow)
  //    RDX:RAX / RBX -> RAX=quot, RDX=rem. Arithmetic flags undefined.
  // ================================================================
  cat = "DIV";
  for (int i = 0; i < NVALS; i++) {
    for (int j = 0; j < NVALS; j++) {
      if (VALS[j] == 0) continue;

      // DIV: RDX=0 so quotient always fits (dividend < 2^64, divisor > 0)
      ArchState init = {.rax = VALS[i], .rbx = VALS[j], .rdx = 0, .rflags = 0x2};
      name = std::format("S div64 {},{}", i, j);
      add(name, {0x48, 0xF7, 0xF3}, init, FL_NONE);
    }
  }

  cat = "IDIV";
  for (int i = 0; i < NVALS; i++) {
    for (int j = 0; j < NVALS; j++) {
      if (VALS[j] == 0) continue;

      // IDIV: sign-extend RAX into RDX:RAX.
      // Skip INT64_MIN / -1 (quotient overflow -> #DE).
      i64 dividend = (i64)VALS[i];
      i64 divisor = (i64)VALS[j];
      if (dividend == (i64)0x8000000000000000 && divisor == -1)
        continue;

      ArchState init = {
        .rax = VALS[i],
        .rbx = VALS[j],
        .rdx = (dividend < 0) ? 0xFFFFFFFFFFFFFFFF : 0ULL,
        .rflags = 0x2,
      };
      name = std::format("S idiv64 {},{}", i, j);
      add(name, {0x48, 0xF7, 0xFB}, init, FL_NONE);
    }
  }

  // ================================================================
  // 6. Register variation — ADD r64,r64 with all non-RSP register pairs
  //    Catches REX.R / REX.B encoding bugs.
  // ================================================================
  cat = "Register variation";
  for (int dst = 0; dst < 16; dst++) {
    if (dst == 4) continue;  // skip RSP
    for (int src = 0; src < 16; src++) {
      if (src == 4 || src == dst) continue;
      ArchState init = {.rflags = 0x2};
      set_gpr(init, dst, 0x123456789ABCDEF0);
      set_gpr(init, src, 0x0FEDCBA987654321);
      name = std::format("S add {},{}", GPR_NAMES[dst], GPR_NAMES[src]);
      add(name, encode_alu_rr(0x00, 64, dst, src), init, FL_ALL);
    }
  }

  // ================================================================
  // 7. Random testing — supplement stratified tests with randomized
  //    inputs biased 75% toward interesting values.
  // ================================================================
  cat = "Random";
  std::mt19937_64 rng(12345);  // fixed seed for reproducibility
  for (int t = 0; t < 1000; t++) {
    int oi = rng() % 8;
    int si = rng() % 4;
    auto &op = alu_ops[oi];

    u64 a = (rng() % 4) ? VALS[rng() % NVALS] : rng();
    u64 b = (rng() % 4) ? VALS[rng() % NVALS] : rng();
    u64 fl = 0x2 | ((rng() & 1) ? FL_CF : 0ULL);
    ArchState init = {.rax = a, .rbx = b, .rflags = fl};

    name = std::format("S rand {}{} {}", op.name, sz_sfx[si], t);
    add(name, encode_alu_rr(op.base, sizes[si], 0, 3), init, op.mask);
  }
}

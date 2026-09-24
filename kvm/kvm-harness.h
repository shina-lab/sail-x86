#ifndef KVM_HARNESS_H
#define KVM_HARNESS_H

#include "sail_x86_model.h"
#include <array>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <format>
#include <linux/kvm.h>
#include <memory>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <random>
#include <string>
#include <unistd.h>
#include <asm/kvm.h>
#include <vector>

// lbits helpers for ZMM register access (full 512-bit)
inline void zmm_to_bytes(lbits val, u8 *out) {
  mpz_t tmp;
  mpz_init_set(tmp, *val.bits);
  for (int i = 0; i < 64; i++) {
    out[i] = (u8)(mpz_get_ui(tmp) & 0xFF);
    mpz_fdiv_q_2exp(tmp, tmp, 8);
  }
  mpz_clear(tmp);
}

inline void bytes_to_zmm(lbits *out, const u8 *in) {
  mpz_set_ui(*out->bits, 0);
  for (int i = 64; i > 0; i--) {
    mpz_mul_2exp(*out->bits, *out->bits, 8);
    mpz_add_ui(*out->bits, *out->bits, in[i - 1]);
  }
  out->len = 512;
}

// Legacy aliases
inline void xmm_to_bytes(lbits val, u8 *out) { zmm_to_bytes(val, out); }
inline void bytes_to_xmm(lbits *out, const u8 *in) { bytes_to_zmm(out, in); }

// Guest physical memory layout (identity-mapped, 2MB total):
//   0x00000 - 0x00FFF  PML4
//   0x01000 - 0x01FFF  PDPT
//   0x02000 - 0x02FFF  PD
//   0x03000 - 0x03FFF  GDT
//   0x10000 - 0x10FFF  Test code (instructions + HLT)
//   0x11000 - 0x11FFF  Test data (for memory operands)
//   0x1F000 - 0x1FFFF  Stack (RSP starts at 0x20000)
static constexpr u64 GUEST_MEM_SIZE = 2 * 1024 * 1024;
static constexpr u64 PML4_ADDR      = 0x00000;
static constexpr u64 PDPT_ADDR      = 0x01000;
static constexpr u64 PD_ADDR        = 0x02000;
static constexpr u64 GDT_ADDR       = 0x03000;
static constexpr u64 TSS_ADDR       = 0x03800;  // 64-bit TSS (104 bytes, within GDT page)
static constexpr u64 IDT_ADDR        = 0x04000;
static constexpr u64 HANDLER_ADDR    = 0x05000;
static constexpr u64 COMMON_HANDLER  = HANDLER_ADDR + 32 * 16;  // 0x05200
static constexpr u64 CODE_ADDR      = 0x10000;
static constexpr u64 DATA_ADDR      = 0x11000;
static constexpr u64 FAULT_INFO_ADDR = 0x12000;
static constexpr u64 STACK_TOP      = 0x20000;

// RFLAGS bit positions
static constexpr u64 FL_CF = 0x001;
static constexpr u64 FL_PF = 0x004;
static constexpr u64 FL_AF = 0x010;
static constexpr u64 FL_ZF = 0x040;
static constexpr u64 FL_SF = 0x080;
static constexpr u64 FL_DF = 0x400;
static constexpr u64 FL_OF = 0x800;
static constexpr u64 FL_ARITH = FL_CF | FL_PF | FL_AF | FL_ZF | FL_SF | FL_OF;
static constexpr u64 FL_ALL = FL_ARITH | FL_DF;
static constexpr u64 FL_NO_AF = FL_ALL & ~FL_AF;
static constexpr u64 FL_NO_AF_OF = FL_ALL & ~(FL_AF | FL_OF);
static constexpr u64 FL_CF_OF = FL_CF | FL_OF;
static constexpr u64 FL_ZF_ONLY = FL_ZF;
static constexpr u64 FL_CF_ZF = FL_CF | FL_ZF;
static constexpr u64 FL_NONE = 0;

inline u64 condition_flags_mask(unsigned cc) {
  static constexpr u64 masks[] = {
    FL_OF, FL_CF, FL_ZF, FL_CF | FL_ZF,
    FL_SF, FL_PF, FL_SF | FL_OF, FL_ZF | FL_SF | FL_OF,
  };
  assert(cc < 16);
  return masks[cc / 2];
}

inline u64 shift_input_flags_mask(int digit, int width, unsigned count) {
  if (digit != 2 && digit != 3) return 0;
  count &= width == 64 ? 63 : 31;
  if (width < 32) count %= width + 1;
  return count ? FL_CF : 0;
}

// The arithmetic flags defined by a shift/rotate depend on the input count.
// Other flags, including those an instruction preserves, are always checked.
inline u64 shift_flags_mask(int digit, int width, unsigned count) {
  count &= width == 64 ? 63 : 31;
  if (digit == 2 || digit == 3) {
    if (width < 32 && count % (width + 1) == 0) return FL_ALL;
  }
  if (count == 0) return FL_ALL;
  u64 mask = count == 1 ? FL_ALL : FL_ALL & ~FL_OF;
  if (digit >= 4) {
    mask &= ~FL_AF;
    if (digit != 7 && count >= unsigned(width)) mask &= ~FL_CF;
  }
  return mask;
}

// 512-bit ZMM value stored as eight 64-bit quadwords (little-endian).
// Union provides .lo/.hi aliases for backward compatibility with XMM-only tests.
struct ZmmVal {
  union {
    u64 q[8];
    struct { u64 lo, hi; };  // aliases for q[0], q[1]
  };
  // memcpy permits element-sized writes without aliasing the u64 storage.
  template <typename T> void set(unsigned index, T value) {
    assert((index + 1) * sizeof(T) <= sizeof(q));
    memcpy(reinterpret_cast<u8 *>(q) + index * sizeof(T), &value, sizeof(T));
  }
  bool operator==(const ZmmVal &o) const { return memcmp(q, o.q, 64) == 0; }
  bool operator!=(const ZmmVal &o) const { return !(*this == o); }
  bool is_zero() const {
    for (int i = 0; i < 8; i++) if (q[i]) return false;
    return true;
  }
};
using XmmVal = ZmmVal;  // backward compat

inline ZmmVal xmm_from_f32(float a, float b, float c, float d) {
  ZmmVal v = {};
  u32 parts[4];
  memcpy(&parts[0], &a, 4);
  memcpy(&parts[1], &b, 4);
  memcpy(&parts[2], &c, 4);
  memcpy(&parts[3], &d, 4);
  v.lo = (u64)parts[0] | ((u64)parts[1] << 32);
  v.hi = (u64)parts[2] | ((u64)parts[3] << 32);
  return v;
}

inline ZmmVal xmm_from_f64(double a, double b) {
  ZmmVal v = {};
  memcpy(&v.lo, &a, 8);
  memcpy(&v.hi, &b, 8);
  return v;
}

inline ZmmVal xmm_from_u64(u64 lo, u64 hi) {
  ZmmVal v = {};
  v.lo = lo;
  v.hi = hi;
  return v;
}

inline ZmmVal xmm_from_u32(u32 a, u32 b, u32 c, u32 d) {
  ZmmVal v = {};
  v.lo = (u64)a | ((u64)b << 32);
  v.hi = (u64)c | ((u64)d << 32);
  return v;
}

// Changed only while constructing test cases. Explicit initializers (including
// zero) override this background; execution uses the resulting concrete state.
inline u64 initial_register_fill = 0;

// Only arithmetic status flags follow the register background. Control flags
// must not enable single stepping, interrupts, or a different execution mode.
// A test overrides just the status flags its instruction sequence consumes.
inline u64 initial_flags(u64 inputs = 0, u64 values = 0) {
  assert((inputs & ~FL_ARITH) == 0);
  return 0x2 | (initial_register_fill & FL_ARITH & ~inputs) | (values & inputs);
}

inline std::array<ZmmVal, 32> initial_zmm_values() {
  std::array<ZmmVal, 32> values;
  for (auto &reg : values)
    for (u64 &word : reg.q)
      word = initial_register_fill;
  return values;
}

inline std::array<u64, 8> initial_kreg_values() {
  std::array<u64, 8> values;
  values.fill(initial_register_fill);
  return values;
}

// Architectural state we compare between KVM and Sail.
struct ArchState {
  u64 rax = initial_register_fill;
  u64 rbx = initial_register_fill;
  u64 rcx = initial_register_fill;
  u64 rdx = initial_register_fill;
  u64 rsi = initial_register_fill;
  u64 rdi = initial_register_fill;
  u64 rbp = initial_register_fill;
  // RSP=0 selects STACK_TOP in the runners, so keep this sentinel unchanged.
  u64 rsp = 0;
  u64 r8 = initial_register_fill;
  u64 r9 = initial_register_fill;
  u64 r10 = initial_register_fill;
  u64 r11 = initial_register_fill;
  u64 r12 = initial_register_fill;
  u64 r13 = initial_register_fill;
  u64 r14 = initial_register_fill;
  u64 r15 = initial_register_fill;
  u64 rip = 0;
  u64 rflags = initial_flags();
  std::array<ZmmVal, 32> xmm = initial_zmm_values(); // full 512-bit ZMM registers
  u32 mxcsr = 0x1F80;   // default MXCSR
  std::array<u64, 8> kregs = initial_kreg_values(); // AVX-512 opmask registers k0-k7
  u64 dr[4] = {};        // DR0-DR3 breakpoint addresses (initial state only)
  u64 dr6 = 0xFFFF0FF0;  // DR6: reset value as initial state; compared after the run
  u64 dr7 = 0x400;       // DR7: reset value as initial state; compared after the run

  void print(const char *label) const {
    fprintf(stderr, "  %s:\n", label);
    fprintf(stderr, "    RAX=%016lx RBX=%016lx RCX=%016lx RDX=%016lx\n",
            rax, rbx, rcx, rdx);
    fprintf(stderr, "    RSI=%016lx RDI=%016lx RBP=%016lx RSP=%016lx\n",
            rsi, rdi, rbp, rsp);
    fprintf(stderr, "    R8 =%016lx R9 =%016lx R10=%016lx R11=%016lx\n",
            r8, r9, r10, r11);
    fprintf(stderr, "    R12=%016lx R13=%016lx R14=%016lx R15=%016lx\n",
            r12, r13, r14, r15);
    fprintf(stderr, "    RIP=%016lx RFLAGS=%016lx MXCSR=%08x\n", rip, rflags, mxcsr);
    for (int i = 0; i < 32; i++) {
      if (!xmm[i].is_zero()) {
        bool upper = false;
        for (int j = 2; j < 8; j++) if (xmm[i].q[j]) upper = true;
        if (upper)
          fprintf(stderr, "    ZMM%-2d=%016lx%016lx%016lx%016lx%016lx%016lx%016lx%016lx\n",
                  i, xmm[i].q[7], xmm[i].q[6], xmm[i].q[5], xmm[i].q[4],
                  xmm[i].q[3], xmm[i].q[2], xmm[i].q[1], xmm[i].q[0]);
        else
          fprintf(stderr, "    XMM%-2d=%016lx%016lx\n", i, xmm[i].hi, xmm[i].lo);
      }
    }
  }

  bool compare(const ArchState &other, u64 flags_mask = FL_ALL,
               bool cmp_mxcsr = false, double approx_rel_tol = 0,
               int approx_elem_bits = 0, int approx_result_bits = 0,
               unsigned approx_reg = 0) const {
    // A test may exclude undefined arithmetic flags, but cannot hide changes
    // to the rest of RFLAGS (DF, IF, TF, IOPL, etc.).
    flags_mask |= ~FL_ARITH;
    if (approx_rel_tol > 0) {
      assert(approx_reg < 32);
      assert(approx_elem_bits == 16 || approx_elem_bits == 32 || approx_elem_bits == 64);
      assert(approx_result_bits > 0 && approx_result_bits <= 512);
      assert(approx_result_bits % approx_elem_bits == 0);
    }
    bool ok = true;
    auto cmp = [&](const std::string &name, u64 a, u64 b) {
      if (a != b) {
        fprintf(stderr, "  MISMATCH %s: kvm=%016lx sail=%016lx\n", name.c_str(), a, b);
        ok = false;
      }
    };
    cmp("RAX", rax, other.rax);
    cmp("RBX", rbx, other.rbx);
    cmp("RCX", rcx, other.rcx);
    cmp("RDX", rdx, other.rdx);
    cmp("RSI", rsi, other.rsi);
    cmp("RDI", rdi, other.rdi);
    cmp("RBP", rbp, other.rbp);
    cmp("RSP", rsp, other.rsp);
    cmp("R8",  r8,  other.r8);
    cmp("R9",  r9,  other.r9);
    cmp("R10", r10, other.r10);
    cmp("R11", r11, other.r11);
    cmp("R12", r12, other.r12);
    cmp("R13", r13, other.r13);
    cmp("R14", r14, other.r14);
    cmp("R15", r15, other.r15);
    cmp("RIP", rip, other.rip);
    cmp("RFLAGS", rflags & flags_mask, other.rflags & flags_mask);
    for (int i = 0; i < 32; i++) {
      bool zmm_ok = true;
      if (approx_rel_tol > 0 && unsigned(i) == approx_reg) {
        // Only computed elements get a tolerance. Copied elements, upper
        // bits, and all other registers must match exactly.
        int n_elems = approx_result_bits / approx_elem_bits;
        const u8 *a_bytes = reinterpret_cast<const u8 *>(xmm[i].q);
        const u8 *b_bytes = reinterpret_cast<const u8 *>(other.xmm[i].q);
        for (int e = 0; e < n_elems; e++) {
          int offset = e * (approx_elem_bits / 8);
          if (memcmp(a_bytes + offset, b_bytes + offset, approx_elem_bits / 8) == 0)
            continue;
          double a_val, b_val;
          if (approx_elem_bits == 16) {
            _Float16 a_h, b_h;
            memcpy(&a_h, (u8 *)xmm[i].q + e * 2, 2);
            memcpy(&b_h, (u8 *)other.xmm[i].q + e * 2, 2);
            a_val = (float)a_h; b_val = (float)b_h;
          } else if (approx_elem_bits == 32) {
            u32 a_u, b_u;
            memcpy(&a_u, (u8 *)xmm[i].q + e * 4, 4);
            memcpy(&b_u, (u8 *)other.xmm[i].q + e * 4, 4);
            float a_f, b_f;
            memcpy(&a_f, &a_u, 4); memcpy(&b_f, &b_u, 4);
            a_val = a_f; b_val = b_f;
          } else {
            memcpy(&a_val, (u8 *)xmm[i].q + e * 8, 8);
            memcpy(&b_val, (u8 *)other.xmm[i].q + e * 8, 8);
          }
          // Relative error does not justify changing signed zero, infinity,
          // or a NaN. In particular, NaN must not make a mismatch pass.
          if (!std::isfinite(a_val) || !std::isfinite(b_val) || a_val == 0 || b_val == 0) {
            zmm_ok = false;
            break;
          }
          double rel_err = fabs(a_val - b_val) / fabs(a_val);
          if (rel_err > approx_rel_tol) { zmm_ok = false; break; }
        }
        int exact_offset = approx_result_bits / 8;
        if (memcmp(a_bytes + exact_offset, b_bytes + exact_offset, 64 - exact_offset) != 0)
          zmm_ok = false;
      } else {
        zmm_ok = (xmm[i] == other.xmm[i]);
      }
      if (!zmm_ok) {
        fprintf(stderr, "  MISMATCH ZMM%d: kvm=%016lx%016lx%016lx%016lx%016lx%016lx%016lx%016lx\n"
                "                 sail=%016lx%016lx%016lx%016lx%016lx%016lx%016lx%016lx\n",
                i,
                xmm[i].q[7], xmm[i].q[6], xmm[i].q[5], xmm[i].q[4],
                xmm[i].q[3], xmm[i].q[2], xmm[i].q[1], xmm[i].q[0],
                other.xmm[i].q[7], other.xmm[i].q[6], other.xmm[i].q[5], other.xmm[i].q[4],
                other.xmm[i].q[3], other.xmm[i].q[2], other.xmm[i].q[1], other.xmm[i].q[0]);
        ok = false;
      }
    }
    if (cmp_mxcsr) {
      // Compare MXCSR excluding DAZ (bit 6) and FTZ (bit 15) and exception flags (bits 0-5)
      u32 mask = 0x7F80;  // rounding mode + exception masks
      if ((mxcsr & mask) != (other.mxcsr & mask)) {
        fprintf(stderr, "  MISMATCH MXCSR: kvm=%08x sail=%08x\n", mxcsr, other.mxcsr);
        ok = false;
      }
    }
    for (int i = 0; i < 8; i++) {
      if (kregs[i] != other.kregs[i]) {
        fprintf(stderr, "  MISMATCH K%d: kvm=%016lx sail=%016lx\n",
                i, kregs[i], other.kregs[i]);
        ok = false;
      }
    }
    // Debug registers: DR6 under its status bits (B0-B3, BD, BS, BT; the
    // same mask as DR6_CMP_MASK below), DR7 in full.
    if ((dr6 ^ other.dr6) & 0xE00Full) {
      fprintf(stderr, "  MISMATCH DR6: kvm=%016lx sail=%016lx\n", dr6, other.dr6);
      ok = false;
    }
    cmp("DR7", dr7, other.dr7);
    return ok;
  }
};

// Select the inputs of one instruction form from a shared operand pool.
// Control state (including the valid stack pointer) is kept separately.
inline ArchState with_gpr_inputs(ArchState values,
                                std::initializer_list<u64 ArchState::*> inputs) {
  ArchState background;
  for (auto reg : {&ArchState::rax, &ArchState::rbx, &ArchState::rcx,
                  &ArchState::rdx, &ArchState::rsi, &ArchState::rdi,
                  &ArchState::rbp, &ArchState::r8, &ArchState::r9,
                  &ArchState::r10, &ArchState::r11, &ArchState::r12,
                  &ArchState::r13, &ArchState::r14, &ArchState::r15}) {
    bool input = false;
    for (auto selected : inputs) input |= selected == reg;
    if (!input) values.*reg = background.*reg;
  }
  return values;
}

inline ArchState with_vector_inputs(ArchState values, u32 inputs) {
  auto vectors = values.xmm;
  values.xmm = ArchState{}.xmm;
  for (unsigned i = 0; i < 32; i++)
    if (inputs & (1U << i)) values.xmm[i] = vectors[i];
  return values;
}

inline ArchState with_flag_inputs(ArchState values, u64 inputs) {
  values.rflags = (values.rflags & ~FL_ARITH) | initial_flags(inputs, values.rflags);
  return values;
}

// XSAVE reads every enabled vector/opmask component named by EDX:EAX,
// even registers not named in its encoding. Initialize precisely those bits.
inline ArchState with_xsave_vector_inputs(ArchState values, u64 mask) {
  for (unsigned reg = 0; reg < 32; reg++) {
    for (unsigned q = 0; q < 8; q++) {
      unsigned component = reg >= 16 ? 7 : q < 2 ? 1 : q < 4 ? 2 : 6;
      if (mask & (1ULL << component)) values.xmm[reg].q[q] = 0;
    }
  }
  if (mask & (1ULL << 5)) values.kregs.fill(0);
  return values;
}

// Fault information captured from exception handlers.
struct FaultInfo {
  bool faulted = false;
  int vector = -1;
  u64 error_code = 0;
  u64 faulting_rip = 0;  // RIP the CPU pushed: the instruction for a fault, the next one for a trap
  u64 cr2 = 0;  // CR2 after the fault (meaningful for #PF; 0 otherwise)
  u64 dr6 = 0;  // DR6 after the fault (meaningful for #DB; compared under DR6_CMP_MASK)
  u64 dr7 = 0;  // DR7 after the fault (general detect clears GD)
  u64 rflags_image = 0;  // RFLAGS as pushed for the handler (compared under RFLAGS_IMAGE_MASK)
};

// DR6 bits compared between KVM and the model: B0-B3, BD, BS, BT.  Bit 11
// (BLD) and bit 16 (RTM) are vendor- and hypervisor-dependent constants.
static constexpr u64 DR6_CMP_MASK = 0xE00F;

// Pushed-RFLAGS bits compared: CF PF AF ZF SF TF IF DF OF and RF (bit 16),
// whose value in the image encodes the fault/trap distinction.
static constexpr u64 RFLAGS_IMAGE_MASK = 0x10FD5;

struct TestCase {
  std::string name;
  std::string category;
  std::vector<u8> code;
  ArchState initial;
  u64 flags_mask = FL_ALL;       // defined arithmetic flags; other RFLAGS bits always compared
  u32 xmm_mask = 0;              // legacy positional field; all ZMM registers are compared
  bool cmp_mxcsr = false;
  std::vector<u8> init_data;       // placed at DATA_ADDR
  size_t compare_data_len = 0;     // bytes at DATA_ADDR to compare after execution
  bool expect_fault = false;       // test expects an exception, not normal HLT
  int expected_vector = -1;        // expected exception vector (-1 = any)
  u8 kreg_mask = 0;              // legacy positional field; all k-registers are compared
  u64 xcr0_override = 0;          // if nonzero, override XCR0 for this test
  u64 cr4_override = 0;           // if nonzero, override CR4 for this test
  double approx_rel_tol = 0;      // tolerance for computed results of reciprocal/rsqrt instructions
  int approx_elem_bits = 0;       // element size for approximate comparison (32 or 64)
  bool compat_mode = false;       // execute test code in 32-bit compatibility mode
  bool enable_paging = false;     // give the Sail model the guest's identity
                                  // paging (the KVM guest always pages); for
                                  // tests that probe translation and #PF
  u64 rflags_image_ignore = 0;    // pushed-RFLAGS bits not compared for this
                                  // test (a hypervisor artifact, with the
                                  // reason at the test)
  int approx_result_bits = 0;    // low computed bits; remaining bits must match exactly
  unsigned approx_reg = 0;       // only this destination register gets a tolerance
  std::vector<std::pair<u32, u64>> msrs;  // MSRs loaded on both sides before the run
                                          // (IA32_EFER goes through the KVM segment state)
  bool system_mode = false;      // the model delivers exceptions through a mirror of the
                                 // guest's IDT; SYSCALL/SYSRET/SYSENTER/SYSEXIT need the
                                 // model's system-mode paths
};

// Test registration functions (defined in separate kvm-tests-*.cpp files)
void add_systematic_tests(std::vector<TestCase> &tests);
void add_baseline_tests(std::vector<TestCase> &tests);
void add_sse_tests(std::vector<TestCase> &tests);
void add_misc_instruction_tests(std::vector<TestCase> &tests);
void add_x87_avx_tests(std::vector<TestCase> &tests);
void add_x87_compat_tests(std::vector<TestCase> &tests);
void add_fp_edge_tests(std::vector<TestCase> &tests);
void add_encoding_tests(std::vector<TestCase> &tests);
void add_exception_tests(std::vector<TestCase> &tests);
void add_mmx_tests(std::vector<TestCase> &tests);
void add_feature_tests(std::vector<TestCase> &tests);
void add_compat_tests(std::vector<TestCase> &tests);
void add_xsave_tests(std::vector<TestCase> &tests);
void add_avx_fp_tests(std::vector<TestCase> &tests);
void add_avx_int_tests(std::vector<TestCase> &tests);
void add_avx_shift_tests(std::vector<TestCase> &tests);
void add_avx_fma_tests(std::vector<TestCase> &tests);
void add_avx_scalar_tests(std::vector<TestCase> &tests);
void add_avx_narrow_tests(std::vector<TestCase> &tests);
void add_avx_cmp_tests(std::vector<TestCase> &tests);
void add_avx_perm_tests(std::vector<TestCase> &tests);
void add_avx_conv_tests(std::vector<TestCase> &tests);
void add_avx_special_tests(std::vector<TestCase> &tests);
void add_avx_mov_tests(std::vector<TestCase> &tests);
void add_avx_vex_only_tests(std::vector<TestCase> &tests);
void add_avx_hi16_tests(std::vector<TestCase> &tests);
void add_avx_fp16_tests(std::vector<TestCase> &tests);
void add_system_tests(std::vector<TestCase> &tests);

#endif // KVM_HARNESS_H

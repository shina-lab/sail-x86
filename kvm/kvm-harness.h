#ifndef KVM_HARNESS_H
#define KVM_HARNESS_H

#include "sail_x86_model.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <format>
#include <linux/kvm.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <random>
#include <string>
#include <unistd.h>
#include <asm/kvm.h>
#include <vector>

// lbits helpers for XMM register access
inline void xmm_to_bytes(lbits val, u8 *out) {
  mpz_t tmp;
  mpz_init_set(tmp, *val.bits);
  for (int i = 0; i < 16; i++) {
    out[i] = (u8)(mpz_get_ui(tmp) & 0xFF);
    mpz_fdiv_q_2exp(tmp, tmp, 8);
  }
  mpz_clear(tmp);
}

inline void bytes_to_xmm(lbits *out, const u8 *in) {
  mpz_set_ui(*out->bits, 0);
  for (int i = 16; i > 0; i--) {
    mpz_mul_2exp(*out->bits, *out->bits, 8);
    mpz_add_ui(*out->bits, *out->bits, in[i - 1]);
  }
  out->len = 512;  // ZMM registers are 512-bit; upper bits are implicitly zero
}

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
static constexpr u64 FL_ALL = FL_CF | FL_PF | FL_AF | FL_ZF | FL_SF | FL_DF | FL_OF;
static constexpr u64 FL_NO_AF = FL_ALL & ~FL_AF;
static constexpr u64 FL_NO_AF_OF = FL_ALL & ~(FL_AF | FL_OF);
static constexpr u64 FL_CF_OF = FL_CF | FL_OF;
static constexpr u64 FL_ZF_ONLY = FL_ZF;
static constexpr u64 FL_CF_ZF = FL_CF | FL_ZF;
static constexpr u64 FL_NONE = 0;

// 128-bit XMM value stored as two 64-bit halves (little-endian).
struct XmmVal {
  u64 lo = 0, hi = 0;
  bool operator==(const XmmVal &o) const { return lo == o.lo && hi == o.hi; }
  bool operator!=(const XmmVal &o) const { return !(*this == o); }
};

inline XmmVal xmm_from_f32(float a, float b, float c, float d) {
  XmmVal v;
  u32 parts[4];
  memcpy(&parts[0], &a, 4);
  memcpy(&parts[1], &b, 4);
  memcpy(&parts[2], &c, 4);
  memcpy(&parts[3], &d, 4);
  v.lo = (u64)parts[0] | ((u64)parts[1] << 32);
  v.hi = (u64)parts[2] | ((u64)parts[3] << 32);
  return v;
}

inline XmmVal xmm_from_f64(double a, double b) {
  XmmVal v;
  memcpy(&v.lo, &a, 8);
  memcpy(&v.hi, &b, 8);
  return v;
}

inline XmmVal xmm_from_u64(u64 lo, u64 hi) {
  return {lo, hi};
}

inline XmmVal xmm_from_u32(u32 a, u32 b, u32 c, u32 d) {
  XmmVal v;
  v.lo = (u64)a | ((u64)b << 32);
  v.hi = (u64)c | ((u64)d << 32);
  return v;
}

// Architectural state we compare between KVM and Sail.
struct ArchState {
  u64 rax = 0;
  u64 rbx = 0;
  u64 rcx = 0;
  u64 rdx = 0;
  u64 rsi = 0;
  u64 rdi = 0;
  u64 rbp = 0;
  u64 rsp = 0;
  u64 r8 = 0;
  u64 r9 = 0;
  u64 r10 = 0;
  u64 r11 = 0;
  u64 r12 = 0;
  u64 r13 = 0;
  u64 r14 = 0;
  u64 r15 = 0;
  u64 rip = 0;
  u64 rflags = 0;
  XmmVal xmm[16] = {};
  u32 mxcsr = 0x1F80;  // default MXCSR
  u64 kregs[8] = {};    // AVX-512 opmask registers k0-k7

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
    for (int i = 0; i < 16; i++) {
      if (xmm[i].lo || xmm[i].hi)
        fprintf(stderr, "    XMM%-2d=%016lx%016lx\n", i, xmm[i].hi, xmm[i].lo);
    }
  }

  bool compare(const ArchState &other, u64 flags_mask, u32 xmm_mask,
               bool cmp_mxcsr, u8 kreg_mask = 0) const {
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
    // Skip RIP: KVM advances past HLT, Sail points at it.
    cmp("RFLAGS", rflags & flags_mask, other.rflags & flags_mask);
    for (int i = 0; i < 16; i++) {
      if (xmm_mask & (1u << i)) {
        if (xmm[i] != other.xmm[i]) {
          fprintf(stderr, "  MISMATCH XMM%d: kvm=%016lx%016lx sail=%016lx%016lx\n",
                  i, xmm[i].hi, xmm[i].lo, other.xmm[i].hi, other.xmm[i].lo);
          ok = false;
        }
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
      if (kreg_mask & (1u << i)) {
        if (kregs[i] != other.kregs[i]) {
          fprintf(stderr, "  MISMATCH K%d: kvm=%016lx sail=%016lx\n",
                  i, kregs[i], other.kregs[i]);
          ok = false;
        }
      }
    }
    return ok;
  }
};

// Fault information captured from exception handlers.
struct FaultInfo {
  bool faulted = false;
  int vector = -1;
  u64 error_code = 0;
  u64 faulting_rip = 0;
};

struct TestCase {
  std::string name;
  std::string category;
  std::vector<u8> code;
  ArchState initial;
  u64 flags_mask;
  u32 xmm_mask = 0;               // bitmask of XMM registers to compare
  bool cmp_mxcsr = false;
  std::vector<u8> init_data;       // placed at DATA_ADDR
  size_t compare_data_len = 0;     // bytes at DATA_ADDR to compare after execution
  bool expect_fault = false;       // test expects an exception, not normal HLT
  int expected_vector = -1;        // expected exception vector (-1 = any)
  u8 kreg_mask = 0;               // bitmask of k-registers to compare (k0-k7)
  u64 xcr0_override = 0;          // if nonzero, override XCR0 for this test
  u64 cr4_override = 0;           // if nonzero, override CR4 for this test
  bool compat_mode = false;       // execute test code in 32-bit compatibility mode
};

// Test registration functions (defined in separate kvm-tests-*.cpp files)
void add_systematic_tests(std::vector<TestCase> &tests);
void add_baseline_tests(std::vector<TestCase> &tests);
void add_sse_tests(std::vector<TestCase> &tests);
void add_misc_instruction_tests(std::vector<TestCase> &tests);
void add_x87_avx_tests(std::vector<TestCase> &tests);
void add_fp_edge_tests(std::vector<TestCase> &tests);
void add_encoding_tests(std::vector<TestCase> &tests);
void add_exception_tests(std::vector<TestCase> &tests);
void add_vex_tests(std::vector<TestCase> &tests);
void add_evex_tests(std::vector<TestCase> &tests);
void add_evex_tests_2(std::vector<TestCase> &tests);
void add_mmx_tests(std::vector<TestCase> &tests);
void add_feature_tests(std::vector<TestCase> &tests);
void add_compat_tests(std::vector<TestCase> &tests);
void add_xsave_tests(std::vector<TestCase> &tests);

#endif // KVM_HARNESS_H

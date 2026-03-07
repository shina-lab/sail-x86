// KVM-based differential test harness for sail-x86.
//
// Sets up a KVM VM in 64-bit long mode, runs test instruction sequences,
// and compares the resulting architectural state against the Sail model.

#include "sail_x86_model.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <linux/kvm.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <random>
#include <string>
#include <unistd.h>
#include <asm/kvm.h>
#include <vector>

// lbits helpers for XMM register access
static void xmm_to_bytes(lbits val, u8 *out) {
  mpz_t tmp;
  mpz_init_set(tmp, *val.bits);
  for (int i = 0; i < 16; i++) {
    out[i] = (u8)(mpz_get_ui(tmp) & 0xFF);
    mpz_fdiv_q_2exp(tmp, tmp, 8);
  }
  mpz_clear(tmp);
}

static void bytes_to_xmm(lbits *out, const u8 *in) {
  mpz_set_ui(*out->bits, 0);
  for (int i = 16; i > 0; i--) {
    mpz_mul_2exp(*out->bits, *out->bits, 8);
    mpz_add_ui(*out->bits, *out->bits, in[i - 1]);
  }
  out->len = 128;
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
static constexpr u64 CODE_ADDR      = 0x10000;
static constexpr u64 DATA_ADDR      = 0x11000;
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

static XmmVal xmm_from_f32(float a, float b, float c, float d) {
  XmmVal v;
  u32 parts[4];
  memcpy(&parts[0], &a, 4); memcpy(&parts[1], &b, 4);
  memcpy(&parts[2], &c, 4); memcpy(&parts[3], &d, 4);
  v.lo = (u64)parts[0] | ((u64)parts[1] << 32);
  v.hi = (u64)parts[2] | ((u64)parts[3] << 32);
  return v;
}

static XmmVal xmm_from_f64(double a, double b) {
  XmmVal v;
  memcpy(&v.lo, &a, 8);
  memcpy(&v.hi, &b, 8);
  return v;
}

static XmmVal xmm_from_u64(u64 lo, u64 hi) {
  return {lo, hi};
}

static XmmVal xmm_from_u32(u32 a, u32 b, u32 c, u32 d) {
  XmmVal v;
  v.lo = (u64)a | ((u64)b << 32);
  v.hi = (u64)c | ((u64)d << 32);
  return v;
}

// Architectural state we compare between KVM and Sail.
struct ArchState {
  u64 rax, rbx, rcx, rdx, rsi, rdi, rbp, rsp;
  u64 r8, r9, r10, r11, r12, r13, r14, r15;
  u64 rip;
  u64 rflags;
  XmmVal xmm[16];
  u32 mxcsr = 0x1F80;  // default MXCSR

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
               bool cmp_mxcsr) const {
    bool ok = true;
    auto cmp = [&](const char *name, u64 a, u64 b) {
      if (a != b) {
        fprintf(stderr, "  MISMATCH %s: kvm=%016lx sail=%016lx\n", name, a, b);
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
    return ok;
  }
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
};

// ---- KVM VM ----

struct KvmVm {
  int kvm_fd = -1;
  int vm_fd = -1;
  int vcpu_fd = -1;
  struct kvm_run *run = nullptr;
  u8 *guest_mem = nullptr;

  ~KvmVm() {
    if (run) munmap(run, sizeof(kvm_run));
    if (guest_mem) munmap(guest_mem, GUEST_MEM_SIZE);
    if (vcpu_fd >= 0) close(vcpu_fd);
    if (vm_fd >= 0) close(vm_fd);
    if (kvm_fd >= 0) close(kvm_fd);
  }

  bool init() {
    kvm_fd = open("/dev/kvm", O_RDWR | O_CLOEXEC);
    if (kvm_fd < 0) { perror("/dev/kvm"); return false; }

    int api_ver = ioctl(kvm_fd, KVM_GET_API_VERSION, 0);
    if (api_ver != 12) {
      fprintf(stderr, "KVM API version %d (expected 12)\n", api_ver);
      return false;
    }

    vm_fd = ioctl(kvm_fd, KVM_CREATE_VM, 0UL);
    if (vm_fd < 0) { perror("KVM_CREATE_VM"); return false; }

    guest_mem = (u8 *)mmap(nullptr, GUEST_MEM_SIZE,
                           PROT_READ | PROT_WRITE,
                           MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (guest_mem == MAP_FAILED) { perror("mmap guest"); return false; }

    struct kvm_userspace_memory_region region = {};
    region.slot = 0;
    region.guest_phys_addr = 0;
    region.memory_size = GUEST_MEM_SIZE;
    region.userspace_addr = (u64)guest_mem;
    if (ioctl(vm_fd, KVM_SET_USER_MEMORY_REGION, &region) < 0) {
      perror("KVM_SET_USER_MEMORY_REGION");
      return false;
    }

    vcpu_fd = ioctl(vm_fd, KVM_CREATE_VCPU, 0UL);
    if (vcpu_fd < 0) { perror("KVM_CREATE_VCPU"); return false; }

    int mmap_size = ioctl(kvm_fd, KVM_GET_VCPU_MMAP_SIZE, 0);
    if (mmap_size < 0) { perror("KVM_GET_VCPU_MMAP_SIZE"); return false; }
    run = (struct kvm_run *)mmap(nullptr, mmap_size, PROT_READ | PROT_WRITE,
                                 MAP_SHARED, vcpu_fd, 0);
    if (run == MAP_FAILED) { perror("mmap vcpu"); return false; }

    setup_long_mode();
    return true;
  }

  void setup_long_mode() {
    memset(guest_mem, 0, GUEST_MEM_SIZE);

    // Identity-map first 2MB with a single 2MB page.
    u64 *pml4 = (u64 *)(guest_mem + PML4_ADDR);
    pml4[0] = PDPT_ADDR | 0x3;

    u64 *pdpt = (u64 *)(guest_mem + PDPT_ADDR);
    pdpt[0] = PD_ADDR | 0x3;

    u64 *pd = (u64 *)(guest_mem + PD_ADDR);
    pd[0] = 0x0 | 0x83;  // 2MB page, present + writable + PS

    // GDT: null, 64-bit code, data
    u64 *gdt = (u64 *)(guest_mem + GDT_ADDR);
    gdt[0] = 0;
    gdt[1] = 0x00AF9A000000FFFF;  // 64-bit code
    gdt[2] = 0x00CF92000000FFFF;  // data

    struct kvm_sregs sregs;
    ioctl(vcpu_fd, KVM_GET_SREGS, &sregs);

    sregs.cr0 = 0x80000011;  // PE + PG + ET (EM=0, TS=0 for SSE)
    sregs.cr4 = 0x620;       // PAE + OSFXSR + OSXMMEXCPT
    sregs.efer = 0x500;      // LME + LMA
    sregs.cr3 = PML4_ADDR;

    sregs.gdt.base = GDT_ADDR;
    sregs.gdt.limit = 3 * 8 - 1;

    // Code segment
    sregs.cs = {};
    sregs.cs.base = 0;
    sregs.cs.limit = 0xFFFFFFFF;
    sregs.cs.selector = 0x08;
    sregs.cs.type = 0xA;
    sregs.cs.present = 1;
    sregs.cs.s = 1;
    sregs.cs.l = 1;
    sregs.cs.g = 1;

    // Data segments
    auto setup_ds = [](struct kvm_segment &seg) {
      seg = {};
      seg.base = 0;
      seg.limit = 0xFFFFFFFF;
      seg.selector = 0x10;
      seg.type = 0x2;
      seg.present = 1;
      seg.db = 1;
      seg.s = 1;
      seg.g = 1;
    };
    setup_ds(sregs.ds);
    setup_ds(sregs.es);
    setup_ds(sregs.fs);
    setup_ds(sregs.gs);
    setup_ds(sregs.ss);

    ioctl(vcpu_fd, KVM_SET_SREGS, &sregs);

  }

  void load_test(const TestCase &tc) {
    memset(guest_mem + CODE_ADDR, 0, 0x1000);
    memset(guest_mem + DATA_ADDR, 0, 0x1000);

    memcpy(guest_mem + CODE_ADDR, tc.code.data(), tc.code.size());
    guest_mem[CODE_ADDR + tc.code.size()] = 0xF4;  // HLT

    if (!tc.init_data.empty())
      memcpy(guest_mem + DATA_ADDR, tc.init_data.data(), tc.init_data.size());

    struct kvm_regs regs = {};
    regs.rax = tc.initial.rax;
    regs.rbx = tc.initial.rbx;
    regs.rcx = tc.initial.rcx;
    regs.rdx = tc.initial.rdx;
    regs.rsi = tc.initial.rsi;
    regs.rdi = tc.initial.rdi;
    regs.rbp = tc.initial.rbp;
    regs.rsp = tc.initial.rsp ? tc.initial.rsp : STACK_TOP;
    regs.r8  = tc.initial.r8;
    regs.r9  = tc.initial.r9;
    regs.r10 = tc.initial.r10;
    regs.r11 = tc.initial.r11;
    regs.r12 = tc.initial.r12;
    regs.r13 = tc.initial.r13;
    regs.r14 = tc.initial.r14;
    regs.r15 = tc.initial.r15;
    regs.rip = CODE_ADDR;
    regs.rflags = tc.initial.rflags | 0x2;

    ioctl(vcpu_fd, KVM_SET_REGS, &regs);

    // Set XMM registers and MXCSR via XSAVE.
    struct kvm_xsave xsave;
    ioctl(vcpu_fd, KVM_GET_XSAVE, &xsave);
    u8 *xs = (u8 *)&xsave;
    // MXCSR at offset 0x18
    memcpy(xs + 0x18, &tc.initial.mxcsr, 4);
    // XMM0-XMM15 at offset 0xA0 (16 bytes each)
    for (int i = 0; i < 16; i++) {
      memcpy(xs + 0xA0 + i * 16,     &tc.initial.xmm[i].lo, 8);
      memcpy(xs + 0xA0 + i * 16 + 8, &tc.initial.xmm[i].hi, 8);
    }
    // XSTATE_BV at offset 0x200: set bit 0 (x87) + bit 1 (SSE) so KVM loads XMM state.
    u64 xstate_bv = 0x3;
    memcpy(xs + 0x200, &xstate_bv, 8);
    ioctl(vcpu_fd, KVM_SET_XSAVE, &xsave);
  }

  ArchState run_test() {
    if (ioctl(vcpu_fd, KVM_RUN, 0) < 0) {
      perror("KVM_RUN");
      abort();
    }

    if (run->exit_reason != KVM_EXIT_HLT) {
      fprintf(stderr, "KVM: unexpected exit reason %d\n", run->exit_reason);
      if (run->exit_reason == KVM_EXIT_FAIL_ENTRY)
        fprintf(stderr, "  hardware_entry_failure_reason: 0x%llx\n",
                run->fail_entry.hardware_entry_failure_reason);
      if (run->exit_reason == KVM_EXIT_INTERNAL_ERROR)
        fprintf(stderr, "  suberror: %d\n", run->internal.suberror);
      abort();
    }

    struct kvm_regs regs;
    ioctl(vcpu_fd, KVM_GET_REGS, &regs);

    ArchState state = {
      .rax = regs.rax, .rbx = regs.rbx, .rcx = regs.rcx, .rdx = regs.rdx,
      .rsi = regs.rsi, .rdi = regs.rdi, .rbp = regs.rbp, .rsp = regs.rsp,
      .r8  = regs.r8,  .r9  = regs.r9,  .r10 = regs.r10, .r11 = regs.r11,
      .r12 = regs.r12, .r13 = regs.r13, .r14 = regs.r14, .r15 = regs.r15,
      .rip = regs.rip,
      .rflags = regs.rflags,
    };

    struct kvm_xsave xsave;
    ioctl(vcpu_fd, KVM_GET_XSAVE, &xsave);
    u8 *xs = (u8 *)&xsave;
    memcpy(&state.mxcsr, xs + 0x18, 4);
    for (int i = 0; i < 16; i++) {
      memcpy(&state.xmm[i].lo, xs + 0xA0 + i * 16,     8);
      memcpy(&state.xmm[i].hi, xs + 0xA0 + i * 16 + 8, 8);
    }
    return state;
  }

  // Read data area for memory comparison
  void read_data(u8 *buf, size_t len) {
    memcpy(buf, guest_mem + DATA_ADDR, len);
  }
};

// ---- Sail model execution ----

ArchState run_sail(const TestCase &tc, u8 *data_out, size_t data_len) {
  x86::Model model;
  model.model_init();
  model.zinitializze_registers(UNIT);
  model.zcur_mode = x86::zLongMode;
  model.zcur_cpl = 0;

  // Write test code + HLT
  model.memory.write(CODE_ADDR, tc.code.data(), tc.code.size());
  u8 hlt = 0xF4;
  model.memory.write(CODE_ADDR + tc.code.size(), &hlt, 1);

  // Set up stack
  model.memory.map_range(STACK_TOP - 0x1000, 0x1000);

  // Set up data area
  if (!tc.init_data.empty())
    model.memory.write(DATA_ADDR, tc.init_data.data(), tc.init_data.size());
  else
    model.memory.map_range(DATA_ADDR, 0x1000);

  // GPR order: RAX=0, RCX=1, RDX=2, RBX=3, RSP=4, RBP=5, RSI=6, RDI=7, R8-R15=8-15
  model.zGPR.data[0]  = tc.initial.rax;
  model.zGPR.data[1]  = tc.initial.rcx;
  model.zGPR.data[2]  = tc.initial.rdx;
  model.zGPR.data[3]  = tc.initial.rbx;
  model.zGPR.data[4]  = tc.initial.rsp ? tc.initial.rsp : STACK_TOP;
  model.zGPR.data[5]  = tc.initial.rbp;
  model.zGPR.data[6]  = tc.initial.rsi;
  model.zGPR.data[7]  = tc.initial.rdi;
  model.zGPR.data[8]  = tc.initial.r8;
  model.zGPR.data[9]  = tc.initial.r9;
  model.zGPR.data[10] = tc.initial.r10;
  model.zGPR.data[11] = tc.initial.r11;
  model.zGPR.data[12] = tc.initial.r12;
  model.zGPR.data[13] = tc.initial.r13;
  model.zGPR.data[14] = tc.initial.r14;
  model.zGPR.data[15] = tc.initial.r15;
  model.zRIP = CODE_ADDR;

  u64 flags = tc.initial.rflags;
  model.zCF = (flags >> 0) & 1;
  model.zPF = (flags >> 2) & 1;
  model.zAF = (flags >> 4) & 1;
  model.zZF = (flags >> 6) & 1;
  model.zSF = (flags >> 7) & 1;
  model.zDF = (flags >> 10) & 1;
  model.zOF = (flags >> 11) & 1;

  // Set XMM registers and MXCSR
  model.mxcsr_state.mxcsr = tc.initial.mxcsr;
  for (int i = 0; i < 16; i++) {
    u8 bytes[16];
    memcpy(bytes,     &tc.initial.xmm[i].lo, 8);
    memcpy(bytes + 8, &tc.initial.xmm[i].hi, 8);
    RECREATE(lbits)(&model.zZMM.data[i]);
    bytes_to_xmm(&model.zZMM.data[i], bytes);
  }

  x86::zExecutionResult result = {};
  result.kind = x86::Kind_zOk;
  result.variants.zOk = UNIT;

  for (int i = 0; i < 1000; i++) {
    model.zstep(&result, UNIT);
    switch (result.kind) {
    case x86::Kind_zOk: continue;
    case x86::Kind_zHalt: goto done;
    case x86::Kind_zFault: {
      i64 vec = result.variants.zFault.ztup0;
      u32 err = result.variants.zFault.ztup1;
      fprintf(stderr, "Sail: fault #%ld (error 0x%x) at RIP=0x%lx\n",
              vec, err, model.zRIP);
      abort();
    }
    }
  }
  fprintf(stderr, "Sail: did not reach HLT within 1000 steps\n");
  abort();

done:
  u64 rflags = 0x2;
  rflags |= model.zCF << 0;
  rflags |= model.zPF << 2;
  rflags |= model.zAF << 4;
  rflags |= model.zZF << 6;
  rflags |= model.zSF << 7;
  rflags |= model.zDF << 10;
  rflags |= model.zOF << 11;

  if (data_len > 0)
    model.memory.read(DATA_ADDR, data_out, data_len);

  ArchState state = {
    .rax = model.zGPR.data[0],
    .rbx = model.zGPR.data[3],
    .rcx = model.zGPR.data[1],
    .rdx = model.zGPR.data[2],
    .rsi = model.zGPR.data[6],
    .rdi = model.zGPR.data[7],
    .rbp = model.zGPR.data[5],
    .rsp = model.zGPR.data[4],
    .r8  = model.zGPR.data[8],
    .r9  = model.zGPR.data[9],
    .r10 = model.zGPR.data[10],
    .r11 = model.zGPR.data[11],
    .r12 = model.zGPR.data[12],
    .r13 = model.zGPR.data[13],
    .r14 = model.zGPR.data[14],
    .r15 = model.zGPR.data[15],
    .rip = model.zRIP,
    .rflags = rflags,
  };

  state.mxcsr = model.mxcsr_state.mxcsr;
  for (int i = 0; i < 16; i++) {
    u8 bytes[16];
    xmm_to_bytes(model.zZMM.data[i], bytes);
    memcpy(&state.xmm[i].lo, bytes,     8);
    memcpy(&state.xmm[i].hi, bytes + 8, 8);
  }

  model.model_fini();
  return state;
}

// ---- Test cases ----
// Organized by instruction category to systematically cover all Sail code paths.
// Each category targets specific branches in the model (operand sizes, operand
// forms, count values, condition codes, etc.).

// ---- Stratified input generation ----
// Methodology from Strata (Heule et al., PLDI 2016) and Dasgupta et al.
// (PLDI 2019): test each instruction against a matrix of "interesting"
// boundary values that trigger flag transitions, overflow, sign changes,
// and operand-size edge cases.

// 22 values chosen to hit: zero, one, -1, signed min/max at each operand
// size (8/16/32/64), unsigned max at each size, alternating bit patterns,
// the 32/64-bit boundary, and near-boundary values.
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
  case 0:  s.rax = val; break;  case 1:  s.rcx = val; break;
  case 2:  s.rdx = val; break;  case 3:  s.rbx = val; break;
  case 4:  s.rsp = val; break;  case 5:  s.rbp = val; break;
  case 6:  s.rsi = val; break;  case 7:  s.rdi = val; break;
  case 8:  s.r8  = val; break;  case 9:  s.r9  = val; break;
  case 10: s.r10 = val; break;  case 11: s.r11 = val; break;
  case 12: s.r12 = val; break;  case 13: s.r13 = val; break;
  case 14: s.r14 = val; break;  case 15: s.r15 = val; break;
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

static void add_systematic_tests(std::vector<TestCase> &tests) {
  char name[256];
  int sizes[] = {8, 16, 32, 64};
  const char *sz_sfx[] = {"8", "16", "32", "64"};
  std::string cat;

  auto add = [&](const char *n, std::vector<u8> code, ArchState init,
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
    {"add", 0x00, FL_ALL}, {"or",  0x08, FL_ALL},
    {"adc", 0x10, FL_ALL}, {"sbb", 0x18, FL_ALL},
    {"and", 0x20, FL_ALL}, {"sub", 0x28, FL_ALL},
    {"xor", 0x30, FL_ALL}, {"cmp", 0x38, FL_ALL},
  };

  for (int si = 0; si < 4; si++) {
    snprintf(name, sizeof(name), "ALU reg,reg %s", sz_sfx[si]);
    cat = name;
    for (auto &op : alu_ops) {
      for (int i = 0; i < NVALS; i++) {
        for (int j = 0; j < NVALS; j++) {
          ArchState init = {};
          init.rflags = 0x2;
          init.rax = VALS[i];
          init.rbx = VALS[j];
          snprintf(name, sizeof(name), "S %s%s %d,%d",
                   op.name, sz_sfx[si], i, j);
          add(name, encode_alu_rr(op.base, sizes[si], 0, 3),
              init, op.mask);
        }
      }
    }
  }

  // ADC/SBB with CF=1 — exercises carry-in path with all value pairs
  cat = "ADC/SBB CF=1";
  for (int oi : {2, 3}) {
    auto &op = alu_ops[oi];
    for (int si = 0; si < 4; si++) {
      for (int i = 0; i < NVALS; i++) {
        for (int j = 0; j < NVALS; j++) {
          ArchState init = {};
          init.rflags = 0x3;  // CF=1
          init.rax = VALS[i];
          init.rbx = VALS[j];
          snprintf(name, sizeof(name), "S %s%s cf %d,%d",
                   op.name, sz_sfx[si], i, j);
          add(name, encode_alu_rr(op.base, sizes[si], 0, 3),
              init, op.mask);
        }
      }
    }
  }

  // TEST reg,reg — like AND but only sets flags, doesn't write result
  cat = "TEST reg,reg";
  for (int si = 0; si < 4; si++) {
    for (int i = 0; i < NVALS; i++) {
      for (int j = 0; j < NVALS; j++) {
        ArchState init = {};
        init.rflags = 0x2;
        init.rax = VALS[i];
        init.rbx = VALS[j];
        snprintf(name, sizeof(name), "S test%s %d,%d", sz_sfx[si], i, j);
        add(name, encode_alu_rr(0x84, sizes[si], 0, 3),
            init, FL_ALL);
      }
    }
  }

  // ================================================================
  // 2. Shifts by CL — 7 ops × 4 sizes × NSHIFTS × NVALS
  //    Tests shift/rotate with boundary counts and values.
  //    Flag masks are conservative (AF and OF may be undefined).
  // ================================================================
  cat = "Shifts";
  struct ShiftOp { const char *name; int digit; u64 mask; bool needs_cf; };
  ShiftOp shift_ops[] = {
    {"shl", 4, FL_NO_AF_OF, false},
    {"shr", 5, FL_NO_AF_OF, false},
    {"sar", 7, FL_NO_AF_OF, false},
    {"rol", 0, FL_CF, false},
    {"ror", 1, FL_CF, false},
    {"rcl", 2, FL_CF, true},
    {"rcr", 3, FL_CF, true},
  };

  for (auto &op : shift_ops) {
    for (int si = 0; si < 4; si++) {
      for (int ci = 0; ci < NSHIFTS; ci++) {
        for (int vi = 0; vi < NVALS; vi++) {
          ArchState init = {};
          init.rflags = 0x2;
          init.rax = VALS[vi];
          init.rcx = SHIFT_COUNTS[ci];
          snprintf(name, sizeof(name), "S %s%s c%d %d",
                   op.name, sz_sfx[si], (int)SHIFT_COUNTS[ci], vi);
          add(name, encode_shift_cl(op.digit, sizes[si], 0),
              init, op.mask);
        }
      }
    }

    // RCL/RCR with CF=1 — carry is rotated through the value
    if (op.needs_cf) {
      for (int si = 0; si < 4; si++) {
        for (int ci = 0; ci < NSHIFTS; ci++) {
          for (int vi = 0; vi < NVALS; vi++) {
            ArchState init = {};
            init.rflags = 0x3;  // CF=1
            init.rax = VALS[vi];
            init.rcx = SHIFT_COUNTS[ci];
            snprintf(name, sizeof(name), "S %s%s cf c%d %d",
                     op.name, sz_sfx[si], (int)SHIFT_COUNTS[ci], vi);
            add(name, encode_shift_cl(op.digit, sizes[si], 0),
                init, op.mask);
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
        ArchState init = {};
        init.rflags = 0x3;  // CF=1
        init.rax = VALS[vi];
        snprintf(name, sizeof(name), "S %s%s %d",
                 op.name, sz_sfx[si], vi);
        add(name, encode_unary(op.op8, op.op, op.digit, sizes[si], 0),
            init, op.mask);
      }
    }
  }

  // ================================================================
  // 4. MUL/IMUL 1-operand (64-bit) — NVALS × NVALS
  //    RAX * RBX -> RDX:RAX. Only CF and OF are defined.
  // ================================================================
  cat = "MUL/IMUL";
  for (int i = 0; i < NVALS; i++) {
    for (int j = 0; j < NVALS; j++) {
      ArchState init = {};
      init.rflags = 0x2;
      init.rax = VALS[i];
      init.rbx = VALS[j];

      snprintf(name, sizeof(name), "S mul64 %d,%d", i, j);
      add(name, {0x48, 0xF7, 0xE3}, init, FL_CF_OF);

      snprintf(name, sizeof(name), "S imul64 %d,%d", i, j);
      add(name, {0x48, 0xF7, 0xEB}, init, FL_CF_OF);
    }
  }

  // ================================================================
  // 5. DIV/IDIV (64-bit) — NVALS × NVALS (skip div-by-zero / overflow)
  //    RDX:RAX / RBX -> RAX=quot, RDX=rem. All flags undefined.
  // ================================================================
  cat = "DIV/IDIV";
  for (int i = 0; i < NVALS; i++) {
    for (int j = 0; j < NVALS; j++) {
      if (VALS[j] == 0) continue;

      // DIV: RDX=0 so quotient always fits (dividend < 2^64, divisor > 0)
      {
        ArchState init = {};
        init.rflags = 0x2;
        init.rax = VALS[i];
        init.rdx = 0;
        init.rbx = VALS[j];
        snprintf(name, sizeof(name), "S div64 %d,%d", i, j);
        add(name, {0x48, 0xF7, 0xF3}, init, FL_NONE);
      }

      // IDIV: sign-extend RAX into RDX:RAX.
      // Skip INT64_MIN / -1 (quotient overflow -> #DE).
      {
        i64 dividend = (i64)VALS[i];
        i64 divisor = (i64)VALS[j];
        if (dividend == (i64)0x8000000000000000 && divisor == -1)
          continue;

        ArchState init = {};
        init.rflags = 0x2;
        init.rax = VALS[i];
        init.rdx = (dividend < 0) ? 0xFFFFFFFFFFFFFFFF : 0;
        init.rbx = VALS[j];
        snprintf(name, sizeof(name), "S idiv64 %d,%d", i, j);
        add(name, {0x48, 0xF7, 0xFB}, init, FL_NONE);
      }
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
      ArchState init = {};
      init.rflags = 0x2;
      set_gpr(init, dst, 0x123456789ABCDEF0);
      set_gpr(init, src, 0x0FEDCBA987654321);
      snprintf(name, sizeof(name), "S add %s,%s",
               GPR_NAMES[dst], GPR_NAMES[src]);
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

    ArchState init = {};
    init.rax = (rng() % 4) ? VALS[rng() % NVALS] : rng();
    init.rbx = (rng() % 4) ? VALS[rng() % NVALS] : rng();
    init.rflags = 0x2 | ((rng() & 1) ? FL_CF : 0);

    snprintf(name, sizeof(name), "S rand %s%s %d",
             op.name, sz_sfx[si], t);
    add(name, encode_alu_rr(op.base, sizes[si], 0, 3), init, op.mask);
  }
}
std::vector<TestCase> build_tests() {
  std::vector<TestCase> tests;
  std::string cat;

  auto add = [&](const char *name, std::vector<u8> code, ArchState init,
                 u64 mask = FL_ALL) {
    tests.push_back({name, cat, std::move(code), init, mask});
  };

  auto add_mem = [&](const char *name, std::vector<u8> code, ArchState init,
                     u64 mask, std::vector<u8> data, size_t cmp_len) {
    tests.push_back({name, cat, std::move(code), init, mask, 0, false, std::move(data), cmp_len});
  };

  // =====================================================================
  // 1. ALU reg,reg — all 8 operations at 64-bit
  //    Exercises: exec_add_reg_reg, exec_or, exec_adc_reg_reg, exec_sbb_reg_reg,
  //    exec_and, exec_sub, exec_xor, exec_cmp through decode_alu.sail
  // =====================================================================
  cat = "Baseline/ALU reg,reg";
  ArchState alu = {};
  alu.rax = 0x0000000000000037;  // 55
  alu.rbx = 0x000000000000001E;  // 30
  alu.rcx = 7;
  alu.rflags = 0x2;

  // op RAX, RBX (64-bit): REX.W=48, opcode, ModRM=D8 (mod=11,reg=rbx,rm=rax)
  add("add rax,rbx",  {0x48, 0x01, 0xD8}, alu);
  add("or rax,rbx",   {0x48, 0x09, 0xD8}, alu);
  add("and rax,rbx",  {0x48, 0x21, 0xD8}, alu);
  add("sub rax,rbx",  {0x48, 0x29, 0xD8}, alu);
  add("xor rax,rbx",  {0x48, 0x31, 0xD8}, alu);
  add("cmp rax,rbx",  {0x48, 0x39, 0xD8}, alu);

  // ADC/SBB need CF set to exercise the carry-in path
  ArchState alu_cf = alu;
  alu_cf.rflags = 0x3;  // CF=1
  add("adc rax,rbx cf=1",  {0x48, 0x11, 0xD8}, alu_cf);
  add("sbb rax,rbx cf=1",  {0x48, 0x19, 0xD8}, alu_cf);

  // ADC/SBB with CF=0
  add("adc rax,rbx cf=0",  {0x48, 0x11, 0xD8}, alu);
  add("sbb rax,rbx cf=0",  {0x48, 0x19, 0xD8}, alu);

  // =====================================================================
  // 2. ALU operand sizes — exercises all 4 OperandSize branches
  //    32-bit should zero-extend upper 32 bits of dest.
  //    16-bit and 8-bit should preserve upper bits.
  // =====================================================================
  cat = "Baseline/ALU operand sizes";
  ArchState sz = {};
  sz.rax = 0xFFFFFFFF00000005;
  sz.rbx = 0xFFFFFFFF00000003;
  sz.rflags = 0x2;

  // ADD EAX, EBX (32-bit, no REX.W): zeroes upper 32 bits
  add("add eax,ebx (32)",  {0x01, 0xD8}, sz);
  // ADD AX, BX (16-bit, 66h prefix): preserves upper 48 bits
  add("add ax,bx (16)",    {0x66, 0x01, 0xD8}, sz);
  // ADD AL, BL (8-bit): preserves upper 56 bits
  add("add al,bl (8)",     {0x00, 0xD8}, sz);

  // SUB in different sizes
  add("sub eax,ebx (32)",  {0x29, 0xD8}, sz);
  add("sub ax,bx (16)",    {0x66, 0x29, 0xD8}, sz);
  add("sub al,bl (8)",     {0x28, 0xD8}, sz);

  // AND/OR/XOR at 32-bit (test zero-extension)
  add("and eax,ebx (32)",  {0x21, 0xD8}, sz);
  add("or eax,ebx (32)",   {0x09, 0xD8}, sz);
  add("xor eax,ebx (32)",  {0x31, 0xD8}, sz);

  // =====================================================================
  // 3. ALU reg,imm — exercises immediate operand fetch paths
  //    Group 1: 83 /op imm8 (sign-extended), 81 /op imm32
  // =====================================================================
  cat = "Baseline/ALU reg,imm";
  ArchState imm = {};
  imm.rax = 100;
  imm.rflags = 0x2;

  // ADD RAX, imm8:  48 83 C0 imm8 (ModRM=C0: /0=ADD, rm=rax)
  add("add rax,imm8",   {0x48, 0x83, 0xC0, 0x2A}, imm);  // +42
  // SUB RAX, imm8:  48 83 E8 imm8 (ModRM=E8: /5=SUB, rm=rax)
  add("sub rax,imm8",   {0x48, 0x83, 0xE8, 0x0A}, imm);  // -10
  // AND RAX, imm8:  48 83 E0 imm8 (ModRM=E0: /4=AND, rm=rax)
  add("and rax,imm8",   {0x48, 0x83, 0xE0, 0x0F}, imm);  // & 0xF
  // XOR RAX, imm8:  48 83 F0 imm8 (ModRM=F0: /6=XOR, rm=rax)
  add("xor rax,imm8",   {0x48, 0x83, 0xF0, 0xFF}, imm);  // ^ (-1)
  // CMP RAX, imm8:  48 83 F8 imm8 (ModRM=F8: /7=CMP, rm=rax)
  add("cmp rax,imm8",   {0x48, 0x83, 0xF8, 0x64}, imm);  // cmp 100
  // ADC RAX, imm8 with CF=1:
  ArchState imm_cf = imm;
  imm_cf.rflags = 0x3;
  add("adc rax,imm8 cf=1", {0x48, 0x83, 0xD0, 0x05}, imm_cf);  // +5+CF
  // SBB RAX, imm8 with CF=1:
  add("sbb rax,imm8 cf=1", {0x48, 0x83, 0xD8, 0x05}, imm_cf);  // -5-CF

  // ADD RAX, imm32:  48 81 C0 imm32 (sign-extended to 64)
  add("add rax,imm32",  {0x48, 0x81, 0xC0, 0x00, 0x01, 0x00, 0x00}, imm);  // +256

  // Negative imm8 (sign extension): ADD RAX, -1
  add("add rax,-1 (imm8)", {0x48, 0x83, 0xC0, 0xFF}, imm);  // +(-1)

  // =====================================================================
  // 4. ALU corner cases — overflow, zero, MAX/MIN
  // =====================================================================
  cat = "Baseline/ALU corner cases";
  ArchState ov = {};
  ov.rflags = 0x2;

  // Signed overflow: MAX + 1
  ov.rax = 0x7FFFFFFFFFFFFFFF;
  ov.rbx = 1;
  add("add signed overflow", {0x48, 0x01, 0xD8}, ov);

  // Unsigned carry: MAX + 1
  ov.rax = 0xFFFFFFFFFFFFFFFF;
  ov.rbx = 1;
  add("add unsigned carry", {0x48, 0x01, 0xD8}, ov);

  // SUB underflow
  ov.rax = 0;
  ov.rbx = 1;
  add("sub underflow", {0x48, 0x29, 0xD8}, ov);

  // XOR self = 0
  ov.rax = 0xDEADBEEFCAFEBABE;
  add("xor rax,rax", {0x48, 0x31, 0xC0}, ov);

  // CMP equal
  ov.rax = 42;
  ov.rbx = 42;
  add("cmp equal", {0x48, 0x39, 0xD8}, ov);

  // CMP less (unsigned)
  ov.rax = 1;
  ov.rbx = 0xFFFFFFFFFFFFFFFF;
  add("cmp less unsigned", {0x48, 0x39, 0xD8}, ov);

  // TEST RAX, RAX (AND without writing result)
  ov.rax = 0;
  add("test zero", {0x48, 0x85, 0xC0}, ov);
  ov.rax = 0x8000000000000000;
  add("test negative", {0x48, 0x85, 0xC0}, ov);
  ov.rax = 1;
  add("test positive", {0x48, 0x85, 0xC0}, ov);

  // =====================================================================
  // 5. Shift operations — exercises all ShiftOp branches
  //    Group 2: D1 /op (by 1), D3 /op (by CL), C1 /op imm8
  //    ModRM reg field: 0=ROL,1=ROR,2=RCL,3=RCR,4=SHL,5=SHR,7=SAR
  // =====================================================================
  cat = "Baseline/Shift operations";
  ArchState sh = {};
  sh.rax = 0x123456789ABCDEF0;
  sh.rcx = 7;
  sh.rflags = 0x3;  // CF=1 (matters for RCL/RCR)

  // --- By CL (count=7 > 1): AF undefined, OF undefined ---
  // REX.W D3 /op: shift RAX by CL
  add("shl rax,cl",  {0x48, 0xD3, 0xE0}, sh, FL_NO_AF_OF);  // /4
  add("shr rax,cl",  {0x48, 0xD3, 0xE8}, sh, FL_NO_AF_OF);  // /5
  add("sar rax,cl",  {0x48, 0xD3, 0xF8}, sh, FL_NO_AF_OF);  // /7
  add("rol rax,cl",  {0x48, 0xD3, 0xC0}, sh, FL_CF);         // /0, only CF defined (SF/ZF/PF unaffected, OF undef)
  add("ror rax,cl",  {0x48, 0xD3, 0xC8}, sh, FL_CF);         // /1
  add("rcl rax,cl",  {0x48, 0xD3, 0xD0}, sh, FL_CF);         // /2
  add("rcr rax,cl",  {0x48, 0xD3, 0xD8}, sh, FL_CF);         // /3

  // --- By 1: OF is defined ---
  // REX.W D1 /op
  add("shl rax,1",  {0x48, 0xD1, 0xE0}, sh, FL_NO_AF);
  add("shr rax,1",  {0x48, 0xD1, 0xE8}, sh, FL_NO_AF);
  add("sar rax,1",  {0x48, 0xD1, 0xF8}, sh, FL_NO_AF);
  add("rol rax,1",  {0x48, 0xD1, 0xC0}, sh, FL_CF | FL_OF);
  add("ror rax,1",  {0x48, 0xD1, 0xC8}, sh, FL_CF | FL_OF);
  add("rcl rax,1",  {0x48, 0xD1, 0xD0}, sh, FL_CF | FL_OF);
  add("rcr rax,1",  {0x48, 0xD1, 0xD8}, sh, FL_CF | FL_OF);

  // --- By imm8: SHL RAX, 4
  add("shl rax,imm4", {0x48, 0xC1, 0xE0, 0x04}, sh, FL_NO_AF_OF);

  // --- Count = 0: no flags modified (all flags should match initial) ---
  ArchState sh0 = sh;
  sh0.rcx = 0;
  add("shl rax,cl=0", {0x48, 0xD3, 0xE0}, sh0, FL_ALL);
  add("rol rax,cl=0", {0x48, 0xD3, 0xC0}, sh0, FL_ALL);

  // --- Different sizes for shifts ---
  ArchState sh32 = {};
  sh32.rax = 0xFFFFFFFF80000001;
  sh32.rcx = 1;
  sh32.rflags = 0x2;
  // SHL EAX, CL (32-bit, no REX.W): should zero-extend upper 32 bits
  add("shl eax,cl (32)", {0xD3, 0xE0}, sh32, FL_NO_AF);
  // SHR EAX, CL (32-bit)
  add("shr eax,cl (32)", {0xD3, 0xE8}, sh32, FL_NO_AF);
  // SAR EAX, CL (32-bit): sign extends within 32 bits, then zero-extends to 64
  add("sar eax,cl (32)", {0xD3, 0xF8}, sh32, FL_NO_AF);

  // 8-bit shift
  ArchState sh8 = {};
  sh8.rax = 0xFF;
  sh8.rcx = 4;
  sh8.rflags = 0x2;
  add("shl al,cl (8)", {0xD2, 0xE0}, sh8, FL_NO_AF_OF);
  add("shr al,cl (8)", {0xD2, 0xE8}, sh8, FL_NO_AF_OF);

  // =====================================================================
  // 6. Multiply — MUL, IMUL (1/2/3-operand forms)
  //    MUL/IMUL 1-op: SF, ZF, AF, PF undefined; only CF, OF defined
  //    IMUL 2/3-op: SF, ZF, AF, PF undefined; only CF, OF defined
  // =====================================================================
  cat = "Baseline/Multiply";
  ArchState mul = {};
  mul.rflags = 0x2;

  // MUL RBX (64-bit): RAX * RBX -> RDX:RAX
  // F7 /4, rm=3(rbx)
  mul.rax = 7;
  mul.rbx = 6;
  add("mul rbx (small)",  {0x48, 0xF7, 0xE3}, mul, FL_CF_OF);

  // MUL with overflow into RDX
  mul.rax = 0xFFFFFFFFFFFFFFFF;
  mul.rbx = 2;
  add("mul rbx (overflow)", {0x48, 0xF7, 0xE3}, mul, FL_CF_OF);

  // MUL 32-bit: EAX * EBX -> EDX:EAX (F7 /4 without REX.W)
  mul.rax = 100000;
  mul.rbx = 100000;
  add("mul ebx (32)", {0xF7, 0xE3}, mul, FL_CF_OF);

  // MUL 8-bit: AL * BL -> AX (F6 /4, rm=3)
  mul.rax = 200;
  mul.rbx = 200;
  add("mul bl (8)", {0xF6, 0xE3}, mul, FL_CF_OF);

  // IMUL 1-operand (signed): RAX * RBX -> RDX:RAX
  // F7 /5
  mul.rax = (u64)(i64)(-7);
  mul.rbx = 6;
  add("imul1 rbx (neg)", {0x48, 0xF7, 0xEB}, mul, FL_CF_OF);

  // IMUL 2-operand: RAX := RAX * RBX (truncated)
  // 0F AF /r (ModRM: mod=11, reg=rax=0, rm=rbx=3 = C3)
  mul.rax = 42;
  mul.rbx = 100;
  add("imul2 rax,rbx", {0x48, 0x0F, 0xAF, 0xC3}, mul, FL_CF_OF);

  // IMUL 3-operand: RAX := RBX * imm8
  // 6B /r imm8 (ModRM: mod=11, reg=rax=0, rm=rbx=3 = C3)
  mul.rbx = 42;
  add("imul3 rax,rbx,imm8", {0x48, 0x6B, 0xC3, 0x0A}, mul, FL_CF_OF);  // *10

  // IMUL 3-operand with imm32: 69 /r imm32
  add("imul3 rax,rbx,imm32", {0x48, 0x69, 0xC3, 0xE8, 0x03, 0x00, 0x00}, mul, FL_CF_OF);  // *1000

  // =====================================================================
  // 7. Divide — DIV, IDIV (all flags undefined)
  // =====================================================================
  cat = "Baseline/Divide";
  ArchState dv = {};
  dv.rflags = 0x2;

  // DIV RBX (64-bit): RDX:RAX / RBX -> RAX=quot, RDX=rem
  dv.rax = 100;
  dv.rdx = 0;
  dv.rbx = 7;
  add("div rbx (64)",  {0x48, 0xF7, 0xF3}, dv, FL_NONE);

  // DIV with nonzero RDX
  dv.rax = 0;
  dv.rdx = 1;  // dividend = 0x10000000000000000 = 2^64
  dv.rbx = 3;
  add("div rbx (large)", {0x48, 0xF7, 0xF3}, dv, FL_NONE);

  // DIV 32-bit: EDX:EAX / EBX -> EAX=quot, EDX=rem
  dv.rax = 1000;
  dv.rdx = 0;
  dv.rbx = 7;
  add("div ebx (32)", {0xF7, 0xF3}, dv, FL_NONE);

  // IDIV RBX (signed)
  dv.rax = (u64)(i64)(-100);
  dv.rdx = 0xFFFFFFFFFFFFFFFF;  // sign extension of negative dividend
  dv.rbx = 7;
  add("idiv rbx (neg)", {0x48, 0xF7, 0xFB}, dv, FL_NONE);

  // IDIV positive
  dv.rax = 100;
  dv.rdx = 0;
  dv.rbx = 7;
  add("idiv rbx (pos)", {0x48, 0xF7, 0xFB}, dv, FL_NONE);

  // IDIV 8-bit: AX / src8 -> AL=quot, AH=rem
  // F6 /7
  dv.rax = 100;  // dividend in AX (low 16 bits)
  dv.rbx = 7;
  add("idiv bl (8)", {0xF6, 0xFB}, dv, FL_NONE);

  // =====================================================================
  // 8. INC/DEC/NEG/NOT — unary operations
  //    INC/DEC: all flags except CF. NEG: all flags. NOT: no flags.
  // =====================================================================
  cat = "Baseline/INC/DEC/NEG/NOT";
  ArchState un = {};
  un.rflags = 0x3;  // CF=1 (INC/DEC should preserve CF)

  un.rax = 42;
  add("inc rax", {0x48, 0xFF, 0xC0}, un);  // FF /0
  add("dec rax", {0x48, 0xFF, 0xC8}, un);  // FF /1
  add("neg rax", {0x48, 0xF7, 0xD8}, un);  // F7 /3
  add("not rax", {0x48, 0xF7, 0xD0}, un, FL_ALL);  // F7 /2, no flag changes

  // INC/DEC corner cases
  un.rax = 0xFFFFFFFFFFFFFFFF;
  add("inc -1", {0x48, 0xFF, 0xC0}, un);  // -1 -> 0
  un.rax = 0;
  add("dec 0", {0x48, 0xFF, 0xC8}, un);   // 0 -> -1
  un.rax = 0x7FFFFFFFFFFFFFFF;
  add("inc max_signed", {0x48, 0xFF, 0xC0}, un);  // overflow

  // NEG 0 (CF should be 0) and NEG MIN (overflow)
  un.rax = 0;
  add("neg 0", {0x48, 0xF7, 0xD8}, un);
  un.rax = 0x8000000000000000;
  add("neg min_signed", {0x48, 0xF7, 0xD8}, un);

  // 32-bit INC (zero-extends)
  un.rax = 0xFFFFFFFF;
  add("inc eax (32)", {0xFF, 0xC0}, un);

  // =====================================================================
  // 9. Conditional operations — SETcc, CMOVcc
  //    Tests all 16 condition codes via eval_cc
  // =====================================================================
  cat = "Baseline/SETcc/CMOVcc";

  // Set up flags to create interesting condition states.
  // State A: CF=1, ZF=0, SF=0, OF=0, PF=0 (carry set, positive nonzero)
  ArchState ccA = {};
  ccA.rax = 0;
  ccA.rbx = 42;
  ccA.rflags = 0x2 | FL_CF;  // CF=1 only

  // State B: CF=0, ZF=1, SF=0, OF=0, PF=1 (zero result)
  ArchState ccB = {};
  ccB.rax = 0;
  ccB.rbx = 42;
  ccB.rflags = 0x2 | FL_ZF | FL_PF;

  // State C: CF=0, ZF=0, SF=1, OF=0 (negative, no overflow)
  ArchState ccC = {};
  ccC.rax = 0;
  ccC.rbx = 42;
  ccC.rflags = 0x2 | FL_SF;

  // State D: CF=0, ZF=0, SF=1, OF=1 (SF!=OF, so L=true but GE=false)
  ArchState ccD = {};
  ccD.rax = 0;
  ccD.rbx = 42;
  ccD.rflags = 0x2 | FL_SF | FL_OF;

  // SETcc AL: 0F 9x C0 (ModRM=C0: /0, rm=rax)
  // Test all 16 condition codes with state A (CF=1)
  static const char *cc_names[] = {"o","no","b","ae","e","ne","be","a",
                                   "s","ns","p","np","l","ge","le","g"};
  char ccbuf[64];

  for (int cc = 0; cc < 16; cc++) {
    snprintf(ccbuf, sizeof(ccbuf), "set%s al (cf=1)", cc_names[cc]);
    add(ccbuf, {0x0F, (u8)(0x90 + cc), 0xC0}, ccA, FL_ALL);
  }

  // Test SETcc with state B (ZF=1)
  for (int cc : {4, 5, 6, 7}) {  // E, NE, BE, A — all involve ZF
    snprintf(ccbuf, sizeof(ccbuf), "set%s al (zf=1)", cc_names[cc]);
    add(ccbuf, {0x0F, (u8)(0x90 + cc), 0xC0}, ccB, FL_ALL);
  }

  // Test SETcc with state D (SF=1, OF=1 — GE should be true since SF==OF)
  for (int cc : {12, 13, 14, 15}) {  // L, GE, LE, G
    snprintf(ccbuf, sizeof(ccbuf), "set%s al (sf=of=1)", cc_names[cc]);
    add(ccbuf, {0x0F, (u8)(0x90 + cc), 0xC0}, ccD, FL_ALL);
  }

  // CMOVcc RAX, RBX (64-bit): 48 0F 4x C3 (ModRM=C3: reg=rax, rm=rbx)
  // Test taken (condition true) and not-taken
  add("cmove rax,rbx (taken)",     {0x48, 0x0F, 0x44, 0xC3}, ccB, FL_ALL);  // ZF=1 → taken
  add("cmove rax,rbx (not taken)", {0x48, 0x0F, 0x44, 0xC3}, ccA, FL_ALL);  // ZF=0 → not taken
  add("cmovb rax,rbx (taken)",     {0x48, 0x0F, 0x42, 0xC3}, ccA, FL_ALL);  // CF=1 → taken
  add("cmovb rax,rbx (not taken)", {0x48, 0x0F, 0x42, 0xC3}, ccB, FL_ALL);  // CF=0 → not taken
  add("cmovl rax,rbx (taken)",     {0x48, 0x0F, 0x4C, 0xC3}, ccC, FL_ALL);  // SF!=OF → taken
  add("cmovl rax,rbx (not taken)", {0x48, 0x0F, 0x4C, 0xC3}, ccD, FL_ALL);  // SF==OF → not taken
  add("cmovg rax,rbx (taken)",     {0x48, 0x0F, 0x4F, 0xC3}, ccA, FL_ALL);  // ZF=0 & SF==OF → taken
  add("cmovg rax,rbx (not taken)", {0x48, 0x0F, 0x4F, 0xC3}, ccB, FL_ALL);  // ZF=1 → not taken

  // =====================================================================
  // 10. Branch — Jcc (tests decode_pos + offset calculation)
  // =====================================================================
  cat = "Baseline/Branch";

  // JE rel8: 74 xx. If taken, skip a MOV instruction.
  // Layout: JE +3 (skip 3 bytes) | MOV EAX,1 (B8 01 00 00 00 = 5 bytes, but
  // we use a 3-byte: XOR EAX,EAX = 31 C0 ... no, let's be precise)
  // JE +2 skips 2 bytes: the next 2-byte instruction (XOR EAX,EAX) is skipped.
  //
  // Code: 74 02 | 48 FF C0 (INC RAX) | [HLT auto-appended]
  // If ZF=1: jump over INC RAX, RAX stays 0.
  // If ZF=0: execute INC RAX, RAX becomes 1.
  ArchState br = {};
  br.rax = 0;
  br.rflags = 0x2 | FL_ZF;  // ZF=1
  add("je taken (skip inc)",     {0x74, 0x03, 0x48, 0xFF, 0xC0}, br, FL_ALL);

  br.rflags = 0x2;  // ZF=0
  add("je not taken (exec inc)", {0x74, 0x03, 0x48, 0xFF, 0xC0}, br, FL_ALL);

  // JL rel8: 7C xx
  br.rflags = 0x2 | FL_SF;  // SF=1, OF=0 → SF!=OF → L is true
  add("jl taken",     {0x7C, 0x03, 0x48, 0xFF, 0xC0}, br, FL_ALL);
  br.rflags = 0x2;  // SF=0, OF=0 → SF==OF → L is false
  add("jl not taken", {0x7C, 0x03, 0x48, 0xFF, 0xC0}, br, FL_ALL);

  // JMP rel8: EB xx (unconditional short jump)
  add("jmp rel8",     {0xEB, 0x03, 0x48, 0xFF, 0xC0}, br, FL_ALL);

  // =====================================================================
  // 11. Data movement — MOVSX, MOVZX, MOVSXD, BSWAP, CBW, CWD, XCHG
  // =====================================================================
  cat = "Baseline/Data movement";
  ArchState mv = {};
  mv.rflags = 0x2;

  // MOVSX RAX, BL: sign-extend byte to 64
  mv.rbx = 0xFF;  // -1 as byte
  add("movsx rax,bl",  {0x48, 0x0F, 0xBE, 0xC3}, mv, FL_ALL);
  mv.rbx = 0x7F;  // +127
  add("movsx rax,bl pos", {0x48, 0x0F, 0xBE, 0xC3}, mv, FL_ALL);

  // MOVSX RAX, BX: sign-extend word to 64
  mv.rbx = 0x8000;  // -32768 as word
  add("movsx rax,bx",  {0x48, 0x0F, 0xBF, 0xC3}, mv, FL_ALL);

  // MOVSXD RAX, EBX: sign-extend dword to 64 (REX.W 63 /r)
  mv.rbx = 0x80000000;  // -2^31 as dword
  add("movsxd rax,ebx", {0x48, 0x63, 0xC3}, mv, FL_ALL);
  mv.rbx = 0x7FFFFFFF;
  add("movsxd rax,ebx pos", {0x48, 0x63, 0xC3}, mv, FL_ALL);

  // MOVZX RAX, BL: zero-extend byte to 64
  mv.rbx = 0xFF;
  add("movzx rax,bl",  {0x48, 0x0F, 0xB6, 0xC3}, mv, FL_ALL);

  // MOVZX RAX, BX: zero-extend word to 64
  mv.rbx = 0xFFFF;
  add("movzx rax,bx",  {0x48, 0x0F, 0xB7, 0xC3}, mv, FL_ALL);

  // BSWAP RAX: 48 0F C8
  mv.rax = 0x0102030405060708;
  add("bswap rax",  {0x48, 0x0F, 0xC8}, mv, FL_ALL);

  // BSWAP EAX (32-bit): 0F C8
  mv.rax = 0xFFFFFFFF01020304;
  add("bswap eax (32)", {0x0F, 0xC8}, mv, FL_ALL);  // upper 32 bits zeroed

  // CBW: 66 98 (sign-extend AL -> AX)
  mv.rax = 0x123456789ABCDE80;  // AL = 0x80
  add("cbw", {0x66, 0x98}, mv, FL_ALL);

  // CWDE: 98 (sign-extend AX -> EAX)
  mv.rax = 0x123456789ABC8000;  // AX = 0x8000
  add("cwde", {0x98}, mv, FL_ALL);

  // CDQE: 48 98 (sign-extend EAX -> RAX)
  mv.rax = 0x1234567880000000;  // EAX = 0x80000000
  add("cdqe", {0x48, 0x98}, mv, FL_ALL);

  // CWD: 66 99 (sign-extend AX -> DX:AX)
  mv.rax = 0x8000;  // AX = 0x8000 (negative)
  mv.rdx = 0;
  add("cwd", {0x66, 0x99}, mv, FL_ALL);

  // CDQ: 99 (sign-extend EAX -> EDX:EAX)
  mv.rax = 0x80000000;
  mv.rdx = 0;
  add("cdq", {0x99}, mv, FL_ALL);

  // CQO: 48 99 (sign-extend RAX -> RDX:RAX)
  mv.rax = 0x8000000000000000;
  mv.rdx = 0;
  add("cqo neg", {0x48, 0x99}, mv, FL_ALL);
  mv.rax = 0x7FFFFFFFFFFFFFFF;
  add("cqo pos", {0x48, 0x99}, mv, FL_ALL);

  // XCHG RAX, RBX: 48 93
  mv.rax = 0xAAAAAAAAAAAAAAAA;
  mv.rbx = 0xBBBBBBBBBBBBBBBB;
  add("xchg rax,rbx", {0x48, 0x93}, mv, FL_ALL);

  // XCHG RCX, RDX: 48 87 CA (ModRM=CA: mod=11, reg=rcx=1, rm=rdx=2)
  mv.rcx = 0xCCCCCCCCCCCCCCCC;
  mv.rdx = 0xDDDDDDDDDDDDDDDD;
  add("xchg rcx,rdx", {0x48, 0x87, 0xCA}, mv, FL_ALL);

  // =====================================================================
  // 12. Bit operations — BT, BTS, BTR, BTC, BSF, BSR, POPCNT, LZCNT, TZCNT
  // =====================================================================
  cat = "Baseline/Bit operations";
  ArchState bt = {};
  bt.rflags = 0x2;

  // BT RAX, RBX: test bit RBX of RAX. CF = selected bit.
  // 0F A3 /r (ModRM: reg=rbx=3, rm=rax=0 = D8)
  bt.rax = 0x80;  // bit 7 set
  bt.rbx = 7;
  add("bt rax,rbx (set)",   {0x48, 0x0F, 0xA3, 0xD8}, bt, FL_CF);
  bt.rbx = 6;
  add("bt rax,rbx (clear)", {0x48, 0x0F, 0xA3, 0xD8}, bt, FL_CF);

  // BTS RAX, RBX: CF = old bit, then set bit. 0F AB /r
  bt.rax = 0;
  bt.rbx = 5;
  add("bts rax,rbx", {0x48, 0x0F, 0xAB, 0xD8}, bt, FL_CF);

  // BTR RAX, RBX: CF = old bit, then clear bit. 0F B3 /r
  bt.rax = 0xFF;
  bt.rbx = 3;
  add("btr rax,rbx", {0x48, 0x0F, 0xB3, 0xD8}, bt, FL_CF);

  // BTC RAX, RBX: CF = old bit, then complement bit. 0F BB /r
  bt.rax = 0xFF;
  bt.rbx = 0;
  add("btc rax,rbx", {0x48, 0x0F, 0xBB, 0xD8}, bt, FL_CF);

  // BT reg, imm8: 0F BA /4 imm8
  bt.rax = 0x100;  // bit 8 set
  add("bt rax,imm8", {0x48, 0x0F, 0xBA, 0xE0, 0x08}, bt, FL_CF);

  // BSF RAX, RBX: find lowest set bit. ZF=1 if source=0.
  // 0F BC /r (ModRM: reg=rax=0, rm=rbx=3 = C3)
  bt.rbx = 0x100;  // bit 8 set → result = 8
  add("bsf rax,rbx", {0x48, 0x0F, 0xBC, 0xC3}, bt, FL_ZF_ONLY);
  bt.rbx = 0;  // ZF=1
  add("bsf rax,rbx zero", {0x48, 0x0F, 0xBC, 0xC3}, bt, FL_ZF_ONLY);

  // BSR RAX, RBX: find highest set bit.
  // 0F BD /r
  bt.rbx = 0x100;  // bit 8 = highest → result = 8
  add("bsr rax,rbx", {0x48, 0x0F, 0xBD, 0xC3}, bt, FL_ZF_ONLY);
  bt.rbx = 0;
  add("bsr rax,rbx zero", {0x48, 0x0F, 0xBD, 0xC3}, bt, FL_ZF_ONLY);

  // POPCNT RAX, RBX: F3 48 0F B8 C3
  bt.rbx = 0xFF00FF00FF00FF00;  // 32 bits set
  add("popcnt rax,rbx", {0xF3, 0x48, 0x0F, 0xB8, 0xC3}, bt, FL_ALL);
  bt.rbx = 0;
  add("popcnt rax,rbx zero", {0xF3, 0x48, 0x0F, 0xB8, 0xC3}, bt, FL_ALL);

  // LZCNT RAX, RBX: F3 48 0F BD C3
  bt.rbx = 0x0000000100000000;  // bit 32 set → lzcnt = 31
  add("lzcnt rax,rbx", {0xF3, 0x48, 0x0F, 0xBD, 0xC3}, bt, FL_CF_ZF);
  bt.rbx = 0;
  add("lzcnt rax,rbx zero", {0xF3, 0x48, 0x0F, 0xBD, 0xC3}, bt, FL_CF_ZF);
  bt.rbx = 0x8000000000000000;  // highest bit → lzcnt = 0, ZF=1
  add("lzcnt rax,rbx msb", {0xF3, 0x48, 0x0F, 0xBD, 0xC3}, bt, FL_CF_ZF);

  // TZCNT RAX, RBX: F3 48 0F BC C3
  bt.rbx = 0x100;  // bit 8 → tzcnt = 8
  add("tzcnt rax,rbx", {0xF3, 0x48, 0x0F, 0xBC, 0xC3}, bt, FL_CF_ZF);
  bt.rbx = 0;
  add("tzcnt rax,rbx zero", {0xF3, 0x48, 0x0F, 0xBC, 0xC3}, bt, FL_CF_ZF);
  bt.rbx = 1;  // tzcnt = 0, ZF=1
  add("tzcnt rax,rbx lsb", {0xF3, 0x48, 0x0F, 0xBC, 0xC3}, bt, FL_CF_ZF);

  // =====================================================================
  // 13. Stack operations — PUSH, POP, CALL+RET
  // =====================================================================
  cat = "Baseline/Stack operations";

  // PUSH RBX (53) + POP RAX (58): RAX should get RBX's value
  ArchState stk = {};
  stk.rbx = 0xDEADBEEFCAFEBABE;
  stk.rflags = 0x2;
  add("push rbx; pop rax", {0x53, 0x58}, stk, FL_ALL);

  // PUSH imm8 (6A imm8) + POP RAX: test sign-extension
  stk.rax = 0;
  add("push imm8(-1); pop rax", {0x6A, 0xFF, 0x58}, stk, FL_ALL);

  // PUSH imm32 (68 imm32) + POP RAX
  add("push imm32; pop rax", {0x68, 0x78, 0x56, 0x34, 0x12, 0x58}, stk, FL_ALL);

  // CALL rel32 + RET: tests stack push/pop of return address
  // Layout: E8 01 00 00 00 | F4 | C3
  //   offset 0: CALL +1 → target = offset 6
  //   offset 5: HLT (return point)
  //   offset 6: RET
  stk.rax = 0;
  add("call+ret", {0xE8, 0x01, 0x00, 0x00, 0x00, 0xF4, 0xC3}, stk, FL_ALL);

  // CALL + RET with operations in callee
  // E8 02 00 00 00 | F4 | 48 FF C0 | C3
  //   offset 0: CALL +2 → target = offset 7
  //   offset 5: HLT (return point, after RET pops here... wait)
  // Actually: CALL pushes return address = offset 5, jumps to offset 7.
  // Wait, the CALL is 5 bytes (E8 + 4-byte offset). Return addr = CODE_ADDR + 5.
  // Target = CODE_ADDR + 5 + 2 = CODE_ADDR + 7.
  // Offset 5: F4 = HLT (this is where RET returns to)
  // Offset 6: padding (need 1 byte before target at offset 7)
  // Let me redo: CALL offset = 2 means skip 2 bytes after the CALL.
  // Return addr = CODE_ADDR + 5. Target = CODE_ADDR + 5 + 2 = CODE_ADDR + 7.
  // So bytes 5,6 = F4, 90 (HLT, NOP as padding). Byte 7+ = INC RAX + RET.
  // After RET, execution continues at offset 5 = HLT.
  stk.rax = 0;
  add("call+inc+ret", {0xE8, 0x02, 0x00, 0x00, 0x00, 0xF4, 0x90,
                        0x48, 0xFF, 0xC0, 0xC3}, stk, FL_ALL);

  // =====================================================================
  // 14. LEA — exercises addressing mode computation without memory access
  // =====================================================================
  cat = "Baseline/LEA";
  ArchState lea = {};
  lea.rbx = 100;
  lea.rcx = 7;
  lea.rsi = 0x1000;
  lea.rflags = 0x2;

  // LEA RAX, [RBX + RCX*2]: 48 8D 04 4B
  add("lea [rbx+rcx*2]", {0x48, 0x8D, 0x04, 0x4B}, lea, FL_ALL);

  // LEA RAX, [RBX + RCX*8 + 0x10]: 48 8D 44 CB 10
  add("lea [rbx+rcx*8+disp8]", {0x48, 0x8D, 0x44, 0xCB, 0x10}, lea, FL_ALL);

  // LEA RAX, [RSI + 0x100]: 48 8D 86 00 01 00 00
  add("lea [rsi+disp32]", {0x48, 0x8D, 0x86, 0x00, 0x01, 0x00, 0x00}, lea, FL_ALL);

  // LEA EAX, [EBX + ECX*4] (32-bit, with 67h prefix): zero-extends to 64
  // 67 8D 04 8B
  add("lea eax,[ebx+ecx*4] (32)", {0x67, 0x8D, 0x04, 0x8B}, lea, FL_ALL);

  // =====================================================================
  // 15. Memory operands — exercises RM_mem paths in read_rm_val/write_rm_val
  //     RDI = DATA_ADDR, initial data placed there
  // =====================================================================
  cat = "Baseline/Memory operands";

  // MOV RAX, [RDI]: 48 8B 07 (load 8 bytes)
  {
    ArchState mem = {};
    mem.rdi = DATA_ADDR;
    mem.rflags = 0x2;
    std::vector<u8> data = {0x78, 0x56, 0x34, 0x12, 0xEF, 0xCD, 0xAB, 0x90};
    add_mem("mov rax,[rdi]", {0x48, 0x8B, 0x07}, mem, FL_ALL, data, 0);
  }

  // MOV EAX, [RDI]: 8B 07 (load 4 bytes, zero-extends)
  {
    ArchState mem = {};
    mem.rax = 0xFFFFFFFFFFFFFFFF;
    mem.rdi = DATA_ADDR;
    mem.rflags = 0x2;
    std::vector<u8> data = {0x78, 0x56, 0x34, 0x12, 0, 0, 0, 0};
    add_mem("mov eax,[rdi] (32)", {0x8B, 0x07}, mem, FL_ALL, data, 0);
  }

  // MOV [RDI], RAX: 48 89 07 (store 8 bytes)
  {
    ArchState mem = {};
    mem.rax = 0x123456789ABCDEF0;
    mem.rdi = DATA_ADDR;
    mem.rflags = 0x2;
    add_mem("mov [rdi],rax", {0x48, 0x89, 0x07}, mem, FL_ALL, {}, 8);
  }

  // ADD RAX, [RDI]: 48 03 07
  {
    ArchState mem = {};
    mem.rax = 100;
    mem.rdi = DATA_ADDR;
    mem.rflags = 0x2;
    u8 val[] = {42, 0, 0, 0, 0, 0, 0, 0};
    add_mem("add rax,[rdi]", {0x48, 0x03, 0x07}, mem, FL_ALL,
            {val, val + 8}, 0);
  }

  // ADD [RDI], RAX: 48 01 07 (read-modify-write to memory)
  {
    ArchState mem = {};
    mem.rax = 100;
    mem.rdi = DATA_ADDR;
    mem.rflags = 0x2;
    u8 val[] = {42, 0, 0, 0, 0, 0, 0, 0};
    add_mem("add [rdi],rax", {0x48, 0x01, 0x07}, mem, FL_ALL,
            {val, val + 8}, 8);
  }

  // CMP RAX, [RDI]: 48 3B 07 (compare reg with memory)
  {
    ArchState mem = {};
    mem.rax = 42;
    mem.rdi = DATA_ADDR;
    mem.rflags = 0x2;
    u8 val[] = {42, 0, 0, 0, 0, 0, 0, 0};
    add_mem("cmp rax,[rdi] equal", {0x48, 0x3B, 0x07}, mem, FL_ALL,
            {val, val + 8}, 0);
  }

  // MOV [RDI+8], RBX using displacement: 48 89 5F 08
  {
    ArchState mem = {};
    mem.rbx = 0xCAFEBABE;
    mem.rdi = DATA_ADDR;
    mem.rflags = 0x2;
    add_mem("mov [rdi+8],rbx", {0x48, 0x89, 0x5F, 0x08}, mem, FL_ALL, {}, 16);
  }

  // SHL QWORD [RDI], CL: 48 D3 27 (shift memory operand)
  {
    ArchState mem = {};
    mem.rcx = 4;
    mem.rdi = DATA_ADDR;
    mem.rflags = 0x2;
    u8 val[] = {0xFF, 0, 0, 0, 0, 0, 0, 0};
    add_mem("shl [rdi],cl", {0x48, 0xD3, 0x27}, mem, FL_NO_AF_OF,
            {val, val + 8}, 8);
  }

  // INC QWORD [RDI]: 48 FF 07
  {
    ArchState mem = {};
    mem.rdi = DATA_ADDR;
    mem.rflags = 0x2;
    u8 val[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F};
    add_mem("inc [rdi]", {0x48, 0xFF, 0x07}, mem, FL_ALL, {val, val + 8}, 8);
  }

  // =====================================================================
  // 16. Double-precision shifts — SHLD, SHRD
  // =====================================================================
  cat = "Baseline/SHLD/SHRD";
  ArchState ds = {};
  ds.rax = 0x123456789ABCDEF0;
  ds.rbx = 0xFEDCBA9876543210;
  ds.rcx = 8;
  ds.rflags = 0x2;

  // SHLD RAX, RBX, CL: 48 0F A5 D8 (reg=rbx, rm=rax)
  add("shld rax,rbx,cl", {0x48, 0x0F, 0xA5, 0xD8}, ds, FL_NO_AF_OF);

  // SHRD RAX, RBX, CL: 48 0F AD D8
  add("shrd rax,rbx,cl", {0x48, 0x0F, 0xAD, 0xD8}, ds, FL_NO_AF_OF);

  // SHLD with count=1 (OF defined)
  ds.rcx = 1;
  add("shld rax,rbx,1", {0x48, 0x0F, 0xA5, 0xD8}, ds, FL_NO_AF);

  // SHRD with count=1
  add("shrd rax,rbx,1", {0x48, 0x0F, 0xAD, 0xD8}, ds, FL_NO_AF);

  // SHLD with imm8: 48 0F A4 D8 imm8
  ds.rcx = 0;  // CL unused, imm8 used
  add("shld rax,rbx,imm4", {0x48, 0x0F, 0xA4, 0xD8, 0x04}, ds, FL_NO_AF_OF);
  add("shrd rax,rbx,imm4", {0x48, 0x0F, 0xAC, 0xD8, 0x04}, ds, FL_NO_AF_OF);

  // =====================================================================
  // 17. MOV reg,imm — tests fetch_imm_v paths
  // =====================================================================
  cat = "Baseline/MOV reg,imm";
  ArchState mi = {};
  mi.rflags = 0x2;

  // MOV RAX, imm64: 48 B8 imm64 (REX.W + B8+rd)
  add("mov rax,imm64", {0x48, 0xB8, 0x01, 0x02, 0x03, 0x04,
                         0x05, 0x06, 0x07, 0x08}, mi, FL_ALL);

  // MOV EAX, imm32: B8 imm32 (zero-extends to 64)
  mi.rax = 0xFFFFFFFFFFFFFFFF;
  add("mov eax,imm32", {0xB8, 0x78, 0x56, 0x34, 0x12}, mi, FL_ALL);

  // MOV AX, imm16: 66 B8 imm16 (preserves upper bits)
  mi.rax = 0xFFFFFFFFFFFF0000;
  add("mov ax,imm16", {0x66, 0xB8, 0xAB, 0xCD}, mi, FL_ALL);

  // =====================================================================
  // 18. XADD — exchange and add
  // =====================================================================
  cat = "Baseline/XADD";
  ArchState xa = {};
  xa.rax = 10;
  xa.rbx = 20;
  xa.rflags = 0x2;
  // XADD RAX, RBX: 48 0F C1 D8 (reg=rbx, rm=rax)
  // RAX := RAX + RBX, RBX := old RAX
  add("xadd rax,rbx", {0x48, 0x0F, 0xC1, 0xD8}, xa);

  // =====================================================================
  // 19. CMPXCHG — compare and exchange
  // =====================================================================
  cat = "Baseline/CMPXCHG";
  // CMPXCHG RBX, RCX: 48 0F B1 CB (reg=rcx, rm=rbx)
  // If RAX == RBX: ZF=1, RBX := RCX
  // If RAX != RBX: ZF=0, RAX := RBX

  // Case 1: equal
  ArchState cx = {};
  cx.rax = 42;
  cx.rbx = 42;
  cx.rcx = 99;
  cx.rflags = 0x2;
  add("cmpxchg equal", {0x48, 0x0F, 0xB1, 0xCB}, cx);

  // Case 2: not equal
  cx.rax = 42;
  cx.rbx = 100;
  cx.rcx = 99;
  add("cmpxchg not equal", {0x48, 0x0F, 0xB1, 0xCB}, cx);

  // =====================================================================
  // 20. Multi-instruction sequences — tests instruction interaction
  // =====================================================================
  cat = "Baseline/Multi-instruction";

  // ADD + ADC chain (tests carry propagation across instructions)
  // ADD RAX, RBX; ADC RDX, RCX
  ArchState chain = {};
  chain.rax = 0xFFFFFFFFFFFFFFFF;
  chain.rbx = 2;
  chain.rcx = 0;
  chain.rdx = 0;
  chain.rflags = 0x2;
  add("add+adc chain", {0x48, 0x01, 0xD8,   // ADD RAX, RBX
                         0x48, 0x11, 0xCA}, chain);  // ADC RDX, RCX

  // CMP + CMOVL (conditional based on previous comparison)
  ArchState cmpseq = {};
  cmpseq.rax = 10;
  cmpseq.rbx = 20;
  cmpseq.rcx = 99;
  cmpseq.rflags = 0x2;
  // CMP RAX, RBX; CMOVL RAX, RCX (if RAX < RBX, RAX := RCX)
  add("cmp+cmovl taken", {0x48, 0x39, 0xD8,               // CMP RAX, RBX
                           0x48, 0x0F, 0x4C, 0xC1}, cmpseq, FL_ALL);  // CMOVL RAX, RCX

  cmpseq.rax = 30;
  add("cmp+cmovl not taken", {0x48, 0x39, 0xD8,
                               0x48, 0x0F, 0x4C, 0xC1}, cmpseq, FL_ALL);

  // SHL + OR (construct value through shifts)
  ArchState shift_or = {};
  shift_or.rax = 0xFF;
  shift_or.rbx = 0x01;
  shift_or.rcx = 8;
  shift_or.rflags = 0x2;
  // SHL RAX, CL; OR RAX, RBX → RAX = 0xFF01 (if CL=8)
  add("shl+or construct", {0x48, 0xD3, 0xE0,        // SHL RAX, CL
                            0x48, 0x09, 0xD8}, shift_or, FL_ALL);

  // =====================================================================
  // 21. REX prefix variations — tests REX.R, REX.B for upper registers
  // =====================================================================
  cat = "Baseline/REX prefix";
  ArchState rex = {};
  rex.r8  = 0x1111111111111111;
  rex.r9  = 0x2222222222222222;
  rex.r12 = 0x3333333333333333;
  rex.r15 = 0x4444444444444444;
  rex.rflags = 0x2;

  // ADD R8, R9: 4D 01 C8 (REX.W+R+B=4D, 01, ModRM=C8: reg=r9=1, rm=r8=0)
  add("add r8,r9", {0x4D, 0x01, 0xC8}, rex);

  // MOV R12, R15: 4D 89 FC (REX.W+R+B, 89, ModRM=FC: reg=r15=7, rm=r12=4)
  add("mov r12,r15", {0x4D, 0x89, 0xFC}, rex, FL_ALL);

  // INC R8: 49 FF C0
  add("inc r8", {0x49, 0xFF, 0xC0}, rex);

  // =====================================================================
  // 22. Flag manipulation — CLC, STC, CLD, STD, CMC, LAHF, SAHF
  // =====================================================================
  cat = "Baseline/Flag manipulation";

  // CLC: F8
  ArchState fl = {};
  fl.rflags = 0x2 | FL_CF;
  add("clc", {0xF8}, fl, FL_ALL);

  // STC: F9
  fl.rflags = 0x2;
  add("stc", {0xF9}, fl, FL_ALL);

  // CMC (complement CF): F5
  fl.rflags = 0x2;
  add("cmc cf=0", {0xF5}, fl, FL_ALL);
  fl.rflags = 0x2 | FL_CF;
  add("cmc cf=1", {0xF5}, fl, FL_ALL);

  // CLD: FC
  fl.rflags = 0x2 | FL_DF;
  add("cld", {0xFC}, fl, FL_ALL);

  // STD: FD
  fl.rflags = 0x2;
  add("std", {0xFD}, fl, FL_ALL);

  // LAHF: load AH from flags (9F). AH = SF:ZF:0:AF:0:PF:1:CF
  fl.rflags = 0x2 | FL_CF | FL_ZF | FL_SF;
  fl.rax = 0;
  add("lahf", {0x9F}, fl, FL_ALL);

  // =====================================================================
  // 23. SSE/SSE2 — packed and scalar floating-point operations
  // =====================================================================
  cat = "SSE";

  auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                      u32 xmm_cmp) {
    tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
  };

  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // ADDPS XMM0, XMM1: 0F 58 C1
    add_xmm("addps xmm0,xmm1", {0x0F, 0x58, 0xC1}, s, 0x3);
    // SUBPS XMM0, XMM1: 0F 5C C1
    add_xmm("subps xmm0,xmm1", {0x0F, 0x5C, 0xC1}, s, 0x3);
    // MULPS XMM0, XMM1: 0F 59 C1
    add_xmm("mulps xmm0,xmm1", {0x0F, 0x59, 0xC1}, s, 0x3);
    // DIVPS XMM0, XMM1: 0F 5E C1
    add_xmm("divps xmm0,xmm1", {0x0F, 0x5E, 0xC1}, s, 0x3);
    // MINPS XMM0, XMM1: 0F 5D C1
    add_xmm("minps xmm0,xmm1", {0x0F, 0x5D, 0xC1}, s, 0x3);
    // MAXPS XMM0, XMM1: 0F 5F C1
    add_xmm("maxps xmm0,xmm1", {0x0F, 0x5F, 0xC1}, s, 0x3);

    // MOVAPS XMM2, XMM0: 0F 28 D0
    add_xmm("movaps xmm2,xmm0", {0x0F, 0x28, 0xD0}, s, 0x4);
    // MOVUPS XMM2, XMM0: 0F 10 D0
    add_xmm("movups xmm2,xmm0", {0x0F, 0x10, 0xD0}, s, 0x4);
  }

  // ADDPD/SUBPD/MULPD/DIVPD — packed double
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f64(1.5, 2.5);
    s.xmm[1] = xmm_from_f64(3.0, 4.0);

    // ADDPD XMM0, XMM1: 66 0F 58 C1
    add_xmm("addpd xmm0,xmm1", {0x66, 0x0F, 0x58, 0xC1}, s, 0x3);
    // SUBPD XMM0, XMM1: 66 0F 5C C1
    add_xmm("subpd xmm0,xmm1", {0x66, 0x0F, 0x5C, 0xC1}, s, 0x3);
    // MULPD XMM0, XMM1: 66 0F 59 C1
    add_xmm("mulpd xmm0,xmm1", {0x66, 0x0F, 0x59, 0xC1}, s, 0x3);
    // DIVPD XMM0, XMM1: 66 0F 5E C1
    add_xmm("divpd xmm0,xmm1", {0x66, 0x0F, 0x5E, 0xC1}, s, 0x3);
  }

  // ADDSS/SUBSS/MULSS/DIVSS — scalar single
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);

    // ADDSS XMM0, XMM1: F3 0F 58 C1
    add_xmm("addss xmm0,xmm1", {0xF3, 0x0F, 0x58, 0xC1}, s, 0x3);
    // SUBSS XMM0, XMM1: F3 0F 5C C1
    add_xmm("subss xmm0,xmm1", {0xF3, 0x0F, 0x5C, 0xC1}, s, 0x3);
    // MULSS XMM0, XMM1: F3 0F 59 C1
    add_xmm("mulss xmm0,xmm1", {0xF3, 0x0F, 0x59, 0xC1}, s, 0x3);
    // DIVSS XMM0, XMM1: F3 0F 5E C1
    add_xmm("divss xmm0,xmm1", {0xF3, 0x0F, 0x5E, 0xC1}, s, 0x3);
  }

  // ADDSD/SUBSD/MULSD/DIVSD — scalar double
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f64(1.5, 100.0);
    s.xmm[1] = xmm_from_f64(2.5, 200.0);

    // ADDSD XMM0, XMM1: F2 0F 58 C1
    add_xmm("addsd xmm0,xmm1", {0xF2, 0x0F, 0x58, 0xC1}, s, 0x3);
    // SUBSD XMM0, XMM1: F2 0F 5C C1
    add_xmm("subsd xmm0,xmm1", {0xF2, 0x0F, 0x5C, 0xC1}, s, 0x3);
    // MULSD XMM0, XMM1: F2 0F 59 C1
    add_xmm("mulsd xmm0,xmm1", {0xF2, 0x0F, 0x59, 0xC1}, s, 0x3);
    // DIVSD XMM0, XMM1: F2 0F 5E C1
    add_xmm("divsd xmm0,xmm1", {0xF2, 0x0F, 0x5E, 0xC1}, s, 0x3);
  }

  // SSE2 integer — PADDB/PADDW/PADDD/PADDQ, PSUBB, PAND/POR/PXOR
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x1011121314151617, 0x18191A1B1C1D1E1F);

    // PADDB XMM0, XMM1: 66 0F FC C1
    add_xmm("paddb xmm0,xmm1", {0x66, 0x0F, 0xFC, 0xC1}, s, 0x3);
    // PADDW XMM0, XMM1: 66 0F FD C1
    add_xmm("paddw xmm0,xmm1", {0x66, 0x0F, 0xFD, 0xC1}, s, 0x3);
    // PADDD XMM0, XMM1: 66 0F FE C1
    add_xmm("paddd xmm0,xmm1", {0x66, 0x0F, 0xFE, 0xC1}, s, 0x3);
    // PADDQ XMM0, XMM1: 66 0F D4 C1
    add_xmm("paddq xmm0,xmm1", {0x66, 0x0F, 0xD4, 0xC1}, s, 0x3);
    // PSUBB XMM0, XMM1: 66 0F F8 C1
    add_xmm("psubb xmm0,xmm1", {0x66, 0x0F, 0xF8, 0xC1}, s, 0x3);
    // PAND XMM0, XMM1: 66 0F DB C1
    add_xmm("pand xmm0,xmm1", {0x66, 0x0F, 0xDB, 0xC1}, s, 0x3);
    // POR XMM0, XMM1: 66 0F EB C1
    add_xmm("por xmm0,xmm1", {0x66, 0x0F, 0xEB, 0xC1}, s, 0x3);
    // PXOR XMM0, XMM1: 66 0F EF C1
    add_xmm("pxor xmm0,xmm1", {0x66, 0x0F, 0xEF, 0xC1}, s, 0x3);
  }

  // SSE2 shuffle/unpack
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // SHUFPS XMM0, XMM1, 0x1B: 0F C6 C1 1B (reverse order)
    add_xmm("shufps xmm0,xmm1,0x1b", {0x0F, 0xC6, 0xC1, 0x1B}, s, 0x3);
    // UNPCKLPS XMM0, XMM1: 0F 14 C1
    add_xmm("unpcklps xmm0,xmm1", {0x0F, 0x14, 0xC1}, s, 0x3);
    // UNPCKHPS XMM0, XMM1: 0F 15 C1
    add_xmm("unpckhps xmm0,xmm1", {0x0F, 0x15, 0xC1}, s, 0x3);
  }

  // SSE conversions
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.5f, 2.7f, -3.2f, 4.9f);

    // CVTPS2DQ XMM1, XMM0: 66 0F 5B C8 (ModRM: reg=1, rm=0)
    add_xmm("cvtps2dq xmm1,xmm0", {0x66, 0x0F, 0x5B, 0xC8}, s, 0x2);

    // CVTTPS2DQ XMM1, XMM0: F3 0F 5B C8
    add_xmm("cvttps2dq xmm1,xmm0", {0xF3, 0x0F, 0x5B, 0xC8}, s, 0x2);

    // CVTDQ2PS XMM1, XMM0: 0F 5B C8 (with integer input)
    ArchState si = {};
    si.rflags = 0x2;
    si.xmm[0] = xmm_from_u32(1, 2, 0xFFFFFFFF, 100);
    add_xmm("cvtdq2ps xmm1,xmm0", {0x0F, 0x5B, 0xC8}, si, 0x2);
  }

  // MOVD/MOVQ — GPR ↔ XMM
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rax = 0x123456789ABCDEF0;

    // MOVQ XMM0, RAX: 66 48 0F 6E C0
    add_xmm("movq xmm0,rax", {0x66, 0x48, 0x0F, 0x6E, 0xC0}, s, 0x1);

    // MOVD XMM0, EAX: 66 0F 6E C0
    add_xmm("movd xmm0,eax", {0x66, 0x0F, 0x6E, 0xC0}, s, 0x1);

    // MOVQ RAX, XMM1: 66 48 0F 7E C8 (reg=1, rm=0 → XMM1 to RAX)
    ArchState s2 = {};
    s2.rflags = 0x2;
    s2.xmm[1] = xmm_from_u64(0xDEADBEEFCAFEBABE, 0x1234567890ABCDEF);
    // MOVQ RAX, XMM1: 66 REX.W 0F 7E C8 (ModRM: reg=xmm1=1, rm=rax=0)
    tests.push_back({"movq rax,xmm1", cat, {0x66, 0x48, 0x0F, 0x7E, 0xC8},
                      s2, FL_ALL, 0x0, false});
  }

  // SSE compare — UCOMISS sets EFLAGS
  {
    ArchState s = {};
    s.rflags = 0x2;

    // Equal
    s.xmm[0] = xmm_from_f32(1.0f, 0, 0, 0);
    s.xmm[1] = xmm_from_f32(1.0f, 0, 0, 0);
    // UCOMISS XMM0, XMM1: 0F 2E C1
    add_xmm("ucomiss eq", {0x0F, 0x2E, 0xC1}, s, 0x0);

    // Less
    s.xmm[0] = xmm_from_f32(1.0f, 0, 0, 0);
    s.xmm[1] = xmm_from_f32(2.0f, 0, 0, 0);
    add_xmm("ucomiss lt", {0x0F, 0x2E, 0xC1}, s, 0x0);

    // Greater
    s.xmm[0] = xmm_from_f32(3.0f, 0, 0, 0);
    s.xmm[1] = xmm_from_f32(2.0f, 0, 0, 0);
    add_xmm("ucomiss gt", {0x0F, 0x2E, 0xC1}, s, 0x0);

    // UCOMISD XMM0, XMM1: 66 0F 2E C1
    s.xmm[0] = xmm_from_f64(1.5, 0);
    s.xmm[1] = xmm_from_f64(1.5, 0);
    add_xmm("ucomisd eq", {0x66, 0x0F, 0x2E, 0xC1}, s, 0x0);

    s.xmm[0] = xmm_from_f64(1.0, 0);
    s.xmm[1] = xmm_from_f64(2.0, 0);
    add_xmm("ucomisd lt", {0x66, 0x0F, 0x2E, 0xC1}, s, 0x0);
  }

  // Upper registers (XMM8+) via REX prefix
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[8]  = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[9]  = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);

    // ADDPS XMM8, XMM9: 45 0F 58 C1 (REX.R+B)
    add_xmm("addps xmm8,xmm9", {0x45, 0x0F, 0x58, 0xC1}, s, 0x300);
  }

  // SSE logical — ANDPS/ANDNPS/ORPS/XORPS
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0xFF00FF00FF00FF00, 0x0F0F0F0F0F0F0F0F);
    s.xmm[1] = xmm_from_u64(0x00FF00FF00FF00FF, 0xF0F0F0F0F0F0F0F0);

    // ANDPS XMM0, XMM1: 0F 54 C1
    add_xmm("andps xmm0,xmm1", {0x0F, 0x54, 0xC1}, s, 0x3);
    // ANDNPS XMM0, XMM1: 0F 55 C1  (NOT(xmm0) AND xmm1)
    add_xmm("andnps xmm0,xmm1", {0x0F, 0x55, 0xC1}, s, 0x3);
    // ORPS XMM0, XMM1: 0F 56 C1
    add_xmm("orps xmm0,xmm1", {0x0F, 0x56, 0xC1}, s, 0x3);
    // XORPS XMM0, XMM1: 0F 57 C1
    add_xmm("xorps xmm0,xmm1", {0x0F, 0x57, 0xC1}, s, 0x3);

    // ANDPD XMM0, XMM1: 66 0F 54 C1
    add_xmm("andpd xmm0,xmm1", {0x66, 0x0F, 0x54, 0xC1}, s, 0x3);
    // ANDNPD XMM0, XMM1: 66 0F 55 C1
    add_xmm("andnpd xmm0,xmm1", {0x66, 0x0F, 0x55, 0xC1}, s, 0x3);
    // ORPD XMM0, XMM1: 66 0F 56 C1
    add_xmm("orpd xmm0,xmm1", {0x66, 0x0F, 0x56, 0xC1}, s, 0x3);
    // XORPD XMM0, XMM1: 66 0F 57 C1
    add_xmm("xorpd xmm0,xmm1", {0x66, 0x0F, 0x57, 0xC1}, s, 0x3);
  }

  // SSE SQRT — SQRTPS/SQRTPD/SQRTSS/SQRTSD
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(4.0f, 9.0f, 16.0f, 25.0f);

    // SQRTPS XMM1, XMM0: 0F 51 C8
    add_xmm("sqrtps xmm1,xmm0", {0x0F, 0x51, 0xC8}, s, 0x2);
    // SQRTSS XMM1, XMM0: F3 0F 51 C8
    add_xmm("sqrtss xmm1,xmm0", {0xF3, 0x0F, 0x51, 0xC8}, s, 0x2);

    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(4.0, 9.0);

    // SQRTPD XMM1, XMM0: 66 0F 51 C8
    add_xmm("sqrtpd xmm1,xmm0", {0x66, 0x0F, 0x51, 0xC8}, sd, 0x2);
    // SQRTSD XMM1, XMM0: F2 0F 51 C8
    add_xmm("sqrtsd xmm1,xmm0", {0xF2, 0x0F, 0x51, 0xC8}, sd, 0x2);
  }

  // SSE MIN/MAX — remaining variants (MINPD/MAXPD/MINSS/MAXSS/MINSD/MAXSD)
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 8.0f, 3.0f, 6.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 2.0f, 7.0f, 4.0f);

    // MINSS XMM0, XMM1: F3 0F 5D C1
    add_xmm("minss xmm0,xmm1", {0xF3, 0x0F, 0x5D, 0xC1}, s, 0x3);
    // MAXSS XMM0, XMM1: F3 0F 5F C1
    add_xmm("maxss xmm0,xmm1", {0xF3, 0x0F, 0x5F, 0xC1}, s, 0x3);

    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(1.5, 8.5);
    sd.xmm[1] = xmm_from_f64(5.5, 2.5);

    // MINPD XMM0, XMM1: 66 0F 5D C1
    add_xmm("minpd xmm0,xmm1", {0x66, 0x0F, 0x5D, 0xC1}, sd, 0x3);
    // MAXPD XMM0, XMM1: 66 0F 5F C1
    add_xmm("maxpd xmm0,xmm1", {0x66, 0x0F, 0x5F, 0xC1}, sd, 0x3);
    // MINSD XMM0, XMM1: F2 0F 5D C1
    add_xmm("minsd xmm0,xmm1", {0xF2, 0x0F, 0x5D, 0xC1}, sd, 0x3);
    // MAXSD XMM0, XMM1: F2 0F 5F C1
    add_xmm("maxsd xmm0,xmm1", {0xF2, 0x0F, 0x5F, 0xC1}, sd, 0x3);
  }

  // SSE comparison — CMPPS/CMPPD
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 5.0f, 3.0f, 3.0f);
    s.xmm[1] = xmm_from_f32(2.0f, 5.0f, 1.0f, 4.0f);

    // CMPPS XMM0, XMM1, 0 (EQ): 0F C2 C1 00
    add_xmm("cmpps eq", {0x0F, 0xC2, 0xC1, 0x00}, s, 0x3);
    // CMPPS XMM0, XMM1, 1 (LT): 0F C2 C1 01
    add_xmm("cmpps lt", {0x0F, 0xC2, 0xC1, 0x01}, s, 0x3);
    // CMPPS XMM0, XMM1, 2 (LE): 0F C2 C1 02
    add_xmm("cmpps le", {0x0F, 0xC2, 0xC1, 0x02}, s, 0x3);

    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(1.0, 5.0);
    sd.xmm[1] = xmm_from_f64(2.0, 5.0);

    // CMPPD XMM0, XMM1, 0 (EQ): 66 0F C2 C1 00
    add_xmm("cmppd eq", {0x66, 0x0F, 0xC2, 0xC1, 0x00}, sd, 0x3);
    // CMPPD XMM0, XMM1, 1 (LT): 66 0F C2 C1 01
    add_xmm("cmppd lt", {0x66, 0x0F, 0xC2, 0xC1, 0x01}, sd, 0x3);

    // CMPSS XMM0, XMM1, 0 (EQ): F3 0F C2 C1 00
    add_xmm("cmpss eq", {0xF3, 0x0F, 0xC2, 0xC1, 0x00}, s, 0x3);
    // CMPSD XMM0, XMM1, 1 (LT): F2 0F C2 C1 01
    add_xmm("cmpsd lt", {0xF2, 0x0F, 0xC2, 0xC1, 0x01}, sd, 0x3);
  }

  // SSE2 integer — PSUBW/PSUBD/PSUBQ, PANDN, PCMPEQB/PCMPEQW/PCMPEQD, PCMPGTB
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x0001020304050607, 0x08090A0B0C0D0E0F);

    // PSUBW XMM0, XMM1: 66 0F F9 C1
    add_xmm("psubw xmm0,xmm1", {0x66, 0x0F, 0xF9, 0xC1}, s, 0x3);
    // PSUBD XMM0, XMM1: 66 0F FA C1
    add_xmm("psubd xmm0,xmm1", {0x66, 0x0F, 0xFA, 0xC1}, s, 0x3);
    // PSUBQ XMM0, XMM1: 66 0F FB C1
    add_xmm("psubq xmm0,xmm1", {0x66, 0x0F, 0xFB, 0xC1}, s, 0x3);
    // PANDN XMM0, XMM1: 66 0F DF C1
    add_xmm("pandn xmm0,xmm1", {0x66, 0x0F, 0xDF, 0xC1}, s, 0x3);

    // PCMPEQB XMM0, XMM1: 66 0F 74 C1
    add_xmm("pcmpeqb xmm0,xmm1", {0x66, 0x0F, 0x74, 0xC1}, s, 0x3);
    // PCMPEQW XMM0, XMM1: 66 0F 75 C1
    add_xmm("pcmpeqw xmm0,xmm1", {0x66, 0x0F, 0x75, 0xC1}, s, 0x3);
    // PCMPEQD XMM0, XMM1: 66 0F 76 C1
    add_xmm("pcmpeqd xmm0,xmm1", {0x66, 0x0F, 0x76, 0xC1}, s, 0x3);
    // PCMPGTB XMM0, XMM1: 66 0F 64 C1
    add_xmm("pcmpgtb xmm0,xmm1", {0x66, 0x0F, 0x64, 0xC1}, s, 0x3);
    // PCMPGTW XMM0, XMM1: 66 0F 65 C1
    add_xmm("pcmpgtw xmm0,xmm1", {0x66, 0x0F, 0x65, 0xC1}, s, 0x3);
    // PCMPGTD XMM0, XMM1: 66 0F 66 C1
    add_xmm("pcmpgtd xmm0,xmm1", {0x66, 0x0F, 0x66, 0xC1}, s, 0x3);
  }

  // SSE2 shuffle — PSHUFD, SHUFPD, UNPCKLPD, UNPCKHPD
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);

    // PSHUFD XMM1, XMM0, 0x1B (reverse): 66 0F 70 C8 1B
    add_xmm("pshufd xmm1,xmm0,0x1b", {0x66, 0x0F, 0x70, 0xC8, 0x1B}, s, 0x2);
    // PSHUFD XMM1, XMM0, 0x00 (broadcast low): 66 0F 70 C8 00
    add_xmm("pshufd xmm1,xmm0,0x00", {0x66, 0x0F, 0x70, 0xC8, 0x00}, s, 0x2);

    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(1.0, 2.0);
    sd.xmm[1] = xmm_from_f64(3.0, 4.0);

    // SHUFPD XMM0, XMM1, 0x01: 66 0F C6 C1 01
    add_xmm("shufpd xmm0,xmm1,0x01", {0x66, 0x0F, 0xC6, 0xC1, 0x01}, sd, 0x3);
    // UNPCKLPD XMM0, XMM1: 66 0F 14 C1
    add_xmm("unpcklpd xmm0,xmm1", {0x66, 0x0F, 0x14, 0xC1}, sd, 0x3);
    // UNPCKHPD XMM0, XMM1: 66 0F 15 C1
    add_xmm("unpckhpd xmm0,xmm1", {0x66, 0x0F, 0x15, 0xC1}, sd, 0x3);
  }

  // SSE2 data movement — MOVAPD/MOVUPD/MOVDQA/MOVDQU
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0xDEADBEEFCAFEBABE, 0x123456789ABCDEF0);

    // MOVAPD XMM2, XMM0: 66 0F 28 D0
    add_xmm("movapd xmm2,xmm0", {0x66, 0x0F, 0x28, 0xD0}, s, 0x4);
    // MOVUPD XMM2, XMM0: 66 0F 10 D0
    add_xmm("movupd xmm2,xmm0", {0x66, 0x0F, 0x10, 0xD0}, s, 0x4);
    // MOVDQA XMM2, XMM0: 66 0F 6F D0
    add_xmm("movdqa xmm2,xmm0", {0x66, 0x0F, 0x6F, 0xD0}, s, 0x4);
    // MOVDQU XMM2, XMM0: F3 0F 6F D0
    add_xmm("movdqu xmm2,xmm0", {0xF3, 0x0F, 0x6F, 0xD0}, s, 0x4);
  }

  // SSE2 pack/unpack integer
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u32(0x00010002, 0x00030004, 0x00050006, 0x00070008);
    s.xmm[1] = xmm_from_u32(0x000A000B, 0x000C000D, 0x000E000F, 0x00100011);

    // PACKSSWB XMM0, XMM1: 66 0F 63 C1
    add_xmm("packsswb xmm0,xmm1", {0x66, 0x0F, 0x63, 0xC1}, s, 0x3);
    // PACKUSWB XMM0, XMM1: 66 0F 67 C1
    add_xmm("packuswb xmm0,xmm1", {0x66, 0x0F, 0x67, 0xC1}, s, 0x3);
    // PACKSSDW XMM0, XMM1: 66 0F 6B C1
    add_xmm("packssdw xmm0,xmm1", {0x66, 0x0F, 0x6B, 0xC1}, s, 0x3);

    // PUNPCKLBW XMM0, XMM1: 66 0F 60 C1
    add_xmm("punpcklbw xmm0,xmm1", {0x66, 0x0F, 0x60, 0xC1}, s, 0x3);
    // PUNPCKLWD XMM0, XMM1: 66 0F 61 C1
    add_xmm("punpcklwd xmm0,xmm1", {0x66, 0x0F, 0x61, 0xC1}, s, 0x3);
    // PUNPCKLDQ XMM0, XMM1: 66 0F 62 C1
    add_xmm("punpckldq xmm0,xmm1", {0x66, 0x0F, 0x62, 0xC1}, s, 0x3);
    // PUNPCKLQDQ XMM0, XMM1: 66 0F 6C C1
    add_xmm("punpcklqdq xmm0,xmm1", {0x66, 0x0F, 0x6C, 0xC1}, s, 0x3);
    // PUNPCKHBW XMM0, XMM1: 66 0F 68 C1
    add_xmm("punpckhbw xmm0,xmm1", {0x66, 0x0F, 0x68, 0xC1}, s, 0x3);
    // PUNPCKHWD XMM0, XMM1: 66 0F 69 C1
    add_xmm("punpckhwd xmm0,xmm1", {0x66, 0x0F, 0x69, 0xC1}, s, 0x3);
    // PUNPCKHDQ XMM0, XMM1: 66 0F 6A C1
    add_xmm("punpckhdq xmm0,xmm1", {0x66, 0x0F, 0x6A, 0xC1}, s, 0x3);
    // PUNPCKHQDQ XMM0, XMM1: 66 0F 6D C1
    add_xmm("punpckhqdq xmm0,xmm1", {0x66, 0x0F, 0x6D, 0xC1}, s, 0x3);
  }

  // SSE2 shift — PSLLW/PSLLD/PSLLQ/PSRLW/PSRLD/PSRLQ/PSRAW/PSRAD (imm8)
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);

    // PSLLW XMM0, 4: 66 0F 71 F0 04
    add_xmm("psllw xmm0,4", {0x66, 0x0F, 0x71, 0xF0, 0x04}, s, 0x1);
    // PSLLD XMM0, 4: 66 0F 72 F0 04
    add_xmm("pslld xmm0,4", {0x66, 0x0F, 0x72, 0xF0, 0x04}, s, 0x1);
    // PSLLQ XMM0, 4: 66 0F 73 F0 04
    add_xmm("psllq xmm0,4", {0x66, 0x0F, 0x73, 0xF0, 0x04}, s, 0x1);
    // PSRLW XMM0, 4: 66 0F 71 D0 04
    add_xmm("psrlw xmm0,4", {0x66, 0x0F, 0x71, 0xD0, 0x04}, s, 0x1);
    // PSRLD XMM0, 4: 66 0F 72 D0 04
    add_xmm("psrld xmm0,4", {0x66, 0x0F, 0x72, 0xD0, 0x04}, s, 0x1);
    // PSRLQ XMM0, 4: 66 0F 73 D0 04
    add_xmm("psrlq xmm0,4", {0x66, 0x0F, 0x73, 0xD0, 0x04}, s, 0x1);
    // PSRAW XMM0, 4: 66 0F 71 E0 04
    add_xmm("psraw xmm0,4", {0x66, 0x0F, 0x71, 0xE0, 0x04}, s, 0x1);
    // PSRAD XMM0, 4: 66 0F 72 E0 04
    add_xmm("psrad xmm0,4", {0x66, 0x0F, 0x72, 0xE0, 0x04}, s, 0x1);
  }

  // SSE2 multiply — PMULLW/PMULHW/PMULHUW/PMULUDQ/PMADDWD
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
    s.xmm[1] = xmm_from_u64(0x0010002000300040, 0x0050006000700080);

    // PMULLW XMM0, XMM1: 66 0F D5 C1
    add_xmm("pmullw xmm0,xmm1", {0x66, 0x0F, 0xD5, 0xC1}, s, 0x3);
    // PMULHW XMM0, XMM1: 66 0F E5 C1
    add_xmm("pmulhw xmm0,xmm1", {0x66, 0x0F, 0xE5, 0xC1}, s, 0x3);
    // PMULHUW XMM0, XMM1: 66 0F E4 C1
    add_xmm("pmulhuw xmm0,xmm1", {0x66, 0x0F, 0xE4, 0xC1}, s, 0x3);
    // PMULUDQ XMM0, XMM1: 66 0F F4 C1
    add_xmm("pmuludq xmm0,xmm1", {0x66, 0x0F, 0xF4, 0xC1}, s, 0x3);
    // PMADDWD XMM0, XMM1: 66 0F F5 C1
    add_xmm("pmaddwd xmm0,xmm1", {0x66, 0x0F, 0xF5, 0xC1}, s, 0x3);
  }

  // SSE2 saturating arithmetic — PADDSB/PADDSW/PADDUSB/PADDUSW/PSUBSB/PSUBSW/PSUBUSB/PSUBUSW
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x7F80FF01FE027E81, 0x7FFF800100FEFF01);
    s.xmm[1] = xmm_from_u64(0x0180017F01FE8001, 0x00017FFF01010101);

    // PADDSB XMM0, XMM1: 66 0F EC C1
    add_xmm("paddsb xmm0,xmm1", {0x66, 0x0F, 0xEC, 0xC1}, s, 0x3);
    // PADDSW XMM0, XMM1: 66 0F ED C1
    add_xmm("paddsw xmm0,xmm1", {0x66, 0x0F, 0xED, 0xC1}, s, 0x3);
    // PADDUSB XMM0, XMM1: 66 0F DC C1
    add_xmm("paddusb xmm0,xmm1", {0x66, 0x0F, 0xDC, 0xC1}, s, 0x3);
    // PADDUSW XMM0, XMM1: 66 0F DD C1
    add_xmm("paddusw xmm0,xmm1", {0x66, 0x0F, 0xDD, 0xC1}, s, 0x3);
    // PSUBSB XMM0, XMM1: 66 0F E8 C1
    add_xmm("psubsb xmm0,xmm1", {0x66, 0x0F, 0xE8, 0xC1}, s, 0x3);
    // PSUBSW XMM0, XMM1: 66 0F E9 C1
    add_xmm("psubsw xmm0,xmm1", {0x66, 0x0F, 0xE9, 0xC1}, s, 0x3);
    // PSUBUSB XMM0, XMM1: 66 0F D8 C1
    add_xmm("psubusb xmm0,xmm1", {0x66, 0x0F, 0xD8, 0xC1}, s, 0x3);
    // PSUBUSW XMM0, XMM1: 66 0F D9 C1
    add_xmm("psubusw xmm0,xmm1", {0x66, 0x0F, 0xD9, 0xC1}, s, 0x3);
  }

  // SSE2 average/SAD — PAVGB/PAVGW/PSADBW
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x1011121314151617, 0x18191A1B1C1D1E1F);

    // PAVGB XMM0, XMM1: 66 0F E0 C1
    add_xmm("pavgb xmm0,xmm1", {0x66, 0x0F, 0xE0, 0xC1}, s, 0x3);
    // PAVGW XMM0, XMM1: 66 0F E3 C1
    add_xmm("pavgw xmm0,xmm1", {0x66, 0x0F, 0xE3, 0xC1}, s, 0x3);
    // PSADBW XMM0, XMM1: 66 0F F6 C1
    add_xmm("psadbw xmm0,xmm1", {0x66, 0x0F, 0xF6, 0xC1}, s, 0x3);
  }

  // NOTE: RCPPS/RCPSS/RSQRTPS/RSQRTSS are approximate instructions with
  // implementation-defined precision, so we cannot do exact comparison.

  // SSE2 PSHUFHW/PSHUFLW
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);

    // PSHUFHW XMM1, XMM0, 0x1B: F3 0F 70 C8 1B
    add_xmm("pshufhw xmm1,xmm0,0x1b", {0xF3, 0x0F, 0x70, 0xC8, 0x1B}, s, 0x2);
    // PSHUFLW XMM1, XMM0, 0x1B: F2 0F 70 C8 1B
    add_xmm("pshuflw xmm1,xmm0,0x1b", {0xF2, 0x0F, 0x70, 0xC8, 0x1B}, s, 0x2);
  }

  add_systematic_tests(tests);

  return tests;
}


int main(int argc, char **argv) {
  const char *filter = argc > 1 ? argv[1] : nullptr;

  KvmVm vm;
  if (!vm.init()) {
    fprintf(stderr, "Failed to initialize KVM VM\n");
    return 1;
  }

  auto tests = build_tests();
  int passed = 0, failed = 0;
  std::string last_cat;

  for (const auto &tc : tests) {
    if (filter && tc.category.compare(0, strlen(filter), filter) != 0)
      continue;
    if (tc.category != last_cat) {
      last_cat = tc.category;
      fprintf(stderr, "Testing %s ...\n", last_cat.c_str());
    }
    // Run on KVM.
    vm.load_test(tc);
    ArchState kvm_state = vm.run_test();

    // Run on Sail.
    u8 kvm_data[4096] = {}, sail_data[4096] = {};
    if (tc.compare_data_len > 0)
      vm.read_data(kvm_data, tc.compare_data_len);

    ArchState sail_state = run_sail(tc, sail_data, tc.compare_data_len);

    // Compare registers.
    bool ok = kvm_state.compare(sail_state, tc.flags_mask, tc.xmm_mask,
                                tc.cmp_mxcsr);

    // Compare memory.
    if (tc.compare_data_len > 0 &&
        memcmp(kvm_data, sail_data, tc.compare_data_len) != 0) {
      ok = false;
    }

    if (ok) {
      passed++;
    } else {
      fprintf(stderr, "FAIL: %s\n", tc.name.c_str());
      kvm_state.print("KVM");
      sail_state.print("Sail");
      if (tc.compare_data_len > 0 &&
          memcmp(kvm_data, sail_data, tc.compare_data_len) != 0) {
        fprintf(stderr, "  DATA MISMATCH (%zu bytes):\n", tc.compare_data_len);
        fprintf(stderr, "    KVM: ");
        for (size_t i = 0; i < tc.compare_data_len; i++)
          fprintf(stderr, "%02x", kvm_data[i]);
        fprintf(stderr, "\n    Sail:");
        for (size_t i = 0; i < tc.compare_data_len; i++)
          fprintf(stderr, "%02x", sail_data[i]);
        fprintf(stderr, "\n");
      }
      failed++;
    }
  }

  fprintf(stderr, "%d passed, %d failed out of %d tests\n",
          passed, failed, passed + failed);
  return failed > 0 ? 1 : 0;
}

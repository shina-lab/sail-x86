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

    // Set up CPUID with host-supported features (needed for AVX, XSAVE, etc.)
    {
      size_t buf_size = sizeof(struct kvm_cpuid2) + 256 * sizeof(struct kvm_cpuid_entry2);
      auto buf = std::vector<u8>(buf_size, 0);
      auto *cpuid = (struct kvm_cpuid2 *)buf.data();
      cpuid->nent = 256;
      if (ioctl(kvm_fd, KVM_GET_SUPPORTED_CPUID, cpuid) < 0)
        perror("KVM_GET_SUPPORTED_CPUID");
      else if (ioctl(vcpu_fd, KVM_SET_CPUID2, cpuid) < 0)
        perror("KVM_SET_CPUID2");
    }

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
    sregs.cr4 = 0x40620;     // PAE + OSFXSR + OSXMMEXCPT + OSXSAVE
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

    // Enable AVX in XCR0: bit 0 (x87), bit 1 (SSE), bit 2 (AVX)
    struct kvm_xcrs xcrs = {};
    xcrs.nr_xcrs = 1;
    xcrs.xcrs[0].xcr = 0;  // XCR0
    xcrs.xcrs[0].value = 0xE7;  // x87 + SSE + AVX + opmask + ZMM_Hi256 + Hi16_ZMM
    int xcr_ret = ioctl(vcpu_fd, KVM_SET_XCRS, &xcrs);
    if (xcr_ret < 0)
      fprintf(stderr, "KVM_SET_XCRS failed: %s\n", strerror(errno));

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

    // Set XMM registers, MXCSR, and x87 state via XSAVE.
    struct kvm_xsave xsave;
    memset(&xsave, 0, sizeof(xsave));
    u8 *xs = (u8 *)&xsave;
    // x87 state: FCW=0x037F (default), FSW=0, FTW=0xFF (all empty)
    u16 fcw = 0x037F;
    memcpy(xs + 0, &fcw, 2);     // FCW
    // FSW at offset 2 = 0 (TOP=0, all flags clear) — already zero from memset
    // Abridged FTW: 0 = empty, 1 = valid. 0x00 = all empty.
    // (Already zero from memset)
    // ST(0)-ST(7) at offset 32, 16 bytes stride — already zero from memset
    // MXCSR at offset 0x18
    memcpy(xs + 0x18, &tc.initial.mxcsr, 4);
    // XMM0-XMM15 at offset 0xA0 (16 bytes each)
    for (int i = 0; i < 16; i++) {
      memcpy(xs + 0xA0 + i * 16,     &tc.initial.xmm[i].lo, 8);
      memcpy(xs + 0xA0 + i * 16 + 8, &tc.initial.xmm[i].hi, 8);
    }
    // XSTATE_BV at offset 0x200: set bit 0 (x87) + bit 1 (SSE) so KVM loads state.
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

  // Initialize x87 FPU to default state (CW=0x037F, etc.)
  model.zx87_init(UNIT);

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
      fprintf(stderr, "Sail: fault #%ld (error 0x%x) at RIP=0x%lx [%s]\n",
              vec, err, model.zRIP, tc.name.c_str());
      // Print code bytes for debugging
      fprintf(stderr, "  code bytes:");
      for (size_t j = 0; j < tc.code.size(); j++)
        fprintf(stderr, " %02x", tc.code[j]);
      fprintf(stderr, "\n");
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

  // SSE conversions — remaining variants
  {
    // CVTDQ2PD: F3 0F E6 C8 (xmm1,xmm0)
    ArchState si = {};
    si.rflags = 0x2;
    si.xmm[0] = xmm_from_u32(1, 0xFFFFFFFF, 100, 0);  // low 2 dwords used
    add_xmm("cvtdq2pd xmm1,xmm0", {0xF3, 0x0F, 0xE6, 0xC8}, si, 0x2);

    // CVTPD2DQ: F2 0F E6 C8 (xmm1,xmm0)
    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(1.5, -2.5);
    add_xmm("cvtpd2dq xmm1,xmm0", {0xF2, 0x0F, 0xE6, 0xC8}, sd, 0x2);

    // CVTTPD2DQ: 66 0F E6 C8 (xmm1,xmm0)
    add_xmm("cvttpd2dq xmm1,xmm0", {0x66, 0x0F, 0xE6, 0xC8}, sd, 0x2);

    // CVTPS2PD: 0F 5A C8 (xmm1,xmm0)
    ArchState sp = {};
    sp.rflags = 0x2;
    sp.xmm[0] = xmm_from_f32(1.5f, -2.5f, 3.0f, 4.0f);
    add_xmm("cvtps2pd xmm1,xmm0", {0x0F, 0x5A, 0xC8}, sp, 0x2);

    // CVTPD2PS: 66 0F 5A C8 (xmm1,xmm0)
    add_xmm("cvtpd2ps xmm1,xmm0", {0x66, 0x0F, 0x5A, 0xC8}, sd, 0x2);

    // CVTSS2SD: F3 0F 5A C8 (xmm1,xmm0)
    add_xmm("cvtss2sd xmm1,xmm0", {0xF3, 0x0F, 0x5A, 0xC8}, sp, 0x2);

    // CVTSD2SS: F2 0F 5A C8 (xmm1,xmm0)
    add_xmm("cvtsd2ss xmm1,xmm0", {0xF2, 0x0F, 0x5A, 0xC8}, sd, 0x2);

    // CVTSI2SS: F3 0F 2A C0 (xmm0,eax)
    ArchState sg = {};
    sg.rflags = 0x2;
    sg.rax = 42;
    add_xmm("cvtsi2ss xmm0,eax", {0xF3, 0x0F, 0x2A, 0xC0}, sg, 0x1);

    // CVTSI2SD: F2 0F 2A C0 (xmm0,eax)
    add_xmm("cvtsi2sd xmm0,eax", {0xF2, 0x0F, 0x2A, 0xC0}, sg, 0x1);

    // CVTSI2SS with REX.W (64-bit): F3 48 0F 2A C0 (xmm0,rax)
    ArchState sg64 = {};
    sg64.rflags = 0x2;
    sg64.rax = 0x100000042;
    add_xmm("cvtsi2ss xmm0,rax", {0xF3, 0x48, 0x0F, 0x2A, 0xC0}, sg64, 0x1);

    // CVTSI2SD with REX.W: F2 48 0F 2A C0 (xmm0,rax)
    add_xmm("cvtsi2sd xmm0,rax", {0xF2, 0x48, 0x0F, 0x2A, 0xC0}, sg64, 0x1);

    // CVTSS2SI: F3 0F 2D C0 (eax,xmm0) — result in RAX
    ArchState sf = {};
    sf.rflags = 0x2;
    sf.xmm[0] = xmm_from_f32(42.5f, 0, 0, 0);
    tests.push_back({"cvtss2si eax,xmm0", cat, {0xF3, 0x0F, 0x2D, 0xC0},
                      sf, FL_ALL, 0x0, false});

    // CVTSD2SI: F2 0F 2D C0 (eax,xmm0)
    ArchState sfd = {};
    sfd.rflags = 0x2;
    sfd.xmm[0] = xmm_from_f64(42.5, 0);
    tests.push_back({"cvtsd2si eax,xmm0", cat, {0xF2, 0x0F, 0x2D, 0xC0},
                      sfd, FL_ALL, 0x0, false});

    // CVTTSS2SI: F3 0F 2C C0 (eax,xmm0)
    tests.push_back({"cvttss2si eax,xmm0", cat, {0xF3, 0x0F, 0x2C, 0xC0},
                      sf, FL_ALL, 0x0, false});

    // CVTTSD2SI: F2 0F 2C C0 (eax,xmm0)
    tests.push_back({"cvttsd2si eax,xmm0", cat, {0xF2, 0x0F, 0x2C, 0xC0},
                      sfd, FL_ALL, 0x0, false});
  }

  // COMISS/COMISD — ordered compare, set EFLAGS
  {
    ArchState s = {};
    s.rflags = 0x2;

    s.xmm[0] = xmm_from_f32(1.0f, 0, 0, 0);
    s.xmm[1] = xmm_from_f32(2.0f, 0, 0, 0);
    // COMISS XMM0, XMM1: 0F 2F C1
    add_xmm("comiss lt", {0x0F, 0x2F, 0xC1}, s, 0x0);

    s.xmm[1] = xmm_from_f32(1.0f, 0, 0, 0);
    add_xmm("comiss eq", {0x0F, 0x2F, 0xC1}, s, 0x0);

    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(3.0, 0);
    sd.xmm[1] = xmm_from_f64(1.0, 0);
    // COMISD XMM0, XMM1: 66 0F 2F C1
    add_xmm("comisd gt", {0x66, 0x0F, 0x2F, 0xC1}, sd, 0x0);
  }

  // PSLLDQ/PSRLDQ — byte shift
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);

    // PSLLDQ XMM0, 3: 66 0F 73 F8 03 (ModRM /7, rm=xmm0)
    add_xmm("pslldq xmm0,3", {0x66, 0x0F, 0x73, 0xF8, 0x03}, s, 0x1);
    // PSRLDQ XMM0, 3: 66 0F 73 D8 03 (ModRM /3, rm=xmm0)
    add_xmm("psrldq xmm0,3", {0x66, 0x0F, 0x73, 0xD8, 0x03}, s, 0x1);
  }

  // MOVHLPS/MOVLHPS — reg-reg forms
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // MOVHLPS XMM0, XMM1: 0F 12 C1 (move high half of xmm1 to low half of xmm0)
    add_xmm("movhlps xmm0,xmm1", {0x0F, 0x12, 0xC1}, s, 0x3);
    // MOVLHPS XMM0, XMM1: 0F 16 C1 (move low half of xmm1 to high half of xmm0)
    add_xmm("movlhps xmm0,xmm1", {0x0F, 0x16, 0xC1}, s, 0x3);
  }

  // MOVSS/MOVSD — reg-reg forms (merge into low element)
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);

    // MOVSS XMM0, XMM1: F3 0F 10 C1 (merge low dword of xmm1 into xmm0)
    add_xmm("movss xmm0,xmm1", {0xF3, 0x0F, 0x10, 0xC1}, s, 0x3);

    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(1.5, 2.5);
    sd.xmm[1] = xmm_from_f64(10.5, 20.5);

    // MOVSD XMM0, XMM1: F2 0F 10 C1 (merge low qword of xmm1 into xmm0)
    add_xmm("movsd xmm0,xmm1", {0xF2, 0x0F, 0x10, 0xC1}, sd, 0x3);
  }

  // PINSRW/PEXTRW
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rax = 0x1234;
    s.xmm[0] = xmm_from_u64(0, 0);

    // PINSRW XMM0, EAX, 3: 66 0F C4 C0 03
    add_xmm("pinsrw xmm0,eax,3", {0x66, 0x0F, 0xC4, 0xC0, 0x03}, s, 0x1);

    // PEXTRW EAX, XMM1, 2: 66 0F C5 C1 02
    ArchState s2 = {};
    s2.rflags = 0x2;
    s2.xmm[1] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
    tests.push_back({"pextrw eax,xmm1,2", cat, {0x66, 0x0F, 0xC5, 0xC1, 0x02},
                      s2, FL_ALL, 0x0, false});
  }

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

  // =====================================================================
  // 24. SSSE3 — supplemental SSE3 integer instructions
  // =====================================================================
  cat = "SSSE3";

  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x0003020100070605, 0x0403020108070605);

    // PSHUFB XMM0, XMM1: 66 0F 38 00 C1
    add_xmm("pshufb xmm0,xmm1", {0x66, 0x0F, 0x38, 0x00, 0xC1}, s, 0x3);
  }

  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
    s.xmm[1] = xmm_from_u64(0x0010002000300040, 0x0050006000700080);

    // PHADDW XMM0, XMM1: 66 0F 38 01 C1
    add_xmm("phaddw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x01, 0xC1}, s, 0x3);
    // PHADDD XMM0, XMM1: 66 0F 38 02 C1
    add_xmm("phaddd xmm0,xmm1", {0x66, 0x0F, 0x38, 0x02, 0xC1}, s, 0x3);
    // PHADDSW XMM0, XMM1: 66 0F 38 03 C1
    add_xmm("phaddsw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x03, 0xC1}, s, 0x3);
    // PHSUBW XMM0, XMM1: 66 0F 38 05 C1
    add_xmm("phsubw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x05, 0xC1}, s, 0x3);
    // PHSUBD XMM0, XMM1: 66 0F 38 06 C1
    add_xmm("phsubd xmm0,xmm1", {0x66, 0x0F, 0x38, 0x06, 0xC1}, s, 0x3);
    // PHSUBSW XMM0, XMM1: 66 0F 38 07 C1
    add_xmm("phsubsw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x07, 0xC1}, s, 0x3);

    // PMADDUBSW XMM0, XMM1: 66 0F 38 04 C1
    add_xmm("pmaddubsw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x04, 0xC1}, s, 0x3);
    // PMULHRSW XMM0, XMM1: 66 0F 38 0B C1
    add_xmm("pmulhrsw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x0B, 0xC1}, s, 0x3);
  }

  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x01FF037F05816082, 0x7FFFFFFF80000001);

    // PABSB XMM1, XMM0: 66 0F 38 1C C8
    add_xmm("pabsb xmm1,xmm0", {0x66, 0x0F, 0x38, 0x1C, 0xC8}, s, 0x2);
    // PABSW XMM1, XMM0: 66 0F 38 1D C8
    add_xmm("pabsw xmm1,xmm0", {0x66, 0x0F, 0x38, 0x1D, 0xC8}, s, 0x2);
    // PABSD XMM1, XMM0: 66 0F 38 1E C8
    add_xmm("pabsd xmm1,xmm0", {0x66, 0x0F, 0x38, 0x1E, 0xC8}, s, 0x2);
  }

  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x01FF037F05816082, 0x7FFFFFFF80000001);
    s.xmm[1] = xmm_from_u64(0x0001000100010001, 0xFFFF0000FFFF0000);

    // PSIGNB XMM0, XMM1: 66 0F 38 08 C1
    add_xmm("psignb xmm0,xmm1", {0x66, 0x0F, 0x38, 0x08, 0xC1}, s, 0x3);
    // PSIGNW XMM0, XMM1: 66 0F 38 09 C1
    add_xmm("psignw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x09, 0xC1}, s, 0x3);
    // PSIGND XMM0, XMM1: 66 0F 38 0A C1
    add_xmm("psignd xmm0,xmm1", {0x66, 0x0F, 0x38, 0x0A, 0xC1}, s, 0x3);
  }

  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // PALIGNR XMM0, XMM1, 4: 66 0F 3A 0F C1 04
    add_xmm("palignr xmm0,xmm1,4", {0x66, 0x0F, 0x3A, 0x0F, 0xC1, 0x04}, s, 0x3);
  }

  // =====================================================================
  // 25. SSE4.1 instructions
  // =====================================================================
  cat = "SSE4.1";

  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x01FF037F05816082, 0x7FFFFFFF80000001);
    s.xmm[1] = xmm_from_u64(0x02FE027E04806183, 0x80000000FFFFFFFF);

    // PMAXSB XMM0, XMM1: 66 0F 38 3C C1
    add_xmm("pmaxsb xmm0,xmm1", {0x66, 0x0F, 0x38, 0x3C, 0xC1}, s, 0x3);
    // PMAXSD XMM0, XMM1: 66 0F 38 3D C1
    add_xmm("pmaxsd xmm0,xmm1", {0x66, 0x0F, 0x38, 0x3D, 0xC1}, s, 0x3);
    // PMAXUW XMM0, XMM1: 66 0F 38 3E C1
    add_xmm("pmaxuw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x3E, 0xC1}, s, 0x3);
    // PMAXUD XMM0, XMM1: 66 0F 38 3F C1
    add_xmm("pmaxud xmm0,xmm1", {0x66, 0x0F, 0x38, 0x3F, 0xC1}, s, 0x3);

    // PMINSB XMM0, XMM1: 66 0F 38 38 C1
    add_xmm("pminsb xmm0,xmm1", {0x66, 0x0F, 0x38, 0x38, 0xC1}, s, 0x3);
    // PMINSD XMM0, XMM1: 66 0F 38 39 C1
    add_xmm("pminsd xmm0,xmm1", {0x66, 0x0F, 0x38, 0x39, 0xC1}, s, 0x3);
    // PMINUW XMM0, XMM1: 66 0F 38 3A C1
    add_xmm("pminuw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x3A, 0xC1}, s, 0x3);
    // PMINUD XMM0, XMM1: 66 0F 38 3B C1
    add_xmm("pminud xmm0,xmm1", {0x66, 0x0F, 0x38, 0x3B, 0xC1}, s, 0x3);

    // PMAXSW (SSE2): 66 0F EE C1
    add_xmm("pmaxsw xmm0,xmm1", {0x66, 0x0F, 0xEE, 0xC1}, s, 0x3);
    // PMINSW (SSE2): 66 0F EA C1
    add_xmm("pminsw xmm0,xmm1", {0x66, 0x0F, 0xEA, 0xC1}, s, 0x3);
    // PMAXUB (SSE2): 66 0F DE C1
    add_xmm("pmaxub xmm0,xmm1", {0x66, 0x0F, 0xDE, 0xC1}, s, 0x3);
    // PMINUB (SSE2): 66 0F DA C1
    add_xmm("pminub xmm0,xmm1", {0x66, 0x0F, 0xDA, 0xC1}, s, 0x3);

    // PMULLD XMM0, XMM1: 66 0F 38 40 C1
    add_xmm("pmulld xmm0,xmm1", {0x66, 0x0F, 0x38, 0x40, 0xC1}, s, 0x3);

    // PACKUSDW XMM0, XMM1: 66 0F 38 2B C1
    add_xmm("packusdw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x2B, 0xC1}, s, 0x3);

    // PCMPEQQ XMM0, XMM1: 66 0F 38 29 C1
    add_xmm("pcmpeqq xmm0,xmm1", {0x66, 0x0F, 0x38, 0x29, 0xC1}, s, 0x3);
  }

  // PINSRB/PINSRD/PEXTRB/PEXTRD
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rax = 0x42;
    s.xmm[0] = xmm_from_u64(0, 0);

    // PINSRB XMM0, EAX, 5: 66 0F 3A 20 C0 05
    add_xmm("pinsrb xmm0,eax,5", {0x66, 0x0F, 0x3A, 0x20, 0xC0, 0x05}, s, 0x1);
    // PINSRD XMM0, EAX, 2: 66 0F 3A 22 C0 02
    add_xmm("pinsrd xmm0,eax,2", {0x66, 0x0F, 0x3A, 0x22, 0xC0, 0x02}, s, 0x1);

    ArchState s2 = {};
    s2.rflags = 0x2;
    s2.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);

    // PEXTRB EAX, XMM0, 5: 66 0F 3A 14 C0 05
    tests.push_back({"pextrb eax,xmm0,5", cat, {0x66, 0x0F, 0x3A, 0x14, 0xC0, 0x05},
                      s2, FL_ALL, 0x0, false});
    // PEXTRD EAX, XMM0, 2: 66 0F 3A 16 C0 02
    tests.push_back({"pextrd eax,xmm0,2", cat, {0x66, 0x0F, 0x3A, 0x16, 0xC0, 0x02},
                      s2, FL_ALL, 0x0, false});
  }

  // EXTRACTPS/INSERTPS
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);

    // EXTRACTPS EAX, XMM0, 2: 66 0F 3A 17 C0 02
    tests.push_back({"extractps eax,xmm0,2", cat, {0x66, 0x0F, 0x3A, 0x17, 0xC0, 0x02},
                      s, FL_ALL, 0x0, false});

    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    // INSERTPS XMM0, XMM1, 0x1A: 66 0F 3A 21 C1 1A (src[1] -> dst[2], zero mask=0b1010)
    add_xmm("insertps xmm0,xmm1,0x1a", {0x66, 0x0F, 0x3A, 0x21, 0xC1, 0x1A}, s, 0x3);
  }

  // BLENDPS/BLENDPD/PBLENDW
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);

    // BLENDPS XMM0, XMM1, 0x0A: 66 0F 3A 0C C1 0A (blend elements 1,3)
    add_xmm("blendps xmm0,xmm1,0x0a", {0x66, 0x0F, 0x3A, 0x0C, 0xC1, 0x0A}, s, 0x3);

    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(1.0, 2.0);
    sd.xmm[1] = xmm_from_f64(10.0, 20.0);

    // BLENDPD XMM0, XMM1, 0x02: 66 0F 3A 0D C1 02 (blend element 1)
    add_xmm("blendpd xmm0,xmm1,0x02", {0x66, 0x0F, 0x3A, 0x0D, 0xC1, 0x02}, sd, 0x3);

    ArchState si = {};
    si.rflags = 0x2;
    si.xmm[0] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
    si.xmm[1] = xmm_from_u64(0x0010002000300040, 0x0050006000700080);

    // PBLENDW XMM0, XMM1, 0xAA: 66 0F 3A 0E C1 AA (blend alternate words)
    add_xmm("pblendw xmm0,xmm1,0xaa", {0x66, 0x0F, 0x3A, 0x0E, 0xC1, 0xAA}, si, 0x3);
  }

  // ROUNDPS/ROUNDPD/ROUNDSS/ROUNDSD
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.3f, 2.7f, -1.5f, -2.5f);

    // ROUNDPS XMM1, XMM0, 0 (round nearest): 66 0F 3A 08 C8 00
    add_xmm("roundps nearest", {0x66, 0x0F, 0x3A, 0x08, 0xC8, 0x00}, s, 0x2);
    // ROUNDPS XMM1, XMM0, 1 (floor): 66 0F 3A 08 C8 01
    add_xmm("roundps floor", {0x66, 0x0F, 0x3A, 0x08, 0xC8, 0x01}, s, 0x2);
    // ROUNDPS XMM1, XMM0, 2 (ceil): 66 0F 3A 08 C8 02
    add_xmm("roundps ceil", {0x66, 0x0F, 0x3A, 0x08, 0xC8, 0x02}, s, 0x2);
    // ROUNDPS XMM1, XMM0, 3 (truncate): 66 0F 3A 08 C8 03
    add_xmm("roundps trunc", {0x66, 0x0F, 0x3A, 0x08, 0xC8, 0x03}, s, 0x2);

    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(1.3, -2.7);

    // ROUNDPD XMM1, XMM0, 0: 66 0F 3A 09 C8 00
    add_xmm("roundpd nearest", {0x66, 0x0F, 0x3A, 0x09, 0xC8, 0x00}, sd, 0x2);
    // ROUNDPD XMM1, XMM0, 1: 66 0F 3A 09 C8 01
    add_xmm("roundpd floor", {0x66, 0x0F, 0x3A, 0x09, 0xC8, 0x01}, sd, 0x2);

    // ROUNDSS XMM1, XMM0, 0: 66 0F 3A 0A C8 00
    add_xmm("roundss nearest", {0x66, 0x0F, 0x3A, 0x0A, 0xC8, 0x00}, s, 0x2);
    // ROUNDSD XMM1, XMM0, 1: 66 0F 3A 0B C8 01
    add_xmm("roundsd floor", {0x66, 0x0F, 0x3A, 0x0B, 0xC8, 0x01}, sd, 0x2);
  }

  // PTEST — sets ZF and CF in EFLAGS
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0xFF00FF00FF00FF00, 0x00FF00FF00FF00FF);
    s.xmm[1] = xmm_from_u64(0x00FF00FF00FF00FF, 0xFF00FF00FF00FF00);

    // PTEST XMM0, XMM1: 66 0F 38 17 C1 (AND is zero → ZF=1)
    add_xmm("ptest zero", {0x66, 0x0F, 0x38, 0x17, 0xC1}, s, 0x0);

    s.xmm[1] = s.xmm[0];
    // PTEST XMM0, XMM0: same bits → ZF=0
    add_xmm("ptest nonzero", {0x66, 0x0F, 0x38, 0x17, 0xC1}, s, 0x0);
  }

  // PMOVZX — zero-extend packed integers
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0);

    // PMOVZXBW XMM1, XMM0: 66 0F 38 30 C8
    add_xmm("pmovzxbw xmm1,xmm0", {0x66, 0x0F, 0x38, 0x30, 0xC8}, s, 0x2);
    // PMOVZXBD XMM1, XMM0: 66 0F 38 31 C8
    add_xmm("pmovzxbd xmm1,xmm0", {0x66, 0x0F, 0x38, 0x31, 0xC8}, s, 0x2);
    // PMOVZXBQ XMM1, XMM0: 66 0F 38 32 C8
    add_xmm("pmovzxbq xmm1,xmm0", {0x66, 0x0F, 0x38, 0x32, 0xC8}, s, 0x2);
    // PMOVZXWD XMM1, XMM0: 66 0F 38 33 C8
    add_xmm("pmovzxwd xmm1,xmm0", {0x66, 0x0F, 0x38, 0x33, 0xC8}, s, 0x2);
    // PMOVZXWQ XMM1, XMM0: 66 0F 38 34 C8
    add_xmm("pmovzxwq xmm1,xmm0", {0x66, 0x0F, 0x38, 0x34, 0xC8}, s, 0x2);
    // PMOVZXDQ XMM1, XMM0: 66 0F 38 35 C8
    add_xmm("pmovzxdq xmm1,xmm0", {0x66, 0x0F, 0x38, 0x35, 0xC8}, s, 0x2);
  }

  // PMOVSX — sign-extend packed integers
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x01FF037F05816082, 0);

    // PMOVSXBW XMM1, XMM0: 66 0F 38 20 C8
    add_xmm("pmovsxbw xmm1,xmm0", {0x66, 0x0F, 0x38, 0x20, 0xC8}, s, 0x2);
    // PMOVSXBD XMM1, XMM0: 66 0F 38 21 C8
    add_xmm("pmovsxbd xmm1,xmm0", {0x66, 0x0F, 0x38, 0x21, 0xC8}, s, 0x2);
    // PMOVSXBQ XMM1, XMM0: 66 0F 38 22 C8
    add_xmm("pmovsxbq xmm1,xmm0", {0x66, 0x0F, 0x38, 0x22, 0xC8}, s, 0x2);
    // PMOVSXWD XMM1, XMM0: 66 0F 38 23 C8
    add_xmm("pmovsxwd xmm1,xmm0", {0x66, 0x0F, 0x38, 0x23, 0xC8}, s, 0x2);
    // PMOVSXWQ XMM1, XMM0: 66 0F 38 24 C8
    add_xmm("pmovsxwq xmm1,xmm0", {0x66, 0x0F, 0x38, 0x24, 0xC8}, s, 0x2);
    // PMOVSXDQ XMM1, XMM0: 66 0F 38 25 C8
    add_xmm("pmovsxdq xmm1,xmm0", {0x66, 0x0F, 0x38, 0x25, 0xC8}, s, 0x2);
  }

  // DPPS/DPPD — dot product
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // DPPS XMM0, XMM1, 0xFF: 66 0F 3A 40 C1 FF (all elements, broadcast result)
    add_xmm("dpps xmm0,xmm1,0xff", {0x66, 0x0F, 0x3A, 0x40, 0xC1, 0xFF}, s, 0x3);
    // DPPS XMM0, XMM1, 0x71: first 3 elements, result to element 0 only
    add_xmm("dpps xmm0,xmm1,0x71", {0x66, 0x0F, 0x3A, 0x40, 0xC1, 0x71}, s, 0x3);

    ArchState sd = {};
    sd.rflags = 0x2;
    sd.xmm[0] = xmm_from_f64(1.5, 2.5);
    sd.xmm[1] = xmm_from_f64(3.0, 4.0);

    // DPPD XMM0, XMM1, 0x33: 66 0F 3A 41 C1 33 (both elements, broadcast)
    add_xmm("dppd xmm0,xmm1,0x33", {0x66, 0x0F, 0x3A, 0x41, 0xC1, 0x33}, sd, 0x3);
  }

  // MPSADBW
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // MPSADBW XMM0, XMM1, 0: 66 0F 3A 42 C1 00
    add_xmm("mpsadbw xmm0,xmm1,0", {0x66, 0x0F, 0x3A, 0x42, 0xC1, 0x00}, s, 0x3);
  }

  // =====================================================================
  // 26. SSE4.2 instructions
  // =====================================================================
  cat = "SSE4.2";

  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x0001020304050607, 0x08090A0B0C0D0E0F);

    // PCMPGTQ XMM0, XMM1: 66 0F 38 37 C1
    add_xmm("pcmpgtq xmm0,xmm1", {0x66, 0x0F, 0x38, 0x37, 0xC1}, s, 0x3);
  }

  // PCMPISTRI — implicit-length string compare
  {
    ArchState s = {};
    s.rflags = 0x2;
    // "Hello\0\0..." in xmm0
    s.xmm[0] = xmm_from_u64(0x0000006F6C6C6548, 0);
    // "Hello\0\0..." in xmm1
    s.xmm[1] = xmm_from_u64(0x0000006F6C6C6548, 0);

    // PCMPISTRI XMM0, XMM1, 0x08 (equal each, unsigned byte): 66 0F 3A 63 C1 08
    // Result in ECX (index of first mismatch/match)
    tests.push_back({"pcmpistri eq", cat, {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x08},
                      s, FL_ALL, 0x0, false});

    // Different strings
    s.xmm[1] = xmm_from_u64(0x0000006F6C6C6549, 0);  // "Iello\0..."
    tests.push_back({"pcmpistri ne", cat, {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x08},
                      s, FL_ALL, 0x0, false});
  }

  // PCMPISTRM — implicit-length string compare, result in XMM0
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0000006F6C6C6548, 0);
    s.xmm[1] = xmm_from_u64(0x0000006F6C6C6548, 0);

    // PCMPISTRM XMM0, XMM1, 0x08 (equal each): 66 0F 3A 62 C1 08
    add_xmm("pcmpistrm eq", {0x66, 0x0F, 0x3A, 0x62, 0xC1, 0x08}, s, 0x1);
  }

  // PCMPESTRI — explicit-length string compare (length in EAX/EDX)
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rax = 5;  // length of string in xmm0
    s.rdx = 5;  // length of string in xmm1
    s.xmm[0] = xmm_from_u64(0x0000006F6C6C6548, 0);
    s.xmm[1] = xmm_from_u64(0x0000006F6C6C6548, 0);

    // PCMPESTRI XMM0, XMM1, 0x08: 66 0F 3A 61 C1 08
    tests.push_back({"pcmpestri eq", cat, {0x66, 0x0F, 0x3A, 0x61, 0xC1, 0x08},
                      s, FL_ALL, 0x0, false});
  }

  // PCMPESTRM — explicit-length, result in XMM0
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rax = 5;
    s.rdx = 5;
    s.xmm[0] = xmm_from_u64(0x0000006F6C6C6548, 0);
    s.xmm[1] = xmm_from_u64(0x0000006F6C6C6548, 0);

    // PCMPESTRM XMM0, XMM1, 0x08: 66 0F 3A 60 C1 08
    add_xmm("pcmpestrm eq", {0x66, 0x0F, 0x3A, 0x60, 0xC1, 0x08}, s, 0x1);
  }

  // CRC32
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rax = 0;         // initial CRC
    s.rcx = 0x12345678;

    // CRC32 EAX, CL: F2 0F 38 F0 C1 (8-bit operand)
    tests.push_back({"crc32 eax,cl", cat, {0xF2, 0x0F, 0x38, 0xF0, 0xC1},
                      s, FL_ALL, 0x0, false});
    // CRC32 EAX, ECX: F2 0F 38 F1 C1 (32-bit operand)
    tests.push_back({"crc32 eax,ecx", cat, {0xF2, 0x0F, 0x38, 0xF1, 0xC1},
                      s, FL_ALL, 0x0, false});
  }

  // =====================================================================
  // 27. AES-NI & PCLMUL
  // =====================================================================
  cat = "AES";

  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[1] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // AESENC XMM0, XMM1: 66 0F 38 DC C1
    add_xmm("aesenc xmm0,xmm1", {0x66, 0x0F, 0x38, 0xDC, 0xC1}, s, 0x3);
    // AESENCLAST XMM0, XMM1: 66 0F 38 DD C1
    add_xmm("aesenclast xmm0,xmm1", {0x66, 0x0F, 0x38, 0xDD, 0xC1}, s, 0x3);
    // AESDEC XMM0, XMM1: 66 0F 38 DE C1
    add_xmm("aesdec xmm0,xmm1", {0x66, 0x0F, 0x38, 0xDE, 0xC1}, s, 0x3);
    // AESDECLAST XMM0, XMM1: 66 0F 38 DF C1
    add_xmm("aesdeclast xmm0,xmm1", {0x66, 0x0F, 0x38, 0xDF, 0xC1}, s, 0x3);
    // AESIMC XMM1, XMM0: 66 0F 38 DB C8
    add_xmm("aesimc xmm1,xmm0", {0x66, 0x0F, 0x38, 0xDB, 0xC8}, s, 0x2);
    // AESKEYGENASSIST XMM1, XMM0, 0x01: 66 0F 3A DF C8 01
    add_xmm("aeskeygenassist xmm1,xmm0,0x01", {0x66, 0x0F, 0x3A, 0xDF, 0xC8, 0x01}, s, 0x2);
    // PCLMULQDQ XMM0, XMM1, 0x00: 66 0F 3A 44 C1 00
    add_xmm("pclmulqdq xmm0,xmm1,0x00", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x00}, s, 0x3);
  }

  // =====================================================================
  // 28. SETcc — all condition codes
  // =====================================================================
  cat = "SETcc";
  {
    // Test with flags: CF=0, ZF=1, SF=1, OF=0, PF=1
    ArchState s = {};
    s.rax = 0xFFFFFFFFFFFFFFFF;  // pre-fill so we see zero-extension
    s.rflags = 0x2 | FL_ZF | FL_SF | FL_PF;

    // SETcc AL: 0F 9x C0 (mod=11, rm=rax)
    add("seto al",   {0x0F, 0x90, 0xC0}, s, FL_ALL);  // OF=0 → 0
    add("setno al",  {0x0F, 0x91, 0xC0}, s, FL_ALL);  // !OF → 1
    add("setb al",   {0x0F, 0x92, 0xC0}, s, FL_ALL);  // CF=0 → 0
    add("setnb al",  {0x0F, 0x93, 0xC0}, s, FL_ALL);  // !CF → 1
    add("sete al",   {0x0F, 0x94, 0xC0}, s, FL_ALL);  // ZF=1 → 1
    add("setne al",  {0x0F, 0x95, 0xC0}, s, FL_ALL);  // !ZF → 0
    add("setbe al",  {0x0F, 0x96, 0xC0}, s, FL_ALL);  // CF|ZF → 1
    add("setnbe al", {0x0F, 0x97, 0xC0}, s, FL_ALL);  // !CF&!ZF → 0
    add("sets al",   {0x0F, 0x98, 0xC0}, s, FL_ALL);  // SF=1 → 1
    add("setns al",  {0x0F, 0x99, 0xC0}, s, FL_ALL);  // !SF → 0
    add("setp al",   {0x0F, 0x9A, 0xC0}, s, FL_ALL);  // PF=1 → 1
    add("setnp al",  {0x0F, 0x9B, 0xC0}, s, FL_ALL);  // !PF → 0
    add("setl al",   {0x0F, 0x9C, 0xC0}, s, FL_ALL);  // SF!=OF → 1
    add("setnl al",  {0x0F, 0x9D, 0xC0}, s, FL_ALL);  // SF==OF → 0
    add("setle al",  {0x0F, 0x9E, 0xC0}, s, FL_ALL);  // ZF|(SF!=OF) → 1
    add("setnle al", {0x0F, 0x9F, 0xC0}, s, FL_ALL);  // !ZF&(SF==OF) → 0

    // Second set with different flags: CF=1, ZF=0, SF=0, OF=1
    s.rflags = 0x2 | FL_CF | FL_OF;
    add("seto al (OF=1)",  {0x0F, 0x90, 0xC0}, s, FL_ALL);
    add("setb al (CF=1)",  {0x0F, 0x92, 0xC0}, s, FL_ALL);
    add("setl al (SF=OF)", {0x0F, 0x9C, 0xC0}, s, FL_ALL);  // SF=0,OF=1 → 1
  }

  // =====================================================================
  // 29. Remaining CMOVcc variants
  // =====================================================================
  cat = "CMOVcc";
  {
    ArchState s = {};
    s.rax = 0x1111111111111111;
    s.rbx = 0x2222222222222222;
    s.rflags = 0x2 | FL_ZF | FL_SF | FL_PF;

    // CMOVcc RAX, RBX: 48 0F 4x C3
    add("cmovnb rax,rbx",  {0x48, 0x0F, 0x43, 0xC3}, s, FL_ALL);  // !CF → taken
    add("cmovne rax,rbx",  {0x48, 0x0F, 0x45, 0xC3}, s, FL_ALL);  // !ZF → not taken
    add("cmovbe rax,rbx",  {0x48, 0x0F, 0x46, 0xC3}, s, FL_ALL);  // CF|ZF → taken
    add("cmova rax,rbx",   {0x48, 0x0F, 0x47, 0xC3}, s, FL_ALL);  // !CF&!ZF → not taken
    add("cmovs rax,rbx",   {0x48, 0x0F, 0x48, 0xC3}, s, FL_ALL);  // SF → taken
    add("cmovns rax,rbx",  {0x48, 0x0F, 0x49, 0xC3}, s, FL_ALL);  // !SF → not taken
    add("cmovp rax,rbx",   {0x48, 0x0F, 0x4A, 0xC3}, s, FL_ALL);  // PF → taken
    add("cmovnp rax,rbx",  {0x48, 0x0F, 0x4B, 0xC3}, s, FL_ALL);  // !PF → not taken
    add("cmovge rax,rbx",  {0x48, 0x0F, 0x4D, 0xC3}, s, FL_ALL);  // SF==OF → not taken
    add("cmovle rax,rbx",  {0x48, 0x0F, 0x4E, 0xC3}, s, FL_ALL);  // ZF|(SF!=OF) → taken
  }

  // =====================================================================
  // 30. POP register
  // =====================================================================
  cat = "POP";
  {
    // PUSH RAX; POP RBX — tests POP reg
    ArchState s = {};
    s.rax = 0xDEADBEEFCAFEBABE;
    s.rbx = 0;
    s.rsp = 0x20000;
    s.rflags = 0x2;
    // PUSH RAX (50); POP RBX (5B)
    add("push rax; pop rbx", {0x50, 0x5B}, s, FL_ALL);

    // PUSH imm32; POP RAX — tests POP with sign-extended immediate
    s.rax = 0;
    // PUSH 0x42 (6A 42); POP RAX (58)
    add("push 0x42; pop rax", {0x6A, 0x42, 0x58}, s, FL_ALL);
  }

  // =====================================================================
  // 31. LEAVE
  // =====================================================================
  cat = "LEAVE";
  {
    // Set up: RSP=0x1FF00, RBP=0x1FFF0 with a value at [RBP]
    // LEAVE does: RSP = RBP; POP RBP
    ArchState s = {};
    s.rsp = 0x1FF00;
    s.rbp = 0x1FFF0;
    s.rflags = 0x2;
    // Use PUSH/LEAVE sequence: PUSH saves RBP on stack, then LEAVE restores it.
    // PUSH RBP (55); MOV RBP,RSP (48 89 E5); LEAVE (C9)
    add("push rbp; mov rbp,rsp; leave", {0x55, 0x48, 0x89, 0xE5, 0xC9}, s, FL_ALL);
  }

  // =====================================================================
  // 32. LOOP/LOOPcc
  // =====================================================================
  cat = "LOOP";
  {
    // LOOP with RCX=3: loop back to add 1 to RAX three times
    // Layout: INC RAX (48 FF C0) + LOOP -5 (E2 FB)
    ArchState s = {};
    s.rax = 0;
    s.rcx = 3;
    s.rflags = 0x2;
    // INC RAX; LOOP -5 (back to INC)
    add("loop rcx=3", {0x48, 0xFF, 0xC0, 0xE2, 0xFB}, s, FL_ALL);

    // LOOP with RCX=1: loop body executes once then falls through
    s.rcx = 1;
    add("loop rcx=1", {0x48, 0xFF, 0xC0, 0xE2, 0xFB}, s, FL_ALL);
  }

  // =====================================================================
  // 33. CMPXCHG8B/CMPXCHG16B
  // =====================================================================
  cat = "CMPXCHG8B";
  {
    // CMPXCHG8B [RDI]: 0F C7 0F (mod=00, reg=1, rm=rdi)
    // Compare EDX:EAX with m64. If equal, set ZF and store ECX:EBX.
    // Otherwise, load m64 into EDX:EAX.

    // Case 1: match (EDX:EAX == m64)
    ArchState s = {};
    s.rdi = DATA_ADDR;
    s.rax = 0x44332211;
    s.rdx = 0x88776655;
    s.rbx = 0xDDCCBBAA;
    s.rcx = 0x11223344;
    s.rflags = 0x2;
    u8 val[] = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88};
    add_mem("cmpxchg8b match", {0x0F, 0xC7, 0x0F}, s, FL_ALL,
            {val, val + 8}, 8);

    // Case 2: no match
    s.rax = 0x00000000;
    s.rdx = 0x00000000;
    add_mem("cmpxchg8b no match", {0x0F, 0xC7, 0x0F}, s, FL_ALL,
            {val, val + 8}, 8);
  }

  // =====================================================================
  // 34. MOVNTI
  // =====================================================================
  cat = "MOVNTI";
  {
    // MOVNTI [RDI], EAX: 0F C3 07
    ArchState s = {};
    s.rdi = DATA_ADDR;
    s.rax = 0xDEADBEEF12345678;
    s.rflags = 0x2;
    add_mem("movnti [rdi],eax", {0x0F, 0xC3, 0x07}, s, FL_ALL, {}, 4);

    // MOVNTI [RDI], RAX: 48 0F C3 07
    add_mem("movnti [rdi],rax", {0x48, 0x0F, 0xC3, 0x07}, s, FL_ALL, {}, 8);
  }

  // =====================================================================
  // 35. LDMXCSR/STMXCSR
  // =====================================================================
  cat = "LDMXCSR";
  {
    // STMXCSR [RDI]: 0F AE 1F (mod=00, reg=3, rm=rdi)
    ArchState s = {};
    s.rdi = DATA_ADDR;
    s.rflags = 0x2;
    add_mem("stmxcsr [rdi]", {0x0F, 0xAE, 0x1F}, s, FL_ALL, {}, 4);

    // LDMXCSR [RDI]: 0F AE 17 (mod=00, reg=2, rm=rdi)
    // Load MXCSR with default value 0x1F80
    u8 mxcsr[] = {0x80, 0x1F, 0x00, 0x00};
    add_mem("ldmxcsr [rdi]", {0x0F, 0xAE, 0x17}, s, FL_ALL,
            {mxcsr, mxcsr + 4}, 0);
  }

  // =====================================================================
  // 36. Fences (LFENCE/MFENCE/SFENCE) — these are NOPs for our model
  // =====================================================================
  cat = "Fences";
  {
    ArchState s = {};
    s.rax = 42;
    s.rflags = 0x2;
    // LFENCE: 0F AE E8
    add("lfence", {0x0F, 0xAE, 0xE8}, s, FL_ALL);
    // MFENCE: 0F AE F0
    add("mfence", {0x0F, 0xAE, 0xF0}, s, FL_ALL);
    // SFENCE: 0F AE F8
    add("sfence", {0x0F, 0xAE, 0xF8}, s, FL_ALL);
  }

  // =====================================================================
  // 37. SSE3 FP — MOVSLDUP, MOVSHDUP, MOVDDUP, HADDPS/PD, HSUBPS/PD,
  //     ADDSUBPS/PD
  // =====================================================================
  cat = "SSE3";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // MOVSLDUP XMM2, XMM0: F3 0F 12 D0 — duplicates even-indexed floats
    add_xmm("movsldup xmm2,xmm0", {0xF3, 0x0F, 0x12, 0xD0}, s, 0x4);

    // MOVSHDUP XMM2, XMM0: F3 0F 16 D0 — duplicates odd-indexed floats
    add_xmm("movshdup xmm2,xmm0", {0xF3, 0x0F, 0x16, 0xD0}, s, 0x4);

    // HADDPS XMM0, XMM1: F2 0F 7C C1
    add_xmm("haddps xmm0,xmm1", {0xF2, 0x0F, 0x7C, 0xC1}, s, 0x3);

    // HSUBPS XMM0, XMM1: F2 0F 7D C1
    add_xmm("hsubps xmm0,xmm1", {0xF2, 0x0F, 0x7D, 0xC1}, s, 0x3);

    // ADDSUBPS XMM0, XMM1: F2 0F D0 C1
    add_xmm("addsubps xmm0,xmm1", {0xF2, 0x0F, 0xD0, 0xC1}, s, 0x3);
  }
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f64(1.5, 2.5);
    s.xmm[1] = xmm_from_f64(3.0, 4.0);

    // MOVDDUP XMM2, XMM0: F2 0F 12 D0 — duplicate low double
    add_xmm("movddup xmm2,xmm0", {0xF2, 0x0F, 0x12, 0xD0}, s, 0x4);

    // HADDPD XMM0, XMM1: 66 0F 7C C1
    add_xmm("haddpd xmm0,xmm1", {0x66, 0x0F, 0x7C, 0xC1}, s, 0x3);

    // HSUBPD XMM0, XMM1: 66 0F 7D C1
    add_xmm("hsubpd xmm0,xmm1", {0x66, 0x0F, 0x7D, 0xC1}, s, 0x3);

    // ADDSUBPD XMM0, XMM1: 66 0F D0 C1
    add_xmm("addsubpd xmm0,xmm1", {0x66, 0x0F, 0xD0, 0xC1}, s, 0x3);
  }

  // =====================================================================
  // 38. SSE4.1 remaining — BLENDVPS, BLENDVPD, PBLENDVB, PHMINPOSUW
  // =====================================================================
  cat = "SSE4.1v";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    // XMM0 is implicit mask for BLENDVPS
    // Use a mask where high bit of each dword selects from xmm1
    // Mask in xmm0: float with sign bit set = select from src2
    // We need xmm0 as both dest and mask, so we use different regs:
    // BLENDVPS XMM2, XMM1, <XMM0>: 66 0F 38 14 D1
    s.xmm[2] = xmm_from_f32(100.0f, 200.0f, 300.0f, 400.0f);
    // Set mask: element 0 and 2 have sign bit set (negative)
    s.xmm[0] = xmm_from_f32(-1.0f, 1.0f, -1.0f, 1.0f);
    add_xmm("blendvps xmm2,xmm1,xmm0", {0x66, 0x0F, 0x38, 0x14, 0xD1}, s, 0x7);

    // BLENDVPD XMM2, XMM1, <XMM0>: 66 0F 38 15 D1
    s.xmm[0] = xmm_from_f64(-1.0, 1.0);  // mask: select low from src2
    s.xmm[1] = xmm_from_f64(10.0, 20.0);
    s.xmm[2] = xmm_from_f64(100.0, 200.0);
    add_xmm("blendvpd xmm2,xmm1,xmm0", {0x66, 0x0F, 0x38, 0x15, 0xD1}, s, 0x7);

    // PBLENDVB XMM2, XMM1, <XMM0>: 66 0F 38 10 D1
    s.xmm[0] = xmm_from_u64(0xFF00FF00FF00FF00, 0x00FF00FF00FF00FF);
    s.xmm[1] = xmm_from_u64(0x1111111111111111, 0x2222222222222222);
    s.xmm[2] = xmm_from_u64(0xAAAAAAAAAAAAAAAA, 0xBBBBBBBBBBBBBBBB);
    add_xmm("pblendvb xmm2,xmm1,xmm0", {0x66, 0x0F, 0x38, 0x10, 0xD1}, s, 0x7);
  }
  {
    // PHMINPOSUW XMM0, XMM1: 66 0F 38 41 C1
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0005000300070001, 0x0009000200040008);
    add_xmm("phminposuw xmm0,xmm1", {0x66, 0x0F, 0x38, 0x41, 0xC1}, s, 0x3);
  }

  // =====================================================================
  // 39. MOVLPS/MOVHPS memory forms
  // =====================================================================
  cat = "MOVxPS";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);

    // MOVLPS [RDI], XMM0: 0F 13 07 — store low 64 bits to memory
    tests.push_back({"movlps [rdi],xmm0", cat, {0x0F, 0x13, 0x07},
                      s, FL_ALL, 0x0, false, {}, 8});

    // MOVHPS [RDI], XMM0: 0F 17 07 — store high 64 bits to memory
    tests.push_back({"movhps [rdi],xmm0", cat, {0x0F, 0x17, 0x07},
                      s, FL_ALL, 0x0, false, {}, 8});

    // MOVLPS XMM0, [RDI]: 0F 12 07 — load 64 bits into low half
    u8 data[] = {0x00, 0x00, 0x80, 0x41, 0x00, 0x00, 0x00, 0x42};  // 16.0f, 32.0f
    tests.push_back({"movlps xmm0,[rdi]", cat, {0x0F, 0x12, 0x07},
                      s, FL_ALL, 0x1, false, {data, data + 8}, 0});

    // MOVHPS XMM0, [RDI]: 0F 16 07 — load 64 bits into high half
    tests.push_back({"movhps xmm0,[rdi]", cat, {0x0F, 0x16, 0x07},
                      s, FL_ALL, 0x1, false, {data, data + 8}, 0});

    // MOVLPD [RDI], XMM0: 66 0F 13 07
    s.xmm[0] = xmm_from_f64(1.5, 2.5);
    tests.push_back({"movlpd [rdi],xmm0", cat, {0x66, 0x0F, 0x13, 0x07},
                      s, FL_ALL, 0x0, false, {}, 8});

    // MOVHPD [RDI], XMM0: 66 0F 17 07
    tests.push_back({"movhpd [rdi],xmm0", cat, {0x66, 0x0F, 0x17, 0x07},
                      s, FL_ALL, 0x0, false, {}, 8});
  }

  // =====================================================================
  // 40. String instructions with REP
  // =====================================================================
  cat = "String";
  {
    // REP STOSB: fill RCX bytes at [RDI] with AL
    ArchState s = {};
    s.rflags = 0x2;  // DF=0 (forward)
    s.rdi = DATA_ADDR;
    s.rax = 0x42;
    s.rcx = 8;
    tests.push_back({"rep stosb", cat, {0xF3, 0xAA},
                      s, FL_ALL, 0, false, {}, 8});

    // REP STOSD: fill RCX dwords at [RDI] with EAX
    s.rax = 0xDEADBEEF;
    s.rcx = 2;
    tests.push_back({"rep stosd", cat, {0xF3, 0xAB},
                      s, FL_ALL, 0, false, {}, 8});

    // REP STOSQ: fill RCX qwords at [RDI] with RAX
    s.rax = 0x123456789ABCDEF0;
    s.rcx = 1;
    tests.push_back({"rep stosq", cat, {0xF3, 0x48, 0xAB},
                      s, FL_ALL, 0, false, {}, 8});

    // REP MOVSB: copy RCX bytes from [RSI] to [RDI]
    s.rsi = DATA_ADDR;
    s.rdi = DATA_ADDR + 32;
    s.rcx = 8;
    u8 src_data[] = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88};
    // We put src data at DATA_ADDR, copy to DATA_ADDR+32
    tests.push_back({"rep movsb", cat, {0xF3, 0xA4},
                      s, FL_ALL, 0, false, {src_data, src_data + 8}, 40});

    // LODSQ: load [RSI] into RAX
    s.rsi = DATA_ADDR;
    s.rdi = 0;
    s.rcx = 0;
    s.rax = 0;
    tests.push_back({"lodsq", cat, {0x48, 0xAD},
                      s, FL_ALL, 0, false, {src_data, src_data + 8}, 0});

    // SCASB: compare AL with [RDI], set flags
    s.rdi = DATA_ADDR;
    s.rax = 0x11;
    tests.push_back({"scasb (match)", cat, {0xAE},
                      s, FL_ALL, 0, false, {src_data, src_data + 8}, 0});

    s.rax = 0xFF;
    tests.push_back({"scasb (no match)", cat, {0xAE},
                      s, FL_ALL, 0, false, {src_data, src_data + 8}, 0});

    // CMPSB: compare [RSI] with [RDI]
    s.rsi = DATA_ADDR;
    s.rdi = DATA_ADDR;
    s.rax = 0;
    tests.push_back({"cmpsb (equal)", cat, {0xA6},
                      s, FL_ALL, 0, false, {src_data, src_data + 8}, 0});
  }

  // =====================================================================
  // 41. EMMS
  // =====================================================================
  cat = "EMMS";
  {
    ArchState s = {};
    s.rflags = 0x2;
    // EMMS: 0F 77
    add("emms", {0x0F, 0x77}, s, FL_ALL);
  }

  // =====================================================================
  // 42. MOVNTDQA (SSE4.1 streaming load)
  // =====================================================================
  cat = "SSE4.1v";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    // 16 bytes of test data (aligned)
    u8 data[] = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10};
    // MOVNTDQA XMM0, [RDI]: 66 0F 38 2A 07
    tests.push_back({"movntdqa xmm0,[rdi]", cat, {0x66, 0x0F, 0x38, 0x2A, 0x07},
                      s, FL_ALL, 0x1, false, {data, data + 16}, 0});
  }

  // =====================================================================
  // 43. x87 FPU — tests using memory store to verify results
  //     We use FILD/FLD to load values, operate, then FISTP/FSTP to store
  //     results back to memory for comparison.
  // =====================================================================
  cat = "x87";
  {
    // FLDZ + FSTP m64fp: push 0.0 then store to [RDI]
    // D9 EE (FLDZ) + DD 1F (FSTP m64fp [RDI])
    ArchState s = {};
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    tests.push_back({"fldz; fstp [rdi]", cat, {0xD9, 0xEE, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FLD1 + FSTP m64fp: push 1.0 then store
    // D9 E8 (FLD1) + DD 1F (FSTP m64fp [RDI])
    tests.push_back({"fld1; fstp [rdi]", cat, {0xD9, 0xE8, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FLDPI + FSTP m64fp: push pi then store
    // D9 EB (FLDPI) + DD 1F (FSTP m64fp [RDI])
    tests.push_back({"fldpi; fstp [rdi]", cat, {0xD9, 0xEB, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FLDL2E + FSTP m64fp: push log2(e) then store
    // D9 EA (FLDL2E) + DD 1F (FSTP m64fp)
    tests.push_back({"fldl2e; fstp [rdi]", cat, {0xD9, 0xEA, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FLDLN2 + FSTP m64fp: push ln(2) then store
    // D9 ED (FLDLN2) + DD 1F
    tests.push_back({"fldln2; fstp [rdi]", cat, {0xD9, 0xED, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FILD m32int + FISTP m32int: load int, store int back
    // DB 07 (FILD m32 [RDI]) + DB 1F (FISTP m32 [RDI])
    u8 int_val[] = {42, 0, 0, 0};
    tests.push_back({"fild [rdi]; fistp [rdi]", cat,
                      {0xDB, 0x07, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {int_val, int_val + 4}, 4});

    // FADD: FILD 10 + FILD 32 + FADDP + FISTP → 42
    // Load 10 at [RDI], 32 at [RDI+4]
    u8 add_data[] = {10, 0, 0, 0, 32, 0, 0, 0};
    // FILD [RDI] (DB 07) + FILD [RDI+4] (DB 47 04) + FADDP (DE C1) + FISTP [RDI] (DB 1F)
    tests.push_back({"fild+fild+faddp+fistp", cat,
                      {0xDB, 0x07, 0xDB, 0x47, 0x04, 0xDE, 0xC1, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {add_data, add_data + 8}, 4});

    // FSUB: FILD 42 + FILD 10 + FSUBRP + FISTP → 32
    // FILD [RDI] (DB 07) + FILD [RDI+4] (DB 47 04) + FSUBRP (DE E1) + FISTP [RDI] (DB 1F)
    u8 sub_data[] = {42, 0, 0, 0, 10, 0, 0, 0};
    tests.push_back({"fild+fild+fsubrp+fistp", cat,
                      {0xDB, 0x07, 0xDB, 0x47, 0x04, 0xDE, 0xE1, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {sub_data, sub_data + 8}, 4});

    // FMUL: FILD 6 + FILD 7 + FMULP + FISTP → 42
    u8 mul_data[] = {6, 0, 0, 0, 7, 0, 0, 0};
    // FILD [RDI] (DB 07) + FILD [RDI+4] (DB 47 04) + FMULP (DE C9) + FISTP [RDI] (DB 1F)
    tests.push_back({"fild+fild+fmulp+fistp", cat,
                      {0xDB, 0x07, 0xDB, 0x47, 0x04, 0xDE, 0xC9, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {mul_data, mul_data + 8}, 4});

    // FCHS: FILD 42 + FCHS + FISTP → -42
    u8 chs_data[] = {42, 0, 0, 0};
    // FILD [RDI] (DB 07) + FCHS (D9 E0) + FISTP [RDI] (DB 1F)
    tests.push_back({"fild+fchs+fistp", cat,
                      {0xDB, 0x07, 0xD9, 0xE0, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {chs_data, chs_data + 4}, 4});

    // FABS: FILD -5 + FABS + FISTP → 5
    u8 abs_data[] = {0xFB, 0xFF, 0xFF, 0xFF};  // -5 as int32
    // FILD [RDI] (DB 07) + FABS (D9 E1) + FISTP [RDI] (DB 1F)
    tests.push_back({"fild+fabs+fistp", cat,
                      {0xDB, 0x07, 0xD9, 0xE1, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {abs_data, abs_data + 4}, 4});

    // FXCH: FLD1 + FLDZ + FXCH + FSTP m64fp → should store 1.0 (was on top after FXCH)
    // D9 E8 (FLD1) + D9 EE (FLDZ) + D9 C9 (FXCH ST(1)) + DD 1F (FSTP [RDI])
    tests.push_back({"fld1+fldz+fxch+fstp", cat,
                      {0xD9, 0xE8, 0xD9, 0xEE, 0xD9, 0xC9, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FSTCW/FLDCW: store control word, load it back
    // D9 3F (FSTCW [RDI]) — stores the FPU control word
    tests.push_back({"fstcw [rdi]", cat, {0xD9, 0x3F},
                      s, FL_ALL, 0, false, {}, 2});

    // FINIT + FSTSW AX: initialize FPU, store status word to AX
    // DB E3 (FNINIT) + DF E0 (FNSTSW AX)
    tests.push_back({"finit+fstsw ax", cat, {0xDB, 0xE3, 0xDF, 0xE0},
                      s, FL_ALL, 0, false, {}, 0});

    // FUCOMI: compare ST(0) with ST(1), set EFLAGS
    // FLD1 + FLDZ + DB E9 (FUCOMI ST,ST(1)) — compares 0.0 vs 1.0
    tests.push_back({"fld1+fldz+fucomi", cat,
                      {0xD9, 0xE8, 0xD9, 0xEE, 0xDB, 0xE9},
                      s, FL_ALL, 0, false, {}, 0});
  }

  // =====================================================================
  // 44. ENTER
  // =====================================================================
  cat = "ENTER";
  {
    ArchState s = {};
    s.rsp = 0x20000;
    s.rbp = 0x1F000;
    s.rflags = 0x2;

    // ENTER 0x10, 0: C8 10 00 00 (allocate 16 bytes, nesting=0)
    // Then LEAVE to restore: C9
    add("enter 0x10,0; leave", {0xC8, 0x10, 0x00, 0x00, 0xC9}, s, FL_ALL);

    // ENTER 0x00, 0: C8 00 00 00 (allocate 0 bytes, nesting=0)
    add("enter 0x00,0; leave", {0xC8, 0x00, 0x00, 0x00, 0xC9}, s, FL_ALL);
  }

  // =====================================================================
  // 45. More x87 — transcendental/rounding ops
  // =====================================================================
  cat = "x87";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;

    // FSQRT: FLD1 + FLD1 + FADDP (=2.0) + FSQRT + FSTP
    // D9 E8 (FLD1) + D9 E8 (FLD1) + DE C1 (FADDP) + D9 FA (FSQRT) + DD 1F (FSTP [RDI])
    tests.push_back({"fld1+fld1+faddp+fsqrt+fstp", cat,
                      {0xD9, 0xE8, 0xD9, 0xE8, 0xDE, 0xC1, 0xD9, 0xFA, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FRNDINT: FLD constant + FRNDINT + FISTP
    // Load 3.7 via FILD 37 / FILD 10 / FDIVP
    u8 rnd_data[] = {37, 0, 0, 0, 10, 0, 0, 0};
    // FILD [RDI] (DB 07) + FILD [RDI+4] (DB 47 04) + DE F9 (FDIVRP) + D9 FC (FRNDINT) + DB 1F (FISTP [RDI])
    tests.push_back({"fild 37/fild 10/fdivrp/frndint/fistp", cat,
                      {0xDB, 0x07, 0xDB, 0x47, 0x04, 0xDE, 0xF9, 0xD9, 0xFC, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {rnd_data, rnd_data + 8}, 4});

    // FSIN: FLD PI/2 ≈ push PI, divide by FILD 2
    // Rather than complex setup, just test FLDZ + FSIN + FSTP (sin(0)=0)
    // D9 EE (FLDZ) + D9 FE (FSIN) + DD 1F (FSTP [RDI])
    tests.push_back({"fldz+fsin+fstp", cat,
                      {0xD9, 0xEE, 0xD9, 0xFE, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FCOS: cos(0)=1
    // D9 EE (FLDZ) + D9 FF (FCOS) + DD 1F (FSTP [RDI])
    tests.push_back({"fldz+fcos+fstp", cat,
                      {0xD9, 0xEE, 0xD9, 0xFF, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FLD m64fp + FSTP m64fp: load double, store back
    // DD 07 (FLD m64fp [RDI]) + DD 1F (FSTP m64fp [RDI])
    u8 dbl_val[8];
    double dv = 3.14159;
    memcpy(dbl_val, &dv, 8);
    tests.push_back({"fld m64; fstp m64", cat,
                      {0xDD, 0x07, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {dbl_val, dbl_val + 8}, 8});

    // FLD m32fp + FSTP m32fp: load float, store back
    // D9 07 (FLD m32fp [RDI]) + D9 1F (FSTP m32fp [RDI])
    u8 flt_val[4];
    float fv = 2.71828f;
    memcpy(flt_val, &fv, 4);
    tests.push_back({"fld m32; fstp m32", cat,
                      {0xD9, 0x07, 0xD9, 0x1F},
                      s, FL_ALL, 0, false, {flt_val, flt_val + 4}, 4});

    // FIST m16: FILD 100 + FIST m16 [RDI]
    u8 i100[] = {100, 0, 0, 0};
    // DB 07 (FILD m32 [RDI]) + DF 17 (FIST m16 [RDI])
    tests.push_back({"fild+fist m16", cat,
                      {0xDB, 0x07, 0xDF, 0x17},
                      s, FL_ALL, 0, false, {i100, i100 + 4}, 2});

    // FISTP m64: FILD 12345 + FISTP m64 [RDI]
    u8 i12345[] = {0x39, 0x30, 0, 0};  // 12345
    // DB 07 (FILD m32 [RDI]) + DF 3F (FISTP m64 [RDI])
    tests.push_back({"fild+fistp m64", cat,
                      {0xDB, 0x07, 0xDF, 0x3F},
                      s, FL_ALL, 0, false, {i12345, i12345 + 4}, 8});

    // FILD m64int + FISTP m64int
    u8 i64_val[] = {0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
    // DF 2F (FILD m64 [RDI]) + DF 3F (FISTP m64 [RDI])
    tests.push_back({"fild m64; fistp m64", cat,
                      {0xDF, 0x2F, 0xDF, 0x3F},
                      s, FL_ALL, 0, false, {i64_val, i64_val + 8}, 8});

    // FILD m16int + FISTP m32int
    u8 i16_val[] = {0x0A, 0x00};  // 10
    // DF 07 (FILD m16 [RDI]) + DB 1F (FISTP m32 [RDI])
    tests.push_back({"fild m16; fistp m32", cat,
                      {0xDF, 0x07, 0xDB, 0x1F},
                      s, FL_ALL, 0, false, {i16_val, i16_val + 2}, 4});

    // FUCOMIP: compare and set EFLAGS, pop
    // FLD1 + FLDZ + DF E9 (FUCOMIP ST, ST(1)) — compares 0.0 vs 1.0
    tests.push_back({"fld1+fldz+fucomip", cat,
                      {0xD9, 0xE8, 0xD9, 0xEE, 0xDF, 0xE9},
                      s, FL_ALL, 0, false, {}, 0});
  }

  // =====================================================================
  // 46. CMPXCHG16B
  // =====================================================================
  cat = "CMPXCHG16B";
  {
    // CMPXCHG16B [RDI]: REX.W 0F C7 0F (mod=00, reg=1, rm=rdi)
    // Compare RDX:RAX with m128. If equal, set ZF and store RCX:RBX.

    // Case 1: match
    ArchState s = {};
    s.rdi = DATA_ADDR;  // DATA_ADDR is 0x11000, 4K-aligned
    s.rax = 0x44332211AABBCCDD;
    s.rdx = 0x88776655EEFF0011;
    s.rbx = 0xDDCCBBAA11223344;
    s.rcx = 0x1122334455667788;
    s.rflags = 0x2;
    u8 val[] = {0xDD, 0xCC, 0xBB, 0xAA, 0x11, 0x22, 0x33, 0x44,
                0x11, 0x00, 0xFF, 0xEE, 0x55, 0x66, 0x77, 0x88};
    add_mem("cmpxchg16b match", {0x48, 0x0F, 0xC7, 0x0F}, s, FL_ALL,
            {val, val + 16}, 16);

    // Case 2: no match
    s.rax = 0x0000000000000000;
    s.rdx = 0x0000000000000000;
    add_mem("cmpxchg16b no match", {0x48, 0x0F, 0xC7, 0x0F}, s, FL_ALL,
            {val, val + 16}, 16);
  }

  // =====================================================================
  // 47. AVX (VEX-encoded 128-bit) — packed/scalar FP and integer
  //
  // VEX 2-byte encoding: C5 [R̄.vvvv.L.pp] opcode ModRM
  //   R̄=1 for xmm0-7, vvvv = ~src1 (inverted), L=0 for 128-bit
  //   pp: 00=NP, 01=66, 10=F3, 11=F2
  //
  // Example: VADDPS xmm0, xmm1, xmm2 → C5 F0 58 C2
  //   R̄=1, vvvv=~1=1110=0xE, L=0, pp=00 → byte = 0xF0
  //   opcode=0x58, ModRM=0xC2 (mod=11, reg=0, rm=2)
  // =====================================================================
  cat = "AVX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // VEX 2-byte: C5 [R̄.vvvv.L.pp]
    // For xmm0 = xmm1 op xmm2: vvvv=~1=0xE, L=0, pp=00 → 0xF0
    // ModRM: mod=11, reg=xmm0=0, rm=xmm2=2 → 0xC2

    // VADDPS xmm0, xmm1, xmm2: C5 F0 58 C2
    add_xmm("vaddps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x58, 0xC2}, s, 0x7);
    // VSUBPS xmm0, xmm1, xmm2: C5 F0 5C C2
    add_xmm("vsubps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x5C, 0xC2}, s, 0x7);
    // VMULPS xmm0, xmm1, xmm2: C5 F0 59 C2
    add_xmm("vmulps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x59, 0xC2}, s, 0x7);
    // VDIVPS xmm0, xmm1, xmm2: C5 F0 5E C2
    add_xmm("vdivps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x5E, 0xC2}, s, 0x7);
    // VMINPS xmm0, xmm1, xmm2: C5 F0 5D C2
    add_xmm("vminps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x5D, 0xC2}, s, 0x7);
    // VMAXPS xmm0, xmm1, xmm2: C5 F0 5F C2
    add_xmm("vmaxps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x5F, 0xC2}, s, 0x7);

    // VSQRTPS xmm0, xmm1: C5 F8 51 C1  (vvvv=1111=unused, pp=00)
    add_xmm("vsqrtps xmm0,xmm1", {0xC5, 0xF8, 0x51, 0xC1}, s, 0x3);

    // VANDPS xmm0, xmm1, xmm2: C5 F0 54 C2
    add_xmm("vandps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x54, 0xC2}, s, 0x7);
    // VANDNPS xmm0, xmm1, xmm2: C5 F0 55 C2
    add_xmm("vandnps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x55, 0xC2}, s, 0x7);
    // VORPS xmm0, xmm1, xmm2: C5 F0 56 C2
    add_xmm("vorps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x56, 0xC2}, s, 0x7);
    // VXORPS xmm0, xmm1, xmm2: C5 F0 57 C2
    add_xmm("vxorps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x57, 0xC2}, s, 0x7);

    // VSHUFPS xmm0, xmm1, xmm2, 0x1B: C5 F0 C6 C2 1B
    add_xmm("vshufps xmm0,xmm1,xmm2,0x1B", {0xC5, 0xF0, 0xC6, 0xC2, 0x1B}, s, 0x7);

    // VUNPCKLPS xmm0, xmm1, xmm2: C5 F0 14 C2
    add_xmm("vunpcklps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x14, 0xC2}, s, 0x7);
    // VUNPCKHPS xmm0, xmm1, xmm2: C5 F0 15 C2
    add_xmm("vunpckhps xmm0,xmm1,xmm2", {0xC5, 0xF0, 0x15, 0xC2}, s, 0x7);
  }

  // AVX packed double
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f64(1.5, 2.5);
    s.xmm[2] = xmm_from_f64(3.0, 4.0);

    // pp=01 (66 prefix): vvvv=~1=0xE, L=0, pp=01 → 0xF1
    // VADDPD xmm0, xmm1, xmm2: C5 F1 58 C2
    add_xmm("vaddpd xmm0,xmm1,xmm2", {0xC5, 0xF1, 0x58, 0xC2}, s, 0x7);
    // VSUBPD xmm0, xmm1, xmm2: C5 F1 5C C2
    add_xmm("vsubpd xmm0,xmm1,xmm2", {0xC5, 0xF1, 0x5C, 0xC2}, s, 0x7);
    // VMULPD xmm0, xmm1, xmm2: C5 F1 59 C2
    add_xmm("vmulpd xmm0,xmm1,xmm2", {0xC5, 0xF1, 0x59, 0xC2}, s, 0x7);
    // VDIVPD xmm0, xmm1, xmm2: C5 F1 5E C2
    add_xmm("vdivpd xmm0,xmm1,xmm2", {0xC5, 0xF1, 0x5E, 0xC2}, s, 0x7);

    // VANDPD xmm0, xmm1, xmm2: C5 F1 54 C2
    add_xmm("vandpd xmm0,xmm1,xmm2", {0xC5, 0xF1, 0x54, 0xC2}, s, 0x7);
    // VXORPD xmm0, xmm1, xmm2: C5 F1 57 C2
    add_xmm("vxorpd xmm0,xmm1,xmm2", {0xC5, 0xF1, 0x57, 0xC2}, s, 0x7);

    // VSHUFPD xmm0, xmm1, xmm2, 0x01: C5 F1 C6 C2 01
    add_xmm("vshufpd xmm0,xmm1,xmm2,0x01", {0xC5, 0xF1, 0xC6, 0xC2, 0x01}, s, 0x7);

    // VUNPCKLPD xmm0, xmm1, xmm2: C5 F1 14 C2
    add_xmm("vunpcklpd xmm0,xmm1,xmm2", {0xC5, 0xF1, 0x14, 0xC2}, s, 0x7);
    // VUNPCKHPD xmm0, xmm1, xmm2: C5 F1 15 C2
    add_xmm("vunpckhpd xmm0,xmm1,xmm2", {0xC5, 0xF1, 0x15, 0xC2}, s, 0x7);
  }

  // AVX scalar
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);

    // pp=10 (F3 prefix): vvvv=~1=0xE, L=0, pp=10 → 0xF2
    // VADDSS xmm0, xmm1, xmm2: C5 F2 58 C2
    add_xmm("vaddss xmm0,xmm1,xmm2", {0xC5, 0xF2, 0x58, 0xC2}, s, 0x7);
    // VSUBSS xmm0, xmm1, xmm2: C5 F2 5C C2
    add_xmm("vsubss xmm0,xmm1,xmm2", {0xC5, 0xF2, 0x5C, 0xC2}, s, 0x7);
    // VMULSS xmm0, xmm1, xmm2: C5 F2 59 C2
    add_xmm("vmulss xmm0,xmm1,xmm2", {0xC5, 0xF2, 0x59, 0xC2}, s, 0x7);
    // VDIVSS xmm0, xmm1, xmm2: C5 F2 5E C2
    add_xmm("vdivss xmm0,xmm1,xmm2", {0xC5, 0xF2, 0x5E, 0xC2}, s, 0x7);

    // pp=11 (F2 prefix): vvvv=~1=0xE, L=0, pp=11 → 0xF3
    s.xmm[1] = xmm_from_f64(1.5, 2.5);
    s.xmm[2] = xmm_from_f64(3.0, 4.0);
    // VADDSD xmm0, xmm1, xmm2: C5 F3 58 C2
    add_xmm("vaddsd xmm0,xmm1,xmm2", {0xC5, 0xF3, 0x58, 0xC2}, s, 0x7);
    // VSUBSD xmm0, xmm1, xmm2: C5 F3 5C C2
    add_xmm("vsubsd xmm0,xmm1,xmm2", {0xC5, 0xF3, 0x5C, 0xC2}, s, 0x7);
    // VMULSD xmm0, xmm1, xmm2: C5 F3 59 C2
    add_xmm("vmulsd xmm0,xmm1,xmm2", {0xC5, 0xF3, 0x59, 0xC2}, s, 0x7);
    // VDIVSD xmm0, xmm1, xmm2: C5 F3 5E C2
    add_xmm("vdivsd xmm0,xmm1,xmm2", {0xC5, 0xF3, 0x5E, 0xC2}, s, 0x7);
  }

  // AVX data movement
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);

    // VMOVAPS xmm0, xmm1: C5 F8 28 C1  (vvvv=1111, pp=00)
    add_xmm("vmovaps xmm0,xmm1", {0xC5, 0xF8, 0x28, 0xC1}, s, 0x3);
    // VMOVUPS xmm0, xmm1: C5 F8 10 C1
    add_xmm("vmovups xmm0,xmm1", {0xC5, 0xF8, 0x10, 0xC1}, s, 0x3);
    // VMOVAPD xmm0, xmm1: C5 F9 28 C1  (pp=01)
    add_xmm("vmovapd xmm0,xmm1", {0xC5, 0xF9, 0x28, 0xC1}, s, 0x3);
    // VMOVDQA xmm0, xmm1: C5 F9 6F C1  (pp=01)
    add_xmm("vmovdqa xmm0,xmm1", {0xC5, 0xF9, 0x6F, 0xC1}, s, 0x3);
    // VMOVDQU xmm0, xmm1: C5 FA 6F C1  (pp=10)
    add_xmm("vmovdqu xmm0,xmm1", {0xC5, 0xFA, 0x6F, 0xC1}, s, 0x3);
  }

  // AVX packed integer
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // pp=01 (66), vvvv=~1=0xE, L=0 → 0xF1
    // VPADDB xmm0, xmm1, xmm2: C5 F1 FC C2
    add_xmm("vpaddb xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xFC, 0xC2}, s, 0x7);
    // VPADDW xmm0, xmm1, xmm2: C5 F1 FD C2
    add_xmm("vpaddw xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xFD, 0xC2}, s, 0x7);
    // VPADDD xmm0, xmm1, xmm2: C5 F1 FE C2
    add_xmm("vpaddd xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xFE, 0xC2}, s, 0x7);
    // VPADDQ xmm0, xmm1, xmm2: C5 F1 D4 C2
    add_xmm("vpaddq xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xD4, 0xC2}, s, 0x7);
    // VPSUBB xmm0, xmm1, xmm2: C5 F1 F8 C2
    add_xmm("vpsubb xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xF8, 0xC2}, s, 0x7);

    // VPAND xmm0, xmm1, xmm2: C5 F1 DB C2
    add_xmm("vpand xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xDB, 0xC2}, s, 0x7);
    // VPOR xmm0, xmm1, xmm2: C5 F1 EB C2
    add_xmm("vpor xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xEB, 0xC2}, s, 0x7);
    // VPXOR xmm0, xmm1, xmm2: C5 F1 EF C2
    add_xmm("vpxor xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xEF, 0xC2}, s, 0x7);
    // VPANDN xmm0, xmm1, xmm2: C5 F1 DF C2
    add_xmm("vpandn xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xDF, 0xC2}, s, 0x7);
  }

  // AVX VCMPPS/VCMPPD
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 3.0f, 2.0f, 4.0f);

    // VCMPPS xmm0, xmm1, xmm2, 0 (EQ): C5 F0 C2 C2 00
    add_xmm("vcmpps eq", {0xC5, 0xF0, 0xC2, 0xC2, 0x00}, s, 0x7);
    // VCMPPS xmm0, xmm1, xmm2, 1 (LT): C5 F0 C2 C2 01
    add_xmm("vcmpps lt", {0xC5, 0xF0, 0xC2, 0xC2, 0x01}, s, 0x7);
  }

  // AVX conversion: VCVTDQ2PS, VCVTPS2DQ
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u32(1, 2, 0xFFFFFFFF, 100);  // ints: 1, 2, -1, 100

    // VCVTDQ2PS xmm0, xmm1: C5 F8 5B C1 (NP)
    add_xmm("vcvtdq2ps xmm0,xmm1", {0xC5, 0xF8, 0x5B, 0xC1}, s, 0x3);

    s.xmm[1] = xmm_from_f32(1.7f, -2.3f, 100.5f, 0.0f);
    // VCVTPS2DQ xmm0, xmm1: C5 F9 5B C1 (66)
    add_xmm("vcvtps2dq xmm0,xmm1", {0xC5, 0xF9, 0x5B, 0xC1}, s, 0x3);
    // VCVTTPS2DQ xmm0, xmm1: C5 FA 5B C1 (F3)
    add_xmm("vcvttps2dq xmm0,xmm1", {0xC5, 0xFA, 0x5B, 0xC1}, s, 0x3);
  }

  // =====================================================================
  // 48. AVX VBROADCAST, VINSERTF128/VEXTRACTF128
  // =====================================================================
  cat = "AVX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);

    // VBROADCASTSS xmm0, xmm1: VEX.128.66.0F38.W0 18 /r
    // 3-byte VEX: C4 [R̄.X̄.B̄.mmmmm] [W.vvvv.L.pp]
    // R̄=1, X̄=1, B̄=1, mmmmm=00010 (0F38) → byte1 = 0b_111_00010 = 0xE2
    // W=0, vvvv=1111 (unused), L=0, pp=01 (66) → byte2 = 0b_0_1111_0_01 = 0x79
    // ModRM: mod=11, reg=xmm0=0, rm=xmm1=1 → 0xC1
    add_xmm("vbroadcastss xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x18, 0xC1}, s, 0x3);
  }

  // =====================================================================
  // 49. More x87 transcendental/special operations
  // =====================================================================
  cat = "x87";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;

    // FLDL2T + FSTP: log2(10)
    tests.push_back({"fldl2t; fstp [rdi]", cat, {0xD9, 0xE9, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FLDLG2 + FSTP: log10(2)
    tests.push_back({"fldlg2; fstp [rdi]", cat, {0xD9, 0xEC, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FTST: compare ST(0) with 0.0
    // FLD1 + FTST → C1 should be clear (ST(0)>0)
    // D9 E8 (FLD1) + D9 E4 (FTST) + DF E0 (FNSTSW AX) to read result
    tests.push_back({"fld1+ftst+fstsw", cat,
                      {0xD9, 0xE8, 0xD9, 0xE4, 0xDF, 0xE0},
                      s, FL_ALL, 0, false, {}, 0});

    // FINCSTP/FDECSTP: adjust FPU stack pointer
    // D9 F7 (FINCSTP) + DF E0 (FNSTSW AX)
    tests.push_back({"fincstp+fstsw", cat,
                      {0xD9, 0xF7, 0xDF, 0xE0},
                      s, FL_ALL, 0, false, {}, 0});

    // D9 F6 (FDECSTP) + DF E0 (FNSTSW AX)
    tests.push_back({"fdecstp+fstsw", cat,
                      {0xD9, 0xF6, 0xDF, 0xE0},
                      s, FL_ALL, 0, false, {}, 0});

    // FCOM: compare ST(0) and ST(1)
    // FLD1 + FLDZ + D8 D1 (FCOM ST(1)) + DF E0 (FNSTSW AX)
    tests.push_back({"fld1+fldz+fcom+fstsw", cat,
                      {0xD9, 0xE8, 0xD9, 0xEE, 0xD8, 0xD1, 0xDF, 0xE0},
                      s, FL_ALL, 0, false, {}, 0});

    // FCOMP: compare ST(0) and ST(1), pop
    // FLD1 + FLDZ + D8 D9 (FCOMP ST(1)) + DF E0 (FNSTSW AX)
    tests.push_back({"fld1+fldz+fcomp+fstsw", cat,
                      {0xD9, 0xE8, 0xD9, 0xEE, 0xD8, 0xD9, 0xDF, 0xE0},
                      s, FL_ALL, 0, false, {}, 0});

    // FXAM: examine ST(0) classification
    // FLD1 + D9 E5 (FXAM) + DF E0 (FNSTSW AX)
    tests.push_back({"fld1+fxam+fstsw", cat,
                      {0xD9, 0xE8, 0xD9, 0xE5, 0xDF, 0xE0},
                      s, FL_ALL, 0, false, {}, 0});

    // FLDZ + FXAM (examine zero)
    tests.push_back({"fldz+fxam+fstsw", cat,
                      {0xD9, 0xEE, 0xD9, 0xE5, 0xDF, 0xE0},
                      s, FL_ALL, 0, false, {}, 0});
  }

  // =====================================================================
  // 50. More string instruction sizes
  // =====================================================================
  cat = "String";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;

    // REP STOSW: fill with 16-bit values
    s.rax = 0xABCD;
    s.rcx = 4;
    // 66 F3 AB (REP STOSW)
    tests.push_back({"rep stosw", cat, {0x66, 0xF3, 0xAB},
                      s, FL_ALL, 0, false, {}, 8});

    // REP MOVSQ: copy 8-byte units
    u8 src_data[] = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88};
    s.rsi = DATA_ADDR;
    s.rdi = DATA_ADDR + 32;
    s.rcx = 1;
    // F3 48 A5 (REP MOVSQ)
    tests.push_back({"rep movsq", cat, {0xF3, 0x48, 0xA5},
                      s, FL_ALL, 0, false, {src_data, src_data + 8}, 40});

    // LODSB: load byte from [RSI] into AL
    s.rsi = DATA_ADDR;
    s.rdi = 0;
    s.rcx = 0;
    s.rax = 0;
    // AC (LODSB)
    tests.push_back({"lodsb", cat, {0xAC},
                      s, FL_ALL, 0, false, {src_data, src_data + 8}, 0});

    // LODSD: load dword from [RSI] into EAX
    // AD (LODSD — no REX.W, so 32-bit)
    tests.push_back({"lodsd", cat, {0xAD},
                      s, FL_ALL, 0, false, {src_data, src_data + 8}, 0});

    // SCASD: compare EAX with [RDI]
    s.rdi = DATA_ADDR;
    s.rax = 0x44332211;
    // AF (SCASD)
    tests.push_back({"scasd (match)", cat, {0xAF},
                      s, FL_ALL, 0, false, {src_data, src_data + 8}, 0});
  }

  // =====================================================================
  // 51. AVX-512 (EVEX-encoded 128-bit) — basic tests
  //
  // EVEX 4-byte prefix: 62 [P0] [P1] [P2] opcode ModRM
  // P0 = R̄.X̄.B̄.R̄'.00.mm  (mm=01 for 0F map)
  // P1 = W.vvvv.1.pp      (pp=01 for 66 prefix)
  // P2 = z.L'L.b.V̄'.aaa   (L'L=00 for 128, aaa=000 for no mask)
  //
  // For xmm0 = xmm1 op xmm2: R̄=X̄=B̄=R̄'=1, vvvv=~1=1110, V̄'=1
  //   P0 = 0xF1, P1 = 0x75 (W=0,66), P2 = 0x08 (128,no mask)
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // VPADDD xmm0, xmm1, xmm2: 62 F1 75 08 FE C2
    add_xmm("evex vpaddd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xFE, 0xC2}, s, 0x7);

    // VPSUBD xmm0, xmm1, xmm2: 62 F1 75 08 FA C2
    add_xmm("evex vpsubd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xFA, 0xC2}, s, 0x7);

    // VPAND xmm0, xmm1, xmm2 (VPANDD): 62 F1 75 08 DB C2
    add_xmm("evex vpandd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xDB, 0xC2}, s, 0x7);

    // VPOR xmm0, xmm1, xmm2 (VPORD): 62 F1 75 08 EB C2
    add_xmm("evex vpord xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xEB, 0xC2}, s, 0x7);

    // VPXOR xmm0, xmm1, xmm2 (VPXORD): 62 F1 75 08 EF C2
    add_xmm("evex vpxord xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xEF, 0xC2}, s, 0x7);
  }
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // VADDPS xmm0, xmm1, xmm2 (EVEX.128.NP.0F W0):
    // P0=0xF1, P1=0x70 (W=0,vvvv=1110,1,pp=00), P2=0x08
    add_xmm("evex vaddps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x58, 0xC2}, s, 0x7);

    // VSUBPS xmm0, xmm1, xmm2
    add_xmm("evex vsubps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x5C, 0xC2}, s, 0x7);

    // VMULPS xmm0, xmm1, xmm2
    add_xmm("evex vmulps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x59, 0xC2}, s, 0x7);

    // VMOVAPS xmm0, xmm1 (EVEX.128.NP.0F W0):
    // P0=0xF1, P1=0x7C (vvvv=1111,1,pp=00), P2=0x08
    add_xmm("evex vmovaps xmm0,xmm1",
            {0x62, 0xF1, 0x7C, 0x08, 0x28, 0xC1}, s, 0x3);
  }
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f64(1.5, 2.5);
    s.xmm[2] = xmm_from_f64(3.0, 4.0);

    // VADDPD xmm0, xmm1, xmm2 (EVEX.128.66.0F W1):
    // P0=0xF1, P1=0xF5 (W=1,vvvv=1110,1,pp=01), P2=0x08
    add_xmm("evex vaddpd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0x58, 0xC2}, s, 0x7);

    // VMULPD xmm0, xmm1, xmm2
    add_xmm("evex vmulpd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0x59, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 52. VEX FMA instructions
  // VEX.128.66.0F38.W0: 3-byte VEX C4 E2 71 xx C2
  //   P0: R̄=1,X̄=1,B̄=1, mmmmm=00010 (0F38) → 0xE2
  //   P1: W=0, vvvv=~1=1110, L=0, pp=01 (66) → 0x71
  // =====================================================================
  cat = "AVX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);

    // VFMADD132PS xmm0, xmm1, xmm2: C4 E2 71 98 C2
    add_xmm("vex vfmadd132ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0x98, 0xC2}, s, 0x7);

    // VFMADD213PS xmm0, xmm1, xmm2: C4 E2 71 A8 C2
    add_xmm("vex vfmadd213ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xA8, 0xC2}, s, 0x7);

    // VFMADD231PS xmm0, xmm1, xmm2: C4 E2 71 B8 C2
    s.xmm[0] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    add_xmm("vex vfmadd231ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xB8, 0xC2}, s, 0x7);

    // VFMSUB132PS xmm0, xmm1, xmm2: C4 E2 71 9A C2
    s.xmm[0] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);
    add_xmm("vex vfmsub132ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0x9A, 0xC2}, s, 0x7);

    // VFNMADD132PS xmm0, xmm1, xmm2: C4 E2 71 9C C2
    add_xmm("vex vfnmadd132ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0x9C, 0xC2}, s, 0x7);

    // VFNMSUB132PS xmm0, xmm1, xmm2: C4 E2 71 9E C2
    add_xmm("vex vfnmsub132ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0x9E, 0xC2}, s, 0x7);

    // VFMADD132SS xmm0, xmm1, xmm2: C4 E2 71 99 C2
    add_xmm("vex vfmadd132ss xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0x99, 0xC2}, s, 0x7);

    // VFMADD213SS xmm0, xmm1, xmm2: C4 E2 71 A9 C2
    add_xmm("vex vfmadd213ss xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xA9, 0xC2}, s, 0x7);

    // VFMADD231SS xmm0, xmm1, xmm2: C4 E2 71 B9 C2
    add_xmm("vex vfmadd231ss xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xB9, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 53. VINSERTF128 / VEXTRACTF128
  // VINSERTF128 ymm, ymm, xmm, imm8: VEX.256.66.0F3A.W0 18 /r ib
  //   C4 E3 75 18 C2 01 → insert xmm2 into upper 128 of ymm0 (vvvv=ymm1)
  // VEXTRACTF128 xmm, ymm, imm8: VEX.256.66.0F3A.W0 19 /r ib
  //   C4 E3 7D 19 C2 01 → extract upper 128 of ymm0 into xmm2
  // =====================================================================
  cat = "AVX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x1111111122222222, 0x3333333344444444);
    s.xmm[2] = xmm_from_u64(0xAAAAAAAABBBBBBBB, 0xCCCCCCCCDDDDDDDD);

    // VINSERTF128 ymm0, ymm1, xmm2, 0 (insert into lower 128)
    // C4 E3 [R̄.X̄.B̄.mmmmm=11.00011] [W.vvvv.L.pp = 0.1110.1.01] 18 C2 00
    // P0=0xE3, P1=0x75 (vvvv=1110,L=1,pp=01), opcode=0x18, ModRM=0xC2, imm=0x00
    add_xmm("vinsertf128 ymm0,ymm1,xmm2,0",
            {0xC4, 0xE3, 0x75, 0x18, 0xC2, 0x00}, s, 0x7);

    // VINSERTF128 ymm0, ymm1, xmm2, 1 (insert into upper 128)
    add_xmm("vinsertf128 ymm0,ymm1,xmm2,1",
            {0xC4, 0xE3, 0x75, 0x18, 0xC2, 0x01}, s, 0x7);

    // VEXTRACTF128 xmm2, ymm0, 0 (extract lower 128)
    // VEX.256.66.0F3A.W0 19 /r ib
    // C4 E3 7D 19 C2 00 → vvvv=1111 (unused), L=1
    add_xmm("vextractf128 xmm2,ymm0,0",
            {0xC4, 0xE3, 0x7D, 0x19, 0xC2, 0x00}, s, 0x7);

    // VEXTRACTF128 xmm2, ymm0, 1 (extract upper 128)
    add_xmm("vextractf128 xmm2,ymm0,1",
            {0xC4, 0xE3, 0x7D, 0x19, 0xC2, 0x01}, s, 0x7);
  }

  // =====================================================================
  // 54. More x87 transcendental/special
  // =====================================================================
  cat = "x87";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;

    // FPTAN: tan(ST(0)), push 1.0
    // FLD1 (D9 E8) + FPTAN (D9 F2) + FSTP [RDI] (DD 1F) + FSTP [RDI+8] (DD 5F 08)
    // ST(0) = 1.0, FPTAN pushes result: ST(0)=1.0, ST(1)=tan(1.0)
    tests.push_back({"fld1+fptan+fstp+fstp", cat,
                      {0xD9, 0xE8, 0xD9, 0xF2, 0xDD, 0x1F, 0xDD, 0x5F, 0x08},
                      s, FL_ALL, 0, false, {}, 16});

    // FPATAN: atan2(ST(1), ST(0)), pop
    // FLD1 (D9 E8) + FLD1 (D9 E8) + FPATAN (D9 F3) + FSTP [RDI] (DD 1F)
    // atan2(1.0, 1.0) = pi/4
    tests.push_back({"fld1+fld1+fpatan+fstp", cat,
                      {0xD9, 0xE8, 0xD9, 0xE8, 0xD9, 0xF3, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // F2XM1: 2^ST(0) - 1
    // FLDZ (D9 EE) + F2XM1 (D9 F0) + FSTP [RDI] (DD 1F)
    // 2^0 - 1 = 0.0
    tests.push_back({"fldz+f2xm1+fstp", cat,
                      {0xD9, 0xEE, 0xD9, 0xF0, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FYL2X: ST(1) * log2(ST(0)), pop
    // FLD1 (D9 E8) + FLD1 (D9 E8) + FYL2X (D9 F1) + FSTP [RDI]
    // 1.0 * log2(1.0) = 0.0
    tests.push_back({"fld1+fld1+fyl2x+fstp", cat,
                      {0xD9, 0xE8, 0xD9, 0xE8, 0xD9, 0xF1, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FYL2XP1: ST(1) * log2(ST(0) + 1), pop
    // FLDZ (D9 EE) + FLD1 (D9 E8) + FYL2XP1 (D9 F9) + FSTP [RDI]
    // log2(0 + 1) = 0 → 1.0 * 0 = 0.0
    // Note: ST(1)=FLDZ=0, ST(0)=FLD1=1, but fyl2xp1: ST(1)*log2(ST(0)+1)
    // Actually: push 0, push 1 → ST(0)=1, ST(1)=0 → 0*log2(1+1)=0
    tests.push_back({"fldz+fld1+fyl2xp1+fstp", cat,
                      {0xD9, 0xEE, 0xD9, 0xE8, 0xD9, 0xF9, 0xDD, 0x1F},
                      s, FL_ALL, 0, false, {}, 8});

    // FPREM: ST(0) = ST(0) mod ST(1)
    // Push 3.0 then push 10.0: FILD [mem(3)] + FILD [mem(10)]
    // Use constants: FLD1 + FLD1 + FADDP → 2.0, then FPREM
    // Actually simpler: use FLDPI + FLD1 + FPREM + FSTP
    // pi mod 1.0
    tests.push_back({"fldpi+fld1+fprem+fstp+fstp", cat,
                      {0xD9, 0xEB, 0xD9, 0xE8, 0xD9, 0xF8, 0xDD, 0x1F, 0xDD, 0x5F, 0x08},
                      s, FL_ALL, 0, false, {}, 16});

    // FPREM1: IEEE remainder
    tests.push_back({"fldpi+fld1+fprem1+fstp+fstp", cat,
                      {0xD9, 0xEB, 0xD9, 0xE8, 0xD9, 0xF5, 0xDD, 0x1F, 0xDD, 0x5F, 0x08},
                      s, FL_ALL, 0, false, {}, 16});

    // FSCALE: ST(0) = ST(0) * 2^trunc(ST(1))
    // FLD1 + FLD1 + FSCALE + FSTP → 1.0 * 2^1 = 2.0
    tests.push_back({"fld1+fld1+fscale+fstp+fstp", cat,
                      {0xD9, 0xE8, 0xD9, 0xE8, 0xD9, 0xFD, 0xDD, 0x1F, 0xDD, 0x5F, 0x08},
                      s, FL_ALL, 0, false, {}, 16});

    // FXTRACT: split into exponent + significand
    // FLDPI + FXTRACT + FSTP + FSTP → exponent and significand of pi
    tests.push_back({"fldpi+fxtract+fstp+fstp", cat,
                      {0xD9, 0xEB, 0xD9, 0xF4, 0xDD, 0x1F, 0xDD, 0x5F, 0x08},
                      s, FL_ALL, 0, false, {}, 16});

    // FUCOM ST(1): compare ST(0) and ST(1) without pop
    // FLD1 + FLDPI + DD E1 (FUCOM ST(1)) + DF E0 (FNSTSW AX)
    tests.push_back({"fld1+fldpi+fucom+fstsw", cat,
                      {0xD9, 0xE8, 0xD9, 0xEB, 0xDD, 0xE1, 0xDF, 0xE0},
                      s, FL_ALL, 0, false, {}, 0});

    // FUCOMP ST(1): compare ST(0) and ST(1), pop
    tests.push_back({"fld1+fldpi+fucomp+fstsw", cat,
                      {0xD9, 0xE8, 0xD9, 0xEB, 0xDD, 0xE9, 0xDF, 0xE0},
                      s, FL_ALL, 0, false, {}, 0});
  }

  // =====================================================================
  // 55. More string instruction sizes
  // =====================================================================
  cat = "String";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;

    // LODSW: load word from [RSI] into AX (66 prefix)
    u8 src_data2[] = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88};
    s.rsi = DATA_ADDR;
    s.rax = 0;
    // 66 AD (LODSW)
    tests.push_back({"lodsw", cat, {0x66, 0xAD},
                      s, FL_ALL, 0, false,
                      {src_data2, src_data2 + 8}, 0});

    // REP MOVSD: copy 4-byte units
    s.rsi = DATA_ADDR;
    s.rdi = DATA_ADDR + 32;
    s.rcx = 2;
    // F3 A5 (REP MOVSD — no REX.W so 32-bit)
    tests.push_back({"rep movsd", cat, {0xF3, 0xA5},
                      s, FL_ALL, 0, false,
                      {src_data2, src_data2 + 8}, 40});

    // REP MOVSW: copy 2-byte units
    s.rsi = DATA_ADDR;
    s.rdi = DATA_ADDR + 32;
    s.rcx = 4;
    // F3 66 A5 (REP MOVSW)
    tests.push_back({"rep movsw", cat, {0x66, 0xF3, 0xA5},
                      s, FL_ALL, 0, false,
                      {src_data2, src_data2 + 8}, 40});

    // SCASW: compare AX with [RDI]
    s.rdi = DATA_ADDR;
    s.rax = 0x2211;
    s.rcx = 0;
    s.rsi = 0;
    // 66 AF (SCASW)
    tests.push_back({"scasw (match)", cat, {0x66, 0xAF},
                      s, FL_ALL, 0, false,
                      {src_data2, src_data2 + 8}, 0});

    // SCASQ: compare RAX with [RDI]
    s.rax = 0x8877665544332211;
    // 48 AF (SCASQ)
    tests.push_back({"scasq (match)", cat, {0x48, 0xAF},
                      s, FL_ALL, 0, false,
                      {src_data2, src_data2 + 8}, 0});

    // CMPSW: compare [RSI] with [RDI]
    s.rsi = DATA_ADDR;
    s.rdi = DATA_ADDR;
    s.rax = 0;
    // 66 A7 (CMPSW)
    tests.push_back({"cmpsw (equal)", cat, {0x66, 0xA7},
                      s, FL_ALL, 0, false,
                      {src_data2, src_data2 + 8}, 0});

    // CMPSD (string): compare [RSI] dword with [RDI] dword
    // A7 (CMPSD)
    tests.push_back({"cmpsd (equal)", cat, {0xA7},
                      s, FL_ALL, 0, false,
                      {src_data2, src_data2 + 8}, 0});

    // CMPSQ: compare [RSI] qword with [RDI] qword
    // 48 A7 (CMPSQ)
    tests.push_back({"cmpsq (equal)", cat, {0x48, 0xA7},
                      s, FL_ALL, 0, false,
                      {src_data2, src_data2 + 8}, 0});
  }

  // =====================================================================
  // 56. XGETBV test
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rcx = 0; // XCR0
    // XGETBV: 0F 01 D0
    add_xmm("xgetbv ecx=0", {0x0F, 0x01, 0xD0}, s, 0x0);
  }

  // =====================================================================
  // 57. More EVEX integer operations
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // VPADDQ xmm0, xmm1, xmm2: 62 F1 F5 08 D4 C2 (66,W=1)
    add_xmm("evex vpaddq xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0xD4, 0xC2}, s, 0x7);

    // VPSUBQ xmm0, xmm1, xmm2: 62 F1 F5 08 FB C2
    add_xmm("evex vpsubq xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0xFB, 0xC2}, s, 0x7);

    // VPSUBB xmm0, xmm1, xmm2: 62 F1 75 08 F8 C2 (66,W=0)
    add_xmm("evex vpsubb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xF8, 0xC2}, s, 0x7);

    // VPMINUB xmm0, xmm1, xmm2: 62 F1 75 08 DA C2
    add_xmm("evex vpminub xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xDA, 0xC2}, s, 0x7);

    // VPSLLD xmm0, xmm1, imm8(4): EVEX.128.66.0F W0 72 /6 ib
    // 62 F1 75 08 72 F1 04
    // Here reg=xmm1 (in vvvv for shift-imm), rm=xmm1, dst written to vvvv
    // Actually for VPSLLD by immediate, encoding is:
    // EVEX prefix + 72 + ModRM(/6=reg field 6, r/m=src) + imm8
    // dst = vvvv, src = r/m
    // 62 [F1] [75] [08] 72 [mod=11,reg=6,rm=1=0xF1] 04
    add_xmm("evex vpslld xmm0,xmm1,4",
            {0x62, 0xF1, 0x7D, 0x08, 0x72, 0xF1, 0x04}, s, 0x7);

    // VPSRLD xmm0, xmm1, imm8(4): 62 F1 7D 08 72 D1 04 (/2)
    add_xmm("evex vpsrld xmm0,xmm1,4",
            {0x62, 0xF1, 0x7D, 0x08, 0x72, 0xD1, 0x04}, s, 0x7);
  }

  // =====================================================================
  // 58. More EVEX FP operations
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f32(1.0f, 4.0f, 9.0f, 16.0f);
    s.xmm[2] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);

    // VDIVPS xmm0, xmm1, xmm2: 62 F1 74 08 5E C2
    add_xmm("evex vdivps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x5E, 0xC2}, s, 0x7);

    // VMINPS xmm0, xmm1, xmm2: 62 F1 74 08 5D C2
    add_xmm("evex vminps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x5D, 0xC2}, s, 0x7);

    // VMAXPS xmm0, xmm1, xmm2: 62 F1 74 08 5F C2
    add_xmm("evex vmaxps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x5F, 0xC2}, s, 0x7);

    // VSQRTPS xmm0, xmm1: 62 F1 7C 08 51 C1 (NP,W=0,vvvv=1111)
    add_xmm("evex vsqrtps xmm0,xmm1",
            {0x62, 0xF1, 0x7C, 0x08, 0x51, 0xC1}, s, 0x3);
  }
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f64(1.5, 4.0);
    s.xmm[2] = xmm_from_f64(3.0, 2.0);

    // VSUBPD xmm0, xmm1, xmm2: 62 F1 F5 08 5C C2 (66,W=1)
    add_xmm("evex vsubpd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0x5C, 0xC2}, s, 0x7);

    // VDIVPD xmm0, xmm1, xmm2: 62 F1 F5 08 5E C2
    add_xmm("evex vdivpd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0x5E, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 59. EVEX FMA (more variants)
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);

    // VFMSUB132PS: 62 F2 75 08 9A C2
    add_xmm("evex vfmsub132ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x9A, 0xC2}, s, 0x7);

    // VFNMADD132PS: 62 F2 75 08 9C C2
    add_xmm("evex vfnmadd132ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x9C, 0xC2}, s, 0x7);

    // VFNMSUB132PS: 62 F2 75 08 9E C2
    add_xmm("evex vfnmsub132ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x9E, 0xC2}, s, 0x7);

    // VFMSUB213PS: 62 F2 75 08 AA C2
    add_xmm("evex vfmsub213ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xAA, 0xC2}, s, 0x7);

    // VFNMADD213PS: 62 F2 75 08 AC C2
    add_xmm("evex vfnmadd213ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xAC, 0xC2}, s, 0x7);

    // VFNMSUB213PS: 62 F2 75 08 AE C2
    add_xmm("evex vfnmsub213ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xAE, 0xC2}, s, 0x7);

    // VFMSUB231PS: 62 F2 75 08 BA C2
    s.xmm[0] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    add_xmm("evex vfmsub231ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xBA, 0xC2}, s, 0x7);

    // VFNMADD231PS: 62 F2 75 08 BC C2
    add_xmm("evex vfnmadd231ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xBC, 0xC2}, s, 0x7);

    // VFNMSUB231PS: 62 F2 75 08 BE C2
    add_xmm("evex vfnmsub231ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xBE, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 60. EVEX FMA instructions (PD and scalar)
  //
  // VFMADD132PS: dst = dst * src3 + vvvv
  // EVEX.128.66.0F38.W0: P0=0xF2 (mm=10), P1=0x75, P2=0x08
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);   // dst (a)
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f); // vvvv (c)
    s.xmm[2] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);    // src3 (b)
    // Result: a*b + c = {12, 23, 34, 45}

    // VFMADD132PS xmm0, xmm1, xmm2: 62 F2 75 08 98 C2
    add_xmm("evex vfmadd132ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x98, 0xC2}, s, 0x7);

    // VFMADD213PS: dst = vvvv * dst + src3 → xmm1 * xmm0 + xmm2
    // Opcode 0xA8: 62 F2 75 08 A8 C2
    s.xmm[0] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);
    // Result: xmm1 * xmm0 + xmm2 = {21, 61, 121, 201}
    add_xmm("evex vfmadd213ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xA8, 0xC2}, s, 0x7);

    // VFMADD231PS: dst = vvvv * src3 + dst → xmm1 * xmm2 + xmm0
    // Opcode 0xB8: 62 F2 75 08 B8 C2
    s.xmm[0] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    // Result: xmm1 * xmm2 + xmm0 = {21, 61, 121, 201}
    add_xmm("evex vfmadd231ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xB8, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 61. EVEX FMA PD and scalar SS/SD
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f64(2.0, 3.0);
    s.xmm[1] = xmm_from_f64(10.0, 20.0);
    s.xmm[2] = xmm_from_f64(1.0, 1.0);

    // VFMADD132PD xmm0, xmm1, xmm2: EVEX.128.66.0F38.W1
    // P0=0xF2 (mm=10), P1=0xF5 (W=1,vvvv=1110,1,pp=01), P2=0x08
    add_xmm("evex vfmadd132pd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0xF5, 0x08, 0x98, 0xC2}, s, 0x7);

    // VFMADD213PD: 62 F2 F5 08 A8 C2
    add_xmm("evex vfmadd213pd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0xF5, 0x08, 0xA8, 0xC2}, s, 0x7);

    // VFMADD231PD: 62 F2 F5 08 B8 C2
    s.xmm[0] = xmm_from_f64(1.0, 1.0);
    s.xmm[1] = xmm_from_f64(10.0, 20.0);
    s.xmm[2] = xmm_from_f64(2.0, 3.0);
    add_xmm("evex vfmadd231pd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0xF5, 0x08, 0xB8, 0xC2}, s, 0x7);
  }
  {
    // Scalar FMA: VFMADD132SS, VFMADD132SD
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(2.0f, 99.0f, 99.0f, 99.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 88.0f, 88.0f, 88.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 77.0f, 77.0f, 77.0f);

    // VFMADD132SS: EVEX.LIG.66.0F38.W0 99 /r
    // 62 F2 75 08 99 C2
    add_xmm("evex vfmadd132ss xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x99, 0xC2}, s, 0x7);

    // VFMADD213SS: 62 F2 75 08 A9 C2
    add_xmm("evex vfmadd213ss xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xA9, 0xC2}, s, 0x7);

    // VFMADD231SS: 62 F2 75 08 B9 C2
    add_xmm("evex vfmadd231ss xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xB9, 0xC2}, s, 0x7);

    s.xmm[0] = xmm_from_f64(2.0, 99.0);
    s.xmm[1] = xmm_from_f64(10.0, 88.0);
    s.xmm[2] = xmm_from_f64(1.0, 77.0);

    // VFMADD132SD: EVEX.LIG.66.0F38.W1 99 /r
    // 62 F2 F5 08 99 C2
    add_xmm("evex vfmadd132sd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0xF5, 0x08, 0x99, 0xC2}, s, 0x7);

    // VFMADD213SD: 62 F2 F5 08 A9 C2
    add_xmm("evex vfmadd213sd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0xF5, 0x08, 0xA9, 0xC2}, s, 0x7);

    // VFMADD231SD: 62 F2 F5 08 B9 C2
    add_xmm("evex vfmadd231sd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0xF5, 0x08, 0xB9, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 62. FBLD/FBSTP (BCD load/store)
  // =====================================================================
  cat = "x87";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;

    // FBLD loads a 10-byte packed BCD from memory
    // FBSTP stores to 10-byte packed BCD and pops
    // BCD encoding: 10 bytes, each nibble is a digit, byte 9 bit 7 = sign
    // Value 12345: stored as 45 23 01 00 00 00 00 00 00 00
    u8 bcd_data[10] = {0x45, 0x23, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

    // FBLD [RDI]: DF /4 → DF 27 (mod=00, reg=4, rm=7=RDI)
    // then FBSTP [RDI+16]: DF /6 → DF 6F 10
    tests.push_back({"fbld+fbstp", cat,
                      {0xDF, 0x27, 0xDF, 0x6F, 0x10},
                      s, FL_ALL, 0, false,
                      {bcd_data, bcd_data + 10}, 26});
  }

  // =====================================================================
  // 63. EVEX 256-bit (YMM) operations
  //
  // P2: z=0, L'L=01 (256-bit), b=0, V'=1, aaa=000
  //   → P2 = 0b_0_01_0_1_000 = 0x28
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);
    // YMM upper halves (xmm indices 17, 18 in our model — but KVM uses
    // xsave area). For register-to-register, we set initial YMM state.
    // Our harness only sets XMM[0..15], not YMM upper halves.
    // Let's use 128-bit tests that are already well-covered and add
    // a few 256-bit integer tests.

    // VPADDD ymm0, ymm1, ymm2 (EVEX.256.66.0F.W0):
    // P0=0xF1 (mm=01), P1=0x75, P2=0x28 (L'L=01)
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);
    add_xmm("evex vpaddd ymm0,ymm1,ymm2 (256)",
            {0x62, 0xF1, 0x75, 0x28, 0xFE, 0xC2}, s, 0x7);

    // VADDPS ymm0, ymm1, ymm2 (EVEX.256.NP.0F.W0):
    // P1=0x74 (vvvv=1110,pp=00), P2=0x28
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);
    add_xmm("evex vaddps ymm0,ymm1,ymm2 (256)",
            {0x62, 0xF1, 0x74, 0x28, 0x58, 0xC2}, s, 0x7);

    // VPXORD ymm0, ymm1, ymm2 (EVEX.256.66.0F.W0):
    s.xmm[1] = xmm_from_u64(0xFFFFFFFF00000000, 0x12345678ABCDEF01);
    s.xmm[2] = xmm_from_u64(0x0F0F0F0FF0F0F0F0, 0xFEDCBA9876543210);
    add_xmm("evex vpxord ymm0,ymm1,ymm2 (256)",
            {0x62, 0xF1, 0x75, 0x28, 0xEF, 0xC2}, s, 0x7);

    // VMULPS ymm0, ymm1, ymm2 (EVEX.256.NP.0F.W0):
    s.xmm[1] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    s.xmm[2] = xmm_from_f32(10.0f, 10.0f, 10.0f, 10.0f);
    add_xmm("evex vmulps ymm0,ymm1,ymm2 (256)",
            {0x62, 0xF1, 0x74, 0x28, 0x59, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 64. EVEX shuffle/permutation
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // VSHUFPS xmm0, xmm1, xmm2, imm8: EVEX.128.NP.0F.W0 C6 /r ib
    // 62 F1 74 08 C6 C2 0x1B (select 3,2,1,0 → reverse)
    add_xmm("evex vshufps xmm0,xmm1,xmm2,0x1B",
            {0x62, 0xF1, 0x74, 0x08, 0xC6, 0xC2, 0x1B}, s, 0x7);

    // VUNPCKLPS xmm0, xmm1, xmm2: EVEX.128.NP.0F.W0 14 /r
    add_xmm("evex vunpcklps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x14, 0xC2}, s, 0x7);

    // VUNPCKHPS xmm0, xmm1, xmm2: EVEX.128.NP.0F.W0 15 /r
    add_xmm("evex vunpckhps xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x74, 0x08, 0x15, 0xC2}, s, 0x7);

    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // VPUNPCKLDQ xmm0, xmm1, xmm2: EVEX.128.66.0F.W0 62 /r
    add_xmm("evex vpunpckldq xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0x62, 0xC2}, s, 0x7);

    // VPUNPCKLQDQ xmm0, xmm1, xmm2: EVEX.128.66.0F.W1 6C /r
    add_xmm("evex vpunpcklqdq xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0x6C, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 65. EVEX conversion instructions
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f32(1.5f, 2.7f, -3.2f, 4.9f);

    // VCVTPS2DQ xmm0, xmm1: EVEX.128.66.0F.W0 5B /r
    // 62 F1 7D 08 5B C1 (vvvv=1111 unused)
    add_xmm("evex vcvtps2dq xmm0,xmm1",
            {0x62, 0xF1, 0x7D, 0x08, 0x5B, 0xC1}, s, 0x3);

    // VCVTTPS2DQ xmm0, xmm1: EVEX.128.F3.0F.W0 5B /r
    // 62 F1 7E 08 5B C1
    add_xmm("evex vcvttps2dq xmm0,xmm1",
            {0x62, 0xF1, 0x7E, 0x08, 0x5B, 0xC1}, s, 0x3);

    // VCVTDQ2PS xmm0, xmm1: EVEX.128.NP.0F.W0 5B /r
    s.xmm[1] = xmm_from_u64(0x0000000100000002, 0x00000003FFFFFFFE);
    add_xmm("evex vcvtdq2ps xmm0,xmm1",
            {0x62, 0xF1, 0x7C, 0x08, 0x5B, 0xC1}, s, 0x3);
  }

  // =====================================================================
  // 66. EVEX VFMADDSUB / VFMSUBADD
  //
  // VFMADDSUB132PS: even elements use subtract, odd use add
  // (result[i] = a*b+c for odd i, a*b-c for even i)
  // EVEX.128.66.0F38.W0: opcode 0x96
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);

    // VFMADDSUB132PS: 62 F2 75 08 96 C2
    add_xmm("evex vfmaddsub132ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x96, 0xC2}, s, 0x7);

    // VFMADDSUB213PS: 62 F2 75 08 A6 C2
    add_xmm("evex vfmaddsub213ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xA6, 0xC2}, s, 0x7);

    // VFMADDSUB231PS: 62 F2 75 08 B6 C2
    s.xmm[0] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    add_xmm("evex vfmaddsub231ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xB6, 0xC2}, s, 0x7);

    // VFMSUBADD132PS: 62 F2 75 08 97 C2
    s.xmm[0] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);
    add_xmm("evex vfmsubadd132ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x97, 0xC2}, s, 0x7);

    // VFMSUBADD213PS: 62 F2 75 08 A7 C2
    add_xmm("evex vfmsubadd213ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xA7, 0xC2}, s, 0x7);

    // VFMSUBADD231PS: 62 F2 75 08 B7 C2
    s.xmm[0] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    add_xmm("evex vfmsubadd231ps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0xB7, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 67. EVEX 0F38 arithmetic/comparison
  // EVEX.128.66.0F38: P0=0xF2 (mm=10), P1=0x75 (W=0,66), P2=0x08
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x0807060504030201, 0x100F0E0D0C0B0A09);

    // VPMINSB xmm0, xmm1, xmm2: 62 F2 75 08 38 C2
    add_xmm("evex vpminsb xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x38, 0xC2}, s, 0x7);

    // VPMINSD xmm0, xmm1, xmm2: 62 F2 75 08 39 C2
    add_xmm("evex vpminsd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x39, 0xC2}, s, 0x7);

    // VPMAXSB xmm0, xmm1, xmm2: 62 F2 75 08 3C C2
    add_xmm("evex vpmaxsb xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x3C, 0xC2}, s, 0x7);

    // VPMAXSD xmm0, xmm1, xmm2: 62 F2 75 08 3D C2
    add_xmm("evex vpmaxsd xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x3D, 0xC2}, s, 0x7);

    // VPMINUD xmm0, xmm1, xmm2: 62 F2 75 08 3B C2
    add_xmm("evex vpminud xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x3B, 0xC2}, s, 0x7);

    // VPMAXUD xmm0, xmm1, xmm2: 62 F2 75 08 3F C2
    add_xmm("evex vpmaxud xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x3F, 0xC2}, s, 0x7);

    // VPACKUSDW xmm0, xmm1, xmm2: 62 F2 75 08 2B C2
    add_xmm("evex vpackusdw xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x2B, 0xC2}, s, 0x7);

    // VPMULLD xmm0, xmm1, xmm2: 62 F2 75 08 40 C2
    add_xmm("evex vpmulld xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x40, 0xC2}, s, 0x7);

    // VPMULUDQ xmm0, xmm1, xmm2: 62 F1 F5 08 F4 C2 (66,W=1)
    add_xmm("evex vpmuludq xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0xF5, 0x08, 0xF4, 0xC2}, s, 0x7);

    // VPMULLW xmm0, xmm1, xmm2: 62 F1 75 08 D5 C2 (0F map)
    add_xmm("evex vpmullw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xD5, 0xC2}, s, 0x7);

    // VPABSB xmm0, xmm1: EVEX.128.66.0F38.W0 1C /r
    // 62 F2 7D 08 1C C1 (vvvv=1111 unused)
    s.xmm[1] = xmm_from_u64(0x80FF01027F00FE03, 0x0405060708090A0B);
    add_xmm("evex vpabsb xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x1C, 0xC1}, s, 0x3);

    // VPABSD xmm0, xmm1: 62 F2 7D 08 1E C1
    add_xmm("evex vpabsd xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x1E, 0xC1}, s, 0x3);
  }

  // =====================================================================
  // 68. EVEX permutation/shuffle
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    // Control: element i selects src[ctrl[i][1:0]]
    // 0x03020100 → select [0,1,2,3] (identity)
    // 0x00010203 → select [3,2,1,0] (reverse)
    s.xmm[2] = xmm_from_u64(0x0000000300000002, 0x0000000100000000);

    // VPERMILPS xmm0, xmm1, xmm2: EVEX.128.66.0F38.W0 0C /r
    // 62 F2 75 08 0C C2
    add_xmm("evex vpermilps xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x0C, 0xC2}, s, 0x7);

    // Reverse: ctrl=[3,2,1,0]
    s.xmm[2] = xmm_from_u64(0x0000000000000001, 0x0000000200000003);
    add_xmm("evex vpermilps rev xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x0C, 0xC2}, s, 0x7);

    // VPERMILPS with immediate: EVEX.128.66.0F3A.W0 04 /r ib
    // 62 F3 7D 08 04 C1 1B → VPERMILPS xmm0, xmm1, 0x1B (reverse)
    add_xmm("evex vpermilps xmm0,xmm1,0x1B",
            {0x62, 0xF3, 0x7D, 0x08, 0x04, 0xC1, 0x1B}, s, 0x3);

    // VPSHUFB xmm0, xmm1, xmm2: EVEX.128.66.0F38.W0 00 /r
    // 62 F2 75 08 00 C2
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    // Control: byte shuffle. High bit = zero out, otherwise idx&0xF selects byte.
    s.xmm[2] = xmm_from_u64(0x0001020380040506, 0x0708090A0B0C0D0E);
    add_xmm("evex vpshufb xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x00, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 69. EVEX immediate instructions (0F3A map)
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // VPALIGNR xmm0, xmm1, xmm2, 4: EVEX.128.66.0F3A.WIG 0F /r ib
    // 62 F3 75 08 0F C2 04
    add_xmm("evex vpalignr xmm0,xmm1,xmm2,4",
            {0x62, 0xF3, 0x75, 0x08, 0x0F, 0xC2, 0x04}, s, 0x7);

    // VPEXTRB ecx, xmm1, 3: EVEX.128.66.0F3A.WIG 14 /r ib
    // 62 F3 7D 08 14 C9 03 (reg=xmm1, r/m=ecx)
    add_xmm("evex vpextrb ecx,xmm1,3",
            {0x62, 0xF3, 0x7D, 0x08, 0x14, 0xC9, 0x03}, s, 0x3);

    // VPEXTRD ecx, xmm1, 2: EVEX.128.66.0F3A.W0 16 /r ib
    // 62 F3 7D 08 16 C9 02
    add_xmm("evex vpextrd ecx,xmm1,2",
            {0x62, 0xF3, 0x7D, 0x08, 0x16, 0xC9, 0x02}, s, 0x3);

    // VPINSRB xmm0, xmm1, ecx, 5: EVEX.128.66.0F3A.WIG 20 /r ib
    // 62 F3 75 08 20 C1 05
    s.rcx = 0x42;
    add_xmm("evex vpinsrb xmm0,xmm1,ecx,5",
            {0x62, 0xF3, 0x75, 0x08, 0x20, 0xC1, 0x05}, s, 0x7);

    // VPINSRD xmm0, xmm1, ecx, 1: EVEX.128.66.0F3A.W0 22 /r ib
    // 62 F3 75 08 22 C1 01
    s.rcx = 0xDEADBEEF;
    add_xmm("evex vpinsrd xmm0,xmm1,ecx,1",
            {0x62, 0xF3, 0x75, 0x08, 0x22, 0xC1, 0x01}, s, 0x7);

    // VPSHUFD xmm0, xmm1, 0x1B: EVEX.128.66.0F.W0 70 /r ib
    // 62 F1 7D 08 70 C1 1B
    add_xmm("evex vpshufd xmm0,xmm1,0x1B",
            {0x62, 0xF1, 0x7D, 0x08, 0x70, 0xC1, 0x1B}, s, 0x3);

    // VPSHUFHW xmm0, xmm1, 0x1B: EVEX.128.F3.0F.WIG 70 /r ib
    // 62 F1 7E 08 70 C1 1B
    add_xmm("evex vpshufhw xmm0,xmm1,0x1B",
            {0x62, 0xF1, 0x7E, 0x08, 0x70, 0xC1, 0x1B}, s, 0x3);

    // VPSHUFLW xmm0, xmm1, 0x1B: EVEX.128.F2.0F.WIG 70 /r ib
    // 62 F1 7F 08 70 C1 1B
    add_xmm("evex vpshuflw xmm0,xmm1,0x1B",
            {0x62, 0xF1, 0x7F, 0x08, 0x70, 0xC1, 0x1B}, s, 0x3);
  }

  // =====================================================================
  // 70. EVEX more arithmetic (0F38 map)
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x0807060504030201, 0x100F0E0D0C0B0A09);

    // VPMAXUW xmm0, xmm1, xmm2: 62 F2 75 08 3E C2
    add_xmm("evex vpmaxuw xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x3E, 0xC2}, s, 0x7);

    // VPABSW xmm0, xmm1: 62 F2 7D 08 1D C1
    s.xmm[1] = xmm_from_u64(0x80007FFF00010002, 0xFFFE000300040005);
    add_xmm("evex vpabsw xmm0,xmm1",
            {0x62, 0xF2, 0x7D, 0x08, 0x1D, 0xC1}, s, 0x3);

    // VPABSQ xmm0, xmm1: 62 F2 FD 08 1F C1 (W=1)
    s.xmm[1] = xmm_from_u64(0xFFFFFFFFFFFFFFFF, 0x0000000000000001);
    add_xmm("evex vpabsq xmm0,xmm1",
            {0x62, 0xF2, 0xFD, 0x08, 0x1F, 0xC1}, s, 0x3);

    // VPMADDUBSW xmm0, xmm1, xmm2: 62 F2 75 08 04 C2
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    add_xmm("evex vpmaddubsw xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x04, 0xC2}, s, 0x7);

    // VPMULHRSW xmm0, xmm1, xmm2: 62 F2 75 08 0B C2
    add_xmm("evex vpmulhrsw xmm0,xmm1,xmm2",
            {0x62, 0xF2, 0x75, 0x08, 0x0B, 0xC2}, s, 0x7);

    // VPMADDWD xmm0, xmm1, xmm2: EVEX.128.66.0F.W0 F5 /r
    // 62 F1 75 08 F5 C2
    add_xmm("evex vpmaddwd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xF5, 0xC2}, s, 0x7);

    // VPSADBW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG F6 /r
    // 62 F1 75 08 F6 C2
    add_xmm("evex vpsadbw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xF6, 0xC2}, s, 0x7);

    // VPMULHUW xmm0, xmm1, xmm2: EVEX.128.66.0F.W0 E4 /r
    // 62 F1 75 08 E4 C2
    add_xmm("evex vpmulhuw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xE4, 0xC2}, s, 0x7);

    // VPMULHW xmm0, xmm1, xmm2: EVEX.128.66.0F.W0 E5 /r
    // 62 F1 75 08 E5 C2
    add_xmm("evex vpmulhw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xE5, 0xC2}, s, 0x7);

    // VPAVGB xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG E0 /r
    // 62 F1 75 08 E0 C2
    add_xmm("evex vpavgb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xE0, 0xC2}, s, 0x7);

    // VPAVGW xmm0, xmm1, xmm2: EVEX.128.66.0F.WIG E3 /r
    // 62 F1 75 08 E3 C2
    add_xmm("evex vpavgw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xE3, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 71. EVEX data movement and more integer
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
    s.xmm[2] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);

    // VMOVDQA32 xmm0, xmm1: EVEX.128.66.0F.W0 6F /r
    // 62 F1 7D 08 6F C1
    add_xmm("evex vmovdqa32 xmm0,xmm1",
            {0x62, 0xF1, 0x7D, 0x08, 0x6F, 0xC1}, s, 0x3);

    // VMOVD xmm0, ecx: EVEX.128.66.0F.W0 6E /r
    // 62 F1 7D 08 6E C1 (reg=xmm0, r/m=ecx)
    s.rcx = 0xDEADBEEF;
    add_xmm("evex vmovd xmm0,ecx",
            {0x62, 0xF1, 0x7D, 0x08, 0x6E, 0xC1}, s, 0x3);

    // VMOVQ xmm0, rcx: EVEX.128.66.0F.W1 6E /r
    // 62 F1 FD 08 6E C1
    s.rcx = 0x123456789ABCDEF0;
    add_xmm("evex vmovq xmm0,rcx",
            {0x62, 0xF1, 0xFD, 0x08, 0x6E, 0xC1}, s, 0x3);

    // VPADDB xmm0, xmm1, xmm2: 62 F1 75 08 FC C2
    add_xmm("evex vpaddb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xFC, 0xC2}, s, 0x7);

    // VPADDW xmm0, xmm1, xmm2: 62 F1 75 08 FD C2
    add_xmm("evex vpaddw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xFD, 0xC2}, s, 0x7);

    // VPSUBW xmm0, xmm1, xmm2: 62 F1 75 08 F9 C2
    add_xmm("evex vpsubw xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xF9, 0xC2}, s, 0x7);

    // VPANDND xmm0, xmm1, xmm2: 62 F1 75 08 DF C2
    add_xmm("evex vpandnd xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xDF, 0xC2}, s, 0x7);

    // VPADDSB xmm0, xmm1, xmm2: 62 F1 75 08 EC C2
    add_xmm("evex vpaddsb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xEC, 0xC2}, s, 0x7);

    // VPADDUSB xmm0, xmm1, xmm2: 62 F1 75 08 DC C2
    add_xmm("evex vpaddusb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xDC, 0xC2}, s, 0x7);

    // VPSUBSB xmm0, xmm1, xmm2: 62 F1 75 08 E8 C2
    add_xmm("evex vpsubsb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xE8, 0xC2}, s, 0x7);

    // VPSUBUSB xmm0, xmm1, xmm2: 62 F1 75 08 D8 C2
    add_xmm("evex vpsubusb xmm0,xmm1,xmm2",
            {0x62, 0xF1, 0x75, 0x08, 0xD8, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // 72. EVEX FP comparison
  // =====================================================================
  cat = "EVEX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[2] = xmm_from_f32(4.0f, 2.0f, 1.0f, 5.0f);

    // VCMPPS xmm0, xmm1, xmm2, 0 (EQ): EVEX.128.NP.0F.W0 C2 /r ib
    // Result goes to k register in AVX-512, but if no masking, still
    // writes to register. Actually VCMPPS in EVEX writes to k register.
    // Let me use VUCOMISS instead which writes to RFLAGS.

    // VUCOMISS xmm1, xmm2: EVEX.LIG.NP.0F.W0 2E /r
    // 62 F1 7C 08 2E CA (reg=xmm1, r/m=xmm2)
    add_xmm("evex vucomiss xmm1,xmm2",
            {0x62, 0xF1, 0x7C, 0x08, 0x2E, 0xCA}, s, 0x3);

    s.xmm[1] = xmm_from_f64(1.5, 2.5);
    s.xmm[2] = xmm_from_f64(3.0, 2.5);

    // VUCOMISD xmm1, xmm2: EVEX.LIG.66.0F.W1 2E /r
    // 62 F1 FD 08 2E CA
    add_xmm("evex vucomisd xmm1,xmm2",
            {0x62, 0xF1, 0xFD, 0x08, 0x2E, 0xCA}, s, 0x3);
  }

  // =====================================================================
  // 73. VEX VFMADDSUB / VFMSUBADD
  // =====================================================================
  cat = "AVX";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(2.0f, 3.0f, 4.0f, 5.0f);
    s.xmm[1] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
    s.xmm[2] = xmm_from_f32(1.0f, 1.0f, 1.0f, 1.0f);

    // VFMADDSUB132PS: C4 E2 71 96 C2
    add_xmm("vex vfmaddsub132ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0x96, 0xC2}, s, 0x7);

    // VFMADDSUB213PS: C4 E2 71 A6 C2
    add_xmm("vex vfmaddsub213ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xA6, 0xC2}, s, 0x7);

    // VFMSUBADD132PS: C4 E2 71 97 C2
    add_xmm("vex vfmsubadd132ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0x97, 0xC2}, s, 0x7);

    // VFMSUBADD213PS: C4 E2 71 A7 C2
    add_xmm("vex vfmsubadd213ps xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xA7, 0xC2}, s, 0x7);
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

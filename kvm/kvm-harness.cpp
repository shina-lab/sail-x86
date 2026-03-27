// KVM-based differential test harness for sail-x86.
//
// Sets up a KVM VM in 64-bit long mode, runs test instruction sequences,
// and compares the resulting architectural state against the Sail model.

#include "kvm-harness.h"
#include "x86-helpers.h"

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
    if (kvm_fd < 0) {
      perror("/dev/kvm");
      return false;
    }

    int api_ver = ioctl(kvm_fd, KVM_GET_API_VERSION, 0);
    if (api_ver != 12) {
      fprintf(stderr, "KVM API version %d (expected 12)\n", api_ver);
      return false;
    }

    vm_fd = ioctl(kvm_fd, KVM_CREATE_VM, 0UL);
    if (vm_fd < 0) {
      perror("KVM_CREATE_VM");
      return false;
    }

    guest_mem = (u8 *)mmap(nullptr, GUEST_MEM_SIZE,
                           PROT_READ | PROT_WRITE,
                           MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (guest_mem == MAP_FAILED) {
      perror("mmap guest");
      return false;
    }

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
    if (vcpu_fd < 0) {
      perror("KVM_CREATE_VCPU");
      return false;
    }

    int mmap_size = ioctl(kvm_fd, KVM_GET_VCPU_MMAP_SIZE, 0);
    if (mmap_size < 0) {
      perror("KVM_GET_VCPU_MMAP_SIZE");
      return false;
    }
    run = (struct kvm_run *)mmap(nullptr, mmap_size, PROT_READ | PROT_WRITE,
                                 MAP_SHARED, vcpu_fd, 0);
    if (run == MAP_FAILED) {
      perror("mmap vcpu");
      return false;
    }

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
    // U/S bit set at all levels so user-mode (CPL 3) tests can work.
    u64 *pml4 = (u64 *)(guest_mem + PML4_ADDR);
    pml4[0] = PDPT_ADDR | 0x7;  // present + writable + user

    u64 *pdpt = (u64 *)(guest_mem + PDPT_ADDR);
    pdpt[0] = PD_ADDR | 0x7;    // present + writable + user

    u64 *pd = (u64 *)(guest_mem + PD_ADDR);
    pd[0] = 0x0 | 0x87;  // 2MB page, present + writable + user + PS

    // IDT: exception handlers for vectors 0-31
    {
      // Vectors with error codes pushed by CPU
      auto has_error_code = [](int v) {
        return v == 8 || v == 10 || v == 11 || v == 12 ||
               v == 13 || v == 14 || v == 17 || v == 21 || v == 30;
      };

      // Write handler stubs at HANDLER_ADDR, 16 bytes each
      for (int v = 0; v < 32; v++) {
        u8 stub[16];
        memset(stub, 0xCC, sizeof(stub));  // fill with INT3
        int off = 0;
        if (!has_error_code(v)) {
          stub[off++] = 0x6A;  // push 0 (dummy error code)
          stub[off++] = 0x00;
        } else {
          stub[off++] = 0x90;  // nop nop (error code on stack)
          stub[off++] = 0x90;
        }
        stub[off++] = 0x6A;   // push <vector>
        stub[off++] = (u8)v;
        stub[off++] = 0xE9;                          // jmp rel32
        u64 stub_addr = HANDLER_ADDR + v * 16;
        i32 rel = (i32)(COMMON_HANDLER - (stub_addr + off + 4));
        memcpy(stub + off, &rel, 4);
        memcpy(guest_mem + stub_addr, stub, 16);
      }

      // Common handler: pop vector + error code, store at FAULT_INFO_ADDR, HLT
      u8 common[] = {
        0x58,                                                     // pop rax (vector)
        0x48, 0x89, 0x04, 0x25,                                   // mov [FAULT_INFO_ADDR], rax
          (u8)(FAULT_INFO_ADDR), (u8)(FAULT_INFO_ADDR >> 8),
          (u8)(FAULT_INFO_ADDR >> 16), (u8)(FAULT_INFO_ADDR >> 24),
        0x58,                                                     // pop rax (error code)
        0x48, 0x89, 0x04, 0x25,                                   // mov [FAULT_INFO_ADDR+8], rax
          (u8)(FAULT_INFO_ADDR + 8), (u8)((FAULT_INFO_ADDR + 8) >> 8),
          (u8)((FAULT_INFO_ADDR + 8) >> 16), (u8)((FAULT_INFO_ADDR + 8) >> 24),
        0x48, 0x8B, 0x04, 0x24,                                   // mov rax, [rsp]
        0x48, 0x89, 0x04, 0x25,                                   // mov [FAULT_INFO_ADDR+16], rax
          (u8)(FAULT_INFO_ADDR + 16), (u8)((FAULT_INFO_ADDR + 16) >> 8),
          (u8)((FAULT_INFO_ADDR + 16) >> 16), (u8)((FAULT_INFO_ADDR + 16) >> 24),
        0xF4,                                                     // hlt
      };
      memcpy(guest_mem + COMMON_HANDLER, common, sizeof(common));

      // Write IDT entries (16-bit interrupt gate descriptors)
      for (int v = 0; v < 32; v++) {
        u64 handler = HANDLER_ADDR + v * 16;
        u8 entry[16] = {};
        u16 offset_lo = handler & 0xFFFF;
        u16 selector = 0x08;  // code segment
        u8 type_attr = 0x8E;  // present, DPL=0, 64-bit interrupt gate
        u16 offset_mid = (handler >> 16) & 0xFFFF;
        u32 offset_hi = (handler >> 32) & 0xFFFFFFFF;
        memcpy(entry + 0, &offset_lo, 2);
        memcpy(entry + 2, &selector, 2);
        entry[4] = 0;  // IST = 0
        entry[5] = type_attr;
        memcpy(entry + 6, &offset_mid, 2);
        memcpy(entry + 8, &offset_hi, 4);
        memcpy(guest_mem + IDT_ADDR + v * 16, entry, 16);
      }
    }

    // GDT: null, 64-bit code, data, plus test entries for LAR/LSL/VERR/VERW
    u64 *gdt = (u64 *)(guest_mem + GDT_ADDR);
    gdt[0] = 0;
    gdt[1] = 0x00AF9A000000FFFF;  // 64-bit code (selector 0x08): type=0xA, S=1
    gdt[2] = 0x00CF92000000FFFF;  // data (selector 0x10): type=0x2, S=1
    // 64-bit TSS at TSS_ADDR (selector 0x18): type=0x9, S=0, P=1
    // Descriptor: base=TSS_ADDR, limit=0x67 (103 bytes)
    gdt[3] = 0x0000890000000067ULL
           | ((TSS_ADDR & 0x00FFFFFF) << 16)
           | ((TSS_ADDR & 0xFF000000) << 32);
    gdt[4] = 0;  // upper half: base[63:32] = 0

    // Write TSS data: RSP0 at offset 4
    u8 *tss = guest_mem + TSS_ADDR;
    memset(tss, 0, 104);
    u64 rsp0 = STACK_TOP;
    memcpy(tss + 4, &rsp0, 8);
    gdt[5] = 0x00008E0000000000;  // interrupt gate type (selector 0x28): type=0xE, S=0, P=1
    gdt[6] = 0;                   // upper half
    gdt[7] = 0x00CF90000000FFFF;  // read-only data (selector 0x38): type=0x0, S=1, P=1
    gdt[8] = 0x00AF98000000FFFF;  // execute-only code (selector 0x40): type=0x8, S=1, P=1
    gdt[9] = 0x00CF9A000000FFFF;   // 32-bit code (selector 0x48): type=0xA, S=1, D=1, L=0
    gdt[10] = 0x00AFFA000000FFFF;  // 64-bit user code (selector 0x53): type=0xA, S=1, DPL=3, L=1
    gdt[11] = 0x00CFF2000000FFFF;  // user data (selector 0x5B): type=0x2, S=1, DPL=3

    struct kvm_sregs sregs;
    ioctl(vcpu_fd, KVM_GET_SREGS, &sregs);

    sregs.cr0 = 0x80000011;  // PE + PG + ET (EM=0, TS=0 for SSE)
    sregs.cr4 = 0x50620;     // PAE + OSFXSR + OSXMMEXCPT + FSGSBASE + OSXSAVE
    sregs.efer = 0x500;      // LME + LMA
    sregs.cr3 = PML4_ADDR;

    sregs.gdt.base = GDT_ADDR;
    sregs.gdt.limit = 12 * 8 - 1;

    sregs.idt.base = IDT_ADDR;
    sregs.idt.limit = 32 * 16 - 1;

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

    // Task Register — needed for privilege-level changes (RSP0 from TSS)
    sregs.tr = {};
    sregs.tr.base = TSS_ADDR;
    sregs.tr.limit = 103;
    sregs.tr.selector = 0x18;
    sregs.tr.type = 0xB;  // 64-bit TSS (busy)
    sregs.tr.present = 1;
    sregs.tr.s = 0;

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
    // Restore default XCR0 and CR4 (may have been overridden by previous test)
    struct kvm_xcrs xcrs_default = {};
    xcrs_default.nr_xcrs = 1;
    xcrs_default.xcrs[0].xcr = 0;
    xcrs_default.xcrs[0].value = 0xE7;
    ioctl(vcpu_fd, KVM_SET_XCRS, &xcrs_default);

    struct kvm_sregs sregs_tmp;
    ioctl(vcpu_fd, KVM_GET_SREGS, &sregs_tmp);
    sregs_tmp.cr4 = 0x50620;  // PAE + OSFXSR + OSXMMEXCPT + FSGSBASE + OSXSAVE
    // Set CS based on processor mode
    if (tc.compat_mode) {
      sregs_tmp.cs.selector = 0x48;
      sregs_tmp.cs.l = 0;   // Not 64-bit
      sregs_tmp.cs.db = 1;  // 32-bit default operand/address size
    } else {
      sregs_tmp.cs.selector = 0x08;
      sregs_tmp.cs.l = 1;   // 64-bit
      sregs_tmp.cs.db = 0;
    }
    // Restore SS to kernel data segment (previous test may have changed it,
    // e.g. IRET to user mode sets SS.DPL=3 which causes #SS for kernel code).
    sregs_tmp.ss = {};
    sregs_tmp.ss.base = 0;
    sregs_tmp.ss.limit = 0xFFFFFFFF;
    sregs_tmp.ss.selector = 0x10;
    sregs_tmp.ss.type = 0x2;
    sregs_tmp.ss.present = 1;
    sregs_tmp.ss.db = 1;
    sregs_tmp.ss.s = 1;
    sregs_tmp.ss.g = 1;
    ioctl(vcpu_fd, KVM_SET_SREGS, &sregs_tmp);

    memset(guest_mem + CODE_ADDR, 0, 0x1000);
    memset(guest_mem + DATA_ADDR, 0, 0x1000);
    memset(guest_mem + FAULT_INFO_ADDR, 0xFF, 24);  // clear fault info

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
    // XMM0-XMM15 low 128 bits at offset 0xA0 (16 bytes each)
    for (int i = 0; i < 16; i++)
      memcpy(xs + 0xA0 + i * 16, &tc.initial.xmm[i].q[0], 16);
    // YMM0-YMM15 upper 128 bits at offset 0x240 (component 2/AVX, 16 bytes each)
    for (int i = 0; i < 16; i++)
      memcpy(xs + 0x240 + i * 16, &tc.initial.xmm[i].q[2], 16);
    // Opmask registers (k0-k7) at offset 0x340 (component 5, 8 bytes each)
    for (int i = 0; i < 8; i++)
      memcpy(xs + 0x340 + i * 8, &tc.initial.kregs[i], 8);
    // ZMM0-ZMM15 upper 256 bits at offset 0x380 (component 6/ZMM_Hi256, 32 bytes each)
    for (int i = 0; i < 16; i++)
      memcpy(xs + 0x380 + i * 32, &tc.initial.xmm[i].q[4], 32);
    // ZMM16-ZMM31 full 512 bits at offset 0x580 (component 7/Hi16_ZMM, 64 bytes each)
    for (int i = 0; i < 16; i++)
      memcpy(xs + 0x580 + i * 64, &tc.initial.xmm[16 + i].q[0], 64);

    // XSTATE_BV at offset 0x200: all AVX-512 components
    u64 xstate_bv = 0xE7;  // x87 + SSE + AVX + opmask + ZMM_Hi256 + Hi16_ZMM
    memcpy(xs + 0x200, &xstate_bv, 8);
    ioctl(vcpu_fd, KVM_SET_XSAVE, &xsave);

    // Apply per-test XCR0 override if requested
    if (tc.xcr0_override) {
      struct kvm_xcrs xcrs = {};
      xcrs.nr_xcrs = 1;
      xcrs.xcrs[0].xcr = 0;
      xcrs.xcrs[0].value = tc.xcr0_override;
      ioctl(vcpu_fd, KVM_SET_XCRS, &xcrs);
    }

    // Apply per-test CR4 override if requested
    if (tc.cr4_override) {
      struct kvm_sregs sregs;
      ioctl(vcpu_fd, KVM_GET_SREGS, &sregs);
      sregs.cr4 = tc.cr4_override;
      ioctl(vcpu_fd, KVM_SET_SREGS, &sregs);
    }
  }

  // Check if a KVM run resulted in a fault (HLT in exception handler area).
  bool check_kvm_fault(FaultInfo &fi) {
    struct kvm_regs regs;
    ioctl(vcpu_fd, KVM_GET_REGS, &regs);
    if (regs.rip > COMMON_HANDLER && regs.rip <= COMMON_HANDLER + 0x100) {
      fi.faulted = true;
      u64 vec_val;
      u64 err_val;
      u64 rip_val;
      memcpy(&vec_val, guest_mem + FAULT_INFO_ADDR, 8);
      memcpy(&err_val, guest_mem + FAULT_INFO_ADDR + 8, 8);
      memcpy(&rip_val, guest_mem + FAULT_INFO_ADDR + 16, 8);
      fi.vector = (int)vec_val;
      fi.error_code = err_val;
      fi.faulting_rip = rip_val;
      return true;
    }
    return false;
  }

  // Run test expecting a fault. Returns fault info.
  FaultInfo run_test_fault() {
    if (ioctl(vcpu_fd, KVM_RUN, 0) < 0) {
      perror("KVM_RUN");
      abort();
    }

    FaultInfo fi;
    if (run->exit_reason == KVM_EXIT_HLT) {
      if (check_kvm_fault(fi))
        return fi;
      fprintf(stderr, "KVM: expected fault but got normal HLT\n");
      abort();
    }
    if (run->exit_reason == KVM_EXIT_SHUTDOWN) {
      fprintf(stderr, "KVM: triple fault (shutdown) — IDT setup problem?\n");
      abort();
    }
    fprintf(stderr, "KVM: unexpected exit reason %d\n", run->exit_reason);
    abort();
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

    // Check for unexpected fault
    FaultInfo fi;
    if (check_kvm_fault(fi)) {
      fprintf(stderr, "KVM: unexpected fault #%d (error 0x%lx) at RIP=0x%lx\n",
              fi.vector, fi.error_code, fi.faulting_rip);
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
    // XMM0-15 low 128 bits
    for (int i = 0; i < 16; i++)
      memcpy(&state.xmm[i].q[0], xs + 0xA0 + i * 16, 16);
    // YMM0-15 upper 128 bits
    for (int i = 0; i < 16; i++)
      memcpy(&state.xmm[i].q[2], xs + 0x240 + i * 16, 16);
    // Opmask registers (k0-k7)
    for (int i = 0; i < 8; i++)
      memcpy(&state.kregs[i], xs + 0x340 + i * 8, 8);
    // ZMM0-15 upper 256 bits
    for (int i = 0; i < 16; i++)
      memcpy(&state.xmm[i].q[4], xs + 0x380 + i * 32, 32);
    // ZMM16-31 full 512 bits
    for (int i = 0; i < 16; i++)
      memcpy(&state.xmm[16 + i].q[0], xs + 0x580 + i * 64, 64);
    return state;
  }

  // Read data area for memory comparison
  void read_data(u8 *buf, size_t len) {
    memcpy(buf, guest_mem + DATA_ADDR, len);
  }
};

// ---- Sail model execution ----

static void map_guest_page(u64 addr, size_t len) {
  void *p = mmap((void *)addr, len, PROT_READ | PROT_WRITE,
                 MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED_NOREPLACE, -1, 0);
  if (p == MAP_FAILED) {
    fprintf(stderr, "mmap failed at 0x%lx: %s\n", addr, strerror(errno));
    abort();
  }
}

ArchState run_sail(const TestCase &tc, u8 *data_out, size_t data_len,
                   FaultInfo *fault_out = nullptr) {
  x86::Model model;
  model.model_init();
  model.zinitializze_registers(UNIT);
  x86::enable_all_features(model);
  model.zcur_mode = tc.compat_mode ? x86::zCompatibilityMode : x86::zLongMode;
  model.zcur_cpl = 0;

  // Set up segment descriptor caches.
  // In compatibility mode, CS.D=1 for 32-bit default operand/address size.
  // In long mode, CS.L=1 and CS.D=0 (SDM Vol.3A §3.4.5).
  // All segments get flat 4GB limits (base=0, limit=0xFFFFFFFF, present).
  for (int i = 0; i < 6; i++) {
    model.zSegCache.data[i].zseg_base = 0;
    model.zSegCache.data[i].zseg_limit = 0xFFFFFFFF;
    model.zSegCache.data[i].zseg_present = 1;
    model.zSegCache.data[i].zseg_s = 1;
    model.zSegCache.data[i].zseg_g = 1;
    model.zSegCache.data[i].zseg_db = 1;
  }
  if (tc.compat_mode) {
    model.zSegCache.data[x86::SEG_CS].zseg_l = 0;
  } else {
    model.zSegCache.data[x86::SEG_CS].zseg_db = 0;
    model.zSegCache.data[x86::SEG_CS].zseg_l = 1;
  }
  model.zCR4 = 0x50620;  // PAE + OSFXSR + OSXMMEXCPT + FSGSBASE + OSXSAVE

  // Ensure guest pages are mapped (idempotent after first call).
  static bool pages_mapped = false;
  if (!pages_mapped) {
    map_guest_page(CODE_ADDR, 0x1000);
    map_guest_page(DATA_ADDR, 0x1000);
    map_guest_page(STACK_TOP - 0x1000, 0x1000);
    // Map page for Sail-side GDT (can't use 0x3000, too low for mmap)
    map_guest_page(0x14000, 0x1000);
    pages_mapped = true;
  }

  // Write test code + HLT
  memset((void *)CODE_ADDR, 0, 0x1000);
  memcpy((void *)CODE_ADDR, tc.code.data(), tc.code.size());
  u8 hlt = 0xF4;
  memcpy((void *)(CODE_ADDR + tc.code.size()), &hlt, 1);

  // Set up data area
  memset((void *)DATA_ADDR, 0, 0x1000);
  if (!tc.init_data.empty())
    memcpy((void *)DATA_ADDR, tc.init_data.data(), tc.init_data.size());

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

  // Initialize GDTR and write GDT entries to match KVM guest
  // Use 0x14000 for Sail-side GDT (0x3000 is too low for mmap)
  static constexpr u64 SAIL_GDT_ADDR = 0x14000;
  model.zGDTR_base = SAIL_GDT_ADDR;
  model.zGDTR_limit = 12 * 8 - 1;

  // Set up Sail-side TSS with RSP0
  static constexpr u64 SAIL_TSS_ADDR = SAIL_GDT_ADDR + 0x800;
  model.zTR_base = SAIL_TSS_ADDR;
  memset((void *)SAIL_TSS_ADDR, 0, 104);
  u64 sail_rsp0 = STACK_TOP;
  memcpy((void *)(SAIL_TSS_ADDR + 4), &sail_rsp0, 8);

  ((u64 *)SAIL_GDT_ADDR)[0] = 0;
  ((u64 *)SAIL_GDT_ADDR)[1] = 0x00AF9A000000FFFF;  // 64-bit code (selector 0x08)
  ((u64 *)SAIL_GDT_ADDR)[2] = 0x00CF92000000FFFF;  // data (selector 0x10)
  // 64-bit TSS descriptor at SAIL_TSS_ADDR
  ((u64 *)SAIL_GDT_ADDR)[3] = 0x0000890000000067ULL
    | ((SAIL_TSS_ADDR & 0x00FFFFFFULL) << 16)
    | ((SAIL_TSS_ADDR & 0xFF000000ULL) << 32);
  ((u64 *)SAIL_GDT_ADDR)[4] = 0;  // upper half: base[63:32] = 0
  ((u64 *)SAIL_GDT_ADDR)[5] = 0x00008E0000000000;  // interrupt gate type (selector 0x28)
  ((u64 *)SAIL_GDT_ADDR)[6] = 0;                   // upper half
  ((u64 *)SAIL_GDT_ADDR)[7] = 0x00CF90000000FFFF;  // read-only data (selector 0x38)
  ((u64 *)SAIL_GDT_ADDR)[8] = 0x00AF98000000FFFF;  // execute-only code (selector 0x40)
  ((u64 *)SAIL_GDT_ADDR)[9] = 0x00CF9A000000FFFF;   // 32-bit code (selector 0x48)
  ((u64 *)SAIL_GDT_ADDR)[10] = 0x00AFFA000000FFFF;  // 64-bit user code (selector 0x53)
  ((u64 *)SAIL_GDT_ADDR)[11] = 0x00CFF2000000FFFF;  // user data (selector 0x5B)

  // Initialize x87 FPU to default state (CW=0x037F, etc.)
  model.zx87_init(UNIT);

  // Set ZMM registers and MXCSR
  model.mxcsr_state.mxcsr = tc.initial.mxcsr;
  for (int i = 0; i < 32; i++) {
    u8 bytes[64];
    memcpy(bytes, &tc.initial.xmm[i].q[0], 64);
    RECREATE(lbits)(&model.zZMM.data[i]);
    bytes_to_zmm(&model.zZMM.data[i], bytes);
  }

  // Set k-registers (opmask)
  for (int i = 0; i < 8; i++)
    model.zKREG.data[i] = tc.initial.kregs[i];

  // Apply per-test XCR0/CR4 overrides
  if (tc.xcr0_override)
    model.zXCR0 = tc.xcr0_override;
  if (tc.cr4_override)
    model.zCR4 = tc.cr4_override;

  for (int i = 0; i < 1000; i++) {
    model.zstep(UNIT);
    if (model.zfault_pending) {
      i64 vec = model.zfault_vector;
      u32 err = model.zfault_error_code;
      if (fault_out) {
        fault_out->faulted = true;
        fault_out->vector = (int)vec;
        fault_out->error_code = err;
        fault_out->faulting_rip = model.zRIP;
        model.model_fini();
        return {};
      }
      fprintf(stderr, "Sail: fault #%ld (error 0x%x) at RIP=0x%lx [%s]\n",
              vec, err, model.zRIP, tc.name.c_str());
      fprintf(stderr, "  code bytes:");
      for (size_t j = 0; j < tc.code.size(); j++)
        fprintf(stderr, " %02x", tc.code[j]);
      fprintf(stderr, "\n");
      abort();
    }
    if (model.zsystem_state == x86::zSysHalted) goto done;
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
    memcpy(data_out, (void *)DATA_ADDR, data_len);

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
  for (int i = 0; i < 32; i++) {
    u8 bytes[64];
    zmm_to_bytes(model.zZMM.data[i], bytes);
    memcpy(&state.xmm[i].q[0], bytes, 64);
  }
  for (int i = 0; i < 8; i++)
    state.kregs[i] = model.zKREG.data[i];

  model.model_fini();
  return state;
}

std::vector<TestCase> build_tests() {
  std::vector<TestCase> tests;

  add_baseline_tests(tests);
  add_sse_tests(tests);
  add_misc_instruction_tests(tests);
  add_x87_avx_tests(tests);
  add_fp_edge_tests(tests);
  add_encoding_tests(tests);
  add_systematic_tests(tests);
  add_exception_tests(tests);

  add_mmx_tests(tests);
  add_feature_tests(tests);
  add_compat_tests(tests);
  add_xsave_tests(tests);
  add_avx_comprehensive_tests(tests);

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
  int passed = 0;
  int failed = 0;
  std::string last_cat;

  for (const auto &tc : tests) {
    if (filter && tc.category.compare(0, strlen(filter), filter) != 0)
      continue;
    if (tc.category != last_cat) {
      last_cat = tc.category;
      fprintf(stderr, "Testing %s ...\n", last_cat.c_str());
    }
    vm.load_test(tc);

    if (tc.expect_fault) {
      // Fault-expecting test: compare exception vector and error code.
      FaultInfo kvm_fault = vm.run_test_fault();
      FaultInfo sail_fault;
      run_sail(tc, nullptr, 0, &sail_fault);

      bool ok = true;
      if (!kvm_fault.faulted) {
        fprintf(stderr, "  KVM: expected fault but none occurred\n");
        ok = false;
      }
      if (!sail_fault.faulted) {
        fprintf(stderr, "  Sail: expected fault but none occurred\n");
        ok = false;
      }
      if (kvm_fault.faulted && sail_fault.faulted) {
        if (kvm_fault.vector != sail_fault.vector) {
          fprintf(stderr, "  MISMATCH vector: kvm=%d sail=%d\n",
                  kvm_fault.vector, sail_fault.vector);
          ok = false;
        }
        if (kvm_fault.error_code != sail_fault.error_code) {
          fprintf(stderr, "  MISMATCH error_code: kvm=0x%lx sail=0x%lx\n",
                  kvm_fault.error_code, sail_fault.error_code);
          ok = false;
        }
        if (tc.expected_vector >= 0 && kvm_fault.vector != tc.expected_vector) {
          fprintf(stderr, "  UNEXPECTED vector: got %d expected %d\n",
                  kvm_fault.vector, tc.expected_vector);
          ok = false;
        }
      }

      if (ok) {
        passed++;
      } else {
        fprintf(stderr, "FAIL: %s (kvm: #%d err=0x%lx rip=0x%lx, sail: #%d err=0x%lx rip=0x%lx)\n",
                tc.name.c_str(),
                kvm_fault.vector, kvm_fault.error_code, kvm_fault.faulting_rip,
                sail_fault.vector, sail_fault.error_code, sail_fault.faulting_rip);
        failed++;
      }
    } else {
      // Normal test: compare architectural state.
      ArchState kvm_state = vm.run_test();

      u8 kvm_data[4096] = {}, sail_data[4096] = {};
      if (tc.compare_data_len > 0)
        vm.read_data(kvm_data, tc.compare_data_len);

      ArchState sail_state = run_sail(tc, sail_data, tc.compare_data_len);

      bool ok = kvm_state.compare(sail_state, tc.flags_mask, tc.xmm_mask,
                                  tc.cmp_mxcsr, tc.kreg_mask);

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
  }

  fprintf(stderr, "%d passed, %d failed out of %d tests\n",
          passed, failed, passed + failed);
  return failed > 0 ? 1 : 0;
}

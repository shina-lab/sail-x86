// KVM-based differential test harness for sail-x86.
//
// Sets up a KVM VM in 64-bit long mode, runs test instruction sequences,
// and compares the resulting architectural state against the Sail model.

#include "kvm_harness.h"

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
          stub[off++] = 0x6A; stub[off++] = 0x00;  // push 0 (dummy error code)
        } else {
          stub[off++] = 0x90; stub[off++] = 0x90;  // nop nop (error code on stack)
        }
        stub[off++] = 0x6A; stub[off++] = (u8)v;   // push <vector>
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
    // XMM0-XMM15 at offset 0xA0 (16 bytes each)
    for (int i = 0; i < 16; i++) {
      memcpy(xs + 0xA0 + i * 16,     &tc.initial.xmm[i].lo, 8);
      memcpy(xs + 0xA0 + i * 16 + 8, &tc.initial.xmm[i].hi, 8);
    }
    // Opmask registers (k0-k7) at offset 0x340 (component 5, 8 bytes each)
    // Offset from CPUID leaf 0xD subleaf 5: EBX=0x340
    for (int i = 0; i < 8; i++)
      memcpy(xs + 0x340 + i * 8, &tc.initial.kregs[i], 8);

    // XSTATE_BV at offset 0x200: bits 0(x87) + 1(SSE) + 2(AVX) + 5(opmask)
    u64 xstate_bv = 0x27;  // bits 0,1,2,5
    memcpy(xs + 0x200, &xstate_bv, 8);
    ioctl(vcpu_fd, KVM_SET_XSAVE, &xsave);
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
    for (int i = 0; i < 16; i++) {
      memcpy(&state.xmm[i].lo, xs + 0xA0 + i * 16,     8);
      memcpy(&state.xmm[i].hi, xs + 0xA0 + i * 16 + 8, 8);
    }
    // Opmask registers (k0-k7) at offset 0x340 (component 5)
    for (int i = 0; i < 8; i++)
      memcpy(&state.kregs[i], xs + 0x340 + i * 8, 8);
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
  model.zcur_mode = x86::zLongMode;
  model.zcur_cpl = 0;

  // Ensure guest pages are mapped (idempotent after first call).
  static bool pages_mapped = false;
  if (!pages_mapped) {
    map_guest_page(CODE_ADDR, 0x1000);
    map_guest_page(DATA_ADDR, 0x1000);
    map_guest_page(STACK_TOP - 0x1000, 0x1000);
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

  // Set k-registers (opmask)
  for (int i = 0; i < 8; i++)
    model.zKREG.data[i] = tc.initial.kregs[i];

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
  for (int i = 0; i < 16; i++) {
    u8 bytes[16];
    xmm_to_bytes(model.zZMM.data[i], bytes);
    memcpy(&state.xmm[i].lo, bytes,     8);
    memcpy(&state.xmm[i].hi, bytes + 8, 8);
  }
  for (int i = 0; i < 8; i++)
    state.kregs[i] = model.zKREG.data[i];

  model.model_fini();
  return state;
}

std::vector<TestCase> build_tests() {
  std::vector<TestCase> tests;
  std::string cat;

  auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                      u32 xmm_cmp) {
    tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
  };
  add_baseline_tests(tests);
  add_sse_tests(tests);
  add_misc_instruction_tests(tests);
  add_x87_avx_tests(tests);
  add_fp_edge_tests(tests);
  add_extended_instruction_tests(tests);
  add_systematic_tests(tests);
  add_exception_tests(tests);

  // =====================================================================
  // MOVQ store (66 0F D6) + VMOVQ store (VEX.128.66.0F D6)
  // =====================================================================
  cat = "MOVQ store";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0xDEADBEEFCAFEBABE, 0x1234567890ABCDEF);

    // 66 0F D6 C8: MOVQ xmm0, xmm1 (reg-reg: store low qword of xmm1 to xmm0, zero upper)
    // ModRM: mod=11, reg=1(src), rm=0(dst) → 0xC8
    add_xmm("movq xmm0,xmm1 (66 0F D6)", {0x66, 0x0F, 0xD6, 0xC8}, s, 0x3);

    // VEX.128.66.0F D6: VMOVQ xmm0, xmm1
    // 2-byte VEX: C5 [R̄.vvvv.L.pp]
    // R̄=1, vvvv=1111, L=0, pp=01(66) → 0xF9
    // C5 F9 D6 C8: VMOVQ xmm0, xmm1
    // reg=xmm1(1), rm=xmm0(0): ModRM = mod=11, reg=001, rm=000 → 0xC8
    add_xmm("vmovq xmm0,xmm1 (VEX D6)", {0xC5, 0xF9, 0xD6, 0xC8}, s, 0x3);
  }

  // =====================================================================
  // VEX 0F3A — blend, extract, insert, align, carry-less multiply
  // =====================================================================
  cat = "VEX 0F3A";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    // VBLENDPS xmm0, xmm1, xmm2, 0x05
    // VEX.128.66.0F3A 0C /r ib — C4 E3 71 0C C2 05
    // imm=0x05: select elements 0,2 from src2(xmm2), 1,3 from src1(xmm1)
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      s.xmm[2] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);
      add_xmm("vblendps xmm0,xmm1,xmm2,0x05",
              {0xC4, 0xE3, 0x71, 0x0C, 0xC2, 0x05}, s, 0x7);
    }

    // VBLENDPD xmm0, xmm1, xmm2, 0x01
    // VEX.128.66.0F3A 0D /r ib — C4 E3 71 0D C2 01
    // imm=0x01: select element 0 from src2(xmm2), element 1 from src1(xmm1)
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_f64(1.0, 2.0);
      s.xmm[2] = xmm_from_f64(3.0, 4.0);
      add_xmm("vblendpd xmm0,xmm1,xmm2,0x01",
              {0xC4, 0xE3, 0x71, 0x0D, 0xC2, 0x01}, s, 0x7);
    }

    // VPBLENDW xmm0, xmm1, xmm2, 0xAA
    // VEX.128.66.0F3A 0E /r ib — C4 E3 71 0E C2 AA
    // imm=0xAA: alternating words from src2
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
      s.xmm[2] = xmm_from_u64(0x1011101210131014, 0x1015101610171018);
      add_xmm("vpblendw xmm0,xmm1,xmm2,0xAA",
              {0xC4, 0xE3, 0x71, 0x0E, 0xC2, 0xAA}, s, 0x7);
    }

    // VPALIGNR xmm0, xmm1, xmm2, 4
    // VEX.128.66.0F3A 0F /r ib — C4 E3 71 0F C2 04
    // Shift right 4 bytes: concatenate xmm1:xmm2 and extract 16 bytes at offset 4
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
      s.xmm[2] = xmm_from_u64(0x1112131415161718, 0x191A1B1C1D1E1F20);
      add_xmm("vpalignr xmm0,xmm1,xmm2,4",
              {0xC4, 0xE3, 0x71, 0x0F, 0xC2, 0x04}, s, 0x7);
    }

    // VPEXTRB eax, xmm1, 2
    // VEX.128.66.0F3A 14 /r ib — C4 E3 79 14 C8 02
    // ModRM: mod=11, reg=1(xmm1 src), rm=0(eax dest) → 0xC8
    // vvvv=1111 (unused), byte2=0x79 (W=0,vvvv=1111,L=0,pp=01)
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(0xDEADBEEFCAFE0102, 0x1234567890ABCDEF);
      tests.push_back({"vpextrb eax,xmm1,2", cat,
                       {0xC4, 0xE3, 0x79, 0x14, 0xC8, 0x02}, s, FL_ALL, 0x3});
    }

    // VPEXTRD eax, xmm1, 1
    // VEX.128.66.0F3A 16 /r ib — C4 E3 79 16 C8 01
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      tests.push_back({"vpextrd eax,xmm1,1", cat,
                       {0xC4, 0xE3, 0x79, 0x16, 0xC8, 0x01}, s, FL_ALL, 0x3});
    }

    // VEXTRACTPS eax, xmm1, 2
    // VEX.128.66.0F3A 17 /r ib — C4 E3 79 17 C8 02
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      tests.push_back({"vextractps eax,xmm1,2", cat,
                       {0xC4, 0xE3, 0x79, 0x17, 0xC8, 0x02}, s, FL_ALL, 0x3});
    }

    // VPINSRB xmm0, xmm1, eax, 3
    // VEX.128.66.0F3A 20 /r ib — C4 E3 71 20 C0 03
    // ModRM: mod=11, reg=0(xmm0 dest), rm=0(eax src) → 0xC0
    // vvvv=~1=1110, byte2=0x71
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rax = 0x42;
      s.xmm[1] = xmm_from_u64(0x0102030405060708, 0x090A0B0C0D0E0F10);
      add_xmm("vpinsrb xmm0,xmm1,eax,3",
              {0xC4, 0xE3, 0x71, 0x20, 0xC0, 0x03}, s, 0x3);
    }

    // VPINSRD xmm0, xmm1, eax, 2
    // VEX.128.66.0F3A 22 /r ib — C4 E3 71 22 C0 02
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rax = 0xDEADBEEF;
      s.xmm[1] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      add_xmm("vpinsrd xmm0,xmm1,eax,2",
              {0xC4, 0xE3, 0x71, 0x22, 0xC0, 0x02}, s, 0x3);
    }

    // VPCLMULQDQ xmm0, xmm1, xmm2, 0x00
    // VEX.128.66.0F3A 44 /r ib — C4 E3 71 44 C2 00
    // Carry-less multiply low qwords
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(0x0000000000000007, 0x0000000000000000);
      s.xmm[2] = xmm_from_u64(0x000000000000000B, 0x0000000000000000);
      add_xmm("vpclmulqdq xmm0,xmm1,xmm2,0x00",
              {0xC4, 0xE3, 0x71, 0x44, 0xC2, 0x00}, s, 0x7);
    }

    // VPCLMULQDQ xmm0, xmm1, xmm2, 0x11
    // Carry-less multiply high qwords
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u64(0x0000000000000000, 0x0123456789ABCDEF);
      s.xmm[2] = xmm_from_u64(0x0000000000000000, 0x00000000000000FF);
      add_xmm("vpclmulqdq xmm0,xmm1,xmm2,0x11",
              {0xC4, 0xE3, 0x71, 0x44, 0xC2, 0x11}, s, 0x7);
    }

    // VPBLENDD xmm0, xmm1, xmm2, 0x05
    // VEX.128.66.0F3A 02 /r ib — C4 E3 71 02 C2 05
    // imm=0x05: select dwords 0,2 from src2
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.xmm[1] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      s.xmm[2] = xmm_from_u32(0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC, 0xDDDDDDDD);
      add_xmm("vpblendd xmm0,xmm1,xmm2,0x05",
              {0xC4, 0xE3, 0x71, 0x02, 0xC2, 0x05}, s, 0x7);
    }
  }

  // =====================================================================
  // BMI2 — bit manipulation instructions (GPR tests)
  // =====================================================================
  cat = "BMI2";
  {
    // BZHI eax, ecx, edx — zero high bits in ecx starting at bit position in edx
    // VEX.NDS.LZ.0F38.W0 F5 /r — C4 E2 68 F5 C1
    // reg=0(eax dest), rm=1(ecx src), vvvv=~2=1101(edx index)
    // byte2: W=0,vvvv=1101,L=0,pp=00 → 0x68
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rcx = 0xDEADBEEF12345678;
      s.rdx = 16;
      // 32-bit: eax = ecx[31:0] with bits above 16 cleared = 0x5678
      tests.push_back({"bzhi eax,ecx,edx bit16", cat,
                       {0xC4, 0xE2, 0x68, 0xF5, 0xC1}, s,
                       FL_ZF | FL_SF | FL_CF | FL_OF});
    }
    // BZHI with zero index → result=0, ZF=1
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rcx = 0xFFFFFFFF;
      s.rdx = 0;
      tests.push_back({"bzhi eax,ecx,edx bit0", cat,
                       {0xC4, 0xE2, 0x68, 0xF5, 0xC1}, s,
                       FL_ZF | FL_SF | FL_CF | FL_OF});
    }
    // BZHI 64-bit: rax, rcx, rdx
    // W=1: byte2 = 0b1_1101_0_00 = 0xE8
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rcx = 0xFFFFFFFFFFFFFFFF;
      s.rdx = 32;
      tests.push_back({"bzhi rax,rcx,rdx bit32", cat,
                       {0xC4, 0xE2, 0xE8, 0xF5, 0xC1}, s,
                       FL_ZF | FL_SF | FL_CF | FL_OF});
    }
    // BZHI with index >= operand size → CF=1, result unchanged
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rcx = 0x12345678;
      s.rdx = 40;  // >= 32 for W0
      tests.push_back({"bzhi eax,ecx,edx overflow", cat,
                       {0xC4, 0xE2, 0x68, 0xF5, 0xC1}, s,
                       FL_ZF | FL_SF | FL_CF | FL_OF});
    }

    // PDEP eax, ecx, edx — parallel bit deposit
    // VEX.NDS.LZ.F2.0F38.W0 F5 /r — C4 E2 73 F5 C2
    // reg=0(eax dest), vvvv=~1=1110(ecx src), rm=2(edx mask)
    // byte2: W=0,vvvv=1110,L=0,pp=11(F2) → 0x73
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rcx = 0x000000FF;  // source bits
      s.rdx = 0x55555555;  // mask: every other bit
      tests.push_back({"pdep eax,ecx,edx", cat,
                       {0xC4, 0xE2, 0x73, 0xF5, 0xC2}, s, FL_NONE});
    }
    // PDEP 64-bit
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rcx = 0x00000000000000FF;
      s.rdx = 0x5555555555555555;
      // W=1: byte2 = 0b1_1110_0_11 = 0xF3
      tests.push_back({"pdep rax,rcx,rdx 64", cat,
                       {0xC4, 0xE2, 0xF3, 0xF5, 0xC2}, s, FL_NONE});
    }

    // PEXT eax, ecx, edx — parallel bit extract
    // VEX.NDS.LZ.F3.0F38.W0 F5 /r — C4 E2 72 F5 C2
    // byte2: W=0,vvvv=1110,L=0,pp=10(F3) → 0x72
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rcx = 0xAAAAAAAA;  // source
      s.rdx = 0x55555555;  // mask: every other bit
      tests.push_back({"pext eax,ecx,edx", cat,
                       {0xC4, 0xE2, 0x72, 0xF5, 0xC2}, s, FL_NONE});
    }
    // PEXT 64-bit
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rcx = 0xAAAAAAAAAAAAAAAA;
      s.rdx = 0x5555555555555555;
      // W=1: byte2 = 0b1_1110_0_10 = 0xF2
      tests.push_back({"pext rax,rcx,rdx 64", cat,
                       {0xC4, 0xE2, 0xF2, 0xF5, 0xC2}, s, FL_NONE});
    }

    // MULX ebx, eax, ecx — unsigned multiply EDX * ECX → EBX:EAX
    // VEX.NDD.LZ.F2.0F38.W0 F6 /r — C4 E2 7B F6 D9
    // reg=3(ebx hi), vvvv=~0=1111(eax lo), rm=1(ecx src)
    // byte2: W=0,vvvv=1111,L=0,pp=11(F2) → 0x7B
    // ModRM: mod=11, reg=011, rm=001 → 0xD9
    // Implicit src1 = EDX
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rdx = 100;
      s.rcx = 200;
      tests.push_back({"mulx ebx,eax,ecx 100*200", cat,
                       {0xC4, 0xE2, 0x7B, 0xF6, 0xD9}, s, FL_NONE});
    }
    // MULX with large values to produce high part
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rdx = 0xFFFFFFFF;
      s.rcx = 0xFFFFFFFF;
      tests.push_back({"mulx ebx,eax,ecx max32", cat,
                       {0xC4, 0xE2, 0x7B, 0xF6, 0xD9}, s, FL_NONE});
    }
    // MULX 64-bit: W=1, byte2 = 0b1_1111_0_11 = 0xFB
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rdx = 0x100000000;
      s.rcx = 0x100000000;
      tests.push_back({"mulx rbx,rax,rcx 64", cat,
                       {0xC4, 0xE2, 0xFB, 0xF6, 0xD9}, s, FL_NONE});
    }

    // SARX eax, ecx, edx — arithmetic shift right without flags
    // VEX.NDS.LZ.F3.0F38.W0 F7 /r — C4 E2 6A F7 C1
    // reg=0(eax dest), rm=1(ecx src), vvvv=~2=1101(edx count)
    // byte2: W=0,vvvv=1101,L=0,pp=10(F3) → 0x6A
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rcx = 0x80000000;  // negative when treated as signed 32-bit
      s.rdx = 4;
      tests.push_back({"sarx eax,ecx,edx", cat,
                       {0xC4, 0xE2, 0x6A, 0xF7, 0xC1}, s, FL_NONE});
    }

    // SHLX eax, ecx, edx — logical shift left without flags
    // VEX.NDS.LZ.66.0F38.W0 F7 /r — C4 E2 69 F7 C1
    // byte2: W=0,vvvv=1101,L=0,pp=01(66) → 0x69
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rcx = 0x12345678;
      s.rdx = 8;
      tests.push_back({"shlx eax,ecx,edx", cat,
                       {0xC4, 0xE2, 0x69, 0xF7, 0xC1}, s, FL_NONE});
    }

    // SHRX eax, ecx, edx — logical shift right without flags
    // VEX.NDS.LZ.F2.0F38.W0 F7 /r — C4 E2 6B F7 C1
    // byte2: W=0,vvvv=1101,L=0,pp=11(F2) → 0x6B
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rcx = 0x12345678;
      s.rdx = 8;
      tests.push_back({"shrx eax,ecx,edx", cat,
                       {0xC4, 0xE2, 0x6B, 0xF7, 0xC1}, s, FL_NONE});
    }

    // SARX 64-bit: W=1, byte2 = 0b1_1101_0_10 = 0xEA
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rcx = 0x8000000000000000;
      s.rdx = 16;
      tests.push_back({"sarx rax,rcx,rdx 64", cat,
                       {0xC4, 0xE2, 0xEA, 0xF7, 0xC1}, s, FL_NONE});
    }

    // SHLX 64-bit: W=1, byte2 = 0b1_1101_0_01 = 0xE9
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rcx = 0x0000000000000001;
      s.rdx = 63;
      tests.push_back({"shlx rax,rcx,rdx 64", cat,
                       {0xC4, 0xE2, 0xE9, 0xF7, 0xC1}, s, FL_NONE});
    }

    // SHRX 64-bit: W=1, byte2 = 0b1_1101_0_11 = 0xEB
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rcx = 0x8000000000000000;
      s.rdx = 32;
      tests.push_back({"shrx rax,rcx,rdx 64", cat,
                       {0xC4, 0xE2, 0xEB, 0xF7, 0xC1}, s, FL_NONE});
    }

    // RORX eax, ecx, 4 — rotate right without flags
    // VEX.LZ.F2.0F3A.W0 F0 /r ib — C4 E3 7B F0 C1 04
    // byte1=0xE3 (mmmmm=00011=0F3A), byte2: W=0,vvvv=1111,L=0,pp=11(F2) → 0x7B
    // reg=0(eax dest), rm=1(ecx src), imm=4
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rcx = 0x12345678;
      tests.push_back({"rorx eax,ecx,4", cat,
                       {0xC4, 0xE3, 0x7B, 0xF0, 0xC1, 0x04}, s, FL_NONE});
    }
    // RORX 64-bit: W=1, byte2 = 0b1_1111_0_11 = 0xFB
    {
      ArchState s = {};
      s.rflags = 0x2;
      s.rcx = 0x123456789ABCDEF0;
      tests.push_back({"rorx rax,rcx,8 64", cat,
                       {0xC4, 0xE3, 0xFB, 0xF0, 0xC1, 0x08}, s, FL_NONE});
    }
  }

  // =====================================================================
  // VEX AES-NI — AES encryption/decryption rounds
  // =====================================================================
  cat = "VEX AES-NI";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    // Common AES test state — non-trivial data in xmm registers
    ArchState aes = {};
    aes.rflags = 0x2;
    aes.xmm[1] = xmm_from_u64(0x0123456789ABCDEF, 0xFEDCBA9876543210);
    aes.xmm[2] = xmm_from_u64(0x0F0E0D0C0B0A0908, 0x0706050403020100);

    // VAESENC xmm0, xmm1, xmm2 — one AES encryption round
    // VEX.128.66.0F38.WIG DC /r — C4 E2 71 DC C2
    // vvvv=~1=1110, byte2: W=0,vvvv=1110,L=0,pp=01 → 0x71
    add_xmm("vaesenc xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xDC, 0xC2}, aes, 0x7);

    // VAESENCLAST xmm0, xmm1, xmm2 — last AES encryption round
    // VEX.128.66.0F38.WIG DD /r — C4 E2 71 DD C2
    add_xmm("vaesenclast xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xDD, 0xC2}, aes, 0x7);

    // VAESDEC xmm0, xmm1, xmm2 — one AES decryption round
    // VEX.128.66.0F38.WIG DE /r — C4 E2 71 DE C2
    add_xmm("vaesdec xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xDE, 0xC2}, aes, 0x7);

    // VAESDECLAST xmm0, xmm1, xmm2 — last AES decryption round
    // VEX.128.66.0F38.WIG DF /r — C4 E2 71 DF C2
    add_xmm("vaesdeclast xmm0,xmm1,xmm2",
            {0xC4, 0xE2, 0x71, 0xDF, 0xC2}, aes, 0x7);

    // VAESIMC xmm0, xmm1 — AES InvMixColumns
    // VEX.128.66.0F38.WIG DB /r — C4 E2 79 DB C1
    // vvvv=1111 (unary), byte2=0x79
    add_xmm("vaesimc xmm0,xmm1",
            {0xC4, 0xE2, 0x79, 0xDB, 0xC1}, aes, 0x3);

    // VAESKEYGENASSIST xmm0, xmm1, 0x01 — AES key expansion assist
    // VEX.128.66.0F3A.WIG DF /r ib — C4 E3 79 DF C1 01
    // vvvv=1111 (unary), byte1=0xE3 (0F3A), byte2=0x79
    add_xmm("vaeskeygenassist xmm0,xmm1,0x01",
            {0xC4, 0xE3, 0x79, 0xDF, 0xC1, 0x01}, aes, 0x3);

    // VAESKEYGENASSIST with different round constant
    add_xmm("vaeskeygenassist xmm0,xmm1,0x02",
            {0xC4, 0xE3, 0x79, 0xDF, 0xC1, 0x02}, aes, 0x3);

    // Second set of AES data to increase coverage
    ArchState aes2 = {};
    aes2.rflags = 0x2;
    aes2.xmm[1] = xmm_from_u64(0x00112233AABBCCDD, 0xEEFF001122334455);
    aes2.xmm[2] = xmm_from_u64(0x5A5A5A5A5A5A5A5A, 0xA5A5A5A5A5A5A5A5);

    add_xmm("vaesenc xmm0,xmm1,xmm2 v2",
            {0xC4, 0xE2, 0x71, 0xDC, 0xC2}, aes2, 0x7);
    add_xmm("vaesenclast xmm0,xmm1,xmm2 v2",
            {0xC4, 0xE2, 0x71, 0xDD, 0xC2}, aes2, 0x7);
    add_xmm("vaesdec xmm0,xmm1,xmm2 v2",
            {0xC4, 0xE2, 0x71, 0xDE, 0xC2}, aes2, 0x7);
    add_xmm("vaesdeclast xmm0,xmm1,xmm2 v2",
            {0xC4, 0xE2, 0x71, 0xDF, 0xC2}, aes2, 0x7);
  }

  // =====================================================================
  // 74. VEX SSSE3 — VEX-encoded SSSE3 integer instructions (0F38 map)
  // =====================================================================
  cat = "VEX SSSE3";

  // 3-operand VEX SSSE3 tests: dst=xmm0, src1=xmm1, src2=xmm2
  // VEX.128.66.0F38: C4 E2 71 <op> C2
  //   E2 = R̄=1,X̄=1,B̄=1,mmmmm=00010(0F38)
  //   71 = W=0,vvvv=1110(~xmm1),L=0,pp=01(66)
  {
    ArchState s = {};
    s.rflags = 0x2;
    // Shuffle source: bytes 0x00..0x0F
    s.xmm[1] = xmm_from_u64(0x0F0E0D0C0B0A0908, 0x0706050403020100);
    // Shuffle control: mix of indices and high-bit-set (zeroing) entries
    s.xmm[2] = xmm_from_u64(0x830201008F060504, 0x0302010083020100);

    // VPSHUFB xmm0, xmm1, xmm2: C4 E2 71 00 C2
    add_xmm("vpshufb xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x00, 0xC2}, s, 0x7);
  }

  {
    ArchState s = {};
    s.rflags = 0x2;
    // Words for horizontal add/sub: distinct values to verify lane pairing
    s.xmm[1] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
    s.xmm[2] = xmm_from_u64(0x0010002000300040, 0x0050006000700080);

    // VPHADDW xmm0, xmm1, xmm2: C4 E2 71 01 C2
    add_xmm("vphaddw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x01, 0xC2}, s, 0x7);
    // VPHADDD xmm0, xmm1, xmm2: C4 E2 71 02 C2
    add_xmm("vphaddd xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x02, 0xC2}, s, 0x7);
    // VPHADDSW xmm0, xmm1, xmm2: C4 E2 71 03 C2
    add_xmm("vphaddsw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x03, 0xC2}, s, 0x7);
    // VPMADDUBSW xmm0, xmm1, xmm2: C4 E2 71 04 C2
    add_xmm("vpmaddubsw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x04, 0xC2}, s, 0x7);
    // VPHSUBW xmm0, xmm1, xmm2: C4 E2 71 05 C2
    add_xmm("vphsubw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x05, 0xC2}, s, 0x7);
    // VPHSUBD xmm0, xmm1, xmm2: C4 E2 71 06 C2
    add_xmm("vphsubd xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x06, 0xC2}, s, 0x7);
    // VPHSUBSW xmm0, xmm1, xmm2: C4 E2 71 07 C2
    add_xmm("vphsubsw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x07, 0xC2}, s, 0x7);
    // VPMULHRSW xmm0, xmm1, xmm2: C4 E2 71 0B C2
    add_xmm("vpmulhrsw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x0B, 0xC2}, s, 0x7);
  }

  // VPSIGN — sign/zero/negate paths
  {
    ArchState s = {};
    s.rflags = 0x2;
    // Mix of positive, negative, zero values
    s.xmm[1] = xmm_from_u64(0x01FF037F05816082, 0x7FFFFFFF80000001);
    // Control: positive (keep), negative (negate), zero (zero out)
    s.xmm[2] = xmm_from_u64(0x0001000100010001, 0xFFFF0000FFFF0000);

    // VPSIGNB xmm0, xmm1, xmm2: C4 E2 71 08 C2
    add_xmm("vpsignb xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x08, 0xC2}, s, 0x7);
    // VPSIGNW xmm0, xmm1, xmm2: C4 E2 71 09 C2
    add_xmm("vpsignw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x09, 0xC2}, s, 0x7);
    // VPSIGND xmm0, xmm1, xmm2: C4 E2 71 0A C2
    add_xmm("vpsignd xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x0A, 0xC2}, s, 0x7);
  }

  // VPABS — unary, vvvv=1111b → byte2=0x79
  // VEX.128.66.0F38 with vvvv=1111: C4 E2 79 <op> C1
  {
    ArchState s = {};
    s.rflags = 0x2;
    // Values with negative/positive/zero/min to exercise abs paths
    s.xmm[1] = xmm_from_u64(0x01FF037F05816082, 0x7FFFFFFF80000001);

    // VPABSB xmm0, xmm1: C4 E2 79 1C C1
    add_xmm("vpabsb xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x1C, 0xC1}, s, 0x3);
    // VPABSW xmm0, xmm1: C4 E2 79 1D C1
    add_xmm("vpabsw xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x1D, 0xC1}, s, 0x3);
    // VPABSD xmm0, xmm1: C4 E2 79 1E C1
    add_xmm("vpabsd xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x1E, 0xC1}, s, 0x3);
  }

  // =====================================================================
  // 75. VEX SSE4.1 — VEX-encoded SSE4.1 integer instructions (0F38 map)
  // =====================================================================
  cat = "VEX SSE4.1";

  // Sign-extend instructions (unary, vvvv=1111b → byte2=0x79)
  // Use data with bit 7 set to verify sign extension
  {
    ArchState s = {};
    s.rflags = 0x2;
    // Bytes with mix of positive (0x07, 0x03, 0x05, 0x04, 0x02, 0x7F)
    // and negative (0x80, 0xFF, 0xFB, 0xFA, 0xFC, 0xFE) to test sign extension
    s.xmm[1] = xmm_from_u64(0x0180FF7F02FE0300, 0x04FC0580FB06FA07);

    // VPMOVSXBW xmm0, xmm1: C4 E2 79 20 C1
    add_xmm("vpmovsxbw xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x20, 0xC1}, s, 0x3);
    // VPMOVSXBD xmm0, xmm1: C4 E2 79 21 C1
    add_xmm("vpmovsxbd xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x21, 0xC1}, s, 0x3);
    // VPMOVSXBQ xmm0, xmm1: C4 E2 79 22 C1
    add_xmm("vpmovsxbq xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x22, 0xC1}, s, 0x3);
    // VPMOVSXWD xmm0, xmm1: C4 E2 79 23 C1
    add_xmm("vpmovsxwd xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x23, 0xC1}, s, 0x3);
    // VPMOVSXWQ xmm0, xmm1: C4 E2 79 24 C1
    add_xmm("vpmovsxwq xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x24, 0xC1}, s, 0x3);
    // VPMOVSXDQ xmm0, xmm1: C4 E2 79 25 C1
    add_xmm("vpmovsxdq xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x25, 0xC1}, s, 0x3);
  }

  // Zero-extend instructions (unary, vvvv=1111b → byte2=0x79)
  {
    ArchState s = {};
    s.rflags = 0x2;
    // Same data as sign-extend to cross-check
    s.xmm[1] = xmm_from_u64(0x0180FF7F02FE0300, 0x04FC0580FB06FA07);

    // VPMOVZXBW xmm0, xmm1: C4 E2 79 30 C1
    add_xmm("vpmovzxbw xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x30, 0xC1}, s, 0x3);
    // VPMOVZXBD xmm0, xmm1: C4 E2 79 31 C1
    add_xmm("vpmovzxbd xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x31, 0xC1}, s, 0x3);
    // VPMOVZXBQ xmm0, xmm1: C4 E2 79 32 C1
    add_xmm("vpmovzxbq xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x32, 0xC1}, s, 0x3);
    // VPMOVZXWD xmm0, xmm1: C4 E2 79 33 C1
    add_xmm("vpmovzxwd xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x33, 0xC1}, s, 0x3);
    // VPMOVZXWQ xmm0, xmm1: C4 E2 79 34 C1
    add_xmm("vpmovzxwq xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x34, 0xC1}, s, 0x3);
    // VPMOVZXDQ xmm0, xmm1: C4 E2 79 35 C1
    add_xmm("vpmovzxdq xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x35, 0xC1}, s, 0x3);
  }

  // 3-operand SSE4.1: dst=xmm0, src1=xmm1, src2=xmm2
  // VEX.128.66.0F38 with vvvv=xmm1: C4 E2 71 <op> C2
  {
    ArchState s = {};
    s.rflags = 0x2;
    // Values where signed and unsigned orderings differ
    // Signed: 0x80=-128 < 0x7F=127; Unsigned: 0x80=128 > 0x7F=127
    s.xmm[1] = xmm_from_u64(0x01FF037F05816082, 0x7FFFFFFF80000001);
    s.xmm[2] = xmm_from_u64(0x02FE027E04806183, 0x80000000FFFFFFFF);

    // VPMULDQ xmm0, xmm1, xmm2: C4 E2 71 28 C2
    // Multiplies dwords at positions 0 and 2 (signed) → qword results
    add_xmm("vpmuldq xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x28, 0xC2}, s, 0x7);
    // VPCMPEQQ xmm0, xmm1, xmm2: C4 E2 71 29 C2
    add_xmm("vpcmpeqq xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x29, 0xC2}, s, 0x7);
    // VPACKUSDW xmm0, xmm1, xmm2: C4 E2 71 2B C2
    add_xmm("vpackusdw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x2B, 0xC2}, s, 0x7);

    // VPMINSB xmm0, xmm1, xmm2: C4 E2 71 38 C2
    add_xmm("vpminsb xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x38, 0xC2}, s, 0x7);
    // VPMINSD xmm0, xmm1, xmm2: C4 E2 71 39 C2
    add_xmm("vpminsd xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x39, 0xC2}, s, 0x7);
    // VPMINUW xmm0, xmm1, xmm2: C4 E2 71 3A C2
    add_xmm("vpminuw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x3A, 0xC2}, s, 0x7);
    // VPMINUD xmm0, xmm1, xmm2: C4 E2 71 3B C2
    add_xmm("vpminud xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x3B, 0xC2}, s, 0x7);

    // VPMAXSB xmm0, xmm1, xmm2: C4 E2 71 3C C2
    add_xmm("vpmaxsb xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x3C, 0xC2}, s, 0x7);
    // VPMAXSD xmm0, xmm1, xmm2: C4 E2 71 3D C2
    add_xmm("vpmaxsd xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x3D, 0xC2}, s, 0x7);
    // VPMAXUW xmm0, xmm1, xmm2: C4 E2 71 3E C2
    add_xmm("vpmaxuw xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x3E, 0xC2}, s, 0x7);
    // VPMAXUD xmm0, xmm1, xmm2: C4 E2 71 3F C2
    add_xmm("vpmaxud xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x3F, 0xC2}, s, 0x7);

    // VPMULLD xmm0, xmm1, xmm2: C4 E2 71 40 C2
    add_xmm("vpmulld xmm0,xmm1,xmm2", {0xC4, 0xE2, 0x71, 0x40, 0xC2}, s, 0x7);
  }

  // VPHMINPOSUW — unary, 128-bit only (vvvv=1111b → byte2=0x79)
  {
    ArchState s = {};
    s.rflags = 0x2;
    // 8 unsigned words: find the minimum and its index
    // Words: 0x0040, 0x0003, 0x0080, 0x0001, 0x00FF, 0x0002, 0x0050, 0x0010
    s.xmm[1] = xmm_from_u64(0x00100050000200FF, 0x0001008000030040);

    // VPHMINPOSUW xmm0, xmm1: C4 E2 79 41 C1
    add_xmm("vphminposuw xmm0,xmm1", {0xC4, 0xE2, 0x79, 0x41, 0xC1}, s, 0x3);
  }

  // VPMULDQ with interesting dword positions 0 and 2
  {
    ArchState s = {};
    s.rflags = 0x2;
    // dword[0]=0xFFFFFFFE (-2), dword[1]=junk, dword[2]=0x7FFFFFFF (INT_MAX), dword[3]=junk
    s.xmm[1] = xmm_from_u64(0xDEAD7FFFFFFFDEAD, 0xFFFFFFFE);
    // dword[0]=0x00000003 (3), dword[1]=junk, dword[2]=0xFFFFFFFF (-1), dword[3]=junk
    s.xmm[2] = xmm_from_u64(0xBEEFFFFFFFFFBEEF, 0x00000003);

    // VPMULDQ xmm0, xmm1, xmm2: C4 E2 71 28 C2
    add_xmm("vpmuldq xmm0,xmm1,xmm2 (edge)", {0xC4, 0xE2, 0x71, 0x28, 0xC2}, s, 0x7);
  }

  // VPCMPEQQ with equal and unequal qwords
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0xDEADBEEFCAFEBABE, 0x0123456789ABCDEF);
    s.xmm[2] = xmm_from_u64(0xDEADBEEFCAFEBABE, 0xFEDCBA9876543210);

    // VPCMPEQQ: qword[0] matches → 0xFFFF..., qword[1] differs → 0x0000...
    add_xmm("vpcmpeqq xmm0,xmm1,xmm2 (mixed)", {0xC4, 0xE2, 0x71, 0x29, 0xC2}, s, 0x7);
  }

  // ── VEX pack/unpack/compare (VEX 0F) ──
  cat = "VEX pack/unpack";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0001000200030004, 0x0005000600070008);
    s.xmm[2] = xmm_from_u64(0x000A000B000C000D, 0x000E000F00100011);

    // VPUNPCKLBW xmm0,xmm1,xmm2: C5 F1 60 C2
    add_xmm("vpunpcklbw", {0xC5, 0xF1, 0x60, 0xC2}, s, 0x7);
    // VPUNPCKLWD: C5 F1 61 C2
    add_xmm("vpunpcklwd", {0xC5, 0xF1, 0x61, 0xC2}, s, 0x7);
    // VPUNPCKLDQ: C5 F1 62 C2
    add_xmm("vpunpckldq", {0xC5, 0xF1, 0x62, 0xC2}, s, 0x7);
    // VPACKSSWB: C5 F1 63 C2
    add_xmm("vpacksswb", {0xC5, 0xF1, 0x63, 0xC2}, s, 0x7);
    // VPCMPGTB: C5 F1 64 C2
    add_xmm("vpcmpgtb", {0xC5, 0xF1, 0x64, 0xC2}, s, 0x7);
    // VPCMPGTW: C5 F1 65 C2
    add_xmm("vpcmpgtw", {0xC5, 0xF1, 0x65, 0xC2}, s, 0x7);
    // VPCMPGTD: C5 F1 66 C2
    add_xmm("vpcmpgtd", {0xC5, 0xF1, 0x66, 0xC2}, s, 0x7);
    // VPACKUSWB: C5 F1 67 C2
    add_xmm("vpackuswb", {0xC5, 0xF1, 0x67, 0xC2}, s, 0x7);
    // VPUNPCKHBW: C5 F1 68 C2
    add_xmm("vpunpckhbw", {0xC5, 0xF1, 0x68, 0xC2}, s, 0x7);
    // VPUNPCKHWD: C5 F1 69 C2
    add_xmm("vpunpckhwd", {0xC5, 0xF1, 0x69, 0xC2}, s, 0x7);
    // VPUNPCKHDQ: C5 F1 6A C2
    add_xmm("vpunpckhdq", {0xC5, 0xF1, 0x6A, 0xC2}, s, 0x7);
    // VPACKSSDW: C5 F1 6B C2
    add_xmm("vpackssdw", {0xC5, 0xF1, 0x6B, 0xC2}, s, 0x7);
    // VPUNPCKLQDQ: C5 F1 6C C2
    add_xmm("vpunpcklqdq", {0xC5, 0xF1, 0x6C, 0xC2}, s, 0x7);
    // VPUNPCKHQDQ: C5 F1 6D C2
    add_xmm("vpunpckhqdq", {0xC5, 0xF1, 0x6D, 0xC2}, s, 0x7);

    // VPCMPEQB: C5 F1 74 C2
    add_xmm("vpcmpeqb", {0xC5, 0xF1, 0x74, 0xC2}, s, 0x7);
    // VPCMPEQW: C5 F1 75 C2
    add_xmm("vpcmpeqw", {0xC5, 0xF1, 0x75, 0xC2}, s, 0x7);
  }

  // ── VEX multiply/SAD/avg (VEX 0F) ──
  cat = "VEX multiply";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x0064FFCE00050003, 0x7FFF80000002FFFE);
    s.xmm[2] = xmm_from_u64(0x000AFFEC00020004, 0x0001FFFF00037FFF);

    // VPMULLW: C5 F1 D5 C2
    add_xmm("vpmullw", {0xC5, 0xF1, 0xD5, 0xC2}, s, 0x7);
    // VPMULHUW: C5 F1 E4 C2
    add_xmm("vpmulhuw", {0xC5, 0xF1, 0xE4, 0xC2}, s, 0x7);
    // VPMULHW: C5 F1 E5 C2
    add_xmm("vpmulhw", {0xC5, 0xF1, 0xE5, 0xC2}, s, 0x7);
    // VPMULUDQ: C5 F1 F4 C2
    add_xmm("vpmuludq", {0xC5, 0xF1, 0xF4, 0xC2}, s, 0x7);
    // VPMADDWD: C5 F1 F5 C2
    add_xmm("vpmaddwd", {0xC5, 0xF1, 0xF5, 0xC2}, s, 0x7);
    // VPSADBW: C5 F1 F6 C2
    add_xmm("vpsadbw", {0xC5, 0xF1, 0xF6, 0xC2}, s, 0x7);
    // VPAVGB: C5 F1 E0 C2
    add_xmm("vpavgb", {0xC5, 0xF1, 0xE0, 0xC2}, s, 0x7);
    // VPAVGW: C5 F1 E3 C2
    add_xmm("vpavgw", {0xC5, 0xF1, 0xE3, 0xC2}, s, 0x7);
  }

  // ── VEX saturating arithmetic (VEX 0F) ──
  cat = "VEX saturating arith";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x7F80FF00FE01F0E0, 0x7FFF8000FFFE0001);
    s.xmm[2] = xmm_from_u64(0x0180FF007F01F0E0, 0x0001FFFF00020001);

    // VPADDSB: C5 F1 EC C2
    add_xmm("vpaddsb", {0xC5, 0xF1, 0xEC, 0xC2}, s, 0x7);
    // VPADDSW: C5 F1 ED C2
    add_xmm("vpaddsw", {0xC5, 0xF1, 0xED, 0xC2}, s, 0x7);
    // VPADDUSB: C5 F1 DC C2
    add_xmm("vpaddusb", {0xC5, 0xF1, 0xDC, 0xC2}, s, 0x7);
    // VPADDUSW: C5 F1 DD C2
    add_xmm("vpaddusw", {0xC5, 0xF1, 0xDD, 0xC2}, s, 0x7);
    // VPSUBSB: C5 F1 E8 C2
    add_xmm("vpsubsb", {0xC5, 0xF1, 0xE8, 0xC2}, s, 0x7);
    // VPSUBSW: C5 F1 E9 C2
    add_xmm("vpsubsw", {0xC5, 0xF1, 0xE9, 0xC2}, s, 0x7);
    // VPSUBUSB: C5 F1 D8 C2
    add_xmm("vpsubusb", {0xC5, 0xF1, 0xD8, 0xC2}, s, 0x7);
    // VPSUBUSW: C5 F1 D9 C2
    add_xmm("vpsubusw", {0xC5, 0xF1, 0xD9, 0xC2}, s, 0x7);
    // VPMINUB: C5 F1 DA C2
    add_xmm("vpminub", {0xC5, 0xF1, 0xDA, 0xC2}, s, 0x7);
    // VPMAXUB: C5 F1 DE C2
    add_xmm("vpmaxub", {0xC5, 0xF1, 0xDE, 0xC2}, s, 0x7);
    // VPMINSW: C5 F1 EA C2
    add_xmm("vpminsw", {0xC5, 0xF1, 0xEA, 0xC2}, s, 0x7);
  }

  // ── VEX shifts by XMM (VEX 0F) ──
  cat = "VEX shifts";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0xFF00FF00ABCD1234, 0x8000000012345678);
    s.xmm[2] = xmm_from_u64(0x0000000000000004, 0x0000000000000000); // shift count = 4

    // VPSRLW: C5 F1 D1 C2
    add_xmm("vpsrlw by xmm", {0xC5, 0xF1, 0xD1, 0xC2}, s, 0x7);
    // VPSRLD: C5 F1 D2 C2
    add_xmm("vpsrld by xmm", {0xC5, 0xF1, 0xD2, 0xC2}, s, 0x7);
    // VPSRLQ: C5 F1 D3 C2
    add_xmm("vpsrlq by xmm", {0xC5, 0xF1, 0xD3, 0xC2}, s, 0x7);
    // VPSRAW: C5 F1 E1 C2
    add_xmm("vpsraw by xmm", {0xC5, 0xF1, 0xE1, 0xC2}, s, 0x7);
    // VPSRAD: C5 F1 E2 C2
    add_xmm("vpsrad by xmm", {0xC5, 0xF1, 0xE2, 0xC2}, s, 0x7);
    // VPSLLW: C5 F1 F1 C2
    add_xmm("vpsllw by xmm", {0xC5, 0xF1, 0xF1, 0xC2}, s, 0x7);
    // VPSLLD: C5 F1 F2 C2
    add_xmm("vpslld by xmm", {0xC5, 0xF1, 0xF2, 0xC2}, s, 0x7);
    // VPSLLQ: C5 F1 F3 C2
    add_xmm("vpsllq by xmm", {0xC5, 0xF1, 0xF3, 0xC2}, s, 0x7);
  }

  // ── VEX immediate shifts (VEX 0F groups 71/72/73) ──
  cat = "VEX imm shifts";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0xFF00FF00ABCD1234, 0x8000000012345678);

    // VPSRLW xmm0, xmm1, 4: C5 F9 71 D1 04
    add_xmm("vpsrlw imm", {0xC5, 0xF9, 0x71, 0xD1, 0x04}, s, 0x3);
    // VPSRAW xmm0, xmm1, 4: C5 F9 71 E1 04 (reg=4)
    add_xmm("vpsraw imm", {0xC5, 0xF9, 0x71, 0xE1, 0x04}, s, 0x3);
    // VPSLLW xmm0, xmm1, 4: C5 F9 71 F1 04 (reg=6)
    add_xmm("vpsllw imm", {0xC5, 0xF9, 0x71, 0xF1, 0x04}, s, 0x3);
    // VPSRLD xmm0, xmm1, 4: C5 F9 72 D1 04
    add_xmm("vpsrld imm", {0xC5, 0xF9, 0x72, 0xD1, 0x04}, s, 0x3);
    // VPSRAD xmm0, xmm1, 4: C5 F9 72 E1 04
    add_xmm("vpsrad imm", {0xC5, 0xF9, 0x72, 0xE1, 0x04}, s, 0x3);
    // VPSLLD xmm0, xmm1, 4: C5 F9 72 F1 04
    add_xmm("vpslld imm", {0xC5, 0xF9, 0x72, 0xF1, 0x04}, s, 0x3);
    // VPSRLQ xmm0, xmm1, 4: C5 F9 73 D1 04
    add_xmm("vpsrlq imm", {0xC5, 0xF9, 0x73, 0xD1, 0x04}, s, 0x3);
    // VPSLLQ xmm0, xmm1, 4: C5 F9 73 F1 04
    add_xmm("vpsllq imm", {0xC5, 0xF9, 0x73, 0xF1, 0x04}, s, 0x3);
    // VPSRLDQ xmm0, xmm1, 4: C5 F9 73 D9 04 (reg=3)
    add_xmm("vpsrldq imm", {0xC5, 0xF9, 0x73, 0xD9, 0x04}, s, 0x3);
    // VPSLLDQ xmm0, xmm1, 4: C5 F9 73 F9 04 (reg=7)
    add_xmm("vpslldq imm", {0xC5, 0xF9, 0x73, 0xF9, 0x04}, s, 0x3);
  }

  // ── AVX2 variable shifts (VEX 0F38) ──
  cat = "AVX2 var shifts";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL, xmm_cmp, false});
    };

    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0xFF000000ABCD1234, 0x8000000012345678);
    s.xmm[2] = xmm_from_u64(0x0000000400000008, 0x0000001000000001); // shift counts per dword

    // VPSRLVD xmm0, xmm1, xmm2: C4 E2 71 45 C2 (VEX.128.66.0F38.W0)
    add_xmm("vpsrlvd", {0xC4, 0xE2, 0x71, 0x45, 0xC2}, s, 0x7);
    // VPSRAVD xmm0, xmm1, xmm2: C4 E2 71 46 C2
    add_xmm("vpsravd", {0xC4, 0xE2, 0x71, 0x46, 0xC2}, s, 0x7);
    // VPSLLVD xmm0, xmm1, xmm2: C4 E2 71 47 C2
    add_xmm("vpsllvd", {0xC4, 0xE2, 0x71, 0x47, 0xC2}, s, 0x7);

    // VPSRLVQ xmm0, xmm1, xmm2: C4 E2 F1 45 C2 (W=1 for qword)
    s.xmm[2] = xmm_from_u64(0x0000000000000004, 0x0000000000000010); // shift counts per qword
    add_xmm("vpsrlvq", {0xC4, 0xE2, 0xF1, 0x45, 0xC2}, s, 0x7);
    // VPSLLVQ xmm0, xmm1, xmm2: C4 E2 F1 47 C2
    add_xmm("vpsllvq", {0xC4, 0xE2, 0xF1, 0x47, 0xC2}, s, 0x7);
  }

  // ── VEX VTESTPS/VTESTPD (VEX 0F38) ──
  cat = "VEX test";
  {
    auto add_test = [&](const char *name, std::vector<u8> code, ArchState init, u64 mask) {
      tests.push_back({name, cat, std::move(code), init, mask});
    };

    ArchState s = {};
    s.rflags = 0x2;
    // Use values where AND and ANDNOT give different zero/non-zero results
    s.xmm[1] = xmm_from_u64(0x8000000080000000, 0x0000000000000000); // sign bits set in low half
    s.xmm[2] = xmm_from_u64(0x8000000080000000, 0x8000000080000000); // all sign bits set

    // VTESTPS xmm1, xmm2: C4 E2 79 0E CA
    add_test("vtestps", {0xC4, 0xE2, 0x79, 0x0E, 0xCA}, s, FL_ZF | FL_CF);

    s.xmm[1] = xmm_from_u64(0x0000000000000000, 0x0000000000000000);
    // src1=0, src2=anything → AND=0 → ZF=1; ANDNOT=src2 → CF=0 (if src2 nonzero)
    add_test("vtestps zf=1", {0xC4, 0xE2, 0x79, 0x0E, 0xCA}, s, FL_ZF | FL_CF);

    // VTESTPD: C4 E2 79 0F CA
    s.xmm[1] = xmm_from_u64(0x8000000000000000, 0x8000000000000000);
    s.xmm[2] = xmm_from_u64(0x8000000000000000, 0x8000000000000000);
    add_test("vtestpd all match", {0xC4, 0xE2, 0x79, 0x0F, 0xCA}, s, FL_ZF | FL_CF);
  }

  // =====================================================================
  // VEX 0F misc — VMOVMSKPS/PD, VPMOVMSKB, VCVT*, VRSQRTPS, VRCPPS, etc.
  // =====================================================================
  cat = "VEX 0F misc";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };
    auto add_gpr = [&](const char *name, std::vector<u8> code, ArchState init,
                        u64 flags_mask = FL_NONE) {
      tests.push_back({name, cat, std::move(code), init, flags_mask});
    };

    ArchState s = {};
    s.rflags = 0x2;

    // VMOVMSKPS: C5 F8 50 C1 = vmovmskps eax, xmm1 (NP, L=0)
    s.xmm[1] = xmm_from_u64(0x80000000FF000000, 0x00000000F0000000);
    add_gpr("vmovmskps eax,xmm1", {0xC5, 0xF8, 0x50, 0xC1}, s);

    // VMOVMSKPD: C5 F9 50 C1 = vmovmskpd eax, xmm1 (66, L=0)
    s.xmm[1] = xmm_from_u64(0x8000000000000000, 0x0000000000000001);
    add_gpr("vmovmskpd eax,xmm1", {0xC5, 0xF9, 0x50, 0xC1}, s);

    // VPMOVMSKB: C5 F9 D7 C1 = vpmovmskb eax, xmm1 (66, L=0)
    s.xmm[1] = xmm_from_u64(0xFF00FF00FF00FF00, 0x00FF00FF00FF00FF);
    add_gpr("vpmovmskb eax,xmm1", {0xC5, 0xF9, 0xD7, 0xC1}, s);

    // VCVTSS2SI: C5 FA 2D C1 = vcvtss2si eax, xmm1 (F3, L=0)
    // xmm1[31:0] = 0x41200000 = 10.0f
    s.xmm[1] = xmm_from_u64(0, 0x0000000041200000);
    add_gpr("vcvtss2si eax,xmm1", {0xC5, 0xFA, 0x2D, 0xC1}, s);

    // VCVTSD2SI: C5 FB 2D C1 = vcvtsd2si eax, xmm1 (F2, L=0)
    // xmm1[63:0] = 0x4024000000000000 = 10.0
    s.xmm[1] = xmm_from_u64(0, 0x4024000000000000);
    add_gpr("vcvtsd2si eax,xmm1", {0xC5, 0xFB, 0x2D, 0xC1}, s);

    // VCVTDQ2PD: C5 FA E6 C1 = vcvtdq2pd xmm0, xmm1 (F3, L=0)
    s.xmm[1] = xmm_from_u64(0, 0x0000000A00000005); // 10, 5
    add_xmm("vcvtdq2pd xmm0,xmm1", {0xC5, 0xFA, 0xE6, 0xC1}, s, 0x3);

    // VCVTPD2DQ: C5 FB E6 C1 = vcvtpd2dq xmm0, xmm1 (F2, L=0)
    // xmm1 = 3.0 (0x4008000000000000), 7.0 (0x401C000000000000)
    s.xmm[1] = xmm_from_u64(0x401C000000000000, 0x4008000000000000);
    add_xmm("vcvtpd2dq xmm0,xmm1", {0xC5, 0xFB, 0xE6, 0xC1}, s, 0x3);

    // VCVTTPD2DQ: C5 F9 E6 C1 = vcvttpd2dq xmm0, xmm1 (66, L=0)
    s.xmm[1] = xmm_from_u64(0x401C000000000000, 0x4008000000000000);
    add_xmm("vcvttpd2dq xmm0,xmm1", {0xC5, 0xF9, 0xE6, 0xC1}, s, 0x3);

    // VPMAXSW: C5 F1 EE C2 = vpmaxsw xmm0, xmm1, xmm2 (66, L=0)
    s.xmm[1] = xmm_from_u64(0x0001FFFF00038000, 0x7FFF00050003FFFE);
    s.xmm[2] = xmm_from_u64(0xFFFF0002800000FF, 0x0006FFFF7FFF0001);
    add_xmm("vpmaxsw xmm0,xmm1,xmm2", {0xC5, 0xF1, 0xEE, 0xC2}, s, 0x7);

    // Note: VRSQRTPS, VRCPPS, VRSQRTSS, VRCPSS are approximate instructions.
    // Real hardware returns approximations (within 1.5*2^-12 relative error)
    // while our Sail model returns exact results, so we skip exact-match KVM tests.

    // VMOVLPS store: C5 F8 13 07 = vmovlps [rdi], xmm0 (NP, L=0)
    s.xmm[0] = xmm_from_u64(0xAAAABBBBCCCCDDDD, 0x1234567890ABCDEF);
    s.rdi = DATA_ADDR;
    {
      TestCase tc;
      tc.name = "vmovlps [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xC5, 0xF8, 0x13, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.compare_data_len = 8;
      tc.init_data = std::vector<u8>(16, 0);
      tests.push_back(std::move(tc));
    }

    // VMOVHPS store: C5 F8 17 07 = vmovhps [rdi], xmm0 (NP, L=0)
    {
      TestCase tc;
      tc.name = "vmovhps [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xC5, 0xF8, 0x17, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.compare_data_len = 8;
      tc.init_data = std::vector<u8>(16, 0);
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // VEX gather — AVX2 VGATHER instructions
  // =====================================================================
  cat = "VEX gather";
  {
    // Set up a data array at DATA_ADDR with known 32-bit values
    // data[0..31] = 0x10, 0x20, 0x30, 0x40 at dword offsets
    std::vector<u8> gather_data(64, 0);
    for (int i = 0; i < 8; i++) {
      uint32_t val = (uint32_t)(i + 1) * 0x11111111u;
      memcpy(&gather_data[i * 4], &val, 4);
    }

    ArchState s = {};
    s.rflags = 0x2;
    s.rdi = DATA_ADDR; // base address

    // VPGATHERDD xmm0, [rdi + xmm2*1], xmm1
    // Indices: xmm2 = {0, 4, 8, 12} (dword offsets 0,1,2,3)
    // Mask: xmm1 = all sign bits set (all active)
    s.xmm[0] = xmm_from_u64(0, 0);
    s.xmm[1] = xmm_from_u64(0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF); // mask all set
    s.xmm[2] = xmm_from_u64(0x0000000C00000008, 0x0000000400000000); // indices

    // VEX.128.66.0F38.W0 90: C4 E2 71 90 04 17
    // But VSIB encoding: modrm=04 (mod=00, reg=0, rm=100=SIB), SIB=17 (scale=0, idx=2, base=7=rdi)
    // Actually: C4 E2 71 90 04 17
    {
      TestCase tc;
      tc.name = "vpgatherdd xmm0,[rdi+xmm2*1],xmm1";
      tc.category = cat;
      tc.code = {0xC4, 0xE2, 0x71, 0x90, 0x04, 0x17};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7; // xmm0, xmm1 (zeroed), xmm2
      tc.init_data = gather_data;
      tests.push_back(std::move(tc));
    }

    // VPGATHERDD with partial mask: only gather elements 0 and 2
    s.xmm[1] = xmm_from_u64(0x8000000000000000, 0x0000000080000000); // mask bits 0,2
    {
      TestCase tc;
      tc.name = "vpgatherdd partial mask";
      tc.category = cat;
      tc.code = {0xC4, 0xE2, 0x71, 0x90, 0x04, 0x17};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = gather_data;
      tests.push_back(std::move(tc));
    }

    // VGATHERDPS (same encoding as VPGATHERDD but FP interpretation)
    // C4 E2 71 92 04 17
    s.xmm[1] = xmm_from_u64(0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF);
    s.xmm[0] = xmm_from_u64(0, 0);
    {
      TestCase tc;
      tc.name = "vgatherdps xmm0,[rdi+xmm2*1],xmm1";
      tc.category = cat;
      tc.code = {0xC4, 0xE2, 0x71, 0x92, 0x04, 0x17};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tc.init_data = gather_data;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // K-register ops — KANDNW, KORW, KXNORW, KUNPCKBW, KORTESTW, KTESTW
  // =====================================================================
  cat = "K-register ops";
  {
    auto add_flags = [&](const char *name, std::vector<u8> code, ArchState init) {
      tests.push_back({name, cat, std::move(code), init, FL_ALL});
    };

    ArchState s = {};
    s.rflags = 0x2;

    // Set up k1=0xAAAA, k2=0x5555 via KMOVW from GPR
    // We pre-load k-registers using KMOV r32->k then do the operation and read back with KMOV k->r32
    // Since KVM runs all code together, we encode a sequence.

    // Test KORW k3, k1, k2 then KMOVW eax, k3
    // Load k1=0xAAAA: mov eax, 0xAAAA / kmovw k1, eax
    // Load k2=0x5555: mov eax, 0x5555 / kmovw k2, eax
    // KORW k3, k1, k2: C5 EC 45 DB (VEX.256.NP.0F 45: k3=modrm.reg(011), k1=vvvv(001), k2=rm(011))
    // Actually: VEX.NDS.LZ.0F. Let me encode properly.
    // KORW uses VEX.L1.NP.0F.W0 45 /r
    // k3, k1, k2: modrm = 0xCB (mod=11, reg=001(k1), rm=011(k3)) wait...
    // Encoding: KORW k1, k2, k3: reg=dst, vvvv=src1, rm=src2
    // VEX byte1: R̄=1, vvvv=~k1, L=1, pp=00 → 1.1100.1.00 = 0xE4
    // C5 E4 45 D9 = KORW k3, k3, k1? No, need to be more careful.

    // Let me use a simpler approach: just test KORTESTW since it sets flags
    // Load k1=0x5555 via mov eax, 0x5555 / C5 F8 92 C8 (kmovw k1, eax)
    // Load k2=0xAAAA via mov eax, 0xAAAA / C5 F8 92 D0 (kmovw k2, eax)
    // KORTESTW k1, k2: C5 F8 98 CA (VEX.LZ.NP.0F.W0 98, modrm=CA: reg=k1(001), rm=k2(010))
    s.rax = 0x5555;
    s.rdx = 0xAAAA;
    // mov eax, 0x5555 already set. Use: C5 F8 92 C8 = kmovw k1, eax
    // C5 F8 92 D2 = kmovw k2, edx
    // C5 F8 98 CA = kortestw k1, k2
    add_flags("kortestw k1(5555),k2(AAAA) -> k1|k2=FFFF",
      {0xC5, 0xF8, 0x92, 0xC8,  // kmovw k1, eax (0x5555)
       0xC5, 0xF8, 0x92, 0xD2,  // kmovw k2, edx (0xAAAA)
       0xC5, 0xF8, 0x98, 0xCA}, // kortestw k1, k2
      s);

    // KORTESTW with zero result
    s.rax = 0;
    s.rdx = 0;
    add_flags("kortestw k1(0),k2(0) -> ZF=1",
      {0xC5, 0xF8, 0x92, 0xC8,
       0xC5, 0xF8, 0x92, 0xD2,
       0xC5, 0xF8, 0x98, 0xCA},
      s);

    // KTESTW: k1&k2 and ~k1&k2
    s.rax = 0xFFFF;
    s.rdx = 0x00FF;
    add_flags("ktestw k1(FFFF),k2(00FF)",
      {0xC5, 0xF8, 0x92, 0xC8,
       0xC5, 0xF8, 0x92, 0xD2,
       0xC5, 0xF8, 0x99, 0xCA},
      s);

    s.rax = 0x0000;
    s.rdx = 0xFFFF;
    add_flags("ktestw k1(0),k2(FFFF) -> ZF=1",
      {0xC5, 0xF8, 0x92, 0xC8,
       0xC5, 0xF8, 0x92, 0xD2,
       0xC5, 0xF8, 0x99, 0xCA},
      s);

    // --- K-register logical operations ---
    // All use k1, k2 as inputs (loaded via XSAVE), k3 as output (read via KMOVW eax, k3).
    // KMOVW eax, k3 = C5 F8 93 C3

    // KANDW k3, k1, k2: VEX.L1.0F.W0 41 /r
    // k3=reg(011), vvvv=~k1=1110, k2=rm(010) → C5 EC 41 DA
    {
      TestCase tc;
      tc.name = "kandw k3,k1,k2: AAAA & 5555 = 0";
      tc.category = cat;
      tc.code = {0xC5, 0xF4, 0x41, 0xDA,   // kandw k3, k1, k2
                 0xC5, 0xF8, 0x93, 0xC3};   // kmovw eax, k3
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xAAAA;
      tc.initial.kregs[2] = 0x5555;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KANDW — overlapping bits
    {
      TestCase tc;
      tc.name = "kandw k3,k1,k2: FF00 & 0FF0 = 0F00";
      tc.category = cat;
      tc.code = {0xC5, 0xF4, 0x41, 0xDA,
                 0xC5, 0xF8, 0x93, 0xC3};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xFF00;
      tc.initial.kregs[2] = 0x0FF0;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KORW k3, k1, k2: VEX.L1.0F.W0 45 /r → C5 EC 45 DA
    {
      TestCase tc;
      tc.name = "korw k3,k1,k2: AAAA | 5555 = FFFF";
      tc.category = cat;
      tc.code = {0xC5, 0xF4, 0x45, 0xDA,
                 0xC5, 0xF8, 0x93, 0xC3};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xAAAA;
      tc.initial.kregs[2] = 0x5555;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KXORW k3, k1, k2: VEX.L1.0F.W0 47 /r → C5 EC 47 DA
    {
      TestCase tc;
      tc.name = "kxorw k3,k1,k2: FFFF ^ 00FF = FF00";
      tc.category = cat;
      tc.code = {0xC5, 0xF4, 0x47, 0xDA,
                 0xC5, 0xF8, 0x93, 0xC3};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xFFFF;
      tc.initial.kregs[2] = 0x00FF;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KANDNW k3, k1, k2: VEX.L1.0F.W0 42 /r → C5 EC 42 DA
    // result = ~k1 & k2
    {
      TestCase tc;
      tc.name = "kandnw k3,k1,k2: ~FF00 & 0FF0 = 00F0";
      tc.category = cat;
      tc.code = {0xC5, 0xF4, 0x42, 0xDA,
                 0xC5, 0xF8, 0x93, 0xC3};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xFF00;
      tc.initial.kregs[2] = 0x0FF0;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KXNORW k3, k1, k2: VEX.L1.0F.W0 46 /r → C5 EC 46 DA
    // result = ~(k1 ^ k2)
    {
      TestCase tc;
      tc.name = "kxnorw k3,k1,k2: ~(FF00^00FF) = 00FF (lower 16)";
      tc.category = cat;
      tc.code = {0xC5, 0xF4, 0x46, 0xDA,
                 0xC5, 0xF8, 0x93, 0xC3};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xFF00;
      tc.initial.kregs[2] = 0x00FF;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KNOTW k3, k1: VEX.L0.0F.W0 44 /r → C5 F8 44 D9
    // dst=k3(011), src=k1(001), vvvv=1111
    {
      TestCase tc;
      tc.name = "knotw k3,k1: ~AAAA = 5555";
      tc.category = cat;
      tc.code = {0xC5, 0xF8, 0x44, 0xD9,
                 0xC5, 0xF8, 0x93, 0xC3};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xAAAA;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KUNPCKBW k3, k1, k2: VEX.L1.0F.W0 4B /r → C5 F4 4B DA
    // result = k1[7:0] : k2[7:0] (concatenate low bytes)
    // Use KMOVW preamble to load k1, k2 (XSAVE may not load reliably for this).
    {
      TestCase tc;
      tc.name = "kunpckbw k3,k1,k2: AB:CD = ABCD";
      tc.category = cat;
      tc.code = {0xC5, 0xF8, 0x92, 0xC8,   // kmovw k1, eax (0xAB)
                 0xC5, 0xF8, 0x92, 0xD2,   // kmovw k2, edx (0xCD)
                 0xC5, 0xF5, 0x4B, 0xDA,   // kunpckbw k3, k1, k2 (VEX.L1.66.0F.W0)
                 0xC5, 0xF8, 0x93, 0xC3};  // kmovw eax, k3
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = 0xAB;
      tc.initial.rdx = 0xCD;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KMOVW k1, m16: VEX.L0.0F.W0 90 /r (memory load)
    // Load k1 from [DATA_ADDR] containing 0x1234
    {
      TestCase tc;
      tc.name = "kmovw k1,m16: load 1234h";
      tc.category = cat;
      // mov rdi, DATA_ADDR; kmovw k1, [rdi]; kmovw eax, k1
      tc.code = {0x48, 0xBF, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,  // mov rdi, 0x10000 (DATA_ADDR)
                 0xC5, 0xF8, 0x90, 0x0F,   // kmovw k1, [rdi]
                 0xC5, 0xF8, 0x93, 0xC1};  // kmovw eax, k1
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.init_data = {0x34, 0x12};  // 0x1234 in little-endian
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // KMOVW m16, k1: VEX.L0.0F.W0 91 /r (memory store)
    {
      TestCase tc;
      tc.name = "kmovw m16,k1: store BEEF to mem";
      tc.category = cat;
      // mov rdi, DATA_ADDR; kmovw [rdi], k1
      tc.code = {0x48, 0xBF, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,  // mov rdi, DATA_ADDR
                 0xC5, 0xF8, 0x91, 0x0F};  // kmovw [rdi], k1
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.kregs[1] = 0xBEEF;
      tc.flags_mask = FL_NONE;
      tc.compare_data_len = 2;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // EVEX blend — VPBLENDMD/Q, VBLENDMPS/PD
  // =====================================================================
  cat = "EVEX blend";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[1] = xmm_from_u64(0x1111111122222222, 0x3333333344444444);
    s.xmm[2] = xmm_from_u64(0xAAAAAAAABBBBBBBB, 0xCCCCCCCCDDDDDDDD);

    // VPBLENDMD xmm0, xmm1, xmm2 (no mask = blend all from src2)
    // EVEX.128.66.0F38.W0 64 /r, aaa=000 (no mask)
    // EVEX: 62 [P0][P1][P2] 64 modrm
    // P0: R̄=1, X̄=1, B̄=1, R'̄=1, 00, mm=10 → 0xF2
    // P1: W=0, vvvv=~1=1110, 1, pp=01 → 0.1110.1.01 = 0x75
    // Wait, vvvv is inverted. xmm1 = 0001, inverted = 1110
    // P1: W=0, ~vvvv=1110, 1, pp=01 → 0111.0101 = 0x75
    // P2: z=0, L'L=00, b=0, V'̄=1, aaa=000 → 0.00.0.1.000 = 0x08
    // modrm: mod=11, reg=000(xmm0), rm=010(xmm2) → 0xC2
    add_xmm("vpblendmd xmm0,xmm1,xmm2 (no mask)",
      {0x62, 0xF2, 0x75, 0x08, 0x64, 0xC2}, s, 0x7);

    // VBLENDMPS xmm0, xmm1, xmm2 (no mask) — same as above but opcode 65
    add_xmm("vblendmps xmm0,xmm1,xmm2 (no mask)",
      {0x62, 0xF2, 0x75, 0x08, 0x65, 0xC2}, s, 0x7);
  }

  // =====================================================================
  // VLDDQU — VEX 0F F0 unaligned load
  // =====================================================================
  cat = "VLDDQU";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;

    // VLDDQU xmm0, [rdi]: C5 FB F0 07 (VEX.128.F2.0F F0, modrm=[rdi])
    std::vector<u8> lddqu_data(32, 0);
    for (int i = 0; i < 16; i++) lddqu_data[i] = 0x10 + i;
    {
      TestCase tc;
      tc.name = "vlddqu xmm0,[rdi]";
      tc.category = cat;
      tc.code = {0xC5, 0xFB, 0xF0, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x1;
      tc.init_data = lddqu_data;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // VHADDPS/VHSUBPS/VADDSUBPS — VEX horizontal FP
  // =====================================================================
  cat = "VEX horiz FP";
  {
    auto add_test = [&](const char *name, std::vector<u8> code, ArchState init, u64 mask) {
      tests.push_back({name, cat, std::move(code), init, mask, 0xFFFF});
    };

    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);

    // VHADDPS xmm2, xmm0, xmm1: C5 FB 7C D1
    add_test("vhaddps xmm", {0xC5, 0xFB, 0x7C, 0xD1}, s, FL_NONE);

    // VHSUBPS xmm3, xmm0, xmm1: C5 FB 7D D9
    add_test("vhsubps xmm", {0xC5, 0xFB, 0x7D, 0xD9}, s, FL_NONE);

    // VADDSUBPS xmm4, xmm0, xmm1: C5 FB D0 E1
    add_test("vaddsubps xmm", {0xC5, 0xFB, 0xD0, 0xE1}, s, FL_NONE);

    // VHADDPD xmm5, xmm0, xmm1 (66.0F 7C)
    s.xmm[0] = xmm_from_f64(1.0, 3.0);
    s.xmm[1] = xmm_from_f64(5.0, 7.0);
    add_test("vhaddpd xmm", {0xC5, 0xF9, 0x7C, 0xE9}, s, FL_NONE);
  }

  // =====================================================================
  // VPTEST — VEX 0F38 17
  // =====================================================================
  cat = "VPTEST";
  {
    auto add_test = [&](const char *name, std::vector<u8> code, ArchState init, u64 mask) {
      tests.push_back({name, cat, std::move(code), init, mask});
    };

    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0xFFFFFFFFFFFFFFFFULL, 0xFFFFFFFFFFFFFFFFULL);
    s.xmm[1] = xmm_from_u64(0xFFFFFFFFFFFFFFFFULL, 0xFFFFFFFFFFFFFFFFULL);
    // VPTEST xmm0, xmm1: C4 E2 79 17 C1
    add_test("vptest all-ones", {0xC4, 0xE2, 0x79, 0x17, 0xC1}, s, FL_ZF | FL_CF);

    s.xmm[0] = xmm_from_u64(0, 0);
    add_test("vptest zero,ones", {0xC4, 0xE2, 0x79, 0x17, 0xC1}, s, FL_ZF | FL_CF);

    s.xmm[0] = xmm_from_u64(0xFFFFFFFFFFFFFFFFULL, 0xFFFFFFFFFFFFFFFFULL);
    s.xmm[1] = xmm_from_u64(0, 0);
    add_test("vptest ones,zero", {0xC4, 0xE2, 0x79, 0x17, 0xC1}, s, FL_ZF | FL_CF);
  }

  // =====================================================================
  // VPCMPGTQ — VEX 0F38 37
  // =====================================================================
  cat = "VPCMPGTQ";
  {
    auto add_test = [&](const char *name, std::vector<u8> code, ArchState init, u64 mask) {
      tests.push_back({name, cat, std::move(code), init, mask, 0xFFFF});
    };

    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(10, 5);
    s.xmm[1] = xmm_from_u64(3, 8);
    // VPCMPGTQ xmm2, xmm0, xmm1: C4 E2 79 37 D1
    add_test("vpcmpgtq", {0xC4, 0xE2, 0x79, 0x37, 0xD1}, s, FL_NONE);
  }

  // =====================================================================
  // VPERMILPS/PD — VEX permute
  // =====================================================================
  cat = "VPERMIL";
  {
    auto add_test = [&](const char *name, std::vector<u8> code, ArchState init, u64 mask) {
      tests.push_back({name, cat, std::move(code), init, mask, 0xFFFF});
    };

    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);

    // VPERMILPS xmm1, xmm0, imm8=0x1B (reverse)
    // VEX.128.66.0F3A 04 /r ib: C4 E3 79 04 C8 1B
    add_test("vpermilps imm reverse", {0xC4, 0xE3, 0x79, 0x04, 0xC8, 0x1B}, s, FL_NONE);

    // VPERMILPS xmm1, xmm0, imm8=0x00 (broadcast element 0)
    add_test("vpermilps imm bcast", {0xC4, 0xE3, 0x79, 0x04, 0xC8, 0x00}, s, FL_NONE);

    // VPERMILPD xmm1, xmm0, imm8=0x01 (swap qwords)
    s.xmm[0] = xmm_from_f64(1.0, 2.0);
    add_test("vpermilpd imm swap", {0xC4, 0xE3, 0x79, 0x05, 0xC8, 0x01}, s, FL_NONE);
  }

  // =====================================================================
  // VMOVNTDQ — VEX non-temporal store
  // =====================================================================
  cat = "VMOVNTDQ";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    s.xmm[0] = xmm_from_u64(0x8877665544332211ULL, 0x01FFEEDDCCBBAA99ULL);

    // VMOVNTDQ [rdi], xmm0: C5 F9 E7 07
    {
      TestCase tc;
      tc.name = "vmovntdq [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xC5, 0xF9, 0xE7, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // Vector memory stores — verify memory output
  // =====================================================================
  cat = "Vec stores";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    s.xmm[0] = xmm_from_u64(0x1122334455667788ULL, 0x99AABBCCDDEEFF00ULL);
    s.xmm[1] = xmm_from_u64(0xAAAABBBBCCCCDDDDULL, 0xEEEEFFFF00001111ULL);

    // MOVAPS [rdi], xmm0: 0F 29 07
    {
      TestCase tc;
      tc.name = "movaps [rdi],xmm0";
      tc.category = cat;
      tc.code = {0x0F, 0x29, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // MOVUPS [rdi], xmm0: 0F 11 07
    {
      TestCase tc;
      tc.name = "movups [rdi],xmm0";
      tc.category = cat;
      tc.code = {0x0F, 0x11, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // MOVDQU [rdi], xmm0: F3 0F 7F 07
    {
      TestCase tc;
      tc.name = "movdqu [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xF3, 0x0F, 0x7F, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // MOVDQA [rdi], xmm0: 66 0F 7F 07
    {
      TestCase tc;
      tc.name = "movdqa [rdi],xmm0";
      tc.category = cat;
      tc.code = {0x66, 0x0F, 0x7F, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // MOVLPS [rdi], xmm0: 0F 13 07 (store low 64 bits)
    {
      TestCase tc;
      tc.name = "movlps [rdi],xmm0";
      tc.category = cat;
      tc.code = {0x0F, 0x13, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }

    // MOVHPS [rdi], xmm0: 0F 17 07 (store high 64 bits)
    {
      TestCase tc;
      tc.name = "movhps [rdi],xmm0";
      tc.category = cat;
      tc.code = {0x0F, 0x17, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }

    // MOVSS [rdi], xmm0: F3 0F 11 07 (store 32 bits)
    {
      TestCase tc;
      tc.name = "movss [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xF3, 0x0F, 0x11, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // MOVSD [rdi], xmm0: F2 0F 11 07 (store 64 bits)
    {
      TestCase tc;
      tc.name = "movsd [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xF2, 0x0F, 0x11, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }

    // VMOVAPS [rdi], xmm0: C5 F8 29 07
    {
      TestCase tc;
      tc.name = "vmovaps [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xC5, 0xF8, 0x29, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // VMOVDQU [rdi], xmm0: C5 FA 7F 07
    {
      TestCase tc;
      tc.name = "vmovdqu [rdi],xmm0";
      tc.category = cat;
      tc.code = {0xC5, 0xFA, 0x7F, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 16;
      tests.push_back(std::move(tc));
    }

    // VMOVAPS [rdi], ymm0: need to set up ymm0 first
    // Use VINSERTF128 ymm0, ymm0, xmm1, 1 (C4 E3 7D 18 C1 01) to set hi half
    {
      TestCase tc;
      tc.name = "vmovaps [rdi],ymm0 (32 bytes)";
      tc.category = cat;
      tc.code = {0xC4, 0xE3, 0x7D, 0x18, 0xC1, 0x01,  // vinsertf128 ymm0,ymm0,xmm1,1
                 0xC5, 0xFC, 0x29, 0x07};               // vmovaps [rdi], ymm0
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 32;
      tests.push_back(std::move(tc));
    }

    // VMOVDQU [rdi], ymm0: C5 FE 7F 07
    {
      TestCase tc;
      tc.name = "vmovdqu [rdi],ymm0 (32 bytes)";
      tc.category = cat;
      tc.code = {0xC4, 0xE3, 0x7D, 0x18, 0xC1, 0x01,  // vinsertf128 ymm0,ymm0,xmm1,1
                 0xC5, 0xFE, 0x7F, 0x07};               // vmovdqu [rdi], ymm0
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0;
      tc.compare_data_len = 32;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // Indirect JMP/CALL — register and memory operands
  // =====================================================================
  cat = "Indirect JMP";
  {
    // JMP rax: FF E0 — jump to rax (CODE_ADDR + 2 = right after the JMP)
    {
      TestCase tc;
      tc.name = "jmp rax";
      tc.category = cat;
      tc.code = {0xFF, 0xE0};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = CODE_ADDR + 2;  // target = after JMP
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // JMP rax skipping bytes: FF E0 CC CC (jump over INT3s)
    {
      TestCase tc;
      tc.name = "jmp rax (skip INT3)";
      tc.category = cat;
      tc.code = {0xFF, 0xE0, 0xCC, 0xCC};  // JMP rax, INT3, INT3
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = CODE_ADDR + 4;  // skip the INT3 bytes
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // JMP [rdi]: FF 27 — indirect through memory
    {
      TestCase tc;
      tc.name = "jmp [rdi]";
      tc.category = cat;
      tc.code = {0xFF, 0x27, 0xCC, 0xCC};  // JMP [rdi], INT3, INT3
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      // [DATA_ADDR] = CODE_ADDR + 4 (skip JMP and INT3s)
      u64 target = CODE_ADDR + 4;
      tc.init_data.resize(8);
      memcpy(tc.init_data.data(), &target, 8);
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // CALL rax: FF D0 — push return addr, jump to rax
    // target = CODE_ADDR + 2 (right after CALL), so RET addr = CODE_ADDR+2
    // RSP should decrease by 8
    {
      TestCase tc;
      tc.name = "call rax";
      tc.category = cat;
      tc.code = {0xFF, 0xD0};  // CALL rax
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = CODE_ADDR + 2;  // target = right after CALL (then HLT)
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // CALL [rdi]: FF 17 — indirect call through memory
    {
      TestCase tc;
      tc.name = "call [rdi]";
      tc.category = cat;
      tc.code = {0xFF, 0x17, 0xCC, 0xCC};  // CALL [rdi], INT3, INT3
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      u64 target2 = CODE_ADDR + 4;
      tc.init_data.resize(8);
      memcpy(tc.init_data.data(), &target2, 8);
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // CALL rax + RET: call to a RET instruction, verify round-trip.
    // Layout: CALL rax; NOP; NOP; NOP; HLT; RET
    // CALL pushes CODE_ADDR+2, jumps to CODE_ADDR+6 (RET).
    // RET pops CODE_ADDR+2, jumps there. NOPs then HLT.
    {
      TestCase tc;
      tc.name = "call rax + ret";
      tc.category = cat;
      tc.code = {0xFF, 0xD0,           // 0: CALL rax (2 bytes)
                 0x90, 0x90, 0x90,     // 2: NOP NOP NOP (landing pad)
                 0xF4,                 // 5: HLT (stop after return)
                 0xC3};                // 6: RET (target of CALL)
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = CODE_ADDR + 6;  // point to the RET
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // FP conversion edge cases
  // =====================================================================
  cat = "FP conv edge";
  {
    auto add_xmm = [&](const char *name, std::vector<u8> code, ArchState init,
                        u32 xmm_cmp = 0x1) {
      tests.push_back({name, cat, std::move(code), init, FL_NONE, xmm_cmp, false});
    };

    ArchState s = {};
    s.rflags = 0x2;
    s.mxcsr = 0x1F80;  // default MXCSR

    // CVTPS2PD xmm0, xmm1: 0F 5A C1 (convert 2 floats → 2 doubles)
    // Denormal float: 0x00000001 = smallest subnormal
    s.xmm[1] = xmm_from_u32(0x00000001, 0x80000001, 0, 0);  // +denorm, -denorm
    add_xmm("cvtps2pd denormals", {0x0F, 0x5A, 0xC1}, s);

    // CVTPS2PD with NaN: 0x7FC00000 = quiet NaN, 0x7F800001 = signaling NaN
    s.xmm[1] = xmm_from_u32(0x7FC00000, 0x7F800001, 0, 0);
    add_xmm("cvtps2pd NaN", {0x0F, 0x5A, 0xC1}, s);

    // CVTPS2PD with Inf: 0x7F800000 = +Inf, 0xFF800000 = -Inf
    s.xmm[1] = xmm_from_u32(0x7F800000, 0xFF800000, 0, 0);
    add_xmm("cvtps2pd Inf", {0x0F, 0x5A, 0xC1}, s);

    // CVTPS2PD with -0: 0x80000000
    s.xmm[1] = xmm_from_u32(0x80000000, 0x00000000, 0, 0);  // -0, +0
    add_xmm("cvtps2pd neg zero", {0x0F, 0x5A, 0xC1}, s);

    // CVTPD2PS xmm0, xmm1: 66 0F 5A C1 (convert 2 doubles → 2 floats)
    // Large double that loses precision: 1.0 + 2^-24 (just beyond float precision)
    {
      double d1 = 1.0 + ldexp(1.0, -24);  // 1.0000000596... rounds to 1.0f
      double d2 = 1.0e38;                   // large but representable as float
      u64 b1, b2;
      memcpy(&b1, &d1, 8);
      memcpy(&b2, &d2, 8);
      s.xmm[1] = xmm_from_u64(b1, b2);
    }
    add_xmm("cvtpd2ps precision loss", {0x66, 0x0F, 0x5A, 0xC1}, s);

    // CVTSD2SS xmm0, xmm1: F2 0F 5A C1 (convert scalar double → scalar float)
    // Double that's too large for float: ~3.5e38 → +Inf
    {
      double big = 3.5e38;
      u64 bbig;
      memcpy(&bbig, &big, 8);
      s.xmm[0] = xmm_from_u32(0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF);
      s.xmm[1] = xmm_from_u64(bbig, 0);
    }
    add_xmm("cvtsd2ss overflow to inf", {0xF2, 0x0F, 0x5A, 0xC1}, s);

    // CVTSI2SS xmm0, eax: F3 0F 2A C0 (convert int32 → float)
    // Large integer that can't be exactly represented: 2^24 + 1 = 16777217
    s.xmm[0] = {};
    s.rax = 16777217;  // 2^24+1: rounds to 16777216.0f or 16777218.0f
    add_xmm("cvtsi2ss large int", {0xF3, 0x0F, 0x2A, 0xC0}, s);

    // CVTSI2SS xmm0, rax: F3 48 0F 2A C0 (convert int64 → float)
    s.rax = (1ULL << 53) + 1;  // just beyond double precision
    add_xmm("cvtsi2ss int64 rounding", {0xF3, 0x48, 0x0F, 0x2A, 0xC0}, s);

    // CVTSD2SS round-trip: double → float → double
    // Start with a double that's exactly representable as float
    {
      float f = 1.5f;
      double d = (double)f;
      u64 bd;
      memcpy(&bd, &d, 8);
      s.xmm[1] = xmm_from_u64(bd, 0);
      s.xmm[0] = {};
    }
    // CVTSD2SS xmm0, xmm1; CVTSS2SD xmm0, xmm0
    add_xmm("cvtsd2ss+cvtss2sd round-trip",
             {0xF2, 0x0F, 0x5A, 0xC1,   // cvtsd2ss xmm0, xmm1
              0xF3, 0x0F, 0x5A, 0xC0},  // cvtss2sd xmm0, xmm0
             s);
  }

  // =====================================================================
  // PUSH/POP memory operands
  // =====================================================================
  cat = "PUSH/POP mem";
  {
    // PUSH qword [rdi]: FF 37 — push value at [rdi] onto stack
    // Stack is verified by comparing RSP and the value pushed (read via POP rax)
    {
      TestCase tc;
      tc.name = "push qword [rdi]";
      tc.category = cat;
      // push qword [rdi]; pop rax (verify stack content)
      tc.code = {0xFF, 0x37,  // push qword [rdi]
                 0x58};        // pop rax
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      u64 val = 0xDEADBEEFCAFEBABEULL;
      tc.init_data.resize(8);
      memcpy(tc.init_data.data(), &val, 8);
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // POP qword [rdi]: 8F 07 — pop from stack into memory
    {
      TestCase tc;
      tc.name = "pop qword [rdi]";
      tc.category = cat;
      // push rax; pop qword [rdi]
      tc.code = {0x50,         // push rax
                 0x8F, 0x07};  // pop qword [rdi]
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0x123456789ABCDEF0ULL;
      tc.flags_mask = FL_NONE;
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }

    // PUSH imm16: 66 68 imm16 — push 16-bit immediate
    // Verify stack content via pop
    {
      TestCase tc;
      tc.name = "push imm16 0x1234";
      tc.category = cat;
      // push 0x1234; pop rax
      tc.code = {0x66, 0x68, 0x34, 0x12,  // push 0x1234
                 0x66, 0x58};               // pop ax (16-bit)
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rax = 0;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // PUSH imm8: 6A imm8 — push sign-extended 8-bit immediate
    {
      TestCase tc;
      tc.name = "push imm8 0xFF (-1)";
      tc.category = cat;
      // push -1; pop rax
      tc.code = {0x6A, 0xFF,  // push -1 (sign-extended to 64-bit)
                 0x58};        // pop rax
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }

    // PUSH imm32: 68 imm32 — push sign-extended 32-bit immediate
    {
      TestCase tc;
      tc.name = "push imm32 0x80000000";
      tc.category = cat;
      // push 0x80000000; pop rax (sign-extends to 0xFFFFFFFF80000000)
      tc.code = {0x68, 0x00, 0x00, 0x00, 0x80,  // push 0x80000000
                 0x58};                            // pop rax
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.flags_mask = FL_NONE;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // LOCK prefix memory operations — read-modify-write on memory
  // =====================================================================
  cat = "LOCK mem";
  {
    // LOCK ADD [rdi], eax: F0 01 07  (32-bit)
    {
      TestCase tc;
      tc.name = "lock add [rdi],eax 32";
      tc.category = cat;
      tc.code = {0xF0, 0x01, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0x100;
      tc.init_data = {0x34, 0x12, 0x00, 0x00};  // [rdi] = 0x1234
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK ADD [rdi], rax: F0 48 01 07  (64-bit)
    {
      TestCase tc;
      tc.name = "lock add [rdi],rax 64";
      tc.category = cat;
      tc.code = {0xF0, 0x48, 0x01, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0x1000000000ULL;
      tc.init_data = {0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00};
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 8;
      tests.push_back(std::move(tc));
    }

    // LOCK SUB [rdi], ecx: F0 29 0F  (32-bit)
    {
      TestCase tc;
      tc.name = "lock sub [rdi],ecx 32";
      tc.category = cat;
      tc.code = {0xF0, 0x29, 0x0F};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rcx = 1;
      tc.init_data = {0x00, 0x00, 0x00, 0x00};  // 0 - 1 = underflow
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK OR [rdi], eax: F0 09 07  (32-bit)
    {
      TestCase tc;
      tc.name = "lock or [rdi],eax 32";
      tc.category = cat;
      tc.code = {0xF0, 0x09, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0xFF00FF00;
      tc.init_data = {0x0F, 0x0F, 0x0F, 0x0F};
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK AND [rdi], eax: F0 21 07  (32-bit)
    {
      TestCase tc;
      tc.name = "lock and [rdi],eax 32";
      tc.category = cat;
      tc.code = {0xF0, 0x21, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0xFF00FF00;
      tc.init_data = {0xAB, 0xCD, 0xEF, 0x12};
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK XOR [rdi], eax: F0 31 07  (32-bit)
    {
      TestCase tc;
      tc.name = "lock xor [rdi],eax 32";
      tc.category = cat;
      tc.code = {0xF0, 0x31, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0xFFFFFFFF;
      tc.init_data = {0xAA, 0x55, 0xAA, 0x55};
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK INC dword [rdi]: F0 FF 07
    {
      TestCase tc;
      tc.name = "lock inc dword [rdi]";
      tc.category = cat;
      tc.code = {0xF0, 0xFF, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.init_data = {0xFF, 0xFF, 0xFF, 0x7F};  // 0x7FFFFFFF → overflow
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK DEC dword [rdi]: F0 FF 0F
    {
      TestCase tc;
      tc.name = "lock dec dword [rdi]";
      tc.category = cat;
      tc.code = {0xF0, 0xFF, 0x0F};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.init_data = {0x00, 0x00, 0x00, 0x00};  // 0 → underflow
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK XADD [rdi], eax: F0 0F C1 07
    // Swaps src and dst, then adds. [rdi] += eax, eax gets old [rdi].
    {
      TestCase tc;
      tc.name = "lock xadd [rdi],eax 32";
      tc.category = cat;
      tc.code = {0xF0, 0x0F, 0xC1, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 10;
      tc.init_data = {0x05, 0x00, 0x00, 0x00};  // [rdi] = 5
      tc.flags_mask = FL_ALL;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK BTS [rdi], eax: F0 0F AB 07
    // Set bit eax in [rdi], CF = old bit value
    {
      TestCase tc;
      tc.name = "lock bts [rdi],eax (bit 3)";
      tc.category = cat;
      tc.code = {0xF0, 0x0F, 0xAB, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 3;  // set bit 3
      tc.init_data = {0x00, 0x00, 0x00, 0x00};  // bit 3 was 0
      tc.flags_mask = FL_CF;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK BTR [rdi], eax: F0 0F B3 07
    // Reset bit eax in [rdi], CF = old bit value
    {
      TestCase tc;
      tc.name = "lock btr [rdi],eax (bit 7)";
      tc.category = cat;
      tc.code = {0xF0, 0x0F, 0xB3, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 7;  // reset bit 7
      tc.init_data = {0xFF, 0x00, 0x00, 0x00};  // bit 7 was 1
      tc.flags_mask = FL_CF;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }

    // LOCK BTC [rdi], eax: F0 0F BB 07
    // Complement bit eax in [rdi], CF = old bit value
    {
      TestCase tc;
      tc.name = "lock btc [rdi],eax (bit 0)";
      tc.category = cat;
      tc.code = {0xF0, 0x0F, 0xBB, 0x07};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.rdi = DATA_ADDR;
      tc.initial.rax = 0;  // toggle bit 0
      tc.init_data = {0x01, 0x00, 0x00, 0x00};  // bit 0 was 1 → 0
      tc.flags_mask = FL_CF;
      tc.compare_data_len = 4;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // VPERM2F128 — 256-bit lane permute (use VINSERTF128 to set up YMM state)
  // =====================================================================
  cat = "VPERM2F128";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
    s.xmm[1] = xmm_from_f32(5.0f, 6.0f, 7.0f, 8.0f);
    s.xmm[2] = xmm_from_f32(9.0f, 10.0f, 11.0f, 12.0f);
    // Use VINSERTF128 to set up ymm0 = {hi:xmm1, lo:xmm0}, then VPERM2F128
    // VINSERTF128 ymm0, ymm0, xmm1, 1: C4 E3 7D 18 C1 01
    // Then VPERM2F128 ymm3, ymm0, ymm0, 0x01: swap halves
    // C4 E3 7D 06 D8 01 (dst=ymm3, vvvv=ymm0, src2=ymm0, imm=0x01)
    {
      TestCase tc;
      tc.name = "vperm2f128 swap";
      tc.category = cat;
      // Setup: vinsertf128 ymm0, ymm0, xmm1, 1
      // Then: vperm2f128 ymm3, ymm0, ymm0, 0x01
      tc.code = {0xC4, 0xE3, 0x7D, 0x18, 0xC1, 0x01,   // vinsertf128
                 0xC4, 0xE3, 0x7D, 0x06, 0xD8, 0x01};  // vperm2f128
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0xFFFF;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // VINSERTI128/VEXTRACTI128 — AVX2 lane insert/extract
  // =====================================================================
  cat = "VEX insert/extract i128";
  {
    auto add_test = [&](const char *name, std::vector<u8> code, ArchState init, u64 mask) {
      tests.push_back({name, cat, std::move(code), init, mask, 0xFFFF});
    };

    ArchState s = {};
    s.rflags = 0x2;
    s.xmm[0] = xmm_from_u64(0x1111111111111111ULL, 0x2222222222222222ULL);
    s.xmm[1] = xmm_from_u64(0xAAAAAAAAAAAAAAAAULL, 0xBBBBBBBBBBBBBBBBULL);

    // VINSERTI128 ymm2, ymm0, xmm1, 1
    add_test("vinserti128 hi", {0xC4, 0xE3, 0x7D, 0x38, 0xD1, 0x01}, s, FL_NONE);

    // VINSERTI128 ymm2, ymm0, xmm1, 0
    add_test("vinserti128 lo", {0xC4, 0xE3, 0x7D, 0x38, 0xD1, 0x00}, s, FL_NONE);

    // VEXTRACTI128 xmm3, ymm0, 1
    add_test("vextracti128 hi", {0xC4, 0xE3, 0x7D, 0x39, 0xC3, 0x01}, s, FL_NONE);

    // VEXTRACTI128 xmm3, ymm0, 0
    add_test("vextracti128 lo", {0xC4, 0xE3, 0x7D, 0x39, 0xC3, 0x00}, s, FL_NONE);
  }

  // =====================================================================
  // VPMASKMOVD — VEX masked load/store
  // =====================================================================
  cat = "VPMASKMOVD";
  {
    ArchState s = {};
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;

    // Set mask in xmm1: sign bits set for elements 0 and 2
    s.xmm[1] = xmm_from_u32(0x80000000u, 0x00000000u, 0x80000000u, 0x00000000u);

    // Memory data: 0x11111111, 0x22222222, 0x33333333, 0x44444444
    std::vector<u8> data(16);
    for (int i = 0; i < 4; i++) {
      uint32_t v = (uint32_t)(i + 1) * 0x11111111u;
      memcpy(data.data() + i * 4, &v, 4);
    }

    // VPMASKMOVD xmm0, xmm1, [rdi]: VEX.NDS.128.66.0F38 8C /r
    // C4 E2 71 8C 07 (vvvv=xmm1=~0001=1110 → 0111_0001 = 0x71, modrm=07=[rdi])
    {
      TestCase tc;
      tc.name = "vpmaskmovd load partial";
      tc.category = cat;
      tc.code = {0xC4, 0xE2, 0x71, 0x8C, 0x07};
      tc.initial = s;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x1;
      tc.init_data = data;
      tests.push_back(std::move(tc));
    }
  }

  // =====================================================================
  // EVEX writemask (k-register masking) tests
  //
  // EVEX P2 byte: z.L'L.b.V'.aaa
  // aaa = mask register index (0=no mask, 1=k1, etc.)
  // z = 0: merge masking (preserve dest elements), z = 1: zero masking
  //
  // For 128-bit with k1 merge: P2 = 0.00.0.1.001 = 0x09
  // For 128-bit with k1 zero:  P2 = 1.00.0.1.001 = 0x89
  // =====================================================================
  cat = "EVEX mask";
  {
    // VPADDD xmm0{k1}, xmm1, xmm2 — merge masking, partial mask
    // k1 = 0b0101 → elements 0,2 updated, elements 1,3 preserved from dest
    // P2 = 0x09 (z=0, L'L=00, b=0, V'=1, aaa=001)
    {
      TestCase tc;
      tc.name = "vpaddd xmm merge k1=0101b";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x75, 0x09, 0xFE, 0xC2};  // VPADDD xmm0{k1}, xmm1, xmm2
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_u32(0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF);
      tc.initial.xmm[1] = xmm_from_u32(1, 2, 3, 4);
      tc.initial.xmm[2] = xmm_from_u32(10, 20, 30, 40);
      tc.initial.kregs[1] = 0x5;  // k1 = 0101b
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VPADDD xmm0{k1}{z}, xmm1, xmm2 — zero masking
    // k1 = 0b0101 → elements 0,2 get result, elements 1,3 zeroed
    // P2 = 0x89 (z=1, L'L=00, b=0, V'=1, aaa=001)
    {
      TestCase tc;
      tc.name = "vpaddd xmm zero k1=0101b";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x75, 0x89, 0xFE, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_u32(0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF);
      tc.initial.xmm[1] = xmm_from_u32(1, 2, 3, 4);
      tc.initial.xmm[2] = xmm_from_u32(10, 20, 30, 40);
      tc.initial.kregs[1] = 0x5;  // k1 = 0101b
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VPADDD xmm0{k1}, xmm1, xmm2 — full mask (k1=0xF = all ones for 4 dwords)
    // Should behave like no masking
    {
      TestCase tc;
      tc.name = "vpaddd xmm merge k1=full";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x75, 0x09, 0xFE, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[1] = xmm_from_u32(1, 2, 3, 4);
      tc.initial.xmm[2] = xmm_from_u32(10, 20, 30, 40);
      tc.initial.kregs[1] = 0xF;  // all dword elements active
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VPADDD xmm0{k1}, xmm1, xmm2 — empty mask (k1=0)
    // Merge: all elements preserved from dest (no operation)
    {
      TestCase tc;
      tc.name = "vpaddd xmm merge k1=0";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x75, 0x09, 0xFE, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_u32(0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC, 0xDDDDDDDD);
      tc.initial.xmm[1] = xmm_from_u32(1, 2, 3, 4);
      tc.initial.xmm[2] = xmm_from_u32(10, 20, 30, 40);
      tc.initial.kregs[1] = 0;  // empty mask
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VPADDD xmm0{k1}{z}, xmm1, xmm2 — empty mask, zero masking
    // All elements zeroed
    {
      TestCase tc;
      tc.name = "vpaddd xmm zero k1=0";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x75, 0x89, 0xFE, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_u32(0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF, 0xDEADBEEF);
      tc.initial.xmm[1] = xmm_from_u32(1, 2, 3, 4);
      tc.initial.xmm[2] = xmm_from_u32(10, 20, 30, 40);
      tc.initial.kregs[1] = 0;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VADDPS xmm0{k2}, xmm1, xmm2 — FP with merge mask
    // k2 = 0b1010 → elements 1,3 updated, elements 0,2 preserved
    // P2 = 0x0A (z=0, aaa=010=k2)
    {
      TestCase tc;
      tc.name = "vaddps xmm merge k2=1010b";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x74, 0x0A, 0x58, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_f32(-1.0f, -1.0f, -1.0f, -1.0f);
      tc.initial.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      tc.initial.xmm[2] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
      tc.initial.kregs[2] = 0xA;  // 1010b
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VADDPS xmm0{k2}{z}, xmm1, xmm2 — FP with zero mask
    // P2 = 0x8A (z=1, aaa=010=k2)
    {
      TestCase tc;
      tc.name = "vaddps xmm zero k2=1010b";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x74, 0x8A, 0x58, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_f32(-1.0f, -1.0f, -1.0f, -1.0f);
      tc.initial.xmm[1] = xmm_from_f32(1.0f, 2.0f, 3.0f, 4.0f);
      tc.initial.xmm[2] = xmm_from_f32(10.0f, 20.0f, 30.0f, 40.0f);
      tc.initial.kregs[2] = 0xA;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // VPXORD xmm0{k1}, xmm1, xmm2 — logical with mask
    // k1 = 0b0011 → only elements 0,1 updated
    {
      TestCase tc;
      tc.name = "vpxord xmm merge k1=0011b";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x75, 0x09, 0xEF, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_u32(0x11111111, 0x22222222, 0x33333333, 0x44444444);
      tc.initial.xmm[1] = xmm_from_u32(0xFF00FF00, 0x00FF00FF, 0xAAAAAAAA, 0x55555555);
      tc.initial.xmm[2] = xmm_from_u32(0x0F0F0F0F, 0xF0F0F0F0, 0x12345678, 0x9ABCDEF0);
      tc.initial.kregs[1] = 0x3;
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }

    // 256-bit EVEX with mask: VPADDD ymm0{k1}, ymm1, ymm2
    // P2 = 0x29 (z=0, L'L=01=256-bit, b=0, V'=1, aaa=001)
    // k1 = 0b01010101 → alternate elements
    {
      TestCase tc;
      tc.name = "vpaddd ymm merge k1=55h";
      tc.category = cat;
      tc.code = {0x62, 0xF1, 0x75, 0x29, 0xFE, 0xC2};
      tc.initial = {};
      tc.initial.rflags = 0x2;
      tc.initial.xmm[0] = xmm_from_u32(0xDEAD0000, 0xDEAD0001, 0xDEAD0002, 0xDEAD0003);
      tc.initial.xmm[1] = xmm_from_u32(1, 2, 3, 4);
      tc.initial.xmm[2] = xmm_from_u32(100, 200, 300, 400);
      tc.initial.kregs[1] = 0x55;  // 01010101b
      tc.flags_mask = FL_NONE;
      tc.xmm_mask = 0x7;
      tests.push_back(std::move(tc));
    }
  }

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

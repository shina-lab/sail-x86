#include "kvm-harness.h"
#include <cpuid.h>

// System and privileged instructions that the differential suite can observe
// from CPL 0 in the guest: control-register moves and CLTS, RDTSC's zero
// extension, RDPMC's #GP, the fault paths of SYSCALL/SYSRET/SYSENTER/SYSEXIT
// without their MSRs, VMREAD/VMWRITE outside VMX operation, CLI, INT n, RSM
// outside SMM, and the cache instructions KVM intercepts.
//
// For an intercepted instruction the reference behavior includes KVM's
// implementation: INVD and WBINVD are emulated as no-ops, MOV to CR0/CR4/CR8
// is validated by KVM's own checks (which agree with the SDM for every case
// below), and RDPMC is answered by the virtual PMU.
void add_system_tests(std::vector<TestCase> &tests) {
  std::string cat;

  u32 vendor_eax, vendor_ebx, vendor_ecx, vendor_edx;
  __get_cpuid(0, &vendor_eax, &vendor_ebx, &vendor_ecx, &vendor_edx);
  const bool amd_host = (vendor_ebx == 0x68747541);  // "Auth" of AuthenticAMD
  // MOV to/from CR leaves the arithmetic flags undefined on Intel (SDM
  // Vol.2B, MOV control-register entry); AMD preserves them (APM Vol.3).
  const u64 mov_cr_flags = amd_host ? FL_ALL : FL_DF;

  // The model's CR0 and EFER equal the guest's (0x80000011, 0x500) only
  // when a test asks for the guest's identity paging, so every test that
  // reads or writes CR0, or depends on EFER, does.
  auto add_paged = [&](const std::string &name, std::vector<u8> code, ArchState init,
                       u64 mask = FL_ALL) {
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = std::move(code);
    tc.initial = init;
    tc.flags_mask = mask;
    tc.enable_paging = true;
    tests.push_back(std::move(tc));
  };
  auto add_fault = [&](const std::string &name, std::vector<u8> code, ArchState init,
                       int vec) {
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = std::move(code);
    tc.initial = init;
    tc.flags_mask = FL_ALL;
    tc.expect_fault = true;
    tc.expected_vector = vec;
    tc.enable_paging = true;
    tests.push_back(std::move(tc));
  };
  auto add = [&](const std::string &name, std::vector<u8> code, ArchState init,
                 u64 mask = FL_ALL) {
    tests.push_back({name, cat, std::move(code), init, mask});
  };

  const u64 CR0_GUEST = 0x80000011;  // PG + ET + PE, as the harness sets it
  const u64 CR4_GUEST = 0x50620;     // PAE + OSFXSR + OSXMMEXCPT + FSGSBASE + OSXSAVE

  // =====================================================================
  // MOV r64, CRn / MOV CRn, r64 (0F 20 /r, 0F 22 /r) and CLTS (0F 06)
  // =====================================================================
  cat = "System CR";
  {
    // Reads.  CR3 is not compared: the two sides page from different tables.
    add_paged("mov rax,cr0", {0x0F, 0x20, 0xC0}, {}, mov_cr_flags);
    add_paged("mov r15,cr0 (REX.B)", {0x41, 0x0F, 0x20, 0xC7}, {}, mov_cr_flags);
    add_paged("mov rax,cr2", {0x0F, 0x20, 0xD0}, {}, mov_cr_flags);
    add_paged("mov rax,cr4", {0x0F, 0x20, 0xE0}, {}, mov_cr_flags);
    add_paged("mov rax,cr8 (REX.R)", {0x44, 0x0F, 0x20, 0xC0}, {}, mov_cr_flags);

    // Writes, each read back through a second register.
    auto write_read = [&](const std::string &name, u64 value,
                          std::vector<u8> write, std::vector<u8> read) {
      std::vector<u8> code = write;
      code.insert(code.end(), read.begin(), read.end());
      add_paged(name, code, {.rax = value}, mov_cr_flags);
    };
    const std::vector<u8> mov_cr0_rax = {0x0F, 0x22, 0xC0}, mov_rbx_cr0 = {0x0F, 0x20, 0xC3};
    const std::vector<u8> mov_cr4_rax = {0x0F, 0x22, 0xE0}, mov_rbx_cr4 = {0x0F, 0x20, 0xE3};
    const std::vector<u8> mov_cr2_rax = {0x0F, 0x22, 0xD0}, mov_rbx_cr2 = {0x0F, 0x20, 0xD3};
    const std::vector<u8> mov_cr8_rax = {0x44, 0x0F, 0x22, 0xC0}, mov_rbx_cr8 = {0x44, 0x0F, 0x20, 0xC3};

    write_read("mov cr0,rax (unchanged); mov rbx,cr0", CR0_GUEST, mov_cr0_rax, mov_rbx_cr0);
    write_read("mov cr0,rax sets TS; mov rbx,cr0", CR0_GUEST | 0x8, mov_cr0_rax, mov_rbx_cr0);
    write_read("mov cr0,rax sets NE, WP, AM; mov rbx,cr0",
               CR0_GUEST | 0x20 | 0x10000 | 0x40000, mov_cr0_rax, mov_rbx_cr0);
    write_read("mov cr0,rax sets CD and NW; mov rbx,cr0",
               CR0_GUEST | 0x60000000, mov_cr0_rax, mov_rbx_cr0);
    // SDM: setting a reserved bit in CR0[31:0] is ignored.
    write_read("mov cr0,rax with reserved bits 8 and 20 (ignored); mov rbx,cr0",
               CR0_GUEST | 0x100 | 0x100000, mov_cr0_rax, mov_rbx_cr0);
    write_read("mov cr4,rax sets TSD; mov rbx,cr4", CR4_GUEST | 0x4, mov_cr4_rax, mov_rbx_cr4);
    write_read("mov cr4,rax sets PCE; mov rbx,cr4", CR4_GUEST | 0x100, mov_cr4_rax, mov_rbx_cr4);
    write_read("mov cr2,rax; mov rbx,cr2", 0x123456789ABCDEF0, mov_cr2_rax, mov_rbx_cr2);
    // The TPR is restored to 0 at the end: KVM on AMD keeps a guest's CR8
    // write in the VMCB, where the harness's per-test reset does not reach.
    {
      std::vector<u8> code = mov_cr8_rax;
      code.insert(code.end(), mov_rbx_cr8.begin(), mov_rbx_cr8.end());
      code.insert(code.end(), {0x31, 0xC9, 0x44, 0x0F, 0x22, 0xC1});  // xor ecx,ecx; mov cr8,rcx
      add_paged("mov cr8,rax; mov rbx,cr8; mov cr8,rcx (0)", code, {.rax = 0x9}, mov_cr_flags);
    }

    // CLTS: clear a TS set through CR0, and a TS already clear.
    {
      std::vector<u8> code = mov_cr0_rax;
      code.insert(code.end(), {0x0F, 0x06});
      code.insert(code.end(), mov_rbx_cr0.begin(), mov_rbx_cr0.end());
      add_paged("mov cr0,rax sets TS; clts; mov rbx,cr0", code, {.rax = CR0_GUEST | 0x8}, mov_cr_flags);
    }
    {
      std::vector<u8> code = {0x0F, 0x06};
      code.insert(code.end(), mov_rbx_cr0.begin(), mov_rbx_cr0.end());
      add_paged("clts with TS clear; mov rbx,cr0", code, {}, mov_cr_flags);
    }

    // #GP(0) cases from the SDM's 64-bit mode exception list.
    add_fault("mov cr0,rax with bit 40 set (#GP: CR0[63:32] reserved)",
              mov_cr0_rax, {.rax = CR0_GUEST | (1ULL << 40)}, 13);
    add_fault("mov cr0,rax with NW=1, CD=0 (#GP)", mov_cr0_rax, {.rax = CR0_GUEST | 0x20000000}, 13);
    add_fault("mov cr0,rax with PG=1, PE=0 (#GP)", mov_cr0_rax, {.rax = CR0_GUEST & ~1ULL}, 13);
    add_fault("mov cr4,rax with bit 63 set (#GP: reserved)", mov_cr4_rax, {.rax = CR4_GUEST | (1ULL << 63)}, 13);
    add_fault("mov cr4,rax with bit 15 set (#GP: reserved)", mov_cr4_rax, {.rax = CR4_GUEST | 0x8000}, 13);
    add_fault("mov cr4,rax clearing PAE in IA-32e mode (#GP)", mov_cr4_rax, {.rax = CR4_GUEST & ~0x20ULL}, 13);
    add_fault("mov cr8,rax with bit 4 set (#GP: reserved)", mov_cr8_rax, {.rax = 0x10}, 13);
    // #UD: CR1, CR5, and REX.R naming a register other than CR8.
    add_fault("mov rax,cr1 (#UD)", {0x0F, 0x20, 0xC8}, {}, 6);
    add_fault("mov cr5,rax (#UD)", {0x0F, 0x22, 0xE8}, {}, 6);
    add_fault("mov rax,cr9 via REX.R (#UD)", {0x44, 0x0F, 0x20, 0xC8}, {}, 6);
  }

  // =====================================================================
  // RDTSC (0F 31), RDPMC (0F 33)
  // =====================================================================
  cat = "System TSC";
  {
    // The counter value is not comparable; the zero extension of EAX and
    // EDX into RAX and RDX is.  The shifts' flags depend on the value.
    std::vector<u8> rdtsc_zx = {0x0F, 0x31,
                                0x48, 0xC1, 0xE8, 0x20,   // shr rax,32
                                0x48, 0xC1, 0xEA, 0x20};  // shr rdx,32
    add("rdtsc; shr rax,32; shr rdx,32 (zero extension)", rdtsc_zx, {}, FL_DF);
    {
      TestCase tc = {"rdtsc with CR4.TSD set at CPL 0", cat, rdtsc_zx, {}, FL_DF};
      tc.cr4_override = CR4_GUEST | 0x4;
      tests.push_back(std::move(tc));
    }
    // An index that is not a counter on any processor: #GP(0).  Valid
    // indices are answered by KVM's virtual PMU, which the model does not
    // have, so they are not compared.
    add_fault("rdpmc with an invalid counter index (#GP)", {0x0F, 0x33}, {.rcx = 0x12345678}, 13);
  }

  // =====================================================================
  // SYSCALL/SYSRET without EFER.SCE, SYSENTER/SYSEXIT without their MSR
  // =====================================================================
  cat = "System fast-call faults";
  {
    // The guest's EFER is LME+LMA with SCE clear; IA32_SYSENTER_CS is 0.
    add_fault("syscall with EFER.SCE=0 (#UD)", {0x0F, 0x05}, {}, 6);
    add_fault("sysret with EFER.SCE=0 (#UD)", {0x0F, 0x07}, {}, 6);
    add_fault("sysretq with EFER.SCE=0 (#UD)", {0x48, 0x0F, 0x07}, {}, 6);
    // AMD processors have no SYSENTER in 64-bit mode (it is #UD), and KVM's
    // emulator declines to emulate it there, so this case runs on Intel
    // hosts only.  SYSEXIT is emulated by KVM on AMD with the Intel #GP.
    if (!amd_host)
      add_fault("sysenter with IA32_SYSENTER_CS=0 (#GP)", {0x0F, 0x34}, {}, 13);
    add_fault("sysexit with IA32_SYSENTER_CS=0 (#GP)", {0x0F, 0x35}, {}, 13);
    add_fault("sysexitq with IA32_SYSENTER_CS=0 (#GP)", {0x48, 0x0F, 0x35}, {}, 13);
  }

  // =====================================================================
  // VMREAD/VMWRITE (0F 78, 0F 79) outside VMX operation: #UD
  // =====================================================================
  cat = "System VMX";
  {
    add_fault("vmread rax,rbx outside VMX operation (#UD)", {0x0F, 0x78, 0xD8}, {}, 6);
    add_fault("vmread [rdi],rbx outside VMX operation (#UD)", {0x0F, 0x78, 0x1F}, {.rdi = DATA_ADDR}, 6);
    add_fault("vmwrite rbx,rax outside VMX operation (#UD)", {0x0F, 0x79, 0xD8}, {}, 6);
    add_fault("vmwrite rbx,[rdi] outside VMX operation (#UD)", {0x0F, 0x79, 0x1F}, {.rdi = DATA_ADDR}, 6);
  }

  // =====================================================================
  // CLI (FA), INVD (0F 08), WBINVD (0F 09), RSM (0F AA), INT n (CD ib)
  // =====================================================================
  cat = "System misc";
  {
    // IF is part of the compared RFLAGS.
    add("sti; cli", {0xFB, 0xFA}, {});
    add("cli with IF clear", {0xFA}, {});
    add("sti; cli; sti (IF set at HLT)", {0xFB, 0xFA, 0xFB}, {});
    // KVM emulates both as no-ops; no architectural state changes.
    add("invd", {0x0F, 0x08}, {});
    add("wbinvd", {0x0F, 0x09}, {});
    add_fault("rsm outside SMM (#UD)", {0x0F, 0xAA}, {}, 6);

    // INT n to a gate of the harness's IDT: recorded like a fault with the
    // vector, no error code, and the next instruction as the return RIP.
    // Vectors whose handler stub expects a CPU-pushed error code (8, 10-14,
    // 17, 21, 30) and the fault-class vectors are left out.
    for (int vec : {1, 2, 3, 4, 9, 15, 18, 22, 27, 31}) {
      add_fault("int " + std::to_string(vec), {0xCD, u8(vec), 0x90}, {}, vec);
    }
    add_fault("int 3 after mov rax,imm", {0x48, 0xC7, 0xC0, 0x78, 0x56, 0x34, 0x12, 0xCD, 0x03, 0x90}, {}, 3);
  }
}

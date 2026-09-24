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

    // RDPID (F3 0F C7 /7): IA32_TSC_AUX into the destination, the full
    // 64-bit register in 64-bit mode whatever the 66 prefix says.
    {
      u32 a, b, c, d;
      if (__get_cpuid_count(7, 0, &a, &b, &c, &d) && (c & (1u << 22))) {
        const u32 MSR_TSC_AUX = 0xC0000103;
        auto rdpid = [&](const std::string &name, std::vector<u8> code, u64 aux) {
          TestCase tc = {name, cat, std::move(code), {}, FL_ALL};
          tc.msrs = {{MSR_TSC_AUX, aux}};
          tests.push_back(std::move(tc));
        };
        rdpid("rdpid rbx", {0xF3, 0x0F, 0xC7, 0xFB}, 0x00C0FFEE);
        rdpid("rdpid rbx (TSC_AUX = 0)", {0xF3, 0x0F, 0xC7, 0xFB}, 0);
        rdpid("rdpid rbx (66 prefix: still the full register)", {0x66, 0xF3, 0x0F, 0xC7, 0xFB}, 0x89ABCDEF);
        rdpid("rdpid r11 (REX.B)", {0xF3, 0x41, 0x0F, 0xC7, 0xFB}, 0x12345678);
      }
    }
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
    // 17, 21, 30) are left out.  The fault-class vectors 0, 5, 6, 7, 16, 19
    // and 20 check that the pushed RFLAGS image carries RF = 0 for a
    // software interrupt (SDM Vol.3B §20.3.1.1), not the 1 of a fault.
    for (int vec : {0, 1, 2, 3, 4, 5, 6, 7, 9, 15, 16, 18, 19, 20, 22, 27, 31}) {
      add_fault("int " + std::to_string(vec), {0xCD, u8(vec), 0x90}, {}, vec);
    }
    add_fault("int 3 after mov rax,imm", {0x48, 0xC7, 0xC0, 0x78, 0x56, 0x34, 0x12, 0xCD, 0x03, 0x90}, {}, 3);
  }

  // =====================================================================
  // LTR r/m16 (0F 00 /3) and STR (0F 00 /1)
  // =====================================================================
  cat = "System LTR";
  {
    // The GDT's TSS descriptor (selector 0x18) is an available 64-bit TSS
    // in memory although TR already holds it as busy, so a first LTR
    // succeeds and marks it busy; STR to memory reads the selector back.
    // The checks of the SDM's Operation section, in order: a null selector
    // #GP(0); an LDT selector or one beyond the GDT limit #GP(selector);
    // a descriptor that is not an available TSS #GP(selector).
    auto ltr = [&](const std::string &name, std::vector<u8> code, ArchState init,
                   std::vector<u8> data, size_t cmp_len) {
      TestCase tc;
      tc.name = name;
      tc.category = cat;
      tc.code = std::move(code);
      tc.initial = init;
      tc.flags_mask = FL_ALL;
      tc.init_data = std::move(data);
      tc.compare_data_len = cmp_len;
      tests.push_back(std::move(tc));
    };
    const std::vector<u8> ltr_ax = {0x0F, 0x00, 0xD8};   // ltr ax
    const std::vector<u8> str_mem = {0x0F, 0x00, 0x0F};  // str word [rdi]
    auto then_str = [&](std::vector<u8> code) {
      code.insert(code.end(), str_mem.begin(), str_mem.end());
      return code;
    };
    const std::vector<u8> zero2(2, 0);
    ltr("ltr ax (0x18, available TSS); str [rdi]", then_str(ltr_ax), {.rax = 0x18, .rdi = DATA_ADDR}, zero2, 2);
    ltr("ltr ax (0x1B, RPL kept); str [rdi]", then_str(ltr_ax), {.rax = 0x1B, .rdi = DATA_ADDR}, zero2, 2);
    // ltr word [rdi]; str word [rdi+8]
    ltr("ltr word [rdi] (0x18); str [rdi+8]", {0x0F, 0x00, 0x1F, 0x0F, 0x00, 0x4F, 0x08},
        {.rdi = DATA_ADDR}, {0x18, 0x00, 0, 0, 0, 0, 0, 0, 0, 0}, 10);
    add_fault("ltr ax twice (busy TSS → #GP(0x18))", {0x0F, 0x00, 0xD8, 0x0F, 0x00, 0xD8}, {.rax = 0x18}, 13);
    add_fault("ltr ax (null selector → #GP(0))", ltr_ax, {.rax = 0}, 13);
    add_fault("ltr ax (0x3, null with RPL → #GP(0))", ltr_ax, {.rax = 0x3}, 13);
    add_fault("ltr ax (0x1C, LDT selector → #GP(0x1C))", ltr_ax, {.rax = 0x1C}, 13);
    add_fault("ltr ax (0x100, beyond the GDT limit → #GP(0x100))", ltr_ax, {.rax = 0x100}, 13);
    add_fault("ltr ax (0x8000, far beyond the GDT → #GP(0x8000))", ltr_ax, {.rax = 0x8000}, 13);
    add_fault("ltr ax (0x10, data segment → #GP(0x10))", ltr_ax, {.rax = 0x10}, 13);
    add_fault("ltr ax (0x08, code segment → #GP(0x08))", ltr_ax, {.rax = 0x08}, 13);
    add_fault("ltr ax (0x28, gate descriptor → #GP(0x28))", ltr_ax, {.rax = 0x28}, 13);
  }

  // =====================================================================
  // SYSCALL/SYSRET/SYSENTER/SYSEXIT with their MSRs
  // =====================================================================
  cat = "System fast call";
  {
    // The model runs in system mode here, delivering exceptions through a
    // mirror of the guest's IDT, so a return to CPL 3 can end in a UD2
    // whose #UD (vector, RIP, pushed RFLAGS) is the observed outcome.
    const u32 MSR_EFER = 0xC0000080, MSR_STAR = 0xC0000081, MSR_LSTAR = 0xC0000082,
              MSR_FMASK = 0xC0000084, MSR_SYSENTER_CS = 0x174, MSR_SYSENTER_ESP = 0x175,
              MSR_SYSENTER_EIP = 0x176;
    const u64 EFER_SCE = 0x501;                      // LME + LMA + SCE
    const u64 STAR = (0x43ULL << 48) | (0x08ULL << 32);  // SYSRET: CS 0x53/0x43, SS 0x4B; SYSCALL: CS 0x08, SS 0x10
    auto sys = [&](const std::string &name, std::vector<u8> code, ArchState init,
                   std::vector<std::pair<u32, u64>> msrs, int vec = -2) {
      TestCase tc;
      tc.name = name;
      tc.category = cat;
      tc.code = std::move(code);
      tc.initial = init;
      tc.flags_mask = FL_ALL;
      tc.enable_paging = true;
      tc.system_mode = true;
      tc.msrs = std::move(msrs);
      if (vec != -2) {
        tc.expect_fault = true;
        tc.expected_vector = vec;
      }
      tests.push_back(std::move(tc));
    };
    // Layout: the instruction at offset 0, a UD2 behind it that only a
    // missing transfer would reach, NOPs, and the transfer target at
    // offset 8: nothing (the harness's HLT) for an entry to CPL 0, UD2 or
    // INT3 for a return to CPL 3.
    auto layout = [](std::vector<u8> insn, std::vector<u8> target) {
      std::vector<u8> code = std::move(insn);
      code.insert(code.end(), {0x0F, 0x0B});
      while (code.size() < 8) code.push_back(0x90);
      code.insert(code.end(), target.begin(), target.end());
      return code;
    };
    const std::vector<u8> ud2 = {0x0F, 0x0B};
    const u64 TARGET = CODE_ADDR + 8;

    // SYSCALL: RCX := next RIP, R11 := RFLAGS, RFLAGS &= ~FMASK, RIP := LSTAR,
    // CPL stays 0.  IF and DF are set at the call so FMASK's effect shows.
    for (u64 fmask : {0ULL, 0x600ULL}) {
      ArchState s = {.rflags = initial_flags() | 0x600};
      sys(std::format("syscall (FMASK={:#x})", fmask), layout({0x0F, 0x05}, {}), s,
          {{MSR_EFER, EFER_SCE}, {MSR_STAR, STAR}, {MSR_LSTAR, TARGET}, {MSR_FMASK, fmask}});
    }

    // SYSRET: RIP := RCX, RFLAGS := (R11 & 3C7FD7H) | 2, CS/SS from STAR[63:48],
    // CPL 3.  The UD2 at the target reports the loaded RIP and RFLAGS.
    {
      ArchState s = {.rcx = TARGET, .r11 = 0x202};
      sys("sysretq to CPL 3 (ud2 there)", layout({0x48, 0x0F, 0x07}, ud2), s,
          {{MSR_EFER, EFER_SCE}, {MSR_STAR, STAR}}, 6);
      ArchState f = {.rcx = TARGET, .r11 = 0x2 | FL_ARITH | (1ULL << 16) | (1ULL << 17)};
      sys("sysretq with RF and VM in R11 (masked)", layout({0x48, 0x0F, 0x07}, ud2), f,
          {{MSR_EFER, EFER_SCE}, {MSR_STAR, STAR}}, 6);
      sys("sysret to compatibility mode CPL 3 (ud2 there)", layout({0x0F, 0x07}, ud2), s,
          {{MSR_EFER, EFER_SCE}, {MSR_STAR, STAR}}, 6);
      // Intel raises the #GP(0) in SYSRET itself (SDM Vol.2B SYSRET); AMD
      // completes the return and faults on the fetch at CPL 3, with the
      // non-canonical RIP and the new RFLAGS in the frame (observed on the
      // Threadripper), so this case runs on Intel hosts only.
      if (!amd_host) {
        ArchState nc = {.rcx = 0x0000800000000000ULL, .r11 = 0x202};
        sys("sysretq with a non-canonical RCX (#GP)", layout({0x48, 0x0F, 0x07}, ud2), nc,
            {{MSR_EFER, EFER_SCE}, {MSR_STAR, STAR}}, 13);
      }
      // INT3 at CPL 3 through a DPL 0 gate: #GP with error code 3*8+2.
      sys("sysretq then int3 at CPL 3 (#GP, error 0x1a)", layout({0x48, 0x0F, 0x07}, {0xCC}), s,
          {{MSR_EFER, EFER_SCE}, {MSR_STAR, STAR}}, 13);
    }

    // SYSENTER (Intel hosts only, see above): CS 0x08, SS 0x10, RSP and RIP
    // from the MSRs, IF cleared.  Bits 15:2 of IA32_SYSENTER_CS zero: #GP(0).
    if (!amd_host) {
      ArchState s = {.rflags = initial_flags() | 0x200};
      sys("sysenter to CPL 0 (HLT at SYSENTER_EIP)", layout({0x0F, 0x34}, {}), s,
          {{MSR_SYSENTER_CS, 0x08}, {MSR_SYSENTER_ESP, STACK_TOP - 0x100}, {MSR_SYSENTER_EIP, TARGET}});
      sys("sysenter with IA32_SYSENTER_CS=3 (#GP: bits 15:2 zero)", layout({0x0F, 0x34}, {}), s,
          {{MSR_SYSENTER_CS, 0x3}, {MSR_SYSENTER_ESP, STACK_TOP - 0x100}, {MSR_SYSENTER_EIP, TARGET}}, 13);
    }

    // SYSEXIT: CS := IA32_SYSENTER_CS + 32 (64-bit) or + 16, RPL 3, SS := CS + 8,
    // RIP := RDX, RSP := RCX, CPL 3.  With SYSENTER_CS = 0x33 the selectors
    // are the GDT's user code and data (0x53, 0x5B) or 0x43 and 0x4B.
    {
      ArchState s = {.rcx = STACK_TOP - 0x200, .rdx = TARGET};
      sys("sysexitq to CPL 3 (ud2 there)", layout({0x48, 0x0F, 0x35}, ud2), s, {{MSR_SYSENTER_CS, 0x33}}, 6);
      sys("sysexit to compatibility mode CPL 3 (ud2 there)", layout({0x0F, 0x35}, ud2), s, {{MSR_SYSENTER_CS, 0x33}}, 6);
      ArchState nc = {.rcx = STACK_TOP - 0x200, .rdx = 0x0000800000000000ULL};
      sys("sysexitq with a non-canonical RDX (#GP)", layout({0x48, 0x0F, 0x35}, ud2), nc, {{MSR_SYSENTER_CS, 0x33}}, 13);
      // IA32_SYSENTER_CS = 3: bits 15:2 zero, #GP(0) per the SDM's Operation
      // section and its compatibility-mode list.  The 64-bit list says the
      // selector must be zero; the Xeon follows the pseudocode, and KVM's
      // emulator on AMD follows the list, so the 64-bit case is Intel-only.
      sys("sysexit with IA32_SYSENTER_CS=3 (#GP: bits 15:2 zero)", layout({0x0F, 0x35}, ud2), s, {{MSR_SYSENTER_CS, 0x3}}, 13);
      if (!amd_host)
        sys("sysexitq with IA32_SYSENTER_CS=3 (#GP: bits 15:2 zero)", layout({0x48, 0x0F, 0x35}, ud2), s, {{MSR_SYSENTER_CS, 0x3}}, 13);
    }
  }

  // =====================================================================
  // IN, OUT, INS, OUTS (E4-E7, EC-EF, 6C-6F)
  // =====================================================================
  cat = "System I/O";
  {
    // Every port access leaves the guest (KVM_EXIT_IO) and the model
    // (__port_in/__port_out externals); the harness compares the two
    // sequences of (direction, size, port, value), supplying the same
    // port-derived value to an IN on both sides.
    auto io = [&](const std::string &name, std::vector<u8> code, ArchState init,
                  std::vector<u8> data = {}, size_t cmp_len = 0) {
      TestCase tc;
      tc.name = name;
      tc.category = cat;
      tc.code = std::move(code);
      tc.initial = init;
      tc.flags_mask = FL_ALL;
      tc.init_data = std::move(data);
      tc.compare_data_len = cmp_len;
      tests.push_back(std::move(tc));
    };
    const u64 PORT = 0x3F8;
    // IN: AL and AX merge into RAX, EAX zero-extends.
    io("in al,0x60", {0xE4, 0x60}, {});
    io("in ax,0x60", {0x66, 0xE5, 0x60}, {});
    io("in eax,0x60", {0xE5, 0x60}, {});
    io("in al,dx", {0xEC}, {.rdx = PORT});
    io("in ax,dx", {0x66, 0xED}, {.rdx = PORT});
    io("in eax,dx", {0xED}, {.rdx = PORT});
    io("in eax,dx (REX.W ignored)", {0x48, 0xED}, {.rdx = PORT});
    // OUT: the logged value is the low 8, 16 or 32 bits of RAX.
    ArchState o = {.rax = 0x1122334455667788};
    io("out 0x60,al", {0xE6, 0x60}, o);
    io("out 0x60,ax", {0x66, 0xE7, 0x60}, o);
    io("out 0x60,eax", {0xE7, 0x60}, o);
    o.rdx = PORT;
    io("out dx,al", {0xEE}, o);
    io("out dx,ax", {0x66, 0xEF}, o);
    io("out dx,eax", {0xEF}, o);
    io("out dx,al; in al,dx; out 0x61,al", {0xEE, 0xEC, 0xE6, 0x61}, o);

    // INS: ES:[RDI] gets the value, RDI moves by the size in DF's direction.
    std::vector<u8> zeros(16, 0);
    ArchState ins = {.rdx = PORT, .rdi = DATA_ADDR};
    io("insb", {0x6C}, ins, zeros, 16);
    io("insw", {0x66, 0x6D}, ins, zeros, 16);
    io("insd", {0x6D}, ins, zeros, 16);
    io("insd (REX.W ignored)", {0x48, 0x6D}, ins, zeros, 16);
    ArchState ins_down = {.rdx = PORT, .rdi = DATA_ADDR + 8, .rflags = initial_flags() | FL_DF};
    io("insd with DF set", {0x6D}, ins_down, zeros, 16);
    ArchState ins32 = {.rdx = PORT, .rdi = DATA_ADDR};
    io("insb with a 32-bit address size", {0x67, 0x6C}, ins32, zeros, 16);
    ArchState rep = {.rcx = 3, .rdx = PORT, .rdi = DATA_ADDR};
    io("rep insb (RCX=3)", {0xF3, 0x6C}, rep, zeros, 16);
    io("rep insw (RCX=3)", {0xF3, 0x66, 0x6D}, rep, zeros, 16);
    io("rep insd (RCX=3)", {0xF3, 0x6D}, rep, zeros, 16);
    ArchState rep0 = {.rcx = 0, .rdx = PORT, .rdi = DATA_ADDR};
    io("rep insb (RCX=0: nothing)", {0xF3, 0x6C}, rep0, zeros, 16);

    // OUTS: DS:[RSI] is written to the port, RSI moves.
    std::vector<u8> src = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88,
                           0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x00};
    ArchState outs = {.rdx = PORT, .rsi = DATA_ADDR};
    io("outsb", {0x6E}, outs, src);
    io("outsw", {0x66, 0x6F}, outs, src);
    io("outsd", {0x6F}, outs, src);
    ArchState outs_down = {.rdx = PORT, .rsi = DATA_ADDR + 8, .rflags = initial_flags() | FL_DF};
    io("outsw with DF set", {0x66, 0x6F}, outs_down, src);
    ArchState reps = {.rcx = 3, .rdx = PORT, .rsi = DATA_ADDR};
    io("rep outsb (RCX=3)", {0xF3, 0x6E}, reps, src);
    io("rep outsw (RCX=3)", {0xF3, 0x66, 0x6F}, reps, src);
    io("rep outsd (RCX=3)", {0xF3, 0x6F}, reps, src);
    io("outsb with a segment override (FS)", {0x64, 0x6E}, outs, src);
  }
}

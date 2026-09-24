#include "kvm-harness.h"
#include <cpuid.h>

void add_exception_tests(std::vector<TestCase> &tests) {
  std::string cat;

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
    tests.push_back(std::move(tc));
  };

  // =====================================================================
  // Exception/Fault tests
  // =====================================================================

  // ---- #DE (vector 0): Division error ----
  cat = "Exception #DE";

  // DIV by zero — all sizes
  add_fault("div rcx (div by zero, 64-bit)", {0x48, 0xF7, 0xF1},
            {.rax = 42, .rcx = 0, .rdx = 0}, 0);
  add_fault("div ecx (div by zero, 32-bit)", {0xF7, 0xF1},
            {.rax = 42, .rcx = 0, .rdx = 0}, 0);
  add_fault("div cx (div by zero, 16-bit)", {0x66, 0xF7, 0xF1},
            {.rax = 42, .rcx = 0, .rdx = 0}, 0);
  add_fault("div cl (div by zero, 8-bit)", {0xF6, 0xF1},
            {.rax = 42, .rcx = 0}, 0);

  // IDIV by zero — all sizes
  add_fault("idiv rcx (div by zero, 64-bit)", {0x48, 0xF7, 0xF9},
            {.rax = 42, .rcx = 0, .rdx = 0}, 0);
  add_fault("idiv ecx (div by zero, 32-bit)", {0xF7, 0xF9},
            {.rax = 42, .rcx = 0, .rdx = 0}, 0);
  add_fault("idiv cx (div by zero, 16-bit)", {0x66, 0xF7, 0xF9},
            {.rax = 42, .rcx = 0, .rdx = 0}, 0);
  add_fault("idiv cl (div by zero, 8-bit)", {0xF6, 0xF9},
            {.rax = 42, .rcx = 0}, 0);

  // DIV quotient overflow

  // 8-bit: AX=0x100, CL=1 → quotient 256 doesn't fit in AL
  add_fault("div cl (quotient overflow, 8-bit)", {0xF6, 0xF1},
            {.rax = 0x100, .rcx = 1}, 0);

  // 32-bit: EDX:EAX = 0x1_00000000, ECX=1 → quotient overflows 32 bits
  add_fault("div ecx (quotient overflow, 32-bit)", {0xF7, 0xF1},
            {.rax = 0, .rcx = 1, .rdx = 1}, 0);

  // 64-bit: RDX:RAX = 2^64, RCX=1 → quotient overflows 64 bits
  add_fault("div rcx (quotient overflow, 64-bit)", {0x48, 0xF7, 0xF1},
            {.rax = 0, .rcx = 1, .rdx = 1}, 0);

  // DIV quotient overflow — 16-bit
  // DX:AX = 0x10000, CX=1 → quotient 65536 > UINT16_MAX
  add_fault("div cx (quotient overflow, 16-bit)", {0x66, 0xF7, 0xF1},
            {.rax = 0, .rcx = 1, .rdx = 1}, 0);

  // IDIV quotient overflow

  // 8-bit: AX=0x80, CL=1 → quotient 128 > INT8_MAX (127)
  add_fault("idiv cl (quotient overflow, 8-bit)", {0xF6, 0xF9},
            {.rax = 0x80, .rcx = 1}, 0);

  // 32-bit: EDX=0, EAX=0x80000000, ECX=1 → quotient 0x80000000 > INT32_MAX
  add_fault("idiv ecx (quotient overflow, 32-bit)", {0xF7, 0xF9},
            {.rax = 0x80000000, .rcx = 1, .rdx = 0}, 0);

  // 64-bit: RDX=0, RAX=0x8000000000000000, RCX=1
  add_fault("idiv rcx (quotient overflow, 64-bit)", {0x48, 0xF7, 0xF9},
            {.rax = 0x8000000000000000ULL, .rcx = 1, .rdx = 0}, 0);

  // IDIV by -1 overflow: most negative / -1 overflows
  // 32-bit: EDX:EAX = 0xFFFFFFFF:80000000 (-2147483648), ECX=0xFFFFFFFF (-1)
  // quotient would be INT32_MIN / -1 = 2147483648 > INT32_MAX
  add_fault("idiv ecx (INT32_MIN / -1 overflow)", {0xF7, 0xF9},
            {.rax = 0x80000000, .rcx = 0xFFFFFFFF, .rdx = 0xFFFFFFFF}, 0);

  // ---- #UD (vector 6): Invalid opcode ----
  cat = "Exception #UD";

  add_fault("ud2", {0x0F, 0x0B}, {}, 6);

  // UD1 (0F B9): explicit undefined instruction with ModRM
  add_fault("ud1 (0F B9)", {0x0F, 0xB9, 0xC0}, {}, 6);

  // LOCK ADD RAX, RBX: F0 48 01 D8 — register destination, #UD
  add_fault("lock add rax,rbx (reg dest → #UD)", {0xF0, 0x48, 0x01, 0xD8},
            {}, 6);

  // LOCK CMP [RDI], RAX: F0 48 39 07 — CMP doesn't write, #UD even with mem
  add_fault("lock cmp [rdi],rax (CMP not lockable → #UD)", {0xF0, 0x48, 0x39, 0x07},
            {}, 6);

  // LOCK MOV RAX, RBX: F0 48 89 D8 — MOV is not lockable, #UD
  add_fault("lock mov rax,rbx (non-lockable → #UD)", {0xF0, 0x48, 0x89, 0xD8},
            {}, 6);

  // LOCK NOP: F0 90 — NOP is not lockable, #UD
  add_fault("lock nop (non-lockable → #UD)", {0xF0, 0x90},
            {}, 6);

  // VPCLMULQDQ zmm0, zmm1, zmm2, 0 with EVEX.aaa = 001b: the instruction
  // has no opmask operand, so a mask register is #UD (SDM Vol.2A Table 2-42).
  // Hosts without VPCLMULQDQ #UD on the missing feature instead.
  add_fault("vpclmulqdq zmm {k1} (no opmask → #UD)",
            {0x62, 0xF3, 0x75, 0x49, 0x44, 0xC2, 0x00}, {}, 6);

  // VAESENC zmm0, zmm1, zmm2 with EVEX.aaa = 001b: same rule (VAES has no
  // opmask operand), same #UD on hosts without VAES.
  add_fault("vaesenc zmm {k1} (no opmask → #UD)",
            {0x62, 0xF2, 0x75, 0x49, 0xDC, 0xC2}, {}, 6);

  // VLDMXCSR/VSTMXCSR are VEX.LZ with vvvv reserved: VEX.L = 1 and
  // vvvv != 1111b are #UD (SDM LDMXCSR/STMXCSR pages).
  add_fault("vldmxcsr [rdi] with VEX.L=1 (#UD)", {0xC5, 0xFC, 0xAE, 0x17},
            {}, 6);
  add_fault("vstmxcsr [rdi] with vvvv=1110b (#UD)", {0xC5, 0xF0, 0xAE, 0x1F},
            {}, 6);

  // VBROADCASTF32X2 has only 256- and 512-bit forms: EVEX.128 (L'L=00) is #UD.
  add_fault("vbroadcastf32x2 xmm (no 128-bit form → #UD)",
            {0x62, 0xF2, 0x7D, 0x08, 0x19, 0xC1}, {}, 6);

  // ---- #DB (vector 1): Debug exception ----
  cat = "Exception #DB";

  u32 vendor_eax, vendor_ebx, vendor_ecx, vendor_edx;
  __get_cpuid(0, &vendor_eax, &vendor_ebx, &vendor_ecx, &vendor_edx);
  const bool amd_host = (vendor_ebx == 0x68747541);  // "Auth" of AuthenticAMD
  // A completed MOV DR leaves arithmetic flags undefined on Intel (SDM
  // Vol.2B, MOV debug-register entry); AMD preserves them (APM Vol.3).
  const u64 mov_dr_undefined_flags = amd_host ? 0 : FL_ARITH;

  // INT1/ICEBP (F1) is a trap: the pushed RIP is past the instruction and
  // DR6 is not modified.  Both hosts' silicon pushes the next RIP (measured
  // natively through the RIP a SIGTRAP handler sees), but KVM on AMD (SVM)
  // delivers this #DB to the guest with the INT1's own RIP, so the plain
  // case is a hypervisor artifact there and runs on Intel hosts only.
  if (!amd_host)
    add_fault("int1 (F1) trap, RIP past the instruction", {0xF1, 0xF4}, {}, 1);

  // Single-step (RFLAGS.TF = 0x100): TF is sampled before each instruction
  // and the trap is taken after it, with the next RIP pushed and DR6.BS set
  // (SDM Vol.3B §20.3.1.4).  Both RIP and DR6 are compared with the host.
  add_fault("single-step nop", {0x90, 0xF4}, {.rflags = initial_flags() | 0x100}, 1);
  add_fault("single-step jmp (RIP = target)",
            {0xEB, 0x02, 0x90, 0x90, 0xF4}, {.rflags = initial_flags() | 0x100}, 1);
  // MOV SS suppresses its own trap; the following NOP is trapped (§7.8.3).
  add_fault("single-step mov ss; nop (trap after the nop)",
            {0x8E, 0xD0, 0x90, 0xF4}, {.rax = 0x10, .rflags = initial_flags() | 0x100}, 1);
  // The instruction that sets TF is not trapped: PUSH 0x102; POPFQ; NOP; NOP.
  add_fault("single-step popf setting TF (trap after the next nop)",
            {0x68, 0x02, 0x01, 0x00, 0x00, 0x9D, 0x90, 0x90, 0xF4}, {}, 1);
  // INT3 and INT1 clear TF as part of delivery: no single-step trap follows.
  add_fault("single-step int3 (vector 3, no #DB)", {0xCC, 0xF4}, {.rflags = initial_flags() | 0x100}, 3);
  add_fault("single-step int1 (one #DB, DR6.BS clear)", {0xF1, 0xF4}, {.rflags = initial_flags() | 0x100}, 1);
  // A faulting instruction gets no trap.
  add_fault("single-step ud2 (fault, no #DB)", {0x0F, 0x0B}, {.rflags = initial_flags() | 0x100}, 6);
  add_fault("single-step mov dr7", {0x0F, 0x23, 0xF8, 0x90, 0xF4},
            {.rax = 0x400, .rflags = initial_flags() | 0x100}, 1);
  tests.back().rflags_image_ignore = mov_dr_undefined_flags;
  // Probes whose outcome the SDM leaves to the reader; the host decides.
  add_fault("single-step sti; nop (STI shadow and the trap)",
            {0xFB, 0x90, 0xF4}, {.rflags = initial_flags() | 0x100}, -1);
  {
    ArchState s = {.rflags = initial_flags() | 0x100};
    s.dr6 = 0xFFFF0FF3;  // B0/B1 preset: cleared by the trap?
    add_fault("single-step with DR6.B0/B1 preset", {0x90, 0xF4}, s, -1);
  }
  {
    // POPFQ that clears TF while TF was set at its start: trap after it?
    TestCase tc;
    tc.name = "single-step popf clearing TF";
    tc.category = cat;
    tc.code = {0x9D, 0x90, 0xF4};
    tc.initial = {.rsp = DATA_ADDR + 64, .rflags = initial_flags() | 0x100};
    tc.flags_mask = FL_ALL;
    tc.expect_fault = true;
    tc.expected_vector = -1;
    tc.init_data.assign(72, 0);
    tc.init_data[64] = 0x02;  // RFLAGS image with TF clear
    tests.push_back(std::move(tc));
  }

  // Instruction breakpoints (DR7 R/Wn = 00, LENn = 00): a fault before the
  // instruction whose first byte is at DRn, so the pushed RIP is that
  // instruction, DR6 reports Bn, and the pushed RF stays 0 (SDM Vol.3B
  // §20.3.1.1).  A case that must not fault is a normal state comparison.
  auto bp_state = [](int n, u64 addr, u64 dr7_bits) {
    ArchState s = {};
    s.dr[n] = addr;
    s.dr7 = dr7_bits;
    return s;
  };
  auto add_no_fault = [&](const std::string &name, std::vector<u8> code,
                          ArchState init, u64 flags_mask = FL_ALL) {
    tests.push_back({name, cat, std::move(code), init, flags_mask, 0, false});
  };
  add_fault("insn bp DR0 (L0) on the second instruction",
            {0x90, 0x90, 0xF4}, bp_state(0, CODE_ADDR + 1, 0x1), 1);
  add_fault("insn bp DR3 (G3) on the third instruction",
            {0x90, 0x90, 0x90, 0xF4}, bp_state(3, CODE_ADDR + 2, 0x80), 1);
  add_fault("insn bp on the first instruction",
            {0x90, 0xF4}, bp_state(0, CODE_ADDR, 0x1), 1);
  add_no_fault("insn bp address set but DR7 disabled",
               {0x90, 0x90, 0xF4}, bp_state(0, CODE_ADDR + 1, 0x0));
  // The address must be the instruction's first byte, prefixes included:
  // "66 90" at +1 matches at its prefix, not at its opcode byte.
  add_fault("insn bp on a prefix byte (66 90)",
            {0x90, 0x66, 0x90, 0xF4}, bp_state(0, CODE_ADDR + 1, 0x1), 1);
  add_no_fault("insn bp on the opcode byte after a prefix (no match)",
               {0x90, 0x66, 0x90, 0xF4}, bp_state(0, CODE_ADDR + 2, 0x1));
  // The instruction after MOV SS is exempt on Intel, as if RF were set
  // (§7.8.3); AMD Zen 4 takes the breakpoint (both measured natively with
  // a ptrace-armed DR0), and the model follows its vendor profile.  The
  // instruction after that is not exempt anywhere.
  {
    ArchState s = bp_state(0, CODE_ADDR + 2, 0x1); s.rax = 0x10;
    if (amd_host)
      add_fault("insn bp on the instruction after mov ss (AMD: taken)",
                {0x8E, 0xD0, 0x90, 0xF4}, s, 1);
    else
      add_no_fault("insn bp on the instruction after mov ss (Intel: suppressed)",
                   {0x8E, 0xD0, 0x90, 0xF4}, s);
    s.dr[0] = CODE_ADDR + 3;
    add_fault("insn bp two instructions after mov ss",
              {0x8E, 0xD0, 0x90, 0xF4}, s, 1);
  }
  // IRETQ transfers RF from its frame: with RF = 1 in the image the
  // breakpoint on the return target is skipped once; with RF = 0 it fires.
  // Frame: push SS(0x10), RSP, RFLAGS(rbx), CS(0x08), RIP(rax); target at +9.
  {
    std::vector<u8> code = {0x6A, 0x10, 0x54, 0x53, 0x6A, 0x08, 0x50, 0x48, 0xCF, 0x90, 0xF4};
    ArchState s = bp_state(0, CODE_ADDR + 9, 0x1);
    s.rax = CODE_ADDR + 9;
    s.rbx = 0x10002;  // RF set
    add_no_fault("insn bp skipped by IRETQ with RF in the frame", code, s);
    s.rbx = 0x2;
    add_fault("insn bp taken after IRETQ without RF", code, s, 1);
  }
  // A matching but disabled DR1 next to enabled DR0: neither vendor reports
  // B1.  A single-step trap taken before a breakpointed instruction: Intel
  // reports B0 together with BS, AMD reports BS alone; the model follows
  // its vendor profile.
  {
    ArchState s = bp_state(0, CODE_ADDR + 1, 0x1); s.dr[1] = CODE_ADDR + 1;
    add_fault("insn bp with a matching disabled DR1 alongside", {0x90, 0x90, 0xF4}, s, -1);
    ArchState t = bp_state(0, CODE_ADDR + 1, 0x1); t.rflags = initial_flags() | 0x100;
    add_fault("single-step trap before a breakpointed instruction", {0x90, 0x90, 0xF4}, t, -1);
  }

  // Data breakpoints (SDM Vol.3B §20.2.5, §20.3.1.2): R/Wn = 01 for writes,
  // 11 for reads and writes; LENn = 00/01/11/10 for 1/2/4/8 bytes with the
  // low address bits masked.  A trap after the instruction whose access
  // touches any byte of the range, the pushed RIP past the instruction and
  // DR6 reporting Bn.  rdi = DATA_ADDR throughout.
  auto dbp = [&](int n, u64 addr, unsigned rw, unsigned len) {
    ArchState s = {.rdi = DATA_ADDR};
    s.dr[n] = addr;
    s.dr7 = (1ull << (2 * n)) | ((u64)rw << (16 + 4 * n)) | ((u64)len << (18 + 4 * n));
    return s;
  };
  auto dbp_store = [&](int n, u64 addr, unsigned rw, unsigned len) {
    ArchState s = dbp(n, addr, rw, len);
    s.rax = 0;
    return s;
  };
  add_fault("data bp write LEN=1 hit by mov [rdi],al", {0x88, 0x07, 0x90, 0xF4}, dbp_store(0, DATA_ADDR, 1, 0), 1);
  add_fault("data bp R/W LEN=1 hit by mov al,[rdi]", {0x8A, 0x07, 0x90, 0xF4}, dbp(0, DATA_ADDR, 3, 0), 1);
  add_no_fault("data bp write-only not hit by a read", {0x8A, 0x07, 0x90, 0xF4}, dbp(0, DATA_ADDR, 1, 0));
  add_no_fault("data bp LEN=1 at +1 not hit by a byte write at +0", {0x88, 0x07, 0x90, 0xF4}, dbp_store(0, DATA_ADDR + 1, 1, 0));
  add_fault("data bp LEN=1 at +3 hit by a dword write at +0", {0x89, 0x07, 0x90, 0xF4}, dbp_store(0, DATA_ADDR + 3, 1, 0), 1);
  add_no_fault("data bp LEN=1 at +3 not hit by a word write at +0", {0x66, 0x89, 0x07, 0x90, 0xF4}, dbp_store(0, DATA_ADDR + 3, 1, 0));
  add_fault("data bp LEN=4 at +4 hit by a byte write at +7", {0x88, 0x47, 0x07, 0x90, 0xF4}, dbp_store(0, DATA_ADDR + 4, 1, 3), 1);
  add_no_fault("data bp LEN=4 at +4 not hit by a byte write at +8", {0x88, 0x47, 0x08, 0x90, 0xF4}, dbp_store(0, DATA_ADDR + 4, 1, 3));
  add_fault("data bp LEN=4 at unaligned +6 masks to +4: hit by a write at +4", {0x88, 0x47, 0x04, 0x90, 0xF4}, dbp_store(0, DATA_ADDR + 6, 1, 3), 1);
  add_fault("data bp LEN=8 at +8 hit by a byte write at +15", {0x88, 0x47, 0x0F, 0x90, 0xF4}, dbp_store(0, DATA_ADDR + 8, 1, 2), 1);
  add_no_fault("data bp LEN=8 at +8 not hit by a byte write at +16", {0x88, 0x47, 0x10, 0x90, 0xF4}, dbp_store(0, DATA_ADDR + 8, 1, 2));
  {
    ArchState s = dbp_store(0, DATA_ADDR, 1, 0);
    s.dr[1] = DATA_ADDR + 1; s.dr7 |= (1ull << 2) | (1ull << 20);
    add_fault("data bp DR0 and DR1 hit by one word write (B0 and B1)", {0x66, 0x89, 0x07, 0x90, 0xF4}, s, 1);
  }
  {
    ArchState s = bp_state(0, STACK_TOP - 8, 0x1 | (1ULL << 16) | (2ULL << 18));
    s.rax = 0;
    add_fault("data bp LEN=8 on the stack slot hit by push rax", {0x50, 0x90, 0xF4}, s, 1);
  }
  {
    ArchState s = dbp_store(0, DATA_ADDR, 1, 0); s.rflags = initial_flags() | 0x100;
    add_fault("data bp with single-step: BS and B0 together", {0x88, 0x07, 0x90, 0xF4}, s, 1);
  }
  {
    // A faulting instruction loses its data breakpoint: divb [rdi] with
    // [rdi] = 0 reads the divisor (a hit) and then raises #DE; DR6 stays.
    TestCase tc;
    tc.name = "data bp lost when the instruction faults (divb [rdi] by zero)";
    tc.category = cat;
    tc.code = {0xF6, 0x37};
    tc.initial = dbp(0, DATA_ADDR, 3, 0);
    tc.initial.rax = 1;
    tc.flags_mask = FL_ALL;
    tc.expect_fault = true;
    tc.expected_vector = 0;
    tc.init_data.assign(16, 0);
    tests.push_back(std::move(tc));
  }
  {
    // MOV SS from memory hitting a read breakpoint: the trap is delivered
    // after the following instruction (§20.3.1.2).
    TestCase tc;
    tc.name = "data bp on mov ss,[rdi] delivered after the next instruction";
    tc.category = cat;
    tc.code = {0x8E, 0x17, 0x90, 0xF4};
    tc.initial = dbp(0, DATA_ADDR, 3, 0);
    tc.flags_mask = FL_ALL;
    tc.expect_fault = true;
    tc.expected_vector = 1;
    tc.init_data = {0x10, 0x00};  // SS selector
    tests.push_back(std::move(tc));
  }
  // Repeated string instructions: the trap follows the iteration that hit
  // (or each iteration under TF), RIP back at the instruction with RF = 1
  // in the image (§20.3.1.1), unless the processor batches iterations
  // (fast strings, §20.3.1.2): probes.
  {
    ArchState s = dbp(0, DATA_ADDR + 2, 1, 0); s.rcx = 4; s.rax = 0x41;
    add_fault("data bp inside rep stosb (trap after the hitting iteration)", {0xF3, 0xAA, 0x90, 0xF4}, s, -1);
    ArchState t = {.rax = 0, .rcx = 3, .rdi = DATA_ADDR, .rflags = initial_flags() | 0x100};
    add_fault("single-step of rep stosb (trap after the first iteration, RF=1)", {0xF3, 0xAA, 0x90, 0xF4}, t, -1);
  }

  // General detect (DR7.GD, §20.3.1.3): any MOV DR raises #DB before the
  // access, a fault with DR6.BD, and the processor clears GD on the way to
  // the handler (DR7 is compared).  The SDM's rule (§20.3.1.1) puts RF = 1
  // in the pushed image of this fault, but under KVM every MOV DR is a VM
  // exit that leaves the guest's RF at 0 (Vol.3C §30.3.3) and the #DB is
  // then injected, so both hosts show RF = 0 here; the bit is not compared.
  {
    auto add_gd = [&](const std::string &name, std::vector<u8> code, ArchState init) {
      TestCase tc;
      tc.name = name;
      tc.category = cat;
      tc.code = std::move(code);
      tc.initial = init;
      tc.flags_mask = FL_ALL;
      tc.expect_fault = true;
      tc.expected_vector = 1;
      tc.rflags_image_ignore = 0x10000;  // RF
      tests.push_back(std::move(tc));
    };
    ArchState s = {}; s.dr7 = 0x2400;
    add_gd("general detect: mov rax,dr0 with DR7.GD", {0x0F, 0x21, 0xC0, 0xF4}, s);
    s.rax = 0x400;
    add_gd("general detect: mov dr7,rax with DR7.GD", {0x0F, 0x23, 0xF8, 0xF4}, s);
  }
  // MOV to DR6/DR7 in 64-bit mode: a 1 in bits 63:32 is #GP(0) (§20.2.6);
  // otherwise the reserved bits read back as fixed values (compared in the
  // final state).
  {
    ArchState s = {};
    s.rax = 0x100000400ull;
    add_fault("mov dr7,rax with bit 32 set (#GP)", {0x0F, 0x23, 0xF8, 0xF4}, s, 13);
    add_fault("mov dr6,rax with bit 32 set (#GP)", {0x0F, 0x23, 0xF0, 0xF4}, s, 13);
    s.rax = 0x1400;  // bits 10 and 12: bit 10 reads as 1 regardless, bit 12 is dropped
    add_no_fault("mov dr7,rax with reserved bits 10 and 12 (reads back 0x400)",
                 {0x0F, 0x23, 0xF8, 0xF4}, s, FL_ALL & ~mov_dr_undefined_flags);
    s.rax = 0xFFFFFFFF;  // low 32 all ones: the status bits are set, the rest fixed
    add_no_fault("mov dr6,rax with all low bits set", {0x0F, 0x23, 0xF0, 0xF4},
                 s, FL_ALL & ~mov_dr_undefined_flags);
    s.rax = 0;
    add_no_fault("mov dr6,rax with zero (reserved ones stay)",
                 {0x0F, 0x23, 0xF0, 0xF4}, s, FL_ALL & ~mov_dr_undefined_flags);
  }

  // ---- #GP (vector 13): General protection fault ----
  cat = "Exception #GP";

  // SSE MOVAPS/MOVAPD load unaligned
  add_fault("movaps xmm0,[rdi] load (unaligned → #GP)", {0x0F, 0x28, 0x07},
            {.rdi = DATA_ADDR + 1}, 13);
  add_fault("movapd xmm0,[rdi] load (unaligned → #GP)", {0x66, 0x0F, 0x28, 0x07},
            {.rdi = DATA_ADDR + 3}, 13);

  // SSE MOVAPS/MOVAPD store unaligned
  // MOVAPS [RDI], XMM0: 0F 29 07
  add_fault("movaps [rdi],xmm0 store (unaligned → #GP)", {0x0F, 0x29, 0x07},
            {.rdi = DATA_ADDR + 1}, 13);

  // MOVAPD [RDI], XMM0: 66 0F 29 07
  add_fault("movapd [rdi],xmm0 store (unaligned → #GP)", {0x66, 0x0F, 0x29, 0x07},
            {.rdi = DATA_ADDR + 5}, 13);

  // VEX VMOVAPS load unaligned (128-bit)
  // VMOVAPS XMM0, [RDI]: C5 F8 28 07
  add_fault("vmovaps xmm0,[rdi] load (unaligned → #GP)", {0xC5, 0xF8, 0x28, 0x07},
            {.rdi = DATA_ADDR + 1}, 13);

  // VEX VMOVAPS store unaligned (128-bit)
  // VMOVAPS [RDI], XMM0: C5 F8 29 07
  add_fault("vmovaps [rdi],xmm0 store (unaligned → #GP)", {0xC5, 0xF8, 0x29, 0x07},
            {.rdi = DATA_ADDR + 7}, 13);

  // VEX VMOVAPD load unaligned (128-bit)
  // VMOVAPD XMM0, [RDI]: C5 F9 28 07
  add_fault("vmovapd xmm0,[rdi] load (unaligned → #GP)", {0xC5, 0xF9, 0x28, 0x07},
            {.rdi = DATA_ADDR + 2}, 13);

  // VEX VMOVAPS load unaligned (256-bit, 32-byte alignment required)
  // VMOVAPS YMM0, [RDI]: C5 FC 28 07 (VEX.256.NP)
  add_fault("vmovaps ymm0,[rdi] load (16-aligned, not 32 → #GP)", {0xC5, 0xFC, 0x28, 0x07},
            {.rdi = DATA_ADDR + 16}, 13);  // 16-byte aligned but not 32-byte aligned

  // VEX VMOVAPD store unaligned (128-bit)
  // VMOVAPD [RDI], XMM0: C5 F9 29 07
  add_fault("vmovapd [rdi],xmm0 store (unaligned → #GP)", {0xC5, 0xF9, 0x29, 0x07},
            {.rdi = DATA_ADDR + 3}, 13);

  // VEX VMOVAPD load unaligned (256-bit, 32-byte alignment required)
  // VMOVAPD YMM0, [RDI]: C5 FD 28 07
  add_fault("vmovapd ymm0,[rdi] load (16-aligned, not 32 → #GP)", {0xC5, 0xFD, 0x28, 0x07},
            {.rdi = DATA_ADDR + 16}, 13);  // 16-byte aligned but not 32-byte aligned

  // VEX VMOVAPS store unaligned (256-bit)
  // VMOVAPS [RDI], YMM0: C5 FC 29 07
  add_fault("vmovaps [rdi],ymm0 store (16-aligned, not 32 → #GP)", {0xC5, 0xFC, 0x29, 0x07},
            {.rdi = DATA_ADDR + 16}, 13);

  // VEX VMOVAPD store unaligned (256-bit)
  // VMOVAPD [RDI], YMM0: C5 FD 29 07
  add_fault("vmovapd [rdi],ymm0 store (16-aligned, not 32 → #GP)", {0xC5, 0xFD, 0x29, 0x07},
            {.rdi = DATA_ADDR + 16}, 13);

  // VEX VMOVDQA load unaligned (128-bit)
  // VMOVDQA XMM0, [RDI]: C5 F9 6F 07
  add_fault("vmovdqa xmm0,[rdi] load (unaligned → #GP)", {0xC5, 0xF9, 0x6F, 0x07},
            {.rdi = DATA_ADDR + 1}, 13);

  // VEX VMOVDQA store unaligned (128-bit)
  // VMOVDQA [RDI], XMM0: C5 F9 7F 07
  add_fault("vmovdqa [rdi],xmm0 store (unaligned → #GP)", {0xC5, 0xF9, 0x7F, 0x07},
            {.rdi = DATA_ADDR + 1}, 13);

  // VEX VMOVNTDQ store unaligned (128-bit)
  // VMOVNTDQ [RDI], XMM0: C5 F9 E7 07
  add_fault("vmovntdq [rdi],xmm0 store (unaligned → #GP)", {0xC5, 0xF9, 0xE7, 0x07},
            {.rdi = DATA_ADDR + 1}, 13);

  // VEX VMOVNTPS store unaligned (128-bit)
  // VMOVNTPS [RDI], XMM0: C5 F8 2B 07
  add_fault("vmovntps [rdi],xmm0 store (unaligned → #GP)", {0xC5, 0xF8, 0x2B, 0x07},
            {.rdi = DATA_ADDR + 1}, 13);

  // VEX VMOVSS/VMOVSD memory forms: vvvv must be 1111b, else #UD
  cat = "Exception #UD";

  // VMOVSS XMM0, [RDI] with vvvv=1110 (should be 1111): C5 F2 10 07
  // Normal: C5 FA 10 07 (vvvv=1111). F2 = R=1,vvvv=1110,L=0,pp=10.
  add_fault("vmovss xmm,m32 vvvv!=1111 → #UD", {0xC5, 0xF2, 0x10, 0x07},
            {}, 6);

  // VMOVSD XMM0, [RDI] with vvvv=1110: C5 F3 10 07
  // Normal: C5 FB 10 07 (vvvv=1111, pp=11=F2). F3 = R=1,vvvv=1110,L=0,pp=11.
  add_fault("vmovsd xmm,m64 vvvv!=1111 → #UD", {0xC5, 0xF3, 0x10, 0x07},
            {}, 6);

  // VMOVSS [RDI], XMM0 with vvvv=1110: C5 F2 11 07
  add_fault("vmovss m32,xmm vvvv!=1111 → #UD", {0xC5, 0xF2, 0x11, 0x07},
            {}, 6);

  // VMOVSD [RDI], XMM0 with vvvv=1110: C5 F3 11 07
  add_fault("vmovsd m64,xmm vvvv!=1111 → #UD", {0xC5, 0xF3, 0x11, 0x07},
            {}, 6);

  // ---- More #UD tests: LOCK on 2-byte opcodes ----
  cat = "Exception #UD";

  // LOCK MOVZX EAX, BL: F0 0F B6 C3 — MOVZX not lockable, #UD
  add_fault("lock movzx eax,bl (2-byte non-lockable → #UD)", {0xF0, 0x0F, 0xB6, 0xC3},
            {}, 6);

  // LOCK BSF EAX, EBX: F0 0F BC C3 — BSF not lockable, #UD
  add_fault("lock bsf eax,ebx (2-byte non-lockable → #UD)", {0xF0, 0x0F, 0xBC, 0xC3},
            {}, 6);

  // LOCK CMPXCHG EAX, EBX: F0 0F B1 D8 — reg dest on lockable 2-byte, #UD
  // CMPXCHG r/m, r: ModRM D8 = 11 011 000 = reg, reg=EBX, rm=EAX
  add_fault("lock cmpxchg eax,ebx (reg dest → #UD)", {0xF0, 0x0F, 0xB1, 0xD8},
            {}, 6);

  // LOCK XADD EAX, EBX: F0 0F C1 D8 — reg dest on lockable 2-byte, #UD
  add_fault("lock xadd eax,ebx (reg dest → #UD)", {0xF0, 0x0F, 0xC1, 0xD8},
            {}, 6);

  // LOCK INC EAX: F0 FF C0 — INC with register dest, #UD
  // FF C0 = ModRM 11 000 000 = /0, rm=EAX (register)
  add_fault("lock inc eax (reg dest → #UD)", {0xF0, 0xFF, 0xC0},
            {}, 6);

  // LOCK NEG EAX: F0 F7 D8 — NEG with register dest, #UD
  // F7 D8 = ModRM 11 011 000 = /3, rm=EAX (register)
  add_fault("lock neg eax (reg dest → #UD)", {0xF0, 0xF7, 0xD8},
            {}, 6);

  // LOCK MUL EAX: F0 F7 E0 — MUL (/4) not lockable even as Group 3, #UD
  // F7 E0 = ModRM 11 100 000 = /4, rm=EAX
  add_fault("lock mul eax (MUL not lockable → #UD)", {0xF0, 0xF7, 0xE0},
            {}, 6);

  // LOCK DIV ECX: F0 F7 F1 — DIV (/6) not lockable, #UD
  add_fault("lock div ecx (DIV not lockable → #UD)", {0xF0, 0xF7, 0xF1},
            {}, 6);

  // LOCK PUSH RAX: F0 50 — PUSH not lockable, #UD
  add_fault("lock push rax (non-lockable → #UD)", {0xF0, 0x50},
            {}, 6);

  // ---- VEX.L=1 on 128-bit-only instructions → #UD ----
  // VEX 2-byte prefix byte2: R̃ vvvv L pp
  // L=0: F8(NP), F9(66), FA(F3), FB(F2)
  // L=1: FC(NP), FD(66), FE(F3), FF(F2)

  // VPINSRW xmm0,xmm0,ecx,0 with VEX.L=1: C5 FD C4 C1 00
  // Normal (L=0): C5 F9 C4 C1 00
  add_fault("vpinsrw L=1 (128-bit only → #UD)", {0xC5, 0xFD, 0xC4, 0xC1, 0x00},
            {}, 6);

  {
    // VPEXTRW eax,xmm1,0 with VEX.L=1: C5 FD C5 C1 00
    // Normal (L=0): C5 F9 C5 C1 00
    ArchState s = {};
    s.xmm[1] = xmm_from_u64(0x0011223344556677, 0x8899AABBCCDDEEFF);
    add_fault("vpextrw L=1 (128-bit only → #UD)", {0xC5, 0xFD, 0xC5, 0xC1, 0x00},
        with_vector_inputs(s, 0x0), 6);
  }

  // VMOVD xmm0,ecx with VEX.L=1: C5 FD 6E C1
  // Normal (L=0): C5 F9 6E C1
  add_fault("vmovd xmm,r32 L=1 (128-bit only → #UD)", {0xC5, 0xFD, 0x6E, 0xC1},
            {}, 6);

  {
    // VMOVD ecx,xmm0 with VEX.L=1: C5 FD 7E C1
    // Normal (L=0): C5 F9 7E C1
    ArchState s = {};
    s.xmm[0] = xmm_from_u64(0x12345678, 0);
    add_fault("vmovd r32,xmm L=1 (128-bit only → #UD)", {0xC5, 0xFD, 0x7E, 0xC1},
        with_vector_inputs(s, 0x0), 6);
  }

  // NOTE: Scalar instructions (VUCOMISS, VCVTSI2SS, VCVTTSS2SI, etc.)
  // do NOT #UD with VEX.L=1 on real hardware — the L bit is ignored.

  // ---- VEX.vvvv reserved (must be 1111b) → #UD ----
  // VEX byte2: R̃ vvvv L pp
  // vvvv=1111 → reserved OK (byte2 upper nibble F)
  // vvvv=1110 → register 1, not reserved (byte2 upper nibble E + R̃ bit)
  // C5 F8 = R̃=1 vvvv=1111 L=0 pp=00(NP)  → valid
  // C5 F0 = R̃=1 vvvv=1110 L=0 pp=00(NP)  → vvvv not reserved
  // C5 F1 = R̃=1 vvvv=1110 L=0 pp=01(66)  → vvvv not reserved

  // VMOVAPS xmm0,[mem] with vvvv!=1111: C5 F0 28 07 (via [rdi])
  add_fault("vmovaps load vvvv!=0 → #UD", {0xC5, 0xF0, 0x28, 0x07},
            {}, 6);

  // VMOVAPD xmm0,[mem] with vvvv!=1111: C5 F1 28 07
  add_fault("vmovapd load vvvv!=0 → #UD", {0xC5, 0xF1, 0x28, 0x07},
            {}, 6);

  // VMOVAPS [mem],xmm0 with vvvv!=1111: C5 F0 29 07
  add_fault("vmovaps store vvvv!=0 → #UD", {0xC5, 0xF0, 0x29, 0x07},
            {}, 6);

  // VMOVDQA xmm0,[mem] with vvvv!=1111: C5 F1 6F 07
  add_fault("vmovdqa load vvvv!=0 → #UD", {0xC5, 0xF1, 0x6F, 0x07},
            {}, 6);

  // VMOVDQU xmm0,[mem] with vvvv!=1111: C5 F2 6F 07 (pp=F3)
  // C5 FA = R̃=1 vvvv=1111 L=0 pp=10(F3); C5 F2 = vvvv=1110
  add_fault("vmovdqu load vvvv!=0 → #UD", {0xC5, 0xF2, 0x6F, 0x07},
            {}, 6);

  // VMOVDQA [mem],xmm0 with vvvv!=1111: C5 F1 7F 07
  add_fault("vmovdqa store vvvv!=0 → #UD", {0xC5, 0xF1, 0x7F, 0x07},
            {}, 6);

  // VMOVDQU [mem],xmm0 with vvvv!=1111: C5 F2 7F 07
  add_fault("vmovdqu store vvvv!=0 → #UD", {0xC5, 0xF2, 0x7F, 0x07},
            {}, 6);

  // VUCOMISS xmm0,xmm1 with vvvv!=1111: C5 F0 2E C1
  add_fault("vucomiss vvvv!=0 → #UD", {0xC5, 0xF0, 0x2E, 0xC1},
            {}, 6);

  // VUCOMISD xmm0,xmm1 with vvvv!=1111: C5 F1 2E C1
  add_fault("vucomisd vvvv!=0 → #UD", {0xC5, 0xF1, 0x2E, 0xC1},
            {}, 6);

  // VCOMISS xmm0,xmm1 with vvvv!=1111: C5 F0 2F C1
  add_fault("vcomiss vvvv!=0 → #UD", {0xC5, 0xF0, 0x2F, 0xC1},
            {}, 6);

  // VCOMISD xmm0,xmm1 with vvvv!=1111: C5 F1 2F C1
  add_fault("vcomisd vvvv!=0 → #UD", {0xC5, 0xF1, 0x2F, 0xC1},
            {}, 6);

  // VCVTPS2PD xmm0,xmm1 with vvvv!=1111: C5 F0 5A C1
  add_fault("vcvtps2pd vvvv!=0 → #UD", {0xC5, 0xF0, 0x5A, 0xC1},
            {}, 6);

  // VCVTPD2PS xmm0,xmm1 with vvvv!=1111: C5 F1 5A C1
  add_fault("vcvtpd2ps vvvv!=0 → #UD", {0xC5, 0xF1, 0x5A, 0xC1},
            {}, 6);

  // VZEROUPPER with vvvv!=1111: C5 F0 77
  // Normal: C5 F8 77
  add_fault("vzeroupper vvvv!=0 → #UD", {0xC5, 0xF0, 0x77},
            {}, 6);

  // VBROADCASTSS xmm0,[mem] with vvvv!=1111: C4 E2 F1 18 07
  // 3-byte VEX: C4 E2 [W vvvv L pp]
  // Normal: C4 E2 79 18 07 (W=0 vvvv=1111 L=0 pp=01)
  // Bad:    C4 E2 71 18 07 (W=0 vvvv=1110 L=0 pp=01)
  add_fault("vbroadcastss vvvv!=0 → #UD", {0xC4, 0xE2, 0x71, 0x18, 0x07},
            {}, 6);

  // VMOVUPS xmm0,[mem] with vvvv!=1111: C5 F0 10 07
  // Normal: C5 F8 10 07
  add_fault("vmovups load vvvv!=0 → #UD", {0xC5, 0xF0, 0x10, 0x07},
            {}, 6);

  // VMOVUPS [mem],xmm0 with vvvv!=1111: C5 F0 11 07
  add_fault("vmovups store vvvv!=0 → #UD", {0xC5, 0xF0, 0x11, 0x07},
            {}, 6);

  // VCVTDQ2PS xmm0,xmm1 with vvvv!=1111: C5 F0 5B C1
  // Normal: C5 F8 5B C1 (NP = VCVTDQ2PS)
  add_fault("vcvtdq2ps vvvv!=0 → #UD", {0xC5, 0xF0, 0x5B, 0xC1},
            {}, 6);

  // VCVTPS2DQ xmm0,xmm1 with vvvv!=1111: C5 F1 5B C1
  // Normal: C5 F9 5B C1 (66 = VCVTPS2DQ)
  add_fault("vcvtps2dq vvvv!=0 → #UD", {0xC5, 0xF1, 0x5B, 0xC1},
            {}, 6);

  // VBROADCASTSD ymm0,[mem] with vvvv!=1111: C4 E2 71 19 07
  // Normal: C4 E2 7D 19 07 (W=0 vvvv=1111 L=1 pp=01)
  // Bad:    C4 E2 75 19 07 (W=0 vvvv=1110 L=1 pp=01)
  add_fault("vbroadcastsd vvvv!=0 → #UD", {0xC4, 0xE2, 0x75, 0x19, 0x07},
            {}, 6);

  // VPBROADCASTD xmm0,xmm1 with vvvv!=1111: C4 E2 71 58 C1
  // Normal: C4 E2 79 58 C1 (W=0 vvvv=1111 L=0 pp=01)
  add_fault("vpbroadcastd vvvv!=0 → #UD", {0xC4, 0xE2, 0x71, 0x58, 0xC1},
            {}, 6);

  // VCVTPH2PS xmm0,xmm1 with vvvv!=1111: C4 E2 71 13 C1
  // Normal: C4 E2 79 13 C1 (W=0 vvvv=1111 L=0 pp=01)
  add_fault("vcvtph2ps vvvv!=0 → #UD", {0xC4, 0xE2, 0x71, 0x13, 0xC1},
            {}, 6);

  // ---- Memory-only instructions with register form → #UD ----

  // VBROADCASTF128 ymm0,xmm0 (register form): C4 E2 7D 1A C0
  // 3-byte VEX: C4 [R̃XB=E2] [W=0 vvvv=1111 L=1 pp=01 = 7D]
  // ModRM C0 = mod=11 (reg), reg=0, rm=0
  add_fault("vbroadcastf128 reg form → #UD", {0xC4, 0xE2, 0x7D, 0x1A, 0xC0},
            {}, 6);

  // VBROADCASTSD xmm0,xmm0 (VEX.128, L=0): C4 E2 79 19 C0
  // VBROADCASTSD requires VEX.256 (L=1); L=0 → #UD
  add_fault("vbroadcastsd L=0 (256-only → #UD)", {0xC4, 0xE2, 0x79, 0x19, 0xC0},
            {}, 6);

  // VEXTRACTF128 xmm0,xmm1,0 with VEX.L=0: C4 E3 79 19 C8 00
  // 3-byte VEX: C4 [R̃XB=E3] [W=0 vvvv=1111 L=0 pp=01 = 79]
  // VEXTRACTF128 requires VEX.256 (L=1); L=0 → #UD
  add_fault("vextractf128 L=0 (256-only → #UD)", {0xC4, 0xE3, 0x79, 0x19, 0xC8, 0x00},
            {}, 6);

  // VINSERTF128 xmm0,xmm0,xmm1,0 with VEX.L=0: C4 E3 79 18 C1 00
  // VINSERTF128 requires VEX.256 (L=1); L=0 → #UD
  add_fault("vinsertf128 L=0 (256-only → #UD)", {0xC4, 0xE3, 0x79, 0x18, 0xC1, 0x00},
            {}, 6);

  // ---- Instruction length limit (>15 bytes → #GP(0)) ----
  cat = "Exception #GP";

  // 15 redundant 66 prefixes + NOP (0x90) = 16 bytes total → #GP(0)
  add_fault("16-byte insn (15x 66 + NOP) → #GP",
            {0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66,
             0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x90},
            {}, 13);

  // 14x 66 + 3-byte NOP (0F 1F 00) = 17 bytes → #GP(0)
  add_fault("17-byte insn (14x 66 + 3-byte NOP) → #GP",
            {0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x66,
             0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x0F, 0x1F, 0x00},
            {}, 13);

  // 15x F3 + 90 = 16 bytes → #GP(0)
  add_fault("16-byte insn (15x F3 + NOP) → #GP",
            {0xF3, 0xF3, 0xF3, 0xF3, 0xF3, 0xF3, 0xF3, 0xF3,
             0xF3, 0xF3, 0xF3, 0xF3, 0xF3, 0xF3, 0xF3, 0x90},
            {}, 13);

  // Note: INVPCID descriptor validation #GP tests are not possible via KVM
  // because KVM intercepts INVPCID (VM exit) and emulates it without
  // checking reserved bits or canonical addresses. The Sail model does
  // validate these per the SDM.

  // ---- #PF (vector 14): page faults beyond the identity-mapped 2MB ----
  //
  // The guest maps only the first 2MB; any access at or above 0x200000
  // takes a not-present #PF.  These are the suite's first tests that
  // compare the page-fault path itself — vector, error code (R/W and
  // I/D bits), and CR2 — rather than avoiding it.  enable_paging gives
  // the Sail model the same identity mapping the KVM guest always has.
  cat = "Exception #PF";
  auto add_pf = [&](const std::string &name, std::vector<u8> code,
                    ArchState init) {
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = std::move(code);
    tc.initial = init;
    tc.flags_mask = FL_ALL;
    tc.expect_fault = true;
    tc.expected_vector = 14;
    tc.enable_paging = true;
    tests.push_back(std::move(tc));
  };

  {
    ArchState pf = {};

    // Read and write of an unmapped address: error code P=0, W per access
    pf.rbx = 0x300000;
    add_pf("pf read [0x300000]", {0x48, 0x8B, 0x03}, pf);   // mov rax,[rbx]
    ArchState store = pf; store.rax = 0;
    add_pf("pf write [0x300000]", {0x48, 0x89, 0x03}, store);  // mov [rbx],rax

    // First unmapped byte
    pf.rbx = 0x200000;
    add_pf("pf read first unmapped byte", {0x48, 0x8B, 0x03}, pf);

    // 8-byte read straddling the mapping boundary: the fault is on the
    // second page, so CR2 must point into the unmapped page
    pf.rbx = 0x1FFFFC;
    add_pf("pf read straddling 2MB boundary", {0x48, 0x8B, 0x03}, pf);

    // Instruction fetch from an unmapped page
    pf.rbx = 0x400000;
    add_pf("pf ifetch jmp 0x400000", {0xFF, 0xE3}, pf);     // jmp rbx
  }
}

// WAITPKG: TPAUSE (66 0F AE /6), UMWAIT (F2 0F AE /6), UMONITOR (F3 0F AE /6),
// all with ModRM.mod = 11, and the IA32_UMWAIT_CONTROL MSR (E1H).
// Constructed only where the host has WAITPKG (CPUID.(7,0):ECX[5]); run
// against an Intel Xeon Platinum 8562Y+ (Emerald Rapids) under KVM, where
// the guest executes them natively ("enable user wait and pause") and its
// IA32_UMWAIT_CONTROL starts at 0.
//
// A wait ends at its deadline: EDX:EAX, or the OS limit IA32_UMWAIT_CONTROL
// [31:2] TSC quanta from now when that is earlier, in which case CF is set.
// A deadline of 0 has passed, one of 2^64 - 1 never comes, so the cases use
// those two and an OS limit of 0x1000 cycles (a microsecond) to make the
// waits deterministic and short; the limit is written and then restored to
// 0 inside the code sequence, because the guest's MSR outlives a test.

#include "kvm-harness.h"
#include <cpuid.h>

namespace {

// mov ecx, 0xE1; mov eax, lo; xor edx, edx; wrmsr
std::vector<u8> wrmsr_umwait_control(u32 lo) {
  return {0xB9, 0xE1, 0x00, 0x00, 0x00,
          0xB8, u8(lo), u8(lo >> 8), u8(lo >> 16), u8(lo >> 24),
          0x31, 0xD2,
          0x0F, 0x30};
}
// mov eax, lo; mov edx, hi  (the deadline)
std::vector<u8> deadline(u32 lo, u32 hi) {
  return {0xB8, u8(lo), u8(lo >> 8), u8(lo >> 16), u8(lo >> 24),
          0xBA, u8(hi), u8(hi >> 8), u8(hi >> 16), u8(hi >> 24)};
}
const std::vector<u8> TPAUSE_EBX  = {0x66, 0x0F, 0xAE, 0xF3};        // tpause ebx
const std::vector<u8> UMWAIT_EBX  = {0xF2, 0x0F, 0xAE, 0xF3};        // umwait ebx
const std::vector<u8> UMONITOR_RDI = {0xF3, 0x0F, 0xAE, 0xF7};       // umonitor rdi

std::vector<u8> cat(std::initializer_list<std::vector<u8>> parts) {
  std::vector<u8> v;
  for (const auto &p : parts) v.insert(v.end(), p.begin(), p.end());
  return v;
}

}  // namespace

void add_waitpkg_tests(std::vector<TestCase> &tests) {
  u32 a7, b7, c7, d7;
  __cpuid_count(7, 0, a7, b7, c7, d7);
  if (!(c7 & (1u << 5))) return;  // no WAITPKG

  const std::string cat_name = "WAITPKG";
  // rbx: the control register operand (bit 0: C0.1); rdi: the monitor
  // address; rsi: a second value the sequences leave alone.
  const ArchState regs = {.rbx = 0, .rsi = 0x5555555555555555, .rdi = DATA_ADDR};

  // init replaces regs where a case needs other register values.
  auto add = [&](const std::string &name, std::vector<u8> code, const ArchState *init = nullptr) {
    TestCase tc;
    tc.name = name;
    tc.category = cat_name;
    tc.code = std::move(code);
    tc.initial = init ? *init : regs;
    tc.flags_mask = FL_ALL;
    tests.push_back(std::move(tc));
  };
  auto add_fault = [&](const std::string &name, std::vector<u8> code, int vec,
                       const ArchState *init = nullptr) {
    TestCase tc;
    tc.name = name;
    tc.category = cat_name;
    tc.code = std::move(code);
    tc.initial = init ? *init : regs;
    tc.flags_mask = FL_ALL;
    tc.expect_fault = true;
    tc.expected_vector = vec;
    tests.push_back(std::move(tc));
  };

  // A deadline in the past: no wait, CF = 0, the other arithmetic flags cleared.
  add("tpause ebx (C0.2), deadline 0", cat({deadline(0, 0), TPAUSE_EBX}));
  {
    ArchState r = regs; r.rbx = 1;
    add("tpause ebx (C0.1), deadline 0", cat({deadline(0, 0), TPAUSE_EBX}), &r);
  }
  {
    ArchState r = regs; r.r8 = 0;
    add("tpause r8d (REX.B), deadline 0", cat({deadline(0, 0), {0x66, 0x41, 0x0F, 0xAE, 0xF0}}), &r);
  }
  add("umwait ebx without umonitor, deadline 0", cat({deadline(0, 0), UMWAIT_EBX}));
  add("umonitor rdi; umwait ebx, deadline 0", cat({deadline(0, 0), UMONITOR_RDI, UMWAIT_EBX}));
  // A deadline that never comes with an OS limit of 0x1000 cycles: the
  // limit ends the wait, CF = 1.  The MSR is restored afterwards.
  add("wrmsr UMWAIT_CONTROL=0x1000; tpause ebx, deadline -1 (CF=1); wrmsr 0",
      cat({wrmsr_umwait_control(0x1000), deadline(~0u, ~0u), TPAUSE_EBX, wrmsr_umwait_control(0)}));
  add("wrmsr UMWAIT_CONTROL=0x1000; umonitor rdi; umwait ebx, deadline -1 (CF=1); wrmsr 0",
      cat({wrmsr_umwait_control(0x1000), UMONITOR_RDI, deadline(~0u, ~0u), UMWAIT_EBX,
           wrmsr_umwait_control(0)}));
  // Without an armed monitor UMWAIT does not wait: TSC < deadline, CF = 0.
  add("wrmsr UMWAIT_CONTROL=0x1000; umwait ebx without umonitor, deadline -1 (CF=0); wrmsr 0",
      cat({wrmsr_umwait_control(0x1000), deadline(~0u, ~0u), UMWAIT_EBX, wrmsr_umwait_control(0)}));
  // The monitor is consumed by UMWAIT: a second UMWAIT does not wait.
  add("umonitor; umwait (limit) twice: second has CF=0",
      cat({wrmsr_umwait_control(0x1000), UMONITOR_RDI, deadline(~0u, ~0u), UMWAIT_EBX, UMWAIT_EBX,
           wrmsr_umwait_control(0)}));
  // A deadline before the OS limit: CF = 0 (the instruction's own deadline).
  add("wrmsr UMWAIT_CONTROL=0x1000; tpause ebx, deadline 0 (CF=0); wrmsr 0",
      cat({wrmsr_umwait_control(0x1000), deadline(0, 0), TPAUSE_EBX, wrmsr_umwait_control(0)}));
  // UMONITOR with a 67H prefix takes edi; with a segment override, that segment.
  add("umonitor edi (67H); umwait, deadline 0",
      cat({deadline(0, 0), {0x67, 0xF3, 0x0F, 0xAE, 0xF7}, UMWAIT_EBX}));
  add("fs umonitor rdi; umwait, deadline 0",
      cat({deadline(0, 0), {0x64, 0xF3, 0x0F, 0xAE, 0xF7}, UMWAIT_EBX}));
  // The MSR: reset value 0, readable and writable.
  {
    ArchState r = regs; r.rcx = 0xE1;
    add("rdmsr IA32_UMWAIT_CONTROL (0)", {0x0F, 0x32}, &r);
    add("wrmsr UMWAIT_CONTROL=0x1001; rdmsr; wrmsr 0",
        cat({wrmsr_umwait_control(0x1001), {0xB9, 0xE1, 0x00, 0x00, 0x00, 0x0F, 0x32},
             {0x50},                                        // push rax (the value read)
             wrmsr_umwait_control(0), {0x58}}),             // pop rax
        &r);
  }

  // Faults
  {
    ArchState r = regs; r.rbx = 2;
    add_fault("tpause ebx with bit 1 set #GP", cat({deadline(0, 0), TPAUSE_EBX}), 13, &r);
    add_fault("umwait ebx with bit 1 set #GP", cat({deadline(0, 0), UMWAIT_EBX}), 13, &r);
    r.rbx = 0x80000000;
    add_fault("tpause ebx with bit 31 set #GP", cat({deadline(0, 0), TPAUSE_EBX}), 13, &r);
    r.rbx = 0x100000000ULL;  // bits above 31 are not part of r32
    add("tpause ebx with rbx bit 32 set (ignored)", cat({deadline(0, 0), TPAUSE_EBX}), &r);
  }
  add_fault("lock tpause #UD", cat({deadline(0, 0), {0xF0, 0x66, 0x0F, 0xAE, 0xF3}}), 6);
  add_fault("lock umonitor #UD", {0xF0, 0xF3, 0x0F, 0xAE, 0xF7}, 6);
  // UMONITOR on a non-canonical or an unmapped address is not a case
  // here: the SDM gives the instruction the faults of a byte load (#GP(0),
  // #SS(0), #PF), which the model raises, but the Xeon Platinum 8562Y+
  // under KVM completes both without a fault (recorded with the evidence
  // as a manual-versus-hardware observation).
  {
    ArchState r = regs; r.rcx = 0xE1; r.rax = 2; r.rdx = 0;
    add_fault("wrmsr UMWAIT_CONTROL with bit 1 #GP", {0x0F, 0x30}, 13, &r);
    r.rax = 0; r.rdx = 1;
    add_fault("wrmsr UMWAIT_CONTROL with bit 32 #GP", {0x0F, 0x30}, 13, &r);
  }
}

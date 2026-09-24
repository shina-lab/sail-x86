// Hint instructions with no architectural effect: PREFETCHW (0F 0D /1) and
// the reserved-NOP forms of its opcode, CLDEMOTE (0F 1C /0), and SERIALIZE
// (0F 01 E8).  Each is checked to leave every register, flag and the data
// page unchanged; the LOCK prefix is #UD on all of them.

#include "kvm-harness.h"
#include <cpuid.h>

void add_hint_tests(std::vector<TestCase> &tests) {
  std::string cat;

  // Distinct register values so an unintended write would show.
  const ArchState regs = {
    .rax = 0x1111111111111111, .rbx = 0x2222222222222222, .rcx = 0x3333333333333333,
    .rdx = 0x4444444444444444, .rsi = DATA_ADDR + 0x10, .rdi = DATA_ADDR,
    .rbp = 0x5555555555555555, .r8 = DATA_ADDR + 0x20,
    .r9 = 0x0000700000000000,  // canonical, unmapped
  };
  std::vector<u8> data(64);
  for (int i = 0; i < 64; i++) data[i] = u8(0xA0 + i);

  auto add = [&](const std::string &name, std::vector<u8> code) {
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = std::move(code);
    tc.initial = regs;
    tc.flags_mask = FL_ALL;
    tc.init_data = data;
    tc.compare_data_len = 64;
    tests.push_back(std::move(tc));
  };
  auto add_ud = [&](const std::string &name, std::vector<u8> code) {
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = std::move(code);
    tc.initial = regs;
    tc.flags_mask = FL_ALL;
    tc.expect_fault = true;
    tc.expected_vector = 6;
    tests.push_back(std::move(tc));
  };

  // =====================================================================
  // PREFETCHW m8 — 0F 0D /1 (SDM Vol.2B).  The other /r forms of 0F 0D
  // are reserved NOPs (SDM Vol.3B, "Reserved NOP"); the SDM lists no
  // fault but #UD for LOCK, and no CPUID condition.
  // =====================================================================
  cat = "PREFETCHW";
  add("prefetchw [rdi]", {0x0F, 0x0D, 0x0F});
  add("prefetchw [rsi]", {0x0F, 0x0D, 0x0E});
  add("prefetchw [r8] (REX.B)", {0x41, 0x0F, 0x0D, 0x08});
  add("prefetchw [rdi+0x20]", {0x0F, 0x0D, 0x4F, 0x20});
  add("prefetchw [rdi+rcx*8+disp32]", {0x0F, 0x0D, 0x8C, 0xCF, 0x00, 0x10, 0x00, 0x00});
  add("prefetchw [rip+disp32]", {0x0F, 0x0D, 0x0D, 0x00, 0x00, 0x00, 0x00});
  // An unmapped address (r9) and a non-canonical one (rax): hints take
  // no fault.
  add("prefetchw [r9] (unmapped)", {0x41, 0x0F, 0x0D, 0x09});
  add("prefetchw [rax] (non-canonical)", {0x0F, 0x0D, 0x08});
  // The other reg fields: reserved NOPs on both vendors.
  add("0F 0D /0 [rdi] (PREFETCH, reserved NOP)", {0x0F, 0x0D, 0x07});
  add("0F 0D /2 [rdi] (PREFETCHWT1 slot, reserved NOP)", {0x0F, 0x0D, 0x17});
  add("0F 0D /3 [rdi] (reserved NOP)", {0x0F, 0x0D, 0x1F});
  add("0F 0D /7 [rdi] (reserved NOP)", {0x0F, 0x0D, 0x3F});
  // The register form (mod = 11): a reserved NOP on Intel; AMD, whose APM
  // gives PREFETCH/PREFETCHW a memory operand, raises #UD (Zen 4).
  {
    u32 a, b, c, d;
    __get_cpuid(0, &a, &b, &c, &d);
    const bool amd_host = (b == 0x68747541);  // "Auth" of AuthenticAMD
    if (amd_host) {
      add_ud("0F 0D /1 mod=11 #UD (AMD)", {0x0F, 0x0D, 0xCF});
      add_ud("0F 0D /4 mod=11 #UD (AMD)", {0x0F, 0x0D, 0xE0});
    } else {
      add("0F 0D /1 mod=11 (reserved NOP)", {0x0F, 0x0D, 0xCF});
      add("0F 0D /4 mod=11 (reserved NOP)", {0x0F, 0x0D, 0xE0});
    }
  }
  // 66/F2/F3 and REX.W prefixes are accepted like on any ModR/M NOP.
  add("66 prefetchw [rdi]", {0x66, 0x0F, 0x0D, 0x0F});
  add("f3 prefetchw [rdi]", {0xF3, 0x0F, 0x0D, 0x0F});
  add("f2 prefetchw [rdi]", {0xF2, 0x0F, 0x0D, 0x0F});
  add("rex.w prefetchw [rdi]", {0x48, 0x0F, 0x0D, 0x0F});
  add_ud("lock prefetchw [rdi] #UD", {0xF0, 0x0F, 0x0D, 0x0F});
  add_ud("lock 0F 0D /0 [rdi] #UD", {0xF0, 0x0F, 0x0D, 0x07});

  // =====================================================================
  // CLDEMOTE m8 — 0F 1C /0.  A hint; on a processor without it (CPUID.7.0:
  // ECX[25] = 0) the encoding is a NOP as well, so it runs on both hosts.
  // =====================================================================
  cat = "CLDEMOTE";
  add("cldemote [rdi]", {0x0F, 0x1C, 0x07});
  add("cldemote [rsi+0x10]", {0x0F, 0x1C, 0x46, 0x10});
  add("cldemote [r8] (REX.B)", {0x41, 0x0F, 0x1C, 0x00});
  add("cldemote [r9] (unmapped)", {0x41, 0x0F, 0x1C, 0x01});
  add("cldemote [rax] (non-canonical)", {0x0F, 0x1C, 0x00});
  add("0F 1C /0 mod=11 (reserved)", {0x0F, 0x1C, 0xC7});
  add("0F 1C /3 [rdi] (reserved NOP)", {0x0F, 0x1C, 0x1F});
  add("66 cldemote [rdi]", {0x66, 0x0F, 0x1C, 0x07});
  add_ud("lock cldemote [rdi] #UD", {0xF0, 0x0F, 0x1C, 0x07});

  // =====================================================================
  // SERIALIZE — NP 0F 01 E8: no effect on registers, flags or memory.
  // #UD where CPUID.7.0:EDX[14] = 0, so it is constructed only on a host
  // with it (the AMD host has none; that #UD is not modeled yet).
  // =====================================================================
  {
    u32 a, b, c, d;
    __cpuid_count(7, 0, a, b, c, d);
    if (d & (1u << 14)) {
      cat = "SERIALIZE";
      add("serialize", {0x0F, 0x01, 0xE8});
      add("serialize; serialize", {0x0F, 0x01, 0xE8, 0x0F, 0x01, 0xE8});
      add_ud("lock serialize #UD", {0xF0, 0x0F, 0x01, 0xE8});
    }
  }
}

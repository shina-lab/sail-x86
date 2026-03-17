// Feature-gating tests: verify that disabling XCR0/CR4 bits causes #UD
// on both KVM hardware and the Sail model.
//
// These tests change XCR0 or CR4 per-test to disable specific features,
// then run an instruction that requires that feature and expect #UD (vector 6).

#include "kvm-harness.h"

void add_feature_tests(std::vector<TestCase> &tests) {
  std::string cat;

  auto add_ud = [&](const std::string &name, std::vector<u8> code,
                    ArchState init, u64 xcr0, u64 cr4 = 0) {
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = std::move(code);
    tc.initial = init;
    tc.flags_mask = 0;
    tc.expect_fault = true;
    tc.expected_vector = 6;  // #UD
    tc.xcr0_override = xcr0;
    tc.cr4_override = cr4;
    tests.push_back(std::move(tc));
  };

  cat = "Feature gating";

  // --- AVX disabled (XCR0=0x03: x87+SSE only, no AVX) ---
  add_ud("VADDPS with AVX disabled", {0xC5, 0xF0, 0x58, 0xC2}, {.rflags = 0x2}, 0x03);
  add_ud("VPXOR with AVX disabled", {0xC5, 0xF1, 0xEF, 0xC2}, {.rflags = 0x2}, 0x03);
  add_ud("VMOVDQA with AVX disabled", {0xC5, 0xF9, 0x6F, 0xC1}, {.rflags = 0x2}, 0x03);

  // --- AVX-512 disabled (XCR0=0x07: x87+SSE+AVX, no opmask/ZMM) ---
  // VPADDD zmm0, zmm1, zmm2  (62 F1 75 48 FE C2)
  add_ud("VPADDD zmm with AVX-512 disabled",
         {0x62, 0xF1, 0x75, 0x48, 0xFE, 0xC2}, {.rflags = 0x2}, 0x07);
  // VPXORD zmm0, zmm1, zmm2  (62 F1 75 48 EF C2)
  add_ud("VPXORD zmm with AVX-512 disabled",
         {0x62, 0xF1, 0x75, 0x48, 0xEF, 0xC2}, {.rflags = 0x2}, 0x07);

  // --- CR4.OSXSAVE disabled (0x10620 = 0x50620 without bit 18) ---
  add_ud("VADDPS with OSXSAVE disabled", {0xC5, 0xF0, 0x58, 0xC2},
         {.rflags = 0x2}, 0xE7, 0x10620);

  // --- GPR instructions unaffected by AVX being disabled ---
  {
    TestCase tc;
    tc.name = "ADD eax,ebx with AVX disabled";
    tc.category = cat;
    tc.code = {0x01, 0xD8};
    tc.initial = {.rax = 10, .rbx = 20, .rflags = 0x2};
    tc.flags_mask = FL_ALL;
    tc.xcr0_override = 0x03;
    tests.push_back(std::move(tc));
  }
}

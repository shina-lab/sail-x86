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

  // --- EVEX masked memory store (vmovdqu8 with k1 mask) ---
  // Verifies that masked stores only write bytes where mask bit = 1.
  // This is the pattern glibc's EVEX+BMI2 memset uses for partial writes.
  {
    TestCase tc;
    tc.name = "vmovdqu8 masked store (24 of 32 bytes)";
    tc.category = cat;
    // Fill data area with 0x41 pattern, then do masked zero-fill of 24 bytes.
    // vpbroadcastb esi, ymm16    (esi=0, broadcast zero)
    // mov ecx, 0xFFFFFFFF
    // bzhi edx, ecx, ecx         (ecx = (1<<24)-1 = 0x00FFFFFF)
    // kmovd ecx, k1
    // vmovdqu8 ymm16, [rdi]{k1}  (write 24 zero bytes at DATA_ADDR)
    tc.code = {
      0x62, 0xe2, 0x7d, 0x28, 0x7a, 0xc6,  // vpbroadcastb %esi,%ymm16
      0xb9, 0xff, 0xff, 0xff, 0xff,          // mov $0xffffffff,%ecx
      0xc4, 0xe2, 0x68, 0xf5, 0xc9,          // bzhi %edx,%ecx,%ecx
      0xc5, 0xfb, 0x92, 0xc9,                // kmovd %ecx,%k1
      0x62, 0xe1, 0x7f, 0x29, 0x7f, 0x07,    // vmovdqu8 %ymm16,(%rdi){%k1}
    };
    tc.initial = {.rdx = 24, .rsi = 0, .rdi = DATA_ADDR, .rflags = 0x2};
    // Init data: 32 bytes of 0x41
    tc.init_data.assign(32, 0x41);
    // Compare first 32 bytes: 24 zeros + 8 unchanged (0x41)
    tc.compare_data_len = 32;
    tc.flags_mask = 0;
    tests.push_back(std::move(tc));
  }
}

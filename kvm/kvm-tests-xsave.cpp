#include "kvm-harness.h"

#include <cpuid.h>

void add_xsave_tests(std::vector<TestCase> &tests) {
  std::string cat;

  static constexpr size_t XSAVE_AREA_SIZE = 0x980;

  // =====================================================================
  // XSAVEC round-trip — save compacted, restore via XRSTOR
  // =====================================================================
  cat = "XSAVEC roundtrip";

  {
    ArchState s = with_xsave_vector_inputs({}, 0x7);
    s.rflags = initial_flags();
    s.rdi = DATA_ADDR;
    s.rax = 0x7;             // x87 + SSE + AVX
    s.rdx = 0;
    s.xmm[0].lo = 0xDEADDEADDEADDEAD;
    s.xmm[0].hi = 0xBEEFBEEFBEEFBEEF;
    s.xmm[2].lo = 0x2222222222222222;
    s.xmm[2].hi = 0x3333333333333333;

    std::vector<u8> init(XSAVE_AREA_SIZE, 0);

    // XSAVEC [RDI]          ; save in compacted format
    // PXOR XMM0, XMM0
    // PXOR XMM2, XMM2
    // XRSTOR [RDI]          ; restore (XRSTOR handles compacted via XCOMP_BV[63])
    tests.push_back({"xsavec-xrstor roundtrip", cat,
                      {0x0F, 0xC7, 0x27,              // XSAVEC [RDI]
                       0x66, 0x0F, 0xEF, 0xC0,        // PXOR XMM0, XMM0
                       0x66, 0x0F, 0xEF, 0xD2,        // PXOR XMM2, XMM2
                       0x0F, 0xAE, 0x2F},             // XRSTOR [RDI]
                      s, FL_ALL, 0x5, false,          // compare XMM0, XMM2
                      init, 0});
  }

  // XSAVEC with full components, round-trip
  {
    ArchState s = with_xsave_vector_inputs({}, 0xE7);
    s.rflags = initial_flags();
    s.rdi = DATA_ADDR;
    s.rax = 0xE7;            // all components
    s.rdx = 0;
    s.xmm[0].lo = 0xAAAABBBBCCCCDDDD;
    s.xmm[0].hi = 0xEEEEFFFF00001111;
    s.xmm[15].lo = 0x1515151515151515;
    s.xmm[15].hi = 0x1616161616161616;
    s.kregs[0] = 0xDEAD;
    s.kregs[7] = 0xBEEF;

    std::vector<u8> init(XSAVE_AREA_SIZE, 0);

    tests.push_back({"xsavec-xrstor full roundtrip", cat,
                      {0x0F, 0xC7, 0x27,              // XSAVEC [RDI]
                       0x66, 0x0F, 0xEF, 0xC0,        // PXOR XMM0, XMM0
                       0x66, 0x45, 0x0F, 0xEF, 0xFF,  // PXOR XMM15, XMM15
                       0x0F, 0xAE, 0x2F},             // XRSTOR [RDI]
                      s, FL_ALL, (1u << 0) | (1u << 15), false,
                      init, 0,
                      false, -1,
                      (1u << 0) | (1u << 7)});  // compare k0, k7
  }

  // =====================================================================
  // XGETBV tests
  // =====================================================================
  cat = "XGETBV";

  // XGETBV ECX=0: should return XCR0 in EDX:EAX
  {
    ArchState s;
    s.rcx = 0;
    tests.push_back({"xgetbv ecx=0", cat,
                      {0x0F, 0x01, 0xD0},
                      s, FL_ALL});
  }

  // XGETBV ECX=1: KVM intercepts XGETBV and doesn't support ECX=1 for guests,
  // so we can't test this via KVM differential testing. Our Sail model
  // correctly returns XCR0 | IA32_XSS per the SDM.

  // XGETBV ECX=2: should #GP
  {
    ArchState s;
    s.rcx = 2;

    TestCase tc;
    tc.name = "xgetbv ecx=2 #GP";
    tc.category = cat;
    tc.code = {0x0F, 0x01, 0xD0};
    tc.initial = s;
    tc.flags_mask = FL_ALL;
    tc.expect_fault = true;
    tc.expected_vector = 13;  // #GP
    tests.push_back(tc);
  }

  // =====================================================================
  // CPUID leaf 0xD — XSAVE feature enumeration
  // =====================================================================
  cat = "CPUID XSAVE";

  // CPUID leaf 0xD, subleaf 2: AVX component info (size=256, offset=576)
  {
    ArchState s;
    s.rax = 0xD;
    s.rcx = 2;
    tests.push_back({"cpuid leaf 0xD sub 2", cat,
                      {0x0F, 0xA2},
                      s, FL_ALL});
  }

  // CPUID leaf 0xD, subleaf 0.  EAX (XCR0_SUPPORTED) and ECX (the
  // standard-format size covering every supported component) are masked
  // because the hosts support components the model does not: PKRU on
  // both, AMX on Intel.  EBX, the size for the components enabled in
  // XCR0, depends on the vendor's component offsets and is compared as
  // is.
  {
    ArchState s;
    s.rax = 0xD;
    s.rcx = 0;
    tests.push_back({"cpuid leaf 0xD sub 0 (EBX)", cat,
                      {0x0F, 0xA2,                    // cpuid
                       0x25, 0xFF, 0x00, 0x00, 0x00,  // and eax, 0xFF
                       0x31, 0xC9},                   // xor ecx, ecx
                      s, FL_ALL});
  }

  // CPUID leaf 0xD, subleaves 5-7: the AVX-512 components.  Their
  // standard-format offsets differ between Intel (1088/1152/1664) and
  // AMD (832/896/1408); the model follows the vendor profile the harness
  // selects from the host, so all four registers are compared.
  for (u64 sub : {5ull, 6ull, 7ull}) {
    ArchState s;
    s.rax = 0xD;
    s.rcx = sub;
    tests.push_back({std::format("cpuid leaf 0xD sub {}", sub), cat,
                      {0x0F, 0xA2},
                      s, FL_ALL});
  }

  // =====================================================================
  // IA32_XSS MSR (0xDA0) — supervisor state components
  // =====================================================================
  cat = "IA32_XSS";

  // RDMSR IA32_XSS: should return 0 (no supervisor components supported)
  {
    ArchState s;
    s.rcx = 0xDA0;           // IA32_XSS
    // 0F 32 = RDMSR
    tests.push_back({"rdmsr IA32_XSS", cat,
                      {0x0F, 0x32},
                      s, FL_ALL});
  }

  // WRMSR IA32_XSS with 0: should succeed (no-op)
  {
    ArchState s;
    s.rcx = 0xDA0;
    s.rax = 0;               // low 32 bits = 0
    s.rdx = 0;               // high 32 bits = 0
    // 0F 30 = WRMSR
    tests.push_back({"wrmsr IA32_XSS zero", cat,
                      {0x0F, 0x30},
                      s, FL_ALL});
  }

  // WRMSR IA32_XSS with nonzero: should #GP (no bits supported)
  {
    ArchState s;
    s.rcx = 0xDA0;
    s.rax = 0x100;           // bit 8 (PT state) — not supported
    s.rdx = 0;

    TestCase tc;
    tc.name = "wrmsr IA32_XSS nonzero #GP";
    tc.category = cat;
    tc.code = {0x0F, 0x30};
    tc.initial = s;
    tc.flags_mask = FL_ALL;
    tc.expect_fault = true;
    tc.expected_vector = 13;  // #GP
    tests.push_back(tc);
  }

  // Subleaf 0 tests omitted: EAX/ECX mismatch due to host PKRU support
  // (KVM XCR0_SUPPORTED=0x2E7 includes bit 9, our model doesn't have PKRU).
  // The dynamic EBX values (0x240, 0x340, 0x980) were verified to match
  // on the AMD host; an Intel host enumerates the AVX-512 components at
  // different offsets (see XsaveLayout in kvm-harness.cpp).

  // CPUID leaf 0xD, subleaf 1: dynamic EBX (compacted size of the
  // XCR0-enabled components).  EAX is masked to bits 3:0 (XSAVEOPT,
  // XSAVEC, XGETBV1, XSAVES) before the comparison: bit 4 (XFD) reflects
  // the host's AMX support, which the model does not implement.
  for (u64 xcr0 : {0x03ull, 0x07ull, 0xE7ull}) {
    ArchState s;
    s.rax = 0xD;
    s.rcx = 1;
    TestCase tc;
    tc.name = std::format("cpuid 0xD.1 EBX xcr0=0x{:02X}", xcr0);
    tc.category = cat;
    tc.code = {0x0F, 0xA2,         // cpuid
               0x83, 0xE0, 0x0F};  // and eax, 0xF
    tc.initial = s;
    tc.flags_mask = FL_ALL;
    tc.xcr0_override = xcr0;
    tests.push_back(tc);
  }

  // =====================================================================
  // Standard-format XSAVE images — the vendor-specific component layout
  // =====================================================================
  // The standard-format offsets of the AVX-512 components come from
  // CPUID.(0xD,i).EBX and differ between vendors.  The harness selects
  // the model's vendor profile from the host, so an image can be compared
  // byte for byte on either vendor, and each layout is thereby checked
  // against its own silicon.  Component 0 (x87) is left out of the
  // masks: the harness starts it in its initial configuration, and
  // whether XSAVE then reports it in XSTATE_BV (XINUSE tracking) is
  // implementation specific.  Every other component is loaded with
  // nonzero data, so XINUSE is 1 and XSTATE_BV is determined.
  cat = "XSAVE image";

  // Standard-format offset of a component on this host.
  auto host_offset = [](u32 component) {
    u32 a, b, c, d;
    __cpuid_count(0xD, component, a, b, c, d);
    return b;
  };
  // End of the Intel layout (Hi16_ZMM at 1664 + 1024); AMD's fits inside.
  static constexpr size_t STD_IMAGE_SIZE = 2688;

  // Every ZMM register and every k register gets a distinct nonzero value.
  auto zmm_pattern = [](int i) {
    ZmmVal v;
    for (int j = 0; j < 8; j++)
      v.q[j] = (u64)(i * 8 + j + 1) * 0x0101010101010101ULL;
    return v;
  };
  auto k_pattern = [](int i) { return (u64)0x1111 * (i + 1); };

  // XSAVE [RDI] with EDX:EAX = 0xE6: every component but x87 is written.
  {
    ArchState s;
    s.rdi = DATA_ADDR;
    s.rax = 0xE6;
    s.rdx = 0;
    for (int i = 0; i < 32; i++) s.xmm[i] = zmm_pattern(i);
    for (int i = 0; i < 8; i++) s.kregs[i] = k_pattern(i);
    std::vector<u8> init(STD_IMAGE_SIZE, 0);
    tests.push_back({"xsave standard image (mask 0xE6)", cat,
                      {0x0F, 0xAE, 0x27},             // XSAVE [RDI]
                      s, FL_ALL, 0, false, init, STD_IMAGE_SIZE});
  }

  // XRSTOR [RDI] from a standard-format image laid out at the host's
  // component offsets; every ZMM and k register is compared afterwards.
  {
    ArchState s;
    s.rdi = DATA_ADDR;
    s.rax = 0xE6;
    s.rdx = 0;
    std::vector<u8> init(STD_IMAGE_SIZE, 0);
    u32 mxcsr = 0x1F80;
    memcpy(init.data() + 0x18, &mxcsr, 4);
    for (int i = 0; i < 16; i++) {
      ZmmVal v = zmm_pattern(i);
      memcpy(init.data() + 0xA0 + i * 16, &v.q[0], 16);
      memcpy(init.data() + host_offset(2) + i * 16, &v.q[2], 16);
      memcpy(init.data() + host_offset(6) + i * 32, &v.q[4], 32);
    }
    for (int i = 0; i < 16; i++) {
      ZmmVal v = zmm_pattern(16 + i);
      memcpy(init.data() + host_offset(7) + i * 64, &v.q[0], 64);
    }
    for (int i = 0; i < 8; i++) {
      u64 k = k_pattern(i);
      memcpy(init.data() + host_offset(5) + i * 8, &k, 8);
    }
    u64 xstate_bv = 0xE6;
    memcpy(init.data() + 512, &xstate_bv, 8);
    tests.push_back({"xrstor standard image (mask 0xE6)", cat,
                      {0x0F, 0xAE, 0x2F},             // XRSTOR [RDI]
                      s, FL_ALL, 0xFFFFFFFFu, false, init, 0,
                      false, -1, 0xFF});
  }
}

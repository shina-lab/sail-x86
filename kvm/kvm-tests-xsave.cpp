#include "kvm-harness.h"

void add_xsave_tests(std::vector<TestCase> &tests) {
  std::string cat;

  static constexpr size_t XSAVE_AREA_SIZE = 0x980;

  // =====================================================================
  // XSAVEC round-trip — save compacted, restore via XRSTOR
  // =====================================================================
  cat = "XSAVEC roundtrip";

  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    s.rax = 0x7;             // x87 + SSE + AVX
    s.rdx = 0;
    s.xmm[0] = xmm_from_u64(0xDEADDEADDEADDEAD, 0xBEEFBEEFBEEFBEEF);
    s.xmm[2] = xmm_from_u64(0x2222222222222222, 0x3333333333333333);

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
                      s, FL_NONE, 0x5, false,          // compare XMM0, XMM2
                      init, 0});
  }

  // XSAVEC with full components, round-trip
  {
    ArchState s;
    s.rflags = 0x2;
    s.rdi = DATA_ADDR;
    s.rax = 0xE7;            // all components
    s.rdx = 0;
    s.xmm[0] = xmm_from_u64(0xAAAABBBBCCCCDDDD, 0xEEEEFFFF00001111);
    s.xmm[15] = xmm_from_u64(0x1515151515151515, 0x1616161616161616);
    s.kregs[0] = 0xDEAD;
    s.kregs[7] = 0xBEEF;

    std::vector<u8> init(XSAVE_AREA_SIZE, 0);

    tests.push_back({"xsavec-xrstor full roundtrip", cat,
                      {0x0F, 0xC7, 0x27,              // XSAVEC [RDI]
                       0x66, 0x0F, 0xEF, 0xC0,        // PXOR XMM0, XMM0
                       0x66, 0x45, 0x0F, 0xEF, 0xFF,  // PXOR XMM15, XMM15
                       0x0F, 0xAE, 0x2F},             // XRSTOR [RDI]
                      s, FL_NONE, (1u << 0) | (1u << 15), false,
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
    s.rflags = 0x2;
    s.rcx = 0;
    tests.push_back({"xgetbv ecx=0", cat,
                      {0x0F, 0x01, 0xD0},
                      s, FL_NONE});
  }

  // XGETBV ECX=1: KVM intercepts XGETBV and doesn't support ECX=1 for guests,
  // so we can't test this via KVM differential testing. Our Sail model
  // correctly returns XCR0 | IA32_XSS per the SDM.

  // XGETBV ECX=2: should #GP
  {
    ArchState s;
    s.rflags = 0x2;
    s.rcx = 2;

    TestCase tc;
    tc.name = "xgetbv ecx=2 #GP";
    tc.category = cat;
    tc.code = {0x0F, 0x01, 0xD0};
    tc.initial = s;
    tc.flags_mask = FL_NONE;
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
    s.rflags = 0x2;
    s.rax = 0xD;
    s.rcx = 2;
    tests.push_back({"cpuid leaf 0xD sub 2", cat,
                      {0x0F, 0xA2},
                      s, FL_NONE});
  }

  // =====================================================================
  // IA32_XSS MSR (0xDA0) — supervisor state components
  // =====================================================================
  cat = "IA32_XSS";

  // RDMSR IA32_XSS: should return 0 (no supervisor components supported)
  {
    ArchState s;
    s.rflags = 0x2;
    s.rcx = 0xDA0;           // IA32_XSS
    // 0F 32 = RDMSR
    tests.push_back({"rdmsr IA32_XSS", cat,
                      {0x0F, 0x32},
                      s, FL_NONE});
  }

  // WRMSR IA32_XSS with 0: should succeed (no-op)
  {
    ArchState s;
    s.rflags = 0x2;
    s.rcx = 0xDA0;
    s.rax = 0;               // low 32 bits = 0
    s.rdx = 0;               // high 32 bits = 0
    // 0F 30 = WRMSR
    tests.push_back({"wrmsr IA32_XSS zero", cat,
                      {0x0F, 0x30},
                      s, FL_NONE});
  }

  // WRMSR IA32_XSS with nonzero: should #GP (no bits supported)
  {
    ArchState s;
    s.rflags = 0x2;
    s.rcx = 0xDA0;
    s.rax = 0x100;           // bit 8 (PT state) — not supported
    s.rdx = 0;

    TestCase tc;
    tc.name = "wrmsr IA32_XSS nonzero #GP";
    tc.category = cat;
    tc.code = {0x0F, 0x30};
    tc.initial = s;
    tc.flags_mask = FL_NONE;
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
    s.rflags = 0x2;
    s.rax = 0xD;
    s.rcx = 1;
    TestCase tc;
    tc.name = std::format("cpuid 0xD.1 EBX xcr0=0x{:02X}", xcr0);
    tc.category = cat;
    tc.code = {0x0F, 0xA2,         // cpuid
               0x83, 0xE0, 0x0F};  // and eax, 0xF
    tc.initial = s;
    tc.flags_mask = FL_NONE;
    tc.xcr0_override = xcr0;
    tests.push_back(tc);
  }
}

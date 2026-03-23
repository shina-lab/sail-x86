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
}

#include "kvm-harness.h"

#include <algorithm>
#include <cpuid.h>

void add_xsave_tests(std::vector<TestCase> &tests) {
  using namespace feature;
  std::string cat;

  // The cases' XSAVE areas are the data page, which starts zeroed.  The
  // XSAVE extensions are enumerated in CPUID leaf 0DH, which a processor
  // has with XSAVE (SDM Vol.1 §13.2 p.13-3).
  const bool xsave = host_has(XSAVE);

  // =====================================================================
  // XSAVEC round-trip — save compacted, restore via XRSTOR
  // =====================================================================
  cat = "XSAVEC roundtrip";

  // Every component saved is out of its initial configuration (FLD1 for
  // x87): XSAVEC writes a component in its initial configuration or not at
  // the implementation's choice (SDM Vol.1 §13.6, §13.10).
  if (xsave && host_has(XSAVEC)) {
    ArchState s = with_xsave_vector_inputs({}, 0x7);
    s.rflags = initial_flags();
    s.rdi = DATA_ADDR;
    s.rax = 0x7;             // x87 + SSE + AVX
    s.rdx = 0;
    s.xmm[0].lo = 0xDEADDEADDEADDEAD;
    s.xmm[0].hi = 0xBEEFBEEFBEEFBEEF;
    s.xmm[0].q[2] = 0x4444444444444444;  // AVX: bits 255:128
    s.xmm[2].lo = 0x2222222222222222;
    s.xmm[2].hi = 0x3333333333333333;

    // FLD1
    // XSAVEC [RDI]          ; save in compacted format
    // PXOR XMM0, XMM0
    // PXOR XMM2, XMM2
    // XRSTOR [RDI]          ; restore (XRSTOR handles compacted via XCOMP_BV[63])
    tests.push_back({"xsavec-xrstor roundtrip", cat,
                      {0xD9, 0xE8,                    // FLD1
                       0x0F, 0xC7, 0x27,              // XSAVEC [RDI]
                       0x66, 0x0F, 0xEF, 0xC0,        // PXOR XMM0, XMM0
                       0x66, 0x0F, 0xEF, 0xD2,        // PXOR XMM2, XMM2
                       0x0F, 0xAE, 0x2F},             // XRSTOR [RDI]
                      s, FL_ALL, 0x5});               // compare XMM0, XMM2
    fxsave_x87_undefined(tests.back(), 0, X87_XSAVE_NO_ES);  // FSW.ES = 0 after FLD1
  }

  // XSAVEC with full components, round-trip
  if (xsave && host_has(XSAVEC)) {
    ArchState s = with_xsave_vector_inputs({}, 0xE7);
    s.rflags = initial_flags();
    s.rdi = DATA_ADDR;
    s.rax = 0xE7;            // all components
    s.rdx = 0;
    s.xmm[0].lo = 0xAAAABBBBCCCCDDDD;
    s.xmm[0].hi = 0xEEEEFFFF00001111;
    s.xmm[15].lo = 0x1515151515151515;
    s.xmm[15].hi = 0x1616161616161616;
    s.xmm[0].q[2] = 0x4444444444444444;   // AVX: bits 255:128
    s.xmm[0].q[4] = 0x6666666666666666;   // ZMM_Hi256: bits 511:256
    s.xmm[16].q[0] = 0x1717171717171717;  // Hi16_ZMM
    s.kregs[0] = 0xDEAD;
    s.kregs[7] = 0xBEEF;

    tests.push_back({"xsavec-xrstor full roundtrip", cat,
                      {0xD9, 0xE8,                    // FLD1
                       0x0F, 0xC7, 0x27,              // XSAVEC [RDI]
                       0x66, 0x0F, 0xEF, 0xC0,        // PXOR XMM0, XMM0
                       0x66, 0x45, 0x0F, 0xEF, 0xFF,  // PXOR XMM15, XMM15
                       0x0F, 0xAE, 0x2F},             // XRSTOR [RDI]
                      s, FL_ALL, (1u << 0) | (1u << 15), false,
                      {}, 0,
                      false, -1,
                      (1u << 0) | (1u << 7)});  // compare k0, k7
    fxsave_x87_undefined(tests.back(), 0, X87_XSAVE_NO_ES);  // FSW.ES = 0 after FLD1
  }

  // SSE with the XMM registers 0 and MXCSR 7F80H.  The SDM writes
  // XSTATE_BV[1] as 1 "if RFBM[1] = 1 and MXCSR does not have the value
  // 1F80H" and "saves all of state component 1" (Vol.1 §13.10); the APM
  // has XSTATE_BV = "the logical AND of the RFBM and XINUSE bitmaps" and
  // no MXCSR rule (Vol.4 XSAVEC p.1776), and XINUSE[1] may be either value
  // for XMM registers in their initial configuration.  So the bit and the
  // component (MXCSR, MXCSR_MASK and the XMM registers) are open, as in
  // the model; the rest of the image is compared.  The page starts as EEh,
  // so the bytes XSAVEC leaves show.
  if (xsave && host_has(XSAVEC)) {
    ArchState s = with_xsave_vector_inputs({}, 0x2);
    s.rflags = initial_flags();
    s.rdi = DATA_ADDR;
    s.rax = 0x2;
    s.rdx = 0;
    s.mxcsr = 0x7F80;
    tests.push_back({"xsavec [rdi] mask SSE (XMM registers 0, MXCSR 7F80H)", cat,
                      {0x0F, 0xC7, 0x27},             // XSAVEC [RDI]
                      s, FL_ALL, 0, false, std::vector<u8>(0x1000, 0xEE), 0});
    tests.back().data_undefined.push_back({0x200, 0x02});
    for (u16 j = 0x18; j < 0x20; j++) tests.back().data_undefined.push_back({j, 0xFF});
    for (u16 j = 0xA0; j < 0x1A0; j++) tests.back().data_undefined.push_back({j, 0xFF});
  }

  // =====================================================================
  // XGETBV tests
  // =====================================================================
  cat = "XGETBV";

  // XGETBV ECX=0: should return XCR0 in EDX:EAX
  if (xsave) {
    ArchState s;
    s.rcx = 0;
    tests.push_back({"xgetbv ecx=0", cat,
                      {0x0F, 0x01, 0xD0},
                      s, FL_ALL});
  }

  // XGETBV ECX=1: XCR0 AND XINUSE, where XINUSE[i] is 1 for a component
  // out of its initial configuration and either value for one in it
  // (SDM Vol.1 §13.6; APM Vol.4 XGETBV p.1763).  The bits of the
  // components left initial are masked, EAX[1] with MXCSR 7F80H as well:
  // the SDM sets it "if XCR0[1] = 1 and MXCSR does not have its RESET
  // value of 1F80H", the APM has no such rule.  ECX = 1 needs
  // CPUID.(0DH,1):EAX[2] (SDM Vol.2D XGETBV p.6-35).
  if (xsave && host_has(XGETBV1)) {
    ArchState s;
    s.rcx = 1;
    s.xmm[0].lo = 0x1234;  // SSE in use
    TestCase tc;
    tc.name = "fld1; xgetbv ecx=1 (x87 and SSE in use)";
    tc.category = cat;
    tc.code = {0xD9, 0xE8, 0x0F, 0x01, 0xD0};
    tc.initial = s;
    tc.flags_mask = FL_ALL;
    tc.undefined.gpr[0] = 0xFFFFFFFC;
    tests.push_back(tc);

    s = ArchState{};
    s.rcx = 1;
    s.mxcsr = 0x7F80;
    tc.name = "xgetbv ecx=1 (XMM registers 0, MXCSR 7F80H)";
    tc.code = {0x0F, 0x01, 0xD0};
    tc.initial = s;
    tc.undefined.gpr[0] = 0xFFFFFFFF;
    tests.push_back(tc);
  }

  // XGETBV ECX=2: should #GP
  if (xsave) {
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

  // CPUID leaf 0xD, subleaf 0: EDX:EAX the XCR0 bits the processor
  // supports, EBX the standard-format size for the components XCR0
  // enables and ECX the one for every supported component (SDM Vol.1
  // §13.2 p.13-3).  The guest's leaf has the harness's components
  // (guest_cpuid), as the model's does, so all four registers are
  // compared.
  if (xsave) {
    ArchState s;
    s.rax = 0xD;
    s.rcx = 0;
    tests.push_back({"cpuid leaf 0xD sub 0", cat,
                      {0x0F, 0xA2},
                      s, FL_ALL});
  }

  // CPUID leaf 0xD, subleaves 2 and 5-7: the AVX and AVX-512 components'
  // sizes, standard-format offsets and compacted-format alignment, which
  // neither manual fixes (SDM Vol.1 §13.2 p.13-4); the model is given the
  // guest's.  A component the guest does not have reads as zeros.
  for (u64 sub : {2ull, 5ull, 6ull, 7ull}) {
    if (!xsave) break;
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

  // The MSR exists with XSAVES, CPUID.(0DH,1):EAX[3] (SDM Vol.1 §13.2
  // p.13-4).  The guest's CPUID.(0DH,1):EDX:ECX has no supervisor
  // component (guest_cpuid), so the MSR's only valid value is 0.

  // RDMSR IA32_XSS: should return 0 (no supervisor components supported)
  if (xsave && host_has(XSAVES)) {
    ArchState s;
    s.rcx = 0xDA0;           // IA32_XSS
    // 0F 32 = RDMSR
    tests.push_back({"rdmsr IA32_XSS", cat,
                      {0x0F, 0x32},
                      s, FL_ALL});
  }

  // WRMSR IA32_XSS with 0: should succeed (no-op)
  if (xsave && host_has(XSAVES)) {
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
  if (xsave && host_has(XSAVES)) {
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

  // CPUID leaf 0xD, subleaf 1: EAX the XSAVE extensions, and EBX the
  // compacted size of the components XCR0 | IA32_XSS enables, with XSAVEC
  // or XSAVES (SDM Vol.1 §13.2 p.13-4), for XCR0 of SSE, of SSE and AVX
  // and of every component the guest enables.  EAX is masked to the bits
  // the manual defines, 4:0 ("EAX[31:5] are reserved").
  std::vector<u64> xcr0s;
  for (u64 x : {u64(0x3), guest_xcr0() & 0x7, guest_xcr0()})
    if (std::find(xcr0s.begin(), xcr0s.end(), x) == xcr0s.end()) xcr0s.push_back(x);
  for (u64 xcr0 : xcr0s) {
    if (!xsave) break;
    ArchState s;
    s.rax = 0xD;
    s.rcx = 1;
    TestCase tc;
    tc.name = std::format("cpuid 0xD.1 EBX xcr0=0x{:02X}", xcr0);
    tc.category = cat;
    tc.code = {0x0F, 0xA2,         // cpuid
               0x83, 0xE0, 0x1F};  // and eax, 0x1F
    tc.initial = s;
    tc.flags_mask = FL_ALL;
    tc.xcr0_override = xcr0;
    tests.push_back(tc);
  }

  // =====================================================================
  // Standard-format XSAVE images — the implementation's component layout
  // =====================================================================
  // Component i of a standard-format image is at "the offset (in bytes,
  // from the base of the XSAVE area)" CPUID.(0DH,i):EBX gives, and is
  // CPUID.(0DH,i):EAX bytes long (SDM Vol.1 §13.2 p.13-4, §13.4.3).  The
  // manuals leave the offsets to the implementation; the model is given
  // the guest's, so an image is compared byte for byte on any processor.
  // The images hold every component the guest's XCR0 enables but x87
  // (component 0): the harness starts it in its initial configuration,
  // and whether XSAVE then reports it in XSTATE_BV (XINUSE tracking) is
  // implementation specific.  Every other component is loaded with
  // nonzero data, so XINUSE is 1 and XSTATE_BV is determined.
  cat = "XSAVE image";
  const u64 image_mask = guest_xcr0() & ~1ULL;
  u32 image_size = 576;  // the legacy region and the XSAVE header
  for (unsigned i = 2; i < 64; i++) {
    if (!(image_mask >> i & 1)) continue;
    std::array<u32, 4> d = guest_cpuid(0xD, i);
    image_size = std::max(image_size, d[CPUID_EBX] + d[CPUID_EAX]);
  }
  const bool image_fits = xsave && image_size <= 0x1000;  // in the data page

  // Every ZMM register and every k register gets a distinct nonzero value.
  auto zmm_pattern = [](int i) {
    ZmmVal v;
    for (int j = 0; j < 8; j++)
      v.q[j] = (u64)(i * 8 + j + 1) * 0x0101010101010101ULL;
    return v;
  };
  auto k_pattern = [](int i) { return (u64)0x1111 * (i + 1); };

  // XSAVE [RDI] with EDX:EAX = image_mask: every component but x87 is
  // written.
  if (image_fits) {
    ArchState s;
    s.rdi = DATA_ADDR;
    s.rax = image_mask;
    s.rdx = 0;
    for (int i = 0; i < 32; i++) s.xmm[i] = zmm_pattern(i);
    for (int i = 0; i < 8; i++) s.kregs[i] = k_pattern(i);
    tests.push_back({std::format("xsave standard image (mask 0x{:X})", image_mask), cat,
                      {0x0F, 0xAE, 0x27},             // XSAVE [RDI]
                      s, FL_ALL});
  }

  // XRSTOR [RDI] from a standard-format image laid out at the guest's
  // component offsets; every ZMM and k register is compared afterwards.
  if (image_fits) {
    ArchState s;
    s.rdi = DATA_ADDR;
    s.rax = image_mask;
    s.rdx = 0;
    std::vector<u8> init(image_size, 0);
    // n bytes at byte j of component i's section, if the image has it.
    auto put = [&](unsigned i, u32 j, const void *src, size_t n) {
      if (image_mask >> i & 1) memcpy(init.data() + guest_cpuid(0xD, i)[CPUID_EBX] + j, src, n);
    };
    u32 mxcsr = 0x1F80;
    memcpy(init.data() + 0x18, &mxcsr, 4);
    for (int i = 0; i < 16; i++) {
      ZmmVal v = zmm_pattern(i);
      memcpy(init.data() + 0xA0 + i * 16, &v.q[0], 16);
      put(2, i * 16, &v.q[2], 16);
      put(6, i * 32, &v.q[4], 32);
    }
    for (int i = 0; i < 16; i++) {
      ZmmVal v = zmm_pattern(16 + i);
      put(7, i * 64, &v.q[0], 64);
    }
    for (int i = 0; i < 8; i++) {
      u64 k = k_pattern(i);
      put(5, i * 8, &k, 8);
    }
    memcpy(init.data() + 512, &image_mask, 8);  // XSTATE_BV
    tests.push_back({std::format("xrstor standard image (mask 0x{:X})", image_mask), cat,
                      {0x0F, 0xAE, 0x2F},             // XRSTOR [RDI]
                      s, FL_ALL, 0xFFFFFFFFu, false, init, 0,
                      false, -1, 0xFF});
  }

  // =====================================================================
  // FXSAVE/FXRSTOR (0F AE /0, /1): the image must be 16-byte aligned, and
  // FXRSTOR is #GP(0) "for an attempt to set reserved bits in MXCSR"; a
  // valid image loads MXCSR and XMM0-15 while bits 511:128 of the
  // registers are kept (a non-VEX instruction on XMM state, Vol.1 §14.8).
  // =====================================================================
  cat = "FXRSTOR";
  {
    // An FXSAVE-format image: FCW 037F, FSW 0, abridged FTW 0 (all empty),
    // MXCSR at 0x18, ST0-7 at 0x20 and XMM0-15 at 0xA0 with distinctive
    // bytes; bytes 464:511 are for software and ignored.
    auto image = [](u32 mxcsr) {
      std::vector<u8> img(512, 0);
      img[0] = 0x7F;
      img[1] = 0x03;
      memcpy(img.data() + 0x18, &mxcsr, 4);
      for (int i = 0; i < 8; i++)
        for (int j = 0; j < 10; j++) img[0x20 + i * 16 + j] = (u8)(0x10 * i + j + 1);
      for (int i = 0; i < 16; i++)
        for (int j = 0; j < 16; j++) img[0xA0 + i * 16 + j] = (u8)(0x11 * (i + 1) + j);
      for (int j = 464; j < 512; j++) img[j] = 0xEE;
      return img;
    };
    auto fx = [&](const std::string &name, std::vector<u8> code, ArchState init,
                  std::vector<u8> data, int vec = -2) {
      TestCase tc;
      tc.name = name;
      tc.category = cat;
      tc.code = std::move(code);
      tc.initial = init;
      tc.flags_mask = FL_ALL;
      tc.init_data = std::move(data);
      if (vec != -2) {
        tc.expect_fault = true;
        tc.expected_vector = vec;
      } else {
        tc.cmp_mxcsr = true;
      }
      tests.push_back(std::move(tc));
    };
    const std::vector<u8> fxrstor = {0x0F, 0xAE, 0x0F};          // fxrstor [rdi]
    const std::vector<u8> fxrstor64 = {0x48, 0x0F, 0xAE, 0x0F};  // fxrstor64 [rdi]
    const std::vector<u8> fxsave = {0x0F, 0xAE, 0x07};           // fxsave [rdi]

    // Bits 511:128 of the registers are inputs: FXRSTOR must keep them.
    ArchState s = {.rdi = DATA_ADDR};
    for (int i = 0; i < 16; i++)
      for (int q = 2; q < 8; q++)
        s.xmm[i].q[q] = 0xA5A5A5A5A5A5A5A5ULL ^ (0x0101010101010101ULL * (i * 8 + q));

    fx("fxrstor [rdi] (valid image, MXCSR 7F80: masks + round toward zero)", fxrstor, s, image(0x7F80));
    fx("fxrstor [rdi] (valid image, MXCSR 1F80)", fxrstor, s, image(0x1F80));
    fx("fxrstor64 [rdi] (valid image, MXCSR 5F80)", fxrstor64, s, image(0x5F80));
    // Reserved MXCSR bits: bit 16 (reserved on both vendors) and 31:18
    fx("fxrstor [rdi] with MXCSR bit 16 set (#GP)", fxrstor, s, image(0x1F80 | 0x10000), 13);
    fx("fxrstor [rdi] with MXCSR bits 31:18 set (#GP)", fxrstor, s, image(0x1F80 | 0xFFFC0000u), 13);
    fx("fxrstor64 [rdi] with MXCSR bit 16 set (#GP)", fxrstor64, s, image(0x1F80 | 0x10000), 13);
    // Misaligned operands
    ArchState mis = s;
    mis.rdi = DATA_ADDR + 8;
    fx("fxrstor [rdi+8] misaligned (#GP)", fxrstor, mis, image(0x1F80), 13);
    fx("fxsave [rdi+8] misaligned (#GP)", fxsave, mis, std::vector<u8>(512, 0), 13);
    // An image whose other fields are arbitrary bytes (the coverage run's
    // pattern) with a valid MXCSR loads like any other.
    {
      std::vector<u8> pat(512);
      for (int j = 0; j < 512; j++) pat[j] = (u8)(j * 7 + 3);
      u32 mxcsr = 0x1F80;
      memcpy(pat.data() + 0x18, &mxcsr, 4);
      fx("fxrstor [rdi] (arbitrary image bytes, valid MXCSR)", fxrstor, s, pat);
    }

    // CR4.OSFXSR = 0: "FXSAVE and FXRSTOR may or may not operate on SSE
    // state; this behavior is implementation dependent" (SDM Vol.1 §10.5.1
    // p.10-16), and the APM's FXSAVE "does not save the image of
    // XMM0–XMM15 or MXCSR" and its FXRSTOR does not load it (APM Vol.5
    // FXSAVE p.26, FXRSTOR p.24): the SSE fields and state are open.
    // MXCSR_MASK is written either way.  The image MXCSR is valid: the
    // #GP for a reserved bit, which only an SDM processor that loads it
    // could raise, is not tested.
    {
      const u64 CR4_NO_OSFXSR = guest_cr4() & ~CR4_OSFXSR;
      ArchState o = s;
      o.mxcsr = 0x7F80;
      for (int i = 0; i < 16; i++)
        for (int q = 0; q < 2; q++) o.xmm[i].q[q] = 0x5A5A5A5A5A5A5A5AULL ^ (0x0101010101010101ULL * (i * 2 + q));
      fx("fxsave [rdi] with CR4.OSFXSR = 0", fxsave, o, std::vector<u8>(512, 0xEE));
      tests.back().cr4_override = CR4_NO_OSFXSR;
      fxsave_x87_undefined(tests.back(), 0, X87_FXSAVE_NO_ES);
      for (u16 j = 0x18; j < 0x1C; j++) tests.back().data_undefined.push_back({j, 0xFF});
      for (u16 j = 0xA0; j < 0x1A0; j++) tests.back().data_undefined.push_back({j, 0xFF});
      fx("fxrstor [rdi] with CR4.OSFXSR = 0", fxrstor, o, image(0x1F80));
      tests.back().cr4_override = CR4_NO_OSFXSR;
      tests.back().undefined.mxcsr = ~0u;
      for (int i = 0; i < 16; i++) tests.back().undefined.zmm[i][0] = tests.back().undefined.zmm[i][1] = ~0ULL;
    }

    // The x87 pointers an image carries, read back with FNSTENV.  The SDM's
    // FXRSTOR and XRSTOR load FOP, FIP and FDP, and FCS and FDS from the
    // 32-bit format (Vol.1 §8.1.8).  The APM's FXRSTOR loads them only
    // "when FXRSTOR sets FSW.ES=1 after recomputing it" (Vol.5 FXRSTOR
    // p.24), its XRSTOR likewise where RstrFpErrPtrs is 0 and always where
    // it is 1, zeroing "the CS and DS portions" in 64-bit mode (Vol.2
    // §11.5.10 p.361).  With FSW.ES = 0 they are open but after an XRSTOR
    // with RstrFpErrPtrs (X87_FXSAVE_NO_ES, X87_XSAVE_NO_ES).
    for (bool es : {false, true}) {
      std::vector<u8> img = image(0x1F80);
      u16 cw = es ? 0x037E : 0x037F, sw = es ? 0x0001 : 0x0000;  // IE, unmasked or not
      u16 fop = 0x01D9, fcs = 0x0023, fds = 0x002B;
      u32 fip = 0x12345678, fdp = 0x9ABCDEF0;
      memcpy(&img[0], &cw, 2);
      memcpy(&img[2], &sw, 2);
      memcpy(&img[6], &fop, 2);
      memcpy(&img[8], &fip, 4);
      memcpy(&img[12], &fcs, 2);
      memcpy(&img[16], &fdp, 4);
      memcpy(&img[20], &fds, 2);
      std::string what = es ? "FSW.ES = 1" : "FSW.ES = 0";
      std::vector<u8> code = fxrstor;
      code.insert(code.end(), {0xD9, 0xB7, 0x00, 0x02, 0x00, 0x00});  // fnstenv [rdi+0x200]
      fx("fxrstor [rdi] (" + what + "); fnstenv: the x87 pointers", code, s, img);
      unsigned open = X87_CW_LOADED | X87_LONG_MODE;
      x87_env_undefined(tests.back(), 0x200, es ? open : open | X87_FXSAVE_NO_ES);
      if (!xsave) continue;
      img.resize(576, 0);
      img[512] = 1;  // XSTATE_BV: x87
      code = {0x0F, 0xAE, 0x2F,                       // xrstor [rdi]
              0xD9, 0xB7, 0x40, 0x02, 0x00, 0x00};    // fnstenv [rdi+0x240]
      ArchState x = s;
      x.rax = 1;
      x.rdx = 0;
      fx("xrstor [rdi] (" + what + "); fnstenv: the x87 pointers", code, x, img);
      x87_env_undefined(tests.back(), 0x240, es ? open : open | X87_XSAVE_NO_ES);
    }
  }
}

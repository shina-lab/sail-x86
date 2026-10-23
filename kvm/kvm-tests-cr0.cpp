// CR0.TS, CR0.EM and CR0.MP, and the instructions they stop: each case
// writes CR0 from R11 and then executes one instruction, which raises #NM
// or #UD or completes.  The harness restores CR0 before every case.
//
// The rules (SDM Vol.3A §2.5 and Tables 2-2, 15-1 and 16-1, Vol.2A
// §§2.5-2.9, the exception classes; APM Vol.2 §3.1.1, §8.2.7 and §8.2.8,
// Vol.4 §3.2.1; the instruction pages):
//   - TS = 1: #NM before any x87, MMX, SSE, AVX or AVX-512 instruction,
//     the XSAVE family, FXSAVE/FXRSTOR, LDMXCSR/STMXCSR and EMMS; not
//     before PAUSE, PREFETCHh, SFENCE, LFENCE, MFENCE, MOVNTI, CLFLUSH,
//     CRC32, POPCNT, the VEX-encoded general-purpose instructions (BMI1,
//     BMI2: exception class 13) or XGETBV.
//   - EM = 1: #NM for x87 and FXSAVE/FXRSTOR.  #UD for MMX, legacy SSE,
//     LDMXCSR/STMXCSR and EMMS: on Intel whatever TS ("If the EM flag is
//     set, the setting of the TS flag has no effect", SDM Vol.3A §2.5);
//     the APM gives EM its #UD and TS its #NM in no order.  The XSAVE
//     family ignores EM.  The SDM's VEX and EVEX classes ignore it.  The
//     APM gives #UD for AVX-512 (EVEX and the opmask instructions; Vol.4
//     §3.2.1) and for the VEX SIMD instructions without a legacy SSE form
//     (Vol.2 §8.2.7; Vol.4 Table 3-1, Classes 4G and 4H), and contradicts
//     itself for the VEX forms of SSE instructions (Vol.2 §8.2.7: #UD; the
//     PADDD and LDMXCSR pages: SSE forms only), so there an AMD case
//     accepts either.
//   - WAIT/FWAIT: #NM only when TS = 1 and MP = 1.
//   - #NM and #UD are both faults from decoding the instruction, in one
//     class whose internal order the manuals leave open (SDM Vol.3A §7.9,
//     Table 7-2, class 9; APM Vol.2 §8.5, Table 8-9, group 6), ahead of
//     the faults of its memory operands.  The model raises the #UD of the
//     encoding first; a case of an encoding that is #UD accepts either
//     fault when TS (or, where it applies, EM) is set.
//
// rdi points to the data page, rsi to an unmapped page (the harness maps
// nothing below CODE_ADDR).

#include "kvm-harness.h"
#include <cpuid.h>

namespace {

constexpr u64 CR0_GUEST = 0x80000011;  // PG + ET + PE, as the harness sets it
constexpr u64 MP = 0x2, EM = 0x4, TS = 0x8;
constexpr u64 UNMAPPED = 0x1000;
const std::vector<u8> MOV_CR0_R11 = {0x41, 0x0F, 0x22, 0xC3};  // mov cr0, r11

constexpr int NONE = -1, UD = 6, NM = 7;

}  // namespace

void add_cr0_tests(std::vector<TestCase> &tests) {
  u32 a, b, c, d;
  __get_cpuid(0, &a, &b, &c, &d);
  const bool amd_host = b == 0x68747541;  // "Auth" of AuthenticAMD
  const u64 AMX_XCR0 = guest_xcr0() | 3ULL << 17;
  // A case of an instruction the guest lacks is left out: its #UD and the
  // #NM are in one class, in no order (as for add_ud below), and the
  // model has no switch for AVX2.
  using namespace feature;
  // The arithmetic flags after MOV to CR0, where the manuals differ: "The
  // OF, SF, ZF, AF, PF, and CF flags are undefined" (SDM Vol.2B MOV—Move
  // to/from Control Registers); "rFLAGS Affected None" (APM Vol.3 MOV
  // CRn).
  const u64 flags = amd_host ? FL_ALL : FL_DF;

  // vec is the exception the instruction raises, or NONE when it completes.
  auto add = [&](const std::string &cat, u64 bits, const std::string &name,
                 std::vector<u8> insn, int vec, ArchState init = {},
                 std::vector<u8> data = {}) {
    TestCase tc;
    tc.name = name;
    tc.category = cat;
    tc.code = MOV_CR0_R11;
    tc.code.insert(tc.code.end(), insn.begin(), insn.end());
    init.r11 = CR0_GUEST | bits;
    tc.initial = init;
    tc.init_data = std::move(data);
    tc.flags_mask = flags;
    tc.rflags_image_ignore = FL_ARITH & ~flags;
    tc.enable_paging = true;
    if (vec != NONE) {
      tc.expect_fault = true;
      tc.expected_vector = vec;
    }
    tests.push_back(std::move(tc));
  };
  // Where the manuals leave the outcome open, the last case accepts any of
  // the outcomes they allow instead of the one add() gave.
  auto allow = [&](std::vector<int> outcomes) {
    TestCase &tc = tests.back();
    tc.expect_fault = false;
    tc.expected_vector = -1;
    tc.allowed_outcomes = std::move(outcomes);
  };
  const std::vector<int> UD_OR_NM = {UD, NM};
  // An encoding that is #UD, run with TS set (or EM, for an opcode EM
  // gives #NM): the #UD and the #NM are in one class, in no order (SDM
  // Vol.3A Table 7-2, class 9; APM Vol.2 Table 8-9, group 6).  The model
  // raises the #UD; the case accepts either.
  auto add_ud = [&](const std::string &cat, u64 bits, const std::string &name,
                    std::vector<u8> insn, ArchState init = {}) {
    add(cat, bits, name, std::move(insn), UD, init);
    allow(UD_OR_NM);
  };
  // ANDN leaves AF and PF undefined: "AF and PF flags are undefined" (SDM
  // Vol.2A ANDN), "AF U PF U" (APM Vol.3 ANDN).
  auto af_pf_undefined = [&] {
    tests.back().flags_mask &= ~(FL_AF | FL_PF);
    tests.back().rflags_image_ignore |= FL_AF | FL_PF;
  };

  const ArchState mem = {.rdi = DATA_ADDR};
  const ArchState unmapped = {.rsi = UNMAPPED};
  ArchState gprs = {.rax = 0x0123456789ABCDEF, .rbx = 0xFEDCBA9876543210,
                    .rcx = 0x0F0F0F0F0F0F0F0F};
  ArchState vectors;
  for (int i = 0; i < 3; i++)
    for (int q = 0; q < 8; q++)
      vectors.xmm[i].q[q] = 0x0101010101010101ULL * (i + 1) + q;
  for (int i = 1; i < 3; i++) vectors.kregs[i] = 0x5A5A + i;
  const std::vector<u8> mxcsr_1f80 = {0x80, 0x1F, 0x00, 0x00};

  // =====================================================================
  for (u64 bits : {TS, TS | MP}) {
    std::string cat = bits & MP ? "CR0.TS MP" : "CR0.TS";

    // Legacy SSE, register and memory forms; the memory form faults ahead
    // of its #GP (misaligned) or #PF (unmapped).
    add(cat, bits, "addps xmm0,xmm1", {0x0F, 0x58, 0xC1}, NM);
    add(cat, bits, "movaps xmm0,[rdi]", {0x0F, 0x28, 0x07}, NM, mem);
    add(cat, bits, "movaps xmm0,[rdi+8] (misaligned)", {0x0F, 0x28, 0x47, 0x08}, NM, mem);
    add(cat, bits, "movups xmm0,[rsi] (unmapped)", {0x0F, 0x10, 0x06}, NM, unmapped);
    add(cat, bits, "movaps [rsi],xmm1 (unmapped)", {0x0F, 0x29, 0x0E}, NM, unmapped);
    add(cat, bits, "movd xmm0,eax", {0x66, 0x0F, 0x6E, 0xC0}, NM);
    if (host_has(SSE3)) {
      add(cat, bits, "haddps xmm0,xmm1 (SSE3)", {0xF2, 0x0F, 0x7C, 0xC1}, NM);
      add(cat, bits, "lddqu xmm0,[rsi] (SSE3, unmapped)", {0xF2, 0x0F, 0xF0, 0x06}, NM, unmapped);
    }
    if (host_has(SSSE3)) {
      add(cat, bits, "pshufb xmm0,xmm1 (SSSE3)", {0x66, 0x0F, 0x38, 0x00, 0xC1}, NM);
      add(cat, bits, "palignr xmm0,xmm1,4", {0x66, 0x0F, 0x3A, 0x0F, 0xC1, 0x04}, NM);
    }
    if (host_has(SSE4_1)) {
      add(cat, bits, "ptest xmm0,xmm1 (SSE4.1)", {0x66, 0x0F, 0x38, 0x17, 0xC1}, NM);
      add(cat, bits, "movntdqa xmm0,[rsi] (unmapped)", {0x66, 0x0F, 0x38, 0x2A, 0x06}, NM,
          unmapped);
      add(cat, bits, "pextrb [rsi],xmm1,1 (unmapped)", {0x66, 0x0F, 0x3A, 0x14, 0x0E, 0x01}, NM,
          unmapped);
    }
    if (host_has(SSE4_2))
      add(cat, bits, "pcmpistri xmm0,xmm1,0Ch (SSE4.2)", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x0C},
          NM);
    if (host_has(AESNI))
      add(cat, bits, "aesenc xmm0,xmm1", {0x66, 0x0F, 0x38, 0xDC, 0xC1}, NM);
    if (host_has(PCLMULQDQ))
      add(cat, bits, "pclmulqdq xmm0,xmm1,0", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x00}, NM);
    if (host_has(SHA)) {
      add(cat, bits, "sha1nexte xmm0,xmm1", {0x0F, 0x38, 0xC8, 0xC1}, NM);
      add(cat, bits, "sha1rnds4 xmm0,xmm1,0", {0x0F, 0x3A, 0xCC, 0xC1, 0x00}, NM);
    }
    if (host_has(feature::GFNI))
      add(cat, bits, "gf2p8mulb xmm0,xmm1", {0x66, 0x0F, 0x38, 0xCF, 0xC1}, NM);
    add(cat, bits, "ldmxcsr [rsi] (unmapped)", {0x0F, 0xAE, 0x16}, NM, unmapped);
    add(cat, bits, "stmxcsr [rsi] (unmapped)", {0x0F, 0xAE, 0x1E}, NM, unmapped);
    if (host_has(SSE4A))
      add(cat, bits, "extrq xmm0,xmm1 (SSE4A)", {0x66, 0x0F, 0x79, 0xC1}, NM);

    // MMX
    add(cat, bits, "paddb mm0,mm1", {0x0F, 0xFC, 0xC1}, NM);
    add(cat, bits, "movq mm0,[rsi] (unmapped)", {0x0F, 0x6F, 0x06}, NM, unmapped);
    if (host_has(SSSE3)) {
      add(cat, bits, "pshufb mm0,mm1", {0x0F, 0x38, 0x00, 0xC1}, NM);
      add(cat, bits, "palignr mm0,mm1,1", {0x0F, 0x3A, 0x0F, 0xC1, 0x01}, NM);
    }
    add(cat, bits, "cvtpi2ps xmm0,mm1", {0x0F, 0x2A, 0xC1}, NM);
    add(cat, bits, "emms", {0x0F, 0x77}, NM);

    // x87, the control instructions included; WAIT only with MP.
    add(cat, bits, "fld1", {0xD9, 0xE8}, NM);
    add(cat, bits, "fld dword [rsi] (unmapped)", {0xD9, 0x06}, NM, unmapped);
    add(cat, bits, "fnstsw ax", {0xDF, 0xE0}, NM);
    add(cat, bits, "fninit", {0xDB, 0xE3}, NM);
    add(cat, bits, "fnstcw [rsi] (unmapped)", {0xD9, 0x3E}, NM, unmapped);
    if (host_has(SSE3))
      add(cat, bits, "fisttp dword [rsi] (SSE3, unmapped)", {0xDB, 0x0E}, NM, unmapped);
    add(cat, bits, "fwait", {0x9B}, bits & MP ? NM : NONE);

    // The XSAVE family and FXSAVE/FXRSTOR
    ArchState xmask = {.rax = 3, .rdx = 0, .rsi = UNMAPPED};
    add(cat, bits, "fxsave [rsi] (unmapped)", {0x0F, 0xAE, 0x06}, NM, unmapped);
    add(cat, bits, "fxrstor [rsi] (unmapped)", {0x0F, 0xAE, 0x0E}, NM, unmapped);
    add(cat, bits, "fxsave [rdi+8] (misaligned)", {0x0F, 0xAE, 0x47, 0x08}, NM, mem);
    if (host_has(XSAVE)) {
      add(cat, bits, "xsave [rsi] (unmapped)", {0x0F, 0xAE, 0x26}, NM, xmask);
      add(cat, bits, "xrstor [rsi] (unmapped)", {0x0F, 0xAE, 0x2E}, NM, xmask);
    }
    if (host_has(XSAVEOPT))
      add(cat, bits, "xsaveopt [rsi] (unmapped)", {0x0F, 0xAE, 0x36}, NM, xmask);
    if (host_has(XSAVEC))
      add(cat, bits, "xsavec [rsi] (unmapped)", {0x0F, 0xC7, 0x26}, NM, xmask);
    if (host_has(XSAVES)) {
      add(cat, bits, "xsaves [rsi] (unmapped)", {0x0F, 0xC7, 0x2E}, NM, xmask);
      add(cat, bits, "xrstors [rsi] (unmapped)", {0x0F, 0xC7, 0x1E}, NM, xmask);
    }

    // VEX: AVX, AVX2, FMA, F16C, the opmask instructions (class K20/K21)
    if (host_has(AVX)) {
      add(cat, bits, "vaddps ymm0,ymm1,ymm2", {0xC5, 0xF4, 0x58, 0xC2}, NM);
      add(cat, bits, "vmovups ymm0,[rsi] (unmapped)", {0xC5, 0xFC, 0x10, 0x06}, NM, unmapped);
      add(cat, bits, "vmovaps ymm0,[rdi+8] (misaligned)", {0xC5, 0xFC, 0x28, 0x47, 0x08}, NM,
          mem);
      add(cat, bits, "vzeroupper", {0xC5, 0xF8, 0x77}, NM);
      add(cat, bits, "vldmxcsr [rsi] (unmapped)", {0xC5, 0xF8, 0xAE, 0x16}, NM, unmapped);
    }
    if (host_has(AVX2))
      add(cat, bits, "vpgatherdd xmm0,[rsi+xmm1*4],xmm2 (unmapped)",
          {0xC4, 0xE2, 0x69, 0x90, 0x04, 0x8E}, NM, unmapped);
    if (host_has(FMA))
      add(cat, bits, "vfmadd231ps ymm0,ymm1,ymm2", {0xC4, 0xE2, 0x75, 0xB8, 0xC2}, NM);
    if (host_has(F16C))
      add(cat, bits, "vcvtph2ps ymm0,xmm1", {0xC4, 0xE2, 0x7D, 0x13, 0xC1}, NM);
    add(cat, bits, "kmovw k1,k2", {0xC5, 0xF8, 0x90, 0xCA}, NM);
    add(cat, bits, "kmovw k1,[rsi] (unmapped)", {0xC5, 0xF8, 0x90, 0x0E}, NM, unmapped);

    // EVEX
    add(cat, bits, "vaddps zmm0,zmm1,zmm2", {0x62, 0xF1, 0x74, 0x48, 0x58, 0xC2}, NM);
    add(cat, bits, "vmovups zmm0,[rsi] (unmapped)", {0x62, 0xF1, 0x7C, 0x48, 0x10, 0x06}, NM,
        unmapped);
    {
      // A masked-off store to an unmapped page suppresses the #PF.
      ArchState s = unmapped;
      s.kregs[1] = 0;
      add(cat, bits, "vmovups [rsi]{k1},zmm0 (k1 = 0, unmapped)",
          {0x62, 0xF1, 0x7C, 0x49, 0x11, 0x06}, NM, s);
    }
    add(cat, bits, "vpcmpeqd k1,zmm0,zmm1", {0x62, 0xF1, 0x7D, 0x48, 0x76, 0xC9}, NM);
    add(cat, bits, "vpgatherdd zmm0{k1},[rsi+zmm1*4] (unmapped)",
        {0x62, 0xF2, 0x7D, 0x49, 0x90, 0x04, 0x8E}, NM, unmapped);

    // Unaffected
    if (host_has(SSE4_2))
      add(cat, bits, "crc32 eax,ebx", {0xF2, 0x0F, 0x38, 0xF1, 0xC3}, NONE, gprs);
    if (host_has(POPCNT))
      add(cat, bits, "popcnt eax,ebx", {0xF3, 0x0F, 0xB8, 0xC3}, NONE, gprs);
    {
      ArchState s = gprs;
      s.rdi = DATA_ADDR;
      add(cat, bits, "movnti [rdi],eax", {0x0F, 0xC3, 0x07}, NONE, s);
    }
    add(cat, bits, "pause", {0xF3, 0x90}, NONE);
    add(cat, bits, "prefetcht0 [rdi]", {0x0F, 0x18, 0x0F}, NONE, mem);
    add(cat, bits, "sfence", {0x0F, 0xAE, 0xF8}, NONE);
    add(cat, bits, "lfence", {0x0F, 0xAE, 0xE8}, NONE);
    add(cat, bits, "mfence", {0x0F, 0xAE, 0xF0}, NONE);
    add(cat, bits, "clflush [rdi]", {0x0F, 0xAE, 0x3F}, NONE, mem);
    if (host_has(BMI1)) {
      add(cat, bits, "andn eax,ebx,ecx (BMI1)", {0xC4, 0xE2, 0x60, 0xF2, 0xC1}, NONE, gprs);
      af_pf_undefined();
    }
    if (host_has(BMI2))
      add(cat, bits, "rorx eax,ebx,3 (BMI2)", {0xC4, 0xE3, 0x7B, 0xF0, 0xC3, 0x03}, NONE, gprs);
    if (host_has(XSAVE)) {
      ArchState s = {.rcx = 0};
      add(cat, bits, "xgetbv (ecx = 0)", {0x0F, 0x01, 0xD0}, NONE, s);
    }
    if (host_has_amx()) {
      add(cat, bits, "tilerelease", {0xC4, 0xE2, 0x78, 0x49, 0xC0}, NONE);
      tests.back().xcr0_override = AMX_XCR0;
      add(cat, bits, "ldtilecfg [rsi] (unmapped)", {0xC4, 0xE2, 0x78, 0x49, 0x06}, 14, unmapped);
      tests.back().xcr0_override = AMX_XCR0;
    }

    // Encodings that are #UD: undefined opcodes, mandatory prefixes,
    // ModR/M.reg extensions and r/m forms, LOCK, and register operands an
    // instruction forbids.  With TS set they may raise either fault
    // (add_ud).
    add_ud(cat, bits, "F2 0F 14 (unpcklps with F2) #UD", {0xF2, 0x0F, 0x14, 0xC1});
    add_ud(cat, bits, "66 0F 13 /r reg (movlpd store, register form) #UD",
           {0x66, 0x0F, 0x13, 0xC1});
    add_ud(cat, bits, "lock addps #UD", {0xF0, 0x0F, 0x58, 0xC1});
    add_ud(cat, bits, "66 0F 71 /0 (group 12, /0) #UD", {0x66, 0x0F, 0x71, 0xC1, 0x00});
    add_ud(cat, bits, "F3 0F 38 00 (pshufb with F3) #UD", {0xF3, 0x0F, 0x38, 0x00, 0xC1});
    add_ud(cat, bits, "66 0F 38 2A reg (movntdqa, register form) #UD",
           {0x66, 0x0F, 0x38, 0x2A, 0xC1});
    add_ud(cat, bits, "66 0F 38 FF (undefined) #UD", {0x66, 0x0F, 0x38, 0xFF, 0xC1});
    add_ud(cat, bits, "F3 0F 3A 0F (palignr with F3) #UD", {0xF3, 0x0F, 0x3A, 0x0F, 0xC1, 0x01});
    add_ud(cat, bits, "66 0F 3A FF (undefined) #UD", {0x66, 0x0F, 0x3A, 0xFF, 0xC1, 0x00});
    add_ud(cat, bits, "66 0F 77 (emms with 66) #UD", {0x66, 0x0F, 0x77});
    add_ud(cat, bits, "0F AE /2 reg (ldmxcsr, register form) #UD", {0x0F, 0xAE, 0xD0});
    add_ud(cat, bits, "0F AE /0 reg (fxsave, register form) #UD", {0x0F, 0xAE, 0xC0});
    add_ud(cat, bits, "0F C7 /4 reg (xsavec, register form) #UD", {0x0F, 0xC7, 0xE0});
    add_ud(cat, bits, "lock fld1 #UD", {0xF0, 0xD9, 0xE8});
    add_ud(cat, bits, "vmovd xmm0,eax with vvvv = 1110b #UD", {0xC5, 0xF1, 0x6E, 0xC0});
    add_ud(cat, bits, "vmovd xmm0,eax with VEX.L = 1 #UD", {0xC5, 0xFD, 0x6E, 0xC0});
    add_ud(cat, bits, "VEX.128.66.0F 71 /0 #UD", {0xC5, 0xF9, 0x71, 0xC1, 0x00});
    add_ud(cat, bits, "VEX.0F AE /4 (no vxsave) #UD", {0xC5, 0xF8, 0xAE, 0x27}, mem);
    add_ud(cat, bits, "vpgatherdd xmm0,[rsi+xmm0*4],xmm2 (destination = index) #UD",
           {0xC4, 0xE2, 0x69, 0x90, 0x04, 0x86}, unmapped);
    add_ud(cat, bits, "vpgatherdd xmm0,[rsi+xmm1*4],xmm0 (destination = mask) #UD",
           {0xC4, 0xE2, 0x79, 0x90, 0x04, 0x8E}, unmapped);
    add_ud(cat, bits, "vpgatherdd xmm0,[rsi],xmm2 (no SIB) #UD", {0xC4, 0xE2, 0x69, 0x90, 0x06},
           unmapped);
    // An opmask register above k7, in ModR/M.reg (VEX.R set): "VEX.R == 0
    // | When ModR/M.reg specifies a K register | #UD", "Cannot specify a K
    // Register above k7" (APM Vol.4 §3.2.5); or in VEX.vvvv (bit 3 set):
    // "K-regs are instruction operands not mask control. | If vvvv =
    // 0xxxb" (SDM Vol.2A Table 2-42; the APM has no rule for vvvv).
    add_ud(cat, bits, "kandw k1,k10,k3 (vvvv bit 3)", {0xC5, 0xAC, 0x41, 0xCB});
    add_ud(cat, bits, "kmovw k9,k2 (VEX.R)", {0xC5, 0x78, 0x90, 0xCA});
    add_ud(cat, bits, "vaddps zmm0{z},zmm1,zmm2 (zeroing without a mask) #UD",
           {0x62, 0xF1, 0x74, 0xC8, 0x58, 0xC2});
    add_ud(cat, bits, "vaddps with EVEX.L'L = 11b #UD", {0x62, 0xF1, 0x74, 0x68, 0x58, 0xC2});
    add_ud(cat, bits, "vpgatherdd zmm0{k1},[rsi+zmm0*4] (destination = index) #UD",
           {0x62, 0xF2, 0x7D, 0x49, 0x90, 0x04, 0x86}, unmapped);
    add_ud(cat, bits, "vpgatherdd zmm0,[rsi+zmm1*4] (k0) #UD",
           {0x62, 0xF2, 0x7D, 0x48, 0x90, 0x04, 0x8E}, unmapped);
    add_ud(cat, bits, "vpgatherdd zmm0{k1},[rsi] (no SIB) #UD",
           {0x62, 0xF2, 0x7D, 0x49, 0x90, 0x06}, unmapped);
    add_ud(cat, bits, "vpscatterdd [rsi]{k1},zmm0 (no SIB) #UD",
           {0x62, 0xF2, 0x7D, 0x49, 0xA0, 0x06}, unmapped);
    add_ud(cat, bits, "vpcmpeqd k1,zmm0,zmm1 with EVEX.R #UD",
           {0x62, 0x71, 0x7D, 0x48, 0x76, 0xC9});
    add_ud(cat, bits, "vpcmpeqd k1,zmm0,zmm1 with EVEX.R' #UD",
           {0x62, 0xE1, 0x7D, 0x48, 0x76, 0xC9});
    add_ud(cat, bits, "v4fmaddps (AVX512_4FMAPS) #UD", {0x62, 0xF2, 0x77, 0x48, 0x9A, 0x06},
           unmapped);
    add_ud(cat, bits, "vfcmulcph zmm0,zmm0,zmm1 (destination = source) #UD",
           {0x62, 0xF6, 0x7F, 0x48, 0xD6, 0xC1});

    // Encodings that are no instruction but whose opcode is that of an x87
    // instruction or of FXSAVE and FXRSTOR: an undefined D8-DF form (APM
    // Vol.3 Table A-15 "invalid"), and 0F AE /0 and /1 with a memory
    // operand, which are FXSAVE and FXRSTOR without a prefix only (SDM "NP
    // 0F AE /0"; APM Vol.3 Table A-7), under a 66, F2 or F3 prefix and
    // VEX- or EVEX-encoded.  They are #UD with CR0.EM = CR0.TS = 0 (the
    // cases below with bits 0), and with TS set either fault (add_ud), as
    // with a LOCK prefix.
    add_ud(cat, bits, "D9 D1 (undefined x87)", {0xD9, 0xD1});
    add_ud(cat, bits, "66 0F AE /0 (fxsave with 66)", {0x66, 0x0F, 0xAE, 0x07}, mem);
    add_ud(cat, bits, "F3 0F AE /1 (fxrstor with F3)", {0xF3, 0x0F, 0xAE, 0x0F}, mem);
    add_ud(cat, bits, "VEX.0F AE /0", {0xC5, 0xF8, 0xAE, 0x07}, mem);
    add_ud(cat, bits, "VEX.256.66.0F AE /1", {0xC5, 0xFD, 0xAE, 0x0F}, mem);
    add_ud(cat, bits, "EVEX.0F AE /0", {0x62, 0xF1, 0x7C, 0x48, 0xAE, 0x07}, mem);
    add_ud(cat, bits, "lock fxsave #UD", {0xF0, 0x0F, 0xAE, 0x07}, mem);
  }
  for (const auto &[name, insn] : std::vector<std::pair<std::string, std::vector<u8>>>{
           {"D9 D1 (undefined x87) #UD", {0xD9, 0xD1}},
           {"66 0F AE /0 (fxsave with 66) #UD", {0x66, 0x0F, 0xAE, 0x07}},
           {"VEX.0F AE /0 #UD", {0xC5, 0xF8, 0xAE, 0x07}},
           {"EVEX.0F AE /0 #UD", {0x62, 0xF1, 0x7C, 0x48, 0xAE, 0x07}}})
    add("CR0.TS", 0, name + " (CR0.TS = 0)", insn, UD, mem);

  // =====================================================================
  for (u64 bits : {EM, EM | TS, EM | MP, EM | MP | TS}) {
    std::string cat = "CR0.EM";
    // " [EM]", " [EM MP]", " [EM TS]", " [EM MP TS]"
    std::string tag = std::string(" [EM") + (bits & MP ? " MP" : "") + (bits & TS ? " TS" : "");
    auto name = [&](const std::string &n) { return n + tag + "]"; };

    // Legacy SSE and MMX: #UD.  With TS set as well, #UD on Intel (SDM
    // Vol.3A §2.5, Tables 15-1 and 16-1); the APM gives the #UD of EM
    // (Vol.2 §3.1.1) and the #NM of TS in no order (Table 8-9, group 6).
    auto add_media = [&](const std::string &n, std::vector<u8> insn, ArchState init = {}) {
      add(cat, bits, name(n), std::move(insn), UD, init);
      if (amd_host && bits & TS) allow(UD_OR_NM);
    };
    add_media("addps xmm0,xmm1", {0x0F, 0x58, 0xC1});
    add_media("movups xmm0,[rsi] (unmapped)", {0x0F, 0x10, 0x06}, unmapped);
    add_media("pshufb xmm0,xmm1", {0x66, 0x0F, 0x38, 0x00, 0xC1});
    add_media("palignr xmm0,xmm1,4", {0x66, 0x0F, 0x3A, 0x0F, 0xC1, 0x04});
    add_media("aesenc xmm0,xmm1", {0x66, 0x0F, 0x38, 0xDC, 0xC1});
    add_media("sha1nexte xmm0,xmm1", {0x0F, 0x38, 0xC8, 0xC1});
    add_media("ldmxcsr [rsi] (unmapped)", {0x0F, 0xAE, 0x16}, unmapped);
    add_media("stmxcsr [rsi] (unmapped)", {0x0F, 0xAE, 0x1E}, unmapped);
    if (host_has(SSE4A)) add_media("extrq xmm0,xmm1 (SSE4A)", {0x66, 0x0F, 0x79, 0xC1});
    add_media("paddb mm0,mm1", {0x0F, 0xFC, 0xC1});
    add_media("pshufb mm0,mm1", {0x0F, 0x38, 0x00, 0xC1});
    add_media("cvtpi2ps xmm0,mm1", {0x0F, 0x2A, 0xC1});
    add_media("emms", {0x0F, 0x77});

    // x87 and FXSAVE/FXRSTOR: #NM.  WAIT: #NM only with TS and MP.  An
    // undefined x87 form and the FXSAVE opcode under a prefix or VEX/EVEX
    // are no instruction: their #UD and the #NM that EM gives the x87
    // instructions and FXSAVE are in one class, in no order (add_ud).
    add(cat, bits, name("fld1"), {0xD9, 0xE8}, NM);
    add(cat, bits, name("fnstsw ax"), {0xDF, 0xE0}, NM);
    add(cat, bits, name("fninit"), {0xDB, 0xE3}, NM);
    add(cat, bits, name("fld dword [rsi] (unmapped)"), {0xD9, 0x06}, NM, unmapped);
    add(cat, bits, name("fwait"), {0x9B}, (bits & (MP | TS)) == (MP | TS) ? NM : NONE);
    add(cat, bits, name("fxsave [rsi] (unmapped)"), {0x0F, 0xAE, 0x06}, NM, unmapped);
    add(cat, bits, name("fxrstor [rsi] (unmapped)"), {0x0F, 0xAE, 0x0E}, NM, unmapped);
    add_ud(cat, bits, name("D9 D1 (undefined x87)"), {0xD9, 0xD1});
    add_ud(cat, bits, name("66 0F AE /0 (fxsave with 66)"), {0x66, 0x0F, 0xAE, 0x07}, mem);
    add_ud(cat, bits, name("VEX.0F AE /0"), {0xC5, 0xF8, 0xAE, 0x07}, mem);
    add_ud(cat, bits, name("EVEX.0F AE /1"), {0x62, 0xF1, 0x7C, 0x48, 0xAE, 0x0F}, mem);

    // The XSAVE family and the VEX forms of SSE instructions ignore EM; TS
    // still applies.
    int ts = bits & TS ? NM : NONE;
    if (host_has(XSAVE)) {
      ArchState s = with_xsave_vector_inputs({.rax = 3, .rdx = 0, .rdi = DATA_ADDR}, 3);
      add(cat, bits, name("xsave [rdi] (x87, SSE)"), {0x0F, 0xAE, 0x27}, ts, s);
      // Both components are in their initial configuration, for which
      // XSTATE_BV[i] "may be written with either 0 or 1" (SDM Vol.1 §13.7).
      if (ts == NONE) {
        fxsave_x87_undefined(tests.back(), 0, 0);
        tests.back().data_undefined.push_back({0x200, 0x03});
      }
    }
    {
      ArchState s = vectors;
      s.rdi = DATA_ADDR;
      // For the VEX SIMD instructions the APM contradicts itself (Vol.2
      // §8.2.7: #UD for "any SSE instruction (uses ZMM/YMM/XMM registers)
      // ... when CR0.EM = 1"; the PADDD/VPADDD and LDMXCSR/VLDMXCSR pages:
      // the EM row for the SSE forms only), so an AMD host may raise #UD.
      if (host_has(AVX2)) {
        add(cat, bits, name("vpaddd ymm0,ymm1,ymm2"), {0xC5, 0xF5, 0xFE, 0xC2}, ts, s);
        if (amd_host) allow({UD, ts});
      }
      if (host_has(AVX)) {
        add(cat, bits, name("vldmxcsr [rdi]"), {0xC5, 0xF8, 0xAE, 0x17}, ts, s, mxcsr_1f80);
        if (amd_host) allow({UD, ts});
        add(cat, bits, name("vstmxcsr [rdi]"), {0xC5, 0xF8, 0xAE, 0x1F}, ts, s);
        if (amd_host) allow({UD, ts});
      }
      // AVX-512, EVEX and the opmask instructions: the SDM's classes
      // (E1-E12, K20, K21) give EM no rule; the APM gives it #UD (Vol.4
      // §3.2.1), and with TS set as well #UD or #NM, in no order.
      int em_amd = amd_host ? UD : ts;
      add(cat, bits, name("vpaddd zmm0,zmm1,zmm2"), {0x62, 0xF1, 0x75, 0x48, 0xFE, 0xC2}, em_amd,
          s);
      if (amd_host && bits & TS) allow(UD_OR_NM);
      add(cat, bits, name("kmovw k1,k2"), {0xC5, 0xF8, 0x90, 0xCA}, em_amd, s);
      if (amd_host && bits & TS) allow(UD_OR_NM);
      // The VEX SIMD instructions without a legacy SSE form: the SDM's
      // classes (Types 4, 6 and 8) give EM no rule; the APM gives it #UD
      // (Vol.2 §8.2.7; Classes 4G, 4H and 4H-1 name it, the others do not
      // contradict it), and with TS set as well #UD or #NM, in no order.
      // One of each kind of class: 4G, 4H, 4H-1, 4J, 4K, 6B, 6D-X, 8.
      using Case = std::tuple<std::string, CpuidBit, std::vector<u8>>;
      for (const auto &[n, needs, insn] : std::vector<Case>{
               {"vtestps xmm1,xmm2", AVX, {0xC4, 0xE2, 0x79, 0x0E, 0xCA}},
               {"vpermd ymm0,ymm1,ymm2", AVX2, {0xC4, 0xE2, 0x75, 0x36, 0xC2}},
               {"vpermq ymm0,ymm1,1Bh", AVX2, {0xC4, 0xE3, 0xFD, 0x00, 0xC1, 0x1B}},
               {"vpblendd ymm0,ymm1,ymm2,55h", AVX2, {0xC4, 0xE3, 0x75, 0x02, 0xC2, 0x55}},
               {"vpsllvd ymm0,ymm1,ymm2", AVX2, {0xC4, 0xE2, 0x75, 0x47, 0xC2}},
               {"vinserti128 ymm0,ymm1,xmm2,1", AVX2, {0xC4, 0xE3, 0x75, 0x38, 0xC2, 0x01}},
               {"vbroadcastss ymm0,xmm1", AVX2, {0xC4, 0xE2, 0x7D, 0x18, 0xC1}},
               {"vzeroupper", AVX, {0xC5, 0xF8, 0x77}}}) {
        if (!host_has(needs)) continue;
        add(cat, bits, name(n), insn, em_amd, s);
        if (amd_host && bits & TS) allow(UD_OR_NM);
      }
    }

    // Unaffected
    if (host_has(SSE4_2))
      add(cat, bits, name("crc32 eax,ebx"), {0xF2, 0x0F, 0x38, 0xF1, 0xC3}, NONE, gprs);
    if (host_has(POPCNT))
      add(cat, bits, name("popcnt eax,ebx"), {0xF3, 0x0F, 0xB8, 0xC3}, NONE, gprs);
    if (host_has(BMI1)) {
      add(cat, bits, name("andn eax,ebx,ecx (BMI1)"), {0xC4, 0xE2, 0x60, 0xF2, 0xC1}, NONE,
          gprs);
      af_pf_undefined();
    }
    add(cat, bits, name("sfence"), {0x0F, 0xAE, 0xF8}, NONE);
    add(cat, bits, name("clflush [rdi]"), {0x0F, 0xAE, 0x3F}, NONE, mem);
  }
}

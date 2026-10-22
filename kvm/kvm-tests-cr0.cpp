// CR0.TS, CR0.EM and CR0.MP, and the instructions they stop: each case
// writes CR0 from R11 and then executes one instruction, which raises #NM
// or #UD or completes.  The harness restores CR0 before every case.
//
// The SDM's rules (Vol.3A §2.5, Table 2-2; Vol.2A §§2.5, 2.8 and 2.9, the
// exception classes; Vol.3B §23.25.3 for MMX; the instruction pages):
//   - TS = 1: #NM before any x87, MMX, SSE, AVX or AVX-512 instruction,
//     the XSAVE family, FXSAVE/FXRSTOR, LDMXCSR/STMXCSR and EMMS; not
//     before PAUSE, PREFETCHh, SFENCE, LFENCE, MFENCE, MOVNTI, CLFLUSH,
//     CRC32, POPCNT, the VEX-encoded general-purpose instructions (BMI1,
//     BMI2: exception class 13) or XGETBV.
//   - EM = 1: #UD for MMX, legacy SSE (not VEX or EVEX), LDMXCSR/STMXCSR
//     and EMMS, whatever TS; #NM for x87 and FXSAVE/FXRSTOR.
//   - WAIT/FWAIT: #NM only when TS = 1 and MP = 1.
//   - #NM and #UD are both faults from decoding the instruction (Vol.3A
//     §7.9, Table 7-2), ahead of the faults of its memory operands.
// An Emerald Rapids raises every #UD the encoding decides ahead of the
// #NM, register operands an instruction forbids included.
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
  __cpuid_count(7, 0, a, b, c, d);
  const bool amx_host = d & (1u << 24);  // AMX-TILE
  const bool fp16_host = d & (1u << 23);  // AVX512-FP16
  const u64 AMX_XCR0 = 0xE7 | (3ULL << 17);
  // MOV to CR0 leaves the arithmetic flags undefined on Intel (SDM Vol.2B
  // MOV, control registers); AMD preserves them.
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
    add(cat, bits, "haddps xmm0,xmm1 (SSE3)", {0xF2, 0x0F, 0x7C, 0xC1}, NM);
    add(cat, bits, "lddqu xmm0,[rsi] (SSE3, unmapped)", {0xF2, 0x0F, 0xF0, 0x06}, NM, unmapped);
    add(cat, bits, "pshufb xmm0,xmm1 (SSSE3)", {0x66, 0x0F, 0x38, 0x00, 0xC1}, NM);
    add(cat, bits, "ptest xmm0,xmm1 (SSE4.1)", {0x66, 0x0F, 0x38, 0x17, 0xC1}, NM);
    add(cat, bits, "movntdqa xmm0,[rsi] (unmapped)", {0x66, 0x0F, 0x38, 0x2A, 0x06}, NM, unmapped);
    add(cat, bits, "palignr xmm0,xmm1,4", {0x66, 0x0F, 0x3A, 0x0F, 0xC1, 0x04}, NM);
    add(cat, bits, "pextrb [rsi],xmm1,1 (unmapped)", {0x66, 0x0F, 0x3A, 0x14, 0x0E, 0x01}, NM,
        unmapped);
    add(cat, bits, "pcmpistri xmm0,xmm1,0Ch (SSE4.2)", {0x66, 0x0F, 0x3A, 0x63, 0xC1, 0x0C}, NM);
    add(cat, bits, "aesenc xmm0,xmm1", {0x66, 0x0F, 0x38, 0xDC, 0xC1}, NM);
    add(cat, bits, "pclmulqdq xmm0,xmm1,0", {0x66, 0x0F, 0x3A, 0x44, 0xC1, 0x00}, NM);
    add(cat, bits, "sha1nexte xmm0,xmm1", {0x0F, 0x38, 0xC8, 0xC1}, NM);
    add(cat, bits, "sha1rnds4 xmm0,xmm1,0", {0x0F, 0x3A, 0xCC, 0xC1, 0x00}, NM);
    add(cat, bits, "gf2p8mulb xmm0,xmm1", {0x66, 0x0F, 0x38, 0xCF, 0xC1}, NM);
    add(cat, bits, "ldmxcsr [rsi] (unmapped)", {0x0F, 0xAE, 0x16}, NM, unmapped);
    add(cat, bits, "stmxcsr [rsi] (unmapped)", {0x0F, 0xAE, 0x1E}, NM, unmapped);
    if (amd_host)
      add(cat, bits, "extrq xmm0,xmm1 (SSE4A)", {0x66, 0x0F, 0x79, 0xC1}, NM);

    // MMX
    add(cat, bits, "paddb mm0,mm1", {0x0F, 0xFC, 0xC1}, NM);
    add(cat, bits, "movq mm0,[rsi] (unmapped)", {0x0F, 0x6F, 0x06}, NM, unmapped);
    add(cat, bits, "pshufb mm0,mm1", {0x0F, 0x38, 0x00, 0xC1}, NM);
    add(cat, bits, "palignr mm0,mm1,1", {0x0F, 0x3A, 0x0F, 0xC1, 0x01}, NM);
    add(cat, bits, "cvtpi2ps xmm0,mm1", {0x0F, 0x2A, 0xC1}, NM);
    add(cat, bits, "emms", {0x0F, 0x77}, NM);

    // x87, the control instructions included; WAIT only with MP.
    add(cat, bits, "fld1", {0xD9, 0xE8}, NM);
    add(cat, bits, "fld dword [rsi] (unmapped)", {0xD9, 0x06}, NM, unmapped);
    add(cat, bits, "fnstsw ax", {0xDF, 0xE0}, NM);
    add(cat, bits, "fninit", {0xDB, 0xE3}, NM);
    add(cat, bits, "fnstcw [rsi] (unmapped)", {0xD9, 0x3E}, NM, unmapped);
    add(cat, bits, "fisttp dword [rsi] (SSE3, unmapped)", {0xDB, 0x0E}, NM, unmapped);
    add(cat, bits, "fwait", {0x9B}, bits & MP ? NM : NONE);

    // The XSAVE family and FXSAVE/FXRSTOR
    ArchState xmask = {.rax = 3, .rdx = 0, .rsi = UNMAPPED};
    add(cat, bits, "fxsave [rsi] (unmapped)", {0x0F, 0xAE, 0x06}, NM, unmapped);
    add(cat, bits, "fxrstor [rsi] (unmapped)", {0x0F, 0xAE, 0x0E}, NM, unmapped);
    add(cat, bits, "fxsave [rdi+8] (misaligned)", {0x0F, 0xAE, 0x47, 0x08}, NM, mem);
    add(cat, bits, "xsave [rsi] (unmapped)", {0x0F, 0xAE, 0x26}, NM, xmask);
    add(cat, bits, "xrstor [rsi] (unmapped)", {0x0F, 0xAE, 0x2E}, NM, xmask);
    add(cat, bits, "xsaveopt [rsi] (unmapped)", {0x0F, 0xAE, 0x36}, NM, xmask);
    add(cat, bits, "xsavec [rsi] (unmapped)", {0x0F, 0xC7, 0x26}, NM, xmask);
    add(cat, bits, "xsaves [rsi] (unmapped)", {0x0F, 0xC7, 0x2E}, NM, xmask);
    add(cat, bits, "xrstors [rsi] (unmapped)", {0x0F, 0xC7, 0x1E}, NM, xmask);

    // VEX: AVX, AVX2, FMA, F16C, the opmask instructions (class K20/K21)
    add(cat, bits, "vaddps ymm0,ymm1,ymm2", {0xC5, 0xF4, 0x58, 0xC2}, NM);
    add(cat, bits, "vmovups ymm0,[rsi] (unmapped)", {0xC5, 0xFC, 0x10, 0x06}, NM, unmapped);
    add(cat, bits, "vmovaps ymm0,[rdi+8] (misaligned)", {0xC5, 0xFC, 0x28, 0x47, 0x08}, NM, mem);
    add(cat, bits, "vzeroupper", {0xC5, 0xF8, 0x77}, NM);
    add(cat, bits, "vldmxcsr [rsi] (unmapped)", {0xC5, 0xF8, 0xAE, 0x16}, NM, unmapped);
    add(cat, bits, "vpgatherdd xmm0,[rsi+xmm1*4],xmm2 (unmapped)",
        {0xC4, 0xE2, 0x69, 0x90, 0x04, 0x8E}, NM, unmapped);
    add(cat, bits, "vfmadd231ps ymm0,ymm1,ymm2", {0xC4, 0xE2, 0x75, 0xB8, 0xC2}, NM);
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
    add(cat, bits, "crc32 eax,ebx", {0xF2, 0x0F, 0x38, 0xF1, 0xC3}, NONE, gprs);
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
    add(cat, bits, "andn eax,ebx,ecx (BMI1)", {0xC4, 0xE2, 0x60, 0xF2, 0xC1}, NONE, gprs);
    add(cat, bits, "rorx eax,ebx,3 (BMI2)", {0xC4, 0xE3, 0x7B, 0xF0, 0xC3, 0x03}, NONE, gprs);
    {
      ArchState s = {.rcx = 0};
      add(cat, bits, "xgetbv (ecx = 0)", {0x0F, 0x01, 0xD0}, NONE, s);
    }
    if (amx_host) {
      add(cat, bits, "tilerelease", {0xC4, 0xE2, 0x78, 0x49, 0xC0}, NONE);
      tests.back().xcr0_override = AMX_XCR0;
      add(cat, bits, "ldtilecfg [rsi] (unmapped)", {0xC4, 0xE2, 0x78, 0x49, 0x06}, 14, unmapped);
      tests.back().xcr0_override = AMX_XCR0;
    }

    // Undefined encodings: #UD, a fault from decoding like #NM, comes first.
    add(cat, bits, "F2 0F 14 (unpcklps with F2) #UD", {0xF2, 0x0F, 0x14, 0xC1}, UD);
    add(cat, bits, "66 0F 13 /r reg (movlpd store, register form) #UD",
        {0x66, 0x0F, 0x13, 0xC1}, UD);
    add(cat, bits, "lock addps #UD", {0xF0, 0x0F, 0x58, 0xC1}, UD);
    add(cat, bits, "66 0F 71 /0 (group 12, /0) #UD", {0x66, 0x0F, 0x71, 0xC1, 0x00}, UD);
    add(cat, bits, "F3 0F 38 00 (pshufb with F3) #UD", {0xF3, 0x0F, 0x38, 0x00, 0xC1}, UD);
    add(cat, bits, "66 0F 38 2A reg (movntdqa, register form) #UD",
        {0x66, 0x0F, 0x38, 0x2A, 0xC1}, UD);
    add(cat, bits, "66 0F 38 FF (undefined) #UD", {0x66, 0x0F, 0x38, 0xFF, 0xC1}, UD);
    add(cat, bits, "F3 0F 3A 0F (palignr with F3) #UD", {0xF3, 0x0F, 0x3A, 0x0F, 0xC1, 0x01}, UD);
    add(cat, bits, "66 0F 3A FF (undefined) #UD", {0x66, 0x0F, 0x3A, 0xFF, 0xC1, 0x00}, UD);
    add(cat, bits, "66 0F 77 (emms with 66) #UD", {0x66, 0x0F, 0x77}, UD);
    add(cat, bits, "0F AE /2 reg (ldmxcsr, register form) #UD", {0x0F, 0xAE, 0xD0}, UD);
    add(cat, bits, "0F AE /0 reg (fxsave, register form) #UD", {0x0F, 0xAE, 0xC0}, UD);
    add(cat, bits, "0F C7 /4 reg (xsavec, register form) #UD", {0x0F, 0xC7, 0xE0}, UD);
    add(cat, bits, "lock fld1 #UD", {0xF0, 0xD9, 0xE8}, UD);
    add(cat, bits, "vmovd xmm0,eax with vvvv = 1110b #UD", {0xC5, 0xF1, 0x6E, 0xC0}, UD);
    add(cat, bits, "vmovd xmm0,eax with VEX.L = 1 #UD", {0xC5, 0xFD, 0x6E, 0xC0}, UD);
    add(cat, bits, "VEX.128.66.0F 71 /0 #UD", {0xC5, 0xF9, 0x71, 0xC1, 0x00}, UD);
    add(cat, bits, "VEX.0F AE /4 (no vxsave) #UD", {0xC5, 0xF8, 0xAE, 0x27}, UD, mem);
    add(cat, bits, "vpgatherdd xmm0,[rsi+xmm0*4],xmm2 (destination = index) #UD",
        {0xC4, 0xE2, 0x69, 0x90, 0x04, 0x86}, UD, unmapped);
    add(cat, bits, "vpgatherdd xmm0,[rsi+xmm1*4],xmm0 (destination = mask) #UD",
        {0xC4, 0xE2, 0x79, 0x90, 0x04, 0x8E}, UD, unmapped);
    add(cat, bits, "vpgatherdd xmm0,[rsi],xmm2 (no SIB) #UD", {0xC4, 0xE2, 0x69, 0x90, 0x06}, UD,
        unmapped);
    // An opmask in ModR/M.reg with VEX.R set, or in VEX.vvvv with its bit
    // 3 set: #UD on Intel, ignored on AMD.
    add(cat, bits, "kandw k1,k10,k3 (vvvv bit 3)", {0xC5, 0xAC, 0x41, 0xCB}, amd_host ? NM : UD);
    add(cat, bits, "kmovw k9,k2 (VEX.R)", {0xC5, 0x78, 0x90, 0xCA}, amd_host ? NM : UD);
    add(cat, bits, "vaddps zmm0{z},zmm1,zmm2 (zeroing without a mask) #UD",
        {0x62, 0xF1, 0x74, 0xC8, 0x58, 0xC2}, UD);
    add(cat, bits, "vaddps with EVEX.L'L = 11b #UD", {0x62, 0xF1, 0x74, 0x68, 0x58, 0xC2}, UD);
    add(cat, bits, "vpgatherdd zmm0{k1},[rsi+zmm0*4] (destination = index) #UD",
        {0x62, 0xF2, 0x7D, 0x49, 0x90, 0x04, 0x86}, UD, unmapped);
    add(cat, bits, "vpgatherdd zmm0,[rsi+zmm1*4] (k0) #UD", {0x62, 0xF2, 0x7D, 0x48, 0x90, 0x04, 0x8E},
        UD, unmapped);
    add(cat, bits, "vpgatherdd zmm0{k1},[rsi] (no SIB) #UD", {0x62, 0xF2, 0x7D, 0x49, 0x90, 0x06},
        UD, unmapped);
    add(cat, bits, "vpscatterdd [rsi]{k1},zmm0 (no SIB) #UD", {0x62, 0xF2, 0x7D, 0x49, 0xA0, 0x06},
        UD, unmapped);
    add(cat, bits, "vpcmpeqd k1,zmm0,zmm1 with EVEX.R #UD", {0x62, 0x71, 0x7D, 0x48, 0x76, 0xC9},
        UD);
    add(cat, bits, "vpcmpeqd k1,zmm0,zmm1 with EVEX.R' #UD", {0x62, 0xE1, 0x7D, 0x48, 0x76, 0xC9},
        UD);
    add(cat, bits, "v4fmaddps (AVX512_4FMAPS) #UD", {0x62, 0xF2, 0x77, 0x48, 0x9A, 0x06}, UD,
        unmapped);
    if (fp16_host)
      add(cat, bits, "vfcmulcph zmm0,zmm0,zmm1 (destination = source) #UD",
          {0x62, 0xF6, 0x7F, 0x48, 0xD6, 0xC1}, UD);

    // Encodings that are no instruction but whose opcode is that of an x87
    // instruction or of FXSAVE and FXRSTOR: an undefined D8-DF form (APM
    // Vol.3 Table A-15 "invalid"), and 0F AE /0 and /1 with a memory
    // operand, which are FXSAVE and FXRSTOR without a prefix only (SDM "NP
    // 0F AE /0"; APM Vol.3 Table A-7), under a 66, F2 or F3 prefix and
    // VEX- or EVEX-encoded.  They are #UD with CR0.EM = CR0.TS = 0 (the
    // cases below with bits 0), and with TS set either fault, which the
    // manuals do not order (SDM Vol.3A Table 7-2, class 9; APM Vol.2 Table
    // 8-9, group 6).  The model raises the #UD.  A LOCK prefix is #UD
    // first.
    add(cat, bits, "D9 D1 (undefined x87)", {0xD9, 0xD1}, UD);
    allow(UD_OR_NM);
    add(cat, bits, "66 0F AE /0 (fxsave with 66)", {0x66, 0x0F, 0xAE, 0x07}, UD, mem);
    allow(UD_OR_NM);
    add(cat, bits, "F3 0F AE /1 (fxrstor with F3)", {0xF3, 0x0F, 0xAE, 0x0F}, UD, mem);
    allow(UD_OR_NM);
    add(cat, bits, "VEX.0F AE /0", {0xC5, 0xF8, 0xAE, 0x07}, UD, mem);
    allow(UD_OR_NM);
    add(cat, bits, "VEX.256.66.0F AE /1", {0xC5, 0xFD, 0xAE, 0x0F}, UD, mem);
    allow(UD_OR_NM);
    add(cat, bits, "EVEX.0F AE /0", {0x62, 0xF1, 0x7C, 0x48, 0xAE, 0x07}, UD, mem);
    allow(UD_OR_NM);
    add(cat, bits, "lock fxsave #UD", {0xF0, 0x0F, 0xAE, 0x07}, UD, mem);
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
    std::string tag = (bits & MP ? std::string(" MP") : "") + (bits & TS ? " TS" : "");
    auto name = [&](const std::string &n) { return n + (tag.empty() ? "" : " [" + tag.substr(1) + "]"); };

    // Legacy SSE and MMX: #UD, whatever TS.
    add(cat, bits, name("addps xmm0,xmm1"), {0x0F, 0x58, 0xC1}, UD);
    add(cat, bits, name("movups xmm0,[rsi] (unmapped)"), {0x0F, 0x10, 0x06}, UD, unmapped);
    add(cat, bits, name("pshufb xmm0,xmm1"), {0x66, 0x0F, 0x38, 0x00, 0xC1}, UD);
    add(cat, bits, name("palignr xmm0,xmm1,4"), {0x66, 0x0F, 0x3A, 0x0F, 0xC1, 0x04}, UD);
    add(cat, bits, name("aesenc xmm0,xmm1"), {0x66, 0x0F, 0x38, 0xDC, 0xC1}, UD);
    add(cat, bits, name("sha1nexte xmm0,xmm1"), {0x0F, 0x38, 0xC8, 0xC1}, UD);
    add(cat, bits, name("ldmxcsr [rsi] (unmapped)"), {0x0F, 0xAE, 0x16}, UD, unmapped);
    add(cat, bits, name("stmxcsr [rsi] (unmapped)"), {0x0F, 0xAE, 0x1E}, UD, unmapped);
    if (amd_host)
      add(cat, bits, name("extrq xmm0,xmm1 (SSE4A)"), {0x66, 0x0F, 0x79, 0xC1}, UD);
    add(cat, bits, name("paddb mm0,mm1"), {0x0F, 0xFC, 0xC1}, UD);
    add(cat, bits, name("pshufb mm0,mm1"), {0x0F, 0x38, 0x00, 0xC1}, UD);
    add(cat, bits, name("cvtpi2ps xmm0,mm1"), {0x0F, 0x2A, 0xC1}, UD);
    add(cat, bits, name("emms"), {0x0F, 0x77}, UD);

    // x87 and FXSAVE/FXRSTOR: #NM.  WAIT: #NM only with TS and MP.  An
    // undefined x87 form and the FXSAVE opcode under a prefix or VEX/EVEX
    // are no instruction: their #UD and the #NM that EM gives the x87
    // instructions and FXSAVE are in one class, in no order (as under TS
    // above).
    add(cat, bits, name("fld1"), {0xD9, 0xE8}, NM);
    add(cat, bits, name("fnstsw ax"), {0xDF, 0xE0}, NM);
    add(cat, bits, name("fninit"), {0xDB, 0xE3}, NM);
    add(cat, bits, name("fld dword [rsi] (unmapped)"), {0xD9, 0x06}, NM, unmapped);
    add(cat, bits, name("fwait"), {0x9B}, (bits & (MP | TS)) == (MP | TS) ? NM : NONE);
    add(cat, bits, name("fxsave [rsi] (unmapped)"), {0x0F, 0xAE, 0x06}, NM, unmapped);
    add(cat, bits, name("fxrstor [rsi] (unmapped)"), {0x0F, 0xAE, 0x0E}, NM, unmapped);
    add(cat, bits, name("D9 D1 (undefined x87)"), {0xD9, 0xD1}, UD);
    allow(UD_OR_NM);
    add(cat, bits, name("66 0F AE /0 (fxsave with 66)"), {0x66, 0x0F, 0xAE, 0x07}, UD, mem);
    allow(UD_OR_NM);
    add(cat, bits, name("VEX.0F AE /0"), {0xC5, 0xF8, 0xAE, 0x07}, UD, mem);
    allow(UD_OR_NM);
    add(cat, bits, name("EVEX.0F AE /1"), {0x62, 0xF1, 0x7C, 0x48, 0xAE, 0x0F}, UD, mem);
    allow(UD_OR_NM);

    // The XSAVE family, VEX and EVEX ignore EM; TS still applies.
    int ts = bits & TS ? NM : NONE;
    {
      ArchState s = with_xsave_vector_inputs({.rax = 3, .rdx = 0, .rdi = DATA_ADDR}, 3);
      add(cat, bits, name("xsave [rdi] (x87, SSE)"), {0x0F, 0xAE, 0x27}, ts, s);
    }
    {
      ArchState s = vectors;
      s.rdi = DATA_ADDR;
      add(cat, bits, name("vpaddd ymm0,ymm1,ymm2"), {0xC5, 0xF5, 0xFE, 0xC2}, ts, s);
      add(cat, bits, name("vpaddd zmm0,zmm1,zmm2"), {0x62, 0xF1, 0x75, 0x48, 0xFE, 0xC2}, ts, s);
      add(cat, bits, name("kmovw k1,k2"), {0xC5, 0xF8, 0x90, 0xCA}, ts, s);
      add(cat, bits, name("vldmxcsr [rdi]"), {0xC5, 0xF8, 0xAE, 0x17}, ts, s, mxcsr_1f80);
      add(cat, bits, name("vstmxcsr [rdi]"), {0xC5, 0xF8, 0xAE, 0x1F}, ts, s);
    }

    // Unaffected
    add(cat, bits, name("crc32 eax,ebx"), {0xF2, 0x0F, 0x38, 0xF1, 0xC3}, NONE, gprs);
    add(cat, bits, name("popcnt eax,ebx"), {0xF3, 0x0F, 0xB8, 0xC3}, NONE, gprs);
    add(cat, bits, name("andn eax,ebx,ecx (BMI1)"), {0xC4, 0xE2, 0x60, 0xF2, 0xC1}, NONE, gprs);
    add(cat, bits, name("sfence"), {0x0F, 0xAE, 0xF8}, NONE);
    add(cat, bits, name("clflush [rdi]"), {0x0F, 0xAE, 0x3F}, NONE, mem);
  }
}

// x86-64 — VEX Dispatch

val dispatch_vex_0f : (byte, Prefixes) -> unit
function dispatch_vex_0f(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);

  match op {
    // FP: moves, arithmetic, compare, convert, shuffle, unpack
    op if (16 <= op & op <= 23) | (40 <= op & op <= 47)
        | (80 <= op & op <= 95) | op == 194 | op == 198
      => dispatch_vex_0f_fp(op, pfx),

    // Integer: moves, arithmetic, logical, compare, shuffle, insert/extract,
    // mask register ops, pack/unpack, shift, VZEROUPPER/VZEROALL
    op if (65 <= op & op <= 66) | (68 <= op & op <= 71) | (74 <= op & op <= 75)
        | (96 <= op & op <= 119) | (124 <= op & op <= 127)
        | (144 <= op & op <= 147) | (152 <= op & op <= 153)
        | (196 <= op & op <= 197) | (208 <= op & op <= 254)
      => dispatch_vex_0f_int(op, pfx),

    // 0F AE /2, /3: VLDMXCSR/VSTMXCSR m32 — VEX.LZ.0F.WIG with vvvv = 1111b.
    // The other Group 15 members have no VEX form, and a register operand
    // or VEX.L = 1 is #UD.  The MXCSR reserved-bit #GP is in load_mxcsr.
    174 => {
      if pfx.vex_l | pfx.vex_vvvv != 0 | get_mandatory_prefix(pfx) != MP_NONE then raise_UD();
      let (reg_field, dest) = fetch_modrm_raw(pfx);
      match (reg_field, dest) {
        (2, RM_mem(_)) => load_mxcsr(rm_mem(dest)),
        (3, RM_mem(_)) => rm_mem(dest) = __stmxcsr(),
        _ => raise_UD(),
      }
    },

    _ => raise_UD(),
  }
}

// =========================================================================
// VEX 0F38 map dispatch — routes to sub-dispatchers
// =========================================================================

val dispatch_vex_0f38 : (byte, Prefixes) -> unit
function dispatch_vex_0f38(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);

  // BMI1/BMI2 GPR instructions (opcodes F2-F7) do not require AVX, and
  // the Intel AMX instructions (49, 4B, 5C, 5E) need CR4.OSXSAVE and
  // XCR0[18:17] rather than XCR0.AVX (SDM Vol.2 Table 1-67; checked in
  // dispatch_amx).  All other VEX 0F38 instructions use SIMD and require
  // avx_enabled().
  let is_bmi = (242 <= op & op <= 247);
  let is_amx = op == 73 | op == 75 | op == 92 | op == 94;
  if ~(is_bmi) & ~(is_amx) & ~(avx_enabled()) then raise_UD();

  match op {
    // Intel AMX: LDTILECFG/STTILECFG/TILERELEASE/TILEZERO (49),
    // TILELOADD/TILELOADDT1/TILESTORED (4B), TDPBF16PS (5C),
    // TDPBSSD/TDPBSUD/TDPBUSD/TDPBUUD (5E)
    op if is_amx => dispatch_amx(op, pfx),

    // SSSE3, SSE4, broadcast, BMI, variable shifts, gather, test, maskmov,
    // permute, AVX-VNNI, VGF2P8MULB, AES
    op if (0 <= op & op <= 15) | op == 19 | (22 <= op & op <= 26)
        | (28 <= op & op <= 30) | (32 <= op & op <= 37) | (40 <= op & op <= 65)
        | (69 <= op & op <= 71) | (80 <= op & op <= 83) | (88 <= op & op <= 90)
        | (120 <= op & op <= 121)
        | op == 140 | op == 142 | (144 <= op & op <= 147) | op == 207
        | (219 <= op & op <= 223) | (242 <= op & op <= 243) | (245 <= op & op <= 247)
      => dispatch_vex_0f38_arith(op, pfx),

    // FMA3 instructions (0F38 96..BF)
    op if (150 <= op & op <= 159) | (166 <= op & op <= 175)
        | (182 <= op & op <= 191)
      => dispatch_vex_0f38_fma(op, pfx),

    _ => raise_UD(),
  }
}

// =========================================================================
// VEX encoding forms
//
// The values of VEX.L, VEX.W and VEX.vvvv and the kinds of ModRM.r/m
// operand that each VEX opcode accepts, transcribed from the opcode tables
// of SDM Vol.2 (notation in Vol.2A §3.1.1.2).  An opcode column such as
// "VEX.128.66.0F38.W0 2C /r" gives the vector length (128, L0 or LZ:
// VEX.L = 0; 256 or L1: VEX.L = 1; LIG: either), the mandatory prefix, the
// map and VEX.W (W0, W1, or WIG for either).  The Instruction Operand
// Encoding table says whether VEX.vvvv is an operand; if not, it is
// reserved and must be 1111b (§2.3.5.6).  The type of the r/m operand says
// whether it may be a register (xmm2), memory (m64) or either (xmm2/m64).
// Every other encoding, including a map, opcode and pp the SDM does not
// define, is #UD, which dispatch_vex_with_byte2 raises before a handler
// runs.  Run over every map, opcode, pp, L, W, vvvv = 1111b or not, and
// register or memory r/m, a Zen 4 and an Emerald Rapids agree with these
// tables wherever the handlers' own checks (ModRM.reg, VSIB, CPUID
// features) do not decide, except where an entry says otherwise; the AMX
// opcodes were not probed.
//
// A set of forms is a mask over the 16 combinations of VEX.L, VEX.W,
// V (VEX.vvvv != 1111b) and M (a memory r/m): bit 8 L + 4 W + 2 V + M.
// =========================================================================

let VEX_L0    : bits(16) = 0x00FF  // VEX.128, VEX.L0, VEX.LZ
let VEX_L1    : bits(16) = 0xFF00  // VEX.256, VEX.L1
let VEX_LIG   : bits(16) = 0xFFFF
let VEX_W0    : bits(16) = 0x0F0F
let VEX_W1    : bits(16) = 0xF0F0
let VEX_WIG   : bits(16) = 0xFFFF
let VEX_VVVV  : bits(16) = 0xFFFF  // VEX.vvvv is an operand
let VEX_V1111 : bits(16) = 0x3333  // VEX.vvvv is reserved (1111b)
let VEX_RM    : bits(16) = 0xFFFF  // register or memory r/m
let VEX_REG   : bits(16) = 0x5555  // register r/m only (mod = 11b)
let VEX_MEM   : bits(16) = 0xAAAA  // memory r/m only

val vex_form : (bits(16), bits(16), bits(16), bits(16)) -> bits(16)
function vex_form(l, w, v, rm) = l & w & v & rm

// The 0F map.
val vex_forms_0f : (byte, MandatoryPrefix) -> bits(16)
function vex_forms_0f(op, mp) = match (op, mp) {
  (0x10, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VMOVUPS
  (0x10, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VMOVUPD
  (0x10, MP_F3)    => // VMOVSS
    vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_REG)
    | vex_form(VEX_LIG, VEX_WIG, VEX_V1111, VEX_MEM),
  (0x10, MP_F2)    => // VMOVSD
    vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_REG)
    | vex_form(VEX_LIG, VEX_WIG, VEX_V1111, VEX_MEM),
  (0x11, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VMOVUPS
  (0x11, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VMOVUPD
  (0x11, MP_F3)    => // VMOVSS
    vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_REG)
    | vex_form(VEX_LIG, VEX_WIG, VEX_V1111, VEX_MEM),
  (0x11, MP_F2)    => // VMOVSD
    vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_REG)
    | vex_form(VEX_LIG, VEX_WIG, VEX_V1111, VEX_MEM),
  (0x12, MP_NONE)  => // VMOVHLPS, VMOVLPS
    vex_form(VEX_L0, VEX_WIG, VEX_VVVV, VEX_REG)
    | vex_form(VEX_L0, VEX_WIG, VEX_VVVV, VEX_MEM),
  (0x12, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_VVVV, VEX_MEM), // VMOVLPD
  (0x12, MP_F3)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VMOVSLDUP
  (0x12, MP_F2)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VMOVDDUP
  (0x13, MP_NONE)  => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_MEM), // VMOVLPS
  (0x13, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_MEM), // VMOVLPD
  (0x14, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VUNPCKLPS
  (0x14, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VUNPCKLPD
  (0x15, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VUNPCKHPS
  (0x15, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VUNPCKHPD
  (0x16, MP_NONE)  => // VMOVHPS, VMOVLHPS
    vex_form(VEX_L0, VEX_WIG, VEX_VVVV, VEX_MEM)
    | vex_form(VEX_L0, VEX_WIG, VEX_VVVV, VEX_REG),
  (0x16, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_VVVV, VEX_MEM), // VMOVHPD
  (0x16, MP_F3)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VMOVSHDUP
  (0x17, MP_NONE)  => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_MEM), // VMOVHPS
  (0x17, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_MEM), // VMOVHPD
  (0x28, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VMOVAPS
  (0x28, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VMOVAPD
  (0x29, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VMOVAPS
  (0x29, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VMOVAPD
  (0x2A, MP_F3)    => vex_form(VEX_LIG, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VCVTSI2SS
  (0x2A, MP_F2)    => vex_form(VEX_LIG, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VCVTSI2SD
  (0x2B, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_MEM), // VMOVNTPS
  (0x2B, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_MEM), // VMOVNTPD
  (0x2C, MP_F3)    => vex_form(VEX_LIG, VEX_W0 | VEX_W1, VEX_V1111, VEX_RM), // VCVTTSS2SI
  (0x2C, MP_F2)    => vex_form(VEX_LIG, VEX_W0 | VEX_W1, VEX_V1111, VEX_RM), // VCVTTSD2SI
  (0x2D, MP_F3)    => vex_form(VEX_LIG, VEX_W0 | VEX_W1, VEX_V1111, VEX_RM), // VCVTSS2SI
  (0x2D, MP_F2)    => vex_form(VEX_LIG, VEX_W0 | VEX_W1, VEX_V1111, VEX_RM), // VCVTSD2SI
  (0x2E, MP_NONE)  => vex_form(VEX_LIG, VEX_WIG, VEX_V1111, VEX_RM), // VUCOMISS
  (0x2E, MP_66)    => vex_form(VEX_LIG, VEX_WIG, VEX_V1111, VEX_RM), // VUCOMISD
  (0x2F, MP_NONE)  => vex_form(VEX_LIG, VEX_WIG, VEX_V1111, VEX_RM), // VCOMISS
  (0x2F, MP_66)    => vex_form(VEX_LIG, VEX_WIG, VEX_V1111, VEX_RM), // VCOMISD
  (0x41, MP_NONE)  => vex_form(VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_REG), // KANDW, KANDQ
  (0x41, MP_66)    => vex_form(VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_REG), // KANDB, KANDD
  (0x42, MP_NONE)  => vex_form(VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_REG), // KANDNW, KANDNQ
  (0x42, MP_66)    => vex_form(VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_REG), // KANDNB, KANDND
  (0x44, MP_NONE)  => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_REG), // KNOTW, KNOTQ
  (0x44, MP_66)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_REG), // KNOTB, KNOTD
  (0x45, MP_NONE)  => vex_form(VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_REG), // KORW, KORQ
  (0x45, MP_66)    => vex_form(VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_REG), // KORB, KORD
  (0x46, MP_NONE)  => vex_form(VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_REG), // KXNORW, KXNORQ
  (0x46, MP_66)    => vex_form(VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_REG), // KXNORB, KXNORD
  (0x47, MP_NONE)  => vex_form(VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_REG), // KXORW, KXORQ
  (0x47, MP_66)    => vex_form(VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_REG), // KXORB, KXORD
  (0x4A, MP_NONE)  => vex_form(VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_REG), // KADDW, KADDQ
  (0x4A, MP_66)    => vex_form(VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_REG), // KADDB, KADDD
  (0x4B, MP_NONE)  => vex_form(VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_REG), // KUNPCKWD, KUNPCKDQ
  (0x4B, MP_66)    => vex_form(VEX_L1, VEX_W0, VEX_VVVV, VEX_REG), // KUNPCKBW
  (0x50, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_REG), // VMOVMSKPS
  (0x50, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_REG), // VMOVMSKPD
  (0x51, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VSQRTPS
  (0x51, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VSQRTPD
  (0x51, MP_F3)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VSQRTSS
  (0x51, MP_F2)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VSQRTSD
  (0x52, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VRSQRTPS
  (0x52, MP_F3)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VRSQRTSS
  (0x53, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VRCPPS
  (0x53, MP_F3)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VRCPSS
  (0x54, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VANDPS
  (0x54, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VANDPD
  (0x55, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VANDNPS
  (0x55, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VANDNPD
  (0x56, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VORPS
  (0x56, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VORPD
  (0x57, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VXORPS
  (0x57, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VXORPD
  (0x58, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VADDPS
  (0x58, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VADDPD
  (0x58, MP_F3)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VADDSS
  (0x58, MP_F2)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VADDSD
  (0x59, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VMULPS
  (0x59, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VMULPD
  (0x59, MP_F3)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VMULSS
  (0x59, MP_F2)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VMULSD
  (0x5A, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VCVTPS2PD
  (0x5A, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VCVTPD2PS
  (0x5A, MP_F3)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VCVTSS2SD
  (0x5A, MP_F2)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VCVTSD2SS
  (0x5B, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VCVTDQ2PS
  (0x5B, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VCVTPS2DQ
  (0x5B, MP_F3)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VCVTTPS2DQ
  (0x5C, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VSUBPS
  (0x5C, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VSUBPD
  (0x5C, MP_F3)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VSUBSS
  (0x5C, MP_F2)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VSUBSD
  (0x5D, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VMINPS
  (0x5D, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VMINPD
  (0x5D, MP_F3)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VMINSS
  (0x5D, MP_F2)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VMINSD
  (0x5E, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VDIVPS
  (0x5E, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VDIVPD
  (0x5E, MP_F3)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VDIVSS
  (0x5E, MP_F2)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VDIVSD
  (0x5F, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VMAXPS
  (0x5F, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VMAXPD
  (0x5F, MP_F3)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VMAXSS
  (0x5F, MP_F2)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VMAXSD
  (0x60, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPUNPCKLBW
  (0x61, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPUNPCKLWD
  (0x62, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPUNPCKLDQ
  (0x63, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPACKSSWB
  (0x64, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPCMPGTB
  (0x65, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPCMPGTW
  (0x66, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPCMPGTD
  (0x67, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPACKUSWB
  (0x68, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPUNPCKHBW
  (0x69, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPUNPCKHWD
  (0x6A, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPUNPCKHDQ
  (0x6B, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPACKSSDW
  (0x6C, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPUNPCKLQDQ
  (0x6D, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPUNPCKHQDQ
  (0x6E, MP_66)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_RM), // VMOVD, VMOVQ
  (0x6F, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VMOVDQA
  (0x6F, MP_F3)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VMOVDQU
  (0x70, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPSHUFD
  (0x70, MP_F3)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPSHUFHW
  (0x70, MP_F2)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPSHUFLW
  // Groups 12-14; the handler checks ModRM.reg (/digit).
  (0x71, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_REG), // VPSRLW /2, VPSRAW /4, VPSLLW /6
  (0x72, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_REG), // VPSRLD /2, VPSRAD /4, VPSLLD /6
  (0x73, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_REG), // VPSRLQ /2, VPSRLDQ /3, VPSLLQ /6, VPSLLDQ /7
  (0x74, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPCMPEQB
  (0x75, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPCMPEQW
  (0x76, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPCMPEQD
  (0x77, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_REG), // VZEROUPPER, VZEROALL: no ModR/M
  (0x7C, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VHADDPD
  (0x7C, MP_F2)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VHADDPS
  (0x7D, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VHSUBPD
  (0x7D, MP_F2)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VHSUBPS
  (0x7E, MP_66)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_RM), // VMOVD, VMOVQ
  (0x7E, MP_F3)    => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_RM), // VMOVQ
  (0x7F, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VMOVDQA
  (0x7F, MP_F3)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VMOVDQU
  (0x90, MP_NONE)  => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_RM), // KMOVW, KMOVQ
  (0x90, MP_66)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_RM), // KMOVB, KMOVD
  (0x91, MP_NONE)  => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_MEM), // KMOVW, KMOVQ
  (0x91, MP_66)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_MEM), // KMOVB, KMOVD
  (0x92, MP_NONE)  => vex_form(VEX_L0, VEX_W0, VEX_V1111, VEX_REG), // KMOVW
  (0x92, MP_66)    => vex_form(VEX_L0, VEX_W0, VEX_V1111, VEX_REG), // KMOVB
  (0x92, MP_F2)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_REG), // KMOVQ, KMOVD
  (0x93, MP_NONE)  => vex_form(VEX_L0, VEX_W0, VEX_V1111, VEX_REG), // KMOVW
  (0x93, MP_66)    => vex_form(VEX_L0, VEX_W0, VEX_V1111, VEX_REG), // KMOVB
  (0x93, MP_F2)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_REG), // KMOVQ, KMOVD
  (0x98, MP_NONE)  => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_REG), // KORTESTW, KORTESTQ
  (0x98, MP_66)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_REG), // KORTESTB, KORTESTD
  (0x99, MP_NONE)  => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_REG), // KTESTW, KTESTQ
  (0x99, MP_66)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_REG), // KTESTB, KTESTD
  (0xAE, MP_NONE)  => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_MEM), // VLDMXCSR /2, VSTMXCSR /3
  (0xC2, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VCMPPS
  (0xC2, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VCMPPD
  (0xC2, MP_F3)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VCMPSS
  (0xC2, MP_F2)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VCMPSD
  // VPINSRW and VPEXTRW are W0 in the opcode column, but "In 64-bit mode,
  // VEX.W1 is ignored for VPINSRW" (and VPEXTRW; SDM notes).
  (0xC4, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_VVVV, VEX_RM), // VPINSRW
  (0xC5, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_REG), // VPEXTRW
  (0xC6, MP_NONE)  => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VSHUFPS
  (0xC6, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VSHUFPD
  (0xD0, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VADDSUBPD
  (0xD0, MP_F2)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VADDSUBPS
  (0xD1, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSRLW
  (0xD2, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSRLD
  (0xD3, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSRLQ
  (0xD4, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPADDQ
  (0xD5, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMULLW
  (0xD6, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_RM), // VMOVQ
  (0xD7, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_REG), // VPMOVMSKB
  (0xD8, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSUBUSB
  (0xD9, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSUBUSW
  (0xDA, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMINUB
  (0xDB, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPAND
  (0xDC, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPADDUSB
  (0xDD, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPADDUSW
  (0xDE, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMAXUB
  (0xDF, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPANDN
  (0xE0, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPAVGB
  (0xE1, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSRAW
  (0xE2, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSRAD
  (0xE3, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPAVGW
  (0xE4, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMULHUW
  (0xE5, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMULHW
  (0xE6, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VCVTTPD2DQ
  (0xE6, MP_F3)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VCVTDQ2PD
  (0xE6, MP_F2)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VCVTPD2DQ
  (0xE7, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_MEM), // VMOVNTDQ
  (0xE8, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSUBSB
  (0xE9, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSUBSW
  (0xEA, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMINSW
  (0xEB, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPOR
  (0xEC, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPADDSB
  (0xED, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPADDSW
  (0xEE, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMAXSW
  (0xEF, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPXOR
  (0xF0, MP_F2)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_MEM), // VLDDQU
  (0xF1, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSLLW
  (0xF2, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSLLD
  (0xF3, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSLLQ
  (0xF4, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMULUDQ
  (0xF5, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMADDWD
  (0xF6, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSADBW
  (0xF7, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_REG), // VMASKMOVDQU
  (0xF8, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSUBB
  (0xF9, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSUBW
  (0xFA, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSUBD
  (0xFB, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSUBQ
  (0xFC, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPADDB
  (0xFD, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPADDW
  (0xFE, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPADDD
  _ => zeros(),
}

// The 0F38 map.
val vex_forms_0f38 : (byte, MandatoryPrefix) -> bits(16)
function vex_forms_0f38(op, mp) = match (op, mp) {
  (0x00, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSHUFB
  (0x01, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPHADDW
  (0x02, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPHADDD
  (0x03, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPHADDSW
  (0x04, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMADDUBSW
  (0x05, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPHSUBW
  (0x06, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPHSUBD
  (0x07, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPHSUBSW
  (0x08, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSIGNB
  (0x09, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSIGNW
  (0x0A, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPSIGND
  (0x0B, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMULHRSW
  (0x0C, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_VVVV, VEX_RM), // VPERMILPS
  (0x0D, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_VVVV, VEX_RM), // VPERMILPD
  (0x0E, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_V1111, VEX_RM), // VTESTPS
  (0x0F, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_V1111, VEX_RM), // VTESTPD
  (0x13, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_V1111, VEX_RM), // VCVTPH2PS
  (0x16, MP_66)    => vex_form(VEX_L1, VEX_W0, VEX_VVVV, VEX_RM), // VPERMPS
  (0x17, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPTEST
  (0x18, MP_66)    => // VBROADCASTSS
    vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_V1111, VEX_MEM)
    | vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_V1111, VEX_REG),
  (0x19, MP_66)    => // VBROADCASTSD
    vex_form(VEX_L1, VEX_W0, VEX_V1111, VEX_MEM)
    | vex_form(VEX_L1, VEX_W0, VEX_V1111, VEX_REG),
  (0x1A, MP_66)    => vex_form(VEX_L1, VEX_W0, VEX_V1111, VEX_MEM), // VBROADCASTF128
  (0x1C, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPABSB
  (0x1D, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPABSW
  (0x1E, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPABSD
  (0x20, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPMOVSXBW
  (0x21, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPMOVSXBD
  (0x22, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPMOVSXBQ
  (0x23, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPMOVSXWD
  (0x24, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPMOVSXWQ
  (0x25, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPMOVSXDQ
  (0x28, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMULDQ
  (0x29, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPCMPEQQ
  (0x2A, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_MEM), // VMOVNTDQA
  (0x2B, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPACKUSDW
  (0x2C, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_VVVV, VEX_MEM), // VMASKMOVPS
  (0x2D, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_VVVV, VEX_MEM), // VMASKMOVPD
  (0x2E, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_VVVV, VEX_MEM), // VMASKMOVPS
  (0x2F, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_VVVV, VEX_MEM), // VMASKMOVPD
  (0x30, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPMOVZXBW
  (0x31, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPMOVZXBD
  (0x32, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPMOVZXBQ
  (0x33, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPMOVZXWD
  (0x34, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPMOVZXWQ
  (0x35, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VPMOVZXDQ
  (0x36, MP_66)    => vex_form(VEX_L1, VEX_W0, VEX_VVVV, VEX_RM), // VPERMD
  (0x37, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPCMPGTQ
  (0x38, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMINSB
  (0x39, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMINSD
  (0x3A, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMINUW
  (0x3B, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMINUD
  (0x3C, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMAXSB
  (0x3D, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMAXSD
  (0x3E, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMAXUW
  (0x3F, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMAXUD
  (0x40, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPMULLD
  (0x41, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_RM), // VPHMINPOSUW
  (0x45, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VPSRLVD, VPSRLVQ
  (0x46, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_VVVV, VEX_RM), // VPSRAVD
  (0x47, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VPSLLVD, VPSLLVQ
  // Intel AMX (49, 4B, 5C, 5E): dispatch_amx checks the forms.
  (0x49, _)        => ones(),
  (0x4B, _)        => ones(),
  (0x50, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_VVVV, VEX_RM), // VPDPBUSD
  (0x51, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_VVVV, VEX_RM), // VPDPBUSDS
  (0x52, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_VVVV, VEX_RM), // VPDPWSSD
  (0x53, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_VVVV, VEX_RM), // VPDPWSSDS
  (0x58, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_V1111, VEX_RM), // VPBROADCASTD
  (0x59, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_V1111, VEX_RM), // VPBROADCASTQ
  (0x5A, MP_66)    => vex_form(VEX_L1, VEX_W0, VEX_V1111, VEX_MEM), // VBROADCASTI128
  (0x5C, _)        => ones(),
  (0x5E, _)        => ones(),
  (0x78, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_V1111, VEX_RM), // VPBROADCASTB
  (0x79, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_V1111, VEX_RM), // VPBROADCASTW
  (0x8C, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_MEM), // VPMASKMOVD, VPMASKMOVQ
  (0x8E, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_MEM), // VPMASKMOVD, VPMASKMOVQ
  // Gathers: VSIB memory operands (decode_vsib_vex).
  (0x90, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_MEM), // VPGATHERDD, VPGATHERDQ
  (0x91, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_MEM), // VPGATHERQD, VPGATHERQQ
  (0x92, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_MEM), // VGATHERDPS, VGATHERDPD
  (0x93, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_MEM), // VGATHERQPS, VGATHERQPD
  (0x96, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFMADDSUB132PS, VFMADDSUB132PD
  (0x97, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFMSUBADD132PS, VFMSUBADD132PD
  (0x98, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFMADD132PS, VFMADD132PD
  (0x99, MP_66)    => vex_form(VEX_LIG, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFMADD132SS, VFMADD132SD
  (0x9A, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFMSUB132PS, VFMSUB132PD
  (0x9B, MP_66)    => vex_form(VEX_LIG, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFMSUB132SS, VFMSUB132SD
  (0x9C, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFNMADD132PS, VFNMADD132PD
  (0x9D, MP_66)    => vex_form(VEX_LIG, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFNMADD132SS, VFNMADD132SD
  (0x9E, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFNMSUB132PS, VFNMSUB132PD
  (0x9F, MP_66)    => vex_form(VEX_LIG, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFNMSUB132SS, VFNMSUB132SD
  (0xA6, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFMADDSUB213PS, VFMADDSUB213PD
  (0xA7, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFMSUBADD213PS, VFMSUBADD213PD
  (0xA8, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFMADD213PS, VFMADD213PD
  (0xA9, MP_66)    => vex_form(VEX_LIG, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFMADD213SS, VFMADD213SD
  (0xAA, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFMSUB213PS, VFMSUB213PD
  (0xAB, MP_66)    => vex_form(VEX_LIG, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFMSUB213SS, VFMSUB213SD
  (0xAC, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFNMADD213PS, VFNMADD213PD
  (0xAD, MP_66)    => vex_form(VEX_LIG, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFNMADD213SS, VFNMADD213SD
  (0xAE, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFNMSUB213PS, VFNMSUB213PD
  (0xAF, MP_66)    => vex_form(VEX_LIG, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFNMSUB213SS, VFNMSUB213SD
  (0xB6, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFMADDSUB231PS, VFMADDSUB231PD
  (0xB7, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFMSUBADD231PS, VFMSUBADD231PD
  (0xB8, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFMADD231PS, VFMADD231PD
  (0xB9, MP_66)    => vex_form(VEX_LIG, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFMADD231SS, VFMADD231SD
  (0xBA, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFMSUB231PS, VFMSUB231PD
  (0xBB, MP_66)    => vex_form(VEX_LIG, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFMSUB231SS, VFMSUB231SD
  (0xBC, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFNMADD231PS, VFNMADD231PD
  (0xBD, MP_66)    => vex_form(VEX_LIG, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFNMADD231SS, VFNMADD231SD
  (0xBE, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFNMSUB231PS, VFNMSUB231PD
  (0xBF, MP_66)    => vex_form(VEX_LIG, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VFNMSUB231SS, VFNMSUB231SD
  (0xCF, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_VVVV, VEX_RM), // VGF2P8MULB
  (0xDB, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_RM), // VAESIMC
  (0xDC, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VAESENC
  (0xDD, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VAESENCLAST
  (0xDE, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VAESDEC
  (0xDF, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VAESDECLAST
  (0xF2, MP_NONE)  => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // ANDN
  (0xF3, MP_NONE)  => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // BLSR /1, BLSMSK /2, BLSI /3
  (0xF5, MP_NONE)  => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // BZHI
  (0xF5, MP_F3)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // PEXT
  (0xF5, MP_F2)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // PDEP
  (0xF6, MP_F2)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // MULX
  (0xF7, MP_NONE)  => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // BEXTR
  (0xF7, MP_66)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // SHLX
  (0xF7, MP_F3)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // SARX
  (0xF7, MP_F2)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // SHRX
  _ => zeros(),
}

// The 0F3A map.
val vex_forms_0f3a : (byte, MandatoryPrefix) -> bits(16)
function vex_forms_0f3a(op, mp) = match (op, mp) {
  // VPERMQ and VPERMPD are W1; a Zen 4 ignores VEX.W, an Emerald Rapids
  // raises #UD for W0.
  (0x00, MP_66)    => // VPERMQ
    vex_form(VEX_L1, if vendor == Vendor_AMD then VEX_WIG else VEX_W1, VEX_V1111, VEX_RM),
  (0x01, MP_66)    => // VPERMPD
    vex_form(VEX_L1, if vendor == Vendor_AMD then VEX_WIG else VEX_W1, VEX_V1111, VEX_RM),
  (0x02, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_VVVV, VEX_RM), // VPBLENDD
  (0x04, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_V1111, VEX_RM), // VPERMILPS
  (0x05, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_V1111, VEX_RM), // VPERMILPD
  (0x06, MP_66)    => vex_form(VEX_L1, VEX_W0, VEX_VVVV, VEX_RM), // VPERM2F128
  (0x08, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VROUNDPS
  (0x09, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_V1111, VEX_RM), // VROUNDPD
  (0x0A, MP_66)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VROUNDSS
  (0x0B, MP_66)    => vex_form(VEX_LIG, VEX_WIG, VEX_VVVV, VEX_RM), // VROUNDSD
  (0x0C, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VBLENDPS
  (0x0D, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VBLENDPD
  (0x0E, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPBLENDW
  (0x0F, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPALIGNR
  // VPEXTRB, VPEXTRW and VPINSRB: as VPINSRW, W0 but VEX.W1 is ignored.
  (0x14, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_RM), // VPEXTRB
  (0x15, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_RM), // VPEXTRW
  (0x16, MP_66)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_RM), // VPEXTRD, VPEXTRQ
  (0x17, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_RM), // VEXTRACTPS
  (0x18, MP_66)    => vex_form(VEX_L1, VEX_W0, VEX_VVVV, VEX_RM), // VINSERTF128
  (0x19, MP_66)    => vex_form(VEX_L1, VEX_W0, VEX_V1111, VEX_RM), // VEXTRACTF128
  (0x1D, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_V1111, VEX_RM), // VCVTPS2PH
  (0x20, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_VVVV, VEX_RM), // VPINSRB
  (0x21, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_VVVV, VEX_RM), // VINSERTPS
  (0x22, MP_66)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_VVVV, VEX_RM), // VPINSRD, VPINSRQ
  (0x30, MP_66)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_REG), // KSHIFTRB, KSHIFTRW
  (0x31, MP_66)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_REG), // KSHIFTRD, KSHIFTRQ
  (0x32, MP_66)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_REG), // KSHIFTLB, KSHIFTLW
  (0x33, MP_66)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_REG), // KSHIFTLD, KSHIFTLQ
  (0x38, MP_66)    => vex_form(VEX_L1, VEX_W0, VEX_VVVV, VEX_RM), // VINSERTI128
  (0x39, MP_66)    => vex_form(VEX_L1, VEX_W0, VEX_V1111, VEX_RM), // VEXTRACTI128
  (0x40, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VDPPS
  (0x41, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_VVVV, VEX_RM), // VDPPD
  (0x42, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VMPSADBW
  (0x44, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_WIG, VEX_VVVV, VEX_RM), // VPCLMULQDQ
  (0x46, MP_66)    => vex_form(VEX_L1, VEX_W0, VEX_VVVV, VEX_RM), // VPERM2I128
  (0x4A, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_VVVV, VEX_RM), // VBLENDVPS
  (0x4B, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_VVVV, VEX_RM), // VBLENDVPD
  (0x4C, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W0, VEX_VVVV, VEX_RM), // VPBLENDVB
  (0x60, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_RM), // VPCMPESTRM
  (0x61, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_RM), // VPCMPESTRI
  (0x62, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_RM), // VPCMPISTRM
  (0x63, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_RM), // VPCMPISTRI
  (0xCE, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W1, VEX_VVVV, VEX_RM), // VGF2P8AFFINEQB
  (0xCF, MP_66)    => vex_form(VEX_L0 | VEX_L1, VEX_W1, VEX_VVVV, VEX_RM), // VGF2P8AFFINEINVQB
  (0xDF, MP_66)    => vex_form(VEX_L0, VEX_WIG, VEX_V1111, VEX_RM), // VAESKEYGENASSIST
  (0xF0, MP_F2)    => vex_form(VEX_L0, VEX_W0 | VEX_W1, VEX_V1111, VEX_RM), // RORX
  _ => zeros(),
}

// The ModR/M byte after the opcode, left in the instruction stream for the
// handler to fetch.
val vex_peek_modrm : unit -> byte
function vex_peek_modrm() = {
  let modrm = fetch(1);
  decode_pos = decode_pos - 1;
  modrm
}

// Whether the encoding is one of its opcode's forms.  VZEROUPPER and
// VZEROALL (0F 77) have no ModR/M byte; their forms are register forms.
val vex_form_valid : (range(0, 31), byte, Prefixes) -> bool
function vex_form_valid(map, opcode, pfx) = {
  let mp = get_mandatory_prefix(pfx);
  let forms : bits(16) = match map {
    1 => vex_forms_0f(opcode, mp),
    2 => vex_forms_0f38(opcode, mp),
    3 => vex_forms_0f3a(opcode, mp),
    _ => zeros(),
  };
  if forms == zeros() then false else {
    let mem : bool = if map == 1 & opcode == 0x77 then false
                     else vex_peek_modrm()[7..6] != 0b11;
    let i : range(0, 15) = (if pfx.vex_l then 8 else 0) + (if pfx.vex_w then 4 else 0)
                         + (if pfx.vex_vvvv != 0 then 2 else 0) + (if mem then 1 else 0);
    forms[i] == bitone
  }
}

// =========================================================================
// Top-level VEX dispatch — called from 1-byte opcode map for C4/C5.
// Must come after dispatch_vex_0f/0f38/0f3a definitions.
// =========================================================================

// Dispatch VEX-encoded instruction when the second byte has already been
// fetched (needed for C4/C5 in non-64-bit mode where the second byte is
// peeked at to distinguish VEX from LES/LDS).  lpfx holds the legacy
// prefixes before the VEX prefix.  Of those, only a segment override and
// 67h are not #UD (vex_after_legacy_prefix), and they apply to the memory
// operand as in any other instruction.
val dispatch_vex_with_byte2 : (byte, byte, Prefixes) -> unit
function dispatch_vex_with_byte2(first_byte, b1, lpfx) = {
  if cur_mode == Virtual8086Mode then raise_UD();
  // NOTE: avx_enabled() is NOT checked here.  VEX-encoded GPR-only
  // instructions (BMI1/BMI2) do not require CR4.OSXSAVE or XCR0[AVX].
  // The check is deferred to sub-dispatchers that handle SIMD instructions.
  let (pfx, map) : (Prefixes, range(0, 31)) =
    if first_byte == 0xC5 then {
      decode_vex2(b1)
    } else {
      // C4 = 3-byte VEX
      let b2 = fetch(1);
      decode_vex3(b1, b2)
    };
  let pfx = { pfx with seg_override = lpfx.seg_override, has_adsize = lpfx.has_adsize };

  let opcode = fetch(1);
  if ~(vex_form_valid(map, opcode, pfx)) then raise_UD();
  // Outside 64-bit mode, "the 3-byte VEX version will ignore" the top bit
  // of vvvv (SDM Vol.2A §2.3.5.6; in the 2-byte VEX it is 1, or the
  // instruction is LDS).  An Emerald Rapids ignores it where vvvv names a
  // register, a vector or a GPR, but raises #UD for 0111b where vvvv is
  // reserved, as in 64-bit mode: the forms above have checked the whole
  // field.
  let pfx = if cur_mode != LongMode then { pfx with vex_vvvv = pfx.vex_vvvv % 8 } else pfx;

  match map {
    1 => { if ~(avx_enabled()) then raise_UD(); dispatch_vex_0f(opcode, pfx) },
    2 => dispatch_vex_0f38(opcode, pfx),
    3 => dispatch_vex_0f3a(opcode, pfx),
    _ => raise_UD(),
  }
}

val dispatch_vex : (byte, Prefixes) -> unit
function dispatch_vex(first_byte, lpfx) = {
  let b1 = fetch(1);
  dispatch_vex_with_byte2(first_byte, b1, lpfx)
}

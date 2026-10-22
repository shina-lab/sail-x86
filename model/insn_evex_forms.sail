// x86-64 — EVEX Opcode Forms
//
// The EVEX opcode forms the SDM defines, and the encoding checks they
// drive.  evex_check_form runs once per EVEX instruction, before the
// handlers in insn_evex_*.sail, and raises #UD for any encoding no form
// allows, so the handlers can assume a valid encoding.
//
// SDM Vol.2A §2.7.11.3 makes the validity of most EVEX fields depend on
// the opcode: on the operands it encodes (Table 2-41), on its use of an
// opmask (Table 2-42; §2.7.4) and on what EVEX.b means for it (Table 2-43;
// §§2.7.6-2.7.9).  The opcode tables of the instruction reference pages
// (Vol.2A-2D Chapters 3-5) list every valid combination, one row per form,
// e.g.
//   EVEX.512.66.0F.W1 58 /r VADDPD zmm1 {k1}{z}, zmm2, zmm3/m512/m64bcst{er}
// The table below collects those rows: one arm per opcode, pp, W,
// ModRM.reg opcode extension (/digit) and register or memory ModRM.r/m
// (where the rows differ, as VMOVSS reg, reg vs. VMOVSS m32), with
//   - the vector lengths of its rows (EVEX.128/256/512, or LLIG),
//   - whether EVEX.vvvv names an operand, from the instruction's
//     "Instruction Operand Encoding" table,
//   - its masking ({k1}, {k1}{z}, or none) and what zeroing would apply
//     to (an opmask operand, a ModRM.r/m destination),
//   - its broadcast element size (m16bcst/m32bcst/m64bcst),
//   - and {er} or {sae}.
// Rows with W0 and W1 that agree on all of these share an arm with W
// ignored.  The table was generated from the SDM reference pages of the
// February 2026 revision (one page per mnemonic, as in ~/sdm); it includes
// the forms of AVX512_4FMAPS and AVX512_4VNNIW, which the model does not
// implement (evex_feature_present).
//
// The table and checks were compared with an Intel Emerald Rapids and an
// AMD Zen 4 executing every map, opcode, pp, W, ModRM.reg, register and
// memory r/m and vector length, each with EVEX.b, z, aaa, vvvv, V' and
// L'L = 11b varied one at a time.  The hardware agrees with them, except
// for:
//   - VCVTSI2SD, VCVTUSI2SD, VCVTDQ2PD and VCVTUDQ2PD (W0): their rows
//     have no {er}, but both vendors take EVEX.b in the register form as
//     for the {er} W1 forms of the same opcodes, including the 512-bit
//     vector length.  Their arms say RC_ER, marked "EVEX.b as W1".
//   - AMD, which ignores EVEX.b in the register form of a form with a
//     broadcast but no {er}/{sae} (the vector length stays EVEX.L'L), and
//     EVEX.z in a form without masking unless the zeroing would apply to
//     an opmask or memory operand.  Intel raises #UD for both, as the SDM
//     says.

// What EVEX.V':vvvv encodes (SDM Vol.2A Tables 2-33 and 2-41).
enum EvexVvvv = {
  V_REG,   // a vector register operand
  V_NONE,  // nothing: EVEX.vvvv must be 1111b and EVEX.V' 1
  V_VSIB,  // nothing, but EVEX.V' extends the VSIB index register
}

// The opmask an instruction takes in EVEX.aaa, and whether it can zero
// (SDM Vol.2A §2.7.4).
enum EvexMasking = {
  K_NONE,     // no {k1}: aaa must be 000b
  K_NONE_RM,  // the same, with a ModRM.r/m destination (a store in the memory form)
  K_NONE_K,   // the same, with an opmask source or destination
  K_MERGE,    // {k1} (or {k2} for an opmask destination): no zeroing
  K_ZERO,     // {k1}{z}
  K_ZERO_RM,  // {k1}{z} with a ModRM.r/m destination: no zeroing to memory
}

// What EVEX.b means in the register form (SDM Vol.2A Table 2-43).
enum EvexRounding = {
  RC_NONE,  // nothing: #UD
  RC_ER,    // {er}: static rounding mode in EVEX.L'L
  RC_SAE,   // {sae}: suppress all exceptions, EVEX.L'L ignored
}

struct EvexForm = {
  lengths : bits(3),        // EVEX.L'L of the rows: bit i for L'L = i; 000b = LLIG
  vvvv : EvexVvvv,
  masking : EvexMasking,
  bcst : {0, 16, 32, 64},   // broadcast element size; 0 = no broadcast
  rounding : EvexRounding,
}

val evex_form : (bits(3), EvexVvvv, EvexMasking, {0, 16, 32, 64}, EvexRounding) -> option(EvexForm)
function evex_form(lengths, vvvv, masking, bcst, rounding) =
  Some(struct { lengths = lengths, vvvv = vvvv, masking = masking, bcst = bcst, rounding = rounding })

// The forms of each opcode map, by (opcode, pp, W, ModRM.reg, register
// r/m).  pp: 00b = NP, 01b = 66, 10b = F3, 11b = F2.

val evex_form_0f : (byte, bits(2), bit, bits(3), bool) -> option(EvexForm)
function evex_form_0f(op, pp, w, digit, is_reg) = match (op, pp, w, digit, is_reg) {
  (0x10, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VMOVUPS
  (0x10, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VMOVUPD
  (0x10, 0b10, 0b0,     _,  true) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_NONE), // VMOVSS
  (0x10, 0b10, 0b0,     _, false) => evex_form(0b000, V_NONE, K_ZERO,      0, RC_NONE), // VMOVSS
  (0x10, 0b11, 0b1,     _,  true) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_NONE), // VMOVSD
  (0x10, 0b11, 0b1,     _, false) => evex_form(0b000, V_NONE, K_ZERO,      0, RC_NONE), // VMOVSD
  (0x11, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VMOVUPS
  (0x11, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VMOVUPD
  (0x11, 0b10, 0b0,     _,  true) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_NONE), // VMOVSS
  (0x11, 0b10, 0b0,     _, false) => evex_form(0b000, V_NONE, K_MERGE,     0, RC_NONE), // VMOVSS
  (0x11, 0b11, 0b1,     _,  true) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_NONE), // VMOVSD
  (0x11, 0b11, 0b1,     _, false) => evex_form(0b000, V_NONE, K_MERGE,     0, RC_NONE), // VMOVSD
  (0x12, 0b00, 0b0,     _,  true) => evex_form(0b001, V_REG,  K_NONE,      0, RC_NONE), // VMOVHLPS
  (0x12, 0b00, 0b0,     _, false) => evex_form(0b001, V_REG,  K_NONE,      0, RC_NONE), // VMOVLPS
  (0x12, 0b01, 0b1,     _, false) => evex_form(0b001, V_REG,  K_NONE,      0, RC_NONE), // VMOVLPD
  (0x12, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VMOVSLDUP
  (0x12, 0b11, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VMOVDDUP
  (0x13, 0b00, 0b0,     _, false) => evex_form(0b001, V_NONE, K_NONE_RM,   0, RC_NONE), // VMOVLPS
  (0x13, 0b01, 0b1,     _, false) => evex_form(0b001, V_NONE, K_NONE_RM,   0, RC_NONE), // VMOVLPD
  (0x14, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VUNPCKLPS
  (0x14, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VUNPCKLPD
  (0x15, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VUNPCKHPS
  (0x15, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VUNPCKHPD
  (0x16, 0b00, 0b0,     _,  true) => evex_form(0b001, V_REG,  K_NONE,      0, RC_NONE), // VMOVLHPS
  (0x16, 0b00, 0b0,     _, false) => evex_form(0b001, V_REG,  K_NONE,      0, RC_NONE), // VMOVHPS
  (0x16, 0b01, 0b1,     _, false) => evex_form(0b001, V_REG,  K_NONE,      0, RC_NONE), // VMOVHPD
  (0x16, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VMOVSHDUP
  (0x17, 0b00, 0b0,     _, false) => evex_form(0b001, V_NONE, K_NONE_RM,   0, RC_NONE), // VMOVHPS
  (0x17, 0b01, 0b1,     _, false) => evex_form(0b001, V_NONE, K_NONE_RM,   0, RC_NONE), // VMOVHPD
  (0x28, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VMOVAPS
  (0x28, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VMOVAPD
  (0x29, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VMOVAPS
  (0x29, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VMOVAPD
  (0x2A, 0b10,   _,     _,     _) => evex_form(0b000, V_REG,  K_NONE,      0, RC_ER), // VCVTSI2SS
  (0x2A, 0b11, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_NONE,      0, RC_ER), // VCVTSI2SD (EVEX.b as W1)
  (0x2A, 0b11, 0b1,     _,     _) => evex_form(0b000, V_REG,  K_NONE,      0, RC_ER), // VCVTSI2SD
  (0x2B, 0b00, 0b0,     _, false) => evex_form(0b111, V_NONE, K_NONE_RM,   0, RC_NONE), // VMOVNTPS
  (0x2B, 0b01, 0b1,     _, false) => evex_form(0b111, V_NONE, K_NONE_RM,   0, RC_NONE), // VMOVNTPD
  (0x2C, 0b10,   _,     _,     _) => evex_form(0b000, V_NONE, K_NONE,      0, RC_SAE), // VCVTTSS2SI
  (0x2C, 0b11,   _,     _,     _) => evex_form(0b000, V_NONE, K_NONE,      0, RC_SAE), // VCVTTSD2SI
  (0x2D, 0b10,   _,     _,     _) => evex_form(0b000, V_NONE, K_NONE,      0, RC_ER), // VCVTSS2SI
  (0x2D, 0b11,   _,     _,     _) => evex_form(0b000, V_NONE, K_NONE,      0, RC_ER), // VCVTSD2SI
  (0x2E, 0b00, 0b0,     _,     _) => evex_form(0b000, V_NONE, K_NONE,      0, RC_SAE), // VUCOMISS
  (0x2E, 0b01, 0b1,     _,     _) => evex_form(0b000, V_NONE, K_NONE,      0, RC_SAE), // VUCOMISD
  (0x2F, 0b00, 0b0,     _,     _) => evex_form(0b000, V_NONE, K_NONE,      0, RC_SAE), // VCOMISS
  (0x2F, 0b01, 0b1,     _,     _) => evex_form(0b000, V_NONE, K_NONE,      0, RC_SAE), // VCOMISD
  (0x51, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_ER), // VSQRTPS
  (0x51, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_ER), // VSQRTPD
  (0x51, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VSQRTSS
  (0x51, 0b11, 0b1,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VSQRTSD
  (0x54, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VANDPS
  (0x54, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VANDPD
  (0x55, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VANDNPS
  (0x55, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VANDNPD
  (0x56, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VORPS
  (0x56, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VORPD
  (0x57, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VXORPS
  (0x57, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VXORPD
  (0x58, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VADDPS
  (0x58, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VADDPD
  (0x58, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VADDSS
  (0x58, 0b11, 0b1,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VADDSD
  (0x59, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VMULPS
  (0x59, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VMULPD
  (0x59, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VMULSS
  (0x59, 0b11, 0b1,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VMULSD
  (0x5A, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_SAE), // VCVTPS2PD
  (0x5A, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_ER), // VCVTPD2PS
  (0x5A, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VCVTSS2SD
  (0x5A, 0b11, 0b1,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VCVTSD2SS
  (0x5B, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_ER), // VCVTDQ2PS
  (0x5B, 0b00, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_ER), // VCVTQQ2PS
  (0x5B, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_ER), // VCVTPS2DQ
  (0x5B, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_SAE), // VCVTTPS2DQ
  (0x5C, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VSUBPS
  (0x5C, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VSUBPD
  (0x5C, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VSUBSS
  (0x5C, 0b11, 0b1,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VSUBSD
  (0x5D, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_SAE), // VMINPS
  (0x5D, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_SAE), // VMINPD
  (0x5D, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VMINSS
  (0x5D, 0b11, 0b1,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VMINSD
  (0x5E, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VDIVPS
  (0x5E, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VDIVPD
  (0x5E, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VDIVSS
  (0x5E, 0b11, 0b1,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VDIVSD
  (0x5F, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_SAE), // VMAXPS
  (0x5F, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_SAE), // VMAXPD
  (0x5F, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VMAXSS
  (0x5F, 0b11, 0b1,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VMAXSD
  (0x60, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPUNPCKLBW
  (0x61, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPUNPCKLWD
  (0x62, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPUNPCKLDQ
  (0x63, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPACKSSWB
  (0x64, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,     0, RC_NONE), // VPCMPGTB
  (0x65, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,     0, RC_NONE), // VPCMPGTW
  (0x66, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,    32, RC_NONE), // VPCMPGTD
  (0x67, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPACKUSWB
  (0x68, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPUNPCKHBW
  (0x69, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPUNPCKHWD
  (0x6A, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPUNPCKHDQ
  (0x6B, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPACKSSDW
  (0x6C, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPUNPCKLQDQ
  (0x6D, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPUNPCKHQDQ
  (0x6E, 0b01,   _,     _,     _) => evex_form(0b001, V_NONE, K_NONE,      0, RC_NONE), // VMOVD/VMOVQ
  (0x6F, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VMOVDQA32/VMOVDQA64
  (0x6F, 0b10,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VMOVDQU32/VMOVDQU64
  (0x6F, 0b11,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VMOVDQU8/VMOVDQU16
  (0x70, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_NONE), // VPSHUFD
  (0x70, 0b10,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPSHUFHW
  (0x70, 0b11,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPSHUFLW
  (0x71, 0b01,   _, 0b010,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSRLW
  (0x71, 0b01,   _, 0b100,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSRAW
  (0x71, 0b01,   _, 0b110,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSLLW
  (0x72, 0b01, 0b0, 0b000,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPRORD
  (0x72, 0b01, 0b1, 0b000,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPRORQ
  (0x72, 0b01, 0b0, 0b001,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPROLD
  (0x72, 0b01, 0b1, 0b001,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPROLQ
  (0x72, 0b01, 0b0, 0b010,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPSRLD
  (0x72, 0b01, 0b0, 0b100,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPSRAD
  (0x72, 0b01, 0b1, 0b100,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPSRAQ
  (0x72, 0b01, 0b0, 0b110,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPSLLD
  (0x73, 0b01, 0b1, 0b010,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPSRLQ
  (0x73, 0b01,   _, 0b011,     _) => evex_form(0b111, V_REG,  K_NONE,      0, RC_NONE), // VPSRLDQ
  (0x73, 0b01, 0b1, 0b110,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPSLLQ
  (0x73, 0b01,   _, 0b111,     _) => evex_form(0b111, V_REG,  K_NONE,      0, RC_NONE), // VPSLLDQ
  (0x74, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,     0, RC_NONE), // VPCMPEQB
  (0x75, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,     0, RC_NONE), // VPCMPEQW
  (0x76, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,    32, RC_NONE), // VPCMPEQD
  (0x78, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_SAE), // VCVTTPS2UDQ
  (0x78, 0b00, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_SAE), // VCVTTPD2UDQ
  (0x78, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_SAE), // VCVTTPS2UQQ
  (0x78, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_SAE), // VCVTTPD2UQQ
  (0x78, 0b10,   _,     _,     _) => evex_form(0b000, V_NONE, K_NONE,      0, RC_SAE), // VCVTTSS2USI
  (0x78, 0b11,   _,     _,     _) => evex_form(0b000, V_NONE, K_NONE,      0, RC_SAE), // VCVTTSD2USI
  (0x79, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_ER), // VCVTPS2UDQ
  (0x79, 0b00, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_ER), // VCVTPD2UDQ
  (0x79, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_ER), // VCVTPS2UQQ
  (0x79, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_ER), // VCVTPD2UQQ
  (0x79, 0b10,   _,     _,     _) => evex_form(0b000, V_NONE, K_NONE,      0, RC_ER), // VCVTSS2USI
  (0x79, 0b11,   _,     _,     _) => evex_form(0b000, V_NONE, K_NONE,      0, RC_ER), // VCVTSD2USI
  (0x7A, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_SAE), // VCVTTPS2QQ
  (0x7A, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_SAE), // VCVTTPD2QQ
  (0x7A, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_ER), // VCVTUDQ2PD (EVEX.b as W1)
  (0x7A, 0b10, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_ER), // VCVTUQQ2PD
  (0x7A, 0b11, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_ER), // VCVTUDQ2PS
  (0x7A, 0b11, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_ER), // VCVTUQQ2PS
  (0x7B, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_ER), // VCVTPS2QQ
  (0x7B, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_ER), // VCVTPD2QQ
  (0x7B, 0b10,   _,     _,     _) => evex_form(0b000, V_REG,  K_NONE,      0, RC_ER), // VCVTUSI2SS
  (0x7B, 0b11, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_NONE,      0, RC_ER), // VCVTUSI2SD (EVEX.b as W1)
  (0x7B, 0b11, 0b1,     _,     _) => evex_form(0b000, V_REG,  K_NONE,      0, RC_ER), // VCVTUSI2SD
  (0x7E, 0b01,   _,     _,     _) => evex_form(0b001, V_NONE, K_NONE_RM,   0, RC_NONE), // VMOVD/VMOVQ
  (0x7E, 0b10, 0b1,     _,     _) => evex_form(0b001, V_NONE, K_NONE,      0, RC_NONE), // VMOVQ
  (0x7F, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VMOVDQA32/VMOVDQA64
  (0x7F, 0b10,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VMOVDQU32/VMOVDQU64
  (0x7F, 0b11,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VMOVDQU8/VMOVDQU16
  (0xC2, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,    32, RC_SAE), // VCMPPS
  (0xC2, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,    64, RC_SAE), // VCMPPD
  (0xC2, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_MERGE,     0, RC_SAE), // VCMPSS
  (0xC2, 0b11, 0b1,     _,     _) => evex_form(0b000, V_REG,  K_MERGE,     0, RC_SAE), // VCMPSD
  (0xC4, 0b01,   _,     _,     _) => evex_form(0b001, V_REG,  K_NONE,      0, RC_NONE), // VPINSRW
  (0xC5, 0b01,   _,     _,  true) => evex_form(0b001, V_NONE, K_NONE,      0, RC_NONE), // VPEXTRW
  (0xC6, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VSHUFPS
  (0xC6, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VSHUFPD
  (0xD1, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSRLW
  (0xD2, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSRLD
  (0xD3, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSRLQ
  (0xD4, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPADDQ
  (0xD5, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPMULLW
  (0xD6, 0b01, 0b1,     _,     _) => evex_form(0b001, V_NONE, K_NONE_RM,   0, RC_NONE), // VMOVQ
  (0xD8, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSUBUSB
  (0xD9, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSUBUSW
  (0xDA, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPMINUB
  (0xDB, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPANDD
  (0xDB, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPANDQ
  (0xDC, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPADDUSB
  (0xDD, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPADDUSW
  (0xDE, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPMAXUB
  (0xDF, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPANDND
  (0xDF, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPANDNQ
  (0xE0, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPAVGB
  (0xE1, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSRAW
  (0xE2, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSRAD/VPSRAQ
  (0xE3, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPAVGW
  (0xE4, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPMULHUW
  (0xE5, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPMULHW
  (0xE6, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_SAE), // VCVTTPD2DQ
  (0xE6, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_ER), // VCVTDQ2PD (EVEX.b as W1)
  (0xE6, 0b10, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_ER), // VCVTQQ2PD
  (0xE6, 0b11, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_ER), // VCVTPD2DQ
  (0xE7, 0b01, 0b0,     _, false) => evex_form(0b111, V_NONE, K_NONE_RM,   0, RC_NONE), // VMOVNTDQ
  (0xE8, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSUBSB
  (0xE9, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSUBSW
  (0xEA, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPMINSW
  (0xEB, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPORD
  (0xEB, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPORQ
  (0xEC, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPADDSB
  (0xED, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPADDSW
  (0xEE, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPMAXSW
  (0xEF, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPXORD
  (0xEF, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPXORQ
  (0xF1, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSLLW
  (0xF2, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSLLD
  (0xF3, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSLLQ
  (0xF4, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPMULUDQ
  (0xF5, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPMADDWD
  (0xF6, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_NONE,      0, RC_NONE), // VPSADBW
  (0xF8, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSUBB
  (0xF9, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSUBW
  (0xFA, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPSUBD
  (0xFB, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPSUBQ
  (0xFC, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPADDB
  (0xFD, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPADDW
  (0xFE, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPADDD
  _ => None()
}

val evex_form_0f38 : (byte, bits(2), bit, bits(3), bool) -> option(EvexForm)
function evex_form_0f38(op, pp, w, digit, is_reg) = match (op, pp, w, digit, is_reg) {
  (0x00, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSHUFB
  (0x04, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPMADDUBSW
  (0x0B, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPMULHRSW
  (0x0C, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPERMILPS
  (0x0D, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPERMILPD
  (0x10, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSRLVW
  (0x10, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPMOVUSWB
  (0x11, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSRAVW
  (0x11, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPMOVUSDB
  (0x12, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSLLVW
  (0x12, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPMOVUSQB
  (0x13, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_SAE), // VCVTPH2PS
  (0x13, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPMOVUSDW
  (0x14, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPRORVD
  (0x14, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPRORVQ
  (0x14, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPMOVUSQW
  (0x15, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPROLVD
  (0x15, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPROLVQ
  (0x15, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPMOVUSQD
  (0x16, 0b01, 0b0,     _,     _) => evex_form(0b110, V_REG,  K_ZERO,     32, RC_NONE), // VPERMPS
  (0x16, 0b01, 0b1,     _,     _) => evex_form(0b110, V_REG,  K_ZERO,     64, RC_NONE), // VPERMPD
  (0x18, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VBROADCASTSS
  (0x19, 0b01,   _,     _,     _) => evex_form(0b110, V_NONE, K_ZERO,      0, RC_NONE), // VBROADCASTF32X2/VBROADCASTSD
  (0x1A, 0b01,   _,     _, false) => evex_form(0b110, V_NONE, K_ZERO,      0, RC_NONE), // VBROADCASTF32X4/VBROADCASTF64X2
  (0x1B, 0b01,   _,     _, false) => evex_form(0b100, V_NONE, K_ZERO,      0, RC_NONE), // VBROADCASTF32X8/VBROADCASTF64X4
  (0x1C, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPABSB
  (0x1D, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPABSW
  (0x1E, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_NONE), // VPABSD
  (0x1F, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_NONE), // VPABSQ
  (0x20, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPMOVSXBW
  (0x20, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPMOVSWB
  (0x21, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPMOVSXBD
  (0x21, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPMOVSDB
  (0x22, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPMOVSXBQ
  (0x22, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPMOVSQB
  (0x23, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPMOVSXWD
  (0x23, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPMOVSDW
  (0x24, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPMOVSXWQ
  (0x24, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPMOVSQW
  (0x25, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPMOVSXDQ
  (0x25, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPMOVSQD
  (0x26, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,     0, RC_NONE), // VPTESTMB/VPTESTMW
  (0x26, 0b10,   _,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,     0, RC_NONE), // VPTESTNMB/VPTESTNMW
  (0x27, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,    32, RC_NONE), // VPTESTMD
  (0x27, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,    64, RC_NONE), // VPTESTMQ
  (0x27, 0b10, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,    32, RC_NONE), // VPTESTNMD
  (0x27, 0b10, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,    64, RC_NONE), // VPTESTNMQ
  (0x28, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPMULDQ
  (0x28, 0b10,   _,     _,  true) => evex_form(0b111, V_NONE, K_NONE_K,    0, RC_NONE), // VPMOVM2B/VPMOVM2W
  (0x29, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,    64, RC_NONE), // VPCMPEQQ
  (0x29, 0b10,   _,     _,  true) => evex_form(0b111, V_NONE, K_NONE_K,    0, RC_NONE), // VPMOVB2M/VPMOVW2M
  (0x2A, 0b01, 0b0,     _, false) => evex_form(0b111, V_NONE, K_NONE,      0, RC_NONE), // VMOVNTDQA
  (0x2A, 0b10, 0b1,     _,  true) => evex_form(0b111, V_NONE, K_NONE_K,    0, RC_NONE), // VPBROADCASTMB2Q
  (0x2B, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPACKUSDW
  (0x2C, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VSCALEFPS
  (0x2C, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VSCALEFPD
  (0x2D, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VSCALEFSS/VSCALEFSD
  (0x30, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPMOVZXBW
  (0x30, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPMOVWB
  (0x31, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPMOVZXBD
  (0x31, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPMOVDB
  (0x32, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPMOVZXBQ
  (0x32, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPMOVQB
  (0x33, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPMOVZXWD
  (0x33, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPMOVDW
  (0x34, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPMOVZXWQ
  (0x34, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPMOVQW
  (0x35, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPMOVZXDQ
  (0x35, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPMOVQD
  (0x36, 0b01, 0b0,     _,     _) => evex_form(0b110, V_REG,  K_ZERO,     32, RC_NONE), // VPERMD
  (0x36, 0b01, 0b1,     _,     _) => evex_form(0b110, V_REG,  K_ZERO,     64, RC_NONE), // VPERMQ
  (0x37, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,    64, RC_NONE), // VPCMPGTQ
  (0x38, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPMINSB
  (0x38, 0b10,   _,     _,  true) => evex_form(0b111, V_NONE, K_NONE_K,    0, RC_NONE), // VPMOVM2D/VPMOVM2Q
  (0x39, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPMINSD
  (0x39, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPMINSQ
  (0x39, 0b10,   _,     _,  true) => evex_form(0b111, V_NONE, K_NONE_K,    0, RC_NONE), // VPMOVD2M/VPMOVQ2M
  (0x3A, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPMINUW
  (0x3A, 0b10, 0b0,     _,  true) => evex_form(0b111, V_NONE, K_NONE_K,    0, RC_NONE), // VPBROADCASTMW2D
  (0x3B, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPMINUD
  (0x3B, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPMINUQ
  (0x3C, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPMAXSB
  (0x3D, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPMAXSD
  (0x3D, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPMAXSQ
  (0x3E, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPMAXUW
  (0x3F, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPMAXUD
  (0x3F, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPMAXUQ
  (0x40, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPMULLD
  (0x40, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPMULLQ
  (0x42, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_SAE), // VGETEXPPS
  (0x42, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_SAE), // VGETEXPPD
  (0x43, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VGETEXPSS/VGETEXPSD
  (0x44, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_NONE), // VPLZCNTD
  (0x44, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_NONE), // VPLZCNTQ
  (0x45, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPSRLVD
  (0x45, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPSRLVQ
  (0x46, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPSRAVD
  (0x46, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPSRAVQ
  (0x47, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPSLLVD
  (0x47, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPSLLVQ
  (0x4C, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_NONE), // VRCP14PS
  (0x4C, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_NONE), // VRCP14PD
  (0x4D, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_NONE), // VRCP14SS/VRCP14SD
  (0x4E, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_NONE), // VRSQRT14PS
  (0x4E, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_NONE), // VRSQRT14PD
  (0x4F, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_NONE), // VRSQRT14SS/VRSQRT14SD
  (0x50, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPDPBUSD
  (0x51, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPDPBUSDS
  (0x52, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPDPWSSD
  (0x52, 0b10, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VDPBF16PS
  (0x52, 0b11, 0b0,     _, false) => evex_form(0b100, V_REG,  K_ZERO,      0, RC_NONE), // VP4DPWSSD
  (0x53, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPDPWSSDS
  (0x53, 0b11, 0b0,     _, false) => evex_form(0b100, V_REG,  K_ZERO,      0, RC_NONE), // VP4DPWSSDS
  (0x54, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPOPCNTB/VPOPCNTW
  (0x55, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_NONE), // VPOPCNTD
  (0x55, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_NONE), // VPOPCNTQ
  (0x58, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPBROADCASTD
  (0x59, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VBROADCASTI32X2/VPBROADCASTQ
  (0x5A, 0b01,   _,     _, false) => evex_form(0b110, V_NONE, K_ZERO,      0, RC_NONE), // VBROADCASTI32X4/VBROADCASTI64X2
  (0x5B, 0b01,   _,     _, false) => evex_form(0b100, V_NONE, K_ZERO,      0, RC_NONE), // VBROADCASTI32X8/VBROADCASTI64X4
  (0x62, 0b01,   _,     _,  true) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPEXPANDB/VPEXPANDW
  (0x62, 0b01,   _,     _, false) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPEXPANDB/VPEXPANDW
  (0x63, 0b01,   _,     _,  true) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPCOMPRESSB/VPCOMPRESSW
  (0x63, 0b01,   _,     _, false) => evex_form(0b111, V_NONE, K_MERGE,     0, RC_NONE), // VPCOMPRESSB/VPCOMPRESSW
  (0x64, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPBLENDMD
  (0x64, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPBLENDMQ
  (0x65, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VBLENDMPS
  (0x65, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VBLENDMPD
  (0x66, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPBLENDMB/VPBLENDMW
  (0x68, 0b11, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_NONE_K,   32, RC_NONE), // VP2INTERSECTD
  (0x68, 0b11, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_NONE_K,   64, RC_NONE), // VP2INTERSECTQ
  (0x70, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSHLDVW
  (0x71, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPSHLDVD
  (0x71, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPSHLDVQ
  (0x72, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSHRDVW
  (0x72, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_NONE), // VCVTNEPS2BF16
  (0x72, 0b11, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VCVTNE2PS2BF16
  (0x73, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPSHRDVD
  (0x73, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPSHRDVQ
  (0x75, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPERMI2B/VPERMI2W
  (0x76, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPERMI2D
  (0x76, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPERMI2Q
  (0x77, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPERMI2PS
  (0x77, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPERMI2PD
  (0x78, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPBROADCASTB
  (0x79, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPBROADCASTW
  (0x7A, 0b01, 0b0,     _,  true) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPBROADCASTB
  (0x7B, 0b01, 0b0,     _,  true) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPBROADCASTW
  (0x7C, 0b01,   _,     _,  true) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPBROADCASTD/VPBROADCASTQ
  (0x7D, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPERMT2B/VPERMT2W
  (0x7E, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPERMT2D
  (0x7E, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPERMT2Q
  (0x7F, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPERMT2PS
  (0x7F, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPERMT2PD
  (0x83, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPMULTISHIFTQB
  (0x88, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VEXPANDPS/VEXPANDPD
  (0x89, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,      0, RC_NONE), // VPEXPANDD/VPEXPANDQ
  (0x8A, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VCOMPRESSPS/VCOMPRESSPD
  (0x8B, 0b01,   _,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_NONE), // VPCOMPRESSD/VPCOMPRESSQ
  (0x8D, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPERMB/VPERMW
  (0x8F, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,     0, RC_NONE), // VPSHUFBITQMB
  (0x90, 0b01,   _,     _, false) => evex_form(0b111, V_VSIB, K_MERGE,     0, RC_NONE), // VPGATHERDD/VPGATHERDQ
  (0x91, 0b01,   _,     _, false) => evex_form(0b111, V_VSIB, K_MERGE,     0, RC_NONE), // VPGATHERQD/VPGATHERQQ
  (0x92, 0b01,   _,     _, false) => evex_form(0b111, V_VSIB, K_MERGE,     0, RC_NONE), // VGATHERDPS/VGATHERDPD
  (0x93, 0b01,   _,     _, false) => evex_form(0b111, V_VSIB, K_MERGE,     0, RC_NONE), // VGATHERQPS/VGATHERQPD
  (0x96, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFMADDSUB132PS
  (0x96, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VFMADDSUB132PD
  (0x97, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFMSUBADD132PS
  (0x97, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VFMSUBADD132PD
  (0x98, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFMADD132PS
  (0x98, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VFMADD132PD
  (0x99, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFMADD132SS/VFMADD132SD
  (0x9A, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFMSUB132PS
  (0x9A, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VFMSUB132PD
  (0x9A, 0b11, 0b0,     _, false) => evex_form(0b100, V_REG,  K_ZERO,      0, RC_NONE), // V4FMADDPS
  (0x9B, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFMSUB132SS/VFMSUB132SD
  (0x9B, 0b11, 0b0,     _, false) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_NONE), // V4FMADDSS
  (0x9C, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFNMADD132PS
  (0x9C, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VFNMADD132PD
  (0x9D, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFNMADD132SS/VFNMADD132SD
  (0x9E, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFNMSUB132PS
  (0x9E, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VFNMSUB132PD
  (0x9F, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFNMSUB132SS/VFNMSUB132SD
  (0xA0, 0b01,   _,     _, false) => evex_form(0b111, V_VSIB, K_MERGE,     0, RC_NONE), // VPSCATTERDD/VPSCATTERDQ
  (0xA1, 0b01,   _,     _, false) => evex_form(0b111, V_VSIB, K_MERGE,     0, RC_NONE), // VPSCATTERQD/VPSCATTERQQ
  (0xA2, 0b01,   _,     _, false) => evex_form(0b111, V_VSIB, K_MERGE,     0, RC_NONE), // VSCATTERDPS/VSCATTERDPD
  (0xA3, 0b01,   _,     _, false) => evex_form(0b111, V_VSIB, K_MERGE,     0, RC_NONE), // VSCATTERQPS/VSCATTERQPD
  (0xA6, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFMADDSUB213PS
  (0xA6, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VFMADDSUB213PD
  (0xA7, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFMSUBADD213PS
  (0xA7, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VFMSUBADD213PD
  (0xA8, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFMADD213PS
  (0xA8, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VFMADD213PD
  (0xA9, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFMADD213SS/VFMADD213SD
  (0xAA, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFMSUB213PS
  (0xAA, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VFMSUB213PD
  (0xAA, 0b11, 0b0,     _, false) => evex_form(0b100, V_REG,  K_ZERO,      0, RC_NONE), // V4FNMADDPS
  (0xAB, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFMSUB213SS/VFMSUB213SD
  (0xAB, 0b11, 0b0,     _, false) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_NONE), // V4FNMADDSS
  (0xAC, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFNMADD213PS
  (0xAC, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VFNMADD213PD
  (0xAD, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFNMADD213SS/VFNMADD213SD
  (0xAE, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFNMSUB213PS
  (0xAE, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VFNMSUB213PD
  (0xAF, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFNMSUB213SS/VFNMSUB213SD
  (0xB4, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPMADD52LUQ
  (0xB5, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPMADD52HUQ
  (0xB6, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFMADDSUB231PS
  (0xB6, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VFMADDSUB231PD
  (0xB7, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFMSUBADD231PS
  (0xB7, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VFMSUBADD231PD
  (0xB8, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFMADD231PS
  (0xB8, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VFMADD231PD
  (0xB9, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFMADD231SS/VFMADD231SD
  (0xBA, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFMSUB231PS
  (0xBA, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VFMSUB231PD
  (0xBB, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFMSUB231SS/VFMSUB231SD
  (0xBC, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFNMADD231PS
  (0xBC, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VFNMADD231PD
  (0xBD, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFNMADD231SS/VFNMADD231SD
  (0xBE, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFNMSUB231PS
  (0xBE, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_ER), // VFNMSUB231PD
  (0xBF, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFNMSUB231SS/VFNMSUB231SD
  (0xC4, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_NONE), // VPCONFLICTD
  (0xC4, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_NONE), // VPCONFLICTQ
  (0xC6, 0b01,   _, 0b001, false) => evex_form(0b100, V_VSIB, K_MERGE,     0, RC_NONE), // VGATHERPF0DPS/VGATHERPF0DPD
  (0xC6, 0b01,   _, 0b010, false) => evex_form(0b100, V_VSIB, K_MERGE,     0, RC_NONE), // VGATHERPF1DPS/VGATHERPF1DPD
  (0xC6, 0b01,   _, 0b101, false) => evex_form(0b100, V_VSIB, K_MERGE,     0, RC_NONE), // VSCATTERPF0DPS/VSCATTERPF0DPD
  (0xC6, 0b01,   _, 0b110, false) => evex_form(0b100, V_VSIB, K_MERGE,     0, RC_NONE), // VSCATTERPF1DPS/VSCATTERPF1DPD
  (0xC7, 0b01,   _, 0b001, false) => evex_form(0b100, V_VSIB, K_MERGE,     0, RC_NONE), // VGATHERPF0QPS/VGATHERPF0QPD
  (0xC7, 0b01,   _, 0b010, false) => evex_form(0b100, V_VSIB, K_MERGE,     0, RC_NONE), // VGATHERPF1QPS/VGATHERPF1QPD
  (0xC7, 0b01,   _, 0b101, false) => evex_form(0b100, V_VSIB, K_MERGE,     0, RC_NONE), // VSCATTERPF0QPS/VSCATTERPF0QPD
  (0xC7, 0b01,   _, 0b110, false) => evex_form(0b100, V_VSIB, K_MERGE,     0, RC_NONE), // VSCATTERPF1QPS/VSCATTERPF1QPD
  (0xC8, 0b01, 0b0,     _,     _) => evex_form(0b100, V_NONE, K_ZERO,     32, RC_SAE), // VEXP2PS
  (0xC8, 0b01, 0b1,     _,     _) => evex_form(0b100, V_NONE, K_ZERO,     64, RC_SAE), // VEXP2PD
  (0xCA, 0b01, 0b0,     _,     _) => evex_form(0b100, V_NONE, K_ZERO,     32, RC_SAE), // VRCP28PS
  (0xCA, 0b01, 0b1,     _,     _) => evex_form(0b100, V_NONE, K_ZERO,     64, RC_SAE), // VRCP28PD
  (0xCB, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VRCP28SS/VRCP28SD
  (0xCC, 0b01, 0b0,     _,     _) => evex_form(0b100, V_NONE, K_ZERO,     32, RC_SAE), // VRSQRT28PS
  (0xCC, 0b01, 0b1,     _,     _) => evex_form(0b100, V_NONE, K_ZERO,     64, RC_SAE), // VRSQRT28PD
  (0xCD, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VRSQRT28SS/VRSQRT28SD
  (0xCF, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VGF2P8MULB
  (0xDC, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_NONE,      0, RC_NONE), // VAESENC
  (0xDD, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_NONE,      0, RC_NONE), // VAESENCLAST
  (0xDE, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_NONE,      0, RC_NONE), // VAESDEC
  (0xDF, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_NONE,      0, RC_NONE), // VAESDECLAST
  _ => None()
}

val evex_form_0f3a : (byte, bits(2), bit, bits(3), bool) -> option(EvexForm)
function evex_form_0f3a(op, pp, w, digit, is_reg) = match (op, pp, w, digit, is_reg) {
  (0x00, 0b01, 0b1,     _,     _) => evex_form(0b110, V_NONE, K_ZERO,     64, RC_NONE), // VPERMQ
  (0x01, 0b01, 0b1,     _,     _) => evex_form(0b110, V_NONE, K_ZERO,     64, RC_NONE), // VPERMPD
  (0x03, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VALIGND
  (0x03, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VALIGNQ
  (0x04, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_NONE), // VPERMILPS
  (0x05, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_NONE), // VPERMILPD
  (0x08, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_SAE), // VRNDSCALEPH
  (0x08, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_SAE), // VRNDSCALEPS
  (0x09, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_SAE), // VRNDSCALEPD
  (0x0A, 0b00, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VRNDSCALESH
  (0x0A, 0b01, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VRNDSCALESS
  (0x0B, 0b01, 0b1,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VRNDSCALESD
  (0x0F, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPALIGNR
  (0x14, 0b01,   _,     _,     _) => evex_form(0b001, V_NONE, K_NONE_RM,   0, RC_NONE), // VPEXTRB
  (0x15, 0b01,   _,     _,     _) => evex_form(0b001, V_NONE, K_NONE_RM,   0, RC_NONE), // VPEXTRW
  (0x16, 0b01,   _,     _,     _) => evex_form(0b001, V_NONE, K_NONE_RM,   0, RC_NONE), // VPEXTRD/VPEXTRQ
  (0x17, 0b01,   _,     _,     _) => evex_form(0b001, V_NONE, K_NONE_RM,   0, RC_NONE), // VEXTRACTPS
  (0x18, 0b01,   _,     _,     _) => evex_form(0b110, V_REG,  K_ZERO,      0, RC_NONE), // VINSERTF32X4/VINSERTF64X2
  (0x19, 0b01,   _,     _,     _) => evex_form(0b110, V_NONE, K_ZERO_RM,   0, RC_NONE), // VEXTRACTF32X4/VEXTRACTF64X2
  (0x1A, 0b01,   _,     _,     _) => evex_form(0b100, V_REG,  K_ZERO,      0, RC_NONE), // VINSERTF32X8/VINSERTF64X4
  (0x1B, 0b01,   _,     _,     _) => evex_form(0b100, V_NONE, K_ZERO_RM,   0, RC_NONE), // VEXTRACTF32X8/VEXTRACTF64X4
  (0x1D, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO_RM,   0, RC_SAE), // VCVTPS2PH
  (0x1E, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,    32, RC_NONE), // VPCMPUD
  (0x1E, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,    64, RC_NONE), // VPCMPUQ
  (0x1F, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,    32, RC_NONE), // VPCMPD
  (0x1F, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,    64, RC_NONE), // VPCMPQ
  (0x20, 0b01,   _,     _,     _) => evex_form(0b001, V_REG,  K_NONE,      0, RC_NONE), // VPINSRB
  (0x21, 0b01, 0b0,     _,     _) => evex_form(0b001, V_REG,  K_NONE,      0, RC_NONE), // VINSERTPS
  (0x22, 0b01,   _,     _,     _) => evex_form(0b001, V_REG,  K_NONE,      0, RC_NONE), // VPINSRD/VPINSRQ
  (0x23, 0b01, 0b0,     _,     _) => evex_form(0b110, V_REG,  K_ZERO,     32, RC_NONE), // VSHUFF32X4
  (0x23, 0b01, 0b1,     _,     _) => evex_form(0b110, V_REG,  K_ZERO,     64, RC_NONE), // VSHUFF64X2
  (0x25, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPTERNLOGD
  (0x25, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPTERNLOGQ
  (0x26, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_SAE), // VGETMANTPH
  (0x26, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_SAE), // VGETMANTPS
  (0x26, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_SAE), // VGETMANTPD
  (0x27, 0b00, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VGETMANTSH
  (0x27, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VGETMANTSS/VGETMANTSD
  (0x38, 0b01,   _,     _,     _) => evex_form(0b110, V_REG,  K_ZERO,      0, RC_NONE), // VINSERTI32X4/VINSERTI64X2
  (0x39, 0b01,   _,     _,     _) => evex_form(0b110, V_NONE, K_ZERO_RM,   0, RC_NONE), // VEXTRACTI32X4/VEXTRACTI64X2
  (0x3A, 0b01,   _,     _,     _) => evex_form(0b100, V_REG,  K_ZERO,      0, RC_NONE), // VINSERTI32X8/VINSERTI64X4
  (0x3B, 0b01,   _,     _,     _) => evex_form(0b100, V_NONE, K_ZERO_RM,   0, RC_NONE), // VEXTRACTI32X8/VEXTRACTI64X4
  (0x3E, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,     0, RC_NONE), // VPCMPUB/VPCMPUW
  (0x3F, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,     0, RC_NONE), // VPCMPB/VPCMPW
  (0x42, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VDBPSADBW
  (0x43, 0b01, 0b0,     _,     _) => evex_form(0b110, V_REG,  K_ZERO,     32, RC_NONE), // VSHUFI32X4
  (0x43, 0b01, 0b1,     _,     _) => evex_form(0b110, V_REG,  K_ZERO,     64, RC_NONE), // VSHUFI64X2
  (0x44, 0b01,   _,     _,     _) => evex_form(0b111, V_REG,  K_NONE,      0, RC_NONE), // VPCLMULQDQ
  (0x50, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_SAE), // VRANGEPS
  (0x50, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_SAE), // VRANGEPD
  (0x51, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VRANGESS/VRANGESD
  (0x54, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_SAE), // VFIXUPIMMPS
  (0x54, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_SAE), // VFIXUPIMMPD
  (0x55, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VFIXUPIMMSS/VFIXUPIMMSD
  (0x56, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_SAE), // VREDUCEPH
  (0x56, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_SAE), // VREDUCEPS
  (0x56, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_SAE), // VREDUCEPD
  (0x57, 0b00, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VREDUCESH
  (0x57, 0b01,   _,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VREDUCESS/VREDUCESD
  (0x66, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_MERGE,    16, RC_NONE), // VFPCLASSPH
  (0x66, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_MERGE,    32, RC_NONE), // VFPCLASSPS
  (0x66, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_MERGE,    64, RC_NONE), // VFPCLASSPD
  (0x67, 0b00, 0b0,     _,     _) => evex_form(0b000, V_NONE, K_MERGE,     0, RC_NONE), // VFPCLASSSH
  (0x67, 0b01,   _,     _,     _) => evex_form(0b000, V_NONE, K_MERGE,     0, RC_NONE), // VFPCLASSSS/VFPCLASSSD
  (0x70, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSHLDW
  (0x71, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPSHLDD
  (0x71, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPSHLDQ
  (0x72, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,      0, RC_NONE), // VPSHRDW
  (0x73, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_NONE), // VPSHRDD
  (0x73, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VPSHRDQ
  (0xC2, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_MERGE,    16, RC_SAE), // VCMPPH
  (0xC2, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_MERGE,     0, RC_SAE), // VCMPSH
  (0xCE, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VGF2P8AFFINEQB
  (0xCF, 0b01, 0b1,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     64, RC_NONE), // VGF2P8AFFINEINVQB
  _ => None()
}

val evex_form_map5 : (byte, bits(2), bit, bits(3), bool) -> option(EvexForm)
function evex_form_map5(op, pp, w, digit, is_reg) = match (op, pp, w, digit, is_reg) {
  (0x10, 0b10, 0b0,     _,  true) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_NONE), // VMOVSH
  (0x10, 0b10, 0b0,     _, false) => evex_form(0b000, V_NONE, K_ZERO,      0, RC_NONE), // VMOVSH
  (0x11, 0b10, 0b0,     _,  true) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_NONE), // VMOVSH
  (0x11, 0b10, 0b0,     _, false) => evex_form(0b000, V_NONE, K_MERGE,     0, RC_NONE), // VMOVSH
  (0x1D, 0b00, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VCVTSS2SH
  (0x1D, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_ER), // VCVTPS2PHX
  (0x2A, 0b10,   _,     _,     _) => evex_form(0b000, V_REG,  K_NONE,      0, RC_ER), // VCVTSI2SH
  (0x2C, 0b10,   _,     _,     _) => evex_form(0b000, V_NONE, K_NONE,      0, RC_SAE), // VCVTTSH2SI
  (0x2D, 0b10,   _,     _,     _) => evex_form(0b000, V_NONE, K_NONE,      0, RC_ER), // VCVTSH2SI
  (0x2E, 0b00, 0b0,     _,     _) => evex_form(0b000, V_NONE, K_NONE,      0, RC_SAE), // VUCOMISH
  (0x2F, 0b00, 0b0,     _,     _) => evex_form(0b000, V_NONE, K_NONE,      0, RC_SAE), // VCOMISH
  (0x51, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_ER), // VSQRTPH
  (0x51, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VSQRTSH
  (0x58, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VADDPH
  (0x58, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VADDSH
  (0x59, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VMULPH
  (0x59, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VMULSH
  (0x5A, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_SAE), // VCVTPH2PD
  (0x5A, 0b01, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_ER), // VCVTPD2PH
  (0x5A, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VCVTSH2SD
  (0x5A, 0b11, 0b1,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VCVTSD2SH
  (0x5B, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_ER), // VCVTDQ2PH
  (0x5B, 0b00, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_ER), // VCVTQQ2PH
  (0x5B, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_ER), // VCVTPH2DQ
  (0x5B, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_SAE), // VCVTTPH2DQ
  (0x5C, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VSUBPH
  (0x5C, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VSUBSH
  (0x5D, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_SAE), // VMINPH
  (0x5D, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VMINSH
  (0x5E, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VDIVPH
  (0x5E, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VDIVSH
  (0x5F, 0b00, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_SAE), // VMAXPH
  (0x5F, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VMAXSH
  (0x6E, 0b01,   _,     _,     _) => evex_form(0b001, V_NONE, K_NONE,      0, RC_NONE), // VMOVW
  (0x78, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_SAE), // VCVTTPH2UDQ
  (0x78, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_SAE), // VCVTTPH2UQQ
  (0x78, 0b10,   _,     _,     _) => evex_form(0b000, V_NONE, K_NONE,      0, RC_SAE), // VCVTTSH2USI
  (0x79, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_ER), // VCVTPH2UDQ
  (0x79, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_ER), // VCVTPH2UQQ
  (0x79, 0b10,   _,     _,     _) => evex_form(0b000, V_NONE, K_NONE,      0, RC_ER), // VCVTSH2USI
  (0x7A, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_SAE), // VCVTTPH2QQ
  (0x7A, 0b11, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     32, RC_ER), // VCVTUDQ2PH
  (0x7A, 0b11, 0b1,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     64, RC_ER), // VCVTUQQ2PH
  (0x7B, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_ER), // VCVTPH2QQ
  (0x7B, 0b10,   _,     _,     _) => evex_form(0b000, V_REG,  K_NONE,      0, RC_ER), // VCVTUSI2SH
  (0x7C, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_SAE), // VCVTTPH2UW
  (0x7C, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_SAE), // VCVTTPH2W
  (0x7D, 0b00, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_ER), // VCVTPH2UW
  (0x7D, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_ER), // VCVTPH2W
  (0x7D, 0b10, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_ER), // VCVTW2PH
  (0x7D, 0b11, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_ER), // VCVTUW2PH
  (0x7E, 0b01,   _,     _,     _) => evex_form(0b001, V_NONE, K_NONE_RM,   0, RC_NONE), // VMOVW
  _ => None()
}

val evex_form_map6 : (byte, bits(2), bit, bits(3), bool) -> option(EvexForm)
function evex_form_map6(op, pp, w, digit, is_reg) = match (op, pp, w, digit, is_reg) {
  (0x13, 0b00, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VCVTSH2SS
  (0x13, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_SAE), // VCVTPH2PSX
  (0x2C, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VSCALEFPH
  (0x2D, 0b01, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VSCALEFSH
  (0x42, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_SAE), // VGETEXPPH
  (0x43, 0b01, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_SAE), // VGETEXPSH
  (0x4C, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_NONE), // VRCPPH
  (0x4D, 0b01, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_NONE), // VRCPSH
  (0x4E, 0b01, 0b0,     _,     _) => evex_form(0b111, V_NONE, K_ZERO,     16, RC_NONE), // VRSQRTPH
  (0x4F, 0b01, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_NONE), // VRSQRTSH
  (0x56, 0b10, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFMADDCPH
  (0x56, 0b11, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFCMADDCPH
  (0x57, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFMADDCSH
  (0x57, 0b11, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFCMADDCSH
  (0x96, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VFMADDSUB132PH
  (0x97, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VFMSUBADD132PH
  (0x98, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VFMADD132PH
  (0x99, 0b01, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFMADD132SH
  (0x9A, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VFMSUB132PH
  (0x9B, 0b01, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFMSUB132SH
  (0x9C, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VFNMADD132PH
  (0x9D, 0b01, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFNMADD132SH
  (0x9E, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VFNMSUB132PH
  (0x9F, 0b01, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFNMSUB132SH
  (0xA6, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VFMADDSUB213PH
  (0xA7, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VFMSUBADD213PH
  (0xA8, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VFMADD213PH
  (0xA9, 0b01, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFMADD213SH
  (0xAA, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VFMSUB213PH
  (0xAB, 0b01, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFMSUB213SH
  (0xAC, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VFNMADD213PH
  (0xAD, 0b01, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFNMADD213SH
  (0xAE, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VFNMSUB213PH
  (0xAF, 0b01, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFNMSUB213SH
  (0xB6, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VFMADDSUB231PH
  (0xB7, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VFMSUBADD231PH
  (0xB8, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VFMADD231PH
  (0xB9, 0b01, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFMADD231SH
  (0xBA, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VFMSUB231PH
  (0xBB, 0b01, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFMSUB231SH
  (0xBC, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VFNMADD231PH
  (0xBD, 0b01, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFNMADD231SH
  (0xBE, 0b01, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     16, RC_ER), // VFNMSUB231PH
  (0xBF, 0b01, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFNMSUB231SH
  (0xD6, 0b10, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFMULCPH
  (0xD6, 0b11, 0b0,     _,     _) => evex_form(0b111, V_REG,  K_ZERO,     32, RC_ER), // VFCMULCPH
  (0xD7, 0b10, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFMULCSH
  (0xD7, 0b11, 0b0,     _,     _) => evex_form(0b000, V_REG,  K_ZERO,      0, RC_ER), // VFCMULCSH
  _ => None()
}

// Whether the processor has the extension of an EVEX form beyond those
// has_avx512 stands for (CPUID leaf 7 in insn_baseline.sail): AVX512-FP16
// (CPUID.(EAX=07H,ECX=0):EDX[23]) for maps 5 and 6 and the 0F3A forms
// with no prefix or F3 (VRNDSCALEPH ... VCMPSH), GFNI, VAES and
// VPCLMULQDQ.  The model implements neither AVX512_4FMAPS nor
// AVX512_4VNNIW (F2 0F38 52, 53, 9A, 9B, AA, AB; Xeon Phi only).
val evex_feature_present : (range(0, 7), byte, bits(2)) -> bool
function evex_feature_present(mmm, opcode, pp) = {
  let op : range(0, 255) = unsigned(opcode);
  match mmm {
    2 => match op {
      // VP4DPWSSD, VP4DPWSSDS, V4FMADDPS, V4FMADDSS, V4FNMADDPS, V4FNMADDSS
      op if op == 82 | op == 83 | op == 154 | op == 155 | op == 170 | op == 171 =>
        pp != 0b11,
      // VGF2P8MULB
      207 => has_gfni,
      // VAESENC, VAESENCLAST, VAESDEC, VAESDECLAST
      op if 220 <= op & op <= 223 => has_vaes,
      _ => true,
    },
    3 => match op {
      // VPCLMULQDQ
      68 => has_vpclmulqdq,
      // VGF2P8AFFINEQB, VGF2P8AFFINEINVQB
      op if op == 206 | op == 207 => has_gfni,
      _ => has_avx512_fp16 | pp == 0b01 | pp == 0b11,
    },
    5 => has_avx512_fp16,
    6 => has_avx512_fp16,
    _ => true,
  }
}

// Whether an EVEX form has an opmask destination in ModR/M.reg (the
// handlers read it with evex_kreg_dest): VPCMPGTB/W/D, VPCMPEQB/W/D and
// VCMPPS/PD/SS/SD (0F 64-66, 74-76, C2); VPTESTM, VPTESTNM, VPCMPEQQ,
// VPMOVB2M/W2M, VPCMPGTQ, VPMOVD2M/Q2M, VP2INTERSECT and VPSHUFBITQMB
// (0F38 26, 27, 29, 37, F3 39, 68, 8F); VPCMP[U]B/W/D/Q, VFPCLASS and
// VCMPPH/SH (0F3A 1E, 1F, 3E, 3F, 66, 67, C2).  The forms table has the
// prefixes of these opcodes.
val evex_kreg_destination : (range(0, 7), byte, bits(2)) -> bool
function evex_kreg_destination(mmm, opcode, pp) = {
  let op : range(0, 255) = unsigned(opcode);
  match mmm {
    1 => (100 <= op & op <= 102) | (116 <= op & op <= 118) | op == 194,
    2 => op == 38 | op == 39 | op == 41 | op == 55 | (op == 57 & pp == 0b10) | op == 104
         | op == 143,
    3 => op == 30 | op == 31 | op == 62 | op == 63 | op == 102 | op == 103 | op == 194,
    _ => false,
  }
}

// Whether an EVEX form has a general-purpose register destination in
// ModR/M.reg: VCVT[T]SS2SI, VCVT[T]SD2SI, VCVT[T]SS2USI and VCVT[T]SD2USI
// (0F 2C, 2D, 78, 79 with F3 or F2), VPEXTRW r32, xmm (0F C5, whose
// memory form is no form) and VCVT[T]SH2SI and VCVT[T]SH2USI (map 5 2C,
// 2D, 78, 79 with F3).
val evex_gpr_destination : (range(0, 7), byte, bits(2)) -> bool
function evex_gpr_destination(mmm, opcode, pp) = {
  let op : range(0, 255) = unsigned(opcode);
  let to_gpr : bool = op == 44 | op == 45 | op == 120 | op == 121;
  match mmm {
    1 => (to_gpr & (pp == 0b10 | pp == 0b11)) | (op == 197 & pp == 0b01),
    5 => to_gpr & pp == 0b10,
    _ => false,
  }
}

// Check an EVEX instruction against the form of its map (mmm), opcode, pp,
// W, ModRM.reg and ModRM.mod, and raise #UD for an encoding the form does
// not allow.  Returns the prefixes with the fields AMD ignores cleared, and
// with the register number in EVEX.vvvv as the mode makes it.
// What a valid EVEX.b means in a register form, static rounding or SAE
// with the 512-bit vector length, is up to the handlers (evex_begin_rc,
// evex_sae_ll in insn_evex.sail).
val evex_check_form : (range(0, 7), byte, Prefixes) -> Prefixes
function evex_check_form(mmm, opcode, pfx) = {
  // Every EVEX instruction has a ModR/M byte.  Peek at it; the handler
  // fetches it again.
  let modrm = fetch(1);
  decode_pos = decode_pos - 1;
  let is_reg = modrm[7..6] == 0b11;
  let pp : bits(2) =
    if pfx.has_opsize then 0b01 else if pfx.has_rep then 0b10
    else if pfx.has_repne then 0b11 else 0b00;
  let w = bool_to_bit(pfx.rex_w);
  let form : option(EvexForm) = match mmm {
    1 => evex_form_0f(opcode, pp, w, modrm[5..3], is_reg),
    2 => evex_form_0f38(opcode, pp, w, modrm[5..3], is_reg),
    3 => evex_form_0f3a(opcode, pp, w, modrm[5..3], is_reg),
    5 => evex_form_map5(opcode, pp, w, modrm[5..3], is_reg),
    6 => evex_form_map6(opcode, pp, w, modrm[5..3], is_reg),
    _ => None(),
  };
  let f : EvexForm = match form {
    Some(f) => f,
    None() => raise_UD(),
  };
  if ~(evex_feature_present(mmm, opcode, pp)) then raise_UD();

  // EVEX.b (Table 2-43): in a register form, static rounding ({er}) or SAE
  // ({sae}); in a memory form, embedded broadcast (§2.7.7); #UD otherwise.
  // AMD ignores it in the register form of a form with a broadcast.
  let b_ignored : bool =
    pfx.evex_b & is_reg & f.rounding == RC_NONE & f.bcst != 0 & vendor == Vendor_AMD;
  if pfx.evex_b & ~(b_ignored) & (if is_reg then f.rounding == RC_NONE else f.bcst == 0)
  then raise_UD();
  let rc_form : bool = pfx.evex_b & is_reg & f.rounding != RC_NONE;

  // EVEX.L'L (Table 2-38): one of the vector lengths of the form's rows.
  // Scalar (LLIG) forms ignore it (§2.7.10) but for 11b, which is reserved
  // in every form; {er} and {sae} in a register form use it for the
  // rounding mode or ignore it.
  let len_ok : bool = match pfx.evex_ll {
    0 => f.lengths == 0b000 | f.lengths[0] == bitone,
    1 => f.lengths == 0b000 | f.lengths[1] == bitone,
    2 => f.lengths == 0b000 | f.lengths[2] == bitone,
    _ => false,
  };
  if ~(rc_form) & ~(len_ok) then raise_UD();

  // EVEX.vvvv and EVEX.V' (Table 2-41) are 1111b and 1 where they encode
  // no register (pfx.evex_vvvvv holds them inverted).  Outside 64-bit mode
  // the top bit of a vvvv that names a register is ignored ("P[14]
  // ignored"), and V' = 1 is #UD where it would extend a register number,
  // the vvvv operand or the VSIB index; where vvvv names nothing, the whole
  // field must still be 1111b.  An Emerald Rapids follows these rules; a
  // Zen 4 ignores V' as well where vvvv names a register.
  let legacy : bool = cur_mode != LongMode;
  match f.vvvv {
    V_REG  => if legacy & pfx.evex_vvvvv >= 16 & vendor == Vendor_Intel then raise_UD(),
    V_NONE => if pfx.evex_vvvvv != 0 then raise_UD(),
    V_VSIB => if pfx.evex_vvvvv % 16 != 0 | legacy & pfx.evex_vvvvv >= 16 then raise_UD(),
  };
  let vvvvv : simd_idx = if legacy & f.vvvv == V_REG then pfx.evex_vvvvv % 8 else pfx.evex_vvvvv;

  // EVEX.aaa and EVEX.z (Table 2-42): an instruction without an opmask
  // needs aaa = 000b, and a gather or scatter, which updates its mask,
  // aaa != 000b.  Zeroing-masking needs a mask (aaa != 000b) and is #UD
  // for opmask operands, stores, gathers and scatters.  AMD ignores
  // EVEX.z in a form without masking unless the zeroing would apply to an
  // opmask or memory operand.
  let masked = pfx.evex_aaa != 0;
  let unmasked_form : bool = match f.masking {
    K_NONE    => true,
    K_NONE_RM => true,
    K_NONE_K  => true,
    _         => false,
  };
  if unmasked_form & masked then raise_UD();
  if f.vvvv == V_VSIB & ~(masked) then raise_UD();
  let zeroing_ok : bool = masked & (f.masking == K_ZERO | f.masking == K_ZERO_RM & is_reg);
  let z_ignored : bool =
    vendor == Vendor_AMD & (f.masking == K_NONE | f.masking == K_NONE_RM & is_reg);
  if pfx.evex_z == bitone & ~(zeroing_ok) & ~(z_ignored) then raise_UD();

  // The conditions of single instructions: a VSIB operand needs a SIB byte,
  // and a gather's destination must not be its index register (SDM
  // VPGATHERDD etc.: "#UD fault if ModRM.rm is different than 100b", "if
  // the destination vector zmm1 is the same as index vector VINDEX"); an
  // opmask destination is k0-k7, so R and R' must be 0, and a
  // general-purpose register in ModR/M.reg is one of 16, so R' must be 0
  // in 64-bit mode (SDM Vol.2A Table 2-41, of the encoded, inverted bits:
  // "ModRM.reg encodes k-reg If EVEX.R = 0", "ModRM.reg encodes k-reg or
  // GPR If 0", non-64-bit "None (ignored)"; APM Vol.4 §3.2.4: "When
  // ModR/M.reg specifies a K register #UD ... Cannot specify a K register
  // above k7", "EVEX.R' == 0 | When ModR/M.reg specifies a K register or a
  // General Purpose Register | #UD | Ign"); and a complex FP16 multiply's
  // destination must be neither source (SDM VFCMADDCPH etc.: "#UD If
  // (dest_reg == src1_reg) or (dest_reg == src2_reg)").  Like every #UD of
  // the encoding, these come ahead of the #NM of CR0.TS (exceptions.sail).
  let op : range(0, 255) = unsigned(opcode);
  let dst = evex_reg_idx(modrm, pfx);
  if f.vvvv == V_VSIB then {
    if modrm[2..0] != 0b100 then raise_UD();
    let sib = peek_sib();
    let index : simd_idx =
      (if pfx.evex_vvvvv >= 16 then 16 else 0) + unsigned(pfx.rex_x @ sib[5..3]);
    if mmm == 2 & 144 <= op & op <= 147 & dst == index then raise_UD()
  };
  if evex_kreg_destination(mmm, opcode, pp) & (pfx.rex_r == 0b1 | pfx.evex_rr == 0b1)
  then raise_UD();
  // (Outside 64-bit mode decode_evex_with_p0 has cleared EVEX.R'.)
  if evex_gpr_destination(mmm, opcode, pp) & pfx.evex_rr == 0b1 then raise_UD();
  let complex_fp16 : bool = mmm == 6 & (op == 86 | op == 87 | op == 214 | op == 215);
  if complex_fp16 & (dst == vvvvv | is_reg & dst == evex_rm_reg_idx(modrm, pfx))
  then raise_UD();

  { pfx with evex_b = pfx.evex_b & ~(b_ignored),
             evex_z = if z_ignored then bitzero else pfx.evex_z,
             evex_vvvvv = vvvvv }
}

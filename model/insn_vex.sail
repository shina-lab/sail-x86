// x86-64 — VEX Prefix Decoding and Dispatch
//
// Handles 2-byte VEX (C5h) and 3-byte VEX (C4h) prefixes.
// In 64-bit mode, C4/C5 are always VEX prefixes (LES/LDS are invalid).
//
// VEX replaces REX + mandatory prefix + opcode escape bytes.
// 2-byte VEX (C5): [C5] [R̄.vvvv.L.pp]       — implies map 0F
// 3-byte VEX (C4): [C4] [R̄.X̄.B̄.mmmmm] [W.vvvv.L.pp]

// =========================================================================
// Scalar FMA: unified dispatch for all 24 scalar FMA variants.
// Replaces exec_vfmadd132ss/sd, exec_vfmsub213ss/sd, etc.
// =========================================================================

enum FMAOrder = { FMA_132, FMA_213, FMA_231 }

val exec_vfma_scalar : (PackedTernaryOp, FMAOrder, bool, simd_idx, xmmword, xmmword) -> unit
function exec_vfma_scalar(op, order, is64, dst, src2, src3) = {
  let d : xmmword = read_simd(dst);
  let (a, b, c) : (xmmword, xmmword, xmmword) = match order {
    FMA_132 => (d, src3, src2),
    FMA_213 => (src2, d, src3),
    FMA_231 => (src2, src3, d),
  };
  let eb = if is64 then 64 else 32;
  write_simd(128, dst, d[127..eb] @ packed_ternary_elem(op, a[(eb - 1)..0], b[(eb - 1)..0], c[(eb - 1)..0]))
}

// Decode a 2-byte VEX prefix (C5 already consumed, byte1 is the payload).
// Returns (Prefixes, opcode_map) where opcode_map is always 1 (0F).
val decode_vex2 : byte -> (Prefixes, range(0, 31))
function decode_vex2(byte1) = {
  let pfx = {default_prefixes() with
    vex_present = true,
    // R̄ is bit 7 (inverted)
    rex_r = ~(byte1[7]),
    // vvvv is bits 6:3 (inverted)
    vex_vvvv = 15 - unsigned(byte1[6..3]),
    // L is bit 2
    vex_l = byte1[2] == 0b1,
    // pp is bits 1:0 — map to mandatory prefix flags
    has_opsize = byte1[1..0] == 0b01,
    has_rep    = byte1[1..0] == 0b10,
    has_repne  = byte1[1..0] == 0b11,
    has_rex = true, // VEX implies REX-like behavior
  };
  (pfx, 1) // map = 0F
}

// Decode a 3-byte VEX prefix (C4 already consumed, byte1 and byte2 follow).
// Outside 64-bit mode only eight registers exist: R̄ and X̄ are 1, or the
// instruction would be LES (insn_dispatch.sail), and "In 32-bit modes,
// [VEX.B̄] is ignored" (SDM Vol.2A §2.3.5.4).  The top bit of vvvv is
// ignored there only where vvvv names a register (dispatch_vex_with_byte2).
val decode_vex3 : (byte, byte) -> (Prefixes, range(0, 31))
function decode_vex3(byte1, byte2) = {
  let mmmmm : range(0, 31) = unsigned(byte1[4..0]);
  let pfx = {default_prefixes() with
    vex_present = true,
    // R̄, X̄, B̄ are bits 7, 6, 5 of byte1 (inverted)
    rex_r = ~(byte1[7]),
    rex_x = ~(byte1[6]),
    rex_b = if cur_mode != LongMode then bitzero else ~(byte1[5]),
    // W is bit 7 of byte2
    vex_w = byte2[7] == 0b1,
    rex_w = byte2[7] == 0b1,
    // vvvv is bits 6:3 of byte2 (inverted)
    vex_vvvv = 15 - unsigned(byte2[6..3]),
    // L is bit 2 of byte2
    vex_l = byte2[2] == 0b1,
    // pp is bits 1:0 of byte2
    has_opsize = byte2[1..0] == 0b01,
    has_rep    = byte2[1..0] == 0b10,
    has_repne  = byte2[1..0] == 0b11,
    has_rex = true,
  };
  (pfx, mmmmm)
}

// VEX vector length and element size helpers.
val vex_vl : Prefixes -> {128, 256}
function vex_vl(pfx) = if pfx.vex_l then 256 else 128

val vex_elem : Prefixes -> {32, 64}
function vex_elem(pfx) = if pfx.vex_w then 64 else 32

// The size of a general-purpose register or memory operand that VEX.W or
// EVEX.W selects as REX.W does in a legacy instruction: 64 bits with W1 in
// 64-bit mode, else 32.  "VEX.W1 is ignored in non-64-bit modes" (BMI1 and
// BMI2, e.g. SDM Vol.2A ANDN), and "VEX.W1/EVEX.W1 in non-64 bit is
// ignored; the instructions behaves as if the W0 version is used" (VMOVQ,
// VPEXTRQ, VPINSRQ, VCVTSI2SD and the other conversions to and from a GPR;
// §2.3.5.5).  W is an opcode extension or element size elsewhere and is
// not ignored there.
val vex_gpr_size : Prefixes -> {32, 64}
function vex_gpr_size(pfx) = if pfx.vex_w & cur_mode == LongMode then 64 else 32

// Polymorphic VEX source read from r/m field: register or memory.
val decode_vex_src : forall 'vl, 'vl in {128, 256}. (implicit('vl), XRM) -> bits('vl)
function decode_vex_src(vl, xm) = match xm {
  XRM_reg(xi) => read_simd(xi),
  XRM_mem(m)  => read_mem(m),
}

// =========================================================================
// VEX dispatch helpers: absorb common modrm decode + read/write pattern
// =========================================================================

// 3-operand VEX unpack: dst = packed_unpack(eb, half, vvvv, rm)
val vex_exec_unpack : ({8, 16, 32, 64}, {0, 64}, Prefixes) -> unit
function vex_exec_unpack(eb, half, pfx) = {
  let modrm = fetch(1);
  let dst = modrm_xreg(modrm, pfx);
  let src = modrm_xrm(modrm, pfx);
  let vl = vex_vl(pfx);
  write_simd(vl, dst, packed_unpack(eb, half, read_simd(vl, pfx.vex_vvvv), decode_vex_src(src)))
}

// 3-operand VEX pack: dst = packed_pack(op, src_eb, dst_eb, vvvv, rm)
val vex_exec_pack : forall 'src 'dst, 'src in {16, 32} & 'dst in {8, 16} & 'src == 'dst * 2.
  (PackedNarrowOp, int('src), int('dst), Prefixes) -> unit
function vex_exec_pack(op, src_eb, dst_eb, pfx) = {
  let modrm = fetch(1);
  let dst = modrm_xreg(modrm, pfx);
  let src = modrm_xrm(modrm, pfx);
  let vl = vex_vl(pfx);
  write_simd(vl, dst, packed_pack(op, src_eb, dst_eb, read_simd(vl, pfx.vex_vvvv), decode_vex_src(src)))
}

// 3-operand VEX shift-by-xmm: dst = uniform_shift(op, eb, vvvv, count_from_rm[63:0])
val vex_exec_shift : (PackedShiftOp, {16, 32, 64}, Prefixes) -> unit
function vex_exec_shift(op, eb, pfx) = {
  let modrm = fetch(1);
  let dst = modrm_xreg(modrm, pfx);
  let src = modrm_xrm(modrm, pfx);
  let c : nat = unsigned(decode_vex_src(128, src)[63..0]);
  let vl = vex_vl(pfx);
  write_simd(vl, dst, packed_uniform_shift(op, eb, read_simd(vl, pfx.vex_vvvv), c))
}

// 3-operand VEX binop: dst = packed_binop(op, eb, vvvv, rm)
val vex_exec_binop : (PackedBinOp, {8, 16, 32, 64, 128}, Prefixes) -> unit
function vex_exec_binop(op, eb, pfx) = {
  let modrm = fetch(1);
  let dst = modrm_xreg(modrm, pfx);
  let src = modrm_xrm(modrm, pfx);
  let vl = vex_vl(pfx);
  write_simd(vl, dst, packed_binop(op, eb, read_simd(vl, pfx.vex_vvvv), decode_vex_src(src)))
}

// Opmask register operands of the VEX opmask instructions, whose forms
// (VEX.L1 for the three-operand ones, L0 for the others; register r/m
// except for KMOV) are in vex_forms_0f and vex_forms_0f3a.  Opmask
// registers have three-bit numbers: an opmask in ModR/M.reg with VEX.R
// set, or in 64-bit mode in VEX.vvvv with its bit 3 set, is #UD, which
// vex_check_form raises, and VEX.B for an opmask in ModR/M.r/m is ignored
// (SDM Vol.2A Table 2-41 and its note 1, "This table also represents VEX
// restrictions": "EVEX.B | ModRM.r/m encodes k-reg | None (ignored) |
// None (ignored)"; APM Vol.4 §3.2.5: "EVEX.B == 0 | When ModRM.bbb
// specifies a K Register | Ign | Ign | KADDQ").
val vex_kreg_reg : byte -> kreg_idx
function vex_kreg_reg(modrm) = unsigned(modrm[5..3])

val vex_kreg_vvvv : Prefixes -> kreg_idx
function vex_kreg_vvvv(pfx) = pfx.vex_vvvv % 8

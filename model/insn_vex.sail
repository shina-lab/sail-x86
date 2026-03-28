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
  let d = read_xmm(dst);
  if ~(is64) then {
    let r : dword = match order {
      FMA_132 => packed_ternary_elem(op, d[31..0], src3[31..0], src2[31..0]),
      FMA_213 => packed_ternary_elem(op, src2[31..0], d[31..0], src3[31..0]),
      FMA_231 => packed_ternary_elem(op, src2[31..0], src3[31..0], d[31..0]),
    };
    write_xmm(dst, d[127..32] @ r)
  } else {
    let r : qword = match order {
      FMA_132 => packed_ternary_elem(op, d[63..0], src3[63..0], src2[63..0]),
      FMA_213 => packed_ternary_elem(op, src2[63..0], d[63..0], src3[63..0]),
      FMA_231 => packed_ternary_elem(op, src2[63..0], src3[63..0], d[63..0]),
    };
    write_xmm(dst, d[127..64] @ r)
  }
}

// =========================================================================
// 128-bit packed integer add/sub helpers
// =========================================================================

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
val decode_vex3 : (byte, byte) -> (Prefixes, range(0, 31))
function decode_vex3(byte1, byte2) = {
  let mmmmm : range(0, 31) = unsigned(byte1[4..0]);
  let pfx = {default_prefixes() with
    vex_present = true,
    // R̄, X̄, B̄ are bits 7, 6, 5 of byte1 (inverted)
    rex_r = ~(byte1[7]),
    rex_x = ~(byte1[6]),
    rex_b = ~(byte1[5]),
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

// Polymorphic VEX source read from r/m field: register or memory.
val decode_vex_src : forall 'vl, 'vl in {128, 256}. (implicit('vl), byte, RM, Prefixes) -> bits('vl)
function decode_vex_src(vl, modrm, rm, pfx) = match rm {
  RM_reg(_) => read_simd(modrm_xmm_rm(modrm, pfx)),
  RM_mem(m) => read_mem(m),
}

// Monomorphic aliases (used by legacy callers).
val decode_vex_src_xmm : (byte, RM, Prefixes) -> xmmword
function decode_vex_src_xmm(modrm, rm, pfx) = decode_vex_src(128, modrm, rm, pfx)

val decode_vex_src_ymm : (byte, RM, Prefixes) -> ymmword
function decode_vex_src_ymm(modrm, rm, pfx) = decode_vex_src(256, modrm, rm, pfx)

// =========================================================================
// VEX dispatch helpers: absorb common modrm decode + read/write pattern
// =========================================================================

// 3-operand VEX binop: dst = packed_binop(op, eb, vvvv, rm)
val vex_exec_binop : (PackedBinOp, {8, 16, 32, 64, 128}, Prefixes) -> unit
function vex_exec_binop(op, eb, pfx) = {
  let modrm = fetch(1);
  let dst = modrm_xmm_reg(modrm, pfx);
  let src = modrm_rm(modrm, pfx);
  let vl = vex_vl(pfx);
  write_simd(vl, dst, packed_binop(op, eb, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx)))
}

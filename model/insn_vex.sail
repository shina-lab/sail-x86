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
// Packed 32-bit ternary operations (fixed dword element size)
//
// For operations like VNNI that decompose each dword internally
// (e.g. multiply bytes/words within each dword and accumulate)
// but don't generalize to other element sizes.
// =========================================================================

// Signed saturation to 32-bit range.
enum TernaryOp32 = { TO32_DPBusd, TO32_DPBusds, TO32_DPWssd, TO32_DPWssds }

val ternary_elem32 : (TernaryOp32, dword, dword, dword) -> dword
function ternary_elem32(op, dst, s1, s2) = match op {
  // VPDPBUSD: unsigned bytes × signed bytes, sum 4 products, accumulate
  TO32_DPBusd => {
    let sum : int = signed(dst)
      + unsigned(s1[7..0])   * signed(s2[7..0])
      + unsigned(s1[15..8])  * signed(s2[15..8])
      + unsigned(s1[23..16]) * signed(s2[23..16])
      + unsigned(s1[31..24]) * signed(s2[31..24]);
    to_bits_truncate(32, sum)
  },
  // VPDPBUSDS: same with signed dword saturation
  TO32_DPBusds => {
    let sum : int = signed(dst)
      + unsigned(s1[7..0])   * signed(s2[7..0])
      + unsigned(s1[15..8])  * signed(s2[15..8])
      + unsigned(s1[23..16]) * signed(s2[23..16])
      + unsigned(s1[31..24]) * signed(s2[31..24]);
    sat_s(to_bits_truncate(33, sum))
  },
  // VPDPWSSD: signed words × signed words, sum 2 products, accumulate
  TO32_DPWssd => {
    let sum : int = signed(dst)
      + signed(s1[15..0])  * signed(s2[15..0])
      + signed(s1[31..16]) * signed(s2[31..16]);
    get_slice_int(32, sum, 0)
  },
  // VPDPWSSDS: same with signed dword saturation
  TO32_DPWssds => {
    let sum : int = signed(dst)
      + signed(s1[15..0])  * signed(s2[15..0])
      + signed(s1[31..16]) * signed(s2[31..16]);
    sat_s(to_bits_truncate(33, sum))
  },
}

val packed_ternop32 : forall 'vl, 'vl in {128, 256, 512}.
  (TernaryOp32, bits('vl), bits('vl), bits('vl)) -> bits('vl)
function packed_ternop32(op, a, b, c) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) {
    let hi = i * 32 + 31;
    let lo = i * 32;
    r[hi..lo] = ternary_elem32(op, a[hi..lo], b[hi..lo], c[hi..lo])
  };
  r
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
val vex_exec_binop : (PackedBinOp, {8, 16, 32, 64}, Prefixes) -> unit
function vex_exec_binop(op, eb, pfx) = {
  let modrm = fetch(1);
  let dst = modrm_xmm_reg(modrm, pfx);
  let src = modrm_rm(modrm, pfx);
  let vl = vex_vl(pfx);
  write_simd(vl, dst, packed_binop(op, eb, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx)))
}

// 3-operand VEX horizontal binop: dst = packed_horiz_binop(op, eb, 128, vvvv, rm)
val vex_exec_horiz_binop : (PackedBinOp, {16, 32}, Prefixes) -> unit
function vex_exec_horiz_binop(op, eb, pfx) = {
  let modrm = fetch(1);
  let dst = modrm_xmm_reg(modrm, pfx);
  let src = modrm_rm(modrm, pfx);
  let vl = vex_vl(pfx);
  write_simd(vl, dst, packed_horiz_binop(op, eb, 128, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx)))
}

// 2-operand VEX unop: dst = packed_unop(op, eb, rm) — vvvv must be 0
val vex_exec_unop : (PackedUnaryOp, {8, 16, 32, 64}, Prefixes) -> unit
function vex_exec_unop(op, eb, pfx) = {
  if pfx.vex_vvvv != 0 then raise_UD();
  let modrm = fetch(1);
  let dst = modrm_xmm_reg(modrm, pfx);
  let src = modrm_rm(modrm, pfx);
  let vl = vex_vl(pfx);
  write_simd(vl, dst, packed_unop(op, eb, decode_vex_src(modrm, src, pfx)))
}

// =========================================================================
// SSSE3 VEX helpers — 128-bit lane operations
// =========================================================================

// VPSHUFB: byte shuffle per 128-bit lane (each byte selected by low 4 bits of ctrl;
// high bit of ctrl byte → zero)
val vex_pshufb_128 : (xmmword, xmmword) -> xmmword
function vex_pshufb_128(src, ctrl) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 15) {
    let c : byte = ctrl[(i*8+7)..(i*8)];
    result[(i*8+7)..(i*8)] = pshufb_byte(src, c)
  };
  result
}

val vex_pshufb_256 : (ymmword, ymmword) -> ymmword
function vex_pshufb_256(src, ctrl) =
  vex_pshufb_128(src[255..128], ctrl[255..128]) @ vex_pshufb_128(src[127..0], ctrl[127..0])

// VPMADDUBSW: multiply unsigned bytes by signed bytes, add adjacent pairs with saturation
val vex_pmaddubsw_128 : (xmmword, xmmword) -> xmmword
function vex_pmaddubsw_128(a, b) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let a_even : byte = a[(lo+7)..lo];
    let b_even : byte = b[(lo+7)..lo];
    let a_odd  : byte = a[(lo+15)..(lo+8)];
    let b_odd  : byte = b[(lo+15)..(lo+8)];
    result[(lo+15)..lo] = pmaddubsw_pair(a_even, b_even, a_odd, b_odd)
  };
  result
}

val vex_pmaddubsw_256 : (ymmword, ymmword) -> ymmword
function vex_pmaddubsw_256(a, b) =
  vex_pmaddubsw_128(a[255..128], b[255..128]) @ vex_pmaddubsw_128(a[127..0], b[127..0])

// =========================================================================
// SSE4.1 integer helpers — PMINUW, PCMPEQQ, PHMINPOSUW
// =========================================================================

// PHMINPOSUW: find minimum unsigned word among 8 words.
// Result: bits[15:0] = min value, bits[18:16] = index of min, rest zeroed.
val avx_phminposuw_128 : xmmword -> xmmword
function avx_phminposuw_128(src) = {
  var mv : word = src[15..0];
  var mi : bits(3) = 0b000;

  let v1 : word = src[31..16];
  let d1 : bits(17) = (0b0 @ v1) - (0b0 @ mv);
  let u1 : word = sign_extend(d1[16]);
  mv = (v1 & u1) | (mv & ~(u1));
  mi = (0b001 & u1[2..0]) | (mi & ~(u1[2..0]));

  let v2 : word = src[47..32];
  let d2 : bits(17) = (0b0 @ v2) - (0b0 @ mv);
  let u2 : word = sign_extend(d2[16]);
  mv = (v2 & u2) | (mv & ~(u2));
  mi = (0b010 & u2[2..0]) | (mi & ~(u2[2..0]));

  let v3 : word = src[63..48];
  let d3 : bits(17) = (0b0 @ v3) - (0b0 @ mv);
  let u3 : word = sign_extend(d3[16]);
  mv = (v3 & u3) | (mv & ~(u3));
  mi = (0b011 & u3[2..0]) | (mi & ~(u3[2..0]));

  let v4 : word = src[79..64];
  let d4 : bits(17) = (0b0 @ v4) - (0b0 @ mv);
  let u4 : word = sign_extend(d4[16]);
  mv = (v4 & u4) | (mv & ~(u4));
  mi = (0b100 & u4[2..0]) | (mi & ~(u4[2..0]));

  let v5 : word = src[95..80];
  let d5 : bits(17) = (0b0 @ v5) - (0b0 @ mv);
  let u5 : word = sign_extend(d5[16]);
  mv = (v5 & u5) | (mv & ~(u5));
  mi = (0b101 & u5[2..0]) | (mi & ~(u5[2..0]));

  let v6 : word = src[111..96];
  let d6 : bits(17) = (0b0 @ v6) - (0b0 @ mv);
  let u6 : word = sign_extend(d6[16]);
  mv = (v6 & u6) | (mv & ~(u6));
  mi = (0b110 & u6[2..0]) | (mi & ~(u6[2..0]));

  let v7 : word = src[127..112];
  let d7 : bits(17) = (0b0 @ v7) - (0b0 @ mv);
  let u7 : word = sign_extend(d7[16]);
  mv = (v7 & u7) | (mv & ~(u7));
  mi = (0b111 & u7[2..0]) | (mi & ~(u7[2..0]));

  zeros(109) @ mi @ mv
}

// =========================================================================
// Polymorphic per-128-bit-lane operations (shared by VEX and EVEX)
// =========================================================================

val avx_pmuludq_lane : (xmmword, xmmword) -> xmmword
function avx_pmuludq_lane(a, b) = {
  let prod1 : qword = to_bits(64, unsigned(a[31..0]) * unsigned(b[31..0]));
  let prod0 : qword = to_bits(64, unsigned(a[95..64]) * unsigned(b[95..64]));
  prod0 @ prod1
}

val avx_pmuludq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_pmuludq(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) { let lo = i * 128;
    r[(lo + 127)..lo] = avx_pmuludq_lane(a[(lo + 127)..lo], b[(lo + 127)..lo]) };
  r
}

val avx_pmaddwd_lane : (xmmword, xmmword) -> xmmword
function avx_pmaddwd_lane(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let wlo : range(0, 96) = i * 32;
    let w0 = signed(a[(wlo + 15)..wlo]) * signed(b[(wlo + 15)..wlo]);
    let w1 = signed(a[(wlo + 31)..(wlo + 16)]) * signed(b[(wlo + 31)..(wlo + 16)]);
    r[(wlo + 31)..wlo] = get_slice_int(32, w0 + w1, 0);
  };
  r
}

val avx_pmaddwd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_pmaddwd(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) { let lo = i * 128;
    r[(lo + 127)..lo] = avx_pmaddwd_lane(a[(lo + 127)..lo], b[(lo + 127)..lo]) };
  r
}

val avx_psadbw_64 : (bits(64), bits(64)) -> bits(64)
function avx_psadbw_64(a, b) = {
  var sum : int = 0;
  foreach (i from 0 to 7) {
    let lo : range(0, 56) = i * 8;
    sum = sum + abs_diff8(a[(lo + 7)..lo], b[(lo + 7)..lo]);
  };
  zero_extend(get_slice_int(16, sum, 0))
}

val avx_psadbw_lane : (xmmword, xmmword) -> xmmword
function avx_psadbw_lane(a, b) =
  avx_psadbw_64(a[127..64], b[127..64]) @ avx_psadbw_64(a[63..0], b[63..0])

val avx_psadbw : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_psadbw(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) { let lo = i * 128;
    r[(lo + 127)..lo] = avx_psadbw_lane(a[(lo + 127)..lo], b[(lo + 127)..lo]) };
  r
}

val avx_punpcklbw_lane : (xmmword, xmmword) -> xmmword
function avx_punpcklbw_lane(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let src_lo : range(0, 56) = i * 8; let dst_lo : range(0, 112) = i * 16;
    r[(dst_lo + 7)..dst_lo] = a[(src_lo + 7)..src_lo];
    r[(dst_lo + 15)..(dst_lo + 8)] = b[(src_lo + 7)..src_lo];
  };
  r
}

val avx_punpcklbw : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_punpcklbw(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) { let lo = i * 128;
    r[(lo + 127)..lo] = avx_punpcklbw_lane(a[(lo + 127)..lo], b[(lo + 127)..lo]) };
  r
}

val avx_punpcklwd_lane : (xmmword, xmmword) -> xmmword
function avx_punpcklwd_lane(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let src_lo : range(0, 48) = i * 16; let dst_lo : range(0, 96) = i * 32;
    r[(dst_lo + 15)..dst_lo] = a[(src_lo + 15)..src_lo];
    r[(dst_lo + 31)..(dst_lo + 16)] = b[(src_lo + 15)..src_lo];
  };
  r
}

val avx_punpcklwd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_punpcklwd(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) { let lo = i * 128;
    r[(lo + 127)..lo] = avx_punpcklwd_lane(a[(lo + 127)..lo], b[(lo + 127)..lo]) };
  r
}

val avx_punpckldq_lane : (xmmword, xmmword) -> xmmword
function avx_punpckldq_lane(a, b) = b[63..32] @ a[63..32] @ b[31..0] @ a[31..0]

val avx_punpcklqdq_lane : (xmmword, xmmword) -> xmmword
function avx_punpcklqdq_lane(a, b) = b[63..0] @ a[63..0]

val avx_punpckhbw_lane : (xmmword, xmmword) -> xmmword
function avx_punpckhbw_lane(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let src_lo : range(0, 120) = i * 8 + 64; let dst_lo : range(0, 112) = i * 16;
    r[(dst_lo + 7)..dst_lo] = a[(src_lo + 7)..src_lo];
    r[(dst_lo + 15)..(dst_lo + 8)] = b[(src_lo + 7)..src_lo];
  };
  r
}

val avx_punpckhbw : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_punpckhbw(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) { let lo = i * 128;
    r[(lo + 127)..lo] = avx_punpckhbw_lane(a[(lo + 127)..lo], b[(lo + 127)..lo]) };
  r
}

val avx_punpcklqdq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_punpcklqdq(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) { let lo = i * 128;
    r[(lo + 127)..lo] = avx_punpcklqdq_lane(a[(lo + 127)..lo], b[(lo + 127)..lo]) };
  r
}

val avx_punpckldq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_punpckldq(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) { let lo = i * 128;
    r[(lo + 127)..lo] = avx_punpckldq_lane(a[(lo + 127)..lo], b[(lo + 127)..lo]) };
  r
}

val avx_punpckhwd_lane : (xmmword, xmmword) -> xmmword
function avx_punpckhwd_lane(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let src_lo : range(0, 112) = i * 16 + 64; let dst_lo : range(0, 96) = i * 32;
    r[(dst_lo + 15)..dst_lo] = a[(src_lo + 15)..src_lo];
    r[(dst_lo + 31)..(dst_lo + 16)] = b[(src_lo + 15)..src_lo];
  };
  r
}

val avx_punpckhwd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_punpckhwd(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) { let lo = i * 128;
    r[(lo + 127)..lo] = avx_punpckhwd_lane(a[(lo + 127)..lo], b[(lo + 127)..lo]) };
  r
}

val avx_punpckhdq_lane : (xmmword, xmmword) -> xmmword
function avx_punpckhdq_lane(a, b) = b[127..96] @ a[127..96] @ b[95..64] @ a[95..64]

val avx_punpckhqdq_lane : (xmmword, xmmword) -> xmmword
function avx_punpckhqdq_lane(a, b) = b[127..64] @ a[127..64]

val avx_packsswb_lane : (xmmword, xmmword) -> xmmword
function avx_packsswb_lane(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let src_lo : range(0, 112) = i * 16;
    r[(i * 8 + 7)..(i * 8)] = sat_s(a[(src_lo + 15)..src_lo]);
    r[(i * 8 + 71)..(i * 8 + 64)] = sat_s(b[(src_lo + 15)..src_lo]);
  };
  r
}

val avx_packsswb : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_packsswb(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) { let lo = i * 128;
    r[(lo + 127)..lo] = avx_packsswb_lane(a[(lo + 127)..lo], b[(lo + 127)..lo]) };
  r
}

val avx_punpckhqdq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_punpckhqdq(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) { let lo = i * 128;
    r[(lo + 127)..lo] = avx_punpckhqdq_lane(a[(lo + 127)..lo], b[(lo + 127)..lo]) };
  r
}

val avx_punpckhdq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_punpckhdq(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) { let lo = i * 128;
    r[(lo + 127)..lo] = avx_punpckhdq_lane(a[(lo + 127)..lo], b[(lo + 127)..lo]) };
  r
}

val avx_packssdw_lane : (xmmword, xmmword) -> xmmword
function avx_packssdw_lane(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let src_lo : range(0, 96) = i * 32;
    r[(i * 16 + 15)..(i * 16)] = sat_s(a[(src_lo + 31)..src_lo]);
    r[(i * 16 + 79)..(i * 16 + 64)] = sat_s(b[(src_lo + 31)..src_lo]);
  };
  r
}

val avx_packssdw : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_packssdw(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) { let lo = i * 128;
    r[(lo + 127)..lo] = avx_packssdw_lane(a[(lo + 127)..lo], b[(lo + 127)..lo]) };
  r
}

val avx_packuswb_lane : (xmmword, xmmword) -> xmmword
function avx_packuswb_lane(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let src_lo : range(0, 112) = i * 16;
    r[(i * 8 + 7)..(i * 8)] = sat_su(a[(src_lo + 15)..src_lo]);
    r[(i * 8 + 71)..(i * 8 + 64)] = sat_su(b[(src_lo + 15)..src_lo]);
  };
  r
}

val avx_packuswb : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_packuswb(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) { let lo = i * 128;
    r[(lo + 127)..lo] = avx_packuswb_lane(a[(lo + 127)..lo], b[(lo + 127)..lo]) };
  r
}

val avx_pshufd_lane : (xmmword, byte) -> xmmword
function avx_pshufd_lane(src, imm) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let sel_bits : range(0, 6) = i * 2;
    let sel : range(0, 3) = unsigned(imm[(sel_bits + 1)..sel_bits]);
    let src_lo : range(0, 96) = sel * 32;
    let dst_lo : range(0, 96) = i * 32;
    r[(dst_lo + 31)..dst_lo] = src[(src_lo + 31)..src_lo];
  };
  r
}

val avx_pshufd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits(8)) -> bits('vl)
function avx_pshufd(vl, src, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) { let lo = i * 128;
    r[(lo + 127)..lo] = avx_pshufd_lane(src[(lo + 127)..lo], imm) };
  r
}

val avx_pshufhw_lane : (xmmword, byte) -> xmmword
function avx_pshufhw_lane(src, imm) = {
  var r : xmmword = zeros();
  r[63..0] = src[63..0];
  foreach (i from 0 to 3) {
    let sel_bits : range(0, 6) = i * 2;
    let sel : range(0, 3) = unsigned(imm[(sel_bits + 1)..sel_bits]);
    let src_lo : range(0, 112) = sel * 16 + 64;
    let dst_lo : range(0, 112) = i * 16 + 64;
    r[(dst_lo + 15)..dst_lo] = src[(src_lo + 15)..src_lo];
  };
  r
}

val avx_pshufhw : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits(8)) -> bits('vl)
function avx_pshufhw(vl, src, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) { let lo = i * 128;
    r[(lo + 127)..lo] = avx_pshufhw_lane(src[(lo + 127)..lo], imm) };
  r
}

val avx_pshuflw_lane : (xmmword, byte) -> xmmword
function avx_pshuflw_lane(src, imm) = {
  var r : xmmword = zeros();
  r[127..64] = src[127..64];
  foreach (i from 0 to 3) {
    let sel_bits : range(0, 6) = i * 2;
    let sel : range(0, 3) = unsigned(imm[(sel_bits + 1)..sel_bits]);
    let src_lo : range(0, 48) = sel * 16;
    let dst_lo : range(0, 48) = i * 16;
    r[(dst_lo + 15)..dst_lo] = src[(src_lo + 15)..src_lo];
  };
  r
}

val avx_pshuflw : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits(8)) -> bits('vl)
function avx_pshuflw(vl, src, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) { let lo = i * 128;
    r[(lo + 127)..lo] = avx_pshuflw_lane(src[(lo + 127)..lo], imm) };
  r
}

// Packed shift helpers for 128-bit lanes
val vex_psrlw_128 : (xmmword, nat) -> xmmword
function vex_psrlw_128(a, c) =
  (a[127..112] >> c) @ (a[111..96] >> c) @
  (a[95..80] >> c)   @ (a[79..64] >> c)  @
  (a[63..48] >> c)   @ (a[47..32] >> c)  @
  (a[31..16] >> c)   @ (a[15..0] >> c)

val vex_psrld_128 : (xmmword, nat) -> xmmword
function vex_psrld_128(a, c) =
  (a[127..96] >> c) @ (a[95..64] >> c) @
  (a[63..32] >> c)  @ (a[31..0] >> c)

val vex_psrlq_128 : (xmmword, nat) -> xmmword
function vex_psrlq_128(a, c) =
  (a[127..64] >> c) @ (a[63..0] >> c)

val vex_psraw_128 : (xmmword, nat) -> xmmword
function vex_psraw_128(a, c) =
  (a[127..112] >>> c) @ (a[111..96] >>> c) @
  (a[95..80] >>> c)   @ (a[79..64] >>> c)  @
  (a[63..48] >>> c)   @ (a[47..32] >>> c)  @
  (a[31..16] >>> c)   @ (a[15..0] >>> c)

val vex_psrad_128 : (xmmword, nat) -> xmmword
function vex_psrad_128(a, c) =
  (a[127..96] >>> c) @ (a[95..64] >>> c) @
  (a[63..32] >>> c)  @ (a[31..0] >>> c)

val vex_psllw_128 : (xmmword, nat) -> xmmword
function vex_psllw_128(a, c) =
  (a[127..112] << c) @ (a[111..96] << c) @
  (a[95..80] << c)   @ (a[79..64] << c)  @
  (a[63..48] << c)   @ (a[47..32] << c)  @
  (a[31..16] << c)   @ (a[15..0] << c)

val vex_pslld_128 : (xmmword, nat) -> xmmword
function vex_pslld_128(a, c) =
  (a[127..96] << c) @ (a[95..64] << c) @
  (a[63..32] << c)  @ (a[31..0] << c)

val vex_psllq_128 : (xmmword, nat) -> xmmword
function vex_psllq_128(a, c) =
  (a[127..64] << c) @ (a[63..0] << c)


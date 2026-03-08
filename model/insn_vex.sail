// x86-64 Decoder — VEX Prefix Decoding and Dispatch
//
// Handles 2-byte VEX (C5h) and 3-byte VEX (C4h) prefixes.
// In 64-bit mode, C4/C5 are always VEX prefixes (LES/LDS are invalid).
//
// VEX replaces REX + mandatory prefix + opcode escape bytes.
// 2-byte VEX (C5): [C5] [R̄.vvvv.L.pp]       — implies map 0F
// 3-byte VEX (C4): [C4] [R̄.X̄.B̄.mmmmm] [W.vvvv.L.pp]

// =========================================================================
// 128-bit packed FP helpers — lane operations for AVX
// =========================================================================

val vaddps_xmm : (xmmword, xmmword) -> xmmword
function vaddps_xmm(a, b) =
  __f32_add(a[127..96], b[127..96]) @
  __f32_add(a[95..64],  b[95..64])  @
  __f32_add(a[63..32],  b[63..32])  @
  __f32_add(a[31..0],   b[31..0])

val vsubps_xmm : (xmmword, xmmword) -> xmmword
function vsubps_xmm(a, b) =
  __f32_sub(a[127..96], b[127..96]) @
  __f32_sub(a[95..64],  b[95..64])  @
  __f32_sub(a[63..32],  b[63..32])  @
  __f32_sub(a[31..0],   b[31..0])

val vmulps_xmm : (xmmword, xmmword) -> xmmword
function vmulps_xmm(a, b) =
  __f32_mul(a[127..96], b[127..96]) @
  __f32_mul(a[95..64],  b[95..64])  @
  __f32_mul(a[63..32],  b[63..32])  @
  __f32_mul(a[31..0],   b[31..0])

val vdivps_xmm : (xmmword, xmmword) -> xmmword
function vdivps_xmm(a, b) =
  __f32_div(a[127..96], b[127..96]) @
  __f32_div(a[95..64],  b[95..64])  @
  __f32_div(a[63..32],  b[63..32])  @
  __f32_div(a[31..0],   b[31..0])

val vminps_xmm : (xmmword, xmmword) -> xmmword
function vminps_xmm(a, b) =
  __f32_min(a[127..96], b[127..96]) @
  __f32_min(a[95..64],  b[95..64])  @
  __f32_min(a[63..32],  b[63..32])  @
  __f32_min(a[31..0],   b[31..0])

val vmaxps_xmm : (xmmword, xmmword) -> xmmword
function vmaxps_xmm(a, b) =
  __f32_max(a[127..96], b[127..96]) @
  __f32_max(a[95..64],  b[95..64])  @
  __f32_max(a[63..32],  b[63..32])  @
  __f32_max(a[31..0],   b[31..0])

val vsqrtps_xmm : xmmword -> xmmword
function vsqrtps_xmm(a) =
  __f32_sqrt(a[127..96]) @ __f32_sqrt(a[95..64]) @
  __f32_sqrt(a[63..32])  @ __f32_sqrt(a[31..0])

val vaddpd_xmm : (xmmword, xmmword) -> xmmword
function vaddpd_xmm(a, b) =
  __f64_add(a[127..64], b[127..64]) @ __f64_add(a[63..0], b[63..0])

val vsubpd_xmm : (xmmword, xmmword) -> xmmword
function vsubpd_xmm(a, b) =
  __f64_sub(a[127..64], b[127..64]) @ __f64_sub(a[63..0], b[63..0])

val vmulpd_xmm : (xmmword, xmmword) -> xmmword
function vmulpd_xmm(a, b) =
  __f64_mul(a[127..64], b[127..64]) @ __f64_mul(a[63..0], b[63..0])

val vdivpd_xmm : (xmmword, xmmword) -> xmmword
function vdivpd_xmm(a, b) =
  __f64_div(a[127..64], b[127..64]) @ __f64_div(a[63..0], b[63..0])

val vminpd_xmm : (xmmword, xmmword) -> xmmword
function vminpd_xmm(a, b) =
  __f64_min(a[127..64], b[127..64]) @ __f64_min(a[63..0], b[63..0])

val vmaxpd_xmm : (xmmword, xmmword) -> xmmword
function vmaxpd_xmm(a, b) =
  __f64_max(a[127..64], b[127..64]) @ __f64_max(a[63..0], b[63..0])

val vsqrtpd_xmm : xmmword -> xmmword
function vsqrtpd_xmm(a) =
  __f64_sqrt(a[127..64]) @ __f64_sqrt(a[63..0])

// =========================================================================
// 128-bit packed integer add/sub helpers
// =========================================================================

val avx_paddb_128 : (xmmword, xmmword) -> xmmword
function avx_paddb_128(a, b) =
  (a[127..120] + b[127..120]) @ (a[119..112] + b[119..112]) @
  (a[111..104] + b[111..104]) @ (a[103..96]  + b[103..96])  @
  (a[95..88]   + b[95..88])   @ (a[87..80]   + b[87..80])   @
  (a[79..72]   + b[79..72])   @ (a[71..64]   + b[71..64])   @
  (a[63..56]   + b[63..56])   @ (a[55..48]   + b[55..48])   @
  (a[47..40]   + b[47..40])   @ (a[39..32]   + b[39..32])   @
  (a[31..24]   + b[31..24])   @ (a[23..16]   + b[23..16])   @
  (a[15..8]    + b[15..8])    @ (a[7..0]     + b[7..0])

val avx_paddw_128 : (xmmword, xmmword) -> xmmword
function avx_paddw_128(a, b) =
  (a[127..112] + b[127..112]) @ (a[111..96] + b[111..96]) @
  (a[95..80]   + b[95..80])   @ (a[79..64]  + b[79..64])  @
  (a[63..48]   + b[63..48])   @ (a[47..32]  + b[47..32])  @
  (a[31..16]   + b[31..16])   @ (a[15..0]   + b[15..0])

val avx_paddd_128 : (xmmword, xmmword) -> xmmword
function avx_paddd_128(a, b) =
  (a[127..96] + b[127..96]) @ (a[95..64] + b[95..64]) @
  (a[63..32]  + b[63..32])  @ (a[31..0]  + b[31..0])

val avx_paddq_128 : (xmmword, xmmword) -> xmmword
function avx_paddq_128(a, b) =
  (a[127..64] + b[127..64]) @ (a[63..0] + b[63..0])

val avx_psubb_128 : (xmmword, xmmword) -> xmmword
function avx_psubb_128(a, b) =
  (a[127..120] - b[127..120]) @ (a[119..112] - b[119..112]) @
  (a[111..104] - b[111..104]) @ (a[103..96]  - b[103..96])  @
  (a[95..88]   - b[95..88])   @ (a[87..80]   - b[87..80])   @
  (a[79..72]   - b[79..72])   @ (a[71..64]   - b[71..64])   @
  (a[63..56]   - b[63..56])   @ (a[55..48]   - b[55..48])   @
  (a[47..40]   - b[47..40])   @ (a[39..32]   - b[39..32])   @
  (a[31..24]   - b[31..24])   @ (a[23..16]   - b[23..16])   @
  (a[15..8]    - b[15..8])    @ (a[7..0]     - b[7..0])

val avx_psubw_128 : (xmmword, xmmword) -> xmmword
function avx_psubw_128(a, b) =
  (a[127..112] - b[127..112]) @ (a[111..96] - b[111..96]) @
  (a[95..80]   - b[95..80])   @ (a[79..64]  - b[79..64])  @
  (a[63..48]   - b[63..48])   @ (a[47..32]  - b[47..32])  @
  (a[31..16]   - b[31..16])   @ (a[15..0]   - b[15..0])

val avx_psubd_128 : (xmmword, xmmword) -> xmmword
function avx_psubd_128(a, b) =
  (a[127..96] - b[127..96]) @ (a[95..64] - b[95..64]) @
  (a[63..32]  - b[63..32])  @ (a[31..0]  - b[31..0])

val avx_psubq_128 : (xmmword, xmmword) -> xmmword
function avx_psubq_128(a, b) =
  (a[127..64] - b[127..64]) @ (a[63..0] - b[63..0])

// Decode a 2-byte VEX prefix (C5 already consumed, byte1 is the payload).
// Returns (Prefixes, opcode_map) where opcode_map is always 1 (0F).
val decode_vex2 : byte -> (Prefixes, range(0, 31))
function decode_vex2(byte1) = {
  let pfx = {default_prefixes() with
    vex_present = true,
    // R̄ is bit 7 (inverted)
    rex_r = not_bool(byte1[7] == bitone),
    // vvvv is bits 6:3 (inverted)
    vex_vvvv = 15 - unsigned(byte1[6..3]),
    // L is bit 2
    vex_l = byte1[2] == bitone,
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
    rex_r = not_bool(byte1[7] == bitone),
    rex_x = not_bool(byte1[6] == bitone),
    rex_b = not_bool(byte1[5] == bitone),
    // W is bit 7 of byte2
    vex_w = byte2[7] == bitone,
    rex_w = byte2[7] == bitone,
    // vvvv is bits 6:3 of byte2 (inverted)
    vex_vvvv = 15 - unsigned(byte2[6..3]),
    // L is bit 2 of byte2
    vex_l = byte2[2] == bitone,
    // pp is bits 1:0 of byte2
    has_opsize = byte2[1..0] == 0b01,
    has_rep    = byte2[1..0] == 0b10,
    has_repne  = byte2[1..0] == 0b11,
    has_rex = true,
  };
  (pfx, mmmmm)
}

// Helper: decode VEX XMM/YMM source from ModR/M r/m field.
// Returns (xmm_value, ymm_value, is_memory, effective_addr).
// For register operands, reads the register. For memory, loads from memory.
val decode_vex_src_xmm : (byte, RM, Prefixes) -> xmmword
function decode_vex_src_xmm(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
  RM_mem(addr) => mem_read128(fixup_addr(addr)),
}

val decode_vex_src_ymm : (byte, RM, Prefixes) -> ymmword
function decode_vex_src_ymm(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_ymm(modrm_xmm_rm(modrm, pfx)),
  RM_mem(addr) => mem_read256(fixup_addr(addr)),
}

// =========================================================================
// FP16 <-> FP32 conversion helpers (used by VEX VCVTPH2PS/VCVTPS2PH and EVEX)
// =========================================================================

val fp16_to_fp32 : bits(16) -> bits(32)
function fp16_to_fp32(h) = {
  let sign : bits(1) = h[15..15];
  let exp5 : bits(5) = h[14..10];
  let frac10 : bits(10) = h[9..0];
  if exp5 == 0b11111 then {
    sign @ 0xFF @ frac10 @ 0b0000000000000
  } else if exp5 == 0b00000 then {
    if frac10 == zeros() then {
      sign @ 0x00000000[30..0]
    } else {
      var shift : int = 0;
      let f : bits(10) = frac10;
      var done : bool = false;
      foreach (i from 9 downto 0) {
        if not_bool(done) & f[i] == bitzero then shift = shift + 1
        else done = true
      };
      let new_exp : int = 112 - shift;
      let shifted : bits(10) = sail_shiftleft(frac10, shift + 1);
      sign @ get_slice_int(8, new_exp, 0) @ shifted @ 0b0000000000000
    }
  } else {
    let new_exp : bits(8) = sail_zero_extend(exp5, 8) + 0x70;
    sign @ new_exp @ frac10 @ 0b0000000000000
  }
}

val fp32_to_fp16 : bits(32) -> bits(16)
function fp32_to_fp16(f) = {
  let sign : bits(1) = f[31..31];
  let exp8 : bits(8) = f[30..23];
  let frac23 : bits(23) = f[22..0];
  let exp_val : int = unsigned(exp8);
  if exp8 == 0xFF then {
    if frac23 == zeros() then sign @ 0b11111 @ 0b0000000000
    else sign @ 0b11111 @ frac23[22..13]
  } else if exp_val > 142 then {
    sign @ 0b11111 @ 0b0000000000
  } else if exp_val < 103 then {
    sign @ 0b00000 @ 0b0000000000
  } else if exp_val < 113 then {
    let shift_amt : int = 113 - exp_val;
    let full_frac : bits(24) = 0b1 @ frac23;
    let shifted : bits(24) = sail_shiftright(full_frac, shift_amt);
    sign @ 0b00000 @ shifted[9..0]
  } else {
    let new_exp : int = exp_val - 112;
    sign @ get_slice_int(5, new_exp, 0) @ frac23[22..13]
  }
}

val avx_vcvtph2ps_128 : bits(64) -> xmmword
function avx_vcvtph2ps_128(src) = {
  fp16_to_fp32(src[63..48]) @ fp16_to_fp32(src[47..32]) @
  fp16_to_fp32(src[31..16]) @ fp16_to_fp32(src[15..0])
}

val avx_vcvtps2ph_128 : xmmword -> bits(64)
function avx_vcvtps2ph_128(src) = {
  fp32_to_fp16(src[127..96]) @ fp32_to_fp16(src[95..64]) @
  fp32_to_fp16(src[63..32]) @ fp32_to_fp16(src[31..0])
}

val avx_vcvtph2ps_256 : xmmword -> ymmword
function avx_vcvtph2ps_256(src) = {
  avx_vcvtph2ps_128(src[127..64]) @ avx_vcvtph2ps_128(src[63..0])
}

val avx_vcvtps2ph_256 : ymmword -> xmmword
function avx_vcvtps2ph_256(src) = {
  avx_vcvtps2ph_128(src[255..128]) @ avx_vcvtps2ph_128(src[127..0])
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
    if c[7] == bitone then
      result[(i*8+7)..(i*8)] = 0x00
    else {
      let idx : range(0, 15) = unsigned(c[3..0]);
      result[(i*8+7)..(i*8)] = src[(idx*8+7)..(idx*8)]
    }
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

// VPMULHRSW: packed multiply high with round and scale
val vex_pmulhrsw_128 : (xmmword, xmmword) -> xmmword
function vex_pmulhrsw_128(a, b) =
  mulhrsw(a[127..112], b[127..112]) @ mulhrsw(a[111..96], b[111..96]) @
  mulhrsw(a[95..80], b[95..80]) @ mulhrsw(a[79..64], b[79..64]) @
  mulhrsw(a[63..48], b[63..48]) @ mulhrsw(a[47..32], b[47..32]) @
  mulhrsw(a[31..16], b[31..16]) @ mulhrsw(a[15..0], b[15..0])

val vex_pmulhrsw_256 : (ymmword, ymmword) -> ymmword
function vex_pmulhrsw_256(a, b) =
  vex_pmulhrsw_128(a[255..128], b[255..128]) @ vex_pmulhrsw_128(a[127..0], b[127..0])

// VPABSB: absolute value of packed signed bytes
val vex_pabsb_128 : xmmword -> xmmword
function vex_pabsb_128(a) =
  abs8(a[127..120]) @ abs8(a[119..112]) @
  abs8(a[111..104]) @ abs8(a[103..96])  @
  abs8(a[95..88])   @ abs8(a[87..80])   @
  abs8(a[79..72])   @ abs8(a[71..64])   @
  abs8(a[63..56])   @ abs8(a[55..48])   @
  abs8(a[47..40])   @ abs8(a[39..32])   @
  abs8(a[31..24])   @ abs8(a[23..16])   @
  abs8(a[15..8])    @ abs8(a[7..0])

val vex_pabsb_256 : ymmword -> ymmword
function vex_pabsb_256(a) =
  vex_pabsb_128(a[255..128]) @ vex_pabsb_128(a[127..0])

// VPABSW: absolute value of packed signed words
val vex_pabsw_128 : xmmword -> xmmword
function vex_pabsw_128(a) =
  abs16(a[127..112]) @ abs16(a[111..96]) @
  abs16(a[95..80])   @ abs16(a[79..64])  @
  abs16(a[63..48])   @ abs16(a[47..32])  @
  abs16(a[31..16])   @ abs16(a[15..0])

val vex_pabsw_256 : ymmword -> ymmword
function vex_pabsw_256(a) =
  vex_pabsw_128(a[255..128]) @ vex_pabsw_128(a[127..0])

// VPABSD: absolute value of packed signed dwords
val vex_pabsd_128 : xmmword -> xmmword
function vex_pabsd_128(a) =
  abs32(a[127..96]) @ abs32(a[95..64]) @
  abs32(a[63..32])  @ abs32(a[31..0])

val vex_pabsd_256 : ymmword -> ymmword
function vex_pabsd_256(a) =
  vex_pabsd_128(a[255..128]) @ vex_pabsd_128(a[127..0])

// VPHADDW: horizontal add packed words (one 128-bit lane)
// result = [src2 adjacent-pair sums (high half)] @ [src1 adjacent-pair sums (low half)]
val avx_phaddw_128 : (xmmword, xmmword) -> xmmword
function avx_phaddw_128(a, b) =
  (b[127..112] + b[111..96]) @ (b[95..80] + b[79..64]) @
  (b[63..48] + b[47..32]) @ (b[31..16] + b[15..0]) @
  (a[127..112] + a[111..96]) @ (a[95..80] + a[79..64]) @
  (a[63..48] + a[47..32]) @ (a[31..16] + a[15..0])

val avx_phaddw_256 : (ymmword, ymmword) -> ymmword
function avx_phaddw_256(a, b) =
  avx_phaddw_128(a[255..128], b[255..128]) @ avx_phaddw_128(a[127..0], b[127..0])

// VPHADDD: horizontal add packed dwords (one 128-bit lane)
val avx_phaddd_128 : (xmmword, xmmword) -> xmmword
function avx_phaddd_128(a, b) =
  (b[127..96] + b[95..64]) @ (b[63..32] + b[31..0]) @
  (a[127..96] + a[95..64]) @ (a[63..32] + a[31..0])

val avx_phaddd_256 : (ymmword, ymmword) -> ymmword
function avx_phaddd_256(a, b) =
  avx_phaddd_128(a[255..128], b[255..128]) @ avx_phaddd_128(a[127..0], b[127..0])

// VPHADDSW: horizontal add packed signed words with saturation (one 128-bit lane)
val avx_phaddsw_128 : (xmmword, xmmword) -> xmmword
function avx_phaddsw_128(a, b) =
  sat_add_s16(b[127..112], b[111..96]) @ sat_add_s16(b[95..80], b[79..64]) @
  sat_add_s16(b[63..48], b[47..32]) @ sat_add_s16(b[31..16], b[15..0]) @
  sat_add_s16(a[127..112], a[111..96]) @ sat_add_s16(a[95..80], a[79..64]) @
  sat_add_s16(a[63..48], a[47..32]) @ sat_add_s16(a[31..16], a[15..0])

val avx_phaddsw_256 : (ymmword, ymmword) -> ymmword
function avx_phaddsw_256(a, b) =
  avx_phaddsw_128(a[255..128], b[255..128]) @ avx_phaddsw_128(a[127..0], b[127..0])

// VPHSUBW: horizontal subtract packed words (one 128-bit lane)
// Each pair: low - high (e.g. a[15:0] - a[31:16])
val avx_phsubw_128 : (xmmword, xmmword) -> xmmword
function avx_phsubw_128(a, b) =
  (b[111..96] - b[127..112]) @ (b[79..64] - b[95..80]) @
  (b[47..32] - b[63..48]) @ (b[15..0] - b[31..16]) @
  (a[111..96] - a[127..112]) @ (a[79..64] - a[95..80]) @
  (a[47..32] - a[63..48]) @ (a[15..0] - a[31..16])

val avx_phsubw_256 : (ymmword, ymmword) -> ymmword
function avx_phsubw_256(a, b) =
  avx_phsubw_128(a[255..128], b[255..128]) @ avx_phsubw_128(a[127..0], b[127..0])

// VPHSUBD: horizontal subtract packed dwords (one 128-bit lane)
val avx_phsubd_128 : (xmmword, xmmword) -> xmmword
function avx_phsubd_128(a, b) =
  (b[95..64] - b[127..96]) @ (b[31..0] - b[63..32]) @
  (a[95..64] - a[127..96]) @ (a[31..0] - a[63..32])

val avx_phsubd_256 : (ymmword, ymmword) -> ymmword
function avx_phsubd_256(a, b) =
  avx_phsubd_128(a[255..128], b[255..128]) @ avx_phsubd_128(a[127..0], b[127..0])

// VPHSUBSW: horizontal subtract packed signed words with saturation (one 128-bit lane)
val avx_phsubsw_128 : (xmmword, xmmword) -> xmmword
function avx_phsubsw_128(a, b) =
  sat_sub_s16(b[111..96], b[127..112]) @ sat_sub_s16(b[79..64], b[95..80]) @
  sat_sub_s16(b[47..32], b[63..48]) @ sat_sub_s16(b[15..0], b[31..16]) @
  sat_sub_s16(a[111..96], a[127..112]) @ sat_sub_s16(a[79..64], a[95..80]) @
  sat_sub_s16(a[47..32], a[63..48]) @ sat_sub_s16(a[15..0], a[31..16])

val avx_phsubsw_256 : (ymmword, ymmword) -> ymmword
function avx_phsubsw_256(a, b) =
  avx_phsubsw_128(a[255..128], b[255..128]) @ avx_phsubsw_128(a[127..0], b[127..0])

// VPSIGNB: negate/zero/keep bytes (one 128-bit lane)
val avx_psignb_128 : (xmmword, xmmword) -> xmmword
function avx_psignb_128(a, b) =
  psign8(a[127..120], b[127..120]) @ psign8(a[119..112], b[119..112]) @
  psign8(a[111..104], b[111..104]) @ psign8(a[103..96], b[103..96]) @
  psign8(a[95..88], b[95..88]) @ psign8(a[87..80], b[87..80]) @
  psign8(a[79..72], b[79..72]) @ psign8(a[71..64], b[71..64]) @
  psign8(a[63..56], b[63..56]) @ psign8(a[55..48], b[55..48]) @
  psign8(a[47..40], b[47..40]) @ psign8(a[39..32], b[39..32]) @
  psign8(a[31..24], b[31..24]) @ psign8(a[23..16], b[23..16]) @
  psign8(a[15..8], b[15..8]) @ psign8(a[7..0], b[7..0])

val avx_psignb_256 : (ymmword, ymmword) -> ymmword
function avx_psignb_256(a, b) =
  avx_psignb_128(a[255..128], b[255..128]) @ avx_psignb_128(a[127..0], b[127..0])

// VPSIGNW: negate/zero/keep words (one 128-bit lane)
val avx_psignw_128 : (xmmword, xmmword) -> xmmword
function avx_psignw_128(a, b) =
  psign16(a[127..112], b[127..112]) @ psign16(a[111..96], b[111..96]) @
  psign16(a[95..80], b[95..80]) @ psign16(a[79..64], b[79..64]) @
  psign16(a[63..48], b[63..48]) @ psign16(a[47..32], b[47..32]) @
  psign16(a[31..16], b[31..16]) @ psign16(a[15..0], b[15..0])

val avx_psignw_256 : (ymmword, ymmword) -> ymmword
function avx_psignw_256(a, b) =
  avx_psignw_128(a[255..128], b[255..128]) @ avx_psignw_128(a[127..0], b[127..0])

// VPSIGND: negate/zero/keep dwords (one 128-bit lane)
val avx_psignd_128 : (xmmword, xmmword) -> xmmword
function avx_psignd_128(a, b) =
  psign32(a[127..96], b[127..96]) @ psign32(a[95..64], b[95..64]) @
  psign32(a[63..32], b[63..32]) @ psign32(a[31..0], b[31..0])

val avx_psignd_256 : (ymmword, ymmword) -> ymmword
function avx_psignd_256(a, b) =
  avx_psignd_128(a[255..128], b[255..128]) @ avx_psignd_128(a[127..0], b[127..0])

// =========================================================================
// SSE4.1 integer helpers — PMINUW, PCMPEQQ, PHMINPOSUW
// =========================================================================

val avx_pminuw_128 : (xmmword, xmmword) -> xmmword
function avx_pminuw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo = i * 16;
    let hi = lo + 15;
    let av : word = a[(hi)..(lo)];
    let bv : word = b[(hi)..(lo)];
    r[(hi)..(lo)] = if unsigned(av) < unsigned(bv) then av else bv
  };
  r
}

val avx_pminuw_256 : (ymmword, ymmword) -> ymmword
function avx_pminuw_256(a, b) =
  avx_pminuw_128(a[255..128], b[255..128]) @
  avx_pminuw_128(a[127..0], b[127..0])

val avx_maxuw_128 : (xmmword, xmmword) -> xmmword
function avx_maxuw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo = i * 16;
    let hi = lo + 15;
    let av : word = a[(hi)..(lo)];
    let bv : word = b[(hi)..(lo)];
    r[(hi)..(lo)] = if unsigned(av) > unsigned(bv) then av else bv
  };
  r
}

val avx_maxuw_256 : (ymmword, ymmword) -> ymmword
function avx_maxuw_256(a, b) =
  avx_maxuw_128(a[255..128], b[255..128]) @
  avx_maxuw_128(a[127..0], b[127..0])

val avx_pcmpeqq_128 : (xmmword, xmmword) -> xmmword
function avx_pcmpeqq_128(a, b) = {
  let r1 : qword = if a[127..64] == b[127..64] then ones() else zeros();
  let r0 : qword = if a[63..0] == b[63..0] then ones() else zeros();
  r1 @ r0
}

val avx_pcmpeqq_256 : (ymmword, ymmword) -> ymmword
function avx_pcmpeqq_256(a, b) =
  avx_pcmpeqq_128(a[255..128], b[255..128]) @
  avx_pcmpeqq_128(a[127..0], b[127..0])

// PHMINPOSUW: find minimum unsigned word among 8 words.
// Result: bits[15:0] = min value, bits[18:16] = index of min, rest zeroed.
val avx_phminposuw_128 : xmmword -> xmmword
function avx_phminposuw_128(src) = {
  var min_val : word = src[15..0];
  var min_idx : int = 0;
  foreach (i from 1 to 7) {
    let lo = i * 16;
    let hi = lo + 15;
    let v : word = src[(hi)..(lo)];
    if unsigned(v) < unsigned(min_val) then {
      min_val = v;
      min_idx = i
    }
  };
  let idx : bits(3) = get_slice_int(3, min_idx, 0);
  zeros(109) @ idx @ min_val
}

// =========================================================================
// VEX 0F integer helpers — pavg, pmulh, pmaddwd
// =========================================================================

// VPAVGB 128: unsigned byte average = (a + b + 1) >> 1
val vex_pavgb_128 : (xmmword, xmmword) -> xmmword
function vex_pavgb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    let avg : int = (unsigned(a[(lo + 7)..lo]) + unsigned(b[(lo + 7)..lo]) + 1) / 2;
    r[(lo + 7)..lo] = get_slice_int(8, avg, 0);
  };
  r
}

val vex_pavgb_256 : (ymmword, ymmword) -> ymmword
function vex_pavgb_256(a, b) =
  vex_pavgb_128(a[255..128], b[255..128]) @ vex_pavgb_128(a[127..0], b[127..0])

// VPAVGW 128: unsigned word average
val vex_pavgw_128 : (xmmword, xmmword) -> xmmword
function vex_pavgw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let avg : int = (unsigned(a[(lo + 15)..lo]) + unsigned(b[(lo + 15)..lo]) + 1) / 2;
    r[(lo + 15)..lo] = get_slice_int(16, avg, 0);
  };
  r
}

val vex_pavgw_256 : (ymmword, ymmword) -> ymmword
function vex_pavgw_256(a, b) =
  vex_pavgw_128(a[255..128], b[255..128]) @ vex_pavgw_128(a[127..0], b[127..0])

// VPMULHUW 128: multiply packed unsigned words, store high 16 bits
val vex_pmulhuw_128 : (xmmword, xmmword) -> xmmword
function vex_pmulhuw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let prod : int = unsigned(a[(lo + 15)..lo]) * unsigned(b[(lo + 15)..lo]);
    r[(lo + 15)..lo] = get_slice_int(16, prod, 16);
  };
  r
}

val vex_pmulhuw_256 : (ymmword, ymmword) -> ymmword
function vex_pmulhuw_256(a, b) =
  vex_pmulhuw_128(a[255..128], b[255..128]) @ vex_pmulhuw_128(a[127..0], b[127..0])

// VPMULHW 128: multiply packed signed words, store high 16 bits
val vex_pmulhw_128 : (xmmword, xmmword) -> xmmword
function vex_pmulhw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let prod : int = signed(a[(lo + 15)..lo]) * signed(b[(lo + 15)..lo]);
    r[(lo + 15)..lo] = get_slice_int(16, prod, 16);
  };
  r
}

val vex_pmulhw_256 : (ymmword, ymmword) -> ymmword
function vex_pmulhw_256(a, b) =
  vex_pmulhw_128(a[255..128], b[255..128]) @ vex_pmulhw_128(a[127..0], b[127..0])

// VPMADDWD 128: multiply signed words, add adjacent pairs to dwords
val vex_pmaddwd_128 : (xmmword, xmmword) -> xmmword
function vex_pmaddwd_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let wlo : range(0, 96) = i * 32;
    let w0 = signed(a[(wlo + 15)..wlo]) * signed(b[(wlo + 15)..wlo]);
    let w1 = signed(a[(wlo + 31)..(wlo + 16)]) * signed(b[(wlo + 31)..(wlo + 16)]);
    r[(wlo + 31)..wlo] = get_slice_int(32, w0 + w1, 0);
  };
  r
}

val vex_pmaddwd_256 : (ymmword, ymmword) -> ymmword
function vex_pmaddwd_256(a, b) =
  vex_pmaddwd_128(a[255..128], b[255..128]) @ vex_pmaddwd_128(a[127..0], b[127..0])

// =========================================================================
// VEX 0F integer helpers — compare, pack, unpack, multiply, shift, sat
// =========================================================================

// VPCMPGTB/W/D: compare packed signed for greater-than
val vex_pcmpgtb_128 : (xmmword, xmmword) -> xmmword
function vex_pcmpgtb_128(a, b) =
  cmp_gt8(a[127..120], b[127..120]) @ cmp_gt8(a[119..112], b[119..112]) @
  cmp_gt8(a[111..104], b[111..104]) @ cmp_gt8(a[103..96],  b[103..96])  @
  cmp_gt8(a[95..88],   b[95..88])   @ cmp_gt8(a[87..80],   b[87..80])   @
  cmp_gt8(a[79..72],   b[79..72])   @ cmp_gt8(a[71..64],   b[71..64])   @
  cmp_gt8(a[63..56],   b[63..56])   @ cmp_gt8(a[55..48],   b[55..48])   @
  cmp_gt8(a[47..40],   b[47..40])   @ cmp_gt8(a[39..32],   b[39..32])   @
  cmp_gt8(a[31..24],   b[31..24])   @ cmp_gt8(a[23..16],   b[23..16])   @
  cmp_gt8(a[15..8],    b[15..8])    @ cmp_gt8(a[7..0],     b[7..0])

val vex_pcmpgtw_128 : (xmmword, xmmword) -> xmmword
function vex_pcmpgtw_128(a, b) =
  cmp_gt16(a[127..112], b[127..112]) @ cmp_gt16(a[111..96], b[111..96]) @
  cmp_gt16(a[95..80],   b[95..80])   @ cmp_gt16(a[79..64],  b[79..64])  @
  cmp_gt16(a[63..48],   b[63..48])   @ cmp_gt16(a[47..32],  b[47..32])  @
  cmp_gt16(a[31..16],   b[31..16])   @ cmp_gt16(a[15..0],   b[15..0])

val vex_pcmpgtd_128 : (xmmword, xmmword) -> xmmword
function vex_pcmpgtd_128(a, b) = {
  let r3 : dword = if signed(a[127..96]) > signed(b[127..96]) then ones() else zeros();
  let r2 : dword = if signed(a[95..64])  > signed(b[95..64])  then ones() else zeros();
  let r1 : dword = if signed(a[63..32])  > signed(b[63..32])  then ones() else zeros();
  let r0 : dword = if signed(a[31..0])   > signed(b[31..0])   then ones() else zeros();
  r3 @ r2 @ r1 @ r0
}

// VPCMPEQB/W: compare packed for equality
val vex_pcmpeqb_128 : (xmmword, xmmword) -> xmmword
function vex_pcmpeqb_128(a, b) =
  cmp_eq8(a[127..120], b[127..120]) @ cmp_eq8(a[119..112], b[119..112]) @
  cmp_eq8(a[111..104], b[111..104]) @ cmp_eq8(a[103..96],  b[103..96])  @
  cmp_eq8(a[95..88],   b[95..88])   @ cmp_eq8(a[87..80],   b[87..80])   @
  cmp_eq8(a[79..72],   b[79..72])   @ cmp_eq8(a[71..64],   b[71..64])   @
  cmp_eq8(a[63..56],   b[63..56])   @ cmp_eq8(a[55..48],   b[55..48])   @
  cmp_eq8(a[47..40],   b[47..40])   @ cmp_eq8(a[39..32],   b[39..32])   @
  cmp_eq8(a[31..24],   b[31..24])   @ cmp_eq8(a[23..16],   b[23..16])   @
  cmp_eq8(a[15..8],    b[15..8])    @ cmp_eq8(a[7..0],     b[7..0])

val vex_pcmpeqw_128 : (xmmword, xmmword) -> xmmword
function vex_pcmpeqw_128(a, b) =
  cmp_eq16(a[127..112], b[127..112]) @ cmp_eq16(a[111..96], b[111..96]) @
  cmp_eq16(a[95..80],   b[95..80])   @ cmp_eq16(a[79..64],  b[79..64])  @
  cmp_eq16(a[63..48],   b[63..48])   @ cmp_eq16(a[47..32],  b[47..32])  @
  cmp_eq16(a[31..16],   b[31..16])   @ cmp_eq16(a[15..0],   b[15..0])

// VPACKSSWB/VPACKUSWB/VPACKSSDW: pack with saturation
val vex_packsswb_128 : (xmmword, xmmword) -> xmmword
function vex_packsswb_128(a, b) =
  sat_s16_to_s8(b[127..112]) @ sat_s16_to_s8(b[111..96]) @
  sat_s16_to_s8(b[95..80])   @ sat_s16_to_s8(b[79..64])  @
  sat_s16_to_s8(b[63..48])   @ sat_s16_to_s8(b[47..32])  @
  sat_s16_to_s8(b[31..16])   @ sat_s16_to_s8(b[15..0])   @
  sat_s16_to_s8(a[127..112]) @ sat_s16_to_s8(a[111..96]) @
  sat_s16_to_s8(a[95..80])   @ sat_s16_to_s8(a[79..64])  @
  sat_s16_to_s8(a[63..48])   @ sat_s16_to_s8(a[47..32])  @
  sat_s16_to_s8(a[31..16])   @ sat_s16_to_s8(a[15..0])

val vex_packuswb_128 : (xmmword, xmmword) -> xmmword
function vex_packuswb_128(a, b) =
  sat_s16_to_u8(b[127..112]) @ sat_s16_to_u8(b[111..96]) @
  sat_s16_to_u8(b[95..80])   @ sat_s16_to_u8(b[79..64])  @
  sat_s16_to_u8(b[63..48])   @ sat_s16_to_u8(b[47..32])  @
  sat_s16_to_u8(b[31..16])   @ sat_s16_to_u8(b[15..0])   @
  sat_s16_to_u8(a[127..112]) @ sat_s16_to_u8(a[111..96]) @
  sat_s16_to_u8(a[95..80])   @ sat_s16_to_u8(a[79..64])  @
  sat_s16_to_u8(a[63..48])   @ sat_s16_to_u8(a[47..32])  @
  sat_s16_to_u8(a[31..16])   @ sat_s16_to_u8(a[15..0])

val vex_packssdw_128 : (xmmword, xmmword) -> xmmword
function vex_packssdw_128(a, b) =
  sat_s32_to_s16(b[127..96]) @ sat_s32_to_s16(b[95..64]) @
  sat_s32_to_s16(b[63..32])  @ sat_s32_to_s16(b[31..0])  @
  sat_s32_to_s16(a[127..96]) @ sat_s32_to_s16(a[95..64]) @
  sat_s32_to_s16(a[63..32])  @ sat_s32_to_s16(a[31..0])

// VPUNPCK*: interleave operations (one 128-bit lane)
val vex_punpcklbw_128 : (xmmword, xmmword) -> xmmword
function vex_punpcklbw_128(a, b) =
  b[63..56] @ a[63..56] @ b[55..48] @ a[55..48] @
  b[47..40] @ a[47..40] @ b[39..32] @ a[39..32] @
  b[31..24] @ a[31..24] @ b[23..16] @ a[23..16] @
  b[15..8]  @ a[15..8]  @ b[7..0]   @ a[7..0]

val vex_punpckhbw_128 : (xmmword, xmmword) -> xmmword
function vex_punpckhbw_128(a, b) =
  b[127..120] @ a[127..120] @ b[119..112] @ a[119..112] @
  b[111..104] @ a[111..104] @ b[103..96]  @ a[103..96]  @
  b[95..88]   @ a[95..88]   @ b[87..80]   @ a[87..80]   @
  b[79..72]   @ a[79..72]   @ b[71..64]   @ a[71..64]

val vex_punpcklwd_128 : (xmmword, xmmword) -> xmmword
function vex_punpcklwd_128(a, b) =
  b[63..48] @ a[63..48] @ b[47..32] @ a[47..32] @
  b[31..16] @ a[31..16] @ b[15..0]  @ a[15..0]

val vex_punpckhwd_128 : (xmmword, xmmword) -> xmmword
function vex_punpckhwd_128(a, b) =
  b[127..112] @ a[127..112] @ b[111..96] @ a[111..96] @
  b[95..80]   @ a[95..80]   @ b[79..64]  @ a[79..64]

val vex_punpckldq_128 : (xmmword, xmmword) -> xmmword
function vex_punpckldq_128(a, b) =
  b[63..32] @ a[63..32] @ b[31..0] @ a[31..0]

val vex_punpckhdq_128 : (xmmword, xmmword) -> xmmword
function vex_punpckhdq_128(a, b) =
  b[127..96] @ a[127..96] @ b[95..64] @ a[95..64]

val vex_punpcklqdq_128 : (xmmword, xmmword) -> xmmword
function vex_punpcklqdq_128(a, b) =
  b[63..0] @ a[63..0]

val vex_punpckhqdq_128 : (xmmword, xmmword) -> xmmword
function vex_punpckhqdq_128(a, b) =
  b[127..64] @ a[127..64]

// VPMULLW: multiply packed signed words, store low 16 bits
val vex_pmullw_128 : (xmmword, xmmword) -> xmmword
function vex_pmullw_128(a, b) =
  mul_lo16(a[127..112], b[127..112]) @ mul_lo16(a[111..96], b[111..96]) @
  mul_lo16(a[95..80],   b[95..80])   @ mul_lo16(a[79..64],  b[79..64])  @
  mul_lo16(a[63..48],   b[63..48])   @ mul_lo16(a[47..32],  b[47..32])  @
  mul_lo16(a[31..16],   b[31..16])   @ mul_lo16(a[15..0],   b[15..0])

val vex_pmullw_256 : (ymmword, ymmword) -> ymmword
function vex_pmullw_256(a, b) =
  vex_pmullw_128(a[255..128], b[255..128]) @ vex_pmullw_128(a[127..0], b[127..0])

// VPMULUDQ: multiply packed unsigned dwords (lanes 0,2), produce qword results
val vex_pmuludq_128 : (xmmword, xmmword) -> xmmword
function vex_pmuludq_128(a, b) = {
  let p1 : qword = to_bits(64, unsigned(a[95..64]) * unsigned(b[95..64]));
  let p0 : qword = to_bits(64, unsigned(a[31..0])  * unsigned(b[31..0]));
  p1 @ p0
}

val vex_pmuludq_256 : (ymmword, ymmword) -> ymmword
function vex_pmuludq_256(a, b) =
  vex_pmuludq_128(a[255..128], b[255..128]) @ vex_pmuludq_128(a[127..0], b[127..0])

// VPSADBW: sum of absolute differences per 8-byte group
val vex_psadbw_128 : (xmmword, xmmword) -> xmmword
function vex_psadbw_128(a, b) = {
  let sum1 : int = abs_diff8(a[127..120], b[127..120]) + abs_diff8(a[119..112], b[119..112]) +
                    abs_diff8(a[111..104], b[111..104]) + abs_diff8(a[103..96],  b[103..96])  +
                    abs_diff8(a[95..88],   b[95..88])   + abs_diff8(a[87..80],   b[87..80])   +
                    abs_diff8(a[79..72],   b[79..72])   + abs_diff8(a[71..64],   b[71..64]);
  let sum0 : int = abs_diff8(a[63..56],   b[63..56])   + abs_diff8(a[55..48],   b[55..48])   +
                    abs_diff8(a[47..40],   b[47..40])   + abs_diff8(a[39..32],   b[39..32])   +
                    abs_diff8(a[31..24],   b[31..24])   + abs_diff8(a[23..16],   b[23..16])   +
                    abs_diff8(a[15..8],    b[15..8])    + abs_diff8(a[7..0],     b[7..0]);
  get_slice_int(64, sum1, 0) @ get_slice_int(64, sum0, 0)
}

val vex_psadbw_256 : (ymmword, ymmword) -> ymmword
function vex_psadbw_256(a, b) =
  vex_psadbw_128(a[255..128], b[255..128]) @ vex_psadbw_128(a[127..0], b[127..0])

// VPMINUB/VPMAXUB: min/max of packed unsigned bytes
val vex_pminub_128 : (xmmword, xmmword) -> xmmword
function vex_pminub_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 8; let hi = lo + 7;
    let av : byte = a[(hi)..(lo)]; let bv : byte = b[(hi)..(lo)];
    r[(hi)..(lo)] = if unsigned(av) < unsigned(bv) then av else bv
  };
  r
}

val vex_pmaxub_128 : (xmmword, xmmword) -> xmmword
function vex_pmaxub_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 8; let hi = lo + 7;
    let av : byte = a[(hi)..(lo)]; let bv : byte = b[(hi)..(lo)];
    r[(hi)..(lo)] = if unsigned(av) > unsigned(bv) then av else bv
  };
  r
}

// VPMINSW: minimum of packed signed words
val vex_pminsw_128 : (xmmword, xmmword) -> xmmword
function vex_pminsw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo = i * 16; let hi = lo + 15;
    let av : word = a[(hi)..(lo)]; let bv : word = b[(hi)..(lo)];
    r[(hi)..(lo)] = if signed(av) < signed(bv) then av else bv
  };
  r
}

// Saturation add/sub for packed bytes and words (128-bit lanes)
val vex_paddsb_128 : (xmmword, xmmword) -> xmmword
function vex_paddsb_128(a, b) =
  sat_add_s8(a[127..120], b[127..120]) @ sat_add_s8(a[119..112], b[119..112]) @
  sat_add_s8(a[111..104], b[111..104]) @ sat_add_s8(a[103..96],  b[103..96])  @
  sat_add_s8(a[95..88],   b[95..88])   @ sat_add_s8(a[87..80],   b[87..80])   @
  sat_add_s8(a[79..72],   b[79..72])   @ sat_add_s8(a[71..64],   b[71..64])   @
  sat_add_s8(a[63..56],   b[63..56])   @ sat_add_s8(a[55..48],   b[55..48])   @
  sat_add_s8(a[47..40],   b[47..40])   @ sat_add_s8(a[39..32],   b[39..32])   @
  sat_add_s8(a[31..24],   b[31..24])   @ sat_add_s8(a[23..16],   b[23..16])   @
  sat_add_s8(a[15..8],    b[15..8])    @ sat_add_s8(a[7..0],     b[7..0])

val vex_paddsw_128 : (xmmword, xmmword) -> xmmword
function vex_paddsw_128(a, b) =
  sat_add_s16(a[127..112], b[127..112]) @ sat_add_s16(a[111..96], b[111..96]) @
  sat_add_s16(a[95..80],   b[95..80])   @ sat_add_s16(a[79..64],  b[79..64])  @
  sat_add_s16(a[63..48],   b[63..48])   @ sat_add_s16(a[47..32],  b[47..32])  @
  sat_add_s16(a[31..16],   b[31..16])   @ sat_add_s16(a[15..0],   b[15..0])

val vex_paddusb_128 : (xmmword, xmmword) -> xmmword
function vex_paddusb_128(a, b) =
  sat_add_u8(a[127..120], b[127..120]) @ sat_add_u8(a[119..112], b[119..112]) @
  sat_add_u8(a[111..104], b[111..104]) @ sat_add_u8(a[103..96],  b[103..96])  @
  sat_add_u8(a[95..88],   b[95..88])   @ sat_add_u8(a[87..80],   b[87..80])   @
  sat_add_u8(a[79..72],   b[79..72])   @ sat_add_u8(a[71..64],   b[71..64])   @
  sat_add_u8(a[63..56],   b[63..56])   @ sat_add_u8(a[55..48],   b[55..48])   @
  sat_add_u8(a[47..40],   b[47..40])   @ sat_add_u8(a[39..32],   b[39..32])   @
  sat_add_u8(a[31..24],   b[31..24])   @ sat_add_u8(a[23..16],   b[23..16])   @
  sat_add_u8(a[15..8],    b[15..8])    @ sat_add_u8(a[7..0],     b[7..0])

val vex_paddusw_128 : (xmmword, xmmword) -> xmmword
function vex_paddusw_128(a, b) =
  sat_add_u16(a[127..112], b[127..112]) @ sat_add_u16(a[111..96], b[111..96]) @
  sat_add_u16(a[95..80],   b[95..80])   @ sat_add_u16(a[79..64],  b[79..64])  @
  sat_add_u16(a[63..48],   b[63..48])   @ sat_add_u16(a[47..32],  b[47..32])  @
  sat_add_u16(a[31..16],   b[31..16])   @ sat_add_u16(a[15..0],   b[15..0])

val vex_psubsb_128 : (xmmword, xmmword) -> xmmword
function vex_psubsb_128(a, b) =
  sat_sub_s8(a[127..120], b[127..120]) @ sat_sub_s8(a[119..112], b[119..112]) @
  sat_sub_s8(a[111..104], b[111..104]) @ sat_sub_s8(a[103..96],  b[103..96])  @
  sat_sub_s8(a[95..88],   b[95..88])   @ sat_sub_s8(a[87..80],   b[87..80])   @
  sat_sub_s8(a[79..72],   b[79..72])   @ sat_sub_s8(a[71..64],   b[71..64])   @
  sat_sub_s8(a[63..56],   b[63..56])   @ sat_sub_s8(a[55..48],   b[55..48])   @
  sat_sub_s8(a[47..40],   b[47..40])   @ sat_sub_s8(a[39..32],   b[39..32])   @
  sat_sub_s8(a[31..24],   b[31..24])   @ sat_sub_s8(a[23..16],   b[23..16])   @
  sat_sub_s8(a[15..8],    b[15..8])    @ sat_sub_s8(a[7..0],     b[7..0])

val vex_psubsw_128 : (xmmword, xmmword) -> xmmword
function vex_psubsw_128(a, b) =
  sat_sub_s16(a[127..112], b[127..112]) @ sat_sub_s16(a[111..96], b[111..96]) @
  sat_sub_s16(a[95..80],   b[95..80])   @ sat_sub_s16(a[79..64],  b[79..64])  @
  sat_sub_s16(a[63..48],   b[63..48])   @ sat_sub_s16(a[47..32],  b[47..32])  @
  sat_sub_s16(a[31..16],   b[31..16])   @ sat_sub_s16(a[15..0],   b[15..0])

val vex_psubusb_128 : (xmmword, xmmword) -> xmmword
function vex_psubusb_128(a, b) =
  sat_sub_u8(a[127..120], b[127..120]) @ sat_sub_u8(a[119..112], b[119..112]) @
  sat_sub_u8(a[111..104], b[111..104]) @ sat_sub_u8(a[103..96],  b[103..96])  @
  sat_sub_u8(a[95..88],   b[95..88])   @ sat_sub_u8(a[87..80],   b[87..80])   @
  sat_sub_u8(a[79..72],   b[79..72])   @ sat_sub_u8(a[71..64],   b[71..64])   @
  sat_sub_u8(a[63..56],   b[63..56])   @ sat_sub_u8(a[55..48],   b[55..48])   @
  sat_sub_u8(a[47..40],   b[47..40])   @ sat_sub_u8(a[39..32],   b[39..32])   @
  sat_sub_u8(a[31..24],   b[31..24])   @ sat_sub_u8(a[23..16],   b[23..16])   @
  sat_sub_u8(a[15..8],    b[15..8])    @ sat_sub_u8(a[7..0],     b[7..0])

val vex_psubusw_128 : (xmmword, xmmword) -> xmmword
function vex_psubusw_128(a, b) =
  sat_sub_u16(a[127..112], b[127..112]) @ sat_sub_u16(a[111..96], b[111..96]) @
  sat_sub_u16(a[95..80],   b[95..80])   @ sat_sub_u16(a[79..64],  b[79..64])  @
  sat_sub_u16(a[63..48],   b[63..48])   @ sat_sub_u16(a[47..32],  b[47..32])  @
  sat_sub_u16(a[31..16],   b[31..16])   @ sat_sub_u16(a[15..0],   b[15..0])

// Packed shift helpers for 128-bit lanes
val vex_psrlw_128 : (xmmword, int) -> xmmword
function vex_psrlw_128(a, c) =
  srl16(a[127..112], c) @ srl16(a[111..96], c) @
  srl16(a[95..80], c)   @ srl16(a[79..64], c)  @
  srl16(a[63..48], c)   @ srl16(a[47..32], c)  @
  srl16(a[31..16], c)   @ srl16(a[15..0], c)

val vex_psrld_128 : (xmmword, int) -> xmmword
function vex_psrld_128(a, c) =
  srl32(a[127..96], c) @ srl32(a[95..64], c) @
  srl32(a[63..32], c)  @ srl32(a[31..0], c)

val vex_psrlq_128 : (xmmword, int) -> xmmword
function vex_psrlq_128(a, c) =
  srl64(a[127..64], c) @ srl64(a[63..0], c)

val vex_psraw_128 : (xmmword, int) -> xmmword
function vex_psraw_128(a, c) =
  sra16(a[127..112], c) @ sra16(a[111..96], c) @
  sra16(a[95..80], c)   @ sra16(a[79..64], c)  @
  sra16(a[63..48], c)   @ sra16(a[47..32], c)  @
  sra16(a[31..16], c)   @ sra16(a[15..0], c)

val vex_psrad_128 : (xmmword, int) -> xmmword
function vex_psrad_128(a, c) =
  sra32(a[127..96], c) @ sra32(a[95..64], c) @
  sra32(a[63..32], c)  @ sra32(a[31..0], c)

val vex_psllw_128 : (xmmword, int) -> xmmword
function vex_psllw_128(a, c) =
  sll16(a[127..112], c) @ sll16(a[111..96], c) @
  sll16(a[95..80], c)   @ sll16(a[79..64], c)  @
  sll16(a[63..48], c)   @ sll16(a[47..32], c)  @
  sll16(a[31..16], c)   @ sll16(a[15..0], c)

val vex_pslld_128 : (xmmword, int) -> xmmword
function vex_pslld_128(a, c) =
  sll32(a[127..96], c) @ sll32(a[95..64], c) @
  sll32(a[63..32], c)  @ sll32(a[31..0], c)

val vex_psllq_128 : (xmmword, int) -> xmmword
function vex_psllq_128(a, c) =
  sll64(a[127..64], c) @ sll64(a[63..0], c)

// =========================================================================
// VEX 0F map dispatch (AVX versions of SSE instructions)
// =========================================================================


val dispatch_vex_0f : (byte, Prefixes) -> ExecutionResult
function dispatch_vex_0f(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F 10: VMOVUPS/VMOVUPD/VMOVSS/VMOVSD (load)
  16 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => // VMOVUPS (vvvv reserved)
        if pfx.vex_vvvv != 0 then { raise_UD() } else if pfx.vex_l then {
          let src = decode_vex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, src);
          Ok()
        } else { let src = decode_vex_src_xmm(modrm, rm, pfx); write_xmm(dst, src); Ok() },
      MP_66 => // VMOVUPD (vvvv reserved)
        if pfx.vex_vvvv != 0 then { raise_UD() } else if pfx.vex_l then {
          let src = decode_vex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, src);
          Ok()
        } else { let src = decode_vex_src_xmm(modrm, rm, pfx); write_xmm(dst, src); Ok() },
      MP_F3 => { // VMOVSS xmm1, xmm2, xmm3 or xmm1, m32
        match rm {
          RM_reg(_) => {
            // reg-reg: merge src2[127:32] with src3[31:0]
            let src2 : xmmword = read_xmm(pfx.vex_vvvv);
            let src3 : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, src2[127..32] @ src3[31..0]);
            Ok()
          },
          RM_mem(addr) => {
            // mem: load 32 bits, zero-extend to 128
            let v : dword = mem_read32(fixup_addr(addr));
            write_xmm(dst, zeros(96) @ v);
            Ok()
          },
        }
      },
      MP_F2 => { // VMOVSD xmm1, xmm2, xmm3 or xmm1, m64
        match rm {
          RM_reg(_) => {
            let src2 : xmmword = read_xmm(pfx.vex_vvvv);
            let src3 : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, src2[127..64] @ src3[63..0]);
            Ok()
          },
          RM_mem(addr) => {
            let v : qword = mem_read64(fixup_addr(addr));
            write_xmm(dst, zeros(64) @ v);
            Ok()
          },
        }
      },
    }
  },

  // 0F 11: VMOVUPS/VMOVUPD/VMOVSS/VMOVSD (store)
  17 => {
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => // VMOVUPS (vvvv reserved)
        if pfx.vex_vvvv != 0 then { raise_UD() } else match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            if pfx.vex_l then {
              write_ymm(dst, read_ymm(src)); Ok()
            } else {
              write_xmm(dst, read_xmm(src)); Ok()
            }
          },
          RM_mem(addr) => {
            let a = fixup_addr(addr);
            if pfx.vex_l then {
              mem_write256(a, read_ymm(src)); Ok()
            } else {
              mem_write128(a, read_xmm(src)); Ok()
            }
          },
        },
      MP_66 => // VMOVUPD (vvvv reserved)
        if pfx.vex_vvvv != 0 then { raise_UD() } else match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            if pfx.vex_l then {
              write_ymm(dst, read_ymm(src)); Ok()
            } else {
              write_xmm(dst, read_xmm(src)); Ok()
            }
          },
          RM_mem(addr) => {
            let a = fixup_addr(addr);
            if pfx.vex_l then {
              mem_write256(a, read_ymm(src)); Ok()
            } else {
              mem_write128(a, read_xmm(src)); Ok()
            }
          },
        },
      MP_F3 => { // VMOVSS store
        match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            let src2 : xmmword = read_xmm(pfx.vex_vvvv);
            let src3 : xmmword = read_xmm(src);
            write_xmm(dst, src2[127..32] @ src3[31..0]);
            Ok()
          },
          RM_mem(addr) => { mem_write32(fixup_addr(addr), read_xmm(src)[31..0]); Ok() },
        }
      },
      MP_F2 => { // VMOVSD store
        match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            let src2 : xmmword = read_xmm(pfx.vex_vvvv);
            let src3 : xmmword = read_xmm(src);
            write_xmm(dst, src2[127..64] @ src3[63..0]);
            Ok()
          },
          RM_mem(addr) => { mem_write64(fixup_addr(addr), read_xmm(src)[63..0]); Ok() },
        }
      },
    }
  },

  // 0F 28: VMOVAPS/VMOVAPD (load)
  // SDM: VEX.vvvv must be 1111b
  40 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match rm {
      RM_reg(_) => {
        if pfx.vex_l then {
          write_ymm(dst, read_ymm(modrm_xmm_rm(modrm, pfx)));
        } else {
          write_xmm(dst, read_xmm(modrm_xmm_rm(modrm, pfx)));
        };
        Ok()
      },
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        // VMOVAPS/VMOVAPD require alignment: 32 for YMM, 16 for XMM; #GP(0) if unaligned
        if pfx.vex_l then {
          if unsigned(a) % 32 != 0 then {
            raise_GP0()
          } else {
            write_ymm(dst, mem_read256(a));
            Ok()
          }
        } else {
          if unsigned(a) % 16 != 0 then {
            raise_GP0()
          } else {
            write_xmm(dst, mem_read128(a));
            Ok()
          }
        }
      },
    }
    }
  },

  // 0F 29: VMOVAPS/VMOVAPD (store)
  // SDM: VEX.vvvv must be 1111b
  41 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else {
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match rm {
      RM_reg(_) => {
        let dst = modrm_xmm_rm(modrm, pfx);
        if pfx.vex_l then {
          write_ymm(dst, read_ymm(src)); Ok()
        } else {
          write_xmm(dst, read_xmm(src)); Ok()
        }
      },
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        // VMOVAPS/VMOVAPD require alignment: 32 for YMM, 16 for XMM; #GP(0) if unaligned
        if pfx.vex_l then {
          if unsigned(a) % 32 != 0 then {
            raise_GP0()
          } else {
            mem_write256(a, read_ymm(src)); Ok()
          }
        } else {
          if unsigned(a) % 16 != 0 then {
            raise_GP0()
          } else {
            mem_write128(a, read_xmm(src)); Ok()
          }
        }
      },
    }
    }
  },

  // 0F 2E: VUCOMISS (NP) / VUCOMISD (66) — unordered compare scalars, set EFLAGS
  // SDM: VEX.vvvv must be 1111b
  46 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else {
    let modrm = fetch_byte();
    let src_reg = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => { // VUCOMISS
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read32(fixup_addr(addr))),
        };
        let a : dword = read_xmm(src_reg)[31..0];
        let b : dword = src[31..0];
        match __compare_ss(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok()
      },
      MP_66 => { // VUCOMISD
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read64(fixup_addr(addr))),
        };
        let a : qword = read_xmm(src_reg)[63..0];
        let b : qword = src[63..0];
        match __compare_sd(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok()
      },
      _ => raise_UD(),
    }
    }
  },

  // 0F 2F: VCOMISS (NP) / VCOMISD (66) — ordered compare scalars, set EFLAGS
  // SDM: VEX.vvvv must be 1111b
  47 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else {
    let modrm = fetch_byte();
    let src_reg = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => { // VCOMISS
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read32(fixup_addr(addr))),
        };
        let a : dword = read_xmm(src_reg)[31..0];
        let b : dword = src[31..0];
        match __compare_ss(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok()
      },
      MP_66 => { // VCOMISD
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read64(fixup_addr(addr))),
        };
        let a : qword = read_xmm(src_reg)[63..0];
        let b : qword = src[63..0];
        match __compare_sd(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok()
      },
      _ => raise_UD(),
    }
    }
  },

  // 0F 14: VUNPCKLPS (NP) / VUNPCKLPD (66)
  20 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      match mp {
        MP_NONE => { // VUNPCKLPS ymm
          let lo = src2[63..32] @ src1[63..32] @ src2[31..0] @ src1[31..0];
          let hi = src2[191..160] @ src1[191..160] @ src2[159..128] @ src1[159..128];
          write_ymm(dst, hi @ lo);
          Ok()
        },
        MP_66 => { // VUNPCKLPD ymm
          let lo = src2[63..0] @ src1[63..0];
          let hi = src2[191..128] @ src1[191..128];
          write_ymm(dst, hi @ lo);
          Ok()
        },
        _ => raise_UD(),
      }
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      match mp {
        MP_NONE => { write_xmm(dst, src2[63..32] @ src1[63..32] @ src2[31..0] @ src1[31..0]); Ok() },
        MP_66   => { write_xmm(dst, src2[63..0] @ src1[63..0]); Ok() },
        _ => raise_UD(),
      }
    }
  },

  // 0F 15: VUNPCKHPS (NP) / VUNPCKHPD (66)
  21 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      match mp {
        MP_NONE => { // VUNPCKHPS ymm
          let lo = src2[127..96] @ src1[127..96] @ src2[95..64] @ src1[95..64];
          let hi = src2[255..224] @ src1[255..224] @ src2[223..192] @ src1[223..192];
          write_ymm(dst, hi @ lo);
          Ok()
        },
        MP_66 => { // VUNPCKHPD ymm
          let lo = src2[127..64] @ src1[127..64];
          let hi = src2[255..192] @ src1[255..192];
          write_ymm(dst, hi @ lo);
          Ok()
        },
        _ => raise_UD(),
      }
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      match mp {
        MP_NONE => { write_xmm(dst, src2[127..96] @ src1[127..96] @ src2[95..64] @ src1[95..64]); Ok() },
        MP_66   => { write_xmm(dst, src2[127..64] @ src1[127..64]); Ok() },
        _ => raise_UD(),
      }
    }
  },

  // 0F 12: VMOVLPS/VMOVHLPS (NP) / VMOVLPD (66) / VMOVSLDUP (F3) / VMOVDDUP (F2)
  18 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => {
        match rm {
          RM_reg(_) => { // VMOVHLPS: dst[63:0] = src2[127:64], dst[127:64] = vvvv[127:64]
            let src1 : xmmword = read_xmm(pfx.vex_vvvv);
            let src2 : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, src1[127..64] @ src2[127..64]);
            Ok()
          },
          RM_mem(addr) => { // VMOVLPS: dst[63:0] = m64, dst[127:64] = vvvv[127:64]
            let src1 : xmmword = read_xmm(pfx.vex_vvvv);
            let v : qword = mem_read64(fixup_addr(addr));
            write_xmm(dst, src1[127..64] @ v);
            Ok()
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 16: VMOVHPS/VMOVLHPS (NP) / VMOVHPD (66) / VMOVSHDUP (F3)
  22 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => {
        match rm {
          RM_reg(_) => { // VMOVLHPS: dst[127:64] = src2[63:0], dst[63:0] = vvvv[63:0]
            let src1 : xmmword = read_xmm(pfx.vex_vvvv);
            let src2 : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, src2[63..0] @ src1[63..0]);
            Ok()
          },
          RM_mem(addr) => { // VMOVHPS: dst[63:0] = vvvv[63:0], dst[127:64] = m64
            let src1 : xmmword = read_xmm(pfx.vex_vvvv);
            let v : qword = mem_read64(fixup_addr(addr));
            write_xmm(dst, v @ src1[63..0]);
            Ok()
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 2A: VCVTSI2SS (F3) / VCVTSI2SD (F2) — int to scalar float
  42 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src1 : xmmword = read_xmm(pfx.vex_vvvv);
    match mp {
      MP_F3 => { // VCVTSI2SS
        if pfx.vex_w then {
          let v : qword = match rm { RM_reg(idx) => read_gpr64(idx), RM_mem(addr) => mem_read64(fixup_addr(addr)) };
          write_xmm(dst, src1[127..32] @ __int64_to_f32(v));
        } else {
          let v : dword = match rm { RM_reg(idx) => read_gpr32(idx), RM_mem(addr) => mem_read32(fixup_addr(addr)) };
          write_xmm(dst, src1[127..32] @ __int32_to_f32(v));
        };
        Ok()
      },
      MP_F2 => { // VCVTSI2SD
        if pfx.vex_w then {
          let v : qword = match rm { RM_reg(idx) => read_gpr64(idx), RM_mem(addr) => mem_read64(fixup_addr(addr)) };
          write_xmm(dst, src1[127..64] @ __int64_to_f64(v));
        } else {
          let v : dword = match rm { RM_reg(idx) => read_gpr32(idx), RM_mem(addr) => mem_read32(fixup_addr(addr)) };
          write_xmm(dst, src1[127..64] @ __int32_to_f64(v));
        };
        Ok()
      },
      _ => raise_UD(),
    }
  },

  // 0F 2C: VCVTTSS2SI (F3) / VCVTTSD2SI (F2) — truncating scalar float to int
  44 => {
    let modrm = fetch_byte();
    let rm = decode_rm(modrm, pfx);
    let dst_gpr = modrm_reg(modrm, pfx);
    match mp {
      MP_F3 => { // VCVTTSS2SI
        let src : dword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        if pfx.vex_w then write_gpr64(dst_gpr, __f32_to_int64_trunc(src))
        else write_gpr32(dst_gpr, __f32_to_int32_trunc(src));
        Ok()
      },
      MP_F2 => { // VCVTTSD2SI
        let src : qword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        if pfx.vex_w then write_gpr64(dst_gpr, __f64_to_int64_trunc(src))
        else write_gpr32(dst_gpr, __f64_to_int32_trunc(src));
        Ok()
      },
      _ => raise_UD(),
    }
  },

  // 0F 41: KANDW k1, k2, k3 (NP, W0)
  65 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = pfx.vex_vvvv % 8;
    let k3 : range(0, 7) = unsigned(modrm[2..0]);
    let result : qword = read_kreg(k2) & read_kreg(k3);
    write_kreg(k1, zero_extend(result[15..0]));
    Ok()
  },

  // 0F 44: KNOTW k1, k2 (NP, W0)
  68 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = unsigned(modrm[2..0]);
    write_kreg(k1, zero_extend(~(read_kreg(k2)[15..0])));
    Ok()
  },

  // 0F 47: KXORW k1, k2, k3 (NP, W0)
  71 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = pfx.vex_vvvv % 8;
    let k3 : range(0, 7) = unsigned(modrm[2..0]);
    let result : qword = xor_vec(read_kreg(k2), read_kreg(k3));
    write_kreg(k1, zero_extend(result[15..0]));
    Ok()
  },

  // 0F 4A: KADDW k1, k2, k3 (NP, W0)
  74 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = pfx.vex_vvvv % 8;
    let k3 : range(0, 7) = unsigned(modrm[2..0]);
    let sum : bits(16) = read_kreg(k2)[15..0] + read_kreg(k3)[15..0];
    write_kreg(k1, zero_extend(sum));
    Ok()
  },

  // 0F 92: KMOVW r32 -> k (NP, W0) / KMOVB/D/Q variants
  146 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => { // KMOVW: r/m16 -> k
        let v : dword = match rm {
          RM_reg(idx) => read_gpr32(idx),
          RM_mem(addr) => zero_extend(mem_read16(fixup_addr(addr))),
        };
        write_kreg(k1, zero_extend(v[15..0]));
        Ok()
      },
      _ => raise_UD(),
    }
  },

  // 0F 93: KMOVW k -> r32 (NP, W0) / KMOVD k -> r32 (F2, W0)
  147 => {
    let modrm = fetch_byte();
    let dst_gpr = modrm_reg(modrm, pfx);
    let k1 : range(0, 7) = unsigned(modrm[2..0]);
    match mp {
      MP_NONE => { // KMOVW
        write_gpr32(dst_gpr, zero_extend(read_kreg(k1)[15..0]));
        Ok()
      },
      MP_F2 => { // KMOVD
        write_gpr32(dst_gpr, read_kreg(k1)[31..0]);
        Ok()
      },
      _ => raise_UD(),
    }
  },

  // 0F 50-5F: Packed arithmetic
  // Common pattern: dst = vvvv OP src (3-operand)
  op if 80 <= op & op <= 95 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let col : range(0, 15) = op - 80;

    if pfx.vex_l then {
      // 256-bit YMM path
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      match col {
        1 => if pfx.vex_vvvv != 0 then { raise_UD() } else match mp { // VSQRTPS/VSQRTPD (unary, vvvv reserved)
          MP_NONE => { write_ymm(dst, vsqrtps_xmm(src2[255..128]) @ vsqrtps_xmm(src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vsqrtpd_xmm(src2[255..128]) @ vsqrtpd_xmm(src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        4 => match mp { // VANDPS/VANDPD
          _ => { write_ymm(dst, src1 & src2); Ok() },
        },
        5 => match mp { // VANDNPS/VANDNPD
          _ => { write_ymm(dst, ~(src1) & src2); Ok() },
        },
        6 => match mp { // VORPS/VORPD
          _ => { write_ymm(dst, src1 | src2); Ok() },
        },
        7 => match mp { // VXORPS/VXORPD
          _ => { write_ymm(dst, xor_vec(src1, src2)); Ok() },
        },
        8 => match mp { // VADDPS/VADDPD
          MP_NONE => { write_ymm(dst, vaddps_xmm(src1[255..128], src2[255..128]) @ vaddps_xmm(src1[127..0], src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vaddpd_xmm(src1[255..128], src2[255..128]) @ vaddpd_xmm(src1[127..0], src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        9 => match mp { // VMULPS/VMULPD
          MP_NONE => { write_ymm(dst, vmulps_xmm(src1[255..128], src2[255..128]) @ vmulps_xmm(src1[127..0], src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vmulpd_xmm(src1[255..128], src2[255..128]) @ vmulpd_xmm(src1[127..0], src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        10 => if pfx.vex_vvvv != 0 then { raise_UD() } else match mp { // VCVTPS2PD/VCVTPD2PS (256-bit, vvvv reserved)
          MP_NONE => { // VCVTPS2PD: 4 floats -> 4 doubles
            let r3 = __f32_to_f64(src2[127..96]);
            let r2 = __f32_to_f64(src2[95..64]);
            let r1 = __f32_to_f64(src2[63..32]);
            let r0 = __f32_to_f64(src2[31..0]);
            write_ymm(dst, r3 @ r2 @ r1 @ r0);
            Ok()
          },
          MP_66 => { // VCVTPD2PS: 4 doubles -> 4 floats (in low 128)
            let r3 = __f64_to_f32(src2[255..192]);
            let r2 = __f64_to_f32(src2[191..128]);
            let r1 = __f64_to_f32(src2[127..64]);
            let r0 = __f64_to_f32(src2[63..0]);
            write_xmm(dst, r3 @ r2 @ r1 @ r0);
            Ok()
          },
          _ => raise_UD(),
        },
        12 => match mp { // VSUBPS/VSUBPD
          MP_NONE => { write_ymm(dst, vsubps_xmm(src1[255..128], src2[255..128]) @ vsubps_xmm(src1[127..0], src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vsubpd_xmm(src1[255..128], src2[255..128]) @ vsubpd_xmm(src1[127..0], src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        13 => match mp { // VMINPS/VMINPD
          MP_NONE => { write_ymm(dst, vminps_xmm(src1[255..128], src2[255..128]) @ vminps_xmm(src1[127..0], src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vminpd_xmm(src1[255..128], src2[255..128]) @ vminpd_xmm(src1[127..0], src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        14 => match mp { // VDIVPS/VDIVPD
          MP_NONE => { write_ymm(dst, vdivps_xmm(src1[255..128], src2[255..128]) @ vdivps_xmm(src1[127..0], src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vdivpd_xmm(src1[255..128], src2[255..128]) @ vdivpd_xmm(src1[127..0], src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        15 => match mp { // VMAXPS/VMAXPD
          MP_NONE => { write_ymm(dst, vmaxps_xmm(src1[255..128], src2[255..128]) @ vmaxps_xmm(src1[127..0], src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vmaxpd_xmm(src1[255..128], src2[255..128]) @ vmaxpd_xmm(src1[127..0], src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        _ => raise_UD(),
      }
    } else {
      // 128-bit XMM path (upper bits zeroed by write_xmm)
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      match col {
        1 => match mp { // VSQRTPS/VSQRTPD/VSQRTSS/VSQRTSD
          MP_NONE => if pfx.vex_vvvv != 0 then { raise_UD() } else { write_xmm(dst, vsqrtps_xmm(src2)); Ok() },
          MP_66   => if pfx.vex_vvvv != 0 then { raise_UD() } else { write_xmm(dst, vsqrtpd_xmm(src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_sqrt(src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_sqrt(src2[63..0])); Ok() },
        },
        4 => match mp { // VANDPS/VANDPD
          _ => { write_xmm(dst, src1 & src2); Ok() },
        },
        5 => match mp { // VANDNPS/VANDNPD
          _ => { write_xmm(dst, ~(src1) & src2); Ok() },
        },
        6 => match mp { // VORPS/VORPD
          _ => { write_xmm(dst, src1 | src2); Ok() },
        },
        7 => match mp { // VXORPS/VXORPD
          _ => { write_xmm(dst, xor_vec(src1, src2)); Ok() },
        },
        8 => match mp { // VADDPS/VADDPD/VADDSS/VADDSD
          MP_NONE => { write_xmm(dst, vaddps_xmm(src1, src2)); Ok() },
          MP_66   => { write_xmm(dst, vaddpd_xmm(src1, src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_add(src1[31..0], src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_add(src1[63..0], src2[63..0])); Ok() },
        },
        9 => match mp { // VMULPS/VMULPD/VMULSS/VMULSD
          MP_NONE => { write_xmm(dst, vmulps_xmm(src1, src2)); Ok() },
          MP_66   => { write_xmm(dst, vmulpd_xmm(src1, src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_mul(src1[31..0], src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_mul(src1[63..0], src2[63..0])); Ok() },
        },
        11 => if pfx.vex_vvvv != 0 then { raise_UD() } else match mp { // VCVTDQ2PS/VCVTPS2DQ/VCVTTPS2DQ (unary, vvvv reserved)
          MP_NONE => { // VCVTDQ2PS
            write_xmm(dst, __int32_to_f32(src2[127..96]) @ __int32_to_f32(src2[95..64]) @
              __int32_to_f32(src2[63..32]) @ __int32_to_f32(src2[31..0]));
            Ok()
          },
          MP_66 => { // VCVTPS2DQ
            write_xmm(dst, __f32_to_int32(src2[127..96]) @ __f32_to_int32(src2[95..64]) @
              __f32_to_int32(src2[63..32]) @ __f32_to_int32(src2[31..0]));
            Ok()
          },
          MP_F3 => { // VCVTTPS2DQ
            write_xmm(dst, __f32_to_int32_trunc(src2[127..96]) @ __f32_to_int32_trunc(src2[95..64]) @
              __f32_to_int32_trunc(src2[63..32]) @ __f32_to_int32_trunc(src2[31..0]));
            Ok()
          },
          _ => raise_UD(),
        },
        10 => match mp { // VCVTPS2PD/VCVTPD2PS/VCVTSS2SD/VCVTSD2SS (128-bit)
          MP_NONE => // VCVTPS2PD: 2 floats -> 2 doubles (vvvv reserved)
            if pfx.vex_vvvv != 0 then { raise_UD() } else {
            let r1 = __f32_to_f64(src2[63..32]);
            let r0 = __f32_to_f64(src2[31..0]);
            write_xmm(dst, r1 @ r0);
            Ok()
          },
          MP_66 => // VCVTPD2PS: 2 doubles -> 2 floats (vvvv reserved)
            if pfx.vex_vvvv != 0 then { raise_UD() } else {
            let r1 = __f64_to_f32(src2[127..64]);
            let r0 = __f64_to_f32(src2[63..0]);
            write_xmm(dst, zeros(64) @ r1 @ r0);
            Ok()
          },
          MP_F3 => { // VCVTSS2SD: scalar float -> double
            write_xmm(dst, src1[127..64] @ __f32_to_f64(src2[31..0]));
            Ok()
          },
          MP_F2 => { // VCVTSD2SS: scalar double -> float
            write_xmm(dst, src1[127..32] @ __f64_to_f32(src2[63..0]));
            Ok()
          },
        },
        12 => match mp { // VSUBPS/VSUBPD/VSUBSS/VSUBSD
          MP_NONE => { write_xmm(dst, vsubps_xmm(src1, src2)); Ok() },
          MP_66   => { write_xmm(dst, vsubpd_xmm(src1, src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_sub(src1[31..0], src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_sub(src1[63..0], src2[63..0])); Ok() },
        },
        13 => match mp { // VMINPS/VMINPD/VMINSS/VMINSD
          MP_NONE => { write_xmm(dst, vminps_xmm(src1, src2)); Ok() },
          MP_66   => { write_xmm(dst, vminpd_xmm(src1, src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_min(src1[31..0], src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_min(src1[63..0], src2[63..0])); Ok() },
        },
        14 => match mp { // VDIVPS/VDIVPD/VDIVSS/VDIVSD
          MP_NONE => { write_xmm(dst, vdivps_xmm(src1, src2)); Ok() },
          MP_66   => { write_xmm(dst, vdivpd_xmm(src1, src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_div(src1[31..0], src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_div(src1[63..0], src2[63..0])); Ok() },
        },
        15 => match mp { // VMAXPS/VMAXPD/VMAXSS/VMAXSD
          MP_NONE => { write_xmm(dst, vmaxps_xmm(src1, src2)); Ok() },
          MP_66   => { write_xmm(dst, vmaxpd_xmm(src1, src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_max(src1[31..0], src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_max(src1[63..0], src2[63..0])); Ok() },
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F 6E: VMOVD/VMOVQ gpr/mem -> xmm (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  110 => {
    if mp != MP_66 | pfx.vex_l then {
      raise_UD()
    } else if pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_w then {
        // VMOVQ xmm, r/m64
        let v : qword = match rm {
          RM_reg(idx) => read_gpr64(idx),
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_xmm(dst, zero_extend(v));
        Ok()
      } else {
        // VMOVD xmm, r/m32
        let v : dword = match rm {
          RM_reg(idx) => read_gpr32(idx),
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        write_xmm(dst, zero_extend(v));
        Ok()
      }
    }
  },

  // 0F 6F: VMOVDQA/VMOVDQU (load)
  // SDM: VEX.vvvv must be 1111b
  111 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_66 => // VMOVDQA
        if pfx.vex_l then {
          write_ymm(dst, decode_vex_src_ymm(modrm, rm, pfx));
          Ok()
        } else { write_xmm(dst, decode_vex_src_xmm(modrm, rm, pfx)); Ok() },
      MP_F3 => // VMOVDQU
        if pfx.vex_l then {
          write_ymm(dst, decode_vex_src_ymm(modrm, rm, pfx));
          Ok()
        } else { write_xmm(dst, decode_vex_src_xmm(modrm, rm, pfx)); Ok() },
      _ => raise_UD(),
    }
    }
  },

  // 0F 7E: VMOVD/VMOVQ xmm -> gpr/mem (66 prefix) / VMOVQ xmm,xmm/m64 (F3 prefix)
  // SDM: VEX.128 only, VEX.vvvv must be 1111b
  126 => {
    if pfx.vex_vvvv != 0 | pfx.vex_l then {
      raise_UD()
    } else {
    let modrm = fetch_byte();
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_66 => {
        // VMOVD/VMOVQ xmm -> r/m
        let src = read_xmm(modrm_xmm_reg(modrm, pfx));
        if pfx.vex_w then {
          match rm {
            RM_reg(idx) => write_gpr64(idx, src[63..0]),
            RM_mem(addr) => mem_write64(fixup_addr(addr), src[63..0]),
          };
        } else {
          match rm {
            RM_reg(idx) => write_gpr32(idx, src[31..0]),
            RM_mem(addr) => mem_write32(fixup_addr(addr), src[31..0]),
          };
        };
        Ok()
      },
      MP_F3 => {
        // VMOVQ xmm1, xmm2/m64
        let dst = modrm_xmm_reg(modrm, pfx);
        match rm {
          RM_reg(_) => {
            let src = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, zero_extend(src[63..0]));
            Ok()
          },
          RM_mem(addr) => {
            let v : qword = mem_read64(fixup_addr(addr));
            write_xmm(dst, zero_extend(v));
            Ok()
          },
        }
      },
      _ => raise_UD(),
    }
    }
  },

  // 0F 7F: VMOVDQA/VMOVDQU (store)
  // SDM: VEX.vvvv must be 1111b
  127 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else {
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match rm {
      RM_reg(_) => {
        let dst = modrm_xmm_rm(modrm, pfx);
        if pfx.vex_l then {
          write_ymm(dst, read_ymm(src)); Ok()
        } else {
          write_xmm(dst, read_xmm(src)); Ok()
        }
      },
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        if pfx.vex_l then {
          mem_write256(a, read_ymm(src)); Ok()
        } else {
          mem_write128(a, read_xmm(src)); Ok()
        }
      },
    }
    }
  },

  // 0F 70: VPSHUFD xmm/ymm, xmm/ymm/m, imm8 (66 prefix)
  // SDM: VEX.vvvv must be 1111b. 256-bit shuffles each 128-bit lane independently.
  112 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        let imm = fetch_byte();
        // Shuffle low 128-bit lane
        let lo : xmmword = src[127..0];
        let l0 : dword = match unsigned(imm[1..0]) {
          0 => lo[31..0], 1 => lo[63..32], 2 => lo[95..64], _ => lo[127..96],
        };
        let l1 : dword = match unsigned(imm[3..2]) {
          0 => lo[31..0], 1 => lo[63..32], 2 => lo[95..64], _ => lo[127..96],
        };
        let l2 : dword = match unsigned(imm[5..4]) {
          0 => lo[31..0], 1 => lo[63..32], 2 => lo[95..64], _ => lo[127..96],
        };
        let l3 : dword = match unsigned(imm[7..6]) {
          0 => lo[31..0], 1 => lo[63..32], 2 => lo[95..64], _ => lo[127..96],
        };
        // Shuffle high 128-bit lane
        let hi : xmmword = src[255..128];
        let h0 : dword = match unsigned(imm[1..0]) {
          0 => hi[31..0], 1 => hi[63..32], 2 => hi[95..64], _ => hi[127..96],
        };
        let h1 : dword = match unsigned(imm[3..2]) {
          0 => hi[31..0], 1 => hi[63..32], 2 => hi[95..64], _ => hi[127..96],
        };
        let h2 : dword = match unsigned(imm[5..4]) {
          0 => hi[31..0], 1 => hi[63..32], 2 => hi[95..64], _ => hi[127..96],
        };
        let h3 : dword = match unsigned(imm[7..6]) {
          0 => hi[31..0], 1 => hi[63..32], 2 => hi[95..64], _ => hi[127..96],
        };
        write_ymm(dst, (h3 @ h2 @ h1 @ h0) @ (l3 @ l2 @ l1 @ l0));
        Ok()
      } else {
        let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        let imm = fetch_byte();
        let d0 : dword = match unsigned(imm[1..0]) {
          0 => src[31..0], 1 => src[63..32], 2 => src[95..64], _ => src[127..96],
        };
        let d1 : dword = match unsigned(imm[3..2]) {
          0 => src[31..0], 1 => src[63..32], 2 => src[95..64], _ => src[127..96],
        };
        let d2 : dword = match unsigned(imm[5..4]) {
          0 => src[31..0], 1 => src[63..32], 2 => src[95..64], _ => src[127..96],
        };
        let d3 : dword = match unsigned(imm[7..6]) {
          0 => src[31..0], 1 => src[63..32], 2 => src[95..64], _ => src[127..96],
        };
        write_xmm(dst, d3 @ d2 @ d1 @ d0);
        Ok()
      }
    }
  },

  // 0F 76: VPCMPEQD xmm/ymm (66 prefix)
  118 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        let r7 : dword = if src1[255..224] == src2[255..224] then ones() else zeros();
        let r6 : dword = if src1[223..192] == src2[223..192] then ones() else zeros();
        let r5 : dword = if src1[191..160] == src2[191..160] then ones() else zeros();
        let r4 : dword = if src1[159..128] == src2[159..128] then ones() else zeros();
        let r3 : dword = if src1[127..96]  == src2[127..96]  then ones() else zeros();
        let r2 : dword = if src1[95..64]   == src2[95..64]   then ones() else zeros();
        let r1 : dword = if src1[63..32]   == src2[63..32]   then ones() else zeros();
        let r0 : dword = if src1[31..0]    == src2[31..0]    then ones() else zeros();
        write_ymm(dst, r7 @ r6 @ r5 @ r4 @ r3 @ r2 @ r1 @ r0);
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        let r3 : dword = if src1[127..96] == src2[127..96] then ones() else zeros();
        let r2 : dword = if src1[95..64]  == src2[95..64]  then ones() else zeros();
        let r1 : dword = if src1[63..32]  == src2[63..32]  then ones() else zeros();
        let r0 : dword = if src1[31..0]   == src2[31..0]   then ones() else zeros();
        write_xmm(dst, r3 @ r2 @ r1 @ r0);
        Ok()
      }
    }
  },

  // 0F 77: VZEROUPPER (VEX.128) / VZEROALL (VEX.256)
  // SDM: VEX.vvvv must be 1111b
  119 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else if pfx.vex_l then {
      // VZEROALL: zero ZMM0-ZMM15 entirely (in 64-bit mode)
      foreach (i from 0 to 15) {
        ZMM[i] = zeros()
      };
      Ok()
    } else {
      // VZEROUPPER: zero upper bits (255:128) of ZMM0-ZMM15
      foreach (i from 0 to 15) {
        var r : zmmword = ZMM[i];
        r[511..128] = zeros();
        ZMM[i] = r
      };
      Ok()
    }
  },

  // 0F EF: VPXOR (66 prefix)
  239 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1_reg = pfx.vex_vvvv;
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(src1_reg);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, xor_vec(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(src1_reg);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, xor_vec(src1, src2));
        Ok()
      }
    }
  },

  // 0F DB: VPAND (66 prefix)
  219 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, read_ymm(pfx.vex_vvvv) & decode_vex_src_ymm(modrm, rm, pfx));
        Ok()
      } else { write_xmm(dst, read_xmm(pfx.vex_vvvv) & decode_vex_src_xmm(modrm, rm, pfx)); Ok() }
    }
  },

  // 0F DF: VPANDN (66 prefix)
  223 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, ~(read_ymm(pfx.vex_vvvv)) & decode_vex_src_ymm(modrm, rm, pfx));
        Ok()
      } else {
        write_xmm(dst, ~(read_xmm(pfx.vex_vvvv)) & decode_vex_src_xmm(modrm, rm, pfx));
        Ok()
      }
    }
  },

  // 0F EB: VPOR (66 prefix)
  235 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, read_ymm(pfx.vex_vvvv) | decode_vex_src_ymm(modrm, rm, pfx));
        Ok()
      } else { write_xmm(dst, read_xmm(pfx.vex_vvvv) | decode_vex_src_xmm(modrm, rm, pfx)); Ok() }
    }
  },

  // 0F FC: VPADDB (66 prefix)
  252 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_paddb_128(src1[255..128], src2[255..128]) @ avx_paddb_128(src1[127..0], src2[127..0]));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_paddb_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F FD: VPADDW (66 prefix)
  253 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_paddw_128(src1[255..128], src2[255..128]) @ avx_paddw_128(src1[127..0], src2[127..0]));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_paddw_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F FE: VPADDD (66 prefix)
  254 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_paddd_128(src1[255..128], src2[255..128]) @ avx_paddd_128(src1[127..0], src2[127..0]));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_paddd_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F D4: VPADDQ (66 prefix)
  212 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_paddq_128(src1[255..128], src2[255..128]) @ avx_paddq_128(src1[127..0], src2[127..0]));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_paddq_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F D6: VMOVQ xmm1/m64, xmm2 (66 prefix, VEX.128 only)
  // SDM: VEX.vvvv must be 1111b, VEX.L must be 0
  214 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let src_xmm = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v : qword = read_xmm(src_xmm)[63..0];
      match rm {
        RM_reg(_) => {
          write_xmm(modrm_xmm_rm(modrm, pfx), zero_extend(v));
          Ok()
        },
        RM_mem(addr) => { mem_write64(fixup_addr(addr), v); Ok() },
      }
    }
  },

  // 0F F8: VPSUBB (66 prefix)
  248 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_psubb_128(src1[255..128], src2[255..128]) @ avx_psubb_128(src1[127..0], src2[127..0]));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_psubb_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F F9: VPSUBW (66 prefix)
  249 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_psubw_128(src1[255..128], src2[255..128]) @ avx_psubw_128(src1[127..0], src2[127..0]));
        Ok()
      } else {
        write_xmm(dst, avx_psubw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F FA: VPSUBD (66 prefix)
  250 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_psubd_128(src1[255..128], src2[255..128]) @ avx_psubd_128(src1[127..0], src2[127..0]));
        Ok()
      } else {
        write_xmm(dst, avx_psubd_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F FB: VPSUBQ (66 prefix)
  251 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_psubq_128(src1[255..128], src2[255..128]) @ avx_psubq_128(src1[127..0], src2[127..0]));
        Ok()
      } else {
        write_xmm(dst, avx_psubq_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F C4: VPINSRW xmm, xmm, r32/m16, imm8 (66 prefix, VEX.128 only)
  196 => {
    if mp != MP_66 | pfx.vex_l then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let v : word = match rm {
        RM_reg(idx) => read_gpr32(idx)[15..0],
        RM_mem(addr) => mem_read16(fixup_addr(addr)),
      };
      let imm = fetch_byte();
      let sel : range(0, 7) = unsigned(imm[2..0]);
      var result : xmmword = src1;
      foreach (i from 0 to 7) {
        if i == sel then result[(16 * i + 15) .. (16 * i)] = v;
      };
      write_xmm(dst, result);
      Ok()
    }
  },

  // 0F C5: VPEXTRW r32, xmm, imm8 (66 prefix, VEX.128 only)
  197 => {
    if mp != MP_66 | pfx.vex_l then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst_gpr = modrm_reg(modrm, pfx);
      let src : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
      let imm = fetch_byte();
      let sel : range(0, 7) = unsigned(imm[2..0]);
      var result : word = zeros();
      foreach (i from 0 to 7) {
        if i == sel then result = src[(16 * i + 15) .. (16 * i)];
      };
      write_gpr32(dst_gpr, zero_extend(result));
      Ok()
    }
  },

  // 0F C2: VCMPPS/VCMPPD/VCMPSS/VCMPSD imm8
  194 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let imm = fetch_byte();
    let pred : bits(3) = imm[2..0];
    match mp {
      MP_NONE => { // VCMPPS
        if pfx.vex_l then {
          let src1 : ymmword = read_ymm(pfx.vex_vvvv);
          let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, cmp_pred_f32(src1[255..224], src2[255..224], pred) @
                          cmp_pred_f32(src1[223..192], src2[223..192], pred) @
                          cmp_pred_f32(src1[191..160], src2[191..160], pred) @
                          cmp_pred_f32(src1[159..128], src2[159..128], pred) @
                          cmp_pred_f32(src1[127..96],  src2[127..96],  pred) @
                          cmp_pred_f32(src1[95..64],   src2[95..64],   pred) @
                          cmp_pred_f32(src1[63..32],   src2[63..32],   pred) @
                          cmp_pred_f32(src1[31..0],    src2[31..0],    pred));
          Ok()
        } else {
          let src1 : xmmword = read_xmm(pfx.vex_vvvv);
          let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          write_xmm(dst, cmp_pred_f32(src1[127..96], src2[127..96], pred) @
                          cmp_pred_f32(src1[95..64],  src2[95..64],  pred) @
                          cmp_pred_f32(src1[63..32],  src2[63..32],  pred) @
                          cmp_pred_f32(src1[31..0],   src2[31..0],   pred));
          Ok()
        }
      },
      MP_66 => { // VCMPPD
        if pfx.vex_l then {
          let src1 : ymmword = read_ymm(pfx.vex_vvvv);
          let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, cmp_pred_f64(src1[255..192], src2[255..192], pred) @
                          cmp_pred_f64(src1[191..128], src2[191..128], pred) @
                          cmp_pred_f64(src1[127..64],  src2[127..64],  pred) @
                          cmp_pred_f64(src1[63..0],    src2[63..0],    pred));
          Ok()
        } else {
          let src1 : xmmword = read_xmm(pfx.vex_vvvv);
          let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          write_xmm(dst, cmp_pred_f64(src1[127..64], src2[127..64], pred) @
                          cmp_pred_f64(src1[63..0],   src2[63..0],   pred));
          Ok()
        }
      },
      MP_F3 => { // VCMPSS (scalar, VEX.L ignored)
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, src1[127..32] @ cmp_pred_f32(src1[31..0], src2[31..0], pred));
        Ok()
      },
      MP_F2 => { // VCMPSD (scalar, VEX.L ignored)
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, src1[127..64] @ cmp_pred_f64(src1[63..0], src2[63..0], pred));
        Ok()
      },
    }
  },

  // 0F C6: VSHUFPS (NP) / VSHUFPD (66) imm8
  198 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let imm = fetch_byte();
    match mp {
      MP_NONE => { // VSHUFPS
        let s0 : range(0, 3) = unsigned(imm[1..0]);
        let s1 : range(0, 3) = unsigned(imm[3..2]);
        let s2 : range(0, 3) = unsigned(imm[5..4]);
        let s3 : range(0, 3) = unsigned(imm[7..6]);
        if pfx.vex_l then {
          // 256-bit: two independent 128-bit lane shuffles, same imm8
          let src1 : ymmword = read_ymm(pfx.vex_vvvv);
          let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          // Low lane: select from src1[127..0] and src2[127..0]
          var r0 : dword = zeros(); var r1 : dword = zeros();
          var r2 : dword = zeros(); var r3 : dword = zeros();
          foreach (i from 0 to 3) {
            if i == s0 then r0 = src1[(32*i+31) .. (32*i)];
            if i == s1 then r1 = src1[(32*i+31) .. (32*i)];
            if i == s2 then r2 = src2[(32*i+31) .. (32*i)];
            if i == s3 then r3 = src2[(32*i+31) .. (32*i)];
          };
          // High lane: select from src1[255..128] and src2[255..128]
          var r4 : dword = zeros(); var r5 : dword = zeros();
          var r6 : dword = zeros(); var r7 : dword = zeros();
          foreach (i from 0 to 3) {
            if i == s0 then r4 = src1[(32*i+159) .. (32*i+128)];
            if i == s1 then r5 = src1[(32*i+159) .. (32*i+128)];
            if i == s2 then r6 = src2[(32*i+159) .. (32*i+128)];
            if i == s3 then r7 = src2[(32*i+159) .. (32*i+128)];
          };
          write_ymm(dst, r7 @ r6 @ r5 @ r4 @ r3 @ r2 @ r1 @ r0);
          Ok()
        } else {
          let src1 : xmmword = read_xmm(pfx.vex_vvvv);
          let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          var r0 : dword = zeros(); var r1 : dword = zeros();
          var r2 : dword = zeros(); var r3 : dword = zeros();
          foreach (i from 0 to 3) {
            if i == s0 then r0 = src1[(32*i+31) .. (32*i)];
            if i == s1 then r1 = src1[(32*i+31) .. (32*i)];
            if i == s2 then r2 = src2[(32*i+31) .. (32*i)];
            if i == s3 then r3 = src2[(32*i+31) .. (32*i)];
          };
          write_xmm(dst, r3 @ r2 @ r1 @ r0);
          Ok()
        }
      },
      MP_66 => { // VSHUFPD
        if pfx.vex_l then {
          // 256-bit: 4 qwords, each selected by one imm8 bit
          let src1 : ymmword = read_ymm(pfx.vex_vvvv);
          let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          let r0 : qword = if imm[0] == bitone then src1[127..64] else src1[63..0];
          let r1 : qword = if imm[1] == bitone then src2[127..64] else src2[63..0];
          let r2 : qword = if imm[2] == bitone then src1[255..192] else src1[191..128];
          let r3 : qword = if imm[3] == bitone then src2[255..192] else src2[191..128];
          write_ymm(dst, r3 @ r2 @ r1 @ r0);
          Ok()
        } else {
          let src1 : xmmword = read_xmm(pfx.vex_vvvv);
          let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          let r0 : qword = if imm[0] == bitone then src1[127..64] else src1[63..0];
          let r1 : qword = if imm[1] == bitone then src2[127..64] else src2[63..0];
          write_xmm(dst, r1 @ r0);
          Ok()
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F E0: VPAVGB xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  224 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, vex_pavgb_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, vex_pavgb_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F E3: VPAVGW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  227 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, vex_pavgw_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, vex_pavgw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F E4: VPMULHUW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  228 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, vex_pmulhuw_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, vex_pmulhuw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F E5: VPMULHW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  229 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, vex_pmulhw_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, vex_pmulhw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F F5: VPMADDWD xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  245 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, vex_pmaddwd_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, vex_pmaddwd_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F 60: VPUNPCKLBW (66 prefix)
  96 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_punpcklbw_128(s1[255..128], s2[255..128]) @ vex_punpcklbw_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_punpcklbw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F 61: VPUNPCKLWD (66 prefix)
  97 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_punpcklwd_128(s1[255..128], s2[255..128]) @ vex_punpcklwd_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_punpcklwd_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F 62: VPUNPCKLDQ (66 prefix)
  98 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_punpckldq_128(s1[255..128], s2[255..128]) @ vex_punpckldq_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_punpckldq_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F 63: VPACKSSWB (66 prefix)
  99 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_packsswb_128(s1[255..128], s2[255..128]) @ vex_packsswb_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_packsswb_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F 64: VPCMPGTB (66 prefix)
  100 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_pcmpgtb_128(s1[255..128], s2[255..128]) @ vex_pcmpgtb_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_pcmpgtb_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F 65: VPCMPGTW (66 prefix)
  101 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_pcmpgtw_128(s1[255..128], s2[255..128]) @ vex_pcmpgtw_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_pcmpgtw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F 66: VPCMPGTD (66 prefix)
  102 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_pcmpgtd_128(s1[255..128], s2[255..128]) @ vex_pcmpgtd_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_pcmpgtd_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F 67: VPACKUSWB (66 prefix)
  103 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_packuswb_128(s1[255..128], s2[255..128]) @ vex_packuswb_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_packuswb_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F 68: VPUNPCKHBW (66 prefix)
  104 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_punpckhbw_128(s1[255..128], s2[255..128]) @ vex_punpckhbw_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_punpckhbw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F 69: VPUNPCKHWD (66 prefix)
  105 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_punpckhwd_128(s1[255..128], s2[255..128]) @ vex_punpckhwd_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_punpckhwd_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F 6A: VPUNPCKHDQ (66 prefix)
  106 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_punpckhdq_128(s1[255..128], s2[255..128]) @ vex_punpckhdq_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_punpckhdq_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F 6B: VPACKSSDW (66 prefix)
  107 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_packssdw_128(s1[255..128], s2[255..128]) @ vex_packssdw_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_packssdw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F 6C: VPUNPCKLQDQ (66 prefix)
  108 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_punpcklqdq_128(s1[255..128], s2[255..128]) @ vex_punpcklqdq_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_punpcklqdq_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F 6D: VPUNPCKHQDQ (66 prefix)
  109 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_punpckhqdq_128(s1[255..128], s2[255..128]) @ vex_punpckhqdq_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_punpckhqdq_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F 71: Group 12 — VPSRLW/VPSRAW/VPSLLW imm8 (66 prefix)
  // VEX: modrm.rm = src, vvvv = dst
  113 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let _ = decode_rm(modrm, pfx);
      let src_idx = modrm_xmm_rm(modrm, pfx);
      let dst = pfx.vex_vvvv;
      let imm = fetch_byte();
      let c : int = unsigned(imm);
      if pfx.vex_l then {
        let a : ymmword = read_ymm(src_idx);
        if reg_field == 2 then {
          write_ymm(dst, vex_psrlw_128(a[255..128], c) @ vex_psrlw_128(a[127..0], c)); Ok()
        } else if reg_field == 4 then {
          write_ymm(dst, vex_psraw_128(a[255..128], c) @ vex_psraw_128(a[127..0], c)); Ok()
        } else if reg_field == 6 then {
          write_ymm(dst, vex_psllw_128(a[255..128], c) @ vex_psllw_128(a[127..0], c)); Ok()
        } else raise_UD()
      } else {
        let a : xmmword = read_xmm(src_idx);
        if reg_field == 2 then {
          write_xmm(dst, vex_psrlw_128(a, c)); Ok()
        } else if reg_field == 4 then {
          write_xmm(dst, vex_psraw_128(a, c)); Ok()
        } else if reg_field == 6 then {
          write_xmm(dst, vex_psllw_128(a, c)); Ok()
        } else raise_UD()
      }
    }
  },

  // 0F 72: Group 13 — VPSRLD/VPSRAD/VPSLLD imm8 (66 prefix)
  114 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let _ = decode_rm(modrm, pfx);
      let src_idx = modrm_xmm_rm(modrm, pfx);
      let dst = pfx.vex_vvvv;
      let imm = fetch_byte();
      let c : int = unsigned(imm);
      if pfx.vex_l then {
        let a : ymmword = read_ymm(src_idx);
        if reg_field == 2 then {
          write_ymm(dst, vex_psrld_128(a[255..128], c) @ vex_psrld_128(a[127..0], c)); Ok()
        } else if reg_field == 4 then {
          write_ymm(dst, vex_psrad_128(a[255..128], c) @ vex_psrad_128(a[127..0], c)); Ok()
        } else if reg_field == 6 then {
          write_ymm(dst, vex_pslld_128(a[255..128], c) @ vex_pslld_128(a[127..0], c)); Ok()
        } else raise_UD()
      } else {
        let a : xmmword = read_xmm(src_idx);
        if reg_field == 2 then {
          write_xmm(dst, vex_psrld_128(a, c)); Ok()
        } else if reg_field == 4 then {
          write_xmm(dst, vex_psrad_128(a, c)); Ok()
        } else if reg_field == 6 then {
          write_xmm(dst, vex_pslld_128(a, c)); Ok()
        } else raise_UD()
      }
    }
  },

  // 0F 73: Group 14 — VPSRLQ/VPSRLDQ/VPSLLQ/VPSLLDQ imm8 (66 prefix)
  115 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let _ = decode_rm(modrm, pfx);
      let src_idx = modrm_xmm_rm(modrm, pfx);
      let dst = pfx.vex_vvvv;
      let imm = fetch_byte();
      let c : range(0, 255) = unsigned(imm);
      if pfx.vex_l then {
        let a : ymmword = read_ymm(src_idx);
        let lo : xmmword = a[127..0];
        let hi : xmmword = a[255..128];
        if reg_field == 2 then {
          // VPSRLQ
          let ci : int = c;
          write_ymm(dst, vex_psrlq_128(hi, ci) @ vex_psrlq_128(lo, ci)); Ok()
        } else if reg_field == 3 then {
          // VPSRLDQ: byte shift right per 128-bit lane
          let byte_count : range(0, 16) = if c > 15 then 16 else c;
          let shift : range(0, 128) = byte_count * 8;
          let rlo : xmmword = if shift > 127 then zeros() else lo >> shift;
          let rhi : xmmword = if shift > 127 then zeros() else hi >> shift;
          write_ymm(dst, rhi @ rlo); Ok()
        } else if reg_field == 6 then {
          // VPSLLQ
          let ci : int = c;
          write_ymm(dst, vex_psllq_128(hi, ci) @ vex_psllq_128(lo, ci)); Ok()
        } else if reg_field == 7 then {
          // VPSLLDQ: byte shift left per 128-bit lane
          let byte_count : range(0, 16) = if c > 15 then 16 else c;
          let shift : range(0, 128) = byte_count * 8;
          let rlo : xmmword = if shift > 127 then zeros() else lo << shift;
          let rhi : xmmword = if shift > 127 then zeros() else hi << shift;
          write_ymm(dst, rhi @ rlo); Ok()
        } else raise_UD()
      } else {
        let a : xmmword = read_xmm(src_idx);
        if reg_field == 2 then {
          write_xmm(dst, vex_psrlq_128(a, c)); Ok()
        } else if reg_field == 3 then {
          let byte_count : range(0, 16) = if c > 15 then 16 else c;
          let shift : range(0, 128) = byte_count * 8;
          let r : xmmword = if shift > 127 then zeros() else a >> shift;
          write_xmm(dst, r); Ok()
        } else if reg_field == 6 then {
          write_xmm(dst, vex_psllq_128(a, c)); Ok()
        } else if reg_field == 7 then {
          let byte_count : range(0, 16) = if c > 15 then 16 else c;
          let shift : range(0, 128) = byte_count * 8;
          let r : xmmword = if shift > 127 then zeros() else a << shift;
          write_xmm(dst, r); Ok()
        } else raise_UD()
      }
    }
  },

  // 0F 74: VPCMPEQB (66 prefix)
  116 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_pcmpeqb_128(s1[255..128], s2[255..128]) @ vex_pcmpeqb_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_pcmpeqb_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F 75: VPCMPEQW (66 prefix)
  117 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_pcmpeqw_128(s1[255..128], s2[255..128]) @ vex_pcmpeqw_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_pcmpeqw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F D1: VPSRLW xmm/ymm, xmm/ymm, xmm/m128 (66 prefix) — shift by xmm count
  209 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let cnt_xmm : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let c : int = unsigned(cnt_xmm[63..0]);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        write_ymm(dst, vex_psrlw_128(s1[255..128], c) @ vex_psrlw_128(s1[127..0], c));
        Ok()
      } else {
        write_xmm(dst, vex_psrlw_128(read_xmm(pfx.vex_vvvv), c));
        Ok()
      }
    }
  },

  // 0F D2: VPSRLD xmm/ymm, xmm/ymm, xmm/m128 (66 prefix)
  210 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let cnt_xmm : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let c : int = unsigned(cnt_xmm[63..0]);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        write_ymm(dst, vex_psrld_128(s1[255..128], c) @ vex_psrld_128(s1[127..0], c));
        Ok()
      } else {
        write_xmm(dst, vex_psrld_128(read_xmm(pfx.vex_vvvv), c));
        Ok()
      }
    }
  },

  // 0F D3: VPSRLQ xmm/ymm, xmm/ymm, xmm/m128 (66 prefix)
  211 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let cnt_xmm : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let c : int = unsigned(cnt_xmm[63..0]);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        write_ymm(dst, vex_psrlq_128(s1[255..128], c) @ vex_psrlq_128(s1[127..0], c));
        Ok()
      } else {
        write_xmm(dst, vex_psrlq_128(read_xmm(pfx.vex_vvvv), c));
        Ok()
      }
    }
  },

  // 0F D5: VPMULLW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  213 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, vex_pmullw_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, vex_pmullw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F D8: VPSUBUSB (66 prefix)
  216 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_psubusb_128(s1[255..128], s2[255..128]) @ vex_psubusb_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_psubusb_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F D9: VPSUBUSW (66 prefix)
  217 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_psubusw_128(s1[255..128], s2[255..128]) @ vex_psubusw_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_psubusw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F DA: VPMINUB (66 prefix)
  218 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_pminub_128(s1[255..128], s2[255..128]) @ vex_pminub_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_pminub_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F DC: VPADDUSB (66 prefix)
  220 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_paddusb_128(s1[255..128], s2[255..128]) @ vex_paddusb_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_paddusb_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F DD: VPADDUSW (66 prefix)
  221 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_paddusw_128(s1[255..128], s2[255..128]) @ vex_paddusw_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_paddusw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F DE: VPMAXUB (66 prefix)
  222 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_pmaxub_128(s1[255..128], s2[255..128]) @ vex_pmaxub_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_pmaxub_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F E1: VPSRAW xmm/ymm, xmm/ymm, xmm/m128 (66 prefix) — shift by xmm count
  225 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let cnt_xmm : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let c : int = unsigned(cnt_xmm[63..0]);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        write_ymm(dst, vex_psraw_128(s1[255..128], c) @ vex_psraw_128(s1[127..0], c));
        Ok()
      } else {
        write_xmm(dst, vex_psraw_128(read_xmm(pfx.vex_vvvv), c));
        Ok()
      }
    }
  },

  // 0F E2: VPSRAD xmm/ymm, xmm/ymm, xmm/m128 (66 prefix)
  226 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let cnt_xmm : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let c : int = unsigned(cnt_xmm[63..0]);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        write_ymm(dst, vex_psrad_128(s1[255..128], c) @ vex_psrad_128(s1[127..0], c));
        Ok()
      } else {
        write_xmm(dst, vex_psrad_128(read_xmm(pfx.vex_vvvv), c));
        Ok()
      }
    }
  },

  // 0F E8: VPSUBSB (66 prefix)
  232 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_psubsb_128(s1[255..128], s2[255..128]) @ vex_psubsb_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_psubsb_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F E9: VPSUBSW (66 prefix)
  233 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_psubsw_128(s1[255..128], s2[255..128]) @ vex_psubsw_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_psubsw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F EA: VPMINSW (66 prefix)
  234 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_pminsw_128(s1[255..128], s2[255..128]) @ vex_pminsw_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_pminsw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F EC: VPADDSB (66 prefix)
  236 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_paddsb_128(s1[255..128], s2[255..128]) @ vex_paddsb_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_paddsb_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F ED: VPADDSW (66 prefix)
  237 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        let s2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_paddsw_128(s1[255..128], s2[255..128]) @ vex_paddsw_128(s1[127..0], s2[127..0]));
        Ok()
      } else {
        write_xmm(dst, vex_paddsw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F F1: VPSLLW xmm/ymm, xmm/ymm, xmm/m128 (66 prefix) — shift by xmm count
  241 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let cnt_xmm : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let c : int = unsigned(cnt_xmm[63..0]);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        write_ymm(dst, vex_psllw_128(s1[255..128], c) @ vex_psllw_128(s1[127..0], c));
        Ok()
      } else {
        write_xmm(dst, vex_psllw_128(read_xmm(pfx.vex_vvvv), c));
        Ok()
      }
    }
  },

  // 0F F2: VPSLLD xmm/ymm, xmm/ymm, xmm/m128 (66 prefix)
  242 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let cnt_xmm : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let c : int = unsigned(cnt_xmm[63..0]);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        write_ymm(dst, vex_pslld_128(s1[255..128], c) @ vex_pslld_128(s1[127..0], c));
        Ok()
      } else {
        write_xmm(dst, vex_pslld_128(read_xmm(pfx.vex_vvvv), c));
        Ok()
      }
    }
  },

  // 0F F3: VPSLLQ xmm/ymm, xmm/ymm, xmm/m128 (66 prefix)
  243 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let cnt_xmm : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let c : int = unsigned(cnt_xmm[63..0]);
      if pfx.vex_l then {
        let s1 : ymmword = read_ymm(pfx.vex_vvvv);
        write_ymm(dst, vex_psllq_128(s1[255..128], c) @ vex_psllq_128(s1[127..0], c));
        Ok()
      } else {
        write_xmm(dst, vex_psllq_128(read_xmm(pfx.vex_vvvv), c));
        Ok()
      }
    }
  },

  // 0F F4: VPMULUDQ xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  244 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, vex_pmuludq_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, vex_pmuludq_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F F6: VPSADBW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  246 => {
    if mp != MP_66 then { raise_UD() } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, vex_psadbw_256(read_ymm(pfx.vex_vvvv), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, vex_psadbw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  _ => raise_UD(),
  }
}

// =========================================================================
// VEX 0F38 helpers — VTESTPS/PD, VMASKMOV, variable shifts, permute
// =========================================================================

// VMASKMOVPS load 128-bit: conditional load of dword lanes based on sign bit of mask
val vex_maskmovps_load_128 : (xmmword, xmmword) -> xmmword
function vex_maskmovps_load_128(mask, data) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 3) {
    if mask[(i * 32 + 31)] == bitone then
      result[(i * 32 + 31) .. (i * 32)] = data[(i * 32 + 31) .. (i * 32)]
  };
  result
}

val vex_maskmovps_load_256 : (ymmword, ymmword) -> ymmword
function vex_maskmovps_load_256(mask, data) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 7) {
    if mask[(i * 32 + 31)] == bitone then
      result[(i * 32 + 31) .. (i * 32)] = data[(i * 32 + 31) .. (i * 32)]
  };
  result
}

// VMASKMOVPD load 128-bit: conditional load of qword lanes based on sign bit of mask
val vex_maskmovpd_load_128 : (xmmword, xmmword) -> xmmword
function vex_maskmovpd_load_128(mask, data) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 1) {
    if mask[(i * 64 + 63)] == bitone then
      result[(i * 64 + 63) .. (i * 64)] = data[(i * 64 + 63) .. (i * 64)]
  };
  result
}

val vex_maskmovpd_load_256 : (ymmword, ymmword) -> ymmword
function vex_maskmovpd_load_256(mask, data) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 3) {
    if mask[(i * 64 + 63)] == bitone then
      result[(i * 64 + 63) .. (i * 64)] = data[(i * 64 + 63) .. (i * 64)]
  };
  result
}

// VMASKMOVPS store helpers: return (data_to_write, write_mask) pairs not needed;
// we write individual dwords/qwords conditionally in the dispatch code.

// VPERMPS/VPERMD 256-bit: permute 8 dwords using index vector
val vex_vpermd_256 : (ymmword, ymmword) -> ymmword
function vex_vpermd_256(ctrl, src) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 7) {
    let idx : range(0, 7) = unsigned(ctrl[(i * 32 + 2) .. (i * 32)]);
    foreach (j from 0 to 7) {
      if j == idx then
        result[(i * 32 + 31) .. (i * 32)] = src[(j * 32 + 31) .. (j * 32)]
    }
  };
  result
}

// VPSRLVD 128-bit: variable logical right shift, dword granularity
val vex_psrlvd_128 : (xmmword, xmmword) -> xmmword
function vex_psrlvd_128(data, shift) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 3) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 32 + 31) .. (i * 32)]);
    if count < 32 then
      result[(i * 32 + 31) .. (i * 32)] = sail_shiftright(data[(i * 32 + 31) .. (i * 32)], count)
  };
  result
}

val vex_psrlvd_256 : (ymmword, ymmword) -> ymmword
function vex_psrlvd_256(data, shift) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 7) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 32 + 31) .. (i * 32)]);
    if count < 32 then
      result[(i * 32 + 31) .. (i * 32)] = sail_shiftright(data[(i * 32 + 31) .. (i * 32)], count)
  };
  result
}

// VPSRLVQ 128-bit: variable logical right shift, qword granularity
val vex_psrlvq_128 : (xmmword, xmmword) -> xmmword
function vex_psrlvq_128(data, shift) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 1) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 64 + 31) .. (i * 64)]);
    if count < 64 then
      result[(i * 64 + 63) .. (i * 64)] = sail_shiftright(data[(i * 64 + 63) .. (i * 64)], count)
  };
  result
}

val vex_psrlvq_256 : (ymmword, ymmword) -> ymmword
function vex_psrlvq_256(data, shift) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 3) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 64 + 31) .. (i * 64)]);
    if count < 64 then
      result[(i * 64 + 63) .. (i * 64)] = sail_shiftright(data[(i * 64 + 63) .. (i * 64)], count)
  };
  result
}

// VPSRAVD 128-bit: variable arithmetic right shift, dword granularity
val vex_psravd_128 : (xmmword, xmmword) -> xmmword
function vex_psravd_128(data, shift) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 3) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 32 + 31) .. (i * 32)]);
    let elem : dword = data[(i * 32 + 31) .. (i * 32)];
    if count >= 32 then
      // Fill with sign bit
      result[(i * 32 + 31) .. (i * 32)] = sail_arith_shiftright(elem, 31)
    else
      result[(i * 32 + 31) .. (i * 32)] = sail_arith_shiftright(elem, count)
  };
  result
}

val vex_psravd_256 : (ymmword, ymmword) -> ymmword
function vex_psravd_256(data, shift) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 7) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 32 + 31) .. (i * 32)]);
    let elem : dword = data[(i * 32 + 31) .. (i * 32)];
    if count >= 32 then
      result[(i * 32 + 31) .. (i * 32)] = sail_arith_shiftright(elem, 31)
    else
      result[(i * 32 + 31) .. (i * 32)] = sail_arith_shiftright(elem, count)
  };
  result
}

// VPSLLVD 128-bit: variable logical left shift, dword granularity
val vex_psllvd_128 : (xmmword, xmmword) -> xmmword
function vex_psllvd_128(data, shift) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 3) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 32 + 31) .. (i * 32)]);
    if count < 32 then
      result[(i * 32 + 31) .. (i * 32)] = sail_shiftleft(data[(i * 32 + 31) .. (i * 32)], count)
  };
  result
}

val vex_psllvd_256 : (ymmword, ymmword) -> ymmword
function vex_psllvd_256(data, shift) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 7) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 32 + 31) .. (i * 32)]);
    if count < 32 then
      result[(i * 32 + 31) .. (i * 32)] = sail_shiftleft(data[(i * 32 + 31) .. (i * 32)], count)
  };
  result
}

// VPSLLVQ 128-bit: variable logical left shift, qword granularity
val vex_psllvq_128 : (xmmword, xmmword) -> xmmword
function vex_psllvq_128(data, shift) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 1) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 64 + 31) .. (i * 64)]);
    if count < 64 then
      result[(i * 64 + 63) .. (i * 64)] = sail_shiftleft(data[(i * 64 + 63) .. (i * 64)], count)
  };
  result
}

val vex_psllvq_256 : (ymmword, ymmword) -> ymmword
function vex_psllvq_256(data, shift) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 3) {
    let count : range(0, 4294967295) = unsigned(shift[(i * 64 + 31) .. (i * 64)]);
    if count < 64 then
      result[(i * 64 + 63) .. (i * 64)] = sail_shiftleft(data[(i * 64 + 63) .. (i * 64)], count)
  };
  result
}

// =========================================================================
// VEX 0F38 map dispatch
// =========================================================================

val dispatch_vex_0f38 : (byte, Prefixes) -> ExecutionResult
function dispatch_vex_0f38(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F38 00: VPSHUFB xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  0 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1_idx = pfx.vex_vvvv;
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(src1_idx);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_pshufb_256(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(src1_idx);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, vex_pshufb_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F38 01: VPHADDW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  1 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1_idx = pfx.vex_vvvv;
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(src1_idx);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_phaddw_256(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(src1_idx);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_phaddw_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F38 02: VPHADDD xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  2 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1_idx = pfx.vex_vvvv;
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(src1_idx);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_phaddd_256(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(src1_idx);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_phaddd_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F38 03: VPHADDSW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  3 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1_idx = pfx.vex_vvvv;
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(src1_idx);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_phaddsw_256(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(src1_idx);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_phaddsw_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F38 04: VPMADDUBSW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  4 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1_idx = pfx.vex_vvvv;
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(src1_idx);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_pmaddubsw_256(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(src1_idx);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, vex_pmaddubsw_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F38 05: VPHSUBW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  5 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1_idx = pfx.vex_vvvv;
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(src1_idx);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_phsubw_256(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(src1_idx);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_phsubw_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F38 06: VPHSUBD xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  6 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1_idx = pfx.vex_vvvv;
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(src1_idx);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_phsubd_256(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(src1_idx);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_phsubd_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F38 07: VPHSUBSW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  7 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1_idx = pfx.vex_vvvv;
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(src1_idx);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_phsubsw_256(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(src1_idx);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_phsubsw_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F38 08: VPSIGNB xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  8 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1_idx = pfx.vex_vvvv;
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(src1_idx);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_psignb_256(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(src1_idx);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_psignb_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F38 09: VPSIGNW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  9 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1_idx = pfx.vex_vvvv;
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(src1_idx);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_psignw_256(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(src1_idx);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_psignw_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F38 0A: VPSIGND xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  10 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1_idx = pfx.vex_vvvv;
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(src1_idx);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_psignd_256(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(src1_idx);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_psignd_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F38 0B: VPMULHRSW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  11 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1_idx = pfx.vex_vvvv;
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(src1_idx);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_pmulhrsw_256(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(src1_idx);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, vex_pmulhrsw_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F38 18: VBROADCASTSS xmm1, xmm2/m32 (VEX.128/256)
  // SDM: VEX.vvvv must be 1111b
  24 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let val32 : dword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
        RM_mem(addr) => mem_read32(fixup_addr(addr)),
      };
      if pfx.vex_l then {
        // 256-bit: broadcast to 8 dwords
        write_ymm(dst, val32 @ val32 @ val32 @ val32 @
                       val32 @ val32 @ val32 @ val32);
        Ok()
      } else {
        // 128-bit: broadcast to 4 dwords
        write_xmm(dst, val32 @ val32 @ val32 @ val32);
        Ok()
      }
    }
  },

  // 0F38 19: VBROADCASTSD ymm1, xmm2/m64 (VEX.256 only)
  // SDM: VEX.128 form #UDs, VEX.vvvv must be 1111b
  25 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else if not_bool(pfx.vex_l) then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let val64 : qword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(addr) => mem_read64(fixup_addr(addr)),
      };
      write_ymm(dst, val64 @ val64 @ val64 @ val64);
      Ok()
    }
  },

  // 0F38 1A: VBROADCASTF128 ymm1, m128 (VEX.256 only)
  // SDM: VEX.vvvv must be 1111b
  26 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else if not_bool(pfx.vex_l) then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_reg(_) => raise_UD(), // memory-only
        RM_mem(addr) => {
          let v : xmmword = mem_read128(fixup_addr(addr));
          write_ymm(dst, v @ v);
          Ok()
        },
      }
    }
  },

  // 0F38 78: VPBROADCASTB xmm/ymm, xmm/m8 (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  120 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let val8 : byte = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[7..0],
        RM_mem(addr) => mem_read8(fixup_addr(addr)),
      };
      if pfx.vex_l then {
        write_ymm(dst, val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @
                       val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @
                       val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @
                       val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8);
        Ok()
      } else {
        write_xmm(dst, val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @
                       val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8);
        Ok()
      }
    }
  },

  // 0F38 79: VPBROADCASTW xmm/ymm, xmm/m16 (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  121 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let val16 : word = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[15..0],
        RM_mem(addr) => mem_read16(fixup_addr(addr)),
      };
      if pfx.vex_l then {
        write_ymm(dst, val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16 @
                       val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16);
        Ok()
      } else {
        write_xmm(dst, val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16);
        Ok()
      }
    }
  },

  // 0F38 58: VPBROADCASTD xmm/ymm, xmm/m32 (66 prefix) — same as VBROADCASTSS but int
  // SDM: VEX.vvvv must be 1111b
  88 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let val32 : dword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
        RM_mem(addr) => mem_read32(fixup_addr(addr)),
      };
      if pfx.vex_l then {
        write_ymm(dst, val32 @ val32 @ val32 @ val32 @ val32 @ val32 @ val32 @ val32);
        Ok()
      } else {
        write_xmm(dst, val32 @ val32 @ val32 @ val32);
        Ok()
      }
    }
  },

  // 0F38 59: VPBROADCASTQ xmm/ymm, xmm/m64 (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  89 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let val64 : qword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(addr) => mem_read64(fixup_addr(addr)),
      };
      if pfx.vex_l then {
        write_ymm(dst, val64 @ val64 @ val64 @ val64);
        Ok()
      } else {
        write_xmm(dst, val64 @ val64);
        Ok()
      }
    }
  },

  // 0F38 13: VCVTPH2PS xmm/ymm, xmm/m64/m128 (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  19 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        // 256-bit: 8 FP16 -> 8 FP32
        let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_ymm(dst, avx_vcvtph2ps_256(src));
        Ok()
      } else {
        // 128-bit: 4 FP16 -> 4 FP32
        let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_vcvtph2ps_128(src[63..0]));
        Ok()
      }
    }
  },

  // 0F38 1C: VPABSB xmm/ymm, xmm/ymm/m (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  28 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_pabsb_256(src));
        Ok()
      } else {
        let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, vex_pabsb_128(src));
        Ok()
      }
    }
  },

  // 0F38 1D: VPABSW xmm/ymm, xmm/ymm/m (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  29 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_pabsw_256(src));
        Ok()
      } else {
        let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, vex_pabsw_128(src));
        Ok()
      }
    }
  },

  // 0F38 1E: VPABSD xmm/ymm, xmm/ymm/m (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  30 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, vex_pabsd_256(src));
        Ok()
      } else {
        let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, vex_pabsd_128(src));
        Ok()
      }
    }
  },

  // -----------------------------------------------------------------------
  // VEX FMA3 instructions (0F38 96..BF)
  //
  // All require 66 mandatory prefix.
  // W=0 selects PS/SS variants, W=1 selects PD/SD variants.
  // L=0 for 128-bit (or scalar), L=1 for 256-bit.
  //
  // Operand mapping (avx_fmadd(a,b,c) computes a*b+c):
  //   132: a=dst, b=rm,  c=vvvv
  //   213: a=vvvv, b=dst, c=rm
  //   231: a=vvvv, b=rm,  c=dst
  // -----------------------------------------------------------------------

  // 0F38 96: VFMADDSUB132PS (W0) / VFMADDSUB132PD (W1)
  150 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmaddsub_pd_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fmaddsub_pd_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmaddsub_ps_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fmaddsub_ps_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      }
    }
  },

  // 0F38 97: VFMSUBADD132PS (W0) / VFMSUBADD132PD (W1)
  151 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsubadd_pd_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fmsubadd_pd_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsubadd_ps_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fmsubadd_ps_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      }
    }
  },

  // 0F38 98: VFMADD132PS (W0) / VFMADD132PD (W1)
  152 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmadd_pd_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fmadd_pd_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmadd_ps_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fmadd_ps_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      }
    }
  },

  // 0F38 99: VFMADD132SS (W0) / VFMADD132SD (W1)
  153 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfmadd132sd(dst, src2, src3)
      } else {
        exec_vfmadd132ss(dst, src2, src3)
      }
    }
  },

  // 0F38 9A: VFMSUB132PS (W0) / VFMSUB132PD (W1)
  154 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsub_pd_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fmsub_pd_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsub_ps_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fmsub_ps_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      }
    }
  },

  // 0F38 9B: VFMSUB132SS (W0) / VFMSUB132SD (W1)
  155 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfmsub132sd(dst, src2, src3)
      } else {
        exec_vfmsub132ss(dst, src2, src3)
      }
    }
  },

  // 0F38 9C: VFNMADD132PS (W0) / VFNMADD132PD (W1)
  156 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmadd_pd_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fnmadd_pd_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmadd_ps_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fnmadd_ps_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      }
    }
  },

  // 0F38 9D: VFNMADD132SS (W0) / VFNMADD132SD (W1)
  157 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfnmadd132sd(dst, src2, src3)
      } else {
        exec_vfnmadd132ss(dst, src2, src3)
      }
    }
  },

  // 0F38 9E: VFNMSUB132PS (W0) / VFNMSUB132PD (W1)
  158 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmsub_pd_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fnmsub_pd_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmsub_ps_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fnmsub_ps_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      }
    }
  },

  // 0F38 9F: VFNMSUB132SS (W0) / VFNMSUB132SD (W1)
  159 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfnmsub132sd(dst, src2, src3)
      } else {
        exec_vfnmsub132ss(dst, src2, src3)
      }
    }
  },

  // 0F38 A6: VFMADDSUB213PS (W0) / VFMADDSUB213PD (W1)
  166 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmaddsub_pd_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fmaddsub_pd_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmaddsub_ps_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fmaddsub_ps_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      }
    }
  },

  // 0F38 A7: VFMSUBADD213PS (W0) / VFMSUBADD213PD (W1)
  167 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsubadd_pd_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fmsubadd_pd_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsubadd_ps_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fmsubadd_ps_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      }
    }
  },

  // 0F38 A8: VFMADD213PS (W0) / VFMADD213PD (W1)
  168 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmadd_pd_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fmadd_pd_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmadd_ps_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fmadd_ps_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      }
    }
  },

  // 0F38 A9: VFMADD213SS (W0) / VFMADD213SD (W1)
  169 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfmadd213sd(dst, src2, src3)
      } else {
        exec_vfmadd213ss(dst, src2, src3)
      }
    }
  },

  // 0F38 AA: VFMSUB213PS (W0) / VFMSUB213PD (W1)
  170 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsub_pd_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fmsub_pd_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsub_ps_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fmsub_ps_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      }
    }
  },

  // 0F38 AB: VFMSUB213SS (W0) / VFMSUB213SD (W1)
  171 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfmsub213sd(dst, src2, src3)
      } else {
        exec_vfmsub213ss(dst, src2, src3)
      }
    }
  },

  // 0F38 AC: VFNMADD213PS (W0) / VFNMADD213PD (W1)
  172 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmadd_pd_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fnmadd_pd_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmadd_ps_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fnmadd_ps_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      }
    }
  },

  // 0F38 AD: VFNMADD213SS (W0) / VFNMADD213SD (W1)
  173 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfnmadd213sd(dst, src2, src3)
      } else {
        exec_vfnmadd213ss(dst, src2, src3)
      }
    }
  },

  // 0F38 AE: VFNMSUB213PS (W0) / VFNMSUB213PD (W1)
  174 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmsub_pd_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fnmsub_pd_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmsub_ps_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fnmsub_ps_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      }
    }
  },

  // 0F38 AF: VFNMSUB213SS (W0) / VFNMSUB213SD (W1)
  175 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfnmsub213sd(dst, src2, src3)
      } else {
        exec_vfnmsub213ss(dst, src2, src3)
      }
    }
  },

  // 0F38 B6: VFMADDSUB231PS (W0) / VFMADDSUB231PD (W1)
  182 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmaddsub_pd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fmaddsub_pd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmaddsub_ps_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fmaddsub_ps_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      }
    }
  },

  // 0F38 B7: VFMSUBADD231PS (W0) / VFMSUBADD231PD (W1)
  183 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsubadd_pd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fmsubadd_pd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsubadd_ps_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fmsubadd_ps_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      }
    }
  },

  // 0F38 B8: VFMADD231PS (W0) / VFMADD231PD (W1)
  184 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmadd_pd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fmadd_pd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmadd_ps_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fmadd_ps_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      }
    }
  },

  // 0F38 B9: VFMADD231SS (W0) / VFMADD231SD (W1)
  185 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfmadd231sd(dst, src2, src3)
      } else {
        exec_vfmadd231ss(dst, src2, src3)
      }
    }
  },

  // 0F38 BA: VFMSUB231PS (W0) / VFMSUB231PD (W1)
  186 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsub_pd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fmsub_pd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsub_ps_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fmsub_ps_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      }
    }
  },

  // 0F38 BB: VFMSUB231SS (W0) / VFMSUB231SD (W1)
  187 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfmsub231sd(dst, src2, src3)
      } else {
        exec_vfmsub231ss(dst, src2, src3)
      }
    }
  },

  // 0F38 BC: VFNMADD231PS (W0) / VFNMADD231PD (W1)
  188 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmadd_pd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fnmadd_pd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmadd_ps_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fnmadd_ps_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      }
    }
  },

  // 0F38 BD: VFNMADD231SS (W0) / VFNMADD231SD (W1)
  189 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfnmadd231sd(dst, src2, src3)
      } else {
        exec_vfnmadd231ss(dst, src2, src3)
      }
    }
  },

  // 0F38 BE: VFNMSUB231PS (W0) / VFNMSUB231PD (W1)
  190 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmsub_pd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fnmsub_pd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmsub_ps_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fnmsub_ps_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      }
    }
  },

  // 0F38 BF: VFNMSUB231SS (W0) / VFNMSUB231SD (W1)
  191 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfnmsub231sd(dst, src2, src3)
      } else {
        exec_vfnmsub231ss(dst, src2, src3)
      }
    }
  },

  // 0F38 F2: ANDN (NP, VEX.NDS.LZ) — dest = ~vvvv & src
  242 => {
    if mp != MP_NONE then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let os : OperandSize = if pfx.vex_w then OS64 else OS32;
      let src = read_rm_val(rm, os, true);
      let v : gpr_idx = pfx.vex_vvvv % 16;
      let vval : qword = read_gpr(v, os);
      let result : qword = ~(vval) & src;
      write_gpr(dst, os, result);
      SF = bool_to_bit(if pfx.vex_w then result[63] == bitone else result[31] == bitone);
      ZF = bool_to_bit(if pfx.vex_w then result == zeros() else result[31..0] == zeros());
      OF = bitzero;
      CF = bitzero;
      Ok()
    }
  },

  // 0F38 F3: BLSI/BLSMSK/BLSR (NP, VEX.NDD.LZ) — selected by modrm /reg
  243 => {
    if mp != MP_NONE then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm(modrm, pfx);
      let os : OperandSize = if pfx.vex_w then OS64 else OS32;
      let src : qword = read_rm_val(rm, os, true);
      let dst : gpr_idx = pfx.vex_vvvv % 16;
      match reg_field {
        1 => {
          // BLSR: dest = (src - 1) & src
          let result : qword = (src - 1) & src;
          write_gpr(dst, os, result);
          SF = bool_to_bit(if pfx.vex_w then result[63] == bitone else result[31] == bitone);
          ZF = bool_to_bit(if pfx.vex_w then result == zeros() else result[31..0] == zeros());
          CF = bool_to_bit(if pfx.vex_w then src == zeros() else src[31..0] == zeros());
          OF = bitzero;
          Ok()
        },
        2 => {
          // BLSMSK: dest = (src - 1) ^ src
          let result : qword = (src - 1) ^ src;
          write_gpr(dst, os, result);
          SF = bool_to_bit(if pfx.vex_w then result[63] == bitone else result[31] == bitone);
          ZF = bitzero;
          CF = bool_to_bit(if pfx.vex_w then src == zeros() else src[31..0] == zeros());
          OF = bitzero;
          Ok()
        },
        3 => {
          // BLSI: dest = (-src) & src (isolate lowest set bit)
          let neg_src : qword = ~(src) + 1;
          let result : qword = neg_src & src;
          write_gpr(dst, os, result);
          SF = bool_to_bit(if pfx.vex_w then result[63] == bitone else result[31] == bitone);
          ZF = bool_to_bit(if pfx.vex_w then result == zeros() else result[31..0] == zeros());
          CF = bool_to_bit(if pfx.vex_w then src != zeros() else src[31..0] != zeros());
          OF = bitzero;
          Ok()
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F38 DB: VAESIMC — VEX.128.66.0F38.WIG DB
  219 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD()
    } else if pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      write_xmm(dst, __aesimc(src));
      Ok()
    }
  },

  // 0F38 DC: VAESENC — VEX.128.66.0F38.WIG DC
  220 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let state : xmmword = read_xmm(pfx.vex_vvvv);
      let roundkey : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      write_xmm(dst, __aesenc(state, roundkey));
      Ok()
    }
  },

  // 0F38 DD: VAESENCLAST — VEX.128.66.0F38.WIG DD
  221 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let state : xmmword = read_xmm(pfx.vex_vvvv);
      let roundkey : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      write_xmm(dst, __aesenclast(state, roundkey));
      Ok()
    }
  },

  // 0F38 DE: VAESDEC — VEX.128.66.0F38.WIG DE
  222 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let state : xmmword = read_xmm(pfx.vex_vvvv);
      let roundkey : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      write_xmm(dst, __aesdec(state, roundkey));
      Ok()
    }
  },

  // 0F38 DF: VAESDECLAST — VEX.128.66.0F38.WIG DF
  223 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let state : xmmword = read_xmm(pfx.vex_vvvv);
      let roundkey : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      write_xmm(dst, __aesdeclast(state, roundkey));
      Ok()
    }
  },

  // 0F38 F5: BZHI (NP) / PDEP (F2) / PEXT (F3) — multiplexed by mandatory prefix
  245 => {
    let modrm = fetch_byte();
    let dst = modrm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let os : OperandSize = if pfx.vex_w then OS64 else OS32;
    let os_bits : {32, 64} = if pfx.vex_w then 64 else 32;
    match mp {
      MP_NONE => {
        // BZHI: VEX.NDS.LZ.0F38.W0/W1 F5
        // dest = src1 & ((1 << src2[7:0]) - 1), if index < operand size
        let src1 : qword = read_rm_val(rm, os, true);
        let v : gpr_idx = pfx.vex_vvvv % 16;
        let src2 : qword = read_gpr(v, os);
        let index : range(0, 255) = unsigned(src2[7..0]);
        var result : qword = zeros();
        if index >= os_bits then {
          result = src1;
          CF = bitone
        } else {
          let shift_amt : range(0, 255) = 64 - index;
          result = (src1 << shift_amt) >> shift_amt;
          CF = bitzero
        };
        write_gpr(dst, os, result);
        SF = bool_to_bit(if pfx.vex_w then result[63] == bitone else result[31] == bitone);
        ZF = bool_to_bit(if pfx.vex_w then result == zeros() else result[31..0] == zeros());
        OF = bitzero;
        Ok()
      },
      MP_F2 => {
        // PDEP: VEX.NDS.LZ.F2.0F38.W0/W1 F5
        // Parallel bit deposit: scatter contiguous low bits of src to mask positions
        let src : qword = read_gpr(pfx.vex_vvvv % 16, os);
        let mask : qword = read_rm_val(rm, os, true);
        var temp : qword = zeros();
        var k : range(0, 63) = 0;
        foreach (i from 0 to 63) {
          if mask[i] == bitone then {
            temp[i] = src[k];
            k = (k + 1) % 64
          }
        };
        write_gpr(dst, os, temp);
        Ok()
      },
      MP_F3 => {
        // PEXT: VEX.NDS.LZ.F3.0F38.W0/W1 F5
        // Parallel bit extract: gather bits at mask positions to contiguous low bits
        let src : qword = read_gpr(pfx.vex_vvvv % 16, os);
        let mask : qword = read_rm_val(rm, os, true);
        var temp : qword = zeros();
        var k : range(0, 63) = 0;
        foreach (i from 0 to 63) {
          if mask[i] == bitone then {
            temp[k] = src[i];
            k = (k + 1) % 64
          }
        };
        write_gpr(dst, os, temp);
        Ok()
      },
      _ => raise_UD(),
    }
  },

  // 0F38 F6: MULX (F2, VEX.NDD.LZ) — unsigned multiply without affecting flags
  246 => {
    if mp != MP_F2 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst_hi = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let os : OperandSize = if pfx.vex_w then OS64 else OS32;
      let dst_lo : gpr_idx = pfx.vex_vvvv % 16;
      // Implicit source is EDX/RDX
      let src1 : qword = read_gpr(2, os);   // RDX = GPR index 2
      let src2 : qword = read_rm_val(rm, os, true);
      if pfx.vex_w then {
        // 64-bit multiply -> 128-bit result
        let product : bits(128) = to_bits(128, unsigned(src1[63..0]) * unsigned(src2[63..0]));
        write_gpr(dst_lo, OS64, zero_extend(product[63..0]));
        write_gpr(dst_hi, OS64, zero_extend(product[127..64]));
      } else {
        // 32-bit multiply -> 64-bit result
        let product : bits(64) = to_bits(64, unsigned(src1[31..0]) * unsigned(src2[31..0]));
        write_gpr(dst_lo, OS32, zero_extend(product[31..0]));
        write_gpr(dst_hi, OS32, zero_extend(product[63..32]));
      };
      Ok()
    }
  },

  // 0F38 F7: BEXTR (NP) / SARX (F3) / SHLX (66) / SHRX (F2) — multiplexed by prefix
  247 => {
    let modrm = fetch_byte();
    let dst = modrm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let os : OperandSize = if pfx.vex_w then OS64 else OS32;
    match mp {
      MP_NONE => {
        // BEXTR: VEX.NDS.LZ.0F38 F7 — bit field extract
        let src : qword = read_rm_val(rm, os, true);
        let v : gpr_idx = pfx.vex_vvvv % 16;
        let ctrl : qword = read_gpr(v, os);
        let start : range(0, 255) = unsigned(ctrl[7..0]);
        let len : range(0, 255) = unsigned(ctrl[15..8]);
        let os_bits : {32, 64} = if pfx.vex_w then 64 else 32;
        var result : qword = zeros();
        if start < os_bits then {
          let shifted : qword = src >> start;
          if len >= os_bits then {
            result = shifted
          } else {
            // Create mask with len low bits set
            let shift_amt : range(0, 255) = 64 - len;
            result = (shifted << shift_amt) >> shift_amt
          }
        };
        write_gpr(dst, os, result);
        ZF = bool_to_bit(if pfx.vex_w then result == zeros() else result[31..0] == zeros());
        OF = bitzero;
        CF = bitzero;
        Ok()
      },
      MP_F3 => {
        // SARX: VEX.NDS.LZ.F3.0F38.W0/W1 F7 — arithmetic right shift, no flags
        let src1 : qword = read_rm_val(rm, os, true);
        let v : gpr_idx = pfx.vex_vvvv % 16;
        let count_val : qword = read_gpr(v, os);
        if pfx.vex_w then {
          let count : range(0, 63) = unsigned(count_val[5..0]);
          let result : bits(64) = sail_arith_shiftright(src1[63..0], count);
          write_gpr(dst, OS64, zero_extend(result));
        } else {
          let count : range(0, 31) = unsigned(count_val[4..0]);
          let result : bits(32) = sail_arith_shiftright(src1[31..0], count);
          write_gpr(dst, OS32, zero_extend(result));
        };
        Ok()
      },
      MP_66 => {
        // SHLX: VEX.NDS.LZ.66.0F38.W0/W1 F7 — logical left shift, no flags
        let src1 : qword = read_rm_val(rm, os, true);
        let v : gpr_idx = pfx.vex_vvvv % 16;
        let count_val : qword = read_gpr(v, os);
        let count : range(0, 63) = if pfx.vex_w then unsigned(count_val[5..0])
                                    else unsigned(count_val[4..0]);
        let result : qword = src1 << count;
        write_gpr(dst, os, result);
        Ok()
      },
      MP_F2 => {
        // SHRX: VEX.NDS.LZ.F2.0F38.W0/W1 F7 — logical right shift, no flags
        let src1 : qword = read_rm_val(rm, os, true);
        let v : gpr_idx = pfx.vex_vvvv % 16;
        let count_val : qword = read_gpr(v, os);
        let count : range(0, 63) = if pfx.vex_w then unsigned(count_val[5..0])
                                    else unsigned(count_val[4..0]);
        let result : qword = src1 >> count;
        write_gpr(dst, os, result);
        Ok()
      },
    }
  },

  // -----------------------------------------------------------------------
  // SSE4.1 sign/zero-extend, arithmetic, min/max (0F38 20..41)
  // -----------------------------------------------------------------------

  // 0F38 20: VPMOVSXBW (66 prefix, vvvv must be 1111b)
  // 128-bit: sign-extend 8 bytes (low qword) to 8 words
  // 256-bit: sign-extend 16 bytes (full xmm) to 16 words
  32 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_ymm(dst, avx_pmovsxbw_256(src));
        Ok()
      } else {
        let src : qword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_xmm(dst, avx_pmovsxbw_128(src));
        Ok()
      }
    }
  },

  // 0F38 21: VPMOVSXBD (66 prefix, vvvv must be 1111b)
  // 128-bit: sign-extend 4 bytes (32 bits) to 4 dwords
  // 256-bit: sign-extend 8 bytes (64 bits) to 8 dwords
  33 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : qword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_ymm(dst, avx_pmovsxbd_256(src));
        Ok()
      } else {
        let src : dword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        write_xmm(dst, avx_pmovsxbd_128(src));
        Ok()
      }
    }
  },

  // 0F38 22: VPMOVSXBQ (66 prefix, vvvv must be 1111b)
  // 128-bit: sign-extend 2 bytes (16 bits) to 2 qwords
  // 256-bit: sign-extend 4 bytes (32 bits) to 4 qwords
  34 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : dword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        write_ymm(dst, avx_pmovsxbq_256(src));
        Ok()
      } else {
        let src : word = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[15..0],
          RM_mem(addr) => mem_read16(fixup_addr(addr)),
        };
        write_xmm(dst, avx_pmovsxbq_128(src));
        Ok()
      }
    }
  },

  // 0F38 23: VPMOVSXWD (66 prefix, vvvv must be 1111b)
  // 128-bit: sign-extend 4 words (64 bits) to 4 dwords
  // 256-bit: sign-extend 8 words (128 bits) to 8 dwords
  35 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_ymm(dst, avx_pmovsxwd_256(src));
        Ok()
      } else {
        let src : qword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_xmm(dst, avx_pmovsxwd_128(src));
        Ok()
      }
    }
  },

  // 0F38 24: VPMOVSXWQ (66 prefix, vvvv must be 1111b)
  // 128-bit: sign-extend 2 words (32 bits) to 2 qwords
  // 256-bit: sign-extend 4 words (64 bits) to 4 qwords
  36 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : qword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_ymm(dst, avx_pmovsxwq_256(src));
        Ok()
      } else {
        let src : dword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        write_xmm(dst, avx_pmovsxwq_128(src));
        Ok()
      }
    }
  },

  // 0F38 25: VPMOVSXDQ (66 prefix, vvvv must be 1111b)
  // 128-bit: sign-extend 2 dwords (64 bits) to 2 qwords
  // 256-bit: sign-extend 4 dwords (128 bits) to 4 qwords
  37 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_ymm(dst, avx_pmovsxdq_256(src));
        Ok()
      } else {
        let src : qword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_xmm(dst, avx_pmovsxdq_128(src));
        Ok()
      }
    }
  },

  // 0F38 28: VPMULDQ (66 prefix)
  // Multiply signed dwords at positions 0 and 2 producing qword results
  40 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_l then {
        write_ymm(dst, avx_pmuldq_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, avx_pmuldq_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F38 29: VPCMPEQQ (66 prefix)
  // Compare packed qwords for equality; result is all 1s or all 0s per lane
  41 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_l then {
        write_ymm(dst, avx_pcmpeqq_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, avx_pcmpeqq_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F38 2A: VMOVNTDQA (66 prefix, vvvv must be 1111b)
  // Non-temporal aligned load; memory-only source
  42 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_reg(_) => raise_UD(), // memory-only
        RM_mem(addr) => {
          if pfx.vex_l then {
            write_ymm(dst, mem_read256(fixup_addr(addr)));
            Ok()
          } else {
            write_xmm(dst, mem_read128(fixup_addr(addr)));
            Ok()
          }
        },
      }
    }
  },

  // 0F38 2B: VPACKUSDW (66 prefix)
  // Pack dwords to words with unsigned saturation
  43 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_l then {
        write_ymm(dst, avx_packusdw_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, avx_packusdw_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F38 30: VPMOVZXBW (66 prefix, vvvv must be 1111b)
  // 128-bit: zero-extend 8 bytes (64 bits) to 8 words
  // 256-bit: zero-extend 16 bytes (128 bits) to 16 words
  48 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_ymm(dst, avx_pmovzxbw_256(src));
        Ok()
      } else {
        let src : qword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_xmm(dst, avx_pmovzxbw_128(src));
        Ok()
      }
    }
  },

  // 0F38 31: VPMOVZXBD (66 prefix, vvvv must be 1111b)
  // 128-bit: zero-extend 4 bytes (32 bits) to 4 dwords
  // 256-bit: zero-extend 8 bytes (64 bits) to 8 dwords
  49 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : qword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_ymm(dst, avx_pmovzxbd_256(src));
        Ok()
      } else {
        let src : dword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        write_xmm(dst, avx_pmovzxbd_128(src));
        Ok()
      }
    }
  },

  // 0F38 32: VPMOVZXBQ (66 prefix, vvvv must be 1111b)
  // 128-bit: zero-extend 2 bytes (16 bits) to 2 qwords
  // 256-bit: zero-extend 4 bytes (32 bits) to 4 qwords
  50 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : dword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        write_ymm(dst, avx_pmovzxbq_256(src));
        Ok()
      } else {
        let src : word = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[15..0],
          RM_mem(addr) => mem_read16(fixup_addr(addr)),
        };
        write_xmm(dst, avx_pmovzxbq_128(src));
        Ok()
      }
    }
  },

  // 0F38 33: VPMOVZXWD (66 prefix, vvvv must be 1111b)
  // 128-bit: zero-extend 4 words (64 bits) to 4 dwords
  // 256-bit: zero-extend 8 words (128 bits) to 8 dwords
  51 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_ymm(dst, avx_pmovzxwd_256(src));
        Ok()
      } else {
        let src : qword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_xmm(dst, avx_pmovzxwd_128(src));
        Ok()
      }
    }
  },

  // 0F38 34: VPMOVZXWQ (66 prefix, vvvv must be 1111b)
  // 128-bit: zero-extend 2 words (32 bits) to 2 qwords
  // 256-bit: zero-extend 4 words (64 bits) to 4 qwords
  52 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : qword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_ymm(dst, avx_pmovzxwq_256(src));
        Ok()
      } else {
        let src : dword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        write_xmm(dst, avx_pmovzxwq_128(src));
        Ok()
      }
    }
  },

  // 0F38 35: VPMOVZXDQ (66 prefix, vvvv must be 1111b)
  // 128-bit: zero-extend 2 dwords (64 bits) to 2 qwords
  // 256-bit: zero-extend 4 dwords (128 bits) to 4 qwords
  53 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_ymm(dst, avx_pmovzxdq_256(src));
        Ok()
      } else {
        let src : qword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_xmm(dst, avx_pmovzxdq_128(src));
        Ok()
      }
    }
  },

  // 0F38 38: VPMINSB (66 prefix)
  // Packed minimum of signed bytes
  56 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_l then {
        write_ymm(dst, avx_pminsb_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, avx_pminsb_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F38 39: VPMINSD (66 prefix)
  // Packed minimum of signed dwords
  57 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_l then {
        write_ymm(dst, avx_pminsd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, avx_pminsd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F38 3A: VPMINUW (66 prefix)
  // Packed minimum of unsigned words
  58 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_l then {
        write_ymm(dst, avx_pminuw_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, avx_pminuw_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F38 3B: VPMINUD (66 prefix)
  // Packed minimum of unsigned dwords
  59 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_l then {
        write_ymm(dst, avx_pminud_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, avx_pminud_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F38 3C: VPMAXSB (66 prefix)
  // Packed maximum of signed bytes
  60 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_l then {
        write_ymm(dst, avx_pmaxsb_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, avx_pmaxsb_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F38 3D: VPMAXSD (66 prefix)
  // Packed maximum of signed dwords
  61 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_l then {
        write_ymm(dst, avx_pmaxsd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, avx_pmaxsd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F38 3E: VPMAXUW (66 prefix)
  // Packed maximum of unsigned words
  62 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_l then {
        write_ymm(dst, avx_maxuw_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, avx_maxuw_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F38 3F: VPMAXUD (66 prefix)
  // Packed maximum of unsigned dwords
  63 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_l then {
        write_ymm(dst, avx_pmaxud_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, avx_pmaxud_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F38 40: VPMULLD (66 prefix)
  // Multiply packed dword integers, store low 32 bits of each result
  64 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_l then {
        write_ymm(dst, avx_pmulld_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, avx_pmulld_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F38 41: VPHMINPOSUW (66 prefix, VEX.128 only, vvvv must be 1111b)
  // Packed horizontal minimum of unsigned words
  65 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD() // VEX.128 only
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      write_xmm(dst, avx_phminposuw_128(src));
      Ok()
    }
  },

  // 0F38 0E: VTESTPS xmm, xmm/m128 or ymm, ymm/m256 (VEX.128/256.66.0F38.W0)
  // SDM: VEX.vvvv must be 1111b
  // Sets ZF if AND(src1, src2) == 0; sets CF if AND(NOT src1, src2) == 0
  // Clears OF, AF, PF, SF
  14 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 | pfx.vex_w then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let src1_idx = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(src1_idx);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        let tmp1 : ymmword = src1 & src2;
        let tmp2 : ymmword = not_vec(src1) & src2;
        ZF = if tmp1 == zeros() then bitone else bitzero;
        CF = if tmp2 == zeros() then bitone else bitzero;
        OF = bitzero; AF = bitzero; PF = bitzero; SF = bitzero;
        Ok()
      } else {
        let src1 : xmmword = read_xmm(src1_idx);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        let tmp1 : xmmword = src1 & src2;
        let tmp2 : xmmword = not_vec(src1) & src2;
        ZF = if tmp1 == zeros() then bitone else bitzero;
        CF = if tmp2 == zeros() then bitone else bitzero;
        OF = bitzero; AF = bitzero; PF = bitzero; SF = bitzero;
        Ok()
      }
    }
  },

  // 0F38 0F: VTESTPD xmm, xmm/m128 or ymm, ymm/m256 (VEX.128/256.66.0F38.W0)
  // SDM: VEX.vvvv must be 1111b
  // Same logic as VTESTPS but for packed doubles (bit-level identical)
  15 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 | pfx.vex_w then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let src1_idx = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(src1_idx);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        let tmp1 : ymmword = src1 & src2;
        let tmp2 : ymmword = not_vec(src1) & src2;
        ZF = if tmp1 == zeros() then bitone else bitzero;
        CF = if tmp2 == zeros() then bitone else bitzero;
        OF = bitzero; AF = bitzero; PF = bitzero; SF = bitzero;
        Ok()
      } else {
        let src1 : xmmword = read_xmm(src1_idx);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        let tmp1 : xmmword = src1 & src2;
        let tmp2 : xmmword = not_vec(src1) & src2;
        ZF = if tmp1 == zeros() then bitone else bitzero;
        CF = if tmp2 == zeros() then bitone else bitzero;
        OF = bitzero; AF = bitzero; PF = bitzero; SF = bitzero;
        Ok()
      }
    }
  },

  // 0F38 16: VPERMPS ymm, ymm, ymm/m256 (VEX.256.66.0F38.W0)
  // VEX.256 only; L=0 → #UD
  22 => {
    if mp != MP_66 | pfx.vex_w then {
      raise_UD()
    } else if not_bool(pfx.vex_l) then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let ctrl : ymmword = read_ymm(pfx.vex_vvvv);
      let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_vpermd_256(ctrl, src));
      Ok()
    }
  },

  // 0F38 2C: VMASKMOVPS load xmm1, xmm2, m128 (VEX.128/256.66.0F38.W0)
  // dst = modrm_reg, mask = vvvv, src = memory (RM_reg → #UD)
  44 => {
    if mp != MP_66 | pfx.vex_w then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_reg(_) => raise_UD(),
        RM_mem(addr) => {
          let a = fixup_addr(addr);
          if pfx.vex_l then {
            let mask : ymmword = read_ymm(pfx.vex_vvvv);
            let data : ymmword = mem_read256(a);
            write_ymm(dst, vex_maskmovps_load_256(mask, data));
            Ok()
          } else {
            let mask : xmmword = read_xmm(pfx.vex_vvvv);
            let data : xmmword = mem_read128(a);
            write_xmm(dst, vex_maskmovps_load_128(mask, data));
            Ok()
          }
        },
      }
    }
  },

  // 0F38 2D: VMASKMOVPD load xmm1, xmm2, m128 (VEX.128/256.66.0F38.W0)
  // dst = modrm_reg, mask = vvvv, src = memory (RM_reg → #UD)
  45 => {
    if mp != MP_66 | pfx.vex_w then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_reg(_) => raise_UD(),
        RM_mem(addr) => {
          let a = fixup_addr(addr);
          if pfx.vex_l then {
            let mask : ymmword = read_ymm(pfx.vex_vvvv);
            let data : ymmword = mem_read256(a);
            write_ymm(dst, vex_maskmovpd_load_256(mask, data));
            Ok()
          } else {
            let mask : xmmword = read_xmm(pfx.vex_vvvv);
            let data : xmmword = mem_read128(a);
            write_xmm(dst, vex_maskmovpd_load_128(mask, data));
            Ok()
          }
        },
      }
    }
  },

  // 0F38 2E: VMASKMOVPS store m128, xmm2, xmm1 (VEX.128/256.66.0F38.W0)
  // src = modrm_reg, mask = vvvv, dst = memory (RM_reg → #UD)
  46 => {
    if mp != MP_66 | pfx.vex_w then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let src_idx = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_reg(_) => raise_UD(),
        RM_mem(addr) => {
          let a = fixup_addr(addr);
          if pfx.vex_l then {
            let mask : ymmword = read_ymm(pfx.vex_vvvv);
            let src : ymmword = read_ymm(src_idx);
            foreach (i from 0 to 7) {
              if mask[(i * 32 + 31)] == bitone then
                mem_write32(a + zero_extend(to_bits(64, i * 4)), src[(i * 32 + 31) .. (i * 32)])
            };
            Ok()
          } else {
            let mask : xmmword = read_xmm(pfx.vex_vvvv);
            let src : xmmword = read_xmm(src_idx);
            foreach (i from 0 to 3) {
              if mask[(i * 32 + 31)] == bitone then
                mem_write32(a + zero_extend(to_bits(64, i * 4)), src[(i * 32 + 31) .. (i * 32)])
            };
            Ok()
          }
        },
      }
    }
  },

  // 0F38 2F: VMASKMOVPD store m128, xmm2, xmm1 (VEX.128/256.66.0F38.W0)
  // src = modrm_reg, mask = vvvv, dst = memory (RM_reg → #UD)
  47 => {
    if mp != MP_66 | pfx.vex_w then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let src_idx = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_reg(_) => raise_UD(),
        RM_mem(addr) => {
          let a = fixup_addr(addr);
          if pfx.vex_l then {
            let mask : ymmword = read_ymm(pfx.vex_vvvv);
            let src : ymmword = read_ymm(src_idx);
            foreach (i from 0 to 3) {
              if mask[(i * 64 + 63)] == bitone then
                mem_write64(a + zero_extend(to_bits(64, i * 8)), src[(i * 64 + 63) .. (i * 64)])
            };
            Ok()
          } else {
            let mask : xmmword = read_xmm(pfx.vex_vvvv);
            let src : xmmword = read_xmm(src_idx);
            foreach (i from 0 to 1) {
              if mask[(i * 64 + 63)] == bitone then
                mem_write64(a + zero_extend(to_bits(64, i * 8)), src[(i * 64 + 63) .. (i * 64)])
            };
            Ok()
          }
        },
      }
    }
  },

  // 0F38 36: VPERMD ymm1, ymm2, ymm3/m256 (VEX.256.66.0F38.W0)
  // VEX.256 only; L=0 → #UD
  54 => {
    if mp != MP_66 | pfx.vex_w then {
      raise_UD()
    } else if not_bool(pfx.vex_l) then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let ctrl : ymmword = read_ymm(pfx.vex_vvvv);
      let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      write_ymm(dst, vex_vpermd_256(ctrl, src));
      Ok()
    }
  },

  // 0F38 45: VPSRLVD (W0) / VPSRLVQ (W1) (VEX.128/256.66.0F38)
  // Variable logical right shift per element
  69 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        // VPSRLVQ
        if pfx.vex_l then {
          write_ymm(dst, vex_psrlvq_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx)));
          Ok()
        } else {
          write_xmm(dst, vex_psrlvq_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx)));
          Ok()
        }
      } else {
        // VPSRLVD
        if pfx.vex_l then {
          write_ymm(dst, vex_psrlvd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx)));
          Ok()
        } else {
          write_xmm(dst, vex_psrlvd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx)));
          Ok()
        }
      }
    }
  },

  // 0F38 46: VPSRAVD (VEX.128/256.66.0F38.W0)
  // Variable arithmetic right shift, dword only (no qword form in AVX2)
  70 => {
    if mp != MP_66 | pfx.vex_w then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_l then {
        write_ymm(dst, vex_psravd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx)));
        Ok()
      } else {
        write_xmm(dst, vex_psravd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F38 47: VPSLLVD (W0) / VPSLLVQ (W1) (VEX.128/256.66.0F38)
  // Variable logical left shift per element
  71 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        // VPSLLVQ
        if pfx.vex_l then {
          write_ymm(dst, vex_psllvq_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx)));
          Ok()
        } else {
          write_xmm(dst, vex_psllvq_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx)));
          Ok()
        }
      } else {
        // VPSLLVD
        if pfx.vex_l then {
          write_ymm(dst, vex_psllvd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx)));
          Ok()
        } else {
          write_xmm(dst, vex_psllvd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx)));
          Ok()
        }
      }
    }
  },

  _ => raise_UD(),
  }
}

// =========================================================================
// VEX 0F3A helpers — blend, palignr, round, dpps/dppd, permute
// =========================================================================

// VBLENDPS 128-bit: for each dword i, select from src1 or src2 based on imm8[i]
val avx_blendps_128 : (xmmword, xmmword, byte) -> xmmword
function avx_blendps_128(src1, src2, imm) = {
  let d0 : dword = if imm[0] == bitone then src2[31..0]    else src1[31..0];
  let d1 : dword = if imm[1] == bitone then src2[63..32]   else src1[63..32];
  let d2 : dword = if imm[2] == bitone then src2[95..64]   else src1[95..64];
  let d3 : dword = if imm[3] == bitone then src2[127..96]  else src1[127..96];
  d3 @ d2 @ d1 @ d0
}

val avx_blendps_256 : (ymmword, ymmword, byte) -> ymmword
function avx_blendps_256(src1, src2, imm) = {
  let d0 : dword = if imm[0] == bitone then src2[31..0]    else src1[31..0];
  let d1 : dword = if imm[1] == bitone then src2[63..32]   else src1[63..32];
  let d2 : dword = if imm[2] == bitone then src2[95..64]   else src1[95..64];
  let d3 : dword = if imm[3] == bitone then src2[127..96]  else src1[127..96];
  let d4 : dword = if imm[4] == bitone then src2[159..128] else src1[159..128];
  let d5 : dword = if imm[5] == bitone then src2[191..160] else src1[191..160];
  let d6 : dword = if imm[6] == bitone then src2[223..192] else src1[223..192];
  let d7 : dword = if imm[7] == bitone then src2[255..224] else src1[255..224];
  d7 @ d6 @ d5 @ d4 @ d3 @ d2 @ d1 @ d0
}

// VBLENDPD 128-bit: for each qword i, select based on imm8[i]
val avx_blendpd_128 : (xmmword, xmmword, byte) -> xmmword
function avx_blendpd_128(src1, src2, imm) = {
  let lo : qword = if imm[0] == bitone then src2[63..0]   else src1[63..0];
  let hi : qword = if imm[1] == bitone then src2[127..64] else src1[127..64];
  hi @ lo
}

val avx_blendpd_256 : (ymmword, ymmword, byte) -> ymmword
function avx_blendpd_256(src1, src2, imm) = {
  let q0 : qword = if imm[0] == bitone then src2[63..0]    else src1[63..0];
  let q1 : qword = if imm[1] == bitone then src2[127..64]  else src1[127..64];
  let q2 : qword = if imm[2] == bitone then src2[191..128] else src1[191..128];
  let q3 : qword = if imm[3] == bitone then src2[255..192] else src1[255..192];
  q3 @ q2 @ q1 @ q0
}

// VPBLENDW 128-bit: for each word i, select based on imm8[i]
val avx_pblendw_128 : (xmmword, xmmword, byte) -> xmmword
function avx_pblendw_128(src1, src2, imm) = {
  let w0 : word = if imm[0] == bitone then src2[15..0]    else src1[15..0];
  let w1 : word = if imm[1] == bitone then src2[31..16]   else src1[31..16];
  let w2 : word = if imm[2] == bitone then src2[47..32]   else src1[47..32];
  let w3 : word = if imm[3] == bitone then src2[63..48]   else src1[63..48];
  let w4 : word = if imm[4] == bitone then src2[79..64]   else src1[79..64];
  let w5 : word = if imm[5] == bitone then src2[95..80]   else src1[95..80];
  let w6 : word = if imm[6] == bitone then src2[111..96]  else src1[111..96];
  let w7 : word = if imm[7] == bitone then src2[127..112] else src1[127..112];
  w7 @ w6 @ w5 @ w4 @ w3 @ w2 @ w1 @ w0
}

// VPBLENDD 128-bit: for each dword i, select based on imm8[i]
val avx_pblendd_128 : (xmmword, xmmword, byte) -> xmmword
function avx_pblendd_128(src1, src2, imm) = {
  let d0 : dword = if imm[0] == bitone then src2[31..0]   else src1[31..0];
  let d1 : dword = if imm[1] == bitone then src2[63..32]  else src1[63..32];
  let d2 : dword = if imm[2] == bitone then src2[95..64]  else src1[95..64];
  let d3 : dword = if imm[3] == bitone then src2[127..96] else src1[127..96];
  d3 @ d2 @ d1 @ d0
}

val avx_pblendd_256 : (ymmword, ymmword, byte) -> ymmword
function avx_pblendd_256(src1, src2, imm) = {
  let d0 : dword = if imm[0] == bitone then src2[31..0]    else src1[31..0];
  let d1 : dword = if imm[1] == bitone then src2[63..32]   else src1[63..32];
  let d2 : dword = if imm[2] == bitone then src2[95..64]   else src1[95..64];
  let d3 : dword = if imm[3] == bitone then src2[127..96]  else src1[127..96];
  let d4 : dword = if imm[4] == bitone then src2[159..128] else src1[159..128];
  let d5 : dword = if imm[5] == bitone then src2[191..160] else src1[191..160];
  let d6 : dword = if imm[6] == bitone then src2[223..192] else src1[223..192];
  let d7 : dword = if imm[7] == bitone then src2[255..224] else src1[255..224];
  d7 @ d6 @ d5 @ d4 @ d3 @ d2 @ d1 @ d0
}

// VPALIGNR 128-bit: concatenate src1(high):src2(low), shift right by imm bytes, take low 128 bits
val avx_palignr_128 : (xmmword, xmmword, byte) -> xmmword
function avx_palignr_128(src1, src2, imm) = {
  let shift_bytes : int = unsigned(imm);
  let concat : ymmword = src1 @ src2;
  if shift_bytes <= 0 then concat[127..0]
  else if shift_bytes >= 32 then zeros()
  else (concat >> (shift_bytes * 8))[127..0]
}

// VROUNDPS 128-bit
val avx_roundps_128 : (xmmword, byte) -> xmmword
function avx_roundps_128(src, imm) = {
  let d0 : dword = __f32_round(src[31..0], imm);
  let d1 : dword = __f32_round(src[63..32], imm);
  let d2 : dword = __f32_round(src[95..64], imm);
  let d3 : dword = __f32_round(src[127..96], imm);
  d3 @ d2 @ d1 @ d0
}

// VROUNDPD 128-bit
val avx_roundpd_128 : (xmmword, byte) -> xmmword
function avx_roundpd_128(src, imm) = {
  let lo : qword = __f64_round(src[63..0], imm);
  let hi : qword = __f64_round(src[127..64], imm);
  hi @ lo
}

// VDPPS 128-bit: dot product of packed singles
val avx_dpps_128 : (xmmword, xmmword, byte) -> xmmword
function avx_dpps_128(a, b, imm) = {
  let zero : dword = 0x00000000;
  let temp0 : dword = if imm[4] == bitone then __f32_mul(a[31..0], b[31..0]) else zero;
  let temp1 : dword = if imm[5] == bitone then __f32_mul(a[63..32], b[63..32]) else zero;
  let temp2 : dword = if imm[6] == bitone then __f32_mul(a[95..64], b[95..64]) else zero;
  let temp3 : dword = if imm[7] == bitone then __f32_mul(a[127..96], b[127..96]) else zero;
  let sum01 : dword = __f32_add(temp0, temp1);
  let sum23 : dword = __f32_add(temp2, temp3);
  let sum : dword = __f32_add(sum01, sum23);
  let d0 : dword = if imm[0] == bitone then sum else zero;
  let d1 : dword = if imm[1] == bitone then sum else zero;
  let d2 : dword = if imm[2] == bitone then sum else zero;
  let d3 : dword = if imm[3] == bitone then sum else zero;
  d3 @ d2 @ d1 @ d0
}

// VDPPD 128-bit: dot product of packed doubles
val avx_dppd_128 : (xmmword, xmmword, byte) -> xmmword
function avx_dppd_128(a, b, imm) = {
  let zero : qword = 0x0000000000000000;
  let temp0 : qword = if imm[4] == bitone then __f64_mul(a[63..0], b[63..0]) else zero;
  let temp1 : qword = if imm[5] == bitone then __f64_mul(a[127..64], b[127..64]) else zero;
  let sum : qword = __f64_add(temp0, temp1);
  let lo : qword = if imm[0] == bitone then sum else zero;
  let hi : qword = if imm[1] == bitone then sum else zero;
  hi @ lo
}

// VPERMQ: permute 256-bit qwords based on imm8
val avx_vpermq : (ymmword, byte) -> ymmword
function avx_vpermq(src, imm) = {
  let sel0 : range(0, 3) = unsigned(imm[1..0]);
  let sel1 : range(0, 3) = unsigned(imm[3..2]);
  let sel2 : range(0, 3) = unsigned(imm[5..4]);
  let sel3 : range(0, 3) = unsigned(imm[7..6]);
  let q0 : qword = match sel0 { 0 => src[63..0], 1 => src[127..64], 2 => src[191..128], _ => src[255..192] };
  let q1 : qword = match sel1 { 0 => src[63..0], 1 => src[127..64], 2 => src[191..128], _ => src[255..192] };
  let q2 : qword = match sel2 { 0 => src[63..0], 1 => src[127..64], 2 => src[191..128], _ => src[255..192] };
  let q3 : qword = match sel3 { 0 => src[63..0], 1 => src[127..64], 2 => src[191..128], _ => src[255..192] };
  q3 @ q2 @ q1 @ q0
}

// VINSERTPS for VEX: takes dst xmm value, handles mem flag
val avx_insertps : (xmmword, xmmword, byte, bool) -> xmmword
function avx_insertps(dst, src, imm8, is_mem) = {
  // For memory operand, count_s (imm8[7:6]) is ignored — the 32-bit value is used directly
  let src_float : dword = if is_mem then src[31..0] else {
    let src_sel : range(0, 3) = unsigned(imm8[7..6]);
    match src_sel { 0 => src[31..0], 1 => src[63..32], 2 => src[95..64], _ => src[127..96] }
  };
  let dst_sel : range(0, 3) = unsigned(imm8[5..4]);
  let t0 : dword = if dst_sel == 0 then src_float else dst[31..0];
  let t1 : dword = if dst_sel == 1 then src_float else dst[63..32];
  let t2 : dword = if dst_sel == 2 then src_float else dst[95..64];
  let t3 : dword = if dst_sel == 3 then src_float else dst[127..96];
  let d0 : dword = if imm8[0] == bitone then 0x00000000 else t0;
  let d1 : dword = if imm8[1] == bitone then 0x00000000 else t1;
  let d2 : dword = if imm8[2] == bitone then 0x00000000 else t2;
  let d3 : dword = if imm8[3] == bitone then 0x00000000 else t3;
  d3 @ d2 @ d1 @ d0
}

// Extract word from XMM at position sel (0..7)
val extract_word_from_xmm : (xmmword, range(0, 7)) -> word
function extract_word_from_xmm(s, sel) = {
  match sel {
    0 => s[15..0],
    1 => s[31..16],
    2 => s[47..32],
    3 => s[63..48],
    4 => s[79..64],
    5 => s[95..80],
    6 => s[111..96],
    7 => s[127..112]
  }
}

// =========================================================================
// VEX 0F3A map dispatch
// =========================================================================

val dispatch_vex_0f3a : (byte, Prefixes) -> ExecutionResult
function dispatch_vex_0f3a(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F3A 18: VINSERTF128 ymm1, ymm2, xmm3/m128, imm8
  24 => {
    if mp != MP_66 then {
      raise_UD()
    } else if not_bool(pfx.vex_l) then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : xmmword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(addr) => mem_read128(fixup_addr(addr)),
      };
      let imm = fetch_byte();
      // imm8[0] selects which 128-bit lane to replace
      if imm[0] == bitzero then
        write_ymm(dst, src1[255..128] @ src2)
      else
        write_ymm(dst, src2 @ src1[127..0]);
      Ok()
    }
  },

  // 0F3A 19: VEXTRACTF128 xmm1/m128, ymm2, imm8
  25 => {
    if mp != MP_66 then {
      raise_UD()
    } else if not_bool(pfx.vex_l) then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let src = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src_ymm : ymmword = read_ymm(src);
      let imm = fetch_byte();
      let extracted : xmmword =
        if imm[0] == bitzero then src_ymm[127..0]
        else src_ymm[255..128];
      match rm {
        RM_reg(_) => { write_xmm(modrm_xmm_rm(modrm, pfx), extracted); Ok() },
        RM_mem(addr) => { mem_write128(fixup_addr(addr), extracted); Ok() },
      }
    }
  },

  // 0F3A 30: KSHIFTRW k1, k2, imm8 (66, W1)
  48 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let k1 : range(0, 7) = unsigned(modrm[5..3]);
      let k2 : range(0, 7) = unsigned(modrm[2..0]);
      let imm = fetch_byte();
      let shift : range(0, 255) = unsigned(imm);
      let src : bits(16) = read_kreg(k2)[15..0];
      let result : bits(16) = if shift >= 16 then zeros() else sail_shiftright(src, shift);
      write_kreg(k1, zero_extend(result));
      Ok()
    }
  },

  // 0F3A 32: KSHIFTLW k1, k2, imm8 (66, W1)
  50 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let k1 : range(0, 7) = unsigned(modrm[5..3]);
      let k2 : range(0, 7) = unsigned(modrm[2..0]);
      let imm = fetch_byte();
      let shift : range(0, 255) = unsigned(imm);
      let src : bits(16) = read_kreg(k2)[15..0];
      let result : bits(16) = if shift >= 16 then zeros() else sail_shiftleft(src, shift);
      write_kreg(k1, zero_extend(result));
      Ok()
    }
  },

  // 0F3A 1D: VCVTPS2PH xmm/m64/m128, xmm/ymm, imm8 (66 prefix)
  29 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let src = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let imm = fetch_byte();
      if pfx.vex_l then {
        let res : xmmword = avx_vcvtps2ph_256(read_ymm(src));
        match rm {
          RM_reg(_) => { write_xmm(modrm_xmm_rm(modrm, pfx), res); Ok() },
          RM_mem(addr) => { mem_write128(fixup_addr(addr), res); Ok() },
        }
      } else {
        let res : bits(64) = avx_vcvtps2ph_128(read_xmm(src));
        match rm {
          RM_reg(_) => { write_xmm(modrm_xmm_rm(modrm, pfx), zero_extend(res)); Ok() },
          RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok() },
        }
      }
    }
  },

  // 0F3A DF: VAESKEYGENASSIST — VEX.128.66.0F3A.WIG DF
  223 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD()
    } else if pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let imm = fetch_byte();
      write_xmm(dst, __aeskeygenassist(src, imm));
      Ok()
    }
  },

  // 0F3A F0: RORX — VEX.LZ.F2.0F3A.W0/W1 F0
  240 => {
    if mp != MP_F2 then {
      raise_UD()
    } else if pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let os : OperandSize = if pfx.vex_w then OS64 else OS32;
      let src : qword = read_rm_val(rm, os, true);
      let imm = fetch_byte();
      if pfx.vex_w then {
        // 64-bit rotate right
        let rot : range(0, 63) = unsigned(imm[5..0]);
        let result : bits(64) = (src[63..0] >> rot) | (src[63..0] << (64 - rot));
        write_gpr(dst, OS64, zero_extend(result));
      } else {
        // 32-bit rotate right
        let rot : range(0, 31) = unsigned(imm[4..0]);
        let result : bits(32) = (src[31..0] >> rot) | (src[31..0] << (32 - rot));
        write_gpr(dst, OS32, zero_extend(result));
      };
      Ok()
    }
  },

  // 0F3A 00: VPERMQ ymm1, ymm2/m256, imm8 (66, W1) — VEX.256 only
  0 => {
    if mp != MP_66 then {
      raise_UD()
    } else if not_bool(pfx.vex_l) then {
      raise_UD()
    } else if not_bool(pfx.vex_w) then {
      raise_UD()
    } else if pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      let imm = fetch_byte();
      write_ymm(dst, avx_vpermq(src, imm));
      Ok()
    }
  },

  // 0F3A 01: VPERMPD ymm1, ymm2/m256, imm8 (66, W1) — VEX.256 only
  1 => {
    if mp != MP_66 then {
      raise_UD()
    } else if not_bool(pfx.vex_l) then {
      raise_UD()
    } else if not_bool(pfx.vex_w) then {
      raise_UD()
    } else if pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      let imm = fetch_byte();
      // Same permutation as VPERMQ — permute qwords (doubles are 64-bit like qwords)
      write_ymm(dst, avx_vpermq(src, imm));
      Ok()
    }
  },

  // 0F3A 02: VPBLENDD xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66, W0)
  2 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        let imm = fetch_byte();
        write_ymm(dst, avx_pblendd_256(src1, src2, imm));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        let imm = fetch_byte();
        write_xmm(dst, avx_pblendd_128(src1, src2, imm));
        Ok()
      }
    }
  },

  // 0F3A 08: VROUNDPS xmm/ymm, xmm/ymm/m, imm8 (66) — vvvv must be 1111b
  8 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        let imm = fetch_byte();
        let lo : xmmword = avx_roundps_128(src[127..0], imm);
        let hi : xmmword = avx_roundps_128(src[255..128], imm);
        write_ymm(dst, hi @ lo);
        Ok()
      } else {
        let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        let imm = fetch_byte();
        write_xmm(dst, avx_roundps_128(src, imm));
        Ok()
      }
    }
  },

  // 0F3A 09: VROUNDPD xmm/ymm, xmm/ymm/m, imm8 (66) — vvvv must be 1111b
  9 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        let imm = fetch_byte();
        let lo : xmmword = avx_roundpd_128(src[127..0], imm);
        let hi : xmmword = avx_roundpd_128(src[255..128], imm);
        write_ymm(dst, hi @ lo);
        Ok()
      } else {
        let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        let imm = fetch_byte();
        write_xmm(dst, avx_roundpd_128(src, imm));
        Ok()
      }
    }
  },

  // 0F3A 0A: VROUNDSS xmm, xmm, xmm/m32, imm8 (66) — VEX.128 only, has vvvv source
  10 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2_lo : dword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
        RM_mem(addr) => mem_read32(fixup_addr(addr)),
      };
      let imm = fetch_byte();
      let rounded : dword = __f32_round(src2_lo, imm);
      write_xmm(dst, src1[127..32] @ rounded);
      Ok()
    }
  },

  // 0F3A 0B: VROUNDSD xmm, xmm, xmm/m64, imm8 (66) — VEX.128 only, has vvvv source
  11 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2_lo : qword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(addr) => mem_read64(fixup_addr(addr)),
      };
      let imm = fetch_byte();
      let rounded : qword = __f64_round(src2_lo, imm);
      write_xmm(dst, src1[127..64] @ rounded);
      Ok()
    }
  },

  // 0F3A 0C: VBLENDPS xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66)
  12 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        let imm = fetch_byte();
        write_ymm(dst, avx_blendps_256(src1, src2, imm));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        let imm = fetch_byte();
        write_xmm(dst, avx_blendps_128(src1, src2, imm));
        Ok()
      }
    }
  },

  // 0F3A 0D: VBLENDPD xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66)
  13 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        let imm = fetch_byte();
        write_ymm(dst, avx_blendpd_256(src1, src2, imm));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        let imm = fetch_byte();
        write_xmm(dst, avx_blendpd_128(src1, src2, imm));
        Ok()
      }
    }
  },

  // 0F3A 0E: VPBLENDW xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66)
  14 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        let imm = fetch_byte();
        // For 256-bit, same imm8 pattern applies to each 128-bit lane
        let lo : xmmword = avx_pblendw_128(src1[127..0], src2[127..0], imm);
        let hi : xmmword = avx_pblendw_128(src1[255..128], src2[255..128], imm);
        write_ymm(dst, hi @ lo);
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        let imm = fetch_byte();
        write_xmm(dst, avx_pblendw_128(src1, src2, imm));
        Ok()
      }
    }
  },

  // 0F3A 0F: VPALIGNR xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66)
  15 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        let imm = fetch_byte();
        // Each 128-bit lane is aligned independently
        let lo : xmmword = avx_palignr_128(src1[127..0], src2[127..0], imm);
        let hi : xmmword = avx_palignr_128(src1[255..128], src2[255..128], imm);
        write_ymm(dst, hi @ lo);
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        let imm = fetch_byte();
        write_xmm(dst, avx_palignr_128(src1, src2, imm));
        Ok()
      }
    }
  },

  // 0F3A 14: VPEXTRB r/m8, xmm, imm8 (66) — VEX.128 only, vvvv must be 1111b
  20 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD()
    } else if pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let src = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let imm = fetch_byte();
      let v : byte = extract_byte_from_xmm(read_xmm(src), imm);
      match rm {
        RM_reg(_) => {
          let dst_reg = modrm_rm_reg(modrm, pfx);
          write_gpr32(dst_reg, zero_extend(v));
        },
        RM_mem(addr) => mem_write8(fixup_addr(addr), v),
      };
      Ok()
    }
  },

  // 0F3A 15: VPEXTRW r/m16, xmm, imm8 (66) — VEX.128 only, vvvv must be 1111b
  21 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD()
    } else if pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let src = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let imm = fetch_byte();
      let sel : range(0, 7) = unsigned(imm[2..0]);
      let w : word = extract_word_from_xmm(read_xmm(src), sel);
      match rm {
        RM_reg(_) => {
          let dst_reg = modrm_rm_reg(modrm, pfx);
          write_gpr32(dst_reg, zero_extend(w));
        },
        RM_mem(addr) => mem_write16(fixup_addr(addr), w),
      };
      Ok()
    }
  },

  // 0F3A 16: VPEXTRD/VPEXTRQ r/m, xmm, imm8 (66) — VEX.128 only, vvvv must be 1111b
  22 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD()
    } else if pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let src = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let imm = fetch_byte();
      let src_xmm : xmmword = read_xmm(src);
      match rm {
        RM_reg(_) => {
          let dst_reg = modrm_rm_reg(modrm, pfx);
          if pfx.rex_w then write_gpr64(dst_reg, extract_qword_from_xmm(src_xmm, imm))
          else write_gpr32(dst_reg, extract_dword_from_xmm(src_xmm, imm))
        },
        RM_mem(addr) => {
          let a = fixup_addr(addr);
          if pfx.rex_w then mem_write64(a, extract_qword_from_xmm(src_xmm, imm))
          else mem_write32(a, extract_dword_from_xmm(src_xmm, imm))
        },
      };
      Ok()
    }
  },

  // 0F3A 17: VEXTRACTPS r/m32, xmm, imm8 (66) — VEX.128 only, vvvv must be 1111b
  23 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD()
    } else if pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let src = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let imm = fetch_byte();
      let v : dword = extract_dword_from_xmm(read_xmm(src), imm);
      match rm {
        RM_reg(_) => {
          let dst_reg = modrm_rm_reg(modrm, pfx);
          write_gpr32(dst_reg, v);
        },
        RM_mem(addr) => mem_write32(fixup_addr(addr), v),
      };
      Ok()
    }
  },

  // 0F3A 20: VPINSRB xmm, xmm, r/m8, imm8 (66) — VEX.128 only
  32 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let v : byte = match rm {
        RM_reg(_) => read_gpr8l(modrm_rm_reg(modrm, pfx)),
        RM_mem(addr) => mem_read8(fixup_addr(addr)),
      };
      let imm = fetch_byte();
      let sel : range(0, 15) = unsigned(imm[3..0]);
      write_xmm(dst, insert_byte(src1, v, sel));
      Ok()
    }
  },

  // 0F3A 21: VINSERTPS xmm, xmm, xmm/m32, imm8 (66) — VEX.128 only
  33 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let dst_base : xmmword = read_xmm(pfx.vex_vvvv);
      let is_mem : bool = match rm { RM_reg(_) => false, RM_mem(_) => true };
      let src : xmmword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(addr) => zero_extend(mem_read32(fixup_addr(addr))),
      };
      let imm = fetch_byte();
      write_xmm(dst, avx_insertps(dst_base, src, imm, is_mem));
      Ok()
    }
  },

  // 0F3A 22: VPINSRD/VPINSRQ xmm, xmm, r/m, imm8 (66) — VEX.128 only
  34 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let imm = fetch_byte();
      if pfx.rex_w then {
        // VPINSRQ
        let v : qword = match rm {
          RM_reg(_) => read_gpr64(modrm_rm_reg(modrm, pfx)),
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        let sel : range(0, 1) = unsigned(imm[0..0]);
        let r : xmmword = match sel {
          0 => src1[127..64] @ v,
          1 => v @ src1[63..0]
        };
        write_xmm(dst, r);
        Ok()
      } else {
        // VPINSRD
        let v : dword = match rm {
          RM_reg(_) => read_gpr32(modrm_rm_reg(modrm, pfx)),
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        let sel : range(0, 3) = unsigned(imm[1..0]);
        write_xmm(dst, insert_dword(src1, v, sel));
        Ok()
      }
    }
  },

  // 0F3A 40: VDPPS xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66)
  64 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        let imm = fetch_byte();
        // 256-bit DPPS: each 128-bit lane independently
        let lo : xmmword = avx_dpps_128(src1[127..0], src2[127..0], imm);
        let hi : xmmword = avx_dpps_128(src1[255..128], src2[255..128], imm);
        write_ymm(dst, hi @ lo);
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        let imm = fetch_byte();
        write_xmm(dst, avx_dpps_128(src1, src2, imm));
        Ok()
      }
    }
  },

  // 0F3A 41: VDPPD xmm, xmm, xmm/m128, imm8 (66) — VEX.128 only
  65 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let imm = fetch_byte();
      write_xmm(dst, avx_dppd_128(src1, src2, imm));
      Ok()
    }
  },

  // 0F3A 42: VMPSADBW xmm/ymm, xmm/ymm, xmm/ymm/m, imm8 (66)
  66 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        let imm = fetch_byte();
        // 256-bit: each 128-bit lane independently, imm8[2:0] for low lane, imm8[5:3] for high lane
        let lo : xmmword = __mpsadbw(src1[127..0], src2[127..0], 0b00000 @ imm[2..0]);
        let hi : xmmword = __mpsadbw(src1[255..128], src2[255..128], 0b00000 @ imm[5..3]);
        write_ymm(dst, hi @ lo);
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        let imm = fetch_byte();
        write_xmm(dst, __mpsadbw(src1, src2, imm));
        Ok()
      }
    }
  },

  // 0F3A 44: VPCLMULQDQ xmm, xmm, xmm/m128, imm8 (66) — VEX.128 only
  68 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_l then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      let imm = fetch_byte();
      let sel_a : qword = if imm[0] == bitone then src1[127..64] else src1[63..0];
      let sel_b : qword = if imm[4] == bitone then src2[127..64] else src2[63..0];
      let result : xmmword = __pclmulqdq(sel_a, sel_b);
      write_xmm(dst, result);
      Ok()
    }
  },

  _ => raise_UD(),
  }
}

// =========================================================================
// Top-level VEX dispatch — called from 1-byte opcode map for C4/C5.
// Must come after dispatch_vex_0f/0f38/0f3a definitions.
// =========================================================================

val dispatch_vex : byte -> ExecutionResult
function dispatch_vex(first_byte) = {
  let (pfx, map) : (Prefixes, range(0, 31)) =
    if first_byte == 0xC5 then {
      let b1 = fetch_byte();
      decode_vex2(b1)
    } else {
      // C4 = 3-byte VEX
      let b1 = fetch_byte();
      let b2 = fetch_byte();
      decode_vex3(b1, b2)
    };

  let opcode = fetch_byte();

  match map {
    1 => dispatch_vex_0f(opcode, pfx),
    2 => dispatch_vex_0f38(opcode, pfx),
    3 => dispatch_vex_0f3a(opcode, pfx),
    _ => raise_UD(),
  }
}

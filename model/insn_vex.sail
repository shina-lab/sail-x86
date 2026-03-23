// x86-64 — VEX Prefix Decoding and Dispatch
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

// Helper: decode VEX XMM/YMM source from ModR/M r/m field.
// Returns (xmm_value, ymm_value, is_memory, effective_addr).
// For register operands, reads the register. For memory, loads from memory.
val decode_vex_src_xmm : (byte, RM, Prefixes) -> xmmword
function decode_vex_src_xmm(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
  RM_mem(seg, addr) => seg_read128(seg, addr),
}

val decode_vex_src_ymm : (byte, RM, Prefixes) -> ymmword
function decode_vex_src_ymm(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_ymm(modrm_xmm_rm(modrm, pfx)),
  RM_mem(seg, addr) => seg_read256(seg, addr),
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
        if ~(done) & f[i] == 0b0 then shift = shift + 1
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

// rc: imm8[1:0] rounding control — 00=RNE, 01=round down, 10=round up, 11=truncate
val fp32_to_fp16 : (bits(32), bits(2)) -> bits(16)
function fp32_to_fp16(f, rc) = {
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
  } else {
    // Compute 15-bit truncated result (5-bit exp @ 10-bit mantissa), round bit, sticky bit
    let (top15, round_bit, sticky_bit) : (bits(15), bit, bit) =
      if exp_val < 113 then {
        // Denormal: right-shift (1.frac23) into 10-bit mantissa with exp=0
        // Use 37-bit intermediate (24 mantissa + 13 guard) to preserve round/sticky bits
        let shift_amt : int = 113 - exp_val;
        let wide : bits(37) = (0b1 @ frac23) @ 0b0000000000000;
        let shifted : bits(37) = sail_shiftright(wide, shift_amt);
        let sticky : bits(26) = (0b0 @ shifted[24..0]) - 1;
        (0b00000 @ shifted[35..26], shifted[25], ~(sticky[25]))
      } else {
        let new_exp : int = exp_val - 112;
        let sticky : bits(13) = (0b0 @ frac23[11..0]) - 1;
        (get_slice_int(5, new_exp, 0) @ frac23[22..13], frac23[12], ~(sticky[12]))
      };
    let round_up : bool = match rc {
      0b00 => (round_bit == 0b1) & (sticky_bit == 0b1 | top15[0] == 0b1),
      0b01 => (sign == 0b1) & (round_bit == 0b1 | sticky_bit == 0b1),
      0b10 => (sign == 0b0) & (round_bit == 0b1 | sticky_bit == 0b1),
      0b11 => false
    };
    let result15 : bits(15) = if round_up then top15 + 1 else top15;
    sign @ result15
  }
}

val avx_vcvtph2ps_128 : bits(64) -> xmmword
function avx_vcvtph2ps_128(src) = {
  fp16_to_fp32(src[63..48]) @ fp16_to_fp32(src[47..32]) @
  fp16_to_fp32(src[31..16]) @ fp16_to_fp32(src[15..0])
}

val avx_vcvtps2ph_128 : (xmmword, bits(2)) -> bits(64)
function avx_vcvtps2ph_128(src, rc) = {
  fp32_to_fp16(src[127..96], rc) @ fp32_to_fp16(src[95..64], rc) @
  fp32_to_fp16(src[63..32], rc) @ fp32_to_fp16(src[31..0], rc)
}

val avx_vcvtph2ps_256 : xmmword -> ymmword
function avx_vcvtph2ps_256(src) = {
  avx_vcvtph2ps_128(src[127..64]) @ avx_vcvtph2ps_128(src[63..0])
}

val avx_vcvtps2ph_256 : (ymmword, bits(2)) -> xmmword
function avx_vcvtps2ph_256(src, rc) = {
  avx_vcvtps2ph_128(src[255..128], rc) @ avx_vcvtps2ph_128(src[127..0], rc)
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
  abs(a[127..120]) @ abs(a[119..112]) @
  abs(a[111..104]) @ abs(a[103..96])  @
  abs(a[95..88])   @ abs(a[87..80])   @
  abs(a[79..72])   @ abs(a[71..64])   @
  abs(a[63..56])   @ abs(a[55..48])   @
  abs(a[47..40])   @ abs(a[39..32])   @
  abs(a[31..24])   @ abs(a[23..16])   @
  abs(a[15..8])    @ abs(a[7..0])

val vex_pabsb_256 : ymmword -> ymmword
function vex_pabsb_256(a) =
  vex_pabsb_128(a[255..128]) @ vex_pabsb_128(a[127..0])

// VPABSW: absolute value of packed signed words
val vex_pabsw_128 : xmmword -> xmmword
function vex_pabsw_128(a) =
  abs(a[127..112]) @ abs(a[111..96]) @
  abs(a[95..80])   @ abs(a[79..64])  @
  abs(a[63..48])   @ abs(a[47..32])  @
  abs(a[31..16])   @ abs(a[15..0])

val vex_pabsw_256 : ymmword -> ymmword
function vex_pabsw_256(a) =
  vex_pabsw_128(a[255..128]) @ vex_pabsw_128(a[127..0])

// VPABSD: absolute value of packed signed dwords
val vex_pabsd_128 : xmmword -> xmmword
function vex_pabsd_128(a) =
  abs(a[127..96]) @ abs(a[95..64]) @
  abs(a[63..32])  @ abs(a[31..0])

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
  sat_sub_s(b[111..96], b[127..112]) @ sat_sub_s(b[79..64], b[95..80]) @
  sat_sub_s(b[47..32], b[63..48]) @ sat_sub_s(b[15..0], b[31..16]) @
  sat_sub_s(a[111..96], a[127..112]) @ sat_sub_s(a[79..64], a[95..80]) @
  sat_sub_s(a[47..32], a[63..48]) @ sat_sub_s(a[15..0], a[31..16])

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
    r[(hi)..(lo)] = min_u(av, bv)
  };
  r
}

val avx_pminuw_256 : (ymmword, ymmword) -> ymmword
function avx_pminuw_256(a, b) =
  avx_pminuw_128(a[255..128], b[255..128]) @
  avx_pminuw_128(a[127..0], b[127..0])

val avx_pminuw_512 : (zmmword, zmmword) -> zmmword
function avx_pminuw_512(a, b) =
  avx_pminuw_256(a[511..256], b[511..256]) @
  avx_pminuw_256(a[255..0], b[255..0])

val avx_maxuw_128 : (xmmword, xmmword) -> xmmword
function avx_maxuw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo = i * 16;
    let hi = lo + 15;
    let av : word = a[(hi)..(lo)];
    let bv : word = b[(hi)..(lo)];
    r[(hi)..(lo)] = max_u(av, bv)
  };
  r
}

val avx_maxuw_256 : (ymmword, ymmword) -> ymmword
function avx_maxuw_256(a, b) =
  avx_maxuw_128(a[255..128], b[255..128]) @
  avx_maxuw_128(a[127..0], b[127..0])

val avx_pcmpeqq_128 : (xmmword, xmmword) -> xmmword
function avx_pcmpeqq_128(a, b) =
  cmp_eq(a[127..64], b[127..64]) @
  cmp_eq(a[63..0], b[63..0])

val avx_pcmpeqq_256 : (ymmword, ymmword) -> ymmword
function avx_pcmpeqq_256(a, b) =
  avx_pcmpeqq_128(a[255..128], b[255..128]) @
  avx_pcmpeqq_128(a[127..0], b[127..0])

// PHMINPOSUW: find minimum unsigned word among 8 words.
// Result: bits[15:0] = min value, bits[18:16] = index of min, rest zeroed.
val avx_phminposuw_128 : xmmword -> xmmword
function avx_phminposuw_128(src) = {
  var mv : word = src[15..0];
  var mi : bits(3) = 0b000;

  let v1 : word = src[31..16];
  let d1 : bits(17) = (0b0 @ v1) - (0b0 @ mv);
  let u1 : word = sign_extend(d1[16..16]);
  mv = (v1 & u1) | (mv & ~(u1));
  mi = (0b001 & u1[2..0]) | (mi & ~(u1[2..0]));

  let v2 : word = src[47..32];
  let d2 : bits(17) = (0b0 @ v2) - (0b0 @ mv);
  let u2 : word = sign_extend(d2[16..16]);
  mv = (v2 & u2) | (mv & ~(u2));
  mi = (0b010 & u2[2..0]) | (mi & ~(u2[2..0]));

  let v3 : word = src[63..48];
  let d3 : bits(17) = (0b0 @ v3) - (0b0 @ mv);
  let u3 : word = sign_extend(d3[16..16]);
  mv = (v3 & u3) | (mv & ~(u3));
  mi = (0b011 & u3[2..0]) | (mi & ~(u3[2..0]));

  let v4 : word = src[79..64];
  let d4 : bits(17) = (0b0 @ v4) - (0b0 @ mv);
  let u4 : word = sign_extend(d4[16..16]);
  mv = (v4 & u4) | (mv & ~(u4));
  mi = (0b100 & u4[2..0]) | (mi & ~(u4[2..0]));

  let v5 : word = src[95..80];
  let d5 : bits(17) = (0b0 @ v5) - (0b0 @ mv);
  let u5 : word = sign_extend(d5[16..16]);
  mv = (v5 & u5) | (mv & ~(u5));
  mi = (0b101 & u5[2..0]) | (mi & ~(u5[2..0]));

  let v6 : word = src[111..96];
  let d6 : bits(17) = (0b0 @ v6) - (0b0 @ mv);
  let u6 : word = sign_extend(d6[16..16]);
  mv = (v6 & u6) | (mv & ~(u6));
  mi = (0b110 & u6[2..0]) | (mi & ~(u6[2..0]));

  let v7 : word = src[127..112];
  let d7 : bits(17) = (0b0 @ v7) - (0b0 @ mv);
  let u7 : word = sign_extend(d7[16..16]);
  mv = (v7 & u7) | (mv & ~(u7));
  mi = (0b111 & u7[2..0]) | (mi & ~(u7[2..0]));

  zeros(109) @ mi @ mv
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
  cmp_gt(a[127..120], b[127..120]) @ cmp_gt(a[119..112], b[119..112]) @
  cmp_gt(a[111..104], b[111..104]) @ cmp_gt(a[103..96],  b[103..96])  @
  cmp_gt(a[95..88],   b[95..88])   @ cmp_gt(a[87..80],   b[87..80])   @
  cmp_gt(a[79..72],   b[79..72])   @ cmp_gt(a[71..64],   b[71..64])   @
  cmp_gt(a[63..56],   b[63..56])   @ cmp_gt(a[55..48],   b[55..48])   @
  cmp_gt(a[47..40],   b[47..40])   @ cmp_gt(a[39..32],   b[39..32])   @
  cmp_gt(a[31..24],   b[31..24])   @ cmp_gt(a[23..16],   b[23..16])   @
  cmp_gt(a[15..8],    b[15..8])    @ cmp_gt(a[7..0],     b[7..0])

val vex_pcmpgtw_128 : (xmmword, xmmword) -> xmmword
function vex_pcmpgtw_128(a, b) =
  cmp_gt(a[127..112], b[127..112]) @ cmp_gt(a[111..96], b[111..96]) @
  cmp_gt(a[95..80],   b[95..80])   @ cmp_gt(a[79..64],  b[79..64])  @
  cmp_gt(a[63..48],   b[63..48])   @ cmp_gt(a[47..32],  b[47..32])  @
  cmp_gt(a[31..16],   b[31..16])   @ cmp_gt(a[15..0],   b[15..0])

val vex_pcmpgtd_128 : (xmmword, xmmword) -> xmmword
function vex_pcmpgtd_128(a, b) =
  cmp_gt(a[127..96], b[127..96]) @
  cmp_gt(a[95..64], b[95..64]) @
  cmp_gt(a[63..32], b[63..32]) @
  cmp_gt(a[31..0], b[31..0])

// VPCMPEQB/W: compare packed for equality
val vex_pcmpeqb_128 : (xmmword, xmmword) -> xmmword
function vex_pcmpeqb_128(a, b) =
  cmp_eq(a[127..120], b[127..120]) @ cmp_eq(a[119..112], b[119..112]) @
  cmp_eq(a[111..104], b[111..104]) @ cmp_eq(a[103..96],  b[103..96])  @
  cmp_eq(a[95..88],   b[95..88])   @ cmp_eq(a[87..80],   b[87..80])   @
  cmp_eq(a[79..72],   b[79..72])   @ cmp_eq(a[71..64],   b[71..64])   @
  cmp_eq(a[63..56],   b[63..56])   @ cmp_eq(a[55..48],   b[55..48])   @
  cmp_eq(a[47..40],   b[47..40])   @ cmp_eq(a[39..32],   b[39..32])   @
  cmp_eq(a[31..24],   b[31..24])   @ cmp_eq(a[23..16],   b[23..16])   @
  cmp_eq(a[15..8],    b[15..8])    @ cmp_eq(a[7..0],     b[7..0])

val vex_pcmpeqw_128 : (xmmword, xmmword) -> xmmword
function vex_pcmpeqw_128(a, b) =
  cmp_eq(a[127..112], b[127..112]) @ cmp_eq(a[111..96], b[111..96]) @
  cmp_eq(a[95..80],   b[95..80])   @ cmp_eq(a[79..64],  b[79..64])  @
  cmp_eq(a[63..48],   b[63..48])   @ cmp_eq(a[47..32],  b[47..32])  @
  cmp_eq(a[31..16],   b[31..16])   @ cmp_eq(a[15..0],   b[15..0])

// VPACKSSWB/VPACKUSWB/VPACKSSDW: pack with saturation
val vex_packsswb_128 : (xmmword, xmmword) -> xmmword
function vex_packsswb_128(a, b) =
  sat_s8(b[127..112]) @ sat_s8(b[111..96]) @
  sat_s8(b[95..80])   @ sat_s8(b[79..64])  @
  sat_s8(b[63..48])   @ sat_s8(b[47..32])  @
  sat_s8(b[31..16])   @ sat_s8(b[15..0])   @
  sat_s8(a[127..112]) @ sat_s8(a[111..96]) @
  sat_s8(a[95..80])   @ sat_s8(a[79..64])  @
  sat_s8(a[63..48])   @ sat_s8(a[47..32])  @
  sat_s8(a[31..16])   @ sat_s8(a[15..0])

val vex_packuswb_128 : (xmmword, xmmword) -> xmmword
function vex_packuswb_128(a, b) =
  sat_su8(b[127..112]) @ sat_su8(b[111..96]) @
  sat_su8(b[95..80])   @ sat_su8(b[79..64])  @
  sat_su8(b[63..48])   @ sat_su8(b[47..32])  @
  sat_su8(b[31..16])   @ sat_su8(b[15..0])   @
  sat_su8(a[127..112]) @ sat_su8(a[111..96]) @
  sat_su8(a[95..80])   @ sat_su8(a[79..64])  @
  sat_su8(a[63..48])   @ sat_su8(a[47..32])  @
  sat_su8(a[31..16])   @ sat_su8(a[15..0])

val vex_packssdw_128 : (xmmword, xmmword) -> xmmword
function vex_packssdw_128(a, b) =
  sat_s16(b[127..96]) @ sat_s16(b[95..64]) @
  sat_s16(b[63..32])  @ sat_s16(b[31..0])  @
  sat_s16(a[127..96]) @ sat_s16(a[95..64]) @
  sat_s16(a[63..32])  @ sat_s16(a[31..0])

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
    r[(hi)..(lo)] = min_u(av, bv)
  };
  r
}

val vex_pmaxub_128 : (xmmword, xmmword) -> xmmword
function vex_pmaxub_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 8; let hi = lo + 7;
    let av : byte = a[(hi)..(lo)]; let bv : byte = b[(hi)..(lo)];
    r[(hi)..(lo)] = max_u(av, bv)
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
    r[(hi)..(lo)] = min_s(av, bv)
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
  sat_sub_s(a[127..120], b[127..120]) @ sat_sub_s(a[119..112], b[119..112]) @
  sat_sub_s(a[111..104], b[111..104]) @ sat_sub_s(a[103..96],  b[103..96])  @
  sat_sub_s(a[95..88],   b[95..88])   @ sat_sub_s(a[87..80],   b[87..80])   @
  sat_sub_s(a[79..72],   b[79..72])   @ sat_sub_s(a[71..64],   b[71..64])   @
  sat_sub_s(a[63..56],   b[63..56])   @ sat_sub_s(a[55..48],   b[55..48])   @
  sat_sub_s(a[47..40],   b[47..40])   @ sat_sub_s(a[39..32],   b[39..32])   @
  sat_sub_s(a[31..24],   b[31..24])   @ sat_sub_s(a[23..16],   b[23..16])   @
  sat_sub_s(a[15..8],    b[15..8])    @ sat_sub_s(a[7..0],     b[7..0])

val vex_psubsw_128 : (xmmword, xmmword) -> xmmword
function vex_psubsw_128(a, b) =
  sat_sub_s(a[127..112], b[127..112]) @ sat_sub_s(a[111..96], b[111..96]) @
  sat_sub_s(a[95..80],   b[95..80])   @ sat_sub_s(a[79..64],  b[79..64])  @
  sat_sub_s(a[63..48],   b[63..48])   @ sat_sub_s(a[47..32],  b[47..32])  @
  sat_sub_s(a[31..16],   b[31..16])   @ sat_sub_s(a[15..0],   b[15..0])

val vex_psubusb_128 : (xmmword, xmmword) -> xmmword
function vex_psubusb_128(a, b) =
  sat_sub_u(a[127..120], b[127..120]) @ sat_sub_u(a[119..112], b[119..112]) @
  sat_sub_u(a[111..104], b[111..104]) @ sat_sub_u(a[103..96],  b[103..96])  @
  sat_sub_u(a[95..88],   b[95..88])   @ sat_sub_u(a[87..80],   b[87..80])   @
  sat_sub_u(a[79..72],   b[79..72])   @ sat_sub_u(a[71..64],   b[71..64])   @
  sat_sub_u(a[63..56],   b[63..56])   @ sat_sub_u(a[55..48],   b[55..48])   @
  sat_sub_u(a[47..40],   b[47..40])   @ sat_sub_u(a[39..32],   b[39..32])   @
  sat_sub_u(a[31..24],   b[31..24])   @ sat_sub_u(a[23..16],   b[23..16])   @
  sat_sub_u(a[15..8],    b[15..8])    @ sat_sub_u(a[7..0],     b[7..0])

val vex_psubusw_128 : (xmmword, xmmword) -> xmmword
function vex_psubusw_128(a, b) =
  sat_sub_u(a[127..112], b[127..112]) @ sat_sub_u(a[111..96], b[111..96]) @
  sat_sub_u(a[95..80],   b[95..80])   @ sat_sub_u(a[79..64],  b[79..64])  @
  sat_sub_u(a[63..48],   b[63..48])   @ sat_sub_u(a[47..32],  b[47..32])  @
  sat_sub_u(a[31..16],   b[31..16])   @ sat_sub_u(a[15..0],   b[15..0])

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


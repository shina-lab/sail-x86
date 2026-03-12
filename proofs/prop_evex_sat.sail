$include "../model/prelude.sail"

// --- Branchless helpers (same as model code in insn_sse_int.sail) ---

val sat_add_s8 : (bits(8), bits(8)) -> bits(8)
function sat_add_s8(a, b) = {
  let wide : bits(9) = sign_extend(a) + sign_extend(b);
  let ov : bits(1) = ~(wide[8..8]) & wide[7..7];
  let uf : bits(1) = wide[8..8] & ~(wide[7..7]);
  let ov_mask : bits(8) = sign_extend(ov);
  let uf_mask : bits(8) = sign_extend(uf);
  (0x7F & ov_mask) | (0x80 & uf_mask) | (wide[7..0] & ~(ov_mask) & ~(uf_mask))
}

val sat_sub_s8 : (bits(8), bits(8)) -> bits(8)
function sat_sub_s8(a, b) = {
  let wide : bits(9) = sign_extend(a) - sign_extend(b);
  let ov : bits(1) = ~(wide[8..8]) & wide[7..7];
  let uf : bits(1) = wide[8..8] & ~(wide[7..7]);
  let ov_mask : bits(8) = sign_extend(ov);
  let uf_mask : bits(8) = sign_extend(uf);
  (0x7F & ov_mask) | (0x80 & uf_mask) | (wide[7..0] & ~(ov_mask) & ~(uf_mask))
}

val sat_add_s16 : (bits(16), bits(16)) -> bits(16)
function sat_add_s16(a, b) = {
  let wide : bits(17) = sign_extend(a) + sign_extend(b);
  let ov : bits(1) = ~(wide[16..16]) & wide[15..15];
  let uf : bits(1) = wide[16..16] & ~(wide[15..15]);
  let ov_mask : bits(16) = sign_extend(ov);
  let uf_mask : bits(16) = sign_extend(uf);
  (0x7FFF & ov_mask) | (0x8000 & uf_mask) | (wide[15..0] & ~(ov_mask) & ~(uf_mask))
}

val sat_sub_s16 : (bits(16), bits(16)) -> bits(16)
function sat_sub_s16(a, b) = {
  let wide : bits(17) = sign_extend(a) - sign_extend(b);
  let ov : bits(1) = ~(wide[16..16]) & wide[15..15];
  let uf : bits(1) = wide[16..16] & ~(wide[15..15]);
  let ov_mask : bits(16) = sign_extend(ov);
  let uf_mask : bits(16) = sign_extend(uf);
  (0x7FFF & ov_mask) | (0x8000 & uf_mask) | (wide[15..0] & ~(ov_mask) & ~(uf_mask))
}

val sat_add_u8 : (bits(8), bits(8)) -> bits(8)
function sat_add_u8(a, b) = {
  let wide : bits(9) = (0b0 @ a) + (0b0 @ b);
  let sat : bits(8) = sign_extend(wide[8..8]);
  wide[7..0] | sat
}

val sat_add_u16 : (bits(16), bits(16)) -> bits(16)
function sat_add_u16(a, b) = {
  let wide : bits(17) = (0b0 @ a) + (0b0 @ b);
  let sat : bits(16) = sign_extend(wide[16..16]);
  wide[15..0] | sat
}

val sat_sub_u8 : (bits(8), bits(8)) -> bits(8)
function sat_sub_u8(a, b) = {
  let wide : bits(9) = (0b0 @ a) - (0b0 @ b);
  let mask : bits(8) = sign_extend(~(wide[8..8]));
  wide[7..0] & mask
}

val sat_sub_u16 : (bits(16), bits(16)) -> bits(16)
function sat_sub_u16(a, b) = {
  let wide : bits(17) = (0b0 @ a) - (0b0 @ b);
  let mask : bits(16) = sign_extend(~(wide[16..16]));
  wide[15..0] & mask
}

// ================================================================
// Proof: saturate_sb(a, b) == sat_add_s8(a, b)
// ================================================================

$property
function prop_saturate_sb(a : bits(8), b : bits(8)) -> bool = {
  let sum : int = signed(a) + signed(b);
  let orig : bits(8) = if sum > 127 then 0x7F
                        else if sum < negate(128) then 0x80
                        else get_slice_int(8, sum, 0);
  let branchless : bits(8) = sat_add_s8(a, b);
  orig == branchless
}

// ================================================================
// Proof: saturate_sw(a, b) == sat_add_s16(a, b)
// ================================================================

$property
function prop_saturate_sw(a : bits(16), b : bits(16)) -> bool = {
  let sum : int = signed(a) + signed(b);
  let orig : bits(16) = if sum > 32767 then 0x7FFF
                          else if sum < negate(32768) then 0x8000
                          else get_slice_int(16, sum, 0);
  let branchless : bits(16) = sat_add_s16(a, b);
  orig == branchless
}

// ================================================================
// Proof: saturate_sb_sub(a, b) == sat_sub_s8(a, b)
// ================================================================

$property
function prop_saturate_sb_sub(a : bits(8), b : bits(8)) -> bool = {
  let diff : int = signed(a) - signed(b);
  let orig : bits(8) = if diff > 127 then 0x7F
                         else if diff < negate(128) then 0x80
                         else get_slice_int(8, diff, 0);
  let branchless : bits(8) = sat_sub_s8(a, b);
  orig == branchless
}

// ================================================================
// Proof: saturate_sw_sub(a, b) == sat_sub_s16(a, b)
// ================================================================

$property
function prop_saturate_sw_sub(a : bits(16), b : bits(16)) -> bool = {
  let diff : int = signed(a) - signed(b);
  let orig : bits(16) = if diff > 32767 then 0x7FFF
                          else if diff < negate(32768) then 0x8000
                          else get_slice_int(16, diff, 0);
  let branchless : bits(16) = sat_sub_s16(a, b);
  orig == branchless
}

// ================================================================
// Proof: saturate_ub_add(a, b) == sat_add_u8(a, b)
// ================================================================

$property
function prop_saturate_ub_add(a : bits(8), b : bits(8)) -> bool = {
  let sum : int = unsigned(a) + unsigned(b);
  let orig : bits(8) = if sum > 255 then 0xFF
                         else get_slice_int(8, sum, 0);
  let branchless : bits(8) = sat_add_u8(a, b);
  orig == branchless
}

// ================================================================
// Proof: saturate_uw_add(a, b) == sat_add_u16(a, b)
// ================================================================

$property
function prop_saturate_uw_add(a : bits(16), b : bits(16)) -> bool = {
  let sum : int = unsigned(a) + unsigned(b);
  let orig : bits(16) = if sum > 65535 then 0xFFFF
                          else get_slice_int(16, sum, 0);
  let branchless : bits(16) = sat_add_u16(a, b);
  orig == branchless
}

// ================================================================
// Proof: saturate_ub_sub(a, b) == sat_sub_u8(a, b)
// ================================================================

$property
function prop_saturate_ub_sub(a : bits(8), b : bits(8)) -> bool = {
  let diff : int = unsigned(a) - unsigned(b);
  let orig : bits(8) = if diff < 0 then 0x00
                         else get_slice_int(8, diff, 0);
  let branchless : bits(8) = sat_sub_u8(a, b);
  orig == branchless
}

// ================================================================
// Proof: saturate_uw_sub(a, b) == sat_sub_u16(a, b)
// ================================================================

$property
function prop_saturate_uw_sub(a : bits(16), b : bits(16)) -> bool = {
  let diff : int = unsigned(a) - unsigned(b);
  let orig : bits(16) = if diff < 0 then 0x0000
                          else get_slice_int(16, diff, 0);
  let branchless : bits(16) = sat_sub_u16(a, b);
  orig == branchless
}

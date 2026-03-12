$include "../model/prelude.sail"

// --- or_reduce helpers (same as model code) ---

val or_reduce_8 : bits(8) -> bits(1)
function or_reduce_8(v) = {
  let r4 : bits(4) = v[7..4] | v[3..0];
  let r2 : bits(2) = r4[3..2] | r4[1..0];
  r2[1..1] | r2[0..0]
}

val or_reduce_16 : bits(16) -> bits(1)
function or_reduce_16(v) = or_reduce_8(v[15..8] | v[7..0])

// --- Branchless helpers (textually identical to model code) ---

val sat_s16_to_s8 : bits(16) -> bits(8)
function sat_s16_to_s8(x) = {
  let sign : bits(1) = x[15..15];
  let diff : bits(8) = x[14..7] ^ sign_extend(sign);
  let out_of_range : bits(1) = or_reduce_8(diff);
  let out_mask : bits(8) = sign_extend(out_of_range);
  let clamp_val : bits(8) = sign_extend(sign) ^ 0x7F;
  (clamp_val & out_mask) | (x[7..0] & ~(out_mask))
}

val sat_s32_to_s16 : bits(32) -> bits(16)
function sat_s32_to_s16(x) = {
  let sign : bits(1) = x[31..31];
  let diff : bits(16) = x[30..15] ^ sign_extend(sign);
  let out_of_range : bits(1) = or_reduce_16(diff);
  let out_mask : bits(16) = sign_extend(out_of_range);
  let clamp_val : bits(16) = sign_extend(sign) ^ 0x7FFF;
  (clamp_val & out_mask) | (x[15..0] & ~(out_mask))
}

val sat_s16_to_u8 : bits(16) -> bits(8)
function sat_s16_to_u8(x) = {
  let neg_mask : bits(16) = sign_extend(x[15..15]);
  let pos_val : bits(16) = x & ~(neg_mask);
  let overflow : bits(1) = or_reduce_8(pos_val[15..8]);
  let over_mask : bits(8) = sign_extend(overflow);
  pos_val[7..0] | over_mask
}

// ================================================================
// Proofs
// ================================================================

// saturate_sw_to_sb == sat_s16_to_s8
$property
function prop_sat_sw_to_sb(w : bits(16)) -> bool = {
  let v : int = signed(w);
  let orig : bits(8) = if v > 127 then 0x7F
                        else if v < negate(128) then 0x80
                        else get_slice_int(8, v, 0);
  let branchless : bits(8) = sat_s16_to_s8(w);
  orig == branchless
}

// saturate_sd_to_sw == sat_s32_to_s16
$property
function prop_sat_sd_to_sw(d : bits(32)) -> bool = {
  let v : int = signed(d);
  let orig : bits(16) = if v > 32767 then 0x7FFF
                          else if v < negate(32768) then 0x8000
                          else get_slice_int(16, v, 0);
  let branchless : bits(16) = sat_s32_to_s16(d);
  orig == branchless
}

// saturate_sw_to_ub == sat_s16_to_u8
$property
function prop_sat_sw_to_ub(w : bits(16)) -> bool = {
  let v : int = signed(w);
  let orig : bits(8) = if v > 255 then 0xFF
                        else if v < 0 then 0x00
                        else get_slice_int(8, v, 0);
  let branchless : bits(8) = sat_s16_to_u8(w);
  orig == branchless
}

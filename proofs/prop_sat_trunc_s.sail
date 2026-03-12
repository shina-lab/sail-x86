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

val or_reduce_32 : bits(32) -> bits(1)
function or_reduce_32(v) = or_reduce_16(v[31..16] | v[15..0])

// --- Existing branchless helpers (textually identical to model code) ---

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

// --- New branchless helpers for wider signed truncation ---

// Dword → Byte: signed-saturate 32-bit to 8-bit [-128, 127]
val sat_s32_to_s8 : bits(32) -> bits(8)
function sat_s32_to_s8(x) = {
  let sign : bits(1) = x[31..31];
  let diff : bits(24) = x[30..7] ^ sign_extend(sign);
  let out_of_range : bits(1) = or_reduce_8(diff[23..16] | diff[15..8] | diff[7..0]);
  let out_mask : bits(8) = sign_extend(out_of_range);
  let clamp_val : bits(8) = sign_extend(sign) ^ 0x7F;
  (clamp_val & out_mask) | (x[7..0] & ~(out_mask))
}

// Qword → Byte: signed-saturate 64-bit to 8-bit [-128, 127]
val sat_s64_to_s8 : bits(64) -> bits(8)
function sat_s64_to_s8(x) = {
  let sign : bits(1) = x[63..63];
  let diff : bits(56) = x[62..7] ^ sign_extend(sign);
  let folded : bits(8) = diff[55..48] | diff[47..40] | diff[39..32] | diff[31..24] | diff[23..16] | diff[15..8] | diff[7..0];
  let out_of_range : bits(1) = or_reduce_8(folded);
  let out_mask : bits(8) = sign_extend(out_of_range);
  let clamp_val : bits(8) = sign_extend(sign) ^ 0x7F;
  (clamp_val & out_mask) | (x[7..0] & ~(out_mask))
}

// Qword → Word: signed-saturate 64-bit to 16-bit [-32768, 32767]
val sat_s64_to_s16 : bits(64) -> bits(16)
function sat_s64_to_s16(x) = {
  let sign : bits(1) = x[63..63];
  let diff : bits(48) = x[62..15] ^ sign_extend(sign);
  let folded : bits(16) = diff[47..32] | diff[31..16] | diff[15..0];
  let out_of_range : bits(1) = or_reduce_16(folded);
  let out_mask : bits(16) = sign_extend(out_of_range);
  let clamp_val : bits(16) = sign_extend(sign) ^ 0x7FFF;
  (clamp_val & out_mask) | (x[15..0] & ~(out_mask))
}

// Qword → Dword: signed-saturate 64-bit to 32-bit
val sat_s64_to_s32 : bits(64) -> bits(32)
function sat_s64_to_s32(x) = {
  let sign : bits(1) = x[63..63];
  let diff : bits(32) = x[62..31] ^ sign_extend(sign);
  let out_of_range : bits(1) = or_reduce_32(diff);
  let out_mask : bits(32) = sign_extend(out_of_range);
  let clamp_val : bits(32) = sign_extend(sign) ^ 0x7FFFFFFF;
  (clamp_val & out_mask) | (x[31..0] & ~(out_mask))
}

// ================================================================
// Proofs
// ================================================================

$property
function prop_sat_s32_to_s8(x : bits(32)) -> bool = {
  let v : int = signed(x);
  let orig : bits(8) = if v > 127 then 0x7F
                        else if v < negate(128) then 0x80
                        else get_slice_int(8, v, 0);
  let branchless : bits(8) = sat_s32_to_s8(x);
  orig == branchless
}

$property
function prop_sat_s64_to_s8(x : bits(64)) -> bool = {
  let v : int = signed(x);
  let orig : bits(8) = if v > 127 then 0x7F
                        else if v < negate(128) then 0x80
                        else get_slice_int(8, v, 0);
  let branchless : bits(8) = sat_s64_to_s8(x);
  orig == branchless
}

$property
function prop_sat_s64_to_s16(x : bits(64)) -> bool = {
  let v : int = signed(x);
  let orig : bits(16) = if v > 32767 then 0x7FFF
                          else if v < negate(32768) then 0x8000
                          else get_slice_int(16, v, 0);
  let branchless : bits(16) = sat_s64_to_s16(x);
  orig == branchless
}

$property
function prop_sat_s64_to_s32(x : bits(64)) -> bool = {
  let v : int = signed(x);
  let orig : bits(32) = if v > 2147483647 then 0x7FFFFFFF
                          else if v < negate(2147483648) then 0x80000000
                          else get_slice_int(32, v, 0);
  let branchless : bits(32) = sat_s64_to_s32(x);
  orig == branchless
}

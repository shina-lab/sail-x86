$include "../model/prelude.sail"

// --- abs helpers (same as model code) ---

val abs8 : bits(8) -> bits(8)
function abs8(x) = { let m : bits(8) = sign_extend(x[7..7]); (x ^ m) - m }

val abs16 : bits(16) -> bits(16)
function abs16(x) = { let m : bits(16) = sign_extend(x[15..15]); (x ^ m) - m }

val abs32 : bits(32) -> bits(32)
function abs32(x) = { let m : bits(32) = sign_extend(x[31..31]); (x ^ m) - m }

val abs64 : bits(64) -> bits(64)
function abs64(x) = { let m : bits(64) = sign_extend(x[63..63]); (x ^ m) - m }

// ================================================================
// Per-element proof: abs64 matches if/else definition
// ================================================================

$property
function prop_abs64(x : bits(64)) -> bool = {
  let orig : bits(64) = if signed(x) < 0 then sub_bits(zeros(), x) else x;
  let branchless : bits(64) = abs64(x);
  orig == branchless
}

// ================================================================
// Full-width VPABSB 128-bit proof
// ================================================================

$property
function prop_vpabsb_128(a : bits(128)) -> bool = {
  let orig : bits(128) =
    (if signed(a[127..120]) < 0 then sub_bits(zeros(), a[127..120]) else a[127..120]) @
    (if signed(a[119..112]) < 0 then sub_bits(zeros(), a[119..112]) else a[119..112]) @
    (if signed(a[111..104]) < 0 then sub_bits(zeros(), a[111..104]) else a[111..104]) @
    (if signed(a[103..96]) < 0 then sub_bits(zeros(), a[103..96]) else a[103..96]) @
    (if signed(a[95..88]) < 0 then sub_bits(zeros(), a[95..88]) else a[95..88]) @
    (if signed(a[87..80]) < 0 then sub_bits(zeros(), a[87..80]) else a[87..80]) @
    (if signed(a[79..72]) < 0 then sub_bits(zeros(), a[79..72]) else a[79..72]) @
    (if signed(a[71..64]) < 0 then sub_bits(zeros(), a[71..64]) else a[71..64]) @
    (if signed(a[63..56]) < 0 then sub_bits(zeros(), a[63..56]) else a[63..56]) @
    (if signed(a[55..48]) < 0 then sub_bits(zeros(), a[55..48]) else a[55..48]) @
    (if signed(a[47..40]) < 0 then sub_bits(zeros(), a[47..40]) else a[47..40]) @
    (if signed(a[39..32]) < 0 then sub_bits(zeros(), a[39..32]) else a[39..32]) @
    (if signed(a[31..24]) < 0 then sub_bits(zeros(), a[31..24]) else a[31..24]) @
    (if signed(a[23..16]) < 0 then sub_bits(zeros(), a[23..16]) else a[23..16]) @
    (if signed(a[15..8]) < 0 then sub_bits(zeros(), a[15..8]) else a[15..8]) @
    (if signed(a[7..0]) < 0 then sub_bits(zeros(), a[7..0]) else a[7..0]);
  let branchless : bits(128) =
    abs8(a[127..120]) @ abs8(a[119..112]) @ abs8(a[111..104]) @ abs8(a[103..96]) @
    abs8(a[95..88]) @ abs8(a[87..80]) @ abs8(a[79..72]) @ abs8(a[71..64]) @
    abs8(a[63..56]) @ abs8(a[55..48]) @ abs8(a[47..40]) @ abs8(a[39..32]) @
    abs8(a[31..24]) @ abs8(a[23..16]) @ abs8(a[15..8]) @ abs8(a[7..0]);
  orig == branchless
}

// ================================================================
// Full-width VPABSW 128-bit proof
// ================================================================

$property
function prop_vpabsw_128(a : bits(128)) -> bool = {
  let orig : bits(128) =
    (if signed(a[127..112]) < 0 then sub_bits(zeros(), a[127..112]) else a[127..112]) @
    (if signed(a[111..96]) < 0 then sub_bits(zeros(), a[111..96]) else a[111..96]) @
    (if signed(a[95..80]) < 0 then sub_bits(zeros(), a[95..80]) else a[95..80]) @
    (if signed(a[79..64]) < 0 then sub_bits(zeros(), a[79..64]) else a[79..64]) @
    (if signed(a[63..48]) < 0 then sub_bits(zeros(), a[63..48]) else a[63..48]) @
    (if signed(a[47..32]) < 0 then sub_bits(zeros(), a[47..32]) else a[47..32]) @
    (if signed(a[31..16]) < 0 then sub_bits(zeros(), a[31..16]) else a[31..16]) @
    (if signed(a[15..0]) < 0 then sub_bits(zeros(), a[15..0]) else a[15..0]);
  let branchless : bits(128) =
    abs16(a[127..112]) @ abs16(a[111..96]) @ abs16(a[95..80]) @ abs16(a[79..64]) @
    abs16(a[63..48]) @ abs16(a[47..32]) @ abs16(a[31..16]) @ abs16(a[15..0]);
  orig == branchless
}

// ================================================================
// Full-width VPABSD 128-bit proof
// ================================================================

$property
function prop_vpabsd_128(a : bits(128)) -> bool = {
  let orig : bits(128) =
    (if signed(a[127..96]) < 0 then sub_bits(zeros(), a[127..96]) else a[127..96]) @
    (if signed(a[95..64]) < 0 then sub_bits(zeros(), a[95..64]) else a[95..64]) @
    (if signed(a[63..32]) < 0 then sub_bits(zeros(), a[63..32]) else a[63..32]) @
    (if signed(a[31..0]) < 0 then sub_bits(zeros(), a[31..0]) else a[31..0]);
  let branchless : bits(128) =
    abs32(a[127..96]) @ abs32(a[95..64]) @ abs32(a[63..32]) @ abs32(a[31..0]);
  orig == branchless
}

// ================================================================
// Full-width VPABSQ 128-bit proof
// ================================================================

$property
function prop_vpabsq_128(a : bits(128)) -> bool = {
  let orig : bits(128) =
    (if signed(a[127..64]) < 0 then sub_bits(zeros(), a[127..64]) else a[127..64]) @
    (if signed(a[63..0]) < 0 then sub_bits(zeros(), a[63..0]) else a[63..0]);
  let branchless : bits(128) =
    abs64(a[127..64]) @ abs64(a[63..0]);
  orig == branchless
}

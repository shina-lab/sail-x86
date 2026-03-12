$include "../model/prelude.sail"

// --- blend_byte (textually identical to model code) ---

val blend_byte : (bits(8), bits(8), bits(1)) -> bits(8)
function blend_byte(a, b, sel) = { let m : bits(8) = sign_extend(sel); (a & ~(m)) | (b & m) }

// ================================================================
// Proof: blend_byte matches if/else
// ================================================================

$property
function prop_blend_byte(a : bits(8), b : bits(8), sel : bits(1)) -> bool = {
  let orig : bits(8) = if sel == 0b1 then b else a;
  let branchless : bits(8) = blend_byte(a, b, sel);
  orig == branchless
}

// Full-width PBLENDVB 128-bit proof
$property
function prop_pblendvb_128(a : bits(128), b : bits(128), m : bits(128)) -> bool = {
  let orig : bits(128) =
    (if m[127..127] == 0b1 then b[127..120] else a[127..120]) @
    (if m[119..119] == 0b1 then b[119..112] else a[119..112]) @
    (if m[111..111] == 0b1 then b[111..104] else a[111..104]) @
    (if m[103..103] == 0b1 then b[103..96] else a[103..96]) @
    (if m[95..95] == 0b1 then b[95..88] else a[95..88]) @
    (if m[87..87] == 0b1 then b[87..80] else a[87..80]) @
    (if m[79..79] == 0b1 then b[79..72] else a[79..72]) @
    (if m[71..71] == 0b1 then b[71..64] else a[71..64]) @
    (if m[63..63] == 0b1 then b[63..56] else a[63..56]) @
    (if m[55..55] == 0b1 then b[55..48] else a[55..48]) @
    (if m[47..47] == 0b1 then b[47..40] else a[47..40]) @
    (if m[39..39] == 0b1 then b[39..32] else a[39..32]) @
    (if m[31..31] == 0b1 then b[31..24] else a[31..24]) @
    (if m[23..23] == 0b1 then b[23..16] else a[23..16]) @
    (if m[15..15] == 0b1 then b[15..8] else a[15..8]) @
    (if m[7..7] == 0b1 then b[7..0] else a[7..0]);
  let branchless : bits(128) =
    blend_byte(a[127..120], b[127..120], m[127..127]) @
    blend_byte(a[119..112], b[119..112], m[119..119]) @
    blend_byte(a[111..104], b[111..104], m[111..111]) @
    blend_byte(a[103..96], b[103..96], m[103..103]) @
    blend_byte(a[95..88], b[95..88], m[95..95]) @
    blend_byte(a[87..80], b[87..80], m[87..87]) @
    blend_byte(a[79..72], b[79..72], m[79..79]) @
    blend_byte(a[71..64], b[71..64], m[71..71]) @
    blend_byte(a[63..56], b[63..56], m[63..63]) @
    blend_byte(a[55..48], b[55..48], m[55..55]) @
    blend_byte(a[47..40], b[47..40], m[47..47]) @
    blend_byte(a[39..32], b[39..32], m[39..39]) @
    blend_byte(a[31..24], b[31..24], m[31..31]) @
    blend_byte(a[23..16], b[23..16], m[23..23]) @
    blend_byte(a[15..8], b[15..8], m[15..15]) @
    blend_byte(a[7..0], b[7..0], m[7..7]);
  orig == branchless
}

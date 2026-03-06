// PBLENDVB — Variable Blend Packed Bytes (SSE4.1)
//
// Conditionally copies byte elements from src to dst based on the
// most significant bit of each byte in the implicit mask register XMM0.
// If mask byte MSB is 1, take from src; otherwise keep dst byte.
// No flags affected.

val pblendvb_byte : (byte, byte, byte) -> byte
function pblendvb_byte(dst_b, src_b, mask_b) =
  if mask_b[7] == bitone then src_b else dst_b

val exec_pblendvb : (simd_idx, xmmword) -> ExecutionResult
function exec_pblendvb(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let m : xmmword = read_xmm(0);
  let r : xmmword =
    pblendvb_byte(a[127..120], b[127..120], m[127..120]) @
    pblendvb_byte(a[119..112], b[119..112], m[119..112]) @
    pblendvb_byte(a[111..104], b[111..104], m[111..104]) @
    pblendvb_byte(a[103..96],  b[103..96],  m[103..96]) @
    pblendvb_byte(a[95..88],   b[95..88],   m[95..88]) @
    pblendvb_byte(a[87..80],   b[87..80],   m[87..80]) @
    pblendvb_byte(a[79..72],   b[79..72],   m[79..72]) @
    pblendvb_byte(a[71..64],   b[71..64],   m[71..64]) @
    pblendvb_byte(a[63..56],   b[63..56],   m[63..56]) @
    pblendvb_byte(a[55..48],   b[55..48],   m[55..48]) @
    pblendvb_byte(a[47..40],   b[47..40],   m[47..40]) @
    pblendvb_byte(a[39..32],   b[39..32],   m[39..32]) @
    pblendvb_byte(a[31..24],   b[31..24],   m[31..24]) @
    pblendvb_byte(a[23..16],   b[23..16],   m[23..16]) @
    pblendvb_byte(a[15..8],    b[15..8],    m[15..8]) @
    pblendvb_byte(a[7..0],     b[7..0],     m[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

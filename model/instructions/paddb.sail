// PADDB — Add Packed Byte Integers
//
// Adds 16 pairs of 8-bit integers from two 128-bit XMM registers.
// Overflow wraps around (carry is ignored). No flags affected.

// Legacy SSE: PADDB xmm1, xmm2
val exec_paddb_xmm : (simd_idx, xmmword) -> ExecutionResult
function exec_paddb_xmm(dst, src) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  var result : xmmword = zeros();
  result[7..0]     = a[7..0]     + b[7..0];
  result[15..8]    = a[15..8]    + b[15..8];
  result[23..16]   = a[23..16]   + b[23..16];
  result[31..24]   = a[31..24]   + b[31..24];
  result[39..32]   = a[39..32]   + b[39..32];
  result[47..40]   = a[47..40]   + b[47..40];
  result[55..48]   = a[55..48]   + b[55..48];
  result[63..56]   = a[63..56]   + b[63..56];
  result[71..64]   = a[71..64]   + b[71..64];
  result[79..72]   = a[79..72]   + b[79..72];
  result[87..80]   = a[87..80]   + b[87..80];
  result[95..88]   = a[95..88]   + b[95..88];
  result[103..96]  = a[103..96]  + b[103..96];
  result[111..104] = a[111..104] + b[111..104];
  result[119..112] = a[119..112] + b[119..112];
  result[127..120] = a[127..120] + b[127..120];
  write_xmm_legacy(dst, result);
  Ok(())
}

// VEX.128: VPADDB xmm1, xmm2, xmm3
val exec_vpaddb_xmm : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vpaddb_xmm(dst, src1, src2) = {
  let a : xmmword = src1;
  let b : xmmword = src2;
  var result : xmmword = zeros();
  result[7..0]     = a[7..0]     + b[7..0];
  result[15..8]    = a[15..8]    + b[15..8];
  result[23..16]   = a[23..16]   + b[23..16];
  result[31..24]   = a[31..24]   + b[31..24];
  result[39..32]   = a[39..32]   + b[39..32];
  result[47..40]   = a[47..40]   + b[47..40];
  result[55..48]   = a[55..48]   + b[55..48];
  result[63..56]   = a[63..56]   + b[63..56];
  result[71..64]   = a[71..64]   + b[71..64];
  result[79..72]   = a[79..72]   + b[79..72];
  result[87..80]   = a[87..80]   + b[87..80];
  result[95..88]   = a[95..88]   + b[95..88];
  result[103..96]  = a[103..96]  + b[103..96];
  result[111..104] = a[111..104] + b[111..104];
  result[119..112] = a[119..112] + b[119..112];
  result[127..120] = a[127..120] + b[127..120];
  write_xmm(dst, result);
  Ok(())
}

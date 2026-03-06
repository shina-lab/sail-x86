// BLENDVPD — Variable Blend Packed Double-FP (SSE4.1)
// BLENDVPS — Variable Blend Packed Single-FP (SSE4.1)
// PBLENDVB — Variable Blend Packed Bytes (SSE4.1)
// Mask register selects per-element from dst or src.
// No flags affected.

val exec_blendvpd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_blendvpd(dst, src, mask_xmm) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let m : xmmword = mask_xmm;
  let lo : qword = if m[63] == bitone then b[63..0] else a[63..0];
  let hi : qword = if m[127] == bitone then b[127..64] else a[127..64];
  write_xmm_legacy(dst, hi @ lo);
  Ok(())
}

val exec_blendvps : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_blendvps(dst, src, mask_xmm) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let m : xmmword = mask_xmm;
  let d0 : dword = if m[31] == bitone then b[31..0] else a[31..0];
  let d1 : dword = if m[63] == bitone then b[63..32] else a[63..32];
  let d2 : dword = if m[95] == bitone then b[95..64] else a[95..64];
  let d3 : dword = if m[127] == bitone then b[127..96] else a[127..96];
  write_xmm_legacy(dst, d3 @ d2 @ d1 @ d0);
  Ok(())
}

val blend_byte : (byte, byte, bit) -> byte
function blend_byte(a, b, sel) = if sel == bitone then b else a

val exec_pblendvb : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_pblendvb(dst, src, mask_xmm) = {
  let a : xmmword = read_xmm(dst);
  let b : xmmword = src;
  let m : xmmword = mask_xmm;
  let r0  : byte = blend_byte(a[7..0],     b[7..0],     m[7]);
  let r1  : byte = blend_byte(a[15..8],    b[15..8],    m[15]);
  let r2  : byte = blend_byte(a[23..16],   b[23..16],   m[23]);
  let r3  : byte = blend_byte(a[31..24],   b[31..24],   m[31]);
  let r4  : byte = blend_byte(a[39..32],   b[39..32],   m[39]);
  let r5  : byte = blend_byte(a[47..40],   b[47..40],   m[47]);
  let r6  : byte = blend_byte(a[55..48],   b[55..48],   m[55]);
  let r7  : byte = blend_byte(a[63..56],   b[63..56],   m[63]);
  let r8  : byte = blend_byte(a[71..64],   b[71..64],   m[71]);
  let r9  : byte = blend_byte(a[79..72],   b[79..72],   m[79]);
  let r10 : byte = blend_byte(a[87..80],   b[87..80],   m[87]);
  let r11 : byte = blend_byte(a[95..88],   b[95..88],   m[95]);
  let r12 : byte = blend_byte(a[103..96],  b[103..96],  m[103]);
  let r13 : byte = blend_byte(a[111..104], b[111..104], m[111]);
  let r14 : byte = blend_byte(a[119..112], b[119..112], m[119]);
  let r15 : byte = blend_byte(a[127..120], b[127..120], m[127]);
  write_xmm_legacy(dst, r15 @ r14 @ r13 @ r12 @ r11 @ r10 @ r9 @ r8 @ r7 @ r6 @ r5 @ r4 @ r3 @ r2 @ r1 @ r0);
  Ok(())
}

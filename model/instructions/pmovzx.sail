// PMOVZX — Packed Move with Zero Extend (SSE4.1)
// Zero-extends packed integers from smaller to larger element sizes.
// No flags affected.

val zx8_16 : byte -> word
function zx8_16(v) = zero_extend(v)

val zx8_32 : byte -> dword
function zx8_32(v) = zero_extend(v)

val zx8_64 : byte -> qword
function zx8_64(v) = zero_extend(v)

val zx16_32 : word -> dword
function zx16_32(v) = zero_extend(v)

val zx16_64 : word -> qword
function zx16_64(v) = zero_extend(v)

val zx32_64 : dword -> qword
function zx32_64(v) = zero_extend(v)

// PMOVZXBW: 8 x u8 -> 8 x u16
val exec_pmovzxbw : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovzxbw(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    zx8_16(s[63..56]) @ zx8_16(s[55..48]) @
    zx8_16(s[47..40]) @ zx8_16(s[39..32]) @
    zx8_16(s[31..24]) @ zx8_16(s[23..16]) @
    zx8_16(s[15..8])  @ zx8_16(s[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

// PMOVZXBD: 4 x u8 -> 4 x u32
val exec_pmovzxbd : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovzxbd(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    zx8_32(s[31..24]) @ zx8_32(s[23..16]) @
    zx8_32(s[15..8])  @ zx8_32(s[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

// PMOVZXBQ: 2 x u8 -> 2 x u64
val exec_pmovzxbq : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovzxbq(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    zx8_64(s[15..8]) @ zx8_64(s[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

// PMOVZXWD: 4 x u16 -> 4 x u32
val exec_pmovzxwd : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovzxwd(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    zx16_32(s[63..48]) @ zx16_32(s[47..32]) @
    zx16_32(s[31..16]) @ zx16_32(s[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

// PMOVZXWQ: 2 x u16 -> 2 x u64
val exec_pmovzxwq : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovzxwq(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    zx16_64(s[31..16]) @ zx16_64(s[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

// PMOVZXDQ: 2 x u32 -> 2 x u64
val exec_pmovzxdq : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovzxdq(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    zx32_64(s[63..32]) @ zx32_64(s[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

// PMOVSX — Packed Move with Sign Extend (SSE4.1)
// Sign-extends packed integers from smaller to larger element sizes.
// No flags affected.

val sx8_16 : byte -> word
function sx8_16(v) = sign_extend(v)

val sx8_32 : byte -> dword
function sx8_32(v) = sign_extend(v)

val sx8_64 : byte -> qword
function sx8_64(v) = sign_extend(v)

val sx16_32 : word -> dword
function sx16_32(v) = sign_extend(v)

val sx16_64 : word -> qword
function sx16_64(v) = sign_extend(v)

val sx32_64 : dword -> qword
function sx32_64(v) = sign_extend(v)

// PMOVSXBW: 8 x i8 -> 8 x i16
val exec_pmovsxbw : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovsxbw(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    sx8_16(s[63..56]) @ sx8_16(s[55..48]) @
    sx8_16(s[47..40]) @ sx8_16(s[39..32]) @
    sx8_16(s[31..24]) @ sx8_16(s[23..16]) @
    sx8_16(s[15..8])  @ sx8_16(s[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

// PMOVSXBD: 4 x i8 -> 4 x i32
val exec_pmovsxbd : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovsxbd(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    sx8_32(s[31..24]) @ sx8_32(s[23..16]) @
    sx8_32(s[15..8])  @ sx8_32(s[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

// PMOVSXBQ: 2 x i8 -> 2 x i64
val exec_pmovsxbq : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovsxbq(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    sx8_64(s[15..8]) @ sx8_64(s[7..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

// PMOVSXWD: 4 x i16 -> 4 x i32
val exec_pmovsxwd : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovsxwd(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    sx16_32(s[63..48]) @ sx16_32(s[47..32]) @
    sx16_32(s[31..16]) @ sx16_32(s[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

// PMOVSXWQ: 2 x i16 -> 2 x i64
val exec_pmovsxwq : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovsxwq(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    sx16_64(s[31..16]) @ sx16_64(s[15..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

// PMOVSXDQ: 2 x i32 -> 2 x i64
val exec_pmovsxdq : (simd_idx, xmmword) -> ExecutionResult
function exec_pmovsxdq(dst, src) = {
  let s : xmmword = src;
  let r : xmmword =
    sx32_64(s[63..32]) @ sx32_64(s[31..0]);
  write_xmm_legacy(dst, r);
  Ok(())
}

// VPBROADCAST — Broadcast Integer Value
// VPBROADCASTB/VPBROADCASTW/VPBROADCASTD/VPBROADCASTQ — Broadcast from GPR/XMM
// VPBROADCASTM — Broadcast Mask to Vector Register
//
// These instructions replicate a scalar value across all elements of
// the destination SIMD register. AVX2/AVX-512 instructions modeled
// as external functions. No flags affected.

// =========================================================================
// VPBROADCAST — Load with Broadcast (AVX2 generic form)
// =========================================================================

val __vpbroadcast_xmm : (xmmword, byte) -> xmmword
val __vpbroadcast_ymm : (xmmword, byte) -> ymmword

// VPBROADCAST (VEX.128): broadcast element from xmm2/m to xmm1
val exec_vpbroadcast_xmm : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_vpbroadcast_xmm(dst, src, elem_size) = {
  let s : xmmword = src;
  write_xmm(dst, __vpbroadcast_xmm(s, elem_size));
  Ok(())
}

// VPBROADCAST (VEX.256): broadcast element from xmm2/m to ymm1
val exec_vpbroadcast_ymm : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_vpbroadcast_ymm(dst, src, elem_size) = {
  let s : xmmword = src;
  write_ymm(dst, __vpbroadcast_ymm(s, elem_size));
  Ok(())
}

// =========================================================================
// VPBROADCASTB — Broadcast Byte (AVX2/AVX-512)
// =========================================================================

val __vpbroadcastb_xmm : byte -> xmmword
val __vpbroadcastb_ymm : byte -> ymmword
val __vpbroadcastb_zmm : byte -> zmmword

// VPBROADCASTB (VEX.128/EVEX.128): xmm1 := broadcast byte
val exec_vpbroadcastb_xmm : (simd_idx, byte) -> ExecutionResult
function exec_vpbroadcastb_xmm(dst, val8) = {
  write_xmm(dst, __vpbroadcastb_xmm(val8));
  Ok(())
}

// VPBROADCASTB (VEX.256/EVEX.256): ymm1 := broadcast byte
val exec_vpbroadcastb_ymm : (simd_idx, byte) -> ExecutionResult
function exec_vpbroadcastb_ymm(dst, val8) = {
  write_ymm(dst, __vpbroadcastb_ymm(val8));
  Ok(())
}

// VPBROADCASTB (EVEX.512): zmm1 := broadcast byte
val exec_vpbroadcastb_zmm : (simd_idx, byte) -> ExecutionResult
function exec_vpbroadcastb_zmm(dst, val8) = {
  write_zmm(dst, __vpbroadcastb_zmm(val8));
  Ok(())
}

// =========================================================================
// VPBROADCASTW — Broadcast Word (AVX2/AVX-512)
// =========================================================================

val __vpbroadcastw_xmm : word -> xmmword
val __vpbroadcastw_ymm : word -> ymmword
val __vpbroadcastw_zmm : word -> zmmword

// VPBROADCASTW (VEX.128/EVEX.128): xmm1 := broadcast word
val exec_vpbroadcastw_xmm : (simd_idx, word) -> ExecutionResult
function exec_vpbroadcastw_xmm(dst, val16) = {
  write_xmm(dst, __vpbroadcastw_xmm(val16));
  Ok(())
}

// VPBROADCASTW (VEX.256/EVEX.256): ymm1 := broadcast word
val exec_vpbroadcastw_ymm : (simd_idx, word) -> ExecutionResult
function exec_vpbroadcastw_ymm(dst, val16) = {
  write_ymm(dst, __vpbroadcastw_ymm(val16));
  Ok(())
}

// VPBROADCASTW (EVEX.512): zmm1 := broadcast word
val exec_vpbroadcastw_zmm : (simd_idx, word) -> ExecutionResult
function exec_vpbroadcastw_zmm(dst, val16) = {
  write_zmm(dst, __vpbroadcastw_zmm(val16));
  Ok(())
}

// =========================================================================
// VPBROADCASTD — Broadcast Dword (AVX2/AVX-512)
// =========================================================================

val __vpbroadcastd_xmm : dword -> xmmword
val __vpbroadcastd_ymm : dword -> ymmword
val __vpbroadcastd_zmm : dword -> zmmword

// VPBROADCASTD (VEX.128/EVEX.128): xmm1 := broadcast dword
val exec_vpbroadcastd_xmm : (simd_idx, dword) -> ExecutionResult
function exec_vpbroadcastd_xmm(dst, val32) = {
  write_xmm(dst, __vpbroadcastd_xmm(val32));
  Ok(())
}

// VPBROADCASTD (VEX.256/EVEX.256): ymm1 := broadcast dword
val exec_vpbroadcastd_ymm : (simd_idx, dword) -> ExecutionResult
function exec_vpbroadcastd_ymm(dst, val32) = {
  write_ymm(dst, __vpbroadcastd_ymm(val32));
  Ok(())
}

// VPBROADCASTD (EVEX.512): zmm1 := broadcast dword
val exec_vpbroadcastd_zmm : (simd_idx, dword) -> ExecutionResult
function exec_vpbroadcastd_zmm(dst, val32) = {
  write_zmm(dst, __vpbroadcastd_zmm(val32));
  Ok(())
}

// =========================================================================
// VPBROADCASTQ — Broadcast Qword (AVX2/AVX-512)
// =========================================================================

val __vpbroadcastq_xmm : qword -> xmmword
val __vpbroadcastq_ymm : qword -> ymmword
val __vpbroadcastq_zmm : qword -> zmmword

// VPBROADCASTQ (VEX.128/EVEX.128): xmm1 := broadcast qword
val exec_vpbroadcastq_xmm : (simd_idx, qword) -> ExecutionResult
function exec_vpbroadcastq_xmm(dst, val64) = {
  write_xmm(dst, __vpbroadcastq_xmm(val64));
  Ok(())
}

// VPBROADCASTQ (VEX.256/EVEX.256): ymm1 := broadcast qword
val exec_vpbroadcastq_ymm : (simd_idx, qword) -> ExecutionResult
function exec_vpbroadcastq_ymm(dst, val64) = {
  write_ymm(dst, __vpbroadcastq_ymm(val64));
  Ok(())
}

// VPBROADCASTQ (EVEX.512): zmm1 := broadcast qword
val exec_vpbroadcastq_zmm : (simd_idx, qword) -> ExecutionResult
function exec_vpbroadcastq_zmm(dst, val64) = {
  write_zmm(dst, __vpbroadcastq_zmm(val64));
  Ok(())
}

// =========================================================================
// VPBROADCASTM — Broadcast Mask to Vector Register (AVX-512)
// VPBROADCASTMB2Q — Broadcast 8-bit mask to packed qwords
// VPBROADCASTMW2D — Broadcast 16-bit mask to packed dwords
// =========================================================================

val __vpbroadcastmb2q_xmm : byte -> xmmword
val __vpbroadcastmb2q_ymm : byte -> ymmword
val __vpbroadcastmb2q_zmm : byte -> zmmword
val __vpbroadcastmw2d_xmm : word -> xmmword
val __vpbroadcastmw2d_ymm : word -> ymmword
val __vpbroadcastmw2d_zmm : word -> zmmword

// VPBROADCASTMB2Q (EVEX.128): xmm1 := broadcast mask byte to qwords
val exec_vpbroadcastmb2q_xmm : (simd_idx, byte) -> ExecutionResult
function exec_vpbroadcastmb2q_xmm(dst, mask_val) = {
  write_xmm(dst, __vpbroadcastmb2q_xmm(mask_val));
  Ok(())
}

// VPBROADCASTMB2Q (EVEX.256): ymm1 := broadcast mask byte to qwords
val exec_vpbroadcastmb2q_ymm : (simd_idx, byte) -> ExecutionResult
function exec_vpbroadcastmb2q_ymm(dst, mask_val) = {
  write_ymm(dst, __vpbroadcastmb2q_ymm(mask_val));
  Ok(())
}

// VPBROADCASTMB2Q (EVEX.512): zmm1 := broadcast mask byte to qwords
val exec_vpbroadcastmb2q_zmm : (simd_idx, byte) -> ExecutionResult
function exec_vpbroadcastmb2q_zmm(dst, mask_val) = {
  write_zmm(dst, __vpbroadcastmb2q_zmm(mask_val));
  Ok(())
}

// VPBROADCASTMW2D (EVEX.128): xmm1 := broadcast mask word to dwords
val exec_vpbroadcastmw2d_xmm : (simd_idx, word) -> ExecutionResult
function exec_vpbroadcastmw2d_xmm(dst, mask_val) = {
  write_xmm(dst, __vpbroadcastmw2d_xmm(mask_val));
  Ok(())
}

// VPBROADCASTMW2D (EVEX.256): ymm1 := broadcast mask word to dwords
val exec_vpbroadcastmw2d_ymm : (simd_idx, word) -> ExecutionResult
function exec_vpbroadcastmw2d_ymm(dst, mask_val) = {
  write_ymm(dst, __vpbroadcastmw2d_ymm(mask_val));
  Ok(())
}

// VPBROADCASTMW2D (EVEX.512): zmm1 := broadcast mask word to dwords
val exec_vpbroadcastmw2d_zmm : (simd_idx, word) -> ExecutionResult
function exec_vpbroadcastmw2d_zmm(dst, mask_val) = {
  write_zmm(dst, __vpbroadcastmw2d_zmm(mask_val));
  Ok(())
}

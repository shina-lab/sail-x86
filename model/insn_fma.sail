// FMA helper functions shared by VEX and EVEX instruction decoders.
//
// Packed and scalar FMA variants (fmadd, fmsub, fnmadd, fnmsub,
// fmaddsub, fmsubadd) for PS/PD in 128/256/512-bit widths,
// plus scalar SS/SD exec_* helpers.

val avx_fmadd_ps_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fmadd_ps_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = __f32_fmadd(a[(lo + 31)..lo], b[(lo + 31)..lo], c[(lo + 31)..lo]);
  };
  r
}

val avx_fmadd_ps_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fmadd_ps_256(a, b, c) = avx_fmadd_ps_128(a[255..128], b[255..128], c[255..128]) @ avx_fmadd_ps_128(a[127..0], b[127..0], c[127..0])

val avx_fmadd_ps_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fmadd_ps_512(a, b, c) = avx_fmadd_ps_256(a[511..256], b[511..256], c[511..256]) @ avx_fmadd_ps_256(a[255..0], b[255..0], c[255..0])

val avx_fmadd_pd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fmadd_pd_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    r[(lo + 63)..lo] = __f64_fmadd(a[(lo + 63)..lo], b[(lo + 63)..lo], c[(lo + 63)..lo]);
  };
  r
}

val avx_fmadd_pd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fmadd_pd_256(a, b, c) = avx_fmadd_pd_128(a[255..128], b[255..128], c[255..128]) @ avx_fmadd_pd_128(a[127..0], b[127..0], c[127..0])

val avx_fmadd_pd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fmadd_pd_512(a, b, c) = avx_fmadd_pd_256(a[511..256], b[511..256], c[511..256]) @ avx_fmadd_pd_256(a[255..0], b[255..0], c[255..0])

val avx_fmsub_ps_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fmsub_ps_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = __f32_fmsub(a[(lo + 31)..lo], b[(lo + 31)..lo], c[(lo + 31)..lo]);
  };
  r
}

val avx_fmsub_ps_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fmsub_ps_256(a, b, c) = avx_fmsub_ps_128(a[255..128], b[255..128], c[255..128]) @ avx_fmsub_ps_128(a[127..0], b[127..0], c[127..0])

val avx_fmsub_ps_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fmsub_ps_512(a, b, c) = avx_fmsub_ps_256(a[511..256], b[511..256], c[511..256]) @ avx_fmsub_ps_256(a[255..0], b[255..0], c[255..0])

val avx_fmsub_pd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fmsub_pd_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    r[(lo + 63)..lo] = __f64_fmsub(a[(lo + 63)..lo], b[(lo + 63)..lo], c[(lo + 63)..lo]);
  };
  r
}

val avx_fmsub_pd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fmsub_pd_256(a, b, c) = avx_fmsub_pd_128(a[255..128], b[255..128], c[255..128]) @ avx_fmsub_pd_128(a[127..0], b[127..0], c[127..0])

val avx_fmsub_pd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fmsub_pd_512(a, b, c) = avx_fmsub_pd_256(a[511..256], b[511..256], c[511..256]) @ avx_fmsub_pd_256(a[255..0], b[255..0], c[255..0])

val avx_fnmadd_ps_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fnmadd_ps_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = __f32_fnmadd(a[(lo + 31)..lo], b[(lo + 31)..lo], c[(lo + 31)..lo]);
  };
  r
}

val avx_fnmadd_ps_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fnmadd_ps_256(a, b, c) = avx_fnmadd_ps_128(a[255..128], b[255..128], c[255..128]) @ avx_fnmadd_ps_128(a[127..0], b[127..0], c[127..0])

val avx_fnmadd_ps_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fnmadd_ps_512(a, b, c) = avx_fnmadd_ps_256(a[511..256], b[511..256], c[511..256]) @ avx_fnmadd_ps_256(a[255..0], b[255..0], c[255..0])

val avx_fnmadd_pd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fnmadd_pd_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    r[(lo + 63)..lo] = __f64_fnmadd(a[(lo + 63)..lo], b[(lo + 63)..lo], c[(lo + 63)..lo]);
  };
  r
}

val avx_fnmadd_pd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fnmadd_pd_256(a, b, c) = avx_fnmadd_pd_128(a[255..128], b[255..128], c[255..128]) @ avx_fnmadd_pd_128(a[127..0], b[127..0], c[127..0])

val avx_fnmadd_pd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fnmadd_pd_512(a, b, c) = avx_fnmadd_pd_256(a[511..256], b[511..256], c[511..256]) @ avx_fnmadd_pd_256(a[255..0], b[255..0], c[255..0])

val avx_fnmsub_ps_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fnmsub_ps_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = __f32_fnmsub(a[(lo + 31)..lo], b[(lo + 31)..lo], c[(lo + 31)..lo]);
  };
  r
}

val avx_fnmsub_ps_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fnmsub_ps_256(a, b, c) = avx_fnmsub_ps_128(a[255..128], b[255..128], c[255..128]) @ avx_fnmsub_ps_128(a[127..0], b[127..0], c[127..0])

val avx_fnmsub_ps_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fnmsub_ps_512(a, b, c) = avx_fnmsub_ps_256(a[511..256], b[511..256], c[511..256]) @ avx_fnmsub_ps_256(a[255..0], b[255..0], c[255..0])

val avx_fnmsub_pd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fnmsub_pd_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    r[(lo + 63)..lo] = __f64_fnmsub(a[(lo + 63)..lo], b[(lo + 63)..lo], c[(lo + 63)..lo]);
  };
  r
}

val avx_fnmsub_pd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fnmsub_pd_256(a, b, c) = avx_fnmsub_pd_128(a[255..128], b[255..128], c[255..128]) @ avx_fnmsub_pd_128(a[127..0], b[127..0], c[127..0])

val avx_fnmsub_pd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fnmsub_pd_512(a, b, c) = avx_fnmsub_pd_256(a[511..256], b[511..256], c[511..256]) @ avx_fnmsub_pd_256(a[255..0], b[255..0], c[255..0])

val avx_fmaddsub_ps_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fmaddsub_ps_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    if i % 2 == 0
    then r[(lo + 31)..lo] = __f32_fmsub(a[(lo + 31)..lo], b[(lo + 31)..lo], c[(lo + 31)..lo])
    else r[(lo + 31)..lo] = __f32_fmadd(a[(lo + 31)..lo], b[(lo + 31)..lo], c[(lo + 31)..lo]);
  };
  r
}

val avx_fmaddsub_ps_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fmaddsub_ps_256(a, b, c) = avx_fmaddsub_ps_128(a[255..128], b[255..128], c[255..128]) @ avx_fmaddsub_ps_128(a[127..0], b[127..0], c[127..0])

val avx_fmaddsub_ps_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fmaddsub_ps_512(a, b, c) = avx_fmaddsub_ps_256(a[511..256], b[511..256], c[511..256]) @ avx_fmaddsub_ps_256(a[255..0], b[255..0], c[255..0])

val avx_fmaddsub_pd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fmaddsub_pd_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    if i % 2 == 0
    then r[(lo + 63)..lo] = __f64_fmsub(a[(lo + 63)..lo], b[(lo + 63)..lo], c[(lo + 63)..lo])
    else r[(lo + 63)..lo] = __f64_fmadd(a[(lo + 63)..lo], b[(lo + 63)..lo], c[(lo + 63)..lo]);
  };
  r
}

val avx_fmaddsub_pd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fmaddsub_pd_256(a, b, c) = avx_fmaddsub_pd_128(a[255..128], b[255..128], c[255..128]) @ avx_fmaddsub_pd_128(a[127..0], b[127..0], c[127..0])

val avx_fmaddsub_pd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fmaddsub_pd_512(a, b, c) = avx_fmaddsub_pd_256(a[511..256], b[511..256], c[511..256]) @ avx_fmaddsub_pd_256(a[255..0], b[255..0], c[255..0])

val avx_fmsubadd_ps_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fmsubadd_ps_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    if i % 2 == 0
    then r[(lo + 31)..lo] = __f32_fmadd(a[(lo + 31)..lo], b[(lo + 31)..lo], c[(lo + 31)..lo])
    else r[(lo + 31)..lo] = __f32_fmsub(a[(lo + 31)..lo], b[(lo + 31)..lo], c[(lo + 31)..lo]);
  };
  r
}

val avx_fmsubadd_ps_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fmsubadd_ps_256(a, b, c) = avx_fmsubadd_ps_128(a[255..128], b[255..128], c[255..128]) @ avx_fmsubadd_ps_128(a[127..0], b[127..0], c[127..0])

val avx_fmsubadd_ps_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fmsubadd_ps_512(a, b, c) = avx_fmsubadd_ps_256(a[511..256], b[511..256], c[511..256]) @ avx_fmsubadd_ps_256(a[255..0], b[255..0], c[255..0])

val avx_fmsubadd_pd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_fmsubadd_pd_128(a, b, c) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    if i % 2 == 0
    then r[(lo + 63)..lo] = __f64_fmadd(a[(lo + 63)..lo], b[(lo + 63)..lo], c[(lo + 63)..lo])
    else r[(lo + 63)..lo] = __f64_fmsub(a[(lo + 63)..lo], b[(lo + 63)..lo], c[(lo + 63)..lo]);
  };
  r
}

val avx_fmsubadd_pd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_fmsubadd_pd_256(a, b, c) = avx_fmsubadd_pd_128(a[255..128], b[255..128], c[255..128]) @ avx_fmsubadd_pd_128(a[127..0], b[127..0], c[127..0])

val avx_fmsubadd_pd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_fmsubadd_pd_512(a, b, c) = avx_fmsubadd_pd_256(a[511..256], b[511..256], c[511..256]) @ avx_fmsubadd_pd_256(a[255..0], b[255..0], c[255..0])


val exec_vfmadd132ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmadd132ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fmadd(d[31..0], src3[31..0], src2[31..0])); Ok(())
}

val exec_vfmadd132sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmadd132sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fmadd(d[63..0], src3[63..0], src2[63..0])); Ok(())
}

val exec_vfmsub132ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmsub132ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fmsub(d[31..0], src3[31..0], src2[31..0])); Ok(())
}

val exec_vfmsub132sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmsub132sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fmsub(d[63..0], src3[63..0], src2[63..0])); Ok(())
}

val exec_vfnmadd132ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmadd132ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fnmadd(d[31..0], src3[31..0], src2[31..0])); Ok(())
}

val exec_vfnmadd132sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmadd132sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fnmadd(d[63..0], src3[63..0], src2[63..0])); Ok(())
}

val exec_vfnmsub132ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmsub132ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fnmsub(d[31..0], src3[31..0], src2[31..0])); Ok(())
}

val exec_vfnmsub132sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmsub132sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fnmsub(d[63..0], src3[63..0], src2[63..0])); Ok(())
}

val exec_vfmadd213ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmadd213ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fmadd(src2[31..0], d[31..0], src3[31..0])); Ok(())
}

val exec_vfmadd213sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmadd213sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fmadd(src2[63..0], d[63..0], src3[63..0])); Ok(())
}

val exec_vfmsub213ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmsub213ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fmsub(src2[31..0], d[31..0], src3[31..0])); Ok(())
}

val exec_vfmsub213sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmsub213sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fmsub(src2[63..0], d[63..0], src3[63..0])); Ok(())
}

val exec_vfnmadd213ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmadd213ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fnmadd(src2[31..0], d[31..0], src3[31..0])); Ok(())
}

val exec_vfnmadd213sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmadd213sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fnmadd(src2[63..0], d[63..0], src3[63..0])); Ok(())
}

val exec_vfnmsub213ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmsub213ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fnmsub(src2[31..0], d[31..0], src3[31..0])); Ok(())
}

val exec_vfnmsub213sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmsub213sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fnmsub(src2[63..0], d[63..0], src3[63..0])); Ok(())
}

val exec_vfmadd231ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmadd231ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fmadd(src2[31..0], src3[31..0], d[31..0])); Ok(())
}

val exec_vfmadd231sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmadd231sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fmadd(src2[63..0], src3[63..0], d[63..0])); Ok(())
}

val exec_vfmsub231ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmsub231ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fmsub(src2[31..0], src3[31..0], d[31..0])); Ok(())
}

val exec_vfmsub231sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfmsub231sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fmsub(src2[63..0], src3[63..0], d[63..0])); Ok(())
}

val exec_vfnmadd231ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmadd231ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fnmadd(src2[31..0], src3[31..0], d[31..0])); Ok(())
}

val exec_vfnmadd231sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmadd231sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fnmadd(src2[63..0], src3[63..0], d[63..0])); Ok(())
}

val exec_vfnmsub231ss : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmsub231ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fnmsub(src2[31..0], src3[31..0], d[31..0])); Ok(())
}

val exec_vfnmsub231sd : (simd_idx, xmmword, xmmword) -> ExecutionResult
function exec_vfnmsub231sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fnmsub(src2[63..0], src3[63..0], d[63..0])); Ok(())
}



// x86-64 — FMA Shared Helpers
//
// Polymorphic FMA helpers and scalar SS/SD exec_* helpers.

// FMADDSUB: even elements get a*b-c, odd elements get a*b+c.
val avx_fmaddsub : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {32, 64}.
  (int('eb), bits('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_fmaddsub(eb, a, b, c) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    let ae = a[(lo + 'eb - 1)..lo];
    let be = b[(lo + 'eb - 1)..lo];
    let ce = c[(lo + 'eb - 1)..lo];
    r[(lo + 'eb - 1)..lo] = match eb {
      32 => if i % 2 == 0 then __f32_fmsub(ae, be, ce) else __f32_fmadd(ae, be, ce),
      64 => if i % 2 == 0 then __f64_fmsub(ae, be, ce) else __f64_fmadd(ae, be, ce),
    };
  };
  r
}

// FMSUBADD: even elements get a*b+c, odd elements get a*b-c.
val avx_fmsubadd : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {32, 64}.
  (int('eb), bits('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_fmsubadd(eb, a, b, c) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    let ae = a[(lo + 'eb - 1)..lo];
    let be = b[(lo + 'eb - 1)..lo];
    let ce = c[(lo + 'eb - 1)..lo];
    r[(lo + 'eb - 1)..lo] = match eb {
      32 => if i % 2 == 0 then __f32_fmadd(ae, be, ce) else __f32_fmsub(ae, be, ce),
      64 => if i % 2 == 0 then __f64_fmadd(ae, be, ce) else __f64_fmsub(ae, be, ce),
    };
  };
  r
}

val exec_vfmadd132ss : (simd_idx, xmmword, xmmword) -> unit
function exec_vfmadd132ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fmadd(d[31..0], src3[31..0], src2[31..0]))
}

val exec_vfmadd132sd : (simd_idx, xmmword, xmmword) -> unit
function exec_vfmadd132sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fmadd(d[63..0], src3[63..0], src2[63..0]))
}

val exec_vfmsub132ss : (simd_idx, xmmword, xmmword) -> unit
function exec_vfmsub132ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fmsub(d[31..0], src3[31..0], src2[31..0]))
}

val exec_vfmsub132sd : (simd_idx, xmmword, xmmword) -> unit
function exec_vfmsub132sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fmsub(d[63..0], src3[63..0], src2[63..0]))
}

val exec_vfnmadd132ss : (simd_idx, xmmword, xmmword) -> unit
function exec_vfnmadd132ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fnmadd(d[31..0], src3[31..0], src2[31..0]))
}

val exec_vfnmadd132sd : (simd_idx, xmmword, xmmword) -> unit
function exec_vfnmadd132sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fnmadd(d[63..0], src3[63..0], src2[63..0]))
}

val exec_vfnmsub132ss : (simd_idx, xmmword, xmmword) -> unit
function exec_vfnmsub132ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fnmsub(d[31..0], src3[31..0], src2[31..0]))
}

val exec_vfnmsub132sd : (simd_idx, xmmword, xmmword) -> unit
function exec_vfnmsub132sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fnmsub(d[63..0], src3[63..0], src2[63..0]))
}

val exec_vfmadd213ss : (simd_idx, xmmword, xmmword) -> unit
function exec_vfmadd213ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fmadd(src2[31..0], d[31..0], src3[31..0]))
}

val exec_vfmadd213sd : (simd_idx, xmmword, xmmword) -> unit
function exec_vfmadd213sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fmadd(src2[63..0], d[63..0], src3[63..0]))
}

val exec_vfmsub213ss : (simd_idx, xmmword, xmmword) -> unit
function exec_vfmsub213ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fmsub(src2[31..0], d[31..0], src3[31..0]))
}

val exec_vfmsub213sd : (simd_idx, xmmword, xmmword) -> unit
function exec_vfmsub213sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fmsub(src2[63..0], d[63..0], src3[63..0]))
}

val exec_vfnmadd213ss : (simd_idx, xmmword, xmmword) -> unit
function exec_vfnmadd213ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fnmadd(src2[31..0], d[31..0], src3[31..0]))
}

val exec_vfnmadd213sd : (simd_idx, xmmword, xmmword) -> unit
function exec_vfnmadd213sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fnmadd(src2[63..0], d[63..0], src3[63..0]))
}

val exec_vfnmsub213ss : (simd_idx, xmmword, xmmword) -> unit
function exec_vfnmsub213ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fnmsub(src2[31..0], d[31..0], src3[31..0]))
}

val exec_vfnmsub213sd : (simd_idx, xmmword, xmmword) -> unit
function exec_vfnmsub213sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fnmsub(src2[63..0], d[63..0], src3[63..0]))
}

val exec_vfmadd231ss : (simd_idx, xmmword, xmmword) -> unit
function exec_vfmadd231ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fmadd(src2[31..0], src3[31..0], d[31..0]))
}

val exec_vfmadd231sd : (simd_idx, xmmword, xmmword) -> unit
function exec_vfmadd231sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fmadd(src2[63..0], src3[63..0], d[63..0]))
}

val exec_vfmsub231ss : (simd_idx, xmmword, xmmword) -> unit
function exec_vfmsub231ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fmsub(src2[31..0], src3[31..0], d[31..0]))
}

val exec_vfmsub231sd : (simd_idx, xmmword, xmmword) -> unit
function exec_vfmsub231sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fmsub(src2[63..0], src3[63..0], d[63..0]))
}

val exec_vfnmadd231ss : (simd_idx, xmmword, xmmword) -> unit
function exec_vfnmadd231ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fnmadd(src2[31..0], src3[31..0], d[31..0]))
}

val exec_vfnmadd231sd : (simd_idx, xmmword, xmmword) -> unit
function exec_vfnmadd231sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fnmadd(src2[63..0], src3[63..0], d[63..0]))
}

val exec_vfnmsub231ss : (simd_idx, xmmword, xmmword) -> unit
function exec_vfnmsub231ss(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..32] @ __f32_fnmsub(src2[31..0], src3[31..0], d[31..0]))
}

val exec_vfnmsub231sd : (simd_idx, xmmword, xmmword) -> unit
function exec_vfnmsub231sd(dst, src2, src3) = {
  let d = read_xmm(dst);
  write_xmm(dst, d[127..64] @ __f64_fnmsub(src2[63..0], src3[63..0], d[63..0]))
}



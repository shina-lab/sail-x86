// x86-64 — VEX FMA Instructions (0F38 map)
//
// FMA3 fused multiply-add/sub instructions (0F38 96..BF).
// All require 66 mandatory prefix.
// W=0 selects PS/SS variants, W=1 selects PD/SD variants.
// L=0 for 128-bit (or scalar), L=1 for 256-bit.
//
// Operand mapping (avx_fmadd(a,b,c) computes a*b+c):
//   132: a=dst, b=rm,  c=vvvv
//   213: a=vvvv, b=dst, c=rm
//   231: a=vvvv, b=rm,  c=dst

// VEX packed FMA: decode modrm, read sources, apply packed ternary op
val vex_exec_fma_packed : (PackedTernaryOp, FMAOrder, Prefixes) -> unit
function vex_exec_fma_packed(op, order, pfx) = {
  let modrm = fetch(1);
  let dst = modrm_xreg(modrm, pfx);
  let src = modrm_xrm(modrm, pfx);
  let vl = vex_vl(pfx);
  let eb = vex_elem(pfx);
  let d = read_simd(vl, dst);
  let v = read_simd(vl, pfx.vex_vvvv);
  let r = decode_vex_src(vl, src);
  match order {
    FMA_132 => write_simd(vl, dst, packed_ternop(op, eb, d, r, v)),
    FMA_213 => write_simd(vl, dst, packed_ternop(op, eb, v, d, r)),
    FMA_231 => write_simd(vl, dst, packed_ternop(op, eb, v, r, d)),
  }
}

// VEX scalar FMA: decode modrm, read sources, dispatch to exec_vfma_scalar
val vex_exec_fma_scalar : (PackedTernaryOp, FMAOrder, Prefixes) -> unit
function vex_exec_fma_scalar(op, order, pfx) = {
  let modrm = fetch(1);
  let dst = modrm_xreg(modrm, pfx);
  let src = modrm_xrm(modrm, pfx);
  let src2 : xmmword = read_simd(pfx.vex_vvvv);
  let src3 = decode_vex_src(128, src);
  exec_vfma_scalar(op, order, pfx.vex_w, dst, src2, src3)
}

val dispatch_vex_0f38_fma : (range(0, 255), Prefixes) -> unit
function dispatch_vex_0f38_fma(op, pfx) = {
  if ~(has_fma) then raise_UD();
  let mp = get_mandatory_prefix(pfx);

  match op {

  // -----------------------------------------------------------------------
  // VEX FMA3 instructions (0F38 96..BF)
  // -----------------------------------------------------------------------

  // 0F38 96: VFMADDSUB132PS (W0) / VFMADDSUB132PD (W1)
  150 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xreg(modrm, pfx);
    let src = modrm_xrm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, avx_fmaddsub(eb, read_simd(vl, dst), decode_vex_src(src), read_simd(vl, pfx.vex_vvvv)))
  },

  // 0F38 97: VFMSUBADD132PS (W0) / VFMSUBADD132PD (W1)
  151 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xreg(modrm, pfx);
    let src = modrm_xrm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, avx_fmsubadd(eb, read_simd(vl, dst), decode_vex_src(src), read_simd(vl, pfx.vex_vvvv)))
  },

  // 0F38 98-9F: VFMADD/VFMSUB/VFNMADD/VFNMSUB 132 PS/PD/SS/SD
  152 => { if mp != MP_66 then raise_UD(); vex_exec_fma_packed(PT_FMAdd,  FMA_132, pfx) },
  153 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FMAdd,  FMA_132, pfx) },
  154 => { if mp != MP_66 then raise_UD(); vex_exec_fma_packed(PT_FMSub,  FMA_132, pfx) },
  155 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FMSub,  FMA_132, pfx) },
  156 => { if mp != MP_66 then raise_UD(); vex_exec_fma_packed(PT_FNMAdd, FMA_132, pfx) },
  157 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FNMAdd, FMA_132, pfx) },
  158 => { if mp != MP_66 then raise_UD(); vex_exec_fma_packed(PT_FNMSub, FMA_132, pfx) },
  159 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FNMSub, FMA_132, pfx) },

  // 0F38 A6: VFMADDSUB213PS (W0) / VFMADDSUB213PD (W1)
  166 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xreg(modrm, pfx);
    let src = modrm_xrm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, avx_fmaddsub(eb, read_simd(vl, pfx.vex_vvvv), read_simd(vl, dst), decode_vex_src(src)))
  },

  // 0F38 A7: VFMSUBADD213PS (W0) / VFMSUBADD213PD (W1)
  167 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xreg(modrm, pfx);
    let src = modrm_xrm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, avx_fmsubadd(eb, read_simd(vl, pfx.vex_vvvv), read_simd(vl, dst), decode_vex_src(src)))
  },

  // 0F38 A8-AF: VFMADD/VFMSUB/VFNMADD/VFNMSUB 213 PS/PD/SS/SD
  168 => { if mp != MP_66 then raise_UD(); vex_exec_fma_packed(PT_FMAdd,  FMA_213, pfx) },
  169 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FMAdd,  FMA_213, pfx) },
  170 => { if mp != MP_66 then raise_UD(); vex_exec_fma_packed(PT_FMSub,  FMA_213, pfx) },
  171 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FMSub,  FMA_213, pfx) },
  172 => { if mp != MP_66 then raise_UD(); vex_exec_fma_packed(PT_FNMAdd, FMA_213, pfx) },
  173 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FNMAdd, FMA_213, pfx) },
  174 => { if mp != MP_66 then raise_UD(); vex_exec_fma_packed(PT_FNMSub, FMA_213, pfx) },
  175 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FNMSub, FMA_213, pfx) },

  // 0F38 B6: VFMADDSUB231PS (W0) / VFMADDSUB231PD (W1)
  182 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xreg(modrm, pfx);
    let src = modrm_xrm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, avx_fmaddsub(eb, read_simd(vl, pfx.vex_vvvv), decode_vex_src(src), read_simd(vl, dst)))
  },

  // 0F38 B7: VFMSUBADD231PS (W0) / VFMSUBADD231PD (W1)
  183 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xreg(modrm, pfx);
    let src = modrm_xrm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, avx_fmsubadd(eb, read_simd(vl, pfx.vex_vvvv), decode_vex_src(src), read_simd(vl, dst)))
  },

  // 0F38 B8-BF: VFMADD/VFMSUB/VFNMADD/VFNMSUB 231 PS/PD/SS/SD
  184 => { if mp != MP_66 then raise_UD(); vex_exec_fma_packed(PT_FMAdd,  FMA_231, pfx) },
  185 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FMAdd,  FMA_231, pfx) },
  186 => { if mp != MP_66 then raise_UD(); vex_exec_fma_packed(PT_FMSub,  FMA_231, pfx) },
  187 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FMSub,  FMA_231, pfx) },
  188 => { if mp != MP_66 then raise_UD(); vex_exec_fma_packed(PT_FNMAdd, FMA_231, pfx) },
  189 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FNMAdd, FMA_231, pfx) },
  190 => { if mp != MP_66 then raise_UD(); vex_exec_fma_packed(PT_FNMSub, FMA_231, pfx) },
  191 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FNMSub, FMA_231, pfx) },

  _ => raise_UD(),
  }
}

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

// VEX scalar FMA: decode modrm, read sources, dispatch to exec_vfma_scalar
val vex_exec_fma_scalar : (PackedTernaryOp, FMAOrder, Prefixes) -> unit
function vex_exec_fma_scalar(op, order, pfx) = {
  let modrm = fetch(1);
  let dst = modrm_xmm_reg(modrm, pfx);
  let src = modrm_rm(modrm, pfx);
  let src2 : xmmword = read_simd(pfx.vex_vvvv);
  let src3 = decode_vex_src(128, modrm, src, pfx);
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
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, avx_fmaddsub(eb, read_simd(vl, dst), decode_vex_src(modrm, src, pfx), read_simd(vl, pfx.vex_vvvv)))
  },

  // 0F38 97: VFMSUBADD132PS (W0) / VFMSUBADD132PD (W1)
  151 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, avx_fmsubadd(eb, read_simd(vl, dst), decode_vex_src(modrm, src, pfx), read_simd(vl, pfx.vex_vvvv)))
  },

  // 0F38 98: VFMADD132PS (W0) / VFMADD132PD (W1)
  152 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, packed_ternop(PT_FMAdd, eb, read_simd(vl, dst), decode_vex_src(modrm, src, pfx), read_simd(vl, pfx.vex_vvvv)))
  },

  // 0F38 99: VFMADD132SS (W0) / VFMADD132SD (W1)
  153 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FMAdd, FMA_132, pfx) },

  // 0F38 9A: VFMSUB132PS (W0) / VFMSUB132PD (W1)
  154 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, packed_ternop(PT_FMSub, eb, read_simd(vl, dst), decode_vex_src(modrm, src, pfx), read_simd(vl, pfx.vex_vvvv)))
  },

  // 0F38 9B: VFMSUB132SS (W0) / VFMSUB132SD (W1)
  155 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FMSub, FMA_132, pfx) },

  // 0F38 9C: VFNMADD132PS (W0) / VFNMADD132PD (W1)
  156 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, packed_ternop(PT_FNMAdd, eb, read_simd(vl, dst), decode_vex_src(modrm, src, pfx), read_simd(vl, pfx.vex_vvvv)))
  },

  // 0F38 9D: VFNMADD132SS (W0) / VFNMADD132SD (W1)
  157 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FNMAdd, FMA_132, pfx) },

  // 0F38 9E: VFNMSUB132PS (W0) / VFNMSUB132PD (W1)
  158 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, packed_ternop(PT_FNMSub, eb, read_simd(vl, dst), decode_vex_src(modrm, src, pfx), read_simd(vl, pfx.vex_vvvv)))
  },

  // 0F38 9F: VFNMSUB132SS (W0) / VFNMSUB132SD (W1)
  159 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FNMSub, FMA_132, pfx) },

  // 0F38 A6: VFMADDSUB213PS (W0) / VFMADDSUB213PD (W1)
  166 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, avx_fmaddsub(eb, read_simd(vl, pfx.vex_vvvv), read_simd(vl, dst), decode_vex_src(modrm, src, pfx)))
  },

  // 0F38 A7: VFMSUBADD213PS (W0) / VFMSUBADD213PD (W1)
  167 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, avx_fmsubadd(eb, read_simd(vl, pfx.vex_vvvv), read_simd(vl, dst), decode_vex_src(modrm, src, pfx)))
  },

  // 0F38 A8: VFMADD213PS (W0) / VFMADD213PD (W1)
  168 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, packed_ternop(PT_FMAdd, eb, read_simd(vl, pfx.vex_vvvv), read_simd(vl, dst), decode_vex_src(modrm, src, pfx)))
  },

  // 0F38 A9: VFMADD213SS (W0) / VFMADD213SD (W1)
  169 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FMAdd, FMA_213, pfx) },

  // 0F38 AA: VFMSUB213PS (W0) / VFMSUB213PD (W1)
  170 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, packed_ternop(PT_FMSub, eb, read_simd(vl, pfx.vex_vvvv), read_simd(vl, dst), decode_vex_src(modrm, src, pfx)))
  },

  // 0F38 AB: VFMSUB213SS (W0) / VFMSUB213SD (W1)
  171 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FMSub, FMA_213, pfx) },

  // 0F38 AC: VFNMADD213PS (W0) / VFNMADD213PD (W1)
  172 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, packed_ternop(PT_FNMAdd, eb, read_simd(vl, pfx.vex_vvvv), read_simd(vl, dst), decode_vex_src(modrm, src, pfx)))
  },

  // 0F38 AD: VFNMADD213SS (W0) / VFNMADD213SD (W1)
  173 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FNMAdd, FMA_213, pfx) },

  // 0F38 AE: VFNMSUB213PS (W0) / VFNMSUB213PD (W1)
  174 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, packed_ternop(PT_FNMSub, eb, read_simd(vl, pfx.vex_vvvv), read_simd(vl, dst), decode_vex_src(modrm, src, pfx)))
  },

  // 0F38 AF: VFNMSUB213SS (W0) / VFNMSUB213SD (W1)
  175 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FNMSub, FMA_213, pfx) },

  // 0F38 B6: VFMADDSUB231PS (W0) / VFMADDSUB231PD (W1)
  182 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, avx_fmaddsub(eb, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx), read_simd(vl, dst)))
  },

  // 0F38 B7: VFMSUBADD231PS (W0) / VFMSUBADD231PD (W1)
  183 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, avx_fmsubadd(eb, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx), read_simd(vl, dst)))
  },

  // 0F38 B8: VFMADD231PS (W0) / VFMADD231PD (W1)
  184 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, packed_ternop(PT_FMAdd, eb, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx), read_simd(vl, dst)))
  },

  // 0F38 B9: VFMADD231SS (W0) / VFMADD231SD (W1)
  185 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FMAdd, FMA_231, pfx) },

  // 0F38 BA: VFMSUB231PS (W0) / VFMSUB231PD (W1)
  186 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, packed_ternop(PT_FMSub, eb, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx), read_simd(vl, dst)))
  },

  // 0F38 BB: VFMSUB231SS (W0) / VFMSUB231SD (W1)
  187 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FMSub, FMA_231, pfx) },

  // 0F38 BC: VFNMADD231PS (W0) / VFNMADD231PD (W1)
  188 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, packed_ternop(PT_FNMAdd, eb, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx), read_simd(vl, dst)))
  },

  // 0F38 BD: VFNMADD231SS (W0) / VFNMADD231SD (W1)
  189 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FNMAdd, FMA_231, pfx) },

  // 0F38 BE: VFNMSUB231PS (W0) / VFNMSUB231PD (W1)
  190 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    let eb = vex_elem(pfx);
    write_simd(vl, dst, packed_ternop(PT_FNMSub, eb, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx), read_simd(vl, dst)))
  },

  // 0F38 BF: VFNMSUB231SS (W0) / VFNMSUB231SD (W1)
  191 => { if mp != MP_66 then raise_UD(); vex_exec_fma_scalar(PT_FNMSub, FMA_231, pfx) },

  _ => raise_UD(),
  }
}

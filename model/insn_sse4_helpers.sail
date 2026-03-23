// x86-64 — SSE4/AVX Shared Integer Helpers
//
// These helper functions are used by both VEX (insn_vex.sail) and
// EVEX (insn_evex_arith.sail) instruction dispatch. This file must
// be included before both.

// =========================================================================
// SSE4.1 sign-extend helpers (128/256-bit only, for VEX use)
// =========================================================================

val avx_pmovsxbw_128 : qword -> xmmword
function avx_pmovsxbw_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 56) = i * 8;
    let dlo : range(0, 112) = i * 16;
    let v : word = sign_extend(src[(slo + 7)..slo]);
    r[(dlo + 15)..dlo] = v;
  };
  r
}

val avx_pmovsxbw_256 : xmmword -> ymmword
function avx_pmovsxbw_256(src) = avx_pmovsxbw_128(src[127..64]) @ avx_pmovsxbw_128(src[63..0])

val avx_pmovsxbd_128 : dword -> xmmword
function avx_pmovsxbd_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 24) = i * 8;
    let dlo : range(0, 96) = i * 32;
    let v : dword = sign_extend(src[(slo + 7)..slo]);
    r[(dlo + 31)..dlo] = v;
  };
  r
}

val avx_pmovsxbd_256 : qword -> ymmword
function avx_pmovsxbd_256(src) = avx_pmovsxbd_128(src[63..32]) @ avx_pmovsxbd_128(src[31..0])

val avx_pmovsxbq_128 : word -> xmmword
function avx_pmovsxbq_128(src) = {
  let lo : qword = sign_extend(src[7..0]);
  let hi : qword = sign_extend(src[15..8]);
  hi @ lo
}

val avx_pmovsxbq_256 : dword -> ymmword
function avx_pmovsxbq_256(src) = avx_pmovsxbq_128(src[31..16]) @ avx_pmovsxbq_128(src[15..0])

val avx_pmovsxwd_128 : qword -> xmmword
function avx_pmovsxwd_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 48) = i * 16;
    let dlo : range(0, 96) = i * 32;
    let v : dword = sign_extend(src[(slo + 15)..slo]);
    r[(dlo + 31)..dlo] = v;
  };
  r
}

val avx_pmovsxwd_256 : xmmword -> ymmword
function avx_pmovsxwd_256(src) = avx_pmovsxwd_128(src[127..64]) @ avx_pmovsxwd_128(src[63..0])

val avx_pmovsxwq_128 : dword -> xmmword
function avx_pmovsxwq_128(src) = {
  let lo : qword = sign_extend(src[15..0]);
  let hi : qword = sign_extend(src[31..16]);
  hi @ lo
}

val avx_pmovsxwq_256 : qword -> ymmword
function avx_pmovsxwq_256(src) = avx_pmovsxwq_128(src[63..32]) @ avx_pmovsxwq_128(src[31..0])

val avx_pmovsxdq_128 : qword -> xmmword
function avx_pmovsxdq_128(src) = {
  let lo : qword = sign_extend(src[31..0]);
  let hi : qword = sign_extend(src[63..32]);
  hi @ lo
}

val avx_pmovsxdq_256 : xmmword -> ymmword
function avx_pmovsxdq_256(src) = avx_pmovsxdq_128(src[127..64]) @ avx_pmovsxdq_128(src[63..0])

// =========================================================================
// SSE4.1 zero-extend helpers (128/256-bit only, for VEX use)
// =========================================================================

val avx_pmovzxbw_128 : qword -> xmmword
function avx_pmovzxbw_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 56) = i * 8;
    let dlo : range(0, 112) = i * 16;
    let v : word = zero_extend(src[(slo + 7)..slo]);
    r[(dlo + 15)..dlo] = v;
  };
  r
}

val avx_pmovzxbw_256 : xmmword -> ymmword
function avx_pmovzxbw_256(src) = avx_pmovzxbw_128(src[127..64]) @ avx_pmovzxbw_128(src[63..0])

val avx_pmovzxbd_128 : dword -> xmmword
function avx_pmovzxbd_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 24) = i * 8;
    let dlo : range(0, 96) = i * 32;
    let v : dword = zero_extend(src[(slo + 7)..slo]);
    r[(dlo + 31)..dlo] = v;
  };
  r
}

val avx_pmovzxbd_256 : qword -> ymmword
function avx_pmovzxbd_256(src) = avx_pmovzxbd_128(src[63..32]) @ avx_pmovzxbd_128(src[31..0])

val avx_pmovzxbq_128 : word -> xmmword
function avx_pmovzxbq_128(src) = {
  let lo : qword = zero_extend(src[7..0]);
  let hi : qword = zero_extend(src[15..8]);
  hi @ lo
}

val avx_pmovzxbq_256 : dword -> ymmword
function avx_pmovzxbq_256(src) = avx_pmovzxbq_128(src[31..16]) @ avx_pmovzxbq_128(src[15..0])

val avx_pmovzxwd_128 : qword -> xmmword
function avx_pmovzxwd_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 48) = i * 16;
    let dlo : range(0, 96) = i * 32;
    let v : dword = zero_extend(src[(slo + 15)..slo]);
    r[(dlo + 31)..dlo] = v;
  };
  r
}

val avx_pmovzxwd_256 : xmmword -> ymmword
function avx_pmovzxwd_256(src) = avx_pmovzxwd_128(src[127..64]) @ avx_pmovzxwd_128(src[63..0])

val avx_pmovzxwq_128 : dword -> xmmword
function avx_pmovzxwq_128(src) = {
  let lo : qword = zero_extend(src[15..0]);
  let hi : qword = zero_extend(src[31..16]);
  hi @ lo
}

val avx_pmovzxwq_256 : qword -> ymmword
function avx_pmovzxwq_256(src) = avx_pmovzxwq_128(src[63..32]) @ avx_pmovzxwq_128(src[31..0])

val avx_pmovzxdq_128 : qword -> xmmword
function avx_pmovzxdq_128(src) = {
  let lo : qword = zero_extend(src[31..0]);
  let hi : qword = zero_extend(src[63..32]);
  hi @ lo
}

val avx_pmovzxdq_256 : xmmword -> ymmword
function avx_pmovzxdq_256(src) = avx_pmovzxdq_128(src[127..64]) @ avx_pmovzxdq_128(src[63..0])

// =========================================================================
// SSE4.1 min/max signed/unsigned helpers (128/256-bit only, for VEX use)
// =========================================================================

val avx_pminsb_128 : (xmmword, xmmword) -> xmmword
function avx_pminsb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    let va = a[(lo + 7)..lo];
    let vb = b[(lo + 7)..lo];
    r[(lo + 7)..lo] = min_s(va, vb);
  };
  r
}

val avx_pminsb_256 : (ymmword, ymmword) -> ymmword
function avx_pminsb_256(a, b) =
  avx_pminsb_128(a[255..128], b[255..128]) @ avx_pminsb_128(a[127..0], b[127..0])

val avx_pminsd_128 : (xmmword, xmmword) -> xmmword
function avx_pminsd_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let va = a[(lo + 31)..lo];
    let vb = b[(lo + 31)..lo];
    r[(lo + 31)..lo] = min_s(va, vb);
  };
  r
}

val avx_pminsd_256 : (ymmword, ymmword) -> ymmword
function avx_pminsd_256(a, b) =
  avx_pminsd_128(a[255..128], b[255..128]) @ avx_pminsd_128(a[127..0], b[127..0])

val avx_pminud_128 : (xmmword, xmmword) -> xmmword
function avx_pminud_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let av : dword = a[(lo + 31)..lo];
    let bv : dword = b[(lo + 31)..lo];
    r[(lo + 31)..lo] = min_u(av, bv)
  };
  r
}

val avx_pminud_256 : (ymmword, ymmword) -> ymmword
function avx_pminud_256(a, b) =
  avx_pminud_128(a[255..128], b[255..128]) @ avx_pminud_128(a[127..0], b[127..0])

val avx_pmaxsb_128 : (xmmword, xmmword) -> xmmword
function avx_pmaxsb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    let va = a[(lo + 7)..lo];
    let vb = b[(lo + 7)..lo];
    r[(lo + 7)..lo] = max_s(va, vb);
  };
  r
}

val avx_pmaxsb_256 : (ymmword, ymmword) -> ymmword
function avx_pmaxsb_256(a, b) =
  avx_pmaxsb_128(a[255..128], b[255..128]) @ avx_pmaxsb_128(a[127..0], b[127..0])

val avx_pmaxsd_128 : (xmmword, xmmword) -> xmmword
function avx_pmaxsd_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let va = a[(lo + 31)..lo];
    let vb = b[(lo + 31)..lo];
    r[(lo + 31)..lo] = max_s(va, vb);
  };
  r
}

val avx_pmaxsd_256 : (ymmword, ymmword) -> ymmword
function avx_pmaxsd_256(a, b) =
  avx_pmaxsd_128(a[255..128], b[255..128]) @ avx_pmaxsd_128(a[127..0], b[127..0])

val avx_pmaxud_128 : (xmmword, xmmword) -> xmmword
function avx_pmaxud_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let av : dword = a[(lo + 31)..lo];
    let bv : dword = b[(lo + 31)..lo];
    r[(lo + 31)..lo] = max_u(av, bv)
  };
  r
}

val avx_pmaxud_256 : (ymmword, ymmword) -> ymmword
function avx_pmaxud_256(a, b) =
  avx_pmaxud_128(a[255..128], b[255..128]) @ avx_pmaxud_128(a[127..0], b[127..0])

// =========================================================================
// SSE4.1 multiply helpers (128/256-bit only, for VEX use)
// =========================================================================

val avx_pmuldq_128 : (xmmword, xmmword) -> xmmword
function avx_pmuldq_128(a, b) = {
  let lo_prod : bits(64) = to_bits_truncate(signed(a[31..0]) * signed(b[31..0]));
  let hi_prod : bits(64) = to_bits_truncate(signed(a[95..64]) * signed(b[95..64]));
  hi_prod @ lo_prod
}

val avx_pmuldq_256 : (ymmword, ymmword) -> ymmword
function avx_pmuldq_256(a, b) =
  avx_pmuldq_128(a[255..128], b[255..128]) @ avx_pmuldq_128(a[127..0], b[127..0])

val avx_pmulld_128 : (xmmword, xmmword) -> xmmword
function avx_pmulld_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let prod : int = signed(a[(lo + 31)..lo]) * signed(b[(lo + 31)..lo]);
    r[(lo + 31)..lo] = to_bits_truncate(prod);
  };
  r
}

val avx_pmulld_256 : (ymmword, ymmword) -> ymmword
function avx_pmulld_256(a, b) =
  avx_pmulld_128(a[255..128], b[255..128]) @ avx_pmulld_128(a[127..0], b[127..0])

// =========================================================================
// VPACKUSDW: pack dwords to words with unsigned saturation (for VEX use)
// =========================================================================

val avx_packusdw_128 : (xmmword, xmmword) -> xmmword
function avx_packusdw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let src_lo : range(0, 96) = i * 32;
    let dst_lo : range(0, 48) = i * 16;
    r[(dst_lo + 15)..dst_lo] = sat_su16(a[(src_lo + 31)..src_lo]);
  };
  foreach (i from 0 to 3) {
    let src_lo : range(0, 96) = i * 32;
    let dst_lo : range(64, 112) = 64 + i * 16;
    r[(dst_lo + 15)..dst_lo] = sat_su16(b[(src_lo + 31)..src_lo]);
  };
  r
}

val avx_packusdw_256 : (ymmword, ymmword) -> ymmword
function avx_packusdw_256(a, b) =
  avx_packusdw_128(a[255..128], b[255..128]) @ avx_packusdw_128(a[127..0], b[127..0])

// =========================================================================
// Gather address computation (shared by VEX and EVEX gather instructions)
// =========================================================================

val gather_addr : (qword, dword, range(0, 3)) -> qword
function gather_addr(base, idx32, scale) = {
  let offset : qword = sign_extend(idx32);
  match scale {
    0 => base + offset,
    1 => base + (offset << 1),
    2 => base + (offset << 2),
    3 => base + (offset << 3),
  }
}

val gather_addr_q : (qword, qword, range(0, 3)) -> qword
function gather_addr_q(base, idx64, scale) = {
  match scale {
    0 => base + idx64,
    1 => base + (idx64 << 1),
    2 => base + (idx64 << 2),
    3 => base + (idx64 << 3),
  }
}

// VEX VSIB decoder: decode SIB for VEX gather instructions.
// Returns (base_addr, vector_index_reg, scale).
// Unlike EVEX, index register is only 4-bit (REX.X extends it).
val decode_vsib_vex : (byte, Prefixes) -> VSIB
function decode_vsib_vex(modrm, pfx) = {
  let modbits : range(0, 3) = unsigned(modrm[7..6]);
  let sib = fetch_byte();
  let scale : range(0, 3) = unsigned(sib[7..6]);
  let index_raw : range(0, 7) = unsigned(sib[5..3]);
  let base_raw : range(0, 7) = unsigned(sib[2..0]);

  let base_idx : gpr_idx = extend_reg(base_raw, pfx.rex_b);
  let vidx : simd_idx = extend_reg(index_raw, pfx.rex_x);

  let base_val : qword =
    if base_raw == 5 & modbits == 0 then {
      let b0 = fetch_byte();
      let b1 = fetch_byte();
      let b2 = fetch_byte();
      let b3 = fetch_byte();
      sign_extend(b3 @ b2 @ b1 @ b0)
    } else if modbits == 0 then {
      read_gpr64(base_idx)
    } else if modbits == 1 then {
      let d8 = fetch_byte();
      read_gpr64(base_idx) + sign_extend(d8)
    } else {
      let b0 = fetch_byte();
      let b1 = fetch_byte();
      let b2 = fetch_byte();
      let b3 = fetch_byte();
      read_gpr64(base_idx) + sign_extend(b3 @ b2 @ b1 @ b0)
    };

  struct { vsib_base = base_val, vsib_vidx = vidx, vsib_scale = scale }
}


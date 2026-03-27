// x86-64 — SSE4/AVX Shared Integer Helpers
//
// These helper functions are used by both VEX (insn_vex.sail) and
// EVEX (insn_evex_arith.sail) instruction dispatch. This file must
// be included before both.

// =========================================================================
// SSE4.1 sign-extend helpers (polymorphic 128/256/512-bit)
// =========================================================================

// VPMOVSXBW: sign-extend packed bytes to words
val avx_pmovsxbw : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_pmovsxbw(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 16 - 1)) {
    let slo = i * 8;
    let dlo = i * 16;
    r[(dlo + 15)..dlo] = sign_extend(src[(slo + 7)..slo])
  };
  r
}

// VPMOVSXBD: sign-extend packed bytes to dwords
val avx_pmovsxbd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_pmovsxbd(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) {
    let slo = i * 8;
    let dlo = i * 32;
    r[(dlo + 31)..dlo] = sign_extend(src[(slo + 7)..slo])
  };
  r
}

// VPMOVSXBQ: sign-extend packed bytes to qwords
val avx_pmovsxbq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_pmovsxbq(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) {
    let slo = i * 8;
    let dlo = i * 64;
    r[(dlo + 63)..dlo] = sign_extend(src[(slo + 7)..slo])
  };
  r
}

// VPMOVSXWD: sign-extend packed words to dwords
val avx_pmovsxwd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_pmovsxwd(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) {
    let slo = i * 16;
    let dlo = i * 32;
    r[(dlo + 31)..dlo] = sign_extend(src[(slo + 15)..slo])
  };
  r
}

// VPMOVSXWQ: sign-extend packed words to qwords
val avx_pmovsxwq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_pmovsxwq(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) {
    let slo = i * 16;
    let dlo = i * 64;
    r[(dlo + 63)..dlo] = sign_extend(src[(slo + 15)..slo])
  };
  r
}

// VPMOVSXDQ: sign-extend packed dwords to qwords
val avx_pmovsxdq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_pmovsxdq(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) {
    let slo = i * 32;
    let dlo = i * 64;
    r[(dlo + 63)..dlo] = sign_extend(src[(slo + 31)..slo])
  };
  r
}

// =========================================================================
// SSE4.1 zero-extend helpers (polymorphic 128/256/512-bit)
// =========================================================================

// VPMOVZXBW: zero-extend packed bytes to words
val avx_pmovzxbw : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_pmovzxbw(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 16 - 1)) {
    let slo = i * 8;
    let dlo = i * 16;
    r[(dlo + 15)..dlo] = zero_extend(src[(slo + 7)..slo])
  };
  r
}

// VPMOVZXBD: zero-extend packed bytes to dwords
val avx_pmovzxbd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_pmovzxbd(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) {
    let slo = i * 8;
    let dlo = i * 32;
    r[(dlo + 31)..dlo] = zero_extend(src[(slo + 7)..slo])
  };
  r
}

// VPMOVZXBQ: zero-extend packed bytes to qwords
val avx_pmovzxbq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_pmovzxbq(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) {
    let slo = i * 8;
    let dlo = i * 64;
    r[(dlo + 63)..dlo] = zero_extend(src[(slo + 7)..slo])
  };
  r
}

// VPMOVZXWD: zero-extend packed words to dwords
val avx_pmovzxwd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_pmovzxwd(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 32 - 1)) {
    let slo = i * 16;
    let dlo = i * 32;
    r[(dlo + 31)..dlo] = zero_extend(src[(slo + 15)..slo])
  };
  r
}

// VPMOVZXWQ: zero-extend packed words to qwords
val avx_pmovzxwq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_pmovzxwq(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) {
    let slo = i * 16;
    let dlo = i * 64;
    r[(dlo + 63)..dlo] = zero_extend(src[(slo + 15)..slo])
  };
  r
}

// VPMOVZXDQ: zero-extend packed dwords to qwords
val avx_pmovzxdq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl)) -> bits('vl)
function avx_pmovzxdq(vl, src) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 64 - 1)) {
    let slo = i * 32;
    let dlo = i * 64;
    r[(dlo + 63)..dlo] = zero_extend(src[(slo + 31)..slo])
  };
  r
}

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
  let sib = fetch(1);
  let scale : range(0, 3) = unsigned(sib[7..6]);

  let base_idx : gpr_idx = unsigned(pfx.rex_b @ sib[2..0]);
  let vidx : simd_idx = unsigned(pfx.rex_x @ sib[5..3]);

  let base_val : qword =
    if sib[2..0] == 0b101 & modbits == 0 then {
      let b0 = fetch(1);
      let b1 = fetch(1);
      let b2 = fetch(1);
      let b3 = fetch(1);
      sign_extend(b3 @ b2 @ b1 @ b0)
    } else if modbits == 0 then {
      v(64, base_idx)
    } else if modbits == 1 then {
      let d8 = fetch(1);
      v(64, base_idx) + sign_extend(d8)
    } else {
      let b0 = fetch(1);
      let b1 = fetch(1);
      let b2 = fetch(1);
      let b3 = fetch(1);
      v(64, base_idx) + sign_extend(b3 @ b2 @ b1 @ b0)
    };

  struct { vsib_base = base_val, vsib_vidx = vidx, vsib_scale = scale }
}


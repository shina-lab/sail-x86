// x86-64 — EVEX Integer Operations (0F map)
//
// Packed integer arithmetic, logic, pack/unpack, shift, and compare.
// Called from dispatch_evex_0f in insn_evex.sail.

// paddb/paddw/paddd/paddq/psubb/psubw/psubd/psubq: EVEX dispatch uses packed_binop directly.
// The _128 lane helpers remain in insn_vex.sail for VEX/SSE dispatch.

// =========================================================================
// AVX-512 writemask helpers
//
// Per SDM: if aaa=0 (k0), no masking (all elements written).
// Otherwise, each bit of the mask register controls one element.
// z=0: merging (unmasked elements keep old dest value)
// z=1: zeroing (unmasked elements become zero)
// =========================================================================

// Apply 16-bit writemask to a 512-bit ZMM result (32-bit elements, 16 lanes).
// mask_val is the low 16 bits of the mask register.
// old_dst is the previous destination value (for merging).

// =========================================================================
// Polymorphic compare-to-mask helpers for EVEX compare instructions.
// Each compares 'vl/'eb elements and produces a qword mask (one bit per element).
// =========================================================================

val avx_pcmpeq_mask : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {8, 16, 32, 64}.
  (int('eb), bits('vl), bits('vl)) -> qword
function avx_pcmpeq_mask(eb, a, b) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[i] = is_eq(a[(lo + 'eb - 1)..lo], b[(lo + 'eb - 1)..lo]);
  };
  r
}

val avx_pcmpgt_mask : forall 'vl 'eb, 'vl in {128, 256, 512} & 'eb in {8, 16, 32, 64}.
  (int('eb), bits('vl), bits('vl)) -> qword
function avx_pcmpgt_mask(eb, a, b) = {
  var r : qword = zeros();
  foreach (i from 0 to ('vl / 'eb - 1)) {
    let lo = i * 'eb;
    r[i] = is_gt(a[(lo + 'eb - 1)..lo], b[(lo + 'eb - 1)..lo]);
  };
  r
}

// =========================================================================
// VPMULUDQ: multiply unsigned dwords → unsigned qwords
// For each 64-bit lane: result = src1[31:0] * src2[31:0] (unsigned)
// =========================================================================

val avx_pmuludq_lane : (xmmword, xmmword) -> xmmword
function avx_pmuludq_lane(a, b) = {
  let prod1 : qword = to_bits(64, unsigned(a[31..0]) * unsigned(b[31..0]));
  let prod0 : qword = to_bits(64, unsigned(a[95..64]) * unsigned(b[95..64]));
  prod0 @ prod1
}

val avx_pmuludq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_pmuludq(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_pmuludq_lane(a[(lo + 127)..lo], b[(lo + 127)..lo])
  };
  r
}

// =========================================================================
// VPMADDWD: multiply and add packed integers
// Per 128-bit lane: for each pair of words, multiply signed and add adjacent products
// =========================================================================

val avx_pmaddwd_lane : (xmmword, xmmword) -> xmmword
function avx_pmaddwd_lane(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let wlo : range(0, 96) = i * 32;
    let w0 = signed(a[(wlo + 15)..wlo]) * signed(b[(wlo + 15)..wlo]);
    let w1 = signed(a[(wlo + 31)..(wlo + 16)]) * signed(b[(wlo + 31)..(wlo + 16)]);
    r[(wlo + 31)..wlo] = get_slice_int(32, w0 + w1, 0);
  };
  r
}

val avx_pmaddwd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_pmaddwd(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_pmaddwd_lane(a[(lo + 127)..lo], b[(lo + 127)..lo])
  };
  r
}

// =========================================================================
// VPSADBW: sum of absolute differences of unsigned bytes
// Per 64-bit group: sum |a[i] - b[i]| for 8 byte pairs → 16-bit result in low word
// =========================================================================

val avx_psadbw_64 : (bits(64), bits(64)) -> bits(64)
function avx_psadbw_64(a, b) = {
  var sum : int = 0;
  foreach (i from 0 to 7) {
    let lo : range(0, 56) = i * 8;
    sum = sum + abs_diff8(a[(lo + 7)..lo], b[(lo + 7)..lo]);
  };
  zero_extend(get_slice_int(16, sum, 0))
}

val avx_psadbw_lane : (xmmword, xmmword) -> xmmword
function avx_psadbw_lane(a, b) =
  avx_psadbw_64(a[127..64], b[127..64]) @ avx_psadbw_64(a[63..0], b[63..0])

val avx_psadbw : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_psadbw(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_psadbw_lane(a[(lo + 127)..lo], b[(lo + 127)..lo])
  };
  r
}

// =========================================================================
// VPUNPCKLBW: interleave low bytes from each 128-bit lane
// For each 128-bit lane: dst[0]=a[0], dst[1]=b[0], dst[2]=a[1], dst[3]=b[1], ...
// =========================================================================

val avx_punpcklbw_lane : (xmmword, xmmword) -> xmmword
function avx_punpcklbw_lane(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let src_lo : range(0, 56) = i * 8;
    let dst_lo : range(0, 112) = i * 16;
    r[(dst_lo + 7)..dst_lo] = a[(src_lo + 7)..src_lo];
    r[(dst_lo + 15)..(dst_lo + 8)] = b[(src_lo + 7)..src_lo];
  };
  r
}

val avx_punpcklbw : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_punpcklbw(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_punpcklbw_lane(a[(lo + 127)..lo], b[(lo + 127)..lo])
  };
  r
}

// VPUNPCKLWD: interleave low words from each 128-bit lane
val avx_punpcklwd_lane : (xmmword, xmmword) -> xmmword
function avx_punpcklwd_lane(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let src_lo : range(0, 48) = i * 16;
    let dst_lo : range(0, 96) = i * 32;
    r[(dst_lo + 15)..dst_lo] = a[(src_lo + 15)..src_lo];
    r[(dst_lo + 31)..(dst_lo + 16)] = b[(src_lo + 15)..src_lo];
  };
  r
}

val avx_punpcklwd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_punpcklwd(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_punpcklwd_lane(a[(lo + 127)..lo], b[(lo + 127)..lo])
  };
  r
}

// VPUNPCKLDQ: interleave low dwords from each 128-bit lane
val avx_punpckldq_lane : (xmmword, xmmword) -> xmmword
function avx_punpckldq_lane(a, b) =
  b[63..32] @ a[63..32] @ b[31..0] @ a[31..0]

// VPUNPCKLQDQ: interleave low qwords from each 128-bit lane
val avx_punpcklqdq_lane : (xmmword, xmmword) -> xmmword
function avx_punpcklqdq_lane(a, b) =
  b[63..0] @ a[63..0]

// =========================================================================
// VPUNPCKHBW: interleave high bytes from each 128-bit lane
// =========================================================================

val avx_punpckhbw_lane : (xmmword, xmmword) -> xmmword
function avx_punpckhbw_lane(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let src_lo : range(0, 120) = i * 8 + 64;
    let dst_lo : range(0, 112) = i * 16;
    r[(dst_lo + 7)..dst_lo] = a[(src_lo + 7)..src_lo];
    r[(dst_lo + 15)..(dst_lo + 8)] = b[(src_lo + 7)..src_lo];
  };
  r
}

val avx_punpckhbw : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_punpckhbw(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_punpckhbw_lane(a[(lo + 127)..lo], b[(lo + 127)..lo])
  };
  r
}

val avx_punpcklqdq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_punpcklqdq(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_punpcklqdq_lane(a[(lo + 127)..lo], b[(lo + 127)..lo])
  };
  r
}

val avx_punpckldq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_punpckldq(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_punpckldq_lane(a[(lo + 127)..lo], b[(lo + 127)..lo])
  };
  r
}

// VPUNPCKHWD: interleave high words from each 128-bit lane
val avx_punpckhwd_lane : (xmmword, xmmword) -> xmmword
function avx_punpckhwd_lane(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let src_lo : range(0, 112) = i * 16 + 64;
    let dst_lo : range(0, 96) = i * 32;
    r[(dst_lo + 15)..dst_lo] = a[(src_lo + 15)..src_lo];
    r[(dst_lo + 31)..(dst_lo + 16)] = b[(src_lo + 15)..src_lo];
  };
  r
}

val avx_punpckhwd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_punpckhwd(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_punpckhwd_lane(a[(lo + 127)..lo], b[(lo + 127)..lo])
  };
  r
}

// VPUNPCKHDQ: interleave high dwords from each 128-bit lane
val avx_punpckhdq_lane : (xmmword, xmmword) -> xmmword
function avx_punpckhdq_lane(a, b) =
  b[127..96] @ a[127..96] @ b[95..64] @ a[95..64]

// VPUNPCKHQDQ: interleave high qwords from each 128-bit lane
val avx_punpckhqdq_lane : (xmmword, xmmword) -> xmmword
function avx_punpckhqdq_lane(a, b) =
  b[127..64] @ a[127..64]

// =========================================================================
// VPACKSSWB: pack signed words to signed bytes with saturation
// Per 128-bit lane: 8 words from src1 → low 8 bytes, 8 words from src2 → high 8 bytes
// =========================================================================

val avx_packsswb_lane : (xmmword, xmmword) -> xmmword
function avx_packsswb_lane(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let src_lo : range(0, 112) = i * 16;
    r[(i * 8 + 7)..(i * 8)] = sat_s8(a[(src_lo + 15)..src_lo]);
    r[(i * 8 + 71)..(i * 8 + 64)] = sat_s8(b[(src_lo + 15)..src_lo]);
  };
  r
}

val avx_packsswb : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_packsswb(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_packsswb_lane(a[(lo + 127)..lo], b[(lo + 127)..lo])
  };
  r
}

val avx_punpckhqdq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_punpckhqdq(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_punpckhqdq_lane(a[(lo + 127)..lo], b[(lo + 127)..lo])
  };
  r
}

val avx_punpckhdq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_punpckhdq(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_punpckhdq_lane(a[(lo + 127)..lo], b[(lo + 127)..lo])
  };
  r
}

// VPACKSSDW: pack signed dwords to signed words with saturation
val avx_packssdw_lane : (xmmword, xmmword) -> xmmword
function avx_packssdw_lane(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let src_lo : range(0, 96) = i * 32;
    r[(i * 16 + 15)..(i * 16)] = sat_s16(a[(src_lo + 31)..src_lo]);
    r[(i * 16 + 79)..(i * 16 + 64)] = sat_s16(b[(src_lo + 31)..src_lo]);
  };
  r
}

val avx_packssdw : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_packssdw(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_packssdw_lane(a[(lo + 127)..lo], b[(lo + 127)..lo])
  };
  r
}

// VPACKUSWB: pack signed words to unsigned bytes with saturation
val avx_packuswb_lane : (xmmword, xmmword) -> xmmword
function avx_packuswb_lane(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let src_lo : range(0, 112) = i * 16;
    r[(i * 8 + 7)..(i * 8)] = sat_su8(a[(src_lo + 15)..src_lo]);
    r[(i * 8 + 71)..(i * 8 + 64)] = sat_su8(b[(src_lo + 15)..src_lo]);
  };
  r
}

val avx_packuswb : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits('vl)) -> bits('vl)
function avx_packuswb(vl, a, b) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_packuswb_lane(a[(lo + 127)..lo], b[(lo + 127)..lo])
  };
  r
}

// =========================================================================
// VPSHUFD: shuffle dwords within each 128-bit lane by imm8
// =========================================================================

val avx_pshufd_lane : (xmmword, byte) -> xmmword
function avx_pshufd_lane(src, imm) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let sel_bits : range(0, 6) = i * 2;
    let sel : range(0, 3) = unsigned(imm[(sel_bits + 1)..sel_bits]);
    let src_lo : range(0, 96) = sel * 32;
    let dst_lo : range(0, 96) = i * 32;
    r[(dst_lo + 31)..dst_lo] = src[(src_lo + 31)..src_lo];
  };
  r
}

val avx_pshufd : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits(8)) -> bits('vl)
function avx_pshufd(vl, src, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_pshufd_lane(src[(lo + 127)..lo], imm)
  };
  r
}

// VPSHUFHW: shuffle high words within each 128-bit lane, low qword unchanged
val avx_pshufhw_lane : (xmmword, byte) -> xmmword
function avx_pshufhw_lane(src, imm) = {
  var r : xmmword = zeros();
  r[63..0] = src[63..0];
  foreach (i from 0 to 3) {
    let sel_bits : range(0, 6) = i * 2;
    let sel : range(0, 3) = unsigned(imm[(sel_bits + 1)..sel_bits]);
    let src_lo : range(0, 112) = sel * 16 + 64;
    let dst_lo : range(0, 112) = i * 16 + 64;
    r[(dst_lo + 15)..dst_lo] = src[(src_lo + 15)..src_lo];
  };
  r
}

val avx_pshufhw : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits(8)) -> bits('vl)
function avx_pshufhw(vl, src, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_pshufhw_lane(src[(lo + 127)..lo], imm)
  };
  r
}

// VPSHUFLW: shuffle low words within each 128-bit lane, high qword unchanged
val avx_pshuflw_lane : (xmmword, byte) -> xmmword
function avx_pshuflw_lane(src, imm) = {
  var r : xmmword = zeros();
  r[127..64] = src[127..64];
  foreach (i from 0 to 3) {
    let sel_bits : range(0, 6) = i * 2;
    let sel : range(0, 3) = unsigned(imm[(sel_bits + 1)..sel_bits]);
    let src_lo : range(0, 48) = sel * 16;
    let dst_lo : range(0, 48) = i * 16;
    r[(dst_lo + 15)..dst_lo] = src[(src_lo + 15)..src_lo];
  };
  r
}

val avx_pshuflw : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), bits(8)) -> bits('vl)
function avx_pshuflw(vl, src, imm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_pshuflw_lane(src[(lo + 127)..lo], imm)
  };
  r
}

// =========================================================================
// Shift by immediate: VPSRLW/D/Q, VPSLLW/D/Q, VPSRAW/D, VPSRAQ
// If count >= element_size, result is 0 (logical) or sign-extended (arithmetic)
// =========================================================================

// VPSRLW: logical right shift words by imm
val avx_psrlw_imm_lane : (xmmword, range(0, 255)) -> xmmword
function avx_psrlw_imm_lane(a, count) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = a[(lo + 15)..lo] >> count;
  };
  r
}

val avx_psrlw_imm : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), range(0, 255)) -> bits('vl)
function avx_psrlw_imm(vl, a, count) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_psrlw_imm_lane(a[(lo + 127)..lo], count)
  };
  r
}

// VPSRLD: logical right shift dwords by imm
val avx_psrld_imm_lane : (xmmword, range(0, 255)) -> xmmword
function avx_psrld_imm_lane(a, count) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = a[(lo + 31)..lo] >> count;
  };
  r
}

val avx_psrld_imm : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), range(0, 255)) -> bits('vl)
function avx_psrld_imm(vl, a, count) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_psrld_imm_lane(a[(lo + 127)..lo], count)
  };
  r
}

// VPSRLQ: logical right shift qwords by imm
val avx_psrlq_imm_lane : (xmmword, range(0, 255)) -> xmmword
function avx_psrlq_imm_lane(a, count) = {
  var r : xmmword = zeros();
  r[63..0] = a[63..0] >> count;
  r[127..64] = a[127..64] >> count;
  r
}

val avx_psrlq_imm : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), range(0, 255)) -> bits('vl)
function avx_psrlq_imm(vl, a, count) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_psrlq_imm_lane(a[(lo + 127)..lo], count)
  };
  r
}

// VPSLLW: logical left shift words by imm
val avx_psllw_imm_lane : (xmmword, range(0, 255)) -> xmmword
function avx_psllw_imm_lane(a, count) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = a[(lo + 15)..lo] << count;
  };
  r
}

val avx_psllw_imm : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), range(0, 255)) -> bits('vl)
function avx_psllw_imm(vl, a, count) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_psllw_imm_lane(a[(lo + 127)..lo], count)
  };
  r
}

// VPSLLD: logical left shift dwords by imm
val avx_pslld_imm_lane : (xmmword, range(0, 255)) -> xmmword
function avx_pslld_imm_lane(a, count) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = a[(lo + 31)..lo] << count;
  };
  r
}

val avx_pslld_imm : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), range(0, 255)) -> bits('vl)
function avx_pslld_imm(vl, a, count) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_pslld_imm_lane(a[(lo + 127)..lo], count)
  };
  r
}

// VPSLLQ: logical left shift qwords by imm
val avx_psllq_imm_lane : (xmmword, range(0, 255)) -> xmmword
function avx_psllq_imm_lane(a, count) = {
  var r : xmmword = zeros();
  r[63..0] = a[63..0] << count;
  r[127..64] = a[127..64] << count;
  r
}

val avx_psllq_imm : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), range(0, 255)) -> bits('vl)
function avx_psllq_imm(vl, a, count) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_psllq_imm_lane(a[(lo + 127)..lo], count)
  };
  r
}

// VPSRAW: arithmetic right shift words by imm
val avx_psraw_imm : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), range(0, 255)) -> bits('vl)
function avx_psraw_imm(vl, a, count) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 16 - 1)) {
    let lo = i * 16;
    r[(lo + 15)..lo] = a[(lo + 15)..lo] >>> count
  };
  r
}

// VPSRAD: arithmetic right shift dwords by imm
val arith_shr_dwords_128b : (xmmword, range(0, 255)) -> xmmword
function arith_shr_dwords_128b(a, count) =
  (a[127..96] >>> count) @
  (a[95..64] >>> count) @
  (a[63..32] >>> count) @
  (a[31..0] >>> count)

val arith_shr_dwords_256b : (ymmword, range(0, 255)) -> ymmword
function arith_shr_dwords_256b(a, count) =
  (a[255..224] >>> count) @
  (a[223..192] >>> count) @
  (a[191..160] >>> count) @
  (a[159..128] >>> count) @
  (a[127..96] >>> count) @
  (a[95..64] >>> count) @
  (a[63..32] >>> count) @
  (a[31..0] >>> count)

val arith_shr_dwords_512b : (zmmword, range(0, 255)) -> zmmword
function arith_shr_dwords_512b(a, count) =
  arith_shr_dwords_256b(a[511..256], count) @ arith_shr_dwords_256b(a[255..0], count)

// VPSRAQ: arithmetic right shift qwords by imm (AVX-512 new)
val arith_shr_qwords_128b : (xmmword, range(0, 255)) -> xmmword
function arith_shr_qwords_128b(a, count) =
  (a[127..64] >>> count) @
  (a[63..0] >>> count)

val arith_shr_qwords_256b : (ymmword, range(0, 255)) -> ymmword
function arith_shr_qwords_256b(a, count) =
  (a[255..192] >>> count) @
  (a[191..128] >>> count) @
  (a[127..64] >>> count) @
  (a[63..0] >>> count)

val arith_shr_qwords_512b : (zmmword, range(0, 255)) -> zmmword
function arith_shr_qwords_512b(a, count) =
  (a[511..448] >>> count) @
  (a[447..384] >>> count) @
  (a[383..320] >>> count) @
  (a[319..256] >>> count) @
  (a[255..192] >>> count) @
  (a[191..128] >>> count) @
  (a[127..64] >>> count) @
  (a[63..0] >>> count)

// VPSLLDQ: byte shift left per 128-bit lane
val avx_pslldq_lane : (xmmword, range(0, 255)) -> xmmword
function avx_pslldq_lane(a, count) = a << (count * 8)

val avx_pslldq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), range(0, 255)) -> bits('vl)
function avx_pslldq(vl, a, count) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_pslldq_lane(a[(lo + 127)..lo], count)
  };
  r
}

// VPSRLDQ: byte shift right per 128-bit lane
val avx_psrldq_lane : (xmmword, range(0, 255)) -> xmmword
function avx_psrldq_lane(a, count) = a >> (count * 8)

val avx_psrldq : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), range(0, 255)) -> bits('vl)
function avx_psrldq(vl, a, count) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_psrldq_lane(a[(lo + 127)..lo], count)
  };
  r
}

// =========================================================================
// VPROLD/Q: rotate left dwords/qwords (immediate via broadcast count vector)
// VPRORD/Q: rotate right dwords/qwords
// =========================================================================

val evex_vprold_128 : (xmmword, xmmword) -> xmmword
function evex_vprold_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let c : range(0, 31) = unsigned(cnt[(lo + 4)..lo]);
    let elem : bits(32) = src[(lo + 31)..lo];
    r[(lo + 31)..lo] = shift_bits_left(elem, cnt[(lo + 4)..lo]) | shift_bits_right(elem, to_bits_truncate(5, 32 - c));
  };
  r
}

val evex_vprold_256 : (ymmword, ymmword) -> ymmword
function evex_vprold_256(a, b) =
  evex_vprold_128(a[255..128], b[255..128]) @ evex_vprold_128(a[127..0], b[127..0])

val evex_vprold_512 : (zmmword, zmmword) -> zmmword
function evex_vprold_512(a, b) =
  evex_vprold_256(a[511..256], b[511..256]) @ evex_vprold_256(a[255..0], b[255..0])

val evex_vprord_128 : (xmmword, xmmword) -> xmmword
function evex_vprord_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let c : range(0, 31) = unsigned(cnt[(lo + 4)..lo]);
    let elem : bits(32) = src[(lo + 31)..lo];
    r[(lo + 31)..lo] = shift_bits_right(elem, cnt[(lo + 4)..lo]) | shift_bits_left(elem, to_bits_truncate(5, 32 - c));
  };
  r
}

val evex_vprord_256 : (ymmword, ymmword) -> ymmword
function evex_vprord_256(a, b) =
  evex_vprord_128(a[255..128], b[255..128]) @ evex_vprord_128(a[127..0], b[127..0])

val evex_vprord_512 : (zmmword, zmmword) -> zmmword
function evex_vprord_512(a, b) =
  evex_vprord_256(a[511..256], b[511..256]) @ evex_vprord_256(a[255..0], b[255..0])

val evex_vprolq_128 : (xmmword, xmmword) -> xmmword
function evex_vprolq_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let c : range(0, 63) = unsigned(cnt[(lo + 5)..lo]);
    let elem : bits(64) = src[(lo + 63)..lo];
    r[(lo + 63)..lo] = shift_bits_left(elem, cnt[(lo + 5)..lo]) | shift_bits_right(elem, to_bits_truncate(6, 64 - c));
  };
  r
}

val evex_vprolq_256 : (ymmword, ymmword) -> ymmword
function evex_vprolq_256(a, b) =
  evex_vprolq_128(a[255..128], b[255..128]) @ evex_vprolq_128(a[127..0], b[127..0])

val evex_vprolq_512 : (zmmword, zmmword) -> zmmword
function evex_vprolq_512(a, b) =
  evex_vprolq_256(a[511..256], b[511..256]) @ evex_vprolq_256(a[255..0], b[255..0])

val evex_vprorq_128 : (xmmword, xmmword) -> xmmword
function evex_vprorq_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let c : range(0, 63) = unsigned(cnt[(lo + 5)..lo]);
    let elem : bits(64) = src[(lo + 63)..lo];
    r[(lo + 63)..lo] = shift_bits_right(elem, cnt[(lo + 5)..lo]) | shift_bits_left(elem, to_bits_truncate(6, 64 - c));
  };
  r
}

val evex_vprorq_256 : (ymmword, ymmword) -> ymmword
function evex_vprorq_256(a, b) =
  evex_vprorq_128(a[255..128], b[255..128]) @ evex_vprorq_128(a[127..0], b[127..0])

val evex_vprorq_512 : (zmmword, zmmword) -> zmmword
function evex_vprorq_512(a, b) =
  evex_vprorq_256(a[511..256], b[511..256]) @ evex_vprorq_256(a[255..0], b[255..0])

// =========================================================================
// Shift by XMM count: count comes from low 64 bits of XMM register
// Same functions as imm but count extracted from xmm src2[63:0]
// =========================================================================

val clamp_shift_bv64 : bits(64) -> range(0, 255)
function clamp_shift_bv64(raw) = {
  let hi_nonzero : bit = is_nonzero(raw[63..56] | raw[55..48] | raw[47..40] | raw[39..32] | raw[31..24] | raw[23..16] | raw[15..8]);
  let sat_mask : bits(8) = sign_extend(hi_nonzero);
  unsigned(raw[7..0] | sat_mask)
}

// VPSRLW by xmm count
val avx_psrlw_xmm_lane : (xmmword, xmmword) -> xmmword
function avx_psrlw_xmm_lane(a, count_xmm) =
  avx_psrlw_imm_lane(a, clamp_shift_bv64(count_xmm[63..0]))

val avx_psrlw_xmm : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), xmmword) -> bits('vl)
function avx_psrlw_xmm(vl, a, count_xmm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_psrlw_xmm_lane(a[(lo + 127)..lo], count_xmm)
  };
  r
}

// VPSRLD by xmm count
val avx_psrld_xmm_lane : (xmmword, xmmword) -> xmmword
function avx_psrld_xmm_lane(a, count_xmm) =
  avx_psrld_imm_lane(a, clamp_shift_bv64(count_xmm[63..0]))

val avx_psrld_xmm : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), xmmword) -> bits('vl)
function avx_psrld_xmm(vl, a, count_xmm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_psrld_xmm_lane(a[(lo + 127)..lo], count_xmm)
  };
  r
}

// VPSRLQ by xmm count
val avx_psrlq_xmm_lane : (xmmword, xmmword) -> xmmword
function avx_psrlq_xmm_lane(a, count_xmm) =
  avx_psrlq_imm_lane(a, clamp_shift_bv64(count_xmm[63..0]))

val avx_psrlq_xmm : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), xmmword) -> bits('vl)
function avx_psrlq_xmm(vl, a, count_xmm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_psrlq_xmm_lane(a[(lo + 127)..lo], count_xmm)
  };
  r
}

// VPSLLW by xmm count
val avx_psllw_xmm_lane : (xmmword, xmmword) -> xmmword
function avx_psllw_xmm_lane(a, count_xmm) =
  avx_psllw_imm_lane(a, clamp_shift_bv64(count_xmm[63..0]))

val avx_psllw_xmm : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), xmmword) -> bits('vl)
function avx_psllw_xmm(vl, a, count_xmm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_psllw_xmm_lane(a[(lo + 127)..lo], count_xmm)
  };
  r
}

// VPSLLD by xmm count
val avx_pslld_xmm_lane : (xmmword, xmmword) -> xmmword
function avx_pslld_xmm_lane(a, count_xmm) =
  avx_pslld_imm_lane(a, clamp_shift_bv64(count_xmm[63..0]))

val avx_pslld_xmm : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), xmmword) -> bits('vl)
function avx_pslld_xmm(vl, a, count_xmm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_pslld_xmm_lane(a[(lo + 127)..lo], count_xmm)
  };
  r
}

// VPSLLQ by xmm count
val avx_psllq_xmm_lane : (xmmword, xmmword) -> xmmword
function avx_psllq_xmm_lane(a, count_xmm) =
  avx_psllq_imm_lane(a, clamp_shift_bv64(count_xmm[63..0]))

val avx_psllq_xmm : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), xmmword) -> bits('vl)
function avx_psllq_xmm(vl, a, count_xmm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_psllq_xmm_lane(a[(lo + 127)..lo], count_xmm)
  };
  r
}

// VPSRAW by xmm count
val avx_psraw_xmm_lane : (xmmword, xmmword) -> xmmword
function avx_psraw_xmm_lane(a, count_xmm) =
  avx_psraw_imm(a, clamp_shift_bv64(count_xmm[63..0]))

val avx_psraw_xmm : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), xmmword) -> bits('vl)
function avx_psraw_xmm(vl, a, count_xmm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_psraw_xmm_lane(a[(lo + 127)..lo], count_xmm)
  };
  r
}

// VPSRAD by xmm count
val avx_psrad_xmm_lane : (xmmword, xmmword) -> xmmword
function avx_psrad_xmm_lane(a, count_xmm) =
  arith_shr_dwords_128b(a, clamp_shift_bv64(count_xmm[63..0]))

val avx_psrad_xmm : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), xmmword) -> bits('vl)
function avx_psrad_xmm(vl, a, count_xmm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_psrad_xmm_lane(a[(lo + 127)..lo], count_xmm)
  };
  r
}

// VPSRAQ by xmm count
val avx_psraq_xmm_lane : (xmmword, xmmword) -> xmmword
function avx_psraq_xmm_lane(a, count_xmm) =
  arith_shr_qwords_128b(a, clamp_shift_bv64(count_xmm[63..0]))

val avx_psraq_xmm : forall 'vl, 'vl in {128, 256, 512}. (implicit('vl), bits('vl), xmmword) -> bits('vl)
function avx_psraq_xmm(vl, a, count_xmm) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 128 - 1)) {
    let lo = i * 128;
    r[(lo + 127)..lo] = avx_psraq_xmm_lane(a[(lo + 127)..lo], count_xmm)
  };
  r
}

// =========================================================================
// VMOVSLDUP — Duplicate Even-Indexed Single-FP Values
// Each pair of 32-bit floats: [A, B] → [A, A] (even index duplicated)
// =========================================================================

val dispatch_evex_int : (range(0, 255), Prefixes) -> unit
function dispatch_evex_int(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {
  // 0F 6F: VMOVDQA32/64 (66), VMOVDQU32/64 (F3), VMOVDQU8/16 (F2)
  111 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let mp = get_mandatory_prefix(pfx);
    let vl = evex_vl(pfx);
    let s = evex_src(vl, modrm, src, pfx);
    // Element size depends on prefix: F2→byte/word, others→dword/qword
    match mp {
      MP_F2 => if pfx.rex_w
               then evex_write(dst, evex_wmask(pfx, vl / 16), s)
               else evex_write(dst, evex_wmask(pfx, vl / 8), s),
      _     => { let eb = evex_elem(pfx);
                 evex_write(dst, evex_wmask(pfx, vl / eb), s) },
    }
  },

  // 0F 7F: VMOVDQA32/VMOVDQA64/VMOVDQU32/VMOVDQU64 (EVEX store)
  127 => {
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match dest {
      RM_reg(_) => {
        let dst = evex_rm_reg_idx(modrm, pfx);
        match (pfx.rex_w, pfx.evex_ll) {
          (true, 0) => evex_write(dst, evex_wmask(pfx, 2), read_xmm(src)),
          (true, 1) => evex_write(dst, evex_wmask(pfx, 4), read_ymm(src)),
          (true, 2) => evex_write(dst, evex_wmask(pfx, 8), read_zmm(src)),
          (false, 0) => evex_write(dst, evex_wmask(pfx, 4), read_xmm(src)),
          (false, 1) => evex_write(dst, evex_wmask(pfx, 8), read_ymm(src)),
          (false, 2) => evex_write(dst, evex_wmask(pfx, 16), read_zmm(src)),
          _ => raise_UD(),
        }
      },
      RM_mem(m) => {
        let mask : qword = evex_kmask64(pfx);
        let elem_size : {1, 2, 4, 8} =
          if pfx.has_repne then (if pfx.rex_w then 2 else 1)
          else (if pfx.rex_w then 8 else 4);
        let nbytes : {16, 32, 64} = match pfx.evex_ll { 0 => 16, 1 => 32, 2 => 64 , 3 => { raise_UD(); 16 } };
        evex_masked_mem_store(m, read_zmm(src), mask, nbytes, elem_size)
      },
    }
  },

  // 0F EF: VPXORD (W0) / VPXORQ (W1) (EVEX, 66 prefix)
  239 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, read_simd(vl, pfx.evex_vvvvv) ^ evex_bcast_src(modrm, src, pfx, eb))
  },

  // 0F DB: VPANDD (W0) / VPANDQ (W1) (EVEX, 66 prefix)
  219 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, read_simd(vl, pfx.evex_vvvvv) & evex_bcast_src(modrm, src, pfx, eb))
  },

  // 0F EB: VPORD (W0) / VPORQ (W1) (EVEX, 66 prefix)
  235 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, read_simd(vl, pfx.evex_vvvvv) | evex_bcast_src(modrm, src, pfx, eb))
  },

  // 0F FE: VPADDD (EVEX, 66 prefix, W0)
  254 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 32);
    evex_write(dst, mask, packed_binop(PB_Add, 32, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 32)))
  },

  // 0F FA: VPSUBD (EVEX, 66 prefix, W0)
  250 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 32);
    evex_write(dst, mask, packed_binop(PB_Sub, 32, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 32)))
  },

  // 0F D4: VPADDQ (EVEX, 66 prefix, W1)
  212 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 64);
    evex_write(dst, mask, packed_binop(PB_Add, 64, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 64)))
  },

  // 0F FB: VPSUBQ (EVEX, 66 prefix, W1)
  251 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 64);
    evex_write(dst, mask, packed_binop(PB_Sub, 64, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 64)))
  },

  // 0F 6E: VMOVD (66, W=0) / VMOVQ (66, W=1) — load from GPR/mem to XMM
  110 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    match (src, pfx.rex_w) {
      // VMOVQ: load qword into XMM, zero upper
      (RM_reg(_), true)   => evex_write(dst, evex_wmask(pfx, 8), zero_extend(v(64, modrm_rm_reg(modrm, pfx))) : zmmword),
      (RM_mem(m), true)  => evex_write(dst, evex_wmask(pfx, 8), zero_extend(v(64, m)) : zmmword),
      // VMOVD: load dword into XMM, zero upper
      (RM_reg(_), false)  => evex_write(dst, evex_wmask(pfx, 16), zero_extend(v(32, modrm_rm_reg(modrm, pfx))) : zmmword),
      (RM_mem(m), false) => evex_write(dst, evex_wmask(pfx, 16), zero_extend(v(32, m)) : zmmword),
    }
  },

  // 0F 74: VPCMPEQB → kmask (66, EVEX)
  116 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let k_mask = avx_pcmpeq_mask(8, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)) & evex_kmask64(pfx);
    write_kreg(dst_k, k_mask)
  },

  // 0F 76: VPCMPEQD → kmask (66, EVEX, W0) — supports m32bcst
  118 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let k_mask = avx_pcmpeq_mask(32, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 32)) & evex_kmask64(pfx);
    write_kreg(dst_k, k_mask)
  },

  // 0F 7E: VMOVD (66, W=0) / VMOVQ (66, W=1) — store from XMM to GPR/mem
  126 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = evex_reg_idx(modrm, pfx);
    let dest = modrm_rm_evex(modrm, pfx, if pfx.rex_w then 8 else 4);
    let src_xmm = read_xmm(src);
    match (dest, pfx.rex_w) {
      // VMOVQ: store qword from XMM to GPR/mem
      (RM_reg(_), true)    => v(modrm_rm_reg(modrm, pfx)) = src_xmm[63..0],
      (RM_mem(m), true)   => v(m) = src_xmm[63..0],
      // VMOVD: store dword from XMM to GPR/mem
      (RM_reg(_), false)   => v(modrm_rm_reg(modrm, pfx)) = src_xmm[31..0],
      (RM_mem(m), false)  => v(m) = src_xmm[31..0],
    }
  },

  // 0F DA: VPMINUB (66, EVEX)
  218 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 8);
    evex_write(dst, mask, packed_binop(PB_MinU, 8, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F E7: VMOVNTDQ (66, EVEX) — non-temporal store (we just do a regular store)
  231 => {
    if mp != MP_66 then raise_UD();
    let (src, dest) = fetch_modrm_evex(pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    match dest {
      RM_mem(m) => write_mem(seg_linear(m, 64), read_simd(vl, src)),
      _ => raise_UD(),
    }
  },

  // 0F F8: VPSUBB (66, EVEX)
  248 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 8);
    evex_write(dst, mask, packed_binop(PB_Sub, 8, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F FC: VPADDB (66, EVEX)
  252 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 8);
    evex_write(dst, mask, packed_binop(PB_Add, 8, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F DF: VPANDND (66,W0) / VPANDNQ (66,W1)
  223 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let eb = evex_elem(pfx);
    let mask = evex_wmask(pfx, vl / eb);
    evex_write(dst, mask, ~(read_simd(vl, pfx.evex_vvvvv)) & evex_bcast_src(modrm, src, pfx, eb))
  },

  // 0F FD: VPADDW (66, EVEX) [BW]
  253 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 16);
    evex_write(dst, mask, packed_binop(PB_Add, 16, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F F9: VPSUBW (66, EVEX) [BW]
  249 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 16);
    evex_write(dst, mask, packed_binop(PB_Sub, 16, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F EC: VPADDSB (66, EVEX) [BW]
  236 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 8);
    evex_write(dst, mask, packed_binop(PB_SatAddS, 8, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F ED: VPADDSW (66, EVEX) [BW]
  237 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 16);
    evex_write(dst, mask, packed_binop(PB_SatAddS, 16, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F E8: VPSUBSB (66, EVEX) [BW]
  232 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 8);
    evex_write(dst, mask, packed_binop(PB_SatSubS, 8, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F E9: VPSUBSW (66, EVEX) [BW]
  233 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 16);
    evex_write(dst, mask, packed_binop(PB_SatSubS, 16, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F DC: VPADDUSB (66, EVEX) [BW]
  220 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 8);
    evex_write(dst, mask, packed_binop(PB_SatAddU, 8, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F DD: VPADDUSW (66, EVEX) [BW]
  221 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 16);
    evex_write(dst, mask, packed_binop(PB_SatAddU, 16, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F D8: VPSUBUSB (66, EVEX) [BW]
  216 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 8);
    evex_write(dst, mask, packed_binop(PB_SatSubU, 8, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F D9: VPSUBUSW (66, EVEX) [BW]
  217 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 16);
    evex_write(dst, mask, packed_binop(PB_SatSubU, 16, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F D5: VPMULLW (66, EVEX) [BW]
  213 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 16);
    evex_write(dst, mask, packed_binop(PB_MulLow, 16, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F E4: VPMULHUW (66, EVEX) [BW]
  228 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 16);
    evex_write(dst, mask, packed_binop(PB_MulHighU, 16, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F E5: VPMULHW (66, EVEX) [BW]
  229 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 16);
    evex_write(dst, mask, packed_binop(PB_MulHighS, 16, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F DE: VPMAXUB (66, EVEX) [BW]
  222 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 8);
    evex_write(dst, mask, packed_binop(PB_MaxU, 8, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F EA: VPMINSW (66, EVEX) [BW]
  234 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 16);
    evex_write(dst, mask, packed_binop(PB_MinS, 16, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F EE: VPMAXSW (66, EVEX) [BW]
  238 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 16);
    evex_write(dst, mask, packed_binop(PB_MaxS, 16, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F E0: VPAVGB (66, EVEX) [BW]
  224 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 8);
    evex_write(dst, mask, packed_binop(PB_Avg, 8, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F E3: VPAVGW (66, EVEX) [BW]
  227 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 16);
    evex_write(dst, mask, packed_binop(PB_Avg, 16, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F F4: VPMULUDQ (66, EVEX, W1) [F] — supports m64bcst
  244 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 64);
    evex_write(dst, mask, avx_pmuludq(read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, modrm, src, pfx, 64)))
  },

  // 0F F5: VPMADDWD (66, EVEX) [BW]
  245 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 32);
    evex_write(dst, mask, avx_pmaddwd(read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F F6: VPSADBW (66, EVEX) [BW] — no writemask
  246 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 64);
    evex_write(dst, mask, avx_psadbw(read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F 64: VPCMPGTB → kmask (66, EVEX) [BW]
  100 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let k_mask = avx_pcmpgt_mask(8, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)) & evex_kmask64(pfx);
    write_kreg(dst_k, k_mask)
  },

  // 0F 65: VPCMPGTW → kmask (66, EVEX) [BW]
  101 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let k_mask = avx_pcmpgt_mask(16, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)) & evex_kmask64(pfx);
    write_kreg(dst_k, k_mask)
  },

  // 0F 66: VPCMPGTD → kmask (66, EVEX, W0) [F] — supports m32bcst
  102 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let k_mask = avx_pcmpgt_mask(32, read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 32)) & evex_kmask64(pfx);
    write_kreg(dst_k, k_mask)
  },

  // 0F 75: VPCMPEQW → kmask (66, EVEX) [BW]
  117 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let k_mask = avx_pcmpeq_mask(16, read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)) & evex_kmask64(pfx);
    write_kreg(dst_k, k_mask)
  },

  // 0F 51: VSQRTPS (NP) / VSQRTPD (66)
  // 0F 60: VPUNPCKLBW (66, EVEX) [BW]
  96 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 8), avx_punpcklbw(read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F 61: VPUNPCKLWD (66, EVEX) [BW]
  97 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 16), avx_punpcklwd(read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F 62: VPUNPCKLDQ (66, EVEX, W0) [F] — supports m32bcst
  98 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 32), avx_punpckldq(read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 32)))
  },

  // 0F 63: VPACKSSWB (66, EVEX) [BW]
  99 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 8);
    evex_write(dst, mask, avx_packsswb(read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F 67: VPACKUSWB (66, EVEX) [BW]
  103 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 8);
    evex_write(dst, mask, avx_packuswb(read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F 68: VPUNPCKHBW (66, EVEX) [BW]
  104 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 8), avx_punpckhbw(read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F 69: VPUNPCKHWD (66, EVEX) [BW]
  105 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 16), avx_punpckhwd(read_simd(vl, pfx.evex_vvvvv), evex_src(vl, modrm, src, pfx)))
  },

  // 0F 6A: VPUNPCKHDQ (66, EVEX, W0) [F] — supports m32bcst
  106 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 32), avx_punpckhdq(read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 32)))
  },

  // 0F 6B: VPACKSSDW (66, EVEX, W0) [BW] — supports m32bcst
  107 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let vl = evex_vl(pfx);
    let mask = evex_wmask(pfx, vl / 16);
    evex_write(dst, mask, avx_packssdw(read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(vl, modrm, src, pfx, 32)))
  },

  // 0F 6C: VPUNPCKLQDQ (66, EVEX, W1) [F] — supports m64bcst
  108 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 64), avx_punpcklqdq(read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 64)))
  },

  // 0F 6D: VPUNPCKHQDQ (66, EVEX, W1) [F] — supports m64bcst
  109 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 64), avx_punpckhqdq(read_simd(vl, pfx.evex_vvvvv), evex_bcast_src(modrm, src, pfx, 64)))
  },

  // 0F 70: VPSHUFD (66, W0, m32bcst) / VPSHUFHW (F3) / VPSHUFLW (F2)
  112 => {
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match src { RM_mem(_) => true, _ => false };
    let imm = fetch(1);
    match mp {
      MP_66 => {
        let vl = evex_vl(pfx);
        evex_write(dst, evex_wmask(pfx, vl / 32), avx_pshufd(evex_bcast_src(vl, modrm, src, pfx, 32), imm))
      },
      MP_F3 => {
        let vl = evex_vl(pfx);
        evex_write(dst, evex_wmask(pfx, vl / 16), avx_pshufhw(evex_src(vl, modrm, src, pfx), imm))
      },
      MP_F2 => {
        let vl = evex_vl(pfx);
        evex_write(dst, evex_wmask(pfx, vl / 16), avx_pshuflw(evex_src(vl, modrm, src, pfx), imm))
      },
      _ => raise_UD(),
    }
  },

  // 0F 71: Group 12 — shift word by imm8 (66, EVEX)
  // /2=VPSRLW, /4=VPSRAW, /6=VPSLLW
  // 0F 71: Group 12 — shift word by imm8 (66, EVEX)
  // /2=VPSRLW, /4=VPSRAW, /6=VPSLLW
  113 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let digit : range(0, 7) = unsigned(modrm[5..3]);
    let src = evex_rm_reg_idx(modrm, pfx);
    let dst = pfx.evex_vvvvv;
    let imm = fetch(1);
    let count : range(0, 255) = unsigned(imm);
    match digit {
      2 => {
        let vl = evex_vl(pfx);
        evex_write(dst, evex_wmask(pfx, vl / 16), avx_psrlw_imm(read_simd(vl, src), count))
      },
      4 => {
        let vl = evex_vl(pfx);
        evex_write(dst, evex_wmask(pfx, vl / 16), avx_psraw_imm(read_simd(vl, src), count))
      },
      6 => {
        let vl = evex_vl(pfx);
        evex_write(dst, evex_wmask(pfx, vl / 16), avx_psllw_imm(read_simd(vl, src), count))
      },
      _ => raise_UD(),
    }
  },

  // 0F 72: Group 13 — shift/rotate dword/qword by imm8 (66, EVEX)
  // /0=VPRORD(W0)/VPRORQ(W1), /1=VPROLD(W0)/VPROLQ(W1)
  // /2=VPSRLD(W0)/VPSRLQ(W1), /4=VPSRAD(W0)/VPSRAQ(W1), /6=VPSLLD(W0)/VPSLLQ(W1)
  114 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let digit : range(0, 7) = unsigned(modrm[5..3]);
    let src = evex_rm_reg_idx(modrm, pfx);
    let dst = pfx.evex_vvvvv;
    let imm = fetch(1);
    let count : range(0, 255) = unsigned(imm);
    match (pfx.rex_w, digit, pfx.evex_ll) {
      // VPRORQ zmm1/ymm1/xmm1, zmm2/ymm2/xmm2/m512/m256/m128, imm8
      (true, 0, 0) => {
        let c : bits(64) = zero_extend(imm);
        let cv : xmmword = c @ c;
        evex_write(dst, evex_wmask(pfx, 2), evex_vprorq_128(read_xmm(src), cv))
      },
      (true, 0, 1) => {
        let c : bits(64) = zero_extend(imm);
        let cv : ymmword = c @ c @ c @ c;
        evex_write(dst, evex_wmask(pfx, 4), evex_vprorq_256(read_ymm(src), cv))
      },
      (true, 0, 2) => {
        let c : bits(64) = zero_extend(imm);
        let cv : zmmword = c @ c @ c @ c @ c @ c @ c @ c;
        evex_write(dst, evex_wmask(pfx, 8), evex_vprorq_512(read_zmm(src), cv))
      },
      // VPROLQ zmm1/ymm1/xmm1, zmm2/ymm2/xmm2/m512/m256/m128, imm8
      (true, 1, 0) => {
        let c : bits(64) = zero_extend(imm);
        let cv : xmmword = c @ c;
        evex_write(dst, evex_wmask(pfx, 2), evex_vprolq_128(read_xmm(src), cv))
      },
      (true, 1, 1) => {
        let c : bits(64) = zero_extend(imm);
        let cv : ymmword = c @ c @ c @ c;
        evex_write(dst, evex_wmask(pfx, 4), evex_vprolq_256(read_ymm(src), cv))
      },
      (true, 1, 2) => {
        let c : bits(64) = zero_extend(imm);
        let cv : zmmword = c @ c @ c @ c @ c @ c @ c @ c;
        evex_write(dst, evex_wmask(pfx, 8), evex_vprolq_512(read_zmm(src), cv))
      },
      // VPSRLQ zmm1/ymm1/xmm1, zmm2/ymm2/xmm2, imm8
      (true, 2, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_psrlq_imm_lane(read_xmm(src), count)),
      (true, 2, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_psrlq_imm(read_ymm(src), count)),
      (true, 2, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_psrlq_imm(read_zmm(src), count)),
      // VPSRAQ zmm1/ymm1/xmm1, zmm2/ymm2/xmm2, imm8
      (true, 4, 0) => evex_write(dst, evex_wmask(pfx, 2), arith_shr_qwords_128b(read_xmm(src), count)),
      (true, 4, 1) => evex_write(dst, evex_wmask(pfx, 4), arith_shr_qwords_256b(read_ymm(src), count)),
      (true, 4, 2) => evex_write(dst, evex_wmask(pfx, 8), arith_shr_qwords_512b(read_zmm(src), count)),
      // VPSLLQ zmm1/ymm1/xmm1, zmm2/ymm2/xmm2, imm8
      (true, 6, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_psllq_imm_lane(read_xmm(src), count)),
      (true, 6, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_psllq_imm(read_ymm(src), count)),
      (true, 6, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_psllq_imm(read_zmm(src), count)),
      // VPRORD zmm1/ymm1/xmm1, zmm2/ymm2/xmm2/m512/m256/m128, imm8
      (false, 0, 0) => {
        let c : bits(32) = zero_extend(imm);
        let cv : xmmword = c @ c @ c @ c;
        evex_write(dst, evex_wmask(pfx, 4), evex_vprord_128(read_xmm(src), cv))
      },
      (false, 0, 1) => {
        let c : bits(32) = zero_extend(imm);
        let cv : ymmword = c @ c @ c @ c @ c @ c @ c @ c;
        evex_write(dst, evex_wmask(pfx, 8), evex_vprord_256(read_ymm(src), cv))
      },
      (false, 0, 2) => {
        let c : bits(32) = zero_extend(imm);
        let cv : zmmword = c @ c @ c @ c @ c @ c @ c @ c @ c @ c @ c @ c @ c @ c @ c @ c;
        evex_write(dst, evex_wmask(pfx, 16), evex_vprord_512(read_zmm(src), cv))
      },
      // VPROLD zmm1/ymm1/xmm1, zmm2/ymm2/xmm2/m512/m256/m128, imm8
      (false, 1, 0) => {
        let c : bits(32) = zero_extend(imm);
        let cv : xmmword = c @ c @ c @ c;
        evex_write(dst, evex_wmask(pfx, 4), evex_vprold_128(read_xmm(src), cv))
      },
      (false, 1, 1) => {
        let c : bits(32) = zero_extend(imm);
        let cv : ymmword = c @ c @ c @ c @ c @ c @ c @ c;
        evex_write(dst, evex_wmask(pfx, 8), evex_vprold_256(read_ymm(src), cv))
      },
      (false, 1, 2) => {
        let c : bits(32) = zero_extend(imm);
        let cv : zmmword = c @ c @ c @ c @ c @ c @ c @ c @ c @ c @ c @ c @ c @ c @ c @ c;
        evex_write(dst, evex_wmask(pfx, 16), evex_vprold_512(read_zmm(src), cv))
      },
      // VPSRLD zmm1/ymm1/xmm1, zmm2/ymm2/xmm2, imm8
      (false, 2, 0) => evex_write(dst, evex_wmask(pfx, 4), avx_psrld_imm_lane(read_xmm(src), count)),
      (false, 2, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_psrld_imm(read_ymm(src), count)),
      (false, 2, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_psrld_imm(read_zmm(src), count)),
      // VPSRAD zmm1/ymm1/xmm1, zmm2/ymm2/xmm2, imm8
      (false, 4, 0) => evex_write(dst, evex_wmask(pfx, 4), arith_shr_dwords_128b(read_xmm(src), count)),
      (false, 4, 1) => evex_write(dst, evex_wmask(pfx, 8), arith_shr_dwords_256b(read_ymm(src), count)),
      (false, 4, 2) => evex_write(dst, evex_wmask(pfx, 16), arith_shr_dwords_512b(read_zmm(src), count)),
      // VPSLLD zmm1/ymm1/xmm1, zmm2/ymm2/xmm2, imm8
      (false, 6, 0) => evex_write(dst, evex_wmask(pfx, 4), avx_pslld_imm_lane(read_xmm(src), count)),
      (false, 6, 1) => evex_write(dst, evex_wmask(pfx, 8), avx_pslld_imm(read_ymm(src), count)),
      (false, 6, 2) => evex_write(dst, evex_wmask(pfx, 16), avx_pslld_imm(read_zmm(src), count)),
      _ => raise_UD(),
    }
  },

  // 0F 73: Group 14 — shift qword/dq by imm8 (66, EVEX)
  // /2=VPSRLQ(W1), /3=VPSRLDQ, /6=VPSLLQ(W1), /7=VPSLLDQ
  115 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let digit : range(0, 7) = unsigned(modrm[5..3]);
    let src = evex_rm_reg_idx(modrm, pfx);
    let dst = pfx.evex_vvvvv;
    let imm = fetch(1);
    let count : range(0, 255) = unsigned(imm);
    match (digit, pfx.evex_ll) {
      // VPSRLQ zmm1/ymm1/xmm1, zmm2/ymm2/xmm2, imm8
      (2, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_psrlq_imm_lane(read_xmm(src), count)),
      (2, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_psrlq_imm(read_ymm(src), count)),
      (2, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_psrlq_imm(read_zmm(src), count)),
      // VPSRLDQ zmm1/ymm1/xmm1, zmm2/ymm2/xmm2, imm8
      (3, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_psrldq_lane(read_xmm(src), count)),
      (3, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_psrldq(read_ymm(src), count)),
      (3, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_psrldq(read_zmm(src), count)),
      // VPSLLQ zmm1/ymm1/xmm1, zmm2/ymm2/xmm2, imm8
      (6, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_psllq_imm_lane(read_xmm(src), count)),
      (6, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_psllq_imm(read_ymm(src), count)),
      (6, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_psllq_imm(read_zmm(src), count)),
      // VPSLLDQ zmm1/ymm1/xmm1, zmm2/ymm2/xmm2, imm8
      (7, 0) => evex_write(dst, evex_wmask(pfx, 2), avx_pslldq_lane(read_xmm(src), count)),
      (7, 1) => evex_write(dst, evex_wmask(pfx, 4), avx_pslldq(read_ymm(src), count)),
      (7, 2) => evex_write(dst, evex_wmask(pfx, 8), avx_pslldq(read_zmm(src), count)),
      _ => raise_UD(),
    }
  },

  // 0F C4: VPINSRW (66) — insert word from r32/m16 into XMM [BW]
  196 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 2);
    let src1 = read_xmm(pfx.evex_vvvvv);
    let word_val : bits(16) = match src {
      RM_reg(_) => v(32, modrm_rm_reg(modrm, pfx))[15..0],
      RM_mem(m) => v(m),
    };
    let imm = fetch(1);
    let sel : range(0, 7) = unsigned(imm[2..0]);
    var result = src1;
    let lo : range(0, 112) = sel * 16;
    result[(lo + 15)..lo] = word_val;
    evex_write(dst, evex_wmask(pfx, 8), result)
  },

  // 0F C5: VPEXTRW (66) — extract word from XMM to r32 [BW]
  197 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src_xmm = read_xmm(evex_rm_reg_idx(modrm, pfx));
    let dst_gpr = modrm_reg(modrm, pfx);
    let imm = fetch(1);
    let sel : range(0, 7) = unsigned(imm[2..0]);
    let lo : range(0, 112) = sel * 16;
    let word_val : bits(16) = src_xmm[(lo + 15)..lo];
    v(dst_gpr) = zero_extend(64, word_val)
  },

  // 0F C2: VCMPPS (NP,W0) / VCMPPD (66,W1) / VCMPSS (F3) / VCMPSD (F2) → kmask
  // 0F D6: VMOVQ store (66,W1) — store low qword of XMM to XMM/m64
  214 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src_xmm = read_xmm(evex_reg_idx(modrm, pfx));
    let dest = modrm_rm_evex(modrm, pfx, 8);
    let qval : qword = src_xmm[63..0];
    match dest {
      RM_reg(_) => {
        let dst = evex_rm_reg_idx(modrm, pfx);
        evex_write(dst, evex_wmask(pfx, 2), zero_extend(qval) : xmmword)
      },
      RM_mem(m) => v(m) = qval,
    }
  },

  // 0F E6: VCVTDQ2PD (F3,W0) / VCVTPD2DQ (F2,W1) / VCVTTPD2DQ (66,W1) / VCVTQQ2PD (F3,W1)
  // 0F D1: VPSRLW by xmm (66, EVEX) [BW]
  209 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 16);
    let count_xmm : xmmword = evex_src(128,modrm, src, pfx);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 16), avx_psrlw_xmm(read_simd(vl, pfx.evex_vvvvv), count_xmm))
  },

  // 0F D2: VPSRLD by xmm (66, EVEX) [F]
  210 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 16);
    let count_xmm : xmmword = evex_src(128,modrm, src, pfx);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 32), avx_psrld_xmm(read_simd(vl, pfx.evex_vvvvv), count_xmm))
  },

  // 0F D3: VPSRLQ by xmm (66, EVEX) [F]
  211 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 16);
    let count_xmm : xmmword = evex_src(128,modrm, src, pfx);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 64), avx_psrlq_xmm(read_simd(vl, pfx.evex_vvvvv), count_xmm))
  },

  // 0F E1: VPSRAW by xmm (66, EVEX) [BW]
  225 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 16);
    let count_xmm : xmmword = evex_src(128,modrm, src, pfx);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 16), avx_psraw_xmm(read_simd(vl, pfx.evex_vvvvv), count_xmm))
  },

  // 0F E2: VPSRAD (66,W0) / VPSRAQ (66,W1) by xmm (EVEX)
  226 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 16);
    let count_xmm : xmmword = evex_src(128,modrm, src, pfx);
    let vl = evex_vl(pfx);
    if pfx.rex_w then
      evex_write(dst, evex_wmask(pfx, vl / 64), avx_psraq_xmm(read_simd(vl, pfx.evex_vvvvv), count_xmm))
    else
      evex_write(dst, evex_wmask(pfx, vl / 32), avx_psrad_xmm(read_simd(vl, pfx.evex_vvvvv), count_xmm))
  },

  // 0F F1: VPSLLW by xmm (66, EVEX) [BW]
  241 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 16);
    let count_xmm : xmmword = evex_src(128,modrm, src, pfx);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 16), avx_psllw_xmm(read_simd(vl, pfx.evex_vvvvv), count_xmm))
  },

  // 0F F2: VPSLLD by xmm (66, EVEX) [F]
  242 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 16);
    let count_xmm : xmmword = evex_src(128,modrm, src, pfx);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 32), avx_pslld_xmm(read_simd(vl, pfx.evex_vvvvv), count_xmm))
  },

  // 0F F3: VPSLLQ by xmm (66, EVEX) [F]
  243 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = evex_reg_idx(modrm, pfx);
    let src = modrm_rm_evex(modrm, pfx, 16);
    let count_xmm : xmmword = evex_src(128,modrm, src, pfx);
    let vl = evex_vl(pfx);
    evex_write(dst, evex_wmask(pfx, vl / 64), avx_psllq_xmm(read_simd(vl, pfx.evex_vvvvv), count_xmm))
  },

  _ => raise_UD(),
  }
}

// x86-64 EVEX — Integer Operations (0F map)
//
// Packed integer arithmetic, logic, pack/unpack, shift, and compare.
// Called from dispatch_evex_0f in insn_evex.sail.

val avx_paddb_256 : (ymmword, ymmword) -> ymmword
function avx_paddb_256(a, b) =
  avx_paddb_128(a[255..128], b[255..128]) @
  avx_paddb_128(a[127..0],   b[127..0])

val avx_paddw_256 : (ymmword, ymmword) -> ymmword
function avx_paddw_256(a, b) =
  avx_paddw_128(a[255..128], b[255..128]) @
  avx_paddw_128(a[127..0],   b[127..0])

val avx_paddd_256 : (ymmword, ymmword) -> ymmword
function avx_paddd_256(a, b) =
  avx_paddd_128(a[255..128], b[255..128]) @
  avx_paddd_128(a[127..0],   b[127..0])

val avx_paddq_256 : (ymmword, ymmword) -> ymmword
function avx_paddq_256(a, b) =
  avx_paddq_128(a[255..128], b[255..128]) @
  avx_paddq_128(a[127..0],   b[127..0])

val avx_psubb_256 : (ymmword, ymmword) -> ymmword
function avx_psubb_256(a, b) =
  avx_psubb_128(a[255..128], b[255..128]) @
  avx_psubb_128(a[127..0],   b[127..0])

val avx_psubw_256 : (ymmword, ymmword) -> ymmword
function avx_psubw_256(a, b) =
  avx_psubw_128(a[255..128], b[255..128]) @
  avx_psubw_128(a[127..0],   b[127..0])

val avx_psubd_256 : (ymmword, ymmword) -> ymmword
function avx_psubd_256(a, b) =
  avx_psubd_128(a[255..128], b[255..128]) @
  avx_psubd_128(a[127..0],   b[127..0])

val avx_psubq_256 : (ymmword, ymmword) -> ymmword
function avx_psubq_256(a, b) =
  avx_psubq_128(a[255..128], b[255..128]) @
  avx_psubq_128(a[127..0],   b[127..0])

// =========================================================================
// 512-bit (ZMM) packed FP helpers
// Implemented as: high_256 @ low_256 using YMM helpers.
// =========================================================================

val avx_paddb_512 : (zmmword, zmmword) -> zmmword
function avx_paddb_512(a, b) =
  avx_paddb_256(a[511..256], b[511..256]) @
  avx_paddb_256(a[255..0],   b[255..0])

val avx_paddw_512 : (zmmword, zmmword) -> zmmword
function avx_paddw_512(a, b) =
  avx_paddw_256(a[511..256], b[511..256]) @
  avx_paddw_256(a[255..0],   b[255..0])

val avx_paddd_512 : (zmmword, zmmword) -> zmmword
function avx_paddd_512(a, b) =
  avx_paddd_256(a[511..256], b[511..256]) @
  avx_paddd_256(a[255..0],   b[255..0])

val avx_paddq_512 : (zmmword, zmmword) -> zmmword
function avx_paddq_512(a, b) =
  avx_paddq_256(a[511..256], b[511..256]) @
  avx_paddq_256(a[255..0],   b[255..0])

val avx_psubb_512 : (zmmword, zmmword) -> zmmword
function avx_psubb_512(a, b) =
  avx_psubb_256(a[511..256], b[511..256]) @
  avx_psubb_256(a[255..0],   b[255..0])

val avx_psubw_512 : (zmmword, zmmword) -> zmmword
function avx_psubw_512(a, b) =
  avx_psubw_256(a[511..256], b[511..256]) @
  avx_psubw_256(a[255..0],   b[255..0])

val avx_psubd_512 : (zmmword, zmmword) -> zmmword
function avx_psubd_512(a, b) =
  avx_psubd_256(a[511..256], b[511..256]) @
  avx_psubd_256(a[255..0],   b[255..0])

val avx_psubq_512 : (zmmword, zmmword) -> zmmword
function avx_psubq_512(a, b) =
  avx_psubq_256(a[511..256], b[511..256]) @
  avx_psubq_256(a[255..0],   b[255..0])

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

val avx_pminub_128 : (xmmword, xmmword) -> xmmword
function avx_pminub_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 8;
    let hi = lo + 7;
    let av : byte = a[(hi)..(lo)];
    let bv : byte = b[(hi)..(lo)];
    r[(hi)..(lo)] = if unsigned(av) < unsigned(bv) then av else bv
  };
  r
}

val avx_pminub_256 : (ymmword, ymmword) -> ymmword
function avx_pminub_256(a, b) =
  avx_pminub_128(a[255..128], b[255..128]) @
  avx_pminub_128(a[127..0], b[127..0])

val avx_pminub_512 : (zmmword, zmmword) -> zmmword
function avx_pminub_512(a, b) =
  avx_pminub_256(a[511..256], b[511..256]) @
  avx_pminub_256(a[255..0], b[255..0])

// =========================================================================
// AVX-512 packed unsigned dword minimum
// =========================================================================

val avx_pcmpeqb_mask_128 : (xmmword, xmmword) -> word
function avx_pcmpeqb_mask_128(a, b) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 8;
    let hi = lo + 7;
    if a[(hi)..(lo)] == b[(hi)..(lo)] then r[i] = bitone
  };
  r
}

val avx_pcmpeqb_mask_256 : (ymmword, ymmword) -> dword
function avx_pcmpeqb_mask_256(a, b) = {
  var r : dword = zeros();
  foreach (i from 0 to 31) {
    let lo = i * 8;
    let hi = lo + 7;
    if a[(hi)..(lo)] == b[(hi)..(lo)] then r[i] = bitone
  };
  r
}

val avx_pcmpeqb_mask_512 : (zmmword, zmmword) -> qword
function avx_pcmpeqb_mask_512(a, b) = {
  var r : qword = zeros();
  foreach (i from 0 to 63) {
    let lo = i * 8;
    let hi = lo + 7;
    if a[(hi)..(lo)] == b[(hi)..(lo)] then r[i] = bitone
  };
  r
}

// =========================================================================
// VPTESTMB: mask[i] = (a[i] AND b[i]) != 0
// VPTESTNMB: mask[i] = (a[i] AND b[i]) == 0
// =========================================================================

val avx_pcmpeqd_mask_128 : (xmmword, xmmword) -> byte
function avx_pcmpeqd_mask_128(a, b) = {
  var r : byte = zeros();
  foreach (i from 0 to 3) {
    let lo = i * 32; let hi = lo + 31;
    if a[(hi)..(lo)] == b[(hi)..(lo)] then r[i] = bitone
  };
  r
}

val avx_pcmpeqd_mask_256 : (ymmword, ymmword) -> byte
function avx_pcmpeqd_mask_256(a, b) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let lo = i * 32; let hi = lo + 31;
    if a[(hi)..(lo)] == b[(hi)..(lo)] then r[i] = bitone
  };
  r
}

val avx_pcmpeqd_mask_512 : (zmmword, zmmword) -> word
function avx_pcmpeqd_mask_512(a, b) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 32; let hi = lo + 31;
    if a[(hi)..(lo)] == b[(hi)..(lo)] then r[i] = bitone
  };
  r
}

// VPCMPNEQD producing kmask (neq = pred 4)
// Reusing VPCMPUB pattern but for dwords

val saturate_sb : (byte, byte) -> byte
function saturate_sb(a, b) = {
  let sum : int = signed(a) + signed(b);
  if sum > 127 then 0x7F
  else if sum < negate(128) then 0x80
  else get_slice_int(8, sum, 0)
}

val avx_paddsb_128 : (xmmword, xmmword) -> xmmword
function avx_paddsb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    r[(lo + 7)..lo] = saturate_sb(a[(lo + 7)..lo], b[(lo + 7)..lo]);
  };
  r
}

val avx_paddsb_256 : (ymmword, ymmword) -> ymmword
function avx_paddsb_256(a, b) =
  avx_paddsb_128(a[255..128], b[255..128]) @ avx_paddsb_128(a[127..0], b[127..0])

val avx_paddsb_512 : (zmmword, zmmword) -> zmmword
function avx_paddsb_512(a, b) =
  avx_paddsb_256(a[511..256], b[511..256]) @ avx_paddsb_256(a[255..0], b[255..0])

// SaturateToSignedWord: clamp (signed 32-bit sum) to [-32768, 32767]

val saturate_sw : (word, word) -> word
function saturate_sw(a, b) = {
  let sum : int = signed(a) + signed(b);
  if sum > 32767 then 0x7FFF
  else if sum < negate(32768) then 0x8000
  else get_slice_int(16, sum, 0)
}

val avx_paddsw_128 : (xmmword, xmmword) -> xmmword
function avx_paddsw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = saturate_sw(a[(lo + 15)..lo], b[(lo + 15)..lo]);
  };
  r
}

val avx_paddsw_256 : (ymmword, ymmword) -> ymmword
function avx_paddsw_256(a, b) =
  avx_paddsw_128(a[255..128], b[255..128]) @ avx_paddsw_128(a[127..0], b[127..0])

val avx_paddsw_512 : (zmmword, zmmword) -> zmmword
function avx_paddsw_512(a, b) =
  avx_paddsw_256(a[511..256], b[511..256]) @ avx_paddsw_256(a[255..0], b[255..0])

// SaturateToSignedByte for subtraction

val saturate_sb_sub : (byte, byte) -> byte
function saturate_sb_sub(a, b) = {
  let diff : int = signed(a) - signed(b);
  if diff > 127 then 0x7F
  else if diff < negate(128) then 0x80
  else get_slice_int(8, diff, 0)
}

val avx_psubsb_128 : (xmmword, xmmword) -> xmmword
function avx_psubsb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    r[(lo + 7)..lo] = saturate_sb_sub(a[(lo + 7)..lo], b[(lo + 7)..lo]);
  };
  r
}

val avx_psubsb_256 : (ymmword, ymmword) -> ymmword
function avx_psubsb_256(a, b) =
  avx_psubsb_128(a[255..128], b[255..128]) @ avx_psubsb_128(a[127..0], b[127..0])

val avx_psubsb_512 : (zmmword, zmmword) -> zmmword
function avx_psubsb_512(a, b) =
  avx_psubsb_256(a[511..256], b[511..256]) @ avx_psubsb_256(a[255..0], b[255..0])

// SaturateToSignedWord for subtraction

val saturate_sw_sub : (word, word) -> word
function saturate_sw_sub(a, b) = {
  let diff : int = signed(a) - signed(b);
  if diff > 32767 then 0x7FFF
  else if diff < negate(32768) then 0x8000
  else get_slice_int(16, diff, 0)
}

val avx_psubsw_128 : (xmmword, xmmword) -> xmmword
function avx_psubsw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = saturate_sw_sub(a[(lo + 15)..lo], b[(lo + 15)..lo]);
  };
  r
}

val avx_psubsw_256 : (ymmword, ymmword) -> ymmword
function avx_psubsw_256(a, b) =
  avx_psubsw_128(a[255..128], b[255..128]) @ avx_psubsw_128(a[127..0], b[127..0])

val avx_psubsw_512 : (zmmword, zmmword) -> zmmword
function avx_psubsw_512(a, b) =
  avx_psubsw_256(a[511..256], b[511..256]) @ avx_psubsw_256(a[255..0], b[255..0])

// SaturateToUnsignedByte for add

val saturate_ub_add : (byte, byte) -> byte
function saturate_ub_add(a, b) = {
  let sum : int = unsigned(a) + unsigned(b);
  if sum > 255 then 0xFF
  else get_slice_int(8, sum, 0)
}

val avx_paddusb_128 : (xmmword, xmmword) -> xmmword
function avx_paddusb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    r[(lo + 7)..lo] = saturate_ub_add(a[(lo + 7)..lo], b[(lo + 7)..lo]);
  };
  r
}

val avx_paddusb_256 : (ymmword, ymmword) -> ymmword
function avx_paddusb_256(a, b) =
  avx_paddusb_128(a[255..128], b[255..128]) @ avx_paddusb_128(a[127..0], b[127..0])

val avx_paddusb_512 : (zmmword, zmmword) -> zmmword
function avx_paddusb_512(a, b) =
  avx_paddusb_256(a[511..256], b[511..256]) @ avx_paddusb_256(a[255..0], b[255..0])

// SaturateToUnsignedWord for add

val saturate_uw_add : (word, word) -> word
function saturate_uw_add(a, b) = {
  let sum : int = unsigned(a) + unsigned(b);
  if sum > 65535 then 0xFFFF
  else get_slice_int(16, sum, 0)
}

val avx_paddusw_128 : (xmmword, xmmword) -> xmmword
function avx_paddusw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = saturate_uw_add(a[(lo + 15)..lo], b[(lo + 15)..lo]);
  };
  r
}

val avx_paddusw_256 : (ymmword, ymmword) -> ymmword
function avx_paddusw_256(a, b) =
  avx_paddusw_128(a[255..128], b[255..128]) @ avx_paddusw_128(a[127..0], b[127..0])

val avx_paddusw_512 : (zmmword, zmmword) -> zmmword
function avx_paddusw_512(a, b) =
  avx_paddusw_256(a[511..256], b[511..256]) @ avx_paddusw_256(a[255..0], b[255..0])

// SaturateToUnsignedByte for sub

val saturate_ub_sub : (byte, byte) -> byte
function saturate_ub_sub(a, b) = {
  let diff : int = unsigned(a) - unsigned(b);
  if diff < 0 then 0x00
  else get_slice_int(8, diff, 0)
}

val avx_psubusb_128 : (xmmword, xmmword) -> xmmword
function avx_psubusb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    r[(lo + 7)..lo] = saturate_ub_sub(a[(lo + 7)..lo], b[(lo + 7)..lo]);
  };
  r
}

val avx_psubusb_256 : (ymmword, ymmword) -> ymmword
function avx_psubusb_256(a, b) =
  avx_psubusb_128(a[255..128], b[255..128]) @ avx_psubusb_128(a[127..0], b[127..0])

val avx_psubusb_512 : (zmmword, zmmword) -> zmmword
function avx_psubusb_512(a, b) =
  avx_psubusb_256(a[511..256], b[511..256]) @ avx_psubusb_256(a[255..0], b[255..0])

// SaturateToUnsignedWord for sub

val saturate_uw_sub : (word, word) -> word
function saturate_uw_sub(a, b) = {
  let diff : int = unsigned(a) - unsigned(b);
  if diff < 0 then 0x0000
  else get_slice_int(16, diff, 0)
}

val avx_psubusw_128 : (xmmword, xmmword) -> xmmword
function avx_psubusw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = saturate_uw_sub(a[(lo + 15)..lo], b[(lo + 15)..lo]);
  };
  r
}

val avx_psubusw_256 : (ymmword, ymmword) -> ymmword
function avx_psubusw_256(a, b) =
  avx_psubusw_128(a[255..128], b[255..128]) @ avx_psubusw_128(a[127..0], b[127..0])

val avx_psubusw_512 : (zmmword, zmmword) -> zmmword
function avx_psubusw_512(a, b) =
  avx_psubusw_256(a[511..256], b[511..256]) @ avx_psubusw_256(a[255..0], b[255..0])

// =========================================================================
// VPMULLW: multiply low word (src1[15:0] * src2[15:0] → result[15:0])
// =========================================================================

val avx_pmullw_128 : (xmmword, xmmword) -> xmmword
function avx_pmullw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let prod : int = signed(a[(lo + 15)..lo]) * signed(b[(lo + 15)..lo]);
    r[(lo + 15)..lo] = get_slice_int(16, prod, 0);
  };
  r
}

val avx_pmullw_256 : (ymmword, ymmword) -> ymmword
function avx_pmullw_256(a, b) =
  avx_pmullw_128(a[255..128], b[255..128]) @ avx_pmullw_128(a[127..0], b[127..0])

val avx_pmullw_512 : (zmmword, zmmword) -> zmmword
function avx_pmullw_512(a, b) =
  avx_pmullw_256(a[511..256], b[511..256]) @ avx_pmullw_256(a[255..0], b[255..0])

// =========================================================================
// VPMULHW: multiply high signed word
// =========================================================================

val avx_pmulhw_128 : (xmmword, xmmword) -> xmmword
function avx_pmulhw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let prod : int = signed(a[(lo + 15)..lo]) * signed(b[(lo + 15)..lo]);
    r[(lo + 15)..lo] = get_slice_int(16, prod, 16);
  };
  r
}

val avx_pmulhw_256 : (ymmword, ymmword) -> ymmword
function avx_pmulhw_256(a, b) =
  avx_pmulhw_128(a[255..128], b[255..128]) @ avx_pmulhw_128(a[127..0], b[127..0])

val avx_pmulhw_512 : (zmmword, zmmword) -> zmmword
function avx_pmulhw_512(a, b) =
  avx_pmulhw_256(a[511..256], b[511..256]) @ avx_pmulhw_256(a[255..0], b[255..0])

// =========================================================================
// VPMULHUW: multiply high unsigned word
// =========================================================================

val avx_pmulhuw_128 : (xmmword, xmmword) -> xmmword
function avx_pmulhuw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let prod : int = unsigned(a[(lo + 15)..lo]) * unsigned(b[(lo + 15)..lo]);
    r[(lo + 15)..lo] = get_slice_int(16, prod, 16);
  };
  r
}

val avx_pmulhuw_256 : (ymmword, ymmword) -> ymmword
function avx_pmulhuw_256(a, b) =
  avx_pmulhuw_128(a[255..128], b[255..128]) @ avx_pmulhuw_128(a[127..0], b[127..0])

val avx_pmulhuw_512 : (zmmword, zmmword) -> zmmword
function avx_pmulhuw_512(a, b) =
  avx_pmulhuw_256(a[511..256], b[511..256]) @ avx_pmulhuw_256(a[255..0], b[255..0])

// =========================================================================
// VPMULUDQ: multiply unsigned dwords → unsigned qwords
// For each 64-bit lane: result = src1[31:0] * src2[31:0] (unsigned)
// =========================================================================

val avx_pmuludq_128 : (xmmword, xmmword) -> xmmword
function avx_pmuludq_128(a, b) = {
  let prod1 : qword = to_bits(64, unsigned(a[31..0]) * unsigned(b[31..0]));
  let prod0 : qword = to_bits(64, unsigned(a[95..64]) * unsigned(b[95..64]));
  prod0 @ prod1
}

val avx_pmuludq_256 : (ymmword, ymmword) -> ymmword
function avx_pmuludq_256(a, b) =
  avx_pmuludq_128(a[255..128], b[255..128]) @ avx_pmuludq_128(a[127..0], b[127..0])

val avx_pmuludq_512 : (zmmword, zmmword) -> zmmword
function avx_pmuludq_512(a, b) =
  avx_pmuludq_256(a[511..256], b[511..256]) @ avx_pmuludq_256(a[255..0], b[255..0])

// =========================================================================
// VPAVGB/VPAVGW: unsigned average = (a + b + 1) >> 1
// =========================================================================

val avx_pavgb_128 : (xmmword, xmmword) -> xmmword
function avx_pavgb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    let avg : int = (unsigned(a[(lo + 7)..lo]) + unsigned(b[(lo + 7)..lo]) + 1) / 2;
    r[(lo + 7)..lo] = get_slice_int(8, avg, 0);
  };
  r
}

val avx_pavgb_256 : (ymmword, ymmword) -> ymmword
function avx_pavgb_256(a, b) =
  avx_pavgb_128(a[255..128], b[255..128]) @ avx_pavgb_128(a[127..0], b[127..0])

val avx_pavgb_512 : (zmmword, zmmword) -> zmmword
function avx_pavgb_512(a, b) =
  avx_pavgb_256(a[511..256], b[511..256]) @ avx_pavgb_256(a[255..0], b[255..0])

val avx_pavgw_128 : (xmmword, xmmword) -> xmmword
function avx_pavgw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let avg : int = (unsigned(a[(lo + 15)..lo]) + unsigned(b[(lo + 15)..lo]) + 1) / 2;
    r[(lo + 15)..lo] = get_slice_int(16, avg, 0);
  };
  r
}

val avx_pavgw_256 : (ymmword, ymmword) -> ymmword
function avx_pavgw_256(a, b) =
  avx_pavgw_128(a[255..128], b[255..128]) @ avx_pavgw_128(a[127..0], b[127..0])

val avx_pavgw_512 : (zmmword, zmmword) -> zmmword
function avx_pavgw_512(a, b) =
  avx_pavgw_256(a[511..256], b[511..256]) @ avx_pavgw_256(a[255..0], b[255..0])

// =========================================================================
// VPMAXUB: unsigned byte max
// =========================================================================

val avx_pmaxub_128 : (xmmword, xmmword) -> xmmword
function avx_pmaxub_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    let va = a[(lo + 7)..lo];
    let vb = b[(lo + 7)..lo];
    r[(lo + 7)..lo] = if unsigned(va) > unsigned(vb) then va else vb;
  };
  r
}

val avx_pmaxub_256 : (ymmword, ymmword) -> ymmword
function avx_pmaxub_256(a, b) =
  avx_pmaxub_128(a[255..128], b[255..128]) @ avx_pmaxub_128(a[127..0], b[127..0])

val avx_pmaxub_512 : (zmmword, zmmword) -> zmmword
function avx_pmaxub_512(a, b) =
  avx_pmaxub_256(a[511..256], b[511..256]) @ avx_pmaxub_256(a[255..0], b[255..0])

// =========================================================================
// VPMINSW: signed word min
// =========================================================================

val avx_pminsw_128 : (xmmword, xmmword) -> xmmword
function avx_pminsw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let va = a[(lo + 15)..lo];
    let vb = b[(lo + 15)..lo];
    r[(lo + 15)..lo] = if signed(va) < signed(vb) then va else vb;
  };
  r
}

val avx_pminsw_256 : (ymmword, ymmword) -> ymmword
function avx_pminsw_256(a, b) =
  avx_pminsw_128(a[255..128], b[255..128]) @ avx_pminsw_128(a[127..0], b[127..0])

val avx_pminsw_512 : (zmmword, zmmword) -> zmmword
function avx_pminsw_512(a, b) =
  avx_pminsw_256(a[511..256], b[511..256]) @ avx_pminsw_256(a[255..0], b[255..0])

// =========================================================================
// VPMAXSW: signed word max
// =========================================================================

val avx_pmaxsw_128 : (xmmword, xmmword) -> xmmword
function avx_pmaxsw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let va = a[(lo + 15)..lo];
    let vb = b[(lo + 15)..lo];
    r[(lo + 15)..lo] = if signed(va) > signed(vb) then va else vb;
  };
  r
}

val avx_pmaxsw_256 : (ymmword, ymmword) -> ymmword
function avx_pmaxsw_256(a, b) =
  avx_pmaxsw_128(a[255..128], b[255..128]) @ avx_pmaxsw_128(a[127..0], b[127..0])

val avx_pmaxsw_512 : (zmmword, zmmword) -> zmmword
function avx_pmaxsw_512(a, b) =
  avx_pmaxsw_256(a[511..256], b[511..256]) @ avx_pmaxsw_256(a[255..0], b[255..0])

// =========================================================================
// VPMADDWD: multiply and add packed integers
// Per 128-bit lane: for each pair of words, multiply signed and add adjacent products
// =========================================================================

val avx_pmaddwd_128 : (xmmword, xmmword) -> xmmword
function avx_pmaddwd_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let wlo : range(0, 96) = i * 32;
    let w0 = signed(a[(wlo + 15)..wlo]) * signed(b[(wlo + 15)..wlo]);
    let w1 = signed(a[(wlo + 31)..(wlo + 16)]) * signed(b[(wlo + 31)..(wlo + 16)]);
    r[(wlo + 31)..wlo] = get_slice_int(32, w0 + w1, 0);
  };
  r
}

val avx_pmaddwd_256 : (ymmword, ymmword) -> ymmword
function avx_pmaddwd_256(a, b) =
  avx_pmaddwd_128(a[255..128], b[255..128]) @ avx_pmaddwd_128(a[127..0], b[127..0])

val avx_pmaddwd_512 : (zmmword, zmmword) -> zmmword
function avx_pmaddwd_512(a, b) =
  avx_pmaddwd_256(a[511..256], b[511..256]) @ avx_pmaddwd_256(a[255..0], b[255..0])

// =========================================================================
// VPSADBW: sum of absolute differences of unsigned bytes
// Per 64-bit group: sum |a[i] - b[i]| for 8 byte pairs → 16-bit result in low word
// =========================================================================

val avx_psadbw_64 : (bits(64), bits(64)) -> bits(64)
function avx_psadbw_64(a, b) = {
  var sum : int = 0;
  foreach (i from 0 to 7) {
    let lo : range(0, 56) = i * 8;
    let diff : int = unsigned(a[(lo + 7)..lo]) - unsigned(b[(lo + 7)..lo]);
    sum = sum + (if diff < 0 then negate(diff) else diff);
  };
  zero_extend(get_slice_int(16, sum, 0))
}

val avx_psadbw_128 : (xmmword, xmmword) -> xmmword
function avx_psadbw_128(a, b) =
  avx_psadbw_64(a[127..64], b[127..64]) @ avx_psadbw_64(a[63..0], b[63..0])

val avx_psadbw_256 : (ymmword, ymmword) -> ymmword
function avx_psadbw_256(a, b) =
  avx_psadbw_128(a[255..128], b[255..128]) @ avx_psadbw_128(a[127..0], b[127..0])

val avx_psadbw_512 : (zmmword, zmmword) -> zmmword
function avx_psadbw_512(a, b) =
  avx_psadbw_256(a[511..256], b[511..256]) @ avx_psadbw_256(a[255..0], b[255..0])

// =========================================================================
// VPCMPGTB/W/D → kmask: signed greater-than comparison
// =========================================================================

val avx_pcmpgtb_mask_128 : (xmmword, xmmword) -> word
function avx_pcmpgtb_mask_128(a, b) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    if signed(a[(lo + 7)..lo]) > signed(b[(lo + 7)..lo])
    then r[i] = bitone;
  };
  r
}

val avx_pcmpgtb_mask_256 : (ymmword, ymmword) -> dword
function avx_pcmpgtb_mask_256(a, b) = {
  var r : dword = zeros();
  foreach (i from 0 to 31) {
    let lo : range(0, 248) = i * 8;
    if signed(a[(lo + 7)..lo]) > signed(b[(lo + 7)..lo])
    then r[i] = bitone;
  };
  r
}

val avx_pcmpgtb_mask_512 : (zmmword, zmmword) -> qword
function avx_pcmpgtb_mask_512(a, b) = {
  var r : qword = zeros();
  foreach (i from 0 to 63) {
    let lo : range(0, 504) = i * 8;
    if signed(a[(lo + 7)..lo]) > signed(b[(lo + 7)..lo])
    then r[i] = bitone;
  };
  r
}

val avx_pcmpgtw_mask_128 : (xmmword, xmmword) -> byte
function avx_pcmpgtw_mask_128(a, b) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    if signed(a[(lo + 15)..lo]) > signed(b[(lo + 15)..lo])
    then r[i] = bitone;
  };
  r
}

val avx_pcmpgtw_mask_256 : (ymmword, ymmword) -> word
function avx_pcmpgtw_mask_256(a, b) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 240) = i * 16;
    if signed(a[(lo + 15)..lo]) > signed(b[(lo + 15)..lo])
    then r[i] = bitone;
  };
  r
}

val avx_pcmpgtw_mask_512 : (zmmword, zmmword) -> dword
function avx_pcmpgtw_mask_512(a, b) = {
  var r : dword = zeros();
  foreach (i from 0 to 31) {
    let lo : range(0, 496) = i * 16;
    if signed(a[(lo + 15)..lo]) > signed(b[(lo + 15)..lo])
    then r[i] = bitone;
  };
  r
}

val avx_pcmpgtd_mask_128 : (xmmword, xmmword) -> byte
function avx_pcmpgtd_mask_128(a, b) = {
  var r : byte = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    if signed(a[(lo + 31)..lo]) > signed(b[(lo + 31)..lo])
    then r[i] = bitone;
  };
  r
}

val avx_pcmpgtd_mask_256 : (ymmword, ymmword) -> byte
function avx_pcmpgtd_mask_256(a, b) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 224) = i * 32;
    if signed(a[(lo + 31)..lo]) > signed(b[(lo + 31)..lo])
    then r[i] = bitone;
  };
  r
}

val avx_pcmpgtd_mask_512 : (zmmword, zmmword) -> word
function avx_pcmpgtd_mask_512(a, b) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 480) = i * 32;
    if signed(a[(lo + 31)..lo]) > signed(b[(lo + 31)..lo])
    then r[i] = bitone;
  };
  r
}

// VPCMPEQW → kmask

val avx_pcmpeqw_mask_128 : (xmmword, xmmword) -> byte
function avx_pcmpeqw_mask_128(a, b) = {
  var r : byte = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    if a[(lo + 15)..lo] == b[(lo + 15)..lo]
    then r[i] = bitone;
  };
  r
}

val avx_pcmpeqw_mask_256 : (ymmword, ymmword) -> word
function avx_pcmpeqw_mask_256(a, b) = {
  var r : word = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 240) = i * 16;
    if a[(lo + 15)..lo] == b[(lo + 15)..lo]
    then r[i] = bitone;
  };
  r
}

val avx_pcmpeqw_mask_512 : (zmmword, zmmword) -> dword
function avx_pcmpeqw_mask_512(a, b) = {
  var r : dword = zeros();
  foreach (i from 0 to 31) {
    let lo : range(0, 496) = i * 16;
    if a[(lo + 15)..lo] == b[(lo + 15)..lo]
    then r[i] = bitone;
  };
  r
}

// =========================================================================
// VPUNPCKLBW: interleave low bytes from each 128-bit lane
// For each 128-bit lane: dst[0]=a[0], dst[1]=b[0], dst[2]=a[1], dst[3]=b[1], ...
// =========================================================================

val avx_punpcklbw_128 : (xmmword, xmmword) -> xmmword
function avx_punpcklbw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let src_lo : range(0, 56) = i * 8;
    let dst_lo : range(0, 112) = i * 16;
    r[(dst_lo + 7)..dst_lo] = a[(src_lo + 7)..src_lo];
    r[(dst_lo + 15)..(dst_lo + 8)] = b[(src_lo + 7)..src_lo];
  };
  r
}

val avx_punpcklbw_256 : (ymmword, ymmword) -> ymmword
function avx_punpcklbw_256(a, b) =
  avx_punpcklbw_128(a[255..128], b[255..128]) @ avx_punpcklbw_128(a[127..0], b[127..0])

val avx_punpcklbw_512 : (zmmword, zmmword) -> zmmword
function avx_punpcklbw_512(a, b) =
  avx_punpcklbw_256(a[511..256], b[511..256]) @ avx_punpcklbw_256(a[255..0], b[255..0])

// VPUNPCKLWD: interleave low words from each 128-bit lane

val avx_punpcklwd_128 : (xmmword, xmmword) -> xmmword
function avx_punpcklwd_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let src_lo : range(0, 48) = i * 16;
    let dst_lo : range(0, 96) = i * 32;
    r[(dst_lo + 15)..dst_lo] = a[(src_lo + 15)..src_lo];
    r[(dst_lo + 31)..(dst_lo + 16)] = b[(src_lo + 15)..src_lo];
  };
  r
}

val avx_punpcklwd_256 : (ymmword, ymmword) -> ymmword
function avx_punpcklwd_256(a, b) =
  avx_punpcklwd_128(a[255..128], b[255..128]) @ avx_punpcklwd_128(a[127..0], b[127..0])

val avx_punpcklwd_512 : (zmmword, zmmword) -> zmmword
function avx_punpcklwd_512(a, b) =
  avx_punpcklwd_256(a[511..256], b[511..256]) @ avx_punpcklwd_256(a[255..0], b[255..0])

// VPUNPCKLDQ: interleave low dwords from each 128-bit lane

val avx_punpckldq_128 : (xmmword, xmmword) -> xmmword
function avx_punpckldq_128(a, b) =
  b[63..32] @ a[63..32] @ b[31..0] @ a[31..0]

val avx_punpckldq_256 : (ymmword, ymmword) -> ymmword
function avx_punpckldq_256(a, b) =
  avx_punpckldq_128(a[255..128], b[255..128]) @ avx_punpckldq_128(a[127..0], b[127..0])

val avx_punpckldq_512 : (zmmword, zmmword) -> zmmword
function avx_punpckldq_512(a, b) =
  avx_punpckldq_256(a[511..256], b[511..256]) @ avx_punpckldq_256(a[255..0], b[255..0])

// VPUNPCKLQDQ: interleave low qwords from each 128-bit lane

val avx_punpcklqdq_128 : (xmmword, xmmword) -> xmmword
function avx_punpcklqdq_128(a, b) =
  b[63..0] @ a[63..0]

val avx_punpcklqdq_256 : (ymmword, ymmword) -> ymmword
function avx_punpcklqdq_256(a, b) =
  avx_punpcklqdq_128(a[255..128], b[255..128]) @ avx_punpcklqdq_128(a[127..0], b[127..0])

val avx_punpcklqdq_512 : (zmmword, zmmword) -> zmmword
function avx_punpcklqdq_512(a, b) =
  avx_punpcklqdq_256(a[511..256], b[511..256]) @ avx_punpcklqdq_256(a[255..0], b[255..0])

// =========================================================================
// VPUNPCKHBW: interleave high bytes from each 128-bit lane
// =========================================================================

val avx_punpckhbw_128 : (xmmword, xmmword) -> xmmword
function avx_punpckhbw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let src_lo : range(0, 120) = i * 8 + 64;
    let dst_lo : range(0, 112) = i * 16;
    r[(dst_lo + 7)..dst_lo] = a[(src_lo + 7)..src_lo];
    r[(dst_lo + 15)..(dst_lo + 8)] = b[(src_lo + 7)..src_lo];
  };
  r
}

val avx_punpckhbw_256 : (ymmword, ymmword) -> ymmword
function avx_punpckhbw_256(a, b) =
  avx_punpckhbw_128(a[255..128], b[255..128]) @ avx_punpckhbw_128(a[127..0], b[127..0])

val avx_punpckhbw_512 : (zmmword, zmmword) -> zmmword
function avx_punpckhbw_512(a, b) =
  avx_punpckhbw_256(a[511..256], b[511..256]) @ avx_punpckhbw_256(a[255..0], b[255..0])

// VPUNPCKHWD: interleave high words from each 128-bit lane

val avx_punpckhwd_128 : (xmmword, xmmword) -> xmmword
function avx_punpckhwd_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let src_lo : range(0, 112) = i * 16 + 64;
    let dst_lo : range(0, 96) = i * 32;
    r[(dst_lo + 15)..dst_lo] = a[(src_lo + 15)..src_lo];
    r[(dst_lo + 31)..(dst_lo + 16)] = b[(src_lo + 15)..src_lo];
  };
  r
}

val avx_punpckhwd_256 : (ymmword, ymmword) -> ymmword
function avx_punpckhwd_256(a, b) =
  avx_punpckhwd_128(a[255..128], b[255..128]) @ avx_punpckhwd_128(a[127..0], b[127..0])

val avx_punpckhwd_512 : (zmmword, zmmword) -> zmmword
function avx_punpckhwd_512(a, b) =
  avx_punpckhwd_256(a[511..256], b[511..256]) @ avx_punpckhwd_256(a[255..0], b[255..0])

// VPUNPCKHDQ: interleave high dwords from each 128-bit lane

val avx_punpckhdq_128 : (xmmword, xmmword) -> xmmword
function avx_punpckhdq_128(a, b) =
  b[127..96] @ a[127..96] @ b[95..64] @ a[95..64]

val avx_punpckhdq_256 : (ymmword, ymmword) -> ymmword
function avx_punpckhdq_256(a, b) =
  avx_punpckhdq_128(a[255..128], b[255..128]) @ avx_punpckhdq_128(a[127..0], b[127..0])

val avx_punpckhdq_512 : (zmmword, zmmword) -> zmmword
function avx_punpckhdq_512(a, b) =
  avx_punpckhdq_256(a[511..256], b[511..256]) @ avx_punpckhdq_256(a[255..0], b[255..0])

// VPUNPCKHQDQ: interleave high qwords from each 128-bit lane

val avx_punpckhqdq_128 : (xmmword, xmmword) -> xmmword
function avx_punpckhqdq_128(a, b) =
  b[127..64] @ a[127..64]

val avx_punpckhqdq_256 : (ymmword, ymmword) -> ymmword
function avx_punpckhqdq_256(a, b) =
  avx_punpckhqdq_128(a[255..128], b[255..128]) @ avx_punpckhqdq_128(a[127..0], b[127..0])

val avx_punpckhqdq_512 : (zmmword, zmmword) -> zmmword
function avx_punpckhqdq_512(a, b) =
  avx_punpckhqdq_256(a[511..256], b[511..256]) @ avx_punpckhqdq_256(a[255..0], b[255..0])

// =========================================================================
// VPACKSSWB: pack signed words to signed bytes with saturation
// Per 128-bit lane: 8 words from src1 → low 8 bytes, 8 words from src2 → high 8 bytes
// =========================================================================

val saturate_sw_to_sb : word -> byte
function saturate_sw_to_sb(w) = {
  let v : int = signed(w);
  if v > 127 then 0x7F
  else if v < negate(128) then 0x80
  else get_slice_int(8, v, 0)
}

val avx_packsswb_128 : (xmmword, xmmword) -> xmmword
function avx_packsswb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let src_lo : range(0, 112) = i * 16;
    r[(i * 8 + 7)..(i * 8)] = saturate_sw_to_sb(a[(src_lo + 15)..src_lo]);
    r[(i * 8 + 71)..(i * 8 + 64)] = saturate_sw_to_sb(b[(src_lo + 15)..src_lo]);
  };
  r
}

val avx_packsswb_256 : (ymmword, ymmword) -> ymmword
function avx_packsswb_256(a, b) =
  avx_packsswb_128(a[255..128], b[255..128]) @ avx_packsswb_128(a[127..0], b[127..0])

val avx_packsswb_512 : (zmmword, zmmword) -> zmmword
function avx_packsswb_512(a, b) =
  avx_packsswb_256(a[511..256], b[511..256]) @ avx_packsswb_256(a[255..0], b[255..0])

// VPACKSSDW: pack signed dwords to signed words with saturation

val saturate_sd_to_sw : dword -> word
function saturate_sd_to_sw(d) = {
  let v : int = signed(d);
  if v > 32767 then 0x7FFF
  else if v < negate(32768) then 0x8000
  else get_slice_int(16, v, 0)
}

val avx_packssdw_128 : (xmmword, xmmword) -> xmmword
function avx_packssdw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let src_lo : range(0, 96) = i * 32;
    r[(i * 16 + 15)..(i * 16)] = saturate_sd_to_sw(a[(src_lo + 31)..src_lo]);
    r[(i * 16 + 79)..(i * 16 + 64)] = saturate_sd_to_sw(b[(src_lo + 31)..src_lo]);
  };
  r
}

val avx_packssdw_256 : (ymmword, ymmword) -> ymmword
function avx_packssdw_256(a, b) =
  avx_packssdw_128(a[255..128], b[255..128]) @ avx_packssdw_128(a[127..0], b[127..0])

val avx_packssdw_512 : (zmmword, zmmword) -> zmmword
function avx_packssdw_512(a, b) =
  avx_packssdw_256(a[511..256], b[511..256]) @ avx_packssdw_256(a[255..0], b[255..0])

// VPACKUSWB: pack signed words to unsigned bytes with saturation

val saturate_sw_to_ub : word -> byte
function saturate_sw_to_ub(w) = {
  let v : int = signed(w);
  if v > 255 then 0xFF
  else if v < 0 then 0x00
  else get_slice_int(8, v, 0)
}

val avx_packuswb_128 : (xmmword, xmmword) -> xmmword
function avx_packuswb_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let src_lo : range(0, 112) = i * 16;
    r[(i * 8 + 7)..(i * 8)] = saturate_sw_to_ub(a[(src_lo + 15)..src_lo]);
    r[(i * 8 + 71)..(i * 8 + 64)] = saturate_sw_to_ub(b[(src_lo + 15)..src_lo]);
  };
  r
}

val avx_packuswb_256 : (ymmword, ymmword) -> ymmword
function avx_packuswb_256(a, b) =
  avx_packuswb_128(a[255..128], b[255..128]) @ avx_packuswb_128(a[127..0], b[127..0])

val avx_packuswb_512 : (zmmword, zmmword) -> zmmword
function avx_packuswb_512(a, b) =
  avx_packuswb_256(a[511..256], b[511..256]) @ avx_packuswb_256(a[255..0], b[255..0])

// =========================================================================
// VPSHUFD: shuffle dwords within each 128-bit lane by imm8
// =========================================================================

val avx_pshufd_128 : (xmmword, byte) -> xmmword
function avx_pshufd_128(src, imm) = {
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

val avx_pshufd_256 : (ymmword, byte) -> ymmword
function avx_pshufd_256(src, imm) =
  avx_pshufd_128(src[255..128], imm) @ avx_pshufd_128(src[127..0], imm)

val avx_pshufd_512 : (zmmword, byte) -> zmmword
function avx_pshufd_512(src, imm) =
  avx_pshufd_256(src[511..256], imm) @ avx_pshufd_256(src[255..0], imm)

// VPSHUFHW: shuffle high words within each 128-bit lane, low qword unchanged

val avx_pshufhw_128 : (xmmword, byte) -> xmmword
function avx_pshufhw_128(src, imm) = {
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

val avx_pshufhw_256 : (ymmword, byte) -> ymmword
function avx_pshufhw_256(src, imm) =
  avx_pshufhw_128(src[255..128], imm) @ avx_pshufhw_128(src[127..0], imm)

val avx_pshufhw_512 : (zmmword, byte) -> zmmword
function avx_pshufhw_512(src, imm) =
  avx_pshufhw_256(src[511..256], imm) @ avx_pshufhw_256(src[255..0], imm)

// VPSHUFLW: shuffle low words within each 128-bit lane, high qword unchanged

val avx_pshuflw_128 : (xmmword, byte) -> xmmword
function avx_pshuflw_128(src, imm) = {
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

val avx_pshuflw_256 : (ymmword, byte) -> ymmword
function avx_pshuflw_256(src, imm) =
  avx_pshuflw_128(src[255..128], imm) @ avx_pshuflw_128(src[127..0], imm)

val avx_pshuflw_512 : (zmmword, byte) -> zmmword
function avx_pshuflw_512(src, imm) =
  avx_pshuflw_256(src[511..256], imm) @ avx_pshuflw_256(src[255..0], imm)

// =========================================================================
// Shift by immediate: VPSRLW/D/Q, VPSLLW/D/Q, VPSRAW/D, VPSRAQ
// If count >= element_size, result is 0 (logical) or sign-extended (arithmetic)
// =========================================================================

// VPSRLW: logical right shift words by imm

val avx_psrlw_imm_128 : (xmmword, range(0, 255)) -> xmmword
function avx_psrlw_imm_128(a, count) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = if count >= 16 then zeros() else a[(lo + 15)..lo] >> count;
  };
  r
}

val avx_psrlw_imm_256 : (ymmword, range(0, 255)) -> ymmword
function avx_psrlw_imm_256(a, count) =
  avx_psrlw_imm_128(a[255..128], count) @ avx_psrlw_imm_128(a[127..0], count)

val avx_psrlw_imm_512 : (zmmword, range(0, 255)) -> zmmword
function avx_psrlw_imm_512(a, count) =
  avx_psrlw_imm_256(a[511..256], count) @ avx_psrlw_imm_256(a[255..0], count)

// VPSRLD: logical right shift dwords by imm

val avx_psrld_imm_128 : (xmmword, range(0, 255)) -> xmmword
function avx_psrld_imm_128(a, count) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = if count >= 32 then zeros() else a[(lo + 31)..lo] >> count;
  };
  r
}

val avx_psrld_imm_256 : (ymmword, range(0, 255)) -> ymmword
function avx_psrld_imm_256(a, count) =
  avx_psrld_imm_128(a[255..128], count) @ avx_psrld_imm_128(a[127..0], count)

val avx_psrld_imm_512 : (zmmword, range(0, 255)) -> zmmword
function avx_psrld_imm_512(a, count) =
  avx_psrld_imm_256(a[511..256], count) @ avx_psrld_imm_256(a[255..0], count)

// VPSRLQ: logical right shift qwords by imm

val avx_psrlq_imm_128 : (xmmword, range(0, 255)) -> xmmword
function avx_psrlq_imm_128(a, count) = {
  var r : xmmword = zeros();
  r[63..0] = if count >= 64 then zeros() else a[63..0] >> count;
  r[127..64] = if count >= 64 then zeros() else a[127..64] >> count;
  r
}

val avx_psrlq_imm_256 : (ymmword, range(0, 255)) -> ymmword
function avx_psrlq_imm_256(a, count) =
  avx_psrlq_imm_128(a[255..128], count) @ avx_psrlq_imm_128(a[127..0], count)

val avx_psrlq_imm_512 : (zmmword, range(0, 255)) -> zmmword
function avx_psrlq_imm_512(a, count) =
  avx_psrlq_imm_256(a[511..256], count) @ avx_psrlq_imm_256(a[255..0], count)

// VPSLLW: logical left shift words by imm

val avx_psllw_imm_128 : (xmmword, range(0, 255)) -> xmmword
function avx_psllw_imm_128(a, count) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = if count >= 16 then zeros() else a[(lo + 15)..lo] << count;
  };
  r
}

val avx_psllw_imm_256 : (ymmword, range(0, 255)) -> ymmword
function avx_psllw_imm_256(a, count) =
  avx_psllw_imm_128(a[255..128], count) @ avx_psllw_imm_128(a[127..0], count)

val avx_psllw_imm_512 : (zmmword, range(0, 255)) -> zmmword
function avx_psllw_imm_512(a, count) =
  avx_psllw_imm_256(a[511..256], count) @ avx_psllw_imm_256(a[255..0], count)

// VPSLLD: logical left shift dwords by imm

val avx_pslld_imm_128 : (xmmword, range(0, 255)) -> xmmword
function avx_pslld_imm_128(a, count) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = if count >= 32 then zeros() else a[(lo + 31)..lo] << count;
  };
  r
}

val avx_pslld_imm_256 : (ymmword, range(0, 255)) -> ymmword
function avx_pslld_imm_256(a, count) =
  avx_pslld_imm_128(a[255..128], count) @ avx_pslld_imm_128(a[127..0], count)

val avx_pslld_imm_512 : (zmmword, range(0, 255)) -> zmmword
function avx_pslld_imm_512(a, count) =
  avx_pslld_imm_256(a[511..256], count) @ avx_pslld_imm_256(a[255..0], count)

// VPSLLQ: logical left shift qwords by imm

val avx_psllq_imm_128 : (xmmword, range(0, 255)) -> xmmword
function avx_psllq_imm_128(a, count) = {
  var r : xmmword = zeros();
  r[63..0] = if count >= 64 then zeros() else a[63..0] << count;
  r[127..64] = if count >= 64 then zeros() else a[127..64] << count;
  r
}

val avx_psllq_imm_256 : (ymmword, range(0, 255)) -> ymmword
function avx_psllq_imm_256(a, count) =
  avx_psllq_imm_128(a[255..128], count) @ avx_psllq_imm_128(a[127..0], count)

val avx_psllq_imm_512 : (zmmword, range(0, 255)) -> zmmword
function avx_psllq_imm_512(a, count) =
  avx_psllq_imm_256(a[511..256], count) @ avx_psllq_imm_256(a[255..0], count)

// VPSRAW: arithmetic right shift words by imm

val arith_shr_word : (word, range(0, 255)) -> word
function arith_shr_word(v, count) = {
  if count == 0 then v
  else if count >= 16 then (if v[15] == bitone then ones() else zeros())
  else {
    // Logical shift right, then fill high bits with sign bit
    let shifted : word = v >> count;
    let sign_bit = v[15];
    var r : word = shifted;
    foreach (i from 0 to 14) {
      let bit_idx : range(0, 15) = 15 - i;
      if i < count then r[bit_idx] = sign_bit;
    };
    r
  }
}

val avx_psraw_imm_128 : (xmmword, range(0, 255)) -> xmmword
function avx_psraw_imm_128(a, count) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = arith_shr_word(a[(lo + 15)..lo], count);
  };
  r
}

val avx_psraw_imm_256 : (ymmword, range(0, 255)) -> ymmword
function avx_psraw_imm_256(a, count) =
  avx_psraw_imm_128(a[255..128], count) @ avx_psraw_imm_128(a[127..0], count)

val avx_psraw_imm_512 : (zmmword, range(0, 255)) -> zmmword
function avx_psraw_imm_512(a, count) =
  avx_psraw_imm_256(a[511..256], count) @ avx_psraw_imm_256(a[255..0], count)

// VPSRAD: arithmetic right shift dwords by imm

val arith_shr_dword : (dword, range(0, 255)) -> dword
function arith_shr_dword(v, count) = {
  if count == 0 then v
  else if count >= 32 then (if v[31] == bitone then ones() else zeros())
  else {
    let shifted : dword = v >> count;
    let sign_bit = v[31];
    var r : dword = shifted;
    foreach (i from 0 to 30) {
      let bit_idx : range(0, 31) = 31 - i;
      if i < count then r[bit_idx] = sign_bit;
    };
    r
  }
}

val avx_psrad_imm_128 : (xmmword, range(0, 255)) -> xmmword
function avx_psrad_imm_128(a, count) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = arith_shr_dword(a[(lo + 31)..lo], count);
  };
  r
}

val avx_psrad_imm_256 : (ymmword, range(0, 255)) -> ymmword
function avx_psrad_imm_256(a, count) =
  avx_psrad_imm_128(a[255..128], count) @ avx_psrad_imm_128(a[127..0], count)

val avx_psrad_imm_512 : (zmmword, range(0, 255)) -> zmmword
function avx_psrad_imm_512(a, count) =
  avx_psrad_imm_256(a[511..256], count) @ avx_psrad_imm_256(a[255..0], count)

// VPSRAQ: arithmetic right shift qwords by imm (AVX-512 new)

val arith_shr_qword : (qword, range(0, 255)) -> qword
function arith_shr_qword(v, count) = {
  if count == 0 then v
  else if count >= 64 then (if v[63] == bitone then ones() else zeros())
  else {
    let shifted : qword = v >> count;
    let sign_bit = v[63];
    var r : qword = shifted;
    foreach (i from 0 to 62) {
      let bit_idx : range(0, 63) = 63 - i;
      if i < count then r[bit_idx] = sign_bit;
    };
    r
  }
}

val avx_psraq_imm_128 : (xmmword, range(0, 255)) -> xmmword
function avx_psraq_imm_128(a, count) = {
  var r : xmmword = zeros();
  r[63..0] = arith_shr_qword(a[63..0], count);
  r[127..64] = arith_shr_qword(a[127..64], count);
  r
}

val avx_psraq_imm_256 : (ymmword, range(0, 255)) -> ymmword
function avx_psraq_imm_256(a, count) =
  avx_psraq_imm_128(a[255..128], count) @ avx_psraq_imm_128(a[127..0], count)

val avx_psraq_imm_512 : (zmmword, range(0, 255)) -> zmmword
function avx_psraq_imm_512(a, count) =
  avx_psraq_imm_256(a[511..256], count) @ avx_psraq_imm_256(a[255..0], count)

// VPSLLDQ: byte shift left per 128-bit lane

val avx_pslldq_128 : (xmmword, range(0, 255)) -> xmmword
function avx_pslldq_128(a, count) = {
  let cnt = if count > 15 then 16 else count;
  a << (cnt * 8)
}

val avx_pslldq_256 : (ymmword, range(0, 255)) -> ymmword
function avx_pslldq_256(a, count) =
  avx_pslldq_128(a[255..128], count) @ avx_pslldq_128(a[127..0], count)

val avx_pslldq_512 : (zmmword, range(0, 255)) -> zmmword
function avx_pslldq_512(a, count) =
  avx_pslldq_256(a[511..256], count) @ avx_pslldq_256(a[255..0], count)

// VPSRLDQ: byte shift right per 128-bit lane

val avx_psrldq_128 : (xmmword, range(0, 255)) -> xmmword
function avx_psrldq_128(a, count) = {
  let cnt = if count > 15 then 16 else count;
  a >> (cnt * 8)
}

val avx_psrldq_256 : (ymmword, range(0, 255)) -> ymmword
function avx_psrldq_256(a, count) =
  avx_psrldq_128(a[255..128], count) @ avx_psrldq_128(a[127..0], count)

val avx_psrldq_512 : (zmmword, range(0, 255)) -> zmmword
function avx_psrldq_512(a, count) =
  avx_psrldq_256(a[511..256], count) @ avx_psrldq_256(a[255..0], count)

// =========================================================================
// Shift by XMM count: count comes from low 64 bits of XMM register
// Same functions as imm but count extracted from xmm src2[63:0]
// =========================================================================

val clamp_shift_count : int -> range(0, 255)
function clamp_shift_count(c) = {
  let r : range(0, 255) = if c > 255 then 255 else if c < 0 then 0 else c;
  r
}

// VPSRLW by xmm count

val avx_psrlw_xmm_128 : (xmmword, xmmword) -> xmmword
function avx_psrlw_xmm_128(a, count_xmm) =
  avx_psrlw_imm_128(a, clamp_shift_count(unsigned(count_xmm[63..0])))

val avx_psrlw_xmm_256 : (ymmword, xmmword) -> ymmword
function avx_psrlw_xmm_256(a, count_xmm) =
  avx_psrlw_imm_256(a, clamp_shift_count(unsigned(count_xmm[63..0])))

val avx_psrlw_xmm_512 : (zmmword, xmmword) -> zmmword
function avx_psrlw_xmm_512(a, count_xmm) =
  avx_psrlw_imm_512(a, clamp_shift_count(unsigned(count_xmm[63..0])))

// VPSRLD by xmm count

val avx_psrld_xmm_128 : (xmmword, xmmword) -> xmmword
function avx_psrld_xmm_128(a, count_xmm) =
  avx_psrld_imm_128(a, clamp_shift_count(unsigned(count_xmm[63..0])))

val avx_psrld_xmm_256 : (ymmword, xmmword) -> ymmword
function avx_psrld_xmm_256(a, count_xmm) =
  avx_psrld_imm_256(a, clamp_shift_count(unsigned(count_xmm[63..0])))

val avx_psrld_xmm_512 : (zmmword, xmmword) -> zmmword
function avx_psrld_xmm_512(a, count_xmm) =
  avx_psrld_imm_512(a, clamp_shift_count(unsigned(count_xmm[63..0])))

// VPSRLQ by xmm count

val avx_psrlq_xmm_128 : (xmmword, xmmword) -> xmmword
function avx_psrlq_xmm_128(a, count_xmm) =
  avx_psrlq_imm_128(a, clamp_shift_count(unsigned(count_xmm[63..0])))

val avx_psrlq_xmm_256 : (ymmword, xmmword) -> ymmword
function avx_psrlq_xmm_256(a, count_xmm) =
  avx_psrlq_imm_256(a, clamp_shift_count(unsigned(count_xmm[63..0])))

val avx_psrlq_xmm_512 : (zmmword, xmmword) -> zmmword
function avx_psrlq_xmm_512(a, count_xmm) =
  avx_psrlq_imm_512(a, clamp_shift_count(unsigned(count_xmm[63..0])))

// VPSLLW by xmm count

val avx_psllw_xmm_128 : (xmmword, xmmword) -> xmmword
function avx_psllw_xmm_128(a, count_xmm) =
  avx_psllw_imm_128(a, clamp_shift_count(unsigned(count_xmm[63..0])))

val avx_psllw_xmm_256 : (ymmword, xmmword) -> ymmword
function avx_psllw_xmm_256(a, count_xmm) =
  avx_psllw_imm_256(a, clamp_shift_count(unsigned(count_xmm[63..0])))

val avx_psllw_xmm_512 : (zmmword, xmmword) -> zmmword
function avx_psllw_xmm_512(a, count_xmm) =
  avx_psllw_imm_512(a, clamp_shift_count(unsigned(count_xmm[63..0])))

// VPSLLD by xmm count

val avx_pslld_xmm_128 : (xmmword, xmmword) -> xmmword
function avx_pslld_xmm_128(a, count_xmm) =
  avx_pslld_imm_128(a, clamp_shift_count(unsigned(count_xmm[63..0])))

val avx_pslld_xmm_256 : (ymmword, xmmword) -> ymmword
function avx_pslld_xmm_256(a, count_xmm) =
  avx_pslld_imm_256(a, clamp_shift_count(unsigned(count_xmm[63..0])))

val avx_pslld_xmm_512 : (zmmword, xmmword) -> zmmword
function avx_pslld_xmm_512(a, count_xmm) =
  avx_pslld_imm_512(a, clamp_shift_count(unsigned(count_xmm[63..0])))

// VPSLLQ by xmm count

val avx_psllq_xmm_128 : (xmmword, xmmword) -> xmmword
function avx_psllq_xmm_128(a, count_xmm) =
  avx_psllq_imm_128(a, clamp_shift_count(unsigned(count_xmm[63..0])))

val avx_psllq_xmm_256 : (ymmword, xmmword) -> ymmword
function avx_psllq_xmm_256(a, count_xmm) =
  avx_psllq_imm_256(a, clamp_shift_count(unsigned(count_xmm[63..0])))

val avx_psllq_xmm_512 : (zmmword, xmmword) -> zmmword
function avx_psllq_xmm_512(a, count_xmm) =
  avx_psllq_imm_512(a, clamp_shift_count(unsigned(count_xmm[63..0])))

// VPSRAW by xmm count

val avx_psraw_xmm_128 : (xmmword, xmmword) -> xmmword
function avx_psraw_xmm_128(a, count_xmm) =
  avx_psraw_imm_128(a, clamp_shift_count(unsigned(count_xmm[63..0])))

val avx_psraw_xmm_256 : (ymmword, xmmword) -> ymmword
function avx_psraw_xmm_256(a, count_xmm) =
  avx_psraw_imm_256(a, clamp_shift_count(unsigned(count_xmm[63..0])))

val avx_psraw_xmm_512 : (zmmword, xmmword) -> zmmword
function avx_psraw_xmm_512(a, count_xmm) =
  avx_psraw_imm_512(a, clamp_shift_count(unsigned(count_xmm[63..0])))

// VPSRAD by xmm count

val avx_psrad_xmm_128 : (xmmword, xmmword) -> xmmword
function avx_psrad_xmm_128(a, count_xmm) =
  avx_psrad_imm_128(a, clamp_shift_count(unsigned(count_xmm[63..0])))

val avx_psrad_xmm_256 : (ymmword, xmmword) -> ymmword
function avx_psrad_xmm_256(a, count_xmm) =
  avx_psrad_imm_256(a, clamp_shift_count(unsigned(count_xmm[63..0])))

val avx_psrad_xmm_512 : (zmmword, xmmword) -> zmmword
function avx_psrad_xmm_512(a, count_xmm) =
  avx_psrad_imm_512(a, clamp_shift_count(unsigned(count_xmm[63..0])))

// VPSRAQ by xmm count

val avx_psraq_xmm_128 : (xmmword, xmmword) -> xmmword
function avx_psraq_xmm_128(a, count_xmm) =
  avx_psraq_imm_128(a, clamp_shift_count(unsigned(count_xmm[63..0])))

val avx_psraq_xmm_256 : (ymmword, xmmword) -> ymmword
function avx_psraq_xmm_256(a, count_xmm) =
  avx_psraq_imm_256(a, clamp_shift_count(unsigned(count_xmm[63..0])))

val avx_psraq_xmm_512 : (zmmword, xmmword) -> zmmword
function avx_psraq_xmm_512(a, count_xmm) =
  avx_psraq_imm_512(a, clamp_shift_count(unsigned(count_xmm[63..0])))

// =========================================================================
// VMOVSLDUP — Duplicate Even-Indexed Single-FP Values
// Each pair of 32-bit floats: [A, B] → [A, A] (even index duplicated)
// =========================================================================


val dispatch_evex_int : (range(0, 255), Prefixes) -> ExecutionResult
function dispatch_evex_int(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {
  // 0F 6F: VMOVDQA32/VMOVDQA64/VMOVDQU32/VMOVDQU64 (EVEX load)
  111 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match pfx.evex_ll {
      2 => { write_zmm(dst, evex_src_zmm(modrm, rm, pfx)); Ok(()) },
      1 => { write_ymm(dst, evex_src_ymm(modrm, rm, pfx)); Ok(()) },
      _ => { write_xmm(dst, evex_src_xmm(modrm, rm, pfx)); Ok(()) },
    }
  },

  // 0F 7F: VMOVDQA32/VMOVDQA64/VMOVDQU32/VMOVDQU64 (EVEX store)
  // 0F 7F: VMOVDQA32/VMOVDQA64/VMOVDQU32/VMOVDQU64 (EVEX store)
  127 => {
    let modrm = fetch_byte();
    let src = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match rm {
      RM_reg(_) => {
        let dst = evex_rm_reg_idx(modrm, pfx);
        match pfx.evex_ll {
          2 => { write_zmm(dst, read_zmm(src)); Ok(()) },
          1 => { write_ymm(dst, read_ymm(src)); Ok(()) },
          _ => { write_xmm(dst, read_xmm(src)); Ok(()) },
        }
      },
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        match pfx.evex_ll {
          2 => { mem_write512(a, read_zmm(src)); Ok(()) },
          1 => { mem_write256(a, read_ymm(src)); Ok(()) },
          _ => { mem_write128(a, read_xmm(src)); Ok(()) },
        }
      },
    }
  },

  // 0F EF: VPXORD/VPXORQ (EVEX, 66 prefix)
  // 0F EF: VPXORD/VPXORQ (EVEX, 66 prefix)
  239 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, xor_vec(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, xor_vec(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, xor_vec(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F DB: VPANDD/VPANDQ (EVEX, 66 prefix)
  // 0F DB: VPANDD/VPANDQ (EVEX, 66 prefix)
  219 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, read_zmm(pfx.evex_vvvvv) & evex_src_zmm(modrm, rm, pfx)); Ok(()) },
        1 => { write_ymm(dst, read_ymm(pfx.evex_vvvvv) & evex_src_ymm(modrm, rm, pfx)); Ok(()) },
        _ => { write_xmm(dst, read_xmm(pfx.evex_vvvvv) & evex_src_xmm(modrm, rm, pfx)); Ok(()) },
      }
    }
  },

  // 0F EB: VPORD/VPORQ (EVEX, 66 prefix)
  // 0F EB: VPORD/VPORQ (EVEX, 66 prefix)
  235 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, read_zmm(pfx.evex_vvvvv) | evex_src_zmm(modrm, rm, pfx)); Ok(()) },
        1 => { write_ymm(dst, read_ymm(pfx.evex_vvvvv) | evex_src_ymm(modrm, rm, pfx)); Ok(()) },
        _ => { write_xmm(dst, read_xmm(pfx.evex_vvvvv) | evex_src_xmm(modrm, rm, pfx)); Ok(()) },
      }
    }
  },

  // 0F FE: VPADDD (EVEX, 66 prefix)
  // 0F FE: VPADDD (EVEX, 66 prefix)
  254 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let result = avx_paddd_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx));
          let masked = apply_writemask_ps_zmm(result, read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok(())
        },
        1 => { write_ymm(dst, avx_paddd_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_paddd_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F FA: VPSUBD (EVEX, 66 prefix)
  // 0F FA: VPSUBD (EVEX, 66 prefix)
  250 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let result = avx_psubd_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx));
          let masked = apply_writemask_ps_zmm(result, read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok(())
        },
        1 => { write_ymm(dst, avx_psubd_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psubd_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F D4: VPADDQ (EVEX, 66 prefix)
  // 0F D4: VPADDQ (EVEX, 66 prefix)
  212 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let result = avx_paddq_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx));
          let masked = apply_writemask_pd_zmm(result, read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok(())
        },
        1 => { write_ymm(dst, avx_paddq_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_paddq_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F FB: VPSUBQ (EVEX, 66 prefix)
  // 0F FB: VPSUBQ (EVEX, 66 prefix)
  251 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let result = avx_psubq_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx));
          let masked = apply_writemask_pd_zmm(result, read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z);
          write_zmm(dst, masked); Ok(())
        },
        1 => { write_ymm(dst, avx_psubq_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psubq_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 6E: VMOVD (66, W=0) / VMOVQ (66, W=1) — load from GPR/mem to XMM
  // 0F 6E: VMOVD (66, W=0) / VMOVQ (66, W=1) — load from GPR/mem to XMM
  110 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      if pfx.rex_w then {
        // VMOVQ: load qword into XMM, zero upper (EVEX zeros full 512 bits)
        let rm = decode_rm_evex(modrm, pfx, 8);
        let v : qword = match rm {
          RM_reg(_) => read_gpr64(modrm_rm_reg(modrm, pfx)),
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_zmm(dst, zero_extend(v));
        Ok(())
      } else {
        // VMOVD: load dword into XMM, zero upper (EVEX zeros full 512 bits)
        let rm = decode_rm_evex(modrm, pfx, 4);
        let v : dword = match rm {
          RM_reg(_) => read_gpr32(modrm_rm_reg(modrm, pfx)),
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        write_zmm(dst, zero_extend(v));
        Ok(())
      }
    }
  },

  // 0F 74: VPCMPEQB → kmask (66, EVEX)
  // 0F 74: VPCMPEQB → kmask (66, EVEX)
  116 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let src1 = read_zmm(pfx.evex_vvvvv);
          let src2 = evex_src_zmm(modrm, rm, pfx);
          let mask = avx_pcmpeqb_mask_512(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then mask else mask & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        1 => {
          let src1 = read_ymm(pfx.evex_vvvvv);
          let src2 = evex_src_ymm(modrm, rm, pfx);
          let mask : dword = avx_pcmpeqb_mask_256(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        _ => {
          let src1 = read_xmm(pfx.evex_vvvvv);
          let src2 = evex_src_xmm(modrm, rm, pfx);
          let mask : word = avx_pcmpeqb_mask_128(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
      }
    }
  },

  // 0F 76: VPCMPEQD → kmask (66, EVEX)
  // 0F 76: VPCMPEQD → kmask (66, EVEX)
  118 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let src1 = read_zmm(pfx.evex_vvvvv);
          let src2 = evex_src_zmm(modrm, rm, pfx);
          let mask : word = avx_pcmpeqd_mask_512(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        1 => {
          let src1 = read_ymm(pfx.evex_vvvvv);
          let src2 = evex_src_ymm(modrm, rm, pfx);
          let mask : byte = avx_pcmpeqd_mask_256(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        _ => {
          let src1 = read_xmm(pfx.evex_vvvvv);
          let src2 = evex_src_xmm(modrm, rm, pfx);
          let mask : byte = avx_pcmpeqd_mask_128(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
      }
    }
  },

  // 0F 7E: VMOVD (66, W=0) / VMOVQ (66, W=1) — store from XMM to GPR/mem
  // 0F 7E: VMOVD (66, W=0) / VMOVQ (66, W=1) — store from XMM to GPR/mem
  126 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      if pfx.rex_w then {
        let rm = decode_rm_evex(modrm, pfx, 8);
        let v : qword = read_xmm(src)[63..0];
        match rm {
          RM_reg(_) => { write_gpr64(modrm_rm_reg(modrm, pfx), v); Ok(()) },
          RM_mem(addr) => { mem_write64(fixup_addr(addr), v); Ok(()) },
        }
      } else {
        let rm = decode_rm_evex(modrm, pfx, 4);
        let v : dword = read_xmm(src)[31..0];
        match rm {
          RM_reg(_) => { write_gpr32(modrm_rm_reg(modrm, pfx), v); Ok(()) },
          RM_mem(addr) => { mem_write32(fixup_addr(addr), v); Ok(()) },
        }
      }
    }
  },

  // 0F DA: VPMINUB (66, EVEX)
  // 0F DA: VPMINUB (66, EVEX)
  218 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pminub_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pminub_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pminub_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F E7: VMOVNTDQ (66, EVEX) — non-temporal store (we just do a regular store)
  // 0F E7: VMOVNTDQ (66, EVEX) — non-temporal store (we just do a regular store)
  231 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match rm {
        RM_mem(addr) => {
          let a = fixup_addr(addr);
          match pfx.evex_ll {
            2 => { mem_write512(a, read_zmm(src)); Ok(()) },
            1 => { mem_write256(a, read_ymm(src)); Ok(()) },
            _ => { mem_write128(a, read_xmm(src)); Ok(()) },
          }
        },
        _ => raise_UD(), // VMOVNTDQ requires memory destination
      }
    }
  },

  // 0F F8: VPSUBB (66, EVEX)
  // 0F F8: VPSUBB (66, EVEX)
  248 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psubb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_psubb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psubb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F FC: VPADDB (66, EVEX)
  // 0F FC: VPADDB (66, EVEX)
  252 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_paddb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_paddb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_paddb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F DF: VPANDND (66,W0) / VPANDNQ (66,W1)
  // 0F DF: VPANDND (66,W0) / VPANDNQ (66,W1)
  223 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, ~(read_zmm(pfx.evex_vvvvv)) & evex_src_zmm(modrm, rm, pfx)); Ok(()) },
        1 => { write_ymm(dst, ~(read_ymm(pfx.evex_vvvvv)) & evex_src_ymm(modrm, rm, pfx)); Ok(()) },
        _ => { write_xmm(dst, ~(read_xmm(pfx.evex_vvvvv)) & evex_src_xmm(modrm, rm, pfx)); Ok(()) },
      }
    }
  },

  // 0F FD: VPADDW (66, EVEX) [BW]
  // 0F FD: VPADDW (66, EVEX) [BW]
  253 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_paddw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_paddw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_paddw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F F9: VPSUBW (66, EVEX) [BW]
  // 0F F9: VPSUBW (66, EVEX) [BW]
  249 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psubw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_psubw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psubw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F EC: VPADDSB (66, EVEX) [BW]
  // 0F EC: VPADDSB (66, EVEX) [BW]
  236 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_paddsb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_paddsb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_paddsb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F ED: VPADDSW (66, EVEX) [BW]
  // 0F ED: VPADDSW (66, EVEX) [BW]
  237 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_paddsw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_paddsw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_paddsw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F E8: VPSUBSB (66, EVEX) [BW]
  // 0F E8: VPSUBSB (66, EVEX) [BW]
  232 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psubsb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_psubsb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psubsb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F E9: VPSUBSW (66, EVEX) [BW]
  // 0F E9: VPSUBSW (66, EVEX) [BW]
  233 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psubsw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_psubsw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psubsw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F DC: VPADDUSB (66, EVEX) [BW]
  // 0F DC: VPADDUSB (66, EVEX) [BW]
  220 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_paddusb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_paddusb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_paddusb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F DD: VPADDUSW (66, EVEX) [BW]
  // 0F DD: VPADDUSW (66, EVEX) [BW]
  221 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_paddusw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_paddusw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_paddusw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F D8: VPSUBUSB (66, EVEX) [BW]
  // 0F D8: VPSUBUSB (66, EVEX) [BW]
  216 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psubusb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_psubusb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psubusb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F D9: VPSUBUSW (66, EVEX) [BW]
  // 0F D9: VPSUBUSW (66, EVEX) [BW]
  217 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psubusw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_psubusw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psubusw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F D5: VPMULLW (66, EVEX) [BW]
  // 0F D5: VPMULLW (66, EVEX) [BW]
  213 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pmullw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pmullw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pmullw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F E4: VPMULHUW (66, EVEX) [BW]
  // 0F E4: VPMULHUW (66, EVEX) [BW]
  228 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pmulhuw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pmulhuw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pmulhuw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F E5: VPMULHW (66, EVEX) [BW]
  // 0F E5: VPMULHW (66, EVEX) [BW]
  229 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pmulhw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pmulhw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pmulhw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F DE: VPMAXUB (66, EVEX) [BW]
  // 0F DE: VPMAXUB (66, EVEX) [BW]
  222 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pmaxub_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pmaxub_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pmaxub_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F EA: VPMINSW (66, EVEX) [BW]
  // 0F EA: VPMINSW (66, EVEX) [BW]
  234 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pminsw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pminsw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pminsw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F EE: VPMAXSW (66, EVEX) [BW]
  // 0F EE: VPMAXSW (66, EVEX) [BW]
  238 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pmaxsw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pmaxsw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pmaxsw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F E0: VPAVGB (66, EVEX) [BW]
  // 0F E0: VPAVGB (66, EVEX) [BW]
  224 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pavgb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pavgb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pavgb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F E3: VPAVGW (66, EVEX) [BW]
  // 0F E3: VPAVGW (66, EVEX) [BW]
  227 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pavgw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pavgw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pavgw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F F4: VPMULUDQ (66, EVEX) [F]
  // 0F F4: VPMULUDQ (66, EVEX) [F]
  244 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pmuludq_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pmuludq_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pmuludq_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F F5: VPMADDWD (66, EVEX) [BW]
  // 0F F5: VPMADDWD (66, EVEX) [BW]
  245 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pmaddwd_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_pmaddwd_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_pmaddwd_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F F6: VPSADBW (66, EVEX) [BW] — no writemask
  // 0F F6: VPSADBW (66, EVEX) [BW] — no writemask
  246 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psadbw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_psadbw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_psadbw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 64: VPCMPGTB → kmask (66, EVEX) [BW]
  // 0F 64: VPCMPGTB → kmask (66, EVEX) [BW]
  100 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let mask = avx_pcmpgtb_mask_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then mask else mask & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        1 => {
          let mask : dword = avx_pcmpgtb_mask_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        _ => {
          let mask : word = avx_pcmpgtb_mask_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
      }
    }
  },

  // 0F 65: VPCMPGTW → kmask (66, EVEX) [BW]
  // 0F 65: VPCMPGTW → kmask (66, EVEX) [BW]
  101 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let mask : dword = avx_pcmpgtw_mask_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        1 => {
          let mask : word = avx_pcmpgtw_mask_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        _ => {
          let mask : byte = avx_pcmpgtw_mask_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
      }
    }
  },

  // 0F 66: VPCMPGTD → kmask (66, EVEX) [F]
  // 0F 66: VPCMPGTD → kmask (66, EVEX) [F]
  102 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let mask : word = avx_pcmpgtd_mask_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        1 => {
          let mask : byte = avx_pcmpgtd_mask_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        _ => {
          let mask : byte = avx_pcmpgtd_mask_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
      }
    }
  },

  // 0F 75: VPCMPEQW → kmask (66, EVEX) [BW]
  // 0F 75: VPCMPEQW → kmask (66, EVEX) [BW]
  117 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => {
          let mask : dword = avx_pcmpeqw_mask_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        1 => {
          let mask : word = avx_pcmpeqw_mask_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
        _ => {
          let mask : byte = avx_pcmpeqw_mask_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx));
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask); Ok(())
        },
      }
    }
  },

  // 0F 51: VSQRTPS (NP) / VSQRTPD (66)
  // 0F 60: VPUNPCKLBW (66, EVEX) [BW]
  96 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_punpcklbw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_punpcklbw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_punpcklbw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 61: VPUNPCKLWD (66, EVEX) [BW]
  // 0F 61: VPUNPCKLWD (66, EVEX) [BW]
  97 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_punpcklwd_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_punpcklwd_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_punpcklwd_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 62: VPUNPCKLDQ (66, EVEX) [F]
  // 0F 62: VPUNPCKLDQ (66, EVEX) [F]
  98 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_punpckldq_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_punpckldq_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_punpckldq_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 63: VPACKSSWB (66, EVEX) [BW]
  // 0F 63: VPACKSSWB (66, EVEX) [BW]
  99 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_packsswb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_packsswb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_packsswb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 67: VPACKUSWB (66, EVEX) [BW]
  // 0F 67: VPACKUSWB (66, EVEX) [BW]
  103 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_packuswb_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_packuswb_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_packuswb_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 68: VPUNPCKHBW (66, EVEX) [BW]
  // 0F 68: VPUNPCKHBW (66, EVEX) [BW]
  104 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_punpckhbw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_punpckhbw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_punpckhbw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 69: VPUNPCKHWD (66, EVEX) [BW]
  // 0F 69: VPUNPCKHWD (66, EVEX) [BW]
  105 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_punpckhwd_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_punpckhwd_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_punpckhwd_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 6A: VPUNPCKHDQ (66, EVEX) [F]
  // 0F 6A: VPUNPCKHDQ (66, EVEX) [F]
  106 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_punpckhdq_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_punpckhdq_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_punpckhdq_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 6B: VPACKSSDW (66, EVEX) [BW]
  // 0F 6B: VPACKSSDW (66, EVEX) [BW]
  107 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_packssdw_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_packssdw_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_packssdw_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 6C: VPUNPCKLQDQ (66, EVEX) [F]
  // 0F 6C: VPUNPCKLQDQ (66, EVEX) [F]
  108 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_punpcklqdq_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_punpcklqdq_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_punpcklqdq_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 6D: VPUNPCKHQDQ (66, EVEX) [F]
  // 0F 6D: VPUNPCKHQDQ (66, EVEX) [F]
  109 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_punpckhqdq_512(read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))); Ok(()) },
        1 => { write_ymm(dst, avx_punpckhqdq_256(read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))); Ok(()) },
        _ => { write_xmm(dst, avx_punpckhqdq_128(read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))); Ok(()) },
      }
    }
  },

  // 0F 70: VPSHUFD (66) / VPSHUFHW (F3) / VPSHUFLW (F2)
  // 0F 70: VPSHUFD (66) / VPSHUFHW (F3) / VPSHUFLW (F2)
  112 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let imm = fetch_byte();
    match mp {
      MP_66 => match pfx.evex_ll { // VPSHUFD
        2 => { write_zmm(dst, avx_pshufd_512(evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_pshufd_256(evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => { write_xmm(dst, avx_pshufd_128(evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
      },
      MP_F3 => match pfx.evex_ll { // VPSHUFHW
        2 => { write_zmm(dst, avx_pshufhw_512(evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_pshufhw_256(evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => { write_xmm(dst, avx_pshufhw_128(evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
      },
      MP_F2 => match pfx.evex_ll { // VPSHUFLW
        2 => { write_zmm(dst, avx_pshuflw_512(evex_src_zmm(modrm, rm, pfx), imm)); Ok(()) },
        1 => { write_ymm(dst, avx_pshuflw_256(evex_src_ymm(modrm, rm, pfx), imm)); Ok(()) },
        _ => { write_xmm(dst, avx_pshuflw_128(evex_src_xmm(modrm, rm, pfx), imm)); Ok(()) },
      },
      _ => raise_UD(),
    }
  },

  // 0F 71: Group 12 — shift word by imm8 (66, EVEX)
  // /2=VPSRLW, /4=VPSRAW, /6=VPSLLW
  // 0F 71: Group 12 — shift word by imm8 (66, EVEX)
  // /2=VPSRLW, /4=VPSRAW, /6=VPSLLW
  113 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let digit : range(0, 7) = unsigned(modrm[5..3]);
      let src = evex_rm_reg_idx(modrm, pfx);
      let dst = pfx.evex_vvvvv;
      let imm = fetch_byte();
      let count : range(0, 255) = unsigned(imm);
      match digit {
        2 => match pfx.evex_ll { // VPSRLW imm
          2 => { write_zmm(dst, avx_psrlw_imm_512(read_zmm(src), count)); Ok(()) },
          1 => { write_ymm(dst, avx_psrlw_imm_256(read_ymm(src), count)); Ok(()) },
          _ => { write_xmm(dst, avx_psrlw_imm_128(read_xmm(src), count)); Ok(()) },
        },
        4 => match pfx.evex_ll { // VPSRAW imm
          2 => { write_zmm(dst, avx_psraw_imm_512(read_zmm(src), count)); Ok(()) },
          1 => { write_ymm(dst, avx_psraw_imm_256(read_ymm(src), count)); Ok(()) },
          _ => { write_xmm(dst, avx_psraw_imm_128(read_xmm(src), count)); Ok(()) },
        },
        6 => match pfx.evex_ll { // VPSLLW imm
          2 => { write_zmm(dst, avx_psllw_imm_512(read_zmm(src), count)); Ok(()) },
          1 => { write_ymm(dst, avx_psllw_imm_256(read_ymm(src), count)); Ok(()) },
          _ => { write_xmm(dst, avx_psllw_imm_128(read_xmm(src), count)); Ok(()) },
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F 72: Group 13 — shift dword/qword by imm8 (66, EVEX)
  // /2=VPSRLD(W0)/VPSRLQ(W1), /4=VPSRAD(W0)/VPSRAQ(W1), /6=VPSLLD(W0)/VPSLLQ(W1)
  // 0F 72: Group 13 — shift dword/qword by imm8 (66, EVEX)
  // /2=VPSRLD(W0)/VPSRLQ(W1), /4=VPSRAD(W0)/VPSRAQ(W1), /6=VPSLLD(W0)/VPSLLQ(W1)
  114 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let digit : range(0, 7) = unsigned(modrm[5..3]);
      let src = evex_rm_reg_idx(modrm, pfx);
      let dst = pfx.evex_vvvvv;
      let imm = fetch_byte();
      let count : range(0, 255) = unsigned(imm);
      if pfx.rex_w then {
        // W=1: qword operations
        match digit {
          2 => match pfx.evex_ll { // VPSRLQ imm
            2 => { write_zmm(dst, avx_psrlq_imm_512(read_zmm(src), count)); Ok(()) },
            1 => { write_ymm(dst, avx_psrlq_imm_256(read_ymm(src), count)); Ok(()) },
            _ => { write_xmm(dst, avx_psrlq_imm_128(read_xmm(src), count)); Ok(()) },
          },
          4 => match pfx.evex_ll { // VPSRAQ imm
            2 => { write_zmm(dst, avx_psraq_imm_512(read_zmm(src), count)); Ok(()) },
            1 => { write_ymm(dst, avx_psraq_imm_256(read_ymm(src), count)); Ok(()) },
            _ => { write_xmm(dst, avx_psraq_imm_128(read_xmm(src), count)); Ok(()) },
          },
          6 => match pfx.evex_ll { // VPSLLQ imm
            2 => { write_zmm(dst, avx_psllq_imm_512(read_zmm(src), count)); Ok(()) },
            1 => { write_ymm(dst, avx_psllq_imm_256(read_ymm(src), count)); Ok(()) },
            _ => { write_xmm(dst, avx_psllq_imm_128(read_xmm(src), count)); Ok(()) },
          },
          _ => raise_UD(),
        }
      } else {
        // W=0: dword operations
        match digit {
          2 => match pfx.evex_ll { // VPSRLD imm
            2 => { write_zmm(dst, avx_psrld_imm_512(read_zmm(src), count)); Ok(()) },
            1 => { write_ymm(dst, avx_psrld_imm_256(read_ymm(src), count)); Ok(()) },
            _ => { write_xmm(dst, avx_psrld_imm_128(read_xmm(src), count)); Ok(()) },
          },
          4 => match pfx.evex_ll { // VPSRAD imm
            2 => { write_zmm(dst, avx_psrad_imm_512(read_zmm(src), count)); Ok(()) },
            1 => { write_ymm(dst, avx_psrad_imm_256(read_ymm(src), count)); Ok(()) },
            _ => { write_xmm(dst, avx_psrad_imm_128(read_xmm(src), count)); Ok(()) },
          },
          6 => match pfx.evex_ll { // VPSLLD imm
            2 => { write_zmm(dst, avx_pslld_imm_512(read_zmm(src), count)); Ok(()) },
            1 => { write_ymm(dst, avx_pslld_imm_256(read_ymm(src), count)); Ok(()) },
            _ => { write_xmm(dst, avx_pslld_imm_128(read_xmm(src), count)); Ok(()) },
          },
          _ => raise_UD(),
        }
      }
    }
  },

  // 0F 73: Group 14 — shift qword/dq by imm8 (66, EVEX)
  // /2=VPSRLQ(W1), /3=VPSRLDQ, /6=VPSLLQ(W1), /7=VPSLLDQ
  // 0F 73: Group 14 — shift qword/dq by imm8 (66, EVEX)
  // /2=VPSRLQ(W1), /3=VPSRLDQ, /6=VPSLLQ(W1), /7=VPSLLDQ
  115 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let digit : range(0, 7) = unsigned(modrm[5..3]);
      let src = evex_rm_reg_idx(modrm, pfx);
      let dst = pfx.evex_vvvvv;
      let imm = fetch_byte();
      let count : range(0, 255) = unsigned(imm);
      match digit {
        2 => match pfx.evex_ll { // VPSRLQ imm (W=1)
          2 => { write_zmm(dst, avx_psrlq_imm_512(read_zmm(src), count)); Ok(()) },
          1 => { write_ymm(dst, avx_psrlq_imm_256(read_ymm(src), count)); Ok(()) },
          _ => { write_xmm(dst, avx_psrlq_imm_128(read_xmm(src), count)); Ok(()) },
        },
        3 => match pfx.evex_ll { // VPSRLDQ imm
          2 => { write_zmm(dst, avx_psrldq_512(read_zmm(src), count)); Ok(()) },
          1 => { write_ymm(dst, avx_psrldq_256(read_ymm(src), count)); Ok(()) },
          _ => { write_xmm(dst, avx_psrldq_128(read_xmm(src), count)); Ok(()) },
        },
        6 => match pfx.evex_ll { // VPSLLQ imm (W=1)
          2 => { write_zmm(dst, avx_psllq_imm_512(read_zmm(src), count)); Ok(()) },
          1 => { write_ymm(dst, avx_psllq_imm_256(read_ymm(src), count)); Ok(()) },
          _ => { write_xmm(dst, avx_psllq_imm_128(read_xmm(src), count)); Ok(()) },
        },
        7 => match pfx.evex_ll { // VPSLLDQ imm
          2 => { write_zmm(dst, avx_pslldq_512(read_zmm(src), count)); Ok(()) },
          1 => { write_ymm(dst, avx_pslldq_256(read_ymm(src), count)); Ok(()) },
          _ => { write_xmm(dst, avx_pslldq_128(read_xmm(src), count)); Ok(()) },
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F C4: VPINSRW (66) — insert word from r32/m16 into XMM [BW]
  // 0F C4: VPINSRW (66) — insert word from r32/m16 into XMM [BW]
  196 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1 = read_xmm(pfx.evex_vvvvv);
      let word_val : bits(16) = match rm {
        RM_reg(_) => read_gpr32(modrm_rm_reg(modrm, pfx))[15..0],
        RM_mem(addr) => mem_read16(fixup_addr(addr)),
      };
      let imm = fetch_byte();
      let sel : range(0, 7) = unsigned(imm[2..0]);
      var result = src1;
      let lo : range(0, 112) = sel * 16;
      result[(lo + 15)..lo] = word_val;
      write_xmm(dst, result);
      Ok(())
    }
  },

  // 0F C5: VPEXTRW (66) — extract word from XMM to r32 [BW]
  // 0F C5: VPEXTRW (66) — extract word from XMM to r32 [BW]
  197 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src_xmm = read_xmm(evex_rm_reg_idx(modrm, pfx));
      let dst_gpr = modrm_reg(modrm, pfx);
      let imm = fetch_byte();
      let sel : range(0, 7) = unsigned(imm[2..0]);
      let lo : range(0, 112) = sel * 16;
      let word_val : bits(16) = src_xmm[(lo + 15)..lo];
      write_gpr(dst_gpr, OS64, zero_extend(word_val));
      Ok(())
    }
  },

  // 0F C2: VCMPPS (NP,W0) / VCMPPD (66,W1) / VCMPSS (F3) / VCMPSD (F2) → kmask
  // 0F D6: VMOVQ store (66,W1) — store low qword of XMM to XMM/m64
  214 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let src_xmm = read_xmm(evex_reg_idx(modrm, pfx));
      let rm = decode_rm_evex(modrm, pfx, 8);
      let qval : qword = src_xmm[63..0];
      match rm {
        RM_reg(_) => {
          let dst = evex_rm_reg_idx(modrm, pfx);
          write_xmm(dst, zero_extend(qval))
        },
        RM_mem(addr) => mem_write64(fixup_addr(addr), qval),
      };
      Ok(())
    }
  },

  // 0F E6: VCVTDQ2PD (F3,W0) / VCVTPD2DQ (F2,W1) / VCVTTPD2DQ (66,W1) / VCVTQQ2PD (F3,W1)
  // 0F D1: VPSRLW by xmm (66, EVEX) [BW]
  209 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let count_xmm : xmmword = evex_src_xmm(modrm, rm, pfx);
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psrlw_xmm_512(read_zmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        1 => { write_ymm(dst, avx_psrlw_xmm_256(read_ymm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        _ => { write_xmm(dst, avx_psrlw_xmm_128(read_xmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
      }
    }
  },

  // 0F D2: VPSRLD by xmm (66, EVEX) [F]
  // 0F D2: VPSRLD by xmm (66, EVEX) [F]
  210 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let count_xmm : xmmword = evex_src_xmm(modrm, rm, pfx);
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psrld_xmm_512(read_zmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        1 => { write_ymm(dst, avx_psrld_xmm_256(read_ymm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        _ => { write_xmm(dst, avx_psrld_xmm_128(read_xmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
      }
    }
  },

  // 0F D3: VPSRLQ by xmm (66, EVEX) [F]
  // 0F D3: VPSRLQ by xmm (66, EVEX) [F]
  211 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let count_xmm : xmmword = evex_src_xmm(modrm, rm, pfx);
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psrlq_xmm_512(read_zmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        1 => { write_ymm(dst, avx_psrlq_xmm_256(read_ymm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        _ => { write_xmm(dst, avx_psrlq_xmm_128(read_xmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
      }
    }
  },

  // 0F E1: VPSRAW by xmm (66, EVEX) [BW]
  // 0F E1: VPSRAW by xmm (66, EVEX) [BW]
  225 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let count_xmm : xmmword = evex_src_xmm(modrm, rm, pfx);
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psraw_xmm_512(read_zmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        1 => { write_ymm(dst, avx_psraw_xmm_256(read_ymm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        _ => { write_xmm(dst, avx_psraw_xmm_128(read_xmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
      }
    }
  },

  // 0F E2: VPSRAD (66,W0) / VPSRAQ (66,W1) by xmm (EVEX)
  // 0F E2: VPSRAD (66,W0) / VPSRAQ (66,W1) by xmm (EVEX)
  226 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let count_xmm : xmmword = evex_src_xmm(modrm, rm, pfx);
      if pfx.rex_w then {
        // VPSRAQ
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_psraq_xmm_512(read_zmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
          1 => { write_ymm(dst, avx_psraq_xmm_256(read_ymm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
          _ => { write_xmm(dst, avx_psraq_xmm_128(read_xmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        }
      } else {
        // VPSRAD
        match pfx.evex_ll {
          2 => { write_zmm(dst, avx_psrad_xmm_512(read_zmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
          1 => { write_ymm(dst, avx_psrad_xmm_256(read_ymm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
          _ => { write_xmm(dst, avx_psrad_xmm_128(read_xmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        }
      }
    }
  },

  // 0F F1: VPSLLW by xmm (66, EVEX) [BW]
  // 0F F1: VPSLLW by xmm (66, EVEX) [BW]
  241 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let count_xmm : xmmword = evex_src_xmm(modrm, rm, pfx);
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psllw_xmm_512(read_zmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        1 => { write_ymm(dst, avx_psllw_xmm_256(read_ymm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        _ => { write_xmm(dst, avx_psllw_xmm_128(read_xmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
      }
    }
  },

  // 0F F2: VPSLLD by xmm (66, EVEX) [F]
  // 0F F2: VPSLLD by xmm (66, EVEX) [F]
  242 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let count_xmm : xmmword = evex_src_xmm(modrm, rm, pfx);
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_pslld_xmm_512(read_zmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        1 => { write_ymm(dst, avx_pslld_xmm_256(read_ymm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        _ => { write_xmm(dst, avx_pslld_xmm_128(read_xmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
      }
    }
  },

  // 0F F3: VPSLLQ by xmm (66, EVEX) [F]
  // 0F F3: VPSLLQ by xmm (66, EVEX) [F]
  243 => {
    if mp != MP_66 then raise_UD()
    else {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, 16);
      let count_xmm : xmmword = evex_src_xmm(modrm, rm, pfx);
      match pfx.evex_ll {
        2 => { write_zmm(dst, avx_psllq_xmm_512(read_zmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        1 => { write_ymm(dst, avx_psllq_xmm_256(read_ymm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
        _ => { write_xmm(dst, avx_psllq_xmm_128(read_xmm(pfx.evex_vvvvv), count_xmm)); Ok(()) },
      }
    }
  },

  _ => raise_UD(),
  }
}

// x86-64 — EVEX Arithmetic/Misc (0F38 map)
//
// Integer min/max/abs, multiply, variable shifts, narrowing/widening
// converts, VNNI, test-mask, and bit manipulation.
// Called from dispatch_evex_0f38 in insn_evex.sail.

val avx_pminud_512 : (zmmword, zmmword) -> zmmword
function avx_pminud_512(a, b) =
  avx_pminud_256(a[511..256], b[511..256]) @
  avx_pminud_256(a[255..0], b[255..0])

// =========================================================================
// AVX-512 VPCMPEQB — compare bytes for equal, produce kmask
// Each byte lane: if a[i] == b[i] then mask bit = 1, else 0
// =========================================================================

val avx_ptestmb_128 : (xmmword, xmmword) -> word
function avx_ptestmb_128(a, b) =
  or_reduce_8(a[127..120] & b[127..120]) @
  or_reduce_8(a[119..112] & b[119..112]) @
  or_reduce_8(a[111..104] & b[111..104]) @
  or_reduce_8(a[103..96]  & b[103..96]) @
  or_reduce_8(a[95..88]   & b[95..88]) @
  or_reduce_8(a[87..80]   & b[87..80]) @
  or_reduce_8(a[79..72]   & b[79..72]) @
  or_reduce_8(a[71..64]   & b[71..64]) @
  or_reduce_8(a[63..56]   & b[63..56]) @
  or_reduce_8(a[55..48]   & b[55..48]) @
  or_reduce_8(a[47..40]   & b[47..40]) @
  or_reduce_8(a[39..32]   & b[39..32]) @
  or_reduce_8(a[31..24]   & b[31..24]) @
  or_reduce_8(a[23..16]   & b[23..16]) @
  or_reduce_8(a[15..8]    & b[15..8]) @
  or_reduce_8(a[7..0]     & b[7..0])

val avx_ptestnmb_128 : (xmmword, xmmword) -> word
function avx_ptestnmb_128(a, b) =
  (~(or_reduce_8(a[127..120] & b[127..120]))) @
  (~(or_reduce_8(a[119..112] & b[119..112]))) @
  (~(or_reduce_8(a[111..104] & b[111..104]))) @
  (~(or_reduce_8(a[103..96]  & b[103..96]))) @
  (~(or_reduce_8(a[95..88]   & b[95..88]))) @
  (~(or_reduce_8(a[87..80]   & b[87..80]))) @
  (~(or_reduce_8(a[79..72]   & b[79..72]))) @
  (~(or_reduce_8(a[71..64]   & b[71..64]))) @
  (~(or_reduce_8(a[63..56]   & b[63..56]))) @
  (~(or_reduce_8(a[55..48]   & b[55..48]))) @
  (~(or_reduce_8(a[47..40]   & b[47..40]))) @
  (~(or_reduce_8(a[39..32]   & b[39..32]))) @
  (~(or_reduce_8(a[31..24]   & b[31..24]))) @
  (~(or_reduce_8(a[23..16]   & b[23..16]))) @
  (~(or_reduce_8(a[15..8]    & b[15..8]))) @
  (~(or_reduce_8(a[7..0]     & b[7..0])))

val avx_ptestmb_256 : (ymmword, ymmword) -> dword
function avx_ptestmb_256(a, b) =
  avx_ptestmb_128(a[255..128], b[255..128]) @
  avx_ptestmb_128(a[127..0], b[127..0])

val avx_ptestnmb_256 : (ymmword, ymmword) -> dword
function avx_ptestnmb_256(a, b) =
  avx_ptestnmb_128(a[255..128], b[255..128]) @
  avx_ptestnmb_128(a[127..0], b[127..0])

val avx_ptestmb_512 : (zmmword, zmmword) -> qword
function avx_ptestmb_512(a, b) =
  avx_ptestmb_256(a[511..256], b[511..256]) @
  avx_ptestmb_256(a[255..0], b[255..0])

val avx_ptestnmb_512 : (zmmword, zmmword) -> qword
function avx_ptestnmb_512(a, b) =
  avx_ptestnmb_256(a[511..256], b[511..256]) @
  avx_ptestnmb_256(a[255..0], b[255..0])

// =========================================================================
// VPTESTMD/VPTESTNMD: dword version
// =========================================================================

val avx_ptestmd_128 : (xmmword, xmmword) -> byte
function avx_ptestmd_128(a, b) =
  0x0 @
  or_reduce_32(a[127..96] & b[127..96]) @
  or_reduce_32(a[95..64]  & b[95..64]) @
  or_reduce_32(a[63..32]  & b[63..32]) @
  or_reduce_32(a[31..0]   & b[31..0])

val avx_ptestnmd_128 : (xmmword, xmmword) -> byte
function avx_ptestnmd_128(a, b) =
  0x0 @
  (~(or_reduce_32(a[127..96] & b[127..96]))) @
  (~(or_reduce_32(a[95..64]  & b[95..64]))) @
  (~(or_reduce_32(a[63..32]  & b[63..32]))) @
  (~(or_reduce_32(a[31..0]   & b[31..0])))

val avx_ptestmd_256 : (ymmword, ymmword) -> byte
function avx_ptestmd_256(a, b) =
  avx_ptestmd_128(a[255..128], b[255..128])[3..0] @
  avx_ptestmd_128(a[127..0], b[127..0])[3..0]

val avx_ptestnmd_256 : (ymmword, ymmword) -> byte
function avx_ptestnmd_256(a, b) =
  avx_ptestnmd_128(a[255..128], b[255..128])[3..0] @
  avx_ptestnmd_128(a[127..0], b[127..0])[3..0]

val avx_ptestmd_512 : (zmmword, zmmword) -> word
function avx_ptestmd_512(a, b) =
  avx_ptestmd_256(a[511..256], b[511..256]) @
  avx_ptestmd_256(a[255..0], b[255..0])

val avx_ptestnmd_512 : (zmmword, zmmword) -> word
function avx_ptestnmd_512(a, b) =
  avx_ptestnmd_256(a[511..256], b[511..256]) @
  avx_ptestnmd_256(a[255..0], b[255..0])

// =========================================================================
// VPTESTMW/VPTESTNMW: word version
// =========================================================================

val avx_ptestmw_128 : (xmmword, xmmword) -> byte
function avx_ptestmw_128(a, b) =
  or_reduce_16(a[127..112] & b[127..112]) @
  or_reduce_16(a[111..96]  & b[111..96]) @
  or_reduce_16(a[95..80]   & b[95..80]) @
  or_reduce_16(a[79..64]   & b[79..64]) @
  or_reduce_16(a[63..48]   & b[63..48]) @
  or_reduce_16(a[47..32]   & b[47..32]) @
  or_reduce_16(a[31..16]   & b[31..16]) @
  or_reduce_16(a[15..0]    & b[15..0])

val avx_ptestnmw_128 : (xmmword, xmmword) -> byte
function avx_ptestnmw_128(a, b) =
  (~(or_reduce_16(a[127..112] & b[127..112]))) @
  (~(or_reduce_16(a[111..96]  & b[111..96]))) @
  (~(or_reduce_16(a[95..80]   & b[95..80]))) @
  (~(or_reduce_16(a[79..64]   & b[79..64]))) @
  (~(or_reduce_16(a[63..48]   & b[63..48]))) @
  (~(or_reduce_16(a[47..32]   & b[47..32]))) @
  (~(or_reduce_16(a[31..16]   & b[31..16]))) @
  (~(or_reduce_16(a[15..0]    & b[15..0])))

val avx_ptestmw_256 : (ymmword, ymmword) -> word
function avx_ptestmw_256(a, b) =
  avx_ptestmw_128(a[255..128], b[255..128]) @
  avx_ptestmw_128(a[127..0], b[127..0])

val avx_ptestnmw_256 : (ymmword, ymmword) -> word
function avx_ptestnmw_256(a, b) =
  avx_ptestnmw_128(a[255..128], b[255..128]) @
  avx_ptestnmw_128(a[127..0], b[127..0])

val avx_ptestmw_512 : (zmmword, zmmword) -> dword
function avx_ptestmw_512(a, b) =
  avx_ptestmw_256(a[511..256], b[511..256]) @
  avx_ptestmw_256(a[255..0], b[255..0])

val avx_ptestnmw_512 : (zmmword, zmmword) -> dword
function avx_ptestnmw_512(a, b) =
  avx_ptestnmw_256(a[511..256], b[511..256]) @
  avx_ptestnmw_256(a[255..0], b[255..0])

// =========================================================================
// VPTESTMQ/VPTESTNMQ: qword version
// =========================================================================

val avx_ptestmq_128 : (xmmword, xmmword) -> byte
function avx_ptestmq_128(a, b) =
  0b000000 @
  or_reduce_64(a[127..64] & b[127..64]) @
  or_reduce_64(a[63..0]   & b[63..0])

val avx_ptestnmq_128 : (xmmword, xmmword) -> byte
function avx_ptestnmq_128(a, b) =
  0b000000 @
  (~(or_reduce_64(a[127..64] & b[127..64]))) @
  (~(or_reduce_64(a[63..0]   & b[63..0])))

val avx_ptestmq_256 : (ymmword, ymmword) -> byte
function avx_ptestmq_256(a, b) =
  0x0 @
  avx_ptestmq_128(a[255..128], b[255..128])[1..0] @
  avx_ptestmq_128(a[127..0], b[127..0])[1..0]

val avx_ptestnmq_256 : (ymmword, ymmword) -> byte
function avx_ptestnmq_256(a, b) =
  0x0 @
  avx_ptestnmq_128(a[255..128], b[255..128])[1..0] @
  avx_ptestnmq_128(a[127..0], b[127..0])[1..0]

val avx_ptestmq_512 : (zmmword, zmmword) -> byte
function avx_ptestmq_512(a, b) =
  avx_ptestmq_128(a[511..384], b[511..384])[1..0] @
  avx_ptestmq_128(a[383..256], b[383..256])[1..0] @
  avx_ptestmq_128(a[255..128], b[255..128])[1..0] @
  avx_ptestmq_128(a[127..0], b[127..0])[1..0]

val avx_ptestnmq_512 : (zmmword, zmmword) -> byte
function avx_ptestnmq_512(a, b) =
  avx_ptestnmq_128(a[511..384], b[511..384])[1..0] @
  avx_ptestnmq_128(a[383..256], b[383..256])[1..0] @
  avx_ptestnmq_128(a[255..128], b[255..128])[1..0] @
  avx_ptestnmq_128(a[127..0], b[127..0])[1..0]

// =========================================================================
// VPCMPUB: compare unsigned bytes with imm8 predicate, produce kmask
// imm8: 0=eq, 1=lt, 2=le, 4=neq, 5=nlt(>=), 6=nle(>)
// =========================================================================

val avx_pmaddubsw_128 : (xmmword, xmmword) -> xmmword
function avx_pmaddubsw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let b0 : range(0, 112) = i * 16;
    let b1 : range(0, 120) = i * 16 + 8;
    let prod0 : int = unsigned(a[(b0 + 7)..b0]) * signed(b[(b0 + 7)..b0]);
    let prod1 : int = unsigned(a[(b1 + 7)..b1]) * signed(b[(b1 + 7)..b1]);
    let sum : int = prod0 + prod1;
    // Saturate to signed 16-bit
    let sat : int = if sum > 32767 then 32767 else if sum < -32768 then -32768 else sum;
    r[(lo + 15)..lo] = to_bits_truncate(sat);
  };
  r
}

val avx_pmaddubsw_256 : (ymmword, ymmword) -> ymmword
function avx_pmaddubsw_256(a, b) =
  avx_pmaddubsw_128(a[255..128], b[255..128]) @ avx_pmaddubsw_128(a[127..0], b[127..0])

val avx_pmaddubsw_512 : (zmmword, zmmword) -> zmmword
function avx_pmaddubsw_512(a, b) =
  avx_pmaddubsw_256(a[511..256], b[511..256]) @ avx_pmaddubsw_256(a[255..0], b[255..0])

// VPMULHRSW: packed multiply high with round and scale (signed words)
// Result = (((a[i] * b[i]) >> 14) + 1) >> 1, truncated to 16 bits

val avx_pmulhrsw_128 : (xmmword, xmmword) -> xmmword
function avx_pmulhrsw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    // Compute in 32-bit signed bitvectors to avoid Sail integer division issues
    let av : bits(32) = sign_extend(a[(lo + 15)..lo]);
    let bv : bits(32) = sign_extend(b[(lo + 15)..lo]);
    let prod : bits(32) = to_bits_truncate(signed(av) * signed(bv));
    // Arithmetic right shift by 14, add 1, arithmetic right shift by 1
    let shifted14 : bits(32) = sail_arith_shiftright(prod, 14);
    let plus1 : bits(32) = to_bits_truncate(signed(shifted14) + 1);
    let result : bits(32) = sail_arith_shiftright(plus1, 1);
    r[(lo + 15)..lo] = result[15..0];
  };
  r
}

val avx_pmulhrsw_256 : (ymmword, ymmword) -> ymmword
function avx_pmulhrsw_256(a, b) =
  avx_pmulhrsw_128(a[255..128], b[255..128]) @ avx_pmulhrsw_128(a[127..0], b[127..0])

val avx_pmulhrsw_512 : (zmmword, zmmword) -> zmmword
function avx_pmulhrsw_512(a, b) =
  avx_pmulhrsw_256(a[511..256], b[511..256]) @ avx_pmulhrsw_256(a[255..0], b[255..0])

// VPMULDQ: multiply packed signed dwords → packed signed qwords (even dwords only)

val avx_pmuldq_512 : (zmmword, zmmword) -> zmmword
function avx_pmuldq_512(a, b) =
  avx_pmuldq_256(a[511..256], b[511..256]) @ avx_pmuldq_256(a[255..0], b[255..0])

// VPMULLD: multiply packed dwords, low 32-bit result

val avx_pmulld_512 : (zmmword, zmmword) -> zmmword
function avx_pmulld_512(a, b) =
  avx_pmulld_256(a[511..256], b[511..256]) @ avx_pmulld_256(a[255..0], b[255..0])

// VPMULLQ: multiply packed qwords, low 64-bit result

val avx_pmullq_128 : (xmmword, xmmword) -> xmmword
function avx_pmullq_128(a, b) = {
  let lo_prod : bits(64) = to_bits_truncate(signed(a[63..0]) * signed(b[63..0]));
  let hi_prod : bits(64) = to_bits_truncate(signed(a[127..64]) * signed(b[127..64]));
  hi_prod @ lo_prod
}

val avx_pmullq_256 : (ymmword, ymmword) -> ymmword
function avx_pmullq_256(a, b) =
  avx_pmullq_128(a[255..128], b[255..128]) @ avx_pmullq_128(a[127..0], b[127..0])

val avx_pmullq_512 : (zmmword, zmmword) -> zmmword
function avx_pmullq_512(a, b) =
  avx_pmullq_256(a[511..256], b[511..256]) @ avx_pmullq_256(a[255..0], b[255..0])

// VPERMILPS (register control): per-element select within 128-bit lane

val avx_pmovsxbw_512 : ymmword -> zmmword
function avx_pmovsxbw_512(src) = avx_pmovsxbw_256(src[255..128]) @ avx_pmovsxbw_256(src[127..0])

// VPMOVSXBD: Sign-extend packed bytes to dwords

val avx_pmovsxbd_512 : xmmword -> zmmword
function avx_pmovsxbd_512(src) = avx_pmovsxbd_256(src[127..64]) @ avx_pmovsxbd_256(src[63..0])

// VPMOVSXBQ: Sign-extend packed bytes to qwords

val avx_pmovsxbq_512 : qword -> zmmword
function avx_pmovsxbq_512(src) = avx_pmovsxbq_256(src[63..32]) @ avx_pmovsxbq_256(src[31..0])

// VPMOVSXWD: Sign-extend packed words to dwords

val avx_pmovsxwd_512 : ymmword -> zmmword
function avx_pmovsxwd_512(src) = avx_pmovsxwd_256(src[255..128]) @ avx_pmovsxwd_256(src[127..0])

// VPMOVSXWQ: Sign-extend packed words to qwords

val avx_pmovsxwq_512 : xmmword -> zmmword
function avx_pmovsxwq_512(src) = avx_pmovsxwq_256(src[127..64]) @ avx_pmovsxwq_256(src[63..0])

// VPMOVSXDQ: Sign-extend packed dwords to qwords

val avx_pmovsxdq_512 : ymmword -> zmmword
function avx_pmovsxdq_512(src) = avx_pmovsxdq_256(src[255..128]) @ avx_pmovsxdq_256(src[127..0])

// =========================================================================
// VPMOVZXBW: Zero-extend packed bytes to words
// =========================================================================

val avx_pmovzxbw_512 : ymmword -> zmmword
function avx_pmovzxbw_512(src) = avx_pmovzxbw_256(src[255..128]) @ avx_pmovzxbw_256(src[127..0])

// VPMOVZXBD: Zero-extend packed bytes to dwords

val avx_pmovzxbd_512 : xmmword -> zmmword
function avx_pmovzxbd_512(src) = avx_pmovzxbd_256(src[127..64]) @ avx_pmovzxbd_256(src[63..0])

// VPMOVZXBQ: Zero-extend packed bytes to qwords

val avx_pmovzxbq_512 : qword -> zmmword
function avx_pmovzxbq_512(src) = avx_pmovzxbq_256(src[63..32]) @ avx_pmovzxbq_256(src[31..0])

// VPMOVZXWD: Zero-extend packed words to dwords

val avx_pmovzxwd_512 : ymmword -> zmmword
function avx_pmovzxwd_512(src) = avx_pmovzxwd_256(src[255..128]) @ avx_pmovzxwd_256(src[127..0])

// VPMOVZXWQ: Zero-extend packed words to qwords

val avx_pmovzxwq_512 : xmmword -> zmmword
function avx_pmovzxwq_512(src) = avx_pmovzxwq_256(src[127..64]) @ avx_pmovzxwq_256(src[63..0])

// VPMOVZXDQ: Zero-extend packed dwords to qwords

val avx_pmovzxdq_512 : ymmword -> zmmword
function avx_pmovzxdq_512(src) = avx_pmovzxdq_256(src[255..128]) @ avx_pmovzxdq_256(src[127..0])

// =========================================================================
// Variable-count shifts: VPSRLVD/Q, VPSRAVD/Q, VPSLLVD/Q
// Each element is shifted by a different count from the count vector
// =========================================================================

// VPSRLVD: variable logical right shift dwords

val avx_psrlvd_128 : (xmmword, xmmword) -> xmmword
function avx_psrlvd_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let c : bits(32) = cnt[(lo + 31)..lo];
    if unsigned(c) >= 32 then r[(lo + 31)..lo] = zeros()
    else r[(lo + 31)..lo] = shift_bits_right(src[(lo + 31)..lo], c);
  };
  r
}

val avx_psrlvd_256 : (ymmword, ymmword) -> ymmword
function avx_psrlvd_256(a, b) =
  avx_psrlvd_128(a[255..128], b[255..128]) @ avx_psrlvd_128(a[127..0], b[127..0])

val avx_psrlvd_512 : (zmmword, zmmword) -> zmmword
function avx_psrlvd_512(a, b) =
  avx_psrlvd_256(a[511..256], b[511..256]) @ avx_psrlvd_256(a[255..0], b[255..0])

// VPSRLVQ: variable logical right shift qwords

val avx_psrlvq_128 : (xmmword, xmmword) -> xmmword
function avx_psrlvq_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let c : bits(64) = cnt[(lo + 63)..lo];
    if unsigned(c) >= 64 then r[(lo + 63)..lo] = zeros()
    else r[(lo + 63)..lo] = shift_bits_right(src[(lo + 63)..lo], c);
  };
  r
}

val avx_psrlvq_256 : (ymmword, ymmword) -> ymmword
function avx_psrlvq_256(a, b) =
  avx_psrlvq_128(a[255..128], b[255..128]) @ avx_psrlvq_128(a[127..0], b[127..0])

val avx_psrlvq_512 : (zmmword, zmmword) -> zmmword
function avx_psrlvq_512(a, b) =
  avx_psrlvq_256(a[511..256], b[511..256]) @ avx_psrlvq_256(a[255..0], b[255..0])

// VPSRAVD: variable arithmetic right shift dwords

val avx_psravd_128 : (xmmword, xmmword) -> xmmword
function avx_psravd_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let c : range(0, 4294967295) = unsigned(cnt[(lo + 31)..lo]);
    let elem : bits(32) = src[(lo + 31)..lo];
    if c >= 32 then {
      if elem[31] == bitone then r[(lo + 31)..lo] = ones()
      else r[(lo + 31)..lo] = zeros()
    } else {
      let shift_amt : range(0, 31) = c;
      r[(lo + 31)..lo] = sail_arith_shiftright(elem, shift_amt);
    }
  };
  r
}

val avx_psravd_256 : (ymmword, ymmword) -> ymmword
function avx_psravd_256(a, b) =
  avx_psravd_128(a[255..128], b[255..128]) @ avx_psravd_128(a[127..0], b[127..0])

val avx_psravd_512 : (zmmword, zmmword) -> zmmword
function avx_psravd_512(a, b) =
  avx_psravd_256(a[511..256], b[511..256]) @ avx_psravd_256(a[255..0], b[255..0])

// VPSRAVQ: variable arithmetic right shift qwords

val avx_psravq_128 : (xmmword, xmmword) -> xmmword
function avx_psravq_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let c = unsigned(cnt[(lo + 63)..lo]);
    let elem : bits(64) = src[(lo + 63)..lo];
    if c >= 64 then {
      if elem[63] == bitone then r[(lo + 63)..lo] = ones()
      else r[(lo + 63)..lo] = zeros()
    } else {
      let shift_amt : range(0, 63) = c;
      r[(lo + 63)..lo] = sail_arith_shiftright(elem, shift_amt);
    }
  };
  r
}

val avx_psravq_256 : (ymmword, ymmword) -> ymmword
function avx_psravq_256(a, b) =
  avx_psravq_128(a[255..128], b[255..128]) @ avx_psravq_128(a[127..0], b[127..0])

val avx_psravq_512 : (zmmword, zmmword) -> zmmword
function avx_psravq_512(a, b) =
  avx_psravq_256(a[511..256], b[511..256]) @ avx_psravq_256(a[255..0], b[255..0])

// VPSLLVD: variable logical left shift dwords

val avx_psllvd_128 : (xmmword, xmmword) -> xmmword
function avx_psllvd_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let c : bits(32) = cnt[(lo + 31)..lo];
    if unsigned(c) >= 32 then r[(lo + 31)..lo] = zeros()
    else r[(lo + 31)..lo] = shift_bits_left(src[(lo + 31)..lo], c);
  };
  r
}

val avx_psllvd_256 : (ymmword, ymmword) -> ymmword
function avx_psllvd_256(a, b) =
  avx_psllvd_128(a[255..128], b[255..128]) @ avx_psllvd_128(a[127..0], b[127..0])

val avx_psllvd_512 : (zmmword, zmmword) -> zmmword
function avx_psllvd_512(a, b) =
  avx_psllvd_256(a[511..256], b[511..256]) @ avx_psllvd_256(a[255..0], b[255..0])

// VPSLLVQ: variable logical left shift qwords

val avx_psllvq_128 : (xmmword, xmmword) -> xmmword
function avx_psllvq_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let c : bits(64) = cnt[(lo + 63)..lo];
    if unsigned(c) >= 64 then r[(lo + 63)..lo] = zeros()
    else r[(lo + 63)..lo] = shift_bits_left(src[(lo + 63)..lo], c);
  };
  r
}

val avx_psllvq_256 : (ymmword, ymmword) -> ymmword
function avx_psllvq_256(a, b) =
  avx_psllvq_128(a[255..128], b[255..128]) @ avx_psllvq_128(a[127..0], b[127..0])

val avx_psllvq_512 : (zmmword, zmmword) -> zmmword
function avx_psllvq_512(a, b) =
  avx_psllvq_256(a[511..256], b[511..256]) @ avx_psllvq_256(a[255..0], b[255..0])

// VPSRLVW: variable logical right shift words

val avx_psrlvw_128 : (xmmword, xmmword) -> xmmword
function avx_psrlvw_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let c : bits(16) = cnt[(lo + 15)..lo];
    if unsigned(c) >= 16 then r[(lo + 15)..lo] = zeros()
    else r[(lo + 15)..lo] = shift_bits_right(src[(lo + 15)..lo], c);
  };
  r
}

val avx_psrlvw_256 : (ymmword, ymmword) -> ymmword
function avx_psrlvw_256(a, b) =
  avx_psrlvw_128(a[255..128], b[255..128]) @ avx_psrlvw_128(a[127..0], b[127..0])

val avx_psrlvw_512 : (zmmword, zmmword) -> zmmword
function avx_psrlvw_512(a, b) =
  avx_psrlvw_256(a[511..256], b[511..256]) @ avx_psrlvw_256(a[255..0], b[255..0])

// VPSRAVW: variable arithmetic right shift words

val avx_psravw_128 : (xmmword, xmmword) -> xmmword
function avx_psravw_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let c : range(0, 65535) = unsigned(cnt[(lo + 15)..lo]);
    let elem : bits(16) = src[(lo + 15)..lo];
    if c >= 16 then {
      if elem[15] == bitone then r[(lo + 15)..lo] = ones()
      else r[(lo + 15)..lo] = zeros()
    } else {
      let shift_amt : range(0, 15) = c;
      r[(lo + 15)..lo] = sail_arith_shiftright(elem, shift_amt);
    }
  };
  r
}

val avx_psravw_256 : (ymmword, ymmword) -> ymmword
function avx_psravw_256(a, b) =
  avx_psravw_128(a[255..128], b[255..128]) @ avx_psravw_128(a[127..0], b[127..0])

val avx_psravw_512 : (zmmword, zmmword) -> zmmword
function avx_psravw_512(a, b) =
  avx_psravw_256(a[511..256], b[511..256]) @ avx_psravw_256(a[255..0], b[255..0])

// VPSLLVW: variable logical left shift words

val avx_psllvw_128 : (xmmword, xmmword) -> xmmword
function avx_psllvw_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let c : bits(16) = cnt[(lo + 15)..lo];
    if unsigned(c) >= 16 then r[(lo + 15)..lo] = zeros()
    else r[(lo + 15)..lo] = shift_bits_left(src[(lo + 15)..lo], c);
  };
  r
}

val avx_psllvw_256 : (ymmword, ymmword) -> ymmword
function avx_psllvw_256(a, b) =
  avx_psllvw_128(a[255..128], b[255..128]) @ avx_psllvw_128(a[127..0], b[127..0])

val avx_psllvw_512 : (zmmword, zmmword) -> zmmword
function avx_psllvw_512(a, b) =
  avx_psllvw_256(a[511..256], b[511..256]) @ avx_psllvw_256(a[255..0], b[255..0])

// VPRORVD: variable rotate right dwords

val avx_prorvd_128 : (xmmword, xmmword) -> xmmword
function avx_prorvd_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let c : range(0, 31) = unsigned(cnt[(lo + 4)..lo]);
    let elem : bits(32) = src[(lo + 31)..lo];
    if c == 0 then {
      r[(lo + 31)..lo] = elem
    } else {
      let rc : range(1, 31) = 32 - c;
      r[(lo + 31)..lo] = shift_bits_right(elem, cnt[(lo + 4)..lo]) | shift_bits_left(elem, to_bits(5, rc));
    }
  };
  r
}

val avx_prorvd_256 : (ymmword, ymmword) -> ymmword
function avx_prorvd_256(a, b) =
  avx_prorvd_128(a[255..128], b[255..128]) @ avx_prorvd_128(a[127..0], b[127..0])

val avx_prorvd_512 : (zmmword, zmmword) -> zmmword
function avx_prorvd_512(a, b) =
  avx_prorvd_256(a[511..256], b[511..256]) @ avx_prorvd_256(a[255..0], b[255..0])

// VPRORVQ: variable rotate right qwords

val avx_prorvq_128 : (xmmword, xmmword) -> xmmword
function avx_prorvq_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let c : range(0, 63) = unsigned(cnt[(lo + 5)..lo]);
    let elem : bits(64) = src[(lo + 63)..lo];
    if c == 0 then {
      r[(lo + 63)..lo] = elem
    } else {
      let rc : range(1, 63) = 64 - c;
      r[(lo + 63)..lo] = shift_bits_right(elem, cnt[(lo + 5)..lo]) | shift_bits_left(elem, to_bits(6, rc));
    }
  };
  r
}

val avx_prorvq_256 : (ymmword, ymmword) -> ymmword
function avx_prorvq_256(a, b) =
  avx_prorvq_128(a[255..128], b[255..128]) @ avx_prorvq_128(a[127..0], b[127..0])

val avx_prorvq_512 : (zmmword, zmmword) -> zmmword
function avx_prorvq_512(a, b) =
  avx_prorvq_256(a[511..256], b[511..256]) @ avx_prorvq_256(a[255..0], b[255..0])

// VPROLVD: variable rotate left dwords

val avx_prolvd_128 : (xmmword, xmmword) -> xmmword
function avx_prolvd_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    let c : range(0, 31) = unsigned(cnt[(lo + 4)..lo]);
    let elem : bits(32) = src[(lo + 31)..lo];
    if c == 0 then {
      r[(lo + 31)..lo] = elem
    } else {
      let rc : range(1, 31) = 32 - c;
      r[(lo + 31)..lo] = shift_bits_left(elem, cnt[(lo + 4)..lo]) | shift_bits_right(elem, to_bits(5, rc));
    }
  };
  r
}

val avx_prolvd_256 : (ymmword, ymmword) -> ymmword
function avx_prolvd_256(a, b) =
  avx_prolvd_128(a[255..128], b[255..128]) @ avx_prolvd_128(a[127..0], b[127..0])

val avx_prolvd_512 : (zmmword, zmmword) -> zmmword
function avx_prolvd_512(a, b) =
  avx_prolvd_256(a[511..256], b[511..256]) @ avx_prolvd_256(a[255..0], b[255..0])

// VPROLVQ: variable rotate left qwords

val avx_prolvq_128 : (xmmword, xmmword) -> xmmword
function avx_prolvq_128(src, cnt) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let c : range(0, 63) = unsigned(cnt[(lo + 5)..lo]);
    let elem : bits(64) = src[(lo + 63)..lo];
    if c == 0 then {
      r[(lo + 63)..lo] = elem
    } else {
      let rc : range(1, 63) = 64 - c;
      r[(lo + 63)..lo] = shift_bits_left(elem, cnt[(lo + 5)..lo]) | shift_bits_right(elem, to_bits(6, rc));
    }
  };
  r
}

val avx_prolvq_256 : (ymmword, ymmword) -> ymmword
function avx_prolvq_256(a, b) =
  avx_prolvq_128(a[255..128], b[255..128]) @ avx_prolvq_128(a[127..0], b[127..0])

val avx_prolvq_512 : (zmmword, zmmword) -> zmmword
function avx_prolvq_512(a, b) =
  avx_prolvq_256(a[511..256], b[511..256]) @ avx_prolvq_256(a[255..0], b[255..0])

// =========================================================================
// VPABSB: absolute value of packed signed bytes
// =========================================================================

val avx_pabsb_128 : (xmmword) -> xmmword
function avx_pabsb_128(a) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    r[(lo + 7)..lo] = abs8(a[(lo + 7)..lo]);
  };
  r
}

val avx_pabsb_256 : (ymmword) -> ymmword
function avx_pabsb_256(a) =
  avx_pabsb_128(a[255..128]) @ avx_pabsb_128(a[127..0])

val avx_pabsb_512 : (zmmword) -> zmmword
function avx_pabsb_512(a) =
  avx_pabsb_256(a[511..256]) @ avx_pabsb_256(a[255..0])

// =========================================================================
// VPABSW: absolute value of packed signed words
// =========================================================================

val avx_pabsw_128 : (xmmword) -> xmmword
function avx_pabsw_128(a) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = abs16(a[(lo + 15)..lo]);
  };
  r
}

val avx_pabsw_256 : (ymmword) -> ymmword
function avx_pabsw_256(a) =
  avx_pabsw_128(a[255..128]) @ avx_pabsw_128(a[127..0])

val avx_pabsw_512 : (zmmword) -> zmmword
function avx_pabsw_512(a) =
  avx_pabsw_256(a[511..256]) @ avx_pabsw_256(a[255..0])

// =========================================================================
// VPABSD: absolute value of packed signed dwords
// =========================================================================

val avx_pabsd_128 : (xmmword) -> xmmword
function avx_pabsd_128(a) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = abs32(a[(lo + 31)..lo]);
  };
  r
}

val avx_pabsd_256 : (ymmword) -> ymmword
function avx_pabsd_256(a) =
  avx_pabsd_128(a[255..128]) @ avx_pabsd_128(a[127..0])

val avx_pabsd_512 : (zmmword) -> zmmword
function avx_pabsd_512(a) =
  avx_pabsd_256(a[511..256]) @ avx_pabsd_256(a[255..0])

// =========================================================================
// VPABSQ: absolute value of packed signed qwords
// =========================================================================

val avx_pabsq_128 : (xmmword) -> xmmword
function avx_pabsq_128(a) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    r[(lo + 63)..lo] = abs64(a[(lo + 63)..lo]);
  };
  r
}

val avx_pabsq_256 : (ymmword) -> ymmword
function avx_pabsq_256(a) =
  avx_pabsq_128(a[255..128]) @ avx_pabsq_128(a[127..0])

val avx_pabsq_512 : (zmmword) -> zmmword
function avx_pabsq_512(a) =
  avx_pabsq_256(a[511..256]) @ avx_pabsq_256(a[255..0])

// =========================================================================
// VPMINSB: signed byte min
// =========================================================================

val avx_pminsb_512 : (zmmword, zmmword) -> zmmword
function avx_pminsb_512(a, b) =
  avx_pminsb_256(a[511..256], b[511..256]) @ avx_pminsb_256(a[255..0], b[255..0])

// =========================================================================
// VPMINSD: signed dword min
// =========================================================================

val avx_pminsd_512 : (zmmword, zmmword) -> zmmword
function avx_pminsd_512(a, b) =
  avx_pminsd_256(a[511..256], b[511..256]) @ avx_pminsd_256(a[255..0], b[255..0])

// =========================================================================
// VPMINSQ: signed qword min
// =========================================================================

val avx_pminsq_128 : (xmmword, xmmword) -> xmmword
function avx_pminsq_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let va = a[(lo + 63)..lo];
    let vb = b[(lo + 63)..lo];
    r[(lo + 63)..lo] = min_s64(va, vb);
  };
  r
}

val avx_pminsq_256 : (ymmword, ymmword) -> ymmword
function avx_pminsq_256(a, b) =
  avx_pminsq_128(a[255..128], b[255..128]) @ avx_pminsq_128(a[127..0], b[127..0])

val avx_pminsq_512 : (zmmword, zmmword) -> zmmword
function avx_pminsq_512(a, b) =
  avx_pminsq_256(a[511..256], b[511..256]) @ avx_pminsq_256(a[255..0], b[255..0])

// =========================================================================
// VPMAXSB: signed byte max
// =========================================================================

val avx_pmaxsb_512 : (zmmword, zmmword) -> zmmword
function avx_pmaxsb_512(a, b) =
  avx_pmaxsb_256(a[511..256], b[511..256]) @ avx_pmaxsb_256(a[255..0], b[255..0])

// =========================================================================
// VPMAXSD: signed dword max
// =========================================================================

val avx_pmaxsd_512 : (zmmword, zmmword) -> zmmword
function avx_pmaxsd_512(a, b) =
  avx_pmaxsd_256(a[511..256], b[511..256]) @ avx_pmaxsd_256(a[255..0], b[255..0])

// =========================================================================
// VPMAXSQ: signed qword max
// =========================================================================

val avx_pmaxsq_128 : (xmmword, xmmword) -> xmmword
function avx_pmaxsq_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let va = a[(lo + 63)..lo];
    let vb = b[(lo + 63)..lo];
    r[(lo + 63)..lo] = max_s64(va, vb);
  };
  r
}

val avx_pmaxsq_256 : (ymmword, ymmword) -> ymmword
function avx_pmaxsq_256(a, b) =
  avx_pmaxsq_128(a[255..128], b[255..128]) @ avx_pmaxsq_128(a[127..0], b[127..0])

val avx_pmaxsq_512 : (zmmword, zmmword) -> zmmword
function avx_pmaxsq_512(a, b) =
  avx_pmaxsq_256(a[511..256], b[511..256]) @ avx_pmaxsq_256(a[255..0], b[255..0])

// =========================================================================
// VPMAXUW: unsigned word max
// =========================================================================

val avx_pmaxuw_128 : (xmmword, xmmword) -> xmmword
function avx_pmaxuw_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    let va = a[(lo + 15)..lo];
    let vb = b[(lo + 15)..lo];
    r[(lo + 15)..lo] = max_u16(va, vb);
  };
  r
}

val avx_pmaxuw_256 : (ymmword, ymmword) -> ymmword
function avx_pmaxuw_256(a, b) =
  avx_pmaxuw_128(a[255..128], b[255..128]) @ avx_pmaxuw_128(a[127..0], b[127..0])

val avx_pmaxuw_512 : (zmmword, zmmword) -> zmmword
function avx_pmaxuw_512(a, b) =
  avx_pmaxuw_256(a[511..256], b[511..256]) @ avx_pmaxuw_256(a[255..0], b[255..0])

// =========================================================================
// VPMAXUD: unsigned dword max
// =========================================================================

val avx_pmaxud_512 : (zmmword, zmmword) -> zmmword
function avx_pmaxud_512(a, b) =
  avx_pmaxud_256(a[511..256], b[511..256]) @ avx_pmaxud_256(a[255..0], b[255..0])

// =========================================================================
// VPMAXUQ: unsigned qword max
// =========================================================================

val avx_pminuq_128 : (xmmword, xmmword) -> xmmword
function avx_pminuq_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let va = a[(lo + 63)..lo];
    let vb = b[(lo + 63)..lo];
    r[(lo + 63)..lo] = min_u64(va, vb);
  };
  r
}

val avx_pminuq_256 : (ymmword, ymmword) -> ymmword
function avx_pminuq_256(a, b) =
  avx_pminuq_128(a[255..128], b[255..128]) @ avx_pminuq_128(a[127..0], b[127..0])

val avx_pminuq_512 : (zmmword, zmmword) -> zmmword
function avx_pminuq_512(a, b) =
  avx_pminuq_256(a[511..256], b[511..256]) @ avx_pminuq_256(a[255..0], b[255..0])

val avx_pmaxuq_128 : (xmmword, xmmword) -> xmmword
function avx_pmaxuq_128(a, b) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    let va = a[(lo + 63)..lo];
    let vb = b[(lo + 63)..lo];
    r[(lo + 63)..lo] = max_u64(va, vb);
  };
  r
}

val avx_pmaxuq_256 : (ymmword, ymmword) -> ymmword
function avx_pmaxuq_256(a, b) =
  avx_pmaxuq_128(a[255..128], b[255..128]) @ avx_pmaxuq_128(a[127..0], b[127..0])

val avx_pmaxuq_512 : (zmmword, zmmword) -> zmmword
function avx_pmaxuq_512(a, b) =
  avx_pmaxuq_256(a[511..256], b[511..256]) @ avx_pmaxuq_256(a[255..0], b[255..0])

// =========================================================================
// VPACKUSDW: pack dwords to words with unsigned saturation
// Per 128-bit lane: 4 dwords from src1 -> 4 words, 4 dwords from src2 -> 4 words
// Each signed dword is clamped to [0, 65535] before truncation
// =========================================================================

val avx_packusdw_512 : (zmmword, zmmword) -> zmmword
function avx_packusdw_512(a, b) =
  avx_packusdw_256(a[511..256], b[511..256]) @ avx_packusdw_256(a[255..0], b[255..0])

// =========================================================================
// VPERMI2/VPERMT2: 2-source permute using index vector
// vperm2_d: select dwords from combined (t1,t2) table using idx
// vperm2_q: select qwords from combined (t1,t2) table using idx
// =========================================================================

val avx_pmovwb_128 : xmmword -> qword
function avx_pmovwb_128(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 112) = i * 16;
    let dlo : range(0, 56) = i * 8;
    r[(dlo + 7)..dlo] = src[(slo + 7)..slo];
  };
  r
}

val avx_pmovwb_256 : ymmword -> xmmword
function avx_pmovwb_256(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let slo : range(0, 240) = i * 16;
    let dlo : range(0, 120) = i * 8;
    r[(dlo + 7)..dlo] = src[(slo + 7)..slo];
  };
  r
}

val avx_pmovwb_512 : zmmword -> ymmword
function avx_pmovwb_512(src) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 31) {
    let slo : range(0, 496) = i * 16;
    let dlo : range(0, 248) = i * 8;
    r[(dlo + 7)..dlo] = src[(slo + 7)..slo];
  };
  r
}

// --- VPMOVDB: truncate dword -> byte ---

val avx_pmovdb_128 : xmmword -> dword
function avx_pmovdb_128(src) = {
  var r : dword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 96) = i * 32;
    let dlo : range(0, 24) = i * 8;
    r[(dlo + 7)..dlo] = src[(slo + 7)..slo];
  };
  r
}

val avx_pmovdb_256 : ymmword -> qword
function avx_pmovdb_256(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 224) = i * 32;
    let dlo : range(0, 56) = i * 8;
    r[(dlo + 7)..dlo] = src[(slo + 7)..slo];
  };
  r
}

val avx_pmovdb_512 : zmmword -> xmmword
function avx_pmovdb_512(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let slo : range(0, 480) = i * 32;
    let dlo : range(0, 120) = i * 8;
    r[(dlo + 7)..dlo] = src[(slo + 7)..slo];
  };
  r
}

// --- VPMOVQB: truncate qword -> byte ---

val avx_pmovqb_128 : xmmword -> word
function avx_pmovqb_128(src) = {
  var r : word = zeros();
  foreach (i from 0 to 1) {
    let slo : range(0, 64) = i * 64;
    let dlo : range(0, 8) = i * 8;
    r[(dlo + 7)..dlo] = src[(slo + 7)..slo];
  };
  r
}

val avx_pmovqb_256 : ymmword -> dword
function avx_pmovqb_256(src) = {
  var r : dword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 192) = i * 64;
    let dlo : range(0, 24) = i * 8;
    r[(dlo + 7)..dlo] = src[(slo + 7)..slo];
  };
  r
}

val avx_pmovqb_512 : zmmword -> qword
function avx_pmovqb_512(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 448) = i * 64;
    let dlo : range(0, 56) = i * 8;
    r[(dlo + 7)..dlo] = src[(slo + 7)..slo];
  };
  r
}

// --- VPMOVDW: truncate dword -> word ---

val avx_pmovdw_128 : xmmword -> qword
function avx_pmovdw_128(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 96) = i * 32;
    let dlo : range(0, 48) = i * 16;
    r[(dlo + 15)..dlo] = src[(slo + 15)..slo];
  };
  r
}

val avx_pmovdw_256 : ymmword -> xmmword
function avx_pmovdw_256(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 224) = i * 32;
    let dlo : range(0, 112) = i * 16;
    r[(dlo + 15)..dlo] = src[(slo + 15)..slo];
  };
  r
}

val avx_pmovdw_512 : zmmword -> ymmword
function avx_pmovdw_512(src) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 15) {
    let slo : range(0, 480) = i * 32;
    let dlo : range(0, 240) = i * 16;
    r[(dlo + 15)..dlo] = src[(slo + 15)..slo];
  };
  r
}

// --- VPMOVQW: truncate qword -> word ---

val avx_pmovqw_128 : xmmword -> dword
function avx_pmovqw_128(src) = {
  var r : dword = zeros();
  foreach (i from 0 to 1) {
    let slo : range(0, 64) = i * 64;
    let dlo : range(0, 16) = i * 16;
    r[(dlo + 15)..dlo] = src[(slo + 15)..slo];
  };
  r
}

val avx_pmovqw_256 : ymmword -> qword
function avx_pmovqw_256(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 192) = i * 64;
    let dlo : range(0, 48) = i * 16;
    r[(dlo + 15)..dlo] = src[(slo + 15)..slo];
  };
  r
}

val avx_pmovqw_512 : zmmword -> xmmword
function avx_pmovqw_512(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 448) = i * 64;
    let dlo : range(0, 112) = i * 16;
    r[(dlo + 15)..dlo] = src[(slo + 15)..slo];
  };
  r
}

// --- VPMOVQD: truncate qword -> dword ---

val avx_pmovqd_128 : xmmword -> qword
function avx_pmovqd_128(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 1) {
    let slo : range(0, 64) = i * 64;
    let dlo : range(0, 32) = i * 32;
    r[(dlo + 31)..dlo] = src[(slo + 31)..slo];
  };
  r
}

val avx_pmovqd_256 : ymmword -> xmmword
function avx_pmovqd_256(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 192) = i * 64;
    let dlo : range(0, 96) = i * 32;
    r[(dlo + 31)..dlo] = src[(slo + 31)..slo];
  };
  r
}

val avx_pmovqd_512 : zmmword -> ymmword
function avx_pmovqd_512(src) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 448) = i * 64;
    let dlo : range(0, 224) = i * 32;
    r[(dlo + 31)..dlo] = src[(slo + 31)..slo];
  };
  r
}

// --- VPMOVUSWB: unsigned-saturate word -> byte ---

val avx_pmovuswb_128 : xmmword -> qword
function avx_pmovuswb_128(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 112) = i * 16;
    let dlo : range(0, 56) = i * 8;
    r[(dlo + 7)..dlo] = sat_trunc_u_w2b(src[(slo + 15)..slo]);
  };
  r
}

val avx_pmovuswb_256 : ymmword -> xmmword
function avx_pmovuswb_256(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let slo : range(0, 240) = i * 16;
    let dlo : range(0, 120) = i * 8;
    r[(dlo + 7)..dlo] = sat_trunc_u_w2b(src[(slo + 15)..slo]);
  };
  r
}

val avx_pmovuswb_512 : zmmword -> ymmword
function avx_pmovuswb_512(src) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 31) {
    let slo : range(0, 496) = i * 16;
    let dlo : range(0, 248) = i * 8;
    r[(dlo + 7)..dlo] = sat_trunc_u_w2b(src[(slo + 15)..slo]);
  };
  r
}

// --- VPMOVUSDB: unsigned-saturate dword -> byte ---

val avx_pmovusdb_128 : xmmword -> dword
function avx_pmovusdb_128(src) = {
  var r : dword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 96) = i * 32;
    let dlo : range(0, 24) = i * 8;
    r[(dlo + 7)..dlo] = sat_trunc_u_d2b(src[(slo + 31)..slo]);
  };
  r
}

val avx_pmovusdb_256 : ymmword -> qword
function avx_pmovusdb_256(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 224) = i * 32;
    let dlo : range(0, 56) = i * 8;
    r[(dlo + 7)..dlo] = sat_trunc_u_d2b(src[(slo + 31)..slo]);
  };
  r
}

val avx_pmovusdb_512 : zmmword -> xmmword
function avx_pmovusdb_512(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let slo : range(0, 480) = i * 32;
    let dlo : range(0, 120) = i * 8;
    r[(dlo + 7)..dlo] = sat_trunc_u_d2b(src[(slo + 31)..slo]);
  };
  r
}

// --- VPMOVUSQB: unsigned-saturate qword -> byte ---

val avx_pmovusqb_128 : xmmword -> word
function avx_pmovusqb_128(src) = {
  var r : word = zeros();
  foreach (i from 0 to 1) {
    let slo : range(0, 64) = i * 64;
    let dlo : range(0, 8) = i * 8;
    r[(dlo + 7)..dlo] = sat_trunc_u_q2b(src[(slo + 63)..slo]);
  };
  r
}

val avx_pmovusqb_256 : ymmword -> dword
function avx_pmovusqb_256(src) = {
  var r : dword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 192) = i * 64;
    let dlo : range(0, 24) = i * 8;
    r[(dlo + 7)..dlo] = sat_trunc_u_q2b(src[(slo + 63)..slo]);
  };
  r
}

val avx_pmovusqb_512 : zmmword -> qword
function avx_pmovusqb_512(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 448) = i * 64;
    let dlo : range(0, 56) = i * 8;
    r[(dlo + 7)..dlo] = sat_trunc_u_q2b(src[(slo + 63)..slo]);
  };
  r
}

// --- VPMOVUSDW: unsigned-saturate dword -> word ---

val avx_pmovusdw_128 : xmmword -> qword
function avx_pmovusdw_128(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 96) = i * 32;
    let dlo : range(0, 48) = i * 16;
    r[(dlo + 15)..dlo] = sat_trunc_u_d2w(src[(slo + 31)..slo]);
  };
  r
}

val avx_pmovusdw_256 : ymmword -> xmmword
function avx_pmovusdw_256(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 224) = i * 32;
    let dlo : range(0, 112) = i * 16;
    r[(dlo + 15)..dlo] = sat_trunc_u_d2w(src[(slo + 31)..slo]);
  };
  r
}

val avx_pmovusdw_512 : zmmword -> ymmword
function avx_pmovusdw_512(src) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 15) {
    let slo : range(0, 480) = i * 32;
    let dlo : range(0, 240) = i * 16;
    r[(dlo + 15)..dlo] = sat_trunc_u_d2w(src[(slo + 31)..slo]);
  };
  r
}

// --- VPMOVUSQW: unsigned-saturate qword -> word ---

val avx_pmovusqw_128 : xmmword -> dword
function avx_pmovusqw_128(src) = {
  var r : dword = zeros();
  foreach (i from 0 to 1) {
    let slo : range(0, 64) = i * 64;
    let dlo : range(0, 16) = i * 16;
    r[(dlo + 15)..dlo] = sat_trunc_u_q2w(src[(slo + 63)..slo]);
  };
  r
}

val avx_pmovusqw_256 : ymmword -> qword
function avx_pmovusqw_256(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 192) = i * 64;
    let dlo : range(0, 48) = i * 16;
    r[(dlo + 15)..dlo] = sat_trunc_u_q2w(src[(slo + 63)..slo]);
  };
  r
}

val avx_pmovusqw_512 : zmmword -> xmmword
function avx_pmovusqw_512(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 448) = i * 64;
    let dlo : range(0, 112) = i * 16;
    r[(dlo + 15)..dlo] = sat_trunc_u_q2w(src[(slo + 63)..slo]);
  };
  r
}

// --- VPMOVUSQD: unsigned-saturate qword -> dword ---

val avx_pmovusqd_128 : xmmword -> qword
function avx_pmovusqd_128(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 1) {
    let slo : range(0, 64) = i * 64;
    let dlo : range(0, 32) = i * 32;
    r[(dlo + 31)..dlo] = sat_trunc_u_q2d(src[(slo + 63)..slo]);
  };
  r
}

val avx_pmovusqd_256 : ymmword -> xmmword
function avx_pmovusqd_256(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 192) = i * 64;
    let dlo : range(0, 96) = i * 32;
    r[(dlo + 31)..dlo] = sat_trunc_u_q2d(src[(slo + 63)..slo]);
  };
  r
}

val avx_pmovusqd_512 : zmmword -> ymmword
function avx_pmovusqd_512(src) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 448) = i * 64;
    let dlo : range(0, 224) = i * 32;
    r[(dlo + 31)..dlo] = sat_trunc_u_q2d(src[(slo + 63)..slo]);
  };
  r
}

// --- VPMOVSWB: signed-saturate word -> byte ---

val avx_pmovswb_128 : xmmword -> qword
function avx_pmovswb_128(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 112) = i * 16;
    let dlo : range(0, 56) = i * 8;
    r[(dlo + 7)..dlo] = sat_s16_to_s8(src[(slo + 15)..slo]);
  };
  r
}

val avx_pmovswb_256 : ymmword -> xmmword
function avx_pmovswb_256(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let slo : range(0, 240) = i * 16;
    let dlo : range(0, 120) = i * 8;
    r[(dlo + 7)..dlo] = sat_s16_to_s8(src[(slo + 15)..slo]);
  };
  r
}

val avx_pmovswb_512 : zmmword -> ymmword
function avx_pmovswb_512(src) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 31) {
    let slo : range(0, 496) = i * 16;
    let dlo : range(0, 248) = i * 8;
    r[(dlo + 7)..dlo] = sat_s16_to_s8(src[(slo + 15)..slo]);
  };
  r
}

// --- VPMOVSDB: signed-saturate dword -> byte ---

val avx_pmovsdb_128 : xmmword -> dword
function avx_pmovsdb_128(src) = {
  var r : dword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 96) = i * 32;
    let dlo : range(0, 24) = i * 8;
    r[(dlo + 7)..dlo] = sat_s32_to_s8(src[(slo + 31)..slo]);
  };
  r
}

val avx_pmovsdb_256 : ymmword -> qword
function avx_pmovsdb_256(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 224) = i * 32;
    let dlo : range(0, 56) = i * 8;
    r[(dlo + 7)..dlo] = sat_s32_to_s8(src[(slo + 31)..slo]);
  };
  r
}

val avx_pmovsdb_512 : zmmword -> xmmword
function avx_pmovsdb_512(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let slo : range(0, 480) = i * 32;
    let dlo : range(0, 120) = i * 8;
    r[(dlo + 7)..dlo] = sat_s32_to_s8(src[(slo + 31)..slo]);
  };
  r
}

// --- VPMOVSQB: signed-saturate qword -> byte ---

val avx_pmovsqb_128 : xmmword -> word
function avx_pmovsqb_128(src) = {
  var r : word = zeros();
  foreach (i from 0 to 1) {
    let slo : range(0, 64) = i * 64;
    let dlo : range(0, 8) = i * 8;
    r[(dlo + 7)..dlo] = sat_s64_to_s8(src[(slo + 63)..slo]);
  };
  r
}

val avx_pmovsqb_256 : ymmword -> dword
function avx_pmovsqb_256(src) = {
  var r : dword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 192) = i * 64;
    let dlo : range(0, 24) = i * 8;
    r[(dlo + 7)..dlo] = sat_s64_to_s8(src[(slo + 63)..slo]);
  };
  r
}

val avx_pmovsqb_512 : zmmword -> qword
function avx_pmovsqb_512(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 448) = i * 64;
    let dlo : range(0, 56) = i * 8;
    r[(dlo + 7)..dlo] = sat_s64_to_s8(src[(slo + 63)..slo]);
  };
  r
}

// --- VPMOVSDW: signed-saturate dword -> word ---

val avx_pmovsdw_128 : xmmword -> qword
function avx_pmovsdw_128(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 96) = i * 32;
    let dlo : range(0, 48) = i * 16;
    r[(dlo + 15)..dlo] = sat_s32_to_s16(src[(slo + 31)..slo]);
  };
  r
}

val avx_pmovsdw_256 : ymmword -> xmmword
function avx_pmovsdw_256(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 224) = i * 32;
    let dlo : range(0, 112) = i * 16;
    r[(dlo + 15)..dlo] = sat_s32_to_s16(src[(slo + 31)..slo]);
  };
  r
}

val avx_pmovsdw_512 : zmmword -> ymmword
function avx_pmovsdw_512(src) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 15) {
    let slo : range(0, 480) = i * 32;
    let dlo : range(0, 240) = i * 16;
    r[(dlo + 15)..dlo] = sat_s32_to_s16(src[(slo + 31)..slo]);
  };
  r
}

// --- VPMOVSQW: signed-saturate qword -> word ---

val avx_pmovsqw_128 : xmmword -> dword
function avx_pmovsqw_128(src) = {
  var r : dword = zeros();
  foreach (i from 0 to 1) {
    let slo : range(0, 64) = i * 64;
    let dlo : range(0, 16) = i * 16;
    r[(dlo + 15)..dlo] = sat_s64_to_s16(src[(slo + 63)..slo]);
  };
  r
}

val avx_pmovsqw_256 : ymmword -> qword
function avx_pmovsqw_256(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 192) = i * 64;
    let dlo : range(0, 48) = i * 16;
    r[(dlo + 15)..dlo] = sat_s64_to_s16(src[(slo + 63)..slo]);
  };
  r
}

val avx_pmovsqw_512 : zmmword -> xmmword
function avx_pmovsqw_512(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 448) = i * 64;
    let dlo : range(0, 112) = i * 16;
    r[(dlo + 15)..dlo] = sat_s64_to_s16(src[(slo + 63)..slo]);
  };
  r
}

// --- VPMOVSQD: signed-saturate qword -> dword ---

val avx_pmovsqd_128 : xmmword -> qword
function avx_pmovsqd_128(src) = {
  var r : qword = zeros();
  foreach (i from 0 to 1) {
    let slo : range(0, 64) = i * 64;
    let dlo : range(0, 32) = i * 32;
    r[(dlo + 31)..dlo] = sat_s64_to_s32(src[(slo + 63)..slo]);
  };
  r
}

val avx_pmovsqd_256 : ymmword -> xmmword
function avx_pmovsqd_256(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let slo : range(0, 192) = i * 64;
    let dlo : range(0, 96) = i * 32;
    r[(dlo + 31)..dlo] = sat_s64_to_s32(src[(slo + 63)..slo]);
  };
  r
}

val avx_pmovsqd_512 : zmmword -> ymmword
function avx_pmovsqd_512(src) = {
  var r : ymmword = zeros();
  foreach (i from 0 to 7) {
    let slo : range(0, 448) = i * 64;
    let dlo : range(0, 224) = i * 32;
    r[(dlo + 31)..dlo] = sat_s64_to_s32(src[(slo + 63)..slo]);
  };
  r
}

// =====================================================================
// VPMOVM2B: mask register -> vector (each bit -> 0xFF or 0x00 byte)
// =====================================================================

val avx_vpmovm2b_128 : qword -> xmmword
function avx_vpmovm2b_128(k) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    result[(lo + 7)..lo] = zeros() - zero_extend([k[i]]);
  };
  result
}

val avx_vpmovm2b_256 : qword -> ymmword
function avx_vpmovm2b_256(k) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 31) {
    let lo : range(0, 248) = i * 8;
    result[(lo + 7)..lo] = zeros() - zero_extend([k[i]]);
  };
  result
}

val avx_vpmovm2b_512 : qword -> zmmword
function avx_vpmovm2b_512(k) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 63) {
    let lo : range(0, 504) = i * 8;
    result[(lo + 7)..lo] = zeros() - zero_extend([k[i]]);
  };
  result
}

// =====================================================================
// VPMOVM2W: mask register -> vector (each bit -> 0xFFFF or 0x0000 word)
// =====================================================================

val avx_vpmovm2w_128 : qword -> xmmword
function avx_vpmovm2w_128(k) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    result[(lo + 15)..lo] = zeros() - zero_extend([k[i]]);
  };
  result
}

val avx_vpmovm2w_256 : qword -> ymmword
function avx_vpmovm2w_256(k) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 240) = i * 16;
    result[(lo + 15)..lo] = zeros() - zero_extend([k[i]]);
  };
  result
}

val avx_vpmovm2w_512 : qword -> zmmword
function avx_vpmovm2w_512(k) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 31) {
    let lo : range(0, 496) = i * 16;
    result[(lo + 15)..lo] = zeros() - zero_extend([k[i]]);
  };
  result
}

// =====================================================================
// VPMOVM2D: mask register -> vector (each bit -> all-ones or all-zeros dword)
// =====================================================================

val avx_vpmovm2d_128 : qword -> xmmword
function avx_vpmovm2d_128(k) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    result[(lo + 31)..lo] = zeros() - zero_extend([k[i]]);
  };
  result
}

val avx_vpmovm2d_256 : qword -> ymmword
function avx_vpmovm2d_256(k) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 224) = i * 32;
    result[(lo + 31)..lo] = zeros() - zero_extend([k[i]]);
  };
  result
}

val avx_vpmovm2d_512 : qword -> zmmword
function avx_vpmovm2d_512(k) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 480) = i * 32;
    result[(lo + 31)..lo] = zeros() - zero_extend([k[i]]);
  };
  result
}

// =====================================================================
// VPMOVM2Q: mask register -> vector (each bit -> all-ones or all-zeros qword)
// =====================================================================

val avx_vpmovm2q_128 : qword -> xmmword
function avx_vpmovm2q_128(k) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 1) {
    let lo : range(0, 64) = i * 64;
    result[(lo + 63)..lo] = zeros() - zero_extend([k[i]]);
  };
  result
}

val avx_vpmovm2q_256 : qword -> ymmword
function avx_vpmovm2q_256(k) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 192) = i * 64;
    result[(lo + 63)..lo] = zeros() - zero_extend([k[i]]);
  };
  result
}

val avx_vpmovm2q_512 : qword -> zmmword
function avx_vpmovm2q_512(k) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 448) = i * 64;
    result[(lo + 63)..lo] = zeros() - zero_extend([k[i]]);
  };
  result
}

// =====================================================================
// VPMOVB2M: vector -> mask (MSB of each byte -> mask bit)
// =====================================================================

val avx_vpmovb2m_128 : xmmword -> qword
function avx_vpmovb2m_128(src) = {
  let mask : word =
    src[127..127] @ src[119..119] @ src[111..111] @ src[103..103] @
    src[95..95] @ src[87..87] @ src[79..79] @ src[71..71] @
    src[63..63] @ src[55..55] @ src[47..47] @ src[39..39] @
    src[31..31] @ src[23..23] @ src[15..15] @ src[7..7];
  zero_extend(mask)
}

val avx_vpmovb2m_256 : ymmword -> qword
function avx_vpmovb2m_256(src) = {
  let mask : dword =
    avx_vpmovb2m_128(src[255..128])[15..0] @
    avx_vpmovb2m_128(src[127..0])[15..0];
  zero_extend(mask)
}

val avx_vpmovb2m_512 : zmmword -> qword
function avx_vpmovb2m_512(src) =
  avx_vpmovb2m_128(src[511..384])[15..0] @
  avx_vpmovb2m_128(src[383..256])[15..0] @
  avx_vpmovb2m_128(src[255..128])[15..0] @
  avx_vpmovb2m_128(src[127..0])[15..0]

// =====================================================================
// VPMOVW2M: vector -> mask (MSB of each word -> mask bit)
// =====================================================================

val avx_vpmovw2m_128 : xmmword -> qword
function avx_vpmovw2m_128(src) = {
  let mask : byte =
    src[127..127] @ src[111..111] @ src[95..95] @ src[79..79] @
    src[63..63] @ src[47..47] @ src[31..31] @ src[15..15];
  zero_extend(mask)
}

val avx_vpmovw2m_256 : ymmword -> qword
function avx_vpmovw2m_256(src) = {
  let mask : word =
    avx_vpmovw2m_128(src[255..128])[7..0] @
    avx_vpmovw2m_128(src[127..0])[7..0];
  zero_extend(mask)
}

val avx_vpmovw2m_512 : zmmword -> qword
function avx_vpmovw2m_512(src) = {
  let mask : dword =
    avx_vpmovw2m_128(src[511..384])[7..0] @
    avx_vpmovw2m_128(src[383..256])[7..0] @
    avx_vpmovw2m_128(src[255..128])[7..0] @
    avx_vpmovw2m_128(src[127..0])[7..0];
  zero_extend(mask)
}

// =====================================================================
// VPMOVD2M: vector -> mask (MSB of each dword -> mask bit)
// =====================================================================

val avx_vpmovd2m_128 : xmmword -> qword
function avx_vpmovd2m_128(src) = {
  let mask : bits(4) = src[127..127] @ src[95..95] @ src[63..63] @ src[31..31];
  zero_extend(mask)
}

val avx_vpmovd2m_256 : ymmword -> qword
function avx_vpmovd2m_256(src) = {
  let mask : byte =
    avx_vpmovd2m_128(src[255..128])[3..0] @
    avx_vpmovd2m_128(src[127..0])[3..0];
  zero_extend(mask)
}

val avx_vpmovd2m_512 : zmmword -> qword
function avx_vpmovd2m_512(src) = {
  let mask : word =
    avx_vpmovd2m_128(src[511..384])[3..0] @
    avx_vpmovd2m_128(src[383..256])[3..0] @
    avx_vpmovd2m_128(src[255..128])[3..0] @
    avx_vpmovd2m_128(src[127..0])[3..0];
  zero_extend(mask)
}

// =====================================================================
// VPMOVQ2M: vector -> mask (MSB of each qword -> mask bit)
// =====================================================================

val avx_vpmovq2m_128 : xmmword -> qword
function avx_vpmovq2m_128(src) = {
  let mask : bits(2) = src[127..127] @ src[63..63];
  zero_extend(mask)
}

val avx_vpmovq2m_256 : ymmword -> qword
function avx_vpmovq2m_256(src) = {
  let mask : bits(4) =
    avx_vpmovq2m_128(src[255..128])[1..0] @
    avx_vpmovq2m_128(src[127..0])[1..0];
  zero_extend(mask)
}

val avx_vpmovq2m_512 : zmmword -> qword
function avx_vpmovq2m_512(src) = {
  let mask : byte =
    avx_vpmovq2m_128(src[511..384])[1..0] @
    avx_vpmovq2m_128(src[383..256])[1..0] @
    avx_vpmovq2m_128(src[255..128])[1..0] @
    avx_vpmovq2m_128(src[127..0])[1..0];
  zero_extend(mask)
}

/* ---- VSHUFF32X4 / VSHUFI32X4: 128-bit lane shuffle ---- */

// Helper: select 128-bit lane from a 512-bit source

val avx_lzcnt32 : dword -> dword
function avx_lzcnt32(v) = {
  if v == zeros() then {
    0x00000020
  } else {
    let count : range(0, 32) = 0;
    foreach (i from 31 downto 0) {
      if v[i] == bitone then return to_bits(32, 31 - i)
    };
    0x00000020
  }
}

val avx_lzcnt64 : qword -> qword
function avx_lzcnt64(v) = {
  if v == zeros() then {
    0x0000000000000040
  } else {
    foreach (i from 63 downto 0) {
      if v[i] == bitone then return to_bits(64, 63 - i)
    };
    0x0000000000000040
  }
}

val avx_vplzcntd_128 : xmmword -> xmmword
function avx_vplzcntd_128(src) = {
  avx_lzcnt32(src[127..96]) @ avx_lzcnt32(src[95..64]) @ avx_lzcnt32(src[63..32]) @ avx_lzcnt32(src[31..0])
}

val avx_vplzcntd_256 : ymmword -> ymmword
function avx_vplzcntd_256(src) = {
  avx_vplzcntd_128(src[255..128]) @ avx_vplzcntd_128(src[127..0])
}

val avx_vplzcntd_512 : zmmword -> zmmword
function avx_vplzcntd_512(src) = {
  avx_vplzcntd_256(src[511..256]) @ avx_vplzcntd_256(src[255..0])
}

val avx_vplzcntq_128 : xmmword -> xmmword
function avx_vplzcntq_128(src) = {
  avx_lzcnt64(src[127..64]) @ avx_lzcnt64(src[63..0])
}

val avx_vplzcntq_256 : ymmword -> ymmword
function avx_vplzcntq_256(src) = {
  avx_vplzcntq_128(src[255..128]) @ avx_vplzcntq_128(src[127..0])
}

val avx_vplzcntq_512 : zmmword -> zmmword
function avx_vplzcntq_512(src) = {
  avx_vplzcntq_256(src[511..256]) @ avx_vplzcntq_256(src[255..0])
}

/* ---- VPCONFLICTD/Q: conflict detection ---- */
// For each element i, produce a bitmask of preceding elements (j < i) that have the same value.

val avx_vpconflictd_128 : xmmword -> xmmword
function avx_vpconflictd_128(src) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 3) {
    let ilo : range(0, 96) = i * 32;
    let elem_i : dword = src[(ilo + 31)..ilo];
    var mask : dword = zeros();
    foreach (j from 0 to 3) {
      if j < i then {
        let jlo : range(0, 96) = j * 32;
        let elem_j : dword = src[(jlo + 31)..jlo];
        if elem_i == elem_j then mask = mask | (sail_zero_extend(0x00000001, 32) << j);
      }
    };
    result[(ilo + 31)..ilo] = mask;
  };
  result
}

val avx_vpconflictd_256 : ymmword -> ymmword
function avx_vpconflictd_256(src) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 7) {
    let ilo : range(0, 224) = i * 32;
    let elem_i : dword = src[(ilo + 31)..ilo];
    var mask : dword = zeros();
    foreach (j from 0 to 7) {
      if j < i then {
        let jlo : range(0, 224) = j * 32;
        let elem_j : dword = src[(jlo + 31)..jlo];
        if elem_i == elem_j then mask = mask | (sail_zero_extend(0x00000001, 32) << j);
      }
    };
    result[(ilo + 31)..ilo] = mask;
  };
  result
}

val avx_vpconflictd_512 : zmmword -> zmmword
function avx_vpconflictd_512(src) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 15) {
    let ilo : range(0, 480) = i * 32;
    let elem_i : dword = src[(ilo + 31)..ilo];
    var mask : dword = zeros();
    foreach (j from 0 to 15) {
      if j < i then {
        let jlo : range(0, 480) = j * 32;
        let elem_j : dword = src[(jlo + 31)..jlo];
        if elem_i == elem_j then mask = mask | (sail_zero_extend(0x00000001, 32) << j);
      }
    };
    result[(ilo + 31)..ilo] = mask;
  };
  result
}

val avx_vpconflictq_128 : xmmword -> xmmword
function avx_vpconflictq_128(src) = {
  var result : xmmword = zeros();
  foreach (i from 0 to 1) {
    let ilo : range(0, 64) = i * 64;
    let elem_i : qword = src[(ilo + 63)..ilo];
    var mask : qword = zeros();
    foreach (j from 0 to 1) {
      if j < i then {
        let jlo : range(0, 64) = j * 64;
        let elem_j : qword = src[(jlo + 63)..jlo];
        if elem_i == elem_j then mask = mask | (sail_zero_extend(0x0000000000000001, 64) << j);
      }
    };
    result[(ilo + 63)..ilo] = mask;
  };
  result
}

val avx_vpconflictq_256 : ymmword -> ymmword
function avx_vpconflictq_256(src) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 3) {
    let ilo : range(0, 192) = i * 64;
    let elem_i : qword = src[(ilo + 63)..ilo];
    var mask : qword = zeros();
    foreach (j from 0 to 3) {
      if j < i then {
        let jlo : range(0, 192) = j * 64;
        let elem_j : qword = src[(jlo + 63)..jlo];
        if elem_i == elem_j then mask = mask | (sail_zero_extend(0x0000000000000001, 64) << j);
      }
    };
    result[(ilo + 63)..ilo] = mask;
  };
  result
}

val avx_vpconflictq_512 : zmmword -> zmmword
function avx_vpconflictq_512(src) = {
  var result : zmmword = zeros();
  foreach (i from 0 to 7) {
    let ilo : range(0, 448) = i * 64;
    let elem_i : qword = src[(ilo + 63)..ilo];
    var mask : qword = zeros();
    foreach (j from 0 to 7) {
      if j < i then {
        let jlo : range(0, 448) = j * 64;
        let elem_j : qword = src[(jlo + 63)..jlo];
        if elem_i == elem_j then mask = mask | (sail_zero_extend(0x0000000000000001, 64) << j);
      }
    };
    result[(ilo + 63)..ilo] = mask;
  };
  result
}

/* ---- VFPCLASS: classify FP value ---- */
// Returns true if any of the imm8-selected classes match:
// bit 0: QNaN, bit 1: +0, bit 2: -0, bit 3: +Inf, bit 4: -Inf
// bit 5: denormal, bit 6: negative finite, bit 7: SNaN

val avx_vpdpbusd_elem : (dword, dword, dword) -> dword
function avx_vpdpbusd_elem(dst, s1, s2) = {
  let p0 : int = unsigned(s1[7..0]) * signed(s2[7..0]);
  let p1 : int = unsigned(s1[15..8]) * signed(s2[15..8]);
  let p2 : int = unsigned(s1[23..16]) * signed(s2[23..16]);
  let p3 : int = unsigned(s1[31..24]) * signed(s2[31..24]);
  let sum : int = signed(dst) + p0 + p1 + p2 + p3;
  get_slice_int(32, sum, 0)
}

val avx_vpdpbusd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpdpbusd_128(dst, src1, src2) = {
  avx_vpdpbusd_elem(dst[127..96], src1[127..96], src2[127..96]) @
  avx_vpdpbusd_elem(dst[95..64], src1[95..64], src2[95..64]) @
  avx_vpdpbusd_elem(dst[63..32], src1[63..32], src2[63..32]) @
  avx_vpdpbusd_elem(dst[31..0], src1[31..0], src2[31..0])
}

val avx_vpdpbusd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpdpbusd_256(dst, src1, src2) = {
  avx_vpdpbusd_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpdpbusd_128(dst[127..0], src1[127..0], src2[127..0])
}

val avx_vpdpbusd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpdpbusd_512(dst, src1, src2) = {
  avx_vpdpbusd_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpdpbusd_256(dst[255..0], src1[255..0], src2[255..0])
}

/* ---- VPDPWSSD: Multiply and Add Signed Word Integers ---- */
// For each dword: dst += src1.s16[0]*src2.s16[0] + src1.s16[1]*src2.s16[1]

val avx_vpdpwssd_elem : (dword, dword, dword) -> dword
function avx_vpdpwssd_elem(dst, s1, s2) = {
  let p0 : int = signed(s1[15..0]) * signed(s2[15..0]);
  let p1 : int = signed(s1[31..16]) * signed(s2[31..16]);
  let sum : int = signed(dst) + p0 + p1;
  get_slice_int(32, sum, 0)
}

val avx_vpdpwssd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpdpwssd_128(dst, src1, src2) = {
  avx_vpdpwssd_elem(dst[127..96], src1[127..96], src2[127..96]) @
  avx_vpdpwssd_elem(dst[95..64], src1[95..64], src2[95..64]) @
  avx_vpdpwssd_elem(dst[63..32], src1[63..32], src2[63..32]) @
  avx_vpdpwssd_elem(dst[31..0], src1[31..0], src2[31..0])
}

val avx_vpdpwssd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpdpwssd_256(dst, src1, src2) = {
  avx_vpdpwssd_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpdpwssd_128(dst[127..0], src1[127..0], src2[127..0])
}

val avx_vpdpwssd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpdpwssd_512(dst, src1, src2) = {
  avx_vpdpwssd_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpdpwssd_256(dst[255..0], src1[255..0], src2[255..0])
}

/* ---- VPDPWSSDS: Same as VPDPWSSD but with signed dword saturation ---- */

val sat_s32 : int -> dword
function sat_s32(v) = {
  if v > 2147483647 then 0x7FFFFFFF
  else if v < negate(2147483648) then 0x80000000
  else get_slice_int(32, v, 0)
}

val avx_vpdpwssds_elem : (dword, dword, dword) -> dword
function avx_vpdpwssds_elem(dst, s1, s2) = {
  let p0 : int = signed(s1[15..0]) * signed(s2[15..0]);
  let p1 : int = signed(s1[31..16]) * signed(s2[31..16]);
  let sum : int = signed(dst) + p0 + p1;
  sat_s32(sum)
}

val avx_vpdpwssds_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpdpwssds_128(dst, src1, src2) = {
  avx_vpdpwssds_elem(dst[127..96], src1[127..96], src2[127..96]) @
  avx_vpdpwssds_elem(dst[95..64], src1[95..64], src2[95..64]) @
  avx_vpdpwssds_elem(dst[63..32], src1[63..32], src2[63..32]) @
  avx_vpdpwssds_elem(dst[31..0], src1[31..0], src2[31..0])
}

val avx_vpdpwssds_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpdpwssds_256(dst, src1, src2) = {
  avx_vpdpwssds_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpdpwssds_128(dst[127..0], src1[127..0], src2[127..0])
}

val avx_vpdpwssds_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpdpwssds_512(dst, src1, src2) = {
  avx_vpdpwssds_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpdpwssds_256(dst[255..0], src1[255..0], src2[255..0])
}

/* ---- VPDPBUSDS: VPDPBUSD with signed dword saturation ---- */

val avx_vpdpbusds_elem : (dword, dword, dword) -> dword
function avx_vpdpbusds_elem(dst, s1, s2) = {
  let p0 : int = unsigned(s1[7..0]) * signed(s2[7..0]);
  let p1 : int = unsigned(s1[15..8]) * signed(s2[15..8]);
  let p2 : int = unsigned(s1[23..16]) * signed(s2[23..16]);
  let p3 : int = unsigned(s1[31..24]) * signed(s2[31..24]);
  let sum : int = signed(dst) + p0 + p1 + p2 + p3;
  sat_s32(sum)
}

val avx_vpdpbusds_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpdpbusds_128(dst, src1, src2) = {
  avx_vpdpbusds_elem(dst[127..96], src1[127..96], src2[127..96]) @
  avx_vpdpbusds_elem(dst[95..64], src1[95..64], src2[95..64]) @
  avx_vpdpbusds_elem(dst[63..32], src1[63..32], src2[63..32]) @
  avx_vpdpbusds_elem(dst[31..0], src1[31..0], src2[31..0])
}

val avx_vpdpbusds_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpdpbusds_256(dst, src1, src2) = {
  avx_vpdpbusds_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpdpbusds_128(dst[127..0], src1[127..0], src2[127..0])
}

val avx_vpdpbusds_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpdpbusds_512(dst, src1, src2) = {
  avx_vpdpbusds_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpdpbusds_256(dst[255..0], src1[255..0], src2[255..0])
}

/* ---- BF16: convert FP32 to BFloat16 ---- */
// Per SDM: RNE, denormals flush to zero, NaN→QNaN, infinity preserved.
// This is pure integer arithmetic — no FPU involved.
val convert_fp32_to_bf16 : dword -> word
function convert_fp32_to_bf16(x) = {
  let exp : byte = x[30..23];
  let mant : bits(23) = x[22..0];
  if exp == 0x00 then {
    // Zero or denormal → signed zero
    x[31..31] @ 0x0000[14..0]
  } else if exp == 0xFF & mant != zeros() then {
    // NaN → truncate and force QNaN (set bit 6 of result = MSB of BF16 mantissa)
    let truncated : word = x[31..16];
    truncated | 0x0040
  } else if exp == 0xFF then {
    // Infinity → preserve
    x[31..16]
  } else {
    // Normal: round to nearest even using integer arithmetic
    let lsb : bit = x[16];
    let rounding_bias : dword = 0x00007FFF + zero_extend(lsb);
    let temp : dword = x + rounding_bias;
    temp[31..16]
  }
}

/* ---- VCVTNEPS2BF16: convert packed FP32 → packed BF16 ---- */
val avx_vcvtneps2bf16_128 : xmmword -> xmmword
function avx_vcvtneps2bf16_128(src) = {
  0x0000000000000000 @
  convert_fp32_to_bf16(src[127..96]) @
  convert_fp32_to_bf16(src[95..64]) @
  convert_fp32_to_bf16(src[63..32]) @
  convert_fp32_to_bf16(src[31..0])
}

val avx_vcvtneps2bf16_256 : ymmword -> xmmword
function avx_vcvtneps2bf16_256(src) = {
  convert_fp32_to_bf16(src[255..224]) @
  convert_fp32_to_bf16(src[223..192]) @
  convert_fp32_to_bf16(src[191..160]) @
  convert_fp32_to_bf16(src[159..128]) @
  convert_fp32_to_bf16(src[127..96]) @
  convert_fp32_to_bf16(src[95..64]) @
  convert_fp32_to_bf16(src[63..32]) @
  convert_fp32_to_bf16(src[31..0])
}

val avx_vcvtneps2bf16_512 : zmmword -> ymmword
function avx_vcvtneps2bf16_512(src) = {
  convert_fp32_to_bf16(src[511..480]) @
  convert_fp32_to_bf16(src[479..448]) @
  convert_fp32_to_bf16(src[447..416]) @
  convert_fp32_to_bf16(src[415..384]) @
  convert_fp32_to_bf16(src[383..352]) @
  convert_fp32_to_bf16(src[351..320]) @
  convert_fp32_to_bf16(src[319..288]) @
  convert_fp32_to_bf16(src[287..256]) @
  convert_fp32_to_bf16(src[255..224]) @
  convert_fp32_to_bf16(src[223..192]) @
  convert_fp32_to_bf16(src[191..160]) @
  convert_fp32_to_bf16(src[159..128]) @
  convert_fp32_to_bf16(src[127..96]) @
  convert_fp32_to_bf16(src[95..64]) @
  convert_fp32_to_bf16(src[63..32]) @
  convert_fp32_to_bf16(src[31..0])
}

/* ---- VCVTNE2PS2BF16: convert two packed FP32 → packed BF16 ---- */
// Lower half from src2, upper half from src1
val avx_vcvtne2ps2bf16_128 : (xmmword, xmmword) -> xmmword
function avx_vcvtne2ps2bf16_128(src1, src2) = {
  convert_fp32_to_bf16(src1[127..96]) @
  convert_fp32_to_bf16(src1[95..64]) @
  convert_fp32_to_bf16(src1[63..32]) @
  convert_fp32_to_bf16(src1[31..0]) @
  convert_fp32_to_bf16(src2[127..96]) @
  convert_fp32_to_bf16(src2[95..64]) @
  convert_fp32_to_bf16(src2[63..32]) @
  convert_fp32_to_bf16(src2[31..0])
}

val avx_vcvtne2ps2bf16_256 : (ymmword, ymmword) -> ymmword
function avx_vcvtne2ps2bf16_256(src1, src2) = {
  convert_fp32_to_bf16(src1[255..224]) @
  convert_fp32_to_bf16(src1[223..192]) @
  convert_fp32_to_bf16(src1[191..160]) @
  convert_fp32_to_bf16(src1[159..128]) @
  convert_fp32_to_bf16(src1[127..96]) @
  convert_fp32_to_bf16(src1[95..64]) @
  convert_fp32_to_bf16(src1[63..32]) @
  convert_fp32_to_bf16(src1[31..0]) @
  convert_fp32_to_bf16(src2[255..224]) @
  convert_fp32_to_bf16(src2[223..192]) @
  convert_fp32_to_bf16(src2[191..160]) @
  convert_fp32_to_bf16(src2[159..128]) @
  convert_fp32_to_bf16(src2[127..96]) @
  convert_fp32_to_bf16(src2[95..64]) @
  convert_fp32_to_bf16(src2[63..32]) @
  convert_fp32_to_bf16(src2[31..0])
}

val avx_vcvtne2ps2bf16_512 : (zmmword, zmmword) -> zmmword
function avx_vcvtne2ps2bf16_512(src1, src2) = {
  convert_fp32_to_bf16(src1[511..480]) @
  convert_fp32_to_bf16(src1[479..448]) @
  convert_fp32_to_bf16(src1[447..416]) @
  convert_fp32_to_bf16(src1[415..384]) @
  convert_fp32_to_bf16(src1[383..352]) @
  convert_fp32_to_bf16(src1[351..320]) @
  convert_fp32_to_bf16(src1[319..288]) @
  convert_fp32_to_bf16(src1[287..256]) @
  convert_fp32_to_bf16(src1[255..224]) @
  convert_fp32_to_bf16(src1[223..192]) @
  convert_fp32_to_bf16(src1[191..160]) @
  convert_fp32_to_bf16(src1[159..128]) @
  convert_fp32_to_bf16(src1[127..96]) @
  convert_fp32_to_bf16(src1[95..64]) @
  convert_fp32_to_bf16(src1[63..32]) @
  convert_fp32_to_bf16(src1[31..0]) @
  convert_fp32_to_bf16(src2[511..480]) @
  convert_fp32_to_bf16(src2[479..448]) @
  convert_fp32_to_bf16(src2[447..416]) @
  convert_fp32_to_bf16(src2[415..384]) @
  convert_fp32_to_bf16(src2[383..352]) @
  convert_fp32_to_bf16(src2[351..320]) @
  convert_fp32_to_bf16(src2[319..288]) @
  convert_fp32_to_bf16(src2[287..256]) @
  convert_fp32_to_bf16(src2[255..224]) @
  convert_fp32_to_bf16(src2[223..192]) @
  convert_fp32_to_bf16(src2[191..160]) @
  convert_fp32_to_bf16(src2[159..128]) @
  convert_fp32_to_bf16(src2[127..96]) @
  convert_fp32_to_bf16(src2[95..64]) @
  convert_fp32_to_bf16(src2[63..32]) @
  convert_fp32_to_bf16(src2[31..0])
}

/* ---- VDPBF16PS: BF16 dot product accumulating to FP32 ---- */
// Per dword: dest += make_fp32(src1.bf16[hi]) * make_fp32(src2.bf16[hi])
//                  + make_fp32(src1.bf16[lo]) * make_fp32(src2.bf16[lo])
val avx_vdpbf16ps_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vdpbf16ps_128(dst, src1, src2) = {
  __vdpbf16ps_elem(dst[127..96], src1[127..96], src2[127..96]) @
  __vdpbf16ps_elem(dst[95..64], src1[95..64], src2[95..64]) @
  __vdpbf16ps_elem(dst[63..32], src1[63..32], src2[63..32]) @
  __vdpbf16ps_elem(dst[31..0], src1[31..0], src2[31..0])
}

val avx_vdpbf16ps_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vdpbf16ps_256(dst, src1, src2) = {
  avx_vdpbf16ps_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vdpbf16ps_128(dst[127..0], src1[127..0], src2[127..0])
}

val avx_vdpbf16ps_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vdpbf16ps_512(dst, src1, src2) = {
  avx_vdpbf16ps_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vdpbf16ps_256(dst[255..0], src1[255..0], src2[255..0])
}

/* ---- VPOPCNT: population count per element ---- */

// Hacker's Delight population count (branchless).
val popcnt8 : byte -> byte
function popcnt8(v) = {
  var x : byte = v;
  x = x - ((x >> 1) & 0x55);
  x = (x & 0x33) + ((x >> 2) & 0x33);
  (x + (x >> 4)) & 0x0F
}

val popcnt16 : word -> word
function popcnt16(v) = {
  var x : word = v;
  x = x - ((x >> 1) & 0x5555);
  x = (x & 0x3333) + ((x >> 2) & 0x3333);
  x = (x + (x >> 4)) & 0x0F0F;
  x = x + (x >> 8);
  x & 0x001F
}

val popcnt32 : dword -> dword
function popcnt32(v) = {
  var x : dword = v;
  x = x - ((x >> 1) & 0x55555555);
  x = (x & 0x33333333) + ((x >> 2) & 0x33333333);
  x = (x + (x >> 4)) & 0x0F0F0F0F;
  x = x + (x >> 8);
  x = x + (x >> 16);
  x & 0x0000003F
}

val popcnt64 : qword -> qword
function popcnt64(v) = {
  var x : qword = v;
  x = x - ((x >> 1) & 0x5555555555555555);
  x = (x & 0x3333333333333333) + ((x >> 2) & 0x3333333333333333);
  x = (x + (x >> 4)) & 0x0F0F0F0F0F0F0F0F;
  x = x + (x >> 8);
  x = x + (x >> 16);
  x = x + (x >> 32);
  x & 0x000000000000007F
}

// VPOPCNTB (byte elements)

val avx_vpopcntb_128 : xmmword -> xmmword
function avx_vpopcntb_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo : range(0, 120) = i * 8;
    r[(lo + 7)..lo] = popcnt8(src[(lo + 7)..lo]);
  };
  r
}

val avx_vpopcntb_256 : ymmword -> ymmword
function avx_vpopcntb_256(src) = {
  avx_vpopcntb_128(src[255..128]) @ avx_vpopcntb_128(src[127..0])
}

val avx_vpopcntb_512 : zmmword -> zmmword
function avx_vpopcntb_512(src) = {
  avx_vpopcntb_256(src[511..256]) @ avx_vpopcntb_256(src[255..0])
}

// VPOPCNTW (word elements)

val avx_vpopcntw_128 : xmmword -> xmmword
function avx_vpopcntw_128(src) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = popcnt16(src[(lo + 15)..lo]);
  };
  r
}

val avx_vpopcntw_256 : ymmword -> ymmword
function avx_vpopcntw_256(src) = {
  avx_vpopcntw_128(src[255..128]) @ avx_vpopcntw_128(src[127..0])
}

val avx_vpopcntw_512 : zmmword -> zmmword
function avx_vpopcntw_512(src) = {
  avx_vpopcntw_256(src[511..256]) @ avx_vpopcntw_256(src[255..0])
}

// VPOPCNTD (dword elements)

val avx_vpopcntd_128 : xmmword -> xmmword
function avx_vpopcntd_128(src) = {
  popcnt32(src[127..96]) @ popcnt32(src[95..64]) @ popcnt32(src[63..32]) @ popcnt32(src[31..0])
}

val avx_vpopcntd_256 : ymmword -> ymmword
function avx_vpopcntd_256(src) = {
  avx_vpopcntd_128(src[255..128]) @ avx_vpopcntd_128(src[127..0])
}

val avx_vpopcntd_512 : zmmword -> zmmword
function avx_vpopcntd_512(src) = {
  avx_vpopcntd_256(src[511..256]) @ avx_vpopcntd_256(src[255..0])
}

// VPOPCNTQ (qword elements)

val avx_vpopcntq_128 : xmmword -> xmmword
function avx_vpopcntq_128(src) = {
  popcnt64(src[127..64]) @ popcnt64(src[63..0])
}

val avx_vpopcntq_256 : ymmword -> ymmword
function avx_vpopcntq_256(src) = {
  avx_vpopcntq_128(src[255..128]) @ avx_vpopcntq_128(src[127..0])
}

val avx_vpopcntq_512 : zmmword -> zmmword
function avx_vpopcntq_512(src) = {
  avx_vpopcntq_256(src[511..256]) @ avx_vpopcntq_256(src[255..0])
}

/* ---- VCVTPH2PS/VCVTPS2PH: 512-bit variants (128/256 defined in insn_vex.sail) ---- */

val avx_vcvtph2ps_512 : ymmword -> zmmword
function avx_vcvtph2ps_512(src) = {
  avx_vcvtph2ps_256(src[255..128]) @ avx_vcvtph2ps_256(src[127..0])
}

val avx_vpshldvw_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpshldvw_128(dst, src1, src2) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = avx_vpshldw_elem(dst[(lo + 15)..lo], src1[(lo + 15)..lo], unsigned(src2[(lo + 15)..lo]));
  }; r
}

val avx_vpshldvw_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpshldvw_256(dst, src1, src2) = {
  avx_vpshldvw_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpshldvw_128(dst[127..0], src1[127..0], src2[127..0])
}

val avx_vpshldvw_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpshldvw_512(dst, src1, src2) = {
  avx_vpshldvw_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpshldvw_256(dst[255..0], src1[255..0], src2[255..0])
}

val avx_vpshldvd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpshldvd_128(dst, src1, src2) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = avx_vpshldd_elem(dst[(lo + 31)..lo], src1[(lo + 31)..lo], unsigned(src2[(lo + 31)..lo]));
  }; r
}

val avx_vpshldvd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpshldvd_256(dst, src1, src2) = {
  avx_vpshldvd_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpshldvd_128(dst[127..0], src1[127..0], src2[127..0])
}

val avx_vpshldvd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpshldvd_512(dst, src1, src2) = {
  avx_vpshldvd_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpshldvd_256(dst[255..0], src1[255..0], src2[255..0])
}

val avx_vpshldvq_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpshldvq_128(dst, src1, src2) = {
  avx_vpshldq_elem(dst[127..64], src1[127..64], unsigned(src2[127..64])) @
  avx_vpshldq_elem(dst[63..0], src1[63..0], unsigned(src2[63..0]))
}

val avx_vpshldvq_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpshldvq_256(dst, src1, src2) = {
  avx_vpshldvq_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpshldvq_128(dst[127..0], src1[127..0], src2[127..0])
}

val avx_vpshldvq_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpshldvq_512(dst, src1, src2) = {
  avx_vpshldvq_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpshldvq_256(dst[255..0], src1[255..0], src2[255..0])
}

// Variable versions (VPSHRDVW/D/Q)

val avx_vpshrdvw_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpshrdvw_128(dst, src1, src2) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 112) = i * 16;
    r[(lo + 15)..lo] = avx_vpshrdw_elem(dst[(lo + 15)..lo], src1[(lo + 15)..lo], unsigned(src2[(lo + 15)..lo]));
  }; r
}

val avx_vpshrdvw_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpshrdvw_256(dst, src1, src2) = {
  avx_vpshrdvw_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpshrdvw_128(dst[127..0], src1[127..0], src2[127..0])
}

val avx_vpshrdvw_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpshrdvw_512(dst, src1, src2) = {
  avx_vpshrdvw_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpshrdvw_256(dst[255..0], src1[255..0], src2[255..0])
}

val avx_vpshrdvd_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpshrdvd_128(dst, src1, src2) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let lo : range(0, 96) = i * 32;
    r[(lo + 31)..lo] = avx_vpshrdd_elem(dst[(lo + 31)..lo], src1[(lo + 31)..lo], unsigned(src2[(lo + 31)..lo]));
  }; r
}

val avx_vpshrdvd_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpshrdvd_256(dst, src1, src2) = {
  avx_vpshrdvd_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpshrdvd_128(dst[127..0], src1[127..0], src2[127..0])
}

val avx_vpshrdvd_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpshrdvd_512(dst, src1, src2) = {
  avx_vpshrdvd_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpshrdvd_256(dst[255..0], src1[255..0], src2[255..0])
}

val avx_vpshrdvq_128 : (xmmword, xmmword, xmmword) -> xmmword
function avx_vpshrdvq_128(dst, src1, src2) = {
  avx_vpshrdq_elem(dst[127..64], src1[127..64], unsigned(src2[127..64])) @
  avx_vpshrdq_elem(dst[63..0], src1[63..0], unsigned(src2[63..0]))
}

val avx_vpshrdvq_256 : (ymmword, ymmword, ymmword) -> ymmword
function avx_vpshrdvq_256(dst, src1, src2) = {
  avx_vpshrdvq_128(dst[255..128], src1[255..128], src2[255..128]) @
  avx_vpshrdvq_128(dst[127..0], src1[127..0], src2[127..0])
}

val avx_vpshrdvq_512 : (zmmword, zmmword, zmmword) -> zmmword
function avx_vpshrdvq_512(dst, src1, src2) = {
  avx_vpshrdvq_256(dst[511..256], src1[511..256], src2[511..256]) @
  avx_vpshrdvq_256(dst[255..0], src1[255..0], src2[255..0])
}

// Immediate versions (VPSHLDW/D/Q imm8)

val avx_vpmultishiftqb_lane : (qword, qword) -> qword
function avx_vpmultishiftqb_lane(ctrl, src) = {
  var r : qword = zeros();
  foreach (i from 0 to 7) {
    let lo : range(0, 56) = i * 8;
    let shift : nat = unsigned(ctrl[(lo + 5)..(lo)]);
    // Extract 8 bits starting at 'shift' from src (wrapping within 64 bits)
    var byte_val : byte = zeros();
    foreach (b from 0 to 7) {
      let bit_pos : range(0, 63) = (shift + b) % 64;
      byte_val[b] = src[bit_pos];
    };
    r[(lo + 7)..lo] = byte_val;
  };
  r
}

val avx_vpmultishiftqb_128 : (xmmword, xmmword) -> xmmword
function avx_vpmultishiftqb_128(ctrl, src) = {
  avx_vpmultishiftqb_lane(ctrl[127..64], src[127..64]) @
  avx_vpmultishiftqb_lane(ctrl[63..0], src[63..0])
}

val avx_vpmultishiftqb_256 : (ymmword, ymmword) -> ymmword
function avx_vpmultishiftqb_256(ctrl, src) = {
  avx_vpmultishiftqb_128(ctrl[255..128], src[255..128]) @
  avx_vpmultishiftqb_128(ctrl[127..0], src[127..0])
}

val avx_vpmultishiftqb_512 : (zmmword, zmmword) -> zmmword
function avx_vpmultishiftqb_512(ctrl, src) = {
  avx_vpmultishiftqb_256(ctrl[511..256], src[511..256]) @
  avx_vpmultishiftqb_256(ctrl[255..0], src[255..0])
}

/* ---- VPSHUFBITQMB: shuffle bits to mask (BITALG) ---- */
// For each byte in src1, use it as an index to select a bit from the
// corresponding qword lane of src2. The selected bit goes to kmask.

val dispatch_evex_arith : (range(0, 255), Prefixes) -> unit
function dispatch_evex_arith(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {
  // 0F38 26: VPTESTMB (66, W=0) / VPTESTMW (66, W=1) / VPTESTNMB (F3, W=0) / VPTESTNMW (F3, W=1)
  38 => {
    let modrm = fetch_byte();
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_negate = mp == MP_F3;
    if mp != MP_66 & mp != MP_F3 then raise_UD();
    if pfx.rex_w then {
      // VPTESTMW / VPTESTNMW (word)
      match pfx.evex_ll {
        2 => {
          let src1 = read_zmm(pfx.evex_vvvvv);
          let src2 = evex_src_zmm(modrm, rm, pfx);
          let mask : dword = if is_negate then avx_ptestnmw_512(src1, src2) else avx_ptestmw_512(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        1 => {
          let src1 = read_ymm(pfx.evex_vvvvv);
          let src2 = evex_src_ymm(modrm, rm, pfx);
          let mask : word = if is_negate then avx_ptestnmw_256(src1, src2) else avx_ptestmw_256(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        _ => {
          let src1 = read_xmm(pfx.evex_vvvvv);
          let src2 = evex_src_xmm(modrm, rm, pfx);
          let mask : byte = if is_negate then avx_ptestnmw_128(src1, src2) else avx_ptestmw_128(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
      }
    } else {
      // VPTESTMB / VPTESTNMB (byte)
      match pfx.evex_ll {
        2 => {
          let src1 = read_zmm(pfx.evex_vvvvv);
          let src2 = evex_src_zmm(modrm, rm, pfx);
          let mask : qword = if is_negate then avx_ptestnmb_512(src1, src2) else avx_ptestmb_512(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then mask else mask & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        1 => {
          let src1 = read_ymm(pfx.evex_vvvvv);
          let src2 = evex_src_ymm(modrm, rm, pfx);
          let mask : dword = if is_negate then avx_ptestnmb_256(src1, src2) else avx_ptestmb_256(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        _ => {
          let src1 = read_xmm(pfx.evex_vvvvv);
          let src2 = evex_src_xmm(modrm, rm, pfx);
          let mask : word = if is_negate then avx_ptestnmb_128(src1, src2) else avx_ptestmb_128(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
      }
    }
  },

  // 0F38 27: VPTESTMD (66, W=0) / VPTESTMQ (66, W=1) / VPTESTNMD (F3, W=0) / VPTESTNMQ (F3, W=1)
  // 0F38 27: VPTESTMD (66, W=0) / VPTESTMQ (66, W=1) / VPTESTNMD (F3, W=0) / VPTESTNMQ (F3, W=1)
  39 => {
    let modrm = fetch_byte();
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let is_negate = mp == MP_F3;
    if mp != MP_66 & mp != MP_F3 then raise_UD();
    if pfx.rex_w then {
      // VPTESTMQ / VPTESTNMQ (qword, m64bcst)
      match pfx.evex_ll {
        2 => {
          let src1 = read_zmm(pfx.evex_vvvvv);
          let src2 = evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem);
          let mask : byte = if is_negate then avx_ptestnmq_512(src1, src2) else avx_ptestmq_512(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        1 => {
          let src1 = read_ymm(pfx.evex_vvvvv);
          let src2 = evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem);
          let mask : byte = if is_negate then avx_ptestnmq_256(src1, src2) else avx_ptestmq_256(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        _ => {
          let src1 = read_xmm(pfx.evex_vvvvv);
          let src2 = evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem);
          let mask : byte = if is_negate then avx_ptestnmq_128(src1, src2) else avx_ptestmq_128(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
      }
    } else {
      // VPTESTMD / VPTESTNMD (dword, m32bcst)
      match pfx.evex_ll {
        2 => {
          let src1 = read_zmm(pfx.evex_vvvvv);
          let src2 = evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem);
          let mask : word = if is_negate then avx_ptestnmd_512(src1, src2) else avx_ptestmd_512(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        1 => {
          let src1 = read_ymm(pfx.evex_vvvvv);
          let src2 = evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem);
          let mask : byte = if is_negate then avx_ptestnmd_256(src1, src2) else avx_ptestmd_256(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        _ => {
          let src1 = read_xmm(pfx.evex_vvvvv);
          let src2 = evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem);
          let mask : byte = if is_negate then avx_ptestnmd_128(src1, src2) else avx_ptestmd_128(src1, src2);
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
      }
    }
  },

  // 0F38 29: VPCMPEQQ (66,W1) [F] / VPMOVB2M (F3,W0) / VPMOVW2M (F3,W1) [BW]
  // 0F38 29: VPCMPEQQ (66,W1) [F] / VPMOVB2M (F3,W0) / VPMOVW2M (F3,W1) [BW]
  41 => {
    if mp == MP_F3 then {
      // VPMOVB2M (W0) / VPMOVW2M (W1): vector -> mask register
      let modrm = fetch_byte();
      let dst_k : kreg_idx = unsigned(modrm[5..3]);
      let src_idx = evex_rm_reg_idx(modrm, pfx);
      if pfx.rex_w then {
        // VPMOVW2M k1, xmm2/ymm2/zmm2
        match pfx.evex_ll {
          2 => write_kreg(dst_k, avx_vpmovw2m_512(read_zmm(src_idx))),
          1 => write_kreg(dst_k, avx_vpmovw2m_256(read_ymm(src_idx))),
          _ => write_kreg(dst_k, avx_vpmovw2m_128(read_xmm(src_idx))),
        }
      } else {
        // VPMOVB2M k1, xmm2/ymm2/zmm2
        match pfx.evex_ll {
          2 => write_kreg(dst_k, avx_vpmovb2m_512(read_zmm(src_idx))),
          1 => write_kreg(dst_k, avx_vpmovb2m_256(read_ymm(src_idx))),
          _ => write_kreg(dst_k, avx_vpmovb2m_128(read_xmm(src_idx))),
        }
      }
    } else if mp == MP_66 then {
      let modrm = fetch_byte();
      let dst_k : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      match pfx.evex_ll {
        2 => {
          let src1 = read_zmm(pfx.evex_vvvvv);
          let src2 = evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem);
          var mask : byte = 0x00;
          foreach (i from 0 to 7) {
            let lo : range(0, 448) = i * 64;
            if src1[(lo + 63)..lo] == src2[(lo + 63)..lo] then mask = mask | to_bits(8, pow2(i));
          };
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        1 => {
          let src1 = read_ymm(pfx.evex_vvvvv);
          let src2 = evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem);
          var mask : byte = 0x00;
          foreach (i from 0 to 3) {
            let lo : range(0, 192) = i * 64;
            if src1[(lo + 63)..lo] == src2[(lo + 63)..lo] then mask = mask | to_bits(8, pow2(i));
          };
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
        _ => {
          let src1 = read_xmm(pfx.evex_vvvvv);
          let src2 = evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem);
          var mask : byte = 0x00;
          foreach (i from 0 to 1) {
            let lo : range(0, 64) = i * 64;
            if src1[(lo + 63)..lo] == src2[(lo + 63)..lo] then mask = mask | to_bits(8, pow2(i));
          };
          let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
          write_kreg(dst_k, k_mask)
        },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 37: VPCMPGTQ (66,W1) [F]
  // 0F38 37: VPCMPGTQ (66,W1) [F]
  55 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst_k : range(0, 7) = unsigned(modrm[5..3]);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    match pfx.evex_ll {
      2 => {
        let src1 = read_zmm(pfx.evex_vvvvv);
        let src2 = evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem);
        var mask : byte = 0x00;
        foreach (i from 0 to 7) {
          let lo : range(0, 448) = i * 64;
          mask[i] = cmp_gt64(src1[(lo + 63)..lo], src2[(lo + 63)..lo])[0];
        };
        let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
        write_kreg(dst_k, k_mask)
      },
      1 => {
        let src1 = read_ymm(pfx.evex_vvvvv);
        let src2 = evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem);
        var mask : byte = 0x00;
        foreach (i from 0 to 3) {
          let lo : range(0, 192) = i * 64;
          mask[i] = cmp_gt64(src1[(lo + 63)..lo], src2[(lo + 63)..lo])[0];
        };
        let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
        write_kreg(dst_k, k_mask)
      },
      _ => {
        let src1 = read_xmm(pfx.evex_vvvvv);
        let src2 = evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem);
        var mask : byte = 0x00;
        foreach (i from 0 to 1) {
          let lo : range(0, 64) = i * 64;
          mask[i] = cmp_gt64(src1[(lo + 63)..lo], src2[(lo + 63)..lo])[0];
        };
        let k_mask : qword = if pfx.evex_aaa == 0 then zero_extend(mask) else zero_extend(mask) & read_kreg(pfx.evex_aaa);
        write_kreg(dst_k, k_mask)
      },
    }
  },

  // 0F38 38: VPMINSB (66) [BW] / VPMOVM2D (F3,W0) / VPMOVM2Q (F3,W1) [DQ]
  // 0F38 38: VPMINSB (66) [BW] / VPMOVM2D (F3,W0) / VPMOVM2Q (F3,W1) [DQ]
  56 => {
    if mp == MP_66 then {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_pminsb_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))),
        1 => write_ymm(dst, avx_pminsb_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))),
        _ => write_xmm(dst, avx_pminsb_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))),
      }
    } else if mp == MP_F3 then {
      // VPMOVM2D (W0) / VPMOVM2Q (W1): mask register -> vector
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let k_idx : kreg_idx = unsigned(modrm[2..0]);
      let k_val = read_kreg(k_idx);
      if pfx.rex_w then {
        // VPMOVM2Q xmm1/ymm1/zmm1, k1
        match pfx.evex_ll {
          2 => write_zmm(dst, avx_vpmovm2q_512(k_val)),
          1 => write_ymm(dst, avx_vpmovm2q_256(k_val)),
          _ => write_xmm(dst, avx_vpmovm2q_128(k_val)),
        }
      } else {
        // VPMOVM2D xmm1/ymm1/zmm1, k1
        match pfx.evex_ll {
          2 => write_zmm(dst, avx_vpmovm2d_512(k_val)),
          1 => write_ymm(dst, avx_vpmovm2d_256(k_val)),
          _ => write_xmm(dst, avx_vpmovm2d_128(k_val)),
        }
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 39: VPMINSD (66,W0) / VPMINSQ (66,W1) [F] / VPMOVD2M (F3,W0) / VPMOVQ2M (F3,W1) [DQ]
  // 0F38 39: VPMINSD (66,W0) / VPMINSQ (66,W1) [F] / VPMOVD2M (F3,W0) / VPMOVQ2M (F3,W1) [DQ]
  57 => {
    if mp == MP_66 then {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      let src1_idx = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPMINSQ
        match pfx.evex_ll {
          2 => write_zmm(dst, avx_pminsq_512(read_zmm(src1_idx), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem))),
          1 => write_ymm(dst, avx_pminsq_256(read_ymm(src1_idx), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem))),
          _ => write_xmm(dst, avx_pminsq_128(read_xmm(src1_idx), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))),
        }
      } else { // VPMINSD
        match pfx.evex_ll {
          2 => write_zmm(dst, avx_pminsd_512(read_zmm(src1_idx), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
          1 => write_ymm(dst, avx_pminsd_256(read_ymm(src1_idx), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
          _ => write_xmm(dst, avx_pminsd_128(read_xmm(src1_idx), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
        }
      }
    } else if mp == MP_F3 then {
      // VPMOVD2M (W0) / VPMOVQ2M (W1): vector -> mask register
      let modrm = fetch_byte();
      let dst_k : kreg_idx = unsigned(modrm[5..3]);
      let src_idx = evex_rm_reg_idx(modrm, pfx);
      if pfx.rex_w then {
        // VPMOVQ2M k1, xmm2/ymm2/zmm2
        match pfx.evex_ll {
          2 => write_kreg(dst_k, avx_vpmovq2m_512(read_zmm(src_idx))),
          1 => write_kreg(dst_k, avx_vpmovq2m_256(read_ymm(src_idx))),
          _ => write_kreg(dst_k, avx_vpmovq2m_128(read_xmm(src_idx))),
        }
      } else {
        // VPMOVD2M k1, xmm2/ymm2/zmm2
        match pfx.evex_ll {
          2 => write_kreg(dst_k, avx_vpmovd2m_512(read_zmm(src_idx))),
          1 => write_kreg(dst_k, avx_vpmovd2m_256(read_ymm(src_idx))),
          _ => write_kreg(dst_k, avx_vpmovd2m_128(read_xmm(src_idx))),
        }
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 3A: VPBROADCASTMW2D (F3,W0) [CD]
  // 0F38 3B: VPMINUD (66, W=0) / VPMINUQ (66, W=1)
  59 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    if pfx.rex_w then {
      // VPMINUQ (m64bcst)
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_pminuq_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_pminuq_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_pminuq_128(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))),
      }
    } else {
      // VPMINUD (m32bcst)
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_pminud_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_pminud_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_pminud_128(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
      }
    }
  },

  // 0F38 2B: VPACKUSDW (66,W0) [BW]
  // 0F38 2B: VPACKUSDW (66,W0) [BW]
  43 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_packusdw_512(read_zmm(src1_idx), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
      1 => write_ymm(dst, avx_packusdw_256(read_ymm(src1_idx), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
      _ => write_xmm(dst, avx_packusdw_128(read_xmm(src1_idx), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
    }
  },

  // 0F38 3C: VPMAXSB (66) [BW]
  // 0F38 3C: VPMAXSB (66) [BW]
  60 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let src1_idx = pfx.evex_vvvvv;
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_pmaxsb_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))),
      1 => write_ymm(dst, avx_pmaxsb_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))),
      _ => write_xmm(dst, avx_pmaxsb_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))),
    }
  },

  // 0F38 3D: VPMAXSD (66,W0) / VPMAXSQ (66,W1) [F]
  // 0F38 3D: VPMAXSD (66,W0) / VPMAXSQ (66,W1) [F]
  61 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    if pfx.rex_w then { // VPMAXSQ
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_pmaxsq_512(read_zmm(src1_idx), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_pmaxsq_256(read_ymm(src1_idx), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_pmaxsq_128(read_xmm(src1_idx), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))),
      }
    } else { // VPMAXSD
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_pmaxsd_512(read_zmm(src1_idx), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_pmaxsd_256(read_ymm(src1_idx), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_pmaxsd_128(read_xmm(src1_idx), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
      }
    }
  },

  // 0F38 3E: VPMAXUW (66) [BW]
  // 0F38 3E: VPMAXUW (66) [BW]
  62 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let src1_idx = pfx.evex_vvvvv;
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_pmaxuw_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))),
      1 => write_ymm(dst, avx_pmaxuw_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))),
      _ => write_xmm(dst, avx_pmaxuw_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))),
    }
  },

  // 0F38 3F: VPMAXUD (66,W0) / VPMAXUQ (66,W1) [F]
  // 0F38 3F: VPMAXUD (66,W0) / VPMAXUQ (66,W1) [F]
  63 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    if pfx.rex_w then { // VPMAXUQ
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_pmaxuq_512(read_zmm(src1_idx), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_pmaxuq_256(read_ymm(src1_idx), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_pmaxuq_128(read_xmm(src1_idx), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))),
      }
    } else { // VPMAXUD
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_pmaxud_512(read_zmm(src1_idx), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_pmaxud_256(read_ymm(src1_idx), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_pmaxud_128(read_xmm(src1_idx), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
      }
    }
  },

  // 0F38 7A: VPBROADCASTB from GPR (66, W=0)
  // r/m field selects a GPR (mod=11 always for this opcode)
  // 0F38 04: VPMADDUBSW (66) [BW]
  4 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let src1_idx = pfx.evex_vvvvv;
    match pfx.evex_ll {
      2 => {
        write_zmm(dst, avx_pmaddubsw_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx)))
      },
      1 => {
        write_ymm(dst, avx_pmaddubsw_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx)))
      },
      _ => {
        write_xmm(dst, avx_pmaddubsw_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx)))
      },
    }
  },

  // 0F38 0B: VPMULHRSW (66) [BW]
  // 0F38 0B: VPMULHRSW (66) [BW]
  11 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let src1_idx = pfx.evex_vvvvv;
    match pfx.evex_ll {
      2 => {
        write_zmm(dst, avx_pmulhrsw_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx)))
      },
      1 => {
        write_ymm(dst, avx_pmulhrsw_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx)))
      },
      _ => {
        write_xmm(dst, avx_pmulhrsw_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx)))
      },
    }
  },

  // 0F38 28: VPMULDQ (66,W1) [F] / VPMOVM2B (F3,W0) / VPMOVM2W (F3,W1) [BW]
  // 0F38 28: VPMULDQ (66,W1) [F] / VPMOVM2B (F3,W0) / VPMOVM2W (F3,W1) [BW]
  40 => {
    if mp == MP_66 then {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => {
          write_zmm(dst, avx_pmuldq_512(read_zmm(src1_idx), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem)))
        },
        1 => {
          write_ymm(dst, avx_pmuldq_256(read_ymm(src1_idx), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem)))
        },
        _ => {
          write_xmm(dst, avx_pmuldq_128(read_xmm(src1_idx), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem)))
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVM2B (W0) / VPMOVM2W (W1): mask register -> vector
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let k_idx : kreg_idx = unsigned(modrm[2..0]);
      let k_val = read_kreg(k_idx);
      if pfx.rex_w then {
        // VPMOVM2W xmm1/ymm1/zmm1, k1
        match pfx.evex_ll {
          2 => write_zmm(dst, avx_vpmovm2w_512(k_val)),
          1 => write_ymm(dst, avx_vpmovm2w_256(k_val)),
          _ => write_xmm(dst, avx_vpmovm2w_128(k_val)),
        }
      } else {
        // VPMOVM2B xmm1/ymm1/zmm1, k1
        match pfx.evex_ll {
          2 => write_zmm(dst, avx_vpmovm2b_512(k_val)),
          1 => write_ymm(dst, avx_vpmovm2b_256(k_val)),
          _ => write_xmm(dst, avx_vpmovm2b_128(k_val)),
        }
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 40: VPMULLD (66,W0) / VPMULLQ (66,W1) [F/DQ]
  // 0F38 40: VPMULLD (66,W0) / VPMULLQ (66,W1) [F/DQ]
  64 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    if pfx.rex_w then { // VPMULLQ
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_pmullq_512(read_zmm(src1_idx), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_pmullq_256(read_ymm(src1_idx), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_pmullq_128(read_xmm(src1_idx), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))),
      }
    } else { // VPMULLD
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_pmulld_512(read_zmm(src1_idx), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_pmulld_256(read_ymm(src1_idx), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_pmulld_128(read_xmm(src1_idx), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
      }
    }
  },

  // 0F38 1C: VPABSB (66) [BW]
  // 0F38 1C: VPABSB (66) [BW]
  28 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_pabsb_512(evex_src_zmm(modrm, rm, pfx))),
      1 => write_ymm(dst, avx_pabsb_256(evex_src_ymm(modrm, rm, pfx))),
      _ => write_xmm(dst, avx_pabsb_128(evex_src_xmm(modrm, rm, pfx))),
    }
  },

  // 0F38 1D: VPABSW (66) [BW]
  // 0F38 1D: VPABSW (66) [BW]
  29 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_pabsw_512(evex_src_zmm(modrm, rm, pfx))),
      1 => write_ymm(dst, avx_pabsw_256(evex_src_ymm(modrm, rm, pfx))),
      _ => write_xmm(dst, avx_pabsw_128(evex_src_xmm(modrm, rm, pfx))),
    }
  },

  // 0F38 1E: VPABSD (66,W0) [F]
  // 0F38 1E: VPABSD (66,W0) [F]
  30 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_pabsd_512(evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
      1 => write_ymm(dst, avx_pabsd_256(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
      _ => write_xmm(dst, avx_pabsd_128(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
    }
  },

  // 0F38 1F: VPABSQ (66,W1) [F]
  // 0F38 1F: VPABSQ (66,W1) [F]
  31 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_pabsq_512(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem))),
      1 => write_ymm(dst, avx_pabsq_256(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem))),
      _ => write_xmm(dst, avx_pabsq_128(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))),
    }
  },

  // 0F38 10: VPSRLVW (66,W1) [BW] / VPMOVUSWB (F3) [BW]
  // 0F38 10: VPSRLVW (66,W1) [BW] / VPMOVUSWB (F3) [BW]
  16 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_psrlvw_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))),
        1 => write_ymm(dst, avx_psrlvw_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))),
        _ => write_xmm(dst, avx_psrlvw_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))),
      }
    } else if mp == MP_F3 then {
      // VPMOVUSWB: src=reg, dst=r/m (narrowing: word->byte)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovuswb_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => write_ymm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res) } } },
        1 => { let res = avx_pmovuswb_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res) } } },
        _ => { let res = avx_pmovuswb_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 11: VPSRAVW (66,W1) [BW] / VPMOVUSDB (F3) [F]
  // 0F38 11: VPSRAVW (66,W1) [BW] / VPMOVUSDB (F3) [F]
  17 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_psravw_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))),
        1 => write_ymm(dst, avx_psravw_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))),
        _ => write_xmm(dst, avx_psravw_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))),
      }
    } else if mp == MP_F3 then {
      // VPMOVUSDB: src=reg, dst=r/m (narrowing: dword->byte)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovusdb_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res) } } },
        1 => { let res = avx_pmovusdb_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
        _ => { let res = avx_pmovusdb_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 4);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write32(fixup_addr(addr), res) } } },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 12: VPSLLVW (66,W1) [BW] / VPMOVUSQB (F3) [F]
  // 0F38 12: VPSLLVW (66,W1) [BW] / VPMOVUSQB (F3) [F]
  18 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let src1_idx = pfx.evex_vvvvv;
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_psllvw_512(read_zmm(src1_idx), evex_src_zmm(modrm, rm, pfx))),
        1 => write_ymm(dst, avx_psllvw_256(read_ymm(src1_idx), evex_src_ymm(modrm, rm, pfx))),
        _ => write_xmm(dst, avx_psllvw_128(read_xmm(src1_idx), evex_src_xmm(modrm, rm, pfx))),
      }
    } else if mp == MP_F3 then {
      // VPMOVUSQB: src=reg, dst=r/m (narrowing: qword->byte)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovusqb_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
        1 => { let res = avx_pmovusqb_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 4);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write32(fixup_addr(addr), res) } } },
        _ => { let res = avx_pmovusqb_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 2);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write16(fixup_addr(addr), res) } } },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 13: VCVTPH2PS (66,W0) [F] / VPMOVUSDW (F3) [F]
  // 0F38 13: VCVTPH2PS (66,W0) [F] / VPMOVUSDW (F3) [F]
  19 => {
    if mp == MP_66 then {
      // VCVTPH2PS: convert packed FP16 (half width) to FP32
      if pfx.rex_w then raise_UD();
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let rm = decode_rm_evex(modrm, pfx, 32);
               let src = evex_src_ymm(modrm, rm, pfx);
               write_zmm(dst, avx_vcvtph2ps_512(src)) },
        1 => { let rm = decode_rm_evex(modrm, pfx, 16);
               let src_x = evex_src_xmm(modrm, rm, pfx);
               write_ymm(dst, avx_vcvtph2ps_256(src_x)) },
        _ => { let rm = decode_rm_evex(modrm, pfx, 8);
               let src_q = evex_src_xmm(modrm, rm, pfx);
               write_xmm(dst, avx_vcvtph2ps_128(src_q[63..0])) },
      }
    } else if mp == MP_F3 then {
      let modrm = fetch_byte();
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovusdw_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => write_ymm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res) } } },
        1 => { let res = avx_pmovusdw_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res) } } },
        _ => { let res = avx_pmovusdw_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 14: VPRORVD (66,W0) / VPRORVQ (66,W1) [F] / VPMOVUSQW (F3) [F]
  // 0F38 14: VPRORVD (66,W0) / VPRORVQ (66,W1) [F] / VPMOVUSQW (F3) [F]
  20 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      let src1_idx = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPRORVQ
        match pfx.evex_ll {
          2 => write_zmm(dst, avx_prorvq_512(read_zmm(src1_idx), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem))),
          1 => write_ymm(dst, avx_prorvq_256(read_ymm(src1_idx), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem))),
          _ => write_xmm(dst, avx_prorvq_128(read_xmm(src1_idx), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))),
        }
      } else { // VPRORVD
        match pfx.evex_ll {
          2 => write_zmm(dst, avx_prorvd_512(read_zmm(src1_idx), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
          1 => write_ymm(dst, avx_prorvd_256(read_ymm(src1_idx), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
          _ => write_xmm(dst, avx_prorvd_128(read_xmm(src1_idx), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
        }
      }
    } else if mp == MP_F3 then {
      // VPMOVUSQW: src=reg, dst=r/m (narrowing: qword->word)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovusqw_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res) } } },
        1 => { let res = avx_pmovusqw_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
        _ => { let res = avx_pmovusqw_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 4);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write32(fixup_addr(addr), res) } } },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 15: VPROLVD (66,W0) / VPROLVQ (66,W1) [F] / VPMOVUSQD (F3) [F]
  // 0F38 15: VPROLVD (66,W0) / VPROLVQ (66,W1) [F] / VPMOVUSQD (F3) [F]
  21 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      let src1_idx = pfx.evex_vvvvv;
      if pfx.rex_w then { // VPROLVQ
        match pfx.evex_ll {
          2 => write_zmm(dst, avx_prolvq_512(read_zmm(src1_idx), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem))),
          1 => write_ymm(dst, avx_prolvq_256(read_ymm(src1_idx), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem))),
          _ => write_xmm(dst, avx_prolvq_128(read_xmm(src1_idx), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))),
        }
      } else { // VPROLVD
        match pfx.evex_ll {
          2 => write_zmm(dst, avx_prolvd_512(read_zmm(src1_idx), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
          1 => write_ymm(dst, avx_prolvd_256(read_ymm(src1_idx), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
          _ => write_xmm(dst, avx_prolvd_128(read_xmm(src1_idx), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
        }
      }
    } else if mp == MP_F3 then {
      // VPMOVUSQD: src=reg, dst=r/m (narrowing: qword->dword)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovusqd_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => write_ymm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res) } } },
        1 => { let res = avx_pmovusqd_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res) } } },
        _ => { let res = avx_pmovusqd_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 20: VPMOVSXBW (66) [BW] / VPMOVSWB (F3) [BW]
  // 0F38 20: VPMOVSXBW (66) [BW] / VPMOVSWB (F3) [BW]
  32 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 32);
          let src : ymmword = match rm {
            RM_reg(_) => read_ymm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read256(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovsxbw_512(src))
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovsxbw_256(src))
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovsxbw_128(src))
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVSWB: src=reg, dst=r/m (narrowing: word->byte, signed saturation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovswb_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => write_ymm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res) } } },
        1 => { let res = avx_pmovswb_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res) } } },
        _ => { let res = avx_pmovswb_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 21: VPMOVSXBD (66) [F] / VPMOVSDB (F3) [F]
  // 0F38 21: VPMOVSXBD (66) [F] / VPMOVSDB (F3) [F]
  33 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovsxbd_512(src))
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovsxbd_256(src))
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 4);
          let src : dword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
            RM_mem(addr) => mem_read32(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovsxbd_128(src))
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVSDB: src=reg, dst=r/m (narrowing: dword->byte, signed saturation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovsdb_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res) } } },
        1 => { let res = avx_pmovsdb_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
        _ => { let res = avx_pmovsdb_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 4);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write32(fixup_addr(addr), res) } } },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 22: VPMOVSXBQ (66) [F] / VPMOVSQB (F3) [F]
  // 0F38 22: VPMOVSXBQ (66) [F] / VPMOVSQB (F3) [F]
  34 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovsxbq_512(src))
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 4);
          let src : dword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
            RM_mem(addr) => mem_read32(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovsxbq_256(src))
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 2);
          let src : word = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(addr) => mem_read16(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovsxbq_128(src))
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVSQB: src=reg, dst=r/m (narrowing: qword->byte, signed saturation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovsqb_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
        1 => { let res = avx_pmovsqb_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 4);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write32(fixup_addr(addr), res) } } },
        _ => { let res = avx_pmovsqb_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 2);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write16(fixup_addr(addr), res) } } },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 23: VPMOVSXWD (66) [F] / VPMOVSDW (F3) [F]
  // 0F38 23: VPMOVSXWD (66) [F] / VPMOVSDW (F3) [F]
  35 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 32);
          let src : ymmword = match rm {
            RM_reg(_) => read_ymm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read256(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovsxwd_512(src))
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovsxwd_256(src))
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovsxwd_128(src))
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVSDW: src=reg, dst=r/m (narrowing: dword->word, signed saturation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovsdw_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => write_ymm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res) } } },
        1 => { let res = avx_pmovsdw_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res) } } },
        _ => { let res = avx_pmovsdw_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 24: VPMOVSXWQ (66) [F] / VPMOVSQW (F3) [F]
  // 0F38 24: VPMOVSXWQ (66) [F] / VPMOVSQW (F3) [F]
  36 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovsxwq_512(src))
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovsxwq_256(src))
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 4);
          let src : dword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
            RM_mem(addr) => mem_read32(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovsxwq_128(src))
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVSQW: src=reg, dst=r/m (narrowing: qword->word, signed saturation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovsqw_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res) } } },
        1 => { let res = avx_pmovsqw_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
        _ => { let res = avx_pmovsqw_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 4);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write32(fixup_addr(addr), res) } } },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 25: VPMOVSXDQ (66) [F] / VPMOVSQD (F3) [F]
  // 0F38 25: VPMOVSXDQ (66) [F] / VPMOVSQD (F3) [F]
  37 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 32);
          let src : ymmword = match rm {
            RM_reg(_) => read_ymm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read256(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovsxdq_512(src))
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovsxdq_256(src))
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovsxdq_128(src))
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVSQD: src=reg, dst=r/m (narrowing: qword->dword, signed saturation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovsqd_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => write_ymm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res) } } },
        1 => { let res = avx_pmovsqd_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res) } } },
        _ => { let res = avx_pmovsqd_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 30: VPMOVZXBW (66) [BW] / VPMOVWB (F3) [BW]
  // 0F38 30: VPMOVZXBW (66) [BW] / VPMOVWB (F3) [BW]
  48 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 32);
          let src : ymmword = match rm {
            RM_reg(_) => read_ymm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read256(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovzxbw_512(src))
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovzxbw_256(src))
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovzxbw_128(src))
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVWB: src=reg, dst=r/m (narrowing: word->byte, truncation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovwb_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => write_ymm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res) } } },
        1 => { let res = avx_pmovwb_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res) } } },
        _ => { let res = avx_pmovwb_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 31: VPMOVZXBD (66) [F] / VPMOVDB (F3) [F]
  // 0F38 31: VPMOVZXBD (66) [F] / VPMOVDB (F3) [F]
  49 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovzxbd_512(src))
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovzxbd_256(src))
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 4);
          let src : dword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
            RM_mem(addr) => mem_read32(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovzxbd_128(src))
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVDB: src=reg, dst=r/m (narrowing: dword->byte, truncation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovdb_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res) } } },
        1 => { let res = avx_pmovdb_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
        _ => { let res = avx_pmovdb_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 4);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write32(fixup_addr(addr), res) } } },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 32: VPMOVZXBQ (66) [F] / VPMOVQB (F3) [F]
  // 0F38 32: VPMOVZXBQ (66) [F] / VPMOVQB (F3) [F]
  50 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovzxbq_512(src))
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 4);
          let src : dword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
            RM_mem(addr) => mem_read32(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovzxbq_256(src))
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 2);
          let src : word = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(addr) => mem_read16(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovzxbq_128(src))
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVQB: src=reg, dst=r/m (narrowing: qword->byte, truncation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovqb_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
        1 => { let res = avx_pmovqb_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 4);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write32(fixup_addr(addr), res) } } },
        _ => { let res = avx_pmovqb_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 2);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write16(fixup_addr(addr), res) } } },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 33: VPMOVZXWD (66) [F] / VPMOVDW (F3) [F]
  // 0F38 33: VPMOVZXWD (66) [F] / VPMOVDW (F3) [F]
  51 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 32);
          let src : ymmword = match rm {
            RM_reg(_) => read_ymm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read256(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovzxwd_512(src))
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovzxwd_256(src))
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovzxwd_128(src))
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVDW: src=reg, dst=r/m (narrowing: dword->word, truncation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovdw_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => write_ymm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res) } } },
        1 => { let res = avx_pmovdw_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res) } } },
        _ => { let res = avx_pmovdw_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 34: VPMOVZXWQ (66) [F] / VPMOVQW (F3) [F]
  // 0F38 34: VPMOVZXWQ (66) [F] / VPMOVQW (F3) [F]
  52 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovzxwq_512(src))
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovzxwq_256(src))
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 4);
          let src : dword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
            RM_mem(addr) => mem_read32(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovzxwq_128(src))
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVQW: src=reg, dst=r/m (narrowing: qword->word, truncation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovqw_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res) } } },
        1 => { let res = avx_pmovqw_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
        _ => { let res = avx_pmovqw_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 4);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write32(fixup_addr(addr), res) } } },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 45: VPSRLVD (66,W0) / VPSRLVQ (66,W1) [F]
  // 0F38 45: VPSRLVD (66,W0) / VPSRLVQ (66,W1) [F]
  69 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    if pfx.rex_w then { // VPSRLVQ
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_psrlvq_512(read_zmm(src1_idx), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_psrlvq_256(read_ymm(src1_idx), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_psrlvq_128(read_xmm(src1_idx), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))),
      }
    } else { // VPSRLVD
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_psrlvd_512(read_zmm(src1_idx), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_psrlvd_256(read_ymm(src1_idx), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_psrlvd_128(read_xmm(src1_idx), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
      }
    }
  },

  // 0F38 46: VPSRAVD (66,W0) / VPSRAVQ (66,W1) [F]
  // 0F38 46: VPSRAVD (66,W0) / VPSRAVQ (66,W1) [F]
  70 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    if pfx.rex_w then { // VPSRAVQ
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_psravq_512(read_zmm(src1_idx), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_psravq_256(read_ymm(src1_idx), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_psravq_128(read_xmm(src1_idx), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))),
      }
    } else { // VPSRAVD
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_psravd_512(read_zmm(src1_idx), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_psravd_256(read_ymm(src1_idx), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_psravd_128(read_xmm(src1_idx), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
      }
    }
  },

  // 0F38 47: VPSLLVD (66,W0) / VPSLLVQ (66,W1) [F]
  // 0F38 47: VPSLLVD (66,W0) / VPSLLVQ (66,W1) [F]
  71 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    let src1_idx = pfx.evex_vvvvv;
    if pfx.rex_w then { // VPSLLVQ
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_psllvq_512(read_zmm(src1_idx), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_psllvq_256(read_ymm(src1_idx), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_psllvq_128(read_xmm(src1_idx), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))),
      }
    } else { // VPSLLVD
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_psllvd_512(read_zmm(src1_idx), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_psllvd_256(read_ymm(src1_idx), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_psllvd_128(read_xmm(src1_idx), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
      }
    }
  },

  // 0F38 35: VPMOVZXDQ (66) [F] / VPMOVQD (F3) [F]
  53 => {
    let modrm = fetch_byte();
    if mp == MP_66 then {
      let dst = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => {
          let rm = decode_rm_evex(modrm, pfx, 32);
          let src : ymmword = match rm {
            RM_reg(_) => read_ymm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read256(fixup_addr(addr)),
          };
          write_zmm(dst, avx_pmovzxdq_512(src))
        },
        1 => {
          let rm = decode_rm_evex(modrm, pfx, 16);
          let src : xmmword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
            RM_mem(addr) => mem_read128(fixup_addr(addr)),
          };
          write_ymm(dst, avx_pmovzxdq_256(src))
        },
        _ => {
          let rm = decode_rm_evex(modrm, pfx, 8);
          let src : qword = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
            RM_mem(addr) => mem_read64(fixup_addr(addr)),
          };
          write_xmm(dst, avx_pmovzxdq_128(src))
        },
      }
    } else if mp == MP_F3 then {
      // VPMOVQD: src=reg, dst=r/m (narrowing: qword->dword, truncation)
      let src = evex_reg_idx(modrm, pfx);
      match pfx.evex_ll {
        2 => { let res = avx_pmovqd_512(read_zmm(src));
               let rm = decode_rm_evex(modrm, pfx, 32);
               match rm { RM_reg(_) => write_ymm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write256(fixup_addr(addr), res) } } },
        1 => { let res = avx_pmovqd_256(read_ymm(src));
               let rm = decode_rm_evex(modrm, pfx, 16);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), res),
                           RM_mem(addr) => { mem_write128(fixup_addr(addr), res) } } },
        _ => { let res = avx_pmovqd_128(read_xmm(src));
               let rm = decode_rm_evex(modrm, pfx, 8);
               match rm { RM_reg(_) => write_xmm(evex_rm_reg_idx(modrm, pfx), zero_extend(res)),
                           RM_mem(addr) => { mem_write64(fixup_addr(addr), res) } } },
      }
    } else {
      raise_UD()
    }
  },

  // 0F38 7D: VPERMT2W (66,W1) [BW] / VPERMT2B (66,W0) [VBMI]
  // 0F38 70: VPSHLDVW (66, W=1) [VBMI2]
  112 => {
    if mp != MP_66 | not_bool(pfx.rex_w) then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_vpshldvw_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))),
      1 => write_ymm(dst, avx_vpshldvw_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))),
      _ => write_xmm(dst, avx_vpshldvw_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))),
    }
  },

  // 0F38 71: VPSHLDVD (66, W=0) / VPSHLDVQ (66, W=1) [VBMI2]
  // 0F38 71: VPSHLDVD (66, W=0) / VPSHLDVQ (66, W=1) [VBMI2]
  113 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    if pfx.rex_w then {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vpshldvq_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_vpshldvq_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_vpshldvq_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))),
      }
    } else {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vpshldvd_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_vpshldvd_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_vpshldvd_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
      }
    }
  },

  // 0F38 72: VPSHRDVW (66,W1) / VCVTNE2PS2BF16 (F2,W0) / VCVTNEPS2BF16 (F3,W0)
  114 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    match mp {
      MP_66 => {
        // VPSHRDVW (W=1 required)
        if not_bool(pfx.rex_w) then raise_UD();
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        match pfx.evex_ll {
          2 => write_zmm(dst, avx_vpshrdvw_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_src_zmm(modrm, rm, pfx))),
          1 => write_ymm(dst, avx_vpshrdvw_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_src_ymm(modrm, rm, pfx))),
          _ => write_xmm(dst, avx_vpshrdvw_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_src_xmm(modrm, rm, pfx))),
        }
      },
      MP_F2 => {
        // VCVTNE2PS2BF16: convert two packed FP32 → packed BF16 (W=0)
        if pfx.rex_w then raise_UD();
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        match pfx.evex_ll {
          2 => write_zmm(dst, avx_vcvtne2ps2bf16_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
          1 => write_ymm(dst, avx_vcvtne2ps2bf16_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
          _ => write_xmm(dst, avx_vcvtne2ps2bf16_128(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
        }
      },
      MP_F3 => {
        // VCVTNEPS2BF16: convert packed FP32 → packed BF16 (W=0, vvvv must be 1111)
        if pfx.rex_w then raise_UD();
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        match pfx.evex_ll {
          2 => {
            let src = evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem);
            write_ymm(dst, avx_vcvtneps2bf16_512(src))
          },
          1 => {
            let src = evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem);
            write_xmm(dst, avx_vcvtneps2bf16_256(src))
          },
          _ => {
            let src = evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem);
            write_xmm(dst, avx_vcvtneps2bf16_128(src))
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F38 73: VPSHRDVD (66, W=0) / VPSHRDVQ (66, W=1) [VBMI2]
  // 0F38 73: VPSHRDVD (66, W=0) / VPSHRDVQ (66, W=1) [VBMI2]
  115 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    if pfx.rex_w then {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vpshrdvq_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_vpshrdvq_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_vpshrdvq_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))),
      }
    } else {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vpshrdvd_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_vpshrdvd_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_vpshrdvd_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
      }
    }
  },

  // 0F38 83: VPMULTISHIFTQB (66,W1) [VBMI]
  // 0F38 83: VPMULTISHIFTQB (66,W1) [VBMI]
  131 => {
    if mp != MP_66 | not_bool(pfx.rex_w) then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_vpmultishiftqb_512(read_zmm(pfx.evex_vvvvv), evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem))),
      1 => write_ymm(dst, avx_vpmultishiftqb_256(read_ymm(pfx.evex_vvvvv), evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem))),
      _ => write_xmm(dst, avx_vpmultishiftqb_128(read_xmm(pfx.evex_vvvvv), evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))),
    }
  },

  // 0F38 8D: VPERMW (66,W1) [BW] / VPERMB (66,W0) [VBMI]
  // 0F38 44: VPLZCNTD (66, W=0) / VPLZCNTQ (66, W=1) [CD]
  68 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    if pfx.rex_w then {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vplzcntq_512(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_vplzcntq_256(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_vplzcntq_128(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))),
      }
    } else {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vplzcntd_512(evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_vplzcntd_256(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_vplzcntd_128(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
      }
    }
  },

  // 0F38 50: VPDPBUSD (66) [VNNI]
  // 0F38 50: VPDPBUSD (66) [VNNI]
  80 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_vpdpbusd_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
      1 => write_ymm(dst, avx_vpdpbusd_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
      _ => write_xmm(dst, avx_vpdpbusd_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
    }
  },

  // 0F38 51: VPDPBUSDS (66) [VNNI]
  // 0F38 51: VPDPBUSDS (66) [VNNI]
  81 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_vpdpbusds_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
      1 => write_ymm(dst, avx_vpdpbusds_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
      _ => write_xmm(dst, avx_vpdpbusds_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
    }
  },

  // 0F38 52: VPDPWSSD (66) [VNNI] / VDPBF16PS (F3) [BF16]
  82 => {
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    match mp {
      MP_66 => {
        // VPDPWSSD xmm1/ymm1/zmm1, xmm2/ymm2/zmm2, xmm3/ymm3/zmm3/m128/m256/m512
        match pfx.evex_ll {
          2 => write_zmm(dst, avx_vpdpwssd_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
          1 => write_ymm(dst, avx_vpdpwssd_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
          _ => write_xmm(dst, avx_vpdpwssd_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
        }
      },
      MP_F3 => {
        // VDPBF16PS: BF16 dot product accumulating to FP32 (W=0)
        if pfx.rex_w then raise_UD();
        match pfx.evex_ll {
          2 => write_zmm(dst, avx_vdpbf16ps_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
          1 => write_ymm(dst, avx_vdpbf16ps_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
          _ => write_xmm(dst, avx_vdpbf16ps_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F38 53: VPDPWSSDS (66) [VNNI]
  // 0F38 53: VPDPWSSDS (66) [VNNI]
  83 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    match pfx.evex_ll {
      2 => write_zmm(dst, avx_vpdpwssds_512(read_zmm(dst), read_zmm(pfx.evex_vvvvv), evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
      1 => write_ymm(dst, avx_vpdpwssds_256(read_ymm(dst), read_ymm(pfx.evex_vvvvv), evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
      _ => write_xmm(dst, avx_vpdpwssds_128(read_xmm(dst), read_xmm(pfx.evex_vvvvv), evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
    }
  },

  // 0F38 54: VPOPCNTB (66, W=0) / VPOPCNTW (66, W=1) [BITALG]
  // 0F38 54: VPOPCNTB (66, W=0) / VPOPCNTW (66, W=1) [BITALG]
  84 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    if pfx.rex_w then {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vpopcntw_512(evex_src_zmm(modrm, rm, pfx))),
        1 => write_ymm(dst, avx_vpopcntw_256(evex_src_ymm(modrm, rm, pfx))),
        _ => write_xmm(dst, avx_vpopcntw_128(evex_src_xmm(modrm, rm, pfx))),
      }
    } else {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vpopcntb_512(evex_src_zmm(modrm, rm, pfx))),
        1 => write_ymm(dst, avx_vpopcntb_256(evex_src_ymm(modrm, rm, pfx))),
        _ => write_xmm(dst, avx_vpopcntb_128(evex_src_xmm(modrm, rm, pfx))),
      }
    }
  },

  // 0F38 55: VPOPCNTD (66, W=0) / VPOPCNTQ (66, W=1) [VPOPCNTDQ]
  // 0F38 55: VPOPCNTD (66, W=0) / VPOPCNTQ (66, W=1) [VPOPCNTDQ]
  85 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    if pfx.rex_w then {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vpopcntq_512(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_vpopcntq_256(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_vpopcntq_128(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))),
      }
    } else {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vpopcntd_512(evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_vpopcntd_256(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_vpopcntd_128(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
      }
    }
  },

  // 0F38 C4: VPCONFLICTD (66, W=0) / VPCONFLICTQ (66, W=1) [CD]
  // 0F38 C4: VPCONFLICTD (66, W=0) / VPCONFLICTQ (66, W=1) [CD]
  196 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
    let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
    if pfx.rex_w then {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vpconflictq_512(evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_vpconflictq_256(evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_vpconflictq_128(evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem))),
      }
    } else {
      match pfx.evex_ll {
        2 => write_zmm(dst, avx_vpconflictd_512(evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem))),
        1 => write_ymm(dst, avx_vpconflictd_256(evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem))),
        _ => write_xmm(dst, avx_vpconflictd_128(evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem))),
      }
    }
  },

  // 0F38 66: VPBLENDMB (66,W0) / VPBLENDMW (66,W1) — mask-controlled byte/word blend
  102 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch_byte();
    let dst = evex_reg_idx(modrm, pfx);
    let rm = decode_rm_evex(modrm, pfx, if pfx.rex_w then 2 else 1);
    let src1_idx = pfx.evex_vvvvv;
    let k : qword = if pfx.evex_aaa == 0 then ones() else read_kreg(pfx.evex_aaa);
    if pfx.rex_w then {
      // VPBLENDMW: word blend
      match pfx.evex_ll {
        2 => {
          let src1 : zmmword = read_zmm(src1_idx);
          let src2 : zmmword = evex_src_zmm(modrm, rm, pfx);
          var result : zmmword = if pfx.evex_z then zeros() else read_zmm(dst);
          foreach (i from 0 to 31) {
            if k[i] == bitone then
              result[(i * 16 + 15) .. (i * 16)] = src2[(i * 16 + 15) .. (i * 16)]
            else if ~(pfx.evex_z) then
              result[(i * 16 + 15) .. (i * 16)] = src1[(i * 16 + 15) .. (i * 16)]
          };
          write_zmm(dst, result)
        },
        1 => {
          let src1 : ymmword = read_ymm(src1_idx);
          let src2 : ymmword = evex_src_ymm(modrm, rm, pfx);
          var result : ymmword = if pfx.evex_z then zeros() else read_ymm(dst);
          foreach (i from 0 to 15) {
            if k[i] == bitone then
              result[(i * 16 + 15) .. (i * 16)] = src2[(i * 16 + 15) .. (i * 16)]
            else if ~(pfx.evex_z) then
              result[(i * 16 + 15) .. (i * 16)] = src1[(i * 16 + 15) .. (i * 16)]
          };
          write_ymm(dst, result)
        },
        _ => {
          let src1 : xmmword = read_xmm(src1_idx);
          let src2 : xmmword = evex_src_xmm(modrm, rm, pfx);
          var result : xmmword = if pfx.evex_z then zeros() else read_xmm(dst);
          foreach (i from 0 to 7) {
            if k[i] == bitone then
              result[(i * 16 + 15) .. (i * 16)] = src2[(i * 16 + 15) .. (i * 16)]
            else if ~(pfx.evex_z) then
              result[(i * 16 + 15) .. (i * 16)] = src1[(i * 16 + 15) .. (i * 16)]
          };
          write_xmm(dst, result)
        },
      }
    } else {
      // VPBLENDMB: byte blend
      match pfx.evex_ll {
        2 => {
          let src1 : zmmword = read_zmm(src1_idx);
          let src2 : zmmword = evex_src_zmm(modrm, rm, pfx);
          var result : zmmword = if pfx.evex_z then zeros() else read_zmm(dst);
          foreach (i from 0 to 63) {
            if k[i] == bitone then
              result[(i * 8 + 7) .. (i * 8)] = src2[(i * 8 + 7) .. (i * 8)]
            else if ~(pfx.evex_z) then
              result[(i * 8 + 7) .. (i * 8)] = src1[(i * 8 + 7) .. (i * 8)]
          };
          write_zmm(dst, result)
        },
        1 => {
          let src1 : ymmword = read_ymm(src1_idx);
          let src2 : ymmword = evex_src_ymm(modrm, rm, pfx);
          var result : ymmword = if pfx.evex_z then zeros() else read_ymm(dst);
          foreach (i from 0 to 31) {
            if k[i] == bitone then
              result[(i * 8 + 7) .. (i * 8)] = src2[(i * 8 + 7) .. (i * 8)]
            else if ~(pfx.evex_z) then
              result[(i * 8 + 7) .. (i * 8)] = src1[(i * 8 + 7) .. (i * 8)]
          };
          write_ymm(dst, result)
        },
        _ => {
          let src1 : xmmword = read_xmm(src1_idx);
          let src2 : xmmword = evex_src_xmm(modrm, rm, pfx);
          var result : xmmword = if pfx.evex_z then zeros() else read_xmm(dst);
          foreach (i from 0 to 15) {
            if k[i] == bitone then
              result[(i * 8 + 7) .. (i * 8)] = src2[(i * 8 + 7) .. (i * 8)]
            else if ~(pfx.evex_z) then
              result[(i * 8 + 7) .. (i * 8)] = src1[(i * 8 + 7) .. (i * 8)]
          };
          write_xmm(dst, result)
        },
      }
    }
  },

  _ => raise_UD(),
  }
}

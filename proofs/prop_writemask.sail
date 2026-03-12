$include "../model/prelude.sail"

type byte    = bits(8)
type word    = bits(16)
type dword   = bits(32)
type qword   = bits(64)
type xmmword = bits(128)
type ymmword = bits(256)
type zmmword = bits(512)

// Local blend helpers (model defines these in types.sail / insn_sse_int.sail)
val blend16 : (word, word, bits(1)) -> word
function blend16(a, b, sel) = { let m : bits(16) = sign_extend(sel); (a & ~(m)) | (b & m) }

val blend32 : (dword, dword, bits(1)) -> dword
function blend32(a, b, sel) = { let m : bits(32) = sign_extend(sel); (a & ~(m)) | (b & m) }

val blend64 : (qword, qword, bits(1)) -> qword
function blend64(a, b, sel) = { let m : bits(64) = sign_extend(sel); (a & ~(m)) | (b & m) }

// ================================================================
// apply_writemask_ps_xmm: 4 × 32-bit elements, 128-bit
// ================================================================

// Original (textually identical to model in insn_evex.sail)
val apply_writemask_ps_xmm_orig : (xmmword, xmmword, word, bool) -> xmmword
function apply_writemask_ps_xmm_orig(result, old_dst, mask_val, zeroing) = {
  var r : xmmword = if zeroing then zeros() else old_dst;
  if mask_val[3] == bitone then r[127..96] = result[127..96];
  if mask_val[2] == bitone then r[95..64]  = result[95..64];
  if mask_val[1] == bitone then r[63..32]  = result[63..32];
  if mask_val[0] == bitone then r[31..0]   = result[31..0];
  r
}

// Branchless version
val apply_writemask_ps_xmm_new : (xmmword, xmmword, word, bool) -> xmmword
function apply_writemask_ps_xmm_new(result, old_dst, mask_val, zeroing) = {
  let base : xmmword = if zeroing then zeros() else old_dst;
  blend32(base[127..96], result[127..96], mask_val[3..3]) @
  blend32(base[95..64],  result[95..64],  mask_val[2..2]) @
  blend32(base[63..32],  result[63..32],  mask_val[1..1]) @
  blend32(base[31..0],   result[31..0],   mask_val[0..0])
}

$property
function prop_writemask_ps_xmm(result : xmmword, old_dst : xmmword, mask_val : word, zeroing : bool) -> bool =
  apply_writemask_ps_xmm_orig(result, old_dst, mask_val, zeroing) ==
  apply_writemask_ps_xmm_new(result, old_dst, mask_val, zeroing)

// ================================================================
// apply_writemask_pd_xmm: 2 × 64-bit elements, 128-bit
// ================================================================

val apply_writemask_pd_xmm_orig : (xmmword, xmmword, byte, bool) -> xmmword
function apply_writemask_pd_xmm_orig(result, old_dst, mask_val, zeroing) = {
  var r : xmmword = if zeroing then zeros() else old_dst;
  if mask_val[1] == bitone then r[127..64] = result[127..64];
  if mask_val[0] == bitone then r[63..0]   = result[63..0];
  r
}

val apply_writemask_pd_xmm_new : (xmmword, xmmword, byte, bool) -> xmmword
function apply_writemask_pd_xmm_new(result, old_dst, mask_val, zeroing) = {
  let base : xmmword = if zeroing then zeros() else old_dst;
  blend64(base[127..64], result[127..64], mask_val[1..1]) @
  blend64(base[63..0],   result[63..0],   mask_val[0..0])
}

$property
function prop_writemask_pd_xmm(result : xmmword, old_dst : xmmword, mask_val : byte, zeroing : bool) -> bool =
  apply_writemask_pd_xmm_orig(result, old_dst, mask_val, zeroing) ==
  apply_writemask_pd_xmm_new(result, old_dst, mask_val, zeroing)

// ================================================================
// apply_writemask_pd_ymm: 4 × 64-bit elements, 256-bit
// ================================================================

val apply_writemask_pd_ymm_orig : (ymmword, ymmword, byte, bool) -> ymmword
function apply_writemask_pd_ymm_orig(result, old_dst, mask_val, zeroing) = {
  var r : ymmword = if zeroing then zeros() else old_dst;
  if mask_val[3] == bitone then r[255..192] = result[255..192];
  if mask_val[2] == bitone then r[191..128] = result[191..128];
  if mask_val[1] == bitone then r[127..64]  = result[127..64];
  if mask_val[0] == bitone then r[63..0]    = result[63..0];
  r
}

val apply_writemask_pd_ymm_new : (ymmword, ymmword, byte, bool) -> ymmword
function apply_writemask_pd_ymm_new(result, old_dst, mask_val, zeroing) = {
  let base : ymmword = if zeroing then zeros() else old_dst;
  blend64(base[255..192], result[255..192], mask_val[3..3]) @
  blend64(base[191..128], result[191..128], mask_val[2..2]) @
  blend64(base[127..64],  result[127..64],  mask_val[1..1]) @
  blend64(base[63..0],    result[63..0],    mask_val[0..0])
}

$property
function prop_writemask_pd_ymm(result : ymmword, old_dst : ymmword, mask_val : byte, zeroing : bool) -> bool =
  apply_writemask_pd_ymm_orig(result, old_dst, mask_val, zeroing) ==
  apply_writemask_pd_ymm_new(result, old_dst, mask_val, zeroing)

// ================================================================
// apply_writemask_ps_ymm: 8 × 32-bit elements, 256-bit
// ================================================================

val apply_writemask_ps_ymm_orig : (ymmword, ymmword, word, bool) -> ymmword
function apply_writemask_ps_ymm_orig(result, old_dst, mask_val, zeroing) = {
  var r : ymmword = if zeroing then zeros() else old_dst;
  if mask_val[7] == bitone then r[255..224] = result[255..224];
  if mask_val[6] == bitone then r[223..192] = result[223..192];
  if mask_val[5] == bitone then r[191..160] = result[191..160];
  if mask_val[4] == bitone then r[159..128] = result[159..128];
  if mask_val[3] == bitone then r[127..96]  = result[127..96];
  if mask_val[2] == bitone then r[95..64]   = result[95..64];
  if mask_val[1] == bitone then r[63..32]   = result[63..32];
  if mask_val[0] == bitone then r[31..0]    = result[31..0];
  r
}

val apply_writemask_ps_ymm_new : (ymmword, ymmword, word, bool) -> ymmword
function apply_writemask_ps_ymm_new(result, old_dst, mask_val, zeroing) = {
  let base : ymmword = if zeroing then zeros() else old_dst;
  blend32(base[255..224], result[255..224], mask_val[7..7]) @
  blend32(base[223..192], result[223..192], mask_val[6..6]) @
  blend32(base[191..160], result[191..160], mask_val[5..5]) @
  blend32(base[159..128], result[159..128], mask_val[4..4]) @
  blend32(base[127..96],  result[127..96],  mask_val[3..3]) @
  blend32(base[95..64],   result[95..64],   mask_val[2..2]) @
  blend32(base[63..32],   result[63..32],   mask_val[1..1]) @
  blend32(base[31..0],    result[31..0],    mask_val[0..0])
}

$property
function prop_writemask_ps_ymm(result : ymmword, old_dst : ymmword, mask_val : word, zeroing : bool) -> bool =
  apply_writemask_ps_ymm_orig(result, old_dst, mask_val, zeroing) ==
  apply_writemask_ps_ymm_new(result, old_dst, mask_val, zeroing)

// ================================================================
// apply_writemask_pd_zmm: 8 × 64-bit elements, 512-bit
// ================================================================

val apply_writemask_pd_zmm_orig : (zmmword, zmmword, byte, bool) -> zmmword
function apply_writemask_pd_zmm_orig(result, old_dst, mask_val, zeroing) = {
  var r : zmmword = if zeroing then zeros() else old_dst;
  if mask_val[7] == bitone then r[511..448] = result[511..448];
  if mask_val[6] == bitone then r[447..384] = result[447..384];
  if mask_val[5] == bitone then r[383..320] = result[383..320];
  if mask_val[4] == bitone then r[319..256] = result[319..256];
  if mask_val[3] == bitone then r[255..192] = result[255..192];
  if mask_val[2] == bitone then r[191..128] = result[191..128];
  if mask_val[1] == bitone then r[127..64]  = result[127..64];
  if mask_val[0] == bitone then r[63..0]    = result[63..0];
  r
}

val apply_writemask_pd_zmm_new : (zmmword, zmmword, byte, bool) -> zmmword
function apply_writemask_pd_zmm_new(result, old_dst, mask_val, zeroing) = {
  let base : zmmword = if zeroing then zeros() else old_dst;
  blend64(base[511..448], result[511..448], mask_val[7..7]) @
  blend64(base[447..384], result[447..384], mask_val[6..6]) @
  blend64(base[383..320], result[383..320], mask_val[5..5]) @
  blend64(base[319..256], result[319..256], mask_val[4..4]) @
  blend64(base[255..192], result[255..192], mask_val[3..3]) @
  blend64(base[191..128], result[191..128], mask_val[2..2]) @
  blend64(base[127..64],  result[127..64],  mask_val[1..1]) @
  blend64(base[63..0],    result[63..0],    mask_val[0..0])
}

$property
function prop_writemask_pd_zmm(result : zmmword, old_dst : zmmword, mask_val : byte, zeroing : bool) -> bool =
  apply_writemask_pd_zmm_orig(result, old_dst, mask_val, zeroing) ==
  apply_writemask_pd_zmm_new(result, old_dst, mask_val, zeroing)

// ================================================================
// apply_writemask_ps_zmm: 16 × 32-bit elements, 512-bit
// ================================================================

val apply_writemask_ps_zmm_orig : (zmmword, zmmword, word, bool) -> zmmword
function apply_writemask_ps_zmm_orig(result, old_dst, mask_val, zeroing) = {
  var r : zmmword = if zeroing then zeros() else old_dst;
  if mask_val[15] == bitone then r[511..480] = result[511..480];
  if mask_val[14] == bitone then r[479..448] = result[479..448];
  if mask_val[13] == bitone then r[447..416] = result[447..416];
  if mask_val[12] == bitone then r[415..384] = result[415..384];
  if mask_val[11] == bitone then r[383..352] = result[383..352];
  if mask_val[10] == bitone then r[351..320] = result[351..320];
  if mask_val[9]  == bitone then r[319..288] = result[319..288];
  if mask_val[8]  == bitone then r[287..256] = result[287..256];
  if mask_val[7]  == bitone then r[255..224] = result[255..224];
  if mask_val[6]  == bitone then r[223..192] = result[223..192];
  if mask_val[5]  == bitone then r[191..160] = result[191..160];
  if mask_val[4]  == bitone then r[159..128] = result[159..128];
  if mask_val[3]  == bitone then r[127..96]  = result[127..96];
  if mask_val[2]  == bitone then r[95..64]   = result[95..64];
  if mask_val[1]  == bitone then r[63..32]   = result[63..32];
  if mask_val[0]  == bitone then r[31..0]    = result[31..0];
  r
}

val apply_writemask_ps_zmm_new : (zmmword, zmmword, word, bool) -> zmmword
function apply_writemask_ps_zmm_new(result, old_dst, mask_val, zeroing) = {
  let base : zmmword = if zeroing then zeros() else old_dst;
  blend32(base[511..480], result[511..480], mask_val[15..15]) @
  blend32(base[479..448], result[479..448], mask_val[14..14]) @
  blend32(base[447..416], result[447..416], mask_val[13..13]) @
  blend32(base[415..384], result[415..384], mask_val[12..12]) @
  blend32(base[383..352], result[383..352], mask_val[11..11]) @
  blend32(base[351..320], result[351..320], mask_val[10..10]) @
  blend32(base[319..288], result[319..288], mask_val[9..9]) @
  blend32(base[287..256], result[287..256], mask_val[8..8]) @
  blend32(base[255..224], result[255..224], mask_val[7..7]) @
  blend32(base[223..192], result[223..192], mask_val[6..6]) @
  blend32(base[191..160], result[191..160], mask_val[5..5]) @
  blend32(base[159..128], result[159..128], mask_val[4..4]) @
  blend32(base[127..96],  result[127..96],  mask_val[3..3]) @
  blend32(base[95..64],   result[95..64],   mask_val[2..2]) @
  blend32(base[63..32],   result[63..32],   mask_val[1..1]) @
  blend32(base[31..0],    result[31..0],    mask_val[0..0])
}

$property
function prop_writemask_ps_zmm(result : zmmword, old_dst : zmmword, mask_val : word, zeroing : bool) -> bool =
  apply_writemask_ps_zmm_orig(result, old_dst, mask_val, zeroing) ==
  apply_writemask_ps_zmm_new(result, old_dst, mask_val, zeroing)

// ================================================================
// apply_writemask_ph_xmm: 8 × 16-bit elements, 128-bit
// ================================================================

val apply_writemask_ph_xmm_orig : (xmmword, xmmword, byte, bool) -> xmmword
function apply_writemask_ph_xmm_orig(result, old_dst, mask_val, zeroing) = {
  var r : xmmword = if zeroing then zeros() else old_dst;
  if mask_val[7] == bitone then r[127..112] = result[127..112];
  if mask_val[6] == bitone then r[111..96]  = result[111..96];
  if mask_val[5] == bitone then r[95..80]   = result[95..80];
  if mask_val[4] == bitone then r[79..64]   = result[79..64];
  if mask_val[3] == bitone then r[63..48]   = result[63..48];
  if mask_val[2] == bitone then r[47..32]   = result[47..32];
  if mask_val[1] == bitone then r[31..16]   = result[31..16];
  if mask_val[0] == bitone then r[15..0]    = result[15..0];
  r
}

val apply_writemask_ph_xmm_new : (xmmword, xmmword, byte, bool) -> xmmword
function apply_writemask_ph_xmm_new(result, old_dst, mask_val, zeroing) = {
  let base : xmmword = if zeroing then zeros() else old_dst;
  blend16(base[127..112], result[127..112], mask_val[7..7]) @
  blend16(base[111..96],  result[111..96],  mask_val[6..6]) @
  blend16(base[95..80],   result[95..80],   mask_val[5..5]) @
  blend16(base[79..64],   result[79..64],   mask_val[4..4]) @
  blend16(base[63..48],   result[63..48],   mask_val[3..3]) @
  blend16(base[47..32],   result[47..32],   mask_val[2..2]) @
  blend16(base[31..16],   result[31..16],   mask_val[1..1]) @
  blend16(base[15..0],    result[15..0],    mask_val[0..0])
}

$property
function prop_writemask_ph_xmm(result : xmmword, old_dst : xmmword, mask_val : byte, zeroing : bool) -> bool =
  apply_writemask_ph_xmm_orig(result, old_dst, mask_val, zeroing) ==
  apply_writemask_ph_xmm_new(result, old_dst, mask_val, zeroing)

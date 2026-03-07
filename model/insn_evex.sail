// x86-64 EVEX — Shared Helpers
//
// Register index computation, source operand reading, writemask application,
// broadcast, and other utilities used by multiple EVEX dispatch files.

// Compute 5-bit destination register index from EVEX R' : R : modrm.reg
val evex_reg_idx : (byte, Prefixes) -> simd_idx
function evex_reg_idx(modrm, pfx) = {
  let base : range(0, 7) = unsigned(modrm[5..3]);
  let r_ext : range(0, 1) = if pfx.rex_r then 1 else 0;
  let rr_ext : range(0, 1) = if pfx.evex_rr then 1 else 0;
  // 5-bit index: R' : R : reg[2:0]
  rr_ext * 16 + r_ext * 8 + base
}

// Compute 5-bit r/m register index (for register operands only).
// For memory operands, B extends the base register (4 bits, not 5).
val evex_rm_reg_idx : (byte, Prefixes) -> simd_idx
function evex_rm_reg_idx(modrm, pfx) = {
  let base : range(0, 7) = unsigned(modrm[2..0]);
  let b_ext : range(0, 1) = if pfx.rex_b then 1 else 0;
  let x_ext : range(0, 1) = if pfx.rex_x then 1 else 0;
  // 5-bit index: X : B : rm[2:0]
  x_ext * 16 + b_ext * 8 + base
}

// Get the effective opmask value for writemask application.
// aaa=0 means no masking (all bits set). Otherwise read the mask register.
val evex_get_mask16 : Prefixes -> word
function evex_get_mask16(pfx) =
  if pfx.evex_aaa == 0 then ones()
  else read_kreg(pfx.evex_aaa)[15..0]

val evex_get_mask8 : Prefixes -> byte
function evex_get_mask8(pfx) =
  if pfx.evex_aaa == 0 then ones()
  else read_kreg(pfx.evex_aaa)[7..0]

// Read ZMM source from r/m field: register or memory.
val evex_src_zmm : (byte, RM, Prefixes) -> zmmword
function evex_src_zmm(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_zmm(evex_rm_reg_idx(modrm, pfx)),
  RM_mem(addr) => mem_read512(fixup_addr(addr)),
}

val evex_src_ymm : (byte, RM, Prefixes) -> ymmword
function evex_src_ymm(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_ymm(evex_rm_reg_idx(modrm, pfx)),
  RM_mem(addr) => mem_read256(fixup_addr(addr)),
}

val evex_src_xmm : (byte, RM, Prefixes) -> xmmword
function evex_src_xmm(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
  RM_mem(addr) => mem_read128(fixup_addr(addr)),
}

// Read a 32-bit value from r/m for broadcast.
val evex_src_m32 : (byte, RM, Prefixes) -> dword
function evex_src_m32(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
  RM_mem(addr) => mem_read32(fixup_addr(addr)),
}

// Read a 64-bit value from r/m for broadcast.
val evex_src_m64 : (byte, RM, Prefixes) -> qword
function evex_src_m64(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
  RM_mem(addr) => mem_read64(fixup_addr(addr)),
}

// =========================================================================
// Shared helpers (used by multiple EVEX dispatch files)
// =========================================================================

val apply_writemask_ps_zmm : (zmmword, zmmword, word, bool) -> zmmword
function apply_writemask_ps_zmm(result, old_dst, mask_val, zeroing) = {
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

// Apply 8-bit writemask to a 512-bit ZMM result (64-bit elements, 8 lanes).

val apply_writemask_pd_zmm : (zmmword, zmmword, byte, bool) -> zmmword
function apply_writemask_pd_zmm(result, old_dst, mask_val, zeroing) = {
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

// Broadcast a 32-bit value to all 16 dword lanes of a ZMM register.

val broadcast_f32_zmm : dword -> zmmword
function broadcast_f32_zmm(v) =
  v @ v @ v @ v @ v @ v @ v @ v @
  v @ v @ v @ v @ v @ v @ v @ v

// Broadcast a 64-bit value to all 8 qword lanes of a ZMM register.

val broadcast_f64_zmm : qword -> zmmword
function broadcast_f64_zmm(v) =
  v @ v @ v @ v @ v @ v @ v @ v

val select4_f32 : (bits(128), bits(2)) -> bits(32)
function select4_f32(src, ctrl) = match ctrl {
  0b00 => src[31..0],
  0b01 => src[63..32],
  0b10 => src[95..64],
  0b11 => src[127..96],
}

val avx_vpshldw_elem : (word, word, nat) -> word
function avx_vpshldw_elem(src1, src2, cnt) = {
  let count : int = cnt % 16;
  let concat : dword = src1 @ src2;
  let shifted : dword = sail_shiftleft(concat, count);
  shifted[31..16]
}

val avx_vpshldd_elem : (dword, dword, nat) -> dword
function avx_vpshldd_elem(src1, src2, cnt) = {
  let count : int = cnt % 32;
  let concat : qword = src1 @ src2;
  let shifted : qword = sail_shiftleft(concat, count);
  shifted[63..32]
}

val avx_vpshldq_elem : (qword, qword, nat) -> qword
function avx_vpshldq_elem(src1, src2, cnt) = {
  let count : int = cnt % 64;
  let concat : bits(128) = src1 @ src2;
  let shifted : bits(128) = sail_shiftleft(concat, count);
  shifted[127..64]
}

val avx_vpshrdw_elem : (word, word, nat) -> word
function avx_vpshrdw_elem(src1, src2, cnt) = {
  let count : int = cnt % 16;
  let concat : dword = src2 @ src1;
  let shifted : dword = sail_shiftright(concat, count);
  shifted[15..0]
}

val avx_vpshrdd_elem : (dword, dword, nat) -> dword
function avx_vpshrdd_elem(src1, src2, cnt) = {
  let count : int = cnt % 32;
  let concat : qword = src2 @ src1;
  let shifted : qword = sail_shiftright(concat, count);
  shifted[31..0]
}

val avx_vpshrdq_elem : (qword, qword, nat) -> qword
function avx_vpshrdq_elem(src1, src2, cnt) = {
  let count : int = cnt % 64;
  let concat : bits(128) = src2 @ src1;
  let shifted : bits(128) = sail_shiftright(concat, count);
  shifted[63..0]
}

val gf2p8_mul : (byte, byte) -> byte
function gf2p8_mul(a, b) = {
  var result : bits(9) = zeros();
  var aa : bits(9) = sail_zero_extend(a, 9);
  foreach (i from 0 to 7) {
    if b[i] == bitone then result = result ^ aa;
    aa = aa << 1;
    if aa[8] == bitone then aa = aa ^ 0b100011011 // 0x11B
  };
  result[7..0]
}

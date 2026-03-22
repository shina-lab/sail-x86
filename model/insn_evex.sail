// x86-64 — EVEX Shared Helpers
//
// Register index computation, source operand reading, writemask application,
// broadcast, and other utilities used by multiple EVEX dispatch files.

// Compute 5-bit destination register index from EVEX R' : R : modrm.reg
val evex_reg_idx : (byte, Prefixes) -> simd_idx
function evex_reg_idx(modrm, pfx) = {
  let base : range(0, 7) = unsigned(modrm[5..3]);
  let r_ext : range(0, 1) = unsigned(zero_extend(pfx.rex_r) : bits(1));
  let rr_ext : range(0, 1) = unsigned(zero_extend(pfx.evex_rr) : bits(1));
  // 5-bit index: R' : R : reg[2:0]
  rr_ext * 16 + r_ext * 8 + base
}

// Compute 5-bit r/m register index (for register operands only).
// For memory operands, B extends the base register (4 bits, not 5).
val evex_rm_reg_idx : (byte, Prefixes) -> simd_idx
function evex_rm_reg_idx(modrm, pfx) = {
  let base : range(0, 7) = unsigned(modrm[2..0]);
  let b_ext : range(0, 1) = unsigned(zero_extend(pfx.rex_b) : bits(1));
  let x_ext : range(0, 1) = unsigned(zero_extend(pfx.rex_x) : bits(1));
  // 5-bit index: X : B : rm[2:0]
  x_ext * 16 + b_ext * 8 + base
}

// Masked memory store: write only bytes where mask bit = 1.
// elem_bytes: element size (1=byte, 2=word, 4=dword, 8=qword).
// One mask bit per element.
val evex_masked_mem_store : (qword, zmmword, qword, int, int) -> unit
function evex_masked_mem_store(addr, data, mask, nbytes, elem_bytes) = {
  if mask == ones() then {
    // Fast path: no masking, write the full vector
    match nbytes {
      64 => mem_write512(addr, data),
      32 => mem_write256(addr, data[255..0]),
      _  => mem_write128(addr, data[127..0]),
    }
  } else {
    // Slow path: write only elements where the corresponding mask bit = 1
    var off : int = 0;
    var m : qword = mask;
    while off < nbytes do {
      if m[0] == 0b1 then {
        var j : int = 0;
        while j < elem_bytes do {
          let idx : int = off + j;
          assert(0 <= idx & idx < 512);
          let byte_val : byte = get_slice_int(8, unsigned(data), idx * 8);
          mem_write8(addr + to_bits(64, idx), byte_val);
          j = j + 1;
        }
      };
      off = off + elem_bytes;
      m = m >> 1;
    }
  }
}

// Get the effective 64-bit opmask: aaa=0 → all-ones (no masking), else kreg(aaa).
// Branchless: OR with all-ones mask when aaa==0, which subsumes any kreg value.
val evex_kmask64 : Prefixes -> qword
function evex_kmask64(pfx) = {
  let no_mask : qword = zeros() - zero_extend(~(or_reduce_8(zero_extend(to_bits(3, pfx.evex_aaa)))));
  no_mask | read_kreg(pfx.evex_aaa)
}

val evex_get_mask16 : Prefixes -> word
function evex_get_mask16(pfx) = evex_kmask64(pfx)[15..0]

val evex_get_mask8 : Prefixes -> byte
function evex_get_mask8(pfx) = evex_kmask64(pfx)[7..0]

// Read ZMM source from r/m field: register or memory.
val evex_src_zmm : (byte, RM, Prefixes) -> zmmword
function evex_src_zmm(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_zmm(evex_rm_reg_idx(modrm, pfx)),
  RM_mem(seg, offset) => seg_read512(seg, offset),
}

val evex_src_ymm : (byte, RM, Prefixes) -> ymmword
function evex_src_ymm(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_ymm(evex_rm_reg_idx(modrm, pfx)),
  RM_mem(seg, offset) => seg_read256(seg, offset),
}

val evex_src_xmm : (byte, RM, Prefixes) -> xmmword
function evex_src_xmm(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx)),
  RM_mem(seg, offset) => seg_read128(seg, offset),
}

// Read a 32-bit value from r/m for broadcast.
val evex_src_m32 : (byte, RM, Prefixes) -> dword
function evex_src_m32(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
  RM_mem(seg, offset) => seg_read32(seg, offset),
}

// Read a 64-bit value from r/m for broadcast.
val evex_src_m64 : (byte, RM, Prefixes) -> qword
function evex_src_m64(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
  RM_mem(seg, offset) => seg_read64(seg, offset),
}

// =========================================================================
// Shared helpers (used by multiple EVEX dispatch files)
// =========================================================================

val apply_writemask_ps_zmm : (zmmword, zmmword, word, bit) -> zmmword
function apply_writemask_ps_zmm(result, old_dst, mask_val, zeroing) = {
  let keep : zmmword = zeros() - zero_extend(~(zeroing));
  let base : zmmword = old_dst & keep;
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

// Apply 8-bit writemask to a 512-bit ZMM result (64-bit elements, 8 lanes).

val apply_writemask_pd_zmm : (zmmword, zmmword, byte, bit) -> zmmword
function apply_writemask_pd_zmm(result, old_dst, mask_val, zeroing) = {
  let keep : zmmword = zeros() - zero_extend(~(zeroing));
  let base : zmmword = old_dst & keep;
  blend64(base[511..448], result[511..448], mask_val[7..7]) @
  blend64(base[447..384], result[447..384], mask_val[6..6]) @
  blend64(base[383..320], result[383..320], mask_val[5..5]) @
  blend64(base[319..256], result[319..256], mask_val[4..4]) @
  blend64(base[255..192], result[255..192], mask_val[3..3]) @
  blend64(base[191..128], result[191..128], mask_val[2..2]) @
  blend64(base[127..64],  result[127..64],  mask_val[1..1]) @
  blend64(base[63..0],    result[63..0],    mask_val[0..0])
}

// Apply 4-bit writemask to a 128-bit XMM result (32-bit elements, 4 lanes).

val apply_writemask_ps_xmm : (xmmword, xmmword, word, bit) -> xmmword
function apply_writemask_ps_xmm(result, old_dst, mask_val, zeroing) = {
  let keep : xmmword = zeros() - zero_extend(~(zeroing));
  let base : xmmword = old_dst & keep;
  blend32(base[127..96], result[127..96], mask_val[3..3]) @
  blend32(base[95..64],  result[95..64],  mask_val[2..2]) @
  blend32(base[63..32],  result[63..32],  mask_val[1..1]) @
  blend32(base[31..0],   result[31..0],   mask_val[0..0])
}

// Apply 8-bit writemask to a 256-bit YMM result (32-bit elements, 8 lanes).

val apply_writemask_ps_ymm : (ymmword, ymmword, word, bit) -> ymmword
function apply_writemask_ps_ymm(result, old_dst, mask_val, zeroing) = {
  let keep : ymmword = zeros() - zero_extend(~(zeroing));
  let base : ymmword = old_dst & keep;
  blend32(base[255..224], result[255..224], mask_val[7..7]) @
  blend32(base[223..192], result[223..192], mask_val[6..6]) @
  blend32(base[191..160], result[191..160], mask_val[5..5]) @
  blend32(base[159..128], result[159..128], mask_val[4..4]) @
  blend32(base[127..96],  result[127..96],  mask_val[3..3]) @
  blend32(base[95..64],   result[95..64],   mask_val[2..2]) @
  blend32(base[63..32],   result[63..32],   mask_val[1..1]) @
  blend32(base[31..0],    result[31..0],    mask_val[0..0])
}

// Apply 2-bit writemask to a 128-bit XMM result (64-bit elements, 2 lanes).

val apply_writemask_pd_xmm : (xmmword, xmmword, byte, bit) -> xmmword
function apply_writemask_pd_xmm(result, old_dst, mask_val, zeroing) = {
  let keep : xmmword = zeros() - zero_extend(~(zeroing));
  let base : xmmword = old_dst & keep;
  blend64(base[127..64], result[127..64], mask_val[1..1]) @
  blend64(base[63..0],   result[63..0],   mask_val[0..0])
}

// Apply 4-bit writemask to a 256-bit YMM result (64-bit elements, 4 lanes).

val apply_writemask_pd_ymm : (ymmword, ymmword, byte, bit) -> ymmword
function apply_writemask_pd_ymm(result, old_dst, mask_val, zeroing) = {
  let keep : ymmword = zeros() - zero_extend(~(zeroing));
  let base : ymmword = old_dst & keep;
  blend64(base[255..192], result[255..192], mask_val[3..3]) @
  blend64(base[191..128], result[191..128], mask_val[2..2]) @
  blend64(base[127..64],  result[127..64],  mask_val[1..1]) @
  blend64(base[63..0],    result[63..0],    mask_val[0..0])
}

// =========================================================================
// Byte-element (8-bit) writemask helpers — for VPADDB, VPSUBB, etc.
// =========================================================================

val apply_writemask_b_xmm : (xmmword, xmmword, word, bit) -> xmmword
function apply_writemask_b_xmm(result, old_dst, mask_val, zeroing) = {
  let keep : xmmword = zeros() - zero_extend(~(zeroing));
  let base : xmmword = old_dst & keep;
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let hi = i * 8 + 7;
    let lo = i * 8;
    r[hi..lo] = blend8(base[hi..lo], result[hi..lo], mask_val[i..i])
  };
  r
}

val apply_writemask_b_ymm : (ymmword, ymmword, dword, bit) -> ymmword
function apply_writemask_b_ymm(result, old_dst, mask_val, zeroing) = {
  let keep : ymmword = zeros() - zero_extend(~(zeroing));
  let base : ymmword = old_dst & keep;
  var r : ymmword = zeros();
  foreach (i from 0 to 31) {
    let hi = i * 8 + 7;
    let lo = i * 8;
    r[hi..lo] = blend8(base[hi..lo], result[hi..lo], mask_val[i..i])
  };
  r
}

val apply_writemask_b_zmm : (zmmword, zmmword, qword, bit) -> zmmword
function apply_writemask_b_zmm(result, old_dst, mask_val, zeroing) = {
  let keep : zmmword = zeros() - zero_extend(~(zeroing));
  let base : zmmword = old_dst & keep;
  var r : zmmword = zeros();
  foreach (i from 0 to 63) {
    let hi = i * 8 + 7;
    let lo = i * 8;
    r[hi..lo] = blend8(base[hi..lo], result[hi..lo], mask_val[i..i])
  };
  r
}

// =========================================================================
// Word-element (16-bit) writemask helpers — for VPADDW, VPSUBW, etc.
// =========================================================================

val apply_writemask_w_xmm : (xmmword, xmmword, byte, bit) -> xmmword
function apply_writemask_w_xmm(result, old_dst, mask_val, zeroing) = {
  let keep : xmmword = zeros() - zero_extend(~(zeroing));
  let base : xmmword = old_dst & keep;
  var r : xmmword = zeros();
  foreach (i from 0 to 7) {
    let hi = i * 16 + 15;
    let lo = i * 16;
    r[hi..lo] = blend16(base[hi..lo], result[hi..lo], mask_val[i..i])
  };
  r
}

val apply_writemask_w_ymm : (ymmword, ymmword, word, bit) -> ymmword
function apply_writemask_w_ymm(result, old_dst, mask_val, zeroing) = {
  let keep : ymmword = zeros() - zero_extend(~(zeroing));
  let base : ymmword = old_dst & keep;
  var r : ymmword = zeros();
  foreach (i from 0 to 15) {
    let hi = i * 16 + 15;
    let lo = i * 16;
    r[hi..lo] = blend16(base[hi..lo], result[hi..lo], mask_val[i..i])
  };
  r
}

val apply_writemask_w_zmm : (zmmword, zmmword, dword, bit) -> zmmword
function apply_writemask_w_zmm(result, old_dst, mask_val, zeroing) = {
  let keep : zmmword = zeros() - zero_extend(~(zeroing));
  let base : zmmword = old_dst & keep;
  var r : zmmword = zeros();
  foreach (i from 0 to 31) {
    let hi = i * 16 + 15;
    let lo = i * 16;
    r[hi..lo] = blend16(base[hi..lo], result[hi..lo], mask_val[i..i])
  };
  r
}

// =========================================================================
// Convenience wrappers: evex_write_{b,w,d,q}_{zmm,ymm,xmm}
// These compute+apply writemask and write the result in one call.
// Element size determines mask granularity:
//   b=8-bit (64 elements/ZMM), w=16-bit (32), d=32-bit (16), q=64-bit (8)
// =========================================================================

// --- Byte (8-bit) element ---
val evex_write_b_zmm : (simd_idx, zmmword, Prefixes) -> unit
function evex_write_b_zmm(dst, result, pfx) =
  write_zmm(dst, apply_writemask_b_zmm(result, read_zmm(dst), evex_kmask64(pfx), pfx.evex_z))

val evex_write_b_ymm : (simd_idx, ymmword, Prefixes) -> unit
function evex_write_b_ymm(dst, result, pfx) =
  write_ymm(dst, apply_writemask_b_ymm(result, read_ymm(dst), evex_kmask64(pfx)[31..0], pfx.evex_z))

val evex_write_b_xmm : (simd_idx, xmmword, Prefixes) -> unit
function evex_write_b_xmm(dst, result, pfx) =
  write_xmm(dst, apply_writemask_b_xmm(result, read_xmm(dst), evex_get_mask16(pfx), pfx.evex_z))

// --- Word (16-bit) element ---
val evex_write_w_zmm : (simd_idx, zmmword, Prefixes) -> unit
function evex_write_w_zmm(dst, result, pfx) =
  write_zmm(dst, apply_writemask_w_zmm(result, read_zmm(dst), evex_kmask64(pfx)[31..0], pfx.evex_z))

val evex_write_w_ymm : (simd_idx, ymmword, Prefixes) -> unit
function evex_write_w_ymm(dst, result, pfx) =
  write_ymm(dst, apply_writemask_w_ymm(result, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z))

val evex_write_w_xmm : (simd_idx, xmmword, Prefixes) -> unit
function evex_write_w_xmm(dst, result, pfx) =
  write_xmm(dst, apply_writemask_w_xmm(result, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z))

// --- Dword (32-bit) element ---
val evex_write_d_zmm : (simd_idx, zmmword, Prefixes) -> unit
function evex_write_d_zmm(dst, result, pfx) =
  write_zmm(dst, apply_writemask_ps_zmm(result, read_zmm(dst), evex_get_mask16(pfx), pfx.evex_z))

val evex_write_d_ymm : (simd_idx, ymmword, Prefixes) -> unit
function evex_write_d_ymm(dst, result, pfx) =
  write_ymm(dst, apply_writemask_ps_ymm(result, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z))

val evex_write_d_xmm : (simd_idx, xmmword, Prefixes) -> unit
function evex_write_d_xmm(dst, result, pfx) =
  write_xmm(dst, apply_writemask_ps_xmm(result, read_xmm(dst), evex_get_mask16(pfx), pfx.evex_z))

// --- Qword (64-bit) element ---
val evex_write_q_zmm : (simd_idx, zmmword, Prefixes) -> unit
function evex_write_q_zmm(dst, result, pfx) =
  write_zmm(dst, apply_writemask_pd_zmm(result, read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z))

val evex_write_q_ymm : (simd_idx, ymmword, Prefixes) -> unit
function evex_write_q_ymm(dst, result, pfx) =
  write_ymm(dst, apply_writemask_pd_ymm(result, read_ymm(dst), evex_get_mask8(pfx), pfx.evex_z))

val evex_write_q_xmm : (simd_idx, xmmword, Prefixes) -> unit
function evex_write_q_xmm(dst, result, pfx) =
  write_xmm(dst, apply_writemask_pd_xmm(result, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z))

// --- PS (32-bit FP) — aliases for dword ---
val evex_write_ps_zmm : (simd_idx, zmmword, Prefixes) -> unit
function evex_write_ps_zmm(dst, result, pfx) = evex_write_d_zmm(dst, result, pfx)

val evex_write_ps_ymm : (simd_idx, ymmword, Prefixes) -> unit
function evex_write_ps_ymm(dst, result, pfx) = evex_write_d_ymm(dst, result, pfx)

val evex_write_ps_xmm : (simd_idx, xmmword, Prefixes) -> unit
function evex_write_ps_xmm(dst, result, pfx) = evex_write_d_xmm(dst, result, pfx)

// --- PD (64-bit FP) — aliases for qword ---
val evex_write_pd_zmm : (simd_idx, zmmword, Prefixes) -> unit
function evex_write_pd_zmm(dst, result, pfx) = evex_write_q_zmm(dst, result, pfx)

val evex_write_pd_ymm : (simd_idx, ymmword, Prefixes) -> unit
function evex_write_pd_ymm(dst, result, pfx) = evex_write_q_ymm(dst, result, pfx)

val evex_write_pd_xmm : (simd_idx, xmmword, Prefixes) -> unit
function evex_write_pd_xmm(dst, result, pfx) = evex_write_q_xmm(dst, result, pfx)

// --- Scalar SS (32-bit) writemask ---
// Applies mask bit 0 only to the lowest dword of an XMM result.
// Upper bits [127:32] are already merged from src1 by the caller.
val evex_write_ss : (simd_idx, xmmword, Prefixes) -> unit
function evex_write_ss(dst, result, pfx) = {
  let mask_bit : bit = evex_kmask64(pfx)[0];
  if mask_bit == 0b1 then {
    write_xmm(dst, result)
  } else if pfx.evex_z == 0b1 then {
    write_xmm(dst, result[127..32] @ zeros(32))
  } else {
    write_xmm(dst, result[127..32] @ read_xmm(dst)[31..0])
  }
}

// --- Scalar SH (16-bit FP16) writemask ---
val evex_write_sh : (simd_idx, xmmword, Prefixes) -> unit
function evex_write_sh(dst, result, pfx) = {
  let mask_bit : bit = evex_kmask64(pfx)[0];
  if mask_bit == 0b1 then {
    write_xmm(dst, result)
  } else if pfx.evex_z == 0b1 then {
    write_xmm(dst, result[127..16] @ zeros(16))
  } else {
    write_xmm(dst, result[127..16] @ read_xmm(dst)[15..0])
  }
}

// --- Scalar SD (64-bit) writemask ---
val evex_write_sd : (simd_idx, xmmword, Prefixes) -> unit
function evex_write_sd(dst, result, pfx) = {
  let mask_bit : bit = evex_kmask64(pfx)[0];
  if mask_bit == 0b1 then {
    write_xmm(dst, result)
  } else if pfx.evex_z == 0b1 then {
    write_xmm(dst, result[127..64] @ zeros(64))
  } else {
    write_xmm(dst, result[127..64] @ read_xmm(dst)[63..0])
  }
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

val broadcast_f32_ymm : dword -> ymmword
function broadcast_f32_ymm(v) =
  v @ v @ v @ v @ v @ v @ v @ v

val broadcast_f32_xmm : dword -> xmmword
function broadcast_f32_xmm(v) =
  v @ v @ v @ v

val broadcast_f64_ymm : qword -> ymmword
function broadcast_f64_ymm(v) =
  v @ v @ v @ v

val broadcast_f64_xmm : qword -> xmmword
function broadcast_f64_xmm(v) =
  v @ v

// Broadcast-aware source helpers: read source from reg/mem, applying
// EVEX.b broadcast when the source is a memory operand.

val evex_bcast_src_f32_zmm : (byte, RM, Prefixes, bool) -> zmmword
function evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem) =
  if pfx.evex_b & is_mem then broadcast_f32_zmm(evex_src_m32(modrm, rm, pfx))
  else evex_src_zmm(modrm, rm, pfx)

val evex_bcast_src_f32_ymm : (byte, RM, Prefixes, bool) -> ymmword
function evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem) =
  if pfx.evex_b & is_mem then broadcast_f32_ymm(evex_src_m32(modrm, rm, pfx))
  else evex_src_ymm(modrm, rm, pfx)

val evex_bcast_src_f32_xmm : (byte, RM, Prefixes, bool) -> xmmword
function evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem) =
  if pfx.evex_b & is_mem then broadcast_f32_xmm(evex_src_m32(modrm, rm, pfx))
  else evex_src_xmm(modrm, rm, pfx)

val evex_bcast_src_f64_zmm : (byte, RM, Prefixes, bool) -> zmmword
function evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem) =
  if pfx.evex_b & is_mem then broadcast_f64_zmm(evex_src_m64(modrm, rm, pfx))
  else evex_src_zmm(modrm, rm, pfx)

val evex_bcast_src_f64_ymm : (byte, RM, Prefixes, bool) -> ymmword
function evex_bcast_src_f64_ymm(modrm, rm, pfx, is_mem) =
  if pfx.evex_b & is_mem then broadcast_f64_ymm(evex_src_m64(modrm, rm, pfx))
  else evex_src_ymm(modrm, rm, pfx)

val evex_bcast_src_f64_xmm : (byte, RM, Prefixes, bool) -> xmmword
function evex_bcast_src_f64_xmm(modrm, rm, pfx, is_mem) =
  if pfx.evex_b & is_mem then broadcast_f64_xmm(evex_src_m64(modrm, rm, pfx))
  else evex_src_xmm(modrm, rm, pfx)

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
    result = result ^ (sign_extend(b[i..i]) & aa);
    aa = aa << 1;
    aa = aa ^ (sign_extend(aa[8..8]) & 0b100011011) // 0x11B
  };
  result[7..0]
}

// =========================================================================
// EVEX Embedded Rounding Control
// =========================================================================
// When EVEX.b=1 and the operand is register-only (ModRM.mod=11), the
// EVEX.LL field encodes a static rounding mode instead of vector length:
//   00=RN (round nearest), 01=RD (round down),
//   02=RU (round up),      03=RZ (round toward zero)
// The vector length is implicitly 512-bit for packed operations.
// SAE (suppress all exceptions) is also implied.
//
// evex_begin_rc() saves the current MXCSR, overrides bits 14:13 with LL,
// and returns (effective_ll, saved_mxcsr). Call evex_end_rc() to restore.

val evex_begin_rc : (Prefixes, bool) -> (range(0, 3), dword)
function evex_begin_rc(pfx, is_reg) = {
  let saved = __stmxcsr();
  if pfx.evex_b & is_reg then {
    // LL encodes rounding control; override MXCSR RC (bits 14:13)
    let rc : range(0, 3) = pfx.evex_ll;
    let new_mxcsr : dword = (saved & 0xFFFF9FFF) | to_bits(32, rc * 8192);
    __ldmxcsr(new_mxcsr);
    (2, saved)  // force 512-bit vector length
  } else {
    (pfx.evex_ll, saved)
  }
}

val evex_end_rc : dword -> unit
function evex_end_rc(saved) = __ldmxcsr(saved)

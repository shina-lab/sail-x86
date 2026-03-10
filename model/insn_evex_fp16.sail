// x86-64 EVEX — AVX-512 FP16 Operations (MAP5 and MAP6)
//
// Half-precision (16-bit) packed and scalar floating-point arithmetic,
// conversions, and special operations.

// =========================================================================
// FP16 element-wise helpers (xmm = 8 lanes, ymm = 16 lanes, zmm = 32 lanes)
// =========================================================================

// Packed FP16 arithmetic: apply a binary f16 operation element-wise on 128 bits (8 × 16-bit)
val vaddph_xmm : (xmmword, xmmword) -> xmmword
function vaddph_xmm(a, b) =
  __f16_add(a[127..112], b[127..112]) @ __f16_add(a[111..96], b[111..96]) @
  __f16_add(a[95..80], b[95..80]) @ __f16_add(a[79..64], b[79..64]) @
  __f16_add(a[63..48], b[63..48]) @ __f16_add(a[47..32], b[47..32]) @
  __f16_add(a[31..16], b[31..16]) @ __f16_add(a[15..0], b[15..0])

val vsubph_xmm : (xmmword, xmmword) -> xmmword
function vsubph_xmm(a, b) =
  __f16_sub(a[127..112], b[127..112]) @ __f16_sub(a[111..96], b[111..96]) @
  __f16_sub(a[95..80], b[95..80]) @ __f16_sub(a[79..64], b[79..64]) @
  __f16_sub(a[63..48], b[63..48]) @ __f16_sub(a[47..32], b[47..32]) @
  __f16_sub(a[31..16], b[31..16]) @ __f16_sub(a[15..0], b[15..0])

val vmulph_xmm : (xmmword, xmmword) -> xmmword
function vmulph_xmm(a, b) =
  __f16_mul(a[127..112], b[127..112]) @ __f16_mul(a[111..96], b[111..96]) @
  __f16_mul(a[95..80], b[95..80]) @ __f16_mul(a[79..64], b[79..64]) @
  __f16_mul(a[63..48], b[63..48]) @ __f16_mul(a[47..32], b[47..32]) @
  __f16_mul(a[31..16], b[31..16]) @ __f16_mul(a[15..0], b[15..0])

val vdivph_xmm : (xmmword, xmmword) -> xmmword
function vdivph_xmm(a, b) =
  __f16_div(a[127..112], b[127..112]) @ __f16_div(a[111..96], b[111..96]) @
  __f16_div(a[95..80], b[95..80]) @ __f16_div(a[79..64], b[79..64]) @
  __f16_div(a[63..48], b[63..48]) @ __f16_div(a[47..32], b[47..32]) @
  __f16_div(a[31..16], b[31..16]) @ __f16_div(a[15..0], b[15..0])

val vminph_xmm : (xmmword, xmmword) -> xmmword
function vminph_xmm(a, b) =
  __f16_min(a[127..112], b[127..112]) @ __f16_min(a[111..96], b[111..96]) @
  __f16_min(a[95..80], b[95..80]) @ __f16_min(a[79..64], b[79..64]) @
  __f16_min(a[63..48], b[63..48]) @ __f16_min(a[47..32], b[47..32]) @
  __f16_min(a[31..16], b[31..16]) @ __f16_min(a[15..0], b[15..0])

val vmaxph_xmm : (xmmword, xmmword) -> xmmword
function vmaxph_xmm(a, b) =
  __f16_max(a[127..112], b[127..112]) @ __f16_max(a[111..96], b[111..96]) @
  __f16_max(a[95..80], b[95..80]) @ __f16_max(a[79..64], b[79..64]) @
  __f16_max(a[63..48], b[63..48]) @ __f16_max(a[47..32], b[47..32]) @
  __f16_max(a[31..16], b[31..16]) @ __f16_max(a[15..0], b[15..0])

val vsqrtph_xmm : xmmword -> xmmword
function vsqrtph_xmm(a) =
  __f16_sqrt(a[127..112]) @ __f16_sqrt(a[111..96]) @
  __f16_sqrt(a[95..80]) @ __f16_sqrt(a[79..64]) @
  __f16_sqrt(a[63..48]) @ __f16_sqrt(a[47..32]) @
  __f16_sqrt(a[31..16]) @ __f16_sqrt(a[15..0])

// YMM (256-bit = 16 × FP16)
val vaddph_ymm : (ymmword, ymmword) -> ymmword
function vaddph_ymm(a, b) =
  vaddph_xmm(a[255..128], b[255..128]) @ vaddph_xmm(a[127..0], b[127..0])

val vsubph_ymm : (ymmword, ymmword) -> ymmword
function vsubph_ymm(a, b) =
  vsubph_xmm(a[255..128], b[255..128]) @ vsubph_xmm(a[127..0], b[127..0])

val vmulph_ymm : (ymmword, ymmword) -> ymmword
function vmulph_ymm(a, b) =
  vmulph_xmm(a[255..128], b[255..128]) @ vmulph_xmm(a[127..0], b[127..0])

val vdivph_ymm : (ymmword, ymmword) -> ymmword
function vdivph_ymm(a, b) =
  vdivph_xmm(a[255..128], b[255..128]) @ vdivph_xmm(a[127..0], b[127..0])

val vminph_ymm : (ymmword, ymmword) -> ymmword
function vminph_ymm(a, b) =
  vminph_xmm(a[255..128], b[255..128]) @ vminph_xmm(a[127..0], b[127..0])

val vmaxph_ymm : (ymmword, ymmword) -> ymmword
function vmaxph_ymm(a, b) =
  vmaxph_xmm(a[255..128], b[255..128]) @ vmaxph_xmm(a[127..0], b[127..0])

val vsqrtph_ymm : ymmword -> ymmword
function vsqrtph_ymm(a) =
  vsqrtph_xmm(a[255..128]) @ vsqrtph_xmm(a[127..0])

// ZMM (512-bit = 32 × FP16)
val vaddph_zmm : (zmmword, zmmword) -> zmmword
function vaddph_zmm(a, b) =
  vaddph_ymm(a[511..256], b[511..256]) @ vaddph_ymm(a[255..0], b[255..0])

val vsubph_zmm : (zmmword, zmmword) -> zmmword
function vsubph_zmm(a, b) =
  vsubph_ymm(a[511..256], b[511..256]) @ vsubph_ymm(a[255..0], b[255..0])

val vmulph_zmm : (zmmword, zmmword) -> zmmword
function vmulph_zmm(a, b) =
  vmulph_ymm(a[511..256], b[511..256]) @ vmulph_ymm(a[255..0], b[255..0])

val vdivph_zmm : (zmmword, zmmword) -> zmmword
function vdivph_zmm(a, b) =
  vdivph_ymm(a[511..256], b[511..256]) @ vdivph_ymm(a[255..0], b[255..0])

val vminph_zmm : (zmmword, zmmword) -> zmmword
function vminph_zmm(a, b) =
  vminph_ymm(a[511..256], b[511..256]) @ vminph_ymm(a[255..0], b[255..0])

val vmaxph_zmm : (zmmword, zmmword) -> zmmword
function vmaxph_zmm(a, b) =
  vmaxph_ymm(a[511..256], b[511..256]) @ vmaxph_ymm(a[255..0], b[255..0])

val vsqrtph_zmm : zmmword -> zmmword
function vsqrtph_zmm(a) =
  vsqrtph_ymm(a[511..256]) @ vsqrtph_ymm(a[255..0])

// =========================================================================
// FP16 writemask helpers (16-bit elements)
// =========================================================================

// Apply 8-bit writemask to 128-bit XMM (8 × 16-bit FP16)
val apply_writemask_ph_xmm : (xmmword, xmmword, byte, bool) -> xmmword
function apply_writemask_ph_xmm(result, old_dst, mask_val, zeroing) = {
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

// Apply 16-bit writemask to 256-bit YMM (16 × 16-bit FP16)
val apply_writemask_ph_ymm : (ymmword, ymmword, word, bool) -> ymmword
function apply_writemask_ph_ymm(result, old_dst, mask_val, zeroing) = {
  var r : ymmword = if zeroing then zeros() else old_dst;
  let hi = apply_writemask_ph_xmm(result[255..128], old_dst[255..128], mask_val[15..8], zeroing);
  let lo = apply_writemask_ph_xmm(result[127..0], old_dst[127..0], mask_val[7..0], zeroing);
  hi @ lo
}

// Apply 32-bit writemask to 512-bit ZMM (32 × 16-bit FP16)
val apply_writemask_ph_zmm : (zmmword, zmmword, dword, bool) -> zmmword
function apply_writemask_ph_zmm(result, old_dst, mask_val, zeroing) = {
  let hi = apply_writemask_ph_ymm(result[511..256], old_dst[511..256], mask_val[31..16], zeroing);
  let lo = apply_writemask_ph_ymm(result[255..0], old_dst[255..0], mask_val[15..0], zeroing);
  hi @ lo
}

// Get 32-bit writemask for FP16 ZMM (32 lanes)
val evex_get_mask32 : Prefixes -> dword
function evex_get_mask32(pfx) =
  if pfx.evex_aaa == 0 then ones()
  else read_kreg(pfx.evex_aaa)[31..0]

// =========================================================================
// FP16 broadcast helpers
// =========================================================================

val broadcast_f16_xmm : word -> xmmword
function broadcast_f16_xmm(v) = v @ v @ v @ v @ v @ v @ v @ v

val broadcast_f16_ymm : word -> ymmword
function broadcast_f16_ymm(v) =
  broadcast_f16_xmm(v) @ broadcast_f16_xmm(v)

val broadcast_f16_zmm : word -> zmmword
function broadcast_f16_zmm(v) =
  broadcast_f16_ymm(v) @ broadcast_f16_ymm(v)

// Read a 16-bit value from r/m for broadcast
val evex_src_m16 : (byte, RM, Prefixes) -> word
function evex_src_m16(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
  RM_mem(addr) => mem_read16(fixup_addr(addr)),
}

val evex_bcast_src_f16_zmm : (byte, RM, Prefixes, bool) -> zmmword
function evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem) =
  if pfx.evex_b & is_mem then broadcast_f16_zmm(evex_src_m16(modrm, rm, pfx))
  else evex_src_zmm(modrm, rm, pfx)

val evex_bcast_src_f16_ymm : (byte, RM, Prefixes, bool) -> ymmword
function evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem) =
  if pfx.evex_b & is_mem then broadcast_f16_ymm(evex_src_m16(modrm, rm, pfx))
  else evex_src_ymm(modrm, rm, pfx)

val evex_bcast_src_f16_xmm : (byte, RM, Prefixes, bool) -> xmmword
function evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem) =
  if pfx.evex_b & is_mem then broadcast_f16_xmm(evex_src_m16(modrm, rm, pfx))
  else evex_src_xmm(modrm, rm, pfx)

// =========================================================================
// EVEX MAP5 dispatch — FP16 basic arithmetic (NP prefix, W=0)
// =========================================================================

// Compressed displacement for FP16 Full tuple: broadcast uses 2 bytes, vector uses 16/32/64
val evex_full_disp_n_fp16 : Prefixes -> range(2, 64)
function evex_full_disp_n_fp16(pfx) =
  if pfx.evex_b then 2
  else match pfx.evex_ll {
    0 => 16,
    1 => 32,
    _ => 64,
  }

val dispatch_evex_map5 : (byte, Prefixes) -> ExecutionResult
function dispatch_evex_map5(opcode, pfx) = {
  let mp = get_mandatory_prefix(pfx);
  let op : range(0, 255) = unsigned(opcode);

  match op {

    // MAP5 0x51: VSQRTPH xmm/ymm/zmm (NP, W=0) or VSQRTSH (F3, W=0)
    81 => {
      if mp != MP_NONE then { raise_UD() }
      else {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
        let result : ExecutionResult = match eff_ll {
          2 => {
            let src = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
            let r = vsqrtph_zmm(src);
            write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
          },
          1 => {
            let src = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
            let r = vsqrtph_ymm(src);
            write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
          },
          _ => {
            let src = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
            let r = vsqrtph_xmm(src);
            write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
          },
        };
        evex_end_rc(saved);
        result
      }
    },

    // MAP5 0x58: VADDPH (NP, W=0) or VADDSH (F3, W=0)
    88 => {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      match mp {
        MP_NONE => {
          let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
          let result : ExecutionResult = match eff_ll {
            2 => {
              let src1 = read_zmm(pfx.evex_vvvvv);
              let src2 = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
              let r = vaddph_zmm(src1, src2);
              write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
            },
            1 => {
              let src1 = read_ymm(pfx.evex_vvvvv);
              let src2 = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
              let r = vaddph_ymm(src1, src2);
              write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
            },
            _ => {
              let src1 = read_xmm(pfx.evex_vvvvv);
              let src2 = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
              let r = vaddph_xmm(src1, src2);
              write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
            },
          };
          evex_end_rc(saved);
          result
        },
        MP_F3 => {
          // VADDSH: scalar FP16 add (lowest 16 bits)
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : word = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(addr) => mem_read16(fixup_addr(addr)),
          };
          let r : word = __f16_add(src1[15..0], src2);
          let result : xmmword = src1[127..16] @ r;
          write_xmm(dst, result); Ok()
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x59: VMULPH (NP, W=0) or VMULSH (F3, W=0)
    89 => {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      match mp {
        MP_NONE => {
          let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
          let result : ExecutionResult = match eff_ll {
            2 => {
              let src1 = read_zmm(pfx.evex_vvvvv);
              let src2 = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
              let r = vmulph_zmm(src1, src2);
              write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
            },
            1 => {
              let src1 = read_ymm(pfx.evex_vvvvv);
              let src2 = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
              let r = vmulph_ymm(src1, src2);
              write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
            },
            _ => {
              let src1 = read_xmm(pfx.evex_vvvvv);
              let src2 = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
              let r = vmulph_xmm(src1, src2);
              write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
            },
          };
          evex_end_rc(saved);
          result
        },
        MP_F3 => {
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : word = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(addr) => mem_read16(fixup_addr(addr)),
          };
          let r : word = __f16_mul(src1[15..0], src2);
          write_xmm(dst, src1[127..16] @ r); Ok()
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x5C: VSUBPH (NP, W=0) or VSUBSH (F3, W=0)
    92 => {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      match mp {
        MP_NONE => {
          let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
          let result : ExecutionResult = match eff_ll {
            2 => {
              let src1 = read_zmm(pfx.evex_vvvvv);
              let src2 = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
              let r = vsubph_zmm(src1, src2);
              write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
            },
            1 => {
              let src1 = read_ymm(pfx.evex_vvvvv);
              let src2 = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
              let r = vsubph_ymm(src1, src2);
              write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
            },
            _ => {
              let src1 = read_xmm(pfx.evex_vvvvv);
              let src2 = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
              let r = vsubph_xmm(src1, src2);
              write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
            },
          };
          evex_end_rc(saved);
          result
        },
        MP_F3 => {
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : word = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(addr) => mem_read16(fixup_addr(addr)),
          };
          let r : word = __f16_sub(src1[15..0], src2);
          write_xmm(dst, src1[127..16] @ r); Ok()
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x5D: VMINPH (NP, W=0) or VMINSH (F3, W=0)
    93 => {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      match mp {
        MP_NONE => {
          let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
          let result : ExecutionResult = match eff_ll {
            2 => {
              let src1 = read_zmm(pfx.evex_vvvvv);
              let src2 = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
              let r = vminph_zmm(src1, src2);
              write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
            },
            1 => {
              let src1 = read_ymm(pfx.evex_vvvvv);
              let src2 = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
              let r = vminph_ymm(src1, src2);
              write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
            },
            _ => {
              let src1 = read_xmm(pfx.evex_vvvvv);
              let src2 = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
              let r = vminph_xmm(src1, src2);
              write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
            },
          };
          evex_end_rc(saved);
          result
        },
        MP_F3 => {
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : word = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(addr) => mem_read16(fixup_addr(addr)),
          };
          let r : word = __f16_min(src1[15..0], src2);
          write_xmm(dst, src1[127..16] @ r); Ok()
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x5E: VDIVPH (NP, W=0) or VDIVSH (F3, W=0)
    94 => {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      match mp {
        MP_NONE => {
          let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
          let result : ExecutionResult = match eff_ll {
            2 => {
              let src1 = read_zmm(pfx.evex_vvvvv);
              let src2 = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
              let r = vdivph_zmm(src1, src2);
              write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
            },
            1 => {
              let src1 = read_ymm(pfx.evex_vvvvv);
              let src2 = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
              let r = vdivph_ymm(src1, src2);
              write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
            },
            _ => {
              let src1 = read_xmm(pfx.evex_vvvvv);
              let src2 = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
              let r = vdivph_xmm(src1, src2);
              write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
            },
          };
          evex_end_rc(saved);
          result
        },
        MP_F3 => {
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : word = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(addr) => mem_read16(fixup_addr(addr)),
          };
          let r : word = __f16_div(src1[15..0], src2);
          write_xmm(dst, src1[127..16] @ r); Ok()
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x5F: VMAXPH (NP, W=0) or VMAXSH (F3, W=0)
    95 => {
      let modrm = fetch_byte();
      let dst = evex_reg_idx(modrm, pfx);
      let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
      let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
      match mp {
        MP_NONE => {
          let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
          let result : ExecutionResult = match eff_ll {
            2 => {
              let src1 = read_zmm(pfx.evex_vvvvv);
              let src2 = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
              let r = vmaxph_zmm(src1, src2);
              write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
            },
            1 => {
              let src1 = read_ymm(pfx.evex_vvvvv);
              let src2 = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
              let r = vmaxph_ymm(src1, src2);
              write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
            },
            _ => {
              let src1 = read_xmm(pfx.evex_vvvvv);
              let src2 = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
              let r = vmaxph_xmm(src1, src2);
              write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
            },
          };
          evex_end_rc(saved);
          result
        },
        MP_F3 => {
          let src1 : xmmword = read_xmm(pfx.evex_vvvvv);
          let src2 : word = match rm {
            RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[15..0],
            RM_mem(addr) => mem_read16(fixup_addr(addr)),
          };
          let r : word = __f16_max(src1[15..0], src2);
          write_xmm(dst, src1[127..16] @ r); Ok()
        },
        _ => raise_UD(),
      }
    },

    // MAP5 0x5A: VCVTPH2PD (NP, W=0) — convert packed FP16 to FP64
    90 => {
      if mp != MP_NONE then { raise_UD() }
      else {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let disp_n : range(2, 16) = if pfx.evex_b then 2 else match pfx.evex_ll {
          0 => 4, 1 => 8, _ => 16,
        };
        let rm = decode_rm_evex(modrm, pfx, disp_n);
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        match pfx.evex_ll {
          2 => {
            // ZMM (8 FP64 from 8 FP16)
            let src : xmmword = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
            let r : zmmword =
              __f16_to_f64(src[127..112]) @ __f16_to_f64(src[111..96]) @
              __f16_to_f64(src[95..80]) @ __f16_to_f64(src[79..64]) @
              __f16_to_f64(src[63..48]) @ __f16_to_f64(src[47..32]) @
              __f16_to_f64(src[31..16]) @ __f16_to_f64(src[15..0]);
            write_zmm(dst, apply_writemask_pd_zmm(r, read_zmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
          },
          1 => {
            // YMM (4 FP64 from 4 FP16)
            let src : qword = match rm {
              RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[63..0],
              RM_mem(addr) => mem_read64(fixup_addr(addr)),
            };
            let r : ymmword =
              __f16_to_f64(src[63..48]) @ __f16_to_f64(src[47..32]) @
              __f16_to_f64(src[31..16]) @ __f16_to_f64(src[15..0]);
            write_ymm(dst, apply_writemask_pd_ymm(r, read_ymm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
          },
          _ => {
            // XMM (2 FP64 from 2 FP16)
            let src : dword = match rm {
              RM_reg(_) => read_xmm(evex_rm_reg_idx(modrm, pfx))[31..0],
              RM_mem(addr) => mem_read32(fixup_addr(addr)),
            };
            let r : xmmword =
              __f16_to_f64(src[31..16]) @ __f16_to_f64(src[15..0]);
            write_xmm(dst, apply_writemask_pd_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
          },
        }
      }
    },

    // MAP5 0x5B: VCVTDQ2PH (NP, W=0) or VCVTQQ2PH (W=1)
    91 => {
      if mp != MP_NONE then { raise_UD() }
      else {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        if pfx.vex_w then {
          // VCVTQQ2PH: convert packed int64 to FP16
          match pfx.evex_ll {
            2 => {
              let src = evex_bcast_src_f64_zmm(modrm, rm, pfx, is_mem);
              let r : xmmword =
                __int64_to_f16(src[511..448]) @ __int64_to_f16(src[447..384]) @
                __int64_to_f16(src[383..320]) @ __int64_to_f16(src[319..256]) @
                __int64_to_f16(src[255..192]) @ __int64_to_f16(src[191..128]) @
                __int64_to_f16(src[127..64]) @ __int64_to_f16(src[63..0]);
              write_xmm(dst, r); Ok()
            },
            _ => raise_UD(),
          }
        } else {
          // VCVTDQ2PH: convert packed int32 to FP16
          match pfx.evex_ll {
            2 => {
              let src = evex_bcast_src_f32_zmm(modrm, rm, pfx, is_mem);
              let r : ymmword =
                __int32_to_f16(src[511..480]) @ __int32_to_f16(src[479..448]) @
                __int32_to_f16(src[447..416]) @ __int32_to_f16(src[415..384]) @
                __int32_to_f16(src[383..352]) @ __int32_to_f16(src[351..320]) @
                __int32_to_f16(src[319..288]) @ __int32_to_f16(src[287..256]) @
                __int32_to_f16(src[255..224]) @ __int32_to_f16(src[223..192]) @
                __int32_to_f16(src[191..160]) @ __int32_to_f16(src[159..128]) @
                __int32_to_f16(src[127..96]) @ __int32_to_f16(src[95..64]) @
                __int32_to_f16(src[63..32]) @ __int32_to_f16(src[31..0]);
              write_ymm(dst, r); Ok()
            },
            1 => {
              let src = evex_bcast_src_f32_ymm(modrm, rm, pfx, is_mem);
              let r : xmmword =
                __int32_to_f16(src[255..224]) @ __int32_to_f16(src[223..192]) @
                __int32_to_f16(src[191..160]) @ __int32_to_f16(src[159..128]) @
                __int32_to_f16(src[127..96]) @ __int32_to_f16(src[95..64]) @
                __int32_to_f16(src[63..32]) @ __int32_to_f16(src[31..0]);
              write_xmm(dst, r); Ok()
            },
            _ => {
              let src = evex_bcast_src_f32_xmm(modrm, rm, pfx, is_mem);
              let r : qword =
                __int32_to_f16(src[127..96]) @ __int32_to_f16(src[95..64]) @
                __int32_to_f16(src[63..32]) @ __int32_to_f16(src[31..0]);
              write_xmm(dst, zero_extend(r)); Ok()
            },
          }
        }
      }
    },

    _ => raise_UD(),
  }
}

// =========================================================================
// EVEX MAP6 dispatch — FP16 FMA and special operations (66 prefix, W=0)
// =========================================================================

// FP16 FMA element-wise helpers
val vfmadd_ph_xmm : (xmmword, xmmword, xmmword) -> xmmword
function vfmadd_ph_xmm(a, b, c) =
  __f16_fmadd(a[127..112], b[127..112], c[127..112]) @
  __f16_fmadd(a[111..96], b[111..96], c[111..96]) @
  __f16_fmadd(a[95..80], b[95..80], c[95..80]) @
  __f16_fmadd(a[79..64], b[79..64], c[79..64]) @
  __f16_fmadd(a[63..48], b[63..48], c[63..48]) @
  __f16_fmadd(a[47..32], b[47..32], c[47..32]) @
  __f16_fmadd(a[31..16], b[31..16], c[31..16]) @
  __f16_fmadd(a[15..0], b[15..0], c[15..0])

val vfmadd_ph_ymm : (ymmword, ymmword, ymmword) -> ymmword
function vfmadd_ph_ymm(a, b, c) =
  vfmadd_ph_xmm(a[255..128], b[255..128], c[255..128]) @
  vfmadd_ph_xmm(a[127..0], b[127..0], c[127..0])

val vfmadd_ph_zmm : (zmmword, zmmword, zmmword) -> zmmword
function vfmadd_ph_zmm(a, b, c) =
  vfmadd_ph_ymm(a[511..256], b[511..256], c[511..256]) @
  vfmadd_ph_ymm(a[255..0], b[255..0], c[255..0])

val vfmsub_ph_xmm : (xmmword, xmmword, xmmword) -> xmmword
function vfmsub_ph_xmm(a, b, c) =
  __f16_fmsub(a[127..112], b[127..112], c[127..112]) @
  __f16_fmsub(a[111..96], b[111..96], c[111..96]) @
  __f16_fmsub(a[95..80], b[95..80], c[95..80]) @
  __f16_fmsub(a[79..64], b[79..64], c[79..64]) @
  __f16_fmsub(a[63..48], b[63..48], c[63..48]) @
  __f16_fmsub(a[47..32], b[47..32], c[47..32]) @
  __f16_fmsub(a[31..16], b[31..16], c[31..16]) @
  __f16_fmsub(a[15..0], b[15..0], c[15..0])

val vfmsub_ph_ymm : (ymmword, ymmword, ymmword) -> ymmword
function vfmsub_ph_ymm(a, b, c) =
  vfmsub_ph_xmm(a[255..128], b[255..128], c[255..128]) @
  vfmsub_ph_xmm(a[127..0], b[127..0], c[127..0])

val vfmsub_ph_zmm : (zmmword, zmmword, zmmword) -> zmmword
function vfmsub_ph_zmm(a, b, c) =
  vfmsub_ph_ymm(a[511..256], b[511..256], c[511..256]) @
  vfmsub_ph_ymm(a[255..0], b[255..0], c[255..0])

val vfnmadd_ph_xmm : (xmmword, xmmword, xmmword) -> xmmword
function vfnmadd_ph_xmm(a, b, c) =
  __f16_fnmadd(a[127..112], b[127..112], c[127..112]) @
  __f16_fnmadd(a[111..96], b[111..96], c[111..96]) @
  __f16_fnmadd(a[95..80], b[95..80], c[95..80]) @
  __f16_fnmadd(a[79..64], b[79..64], c[79..64]) @
  __f16_fnmadd(a[63..48], b[63..48], c[63..48]) @
  __f16_fnmadd(a[47..32], b[47..32], c[47..32]) @
  __f16_fnmadd(a[31..16], b[31..16], c[31..16]) @
  __f16_fnmadd(a[15..0], b[15..0], c[15..0])

val vfnmadd_ph_ymm : (ymmword, ymmword, ymmword) -> ymmword
function vfnmadd_ph_ymm(a, b, c) =
  vfnmadd_ph_xmm(a[255..128], b[255..128], c[255..128]) @
  vfnmadd_ph_xmm(a[127..0], b[127..0], c[127..0])

val vfnmadd_ph_zmm : (zmmword, zmmword, zmmword) -> zmmword
function vfnmadd_ph_zmm(a, b, c) =
  vfnmadd_ph_ymm(a[511..256], b[511..256], c[511..256]) @
  vfnmadd_ph_ymm(a[255..0], b[255..0], c[255..0])

val vfnmsub_ph_xmm : (xmmword, xmmword, xmmword) -> xmmword
function vfnmsub_ph_xmm(a, b, c) =
  __f16_fnmsub(a[127..112], b[127..112], c[127..112]) @
  __f16_fnmsub(a[111..96], b[111..96], c[111..96]) @
  __f16_fnmsub(a[95..80], b[95..80], c[95..80]) @
  __f16_fnmsub(a[79..64], b[79..64], c[79..64]) @
  __f16_fnmsub(a[63..48], b[63..48], c[63..48]) @
  __f16_fnmsub(a[47..32], b[47..32], c[47..32]) @
  __f16_fnmsub(a[31..16], b[31..16], c[31..16]) @
  __f16_fnmsub(a[15..0], b[15..0], c[15..0])

val vfnmsub_ph_ymm : (ymmword, ymmword, ymmword) -> ymmword
function vfnmsub_ph_ymm(a, b, c) =
  vfnmsub_ph_xmm(a[255..128], b[255..128], c[255..128]) @
  vfnmsub_ph_xmm(a[127..0], b[127..0], c[127..0])

val vfnmsub_ph_zmm : (zmmword, zmmword, zmmword) -> zmmword
function vfnmsub_ph_zmm(a, b, c) =
  vfnmsub_ph_ymm(a[511..256], b[511..256], c[511..256]) @
  vfnmsub_ph_ymm(a[255..0], b[255..0], c[255..0])

val dispatch_evex_map6 : (byte, Prefixes) -> ExecutionResult
function dispatch_evex_map6(opcode, pfx) = {
  let mp = get_mandatory_prefix(pfx);
  let op : range(0, 255) = unsigned(opcode);

  match op {

    // MAP6 0x98: VFMADD132PH (66, W=0)
    152 => {
      if mp != MP_66 then { raise_UD() }
      else {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
        let result : ExecutionResult = match eff_ll {
          2 => {
            let a = read_zmm(dst);
            let b = read_zmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
            let r = vfmadd_ph_zmm(a, c, b);  // 132: dest*src3 + src2
            write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
          },
          1 => {
            let a = read_ymm(dst);
            let b = read_ymm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
            let r = vfmadd_ph_ymm(a, c, b);
            write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
          },
          _ => {
            let a = read_xmm(dst);
            let b = read_xmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
            let r = vfmadd_ph_xmm(a, c, b);
            write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
          },
        };
        evex_end_rc(saved);
        result
      }
    },

    // MAP6 0xA8: VFMADD213PH (66, W=0)
    168 => {
      if mp != MP_66 then { raise_UD() }
      else {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
        let result : ExecutionResult = match eff_ll {
          2 => {
            let a = read_zmm(dst);
            let b = read_zmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
            let r = vfmadd_ph_zmm(b, a, c);  // 213: src2*dest + src3
            write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
          },
          1 => {
            let a = read_ymm(dst);
            let b = read_ymm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
            let r = vfmadd_ph_ymm(b, a, c);
            write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
          },
          _ => {
            let a = read_xmm(dst);
            let b = read_xmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
            let r = vfmadd_ph_xmm(b, a, c);
            write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
          },
        };
        evex_end_rc(saved);
        result
      }
    },

    // MAP6 0xB8: VFMADD231PH (66, W=0)
    184 => {
      if mp != MP_66 then { raise_UD() }
      else {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
        let result : ExecutionResult = match eff_ll {
          2 => {
            let a = read_zmm(dst);
            let b = read_zmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
            let r = vfmadd_ph_zmm(b, c, a);  // 231: src2*src3 + dest
            write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
          },
          1 => {
            let a = read_ymm(dst);
            let b = read_ymm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
            let r = vfmadd_ph_ymm(b, c, a);
            write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
          },
          _ => {
            let a = read_xmm(dst);
            let b = read_xmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
            let r = vfmadd_ph_xmm(b, c, a);
            write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
          },
        };
        evex_end_rc(saved);
        result
      }
    },

    // MAP6 0x9A: VFMSUB132PH (66, W=0)
    154 => {
      if mp != MP_66 then { raise_UD() }
      else {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
        let result : ExecutionResult = match eff_ll {
          2 => {
            let a = read_zmm(dst);
            let b = read_zmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
            let r = vfmsub_ph_zmm(a, c, b);  // 132: dest*src3 - src2
            write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
          },
          1 => {
            let a = read_ymm(dst);
            let b = read_ymm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
            let r = vfmsub_ph_ymm(a, c, b);
            write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
          },
          _ => {
            let a = read_xmm(dst);
            let b = read_xmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
            let r = vfmsub_ph_xmm(a, c, b);
            write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
          },
        };
        evex_end_rc(saved);
        result
      }
    },

    // MAP6 0xAA: VFMSUB213PH (66, W=0)
    170 => {
      if mp != MP_66 then { raise_UD() }
      else {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
        let result : ExecutionResult = match eff_ll {
          2 => {
            let a = read_zmm(dst);
            let b = read_zmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
            let r = vfmsub_ph_zmm(b, a, c);  // 213: src2*dest - src3
            write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
          },
          1 => {
            let a = read_ymm(dst);
            let b = read_ymm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
            let r = vfmsub_ph_ymm(b, a, c);
            write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
          },
          _ => {
            let a = read_xmm(dst);
            let b = read_xmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
            let r = vfmsub_ph_xmm(b, a, c);
            write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
          },
        };
        evex_end_rc(saved);
        result
      }
    },

    // MAP6 0xBA: VFMSUB231PH (66, W=0)
    186 => {
      if mp != MP_66 then { raise_UD() }
      else {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
        let result : ExecutionResult = match eff_ll {
          2 => {
            let a = read_zmm(dst);
            let b = read_zmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
            let r = vfmsub_ph_zmm(b, c, a);  // 231: src2*src3 - dest
            write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
          },
          1 => {
            let a = read_ymm(dst);
            let b = read_ymm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
            let r = vfmsub_ph_ymm(b, c, a);
            write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
          },
          _ => {
            let a = read_xmm(dst);
            let b = read_xmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
            let r = vfmsub_ph_xmm(b, c, a);
            write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
          },
        };
        evex_end_rc(saved);
        result
      }
    },

    // MAP6 0x9C: VFNMADD132PH (66, W=0)
    156 => {
      if mp != MP_66 then { raise_UD() }
      else {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
        let result : ExecutionResult = match eff_ll {
          2 => {
            let a = read_zmm(dst);
            let b = read_zmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
            let r = vfnmadd_ph_zmm(a, c, b);  // 132: -dest*src3 + src2
            write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
          },
          1 => {
            let a = read_ymm(dst);
            let b = read_ymm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
            let r = vfnmadd_ph_ymm(a, c, b);
            write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
          },
          _ => {
            let a = read_xmm(dst);
            let b = read_xmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
            let r = vfnmadd_ph_xmm(a, c, b);
            write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
          },
        };
        evex_end_rc(saved);
        result
      }
    },

    // MAP6 0xAC: VFNMADD213PH (66, W=0)
    172 => {
      if mp != MP_66 then { raise_UD() }
      else {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
        let result : ExecutionResult = match eff_ll {
          2 => {
            let a = read_zmm(dst);
            let b = read_zmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
            let r = vfnmadd_ph_zmm(b, a, c);  // 213: -src2*dest + src3
            write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
          },
          1 => {
            let a = read_ymm(dst);
            let b = read_ymm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
            let r = vfnmadd_ph_ymm(b, a, c);
            write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
          },
          _ => {
            let a = read_xmm(dst);
            let b = read_xmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
            let r = vfnmadd_ph_xmm(b, a, c);
            write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
          },
        };
        evex_end_rc(saved);
        result
      }
    },

    // MAP6 0xBC: VFNMADD231PH (66, W=0)
    188 => {
      if mp != MP_66 then { raise_UD() }
      else {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
        let result : ExecutionResult = match eff_ll {
          2 => {
            let a = read_zmm(dst);
            let b = read_zmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
            let r = vfnmadd_ph_zmm(b, c, a);  // 231: -src2*src3 + dest
            write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
          },
          1 => {
            let a = read_ymm(dst);
            let b = read_ymm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
            let r = vfnmadd_ph_ymm(b, c, a);
            write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
          },
          _ => {
            let a = read_xmm(dst);
            let b = read_xmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
            let r = vfnmadd_ph_xmm(b, c, a);
            write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
          },
        };
        evex_end_rc(saved);
        result
      }
    },

    // MAP6 0x9E: VFNMSUB132PH (66, W=0)
    158 => {
      if mp != MP_66 then { raise_UD() }
      else {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
        let result : ExecutionResult = match eff_ll {
          2 => {
            let a = read_zmm(dst);
            let b = read_zmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
            let r = vfnmsub_ph_zmm(a, c, b);  // 132: -dest*src3 - src2
            write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
          },
          1 => {
            let a = read_ymm(dst);
            let b = read_ymm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
            let r = vfnmsub_ph_ymm(a, c, b);
            write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
          },
          _ => {
            let a = read_xmm(dst);
            let b = read_xmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
            let r = vfnmsub_ph_xmm(a, c, b);
            write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
          },
        };
        evex_end_rc(saved);
        result
      }
    },

    // MAP6 0xAE: VFNMSUB213PH (66, W=0)
    174 => {
      if mp != MP_66 then { raise_UD() }
      else {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
        let result : ExecutionResult = match eff_ll {
          2 => {
            let a = read_zmm(dst);
            let b = read_zmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
            let r = vfnmsub_ph_zmm(b, a, c);  // 213: -src2*dest - src3
            write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
          },
          1 => {
            let a = read_ymm(dst);
            let b = read_ymm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
            let r = vfnmsub_ph_ymm(b, a, c);
            write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
          },
          _ => {
            let a = read_xmm(dst);
            let b = read_xmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
            let r = vfnmsub_ph_xmm(b, a, c);
            write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
          },
        };
        evex_end_rc(saved);
        result
      }
    },

    // MAP6 0xBE: VFNMSUB231PH (66, W=0)
    190 => {
      if mp != MP_66 then { raise_UD() }
      else {
        let modrm = fetch_byte();
        let dst = evex_reg_idx(modrm, pfx);
        let rm = decode_rm_evex(modrm, pfx, evex_full_disp_n_fp16(pfx));
        let is_mem : bool = match rm { RM_mem(_) => true, _ => false };
        let (eff_ll, saved) = evex_begin_rc(pfx, not_bool(is_mem));
        let result : ExecutionResult = match eff_ll {
          2 => {
            let a = read_zmm(dst);
            let b = read_zmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_zmm(modrm, rm, pfx, is_mem);
            let r = vfnmsub_ph_zmm(b, c, a);  // 231: -src2*src3 - dest
            write_zmm(dst, apply_writemask_ph_zmm(r, read_zmm(dst), evex_get_mask32(pfx), pfx.evex_z)); Ok()
          },
          1 => {
            let a = read_ymm(dst);
            let b = read_ymm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_ymm(modrm, rm, pfx, is_mem);
            let r = vfnmsub_ph_ymm(b, c, a);
            write_ymm(dst, apply_writemask_ph_ymm(r, read_ymm(dst), evex_get_mask16(pfx), pfx.evex_z)); Ok()
          },
          _ => {
            let a = read_xmm(dst);
            let b = read_xmm(pfx.evex_vvvvv);
            let c = evex_bcast_src_f16_xmm(modrm, rm, pfx, is_mem);
            let r = vfnmsub_ph_xmm(b, c, a);
            write_xmm(dst, apply_writemask_ph_xmm(r, read_xmm(dst), evex_get_mask8(pfx), pfx.evex_z)); Ok()
          },
        };
        evex_end_rc(saved);
        result
      }
    },

    _ => raise_UD(),
  }
}

// x86-64 Decoder — VEX Prefix Decoding and Dispatch
//
// Handles 2-byte VEX (C5h) and 3-byte VEX (C4h) prefixes.
// In 64-bit mode, C4/C5 are always VEX prefixes (LES/LDS are invalid).
//
// VEX replaces REX + mandatory prefix + opcode escape bytes.
// 2-byte VEX (C5): [C5] [R̄.vvvv.L.pp]       — implies map 0F
// 3-byte VEX (C4): [C4] [R̄.X̄.B̄.mmmmm] [W.vvvv.L.pp]

// =========================================================================
// 128-bit packed FP helpers — lane operations for AVX
// =========================================================================

val vaddps_xmm : (xmmword, xmmword) -> xmmword
function vaddps_xmm(a, b) =
  __f32_add(a[127..96], b[127..96]) @
  __f32_add(a[95..64],  b[95..64])  @
  __f32_add(a[63..32],  b[63..32])  @
  __f32_add(a[31..0],   b[31..0])

val vsubps_xmm : (xmmword, xmmword) -> xmmword
function vsubps_xmm(a, b) =
  __f32_sub(a[127..96], b[127..96]) @
  __f32_sub(a[95..64],  b[95..64])  @
  __f32_sub(a[63..32],  b[63..32])  @
  __f32_sub(a[31..0],   b[31..0])

val vmulps_xmm : (xmmword, xmmword) -> xmmword
function vmulps_xmm(a, b) =
  __f32_mul(a[127..96], b[127..96]) @
  __f32_mul(a[95..64],  b[95..64])  @
  __f32_mul(a[63..32],  b[63..32])  @
  __f32_mul(a[31..0],   b[31..0])

val vdivps_xmm : (xmmword, xmmword) -> xmmword
function vdivps_xmm(a, b) =
  __f32_div(a[127..96], b[127..96]) @
  __f32_div(a[95..64],  b[95..64])  @
  __f32_div(a[63..32],  b[63..32])  @
  __f32_div(a[31..0],   b[31..0])

val vminps_xmm : (xmmword, xmmword) -> xmmword
function vminps_xmm(a, b) =
  __f32_min(a[127..96], b[127..96]) @
  __f32_min(a[95..64],  b[95..64])  @
  __f32_min(a[63..32],  b[63..32])  @
  __f32_min(a[31..0],   b[31..0])

val vmaxps_xmm : (xmmword, xmmword) -> xmmword
function vmaxps_xmm(a, b) =
  __f32_max(a[127..96], b[127..96]) @
  __f32_max(a[95..64],  b[95..64])  @
  __f32_max(a[63..32],  b[63..32])  @
  __f32_max(a[31..0],   b[31..0])

val vsqrtps_xmm : xmmword -> xmmword
function vsqrtps_xmm(a) =
  __f32_sqrt(a[127..96]) @ __f32_sqrt(a[95..64]) @
  __f32_sqrt(a[63..32])  @ __f32_sqrt(a[31..0])

val vaddpd_xmm : (xmmword, xmmword) -> xmmword
function vaddpd_xmm(a, b) =
  __f64_add(a[127..64], b[127..64]) @ __f64_add(a[63..0], b[63..0])

val vsubpd_xmm : (xmmword, xmmword) -> xmmword
function vsubpd_xmm(a, b) =
  __f64_sub(a[127..64], b[127..64]) @ __f64_sub(a[63..0], b[63..0])

val vmulpd_xmm : (xmmword, xmmword) -> xmmword
function vmulpd_xmm(a, b) =
  __f64_mul(a[127..64], b[127..64]) @ __f64_mul(a[63..0], b[63..0])

val vdivpd_xmm : (xmmword, xmmword) -> xmmword
function vdivpd_xmm(a, b) =
  __f64_div(a[127..64], b[127..64]) @ __f64_div(a[63..0], b[63..0])

val vminpd_xmm : (xmmword, xmmword) -> xmmword
function vminpd_xmm(a, b) =
  __f64_min(a[127..64], b[127..64]) @ __f64_min(a[63..0], b[63..0])

val vmaxpd_xmm : (xmmword, xmmword) -> xmmword
function vmaxpd_xmm(a, b) =
  __f64_max(a[127..64], b[127..64]) @ __f64_max(a[63..0], b[63..0])

val vsqrtpd_xmm : xmmword -> xmmword
function vsqrtpd_xmm(a) =
  __f64_sqrt(a[127..64]) @ __f64_sqrt(a[63..0])

// =========================================================================
// 128-bit packed integer add/sub helpers
// =========================================================================

val avx_paddb_128 : (xmmword, xmmword) -> xmmword
function avx_paddb_128(a, b) =
  (a[127..120] + b[127..120]) @ (a[119..112] + b[119..112]) @
  (a[111..104] + b[111..104]) @ (a[103..96]  + b[103..96])  @
  (a[95..88]   + b[95..88])   @ (a[87..80]   + b[87..80])   @
  (a[79..72]   + b[79..72])   @ (a[71..64]   + b[71..64])   @
  (a[63..56]   + b[63..56])   @ (a[55..48]   + b[55..48])   @
  (a[47..40]   + b[47..40])   @ (a[39..32]   + b[39..32])   @
  (a[31..24]   + b[31..24])   @ (a[23..16]   + b[23..16])   @
  (a[15..8]    + b[15..8])    @ (a[7..0]     + b[7..0])

val avx_paddw_128 : (xmmword, xmmword) -> xmmword
function avx_paddw_128(a, b) =
  (a[127..112] + b[127..112]) @ (a[111..96] + b[111..96]) @
  (a[95..80]   + b[95..80])   @ (a[79..64]  + b[79..64])  @
  (a[63..48]   + b[63..48])   @ (a[47..32]  + b[47..32])  @
  (a[31..16]   + b[31..16])   @ (a[15..0]   + b[15..0])

val avx_paddd_128 : (xmmword, xmmword) -> xmmword
function avx_paddd_128(a, b) =
  (a[127..96] + b[127..96]) @ (a[95..64] + b[95..64]) @
  (a[63..32]  + b[63..32])  @ (a[31..0]  + b[31..0])

val avx_paddq_128 : (xmmword, xmmword) -> xmmword
function avx_paddq_128(a, b) =
  (a[127..64] + b[127..64]) @ (a[63..0] + b[63..0])

val avx_psubb_128 : (xmmword, xmmword) -> xmmword
function avx_psubb_128(a, b) =
  (a[127..120] - b[127..120]) @ (a[119..112] - b[119..112]) @
  (a[111..104] - b[111..104]) @ (a[103..96]  - b[103..96])  @
  (a[95..88]   - b[95..88])   @ (a[87..80]   - b[87..80])   @
  (a[79..72]   - b[79..72])   @ (a[71..64]   - b[71..64])   @
  (a[63..56]   - b[63..56])   @ (a[55..48]   - b[55..48])   @
  (a[47..40]   - b[47..40])   @ (a[39..32]   - b[39..32])   @
  (a[31..24]   - b[31..24])   @ (a[23..16]   - b[23..16])   @
  (a[15..8]    - b[15..8])    @ (a[7..0]     - b[7..0])

val avx_psubw_128 : (xmmword, xmmword) -> xmmword
function avx_psubw_128(a, b) =
  (a[127..112] - b[127..112]) @ (a[111..96] - b[111..96]) @
  (a[95..80]   - b[95..80])   @ (a[79..64]  - b[79..64])  @
  (a[63..48]   - b[63..48])   @ (a[47..32]  - b[47..32])  @
  (a[31..16]   - b[31..16])   @ (a[15..0]   - b[15..0])

val avx_psubd_128 : (xmmword, xmmword) -> xmmword
function avx_psubd_128(a, b) =
  (a[127..96] - b[127..96]) @ (a[95..64] - b[95..64]) @
  (a[63..32]  - b[63..32])  @ (a[31..0]  - b[31..0])

val avx_psubq_128 : (xmmword, xmmword) -> xmmword
function avx_psubq_128(a, b) =
  (a[127..64] - b[127..64]) @ (a[63..0] - b[63..0])

// Decode a 2-byte VEX prefix (C5 already consumed, byte1 is the payload).
// Returns (Prefixes, opcode_map) where opcode_map is always 1 (0F).
val decode_vex2 : byte -> (Prefixes, range(0, 31))
function decode_vex2(byte1) = {
  let pfx = {default_prefixes() with
    vex_present = true,
    // R̄ is bit 7 (inverted)
    rex_r = not_bool(byte1[7] == bitone),
    // vvvv is bits 6:3 (inverted)
    vex_vvvv = 15 - unsigned(byte1[6..3]),
    // L is bit 2
    vex_l = byte1[2] == bitone,
    // pp is bits 1:0 — map to mandatory prefix flags
    has_opsize = byte1[1..0] == 0b01,
    has_rep    = byte1[1..0] == 0b10,
    has_repne  = byte1[1..0] == 0b11,
    has_rex = true, // VEX implies REX-like behavior
  };
  (pfx, 1) // map = 0F
}

// Decode a 3-byte VEX prefix (C4 already consumed, byte1 and byte2 follow).
val decode_vex3 : (byte, byte) -> (Prefixes, range(0, 31))
function decode_vex3(byte1, byte2) = {
  let mmmmm : range(0, 31) = unsigned(byte1[4..0]);
  let pfx = {default_prefixes() with
    vex_present = true,
    // R̄, X̄, B̄ are bits 7, 6, 5 of byte1 (inverted)
    rex_r = not_bool(byte1[7] == bitone),
    rex_x = not_bool(byte1[6] == bitone),
    rex_b = not_bool(byte1[5] == bitone),
    // W is bit 7 of byte2
    vex_w = byte2[7] == bitone,
    rex_w = byte2[7] == bitone,
    // vvvv is bits 6:3 of byte2 (inverted)
    vex_vvvv = 15 - unsigned(byte2[6..3]),
    // L is bit 2 of byte2
    vex_l = byte2[2] == bitone,
    // pp is bits 1:0 of byte2
    has_opsize = byte2[1..0] == 0b01,
    has_rep    = byte2[1..0] == 0b10,
    has_repne  = byte2[1..0] == 0b11,
    has_rex = true,
  };
  (pfx, mmmmm)
}

// Helper: decode VEX XMM/YMM source from ModR/M r/m field.
// Returns (xmm_value, ymm_value, is_memory, effective_addr).
// For register operands, reads the register. For memory, loads from memory.
val decode_vex_src_xmm : (byte, RM, Prefixes) -> xmmword
function decode_vex_src_xmm(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
  RM_mem(addr) => mem_read128(fixup_addr(addr)),
}

val decode_vex_src_ymm : (byte, RM, Prefixes) -> ymmword
function decode_vex_src_ymm(modrm, rm, pfx) = match rm {
  RM_reg(_) => read_ymm(modrm_xmm_rm(modrm, pfx)),
  RM_mem(addr) => mem_read256(fixup_addr(addr)),
}

// =========================================================================
// FP16 <-> FP32 conversion helpers (used by VEX VCVTPH2PS/VCVTPS2PH and EVEX)
// =========================================================================

val fp16_to_fp32 : bits(16) -> bits(32)
function fp16_to_fp32(h) = {
  let sign : bits(1) = h[15..15];
  let exp5 : bits(5) = h[14..10];
  let frac10 : bits(10) = h[9..0];
  if exp5 == 0b11111 then {
    sign @ 0xFF @ frac10 @ 0b0000000000000
  } else if exp5 == 0b00000 then {
    if frac10 == zeros() then {
      sign @ 0x00000000[30..0]
    } else {
      var shift : int = 0;
      let f : bits(10) = frac10;
      var done : bool = false;
      foreach (i from 9 downto 0) {
        if not_bool(done) & f[i] == bitzero then shift = shift + 1
        else done = true
      };
      let new_exp : int = 112 - shift;
      let shifted : bits(10) = sail_shiftleft(frac10, shift + 1);
      sign @ get_slice_int(8, new_exp, 0) @ shifted @ 0b0000000000000
    }
  } else {
    let new_exp : bits(8) = sail_zero_extend(exp5, 8) + 0x70;
    sign @ new_exp @ frac10 @ 0b0000000000000
  }
}

val fp32_to_fp16 : bits(32) -> bits(16)
function fp32_to_fp16(f) = {
  let sign : bits(1) = f[31..31];
  let exp8 : bits(8) = f[30..23];
  let frac23 : bits(23) = f[22..0];
  let exp_val : int = unsigned(exp8);
  if exp8 == 0xFF then {
    if frac23 == zeros() then sign @ 0b11111 @ 0b0000000000
    else sign @ 0b11111 @ frac23[22..13]
  } else if exp_val > 142 then {
    sign @ 0b11111 @ 0b0000000000
  } else if exp_val < 103 then {
    sign @ 0b00000 @ 0b0000000000
  } else if exp_val < 113 then {
    let shift_amt : int = 113 - exp_val;
    let full_frac : bits(24) = 0b1 @ frac23;
    let shifted : bits(24) = sail_shiftright(full_frac, shift_amt);
    sign @ 0b00000 @ shifted[9..0]
  } else {
    let new_exp : int = exp_val - 112;
    sign @ get_slice_int(5, new_exp, 0) @ frac23[22..13]
  }
}

val avx_vcvtph2ps_128 : bits(64) -> xmmword
function avx_vcvtph2ps_128(src) = {
  fp16_to_fp32(src[63..48]) @ fp16_to_fp32(src[47..32]) @
  fp16_to_fp32(src[31..16]) @ fp16_to_fp32(src[15..0])
}

val avx_vcvtps2ph_128 : xmmword -> bits(64)
function avx_vcvtps2ph_128(src) = {
  fp32_to_fp16(src[127..96]) @ fp32_to_fp16(src[95..64]) @
  fp32_to_fp16(src[63..32]) @ fp32_to_fp16(src[31..0])
}

val avx_vcvtph2ps_256 : xmmword -> ymmword
function avx_vcvtph2ps_256(src) = {
  avx_vcvtph2ps_128(src[127..64]) @ avx_vcvtph2ps_128(src[63..0])
}

val avx_vcvtps2ph_256 : ymmword -> xmmword
function avx_vcvtps2ph_256(src) = {
  avx_vcvtps2ph_128(src[255..128]) @ avx_vcvtps2ph_128(src[127..0])
}

// =========================================================================
// VEX 0F map dispatch (AVX versions of SSE instructions)
// =========================================================================

val dispatch_vex_0f : (byte, Prefixes) -> ExecutionResult
function dispatch_vex_0f(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F 10: VMOVUPS/VMOVUPD/VMOVSS/VMOVSD (load)
  16 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => // VMOVUPS (vvvv reserved)
        if pfx.vex_vvvv != 0 then { raise_UD() } else if pfx.vex_l then {
          let src = decode_vex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, src);
          Ok()
        } else { let src = decode_vex_src_xmm(modrm, rm, pfx); write_xmm(dst, src); Ok() },
      MP_66 => // VMOVUPD (vvvv reserved)
        if pfx.vex_vvvv != 0 then { raise_UD() } else if pfx.vex_l then {
          let src = decode_vex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, src);
          Ok()
        } else { let src = decode_vex_src_xmm(modrm, rm, pfx); write_xmm(dst, src); Ok() },
      MP_F3 => { // VMOVSS xmm1, xmm2, xmm3 or xmm1, m32
        match rm {
          RM_reg(_) => {
            // reg-reg: merge src2[127:32] with src3[31:0]
            let src2 : xmmword = read_xmm(pfx.vex_vvvv);
            let src3 : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, src2[127..32] @ src3[31..0]);
            Ok()
          },
          RM_mem(addr) => {
            // mem: load 32 bits, zero-extend to 128
            let v : dword = mem_read32(fixup_addr(addr));
            write_xmm(dst, zeros(96) @ v);
            Ok()
          },
        }
      },
      MP_F2 => { // VMOVSD xmm1, xmm2, xmm3 or xmm1, m64
        match rm {
          RM_reg(_) => {
            let src2 : xmmword = read_xmm(pfx.vex_vvvv);
            let src3 : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, src2[127..64] @ src3[63..0]);
            Ok()
          },
          RM_mem(addr) => {
            let v : qword = mem_read64(fixup_addr(addr));
            write_xmm(dst, zeros(64) @ v);
            Ok()
          },
        }
      },
    }
  },

  // 0F 11: VMOVUPS/VMOVUPD/VMOVSS/VMOVSD (store)
  17 => {
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => // VMOVUPS (vvvv reserved)
        if pfx.vex_vvvv != 0 then { raise_UD() } else match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            if pfx.vex_l then {
              write_ymm(dst, read_ymm(src)); Ok()
            } else {
              write_xmm(dst, read_xmm(src)); Ok()
            }
          },
          RM_mem(addr) => {
            let a = fixup_addr(addr);
            if pfx.vex_l then {
              mem_write256(a, read_ymm(src)); Ok()
            } else {
              mem_write128(a, read_xmm(src)); Ok()
            }
          },
        },
      MP_66 => // VMOVUPD (vvvv reserved)
        if pfx.vex_vvvv != 0 then { raise_UD() } else match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            if pfx.vex_l then {
              write_ymm(dst, read_ymm(src)); Ok()
            } else {
              write_xmm(dst, read_xmm(src)); Ok()
            }
          },
          RM_mem(addr) => {
            let a = fixup_addr(addr);
            if pfx.vex_l then {
              mem_write256(a, read_ymm(src)); Ok()
            } else {
              mem_write128(a, read_xmm(src)); Ok()
            }
          },
        },
      MP_F3 => { // VMOVSS store
        match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            let src2 : xmmword = read_xmm(pfx.vex_vvvv);
            let src3 : xmmword = read_xmm(src);
            write_xmm(dst, src2[127..32] @ src3[31..0]);
            Ok()
          },
          RM_mem(addr) => { mem_write32(fixup_addr(addr), read_xmm(src)[31..0]); Ok() },
        }
      },
      MP_F2 => { // VMOVSD store
        match rm {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            let src2 : xmmword = read_xmm(pfx.vex_vvvv);
            let src3 : xmmword = read_xmm(src);
            write_xmm(dst, src2[127..64] @ src3[63..0]);
            Ok()
          },
          RM_mem(addr) => { mem_write64(fixup_addr(addr), read_xmm(src)[63..0]); Ok() },
        }
      },
    }
  },

  // 0F 28: VMOVAPS/VMOVAPD (load)
  // SDM: VEX.vvvv must be 1111b
  40 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match rm {
      RM_reg(_) => {
        if pfx.vex_l then {
          write_ymm(dst, read_ymm(modrm_xmm_rm(modrm, pfx)));
        } else {
          write_xmm(dst, read_xmm(modrm_xmm_rm(modrm, pfx)));
        };
        Ok()
      },
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        // VMOVAPS/VMOVAPD require alignment: 32 for YMM, 16 for XMM; #GP(0) if unaligned
        if pfx.vex_l then {
          if unsigned(a) % 32 != 0 then {
            raise_GP0()
          } else {
            write_ymm(dst, mem_read256(a));
            Ok()
          }
        } else {
          if unsigned(a) % 16 != 0 then {
            raise_GP0()
          } else {
            write_xmm(dst, mem_read128(a));
            Ok()
          }
        }
      },
    }
    }
  },

  // 0F 29: VMOVAPS/VMOVAPD (store)
  // SDM: VEX.vvvv must be 1111b
  41 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else {
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match rm {
      RM_reg(_) => {
        let dst = modrm_xmm_rm(modrm, pfx);
        if pfx.vex_l then {
          write_ymm(dst, read_ymm(src)); Ok()
        } else {
          write_xmm(dst, read_xmm(src)); Ok()
        }
      },
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        // VMOVAPS/VMOVAPD require alignment: 32 for YMM, 16 for XMM; #GP(0) if unaligned
        if pfx.vex_l then {
          if unsigned(a) % 32 != 0 then {
            raise_GP0()
          } else {
            mem_write256(a, read_ymm(src)); Ok()
          }
        } else {
          if unsigned(a) % 16 != 0 then {
            raise_GP0()
          } else {
            mem_write128(a, read_xmm(src)); Ok()
          }
        }
      },
    }
    }
  },

  // 0F 2E: VUCOMISS (NP) / VUCOMISD (66) — unordered compare scalars, set EFLAGS
  // SDM: VEX.vvvv must be 1111b
  46 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else {
    let modrm = fetch_byte();
    let src_reg = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => { // VUCOMISS
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read32(fixup_addr(addr))),
        };
        let a : dword = read_xmm(src_reg)[31..0];
        let b : dword = src[31..0];
        match __compare_ss(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok()
      },
      MP_66 => { // VUCOMISD
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read64(fixup_addr(addr))),
        };
        let a : qword = read_xmm(src_reg)[63..0];
        let b : qword = src[63..0];
        match __compare_sd(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok()
      },
      _ => raise_UD(),
    }
    }
  },

  // 0F 2F: VCOMISS (NP) / VCOMISD (66) — ordered compare scalars, set EFLAGS
  // SDM: VEX.vvvv must be 1111b
  47 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else {
    let modrm = fetch_byte();
    let src_reg = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => { // VCOMISS
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read32(fixup_addr(addr))),
        };
        let a : dword = read_xmm(src_reg)[31..0];
        let b : dword = src[31..0];
        match __compare_ss(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok()
      },
      MP_66 => { // VCOMISD
        let src : xmmword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(addr) => zero_extend(mem_read64(fixup_addr(addr))),
        };
        let a : qword = read_xmm(src_reg)[63..0];
        let b : qword = src[63..0];
        match __compare_sd(a, b) {
          FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
          FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
          FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
          FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
        };
        OF = bitzero; SF = bitzero; AF = bitzero;
        Ok()
      },
      _ => raise_UD(),
    }
    }
  },

  // 0F 14: VUNPCKLPS (NP) / VUNPCKLPD (66)
  20 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      match mp {
        MP_NONE => { // VUNPCKLPS ymm
          let lo = src2[63..32] @ src1[63..32] @ src2[31..0] @ src1[31..0];
          let hi = src2[191..160] @ src1[191..160] @ src2[159..128] @ src1[159..128];
          write_ymm(dst, hi @ lo);
          Ok()
        },
        MP_66 => { // VUNPCKLPD ymm
          let lo = src2[63..0] @ src1[63..0];
          let hi = src2[191..128] @ src1[191..128];
          write_ymm(dst, hi @ lo);
          Ok()
        },
        _ => raise_UD(),
      }
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      match mp {
        MP_NONE => { write_xmm(dst, src2[63..32] @ src1[63..32] @ src2[31..0] @ src1[31..0]); Ok() },
        MP_66   => { write_xmm(dst, src2[63..0] @ src1[63..0]); Ok() },
        _ => raise_UD(),
      }
    }
  },

  // 0F 15: VUNPCKHPS (NP) / VUNPCKHPD (66)
  21 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      match mp {
        MP_NONE => { // VUNPCKHPS ymm
          let lo = src2[127..96] @ src1[127..96] @ src2[95..64] @ src1[95..64];
          let hi = src2[255..224] @ src1[255..224] @ src2[223..192] @ src1[223..192];
          write_ymm(dst, hi @ lo);
          Ok()
        },
        MP_66 => { // VUNPCKHPD ymm
          let lo = src2[127..64] @ src1[127..64];
          let hi = src2[255..192] @ src1[255..192];
          write_ymm(dst, hi @ lo);
          Ok()
        },
        _ => raise_UD(),
      }
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      match mp {
        MP_NONE => { write_xmm(dst, src2[127..96] @ src1[127..96] @ src2[95..64] @ src1[95..64]); Ok() },
        MP_66   => { write_xmm(dst, src2[127..64] @ src1[127..64]); Ok() },
        _ => raise_UD(),
      }
    }
  },

  // 0F 12: VMOVLPS/VMOVHLPS (NP) / VMOVLPD (66) / VMOVSLDUP (F3) / VMOVDDUP (F2)
  18 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => {
        match rm {
          RM_reg(_) => { // VMOVHLPS: dst[63:0] = src2[127:64], dst[127:64] = vvvv[127:64]
            let src1 : xmmword = read_xmm(pfx.vex_vvvv);
            let src2 : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, src1[127..64] @ src2[127..64]);
            Ok()
          },
          RM_mem(addr) => { // VMOVLPS: dst[63:0] = m64, dst[127:64] = vvvv[127:64]
            let src1 : xmmword = read_xmm(pfx.vex_vvvv);
            let v : qword = mem_read64(fixup_addr(addr));
            write_xmm(dst, src1[127..64] @ v);
            Ok()
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 16: VMOVHPS/VMOVLHPS (NP) / VMOVHPD (66) / VMOVSHDUP (F3)
  22 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => {
        match rm {
          RM_reg(_) => { // VMOVLHPS: dst[127:64] = src2[63:0], dst[63:0] = vvvv[63:0]
            let src1 : xmmword = read_xmm(pfx.vex_vvvv);
            let src2 : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, src2[63..0] @ src1[63..0]);
            Ok()
          },
          RM_mem(addr) => { // VMOVHPS: dst[63:0] = vvvv[63:0], dst[127:64] = m64
            let src1 : xmmword = read_xmm(pfx.vex_vvvv);
            let v : qword = mem_read64(fixup_addr(addr));
            write_xmm(dst, v @ src1[63..0]);
            Ok()
          },
        }
      },
      _ => raise_UD(),
    }
  },

  // 0F 2A: VCVTSI2SS (F3) / VCVTSI2SD (F2) — int to scalar float
  42 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let src1 : xmmword = read_xmm(pfx.vex_vvvv);
    match mp {
      MP_F3 => { // VCVTSI2SS
        if pfx.vex_w then {
          let v : qword = match rm { RM_reg(idx) => read_gpr64(idx), RM_mem(addr) => mem_read64(fixup_addr(addr)) };
          write_xmm(dst, src1[127..32] @ __int64_to_f32(v));
        } else {
          let v : dword = match rm { RM_reg(idx) => read_gpr32(idx), RM_mem(addr) => mem_read32(fixup_addr(addr)) };
          write_xmm(dst, src1[127..32] @ __int32_to_f32(v));
        };
        Ok()
      },
      MP_F2 => { // VCVTSI2SD
        if pfx.vex_w then {
          let v : qword = match rm { RM_reg(idx) => read_gpr64(idx), RM_mem(addr) => mem_read64(fixup_addr(addr)) };
          write_xmm(dst, src1[127..64] @ __int64_to_f64(v));
        } else {
          let v : dword = match rm { RM_reg(idx) => read_gpr32(idx), RM_mem(addr) => mem_read32(fixup_addr(addr)) };
          write_xmm(dst, src1[127..64] @ __int32_to_f64(v));
        };
        Ok()
      },
      _ => raise_UD(),
    }
  },

  // 0F 2C: VCVTTSS2SI (F3) / VCVTTSD2SI (F2) — truncating scalar float to int
  44 => {
    let modrm = fetch_byte();
    let rm = decode_rm(modrm, pfx);
    let dst_gpr = modrm_reg(modrm, pfx);
    match mp {
      MP_F3 => { // VCVTTSS2SI
        let src : dword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        if pfx.vex_w then write_gpr64(dst_gpr, __f32_to_int64_trunc(src))
        else write_gpr32(dst_gpr, __f32_to_int32_trunc(src));
        Ok()
      },
      MP_F2 => { // VCVTTSD2SI
        let src : qword = match rm {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        if pfx.vex_w then write_gpr64(dst_gpr, __f64_to_int64_trunc(src))
        else write_gpr32(dst_gpr, __f64_to_int32_trunc(src));
        Ok()
      },
      _ => raise_UD(),
    }
  },

  // 0F 41: KANDW k1, k2, k3 (NP, W0)
  65 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = pfx.vex_vvvv % 8;
    let k3 : range(0, 7) = unsigned(modrm[2..0]);
    let result : qword = read_kreg(k2) & read_kreg(k3);
    write_kreg(k1, zero_extend(result[15..0]));
    Ok()
  },

  // 0F 44: KNOTW k1, k2 (NP, W0)
  68 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = unsigned(modrm[2..0]);
    write_kreg(k1, zero_extend(~(read_kreg(k2)[15..0])));
    Ok()
  },

  // 0F 47: KXORW k1, k2, k3 (NP, W0)
  71 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = pfx.vex_vvvv % 8;
    let k3 : range(0, 7) = unsigned(modrm[2..0]);
    let result : qword = xor_vec(read_kreg(k2), read_kreg(k3));
    write_kreg(k1, zero_extend(result[15..0]));
    Ok()
  },

  // 0F 4A: KADDW k1, k2, k3 (NP, W0)
  74 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let k2 : range(0, 7) = pfx.vex_vvvv % 8;
    let k3 : range(0, 7) = unsigned(modrm[2..0]);
    let sum : bits(16) = read_kreg(k2)[15..0] + read_kreg(k3)[15..0];
    write_kreg(k1, zero_extend(sum));
    Ok()
  },

  // 0F 92: KMOVW r32 -> k (NP, W0) / KMOVB/D/Q variants
  146 => {
    let modrm = fetch_byte();
    let k1 : range(0, 7) = unsigned(modrm[5..3]);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_NONE => { // KMOVW: r/m16 -> k
        let v : dword = match rm {
          RM_reg(idx) => read_gpr32(idx),
          RM_mem(addr) => zero_extend(mem_read16(fixup_addr(addr))),
        };
        write_kreg(k1, zero_extend(v[15..0]));
        Ok()
      },
      _ => raise_UD(),
    }
  },

  // 0F 93: KMOVW k -> r32 (NP, W0) / KMOVD k -> r32 (F2, W0)
  147 => {
    let modrm = fetch_byte();
    let dst_gpr = modrm_reg(modrm, pfx);
    let k1 : range(0, 7) = unsigned(modrm[2..0]);
    match mp {
      MP_NONE => { // KMOVW
        write_gpr32(dst_gpr, zero_extend(read_kreg(k1)[15..0]));
        Ok()
      },
      MP_F2 => { // KMOVD
        write_gpr32(dst_gpr, read_kreg(k1)[31..0]);
        Ok()
      },
      _ => raise_UD(),
    }
  },

  // 0F 50-5F: Packed arithmetic
  // Common pattern: dst = vvvv OP src (3-operand)
  op if 80 <= op & op <= 95 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let col : range(0, 15) = op - 80;

    if pfx.vex_l then {
      // 256-bit YMM path
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
      match col {
        1 => if pfx.vex_vvvv != 0 then { raise_UD() } else match mp { // VSQRTPS/VSQRTPD (unary, vvvv reserved)
          MP_NONE => { write_ymm(dst, vsqrtps_xmm(src2[255..128]) @ vsqrtps_xmm(src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vsqrtpd_xmm(src2[255..128]) @ vsqrtpd_xmm(src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        4 => match mp { // VANDPS/VANDPD
          _ => { write_ymm(dst, src1 & src2); Ok() },
        },
        5 => match mp { // VANDNPS/VANDNPD
          _ => { write_ymm(dst, ~(src1) & src2); Ok() },
        },
        6 => match mp { // VORPS/VORPD
          _ => { write_ymm(dst, src1 | src2); Ok() },
        },
        7 => match mp { // VXORPS/VXORPD
          _ => { write_ymm(dst, xor_vec(src1, src2)); Ok() },
        },
        8 => match mp { // VADDPS/VADDPD
          MP_NONE => { write_ymm(dst, vaddps_xmm(src1[255..128], src2[255..128]) @ vaddps_xmm(src1[127..0], src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vaddpd_xmm(src1[255..128], src2[255..128]) @ vaddpd_xmm(src1[127..0], src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        9 => match mp { // VMULPS/VMULPD
          MP_NONE => { write_ymm(dst, vmulps_xmm(src1[255..128], src2[255..128]) @ vmulps_xmm(src1[127..0], src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vmulpd_xmm(src1[255..128], src2[255..128]) @ vmulpd_xmm(src1[127..0], src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        10 => if pfx.vex_vvvv != 0 then { raise_UD() } else match mp { // VCVTPS2PD/VCVTPD2PS (256-bit, vvvv reserved)
          MP_NONE => { // VCVTPS2PD: 4 floats -> 4 doubles
            let r3 = __f32_to_f64(src2[127..96]);
            let r2 = __f32_to_f64(src2[95..64]);
            let r1 = __f32_to_f64(src2[63..32]);
            let r0 = __f32_to_f64(src2[31..0]);
            write_ymm(dst, r3 @ r2 @ r1 @ r0);
            Ok()
          },
          MP_66 => { // VCVTPD2PS: 4 doubles -> 4 floats (in low 128)
            let r3 = __f64_to_f32(src2[255..192]);
            let r2 = __f64_to_f32(src2[191..128]);
            let r1 = __f64_to_f32(src2[127..64]);
            let r0 = __f64_to_f32(src2[63..0]);
            write_xmm(dst, r3 @ r2 @ r1 @ r0);
            Ok()
          },
          _ => raise_UD(),
        },
        12 => match mp { // VSUBPS/VSUBPD
          MP_NONE => { write_ymm(dst, vsubps_xmm(src1[255..128], src2[255..128]) @ vsubps_xmm(src1[127..0], src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vsubpd_xmm(src1[255..128], src2[255..128]) @ vsubpd_xmm(src1[127..0], src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        13 => match mp { // VMINPS/VMINPD
          MP_NONE => { write_ymm(dst, vminps_xmm(src1[255..128], src2[255..128]) @ vminps_xmm(src1[127..0], src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vminpd_xmm(src1[255..128], src2[255..128]) @ vminpd_xmm(src1[127..0], src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        14 => match mp { // VDIVPS/VDIVPD
          MP_NONE => { write_ymm(dst, vdivps_xmm(src1[255..128], src2[255..128]) @ vdivps_xmm(src1[127..0], src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vdivpd_xmm(src1[255..128], src2[255..128]) @ vdivpd_xmm(src1[127..0], src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        15 => match mp { // VMAXPS/VMAXPD
          MP_NONE => { write_ymm(dst, vmaxps_xmm(src1[255..128], src2[255..128]) @ vmaxps_xmm(src1[127..0], src2[127..0])); Ok() },
          MP_66   => { write_ymm(dst, vmaxpd_xmm(src1[255..128], src2[255..128]) @ vmaxpd_xmm(src1[127..0], src2[127..0])); Ok() },
          _ => raise_UD(),
        },
        _ => raise_UD(),
      }
    } else {
      // 128-bit XMM path (upper bits zeroed by write_xmm)
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
      match col {
        1 => match mp { // VSQRTPS/VSQRTPD/VSQRTSS/VSQRTSD
          MP_NONE => if pfx.vex_vvvv != 0 then { raise_UD() } else { write_xmm(dst, vsqrtps_xmm(src2)); Ok() },
          MP_66   => if pfx.vex_vvvv != 0 then { raise_UD() } else { write_xmm(dst, vsqrtpd_xmm(src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_sqrt(src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_sqrt(src2[63..0])); Ok() },
        },
        4 => match mp { // VANDPS/VANDPD
          _ => { write_xmm(dst, src1 & src2); Ok() },
        },
        5 => match mp { // VANDNPS/VANDNPD
          _ => { write_xmm(dst, ~(src1) & src2); Ok() },
        },
        6 => match mp { // VORPS/VORPD
          _ => { write_xmm(dst, src1 | src2); Ok() },
        },
        7 => match mp { // VXORPS/VXORPD
          _ => { write_xmm(dst, xor_vec(src1, src2)); Ok() },
        },
        8 => match mp { // VADDPS/VADDPD/VADDSS/VADDSD
          MP_NONE => { write_xmm(dst, vaddps_xmm(src1, src2)); Ok() },
          MP_66   => { write_xmm(dst, vaddpd_xmm(src1, src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_add(src1[31..0], src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_add(src1[63..0], src2[63..0])); Ok() },
        },
        9 => match mp { // VMULPS/VMULPD/VMULSS/VMULSD
          MP_NONE => { write_xmm(dst, vmulps_xmm(src1, src2)); Ok() },
          MP_66   => { write_xmm(dst, vmulpd_xmm(src1, src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_mul(src1[31..0], src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_mul(src1[63..0], src2[63..0])); Ok() },
        },
        11 => if pfx.vex_vvvv != 0 then { raise_UD() } else match mp { // VCVTDQ2PS/VCVTPS2DQ/VCVTTPS2DQ (unary, vvvv reserved)
          MP_NONE => { // VCVTDQ2PS
            write_xmm(dst, __int32_to_f32(src2[127..96]) @ __int32_to_f32(src2[95..64]) @
              __int32_to_f32(src2[63..32]) @ __int32_to_f32(src2[31..0]));
            Ok()
          },
          MP_66 => { // VCVTPS2DQ
            write_xmm(dst, __f32_to_int32(src2[127..96]) @ __f32_to_int32(src2[95..64]) @
              __f32_to_int32(src2[63..32]) @ __f32_to_int32(src2[31..0]));
            Ok()
          },
          MP_F3 => { // VCVTTPS2DQ
            write_xmm(dst, __f32_to_int32_trunc(src2[127..96]) @ __f32_to_int32_trunc(src2[95..64]) @
              __f32_to_int32_trunc(src2[63..32]) @ __f32_to_int32_trunc(src2[31..0]));
            Ok()
          },
          _ => raise_UD(),
        },
        10 => match mp { // VCVTPS2PD/VCVTPD2PS/VCVTSS2SD/VCVTSD2SS (128-bit)
          MP_NONE => // VCVTPS2PD: 2 floats -> 2 doubles (vvvv reserved)
            if pfx.vex_vvvv != 0 then { raise_UD() } else {
            let r1 = __f32_to_f64(src2[63..32]);
            let r0 = __f32_to_f64(src2[31..0]);
            write_xmm(dst, r1 @ r0);
            Ok()
          },
          MP_66 => // VCVTPD2PS: 2 doubles -> 2 floats (vvvv reserved)
            if pfx.vex_vvvv != 0 then { raise_UD() } else {
            let r1 = __f64_to_f32(src2[127..64]);
            let r0 = __f64_to_f32(src2[63..0]);
            write_xmm(dst, zeros(64) @ r1 @ r0);
            Ok()
          },
          MP_F3 => { // VCVTSS2SD: scalar float -> double
            write_xmm(dst, src1[127..64] @ __f32_to_f64(src2[31..0]));
            Ok()
          },
          MP_F2 => { // VCVTSD2SS: scalar double -> float
            write_xmm(dst, src1[127..32] @ __f64_to_f32(src2[63..0]));
            Ok()
          },
        },
        12 => match mp { // VSUBPS/VSUBPD/VSUBSS/VSUBSD
          MP_NONE => { write_xmm(dst, vsubps_xmm(src1, src2)); Ok() },
          MP_66   => { write_xmm(dst, vsubpd_xmm(src1, src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_sub(src1[31..0], src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_sub(src1[63..0], src2[63..0])); Ok() },
        },
        13 => match mp { // VMINPS/VMINPD/VMINSS/VMINSD
          MP_NONE => { write_xmm(dst, vminps_xmm(src1, src2)); Ok() },
          MP_66   => { write_xmm(dst, vminpd_xmm(src1, src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_min(src1[31..0], src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_min(src1[63..0], src2[63..0])); Ok() },
        },
        14 => match mp { // VDIVPS/VDIVPD/VDIVSS/VDIVSD
          MP_NONE => { write_xmm(dst, vdivps_xmm(src1, src2)); Ok() },
          MP_66   => { write_xmm(dst, vdivpd_xmm(src1, src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_div(src1[31..0], src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_div(src1[63..0], src2[63..0])); Ok() },
        },
        15 => match mp { // VMAXPS/VMAXPD/VMAXSS/VMAXSD
          MP_NONE => { write_xmm(dst, vmaxps_xmm(src1, src2)); Ok() },
          MP_66   => { write_xmm(dst, vmaxpd_xmm(src1, src2)); Ok() },
          MP_F3   => { write_xmm(dst, src1[127..32] @ __f32_max(src1[31..0], src2[31..0])); Ok() },
          MP_F2   => { write_xmm(dst, src1[127..64] @ __f64_max(src1[63..0], src2[63..0])); Ok() },
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F 6E: VMOVD/VMOVQ gpr/mem -> xmm (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  110 => {
    if mp != MP_66 | pfx.vex_l then {
      raise_UD()
    } else if pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_w then {
        // VMOVQ xmm, r/m64
        let v : qword = match rm {
          RM_reg(idx) => read_gpr64(idx),
          RM_mem(addr) => mem_read64(fixup_addr(addr)),
        };
        write_xmm(dst, zero_extend(v));
        Ok()
      } else {
        // VMOVD xmm, r/m32
        let v : dword = match rm {
          RM_reg(idx) => read_gpr32(idx),
          RM_mem(addr) => mem_read32(fixup_addr(addr)),
        };
        write_xmm(dst, zero_extend(v));
        Ok()
      }
    }
  },

  // 0F 6F: VMOVDQA/VMOVDQU (load)
  // SDM: VEX.vvvv must be 1111b
  111 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_66 => // VMOVDQA
        if pfx.vex_l then {
          write_ymm(dst, decode_vex_src_ymm(modrm, rm, pfx));
          Ok()
        } else { write_xmm(dst, decode_vex_src_xmm(modrm, rm, pfx)); Ok() },
      MP_F3 => // VMOVDQU
        if pfx.vex_l then {
          write_ymm(dst, decode_vex_src_ymm(modrm, rm, pfx));
          Ok()
        } else { write_xmm(dst, decode_vex_src_xmm(modrm, rm, pfx)); Ok() },
      _ => raise_UD(),
    }
    }
  },

  // 0F 7E: VMOVD/VMOVQ xmm -> gpr/mem (66 prefix) / VMOVQ xmm,xmm/m64 (F3 prefix)
  // SDM: VEX.128 only, VEX.vvvv must be 1111b
  126 => {
    if pfx.vex_vvvv != 0 | pfx.vex_l then {
      raise_UD()
    } else {
    let modrm = fetch_byte();
    let rm = decode_rm(modrm, pfx);
    match mp {
      MP_66 => {
        // VMOVD/VMOVQ xmm -> r/m
        let src = read_xmm(modrm_xmm_reg(modrm, pfx));
        if pfx.vex_w then {
          match rm {
            RM_reg(idx) => write_gpr64(idx, src[63..0]),
            RM_mem(addr) => mem_write64(fixup_addr(addr), src[63..0]),
          };
        } else {
          match rm {
            RM_reg(idx) => write_gpr32(idx, src[31..0]),
            RM_mem(addr) => mem_write32(fixup_addr(addr), src[31..0]),
          };
        };
        Ok()
      },
      MP_F3 => {
        // VMOVQ xmm1, xmm2/m64
        let dst = modrm_xmm_reg(modrm, pfx);
        match rm {
          RM_reg(_) => {
            let src = read_xmm(modrm_xmm_rm(modrm, pfx));
            write_xmm(dst, zero_extend(src[63..0]));
            Ok()
          },
          RM_mem(addr) => {
            let v : qword = mem_read64(fixup_addr(addr));
            write_xmm(dst, zero_extend(v));
            Ok()
          },
        }
      },
      _ => raise_UD(),
    }
    }
  },

  // 0F 7F: VMOVDQA/VMOVDQU (store)
  // SDM: VEX.vvvv must be 1111b
  127 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else {
    let modrm = fetch_byte();
    let src = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    match rm {
      RM_reg(_) => {
        let dst = modrm_xmm_rm(modrm, pfx);
        if pfx.vex_l then {
          write_ymm(dst, read_ymm(src)); Ok()
        } else {
          write_xmm(dst, read_xmm(src)); Ok()
        }
      },
      RM_mem(addr) => {
        let a = fixup_addr(addr);
        if pfx.vex_l then {
          mem_write256(a, read_ymm(src)); Ok()
        } else {
          mem_write128(a, read_xmm(src)); Ok()
        }
      },
    }
    }
  },

  // 0F 70: VPSHUFD xmm/ymm, xmm/ymm/m, imm8 (66 prefix)
  // SDM: VEX.vvvv must be 1111b. 256-bit shuffles each 128-bit lane independently.
  112 => {
    if mp != MP_66 then {
      raise_UD()
    } else if pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        let imm = fetch_byte();
        // Shuffle low 128-bit lane
        let lo : xmmword = src[127..0];
        let l0 : dword = match unsigned(imm[1..0]) {
          0 => lo[31..0], 1 => lo[63..32], 2 => lo[95..64], _ => lo[127..96],
        };
        let l1 : dword = match unsigned(imm[3..2]) {
          0 => lo[31..0], 1 => lo[63..32], 2 => lo[95..64], _ => lo[127..96],
        };
        let l2 : dword = match unsigned(imm[5..4]) {
          0 => lo[31..0], 1 => lo[63..32], 2 => lo[95..64], _ => lo[127..96],
        };
        let l3 : dword = match unsigned(imm[7..6]) {
          0 => lo[31..0], 1 => lo[63..32], 2 => lo[95..64], _ => lo[127..96],
        };
        // Shuffle high 128-bit lane
        let hi : xmmword = src[255..128];
        let h0 : dword = match unsigned(imm[1..0]) {
          0 => hi[31..0], 1 => hi[63..32], 2 => hi[95..64], _ => hi[127..96],
        };
        let h1 : dword = match unsigned(imm[3..2]) {
          0 => hi[31..0], 1 => hi[63..32], 2 => hi[95..64], _ => hi[127..96],
        };
        let h2 : dword = match unsigned(imm[5..4]) {
          0 => hi[31..0], 1 => hi[63..32], 2 => hi[95..64], _ => hi[127..96],
        };
        let h3 : dword = match unsigned(imm[7..6]) {
          0 => hi[31..0], 1 => hi[63..32], 2 => hi[95..64], _ => hi[127..96],
        };
        write_ymm(dst, (h3 @ h2 @ h1 @ h0) @ (l3 @ l2 @ l1 @ l0));
        Ok()
      } else {
        let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        let imm = fetch_byte();
        let d0 : dword = match unsigned(imm[1..0]) {
          0 => src[31..0], 1 => src[63..32], 2 => src[95..64], _ => src[127..96],
        };
        let d1 : dword = match unsigned(imm[3..2]) {
          0 => src[31..0], 1 => src[63..32], 2 => src[95..64], _ => src[127..96],
        };
        let d2 : dword = match unsigned(imm[5..4]) {
          0 => src[31..0], 1 => src[63..32], 2 => src[95..64], _ => src[127..96],
        };
        let d3 : dword = match unsigned(imm[7..6]) {
          0 => src[31..0], 1 => src[63..32], 2 => src[95..64], _ => src[127..96],
        };
        write_xmm(dst, d3 @ d2 @ d1 @ d0);
        Ok()
      }
    }
  },

  // 0F 76: VPCMPEQD xmm/ymm (66 prefix)
  118 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        let r7 : dword = if src1[255..224] == src2[255..224] then ones() else zeros();
        let r6 : dword = if src1[223..192] == src2[223..192] then ones() else zeros();
        let r5 : dword = if src1[191..160] == src2[191..160] then ones() else zeros();
        let r4 : dword = if src1[159..128] == src2[159..128] then ones() else zeros();
        let r3 : dword = if src1[127..96]  == src2[127..96]  then ones() else zeros();
        let r2 : dword = if src1[95..64]   == src2[95..64]   then ones() else zeros();
        let r1 : dword = if src1[63..32]   == src2[63..32]   then ones() else zeros();
        let r0 : dword = if src1[31..0]    == src2[31..0]    then ones() else zeros();
        write_ymm(dst, r7 @ r6 @ r5 @ r4 @ r3 @ r2 @ r1 @ r0);
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        let r3 : dword = if src1[127..96] == src2[127..96] then ones() else zeros();
        let r2 : dword = if src1[95..64]  == src2[95..64]  then ones() else zeros();
        let r1 : dword = if src1[63..32]  == src2[63..32]  then ones() else zeros();
        let r0 : dword = if src1[31..0]   == src2[31..0]   then ones() else zeros();
        write_xmm(dst, r3 @ r2 @ r1 @ r0);
        Ok()
      }
    }
  },

  // 0F 77: VZEROUPPER (VEX.128) / VZEROALL (VEX.256)
  // SDM: VEX.vvvv must be 1111b
  119 => {
    if pfx.vex_vvvv != 0 then { raise_UD() } else if pfx.vex_l then {
      // VZEROALL: zero ZMM0-ZMM15 entirely (in 64-bit mode)
      foreach (i from 0 to 15) {
        ZMM[i] = zeros()
      };
      Ok()
    } else {
      // VZEROUPPER: zero upper bits (255:128) of ZMM0-ZMM15
      foreach (i from 0 to 15) {
        var r : zmmword = ZMM[i];
        r[511..128] = zeros();
        ZMM[i] = r
      };
      Ok()
    }
  },

  // 0F EF: VPXOR (66 prefix)
  239 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1_reg = pfx.vex_vvvv;
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(src1_reg);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, xor_vec(src1, src2));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(src1_reg);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, xor_vec(src1, src2));
        Ok()
      }
    }
  },

  // 0F DB: VPAND (66 prefix)
  219 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, read_ymm(pfx.vex_vvvv) & decode_vex_src_ymm(modrm, rm, pfx));
        Ok()
      } else { write_xmm(dst, read_xmm(pfx.vex_vvvv) & decode_vex_src_xmm(modrm, rm, pfx)); Ok() }
    }
  },

  // 0F DF: VPANDN (66 prefix)
  223 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, ~(read_ymm(pfx.vex_vvvv)) & decode_vex_src_ymm(modrm, rm, pfx));
        Ok()
      } else {
        write_xmm(dst, ~(read_xmm(pfx.vex_vvvv)) & decode_vex_src_xmm(modrm, rm, pfx));
        Ok()
      }
    }
  },

  // 0F EB: VPOR (66 prefix)
  235 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        write_ymm(dst, read_ymm(pfx.vex_vvvv) | decode_vex_src_ymm(modrm, rm, pfx));
        Ok()
      } else { write_xmm(dst, read_xmm(pfx.vex_vvvv) | decode_vex_src_xmm(modrm, rm, pfx)); Ok() }
    }
  },

  // 0F FC: VPADDB (66 prefix)
  252 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_paddb_128(src1[255..128], src2[255..128]) @ avx_paddb_128(src1[127..0], src2[127..0]));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_paddb_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F FD: VPADDW (66 prefix)
  253 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_paddw_128(src1[255..128], src2[255..128]) @ avx_paddw_128(src1[127..0], src2[127..0]));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_paddw_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F FE: VPADDD (66 prefix)
  254 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_paddd_128(src1[255..128], src2[255..128]) @ avx_paddd_128(src1[127..0], src2[127..0]));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_paddd_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F D4: VPADDQ (66 prefix)
  212 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_paddq_128(src1[255..128], src2[255..128]) @ avx_paddq_128(src1[127..0], src2[127..0]));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_paddq_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F F8: VPSUBB (66 prefix)
  248 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_psubb_128(src1[255..128], src2[255..128]) @ avx_psubb_128(src1[127..0], src2[127..0]));
        Ok()
      } else {
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_psubb_128(src1, src2));
        Ok()
      }
    }
  },

  // 0F F9: VPSUBW (66 prefix)
  249 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_psubw_128(src1[255..128], src2[255..128]) @ avx_psubw_128(src1[127..0], src2[127..0]));
        Ok()
      } else {
        write_xmm(dst, avx_psubw_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F FA: VPSUBD (66 prefix)
  250 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_psubd_128(src1[255..128], src2[255..128]) @ avx_psubd_128(src1[127..0], src2[127..0]));
        Ok()
      } else {
        write_xmm(dst, avx_psubd_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F FB: VPSUBQ (66 prefix)
  251 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        let src1 : ymmword = read_ymm(pfx.vex_vvvv);
        let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
        write_ymm(dst, avx_psubq_128(src1[255..128], src2[255..128]) @ avx_psubq_128(src1[127..0], src2[127..0]));
        Ok()
      } else {
        write_xmm(dst, avx_psubq_128(read_xmm(pfx.vex_vvvv), decode_vex_src_xmm(modrm, rm, pfx)));
        Ok()
      }
    }
  },

  // 0F C4: VPINSRW xmm, xmm, r32/m16, imm8 (66 prefix, VEX.128 only)
  196 => {
    if mp != MP_66 | pfx.vex_l then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let v : word = match rm {
        RM_reg(idx) => read_gpr32(idx)[15..0],
        RM_mem(addr) => mem_read16(fixup_addr(addr)),
      };
      let imm = fetch_byte();
      let sel : range(0, 7) = unsigned(imm[2..0]);
      var result : xmmword = src1;
      foreach (i from 0 to 7) {
        if i == sel then result[(16 * i + 15) .. (16 * i)] = v;
      };
      write_xmm(dst, result);
      Ok()
    }
  },

  // 0F C5: VPEXTRW r32, xmm, imm8 (66 prefix, VEX.128 only)
  197 => {
    if mp != MP_66 | pfx.vex_l then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst_gpr = modrm_reg(modrm, pfx);
      let src : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
      let imm = fetch_byte();
      let sel : range(0, 7) = unsigned(imm[2..0]);
      var result : word = zeros();
      foreach (i from 0 to 7) {
        if i == sel then result = src[(16 * i + 15) .. (16 * i)];
      };
      write_gpr32(dst_gpr, zero_extend(result));
      Ok()
    }
  },

  // 0F C2: VCMPPS/VCMPPD/VCMPSS/VCMPSD imm8
  194 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let imm = fetch_byte();
    let pred : bits(3) = imm[2..0];
    match mp {
      MP_NONE => { // VCMPPS
        if pfx.vex_l then {
          let src1 : ymmword = read_ymm(pfx.vex_vvvv);
          let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, cmp_pred_f32(src1[255..224], src2[255..224], pred) @
                          cmp_pred_f32(src1[223..192], src2[223..192], pred) @
                          cmp_pred_f32(src1[191..160], src2[191..160], pred) @
                          cmp_pred_f32(src1[159..128], src2[159..128], pred) @
                          cmp_pred_f32(src1[127..96],  src2[127..96],  pred) @
                          cmp_pred_f32(src1[95..64],   src2[95..64],   pred) @
                          cmp_pred_f32(src1[63..32],   src2[63..32],   pred) @
                          cmp_pred_f32(src1[31..0],    src2[31..0],    pred));
          Ok()
        } else {
          let src1 : xmmword = read_xmm(pfx.vex_vvvv);
          let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          write_xmm(dst, cmp_pred_f32(src1[127..96], src2[127..96], pred) @
                          cmp_pred_f32(src1[95..64],  src2[95..64],  pred) @
                          cmp_pred_f32(src1[63..32],  src2[63..32],  pred) @
                          cmp_pred_f32(src1[31..0],   src2[31..0],   pred));
          Ok()
        }
      },
      MP_66 => { // VCMPPD
        if pfx.vex_l then {
          let src1 : ymmword = read_ymm(pfx.vex_vvvv);
          let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          write_ymm(dst, cmp_pred_f64(src1[255..192], src2[255..192], pred) @
                          cmp_pred_f64(src1[191..128], src2[191..128], pred) @
                          cmp_pred_f64(src1[127..64],  src2[127..64],  pred) @
                          cmp_pred_f64(src1[63..0],    src2[63..0],    pred));
          Ok()
        } else {
          let src1 : xmmword = read_xmm(pfx.vex_vvvv);
          let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          write_xmm(dst, cmp_pred_f64(src1[127..64], src2[127..64], pred) @
                          cmp_pred_f64(src1[63..0],   src2[63..0],   pred));
          Ok()
        }
      },
      MP_F3 => { // VCMPSS (scalar, VEX.L ignored)
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, src1[127..32] @ cmp_pred_f32(src1[31..0], src2[31..0], pred));
        Ok()
      },
      MP_F2 => { // VCMPSD (scalar, VEX.L ignored)
        let src1 : xmmword = read_xmm(pfx.vex_vvvv);
        let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, src1[127..64] @ cmp_pred_f64(src1[63..0], src2[63..0], pred));
        Ok()
      },
    }
  },

  // 0F C6: VSHUFPS (NP) / VSHUFPD (66) imm8
  198 => {
    let modrm = fetch_byte();
    let dst = modrm_xmm_reg(modrm, pfx);
    let rm = decode_rm(modrm, pfx);
    let imm = fetch_byte();
    match mp {
      MP_NONE => { // VSHUFPS
        let s0 : range(0, 3) = unsigned(imm[1..0]);
        let s1 : range(0, 3) = unsigned(imm[3..2]);
        let s2 : range(0, 3) = unsigned(imm[5..4]);
        let s3 : range(0, 3) = unsigned(imm[7..6]);
        if pfx.vex_l then {
          // 256-bit: two independent 128-bit lane shuffles, same imm8
          let src1 : ymmword = read_ymm(pfx.vex_vvvv);
          let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          // Low lane: select from src1[127..0] and src2[127..0]
          var r0 : dword = zeros(); var r1 : dword = zeros();
          var r2 : dword = zeros(); var r3 : dword = zeros();
          foreach (i from 0 to 3) {
            if i == s0 then r0 = src1[(32*i+31) .. (32*i)];
            if i == s1 then r1 = src1[(32*i+31) .. (32*i)];
            if i == s2 then r2 = src2[(32*i+31) .. (32*i)];
            if i == s3 then r3 = src2[(32*i+31) .. (32*i)];
          };
          // High lane: select from src1[255..128] and src2[255..128]
          var r4 : dword = zeros(); var r5 : dword = zeros();
          var r6 : dword = zeros(); var r7 : dword = zeros();
          foreach (i from 0 to 3) {
            if i == s0 then r4 = src1[(32*i+159) .. (32*i+128)];
            if i == s1 then r5 = src1[(32*i+159) .. (32*i+128)];
            if i == s2 then r6 = src2[(32*i+159) .. (32*i+128)];
            if i == s3 then r7 = src2[(32*i+159) .. (32*i+128)];
          };
          write_ymm(dst, r7 @ r6 @ r5 @ r4 @ r3 @ r2 @ r1 @ r0);
          Ok()
        } else {
          let src1 : xmmword = read_xmm(pfx.vex_vvvv);
          let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          var r0 : dword = zeros(); var r1 : dword = zeros();
          var r2 : dword = zeros(); var r3 : dword = zeros();
          foreach (i from 0 to 3) {
            if i == s0 then r0 = src1[(32*i+31) .. (32*i)];
            if i == s1 then r1 = src1[(32*i+31) .. (32*i)];
            if i == s2 then r2 = src2[(32*i+31) .. (32*i)];
            if i == s3 then r3 = src2[(32*i+31) .. (32*i)];
          };
          write_xmm(dst, r3 @ r2 @ r1 @ r0);
          Ok()
        }
      },
      MP_66 => { // VSHUFPD
        if pfx.vex_l then {
          // 256-bit: 4 qwords, each selected by one imm8 bit
          let src1 : ymmword = read_ymm(pfx.vex_vvvv);
          let src2 : ymmword = decode_vex_src_ymm(modrm, rm, pfx);
          let r0 : qword = if imm[0] == bitone then src1[127..64] else src1[63..0];
          let r1 : qword = if imm[1] == bitone then src2[127..64] else src2[63..0];
          let r2 : qword = if imm[2] == bitone then src1[255..192] else src1[191..128];
          let r3 : qword = if imm[3] == bitone then src2[255..192] else src2[191..128];
          write_ymm(dst, r3 @ r2 @ r1 @ r0);
          Ok()
        } else {
          let src1 : xmmword = read_xmm(pfx.vex_vvvv);
          let src2 : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
          let r0 : qword = if imm[0] == bitone then src1[127..64] else src1[63..0];
          let r1 : qword = if imm[1] == bitone then src2[127..64] else src2[63..0];
          write_xmm(dst, r1 @ r0);
          Ok()
        }
      },
      _ => raise_UD(),
    }
  },

  _ => raise_UD(),
  }
}

// =========================================================================
// VEX 0F38 map dispatch
// =========================================================================

val dispatch_vex_0f38 : (byte, Prefixes) -> ExecutionResult
function dispatch_vex_0f38(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F38 18: VBROADCASTSS xmm1, xmm2/m32 (VEX.128/256)
  // SDM: VEX.vvvv must be 1111b
  24 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let val32 : dword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
        RM_mem(addr) => mem_read32(fixup_addr(addr)),
      };
      if pfx.vex_l then {
        // 256-bit: broadcast to 8 dwords
        write_ymm(dst, val32 @ val32 @ val32 @ val32 @
                       val32 @ val32 @ val32 @ val32);
        Ok()
      } else {
        // 128-bit: broadcast to 4 dwords
        write_xmm(dst, val32 @ val32 @ val32 @ val32);
        Ok()
      }
    }
  },

  // 0F38 19: VBROADCASTSD ymm1, xmm2/m64 (VEX.256 only)
  // SDM: VEX.128 form #UDs, VEX.vvvv must be 1111b
  25 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else if not_bool(pfx.vex_l) then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let val64 : qword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(addr) => mem_read64(fixup_addr(addr)),
      };
      write_ymm(dst, val64 @ val64 @ val64 @ val64);
      Ok()
    }
  },

  // 0F38 1A: VBROADCASTF128 ymm1, m128 (VEX.256 only)
  // SDM: VEX.vvvv must be 1111b
  26 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else if not_bool(pfx.vex_l) then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      match rm {
        RM_reg(_) => raise_UD(), // memory-only
        RM_mem(addr) => {
          let v : xmmword = mem_read128(fixup_addr(addr));
          write_ymm(dst, v @ v);
          Ok()
        },
      }
    }
  },

  // 0F38 78: VPBROADCASTB xmm/ymm, xmm/m8 (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  120 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let val8 : byte = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[7..0],
        RM_mem(addr) => mem_read8(fixup_addr(addr)),
      };
      if pfx.vex_l then {
        write_ymm(dst, val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @
                       val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @
                       val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @
                       val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8);
        Ok()
      } else {
        write_xmm(dst, val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @
                       val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8);
        Ok()
      }
    }
  },

  // 0F38 79: VPBROADCASTW xmm/ymm, xmm/m16 (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  121 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let val16 : word = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[15..0],
        RM_mem(addr) => mem_read16(fixup_addr(addr)),
      };
      if pfx.vex_l then {
        write_ymm(dst, val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16 @
                       val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16);
        Ok()
      } else {
        write_xmm(dst, val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16);
        Ok()
      }
    }
  },

  // 0F38 58: VPBROADCASTD xmm/ymm, xmm/m32 (66 prefix) — same as VBROADCASTSS but int
  // SDM: VEX.vvvv must be 1111b
  88 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let val32 : dword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
        RM_mem(addr) => mem_read32(fixup_addr(addr)),
      };
      if pfx.vex_l then {
        write_ymm(dst, val32 @ val32 @ val32 @ val32 @ val32 @ val32 @ val32 @ val32);
        Ok()
      } else {
        write_xmm(dst, val32 @ val32 @ val32 @ val32);
        Ok()
      }
    }
  },

  // 0F38 59: VPBROADCASTQ xmm/ymm, xmm/m64 (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  89 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let val64 : qword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(addr) => mem_read64(fixup_addr(addr)),
      };
      if pfx.vex_l then {
        write_ymm(dst, val64 @ val64 @ val64 @ val64);
        Ok()
      } else {
        write_xmm(dst, val64 @ val64);
        Ok()
      }
    }
  },

  // 0F38 13: VCVTPH2PS xmm/ymm, xmm/m64/m128 (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  19 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      if pfx.vex_l then {
        // 256-bit: 8 FP16 -> 8 FP32
        let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_ymm(dst, avx_vcvtph2ps_256(src));
        Ok()
      } else {
        // 128-bit: 4 FP16 -> 4 FP32
        let src : xmmword = decode_vex_src_xmm(modrm, rm, pfx);
        write_xmm(dst, avx_vcvtph2ps_128(src[63..0]));
        Ok()
      }
    }
  },

  // -----------------------------------------------------------------------
  // VEX FMA3 instructions (0F38 96..BF)
  //
  // All require 66 mandatory prefix.
  // W=0 selects PS/SS variants, W=1 selects PD/SD variants.
  // L=0 for 128-bit (or scalar), L=1 for 256-bit.
  //
  // Operand mapping (avx_fmadd(a,b,c) computes a*b+c):
  //   132: a=dst, b=rm,  c=vvvv
  //   213: a=vvvv, b=dst, c=rm
  //   231: a=vvvv, b=rm,  c=dst
  // -----------------------------------------------------------------------

  // 0F38 96: VFMADDSUB132PS (W0) / VFMADDSUB132PD (W1)
  150 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmaddsub_pd_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fmaddsub_pd_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmaddsub_ps_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fmaddsub_ps_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      }
    }
  },

  // 0F38 97: VFMSUBADD132PS (W0) / VFMSUBADD132PD (W1)
  151 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsubadd_pd_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fmsubadd_pd_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsubadd_ps_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fmsubadd_ps_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      }
    }
  },

  // 0F38 98: VFMADD132PS (W0) / VFMADD132PD (W1)
  152 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmadd_pd_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fmadd_pd_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmadd_ps_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fmadd_ps_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      }
    }
  },

  // 0F38 99: VFMADD132SS (W0) / VFMADD132SD (W1)
  153 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfmadd132sd(dst, src2, src3)
      } else {
        exec_vfmadd132ss(dst, src2, src3)
      }
    }
  },

  // 0F38 9A: VFMSUB132PS (W0) / VFMSUB132PD (W1)
  154 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsub_pd_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fmsub_pd_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsub_ps_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fmsub_ps_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      }
    }
  },

  // 0F38 9B: VFMSUB132SS (W0) / VFMSUB132SD (W1)
  155 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfmsub132sd(dst, src2, src3)
      } else {
        exec_vfmsub132ss(dst, src2, src3)
      }
    }
  },

  // 0F38 9C: VFNMADD132PS (W0) / VFNMADD132PD (W1)
  156 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmadd_pd_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fnmadd_pd_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmadd_ps_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fnmadd_ps_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      }
    }
  },

  // 0F38 9D: VFNMADD132SS (W0) / VFNMADD132SD (W1)
  157 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfnmadd132sd(dst, src2, src3)
      } else {
        exec_vfnmadd132ss(dst, src2, src3)
      }
    }
  },

  // 0F38 9E: VFNMSUB132PS (W0) / VFNMSUB132PD (W1)
  158 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmsub_pd_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fnmsub_pd_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmsub_ps_256(read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(v))); Ok()
        } else {
          write_xmm(dst, avx_fnmsub_ps_128(read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(v))); Ok()
        }
      }
    }
  },

  // 0F38 9F: VFNMSUB132SS (W0) / VFNMSUB132SD (W1)
  159 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfnmsub132sd(dst, src2, src3)
      } else {
        exec_vfnmsub132ss(dst, src2, src3)
      }
    }
  },

  // 0F38 A6: VFMADDSUB213PS (W0) / VFMADDSUB213PD (W1)
  166 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmaddsub_pd_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fmaddsub_pd_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmaddsub_ps_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fmaddsub_ps_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      }
    }
  },

  // 0F38 A7: VFMSUBADD213PS (W0) / VFMSUBADD213PD (W1)
  167 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsubadd_pd_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fmsubadd_pd_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsubadd_ps_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fmsubadd_ps_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      }
    }
  },

  // 0F38 A8: VFMADD213PS (W0) / VFMADD213PD (W1)
  168 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmadd_pd_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fmadd_pd_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmadd_ps_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fmadd_ps_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      }
    }
  },

  // 0F38 A9: VFMADD213SS (W0) / VFMADD213SD (W1)
  169 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfmadd213sd(dst, src2, src3)
      } else {
        exec_vfmadd213ss(dst, src2, src3)
      }
    }
  },

  // 0F38 AA: VFMSUB213PS (W0) / VFMSUB213PD (W1)
  170 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsub_pd_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fmsub_pd_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsub_ps_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fmsub_ps_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      }
    }
  },

  // 0F38 AB: VFMSUB213SS (W0) / VFMSUB213SD (W1)
  171 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfmsub213sd(dst, src2, src3)
      } else {
        exec_vfmsub213ss(dst, src2, src3)
      }
    }
  },

  // 0F38 AC: VFNMADD213PS (W0) / VFNMADD213PD (W1)
  172 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmadd_pd_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fnmadd_pd_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmadd_ps_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fnmadd_ps_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      }
    }
  },

  // 0F38 AD: VFNMADD213SS (W0) / VFNMADD213SD (W1)
  173 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfnmadd213sd(dst, src2, src3)
      } else {
        exec_vfnmadd213ss(dst, src2, src3)
      }
    }
  },

  // 0F38 AE: VFNMSUB213PS (W0) / VFNMSUB213PD (W1)
  174 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmsub_pd_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fnmsub_pd_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmsub_ps_256(read_ymm(v), read_ymm(dst), decode_vex_src_ymm(modrm, rm, pfx))); Ok()
        } else {
          write_xmm(dst, avx_fnmsub_ps_128(read_xmm(v), read_xmm(dst), decode_vex_src_xmm(modrm, rm, pfx))); Ok()
        }
      }
    }
  },

  // 0F38 AF: VFNMSUB213SS (W0) / VFNMSUB213SD (W1)
  175 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfnmsub213sd(dst, src2, src3)
      } else {
        exec_vfnmsub213ss(dst, src2, src3)
      }
    }
  },

  // 0F38 B6: VFMADDSUB231PS (W0) / VFMADDSUB231PD (W1)
  182 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmaddsub_pd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fmaddsub_pd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmaddsub_ps_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fmaddsub_ps_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      }
    }
  },

  // 0F38 B7: VFMSUBADD231PS (W0) / VFMSUBADD231PD (W1)
  183 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsubadd_pd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fmsubadd_pd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsubadd_ps_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fmsubadd_ps_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      }
    }
  },

  // 0F38 B8: VFMADD231PS (W0) / VFMADD231PD (W1)
  184 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmadd_pd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fmadd_pd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmadd_ps_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fmadd_ps_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      }
    }
  },

  // 0F38 B9: VFMADD231SS (W0) / VFMADD231SD (W1)
  185 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfmadd231sd(dst, src2, src3)
      } else {
        exec_vfmadd231ss(dst, src2, src3)
      }
    }
  },

  // 0F38 BA: VFMSUB231PS (W0) / VFMSUB231PD (W1)
  186 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsub_pd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fmsub_pd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fmsub_ps_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fmsub_ps_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      }
    }
  },

  // 0F38 BB: VFMSUB231SS (W0) / VFMSUB231SD (W1)
  187 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfmsub231sd(dst, src2, src3)
      } else {
        exec_vfmsub231ss(dst, src2, src3)
      }
    }
  },

  // 0F38 BC: VFNMADD231PS (W0) / VFNMADD231PD (W1)
  188 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmadd_pd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fnmadd_pd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmadd_ps_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fnmadd_ps_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      }
    }
  },

  // 0F38 BD: VFNMADD231SS (W0) / VFNMADD231SD (W1)
  189 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfnmadd231sd(dst, src2, src3)
      } else {
        exec_vfnmadd231ss(dst, src2, src3)
      }
    }
  },

  // 0F38 BE: VFNMSUB231PS (W0) / VFNMSUB231PD (W1)
  190 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let v = pfx.vex_vvvv;
      if pfx.vex_w then {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmsub_pd_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fnmsub_pd_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      } else {
        if pfx.vex_l then {
          write_ymm(dst, avx_fnmsub_ps_256(read_ymm(v), decode_vex_src_ymm(modrm, rm, pfx), read_ymm(dst))); Ok()
        } else {
          write_xmm(dst, avx_fnmsub_ps_128(read_xmm(v), decode_vex_src_xmm(modrm, rm, pfx), read_xmm(dst))); Ok()
        }
      }
    }
  },

  // 0F38 BF: VFNMSUB231SS (W0) / VFNMSUB231SD (W1)
  191 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src2 = read_xmm(pfx.vex_vvvv);
      let src3 = decode_vex_src_xmm(modrm, rm, pfx);
      if pfx.vex_w then {
        exec_vfnmsub231sd(dst, src2, src3)
      } else {
        exec_vfnmsub231ss(dst, src2, src3)
      }
    }
  },

  // 0F38 F2: ANDN (NP, VEX.NDS.LZ) — dest = ~vvvv & src
  242 => {
    if mp != MP_NONE then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let os : OperandSize = if pfx.vex_w then OS64 else OS32;
      let src = read_rm_val(rm, os, true);
      let v : gpr_idx = pfx.vex_vvvv % 16;
      let vval : qword = read_gpr(v, os);
      let result : qword = ~(vval) & src;
      write_gpr(dst, os, result);
      SF = bool_to_bit(if pfx.vex_w then result[63] == bitone else result[31] == bitone);
      ZF = bool_to_bit(if pfx.vex_w then result == zeros() else result[31..0] == zeros());
      OF = bitzero;
      CF = bitzero;
      Ok()
    }
  },

  // 0F38 F3: BLSI/BLSMSK/BLSR (NP, VEX.NDD.LZ) — selected by modrm /reg
  243 => {
    if mp != MP_NONE then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let reg_field : range(0, 7) = unsigned(modrm[5..3]);
      let rm = decode_rm(modrm, pfx);
      let os : OperandSize = if pfx.vex_w then OS64 else OS32;
      let src : qword = read_rm_val(rm, os, true);
      let dst : gpr_idx = pfx.vex_vvvv % 16;
      match reg_field {
        1 => {
          // BLSR: dest = (src - 1) & src
          let result : qword = (src - 1) & src;
          write_gpr(dst, os, result);
          SF = bool_to_bit(if pfx.vex_w then result[63] == bitone else result[31] == bitone);
          ZF = bool_to_bit(if pfx.vex_w then result == zeros() else result[31..0] == zeros());
          CF = bool_to_bit(if pfx.vex_w then src == zeros() else src[31..0] == zeros());
          OF = bitzero;
          Ok()
        },
        2 => {
          // BLSMSK: dest = (src - 1) ^ src
          let result : qword = (src - 1) ^ src;
          write_gpr(dst, os, result);
          SF = bool_to_bit(if pfx.vex_w then result[63] == bitone else result[31] == bitone);
          ZF = bitzero;
          CF = bool_to_bit(if pfx.vex_w then src == zeros() else src[31..0] == zeros());
          OF = bitzero;
          Ok()
        },
        3 => {
          // BLSI: dest = (-src) & src (isolate lowest set bit)
          let neg_src : qword = ~(src) + 1;
          let result : qword = neg_src & src;
          write_gpr(dst, os, result);
          SF = bool_to_bit(if pfx.vex_w then result[63] == bitone else result[31] == bitone);
          ZF = bool_to_bit(if pfx.vex_w then result == zeros() else result[31..0] == zeros());
          CF = bool_to_bit(if pfx.vex_w then src != zeros() else src[31..0] != zeros());
          OF = bitzero;
          Ok()
        },
        _ => raise_UD(),
      }
    }
  },

  // 0F38 F7: BEXTR (NP, VEX.NDS.LZ) — bit field extract
  247 => {
    if mp != MP_NONE then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let os : OperandSize = if pfx.vex_w then OS64 else OS32;
      let src : qword = read_rm_val(rm, os, true);
      let v : gpr_idx = pfx.vex_vvvv % 16;
      let ctrl : qword = read_gpr(v, os);
      let start : range(0, 255) = unsigned(ctrl[7..0]);
      let len : range(0, 255) = unsigned(ctrl[15..8]);
      let os_bits : {32, 64} = if pfx.vex_w then 64 else 32;
      var result : qword = zeros();
      if start < os_bits then {
        let shifted : qword = src >> start;
        if len >= os_bits then {
          result = shifted
        } else {
          // Create mask with len low bits set
          let shift_amt : range(0, 255) = 64 - len;
          result = (shifted << shift_amt) >> shift_amt
        }
      };
      write_gpr(dst, os, result);
      ZF = bool_to_bit(if pfx.vex_w then result == zeros() else result[31..0] == zeros());
      OF = bitzero;
      CF = bitzero;
      Ok()
    }
  },

  _ => raise_UD(),
  }
}

// =========================================================================
// VEX 0F3A map dispatch
// =========================================================================

val dispatch_vex_0f3a : (byte, Prefixes) -> ExecutionResult
function dispatch_vex_0f3a(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F3A 18: VINSERTF128 ymm1, ymm2, xmm3/m128, imm8
  24 => {
    if mp != MP_66 then {
      raise_UD()
    } else if not_bool(pfx.vex_l) then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let dst = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : xmmword = match rm {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(addr) => mem_read128(fixup_addr(addr)),
      };
      let imm = fetch_byte();
      // imm8[0] selects which 128-bit lane to replace
      if imm[0] == bitzero then
        write_ymm(dst, src1[255..128] @ src2)
      else
        write_ymm(dst, src2 @ src1[127..0]);
      Ok()
    }
  },

  // 0F3A 19: VEXTRACTF128 xmm1/m128, ymm2, imm8
  25 => {
    if mp != MP_66 then {
      raise_UD()
    } else if not_bool(pfx.vex_l) then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let src = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let src_ymm : ymmword = read_ymm(src);
      let imm = fetch_byte();
      let extracted : xmmword =
        if imm[0] == bitzero then src_ymm[127..0]
        else src_ymm[255..128];
      match rm {
        RM_reg(_) => { write_xmm(modrm_xmm_rm(modrm, pfx), extracted); Ok() },
        RM_mem(addr) => { mem_write128(fixup_addr(addr), extracted); Ok() },
      }
    }
  },

  // 0F3A 30: KSHIFTRW k1, k2, imm8 (66, W1)
  48 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let k1 : range(0, 7) = unsigned(modrm[5..3]);
      let k2 : range(0, 7) = unsigned(modrm[2..0]);
      let imm = fetch_byte();
      let shift : range(0, 255) = unsigned(imm);
      let src : bits(16) = read_kreg(k2)[15..0];
      let result : bits(16) = if shift >= 16 then zeros() else sail_shiftright(src, shift);
      write_kreg(k1, zero_extend(result));
      Ok()
    }
  },

  // 0F3A 32: KSHIFTLW k1, k2, imm8 (66, W1)
  50 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let k1 : range(0, 7) = unsigned(modrm[5..3]);
      let k2 : range(0, 7) = unsigned(modrm[2..0]);
      let imm = fetch_byte();
      let shift : range(0, 255) = unsigned(imm);
      let src : bits(16) = read_kreg(k2)[15..0];
      let result : bits(16) = if shift >= 16 then zeros() else sail_shiftleft(src, shift);
      write_kreg(k1, zero_extend(result));
      Ok()
    }
  },

  // 0F3A 1D: VCVTPS2PH xmm/m64/m128, xmm/ymm, imm8 (66 prefix)
  29 => {
    if mp != MP_66 then {
      raise_UD()
    } else {
      let modrm = fetch_byte();
      let src = modrm_xmm_reg(modrm, pfx);
      let rm = decode_rm(modrm, pfx);
      let imm = fetch_byte();
      if pfx.vex_l then {
        let res : xmmword = avx_vcvtps2ph_256(read_ymm(src));
        match rm {
          RM_reg(_) => { write_xmm(modrm_xmm_rm(modrm, pfx), res); Ok() },
          RM_mem(addr) => { mem_write128(fixup_addr(addr), res); Ok() },
        }
      } else {
        let res : bits(64) = avx_vcvtps2ph_128(read_xmm(src));
        match rm {
          RM_reg(_) => { write_xmm(modrm_xmm_rm(modrm, pfx), zero_extend(res)); Ok() },
          RM_mem(addr) => { mem_write64(fixup_addr(addr), res); Ok() },
        }
      }
    }
  },

  _ => raise_UD(),
  }
}

// =========================================================================
// Top-level VEX dispatch — called from 1-byte opcode map for C4/C5.
// Must come after dispatch_vex_0f/0f38/0f3a definitions.
// =========================================================================

val dispatch_vex : byte -> ExecutionResult
function dispatch_vex(first_byte) = {
  let (pfx, map) : (Prefixes, range(0, 31)) =
    if first_byte == 0xC5 then {
      let b1 = fetch_byte();
      decode_vex2(b1)
    } else {
      // C4 = 3-byte VEX
      let b1 = fetch_byte();
      let b2 = fetch_byte();
      decode_vex3(b1, b2)
    };

  let opcode = fetch_byte();

  match map {
    1 => dispatch_vex_0f(opcode, pfx),
    2 => dispatch_vex_0f38(opcode, pfx),
    3 => dispatch_vex_0f3a(opcode, pfx),
    _ => raise_UD(),
  }
}

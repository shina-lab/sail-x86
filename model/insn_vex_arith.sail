// x86-64 — VEX Arithmetic/Misc (0F38 map)
//
// SSSE3, SSE4, broadcast, BMI, variable shifts, gather, test,
// maskmov, sign/zero-extend, permute.

// =========================================================================
// VEX 0F38 helpers — VTESTPS/PD, VMASKMOV, variable shifts, permute
// =========================================================================

// PHMINPOSUW: find minimum unsigned word among 8 words.
// Result: bits[15:0] = min value, bits[18:16] = index of min, rest zeroed.
val avx_phminposuw_128 : xmmword -> xmmword
function avx_phminposuw_128(src) = {
  var mv : word = src[15..0];
  var mi : bits(3) = 0b000;

  let v1 : word = src[31..16];
  let d1 : bits(17) = (0b0 @ v1) - (0b0 @ mv);
  let u1 : word = sign_extend(d1[16]);
  mv = (v1 & u1) | (mv & ~(u1));
  mi = (0b001 & u1[2..0]) | (mi & ~(u1[2..0]));

  let v2 : word = src[47..32];
  let d2 : bits(17) = (0b0 @ v2) - (0b0 @ mv);
  let u2 : word = sign_extend(d2[16]);
  mv = (v2 & u2) | (mv & ~(u2));
  mi = (0b010 & u2[2..0]) | (mi & ~(u2[2..0]));

  let v3 : word = src[63..48];
  let d3 : bits(17) = (0b0 @ v3) - (0b0 @ mv);
  let u3 : word = sign_extend(d3[16]);
  mv = (v3 & u3) | (mv & ~(u3));
  mi = (0b011 & u3[2..0]) | (mi & ~(u3[2..0]));

  let v4 : word = src[79..64];
  let d4 : bits(17) = (0b0 @ v4) - (0b0 @ mv);
  let u4 : word = sign_extend(d4[16]);
  mv = (v4 & u4) | (mv & ~(u4));
  mi = (0b100 & u4[2..0]) | (mi & ~(u4[2..0]));

  let v5 : word = src[95..80];
  let d5 : bits(17) = (0b0 @ v5) - (0b0 @ mv);
  let u5 : word = sign_extend(d5[16]);
  mv = (v5 & u5) | (mv & ~(u5));
  mi = (0b101 & u5[2..0]) | (mi & ~(u5[2..0]));

  let v6 : word = src[111..96];
  let d6 : bits(17) = (0b0 @ v6) - (0b0 @ mv);
  let u6 : word = sign_extend(d6[16]);
  mv = (v6 & u6) | (mv & ~(u6));
  mi = (0b110 & u6[2..0]) | (mi & ~(u6[2..0]));

  let v7 : word = src[127..112];
  let d7 : bits(17) = (0b0 @ v7) - (0b0 @ mv);
  let u7 : word = sign_extend(d7[16]);
  mv = (v7 & u7) | (mv & ~(u7));
  mi = (0b111 & u7[2..0]) | (mi & ~(u7[2..0]));

  zeros(109) @ mi @ mv
}

// 2-operand VEX unop: dst = packed_unop(op, eb, rm) — vvvv must be 0
val vex_exec_unop : (PackedUnaryOp, {8, 16, 32, 64}, Prefixes) -> unit
function vex_exec_unop(op, eb, pfx) = {
  if pfx.vex_vvvv != 0 then raise_UD();
  let modrm = fetch(1);
  let dst = modrm_xmm_reg(modrm, pfx);
  let src = modrm_rm(modrm, pfx);
  let vl = vex_vl(pfx);
  write_simd(vl, dst, packed_unop(op, eb, decode_vex_src(modrm, src, pfx)))
}

// VMASKMOVPS load 128-bit: conditional load of dword lanes based on sign bit of mask
val vex_maskmovps_load_128 : (xmmword, xmmword) -> xmmword
function vex_maskmovps_load_128(mask, data) =
  blend(0x00000000, data[127..96], mask[127]) @
  blend(0x00000000, data[95..64],  mask[95]) @
  blend(0x00000000, data[63..32],  mask[63]) @
  blend(0x00000000, data[31..0],   mask[31])

val vex_maskmovps_load_256 : (ymmword, ymmword) -> ymmword
function vex_maskmovps_load_256(mask, data) =
  vex_maskmovps_load_128(mask[255..128], data[255..128]) @
  vex_maskmovps_load_128(mask[127..0], data[127..0])

// VMASKMOVPD load 128-bit: conditional load of qword lanes based on sign bit of mask
val vex_maskmovpd_load_128 : (xmmword, xmmword) -> xmmword
function vex_maskmovpd_load_128(mask, data) =
  blend(0x0000000000000000, data[127..64], mask[127]) @
  blend(0x0000000000000000, data[63..0],   mask[63])

val vex_maskmovpd_load_256 : (ymmword, ymmword) -> ymmword
function vex_maskmovpd_load_256(mask, data) =
  vex_maskmovpd_load_128(mask[255..128], data[255..128]) @
  vex_maskmovpd_load_128(mask[127..0], data[127..0])

// VMASKMOVPS store helpers: return (data_to_write, write_mask) pairs not needed;
// we write individual dwords/qwords conditionally in the dispatch code.

// VPERMPS/VPERMD 256-bit: permute 8 dwords using index vector
val vex_vpermd_256 : (ymmword, ymmword) -> ymmword
function vex_vpermd_256(ctrl, src) = {
  var result : ymmword = zeros();
  foreach (i from 0 to 7) {
    let idx : range(0, 7) = unsigned(ctrl[(i * 32 + 2) .. (i * 32)]);
    result[(i * 32 + 31) .. (i * 32)] = src[(idx * 32 + 31) .. (idx * 32)]
  };
  result
}

val dispatch_vex_0f38_arith : (range(0, 255), Prefixes) -> unit
function dispatch_vex_0f38_arith(op, pfx) = {
  let mp = get_mandatory_prefix(pfx);

  match op {

  // 0F38 00: VPSHUFB xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  // 0F38 00: VPSHUFB xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  0 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_Pshufb, 128, pfx) },
  // 0F38 01: VPHADDW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  1 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_HorizAddW, 128, pfx) },
  // 0F38 02: VPHADDD xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  2 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_HorizAddD, 128, pfx) },
  // 0F38 03: VPHADDSW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  3 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_HorizSatAddW, 128, pfx) },
  // 0F38 04: VPMADDUBSW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  4 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_Pmaddubsw, 16, pfx) },

  // 0F38 05: VPHSUBW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  5 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_HorizSubW, 128, pfx) },
  // 0F38 06: VPHSUBD xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  6 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_HorizSubD, 128, pfx) },
  // 0F38 07: VPHSUBSW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  7 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_HorizSatSubW, 128, pfx) },

  // 0F38 08: VPSIGNB xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  8 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_PSign, 8, pfx) },
  // 0F38 09: VPSIGNW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  9 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_PSign, 16, pfx) },
  // 0F38 0A: VPSIGND xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  10 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_PSign, 32, pfx) },

  // 0F38 0B: VPMULHRSW xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  11 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_MulHRS, 16, pfx) },

  // 0F38 18: VBROADCASTSS xmm1, xmm2/m32 (VEX.128/256)
  // SDM: VEX.vvvv must be 1111b
  24 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let val32 : dword = match src {
      RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
      RM_mem(m) => v(m),
    };
    if pfx.vex_l then {
      // 256-bit: broadcast to 8 dwords
      write_ymm(dst, val32 @ val32 @ val32 @ val32 @
                     val32 @ val32 @ val32 @ val32)
    } else {
      // 128-bit: broadcast to 4 dwords
      write_xmm(dst, val32 @ val32 @ val32 @ val32)
    }
  },

  // 0F38 19: VBROADCASTSD ymm1, xmm2/m64 (VEX.256 only)
  // SDM: VEX.128 form #UDs, VEX.vvvv must be 1111b
  25 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    if ~(pfx.vex_l) then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let val64 : qword = match src {
      RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
      RM_mem(m) => v(m),
    };
    write_ymm(dst, val64 @ val64 @ val64 @ val64)
  },

  // 0F38 1A: VBROADCASTF128 ymm1, m128 (VEX.256 only)
  // SDM: VEX.vvvv must be 1111b
  26 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    if ~(pfx.vex_l) then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let x : xmmword = rm_mem(src);
    write_ymm(dst, x @ x)
  },

  // 0F38 78: VPBROADCASTB xmm/ymm, xmm/m8 (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  120 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let val8 : byte = match src {
      RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[7..0],
      RM_mem(m) => v(m),
    };
    if pfx.vex_l then {
      write_ymm(dst, val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @
                     val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @
                     val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @
                     val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8)
    } else {
      write_xmm(dst, val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @
                     val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8 @ val8)
    }
  },

  // 0F38 79: VPBROADCASTW xmm/ymm, xmm/m16 (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  121 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let val16 : word = match src {
      RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[15..0],
      RM_mem(m) => v(m),
    };
    if pfx.vex_l then {
      write_ymm(dst, val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16 @
                     val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16)
    } else {
      write_xmm(dst, val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16 @ val16)
    }
  },

  // 0F38 58: VPBROADCASTD xmm/ymm, xmm/m32 (66 prefix) — same as VBROADCASTSS but int
  // SDM: VEX.vvvv must be 1111b
  88 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let val32 : dword = match src {
      RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
      RM_mem(m) => v(m),
    };
    if pfx.vex_l then {
      write_ymm(dst, val32 @ val32 @ val32 @ val32 @ val32 @ val32 @ val32 @ val32)
    } else {
      write_xmm(dst, val32 @ val32 @ val32 @ val32)
    }
  },

  // 0F38 59: VPBROADCASTQ xmm/ymm, xmm/m64 (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  89 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let val64 : qword = match src {
      RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
      RM_mem(m) => v(m),
    };
    if pfx.vex_l then {
      write_ymm(dst, val64 @ val64 @ val64 @ val64)
    } else {
      write_xmm(dst, val64 @ val64)
    }
  },

  // 0F38 5A: VBROADCASTI128 ymm, m128 (VEX.256 only, vvvv must be 1111b)
  90 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    if ~(pfx.vex_l) then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let x : xmmword = rm_mem(src);
    write_ymm(dst, x @ x)
  },

  // 0F38 13: VCVTPH2PS xmm/ymm, xmm/m64/m128 (66 prefix)
  // SDM: VEX.vvvv must be 1111b
  19 => {
    if ~(has_f16c) then raise_UD();
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      // 256-bit: 8 FP16 -> 8 FP32
      let src : xmmword = decode_vex_src(128, modrm, src2, pfx);
      write_ymm(dst, avx_vcvtph2ps(src))
    } else {
      // 128-bit: 4 FP16 -> 4 FP32
      let src : xmmword = decode_vex_src(128, modrm, src2, pfx);
      write_xmm(dst, avx_vcvtph2ps(src[63..0]))
    }
  },

  // 0F38 1C: VPABSB xmm/ymm, xmm/ymm/m (66 prefix)
  28 => { if mp != MP_66 then raise_UD(); vex_exec_unop(PU_Abs, 8, pfx) },
  // 0F38 1D: VPABSW xmm/ymm, xmm/ymm/m (66 prefix)
  29 => { if mp != MP_66 then raise_UD(); vex_exec_unop(PU_Abs, 16, pfx) },
  // 0F38 1E: VPABSD xmm/ymm, xmm/ymm/m (66 prefix)
  30 => { if mp != MP_66 then raise_UD(); vex_exec_unop(PU_Abs, 32, pfx) },

  // 0F38 F2: ANDN (NP, VEX.NDS.LZ) — dest = ~vvvv & src
  242 => {
    if ~(has_bmi1) then raise_UD();
    if mp != MP_NONE then raise_UD();
    let (dst, src2) = fetch_modrm(pfx);
    let os : {32, 64} = if pfx.vex_w then 64 else 32;
    let src = v(os, src2);
    let vvvv : gpr_idx = pfx.vex_vvvv % 16;
    let vval = v(os, vvvv);
    let result = ~(vval) & src;
    v(dst) = result;
    SF = result[os - 1];
    ZF = is_zero(result);
    OF = 0b0;
    CF = 0b0
  },

  // 0F38 F3: BLSI/BLSMSK/BLSR (NP, VEX.NDD.LZ) — selected by modrm /reg
  243 => {
    if ~(has_bmi1) then raise_UD();
    if mp != MP_NONE then raise_UD();
    let (reg_field, src2) = fetch_modrm_raw(pfx);
    let 'os : {32, 64} = if pfx.vex_w then 64 else 32;
    let src = v(os, src2);
    let dst : gpr_idx = pfx.vex_vvvv % 16;
    let (result, cf) : (bits('os), bit) = match reg_field {
      1 => ((src - 1) & src,    is_zero(src)),    // BLSR
      2 => ((src - 1) ^ src,    is_zero(src)),    // BLSMSK
      3 => ((~(src) + 1) & src, is_nonzero(src)), // BLSI
      _ => raise_UD(),
    };
    v(dst) = result;
    SF = result[os - 1];
    ZF = if reg_field == 2 then 0b0 else is_zero(result);
    CF = cf;
    OF = 0b0
  },

  // 0F38 DB: VAESIMC — VEX.128.66.0F38.WIG DB
  219 => {
    if ~(has_aesni) then raise_UD();
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    if pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    let src : xmmword = decode_vex_src(128, modrm, src2, pfx);
    write_xmm(dst, __aesimc(src))
  },

  // 0F38 DC: VAESENC — VEX.128.66.0F38.WIG DC
  220 => {
    if ~(has_aesni) then raise_UD();
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let state : xmmword = read_xmm(pfx.vex_vvvv);
    let roundkey : xmmword = decode_vex_src(128, modrm, src, pfx);
    write_xmm(dst, __aesenc(state, roundkey))
  },

  // 0F38 DD: VAESENCLAST — VEX.128.66.0F38.WIG DD
  221 => {
    if ~(has_aesni) then raise_UD();
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let state : xmmword = read_xmm(pfx.vex_vvvv);
    let roundkey : xmmword = decode_vex_src(128, modrm, src, pfx);
    write_xmm(dst, __aesenclast(state, roundkey))
  },

  // 0F38 DE: VAESDEC — VEX.128.66.0F38.WIG DE
  222 => {
    if ~(has_aesni) then raise_UD();
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let state : xmmword = read_xmm(pfx.vex_vvvv);
    let roundkey : xmmword = decode_vex_src(128, modrm, src, pfx);
    write_xmm(dst, __aesdec(state, roundkey))
  },

  // 0F38 DF: VAESDECLAST — VEX.128.66.0F38.WIG DF
  223 => {
    if ~(has_aesni) then raise_UD();
    if mp != MP_66 then raise_UD();
    if pfx.vex_l then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let state : xmmword = read_xmm(pfx.vex_vvvv);
    let roundkey : xmmword = decode_vex_src(128, modrm, src, pfx);
    write_xmm(dst, __aesdeclast(state, roundkey))
  },

  // 0F38 F5: BZHI (NP) / PDEP (F2) / PEXT (F3) — multiplexed by mandatory prefix
  245 => {
    if ~(has_bmi2) then raise_UD();
    let (dst, src2) = fetch_modrm(pfx);
    let os : {32, 64} = if pfx.vex_w then 64 else 32;
    match mp {
      MP_NONE => {
        // BZHI: VEX.NDS.LZ.0F38.W0/W1 F5
        // dest = src1 & ((1 << src2[7:0]) - 1), if index < operand size
        let src1 = v(os, src2);
        let vvvv : gpr_idx = pfx.vex_vvvv % 16;
        let src2 = v(os, vvvv);
        let index : range(0, 255) = unsigned(src2[7..0]);
        let clamped = unsigned(min_u(to_bits(9, index), to_bits(9, os)));
        assert(clamped <= os);
        let shift_amt = os - clamped;
        let result = (src1 << shift_amt) >> shift_amt;
        CF = is_ge_u(to_bits(9, index), to_bits(9, os));
        v(dst) = result;
        SF = result[os - 1];
        ZF = is_zero(result);
        OF = 0b0
      },
      MP_F2 => {
        // PDEP: VEX.NDS.LZ.F2.0F38.W0/W1 F5
        // Parallel bit deposit: scatter contiguous low bits of src to mask positions
        let src : qword = zero_extend(v(os, pfx.vex_vvvv % 16));
        let mask : qword = zero_extend(v(os, src2));
        var temp : qword = zeros();
        var k : range(0, 63) = 0;
        foreach (i from 0 to (os - 1)) {
          temp[i] = src[k] & mask[i];
          k = (k + unsigned(mask[i])) % 64
        };
        v(dst) = temp[(os - 1) .. 0]
      },
      MP_F3 => {
        // PEXT: VEX.NDS.LZ.F3.0F38.W0/W1 F5
        // Parallel bit extract: gather bits at mask positions to contiguous low bits
        let src : qword = zero_extend(v(os, pfx.vex_vvvv % 16));
        let mask : qword = zero_extend(v(os, src2));
        var temp : qword = zeros();
        var k : range(0, 63) = 0;
        foreach (i from 0 to (os - 1)) {
          temp[k] = src[i] & mask[i];
          k = (k + unsigned(mask[i])) % 64
        };
        v(dst) = temp[(os - 1) .. 0]
      },
      _ => raise_UD(),
    }
  },

  // 0F38 F6: MULX (F2, VEX.NDD.LZ) — unsigned multiply without affecting flags
  246 => {
    if ~(has_bmi2) then raise_UD();
    if mp != MP_F2 then raise_UD();
    let (dst_hi, src) = fetch_modrm(pfx);
    let os : {16, 32, 64} = if pfx.vex_w then 64 else 32;
    let dst_lo : gpr_idx = pfx.vex_vvvv % 16;
    // Implicit source is EDX/RDX
    let src1 = v(os, RDX);
    let src2 = v(os, src);
    let product = to_bits_truncate(os * 2, unsigned(src1) * unsigned(src2));
    v(dst_lo) = product[(os - 1)..0];
    v(dst_hi) = product[(os * 2 - 1)..os]
  },

  // 0F38 F7: BEXTR (NP) / SARX (F3) / SHLX (66) / SHRX (F2) — multiplexed by prefix
  247 => {
    if mp == MP_NONE then { if ~(has_bmi1) then raise_UD() }
    else { if ~(has_bmi2) then raise_UD() };
    let (dst, src2) = fetch_modrm(pfx);
    let os : {16, 32, 64} = if pfx.vex_w then 64 else 32;
    match mp {
      MP_NONE => {
        // BEXTR: VEX.NDS.LZ.0F38 F7 — bit field extract
        let src = v(os, src2);
        let vvvv : gpr_idx = pfx.vex_vvvv % 16;
        let ctrl = v(os, vvvv);
        let start : range(0, 255) = unsigned(ctrl[7..0]);
        let len : range(0, 255) = unsigned(ctrl[15..8]);
        // Clamp start and len to os: start >= os → shift all out (result = 0),
        // len >= os → no masking (keep all bits).
        let cs = unsigned(min_u(to_bits(9, start), to_bits(9, os)));
        assert(cs <= os);
        let cl = unsigned(min_u(to_bits(9, len), to_bits(9, os)));
        assert(cl <= os);
        let shifted = src >> cs;
        let shift_amt = os - cl;
        let result = (shifted << shift_amt) >> shift_amt;
        v(dst) = result;
        ZF = is_zero(result);
        OF = 0b0;
        CF = 0b0
      },
      MP_F3 => {
        // SARX: VEX.NDS.LZ.F3.0F38.W0/W1 F7 — arithmetic right shift, no flags
        let src1 = v(os, src2);
        let vvvv : gpr_idx = pfx.vex_vvvv % 16;
        let count_val = v(os, vvvv);
        let count : range(0, 63) = if pfx.vex_w then unsigned(count_val[5..0])
                                    else unsigned(count_val[4..0]);
        v(dst) = src1 >>> count
      },
      MP_66 => {
        // SHLX: VEX.NDS.LZ.66.0F38.W0/W1 F7 — logical left shift, no flags
        let src1 = v(os, src2);
        let vvvv : gpr_idx = pfx.vex_vvvv % 16;
        let count_val = v(os, vvvv);
        let count : range(0, 63) = if pfx.vex_w then unsigned(count_val[5..0])
                                    else unsigned(count_val[4..0]);
        v(dst) = src1 << count
      },
      MP_F2 => {
        // SHRX: VEX.NDS.LZ.F2.0F38.W0/W1 F7 — logical right shift, no flags
        let src1 = v(os, src2);
        let vvvv : gpr_idx = pfx.vex_vvvv % 16;
        let count_val = v(os, vvvv);
        let count : range(0, 63) = if pfx.vex_w then unsigned(count_val[5..0])
                                    else unsigned(count_val[4..0]);
        v(dst) = src1 >> count
      },
    }
  },

  // -----------------------------------------------------------------------
  // SSE4.1 sign/zero-extend, arithmetic, min/max (0F38 20..41)
  // -----------------------------------------------------------------------

  // 0F38 20: VPMOVSXBW (66 prefix, vvvv must be 1111b)
  // 128-bit: sign-extend 8 bytes (low qword) to 8 words
  // 256-bit: sign-extend 16 bytes (full xmm) to 16 words
  32 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src = decode_vex_src(128, modrm, src2, pfx);
      write_ymm(dst, packed_widen_unop(256, PW_SignExtend, 8, 16, src))
    } else {
      let src : bits(64) = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => v(64, m),
      };
      write_xmm(dst, packed_widen_unop(128, PW_SignExtend, 8, 16, src))
    }
  },

  // 0F38 21: VPMOVSXBD (66 prefix, vvvv must be 1111b)
  // 128-bit: sign-extend 4 bytes (32 bits) to 4 dwords
  // 256-bit: sign-extend 8 bytes (64 bits) to 8 dwords
  33 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : bits(64) = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => v(64, m),
      };
      write_ymm(dst, packed_widen_unop(256, PW_SignExtend, 8, 32, src))
    } else {
      let src : bits(32) = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
        RM_mem(m) => v(32, m),
      };
      write_xmm(dst, packed_widen_unop(128, PW_SignExtend, 8, 32, src))
    }
  },

  // 0F38 22: VPMOVSXBQ (66 prefix, vvvv must be 1111b)
  // 128-bit: sign-extend 2 bytes (16 bits) to 2 qwords
  // 256-bit: sign-extend 4 bytes (32 bits) to 4 qwords
  34 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : bits(32) = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
        RM_mem(m) => v(32, m),
      };
      write_ymm(dst, packed_widen_unop(256, PW_SignExtend, 8, 64, src))
    } else {
      let src : bits(16) = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[15..0],
        RM_mem(m) => v(16, m),
      };
      write_xmm(dst, packed_widen_unop(128, PW_SignExtend, 8, 64, src))
    }
  },

  // 0F38 23: VPMOVSXWD (66 prefix, vvvv must be 1111b)
  // 128-bit: sign-extend 4 words (64 bits) to 4 dwords
  // 256-bit: sign-extend 8 words (128 bits) to 8 dwords
  35 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src = decode_vex_src(128, modrm, src2, pfx);
      write_ymm(dst, packed_widen_unop(256, PW_SignExtend, 16, 32, src))
    } else {
      let src : bits(64) = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => v(64, m),
      };
      write_xmm(dst, packed_widen_unop(128, PW_SignExtend, 16, 32, src))
    }
  },

  // 0F38 24: VPMOVSXWQ (66 prefix, vvvv must be 1111b)
  // 128-bit: sign-extend 2 words (32 bits) to 2 qwords
  // 256-bit: sign-extend 4 words (64 bits) to 4 qwords
  36 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : bits(64) = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => v(64, m),
      };
      write_ymm(dst, packed_widen_unop(256, PW_SignExtend, 16, 64, src))
    } else {
      let src : bits(32) = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
        RM_mem(m) => v(32, m),
      };
      write_xmm(dst, packed_widen_unop(128, PW_SignExtend, 16, 64, src))
    }
  },

  // 0F38 25: VPMOVSXDQ (66 prefix, vvvv must be 1111b)
  // 128-bit: sign-extend 2 dwords (64 bits) to 2 qwords
  // 256-bit: sign-extend 4 dwords (128 bits) to 4 qwords
  37 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src = decode_vex_src(128, modrm, src2, pfx);
      write_ymm(dst, packed_widen_unop(256, PW_SignExtend, 32, 64, src))
    } else {
      let src : bits(64) = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => v(64, m),
      };
      write_xmm(dst, packed_widen_unop(128, PW_SignExtend, 32, 64, src))
    }
  },

  // 0F38 28: VPMULDQ (66 prefix)
  // Multiply signed dwords at positions 0 and 2 producing qword results
  40 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vvvv = pfx.vex_vvvv;
    if pfx.vex_l then {
      write_ymm(dst, avx_pmuldq_256(read_ymm(vvvv), decode_vex_src(256, modrm, src, pfx)))
    } else {
      write_xmm(dst, avx_pmuldq_128(read_xmm(vvvv), decode_vex_src(128, modrm, src, pfx)))
    }
  },

  // 0F38 29: VPCMPEQQ (66 prefix)
  41 => { if mp != MP_66 then raise_UD(); vex_exec_binop(PB_CmpEq, 64, pfx) },

  // 0F38 2A: VMOVNTDQA (66 prefix, vvvv must be 1111b)
  // Non-temporal aligned load; memory-only source
  42 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    if pfx.vex_l then write_ymm(dst, rm_mem(src))
    else write_xmm(dst, rm_mem(src))
  },

  // 0F38 2B: VPACKUSDW (66 prefix)
  // Pack dwords to words with unsigned saturation
  43 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1); let dst = modrm_xmm_reg(modrm, pfx); let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_pack(PN_SatSU, 32, 16, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx)))
  },

  // 0F38 30: VPMOVZXBW (66 prefix, vvvv must be 1111b)
  // 128-bit: zero-extend 8 bytes (64 bits) to 8 words
  // 256-bit: zero-extend 16 bytes (128 bits) to 16 words
  48 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src = decode_vex_src(128, modrm, src2, pfx);
      write_ymm(dst, packed_widen_unop(256, PW_ZeroExtend, 8, 16, src))
    } else {
      let src : bits(64) = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => v(64, m),
      };
      write_xmm(dst, packed_widen_unop(128, PW_ZeroExtend, 8, 16, src))
    }
  },

  // 0F38 31: VPMOVZXBD (66 prefix, vvvv must be 1111b)
  // 128-bit: zero-extend 4 bytes (32 bits) to 4 dwords
  // 256-bit: zero-extend 8 bytes (64 bits) to 8 dwords
  49 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : bits(64) = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => v(64, m),
      };
      write_ymm(dst, packed_widen_unop(256, PW_ZeroExtend, 8, 32, src))
    } else {
      let src : bits(32) = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
        RM_mem(m) => v(32, m),
      };
      write_xmm(dst, packed_widen_unop(128, PW_ZeroExtend, 8, 32, src))
    }
  },

  // 0F38 32: VPMOVZXBQ (66 prefix, vvvv must be 1111b)
  // 128-bit: zero-extend 2 bytes (16 bits) to 2 qwords
  // 256-bit: zero-extend 4 bytes (32 bits) to 4 qwords
  50 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : bits(32) = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
        RM_mem(m) => v(32, m),
      };
      write_ymm(dst, packed_widen_unop(256, PW_ZeroExtend, 8, 64, src))
    } else {
      let src : bits(16) = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[15..0],
        RM_mem(m) => v(16, m),
      };
      write_xmm(dst, packed_widen_unop(128, PW_ZeroExtend, 8, 64, src))
    }
  },

  // 0F38 33: VPMOVZXWD (66 prefix, vvvv must be 1111b)
  // 128-bit: zero-extend 4 words (64 bits) to 4 dwords
  // 256-bit: zero-extend 8 words (128 bits) to 8 dwords
  51 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src = decode_vex_src(128, modrm, src2, pfx);
      write_ymm(dst, packed_widen_unop(256, PW_ZeroExtend, 16, 32, src))
    } else {
      let src : bits(64) = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => v(64, m),
      };
      write_xmm(dst, packed_widen_unop(128, PW_ZeroExtend, 16, 32, src))
    }
  },

  // 0F38 34: VPMOVZXWQ (66 prefix, vvvv must be 1111b)
  // 128-bit: zero-extend 2 words (32 bits) to 2 qwords
  // 256-bit: zero-extend 4 words (64 bits) to 4 qwords
  52 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : bits(64) = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => v(64, m),
      };
      write_ymm(dst, packed_widen_unop(256, PW_ZeroExtend, 16, 64, src))
    } else {
      let src : bits(32) = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[31..0],
        RM_mem(m) => v(32, m),
      };
      write_xmm(dst, packed_widen_unop(128, PW_ZeroExtend, 16, 64, src))
    }
  },

  // 0F38 35: VPMOVZXDQ (66 prefix, vvvv must be 1111b)
  // 128-bit: zero-extend 2 dwords (64 bits) to 2 qwords
  // 256-bit: zero-extend 4 dwords (128 bits) to 4 qwords
  53 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src = decode_vex_src(128, modrm, src2, pfx);
      write_ymm(dst, packed_widen_unop(256, PW_ZeroExtend, 32, 64, src))
    } else {
      let src : bits(64) = match src2 {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx))[63..0],
        RM_mem(m) => v(64, m),
      };
      write_xmm(dst, packed_widen_unop(128, PW_ZeroExtend, 32, 64, src))
    }
  },

  // 0F38 38: VPMINSB (66 prefix)
  // Packed minimum of signed bytes
  56 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_binop(PB_MinS, 8, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx)))
  },

  // 0F38 39: VPMINSD (66 prefix)
  57 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_binop(PB_MinS, 32, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx)))
  },

  // 0F38 3A: VPMINUW (66 prefix)
  58 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_binop(PB_MinU, 16, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx)))
  },

  // 0F38 3B: VPMINUD (66 prefix)
  59 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_binop(PB_MinU, 32, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx)))
  },

  // 0F38 3C: VPMAXSB (66 prefix)
  60 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_binop(PB_MaxS, 8, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx)))
  },

  // 0F38 3D: VPMAXSD (66 prefix)
  61 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_binop(PB_MaxS, 32, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx)))
  },

  // 0F38 3E: VPMAXUW (66 prefix)
  62 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_binop(PB_MaxU, 16, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx)))
  },

  // 0F38 3F: VPMAXUD (66 prefix)
  63 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_binop(PB_MaxU, 32, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx)))
  },

  // 0F38 40: VPMULLD (66 prefix)
  64 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let vl = vex_vl(pfx);
    write_simd(vl, dst, packed_binop(PB_MulLow, 32, read_simd(vl, pfx.vex_vvvv), decode_vex_src(modrm, src, pfx)))
  },

  // 0F38 41: VPHMINPOSUW (66 prefix, VEX.128 only, vvvv must be 1111b)
  65 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    if pfx.vex_l then raise_UD(); // VEX.128 only
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    let src : xmmword = decode_vex_src(128, modrm, src2, pfx);
    write_xmm(dst, avx_phminposuw_128(src))
  },

  // 0F38 0E: VTESTPS xmm, xmm/m128 or ymm, ymm/m256 (VEX.128/256.66.0F38.W0)
  // SDM: VEX.vvvv must be 1111b
  // Sets ZF if AND(src1, src2) == 0; sets CF if AND(NOT src1, src2) == 0
  // Clears OF, AF, PF, SF
  14 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 | pfx.vex_w then raise_UD();
    let modrm = fetch(1);
    let src1_idx = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src(256, modrm, src, pfx);
      let tmp1 : ymmword = src1 & src2;
      let tmp2 : ymmword = ~(src1) & src2;
      ZF = is_zero(tmp1[255..192] | tmp1[191..128] | tmp1[127..64] | tmp1[63..0]);
      CF = is_zero(tmp2[255..192] | tmp2[191..128] | tmp2[127..64] | tmp2[63..0]);
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_vex_src(128, modrm, src, pfx);
      let tmp1 : xmmword = src1 & src2;
      let tmp2 : xmmword = ~(src1) & src2;
      ZF = is_zero(tmp1[127..64] | tmp1[63..0]);
      CF = is_zero(tmp2[127..64] | tmp2[63..0]);
    };
    OF = 0b0;
    AF = 0b0;
    PF = 0b0;
    SF = 0b0
  },

  // 0F38 0F: VTESTPD xmm, xmm/m128 or ymm, ymm/m256 (VEX.128/256.66.0F38.W0)
  // SDM: VEX.vvvv must be 1111b
  // Same logic as VTESTPS but for packed doubles (bit-level identical)
  15 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 | pfx.vex_w then raise_UD();
    let modrm = fetch(1);
    let src1_idx = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src(256, modrm, src, pfx);
      let tmp1 : ymmword = src1 & src2;
      let tmp2 : ymmword = ~(src1) & src2;
      ZF = is_zero(tmp1[255..192] | tmp1[191..128] | tmp1[127..64] | tmp1[63..0]);
      CF = is_zero(tmp2[255..192] | tmp2[191..128] | tmp2[127..64] | tmp2[63..0]);
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_vex_src(128, modrm, src, pfx);
      let tmp1 : xmmword = src1 & src2;
      let tmp2 : xmmword = ~(src1) & src2;
      ZF = is_zero(tmp1[127..64] | tmp1[63..0]);
      CF = is_zero(tmp2[127..64] | tmp2[63..0]);
    };
    OF = 0b0;
    AF = 0b0;
    PF = 0b0;
    SF = 0b0
  },

  // 0F38 16: VPERMPS ymm, ymm, ymm/m256 (VEX.256.66.0F38.W0)
  // VEX.256 only; L=0 → #UD
  22 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    if ~(pfx.vex_l) then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    let ctrl : ymmword = read_ymm(pfx.vex_vvvv);
    let src : ymmword = decode_vex_src(256, modrm, src2, pfx);
    write_ymm(dst, vex_vpermd_256(ctrl, src))
  },

  // 0F38 2C: VMASKMOVPS load xmm1, xmm2, m128 (VEX.128/256.66.0F38.W0)
  // dst = modrm_reg, mask = vvvv, src = memory (RM_reg → #UD)
  44 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let mask : ymmword = read_ymm(pfx.vex_vvvv);
      let data : ymmword = rm_mem(src);
      write_ymm(dst, vex_maskmovps_load_256(mask, data))
    } else {
      let mask : xmmword = read_xmm(pfx.vex_vvvv);
      let data : xmmword = rm_mem(src);
      write_xmm(dst, vex_maskmovps_load_128(mask, data))
    }
  },

  // 0F38 2D: VMASKMOVPD load xmm1, xmm2, m128 (VEX.128/256.66.0F38.W0)
  // dst = modrm_reg, mask = vvvv, src = memory (RM_reg → #UD)
  45 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let mask : ymmword = read_ymm(pfx.vex_vvvv);
      let data : ymmword = rm_mem(src);
      write_ymm(dst, vex_maskmovpd_load_256(mask, data))
    } else {
      let mask : xmmword = read_xmm(pfx.vex_vvvv);
      let data : xmmword = rm_mem(src);
      write_xmm(dst, vex_maskmovpd_load_128(mask, data))
    }
  },

  // 0F38 2E: VMASKMOVPS store m128, xmm2, xmm1 (VEX.128/256.66.0F38.W0)
  // src = modrm_reg, mask = vvvv, dst = memory (RM_reg → #UD)
  46 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    let modrm = fetch(1);
    let src_idx = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    match src2 {
      RM_reg(_) => raise_UD(),
      RM_mem(m) => {
        let a = seg_linear(m, if pfx.vex_l then 32 else 16);
        if pfx.vex_l then {
          let mask : ymmword = read_ymm(pfx.vex_vvvv);
          let src : ymmword = read_ymm(src_idx);
          foreach (i from 0 to 7) {
            if mask[(i * 32 + 31)] == 0b1 then
              write_mem(32, a + zero_extend(to_bits(64, i * 4)), src[(i * 32 + 31) .. (i * 32)])
          }
        } else {
          let mask : xmmword = read_xmm(pfx.vex_vvvv);
          let src : xmmword = read_xmm(src_idx);
          foreach (i from 0 to 3) {
            if mask[(i * 32 + 31)] == 0b1 then
              write_mem(32, a + zero_extend(to_bits(64, i * 4)), src[(i * 32 + 31) .. (i * 32)])
          }
        }
      },
    }
  },

  // 0F38 2F: VMASKMOVPD store m128, xmm2, xmm1 (VEX.128/256.66.0F38.W0)
  // src = modrm_reg, mask = vvvv, dst = memory (RM_reg → #UD)
  47 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    let modrm = fetch(1);
    let src_idx = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    match src2 {
      RM_reg(_) => raise_UD(),
      RM_mem(m) => {
        let a = seg_linear(m, if pfx.vex_l then 32 else 16);
        if pfx.vex_l then {
          let mask : ymmword = read_ymm(pfx.vex_vvvv);
          let src : ymmword = read_ymm(src_idx);
          foreach (i from 0 to 3) {
            if mask[(i * 64 + 63)] == 0b1 then
              write_mem(64, a + zero_extend(to_bits(64, i * 8)), src[(i * 64 + 63) .. (i * 64)])
          }
        } else {
          let mask : xmmword = read_xmm(pfx.vex_vvvv);
          let src : xmmword = read_xmm(src_idx);
          foreach (i from 0 to 1) {
            if mask[(i * 64 + 63)] == 0b1 then
              write_mem(64, a + zero_extend(to_bits(64, i * 8)), src[(i * 64 + 63) .. (i * 64)])
          }
        }
      },
    }
  },

  // 0F38 36: VPERMD ymm1, ymm2, ymm3/m256 (VEX.256.66.0F38.W0)
  // VEX.256 only; L=0 → #UD
  54 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    if ~(pfx.vex_l) then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    let ctrl : ymmword = read_ymm(pfx.vex_vvvv);
    let src : ymmword = decode_vex_src(256, modrm, src2, pfx);
    write_ymm(dst, vex_vpermd_256(ctrl, src))
  },

  // 0F38 45: VPSRLVD (W0) / VPSRLVQ (W1) (VEX.128/256.66.0F38)
  69 => {
    if mp != MP_66 then raise_UD();
    let eb = vex_elem(pfx);
    vex_exec_binop(PB_Srl, eb, pfx)
  },
  // 0F38 46: VPSRAVD (VEX.128/256.66.0F38.W0)
  70 => {
    if mp != MP_66 | pfx.vex_w then raise_UD();
    vex_exec_binop(PB_Sra, 32, pfx)
  },

  // 0F38 47: VPSLLVD (W0) / VPSLLVQ (W1) (VEX.128/256.66.0F38)
  71 => {
    if mp != MP_66 then raise_UD();
    let eb = vex_elem(pfx);
    vex_exec_binop(PB_Sll, eb, pfx)
  },

  // 0F38 90: VPGATHERDD (66,W0) / VPGATHERDQ (66,W1) — dword indices, VEX gather
  144 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let vsib = decode_vsib_vex(modrm, pfx);
    let mask_idx = pfx.vex_vvvv;
    if pfx.vex_w then {
      // VPGATHERDQ: dword indices, qword elements
      if pfx.vex_l then {
        var result : ymmword = read_ymm(dst);
        let mask : ymmword = read_ymm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 3) {
          if mask[(i * 64 + 63)] == 0b1 then {
            let idx : dword = indices[(i * 32 + 31) .. (i * 32)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 64 + 63) .. (i * 64)] = read_mem(64, addr)
          }
        };
        write_ymm(dst, result);
        write_ymm(mask_idx, zeros())
      } else {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 1) {
          if mask[(i * 64 + 63)] == 0b1 then {
            let idx : dword = indices[(i * 32 + 31) .. (i * 32)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 64 + 63) .. (i * 64)] = read_mem(64, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      }
    } else {
      // VPGATHERDD: dword indices, dword elements
      if pfx.vex_l then {
        var result : ymmword = read_ymm(dst);
        let mask : ymmword = read_ymm(mask_idx);
        let indices : ymmword = read_ymm(vsib.vsib_vidx);
        foreach (i from 0 to 7) {
          if mask[(i * 32 + 31)] == 0b1 then {
            let idx : dword = indices[(i * 32 + 31) .. (i * 32)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 32 + 31) .. (i * 32)] = read_mem(32, addr)
          }
        };
        write_ymm(dst, result);
        write_ymm(mask_idx, zeros())
      } else {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 3) {
          if mask[(i * 32 + 31)] == 0b1 then {
            let idx : dword = indices[(i * 32 + 31) .. (i * 32)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 32 + 31) .. (i * 32)] = read_mem(32, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      }
    }
  },

  // 0F38 91: VPGATHERQD (66,W0) / VPGATHERQQ (66,W1) — qword indices, VEX gather
  145 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let vsib = decode_vsib_vex(modrm, pfx);
    let mask_idx = pfx.vex_vvvv;
    if pfx.vex_w then {
      // VPGATHERQQ: qword indices, qword elements
      if pfx.vex_l then {
        var result : ymmword = read_ymm(dst);
        let mask : ymmword = read_ymm(mask_idx);
        let indices : ymmword = read_ymm(vsib.vsib_vidx);
        foreach (i from 0 to 3) {
          if mask[(i * 64 + 63)] == 0b1 then {
            let idx : qword = indices[(i * 64 + 63) .. (i * 64)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 64 + 63) .. (i * 64)] = read_mem(64, addr)
          }
        };
        write_ymm(dst, result);
        write_ymm(mask_idx, zeros())
      } else {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 1) {
          if mask[(i * 64 + 63)] == 0b1 then {
            let idx : qword = indices[(i * 64 + 63) .. (i * 64)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 64 + 63) .. (i * 64)] = read_mem(64, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      }
    } else {
      // VPGATHERQD: qword indices, dword elements
      if pfx.vex_l then {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : ymmword = read_ymm(vsib.vsib_vidx);
        foreach (i from 0 to 3) {
          if mask[(i * 32 + 31)] == 0b1 then {
            let idx : qword = indices[(i * 64 + 63) .. (i * 64)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 32 + 31) .. (i * 32)] = read_mem(32, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      } else {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 1) {
          if mask[(i * 32 + 31)] == 0b1 then {
            let idx : qword = indices[(i * 64 + 63) .. (i * 64)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 32 + 31) .. (i * 32)] = read_mem(32, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      }
    }
  },

  // 0F38 92: VGATHERDPS (66,W0) / VGATHERDPD (66,W1) — same encoding as 90 but FP
  146 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let vsib = decode_vsib_vex(modrm, pfx);
    let mask_idx = pfx.vex_vvvv;
    if pfx.vex_w then {
      // VGATHERDPD: dword indices, f64 elements
      if pfx.vex_l then {
        var result : ymmword = read_ymm(dst);
        let mask : ymmword = read_ymm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 3) {
          if mask[(i * 64 + 63)] == 0b1 then {
            let idx : dword = indices[(i * 32 + 31) .. (i * 32)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 64 + 63) .. (i * 64)] = read_mem(64, addr)
          }
        };
        write_ymm(dst, result);
        write_ymm(mask_idx, zeros())
      } else {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 1) {
          if mask[(i * 64 + 63)] == 0b1 then {
            let idx : dword = indices[(i * 32 + 31) .. (i * 32)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 64 + 63) .. (i * 64)] = read_mem(64, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      }
    } else {
      // VGATHERDPS: dword indices, f32 elements
      if pfx.vex_l then {
        var result : ymmword = read_ymm(dst);
        let mask : ymmword = read_ymm(mask_idx);
        let indices : ymmword = read_ymm(vsib.vsib_vidx);
        foreach (i from 0 to 7) {
          if mask[(i * 32 + 31)] == 0b1 then {
            let idx : dword = indices[(i * 32 + 31) .. (i * 32)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 32 + 31) .. (i * 32)] = read_mem(32, addr)
          }
        };
        write_ymm(dst, result);
        write_ymm(mask_idx, zeros())
      } else {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 3) {
          if mask[(i * 32 + 31)] == 0b1 then {
            let idx : dword = indices[(i * 32 + 31) .. (i * 32)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 32 + 31) .. (i * 32)] = read_mem(32, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      }
    }
  },

  // 0F38 93: VGATHERQPS (66,W0) / VGATHERQPD (66,W1) — same encoding as 91 but FP
  147 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let vsib = decode_vsib_vex(modrm, pfx);
    let mask_idx = pfx.vex_vvvv;
    if pfx.vex_w then {
      // VGATHERQPD: qword indices, f64 elements
      if pfx.vex_l then {
        var result : ymmword = read_ymm(dst);
        let mask : ymmword = read_ymm(mask_idx);
        let indices : ymmword = read_ymm(vsib.vsib_vidx);
        foreach (i from 0 to 3) {
          if mask[(i * 64 + 63)] == 0b1 then {
            let idx : qword = indices[(i * 64 + 63) .. (i * 64)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 64 + 63) .. (i * 64)] = read_mem(64, addr)
          }
        };
        write_ymm(dst, result);
        write_ymm(mask_idx, zeros())
      } else {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 1) {
          if mask[(i * 64 + 63)] == 0b1 then {
            let idx : qword = indices[(i * 64 + 63) .. (i * 64)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 64 + 63) .. (i * 64)] = read_mem(64, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      }
    } else {
      // VGATHERQPS: qword indices, f32 elements
      if pfx.vex_l then {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : ymmword = read_ymm(vsib.vsib_vidx);
        foreach (i from 0 to 3) {
          if mask[(i * 32 + 31)] == 0b1 then {
            let idx : qword = indices[(i * 64 + 63) .. (i * 64)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 32 + 31) .. (i * 32)] = read_mem(32, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      } else {
        var result : xmmword = read_xmm(dst);
        let mask : xmmword = read_xmm(mask_idx);
        let indices : xmmword = read_xmm(vsib.vsib_vidx);
        foreach (i from 0 to 1) {
          if mask[(i * 32 + 31)] == 0b1 then {
            let idx : qword = indices[(i * 64 + 63) .. (i * 64)];
            let addr = gather_addr(vsib.vsib_base, idx, vsib.vsib_scale);
            result[(i * 32 + 31) .. (i * 32)] = read_mem(32, addr)
          }
        };
        write_xmm(dst, result);
        write_xmm(mask_idx, zeros())
      }
    }
  },

  // 0F38 0C: VPERMILPS xmm/ymm, xmm/ymm, xmm/ymm/m (66, register-controlled)
  // VEX.NDS: VPERMILPS dst(reg), src(vvvv), ctrl(r/m)
  12 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : ymmword = read_ymm(pfx.vex_vvvv);
      let ctrl : ymmword = decode_vex_src(256, modrm, src2, pfx);
      var result : ymmword = zeros();
      // Per 128-bit lane, select from 4 dwords within that lane
      foreach (i from 0 to 3) {
        let sel : range(0, 3) = unsigned(ctrl[(i * 32 + 1) .. (i * 32)]);
        result[(i * 32 + 31) .. (i * 32)] = src[(sel * 32 + 31) .. (sel * 32)]
      };
      foreach (i from 4 to 7) {
        let sel : range(0, 3) = unsigned(ctrl[(i * 32 + 1) .. (i * 32)]);
        result[(i * 32 + 31) .. (i * 32)] = src[((sel + 4) * 32 + 31) .. ((sel + 4) * 32)]
      };
      write_ymm(dst, result)
    } else {
      let src : xmmword = read_xmm(pfx.vex_vvvv);
      let ctrl : xmmword = decode_vex_src(128, modrm, src2, pfx);
      var result : xmmword = zeros();
      foreach (i from 0 to 3) {
        let sel : range(0, 3) = unsigned(ctrl[(i * 32 + 1) .. (i * 32)]);
        result[(i * 32 + 31) .. (i * 32)] = src[(sel * 32 + 31) .. (sel * 32)]
      };
      write_xmm(dst, result)
    }
  },

  // 0F38 0D: VPERMILPD xmm/ymm, xmm/ymm, xmm/ymm/m (66, register-controlled)
  // VEX.NDS: VPERMILPD dst(reg), src(vvvv), ctrl(r/m)
  13 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src2 = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src : ymmword = read_ymm(pfx.vex_vvvv);
      let ctrl : ymmword = decode_vex_src(256, modrm, src2, pfx);
      var result : ymmword = zeros();
      // Per 128-bit lane, select from 2 qwords within that lane using bit 1
      let s0 : range(0, 1) = unsigned(ctrl[1]);
      result[63..0] = src[(s0 * 64 + 63) .. (s0 * 64)];
      let s1 : range(0, 1) = unsigned(ctrl[65]);
      result[127..64] = src[(s1 * 64 + 63 + 0) .. (s1 * 64 + 0)];
      let s2 : range(0, 1) = unsigned(ctrl[129]);
      result[191..128] = src[((s2 + 2) * 64 + 63) .. ((s2 + 2) * 64)];
      let s3 : range(0, 1) = unsigned(ctrl[193]);
      result[255..192] = src[((s3 + 2) * 64 + 63) .. ((s3 + 2) * 64)];
      write_ymm(dst, result)
    } else {
      let src : xmmword = read_xmm(pfx.vex_vvvv);
      let ctrl : xmmword = decode_vex_src(128, modrm, src2, pfx);
      var result : xmmword = zeros();
      let s0 : range(0, 1) = unsigned(ctrl[1]);
      result[63..0] = src[(s0 * 64 + 63) .. (s0 * 64)];
      let s1 : range(0, 1) = unsigned(ctrl[65]);
      result[127..64] = src[(s1 * 64 + 63) .. (s1 * 64)];
      write_xmm(dst, result)
    }
  },

  // 0F38 17: VPTEST xmm/ymm, xmm/ymm/m (66 prefix, vvvv must be 1111b)
  23 => {
    if mp != MP_66 | pfx.vex_vvvv != 0 then raise_UD();
    let modrm = fetch(1);
    let src1_idx = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src(256, modrm, src, pfx);
      let tmp1 : ymmword = src1 & src2;
      let tmp2 : ymmword = ~(src1) & src2;
      ZF = is_zero(tmp1[255..192] | tmp1[191..128] | tmp1[127..64] | tmp1[63..0]);
      CF = is_zero(tmp2[255..192] | tmp2[191..128] | tmp2[127..64] | tmp2[63..0]);
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_vex_src(128, modrm, src, pfx);
      let tmp1 : xmmword = src1 & src2;
      let tmp2 : xmmword = ~(src1) & src2;
      ZF = is_zero(tmp1[127..64] | tmp1[63..0]);
      CF = is_zero(tmp2[127..64] | tmp2[63..0]);
    };
    OF = 0b0;
    AF = 0b0;
    PF = 0b0;
    SF = 0b0
  },

  // 0F38 37: VPCMPGTQ xmm/ymm, xmm/ymm, xmm/ymm/m (66 prefix)
  55 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(pfx.vex_vvvv);
      let src2 : ymmword = decode_vex_src(256, modrm, src, pfx);
      var result : ymmword = zeros();
      foreach (i from 0 to 3) {
        let a : bits(64) = src1[(i * 64 + 63) .. (i * 64)];
        let b : bits(64) = src2[(i * 64 + 63) .. (i * 64)];
        result[(i * 64 + 63) .. (i * 64)] = cmp_gt(a, b)
      };
      write_ymm(dst, result)
    } else {
      let src1 : xmmword = read_xmm(pfx.vex_vvvv);
      let src2 : xmmword = decode_vex_src(128, modrm, src, pfx);
      var result : xmmword = zeros();
      foreach (i from 0 to 1) {
        let a : bits(64) = src1[(i * 64 + 63) .. (i * 64)];
        let b : bits(64) = src2[(i * 64 + 63) .. (i * 64)];
        result[(i * 64 + 63) .. (i * 64)] = cmp_gt(a, b)
      };
      write_xmm(dst, result)
    }
  },

  // 0F38 8C: VPMASKMOVD/Q (load) xmm/ymm, xmm/ymm, m (66 prefix)
  140 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    match src {
      RM_mem(m) => {
        let a = seg_linear(m, if pfx.vex_l then 32 else 16);
        let mask_idx = pfx.vex_vvvv;
        match (pfx.vex_l, pfx.rex_w) {
          // VPMASKMOVQ: qword elements
          (true, true) => {
            let mask : ymmword = read_ymm(mask_idx);
            var result : ymmword = zeros();
            foreach (i from 0 to 3) {
              if mask[(i * 64 + 63)] == 0b1 then
                result[(i * 64 + 63) .. (i * 64)] = read_mem(64, a + to_bits(64, i * 8))
            };
            write_ymm(dst, result)
          },
          (false, true) => {
            let mask : xmmword = read_xmm(mask_idx);
            var result : xmmword = zeros();
            foreach (i from 0 to 1) {
              if mask[(i * 64 + 63)] == 0b1 then
                result[(i * 64 + 63) .. (i * 64)] = read_mem(64, a + to_bits(64, i * 8))
            };
            write_xmm(dst, result)
          },
          // VPMASKMOVD: dword elements
          (true, false) => {
            let mask : ymmword = read_ymm(mask_idx);
            var result : ymmword = zeros();
            foreach (i from 0 to 7) {
              if mask[(i * 32 + 31)] == 0b1 then
                result[(i * 32 + 31) .. (i * 32)] = read_mem(32, a + to_bits(64, i * 4))
            };
            write_ymm(dst, result)
          },
          (false, false) => {
            let mask : xmmword = read_xmm(mask_idx);
            var result : xmmword = zeros();
            foreach (i from 0 to 3) {
              if mask[(i * 32 + 31)] == 0b1 then
                result[(i * 32 + 31) .. (i * 32)] = read_mem(32, a + to_bits(64, i * 4))
            };
            write_xmm(dst, result)
          },
        }
      },
      RM_reg(_) => raise_UD(),
    }
  },

  // 0F38 8E: VPMASKMOVD/Q (store) m, xmm/ymm, xmm/ymm (66 prefix)
  142 => {
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let src = modrm_xmm_reg(modrm, pfx);
    let dest = modrm_rm(modrm, pfx);
    match dest {
      RM_mem(m) => {
        let a = seg_linear(m, if pfx.vex_l then 32 else 16);
        let mask_idx = pfx.vex_vvvv;
        match (pfx.vex_l, pfx.rex_w) {
          // VPMASKMOVQ: qword elements
          (true, true) => {
            let mask : ymmword = read_ymm(mask_idx);
            let data : ymmword = read_ymm(src);
            foreach (i from 0 to 3) {
              if mask[(i * 64 + 63)] == 0b1 then
                write_mem(64, a + to_bits(64, i * 8), data[(i * 64 + 63) .. (i * 64)])
            }
          },
          (false, true) => {
            let mask : xmmword = read_xmm(mask_idx);
            let data : xmmword = read_xmm(src);
            foreach (i from 0 to 1) {
              if mask[(i * 64 + 63)] == 0b1 then
                write_mem(64, a + to_bits(64, i * 8), data[(i * 64 + 63) .. (i * 64)])
            }
          },
          // VPMASKMOVD: dword elements
          (true, false) => {
            let mask : ymmword = read_ymm(mask_idx);
            let data : ymmword = read_ymm(src);
            foreach (i from 0 to 7) {
              if mask[(i * 32 + 31)] == 0b1 then
                write_mem(32, a + to_bits(64, i * 4), data[(i * 32 + 31) .. (i * 32)])
            }
          },
          (false, false) => {
            let mask : xmmword = read_xmm(mask_idx);
            let data : xmmword = read_xmm(src);
            foreach (i from 0 to 3) {
              if mask[(i * 32 + 31)] == 0b1 then
                write_mem(32, a + to_bits(64, i * 4), data[(i * 32 + 31) .. (i * 32)])
            }
          },
        }
      },
      RM_reg(_) => raise_UD(),
    }
  },

  // VGF2P8MULB: VEX.128/256.66.0F38.W0 CF /r
  207 => {
    let mp = get_mandatory_prefix(pfx);
    if mp != MP_66 then raise_UD();
    let modrm = fetch(1);
    let dst = modrm_xmm_reg(modrm, pfx);
    let src1_idx = pfx.vex_vvvv;
    let src = modrm_rm(modrm, pfx);
    if pfx.vex_l then {
      let src1 : ymmword = read_ymm(src1_idx);
      let src2 : ymmword = decode_vex_src(modrm, src, pfx);
      write_ymm(dst, avx_gf2p8mulb(src1, src2))
    } else {
      let src1 : xmmword = read_xmm(src1_idx);
      let src2 : xmmword = decode_xmm_src(modrm, src, pfx);
      write_xmm(dst, avx_gf2p8mulb(src1, src2))
    }
  },

  _ => raise_UD(),
  }
}

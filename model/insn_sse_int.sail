// x86-64 — SSE Integer Operations
//
// SSE/SSE2/SSSE3/SSE4.1/SSE4.2 packed integer arithmetic, logical,
// shift, pack/unpack, compare, AES-NI, and PCLMULQDQ.

// Forward declaration — defined in insn_mmx.sail (compiled after this file)
val dispatch_mmx : (range(0, 255), Prefixes) -> unit

// =========================================================================
// SSE dispatch helpers — absorb common decode boilerplate
// =========================================================================

// 2-operand SSE binop with MMX fallback: dst = packed_binop(dst, src)
val sse_exec_binop : (range(0, 255), PackedBinOp, {8, 16, 32, 64, 128}, Prefixes) -> unit
function sse_exec_binop(op, binop_op, eb, pfx) = {
  let mp = get_mandatory_prefix(pfx);
  if mp != MP_66 then dispatch_mmx(op, pfx)
  else {
    let modrm = fetch(1);
    let xreg = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
    ZMM[xreg][127..0] = packed_binop(binop_op, eb, read_simd(xreg), src_xmm)
  }
}

// 2-operand SSE unary op with MMX fallback: dst = packed_unop(src)
val sse_exec_unop : (range(0, 255), PackedUnaryOp, {8, 16, 32, 64}, Prefixes) -> unit
function sse_exec_unop(op, unop_op, eb, pfx) = {
  let mp = get_mandatory_prefix(pfx);
  if mp != MP_66 then dispatch_mmx(op, pfx)
  else {
    let modrm = fetch(1);
    let xreg = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
    ZMM[xreg][127..0] = packed_unop(unop_op, eb, src_xmm)
  }
}

// 2-operand SSE shift-by-xmm with MMX fallback: dst = shift(dst, count from src[63:0])
val sse_exec_shift : (range(0, 255), PackedShiftOp, {16, 32, 64}, Prefixes) -> unit
function sse_exec_shift(op, shift_op, eb, pfx) = {
  let mp = get_mandatory_prefix(pfx);
  if mp != MP_66 then dispatch_mmx(op, pfx)
  else {
    let modrm = fetch(1);
    let xreg = modrm_xmm_reg(modrm, pfx);
    let src = modrm_rm(modrm, pfx);
    let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
    let c : nat = unsigned(src_xmm[63..0]);
    ZMM[xreg][127..0] = packed_uniform_shift(shift_op, eb, read_simd(xreg), c)
  }
}

// =========================================================================
// SSE integer helper functions
// =========================================================================

// CRC32 — Accumulate CRC32C (Castagnoli) value
// Polynomial: 0x1EDC6F41 (reflected: 0x82F63B78)
// Processes one byte at a time using the reflected algorithm.
val crc32c : forall 'n, 'n > 0. (implicit('n), bits(32), bits(8 * 'n)) -> bits(32)
function crc32c(n, crc, data) = {
  var c : bits(32) = crc;
  foreach (i from 0 to (n - 1)) {
    let byte_lo = 8 * i;
    c = c ^ zero_extend(data[(byte_lo + 7) .. byte_lo]);
    foreach (j from 0 to 7) {
      c = (c >> 1) ^ (sign_extend(c[0]) & 0x82F63B78)
    }
  };
  c
}

// PINSRB — Insert Byte (SSE4.1)
// PINSRD — Insert Dword (SSE4.1)
// PINSRQ — Insert Qword (SSE4.1)
// No flags affected.
val insert_byte : (xmmword, byte, range(0, 15)) -> xmmword
function insert_byte(v, b, sel) = {
  let shift : nat = sel * 8;
  let mask : xmmword = ~(zero_extend(0xFF) << shift);
  (v & mask) | (zero_extend(b) << shift)
}

val insert_dword : (xmmword, dword, range(0, 3)) -> xmmword
function insert_dword(v, d, sel) = {
  let shift : nat = sel * 32;
  let mask : xmmword = ~(zero_extend(0xFFFFFFFF) << shift);
  (v & mask) | (zero_extend(d) << shift)
}

// PMULHRSW — Packed Multiply High with Round and Scale (SSSE3)
// No flags affected.
val mulhrsw : (word, word) -> word
function mulhrsw(a, b) = {
  let product : dword = to_bits_truncate(signed(a) * signed(b));
  let rounded : dword = product + 0x00004000;

  // Take bits [30..15] which is equivalent to arithmetic right shift by 15
  rounded[30..15]
}

// PMULLW/PMULLD — Multiply Packed Signed Integers and Store Low Result
// No flags affected.
val mul_lo : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function mul_lo(a, b) = to_bits_truncate(signed(a) * signed(b))

// PMULHW — Multiply Packed Signed Integers and Store High Result (16-bit)
// PMULHUW — Multiply Packed Unsigned Integers and Store High Result (16-bit)
// No flags affected.
val mul_hi16s : (word, word) -> word
function mul_hi16s(a, b) = {
  let product : dword = to_bits_truncate(signed(a) * signed(b));
  product[31..16]
}

val mul_hi16u : (word, word) -> word
function mul_hi16u(a, b) = {
  let product : dword = to_bits_truncate(unsigned(a) * unsigned(b));
  product[31..16]
}

// PSHUFHW — Shuffle Packed High Words
// Low qword copied unchanged from src. High qword: 4 words selected
// from src's high qword by imm8. No flags affected.
val select_high_word : (xmmword, bits(2)) -> word
function select_high_word(v, sel) = {
  let idx : range(0, 3) = unsigned(sel);
  v[(idx * 16 + 79) .. (idx * 16 + 64)]
}

// PSHUFLW — Shuffle Packed Low Words
// High qword copied unchanged from src. Low qword: 4 words selected
// from src's low qword by imm8. No flags affected.
val select_low_word : (xmmword, bits(2)) -> word
function select_low_word(v, sel) = {
  let idx : range(0, 3) = unsigned(sel);
  v[(idx * 16 + 15) .. (idx * 16)]
}

// PSLLW/PSLLD/PSLLQ — Shift Packed Data Left Logical
// PSRLW/PSRLD/PSRLQ — Shift Packed Data Right Logical
// PSRAW/PSRAD — Shift Packed Data Right Arithmetic
// Shift count from imm8 or XMM. No flags affected.

// PSUBSB/PSUBSW — Subtract Packed Signed Integers with Signed Saturation
// PSUBUSB/PSUBUSW — Subtract Packed Unsigned Integers with Unsigned Saturation
// No flags affected.
// Branchless: detect overflow/underflow via sign bits of wide difference.
// =========================================================================
// PCLMULQDQ — Carry-Less Multiplication (SDM Vol.2B §4-242)
//
// Performs carry-less (XOR-based) polynomial multiplication of two 64-bit
// values, producing a 128-bit result. Equivalent to GF(2) multiplication.
// =========================================================================

val pclmulqdq : (bits(64), bits(64)) -> bits(128)
function pclmulqdq(x, y) = {
  var result : bits(128) = zeros();
  foreach (i from 0 to 63) {
    result = result ^ ((zero_extend(y) << i) & sign_extend(x[i]))
  };
  result
}

// =========================================================================
// MASKMOVDQU — Store Selected Bytes (SDM Vol.2B §4-1)
//
// For each byte position, if the high bit of the corresponding mask byte
// is set, write the source byte to memory at DS:RDI + offset.
// =========================================================================

val maskmovdqu : (xmmword, xmmword, qword) -> unit
function maskmovdqu(src, mask, addr) = {
  foreach (i from 0 to 15) {
    if mask[i * 8 + 7] == bitone then
      write_mem(addr + i, src[(i * 8 + 7) .. (i * 8)])
  }
}

// =========================================================================
// MPSADBW — Multiple Packed Sums of Absolute Difference (SDM Vol.2B §4-133)
//
// Computes 8 SAD values by sliding a 4-byte window from dst across a fixed
// 4-byte block from src. imm8[1:0]*32 selects src block offset,
// imm8[2]*32 selects dst starting offset.
// =========================================================================

val mpsadbw : (xmmword, xmmword, byte) -> xmmword
function mpsadbw(dst, src, imm8) = {
  let src_off : range(0, 96) = unsigned(imm8[1..0]) * 32;
  let dst_off : range(0, 32) = unsigned(imm8[2..2]) * 32;
  // Extract the fixed 4-byte block from src
  let s0 : byte = src[(src_off + 7) .. src_off];
  let s1 : byte = src[(src_off + 15) .. (src_off + 8)];
  let s2 : byte = src[(src_off + 23) .. (src_off + 16)];
  let s3 : byte = src[(src_off + 31) .. (src_off + 24)];
  var result : xmmword = zeros();
  foreach (j from 0 to 7) {
    let base : range(0, 88) = dst_off + j * 8;
    let d0 : byte = dst[(base + 7) .. base];
    let d1 : byte = dst[(base + 15) .. (base + 8)];
    let d2 : byte = dst[(base + 23) .. (base + 16)];
    let d3 : byte = dst[(base + 31) .. (base + 24)];
    let sad : int = abs_diff(d0, s0) + abs_diff(d1, s1) +
                    abs_diff(d2, s2) + abs_diff(d3, s3);
    let lo : range(0, 112) = j * 16;
    result[(lo + 15) .. lo] = to_bits_truncate(16, sad)
  };
  result
}

// =========================================================================
// PCMPxSTRx — SSE4.2 String/Text Processing (SDM Vol.2B §4.1)
//
// Common core for PCMPESTRI, PCMPESTRM, PCMPISTRI, PCMPISTRM.
// imm8 controls: [1:0] format, [3:2] aggregation, [5:4] polarity, [6] output.
// =========================================================================

// Compute effective valid lengths for implicit-length instructions.
// Returns index of first null element (or ub+1 if no null found).
// Builds a null-element bitmask, then finds first set bit via CTZ.
val pcmp_implicit_len : (xmmword, range(0, 15)) -> range(0, 16)
function pcmp_implicit_len(x, ub) = {
  // Build null mask: bit i = 1 iff element i is zero
  var null_mask : bits(16) = zeros();
  foreach (i from 0 to 15) {
    if i <= ub then {
      let lo = if ub == 7 then i * 16 else i * 8;
      let hi = if ub == 7 then lo + 15 else lo + 7;
      null_mask[i] = is_zero(x[hi .. lo])
    }
  };
  // Place sentinel at ub+1 so CTZ returns ub+1 when no nulls found.
  // For ub=15, the shift overflows bits(16) giving 0 — CTZ returns 16 naturally.
  // Sentinel at ub+1: CTZ returns ub+1 when no nulls found.
  // For ub=15, the shift overflows bits(16) giving 0 — CTZ returns 16 naturally.
  ctz(null_mask | (0x0001 << (ub + 1)))
}

// Core string comparison engine.
// la, lb = valid lengths of a, b respectively.
// Returns (IntRes2, CF, ZF, SF, OF).
val pcmpxstrx_core : (xmmword, range(0, 16), xmmword, range(0, 16), byte) -> (bits(16), bit, bit, bit, bit)
function pcmpxstrx_core(a, la, b, lb, imm8) = {
  let ub : range(0, 15) = if imm8[0] == bitone then 7 else 15;  // upper bound (word vs byte)

  // Stage 2: Compute BoolRes[j][i] — j indexes b, i indexes a
  // BoolRes[j][i] = 1 if element j of b equals element i of a
  var bool_res : bits(256) = zeros();  // 16×16 matrix flattened
  foreach (j from 0 to 15) {
    foreach (i from 0 to 15) {
      if i <= ub & j <= ub then {
        let elem_bits = if ub == 7 then 16 else 8;
        let a_lo = i * elem_bits;
        let b_lo = j * elem_bits;
        let eq : bit = if ub == 7
          then is_eq(a[(a_lo + 15) .. a_lo], b[(b_lo + 15) .. b_lo])
          else is_eq(a[(a_lo + 7) .. a_lo], b[(b_lo + 7) .. b_lo]);
        bool_res[j * 16 + i] = eq
      }
    }
  };

  // Stage 3: Aggregation
  // Also apply validity overrides per SDM Table 4-7
  var int_res1 : bits(16) = zeros();
  match imm8[3..2] {
    // Equal any: IntRes1[j] = OR over i of (BoolRes[j][i] AND both valid)
    0b00 => {
      let va : bits(16) = ~(0xFFFF << la);
      let vb : bits(16) = ~(0xFFFF << lb);
      foreach (j from 0 to 15) {
        if j <= ub then {
          var any_match : bit = bitzero;
          foreach (i from 0 to 15) {
            if i <= ub then {
              let valid : bit = va[i] & vb[j];
              any_match = any_match | (bool_res[j * 16 + i] & valid)
            }
          };
          int_res1[j] = any_match
        }
      }
    },
    // Ranges: IntRes1[j] = OR over pairs (i, i+1) of (a[i] <= b[j] <= a[i+1])
    0b01 => {
      let va : bits(16) = ~(0xFFFF << la);
      let vb : bits(16) = ~(0xFFFF << lb);
      foreach (j from 0 to 15) {
        if j <= ub then {
          var in_range : bit = bitzero;
          foreach (i_half from 0 to 7) {
            let i = i_half * 2;
            if i + 1 <= ub then {
              let elem_bits = if ub == 7 then 16 else 8;
              let a_lo_lo = i * elem_bits;
              let a_hi_lo = (i + 1) * elem_bits;
              let b_lo = j * elem_bits;
              // Compute comparisons unconditionally, gate with validity mask
              let ge_lo : bit = if ub == 7 then {
                let bw : word = b[(b_lo + 15) .. b_lo];
                let aw : word = a[(a_lo_lo + 15) .. a_lo_lo];
                blend(~(is_gt_u(aw, bw)), ~(is_gt(aw, bw)), imm8[1])
              } else {
                let bb : byte = b[(b_lo + 7) .. b_lo];
                let ab : byte = a[(a_lo_lo + 7) .. a_lo_lo];
                blend(~(is_gt_u(ab, bb)), ~(is_gt(ab, bb)), imm8[1])
              };
              let le_hi : bit = if ub == 7 then {
                let bw : word = b[(b_lo + 15) .. b_lo];
                let aw : word = a[(a_hi_lo + 15) .. a_hi_lo];
                blend(~(is_gt_u(bw, aw)), ~(is_gt(bw, aw)), imm8[1])
              } else {
                let bb : byte = b[(b_lo + 7) .. b_lo];
                let ab : byte = a[(a_hi_lo + 7) .. a_hi_lo];
                blend(~(is_gt_u(bb, ab)), ~(is_gt(bb, ab)), imm8[1])
              };
              let valid : bit = va[i] & va[i + 1] & vb[j];
              in_range = in_range | (ge_lo & le_hi & valid)
            }
          };
          int_res1[j] = in_range
        }
      }
    },
    // Equal each: IntRes1[i] = BoolRes[i][i] with validity overrides
    // both valid → use comparison, both invalid → 1, one invalid → 0
    0b10 => {
      let va : bits(16) = ~(0xFFFF << la);
      let vb : bits(16) = ~(0xFFFF << lb);
      foreach (i from 0 to 15) {
        if i <= ub then
          int_res1[i] = (bool_res[i * 16 + i] & va[i] & vb[i]) | (~(va[i]) & ~(vb[i]))
      }
    },
    // Equal ordered: substring search
    // a_valid & b_valid → AND with comparison
    // ~a_valid → needle exhausted, keep match (AND with 1)
    // a_valid & ~b_valid → haystack short, force false (AND with 0)
    0b11 => {
      let va : bits(16) = ~(0xFFFF << la);
      let vb : bits(16) = ~(0xFFFF << lb);
      foreach (j from 0 to 15) {
        if j <= ub then {
          var all_match : bit = bitone;
          foreach (k_off from 0 to 15) {
            let k = j + k_off;
            if k_off <= ub & k <= ub then
              all_match = all_match & (~(va[k_off]) | (bool_res[k * 16 + k_off] & vb[k]))
          };
          int_res1[j] = all_match
        }
      }
    },
  };

  // Zero out bits beyond ub
  if ub == 7 then int_res1 = int_res1 & 0x00FF;

  // Stage 4: Polarity
  let ub_mask : bits(16) = if ub == 7 then 0x00FF else 0xFFFF;
  let int_res2 : bits(16) = match imm8[5..4] {
    0b00 => int_res1,                     // positive
    0b01 => int_res1 ^ ub_mask,           // negative: flip all valid lanes
    0b10 => int_res1,                     // masked positive (same as positive)
    0b11 => {                             // masked negative: flip where i < lb
      let vb : bits(16) = ~(0xFFFF << lb);
      int_res1 ^ (vb & ub_mask)
    },
  };

  // Flags
  let cf : bit = is_nonzero(int_res2);
  let ub1 : bits(5) = to_bits(5, ub + 1);
  let zf : bit = is_gt_u(ub1, to_bits(5, lb));   // any invalid element in b
  let sf : bit = is_gt_u(ub1, to_bits(5, la));   // any invalid element in a
  let of : bit = int_res2[0];

  (int_res2, cf, zf, sf, of)
}

// Clamp explicit string length per SDM: abs(value), saturated to max_len.
val pcmp_clamp_len : (dword, range(0, 16)) -> range(0, 16)
function pcmp_clamp_len(raw, max_len) = {
  let clamped : dword = min_u(abs(raw), to_bits(32, max_len));
  let result = unsigned(clamped);
  assert(result <= 16);
  result
}

// Find index of first (LSB) or last (MSB) set bit in IntRes2, bounded by ub.
// Returns ub+1 if no bits set.
// Bits above ub are already zeroed by the caller.
val pcmp_bit_index : (bits(16), range(0, 15), bit) -> range(0, 16)
function pcmp_bit_index(int_res2, ub, msb_mode) = {
  let zf : bit = is_zero(int_res2);
  // MSB mode: BSR (highest set bit). Sentinel bit 0 ensures nonzero input.
  // LSB mode: CTZ (lowest set bit).
  let idx : range(0, 16) = if msb_mode == bitone then {
    let r = bsr(zero_extend(int_res2) | 0x0000000000000001); assert(r <= 15); r
  } else {
    ctz(int_res2)
  };
  // If no bits set or idx > ub (word mode CTZ=16): return ub+1
  let out_of_range : bit = zf | is_gt_u(to_bits(5, idx), to_bits(5, ub));
  let result = unsigned(blend(to_bits(5, idx), to_bits(5, ub + 1), out_of_range));
  assert(result <= 16);
  result
}

// Expand IntRes2 bits into byte/word mask or return as bit mask in XMM.
val pcmp_expand_mask : (bits(16), range(0, 15), bit) -> xmmword
function pcmp_expand_mask(int_res2, ub, expand_mode) = {
  if expand_mode == bitone then {
    var m : xmmword = zeros();
    foreach (i from 0 to 15) {
      if i <= ub then {
        if ub == 7 then
          m[(i * 16 + 15) .. (i * 16)] = sign_extend(int_res2[i])
        else
          m[(i * 8 + 7) .. (i * 8)] = sign_extend(int_res2[i])
      }
    };
    m
  } else {
    zero_extend(int_res2)
  }
}

// PCMPISTRI: implicit-length, return index in ECX
val pcmpistri : (xmmword, xmmword, byte) -> (dword, bit, bit, bit, bit)
function pcmpistri(a, b, imm8) = {
  let ub : range(0, 15) = if imm8[0] == bitone then 7 else 15;
  let la = pcmp_implicit_len(a, ub);
  let lb = pcmp_implicit_len(b, ub);
  let (int_res2, cf, zf, sf, of) = pcmpxstrx_core(a, la, b, lb, imm8);
  let idx = pcmp_bit_index(int_res2, ub, imm8[6]);
  (to_bits(32, idx), cf, zf, sf, of)
}

// PCMPISTRM: implicit-length, return mask in XMM0
val pcmpistrm : (xmmword, xmmword, byte) -> (xmmword, bit, bit, bit, bit)
function pcmpistrm(a, b, imm8) = {
  let ub : range(0, 15) = if imm8[0] == bitone then 7 else 15;
  let la = pcmp_implicit_len(a, ub);
  let lb = pcmp_implicit_len(b, ub);
  let (int_res2, cf, zf, sf, of) = pcmpxstrx_core(a, la, b, lb, imm8);
  (pcmp_expand_mask(int_res2, ub, imm8[6]), cf, zf, sf, of)
}

// PCMPESTRI: explicit-length, return index in ECX
val pcmpestri : (xmmword, dword, xmmword, dword, byte) -> (dword, bit, bit, bit, bit)
function pcmpestri(a, raw_la, b, raw_lb, imm8) = {
  let ub : range(0, 15) = if imm8[0] == bitone then 7 else 15;
  let la = pcmp_clamp_len(raw_la, ub + 1);
  let lb = pcmp_clamp_len(raw_lb, ub + 1);
  let (int_res2, cf, zf, sf, of) = pcmpxstrx_core(a, la, b, lb, imm8);
  let idx = pcmp_bit_index(int_res2, ub, imm8[6]);
  (to_bits(32, idx), cf, zf, sf, of)
}

// PCMPESTRM: explicit-length, return mask in XMM0
val pcmpestrm : (xmmword, dword, xmmword, dword, byte) -> (xmmword, bit, bit, bit, bit)
function pcmpestrm(a, raw_la, b, raw_lb, imm8) = {
  let ub : range(0, 15) = if imm8[0] == bitone then 7 else 15;
  let la = pcmp_clamp_len(raw_la, ub + 1);
  let lb = pcmp_clamp_len(raw_lb, ub + 1);
  let (int_res2, cf, zf, sf, of) = pcmpxstrx_core(a, la, b, lb, imm8);
  (pcmp_expand_mask(int_res2, ub, imm8[6]), cf, zf, sf, of)
}

val dispatch_2byte_sse_int : (range(0, 255), Prefixes) -> unit
function dispatch_2byte_sse_int(op, pfx) = {
  match op {
    // 0F 60-6B: PUNPCK*/PACKSSWB/PCMPGT*/PACKUSWB/PUNPCKH*/PACKSSDW
    op if 96 <= op & op <= 107 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch(1);
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let d : xmmword = read_simd(xreg);
        match (op - 96) {
          // PUNPCKLBW/WD/DQ
          0  => ZMM[xreg][127..0] = packed_unpack( 8, 0, d, src_xmm),
          1  => ZMM[xreg][127..0] = packed_unpack(16, 0, d, src_xmm),
          2  => ZMM[xreg][127..0] = packed_unpack(32, 0, d, src_xmm),
          // PACKSSWB
          3  => ZMM[xreg][127..0] = packed_pack(PN_SatS, 16, 8, d, src_xmm),
          // PCMPGTB/W/D
          4  => ZMM[xreg][127..0] = packed_binop(PB_CmpGt,  8, d, src_xmm),
          5  => ZMM[xreg][127..0] = packed_binop(PB_CmpGt, 16, d, src_xmm),
          6  => ZMM[xreg][127..0] = packed_binop(PB_CmpGt, 32, d, src_xmm),
          // PACKUSWB
          7  => ZMM[xreg][127..0] = packed_pack(PN_SatSU, 16, 8, d, src_xmm),
          // PUNPCKHBW/WD/DQ
          8  => ZMM[xreg][127..0] = packed_unpack( 8, 64, d, src_xmm),
          9  => ZMM[xreg][127..0] = packed_unpack(16, 64, d, src_xmm),
          10 => ZMM[xreg][127..0] = packed_unpack(32, 64, d, src_xmm),
          // PACKSSDW
          11 => ZMM[xreg][127..0] = packed_pack(PN_SatS, 32, 16, d, src_xmm),
          _  => raise_UD(),
        }
      }
    },

    // 0F 6C: PUNPCKLQDQ (SSE2 only, no MMX form)
    108 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
      ZMM[xreg][127..0] = packed_unpack(64, 0, read_simd(xreg), src_xmm)
    },

    // 0F 6D: PUNPCKHQDQ (SSE2 only, no MMX form)
    109 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then raise_UD();
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
      ZMM[xreg][127..0] = packed_unpack(64, 64, read_simd(xreg), src_xmm)
    },

    // 0F 6E: MOVD/MOVQ xmm, r/m32 (or r/m64 with REX.W)
    //        MOVD/MOVQ mm, r/m32 (or r/m64 with REX.W) when no prefix
    110 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch(1);
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        match (src, pfx.rex_w) {
          (RM_reg(r), true)  => ZMM[xreg][127..0] = zero_extend(v(64, r)),
          (RM_mem(m), true)  => ZMM[xreg][127..0] = zero_extend(read_mem(64, m)),
          (RM_reg(r), false) => ZMM[xreg][127..0] = zero_extend(v(32, r)),
          (RM_mem(m), false) => ZMM[xreg][127..0] = zero_extend(read_mem(32, m)),
        }
      }
    },

    // 0F 6F: MOVDQA/MOVDQU xmm, xmm/m128 / MOVQ mm, mm/m64 (no prefix)
    111 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch(1);
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        match src {
          RM_reg(_) => {
            match mp {
              MP_66 => ZMM[xreg][127..0] = read_simd(modrm_xmm_rm(modrm, pfx)),
              MP_F3 => ZMM[xreg][127..0] = read_simd(modrm_xmm_rm(modrm, pfx)),
              _     => raise_UD(),
            }
          },
          RM_mem(m) => ZMM[xreg][127..0] = read_mem(m),
        }
      }
    },

    // 0F 70: PSHUFD/PSHUFHW/PSHUFLW / PSHUFW (no prefix)
    112 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch(1);
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_simd(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let imm = fetch(1);
        match mp {
          // PSHUFD xmm1, xmm2/m128, imm8
          MP_66 => ZMM[xreg][127..0] = packed_lane_imm_op(PLI_Pshufd, src_xmm, imm),
          // PSHUFHW xmm1, xmm2/m128, imm8
          MP_F3 => ZMM[xreg][127..0] = packed_lane_imm_op(PLI_Pshufhw, src_xmm, imm),
          // PSHUFLW xmm1, xmm2/m128, imm8
          MP_F2 => ZMM[xreg][127..0] = packed_lane_imm_op(PLI_Pshuflw, src_xmm, imm),
          _     => raise_UD(),
        }
      }
    },

    // 0F 71: Group 12 — PSRLW/PSRAW/PSLLW imm8 (66 or no prefix)
    113 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        if mp != MP_66 then raise_UD();
        let modrm = fetch(1);
        let _ = modrm_rm(modrm, pfx);
        let xreg = modrm_xmm_rm(modrm, pfx);
        let c : nat = unsigned(fetch(1));
        match unsigned(modrm[5..3]) {
          2 => ZMM[xreg][127..0] = packed_uniform_shift(PS_Srl, 16, read_simd(xreg), c),
          4 => ZMM[xreg][127..0] = packed_uniform_shift(PS_Sra, 16, read_simd(xreg), c),
          6 => ZMM[xreg][127..0] = packed_uniform_shift(PS_Sll, 16, read_simd(xreg), c),
          _ => raise_UD(),
        }
      }
    },

    // 0F 72: Group 13 — PSRLD/PSRAD/PSLLD imm8 (66 or no prefix)
    114 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        if mp != MP_66 then raise_UD();
        let modrm = fetch(1);
        let _ = modrm_rm(modrm, pfx);
        let xreg = modrm_xmm_rm(modrm, pfx);
        let c : nat = unsigned(fetch(1));
        match unsigned(modrm[5..3]) {
          2 => ZMM[xreg][127..0] = packed_uniform_shift(PS_Srl, 32, read_simd(xreg), c),
          4 => ZMM[xreg][127..0] = packed_uniform_shift(PS_Sra, 32, read_simd(xreg), c),
          6 => ZMM[xreg][127..0] = packed_uniform_shift(PS_Sll, 32, read_simd(xreg), c),
          _ => raise_UD(),
        }
      }
    },

    // 0F 73: Group 14 — PSRLQ/PSRLDQ/PSLLQ/PSLLDQ imm8 (66 or no prefix)
    115 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        if mp != MP_66 then raise_UD();
        let modrm = fetch(1);
        let _ = modrm_rm(modrm, pfx);
        let xreg = modrm_xmm_rm(modrm, pfx);
        let c : nat = unsigned(fetch(1));
        match unsigned(modrm[5..3]) {
          // PSRLQ xmm1, imm8
          2 => ZMM[xreg][127..0] = packed_uniform_shift(PS_Srl, 64, read_simd(xreg), c),
          // PSRLDQ xmm1, imm8 — byte shift of whole 128-bit register
          3 => ZMM[xreg][127..0] = read_simd(128, xreg) >> (c * 8),
          // PSLLQ xmm1, imm8
          6 => ZMM[xreg][127..0] = packed_uniform_shift(PS_Sll, 64, read_simd(xreg), c),
          // PSLLDQ xmm1, imm8 — byte shift of whole 128-bit register
          7 => ZMM[xreg][127..0] = read_simd(128, xreg) << (c * 8),
          _ => raise_UD(),
        }
      }
    },

    // PCMPEQB xmm1, xmm2/m128
    116 => sse_exec_binop(op, PB_CmpEq,  8, pfx),
    // PCMPEQW xmm1, xmm2/m128
    117 => sse_exec_binop(op, PB_CmpEq, 16, pfx),
    // PCMPEQD xmm1, xmm2/m128
    118 => sse_exec_binop(op, PB_CmpEq, 32, pfx),

    // 0F 7E: MOVD/MOVQ r/m32, xmm (66) / MOVQ xmm,xmm/m64 (F3) / MOVD r/m32, mm (NP)
    126 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch(1);
        let src = modrm_rm(modrm, pfx);
        match mp {
          // MOVD/MOVQ r/m, xmm
          MP_66 => {
            let src_xmm = modrm_xmm_reg(modrm, pfx);
            let x : xmmword = read_simd(src_xmm);
            match (src, pfx.rex_w) {
              (RM_reg(r), true)  => v(r) = x[63..0],
              (RM_mem(m), true)  => write_mem(64, m, x[63..0]),
              (RM_reg(r), false) => v(r) = x[31..0],
              (RM_mem(m), false) => write_mem(32, m, x[31..0]),
            }
          },
          // MOVQ xmm1, xmm2/m64
          MP_F3 => {
            let xreg = modrm_xmm_reg(modrm, pfx);
            match src {
              RM_reg(_) => {
                let src : xmmword = read_simd(modrm_xmm_rm(modrm, pfx));
                ZMM[xreg][127..0] = zero_extend(src[63..0])
              },
              RM_mem(m) => {
                let x : xmmword = zero_extend(read_mem(64, m));
                write_simd(128, xreg, x)
              },
            }
          },
          _ => raise_UD(),
        }
      }
    },

    // 0F 7F: MOVDQA/MOVDQU xmm/m128, xmm / MOVQ mm/m64, mm (NP)
    127 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch(1);
        let xreg = modrm_xmm_reg(modrm, pfx);
        let dest = modrm_rm(modrm, pfx);
        match dest {
          RM_reg(_) => {
            let dst_xmm = modrm_xmm_rm(modrm, pfx);
            match mp {
              MP_66 => ZMM[dst_xmm][127..0] = read_simd(xreg),
              MP_F3 => ZMM[dst_xmm][127..0] = read_simd(xreg),
              _     => raise_UD(),
            }
          },
          RM_mem(m) => {
            write_mem(m, read_simd(128, xreg))
          },
        }
      }
    },

    // 0F D7: PMOVMSKB r, xmm (66 prefix)
    215 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch(1);
        let reg = modrm_reg(modrm, pfx);
        let _ = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = read_simd(modrm_xmm_rm(modrm, pfx));
        let mask : word = src_xmm[127] @ src_xmm[119] @ src_xmm[111] @ src_xmm[103] @
                               src_xmm[95]  @ src_xmm[87]  @ src_xmm[79]  @ src_xmm[71] @
                               src_xmm[63]  @ src_xmm[55]  @ src_xmm[47]  @ src_xmm[39] @
                               src_xmm[31]  @ src_xmm[23]  @ src_xmm[15]  @ src_xmm[7];
        v(reg) = zero_extend(32, mask)
      }
    },

    // 0F DB: PAND xmm, xmm/m128 (66 prefix)
    219 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch(1);
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_simd(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let a : xmmword = read_simd(xreg);
        let b : xmmword = src_xmm;
        ZMM[xreg][127..0] = a & b
      }
    },

    // 0F DF: PANDN xmm, xmm/m128 (66 prefix)
    223 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch(1);
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_simd(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        ZMM[xreg][127..0] = ~(read_simd(xreg)) & src_xmm
      }
    },

    // 0F E5: PMULHW xmm, xmm/m128 (66 prefix)
    229 => sse_exec_binop(op, PB_MulHighS, 16, pfx),

    // 0F EB: POR xmm, xmm/m128 (66 prefix)
    235 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch(1);
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_simd(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        ZMM[xreg][127..0] = read_simd(xreg) | src_xmm
      }
    },

    // 0F EF: PXOR xmm, xmm/m128 (66 prefix)
    239 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch(1);
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_simd(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let a : xmmword = read_simd(xreg);
        let b : xmmword = src_xmm;
        ZMM[xreg][127..0] = a ^ b
      }
    },

    // 0F D4: PADDQ (66 prefix)
    212 => sse_exec_binop(op, PB_Add, 64, pfx),

    // 0F F4: PMULUDQ (66 prefix)
    244 => sse_exec_binop(op, PB_Pmuludq, 64, pfx),

    // 0F F8-FB: PSUBB/W/D/Q (66 prefix)
    248 => sse_exec_binop(op, PB_Sub,  8, pfx),
    249 => sse_exec_binop(op, PB_Sub, 16, pfx),
    250 => sse_exec_binop(op, PB_Sub, 32, pfx),
    251 => sse_exec_binop(op, PB_Sub, 64, pfx),
    // 0F FC-FE: PADDB/W/D (66 prefix)
    252 => sse_exec_binop(op, PB_Add,  8, pfx),
    253 => sse_exec_binop(op, PB_Add, 16, pfx),
    254 => sse_exec_binop(op, PB_Add, 32, pfx),

    // 0F E0: PAVGB (66 prefix)
    224 => sse_exec_binop(op, PB_Avg, 8, pfx),
    // 0F DA: PMINUB (66 prefix)
    218 => sse_exec_binop(op, PB_MinU, 8, pfx),
    // 0F DE: PMAXUB (66 prefix)
    222 => sse_exec_binop(op, PB_MaxU, 8, pfx),
    // 0F F6: PSADBW (66 prefix)
    246 => sse_exec_binop(op, PB_Psadbw, 64, pfx),

    // 0F E7: MOVNTDQ m128, xmm (66 prefix) / MOVNTQ m64, mm (no prefix)
    231 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        if mp != MP_66 then raise_UD();
        let modrm = fetch(1);
        let xreg = modrm_xmm_reg(modrm, pfx);
        let dest = modrm_rm(modrm, pfx);
        rm_mem(dest) = read_simd(128, xreg)
      }
    },

    // 0F C4: PINSRW xmm, r32/m16, imm8 (66 prefix)
    196 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch(1);
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let x : word = v(src);
        let imm = fetch(1);
        let sel : nat = unsigned(imm[2..0]);
        let mask : xmmword = ~(zero_extend(0xFFFF) << (sel * 16));
        ZMM[xreg][127..0] = (read_simd(xreg) & mask) | (zero_extend(x) << (sel * 16))
      }
    },

    // 0F C5: PEXTRW r32, xmm, imm8 (66 prefix)
    197 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch(1);
        let reg = modrm_reg(modrm, pfx);
        let _ = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = read_simd(modrm_xmm_rm(modrm, pfx));
        let imm = fetch(1);
        let sel : nat = unsigned(imm[2..0]);
        v(reg) = zero_extend(32, (src_xmm >> (sel * 16))[15..0])
      }
    },

    // 0F D1-D3: PSRLW/D/Q xmm, xmm/m128 (66 prefix)
    209 => sse_exec_shift(op, PS_Srl, 16, pfx),
    210 => sse_exec_shift(op, PS_Srl, 32, pfx),
    211 => sse_exec_shift(op, PS_Srl, 64, pfx),

    // 0F D5: PMULLW (66 prefix)
    213 => sse_exec_binop(op, PB_MulLow, 16, pfx),

    // 0F D6: MOVQ xmm1/m64, xmm2 (66 prefix)
    214 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch(1);
        let src_xmm = modrm_xmm_reg(modrm, pfx);
        let dest = modrm_rm(modrm, pfx);
        let x : qword = read_simd(128, src_xmm)[63..0];
        match dest {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            ZMM[dst][127..0] = zero_extend(x)
          },
          RM_mem(m) => write_mem(m,x),
        }
      }
    },

    // 0F D8-D9: PSUBUSB/W (66 prefix)
    216 => sse_exec_binop(op, PB_SatSubU,  8, pfx),
    217 => sse_exec_binop(op, PB_SatSubU, 16, pfx),
    // 0F DC-DD: PADDUSB/W (66 prefix)
    220 => sse_exec_binop(op, PB_SatAddU,  8, pfx),
    221 => sse_exec_binop(op, PB_SatAddU, 16, pfx),

    // 0F E1-E2: PSRAW/D xmm, xmm/m128 (66 prefix)
    225 => sse_exec_shift(op, PS_Sra, 16, pfx),
    226 => sse_exec_shift(op, PS_Sra, 32, pfx),
    // 0F E3: PAVGW (66 prefix)
    227 => sse_exec_binop(op, PB_Avg, 16, pfx),
    // 0F E4: PMULHUW (66 prefix)
    228 => sse_exec_binop(op, PB_MulHighU, 16, pfx),

    // 0F E8-E9: PSUBSB/W (66 prefix)
    232 => sse_exec_binop(op, PB_SatSubS,  8, pfx),
    233 => sse_exec_binop(op, PB_SatSubS, 16, pfx),
    // 0F EC-ED: PADDSB/W (66 prefix)
    236 => sse_exec_binop(op, PB_SatAddS,  8, pfx),
    237 => sse_exec_binop(op, PB_SatAddS, 16, pfx),

    // 0F F0: LDDQU xmm, m128 (F2 prefix, SSE3)
    240 => {
      if ~(has_sse3) then raise_UD();
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_F2 then raise_UD();
      let modrm = fetch(1);
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      write_simd(128, xreg, rm_mem(src))
    },

    // 0F F1-F3: PSLLW/D/Q xmm, xmm/m128 (66 prefix)
    241 => sse_exec_shift(op, PS_Sll, 16, pfx),
    242 => sse_exec_shift(op, PS_Sll, 32, pfx),
    243 => sse_exec_shift(op, PS_Sll, 64, pfx),
    // 0F F5: PMADDWD (66 prefix)
    245 => sse_exec_binop(op, PB_Pmaddwd, 32, pfx),

    // 0F F7: MASKMOVDQU xmm, xmm (66 prefix)
    247 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch(1);
        let xreg = modrm_xmm_reg(modrm, pfx);
        let _ = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = read_simd(modrm_xmm_rm(modrm, pfx));
        let addr = v(64, RDI);
        maskmovdqu(read_simd(xreg), src_xmm, addr)
      }
    },

    // 0F EE: PMAXSW (66 prefix)
    238 => sse_exec_binop(op, PB_MaxS, 16, pfx),
    // 0F EA: PMINSW (66 prefix)
    234 => sse_exec_binop(op, PB_MinS, 16, pfx),
    _ => raise_UD(),
  }
}

// =========================================================================
// 3-Byte Opcode Map: SSE Integer Operations
// =========================================================================

// 0F 38 xx — SSE integer operations (SSSE3, SSE4.1, SSE4.2, AES-NI)
val dispatch_3byte_38_sse_int : (byte, Prefixes) -> unit
function dispatch_3byte_38_sse_int(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);
  if mp != MP_66 then raise_UD();
  let modrm = fetch(1);
  let xreg = modrm_xmm_reg(modrm, pfx);
  let src = modrm_rm(modrm, pfx);
  let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
  match op {

    // SSSE3 — PSHUFB
    0  => ZMM[xreg][127..0] = pshufb(read_simd(xreg), src_xmm),
    // PHADDW xmm1, xmm2/m128
    1  => ZMM[xreg][127..0] = packed_binop(PB_HorizAddW, 128, read_simd(xreg), src_xmm),
    // PHADDD xmm1, xmm2/m128
    2  => ZMM[xreg][127..0] = packed_binop(PB_HorizAddD, 128, read_simd(xreg), src_xmm),
    // PHADDSW xmm1, xmm2/m128
    3  => ZMM[xreg][127..0] = packed_binop(PB_HorizSatAddW, 128, read_simd(xreg), src_xmm),
    // PMADDUBSW xmm1, xmm2/m128
    4  => ZMM[xreg][127..0] = packed_binop(PB_Pmaddubsw, 16, read_simd(xreg), src_xmm),
    // PHSUBW xmm1, xmm2/m128
    5  => ZMM[xreg][127..0] = packed_binop(PB_HorizSubW, 128, read_simd(xreg), src_xmm),
    // PHSUBD xmm1, xmm2/m128
    6  => ZMM[xreg][127..0] = packed_binop(PB_HorizSubD, 128, read_simd(xreg), src_xmm),
    // PHSUBSW xmm1, xmm2/m128
    7  => ZMM[xreg][127..0] = packed_binop(PB_HorizSatSubW, 128, read_simd(xreg), src_xmm),
    // PSIGNB/W/D xmm1, xmm2/m128
    8  => ZMM[xreg][127..0] = packed_binop(PB_PSign,  8, read_simd(xreg), src_xmm),
    9  => ZMM[xreg][127..0] = packed_binop(PB_PSign, 16, read_simd(xreg), src_xmm),
    10 => ZMM[xreg][127..0] = packed_binop(PB_PSign, 32, read_simd(xreg), src_xmm),
    // PMULHRSW xmm1, xmm2/m128
    11 => ZMM[xreg][127..0] = packed_binop(PB_MulHRS, 16, read_simd(xreg), src_xmm),

    // SSE4.1 — PBLENDVB (implicit XMM0 mask)
    16 => {
      let a : xmmword = read_simd(xreg);
      let m : xmmword = read_simd(0);
      // For each byte, select src_xmm if high bit of mask byte is set, else keep a
      var r : xmmword = zeros();
      foreach (i from 0 to 15) {
        let lo = i * 8;
        r[(lo + 7)..lo] = blend(a[(lo + 7)..lo], src_xmm[(lo + 7)..lo], m[lo + 7])
      };
      ZMM[xreg][127..0] = r
    },

    // SSE4.1 — PTEST
    23 => {
      let a : xmmword = read_simd(xreg);
      let b : xmmword = src_xmm;
      let temp1 : xmmword = a & b;
      let temp2 : xmmword = (~(a)) & b;
      ZF = is_zero(temp1[127..64] | temp1[63..0]);
      CF = is_zero(temp2[127..64] | temp2[63..0]);
      OF = 0b0;
      AF = 0b0;
      PF = 0b0;
      SF = 0b0
    },

    // SSSE3 — PABSB/W/D
    28 => ZMM[xreg][127..0] = packed_unop(PU_Abs,  8, src_xmm),
    29 => ZMM[xreg][127..0] = packed_unop(PU_Abs, 16, src_xmm),
    30 => ZMM[xreg][127..0] = packed_unop(PU_Abs, 32, src_xmm),

    // SSE4.1 — PMOVSXBW/BD/BQ/WD/WQ/DQ
    32 => ZMM[xreg][127..0] = packed_widen_unop(PW_SignExtend,  8, 16, src_xmm[63..0]),
    33 => ZMM[xreg][127..0] = packed_widen_unop(PW_SignExtend,  8, 32, src_xmm[31..0]),
    34 => ZMM[xreg][127..0] = packed_widen_unop(PW_SignExtend,  8, 64, src_xmm[15..0]),
    35 => ZMM[xreg][127..0] = packed_widen_unop(PW_SignExtend, 16, 32, src_xmm[63..0]),
    36 => ZMM[xreg][127..0] = packed_widen_unop(PW_SignExtend, 16, 64, src_xmm[31..0]),
    37 => ZMM[xreg][127..0] = packed_widen_unop(PW_SignExtend, 32, 64, src_xmm[63..0]),

    // SSE4.1 — PMULDQ (signed 32×32→64, uses dword elements 0 and 2)
    40 => {
      // PMULDQ uses signed dwords, unlike PMULUDQ which uses unsigned.
      // PB_Pmuludq does unsigned — we need a separate approach.
      let a : xmmword = read_simd(xreg);
      let b : xmmword = src_xmm;
      let hi : qword = to_bits_truncate(signed(a[95..64]) * signed(b[95..64]));
      let lo : qword = to_bits_truncate(signed(a[31..0]) * signed(b[31..0]));
      ZMM[xreg][127..0] = hi @ lo
    },
    // PCMPEQQ xmm1, xmm2/m128
    41 => ZMM[xreg][127..0] = packed_binop(PB_CmpEq, 64, read_simd(xreg), src_xmm),
    // MOVNTDQA xmm, m128
    42 => {
      ZMM[xreg][127..0] = rm_mem(src)
    },
    // PACKUSDW xmm1, xmm2/m128
    43 => ZMM[xreg][127..0] = packed_pack(PN_SatSU, 32, 16, read_simd(xreg), src_xmm),

    // SSE4.1 — PMOVZXBW/BD/BQ/WD/WQ/DQ
    48 => ZMM[xreg][127..0] = packed_widen_unop(PW_ZeroExtend,  8, 16, src_xmm[63..0]),
    49 => ZMM[xreg][127..0] = packed_widen_unop(PW_ZeroExtend,  8, 32, src_xmm[31..0]),
    50 => ZMM[xreg][127..0] = packed_widen_unop(PW_ZeroExtend,  8, 64, src_xmm[15..0]),
    51 => ZMM[xreg][127..0] = packed_widen_unop(PW_ZeroExtend, 16, 32, src_xmm[63..0]),
    52 => ZMM[xreg][127..0] = packed_widen_unop(PW_ZeroExtend, 16, 64, src_xmm[31..0]),
    53 => ZMM[xreg][127..0] = packed_widen_unop(PW_ZeroExtend, 32, 64, src_xmm[63..0]),

    // SSE4.2 — PCMPGTQ
    55 => ZMM[xreg][127..0] = packed_binop(PB_CmpGt, 64, read_simd(xreg), src_xmm),
    // SSE4.1 — PMINSB/SD, PMINUW/UD
    56 => ZMM[xreg][127..0] = packed_binop(PB_MinS,  8, read_simd(xreg), src_xmm),
    57 => ZMM[xreg][127..0] = packed_binop(PB_MinS, 32, read_simd(xreg), src_xmm),
    58 => ZMM[xreg][127..0] = packed_binop(PB_MinU, 16, read_simd(xreg), src_xmm),
    59 => ZMM[xreg][127..0] = packed_binop(PB_MinU, 32, read_simd(xreg), src_xmm),
    // SSE4.1 — PMAXSB/SD, PMAXUW/UD
    60 => ZMM[xreg][127..0] = packed_binop(PB_MaxS,  8, read_simd(xreg), src_xmm),
    61 => ZMM[xreg][127..0] = packed_binop(PB_MaxS, 32, read_simd(xreg), src_xmm),
    62 => ZMM[xreg][127..0] = packed_binop(PB_MaxU, 16, read_simd(xreg), src_xmm),
    63 => ZMM[xreg][127..0] = packed_binop(PB_MaxU, 32, read_simd(xreg), src_xmm),
    // SSE4.1 — PMULLD
    64 => ZMM[xreg][127..0] = packed_binop(PB_MulLow, 32, read_simd(xreg), src_xmm),
    // PHMINPOSUW xmm1, xmm2/m128
    65 => {
      let s : xmmword = src_xmm;
      let w0 : word = s[15..0];
      let w1 : word = s[31..16];
      let w2 : word = s[47..32];
      let w3 : word = s[63..48];
      let w4 : word = s[79..64];
      let w5 : word = s[95..80];
      let w6 : word = s[111..96];
      let w7 : word = s[127..112];

      // Find minimum value and index (lowest index wins on tie) — branchless
      var mv : word = w0;
      var mi : word = 0x0000;

      let d1 : bits(17) = (0b0 @ w1) - (0b0 @ mv);
      let u1 : word = sign_extend(d1[16]);
      mv = (w1 & u1) | (mv & ~(u1));
      mi = (0x0001 & u1) | (mi & ~(u1));

      let d2 : bits(17) = (0b0 @ w2) - (0b0 @ mv);
      let u2 : word = sign_extend(d2[16]);
      mv = (w2 & u2) | (mv & ~(u2));
      mi = (0x0002 & u2) | (mi & ~(u2));

      let d3 : bits(17) = (0b0 @ w3) - (0b0 @ mv);
      let u3 : word = sign_extend(d3[16]);
      mv = (w3 & u3) | (mv & ~(u3));
      mi = (0x0003 & u3) | (mi & ~(u3));

      let d4 : bits(17) = (0b0 @ w4) - (0b0 @ mv);
      let u4 : word = sign_extend(d4[16]);
      mv = (w4 & u4) | (mv & ~(u4));
      mi = (0x0004 & u4) | (mi & ~(u4));

      let d5 : bits(17) = (0b0 @ w5) - (0b0 @ mv);
      let u5 : word = sign_extend(d5[16]);
      mv = (w5 & u5) | (mv & ~(u5));
      mi = (0x0005 & u5) | (mi & ~(u5));

      let d6 : bits(17) = (0b0 @ w6) - (0b0 @ mv);
      let u6 : word = sign_extend(d6[16]);
      mv = (w6 & u6) | (mv & ~(u6));
      mi = (0x0006 & u6) | (mi & ~(u6));

      let d7 : bits(17) = (0b0 @ w7) - (0b0 @ mv);
      let u7 : word = sign_extend(d7[16]);
      mv = (w7 & u7) | (mv & ~(u7));
      mi = (0x0007 & u7) | (mi & ~(u7));

      ZMM[xreg][127..0] = zeros(96) @ mi @ mv
    },

    // AES-NI — AESIMC
    219 => {
      if ~(has_aesni) then raise_UD();
      let s : xmmword = src_xmm;
      ZMM[xreg][127..0] = __aesimc(s)
    },
    // AES-NI — AESENC
    220 => {
      if ~(has_aesni) then raise_UD();
      let state : xmmword = read_simd(xreg);
      let roundkey : xmmword = src_xmm;
      ZMM[xreg][127..0] = __aesenc(state, roundkey)
    },
    // AES-NI — AESENCLAST (0F 38 DD)
    221 => {
      if ~(has_aesni) then raise_UD();
      let state : xmmword = read_simd(xreg);
      let roundkey : xmmword = src_xmm;
      ZMM[xreg][127..0] = __aesenclast(state, roundkey)
    },
    // AES-NI — AESDEC (0F 38 DE)
    222 => {
      if ~(has_aesni) then raise_UD();
      let state : xmmword = read_simd(xreg);
      let roundkey : xmmword = src_xmm;
      ZMM[xreg][127..0] = __aesdec(state, roundkey)
    },
    // AES-NI — AESDECLAST
    223 => {
      if ~(has_aesni) then raise_UD();
      let state : xmmword = read_simd(xreg);
      let roundkey : xmmword = src_xmm;
      ZMM[xreg][127..0] = __aesdeclast(state, roundkey)
    },

    // GFNI — GF2P8MULB (66 0F 38 CF)
    207 => {
      ZMM[xreg][127..0] = avx_gf2p8mulb(read_simd(xreg), src_xmm)
    },

    _ => raise_UD(),
  }
}

// 0F 3A xx — SSE integer operations (PBLENDW, PALIGNR, PEXTR*, PINSR*,
//            MPSADBW, PCLMULQDQ, PCMPxSTRx, AESKEYGENASSIST)
val dispatch_3byte_3a_sse_int : (byte, Prefixes) -> unit
function dispatch_3byte_3a_sse_int(opcode, pfx) = {
  let op : range(0, 255) = unsigned(opcode);
  let mp = get_mandatory_prefix(pfx);
  if mp != MP_66 then raise_UD();
  let modrm = fetch(1);
  let xreg = modrm_xmm_reg(modrm, pfx);
  let src = modrm_rm(modrm, pfx);
  match op {

    // SSE4.1 — PBLENDW
    14 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      let a : xmmword = read_simd(xreg);
      var r : xmmword = zeros();
      foreach (i from 0 to 7) {
        let lo = i * 16;
        r[(lo + 15)..lo] = blend(a[(lo + 15)..lo], src_xmm[(lo + 15)..lo], imm[i])
      };
      ZMM[xreg][127..0] = r
    },

    // SSSE3 — PALIGNR
    15 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      let d : xmmword = read_simd(xreg);
      let s : xmmword = src_xmm;
      let concat : ymmword = d @ s;
      let shift_bytes : range(0, 255) = unsigned(imm);
      let r : xmmword = (concat >> (shift_bytes * 8))[127..0];
      ZMM[xreg][127..0] = r
    },

    // SSE4.1 — PEXTRB r/m8, xmm, imm8
    20 => {
      let imm = fetch(1);
      let x = (ZMM[xreg] >> (unsigned(imm[3..0]) * 8))[7..0];
      match src {
        RM_reg(_) => {
          let dst_reg = modrm_rm_reg(modrm, pfx);
          v(dst_reg) = zero_extend(32, x);
        },
        RM_mem(m) => write_mem(m, x),
      }
    },

    // SSE4.1 — PEXTRD/PEXTRQ r/m, xmm, imm8
    22 => {
      let imm = fetch(1);
      let xmm_src : xmmword = read_simd(xreg);
      match (src, pfx.rex_w) {
        (RM_reg(r), true) => v(r) = (xmm_src >> (unsigned(imm[0]) * 64))[63..0],
        (RM_reg(r), false) => v(r) = (xmm_src >> (unsigned(imm[1..0]) * 32))[31..0],
        (RM_mem(m), true)  => v(m) = (xmm_src >> (unsigned(imm[0]) * 64))[63..0],
        (RM_mem(m), false) => v(m) = (xmm_src >> (unsigned(imm[1..0]) * 32))[31..0],
      }
    },

    // SSE4.1 — PINSRB xmm, r/m8, imm8
    32 => {
      let imm = fetch(1);
      let x : byte = match src {
        RM_reg(r) => v(r),
        RM_mem(m) => read_mem(m),
      };
      let v_0 : xmmword = read_simd(xreg);
      let sel : range(0, 15) = unsigned(imm[3..0]);
      let r : xmmword = insert_byte(v_0, x, sel);
      ZMM[xreg][127..0] = r
    },

    // SSE4.1 — PINSRD/PINSRQ xmm, r/m, imm8
    34 => {
      let imm = fetch(1);
      if pfx.rex_w then {
        let x : qword = v(src);
        let v_0 : xmmword = read_simd(xreg);
        let sel : range(0, 1) = unsigned(imm[0]);
        let r : xmmword = match sel {
          0 => v_0[127..64] @ x,
          1 => x @ v_0[63..0]
        };
        ZMM[xreg][127..0] = r
      } else {
        let x : dword = v(src);
        let v_0 : xmmword = read_simd(xreg);
        let sel : range(0, 3) = unsigned(imm[1..0]);
        let r : xmmword = insert_dword(v_0, x, sel);
        ZMM[xreg][127..0] = r
      }
    },

    // SSE4.1 — MPSADBW
    66 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      let a : xmmword = read_simd(xreg);
      let b : xmmword = src_xmm;
      ZMM[xreg][127..0] = mpsadbw(a, b, imm)
    },

    // PCLMULQDQ xmm1, xmm2/m128, imm8
    68 => {
      if ~(has_pclmulqdq) then raise_UD();
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      let a : xmmword = read_simd(xreg);
      let b : xmmword = src_xmm;
      let sel_a : qword = blend(a[63..0], a[127..64], imm[0]);
      let sel_b : qword = blend(b[63..0], b[127..64], imm[4]);
      ZMM[xreg][127..0] = pclmulqdq(sel_a, sel_b)
    },

    // SSE4.2 — PCMPESTRM
    96 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      let a : xmmword = read_simd(xreg);
      let b : xmmword = src_xmm;
      let la : dword = v(RAX);
      let lb : dword = v(RDX);
      let (mask, cf_val, zf_val, sf_val, of_val) = pcmpestrm(a, la, b, lb, imm);
      ZMM[0][127..0] = mask;
      CF = cf_val;
      ZF = zf_val;
      SF = sf_val;
      OF = of_val;
      AF = 0b0;
      PF = 0b0
    },
    // SSE4.2 — PCMPESTRI
    97 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      let a : xmmword = read_simd(xreg);
      let b : xmmword = src_xmm;
      let la : dword = v(RAX);
      let lb : dword = v(RDX);
      let (idx, cf_val, zf_val, sf_val, of_val) = pcmpestri(a, la, b, lb, imm);
      v(RCX) = idx;
      CF = cf_val;
      ZF = zf_val;
      SF = sf_val;
      OF = of_val;
      AF = 0b0;
      PF = 0b0
    },
    // SSE4.2 — PCMPISTRM
    98 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      let a : xmmword = read_simd(xreg);
      let b : xmmword = src_xmm;
      let (mask, cf_val, zf_val, sf_val, of_val) = pcmpistrm(a, b, imm);
      ZMM[0][127..0] = mask;
      CF = cf_val;
      ZF = zf_val;
      SF = sf_val;
      OF = of_val;
      AF = 0b0;
      PF = 0b0
    },
    // SSE4.2 — PCMPISTRI
    99 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      let a : xmmword = read_simd(xreg);
      let b : xmmword = src_xmm;
      let (idx, cf_val, zf_val, sf_val, of_val) = pcmpistri(a, b, imm);
      v(RCX) = idx;
      CF = cf_val;
      ZF = zf_val;
      SF = sf_val;
      OF = of_val;
      AF = 0b0;
      PF = 0b0
    },

    // AES-NI — AESKEYGENASSIST
    223 => {
      if ~(has_aesni) then raise_UD();
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      let s : xmmword = src_xmm;
      ZMM[xreg][127..0] = __aeskeygenassist(s, imm)
    },

    // GFNI — GF2P8AFFINEQB (66 0F 3A CE)
    206 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      ZMM[xreg][127..0] = avx_gf2p8affineqb(read_simd(xreg), src_xmm, imm)
    },

    // GFNI — GF2P8AFFINEINVQB (66 0F 3A CF)
    207 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch(1);
      ZMM[xreg][127..0] = avx_gf2p8affineinvqb(read_simd(xreg), src_xmm, imm)
    },

    _ => raise_UD(),
  }
}

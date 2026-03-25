// x86-64 — SSE Integer Operations
//
// SSE/SSE2/SSSE3/SSE4.1/SSE4.2 packed integer arithmetic, logical,
// shift, pack/unpack, compare, AES-NI, and PCLMULQDQ.

// Forward declaration — defined in insn_mmx.sail (compiled after this file)
val dispatch_mmx : (range(0, 255), Prefixes) -> unit

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

// PMADDUBSW — Multiply and Add Packed Signed and Unsigned Bytes (SSSE3)
// Multiplies unsigned bytes from src1 with signed bytes from src2,
// then adds adjacent pairs with signed saturation to produce 16-bit results.
// No flags affected.
val pmaddubsw_pair : (byte, byte, byte, byte) -> word
function pmaddubsw_pair(a_even, b_even, a_odd, b_odd) = {
  let p1 : int = unsigned(a_even) * signed(b_even);
  let p2 : int = unsigned(a_odd) * signed(b_odd);
  let sum : int = p1 + p2;
  // Branchless signed saturation to 16-bit via 17-bit overflow detection
  let wide : bits(17) = get_slice_int(17, sum, 0);
  let sign : bits(1) = wide[16];
  let of_mask : word = sign_extend(sign ^ wide[15]);
  let sat : word = sign_extend(sign) ^ 0x7FFF;
  (sat & of_mask) | (wide[15..0] & ~(of_mask))
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

// PSADBW — Compute Sum of Absolute Differences
// Computes absolute differences of unsigned byte pairs, then sums each 8-byte group.
// Result is zero-extended to 64 bits per qword lane. No flags affected.
val abs_diff8 : (byte, byte) -> int
function abs_diff8(a, b) = {
  let d1 : bits(9) = (0b0 @ a) - (0b0 @ b);
  let d2 : bits(9) = (0b0 @ b) - (0b0 @ a);
  let m1 : byte = sign_extend(~(d1[8]));
  let m2 : byte = sign_extend(~(d2[8]));
  unsigned((d1[7..0] & m1) | (d2[7..0] & m2))
}

// PSHUFB — Packed Shuffle Bytes (SSSE3)
// Each byte in result is selected from dst by the low 4 bits of the corresponding
// byte in src. If the high bit of the selector byte is set, the result byte is zero.
// No flags affected.
// Branchless: shift right by idx*8, take low byte, AND with zero-mask.
val pshufb_byte : (xmmword, byte) -> byte
function pshufb_byte(data, mask) = {
  let idx : range(0, 15) = unsigned(mask[3..0]);
  let selected : byte = (data >> (idx * 8))[7..0];
  selected & sign_extend(~(mask[7]))
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

// PSIGNB/PSIGNW/PSIGND — Packed Sign (SSSE3)
// Per lane: if b < 0, result = -a; if b == 0, result = 0; if b > 0, result = a.
val psign : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function psign(a, b) = {
  let neg_mask : bits('n) = sign_extend(b['n - 1]);
  ((a ^ neg_mask) - neg_mask) & sign_extend(is_nonzero(b))
}

// PSLLW/PSLLD/PSLLQ — Shift Packed Data Left Logical
// PSRLW/PSRLD/PSRLQ — Shift Packed Data Right Logical
// PSRAW/PSRAD — Shift Packed Data Right Arithmetic
// Shift count from imm8 or XMM. No flags affected.

// PSUBSB/PSUBSW — Subtract Packed Signed Integers with Signed Saturation
// PSUBUSB/PSUBUSW — Subtract Packed Unsigned Integers with Unsigned Saturation
// No flags affected.
// Branchless: detect overflow/underflow via sign bits of wide difference.
val sat_sub_s : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function sat_sub_s(a, b) = {
  let wide : bits('n + 1) = sign_extend(a) - sign_extend(b);
  let result : bits('n) = wide[('n - 1) .. 0];
  let overflow : bit = wide['n] ^ result['n - 1];
  let msb_only : bits('n) = zero_extend(0b1) << ('n - 1);
  let clamp : bits('n) = msb_only ^ sign_extend(~(wide['n]));
  blend(result, clamp, overflow)
}

// Branchless: borrow bit of wide difference → mask to zero.
val sat_sub_u : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bits('n)
function sat_sub_u(a, b) = {
  let wide : bits('n + 1) = zero_extend(a) - zero_extend(b);
  wide[('n - 1) .. 0] & sign_extend(~(wide['n]))
}

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
    if x[i] == bitone then
      result = result ^ (zero_extend(y) << i)
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
      write_mem_linear(addr + i, src[(i * 8 + 7) .. (i * 8)])
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
    let sad : int = abs_diff8(d0, s0) + abs_diff8(d1, s1) +
                    abs_diff8(d2, s2) + abs_diff8(d3, s3);
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
val pcmp_implicit_len : (xmmword, range(0, 15)) -> range(0, 16)
function pcmp_implicit_len(x, ub) = {
  var len : range(0, 16) = ub + 1;
  var found : bool = false;
  foreach (i from 0 to 15) {
    if i <= ub & ~(found) then {
      let lo = if ub == 7 then i * 16 else i * 8;
      let hi = if ub == 7 then lo + 15 else lo + 7;
      if x[hi .. lo] == zeros() then {
        len = i;
        found = true
      }
    }
  };
  len
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
          then bool_to_bit(a[(a_lo + 15) .. a_lo] == b[(b_lo + 15) .. b_lo])
          else bool_to_bit(a[(a_lo + 7) .. a_lo] == b[(b_lo + 7) .. b_lo]);
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
  let int_res2 : bits(16) = match imm8[5..4] {
    0b00 => int_res1,                     // positive
    0b01 => int_res1 ^ (if ub == 7 then 0x00FF else 0xFFFF),  // negative
    0b10 => int_res1,                     // masked positive (same as positive)
    0b11 => {                             // masked negative
      var r : bits(16) = int_res1;
      foreach (i from 0 to 15) {
        if i <= ub & i < lb then
          r[i] = ~(int_res1[i])
      };
      r
    },
  };

  // Flags
  let cf : bit = bool_to_bit(int_res2 != zeros());
  let zf : bit = bool_to_bit(lb < (ub + 1));   // any invalid element in b
  let sf : bit = bool_to_bit(la < (ub + 1));   // any invalid element in a
  let of : bit = int_res2[0];

  (int_res2, cf, zf, sf, of)
}

// Clamp explicit string length per SDM: abs(value), saturated to max_len.
val pcmp_clamp_len : (dword, range(0, 16)) -> range(0, 16)
function pcmp_clamp_len(raw, max_len) = {
  let a : int = if signed(raw) < 0 then negate(signed(raw)) else signed(raw);
  if a >= max_len then max_len
  else if a < 0 then 0
  else a
}

// Find index of first (LSB) or last (MSB) set bit in IntRes2, bounded by ub.
// Returns ub+1 if no bits set.
val pcmp_bit_index : (bits(16), range(0, 15), bit) -> range(0, 16)
function pcmp_bit_index(int_res2, ub, msb_mode) = {
  if int_res2 == zeros() then ub + 1
  else if msb_mode == bitone then {
    var idx : range(0, 15) = 0;
    foreach (i from 0 to 15) {
      if i <= ub & int_res2[i] == bitone then idx = i
    };
    idx
  } else {
    var idx : range(0, 16) = ub + 1;
    var found : bool = false;
    foreach (i from 0 to 15) {
      if i <= ub & int_res2[i] == bitone & ~(found) then {
        idx = i;
        found = true
      }
    };
    idx
  }
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

// EXTRACTPS — Extract Packed Floating-Point Values (SSE4.1)
//
// Extracts a single-precision float from an XMM register at the offset
// specified by imm8[1:0] and stores the 32-bit result in a GPR or memory.
// In 64-bit mode with a GPR destination, the upper 32 bits are zeroed.
// No flags affected.
//
// Uses extract_dword_from_xmm from pextrb.sail (same operation as PEXTRD).
// INSERTPS — Insert Scalar Single-FP (SSE4.1)
// Selects a float from src, inserts into dst at specified position, then zeroes selected lanes.
// No flags affected.

val dispatch_2byte_sse_int : (range(0, 255), Prefixes) -> unit
function dispatch_2byte_sse_int(op, pfx) = {
  match op {
    // 0F 60-6B: PUNPCK*/PACKSSWB/PCMPGT*/PUNPCK*/PACKSSDW/PCMPEQ*
    op if 96 <= op & op <= 107 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let sub_op : range(0, 15) = op - 96;
        match sub_op {
          // PUNPCKLBW xmm1, xmm2/m128
          0 => {
            let d : xmmword = read_xmm(xreg);
            let s : xmmword = src_xmm;
            let result : xmmword =
              s[63..56] @ d[63..56] @
              s[55..48] @ d[55..48] @
              s[47..40] @ d[47..40] @
              s[39..32] @ d[39..32] @
              s[31..24] @ d[31..24] @
              s[23..16] @ d[23..16] @
              s[15..8]  @ d[15..8]  @
              s[7..0]   @ d[7..0];
            write_xmm_legacy(xreg, result)
          },
          // PUNPCKLWD xmm1, xmm2/m128
          1 => {
            let d : xmmword = read_xmm(xreg);
            let s : xmmword = src_xmm;
            let result : xmmword =
              s[63..48] @ d[63..48] @
              s[47..32] @ d[47..32] @
              s[31..16] @ d[31..16] @
              s[15..0]  @ d[15..0];
            write_xmm_legacy(xreg, result)
          },
          // PUNPCKLDQ xmm1, xmm2/m128
          2 => {
            let d : xmmword = read_xmm(xreg);
            let s : xmmword = src_xmm;
            let result : xmmword =
              s[63..32] @ d[63..32] @
              s[31..0]  @ d[31..0];
            write_xmm_legacy(xreg, result)
          },
          // PACKSSWB xmm1, xmm2/m128
          3 => {
            let d : xmmword = read_xmm(xreg);
            let s : xmmword = src_xmm;
            let r : xmmword =
              sat_s8(s[127..112]) @ sat_s8(s[111..96]) @
              sat_s8(s[95..80])   @ sat_s8(s[79..64]) @
              sat_s8(s[63..48])   @ sat_s8(s[47..32]) @
              sat_s8(s[31..16])   @ sat_s8(s[15..0]) @
              sat_s8(d[127..112]) @ sat_s8(d[111..96]) @
              sat_s8(d[95..80])   @ sat_s8(d[79..64]) @
              sat_s8(d[63..48])   @ sat_s8(d[47..32]) @
              sat_s8(d[31..16])   @ sat_s8(d[15..0]);
            write_xmm_legacy(xreg, r)
          },
          // PCMPGTB xmm1, xmm2/m128
          4 => {
            let a : xmmword = read_xmm(xreg);
            let b : xmmword = src_xmm;
            let r : xmmword =
              cmp_gt(a[127..120], b[127..120]) @ cmp_gt(a[119..112], b[119..112]) @
              cmp_gt(a[111..104], b[111..104]) @ cmp_gt(a[103..96], b[103..96]) @
              cmp_gt(a[95..88], b[95..88]) @ cmp_gt(a[87..80], b[87..80]) @
              cmp_gt(a[79..72], b[79..72]) @ cmp_gt(a[71..64], b[71..64]) @
              cmp_gt(a[63..56], b[63..56]) @ cmp_gt(a[55..48], b[55..48]) @
              cmp_gt(a[47..40], b[47..40]) @ cmp_gt(a[39..32], b[39..32]) @
              cmp_gt(a[31..24], b[31..24]) @ cmp_gt(a[23..16], b[23..16]) @
              cmp_gt(a[15..8], b[15..8]) @ cmp_gt(a[7..0], b[7..0]);
            write_xmm_legacy(xreg, r)
          },
          // PCMPGTW xmm1, xmm2/m128
          5 => {
            let a : xmmword = read_xmm(xreg);
            let b : xmmword = src_xmm;
            let r : xmmword =
              cmp_gt(a[127..112], b[127..112]) @ cmp_gt(a[111..96], b[111..96]) @
              cmp_gt(a[95..80], b[95..80]) @ cmp_gt(a[79..64], b[79..64]) @
              cmp_gt(a[63..48], b[63..48]) @ cmp_gt(a[47..32], b[47..32]) @
              cmp_gt(a[31..16], b[31..16]) @ cmp_gt(a[15..0], b[15..0]);
            write_xmm_legacy(xreg, r)
          },
          // PCMPGTD xmm1, xmm2/m128
          6 => {
            let a : xmmword = read_xmm(xreg);
            let b : xmmword = src_xmm;
            let r : xmmword =
              cmp_gt(a[127..96], b[127..96]) @
              cmp_gt(a[95..64], b[95..64]) @
              cmp_gt(a[63..32], b[63..32]) @
              cmp_gt(a[31..0], b[31..0]);
            write_xmm_legacy(xreg, r)
          },
          // PACKUSWB xmm1, xmm2/m128
          7 => {
            let d : xmmword = read_xmm(xreg);
            let s : xmmword = src_xmm;
            let r : xmmword =
              sat_su8(s[127..112]) @ sat_su8(s[111..96]) @
              sat_su8(s[95..80])   @ sat_su8(s[79..64]) @
              sat_su8(s[63..48])   @ sat_su8(s[47..32]) @
              sat_su8(s[31..16])   @ sat_su8(s[15..0]) @
              sat_su8(d[127..112]) @ sat_su8(d[111..96]) @
              sat_su8(d[95..80])   @ sat_su8(d[79..64]) @
              sat_su8(d[63..48])   @ sat_su8(d[47..32]) @
              sat_su8(d[31..16])   @ sat_su8(d[15..0]);
            write_xmm_legacy(xreg, r)
          },
          // PUNPCKHBW xmm1, xmm2/m128
          8 => {
            let d : xmmword = read_xmm(xreg);
            let s : xmmword = src_xmm;
            let result : xmmword =
              s[127..120] @ d[127..120] @
              s[119..112] @ d[119..112] @
              s[111..104] @ d[111..104] @
              s[103..96]  @ d[103..96]  @
              s[95..88]   @ d[95..88]   @
              s[87..80]   @ d[87..80]   @
              s[79..72]   @ d[79..72]   @
              s[71..64]   @ d[71..64];
            write_xmm_legacy(xreg, result)
          },
          // PUNPCKHWD xmm1, xmm2/m128
          9 => {
            let d : xmmword = read_xmm(xreg);
            let s : xmmword = src_xmm;
            let result : xmmword =
              s[127..112] @ d[127..112] @
              s[111..96]  @ d[111..96]  @
              s[95..80]   @ d[95..80]   @
              s[79..64]   @ d[79..64];
            write_xmm_legacy(xreg, result)
          },
          // PUNPCKHDQ xmm1, xmm2/m128
          10 => {
            let d : xmmword = read_xmm(xreg);
            let s : xmmword = src_xmm;
            let result : xmmword =
              s[127..96] @ d[127..96] @
              s[95..64]  @ d[95..64];
            write_xmm_legacy(xreg, result)
          },
          // PACKSSDW xmm1, xmm2/m128
          11 => {
            let d : xmmword = read_xmm(xreg);
            let s : xmmword = src_xmm;
            let r : xmmword =
              sat_s16(s[127..96]) @ sat_s16(s[95..64]) @
              sat_s16(s[63..32])  @ sat_s16(s[31..0]) @
              sat_s16(d[127..96]) @ sat_s16(d[95..64]) @
              sat_s16(d[63..32])  @ sat_s16(d[31..0]);
            write_xmm_legacy(xreg, r)
          },
          _ => raise_UD(),
        }
      }
    },

    // 0F 6C: PUNPCKLQDQ (SSE2 only, no MMX form)
    108 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then raise_UD();
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      let src_xmm : xmmword = match src {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(m) => read_mem(m),
      };
      let d : xmmword = read_xmm(xreg);
      let s : xmmword = src_xmm;
      write_xmm_legacy(xreg, s[63..0] @ d[63..0])
    },

    // 0F 6D: PUNPCKHQDQ (SSE2 only, no MMX form)
    109 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then raise_UD();
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      let src_xmm : xmmword = match src {
        RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
        RM_mem(m) => read_mem(m),
      };
      let d : xmmword = read_xmm(xreg);
      let s : xmmword = src_xmm;
      write_xmm_legacy(xreg, s[127..64] @ d[127..64])
    },

    // 0F 6E: MOVD/MOVQ xmm, r/m32 (or r/m64 with REX.W)
    //        MOVD/MOVQ mm, r/m32 (or r/m64 with REX.W) when no prefix
    110 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        match (src, pfx.rex_w) {
          (RM_reg(r), true)   => write_xmm_legacy(xreg, zero_extend(v(64, r))),
          (RM_mem(m), true)  => write_xmm_legacy(xreg, zero_extend(read_mem(64, m))),
          (RM_reg(r), false)  => write_xmm_legacy(xreg, zero_extend(v(32, r))),
          (RM_mem(m), false) => write_xmm_legacy(xreg, zero_extend(read_mem(32, m))),
        }
      }
    },

    // 0F 6F: MOVDQA/MOVDQU xmm, xmm/m128 / MOVQ mm, mm/m64 (no prefix)
    111 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        match src {
          RM_reg(_) => {
            match mp {
              MP_66 => exec_movdqa(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
              MP_F3 => exec_movdqu(xreg, read_xmm(modrm_xmm_rm(modrm, pfx))),
              _     => raise_UD(),
            }
          },
          RM_mem(m) => write_xmm_legacy(xreg, read_mem(m)),
        }
      }
    },

    // 0F 70: PSHUFD/PSHUFHW/PSHUFLW / PSHUFW (no prefix)
    112 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let imm = fetch_byte();
        match mp {
          // PSHUFD xmm1, xmm2/m128, imm8
          MP_66 => {
            let s : xmmword = src_xmm;
            let sel0 : range(0, 3) = unsigned(imm[1..0]);
            let sel1 : range(0, 3) = unsigned(imm[3..2]);
            let sel2 : range(0, 3) = unsigned(imm[5..4]);
            let sel3 : range(0, 3) = unsigned(imm[7..6]);
            let d0 : dword = s[(sel0 * 32 + 31) .. (sel0 * 32)];
            let d1 : dword = s[(sel1 * 32 + 31) .. (sel1 * 32)];
            let d2 : dword = s[(sel2 * 32 + 31) .. (sel2 * 32)];
            let d3 : dword = s[(sel3 * 32 + 31) .. (sel3 * 32)];
            write_xmm_legacy(xreg, d3 @ d2 @ d1 @ d0)
          },
          // PSHUFHW xmm1, xmm2/m128, imm8
          MP_F3 => {
            let s : xmmword = src_xmm;
            let low : qword = s[63..0];
            let w0 : word = select_high_word(s, imm[1..0]);
            let w1 : word = select_high_word(s, imm[3..2]);
            let w2 : word = select_high_word(s, imm[5..4]);
            let w3 : word = select_high_word(s, imm[7..6]);
            write_xmm_legacy(xreg, w3 @ w2 @ w1 @ w0 @ low)
          },
          // PSHUFLW xmm1, xmm2/m128, imm8
          MP_F2 => {
            let s : xmmword = src_xmm;
            let high : qword = s[127..64];
            let w0 : word = select_low_word(s, imm[1..0]);
            let w1 : word = select_low_word(s, imm[3..2]);
            let w2 : word = select_low_word(s, imm[5..4]);
            let w3 : word = select_low_word(s, imm[7..6]);
            write_xmm_legacy(xreg, high @ w3 @ w2 @ w1 @ w0)
          },
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
        let modrm = fetch_byte();
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let _ = modrm_rm(modrm, pfx);
        let xreg = modrm_xmm_rm(modrm, pfx);
        let imm = fetch_byte();
        match reg_field {
          // PSRLW xmm1, imm8
          2 => {
            let c : nat = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            let r : xmmword =
              (a[127..112] >> c) @ (a[111..96] >> c) @
              (a[95..80] >> c) @ (a[79..64] >> c) @
              (a[63..48] >> c) @ (a[47..32] >> c) @
              (a[31..16] >> c) @ (a[15..0] >> c);
            write_xmm_legacy(xreg, r)
          },
          // PSRAW xmm1, imm8
          4 => {
            let c : nat = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            let r : xmmword =
              (a[127..112] >>> c) @ (a[111..96] >>> c) @
              (a[95..80] >>> c) @ (a[79..64] >>> c) @
              (a[63..48] >>> c) @ (a[47..32] >>> c) @
              (a[31..16] >>> c) @ (a[15..0] >>> c);
            write_xmm_legacy(xreg, r)
          },
          // PSLLW xmm1, imm8
          6 => {
            let c : nat = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            let r : xmmword =
              (a[127..112] << c) @ (a[111..96] << c) @
              (a[95..80] << c) @ (a[79..64] << c) @
              (a[63..48] << c) @ (a[47..32] << c) @
              (a[31..16] << c) @ (a[15..0] << c);
            write_xmm_legacy(xreg, r)
          },
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
        let modrm = fetch_byte();
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let _ = modrm_rm(modrm, pfx);
        let xreg = modrm_xmm_rm(modrm, pfx);
        let imm = fetch_byte();
        match reg_field {
          // PSRLD xmm1, imm8
          2 => {
            let c : nat = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            let r : xmmword =
              (a[127..96] >> c) @ (a[95..64] >> c) @
              (a[63..32] >> c) @ (a[31..0] >> c);
            write_xmm_legacy(xreg, r)
          },
          // PSRAD xmm1, imm8
          4 => {
            let c : nat = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            let r : xmmword =
              (a[127..96] >>> c) @ (a[95..64] >>> c) @
              (a[63..32] >>> c) @ (a[31..0] >>> c);
            write_xmm_legacy(xreg, r)
          },
          // PSLLD xmm1, imm8
          6 => {
            let c : nat = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            let r : xmmword =
              (a[127..96] << c) @ (a[95..64] << c) @
              (a[63..32] << c) @ (a[31..0] << c);
            write_xmm_legacy(xreg, r)
          },
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
        let modrm = fetch_byte();
        let reg_field : range(0, 7) = unsigned(modrm[5..3]);
        let _ = modrm_rm(modrm, pfx);
        let xreg = modrm_xmm_rm(modrm, pfx);
        let imm = fetch_byte();
        match reg_field {
          // PSRLQ xmm1, imm8
          2 => {
            let c : nat = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            let r : xmmword = (a[127..64] >> c) @ (a[63..0] >> c);
            write_xmm_legacy(xreg, r)
          },
          // PSRLDQ xmm1, imm8
          3 => {
            let c : range(0, 255) = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            write_xmm_legacy(xreg, a >> (c * 8))
          },
          // PSLLQ xmm1, imm8
          6 => {
            let c : nat = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            let r : xmmword = (a[127..64] << c) @ (a[63..0] << c);
            write_xmm_legacy(xreg, r)
          },
          // PSLLDQ xmm1, imm8
          7 => {
            let c : range(0, 255) = unsigned(imm);
            let a : xmmword = read_xmm(xreg);
            write_xmm_legacy(xreg, a << (c * 8))
          },
          _ => raise_UD(),
        }
      }
    },

    // 0F 74-76: PCMPEQB/PCMPEQW/PCMPEQD (66 prefix)
    op if 116 <= op & op <= 118 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        match op {
          // PCMPEQB xmm1, xmm2/m128
          116 => {
            let a : xmmword = read_xmm(xreg);
            let b : xmmword = src_xmm;
            let r : xmmword =
              cmp_eq(a[127..120], b[127..120]) @ cmp_eq(a[119..112], b[119..112]) @
              cmp_eq(a[111..104], b[111..104]) @ cmp_eq(a[103..96], b[103..96]) @
              cmp_eq(a[95..88], b[95..88]) @ cmp_eq(a[87..80], b[87..80]) @
              cmp_eq(a[79..72], b[79..72]) @ cmp_eq(a[71..64], b[71..64]) @
              cmp_eq(a[63..56], b[63..56]) @ cmp_eq(a[55..48], b[55..48]) @
              cmp_eq(a[47..40], b[47..40]) @ cmp_eq(a[39..32], b[39..32]) @
              cmp_eq(a[31..24], b[31..24]) @ cmp_eq(a[23..16], b[23..16]) @
              cmp_eq(a[15..8], b[15..8]) @ cmp_eq(a[7..0], b[7..0]);
            write_xmm_legacy(xreg, r)
          },
          // PCMPEQW xmm1, xmm2/m128
          117 => {
            let a : xmmword = read_xmm(xreg);
            let b : xmmword = src_xmm;
            let r : xmmword =
              cmp_eq(a[127..112], b[127..112]) @ cmp_eq(a[111..96], b[111..96]) @
              cmp_eq(a[95..80], b[95..80]) @ cmp_eq(a[79..64], b[79..64]) @
              cmp_eq(a[63..48], b[63..48]) @ cmp_eq(a[47..32], b[47..32]) @
              cmp_eq(a[31..16], b[31..16]) @ cmp_eq(a[15..0], b[15..0]);
            write_xmm_legacy(xreg, r)
          },
          // PCMPEQD xmm1, xmm2/m128
          _   => {
            let a : xmmword = read_xmm(xreg);
            let b : xmmword = src_xmm;
            let r : xmmword =
              cmp_eq(a[127..96], b[127..96]) @
              cmp_eq(a[95..64], b[95..64]) @
              cmp_eq(a[63..32], b[63..32]) @
              cmp_eq(a[31..0], b[31..0]);
            write_xmm_legacy(xreg, r)
          },
        }
      }
    },

    // 0F 7E: MOVD/MOVQ r/m32, xmm (66) / MOVQ xmm,xmm/m64 (F3) / MOVD r/m32, mm (NP)
    126 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let src = modrm_rm(modrm, pfx);
        match mp {
          // MOVD/MOVQ r/m, xmm
          MP_66 => {
            let src_xmm = modrm_xmm_reg(modrm, pfx);
            let x = read_xmm(src_xmm);
            match (src, pfx.rex_w) {
              (RM_reg(r), true)   => v(r) = x[63..0],
              (RM_mem(m), true)  => write_mem(64, m, x[63..0]),
              (RM_reg(r), false)  => v(r) = x[31..0],
              (RM_mem(m), false) => write_mem(32, m, x[31..0]),
            }
          },
          // MOVQ xmm1, xmm2/m64
          MP_F3 => {
            let xreg = modrm_xmm_reg(modrm, pfx);
            match src {
              RM_reg(_) => {
                let src = read_xmm(modrm_xmm_rm(modrm, pfx));
                write_xmm_legacy(xreg, zero_extend(src[63..0]))
              },
              RM_mem(m) => {
                let v : xmmword = zero_extend(read_mem(64, m));
                write_xmm(xreg, v)
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
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let dest = modrm_rm(modrm, pfx);
        match dest {
          RM_reg(_) => {
            let dst_xmm = modrm_xmm_rm(modrm, pfx);
            match mp {
              MP_66 => exec_movdqa(dst_xmm, read_xmm(xreg)),
              MP_F3 => exec_movdqu(dst_xmm, read_xmm(xreg)),
              _     => raise_UD(),
            }
          },
          RM_mem(m) => {
            write_mem(m,read_xmm(xreg))
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
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let _ = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
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
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        write_xmm_legacy(xreg, a & b)
      }
    },

    // 0F DF: PANDN xmm, xmm/m128 (66 prefix)
    223 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        write_xmm_legacy(xreg, ~(read_xmm(xreg)) & src_xmm)
      }
    },

    // 0F E5: PMULHW xmm, xmm/m128 (66 prefix)
    229 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          mul_hi16s(a[127..112], b[127..112]) @ mul_hi16s(a[111..96], b[111..96]) @
          mul_hi16s(a[95..80], b[95..80]) @ mul_hi16s(a[79..64], b[79..64]) @
          mul_hi16s(a[63..48], b[63..48]) @ mul_hi16s(a[47..32], b[47..32]) @
          mul_hi16s(a[31..16], b[31..16]) @ mul_hi16s(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F EB: POR xmm, xmm/m128 (66 prefix)
    235 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        write_xmm_legacy(xreg, read_xmm(xreg) | src_xmm)
      }
    },

    // 0F EF: PXOR xmm, xmm/m128 (66 prefix)
    239 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        write_xmm_legacy(xreg, a ^ b)
      }
    },

    // 0F D4: PADDQ (66 prefix)
    212 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword = (a[127..64] + b[127..64]) @ (a[63..0] + b[63..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F F4: PMULUDQ (66 prefix)
    244 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let hi : qword = to_bits_truncate(unsigned(a[95..64]) * unsigned(b[95..64]));
        let lo : qword = to_bits_truncate(unsigned(a[31..0]) * unsigned(b[31..0]));
        let r : xmmword = hi @ lo;
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F F8: PSUBB (66 prefix)
    248 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          (a[127..120] - b[127..120]) @ (a[119..112] - b[119..112]) @
          (a[111..104] - b[111..104]) @ (a[103..96] - b[103..96]) @
          (a[95..88] - b[95..88]) @ (a[87..80] - b[87..80]) @
          (a[79..72] - b[79..72]) @ (a[71..64] - b[71..64]) @
          (a[63..56] - b[63..56]) @ (a[55..48] - b[55..48]) @
          (a[47..40] - b[47..40]) @ (a[39..32] - b[39..32]) @
          (a[31..24] - b[31..24]) @ (a[23..16] - b[23..16]) @
          (a[15..8] - b[15..8]) @ (a[7..0] - b[7..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F F9: PSUBW (66 prefix)
    249 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword = (a[127..112] - b[127..112]) @
                             (a[111..96] - b[111..96]) @
                             (a[95..80] - b[95..80]) @
                             (a[79..64] - b[79..64]) @
                             (a[63..48] - b[63..48]) @
                             (a[47..32] - b[47..32]) @
                             (a[31..16] - b[31..16]) @
                             (a[15..0] - b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F FA: PSUBD (66 prefix)
    250 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword = (a[127..96] - b[127..96]) @
                             (a[95..64] - b[95..64]) @
                             (a[63..32] - b[63..32]) @
                             (a[31..0] - b[31..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F FB: PSUBQ (66 prefix)
    251 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword = (a[127..64] - b[127..64]) @ (a[63..0] - b[63..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F FC: PADDB (66 prefix)
    252 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        var result : xmmword = zeros();
        result[7..0]     = a[7..0]     + b[7..0];
        result[15..8]    = a[15..8]    + b[15..8];
        result[23..16]   = a[23..16]   + b[23..16];
        result[31..24]   = a[31..24]   + b[31..24];
        result[39..32]   = a[39..32]   + b[39..32];
        result[47..40]   = a[47..40]   + b[47..40];
        result[55..48]   = a[55..48]   + b[55..48];
        result[63..56]   = a[63..56]   + b[63..56];
        result[71..64]   = a[71..64]   + b[71..64];
        result[79..72]   = a[79..72]   + b[79..72];
        result[87..80]   = a[87..80]   + b[87..80];
        result[95..88]   = a[95..88]   + b[95..88];
        result[103..96]  = a[103..96]  + b[103..96];
        result[111..104] = a[111..104] + b[111..104];
        result[119..112] = a[119..112] + b[119..112];
        result[127..120] = a[127..120] + b[127..120];
        write_xmm_legacy(xreg, result)
      }
    },

    // 0F FD: PADDW (66 prefix)
    253 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword = (a[127..112] + b[127..112]) @
                             (a[111..96] + b[111..96]) @
                             (a[95..80] + b[95..80]) @
                             (a[79..64] + b[79..64]) @
                             (a[63..48] + b[63..48]) @
                             (a[47..32] + b[47..32]) @
                             (a[31..16] + b[31..16]) @
                             (a[15..0] + b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F FE: PADDD (66 prefix)
    254 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword = (a[127..96] + b[127..96]) @
                             (a[95..64] + b[95..64]) @
                             (a[63..32] + b[63..32]) @
                             (a[31..0] + b[31..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F E0: PAVGB (66 prefix)
    224 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          avg(a[127..120], b[127..120]) @ avg(a[119..112], b[119..112]) @
          avg(a[111..104], b[111..104]) @ avg(a[103..96], b[103..96]) @
          avg(a[95..88], b[95..88]) @ avg(a[87..80], b[87..80]) @
          avg(a[79..72], b[79..72]) @ avg(a[71..64], b[71..64]) @
          avg(a[63..56], b[63..56]) @ avg(a[55..48], b[55..48]) @
          avg(a[47..40], b[47..40]) @ avg(a[39..32], b[39..32]) @
          avg(a[31..24], b[31..24]) @ avg(a[23..16], b[23..16]) @
          avg(a[15..8], b[15..8]) @ avg(a[7..0], b[7..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F DA: PMINUB (66 prefix)
    218 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          min_u(a[127..120], b[127..120]) @ min_u(a[119..112], b[119..112]) @
          min_u(a[111..104], b[111..104]) @ min_u(a[103..96], b[103..96]) @
          min_u(a[95..88], b[95..88]) @ min_u(a[87..80], b[87..80]) @
          min_u(a[79..72], b[79..72]) @ min_u(a[71..64], b[71..64]) @
          min_u(a[63..56], b[63..56]) @ min_u(a[55..48], b[55..48]) @
          min_u(a[47..40], b[47..40]) @ min_u(a[39..32], b[39..32]) @
          min_u(a[31..24], b[31..24]) @ min_u(a[23..16], b[23..16]) @
          min_u(a[15..8], b[15..8]) @ min_u(a[7..0], b[7..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F DE: PMAXUB (66 prefix)
    222 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          max_u(a[127..120], b[127..120]) @ max_u(a[119..112], b[119..112]) @
          max_u(a[111..104], b[111..104]) @ max_u(a[103..96], b[103..96]) @
          max_u(a[95..88], b[95..88]) @ max_u(a[87..80], b[87..80]) @
          max_u(a[79..72], b[79..72]) @ max_u(a[71..64], b[71..64]) @
          max_u(a[63..56], b[63..56]) @ max_u(a[55..48], b[55..48]) @
          max_u(a[47..40], b[47..40]) @ max_u(a[39..32], b[39..32]) @
          max_u(a[31..24], b[31..24]) @ max_u(a[23..16], b[23..16]) @
          max_u(a[15..8], b[15..8]) @ max_u(a[7..0], b[7..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F F6: PSADBW (66 prefix)
    246 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = match src {
          RM_reg(_) => read_xmm(modrm_xmm_rm(modrm, pfx)),
          RM_mem(m) => read_mem(m),
        };
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let sum_hi : int = abs_diff8(a[127..120], b[127..120]) +
                           abs_diff8(a[119..112], b[119..112]) +
                           abs_diff8(a[111..104], b[111..104]) +
                           abs_diff8(a[103..96], b[103..96]) +
                           abs_diff8(a[95..88], b[95..88]) +
                           abs_diff8(a[87..80], b[87..80]) +
                           abs_diff8(a[79..72], b[79..72]) +
                           abs_diff8(a[71..64], b[71..64]);
        let sum_lo : int = abs_diff8(a[63..56], b[63..56]) +
                           abs_diff8(a[55..48], b[55..48]) +
                           abs_diff8(a[47..40], b[47..40]) +
                           abs_diff8(a[39..32], b[39..32]) +
                           abs_diff8(a[31..24], b[31..24]) +
                           abs_diff8(a[23..16], b[23..16]) +
                           abs_diff8(a[15..8], b[15..8]) +
                           abs_diff8(a[7..0], b[7..0]);
        let hi : qword = to_bits_truncate(sum_hi);
        let lo : qword = to_bits_truncate(sum_lo);
        let r : xmmword = hi @ lo;
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F E7: MOVNTDQ m128, xmm (66 prefix) / MOVNTQ m64, mm (no prefix)
    231 => {
      let mp = get_mandatory_prefix(pfx);
      if mp == MP_NONE then {
        dispatch_mmx(op, pfx)
      } else {
        if mp != MP_66 then raise_UD();
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let dest = modrm_rm(modrm, pfx);
        rm_mem(dest) = read_xmm(xreg)
      }
    },

    // 0F C4: PINSRW xmm, r32/m16, imm8 (66 prefix)
    196 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let v : word = v(src);
        let imm = fetch_byte();
        let v_0 : xmmword = read_xmm(xreg);
        let sel : range(0, 7) = unsigned(imm[2..0]);
        let r : xmmword = match sel {
          0 => v_0[127..16] @ v,
          1 => v_0[127..32] @ v @ v_0[15..0],
          2 => v_0[127..48] @ v @ v_0[31..0],
          3 => v_0[127..64] @ v @ v_0[47..0],
          4 => v_0[127..80] @ v @ v_0[63..0],
          5 => v_0[127..96] @ v @ v_0[79..0],
          6 => v_0[127..112] @ v @ v_0[95..0],
          7 => v @ v_0[111..0]
        };
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F C5: PEXTRW r32, xmm, imm8 (66 prefix)
    197 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let reg = modrm_reg(modrm, pfx);
        let _ = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
        let imm = fetch_byte();
        let sel : range(0, 7) = unsigned(imm[2..0]);
        let word : word = match sel {
          0 => src_xmm[15..0],
          1 => src_xmm[31..16],
          2 => src_xmm[47..32],
          3 => src_xmm[63..48],
          4 => src_xmm[79..64],
          5 => src_xmm[95..80],
          6 => src_xmm[111..96],
          7 => src_xmm[127..112]
        };
        v(reg) = zero_extend(32, word)
      }
    },

    // 0F D1: PSRLW xmm, xmm/m128 (66 prefix)
    209 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let c : nat = unsigned(src_xmm[63..0]);
        let a : xmmword = read_xmm(xreg);
        let r : xmmword =
          (a[127..112] >> c) @ (a[111..96] >> c) @
          (a[95..80] >> c) @ (a[79..64] >> c) @
          (a[63..48] >> c) @ (a[47..32] >> c) @
          (a[31..16] >> c) @ (a[15..0] >> c);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F D2: PSRLD xmm, xmm/m128 (66 prefix)
    210 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let c : nat = unsigned(src_xmm[63..0]);
        let a : xmmword = read_xmm(xreg);
        let r : xmmword =
          (a[127..96] >> c) @ (a[95..64] >> c) @
          (a[63..32] >> c) @ (a[31..0] >> c);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F D3: PSRLQ xmm, xmm/m128 (66 prefix)
    211 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let c : nat = unsigned(src_xmm[63..0]);
        let a : xmmword = read_xmm(xreg);
        let r : xmmword = (a[127..64] >> c) @ (a[63..0] >> c);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F D5: PMULLW (66 prefix)
    213 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          mul_lo(a[127..112], b[127..112]) @ mul_lo(a[111..96], b[111..96]) @
          mul_lo(a[95..80], b[95..80]) @ mul_lo(a[79..64], b[79..64]) @
          mul_lo(a[63..48], b[63..48]) @ mul_lo(a[47..32], b[47..32]) @
          mul_lo(a[31..16], b[31..16]) @ mul_lo(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F D6: MOVQ xmm1/m64, xmm2 (66 prefix)
    214 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let src_xmm = modrm_xmm_reg(modrm, pfx);
        let dest = modrm_rm(modrm, pfx);
        let v : qword = read_xmm(src_xmm)[63..0];
        match dest {
          RM_reg(_) => {
            let dst = modrm_xmm_rm(modrm, pfx);
            write_xmm_legacy(dst, zero_extend(v))
          },
          RM_mem(m) => write_mem(m,v),
        }
      }
    },

    // 0F D8: PSUBUSB (66 prefix)
    216 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          sat_sub_u(a[127..120], b[127..120]) @ sat_sub_u(a[119..112], b[119..112]) @
          sat_sub_u(a[111..104], b[111..104]) @ sat_sub_u(a[103..96], b[103..96]) @
          sat_sub_u(a[95..88], b[95..88]) @ sat_sub_u(a[87..80], b[87..80]) @
          sat_sub_u(a[79..72], b[79..72]) @ sat_sub_u(a[71..64], b[71..64]) @
          sat_sub_u(a[63..56], b[63..56]) @ sat_sub_u(a[55..48], b[55..48]) @
          sat_sub_u(a[47..40], b[47..40]) @ sat_sub_u(a[39..32], b[39..32]) @
          sat_sub_u(a[31..24], b[31..24]) @ sat_sub_u(a[23..16], b[23..16]) @
          sat_sub_u(a[15..8], b[15..8]) @ sat_sub_u(a[7..0], b[7..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F D9: PSUBUSW (66 prefix)
    217 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          sat_sub_u(a[127..112], b[127..112]) @ sat_sub_u(a[111..96], b[111..96]) @
          sat_sub_u(a[95..80], b[95..80]) @ sat_sub_u(a[79..64], b[79..64]) @
          sat_sub_u(a[63..48], b[63..48]) @ sat_sub_u(a[47..32], b[47..32]) @
          sat_sub_u(a[31..16], b[31..16]) @ sat_sub_u(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F DC: PADDUSB (66 prefix)
    220 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          sat_add_u(a[127..120], b[127..120]) @ sat_add_u(a[119..112], b[119..112]) @
          sat_add_u(a[111..104], b[111..104]) @ sat_add_u(a[103..96], b[103..96]) @
          sat_add_u(a[95..88], b[95..88]) @ sat_add_u(a[87..80], b[87..80]) @
          sat_add_u(a[79..72], b[79..72]) @ sat_add_u(a[71..64], b[71..64]) @
          sat_add_u(a[63..56], b[63..56]) @ sat_add_u(a[55..48], b[55..48]) @
          sat_add_u(a[47..40], b[47..40]) @ sat_add_u(a[39..32], b[39..32]) @
          sat_add_u(a[31..24], b[31..24]) @ sat_add_u(a[23..16], b[23..16]) @
          sat_add_u(a[15..8], b[15..8]) @ sat_add_u(a[7..0], b[7..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F DD: PADDUSW (66 prefix)
    221 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          sat_add_u(a[127..112], b[127..112]) @ sat_add_u(a[111..96], b[111..96]) @
          sat_add_u(a[95..80], b[95..80]) @ sat_add_u(a[79..64], b[79..64]) @
          sat_add_u(a[63..48], b[63..48]) @ sat_add_u(a[47..32], b[47..32]) @
          sat_add_u(a[31..16], b[31..16]) @ sat_add_u(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F E1: PSRAW xmm, xmm/m128 (66 prefix)
    225 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let c : nat = unsigned(src_xmm[63..0]);
        let a : xmmword = read_xmm(xreg);
        let r : xmmword =
          (a[127..112] >>> c) @ (a[111..96] >>> c) @
          (a[95..80] >>> c) @ (a[79..64] >>> c) @
          (a[63..48] >>> c) @ (a[47..32] >>> c) @
          (a[31..16] >>> c) @ (a[15..0] >>> c);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F E2: PSRAD xmm, xmm/m128 (66 prefix)
    226 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let c : nat = unsigned(src_xmm[63..0]);
        let a : xmmword = read_xmm(xreg);
        let r : xmmword =
          (a[127..96] >>> c) @ (a[95..64] >>> c) @
          (a[63..32] >>> c) @ (a[31..0] >>> c);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F E3: PAVGW (66 prefix)
    227 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          avg(a[127..112], b[127..112]) @ avg(a[111..96], b[111..96]) @
          avg(a[95..80], b[95..80]) @ avg(a[79..64], b[79..64]) @
          avg(a[63..48], b[63..48]) @ avg(a[47..32], b[47..32]) @
          avg(a[31..16], b[31..16]) @ avg(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F E4: PMULHUW (66 prefix)
    228 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          mul_hi16u(a[127..112], b[127..112]) @ mul_hi16u(a[111..96], b[111..96]) @
          mul_hi16u(a[95..80], b[95..80]) @ mul_hi16u(a[79..64], b[79..64]) @
          mul_hi16u(a[63..48], b[63..48]) @ mul_hi16u(a[47..32], b[47..32]) @
          mul_hi16u(a[31..16], b[31..16]) @ mul_hi16u(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F E8: PSUBSB (66 prefix)
    232 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          sat_sub_s(a[127..120], b[127..120]) @ sat_sub_s(a[119..112], b[119..112]) @
          sat_sub_s(a[111..104], b[111..104]) @ sat_sub_s(a[103..96], b[103..96]) @
          sat_sub_s(a[95..88], b[95..88]) @ sat_sub_s(a[87..80], b[87..80]) @
          sat_sub_s(a[79..72], b[79..72]) @ sat_sub_s(a[71..64], b[71..64]) @
          sat_sub_s(a[63..56], b[63..56]) @ sat_sub_s(a[55..48], b[55..48]) @
          sat_sub_s(a[47..40], b[47..40]) @ sat_sub_s(a[39..32], b[39..32]) @
          sat_sub_s(a[31..24], b[31..24]) @ sat_sub_s(a[23..16], b[23..16]) @
          sat_sub_s(a[15..8], b[15..8]) @ sat_sub_s(a[7..0], b[7..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F E9: PSUBSW (66 prefix)
    233 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          sat_sub_s(a[127..112], b[127..112]) @ sat_sub_s(a[111..96], b[111..96]) @
          sat_sub_s(a[95..80], b[95..80]) @ sat_sub_s(a[79..64], b[79..64]) @
          sat_sub_s(a[63..48], b[63..48]) @ sat_sub_s(a[47..32], b[47..32]) @
          sat_sub_s(a[31..16], b[31..16]) @ sat_sub_s(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F EC: PADDSB (66 prefix)
    236 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          sat_add_s(a[127..120], b[127..120]) @ sat_add_s(a[119..112], b[119..112]) @
          sat_add_s(a[111..104], b[111..104]) @ sat_add_s(a[103..96], b[103..96]) @
          sat_add_s(a[95..88], b[95..88]) @ sat_add_s(a[87..80], b[87..80]) @
          sat_add_s(a[79..72], b[79..72]) @ sat_add_s(a[71..64], b[71..64]) @
          sat_add_s(a[63..56], b[63..56]) @ sat_add_s(a[55..48], b[55..48]) @
          sat_add_s(a[47..40], b[47..40]) @ sat_add_s(a[39..32], b[39..32]) @
          sat_add_s(a[31..24], b[31..24]) @ sat_add_s(a[23..16], b[23..16]) @
          sat_add_s(a[15..8], b[15..8]) @ sat_add_s(a[7..0], b[7..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F ED: PADDSW (66 prefix)
    237 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          sat_add_s(a[127..112], b[127..112]) @ sat_add_s(a[111..96], b[111..96]) @
          sat_add_s(a[95..80], b[95..80]) @ sat_add_s(a[79..64], b[79..64]) @
          sat_add_s(a[63..48], b[63..48]) @ sat_add_s(a[47..32], b[47..32]) @
          sat_add_s(a[31..16], b[31..16]) @ sat_add_s(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F F0: LDDQU xmm, m128 (F2 prefix, SSE3)
    240 => {
      if ~(has_sse3) then raise_UD();
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_F2 then raise_UD();
      let modrm = fetch_byte();
      let xreg = modrm_xmm_reg(modrm, pfx);
      let src = modrm_rm(modrm, pfx);
      write_xmm(xreg, rm_mem(src))
    },

    // 0F F1: PSLLW xmm, xmm/m128 (66 prefix)
    241 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let c : nat = unsigned(src_xmm[63..0]);
        let a : xmmword = read_xmm(xreg);
        let r : xmmword =
          (a[127..112] << c) @ (a[111..96] << c) @
          (a[95..80] << c) @ (a[79..64] << c) @
          (a[63..48] << c) @ (a[47..32] << c) @
          (a[31..16] << c) @ (a[15..0] << c);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F F2: PSLLD xmm, xmm/m128 (66 prefix)
    242 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let c : nat = unsigned(src_xmm[63..0]);
        let a : xmmword = read_xmm(xreg);
        let r : xmmword =
          (a[127..96] << c) @ (a[95..64] << c) @
          (a[63..32] << c) @ (a[31..0] << c);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F F3: PSLLQ xmm, xmm/m128 (66 prefix)
    243 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let c : nat = unsigned(src_xmm[63..0]);
        let a : xmmword = read_xmm(xreg);
        let r : xmmword = (a[127..64] << c) @ (a[63..0] << c);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F F5: PMADDWD (66 prefix)
    245 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let d3 : dword = to_bits_truncate(signed(a[127..112]) * signed(b[127..112]) +
                                              signed(a[111..96]) * signed(b[111..96]));
        let d2 : dword = to_bits_truncate(signed(a[95..80]) * signed(b[95..80]) +
                                              signed(a[79..64]) * signed(b[79..64]));
        let d1 : dword = to_bits_truncate(signed(a[63..48]) * signed(b[63..48]) +
                                              signed(a[47..32]) * signed(b[47..32]));
        let d0 : dword = to_bits_truncate(signed(a[31..16]) * signed(b[31..16]) +
                                              signed(a[15..0]) * signed(b[15..0]));
        let r : xmmword = d3 @ d2 @ d1 @ d0;
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F F7: MASKMOVDQU xmm, xmm (66 prefix)
    247 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let _ = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = read_xmm(modrm_xmm_rm(modrm, pfx));
        let addr = v(64, RDI);
        maskmovdqu(read_xmm(xreg), src_xmm, addr)
      }
    },

    // 0F EE: PMAXSW (66 prefix)
    238 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          max_s(a[127..112], b[127..112]) @ max_s(a[111..96], b[111..96]) @
          max_s(a[95..80], b[95..80]) @ max_s(a[79..64], b[79..64]) @
          max_s(a[63..48], b[63..48]) @ max_s(a[47..32], b[47..32]) @
          max_s(a[31..16], b[31..16]) @ max_s(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },

    // 0F EA: PMINSW (66 prefix)
    234 => {
      let mp = get_mandatory_prefix(pfx);
      if mp != MP_66 then {
        dispatch_mmx(op, pfx)
      } else {
        let modrm = fetch_byte();
        let xreg = modrm_xmm_reg(modrm, pfx);
        let src = modrm_rm(modrm, pfx);
        let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
        let a : xmmword = read_xmm(xreg);
        let b : xmmword = src_xmm;
        let r : xmmword =
          min_s(a[127..112], b[127..112]) @ min_s(a[111..96], b[111..96]) @
          min_s(a[95..80], b[95..80]) @ min_s(a[79..64], b[79..64]) @
          min_s(a[63..48], b[63..48]) @ min_s(a[47..32], b[47..32]) @
          min_s(a[31..16], b[31..16]) @ min_s(a[15..0], b[15..0]);
        write_xmm_legacy(xreg, r)
      }
    },
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
  let modrm = fetch_byte();
  let xreg = modrm_xmm_reg(modrm, pfx);
  let src = modrm_rm(modrm, pfx);
  let src_xmm : xmmword = decode_xmm_src(modrm, src, pfx);
  match op {

    // SSSE3 — PSHUFB
    0  => {
      let d : xmmword = read_xmm(xreg);
      let s : xmmword = src_xmm;
      let r : xmmword =
        pshufb_byte(d, s[127..120]) @ pshufb_byte(d, s[119..112]) @
        pshufb_byte(d, s[111..104]) @ pshufb_byte(d, s[103..96]) @
        pshufb_byte(d, s[95..88])   @ pshufb_byte(d, s[87..80]) @
        pshufb_byte(d, s[79..72])   @ pshufb_byte(d, s[71..64]) @
        pshufb_byte(d, s[63..56])   @ pshufb_byte(d, s[55..48]) @
        pshufb_byte(d, s[47..40])   @ pshufb_byte(d, s[39..32]) @
        pshufb_byte(d, s[31..24])   @ pshufb_byte(d, s[23..16]) @
        pshufb_byte(d, s[15..8])    @ pshufb_byte(d, s[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PHADDW xmm1, xmm2/m128
    1  => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        (b[127..112] + b[111..96]) @ (b[95..80] + b[79..64]) @
        (b[63..48] + b[47..32]) @ (b[31..16] + b[15..0]) @
        (a[127..112] + a[111..96]) @ (a[95..80] + a[79..64]) @
        (a[63..48] + a[47..32]) @ (a[31..16] + a[15..0]);
      write_xmm_legacy(xreg, r)
    },
    // PHADDD xmm1, xmm2/m128
    2  => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        (b[127..96] + b[95..64]) @ (b[63..32] + b[31..0]) @
        (a[127..96] + a[95..64]) @ (a[63..32] + a[31..0]);
      write_xmm_legacy(xreg, r)
    },
    // PHADDSW xmm1, xmm2/m128
    3  => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        sat_add_s(b[127..112], b[111..96]) @ sat_add_s(b[95..80], b[79..64]) @
        sat_add_s(b[63..48], b[47..32]) @ sat_add_s(b[31..16], b[15..0]) @
        sat_add_s(a[127..112], a[111..96]) @ sat_add_s(a[95..80], a[79..64]) @
        sat_add_s(a[63..48], a[47..32]) @ sat_add_s(a[31..16], a[15..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMADDUBSW xmm1, xmm2/m128
    4  => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        pmaddubsw_pair(a[127..120], b[127..120], a[119..112], b[119..112]) @
        pmaddubsw_pair(a[111..104], b[111..104], a[103..96], b[103..96]) @
        pmaddubsw_pair(a[95..88], b[95..88], a[87..80], b[87..80]) @
        pmaddubsw_pair(a[79..72], b[79..72], a[71..64], b[71..64]) @
        pmaddubsw_pair(a[63..56], b[63..56], a[55..48], b[55..48]) @
        pmaddubsw_pair(a[47..40], b[47..40], a[39..32], b[39..32]) @
        pmaddubsw_pair(a[31..24], b[31..24], a[23..16], b[23..16]) @
        pmaddubsw_pair(a[15..8], b[15..8], a[7..0], b[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PHSUBW xmm1, xmm2/m128
    5  => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        (b[111..96] - b[127..112]) @ (b[79..64] - b[95..80]) @
        (b[47..32] - b[63..48]) @ (b[15..0] - b[31..16]) @
        (a[111..96] - a[127..112]) @ (a[79..64] - a[95..80]) @
        (a[47..32] - a[63..48]) @ (a[15..0] - a[31..16]);
      write_xmm_legacy(xreg, r)
    },
    // PHSUBD xmm1, xmm2/m128
    6  => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        (b[95..64] - b[127..96]) @ (b[31..0] - b[63..32]) @
        (a[95..64] - a[127..96]) @ (a[31..0] - a[63..32]);
      write_xmm_legacy(xreg, r)
    },
    // PHSUBSW xmm1, xmm2/m128
    7  => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        sat_sub_s(b[111..96], b[127..112]) @ sat_sub_s(b[79..64], b[95..80]) @
        sat_sub_s(b[47..32], b[63..48]) @ sat_sub_s(b[15..0], b[31..16]) @
        sat_sub_s(a[111..96], a[127..112]) @ sat_sub_s(a[79..64], a[95..80]) @
        sat_sub_s(a[47..32], a[63..48]) @ sat_sub_s(a[15..0], a[31..16]);
      write_xmm_legacy(xreg, r)
    },
    // PSIGNB xmm1, xmm2/m128
    8  => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        psign(a[127..120], b[127..120]) @ psign(a[119..112], b[119..112]) @
        psign(a[111..104], b[111..104]) @ psign(a[103..96], b[103..96]) @
        psign(a[95..88], b[95..88]) @ psign(a[87..80], b[87..80]) @
        psign(a[79..72], b[79..72]) @ psign(a[71..64], b[71..64]) @
        psign(a[63..56], b[63..56]) @ psign(a[55..48], b[55..48]) @
        psign(a[47..40], b[47..40]) @ psign(a[39..32], b[39..32]) @
        psign(a[31..24], b[31..24]) @ psign(a[23..16], b[23..16]) @
        psign(a[15..8], b[15..8]) @ psign(a[7..0], b[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PSIGNW xmm1, xmm2/m128
    9  => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        psign(a[127..112], b[127..112]) @ psign(a[111..96], b[111..96]) @
        psign(a[95..80], b[95..80]) @ psign(a[79..64], b[79..64]) @
        psign(a[63..48], b[63..48]) @ psign(a[47..32], b[47..32]) @
        psign(a[31..16], b[31..16]) @ psign(a[15..0], b[15..0]);
      write_xmm_legacy(xreg, r)
    },
    // PSIGND xmm1, xmm2/m128
    10 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        psign(a[127..96], b[127..96]) @ psign(a[95..64], b[95..64]) @
        psign(a[63..32], b[63..32]) @ psign(a[31..0], b[31..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMULHRSW xmm1, xmm2/m128
    11 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        mulhrsw(a[127..112], b[127..112]) @ mulhrsw(a[111..96], b[111..96]) @
        mulhrsw(a[95..80], b[95..80]) @ mulhrsw(a[79..64], b[79..64]) @
        mulhrsw(a[63..48], b[63..48]) @ mulhrsw(a[47..32], b[47..32]) @
        mulhrsw(a[31..16], b[31..16]) @ mulhrsw(a[15..0], b[15..0]);
      write_xmm_legacy(xreg, r)
    },

    // SSE4.1 — PBLENDVB (implicit XMM0 mask)
    16 => {
      let a : xmmword = read_xmm(xreg);
      let m : xmmword = read_xmm(0);
      let r0  : byte = blend(a[7..0],     src_xmm[7..0],     m[7]);
      let r1  : byte = blend(a[15..8],    src_xmm[15..8],    m[15]);
      let r2  : byte = blend(a[23..16],   src_xmm[23..16],   m[23]);
      let r3  : byte = blend(a[31..24],   src_xmm[31..24],   m[31]);
      let r4  : byte = blend(a[39..32],   src_xmm[39..32],   m[39]);
      let r5  : byte = blend(a[47..40],   src_xmm[47..40],   m[47]);
      let r6  : byte = blend(a[55..48],   src_xmm[55..48],   m[55]);
      let r7  : byte = blend(a[63..56],   src_xmm[63..56],   m[63]);
      let r8  : byte = blend(a[71..64],   src_xmm[71..64],   m[71]);
      let r9  : byte = blend(a[79..72],   src_xmm[79..72],   m[79]);
      let r10 : byte = blend(a[87..80],   src_xmm[87..80],   m[87]);
      let r11 : byte = blend(a[95..88],   src_xmm[95..88],   m[95]);
      let r12 : byte = blend(a[103..96],  src_xmm[103..96],  m[103]);
      let r13 : byte = blend(a[111..104], src_xmm[111..104], m[111]);
      let r14 : byte = blend(a[119..112], src_xmm[119..112], m[119]);
      let r15 : byte = blend(a[127..120], src_xmm[127..120], m[127]);
      write_xmm_legacy(xreg, r15 @ r14 @ r13 @ r12 @ r11 @ r10 @ r9 @ r8 @ r7 @ r6 @ r5 @ r4 @ r3 @ r2 @ r1 @ r0)
    },

    // SSE4.1 — PTEST
    23 => {
      let a : xmmword = read_xmm(xreg);
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

    // SSSE3 — PABSB
    28 => {
      let b : xmmword = src_xmm;
      let r : xmmword =
        abs(b[127..120]) @ abs(b[119..112]) @
        abs(b[111..104]) @ abs(b[103..96]) @
        abs(b[95..88]) @ abs(b[87..80]) @
        abs(b[79..72]) @ abs(b[71..64]) @
        abs(b[63..56]) @ abs(b[55..48]) @
        abs(b[47..40]) @ abs(b[39..32]) @
        abs(b[31..24]) @ abs(b[23..16]) @
        abs(b[15..8]) @ abs(b[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PABSW xmm1, xmm2/m128
    29 => {
      let b : xmmword = src_xmm;
      let r : xmmword =
        abs(b[127..112]) @ abs(b[111..96]) @
        abs(b[95..80]) @ abs(b[79..64]) @
        abs(b[63..48]) @ abs(b[47..32]) @
        abs(b[31..16]) @ abs(b[15..0]);
      write_xmm_legacy(xreg, r)
    },
    // PABSD xmm1, xmm2/m128
    30 => {
      let b : xmmword = src_xmm;
      let r : xmmword =
        abs(b[127..96]) @ abs(b[95..64]) @
        abs(b[63..32]) @ abs(b[31..0]);
      write_xmm_legacy(xreg, r)
    },

    // SSE4.1 — PMOVSXBW
    32 => {
      let s : xmmword = src_xmm;
      let r : xmmword =
        sign_extend(16, s[63..56]) @ sign_extend(16, s[55..48]) @
        sign_extend(16, s[47..40]) @ sign_extend(16, s[39..32]) @
        sign_extend(16, s[31..24]) @ sign_extend(16, s[23..16]) @
        sign_extend(16, s[15..8])  @ sign_extend(16, s[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMOVSXBD xmm1, xmm2/m32
    33 => {
      let s : xmmword = src_xmm;
      let r : xmmword =
        sign_extend(32, s[31..24]) @ sign_extend(32, s[23..16]) @
        sign_extend(32, s[15..8])  @ sign_extend(32, s[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMOVSXBQ xmm1, xmm2/m16
    34 => {
      let s : xmmword = src_xmm;
      let hi : qword = sign_extend(s[15..8]);
      let lo : qword = sign_extend(s[7..0]);
      write_xmm_legacy(xreg, hi @ lo)
    },
    // PMOVSXWD xmm1, xmm2/m64
    35 => {
      let s : xmmword = src_xmm;
      let r : xmmword =
        sign_extend(32, s[63..48]) @ sign_extend(32, s[47..32]) @
        sign_extend(32, s[31..16]) @ sign_extend(32, s[15..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMOVSXWQ xmm1, xmm2/m32
    36 => {
      let s : xmmword = src_xmm;
      let hi : qword = sign_extend(s[31..16]);
      let lo : qword = sign_extend(s[15..0]);
      write_xmm_legacy(xreg, hi @ lo)
    },
    // PMOVSXDQ xmm1, xmm2/m64
    37 => {
      let s : xmmword = src_xmm;
      let hi : qword = sign_extend(s[63..32]);
      let lo : qword = sign_extend(s[31..0]);
      write_xmm_legacy(xreg, hi @ lo)
    },

    // SSE4.1 — PMULDQ
    40 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let hi : qword = to_bits_truncate(signed(a[95..64]) * signed(b[95..64]));
      let lo : qword = to_bits_truncate(signed(a[31..0]) * signed(b[31..0]));
      let r : xmmword = hi @ lo;
      write_xmm_legacy(xreg, r)
    },
    // PCMPEQQ xmm1, xmm2/m128
    41 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword = cmp_eq(a[127..64], b[127..64]) @ cmp_eq(a[63..0], b[63..0]);
      write_xmm_legacy(xreg, r)
    },
    // MOVNTDQA xmm, m128
    42 => {
      write_xmm_legacy(xreg, rm_mem(src))
    },
    // PACKUSDW xmm1, xmm2/m128
    43 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let w0 : word = sat_su16(a[31..0]);
      let w1 : word = sat_su16(a[63..32]);
      let w2 : word = sat_su16(a[95..64]);
      let w3 : word = sat_su16(a[127..96]);
      let w4 : word = sat_su16(b[31..0]);
      let w5 : word = sat_su16(b[63..32]);
      let w6 : word = sat_su16(b[95..64]);
      let w7 : word = sat_su16(b[127..96]);
      write_xmm_legacy(xreg, w7 @ w6 @ w5 @ w4 @ w3 @ w2 @ w1 @ w0)
    },

    // SSE4.1 — PMOVZXBW
    48 => {
      let s : xmmword = src_xmm;
      let r : xmmword =
        zero_extend(16, s[63..56]) @ zero_extend(16, s[55..48]) @
        zero_extend(16, s[47..40]) @ zero_extend(16, s[39..32]) @
        zero_extend(16, s[31..24]) @ zero_extend(16, s[23..16]) @
        zero_extend(16, s[15..8])  @ zero_extend(16, s[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMOVZXBD xmm1, xmm2/m32
    49 => {
      let s : xmmword = src_xmm;
      let r : xmmword =
        zero_extend(32, s[31..24]) @ zero_extend(32, s[23..16]) @
        zero_extend(32, s[15..8])  @ zero_extend(32, s[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMOVZXBQ xmm1, xmm2/m16
    50 => {
      let s : xmmword = src_xmm;
      let hi : qword = zero_extend(s[15..8]);
      let lo : qword = zero_extend(s[7..0]);
      write_xmm_legacy(xreg, hi @ lo)
    },
    // PMOVZXWD xmm1, xmm2/m64
    51 => {
      let s : xmmword = src_xmm;
      let r : xmmword =
        zero_extend(32, s[63..48]) @ zero_extend(32, s[47..32]) @
        zero_extend(32, s[31..16]) @ zero_extend(32, s[15..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMOVZXWQ xmm1, xmm2/m32
    52 => {
      let s : xmmword = src_xmm;
      let hi : qword = zero_extend(s[31..16]);
      let lo : qword = zero_extend(s[15..0]);
      write_xmm_legacy(xreg, hi @ lo)
    },
    // PMOVZXDQ xmm1, xmm2/m64
    53 => {
      let s : xmmword = src_xmm;
      let hi : qword = zero_extend(s[63..32]);
      let lo : qword = zero_extend(s[31..0]);
      write_xmm_legacy(xreg, hi @ lo)
    },

    // SSE4.2 — PCMPGTQ
    55 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword = cmp_gt(a[127..64], b[127..64]) @ cmp_gt(a[63..0], b[63..0]);
      write_xmm_legacy(xreg, r)
    },

    // SSE4.1 — PMINSB
    56 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        min_s(a[127..120], b[127..120]) @ min_s(a[119..112], b[119..112]) @
        min_s(a[111..104], b[111..104]) @ min_s(a[103..96], b[103..96]) @
        min_s(a[95..88], b[95..88]) @ min_s(a[87..80], b[87..80]) @
        min_s(a[79..72], b[79..72]) @ min_s(a[71..64], b[71..64]) @
        min_s(a[63..56], b[63..56]) @ min_s(a[55..48], b[55..48]) @
        min_s(a[47..40], b[47..40]) @ min_s(a[39..32], b[39..32]) @
        min_s(a[31..24], b[31..24]) @ min_s(a[23..16], b[23..16]) @
        min_s(a[15..8], b[15..8]) @ min_s(a[7..0], b[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMINSD xmm1, xmm2/m128
    57 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        min_s(a[127..96], b[127..96]) @ min_s(a[95..64], b[95..64]) @
        min_s(a[63..32], b[63..32]) @ min_s(a[31..0], b[31..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMINUW xmm1, xmm2/m128
    58 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        min_u(a[127..112], b[127..112]) @ min_u(a[111..96], b[111..96]) @
        min_u(a[95..80], b[95..80]) @ min_u(a[79..64], b[79..64]) @
        min_u(a[63..48], b[63..48]) @ min_u(a[47..32], b[47..32]) @
        min_u(a[31..16], b[31..16]) @ min_u(a[15..0], b[15..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMINUD xmm1, xmm2/m128
    59 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        min_u(a[127..96], b[127..96]) @ min_u(a[95..64], b[95..64]) @
        min_u(a[63..32], b[63..32]) @ min_u(a[31..0], b[31..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMAXSB xmm1, xmm2/m128
    60 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        max_s(a[127..120], b[127..120]) @ max_s(a[119..112], b[119..112]) @
        max_s(a[111..104], b[111..104]) @ max_s(a[103..96], b[103..96]) @
        max_s(a[95..88], b[95..88]) @ max_s(a[87..80], b[87..80]) @
        max_s(a[79..72], b[79..72]) @ max_s(a[71..64], b[71..64]) @
        max_s(a[63..56], b[63..56]) @ max_s(a[55..48], b[55..48]) @
        max_s(a[47..40], b[47..40]) @ max_s(a[39..32], b[39..32]) @
        max_s(a[31..24], b[31..24]) @ max_s(a[23..16], b[23..16]) @
        max_s(a[15..8], b[15..8]) @ max_s(a[7..0], b[7..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMAXSD xmm1, xmm2/m128
    61 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        max_s(a[127..96], b[127..96]) @ max_s(a[95..64], b[95..64]) @
        max_s(a[63..32], b[63..32]) @ max_s(a[31..0], b[31..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMAXUW xmm1, xmm2/m128
    62 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        max_u(a[127..112], b[127..112]) @ max_u(a[111..96], b[111..96]) @
        max_u(a[95..80], b[95..80]) @ max_u(a[79..64], b[79..64]) @
        max_u(a[63..48], b[63..48]) @ max_u(a[47..32], b[47..32]) @
        max_u(a[31..16], b[31..16]) @ max_u(a[15..0], b[15..0]);
      write_xmm_legacy(xreg, r)
    },
    // PMAXUD xmm1, xmm2/m128
    63 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        max_u(a[127..96], b[127..96]) @ max_u(a[95..64], b[95..64]) @
        max_u(a[63..32], b[63..32]) @ max_u(a[31..0], b[31..0]);
      write_xmm_legacy(xreg, r)
    },

    // SSE4.1 — PMULLD
    64 => {
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let r : xmmword =
        mul_lo(a[127..96], b[127..96]) @ mul_lo(a[95..64], b[95..64]) @
        mul_lo(a[63..32], b[63..32]) @ mul_lo(a[31..0], b[31..0]);
      write_xmm_legacy(xreg, r)
    },
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

      write_xmm_legacy(xreg, zeros(96) @ mi @ mv)
    },

    // AES-NI — AESIMC
    219 => {
      if ~(has_aesni) then raise_UD();
      let s : xmmword = src_xmm;
      write_xmm_legacy(xreg, __aesimc(s))
    },
    // AES-NI — AESENC
    220 => {
      if ~(has_aesni) then raise_UD();
      let state : xmmword = read_xmm(xreg);
      let roundkey : xmmword = src_xmm;
      write_xmm_legacy(xreg, __aesenc(state, roundkey))
    },
    // AES-NI — AESENCLAST (0F 38 DD)
    221 => {
      if ~(has_aesni) then raise_UD();
      let state : xmmword = read_xmm(xreg);
      let roundkey : xmmword = src_xmm;
      write_xmm_legacy(xreg, __aesenclast(state, roundkey))
    },
    // AES-NI — AESDEC (0F 38 DE)
    222 => {
      if ~(has_aesni) then raise_UD();
      let state : xmmword = read_xmm(xreg);
      let roundkey : xmmword = src_xmm;
      write_xmm_legacy(xreg, __aesdec(state, roundkey))
    },
    // AES-NI — AESDECLAST
    223 => {
      if ~(has_aesni) then raise_UD();
      let state : xmmword = read_xmm(xreg);
      let roundkey : xmmword = src_xmm;
      write_xmm_legacy(xreg, __aesdeclast(state, roundkey))
    },

    // GFNI — GF2P8MULB (66 0F 38 CF)
    207 => {
      write_xmm_legacy(xreg, __gf2p8mulb(read_xmm(xreg), src_xmm))
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
  let modrm = fetch_byte();
  let xreg = modrm_xmm_reg(modrm, pfx);
  let src = modrm_rm(modrm, pfx);
  match op {

    // SSE4.1 — PBLENDW
    14 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      write_xmm_legacy(xreg,
        blend(a[127..112], b[127..112], imm[7]) @
        blend(a[111..96],  b[111..96],  imm[6]) @
        blend(a[95..80],   b[95..80],   imm[5]) @
        blend(a[79..64],   b[79..64],   imm[4]) @
        blend(a[63..48],   b[63..48],   imm[3]) @
        blend(a[47..32],   b[47..32],   imm[2]) @
        blend(a[31..16],   b[31..16],   imm[1]) @
        blend(a[15..0],    b[15..0],    imm[0]))
    },

    // SSSE3 — PALIGNR
    15 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch_byte();
      let d : xmmword = read_xmm(xreg);
      let s : xmmword = src_xmm;
      let concat : ymmword = d @ s;
      let shift_bytes : range(0, 255) = unsigned(imm);
      let r : xmmword = (concat >> (shift_bytes * 8))[127..0];
      write_xmm_legacy(xreg, r)
    },

    // SSE4.1 — PEXTRB r/m8, xmm, imm8
    20 => {
      let imm = fetch_byte();
      let x = extract_byte_from_xmm(read_xmm(xreg), imm);
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
      let imm = fetch_byte();
      let xmm_src = read_xmm(xreg);
      match (src, pfx.rex_w) {
        (RM_reg(_), true)     => v(modrm_rm_reg(modrm, pfx)) = extract_qword_from_xmm(xmm_src, imm),
        (RM_reg(_), false)    => v(modrm_rm_reg(modrm, pfx)) = extract_dword_from_xmm(xmm_src, imm),
        (RM_mem(m), true)  => v(m) = extract_qword_from_xmm(xmm_src, imm),
        (RM_mem(m), false) => v(m) = extract_dword_from_xmm(xmm_src, imm),
      }
    },

    // SSE4.1 — PINSRB xmm, r/m8, imm8
    32 => {
      let imm = fetch_byte();
      let v : byte = match src {
        RM_reg(r) => v(r),
        RM_mem(m) => read_mem(m),
      };
      let v_0 : xmmword = read_xmm(xreg);
      let sel : range(0, 15) = unsigned(imm[3..0]);
      let r : xmmword = insert_byte(v_0, v, sel);
      write_xmm_legacy(xreg, r)
    },

    // SSE4.1 — PINSRD/PINSRQ xmm, r/m, imm8
    34 => {
      let imm = fetch_byte();
      if pfx.rex_w then {
        let v : qword = v(src);
        let v_0 : xmmword = read_xmm(xreg);
        let sel : range(0, 1) = unsigned(imm[0]);
        let r : xmmword = match sel {
          0 => v_0[127..64] @ v,
          1 => v @ v_0[63..0]
        };
        write_xmm_legacy(xreg, r)
      } else {
        let v : dword = v(src);
        let v_0 : xmmword = read_xmm(xreg);
        let sel : range(0, 3) = unsigned(imm[1..0]);
        let r : xmmword = insert_dword(v_0, v, sel);
        write_xmm_legacy(xreg, r)
      }
    },

    // SSE4.1 — MPSADBW
    66 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      write_xmm_legacy(xreg, mpsadbw(a, b, imm))
    },

    // PCLMULQDQ xmm1, xmm2/m128, imm8
    68 => {
      if ~(has_pclmulqdq) then raise_UD();
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let sel_a : qword = blend(a[63..0], a[127..64], imm[0]);
      let sel_b : qword = blend(b[63..0], b[127..64], imm[4]);
      write_xmm_legacy(xreg, pclmulqdq(sel_a, sel_b))
    },

    // SSE4.2 — PCMPESTRM
    96 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let la : dword = v(RAX);
      let lb : dword = v(RDX);
      let (mask, cf_val, zf_val, sf_val, of_val) = pcmpestrm(a, la, b, lb, imm);
      write_xmm_legacy(0, mask);
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
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
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
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
      let b : xmmword = src_xmm;
      let (mask, cf_val, zf_val, sf_val, of_val) = pcmpistrm(a, b, imm);
      write_xmm_legacy(0, mask);
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
      let imm = fetch_byte();
      let a : xmmword = read_xmm(xreg);
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
      let imm = fetch_byte();
      let s : xmmword = src_xmm;
      write_xmm_legacy(xreg, __aeskeygenassist(s, imm))
    },

    // GFNI — GF2P8AFFINEQB (66 0F 3A CE)
    206 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch_byte();
      write_xmm_legacy(xreg, __gf2p8affineqb(read_xmm(xreg), src_xmm, imm))
    },

    // GFNI — GF2P8AFFINEINVQB (66 0F 3A CF)
    207 => {
      let src_xmm = decode_xmm_src(modrm, src, pfx);
      let imm = fetch_byte();
      write_xmm_legacy(xreg, __gf2p8affineinvqb(read_xmm(xreg), src_xmm, imm))
    },

    _ => raise_UD(),
  }
}

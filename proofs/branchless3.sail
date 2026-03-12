// Proof of equivalence between branching and branchless helpers (batch 3).
//
// Covers: popcnt, abs, psign, sat_add/sub (signed/unsigned),
//         pack with saturation (sat_s16_to_s8, sat_s32_to_s16,
//         sat_s16_to_u8, sat_s32_to_u16).
//
// Run:
//   sail --smt --smt-auto --smt-auto-solver z3 proofs/branchless3.sail

$include "../model/prelude.sail"

// ================================================================
// Helper: or_reduce (needed for pack saturation proofs)
// ================================================================

val or_reduce_8 : bits(8) -> bits(1)
function or_reduce_8(v) = {
  let r4 : bits(4) = v[7..4] | v[3..0];
  let r2 : bits(2) = r4[3..2] | r4[1..0];
  r2[1..1] | r2[0..0]
}

val or_reduce_16 : bits(16) -> bits(1)
function or_reduce_16(v) = or_reduce_8(v[15..8] | v[7..0])

// ================================================================
// POPCNT: Hacker's Delight population count
// ================================================================

$property
function prop_popcnt8(v: bits(8)) -> bool = {
  // Original: loop counting set bits
  var count : int = 0;
  foreach (i from 0 to 7) { if v[i] == bitone then count = count + 1 };
  let orig : bits(8) = get_slice_int(8, count, 0);
  // Branchless: Hacker's Delight
  var x : bits(8) = v;
  x = x - ((x >> 1) & 0x55);
  x = (x & 0x33) + ((x >> 2) & 0x33);
  x = (x + (x >> 4)) & 0x0F;
  orig == x
}

$property
function prop_popcnt16(v: bits(16)) -> bool = {
  var count : int = 0;
  foreach (i from 0 to 15) { if v[i] == bitone then count = count + 1 };
  let orig : bits(16) = get_slice_int(16, count, 0);
  var x : bits(16) = v;
  x = x - ((x >> 1) & 0x5555);
  x = (x & 0x3333) + ((x >> 2) & 0x3333);
  x = (x + (x >> 4)) & 0x0F0F;
  x = x + (x >> 8);
  x = x & 0x001F;
  orig == x
}

$property
function prop_popcnt32(v: bits(32)) -> bool = {
  var count : int = 0;
  foreach (i from 0 to 31) { if v[i] == bitone then count = count + 1 };
  let orig : bits(32) = get_slice_int(32, count, 0);
  var x : bits(32) = v;
  x = x - ((x >> 1) & 0x55555555);
  x = (x & 0x33333333) + ((x >> 2) & 0x33333333);
  x = (x + (x >> 4)) & 0x0F0F0F0F;
  x = x + (x >> 8);
  x = x + (x >> 16);
  x = x & 0x0000003F;
  orig == x
}

$property
function prop_popcnt64(v: bits(64)) -> bool = {
  var count : int = 0;
  foreach (i from 0 to 63) { if v[i] == bitone then count = count + 1 };
  let orig : bits(64) = get_slice_int(64, count, 0);
  var x : bits(64) = v;
  x = x - ((x >> 1) & 0x5555555555555555);
  x = (x & 0x3333333333333333) + ((x >> 2) & 0x3333333333333333);
  x = (x + (x >> 4)) & 0x0F0F0F0F0F0F0F0F;
  x = x + (x >> 8);
  x = x + (x >> 16);
  x = x + (x >> 32);
  x = x & 0x000000000000007F;
  orig == x
}

// ================================================================
// ABS: branchless absolute value
// mask = sign-extend of MSB; (x ^ mask) - mask
// ================================================================

$property
function prop_abs8(x: bits(8)) -> bool = {
  let orig : bits(8) = if x[7] == bitone then (0x00 - x) else x;
  let mask : bits(8) = sign_extend(x[7..7]);
  let branchless : bits(8) = (x ^ mask) - mask;
  orig == branchless
}

$property
function prop_abs16(x: bits(16)) -> bool = {
  let orig : bits(16) = if x[15] == bitone then (0x0000 - x) else x;
  let mask : bits(16) = sign_extend(x[15..15]);
  let branchless : bits(16) = (x ^ mask) - mask;
  orig == branchless
}

$property
function prop_abs32(x: bits(32)) -> bool = {
  let orig : bits(32) = if x[31] == bitone then (0x00000000 - x) else x;
  let mask : bits(32) = sign_extend(x[31..31]);
  let branchless : bits(32) = (x ^ mask) - mask;
  orig == branchless
}

// ================================================================
// PSIGN: if b<0 then -a; if b==0 then 0; else a
// neg_mask = sign-extend(b[MSB])  → all-1s if b < 0
// nonzero  = all-1s if b != 0 (via borrow trick)
// result   = ((a ^ neg_mask) - neg_mask) & nonzero
// ================================================================

$property
function prop_psign8(a: bits(8), b: bits(8)) -> bool = {
  let orig : bits(8) =
    if signed(b) < 0 then (0x00 - a)
    else if b == sail_zeros(8) then sail_zeros(8)
    else a;
  let neg_mask : bits(8) = sign_extend(b[7..7]);
  let borrow : bits(9) = (0b0 @ b) - 0b000000001;
  let nonzero : bits(8) = sign_extend(~(borrow[8..8]));
  let branchless : bits(8) = ((a ^ neg_mask) - neg_mask) & nonzero;
  orig == branchless
}

$property
function prop_psign16(a: bits(16), b: bits(16)) -> bool = {
  let orig : bits(16) =
    if signed(b) < 0 then (0x0000 - a)
    else if b == sail_zeros(16) then sail_zeros(16)
    else a;
  let neg_mask : bits(16) = sign_extend(b[15..15]);
  let borrow : bits(17) = (0b0 @ b) - sail_zero_extend(0b1, 17);
  let nonzero : bits(16) = sign_extend(~(borrow[16..16]));
  let branchless : bits(16) = ((a ^ neg_mask) - neg_mask) & nonzero;
  orig == branchless
}

$property
function prop_psign32(a: bits(32), b: bits(32)) -> bool = {
  let orig : bits(32) =
    if signed(b) < 0 then (0x00000000 - a)
    else if b == sail_zeros(32) then sail_zeros(32)
    else a;
  let neg_mask : bits(32) = sign_extend(b[31..31]);
  let borrow : bits(33) = (0b0 @ b) - sail_zero_extend(0b1, 33);
  let nonzero : bits(32) = sign_extend(~(borrow[32..32]));
  let branchless : bits(32) = ((a ^ neg_mask) - neg_mask) & nonzero;
  orig == branchless
}

// ================================================================
// SAT_ADD_U: min(a + b, MAX) for unsigned
// ================================================================

$property
function prop_sat_add_u8(a: bits(8), b: bits(8)) -> bool = {
  let sum : int = unsigned(a) + unsigned(b);
  let orig : bits(8) = get_slice_int(8, if sum > 255 then 255 else sum, 0);
  let wide : bits(9) = (0b0 @ a) + (0b0 @ b);
  let sat : bits(8) = sign_extend(wide[8..8]);
  let branchless : bits(8) = wide[7..0] | sat;
  orig == branchless
}

$property
function prop_sat_add_u16(a: bits(16), b: bits(16)) -> bool = {
  let sum : int = unsigned(a) + unsigned(b);
  let orig : bits(16) = get_slice_int(16, if sum > 65535 then 65535 else sum, 0);
  let wide : bits(17) = (0b0 @ a) + (0b0 @ b);
  let sat : bits(16) = sign_extend(wide[16..16]);
  let branchless : bits(16) = wide[15..0] | sat;
  orig == branchless
}

// ================================================================
// SAT_SUB_U: max(a - b, 0) for unsigned
// ================================================================

$property
function prop_sat_sub_u8(a: bits(8), b: bits(8)) -> bool = {
  let diff : int = unsigned(a) - unsigned(b);
  let orig : bits(8) = get_slice_int(8, if diff < 0 then 0 else diff, 0);
  let wide : bits(9) = (0b0 @ a) - (0b0 @ b);
  let mask : bits(8) = sign_extend(~(wide[8..8]));
  let branchless : bits(8) = wide[7..0] & mask;
  orig == branchless
}

$property
function prop_sat_sub_u16(a: bits(16), b: bits(16)) -> bool = {
  let diff : int = unsigned(a) - unsigned(b);
  let orig : bits(16) = get_slice_int(16, if diff < 0 then 0 else diff, 0);
  let wide : bits(17) = (0b0 @ a) - (0b0 @ b);
  let mask : bits(16) = sign_extend(~(wide[16..16]));
  let branchless : bits(16) = wide[15..0] & mask;
  orig == branchless
}

// ================================================================
// SAT_ADD_S: clamp(a + b, MIN, MAX) for signed
// ================================================================

$property
function prop_sat_add_s8(a: bits(8), b: bits(8)) -> bool = {
  let sum : int = signed(a) + signed(b);
  let clamped : int = if sum < -128 then -128 else if sum > 127 then 127 else sum;
  let orig : bits(8) = get_slice_int(8, clamped, 0);
  let wide : bits(9) = sign_extend(a) + sign_extend(b);
  let ov : bits(1) = ~(wide[8..8]) & wide[7..7];
  let uf : bits(1) = wide[8..8] & ~(wide[7..7]);
  let ov_mask : bits(8) = sign_extend(ov);
  let uf_mask : bits(8) = sign_extend(uf);
  let branchless : bits(8) = (0x7F & ov_mask) | (0x80 & uf_mask) | (wide[7..0] & ~(ov_mask) & ~(uf_mask));
  orig == branchless
}

$property
function prop_sat_add_s16(a: bits(16), b: bits(16)) -> bool = {
  let sum : int = signed(a) + signed(b);
  let clamped : int = if sum < -32768 then -32768 else if sum > 32767 then 32767 else sum;
  let orig : bits(16) = get_slice_int(16, clamped, 0);
  let wide : bits(17) = sign_extend(a) + sign_extend(b);
  let ov : bits(1) = ~(wide[16..16]) & wide[15..15];
  let uf : bits(1) = wide[16..16] & ~(wide[15..15]);
  let ov_mask : bits(16) = sign_extend(ov);
  let uf_mask : bits(16) = sign_extend(uf);
  let branchless : bits(16) = (0x7FFF & ov_mask) | (0x8000 & uf_mask) | (wide[15..0] & ~(ov_mask) & ~(uf_mask));
  orig == branchless
}

// ================================================================
// SAT_SUB_S: clamp(a - b, MIN, MAX) for signed
// ================================================================

$property
function prop_sat_sub_s8(a: bits(8), b: bits(8)) -> bool = {
  let diff : int = signed(a) - signed(b);
  let clamped : int = if diff < -128 then -128 else if diff > 127 then 127 else diff;
  let orig : bits(8) = get_slice_int(8, clamped, 0);
  let wide : bits(9) = sign_extend(a) - sign_extend(b);
  let ov : bits(1) = ~(wide[8..8]) & wide[7..7];
  let uf : bits(1) = wide[8..8] & ~(wide[7..7]);
  let ov_mask : bits(8) = sign_extend(ov);
  let uf_mask : bits(8) = sign_extend(uf);
  let branchless : bits(8) = (0x7F & ov_mask) | (0x80 & uf_mask) | (wide[7..0] & ~(ov_mask) & ~(uf_mask));
  orig == branchless
}

$property
function prop_sat_sub_s16(a: bits(16), b: bits(16)) -> bool = {
  let diff : int = signed(a) - signed(b);
  let clamped : int = if diff < -32768 then -32768 else if diff > 32767 then 32767 else diff;
  let orig : bits(16) = get_slice_int(16, clamped, 0);
  let wide : bits(17) = sign_extend(a) - sign_extend(b);
  let ov : bits(1) = ~(wide[16..16]) & wide[15..15];
  let uf : bits(1) = wide[16..16] & ~(wide[15..15]);
  let ov_mask : bits(16) = sign_extend(ov);
  let uf_mask : bits(16) = sign_extend(uf);
  let branchless : bits(16) = (0x7FFF & ov_mask) | (0x8000 & uf_mask) | (wide[15..0] & ~(ov_mask) & ~(uf_mask));
  orig == branchless
}

// ================================================================
// SAT_S16_TO_U8: clamp signed 16-bit to unsigned 8-bit [0, 255]
// ================================================================

$property
function prop_sat_s16_to_u8(x: bits(16)) -> bool = {
  let v = signed(x);
  let orig : bits(8) = if v > 255 then 0xFF else if v < 0 then 0x00 else x[7..0];
  let neg_mask : bits(16) = sign_extend(x[15..15]);
  let pos_val : bits(16) = x & ~(neg_mask);
  let overflow : bits(1) = or_reduce_8(pos_val[15..8]);
  let over_mask : bits(8) = sign_extend(overflow);
  let branchless : bits(8) = pos_val[7..0] | over_mask;
  orig == branchless
}

// ================================================================
// SAT_S32_TO_U16: clamp signed 32-bit to unsigned 16-bit [0, 65535]
// ================================================================

$property
function prop_sat_s32_to_u16(x: bits(32)) -> bool = {
  let v : int = signed(x);
  let orig : bits(16) = if v < 0 then 0x0000 else if v > 65535 then 0xFFFF else x[15..0];
  let neg_mask : bits(32) = sign_extend(x[31..31]);
  let pos_val : bits(32) = x & ~(neg_mask);
  let overflow : bits(1) = or_reduce_16(pos_val[31..16]);
  let over_mask : bits(16) = sign_extend(overflow);
  let branchless : bits(16) = pos_val[15..0] | over_mask;
  orig == branchless
}

// ================================================================
// SAT_S16_TO_S8: clamp signed 16-bit to signed 8-bit [-128, 127]
// ================================================================

$property
function prop_sat_s16_to_s8(x: bits(16)) -> bool = {
  let v = signed(x);
  let orig : bits(8) = if v > 127 then 0x7F else if v < -128 then 0x80 else x[7..0];
  // Branchless: check if bits [14..7] match sign bit
  let sign : bits(1) = x[15..15];
  let diff : bits(8) = x[14..7] ^ sign_extend(sign);
  let out_of_range : bits(1) = or_reduce_8(diff);
  let out_mask : bits(8) = sign_extend(out_of_range);
  // clamp_val: 0x7F if positive overflow, 0x80 if negative overflow
  let clamp_val : bits(8) = sign_extend(sign) ^ 0x7F;
  let branchless : bits(8) = (clamp_val & out_mask) | (x[7..0] & ~(out_mask));
  orig == branchless
}

// ================================================================
// PSHUFB: byte shuffle with zero-mask
// Branchless: shift right by idx*8, take low byte, AND with ~mask[7] mask
// ================================================================

$property
function prop_pshufb_byte(data: bits(128), mask: bits(8)) -> bool = {
  let orig : bits(8) =
    if mask[7] == bitone then 0x00
    else {
      let idx : range(0, 15) = unsigned(mask[3..0]);
      match idx {
        0  => data[7..0],    1  => data[15..8],
        2  => data[23..16],  3  => data[31..24],
        4  => data[39..32],  5  => data[47..40],
        6  => data[55..48],  7  => data[63..56],
        8  => data[71..64],  9  => data[79..72],
        10 => data[87..80],  11 => data[95..88],
        12 => data[103..96], 13 => data[111..104],
        14 => data[119..112],15 => data[127..120]
      }
    };
  let idx : range(0, 15) = unsigned(mask[3..0]);
  let selected : bits(8) = (data >> (idx * 8))[7..0];
  let branchless : bits(8) = selected & sign_extend(~(mask[7..7]));
  orig == branchless
}

// ================================================================
// BLEND: select element from a or b based on imm bit
// Branchless: (a & ~mask) | (b & mask) where mask = sign_extend(imm_bit)
// ================================================================

$property
function prop_blend32(a: bits(32), b: bits(32), sel: bits(1)) -> bool = {
  let orig : bits(32) = if sel == 0b1 then b else a;
  let m : bits(32) = sign_extend(sel);
  let branchless : bits(32) = (a & ~(m)) | (b & m);
  orig == branchless
}

$property
function prop_blend64(a: bits(64), b: bits(64), sel: bits(1)) -> bool = {
  let orig : bits(64) = if sel == 0b1 then b else a;
  let m : bits(64) = sign_extend(sel);
  let branchless : bits(64) = (a & ~(m)) | (b & m);
  orig == branchless
}

$property
function prop_blend16(a: bits(16), b: bits(16), sel: bits(1)) -> bool = {
  let orig : bits(16) = if sel == 0b1 then b else a;
  let m : bits(16) = sign_extend(sel);
  let branchless : bits(16) = (a & ~(m)) | (b & m);
  orig == branchless
}

// ================================================================
// SAT_S32_TO_S16: clamp signed 32-bit to signed 16-bit [-32768, 32767]
// ================================================================

$property
function prop_sat_s32_to_s16(x: bits(32)) -> bool = {
  let v = signed(x);
  let orig : bits(16) = if v > 32767 then 0x7FFF else if v < -32768 then 0x8000 else x[15..0];
  let sign : bits(1) = x[31..31];
  let diff : bits(16) = x[30..15] ^ sign_extend(sign);
  let out_of_range : bits(1) = or_reduce_16(diff);
  let out_mask : bits(16) = sign_extend(out_of_range);
  let clamp_val : bits(16) = sign_extend(sign) ^ 0x7FFF;
  let branchless : bits(16) = (clamp_val & out_mask) | (x[15..0] & ~(out_mask));
  orig == branchless
}

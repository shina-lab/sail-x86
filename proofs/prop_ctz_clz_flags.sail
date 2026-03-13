// Equivalence proofs: TZCNT/LZCNT/POPCNT flag computations
// Replace bool_to_bit(count == 0) and bool_to_bit(count == N) with
// direct bitvector checks on the source operand.

$include "../model/prelude.sail"

// --- popcount ---
val popcount8 : bits(8) -> range(0, 8)
function popcount8(v) =
  unsigned(v[0..0]) + unsigned(v[1..1]) + unsigned(v[2..2]) + unsigned(v[3..3]) +
  unsigned(v[4..4]) + unsigned(v[5..5]) + unsigned(v[6..6]) + unsigned(v[7..7])

val popcount16 : bits(16) -> range(0, 16)
function popcount16(v) = popcount8(v[7..0]) + popcount8(v[15..8])

val popcount32 : bits(32) -> range(0, 32)
function popcount32(v) = popcount16(v[15..0]) + popcount16(v[31..16])

val popcount64 : bits(64) -> range(0, 64)
function popcount64(v) = popcount32(v[31..0]) + popcount32(v[63..32])

// --- ctz ---
val ctz8 : bits(8) -> range(0, 8)
function ctz8(v) = popcount8(not_vec(v) & (v - 0x01))

val ctz16 : bits(16) -> range(0, 16)
function ctz16(v) = popcount16(not_vec(v) & (v - 0x0001))

val ctz32 : bits(32) -> range(0, 32)
function ctz32(v) = popcount32(not_vec(v) & (v - 0x00000001))

// --- clz ---
val clz8 : bits(8) -> range(0, 8)
function clz8(v) = {
  let x1 : bits(8) = v  | (v  >> 1);
  let x2 : bits(8) = x1 | (x1 >> 2);
  let x3 : bits(8) = x2 | (x2 >> 4);
  8 - popcount8(x3)
}

val clz16 : bits(16) -> range(0, 16)
function clz16(v) = {
  let x1 : bits(16) = v  | (v  >> 1);
  let x2 : bits(16) = x1 | (x1 >> 2);
  let x3 : bits(16) = x2 | (x2 >> 4);
  let x4 : bits(16) = x3 | (x3 >> 8);
  16 - popcount16(x4)
}

val clz32 : bits(32) -> range(0, 32)
function clz32(v) = {
  let x1 : bits(32) = v  | (v  >> 1);
  let x2 : bits(32) = x1 | (x1 >> 2);
  let x3 : bits(32) = x2 | (x2 >> 4);
  let x4 : bits(32) = x3 | (x3 >> 8);
  let x5 : bits(32) = x4 | (x4 >> 16);
  32 - popcount32(x5)
}

// --- or_reduce ---
val or_reduce_8 : bits(8) -> bits(1)
function or_reduce_8(v) = {
  let r4 : bits(4) = v[7..4] | v[3..0];
  let r2 : bits(2) = r4[3..2] | r4[1..0];
  r2[1..1] | r2[0..0]
}

val or_reduce_16 : bits(16) -> bits(1)
function or_reduce_16(v) = or_reduce_8(v[15..8] | v[7..0])

val or_reduce_32 : bits(32) -> bits(1)
function or_reduce_32(v) = or_reduce_16(v[31..16] | v[15..0])

// --- TZCNT proofs ---

// ctz(v) == 8 iff v == zeros (8-bit)
$property
function prop_tzcnt_cf_8(v : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(ctz8(v) == 8);
  let branchless : bit = (~(or_reduce_8(v)))[0];
  orig == branchless
}

// ctz(v) == 16 iff v == zeros (16-bit)
$property
function prop_tzcnt_cf_16(v : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(ctz16(v) == 16);
  let branchless : bit = (~(or_reduce_16(v)))[0];
  orig == branchless
}

// ctz(v) == 32 iff v == zeros (32-bit)
$property
function prop_tzcnt_cf_32(v : bits(32)) -> bool = {
  let orig : bit = bool_to_bit(ctz32(v) == 32);
  let branchless : bit = (~(or_reduce_32(v)))[0];
  orig == branchless
}

// ctz(v) == 0 iff v[0] is set (8-bit)
$property
function prop_tzcnt_zf_8(v : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(ctz8(v) == 0);
  let branchless : bit = v[0];
  orig == branchless
}

// ctz(v) == 0 iff v[0] is set (16-bit)
$property
function prop_tzcnt_zf_16(v : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(ctz16(v) == 0);
  let branchless : bit = v[0];
  orig == branchless
}

// ctz(v) == 0 iff v[0] is set (32-bit)
$property
function prop_tzcnt_zf_32(v : bits(32)) -> bool = {
  let orig : bit = bool_to_bit(ctz32(v) == 0);
  let branchless : bit = v[0];
  orig == branchless
}

// --- LZCNT proofs ---

// clz(v) == 8 iff v == zeros (8-bit)
$property
function prop_lzcnt_cf_8(v : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(clz8(v) == 8);
  let branchless : bit = (~(or_reduce_8(v)))[0];
  orig == branchless
}

// clz(v) == 16 iff v == zeros (16-bit)
$property
function prop_lzcnt_cf_16(v : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(clz16(v) == 16);
  let branchless : bit = (~(or_reduce_16(v)))[0];
  orig == branchless
}

// clz(v) == 32 iff v == zeros (32-bit)
$property
function prop_lzcnt_cf_32(v : bits(32)) -> bool = {
  let orig : bit = bool_to_bit(clz32(v) == 32);
  let branchless : bit = (~(or_reduce_32(v)))[0];
  orig == branchless
}

// clz(v) == 0 iff MSB is set (8-bit)
$property
function prop_lzcnt_zf_8(v : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(clz8(v) == 0);
  let branchless : bit = v[7];
  orig == branchless
}

// clz(v) == 0 iff MSB is set (16-bit)
$property
function prop_lzcnt_zf_16(v : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(clz16(v) == 0);
  let branchless : bit = v[15];
  orig == branchless
}

// clz(v) == 0 iff MSB is set (32-bit)
$property
function prop_lzcnt_zf_32(v : bits(32)) -> bool = {
  let orig : bit = bool_to_bit(clz32(v) == 0);
  let branchless : bit = v[31];
  orig == branchless
}

// --- POPCNT proofs ---

// popcount(v) == 0 iff v == zeros (8-bit)
$property
function prop_popcnt_zf_8(v : bits(8)) -> bool = {
  let orig : bit = bool_to_bit(popcount8(v) == 0);
  let branchless : bit = (~(or_reduce_8(v)))[0];
  orig == branchless
}

// popcount(v) == 0 iff v == zeros (16-bit)
$property
function prop_popcnt_zf_16(v : bits(16)) -> bool = {
  let orig : bit = bool_to_bit(popcount16(v) == 0);
  let branchless : bit = (~(or_reduce_16(v)))[0];
  orig == branchless
}

// popcount(v) == 0 iff v == zeros (32-bit)
$property
function prop_popcnt_zf_32(v : bits(32)) -> bool = {
  let orig : bit = bool_to_bit(popcount32(v) == 0);
  let branchless : bit = (~(or_reduce_32(v)))[0];
  orig == branchless
}

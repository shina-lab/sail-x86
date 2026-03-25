// Equivalence proof: pcmp_bit_index branchless rewrite
//
// LSB mode (find first set bit):
//   Old: linear scan with found flag
//   New: ctz(16, zero_extend(int_res2))
//        result is 16 when int_res2 == 0 (ctz of all-zeros = width)
//
// MSB mode (find last set bit):
//   Old: linear scan keeping last match
//   New: bsr(zero_extend(int_res2))
//        but bsr is undefined for zero, so handle with blend
//
// Zero case: both modes return ub+1. Since bits above ub are already
// zeroed, ctz returns 16 (>= ub+1) and bsr returns 0 (wrong).
// For MSB+zero: blend(bsr_result, ub+1, is_zero(int_res2)).

$include "../model/prelude.sail"

type qword = bits(64)

val popcount : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> range(0, 'n)
function popcount(v) = {
  let x1 : qword = zero_extend(v);
  let x2 = (x1 & 0x5555555555555555) + ((x1 >> 1) & 0x5555555555555555);
  let x3 = (x2 & 0x3333333333333333) + ((x2 >> 2) & 0x3333333333333333);
  let x4 = (x3 & 0x0f0f0f0f0f0f0f0f) + ((x3 >> 4) & 0x0f0f0f0f0f0f0f0f);
  let x5 = (x4 & 0x00ff00ff00ff00ff) + ((x4 >> 8) & 0x00ff00ff00ff00ff);
  let x6 = (x5 & 0x0000ffff0000ffff) + ((x5 >> 16) & 0x0000ffff0000ffff);
  let x7 = (x6 & 0x00000000ffffffff) + ((x6 >> 32) & 0x00000000ffffffff);
  let x = unsigned(x7);
  assert(x <= 'n);
  x
}

val ctz16 : bits(16) -> range(0, 16)
function ctz16(v) = {
  let masked : qword = zero_extend(v) | 0xFFFFFFFFFFFF0000;
  let pc = popcount(~(masked) & (masked - 1));
  assert(pc <= 16);
  pc
}

// Prove LSB mode: ctz matches the found-flag linear scan
// For ub=15 (byte mode, all 16 bits active)
$property
function prop_bit_index_lsb_15(int_res2 : bits(16)) -> bool = {
  let ub = 15;
  // Old: linear scan with found flag
  var idx_old : range(0, 16) = ub + 1;
  var found : bool = false;
  foreach (i from 0 to 15) {
    if i <= ub & int_res2[i] == 0b1 & ~(found) then {
      idx_old = i;
      found = true
    }
  };
  // New: ctz
  let idx_new : range(0, 16) = ctz16(int_res2);
  idx_old == idx_new
}

// For ub=7 (word mode, only low 8 bits active, upper bits are 0)
$property
function prop_bit_index_lsb_7(int_res2_lo : bits(8)) -> bool = {
  let int_res2 : bits(16) = zero_extend(int_res2_lo);
  let ub = 7;
  // Old: linear scan with found flag
  var idx_old : range(0, 16) = ub + 1;
  var found : bool = false;
  foreach (i from 0 to 15) {
    if i <= ub & int_res2[i] == 0b1 & ~(found) then {
      idx_old = i;
      found = true
    }
  };
  // New: ctz (returns 16 if zero, which is > ub+1=8, so clamp)
  let ctz_val = ctz16(int_res2);
  let idx_new : range(0, 16) = if ctz_val > ub + 1 then ub + 1 else ctz_val;
  idx_old == idx_new
}

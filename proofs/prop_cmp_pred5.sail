// Equivalence proof: cmp_pred5 bool→bit transformation
//
// Original (bool): r == FP_EQ, not_bool(r == FP_LT), etc.
// Branchless (bit): match r { FP_EQ => bitone, _ => bitzero }, ~(lt), etc.
//
// Proves that for every predicate 0-31, the bit version equals
// bool_to_bit of the bool version.

$include "../model/prelude.sail"

enum FPCompareResult = { FP_GT, FP_LT, FP_EQ, FP_UNORDERED }

// Bool version (original cmp_pred5 logic)
function cmp_pred5_bool(r : FPCompareResult, pred : range(0, 31)) -> bool = {
  let is_unord = r == FP_UNORDERED;
  match pred {
    0  => r == FP_EQ,
    1  => r == FP_LT,
    2  => r == FP_LT | r == FP_EQ,
    3  => is_unord,
    4  => r != FP_EQ & not_bool(is_unord),
    5  => not_bool(r == FP_LT) | is_unord,
    6  => not_bool(r == FP_LT | r == FP_EQ) | is_unord,
    7  => not_bool(is_unord),
    8  => r == FP_EQ | is_unord,
    9  => r == FP_LT | is_unord,
    10 => (r == FP_LT | r == FP_EQ) | is_unord,
    11 => false,
    12 => r != FP_EQ,
    13 => not_bool(r == FP_LT),
    14 => r == FP_GT | r == FP_EQ,
    15 => true,
    16 => r == FP_EQ,
    17 => r == FP_LT,
    18 => r == FP_LT | r == FP_EQ,
    19 => is_unord,
    20 => r != FP_EQ | is_unord,
    21 => not_bool(r == FP_LT) | is_unord,
    22 => not_bool(r == FP_LT | r == FP_EQ) | is_unord,
    23 => not_bool(is_unord),
    24 => r == FP_EQ | is_unord,
    25 => r == FP_LT | is_unord,
    26 => (r == FP_LT | r == FP_EQ) | is_unord,
    27 => false,
    28 => r != FP_EQ,
    29 => not_bool(r == FP_LT),
    30 => r == FP_GT | r == FP_EQ,
    31 => true,
  }
}

// Bit version (new branchless logic)
function cmp_pred5_bit(r : FPCompareResult, pred : range(0, 31)) -> bit = {
  let unord : bit = match r { FP_UNORDERED => bitone, _ => bitzero };
  let eq : bit = match r { FP_EQ => bitone, _ => bitzero };
  let lt : bit = match r { FP_LT => bitone, _ => bitzero };
  let gt : bit = match r { FP_GT => bitone, _ => bitzero };
  let le : bit = lt | eq;
  match pred {
    0  => eq,
    1  => lt,
    2  => le,
    3  => unord,
    4  => ~(eq) & ~(unord),
    5  => ~(lt) | unord,
    6  => ~(le) | unord,
    7  => ~(unord),
    8  => eq | unord,
    9  => lt | unord,
    10 => le | unord,
    11 => bitzero,
    12 => ~(eq),
    13 => ~(lt),
    14 => gt | eq,
    15 => bitone,
    16 => eq,
    17 => lt,
    18 => le,
    19 => unord,
    20 => ~(eq) | unord,
    21 => ~(lt) | unord,
    22 => ~(le) | unord,
    23 => ~(unord),
    24 => eq | unord,
    25 => lt | unord,
    26 => le | unord,
    27 => bitzero,
    28 => ~(eq),
    29 => ~(lt),
    30 => gt | eq,
    31 => bitone,
  }
}

$property
function prop_cmp_pred5(r : FPCompareResult, pred : bits(5)) -> bool = {
  let p : range(0, 31) = unsigned(pred);
  bool_to_bit(cmp_pred5_bool(r, p)) == cmp_pred5_bit(r, p)
}

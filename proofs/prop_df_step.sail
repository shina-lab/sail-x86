// Equivalence proof: DF direction step branch elimination
//
// Old code:
//   let step = if DF == 0b0 then os / 8 else -(os / 8)
//
// New code:
//   let step = (1 - 2 * unsigned(DF)) * (os / 8)
//
// DF=0: (1 - 0) * N =  N
// DF=1: (1 - 2) * N = -N

$include "../model/prelude.sail"

$property
function prop_df_step(df : bit, delta : bits(4)) -> bool = {
  let n = unsigned(delta);
  // Old
  let orig : int = if df == 0b0 then n else negate(n);
  // New
  let branchless : int = (1 - 2 * unsigned(df)) * n;
  orig == branchless
}

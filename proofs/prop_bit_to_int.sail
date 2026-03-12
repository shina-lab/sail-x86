$include "../model/prelude.sail"

// Test: bit-to-int via unsigned()
$property
function prop_bit_to_int(b : bits(1)) -> bool = {
  let orig : int = if b[0] == bitone then 1 else 0;
  let branchless : int = unsigned(b);
  orig == branchless
}

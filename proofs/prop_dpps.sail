$include "../model/prelude.sail"

// Core identity used by DPPS/DPPD branchless conversion:
//   if bit == 1 then v else zero  ==  v & sign_extend(bit)
//
// The full DPPS/DPPD correctness follows structurally: each conditional
// multiply is replaced by this identity, so the inputs to __f32_add/__f64_add
// are identical, making the sums and final outputs identical.

$property
function prop_mask32(v : bits(32), bit : bits(1)) -> bool = {
  let orig : bits(32) = if bit == 0b1 then v else 0x00000000;
  let branchless : bits(32) = v & sign_extend(bit);
  orig == branchless
}

$property
function prop_mask64(v : bits(64), bit : bits(1)) -> bool = {
  let orig : bits(64) = if bit == 0b1 then v else 0x0000000000000000;
  let branchless : bits(64) = v & sign_extend(bit);
  orig == branchless
}

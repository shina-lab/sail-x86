// Equivalence proof: eliminate bool_to_bit from INSERTPS dst_sel masks
//
// Original: let dst_sel = unsigned(imm8[5..4]);
//           let m0 = zeros() - zero_extend(bool_to_bit(dst_sel == 0));
// Branchless: let sel = imm8[5..4];
//             let m0 = zeros() - zero_extend(~(sel[1..1] | sel[0..0]));

$include "../model/prelude.sail"

// dst_sel == 0: bool_to_bit(unsigned(sel) == 0) ≡ (~(sel[1..1] | sel[0..0]))[0]
$property
function prop_insertps_m0(sel : bits(2)) -> bool = {
  let dst_sel : range(0, 3) = unsigned(sel);
  let orig : bit = bool_to_bit(dst_sel == 0);
  let branchless : bit = (~(sel[1..1] | sel[0..0]))[0];
  orig == branchless
}

// dst_sel == 1: XOR with 0b01, then NOR the bits
$property
function prop_insertps_m1(sel : bits(2)) -> bool = {
  let dst_sel : range(0, 3) = unsigned(sel);
  let orig : bit = bool_to_bit(dst_sel == 1);
  let xor_val : bits(2) = sel ^ 0b01;
  let branchless : bit = (~(xor_val[1..1] | xor_val[0..0]))[0];
  orig == branchless
}

// dst_sel == 2: XOR with 0b10, then NOR
$property
function prop_insertps_m2(sel : bits(2)) -> bool = {
  let dst_sel : range(0, 3) = unsigned(sel);
  let orig : bit = bool_to_bit(dst_sel == 2);
  let xor_val : bits(2) = sel ^ 0b10;
  let branchless : bit = (~(xor_val[1..1] | xor_val[0..0]))[0];
  orig == branchless
}

// dst_sel == 3: XOR with 0b11, then NOR
$property
function prop_insertps_m3(sel : bits(2)) -> bool = {
  let dst_sel : range(0, 3) = unsigned(sel);
  let orig : bit = bool_to_bit(dst_sel == 3);
  let xor_val : bits(2) = sel ^ 0b11;
  let branchless : bit = (~(xor_val[1..1] | xor_val[0..0]))[0];
  orig == branchless
}

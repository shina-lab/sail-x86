default Order dec

$include <prelude.sail>

overload operator - = {sub_bits}
overload operator + = {add_bits}
overload operator ^ = {xor_vec}
overload operator & = {and_vec}
overload operator | = {or_vec}
overload zeros = {sail_zeros}

val rem_positive_round_zero = pure {interpreter: "rem_round_zero", lem: "hardware_mod", c: "tmod_int", cpp: "tmod_int"} : forall 'n 'm, 'n >= 0 & 'm > 0. (int('n), int('m)) -> int(mod('n, 'm))
overload operator % = {rem_positive_round_zero}

// Prove: for 2-source permute, concatenating t2 @ t1 and direct indexing
// is equivalent to if id < N then t1[(id%N)*W..] else t2[(id%N)*W..].

// Dword element, 128-bit
$property
function prop_vperm2_d_128(t1 : bits(128), t2 : bits(128), id_bits : bits(3)) -> bool = {
  let id : range(0, 7) = unsigned(id_bits);
  let sel : range(0, 96) = (id % 4) * 32;
  let original : bits(32) = if id < 4 then t1[(sel + 31)..sel]
    else t2[(sel + 31)..sel];
  let combined : bits(256) = t2 @ t1;
  let branchless : bits(32) = combined[(id * 32 + 31) .. (id * 32)];
  original == branchless
}

// Qword element, 128-bit
$property
function prop_vperm2_q_128(t1 : bits(128), t2 : bits(128), id_bits : bits(2)) -> bool = {
  let id : range(0, 3) = unsigned(id_bits);
  let sel : range(0, 64) = (id % 2) * 64;
  let original : bits(64) = if id < 2 then t1[(sel + 63)..sel]
    else t2[(sel + 63)..sel];
  let combined : bits(256) = t2 @ t1;
  let branchless : bits(64) = combined[(id * 64 + 63) .. (id * 64)];
  original == branchless
}

// Word element, 128-bit
$property
function prop_vperm2_w_128(t1 : bits(128), t2 : bits(128), id_bits : bits(4)) -> bool = {
  let id : range(0, 15) = unsigned(id_bits);
  let sel : range(0, 112) = (id % 8) * 16;
  let original : bits(16) = if id < 8 then t1[(sel + 15)..sel]
    else t2[(sel + 15)..sel];
  let combined : bits(256) = t2 @ t1;
  let branchless : bits(16) = combined[(id * 16 + 15) .. (id * 16)];
  original == branchless
}

// Byte element, 128-bit
$property
function prop_vperm2_b_128(t1 : bits(128), t2 : bits(128), id_bits : bits(5)) -> bool = {
  let id : range(0, 31) = unsigned(id_bits);
  let sel : range(0, 120) = (id % 16) * 8;
  let original : bits(8) = if id < 16 then t1[(sel + 7)..sel]
    else t2[(sel + 7)..sel];
  let combined : bits(256) = t2 @ t1;
  let branchless : bits(8) = combined[(id * 8 + 7) .. (id * 8)];
  original == branchless
}

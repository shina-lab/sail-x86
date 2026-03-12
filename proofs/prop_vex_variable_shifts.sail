$include "../model/prelude.sail"

type dword   = bits(32)
type qword   = bits(64)
type xmmword = bits(128)

// Prove that variable logical right shift on 32-bit elements produces zeros
// when count >= 32, making the `if count < 32` branch redundant.
$property
function prop_psrlvd(elem : dword, count_bits : dword) -> bool = {
  let count : range(0, 4294967295) = unsigned(count_bits);
  let orig : dword = if count < 32 then sail_shiftright(elem, count) else zeros();
  let branchless : dword = sail_shiftright(elem, count);
  orig == branchless
}

// Logical right shift on 64-bit elements
$property
function prop_psrlvq(elem : qword, count_bits : dword) -> bool = {
  let count : range(0, 4294967295) = unsigned(count_bits);
  let orig : qword = if count < 64 then sail_shiftright(elem, count) else zeros();
  let branchless : qword = sail_shiftright(elem, count);
  orig == branchless
}

// Arithmetic right shift on 32-bit elements: clamped to 31 vs unclamped
$property
function prop_psravd(elem : dword, count_bits : dword) -> bool = {
  let count : range(0, 4294967295) = unsigned(count_bits);
  let orig : dword = if count >= 32 then sail_arith_shiftright(elem, 31)
                     else sail_arith_shiftright(elem, count);
  let branchless : dword = sail_arith_shiftright(elem, count);
  orig == branchless
}

// Logical left shift on 32-bit elements
$property
function prop_psllvd(elem : dword, count_bits : dword) -> bool = {
  let count : range(0, 4294967295) = unsigned(count_bits);
  let orig : dword = if count < 32 then sail_shiftleft(elem, count) else zeros();
  let branchless : dword = sail_shiftleft(elem, count);
  orig == branchless
}

// Logical left shift on 64-bit elements
$property
function prop_psllvq(elem : qword, count_bits : dword) -> bool = {
  let count : range(0, 4294967295) = unsigned(count_bits);
  let orig : qword = if count < 64 then sail_shiftleft(elem, count) else zeros();
  let branchless : qword = sail_shiftleft(elem, count);
  orig == branchless
}

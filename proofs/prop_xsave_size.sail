// Equivalence proof: xsave_area_size_standard branchless conversion
//
// Old: priority-encoded if/else chain on mask bits 7, 6, 5, 2
// New: ascending blend chain — each enabled component overwrites the size

$include "../model/prelude.sail"

type dword = bits(32)
type qword = bits(64)

val blend32 : (dword, dword, bit) -> dword
function blend32(a, b, sel) = {
  let m : dword = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

$property
function prop_xsave_size(mask : bits(8)) -> bool = {
  // Old: priority encoder
  let orig : dword =
    if mask[7] == 0b1 then to_bits(32, 2432)
    else if mask[6] == 0b1 then to_bits(32, 1408)
    else if mask[5] == 0b1 then to_bits(32, 896)
    else if mask[2] == 0b1 then to_bits(32, 832)
    else to_bits(32, 576);
  // New: ascending blend chain
  let s0 : dword = to_bits(32, 576);
  let s1 : dword = blend32(s0, to_bits(32, 832), mask[2]);
  let s2 : dword = blend32(s1, to_bits(32, 896), mask[5]);
  let s3 : dword = blend32(s2, to_bits(32, 1408), mask[6]);
  let s4 : dword = blend32(s3, to_bits(32, 2432), mask[7]);
  orig == s4
}

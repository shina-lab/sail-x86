$include "../model/prelude.sail"

// Prove that PALIGNR's 3-way branch can be replaced with a single expression.
// Since imm is a byte, shift_bytes = unsigned(imm) ∈ [0, 255].
// For a 256-bit concatenation shifted right by shift_bytes*8:
//   shift_bytes == 0: (concat >> 0)[127..0] = concat[127..0]  ✓
//   shift_bytes >= 32: shifting 256-bit by ≥256 bits → zeros   ✓

$property
function prop_palignr_128(src1 : bits(128), src2 : bits(128), imm : bits(8)) -> bool = {
  let shift_bytes : range(0, 255) = unsigned(imm);
  let concat : bits(256) = src1 @ src2;
  let orig : bits(128) =
    if shift_bytes <= 0 then concat[127..0]
    else if shift_bytes >= 32 then zeros()
    else (concat >> (shift_bytes * 8))[127..0];
  let branchless : bits(128) = (concat >> (shift_bytes * 8))[127..0];
  orig == branchless
}

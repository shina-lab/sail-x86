$include "../model/prelude.sail"

// Prove: branchless lane extraction via shift
// Pattern: if imm[0] == bitzero then src[127..0] else src[255..128]
//        → (src >> (unsigned(imm[0..0]) * 128))[127..0]

$property
function prop_extract_xmm_from_ymm(src : bits(256), sel : bit) -> bool = {
  let orig : bits(128) = if sel == bitzero then src[127..0] else src[255..128];
  let shift_amt : range(0, 128) = unsigned(zero_extend(sel) : bits(1)) * 128;
  let branchless : bits(128) = (src >> shift_amt)[127..0];
  orig == branchless
}

// Pattern: if imm[0] == bitzero then src[255..0] else src[511..256]
//        → (src >> (unsigned(imm[0..0]) * 256))[255..0]
$property
function prop_extract_ymm_from_zmm(src : bits(512), sel : bit) -> bool = {
  let orig : bits(256) = if sel == bitzero then src[255..0] else src[511..256];
  let shift_amt : range(0, 256) = unsigned(zero_extend(sel) : bits(1)) * 256;
  let branchless : bits(256) = (src >> shift_amt)[255..0];
  orig == branchless
}

// Equivalence proof: branchless conditional negation for DF direction flag
//
// Pattern A (INS/OUTS): if DF == bitone then -N else N
//   branchless: let sign = zeros() - zero_extend(DF); (N ^ sign) - sign
//
// Pattern B (STOS/LODS/SCAS): if DF == bitzero then addr + delta else addr - delta
//   branchless: let sign = zeros() - zero_extend(DF); addr + ((delta ^ sign) - sign)
//
// Pattern C (MOVS/CMPS): same as B but two independent pointer updates

$include "../model/prelude.sail"

// Pattern A: if DF == bitone then 0xFFFFFFFFFFFFFFFF else 0x0000000000000001
// ≡ let sign : qword = zeros() - zero_extend(DF); (0x0000000000000001 ^ sign) - sign
$property
function prop_df_delta_1(DF : bit) -> bool = {
  let orig : bits(64) = if DF == bitone then 0xFFFFFFFFFFFFFFFF else 0x0000000000000001;
  let sign : bits(64) = zeros() - zero_extend(DF);
  let branchless : bits(64) = (0x0000000000000001 ^ sign) - sign;
  orig == branchless
}

// Pattern A: if DF == bitone then 0xFFFFFFFFFFFFFFFE else 0x0000000000000002
$property
function prop_df_delta_2(DF : bit) -> bool = {
  let orig : bits(64) = if DF == bitone then 0xFFFFFFFFFFFFFFFE else 0x0000000000000002;
  let sign : bits(64) = zeros() - zero_extend(DF);
  let branchless : bits(64) = (0x0000000000000002 ^ sign) - sign;
  orig == branchless
}

// Pattern A: if DF == bitone then 0xFFFFFFFFFFFFFFFC else 0x0000000000000004
$property
function prop_df_delta_4(DF : bit) -> bool = {
  let orig : bits(64) = if DF == bitone then 0xFFFFFFFFFFFFFFFC else 0x0000000000000004;
  let sign : bits(64) = zeros() - zero_extend(DF);
  let branchless : bits(64) = (0x0000000000000004 ^ sign) - sign;
  orig == branchless
}

// Pattern B: if DF == bitzero then addr + delta else addr - delta
// ≡ let sign = zeros() - zero_extend(DF); addr + ((delta ^ sign) - sign)
$property
function prop_df_addr_update(addr : bits(64), delta : bits(64), DF : bit) -> bool = {
  let orig : bits(64) = if DF == bitzero then addr + delta else addr - delta;
  let sign : bits(64) = zeros() - zero_extend(DF);
  let branchless : bits(64) = addr + ((delta ^ sign) - sign);
  orig == branchless
}

// Pattern C: two independent pointer updates (MOVS/CMPS)
// if DF == bitzero then { src_addr + delta; dst_addr + delta }
// else { src_addr - delta; dst_addr - delta }
// ≡ let sign = zeros() - zero_extend(DF); let sd = (delta ^ sign) - sign;
//   src_addr + sd; dst_addr + sd
$property
function prop_df_dual_addr_update(src_addr : bits(64), dst_addr : bits(64), delta : bits(64), DF : bit) -> bool = {
  let orig_src : bits(64) = if DF == bitzero then src_addr + delta else src_addr - delta;
  let orig_dst : bits(64) = if DF == bitzero then dst_addr + delta else dst_addr - delta;
  let sign : bits(64) = zeros() - zero_extend(DF);
  let signed_delta : bits(64) = (delta ^ sign) - sign;
  let new_src : bits(64) = src_addr + signed_delta;
  let new_dst : bits(64) = dst_addr + signed_delta;
  orig_src == new_src & orig_dst == new_dst
}

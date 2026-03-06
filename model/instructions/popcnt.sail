// POPCNT — Return the Count of Number of Bits Set to 1
//
// Counts the number of set bits in source operand.
// OF, SF, AF, CF, PF are all cleared. ZF is set if source is zero.

val popcount8 : byte -> range(0, 8)
function popcount8(v) = {
  let b0 : range(0, 1) = if bit_to_bool(v[0]) then 1 else 0;
  let b1 : range(0, 1) = if bit_to_bool(v[1]) then 1 else 0;
  let b2 : range(0, 1) = if bit_to_bool(v[2]) then 1 else 0;
  let b3 : range(0, 1) = if bit_to_bool(v[3]) then 1 else 0;
  let b4 : range(0, 1) = if bit_to_bool(v[4]) then 1 else 0;
  let b5 : range(0, 1) = if bit_to_bool(v[5]) then 1 else 0;
  let b6 : range(0, 1) = if bit_to_bool(v[6]) then 1 else 0;
  let b7 : range(0, 1) = if bit_to_bool(v[7]) then 1 else 0;
  b0 + b1 + b2 + b3 + b4 + b5 + b6 + b7
}

val popcount16 : word -> range(0, 16)
function popcount16(v) =
  popcount8(v[7..0]) + popcount8(v[15..8])

val popcount32 : dword -> range(0, 32)
function popcount32(v) =
  popcount16(v[15..0]) + popcount16(v[31..16])

val popcount64 : qword -> range(0, 64)
function popcount64(v) =
  popcount32(v[31..0]) + popcount32(v[63..32])

val exec_popcnt : (gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_popcnt(dst, src_val, os) = {
  let count : range(0, 64) = match os {
    OS8  => popcount8(src_val[7..0]),
    OS16 => popcount16(src_val[15..0]),
    OS32 => popcount32(src_val[31..0]),
    OS64 => popcount64(src_val),
  };
  OF = bitzero;
  SF = bitzero;
  AF = bitzero;
  CF = bitzero;
  PF = bitzero;
  ZF = if count == 0 then bitone else bitzero;
  write_gpr(dst, os, to_bits_truncate(count));
  Ok(())
}

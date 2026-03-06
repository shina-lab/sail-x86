// BSF — Bit Scan Forward
//
// Searches source for least significant set bit.
// If source = 0, ZF := 1, dest undefined. Else ZF := 0, dest := bit index.
// CF, OF, SF, AF, PF are undefined.

val bsf64 : (qword, range(0, 63)) -> range(0, 63)
function bsf64(v, idx) =
  if idx >= 63 then 63
  else if bit_to_bool(v[idx]) then idx
  else bsf64(v, idx + 1)

val exec_bsf : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_bsf(dst, src, os) = {
  let src_val : qword = read_gpr(src, os);
  let is_zero : bool = match os {
    OS8  => src_val[7..0] == zeros(),
    OS16 => src_val[15..0] == zeros(),
    OS32 => src_val[31..0] == zeros(),
    OS64 => src_val == zeros(),
  };
  if is_zero then {
    ZF = bitone;
  } else {
    ZF = bitzero;
    let idx : range(0, 63) = bsf64(src_val, 0);
    write_gpr(dst, os, to_bits_truncate(idx));
  };
  Ok(())
}

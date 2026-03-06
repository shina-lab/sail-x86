// BSR — Bit Scan Reverse
//
// Searches source for most significant set bit.
// If source = 0, ZF := 1, dest undefined. Else ZF := 0, dest := bit index.
// CF, OF, SF, AF, PF are undefined.

val bsr64 : (qword, range(0, 63)) -> range(0, 63)
function bsr64(v, idx) =
  if idx <= 0 then 0
  else if bit_to_bool(v[idx]) then idx
  else bsr64(v, idx - 1)

val exec_bsr : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_bsr(dst, src, os) = {
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
    let top : range(0, 63) = match os {
      OS8  => 7,
      OS16 => 15,
      OS32 => 31,
      OS64 => 63,
    };
    let idx : range(0, 63) = bsr64(src_val, top);
    write_gpr(dst, os, to_bits_truncate(idx));
  };
  Ok(())
}

// BEXTR — Bit Field Extract (BMI1)
//
// Extracts contiguous bits from SRC1 starting at bit position SRC2[7:0]
// with length SRC2[15:8]. Result stored in DEST, zero-extended.
// ZF set from result. OF/CF cleared. AF/SF/PF undefined.
// Only 32-bit and 64-bit operand sizes.

val exec_bextr : (gpr_idx, gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_bextr(dst, src1, src2, os) = {
  let src_val : qword = read_gpr(src1, os);
  let ctrl : qword = read_gpr(src2, os);
  let start : range(0, 255) = unsigned(ctrl[7..0]);
  let len : range(0, 255) = unsigned(ctrl[15..8]);
  let os_bits : int = operand_size_bits(os);
  let result : qword =
    if start >= os_bits then zeros()
    else {
      let shifted : qword = src_val >> start;
      let eff_len : int = if start + len > os_bits then os_bits - start else len;
      if eff_len >= 64 then shifted
      else {
        let mask : qword = to_bits_truncate((2 ^ eff_len) - 1);
        shifted & mask
      }
    };
  ZF = if result == zeros() then bitone else bitzero;
  OF = bitzero;
  CF = bitzero;
  write_gpr(dst, os, result);
  Ok(())
}

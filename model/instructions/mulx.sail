// MULX — Unsigned Multiply Without Affecting Flags
//
// Unsigned multiply of EDX/RDX by source. High half to dst1, low half to dst2.
// No flags affected. 32/64-bit only (BMI2).

val exec_mulx : (gpr_idx, gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_mulx(dst_hi, dst_lo, src, os) = {
  match os {
    OS32 => {
      let a : int = unsigned(read_gpr32(RDX));
      let b : int = unsigned(read_gpr32(src));
      let result : qword = to_bits_truncate(a * b);
      write_gpr32(dst_lo, result[31..0]);
      write_gpr32(dst_hi, result[63..32]);
    },
    OS64 => {
      let a : int = unsigned(read_gpr64(RDX));
      let b : int = unsigned(read_gpr64(src));
      let result : xmmword = to_bits_truncate(a * b);
      write_gpr64(dst_lo, result[63..0]);
      write_gpr64(dst_hi, result[127..64]);
    },
    _ => (),
  };
  Ok(())
}

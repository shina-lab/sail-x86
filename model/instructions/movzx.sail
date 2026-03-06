// MOVZX — Move With Zero-Extend
//
// Zero-extends the source operand to the destination size.
// No flags affected.

// MOVZX r16/r32/r64, r/m8
val exec_movzx_8 : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_movzx_8(dst, src, os) = {
  let src_val : byte = read_gpr8l(src);
  match os {
    OS16 => write_gpr16(dst, zero_extend(src_val)),
    OS32 => write_gpr32(dst, zero_extend(src_val)),
    OS64 => write_gpr64(dst, zero_extend(src_val)),
    _    => (),
  };
  Ok(())
}

// MOVZX r32/r64, r/m16
val exec_movzx_16 : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_movzx_16(dst, src, os) = {
  let src_val : word = read_gpr16(src);
  match os {
    OS32 => write_gpr32(dst, zero_extend(src_val)),
    OS64 => write_gpr64(dst, zero_extend(src_val)),
    _    => (),
  };
  Ok(())
}

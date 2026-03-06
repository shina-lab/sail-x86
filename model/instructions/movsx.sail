// MOVSX/MOVSXD — Move With Sign-Extension
//
// Sign-extends the source operand to the destination size.
// No flags affected.

// MOVSX r16/r32/r64, r/m8
val exec_movsx_8 : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_movsx_8(dst, src, os) = {
  let src_val : byte = read_gpr8l(src);
  match os {
    OS16 => write_gpr16(dst, sign_extend(src_val)),
    OS32 => write_gpr32(dst, sign_extend(src_val)),
    OS64 => write_gpr64(dst, sign_extend(src_val)),
    _    => (),
  };
  Ok(())
}

// MOVSX r32/r64, r/m16
val exec_movsx_16 : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_movsx_16(dst, src, os) = {
  let src_val : word = read_gpr16(src);
  match os {
    OS32 => write_gpr32(dst, sign_extend(src_val)),
    OS64 => write_gpr64(dst, sign_extend(src_val)),
    _    => (),
  };
  Ok(())
}

// MOVSXD r64, r/m32 (REX.W form)
val exec_movsxd : (gpr_idx, gpr_idx) -> ExecutionResult
function exec_movsxd(dst, src) = {
  let src_val : dword = read_gpr32(src);
  write_gpr64(dst, sign_extend(src_val));
  Ok(())
}

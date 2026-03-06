// SARX/SHLX/SHRX — Shift Without Affecting Flags (BMI2)
//
// Three-operand shift: dst = src1 shifted by src2. No flags affected.
// Count masked to 5 bits (32-bit) or 6 bits (64-bit).

val exec_sarx : (gpr_idx, gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_sarx(dst, src, count_reg, os) = {
  match os {
    OS32 => {
      let count : range(0, 31) = unsigned(read_gpr32(count_reg)) % 32;
      let v : dword = read_gpr32(src);
      write_gpr32(dst, trunc(shift_right_arith(sign_extend(64, v), count)));
    },
    OS64 => {
      let count : range(0, 63) = unsigned(read_gpr64(count_reg)) % 64;
      let v : qword = read_gpr64(src);
      write_gpr64(dst, shift_right_arith(v, count));
    },
    _ => (),
  };
  Ok(())
}

val exec_shlx : (gpr_idx, gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_shlx(dst, src, count_reg, os) = {
  match os {
    OS32 => {
      let count : range(0, 31) = unsigned(read_gpr32(count_reg)) % 32;
      write_gpr32(dst, read_gpr32(src) << count);
    },
    OS64 => {
      let count : range(0, 63) = unsigned(read_gpr64(count_reg)) % 64;
      write_gpr64(dst, read_gpr64(src) << count);
    },
    _ => (),
  };
  Ok(())
}

val exec_shrx : (gpr_idx, gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_shrx(dst, src, count_reg, os) = {
  match os {
    OS32 => {
      let count : range(0, 31) = unsigned(read_gpr32(count_reg)) % 32;
      write_gpr32(dst, read_gpr32(src) >> count);
    },
    OS64 => {
      let count : range(0, 63) = unsigned(read_gpr64(count_reg)) % 64;
      write_gpr64(dst, read_gpr64(src) >> count);
    },
    _ => (),
  };
  Ok(())
}

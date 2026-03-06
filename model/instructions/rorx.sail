// RORX — Rotate Right Logical Without Affecting Flags
//
// Rotates source right by immediate count. No flags affected.
// 32/64-bit only (BMI2).

val exec_rorx : (gpr_idx, gpr_idx, byte, OperandSize) -> ExecutionResult
function exec_rorx(dst, src, imm8, os) = {
  match os {
    OS32 => {
      let y : range(0, 31) = unsigned(imm8) % 32;
      let v : dword = read_gpr32(src);
      write_gpr32(dst, (v >> y) | (v << (32 - y)));
    },
    OS64 => {
      let y : range(0, 63) = unsigned(imm8) % 64;
      let v : qword = read_gpr64(src);
      write_gpr64(dst, (v >> y) | (v << (64 - y)));
    },
    _ => (),
  };
  Ok(())
}

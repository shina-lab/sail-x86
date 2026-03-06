// ADCX — Unsigned Integer Addition of Two Operands With Carry Flag
//
// CF:DEST := DEST + SRC + CF. Only CF is updated; other flags unmodified.
// Only 32-bit and 64-bit operand sizes.

val exec_adcx : (gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_adcx(dst, b, os) = {
  let a : qword = read_gpr(dst, os);
  let c : int = if CF == bitone then 1 else 0;
  let result : qword = a + b + zero_extend(CF);
  match os {
    OS32 => {
      CF = if (unsigned(result[31..0]) != unsigned(a[31..0]) + unsigned(b[31..0]) + c)
           then bitone else bitzero
    },
    OS64 => {
      CF = if (unsigned(result) != unsigned(a) + unsigned(b) + c)
           then bitone else bitzero
    },
    _ => (),
  };
  write_gpr(dst, os, result);
  Ok(())
}

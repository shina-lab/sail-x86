// ADOX — Unsigned Integer Addition of Two Operands With Overflow Flag
//
// OF:DEST := DEST + SRC + OF. Only OF is updated; other flags unmodified.
// Only 32-bit and 64-bit operand sizes.

val exec_adox : (gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_adox(dst, b, os) = {
  let a : qword = read_gpr(dst, os);
  let c : int = if OF == bitone then 1 else 0;
  let result : qword = a + b + zero_extend(OF);
  match os {
    OS32 => {
      OF = if (unsigned(result[31..0]) != unsigned(a[31..0]) + unsigned(b[31..0]) + c)
           then bitone else bitzero
    },
    OS64 => {
      OF = if (unsigned(result) != unsigned(a) + unsigned(b) + c)
           then bitone else bitzero
    },
    _ => (),
  };
  write_gpr(dst, os, result);
  Ok(())
}

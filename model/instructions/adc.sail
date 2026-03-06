// ADC — Add With Carry
//
// Computes dest := dest + src + CF and updates RFLAGS.
// The OF, SF, ZF, AF, CF, and PF flags are set according to the result.

// ADC reg, reg
val exec_adc_reg_reg : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_adc_reg_reg(dst, src, os) = {
  let a : qword = read_gpr(dst, os);
  let b : qword = read_gpr(src, os);
  let carry : qword = zero_extend(CF);
  let result : qword = a + b + carry;
  match os {
    OS8  => update_flags_adc(result[7..0], a[7..0], b[7..0], CF),
    OS16 => update_flags_adc(result[15..0], a[15..0], b[15..0], CF),
    OS32 => update_flags_adc(result[31..0], a[31..0], b[31..0], CF),
    OS64 => update_flags_adc(result, a, b, CF),
  };
  write_gpr(dst, os, result);
  Ok(())
}

// ADC reg, imm
val exec_adc_reg_imm : (gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_adc_reg_imm(dst, imm, os) = {
  let a : qword = read_gpr(dst, os);
  let carry : qword = zero_extend(CF);
  let result : qword = a + imm + carry;
  match os {
    OS8  => update_flags_adc(result[7..0], a[7..0], imm[7..0], CF),
    OS16 => update_flags_adc(result[15..0], a[15..0], imm[15..0], CF),
    OS32 => update_flags_adc(result[31..0], a[31..0], imm[31..0], CF),
    OS64 => update_flags_adc(result, a, imm, CF),
  };
  write_gpr(dst, os, result);
  Ok(())
}

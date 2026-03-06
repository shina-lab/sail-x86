// SAR — Shift Right (Arithmetic)
//
// Shifts dest right by count bits, preserving sign bit.
// CF = last bit shifted out. OF cleared for count=1.
// SF, ZF, PF set from result. AF undefined for count != 0.

val exec_sar : (qword, byte, OperandSize) -> (ExecutionResult, qword)
function exec_sar(a, count_raw, os) = {
  let mod_val : range(32, 64) = if os == OS64 then 64 else 32;
  let count : range(0, 63) = unsigned(count_raw) % mod_val;
  if count == 0 then (Ok(()), a)
  else {
      // CF = last bit shifted out. For SAR, when count >= operand width,
    // the result is all-sign-bits, so CF = sign bit of the original value.
    // SDM pseudocode iterates: CF := LSB(DEST) each step with signed divide.
    let cf_idx : range(0, 63) = match os {
      OS8  => if count >= 8  then 7  else count - 1,
      OS16 => if count >= 16 then 15 else count - 1,
      OS32 => if count >= 32 then 31 else count - 1,
      OS64 => count - 1,
    };
    CF = a[cf_idx];
    let result : qword = match os {
      OS8  => zero_extend(shift_right_arith(a[7..0], count)),
      OS16 => zero_extend(shift_right_arith(a[15..0], count)),
      OS32 => zero_extend(shift_right_arith(a[31..0], count)),
      OS64 => shift_right_arith(a, count),
    };
    match os {
      OS8  => update_SF_ZF_PF(result[7..0]),
      OS16 => update_SF_ZF_PF(result[15..0]),
      OS32 => update_SF_ZF_PF(result[31..0]),
      OS64 => update_SF_ZF_PF(result),
    };
    if count == 1 then OF = bitzero
    else OF = undefined;
    AF = undefined;
    (Ok(()), result)
  }
}

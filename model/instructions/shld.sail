// SHLD — Double Precision Shift Left
//
// Shifts dst left by count, filling vacated bits from src (high bits).
// Equivalent to: result = upper_half(dst:src << count)
// If count=0, no operation. If count > operand_size, undefined.
// CF = last bit shifted out. SF, ZF, PF set from result.
// OF defined for count=1 (sign change). AF undefined.

val exec_shld : (qword, qword, byte, OperandSize) -> (ExecutionResult, qword)
function exec_shld(d, s, count_raw, os) = {
  let count : range(0, 63) = match os {
    OS64 => unsigned(count_raw) % 64,
    _    => unsigned(count_raw) % 32,
  };
  if count == 0 then (Ok(()), d)
  else {
    let result : qword = match os {
      OS16 => {
        if count > 16 then {
          // SDM: result and flags undefined when count > operand size
          CF = undefined; OF = undefined;
          SF = undefined; ZF = undefined; PF = undefined; AF = undefined;
          undefined
        } else {
          let wide : dword = d[15..0] @ s[15..0];
          let shifted : dword = wide << count;
          let r : word = shifted[31..16];
          CF = shifted[15];
          update_SF_ZF_PF(r);
          if count == 1 then
            OF = if r[15] != d[15] then bitone else bitzero
          else OF = undefined;
          zero_extend(r)
        }
      },
      OS32 => {
        let wide : qword = d[31..0] @ s[31..0];
        let shifted : qword = wide << count;
        let r : dword = shifted[63..32];
        CF = shifted[31];
        update_SF_ZF_PF(r);
        if count == 1 then
          OF = if r[31] != d[31] then bitone else bitzero
        else OF = undefined;
        zero_extend(r)
      },
      OS64 => {
        let wide : xmmword = d @ s;
        let shifted : xmmword = wide << count;
        let r : qword = shifted[127..64];
        CF = shifted[63];
        update_SF_ZF_PF(r);
        if count == 1 then
          OF = if r[63] != d[63] then bitone else bitzero
        else OF = undefined;
        r
      },
      _ => d,
    };
    AF = undefined;
    (Ok(()), result)
  }
}

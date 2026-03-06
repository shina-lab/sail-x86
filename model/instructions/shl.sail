// SHL/SAL — Shift Left
//
// Shifts dest left by count bits. CF = last bit shifted out.
// If count=0, flags unchanged. If count=1, OF = MSB(result) XOR CF.
// SF, ZF, PF set from result. AF undefined for count != 0.

val exec_shl : (qword, byte, OperandSize) -> (ExecutionResult, qword)
function exec_shl(a, count_raw, os) = {
  let count : range(0, 63) = match os {
    OS64 => unsigned(count_raw) % 64,
    _    => unsigned(count_raw) % 32,
  };
  if count == 0 then (Ok(()), a)
  else {
      let result : qword = a << count;
    match os {
      OS8 => {
        CF = if count <= 8 then a[8 - count] else undefined;
        if count <= 8 then update_SF_ZF_PF(result[7..0])
        else { SF = undefined; ZF = undefined; PF = undefined };
        if count == 1 then
          OF = if result[7] != CF then bitone else bitzero
        else OF = undefined
      },
      OS16 => {
        CF = if count <= 16 then a[16 - count] else undefined;
        if count <= 16 then update_SF_ZF_PF(result[15..0])
        else { SF = undefined; ZF = undefined; PF = undefined };
        if count == 1 then
          OF = if result[15] != CF then bitone else bitzero
        else OF = undefined
      },
      OS32 => {
        let c : range(0, 31) = unsigned(count_raw) % 32;
        assert(c > 0);
        CF = a[32 - c];
        update_SF_ZF_PF(result[31..0]);
        if count == 1 then
          OF = if result[31] != CF then bitone else bitzero
        else OF = undefined
      },
      OS64 => {
        let c : range(0, 63) = unsigned(count_raw) % 64;
        assert(c > 0);
        CF = a[64 - c];
        update_SF_ZF_PF(result);
        if count == 1 then
          OF = if result[63] != CF then bitone else bitzero
        else OF = undefined
      },
    };
    AF = undefined;
    (Ok(()), result)
  }
}

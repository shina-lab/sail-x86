// SHR — Shift Right (Logical)
//
// Shifts dest right by count bits, filling with zeros.
// CF = last bit shifted out. If count=1, OF = MSB(original).
// SF, ZF, PF set from result. AF undefined for count != 0.

val exec_shr : (qword, byte, OperandSize) -> (ExecutionResult, qword)
function exec_shr(a, count_raw, os) = {
  let mod_val : range(32, 64) = if os == OS64 then 64 else 32;
  let count : range(0, 63) = unsigned(count_raw) % mod_val;
  if count == 0 then (Ok(()), a)
  else {
    let result : qword = a >> count;
    match os {
      OS8 => {
        CF = if count <= 8 then a[count - 1] else undefined;
        if count <= 8 then update_SF_ZF_PF(result[7..0])
        else { SF = undefined; ZF = undefined; PF = undefined };
        if count == 1 then OF = a[7]
        else OF = undefined
      },
      OS16 => {
        CF = if count <= 16 then a[count - 1] else undefined;
        if count <= 16 then update_SF_ZF_PF(result[15..0])
        else { SF = undefined; ZF = undefined; PF = undefined };
        if count == 1 then OF = a[15]
        else OF = undefined
      },
      OS32 => {
        let c : range(0, 31) = unsigned(count_raw) % 32;
        assert(c > 0);
        CF = a[c - 1];
        update_SF_ZF_PF(result[31..0]);
        if count == 1 then OF = a[31]
        else OF = undefined
      },
      OS64 => {
        let c : range(0, 63) = unsigned(count_raw) % 64;
        assert(c > 0);
        CF = a[c - 1];
        update_SF_ZF_PF(result);
        if count == 1 then OF = a[63]
        else OF = undefined
      },
    };
    AF = undefined;
    (Ok(()), result)
  }
}

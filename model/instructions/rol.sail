// ROL — Rotate Left
// ROR — Rotate Right
//
// ROL: Rotates bits left. CF = LSB(result) after rotate.
// ROR: Rotates bits right. CF = MSB(result) after rotate.
// OF defined only for count=1. SF, ZF, AF, PF unaffected.
// Count is masked to 5 bits (6 bits for 64-bit operands).

val exec_rol : (qword, byte, OperandSize) -> (ExecutionResult, qword)
function exec_rol(a, count_raw, os) = {
  let count : range(0, 63) = match os {
    OS64 => unsigned(count_raw) % 64,
    _    => unsigned(count_raw) % 32,
  };
  if count == 0 then (Ok(()), a)
  else {
      let result : qword = match os {
      OS8 => {
        let c : range(0, 7) = count % 8;
        zero_extend((a[7..0] << c) | (a[7..0] >> (8 - c)))
      },
      OS16 => {
        let c : range(0, 15) = count % 16;
        zero_extend((a[15..0] << c) | (a[15..0] >> (16 - c)))
      },
      OS32 => {
        let c : range(0, 31) = count % 32;
        zero_extend((a[31..0] << c) | (a[31..0] >> (32 - c)))
      },
      OS64 => (a << count) | (a >> (64 - count)),
    };
    CF = result[0];
    if count == 1 then match os {
      OS8  => OF = if result[7] != CF then bitone else bitzero,
      OS16 => OF = if result[15] != CF then bitone else bitzero,
      OS32 => OF = if result[31] != CF then bitone else bitzero,
      OS64 => OF = if result[63] != CF then bitone else bitzero,
    } else OF = undefined;
    (Ok(()), result)
  }
}

val exec_ror : (qword, byte, OperandSize) -> (ExecutionResult, qword)
function exec_ror(a, count_raw, os) = {
  let count : range(0, 63) = match os {
    OS64 => unsigned(count_raw) % 64,
    _    => unsigned(count_raw) % 32,
  };
  if count == 0 then (Ok(()), a)
  else {
      let result : qword = match os {
      OS8 => {
        let c : range(0, 7) = count % 8;
        zero_extend((a[7..0] >> c) | (a[7..0] << (8 - c)))
      },
      OS16 => {
        let c : range(0, 15) = count % 16;
        zero_extend((a[15..0] >> c) | (a[15..0] << (16 - c)))
      },
      OS32 => {
        let c : range(0, 31) = count % 32;
        zero_extend((a[31..0] >> c) | (a[31..0] << (32 - c)))
      },
      OS64 => (a >> count) | (a << (64 - count)),
    };
    match os {
      OS8  => CF = result[7],
      OS16 => CF = result[15],
      OS32 => CF = result[31],
      OS64 => CF = result[63],
    };
    if count == 1 then match os {
      OS8  => OF = if result[7] != result[6] then bitone else bitzero,
      OS16 => OF = if result[15] != result[14] then bitone else bitzero,
      OS32 => OF = if result[31] != result[30] then bitone else bitzero,
      OS64 => OF = if result[63] != result[62] then bitone else bitzero,
    } else OF = undefined;
    (Ok(()), result)
  }
}

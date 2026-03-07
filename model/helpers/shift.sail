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
// RCL — Rotate Through Carry Left
// RCR — Rotate Through Carry Right
//
// RCL: Rotates (n+1)-bit value (CF:dest) left by count.
// RCR: Rotates (n+1)-bit value (CF:dest) right by count.
// OF defined only for count=1. Count masked to 5 bits (6 for 64-bit).

val exec_rcl : (qword, byte, OperandSize) -> (ExecutionResult, qword)
function exec_rcl(a, count_raw, os) = {
  let masked : range(0, 63) = match os {
    OS64 => unsigned(count_raw) % 64,
    _    => unsigned(count_raw) % 32,
  };
  let tempcount : int = match os {
    OS8  => masked % 9,
    OS16 => masked % 17,
    OS32 => masked,
    OS64 => masked,
  };
  if tempcount == 0 then (Ok(()), a)
  else {
      var cf_bit : bit = CF;
    var val8  : byte  = a[7..0];
    var val16 : word = a[15..0];
    var val32 : dword = a[31..0];
    var val64 : qword = a;
    var i : int = tempcount;
    while i > 0 do {
      match os {
        OS8 => {
          let tcf : bit = val8[7];
          val8 = val8[6..0] @ cf_bit;
          cf_bit = tcf;
        },
        OS16 => {
          let tcf : bit = val16[15];
          val16 = val16[14..0] @ cf_bit;
          cf_bit = tcf;
        },
        OS32 => {
          let tcf : bit = val32[31];
          val32 = val32[30..0] @ cf_bit;
          cf_bit = tcf;
        },
        OS64 => {
          let tcf : bit = val64[63];
          val64 = val64[62..0] @ cf_bit;
          cf_bit = tcf;
        },
      };
      i = i - 1;
    };
    CF = cf_bit;
    if masked == 1 then match os {
      OS8  => OF = if val8[7] != CF then bitone else bitzero,
      OS16 => OF = if val16[15] != CF then bitone else bitzero,
      OS32 => OF = if val32[31] != CF then bitone else bitzero,
      OS64 => OF = if val64[63] != CF then bitone else bitzero,
    } else OF = undefined;
    let result : qword = match os {
      OS8  => zero_extend(val8),
      OS16 => zero_extend(val16),
      OS32 => zero_extend(val32),
      OS64 => val64,
    };
    (Ok(()), result)
  }
}

val exec_rcr : (qword, byte, OperandSize) -> (ExecutionResult, qword)
function exec_rcr(a, count_raw, os) = {
  let masked : range(0, 63) = match os {
    OS64 => unsigned(count_raw) % 64,
    _    => unsigned(count_raw) % 32,
  };
  let tempcount : int = match os {
    OS8  => masked % 9,
    OS16 => masked % 17,
    OS32 => masked,
    OS64 => masked,
  };
  if tempcount == 0 then (Ok(()), a)
  else {
      var cf_bit : bit = CF;
    var val8  : byte  = a[7..0];
    var val16 : word = a[15..0];
    var val32 : dword = a[31..0];
    var val64 : qword = a;
    // OF is set before the rotate for RCR
    if masked == 1 then match os {
      OS8  => OF = if val8[7] != CF then bitone else bitzero,
      OS16 => OF = if val16[15] != CF then bitone else bitzero,
      OS32 => OF = if val32[31] != CF then bitone else bitzero,
      OS64 => OF = if val64[63] != CF then bitone else bitzero,
    } else OF = undefined;
    var i : int = tempcount;
    while i > 0 do {
      match os {
        OS8 => {
          let tcf : bit = val8[0];
          val8 = cf_bit @ val8[7..1];
          cf_bit = tcf;
        },
        OS16 => {
          let tcf : bit = val16[0];
          val16 = cf_bit @ val16[15..1];
          cf_bit = tcf;
        },
        OS32 => {
          let tcf : bit = val32[0];
          val32 = cf_bit @ val32[31..1];
          cf_bit = tcf;
        },
        OS64 => {
          let tcf : bit = val64[0];
          val64 = cf_bit @ val64[63..1];
          cf_bit = tcf;
        },
      };
      i = i - 1;
    };
    CF = cf_bit;
    let result : qword = match os {
      OS8  => zero_extend(val8),
      OS16 => zero_extend(val16),
      OS32 => zero_extend(val32),
      OS64 => val64,
    };
    (Ok(()), result)
  }
}
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
          CF = wide[32 - count];
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
        CF = wide[64 - count];
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
        CF = wide[128 - count];
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
// SHRD — Double Precision Shift Right
//
// Shifts dst right by count, filling vacated bits from src (low bits).
// Equivalent to: result = lower_half(src:dst >> count)
// If count=0, no operation. If count > operand_size, undefined.
// CF = last bit shifted out. SF, ZF, PF set from result.
// OF defined for count=1 (sign change). AF undefined.

val exec_shrd : (qword, qword, byte, OperandSize) -> (ExecutionResult, qword)
function exec_shrd(d, s, count_raw, os) = {
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
          let wide : dword = s[15..0] @ d[15..0];
          let shifted : dword = wide >> count;
          let r : word = shifted[15..0];
          CF = d[count - 1];
          update_SF_ZF_PF(r);
          if count == 1 then
            OF = if r[15] != d[15] then bitone else bitzero
          else OF = undefined;
          zero_extend(r)
        }
      },
      OS32 => {
        let wide : qword = s[31..0] @ d[31..0];
        let shifted : qword = wide >> count;
        let r : dword = shifted[31..0];
        CF = d[count - 1];
        update_SF_ZF_PF(r);
        if count == 1 then
          OF = if r[31] != d[31] then bitone else bitzero
        else OF = undefined;
        zero_extend(r)
      },
      OS64 => {
        let wide : xmmword = s @ d;
        let shifted : xmmword = wide >> count;
        let r : qword = shifted[63..0];
        CF = d[count - 1];
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

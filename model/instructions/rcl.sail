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

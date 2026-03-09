// INC — Increment by 1
//
// Computes dest := dest + 1. Updates OF, SF, ZF, AF, PF. CF unchanged.

val exec_inc : (qword, OperandSize) -> (ExecutionResult, qword)
function exec_inc(a, os) = {
  let one : qword = zero_extend(0b1 : bits(1));
  let result : qword = a + one;
  match os {
    OS8  => update_flags_add_no_cf(result[7..0], a[7..0], one[7..0]),
    OS16 => update_flags_add_no_cf(result[15..0], a[15..0], one[15..0]),
    OS32 => update_flags_add_no_cf(result[31..0], a[31..0], one[31..0]),
    OS64 => update_flags_add_no_cf(result, a, one),
  };
  (Ok(), result)
}

// DEC — Decrement by 1
//
// Computes dest := dest - 1. Updates OF, SF, ZF, AF, PF. CF unchanged.

val exec_dec : (qword, OperandSize) -> (ExecutionResult, qword)
function exec_dec(a, os) = {
  let one : qword = zero_extend(0b1 : bits(1));
  let result : qword = a - one;
  match os {
    OS8  => update_flags_sub_no_cf(result[7..0], a[7..0], one[7..0]),
    OS16 => update_flags_sub_no_cf(result[15..0], a[15..0], one[15..0]),
    OS32 => update_flags_sub_no_cf(result[31..0], a[31..0], one[31..0]),
    OS64 => update_flags_sub_no_cf(result, a, one),
  };
  (Ok(), result)
}

// MUL — Unsigned Multiply

val exec_mul : (qword, OperandSize) -> ExecutionResult
function exec_mul(src, os) = {
  match os {
    OS8 => {
      let a : int = unsigned(read_gpr8l(RAX));
      let b : int = unsigned(src[7..0]);
      let result : word = to_bits_truncate(a * b);
      write_gpr16(RAX, result);
      CF = bool_to_bit(result[15..8] != zeros());
      OF = CF;
    },
    OS16 => {
      let a : int = unsigned(read_gpr16(RAX));
      let b : int = unsigned(src[15..0]);
      let result : dword = to_bits_truncate(a * b);
      write_gpr16(RAX, result[15..0]);
      write_gpr16(RDX, result[31..16]);
      CF = bool_to_bit(result[31..16] != zeros());
      OF = CF;
    },
    OS32 => {
      let a : int = unsigned(read_gpr32(RAX));
      let b : int = unsigned(src[31..0]);
      let result : qword = to_bits_truncate(a * b);
      write_gpr32(RAX, result[31..0]);
      write_gpr32(RDX, result[63..32]);
      CF = bool_to_bit(result[63..32] != zeros());
      OF = CF;
    },
    OS64 => {
      let a : int = unsigned(read_gpr64(RAX));
      let b : int = unsigned(src);
      let product : int = a * b;
      let result : xmmword = to_bits_truncate(product);
      write_gpr64(RAX, result[63..0]);
      write_gpr64(RDX, result[127..64]);
      CF = bool_to_bit(result[127..64] != zeros());
      OF = CF;
    },
  };
  Ok()
}

// DIV — Unsigned Divide

val exec_div : (qword, OperandSize) -> ExecutionResult
function exec_div(src, os) = {
  match os {
    OS8 => {
      let divisor = unsigned(src[7..0]);
      if divisor == 0 then {
        raise_DE()
      } else {
        let dividend = unsigned(read_gpr16(RAX));
        let quotient = dividend / divisor;
        let remainder = dividend - quotient * divisor;
        if quotient > 255 then {
          raise_DE()
        } else {
          write_gpr8l(RAX, to_bits_truncate(quotient));
          write_gpr8h(RAX, to_bits_truncate(remainder));
          Ok()
        }
      }
    },
    OS16 => {
      let divisor = unsigned(src[15..0]);
      if divisor == 0 then {
        raise_DE()
      } else {
        let dividend = unsigned(read_gpr16(RDX) @ read_gpr16(RAX));
        let quotient = dividend / divisor;
        let remainder = dividend - quotient * divisor;
        if quotient > 65535 then {
          raise_DE()
        } else {
          write_gpr16(RAX, to_bits_truncate(quotient));
          write_gpr16(RDX, to_bits_truncate(remainder));
          Ok()
        }
      }
    },
    OS32 => {
      let divisor = unsigned(src[31..0]);
      if divisor == 0 then {
        raise_DE()
      } else {
        let dividend = unsigned(read_gpr32(RDX) @ read_gpr32(RAX));
        let quotient = dividend / divisor;
        let remainder = dividend - quotient * divisor;
        if quotient > (pow2(32) - 1) then {
          raise_DE()
        } else {
          write_gpr32(RAX, to_bits_truncate(quotient));
          write_gpr32(RDX, to_bits_truncate(remainder));
          Ok()
        }
      }
    },
    OS64 => {
      let divisor = unsigned(src);
      if divisor == 0 then {
        raise_DE()
      } else {
        let dividend = unsigned(read_gpr64(RDX) @ read_gpr64(RAX));
        let quotient = dividend / divisor;
        let remainder = dividend - quotient * divisor;
        if quotient > (pow2(64) - 1) then {
          raise_DE()
        } else {
          write_gpr64(RAX, to_bits_truncate(quotient));
          write_gpr64(RDX, to_bits_truncate(remainder));
          Ok()
        }
      }
    },
  }
}

// IDIV — Signed Divide

val exec_idiv : (qword, OperandSize) -> ExecutionResult
function exec_idiv(src, os) = {
  match os {
    OS8 => {
      let divisor = signed(src[7..0]);
      if divisor == 0 then {
        raise_DE()
      } else {
        let dividend = signed(read_gpr16(RAX));
        let quotient = quot_round_zero(dividend, divisor);
        let remainder = rem_round_zero(dividend, divisor);
        if quotient > 127 | quotient < negate(128) then {
          raise_DE()
        } else {
          write_gpr8l(RAX, to_bits_truncate(quotient));
          write_gpr8h(RAX, to_bits_truncate(remainder));
          Ok()
        }
      }
    },
    OS16 => {
      let divisor = signed(src[15..0]);
      if divisor == 0 then {
        raise_DE()
      } else {
        let dividend = signed(read_gpr16(RDX) @ read_gpr16(RAX));
        let quotient = quot_round_zero(dividend, divisor);
        let remainder = rem_round_zero(dividend, divisor);
        if quotient > 32767 | quotient < negate(32768) then {
          raise_DE()
        } else {
          write_gpr16(RAX, to_bits_truncate(quotient));
          write_gpr16(RDX, to_bits_truncate(remainder));
          Ok()
        }
      }
    },
    OS32 => {
      let divisor = signed(src[31..0]);
      if divisor == 0 then {
        raise_DE()
      } else {
        let dividend = signed(read_gpr32(RDX) @ read_gpr32(RAX));
        let quotient = quot_round_zero(dividend, divisor);
        let remainder = rem_round_zero(dividend, divisor);
        if quotient > (pow2(31) - 1) | quotient < negate(pow2(31)) then {
          raise_DE()
        } else {
          write_gpr32(RAX, to_bits_truncate(quotient));
          write_gpr32(RDX, to_bits_truncate(remainder));
          Ok()
        }
      }
    },
    OS64 => {
      let divisor = signed(src);
      if divisor == 0 then {
        raise_DE()
      } else {
        let dividend = signed(read_gpr64(RDX) @ read_gpr64(RAX));
        let quotient = quot_round_zero(dividend, divisor);
        let remainder = rem_round_zero(dividend, divisor);
        if quotient > (pow2(63) - 1) | quotient < negate(pow2(63)) then {
          raise_DE()
        } else {
          write_gpr64(RAX, to_bits_truncate(quotient));
          write_gpr64(RDX, to_bits_truncate(remainder));
          Ok()
        }
      }
    },
  }
}

// IMUL — Signed Multiply (one-operand form)

val exec_imul_1 : (qword, OperandSize) -> ExecutionResult
function exec_imul_1(src, os) = {
  match os {
    OS8 => {
      let a : int = signed(read_gpr8l(RAX));
      let b : int = signed(src[7..0]);
      let product : int = a * b;
      let result : word = to_bits_truncate(product);
      write_gpr16(RAX, result);
      let truncated : bool = product != signed(result[7..0]);
      CF = bool_to_bit(truncated);
      OF = CF;
    },
    OS16 => {
      let a : int = signed(read_gpr16(RAX));
      let b : int = signed(src[15..0]);
      let product : int = a * b;
      let result : dword = to_bits_truncate(product);
      write_gpr16(RAX, result[15..0]);
      write_gpr16(RDX, result[31..16]);
      let truncated : bool = product != signed(result[15..0]);
      CF = bool_to_bit(truncated);
      OF = CF;
    },
    OS32 => {
      let a : int = signed(read_gpr32(RAX));
      let b : int = signed(src[31..0]);
      let product : int = a * b;
      let result : qword = to_bits_truncate(product);
      write_gpr32(RAX, result[31..0]);
      write_gpr32(RDX, result[63..32]);
      let truncated : bool = product != signed(result[31..0]);
      CF = bool_to_bit(truncated);
      OF = CF;
    },
    OS64 => {
      let a : int = signed(read_gpr64(RAX));
      let b : int = signed(src);
      let product : int = a * b;
      let result : xmmword = to_bits_truncate(product);
      write_gpr64(RAX, result[63..0]);
      write_gpr64(RDX, result[127..64]);
      let truncated : bool = product != signed(result[63..0]);
      CF = bool_to_bit(truncated);
      OF = CF;
    },
  };
  Ok()
}

// PUSH imm

val exec_push_imm : (qword, OperandSize) -> ExecutionResult
function exec_push_imm(imm, os) = {
  match os {
    OS64 => push64(imm),
    OS32 => if cur_mode == LongMode then push64(imm) else push32(imm[31..0]),
    OS16 => push16(imm[15..0]),
    _ => (),
  };
  Ok()
}

// =========================================================================
// Group 3 (F6): Unary byte operations
// =========================================================================

val dispatch_group3_byte : (range(0, 7), RM, Prefixes) -> ExecutionResult
function dispatch_group3_byte(reg_field, rm, pfx) = {
  if reg_field == 0 | reg_field == 1 then {
    // TEST r/m8, imm8
    // Fetch imm BEFORE reading rm so decode_pos is final for RIP-relative fixup
    let imm : qword = zero_extend(fetch_byte());
    let v = read_rm_val(rm, OS8, pfx.has_rex);
    let result = v & imm;
    update_flags_logic(result[7..0]);
    Ok()
  } else {
    let v = read_rm_val(rm, OS8, pfx.has_rex);
    match reg_field {
      0 => Ok(),  // unreachable, handled above
      1 => Ok(),  // unreachable, handled above
      2 => {
        // NOT r/m8
        let result = v ^ 0x00000000000000FF;
        write_rm_val(rm, OS8, pfx.has_rex, result);
        Ok()
      },
      3 => {
        // NEG r/m8
        let zero : qword = zeros();
        let result = zero - v;
        update_flags_sub(result[7..0], zero[7..0], v[7..0]);
        write_rm_val(rm, OS8, pfx.has_rex, result);
        Ok()
      },
      4 => exec_mul(v, OS8),
      5 => exec_imul_1(v, OS8),
      6 => exec_div(v, OS8),
      7 => exec_idiv(v, OS8),
    }
  }
}

// =========================================================================
// Group 3 (F7): Unary word/dword/qword operations
// =========================================================================

val dispatch_group3 : (range(0, 7), RM, OperandSize, Prefixes) -> ExecutionResult
function dispatch_group3(reg_field, rm, os, pfx) = {
  if reg_field == 0 | reg_field == 1 then {
    // TEST r/m, imm (Iz)
    // Fetch imm BEFORE reading rm so decode_pos is final for RIP-relative fixup
    let imm = fetch_imm_z(os);
    let v = read_rm_val(rm, os, pfx.has_rex);
    let result = v & imm;
    match os {
      OS8  => update_flags_logic(result[7..0]),
      OS16 => update_flags_logic(result[15..0]),
      OS32 => update_flags_logic(result[31..0]),
      OS64 => update_flags_logic(result),
    };
    Ok()
  } else {
    let v = read_rm_val(rm, os, pfx.has_rex);
    match reg_field {
      0 => Ok(),  // unreachable
      1 => Ok(),  // unreachable
      2 => {
        // NOT r/m
        let result = ~(v);
        write_rm_val(rm, os, pfx.has_rex, result);
        Ok()
      },
      3 => {
        // NEG r/m
        let zero : qword = zeros();
        let result = zero - v;
        match os {
          OS8  => update_flags_sub(result[7..0], zero[7..0], v[7..0]),
          OS16 => update_flags_sub(result[15..0], zero[15..0], v[15..0]),
          OS32 => update_flags_sub(result[31..0], zero[31..0], v[31..0]),
          OS64 => update_flags_sub(result, zero, v),
        };
        write_rm_val(rm, os, pfx.has_rex, result);
        Ok()
      },
      4 => exec_mul(v, os),
      5 => exec_imul_1(v, os),
      6 => exec_div(v, os),
      7 => exec_idiv(v, os),
    }
  }
}

// =========================================================================
// Group 5 (FF): INC/DEC/CALL/JMP/PUSH
// =========================================================================

val dispatch_group5 : (range(0, 7), RM, Prefixes) -> ExecutionResult
function dispatch_group5(reg_field, rm, pfx) = {
  match reg_field {
    0 => {
      // INC r/m
      let os = get_operand_size(pfx);
      let v = read_rm_val(rm, os, pfx.has_rex);
      let (res, result) = exec_inc(v, os);
      write_rm_val(rm, os, pfx.has_rex, result);
      res
    },
    1 => {
      // DEC r/m
      let os = get_operand_size(pfx);
      let v = read_rm_val(rm, os, pfx.has_rex);
      let (res, result) = exec_dec(v, os);
      write_rm_val(rm, os, pfx.has_rex, result);
      res
    },
    2 => {
      // CALL near indirect (f64 — forced to 64-bit in 64-bit mode)
      // SDM: "operand size for near call is forced to 64-bits" in 64-bit mode.
      // 66h prefix is ignored; 16/32-bit forms are N.E. (Not Encodable).
      let os = get_operand_size_f64(pfx);
      let target = read_rm_val(rm, os, pfx.has_rex);
      let return_addr = decode_pos;
      match os {
        OS64 => push64(return_addr),
        OS32 => push32(return_addr[31..0]),
        OS16 => push16(return_addr[15..0]),
        _ => (),
      };
      next_rip = Some(target);
      Ok()
    },
    4 => {
      // JMP near indirect (f64)
      let target = read_rm_val(rm, OS64, pfx.has_rex);
      next_rip = Some(target);
      Ok()
    },
    6 => {
      // PUSH r/m (d64)
      let os = get_operand_size_d64(pfx);
      let v = read_rm_val(rm, os, pfx.has_rex);
      exec_push_imm(v, os)
    },
    _ => raise_UD(),  // 3=CALL far, 5=JMP far, 7=reserved
  }
}

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
  if count == 0 then {
    (Ok(), a)
  } else {
    let result : qword = a << count;
    match os {
      OS8 => {
        CF = if count <= 8 then a[8 - count] else undefined;
        update_SF_ZF_PF(result[7..0]);
        if count == 1 then
          OF = bool_to_bit(result[7] != CF)
        else OF = undefined
      },
      OS16 => {
        CF = if count <= 16 then a[16 - count] else undefined;
        update_SF_ZF_PF(result[15..0]);
        if count == 1 then
          OF = bool_to_bit(result[15] != CF)
        else OF = undefined
      },
      OS32 => {
        let c : range(0, 31) = unsigned(count_raw) % 32;
        assert(c > 0);
        CF = a[32 - c];
        update_SF_ZF_PF(result[31..0]);
        if count == 1 then
          OF = bool_to_bit(result[31] != CF)
        else OF = undefined
      },
      OS64 => {
        let c : range(0, 63) = unsigned(count_raw) % 64;
        assert(c > 0);
        CF = a[64 - c];
        update_SF_ZF_PF(result);
        if count == 1 then
          OF = bool_to_bit(result[63] != CF)
        else OF = undefined
      },
    };
    AF = undefined;
    (Ok(), result)
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
  if count == 0 then {
    (Ok(), a)
  } else {
    let result : qword = a >> count;
    match os {
      OS8 => {
        CF = if count <= 8 then a[count - 1] else undefined;
        update_SF_ZF_PF(result[7..0]);
        if count == 1 then OF = a[7]
        else OF = undefined
      },
      OS16 => {
        CF = if count <= 16 then a[count - 1] else undefined;
        update_SF_ZF_PF(result[15..0]);
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
    (Ok(), result)
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
  if count == 0 then {
    (Ok(), a)
  } else {
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
    (Ok(), result)
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
  if count == 0 then {
    (Ok(), a)
  } else {
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
      OS8  => OF = bool_to_bit(result[7] != CF),
      OS16 => OF = bool_to_bit(result[15] != CF),
      OS32 => OF = bool_to_bit(result[31] != CF),
      OS64 => OF = bool_to_bit(result[63] != CF),
    } else {
      OF = undefined;
    };
    (Ok(), result)
  }
}

val exec_ror : (qword, byte, OperandSize) -> (ExecutionResult, qword)
function exec_ror(a, count_raw, os) = {
  let count : range(0, 63) = match os {
    OS64 => unsigned(count_raw) % 64,
    _    => unsigned(count_raw) % 32,
  };
  if count == 0 then {
    (Ok(), a)
  } else {
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
      OS8  => OF = bool_to_bit(result[7] != result[6]),
      OS16 => OF = bool_to_bit(result[15] != result[14]),
      OS32 => OF = bool_to_bit(result[31] != result[30]),
      OS64 => OF = bool_to_bit(result[63] != result[62]),
    } else {
      OF = undefined;
    };
    (Ok(), result)
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
  if tempcount == 0 then {
    (Ok(), a)
  } else {
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
      OS8  => OF = bool_to_bit(val8[7] != CF),
      OS16 => OF = bool_to_bit(val16[15] != CF),
      OS32 => OF = bool_to_bit(val32[31] != CF),
      OS64 => OF = bool_to_bit(val64[63] != CF),
    } else {
      OF = undefined;
    };
    let result : qword = match os {
      OS8  => zero_extend(val8),
      OS16 => zero_extend(val16),
      OS32 => zero_extend(val32),
      OS64 => val64,
    };
    (Ok(), result)
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
  if tempcount == 0 then {
    (Ok(), a)
  } else {
    var cf_bit : bit = CF;
    var val8  : byte  = a[7..0];
    var val16 : word = a[15..0];
    var val32 : dword = a[31..0];
    var val64 : qword = a;
    // OF is set before the rotate for RCR
    if masked == 1 then match os {
      OS8  => OF = bool_to_bit(val8[7] != CF),
      OS16 => OF = bool_to_bit(val16[15] != CF),
      OS32 => OF = bool_to_bit(val32[31] != CF),
      OS64 => OF = bool_to_bit(val64[63] != CF),
    } else {
      OF = undefined;
    };
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
    (Ok(), result)
  }
}

// =========================================================================
// Generic shift/rotate handler for Group 2
//
// For register operands, delegates to existing exec_ functions.
// For memory operands, reads/shifts/writes back inline.
// =========================================================================

val exec_shift_rm : (range(0, 7), RM, byte, OperandSize, Prefixes) -> ExecutionResult
function exec_shift_rm(shift_op, rm, count_raw, os, pfx) = {
  // Mask count first — if zero, the entire operation is a no-op (no
  // flags change, no memory write).
  let masked : range(0, 63) = match os {
    OS64 => unsigned(count_raw) % 64,
    _    => unsigned(count_raw) % 32,
  };
  if masked == 0 then {
    // Even with count=0, 32-bit operations zero-extend the upper 32 bits.
    if os == OS32 then {
      let src_val = read_rm_val(rm, os, pfx.has_rex);
      write_rm_val(rm, os, pfx.has_rex, src_val)
    };
    Ok()
  } else {
    let src_val = read_rm_val(rm, os, pfx.has_rex);
    let (result, new_val) : (ExecutionResult, qword) = match shift_op {
      0 => exec_rol(src_val, count_raw, os),
      1 => exec_ror(src_val, count_raw, os),
      2 => exec_rcl(src_val, count_raw, os),
      3 => exec_rcr(src_val, count_raw, os),
      4 => exec_shl(src_val, count_raw, os),
      5 => exec_shr(src_val, count_raw, os),
      6 => exec_shl(src_val, count_raw, os),  // SAL = SHL
      7 => exec_sar(src_val, count_raw, os),
    };
    write_rm_val(rm, os, pfx.has_rex, new_val);
    result
  }
}

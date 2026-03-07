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
      // CALL near indirect (f64 — defaults to 64-bit)
      let os = get_operand_size_d64(pfx);
      let target = read_rm_val(rm, os, pfx.has_rex);
      let return_addr = decode_pos;
      match os {
        OS64 => push64(return_addr),
        OS32 => push64(zero_extend(return_addr[31..0])),
        OS16 => push16(return_addr[15..0]),
        _ => (),
      };
      RIP = target;
      decode_pos = target;
      Ok()
    },
    4 => {
      // JMP near indirect (f64)
      let target = read_rm_val(rm, OS64, pfx.has_rex);
      exec_jmp_abs(target)
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
  if masked == 0 then Ok()
  else {
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

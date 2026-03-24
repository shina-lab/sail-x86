// x86-64 — Group Instruction Helpers (INC/DEC, shifts, MUL/DIV, etc.)
//
// Computes dest := dest + 1. Updates OF, SF, ZF, AF, PF. CF unchanged.

val exec_inc : forall 'os, 'os in {8, 16, 32, 64}. (bits('os)) -> bits('os)
function exec_inc(a) = {
  let result = a + 1;
  update_flags_add_no_cf(result, a, zero_extend(0b1));
  result
}

// DEC — Decrement by 1
//
// Computes dest := dest - 1. Updates OF, SF, ZF, AF, PF. CF unchanged.

val exec_dec : forall 'os, 'os in {8, 16, 32, 64}. (bits('os)) -> bits('os)
function exec_dec(a) = {
  let result = a - 1;
  update_flags_sub_no_cf(result, a, zero_extend(0b1));
  result
}

// MUL — Unsigned Multiply

val exec_mul : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), bits('os)) -> unit
function exec_mul(os, src) = {
  if os == 8 then {
    let a : int = unsigned(reg(8, RAX));
    let b : int = unsigned(src);
    let result : word = to_bits_truncate(a * b);
    reg(RAX) = result;
    CF = is_nonzero(result[15..8]);
    OF = CF;
  } else {
    let a : int = unsigned(reg(os, RAX));
    let b : int = unsigned(src);
    let result : bits('os * 2) = to_bits_truncate(a * b);
    let lo = result[(os - 1)..0];
    let hi = result[(os * 2 - 1)..os];
    reg(RAX) = lo;
    reg(RDX) = hi;
    CF = is_nonzero(hi);
    OF = CF;
  }
}

// DIV — Unsigned Divide
// SDM: CF, OF, SF, ZF, AF, PF are undefined after DIV.

val exec_div : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), bits('os)) -> unit
function exec_div(os, src) = {
  if os == 8 then {
    let divisor = unsigned(src);
    if divisor == 0 then raise_DE();
    assert(divisor > 0);
    let dividend = unsigned(reg(16, RAX));
    let quotient = dividend / divisor;
    let remainder = dividend - quotient * divisor;
    if quotient > 255 then raise_DE();
    reg(RAX) = to_bits_truncate(8, remainder) @ to_bits_truncate(8, quotient);
  } else {
    let divisor = unsigned(src);
    if divisor == 0 then raise_DE();
    assert(divisor > 0);
    let dividend = unsigned(reg(os, RDX) @ reg(os, RAX));
    let quotient = dividend / divisor;
    let remainder = dividend - quotient * divisor;
    if quotient > (pow2(os) - 1) then raise_DE();
    let q_bits : bits('os * 2) = to_bits_truncate(quotient);
    let r_bits : bits('os * 2) = to_bits_truncate(remainder);
    reg(RAX) = q_bits[(os - 1)..0];
    reg(RDX) = r_bits[(os - 1)..0]
  };
  CF = undefined;
  OF = undefined;
  SF = undefined;
  ZF = undefined;
  AF = undefined;
  PF = undefined
}

// IDIV — Signed Divide
// SDM: CF, OF, SF, ZF, AF, PF are undefined after IDIV.

val exec_idiv : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), bits('os)) -> unit
function exec_idiv(os, src) = {
  if os == 8 then {
    let divisor = signed(src);
    if divisor == 0 then raise_DE();
    assert(divisor != 0);
    let dividend = signed(reg(16, RAX));
    let quotient = quot_round_zero(dividend, divisor);
    let remainder = rem_round_zero(dividend, divisor);
    if quotient < -128 | 127 < quotient then raise_DE();
    reg(RAX) = to_bits_truncate(8, remainder) @ to_bits_truncate(8, quotient)
  } else {
    let divisor = signed(src);
    if divisor == 0 then raise_DE();
    assert(divisor != 0);
    let dividend = signed(reg(os, RDX) @ reg(os, RAX));
    let quotient = quot_round_zero(dividend, divisor);
    let remainder = rem_round_zero(dividend, divisor);
    if quotient < -pow2(os - 1) | (pow2(os - 1) - 1) < quotient then raise_DE();
    let q_bits : bits('os * 2) = to_bits_truncate(quotient);
    let r_bits : bits('os * 2) = to_bits_truncate(remainder);
    reg(RAX) = q_bits[(os - 1)..0];
    reg(RDX) = r_bits[(os - 1)..0]
  };
  CF = undefined;
  OF = undefined;
  SF = undefined;
  ZF = undefined;
  AF = undefined;
  PF = undefined
}

// IMUL — Signed Multiply (one-operand form)

val exec_imul_1 : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), bits('os)) -> unit
function exec_imul_1(os, src) = {
  if os == 8 then {
    let a : int = signed(reg(8, RAX));
    let b : int = signed(src);
    let product : int = a * b;
    let result : word = to_bits_truncate(product);
    reg(RAX) = result;
    CF = is_nonzero(result[15..8] ^ sign_extend(result[7]));
    OF = CF;
  } else {
    let a : int = signed(reg(os, RAX));
    let b : int = signed(src);
    let product : int = a * b;
    let result : bits('os * 2) = to_bits_truncate(product);
    let lo = result[(os - 1)..0];
    let hi = result[(os * 2 - 1)..os];
    reg(RAX) = lo;
    reg(RDX) = hi;
    CF = is_nonzero(hi ^ sign_extend(lo[os - 1]));
    OF = CF;
  }
}

// PUSH imm

val exec_push_imm : forall 'os, 'os in {16, 32, 64}. (bits('os), int('os)) -> unit
function exec_push_imm(imm, os) = {
  match os {
    16 => push16(imm),
    32 => if cur_mode == LongMode then push64(sign_extend(imm)) else push32(imm),
    64 => push64(imm),
  }
}

// =========================================================================
// Group 3 (F6): Unary byte operations
// =========================================================================

val dispatch_group3_byte : (range(0, 7), RM) -> unit
function dispatch_group3_byte(reg_field, dest) = {
  if reg_field == 0 | reg_field == 1 then {
    // TEST r/m8, imm8
    // Fetch imm BEFORE reading dest so decode_pos is final for RIP-relative fixup
    let imm : byte = fetch_byte();
    let v = rm(8, dest);
    let result = v & imm;
    update_flags_logic(result)
  } else {
    let v = rm(8, dest);
    match reg_field {
      0 => (),  // unreachable, handled above
      1 => (),  // unreachable, handled above
      // NOT r/m8
      2 => {
        let result = v ^ 0xFF;
        rm(dest) = result
      },
      // NEG r/m8
      3 => {
        let zero : byte = zeros();
        let result = zero - v;
        update_flags_sub(result, zero, v);
        rm(dest) = result
      },
      4 => exec_mul(v),
      5 => exec_imul_1(v),
      6 => exec_div(v),
      7 => exec_idiv(v),
    }
  }
}

// =========================================================================
// Group 3 (F7): Unary word/dword/qword operations
// =========================================================================

val dispatch_group3 : (range(0, 7), RM, {16, 32, 64}) -> unit
function dispatch_group3(reg_field, dest, os) = {
  if reg_field == 0 | reg_field == 1 then {
    // TEST r/m, imm (Iz)
    // Fetch imm BEFORE reading dest so decode_pos is final for RIP-relative fixup
    let imm = fetch_imm_z(os);
    let v = rm(os, dest);
    let result = v & imm[(os - 1) .. 0];
    update_flags_logic(result)
  } else {
    let v = rm(os, dest);
    match reg_field {
      0 => (),  // unreachable
      1 => (),  // unreachable
      // NOT r/m
      2 => {
        let result = ~(v);
        rm(os, dest) = result
      },
      // NEG r/m
      3 => {
        let result = zeros() - v;
        update_flags_sub(result, zeros(), v);
        rm(os, dest) = result
      },
      4 => exec_mul(v),
      5 => exec_imul_1(v),
      6 => exec_div(v),
      7 => exec_idiv(v),
    }
  }
}

// =========================================================================
// Group 5 (FF): INC/DEC/CALL/JMP/PUSH
// =========================================================================

val dispatch_group5 : (range(0, 7), RM, Prefixes) -> unit
function dispatch_group5(reg_field, dest, pfx) = {
  match reg_field {
    // INC r/m
    0 => {
      let os = get_operand_size(pfx);
      let v = rm(os, dest);
      let result = exec_inc(v);
      rm(os, dest) = result
    },
    // DEC r/m
    1 => {
      let os = get_operand_size(pfx);
      let v = rm(os, dest);
      let result = exec_dec(v);
      rm(os, dest) = result
    },
    // CALL near indirect (f64 — forced to 64-bit in 64-bit mode)
    // SDM: "operand size for near call is forced to 64-bits" in 64-bit mode.
    // 66h prefix is ignored; 16/32-bit forms are N.E. (Not Encodable).
    2 => {
      let os = get_operand_size_f64(pfx);
      let target : qword = zero_extend(rm(os, dest));
      let return_addr = decode_pos;
      match os {
        16 => push16(return_addr[15..0]),
        32 => push32(return_addr[31..0]),
        64 => push64(return_addr),
      };
      next_rip = Some(target)
    },
    // JMP near indirect (f64)
    4 => {
      let os = get_operand_size_f64(pfx);
      let target : qword = zero_extend(rm(os, dest));
      next_rip = Some(target)
    },
    // PUSH r/m (d64)
    6 => {
      let os = get_operand_size_d64(pfx);
      let v = rm(os, dest);
      exec_push_imm(v, os)
    },
    // CALL far indirect m16:16/m16:32/m16:64
    // Memory operand contains offset (16/32/64 bits) then selector (16 bits).
    // Register form is #UD.
    3 => {
      match dest {
        RM_reg(_, _) => raise_UD(),
        RM_mem(seg, offset) => {
          let os = get_operand_size(pfx);
          let off_size : int = os / 8;
          let a = seg_linear(seg, offset, off_size + 2);
          let far_offset : qword = zero_extend(mem_read(os / 8, a));
          let far_selector : word = mem_read(a + off_size);
          match cur_mode {
            RealMode => {
              match os {
                16 => { push16(read_segreg(CS)); push16(decode_pos[15..0]) },
                _  => { push32(zero_extend(read_segreg(CS))); push32(decode_pos[31..0]) },
              };
              load_segment_register(CS, far_selector);
              let target : qword = match os {
                16 => zero_extend(far_offset[15..0]),
                _    => zero_extend(far_offset[31..0]),
              };
              next_rip = Some(target)
            },
            _ => exec_far_call_protected(far_selector, far_offset, os),
          }
        },
      }
    },
    // JMP far indirect m16:16/m16:32/m16:64
    // Memory operand contains offset (16/32/64 bits) then selector (16 bits).
    // Register form is #UD.
    5 => {
      match dest {
        RM_reg(_, _) => raise_UD(),
        RM_mem(seg, offset) => {
          let os = get_operand_size(pfx);
          let off_size : int = os / 8;
          let a = seg_linear(seg, offset, off_size + 2);
          let far_offset : qword = zero_extend(mem_read(os / 8, a));
          let far_selector : word = mem_read(a + off_size);
          match cur_mode {
            RealMode => {
              load_segment_register(CS, far_selector);
              let target : qword = match os {
                16 => zero_extend(far_offset[15..0]),
                _    => zero_extend(far_offset[31..0]),
              };
              next_rip = Some(target)
            },
            _ => exec_far_jmp_protected(far_selector, far_offset, os),
          }
        },
      }
    },
    // 7: reserved
    7 => raise_UD(),
  }
}

// SHL/SAL — Shift Left
//
// Shifts dest left by count bits. CF = last bit shifted out.
// If count=0, flags unchanged. If count=1, OF = MSB(result) XOR CF.
// SF, ZF, PF set from result. AF undefined for count != 0.

val exec_shl : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), bits('os), byte) -> bits('os)
function exec_shl(os, a, count_raw) = {
  let count : range(0, 63) = match os {
    64 => unsigned(count_raw) % 64,
    _  => unsigned(count_raw) % 32,
  };
  if count == 0 then {
    a
  } else {
    let result : bits('os) = a << count;
    CF = if count <= os then a[os - count] else undefined;
    update_SF_ZF_PF(result);
    if count == 1 then OF = result[os - 1] ^ CF
    else OF = undefined;
    AF = undefined;
    result
  }
}

// SHR — Shift Right (Logical)
//
// Shifts dest right by count bits, filling with zeros.
// CF = last bit shifted out. If count=1, OF = MSB(original).
// SF, ZF, PF set from result. AF undefined for count != 0.

val exec_shr : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), bits('os), byte) -> bits('os)
function exec_shr(os, a, count_raw) = {
  let mod_val : range(32, 64) = if os == 64 then 64 else 32;
  let count : range(0, 63) = unsigned(count_raw) % mod_val;
  if count == 0 then {
    a
  } else {
    let result : bits('os) = a >> count;
    CF = if count <= os then a[count - 1] else undefined;
    update_SF_ZF_PF(result);
    if count == 1 then OF = a[os - 1]
    else OF = undefined;
    AF = undefined;
    result
  }
}

// SAR — Shift Right (Arithmetic)
//
// Shifts dest right by count bits, preserving sign bit.
// CF = last bit shifted out. OF cleared for count=1.
// SF, ZF, PF set from result. AF undefined for count != 0.

val exec_sar : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), bits('os), byte) -> bits('os)
function exec_sar(os, a, count_raw) = {
  let mod_val : range(32, 64) = if os == 64 then 64 else 32;
  let count : range(0, 63) = unsigned(count_raw) % mod_val;
  if count == 0 then {
    a
  } else {
    // CF = last bit shifted out. For SAR, when count >= operand width,
    // the result is all-sign-bits, so CF = sign bit of the original value.
    // SDM pseudocode iterates: CF := LSB(DEST) each step with signed divide.
    let cf_idx : range(0, 63) = if count >= os then os - 1 else count - 1;
    assert(cf_idx < os);
    CF = a[cf_idx];
    let result : bits('os) = a >>> count;
    update_SF_ZF_PF(result);
    if count == 1 then OF = 0b0
    else OF = undefined;
    AF = undefined;
    result
  }
}

// ROL — Rotate Left
// ROR — Rotate Right
//
// ROL: Rotates bits left. CF = LSB(result) after rotate.
// ROR: Rotates bits right. CF = MSB(result) after rotate.
// OF defined only for count=1. SF, ZF, AF, PF unaffected.
// Count is masked to 5 bits (6 bits for 64-bit operands).

val exec_rol : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), bits('os), byte) -> bits('os)
function exec_rol(os, a, count_raw) = {
  let count : range(0, 63) = match os {
    64 => unsigned(count_raw) % 64,
    _  => unsigned(count_raw) % 32,
  };
  if count == 0 then {
    a
  } else {
    let result : bits('os) = rotl(a, count % os);
    CF = result[0];
    if count == 1 then
      OF = result[os - 1 .. os - 1] ^ CF
    else
      OF = undefined;
    result
  }
}

val exec_ror : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), bits('os), byte) -> bits('os)
function exec_ror(os, a, count_raw) = {
  let count : range(0, 63) = match os {
    64 => unsigned(count_raw) % 64,
    _  => unsigned(count_raw) % 32,
  };
  if count == 0 then {
    a
  } else {
    let result : bits('os) = rotr(a, count % os);
    CF = result[os - 1];
    if count == 1 then
      OF = result[os - 1 .. os - 1] ^ result[os - 2 .. os - 2]
    else
      OF = undefined;
    result
  }
}

// RCL — Rotate Through Carry Left
// RCR — Rotate Through Carry Right
//
// RCL: Rotates (n+1)-bit value (CF:dest) left by count.
// RCR: Rotates (n+1)-bit value (CF:dest) right by count.
// OF defined only for count=1. Count masked to 5 bits (6 for 64-bit).

val exec_rcl : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), bits('os), byte) -> bits('os)
function exec_rcl(os, a, count_raw) = {
  let masked : range(0, 63) = match os {
    64 => unsigned(count_raw) % 64,
    _  => unsigned(count_raw) % 32,
  };
  let c = masked % (os + 1);
  if c == 0 then {
    a
  } else {
    let wide = a @ CF;
    let rotated = rotl(wide, c);
    CF = rotated[0];
    if masked == 1 then
      OF = rotated[os] ^ rotated[0]
    else
      OF = undefined;
    rotated[os..1]
  }
}

val exec_rcr : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), bits('os), byte) -> bits('os)
function exec_rcr(os, a, count_raw) = {
  let masked : range(0, 63) = match os {
    64 => unsigned(count_raw) % 64,
    _  => unsigned(count_raw) % 32,
  };
  let c = masked % (os + 1);
  if c == 0 then {
    a
  } else {
    // OF is set from original value before rotation for RCR
    if masked == 1 then
      OF = a[os - 1] ^ CF
    else
      OF = undefined;
    let wide = a @ CF;
    let rotated = rotr(wide, c);
    CF = rotated[0];
    rotated[os..1]
  }
}

// =========================================================================
// Generic shift/rotate handler for Group 2
//
// For register operands, delegates to existing exec_ functions.
// For memory operands, reads/shifts/writes back inline.
// =========================================================================

val exec_shift_rm : forall 'os, 'os in {8, 16, 32, 64}. (range(0, 7), RM, byte, int('os)) -> unit
function exec_shift_rm(shift_op, dest, count_raw, os) = {
  // Mask count first — if zero, the entire operation is a no-op (no
  // flags change, no memory write).
  let masked : range(0, 63) = match os {
    64 => unsigned(count_raw) % 64,
    _  => unsigned(count_raw) % 32,
  };
  if masked == 0 then {
    // Even with count=0, 32-bit operations zero-extend the upper 32 bits.
    if os == 32 then {
      let src_val = rm(os, dest);
      rm(os, dest) = src_val
    }
  } else {
    let src_val = rm(os, dest);
    let new_val : bits('os) = match shift_op {
      0 => exec_rol(src_val, count_raw),
      1 => exec_ror(src_val, count_raw),
      2 => exec_rcl(src_val, count_raw),
      3 => exec_rcr(src_val, count_raw),
      4 => exec_shl(src_val, count_raw),
      5 => exec_shr(src_val, count_raw),
      6 => exec_shl(src_val, count_raw),  // SAL = SHL
      7 => exec_sar(src_val, count_raw),
    };
    rm(os, dest) = new_val
  }
}

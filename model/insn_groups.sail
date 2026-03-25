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
  let product : int = unsigned(v(os, RAX)) * unsigned(src);
  let result : bits('os * 2) = to_bits_truncate(product);
  if os == 8 then {
    v(RAX) = result;
  } else {
    v(RAX) = result[(os - 1)..0];
    v(RDX) = result[(os * 2 - 1)..os];
  };
  CF = is_nonzero(result[(os * 2 - 1)..os]);
  OF = CF
}

// DIV — Unsigned Divide
// SDM: CF, OF, SF, ZF, AF, PF are undefined after DIV.
val exec_div : forall 'os, 'os in {8, 16, 32, 64}. (implicit('os), bits('os)) -> unit
function exec_div(os, src) = {
  let divisor = unsigned(src);
  if divisor == 0 then raise_DE();
  assert(divisor > 0);
  let dividend = if os == 8
    then unsigned(v(16, RAX))
    else unsigned(v(os, RDX) @ v(os, RAX));
  let quotient = dividend / divisor;
  let remainder = dividend - quotient * divisor;
  if quotient > (pow2(os) - 1) then raise_DE();
  let q_bits = to_bits_truncate(os, quotient);
  let r_bits = to_bits_truncate(os, remainder);
  if os == 8 then {
    v(RAX) = r_bits @ q_bits
  } else {
    v(RAX) = q_bits;
    v(RDX) = r_bits
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
  let divisor = signed(src);
  if divisor == 0 then raise_DE();
  assert(divisor != 0);
  let dividend = if os == 8
    then signed(v(16, RAX))
    else signed(v(os, RDX) @ v(os, RAX));
  let quotient = quot_round_zero(dividend, divisor);
  let remainder = rem_round_zero(dividend, divisor);
  if quotient < -pow2(os - 1) | (pow2(os - 1) - 1) < quotient then raise_DE();
  let q_bits = to_bits_truncate(os, quotient);
  let r_bits = to_bits_truncate(os, remainder);
  if os == 8 then {
    v(RAX) = r_bits @ q_bits
  } else {
    v(RAX) = q_bits;
    v(RDX) = r_bits
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
  let product : int = signed(v(os, RAX)) * signed(src);
  let result : bits('os * 2) = to_bits_truncate(product);
  if os == 8 then {
    v(RAX) = result;
  } else {
    v(RAX) = result[(os - 1)..0];
    v(RDX) = result[(os * 2 - 1)..os];
  };
  CF = is_nonzero(result[(os * 2 - 1)..os] ^ sign_extend(result[os - 1]));
  OF = CF
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
    update_flags_logic(v(8, dest) & imm)
  } else {
    let x = v(8, dest);
    match reg_field {
      0 => (),  // unreachable, handled above
      1 => (),  // unreachable, handled above
      // NOT r/m8
      2 => v(dest) = x ^ 0xFF,
      // NEG r/m8
      3 => {
        let result = zeros() - x;
        update_flags_sub(result, zeros(), x);
        v(dest) = result
      },
      4 => exec_mul(x),
      5 => exec_imul_1(x),
      6 => exec_div(x),
      7 => exec_idiv(x),
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
    update_flags_logic(v(os, dest) & imm[(os - 1) .. 0])
  } else {
    let x = v(os, dest);
    match reg_field {
      0 => (),  // unreachable
      1 => (),  // unreachable
      // NOT r/m
      2 => v(dest) = ~(x),
      // NEG r/m
      3 => {
        let result = zeros() - x;
        update_flags_sub(result, zeros(), x);
        v(os, dest) = result
      },
      4 => exec_mul(x),
      5 => exec_imul_1(x),
      6 => exec_div(x),
      7 => exec_idiv(x),
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
      let os = opsize(pfx);
      v(dest) = exec_inc(v(os, dest))
    },
    // DEC r/m
    1 => {
      let os = opsize(pfx);
      v(dest) = exec_dec(v(os, dest))
    },
    // CALL near indirect (f64 — forced to 64-bit in 64-bit mode)
    // SDM: "operand size for near call is forced to 64-bits" in 64-bit mode.
    // 66h prefix is ignored; 16/32-bit forms are N.E. (Not Encodable).
    2 => {
      let os = opsize_forced64(pfx);
      let target : qword = zero_extend(v(os, dest));
      let return_addr = decode_pos;
      match os {
        16 => push16(return_addr[15..0]),
        32 => push32(return_addr[31..0]),
        64 => push64(return_addr),
      };
      next_rip = Some(target)
    },
    // JMP near indirect (f64)
    4 => next_rip = Some(zero_extend(v(opsize_forced64(pfx), dest))),
    // PUSH r/m (d64)
    6 => {
      let os = opsize_default64(pfx);
      exec_push_imm(v(os, dest), os)
    },
    // CALL far indirect m16:16/m16:32/m16:64
    // Memory operand contains offset (16/32/64 bits) then selector (16 bits).
    // Register form is #UD.
    3 => {
      match dest {
        RM_reg(_) => raise_UD(),
        RM_mem(m) => {
          let os = opsize(pfx);
          let off_size : int = os / 8;
          let a = seg_linear(m, off_size + 2);
          let far_offset : qword = zero_extend(read_mem(os, a));
          let far_selector : word = read_mem(a + off_size);
          match cur_mode {
            RealMode => {
              match os {
                16 => { push16(read_segreg(CS)); push16(decode_pos[15..0]) },
                _  => { push32(zero_extend(read_segreg(CS))); push32(decode_pos[31..0]) },
              };
              load_segment_register(CS, far_selector);
              next_rip = Some(match os {
                16 => zero_extend(far_offset[15..0]),
                _    => zero_extend(far_offset[31..0]),
              })
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
        RM_reg(_) => raise_UD(),
        RM_mem(m) => {
          let os = opsize(pfx);
          let off_size : int = os / 8;
          let a = seg_linear(m, off_size + 2);
          let far_offset : qword = zero_extend(read_mem(os, a));
          let far_selector : word = read_mem(a + off_size);
          match cur_mode {
            RealMode => {
              load_segment_register(CS, far_selector);
              next_rip = Some(match os {
                16 => zero_extend(far_offset[15..0]),
                _    => zero_extend(far_offset[31..0]),
              })
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
val exec_shl : forall 'os, 'os in {8, 16, 32, 64}. (bits('os), byte) -> bits('os)
function exec_shl(a, count_raw) = {
  let count : range(0, 63) = match 'os {
    64 => unsigned(count_raw) % 64,
    _  => unsigned(count_raw) % 32,
  };
  let count_bv : bits(6) = to_bits(6, count);
  let count_nz : bit = is_nonzero(count_bv);
  let old_CF = CF; let old_OF = OF; let old_SF = SF;
  let old_ZF = ZF; let old_PF = PF; let old_AF = AF;
  let result : bits('os) = a << count;
  let cf_count : range(0, 64) = count + unsigned(is_zero(count_bv));
  let cf_idx : range(0, 63) = ('os + 64 - cf_count) % 64;
  let a_ext : bits(64) = zero_extend(a);
  CF = a_ext[cf_idx];
  update_SF_ZF_PF(result);
  OF = result['os - 1] ^ CF;
  AF = undefined;
  // OF defined only for count==1; undefined otherwise
  OF = blend(undefined, OF, is_eq(count_bv, 0b000001));
  // CF undefined when count > operand size (possible for 8/16-bit)
  CF = blend(CF, undefined, is_gt_u(to_bits(7, count), to_bits(7, 'os)));
  // When count==0: restore all flags and return original value
  CF = blend(old_CF, CF, count_nz);
  OF = blend(old_OF, OF, count_nz);
  SF = blend(old_SF, SF, count_nz);
  ZF = blend(old_ZF, ZF, count_nz);
  PF = blend(old_PF, PF, count_nz);
  AF = blend(old_AF, AF, count_nz);
  blend(a, result, count_nz)
}

// SHR — Shift Right (Logical)
//
// Shifts dest right by count bits, filling with zeros.
// CF = last bit shifted out. If count=1, OF = MSB(original).
// SF, ZF, PF set from result. AF undefined for count != 0.
val exec_shr : forall 'os, 'os in {8, 16, 32, 64}. (bits('os), byte) -> bits('os)
function exec_shr(a, count_raw) = {
  let mod_val : range(32, 64) = if 'os == 64 then 64 else 32;
  let count : range(0, 63) = unsigned(count_raw) % mod_val;
  let count_bv : bits(6) = to_bits(6, count);
  let count_nz : bit = is_nonzero(count_bv);
  let old_CF = CF; let old_OF = OF; let old_SF = SF;
  let old_ZF = ZF; let old_PF = PF; let old_AF = AF;
  let result : bits('os) = a >> count;
  let cf_count : range(0, 64) = count + unsigned(is_zero(count_bv));
  assert(cf_count >= 1);
  let a_ext : bits(64) = zero_extend(a);
  CF = a_ext[cf_count - 1];
  update_SF_ZF_PF(result);
  OF = a['os - 1];
  AF = undefined;
  // OF defined only for count==1; undefined otherwise
  OF = blend(undefined, OF, is_eq(count_bv, 0b000001));
  // CF undefined when count > operand size (possible for 8/16-bit)
  CF = blend(CF, undefined, is_gt_u(to_bits(7, count), to_bits(7, 'os)));
  CF = blend(old_CF, CF, count_nz);
  OF = blend(old_OF, OF, count_nz);
  SF = blend(old_SF, SF, count_nz);
  ZF = blend(old_ZF, ZF, count_nz);
  PF = blend(old_PF, PF, count_nz);
  AF = blend(old_AF, AF, count_nz);
  blend(a, result, count_nz)
}

// SAR — Shift Right (Arithmetic)
//
// Shifts dest right by count bits, preserving sign bit.
// CF = last bit shifted out. OF cleared for count=1.
// SF, ZF, PF set from result. AF undefined for count != 0.
val exec_sar : forall 'os, 'os in {8, 16, 32, 64}. (bits('os), byte) -> bits('os)
function exec_sar(a, count_raw) = {
  let mod_val : range(32, 64) = if 'os == 64 then 64 else 32;
  let count : range(0, 63) = unsigned(count_raw) % mod_val;
  let count_bv : bits(6) = to_bits(6, count);
  let count_nz : bit = is_nonzero(count_bv);
  let old_CF = CF; let old_OF = OF; let old_SF = SF;
  let old_ZF = ZF; let old_PF = PF; let old_AF = AF;
  let cf_count : range(0, 64) = count + unsigned(is_zero(count_bv));
  assert(cf_count >= 1);
  let cf_idx_bv : bits(7) = min_u(to_bits(7, cf_count - 1), to_bits(7, 'os - 1));
  let cf_idx = unsigned(cf_idx_bv);
  assert(cf_idx < 'os);
  CF = a[cf_idx];
  let result : bits('os) = a >>> count;
  update_SF_ZF_PF(result);
  OF = 0b0;
  AF = undefined;
  // OF defined only for count==1; undefined otherwise
  OF = blend(undefined, OF, is_eq(count_bv, 0b000001));
  CF = blend(old_CF, CF, count_nz);
  OF = blend(old_OF, OF, count_nz);
  SF = blend(old_SF, SF, count_nz);
  ZF = blend(old_ZF, ZF, count_nz);
  PF = blend(old_PF, PF, count_nz);
  AF = blend(old_AF, AF, count_nz);
  blend(a, result, count_nz)
}

// ROL — Rotate Left
// ROR — Rotate Right
//
// ROL: Rotates bits left. CF = LSB(result) after rotate.
// ROR: Rotates bits right. CF = MSB(result) after rotate.
// OF defined only for count=1. SF, ZF, AF, PF unaffected.
// Count is masked to 5 bits (6 bits for 64-bit operands).
val exec_rol : forall 'os, 'os in {8, 16, 32, 64}. (bits('os), byte) -> bits('os)
function exec_rol(a, count_raw) = {
  let count : range(0, 63) = match 'os {
    64 => unsigned(count_raw) % 64,
    _  => unsigned(count_raw) % 32,
  };
  let count_nz : bit = is_nonzero(to_bits(6, count));
  let old_CF = CF; let old_OF = OF;
  let result : bits('os) = rotl(a, count % 'os);
  CF = result[0];
  OF = result['os - 1] ^ CF;
  // OF defined only for count==1; undefined otherwise
  OF = blend(undefined, OF, is_eq(to_bits(6, count), 0b000001));
  CF = blend(old_CF, CF, count_nz);
  OF = blend(old_OF, OF, count_nz);
  blend(a, result, count_nz)
}

val exec_ror : forall 'os, 'os in {8, 16, 32, 64}. (bits('os), byte) -> bits('os)
function exec_ror(a, count_raw) = {
  let count : range(0, 63) = match 'os {
    64 => unsigned(count_raw) % 64,
    _  => unsigned(count_raw) % 32,
  };
  let count_nz : bit = is_nonzero(to_bits(6, count));
  let old_CF = CF; let old_OF = OF;
  let result : bits('os) = rotr(a, count % 'os);
  CF = result['os - 1];
  OF = result['os - 1] ^ result['os - 2];
  // OF defined only for count==1; undefined otherwise
  OF = blend(undefined, OF, is_eq(to_bits(6, count), 0b000001));
  CF = blend(old_CF, CF, count_nz);
  OF = blend(old_OF, OF, count_nz);
  blend(a, result, count_nz)
}

// RCL — Rotate Through Carry Left
// RCR — Rotate Through Carry Right
//
// RCL: Rotates (n+1)-bit value (CF:dest) left by count.
// RCR: Rotates (n+1)-bit value (CF:dest) right by count.
// OF defined only for count=1. Count masked to 5 bits (6 for 64-bit).
val exec_rcl : forall 'os, 'os in {8, 16, 32, 64}. (bits('os), byte) -> bits('os)
function exec_rcl(a, count_raw) = {
  let masked : range(0, 63) = match 'os {
    64 => unsigned(count_raw) % 64,
    _  => unsigned(count_raw) % 32,
  };
  let c = masked % ('os + 1);
  let c_nz : bit = is_nonzero(to_bits(6, c));
  let old_CF = CF; let old_OF = OF;
  let wide = a @ CF;
  let rotated = rotl(wide, c);
  CF = rotated[0];
  OF = rotated['os] ^ rotated[0];
  // OF defined only for masked==1; undefined otherwise
  OF = blend(undefined, OF, is_eq(to_bits(6, masked), 0b000001));
  CF = blend(old_CF, CF, c_nz);
  OF = blend(old_OF, OF, c_nz);
  blend(a, rotated['os..1], c_nz)
}

val exec_rcr : forall 'os, 'os in {8, 16, 32, 64}. (bits('os), byte) -> bits('os)
function exec_rcr(a, count_raw) = {
  let masked : range(0, 63) = match 'os {
    64 => unsigned(count_raw) % 64,
    _  => unsigned(count_raw) % 32,
  };
  let c = masked % ('os + 1);
  let c_nz : bit = is_nonzero(to_bits(6, c));
  let old_CF = CF; let old_OF = OF;
  // OF is set from original value before rotation for RCR
  OF = a['os - 1] ^ CF;
  // OF defined only for masked==1; undefined otherwise
  OF = blend(undefined, OF, is_eq(to_bits(6, masked), 0b000001));
  let wide = a @ CF;
  let rotated = rotr(wide, c);
  CF = rotated[0];
  CF = blend(old_CF, CF, c_nz);
  OF = blend(old_OF, OF, c_nz);
  blend(a, rotated['os..1], c_nz)
}

// =========================================================================
// Generic shift/rotate handler for Group 2
//
// For register operands, delegates to existing exec_ functions.
// For memory operands, reads/shifts/writes back inline.
// =========================================================================
val exec_shift_rm : forall 'os, 'os in {8, 16, 32, 64}. (range(0, 7), RM, byte, int('os)) -> unit
function exec_shift_rm(shift_op, dest, count_raw, os) = {
  // exec_* functions handle count==0 via blend (return original, flags preserved).
  let src_val = v(os, dest);
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
  v(os, dest) = new_val
}

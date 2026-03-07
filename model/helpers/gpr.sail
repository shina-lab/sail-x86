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
  (Ok(()), result)
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
  (Ok(()), result)
}
// MUL — Unsigned Multiply
//
// Multiplies AL/AX/EAX/RAX by source, storing double-width result.
// CF and OF set if upper half is non-zero. SF, ZF, AF, PF undefined.

val exec_mul : (qword, OperandSize) -> ExecutionResult
function exec_mul(src, os) = {
  match os {
    OS8 => {
      let a : int = unsigned(read_gpr8l(RAX));
      let b : int = unsigned(src[7..0]);
      let result : word = to_bits_truncate(a * b);
      write_gpr16(RAX, result);
      let hi_zero : bool = result[15..8] == zeros();
      CF = if hi_zero then bitzero else bitone;
      OF = CF;
    },
    OS16 => {
      let a : int = unsigned(read_gpr16(RAX));
      let b : int = unsigned(src[15..0]);
      let result : dword = to_bits_truncate(a * b);
      write_gpr16(RAX, result[15..0]);
      write_gpr16(RDX, result[31..16]);
      let hi_zero : bool = result[31..16] == zeros();
      CF = if hi_zero then bitzero else bitone;
      OF = CF;
    },
    OS32 => {
      let a : int = unsigned(read_gpr32(RAX));
      let b : int = unsigned(src[31..0]);
      let result : qword = to_bits_truncate(a * b);
      write_gpr32(RAX, result[31..0]);
      write_gpr32(RDX, result[63..32]);
      let hi_zero : bool = result[63..32] == zeros();
      CF = if hi_zero then bitzero else bitone;
      OF = CF;
    },
    OS64 => {
      let a : int = unsigned(read_gpr64(RAX));
      let b : int = unsigned(src);
      let product : int = a * b;
      let result : xmmword = to_bits_truncate(product);
      write_gpr64(RAX, result[63..0]);
      write_gpr64(RDX, result[127..64]);
      let hi_zero : bool = result[127..64] == zeros();
      CF = if hi_zero then bitzero else bitone;
      OF = CF;
    },
  };
  Ok(())
}
// DIV — Unsigned Divide
//
// Divides the value in AX, DX:AX, EDX:EAX, or RDX:RAX (dividend)
// by the source operand (divisor). Stores quotient and remainder
// in AL:AH, AX:DX, EAX:EDX, or RAX:RDX respectively.
//
// Raises #DE on divide-by-zero or quotient overflow.
// All arithmetic flags (CF, OF, SF, ZF, AF, PF) are undefined.

// The source operand value has already been read (from register or memory)
// and zero-extended to 64 bits.
val exec_div : (qword, OperandSize) -> ExecutionResult
function exec_div(src, os) = {
  match os {
    OS8 => {
      let divisor = unsigned(src[7..0]);
      if divisor == 0 then raise_DE()
      else {
        let dividend = unsigned(read_gpr16(RAX));
        let quotient = dividend / divisor;
        let remainder = dividend - quotient * divisor;
        if quotient > 255 then raise_DE()
        else {
          write_gpr8l(RAX, to_bits_truncate(quotient));
          write_gpr8h(RAX, to_bits_truncate(remainder));
          Ok(())
        }
      }
    },
    OS16 => {
      let divisor = unsigned(src[15..0]);
      if divisor == 0 then raise_DE()
      else {
        let dividend = unsigned(read_gpr16(RDX) @ read_gpr16(RAX));
        let quotient = dividend / divisor;
        let remainder = dividend - quotient * divisor;
        if quotient > 65535 then raise_DE()
        else {
          write_gpr16(RAX, to_bits_truncate(quotient));
          write_gpr16(RDX, to_bits_truncate(remainder));
          Ok(())
        }
      }
    },
    OS32 => {
      let divisor = unsigned(src[31..0]);
      if divisor == 0 then raise_DE()
      else {
        let dividend = unsigned(read_gpr32(RDX) @ read_gpr32(RAX));
        let quotient = dividend / divisor;
        let remainder = dividend - quotient * divisor;
        if quotient > (pow2(32) - 1) then raise_DE()
        else {
          write_gpr32(RAX, to_bits_truncate(quotient));
          write_gpr32(RDX, to_bits_truncate(remainder));
          Ok(())
        }
      }
    },
    OS64 => {
      let divisor = unsigned(src);
      if divisor == 0 then raise_DE()
      else {
        let dividend = unsigned(read_gpr64(RDX) @ read_gpr64(RAX));
        let quotient = dividend / divisor;
        let remainder = dividend - quotient * divisor;
        if quotient > (pow2(64) - 1) then raise_DE()
        else {
          write_gpr64(RAX, to_bits_truncate(quotient));
          write_gpr64(RDX, to_bits_truncate(remainder));
          Ok(())
        }
      }
    },
  }
}
// IDIV — Signed Divide
//
// Signed divide of AX, DX:AX, EDX:EAX, or RDX:RAX (dividend)
// by the source operand (divisor). Quotient is truncated towards zero.
// The remainder has the same sign as the dividend.
//
// Raises #DE on divide-by-zero or quotient overflow.
// All arithmetic flags (CF, OF, SF, ZF, AF, PF) are undefined.

// The source operand value has already been read (from register or memory)
// and zero-extended to 64 bits. The relevant low bits are treated as signed.
val exec_idiv : (qword, OperandSize) -> ExecutionResult
function exec_idiv(src, os) = {
  match os {
    OS8 => {
      let divisor = signed(src[7..0]);
      if divisor == 0 then raise_DE()
      else {
        let dividend = signed(read_gpr16(RAX));
        let quotient = quot_round_zero(dividend, divisor);
        let remainder = rem_round_zero(dividend, divisor);
        if quotient > 127 | quotient < negate(128) then raise_DE()
        else {
          write_gpr8l(RAX, to_bits_truncate(quotient));
          write_gpr8h(RAX, to_bits_truncate(remainder));
          Ok(())
        }
      }
    },
    OS16 => {
      let divisor = signed(src[15..0]);
      if divisor == 0 then raise_DE()
      else {
        let dividend = signed(read_gpr16(RDX) @ read_gpr16(RAX));
        let quotient = quot_round_zero(dividend, divisor);
        let remainder = rem_round_zero(dividend, divisor);
        if quotient > 32767 | quotient < negate(32768) then raise_DE()
        else {
          write_gpr16(RAX, to_bits_truncate(quotient));
          write_gpr16(RDX, to_bits_truncate(remainder));
          Ok(())
        }
      }
    },
    OS32 => {
      let divisor = signed(src[31..0]);
      if divisor == 0 then raise_DE()
      else {
        let dividend = signed(read_gpr32(RDX) @ read_gpr32(RAX));
        let quotient = quot_round_zero(dividend, divisor);
        let remainder = rem_round_zero(dividend, divisor);
        if quotient > (pow2(31) - 1) | quotient < negate(pow2(31)) then raise_DE()
        else {
          write_gpr32(RAX, to_bits_truncate(quotient));
          write_gpr32(RDX, to_bits_truncate(remainder));
          Ok(())
        }
      }
    },
    OS64 => {
      let divisor = signed(src);
      if divisor == 0 then raise_DE()
      else {
        let dividend = signed(read_gpr64(RDX) @ read_gpr64(RAX));
        let quotient = quot_round_zero(dividend, divisor);
        let remainder = rem_round_zero(dividend, divisor);
        if quotient > (pow2(63) - 1) | quotient < negate(pow2(63)) then raise_DE()
        else {
          write_gpr64(RAX, to_bits_truncate(quotient));
          write_gpr64(RDX, to_bits_truncate(remainder));
          Ok(())
        }
      }
    },
  }
}
// IMUL — Signed Multiply
//
// One-operand form: signed multiply AL/AX/EAX/RAX by source,
// storing double-width result. CF/OF set if result sign-extends.
//
// Two-operand form: dst := dst * src (truncated).
// Three-operand form: dst := src * imm (truncated).
// CF/OF set if result was truncated. SF, ZF, AF, PF undefined.

// One-operand form (like MUL but signed)
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
      CF = if truncated then bitone else bitzero;
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
      CF = if truncated then bitone else bitzero;
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
      CF = if truncated then bitone else bitzero;
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
      CF = if truncated then bitone else bitzero;
      OF = CF;
    },
  };
  Ok(())
}

val bsf64 : (qword, range(0, 63)) -> range(0, 63)
function bsf64(v, idx) =
  if idx >= 63 then 63
  else if bit_to_bool(v[idx]) then idx
  else bsf64(v, idx + 1)

val bsr64 : (qword, range(0, 63)) -> range(0, 63)
function bsr64(v, idx) =
  if idx <= 0 then 0
  else if bit_to_bool(v[idx]) then idx
  else bsr64(v, idx - 1)

// BSWAP — Byte Swap
//
// Reverses the byte order of a 32-bit or 64-bit register.
// No flags are affected.

val exec_bswap : (gpr_idx, OperandSize) -> ExecutionResult
function exec_bswap(dst, os) = {
  match os {
    OS32 => {
      let v : dword = read_gpr32(dst);
      write_gpr32(dst, v[7..0] @ v[15..8] @ v[23..16] @ v[31..24])
    },
    OS64 => {
      let v : qword = read_gpr64(dst);
      write_gpr64(dst, v[7..0] @ v[15..8] @ v[23..16] @ v[31..24] @
                       v[39..32] @ v[47..40] @ v[55..48] @ v[63..56])
    },
    _ => (),
  };
  Ok(())
}
// XCHG — Exchange Register/Memory with Register
//
// Exchanges the values of two operands. No flags affected.

val exec_xchg_reg_reg : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_xchg_reg_reg(a, b, os) = {
  let va : qword = read_gpr(a, os);
  let vb : qword = read_gpr(b, os);
  write_gpr(a, os, vb);
  write_gpr(b, os, va);
  Ok(())
}
// XADD — Exchange and Add
//
// Exchanges dst and src, then stores sum in dst.
// TEMP := SRC + DEST; SRC := DEST; DEST := TEMP.
// Flags set from the addition.

val exec_xadd : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_xadd(dst, src, os) = {
  let a : qword = read_gpr(dst, os);
  let b : qword = read_gpr(src, os);
  let sum : qword = a + b;
  match os {
    OS8  => update_flags_add(sum[7..0], a[7..0], b[7..0]),
    OS16 => update_flags_add(sum[15..0], a[15..0], b[15..0]),
    OS32 => update_flags_add(sum[31..0], a[31..0], b[31..0]),
    OS64 => update_flags_add(sum, a, b),
  };
  write_gpr(src, os, a);
  write_gpr(dst, os, sum);
  Ok(())
}
// POPCNT — Return the Count of Number of Bits Set to 1
//
// Counts the number of set bits in source operand.
// OF, SF, AF, CF, PF are all cleared. ZF is set if source is zero.

val popcount8 : byte -> range(0, 8)
function popcount8(v) = {
  let b0 : range(0, 1) = if bit_to_bool(v[0]) then 1 else 0;
  let b1 : range(0, 1) = if bit_to_bool(v[1]) then 1 else 0;
  let b2 : range(0, 1) = if bit_to_bool(v[2]) then 1 else 0;
  let b3 : range(0, 1) = if bit_to_bool(v[3]) then 1 else 0;
  let b4 : range(0, 1) = if bit_to_bool(v[4]) then 1 else 0;
  let b5 : range(0, 1) = if bit_to_bool(v[5]) then 1 else 0;
  let b6 : range(0, 1) = if bit_to_bool(v[6]) then 1 else 0;
  let b7 : range(0, 1) = if bit_to_bool(v[7]) then 1 else 0;
  b0 + b1 + b2 + b3 + b4 + b5 + b6 + b7
}

val popcount16 : word -> range(0, 16)
function popcount16(v) =
  popcount8(v[7..0]) + popcount8(v[15..8])

val popcount32 : dword -> range(0, 32)
function popcount32(v) =
  popcount16(v[15..0]) + popcount16(v[31..16])

val popcount64 : qword -> range(0, 64)
function popcount64(v) =
  popcount32(v[31..0]) + popcount32(v[63..32])

val exec_popcnt : (gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_popcnt(dst, src_val, os) = {
  let count : range(0, 64) = match os {
    OS8  => popcount8(src_val[7..0]),
    OS16 => popcount16(src_val[15..0]),
    OS32 => popcount32(src_val[31..0]),
    OS64 => popcount64(src_val),
  };
  OF = bitzero;
  SF = bitzero;
  AF = bitzero;
  CF = bitzero;
  PF = bitzero;
  ZF = if count == 0 then bitone else bitzero;
  write_gpr(dst, os, to_bits_truncate(count));
  Ok(())
}
// LZCNT — Count the Number of Leading Zero Bits
//
// Counts leading zeros in source. If source is zero, result = operand size.
// CF set if source is zero, ZF set if result is zero.
// OF, SF, PF, AF undefined.

val lzcnt64 : (qword, range(0, 63)) -> range(0, 64)
function lzcnt64(v, idx) =
  if idx == 0 then (if bit_to_bool(v[idx]) then 0 else 64)
  else if bit_to_bool(v[idx]) then 63 - idx
  else lzcnt64(v, idx - 1)

val exec_lzcnt : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_lzcnt(dst, src, os) = {
  let src_val : qword = read_gpr(src, os);
  let os_bits : {8, 16, 32, 64} = operand_size_bits(os);
  let count : range(0, 64) = match os {
    OS8  => lzcnt64(zero_extend(src_val[7..0]), 7),
    OS16 => lzcnt64(zero_extend(src_val[15..0]), 15),
    OS32 => lzcnt64(zero_extend(src_val[31..0]), 31),
    OS64 => lzcnt64(src_val, 63),
  };
  write_gpr(dst, os, to_bits_truncate(count));
  CF = if count == os_bits then bitone else bitzero;
  ZF = if count == 0 then bitone else bitzero;
  Ok(())
}
// TZCNT — Count the Number of Trailing Zero Bits
//
// Counts trailing zeros in source. If source is zero, result = operand size.
// CF set if source is zero, ZF set if result is zero.
// OF, SF, PF, AF undefined.

val exec_tzcnt : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_tzcnt(dst, src, os) = {
  let src_val : qword = read_gpr(src, os);
  let os_bits : {8, 16, 32, 64} = operand_size_bits(os);
  // Reuse bsf64 which scans from bit 0 upward
  let is_zero : bool = match os {
    OS8  => src_val[7..0] == zeros(),
    OS16 => src_val[15..0] == zeros(),
    OS32 => src_val[31..0] == zeros(),
    OS64 => src_val == zeros(),
  };
  let count : int = if is_zero then os_bits
                    else bsf64(src_val, 0);
  write_gpr(dst, os, to_bits_truncate(count));
  CF = if is_zero then bitone else bitzero;
  ZF = if count == 0 then bitone else bitzero;
  Ok(())
}
// ADCX — Unsigned Integer Addition of Two Operands With Carry Flag
//
// CF:DEST := DEST + SRC + CF. Only CF is updated; other flags unmodified.
// Only 32-bit and 64-bit operand sizes.

val exec_adcx : (gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_adcx(dst, b, os) = {
  let a : qword = read_gpr(dst, os);
  let c : int = if CF == bitone then 1 else 0;
  let result : qword = a + b + zero_extend(CF);
  match os {
    OS32 => {
      CF = if (unsigned(result[31..0]) != unsigned(a[31..0]) + unsigned(b[31..0]) + c)
           then bitone else bitzero
    },
    OS64 => {
      CF = if (unsigned(result) != unsigned(a) + unsigned(b) + c)
           then bitone else bitzero
    },
    _ => (),
  };
  write_gpr(dst, os, result);
  Ok(())
}
// ADOX — Unsigned Integer Addition of Two Operands With Overflow Flag
//
// OF:DEST := DEST + SRC + OF. Only OF is updated; other flags unmodified.
// Only 32-bit and 64-bit operand sizes.

val exec_adox : (gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_adox(dst, b, os) = {
  let a : qword = read_gpr(dst, os);
  let c : int = if OF == bitone then 1 else 0;
  let result : qword = a + b + zero_extend(OF);
  match os {
    OS32 => {
      OF = if (unsigned(result[31..0]) != unsigned(a[31..0]) + unsigned(b[31..0]) + c)
           then bitone else bitzero
    },
    OS64 => {
      OF = if (unsigned(result) != unsigned(a) + unsigned(b) + c)
           then bitone else bitzero
    },
    _ => (),
  };
  write_gpr(dst, os, result);
  Ok(())
}
// LAHF — Load Status Flags Into AH Register
// SAHF — Store AH Into Flags
//
// LAHF: AH := RFLAGS(SF:ZF:0:AF:0:PF:1:CF)
// SAHF: RFLAGS(SF:ZF:0:AF:0:PF:1:CF) := AH

val exec_lahf : unit -> ExecutionResult
function exec_lahf() = {
  let v : byte = CF @ bitone @ PF @ bitzero @ AF @ bitzero @ ZF @ SF;
  write_gpr8h(RAX, v);
  Ok(())
}

val exec_sahf : unit -> ExecutionResult
function exec_sahf() = {
  let ah : byte = read_gpr8h(RAX);
  CF = ah[0];
  PF = ah[2];
  AF = ah[4];
  ZF = ah[6];
  SF = ah[7];
  Ok(())
}
// LEA — Load Effective Address
//
// Stores the effective address (not the value at that address) into dst.
// No flags are affected. The effective address is computed by the decoder.

val exec_lea : (gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_lea(dst, addr, os) = {
  write_gpr(dst, os, addr);
  Ok(())
}
// XLAT/XLATB — Table Look-up Translation
//
// AL := byte at [RBX + zero_extend(AL)] (64-bit mode).
// No flags affected.

val exec_xlat : AddressSize -> ExecutionResult
function exec_xlat(asz) = {
  let al : qword = zero_extend(read_gpr8l(RAX));
  let addr : qword = match asz {
    AS64 => read_gpr64(RBX) + al,
    AS32 => zero_extend(read_gpr32(RBX)) + al,
    AS16 => zero_extend(read_gpr16(RBX)) + al,
  };
  write_gpr8l(RAX, mem_read8(addr));
  Ok(())
}
// CPUID — CPU Identification
//
// Returns processor identification and feature information in EAX, EBX,
// ECX, EDX based on input leaf (EAX) and sub-leaf (ECX).
// No flags affected. Values are implementation-defined.

// External function provided by the execution environment.
// Takes (leaf, subleaf) and returns (eax, ebx, ecx, edx).
val __cpuid : (dword, dword) -> (dword, dword, dword, dword)

val exec_cpuid : unit -> ExecutionResult
function exec_cpuid() = {
  let leaf : dword = read_gpr32(RAX);
  let subleaf : dword = read_gpr32(RCX);
  let (out_eax, out_ebx, out_ecx, out_edx) = __cpuid(leaf, subleaf);
  write_gpr32(RAX, out_eax);
  write_gpr32(RBX, out_ebx);
  write_gpr32(RCX, out_ecx);
  write_gpr32(RDX, out_edx);
  Ok(())
}
// RDTSC — Read Time-Stamp Counter
//
// Reads the 64-bit TSC into EDX:EAX (high:low).
// Upper 32 bits of RAX and RDX are cleared.
// No flags affected. TSC value is provided by the execution environment.

// External function: returns current time-stamp counter value.
val __rdtsc : unit -> qword

val exec_rdtsc : unit -> ExecutionResult
function exec_rdtsc() = {
  let tsc : qword = __rdtsc();
  write_gpr32(RAX, tsc[31..0]);
  write_gpr32(RDX, tsc[63..32]);
  Ok(())
}
// CMPXCHG8B/CMPXCHG16B — Compare and Exchange Bytes
//
// Compares EDX:EAX (or RDX:RAX) with 64-bit (or 128-bit) memory operand.
// If equal, sets ZF and stores ECX:EBX (or RCX:RBX) to memory.
// Otherwise, clears ZF and loads memory value into EDX:EAX (or RDX:RAX).

val exec_cmpxchg8b : qword -> ExecutionResult
function exec_cmpxchg8b(addr) = {
  let mem_lo : dword = mem_read32(addr);
  let mem_hi : dword = mem_read32(addr + 0x0000000000000004);
  if read_gpr32(RAX) == mem_lo & read_gpr32(RDX) == mem_hi then {
    ZF = bitone;
    mem_write32(addr, read_gpr32(RBX));
    mem_write32(addr + 0x0000000000000004, read_gpr32(RCX));
  } else {
    ZF = bitzero;
    write_gpr32(RAX, mem_lo);
    write_gpr32(RDX, mem_hi);
  };
  Ok(())
}

val exec_cmpxchg16b : qword -> ExecutionResult
function exec_cmpxchg16b(addr) = {
  let mem_lo : qword = mem_read64(addr);
  let mem_hi : qword = mem_read64(addr + 0x0000000000000008);
  if read_gpr64(RAX) == mem_lo & read_gpr64(RDX) == mem_hi then {
    ZF = bitone;
    mem_write64(addr, read_gpr64(RBX));
    mem_write64(addr + 0x0000000000000008, read_gpr64(RCX));
  } else {
    ZF = bitzero;
    write_gpr64(RAX, mem_lo);
    write_gpr64(RDX, mem_hi);
  };
  Ok(())
}
// XGETBV — Get Value of Extended Control Register
//
// Reads XCR[ECX] into EDX:EAX. ECX=0 (XCR0) reports OS-enabled state components.
// We report x87 + SSE + AVX enabled (bits 0-2).

val exec_xgetbv : unit -> ExecutionResult
function exec_xgetbv() = {
  let ecx_val : dword = read_gpr32(RCX);
  if ecx_val == 0x00000000 then {
    // XCR0: bit 0 = x87, bit 1 = SSE, bit 2 = AVX
    write_gpr32(RAX, 0x00000007);
    write_gpr32(RDX, 0x00000000);
    Ok(())
  } else {
    // Only XCR0 is supported
    raise_GP0()
  }
}
// NOP — No Operation
//
// Does nothing. No flags affected.

val exec_nop : unit -> ExecutionResult
function exec_nop() = Ok(())
// PAUSE — Spin Loop Hint
//
// Provides a hint to the processor that the code is in a spin-wait loop.
// Improves performance and power consumption. Semantically a NOP.

val exec_pause : unit -> ExecutionResult
function exec_pause() = Ok(())
// HLT — Halt
//
// Stops instruction execution. An interrupt or reset resumes execution.
// No flags affected. Requires CPL=0 in protected mode.

val exec_hlt : unit -> ExecutionResult
function exec_hlt() = Halt(())
// CLI — Clear Interrupt Flag
//
// Clears the IF flag, disabling maskable hardware interrupts.
// Full privilege checking (IOPL, PVI/VME modes) is simplified here;
// we model the common case where IOPL >= CPL.

val exec_cli : unit -> ExecutionResult
function exec_cli() = {
  IF_flag = bitzero;
  Ok(())
}
// STI — Set Interrupt Flag
//
// Sets the IF flag, enabling maskable hardware interrupts.
// Full privilege checking (IOPL, PVI/VME modes) is simplified here;
// we model the common case where IOPL >= CPL.

val exec_sti : unit -> ExecutionResult
function exec_sti() = {
  IF_flag = bitone;
  Ok(())
}
// IN — Input From Port
//
// Reads a byte/word/dword from an I/O port into AL/AX/EAX.
// No flags affected. Port access delegated to execution environment.

val __port_in8  : word -> byte
val __port_in16 : word -> word
val __port_in32 : word -> dword

val exec_in : (word, OperandSize) -> ExecutionResult
function exec_in(port, os) = {
  match os {
    OS8  => write_gpr8l(RAX, __port_in8(port)),
    OS16 => write_gpr16(RAX, __port_in16(port)),
    OS32 => write_gpr32(RAX, __port_in32(port)),
    OS64 => (),
  };
  Ok(())
}
// OUT — Output to Port
//
// Writes a byte/word/dword from AL/AX/EAX to an I/O port.
// No flags affected.

val __port_out8  : (word, byte)  -> unit
val __port_out16 : (word, word) -> unit
val __port_out32 : (word, dword) -> unit

val exec_out : (word, OperandSize) -> ExecutionResult
function exec_out(port, os) = {
  match os {
    OS8  => __port_out8(port, read_gpr8l(RAX)),
    OS16 => __port_out16(port, read_gpr16(RAX)),
    OS32 => __port_out32(port, read_gpr32(RAX)),
    OS64 => (),
  };
  Ok(())
}

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

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

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

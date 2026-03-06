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

// Two-operand form: dst := dst * src (truncated to operand size)
val exec_imul_2 : (gpr_idx, gpr_idx, OperandSize) -> ExecutionResult
function exec_imul_2(dst, src, os) = {
  let a : qword = read_gpr(dst, os);
  let b : qword = read_gpr(src, os);
  let product : int = match os {
    OS8  => signed(a[7..0]) * signed(b[7..0]),
    OS16 => signed(a[15..0]) * signed(b[15..0]),
    OS32 => signed(a[31..0]) * signed(b[31..0]),
    OS64 => signed(a) * signed(b),
  };
  let result : qword = to_bits_truncate(product);
  let truncated : bool = match os {
    OS8  => product != signed(result[7..0]),
    OS16 => product != signed(result[15..0]),
    OS32 => product != signed(result[31..0]),
    OS64 => product != signed(result),
  };
  CF = if truncated then bitone else bitzero;
  OF = CF;
  write_gpr(dst, os, result);
  Ok(())
}

// Three-operand form: dst := src * imm (truncated to operand size)
val exec_imul_3 : (gpr_idx, gpr_idx, qword, OperandSize) -> ExecutionResult
function exec_imul_3(dst, src, imm, os) = {
  let b : qword = read_gpr(src, os);
  let product : int = match os {
    OS8  => signed(b[7..0]) * signed(imm[7..0]),
    OS16 => signed(b[15..0]) * signed(imm[15..0]),
    OS32 => signed(b[31..0]) * signed(imm[31..0]),
    OS64 => signed(b) * signed(imm),
  };
  let result : qword = to_bits_truncate(product);
  let truncated : bool = match os {
    OS8  => product != signed(result[7..0]),
    OS16 => product != signed(result[15..0]),
    OS32 => product != signed(result[31..0]),
    OS64 => product != signed(result),
  };
  CF = if truncated then bitone else bitzero;
  OF = CF;
  write_gpr(dst, os, result);
  Ok(())
}

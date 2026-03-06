// COMISS — Compare Scalar Ordered Single Precision FP Values and Set EFLAGS
//
// Compares two single-precision FP values and sets ZF, PF, CF.
// COMISS signals #IA on QNaN; UCOMISS signals only on SNaN.
// OF, AF, SF are cleared.

val exec_comiss : (simd_idx, xmmword) -> ExecutionResult
function exec_comiss(dst, src) = {
  let a : dword = read_xmm(dst)[31..0];
  let b : dword = src[31..0];
  match __compare_ss(a, b) {
    FP_UNORDERED => { ZF = bitone;  PF = bitone;  CF = bitone;  },
    FP_GT        => { ZF = bitzero; PF = bitzero; CF = bitzero; },
    FP_LT        => { ZF = bitzero; PF = bitzero; CF = bitone;  },
    FP_EQ        => { ZF = bitone;  PF = bitzero; CF = bitzero; },
  };
  OF = bitzero;
  AF = bitzero;
  SF = bitzero;
  Ok(())
}

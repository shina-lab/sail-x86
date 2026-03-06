// UCOMISS — Unordered Compare Scalar Single Precision FP Values and Set EFLAGS
//
// Same as COMISS for our spec; the only difference is QNaN handling
// which is abstracted into the external __compare_ss function.

val exec_ucomiss : (simd_idx, xmmword) -> ExecutionResult
function exec_ucomiss(dst, src) = {
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

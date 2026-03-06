// COMISD — Compare Scalar Ordered Double Precision FP Values and Set EFLAGS

val exec_comisd : (simd_idx, xmmword) -> ExecutionResult
function exec_comisd(dst, src) = {
  let a : qword = read_xmm(dst)[63..0];
  let b : qword = src[63..0];
  match __compare_sd(a, b) {
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

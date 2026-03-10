// External floating-point functions provided by the execution environment.
// These implement IEEE 754 arithmetic.

// Single precision (32-bit)
val __f32_add  : (dword, dword) -> dword
val __f32_sub  : (dword, dword) -> dword
val __f32_mul  : (dword, dword) -> dword
val __f32_div  : (dword, dword) -> dword
val __f32_sqrt : dword -> dword
val __f32_min  : (dword, dword) -> dword
val __f32_max  : (dword, dword) -> dword

// Double precision (64-bit)
val __f64_add  : (qword, qword) -> qword
val __f64_sub  : (qword, qword) -> qword
val __f64_mul  : (qword, qword) -> qword
val __f64_div  : (qword, qword) -> qword
val __f64_sqrt : qword -> qword
val __f64_min  : (qword, qword) -> qword
val __f64_max  : (qword, qword) -> qword

// Comparison
enum FPCompareResult = { FP_GT, FP_LT, FP_EQ, FP_UNORDERED }

// x87 classification
enum FPClass = {
  FP_Unsupported,
  FP_NaN,
  FP_Normal,
  FP_Infinity,
  FP_Zero,
  FP_Empty,
  FP_Denormal
}
val __compare_ss : (dword, dword) -> FPCompareResult
val __compare_sd : (qword, qword) -> FPCompareResult
val __compare_sh : (word, word) -> FPCompareResult

// Conversions: int <-> float
val __int32_to_f64 : dword -> qword
val __int64_to_f64 : qword -> qword
val __int32_to_f32 : dword -> dword
val __int64_to_f32 : qword -> dword
val __f64_to_int32 : qword -> dword
val __f64_to_int64 : qword -> qword
val __f32_to_int32 : dword -> dword
val __f32_to_int64 : dword -> qword
val __f64_to_int32_trunc : qword -> dword
val __f64_to_int64_trunc : qword -> qword
val __f32_to_int32_trunc : dword -> dword
val __f32_to_int64_trunc : dword -> qword

// Conversions: unsigned int <-> float
val __uint32_to_f32 : dword -> dword
val __uint64_to_f32 : qword -> dword
val __uint32_to_f64 : dword -> qword
val __uint64_to_f64 : qword -> qword
val __f32_to_uint32 : dword -> dword
val __f32_to_uint64 : dword -> qword
val __f64_to_uint32 : qword -> dword
val __f64_to_uint64 : qword -> qword
val __f32_to_uint32_trunc : dword -> dword
val __f32_to_uint64_trunc : dword -> qword
val __f64_to_uint32_trunc : qword -> dword
val __f64_to_uint64_trunc : qword -> qword

// Conversions: float <-> float
val __f64_to_f32 : qword -> dword
val __f32_to_f64 : dword -> qword

// FMA: fused multiply-add
val __f32_fmadd  : (dword, dword, dword) -> dword
val __f32_fmsub  : (dword, dword, dword) -> dword
val __f32_fnmadd : (dword, dword, dword) -> dword
val __f32_fnmsub : (dword, dword, dword) -> dword
val __f64_fmadd  : (qword, qword, qword) -> qword
val __f64_fmsub  : (qword, qword, qword) -> qword
val __f64_fnmadd : (qword, qword, qword) -> qword
val __f64_fnmsub : (qword, qword, qword) -> qword

// VSCALEF: result = src1 * 2^(floor(src2))
val __f32_scalef : (dword, dword) -> dword
val __f64_scalef : (qword, qword) -> qword

// VGETEXP: extract unbiased exponent as FP value
val __f32_getexp : dword -> dword
val __f64_getexp : qword -> qword

// VRCP14: approximate reciprocal (14-bit precision)
val __f32_rcp14 : dword -> dword
val __f64_rcp14 : qword -> qword

// VRSQRT14: approximate reciprocal square root (14-bit precision)
val __f32_rsqrt14 : dword -> dword
val __f64_rsqrt14 : qword -> qword

// VRNDSCALE: round to specified number of fraction bits
val __f32_rndscale : (dword, byte) -> dword
val __f64_rndscale : (qword, byte) -> qword

// VGETMANT: extract mantissa as FP value
val __f32_getmant : (dword, byte) -> dword
val __f64_getmant : (qword, byte) -> qword

// VREDUCE: reduce FP value
val __f32_reduce : (dword, byte) -> dword
val __f64_reduce : (qword, byte) -> qword

// VFIXUPIMM: fix up special FP values
val __f32_fixupimm : (dword, dword, dword, byte) -> dword
val __f64_fixupimm : (qword, qword, qword, byte) -> qword

// VDPBF16PS: BF16 dot product element (dst += bf16_hi*bf16_hi + bf16_lo*bf16_lo)
val __vdpbf16ps_elem : (dword, dword, dword) -> dword

// Half precision (16-bit) — AVX-512 FP16
val __f16_add  : (word, word) -> word
val __f16_sub  : (word, word) -> word
val __f16_mul  : (word, word) -> word
val __f16_div  : (word, word) -> word
val __f16_sqrt : word -> word
val __f16_min  : (word, word) -> word
val __f16_max  : (word, word) -> word

// FP16 FMA
val __f16_fmadd  : (word, word, word) -> word
val __f16_fmsub  : (word, word, word) -> word
val __f16_fnmadd : (word, word, word) -> word
val __f16_fnmsub : (word, word, word) -> word

// FP16 conversions
val __f16_to_f32 : word -> dword
val __f32_to_f16 : dword -> word
val __f16_to_f64 : word -> qword
val __f64_to_f16 : qword -> word
val __f16_to_int32 : word -> dword
val __f16_to_int64 : word -> qword
val __f16_to_int32_trunc : word -> dword
val __f16_to_int64_trunc : word -> qword
val __int32_to_f16 : dword -> word
val __int64_to_f16 : qword -> word
val __f16_to_uint32 : word -> dword
val __f16_to_uint64 : word -> qword
val __f16_to_uint32_trunc : word -> dword
val __f16_to_uint64_trunc : word -> qword
val __uint32_to_f16 : dword -> word
val __uint64_to_f16 : qword -> word
val __f16_to_int16 : word -> word
val __f16_to_int16_trunc : word -> word
val __int16_to_f16 : word -> word
val __f16_to_uint16 : word -> word
val __f16_to_uint16_trunc : word -> word
val __uint16_to_f16 : word -> word

// FP16 special operations
val __f16_scalef : (word, word) -> word
val __f16_getexp : word -> word
val __f16_rcp   : word -> word
val __f16_rsqrt : word -> word
val __f16_rndscale : (word, byte) -> word
val __f16_getmant : (word, byte) -> word
val __f16_reduce : (word, byte) -> word
// VRCP28/VRSQRT28/VEXP2 (KNL)
val __f32_rcp28 : dword -> dword
val __f64_rcp28 : qword -> qword
val __f32_rsqrt28 : dword -> dword
val __f64_rsqrt28 : qword -> qword
val __f32_exp2 : dword -> dword
val __f64_exp2 : qword -> qword


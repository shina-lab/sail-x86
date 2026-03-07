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

// Conversions: float <-> float
val __f64_to_f32 : qword -> dword
val __f32_to_f64 : dword -> qword

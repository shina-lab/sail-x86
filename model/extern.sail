// x86-64 — External Function Declarations
//
// All functions provided by the execution environment (C/C++ harness).

// =========================================================================
// Memory primitives
// =========================================================================

// Raw physical memory read/write. Size parameter 'n is in bits.
val __read_mem : forall 'n, 'n > 0. (qword, int('n)) -> bits('n)
val __write_mem : forall 'n, 'n > 0. (qword, int('n), bits('n)) -> unit

// Slow-path for page-crossing accesses (each byte translated separately).
val __mem_read_crossing : forall 'n, 'n > 0. (qword, int('n), PTAccess) -> bits('n)
val __mem_write_crossing : forall 'n, 'n > 0. (qword, int('n), bits('n)) -> unit

// Software TLB (purely an optimization; removing does not affect correctness).
val __tlb_lookup : (qword, bool) -> option(qword)
val __tlb_insert : (qword, qword, bool) -> unit
val __tlb_flush : unit -> unit

// =========================================================================
// System
// =========================================================================

val __rdtsc : unit -> qword
val __rdrand64 : unit -> (qword, bit)
val __rdseed64 : unit -> (qword, bit)

// MSR read/write — implemented in C++ as a key-value store
val __rdmsr : dword -> qword
val __wrmsr : (dword, qword) -> unit

val __syscall : (qword, qword) -> unit
val __fxsave : qword -> unit
val __fxsave64 : qword -> unit
val __fxrstor : qword -> unit
val __fxrstor64 : qword -> unit

val __software_interrupt : byte -> unit

// Check for and acknowledge a pending external interrupt.
// Returns the vector number, or -1 if no interrupt pending.
val __check_pending_irq : unit -> int

// Check if an SMI is pending (set by emulator on port 0xB2 write).
val __check_pending_smi : unit -> bool

val __wait : unit -> unit

// =========================================================================
// I/O ports
// =========================================================================

val __port_in8  : word -> byte
val __port_in16 : word -> word
val __port_in32 : word -> dword

val __port_out8  : (word, byte)  -> unit
val __port_out16 : (word, word) -> unit
val __port_out32 : (word, dword) -> unit

// =========================================================================
// MXCSR
// =========================================================================

val __ldmxcsr : dword -> unit
val __stmxcsr : unit -> dword

// =========================================================================
// FP enums
// =========================================================================

enum FPCompareResult = { FP_GT, FP_LT, FP_EQ, FP_UNORDERED }

enum FPClass = {
  FP_Unsupported,
  FP_NaN,
  FP_Normal,
  FP_Infinity,
  FP_Zero,
  FP_Empty,
  FP_Denormal
}

// =========================================================================
// Single precision (f32)
// =========================================================================

val __f32_add  : (dword, dword) -> dword
val __f32_sub  : (dword, dword) -> dword
val __f32_mul  : (dword, dword) -> dword
val __f32_div  : (dword, dword) -> dword
val __f32_sqrt : dword -> dword
val __f32_min  : (dword, dword) -> dword
val __f32_max  : (dword, dword) -> dword
val __f32_rsqrt : dword -> dword
val __f32_rcp : dword -> dword

// =========================================================================
// Double precision (forced64)
// =========================================================================

val __f64_add  : (qword, qword) -> qword
val __f64_sub  : (qword, qword) -> qword
val __f64_mul  : (qword, qword) -> qword
val __f64_div  : (qword, qword) -> qword
val __f64_sqrt : qword -> qword
val __f64_min  : (qword, qword) -> qword
val __f64_max  : (qword, qword) -> qword

// =========================================================================
// FP comparison
// =========================================================================

val __compare_ss : (dword, dword) -> FPCompareResult
val __compare_sd : (qword, qword) -> FPCompareResult
val __compare_sh : (word, word) -> FPCompareResult

// =========================================================================
// FP conversions: int <-> float
// =========================================================================

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

// =========================================================================
// FP conversions: unsigned int <-> float
// =========================================================================

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

// =========================================================================
// FP conversions: float <-> float
// =========================================================================

val __f64_to_f32 : qword -> dword
val __f32_to_f64 : dword -> qword

// =========================================================================
// FP rounding (SSE4.1 ROUNDPS/ROUNDPD/ROUNDSS/ROUNDSD)
// =========================================================================

val __f32_round : (dword, byte) -> dword
val __f64_round : (qword, byte) -> qword

// =========================================================================
// FMA: fused multiply-add
// =========================================================================

val __f32_fmadd  : (dword, dword, dword) -> dword
val __f32_fmsub  : (dword, dword, dword) -> dword
val __f32_fnmadd : (dword, dword, dword) -> dword
val __f32_fnmsub : (dword, dword, dword) -> dword
val __f64_fmadd  : (qword, qword, qword) -> qword
val __f64_fmsub  : (qword, qword, qword) -> qword
val __f64_fnmadd : (qword, qword, qword) -> qword
val __f64_fnmsub : (qword, qword, qword) -> qword

// =========================================================================
// AVX-512 FP special
// =========================================================================

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

// =========================================================================
// Half precision (f16) — AVX-512 FP16
// =========================================================================

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

// =========================================================================
// KNL: VRCP28/VRSQRT28/VEXP2
// =========================================================================

val __f32_rcp28 : dword -> dword
val __f64_rcp28 : qword -> qword
val __f32_rsqrt28 : dword -> dword
val __f64_rsqrt28 : qword -> qword
val __f32_exp2 : dword -> dword
val __f64_exp2 : qword -> qword

// =========================================================================
// x87 extended precision (f80)
// =========================================================================

// Arithmetic
val __f80_add : (fp80, fp80) -> fp80
val __f80_sub : (fp80, fp80) -> fp80
val __f80_mul : (fp80, fp80) -> fp80
val __f80_div : (fp80, fp80) -> fp80
val __f80_sqrt : fp80 -> fp80
val __f80_abs : fp80 -> fp80
val __f80_chs : fp80 -> fp80
val __f80_compare : (fp80, fp80) -> FPCompareResult

// Conversions to/from 80-bit extended precision
val __f80_from_f32 : dword -> fp80
val __f80_from_f64 : qword -> fp80
val __f80_to_f32 : fp80 -> dword
val __f80_to_f64 : fp80 -> qword
val __f80_from_int16 : word -> fp80
val __f80_from_int32 : dword -> fp80
val __f80_from_int64 : qword -> fp80
val __f80_to_int16 : fp80 -> word
val __f80_to_int32 : fp80 -> dword
val __f80_to_int64 : fp80 -> qword
val __f80_to_int16_trunc : fp80 -> word
val __f80_to_int32_trunc : fp80 -> dword
val __f80_to_int64_trunc : fp80 -> qword

// Constants
val __f80_zero : unit -> fp80
val __f80_one : unit -> fp80
val __f80_log2_10 : unit -> fp80
val __f80_log2_e : unit -> fp80
val __f80_pi : unit -> fp80
val __f80_log10_2 : unit -> fp80
val __f80_ln_2 : unit -> fp80

// Classification
val __f80_classify : fp80 -> FPClass

// Decomposition (used by FXTRACT)
val __f80_extract_exponent : fp80 -> fp80
val __f80_extract_significand : fp80 -> fp80

// Transcendental operations
val __f80_yl2x : (fp80, fp80) -> fp80
val __f80_yl2xp1 : (fp80, fp80) -> fp80
val __f80_sin : fp80 -> fp80
val __f80_cos : fp80 -> fp80
val __f80_tan : fp80 -> fp80
val __f80_atan2 : (fp80, fp80) -> fp80
val __f80_2xm1 : fp80 -> fp80
val __f80_scale : (fp80, fp80) -> fp80
val __f80_prem : (fp80, fp80) -> fp80
val __f80_prem1 : (fp80, fp80) -> fp80
val __f80_round : fp80 -> fp80

// BCD conversions (for FBLD/FBSTP)
val __f80_from_bcd : fp80 -> fp80
val __f80_to_bcd : fp80 -> fp80

// =========================================================================
// AES-NI
// =========================================================================

val __aesenc : (xmmword, xmmword) -> xmmword
val __aesdec : (xmmword, xmmword) -> xmmword
val __aesenclast : (xmmword, xmmword) -> xmmword
val __aesdeclast : (xmmword, xmmword) -> xmmword
val __aesimc : xmmword -> xmmword
val __aeskeygenassist : (xmmword, byte) -> xmmword

// =========================================================================
// GFNI
// =========================================================================

val __gf2p8mulb : (xmmword, xmmword) -> xmmword
val __gf2p8affineqb : (xmmword, xmmword, byte) -> xmmword
val __gf2p8affineinvqb : (xmmword, xmmword, byte) -> xmmword

// =========================================================================
// SHA
// =========================================================================

val __sha1rnds4 : (xmmword, xmmword, byte) -> xmmword
val __sha1nexte : (xmmword, xmmword) -> xmmword
val __sha1msg1 : (xmmword, xmmword) -> xmmword
val __sha1msg2 : (xmmword, xmmword) -> xmmword
val __sha256rnds2 : (xmmword, xmmword, xmmword) -> xmmword
val __sha256msg1 : (xmmword, xmmword) -> xmmword
val __sha256msg2 : (xmmword, xmmword) -> xmmword

// =========================================================================
// Width-polymorphic FP overloads
// =========================================================================

// Width-polymorphic FP operations: dispatch to __f{16,32,64}_* based on 'n.
val fadd : forall 'n, 'n in {8, 16, 32, 64}. (bits('n), bits('n)) -> bits('n)
function fadd(a, b) = match 'n { 16 => __f16_add(a, b), 32 => __f32_add(a, b), 64 => __f64_add(a, b), _ => undefined }

val fsub : forall 'n, 'n in {8, 16, 32, 64}. (bits('n), bits('n)) -> bits('n)
function fsub(a, b) = match 'n { 16 => __f16_sub(a, b), 32 => __f32_sub(a, b), 64 => __f64_sub(a, b), _ => undefined }

val fmul : forall 'n, 'n in {8, 16, 32, 64}. (bits('n), bits('n)) -> bits('n)
function fmul(a, b) = match 'n { 16 => __f16_mul(a, b), 32 => __f32_mul(a, b), 64 => __f64_mul(a, b), _ => undefined }

val fdiv : forall 'n, 'n in {8, 16, 32, 64}. (bits('n), bits('n)) -> bits('n)
function fdiv(a, b) = match 'n { 16 => __f16_div(a, b), 32 => __f32_div(a, b), 64 => __f64_div(a, b), _ => undefined }

val fmin : forall 'n, 'n in {8, 16, 32, 64}. (bits('n), bits('n)) -> bits('n)
function fmin(a, b) = match 'n { 16 => __f16_min(a, b), 32 => __f32_min(a, b), 64 => __f64_min(a, b), _ => undefined }

val fmax : forall 'n, 'n in {8, 16, 32, 64}. (bits('n), bits('n)) -> bits('n)
function fmax(a, b) = match 'n { 16 => __f16_max(a, b), 32 => __f32_max(a, b), 64 => __f64_max(a, b), _ => undefined }

val fsqrt : forall 'n, 'n in {8, 16, 32, 64}. bits('n) -> bits('n)
function fsqrt(a) = match 'n { 16 => __f16_sqrt(a), 32 => __f32_sqrt(a), 64 => __f64_sqrt(a), _ => undefined }

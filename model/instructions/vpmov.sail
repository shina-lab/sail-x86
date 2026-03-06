// VPMASKMOV — Conditional SIMD Integer Packed Loads and Stores (AVX2)
//
// Conditionally loads/stores packed dword/qword values using a mask register.
// Modeled as external function (no YMM/ZMM infrastructure).

val __vpmaskmov : unit -> ExecutionResult
val exec_vpmaskmov : unit -> ExecutionResult
function exec_vpmaskmov() = __vpmaskmov()

// VPMOVB2M — Convert Packed Byte Integers to Mask (AVX-512 BW)
// VPMOVW2M — Convert Packed Word Integers to Mask (AVX-512 BW)
// VPMOVD2M — Convert Packed Doubleword Integers to Mask (AVX-512 DQ)
// VPMOVQ2M — Convert Packed Quadword Integers to Mask (AVX-512 DQ)
//
// Set each mask bit to the most significant bit of the corresponding element.

val __vpmovb2m : unit -> ExecutionResult
val exec_vpmovb2m : unit -> ExecutionResult
function exec_vpmovb2m() = __vpmovb2m()

val __vpmovw2m : unit -> ExecutionResult
val exec_vpmovw2m : unit -> ExecutionResult
function exec_vpmovw2m() = __vpmovw2m()

val __vpmovd2m : unit -> ExecutionResult
val exec_vpmovd2m : unit -> ExecutionResult
function exec_vpmovd2m() = __vpmovd2m()

val __vpmovq2m : unit -> ExecutionResult
val exec_vpmovq2m : unit -> ExecutionResult
function exec_vpmovq2m() = __vpmovq2m()

// VPMOVM2B — Convert Mask to Packed Byte Integers (AVX-512 BW)
// VPMOVM2W — Convert Mask to Packed Word Integers (AVX-512 BW)
// VPMOVM2D — Convert Mask to Packed Doubleword Integers (AVX-512 DQ)
// VPMOVM2Q — Convert Mask to Packed Quadword Integers (AVX-512 DQ)
//
// Set each element to all ones or all zeros based on the corresponding mask bit.

val __vpmovm2b : unit -> ExecutionResult
val exec_vpmovm2b : unit -> ExecutionResult
function exec_vpmovm2b() = __vpmovm2b()

val __vpmovm2w : unit -> ExecutionResult
val exec_vpmovm2w : unit -> ExecutionResult
function exec_vpmovm2w() = __vpmovm2w()

val __vpmovm2d : unit -> ExecutionResult
val exec_vpmovm2d : unit -> ExecutionResult
function exec_vpmovm2d() = __vpmovm2d()

val __vpmovm2q : unit -> ExecutionResult
val exec_vpmovm2q : unit -> ExecutionResult
function exec_vpmovm2q() = __vpmovm2q()

// VPMOVDB — Down Convert Packed Dword to Byte (AVX-512)
// VPMOVSDB — Down Convert Packed Signed Dword to Byte with Saturation (AVX-512)
// VPMOVUSDB — Down Convert Packed Unsigned Dword to Byte with Saturation (AVX-512)

val __vpmovdb : unit -> ExecutionResult
val exec_vpmovdb : unit -> ExecutionResult
function exec_vpmovdb() = __vpmovdb()

val __vpmovsdb : unit -> ExecutionResult
val exec_vpmovsdb : unit -> ExecutionResult
function exec_vpmovsdb() = __vpmovsdb()

val __vpmovusdb : unit -> ExecutionResult
val exec_vpmovusdb : unit -> ExecutionResult
function exec_vpmovusdb() = __vpmovusdb()

// VPMOVDW — Down Convert Packed Dword to Word (AVX-512)
// VPMOVSDW — Down Convert Packed Signed Dword to Word with Saturation (AVX-512)
// VPMOVUSDW — Down Convert Packed Unsigned Dword to Word with Saturation (AVX-512)

val __vpmovdw : unit -> ExecutionResult
val exec_vpmovdw : unit -> ExecutionResult
function exec_vpmovdw() = __vpmovdw()

val __vpmovsdw : unit -> ExecutionResult
val exec_vpmovsdw : unit -> ExecutionResult
function exec_vpmovsdw() = __vpmovsdw()

val __vpmovusdw : unit -> ExecutionResult
val exec_vpmovusdw : unit -> ExecutionResult
function exec_vpmovusdw() = __vpmovusdw()

// VPMOVQB — Down Convert Packed Qword to Byte (AVX-512)
// VPMOVSQB — Down Convert Packed Signed Qword to Byte with Saturation (AVX-512)
// VPMOVUSQB — Down Convert Packed Unsigned Qword to Byte with Saturation (AVX-512)

val __vpmovqb : unit -> ExecutionResult
val exec_vpmovqb : unit -> ExecutionResult
function exec_vpmovqb() = __vpmovqb()

val __vpmovsqb : unit -> ExecutionResult
val exec_vpmovsqb : unit -> ExecutionResult
function exec_vpmovsqb() = __vpmovsqb()

val __vpmovusqb : unit -> ExecutionResult
val exec_vpmovusqb : unit -> ExecutionResult
function exec_vpmovusqb() = __vpmovusqb()

// VPMOVQD — Down Convert Packed Qword to Dword (AVX-512)
// VPMOVSQD — Down Convert Packed Signed Qword to Dword with Saturation (AVX-512)
// VPMOVUSQD — Down Convert Packed Unsigned Qword to Dword with Saturation (AVX-512)

val __vpmovqd : unit -> ExecutionResult
val exec_vpmovqd : unit -> ExecutionResult
function exec_vpmovqd() = __vpmovqd()

val __vpmovsqd : unit -> ExecutionResult
val exec_vpmovsqd : unit -> ExecutionResult
function exec_vpmovsqd() = __vpmovsqd()

val __vpmovusqd : unit -> ExecutionResult
val exec_vpmovusqd : unit -> ExecutionResult
function exec_vpmovusqd() = __vpmovusqd()

// VPMOVQW — Down Convert Packed Qword to Word (AVX-512)
// VPMOVSQW — Down Convert Packed Signed Qword to Word with Saturation (AVX-512)
// VPMOVUSQW — Down Convert Packed Unsigned Qword to Word with Saturation (AVX-512)

val __vpmovqw : unit -> ExecutionResult
val exec_vpmovqw : unit -> ExecutionResult
function exec_vpmovqw() = __vpmovqw()

val __vpmovsqw : unit -> ExecutionResult
val exec_vpmovsqw : unit -> ExecutionResult
function exec_vpmovsqw() = __vpmovsqw()

val __vpmovusqw : unit -> ExecutionResult
val exec_vpmovusqw : unit -> ExecutionResult
function exec_vpmovusqw() = __vpmovusqw()

// VPMOVWB — Down Convert Packed Word to Byte (AVX-512 BW)
// VPMOVSWB — Down Convert Packed Signed Word to Byte with Saturation (AVX-512 BW)
// VPMOVUSWB — Down Convert Packed Unsigned Word to Byte with Saturation (AVX-512 BW)

val __vpmovwb : unit -> ExecutionResult
val exec_vpmovwb : unit -> ExecutionResult
function exec_vpmovwb() = __vpmovwb()

val __vpmovswb : unit -> ExecutionResult
val exec_vpmovswb : unit -> ExecutionResult
function exec_vpmovswb() = __vpmovswb()

val __vpmovuswb : unit -> ExecutionResult
val exec_vpmovuswb : unit -> ExecutionResult
function exec_vpmovuswb() = __vpmovuswb()

// VPMULTISHIFTQB — Select Packed Unaligned Bytes from Quadword Sources (AVX-512 VBMI)
//
// For each byte in the destination, a shift amount from the source selects
// 8 contiguous bits from the corresponding quadword of the other source.

val __vpmultishiftqb : unit -> ExecutionResult
val exec_vpmultishiftqb : unit -> ExecutionResult
function exec_vpmultishiftqb() = __vpmultishiftqb()

// VPOPCNT — Packed Population Count (AVX-512 VPOPCNTDQ / AVX-512 BITALG)
//
// Counts the number of set bits in each byte, word, doubleword, or quadword element.

val __vpopcnt : unit -> ExecutionResult
val exec_vpopcnt : unit -> ExecutionResult
function exec_vpopcnt() = __vpopcnt()

// AES-NI Instructions
// AESENC, AESDEC, AESENCLAST, AESDECLAST — AES round operations
// AESIMC — AES Inverse Mix Columns
// AESKEYGENASSIST — AES Round Key Generation Assist
//
// All AES round operations (ShiftRows, SubBytes, MixColumns, etc.) are
// complex cryptographic primitives modeled as external functions.
// No flags affected.

// External AES primitives
val __aesenc : (xmmword, xmmword) -> xmmword
val __aesdec : (xmmword, xmmword) -> xmmword
val __aesenclast : (xmmword, xmmword) -> xmmword
val __aesdeclast : (xmmword, xmmword) -> xmmword
val __aesimc : xmmword -> xmmword
val __aeskeygenassist : (xmmword, byte) -> xmmword

// AESENC — Perform One Round of an AES Encryption Flow
// DEST[127:0] := ShiftRows(SubBytes(MixColumns(SRC1))) XOR SRC2
val exec_aesenc : (simd_idx, xmmword) -> ExecutionResult
function exec_aesenc(dst, src) = {
  let state : xmmword = read_xmm(dst);
  let roundkey : xmmword = src;
  write_xmm_legacy(dst, __aesenc(state, roundkey));
  Ok(())
}

// AESDEC — Perform One Round of an AES Decryption Flow
// DEST[127:0] := InvShiftRows(InvSubBytes(InvMixColumns(SRC1))) XOR SRC2
val exec_aesdec : (simd_idx, xmmword) -> ExecutionResult
function exec_aesdec(dst, src) = {
  let state : xmmword = read_xmm(dst);
  let roundkey : xmmword = src;
  write_xmm_legacy(dst, __aesdec(state, roundkey));
  Ok(())
}

// AESENCLAST — Perform Last Round of an AES Encryption Flow
// DEST[127:0] := ShiftRows(SubBytes(SRC1)) XOR SRC2 (no MixColumns)
val exec_aesenclast : (simd_idx, xmmword) -> ExecutionResult
function exec_aesenclast(dst, src) = {
  let state : xmmword = read_xmm(dst);
  let roundkey : xmmword = src;
  write_xmm_legacy(dst, __aesenclast(state, roundkey));
  Ok(())
}

// AESDECLAST — Perform Last Round of an AES Decryption Flow
// DEST[127:0] := InvShiftRows(InvSubBytes(SRC1)) XOR SRC2 (no InvMixColumns)
val exec_aesdeclast : (simd_idx, xmmword) -> ExecutionResult
function exec_aesdeclast(dst, src) = {
  let state : xmmword = read_xmm(dst);
  let roundkey : xmmword = src;
  write_xmm_legacy(dst, __aesdeclast(state, roundkey));
  Ok(())
}

// AESIMC — Perform the AES InvMixColumns Transformation
// DEST[127:0] := InvMixColumns(SRC)
val exec_aesimc : (simd_idx, xmmword) -> ExecutionResult
function exec_aesimc(dst, src) = {
  let s : xmmword = src;
  write_xmm_legacy(dst, __aesimc(s));
  Ok(())
}

// AESKEYGENASSIST — AES Round Key Generation Assist
// Uses SubWord and RotWord on dwords from SRC, XORs with RCON from imm8.
val exec_aeskeygenassist : (simd_idx, xmmword, byte) -> ExecutionResult
function exec_aeskeygenassist(dst, src, imm8) = {
  let s : xmmword = src;
  write_xmm_legacy(dst, __aeskeygenassist(s, imm8));
  Ok(())
}

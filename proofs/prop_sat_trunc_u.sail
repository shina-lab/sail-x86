$include "../model/prelude.sail"

// --- or_reduce helpers (same as model code) ---

val or_reduce_8 : bits(8) -> bits(1)
function or_reduce_8(v) = {
  let r4 : bits(4) = v[7..4] | v[3..0];
  let r2 : bits(2) = r4[3..2] | r4[1..0];
  r2[1..1] | r2[0..0]
}

val or_reduce_16 : bits(16) -> bits(1)
function or_reduce_16(v) = or_reduce_8(v[15..8] | v[7..0])

val or_reduce_32 : bits(32) -> bits(1)
function or_reduce_32(v) = or_reduce_16(v[31..16] | v[15..0])

val or_reduce_64 : bits(64) -> bits(1)
function or_reduce_64(v) = or_reduce_32(v[63..32] | v[31..0])

// --- Branchless unsigned saturation truncation helpers ---

// Word → Byte: saturate unsigned 16-bit to 8-bit
val sat_trunc_u_w2b : bits(16) -> bits(8)
function sat_trunc_u_w2b(x) = {
  let overflow : bits(8) = sign_extend(or_reduce_8(x[15..8]));
  x[7..0] | overflow
}

// Dword → Word: saturate unsigned 32-bit to 16-bit
val sat_trunc_u_d2w : bits(32) -> bits(16)
function sat_trunc_u_d2w(x) = {
  let overflow : bits(16) = sign_extend(or_reduce_16(x[31..16]));
  x[15..0] | overflow
}

// Dword → Byte: saturate unsigned 32-bit to 8-bit
val sat_trunc_u_d2b : bits(32) -> bits(8)
function sat_trunc_u_d2b(x) = {
  let overflow : bits(8) = sign_extend(or_reduce_8(x[31..24] | x[23..16] | x[15..8]));
  x[7..0] | overflow
}

// Qword → Byte: saturate unsigned 64-bit to 8-bit
val sat_trunc_u_q2b : bits(64) -> bits(8)
function sat_trunc_u_q2b(x) = {
  let overflow : bits(8) = sign_extend(or_reduce_8(x[63..56] | x[55..48] | x[47..40] | x[39..32] | x[31..24] | x[23..16] | x[15..8]));
  x[7..0] | overflow
}

// Qword → Word: saturate unsigned 64-bit to 16-bit
val sat_trunc_u_q2w : bits(64) -> bits(16)
function sat_trunc_u_q2w(x) = {
  let overflow : bits(16) = sign_extend(or_reduce_16(x[63..48] | x[47..32] | x[31..16]));
  x[15..0] | overflow
}

// Qword → Dword: saturate unsigned 64-bit to 32-bit
val sat_trunc_u_q2d : bits(64) -> bits(32)
function sat_trunc_u_q2d(x) = {
  let overflow : bits(32) = sign_extend(or_reduce_32(x[63..32]));
  x[31..0] | overflow
}

// ================================================================
// Proofs
// ================================================================

$property
function prop_sat_trunc_u_w2b(x : bits(16)) -> bool = {
  let orig : bits(8) = if unsigned(x) > 255 then 0xFF else x[7..0];
  let branchless : bits(8) = sat_trunc_u_w2b(x);
  orig == branchless
}

$property
function prop_sat_trunc_u_d2w(x : bits(32)) -> bool = {
  let orig : bits(16) = if unsigned(x) > 65535 then 0xFFFF else x[15..0];
  let branchless : bits(16) = sat_trunc_u_d2w(x);
  orig == branchless
}

$property
function prop_sat_trunc_u_d2b(x : bits(32)) -> bool = {
  let orig : bits(8) = if unsigned(x) > 255 then 0xFF else x[7..0];
  let branchless : bits(8) = sat_trunc_u_d2b(x);
  orig == branchless
}

$property
function prop_sat_trunc_u_q2b(x : bits(64)) -> bool = {
  let orig : bits(8) = if unsigned(x) > 255 then 0xFF else x[7..0];
  let branchless : bits(8) = sat_trunc_u_q2b(x);
  orig == branchless
}

$property
function prop_sat_trunc_u_q2w(x : bits(64)) -> bool = {
  let orig : bits(16) = if unsigned(x) > 65535 then 0xFFFF else x[15..0];
  let branchless : bits(16) = sat_trunc_u_q2w(x);
  orig == branchless
}

$property
function prop_sat_trunc_u_q2d(x : bits(64)) -> bool = {
  let orig : bits(32) = if unsigned(x) > 4294967295 then 0xFFFFFFFF else x[31..0];
  let branchless : bits(32) = sat_trunc_u_q2d(x);
  orig == branchless
}

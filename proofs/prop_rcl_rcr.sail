$include "../model/prelude.sail"

type byte = bits(8)
type word = bits(16)
type dword = bits(32)
type qword = bits(64)

// Monomorphized rotatel/rotater for Sail SMT.
// These match the definitions in model/types.sail.
val rotatel9 : (bits(9), range(0, 9)) -> bits(9)
function rotatel9(v, shift) = (v << shift) | (v >> (9 - shift))

val rotater9 : (bits(9), range(0, 9)) -> bits(9)
function rotater9(v, shift) = (v >> shift) | (v << (9 - shift))

val rotatel17 : (bits(17), range(0, 17)) -> bits(17)
function rotatel17(v, shift) = (v << shift) | (v >> (17 - shift))

val rotater17 : (bits(17), range(0, 17)) -> bits(17)
function rotater17(v, shift) = (v >> shift) | (v << (17 - shift))

val rotatel33 : (bits(33), range(0, 33)) -> bits(33)
function rotatel33(v, shift) = (v << shift) | (v >> (33 - shift))

val rotater33 : (bits(33), range(0, 33)) -> bits(33)
function rotater33(v, shift) = (v >> shift) | (v << (33 - shift))

val rotatel65 : (bits(65), range(0, 65)) -> bits(65)
function rotatel65(v, shift) = (v << shift) | (v >> (65 - shift))

val rotater65 : (bits(65), range(0, 65)) -> bits(65)
function rotater65(v, shift) = (v >> shift) | (v << (65 - shift))

// ================================================================
// Part 1: Single-step equivalence
//
// One iteration of the RCL loop body:
//   tcf = val[msb]; val = val[msb-1..0] @ cf; cf = tcf
// is equivalent to rotatel(val @ cf, 1), split as:
//   new_val = rotated[msb+1..1], new_cf = rotated[0]
//
// Same for RCR (right direction).
// ================================================================

// RCL single step — verbatim from old exec_rcl loop body, os=8
$property
function prop_rcl_step8(val8 : byte, cf_bit : bit) -> bool = {
  let tcf : bit = val8[7];
  let new_val : byte = val8[6..0] @ cf_bit;
  let new_cf : bit = tcf;
  let rotated : bits(9) = rotatel9(val8 @ cf_bit, 1);
  new_val == rotated[8..1] & new_cf == rotated[0]
}

// RCL single step, os=16
$property
function prop_rcl_step16(val16 : word, cf_bit : bit) -> bool = {
  let tcf : bit = val16[15];
  let new_val : word = val16[14..0] @ cf_bit;
  let new_cf : bit = tcf;
  let rotated : bits(17) = rotatel17(val16 @ cf_bit, 1);
  new_val == rotated[16..1] & new_cf == rotated[0]
}

// RCL single step, os=32
$property
function prop_rcl_step32(val32 : dword, cf_bit : bit) -> bool = {
  let tcf : bit = val32[31];
  let new_val : dword = val32[30..0] @ cf_bit;
  let new_cf : bit = tcf;
  let rotated : bits(33) = rotatel33(val32 @ cf_bit, 1);
  new_val == rotated[32..1] & new_cf == rotated[0]
}

// RCL single step, os=64
$property
function prop_rcl_step64(val64 : qword, cf_bit : bit) -> bool = {
  let tcf : bit = val64[63];
  let new_val : qword = val64[62..0] @ cf_bit;
  let new_cf : bit = tcf;
  let rotated : bits(65) = rotatel65(val64 @ cf_bit, 1);
  new_val == rotated[64..1] & new_cf == rotated[0]
}

// RCR single step — verbatim from old exec_rcr loop body, os=8
$property
function prop_rcr_step8(val8 : byte, cf_bit : bit) -> bool = {
  let tcf : bit = val8[0];
  let new_val : byte = cf_bit @ val8[7..1];
  let new_cf : bit = tcf;
  let rotated : bits(9) = rotater9(val8 @ cf_bit, 1);
  new_val == rotated[8..1] & new_cf == rotated[0]
}

// RCR single step, os=16
$property
function prop_rcr_step16(val16 : word, cf_bit : bit) -> bool = {
  let tcf : bit = val16[0];
  let new_val : word = cf_bit @ val16[15..1];
  let new_cf : bit = tcf;
  let rotated : bits(17) = rotater17(val16 @ cf_bit, 1);
  new_val == rotated[16..1] & new_cf == rotated[0]
}

// RCR single step, os=32
$property
function prop_rcr_step32(val32 : dword, cf_bit : bit) -> bool = {
  let tcf : bit = val32[0];
  let new_val : dword = cf_bit @ val32[31..1];
  let new_cf : bit = tcf;
  let rotated : bits(33) = rotater33(val32 @ cf_bit, 1);
  new_val == rotated[32..1] & new_cf == rotated[0]
}

// RCR single step, os=64
$property
function prop_rcr_step64(val64 : qword, cf_bit : bit) -> bool = {
  let tcf : bit = val64[0];
  let new_val : qword = cf_bit @ val64[63..1];
  let new_cf : bit = tcf;
  let rotated : bits(65) = rotater65(val64 @ cf_bit, 1);
  new_val == rotated[64..1] & new_cf == rotated[0]
}

// ================================================================
// Part 2: Rotation composition
//
// rotatel(rotatel(x, a), b) == rotatel(x, a + b)  when a + b <= width
// This lets us conclude: N single-step rotations = rotatel(x, N).
// ================================================================

$property
function prop_rotatel9_compose(x : bits(9), a : bits(4), b : bits(4)) -> bool = {
  let va : range(0, 8) = unsigned(a) % 9;
  let vb : range(0, 8) = unsigned(b) % 9;
  let sum : range(0, 8) = (va + vb) % 9;
  rotatel9(rotatel9(x, va), vb) == rotatel9(x, sum)
}

$property
function prop_rotater9_compose(x : bits(9), a : bits(4), b : bits(4)) -> bool = {
  let va : range(0, 8) = unsigned(a) % 9;
  let vb : range(0, 8) = unsigned(b) % 9;
  let sum : range(0, 8) = (va + vb) % 9;
  rotater9(rotater9(x, va), vb) == rotater9(x, sum)
}

$property
function prop_rotatel17_compose(x : bits(17), a : bits(5), b : bits(5)) -> bool = {
  let va : range(0, 16) = unsigned(a) % 17;
  let vb : range(0, 16) = unsigned(b) % 17;
  let sum : range(0, 16) = (va + vb) % 17;
  rotatel17(rotatel17(x, va), vb) == rotatel17(x, sum)
}

$property
function prop_rotater17_compose(x : bits(17), a : bits(5), b : bits(5)) -> bool = {
  let va : range(0, 16) = unsigned(a) % 17;
  let vb : range(0, 16) = unsigned(b) % 17;
  let sum : range(0, 16) = (va + vb) % 17;
  rotater17(rotater17(x, va), vb) == rotater17(x, sum)
}

$property
function prop_rotatel33_compose(x : bits(33), a : bits(6), b : bits(6)) -> bool = {
  let va : range(0, 32) = unsigned(a) % 33;
  let vb : range(0, 32) = unsigned(b) % 33;
  let sum : range(0, 32) = (va + vb) % 33;
  rotatel33(rotatel33(x, va), vb) == rotatel33(x, sum)
}

$property
function prop_rotater33_compose(x : bits(33), a : bits(6), b : bits(6)) -> bool = {
  let va : range(0, 32) = unsigned(a) % 33;
  let vb : range(0, 32) = unsigned(b) % 33;
  let sum : range(0, 32) = (va + vb) % 33;
  rotater33(rotater33(x, va), vb) == rotater33(x, sum)
}

$property
function prop_rotatel65_compose(x : bits(65), a : bits(7), b : bits(7)) -> bool = {
  let va : range(0, 64) = unsigned(a) % 65;
  let vb : range(0, 64) = unsigned(b) % 65;
  let sum : range(0, 64) = (va + vb) % 65;
  rotatel65(rotatel65(x, va), vb) == rotatel65(x, sum)
}

$property
function prop_rotater65_compose(x : bits(65), a : bits(7), b : bits(7)) -> bool = {
  let va : range(0, 64) = unsigned(a) % 65;
  let vb : range(0, 64) = unsigned(b) % 65;
  let sum : range(0, 64) = (va + vb) % 65;
  rotater65(rotater65(x, va), vb) == rotater65(x, sum)
}

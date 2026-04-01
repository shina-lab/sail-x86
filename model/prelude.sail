// x86-64 — Prelude

default Order dec

$include <smt.sail>
$include <option.sail>
$include <arith.sail>
$include <string.sail>
$include <mapping.sail>
$include <vector_dec.sail>
$include <generic_equality.sail>
$include <hex_bits.sail>
$include <hex_bits_signed.sail>

val unreachable : forall ('a : Type). unit -> 'a
function unreachable() = {
  print_endline("unreachable");
  exit()
}

overload ~ = {not_bool, not_vec}
overload operator & = {and_vec}
overload operator | = {or_vec}
overload operator ^ = {xor_vec}

val sub_vec = pure {c: "sub_bits", cpp: "sub_bits", _: "sub_vec"} : forall 'n. (bits('n), bits('n)) -> bits('n)
val sub_vec_int = pure {c: "sub_bits_int", cpp: "sub_bits_int", _: "sub_vec_int"} : forall 'n. (bits('n), int) -> bits('n)
overload operator - = {sub_vec, sub_vec_int}
overload operator * = {mult_atom, mult_int}

val quot_positive_round_zero = pure {interpreter: "quot_round_zero", lem: "hardware_quot", c: "tdiv_int", cpp: "tdiv_int"}
  : forall 'n 'm, 'n >= 0 & 'm > 0. (int('n), int('m)) -> int(div('n, 'm))

val rem_positive_round_zero = pure {interpreter: "rem_round_zero", lem: "hardware_mod", c: "tmod_int", cpp: "tmod_int"}
  : forall 'n 'm, 'n >= 0 & 'm > 0. (int('n), int('m)) -> int(mod('n, 'm))

val quot_round_zero = pure {interpreter: "quot_round_zero", lem: "hardware_quot", c: "tdiv_int", cpp: "tdiv_int"}
  : forall 'm, 'm != 0. (int, int('m)) -> int

val rem_round_zero = pure {interpreter: "rem_round_zero", lem: "hardware_mod", c: "tmod_int", cpp: "tmod_int"}
  : forall 'm, 'm != 0. (int, int('m)) -> int

overload operator / = {quot_positive_round_zero}
overload operator % = {rem_positive_round_zero}

val sign_extend : forall 'n 'm, 'm >= 'n. (implicit('m), bits('n)) -> bits('m)
val zero_extend : forall 'n 'm, 'm >= 'n. (implicit('m), bits('n)) -> bits('m)
function sign_extend(m, v) = sail_sign_extend(v, m)
function zero_extend(m, v) = sail_zero_extend(v, m)

val zeros : forall 'n, 'n >= 0. implicit('n) -> bits('n)
function zeros(n) = sail_zeros(n)

val ones : forall 'n, 'n >= 0. implicit('n) -> bits('n)
function ones(n) = sail_ones(n)

val trunc : forall 'm 'n, 'm >= 0 & 'm <= 'n. (implicit('m), bits('n)) -> bits('m)
function trunc(m, v) = truncate(v, m)

infix 4 <_s
infix 4 >_s
infix 4 <=_s
infix 4 >=_s
infix 4 <_u
infix 4 >_u
infix 4 <=_u
infix 4 >=_u

val operator <_s  : forall 'n, 'n > 0. (bits('n), bits('n)) -> bool
val operator >_s  : forall 'n, 'n > 0. (bits('n), bits('n)) -> bool
val operator <=_s : forall 'n, 'n > 0. (bits('n), bits('n)) -> bool
val operator >=_s : forall 'n, 'n > 0. (bits('n), bits('n)) -> bool
val operator <_u  : forall 'n. (bits('n), bits('n)) -> bool
val operator >_u  : forall 'n. (bits('n), bits('n)) -> bool
val operator <=_u : forall 'n. (bits('n), bits('n)) -> bool
val operator >=_u : forall 'n. (bits('n), bits('n)) -> bool

function operator <_s  (x, y) = signed(x) < signed(y)
function operator >_s  (x, y) = signed(x) > signed(y)
function operator <=_s (x, y) = signed(x) <= signed(y)
function operator >=_s (x, y) = signed(x) >= signed(y)
function operator <_u  (x, y) = unsigned(x) < unsigned(y)
function operator >_u  (x, y) = unsigned(x) > unsigned(y)
function operator <=_u (x, y) = unsigned(x) <= unsigned(y)
function operator >=_u (x, y) = unsigned(x) >= unsigned(y)

infix 7 >>
infix 7 >>>
infix 7 <<

val "shift_bits_right" : forall 'n 'm. (bits('n), bits('m)) -> bits('n)
val "shift_bits_right_arith" : forall 'n 'm. (bits('n), bits('m)) -> bits('n)
val "shift_bits_left"  : forall 'n 'm. (bits('n), bits('m)) -> bits('n)
val "shiftl" : forall 'm 'n, 'n >= 0. (bits('m), int('n)) -> bits('m)
val "shiftr" : forall 'm 'n, 'n >= 0. (bits('m), int('n)) -> bits('m)

overload operator >> = {shift_bits_right, shiftr}
overload operator << = {shift_bits_left, shiftl}

// Arithmetic right shift: sign-extend, shift, truncate.
// Unlike sail_arith_shiftright, this handles shift >= width correctly.
val operator >>> : forall 'n 'm, 'n >= 1 & 'm >= 0. (bits('n), int('m)) -> bits('n)
function operator >>>(value, shift) =
  sign_extend('n + shift, value)[('n - 1 + shift) .. shift]

mapping bool_bit : bool <-> bit = {
  true  <-> 0b1,
  false <-> 0b0,
}

function bool_to_bit(x : bool) -> bit = bool_bit(x)

val to_bits : forall 'l 'x, 'l >= 0 & 0 <= 'x < 2 ^ 'l. (implicit('l), int('x)) -> bits('l)
function to_bits(l, n) = get_slice_int(l, n, 0)

val to_bits_truncate : forall 'l, 'l >= 0. (implicit('l), int) -> bits('l)
function to_bits_truncate(l, n) = get_slice_int(l, n, 0)

val print_log = pure {c: "print_endline", cpp: "print_endline", _: "print_endline"} : string -> unit
val trace_log = pure {c: "trace_stderr", cpp: "trace_stderr", _: "print_endline"} : string -> unit

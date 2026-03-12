default Order dec

$include <prelude.sail>

overload operator - = {sub_bits}
overload operator + = {add_bits}
overload operator ^ = {xor_vec}
overload operator & = {and_vec}
overload operator | = {or_vec}
overload zeros = {sail_zeros}

val "shift_bits_right" : forall 'n 'm. (bits('n), bits('m)) -> bits('n)
val "shift_bits_left"  : forall 'n 'm. (bits('n), bits('m)) -> bits('n)

val to_bits : forall 'l 'x, 'l >= 0 & 0 <= 'x < 2 ^ 'l. (implicit('l), int('x)) -> bits('l)
function to_bits(l, n) = get_slice_int(l, n, 0)

val to_bits_truncate : forall 'l, 'l >= 0. (implicit('l), int) -> bits('l)
function to_bits_truncate(l, n) = get_slice_int(l, n, 0)

// Prove: removing the c==0 guard from rotate is safe.
// When c=0: to_bits_truncate(5, 32) wraps to 0b00000, so both shifts by 0 give elem.

$property
function prop_rotr32(elem : bits(32), cnt : bits(5)) -> bool = {
  let c : range(0, 31) = unsigned(cnt);
  let branchless : bits(32) = shift_bits_right(elem, cnt) | shift_bits_left(elem, to_bits_truncate(5, 32 - c));
  let original : bits(32) = if c == 0 then elem
    else {
      let rc : range(1, 31) = 32 - c;
      shift_bits_right(elem, cnt) | shift_bits_left(elem, to_bits(5, rc))
    };
  branchless == original
}

$property
function prop_rotl32(elem : bits(32), cnt : bits(5)) -> bool = {
  let c : range(0, 31) = unsigned(cnt);
  let branchless : bits(32) = shift_bits_left(elem, cnt) | shift_bits_right(elem, to_bits_truncate(5, 32 - c));
  let original : bits(32) = if c == 0 then elem
    else {
      let rc : range(1, 31) = 32 - c;
      shift_bits_left(elem, cnt) | shift_bits_right(elem, to_bits(5, rc))
    };
  branchless == original
}

$property
function prop_rotr64(elem : bits(64), cnt : bits(6)) -> bool = {
  let c : range(0, 63) = unsigned(cnt);
  let branchless : bits(64) = shift_bits_right(elem, cnt) | shift_bits_left(elem, to_bits_truncate(6, 64 - c));
  let original : bits(64) = if c == 0 then elem
    else {
      let rc : range(1, 63) = 64 - c;
      shift_bits_right(elem, cnt) | shift_bits_left(elem, to_bits(6, rc))
    };
  branchless == original
}

$property
function prop_rotl64(elem : bits(64), cnt : bits(6)) -> bool = {
  let c : range(0, 63) = unsigned(cnt);
  let branchless : bits(64) = shift_bits_left(elem, cnt) | shift_bits_right(elem, to_bits_truncate(6, 64 - c));
  let original : bits(64) = if c == 0 then elem
    else {
      let rc : range(1, 63) = 64 - c;
      shift_bits_left(elem, cnt) | shift_bits_right(elem, to_bits(6, rc))
    };
  branchless == original
}

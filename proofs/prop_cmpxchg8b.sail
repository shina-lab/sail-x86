// Equivalence proof: CMPXCHG8B/16B partial branchless conversion
//
// The memory write must stay conditional (side effect).
// But ZF computation and register writes can be branchless:
//
// Old: if RAX==mem_lo & RDX==mem_hi then { ZF=1; write_mem } else { ZF=0; RAX=mem_lo; RDX=mem_hi }
// New: let eq = is_eq(RAX,mem_lo) & is_eq(RDX,mem_hi);
//      ZF = eq;
//      if eq == 0b1 then write_mem;  // memory write stays conditional
//      RAX = blend(mem_lo, old_RAX, eq);
//      RDX = blend(mem_hi, old_RDX, eq);

$include "../model/prelude.sail"

val or_reduce : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bits(1)
function or_reduce(v) = {
  let x1 : bits(64) = zero_extend(v);
  let x2 = x1 | (x1 >> 1);
  let x3 = x2 | (x2 >> 2);
  let x4 = x3 | (x3 >> 4);
  let x5 = x4 | (x4 >> 8);
  let x6 = x5 | (x5 >> 16);
  let x7 = x6 | (x6 >> 32);
  x7[0]
}

val is_zero : forall 'n, 0 < 'n & 'n <= 64. bits('n) -> bit
function is_zero(v) = (~(or_reduce(v)))[0]

val is_eq : forall 'n, 0 < 'n & 'n <= 64. (bits('n), bits('n)) -> bit
function is_eq(a, b) = is_zero(a ^ b)

val blend : forall 'n, 0 < 'n. (bits('n), bits('n), bit) -> bits('n)
function blend(a, b, sel) = {
  let m : bits('n) = sign_extend(sel);
  (a & ~(m)) | (b & m)
}

// Prove: is_eq(a,b) & is_eq(c,d) matches a==b & c==d
$property
function prop_eq_and(a : bits(32), b : bits(32), c : bits(32), d : bits(32)) -> bool = {
  let orig : bool = a == b & c == d;
  let branchless : bit = is_eq(a, b) & is_eq(c, d);
  bool_to_bit(orig) == branchless
}

// Prove: register blend is correct
$property
function prop_cmpxchg8b_reg(mem_lo : bits(32), old_rax : bits(32), eq : bit) -> bool = {
  let orig : bits(32) = if eq == 0b1 then old_rax else mem_lo;
  let branchless : bits(32) = blend(mem_lo, old_rax, eq);
  orig == branchless
}

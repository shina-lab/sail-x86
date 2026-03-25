// Equivalence proof: VALIGND/VALIGNQ branchless rewrite
//
// Old: foreach loop with if/else selecting from src1 or src2 per element
// New: concatenate src1:src2, shift right, extract low bits (one-liner)
//
// Proves 128-bit variants (4 dword / 2 qword iterations).
// 256/512-bit variants follow the identical pattern.

$include "../model/prelude.sail"

type byte    = bits(8)
type word    = bits(16)
type dword   = bits(32)
type qword   = bits(64)
type xmmword = bits(128)

// --- OLD: branchy valignd_128 ---

val avx_valignd_128_old : (xmmword, xmmword, byte) -> xmmword
function avx_valignd_128_old(src1, src2, imm) = {
  let shift : range(0, 3) = unsigned(imm[1..0]);
  var r : xmmword = zeros();
  foreach (i from 0 to 3) {
    let src_idx : range(0, 7) = i + shift;
    let dst_lo : range(0, 96) = i * 32;
    if src_idx < 4 then {
      let s : range(0, 96) = src_idx * 32; r[(dst_lo + 31)..dst_lo] = src2[(s + 31)..s]
    } else {
      let s : range(0, 96) = (src_idx - 4) * 32; r[(dst_lo + 31)..dst_lo] = src1[(s + 31)..s]
    };
  };
  r
}

// --- NEW: branchless valignd_128 ---

val avx_valignd_128_new : (xmmword, xmmword, byte) -> xmmword
function avx_valignd_128_new(src1, src2, imm) =
  ((src1 @ src2) >> (unsigned(imm[1..0]) * 32))[127..0]

// --- OLD: branchy valignq_128 ---

val avx_valignq_128_old : (xmmword, xmmword, byte) -> xmmword
function avx_valignq_128_old(src1, src2, imm) = {
  let shift : range(0, 1) = unsigned(imm[0]);
  var r : xmmword = zeros();
  foreach (i from 0 to 1) {
    let src_idx : range(0, 3) = i + shift;
    let dst_lo : range(0, 64) = i * 64;
    if src_idx < 2 then {
      let s : range(0, 64) = src_idx * 64; r[(dst_lo + 63)..dst_lo] = src2[(s + 63)..s]
    } else {
      let s : range(0, 64) = (src_idx - 2) * 64; r[(dst_lo + 63)..dst_lo] = src1[(s + 63)..s]
    };
  };
  r
}

// --- NEW: branchless valignq_128 ---

val avx_valignq_128_new : (xmmword, xmmword, byte) -> xmmword
function avx_valignq_128_new(src1, src2, imm) =
  ((src1 @ src2) >> (unsigned(imm[0..0]) * 64))[127..0]

// --- Equivalence properties ---

$property
function prop_valignd_128(src1 : xmmword, src2 : xmmword, imm : byte) -> bool =
  avx_valignd_128_old(src1, src2, imm) == avx_valignd_128_new(src1, src2, imm)

$property
function prop_valignq_128(src1 : xmmword, src2 : xmmword, imm : byte) -> bool =
  avx_valignq_128_old(src1, src2, imm) == avx_valignq_128_new(src1, src2, imm)

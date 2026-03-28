// x86-64 — Shared SIMD Helpers
//
// Vector-width helper functions shared across legacy SSE, VEX, and EVEX
// instruction files. This file must appear before all insn_*.sail files.

// =========================================================================
// GFNI vector operations
// =========================================================================

val avx_gf2p8mulb : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl)) -> bits('vl)
function avx_gf2p8mulb(src1, src2) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 8 - 1)) {
    let lo = i * 8;
    r[(lo + 7)..lo] = gf2p8_mul(src1[(lo + 7)..lo], src2[(lo + 7)..lo]);
  };
  r
}

// Per-byte affine transform; each byte uses the 8x8 matrix from its 64-bit lane.
val avx_gf2p8affineqb : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl), byte) -> bits('vl)
function avx_gf2p8affineqb(src1, src2, imm8) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 8 - 1)) {
    let lo = i * 8;
    let lane = (i / 8) * 64;
    r[(lo + 7)..lo] = gf2p8_affine(src1[(lo + 7)..lo], src2[(lane + 63)..lane], imm8);
  };
  r
}

// Same but first applies GF(2^8) inverse on each src1 byte.
val avx_gf2p8affineinvqb : forall 'vl, 'vl in {128, 256, 512}.
  (bits('vl), bits('vl), byte) -> bits('vl)
function avx_gf2p8affineinvqb(src1, src2, imm8) = {
  var r : bits('vl) = zeros();
  foreach (i from 0 to ('vl / 8 - 1)) {
    let lo = i * 8;
    let lane = (i / 8) * 64;
    r[(lo + 7)..lo] = gf2p8_affine(gf2p8_inv(src1[(lo + 7)..lo]), src2[(lane + 63)..lane], imm8);
  };
  r
}

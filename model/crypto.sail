// =========================================================================
// AES-NI and SHA extensions — pure Sail implementations.
//
// All 13 crypto primitives (AESENC, AESDEC, AESENCLAST, AESDECLAST, AESIMC,
// AESKEYGENASSIST, SHA1RNDS4, SHA1NEXTE, SHA1MSG1, SHA1MSG2, SHA256RNDS2,
// SHA256MSG1, SHA256MSG2) are defined here. GF(2^8) and rotation primitives
// are reused from branchless.sail.
// =========================================================================

// -------------------------------------------------------------------------
// AES S-boxes
//
// S(x) is defined as the AES affine transform of x's GF(2^8) inverse.
// Using rotation, the affine transform reduces to:
//   sbox(x)     = b ^ rotr(b,4) ^ rotr(b,5) ^ rotr(b,6) ^ rotr(b,7) ^ 0x63
//   inv_sbox(y) = gf_inv(rotr(y,2) ^ rotr(y,5) ^ rotr(y,7) ^ 0x05)
// where b = gf_inv(x).
// -------------------------------------------------------------------------

val aes_sbox : byte -> byte
function aes_sbox(x) = {
  let b = gf2p8_inv(x);
  b ^ rotr(b, 4) ^ rotr(b, 5) ^ rotr(b, 6) ^ rotr(b, 7) ^ 0x63
}

val aes_inv_sbox : byte -> byte
function aes_inv_sbox(y) = {
  let b = rotr(y, 2) ^ rotr(y, 5) ^ rotr(y, 7) ^ 0x05;
  gf2p8_inv(b)
}

// -------------------------------------------------------------------------
// SubBytes / InvSubBytes — apply (inv) S-box to each of 16 bytes.
// -------------------------------------------------------------------------

val aes_sub_bytes : xmmword -> xmmword
function aes_sub_bytes(x) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 8;
    r[(lo + 7)..lo] = aes_sbox(velem(8, x, i));
  };
  r
}

val aes_inv_sub_bytes : xmmword -> xmmword
function aes_inv_sub_bytes(x) = {
  var r : xmmword = zeros();
  foreach (i from 0 to 15) {
    let lo = i * 8;
    r[(lo + 7)..lo] = aes_inv_sbox(velem(8, x, i));
  };
  r
}

// -------------------------------------------------------------------------
// ShiftRows / InvShiftRows
//
// State is column-major: byte i is at position (i mod 4, i div 4).
// ShiftRows rotates row r left by r columns:
//   new[i] = old[shift_rows_tab[i]]
// where shift_rows_tab = [0,5,10,15, 4,9,14,3, 8,13,2,7, 12,1,6,11].
// The concatenation below lists destination bytes from high (pos 15) to low.
// -------------------------------------------------------------------------

val aes_shift_rows : xmmword -> xmmword
function aes_shift_rows(x) =
  velem(8, x, 11) @ velem(8, x, 6)  @ velem(8, x, 1)  @ velem(8, x, 12) @
  velem(8, x, 7)  @ velem(8, x, 2)  @ velem(8, x, 13) @ velem(8, x, 8)  @
  velem(8, x, 3)  @ velem(8, x, 14) @ velem(8, x, 9)  @ velem(8, x, 4)  @
  velem(8, x, 15) @ velem(8, x, 10) @ velem(8, x, 5)  @ velem(8, x, 0)

val aes_inv_shift_rows : xmmword -> xmmword
function aes_inv_shift_rows(x) =
  velem(8, x, 3)  @ velem(8, x, 6)  @ velem(8, x, 9)  @ velem(8, x, 12) @
  velem(8, x, 15) @ velem(8, x, 2)  @ velem(8, x, 5)  @ velem(8, x, 8)  @
  velem(8, x, 11) @ velem(8, x, 14) @ velem(8, x, 1)  @ velem(8, x, 4)  @
  velem(8, x, 7)  @ velem(8, x, 10) @ velem(8, x, 13) @ velem(8, x, 0)

// -------------------------------------------------------------------------
// MixColumns / InvMixColumns
//
// Each 32-bit column [a0 a1 a2 a3] is multiplied by a fixed matrix in
// GF(2^8) (polynomial x^8 + x^4 + x^3 + x + 1). For MixColumns:
//   [b0]   [2 3 1 1] [a0]
//   [b1] = [1 2 3 1] [a1]
//   [b2]   [1 1 2 3] [a2]
//   [b3]   [3 1 1 2] [a3]
// and {0e,0b,0d,09} for InvMixColumns.
// -------------------------------------------------------------------------

val aes_mix_column : bits(32) -> bits(32)
function aes_mix_column(col) = {
  let a0 = col[7..0];
  let a1 = col[15..8];
  let a2 = col[23..16];
  let a3 = col[31..24];
  let b0 = gf2p8_mul(a0, 0x02) ^ gf2p8_mul(a1, 0x03) ^ a2 ^ a3;
  let b1 = a0 ^ gf2p8_mul(a1, 0x02) ^ gf2p8_mul(a2, 0x03) ^ a3;
  let b2 = a0 ^ a1 ^ gf2p8_mul(a2, 0x02) ^ gf2p8_mul(a3, 0x03);
  let b3 = gf2p8_mul(a0, 0x03) ^ a1 ^ a2 ^ gf2p8_mul(a3, 0x02);
  b3 @ b2 @ b1 @ b0
}

val aes_inv_mix_column : bits(32) -> bits(32)
function aes_inv_mix_column(col) = {
  let a0 = col[7..0];
  let a1 = col[15..8];
  let a2 = col[23..16];
  let a3 = col[31..24];
  let b0 = gf2p8_mul(a0, 0x0E) ^ gf2p8_mul(a1, 0x0B) ^ gf2p8_mul(a2, 0x0D) ^ gf2p8_mul(a3, 0x09);
  let b1 = gf2p8_mul(a0, 0x09) ^ gf2p8_mul(a1, 0x0E) ^ gf2p8_mul(a2, 0x0B) ^ gf2p8_mul(a3, 0x0D);
  let b2 = gf2p8_mul(a0, 0x0D) ^ gf2p8_mul(a1, 0x09) ^ gf2p8_mul(a2, 0x0E) ^ gf2p8_mul(a3, 0x0B);
  let b3 = gf2p8_mul(a0, 0x0B) ^ gf2p8_mul(a1, 0x0D) ^ gf2p8_mul(a2, 0x09) ^ gf2p8_mul(a3, 0x0E);
  b3 @ b2 @ b1 @ b0
}

val aes_mix_columns : xmmword -> xmmword
function aes_mix_columns(x) = {
  let c0 = aes_mix_column(x[31..0]);
  let c1 = aes_mix_column(x[63..32]);
  let c2 = aes_mix_column(x[95..64]);
  let c3 = aes_mix_column(x[127..96]);
  c3 @ c2 @ c1 @ c0
}

val aes_inv_mix_columns : xmmword -> xmmword
function aes_inv_mix_columns(x) = {
  let c0 = aes_inv_mix_column(x[31..0]);
  let c1 = aes_inv_mix_column(x[63..32]);
  let c2 = aes_inv_mix_column(x[95..64]);
  let c3 = aes_inv_mix_column(x[127..96]);
  c3 @ c2 @ c1 @ c0
}

// -------------------------------------------------------------------------
// AES-NI instructions
// -------------------------------------------------------------------------

val aesenc : (xmmword, xmmword) -> xmmword
function aesenc(state, key) =
  aes_mix_columns(aes_sub_bytes(aes_shift_rows(state))) ^ key

val aesenclast : (xmmword, xmmword) -> xmmword
function aesenclast(state, key) =
  aes_sub_bytes(aes_shift_rows(state)) ^ key

val aesdec : (xmmword, xmmword) -> xmmword
function aesdec(state, key) =
  aes_inv_mix_columns(aes_inv_sub_bytes(aes_inv_shift_rows(state))) ^ key

val aesdeclast : (xmmword, xmmword) -> xmmword
function aesdeclast(state, key) =
  aes_inv_sub_bytes(aes_inv_shift_rows(state)) ^ key

val aesimc : xmmword -> xmmword
function aesimc(x) = aes_inv_mix_columns(x)

// AESKEYGENASSIST xmm1, xmm2/m128, imm8:
//   DEST[31:0]    = SubWord(SRC[63:32])
//   DEST[63:32]   = RotWord(SubWord(SRC[63:32])) XOR rcon
//   DEST[95:64]   = SubWord(SRC[127:96])
//   DEST[127:96]  = RotWord(SubWord(SRC[127:96])) XOR rcon
// where RotWord rotates a 32-bit word right by 8 bits, rcon = zero_extend(imm8, 32).

val aes_sub_word : bits(32) -> bits(32)
function aes_sub_word(w) =
  aes_sbox(w[31..24]) @ aes_sbox(w[23..16]) @ aes_sbox(w[15..8]) @ aes_sbox(w[7..0])

val aes_rot_word : bits(32) -> bits(32)
function aes_rot_word(w) = w[7..0] @ w[31..8]

val aeskeygenassist : (xmmword, byte) -> xmmword
function aeskeygenassist(key, imm) = {
  let rcon : bits(32) = zero_extend(imm);
  let x1 = key[63..32];
  let x3 = key[127..96];
  let sx1 = aes_sub_word(x1);
  let sx3 = aes_sub_word(x3);
  let y0 : bits(32) = sx1;
  let y1 : bits(32) = aes_rot_word(sx1) ^ rcon;
  let y2 : bits(32) = sx3;
  let y3 : bits(32) = aes_rot_word(sx3) ^ rcon;
  y3 @ y2 @ y1 @ y0
}

// =========================================================================
// SHA-1
// =========================================================================

// SHA-1 per-round function selected by imm8[1:0]:
//   0: Ch     (B & C) ^ (~B & D)
//   1: Parity B ^ C ^ D
//   2: Maj    (B & C) ^ (B & D) ^ (C & D)
//   3: Parity B ^ C ^ D

val sha1_f : (bits(2), bits(32), bits(32), bits(32)) -> bits(32)
function sha1_f(sel, b, c, d) = match sel {
  0b00 => (b & c) ^ (~(b) & d),
  0b01 => b ^ c ^ d,
  0b10 => (b & c) ^ (b & d) ^ (c & d),
  0b11 => b ^ c ^ d,
}

val sha1_k : bits(2) -> bits(32)
function sha1_k(sel) = match sel {
  0b00 => 0x5A827999,
  0b01 => 0x6ED9EBA1,
  0b10 => 0x8F1BBCDC,
  0b11 => 0xCA62C1D6,
}

// SHA1RNDS4: performs four rounds of SHA-1 using the function and constant
// K selected by imm8[1:0]. SRC1 holds state (A,B,C,D); SRC2 holds W+K values.
//
// Each round:  A' = f(B,C,D) + rotl(A,5) + W_i + K  (+ E in rounds 1-3)
//              (B,C,D,E) <- (A, rotl(B,30), C, D)
// E is pipelined from the initial D and added to rounds 1-3's A update.

val sha1rnds4 : (xmmword, xmmword, byte) -> xmmword
function sha1rnds4(src1, src2, imm) = {
  let sel = imm[1..0];
  let k = sha1_k(sel);
  let a0 : bits(32) = src1[127..96];
  let b0 : bits(32) = src1[95..64];
  let c0 : bits(32) = src1[63..32];
  let d0 : bits(32) = src1[31..0];
  let w0 : bits(32) = src2[127..96];
  let w1 : bits(32) = src2[95..64];
  let w2 : bits(32) = src2[63..32];
  let w3 : bits(32) = src2[31..0];
  // Round 0: no E term
  let a1 = sha1_f(sel, b0, c0, d0) + rotl(a0, 5) + w0 + k;
  let b1 = a0;
  let c1 = rotl(b0, 30);
  let d1 = c0;
  let e1 : bits(32) = d0;
  // Round 1: add e1 (= original D)
  let a2 = sha1_f(sel, b1, c1, d1) + rotl(a1, 5) + w1 + k + e1;
  let b2 = a1;
  let c2 = rotl(b1, 30);
  let d2 = c1;
  let e2 : bits(32) = d1;
  // Round 2: add e2 (= original C)
  let a3 = sha1_f(sel, b2, c2, d2) + rotl(a2, 5) + w2 + k + e2;
  let b3 = a2;
  let c3 = rotl(b2, 30);
  let d3 = c2;
  let e3 : bits(32) = d2;
  // Round 3: add e3 (= rotl(original B, 30))
  let a4 = sha1_f(sel, b3, c3, d3) + rotl(a3, 5) + w3 + k + e3;
  let b4 = a3;
  let c4 = rotl(b3, 30);
  let d4 = c3;
  a4 @ b4 @ c4 @ d4
}

// SHA1NEXTE:  DEST = (SRC2[127:96] + rotl(SRC1[127:96], 30)) @ SRC2[95:0]
val sha1nexte : (xmmword, xmmword) -> xmmword
function sha1nexte(src1, src2) = {
  let e : bits(32) = rotl(src1[127..96], 30);
  (src2[127..96] + e) @ src2[95..64] @ src2[63..32] @ src2[31..0]
}

// SHA1MSG1: pairwise XOR of W_{i-16..i-13} and W_{i-14..i-11}.
val sha1msg1 : (xmmword, xmmword) -> xmmword
function sha1msg1(src1, src2) = {
  let w0 = src1[127..96];
  let w1 = src1[95..64];
  let w2 = src1[63..32];
  let w3 = src1[31..0];
  let w4 = src2[127..96];
  let w5 = src2[95..64];
  (w2 ^ w0) @ (w3 ^ w1) @ (w4 ^ w2) @ (w5 ^ w3)
}

// SHA1MSG2: final stage of SHA-1 message schedule — computes W_{i..i+3}.
val sha1msg2 : (xmmword, xmmword) -> xmmword
function sha1msg2(src1, src2) = {
  let w13 = src2[95..64];
  let w14 = src2[63..32];
  let w15 = src2[31..0];
  let w16 : bits(32) = rotl(src1[127..96] ^ w13, 1);
  let w17 : bits(32) = rotl(src1[95..64]  ^ w14, 1);
  let w18 : bits(32) = rotl(src1[63..32]  ^ w15, 1);
  let w19 : bits(32) = rotl(src1[31..0]   ^ w16, 1);
  w16 @ w17 @ w18 @ w19
}

// =========================================================================
// SHA-256
// =========================================================================

val sha_ch : (bits(32), bits(32), bits(32)) -> bits(32)
function sha_ch(x, y, z) = (x & y) ^ (~(x) & z)

val sha_maj : (bits(32), bits(32), bits(32)) -> bits(32)
function sha_maj(x, y, z) = (x & y) ^ (x & z) ^ (y & z)

// Upper-case sigmas (compression).
val sha256_bigsigma0 : bits(32) -> bits(32)
function sha256_bigsigma0(x) = rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22)

val sha256_bigsigma1 : bits(32) -> bits(32)
function sha256_bigsigma1(x) = rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25)

// Lower-case sigmas (message schedule).
val sha256_sigma0 : bits(32) -> bits(32)
function sha256_sigma0(x) = rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3)

val sha256_sigma1 : bits(32) -> bits(32)
function sha256_sigma1(x) = rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10)

// SHA256RNDS2: two rounds of SHA-256.
//   SRC1 = (C, D, G, H) ; SRC2 = (A, B, E, F) ; XMM0 = (.., .., WK1, WK0).
//   DEST = (A_2, B_2, E_2, F_2).
val sha256rnds2 : (xmmword, xmmword, xmmword) -> xmmword
function sha256rnds2(src1, src2, xmm0) = {
  let a0 : bits(32) = src2[127..96];
  let b0 : bits(32) = src2[95..64];
  let c0 : bits(32) = src1[127..96];
  let d0 : bits(32) = src1[95..64];
  let e0 : bits(32) = src2[63..32];
  let f0 : bits(32) = src2[31..0];
  let g0 : bits(32) = src1[63..32];
  let h0 : bits(32) = src1[31..0];
  let wk0 : bits(32) = xmm0[31..0];
  let wk1 : bits(32) = xmm0[63..32];
  let t0 = sha_ch(e0, f0, g0) + sha256_bigsigma1(e0) + wk0 + h0;
  let a1 = t0 + sha_maj(a0, b0, c0) + sha256_bigsigma0(a0);
  let b1 = a0;
  let c1 = b0;
  let d1 = c0;
  let e1 = t0 + d0;
  let f1 = e0;
  let g1 = f0;
  let h1 = g0;
  let t1 = sha_ch(e1, f1, g1) + sha256_bigsigma1(e1) + wk1 + h1;
  let a2 = t1 + sha_maj(a1, b1, c1) + sha256_bigsigma0(a1);
  let b2 = a1;
  let e2 = t1 + d1;
  let f2 = e1;
  a2 @ b2 @ e2 @ f2
}

// SHA256MSG1: intermediate message schedule —  W_i + σ0(W_{i+1}).
val sha256msg1 : (xmmword, xmmword) -> xmmword
function sha256msg1(src1, src2) = {
  let w0 = src1[31..0];
  let w1 = src1[63..32];
  let w2 = src1[95..64];
  let w3 = src1[127..96];
  let w4 = src2[31..0];
  (w3 + sha256_sigma0(w4)) @ (w2 + sha256_sigma0(w3)) @
  (w1 + sha256_sigma0(w2)) @ (w0 + sha256_sigma0(w1))
}

// SHA256MSG2: final message schedule — W_{i+16..i+19}.
val sha256msg2 : (xmmword, xmmword) -> xmmword
function sha256msg2(src1, src2) = {
  let w14 = src2[95..64];
  let w15 = src2[127..96];
  let w16 = src1[31..0]   + sha256_sigma1(w14);
  let w17 = src1[63..32]  + sha256_sigma1(w15);
  let w18 = src1[95..64]  + sha256_sigma1(w16);
  let w19 = src1[127..96] + sha256_sigma1(w17);
  w19 @ w18 @ w17 @ w16
}

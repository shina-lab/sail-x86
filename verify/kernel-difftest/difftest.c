// Run the original (o_) and rewritten (n_) kernel routines on the same
// random inputs and compare every output.  See run.sh.
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

typedef uint8_t u8; typedef uint32_t u32; typedef uint64_t u64;

#define BOTH(ret, name, args) ret o_##name args; ret n_##name args;
BOTH(void, polyval_mul_pclmul, (u8 *a, const u8 *b))
BOTH(void, ghash_blocks_pclmul, (u8 *acc, const u8 *key, const u8 *data, size_t nblocks))
BOTH(void, sha256_transform_ssse3, (u32 *state, const u8 *data, size_t nblocks))
BOTH(void, sha512_transform_rorx, (u64 *state, const u8 *data, size_t nblocks))
BOTH(void, sm3_transform_avx, (u32 *state, const u8 *data, int nblocks))
BOTH(void, chacha_2block_xor_avx2, (const u32 *state, u8 *dst, const u8 *src, unsigned len, int nrounds))
BOTH(void, chacha_4block_xor_avx2, (const u32 *state, u8 *dst, const u8 *src, unsigned len, int nrounds))
BOTH(void, poly1305_blocks_x86_64, (void *ctx, const u8 *inp, size_t len, u32 padbit))
BOTH(void, aes128_expandkey_aesni, (u32 *rndkeys, u32 *inv_rndkeys, const u8 *in_key))
BOTH(void, aes256_expandkey_aesni, (u32 *rndkeys, u32 *inv_rndkeys, const u8 *in_key))
BOTH(void, aegis128_aesni_enc, (void *state, const u8 *src, u8 *dst, unsigned len))
BOTH(void, aegis128_aesni_enc_tail, (void *state, const u8 *src, u8 *dst, unsigned len))
BOTH(void, aes_gcm_precompute_aesni, (void *key))
BOTH(void, aes_gcm_precompute_aesni_avx, (void *key))
BOTH(void, camellia_ecb_enc_16way, (const void *ctx, u8 *dst, const u8 *src))
BOTH(void, camellia_ecb_dec_16way, (const void *ctx, u8 *dst, const u8 *src))
BOTH(void, camellia_ecb_enc_32way, (const void *ctx, u8 *dst, const u8 *src))
BOTH(void, camellia_ecb_dec_32way, (const void *ctx, u8 *dst, const u8 *src))
BOTH(void, aria_aesni_avx_encrypt_16way, (const void *ctx, u8 *dst, const u8 *src))
BOTH(void, aria_aesni_avx2_encrypt_32way, (const void *ctx, u8 *dst, const u8 *src))
BOTH(void, aria_gfni_avx512_encrypt_64way, (const void *ctx, u8 *dst, const u8 *src))
BOTH(void, __serpent_enc_blk_8way, (const void *ctx, u8 *dst, const u8 *src, int xor))
BOTH(void, serpent_dec_blk_8way, (const void *ctx, u8 *dst, const u8 *src))
BOTH(unsigned long, copy_mc_fragile, (void *dst, const void *src, unsigned len))
BOTH(void *, __memset, (void *s, int c, size_t n))
BOTH(uint16_t, ip_compute_csum, (const void *buff, int len))

// Reached only from copy_mc_fragile's machine-check fixup path.
unsigned long o_copy_mc_fragile_handle_tail(char *to, char *from, unsigned len) { abort(); }
unsigned long n_copy_mc_fragile_handle_tail(char *to, char *from, unsigned len) { abort(); }

static u64 rng = 0x9e3779b97f4a7c15ull;
static u64 rnd(void) { rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17; return rng; }
static void fill(void *p, size_t n) { u8 *b = p; for (size_t i = 0; i < n; i++) b[i] = rnd(); }

static int fails, tests;
#define TRIALS 3000
#define CHECK(name, a, b, n) do { tests++; if (memcmp(a, b, n)) { fails++; if (fails <= 40) printf("FAIL %-32s trial %d\n", name, t); } } while (0)
#define DONE(name)

#define ALIGNED __attribute__((aligned(64)))

int main(void) {
    static u8 ALIGNED A[4096], B[4096], C[4096], D[4096], E[4096], F[4096];
    int t;

    for (t = 0; t < TRIALS; t++) {
        fill(A, 16); fill(B, 16); memcpy(C, A, 16);
        o_polyval_mul_pclmul(A, B); n_polyval_mul_pclmul(C, B);
        CHECK("polyval_mul_pclmul", A, C, 16); DONE(polyval_mul_pclmul)
    }
    for (t = 0; t < TRIALS; t++) {
        size_t nb = 1 + rnd() % 8;
        fill(A, 16); fill(B, 16); fill(D, 16 * nb); memcpy(C, A, 16);
        o_ghash_blocks_pclmul(A, B, D, nb); n_ghash_blocks_pclmul(C, B, D, nb);
        CHECK("ghash_blocks_pclmul", A, C, 16); DONE(ghash_blocks_pclmul)
    }
    for (t = 0; t < TRIALS; t++) {
        size_t nb = 1 + rnd() % 3;
        fill(A, 32); fill(D, 64 * nb); memcpy(C, A, 32);
        o_sha256_transform_ssse3((u32 *)A, D, nb); n_sha256_transform_ssse3((u32 *)C, D, nb);
        CHECK("sha256_transform_ssse3", A, C, 32); DONE(sha256_transform_ssse3)
    }
    for (t = 0; t < TRIALS; t++) {
        size_t nb = 1 + rnd() % 3;
        fill(A, 64); fill(D, 128 * nb); memcpy(C, A, 64);
        o_sha512_transform_rorx((u64 *)A, D, nb); n_sha512_transform_rorx((u64 *)C, D, nb);
        CHECK("sha512_transform_rorx", A, C, 64); DONE(sha512_transform_rorx)
    }
    for (t = 0; t < TRIALS; t++) {
        int nb = 1 + rnd() % 3;
        fill(A, 32); fill(D, 64 * nb); memcpy(C, A, 32);
        o_sm3_transform_avx((u32 *)A, D, nb); n_sm3_transform_avx((u32 *)C, D, nb);
        CHECK("sm3_transform_avx", A, C, 32); DONE(sm3_transform_avx)
    }
    for (t = 0; t < TRIALS; t++) {
        unsigned len = 1 + rnd() % 128; int nr = (int[]){20, 12, 8}[rnd() % 3];
        fill(A, 64); fill(D, 128); memset(B, 0, 128); memset(C, 0, 128);
        o_chacha_2block_xor_avx2((u32 *)A, B, D, len, nr); n_chacha_2block_xor_avx2((u32 *)A, C, D, len, nr);
        CHECK("chacha_2block_xor_avx2", B, C, 128); DONE(chacha_2block_xor_avx2)
    }
    for (t = 0; t < TRIALS; t++) {
        unsigned len = 1 + rnd() % 256; int nr = (int[]){20, 12, 8}[rnd() % 3];
        fill(A, 64); fill(D, 256); memset(B, 0, 256); memset(C, 0, 256);
        o_chacha_4block_xor_avx2((u32 *)A, B, D, len, nr); n_chacha_4block_xor_avx2((u32 *)A, C, D, len, nr);
        CHECK("chacha_4block_xor_avx2", B, C, 256); DONE(chacha_4block_xor_avx2)
    }
    for (t = 0; t < TRIALS; t++) {
        size_t len = 16 * (1 + rnd() % 4); u32 pad = rnd() & 1;
        fill(A, 128); fill(D, 64); memcpy(C, A, 128);
        o_poly1305_blocks_x86_64(A, D, len, pad); n_poly1305_blocks_x86_64(C, D, len, pad);
        CHECK("poly1305_blocks_x86_64", A, C, 128); DONE(poly1305_blocks_x86_64)
    }
    for (t = 0; t < TRIALS; t++) {
        fill(D, 32); memset(A, 0, 512); memset(B, 0, 512); memset(C, 0, 512); memset(E, 0, 512);
        o_aes128_expandkey_aesni((u32 *)A, (u32 *)B, D); n_aes128_expandkey_aesni((u32 *)C, (u32 *)E, D);
        CHECK("aes128_expandkey_aesni", A, C, 512); CHECK("aes128_expandkey_aesni_inv", B, E, 512);
        DONE(aes128_expandkey_aesni) DONE(aes128_expandkey_aesni_inv)
    }
    for (t = 0; t < TRIALS; t++) {
        fill(D, 32); memset(A, 0, 512); memset(B, 0, 512); memset(C, 0, 512); memset(E, 0, 512);
        o_aes256_expandkey_aesni((u32 *)A, (u32 *)B, D); n_aes256_expandkey_aesni((u32 *)C, (u32 *)E, D);
        CHECK("aes256_expandkey_aesni", A, C, 512); CHECK("aes256_expandkey_aesni_inv", B, E, 512);
        DONE(aes256_expandkey_aesni) DONE(aes256_expandkey_aesni_inv)
    }
    for (t = 0; t < TRIALS; t++) {
        unsigned len = 16 * (1 + rnd() % 5);
        fill(A, 80); fill(D, 80); memcpy(C, A, 80); memset(B, 0, 80); memset(E, 0, 80);
        o_aegis128_aesni_enc(A, D, B, len); n_aegis128_aesni_enc(C, D, E, len);
        CHECK("aegis128_aesni_enc_state", A, C, 80); CHECK("aegis128_aesni_enc_out", B, E, 80);
        DONE(aegis128_aesni_enc_state) DONE(aegis128_aesni_enc_out)
    }
    for (t = 0; t < TRIALS; t++) {
        unsigned len = 1 + rnd() % 15;
        fill(A, 80); fill(D, 16); memcpy(C, A, 80); memset(B, 0, 16); memset(E, 0, 16);
        o_aegis128_aesni_enc_tail(A, D, B, len); n_aegis128_aesni_enc_tail(C, D, E, len);
        CHECK("aegis128_aesni_enc_tail_state", A, C, 80); CHECK("aegis128_aesni_enc_tail_out", B, E, 16);
        DONE(aegis128_aesni_enc_tail_state) DONE(aegis128_aesni_enc_tail_out)
    }
    for (t = 0; t < TRIALS; t++) {
        // struct aes_gcm_key_aesni: keylen at 0, round keys at 16, H powers from 272.
        fill(A, 1024); *(u32 *)A = 16 + 8 * (rnd() % 3); memcpy(C, A, 1024);
        o_aes_gcm_precompute_aesni(A); n_aes_gcm_precompute_aesni(C);
        CHECK("aes_gcm_precompute_aesni", A, C, 1024); DONE(aes_gcm_precompute_aesni)
    }
    for (t = 0; t < TRIALS; t++) {
        fill(A, 1024); *(u32 *)A = 16 + 8 * (rnd() % 3); memcpy(C, A, 1024);
        o_aes_gcm_precompute_aesni_avx(A); n_aes_gcm_precompute_aesni_avx(C);
        CHECK("aes_gcm_precompute_aesni_avx", A, C, 1024); DONE(aes_gcm_precompute_aesni_avx)
    }
    for (t = 0; t < TRIALS; t++) {
        // struct camellia_ctx: key_table[272 bytes], key_length (16 or 32) at 272.
        fill(A, 512); *(u32 *)(A + 272) = (rnd() & 1) ? 16 : 32; fill(D, 512);
        o_camellia_ecb_enc_16way(A, B, D); n_camellia_ecb_enc_16way(A, C, D);
        CHECK("camellia_ecb_enc_16way", B, C, 256);
        o_camellia_ecb_dec_16way(A, B, D); n_camellia_ecb_dec_16way(A, C, D);
        CHECK("camellia_ecb_dec_16way", B, C, 256);
        o_camellia_ecb_enc_32way(A, B, D); n_camellia_ecb_enc_32way(A, C, D);
        CHECK("camellia_ecb_enc_32way", B, C, 512);
        o_camellia_ecb_dec_32way(A, B, D); n_camellia_ecb_dec_32way(A, C, D);
        CHECK("camellia_ecb_dec_32way", B, C, 512);
        DONE(camellia_ecb_enc_16way) DONE(camellia_ecb_dec_16way) DONE(camellia_ecb_enc_32way) DONE(camellia_ecb_dec_32way)
    }
    for (t = 0; t < TRIALS; t++) {
        // struct aria_ctx: enc_key at 0, dec_key at 272, rounds (12/14/16) at 544.
        fill(A, 1024); *(int *)(A + 544) = (int[]){12, 14, 16}[rnd() % 3]; fill(D, 1024);
        o_aria_aesni_avx_encrypt_16way(A, B, D); n_aria_aesni_avx_encrypt_16way(A, C, D);
        CHECK("aria_aesni_avx_encrypt_16way", B, C, 256);
        o_aria_aesni_avx2_encrypt_32way(A, B, D); n_aria_aesni_avx2_encrypt_32way(A, C, D);
        CHECK("aria_aesni_avx2_encrypt_32way", B, C, 512);
        o_aria_gfni_avx512_encrypt_64way(A, B, D); n_aria_gfni_avx512_encrypt_64way(A, C, D);
        CHECK("aria_gfni_avx512_encrypt_64way", B, C, 1024);
        DONE(aria_aesni_avx_encrypt_16way) DONE(aria_aesni_avx2_encrypt_32way) DONE(aria_gfni_avx512_encrypt_64way)
    }
    for (t = 0; t < TRIALS; t++) {
        int xor = rnd() & 1;
        fill(A, 528); fill(D, 128); fill(B, 128); memcpy(C, B, 128);
        o___serpent_enc_blk_8way(A, B, D, xor); n___serpent_enc_blk_8way(A, C, D, xor);
        CHECK("__serpent_enc_blk_8way", B, C, 128);
        o_serpent_dec_blk_8way(A, B, D); n_serpent_dec_blk_8way(A, C, D);
        CHECK("serpent_dec_blk_8way", B, C, 128);
        DONE(__serpent_enc_blk_8way) DONE(serpent_dec_blk_8way)
    }
    for (t = 0; t < TRIALS; t++) {
        unsigned len = rnd() % 300, so = rnd() % 16, dofs = rnd() % 16;
        fill(D, 512); fill(B, 512); memcpy(C, B, 512);
        unsigned long r1 = o_copy_mc_fragile(B + dofs, D + so, len), r2 = n_copy_mc_fragile(C + dofs, D + so, len);
        CHECK("copy_mc_fragile", B, C, 512); CHECK("copy_mc_fragile_ret", &r1, &r2, sizeof r1);
        DONE(copy_mc_fragile) DONE(copy_mc_fragile_ret)
    }
    for (t = 0; t < TRIALS; t++) {
        size_t n = rnd() % 300; unsigned ofs = rnd() % 16; int c = rnd();
        fill(B, 512); memcpy(C, B, 512);
        void *r1 = o___memset(B + ofs, c, n), *r2 = n___memset(C + ofs, c, n);
        long d1 = (u8 *)r1 - B, d2 = (u8 *)r2 - C;
        CHECK("__memset", B, C, 512); CHECK("__memset_ret", &d1, &d2, sizeof d1);
        DONE(__memset) DONE(__memset_ret)
    }
    for (t = 0; t < TRIALS; t++) {
        int len = rnd() % 300; unsigned ofs = rnd() % 8;
        fill(D, 512);
        uint16_t r1 = o_ip_compute_csum(D + ofs, len), r2 = n_ip_compute_csum(D + ofs, len);
        CHECK("ip_compute_csum", &r1, &r2, 2); DONE(ip_compute_csum)
    }

    printf("%d comparisons, %d failures\n", tests, fails);
    return fails != 0;
}

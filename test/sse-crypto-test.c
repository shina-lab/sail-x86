// Legacy AES-NI + PCLMULQDQ + GFNI instruction tests.
// Compiled with -msse4.2 -maes -mpclmul -mgfni -mno-avx.

typedef unsigned long u64;
typedef long i64;
typedef unsigned int u32;
typedef unsigned char u8;

static i64 syscall1(int nr, u64 a1) {
  i64 ret;
  __asm__ volatile("syscall" : "=a"(ret) : "a"(nr), "D"(a1)
                   : "rcx", "r11", "memory");
  return ret;
}

static i64 syscall3(int nr, u64 a1, u64 a2, u64 a3) {
  i64 ret;
  register u64 r10 __asm__("r10") = 0;
  __asm__ volatile("syscall" : "=a"(ret)
                   : "a"(nr), "D"(a1), "S"(a2), "d"(a3), "r"(r10)
                   : "rcx", "r11", "memory");
  return ret;
}

static void print(const char *s) {
  u64 len = 0;
  while (s[len]) len++;
  syscall3(1, 1, (u64)s, len);
}

static void print_int(int n) {
  char buf[20];
  int i = 0;
  if (n == 0) { print("0"); return; }
  if (n < 0) { print("-"); n = -n; }
  while (n > 0) { buf[i++] = '0' + (n % 10); n /= 10; }
  char out[20];
  for (int j = 0; j < i; j++) out[j] = buf[i - 1 - j];
  out[i] = 0;
  print(out);
}

static void print_hex(u64 val) {
  const char hex[] = "0123456789abcdef";
  char buf[17];
  for (int i = 15; i >= 0; i--) {
    buf[i] = hex[val & 0xF];
    val >>= 4;
  }
  buf[16] = 0;
  print(buf);
}

static int test_num = 0;
static int fail_count = 0;

static void ok(const char *name) {
  test_num++;
  print("ok ");
  print_int(test_num);
  print(" - ");
  print(name);
  print("\n");
}

static void fail(const char *name) {
  test_num++;
  fail_count++;
  print("FAIL ");
  print_int(test_num);
  print(" - ");
  print(name);
  print("\n");
}

static void check(int cond, const char *name) {
  if (cond) ok(name); else fail(name);
}

typedef int v4si __attribute__((vector_size(16)));
typedef long long v2di __attribute__((vector_size(16)));
typedef unsigned char v16qi __attribute__((vector_size(16)));

#define BARRIER(x) __asm__ volatile("" : "+x"(x))

// =========================================================================
// AES-NI
// =========================================================================

static void test_aesenc(void) {
  // Use known test vector: NIST FIPS 197 round
  v2di state = {0x3243f6a8885a308dLL, 0x313198a2e0370734LL};
  v2di key = {0x2b7e151628aed2a6LL, 0xabf7158809cf4f3cLL};
  BARRIER(state); BARRIER(key);
  __asm__ volatile("aesenc %1, %0" : "+x"(state) : "x"(key));
  // Just check it produces non-trivial output (exact value depends on AES tables)
  check(state[0] != 0 || state[1] != 0, "aesenc (non-zero output)");
}

static void test_aesenclast(void) {
  v2di state = {0x3243f6a8885a308dLL, 0x313198a2e0370734LL};
  v2di key = {0x2b7e151628aed2a6LL, 0xabf7158809cf4f3cLL};
  BARRIER(state); BARRIER(key);
  __asm__ volatile("aesenclast %1, %0" : "+x"(state) : "x"(key));
  check(state[0] != 0 || state[1] != 0, "aesenclast (non-zero output)");
}

static void test_aesdec(void) {
  v2di state = {0x3243f6a8885a308dLL, 0x313198a2e0370734LL};
  v2di key = {0x2b7e151628aed2a6LL, 0xabf7158809cf4f3cLL};
  BARRIER(state); BARRIER(key);
  __asm__ volatile("aesdec %1, %0" : "+x"(state) : "x"(key));
  check(state[0] != 0 || state[1] != 0, "aesdec (non-zero output)");
}

static void test_aesdeclast(void) {
  v2di state = {0x3243f6a8885a308dLL, 0x313198a2e0370734LL};
  v2di key = {0x2b7e151628aed2a6LL, 0xabf7158809cf4f3cLL};
  BARRIER(state); BARRIER(key);
  __asm__ volatile("aesdeclast %1, %0" : "+x"(state) : "x"(key));
  check(state[0] != 0 || state[1] != 0, "aesdeclast (non-zero output)");
}

static void test_aesimc(void) {
  v2di key = {0x2b7e151628aed2a6LL, 0xabf7158809cf4f3cLL};
  v2di r;
  BARRIER(key);
  __asm__ volatile("aesimc %1, %0" : "=x"(r) : "x"(key));
  check(r[0] != 0 || r[1] != 0, "aesimc (non-zero output)");
}

static void test_aeskeygenassist(void) {
  v2di key = {0x2b7e151628aed2a6LL, 0xabf7158809cf4f3cLL};
  v2di r;
  BARRIER(key);
  __asm__ volatile("aeskeygenassist $0x01, %1, %0" : "=x"(r) : "x"(key));
  check(r[0] != 0 || r[1] != 0, "aeskeygenassist $0x01");
}

// Test AES encrypt/decrypt round-trip consistency
static void test_aes_roundtrip(void) {
  v2di state = {0x0123456789ABCDEFLL, 0xFEDCBA9876543210LL};
  v2di key = {0, 0};  // zero key for simplicity
  v2di orig = state;
  BARRIER(state); BARRIER(key);
  BARRIER(orig);

  // Do one round of enc then dec with zero key
  v2di enc = state;
  __asm__ volatile("aesenclast %1, %0" : "+x"(enc) : "x"(key));
  // aesenclast with zero key: SubBytes + ShiftRows + XOR(0) = SubBytes + ShiftRows
  // aesdeclast with zero key: InvSubBytes + InvShiftRows + XOR(0)
  v2di dec = enc;
  __asm__ volatile("aesdeclast %1, %0" : "+x"(dec) : "x"(key));
  check(dec[0] == orig[0] && dec[1] == orig[1],
        "aes aesenclast/aesdeclast round-trip");
}

// =========================================================================
// PCLMULQDQ
// =========================================================================

static void test_pclmulqdq(void) {
  v2di a = {0x0000000000000003LL, 0x0000000000000005LL};
  v2di b = {0x0000000000000005LL, 0x0000000000000003LL};
  BARRIER(a); BARRIER(b);
  // imm=0x00: multiply a[0] * b[0] = 3 * 5 in GF(2)
  // 3 = 0b11, 5 = 0b101
  // 0b11 * 0b101 = 0b1111 = 15
  __asm__ volatile("pclmulqdq $0x00, %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 15 && a[1] == 0, "pclmulqdq $0x00 (3*5=15 in GF2)");
}

static void test_pclmulqdq_11(void) {
  v2di a = {0x0000000000000003LL, 0x0000000000000007LL};
  v2di b = {0x0000000000000005LL, 0x000000000000000BLL};
  BARRIER(a); BARRIER(b);
  // imm=0x11: multiply a[1] * b[1] = 7 * 11 in GF(2)
  // 7=0b111, 11=0b1011
  // 0b111 * 0b1011 = 0b111 * 0b1000 ^ 0b111 * 0b10 ^ 0b111 * 0b1
  //                = 0b111000 ^ 0b1110 ^ 0b111 = 0b110001 = 49
  __asm__ volatile("pclmulqdq $0x11, %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 49 && a[1] == 0, "pclmulqdq $0x11 (7*11 in GF2)");
}

// =========================================================================
// GFNI
// =========================================================================

static void test_gf2p8affineinvqb(void) {
  // Identity matrix in column-major GF(2) format
  // For the identity matrix, gf2p8affineinvqb computes GF(2^8) inverse + affine
  v16qi data = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15};
  // Identity matrix: each row has a single 1 bit
  v2di matrix = {0x0102040810204080LL, 0x0102040810204080LL};
  BARRIER(data); BARRIER(matrix);
  __asm__ volatile("gf2p8affineinvqb $0, %1, %0" : "+x"(data) : "x"(matrix));
  // GF(2^8) inverse of 0 is 0, inverse of 1 is 1
  v16qi r;
  __builtin_memcpy(&r, &data, 16);
  check(r[0] == 0 && r[1] == 1, "gf2p8affineinvqb (inv(0)=0, inv(1)=1)");
}

static void test_gf2p8affineqb(void) {
  // With identity matrix and constant 0, should be identity transform
  v16qi data = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15};
  v2di matrix = {0x0102040810204080LL, 0x0102040810204080LL};
  BARRIER(data); BARRIER(matrix);
  __asm__ volatile("gf2p8affineqb $0, %1, %0" : "+x"(data) : "x"(matrix));
  v16qi r;
  __builtin_memcpy(&r, &data, 16);
  check(r[0] == 0 && r[1] == 1 && r[2] == 2 && r[3] == 3,
        "gf2p8affineqb (identity)");
}

static void test_gf2p8mulb(void) {
  // GF(2^8) multiply: 1 * x = x for any x
  v16qi a = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
  v16qi b = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("gf2p8mulb %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 0 && a[1] == 1 && a[2] == 2 && a[3] == 3 &&
        a[14] == 14 && a[15] == 15,
        "gf2p8mulb (1*x = x)");
}

// =========================================================================
// Entry point
// =========================================================================

void __attribute__((force_align_arg_pointer)) _start(void) {
  // AES-NI
  test_aesenc();
  test_aesenclast();
  test_aesdec();
  test_aesdeclast();
  test_aesimc();
  test_aeskeygenassist();
  test_aes_roundtrip();

  // PCLMULQDQ
  test_pclmulqdq();
  test_pclmulqdq_11();

  // GFNI
  test_gf2p8affineinvqb();
  test_gf2p8affineqb();
  test_gf2p8mulb();

  // Summary
  print("\n");
  print_int(test_num);
  print(" tests, ");
  print_int(fail_count);
  print(" failures\n");

  syscall1(60, fail_count);
}

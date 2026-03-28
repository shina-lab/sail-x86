// Legacy SSE1/SSE2 floating-point instruction tests.
// Compiled with -msse4.2 -mno-avx to force legacy (non-VEX) encoding.
// 2-operand destructive form: dst is both input and output.

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

static int f32_eq(float a, float b) {
  union { float f; u32 u; } ua, ub;
  ua.f = a; ub.f = b;
  return ua.u == ub.u;
}

static int f64_eq(double a, double b) {
  union { double f; u64 u; } ua, ub;
  ua.f = a; ub.f = b;
  return ua.u == ub.u;
}

typedef float v4sf __attribute__((vector_size(16)));
typedef double v2df __attribute__((vector_size(16)));
typedef int v4si __attribute__((vector_size(16)));
typedef long long v2di __attribute__((vector_size(16)));

#define BARRIER(x) __asm__ volatile("" : "+x"(x))

// =========================================================================
// SSE1 packed float
// =========================================================================

static void test_addps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {5.0f, 6.0f, 7.0f, 8.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("addps %1, %0" : "+x"(a) : "x"(b));
  check(f32_eq(a[0], 6.0f) && f32_eq(a[1], 8.0f) &&
        f32_eq(a[2], 10.0f) && f32_eq(a[3], 12.0f),
        "addps");
}

static void test_subps(void) {
  v4sf a = {10.0f, 20.0f, 30.0f, 40.0f};
  v4sf b = {1.0f, 2.0f, 3.0f, 4.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("subps %1, %0" : "+x"(a) : "x"(b));
  check(f32_eq(a[0], 9.0f) && f32_eq(a[1], 18.0f) &&
        f32_eq(a[2], 27.0f) && f32_eq(a[3], 36.0f),
        "subps");
}

static void test_mulps(void) {
  v4sf a = {2.0f, 3.0f, 4.0f, 5.0f};
  v4sf b = {10.0f, 10.0f, 10.0f, 10.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("mulps %1, %0" : "+x"(a) : "x"(b));
  check(f32_eq(a[0], 20.0f) && f32_eq(a[1], 30.0f) &&
        f32_eq(a[2], 40.0f) && f32_eq(a[3], 50.0f),
        "mulps");
}

static void test_divps(void) {
  v4sf a = {20.0f, 30.0f, 40.0f, 50.0f};
  v4sf b = {10.0f, 10.0f, 10.0f, 10.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("divps %1, %0" : "+x"(a) : "x"(b));
  check(f32_eq(a[0], 2.0f) && f32_eq(a[1], 3.0f) &&
        f32_eq(a[2], 4.0f) && f32_eq(a[3], 5.0f),
        "divps");
}

static void test_minps(void) {
  v4sf a = {1.0f, 20.0f, 3.0f, 40.0f};
  v4sf b = {10.0f, 2.0f, 30.0f, 4.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("minps %1, %0" : "+x"(a) : "x"(b));
  check(f32_eq(a[0], 1.0f) && f32_eq(a[1], 2.0f) &&
        f32_eq(a[2], 3.0f) && f32_eq(a[3], 4.0f),
        "minps");
}

static void test_maxps(void) {
  v4sf a = {1.0f, 20.0f, 3.0f, 40.0f};
  v4sf b = {10.0f, 2.0f, 30.0f, 4.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("maxps %1, %0" : "+x"(a) : "x"(b));
  check(f32_eq(a[0], 10.0f) && f32_eq(a[1], 20.0f) &&
        f32_eq(a[2], 30.0f) && f32_eq(a[3], 40.0f),
        "maxps");
}

static void test_sqrtps(void) {
  v4sf a = {4.0f, 9.0f, 16.0f, 25.0f};
  v4sf r;
  BARRIER(a);
  __asm__ volatile("sqrtps %1, %0" : "=x"(r) : "x"(a));
  check(f32_eq(r[0], 2.0f) && f32_eq(r[1], 3.0f) &&
        f32_eq(r[2], 4.0f) && f32_eq(r[3], 5.0f),
        "sqrtps");
}

static void test_rsqrtps(void) {
  v4sf a = {1.0f, 1.0f, 1.0f, 1.0f};
  v4sf r;
  BARRIER(a);
  __asm__ volatile("rsqrtps %1, %0" : "=x"(r) : "x"(a));
  // rsqrt(1.0) ≈ 1.0 (approximate)
  check(r[0] > 0.99f && r[0] < 1.01f &&
        r[1] > 0.99f && r[1] < 1.01f &&
        r[2] > 0.99f && r[2] < 1.01f &&
        r[3] > 0.99f && r[3] < 1.01f,
        "rsqrtps");
}

static void test_rcpps(void) {
  v4sf a = {1.0f, 2.0f, 4.0f, 8.0f};
  v4sf r;
  BARRIER(a);
  __asm__ volatile("rcpps %1, %0" : "=x"(r) : "x"(a));
  // rcp(x) ≈ 1/x (approximate)
  check(r[0] > 0.99f && r[0] < 1.01f &&
        r[1] > 0.49f && r[1] < 0.51f &&
        r[2] > 0.24f && r[2] < 0.26f &&
        r[3] > 0.12f && r[3] < 0.13f,
        "rcpps");
}

static void test_andps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  BARRIER(a);
  __asm__ volatile("andps %1, %0" : "+x"(a) : "x"(a));
  check(f32_eq(a[0], 1.0f) && f32_eq(a[1], 2.0f) &&
        f32_eq(a[2], 3.0f) && f32_eq(a[3], 4.0f),
        "andps (self = identity)");
}

static void test_andnps(void) {
  v4si mask = {(int)0xFFFFFFFF, 0, (int)0xFFFFFFFF, 0};
  v4sf val = {1.0f, 2.0f, 3.0f, 4.0f};
  BARRIER(mask); BARRIER(val);
  // andnps: ~mask & val
  __asm__ volatile("andnps %1, %0" : "+x"(mask) : "x"(val));
  v4sf r;
  __builtin_memcpy(&r, &mask, 16);
  check(f32_eq(r[0], 0.0f) && f32_eq(r[1], 2.0f) &&
        f32_eq(r[2], 0.0f) && f32_eq(r[3], 4.0f),
        "andnps");
}

static void test_orps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf z = {0.0f, 0.0f, 0.0f, 0.0f};
  BARRIER(a); BARRIER(z);
  __asm__ volatile("orps %1, %0" : "+x"(a) : "x"(z));
  check(f32_eq(a[0], 1.0f) && f32_eq(a[1], 2.0f) &&
        f32_eq(a[2], 3.0f) && f32_eq(a[3], 4.0f),
        "orps (with zero = identity)");
}

static void test_xorps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  BARRIER(a);
  __asm__ volatile("xorps %1, %0" : "+x"(a) : "x"(a));
  check(f32_eq(a[0], 0.0f) && f32_eq(a[1], 0.0f) &&
        f32_eq(a[2], 0.0f) && f32_eq(a[3], 0.0f),
        "xorps (self = zero)");
}

static void test_cmpps_eq(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {1.0f, 9.0f, 3.0f, 9.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("cmpeqps %1, %0" : "+x"(a) : "x"(b));
  v4si r;
  __builtin_memcpy(&r, &a, 16);
  check(r[0] == (int)0xFFFFFFFF && r[1] == 0 &&
        r[2] == (int)0xFFFFFFFF && r[3] == 0,
        "cmpeqps");
}

static void test_cmpps_lt(void) {
  v4sf a = {1.0f, 5.0f, 3.0f, 7.0f};
  v4sf b = {2.0f, 4.0f, 4.0f, 6.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("cmpltps %1, %0" : "+x"(a) : "x"(b));
  v4si r;
  __builtin_memcpy(&r, &a, 16);
  check(r[0] == (int)0xFFFFFFFF && r[1] == 0 &&
        r[2] == (int)0xFFFFFFFF && r[3] == 0,
        "cmpltps");
}

static void test_cmpps_le(void) {
  v4sf a = {1.0f, 5.0f, 3.0f, 3.0f};
  v4sf b = {1.0f, 4.0f, 4.0f, 3.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("cmpleps %1, %0" : "+x"(a) : "x"(b));
  v4si r;
  __builtin_memcpy(&r, &a, 16);
  check(r[0] == (int)0xFFFFFFFF && r[1] == 0 &&
        r[2] == (int)0xFFFFFFFF && r[3] == (int)0xFFFFFFFF,
        "cmpleps");
}

static void test_cmpps_neq(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {1.0f, 9.0f, 3.0f, 9.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("cmpneqps %1, %0" : "+x"(a) : "x"(b));
  v4si r;
  __builtin_memcpy(&r, &a, 16);
  check(r[0] == 0 && r[1] == (int)0xFFFFFFFF &&
        r[2] == 0 && r[3] == (int)0xFFFFFFFF,
        "cmpneqps");
}

static void test_cmpps_nlt(void) {
  v4sf a = {1.0f, 5.0f, 3.0f, 7.0f};
  v4sf b = {2.0f, 4.0f, 3.0f, 6.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("cmpnltps %1, %0" : "+x"(a) : "x"(b));
  v4si r;
  __builtin_memcpy(&r, &a, 16);
  // NLT = !(a < b) = a >= b
  check(r[0] == 0 && r[1] == (int)0xFFFFFFFF &&
        r[2] == (int)0xFFFFFFFF && r[3] == (int)0xFFFFFFFF,
        "cmpnltps");
}

static void test_cmpps_nle(void) {
  v4sf a = {1.0f, 5.0f, 3.0f, 7.0f};
  v4sf b = {2.0f, 4.0f, 3.0f, 6.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("cmpnleps %1, %0" : "+x"(a) : "x"(b));
  v4si r;
  __builtin_memcpy(&r, &a, 16);
  // NLE = !(a <= b) = a > b
  check(r[0] == 0 && r[1] == (int)0xFFFFFFFF &&
        r[2] == 0 && r[3] == (int)0xFFFFFFFF,
        "cmpnleps");
}

static void test_cmpps_ord(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {5.0f, 6.0f, 7.0f, 8.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("cmpordps %1, %0" : "+x"(a) : "x"(b));
  v4si r;
  __builtin_memcpy(&r, &a, 16);
  // Both operands are ordered (not NaN)
  check(r[0] == (int)0xFFFFFFFF && r[1] == (int)0xFFFFFFFF &&
        r[2] == (int)0xFFFFFFFF && r[3] == (int)0xFFFFFFFF,
        "cmpordps");
}

static void test_movaps(void) {
  v4sf a = {11.0f, 22.0f, 33.0f, 44.0f};
  v4sf r;
  BARRIER(a);
  __asm__ volatile("movaps %1, %0" : "=x"(r) : "x"(a));
  check(f32_eq(r[0], 11.0f) && f32_eq(r[1], 22.0f) &&
        f32_eq(r[2], 33.0f) && f32_eq(r[3], 44.0f),
        "movaps");
}

static void test_movups(void) {
  float buf[4] __attribute__((aligned(16))) = {1.5f, 2.5f, 3.5f, 4.5f};
  v4sf r;
  __asm__ volatile("movups %1, %0" : "=x"(r) : "m"(buf));
  check(f32_eq(r[0], 1.5f) && f32_eq(r[1], 2.5f) &&
        f32_eq(r[2], 3.5f) && f32_eq(r[3], 4.5f),
        "movups load");

  float out[4] __attribute__((aligned(16)));
  __asm__ volatile("movups %1, %0" : "=m"(out) : "x"(r));
  check(f32_eq(out[0], 1.5f) && f32_eq(out[1], 2.5f) &&
        f32_eq(out[2], 3.5f) && f32_eq(out[3], 4.5f),
        "movups store");
}

static void test_movlps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  float mem[2] __attribute__((aligned(8))) = {10.0f, 20.0f};
  BARRIER(a);
  __asm__ volatile("movlps %1, %0" : "+x"(a) : "m"(mem));
  check(f32_eq(a[0], 10.0f) && f32_eq(a[1], 20.0f) &&
        f32_eq(a[2], 3.0f) && f32_eq(a[3], 4.0f),
        "movlps load");
}

static void test_movhps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  float mem[2] __attribute__((aligned(8))) = {10.0f, 20.0f};
  BARRIER(a);
  __asm__ volatile("movhps %1, %0" : "+x"(a) : "m"(mem));
  check(f32_eq(a[0], 1.0f) && f32_eq(a[1], 2.0f) &&
        f32_eq(a[2], 10.0f) && f32_eq(a[3], 20.0f),
        "movhps load");
}

static void test_movlps_store(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  float mem[2] __attribute__((aligned(8)));
  BARRIER(a);
  __asm__ volatile("movlps %1, %0" : "=m"(mem) : "x"(a));
  check(f32_eq(mem[0], 1.0f) && f32_eq(mem[1], 2.0f),
        "movlps store");
}

static void test_movhps_store(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  float mem[2] __attribute__((aligned(8)));
  BARRIER(a);
  __asm__ volatile("movhps %1, %0" : "=m"(mem) : "x"(a));
  check(f32_eq(mem[0], 3.0f) && f32_eq(mem[1], 4.0f),
        "movhps store");
}

static void test_movlhps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {10.0f, 20.0f, 30.0f, 40.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("movlhps %1, %0" : "+x"(a) : "x"(b));
  check(f32_eq(a[0], 1.0f) && f32_eq(a[1], 2.0f) &&
        f32_eq(a[2], 10.0f) && f32_eq(a[3], 20.0f),
        "movlhps");
}

static void test_movhlps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {10.0f, 20.0f, 30.0f, 40.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("movhlps %1, %0" : "+x"(a) : "x"(b));
  check(f32_eq(a[0], 30.0f) && f32_eq(a[1], 40.0f) &&
        f32_eq(a[2], 3.0f) && f32_eq(a[3], 4.0f),
        "movhlps");
}

static void test_unpcklps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {10.0f, 20.0f, 30.0f, 40.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("unpcklps %1, %0" : "+x"(a) : "x"(b));
  check(f32_eq(a[0], 1.0f) && f32_eq(a[1], 10.0f) &&
        f32_eq(a[2], 2.0f) && f32_eq(a[3], 20.0f),
        "unpcklps");
}

static void test_unpckhps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {10.0f, 20.0f, 30.0f, 40.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("unpckhps %1, %0" : "+x"(a) : "x"(b));
  check(f32_eq(a[0], 3.0f) && f32_eq(a[1], 30.0f) &&
        f32_eq(a[2], 4.0f) && f32_eq(a[3], 40.0f),
        "unpckhps");
}

static void test_shufps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {10.0f, 20.0f, 30.0f, 40.0f};
  BARRIER(a); BARRIER(b);
  // imm8 = 0x1B = 0b00_01_10_11 -> a[3], a[2], b[1], b[0]
  __asm__ volatile("shufps $0x1B, %1, %0" : "+x"(a) : "x"(b));
  check(f32_eq(a[0], 4.0f) && f32_eq(a[1], 3.0f) &&
        f32_eq(a[2], 20.0f) && f32_eq(a[3], 10.0f),
        "shufps $0x1B");
}

static void test_shufps_ident(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  BARRIER(a);
  // imm8 = 0xE4 = 0b11_10_01_00 -> identity when src=dst
  __asm__ volatile("shufps $0xE4, %1, %0" : "+x"(a) : "x"(a));
  check(f32_eq(a[0], 1.0f) && f32_eq(a[1], 2.0f) &&
        f32_eq(a[2], 3.0f) && f32_eq(a[3], 4.0f),
        "shufps $0xE4 self");
}

static void test_movmskps(void) {
  v4sf a = {-1.0f, 2.0f, -3.0f, 4.0f};
  int r;
  BARRIER(a);
  __asm__ volatile("movmskps %1, %0" : "=r"(r) : "x"(a));
  // Sign bits: [0]=1, [1]=0, [2]=1, [3]=0 -> 0b0101 = 5
  check(r == 5, "movmskps");
}

// =========================================================================
// SSE1 scalar float
// =========================================================================

static void test_addss(void) {
  v4sf a = {1.0f, 100.0f, 200.0f, 300.0f};
  v4sf b = {2.0f, 999.0f, 999.0f, 999.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("addss %1, %0" : "+x"(a) : "x"(b));
  // Scalar: a[0] = a[0]+b[0], upper lanes unchanged
  check(f32_eq(a[0], 3.0f) && f32_eq(a[1], 100.0f) &&
        f32_eq(a[2], 200.0f) && f32_eq(a[3], 300.0f),
        "addss");
}

static void test_subss(void) {
  v4sf a = {10.0f, 100.0f, 200.0f, 300.0f};
  v4sf b = {3.0f, 999.0f, 999.0f, 999.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("subss %1, %0" : "+x"(a) : "x"(b));
  check(f32_eq(a[0], 7.0f) && f32_eq(a[1], 100.0f) &&
        f32_eq(a[2], 200.0f) && f32_eq(a[3], 300.0f),
        "subss");
}

static void test_mulss(void) {
  v4sf a = {3.0f, 100.0f, 200.0f, 300.0f};
  v4sf b = {7.0f, 999.0f, 999.0f, 999.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("mulss %1, %0" : "+x"(a) : "x"(b));
  check(f32_eq(a[0], 21.0f) && f32_eq(a[1], 100.0f) &&
        f32_eq(a[2], 200.0f) && f32_eq(a[3], 300.0f),
        "mulss");
}

static void test_divss(void) {
  v4sf a = {20.0f, 100.0f, 200.0f, 300.0f};
  v4sf b = {4.0f, 999.0f, 999.0f, 999.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("divss %1, %0" : "+x"(a) : "x"(b));
  check(f32_eq(a[0], 5.0f) && f32_eq(a[1], 100.0f) &&
        f32_eq(a[2], 200.0f) && f32_eq(a[3], 300.0f),
        "divss");
}

static void test_minss(void) {
  v4sf a = {5.0f, 100.0f, 200.0f, 300.0f};
  v4sf b = {3.0f, 999.0f, 999.0f, 999.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("minss %1, %0" : "+x"(a) : "x"(b));
  check(f32_eq(a[0], 3.0f) && f32_eq(a[1], 100.0f) &&
        f32_eq(a[2], 200.0f) && f32_eq(a[3], 300.0f),
        "minss");
}

static void test_maxss(void) {
  v4sf a = {5.0f, 100.0f, 200.0f, 300.0f};
  v4sf b = {3.0f, 999.0f, 999.0f, 999.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("maxss %1, %0" : "+x"(a) : "x"(b));
  check(f32_eq(a[0], 5.0f) && f32_eq(a[1], 100.0f) &&
        f32_eq(a[2], 200.0f) && f32_eq(a[3], 300.0f),
        "maxss");
}

static void test_sqrtss(void) {
  v4sf a = {16.0f, 100.0f, 200.0f, 300.0f};
  BARRIER(a);
  __asm__ volatile("sqrtss %1, %0" : "+x"(a) : "x"(a));
  check(f32_eq(a[0], 4.0f) && f32_eq(a[1], 100.0f) &&
        f32_eq(a[2], 200.0f) && f32_eq(a[3], 300.0f),
        "sqrtss");
}

static void test_rsqrtss(void) {
  v4sf a = {1.0f, 100.0f, 200.0f, 300.0f};
  BARRIER(a);
  __asm__ volatile("rsqrtss %1, %0" : "+x"(a) : "x"(a));
  check(a[0] > 0.99f && a[0] < 1.01f && f32_eq(a[1], 100.0f) &&
        f32_eq(a[2], 200.0f) && f32_eq(a[3], 300.0f),
        "rsqrtss");
}

static void test_rcpss(void) {
  v4sf a = {2.0f, 100.0f, 200.0f, 300.0f};
  BARRIER(a);
  __asm__ volatile("rcpss %1, %0" : "+x"(a) : "x"(a));
  check(a[0] > 0.49f && a[0] < 0.51f && f32_eq(a[1], 100.0f) &&
        f32_eq(a[2], 200.0f) && f32_eq(a[3], 300.0f),
        "rcpss");
}

static void test_cmpss_eq(void) {
  v4sf a = {1.0f, 100.0f, 200.0f, 300.0f};
  v4sf b = {1.0f, 999.0f, 999.0f, 999.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("cmpeqss %1, %0" : "+x"(a) : "x"(b));
  v4si r;
  __builtin_memcpy(&r, &a, 16);
  check(r[0] == (int)0xFFFFFFFF && f32_eq(*(float*)&r[1], 100.0f),
        "cmpeqss");
}

static void test_cmpss_lt(void) {
  v4sf a = {1.0f, 100.0f, 200.0f, 300.0f};
  v4sf b = {2.0f, 999.0f, 999.0f, 999.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("cmpltss %1, %0" : "+x"(a) : "x"(b));
  v4si r;
  __builtin_memcpy(&r, &a, 16);
  check(r[0] == (int)0xFFFFFFFF && f32_eq(*(float*)&r[1], 100.0f),
        "cmpltss");
}

static void test_comiss(void) {
  v4sf a = {1.0f, 0, 0, 0};
  v4sf b = {2.0f, 0, 0, 0};
  BARRIER(a); BARRIER(b);
  int result;
  // comiss sets EFLAGS; use seta to get CF=0 && ZF=0 (a > b)
  __asm__ volatile("comiss %2, %1\n\t"
                   "seta %b0\n\t"
                   "movzbl %b0, %0"
                   : "=r"(result) : "x"(a), "x"(b));
  check(result == 0, "comiss (1.0 < 2.0)");

  v4sf c = {3.0f, 0, 0, 0};
  BARRIER(c);
  __asm__ volatile("comiss %2, %1\n\t"
                   "seta %b0\n\t"
                   "movzbl %b0, %0"
                   : "=r"(result) : "x"(c), "x"(b));
  check(result == 1, "comiss (3.0 > 2.0)");
}

static void test_ucomiss(void) {
  v4sf a = {5.0f, 0, 0, 0};
  v4sf b = {5.0f, 0, 0, 0};
  BARRIER(a); BARRIER(b);
  int result;
  __asm__ volatile("ucomiss %2, %1\n\t"
                   "sete %b0\n\t"
                   "movzbl %b0, %0"
                   : "=r"(result) : "x"(a), "x"(b));
  check(result == 1, "ucomiss (5.0 == 5.0)");
}

static void test_movss(void) {
  float val __attribute__((aligned(4))) = 42.0f;
  v4sf r = {0};
  // movss from memory zero-extends upper lanes
  __asm__ volatile("movss %1, %0" : "=x"(r) : "m"(val));
  check(f32_eq(r[0], 42.0f) && f32_eq(r[1], 0.0f) &&
        f32_eq(r[2], 0.0f) && f32_eq(r[3], 0.0f),
        "movss load (zero-extend)");

  // movss store
  float out __attribute__((aligned(4)));
  v4sf src = {99.0f, 1.0f, 2.0f, 3.0f};
  BARRIER(src);
  __asm__ volatile("movss %1, %0" : "=m"(out) : "x"(src));
  check(f32_eq(out, 99.0f), "movss store");
}

// =========================================================================
// SSE2 packed double
// =========================================================================

static void test_addpd(void) {
  v2df a = {1.5, 2.5};
  v2df b = {3.5, 4.5};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("addpd %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 5.0) && f64_eq(a[1], 7.0), "addpd");
}

static void test_subpd(void) {
  v2df a = {10.0, 20.0};
  v2df b = {3.0, 7.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("subpd %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 7.0) && f64_eq(a[1], 13.0), "subpd");
}

static void test_mulpd(void) {
  v2df a = {3.0, 4.0};
  v2df b = {5.0, 6.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("mulpd %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 15.0) && f64_eq(a[1], 24.0), "mulpd");
}

static void test_divpd(void) {
  v2df a = {20.0, 30.0};
  v2df b = {4.0, 5.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("divpd %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 5.0) && f64_eq(a[1], 6.0), "divpd");
}

static void test_minpd(void) {
  v2df a = {1.0, 20.0};
  v2df b = {10.0, 2.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("minpd %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 1.0) && f64_eq(a[1], 2.0), "minpd");
}

static void test_maxpd(void) {
  v2df a = {1.0, 20.0};
  v2df b = {10.0, 2.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("maxpd %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 10.0) && f64_eq(a[1], 20.0), "maxpd");
}

static void test_sqrtpd(void) {
  v2df a = {4.0, 9.0};
  v2df r;
  BARRIER(a);
  __asm__ volatile("sqrtpd %1, %0" : "=x"(r) : "x"(a));
  check(f64_eq(r[0], 2.0) && f64_eq(r[1], 3.0), "sqrtpd");
}

static void test_andpd(void) {
  v2df a = {1.0, 2.0};
  BARRIER(a);
  __asm__ volatile("andpd %1, %0" : "+x"(a) : "x"(a));
  check(f64_eq(a[0], 1.0) && f64_eq(a[1], 2.0), "andpd (self = identity)");
}

static void test_andnpd(void) {
  v2di mask = {(long long)0xFFFFFFFFFFFFFFFFLL, 0};
  v2df val = {1.0, 2.0};
  BARRIER(mask); BARRIER(val);
  __asm__ volatile("andnpd %1, %0" : "+x"(mask) : "x"(val));
  v2df r;
  __builtin_memcpy(&r, &mask, 16);
  check(f64_eq(r[0], 0.0) && f64_eq(r[1], 2.0), "andnpd");
}

static void test_orpd(void) {
  v2df a = {1.0, 2.0};
  v2df z = {0.0, 0.0};
  BARRIER(a); BARRIER(z);
  __asm__ volatile("orpd %1, %0" : "+x"(a) : "x"(z));
  check(f64_eq(a[0], 1.0) && f64_eq(a[1], 2.0), "orpd (with zero = identity)");
}

static void test_xorpd(void) {
  v2df a = {1.0, 2.0};
  BARRIER(a);
  __asm__ volatile("xorpd %1, %0" : "+x"(a) : "x"(a));
  check(f64_eq(a[0], 0.0) && f64_eq(a[1], 0.0), "xorpd (self = zero)");
}

static void test_cmppd_eq(void) {
  v2df a = {1.0, 2.0};
  v2df b = {1.0, 9.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("cmpeqpd %1, %0" : "+x"(a) : "x"(b));
  v2di r;
  __builtin_memcpy(&r, &a, 16);
  check(r[0] == (long long)0xFFFFFFFFFFFFFFFFLL && r[1] == 0, "cmpeqpd");
}

static void test_cmppd_lt(void) {
  v2df a = {1.0, 5.0};
  v2df b = {2.0, 4.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("cmpltpd %1, %0" : "+x"(a) : "x"(b));
  v2di r;
  __builtin_memcpy(&r, &a, 16);
  check(r[0] == (long long)0xFFFFFFFFFFFFFFFFLL && r[1] == 0, "cmpltpd");
}

static void test_movapd(void) {
  v2df a = {11.0, 22.0};
  v2df r;
  BARRIER(a);
  __asm__ volatile("movapd %1, %0" : "=x"(r) : "x"(a));
  check(f64_eq(r[0], 11.0) && f64_eq(r[1], 22.0), "movapd");
}

static void test_movupd(void) {
  double buf[2] __attribute__((aligned(16))) = {1.5, 2.5};
  v2df r;
  __asm__ volatile("movupd %1, %0" : "=x"(r) : "m"(buf));
  check(f64_eq(r[0], 1.5) && f64_eq(r[1], 2.5), "movupd load");

  double out[2] __attribute__((aligned(16)));
  __asm__ volatile("movupd %1, %0" : "=m"(out) : "x"(r));
  check(f64_eq(out[0], 1.5) && f64_eq(out[1], 2.5), "movupd store");
}

static void test_unpcklpd(void) {
  v2df a = {1.0, 2.0};
  v2df b = {10.0, 20.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("unpcklpd %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 1.0) && f64_eq(a[1], 10.0), "unpcklpd");
}

static void test_unpckhpd(void) {
  v2df a = {1.0, 2.0};
  v2df b = {10.0, 20.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("unpckhpd %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 2.0) && f64_eq(a[1], 20.0), "unpckhpd");
}

static void test_shufpd(void) {
  v2df a = {1.0, 2.0};
  v2df b = {10.0, 20.0};
  BARRIER(a); BARRIER(b);
  // imm=1: a[1], b[0]
  __asm__ volatile("shufpd $1, %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 2.0) && f64_eq(a[1], 10.0), "shufpd $1");
}

static void test_movmskpd(void) {
  v2df a = {-1.0, 2.0};
  int r;
  BARRIER(a);
  __asm__ volatile("movmskpd %1, %0" : "=r"(r) : "x"(a));
  check(r == 1, "movmskpd");
}

static void test_movlpd(void) {
  v2df a = {1.0, 2.0};
  double mem __attribute__((aligned(8))) = 10.0;
  BARRIER(a);
  __asm__ volatile("movlpd %1, %0" : "+x"(a) : "m"(mem));
  check(f64_eq(a[0], 10.0) && f64_eq(a[1], 2.0), "movlpd load");
}

static void test_movlpd_store(void) {
  v2df a = {1.0, 2.0};
  double mem __attribute__((aligned(8)));
  BARRIER(a);
  __asm__ volatile("movlpd %1, %0" : "=m"(mem) : "x"(a));
  check(f64_eq(mem, 1.0), "movlpd store");
}

static void test_movhpd(void) {
  v2df a = {1.0, 2.0};
  double mem __attribute__((aligned(8))) = 10.0;
  BARRIER(a);
  __asm__ volatile("movhpd %1, %0" : "+x"(a) : "m"(mem));
  check(f64_eq(a[0], 1.0) && f64_eq(a[1], 10.0), "movhpd load");
}

static void test_movhpd_store(void) {
  v2df a = {1.0, 2.0};
  double mem __attribute__((aligned(8)));
  BARRIER(a);
  __asm__ volatile("movhpd %1, %0" : "=m"(mem) : "x"(a));
  check(f64_eq(mem, 2.0), "movhpd store");
}

// =========================================================================
// SSE2 scalar double
// =========================================================================

static void test_addsd(void) {
  v2df a = {1.5, 100.0};
  v2df b = {2.5, 999.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("addsd %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 4.0) && f64_eq(a[1], 100.0), "addsd");
}

static void test_subsd(void) {
  v2df a = {10.0, 100.0};
  v2df b = {3.0, 999.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("subsd %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 7.0) && f64_eq(a[1], 100.0), "subsd");
}

static void test_mulsd(void) {
  v2df a = {3.0, 100.0};
  v2df b = {7.0, 999.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("mulsd %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 21.0) && f64_eq(a[1], 100.0), "mulsd");
}

static void test_divsd(void) {
  v2df a = {20.0, 100.0};
  v2df b = {4.0, 999.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("divsd %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 5.0) && f64_eq(a[1], 100.0), "divsd");
}

static void test_minsd(void) {
  v2df a = {5.0, 100.0};
  v2df b = {3.0, 999.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("minsd %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 3.0) && f64_eq(a[1], 100.0), "minsd");
}

static void test_maxsd(void) {
  v2df a = {5.0, 100.0};
  v2df b = {3.0, 999.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("maxsd %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 5.0) && f64_eq(a[1], 100.0), "maxsd");
}

static void test_sqrtsd(void) {
  v2df a = {16.0, 100.0};
  BARRIER(a);
  __asm__ volatile("sqrtsd %1, %0" : "+x"(a) : "x"(a));
  check(f64_eq(a[0], 4.0) && f64_eq(a[1], 100.0), "sqrtsd");
}

static void test_cmpsd_eq(void) {
  v2df a = {1.0, 100.0};
  v2df b = {1.0, 999.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("cmpeqsd %1, %0" : "+x"(a) : "x"(b));
  v2di r;
  __builtin_memcpy(&r, &a, 16);
  check(r[0] == (long long)0xFFFFFFFFFFFFFFFFLL && f64_eq(*(double*)&r[1], 100.0),
        "cmpeqsd");
}

static void test_comisd(void) {
  v2df a = {1.0, 0};
  v2df b = {2.0, 0};
  BARRIER(a); BARRIER(b);
  int result;
  __asm__ volatile("comisd %2, %1\n\t"
                   "seta %b0\n\t"
                   "movzbl %b0, %0"
                   : "=r"(result) : "x"(a), "x"(b));
  check(result == 0, "comisd (1.0 < 2.0)");

  v2df c = {3.0, 0};
  BARRIER(c);
  __asm__ volatile("comisd %2, %1\n\t"
                   "seta %b0\n\t"
                   "movzbl %b0, %0"
                   : "=r"(result) : "x"(c), "x"(b));
  check(result == 1, "comisd (3.0 > 2.0)");
}

static void test_ucomisd(void) {
  v2df a = {5.0, 0};
  v2df b = {5.0, 0};
  BARRIER(a); BARRIER(b);
  int result;
  __asm__ volatile("ucomisd %2, %1\n\t"
                   "sete %b0\n\t"
                   "movzbl %b0, %0"
                   : "=r"(result) : "x"(a), "x"(b));
  check(result == 1, "ucomisd (5.0 == 5.0)");
}

static void test_movsd(void) {
  double val __attribute__((aligned(8))) = 42.0;
  v2df r;
  __asm__ volatile("movsd %1, %0" : "=x"(r) : "m"(val));
  check(f64_eq(r[0], 42.0) && f64_eq(r[1], 0.0), "movsd load (zero-extend)");

  double out __attribute__((aligned(8)));
  v2df src = {99.0, 1.0};
  BARRIER(src);
  __asm__ volatile("movsd %1, %0" : "=m"(out) : "x"(src));
  check(f64_eq(out, 99.0), "movsd store");
}

static void test_movdqa(void) {
  v4si a = {0x11111111, 0x22222222, 0x33333333, 0x44444444};
  v4si r;
  BARRIER(a);
  __asm__ volatile("movdqa %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 0x11111111 && r[1] == 0x22222222 &&
        r[2] == 0x33333333 && r[3] == 0x44444444,
        "movdqa");
}

static void test_movdqu(void) {
  int buf[4] __attribute__((aligned(16))) = {0xAA, 0xBB, 0xCC, 0xDD};
  v4si r;
  __asm__ volatile("movdqu %1, %0" : "=x"(r) : "m"(buf));
  check(r[0] == 0xAA && r[1] == 0xBB && r[2] == 0xCC && r[3] == 0xDD,
        "movdqu load");

  int out[4] __attribute__((aligned(16)));
  __asm__ volatile("movdqu %1, %0" : "=m"(out) : "x"(r));
  check(out[0] == 0xAA && out[1] == 0xBB && out[2] == 0xCC && out[3] == 0xDD,
        "movdqu store");
}

static void test_movntps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  float out[4] __attribute__((aligned(16)));
  BARRIER(a);
  __asm__ volatile("movntps %1, %0" : "=m"(out) : "x"(a));
  check(f32_eq(out[0], 1.0f) && f32_eq(out[1], 2.0f) &&
        f32_eq(out[2], 3.0f) && f32_eq(out[3], 4.0f),
        "movntps");
}

static void test_movntpd(void) {
  v2df a = {1.0, 2.0};
  double out[2] __attribute__((aligned(16)));
  BARRIER(a);
  __asm__ volatile("movntpd %1, %0" : "=m"(out) : "x"(a));
  check(f64_eq(out[0], 1.0) && f64_eq(out[1], 2.0), "movntpd");
}

static void test_movntdq(void) {
  v4si a = {1, 2, 3, 4};
  int out[4] __attribute__((aligned(16)));
  BARRIER(a);
  __asm__ volatile("movntdq %1, %0" : "=m"(out) : "x"(a));
  check(out[0] == 1 && out[1] == 2 && out[2] == 3 && out[3] == 4, "movntdq");
}

// =========================================================================
// SSE2 conversion (scalar)
// =========================================================================

static void test_cvtss2sd(void) {
  v4sf a = {3.0f, 1.0f, 2.0f, 4.0f};
  v2df r = {99.0, 100.0};
  BARRIER(a); BARRIER(r);
  __asm__ volatile("cvtss2sd %1, %0" : "+x"(r) : "x"(a));
  check(f64_eq(r[0], 3.0) && f64_eq(r[1], 100.0), "cvtss2sd");
}

static void test_cvtsd2ss(void) {
  v2df a = {3.0, 99.0};
  v4sf r = {99.0f, 100.0f, 200.0f, 300.0f};
  BARRIER(a); BARRIER(r);
  __asm__ volatile("cvtsd2ss %1, %0" : "+x"(r) : "x"(a));
  check(f32_eq(r[0], 3.0f) && f32_eq(r[1], 100.0f) &&
        f32_eq(r[2], 200.0f) && f32_eq(r[3], 300.0f),
        "cvtsd2ss");
}

static void test_cvtps2pd(void) {
  v4sf a = {3.0f, 7.0f, 0, 0};
  v2df r;
  BARRIER(a);
  __asm__ volatile("cvtps2pd %1, %0" : "=x"(r) : "x"(a));
  check(f64_eq(r[0], 3.0) && f64_eq(r[1], 7.0), "cvtps2pd");
}

static void test_cvtpd2ps(void) {
  v2df a = {3.0, 7.0};
  v4sf r;
  BARRIER(a);
  __asm__ volatile("cvtpd2ps %1, %0" : "=x"(r) : "x"(a));
  check(f32_eq(r[0], 3.0f) && f32_eq(r[1], 7.0f) &&
        f32_eq(r[2], 0.0f) && f32_eq(r[3], 0.0f),
        "cvtpd2ps");
}

static void test_cvtsi2ss(void) {
  v4sf r = {99.0f, 100.0f, 200.0f, 300.0f};
  int val = 42;
  BARRIER(r);
  __asm__ volatile("cvtsi2ss %1, %0" : "+x"(r) : "r"(val));
  check(f32_eq(r[0], 42.0f) && f32_eq(r[1], 100.0f) &&
        f32_eq(r[2], 200.0f) && f32_eq(r[3], 300.0f),
        "cvtsi2ss");
}

static void test_cvtsi2sd(void) {
  v2df r = {99.0, 100.0};
  int val = 42;
  BARRIER(r);
  __asm__ volatile("cvtsi2sd %1, %0" : "+x"(r) : "r"(val));
  check(f64_eq(r[0], 42.0) && f64_eq(r[1], 100.0), "cvtsi2sd");
}

static void test_cvtss2si(void) {
  v4sf a = {42.0f, 0, 0, 0};
  int r;
  BARRIER(a);
  __asm__ volatile("cvtss2si %1, %0" : "=r"(r) : "x"(a));
  check(r == 42, "cvtss2si");
}

static void test_cvtsd2si(void) {
  v2df a = {42.0, 0};
  int r;
  BARRIER(a);
  __asm__ volatile("cvtsd2si %1, %0" : "=r"(r) : "x"(a));
  check(r == 42, "cvtsd2si");
}

static void test_cvttss2si(void) {
  v4sf a = {42.7f, 0, 0, 0};
  int r;
  BARRIER(a);
  __asm__ volatile("cvttss2si %1, %0" : "=r"(r) : "x"(a));
  check(r == 42, "cvttss2si (truncate)");
}

static void test_cvttsd2si(void) {
  v2df a = {42.7, 0};
  int r;
  BARRIER(a);
  __asm__ volatile("cvttsd2si %1, %0" : "=r"(r) : "x"(a));
  check(r == 42, "cvttsd2si (truncate)");
}

static void test_cvtdq2ps(void) {
  v4si a = {1, 2, 3, 4};
  v4sf r;
  BARRIER(a);
  __asm__ volatile("cvtdq2ps %1, %0" : "=x"(r) : "x"(a));
  check(f32_eq(r[0], 1.0f) && f32_eq(r[1], 2.0f) &&
        f32_eq(r[2], 3.0f) && f32_eq(r[3], 4.0f),
        "cvtdq2ps");
}

static void test_cvtps2dq(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4si r;
  BARRIER(a);
  __asm__ volatile("cvtps2dq %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 1 && r[1] == 2 && r[2] == 3 && r[3] == 4, "cvtps2dq");
}

static void test_cvttps2dq(void) {
  v4sf a = {1.7f, 2.3f, 3.9f, 4.1f};
  v4si r;
  BARRIER(a);
  __asm__ volatile("cvttps2dq %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 1 && r[1] == 2 && r[2] == 3 && r[3] == 4, "cvttps2dq (truncate)");
}

static void test_cvtdq2pd(void) {
  v4si a = {7, 13, 0, 0};
  v2df r;
  BARRIER(a);
  __asm__ volatile("cvtdq2pd %1, %0" : "=x"(r) : "x"(a));
  check(f64_eq(r[0], 7.0) && f64_eq(r[1], 13.0), "cvtdq2pd");
}

static void test_cvtpd2dq(void) {
  v2df a = {7.0, 13.0};
  v4si r;
  BARRIER(a);
  __asm__ volatile("cvtpd2dq %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 7 && r[1] == 13, "cvtpd2dq");
}

static void test_cvttpd2dq(void) {
  v2df a = {7.8, 13.2};
  v4si r;
  BARRIER(a);
  __asm__ volatile("cvttpd2dq %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 7 && r[1] == 13, "cvttpd2dq (truncate)");
}

// =========================================================================
// Entry point
// =========================================================================

void __attribute__((force_align_arg_pointer)) _start(void) {
  // SSE1 packed float
  test_addps();
  test_subps();
  test_mulps();
  test_divps();
  test_minps();
  test_maxps();
  test_sqrtps();
  test_rsqrtps();
  test_rcpps();
  test_andps();
  test_andnps();
  test_orps();
  test_xorps();
  test_cmpps_eq();
  test_cmpps_lt();
  test_cmpps_le();
  test_cmpps_neq();
  test_cmpps_nlt();
  test_cmpps_nle();
  test_cmpps_ord();
  test_movaps();
  test_movups();
  test_movlps();
  test_movhps();
  test_movlps_store();
  test_movhps_store();
  test_movlhps();
  test_movhlps();
  test_unpcklps();
  test_unpckhps();
  test_shufps();
  test_shufps_ident();
  test_movmskps();

  // SSE1 scalar float
  test_addss();
  test_subss();
  test_mulss();
  test_divss();
  test_minss();
  test_maxss();
  test_sqrtss();
  test_rsqrtss();
  test_rcpss();
  test_cmpss_eq();
  test_cmpss_lt();
  test_comiss();
  test_ucomiss();
  test_movss();

  // SSE2 packed double
  test_addpd();
  test_subpd();
  test_mulpd();
  test_divpd();
  test_minpd();
  test_maxpd();
  test_sqrtpd();
  test_andpd();
  test_andnpd();
  test_orpd();
  test_xorpd();
  test_cmppd_eq();
  test_cmppd_lt();
  test_movapd();
  test_movupd();
  test_unpcklpd();
  test_unpckhpd();
  test_shufpd();
  test_movmskpd();
  test_movlpd();
  test_movlpd_store();
  test_movhpd();
  test_movhpd_store();

  // SSE2 scalar double
  test_addsd();
  test_subsd();
  test_mulsd();
  test_divsd();
  test_minsd();
  test_maxsd();
  test_sqrtsd();
  test_cmpsd_eq();
  test_comisd();
  test_ucomisd();
  test_movsd();

  // SSE2 data movement
  test_movdqa();
  test_movdqu();
  test_movntps();
  test_movntpd();
  test_movntdq();

  // SSE2 conversions
  test_cvtss2sd();
  test_cvtsd2ss();
  test_cvtps2pd();
  test_cvtpd2ps();
  test_cvtsi2ss();
  test_cvtsi2sd();
  test_cvtss2si();
  test_cvtsd2si();
  test_cvttss2si();
  test_cvttsd2si();
  test_cvtdq2ps();
  test_cvtps2dq();
  test_cvttps2dq();
  test_cvtdq2pd();
  test_cvtpd2dq();
  test_cvttpd2dq();

  // Summary
  print("\n");
  print_int(test_num);
  print(" tests, ");
  print_int(fail_count);
  print(" failures\n");

  syscall1(60, fail_count);
}

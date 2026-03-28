// Legacy SSE1 + SSE2 conversion instruction tests.
// Compiled with -msse4.2 -mno-avx to force legacy (non-VEX) encoding.
// This file tests conversions not already covered in sse-fp-test.c,
// focusing on edge cases and less common conversion paths.

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
// 64-bit integer conversions
// =========================================================================

static void test_cvtsi2ss_64(void) {
  v4sf r = {99.0f, 100.0f, 200.0f, 300.0f};
  long long val = 1000000000LL;
  BARRIER(r);
  __asm__ volatile("cvtsi2ssq %1, %0" : "+x"(r) : "r"(val));
  check(f32_eq(r[0], 1000000000.0f) && f32_eq(r[1], 100.0f),
        "cvtsi2ss (64-bit)");
}

static void test_cvtsi2sd_64(void) {
  v2df r = {99.0, 100.0};
  long long val = 1000000000LL;
  BARRIER(r);
  __asm__ volatile("cvtsi2sdq %1, %0" : "+x"(r) : "r"(val));
  check(f64_eq(r[0], 1000000000.0) && f64_eq(r[1], 100.0),
        "cvtsi2sd (64-bit)");
}

static void test_cvtss2si_64(void) {
  v4sf a = {42.0f, 0, 0, 0};
  long long r;
  BARRIER(a);
  __asm__ volatile("cvtss2siq %1, %0" : "=r"(r) : "x"(a));
  check(r == 42, "cvtss2si (64-bit)");
}

static void test_cvtsd2si_64(void) {
  v2df a = {42.0, 0};
  long long r;
  BARRIER(a);
  __asm__ volatile("cvtsd2siq %1, %0" : "=r"(r) : "x"(a));
  check(r == 42, "cvtsd2si (64-bit)");
}

static void test_cvttss2si_64(void) {
  v4sf a = {42.7f, 0, 0, 0};
  long long r;
  BARRIER(a);
  __asm__ volatile("cvttss2siq %1, %0" : "=r"(r) : "x"(a));
  check(r == 42, "cvttss2si (64-bit, truncate)");
}

static void test_cvttsd2si_64(void) {
  v2df a = {42.7, 0};
  long long r;
  BARRIER(a);
  __asm__ volatile("cvttsd2siq %1, %0" : "=r"(r) : "x"(a));
  check(r == 42, "cvttsd2si (64-bit, truncate)");
}

// =========================================================================
// Edge cases: negative values
// =========================================================================

static void test_cvtsi2ss_neg(void) {
  v4sf r = {0};
  int val = -42;
  __asm__ volatile("cvtsi2ss %1, %0" : "+x"(r) : "r"(val));
  check(f32_eq(r[0], -42.0f), "cvtsi2ss (negative)");
}

static void test_cvtsi2sd_neg(void) {
  v2df r = {0};
  int val = -42;
  __asm__ volatile("cvtsi2sd %1, %0" : "+x"(r) : "r"(val));
  check(f64_eq(r[0], -42.0), "cvtsi2sd (negative)");
}

static void test_cvtss2si_neg(void) {
  v4sf a = {-42.0f, 0, 0, 0};
  int r;
  BARRIER(a);
  __asm__ volatile("cvtss2si %1, %0" : "=r"(r) : "x"(a));
  check(r == -42, "cvtss2si (negative)");
}

static void test_cvtsd2si_neg(void) {
  v2df a = {-42.0, 0};
  int r;
  BARRIER(a);
  __asm__ volatile("cvtsd2si %1, %0" : "=r"(r) : "x"(a));
  check(r == -42, "cvtsd2si (negative)");
}

// =========================================================================
// Edge cases: rounding
// =========================================================================

static void test_cvtss2si_round(void) {
  // Default rounding is round-to-nearest-even
  v4sf a = {2.5f, 0, 0, 0};
  int r;
  BARRIER(a);
  __asm__ volatile("cvtss2si %1, %0" : "=r"(r) : "x"(a));
  // 2.5 rounds to 2 (round to even)
  check(r == 2, "cvtss2si (2.5 -> 2, round to even)");
}

static void test_cvtsd2si_round(void) {
  v2df a = {3.5, 0};
  int r;
  BARRIER(a);
  __asm__ volatile("cvtsd2si %1, %0" : "=r"(r) : "x"(a));
  // 3.5 rounds to 4 (round to even)
  check(r == 4, "cvtsd2si (3.5 -> 4, round to even)");
}

// =========================================================================
// Packed conversions: edge cases
// =========================================================================

static void test_cvtps2dq_neg(void) {
  v4sf a = {-1.0f, -2.0f, -3.0f, -4.0f};
  v4si r;
  BARRIER(a);
  __asm__ volatile("cvtps2dq %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == -1 && r[1] == -2 && r[2] == -3 && r[3] == -4,
        "cvtps2dq (negative)");
}

static void test_cvttps2dq_neg(void) {
  v4sf a = {-1.7f, -2.3f, -3.9f, -4.1f};
  v4si r;
  BARRIER(a);
  __asm__ volatile("cvttps2dq %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == -1 && r[1] == -2 && r[2] == -3 && r[3] == -4,
        "cvttps2dq (negative, truncate)");
}

static void test_cvtdq2ps_neg(void) {
  v4si a = {-1, -2, -3, -4};
  v4sf r;
  BARRIER(a);
  __asm__ volatile("cvtdq2ps %1, %0" : "=x"(r) : "x"(a));
  check(f32_eq(r[0], -1.0f) && f32_eq(r[1], -2.0f) &&
        f32_eq(r[2], -3.0f) && f32_eq(r[3], -4.0f),
        "cvtdq2ps (negative)");
}

static void test_cvtpd2dq_neg(void) {
  v2df a = {-7.0, -13.0};
  v4si r;
  BARRIER(a);
  __asm__ volatile("cvtpd2dq %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == -7 && r[1] == -13, "cvtpd2dq (negative)");
}

static void test_cvttpd2dq_neg(void) {
  v2df a = {-7.8, -13.2};
  v4si r;
  BARRIER(a);
  __asm__ volatile("cvttpd2dq %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == -7 && r[1] == -13, "cvttpd2dq (negative, truncate)");
}

// =========================================================================
// Memory operand conversions
// =========================================================================

static void test_cvtsi2ss_mem(void) {
  int val __attribute__((aligned(4))) = 99;
  v4sf r = {0};
  __asm__ volatile("cvtsi2ssl %1, %0" : "+x"(r) : "m"(val));
  check(f32_eq(r[0], 99.0f), "cvtsi2ss (mem)");
}

static void test_cvtsi2sd_mem(void) {
  int val __attribute__((aligned(4))) = 99;
  v2df r = {0};
  __asm__ volatile("cvtsi2sdl %1, %0" : "+x"(r) : "m"(val));
  check(f64_eq(r[0], 99.0), "cvtsi2sd (mem)");
}

// =========================================================================
// Cross-precision float conversions
// =========================================================================

static void test_cvtps2pd_neg(void) {
  v4sf a = {-3.0f, -7.0f, 0, 0};
  v2df r;
  BARRIER(a);
  __asm__ volatile("cvtps2pd %1, %0" : "=x"(r) : "x"(a));
  check(f64_eq(r[0], -3.0) && f64_eq(r[1], -7.0), "cvtps2pd (negative)");
}

static void test_cvtpd2ps_neg(void) {
  v2df a = {-3.0, -7.0};
  v4sf r;
  BARRIER(a);
  __asm__ volatile("cvtpd2ps %1, %0" : "=x"(r) : "x"(a));
  check(f32_eq(r[0], -3.0f) && f32_eq(r[1], -7.0f) &&
        f32_eq(r[2], 0.0f) && f32_eq(r[3], 0.0f),
        "cvtpd2ps (negative)");
}

static void test_cvtss2sd_neg(void) {
  v4sf a = {-3.0f, 1.0f, 2.0f, 4.0f};
  v2df r = {99.0, 100.0};
  BARRIER(a); BARRIER(r);
  __asm__ volatile("cvtss2sd %1, %0" : "+x"(r) : "x"(a));
  check(f64_eq(r[0], -3.0) && f64_eq(r[1], 100.0), "cvtss2sd (negative)");
}

static void test_cvtsd2ss_neg(void) {
  v2df a = {-3.0, 99.0};
  v4sf r = {99.0f, 100.0f, 200.0f, 300.0f};
  BARRIER(a); BARRIER(r);
  __asm__ volatile("cvtsd2ss %1, %0" : "+x"(r) : "x"(a));
  check(f32_eq(r[0], -3.0f) && f32_eq(r[1], 100.0f), "cvtsd2ss (negative)");
}

// =========================================================================
// MMX-era PI conversions
// =========================================================================

static void test_cvtpi2ps(void) {
  // CVTPI2PS: convert 2 packed dwords in MMX to 2 floats in low XMM
  v4sf r = {99.0f, 99.0f, 100.0f, 200.0f};
  int mm_data[2] __attribute__((aligned(8))) = {3, 7};
  BARRIER(r);
  __asm__ volatile(
    "movq %1, %%mm0\n\t"
    "cvtpi2ps %%mm0, %0\n\t"
    "emms"
    : "+x"(r) : "m"(mm_data) : "mm0");
  check(f32_eq(r[0], 3.0f) && f32_eq(r[1], 7.0f) &&
        f32_eq(r[2], 100.0f) && f32_eq(r[3], 200.0f),
        "cvtpi2ps");
}

static void test_cvttps2pi(void) {
  // CVTTPS2PI: truncate 2 floats in XMM to 2 dwords in MMX
  v4sf a = {3.7f, 7.2f, 0, 0};
  int mm_out[2] __attribute__((aligned(8)));
  BARRIER(a);
  __asm__ volatile(
    "cvttps2pi %1, %%mm0\n\t"
    "movq %%mm0, %0\n\t"
    "emms"
    : "=m"(mm_out) : "x"(a) : "mm0");
  check(mm_out[0] == 3 && mm_out[1] == 7, "cvttps2pi (truncate)");
}

static void test_cvtps2pi(void) {
  // CVTPS2PI: round 2 floats in XMM to 2 dwords in MMX
  v4sf a = {3.0f, 7.0f, 0, 0};
  int mm_out[2] __attribute__((aligned(8)));
  BARRIER(a);
  __asm__ volatile(
    "cvtps2pi %1, %%mm0\n\t"
    "movq %%mm0, %0\n\t"
    "emms"
    : "=m"(mm_out) : "x"(a) : "mm0");
  check(mm_out[0] == 3 && mm_out[1] == 7, "cvtps2pi");
}

static void test_cvtpi2pd(void) {
  // CVTPI2PD: convert 2 packed dwords in MMX to 2 doubles in XMM
  v2df r;
  int mm_data[2] __attribute__((aligned(8))) = {3, 7};
  __asm__ volatile(
    "movq %1, %%mm0\n\t"
    "cvtpi2pd %%mm0, %0\n\t"
    "emms"
    : "=x"(r) : "m"(mm_data) : "mm0");
  check(f64_eq(r[0], 3.0) && f64_eq(r[1], 7.0), "cvtpi2pd");
}

static void test_cvttpd2pi(void) {
  // CVTTPD2PI: truncate 2 doubles in XMM to 2 dwords in MMX
  v2df a = {3.7, 7.2};
  int mm_out[2] __attribute__((aligned(8)));
  BARRIER(a);
  __asm__ volatile(
    "cvttpd2pi %1, %%mm0\n\t"
    "movq %%mm0, %0\n\t"
    "emms"
    : "=m"(mm_out) : "x"(a) : "mm0");
  check(mm_out[0] == 3 && mm_out[1] == 7, "cvttpd2pi (truncate)");
}

static void test_cvtpd2pi(void) {
  // CVTPD2PI: round 2 doubles in XMM to 2 dwords in MMX
  v2df a = {3.0, 7.0};
  int mm_out[2] __attribute__((aligned(8)));
  BARRIER(a);
  __asm__ volatile(
    "cvtpd2pi %1, %%mm0\n\t"
    "movq %%mm0, %0\n\t"
    "emms"
    : "=m"(mm_out) : "x"(a) : "mm0");
  check(mm_out[0] == 3 && mm_out[1] == 7, "cvtpd2pi");
}

// =========================================================================
// Entry point
// =========================================================================

void __attribute__((force_align_arg_pointer)) _start(void) {
  // 64-bit integer conversions
  test_cvtsi2ss_64();
  test_cvtsi2sd_64();
  test_cvtss2si_64();
  test_cvtsd2si_64();
  test_cvttss2si_64();
  test_cvttsd2si_64();

  // Negative values
  test_cvtsi2ss_neg();
  test_cvtsi2sd_neg();
  test_cvtss2si_neg();
  test_cvtsd2si_neg();

  // Rounding
  test_cvtss2si_round();
  test_cvtsd2si_round();

  // Packed negative
  test_cvtps2dq_neg();
  test_cvttps2dq_neg();
  test_cvtdq2ps_neg();
  test_cvtpd2dq_neg();
  test_cvttpd2dq_neg();

  // Memory operands
  test_cvtsi2ss_mem();
  test_cvtsi2sd_mem();

  // Cross-precision negative
  test_cvtps2pd_neg();
  test_cvtpd2ps_neg();
  test_cvtss2sd_neg();
  test_cvtsd2ss_neg();

  // MMX PI conversions
  test_cvtpi2ps();
  test_cvttps2pi();
  test_cvtps2pi();
  test_cvtpi2pd();
  test_cvttpd2pi();
  test_cvtpd2pi();

  // Summary
  print("\n");
  print_int(test_num);
  print(" tests, ");
  print_int(fail_count);
  print(" failures\n");

  syscall1(60, fail_count);
}

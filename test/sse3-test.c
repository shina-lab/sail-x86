// Legacy SSE3 + SSSE3 instruction tests.
// Compiled with -msse4.2 -mno-avx to force legacy (non-VEX) encoding.

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
typedef short v8hi __attribute__((vector_size(16)));
typedef unsigned char v16qi __attribute__((vector_size(16)));

#define BARRIER(x) __asm__ volatile("" : "+x"(x))

// =========================================================================
// SSE3 floating-point
// =========================================================================

static void test_addsubps(void) {
  v4sf a = {10.0f, 20.0f, 30.0f, 40.0f};
  v4sf b = {1.0f, 2.0f, 3.0f, 4.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("addsubps %1, %0" : "+x"(a) : "x"(b));
  // Even lanes subtract, odd lanes add
  check(f32_eq(a[0], 9.0f) && f32_eq(a[1], 22.0f) &&
        f32_eq(a[2], 27.0f) && f32_eq(a[3], 44.0f),
        "addsubps");
}

static void test_addsubpd(void) {
  v2df a = {10.0, 20.0};
  v2df b = {1.0, 2.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("addsubpd %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 9.0) && f64_eq(a[1], 22.0), "addsubpd");
}

static void test_haddps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {10.0f, 20.0f, 30.0f, 40.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("haddps %1, %0" : "+x"(a) : "x"(b));
  // r[0]=a[0]+a[1]=3, r[1]=a[2]+a[3]=7, r[2]=b[0]+b[1]=30, r[3]=b[2]+b[3]=70
  check(f32_eq(a[0], 3.0f) && f32_eq(a[1], 7.0f) &&
        f32_eq(a[2], 30.0f) && f32_eq(a[3], 70.0f),
        "haddps");
}

static void test_hsubps(void) {
  v4sf a = {10.0f, 1.0f, 20.0f, 2.0f};
  v4sf b = {30.0f, 3.0f, 40.0f, 4.0f};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("hsubps %1, %0" : "+x"(a) : "x"(b));
  // r[0]=a[0]-a[1]=9, r[1]=a[2]-a[3]=18, r[2]=b[0]-b[1]=27, r[3]=b[2]-b[3]=36
  check(f32_eq(a[0], 9.0f) && f32_eq(a[1], 18.0f) &&
        f32_eq(a[2], 27.0f) && f32_eq(a[3], 36.0f),
        "hsubps");
}

static void test_haddpd(void) {
  v2df a = {1.0, 2.0};
  v2df b = {10.0, 20.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("haddpd %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 3.0) && f64_eq(a[1], 30.0), "haddpd");
}

static void test_hsubpd(void) {
  v2df a = {10.0, 1.0};
  v2df b = {20.0, 2.0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("hsubpd %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 9.0) && f64_eq(a[1], 18.0), "hsubpd");
}

static void test_movshdup(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf r;
  BARRIER(a);
  __asm__ volatile("movshdup %1, %0" : "=x"(r) : "x"(a));
  // Duplicate odd elements: r = {a[1], a[1], a[3], a[3]}
  check(f32_eq(r[0], 2.0f) && f32_eq(r[1], 2.0f) &&
        f32_eq(r[2], 4.0f) && f32_eq(r[3], 4.0f),
        "movshdup");
}

static void test_movsldup(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf r;
  BARRIER(a);
  __asm__ volatile("movsldup %1, %0" : "=x"(r) : "x"(a));
  // Duplicate even elements: r = {a[0], a[0], a[2], a[2]}
  check(f32_eq(r[0], 1.0f) && f32_eq(r[1], 1.0f) &&
        f32_eq(r[2], 3.0f) && f32_eq(r[3], 3.0f),
        "movsldup");
}

static void test_movddup(void) {
  v2df a = {42.0, 99.0};
  v2df r;
  BARRIER(a);
  __asm__ volatile("movddup %1, %0" : "=x"(r) : "x"(a));
  // Duplicate low element: r = {a[0], a[0]}
  check(f64_eq(r[0], 42.0) && f64_eq(r[1], 42.0), "movddup");
}

static void test_lddqu(void) {
  int buf[4] __attribute__((aligned(16))) = {1, 2, 3, 4};
  v4si r;
  __asm__ volatile("lddqu %1, %0" : "=x"(r) : "m"(buf));
  check(r[0] == 1 && r[1] == 2 && r[2] == 3 && r[3] == 4, "lddqu");
}

// =========================================================================
// SSSE3 integer
// =========================================================================

static void test_pshufb(void) {
  v16qi a = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15};
  v16qi idx = {15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0};
  BARRIER(a); BARRIER(idx);
  __asm__ volatile("pshufb %1, %0" : "+x"(a) : "x"(idx));
  check(a[0] == 15 && a[1] == 14 && a[2] == 13 && a[15] == 0,
        "pshufb (reverse)");
}

static void test_pshufb_zero(void) {
  v16qi a = {0xAA,0xBB,0xCC,0xDD, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  v16qi idx = {0x80, 0, 0x80, 1, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  BARRIER(a); BARRIER(idx);
  __asm__ volatile("pshufb %1, %0" : "+x"(a) : "x"(idx));
  // 0x80 -> 0, else index into a
  check(a[0] == 0 && a[1] == 0xAA && a[2] == 0 && a[3] == 0xBB,
        "pshufb (zero mask)");
}

static void test_phaddw(void) {
  v8hi a = {1, 2, 3, 4, 5, 6, 7, 8};
  v8hi b = {10, 20, 30, 40, 50, 60, 70, 80};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("phaddw %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 3 && a[1] == 7 && a[2] == 11 && a[3] == 15 &&
        a[4] == 30 && a[5] == 70 && a[6] == 110 && a[7] == 150,
        "phaddw");
}

static void test_phaddd(void) {
  v4si a = {1, 2, 3, 4};
  v4si b = {10, 20, 30, 40};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("phaddd %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 3 && a[1] == 7 && a[2] == 30 && a[3] == 70, "phaddd");
}

static void test_phsubw(void) {
  v8hi a = {10, 1, 20, 2, 30, 3, 40, 4};
  v8hi b = {50, 5, 60, 6, 70, 7, 80, 8};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("phsubw %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 9 && a[1] == 18 && a[2] == 27 && a[3] == 36 &&
        a[4] == 45 && a[5] == 54 && a[6] == 63 && a[7] == 72,
        "phsubw");
}

static void test_phsubd(void) {
  v4si a = {10, 1, 20, 2};
  v4si b = {30, 3, 40, 4};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("phsubd %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 9 && a[1] == 18 && a[2] == 27 && a[3] == 36, "phsubd");
}

static void test_phaddsw(void) {
  v8hi a = {32000, 1000, 0, 0, 0, 0, 0, 0};
  v8hi b = {0, 0, 0, 0, 0, 0, 0, 0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("phaddsw %1, %0" : "+x"(a) : "x"(b));
  // 32000 + 1000 = 33000 -> saturate to 32767
  check(a[0] == 32767, "phaddsw (saturate)");
}

static void test_phsubsw(void) {
  v8hi a = {-32000, 1000, 0, 0, 0, 0, 0, 0};
  v8hi b = {0, 0, 0, 0, 0, 0, 0, 0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("phsubsw %1, %0" : "+x"(a) : "x"(b));
  // -32000 - 1000 = -33000 -> saturate to -32768
  check(a[0] == -32768, "phsubsw (saturate)");
}

static void test_pmaddubsw(void) {
  v16qi a = {10, 20, 200, 200, 0,0,0,0,0,0,0,0,0,0,0,0};
  v16qi b = {5, 3, 200, 200, 0,0,0,0,0,0,0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pmaddubsw %1, %0" : "+x"(a) : "x"(b));
  v8hi r;
  __builtin_memcpy(&r, &a, 16);
  // r[0] = 10*5 + 20*3 = 110
  // r[1] = 200*(signed)200 + 200*(signed)200 = 200*(-56) + 200*(-56) = -22400
  check(r[0] == 110 && r[1] == -22400, "pmaddubsw");
}

static void test_pmulhrsw(void) {
  v8hi a = {0x4000, 0x4000, 0, 0, 0, 0, 0, 0};
  v8hi b = {0x4000, 2, 0, 0, 0, 0, 0, 0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pmulhrsw %1, %0" : "+x"(a) : "x"(b));
  // (0x4000 * 0x4000 >> 14 + 1) >> 1 = (0x10000000 >> 14 + 1) >> 1 = (0x4000 + 1) >> 1 = 0x2000
  check(a[0] == 0x2000, "pmulhrsw");
}

static void test_pabsb(void) {
  v16qi a = {(u8)-1, 1, (u8)-127, 127, (u8)-128, 0, 0, 0, 0,0,0,0,0,0,0,0};
  v16qi r;
  BARRIER(a);
  __asm__ volatile("pabsb %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 1 && r[1] == 1 && r[2] == 127 && r[3] == 127 &&
        r[4] == 128 && r[5] == 0,
        "pabsb");
}

static void test_pabsw(void) {
  v8hi a = {-1, 1, -32767, 32767, 0, 0, 0, 0};
  v8hi r;
  BARRIER(a);
  __asm__ volatile("pabsw %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 1 && r[1] == 1 && r[2] == 32767 && r[3] == 32767,
        "pabsw");
}

static void test_pabsd(void) {
  v4si a = {-1, 1, -100, 100};
  v4si r;
  BARRIER(a);
  __asm__ volatile("pabsd %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 1 && r[1] == 1 && r[2] == 100 && r[3] == 100, "pabsd");
}

static void test_psignb(void) {
  v16qi a = {10, 20, 30, 40, 0,0,0,0,0,0,0,0,0,0,0,0};
  v16qi b = {1, (u8)-1, 0, 1, 0,0,0,0,0,0,0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("psignb %1, %0" : "+x"(a) : "x"(b));
  // positive -> keep, negative -> negate, zero -> zero
  check(a[0] == 10 && a[1] == (u8)(-20) && a[2] == 0 && a[3] == 40,
        "psignb");
}

static void test_psignw(void) {
  v8hi a = {10, 20, 30, 40, 0,0,0,0};
  v8hi b = {1, -1, 0, 1, 0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("psignw %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 10 && a[1] == -20 && a[2] == 0 && a[3] == 40, "psignw");
}

static void test_psignd(void) {
  v4si a = {10, 20, 30, 40};
  v4si b = {1, -1, 0, 1};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("psignd %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 10 && a[1] == -20 && a[2] == 0 && a[3] == 40, "psignd");
}

static void test_palignr(void) {
  v16qi a = {16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31};
  v16qi b = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15};
  BARRIER(a); BARRIER(b);
  // palignr $4: concatenate a:b (a is high), shift right by 4 bytes
  __asm__ volatile("palignr $4, %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 4 && a[1] == 5 && a[2] == 6 && a[3] == 7 &&
        a[12] == 16 && a[13] == 17 && a[14] == 18 && a[15] == 19,
        "palignr $4");
}

// =========================================================================
// Entry point
// =========================================================================

void __attribute__((force_align_arg_pointer)) _start(void) {
  // SSE3 FP
  test_addsubps();
  test_addsubpd();
  test_haddps();
  test_hsubps();
  test_haddpd();
  test_hsubpd();
  test_movshdup();
  test_movsldup();
  test_movddup();
  test_lddqu();

  // SSSE3 integer
  test_pshufb();
  test_pshufb_zero();
  test_phaddw();
  test_phaddd();
  test_phsubw();
  test_phsubd();
  test_phaddsw();
  test_phsubsw();
  test_pmaddubsw();
  test_pmulhrsw();
  test_pabsb();
  test_pabsw();
  test_pabsd();
  test_psignb();
  test_psignw();
  test_psignd();
  test_palignr();

  // Summary
  print("\n");
  print_int(test_num);
  print(" tests, ");
  print_int(fail_count);
  print(" failures\n");

  syscall1(60, fail_count);
}

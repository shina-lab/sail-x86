// AVX instruction tests — runs under sail_x86_sim only (not on host).
// Uses VEX-encoded instructions via inline asm with -mavx.
// No libc; uses raw syscalls.

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

// Compare two float arrays (as u32 bit patterns)
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

// =========================================================================
// Tests
// =========================================================================

typedef float v4sf __attribute__((vector_size(16)));
typedef float v8sf __attribute__((vector_size(32)));
typedef double v2df __attribute__((vector_size(16)));
typedef double v4df __attribute__((vector_size(32)));
typedef int v4si __attribute__((vector_size(16)));
typedef int v8si __attribute__((vector_size(32)));
typedef long long v2di __attribute__((vector_size(16)));
typedef long long v4di __attribute__((vector_size(32)));
typedef unsigned char v16qi __attribute__((vector_size(16)));
typedef unsigned char v32qi __attribute__((vector_size(32)));

// Force values through memory to avoid compiler optimizations
#define BARRIER(x) __asm__ volatile("" : "+x"(x))

static void test_vaddps_128(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {5.0f, 6.0f, 7.0f, 8.0f};
  v4sf r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vaddps %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  check(f32_eq(r[0], 6.0f) && f32_eq(r[1], 8.0f) &&
        f32_eq(r[2], 10.0f) && f32_eq(r[3], 12.0f),
        "vaddps xmm");
}

static void test_vaddps_256(void) {
  v8sf a = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f};
  v8sf b = {10.0f, 20.0f, 30.0f, 40.0f, 50.0f, 60.0f, 70.0f, 80.0f};
  v8sf r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vaddps %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  check(f32_eq(r[0], 11.0f) && f32_eq(r[1], 22.0f) &&
        f32_eq(r[2], 33.0f) && f32_eq(r[3], 44.0f) &&
        f32_eq(r[4], 55.0f) && f32_eq(r[5], 66.0f) &&
        f32_eq(r[6], 77.0f) && f32_eq(r[7], 88.0f),
        "vaddps ymm");
}

static void test_vsubps_128(void) {
  v4sf a = {10.0f, 20.0f, 30.0f, 40.0f};
  v4sf b = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vsubps %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  check(f32_eq(r[0], 9.0f) && f32_eq(r[1], 18.0f) &&
        f32_eq(r[2], 27.0f) && f32_eq(r[3], 36.0f),
        "vsubps xmm");
}

static void test_vmulps_128(void) {
  v4sf a = {2.0f, 3.0f, 4.0f, 5.0f};
  v4sf b = {10.0f, 10.0f, 10.0f, 10.0f};
  v4sf r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vmulps %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  check(f32_eq(r[0], 20.0f) && f32_eq(r[1], 30.0f) &&
        f32_eq(r[2], 40.0f) && f32_eq(r[3], 50.0f),
        "vmulps xmm");
}

static void test_vdivps_128(void) {
  v4sf a = {20.0f, 30.0f, 40.0f, 50.0f};
  v4sf b = {10.0f, 10.0f, 10.0f, 10.0f};
  v4sf r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vdivps %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  check(f32_eq(r[0], 2.0f) && f32_eq(r[1], 3.0f) &&
        f32_eq(r[2], 4.0f) && f32_eq(r[3], 5.0f),
        "vdivps xmm");
}

static void test_vaddpd_128(void) {
  v2df a = {1.5, 2.5};
  v2df b = {3.5, 4.5};
  v2df r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vaddpd %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  check(f64_eq(r[0], 5.0) && f64_eq(r[1], 7.0),
        "vaddpd xmm");
}

static void test_vaddpd_256(void) {
  v4df a = {1.0, 2.0, 3.0, 4.0};
  v4df b = {10.0, 20.0, 30.0, 40.0};
  v4df r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vaddpd %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  check(f64_eq(r[0], 11.0) && f64_eq(r[1], 22.0) &&
        f64_eq(r[2], 33.0) && f64_eq(r[3], 44.0),
        "vaddpd ymm");
}

static void test_vmulpd_128(void) {
  v2df a = {3.0, 4.0};
  v2df b = {5.0, 6.0};
  v2df r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vmulpd %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  check(f64_eq(r[0], 15.0) && f64_eq(r[1], 24.0),
        "vmulpd xmm");
}

static void test_vaddss(void) {
  v4sf a = {1.0f, 100.0f, 200.0f, 300.0f};
  v4sf b = {2.0f, 999.0f, 999.0f, 999.0f};
  v4sf r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vaddss %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  // Scalar: r[0] = a[0]+b[0] = 3.0, upper lanes from a
  check(f32_eq(r[0], 3.0f) && f32_eq(r[1], 100.0f) &&
        f32_eq(r[2], 200.0f) && f32_eq(r[3], 300.0f),
        "vaddss (scalar + merge)");
}

static void test_vaddsd(void) {
  v2df a = {1.5, 100.0};
  v2df b = {2.5, 999.0};
  v2df r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vaddsd %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  check(f64_eq(r[0], 4.0) && f64_eq(r[1], 100.0),
        "vaddsd (scalar + merge)");
}

static void test_vxorps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf r;
  BARRIER(a);
  // XOR with itself should give zero
  __asm__ volatile("vxorps %1, %1, %0" : "=x"(r) : "x"(a));
  check(f32_eq(r[0], 0.0f) && f32_eq(r[1], 0.0f) &&
        f32_eq(r[2], 0.0f) && f32_eq(r[3], 0.0f),
        "vxorps (self = zero)");
}

static void test_vandps(void) {
  // AND of same value should be identity
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf r;
  BARRIER(a);
  __asm__ volatile("vandps %1, %1, %0" : "=x"(r) : "x"(a));
  check(f32_eq(r[0], 1.0f) && f32_eq(r[1], 2.0f) &&
        f32_eq(r[2], 3.0f) && f32_eq(r[3], 4.0f),
        "vandps (self = identity)");
}

static void test_vorps(void) {
  // OR with zero should be identity
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf z = {0.0f, 0.0f, 0.0f, 0.0f};
  v4sf r;
  BARRIER(a); BARRIER(z);
  __asm__ volatile("vorps %2, %1, %0" : "=x"(r) : "x"(a), "x"(z));
  check(f32_eq(r[0], 1.0f) && f32_eq(r[1], 2.0f) &&
        f32_eq(r[2], 3.0f) && f32_eq(r[3], 4.0f),
        "vorps (with zero = identity)");
}

static void test_vmovaps_128(void) {
  v4sf a = {11.0f, 22.0f, 33.0f, 44.0f};
  v4sf r;
  BARRIER(a);
  __asm__ volatile("vmovaps %1, %0" : "=x"(r) : "x"(a));
  check(f32_eq(r[0], 11.0f) && f32_eq(r[1], 22.0f) &&
        f32_eq(r[2], 33.0f) && f32_eq(r[3], 44.0f),
        "vmovaps xmm");
}

static void test_vmovaps_256(void) {
  v8sf a = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f};
  v8sf r;
  BARRIER(a);
  __asm__ volatile("vmovaps %1, %0" : "=x"(r) : "x"(a));
  check(f32_eq(r[0], 1.0f) && f32_eq(r[1], 2.0f) &&
        f32_eq(r[2], 3.0f) && f32_eq(r[3], 4.0f) &&
        f32_eq(r[4], 5.0f) && f32_eq(r[5], 6.0f) &&
        f32_eq(r[6], 7.0f) && f32_eq(r[7], 8.0f),
        "vmovaps ymm");
}

static void test_vmovdqa_128(void) {
  v4si a = {0x11111111, 0x22222222, 0x33333333, 0x44444444};
  v4si r;
  BARRIER(a);
  __asm__ volatile("vmovdqa %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 0x11111111 && r[1] == 0x22222222 &&
        r[2] == 0x33333333 && r[3] == 0x44444444,
        "vmovdqa xmm");
}

static void test_vpxor(void) {
  v4si a = {0xDEADBEEF, 0xCAFEBABE, 0x12345678, 0xABCDEF01};
  v4si r;
  BARRIER(a);
  __asm__ volatile("vpxor %1, %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 0 && r[1] == 0 && r[2] == 0 && r[3] == 0,
        "vpxor (self = zero)");
}

static void test_vpand(void) {
  v4si a = {0xFF00FF00, 0x0F0F0F0F, 0xAAAAAAAA, 0x55555555};
  v4si b = {0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF};
  v4si r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpand %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  check(r[0] == (int)0xFF00FF00 && r[1] == 0x0F0F0F0F &&
        r[2] == (int)0xAAAAAAAA && r[3] == 0x55555555,
        "vpand xmm");
}

static void test_vpandn(void) {
  v4si a = {(int)0xFFFFFFFF, 0, (int)0xFFFFFFFF, 0};
  v4si b = {0x12345678, 0x12345678, 0x12345678, 0x12345678};
  v4si r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpandn %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  // PANDN: ~a & b
  check(r[0] == 0 && r[1] == 0x12345678 &&
        r[2] == 0 && r[3] == 0x12345678,
        "vpandn xmm");
}

static void test_vpor(void) {
  v4si a = {0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF};
  v4si b = {0x000000FF, 0x0000FF00, 0x00FF0000, 0xFF000000};
  v4si r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpor %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  check(r[0] == (int)0xFF0000FF && r[1] == (int)0x00FFFF00 &&
        r[2] == (int)0x00FFFF00 && r[3] == (int)0xFF0000FF,
        "vpor xmm");
}

static void test_vpaddb_128(void) {
  v16qi a = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  v16qi b = {16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1};
  v16qi r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpaddb %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  int pass = 1;
  for (int i = 0; i < 16; i++)
    if (r[i] != 17) pass = 0;
  check(pass, "vpaddb xmm (all lanes = 17)");
}

static void test_vpaddd_128(void) {
  v4si a = {100, 200, 300, 400};
  v4si b = {1, 2, 3, 4};
  v4si r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpaddd %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  check(r[0] == 101 && r[1] == 202 && r[2] == 303 && r[3] == 404,
        "vpaddd xmm");
}

static void test_vpaddq_128(void) {
  v2di a = {1000000000LL, 2000000000LL};
  v2di b = {3000000000LL, 4000000000LL};
  v2di r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpaddq %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  check(r[0] == 4000000000LL && r[1] == 6000000000LL,
        "vpaddq xmm");
}

static void test_vpsubb_128(void) {
  v16qi a = {20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20};
  v16qi b = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  v16qi r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpsubb %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  int pass = 1;
  for (int i = 0; i < 16; i++)
    if (r[i] != (u8)(20 - (i + 1))) pass = 0;
  check(pass, "vpsubb xmm");
}

static void test_vpsubd_128(void) {
  v4si a = {100, 200, 300, 400};
  v4si b = {1, 2, 3, 4};
  v4si r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpsubd %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  check(r[0] == 99 && r[1] == 198 && r[2] == 297 && r[3] == 396,
        "vpsubd xmm");
}

static void test_vbroadcastss(void) {
  float val __attribute__((aligned(4))) = 42.0f;
  v4sf r128;
  v8sf r256;
  __asm__ volatile("vbroadcastss %1, %0" : "=x"(r128) : "m"(val));
  __asm__ volatile("vbroadcastss %1, %0" : "=x"(r256) : "m"(val));
  check(f32_eq(r128[0], 42.0f) && f32_eq(r128[1], 42.0f) &&
        f32_eq(r128[2], 42.0f) && f32_eq(r128[3], 42.0f),
        "vbroadcastss xmm");
  check(f32_eq(r256[0], 42.0f) && f32_eq(r256[1], 42.0f) &&
        f32_eq(r256[2], 42.0f) && f32_eq(r256[3], 42.0f) &&
        f32_eq(r256[4], 42.0f) && f32_eq(r256[5], 42.0f) &&
        f32_eq(r256[6], 42.0f) && f32_eq(r256[7], 42.0f),
        "vbroadcastss ymm");
}

static void test_vbroadcastsd(void) {
  double val __attribute__((aligned(8))) = 99.0;
  v4df r;
  __asm__ volatile("vbroadcastsd %1, %0" : "=x"(r) : "m"(val));
  check(f64_eq(r[0], 99.0) && f64_eq(r[1], 99.0) &&
        f64_eq(r[2], 99.0) && f64_eq(r[3], 99.0),
        "vbroadcastsd ymm");
}

static void test_vinsertf128(void) {
  v4df src1 = {1.0, 2.0, 3.0, 4.0};
  v2df src2 = {10.0, 20.0};
  v4df r;
  BARRIER(src1); BARRIER(src2);
  // Insert into low lane (imm=0)
  __asm__ volatile("vinsertf128 $0, %2, %1, %0"
                   : "=x"(r) : "x"(src1), "x"(src2));
  check(f64_eq(r[0], 10.0) && f64_eq(r[1], 20.0) &&
        f64_eq(r[2], 3.0) && f64_eq(r[3], 4.0),
        "vinsertf128 low");
  // Insert into high lane (imm=1)
  __asm__ volatile("vinsertf128 $1, %2, %1, %0"
                   : "=x"(r) : "x"(src1), "x"(src2));
  check(f64_eq(r[0], 1.0) && f64_eq(r[1], 2.0) &&
        f64_eq(r[2], 10.0) && f64_eq(r[3], 20.0),
        "vinsertf128 high");
}

static void test_vextractf128(void) {
  v4df src = {1.0, 2.0, 3.0, 4.0};
  v2df r;
  BARRIER(src);
  // Extract low lane (imm=0)
  __asm__ volatile("vextractf128 $0, %1, %0" : "=x"(r) : "x"(src));
  check(f64_eq(r[0], 1.0) && f64_eq(r[1], 2.0),
        "vextractf128 low");
  // Extract high lane (imm=1)
  __asm__ volatile("vextractf128 $1, %1, %0" : "=x"(r) : "x"(src));
  check(f64_eq(r[0], 3.0) && f64_eq(r[1], 4.0),
        "vextractf128 high");
}

static void test_vzeroupper(void) {
  // Load a 256-bit value, then vzeroupper, then check upper is zero
  v8sf a = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f};
  v8sf r;
  BARRIER(a);
  __asm__ volatile(
    "vmovaps %1, %%ymm0\n\t"
    "vzeroupper\n\t"
    "vmovaps %%ymm0, %0"
    : "=x"(r) : "x"(a) : "ymm0");
  // After vzeroupper, upper 128 of ymm0 should be zero
  check(f32_eq(r[0], 1.0f) && f32_eq(r[1], 2.0f) &&
        f32_eq(r[2], 3.0f) && f32_eq(r[3], 4.0f) &&
        f32_eq(r[4], 0.0f) && f32_eq(r[5], 0.0f) &&
        f32_eq(r[6], 0.0f) && f32_eq(r[7], 0.0f),
        "vzeroupper");
}

// 256-bit integer operations
static void test_vpaddd_256(void) {
  v8si a = {1, 2, 3, 4, 5, 6, 7, 8};
  v8si b = {10, 20, 30, 40, 50, 60, 70, 80};
  v8si r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpaddd %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  check(r[0] == 11 && r[1] == 22 && r[2] == 33 && r[3] == 44 &&
        r[4] == 55 && r[5] == 66 && r[6] == 77 && r[7] == 88,
        "vpaddd ymm");
}

static void test_vpsubd_256(void) {
  v8si a = {100, 200, 300, 400, 500, 600, 700, 800};
  v8si b = {1, 2, 3, 4, 5, 6, 7, 8};
  v8si r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpsubd %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  check(r[0] == 99 && r[1] == 198 && r[2] == 297 && r[3] == 396 &&
        r[4] == 495 && r[5] == 594 && r[6] == 693 && r[7] == 792,
        "vpsubd ymm");
}

static void test_vmovups_mem(void) {
  float buf[4] __attribute__((aligned(16))) = {1.5f, 2.5f, 3.5f, 4.5f};
  v4sf r;
  __asm__ volatile("vmovups %1, %0" : "=x"(r) : "m"(buf));
  check(f32_eq(r[0], 1.5f) && f32_eq(r[1], 2.5f) &&
        f32_eq(r[2], 3.5f) && f32_eq(r[3], 4.5f),
        "vmovups load from memory");

  float out[4] __attribute__((aligned(16)));
  __asm__ volatile("vmovups %1, %0" : "=m"(out) : "x"(r));
  check(f32_eq(out[0], 1.5f) && f32_eq(out[1], 2.5f) &&
        f32_eq(out[2], 3.5f) && f32_eq(out[3], 4.5f),
        "vmovups store to memory");
}

static void test_vmovss_mem(void) {
  float val __attribute__((aligned(4))) = 42.0f;
  v4sf r;
  __asm__ volatile("vmovss %1, %0" : "=x"(r) : "m"(val));
  // Load from mem: zero-extends to 128 bits
  check(f32_eq(r[0], 42.0f) && f32_eq(r[1], 0.0f) &&
        f32_eq(r[2], 0.0f) && f32_eq(r[3], 0.0f),
        "vmovss load (zero-extend)");
}

static void test_vmovsd_mem(void) {
  double val __attribute__((aligned(8))) = 99.0;
  v2df r;
  __asm__ volatile("vmovsd %1, %0" : "=x"(r) : "m"(val));
  check(f64_eq(r[0], 99.0) && f64_eq(r[1], 0.0),
        "vmovsd load (zero-extend)");
}

static void test_vsubps_256(void) {
  v8sf a = {10.0f, 20.0f, 30.0f, 40.0f, 50.0f, 60.0f, 70.0f, 80.0f};
  v8sf b = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f};
  v8sf r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vsubps %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  check(f32_eq(r[0], 9.0f) && f32_eq(r[1], 18.0f) &&
        f32_eq(r[2], 27.0f) && f32_eq(r[3], 36.0f) &&
        f32_eq(r[4], 45.0f) && f32_eq(r[5], 54.0f) &&
        f32_eq(r[6], 63.0f) && f32_eq(r[7], 72.0f),
        "vsubps ymm");
}

static void test_vmulps_256(void) {
  v8sf a = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f};
  v8sf b = {2.0f, 2.0f, 2.0f, 2.0f, 2.0f, 2.0f, 2.0f, 2.0f};
  v8sf r;
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vmulps %2, %1, %0" : "=x"(r) : "x"(a), "x"(b));
  check(f32_eq(r[0], 2.0f) && f32_eq(r[1], 4.0f) &&
        f32_eq(r[2], 6.0f) && f32_eq(r[3], 8.0f) &&
        f32_eq(r[4], 10.0f) && f32_eq(r[5], 12.0f) &&
        f32_eq(r[6], 14.0f) && f32_eq(r[7], 16.0f),
        "vmulps ymm");
}

void _start(void) {
  // FP arithmetic 128-bit
  test_vaddps_128();
  test_vsubps_128();
  test_vmulps_128();
  test_vdivps_128();
  test_vaddpd_128();
  test_vmulpd_128();

  // FP arithmetic 256-bit
  test_vaddps_256();
  test_vsubps_256();
  test_vmulps_256();
  test_vaddpd_256();

  // Scalar FP
  test_vaddss();
  test_vaddsd();

  // Bitwise
  test_vxorps();
  test_vandps();
  test_vorps();

  // Move instructions
  test_vmovaps_128();
  test_vmovaps_256();
  test_vmovdqa_128();
  test_vmovups_mem();
  test_vmovss_mem();
  test_vmovsd_mem();

  // Integer packed
  test_vpxor();
  test_vpand();
  test_vpandn();
  test_vpor();
  test_vpaddb_128();
  test_vpaddd_128();
  test_vpaddq_128();
  test_vpsubb_128();
  test_vpsubd_128();
  test_vpaddd_256();
  test_vpsubd_256();

  // Broadcast
  test_vbroadcastss();
  test_vbroadcastsd();

  // Insert/Extract
  test_vinsertf128();
  test_vextractf128();

  // VZEROUPPER
  test_vzeroupper();

  // Summary
  print("\n");
  print_int(test_num);
  print(" tests, ");
  print_int(fail_count);
  print(" failures\n");

  syscall1(60, fail_count); // exit(fail_count)
}

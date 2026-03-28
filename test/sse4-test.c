// Legacy SSE4.1 + SSE4.2 instruction tests.
// Compiled with -msse4.2 -mno-avx to force legacy (non-VEX) encoding.

typedef unsigned long u64;
typedef long i64;
typedef unsigned int u32;
typedef unsigned char u8;
typedef unsigned short u16;

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
// SSE4.1 floating-point
// =========================================================================

static void test_roundps(void) {
  v4sf a = {1.3f, 2.7f, -1.3f, -2.7f};
  v4sf r;
  BARRIER(a);
  // imm=0: round to nearest even
  __asm__ volatile("roundps $0, %1, %0" : "=x"(r) : "x"(a));
  check(f32_eq(r[0], 1.0f) && f32_eq(r[1], 3.0f) &&
        f32_eq(r[2], -1.0f) && f32_eq(r[3], -3.0f),
        "roundps $0 (nearest)");
}

static void test_roundps_floor(void) {
  v4sf a = {1.3f, 2.7f, -1.3f, -2.7f};
  v4sf r;
  BARRIER(a);
  // imm=1: floor
  __asm__ volatile("roundps $1, %1, %0" : "=x"(r) : "x"(a));
  check(f32_eq(r[0], 1.0f) && f32_eq(r[1], 2.0f) &&
        f32_eq(r[2], -2.0f) && f32_eq(r[3], -3.0f),
        "roundps $1 (floor)");
}

static void test_roundps_ceil(void) {
  v4sf a = {1.3f, 2.7f, -1.3f, -2.7f};
  v4sf r;
  BARRIER(a);
  // imm=2: ceil
  __asm__ volatile("roundps $2, %1, %0" : "=x"(r) : "x"(a));
  check(f32_eq(r[0], 2.0f) && f32_eq(r[1], 3.0f) &&
        f32_eq(r[2], -1.0f) && f32_eq(r[3], -2.0f),
        "roundps $2 (ceil)");
}

static void test_roundps_trunc(void) {
  v4sf a = {1.3f, 2.7f, -1.3f, -2.7f};
  v4sf r;
  BARRIER(a);
  // imm=3: truncate
  __asm__ volatile("roundps $3, %1, %0" : "=x"(r) : "x"(a));
  check(f32_eq(r[0], 1.0f) && f32_eq(r[1], 2.0f) &&
        f32_eq(r[2], -1.0f) && f32_eq(r[3], -2.0f),
        "roundps $3 (truncate)");
}

static void test_roundpd(void) {
  v2df a = {1.3, -2.7};
  v2df r;
  BARRIER(a);
  __asm__ volatile("roundpd $0, %1, %0" : "=x"(r) : "x"(a));
  check(f64_eq(r[0], 1.0) && f64_eq(r[1], -3.0), "roundpd $0 (nearest)");
}

static void test_roundss(void) {
  v4sf a = {99.0f, 100.0f, 200.0f, 300.0f};
  v4sf b = {1.7f, 0, 0, 0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("roundss $1, %1, %0" : "+x"(a) : "x"(b));
  // Floor of 1.7 = 1.0, upper lanes from a preserved
  check(f32_eq(a[0], 1.0f) && f32_eq(a[1], 100.0f) &&
        f32_eq(a[2], 200.0f) && f32_eq(a[3], 300.0f),
        "roundss $1 (floor)");
}

static void test_roundsd(void) {
  v2df a = {99.0, 100.0};
  v2df b = {1.7, 0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("roundsd $1, %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 1.0) && f64_eq(a[1], 100.0), "roundsd $1 (floor)");
}

static void test_dpps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {5.0f, 6.0f, 7.0f, 8.0f};
  BARRIER(a); BARRIER(b);
  // imm=0xFF: dot product of all 4 lanes, broadcast to all 4
  __asm__ volatile("dpps $0xFF, %1, %0" : "+x"(a) : "x"(b));
  // 1*5 + 2*6 + 3*7 + 4*8 = 5+12+21+32 = 70
  check(f32_eq(a[0], 70.0f) && f32_eq(a[1], 70.0f) &&
        f32_eq(a[2], 70.0f) && f32_eq(a[3], 70.0f),
        "dpps $0xFF");
}

static void test_dpps_partial(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {5.0f, 6.0f, 7.0f, 8.0f};
  BARRIER(a); BARRIER(b);
  // imm=0x71: multiply lanes 0,1,2 (bits 4,5,6), store in lane 0 only (bit 0)
  __asm__ volatile("dpps $0x71, %1, %0" : "+x"(a) : "x"(b));
  // 1*5 + 2*6 + 3*7 = 38
  check(f32_eq(a[0], 38.0f) && f32_eq(a[1], 0.0f) &&
        f32_eq(a[2], 0.0f) && f32_eq(a[3], 0.0f),
        "dpps $0x71 (partial)");
}

static void test_dppd(void) {
  v2df a = {3.0, 4.0};
  v2df b = {5.0, 6.0};
  BARRIER(a); BARRIER(b);
  // imm=0x33: multiply both lanes, store in both
  __asm__ volatile("dppd $0x33, %1, %0" : "+x"(a) : "x"(b));
  // 3*5 + 4*6 = 39
  check(f64_eq(a[0], 39.0) && f64_eq(a[1], 39.0), "dppd $0x33");
}

// =========================================================================
// SSE4.1 blend
// =========================================================================

static void test_blendps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {10.0f, 20.0f, 30.0f, 40.0f};
  BARRIER(a); BARRIER(b);
  // imm=0x05 = 0b0101: select b for lanes 0,2
  __asm__ volatile("blendps $0x05, %1, %0" : "+x"(a) : "x"(b));
  check(f32_eq(a[0], 10.0f) && f32_eq(a[1], 2.0f) &&
        f32_eq(a[2], 30.0f) && f32_eq(a[3], 4.0f),
        "blendps $0x05");
}

static void test_blendpd(void) {
  v2df a = {1.0, 2.0};
  v2df b = {10.0, 20.0};
  BARRIER(a); BARRIER(b);
  // imm=0x02: select b for lane 1
  __asm__ volatile("blendpd $0x02, %1, %0" : "+x"(a) : "x"(b));
  check(f64_eq(a[0], 1.0) && f64_eq(a[1], 20.0), "blendpd $0x02");
}

static void test_blendvps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {10.0f, 20.0f, 30.0f, 40.0f};
  // Mask in xmm0: sign bits select from b
  v4si mask = {(int)0x80000000, 0, (int)0x80000000, 0};
  BARRIER(a); BARRIER(b); BARRIER(mask);
  __asm__ volatile(
    "movdqa %2, %%xmm0\n\t"
    "blendvps %%xmm0, %1, %0"
    : "+x"(a) : "x"(b), "x"(mask) : "xmm0");
  check(f32_eq(a[0], 10.0f) && f32_eq(a[1], 2.0f) &&
        f32_eq(a[2], 30.0f) && f32_eq(a[3], 4.0f),
        "blendvps");
}

static void test_blendvpd(void) {
  v2df a = {1.0, 2.0};
  v2df b = {10.0, 20.0};
  v2di mask = {(long long)0x8000000000000000LL, 0};
  BARRIER(a); BARRIER(b); BARRIER(mask);
  __asm__ volatile(
    "movdqa %2, %%xmm0\n\t"
    "blendvpd %%xmm0, %1, %0"
    : "+x"(a) : "x"(b), "x"(mask) : "xmm0");
  check(f64_eq(a[0], 10.0) && f64_eq(a[1], 2.0), "blendvpd");
}

static void test_pblendw(void) {
  v8hi a = {1, 2, 3, 4, 5, 6, 7, 8};
  v8hi b = {10, 20, 30, 40, 50, 60, 70, 80};
  BARRIER(a); BARRIER(b);
  // imm=0x55 = 0b01010101: select b for even words
  __asm__ volatile("pblendw $0x55, %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 10 && a[1] == 2 && a[2] == 30 && a[3] == 4 &&
        a[4] == 50 && a[5] == 6 && a[6] == 70 && a[7] == 8,
        "pblendw $0x55");
}

static void test_pblendvb(void) {
  v16qi a = {1, 2, 3, 4, 5,6,7,8,9,10,11,12,13,14,15,16};
  v16qi b = {11,12,13,14, 15,16,17,18,19,20,21,22,23,24,25,26};
  v16qi mask = {0x80, 0, 0x80, 0, 0,0,0,0,0,0,0,0,0,0,0,0};
  BARRIER(a); BARRIER(b); BARRIER(mask);
  __asm__ volatile(
    "movdqa %2, %%xmm0\n\t"
    "pblendvb %%xmm0, %1, %0"
    : "+x"(a) : "x"(b), "x"(mask) : "xmm0");
  check(a[0] == 11 && a[1] == 2 && a[2] == 13 && a[3] == 4,
        "pblendvb");
}

// =========================================================================
// SSE4.1 integer
// =========================================================================

static void test_pmulld(void) {
  v4si a = {3, 7, 11, 13};
  v4si b = {5, 4, 3, 2};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pmulld %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 15 && a[1] == 28 && a[2] == 33 && a[3] == 26, "pmulld");
}

static void test_pmuldq(void) {
  v4si a = {3, 0, 7, 0};
  v4si b = {5, 0, 11, 0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pmuldq %1, %0" : "+x"(a) : "x"(b));
  v2di r;
  __builtin_memcpy(&r, &a, 16);
  check(r[0] == 15 && r[1] == 77, "pmuldq");
}

static void test_pminsd(void) {
  v4si a = {-10, 20, -30, 40};
  v4si b = {10, -20, 30, -40};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pminsd %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == -10 && a[1] == -20 && a[2] == -30 && a[3] == -40, "pminsd");
}

static void test_pmaxsd(void) {
  v4si a = {-10, 20, -30, 40};
  v4si b = {10, -20, 30, -40};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pmaxsd %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 10 && a[1] == 20 && a[2] == 30 && a[3] == 40, "pmaxsd");
}

static void test_pminud(void) {
  v4si a = {10, 20, 30, 40};
  v4si b = {5, 25, 15, 45};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pminud %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 5 && a[1] == 20 && a[2] == 15 && a[3] == 40, "pminud");
}

static void test_pmaxud(void) {
  v4si a = {10, 20, 30, 40};
  v4si b = {5, 25, 15, 45};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pmaxud %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 10 && a[1] == 25 && a[2] == 30 && a[3] == 45, "pmaxud");
}

static void test_pminsb(void) {
  v16qi a = {(u8)-10, 20, 0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  v16qi b = {10, (u8)-20, 0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pminsb %1, %0" : "+x"(a) : "x"(b));
  check((signed char)a[0] == -10 && (signed char)a[1] == -20, "pminsb");
}

static void test_pmaxsb(void) {
  v16qi a = {(u8)-10, 20, 0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  v16qi b = {10, (u8)-20, 0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pmaxsb %1, %0" : "+x"(a) : "x"(b));
  check((signed char)a[0] == 10 && (signed char)a[1] == 20, "pmaxsb");
}

static void test_pminuw(void) {
  v8hi a = {10, 200, 0,0,0,0,0,0};
  v8hi b = {20, 100, 0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pminuw %1, %0" : "+x"(a) : "x"(b));
  check((u16)a[0] == 10 && (u16)a[1] == 100, "pminuw");
}

static void test_pmaxuw(void) {
  v8hi a = {10, 200, 0,0,0,0,0,0};
  v8hi b = {20, 100, 0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pmaxuw %1, %0" : "+x"(a) : "x"(b));
  check((u16)a[0] == 20 && (u16)a[1] == 200, "pmaxuw");
}

static void test_packusdw(void) {
  v4si a = {0, 65535, 65536, -1};
  v4si b = {1, 2, 3, 4};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("packusdw %1, %0" : "+x"(a) : "x"(b));
  v8hi r;
  __builtin_memcpy(&r, &a, 16);
  check((u16)r[0] == 0 && (u16)r[1] == 65535 && (u16)r[2] == 65535 && (u16)r[3] == 0 &&
        (u16)r[4] == 1 && (u16)r[5] == 2 && (u16)r[6] == 3 && (u16)r[7] == 4,
        "packusdw");
}

static void test_pcmpeqq(void) {
  v2di a = {123456789LL, 987654321LL};
  v2di b = {123456789LL, 0LL};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pcmpeqq %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == (long long)0xFFFFFFFFFFFFFFFFLL && a[1] == 0, "pcmpeqq");
}

static void test_ptest(void) {
  v4si a = {1, 2, 3, 4};
  v4si z = {0, 0, 0, 0};
  BARRIER(a); BARRIER(z);
  int zf_result;
  // ptest: ZF=1 if (a AND b) == 0
  __asm__ volatile("ptest %2, %1\n\t"
                   "sete %b0\n\t"
                   "movzbl %b0, %0"
                   : "=r"(zf_result) : "x"(a), "x"(z));
  check(zf_result == 1, "ptest (ZF=1 for zero mask)");

  __asm__ volatile("ptest %2, %1\n\t"
                   "sete %b0\n\t"
                   "movzbl %b0, %0"
                   : "=r"(zf_result) : "x"(a), "x"(a));
  check(zf_result == 0, "ptest (ZF=0 for non-zero)");
}

// =========================================================================
// SSE4.1 insert/extract
// =========================================================================

static void test_pinsrb(void) {
  v16qi a = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  int val = 0xAB;
  BARRIER(a);
  __asm__ volatile("pinsrb $5, %1, %0" : "+x"(a) : "r"(val));
  check(a[5] == 0xAB && a[0] == 0 && a[4] == 0 && a[6] == 0, "pinsrb $5");
}

static void test_pinsrd(void) {
  v4si a = {0, 0, 0, 0};
  int val = 0x12345678;
  BARRIER(a);
  __asm__ volatile("pinsrd $2, %1, %0" : "+x"(a) : "r"(val));
  check(a[0] == 0 && a[1] == 0 && a[2] == 0x12345678 && a[3] == 0, "pinsrd $2");
}

static void test_pinsrq(void) {
  v2di a = {0, 0};
  long long val = 0x123456789ABCDEF0LL;
  BARRIER(a);
  __asm__ volatile("pinsrq $1, %1, %0" : "+x"(a) : "r"(val));
  check(a[0] == 0 && a[1] == 0x123456789ABCDEF0LL, "pinsrq $1");
}

static void test_pextrb(void) {
  v16qi a = {10,20,30,40,50,60,70,80,90,100,110,120,130,140,150,160};
  int r;
  BARRIER(a);
  __asm__ volatile("pextrb $7, %1, %0" : "=r"(r) : "x"(a));
  check(r == 80, "pextrb $7");
}

static void test_pextrd(void) {
  v4si a = {100, 200, 300, 400};
  int r;
  BARRIER(a);
  __asm__ volatile("pextrd $2, %1, %0" : "=r"(r) : "x"(a));
  check(r == 300, "pextrd $2");
}

static void test_pextrq(void) {
  v2di a = {0x123456789ABCDEF0LL, (long long)0xFEDCBA9876543210LL};
  long long r;
  BARRIER(a);
  __asm__ volatile("pextrq $1, %1, %0" : "=r"(r) : "x"(a));
  check(r == (long long)0xFEDCBA9876543210LL, "pextrq $1");
}

static void test_insertps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {10.0f, 20.0f, 30.0f, 40.0f};
  BARRIER(a); BARRIER(b);
  // imm=0x20: count_s=0 (b[0]=10), count_d=2 (insert at a[2]), zdmask=0
  __asm__ volatile("insertps $0x20, %1, %0" : "+x"(a) : "x"(b));
  check(f32_eq(a[0], 1.0f) && f32_eq(a[1], 2.0f) &&
        f32_eq(a[2], 10.0f) && f32_eq(a[3], 4.0f),
        "insertps $0x20");
}

static void test_extractps(void) {
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  int r;
  BARRIER(a);
  __asm__ volatile("extractps $2, %1, %0" : "=r"(r) : "x"(a));
  float f;
  __builtin_memcpy(&f, &r, 4);
  check(f32_eq(f, 3.0f), "extractps $2");
}

// =========================================================================
// SSE4.1 sign extension
// =========================================================================

static void test_pmovsxbw(void) {
  v16qi a = {(u8)-1, 2, (u8)-3, 4, (u8)-5, 6, (u8)-7, 8, 0,0,0,0,0,0,0,0};
  v8hi r;
  BARRIER(a);
  __asm__ volatile("pmovsxbw %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == -1 && r[1] == 2 && r[2] == -3 && r[3] == 4 &&
        r[4] == -5 && r[5] == 6 && r[6] == -7 && r[7] == 8,
        "pmovsxbw");
}

static void test_pmovsxbd(void) {
  v16qi a = {(u8)-1, 2, (u8)-3, 4, 0,0,0,0,0,0,0,0,0,0,0,0};
  v4si r;
  BARRIER(a);
  __asm__ volatile("pmovsxbd %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == -1 && r[1] == 2 && r[2] == -3 && r[3] == 4, "pmovsxbd");
}

static void test_pmovsxbq(void) {
  v16qi a = {(u8)-1, 2, 0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  v2di r;
  BARRIER(a);
  __asm__ volatile("pmovsxbq %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == -1 && r[1] == 2, "pmovsxbq");
}

static void test_pmovsxwd(void) {
  v8hi a = {-1, 2, -3, 4, 0,0,0,0};
  v4si r;
  BARRIER(a);
  __asm__ volatile("pmovsxwd %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == -1 && r[1] == 2 && r[2] == -3 && r[3] == 4, "pmovsxwd");
}

static void test_pmovsxwq(void) {
  v8hi a = {-1, 2, 0,0,0,0,0,0};
  v2di r;
  BARRIER(a);
  __asm__ volatile("pmovsxwq %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == -1 && r[1] == 2, "pmovsxwq");
}

static void test_pmovsxdq(void) {
  v4si a = {-1, 2, 0, 0};
  v2di r;
  BARRIER(a);
  __asm__ volatile("pmovsxdq %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == -1 && r[1] == 2, "pmovsxdq");
}

static void test_pmovzxbw(void) {
  v16qi a = {0xFF, 2, 0xFE, 4, 0xFD, 6, 0xFC, 8, 0,0,0,0,0,0,0,0};
  v8hi r;
  BARRIER(a);
  __asm__ volatile("pmovzxbw %1, %0" : "=x"(r) : "x"(a));
  check((u16)r[0] == 0xFF && r[1] == 2 && (u16)r[2] == 0xFE && r[3] == 4,
        "pmovzxbw");
}

static void test_pmovzxbd(void) {
  v16qi a = {0xFF, 2, 0xFE, 4, 0,0,0,0,0,0,0,0,0,0,0,0};
  v4si r;
  BARRIER(a);
  __asm__ volatile("pmovzxbd %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 0xFF && r[1] == 2 && r[2] == 0xFE && r[3] == 4, "pmovzxbd");
}

static void test_pmovzxwd(void) {
  v8hi a = {(short)0xFFFF, 2, (short)0xFFFE, 4, 0,0,0,0};
  v4si r;
  BARRIER(a);
  __asm__ volatile("pmovzxwd %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 0xFFFF && r[1] == 2 && r[2] == 0xFFFE && r[3] == 4, "pmovzxwd");
}

static void test_pmovzxbq(void) {
  v16qi a = {0xFF, 2, 0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  v2di r;
  BARRIER(a);
  __asm__ volatile("pmovzxbq %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 0xFF && r[1] == 2, "pmovzxbq");
}

static void test_pmovzxwq(void) {
  v8hi a = {(short)0xFFFF, 2, 0,0,0,0,0,0};
  v2di r;
  BARRIER(a);
  __asm__ volatile("pmovzxwq %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 0xFFFF && r[1] == 2, "pmovzxwq");
}

static void test_pmovzxdq(void) {
  v4si a = {(int)0xFFFFFFFF, 2, 0, 0};
  v2di r;
  BARRIER(a);
  __asm__ volatile("pmovzxdq %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 0xFFFFFFFFLL && r[1] == 2, "pmovzxdq");
}

// =========================================================================
// SSE4.1 misc
// =========================================================================

static void test_phminposuw(void) {
  v8hi a = {50, 10, 30, 20, 40, 5, 60, 70};
  v8hi r;
  BARRIER(a);
  __asm__ volatile("phminposuw %1, %0" : "=x"(r) : "x"(a));
  // r[0] = minimum value (5), r[1] = index (5), rest zeros
  check((u16)r[0] == 5 && (u16)r[1] == 5, "phminposuw");
}

static void test_movntdqa(void) {
  int buf[4] __attribute__((aligned(16))) = {0xAA, 0xBB, 0xCC, 0xDD};
  v4si r;
  __asm__ volatile("movntdqa %1, %0" : "=x"(r) : "m"(buf));
  check(r[0] == 0xAA && r[1] == 0xBB && r[2] == 0xCC && r[3] == 0xDD,
        "movntdqa");
}

static void test_pextrw_mem(void) {
  v8hi a = {10, 20, 30, 40, 50, 60, 70, 80};
  u16 mem __attribute__((aligned(2)));
  BARRIER(a);
  // SSE4.1 PEXTRW to memory (66 0F 3A 15)
  __asm__ volatile("pextrw $3, %1, %0" : "=m"(mem) : "x"(a));
  check(mem == 40, "pextrw $3 (mem)");
}

static void test_mpsadbw(void) {
  v16qi a = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15};
  v16qi b = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15};
  BARRIER(a); BARRIER(b);
  // imm=0: offset 0 in both
  __asm__ volatile("mpsadbw $0, %1, %0" : "+x"(a) : "x"(b));
  v8hi r;
  __builtin_memcpy(&r, &a, 16);
  // With identical inputs and offset 0, first SAD should be 0
  check((u16)r[0] == 0, "mpsadbw $0 (identical)");
}

// =========================================================================
// SSE4.2
// =========================================================================

static void test_pcmpgtq(void) {
  v2di a = {100, -1};
  v2di b = {50, 0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pcmpgtq %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == (long long)0xFFFFFFFFFFFFFFFFLL && a[1] == 0, "pcmpgtq");
}

static void test_pcmpestri(void) {
  // String comparison: find first match
  v16qi a = {0};
  v16qi b = {0};
  // Set up strings "abcd" and "xbyz"
  __builtin_memcpy(&a, "abcdefghijklmnop", 16);
  __builtin_memcpy(&b, "xbyzefghijklmnop", 16);
  BARRIER(a); BARRIER(b);
  int idx;
  // imm=0x00: unsigned bytes, equal any
  // EAX=4 (len a), EDX=4 (len b)
  __asm__ volatile("pcmpestri $0x00, %2, %1"
                   : "=c"(idx)
                   : "x"(a), "x"(b), "a"(4), "d"(4));
  // 'b' is at index 1 in b and also in a, so first matching byte in b is index 1
  check(idx == 1, "pcmpestri (equal any)");
}

static void test_pcmpistrm(void) {
  v16qi a = {0};
  v16qi b = {0};
  __builtin_memcpy(&a, "aaaa", 4);
  __builtin_memcpy(&b, "abab", 4);
  BARRIER(a); BARRIER(b);
  v16qi r;
  // imm=0x00: unsigned bytes, equal any; returns bitmask in xmm0
  __asm__ volatile("pcmpistrm $0x00, %2, %1\n\t"
                   "movdqa %%xmm0, %0"
                   : "=x"(r) : "x"(a), "x"(b) : "xmm0");
  // 'a' matches at positions 0 and 2 in b
  u16 mask;
  __builtin_memcpy(&mask, &r, 2);
  check((mask & 0xF) == 0x5, "pcmpistrm (equal any, bitmask)");
}

static void test_pcmpestrm(void) {
  v16qi a = {0};
  v16qi b = {0};
  __builtin_memcpy(&a, "aaaa", 4);
  __builtin_memcpy(&b, "abab", 4);
  BARRIER(a); BARRIER(b);
  v16qi r;
  // imm=0x00: unsigned bytes, equal any; returns bitmask in xmm0
  __asm__ volatile("pcmpestrm $0x00, %2, %1\n\t"
                   "movdqa %%xmm0, %0"
                   : "=x"(r) : "x"(a), "x"(b), "a"(4), "d"(4) : "xmm0");
  u16 mask;
  __builtin_memcpy(&mask, &r, 2);
  // 'a' matches at positions 0 and 2 in b
  check((mask & 0xF) == 0x5, "pcmpestrm (equal any, bitmask)");
}

static void test_pcmpistri(void) {
  v16qi a = {0};
  v16qi b = {0};
  __builtin_memcpy(&a, "abcd", 4);
  __builtin_memcpy(&b, "xbyz", 4);
  BARRIER(a); BARRIER(b);
  int idx;
  // imm=0x00: unsigned bytes, equal any
  __asm__ volatile("pcmpistri $0x00, %2, %1"
                   : "=c"(idx)
                   : "x"(a), "x"(b));
  // 'b' is at index 1 in b and also in a
  check(idx == 1, "pcmpistri (equal any)");
}

static void test_crc32(void) {
  u32 crc = 0;
  u8 data = 0x01;
  __asm__ volatile("crc32b %1, %0" : "+r"(crc) : "r"(data));
  check(crc == 0xF26B8303, "crc32b");
}

static void test_popcnt(void) {
  u64 val = 0xFF00FF00FF00FF00ULL;
  u64 r;
  __asm__ volatile("popcnt %1, %0" : "=r"(r) : "r"(val));
  check(r == 32, "popcnt");
}

// =========================================================================
// Entry point
// =========================================================================

void __attribute__((force_align_arg_pointer)) _start(void) {
  // SSE4.1 FP
  test_roundps();
  test_roundps_floor();
  test_roundps_ceil();
  test_roundps_trunc();
  test_roundpd();
  test_roundss();
  test_roundsd();
  test_dpps();
  test_dpps_partial();
  test_dppd();

  // SSE4.1 blend
  test_blendps();
  test_blendpd();
  test_blendvps();
  test_blendvpd();
  test_pblendw();
  test_pblendvb();

  // SSE4.1 integer
  test_pmulld();
  test_pmuldq();
  test_pminsd();
  test_pmaxsd();
  test_pminud();
  test_pmaxud();
  test_pminsb();
  test_pmaxsb();
  test_pminuw();
  test_pmaxuw();
  test_packusdw();
  test_pcmpeqq();
  test_ptest();

  // SSE4.1 insert/extract
  test_pinsrb();
  test_pinsrd();
  test_pinsrq();
  test_pextrb();
  test_pextrd();
  test_pextrq();
  test_insertps();
  test_extractps();

  // SSE4.1 sign extension
  test_pmovsxbw();
  test_pmovsxbd();
  test_pmovsxbq();
  test_pmovsxwd();
  test_pmovsxwq();
  test_pmovsxdq();
  test_pmovzxbw();
  test_pmovzxbd();
  test_pmovzxbq();
  test_pmovzxwd();
  test_pmovzxwq();
  test_pmovzxdq();

  // SSE4.1 misc
  test_movntdqa();
  test_pextrw_mem();
  test_phminposuw();
  test_mpsadbw();

  // SSE4.2
  test_pcmpgtq();
  test_pcmpestri();
  test_pcmpestrm();
  test_pcmpistrm();
  test_pcmpistri();
  test_crc32();
  test_popcnt();

  // Summary
  print("\n");
  print_int(test_num);
  print(" tests, ");
  print_int(fail_count);
  print(" failures\n");

  syscall1(60, fail_count);
}

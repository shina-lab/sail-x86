// Legacy SSE2 integer arithmetic, compare, logical, and shift tests.
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

typedef int v4si __attribute__((vector_size(16)));
typedef long long v2di __attribute__((vector_size(16)));
typedef short v8hi __attribute__((vector_size(16)));
typedef unsigned char v16qi __attribute__((vector_size(16)));

#define BARRIER(x) __asm__ volatile("" : "+x"(x))

// =========================================================================
// SSE2 integer arithmetic — byte
// =========================================================================

static void test_paddb(void) {
  v16qi a = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  v16qi b = {16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("paddb %1, %0" : "+x"(a) : "x"(b));
  int pass = 1;
  for (int i = 0; i < 16; i++) if (a[i] != 17) pass = 0;
  check(pass, "paddb");
}

static void test_psubb(void) {
  v16qi a = {20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20};
  v16qi b = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("psubb %1, %0" : "+x"(a) : "x"(b));
  int pass = 1;
  for (int i = 0; i < 16; i++) if (a[i] != (u8)(20 - (i+1))) pass = 0;
  check(pass, "psubb");
}

static void test_paddsb(void) {
  v16qi a = {120, 120, 0, 0, 0,0,0,0,0,0,0,0,0,0,0,0};
  v16qi b = {10, 200, 0, 0, 0,0,0,0,0,0,0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("paddsb %1, %0" : "+x"(a) : "x"(b));
  // 120+10=130 -> clamp to 127 (signed byte)
  check((signed char)a[0] == 127, "paddsb (saturate)");
}

static void test_paddusb(void) {
  v16qi a = {250, 100, 0, 0, 0,0,0,0,0,0,0,0,0,0,0,0};
  v16qi b = {10, 10, 0, 0, 0,0,0,0,0,0,0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("paddusb %1, %0" : "+x"(a) : "x"(b));
  // 250+10=260 -> clamp to 255 (unsigned byte)
  check(a[0] == 255 && a[1] == 110, "paddusb (saturate)");
}

static void test_psubusb(void) {
  v16qi a = {5, 100, 0, 0, 0,0,0,0,0,0,0,0,0,0,0,0};
  v16qi b = {10, 10, 0, 0, 0,0,0,0,0,0,0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("psubusb %1, %0" : "+x"(a) : "x"(b));
  // 5-10 -> clamp to 0 (unsigned)
  check(a[0] == 0 && a[1] == 90, "psubusb (saturate)");
}

static void test_pavgb(void) {
  v16qi a = {10, 20, 0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  v16qi b = {20, 30, 0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pavgb %1, %0" : "+x"(a) : "x"(b));
  // avg(10,20) = 15, avg(20,30) = 25
  check(a[0] == 15 && a[1] == 25, "pavgb");
}

static void test_pmaxub(void) {
  v16qi a = {10, 200, 0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  v16qi b = {20, 100, 0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pmaxub %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 20 && a[1] == 200, "pmaxub");
}

static void test_pminub(void) {
  v16qi a = {10, 200, 0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  v16qi b = {20, 100, 0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pminub %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 10 && a[1] == 100, "pminub");
}

// =========================================================================
// SSE2 integer arithmetic — word (16-bit)
// =========================================================================

static void test_paddw(void) {
  v8hi a = {100, 200, 300, 400, 500, 600, 700, 800};
  v8hi b = {1, 2, 3, 4, 5, 6, 7, 8};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("paddw %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 101 && a[1] == 202 && a[2] == 303 && a[3] == 404 &&
        a[4] == 505 && a[5] == 606 && a[6] == 707 && a[7] == 808,
        "paddw");
}

static void test_psubw(void) {
  v8hi a = {100, 200, 300, 400, 500, 600, 700, 800};
  v8hi b = {1, 2, 3, 4, 5, 6, 7, 8};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("psubw %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 99 && a[1] == 198 && a[2] == 297 && a[3] == 396 &&
        a[4] == 495 && a[5] == 594 && a[6] == 693 && a[7] == 792,
        "psubw");
}

static void test_pmullw(void) {
  v8hi a = {10, 20, 30, 40, 50, 60, 70, 80};
  v8hi b = {2, 3, 4, 5, 6, 7, 8, 9};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pmullw %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 20 && a[1] == 60 && a[2] == 120 && a[3] == 200 &&
        a[4] == 300 && a[5] == 420 && a[6] == 560 && a[7] == 720,
        "pmullw");
}

static void test_pmulhw(void) {
  v8hi a = {(short)0x4000, 0, 0, 0, 0, 0, 0, 0};
  v8hi b = {4, 0, 0, 0, 0, 0, 0, 0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pmulhw %1, %0" : "+x"(a) : "x"(b));
  // 0x4000 * 4 = 0x10000, high word = 1
  check(a[0] == 1, "pmulhw");
}

static void test_pmulhuw(void) {
  v8hi a = {(short)0x8000, 0, 0, 0, 0, 0, 0, 0};
  v8hi b = {2, 0, 0, 0, 0, 0, 0, 0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pmulhuw %1, %0" : "+x"(a) : "x"(b));
  // 0x8000 * 2 = 0x10000, high word = 1
  check(a[0] == 1, "pmulhuw");
}

static void test_paddsw(void) {
  v8hi a = {32000, -32000, 0,0,0,0,0,0};
  v8hi b = {1000, -1000, 0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("paddsw %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 32767 && a[1] == -32768, "paddsw (saturate)");
}

static void test_paddusw(void) {
  v8hi a = {(short)0xFFF0, 100, 0,0,0,0,0,0};
  v8hi b = {(short)0x0020, 200, 0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("paddusw %1, %0" : "+x"(a) : "x"(b));
  check((u16)a[0] == 0xFFFF && (u16)a[1] == 300, "paddusw (saturate)");
}

static void test_pmaxsw(void) {
  v8hi a = {-10, 200, 0,0,0,0,0,0};
  v8hi b = {10, 100, 0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pmaxsw %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 10 && a[1] == 200, "pmaxsw");
}

static void test_pminsw(void) {
  v8hi a = {-10, 200, 0,0,0,0,0,0};
  v8hi b = {10, 100, 0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pminsw %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == -10 && a[1] == 100, "pminsw");
}

static void test_pavgw(void) {
  v8hi a = {10, 20, 0,0,0,0,0,0};
  v8hi b = {20, 30, 0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pavgw %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 15 && a[1] == 25, "pavgw");
}

static void test_pmaddwd(void) {
  v8hi a = {1, 2, 3, 4, 5, 6, 7, 8};
  v8hi b = {10, 20, 30, 40, 50, 60, 70, 80};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pmaddwd %1, %0" : "+x"(a) : "x"(b));
  v4si r;
  __builtin_memcpy(&r, &a, 16);
  // r[0] = 1*10 + 2*20 = 50, r[1] = 3*30 + 4*40 = 250, etc.
  check(r[0] == 50 && r[1] == 250 && r[2] == 610 && r[3] == 1130, "pmaddwd");
}

static void test_psadbw(void) {
  v16qi a = {10, 20, 30, 40, 50, 60, 70, 80, 1, 2, 3, 4, 5, 6, 7, 8};
  v16qi b = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("psadbw %1, %0" : "+x"(a) : "x"(b));
  v2di r;
  __builtin_memcpy(&r, &a, 16);
  // Low: |10|+|20|+...+|80| = 360
  // High: |1|+|2|+...+|8| = 36
  check(r[0] == 360 && r[1] == 36, "psadbw");
}

// =========================================================================
// SSE2 integer arithmetic — dword (32-bit)
// =========================================================================

static void test_paddd(void) {
  v4si a = {100, 200, 300, 400};
  v4si b = {1, 2, 3, 4};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("paddd %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 101 && a[1] == 202 && a[2] == 303 && a[3] == 404, "paddd");
}

static void test_psubd(void) {
  v4si a = {100, 200, 300, 400};
  v4si b = {1, 2, 3, 4};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("psubd %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 99 && a[1] == 198 && a[2] == 297 && a[3] == 396, "psubd");
}

static void test_pmuludq(void) {
  v4si a = {3, 0, 7, 0};
  v4si b = {5, 0, 11, 0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pmuludq %1, %0" : "+x"(a) : "x"(b));
  v2di r;
  __builtin_memcpy(&r, &a, 16);
  // Multiplies a[0]*b[0] -> r[0], a[2]*b[2] -> r[1]
  check(r[0] == 15 && r[1] == 77, "pmuludq");
}

// =========================================================================
// SSE2 integer arithmetic — qword (64-bit)
// =========================================================================

static void test_paddq(void) {
  v2di a = {1000000000LL, 2000000000LL};
  v2di b = {3000000000LL, 4000000000LL};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("paddq %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 4000000000LL && a[1] == 6000000000LL, "paddq");
}

static void test_psubq(void) {
  v2di a = {5000000000LL, 7000000000LL};
  v2di b = {1000000000LL, 2000000000LL};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("psubq %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 4000000000LL && a[1] == 5000000000LL, "psubq");
}

// =========================================================================
// SSE2 compare
// =========================================================================

static void test_pcmpeqb(void) {
  v16qi a = {1,2,3,4, 5,6,7,8, 9,10,11,12, 13,14,15,16};
  v16qi b = {1,0,3,0, 5,0,7,0, 9,0,11,0, 13,0,15,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pcmpeqb %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 0xFF && a[1] == 0x00 && a[2] == 0xFF && a[3] == 0x00 &&
        a[4] == 0xFF && a[5] == 0x00,
        "pcmpeqb");
}

static void test_pcmpeqw(void) {
  v8hi a = {100, 200, 300, 400, 500, 600, 700, 800};
  v8hi b = {100, 0, 300, 0, 500, 0, 700, 0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pcmpeqw %1, %0" : "+x"(a) : "x"(b));
  check((u16)a[0] == 0xFFFF && a[1] == 0 &&
        (u16)a[2] == 0xFFFF && a[3] == 0,
        "pcmpeqw");
}

static void test_pcmpeqd(void) {
  v4si a = {100, 200, 300, 400};
  v4si b = {100, 0, 300, 0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pcmpeqd %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == (int)0xFFFFFFFF && a[1] == 0 &&
        a[2] == (int)0xFFFFFFFF && a[3] == 0,
        "pcmpeqd");
}

static void test_pcmpgtb(void) {
  v16qi a = {10, 5, 10, 5, 0,0,0,0,0,0,0,0,0,0,0,0};
  v16qi b = {5, 10, 10, 10, 0,0,0,0,0,0,0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pcmpgtb %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 0xFF && a[1] == 0x00 && a[2] == 0x00 && a[3] == 0x00,
        "pcmpgtb");
}

static void test_pcmpgtw(void) {
  v8hi a = {100, 50, 100, 50, 0,0,0,0};
  v8hi b = {50, 100, 100, 100, 0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pcmpgtw %1, %0" : "+x"(a) : "x"(b));
  check((u16)a[0] == 0xFFFF && a[1] == 0 && a[2] == 0 && a[3] == 0,
        "pcmpgtw");
}

static void test_pcmpgtd(void) {
  v4si a = {100, 50, 100, 50};
  v4si b = {50, 100, 100, 100};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pcmpgtd %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == (int)0xFFFFFFFF && a[1] == 0 && a[2] == 0 && a[3] == 0,
        "pcmpgtd");
}

// =========================================================================
// SSE2 logical
// =========================================================================

static void test_pand(void) {
  v4si a = {(int)0xFF00FF00, 0x0F0F0F0F, (int)0xAAAAAAAA, 0x55555555};
  v4si b = {(int)0xFFFFFFFF, (int)0xFFFFFFFF, (int)0xFFFFFFFF, (int)0xFFFFFFFF};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pand %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == (int)0xFF00FF00 && a[1] == 0x0F0F0F0F &&
        a[2] == (int)0xAAAAAAAA && a[3] == 0x55555555,
        "pand");
}

static void test_pandn(void) {
  v4si a = {(int)0xFFFFFFFF, 0, (int)0xFFFFFFFF, 0};
  v4si b = {0x12345678, 0x12345678, 0x12345678, 0x12345678};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("pandn %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 0 && a[1] == 0x12345678 &&
        a[2] == 0 && a[3] == 0x12345678,
        "pandn");
}

static void test_por(void) {
  v4si a = {(int)0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF};
  v4si b = {0x000000FF, 0x0000FF00, 0x00FF0000, (int)0xFF000000};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("por %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == (int)0xFF0000FF && a[1] == (int)0x00FFFF00 &&
        a[2] == (int)0x00FFFF00 && a[3] == (int)0xFF0000FF,
        "por");
}

static void test_pxor(void) {
  v4si a = {(int)0xDEADBEEF, (int)0xCAFEBABE, 0x12345678, (int)0xABCDEF01};
  BARRIER(a);
  __asm__ volatile("pxor %1, %0" : "+x"(a) : "x"(a));
  check(a[0] == 0 && a[1] == 0 && a[2] == 0 && a[3] == 0,
        "pxor (self = zero)");
}

// =========================================================================
// SSE2 shifts
// =========================================================================

static void test_psllw(void) {
  v8hi a = {1, 2, 4, 8, 16, 32, 64, 128};
  BARRIER(a);
  __asm__ volatile("psllw $1, %0" : "+x"(a));
  check(a[0] == 2 && a[1] == 4 && a[2] == 8 && a[3] == 16 &&
        a[4] == 32 && a[5] == 64 && a[6] == 128 && a[7] == 256,
        "psllw $1");
}

static void test_psrlw(void) {
  v8hi a = {2, 4, 8, 16, 32, 64, 128, 256};
  BARRIER(a);
  __asm__ volatile("psrlw $1, %0" : "+x"(a));
  check(a[0] == 1 && a[1] == 2 && a[2] == 4 && a[3] == 8 &&
        a[4] == 16 && a[5] == 32 && a[6] == 64 && a[7] == 128,
        "psrlw $1");
}

static void test_psraw(void) {
  v8hi a = {-16, 16, -32, 32, 0,0,0,0};
  BARRIER(a);
  __asm__ volatile("psraw $1, %0" : "+x"(a));
  check(a[0] == -8 && a[1] == 8 && a[2] == -16 && a[3] == 16,
        "psraw $1");
}

static void test_pslld(void) {
  v4si a = {1, 2, 4, 8};
  BARRIER(a);
  __asm__ volatile("pslld $4, %0" : "+x"(a));
  check(a[0] == 16 && a[1] == 32 && a[2] == 64 && a[3] == 128, "pslld $4");
}

static void test_psrld(void) {
  v4si a = {16, 32, 64, 128};
  BARRIER(a);
  __asm__ volatile("psrld $4, %0" : "+x"(a));
  check(a[0] == 1 && a[1] == 2 && a[2] == 4 && a[3] == 8, "psrld $4");
}

static void test_psrad(void) {
  v4si a = {-16, 16, -32, 32};
  BARRIER(a);
  __asm__ volatile("psrad $1, %0" : "+x"(a));
  check(a[0] == -8 && a[1] == 8 && a[2] == -16 && a[3] == 16, "psrad $1");
}

static void test_psllq(void) {
  v2di a = {1, 2};
  BARRIER(a);
  __asm__ volatile("psllq $4, %0" : "+x"(a));
  check(a[0] == 16 && a[1] == 32, "psllq $4");
}

static void test_psrlq(void) {
  v2di a = {16, 32};
  BARRIER(a);
  __asm__ volatile("psrlq $4, %0" : "+x"(a));
  check(a[0] == 1 && a[1] == 2, "psrlq $4");
}

static void test_pslldq(void) {
  v16qi a = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  BARRIER(a);
  __asm__ volatile("pslldq $1, %0" : "+x"(a));
  // Byte shift left by 1: insert zero at byte 0, shift all up
  check(a[0] == 0 && a[1] == 1 && a[2] == 2 && a[15] == 15,
        "pslldq $1");
}

static void test_psrldq(void) {
  v16qi a = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  BARRIER(a);
  __asm__ volatile("psrldq $1, %0" : "+x"(a));
  // Byte shift right by 1: insert zero at byte 15, shift all down
  check(a[0] == 2 && a[1] == 3 && a[14] == 16 && a[15] == 0,
        "psrldq $1");
}

// Variable shifts — right shifts (shift count in XMM register)
static void test_psrlw_xmm(void) {
  v8hi a = {4, 8, 16, 32, 64, 128, 256, 512};
  v2di cnt = {2, 0};
  BARRIER(a); BARRIER(cnt);
  __asm__ volatile("psrlw %1, %0" : "+x"(a) : "x"(cnt));
  check(a[0] == 1 && a[1] == 2 && a[2] == 4 && a[3] == 8,
        "psrlw xmm (count=2)");
}

static void test_psrld_xmm(void) {
  v4si a = {8, 16, 32, 64};
  v2di cnt = {3, 0};
  BARRIER(a); BARRIER(cnt);
  __asm__ volatile("psrld %1, %0" : "+x"(a) : "x"(cnt));
  check(a[0] == 1 && a[1] == 2 && a[2] == 4 && a[3] == 8,
        "psrld xmm (count=3)");
}

static void test_psrlq_xmm(void) {
  v2di a = {32, 64};
  v2di cnt = {5, 0};
  BARRIER(a); BARRIER(cnt);
  __asm__ volatile("psrlq %1, %0" : "+x"(a) : "x"(cnt));
  check(a[0] == 1 && a[1] == 2, "psrlq xmm (count=5)");
}

static void test_psraw_xmm(void) {
  v8hi a = {-16, 16, -32, 32, 0,0,0,0};
  v2di cnt = {1, 0};
  BARRIER(a); BARRIER(cnt);
  __asm__ volatile("psraw %1, %0" : "+x"(a) : "x"(cnt));
  check(a[0] == -8 && a[1] == 8 && a[2] == -16 && a[3] == 16,
        "psraw xmm (count=1)");
}

static void test_psrad_xmm(void) {
  v4si a = {-16, 16, -32, 32};
  v2di cnt = {1, 0};
  BARRIER(a); BARRIER(cnt);
  __asm__ volatile("psrad %1, %0" : "+x"(a) : "x"(cnt));
  check(a[0] == -8 && a[1] == 8 && a[2] == -16 && a[3] == 16,
        "psrad xmm (count=1)");
}

// Saturating sub
static void test_psubsb(void) {
  v16qi a = {(u8)-120, 120, 0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  v16qi b = {10, (u8)-10, 0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("psubsb %1, %0" : "+x"(a) : "x"(b));
  // -120 - 10 = -130 -> clamp to -128
  // 120 - (-10) = 130 -> clamp to 127
  check((signed char)a[0] == -128 && (signed char)a[1] == 127, "psubsb (saturate)");
}

static void test_psubsw(void) {
  v8hi a = {-32000, 32000, 0,0,0,0,0,0};
  v8hi b = {1000, -1000, 0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("psubsw %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == -32768 && a[1] == 32767, "psubsw (saturate)");
}

static void test_psubusw(void) {
  v8hi a = {5, 1000, 0,0,0,0,0,0};
  v8hi b = {10, 10, 0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("psubusw %1, %0" : "+x"(a) : "x"(b));
  // 5-10 unsigned -> clamp to 0
  check((u16)a[0] == 0 && (u16)a[1] == 990, "psubusw (saturate)");
}

// Variable shifts — left shifts (shift count in XMM register)
static void test_psllw_xmm(void) {
  v8hi a = {1, 2, 4, 8, 16, 32, 64, 128};
  v2di cnt = {2, 0};
  BARRIER(a); BARRIER(cnt);
  __asm__ volatile("psllw %1, %0" : "+x"(a) : "x"(cnt));
  check(a[0] == 4 && a[1] == 8 && a[2] == 16 && a[3] == 32,
        "psllw xmm (count=2)");
}

static void test_pslld_xmm(void) {
  v4si a = {1, 2, 4, 8};
  v2di cnt = {3, 0};
  BARRIER(a); BARRIER(cnt);
  __asm__ volatile("pslld %1, %0" : "+x"(a) : "x"(cnt));
  check(a[0] == 8 && a[1] == 16 && a[2] == 32 && a[3] == 64,
        "pslld xmm (count=3)");
}

static void test_psllq_xmm(void) {
  v2di a = {1, 2};
  v2di cnt = {5, 0};
  BARRIER(a); BARRIER(cnt);
  __asm__ volatile("psllq %1, %0" : "+x"(a) : "x"(cnt));
  check(a[0] == 32 && a[1] == 64, "psllq xmm (count=5)");
}

// =========================================================================
// SSE2 pack / unpack
// =========================================================================

static void test_packsswb(void) {
  v8hi a = {0, 127, 128, -1, -128, -129, 0, 0};
  v8hi b = {1, 2, 3, 4, 5, 6, 7, 8};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("packsswb %1, %0" : "+x"(a) : "x"(b));
  v16qi r;
  __builtin_memcpy(&r, &a, 16);
  // Pack with signed saturation: 0, 127, 127(clamp), -1, -128, -128(clamp), 0, 0, 1..8
  check((signed char)r[0] == 0 && (signed char)r[1] == 127 &&
        (signed char)r[2] == 127 && (signed char)r[3] == -1 &&
        (signed char)r[4] == -128 && (signed char)r[5] == -128,
        "packsswb");
}

static void test_packssdw(void) {
  v4si a = {0, 32767, 32768, -32769};
  v4si b = {1, 2, 3, 4};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("packssdw %1, %0" : "+x"(a) : "x"(b));
  v8hi r;
  __builtin_memcpy(&r, &a, 16);
  check(r[0] == 0 && r[1] == 32767 && r[2] == 32767 && r[3] == -32768 &&
        r[4] == 1 && r[5] == 2 && r[6] == 3 && r[7] == 4,
        "packssdw");
}

static void test_packuswb(void) {
  v8hi a = {0, 255, 256, -1, 0, 0, 0, 0};
  v8hi b = {1, 2, 3, 4, 5, 6, 7, 8};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("packuswb %1, %0" : "+x"(a) : "x"(b));
  v16qi r;
  __builtin_memcpy(&r, &a, 16);
  // Unsigned saturation: 0, 255, 255(clamp), 0(clamp), ...
  check(r[0] == 0 && r[1] == 255 && r[2] == 255 && r[3] == 0,
        "packuswb");
}

// =========================================================================
// SSE2 movq, movd
// =========================================================================

static void test_movd_to_xmm(void) {
  int val = 0x12345678;
  v4si r;
  __asm__ volatile("movd %1, %0" : "=x"(r) : "r"(val));
  check(r[0] == 0x12345678 && r[1] == 0 && r[2] == 0 && r[3] == 0,
        "movd gpr->xmm");
}

static void test_movd_from_xmm(void) {
  v4si a = {0x12345678, 0xAAAAAAAA, 0xBBBBBBBB, 0xCCCCCCCC};
  int r;
  BARRIER(a);
  __asm__ volatile("movd %1, %0" : "=r"(r) : "x"(a));
  check(r == 0x12345678, "movd xmm->gpr");
}

static void test_movq_to_xmm(void) {
  long long val = 0x123456789ABCDEF0LL;
  v2di r;
  __asm__ volatile("movq %1, %0" : "=x"(r) : "r"(val));
  check(r[0] == 0x123456789ABCDEF0LL && r[1] == 0, "movq gpr->xmm");
}

static void test_movq_from_xmm(void) {
  v2di a = {0x123456789ABCDEF0LL, (long long)0xAAAAAAAABBBBBBBBLL};
  long long r;
  BARRIER(a);
  __asm__ volatile("movq %1, %0" : "=r"(r) : "x"(a));
  check(r == 0x123456789ABCDEF0LL, "movq xmm->gpr");
}

static void test_pmovmskb(void) {
  v16qi a = {0x80, 0x00, 0x80, 0x00, 0x80, 0x00, 0x80, 0x00,
             0x80, 0x00, 0x80, 0x00, 0x80, 0x00, 0x80, 0x00};
  int r;
  BARRIER(a);
  __asm__ volatile("pmovmskb %1, %0" : "=r"(r) : "x"(a));
  // Sign bits at even positions: 0x5555
  check(r == 0x5555, "pmovmskb");
}

// =========================================================================
// Entry point
// =========================================================================

void __attribute__((force_align_arg_pointer)) _start(void) {
  // Byte arithmetic
  test_paddb();
  test_psubb();
  test_paddsb();
  test_paddusb();
  test_psubusb();
  test_pavgb();
  test_pmaxub();
  test_pminub();

  // Word arithmetic
  test_paddw();
  test_psubw();
  test_pmullw();
  test_pmulhw();
  test_pmulhuw();
  test_paddsw();
  test_paddusw();
  test_pmaxsw();
  test_pminsw();
  test_pavgw();
  test_pmaddwd();
  test_psadbw();

  // Dword arithmetic
  test_paddd();
  test_psubd();
  test_pmuludq();

  // Qword arithmetic
  test_paddq();
  test_psubq();

  // Compare
  test_pcmpeqb();
  test_pcmpeqw();
  test_pcmpeqd();
  test_pcmpgtb();
  test_pcmpgtw();
  test_pcmpgtd();

  // Logical
  test_pand();
  test_pandn();
  test_por();
  test_pxor();

  // Shifts (immediate)
  test_psllw();
  test_psrlw();
  test_psraw();
  test_pslld();
  test_psrld();
  test_psrad();
  test_psllq();
  test_psrlq();
  test_pslldq();
  test_psrldq();

  // Shifts (xmm count)
  test_psllw_xmm();
  test_pslld_xmm();
  test_psllq_xmm();
  test_psrlw_xmm();
  test_psrld_xmm();
  test_psrlq_xmm();
  test_psraw_xmm();
  test_psrad_xmm();

  // Saturating sub
  test_psubsb();
  test_psubsw();
  test_psubusw();

  // Pack
  test_packsswb();
  test_packssdw();
  test_packuswb();

  // Mov
  test_movd_to_xmm();
  test_movd_from_xmm();
  test_movq_to_xmm();
  test_movq_from_xmm();
  test_pmovmskb();

  // Summary
  print("\n");
  print_int(test_num);
  print(" tests, ");
  print_int(fail_count);
  print(" failures\n");

  syscall1(60, fail_count);
}

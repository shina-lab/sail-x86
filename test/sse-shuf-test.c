// Legacy SSE2 shuffle/unpack, data movement, insert/extract tests.
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

typedef float v4sf __attribute__((vector_size(16)));
typedef double v2df __attribute__((vector_size(16)));
typedef int v4si __attribute__((vector_size(16)));
typedef long long v2di __attribute__((vector_size(16)));
typedef short v8hi __attribute__((vector_size(16)));
typedef unsigned char v16qi __attribute__((vector_size(16)));

#define BARRIER(x) __asm__ volatile("" : "+x"(x))

// =========================================================================
// SSE2 shuffle
// =========================================================================

static void test_pshufd(void) {
  v4si a = {1, 2, 3, 4};
  v4si r;
  BARRIER(a);
  // imm8 = 0x1B = 0b00_01_10_11 -> {a[3], a[2], a[1], a[0]}
  __asm__ volatile("pshufd $0x1B, %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 4 && r[1] == 3 && r[2] == 2 && r[3] == 1,
        "pshufd $0x1B (reverse)");
}

static void test_pshufd_broadcast(void) {
  v4si a = {42, 0, 0, 0};
  v4si r;
  BARRIER(a);
  // imm8 = 0x00 -> all lanes = a[0]
  __asm__ volatile("pshufd $0x00, %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 42 && r[1] == 42 && r[2] == 42 && r[3] == 42,
        "pshufd $0x00 (broadcast)");
}

static void test_pshuflw(void) {
  v8hi a = {10, 20, 30, 40, 50, 60, 70, 80};
  v8hi r;
  BARRIER(a);
  // imm8 = 0x1B reverses low 4 words, high 4 unchanged
  __asm__ volatile("pshuflw $0x1B, %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 40 && r[1] == 30 && r[2] == 20 && r[3] == 10 &&
        r[4] == 50 && r[5] == 60 && r[6] == 70 && r[7] == 80,
        "pshuflw $0x1B");
}

static void test_pshufhw(void) {
  v8hi a = {10, 20, 30, 40, 50, 60, 70, 80};
  v8hi r;
  BARRIER(a);
  // imm8 = 0x1B reverses high 4 words, low 4 unchanged
  __asm__ volatile("pshufhw $0x1B, %1, %0" : "=x"(r) : "x"(a));
  check(r[0] == 10 && r[1] == 20 && r[2] == 30 && r[3] == 40 &&
        r[4] == 80 && r[5] == 70 && r[6] == 60 && r[7] == 50,
        "pshufhw $0x1B");
}

// =========================================================================
// SSE2 unpack integer
// =========================================================================

static void test_punpcklbw(void) {
  v16qi a = {1,2,3,4,5,6,7,8, 0,0,0,0,0,0,0,0};
  v16qi b = {11,12,13,14,15,16,17,18, 0,0,0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("punpcklbw %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 1 && a[1] == 11 && a[2] == 2 && a[3] == 12 &&
        a[4] == 3 && a[5] == 13 && a[6] == 4 && a[7] == 14 &&
        a[8] == 5 && a[9] == 15 && a[10] == 6 && a[11] == 16,
        "punpcklbw");
}

static void test_punpckhbw(void) {
  v16qi a = {0,0,0,0,0,0,0,0, 1,2,3,4,5,6,7,8};
  v16qi b = {0,0,0,0,0,0,0,0, 11,12,13,14,15,16,17,18};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("punpckhbw %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 1 && a[1] == 11 && a[2] == 2 && a[3] == 12 &&
        a[4] == 3 && a[5] == 13 && a[6] == 4 && a[7] == 14,
        "punpckhbw");
}

static void test_punpcklwd(void) {
  v8hi a = {1, 2, 3, 4, 0, 0, 0, 0};
  v8hi b = {11, 12, 13, 14, 0, 0, 0, 0};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("punpcklwd %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 1 && a[1] == 11 && a[2] == 2 && a[3] == 12 &&
        a[4] == 3 && a[5] == 13 && a[6] == 4 && a[7] == 14,
        "punpcklwd");
}

static void test_punpckhwd(void) {
  v8hi a = {0, 0, 0, 0, 1, 2, 3, 4};
  v8hi b = {0, 0, 0, 0, 11, 12, 13, 14};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("punpckhwd %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 1 && a[1] == 11 && a[2] == 2 && a[3] == 12 &&
        a[4] == 3 && a[5] == 13 && a[6] == 4 && a[7] == 14,
        "punpckhwd");
}

static void test_punpckldq(void) {
  v4si a = {1, 2, 3, 4};
  v4si b = {11, 12, 13, 14};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("punpckldq %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 1 && a[1] == 11 && a[2] == 2 && a[3] == 12,
        "punpckldq");
}

static void test_punpckhdq(void) {
  v4si a = {1, 2, 3, 4};
  v4si b = {11, 12, 13, 14};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("punpckhdq %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 3 && a[1] == 13 && a[2] == 4 && a[3] == 14,
        "punpckhdq");
}

static void test_punpcklqdq(void) {
  v2di a = {1, 2};
  v2di b = {11, 12};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("punpcklqdq %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 1 && a[1] == 11, "punpcklqdq");
}

static void test_punpckhqdq(void) {
  v2di a = {1, 2};
  v2di b = {11, 12};
  BARRIER(a); BARRIER(b);
  __asm__ volatile("punpckhqdq %1, %0" : "+x"(a) : "x"(b));
  check(a[0] == 2 && a[1] == 12, "punpckhqdq");
}

// =========================================================================
// SSE2 data movement — pextrw / pinsrw
// =========================================================================

static void test_pextrw(void) {
  v8hi a = {10, 20, 30, 40, 50, 60, 70, 80};
  int r;
  BARRIER(a);
  __asm__ volatile("pextrw $3, %1, %0" : "=r"(r) : "x"(a));
  check(r == 40, "pextrw $3");
}

static void test_pinsrw(void) {
  v8hi a = {10, 20, 30, 40, 50, 60, 70, 80};
  int val = 999;
  BARRIER(a);
  __asm__ volatile("pinsrw $2, %1, %0" : "+x"(a) : "r"(val));
  check(a[0] == 10 && a[1] == 20 && a[2] == 999 && a[3] == 40 &&
        a[4] == 50 && a[5] == 60 && a[6] == 70 && a[7] == 80,
        "pinsrw $2");
}

// =========================================================================
// SSE2 maskmovdqu
// =========================================================================

static void test_maskmovdqu(void) {
  // maskmovdqu writes bytes where mask high bit is set
  v16qi data = {0xAA, 0xBB, 0xCC, 0xDD, 0,0,0,0,0,0,0,0,0,0,0,0};
  v16qi mask = {0x80, 0x80, 0x00, 0x80, 0,0,0,0,0,0,0,0,0,0,0,0};
  unsigned char buf[16] __attribute__((aligned(16))) = {0};
  BARRIER(data); BARRIER(mask);
  __asm__ volatile("maskmovdqu %1, %0"
                   : : "x"(data), "x"(mask), "D"(buf) : "memory");
  check(buf[0] == 0xAA && buf[1] == 0xBB && buf[2] == 0x00 && buf[3] == 0xDD,
        "maskmovdqu");
}

// =========================================================================
// Entry point
// =========================================================================

void __attribute__((force_align_arg_pointer)) _start(void) {
  // Shuffle
  test_pshufd();
  test_pshufd_broadcast();
  test_pshuflw();
  test_pshufhw();

  // Unpack integer
  test_punpcklbw();
  test_punpckhbw();
  test_punpcklwd();
  test_punpckhwd();
  test_punpckldq();
  test_punpckhdq();
  test_punpcklqdq();
  test_punpckhqdq();

  // Data movement
  test_pextrw();
  test_pinsrw();

  // Maskmovdqu
  test_maskmovdqu();

  // Summary
  print("\n");
  print_int(test_num);
  print(" tests, ");
  print_int(fail_count);
  print(" failures\n");

  syscall1(60, fail_count);
}

// AVX-512 instruction tests — runs under sail_x86_sim only (not on host).
// Uses EVEX-encoded instructions via inline asm with -mavx512f.
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

typedef float v16sf __attribute__((vector_size(64)));
typedef double v8df __attribute__((vector_size(64)));
typedef int v16si __attribute__((vector_size(64)));
typedef long long v8di __attribute__((vector_size(64)));
typedef short v32hi __attribute__((vector_size(64)));
typedef signed char v64qi __attribute__((vector_size(64)));
typedef unsigned char v64qu __attribute__((vector_size(64)));
typedef unsigned short v32hu __attribute__((vector_size(64)));

#define BARRIER(x) __asm__ volatile("" : "+x"(x))

// =========================================================================
// Tests
// =========================================================================

static void test_vmovups_512(void) {
  v16sf a = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  BARRIER(a);
  v16sf b;
  __asm__ volatile("vmovups %1, %0" : "=x"(b) : "x"(a));
  check(b[0] == 1.0f && b[7] == 8.0f && b[15] == 16.0f,
        "vmovups zmm,zmm");
}

static void test_vmovaps_512(void) {
  v16sf a __attribute__((aligned(64))) = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  v16sf b __attribute__((aligned(64)));
  __asm__ volatile("vmovaps %1, %0" : "=x"(b) : "x"(a));
  check(b[0] == 1.0f && b[15] == 16.0f, "vmovaps zmm,zmm");
}

static void test_vaddps_512(void) {
  v16sf a = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  v16sf b = {16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1};
  BARRIER(a); BARRIER(b);
  v16sf c;
  __asm__ volatile("vaddps %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // All elements should be 17
  int ok_flag = 1;
  for (int i = 0; i < 16; i++)
    if (c[i] != 17.0f) ok_flag = 0;
  check(ok_flag, "vaddps zmm");
}

static void test_vsubps_512(void) {
  v16sf a = {10,20,30,40,50,60,70,80,90,100,110,120,130,140,150,160};
  v16sf b = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  BARRIER(a); BARRIER(b);
  v16sf c;
  __asm__ volatile("vsubps %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  check(c[0] == 9.0f && c[15] == 144.0f, "vsubps zmm");
}

static void test_vmulps_512(void) {
  v16sf a = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  v16sf b = {2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2};
  BARRIER(a); BARRIER(b);
  v16sf c;
  __asm__ volatile("vmulps %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  check(c[0] == 2.0f && c[7] == 16.0f && c[15] == 32.0f, "vmulps zmm");
}

static void test_vaddpd_512(void) {
  v8df a = {1,2,3,4,5,6,7,8};
  v8df b = {8,7,6,5,4,3,2,1};
  BARRIER(a); BARRIER(b);
  v8df c;
  __asm__ volatile("vaddpd %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  int ok_flag = 1;
  for (int i = 0; i < 8; i++)
    if (c[i] != 9.0) ok_flag = 0;
  check(ok_flag, "vaddpd zmm");
}

static void test_vsubpd_512(void) {
  v8df a = {10,20,30,40,50,60,70,80};
  v8df b = {1,2,3,4,5,6,7,8};
  BARRIER(a); BARRIER(b);
  v8df c;
  __asm__ volatile("vsubpd %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  check(c[0] == 9.0 && c[7] == 72.0, "vsubpd zmm");
}

static void test_vmulpd_512(void) {
  v8df a = {1,2,3,4,5,6,7,8};
  v8df b = {3,3,3,3,3,3,3,3};
  BARRIER(a); BARRIER(b);
  v8df c;
  __asm__ volatile("vmulpd %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  check(c[0] == 3.0 && c[7] == 24.0, "vmulpd zmm");
}

static void test_vpxord_512(void) {
  v16si a = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  BARRIER(a);
  v16si c;
  // XOR with itself should be zero
  __asm__ volatile("vpxord %1, %1, %0" : "=x"(c) : "x"(a));
  int ok_flag = 1;
  for (int i = 0; i < 16; i++)
    if (c[i] != 0) ok_flag = 0;
  check(ok_flag, "vpxord zmm self-xor");
}

static void test_vpandd_512(void) {
  v16si a = {0xFF, 0xFF00, 0xFF0000, 0xFF000000, 0xFF, 0xFF00, 0xFF0000, 0xFF000000,
             0xFF, 0xFF00, 0xFF0000, 0xFF000000, 0xFF, 0xFF00, 0xFF0000, 0xFF000000};
  v16si b = {0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF,
             0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF};
  BARRIER(a); BARRIER(b);
  v16si c;
  __asm__ volatile("vpandd %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  check(c[0] == 0xFF && c[1] == 0xFF00 && c[2] == 0, "vpandd zmm");
}

static void test_vpord_512(void) {
  v16si a = {1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0};
  v16si b = {0,2,0,2,0,2,0,2,0,2,0,2,0,2,0,2};
  BARRIER(a); BARRIER(b);
  v16si c;
  __asm__ volatile("vpord %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  check(c[0] == 1 && c[1] == 2 && c[2] == 1 && c[3] == 2, "vpord zmm");
}

static void test_vpaddd_512(void) {
  v16si a = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  v16si b = {16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1};
  BARRIER(a); BARRIER(b);
  v16si c;
  __asm__ volatile("vpaddd %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  int ok_flag = 1;
  for (int i = 0; i < 16; i++)
    if (c[i] != 17) ok_flag = 0;
  check(ok_flag, "vpaddd zmm");
}

static void test_vpsubd_512(void) {
  v16si a = {10,20,30,40,50,60,70,80,90,100,110,120,130,140,150,160};
  v16si b = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  BARRIER(a); BARRIER(b);
  v16si c;
  __asm__ volatile("vpsubd %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  check(c[0] == 9 && c[15] == 144, "vpsubd zmm");
}

static void test_vpaddq_512(void) {
  v8di a = {1,2,3,4,5,6,7,8};
  v8di b = {8,7,6,5,4,3,2,1};
  BARRIER(a); BARRIER(b);
  v8di c;
  __asm__ volatile("vpaddq %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  int ok_flag = 1;
  for (int i = 0; i < 8; i++)
    if (c[i] != 9) ok_flag = 0;
  check(ok_flag, "vpaddq zmm");
}

static void test_vpsubq_512(void) {
  v8di a = {10,20,30,40,50,60,70,80};
  v8di b = {1,2,3,4,5,6,7,8};
  BARRIER(a); BARRIER(b);
  v8di c;
  __asm__ volatile("vpsubq %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  check(c[0] == 9 && c[7] == 72, "vpsubq zmm");
}

static void test_vmovdqa32_512(void) {
  v16si a __attribute__((aligned(64))) = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  v16si b __attribute__((aligned(64)));
  __asm__ volatile("vmovdqa32 %1, %0" : "=x"(b) : "x"(a));
  check(b[0] == 1 && b[15] == 16, "vmovdqa32 zmm,zmm");
}

// =========================================================================
// Test bitwise: VANDPS, VANDNPS, VORPS, VXORPS (EVEX 512-bit)
// =========================================================================

static void test_vxorps_512(void) {
  v16sf a = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  BARRIER(a);
  v16sf c;
  __asm__ volatile("vxorps %1, %1, %0" : "=x"(c) : "x"(a));
  // XOR with self = 0
  int ok_flag = 1;
  for (int i = 0; i < 16; i++)
    if (c[i] != 0.0f) ok_flag = 0;
  check(ok_flag, "vxorps zmm self-xor");
}

// =========================================================================
// Integer saturating arithmetic tests
// =========================================================================

static void test_vpaddsb_512(void) {
  v64qi a, b, c;
  for (int i = 0; i < 64; i++) { a[i] = 100; b[i] = 50; }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpaddsb %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // 100 + 50 = 150 > 127 → saturate to 127
  check(c[0] == 127 && c[63] == 127, "vpaddsb zmm saturate");
}

static void test_vpsubsb_512(void) {
  v64qi a, b, c;
  for (int i = 0; i < 64; i++) { a[i] = -100; b[i] = 50; }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpsubsb %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // -100 - 50 = -150 < -128 → saturate to -128
  check(c[0] == -128 && c[63] == -128, "vpsubsb zmm saturate");
}

static void test_vpaddusb_512(void) {
  v64qu a, b, c;
  for (int i = 0; i < 64; i++) { a[i] = 200; b[i] = 100; }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpaddusb %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // 200 + 100 = 300 > 255 → saturate to 255
  check(c[0] == 255 && c[63] == 255, "vpaddusb zmm saturate");
}

static void test_vpsubusb_512(void) {
  v64qu a, b, c;
  for (int i = 0; i < 64; i++) { a[i] = 10; b[i] = 50; }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpsubusb %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // 10 - 50 = -40 < 0 → saturate to 0
  check(c[0] == 0 && c[63] == 0, "vpsubusb zmm saturate");
}

static void test_vpaddw_512(void) {
  v32hi a, b, c;
  for (int i = 0; i < 32; i++) { a[i] = i; b[i] = 100; }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpaddw %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  check(c[0] == 100 && c[31] == 131, "vpaddw zmm");
}

static void test_vpsubw_512(void) {
  v32hi a, b, c;
  for (int i = 0; i < 32; i++) { a[i] = 200; b[i] = i; }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpsubw %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  check(c[0] == 200 && c[31] == 169, "vpsubw zmm");
}

static void test_vpmullw_512(void) {
  v32hi a, b, c;
  for (int i = 0; i < 32; i++) { a[i] = 7; b[i] = 6; }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpmullw %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  check(c[0] == 42 && c[31] == 42, "vpmullw zmm");
}

static void test_vpmaxub_512(void) {
  v64qu a, b, c;
  for (int i = 0; i < 64; i++) { a[i] = (unsigned char)i; b[i] = 32; }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpmaxub %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  check(c[0] == 32 && c[32] == 32 && c[63] == 63, "vpmaxub zmm");
}

static void test_vpminsw_512(void) {
  v32hi a, b, c;
  for (int i = 0; i < 32; i++) { a[i] = (short)(i - 16); b[i] = 0; }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpminsw %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // a[0]=-16, b[0]=0 → min=-16; a[16]=0, b[16]=0 → 0; a[31]=15, b[31]=0 → 0
  check(c[0] == -16 && c[16] == 0 && c[31] == 0, "vpminsw zmm");
}

static void test_vpavgb_512(void) {
  v64qu a, b, c;
  for (int i = 0; i < 64; i++) { a[i] = 10; b[i] = 20; }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpavgb %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // (10 + 20 + 1) / 2 = 15 (rounded)
  check(c[0] == 15 && c[63] == 15, "vpavgb zmm");
}

static void test_vpmuludq_512(void) {
  v8di a, b, c;
  // Put values in low 32 bits of each qword lane
  for (int i = 0; i < 8; i++) { a[i] = 100000; b[i] = 200000; }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpmuludq %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // 100000 * 200000 = 20000000000
  check(c[0] == 20000000000LL && c[7] == 20000000000LL, "vpmuludq zmm");
}

static void test_vpmaddwd_512(void) {
  v32hi a, b;
  v16si c;
  for (int i = 0; i < 32; i++) { a[i] = 3; b[i] = 4; }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpmaddwd %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // Each dword = 3*4 + 3*4 = 24
  check(c[0] == 24 && c[15] == 24, "vpmaddwd zmm");
}

static void test_vpsadbw_512(void) {
  v64qu a, b;
  v8di c;
  for (int i = 0; i < 64; i++) { a[i] = 10; b[i] = 5; }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpsadbw %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // Each 8-byte group: 8 * |10-5| = 40
  check(c[0] == 40 && c[7] == 40, "vpsadbw zmm");
}

static void test_vsqrtps_512(void) {
  v16sf a = {4,9,16,25,36,49,64,81,100,121,144,169,196,225,256,289};
  BARRIER(a);
  v16sf c;
  __asm__ volatile("vsqrtps %1, %0" : "=x"(c) : "x"(a));
  check(c[0] == 2.0f && c[1] == 3.0f && c[15] == 17.0f, "vsqrtps zmm");
}

static void test_vdivps_512(void) {
  v16sf a = {10,20,30,40,50,60,70,80,90,100,110,120,130,140,150,160};
  v16sf b = {2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2};
  BARRIER(a); BARRIER(b);
  v16sf c;
  __asm__ volatile("vdivps %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  check(c[0] == 5.0f && c[15] == 80.0f, "vdivps zmm");
}

static void test_vminps_512(void) {
  v16sf a = {1,20,3,40,5,60,7,80,9,100,11,120,13,140,15,160};
  v16sf b = {10,2,30,4,50,6,70,8,90,10,110,12,130,14,150,16};
  BARRIER(a); BARRIER(b);
  v16sf c;
  __asm__ volatile("vminps %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  check(c[0] == 1.0f && c[1] == 2.0f && c[14] == 15.0f && c[15] == 16.0f, "vminps zmm");
}

static void test_vmaxps_512(void) {
  v16sf a = {1,20,3,40,5,60,7,80,9,100,11,120,13,140,15,160};
  v16sf b = {10,2,30,4,50,6,70,8,90,10,110,12,130,14,150,16};
  BARRIER(a); BARRIER(b);
  v16sf c;
  __asm__ volatile("vmaxps %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  check(c[0] == 10.0f && c[1] == 20.0f && c[14] == 150.0f && c[15] == 160.0f, "vmaxps zmm");
}

static void test_vpandnd_512(void) {
  v16si a = {-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1};  // all 1s
  v16si b = {0x12345678,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  BARRIER(a); BARRIER(b);
  v16si c;
  __asm__ volatile("vpandnd %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // ~(-1) & 0x12345678 = 0 & 0x12345678 = 0
  check(c[0] == 0, "vpandnd zmm");
}

// =========================================================================
// Pack/Unpack tests
// =========================================================================

static void test_vpunpcklbw_512(void) {
  v64qi a, b, c;
  for (int i = 0; i < 64; i++) { a[i] = i; b[i] = 100 + i; }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpunpcklbw %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // Per 128-bit lane: interleave low 8 bytes
  // Lane 0: a[0],b[0],a[1],b[1],...,a[7],b[7]
  check(c[0] == 0 && c[1] == 100 && c[2] == 1 && c[3] == 101,
        "vpunpcklbw zmm");
}

static void test_vpunpckhbw_512(void) {
  v64qi a, b, c;
  for (int i = 0; i < 64; i++) { a[i] = i; b[i] = 100 + i; }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpunpckhbw %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // Per 128-bit lane: interleave high 8 bytes (bytes 8-15)
  // Lane 0: a[8],b[8],a[9],b[9],...,a[15],b[15]
  check(c[0] == 8 && c[1] == 108 && c[2] == 9 && c[3] == 109,
        "vpunpckhbw zmm");
}

static void test_vpunpckldq_512(void) {
  v16si a = {1,2,3,4, 5,6,7,8, 9,10,11,12, 13,14,15,16};
  v16si b = {17,18,19,20, 21,22,23,24, 25,26,27,28, 29,30,31,32};
  BARRIER(a); BARRIER(b);
  v16si c;
  __asm__ volatile("vpunpckldq %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // Per 128-bit lane: interleave low 2 dwords: a[0],b[0],a[1],b[1]
  check(c[0] == 1 && c[1] == 17 && c[2] == 2 && c[3] == 18,
        "vpunpckldq zmm");
}

static void test_vpunpcklqdq_512(void) {
  v8di a = {1,2,3,4,5,6,7,8};
  v8di b = {10,20,30,40,50,60,70,80};
  BARRIER(a); BARRIER(b);
  v8di c;
  __asm__ volatile("vpunpcklqdq %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // Per 128-bit lane: a[low qword], b[low qword]
  check(c[0] == 1 && c[1] == 10 && c[2] == 3 && c[3] == 30,
        "vpunpcklqdq zmm");
}

static void test_vpacksswb_512(void) {
  v32hi a, b;
  for (int i = 0; i < 32; i++) { a[i] = i * 10; b[i] = -i * 10; }
  BARRIER(a); BARRIER(b);
  v64qi c;
  __asm__ volatile("vpacksswb %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // Lane 0: a[0..7] saturated, then b[0..7] saturated
  // a[0]=0, a[1]=10, ..., a[7]=70 (all fit in byte)
  // b[0]=0, b[1]=-10, ..., b[7]=-70
  check(c[0] == 0 && c[1] == 10 && c[7] == 70 &&
        c[8] == 0 && c[9] == (signed char)-10,
        "vpacksswb zmm");
}

static void test_vpackuswb_512(void) {
  v32hi a, b;
  for (int i = 0; i < 32; i++) { a[i] = i * 20; b[i] = 300 - i * 20; }
  BARRIER(a); BARRIER(b);
  v64qu c;
  __asm__ volatile("vpackuswb %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // a[0]=0, a[1]=20, ..., a[7]=140 (fit in unsigned byte)
  // Saturate: values > 255 → 255, < 0 → 0
  check(c[0] == 0 && c[1] == 20 && c[7] == 140,
        "vpackuswb zmm");
}

// =========================================================================
// Shuffle tests
// =========================================================================

static void test_vpshufd_512(void) {
  v16si a = {1,2,3,4, 5,6,7,8, 9,10,11,12, 13,14,15,16};
  BARRIER(a);
  v16si c;
  // imm8 = 0x1B = 0b00_01_10_11 → select [3,2,1,0] per lane
  __asm__ volatile("vpshufd $0x1b, %1, %0" : "=x"(c) : "x"(a));
  check(c[0] == 4 && c[1] == 3 && c[2] == 2 && c[3] == 1,
        "vpshufd zmm");
}

static void test_vpshufhw_512(void) {
  v32hi a;
  for (int i = 0; i < 32; i++) a[i] = i;
  BARRIER(a);
  v32hi c;
  // imm8 = 0x1B = reverse high words in each lane; low 4 words unchanged
  __asm__ volatile("vpshufhw $0x1b, %1, %0" : "=x"(c) : "x"(a));
  // Low 4 words (indices 0-3) unchanged
  // High 4 words reversed: [4,5,6,7] → [7,6,5,4]
  check(c[0] == 0 && c[3] == 3 && c[4] == 7 && c[5] == 6 && c[7] == 4,
        "vpshufhw zmm");
}

static void test_vpshuflw_512(void) {
  v32hi a;
  for (int i = 0; i < 32; i++) a[i] = i;
  BARRIER(a);
  v32hi c;
  // imm8 = 0x1B = reverse low words in each lane; high 4 words unchanged
  __asm__ volatile("vpshuflw $0x1b, %1, %0" : "=x"(c) : "x"(a));
  // Low 4 words reversed: [0,1,2,3] → [3,2,1,0]
  // High 4 words (indices 4-7) unchanged
  check(c[0] == 3 && c[1] == 2 && c[2] == 1 && c[3] == 0 &&
        c[4] == 4 && c[7] == 7,
        "vpshuflw zmm");
}

// =========================================================================
// Shift tests
// =========================================================================

static void test_vpslld_imm_512(void) {
  v16si a = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  BARRIER(a);
  v16si c;
  __asm__ volatile("vpslld $4, %1, %0" : "=x"(c) : "x"(a));
  check(c[0] == 16 && c[1] == 32 && c[15] == 256, "vpslld imm zmm");
}

static void test_vpsrld_imm_512(void) {
  v16si a;
  for (int i = 0; i < 16; i++) a[i] = (i + 1) * 256;
  BARRIER(a);
  v16si c;
  __asm__ volatile("vpsrld $4, %1, %0" : "=x"(c) : "x"(a));
  check(c[0] == 16 && c[1] == 32 && c[15] == 256, "vpsrld imm zmm");
}

static void test_vpsrad_imm_512(void) {
  v16si a;
  for (int i = 0; i < 16; i++) a[i] = -((i + 1) * 16);
  BARRIER(a);
  v16si c;
  __asm__ volatile("vpsrad $4, %1, %0" : "=x"(c) : "x"(a));
  // -16 >> 4 = -1, -32 >> 4 = -2, etc.
  check(c[0] == -1 && c[1] == -2 && c[15] == -16, "vpsrad imm zmm");
}

static void test_vpsllq_imm_512(void) {
  v8di a = {1,2,3,4,5,6,7,8};
  BARRIER(a);
  v8di c;
  __asm__ volatile("vpsllq $8, %1, %0" : "=x"(c) : "x"(a));
  check(c[0] == 256 && c[7] == 2048, "vpsllq imm zmm");
}

static void test_vpslldq_512(void) {
  v64qu a;
  for (int i = 0; i < 64; i++) a[i] = i + 1;
  BARRIER(a);
  v64qu c;
  // Shift left by 1 byte per 128-bit lane
  __asm__ volatile("vpslldq $1, %1, %0" : "=x"(c) : "x"(a));
  // Lane 0: byte 0 becomes 0, byte 1 becomes old byte 0 (=1)
  check(c[0] == 0 && c[1] == 1 && c[2] == 2, "vpslldq zmm");
}

static void test_vpsrldq_512(void) {
  v64qu a;
  for (int i = 0; i < 64; i++) a[i] = i + 1;
  BARRIER(a);
  v64qu c;
  // Shift right by 1 byte per 128-bit lane
  __asm__ volatile("vpsrldq $1, %1, %0" : "=x"(c) : "x"(a));
  // Lane 0: byte 0 becomes old byte 1 (=2), byte 15 becomes 0
  check(c[0] == 2 && c[1] == 3 && c[14] == 16 && c[15] == 0,
        "vpsrldq zmm");
}

static void test_vpsllw_xmm_512(void) {
  v32hi a;
  for (int i = 0; i < 32; i++) a[i] = i + 1;
  BARRIER(a);
  // Count from XMM: shift by 3
  typedef short v8hi __attribute__((vector_size(16)));
  v8hi cnt = {3,0,0,0,0,0,0,0};
  BARRIER(cnt);
  v32hi c;
  __asm__ volatile("vpsllw %2, %1, %0" : "=x"(c) : "x"(a), "x"(cnt));
  check(c[0] == 8 && c[1] == 16, "vpsllw xmm zmm");
}

static void test_vpunpcklwd_512(void) {
  v32hi a, b, c;
  for (int i = 0; i < 32; i++) { a[i] = i; b[i] = 100 + i; }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpunpcklwd %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // Per 128-bit lane: interleave low 4 words
  check(c[0] == 0 && c[1] == 100 && c[2] == 1 && c[3] == 101,
        "vpunpcklwd zmm");
}

static void test_vpunpckhwd_512(void) {
  v32hi a, b, c;
  for (int i = 0; i < 32; i++) { a[i] = i; b[i] = 100 + i; }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpunpckhwd %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // Per 128-bit lane: interleave high 4 words (words 4-7)
  check(c[0] == 4 && c[1] == 104 && c[2] == 5 && c[3] == 105,
        "vpunpckhwd zmm");
}

static void test_vpunpckhdq_512(void) {
  v16si a = {1,2,3,4, 5,6,7,8, 9,10,11,12, 13,14,15,16};
  v16si b = {17,18,19,20, 21,22,23,24, 25,26,27,28, 29,30,31,32};
  BARRIER(a); BARRIER(b);
  v16si c;
  __asm__ volatile("vpunpckhdq %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // Per 128-bit lane: interleave high 2 dwords: a[2],b[2],a[3],b[3]
  check(c[0] == 3 && c[1] == 19 && c[2] == 4 && c[3] == 20,
        "vpunpckhdq zmm");
}

static void test_vpunpckhqdq_512(void) {
  v8di a = {1,2,3,4,5,6,7,8};
  v8di b = {10,20,30,40,50,60,70,80};
  BARRIER(a); BARRIER(b);
  v8di c;
  __asm__ volatile("vpunpckhqdq %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // Per 128-bit lane: a[high qword], b[high qword]
  check(c[0] == 2 && c[1] == 20 && c[2] == 4 && c[3] == 40,
        "vpunpckhqdq zmm");
}

static void test_vpackssdw_512(void) {
  v16si a = {0, 100, -100, 40000, 0, 100, -100, 40000,
             0, 100, -100, 40000, 0, 100, -100, 40000};
  v16si b = {-40000, 200, -200, 32767, -40000, 200, -200, 32767,
             -40000, 200, -200, 32767, -40000, 200, -200, 32767};
  BARRIER(a); BARRIER(b);
  v32hi c;
  __asm__ volatile("vpackssdw %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // Per 128-bit lane: 4 dwords from a saturated to words, then 4 from b
  // a: 0, 100, -100, 40000→32767
  // b: -40000→-32768, 200, -200, 32767
  check(c[0] == 0 && c[1] == 100 && c[2] == -100 && c[3] == 32767 &&
        c[4] == -32768 && c[5] == 200 && c[6] == -200 && c[7] == 32767,
        "vpackssdw zmm");
}

static void test_vpsrlw_imm_512(void) {
  v32hi a;
  for (int i = 0; i < 32; i++) a[i] = (i + 1) * 64;
  BARRIER(a);
  v32hi c;
  __asm__ volatile("vpsrlw $3, %1, %0" : "=x"(c) : "x"(a));
  // 64 >> 3 = 8, 128 >> 3 = 16
  check(c[0] == 8 && c[1] == 16, "vpsrlw imm zmm");
}

static void test_vpsraw_imm_512(void) {
  v32hi a;
  for (int i = 0; i < 32; i++) a[i] = -((i + 1) * 8);
  BARRIER(a);
  v32hi c;
  __asm__ volatile("vpsraw $3, %1, %0" : "=x"(c) : "x"(a));
  // -8 >> 3 = -1, -16 >> 3 = -2
  check(c[0] == -1 && c[1] == -2, "vpsraw imm zmm");
}

static void test_vpsllw_imm_512(void) {
  v32hi a;
  for (int i = 0; i < 32; i++) a[i] = i + 1;
  BARRIER(a);
  v32hi c;
  __asm__ volatile("vpsllw $3, %1, %0" : "=x"(c) : "x"(a));
  // 1 << 3 = 8, 2 << 3 = 16
  check(c[0] == 8 && c[1] == 16, "vpsllw imm zmm");
}

static void test_vpsrlq_imm_512(void) {
  v8di a = {256, 512, 1024, 2048, 4096, 8192, 16384, 32768};
  BARRIER(a);
  v8di c;
  __asm__ volatile("vpsrlq $4, %1, %0" : "=x"(c) : "x"(a));
  check(c[0] == 16 && c[1] == 32 && c[7] == 2048, "vpsrlq imm zmm");
}

static void test_vpsrlw_xmm_512(void) {
  v32hi a;
  for (int i = 0; i < 32; i++) a[i] = (i + 1) * 64;
  BARRIER(a);
  typedef short v8hi __attribute__((vector_size(16)));
  v8hi cnt = {3,0,0,0,0,0,0,0};
  BARRIER(cnt);
  v32hi c;
  __asm__ volatile("vpsrlw %2, %1, %0" : "=x"(c) : "x"(a), "x"(cnt));
  check(c[0] == 8 && c[1] == 16, "vpsrlw xmm zmm");
}

static void test_vpsrld_xmm_512(void) {
  v16si a;
  for (int i = 0; i < 16; i++) a[i] = (i + 1) * 256;
  BARRIER(a);
  typedef int v4si __attribute__((vector_size(16)));
  v4si cnt = {4,0,0,0};
  BARRIER(cnt);
  v16si c;
  __asm__ volatile("vpsrld %2, %1, %0" : "=x"(c) : "x"(a), "x"(cnt));
  check(c[0] == 16 && c[1] == 32, "vpsrld xmm zmm");
}

static void test_vpsrlq_xmm_512(void) {
  v8di a = {256, 512, 1024, 2048, 4096, 8192, 16384, 32768};
  BARRIER(a);
  typedef long long v2di __attribute__((vector_size(16)));
  v2di cnt = {4,0};
  BARRIER(cnt);
  v8di c;
  __asm__ volatile("vpsrlq %2, %1, %0" : "=x"(c) : "x"(a), "x"(cnt));
  check(c[0] == 16 && c[1] == 32, "vpsrlq xmm zmm");
}

static void test_vpsraw_xmm_512(void) {
  v32hi a;
  for (int i = 0; i < 32; i++) a[i] = -((i + 1) * 8);
  BARRIER(a);
  typedef short v8hi __attribute__((vector_size(16)));
  v8hi cnt = {3,0,0,0,0,0,0,0};
  BARRIER(cnt);
  v32hi c;
  __asm__ volatile("vpsraw %2, %1, %0" : "=x"(c) : "x"(a), "x"(cnt));
  check(c[0] == -1 && c[1] == -2, "vpsraw xmm zmm");
}

static void test_vpsrad_xmm_512(void) {
  v16si a;
  for (int i = 0; i < 16; i++) a[i] = -((i + 1) * 16);
  BARRIER(a);
  typedef int v4si __attribute__((vector_size(16)));
  v4si cnt = {4,0,0,0};
  BARRIER(cnt);
  v16si c;
  __asm__ volatile("vpsrad %2, %1, %0" : "=x"(c) : "x"(a), "x"(cnt));
  check(c[0] == -1 && c[1] == -2, "vpsrad xmm zmm");
}

static void test_vpslld_xmm_512(void) {
  v16si a = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  BARRIER(a);
  typedef int v4si __attribute__((vector_size(16)));
  v4si cnt = {4,0,0,0};
  BARRIER(cnt);
  v16si c;
  __asm__ volatile("vpslld %2, %1, %0" : "=x"(c) : "x"(a), "x"(cnt));
  check(c[0] == 16 && c[1] == 32, "vpslld xmm zmm");
}

static void test_vpsllq_xmm_512(void) {
  v8di a = {1,2,3,4,5,6,7,8};
  BARRIER(a);
  typedef long long v2di __attribute__((vector_size(16)));
  v2di cnt = {8,0};
  BARRIER(cnt);
  v8di c;
  __asm__ volatile("vpsllq %2, %1, %0" : "=x"(c) : "x"(a), "x"(cnt));
  check(c[0] == 256 && c[7] == 2048, "vpsllq xmm zmm");
}

static void test_vmovsldup_512(void) {
  v16sf a = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  BARRIER(a);
  v16sf b;
  __asm__ volatile("vmovsldup %1, %0" : "=x"(b) : "x"(a));
  // Even indices duplicated: [1,1,3,3,5,5,7,7,9,9,11,11,13,13,15,15]
  check(b[0] == 1.0f && b[1] == 1.0f && b[2] == 3.0f && b[3] == 3.0f &&
        b[14] == 15.0f && b[15] == 15.0f, "vmovsldup zmm");
}

static void test_vmovshdup_512(void) {
  v16sf a = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  BARRIER(a);
  v16sf b;
  __asm__ volatile("vmovshdup %1, %0" : "=x"(b) : "x"(a));
  // Odd indices duplicated: [2,2,4,4,6,6,8,8,10,10,12,12,14,14,16,16]
  check(b[0] == 2.0f && b[1] == 2.0f && b[2] == 4.0f && b[3] == 4.0f &&
        b[14] == 16.0f && b[15] == 16.0f, "vmovshdup zmm");
}

static void test_vmovddup_512(void) {
  v8df a = {1,2,3,4,5,6,7,8};
  BARRIER(a);
  v8df b;
  __asm__ volatile("vmovddup %1, %0" : "=x"(b) : "x"(a));
  // Low qword of each 128-bit lane duplicated: [1,1,3,3,5,5,7,7]
  check(b[0] == 1.0 && b[1] == 1.0 && b[2] == 3.0 && b[3] == 3.0 &&
        b[6] == 7.0 && b[7] == 7.0, "vmovddup zmm");
}

static void test_vunpcklps_512(void) {
  v16sf a = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  v16sf b = {17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32};
  BARRIER(a); BARRIER(b);
  v16sf c;
  __asm__ volatile("vunpcklps %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // Per 128-bit lane: interleave low 2 floats
  // Lane 0: a[0],b[0],a[1],b[1] = 1,17,2,18
  check(c[0] == 1.0f && c[1] == 17.0f && c[2] == 2.0f && c[3] == 18.0f,
        "vunpcklps zmm");
}

static void test_vunpckhps_512(void) {
  v16sf a = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  v16sf b = {17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32};
  BARRIER(a); BARRIER(b);
  v16sf c;
  __asm__ volatile("vunpckhps %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // Per 128-bit lane: interleave high 2 floats
  // Lane 0: a[2],b[2],a[3],b[3] = 3,19,4,20
  check(c[0] == 3.0f && c[1] == 19.0f && c[2] == 4.0f && c[3] == 20.0f,
        "vunpckhps zmm");
}

static void test_vunpcklpd_512(void) {
  v8df a = {1,2,3,4,5,6,7,8};
  v8df b = {9,10,11,12,13,14,15,16};
  BARRIER(a); BARRIER(b);
  v8df c;
  __asm__ volatile("vunpcklpd %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // Per 128-bit lane: interleave low double
  // Lane 0: a[0],b[0] = 1,9
  check(c[0] == 1.0 && c[1] == 9.0 && c[2] == 3.0 && c[3] == 11.0,
        "vunpcklpd zmm");
}

static void test_vunpckhpd_512(void) {
  v8df a = {1,2,3,4,5,6,7,8};
  v8df b = {9,10,11,12,13,14,15,16};
  BARRIER(a); BARRIER(b);
  v8df c;
  __asm__ volatile("vunpckhpd %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // Per 128-bit lane: interleave high double
  // Lane 0: a[1],b[1] = 2,10
  check(c[0] == 2.0 && c[1] == 10.0 && c[2] == 4.0 && c[3] == 12.0,
        "vunpckhpd zmm");
}

static void test_vmovlps(void) {
  // VMOVLPS: load m64 into low qword, keep high qword from vvvv
  typedef float v4sf __attribute__((vector_size(16)));
  v4sf src = {1.0f, 2.0f, 3.0f, 4.0f};
  BARRIER(src);
  float mem[2] = {5.0f, 6.0f};
  v4sf dst;
  __asm__ volatile("vmovlps %2, %1, %0" : "=x"(dst) : "x"(src), "m"(mem));
  check(dst[0] == 5.0f && dst[1] == 6.0f && dst[2] == 3.0f && dst[3] == 4.0f,
        "vmovlps xmm,xmm,m64");
}

static void test_vmovhps(void) {
  // VMOVHPS: load m64 into high qword, keep low qword from vvvv
  typedef float v4sf __attribute__((vector_size(16)));
  v4sf src = {1.0f, 2.0f, 3.0f, 4.0f};
  BARRIER(src);
  float mem[2] = {7.0f, 8.0f};
  v4sf dst;
  __asm__ volatile("vmovhps %2, %1, %0" : "=x"(dst) : "x"(src), "m"(mem));
  check(dst[0] == 1.0f && dst[1] == 2.0f && dst[2] == 7.0f && dst[3] == 8.0f,
        "vmovhps xmm,xmm,m64");
}

static void test_vmovhlps(void) {
  typedef float v4sf __attribute__((vector_size(16)));
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {5.0f, 6.0f, 7.0f, 8.0f};
  BARRIER(a); BARRIER(b);
  v4sf c;
  __asm__ volatile("vmovhlps %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // DEST[63:0] = SRC2[127:64], DEST[127:64] = SRC1[127:64]
  check(c[0] == 7.0f && c[1] == 8.0f && c[2] == 3.0f && c[3] == 4.0f,
        "vmovhlps xmm,xmm,xmm");
}

static void test_vmovlhps(void) {
  typedef float v4sf __attribute__((vector_size(16)));
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {5.0f, 6.0f, 7.0f, 8.0f};
  BARRIER(a); BARRIER(b);
  v4sf c;
  __asm__ volatile("vmovlhps %2, %1, %0" : "=x"(c) : "x"(a), "x"(b));
  // DEST[63:0] = SRC1[63:0], DEST[127:64] = SRC2[63:0]
  check(c[0] == 1.0f && c[1] == 2.0f && c[2] == 5.0f && c[3] == 6.0f,
        "vmovlhps xmm,xmm,xmm");
}

static void test_vcvtsi2ss(void) {
  typedef float v4sf __attribute__((vector_size(16)));
  v4sf src = {0.0f, 99.0f, 88.0f, 77.0f};
  BARRIER(src);
  int val = 42;
  v4sf dst;
  __asm__ volatile("vcvtsi2ss %2, %1, %0" : "=x"(dst) : "x"(src), "r"(val));
  check(dst[0] == 42.0f && dst[1] == 99.0f && dst[2] == 88.0f && dst[3] == 77.0f,
        "vcvtsi2ss xmm,xmm,r32");
}

static void test_vcvtsi2sd(void) {
  typedef double v2df __attribute__((vector_size(16)));
  v2df src = {0.0, 99.0};
  BARRIER(src);
  long long val = 123;
  v2df dst;
  __asm__ volatile("vcvtsi2sd %2, %1, %0" : "=x"(dst) : "x"(src), "r"(val));
  check(dst[0] == 123.0 && dst[1] == 99.0, "vcvtsi2sd xmm,xmm,r64");
}

static void test_vcvttss2si(void) {
  typedef float v4sf __attribute__((vector_size(16)));
  v4sf src = {3.7f, 0, 0, 0};
  BARRIER(src);
  int result;
  __asm__ volatile("vcvttss2si %1, %0" : "=r"(result) : "x"(src));
  check(result == 3, "vcvttss2si r32,xmm");
}

static void test_vcvttsd2si(void) {
  typedef double v2df __attribute__((vector_size(16)));
  v2df src = {-7.9, 0};
  BARRIER(src);
  long long result;
  __asm__ volatile("vcvttsd2si %1, %0" : "=r"(result) : "x"(src));
  check(result == -7, "vcvttsd2si r64,xmm");
}

static void test_vucomiss(void) {
  typedef float v4sf __attribute__((vector_size(16)));
  v4sf a = {3.0f, 0, 0, 0};
  v4sf b = {5.0f, 0, 0, 0};
  BARRIER(a); BARRIER(b);
  unsigned char below;
  __asm__ volatile("vucomiss %2, %1; setb %0" : "=r"(below) : "x"(a), "x"(b));
  check(below == 1, "vucomiss (3 < 5)");
}

static void test_vucomisd(void) {
  typedef double v2df __attribute__((vector_size(16)));
  v2df a = {10.0, 0};
  v2df b = {10.0, 0};
  BARRIER(a); BARRIER(b);
  unsigned char eq;
  __asm__ volatile("vucomisd %2, %1; setz %0" : "=r"(eq) : "x"(a), "x"(b));
  check(eq == 1, "vucomisd (10 == 10)");
}

static void test_vcvtps2pd_512(void) {
  typedef float v8sf __attribute__((vector_size(32)));
  v8sf a = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f};
  BARRIER(a);
  v8df c;
  __asm__ volatile("vcvtps2pd %1, %0" : "=x"(c) : "x"(a));
  check(c[0] == 1.0 && c[3] == 4.0 && c[7] == 8.0, "vcvtps2pd zmm,ymm");
}

static void test_vcvtpd2ps_512(void) {
  v8df a = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0};
  BARRIER(a);
  typedef float v8sf __attribute__((vector_size(32)));
  v8sf c;
  __asm__ volatile("vcvtpd2ps %1, %0" : "=x"(c) : "x"(a));
  check(c[0] == 1.0f && c[3] == 4.0f && c[7] == 8.0f, "vcvtpd2ps ymm,zmm");
}

static void test_vcvtdq2ps_512(void) {
  v16si a = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
  BARRIER(a);
  v16sf c;
  __asm__ volatile("vcvtdq2ps %1, %0" : "=x"(c) : "x"(a));
  check(c[0] == 1.0f && c[7] == 8.0f && c[15] == 16.0f, "vcvtdq2ps zmm");
}

static void test_vcvtps2dq_512(void) {
  v16sf a = {1.1f, 2.9f, -3.5f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f, 9.0f, 10.0f, 11.0f, 12.0f, 13.0f, 14.0f, 15.0f, 16.0f};
  BARRIER(a);
  v16si c;
  __asm__ volatile("vcvtps2dq %1, %0" : "=x"(c) : "x"(a));
  check(c[0] == 1 && c[3] == 4 && c[15] == 16, "vcvtps2dq zmm");
}

static void test_vcvttps2dq_512(void) {
  v16sf a = {1.9f, 2.1f, -3.9f, 4.5f, 5.0f, 6.0f, 7.0f, 8.0f, 9.0f, 10.0f, 11.0f, 12.0f, 13.0f, 14.0f, 15.0f, 16.0f};
  BARRIER(a);
  v16si c;
  __asm__ volatile("vcvttps2dq %1, %0" : "=x"(c) : "x"(a));
  check(c[0] == 1 && c[1] == 2 && c[2] == -3 && c[15] == 16, "vcvttps2dq zmm");
}

static void test_vcvtss2sd(void) {
  typedef float v4sf __attribute__((vector_size(16)));
  typedef double v2df __attribute__((vector_size(16)));
  v4sf src = {3.0f, 0, 0, 0};
  v2df base = {0.0, 99.0};
  BARRIER(src); BARRIER(base);
  v2df dst;
  __asm__ volatile("vcvtss2sd %2, %1, %0" : "=x"(dst) : "x"(base), "x"(src));
  check(dst[0] == 3.0 && dst[1] == 99.0, "vcvtss2sd xmm,xmm,xmm");
}

static void test_vcvtsd2ss(void) {
  typedef float v4sf __attribute__((vector_size(16)));
  typedef double v2df __attribute__((vector_size(16)));
  v2df src = {7.0, 0};
  v4sf base = {0.0f, 99.0f, 88.0f, 77.0f};
  BARRIER(src); BARRIER(base);
  v4sf dst;
  __asm__ volatile("vcvtsd2ss %2, %1, %0" : "=x"(dst) : "x"(base), "x"(src));
  check(dst[0] == 7.0f && dst[1] == 99.0f && dst[2] == 88.0f, "vcvtsd2ss xmm,xmm,xmm");
}

// =========================================================================
// VSHUFPS
// =========================================================================

void test_vshufps(void) {
  typedef float v4sf __attribute__((vector_size(16)));
  v4sf a = {1.0f, 2.0f, 3.0f, 4.0f};
  v4sf b = {5.0f, 6.0f, 7.0f, 8.0f};
  BARRIER(a); BARRIER(b);
  v4sf dst;
  // imm8 = 0b00_01_10_11 = 0x1B
  // dst[0] = a[3], dst[1] = a[2], dst[2] = b[1], dst[3] = b[0]
  __asm__ volatile("vshufps $0x1B, %2, %1, %0" : "=x"(dst) : "x"(a), "x"(b));
  check(dst[0] == 4.0f && dst[1] == 3.0f && dst[2] == 6.0f && dst[3] == 5.0f, "vshufps xmm imm8=0x1B");
}

// =========================================================================
// VSHUFPD
// =========================================================================

void test_vshufpd(void) {
  typedef double v2df __attribute__((vector_size(16)));
  v2df a = {1.0, 2.0};
  v2df b = {3.0, 4.0};
  BARRIER(a); BARRIER(b);
  v2df dst;
  // imm8 = 0b11 → bit0=1: dst[0]=a[1]=2.0, bit1=1: dst[1]=b[1]=4.0
  __asm__ volatile("vshufpd $3, %2, %1, %0" : "=x"(dst) : "x"(a), "x"(b));
  check(dst[0] == 2.0 && dst[1] == 4.0, "vshufpd xmm imm8=3");
}

// =========================================================================
// VCMPPS (EVEX → kmask)
// =========================================================================

void test_vcmpps_512(void) {
  typedef float v16sf __attribute__((vector_size(64)));
  v16sf a = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f,
             9.0f, 10.0f, 11.0f, 12.0f, 13.0f, 14.0f, 15.0f, 16.0f};
  v16sf b = {1.0f, 3.0f, 2.0f, 4.0f, 6.0f, 5.0f, 7.0f, 9.0f,
             8.0f, 10.0f, 12.0f, 11.0f, 13.0f, 15.0f, 14.0f, 16.0f};
  BARRIER(a); BARRIER(b);
  unsigned int k;
  // CMP_EQ_OQ = 0: a[i] == b[i]
  __asm__ volatile("vcmpeqps %2, %1, %%k1\n\t"
                   "kmovw %%k1, %0"
                   : "=r"(k) : "v"(a), "v"(b));
  // Equal at indices: 0, 3, 6, 9, 12, 15 → 0x9249
  check((k & 0xFFFF) == 0x9249, "vcmpps zmm CMP_EQ");
}

// =========================================================================
// VCMPPD (EVEX → kmask)
// =========================================================================

void test_vcmppd_512(void) {
  typedef double v8df __attribute__((vector_size(64)));
  v8df a = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0};
  v8df b = {1.0, 3.0, 3.0, 5.0, 5.0, 7.0, 7.0, 8.0};
  BARRIER(a); BARRIER(b);
  unsigned int k;
  // CMP_EQ_OQ = 0: a[i] == b[i]
  __asm__ volatile("vcmpeqpd %2, %1, %%k1\n\t"
                   "kmovw %%k1, %0"
                   : "=r"(k) : "v"(a), "v"(b));
  // Equal at indices: 0, 2, 4, 6, 7 → bits 0,2,4,6,7 → 0xD5
  check((k & 0xFF) == 0xD5, "vcmppd zmm CMP_EQ");
}

// =========================================================================
// VCVTTPS2UDQ / VCVTPS2UDQ
// =========================================================================

void test_vcvttps2udq_512(void) {
  typedef float v16sf __attribute__((vector_size(64)));
  typedef unsigned int v16su __attribute__((vector_size(64)));
  v16sf src = {1.9f, 2.1f, 3.7f, 4.0f, 5.5f, 6.0f, 7.0f, 8.0f,
               0.0f, 100.0f, 200.0f, 300.0f, 1000.0f, 2000.0f, 3000.0f, 4000.0f};
  BARRIER(src);
  v16su dst;
  __asm__ volatile("vcvttps2udq %1, %0" : "=v"(dst) : "v"(src));
  check(dst[0] == 1 && dst[1] == 2 && dst[2] == 3 && dst[3] == 4 &&
        dst[8] == 0 && dst[9] == 100 && dst[14] == 3000 && dst[15] == 4000,
        "vcvttps2udq zmm");
}

// =========================================================================
// VCVTUDQ2PS
// =========================================================================

void test_vcvtudq2ps_512(void) {
  typedef unsigned int v16su __attribute__((vector_size(64)));
  typedef float v16sf __attribute__((vector_size(64)));
  v16su src = {0, 1, 2, 3, 4, 5, 6, 7, 100, 200, 300, 1000, 2000, 3000, 4000, 5000};
  BARRIER(src);
  v16sf dst;
  __asm__ volatile("vcvtudq2ps %1, %0" : "=v"(dst) : "v"(src));
  check(dst[0] == 0.0f && dst[1] == 1.0f && dst[7] == 7.0f &&
        dst[8] == 100.0f && dst[15] == 5000.0f,
        "vcvtudq2ps zmm");
}

// =========================================================================
// VCVTDQ2PD / VCVTPD2DQ / VCVTTPD2DQ
// =========================================================================

void test_vcvtdq2pd_512(void) {
  typedef int v8si __attribute__((vector_size(32)));
  typedef double v8df __attribute__((vector_size(64)));
  v8si src = {-1, 0, 1, 42, 100, -100, 1000, -1000};
  BARRIER(src);
  v8df dst;
  __asm__ volatile("vcvtdq2pd %1, %0" : "=v"(dst) : "v"(src));
  check(dst[0] == -1.0 && dst[1] == 0.0 && dst[2] == 1.0 && dst[3] == 42.0 &&
        dst[4] == 100.0 && dst[5] == -100.0 && dst[7] == -1000.0,
        "vcvtdq2pd zmm");
}

void test_vcvttpd2dq_512(void) {
  typedef double v8df __attribute__((vector_size(64)));
  typedef int v8si __attribute__((vector_size(32)));
  v8df src = {1.9, -2.1, 3.7, -4.0, 5.5, -6.0, 7.0, -8.0};
  BARRIER(src);
  v8si dst;
  __asm__ volatile("vcvttpd2dq %1, %0" : "=v"(dst) : "v"(src));
  check(dst[0] == 1 && dst[1] == -2 && dst[2] == 3 && dst[3] == -4 &&
        dst[4] == 5 && dst[5] == -6 && dst[7] == -8,
        "vcvttpd2dq zmm");
}

// =========================================================================
// VPSHUFB
// =========================================================================

void test_vpshufb_512(void) {
  typedef char v64qi __attribute__((vector_size(64)));
  // Source: 0..15 repeated 4 times
  v64qi src = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,
               0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,
               0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,
               0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15};
  // Control: reverse order in each lane, with one masked byte
  v64qi ctrl = {15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0,
                15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0,
                15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0,
                (char)0x80,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0};
  BARRIER(src); BARRIER(ctrl);
  v64qi dst;
  __asm__ volatile("vpshufb %2, %1, %0" : "=v"(dst) : "v"(src), "v"(ctrl));
  // Lane 0: reversed
  check(dst[0] == 15 && dst[15] == 0 && dst[48] == 0 && dst[49] == 14,
        "vpshufb zmm");
}

// =========================================================================
// VPMULLD
// =========================================================================

void test_vpmulld_512(void) {
  typedef int v16si __attribute__((vector_size(64)));
  v16si a = {1, 2, 3, 4, 5, 6, 7, 8, -1, -2, -3, -4, 100, 200, 300, 400};
  v16si b = {10, 20, 30, 40, 50, 60, 70, 80, -10, -20, -30, -40, 100, 200, 300, 400};
  BARRIER(a); BARRIER(b);
  v16si dst;
  __asm__ volatile("vpmulld %2, %1, %0" : "=v"(dst) : "v"(a), "v"(b));
  check(dst[0] == 10 && dst[1] == 40 && dst[8] == 10 && dst[9] == 40 &&
        dst[12] == 10000 && dst[15] == 160000,
        "vpmulld zmm");
}

// =========================================================================
// VPERMD
// =========================================================================

void test_vpermd_512(void) {
  typedef int v16si __attribute__((vector_size(64)));
  v16si src = {100, 101, 102, 103, 104, 105, 106, 107,
               108, 109, 110, 111, 112, 113, 114, 115};
  // Reverse order using index
  v16si idx = {15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0};
  BARRIER(src); BARRIER(idx);
  v16si dst;
  __asm__ volatile("vpermd %2, %1, %0" : "=v"(dst) : "v"(idx), "v"(src));
  check(dst[0] == 115 && dst[1] == 114 && dst[14] == 101 && dst[15] == 100,
        "vpermd zmm");
}

// =========================================================================
// VPINSRW / VPEXTRW
// =========================================================================

void test_vpinsrw(void) {
  typedef short v8hi __attribute__((vector_size(16)));
  v8hi src = {10, 20, 30, 40, 50, 60, 70, 80};
  BARRIER(src);
  v8hi dst;
  unsigned int val = 99;
  // Insert val (99) at position 3
  __asm__ volatile("vpinsrw $3, %2, %1, %0" : "=x"(dst) : "x"(src), "r"(val));
  check(dst[0] == 10 && dst[1] == 20 && dst[2] == 30 && dst[3] == 99 &&
        dst[4] == 50 && dst[7] == 80, "vpinsrw xmm");
}

void test_vpextrw(void) {
  typedef short v8hi __attribute__((vector_size(16)));
  v8hi src = {10, 20, 30, 40, 50, 60, 70, 80};
  BARRIER(src);
  unsigned int val;
  // Extract word at position 5 (value 60)
  __asm__ volatile("vpextrw $5, %1, %0" : "=r"(val) : "x"(src));
  check(val == 60, "vpextrw xmm");
}

void test_vpmovsxbw_512(void) {
  typedef char v32qi __attribute__((vector_size(32)));
  typedef short v32hi __attribute__((vector_size(64)));
  v32qi src = {-1, 2, -3, 4, -5, 6, -7, 8, -9, 10, -11, 12, -13, 14, -15, 16,
               17, -18, 19, -20, 21, -22, 23, -24, 25, -26, 27, -28, 29, -30, 31, -32};
  BARRIER(src);
  v32hi dst;
  __asm__ volatile("vpmovsxbw %1, %0" : "=v"(dst) : "x"(src));
  check(dst[0] == -1 && dst[1] == 2 && dst[2] == -3 && dst[3] == 4 &&
        dst[30] == 31 && dst[31] == -32, "vpmovsxbw zmm");
}

void test_vpmovzxbw_512(void) {
  typedef unsigned char v32qu __attribute__((vector_size(32)));
  typedef unsigned short v32hu __attribute__((vector_size(64)));
  v32qu src = {255, 0, 128, 1, 200, 50, 100, 150, 10, 20, 30, 40, 50, 60, 70, 80,
               90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210, 220, 230, 240};
  BARRIER(src);
  v32hu dst;
  __asm__ volatile("vpmovzxbw %1, %0" : "=v"(dst) : "x"(src));
  check(dst[0] == 255 && dst[1] == 0 && dst[2] == 128 && dst[3] == 1 &&
        dst[30] == 230 && dst[31] == 240, "vpmovzxbw zmm");
}

void test_vpmovsxwd_512(void) {
  typedef short v16hi __attribute__((vector_size(32)));
  typedef int v16si __attribute__((vector_size(64)));
  v16hi src = {-1, 2, -3, 4, -5, 6, -7, 8, -9, 10, -11, 12, -13, 14, -15, 16};
  BARRIER(src);
  v16si dst;
  __asm__ volatile("vpmovsxwd %1, %0" : "=v"(dst) : "x"(src));
  check(dst[0] == -1 && dst[1] == 2 && dst[2] == -3 && dst[15] == 16, "vpmovsxwd zmm");
}

void test_vpmovzxwd_512(void) {
  typedef unsigned short v16hu __attribute__((vector_size(32)));
  typedef unsigned int v16su __attribute__((vector_size(64)));
  v16hu src = {65535, 0, 32768, 1, 200, 50, 100, 150, 10, 20, 30, 40, 50, 60, 70, 80};
  BARRIER(src);
  v16su dst;
  __asm__ volatile("vpmovzxwd %1, %0" : "=v"(dst) : "x"(src));
  check(dst[0] == 65535 && dst[1] == 0 && dst[2] == 32768 && dst[15] == 80, "vpmovzxwd zmm");
}

void test_vpmovsxdq_512(void) {
  typedef int v8si __attribute__((vector_size(32)));
  typedef long long v8di __attribute__((vector_size(64)));
  v8si src = {-1, 2, -3, 4, -5, 6, -7, 8};
  BARRIER(src);
  v8di dst;
  __asm__ volatile("vpmovsxdq %1, %0" : "=v"(dst) : "x"(src));
  check(dst[0] == -1 && dst[1] == 2 && dst[6] == -7 && dst[7] == 8, "vpmovsxdq zmm");
}

void test_vpmovzxdq_512(void) {
  typedef unsigned int v8su __attribute__((vector_size(32)));
  typedef unsigned long long v8du __attribute__((vector_size(64)));
  v8su src = {0xFFFFFFFF, 0, 0x80000000, 1, 200, 50, 100, 150};
  BARRIER(src);
  v8du dst;
  __asm__ volatile("vpmovzxdq %1, %0" : "=v"(dst) : "x"(src));
  check(dst[0] == 0xFFFFFFFF && dst[1] == 0 && dst[2] == 0x80000000 && dst[7] == 150, "vpmovzxdq zmm");
}

void test_vpsrlvd_512(void) {
  typedef unsigned int v16su __attribute__((vector_size(64)));
  v16su src = {0x80000000, 0xFFFFFFFF, 0x12345678, 0x1, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  v16su cnt = {0, 1, 4, 31, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  BARRIER(src); BARRIER(cnt);
  v16su dst;
  __asm__ volatile("vpsrlvd %2, %1, %0" : "=v"(dst) : "v"(src), "v"(cnt));
  check(dst[0] == 0x80000000 && dst[1] == 0x7FFFFFFF && dst[2] == 0x01234567 && dst[3] == 0, "vpsrlvd zmm");
}

void test_vpsravd_512(void) {
  typedef int v16si __attribute__((vector_size(64)));
  v16si src = {(int)0x80000000, (int)0x80000000, -16, 100, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  v16si cnt = {0, 1, 2, 1, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  BARRIER(src); BARRIER(cnt);
  v16si dst;
  __asm__ volatile("vpsravd %2, %1, %0" : "=v"(dst) : "v"(src), "v"(cnt));
  check(dst[0] == (int)0x80000000 && dst[1] == (int)0xC0000000 && dst[2] == -4 && dst[3] == 50, "vpsravd zmm");
}

void test_vpsllvd_512(void) {
  typedef unsigned int v16su __attribute__((vector_size(64)));
  v16su src = {1, 0x80000000, 0xFF, 3, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  v16su cnt = {31, 1, 8, 0, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  BARRIER(src); BARRIER(cnt);
  v16su dst;
  __asm__ volatile("vpsllvd %2, %1, %0" : "=v"(dst) : "v"(src), "v"(cnt));
  check(dst[0] == 0x80000000 && dst[1] == 0 && dst[2] == 0xFF00 && dst[3] == 3, "vpsllvd zmm");
}

void test_vpermi2d_512(void) {
  typedef unsigned int v16su __attribute__((vector_size(64)));
  // t1 has values 100-115, t2 has values 200-215
  v16su t1 = {100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115};
  v16su t2 = {200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215};
  // idx: 0 -> t1[0]=100, 16 -> t2[0]=200, 5 -> t1[5]=105, 31 -> t2[15]=215
  v16su idx = {0, 16, 5, 31, 1, 17, 15, 20, 0,0,0,0, 0,0,0,0};
  BARRIER(t1); BARRIER(t2); BARRIER(idx);
  v16su dst;
  // vpermi2d: dst=idx, src1=t1(vvvv), src2=t2(rm)
  __asm__ volatile("vpermi2d %2, %1, %0" : "+v"(idx) : "v"(t1), "v"(t2));
  check(idx[0] == 100 && idx[1] == 200 && idx[2] == 105 && idx[3] == 215 &&
        idx[4] == 101 && idx[5] == 201 && idx[6] == 115 && idx[7] == 204, "vpermi2d zmm");
}

void test_vprolvd_512(void) {
  typedef unsigned int v16su __attribute__((vector_size(64)));
  v16su src = {1, 0x80000001, 0xFF, 0x12345678, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  v16su cnt = {1, 1, 8, 0, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  BARRIER(src); BARRIER(cnt);
  v16su dst;
  __asm__ volatile("vprolvd %2, %1, %0" : "=v"(dst) : "v"(src), "v"(cnt));
  check(dst[0] == 2 && dst[1] == 3 && dst[2] == 0xFF00 && dst[3] == 0x12345678, "vprolvd zmm");
}

void test_vpsrlvw_512(void) {
  typedef unsigned short v32hu __attribute__((vector_size(64)));
  v32hu src = {0x8000, 0xFFFF, 0x1234, 1, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  v32hu cnt = {0, 1, 4, 15, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  BARRIER(src); BARRIER(cnt);
  v32hu dst;
  __asm__ volatile("vpsrlvw %2, %1, %0" : "=v"(dst) : "v"(src), "v"(cnt));
  check(dst[0] == 0x8000 && dst[1] == 0x7FFF && dst[2] == 0x0123 && dst[3] == 0, "vpsrlvw zmm");
}

void test_vpabsd_512(void) {
  typedef int v16si __attribute__((vector_size(64)));
  v16si src = {-1, 0, 1, -100, 100, -2147483647, 42, -42, 0,0,0,0, 0,0,0,0};
  BARRIER(src);
  v16si dst;
  __asm__ volatile("vpabsd %1, %0" : "=v"(dst) : "v"(src));
  check(dst[0] == 1 && dst[1] == 0 && dst[2] == 1 && dst[3] == 100 &&
        dst[4] == 100 && dst[5] == 2147483647 && dst[6] == 42 && dst[7] == 42, "vpabsd zmm");
}

void test_vpminsd_512(void) {
  typedef int v16si __attribute__((vector_size(64)));
  v16si a = {-5, 10, 0, -100, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  v16si b = {5, -10, 0, 100, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  BARRIER(a); BARRIER(b);
  v16si dst;
  __asm__ volatile("vpminsd %2, %1, %0" : "=v"(dst) : "v"(a), "v"(b));
  check(dst[0] == -5 && dst[1] == -10 && dst[2] == 0 && dst[3] == -100, "vpminsd zmm");
}

void test_vpmaxsd_512(void) {
  typedef int v16si __attribute__((vector_size(64)));
  v16si a = {-5, 10, 0, -100, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  v16si b = {5, -10, 0, 100, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  BARRIER(a); BARRIER(b);
  v16si dst;
  __asm__ volatile("vpmaxsd %2, %1, %0" : "=v"(dst) : "v"(a), "v"(b));
  check(dst[0] == 5 && dst[1] == 10 && dst[2] == 0 && dst[3] == 100, "vpmaxsd zmm");
}

void test_vpmaxud_512(void) {
  typedef unsigned int v16su __attribute__((vector_size(64)));
  v16su a = {0, 0xFFFFFFFF, 100, 50, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  v16su b = {1, 0, 200, 50, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  BARRIER(a); BARRIER(b);
  v16su dst;
  __asm__ volatile("vpmaxud %2, %1, %0" : "=v"(dst) : "v"(a), "v"(b));
  check(dst[0] == 1 && dst[1] == 0xFFFFFFFF && dst[2] == 200 && dst[3] == 50, "vpmaxud zmm");
}

void test_vfmadd231ps_512(void) {
  typedef float v16sf __attribute__((vector_size(64)));
  v16sf a = {1.0f, 2.0f, 3.0f, 4.0f, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  v16sf b = {5.0f, 6.0f, 7.0f, 8.0f, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  v16sf c = {10.0f, 20.0f, 30.0f, 40.0f, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  BARRIER(a); BARRIER(b); BARRIER(c);
  // VFMADD231PS: dst = b*c + dst (a is dst, b=src2(vvvv), c=src3(rm))
  // dst[0] = 5*10 + 1 = 51, dst[1] = 6*20 + 2 = 122, dst[2] = 7*30 + 3 = 213, dst[3] = 8*40 + 4 = 324
  __asm__ volatile("vfmadd231ps %2, %1, %0" : "+v"(a) : "v"(b), "v"(c));
  check(a[0] == 51.0f && a[1] == 122.0f && a[2] == 213.0f && a[3] == 324.0f, "vfmadd231ps zmm");
}

void test_vfmsub231pd_512(void) {
  typedef double v8df __attribute__((vector_size(64)));
  v8df a = {1.0, 2.0, 3.0, 4.0, 0,0,0,0};
  v8df b = {5.0, 6.0, 7.0, 8.0, 0,0,0,0};
  v8df c = {10.0, 20.0, 30.0, 40.0, 0,0,0,0};
  BARRIER(a); BARRIER(b); BARRIER(c);
  // VFMSUB231PD: dst = b*c - dst
  // dst[0] = 5*10 - 1 = 49, dst[1] = 6*20 - 2 = 118, dst[2] = 7*30 - 3 = 207, dst[3] = 8*40 - 4 = 316
  __asm__ volatile("vfmsub231pd %2, %1, %0" : "+v"(a) : "v"(b), "v"(c));
  check(a[0] == 49.0 && a[1] == 118.0 && a[2] == 207.0 && a[3] == 316.0, "vfmsub231pd zmm");
}

void test_vfnmadd231ps_512(void) {
  typedef float v16sf __attribute__((vector_size(64)));
  v16sf a = {1.0f, 2.0f, 3.0f, 4.0f, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  v16sf b = {5.0f, 6.0f, 7.0f, 8.0f, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  v16sf c = {10.0f, 20.0f, 30.0f, 40.0f, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  BARRIER(a); BARRIER(b); BARRIER(c);
  // VFNMADD231PS: dst = -(b*c) + dst
  // dst[0] = -(5*10) + 1 = -49, dst[1] = -(6*20) + 2 = -118
  __asm__ volatile("vfnmadd231ps %2, %1, %0" : "+v"(a) : "v"(b), "v"(c));
  check(a[0] == -49.0f && a[1] == -118.0f && a[2] == -207.0f && a[3] == -316.0f, "vfnmadd231ps zmm");
}

void test_vfmadd132ps_512(void) {
  typedef float v16sf __attribute__((vector_size(64)));
  v16sf a = {2.0f, 3.0f, 4.0f, 5.0f, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  v16sf b = {10.0f, 20.0f, 30.0f, 40.0f, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  v16sf c = {100.0f, 200.0f, 300.0f, 400.0f, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  BARRIER(a); BARRIER(b); BARRIER(c);
  // VFMADD132PS: dst = dst*src3 + src2 = a*c + b
  // dst[0] = 2*100 + 10 = 210, dst[1] = 3*200 + 20 = 620
  __asm__ volatile("vfmadd132ps %2, %1, %0" : "+v"(a) : "v"(b), "v"(c));
  check(a[0] == 210.0f && a[1] == 620.0f && a[2] == 1230.0f && a[3] == 2040.0f, "vfmadd132ps zmm");
}

void test_vpermt2w_512(void) {
  typedef unsigned short v32hu __attribute__((vector_size(64)));
  // t1 (dest): words 0..31
  v32hu t1 = {100,101,102,103, 104,105,106,107, 108,109,110,111, 112,113,114,115,
              116,117,118,119, 120,121,122,123, 124,125,126,127, 128,129,130,131};
  // t2 (src): words 200..231
  v32hu t2 = {200,201,202,203, 204,205,206,207, 208,209,210,211, 212,213,214,215,
              216,217,218,219, 220,221,222,223, 224,225,226,227, 228,229,230,231};
  // idx (vvvv): select from combined table
  // idx[0]=0 → t1[0]=100, idx[1]=32 → t2[0]=200, idx[2]=5 → t1[5]=105, idx[3]=35 → t2[3]=203
  v32hu idx = {0,32,5,35, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  BARRIER(t1); BARRIER(t2); BARRIER(idx);
  // VPERMT2W: dest(t1) gets result, idx(vvvv) selects, src3(t2) is second table
  __asm__ volatile("vpermt2w %2, %1, %0" : "+v"(t1) : "v"(idx), "v"(t2));
  check(t1[0] == 100 && t1[1] == 200 && t1[2] == 105 && t1[3] == 203, "vpermt2w zmm");
}

void test_vpermw_512(void) {
  typedef unsigned short v32hu __attribute__((vector_size(64)));
  v32hu src = {10,20,30,40, 50,60,70,80, 90,100,110,120, 130,140,150,160,
               170,180,190,200, 210,220,230,240, 250,260,270,280, 290,300,310,320};
  v32hu idx = {31,0,15,1, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  BARRIER(src); BARRIER(idx);
  v32hu dst;
  __asm__ volatile("vpermw %2, %1, %0" : "=v"(dst) : "v"(idx), "v"(src));
  check(dst[0] == 320 && dst[1] == 10 && dst[2] == 160 && dst[3] == 20, "vpermw zmm");
}

// ---- KAND/KXOR/KNOT/KADD/KTEST ----

void test_kand(void) {
  u32 k1_val = 0xFF00, k2_val = 0x0FF0;
  u32 result;
  __asm__ volatile(
    "kmovw %1, %%k1\n\t"
    "kmovw %2, %%k2\n\t"
    "kandw %%k1, %%k2, %%k3\n\t"
    "kmovw %%k3, %0"
    : "=r"(result) : "r"(k1_val), "r"(k2_val) : "k1", "k2", "k3");
  check((result & 0xFFFF) == 0x0F00, "kandw");
}

void test_kxor(void) {
  u32 k1_val = 0xFF00, k2_val = 0x0FF0;
  u32 result;
  __asm__ volatile(
    "kmovw %1, %%k1\n\t"
    "kmovw %2, %%k2\n\t"
    "kxorw %%k1, %%k2, %%k3\n\t"
    "kmovw %%k3, %0"
    : "=r"(result) : "r"(k1_val), "r"(k2_val) : "k1", "k2", "k3");
  check((result & 0xFFFF) == 0xF0F0, "kxorw");
}

void test_knot(void) {
  u32 k1_val = 0xFF00;
  u32 result;
  __asm__ volatile(
    "kmovw %1, %%k1\n\t"
    "knotw %%k1, %%k2\n\t"
    "kmovw %%k2, %0"
    : "=r"(result) : "r"(k1_val) : "k1", "k2");
  check((result & 0xFFFF) == 0x00FF, "knotw");
}

void test_kadd(void) {
  u32 k1_val = 0x0003, k2_val = 0x0004;
  u32 result;
  __asm__ volatile(
    "kmovw %1, %%k1\n\t"
    "kmovw %2, %%k2\n\t"
    "kaddw %%k1, %%k2, %%k3\n\t"
    "kmovw %%k3, %0"
    : "=r"(result) : "r"(k1_val), "r"(k2_val) : "k1", "k2", "k3");
  check((result & 0xFFFF) == 0x0007, "kaddw");
}

void test_kshiftl(void) {
  u32 k1_val = 0x0001;
  u32 result;
  __asm__ volatile(
    "kmovw %1, %%k1\n\t"
    "kshiftlw $4, %%k1, %%k2\n\t"
    "kmovw %%k2, %0"
    : "=r"(result) : "r"(k1_val) : "k1", "k2");
  check((result & 0xFFFF) == 0x0010, "kshiftlw");
}

void test_kshiftr(void) {
  u32 k1_val = 0x8000;
  u32 result;
  __asm__ volatile(
    "kmovw %1, %%k1\n\t"
    "kshiftrw $4, %%k1, %%k2\n\t"
    "kmovw %%k2, %0"
    : "=r"(result) : "r"(k1_val) : "k1", "k2");
  check((result & 0xFFFF) == 0x0800, "kshiftrw");
}

// ---- VPERMQ imm8 ----

void test_vpermq_imm_512(void) {
  typedef long long v8di __attribute__((vector_size(64)));
  v8di src = {10, 20, 30, 40, 50, 60, 70, 80};
  BARRIER(src);
  v8di dst;
  // imm8 = 0x39 = 00 11 10 01 → lane0=src[1], lane1=src[2], lane2=src[3], lane3=src[0]
  // But VPERMQ works per 256-bit lane: low 4 qwords permuted by imm, high 4 qwords permuted by imm
  __asm__ volatile("vpermq $0x39, %1, %0" : "=v"(dst) : "v"(src));
  // Low 256: {10,20,30,40} permuted by 0x39 = 00_11_10_01
  //   dst[0]=src[1]=20, dst[1]=src[2]=30, dst[2]=src[3]=40, dst[3]=src[0]=10
  check(dst[0] == 20 && dst[1] == 30 && dst[2] == 40 && dst[3] == 10, "vpermq imm zmm lo");
  // High 256: {50,60,70,80} permuted same way
  check(dst[4] == 60 && dst[5] == 70 && dst[6] == 80 && dst[7] == 50, "vpermq imm zmm hi");
}

// ---- VALIGND ----

void test_valignd_512(void) {
  typedef int v16si __attribute__((vector_size(64)));
  v16si a = {0,1,2,3, 4,5,6,7, 8,9,10,11, 12,13,14,15};
  v16si b = {100,101,102,103, 104,105,106,107, 108,109,110,111, 112,113,114,115};
  BARRIER(a); BARRIER(b);
  v16si dst;
  // VALIGND concatenates b:a and shifts right by imm dwords
  // imm8=1: result = (b:a >> 1_dword)
  // So dst[0]=a[1], dst[1]=a[2], ..., dst[14]=a[15], dst[15]=b[0]
  __asm__ volatile("valignd $1, %2, %1, %0" : "=v"(dst) : "v"(b), "v"(a));
  check(dst[0] == 1 && dst[14] == 15 && dst[15] == 100, "valignd zmm imm=1");
}

// ---- VPERMILPS imm8 ----

void test_vpermilps_imm_512(void) {
  typedef float v16sf __attribute__((vector_size(64)));
  v16sf src = {1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f,
               9.0f, 10.0f, 11.0f, 12.0f, 13.0f, 14.0f, 15.0f, 16.0f};
  BARRIER(src);
  v16sf dst;
  // imm8 = 0x1B = 00_01_10_11 → each 128-bit lane: [3,2,1,0]
  __asm__ volatile("vpermilps $0x1B, %1, %0" : "=v"(dst) : "v"(src));
  // Lane 0: {4,3,2,1}
  check(dst[0] == 4.0f && dst[1] == 3.0f && dst[2] == 2.0f && dst[3] == 1.0f, "vpermilps imm zmm lane0");
}

// ---- VPALIGNR ----

void test_vpalignr_512(void) {
  typedef unsigned char v64qu __attribute__((vector_size(64)));
  v64qu a, b, dst;
  // Fill a with 0..63, b with 100..163
  for (int i = 0; i < 64; i++) {
    ((unsigned char*)&a)[i] = i;
    ((unsigned char*)&b)[i] = 100 + i;
  }
  BARRIER(a); BARRIER(b);
  // VPALIGNR concatenates per 128-bit lane and shifts right by imm bytes
  // imm=1: each lane: (a_lane : b_lane) >> 1 byte
  __asm__ volatile("vpalignr $1, %2, %1, %0" : "=v"(dst) : "v"(a), "v"(b));
  // Lane 0: b={100..115}, a={0..15}. Concat = {a[0]..a[15] : b[0]..b[15]} = 32 bytes.
  // Shift right 1 byte: result[0]=b[1]=101, result[15]=a[0]=0
  check(((unsigned char*)&dst)[0] == 101 && ((unsigned char*)&dst)[15] == 0, "vpalignr zmm lane0");
}

void test_vrndscaleps_512(void) {
  typedef float v16sf __attribute__((vector_size(64)));
  v16sf a, dst;
  // 1.7f rounded to nearest integer = 2.0f
  for (int i = 0; i < 16; i++) ((float*)&a)[i] = 1.7f;
  BARRIER(a);
  // imm8=0x00: round to nearest, M=0 (integer)
  __asm__ volatile("vrndscaleps $0, %1, %0" : "=v"(dst) : "v"(a));
  check(((float*)&dst)[0] == 2.0f, "vrndscaleps zmm nearest");
}

void test_vrndscalepd_512(void) {
  typedef double v8df __attribute__((vector_size(64)));
  v8df a, dst;
  for (int i = 0; i < 8; i++) ((double*)&a)[i] = 2.3;
  BARRIER(a);
  // imm8=0x04: round down (floor), M=0
  __asm__ volatile("vrndscalepd $4, %1, %0" : "=v"(dst) : "v"(a));
  check(((double*)&dst)[0] == 2.0, "vrndscalepd zmm floor");
}

void test_vscalefps_512(void) {
  typedef float v16sf __attribute__((vector_size(64)));
  v16sf a, b, dst;
  // a = 1.5, b = 2.0 → result = 1.5 * 2^floor(2.0) = 1.5 * 4 = 6.0
  for (int i = 0; i < 16; i++) {
    ((float*)&a)[i] = 1.5f;
    ((float*)&b)[i] = 2.0f;
  }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vscalefps %2, %1, %0" : "=v"(dst) : "v"(a), "v"(b));
  check(((float*)&dst)[0] == 6.0f, "vscalefps zmm");
}

void test_vgetexpps_512(void) {
  typedef float v16sf __attribute__((vector_size(64)));
  v16sf a, dst;
  // getexp(8.0) = 3.0 (since 8 = 1.0 * 2^3)
  for (int i = 0; i < 16; i++) ((float*)&a)[i] = 8.0f;
  BARRIER(a);
  __asm__ volatile("vgetexpps %1, %0" : "=v"(dst) : "v"(a));
  check(((float*)&dst)[0] == 3.0f, "vgetexpps zmm");
}

void test_vrcp14ps_512(void) {
  typedef float v16sf __attribute__((vector_size(64)));
  v16sf a, dst;
  // rcp14(4.0) ≈ 0.25
  for (int i = 0; i < 16; i++) ((float*)&a)[i] = 4.0f;
  BARRIER(a);
  __asm__ volatile("vrcp14ps %1, %0" : "=v"(dst) : "v"(a));
  // Allow some tolerance for approximate reciprocal
  float r = ((float*)&dst)[0];
  check(r > 0.249f && r < 0.251f, "vrcp14ps zmm");
}

void test_vrsqrt14ps_512(void) {
  typedef float v16sf __attribute__((vector_size(64)));
  v16sf a, dst;
  // rsqrt14(4.0) ≈ 0.5
  for (int i = 0; i < 16; i++) ((float*)&a)[i] = 4.0f;
  BARRIER(a);
  __asm__ volatile("vrsqrt14ps %1, %0" : "=v"(dst) : "v"(a));
  float r = ((float*)&dst)[0];
  check(r > 0.499f && r < 0.501f, "vrsqrt14ps zmm");
}

void test_vshuff32x4_512(void) {
  typedef unsigned int v16su __attribute__((vector_size(64)));
  v16su a, b, dst;
  // a: lane0={0,1,2,3}, lane1={4,5,6,7}, lane2={8,9,10,11}, lane3={12,13,14,15}
  // b: lane0={100,101,102,103}, lane1={104,105,106,107}, lane2={108,...}, lane3={112,...}
  for (int i = 0; i < 16; i++) {
    ((unsigned int*)&a)[i] = i;
    ((unsigned int*)&b)[i] = 100 + i;
  }
  BARRIER(a); BARRIER(b);
  // imm=0x00: dst[0]=a.lane0, dst[1]=a.lane0, dst[2]=b.lane0, dst[3]=b.lane0
  __asm__ volatile("vshufi32x4 $0, %2, %1, %0" : "=v"(dst) : "v"(a), "v"(b));
  check(((unsigned int*)&dst)[0] == 0 && ((unsigned int*)&dst)[8] == 100, "vshufi32x4 zmm");
}

void test_vdbpsadbw_512(void) {
  typedef unsigned short v32hu __attribute__((vector_size(64)));
  typedef unsigned char v64qu __attribute__((vector_size(64)));
  v64qu a, b;
  v32hu dst;
  // Simple test: all zeros should give zero differences
  for (int i = 0; i < 64; i++) {
    ((unsigned char*)&a)[i] = 0;
    ((unsigned char*)&b)[i] = 0;
  }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vdbpsadbw $0, %2, %1, %0" : "=v"(dst) : "v"(a), "v"(b));
  check(((unsigned short*)&dst)[0] == 0, "vdbpsadbw zmm zeros");
}

void test_vexpandps_512(void) {
  typedef float v16sf __attribute__((vector_size(64)));
  v16sf src, dst;
  // src has contiguous data: 1.0, 2.0, 3.0, ...
  for (int i = 0; i < 16; i++) ((float*)&src)[i] = (float)(i + 1);
  for (int i = 0; i < 16; i++) ((float*)&dst)[i] = 0.0f;
  BARRIER(src); BARRIER(dst);
  // mask k1 = 0x0005 (bits 0 and 2 set) → expand src[0]→dst[0], src[1]→dst[2]
  u32 mask = 0x0005;
  __asm__ volatile("kmovw %0, %%k1" : : "r"(mask) : "k1");
  __asm__ volatile("vexpandps %1, %0 %{%%k1%}%{z%}" : "=v"(dst) : "v"(src));
  check(((float*)&dst)[0] == 1.0f && ((float*)&dst)[2] == 2.0f && ((float*)&dst)[1] == 0.0f, "vexpandps zmm k1=0x5");
}

void test_vcompressps_512(void) {
  typedef float v16sf __attribute__((vector_size(64)));
  v16sf src, dst;
  // src[0]=10, src[1]=20, src[2]=30, src[3]=40, ...
  for (int i = 0; i < 16; i++) ((float*)&src)[i] = (float)((i + 1) * 10);
  for (int i = 0; i < 16; i++) ((float*)&dst)[i] = 0.0f;
  BARRIER(src); BARRIER(dst);
  // mask k1 = 0x0005 (bits 0 and 2) → compress src[0] and src[2] to dst[0], dst[1]
  u32 mask = 0x0005;
  __asm__ volatile("kmovw %0, %%k1" : : "r"(mask) : "k1");
  __asm__ volatile("vcompressps %1, %0 %{%%k1%}%{z%}" : "=v"(dst) : "v"(src));
  check(((float*)&dst)[0] == 10.0f && ((float*)&dst)[1] == 30.0f, "vcompressps zmm k1=0x5");
}

void test_vplzcntd_512(void) {
  typedef unsigned int v16su __attribute__((vector_size(64)));
  v16su a, dst;
  // lzcnt(1) = 31, lzcnt(0x80000000) = 0, lzcnt(0) = 32
  for (int i = 0; i < 16; i++) ((unsigned int*)&a)[i] = 1;
  BARRIER(a);
  __asm__ volatile("vplzcntd %1, %0" : "=v"(dst) : "v"(a));
  check(((unsigned int*)&dst)[0] == 31, "vplzcntd zmm");
}

void test_vpconflictd_512(void) {
  typedef unsigned int v16su __attribute__((vector_size(64)));
  v16su a, dst;
  // a = {42, 99, 42, 99, ...} — elements 0,2 conflict, elements 1,3 conflict
  for (int i = 0; i < 16; i++) ((unsigned int*)&a)[i] = (i % 2 == 0) ? 42 : 99;
  BARRIER(a);
  __asm__ volatile("vpconflictd %1, %0" : "=v"(dst) : "v"(a));
  // Element 0: no preceding matches → 0
  // Element 1: no preceding matches → 0
  // Element 2: matches element 0 → bit 0 set → 1
  // Element 3: matches element 1 → bit 1 set → 2
  check(((unsigned int*)&dst)[0] == 0 && ((unsigned int*)&dst)[2] == 1 && ((unsigned int*)&dst)[3] == 2, "vpconflictd zmm");
}

void test_vrangeps_512(void) {
  typedef float v16sf __attribute__((vector_size(64)));
  v16sf a, b, dst;
  // VRANGEPS with imm=0 (min operation)
  for (int i = 0; i < 16; i++) {
    ((float*)&a)[i] = 3.0f;
    ((float*)&b)[i] = 1.0f;
  }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vrangeps $0, %2, %1, %0" : "=v"(dst) : "v"(a), "v"(b));
  check(((float*)&dst)[0] == 1.0f, "vrangeps zmm min");
}

void test_vfpclassps_512(void) {
  typedef float v16sf __attribute__((vector_size(64)));
  typedef unsigned int v16su __attribute__((vector_size(64)));
  v16sf a;
  // Set element 0 to +0.0 (class bit 1), rest to 1.0 (normal)
  for (int i = 0; i < 16; i++) ((float*)&a)[i] = 1.0f;
  ((float*)&a)[0] = 0.0f;
  BARRIER(a);
  u32 result;
  // imm=0x02 tests for +0
  __asm__ volatile("vfpclassps $0x02, %0, %%k1" : : "v"(a) : "k1");
  __asm__ volatile("kmovw %%k1, %0" : "=r"(result));
  check(result == 1, "vfpclassps zmm +zero");
}

void test_vpmovdb_512(void) {
  typedef unsigned int v16su __attribute__((vector_size(64)));
  typedef unsigned char v16qu __attribute__((vector_size(16)));
  v16su a;
  v16qu dst;
  // Each dword truncated to byte: 0x100→0x00, 0x1FF→0xFF, 0x42→0x42, etc.
  for (int i = 0; i < 16; i++) ((unsigned int*)&a)[i] = i * 17;
  BARRIER(a);
  __asm__ volatile("vpmovdb %1, %0" : "=v"(dst) : "v"(a));
  // Element 0: 0*17=0 → byte 0, Element 1: 17 → 17, Element 15: 255 → 255
  check(((unsigned char*)&dst)[0] == 0 && ((unsigned char*)&dst)[1] == 17 && ((unsigned char*)&dst)[15] == (unsigned char)(15*17), "vpmovdb zmm");
}

void test_vpmovswb_512(void) {
  typedef short v32hi __attribute__((vector_size(64)));
  typedef signed char v32qi __attribute__((vector_size(32)));
  v32hi a;
  v32qi dst;
  // Signed saturation: 200 → 127, -200 → -128, 50 → 50
  for (int i = 0; i < 32; i++) ((short*)&a)[i] = 200;
  ((short*)&a)[1] = -200;
  ((short*)&a)[2] = 50;
  BARRIER(a);
  __asm__ volatile("vpmovswb %1, %0" : "=v"(dst) : "v"(a));
  check(((signed char*)&dst)[0] == 127 && ((signed char*)&dst)[1] == -128 && ((signed char*)&dst)[2] == 50, "vpmovswb zmm sat");
}

void test_vpmovm2d_512(void) {
  typedef unsigned int v16su __attribute__((vector_size(64)));
  v16su dst;
  // Set k1 = 0x0005 (bits 0 and 2)
  u32 mask = 0x0005;
  __asm__ volatile("kmovw %0, %%k1" : : "r"(mask) : "k1");
  // VPMOVM2D: each dword = 0xFFFFFFFF if mask bit set, else 0
  __asm__ volatile("vpmovm2d %%k1, %0" : "=v"(dst));
  check(((unsigned int*)&dst)[0] == 0xFFFFFFFF && ((unsigned int*)&dst)[1] == 0 && ((unsigned int*)&dst)[2] == 0xFFFFFFFF, "vpmovm2d zmm");
}

void test_vpmovd2m_512(void) {
  typedef int v16si __attribute__((vector_size(64)));
  v16si a;
  // Set MSBs: elements 0,2,4 are negative
  for (int i = 0; i < 16; i++) ((int*)&a)[i] = (i % 2 == 0) ? -1 : 1;
  BARRIER(a);
  u32 result;
  __asm__ volatile("vpmovd2m %0, %%k1" : : "v"(a) : "k1");
  __asm__ volatile("kmovw %%k1, %0" : "=r"(result));
  // Bits 0,2,4,6,8,10,12,14 set = 0x5555
  check(result == 0x5555, "vpmovd2m zmm");
}

void test_vpdpbusd_512(void) {
  typedef unsigned int v16su __attribute__((vector_size(64)));
  v16su a, b, dst;
  // a = unsigned bytes: {1,1,1,1, ...} for each dword
  // b = signed bytes: {2,2,2,2, ...} for each dword
  // Result per dword: 0 + 1*2 + 1*2 + 1*2 + 1*2 = 8
  for (int i = 0; i < 16; i++) {
    ((unsigned int*)&a)[i] = 0x01010101;
    ((unsigned int*)&b)[i] = 0x02020202;
    ((unsigned int*)&dst)[i] = 0;
  }
  BARRIER(a); BARRIER(b); BARRIER(dst);
  __asm__ volatile("vpdpbusd %2, %1, %0" : "+v"(dst) : "v"(a), "v"(b));
  check(((unsigned int*)&dst)[0] == 8, "vpdpbusd zmm");
}

void test_vpdpwssd_512(void) {
  typedef unsigned int v16su __attribute__((vector_size(64)));
  v16su a, b, dst;
  // a = signed words: {3, 3} per dword = 0x00030003
  // b = signed words: {4, 4} per dword = 0x00040004
  // Result per dword: 0 + 3*4 + 3*4 = 24
  for (int i = 0; i < 16; i++) {
    ((unsigned int*)&a)[i] = 0x00030003;
    ((unsigned int*)&b)[i] = 0x00040004;
    ((unsigned int*)&dst)[i] = 0;
  }
  BARRIER(a); BARRIER(b); BARRIER(dst);
  __asm__ volatile("vpdpwssd %2, %1, %0" : "+v"(dst) : "v"(a), "v"(b));
  check(((unsigned int*)&dst)[0] == 24, "vpdpwssd zmm");
}

void test_vpopcntd_512(void) {
  typedef unsigned int v16su __attribute__((vector_size(64)));
  v16su src, dst;
  // 0x0F0F0F0F has 16 ones, 0xFFFFFFFF has 32, 0x00000001 has 1, 0 has 0
  for (int i = 0; i < 16; i++) ((unsigned int*)&src)[i] = 0x0F0F0F0F;
  ((unsigned int*)&src)[1] = 0xFFFFFFFF;
  ((unsigned int*)&src)[2] = 0x00000001;
  ((unsigned int*)&src)[3] = 0x00000000;
  BARRIER(src);
  __asm__ volatile("vpopcntd %1, %0" : "=v"(dst) : "v"(src));
  check(((unsigned int*)&dst)[0] == 16, "vpopcntd zmm [0]=16");
  check(((unsigned int*)&dst)[1] == 32, "vpopcntd zmm [1]=32");
  check(((unsigned int*)&dst)[2] == 1,  "vpopcntd zmm [2]=1");
  check(((unsigned int*)&dst)[3] == 0,  "vpopcntd zmm [3]=0");
}

void test_vpopcntq_512(void) {
  typedef unsigned long long v8du __attribute__((vector_size(64)));
  v8du src, dst;
  for (int i = 0; i < 8; i++) ((unsigned long long*)&src)[i] = 0x0F0F0F0F0F0F0F0FULL;
  ((unsigned long long*)&src)[1] = 0xFFFFFFFFFFFFFFFFULL;
  ((unsigned long long*)&src)[2] = 0x0000000000000001ULL;
  BARRIER(src);
  __asm__ volatile("vpopcntq %1, %0" : "=v"(dst) : "v"(src));
  check(((unsigned long long*)&dst)[0] == 32, "vpopcntq zmm [0]=32");
  check(((unsigned long long*)&dst)[1] == 64, "vpopcntq zmm [1]=64");
  check(((unsigned long long*)&dst)[2] == 1,  "vpopcntq zmm [2]=1");
}

void test_vcvtph2ps_256(void) {
  // FP16 for 1.0 = 0x3C00, 2.0 = 0x4000, 0.5 = 0x3800, -1.0 = 0xBC00
  typedef unsigned short v8hu __attribute__((vector_size(16)));
  typedef float v8sf __attribute__((vector_size(32)));
  v8hu src;
  v8sf dst;
  ((unsigned short*)&src)[0] = 0x3C00; // 1.0
  ((unsigned short*)&src)[1] = 0x4000; // 2.0
  ((unsigned short*)&src)[2] = 0x3800; // 0.5
  ((unsigned short*)&src)[3] = 0xBC00; // -1.0
  ((unsigned short*)&src)[4] = 0x0000; // +0.0
  ((unsigned short*)&src)[5] = 0x7C00; // +Inf
  ((unsigned short*)&src)[6] = 0x4200; // 3.0
  ((unsigned short*)&src)[7] = 0x4400; // 4.0
  BARRIER(src);
  __asm__ volatile("vcvtph2ps %1, %0" : "=v"(dst) : "v"(src));
  check(((float*)&dst)[0] == 1.0f, "vcvtph2ps [0]=1.0");
  check(((float*)&dst)[1] == 2.0f, "vcvtph2ps [1]=2.0");
  check(((float*)&dst)[2] == 0.5f, "vcvtph2ps [2]=0.5");
  check(((float*)&dst)[3] == -1.0f, "vcvtph2ps [3]=-1.0");
}

void test_vcvtps2ph_256(void) {
  typedef float v8sf __attribute__((vector_size(32)));
  typedef unsigned short v8hu __attribute__((vector_size(16)));
  v8sf src;
  v8hu dst;
  ((float*)&src)[0] = 1.0f;
  ((float*)&src)[1] = 2.0f;
  ((float*)&src)[2] = 0.5f;
  ((float*)&src)[3] = -1.0f;
  ((float*)&src)[4] = 0.0f;
  ((float*)&src)[5] = 3.0f;
  ((float*)&src)[6] = 4.0f;
  ((float*)&src)[7] = 8.0f;
  BARRIER(src);
  // imm8=0 means round according to MXCSR (we use truncation in our impl)
  __asm__ volatile("vcvtps2ph $0, %1, %0" : "=v"(dst) : "v"(src));
  check(((unsigned short*)&dst)[0] == 0x3C00, "vcvtps2ph [0]=1.0→0x3C00");
  check(((unsigned short*)&dst)[1] == 0x4000, "vcvtps2ph [1]=2.0→0x4000");
  check(((unsigned short*)&dst)[2] == 0x3800, "vcvtps2ph [2]=0.5→0x3800");
  check(((unsigned short*)&dst)[3] == 0xBC00, "vcvtps2ph [3]=-1.0→0xBC00");
}

void test_vpgatherdd_512(void) {
  unsigned int arr[16] __attribute__((aligned(64)));
  for (int i = 0; i < 16; i++) arr[i] = (i + 1) * 100;
  typedef unsigned int v16su __attribute__((vector_size(64)));
  v16su indices;
  for (int i = 0; i < 16; i++) ((unsigned int*)&indices)[i] = i;
  unsigned int result[16] __attribute__((aligned(64)));
  BARRIER(indices);
  __asm__ volatile(
    "mov $0xFFFF, %%eax\n\t"
    "kmovw %%eax, %%k1\n\t"
    "vpxord %%zmm1, %%zmm1, %%zmm1\n\t"
    "vmovdqa32 %1, %%zmm2\n\t"
    "vpgatherdd (%2, %%zmm2, 4), %%zmm1 %{%%k1%}\n\t"
    "vmovdqa32 %%zmm1, %0"
    : "=m"(result)
    : "m"(indices), "r"(arr)
    : "eax", "k1", "zmm1", "zmm2"
  );
  check(result[0] == 100, "vpgatherdd zmm [0]=100");
  check(result[7] == 800, "vpgatherdd zmm [7]=800");
  check(result[15] == 1600, "vpgatherdd zmm [15]=1600");
}

void test_vpscatterdd_512(void) {
  unsigned int arr[16] __attribute__((aligned(64)));
  for (int i = 0; i < 16; i++) arr[i] = 0;
  unsigned int indices_arr[16] __attribute__((aligned(64)));
  unsigned int src_arr[16] __attribute__((aligned(64)));
  for (int i = 0; i < 16; i++) {
    indices_arr[i] = 15 - i;  // reverse scatter
    src_arr[i] = (i + 1) * 10;
  }
  __asm__ volatile(
    "mov $0xFFFF, %%eax\n\t"
    "kmovw %%eax, %%k1\n\t"
    "vmovdqa32 %1, %%zmm1\n\t"
    "vmovdqa32 %2, %%zmm2\n\t"
    "vpscatterdd %%zmm2, (%0, %%zmm1, 4) %{%%k1%}"
    :
    : "r"(arr), "m"(indices_arr), "m"(src_arr)
    : "eax", "k1", "zmm1", "zmm2", "memory"
  );
  check(arr[15] == 10, "vpscatterdd zmm arr[15]=10");
  check(arr[0] == 160, "vpscatterdd zmm arr[0]=160");
}

void test_vpclmulqdq_512(void) {
  typedef unsigned long long v8du __attribute__((vector_size(64)));
  v8du a, b, dst;
  // Simple test: clmul(1, x) = x for carry-less multiply
  for (int i = 0; i < 8; i++) {
    ((unsigned long long*)&a)[i] = 1;
    ((unsigned long long*)&b)[i] = 0x123456789ABCDEF0ULL;
  }
  BARRIER(a); BARRIER(b);
  // imm8=0x00: select low qword from both
  __asm__ volatile("vpclmulqdq $0, %2, %1, %0" : "=v"(dst) : "v"(a), "v"(b));
  // clmul(1, X) = X
  check(((unsigned long long*)&dst)[0] == 0x123456789ABCDEF0ULL, "vpclmulqdq zmm clmul(1,x)=x");
}

void test_vpshldd_512(void) {
  typedef unsigned int v16su __attribute__((vector_size(64)));
  v16su a, b, dst;
  // VPSHLDD: dst = (src1:src2) << imm8[4:0], take high 32 bits
  // With src1=0x12345678, src2=0xABCDEF00, shift=4:
  // concat = 0x12345678_ABCDEF00, << 4 = 0x2345678A_BCDEF000, high32 = 0x2345678A
  for (int i = 0; i < 16; i++) {
    ((unsigned int*)&a)[i] = 0x12345678;
    ((unsigned int*)&b)[i] = 0xABCDEF00;
  }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vpshldd $4, %2, %1, %0" : "=v"(dst) : "v"(a), "v"(b));
  check(((unsigned int*)&dst)[0] == 0x2345678A, "vpshldd zmm shift=4");
}

void test_gf2p8mulb_512(void) {
  typedef unsigned char v64qu __attribute__((vector_size(64)));
  v64qu a, b, dst;
  // Multiply by 1 in GF(2^8) should give identity
  for (int i = 0; i < 64; i++) {
    ((unsigned char*)&a)[i] = (unsigned char)(i + 1);
    ((unsigned char*)&b)[i] = 1;
  }
  BARRIER(a); BARRIER(b);
  __asm__ volatile("vgf2p8mulb %2, %1, %0" : "=v"(dst) : "v"(a), "v"(b));
  check(((unsigned char*)&dst)[0] == 1, "vgf2p8mulb zmm mul-by-1 [0]=1");
  check(((unsigned char*)&dst)[41] == 42, "vgf2p8mulb zmm mul-by-1 [41]=42");
}

void test_vexp2ps_512(void) {
  typedef float v16sf __attribute__((vector_size(64)));
  v16sf src, dst;
  // 2^0 = 1.0, 2^1 = 2.0, 2^2 = 4.0, 2^(-1) = 0.5
  for (int i = 0; i < 16; i++) ((float*)&src)[i] = 0.0f;
  ((float*)&src)[0] = 0.0f;
  ((float*)&src)[1] = 1.0f;
  ((float*)&src)[2] = 2.0f;
  ((float*)&src)[3] = -1.0f;
  BARRIER(src);
  __asm__ volatile("vexp2ps %1, %0" : "=v"(dst) : "v"(src));
  // Check results: 2^0=1, 2^1=2, 2^2=4, 2^(-1)=0.5
  check(((unsigned*)&dst)[0] == 0x3F800000u, "vexp2ps zmm 2^0=1.0");
  check(((unsigned*)&dst)[1] == 0x40000000u, "vexp2ps zmm 2^1=2.0");
  check(((unsigned*)&dst)[2] == 0x40800000u, "vexp2ps zmm 2^2=4.0");
  check(((unsigned*)&dst)[3] == 0x3F000000u, "vexp2ps zmm 2^-1=0.5");
}

void test_vrcp28ps_512(void) {
  typedef float v16sf __attribute__((vector_size(64)));
  v16sf src, dst;
  for (int i = 0; i < 16; i++) ((float*)&src)[i] = 1.0f;
  ((float*)&src)[0] = 1.0f;   // 1/1 = 1.0
  ((float*)&src)[1] = 2.0f;   // 1/2 = 0.5
  ((float*)&src)[2] = 4.0f;   // 1/4 = 0.25
  BARRIER(src);
  __asm__ volatile("vrcp28ps %1, %0" : "=v"(dst) : "v"(src));
  check(((unsigned*)&dst)[0] == 0x3F800000u, "vrcp28ps zmm 1/1=1.0");
  check(((unsigned*)&dst)[1] == 0x3F000000u, "vrcp28ps zmm 1/2=0.5");
  check(((unsigned*)&dst)[2] == 0x3E800000u, "vrcp28ps zmm 1/4=0.25");
}

void test_vrsqrt28ps_512(void) {
  typedef float v16sf __attribute__((vector_size(64)));
  v16sf src, dst;
  for (int i = 0; i < 16; i++) ((float*)&src)[i] = 1.0f;
  ((float*)&src)[0] = 1.0f;   // 1/sqrt(1) = 1.0
  ((float*)&src)[1] = 4.0f;   // 1/sqrt(4) = 0.5
  BARRIER(src);
  __asm__ volatile("vrsqrt28ps %1, %0" : "=v"(dst) : "v"(src));
  check(((unsigned*)&dst)[0] == 0x3F800000u, "vrsqrt28ps zmm 1/sqrt(1)=1.0");
  check(((unsigned*)&dst)[1] == 0x3F000000u, "vrsqrt28ps zmm 1/sqrt(4)=0.5");
}

void test_vcmpph_512(void) {
  typedef unsigned short v32hu __attribute__((vector_size(64)));
  v32hu a, b;
  // FP16: 1.0=0x3C00, 2.0=0x4000, 0.5=0x3800
  for (int i = 0; i < 32; i++) {
    ((unsigned short*)&a)[i] = 0x3C00;  // all 1.0
    ((unsigned short*)&b)[i] = 0x3C00;  // all 1.0
  }
  ((unsigned short*)&b)[0] = 0x4000;  // b[0] = 2.0 (a < b)
  ((unsigned short*)&b)[1] = 0x3800;  // b[1] = 0.5 (a > b)
  BARRIER(a); BARRIER(b);
  unsigned int mask;
  // vcmpeqph: predicate 0 = EQ
  __asm__ volatile("vcmpeqph %2, %1, %%k1\n\t"
                   "kmovd %%k1, %0"
                   : "=r"(mask) : "v"(a), "v"(b) : "k1");
  // Elements 0 and 1 are not equal, rest are equal
  check((mask & 1) == 0, "vcmpph zmm eq [0] (1!=2)");
  check((mask & 2) == 0, "vcmpph zmm eq [1] (1!=0.5)");
  check((mask & 4) != 0, "vcmpph zmm eq [2] (1==1)");
}

void test_vgatherpf0dps(void) {
  // Gather prefetch is a NOP in our simulator — just verify it doesn't crash
  typedef int v16si __attribute__((vector_size(64)));
  volatile int arr[16];
  for (int i = 0; i < 16; i++) arr[i] = i;
  v16si idx;
  for (int i = 0; i < 16; i++) ((int*)&idx)[i] = i * 4;
  BARRIER(idx);
  unsigned int k = 0xFFFF;
  __asm__ volatile("kmovw %k1, %%k1\n\t"
                   "vgatherpf0dps (%0, %2, 1) %{%%k1%}"
                   : : "r"(arr), "r"(k), "v"(idx) : "k1", "memory");
  check(1, "vgatherpf0dps no-crash");
}

// =========================================================================
// Entry point
// =========================================================================

void __attribute__((force_align_arg_pointer)) _start(void) {
  print("TAP version 13\n");
  print("1..194\n");

  test_vmovups_512();
  test_vmovaps_512();
  test_vaddps_512();
  test_vsubps_512();
  test_vmulps_512();
  test_vaddpd_512();
  test_vsubpd_512();
  test_vmulpd_512();
  test_vpxord_512();
  test_vpandd_512();
  test_vpord_512();
  test_vpaddd_512();
  test_vpsubd_512();
  test_vpaddq_512();
  test_vpsubq_512();
  test_vmovdqa32_512();
  test_vxorps_512();
  test_vpaddsb_512();
  test_vpsubsb_512();
  test_vpaddusb_512();
  test_vpsubusb_512();
  test_vpaddw_512();
  test_vpsubw_512();
  test_vpmullw_512();
  test_vpmaxub_512();
  test_vpminsw_512();
  test_vpavgb_512();
  test_vpmuludq_512();
  test_vpmaddwd_512();
  test_vpsadbw_512();
  test_vsqrtps_512();
  test_vdivps_512();
  test_vminps_512();
  test_vmaxps_512();
  test_vpandnd_512();
  test_vpunpcklbw_512();
  test_vpunpckhbw_512();
  test_vpunpckldq_512();
  test_vpunpcklqdq_512();
  test_vpacksswb_512();
  test_vpackuswb_512();
  test_vpshufd_512();
  test_vpshufhw_512();
  test_vpshuflw_512();
  test_vpslld_imm_512();
  test_vpsrld_imm_512();
  test_vpsrad_imm_512();
  test_vpsllq_imm_512();
  test_vpslldq_512();
  test_vpsrldq_512();
  test_vpsllw_xmm_512();
  test_vpunpcklwd_512();
  test_vpunpckhwd_512();
  test_vpunpckhdq_512();
  test_vpunpckhqdq_512();
  test_vpackssdw_512();
  test_vpsrlw_imm_512();
  test_vpsraw_imm_512();
  test_vpsllw_imm_512();
  test_vpsrlq_imm_512();
  test_vpsrlw_xmm_512();
  test_vpsrld_xmm_512();
  test_vpsrlq_xmm_512();
  test_vpsraw_xmm_512();
  test_vpsrad_xmm_512();
  test_vpslld_xmm_512();
  test_vpsllq_xmm_512();
  test_vmovsldup_512();
  test_vmovshdup_512();
  test_vmovddup_512();
  test_vunpcklps_512();
  test_vunpckhps_512();
  test_vunpcklpd_512();
  test_vunpckhpd_512();
  test_vmovlps();
  test_vmovhps();
  test_vmovhlps();
  test_vmovlhps();
  // vmovlps store and vmovhps store tested via load round-trip above
  test_vcvtsi2ss();
  test_vcvtsi2sd();
  test_vcvttss2si();
  test_vcvttsd2si();
  test_vucomiss();
  test_vucomisd();
  test_vcvtps2pd_512();
  test_vcvtpd2ps_512();
  test_vcvtdq2ps_512();
  test_vcvtps2dq_512();
  test_vcvttps2dq_512();
  test_vcvtss2sd();
  test_vcvtsd2ss();
  test_vshufps();
  test_vshufpd();
  test_vcmpps_512();
  test_vcmppd_512();
  test_vcvttps2udq_512();
  test_vcvtudq2ps_512();
  test_vcvtdq2pd_512();
  test_vcvttpd2dq_512();
  test_vpshufb_512();
  test_vpmulld_512();
  test_vpermd_512();
  test_vpinsrw();
  test_vpextrw();
  test_vpmovsxbw_512();
  test_vpmovzxbw_512();
  test_vpmovsxwd_512();
  test_vpmovzxwd_512();
  test_vpmovsxdq_512();
  test_vpmovzxdq_512();
  test_vpsrlvd_512();
  test_vpsravd_512();
  test_vpsllvd_512();
  test_vpermi2d_512();
  test_vprolvd_512();
  test_vpsrlvw_512();
  test_vpabsd_512();
  test_vpminsd_512();
  test_vpmaxsd_512();
  test_vpmaxud_512();
  test_vfmadd231ps_512();
  test_vfmsub231pd_512();
  test_vfnmadd231ps_512();
  test_vfmadd132ps_512();
  test_vpermt2w_512();
  test_vpermw_512();
  test_kand();
  test_kxor();
  test_knot();
  test_kadd();
  test_kshiftl();
  test_kshiftr();
  test_vpermq_imm_512();
  test_valignd_512();
  test_vpermilps_imm_512();
  test_vpalignr_512();
  test_vrndscaleps_512();
  test_vrndscalepd_512();
  test_vscalefps_512();
  test_vgetexpps_512();
  test_vrcp14ps_512();
  test_vrsqrt14ps_512();
  test_vshuff32x4_512();
  test_vdbpsadbw_512();
  test_vexpandps_512();
  test_vcompressps_512();

  test_vplzcntd_512();
  test_vpconflictd_512();
  test_vrangeps_512();
  test_vfpclassps_512();
  test_vpmovdb_512();
  test_vpmovswb_512();
  test_vpmovm2d_512();
  test_vpmovd2m_512();
  test_vpdpbusd_512();
  test_vpdpwssd_512();
  test_vpopcntd_512();
  test_vpopcntq_512();
  test_vcvtph2ps_256();
  test_vcvtps2ph_256();
  test_vpgatherdd_512();
  test_vpscatterdd_512();
  test_vpclmulqdq_512();
  test_vpshldd_512();
  test_gf2p8mulb_512();
  test_vexp2ps_512();
  test_vrcp28ps_512();
  test_vrsqrt28ps_512();
  test_vcmpph_512();
  test_vgatherpf0dps();

  if (fail_count > 0) {
    print("# ");
    print_int(fail_count);
    print(" test(s) FAILED\n");
    syscall1(60, 1);
  } else {
    print("# All tests passed\n");
    syscall1(60, 0);
  }
}

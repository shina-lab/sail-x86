// Test x87 FPU instructions using raw inline assembly (no libc).

typedef unsigned long u64;
typedef long i64;
typedef unsigned int u32;
typedef unsigned short u16;

static i64 syscall3(int nr, u64 a1, u64 a2, u64 a3) {
  i64 ret;
  register u64 r10 __asm__("r10") = 0;
  __asm__ volatile("syscall" : "=a"(ret)
                   : "a"(nr), "D"(a1), "S"(a2), "d"(a3), "r"(r10)
                   : "rcx", "r11", "memory");
  return ret;
}

static i64 syscall1(int nr, u64 a1) {
  i64 ret;
  __asm__ volatile("syscall" : "=a"(ret) : "a"(nr), "D"(a1)
                   : "rcx", "r11", "memory");
  return ret;
}

#define SYS_write 1
#define SYS_exit  60

static int test_num = 0;
static int fail_count = 0;

static void print(const char *s) {
  int len = 0;
  while (s[len]) len++;
  syscall3(SYS_write, 1, (u64)s, len);
}

static void print_int(i64 n) {
  char buf[20];
  int i = 0;
  if (n < 0) { print("-"); n = -n; }
  if (n == 0) { print("0"); return; }
  while (n > 0) { buf[i++] = '0' + (n % 10); n /= 10; }
  char out[20];
  for (int j = 0; j < i; j++) out[j] = buf[i - 1 - j];
  out[i] = 0;
  print(out);
}

static void check(int ok, const char *name) {
  test_num++;
  if (ok) {
    print("ok ");
  } else {
    print("FAIL ");
    fail_count++;
  }
  print_int(test_num);
  print(" - ");
  print(name);
  print("\n");
}

// Compare two doubles for approximate equality.
static int approx_eq(double a, double b) {
  double diff = a - b;
  if (diff < 0) diff = -diff;
  double mag = b;
  if (mag < 0) mag = -mag;
  if (mag < 1e-10) return diff < 1e-10;
  return diff / mag < 1e-9;
}

// ---- Tests ----

static void test_fld_fst(void) {
  // Load a double, store it back.
  double val = 3.14;
  double result;
  __asm__ volatile(
    "fldl %1\n\t"
    "fstpl %0\n\t"
    : "=m"(result) : "m"(val)
  );
  check(approx_eq(result, 3.14), "fld/fstp double round-trip");
}

static void test_fild_fist(void) {
  // Load integer, store as integer.
  int ival = 42;
  int result;
  __asm__ volatile(
    "fildl %1\n\t"
    "fistpl %0\n\t"
    : "=m"(result) : "m"(ival)
  );
  check(result == 42, "fild/fistp i32 round-trip");

  long lval = -12345678;
  long lresult;
  __asm__ volatile(
    "fildq %1\n\t"
    "fistpq %0\n\t"
    : "=m"(lresult) : "m"(lval)
  );
  check(lresult == -12345678, "fild/fistp i64 round-trip");
}

static void test_fadd(void) {
  double a = 1.5, b = 2.5, result;
  __asm__ volatile(
    "fldl %1\n\t"
    "faddl %2\n\t"
    "fstpl %0\n\t"
    : "=m"(result) : "m"(a), "m"(b)
  );
  check(approx_eq(result, 4.0), "fadd 1.5 + 2.5 = 4.0");
}

static void test_fsub(void) {
  double a = 10.0, b = 3.0, result;
  __asm__ volatile(
    "fldl %1\n\t"
    "fsubl %2\n\t"
    "fstpl %0\n\t"
    : "=m"(result) : "m"(a), "m"(b)
  );
  check(approx_eq(result, 7.0), "fsub 10.0 - 3.0 = 7.0");
}

static void test_fmul(void) {
  double a = 3.0, b = 7.0, result;
  __asm__ volatile(
    "fldl %1\n\t"
    "fmull %2\n\t"
    "fstpl %0\n\t"
    : "=m"(result) : "m"(a), "m"(b)
  );
  check(approx_eq(result, 21.0), "fmul 3.0 * 7.0 = 21.0");
}

static void test_fdiv(void) {
  double a = 22.0, b = 7.0, result;
  __asm__ volatile(
    "fldl %1\n\t"
    "fdivl %2\n\t"
    "fstpl %0\n\t"
    : "=m"(result) : "m"(a), "m"(b)
  );
  check(approx_eq(result, 22.0 / 7.0), "fdiv 22.0 / 7.0");
}

static void test_fsqrt(void) {
  double val = 144.0, result;
  __asm__ volatile(
    "fldl %1\n\t"
    "fsqrt\n\t"
    "fstpl %0\n\t"
    : "=m"(result) : "m"(val)
  );
  check(approx_eq(result, 12.0), "fsqrt(144.0) = 12.0");
}

static void test_fabs(void) {
  double val = -5.5, result;
  __asm__ volatile(
    "fldl %1\n\t"
    "fabs\n\t"
    "fstpl %0\n\t"
    : "=m"(result) : "m"(val)
  );
  check(approx_eq(result, 5.5), "fabs(-5.5) = 5.5");
}

static void test_fchs(void) {
  double val = 3.0, result;
  __asm__ volatile(
    "fldl %1\n\t"
    "fchs\n\t"
    "fstpl %0\n\t"
    : "=m"(result) : "m"(val)
  );
  check(approx_eq(result, -3.0), "fchs(3.0) = -3.0");
}

static void test_fxch(void) {
  // Load two values, exchange, store both.
  double a = 1.0, b = 2.0, r1, r2;
  __asm__ volatile(
    "fldl %2\n\t"      // ST(0)=a=1.0
    "fldl %3\n\t"      // ST(0)=b=2.0, ST(1)=a=1.0
    "fxch %%st(1)\n\t" // ST(0)=a=1.0, ST(1)=b=2.0
    "fstpl %0\n\t"     // r1=1.0, ST(0)=b=2.0
    "fstpl %1\n\t"     // r2=2.0
    : "=m"(r1), "=m"(r2) : "m"(a), "m"(b)
  );
  check(approx_eq(r1, 1.0) && approx_eq(r2, 2.0),
        "fxch swaps ST(0) and ST(1)");
}

static void test_fcom(void) {
  // Compare via FCOMIP which sets EFLAGS.
  double a = 5.0, b = 3.0;
  int above, below, equal;

  // a > b
  __asm__ volatile(
    "fldl %3\n\t"
    "fldl %4\n\t"
    "fcomip %%st(1)\n\t"
    "fstp %%st(0)\n\t"
    "seta %%al\n\t"
    "movzbl %%al, %0\n\t"
    "setb %%al\n\t"
    "movzbl %%al, %1\n\t"
    "sete %%al\n\t"
    "movzbl %%al, %2\n\t"
    : "=r"(above), "=r"(below), "=r"(equal)
    : "m"(b), "m"(a)
    : "ax"
  );
  check(above && !below && !equal, "fcomip 5.0 > 3.0");

  // b < a
  __asm__ volatile(
    "fldl %3\n\t"
    "fldl %4\n\t"
    "fcomip %%st(1)\n\t"
    "fstp %%st(0)\n\t"
    "seta %%al\n\t"
    "movzbl %%al, %0\n\t"
    "setb %%al\n\t"
    "movzbl %%al, %1\n\t"
    "sete %%al\n\t"
    "movzbl %%al, %2\n\t"
    : "=r"(above), "=r"(below), "=r"(equal)
    : "m"(a), "m"(b)
    : "ax"
  );
  check(!above && below && !equal, "fcomip 3.0 < 5.0");

  // a == a
  __asm__ volatile(
    "fldl %3\n\t"
    "fldl %4\n\t"
    "fcomip %%st(1)\n\t"
    "fstp %%st(0)\n\t"
    "seta %%al\n\t"
    "movzbl %%al, %0\n\t"
    "setb %%al\n\t"
    "movzbl %%al, %1\n\t"
    "sete %%al\n\t"
    "movzbl %%al, %2\n\t"
    : "=r"(above), "=r"(below), "=r"(equal)
    : "m"(a), "m"(a)
    : "ax"
  );
  check(!above && !below && equal, "fcomip 5.0 == 5.0");
}

static void test_fconst(void) {
  double result;

  // FLD1
  __asm__ volatile("fld1\n\t" "fstpl %0\n\t" : "=m"(result));
  check(approx_eq(result, 1.0), "fld1 = 1.0");

  // FLDZ
  __asm__ volatile("fldz\n\t" "fstpl %0\n\t" : "=m"(result));
  check(approx_eq(result, 0.0), "fldz = 0.0");

  // FLDPI
  __asm__ volatile("fldpi\n\t" "fstpl %0\n\t" : "=m"(result));
  check(approx_eq(result, 3.14159265358979323846), "fldpi ≈ pi");
}

static void test_stack_depth(void) {
  // Push 8 values, pop them all back.
  double vals[8] = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0};
  double results[8];
  __asm__ volatile(
    "fldl 0(%1)\n\t"
    "fldl 8(%1)\n\t"
    "fldl 16(%1)\n\t"
    "fldl 24(%1)\n\t"
    "fldl 32(%1)\n\t"
    "fldl 40(%1)\n\t"
    "fldl 48(%1)\n\t"
    "fldl 56(%1)\n\t"
    // Now ST(0)=8, ST(1)=7, ..., ST(7)=1
    "fstpl 56(%0)\n\t"
    "fstpl 48(%0)\n\t"
    "fstpl 40(%0)\n\t"
    "fstpl 32(%0)\n\t"
    "fstpl 24(%0)\n\t"
    "fstpl 16(%0)\n\t"
    "fstpl 8(%0)\n\t"
    "fstpl 0(%0)\n\t"
    : : "r"(results), "r"(vals) : "memory"
  );
  int ok = 1;
  for (int i = 0; i < 8; i++)
    if (!approx_eq(results[i], vals[i])) ok = 0;
  check(ok, "push/pop 8 values on x87 stack");
}

static void test_fnstcw_fldcw(void) {
  u16 cw;
  __asm__ volatile("fnstcw %0" : "=m"(cw));
  // Default CW should have bits for precision control and rounding.
  // Bits 8-9 = precision control (11 = extended precision = default)
  // Bits 10-11 = rounding control (00 = round to nearest)
  check((cw & 0x0C00) == 0x0000, "default rounding = round-to-nearest");

  // Set rounding to truncate (round toward zero = 0x0C00).
  u16 new_cw = (cw & ~0x0C00) | 0x0C00;
  double val = 2.7;
  int result;
  __asm__ volatile(
    "fldcw %2\n\t"
    "fldl %1\n\t"
    "fistpl %0\n\t"
    "fldcw %3\n\t"  // restore
    : "=m"(result) : "m"(val), "m"(new_cw), "m"(cw)
  );
  check(result == 2, "fldcw truncation: 2.7 -> 2");

  // With default rounding (to nearest), 2.7 rounds to 3.
  __asm__ volatile(
    "fldl %1\n\t"
    "fistpl %0\n\t"
    : "=m"(result) : "m"(val)
  );
  check(result == 3, "default rounding: 2.7 -> 3");
}

static void test_f32_load_store(void) {
  float fval = 1.25f;
  float fresult;
  __asm__ volatile(
    "flds %1\n\t"
    "fstps %0\n\t"
    : "=m"(fresult) : "m"(fval)
  );
  check(fresult == 1.25f, "fld/fstp float32 round-trip");
}

static void test_mixed_arith(void) {
  // (3.0 + 4.0) * 2.0 - 1.0 = 13.0
  double three = 3.0, four = 4.0, two = 2.0, one = 1.0, result;
  __asm__ volatile(
    "fldl %1\n\t"     // ST(0) = 3.0
    "faddl %2\n\t"    // ST(0) = 7.0
    "fmull %3\n\t"    // ST(0) = 14.0
    "fsubl %4\n\t"    // ST(0) = 13.0
    "fstpl %0\n\t"
    : "=m"(result)
    : "m"(three), "m"(four), "m"(two), "m"(one)
  );
  check(approx_eq(result, 13.0), "mixed arith: (3+4)*2-1 = 13");
}

static void test_fiadd(void) {
  // Float + integer
  double a = 10.5;
  int b = 3;
  double result;
  __asm__ volatile(
    "fldl %1\n\t"
    "fiaddl %2\n\t"
    "fstpl %0\n\t"
    : "=m"(result) : "m"(a), "m"(b)
  );
  check(approx_eq(result, 13.5), "fiadd 10.5 + 3 = 13.5");
}

static void test_st_arith(void) {
  // FADD ST(i), ST(0) form
  double a = 5.0, b = 3.0, result;
  __asm__ volatile(
    "fldl %1\n\t"            // ST(0) = b
    "fldl %2\n\t"            // ST(0) = a, ST(1) = b
    "faddp %%st(0), %%st(1)\n\t" // ST(0) = a + b
    "fstpl %0\n\t"
    : "=m"(result) : "m"(b), "m"(a)
  );
  check(approx_eq(result, 8.0), "faddp ST(1),ST(0): 5+3 = 8");
}

static void do_tests(u64 *sp);

__asm__(
  ".globl _start\n"
  "_start:\n"
  "  mov %rsp, %rdi\n"
  "  call do_tests\n"
);

static void do_tests(u64 *sp) {
  print("# x87 FPU tests\n");

  test_fld_fst();
  test_fild_fist();
  test_fadd();
  test_fsub();
  test_fmul();
  test_fdiv();
  test_fsqrt();
  test_fabs();
  test_fchs();
  test_fxch();
  test_fcom();
  test_fconst();
  test_stack_depth();
  test_fnstcw_fldcw();
  test_f32_load_store();
  test_mixed_arith();
  test_fiadd();
  test_st_arith();

  if (fail_count > 0) {
    print("FAILED ");
    print_int(fail_count);
    print(" test(s)\n");
    syscall1(SYS_exit, 1);
  }

  print("All tests passed\n");
  syscall1(SYS_exit, 0);
}

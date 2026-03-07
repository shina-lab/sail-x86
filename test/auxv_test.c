// Test that the auxiliary vector is set up correctly.

typedef unsigned long u64;
typedef long i64;

#define SYS_write 1
#define SYS_exit  60

#define AT_NULL         0
#define AT_PHDR         3
#define AT_PHENT        4
#define AT_PHNUM        5
#define AT_PAGESZ       6
#define AT_BASE         7
#define AT_ENTRY        9
#define AT_UID          11
#define AT_EUID         12
#define AT_GID          13
#define AT_EGID         14
#define AT_PLATFORM     15
#define AT_HWCAP        16
#define AT_SECURE       23
#define AT_RANDOM       25
#define AT_HWCAP2       26
#define AT_EXECFN       31
#define AT_SYSINFO_EHDR 33

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

static int test_num = 0;
static int fail_count = 0;

static void print(const char *s) {
  int len = 0;
  while (s[len]) len++;
  syscall3(SYS_write, 1, (u64)s, len);
}

static void print_hex(u64 n) {
  char buf[19];
  buf[0] = '0'; buf[1] = 'x';
  for (int i = 0; i < 16; i++)
    buf[17 - i] = "0123456789abcdef"[(n >> (i * 4)) & 0xf];
  buf[18] = 0;
  print(buf);
}

static void check(int ok, const char *name) {
  test_num++;
  if (ok) {
    print("ok ");
  } else {
    print("FAIL ");
    fail_count++;
  }
  // print test number
  char buf[20];
  int n = test_num, i = 0;
  if (n == 0) { buf[i++] = '0'; }
  else { while (n > 0) { buf[i++] = '0' + (n % 10); n /= 10; } }
  for (int j = 0; j < i / 2; j++) {
    char t = buf[j]; buf[j] = buf[i-1-j]; buf[i-1-j] = t;
  }
  buf[i] = 0;
  print(buf);
  print(" - ");
  print(name);
  print("\n");
}

static int streq(const char *a, const char *b) {
  while (*a && *b && *a == *b) { a++; b++; }
  return *a == *b;
}

// Find an auxv entry by type. Returns the value, or 0 if not found.
// Sets *found to 1 if found.
static u64 find_auxv(u64 *auxv, u64 type, int *found) {
  for (int i = 0; auxv[i] || auxv[i + 1]; i += 2) {
    if (auxv[i] == type) {
      *found = 1;
      return auxv[i + 1];
    }
  }
  *found = 0;
  return 0;
}

static void do_tests(u64 *sp);

__asm__(
  ".globl _start\n"
  "_start:\n"
  "  mov %rsp, %rdi\n"
  "  call do_tests\n"
);

static void do_tests(u64 *sp) {
  u64 argc = sp[0];
  char **argv = (char **)(sp + 1);
  // skip argv + NULL
  char **p = argv + argc + 1;
  // skip envp + NULL
  while (*p) p++;
  p++;
  u64 *auxv = (u64 *)p;

  print("# auxv tests\n");

  int found;
  u64 val;

  // AT_PHDR should be present and non-zero
  val = find_auxv(auxv, AT_PHDR, &found);
  check(found && val != 0, "AT_PHDR is present and non-zero");

  // AT_PHENT should be reasonable (typically 56 for 64-bit)
  val = find_auxv(auxv, AT_PHENT, &found);
  check(found && val == 56, "AT_PHENT is 56");

  // AT_PHNUM should be non-zero
  val = find_auxv(auxv, AT_PHNUM, &found);
  check(found && val > 0, "AT_PHNUM is positive");

  // AT_PAGESZ should be 4096
  val = find_auxv(auxv, AT_PAGESZ, &found);
  check(found && val == 4096, "AT_PAGESZ is 4096");

  // AT_ENTRY should be non-zero
  val = find_auxv(auxv, AT_ENTRY, &found);
  check(found && val != 0, "AT_ENTRY is present and non-zero");

  // AT_UID/GID/EUID/EGID should be present
  find_auxv(auxv, AT_UID, &found);
  check(found, "AT_UID is present");
  find_auxv(auxv, AT_GID, &found);
  check(found, "AT_GID is present");
  find_auxv(auxv, AT_EUID, &found);
  check(found, "AT_EUID is present");
  find_auxv(auxv, AT_EGID, &found);
  check(found, "AT_EGID is present");

  // AT_PLATFORM should point to "x86_64"
  val = find_auxv(auxv, AT_PLATFORM, &found);
  check(found && streq((const char *)val, "x86_64"), "AT_PLATFORM is x86_64");

  // AT_HWCAP should be non-zero and have basic x86-64 bits
  val = find_auxv(auxv, AT_HWCAP, &found);
  // Check FPU (bit 0), SSE (bit 25), SSE2 (bit 26)
  check(found && (val & ((1 << 0) | (1 << 25) | (1 << 26))) ==
        ((1 << 0) | (1 << 25) | (1 << 26)),
        "AT_HWCAP has FPU+SSE+SSE2");

  // AT_RANDOM should point to 16 non-zero bytes (extremely unlikely all zero)
  val = find_auxv(auxv, AT_RANDOM, &found);
  if (found) {
    unsigned char *r = (unsigned char *)val;
    int any_nonzero = 0;
    for (int i = 0; i < 16; i++)
      if (r[i]) any_nonzero = 1;
    check(any_nonzero, "AT_RANDOM has non-zero bytes");
  } else {
    check(0, "AT_RANDOM is present");
  }

  // AT_SECURE should be present
  find_auxv(auxv, AT_SECURE, &found);
  check(found, "AT_SECURE is present");

  // AT_EXECFN should point to the executable filename (same as argv[0])
  val = find_auxv(auxv, AT_EXECFN, &found);
  check(found && streq((const char *)val, argv[0]),
        "AT_EXECFN matches argv[0]");

  // AT_SYSINFO_EHDR should NOT be present (we filter it out)
  find_auxv(auxv, AT_SYSINFO_EHDR, &found);
  check(!found, "AT_SYSINFO_EHDR is absent");

  if (fail_count > 0) {
    print("FAILED ");
    char buf[4]; int n = fail_count, i = 0;
    while (n > 0) { buf[i++] = '0' + (n % 10); n /= 10; }
    for (int j = 0; j < i / 2; j++) {
      char t = buf[j]; buf[j] = buf[i-1-j]; buf[i-1-j] = t;
    }
    buf[i] = 0;
    print(buf);
    print(" test(s)\n");
    syscall1(SYS_exit, 1);
  }

  print("All tests passed\n");
  syscall1(SYS_exit, 0);
}

// Test various syscalls using raw inline assembly (no libc).

#define NULL ((void *)0)

typedef unsigned long u64;
typedef long i64;
typedef unsigned int u32;

static i64 syscall0(int nr) {
  i64 ret;
  __asm__ volatile("syscall" : "=a"(ret) : "a"(nr) : "rcx", "r11", "memory");
  return ret;
}

static i64 syscall1(int nr, u64 a1) {
  i64 ret;
  __asm__ volatile("syscall" : "=a"(ret) : "a"(nr), "D"(a1)
                   : "rcx", "r11", "memory");
  return ret;
}

static i64 syscall2(int nr, u64 a1, u64 a2) {
  i64 ret;
  __asm__ volatile("syscall" : "=a"(ret) : "a"(nr), "D"(a1), "S"(a2)
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

static i64 syscall4(int nr, u64 a1, u64 a2, u64 a3, u64 a4) {
  i64 ret;
  register u64 r10 __asm__("r10") = a4;
  __asm__ volatile("syscall" : "=a"(ret)
                   : "a"(nr), "D"(a1), "S"(a2), "d"(a3), "r"(r10)
                   : "rcx", "r11", "memory");
  return ret;
}

static i64 syscall6(int nr, u64 a1, u64 a2, u64 a3, u64 a4, u64 a5, u64 a6) {
  i64 ret;
  register u64 r10 __asm__("r10") = a4;
  register u64 r8 __asm__("r8") = a5;
  register u64 r9 __asm__("r9") = a6;
  __asm__ volatile("syscall" : "=a"(ret)
                   : "a"(nr), "D"(a1), "S"(a2), "d"(a3),
                     "r"(r10), "r"(r8), "r"(r9)
                   : "rcx", "r11", "memory");
  return ret;
}

#define SYS_read            0
#define SYS_write           1
#define SYS_close           3
#define SYS_mmap            9
#define SYS_munmap          11
#define SYS_brk             12
#define SYS_pipe            22
#define SYS_mremap          25
#define SYS_dup             32
#define SYS_getpid          39
#define SYS_exit            60
#define SYS_fcntl           72
#define SYS_getcwd          79
#define SYS_getuid          102
#define SYS_getgid          104
#define SYS_geteuid         107
#define SYS_getegid         108
#define SYS_clock_gettime   228

#define MAP_PRIVATE   0x02
#define MAP_ANONYMOUS 0x20
#define PROT_READ     0x1
#define PROT_WRITE    0x2
#define MREMAP_MAYMOVE 1
#define F_GETFD       1

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

// ---- Tests ----

static void test_write(void) {
  i64 r = syscall3(SYS_write, 1, (u64)"", 0);
  check(r == 0, "write zero bytes returns 0");

  r = syscall3(SYS_write, 1, (u64)"# ", 2);
  check(r == 2, "write returns byte count");
}

static void test_brk(void) {
  i64 cur = syscall1(SYS_brk, 0);
  check(cur > 0, "brk(0) returns current break");

  i64 next = syscall1(SYS_brk, cur + 4096);
  check(next >= cur + 4096, "brk grows heap");

  // Write to newly allocated memory.
  volatile char *p = (volatile char *)cur;
  *p = 42;
  check(*p == 42, "brk memory is writable");
}

static void test_mmap_munmap(void) {
  i64 addr = syscall6(SYS_mmap, 0, 4096,
                       PROT_READ | PROT_WRITE,
                       MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  check(addr > 0, "mmap returns valid address");

  // Anonymous mmap should be zeroed.
  volatile char *p = (volatile char *)addr;
  check(*p == 0, "mmap anonymous memory is zeroed");

  // Write and read back.
  p[0] = 'A';
  p[4095] = 'Z';
  check(p[0] == 'A' && p[4095] == 'Z', "mmap memory is read/writable");

  i64 r = syscall2(SYS_munmap, addr, 4096);
  check(r == 0, "munmap returns 0");
}

static void test_mremap(void) {
  // Allocate a page, write data, then grow it.
  i64 addr = syscall6(SYS_mmap, 0, 4096,
                       PROT_READ | PROT_WRITE,
                       MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  check(addr > 0, "mremap: initial mmap");

  volatile char *p = (volatile char *)addr;
  p[0] = 'X';
  p[100] = 'Y';

  i64 new_addr = syscall4(SYS_mremap, addr, 4096, 8192, MREMAP_MAYMOVE);
  check(new_addr > 0, "mremap returns valid address");

  volatile char *q = (volatile char *)new_addr;
  check(q[0] == 'X' && q[100] == 'Y', "mremap preserves old data");

  // New pages should be zeroed.
  check(q[4096] == 0 && q[8191] == 0, "mremap new pages are zeroed");
}

static void test_pipe_rw(void) {
  int fds[2];
  i64 r = syscall1(SYS_pipe, (u64)fds);
  check(r == 0, "pipe returns 0");

  const char *msg = "hello pipe";
  r = syscall3(SYS_write, fds[1], (u64)msg, 10);
  check(r == 10, "write to pipe");

  char buf[10] = {};
  r = syscall3(SYS_read, fds[0], (u64)buf, 10);
  check(r == 10, "read from pipe");

  int match = 1;
  for (int i = 0; i < 10; i++)
    if (buf[i] != msg[i]) match = 0;
  check(match, "pipe data matches");

  syscall1(SYS_close, fds[0]);
  syscall1(SYS_close, fds[1]);
}

static void test_dup(void) {
  int fds[2];
  syscall1(SYS_pipe, (u64)fds);

  i64 newfd = syscall1(SYS_dup, fds[1]);
  check(newfd >= 0 && newfd != fds[1], "dup returns new fd");

  syscall3(SYS_write, newfd, (u64)"D", 1);
  char c = 0;
  syscall3(SYS_read, fds[0], (u64)&c, 1);
  check(c == 'D', "dup'd fd writes to same pipe");

  syscall1(SYS_close, newfd);
  syscall1(SYS_close, fds[0]);
  syscall1(SYS_close, fds[1]);
}

static void test_getpid(void) {
  i64 pid = syscall0(SYS_getpid);
  check(pid > 0, "getpid returns positive");
}

static void test_getuid_getgid(void) {
  i64 uid = syscall0(SYS_getuid);
  i64 gid = syscall0(SYS_getgid);
  i64 euid = syscall0(SYS_geteuid);
  i64 egid = syscall0(SYS_getegid);
  check(uid >= 0, "getuid returns non-negative");
  check(gid >= 0, "getgid returns non-negative");
  check(euid >= 0, "geteuid returns non-negative");
  check(egid >= 0, "getegid returns non-negative");
}

static void test_getcwd(void) {
  char buf[256] = {};
  i64 r = syscall2(SYS_getcwd, (u64)buf, 256);
  check(r > 0, "getcwd returns positive length");
  check(buf[0] == '/', "getcwd starts with /");
}

static void test_clock_gettime(void) {
  struct { i64 tv_sec; i64 tv_nsec; } ts = {};
  i64 r = syscall2(SYS_clock_gettime, 0 /* CLOCK_REALTIME */, (u64)&ts);
  check(r == 0, "clock_gettime returns 0");
  check(ts.tv_sec > 1000000000, "clock_gettime returns plausible time");
}

static void test_fcntl(void) {
  int fds[2];
  syscall1(SYS_pipe, (u64)fds);
  i64 r = syscall2(SYS_fcntl, fds[0], F_GETFD);
  check(r >= 0, "fcntl F_GETFD succeeds");
  syscall1(SYS_close, fds[0]);
  syscall1(SYS_close, fds[1]);
}

void _start(void) {
  print("# syscall tests\n");

  test_write();
  test_brk();
  test_mmap_munmap();
  test_mremap();
  test_pipe_rw();
  test_dup();
  test_getpid();
  test_getuid_getgid();
  test_getcwd();
  test_clock_gettime();
  test_fcntl();

  print("1..");
  print_int(test_num);
  print("\n");

  if (fail_count > 0) {
    print("FAILED ");
    print_int(fail_count);
    print(" test(s)\n");
    syscall1(SYS_exit, 1);
  }

  print("All tests passed\n");
  syscall1(SYS_exit, 0);
}

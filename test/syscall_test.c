// Test various syscalls using raw inline assembly (no libc).

#define NULL ((void *)0)

typedef unsigned long u64;
typedef long i64;
typedef unsigned int u32;
typedef unsigned short u16;
typedef unsigned char u8;

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

static i64 syscall5(int nr, u64 a1, u64 a2, u64 a3, u64 a4, u64 a5) {
  i64 ret;
  register u64 r10 __asm__("r10") = a4;
  register u64 r8 __asm__("r8") = a5;
  __asm__ volatile("syscall" : "=a"(ret)
                   : "a"(nr), "D"(a1), "S"(a2), "d"(a3),
                     "r"(r10), "r"(r8)
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

// Syscall numbers (x86-64)
#define SYS_read            0
#define SYS_write           1
#define SYS_open            2
#define SYS_close           3
#define SYS_stat            4
#define SYS_fstat           5
#define SYS_lstat           6
#define SYS_poll            7
#define SYS_lseek           8
#define SYS_mmap            9
#define SYS_munmap          11
#define SYS_brk             12
#define SYS_readv           19
#define SYS_writev          20
#define SYS_pipe            22
#define SYS_select          23
#define SYS_sched_yield     24
#define SYS_mremap          25
#define SYS_dup             32
#define SYS_dup2            33
#define SYS_nanosleep       35
#define SYS_getpid          39
#define SYS_socketpair      53
#define SYS_sendto          44
#define SYS_recvfrom        45
#define SYS_sendmsg         46
#define SYS_recvmsg         47
#define SYS_exit            60
#define SYS_fcntl           72
#define SYS_fdatasync       75
#define SYS_truncate        76
#define SYS_ftruncate       77
#define SYS_getcwd          79
#define SYS_chdir           80
#define SYS_fchdir          81
#define SYS_mkdir           83
#define SYS_rmdir           84
#define SYS_link            86
#define SYS_unlink          87
#define SYS_symlink         88
#define SYS_readlink        89
#define SYS_chmod           90
#define SYS_umask           95
#define SYS_gettimeofday    96
#define SYS_getrlimit       97
#define SYS_sysinfo         99
#define SYS_times           100
#define SYS_getuid          102
#define SYS_getgid          104
#define SYS_geteuid         107
#define SYS_getegid         108
#define SYS_getppid         110
#define SYS_getpgrp         111
#define SYS_getpgid         121
#define SYS_getsid          124
#define SYS_statfs          137
#define SYS_gettid          186
#define SYS_openat          257
#define SYS_mkdirat         258
#define SYS_fchmodat        268
#define SYS_utimensat       280
#define SYS_clock_gettime   228
#define SYS_clock_getres    229
#define SYS_eventfd2        290
#define SYS_epoll_create1   291
#define SYS_dup3            292
#define SYS_pipe2           293
#define SYS_inotify_init1   294
#define SYS_getrandom       318
#define SYS_statx           332
#define SYS_sendfile        40
#define SYS_copy_file_range 326
#define SYS_epoll_ctl       233
#define SYS_epoll_wait      232
#define SYS_linkat          265
#define SYS_symlinkat       266
#define SYS_readlinkat      267
#define SYS_renameat2       316
#define SYS_unlinkat        263

// Constants
#define MAP_PRIVATE   0x02
#define MAP_ANONYMOUS 0x20
#define PROT_READ     0x1
#define PROT_WRITE    0x2
#define MREMAP_MAYMOVE 1
#define F_GETFD       1
#define F_GETFL       3
#define F_SETFL       4
#define O_RDONLY      0
#define O_WRONLY      1
#define O_RDWR        2
#define O_CREAT       0100
#define O_TRUNC       01000
#define AT_FDCWD      (-100)
#define SEEK_SET      0
#define SEEK_CUR      1
#define SEEK_END      2
#define AF_UNIX       1
#define SOCK_STREAM   1
#define SOCK_DGRAM    2
#define SOCK_NONBLOCK 04000
#define EFD_NONBLOCK  04000
#define CLOCK_REALTIME 0
#define CLOCK_MONOTONIC 1
#define UTIME_NOW     0x3FFFFFFF
#define EPOLL_CTL_ADD 1
#define EPOLL_CTL_DEL 2
#define EPOLLIN       0x001
#define EPOLLOUT      0x004

// Structures
struct stat_buf {
  u64 st_dev;
  u64 st_ino;
  u64 st_nlink;
  u32 st_mode;
  u32 st_uid;
  u32 st_gid;
  u32 __pad0;
  u64 st_rdev;
  i64 st_size;
  i64 st_blksize;
  i64 st_blocks;
  u64 st_atime_sec;
  u64 st_atime_nsec;
  u64 st_mtime_sec;
  u64 st_mtime_nsec;
  u64 st_ctime_sec;
  u64 st_ctime_nsec;
  i64 __unused[3];
};

struct iovec {
  void *iov_base;
  u64 iov_len;
};

struct timespec {
  i64 tv_sec;
  i64 tv_nsec;
};

struct timeval {
  i64 tv_sec;
  i64 tv_usec;
};

struct statfs_buf {
  i64 f_type;
  i64 f_bsize;
  u64 f_blocks;
  u64 f_bfree;
  u64 f_bavail;
  u64 f_files;
  u64 f_ffree;
  i64 f_fsid[2];
  i64 f_namelen;
  i64 f_frsize;
  i64 f_flags;
  i64 f_spare[4];
};

struct tms_buf {
  i64 tms_utime;
  i64 tms_stime;
  i64 tms_cutime;
  i64 tms_cstime;
};

// Helpers for string comparison
static int streq(const char *a, const char *b) {
  while (*a && *b) { if (*a++ != *b++) return 0; }
  return *a == *b;
}

static int strlen_(const char *s) {
  int n = 0;
  while (s[n]) n++;
  return n;
}

static void memset_(void *p, int c, u64 n) {
  u8 *d = (u8 *)p;
  for (u64 i = 0; i < n; i++) d[i] = c;
}

static void memcpy_(void *dst, const void *src, u64 n) {
  u8 *d = (u8 *)dst;
  const u8 *s = (const u8 *)src;
  for (u64 i = 0; i < n; i++) d[i] = s[i];
}

static int test_num = 0;
static int fail_count = 0;

static void print(const char *s) {
  int len = strlen_(s);
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

// Helper: create a temp file path using pid
static void make_tmp_path(char *buf, const char *suffix) {
  // Use /tmp/sail_test_<pid>_<suffix>
  const char *prefix = "/tmp/sail_test_";
  int i = 0;
  while (prefix[i]) { buf[i] = prefix[i]; i++; }
  i64 pid = syscall0(SYS_getpid);
  char num[20];
  int n = 0;
  if (pid == 0) { num[n++] = '0'; }
  else { while (pid > 0) { num[n++] = '0' + pid % 10; pid /= 10; } }
  for (int j = n - 1; j >= 0; j--) buf[i++] = num[j];
  buf[i++] = '_';
  while (*suffix) buf[i++] = *suffix++;
  buf[i] = 0;
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

  volatile char *p = (volatile char *)cur;
  *p = 42;
  check(*p == 42, "brk memory is writable");
}

static void test_mmap_munmap(void) {
  i64 addr = syscall6(SYS_mmap, 0, 4096,
                       PROT_READ | PROT_WRITE,
                       MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  check(addr > 0, "mmap returns valid address");

  volatile char *p = (volatile char *)addr;
  check(*p == 0, "mmap anonymous memory is zeroed");

  p[0] = 'A';
  p[4095] = 'Z';
  check(p[0] == 'A' && p[4095] == 'Z', "mmap memory is read/writable");

  i64 r = syscall2(SYS_munmap, addr, 4096);
  check(r == 0, "munmap returns 0");
}

static void test_mremap(void) {
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

static void test_dup2_dup3(void) {
  int fds[2];
  syscall1(SYS_pipe, (u64)fds);

  // dup2
  i64 r = syscall2(SYS_dup2, fds[1], 100);
  check(r == 100, "dup2 returns target fd");
  syscall3(SYS_write, 100, (u64)"A", 1);
  char c = 0;
  syscall3(SYS_read, fds[0], (u64)&c, 1);
  check(c == 'A', "dup2'd fd works");
  syscall1(SYS_close, 100);

  // dup3
  r = syscall3(SYS_dup3, fds[1], 101, 0);
  check(r == 101, "dup3 returns target fd");
  syscall3(SYS_write, 101, (u64)"B", 1);
  c = 0;
  syscall3(SYS_read, fds[0], (u64)&c, 1);
  check(c == 'B', "dup3'd fd works");
  syscall1(SYS_close, 101);

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

  i64 ppid = syscall0(SYS_getppid);
  check(ppid >= 0, "getppid returns non-negative");

  i64 pgrp = syscall0(SYS_getpgrp);
  check(pgrp >= 0, "getpgrp returns non-negative");

  i64 pgid = syscall1(SYS_getpgid, 0);
  check(pgid >= 0, "getpgid(0) returns non-negative");

  i64 sid = syscall1(SYS_getsid, 0);
  check(sid >= 0, "getsid(0) returns non-negative");

  i64 tid = syscall0(SYS_gettid);
  check(tid > 0, "gettid returns positive");
}

static void test_getcwd(void) {
  char buf[256] = {};
  i64 r = syscall2(SYS_getcwd, (u64)buf, 256);
  check(r > 0, "getcwd returns positive length");
  check(buf[0] == '/', "getcwd starts with /");
}

static void test_clock_gettime(void) {
  struct timespec ts = {};
  i64 r = syscall2(SYS_clock_gettime, CLOCK_REALTIME, (u64)&ts);
  check(r == 0, "clock_gettime returns 0");
  check(ts.tv_sec > 1000000000, "clock_gettime returns plausible time");
}

static void test_clock_getres(void) {
  struct timespec ts = {};
  i64 r = syscall2(SYS_clock_getres, CLOCK_REALTIME, (u64)&ts);
  check(r == 0, "clock_getres returns 0");
  check(ts.tv_sec == 0 && ts.tv_nsec > 0, "clock_getres returns sub-second resolution");

  struct timespec ts2 = {};
  r = syscall2(SYS_clock_getres, CLOCK_MONOTONIC, (u64)&ts2);
  check(r == 0, "clock_getres MONOTONIC returns 0");
}

static void test_fcntl(void) {
  int fds[2];
  syscall1(SYS_pipe, (u64)fds);
  i64 r = syscall2(SYS_fcntl, fds[0], F_GETFD);
  check(r >= 0, "fcntl F_GETFD succeeds");
  syscall1(SYS_close, fds[0]);
  syscall1(SYS_close, fds[1]);
}

static void test_readv_writev(void) {
  int fds[2];
  syscall1(SYS_pipe, (u64)fds);

  // writev: write "hello" + "world" as two iovecs
  struct iovec wv[2];
  wv[0].iov_base = (void *)"hello";
  wv[0].iov_len = 5;
  wv[1].iov_base = (void *)"world";
  wv[1].iov_len = 5;
  i64 r = syscall3(SYS_writev, fds[1], (u64)wv, 2);
  check(r == 10, "writev returns total bytes");

  // readv: read into two buffers
  char buf1[5] = {};
  char buf2[5] = {};
  struct iovec rv[2];
  rv[0].iov_base = buf1;
  rv[0].iov_len = 5;
  rv[1].iov_base = buf2;
  rv[1].iov_len = 5;
  r = syscall3(SYS_readv, fds[0], (u64)rv, 2);
  check(r == 10, "readv returns total bytes");

  int ok = 1;
  const char *exp1 = "hello";
  const char *exp2 = "world";
  for (int i = 0; i < 5; i++) {
    if (buf1[i] != exp1[i] || buf2[i] != exp2[i]) ok = 0;
  }
  check(ok, "readv data matches writev data");

  syscall1(SYS_close, fds[0]);
  syscall1(SYS_close, fds[1]);
}

static void test_stat_fstat_lstat(void) {
  // stat /tmp (should exist)
  struct stat_buf st;
  memset_(&st, 0, sizeof(st));
  i64 r = syscall2(SYS_stat, (u64)"/tmp", (u64)&st);
  check(r == 0, "stat /tmp returns 0");
  check((st.st_mode & 0170000) == 0040000, "stat /tmp is a directory");

  // fstat on stdout
  memset_(&st, 0, sizeof(st));
  r = syscall2(SYS_fstat, 1, (u64)&st);
  check(r == 0, "fstat stdout returns 0");

  // lstat /tmp
  memset_(&st, 0, sizeof(st));
  r = syscall2(SYS_lstat, (u64)"/tmp", (u64)&st);
  check(r == 0, "lstat /tmp returns 0");

  // stat nonexistent
  r = syscall2(SYS_stat, (u64)"/nonexistent_path_12345", (u64)&st);
  check(r == -2 /* ENOENT */, "stat nonexistent returns ENOENT");
}

static void test_open_read_close(void) {
  // Open /dev/null
  i64 fd = syscall3(SYS_open, (u64)"/dev/null", O_RDONLY, 0);
  check(fd >= 0, "open /dev/null returns valid fd");

  char buf[16];
  i64 r = syscall3(SYS_read, fd, (u64)buf, 16);
  check(r == 0, "read /dev/null returns 0 (EOF)");

  r = syscall1(SYS_close, fd);
  check(r == 0, "close returns 0");
}

static void test_openat(void) {
  i64 fd = syscall4(SYS_openat, (u64)(i64)AT_FDCWD, (u64)"/dev/null", O_RDONLY, 0);
  check(fd >= 0, "openat AT_FDCWD /dev/null returns valid fd");
  syscall1(SYS_close, fd);
}

static void test_lseek(void) {
  // Create a temp file, write, seek, read
  char path[128];
  make_tmp_path(path, "lseek");

  i64 fd = syscall3(SYS_open, (u64)path, O_RDWR | O_CREAT | O_TRUNC, 0644);
  check(fd >= 0, "open temp file for lseek");

  syscall3(SYS_write, fd, (u64)"abcdef", 6);

  i64 off = syscall3(SYS_lseek, fd, 2, SEEK_SET);
  check(off == 2, "lseek SEEK_SET returns 2");

  char buf[4] = {};
  i64 r = syscall3(SYS_read, fd, (u64)buf, 4);
  check(r == 4, "read after lseek returns 4");
  check(buf[0] == 'c' && buf[1] == 'd', "read after lseek returns correct data");

  off = syscall3(SYS_lseek, fd, -3, SEEK_END);
  check(off == 3, "lseek SEEK_END -3 returns 3");

  syscall1(SYS_close, fd);
  syscall1(SYS_unlink, (u64)path);
}

static void test_pipe2(void) {
  int fds[2];
  i64 r = syscall2(SYS_pipe2, (u64)fds, 0);
  check(r == 0, "pipe2 returns 0");

  syscall3(SYS_write, fds[1], (u64)"X", 1);
  char c = 0;
  syscall3(SYS_read, fds[0], (u64)&c, 1);
  check(c == 'X', "pipe2 data round-trip");

  syscall1(SYS_close, fds[0]);
  syscall1(SYS_close, fds[1]);
}

static void test_file_ops(void) {
  // mkdir, create file, link, symlink, readlink, chmod, truncate, unlink, rmdir
  char dir[128], file1[128], file2[128], link1[128], sym1[128];
  make_tmp_path(dir, "dir");
  make_tmp_path(file1, "file1");
  make_tmp_path(file2, "file2");
  make_tmp_path(link1, "link1");
  make_tmp_path(sym1, "sym1");

  i64 r = syscall2(SYS_mkdir, (u64)dir, 0755);
  check(r == 0, "mkdir returns 0");

  // Create file
  i64 fd = syscall3(SYS_open, (u64)file1, O_RDWR | O_CREAT | O_TRUNC, 0644);
  check(fd >= 0, "create file returns valid fd");
  syscall3(SYS_write, fd, (u64)"hello", 5);

  // fdatasync
  r = syscall1(SYS_fdatasync, fd);
  check(r == 0, "fdatasync returns 0");
  syscall1(SYS_close, fd);

  // link
  r = syscall2(SYS_link, (u64)file1, (u64)link1);
  check(r == 0, "link returns 0");

  // symlink
  r = syscall2(SYS_symlink, (u64)file1, (u64)sym1);
  check(r == 0, "symlink returns 0");

  // readlink
  char linkbuf[256] = {};
  r = syscall3(SYS_readlink, (u64)sym1, (u64)linkbuf, 256);
  check(r > 0, "readlink returns positive");
  check(streq(linkbuf, file1), "readlink returns correct target");

  // chmod
  r = syscall2(SYS_chmod, (u64)file1, 0600);
  check(r == 0, "chmod returns 0");

  // stat to verify mode
  struct stat_buf st;
  memset_(&st, 0, sizeof(st));
  syscall2(SYS_stat, (u64)file1, (u64)&st);
  check((st.st_mode & 0777) == 0600, "chmod changed mode to 0600");

  // truncate
  r = syscall2(SYS_truncate, (u64)file1, 3);
  check(r == 0, "truncate returns 0");
  memset_(&st, 0, sizeof(st));
  syscall2(SYS_stat, (u64)file1, (u64)&st);
  check(st.st_size == 3, "truncate changed size to 3");

  // ftruncate
  fd = syscall3(SYS_open, (u64)file1, O_RDWR, 0);
  r = syscall2(SYS_ftruncate, fd, 1);
  check(r == 0, "ftruncate returns 0");
  syscall1(SYS_close, fd);
  memset_(&st, 0, sizeof(st));
  syscall2(SYS_stat, (u64)file1, (u64)&st);
  check(st.st_size == 1, "ftruncate changed size to 1");

  // Cleanup
  syscall1(SYS_unlink, (u64)sym1);
  syscall1(SYS_unlink, (u64)link1);
  syscall1(SYS_unlink, (u64)file1);
  syscall1(SYS_rmdir, (u64)dir);
}

static void test_chdir_fchdir(void) {
  char orig_cwd[256] = {};
  syscall2(SYS_getcwd, (u64)orig_cwd, 256);

  i64 r = syscall1(SYS_chdir, (u64)"/tmp");
  check(r == 0, "chdir /tmp returns 0");

  char cwd[256] = {};
  syscall2(SYS_getcwd, (u64)cwd, 256);
  check(streq(cwd, "/tmp"), "cwd is /tmp after chdir");

  // fchdir
  i64 fd = syscall3(SYS_open, (u64)orig_cwd, O_RDONLY, 0);
  check(fd >= 0, "open original cwd");
  r = syscall1(SYS_fchdir, fd);
  check(r == 0, "fchdir returns 0");
  syscall1(SYS_close, fd);

  memset_(cwd, 0, 256);
  syscall2(SYS_getcwd, (u64)cwd, 256);
  check(streq(cwd, orig_cwd), "fchdir restored original cwd");
}

static void test_sched_yield(void) {
  i64 r = syscall0(SYS_sched_yield);
  check(r == 0, "sched_yield returns 0");
}

static void test_gettimeofday(void) {
  struct timeval tv = {};
  i64 r = syscall2(SYS_gettimeofday, (u64)&tv, 0);
  check(r == 0, "gettimeofday returns 0");
  check(tv.tv_sec > 1000000000, "gettimeofday returns plausible time");
}

static void test_getrlimit(void) {
  // RLIMIT_NOFILE = 7
  struct { u64 rlim_cur; u64 rlim_max; } rl = {};
  i64 r = syscall2(SYS_getrlimit, 7, (u64)&rl);
  check(r == 0, "getrlimit returns 0");
  check(rl.rlim_cur > 0, "getrlimit NOFILE cur > 0");
}

static void test_sysinfo(void) {
  // sysinfo struct is big, just check return
  char buf[256];
  memset_(buf, 0, 256);
  i64 r = syscall1(SYS_sysinfo, (u64)buf);
  check(r == 0, "sysinfo returns 0");
  // uptime is first field (long)
  i64 uptime = *(i64 *)buf;
  check(uptime > 0, "sysinfo uptime > 0");
}

static void test_times(void) {
  struct tms_buf t = {};
  i64 r = syscall1(SYS_times, (u64)&t);
  check(r >= 0, "times returns non-negative");
}

static void test_statfs(void) {
  struct statfs_buf st;
  memset_(&st, 0, sizeof(st));
  i64 r = syscall2(SYS_statfs, (u64)"/tmp", (u64)&st);
  check(r == 0, "statfs /tmp returns 0");
  check(st.f_bsize > 0, "statfs f_bsize > 0");
}

static void test_umask(void) {
  i64 old = syscall1(SYS_umask, 0077);
  check(old >= 0, "umask returns old mask");
  // Restore
  syscall1(SYS_umask, old);
}

static void test_getrandom(void) {
  u8 buf[8] = {};
  i64 r = syscall3(SYS_getrandom, (u64)buf, 8, 0);
  check(r == 8, "getrandom returns 8 bytes");
  // Very unlikely all zeros
  int all_zero = 1;
  for (int i = 0; i < 8; i++) if (buf[i] != 0) all_zero = 0;
  check(!all_zero, "getrandom produces non-zero bytes");
}

static void test_socketpair(void) {
  int sv[2];
  i64 r = syscall4(SYS_socketpair, AF_UNIX, SOCK_STREAM, 0, (u64)sv);
  check(r == 0, "socketpair returns 0");

  // Write through one end, read from the other
  syscall3(SYS_write, sv[0], (u64)"SOCK", 4);
  char buf[4] = {};
  r = syscall3(SYS_read, sv[1], (u64)buf, 4);
  check(r == 4, "socketpair read returns 4");
  check(buf[0] == 'S' && buf[1] == 'O' && buf[2] == 'C' && buf[3] == 'K',
        "socketpair data round-trip");

  syscall1(SYS_close, sv[0]);
  syscall1(SYS_close, sv[1]);
}

static void test_sendto_recvfrom(void) {
  int sv[2];
  syscall4(SYS_socketpair, AF_UNIX, SOCK_STREAM, 0, (u64)sv);

  // sendto (with NULL addr for connected socket)
  i64 r = syscall6(SYS_sendto, sv[0], (u64)"MSG!", 4, 0, 0, 0);
  check(r == 4, "sendto returns 4");

  // recvfrom (with NULL addr)
  char buf[4] = {};
  r = syscall6(SYS_recvfrom, sv[1], (u64)buf, 4, 0, 0, 0);
  check(r == 4, "recvfrom returns 4");
  check(buf[0] == 'M' && buf[3] == '!', "recvfrom data matches");

  syscall1(SYS_close, sv[0]);
  syscall1(SYS_close, sv[1]);
}

static void test_sendmsg_recvmsg(void) {
  int sv[2];
  syscall4(SYS_socketpair, AF_UNIX, SOCK_STREAM, 0, (u64)sv);

  // Build msghdr for sendmsg
  struct iovec siov;
  siov.iov_base = (void *)"MESG";
  siov.iov_len = 4;
  u64 shdr[7] = {}; // name, namelen, iov, iovlen, control, controllen, flags
  shdr[2] = (u64)&siov;
  shdr[3] = 1;
  i64 r = syscall3(SYS_sendmsg, sv[0], (u64)shdr, 0);
  check(r == 4, "sendmsg returns 4");

  // Build msghdr for recvmsg
  char rbuf[4] = {};
  struct iovec riov;
  riov.iov_base = rbuf;
  riov.iov_len = 4;
  u64 rhdr[7] = {};
  rhdr[2] = (u64)&riov;
  rhdr[3] = 1;
  r = syscall3(SYS_recvmsg, sv[1], (u64)rhdr, 0);
  check(r == 4, "recvmsg returns 4");
  check(rbuf[0] == 'M' && rbuf[1] == 'E' && rbuf[2] == 'S' && rbuf[3] == 'G',
        "recvmsg data matches");

  syscall1(SYS_close, sv[0]);
  syscall1(SYS_close, sv[1]);
}

static void test_select(void) {
  int fds[2];
  syscall1(SYS_pipe, (u64)fds);

  // Write something so read end is ready
  syscall3(SYS_write, fds[1], (u64)"X", 1);

  // fd_set is 128 bytes (1024 bits) on x86-64
  u8 rfds[128];
  memset_(rfds, 0, 128);
  // Set bit for fds[0]
  rfds[fds[0] / 8] |= (1 << (fds[0] % 8));

  struct timeval tv = {0, 0}; // instant timeout
  i64 r = syscall5(SYS_select, fds[0] + 1, (u64)rfds, 0, 0, (u64)&tv);
  check(r == 1, "select returns 1 (pipe readable)");
  check(rfds[fds[0] / 8] & (1 << (fds[0] % 8)), "select reports fd ready");

  // Read the byte
  char c;
  syscall3(SYS_read, fds[0], (u64)&c, 1);

  syscall1(SYS_close, fds[0]);
  syscall1(SYS_close, fds[1]);
}

static void test_poll(void) {
  int fds[2];
  syscall1(SYS_pipe, (u64)fds);
  syscall3(SYS_write, fds[1], (u64)"Y", 1);

  // struct pollfd { int fd; short events; short revents; }
  struct { int fd; short events; short revents; } pfd;
  pfd.fd = fds[0];
  pfd.events = 1; // POLLIN
  pfd.revents = 0;

  i64 r = syscall3(SYS_poll, (u64)&pfd, 1, 0);
  check(r == 1, "poll returns 1");
  check(pfd.revents & 1, "poll reports POLLIN");

  char c;
  syscall3(SYS_read, fds[0], (u64)&c, 1);
  syscall1(SYS_close, fds[0]);
  syscall1(SYS_close, fds[1]);
}

static void test_epoll(void) {
  // Create epoll fd
  i64 epfd = syscall1(SYS_epoll_create1, 0);
  check(epfd >= 0, "epoll_create1 returns valid fd");

  int fds[2];
  syscall1(SYS_pipe, (u64)fds);

  // epoll_event: { u32 events; u64 data; } but padded to 12 bytes
  struct { u32 events; u32 pad; u64 data; } ev;
  ev.events = EPOLLIN;
  ev.pad = 0;
  ev.data = 42;

  i64 r = syscall4(SYS_epoll_ctl, epfd, EPOLL_CTL_ADD, fds[0], (u64)&ev);
  check(r == 0, "epoll_ctl ADD returns 0");

  // Write to pipe
  syscall3(SYS_write, fds[1], (u64)"E", 1);

  // Wait for events
  struct { u32 events; u32 pad; u64 data; } out_ev = {};
  r = syscall4(SYS_epoll_wait, epfd, (u64)&out_ev, 1, 0);
  check(r == 1, "epoll_wait returns 1");
  check(out_ev.events & EPOLLIN, "epoll reports EPOLLIN");
  check(out_ev.data == 42, "epoll returns correct data");

  // Remove
  r = syscall4(SYS_epoll_ctl, epfd, EPOLL_CTL_DEL, fds[0], 0);
  check(r == 0, "epoll_ctl DEL returns 0");

  char c;
  syscall3(SYS_read, fds[0], (u64)&c, 1);
  syscall1(SYS_close, fds[0]);
  syscall1(SYS_close, fds[1]);
  syscall1(SYS_close, epfd);
}

static void test_eventfd(void) {
  i64 fd = syscall2(SYS_eventfd2, 0, EFD_NONBLOCK);
  check(fd >= 0, "eventfd2 returns valid fd");

  // Write a count
  u64 val = 5;
  i64 r = syscall3(SYS_write, fd, (u64)&val, 8);
  check(r == 8, "eventfd write returns 8");

  // Read back
  u64 rval = 0;
  r = syscall3(SYS_read, fd, (u64)&rval, 8);
  check(r == 8, "eventfd read returns 8");
  check(rval == 5, "eventfd read value matches");

  syscall1(SYS_close, fd);
}

static void test_inotify(void) {
  i64 fd = syscall1(SYS_inotify_init1, 0);
  check(fd >= 0, "inotify_init1 returns valid fd");
  syscall1(SYS_close, fd);
}

static void test_sendfile(void) {
  // Create source file
  char src[128], dst[128];
  make_tmp_path(src, "sendfile_src");
  make_tmp_path(dst, "sendfile_dst");

  i64 sfd = syscall3(SYS_open, (u64)src, O_RDWR | O_CREAT | O_TRUNC, 0644);
  syscall3(SYS_write, sfd, (u64)"SENDFILE", 8);
  syscall3(SYS_lseek, sfd, 0, SEEK_SET);

  i64 dfd = syscall3(SYS_open, (u64)dst, O_RDWR | O_CREAT | O_TRUNC, 0644);

  i64 r = syscall4(SYS_sendfile, dfd, sfd, 0, 8);
  check(r == 8, "sendfile returns 8");

  // Verify
  syscall3(SYS_lseek, dfd, 0, SEEK_SET);
  char buf[8] = {};
  syscall3(SYS_read, dfd, (u64)buf, 8);
  check(buf[0] == 'S' && buf[7] == 'E', "sendfile data correct");

  syscall1(SYS_close, sfd);
  syscall1(SYS_close, dfd);
  syscall1(SYS_unlink, (u64)src);
  syscall1(SYS_unlink, (u64)dst);
}

static void test_linkat_symlinkat(void) {
  char file[128], lnk[128], sym[128];
  make_tmp_path(file, "lat_file");
  make_tmp_path(lnk, "lat_link");
  make_tmp_path(sym, "lat_sym");

  i64 fd = syscall3(SYS_open, (u64)file, O_RDWR | O_CREAT | O_TRUNC, 0644);
  syscall3(SYS_write, fd, (u64)"test", 4);
  syscall1(SYS_close, fd);

  // linkat(AT_FDCWD, file, AT_FDCWD, lnk, 0)
  i64 r = syscall5(SYS_linkat, (u64)(i64)AT_FDCWD, (u64)file,
                    (u64)(i64)AT_FDCWD, (u64)lnk, 0);
  check(r == 0, "linkat returns 0");

  // symlinkat(file, AT_FDCWD, sym)
  r = syscall3(SYS_symlinkat, (u64)file, (u64)(i64)AT_FDCWD, (u64)sym);
  check(r == 0, "symlinkat returns 0");

  // readlinkat
  char rbuf[256] = {};
  r = syscall4(SYS_readlinkat, (u64)(i64)AT_FDCWD, (u64)sym, (u64)rbuf, 256);
  check(r > 0, "readlinkat returns positive");
  check(streq(rbuf, file), "readlinkat returns correct target");

  syscall1(SYS_unlink, (u64)sym);
  syscall1(SYS_unlink, (u64)lnk);
  syscall1(SYS_unlink, (u64)file);
}

static void test_mkdirat_fchmodat(void) {
  char dir[128];
  make_tmp_path(dir, "mkdirat_dir");

  i64 r = syscall3(SYS_mkdirat, (u64)(i64)AT_FDCWD, (u64)dir, 0755);
  check(r == 0, "mkdirat returns 0");

  r = syscall4(SYS_fchmodat, (u64)(i64)AT_FDCWD, (u64)dir, 0700, 0);
  check(r == 0, "fchmodat returns 0");

  struct stat_buf st;
  memset_(&st, 0, sizeof(st));
  syscall2(SYS_stat, (u64)dir, (u64)&st);
  check((st.st_mode & 0777) == 0700, "fchmodat changed mode");

  syscall1(SYS_rmdir, (u64)dir);
}

static void test_utimensat(void) {
  char file[128];
  make_tmp_path(file, "utimens");

  i64 fd = syscall3(SYS_open, (u64)file, O_RDWR | O_CREAT | O_TRUNC, 0644);
  syscall1(SYS_close, fd);

  // Set atime/mtime to UTIME_NOW
  struct timespec times[2];
  times[0].tv_sec = 0;
  times[0].tv_nsec = UTIME_NOW;
  times[1].tv_sec = 0;
  times[1].tv_nsec = UTIME_NOW;
  i64 r = syscall4(SYS_utimensat, (u64)(i64)AT_FDCWD, (u64)file, (u64)times, 0);
  check(r == 0, "utimensat returns 0");

  syscall1(SYS_unlink, (u64)file);
}

static void test_statx(void) {
  // statx output is 256 bytes. Just check that it doesn't error.
  u8 stx[256];
  memset_(stx, 0, 256);
  // statx(AT_FDCWD, "/tmp", 0, STATX_BASIC_STATS, &stx)
  i64 r = syscall5(SYS_statx, (u64)(i64)AT_FDCWD, (u64)"/tmp", 0, 0x7ff, (u64)stx);
  check(r == 0, "statx /tmp returns 0");
}

static void test_copy_file_range(void) {
  char src[128], dst[128];
  make_tmp_path(src, "cfr_src");
  make_tmp_path(dst, "cfr_dst");

  i64 sfd = syscall3(SYS_open, (u64)src, O_RDWR | O_CREAT | O_TRUNC, 0644);
  syscall3(SYS_write, sfd, (u64)"COPYRANGE", 9);
  syscall3(SYS_lseek, sfd, 0, SEEK_SET);

  i64 dfd = syscall3(SYS_open, (u64)dst, O_RDWR | O_CREAT | O_TRUNC, 0644);

  i64 r = syscall6(SYS_copy_file_range, sfd, 0, dfd, 0, 9, 0);
  check(r == 9, "copy_file_range returns 9");

  syscall3(SYS_lseek, dfd, 0, SEEK_SET);
  char buf[9] = {};
  syscall3(SYS_read, dfd, (u64)buf, 9);
  check(buf[0] == 'C' && buf[8] == 'E', "copy_file_range data correct");

  syscall1(SYS_close, sfd);
  syscall1(SYS_close, dfd);
  syscall1(SYS_unlink, (u64)src);
  syscall1(SYS_unlink, (u64)dst);
}

static void test_renameat2(void) {
  char old[128], new_[128];
  make_tmp_path(old, "renat2_old");
  make_tmp_path(new_, "renat2_new");

  i64 fd = syscall3(SYS_open, (u64)old, O_RDWR | O_CREAT | O_TRUNC, 0644);
  syscall3(SYS_write, fd, (u64)"REN", 3);
  syscall1(SYS_close, fd);

  // renameat2(AT_FDCWD, old, AT_FDCWD, new, 0)
  i64 r = syscall5(SYS_renameat2, (u64)(i64)AT_FDCWD, (u64)old,
                    (u64)(i64)AT_FDCWD, (u64)new_, 0);
  check(r == 0, "renameat2 returns 0");

  // Verify old is gone
  struct stat_buf st;
  r = syscall2(SYS_stat, (u64)old, (u64)&st);
  check(r == -2, "renameat2 old file gone (ENOENT)");

  // Verify new exists
  r = syscall2(SYS_stat, (u64)new_, (u64)&st);
  check(r == 0, "renameat2 new file exists");

  syscall1(SYS_unlink, (u64)new_);
}

__attribute__((force_align_arg_pointer))
void _start(void) {
  print("# syscall tests\n");

  test_write();
  test_brk();
  test_mmap_munmap();
  test_mremap();
  test_pipe_rw();
  test_dup();
  test_dup2_dup3();
  test_getpid();
  test_getuid_getgid();
  test_getcwd();
  test_clock_gettime();
  test_clock_getres();
  test_fcntl();
  test_readv_writev();
  test_stat_fstat_lstat();
  test_open_read_close();
  test_openat();
  test_lseek();
  test_pipe2();
  test_file_ops();
  test_chdir_fchdir();
  test_sched_yield();
  test_gettimeofday();
  test_getrlimit();
  test_sysinfo();
  test_times();
  test_statfs();
  test_umask();
  test_getrandom();
  test_socketpair();
  test_sendto_recvfrom();
  test_sendmsg_recvmsg();
  test_select();
  test_poll();
  test_epoll();
  test_eventfd();
  test_inotify();
  test_sendfile();
  test_linkat_symlinkat();
  test_mkdirat_fchmodat();
  test_utimensat();
  test_statx();
  test_copy_file_range();
  test_renameat2();

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

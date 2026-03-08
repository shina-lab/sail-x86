#include "x86_syscall.h"
#include <cstdio>
#include <cstring>
#include <set>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/utsname.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <fcntl.h>
#include <time.h>
#include <errno.h>
#include <sys/uio.h>
#include <dirent.h>
#include <sys/syscall.h>
#include <sys/vfs.h>
#include <sys/socket.h>
#include <poll.h>
#include <sched.h>
#include <sys/sysinfo.h>
#include <sys/epoll.h>
#include <sys/ioctl.h>
#include <signal.h>
#include <grp.h>
#include <sys/times.h>
#include <sys/select.h>
#include <sys/eventfd.h>
#include <sys/timerfd.h>
#include <sys/signalfd.h>
#include <sys/inotify.h>
#include <sys/sendfile.h>
#include <utime.h>

// Linux x86-64 syscall numbers
static constexpr int SYS_READ = 0;
static constexpr int SYS_WRITE = 1;
static constexpr int SYS_OPEN = 2;
static constexpr int SYS_CLOSE = 3;
static constexpr int SYS_STAT = 4;
static constexpr int SYS_FSTAT = 5;
static constexpr int SYS_LSTAT = 6;
static constexpr int SYS_POLL = 7;
static constexpr int SYS_LSEEK = 8;
static constexpr int SYS_MMAP = 9;
static constexpr int SYS_MPROTECT = 10;
static constexpr int SYS_MUNMAP = 11;
static constexpr int SYS_BRK = 12;
static constexpr int SYS_RT_SIGACTION = 13;
static constexpr int SYS_RT_SIGPROCMASK = 14;
static constexpr int SYS_IOCTL = 16;
static constexpr int SYS_PREAD64 = 17;
static constexpr int SYS_PWRITE64 = 18;
static constexpr int SYS_READV = 19;
static constexpr int SYS_WRITEV = 20;
static constexpr int SYS_ACCESS = 21;
static constexpr int SYS_PIPE = 22;
static constexpr int SYS_SELECT = 23;
static constexpr int SYS_SCHED_YIELD = 24;
static constexpr int SYS_MREMAP = 25;
static constexpr int SYS_MSYNC = 26;
static constexpr int SYS_ALARM = 27;
static constexpr int SYS_MADVISE = 28;
static constexpr int SYS_DUP = 32;
static constexpr int SYS_DUP2 = 33;
static constexpr int SYS_NANOSLEEP = 35;
static constexpr int SYS_GETITIMER = 36;
static constexpr int SYS_SETITIMER = 38;
static constexpr int SYS_GETPID = 39;
static constexpr int SYS_SENDFILE = 40;
static constexpr int SYS_SOCKET = 41;
static constexpr int SYS_CONNECT = 42;
static constexpr int SYS_ACCEPT = 43;
static constexpr int SYS_SENDTO = 44;
static constexpr int SYS_RECVFROM = 45;
static constexpr int SYS_SENDMSG = 46;
static constexpr int SYS_RECVMSG = 47;
static constexpr int SYS_SHUTDOWN = 48;
static constexpr int SYS_BIND = 49;
static constexpr int SYS_LISTEN = 50;
static constexpr int SYS_GETSOCKNAME = 51;
static constexpr int SYS_GETPEERNAME = 52;
static constexpr int SYS_SOCKETPAIR = 53;
static constexpr int SYS_SETSOCKOPT = 54;
static constexpr int SYS_GETSOCKOPT = 55;
static constexpr int SYS_CLONE = 56;
static constexpr int SYS_FORK = 57;
static constexpr int SYS_EXECVE = 59;
static constexpr int SYS_EXIT = 60;
static constexpr int SYS_WAIT4 = 61;
static constexpr int SYS_KILL = 62;
static constexpr int SYS_UNAME = 63;
static constexpr int SYS_FCNTL = 72;
static constexpr int SYS_FLOCK = 73;
static constexpr int SYS_FSYNC = 74;
static constexpr int SYS_FDATASYNC = 75;
static constexpr int SYS_TRUNCATE = 76;
static constexpr int SYS_FTRUNCATE = 77;
static constexpr int SYS_GETDENTS = 78;
static constexpr int SYS_GETCWD = 79;
static constexpr int SYS_CHDIR = 80;
static constexpr int SYS_FCHDIR = 81;
static constexpr int SYS_RENAME = 82;
static constexpr int SYS_MKDIR = 83;
static constexpr int SYS_RMDIR = 84;
static constexpr int SYS_CREAT = 85;
static constexpr int SYS_LINK = 86;
static constexpr int SYS_UNLINK = 87;
static constexpr int SYS_SYMLINK = 88;
static constexpr int SYS_READLINK = 89;
static constexpr int SYS_CHMOD = 90;
static constexpr int SYS_FCHMOD = 91;
static constexpr int SYS_CHOWN = 92;
static constexpr int SYS_FCHOWN = 93;
static constexpr int SYS_LCHOWN = 94;
static constexpr int SYS_UMASK = 95;
static constexpr int SYS_GETTIMEOFDAY = 96;
static constexpr int SYS_GETRLIMIT = 97;
static constexpr int SYS_GETRUSAGE = 98;
static constexpr int SYS_SYSINFO = 99;
static constexpr int SYS_TIMES = 100;
static constexpr int SYS_GETUID = 102;
static constexpr int SYS_GETGID = 104;
static constexpr int SYS_SETUID = 105;
static constexpr int SYS_SETGID = 106;
static constexpr int SYS_GETEUID = 107;
static constexpr int SYS_GETEGID = 108;
static constexpr int SYS_SETPGID = 109;
static constexpr int SYS_GETPPID = 110;
static constexpr int SYS_GETPGRP = 111;
static constexpr int SYS_SETSID = 112;
static constexpr int SYS_SETREUID = 113;
static constexpr int SYS_SETREGID = 114;
static constexpr int SYS_GETGROUPS = 115;
static constexpr int SYS_SETGROUPS = 116;
static constexpr int SYS_SETRESUID = 117;
static constexpr int SYS_GETRESUID = 118;
static constexpr int SYS_SETRESGID = 119;
static constexpr int SYS_GETRESGID = 120;
static constexpr int SYS_GETPGID = 121;
static constexpr int SYS_SETFSUID = 122;
static constexpr int SYS_SETFSGID = 123;
static constexpr int SYS_GETSID = 124;
static constexpr int SYS_SIGALTSTACK = 131;
static constexpr int SYS_UTIME = 132;
static constexpr int SYS_MKNOD = 133;
static constexpr int SYS_STATFS = 137;
static constexpr int SYS_FSTATFS = 138;
static constexpr int SYS_SETRLIMIT = 160;
static constexpr int SYS_PRCTL = 157;
static constexpr int SYS_ARCH_PRCTL = 158;
static constexpr int SYS_GETTID = 186;
static constexpr int SYS_TKILL = 200;
static constexpr int SYS_TIME = 201;
static constexpr int SYS_FUTEX = 202;
static constexpr int SYS_SCHED_SETAFFINITY = 203;
static constexpr int SYS_SCHED_GETAFFINITY = 204;
static constexpr int SYS_EPOLL_CREATE = 213;
static constexpr int SYS_GETDENTS64 = 217;
static constexpr int SYS_SET_TID_ADDRESS = 218;
static constexpr int SYS_FADVISE64 = 221;
static constexpr int SYS_CLOCK_GETTIME = 228;
static constexpr int SYS_CLOCK_GETRES = 229;
static constexpr int SYS_CLOCK_NANOSLEEP = 230;
static constexpr int SYS_EXIT_GROUP = 231;
static constexpr int SYS_EPOLL_WAIT = 232;
static constexpr int SYS_EPOLL_CTL = 233;
static constexpr int SYS_TGKILL = 234;
static constexpr int SYS_UTIMES = 235;
static constexpr int SYS_OPENAT = 257;
static constexpr int SYS_MKDIRAT = 258;
static constexpr int SYS_MKNODAT = 259;
static constexpr int SYS_FCHOWNAT = 260;
static constexpr int SYS_NEWFSTATAT = 262;
static constexpr int SYS_UNLINKAT = 263;
static constexpr int SYS_RENAMEAT = 264;
static constexpr int SYS_LINKAT = 265;
static constexpr int SYS_SYMLINKAT = 266;
static constexpr int SYS_READLINKAT = 267;
static constexpr int SYS_FCHMODAT = 268;
static constexpr int SYS_FACCESSAT = 269;
static constexpr int SYS_PSELECT6 = 270;
static constexpr int SYS_PPOLL = 271;
static constexpr int SYS_SET_ROBUST_LIST = 273;
static constexpr int SYS_SPLICE = 275;
static constexpr int SYS_TEE = 276;
static constexpr int SYS_UTIMENSAT = 280;
static constexpr int SYS_EPOLL_PWAIT = 281;
static constexpr int SYS_TIMERFD_CREATE = 283;
static constexpr int SYS_FALLOCATE = 285;
static constexpr int SYS_TIMERFD_SETTIME = 286;
static constexpr int SYS_TIMERFD_GETTIME = 287;
static constexpr int SYS_ACCEPT4 = 288;
static constexpr int SYS_SIGNALFD4 = 289;
static constexpr int SYS_EVENTFD2 = 290;
static constexpr int SYS_EPOLL_CREATE1 = 291;
static constexpr int SYS_DUP3 = 292;
static constexpr int SYS_PIPE2 = 293;
static constexpr int SYS_INOTIFY_INIT1 = 294;
static constexpr int SYS_INOTIFY_ADD_WATCH = 254;
static constexpr int SYS_INOTIFY_RM_WATCH = 255;
static constexpr int SYS_PRLIMIT64 = 302;
static constexpr int SYS_RENAMEAT2 = 316;
static constexpr int SYS_GETRANDOM = 318;
static constexpr int SYS_MEMBARRIER = 324;
static constexpr int SYS_COPY_FILE_RANGE = 326;
static constexpr int SYS_STATX = 332;
static constexpr int SYS_RSEQ = 334;
static constexpr int SYS_CLOSE_RANGE = 436;
static constexpr int SYS_FACCESSAT2 = 439;

// GPR indices matching the Sail model
static constexpr int RAX = 0;
static constexpr int RCX = 1;
static constexpr int RDX = 2;
static constexpr int RBX = 3;
static constexpr int RSP = 4;
static constexpr int RBP = 5;
static constexpr int RSI = 6;
static constexpr int RDI = 7;
static constexpr int R8 = 8;
static constexpr int R9 = 9;
static constexpr int R10 = 10;
static constexpr int R11 = 11;

static u64 read_gpr(x86::Model &m, int idx) {
  return m.zGPR.data[idx];
}

static void write_gpr(x86::Model &m, int idx, u64 val) {
  m.zGPR.data[idx] = val;
}

// With identity-mapped guest memory, guest pointers are valid host pointers.
static inline void *guest_ptr(u64 addr) { return (void *)addr; }
static inline const char *guest_str(u64 addr) { return (const char *)addr; }

static i64 do_brk(x86::Model &m, u64 addr) {
  if (addr == 0 || addr < m.brk_base) {
    return (i64)m.brk_current;
  }
  if (addr > m.brk_limit) {
    // Can't grow beyond the pre-allocated region.
    return (i64)m.brk_current;
  }
  m.brk_current = addr;
  return (i64)m.brk_current;
}

void emulate_syscall(x86::Model &model) {
  u64 syscall_nr = read_gpr(model, RAX);
  u64 arg1 = read_gpr(model, RDI);
  u64 arg2 = read_gpr(model, RSI);
  u64 arg3 = read_gpr(model, RDX);
  u64 arg4 = read_gpr(model, R10);
  u64 arg5 = read_gpr(model, R8);
  u64 arg6 = read_gpr(model, R9);

  i64 result = -ENOSYS;

  switch (syscall_nr) {

  // ---- File I/O ----

  case SYS_READ: {
    result = ::read((int)arg1, guest_ptr(arg2), (size_t)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_PREAD64: {
    result = ::pread((int)arg1, guest_ptr(arg2), (size_t)arg3, (off_t)arg4);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_WRITE: {
    result = ::write((int)arg1, guest_ptr(arg2), (size_t)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_PWRITE64: {
    result = ::pwrite((int)arg1, guest_ptr(arg2), (size_t)arg3, (off_t)arg4);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_READV: {
    // Guest iovec layout matches host (struct iovec = {void*, size_t})
    result = ::readv((int)arg1, (struct iovec *)guest_ptr(arg2), (int)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_WRITEV: {
    result = ::writev((int)arg1, (struct iovec *)guest_ptr(arg2), (int)arg3);
    if (result < 0) result = -errno;
    break;
  }

  // ---- File open/close/seek ----

  case SYS_OPEN: {
    result = ::open(guest_str(arg1), (int)arg2, (mode_t)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_OPENAT: {
    result = ::openat((int)(i32)arg1, guest_str(arg2), (int)arg3, (mode_t)arg4);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_CLOSE: {
    if (arg1 <= 2) { result = 0; break; }
    result = ::close((int)arg1);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_LSEEK: {
    result = ::lseek((int)arg1, (off_t)arg2, (int)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_DUP: {
    result = ::dup((int)arg1);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_DUP2: {
    result = ::dup2((int)arg1, (int)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_DUP3: {
    result = ::dup3((int)arg1, (int)arg2, (int)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_PIPE: {
    result = ::pipe((int *)guest_ptr(arg1));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_PIPE2: {
    result = ::pipe2((int *)guest_ptr(arg1), (int)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_FCNTL: {
    result = ::fcntl((int)arg1, (int)arg2, arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_FLOCK: {
    result = syscall(SYS_flock, (int)arg1, (int)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_FSYNC: {
    result = ::fsync((int)arg1);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_FDATASYNC: {
    result = ::fdatasync((int)arg1);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_TRUNCATE: {
    result = ::truncate(guest_str(arg1), (off_t)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_FTRUNCATE: {
    result = ::ftruncate((int)arg1, (off_t)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_CREAT: {
    result = ::creat(guest_str(arg1), (mode_t)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_FALLOCATE: {
    result = ::fallocate((int)arg1, (int)arg2, (off_t)arg3, (off_t)arg4);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_SENDFILE: {
    result = ::sendfile((int)arg1, (int)arg2,
                        arg3 ? (off_t *)guest_ptr(arg3) : nullptr, (size_t)arg4);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_COPY_FILE_RANGE: {
    result = syscall(SYS_copy_file_range, (int)arg1,
                     arg2 ? guest_ptr(arg2) : nullptr,
                     (int)arg3,
                     arg4 ? guest_ptr(arg4) : nullptr,
                     (size_t)arg5, (unsigned)arg6);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_SPLICE: {
    result = ::splice((int)arg1, arg2 ? (off_t *)guest_ptr(arg2) : nullptr,
                      (int)arg3, arg4 ? (off_t *)guest_ptr(arg4) : nullptr,
                      (size_t)arg5, (unsigned)arg6);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_TEE: {
    result = ::tee((int)arg1, (int)arg2, (size_t)arg3, (unsigned)arg4);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_CLOSE_RANGE: {
    result = syscall(SYS_close_range, (unsigned)arg1, (unsigned)arg2, (int)arg3);
    if (result < 0) result = -errno;
    break;
  }

  // ---- Stat family ----

  case SYS_STAT:
  case SYS_LSTAT: {
    result = (syscall_nr == SYS_STAT)
      ? ::stat(guest_str(arg1), (struct stat *)guest_ptr(arg2))
      : ::lstat(guest_str(arg1), (struct stat *)guest_ptr(arg2));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_FSTAT: {
    result = ::fstat((int)arg1, (struct stat *)guest_ptr(arg2));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_NEWFSTATAT: {
    result = ::fstatat((int)(i32)arg1, guest_str(arg2),
                       (struct stat *)guest_ptr(arg3), (int)arg4);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_STATFS: {
    result = ::statfs(guest_str(arg1), (struct statfs *)guest_ptr(arg2));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_FSTATFS: {
    result = ::fstatfs((int)arg1, (struct statfs *)guest_ptr(arg2));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_STATX: {
    result = syscall(SYS_statx, (int)(i32)arg1, guest_str(arg2),
                     (int)arg3, (unsigned)arg4, guest_ptr(arg5));
    if (result < 0) result = -errno;
    break;
  }

  // ---- Memory management ----

  case SYS_MMAP: {
    void *p = mmap((void *)arg1, (size_t)arg2, (int)arg3, (int)arg4,
                   (int)(i32)arg5, (off_t)arg6);
    result = (p == MAP_FAILED) ? -(i64)errno : (i64)(u64)p;
    break;
  }
  case SYS_MPROTECT:
    // No-op: passing through mprotect would make code pages unwritable,
    // which breaks the Sail model's memory access pattern.
    result = 0;
    break;
  case SYS_MUNMAP: {
    result = ::munmap(guest_ptr(arg1), (size_t)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_MREMAP: {
    void *p = ::mremap(guest_ptr(arg1), (size_t)arg2, (size_t)arg3,
                       (int)arg4, guest_ptr(arg5));
    result = (p == MAP_FAILED) ? -(i64)errno : (i64)(u64)p;
    break;
  }
  case SYS_BRK:
    result = do_brk(model, arg1);
    break;
  case SYS_FADVISE64:
  case SYS_MADVISE:
    result = 0;
    break;

  // ---- Directory and path operations ----

  case SYS_GETDENTS64: {
    result = syscall(SYS_getdents64, (int)arg1, guest_ptr(arg2), (size_t)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_GETCWD: {
    result = (i64)(u64)::getcwd((char *)guest_ptr(arg1), (size_t)arg2);
    if (result == 0) {
      result = -errno;
    } else {
      result = strlen((char *)guest_ptr(arg1)) + 1;
    }
    break;
  }
  case SYS_CHDIR: {
    result = ::chdir(guest_str(arg1));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_FCHDIR: {
    result = ::fchdir((int)arg1);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_ACCESS: {
    result = ::access(guest_str(arg1), (int)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_FACCESSAT:
  case SYS_FACCESSAT2: {
    result = ::faccessat((int)(i32)arg1, guest_str(arg2), (int)arg3, (int)arg4);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_READLINK: {
    result = ::readlink(guest_str(arg1), (char *)guest_ptr(arg2), (size_t)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_READLINKAT: {
    result = ::readlinkat((int)(i32)arg1, guest_str(arg2),
                          (char *)guest_ptr(arg3), (size_t)arg4);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_MKDIR: {
    result = ::mkdir(guest_str(arg1), (mode_t)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_RMDIR: {
    result = ::rmdir(guest_str(arg1));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_UNLINK: {
    result = ::unlink(guest_str(arg1));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_UNLINKAT: {
    result = ::unlinkat((int)(i32)arg1, guest_str(arg2), (int)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_RENAME: {
    result = ::rename(guest_str(arg1), guest_str(arg2));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_RENAMEAT: {
    result = ::renameat((int)(i32)arg1, guest_str(arg2),
                        (int)(i32)arg3, guest_str(arg4));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_CHMOD: {
    result = ::chmod(guest_str(arg1), (mode_t)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_FCHMOD: {
    result = ::fchmod((int)arg1, (mode_t)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_CHOWN: {
    result = ::chown(guest_str(arg1), (uid_t)arg2, (gid_t)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_FCHOWN: {
    result = ::fchown((int)arg1, (uid_t)arg2, (gid_t)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_UMASK: {
    result = ::umask((mode_t)arg1);
    break;
  }
  case SYS_LINK: {
    result = ::link(guest_str(arg1), guest_str(arg2));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_LINKAT: {
    result = ::linkat((int)(i32)arg1, guest_str(arg2),
                      (int)(i32)arg3, guest_str(arg4), (int)arg5);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_SYMLINK: {
    result = ::symlink(guest_str(arg1), guest_str(arg2));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_SYMLINKAT: {
    result = ::symlinkat(guest_str(arg1), (int)(i32)arg2, guest_str(arg3));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_LCHOWN: {
    result = ::lchown(guest_str(arg1), (uid_t)arg2, (gid_t)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_MKDIRAT: {
    result = ::mkdirat((int)(i32)arg1, guest_str(arg2), (mode_t)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_FCHMODAT: {
    result = ::fchmodat((int)(i32)arg1, guest_str(arg2), (mode_t)arg3, (int)arg4);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_FCHOWNAT: {
    result = ::fchownat((int)(i32)arg1, guest_str(arg2),
                        (uid_t)arg3, (gid_t)arg4, (int)arg5);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_RENAMEAT2: {
    result = syscall(SYS_renameat2, (int)(i32)arg1, guest_str(arg2),
                     (int)(i32)arg3, guest_str(arg4), (unsigned)arg5);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_MKNOD: {
    result = ::mknod(guest_str(arg1), (mode_t)arg2, (dev_t)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_MKNODAT: {
    result = ::mknodat((int)(i32)arg1, guest_str(arg2), (mode_t)arg3, (dev_t)arg4);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_GETDENTS: {
    result = syscall(SYS_getdents, (int)arg1, guest_ptr(arg2), (size_t)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_UTIMENSAT: {
    result = syscall(SYS_utimensat, (int)(i32)arg1,
                     arg2 ? guest_str(arg2) : nullptr,
                     arg3 ? (struct timespec *)guest_ptr(arg3) : nullptr,
                     (int)arg4);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_UTIME: {
    result = ::utime(guest_str(arg1),
                     arg2 ? (struct utimbuf *)guest_ptr(arg2) : nullptr);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_UTIMES: {
    result = ::utimes(guest_str(arg1),
                      arg2 ? (struct timeval *)guest_ptr(arg2) : nullptr);
    if (result < 0) result = -errno;
    break;
  }

  // ---- Process control ----

  case SYS_EXIT:
  case SYS_EXIT_GROUP:
    model.should_exit = true;
    model.exit_code = (int)(i32)arg1;
    result = 0;
    break;

  case SYS_ARCH_PRCTL: {
    #define ARCH_SET_GS  0x1001
    #define ARCH_SET_FS  0x1002
    #define ARCH_GET_FS  0x1003
    #define ARCH_GET_GS  0x1004
    switch (arg1) {
    case ARCH_SET_FS:
      model.zFS_BASE = arg2;
      result = 0;
      break;
    case ARCH_SET_GS:
      model.zGS_BASE = arg2;
      result = 0;
      break;
    case ARCH_GET_FS: {
      *(u64 *)guest_ptr(arg2) = model.zFS_BASE;
      result = 0;
      break;
    }
    case ARCH_GET_GS: {
      *(u64 *)guest_ptr(arg2) = model.zGS_BASE;
      result = 0;
      break;
    }
    default: result = -EINVAL; break;
    }
    break;
  }

  // ---- System info ----

  case SYS_UNAME: {
    struct utsname *uts = (struct utsname *)guest_ptr(arg1);
    memset(uts, 0, sizeof(*uts));
    strcpy(uts->sysname, "Linux");
    strcpy(uts->nodename, "sail-x86");
    strcpy(uts->release, "6.1.0");
    strcpy(uts->version, "#1");
    strcpy(uts->machine, "x86_64");
    result = 0;
    break;
  }
  case SYS_SYSINFO: {
    result = ::sysinfo((struct sysinfo *)guest_ptr(arg1));
    if (result < 0) result = -errno;
    break;
  }

  // ---- IDs ----

  case SYS_GETPID: result = ::getpid(); break;
  case SYS_GETUID: result = ::getuid(); break;
  case SYS_GETGID: result = ::getgid(); break;
  case SYS_GETEUID: result = ::geteuid(); break;
  case SYS_GETEGID: result = ::getegid(); break;
  case SYS_SETFSUID: result = syscall(SYS_setfsuid, (uid_t)arg1); break;
  case SYS_SETFSGID: result = syscall(SYS_setfsgid, (gid_t)arg1); break;
  case SYS_GETPPID: result = ::getppid(); break;
  case SYS_GETTID: result = ::getpid(); break;
  case SYS_SETPGID: result = ::setpgid((pid_t)arg1, (pid_t)arg2); if (result < 0) result = -errno; break;
  case SYS_GETPGRP: result = ::getpgrp(); break;
  case SYS_GETPGID: result = ::getpgid((pid_t)arg1); if (result < 0) result = -errno; break;
  case SYS_GETSID: result = ::getsid((pid_t)arg1); if (result < 0) result = -errno; break;
  case SYS_SETUID: result = ::setuid((uid_t)arg1); if (result < 0) result = -errno; break;
  case SYS_SETGID: result = ::setgid((gid_t)arg1); if (result < 0) result = -errno; break;
  case SYS_SETREUID: result = ::setreuid((uid_t)arg1, (uid_t)arg2); if (result < 0) result = -errno; break;
  case SYS_SETREGID: result = ::setregid((gid_t)arg1, (gid_t)arg2); if (result < 0) result = -errno; break;
  case SYS_SETRESUID: result = ::setresuid((uid_t)arg1, (uid_t)arg2, (uid_t)arg3); if (result < 0) result = -errno; break;
  case SYS_GETRESUID: {
    result = ::getresuid((uid_t *)guest_ptr(arg1), (uid_t *)guest_ptr(arg2),
                         (uid_t *)guest_ptr(arg3));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_SETRESGID: result = ::setresgid((gid_t)arg1, (gid_t)arg2, (gid_t)arg3); if (result < 0) result = -errno; break;
  case SYS_GETRESGID: {
    result = ::getresgid((gid_t *)guest_ptr(arg1), (gid_t *)guest_ptr(arg2),
                         (gid_t *)guest_ptr(arg3));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_SETGROUPS: {
    result = ::setgroups((int)arg1, (gid_t *)guest_ptr(arg2));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_GETGROUPS: {
    result = ::getgroups((int)arg1,
                         arg1 ? (gid_t *)guest_ptr(arg2) : nullptr);
    if (result < 0) result = -errno;
    break;
  }

  // ---- Time ----

  case SYS_CLOCK_GETTIME: {
    result = ::clock_gettime((clockid_t)arg1, (struct timespec *)guest_ptr(arg2));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_GETTIMEOFDAY: {
    result = ::gettimeofday((struct timeval *)guest_ptr(arg1), nullptr);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_TIME: {
    result = (i64)::time(arg1 ? (time_t *)guest_ptr(arg1) : nullptr);
    break;
  }
  case SYS_NANOSLEEP: {
    result = ::nanosleep((struct timespec *)guest_ptr(arg1),
                         arg2 ? (struct timespec *)guest_ptr(arg2) : nullptr);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_CLOCK_GETRES: {
    result = ::clock_getres((clockid_t)arg1,
                            arg2 ? (struct timespec *)guest_ptr(arg2) : nullptr);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_CLOCK_NANOSLEEP: {
    result = ::clock_nanosleep((clockid_t)arg1, (int)arg2,
                               (struct timespec *)guest_ptr(arg3),
                               arg4 ? (struct timespec *)guest_ptr(arg4) : nullptr);
    // clock_nanosleep returns error code directly (not -1/errno)
    if (result != 0) result = -result;
    break;
  }
  case SYS_GETITIMER: {
    result = ::getitimer((int)arg1, (struct itimerval *)guest_ptr(arg2));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_SETITIMER: {
    result = ::setitimer((int)arg1, (struct itimerval *)guest_ptr(arg2),
                         arg3 ? (struct itimerval *)guest_ptr(arg3) : nullptr);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_TIMES: {
    clock_t t = ::times((struct tms *)guest_ptr(arg1));
    result = (t == (clock_t)-1) ? -errno : (i64)t;
    break;
  }

  // ---- Signals (stubs for single-threaded emulation) ----

  case SYS_RT_SIGACTION:
  case SYS_RT_SIGPROCMASK:
  case SYS_SIGALTSTACK:
    result = 0;
    break;
  case SYS_TGKILL:
  case SYS_TKILL:
  case SYS_KILL: {
    int sig = (syscall_nr == SYS_TGKILL) ? (int)arg3 :
              (syscall_nr == SYS_TKILL) ? (int)arg2 : (int)arg2;
    if (sig == SIGABRT || sig == SIGKILL || sig == SIGTERM) {
      model.should_exit = true;
      model.exit_code = 128 + sig;
    }
    result = 0;
    break;
  }
  case SYS_ALARM:
    result = 0;
    break;

  // ---- Threading stubs ----

  case SYS_SET_TID_ADDRESS:
    result = ::getpid(); // return TID (same as PID for single-threaded)
    break;
  case SYS_SET_ROBUST_LIST:
  case SYS_RSEQ:
    result = 0;
    break;
  case SYS_FUTEX: {
    result = syscall(SYS_futex, guest_ptr(arg1), arg2, arg3, arg4, arg5, arg6);
    if (result < 0) result = -errno;
    break;
  }

  // ---- Resource limits ----

  case SYS_PRLIMIT64: {
    if (arg3 != 0) {
      struct rlimit *rl = (struct rlimit *)guest_ptr(arg3);
      rl->rlim_cur = RLIM_INFINITY;
      rl->rlim_max = RLIM_INFINITY;
    }
    result = 0;
    break;
  }
  case SYS_SETRLIMIT: {
    result = ::setrlimit((int)arg1, (struct rlimit *)guest_ptr(arg2));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_GETRLIMIT: {
    result = ::getrlimit((int)arg1, (struct rlimit *)guest_ptr(arg2));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_GETRUSAGE: {
    result = ::getrusage((int)arg1, (struct rusage *)guest_ptr(arg2));
    if (result < 0) result = -errno;
    break;
  }

  // ---- Random ----

  case SYS_GETRANDOM: {
    result = syscall(SYS_getrandom, guest_ptr(arg1), (size_t)arg2, (unsigned)arg3);
    if (result < 0) result = -errno;
    break;
  }

  // ---- Misc ----

  case SYS_IOCTL: {
    int fd = (int)arg1;
    u64 request = arg2;
    // Terminal ioctls: use host buffer to avoid size mismatches.
    if (request == 0x5401 /*TCGETS*/ || request == 0x5413 /*TIOCGWINSZ*/ ||
        request == 0x540F /*TIOCGPGRP*/ || request == 0x5410 /*TIOCSPGRP*/) {
      u8 buf[256] = {};
      size_t sz = (request == 0x5401) ? 36 :
                  (request == 0x5413) ? 8 : 4;
      int r = syscall(SYS_ioctl, fd, request, buf);
      if (r < 0) {
        result = -errno;
      } else {
        memcpy(guest_ptr(arg3), buf, sz);
        result = 0;
      }
    } else {
      result = -ENOTTY;
    }
    break;
  }
  case SYS_PRCTL:
    result = 0;
    break;
  case SYS_MEMBARRIER:
    result = 0;
    break;
  case SYS_SCHED_YIELD:
    result = ::sched_yield();
    break;
  case SYS_SCHED_SETAFFINITY: {
    result = syscall(SYS_sched_setaffinity, (pid_t)arg1, (size_t)arg2,
                     guest_ptr(arg3));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_SCHED_GETAFFINITY: {
    result = syscall(SYS_sched_getaffinity, (pid_t)arg1, (size_t)arg2,
                     guest_ptr(arg3));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_POLL: {
    result = ::poll((struct pollfd *)guest_ptr(arg1), (nfds_t)arg2, (int)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_PPOLL: {
    result = ::ppoll((struct pollfd *)guest_ptr(arg1), (nfds_t)arg2,
                     arg3 ? (struct timespec *)guest_ptr(arg3) : nullptr,
                     nullptr);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_SELECT: {
    result = ::select((int)arg1,
                      arg2 ? (fd_set *)guest_ptr(arg2) : nullptr,
                      arg3 ? (fd_set *)guest_ptr(arg3) : nullptr,
                      arg4 ? (fd_set *)guest_ptr(arg4) : nullptr,
                      arg5 ? (struct timeval *)guest_ptr(arg5) : nullptr);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_PSELECT6: {
    result = ::pselect((int)arg1,
                       arg2 ? (fd_set *)guest_ptr(arg2) : nullptr,
                       arg3 ? (fd_set *)guest_ptr(arg3) : nullptr,
                       arg4 ? (fd_set *)guest_ptr(arg4) : nullptr,
                       arg5 ? (struct timespec *)guest_ptr(arg5) : nullptr,
                       nullptr);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_SETSID: {
    result = ::setsid();
    if (result < 0) result = -errno;
    break;
  }
  case SYS_MSYNC: {
    result = ::msync(guest_ptr(arg1), (size_t)arg2, (int)arg3);
    if (result < 0) result = -errno;
    break;
  }

  // ---- Sockets (pass-through) ----

  case SYS_SOCKET: {
    result = ::socket((int)arg1, (int)arg2, (int)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_CONNECT: {
    result = ::connect((int)arg1, (struct sockaddr *)guest_ptr(arg2), (socklen_t)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_BIND: {
    result = ::bind((int)arg1, (struct sockaddr *)guest_ptr(arg2), (socklen_t)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_LISTEN: {
    result = ::listen((int)arg1, (int)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_SHUTDOWN: {
    result = ::shutdown((int)arg1, (int)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_SETSOCKOPT: {
    result = ::setsockopt((int)arg1, (int)arg2, (int)arg3,
                          guest_ptr(arg4), (socklen_t)arg5);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_GETSOCKOPT: {
    result = ::getsockopt((int)arg1, (int)arg2, (int)arg3,
                          guest_ptr(arg4), (socklen_t *)guest_ptr(arg5));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_ACCEPT:
  case SYS_ACCEPT4: {
    struct sockaddr *addr = arg2 ? (struct sockaddr *)guest_ptr(arg2) : nullptr;
    socklen_t *lenp = arg3 ? (socklen_t *)guest_ptr(arg3) : nullptr;
    result = (syscall_nr == SYS_ACCEPT4)
      ? ::accept4((int)arg1, addr, lenp, (int)arg4)
      : ::accept((int)arg1, addr, lenp);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_SOCKETPAIR: {
    result = ::socketpair((int)arg1, (int)arg2, (int)arg3,
                          (int *)guest_ptr(arg4));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_SENDTO: {
    result = ::sendto((int)arg1, guest_ptr(arg2), (size_t)arg3, (int)arg4,
                      arg5 ? (struct sockaddr *)guest_ptr(arg5) : nullptr,
                      (socklen_t)arg6);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_RECVFROM: {
    result = ::recvfrom((int)arg1, guest_ptr(arg2), (size_t)arg3, (int)arg4,
                        arg5 ? (struct sockaddr *)guest_ptr(arg5) : nullptr,
                        arg6 ? (socklen_t *)guest_ptr(arg6) : nullptr);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_SENDMSG: {
    result = ::sendmsg((int)arg1, (struct msghdr *)guest_ptr(arg2), (int)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_RECVMSG: {
    result = ::recvmsg((int)arg1, (struct msghdr *)guest_ptr(arg2), (int)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_GETSOCKNAME:
  case SYS_GETPEERNAME: {
    result = (syscall_nr == SYS_GETSOCKNAME)
      ? ::getsockname((int)arg1, (struct sockaddr *)guest_ptr(arg2),
                      (socklen_t *)guest_ptr(arg3))
      : ::getpeername((int)arg1, (struct sockaddr *)guest_ptr(arg2),
                      (socklen_t *)guest_ptr(arg3));
    if (result < 0) result = -errno;
    break;
  }

  // ---- xattr (stubs: pretend no xattrs exist) ----

  case SYS_setxattr:
  case SYS_lsetxattr:
  case SYS_fsetxattr:
  case SYS_removexattr:
  case SYS_lremovexattr:
  case SYS_fremovexattr:
    result = -ENOTSUP;
    break;
  case SYS_getxattr:
  case SYS_lgetxattr:
  case SYS_fgetxattr:
    result = -ENODATA;
    break;
  case SYS_listxattr:
  case SYS_llistxattr:
  case SYS_flistxattr:
    result = 0;  // empty list
    break;

  // ---- epoll ----

  case SYS_EPOLL_CREATE: {
    result = ::epoll_create((int)arg1);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_EPOLL_CREATE1: {
    result = ::epoll_create1((int)arg1);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_EPOLL_CTL: {
    result = ::epoll_ctl((int)arg1, (int)arg2, (int)arg3,
                         arg4 ? (struct epoll_event *)guest_ptr(arg4) : nullptr);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_EPOLL_WAIT:
  case SYS_EPOLL_PWAIT: {
    result = ::epoll_wait((int)arg1, (struct epoll_event *)guest_ptr(arg2),
                          (int)arg3, (int)arg4);
    if (result < 0) result = -errno;
    break;
  }

  // ---- eventfd / timerfd / signalfd / inotify ----

  case SYS_EVENTFD2: {
    result = ::eventfd((unsigned)arg1, (int)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_TIMERFD_CREATE: {
    result = ::timerfd_create((int)arg1, (int)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_TIMERFD_SETTIME: {
    result = ::timerfd_settime((int)arg1, (int)arg2,
                               (struct itimerspec *)guest_ptr(arg3),
                               arg4 ? (struct itimerspec *)guest_ptr(arg4) : nullptr);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_TIMERFD_GETTIME: {
    result = ::timerfd_gettime((int)arg1, (struct itimerspec *)guest_ptr(arg2));
    if (result < 0) result = -errno;
    break;
  }
  case SYS_SIGNALFD4: {
    result = ::signalfd((int)arg1, (sigset_t *)guest_ptr(arg2), (int)arg4);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_INOTIFY_INIT1: {
    result = ::inotify_init1((int)arg1);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_INOTIFY_ADD_WATCH: {
    result = ::inotify_add_watch((int)arg1, guest_str(arg2), (uint32_t)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_INOTIFY_RM_WATCH: {
    result = ::inotify_rm_watch((int)arg1, (int)arg2);
    if (result < 0) result = -errno;
    break;
  }

  default: {
    static std::set<u64> warned;
    if (syscall_nr < 1000 && warned.insert(syscall_nr).second)
      fprintf(stderr, "sail-x86: unimplemented syscall %lu\n", syscall_nr);
    result = -ENOSYS;
    break;
  }
  }

  write_gpr(model, RAX, (u64)result);
}

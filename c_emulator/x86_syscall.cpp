#include "x86_syscall.h"
#include <cstdio>
#include <cstring>
#include <set>
#include <string>
#include <vector>
#include <cstdlib>
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
#include <termios.h>
#include <signal.h>

// Linux x86-64 syscall numbers
#define SYS_READ            0
#define SYS_WRITE           1
#define SYS_OPEN            2
#define SYS_CLOSE           3
#define SYS_STAT            4
#define SYS_FSTAT           5
#define SYS_LSTAT           6
#define SYS_POLL            7
#define SYS_LSEEK           8
#define SYS_MMAP            9
#define SYS_MPROTECT        10
#define SYS_MUNMAP          11
#define SYS_MREMAP          25
#define SYS_BRK             12
#define SYS_RT_SIGACTION    13
#define SYS_RT_SIGPROCMASK  14
#define SYS_IOCTL           16
#define SYS_PREAD64         17
#define SYS_PWRITE64        18
#define SYS_WRITEV          20
#define SYS_ACCESS          21
#define SYS_PIPE            22
#define SYS_PIPE2           293
#define SYS_ALARM           27
#define SYS_MADVISE         28
#define SYS_DUP             32
#define SYS_DUP2            33
#define SYS_DUP3            292
#define SYS_NANOSLEEP       35
#define SYS_GETPID          39
#define SYS_SOCKET          41
#define SYS_CONNECT         42
#define SYS_SENDTO          44
#define SYS_RECVFROM        45
#define SYS_SENDMSG         46
#define SYS_RECVMSG         47
#define SYS_SHUTDOWN        48
#define SYS_BIND            49
#define SYS_LISTEN          50
#define SYS_GETSOCKNAME     51
#define SYS_GETPEERNAME     52
#define SYS_SETSOCKOPT      54
#define SYS_GETSOCKOPT      55
#define SYS_CLONE           56
#define SYS_FORK            57
#define SYS_EXECVE          59
#define SYS_EXIT            60
#define SYS_WAIT4           61
#define SYS_KILL            62
#define SYS_UNAME           63
#define SYS_FCNTL           72
#define SYS_FLOCK           73
#define SYS_FSYNC           74
#define SYS_FTRUNCATE       77
#define SYS_GETCWD          79
#define SYS_CHDIR           80
#define SYS_RENAME          82
#define SYS_MKDIR           83
#define SYS_RMDIR           84
#define SYS_UNLINK          87
#define SYS_READLINK        89
#define SYS_CHMOD           90
#define SYS_FCHMOD          91
#define SYS_CHOWN           92
#define SYS_FCHOWN          93
#define SYS_UMASK           95
#define SYS_GETTIMEOFDAY    96
#define SYS_GETRLIMIT       97
#define SYS_GETRUSAGE       98
#define SYS_SYSINFO         99
#define SYS_GETUID          102
#define SYS_GETGID          104
#define SYS_GETEUID         107
#define SYS_GETEGID         108
#define SYS_GETPPID         110
#define SYS_GETPGRP         111
#define SYS_SETSID          112
#define SYS_GETGROUPS       115
#define SYS_SETFSUID        122
#define SYS_SETFSGID        123
#define SYS_SIGALTSTACK     131
#define SYS_STATFS          137
#define SYS_FSTATFS         138
#define SYS_PRCTL           157
#define SYS_ARCH_PRCTL      158
#define SYS_GETTID          186
#define SYS_TIME            201
#define SYS_FADVISE64       221
#define SYS_FUTEX           202
#define SYS_SCHED_GETAFFINITY 204
#define SYS_GETDENTS64      217
#define SYS_SET_TID_ADDRESS 218
#define SYS_CLOCK_GETTIME   228
#define SYS_EXIT_GROUP      231
#define SYS_EPOLL_WAIT      232
#define SYS_EPOLL_CTL       233
#define SYS_TGKILL          234
#define SYS_OPENAT          257
#define SYS_NEWFSTATAT      262
#define SYS_UNLINKAT        263
#define SYS_RENAMEAT        264
#define SYS_FACCESSAT       269
#define SYS_SET_ROBUST_LIST 273
#define SYS_READLINKAT      267
#define SYS_PIPE2_ALT       293
#define SYS_PRLIMIT64       302
#define SYS_GETRANDOM       318
#define SYS_MEMBARRIER      324
#define SYS_STATX           332
#define SYS_RSEQ            334
#define SYS_FACCESSAT2      439
#define SYS_EPOLL_CREATE1   291
#define SYS_EVENTFD2        290

// GPR indices matching the Sail model
static constexpr int RAX = 0, RCX = 1, RDX = 2, RBX = 3;
static constexpr int RSP = 4, RBP = 5, RSI = 6, RDI = 7;
static constexpr int R8 = 8, R9 = 9, R10 = 10, R11 = 11;

static u64 read_gpr(x86::Model &m, int idx) {
  return m.zGPR.data[idx];
}

static void write_gpr(x86::Model &m, int idx, u64 val) {
  m.zGPR.data[idx] = val;
}

// Copy a string from guest memory.
static std::string read_guest_string(x86::Model &m, u64 addr) {
  std::string s;
  while (true) {
    u8 c;
    m.memory.read(addr++, &c, 1);
    if (c == 0) break;
    s += (char)c;
  }
  return s;
}

// Bounce-buffer helpers for syscalls with variable-length I/O buffers.
// Guest pages are individually mmap'd and non-contiguous in host memory,
// so we can't pass a guest pointer directly to host syscalls.

// Read from host fd into guest memory.
static ssize_t host_read_to_guest(x86::Model &m, int fd, u64 guest_buf,
                                  size_t count) {
  std::vector<u8> tmp(count);
  ssize_t n = ::read(fd, tmp.data(), count);
  if (n > 0) m.memory.write(guest_buf, tmp.data(), n);
  return n;
}

// Pread from host fd into guest memory.
static ssize_t host_pread_to_guest(x86::Model &m, int fd, u64 guest_buf,
                                   size_t count, off_t offset) {
  std::vector<u8> tmp(count);
  ssize_t n = ::pread(fd, tmp.data(), count, offset);
  if (n > 0) m.memory.write(guest_buf, tmp.data(), n);
  return n;
}

// Write from guest memory to host fd.
static ssize_t guest_write_to_host(x86::Model &m, int fd, u64 guest_buf,
                                   size_t count) {
  std::vector<u8> tmp(count);
  m.memory.read(guest_buf, tmp.data(), count);
  return ::write(fd, tmp.data(), count);
}

// Pwrite from guest memory to host fd.
static ssize_t guest_pwrite_to_host(x86::Model &m, int fd, u64 guest_buf,
                                    size_t count, off_t offset) {
  std::vector<u8> tmp(count);
  m.memory.read(guest_buf, tmp.data(), count);
  return ::pwrite(fd, tmp.data(), count, offset);
}

static i64 do_brk(x86::Model &m, u64 addr) {
  if (addr == 0 || addr < m.memory.brk_base) {
    return (i64)m.memory.brk_current;
  }
  if (addr > m.memory.brk_current) {
    m.memory.map_range(m.memory.brk_current, addr - m.memory.brk_current);
  }
  m.memory.brk_current = addr;
  return (i64)m.memory.brk_current;
}

// Emulated mmap region tracker.
static u64 mmap_next = 0x7F0000000000ULL;

static i64 do_mmap(x86::Model &m, u64 addr, u64 length,
                       u64 prot, u64 flags, u64 fd,
                       u64 offset) {
  (void)prot;
  if (length == 0) return -EINVAL;

  length = (length + 4095) & ~4095ULL;

  u64 result_addr;
  if (addr != 0 && (flags & MAP_FIXED)) {
    result_addr = addr;
  } else if (addr != 0 && (flags & MAP_FIXED_NOREPLACE)) {
    result_addr = addr;
  } else {
    result_addr = mmap_next;
    mmap_next += length;
  }

  m.memory.map_range(result_addr, length);

  if (flags & MAP_ANONYMOUS) {
    m.memory.zero_range(result_addr, length);
  } else if ((i64)fd >= 0) {
    u8 buf[4096];
    size_t total_read = 0;
    u64 dst = result_addr;
    lseek((int)fd, offset, SEEK_SET);
    size_t remaining = length;
    while (remaining > 0) {
      size_t chunk = remaining > sizeof(buf) ? sizeof(buf) : remaining;
      ssize_t n = ::read((int)fd, buf, chunk);
      if (n <= 0) break;
      m.memory.write(dst, buf, n);
      dst += n;
      total_read += n;
      remaining -= n;
    }
    if (total_read < length) {
      m.memory.zero_range(result_addr + total_read, length - total_read);
    }
  }

  return (i64)result_addr;
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

  // ---- File I/O (bounce buffer for page-safety) ----

  case SYS_READ: {
    if (arg3 == 0) { result = 0; break; }
    model.memory.map_range(arg2, arg3);
    ssize_t n = host_read_to_guest(model, (int)arg1, arg2, arg3);
    result = (n < 0) ? -errno : n;
    break;
  }
  case SYS_PREAD64: {
    if (arg3 == 0) { result = 0; break; }
    model.memory.map_range(arg2, arg3);
    ssize_t n = host_pread_to_guest(model, (int)arg1, arg2, arg3, (off_t)arg4);
    result = (n < 0) ? -errno : n;
    break;
  }
  case SYS_WRITE: {
    if (arg3 == 0) { result = 0; break; }
    ssize_t n = guest_write_to_host(model, (int)arg1, arg2, arg3);
    result = (n < 0) ? -errno : n;
    break;
  }
  case SYS_PWRITE64: {
    if (arg3 == 0) { result = 0; break; }
    ssize_t n = guest_pwrite_to_host(model, (int)arg1, arg2, arg3, (off_t)arg4);
    result = (n < 0) ? -errno : n;
    break;
  }
  case SYS_WRITEV: {
    int fd = (int)arg1;
    u64 iov_addr = arg2;
    int iovcnt = (int)arg3;
    ssize_t total = 0;
    for (int i = 0; i < iovcnt; i++) {
      u64 base, len;
      model.memory.read(iov_addr + i * 16, &base, 8);
      model.memory.read(iov_addr + i * 16 + 8, &len, 8);
      if (len > 0 && base != 0) {
        ssize_t n = guest_write_to_host(model, fd, base, len);
        if (n < 0) { total = -errno; break; }
        total += n;
        if ((size_t)n < len) break;
      }
    }
    result = total;
    break;
  }

  // ---- File open/close/seek ----

  case SYS_OPEN: {
    std::string path = read_guest_string(model, arg1);
    result = ::open(path.c_str(), (int)arg2, (mode_t)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_OPENAT: {
    std::string path = read_guest_string(model, arg2);
    result = ::openat((int)(i32)arg1, path.c_str(), (int)arg3, (mode_t)arg4);
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
    int fds[2];
    result = ::pipe(fds);
    if (result == 0) {
      model.memory.write(arg1, fds, sizeof(fds));
    } else {
      result = -errno;
    }
    break;
  }
  case SYS_PIPE2: {
    int fds[2];
    result = ::pipe2(fds, (int)arg2);
    if (result == 0) {
      model.memory.write(arg1, fds, sizeof(fds));
    } else {
      result = -errno;
    }
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
  case SYS_FTRUNCATE: {
    result = ::ftruncate((int)arg1, (off_t)arg2);
    if (result < 0) result = -errno;
    break;
  }

  // ---- Stat family ----

  case SYS_STAT:
  case SYS_LSTAT: {
    std::string path = read_guest_string(model, arg1);
    struct stat st;
    result = (syscall_nr == SYS_STAT)
      ? ::stat(path.c_str(), &st) : ::lstat(path.c_str(), &st);
    if (result == 0) {
      model.memory.write(arg2, &st, sizeof(st));
    } else {
      result = -errno;
    }
    break;
  }
  case SYS_FSTAT: {
    struct stat st;
    result = ::fstat((int)arg1, &st);
    if (result == 0) {
      model.memory.write(arg2, &st, sizeof(st));
    } else {
      result = -errno;
    }
    break;
  }
  case SYS_NEWFSTATAT: {
    std::string path = read_guest_string(model, arg2);
    struct stat st;
    result = ::fstatat((int)(i32)arg1, path.c_str(), &st, (int)arg4);
    if (result == 0) {
      model.memory.write(arg3, &st, sizeof(st));
    } else {
      result = -errno;
    }
    break;
  }
  case SYS_STATFS: {
    std::string path = read_guest_string(model, arg1);
    struct statfs st;
    result = ::statfs(path.c_str(), &st);
    if (result == 0) {
      model.memory.write(arg2, &st, sizeof(st));
    } else {
      result = -errno;
    }
    break;
  }
  case SYS_FSTATFS: {
    struct statfs st;
    result = ::fstatfs((int)arg1, &st);
    if (result == 0) {
      model.memory.write(arg2, &st, sizeof(st));
    } else {
      result = -errno;
    }
    break;
  }
  case SYS_STATX: {
    // statx(dirfd, pathname, flags, mask, statxbuf)
    std::string path = read_guest_string(model, arg2);
    struct statx stx;
    result = syscall(SYS_statx, (int)(i32)arg1, path.c_str(),
                     (int)arg3, (unsigned)arg4, &stx);
    if (result == 0) {
      model.memory.write(arg5, &stx, sizeof(stx));
    } else {
      result = -errno;
    }
    break;
  }

  // ---- Memory management ----

  case SYS_MMAP:
    result = do_mmap(model, arg1, arg2, arg3, arg4, arg5, arg6);
    break;
  case SYS_MPROTECT:
    result = 0;
    break;
  case SYS_MUNMAP:
    result = 0;
    break;
  case SYS_MREMAP: {
    u64 old_addr = arg1;
    u64 old_size = (arg2 + 4095) & ~4095ULL;
    u64 new_size = (arg3 + 4095) & ~4095ULL;
    u64 flags = arg4;
    if (new_size == 0) { result = -EINVAL; break; }
    if (new_size <= old_size) {
      result = (i64)old_addr;
    } else {
      u64 new_addr;
      if (flags & 1 /* MREMAP_MAYMOVE */) {
        new_addr = mmap_next;
        mmap_next += new_size;
      } else {
        new_addr = old_addr;
      }
      model.memory.map_range(new_addr, new_size);
      if (new_addr != old_addr) {
        for (u64 i = 0; i < old_size; i += 4096) {
          u8 buf[4096];
          model.memory.read(old_addr + i, buf, 4096);
          model.memory.write(new_addr + i, buf, 4096);
        }
      }
      model.memory.zero_range(new_addr + old_size, new_size - old_size);
      result = (i64)new_addr;
    }
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
    // Use a bounce buffer — guest pages aren't contiguous.
    size_t count = arg3;
    std::vector<u8> tmp(count);
    result = syscall(SYS_getdents64, (int)arg1, tmp.data(), count);
    if (result > 0) {
      model.memory.write(arg2, tmp.data(), result);
    } else if (result < 0) {
      result = -errno;
    }
    break;
  }
  case SYS_GETCWD: {
    char cwd[4096];
    if (getcwd(cwd, sizeof(cwd))) {
      size_t len = strlen(cwd) + 1;
      if (len > arg2) { result = -ERANGE; break; }
      model.memory.write(arg1, cwd, len);
      result = len;
    } else {
      result = -errno;
    }
    break;
  }
  case SYS_CHDIR: {
    std::string path = read_guest_string(model, arg1);
    result = ::chdir(path.c_str());
    if (result < 0) result = -errno;
    break;
  }
  case SYS_ACCESS: {
    std::string path = read_guest_string(model, arg1);
    result = ::access(path.c_str(), (int)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_FACCESSAT:
  case SYS_FACCESSAT2: {
    std::string path = read_guest_string(model, arg2);
    result = ::faccessat((int)(i32)arg1, path.c_str(), (int)arg3, (int)arg4);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_READLINK: {
    std::string path = read_guest_string(model, arg1);
    char buf[4096];
    ssize_t n = ::readlink(path.c_str(), buf, sizeof(buf));
    if (n >= 0) {
      if ((u64)n > arg3) n = arg3;
      model.memory.write(arg2, buf, n);
      result = n;
    } else {
      result = -errno;
    }
    break;
  }
  case SYS_READLINKAT: {
    int dirfd = (int)(i64)arg1;
    std::string path = read_guest_string(model, arg2);
    char buf[4096];
    ssize_t n = ::readlinkat(dirfd, path.c_str(), buf, sizeof(buf));
    if (n >= 0) {
      if ((u64)n > arg4) n = arg4;
      model.memory.write(arg3, buf, n);
      result = n;
    } else {
      result = -errno;
    }
    break;
  }
  case SYS_MKDIR: {
    std::string path = read_guest_string(model, arg1);
    result = ::mkdir(path.c_str(), (mode_t)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_RMDIR: {
    std::string path = read_guest_string(model, arg1);
    result = ::rmdir(path.c_str());
    if (result < 0) result = -errno;
    break;
  }
  case SYS_UNLINK: {
    std::string path = read_guest_string(model, arg1);
    result = ::unlink(path.c_str());
    if (result < 0) result = -errno;
    break;
  }
  case SYS_UNLINKAT: {
    std::string path = read_guest_string(model, arg2);
    result = ::unlinkat((int)(i32)arg1, path.c_str(), (int)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_RENAME: {
    std::string old_path = read_guest_string(model, arg1);
    std::string new_path = read_guest_string(model, arg2);
    result = ::rename(old_path.c_str(), new_path.c_str());
    if (result < 0) result = -errno;
    break;
  }
  case SYS_RENAMEAT: {
    std::string old_path = read_guest_string(model, arg2);
    std::string new_path = read_guest_string(model, arg4);
    result = ::renameat((int)(i32)arg1, old_path.c_str(),
                        (int)(i32)arg3, new_path.c_str());
    if (result < 0) result = -errno;
    break;
  }
  case SYS_CHMOD: {
    std::string path = read_guest_string(model, arg1);
    result = ::chmod(path.c_str(), (mode_t)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_FCHMOD: {
    result = ::fchmod((int)arg1, (mode_t)arg2);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_CHOWN: {
    std::string path = read_guest_string(model, arg1);
    result = ::chown(path.c_str(), (uid_t)arg2, (gid_t)arg3);
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
      u64 val = model.zFS_BASE;
      model.memory.write(arg2, &val, 8);
      result = 0;
      break;
    }
    case ARCH_GET_GS: {
      u64 val = model.zGS_BASE;
      model.memory.write(arg2, &val, 8);
      result = 0;
      break;
    }
    default: result = -EINVAL; break;
    }
    break;
  }

  // ---- System info ----

  case SYS_UNAME: {
    struct utsname uts;
    memset(&uts, 0, sizeof(uts));
    strcpy(uts.sysname, "Linux");
    strcpy(uts.nodename, "sail-x86");
    strcpy(uts.release, "6.1.0");
    strcpy(uts.version, "#1");
    strcpy(uts.machine, "x86_64");
    model.memory.write(arg1, &uts, sizeof(uts));
    result = 0;
    break;
  }
  case SYS_SYSINFO: {
    struct sysinfo si;
    result = ::sysinfo(&si);
    if (result == 0) {
      model.memory.write(arg1, &si, sizeof(si));
    } else {
      result = -errno;
    }
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
  case SYS_GETPGRP: result = ::getpgrp(); break;
  case SYS_GETGROUPS: {
    int size = (int)arg1;
    if (size == 0) {
      result = ::getgroups(0, nullptr);
    } else {
      std::vector<gid_t> groups(size);
      result = ::getgroups(size, groups.data());
      if (result > 0) {
        model.memory.write(arg2, groups.data(), result * sizeof(gid_t));
      }
    }
    if (result < 0) result = -errno;
    break;
  }

  // ---- Time ----

  case SYS_CLOCK_GETTIME: {
    struct timespec ts;
    result = ::clock_gettime((clockid_t)arg1, &ts);
    if (result == 0) {
      model.memory.write(arg2, &ts, sizeof(ts));
    } else {
      result = -errno;
    }
    break;
  }
  case SYS_GETTIMEOFDAY: {
    struct timeval tv;
    result = ::gettimeofday(&tv, nullptr);
    if (result == 0) {
      model.memory.write(arg1, &tv, sizeof(tv));
    } else {
      result = -errno;
    }
    break;
  }
  case SYS_TIME: {
    time_t t = ::time(nullptr);
    if (arg1 != 0) {
      model.memory.write(arg1, &t, sizeof(t));
    }
    result = (i64)t;
    break;
  }
  case SYS_NANOSLEEP: {
    struct timespec req;
    model.memory.read(arg1, &req, sizeof(req));
    result = ::nanosleep(&req, nullptr);
    if (result < 0) result = -errno;
    break;
  }

  // ---- Signals (stubs for single-threaded emulation) ----

  case SYS_RT_SIGACTION:
  case SYS_RT_SIGPROCMASK:
  case SYS_SIGALTSTACK:
    result = 0;
    break;
  case SYS_TGKILL:
  case SYS_KILL: {
    int sig = (syscall_nr == SYS_TGKILL) ? (int)arg3 : (int)arg2;
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
    u32 *host_addr = (u32 *)model.memory.host_ptr(arg1);
    result = syscall(SYS_futex, host_addr, arg2, arg3, arg4, arg5, arg6);
    if (result < 0) result = -errno;
    break;
  }

  // ---- Resource limits ----

  case SYS_PRLIMIT64: {
    if (arg3 != 0) {
      struct rlimit rl;
      rl.rlim_cur = RLIM_INFINITY;
      rl.rlim_max = RLIM_INFINITY;
      model.memory.write(arg3, &rl, sizeof(rl));
    }
    result = 0;
    break;
  }
  case SYS_GETRLIMIT: {
    struct rlimit rl;
    result = ::getrlimit((int)arg1, &rl);
    if (result == 0) {
      model.memory.write(arg2, &rl, sizeof(rl));
    } else {
      result = -errno;
    }
    break;
  }
  case SYS_GETRUSAGE: {
    struct rusage ru;
    result = ::getrusage((int)arg1, &ru);
    if (result == 0) {
      model.memory.write(arg2, &ru, sizeof(ru));
    } else {
      result = -errno;
    }
    break;
  }

  // ---- Random ----

  case SYS_GETRANDOM: {
    size_t count = arg2;
    if (count == 0) { result = 0; break; }
    std::vector<u8> tmp(count);
    result = syscall(SYS_getrandom, tmp.data(), count, (unsigned)arg3);
    if (result > 0) {
      model.memory.write(arg1, tmp.data(), result);
    } else if (result < 0) {
      result = -errno;
    }
    break;
  }

  // ---- Misc ----

  case SYS_IOCTL: {
    int fd = arg1;
    u64 request = arg2;
    u64 argp = arg3;
    // Pass through terminal ioctls to the host.
    if (request == TCGETS || request == TIOCGWINSZ ||
        request == TIOCGPGRP || request == TIOCSPGRP) {
      u8 buf[256] = {};
      size_t sz = (request == TCGETS) ? 36 :
                  (request == TIOCGWINSZ) ? 8 : 4;
      int r = ::ioctl(fd, request, buf);
      if (r < 0) {
        result = -errno;
      } else {
        model.memory.write(argp, buf, sz);
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
  case SYS_SCHED_GETAFFINITY: {
    size_t cpusetsize = arg2;
    std::vector<u8> tmp(cpusetsize, 0);
    result = syscall(SYS_sched_getaffinity, (pid_t)arg1, cpusetsize,
                     tmp.data());
    if (result >= 0) {
      model.memory.write(arg3, tmp.data(), cpusetsize);
    } else {
      result = -errno;
    }
    break;
  }
  case SYS_POLL: {
    // poll(fds, nfds, timeout)
    u64 nfds = arg2;
    size_t sz = nfds * sizeof(struct pollfd);
    std::vector<struct pollfd> fds(nfds);
    model.memory.read(arg1, fds.data(), sz);
    result = ::poll(fds.data(), nfds, (int)arg3);
    if (result >= 0) {
      model.memory.write(arg1, fds.data(), sz);
    } else {
      result = -errno;
    }
    break;
  }
  case SYS_SETSID: {
    result = ::setsid();
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
    std::vector<u8> addr(arg3);
    model.memory.read(arg2, addr.data(), arg3);
    result = ::connect((int)arg1, (struct sockaddr *)addr.data(), (socklen_t)arg3);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_BIND: {
    std::vector<u8> addr(arg3);
    model.memory.read(arg2, addr.data(), arg3);
    result = ::bind((int)arg1, (struct sockaddr *)addr.data(), (socklen_t)arg3);
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
    std::vector<u8> optval(arg5);
    model.memory.read(arg4, optval.data(), arg5);
    result = ::setsockopt((int)arg1, (int)arg2, (int)arg3,
                          optval.data(), (socklen_t)arg5);
    if (result < 0) result = -errno;
    break;
  }
  case SYS_GETSOCKOPT: {
    u8 optval[256];
    socklen_t optlen = sizeof(optval);
    model.memory.read(arg5, &optlen, sizeof(optlen));
    if (optlen > sizeof(optval)) optlen = sizeof(optval);
    result = ::getsockopt((int)arg1, (int)arg2, (int)arg3, optval, &optlen);
    if (result == 0) {
      model.memory.write(arg4, optval, optlen);
      model.memory.write(arg5, &optlen, sizeof(optlen));
    } else {
      result = -errno;
    }
    break;
  }
  case SYS_GETSOCKNAME:
  case SYS_GETPEERNAME: {
    u8 addr[128];
    socklen_t addrlen = sizeof(addr);
    model.memory.read(arg3, &addrlen, sizeof(addrlen));
    if (addrlen > sizeof(addr)) addrlen = sizeof(addr);
    result = (syscall_nr == SYS_GETSOCKNAME)
      ? ::getsockname((int)arg1, (struct sockaddr *)addr, &addrlen)
      : ::getpeername((int)arg1, (struct sockaddr *)addr, &addrlen);
    if (result == 0) {
      model.memory.write(arg2, addr, addrlen);
      model.memory.write(arg3, &addrlen, sizeof(addrlen));
    } else {
      result = -errno;
    }
    break;
  }

  // ---- epoll (stubs) ----

  case SYS_EPOLL_CREATE1:
    result = ::epoll_create1((int)arg1);
    if (result < 0) result = -errno;
    break;
  case SYS_EPOLL_CTL:
  case SYS_EPOLL_WAIT:
    result = -ENOSYS;
    break;
  case SYS_EVENTFD2:
    result = -ENOSYS;
    break;

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

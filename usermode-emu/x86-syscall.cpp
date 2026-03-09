#include "x86-syscall.h"
#include <cstring>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/utsname.h>
#include <sys/resource.h>
#include <time.h>
#include <errno.h>
#include <sys/syscall.h>
#include <sys/ioctl.h>
#include <signal.h>
#include <sys/times.h>

// GPR indices matching the Sail model
static constexpr int RAX = 0;
static constexpr int RDI = 7;
static constexpr int RSI = 6;
static constexpr int RDX = 2;
static constexpr int R10 = 10;
static constexpr int R8 = 8;
static constexpr int R9 = 9;

void emulate_syscall(x86::Model &model) {
  u64 syscall_nr = model.zGPR.data[RAX];
  u64 arg1 = model.zGPR.data[RDI];
  u64 arg2 = model.zGPR.data[RSI];
  u64 arg3 = model.zGPR.data[RDX];
  u64 arg4 = model.zGPR.data[R10];
  u64 arg5 = model.zGPR.data[R8];
  u64 arg6 = model.zGPR.data[R9];
  i64 result;

  switch (syscall_nr) {
  case SYS_mmap: {
    void *p = mmap((void *)arg1, (size_t)arg2, (int)arg3, (int)arg4,
                   (int)(i32)arg5, (off_t)arg6);
    result = (p == MAP_FAILED) ? -(i64)errno : (u64)p;
    break;
  }
  case SYS_mremap: {
    void *p = ::mremap((void *)arg1, (size_t)arg2, (size_t)arg3,
                       (int)arg4, (void *)arg5);
    result = (p == MAP_FAILED) ? -(i64)errno : (u64)p;
    break;
  }
  case SYS_brk:
    if (arg1 != 0 && model.brk_base <= arg1 && arg1 <= model.brk_limit)
      model.brk_current = arg1;
    result = (i64)model.brk_current;
    break;
  case SYS_getcwd: {
    // getcwd (returns length, not 0/-1)
    char *p = ::getcwd((char *)arg1, (size_t)arg2);
    result = p ? (i64)strlen(p) + 1 : -(i64)errno;
    break;
  }

  // Process control
  case SYS_exit:
  case SYS_exit_group:
    model.should_exit = true;
    model.exit_code = (int)(i32)arg1;
    result = 0;
    break;
  case SYS_arch_prctl: {
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
    case ARCH_GET_FS:
      *(u64 *)arg2 = model.zFS_BASE;
      result = 0;
      break;
    case ARCH_GET_GS:
      *(u64 *)arg2 = model.zGS_BASE;
      result = 0;
      break;
    default:
      result = -EINVAL;
      break;
    }
    break;
  }

  // System info
  case SYS_uname: {
    struct utsname *uts = (struct utsname *)arg1;
    memset(uts, 0, sizeof(*uts));
    strcpy(uts->sysname, "Linux");
    strcpy(uts->nodename, "sail-x86");
    strcpy(uts->release, "6.1.0");
    strcpy(uts->version, "#1");
    strcpy(uts->machine, "x86_64");
    result = 0;
    break;
  }

  // Time (special return conventions)
  case SYS_clock_nanosleep:
    // clock_nanosleep returns error code directly (not -1/errno)
    result = ::clock_nanosleep((clockid_t)arg1, (int)arg2,
                               (struct timespec *)arg3,
                               arg4 ? (struct timespec *)arg4 : nullptr);
    if (result != 0) result = -result;
    break;
  case SYS_times: {
    clock_t t = ::times((struct tms *)arg1);
    result = (t == (clock_t)-1) ? -errno : (i64)t;
    break;
  }

  // Signals (stubs for single-threaded emulation)
  case SYS_rt_sigaction:
  case SYS_rt_sigprocmask:
  case SYS_sigaltstack:
  case SYS_alarm:
    result = 0;
    break;
  case SYS_tgkill:
  case SYS_tkill:
  case SYS_kill: {
    int sig = (syscall_nr == SYS_tgkill) ? (int)arg3 :
              (syscall_nr == SYS_tkill) ? (int)arg2 : (int)arg2;
    if (sig == SIGABRT || sig == SIGKILL || sig == SIGTERM) {
      model.should_exit = true;
      model.exit_code = 128 + sig;
    }
    result = 0;
    break;
  }

  // IOCTL (terminal handling)
  case SYS_ioctl: {
    u64 request = arg2;
    // Terminal ioctls: use host buffer to avoid size mismatches.
    if (request == TCGETS || request == TIOCGWINSZ ||
        request == TIOCGPGRP || request == TIOCSPGRP) {
      u8 buf[256] = {};
      size_t sz = (request == TCGETS) ? 36 :
                  (request == TIOCGWINSZ) ? 8 : 4;
      int r = syscall(SYS_ioctl, (int)arg1, request, buf);
      if (r < 0) {
        result = -errno;
      } else {
        memcpy((void *)arg3, buf, sz);
        result = 0;
      }
    } else {
      result = syscall(SYS_ioctl, arg1, arg2, arg3);
      if (result < 0) result = -errno;
    }
    break;
  }

  // Default: pass through to kernel
  default:
    result = syscall(syscall_nr, arg1, arg2, arg3, arg4, arg5, arg6);
    if (result < 0) result = -errno;
    break;
  }

  model.zGPR.data[RAX] = result;
}

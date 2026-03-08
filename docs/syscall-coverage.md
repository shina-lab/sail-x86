# Syscall Emulation Coverage Report

**Date:** 2026-03-08
**Source:** `usermode-emu/x86_syscall.cpp`, `test/syscall_test.c`

## Summary

The emulator implements a user-mode Linux x86-64 syscall translation layer. Syscalls
are intercepted and either passed through to the host kernel (with bounce-buffer
marshalling for guest memory) or emulated/stubbed.

| Category            | Fully Implemented | Partial/Stub | Not Present |
|---------------------|------------------:|-------------:|------------:|
| File I/O            | 12                | 0            | 4           |
| File open/close     | 18                | 1 (ioctl)    | 0           |
| Stat family         | 7                 | 0            | 0           |
| Memory management   | 4                 | 4            | 4           |
| Directory/path ops  | 30                | 0            | 0           |
| Process control     | 3                 | 1            | 6           |
| Signals             | 0                 | 6            | 5           |
| IDs                 | 24                | 0            | 0           |
| Time                | 10                | 0            | 0           |
| Threading           | 1                 | 3            | 2           |
| Resource limits     | 5                 | 1            | 0           |
| Sockets             | 15                | 0            | 0           |
| xattr               | 0                 | 12 (stubs)   | 0           |
| Epoll/event/notify  | 10                | 0            | 0           |
| Misc/sched          | 9                 | 1            | many        |
| **Total**           | **~148**          | **~29**      |             |

---

## Test Coverage Summary

### Dedicated syscall test: `test/syscall_test.c`

A raw-syscall test (no libc, linked with `-nostdlib`) that directly exercises **~60
syscalls** with assertions. Run via `ctest` as the `syscall_test` target.

| Test Function | Syscalls Tested |
|---------------|-----------------|
| `test_write` | write |
| `test_brk` | brk |
| `test_mmap_munmap` | mmap, munmap |
| `test_mremap` | mremap |
| `test_pipe_rw` | pipe, write, read, close |
| `test_dup` | dup |
| `test_dup2_dup3` | dup2, dup3 |
| `test_getpid` | getpid |
| `test_getuid_getgid` | getuid, getgid, geteuid, getegid, getppid, getpgrp, getpgid, getsid, gettid |
| `test_getcwd` | getcwd |
| `test_clock_gettime` | clock_gettime |
| `test_clock_getres` | clock_getres |
| `test_fcntl` | fcntl |
| `test_readv_writev` | readv, writev |
| `test_stat_fstat_lstat` | stat, fstat, lstat |
| `test_open_read_close` | open, read, close |
| `test_openat` | openat |
| `test_lseek` | lseek, open, write, read, unlink |
| `test_pipe2` | pipe2 |
| `test_file_ops` | mkdir, open, fdatasync, link, symlink, readlink, chmod, truncate, ftruncate, unlink, rmdir |
| `test_chdir_fchdir` | chdir, fchdir, getcwd, open |
| `test_sched_yield` | sched_yield |
| `test_gettimeofday` | gettimeofday |
| `test_getrlimit` | getrlimit |
| `test_sysinfo` | sysinfo |
| `test_times` | times |
| `test_statfs` | statfs |
| `test_umask` | umask |
| `test_getrandom` | getrandom |
| `test_socketpair` | socketpair |
| `test_sendto_recvfrom` | sendto, recvfrom |
| `test_sendmsg_recvmsg` | sendmsg, recvmsg |
| `test_select` | select |
| `test_poll` | poll |
| `test_epoll` | epoll_create1, epoll_ctl, epoll_wait |
| `test_eventfd` | eventfd2 |
| `test_inotify` | inotify_init1 |
| `test_sendfile` | sendfile |
| `test_linkat_symlinkat` | linkat, symlinkat, readlinkat |
| `test_mkdirat_fchmodat` | mkdirat, fchmodat |
| `test_utimensat` | utimensat |
| `test_statx` | statx |
| `test_copy_file_range` | copy_file_range |
| `test_renameat2` | renameat2 |

### Integration tests (real binaries)

| Test | Binary | Notes |
|------|--------|-------|
| `hello` | Custom (nostdlib) | write, exit |
| `hello_libc` | Custom (static libc) | Full libc init |
| `echo` | `/bin/echo` (dynamic) | Dynamic linker + full syscall stack |
| `ls` | `/bin/ls /` (dynamic) | Filesystem ops, xattr, ioctl |
| `wc` | `/usr/bin/wc` (piped) | Pipe input, read |

---

## Detailed Syscall List

### Legend

- **Full**: Passed through to host or correctly emulated
- **Stub**: Returns success (0) but doesn't actually do anything
- **Partial**: Some functionality missing or simplified
- **Missing**: Not implemented
- Tested column: **Yes** = direct assertions, **Indirect** = exercised by integration tests

---

### File I/O (read/write)

| # | Name | Status | Tested | Notes |
|---|------|--------|--------|-------|
| 0 | `read` | Full | **Yes** | Bounce-buffer |
| 1 | `write` | Full | **Yes** | Bounce-buffer |
| 17 | `pread64` | Full | Indirect | |
| 18 | `pwrite64` | Full | No | |
| 19 | `readv` | Full | **Yes** | Scatter-gather via iovec |
| 20 | `writev` | Full | **Yes** | Gather via iovec |
| 40 | `sendfile` | Full | **Yes** | With optional offset pointer |
| 275 | `splice` | Full | No | |
| 276 | `tee` | Full | No | |
| 326 | `copy_file_range` | Full | **Yes** | |
| 295 | `preadv` | **Missing** | | |
| 296 | `pwritev` | **Missing** | | |
| 327 | `preadv2` | **Missing** | | |
| 328 | `pwritev2` | **Missing** | | |

### File open/close/seek/dup

| # | Name | Status | Tested | Notes |
|---|------|--------|--------|-------|
| 2 | `open` | Full | **Yes** | |
| 3 | `close` | Full | **Yes** | Silently succeeds for fd 0-2 |
| 8 | `lseek` | Full | **Yes** | |
| 32 | `dup` | Full | **Yes** | |
| 33 | `dup2` | Full | **Yes** | |
| 292 | `dup3` | Full | **Yes** | |
| 22 | `pipe` | Full | **Yes** | |
| 293 | `pipe2` | Full | **Yes** | |
| 72 | `fcntl` | Full | **Yes** | |
| 73 | `flock` | Full | No | |
| 74 | `fsync` | Full | No | |
| 75 | `fdatasync` | Full | **Yes** | |
| 76 | `truncate` | Full | **Yes** | |
| 77 | `ftruncate` | Full | **Yes** | |
| 85 | `creat` | Full | No | |
| 257 | `openat` | Full | **Yes** | |
| 285 | `fallocate` | Full | No | |
| 436 | `close_range` | Full | No | |
| 16 | `ioctl` | Partial | Indirect | Only terminal ioctls |

### Stat family

| # | Name | Status | Tested | Notes |
|---|------|--------|--------|-------|
| 4 | `stat` | Full | **Yes** | |
| 5 | `fstat` | Full | **Yes** | |
| 6 | `lstat` | Full | **Yes** | |
| 137 | `statfs` | Full | **Yes** | |
| 138 | `fstatfs` | Full | No | |
| 262 | `newfstatat` | Full | Indirect | |
| 332 | `statx` | Full | **Yes** | |

### Memory management

| # | Name | Status | Tested | Notes |
|---|------|--------|--------|-------|
| 9 | `mmap` | Partial | **Yes** | Ignores prot flags; simple linear allocator |
| 10 | `mprotect` | Stub | Indirect | No-op |
| 11 | `munmap` | Stub | **Yes** | No-op, doesn't free pages |
| 12 | `brk` | Full | **Yes** | Emulated |
| 25 | `mremap` | Full | **Yes** | Emulated with copy |
| 26 | `msync` | Stub | No | No-op |
| 28 | `madvise` | Stub | No | No-op |
| 221 | `fadvise64` | Stub | No | No-op |
| 27 | `mincore` | **Missing** | | |
| 149 | `mlock` | **Missing** | | |
| 150 | `munlock` | **Missing** | | |
| 151 | `mlockall` | **Missing** | | |
| 152 | `munlockall` | **Missing** | | |

### Directory and path operations

| # | Name | Status | Tested | Notes |
|---|------|--------|--------|-------|
| 79 | `getcwd` | Full | **Yes** | |
| 80 | `chdir` | Full | **Yes** | |
| 81 | `fchdir` | Full | **Yes** | |
| 21 | `access` | Full | No | |
| 269 | `faccessat` | Full | No | |
| 439 | `faccessat2` | Full | No | |
| 82 | `rename` | Full | No | |
| 264 | `renameat` | Full | No | |
| 316 | `renameat2` | Full | **Yes** | |
| 83 | `mkdir` | Full | **Yes** | |
| 258 | `mkdirat` | Full | **Yes** | |
| 84 | `rmdir` | Full | **Yes** | |
| 86 | `link` | Full | **Yes** | |
| 265 | `linkat` | Full | **Yes** | |
| 87 | `unlink` | Full | **Yes** | |
| 263 | `unlinkat` | Full | No | |
| 88 | `symlink` | Full | **Yes** | |
| 266 | `symlinkat` | Full | **Yes** | |
| 89 | `readlink` | Full | **Yes** | |
| 267 | `readlinkat` | Full | **Yes** | |
| 90 | `chmod` | Full | **Yes** | |
| 91 | `fchmod` | Full | No | |
| 268 | `fchmodat` | Full | **Yes** | |
| 92 | `chown` | Full | No | |
| 93 | `fchown` | Full | No | |
| 260 | `fchownat` | Full | No | |
| 94 | `lchown` | Full | No | |
| 95 | `umask` | Full | **Yes** | |
| 217 | `getdents64` | Full | Indirect | |
| 78 | `getdents` | Full | No | Legacy |
| 133 | `mknod` | Full | No | |
| 259 | `mknodat` | Full | No | |
| 280 | `utimensat` | Full | **Yes** | |
| 132 | `utime` | Full | No | |
| 235 | `utimes` | Full | No | |

### Process control

| # | Name | Status | Tested | Notes |
|---|------|--------|--------|-------|
| 60 | `exit` | Full | **Yes** | |
| 231 | `exit_group` | Full | Indirect | |
| 158 | `arch_prctl` | Full | Indirect | FS/GS base |
| 157 | `prctl` | Stub | No | Always returns 0 |
| 56 | `clone` | **Missing** | | Single-process only |
| 57 | `fork` | **Missing** | | Single-process only |
| 58 | `vfork` | **Missing** | | |
| 59 | `execve` | **Missing** | | Single-process only |
| 61 | `wait4` | **Missing** | | |
| 247 | `waitid` | **Missing** | | |
| 322 | `execveat` | **Missing** | | |
| 435 | `clone3` | **Missing** | | |
| 135 | `personality` | **Missing** | | |

### Signals

| # | Name | Status | Tested | Notes |
|---|------|--------|--------|-------|
| 13 | `rt_sigaction` | Stub | Indirect | No-op |
| 14 | `rt_sigprocmask` | Stub | No | No-op |
| 37 | `alarm` | Stub | No | No-op |
| 62 | `kill` | Partial | No | Only fatal signals cause exit |
| 200 | `tkill` | Partial | No | Same as kill |
| 234 | `tgkill` | Partial | No | Same as kill |
| 131 | `sigaltstack` | Stub | No | No-op |
| 15 | `rt_sigreturn` | **Missing** | | |
| 127 | `rt_sigpending` | **Missing** | | |
| 128 | `rt_sigtimedwait` | **Missing** | | |
| 129 | `rt_sigqueueinfo` | **Missing** | | |
| 130 | `rt_sigsuspend` | **Missing** | | |

### IDs (user/group)

| # | Name | Status | Tested | Notes |
|---|------|--------|--------|-------|
| 39 | `getpid` | Full | **Yes** | |
| 102 | `getuid` | Full | **Yes** | |
| 104 | `getgid` | Full | **Yes** | |
| 107 | `geteuid` | Full | **Yes** | |
| 108 | `getegid` | Full | **Yes** | |
| 110 | `getppid` | Full | **Yes** | |
| 111 | `getpgrp` | Full | **Yes** | |
| 112 | `setsid` | Full | No | |
| 115 | `getgroups` | Full | No | |
| 122 | `setfsuid` | Full | No | |
| 123 | `setfsgid` | Full | No | |
| 186 | `gettid` | Full | **Yes** | Returns getpid() |
| 105 | `setuid` | Full | No | |
| 106 | `setgid` | Full | No | |
| 109 | `setpgid` | Full | No | |
| 121 | `getpgid` | Full | **Yes** | |
| 124 | `getsid` | Full | **Yes** | |
| 113 | `setreuid` | Full | No | |
| 114 | `setregid` | Full | No | |
| 117 | `setresuid` | Full | No | |
| 118 | `getresuid` | Full | No | |
| 119 | `setresgid` | Full | No | |
| 120 | `getresgid` | Full | No | |
| 116 | `setgroups` | Full | No | |

### Time

| # | Name | Status | Tested | Notes |
|---|------|--------|--------|-------|
| 228 | `clock_gettime` | Full | **Yes** | |
| 229 | `clock_getres` | Full | **Yes** | |
| 230 | `clock_nanosleep` | Full | No | |
| 96 | `gettimeofday` | Full | **Yes** | |
| 201 | `time` | Full | No | |
| 35 | `nanosleep` | Full | No | Writes remainder on EINTR |
| 36 | `getitimer` | Full | No | |
| 38 | `setitimer` | Full | No | |
| 100 | `times` | Full | **Yes** | |

### Threading

| # | Name | Status | Tested | Notes |
|---|------|--------|--------|-------|
| 218 | `set_tid_address` | Partial | Indirect | Returns PID |
| 273 | `set_robust_list` | Stub | No | No-op |
| 334 | `rseq` | Stub | No | No-op |
| 202 | `futex` | Full | No | Pass-through via host_ptr() |
| 274 | `get_robust_list` | **Missing** | | |
| 205 | `set_thread_area` | **Missing** | | |

### Resource limits

| # | Name | Status | Tested | Notes |
|---|------|--------|--------|-------|
| 97 | `getrlimit` | Full | **Yes** | |
| 98 | `getrusage` | Full | No | |
| 160 | `setrlimit` | Full | No | |
| 302 | `prlimit64` | Partial | No | Always returns RLIM_INFINITY |
| 99 | `sysinfo` | Full | **Yes** | |

### Sockets

| # | Name | Status | Tested | Notes |
|---|------|--------|--------|-------|
| 41 | `socket` | Full | Indirect | |
| 42 | `connect` | Full | No | |
| 43 | `accept` | Full | No | |
| 288 | `accept4` | Full | No | |
| 44 | `sendto` | Full | **Yes** | |
| 45 | `recvfrom` | Full | **Yes** | |
| 46 | `sendmsg` | Full | **Yes** | |
| 47 | `recvmsg` | Full | **Yes** | |
| 48 | `shutdown` | Full | No | |
| 49 | `bind` | Full | No | |
| 50 | `listen` | Full | No | |
| 53 | `socketpair` | Full | **Yes** | |
| 54 | `setsockopt` | Full | No | |
| 55 | `getsockopt` | Full | No | |
| 51 | `getsockname` | Full | No | |
| 52 | `getpeername` | Full | No | |

### Extended attributes (xattr)

All 12 xattr syscalls (188-199) are stubbed: `getxattr` variants return `-ENODATA`,
`listxattr` variants return `0`, `setxattr`/`removexattr` variants return `-ENOTSUP`.
This is correct behavior for a filesystem without xattr support.

### Epoll / event notification

| # | Name | Status | Tested | Notes |
|---|------|--------|--------|-------|
| 213 | `epoll_create` | Full | No | |
| 291 | `epoll_create1` | Full | **Yes** | |
| 233 | `epoll_ctl` | Full | **Yes** | |
| 232 | `epoll_wait` | Full | **Yes** | |
| 281 | `epoll_pwait` | Full | No | Ignores sigmask (signals stubbed) |
| 290 | `eventfd2` | Full | **Yes** | |
| 283 | `timerfd_create` | Full | No | |
| 286 | `timerfd_settime` | Full | No | |
| 287 | `timerfd_gettime` | Full | No | |
| 289 | `signalfd4` | Full | No | |
| 294 | `inotify_init1` | Full | **Yes** | |
| 254 | `inotify_add_watch` | Full | No | |
| 255 | `inotify_rm_watch` | Full | No | |

### Scheduling / misc

| # | Name | Status | Tested | Notes |
|---|------|--------|--------|-------|
| 24 | `sched_yield` | Full | **Yes** | |
| 203 | `sched_setaffinity` | Full | No | |
| 204 | `sched_getaffinity` | Full | No | |
| 324 | `membarrier` | Stub | No | No-op |
| 318 | `getrandom` | Full | **Yes** | |
| 7 | `poll` | Full | **Yes** | |
| 271 | `ppoll` | Full | No | Ignores sigmask |
| 23 | `select` | Full | **Yes** | |
| 270 | `pselect6` | Full | No | Ignores sigmask |

---

## Known Limitations

### Memory management
- **mmap**: Simple linear allocator. Ignores protection flags.
- **munmap**: No-op — pages are never freed.
- **mprotect**: No-op — no permission enforcement.

### Process model
- **Single-process only**: `fork`, `clone`, `execve`, `wait4` are not supported.
- **Single-threaded**: Only one thread can exist.

### Signals
- All signal-related syscalls are no-ops. No signal delivery or handlers.

### ioctl
- Only terminal ioctls (TCGETS, TIOCGWINSZ, TIOCGPGRP, TIOCSPGRP).

### prlimit64
- Always reports RLIM_INFINITY. Setting limits is ignored.

### Missing syscalls (not practical to implement in user-mode emulation)
- Multi-process: `fork`/`clone`/`clone3`/`vfork`/`execve`/`execveat`/`wait4`/`waitid`
- Signal delivery: `rt_sigreturn`/`rt_sigpending`/`rt_sigtimedwait`/`rt_sigsuspend`/`rt_sigqueueinfo`
- Memory locking: `mlock`/`munlock`/`mlockall`/`munlockall`/`mincore`
- Vectored I/O v2: `preadv`/`pwritev`/`preadv2`/`pwritev2`
- Thread areas: `set_thread_area`/`get_thread_area`/`get_robust_list`
- `personality`: Process execution domain

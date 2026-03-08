#pragma once

#include "integers.h"
#include <cerrno>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <sys/mman.h>

// Identity-mapped guest memory: guest addresses are valid host pointers.
// These are thin helpers over mmap/memcpy/memset.

static constexpr u64 PAGE_MASK = ~(u64)4095;

// Map pages at a specific guest address (fails if already mapped).
inline void guest_map_fixed(u64 addr, size_t len) {
  if (len == 0) return;
  u64 start = addr & PAGE_MASK;
  u64 end = (addr + len + 4095) & PAGE_MASK;
  size_t size = end - start;
  void *p = mmap((void *)start, size, PROT_READ | PROT_WRITE,
                 MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED_NOREPLACE, -1, 0);
  if (p == MAP_FAILED) {
    fprintf(stderr, "guest_map_fixed failed at 0x%lx len 0x%zx: %s\n",
            start, size, strerror(errno));
    abort();
  }
}

// Map pages at a kernel-chosen address. Returns the guest (== host) address.
inline u64 guest_map_anywhere(size_t len) {
  if (len == 0) return (u64)-EINVAL;
  size_t size = (len + 4095) & PAGE_MASK;
  void *p = mmap(nullptr, size, PROT_READ | PROT_WRITE,
                 MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (p == MAP_FAILED)
    return (u64)-(i64)errno;
  return (u64)p;
}

// Reserve a large address range without backing it with swap.
// Pages become usable (RW) but only consume physical memory on first touch.
inline u64 guest_map_noreserve(size_t len) {
  size_t size = (len + 4095) & PAGE_MASK;
  void *p = mmap(nullptr, size, PROT_READ | PROT_WRITE,
                 MAP_PRIVATE | MAP_ANONYMOUS | MAP_NORESERVE, -1, 0);
  if (p == MAP_FAILED)
    return (u64)-(i64)errno;
  return (u64)p;
}

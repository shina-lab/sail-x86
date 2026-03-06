#pragma once

#include "integers.h"
#include <cstddef>
#include <unordered_map>
#include <cstring>
#include <sys/mman.h>

class EmulatorMemory {
public:
  static constexpr size_t PAGE_SIZE = 4096;
  static constexpr size_t PAGE_SHIFT = 12;
  static constexpr u64 PAGE_MASK = ~(u64)(PAGE_SIZE - 1);

  ~EmulatorMemory() {
    for (auto &[addr, page] : pages_)
      munmap(page, PAGE_SIZE);
  }

  u8 *get_page(u64 addr) {
    u64 page_addr = addr & PAGE_MASK;
    auto it = pages_.find(page_addr);
    if (it != pages_.end())
      return it->second;
    return alloc_page(page_addr);
  }

  u8 *host_ptr(u64 guest_addr) {
    u8 *page = get_page(guest_addr);
    return page + (guest_addr & (PAGE_SIZE - 1));
  }

  void read(u64 addr, void *buf, size_t len) {
    u8 *dst = (u8 *)buf;
    while (len > 0) {
      size_t offset = addr & (PAGE_SIZE - 1);
      size_t chunk = std::min(PAGE_SIZE - offset, len);
      memcpy(dst, get_page(addr) + offset, chunk);
      dst += chunk;
      addr += chunk;
      len -= chunk;
    }
  }

  void write(u64 addr, const void *buf, size_t len) {
    const u8 *src = (const u8 *)buf;
    while (len > 0) {
      size_t offset = addr & (PAGE_SIZE - 1);
      size_t chunk = std::min(PAGE_SIZE - offset, len);
      memcpy(get_page(addr) + offset, src, chunk);
      src += chunk;
      addr += chunk;
      len -= chunk;
    }
  }

  void map_range(u64 start, size_t len) {
    u64 page_start = start & PAGE_MASK;
    u64 page_end = (start + len + PAGE_SIZE - 1) & PAGE_MASK;
    for (u64 a = page_start; a < page_end; a += PAGE_SIZE)
      get_page(a);
  }

  void zero_range(u64 start, size_t len) {
    while (len > 0) {
      size_t offset = start & (PAGE_SIZE - 1);
      size_t chunk = std::min(PAGE_SIZE - offset, len);
      memset(get_page(start) + offset, 0, chunk);
      start += chunk;
      len -= chunk;
    }
  }

  u64 brk_base = 0;
  u64 brk_current = 0;

private:
  u8 *alloc_page(u64 page_addr) {
    void *p = mmap(nullptr, PAGE_SIZE, PROT_READ | PROT_WRITE,
                   MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (p == MAP_FAILED) {
      fprintf(stderr, "mmap failed for page at 0x%lx\n", page_addr);
      abort();
    }
    u8 *page = (u8 *)p;
    pages_[page_addr] = page;
    return page;
  }

  std::unordered_map<u64, u8 *> pages_;
};

#include "x86_platform_base.h"
#include <algorithm>
#include <sys/mman.h>
#include <cstdlib>

PhysicalMemory::~PhysicalMemory() {
  if (ram)
    munmap(ram, size);
}

bool PhysicalMemory::init(u64 sz) {
  size = sz;
  ram = static_cast<u8 *>(
      mmap(nullptr, sz, PROT_READ | PROT_WRITE,
           MAP_PRIVATE | MAP_ANONYMOUS | MAP_NORESERVE, -1, 0));
  return ram != MAP_FAILED;
}

u8 PhysicalMemory::read8(u64 paddr) const {
  if (paddr < size)
    return ram[paddr];
  return 0xFF;
}

u16 PhysicalMemory::read16(u64 paddr) const {
  if (paddr + 1 < size) {
    u16 val;
    memcpy(&val, ram + paddr, 2);
    return val;
  }
  return 0xFFFF;
}

u32 PhysicalMemory::read32(u64 paddr) const {
  if (paddr + 3 < size) {
    u32 val;
    memcpy(&val, ram + paddr, 4);
    return val;
  }
  return 0xFFFFFFFF;
}

u64 PhysicalMemory::read64(u64 paddr) const {
  if (paddr + 7 < size) {
    u64 val;
    memcpy(&val, ram + paddr, 8);
    return val;
  }
  return 0xFFFFFFFFFFFFFFFF;
}

void PhysicalMemory::write8(u64 paddr, u8 val) {
  if (paddr < size)
    ram[paddr] = val;
}

void PhysicalMemory::write16(u64 paddr, u16 val) {
  if (paddr + 1 < size)
    memcpy(ram + paddr, &val, 2);
}

void PhysicalMemory::write32(u64 paddr, u32 val) {
  if (paddr + 3 < size)
    memcpy(ram + paddr, &val, 4);
}

void PhysicalMemory::write64(u64 paddr, u64 val) {
  if (paddr + 7 < size)
    memcpy(ram + paddr, &val, 8);
}

void PhysicalMemory::read_bytes(u64 paddr, void *buf, u64 len) const {
  u64 avail = (paddr < size) ? std::min(len, size - paddr) : 0;
  memcpy(buf, ram + paddr, avail);
  memset(static_cast<u8 *>(buf) + avail, 0xFF, len - avail);
}

void PhysicalMemory::write_bytes(u64 paddr, const void *buf, u64 len) {
  u64 avail = (paddr < size) ? std::min(len, size - paddr) : 0;
  memcpy(ram + paddr, buf, avail);
}

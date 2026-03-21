#include "x86-platform-base.h"
#include <algorithm>
#include <sys/mman.h>
#include <cstdlib>

PhysicalMemory::~PhysicalMemory() {
  if (ram)
    munmap(ram, size);
  free(rom_data);
}

bool PhysicalMemory::init(u64 sz) {
  size = sz;
  ram = static_cast<u8 *>(
      mmap(nullptr, sz, PROT_READ | PROT_WRITE,
           MAP_PRIVATE | MAP_ANONYMOUS | MAP_NORESERVE, -1, 0));
  return ram != MAP_FAILED;
}

void PhysicalMemory::load_rom(const u8 *data, size_t len) {
  free(rom_data);
  rom_data = static_cast<u8 *>(malloc(len));
  memcpy(rom_data, data, len);
  rom_size = len;

  // Copy ROM into the legacy area in RAM (shadow RAM).
  // This makes 0x100000-rom_size..0xFFFFF readable AND writable,
  // allowing SeaBIOS to shadow its runtime code there.
  u64 legacy_base = 0x100000 - len;
  if (legacy_base < size)
    memcpy(ram + legacy_base, data, std::min(len, (size_t)(size - legacy_base)));

  // For ROMs > 64KB: mirror the entire ROM to 0x100000.
  // SeaBIOS's .code16gcc code runs with CS=F000 (CS.base=0xF0000) and
  // uses unreal mode (CS.limit=4GB) to access code at offsets > 0xFFFF.
  // Offset = func - BUILD_BIOS_ADDR (e.g., 0xFA3C3 - 0xE0000 = 0x1A3C3).
  // Linear address = CS.base + offset = 0xF0000 + 0x1A3C3 = 0x10A3C3.
  // This needs to contain the same code as at flat address 0xFA3C3.
  // Since 0xFA3C3 is at ROM[0x1A3C3] and 0x10A3C3 = 0x100000 + 0xA3C3,
  // we need ram[0x100000 + X] = ROM[0x10000 + X] for X in [0, 0xFFFF].
  // In other words: copy the UPPER 64KB of ROM to 0x100000-0x10FFFF.
  if (len > 0x10000 && size > 0x110000) {
    memcpy(ram + 0x100000, data + 0x10000, 0x10000);
  }
}

// Check if paddr falls in the ROM high alias and return the byte.
// High alias: 0x100000000 - rom_size .. 0xFFFFFFFF (read-only).
// The legacy area (below 1MB) is copied into RAM by load_rom() and
// is writable (shadow RAM), so it's NOT handled here.
bool PhysicalMemory::rom_read(u64 paddr, u8 &out) const {
  if (!rom_data) return false;
  u64 high_base = 0x100000000ULL - rom_size;
  if (paddr >= high_base && paddr <= 0xFFFFFFFF) {
    out = rom_data[paddr - high_base];
    return true;
  }
  return false;
}

bool PhysicalMemory::in_rom(u64 paddr) const {
  if (!rom_data) return false;
  u64 high_base = 0x100000000ULL - rom_size;
  return paddr >= high_base && paddr <= 0xFFFFFFFF;
}

u8 PhysicalMemory::read8(u64 paddr) const {
  u8 rom_byte;
  if (rom_read(paddr, rom_byte)) return rom_byte;
  if (paddr < size)
    return ram[paddr];
  return 0xFF;
}

u16 PhysicalMemory::read16(u64 paddr) const {
  // For ROM regions, read byte-by-byte
  if (rom_data && in_rom(paddr))
    return read8(paddr) | ((u16)read8(paddr + 1) << 8);
  if (paddr + 1 < size) {
    u16 val;
    memcpy(&val, ram + paddr, 2);
    return val;
  }
  return 0xFFFF;
}

u32 PhysicalMemory::read32(u64 paddr) const {
  if (rom_data && in_rom(paddr))
    return read8(paddr) | ((u32)read8(paddr+1) << 8) |
           ((u32)read8(paddr+2) << 16) | ((u32)read8(paddr+3) << 24);
  if (paddr + 3 < size) {
    u32 val;
    memcpy(&val, ram + paddr, 4);
    return val;
  }
  return 0xFFFFFFFF;
}

u64 PhysicalMemory::read64(u64 paddr) const {
  if (rom_data && in_rom(paddr))
    return (u64)read32(paddr) | ((u64)read32(paddr + 4) << 32);
  if (paddr + 7 < size) {
    u64 val;
    memcpy(&val, ram + paddr, 8);
    return val;
  }
  return 0xFFFFFFFFFFFFFFFF;
}

void PhysicalMemory::write8(u64 paddr, u8 val) {
  if (in_rom(paddr)) return;  // Silently drop writes to ROM
  if (paddr < size) {
    // Watch stack writes at 0xEFFA0 (linear address with SS.base=0xE0000)
    if (paddr >= 0xEFFA0 && paddr <= 0xEFFA3) {
      static int w8s = 0;
      if (w8s++ < 20)
        fprintf(stderr, "[W8 %05lx] 0x%02x→0x%02x\n", paddr, ram[paddr], val);
    }
    ram[paddr] = val;
  }
}

void PhysicalMemory::write16(u64 paddr, u16 val) {
  if (in_rom(paddr)) return;
  if (paddr + 1 < size) {
    memcpy(ram + paddr, &val, 2);
  }
}

void PhysicalMemory::write32(u64 paddr, u32 val) {
  if (in_rom(paddr)) return;
  if (paddr + 3 < size) {
    // Watch stack writes at 0xEFFA0
    if (paddr >= 0xEFFA0 && paddr <= 0xEFFA3) {
      u32 old; memcpy(&old, ram+paddr, 4);
      if (old != val) {
        static int w = 0;
        if (w++ < 20)
          fprintf(stderr, "[W32 %04lx] 0x%08x→0x%08x\n", paddr, old, val);
      }
    }
    memcpy(ram + paddr, &val, 4);
  }
}

void PhysicalMemory::write64(u64 paddr, u64 val) {
  if (in_rom(paddr)) return;
  if (paddr + 7 < size)
    memcpy(ram + paddr, &val, 8);
}

void PhysicalMemory::read_bytes(u64 paddr, void *buf, u64 len) const {
  // If ROM is active, read byte-by-byte for regions that may overlap ROM
  if (rom_data) {
    u8 *dst = static_cast<u8 *>(buf);
    for (u64 i = 0; i < len; i++)
      dst[i] = read8(paddr + i);
    return;
  }
  u64 avail = (paddr < size) ? std::min(len, size - paddr) : 0;
  memcpy(buf, ram + paddr, avail);
  memset(static_cast<u8 *>(buf) + avail, 0xFF, len - avail);
}

void PhysicalMemory::write_bytes(u64 paddr, const void *buf, u64 len) {
  if (rom_data && in_rom(paddr)) return;
  u64 avail = (paddr < size) ? std::min(len, size - paddr) : 0;
  memcpy(ram + paddr, buf, avail);
}

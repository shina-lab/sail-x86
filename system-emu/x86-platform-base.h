#pragma once

#include "../emu-shared/integers.h"
#include "devices.h"
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

struct MXCSRState {
  u32 mxcsr = 0x1F80;
};

// Physical memory manager for system-level emulation.
// Flat array backing guest physical address space.
class PhysicalMemory {
public:
  static constexpr u64 DEFAULT_RAM_SIZE = 512ULL * 1024 * 1024; // 512 MB

  PhysicalMemory() = default;
  ~PhysicalMemory();

  PhysicalMemory(const PhysicalMemory &) = delete;
  PhysicalMemory &operator=(const PhysicalMemory &) = delete;

  bool init(u64 size = DEFAULT_RAM_SIZE);

  // Load a BIOS ROM image. Mapped at both the high alias
  // (0x100000000 - rom_size .. 0xFFFFFFFF) and the legacy area
  // (0x100000 - rom_size .. 0xFFFFF).
  void load_rom(const u8 *data, size_t len);

  u8 read8(u64 paddr) const;
  u16 read16(u64 paddr) const;
  u32 read32(u64 paddr) const;
  u64 read64(u64 paddr) const;

  void write8(u64 paddr, u8 val);
  void write16(u64 paddr, u16 val);
  void write32(u64 paddr, u32 val);
  void write64(u64 paddr, u64 val);

  // Bulk read/write for arbitrary sizes.
  void read_bytes(u64 paddr, void *buf, u64 len) const;
  void write_bytes(u64 paddr, const void *buf, u64 len);

  u8 *ram_ptr() { return ram; }
  const u8 *ram_ptr() const { return ram; }
  u64 ram_size() const { return size; }

  bool in_ram(u64 paddr) const { return paddr < size; }

  // ROM intercept: check if paddr falls in a ROM region, return byte if so.
  bool rom_read(u64 paddr, u8 &out) const;
  bool in_rom(u64 paddr) const;

private:
  u8 *ram = nullptr;
  u64 size = 0;
  u8 *rom_data = nullptr;
  u64 rom_size = 0;
};

class X86PlatformBase {
public:
  MXCSRState mxcsr_state;

  bool should_exit = false;
  int exit_code = 0;

  // Not used in system mode, but kept for API compatibility with user mode.
  u64 brk_base = 0;
  u64 brk_current = 0;
  u64 brk_limit = 0;

  PhysicalMemory phys_mem;

  // Devices
  UART uart;
  PIC pic_master{0x20, true};
  PIC pic_slave{0xA0, false};
  PIT pit;
  KeyboardController kbd;
  CMOS cmos;
  VGAText vga;
  ATAController ata;
  PCIConfigSpace pci;

  // Simulated TSC: incremented each instruction step.
  // Used instead of host RDTSC so timer calibration matches PIT timing.
  u64 tsc = 0;

  // Pending external interrupt (checked by Sail model)
  bool pending_irq = false;
  u8 pending_irq_vector = 0;

  // Software TLB: 1024-entry direct-mapped, indexed by VPN[9:0].
  // Each entry caches a 4KB page translation.
  static constexpr int TLB_SIZE = 1024;
  struct TLBEntry {
    u64 vpn;       // Virtual page number (addr >> 12)
    u64 ppn;       // Physical page number (paddr >> 12)
    bool valid;
    bool writable; // Can satisfy write accesses
  };
  TLBEntry tlb[TLB_SIZE] = {};
};

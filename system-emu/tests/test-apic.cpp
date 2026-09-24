#include "x86-platform-base.h"
#include <cassert>
#include <cstdio>

static constexpr u64 LAPIC = 0xFEE00000, IOAPIC_BASE = 0xFEC00000;
static void route(X86PlatformBase &p, unsigned pin, u32 lo, u32 hi = 0) {
  p.phys_mem.write32(IOAPIC_BASE, 0x11 + 2 * pin);
  p.phys_mem.write32(IOAPIC_BASE + 0x10, hi);
  p.phys_mem.write32(IOAPIC_BASE, 0x10 + 2 * pin);
  p.phys_mem.write32(IOAPIC_BASE + 0x10, lo);
}

int main() {
  X86PlatformBase p;
  assert(p.phys_mem.init(0x100000));
  auto &m = p.phys_mem;
  auto &a = p.lapic;
  assert(m.read32(LAPIC + 0x30) == 0x50014);
  assert(m.read32(LAPIC + 0xF0) == 0xFF);
  assert(m.read32(LAPIC + 0x350) == 0x10000);
  m.write32(LAPIC + 0xF0, 0x1FF);

  // Self IPI, task priority, ISR priority, nested interrupts and EOI.
  u32 ipi = 0x40051;
  m.write_bytes(LAPIC + 0x300, &ipi, 4);
  assert(a.pending() == 0x51);
  m.write32(LAPIC + 0x80, 0x5F);
  assert(a.pending() == -1);
  m.write32(LAPIC + 0x80, 0);
  assert(a.acknowledge() == 0x51);
  assert(m.read32(LAPIC + 0x120) == (1u << 17));
  a.request(0x52);
  assert(a.pending() == -1); // same priority class as the ISR
  a.request(0x61);
  assert(a.acknowledge() == 0x61);
  m.write32(LAPIC + 0xB0, 0);
  assert(a.pending() == -1);
  m.write32(LAPIC + 0xB0, 0);
  assert(a.acknowledge() == 0x52);
  m.write32(LAPIC + 0xB0, 0);

  // One-shot at divide-by-1, then periodic at divide-by-16.
  m.write32(LAPIC + 0x3E0, 0xB);
  m.write32(LAPIC + 0x320, 0x40);
  m.write32(LAPIC + 0x380, 100);
  p.tsc = 999;
  assert(m.read32(LAPIC + 0x390) == 1);
  assert(a.pending() == -1);
  p.tsc = 1000;
  assert(a.acknowledge() == 0x40);
  m.write32(LAPIC + 0xB0, 0);
  p.tsc = 100000;
  assert(a.pending() == -1);
  m.write32(LAPIC + 0x3E0, 3);
  m.write32(LAPIC + 0x320, 0x20041);
  m.write32(LAPIC + 0x380, 10);
  p.tsc += 3 * 1600 + 160;
  assert(m.read32(LAPIC + 0x390) == 9);
  assert(a.acknowledge() == 0x41);
  m.write32(LAPIC + 0xB0, 0);
  m.write32(LAPIC + 0x380, 0);

  // Masked edges are dropped; one rising edge produces just one interrupt.
  route(p, 14, 0x1002E);
  p.pulse_irq(14);
  assert(a.pending() == -1);
  route(p, 14, 0x2E);
  p.set_irq(14, true);
  assert(a.acknowledge() == 0x2E);
  m.write32(LAPIC + 0xB0, 0);
  p.set_irq(14, true);
  assert(a.pending() == -1);
  p.set_irq(14, false);

  // An asserted, masked level is delivered on unmask. Remote IRR prevents
  // duplicates until EOI, which redelivers only while the line remains high.
  route(p, 14, 0x1802E);
  p.set_irq(14, true);
  route(p, 14, 0x802E);
  assert(a.acknowledge() == 0x2E);
  assert(m.read32(IOAPIC_BASE + 0x10) & 0x4000);
  assert(m.read32(LAPIC + 0x190) & (1u << 14));
  assert(a.pending() == -1);
  m.write32(LAPIC + 0xB0, 0);
  assert(a.acknowledge() == 0x2E);
  p.set_irq(14, false);
  m.write32(LAPIC + 0xB0, 0);
  assert(a.pending() == -1);
  assert(!(m.read32(IOAPIC_BASE + 0x10) & 0x4000));

  // Physical destination filtering and flat logical destination delivery.
  route(p, 4, 0x34, 0x01000000);
  p.pulse_irq(4);
  assert(a.pending() == -1);
  m.write32(LAPIC + 0xD0, 0x02000000);
  route(p, 4, 0x834, 0x02000000);
  p.pulse_irq(4);
  assert(a.acknowledge() == 0x34);
  m.write32(LAPIC + 0xB0, 0);

  // Consuming a queued PS/2 byte lowers IRQ1 so the next byte has an edge.
  route(p, 1, 0x31);
  p.kbd.push_scancode(0x1E);
  p.kbd.push_scancode(0x9E);
  p.set_irq(1, true);
  assert(a.acknowledge() == 0x31);
  assert(p.read_keyboard(0x60) == 0x1E);
  m.write32(LAPIC + 0xB0, 0);
  p.set_irq(1, true);
  assert(a.acknowledge() == 0x31);
  assert(p.read_keyboard(0x60) == 0x9E);
  m.write32(LAPIC + 0xB0, 0);

  m.write32(LAPIC + 0xF0, 0xFF);
  m.write32(LAPIC + 0x320, 0x42);
  assert(m.read32(LAPIC + 0x320) & 0x10000);
  a.base_msr = 0xFEE00100;
  assert(m.read32(LAPIC + 0x30) == 0xFFFFFFFF);
  a.base_msr = 0xFED00900;
  assert(m.read32(0xFED00030) == 0x50014);
  puts("APIC MMIO, priority, IPI, timers, edge/level routing: PASS");
}

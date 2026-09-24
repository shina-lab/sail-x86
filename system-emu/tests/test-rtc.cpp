#include "x86-platform-base.h"
#include <cassert>
#include <cstdio>

int main() {
  X86PlatformBase p;
  auto &c = p.cmos;
  auto read = [&](u8 r) { c.write(0x70, r); return c.read(0x71); };
  auto write = [&](u8 r, u8 v) { c.write(0x70, r); c.write(0x71, v); };
  write(0xB, 0x42); // 24h, periodic IRQ enabled, 1024 Hz
  p.tsc = 976562;
  assert(!c.has_irq());
  p.tsc = 976563;
  assert(c.has_irq());
  assert(read(0xC) == 0xC0 && !c.has_irq());
  assert(read(0xC) == 0);
  write(0xB, 2); // PF continues latching while PIE is disabled
  p.tsc = 2000000;
  assert(!c.has_irq() && read(0xC) == 0x40);
  write(0xA, 0x2F); // 2 Hz
  write(0xB, 0x42);
  p.tsc = 499999999;
  assert(!c.has_irq());
  p.tsc = 500000000;
  p.interrupt_pending();
  assert(c.has_irq() && (p.pic_slave.get_irr() & 1));
  read(0xC); p.set_irq(8, c.has_irq());

  // Route the next RTC edge through IOAPIC INTIN8.
  p.lapic.write(0xF0, 0x1FF);
  p.ioapic.write(0, 0x20); p.ioapic.write(0x10, 0x28);
  p.tsc = 1000000000;
  assert(p.interrupt_pending() && p.lapic.acknowledge() == 0x28);
  assert(read(0) == 1);
  assert(read(0xC) == 0xD0); // PF + UF + IRQF
  p.set_irq(8, c.has_irq()); p.lapic.write(0xB0, 0);

  // SET freezes calendar updates; register C and D are read-only.
  write(0xB, 0x82); write(0, 0x59); write(2, 0x59); write(4, 0x23);
  write(7, 0x28); write(8, 2); write(9, 0x24);
  p.tsc = 2000000000; assert(read(0) == 0x59);
  write(0xB, 0x32); // update-ended and alarm interrupts
  write(1, 0xC0); write(3, 0xC0); write(5, 0xC0);
  p.tsc = 2999800000; assert(read(0xA) & 0x80);
  p.tsc = 3000000000;
  assert(read(0) == 0 && read(2) == 0 && read(4) == 0 && read(7) == 0x29);
  assert((read(0xC) & 0xB0) == 0xB0 && !c.has_irq());
  write(0xC, 0xFF); write(0xD, 0);
  assert(read(0xC) == 0 && read(0xD) == 0x80);
  puts("RTC rates, flags, PIC/IOAPIC routing, SET, UIP and leap day: PASS");
}

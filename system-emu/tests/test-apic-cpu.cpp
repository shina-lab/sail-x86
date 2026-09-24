#include "sail_x86_model.h"
#include "x86-helpers.h"
#include <cassert>
#include <cstdio>

int main() {
  x86::Model m;
  m.model_init();
  m.zinitializze_registers(UNIT);
  x86::enable_all_features(m);
  assert(m.phys_mem.init(0x100000));
  m.zsystem_mode = false; // explicit IRQ acknowledgements, no guest IDT
  m.z__port_out8(0xB2, 0xF1);
  assert(!m.smi_pending && (m.pm.control & 1));
  m.z__port_out32(0xCF8, 0x80000B58);
  m.z__port_out32(0xCFC, 1u << 25);
  m.z__port_out8(0xB2, 0xB5);
  assert(!m.smi_pending);
  m.z__port_out8(0xB028, 1);
  m.z__port_out8(0xB2, 0xB5);
  assert(m.smi_pending && m.z__port_in8(0xB2) == 0xB5);
  m.smi_pending = false;
  m.zcur_mode = x86::zProtectedMode;
  m.zcur_cpl = 0;
  m.zCR0 = 0x11;
  m.zSegCache.data[x86::SEG_CS].zseg_db = 1;
  for (int i = 0; i < 6; ++i) {
    m.zSegCache.data[i].zseg_base = 0;
    m.zSegCache.data[i].zseg_limit = 0xFFFFFFFF;
  }
  // Port polling must not invent PIT time independently of TSC/LAPIC time.
  // Linux calibrates its LAPIC against PIT channel 2 through this port.
  m.z__port_out8(0x43, 0xB0);
  m.z__port_out8(0x42, 0x34);
  m.z__port_out8(0x42, 0x12);
  for (int i = 0; i < 100; ++i) m.z__port_in8(0x61);
  m.z__port_out8(0x43, 0x80);
  u16 count = m.z__port_in8(0x42);
  count |= m.z__port_in8(0x42) << 8;
  assert(count == 0x1234);
  m.z__port_out8(0x20, 0x11);
  m.z__port_out8(0x21, 0x20);
  m.z__port_out8(0x21, 4);
  m.z__port_out8(0x21, 1);
  m.z__port_out8(0x21, 0xFE);
  m.pulse_irq(0);
  sail_int irq;
  CREATE(sail_int)(&irq);
  m.z__check_pending_irq(&irq, UNIT);
  assert(mpz_get_si(irq) == 0x20);
  m.z__port_out8(0x20, 0x20);

  // Execute ordinary guest stores and a load through Sail's memory externs.
  const u8 code[] = {
    0xB8,0,0,0xE0,0xFE,                              // mov eax,FEE00000
    0xC7,0x80,0xF0,0,0,0,0xFF,1,0,0,                // mov [eax+F0],1FF
    0xC7,0x80,0,3,0,0,0x51,0,4,0,                   // mov [eax+300],40051
    0x8B,0x88,0x20,2,0,0,                            // mov ecx,[eax+220]
    0xF4
  };
  m.phys_mem.write_bytes(0x1000, code, sizeof(code));
  m.zRIP = 0x1000;
  for (int i = 0; i < 5; ++i) {
    m.zstep(UNIT);
    assert(!m.zfault_pending);
  }
  assert(m.zGPR.data[1] == (1u << 17));
  m.pulse_irq(0); // PIC pending is disconnected when APIC's LINT0 is masked
  m.z__check_pending_irq(&irq, UNIT);
  assert(mpz_get_si(irq) == 0x51);
  m.phys_mem.write32(0xFEE000B0, 0);
  m.z__check_pending_irq(&irq, UNIT);
  assert(mpz_get_si(irq) == -1);
  m.phys_mem.write32(0xFEE00350, 0x700); // virtual wire ExtINT
  m.z__check_pending_irq(&irq, UNIT);
  assert(mpz_get_si(irq) == 0x20);
  assert(m.z__rdmsr(0x1B) == 0xFEE00900);
  m.z__wrmsr(0x1B, 0xFED00900);
  assert(m.z__rdmsr(0x1B) == 0xFED00900);
  assert(m.phys_mem.read32(0xFED00030) == 0x50014);
  m.z__wrmsr(0x1B, 0xFED00100);
  assert(m.phys_mem.read32(0xFED00030) == 0xFFFFFFFF);
  KILL(sail_int)(&irq);
  m.model_fini();
  puts("Sail APIC MMIO, MSRs and PIC/APIC interrupt dispatch: PASS");
}

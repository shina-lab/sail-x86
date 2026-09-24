#include "devices.h"
#include "pm.h"
#include <cassert>
#include <cstdio>

int main() {
  PCIConfigSpace pci;
  pci.write_addr(0x80000800); assert(pci.read_data() == 0x70008086);
  pci.write_addr(0x8000080C); assert(pci.read_data() & 0x00800000); // multifunction
  pci.write_addr(0x80000900); assert(pci.read_data() == 0x70108086);
  pci.write_addr(0x80000B00); assert(pci.read_data() == 0x71138086);
  pci.write_addr(0x80000940); assert(pci.read_data() == 0x80008000);
  ACPIPM pm;
  assert(pm.timer(1000000000) == 3579545);
  assert(pm.timer(10000000000) == (35795450 & 0xFFFFFF));
  pm.write(4, 1);
  assert(pm.read(4, 0) == 1); // SCI_EN survives the BIOS SMI handler
  pm.write(5, 0x20);
  assert(pm.write(4, 1)); // S5 power-off
  pm.apm_write(0xF0); assert(!(pm.control & 1));
  pm.apm_write(0xF1); assert(pm.control & 1);
  pm.apm_write(0xB5); assert(pm.apmc == 0xB5); // SeaBIOS CALL32 SMM command
  FwCfg fw;
  fw.write(0x510, 5);
  assert(fw.read(0x511) == 1 && fw.read(0x511) == 0);
  u8 rom[512] = {0x55, 0xAA};
  fw.set_vga_rom(rom, sizeof(rom));
  fw.write(0x510, 0x19);
  u8 dir[132];
  for (auto &v : dir) v = fw.read(0x511);
  assert(dir[3] == 2);
  assert(!strcmp((char *)dir + 12, "etc/irq0-override"));
  assert(!strcmp((char *)dir + 76, "vgaroms/vgabios.bin"));
  assert(dir[9] == 0x22 && dir[73] == 0x21);
  fw.write(0x510, 0x22);
  assert(fw.read(0x511) == 1);
  fw.write(0x510, 0x21);
  assert(fw.read(0x511) == 0x55 && fw.read(0x511) == 0xAA);
  puts("fw_cfg CPU count, IRQ0 override and VGA directory: PASS");
}

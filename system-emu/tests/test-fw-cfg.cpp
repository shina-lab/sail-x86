#include "devices.h"
#include <cassert>
#include <cstdio>

int main() {
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

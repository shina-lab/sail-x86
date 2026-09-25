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
  // SeaBIOS ACPI COM1._STA reads CAEN, while COM2._STA reads CBEN.
  // Reflect the one UART actually present so an OS can attach its tty.
  pci.write_addr(0x80000B64);
  assert((pci.read_data() & 0x88000000) == 0x08000000);
  pci.write_addr(0x80000940); assert(pci.read_data() == 0x80008000);
  {
    PCIConfigSpace pci;
    // Exercise the original relocation/decode cases with the QEMU-style BAR.
    pci.write_addr(0x80000920); assert(pci.read_data() == 1);
    assert(!pci.ide_busmaster_handles(0));
    pci.write_data(0xFFFFFFFF); assert(pci.read_data() == 0xFFFFFFF1);
    pci.write_data(0x1234C12F); assert(pci.read_data() == 0x1234C121);
    assert(!pci.ide_busmaster_handles(0xC120));
    pci.write_data(0xC12F);
    assert(pci.ide_busmaster_base() == 0xC120);
    pci.write_addr(0x80000904); pci.write_data(1); // Enable I/O decoding.
    assert(pci.ide_busmaster_handles(0xC120));
    assert(pci.ide_busmaster_handles(0xC12F));
    assert(!pci.ide_busmaster_handles(0xC130));
    pci.write_addr(0x80000904); pci.write_data(4); // I/O decode disabled
    assert(!pci.ide_busmaster_handles(0xC120));
    pci.write_data(5);
    pci.write_addr(0x80000920); pci.write_data(0xD001);
    assert(!pci.ide_busmaster_handles(0xC120));
    assert(pci.ide_busmaster_handles(0xD00F));
  }
  {
    PCIConfigSpace pci;
    // PIIX3 BAR4 must exist even for PIO devices: FreeBSD resets its DMA
    // registers during channel probing. Probe, align, relocate and gate I/O.
    pci.write_addr(0x80000920); assert(pci.read_data() == 1);
    assert(!pci.ide_busmaster_handles(0));
    pci.write_data(0xFFFFFFFF); assert(pci.read_data() == 0xFFFFFFF1);
    assert(~(pci.read_data() & ~3u) + 1 == 16); // firmware BAR sizing
    pci.write_data(0x1234C123); assert(pci.read_data() == 0x1234C121);
    pci.write_addr(0x80000904); pci.write_data(5);
    assert(!pci.ide_busmaster_handles(0xC120)); // no truncation to 16 bits
    pci.write_data(0);
    pci.write_addr(0x80000920); pci.write_data(0xC123);
    assert(pci.ide_busmaster_base() == 0xC120);
    assert(!pci.ide_busmaster_handles(0xC120));
    pci.write_addr(0x80000904); pci.write_data(5);
    assert(pci.ide_busmaster_handles(0xC120) && pci.ide_busmaster_handles(0xC12F));
    assert(!pci.ide_busmaster_handles(0xC11F) && !pci.ide_busmaster_handles(0xC130));
    pci.write_addr(0x80000920); pci.write_data(0xD001);
    assert(!pci.ide_busmaster_handles(0xC120) && pci.ide_busmaster_handles(0xD000));
    pci.write_addr(0x80000904); pci.write_data(4);
    assert(!pci.ide_busmaster_handles(0xD000));
  }
  // PIIX4 PM has no standard BARs or option ROM.
  for (unsigned reg = 0x10; reg <= 0x30; reg += 4) {
    pci.write_addr(0x80000B00 | reg);
    pci.write_data(0xFFFFFFFF);
    assert(pci.read_data() == 0);
  }
  pci.vga_rom_size = 39424;
  pci.write_addr(0x80001030);
  pci.write_data(0xFFFFF800); assert(pci.read_data() == 0xFFFF0000);
  pci.write_data(0xFFFFFFFF); assert(pci.read_data() == 0xFFFF0001);
  pci.write_data(0xFEBF8001);
  assert(pci.read_data() == 0xFEBF0001 && pci.vga_rom_bar_addr == 0xFEBF0000);
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

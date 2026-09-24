#include "x86-platform-base.h"
#include <cassert>
#include <cstdio>

int main(int argc, char **argv) {
  X86PlatformBase p;
  assert(p.phys_mem.init(0x100000));
  auto &v = p.vbe;
  auto reg = [&](u16 i, u16 x) { v.write(0x1CE, i); v.write(0x1CF, x); };
  auto get = [&](u16 i) { v.write(0x1CE, i); return v.read(0x1CF); };
  assert(get(0) == 0xB0C5);
  reg(0, 0xB0C4); assert(get(0) == 0xB0C4);
  reg(0, 0x1234); assert(get(0) == 0xB0C4);
  reg(4, 2); assert(get(1) == 2560 && get(2) == 1600 && get(3) == 32);
  assert(get(10) == 256);
  reg(4, 0); reg(1, 2); reg(2, 2); reg(3, 32); reg(4, 0x41);
  assert(get(6) == 2 && get(7) == 65535);
  auto &m = p.phys_mem;
  m.write32(0xE0000000, 0x00FF0000);
  m.write32(0xE0000004, 0x0000FF00);
  m.write32(0xE0000008, 0x000000FF);
  m.write32(0xE000000C, 0x00FFFFFF);
  auto pixels = v.rgb(p.vga.dac_palette, 255);
  assert((pixels == std::vector<u8>{255,0,0,0,255,0,0,0,255,255,255,255}));
  if (argc > 1) assert(write_png(argv[1], 2, 2, pixels));
  // Banked memory and LFB are two views of the same storage.
  reg(5, 3); m.write32(0xA0000, 0x12345678);
  assert(m.read32(0xE0030000) == 0x12345678);
  // Virtual pitch and display start.
  reg(6, 4); reg(8, 1); reg(9, 1);
  m.write32(0xE0000014, 0x00345678);
  pixels = v.rgb(p.vga.dac_palette, 255);
  assert(pixels[0] == 0x34 && pixels[1] == 0x56 && pixels[2] == 0x78);
  reg(4, 0); reg(4, 0xC1);
  assert(m.read32(0xE0000014) == 0x00345678); // NOCLEARMEM
  reg(4, 0); reg(4, 0x41);
  assert(m.read32(0xE0000014) == 0);
  // PCI BAR sizing and relocation, including memory decode disable.
  p.pci.write_addr(0x80001010); p.pci.write_data(0xFFFFFFFF);
  assert(p.pci.read_data() == 0xFF000008);
  p.pci.write_data(0xD0000000); p.sync_vga_bars();
  m.write32(0xD0000000, 0x12345678);
  u32 word;
  m.read_bytes(0xD0000000, &word, 4);
  assert(word == 0x12345678);
  assert(m.read32(0xE0000000) == 0xFFFFFFFF);
  p.pci.write_addr(0x80001004); p.pci.write_data(1); p.sync_vga_bars();
  assert(m.read32(0xD0000000) == 0xFFFFFFFF);
  p.pci.write_data(3); p.sync_vga_bars();
  // RGB565 and indexed palette conversion.
  reg(4, 0); reg(3, 16); reg(4, 0x41);
  m.write16(0xD0000000, 0x07E0);
  pixels = v.rgb(p.vga.dac_palette, 255);
  assert(pixels[0] == 0 && pixels[1] == 255 && pixels[2] == 0);
  reg(4, 0); reg(3, 8); reg(4, 0x41);
  p.vga.dac_palette[7][0] = 63;
  m.write8(0xD0000000, 7);
  pixels = v.rgb(p.vga.dac_palette, 255);
  assert(pixels[0] == 255 && pixels[1] == 0);
  puts("Bochs DISPI, LFB/banking, PCI BAR, pitch and pixel formats: PASS");
}

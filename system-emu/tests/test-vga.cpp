#include "x86-platform-base.h"
#include <cassert>
#include <cstdio>

int main() {
  X86PlatformBase p;
  assert(p.phys_mem.init(0x100000));
  auto &v = p.vga;
  auto seq = [&](u8 i, u8 x) { v.write(0x3C4, i); v.write(0x3C5, x); };
  auto gc = [&](u8 i, u8 x) { v.write(0x3CE, i); v.write(0x3CF, x); };
  auto crtc = [&](u8 i, u8 x) { v.write(0x3D4, i); v.write(0x3D5, x); };
  auto &m = p.phys_mem;
  seq(4, 6); gc(6, 5); gc(8, 255);
  const u8 pattern[4] = {0xAA, 0xCC, 0xF0, 0xFF};
  for (unsigned plane = 0; plane < 4; ++plane) {
    seq(2, 1 << plane); m.write8(0xA0000, pattern[plane]);
  }
  for (unsigned plane = 0; plane < 4; ++plane) {
    gc(4, plane); assert(m.read8(0xA0000) == pattern[plane]);
  }
  // Mode 1 is a latch-to-memory copy independent of host write data.
  seq(2, 15); gc(5, 1); m.write8(0xA0010, 0);
  for (unsigned plane = 0; plane < 4; ++plane) {
    gc(4, plane); assert(m.read8(0xA0010) == pattern[plane]);
  }
  // Color compare (read mode 1) finds bit positions of color 9.
  gc(5, 8); gc(2, 9); gc(7, 15);
  assert(m.read8(0xA0000) == 2);
  gc(7, 0); assert(m.read8(0xA0000) == 255);
  // Mode 2 expands each low-nibble bit into a plane; preserve masked bits.
  gc(5, 2); gc(8, 0xF0); m.write8(0xA0020, 5);
  const u8 expanded[4] = {0xFA, 0x0C, 0xF0, 0x0F};
  gc(5, 0);
  for (unsigned plane = 0; plane < 4; ++plane) {
    gc(4, plane); assert(m.read8(0xA0020) == expanded[plane]);
  }
  // Rotate and XOR, and mode-0 set/reset substitution.
  gc(4, 0); m.read8(0xA0000); gc(3, 0x19); gc(8, 255); seq(2, 1);
  m.write8(0xA0030, 2); assert(m.read8(0xA0030) == 0xAB);
  gc(3, 0); gc(0, 1); gc(1, 1); m.write8(0xA0040, 0);
  assert(m.read8(0xA0040) == 255);
  // Mode 3 uses rotated host data as a mask and set/reset as the color.
  m.read8(0xA0000); gc(5, 3); gc(0, 0); gc(8, 0xF0);
  m.write8(0xA0050, 0xF0); gc(5, 0);
  assert(m.read8(0xA0050) == 0x0A);
  // Mode 12h geometry and attribute/DAC palette lookup.
  seq(2, 15); gc(0, 1); gc(1, 15); gc(8, 255);
  m.write8(0xA0000, 0);
  crtc(1, 79); crtc(7, 0x3E); crtc(9, 0); crtc(0x12, 0xDF); crtc(0x13, 40);
  v.read(0x3DA); v.write(0x3C0, 0x12); v.write(0x3C0, 15);
  v.write(0x3C0, 1); v.write(0x3C0, 7);
  v.write(0x3C8, 7); v.write(0x3C9, 63); v.write(0x3C9, 0); v.write(0x3C9, 0);
  assert(v.pixel_width() == 640 && v.pixel_height() == 480);
  auto rgb = v.graphics_rgb();
  assert(rgb[0] == 255 && rgb[1] == 0 && rgb[2] == 0);
  // Mode 13h chain-4 maps consecutive CPU bytes across the four planes.
  seq(4, 0xE); seq(2, 15); gc(1, 0); gc(5, 0x40);
  crtc(7, 0x1F); crtc(9, 0x41); crtc(0x12, 0x8F);
  m.write32(0xA0000, 0x0A090807);
  assert(m.read32(0xA0000) == 0x0A090807);
  assert(v.pixel_width() == 320 && v.pixel_height() == 200);
  rgb = v.graphics_rgb();
  assert(rgb[0] == 255 && rgb[3] == 0);
  // The chipset's open SMRAM window and SMM cycles bypass VGA decoding.
  p.pci.write_addr(0x80000070); p.pci.write_data(0x004A0000); p.sync_vga_bars();
  m.write32(0xA0000, 0xDEADBEEF);
  assert(m.read32(0xA0000) == 0xDEADBEEF);
  std::vector<u8> bios(0x20000, 0xFF);
  m.load_rom(bios.data(), bios.size());
  u8 rom[16] = {0x55, 0xAA};
  m.load_vga_rom(rom, sizeof(rom), 0xFEB00000);
  assert(m.read8(0xC0000) == 0x55);
  m.write32(0xC0008, 0x12345678); // SeaVGABIOS writable global variable
  u32 global;
  m.read_bytes(0xC0008, &global, 4);
  assert(global == 0x12345678);
  assert(m.read32(0xFEB00008) == 0);
  p.pci.write_data(0x000A0000); p.sync_vga_bars();
  assert(m.read32(0xA0000) == 0x0A090807);
  m.smram_active = true;
  assert(m.read32(0xA0000) == 0xDEADBEEF);
  puts("VGA planes, latches, read/write modes, chain-4, DAC, mode 12h/13h: PASS");
}

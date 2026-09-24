#pragma once
#include "integers.h"
#include <algorithm>
#include <cstdio>
#include <vector>

// Minimal RGB PNG writer: zlib with uncompressed DEFLATE blocks. Keeping it
// dependency-free also makes signal-requested captures available headlessly.
inline bool write_png(const char *path, unsigned width, unsigned height,
                      const std::vector<u8> &rgb) {
  if (!width || !height || rgb.size() != size_t(width) * height * 3) return false;
  std::vector<u8> png{137,80,78,71,13,10,26,10};
  auto be32 = [](std::vector<u8> &v, u32 n) {
    for (int shift = 24; shift >= 0; shift -= 8) v.push_back(n >> shift);
  };
  auto chunk = [&](const char *type, const std::vector<u8> &data) {
    be32(png, data.size());
    size_t start = png.size();
    png.insert(png.end(), type, type + 4);
    png.insert(png.end(), data.begin(), data.end());
    u32 crc = 0xFFFFFFFF;
    for (size_t i = start; i < png.size(); ++i) {
      crc ^= png[i];
      for (int j = 0; j < 8; ++j) crc = (crc >> 1) ^ (0xEDB88320u & (0u - (crc & 1)));
    }
    be32(png, ~crc);
  };
  std::vector<u8> header;
  be32(header, width); be32(header, height);
  header.insert(header.end(), {8, 2, 0, 0, 0});
  chunk("IHDR", header);
  std::vector<u8> raw;
  raw.reserve(rgb.size() + height);
  for (unsigned y = 0; y < height; ++y) {
    raw.push_back(0); // PNG filter: none
    raw.insert(raw.end(), rgb.begin() + size_t(y) * width * 3,
               rgb.begin() + size_t(y + 1) * width * 3);
  }
  std::vector<u8> deflate{0x78, 0x01};
  for (size_t i = 0; i < raw.size();) {
    unsigned n = std::min<size_t>(65535, raw.size() - i);
    deflate.insert(deflate.end(), {u8(i + n == raw.size()), u8(n), u8(n >> 8), u8(~n), u8(~n >> 8)});
    deflate.insert(deflate.end(), raw.begin() + i, raw.begin() + i + n);
    i += n;
  }
  u32 a = 1, b = 0;
  for (u8 value : raw) { a = (a + value) % 65521; b = (b + a) % 65521; }
  be32(deflate, (b << 16) | a);
  chunk("IDAT", deflate);
  chunk("IEND", {});
  FILE *f = fopen(path, "wb");
  if (!f) return false;
  bool ok = fwrite(png.data(), 1, png.size(), f) == png.size();
  return fclose(f) == 0 && ok;
}

class BochsVBE {
public:
  static constexpr unsigned VRAM_SIZE = 16 * 1024 * 1024;
  u32 lfb_base = 0xE0000000;
  bool memory_enabled = true;
  std::vector<u8> vram = std::vector<u8>(VRAM_SIZE);

  bool enabled() const { return regs[4] & 1; }
  bool dac8() const { return regs[4] & 0x20; }
  bool handles(u16 port) const { return port == 0x1CE || port == 0x1CF; }
  u16 read(u16 port) const {
    if (port == 0x1CE) return index;
    if (index >= 11) return 0;
    if (regs[4] & 2) {
      if (index == 1) return 2560;
      if (index == 2) return 1600;
      if (index == 3) return 32;
    }
    if (index == 7) return stride() ? std::min<unsigned>(65535, VRAM_SIZE / stride()) : 0;
    if (index == 10) return VRAM_SIZE / 65536;
    return regs[index];
  }
  void write(u16 port, u16 value) {
    if (port == 0x1CE) { index = value; return; }
    switch (index) {
    case 0: if (value >= 0xB0C0 && value <= 0xB0C5) regs[0] = value; break;
    case 1: if (!enabled() && value <= 2560) regs[1] = value; break;
    case 2: if (!enabled() && value <= 1600) regs[2] = value; break;
    case 3:
      if (!enabled() && (value == 8 || value == 15 || value == 16 || value == 24 || value == 32)) regs[3] = value;
      break;
    case 4:
      if ((value & 1) && !enabled()) {
        if (!regs[1] || !regs[2] || !regs[3]) return;
        regs[6] = regs[1]; regs[8] = regs[9] = 0;
        if (!(value & 0x80)) std::fill(vram.begin(), vram.end(), 0);
      }
      regs[4] = value & 0xE3;
      break;
    case 5: regs[5] = value & (VRAM_SIZE / 65536 - 1); break;
    case 6:
      if (value >= regs[1] && value && u64(value) * bytes_per_pixel() * regs[2] <= VRAM_SIZE) regs[6] = value;
      break;
    case 8: if (u32(value) + regs[1] <= regs[6]) regs[8] = value; break;
    case 9: if (u64(value + regs[2]) * stride() <= VRAM_SIZE) regs[9] = value; break;
    default: break;
    }
  }
  unsigned width() const { return regs[1]; }
  unsigned height() const { return regs[2]; }
  unsigned depth() const { return regs[3]; }
  bool maps(u64 addr) const {
    return memory_enabled && ((addr >= lfb_base && addr - lfb_base < VRAM_SIZE) ||
           (enabled() && addr >= 0xA0000 && addr < 0xB0000));
  }
  u8 read_mem(u64 addr) const { return vram[offset(addr)]; }
  void write_mem(u64 addr, u8 value) { vram[offset(addr)] = value; }
  std::vector<u8> rgb(const u8 palette[256][3], u8 dac_mask) const {
    if (!enabled()) return {};
    std::vector<u8> image(size_t(width()) * height() * 3);
    for (unsigned y = 0; y < height(); ++y) for (unsigned x = 0; x < width(); ++x) {
      u64 off = u64(y + regs[9]) * stride() + u64(x + regs[8]) * bytes_per_pixel();
      if (off + bytes_per_pixel() > VRAM_SIZE) continue;
      u8 *dst = &image[(size_t(y) * width() + x) * 3];
      if (depth() == 8) {
        for (unsigned c = 0; c < 3; ++c) {
          u8 v = palette[vram[off] & dac_mask][c];
          dst[c] = dac8() ? v : (v & 63) * 255 / 63;
        }
      } else if (depth() == 15 || depth() == 16) {
        u16 v = vram[off] | (u16(vram[off + 1]) << 8);
        unsigned green_bits = depth() == 16 ? 6 : 5;
        dst[0] = ((v >> (5 + green_bits)) & 31) * 255 / 31;
        dst[1] = ((v >> 5) & ((1 << green_bits) - 1)) * 255 / ((1 << green_bits) - 1);
        dst[2] = (v & 31) * 255 / 31;
      } else {
        dst[0] = vram[off + 2]; dst[1] = vram[off + 1]; dst[2] = vram[off];
      }
    }
    return image;
  }
private:
  u16 index = 0;
  u16 regs[11] = {0xB0C5};
  unsigned bytes_per_pixel() const { return (depth() + 7) / 8; }
  unsigned stride() const { return regs[6] * bytes_per_pixel(); }
  unsigned offset(u64 addr) const {
    return addr >= 0xA0000 && addr < 0xB0000 ? regs[5] * 65536 + addr - 0xA0000 : addr - lfb_base;
  }
};

// Floppy media replacement through the same controller used by the guest.
#include "devices.h"
#include <array>
#include <cassert>
#include <cstdio>
#include <string>
#include <vector>

struct FloppyImage {
  std::string path;
  explicit FloppyImage(u8 value) {
    char name[] = "./sail-floppy-XXXXXX";
    int fd = mkstemp(name);
    assert(fd >= 0);
    path = name;
    std::vector<u8> data(1474560, value);
    assert(write(fd, data.data(), data.size()) == (ssize_t)data.size());
    close(fd);
  }
  ~FloppyImage() { unlink(path.c_str()); }
};

struct FloppyMemory {
  std::array<u8, 65536> data{};
  u8 read8(u32 addr) { return data.at(addr); }
  void write8(u32 addr, u8 value) { data.at(addr) = value; }
};

static void seek(FloppyController &fdc, u8 cylinder) {
  for (u8 byte : {u8(0x0F), u8(0), cylinder}) fdc.write(0x3F5, byte);
  fdc.write(0x3F5, 0x08); // SENSE INTERRUPT
  assert(fdc.read(0x3F5) == 0x20);
  assert(fdc.read(0x3F5) == cylinder);
}

static void check_first_sector(FloppyController &fdc, u8 value) {
  DMAController dma;
  dma.ch[2].current_count = 511;
  dma.ch[2].masked = false;
  FloppyMemory memory;
  const u8 read[] = {0x46, 0, 0, 0, 1, 2, 18, 0x1B, 0xFF};
  for (u8 byte : read) fdc.write(0x3F5, byte);
  assert(fdc.do_dma_transfer(dma, memory));
  for (unsigned i = 0; i < 512; ++i) assert(memory.data[i] == value);
  for (unsigned i = 0; i < 7; ++i) fdc.read(0x3F5);
}

static void test_version_and_invalid_commands() {
  FloppyController fdc;
  // Intel 82077AA section 5.2.8: VERSION has no parameters and returns
  // 90h without an interrupt. It must not absorb the next command.
  fdc.write(0x3F5, 0x10);
  assert(fdc.read(0x3F4) == 0xD0);
  assert(!fdc.irq_pending);
  assert(fdc.read(0x3F5) == 0x90);
  assert(fdc.read(0x3F4) == 0x80);
  for (u8 byte : {0x03, 0xDF, 0x02}) fdc.write(0x3F5, byte);
  assert(fdc.read(0x3F4) == 0x80);
  seek(fdc, 7);

  // Table 5-1: an invalid opcode immediately returns ST0=80h. Consume
  // the result, then ensure a valid multi-byte command is still framed.
  fdc.write(0x3F5, 0x00);
  assert(fdc.read(0x3F4) == 0xD0);
  assert(!fdc.irq_pending);
  assert(fdc.read(0x3F5) == 0x80);
  assert(fdc.read(0x3F4) == 0x80);
  seek(fdc, 3);
  puts("Floppy VERSION and invalid-command framing: PASS");
}

int main() {
  test_version_and_invalid_commands();
  FloppyImage first(0x37), second(0xA9);
  FloppyController fdc;
  assert(fdc.open(first.path.c_str()));
  assert(fdc.read(0x3F7) & 0x80);
  seek(fdc, 1);
  assert(!(fdc.read(0x3F7) & 0x80));
  check_first_sector(fdc, 0x37);

  assert(fdc.open(second.path.c_str()));
  assert(fdc.read(0x3F7) & 0x80);
  seek(fdc, 2);
  assert(!(fdc.read(0x3F7) & 0x80));
  check_first_sector(fdc, 0xA9);

  // A failed swap leaves both the old medium and its change state intact.
  assert(!fdc.open((second.path + "/missing").c_str()));
  assert(!(fdc.read(0x3F7) & 0x80));
  check_first_sector(fdc, 0xA9);
  puts("Floppy media replacement: PASS");
}

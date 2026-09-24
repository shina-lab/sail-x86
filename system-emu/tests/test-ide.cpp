// Tests for the IDE channel device model: an ATA hard disk and an ATAPI
// CD-ROM driven through their I/O ports the way SeaBIOS and an OS's PIO
// driver do, without a CPU.

#include "devices.h"
#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

static int tests_passed = 0;
static int tests_failed = 0;

#define TEST(name) \
  static void test_##name(); \
  static void run_test_##name() { \
    printf("  %-50s", #name); \
    fflush(stdout); \
    test_##name(); \
    printf("PASS\n"); \
    tests_passed++; \
  } \
  static void test_##name()

#define ASSERT_EQ(a, b) do { \
  auto _a = (a); auto _b = (b); \
  if (_a != _b) { \
    printf("FAIL\n    %s:%d: %s == 0x%lx, expected 0x%lx\n", \
           __FILE__, __LINE__, #a, (unsigned long)_a, (unsigned long)_b); \
    tests_failed++; \
    return; \
  } \
} while(0)

// A temporary image whose byte at offset i is a function of i, so that any
// sector read can be checked.
struct Image {
  std::string path;
  Image(size_t size) {
    char tmpl[] = "/tmp/sail-ide-XXXXXX";
    int fd = mkstemp(tmpl);
    assert(fd >= 0);
    path = tmpl;
    std::vector<u8> data(size);
    for (size_t i = 0; i < size; i++) data[i] = pattern(i);
    assert(write(fd, data.data(), size) == (ssize_t)size);
    close(fd);
  }
  ~Image() { unlink(path.c_str()); }
  static u8 pattern(size_t i) { return (u8)(i * 7 + (i >> 11)); }
};

static const u16 BASE = 0x170, CTRL = 0x376;

// Poll through the alternate status register, which does not clear the
// interrupt; the tests check irq_pending explicitly.
static u8 status(IDEChannel &c) { return c.read(CTRL); }

// Read one DRQ block of `words` words from the data port.
static std::vector<u8> read_block(IDEChannel &c, size_t words) {
  std::vector<u8> out;
  for (size_t i = 0; i < words; i++) {
    u16 v = c.read16();
    out.push_back(v & 0xFF);
    out.push_back(v >> 8);
  }
  return out;
}

// Issue a PACKET command with the given byte-count limit and 12-byte CDB.
static void send_packet(IDEChannel &c, u16 limit, const u8 cdb[12]) {
  c.write(BASE + 6, 0xA0);         // master
  c.write(BASE + 1, 0x00);         // features: PIO
  c.write(BASE + 4, limit & 0xFF);
  c.write(BASE + 5, limit >> 8);
  c.write(BASE + 7, 0xA0);         // PACKET
  ASSERT_EQ(status(c) & 0x89, 0x08);  // DRQ, not BSY, no ERR
  ASSERT_EQ(c.read(BASE + 2) & 0x03, 0x01);  // interrupt reason: C/D
  for (int i = 0; i < 12; i += 2) c.write16(cdb[i] | (cdb[i + 1] << 8));
}

TEST(atapi_signature_and_identify) {
  Image iso(2048 * 100);
  IDEChannel c(BASE, CTRL);
  assert(c.open_cdrom(iso.path.c_str()));

  // Signature after reset: 01 01 14 EB
  c.write(CTRL, 0x0E);  // SRST | nIEN
  c.write(CTRL, 0x0A);
  ASSERT_EQ(c.read(BASE + 2), 0x01);
  ASSERT_EQ(c.read(BASE + 3), 0x01);
  ASSERT_EQ(c.read(BASE + 4), 0x14);
  ASSERT_EQ(c.read(BASE + 5), 0xEB);
  ASSERT_EQ(c.read(BASE + 1), 0x01);  // diagnostics passed

  // The slave reads as zero, so a probe skips it
  c.write(BASE + 6, 0xB0);
  ASSERT_EQ(c.read(BASE + 6), 0x00);
  ASSERT_EQ(status(c), 0x00);
  c.write(BASE + 6, 0xA0);

  // IDENTIFY DEVICE is refused; IDENTIFY PACKET DEVICE answers 512 bytes
  c.write(BASE + 7, 0xEC);
  ASSERT_EQ(status(c) & 0x01, 0x01);
  ASSERT_EQ(c.read(BASE + 1) & 0x04, 0x04);  // ABRT
  c.write(BASE + 7, 0xA1);
  ASSERT_EQ(status(c) & 0x89, 0x08);
  std::vector<u8> id = read_block(c, 256);
  u16 word0 = id[0] | (id[1] << 8);
  ASSERT_EQ(word0 >> 14, 2);             // ATAPI device
  ASSERT_EQ((word0 >> 8) & 0x1F, 0x05);  // CD-ROM
  ASSERT_EQ((word0 >> 7) & 1, 1);        // removable
  ASSERT_EQ(word0 & 0x03, 0);            // 12-byte packets
  ASSERT_EQ(status(c) & 0x89, 0x00);     // transfer complete
  ASSERT_EQ(c.irq_pending, false);       // nIEN set: no interrupt

  // With interrupts enabled the command interrupts, and reading the status
  // register (not the alternate status) clears it
  c.write(CTRL, 0x08);
  c.write(BASE + 7, 0xA1);
  ASSERT_EQ(c.irq_pending, true);
  ASSERT_EQ(c.read(CTRL) & 0x89, 0x08);
  ASSERT_EQ(c.irq_pending, true);
  ASSERT_EQ(c.read(BASE + 7) & 0x89, 0x08);
  ASSERT_EQ(c.irq_pending, false);
  read_block(c, 256);
}

TEST(atapi_inquiry_capacity_and_read) {
  Image iso(2048 * 100);
  IDEChannel c(BASE, CTRL);
  assert(c.open_cdrom(iso.path.c_str()));
  c.write(CTRL, 0x08);  // interrupts enabled

  // INQUIRY: 36 bytes, CD-ROM, removable
  u8 inquiry[12] = { 0x12, 0, 0, 0, 36, 0 };
  send_packet(c, 2048, inquiry);
  ASSERT_EQ(status(c) & 0x89, 0x08);
  ASSERT_EQ(c.irq_pending, true);
  c.irq_pending = false;
  ASSERT_EQ(c.read(BASE + 2) & 0x03, 0x02);  // I/O: data for the host
  ASSERT_EQ(c.read(BASE + 4) | (c.read(BASE + 5) << 8), 36);
  std::vector<u8> inq = read_block(c, 18);
  ASSERT_EQ(inq[0], 0x05);
  ASSERT_EQ(inq[1], 0x80);
  ASSERT_EQ(status(c) & 0x89, 0x00);
  ASSERT_EQ(c.read(BASE + 2) & 0x03, 0x03);  // command complete
  ASSERT_EQ(c.irq_pending, true);            // completion interrupt
  c.irq_pending = false;

  // READ CAPACITY: last LBA 99, block size 2048
  u8 capacity[12] = { 0x25 };
  send_packet(c, 2048, capacity);
  std::vector<u8> cap = read_block(c, 4);
  ASSERT_EQ((cap[0] << 24) | (cap[1] << 16) | (cap[2] << 8) | cap[3], 99);
  ASSERT_EQ((cap[4] << 24) | (cap[5] << 16) | (cap[6] << 8) | cap[7], 2048);

  // READ(10) of 3 sectors at LBA 5 with a 2048-byte limit: three DRQ
  // blocks, an interrupt each, then the completion interrupt.
  u8 read10[12] = { 0x28, 0, 0, 0, 0, 5, 0, 0, 3, 0 };
  c.irq_pending = false;
  send_packet(c, 2048, read10);
  for (int blk = 0; blk < 3; blk++) {
    ASSERT_EQ(status(c) & 0x89, 0x08);
    ASSERT_EQ(c.irq_pending, true);
    c.irq_pending = false;
    ASSERT_EQ(c.read(BASE + 4) | (c.read(BASE + 5) << 8), 2048);
    std::vector<u8> data = read_block(c, 1024);
    for (int i = 0; i < 2048; i++)
      ASSERT_EQ(data[i], Image::pattern((5 + blk) * 2048 + i));
  }
  ASSERT_EQ(status(c) & 0x89, 0x00);
  ASSERT_EQ(c.irq_pending, true);

  // The same read with an 8192-byte limit (libata) is one block of 6144
  c.irq_pending = false;
  send_packet(c, 8192, read10);
  ASSERT_EQ(c.read(BASE + 4) | (c.read(BASE + 5) << 8), 6144);
  std::vector<u8> data = read_block(c, 3072);
  ASSERT_EQ(data[6143], Image::pattern(8 * 2048 - 1));
  ASSERT_EQ(status(c) & 0x89, 0x00);

  // Reading past the end is a CHECK CONDITION with ILLEGAL REQUEST /
  // LBA OUT OF RANGE, reported by REQUEST SENSE
  u8 bad[12] = { 0x28, 0, 0, 0, 0, 99, 0, 0, 2, 0 };
  send_packet(c, 2048, bad);
  ASSERT_EQ(status(c) & 0x89, 0x01);  // ERR, no DRQ
  ASSERT_EQ(c.read(BASE + 1) >> 4, 0x05);
  u8 sense[12] = { 0x03, 0, 0, 0, 18, 0 };
  send_packet(c, 2048, sense);
  std::vector<u8> s = read_block(c, 9);
  ASSERT_EQ(s[0], 0x70);
  ASSERT_EQ(s[2], 0x05);
  ASSERT_EQ(s[12], 0x21);

  // TEST UNIT READY: no data, one completion interrupt
  u8 tur[12] = { 0x00 };
  c.irq_pending = false;
  send_packet(c, 2048, tur);
  ASSERT_EQ(status(c) & 0x89, 0x00);
  ASSERT_EQ(c.read(BASE + 2) & 0x03, 0x03);
  ASSERT_EQ(c.irq_pending, true);

  // READ TOC, format 0: one data track and the lead-out at LBA 100
  u8 toc[12] = { 0x43, 0, 0, 0, 0, 0, 0, 0, 20, 0 };
  send_packet(c, 2048, toc);
  std::vector<u8> t = read_block(c, 10);
  ASSERT_EQ((t[0] << 8) | t[1], 18);
  ASSERT_EQ(t[2], 1);
  ASSERT_EQ(t[3], 1);
  ASSERT_EQ(t[5], 0x14);
  ASSERT_EQ(t[6], 1);
  ASSERT_EQ(t[14], 0xAA);
  ASSERT_EQ((t[16] << 24) | (t[17] << 16) | (t[18] << 8) | t[19], 100);
}

TEST(ata_disk_read_write) {
  Image disk(512 * 64);
  IDEChannel c(0x1F0, 0x3F6);
  assert(c.open_disk(disk.path.c_str()));
  c.write(0x3F6, 0x0E);
  c.write(0x3F6, 0x08);
  auto st = [&]() { return c.read(0x3F6); };  // alternate status: no IRQ clear
  ASSERT_EQ(c.read(0x1F4), 0x00);  // ATA signature
  ASSERT_EQ(c.read(0x1F5), 0x00);

  // IDENTIFY DEVICE: fixed disk, 64 sectors
  c.write(0x1F6, 0xA0);
  c.write(0x1F7, 0xEC);
  ASSERT_EQ(st() & 0x89, 0x08);
  std::vector<u8> id = read_block(c, 256);
  ASSERT_EQ(id[0] | (id[1] << 8), 0x0040);
  ASSERT_EQ(id[120] | (id[121] << 8) | (id[122] << 16) | (id[123] << 24), 64);  // words 60-61
  ASSERT_EQ(st() & 0x89, 0x00);

  // READ SECTORS: 2 sectors at LBA 3, one interrupt per block, none at the end
  c.irq_pending = false;
  c.write(0x1F6, 0xE0);  // LBA mode
  c.write(0x1F2, 2);
  c.write(0x1F3, 3);
  c.write(0x1F4, 0);
  c.write(0x1F5, 0);
  c.write(0x1F7, 0x20);
  ASSERT_EQ(st() & 0x89, 0x08);
  ASSERT_EQ(c.irq_pending, true);
  c.irq_pending = false;
  std::vector<u8> s0 = read_block(c, 256);
  ASSERT_EQ(s0[100], Image::pattern(3 * 512 + 100));
  ASSERT_EQ(st() & 0x89, 0x08);
  ASSERT_EQ(c.irq_pending, true);
  c.irq_pending = false;
  std::vector<u8> s1 = read_block(c, 256);
  ASSERT_EQ(s1[511], Image::pattern(5 * 512 - 1));
  ASSERT_EQ(st() & 0x89, 0x00);
  ASSERT_EQ(c.irq_pending, false);

  // WRITE SECTORS: 1 sector at LBA 10, then read it back
  c.write(0x1F2, 1);
  c.write(0x1F3, 10);
  c.write(0x1F7, 0x30);
  ASSERT_EQ(st() & 0x89, 0x08);
  ASSERT_EQ(c.irq_pending, false);  // no interrupt before the first block
  for (int i = 0; i < 256; i++) c.write16(0xBEEF ^ i);
  ASSERT_EQ(st() & 0x89, 0x00);
  ASSERT_EQ(c.irq_pending, true);
  c.irq_pending = false;
  c.write(0x1F2, 1);
  c.write(0x1F3, 10);
  c.write(0x1F7, 0x20);
  std::vector<u8> back = read_block(c, 256);
  ASSERT_EQ(back[0] | (back[1] << 8), 0xBEEF);
  ASSERT_EQ(back[510] | (back[511] << 8), 0xBEEF ^ 255);

  // PACKET is refused on a disk
  c.write(0x1F7, 0xA0);
  ASSERT_EQ(st() & 0x01, 0x01);
}

int main() {
  printf("IDE channel tests:\n");
  run_test_atapi_signature_and_identify();
  run_test_atapi_inquiry_capacity_and_read();
  run_test_ata_disk_read_write();
  printf("\n  %d passed, %d failed\n", tests_passed, tests_failed);
  return tests_failed ? 1 : 0;
}

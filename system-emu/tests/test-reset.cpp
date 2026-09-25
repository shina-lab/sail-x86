// BIOS reset must fetch the high ROM vector without help from an old IVT.
#include "x86-reset.h"
#include <algorithm>
#include <array>
#include <cstdio>

int main() {
  x86::Model model;
  if (!model.phys_mem.init(4 * 1024 * 1024)) return 1;
  std::array<u8, 0x10000> rom{};
  // FFFFFFF0: JMP F000:0100; F0100: MOV AX,1234; HLT.
  const u8 entry[] = {0xea, 0x00, 0x01, 0x00, 0xf0};
  const u8 body[] = {0xb8, 0x34, 0x12, 0xf4};
  std::copy(std::begin(entry), std::end(entry), rom.begin() + 0xfff0);
  std::copy(std::begin(body), std::end(body), rom.begin() + 0x100);
  model.phys_mem.load_rom(rom.data(), rom.size());
  const u8 load[] = {0xa0, 0x10, 0x80}; // MOV AL,[8010h] with DS=FFFFh
  model.phys_mem.write_bytes(0xf0200, load, sizeof(load));
  model.phys_mem.write8(0x8000, 0xaa);
  model.phys_mem.write8(0x108000, 0xbb);

  // An installed OS owns the IVT. Any spurious exception must be visible,
  // instead of accidentally booting through the launcher's IRET stub.
  for (unsigned v = 0; v < 256; ++v) {
    model.phys_mem.write16(v * 4, 0x20);
    model.phys_mem.write16(v * 4 + 2, 0x1000);
  }
  for (bool old_a20 : {false, true, false, true}) {
    model.za20_enabled = old_a20;
    init_cpu_state_bios(model);
    model.zstep(UNIT);
    if (model.zfault_pending || model.zevent_delivered ||
        model.zSegReg.data[x86::SEG_CS] != 0xf000 || model.zRIP != 0x100 ||
        model.zSegCache.data[x86::SEG_CS].zseg_base != 0xf0000) {
      printf("FAIL: BIOS reset with prior A20=%u entered %04x:%lx instead of F000:0100\n",
             old_a20, (unsigned)model.zSegReg.data[x86::SEG_CS], (u64)model.zRIP);
      return 1;
    }
    model.zstep(UNIT);
    model.zstep(UNIT);
    if (model.zGPR.data[0] != 0x1234 || model.zsystem_state != x86::zSysHalted) {
      puts("FAIL: reset ROM did not complete");
      return 1;
    }
    // Firmware still controls A20 normally after reset entry.
    model.zload_segment_register(x86::SEG_DS, 0xffff);
    model.z__port_out8(0x92, 0);
    model.zsystem_state = x86::zSysRunning;
    model.zRIP = 0x200;
    model.zstep(UNIT);
    if ((model.zGPR.data[0] & 0xff) != 0xaa) {
      puts("FAIL: disabled A20 did not wrap the firmware data read");
      return 1;
    }
    model.z__port_out8(0x92, 2);
    model.zRIP = 0x200;
    model.zstep(UNIT);
    if ((model.zGPR.data[0] & 0xff) != 0xbb) {
      puts("FAIL: enabled A20 did not expose the high-memory data");
      return 1;
    }
  }
  model.model_fini();
  puts("BIOS reset: 4 reset-vector fetches and post-reset A20 control passed");
}

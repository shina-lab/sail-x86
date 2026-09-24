#include "kvm-harness.h"

// SDM Vol.3B, Architecture Compatibility, "Obsolete Instructions and
// Undefined Opcodes". These encodings are not in the Vol.2 opcode maps.
void add_x87_compat_tests(std::vector<TestCase> &tests) {
  // Load an explicit x87 state, execute the instruction, and save its
  // result. Compare all eight 80-bit registers, CW, SW and the full tag
  // word. Pointer fields and reserved bits of the FSAVE image are omitted.
  auto add_state = [&](const std::string &name, std::vector<u8> insn,
                       u16 cw, u16 sw, u16 tw, u16 undefined_cc, bool compat32) {
    std::vector<u8> data(0x100 + 108, 0);
    memcpy(&data[0x100], &cw, 2);
    memcpy(&data[0x104], &sw, 2);
    memcpy(&data[0x108], &tw, 2);
    const long double values[] = {3.0L, -1.5L, 0.0L, 7.0L,
                                  5.0L, -9.0L, 11.0L, 13.0L};
    for (unsigned i = 0; i < 8; i++)
      memcpy(&data[0x11C + i * 10], &values[i], 10);

    std::vector<u8> code = {
      0xDD, 0xA7, 0x00, 0x01, 0x00, 0x00,        // frstor [rdi+0x100]
    };
    code.insert(code.end(), insn.begin(), insn.end());
    const u8 save[] = {
      0xDD, 0xB7, 0x00, 0x01, 0x00, 0x00,        // fnsave [rdi+0x100]
      0x0F, 0xB7, 0x87, 0x00, 0x01, 0x00, 0x00,  // movzx eax, word [rdi+0x100]
      0x0F, 0xB7, 0x9F, 0x04, 0x01, 0x00, 0x00,  // movzx ebx, word [rdi+0x104]
      0x0F, 0xB7, 0x97, 0x08, 0x01, 0x00, 0x00,  // movzx edx, word [rdi+0x108]
      0x8D, 0xB7, 0x1C, 0x01, 0x00, 0x00,        // lea esi, [rdi+0x11c]
      0xB9, 0x50, 0x00, 0x00, 0x00,              // mov ecx, 80
      0xF3, 0xA4,                                // rep movsb
    };
    code.insert(code.end(), std::begin(save), std::end(save));
    if (undefined_cc) {
      u16 mask = ~undefined_cc;
      code.insert(code.end(), {0x81, 0xE3, (u8)mask, (u8)(mask >> 8), 0, 0});
    }

    TestCase tc;
    tc.name = std::format("{} ({}-bit, CW={:04x}, SW={:04x}, TW={:04x})",
                          name, compat32 ? 32 : 64, cw, sw, tw);
    tc.category = "x87 obsolete";
    tc.code = std::move(code);
    tc.initial.rdi = DATA_ADDR;
    tc.flags_mask = undefined_cc ? FL_NO_AF : FL_ALL;
    tc.init_data = std::move(data);
    tc.compare_data_len = 80;
    tc.compat_mode = compat32;
    tests.push_back(std::move(tc));
  };

  // Seed both clear and set condition codes and exception flags, a
  // non-default control word, and holes in the stack. These instructions
  // must neither initialize the FPU nor clear any part of its status.
  for (bool compat32 : {false, true}) {
    for (u16 sw : {0x0000, 0x7F05}) {
      for (u8 modrm : {0xE0, 0xE1, 0xE4}) {
        add_state(std::format("obsolete NOP DB {:02x}", modrm), {0xDB, modrm},
                  0x0B7F, sw, 0x3300, 0, compat32);
        // FWAIT is a separate instruction with undefined C0/C1/C2/C3.
        add_state(std::format("fwait; obsolete NOP DB {:02x}", modrm),
                  {0x9B, 0xDB, modrm}, 0x0B7F, sw, 0x3300, 0x4700, compat32);
      }
    }
  }

}

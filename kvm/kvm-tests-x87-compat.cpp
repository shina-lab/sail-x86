#include "kvm-harness.h"

// SDM Vol.3B, Architecture Compatibility, "Obsolete Instructions and
// Undefined Opcodes". These encodings are not in the Vol.2 opcode maps.
void add_x87_compat_tests(std::vector<TestCase> &tests) {
  std::string category = "x87 obsolete";
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
    tc.category = category;
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

  // Exercise all seven ordinary aliases and their canonical counterparts.
  // All eight registers contain distinct values (including zero and
  // negative numbers). Rotating TOP catches physical/logical-index errors;
  // starting C1 at one checks its architecturally defined clearing.
  category = "x87 aliases";
  struct { const char *name; u8 opcode, base; u16 undefined_cc; } aliases[] = {
    {"fcom alias",  0xDC, 0xD0, 0},
    {"fcomp alias", 0xDC, 0xD8, 0},
    {"fxch alias",  0xDD, 0xC8, 0x4500},
    {"fcomp alias", 0xDE, 0xD0, 0},
    {"fstp alias",  0xDF, 0xD0, 0x4500},
    {"fxch alias",  0xDF, 0xC8, 0x4500},
    {"fstp alias",  0xDF, 0xD8, 0x4500},
    {"fcom",        0xD8, 0xD0, 0},
    {"fcomp",       0xD8, 0xD8, 0},
    {"fxch",        0xD9, 0xC8, 0x4500},
    {"fstp",        0xDD, 0xD8, 0x4500},
  };
  for (bool compat32 : {false, true}) {
    for (unsigned top = 0; top < 8; top++) {
      for (unsigned i = 0; i < 8; i++) {
        for (auto &op : aliases) {
          u8 modrm = op.base + i;
          add_state(std::format("{} st({}) [{:02x} {:02x}]",
                                op.name, i, op.opcode, modrm),
                    {op.opcode, modrm}, 0x037F, (top << 11) | 0x4700,
                    0, op.undefined_cc, compat32);
        }
      }
    }
  }

  // The two forms with distinct behavior: D9 D8+i never raises stack
  // underflow, and DF C0+i (FFREEP) frees ST(i) before popping ST(0).
  // Check a full stack, an empty source, an empty destination and an
  // entirely empty stack, including with invalid-operation unmasked.
  category = "x87 compatibility stack";
  for (bool compat32 : {false, true}) {
    for (unsigned top : {0, 3, 7}) {
      for (unsigned i = 0; i < 8; i++) {
        u16 source_empty = 3 << (2 * top);
        u16 dest_empty = 3 << (2 * ((top + i) & 7));
        for (u16 tw : {u16(0), source_empty, dest_empty, u16(0xFFFF)}) {
          for (u16 cw : {0x037F, 0x037E}) {
            add_state(std::format("fstp without stack underflow st({})", i),
                      {0xD9, u8(0xD8 + i)}, cw, (top << 11) | 0x4700,
                      tw, 0x4500, compat32);
            add_state(std::format("ffreep st({})", i), {0xDF, u8(0xC0 + i)},
                      cw, (top << 11) | 0x4700, tw, 0x4700, compat32);
          }
        }
      }
    }
  }

  // Adjacent reserved cells are still invalid. In particular, DE D0+i is
  // FCOMP, but only DE D9 in the next group is FCOMPP.
  category = "x87 compatibility invalid";
  for (bool compat32 : {false, true}) {
    for (auto code : {std::vector<u8>{0xD9, 0xD1}, {0xDB, 0xE5},
                      {0xDB, 0xE7}, {0xDE, 0xD8}, {0xDE, 0xDA},
                      {0xDE, 0xDB}, {0xDE, 0xDC}, {0xDE, 0xDD},
                      {0xDE, 0xDE}, {0xDE, 0xDF}, {0xDF, 0xE1},
                      {0xDF, 0xF8}}) {
      TestCase tc;
      tc.name = std::format("reserved x87 {:02x} {:02x} ({}-bit)",
                            code[0], code[1], compat32 ? 32 : 64);
      tc.category = category;
      tc.code = std::move(code);
      tc.compat_mode = compat32;
      tc.expect_fault = true;
      tc.expected_vector = 6;
      tests.push_back(std::move(tc));
    }
  }
}

#include "devices.h"
#include <cassert>
#include <cstdio>

int main() {
  KeyboardController kbd;
  bool a20 = false;
  kbd.a20_gate = &a20;
  kbd.write(0x64, 0xD0);
  assert(kbd.has_data() && (kbd.read(0x64) & 1));
  assert(kbd.read(0x60) == 1 && !kbd.has_data());
  kbd.write(0x64, 0xD1);
  kbd.write(0x60, 3);
  assert(a20);
  kbd.write(0x64, 0xD0);
  assert(kbd.read(0x60) == 3);
  kbd.write(0x64, 0xDD);
  assert(!a20);
  kbd.write(0x64, 0xDF);
  assert(a20);
  // A20 commands must not consume the next keyboard command.
  kbd.write(0x60, 0xF4);
  assert(kbd.read(0x60) == 0xFA);
  puts("8042 A20 output port and gate commands: PASS");
}

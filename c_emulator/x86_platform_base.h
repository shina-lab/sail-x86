#pragma once

#include "x86_memory.h"
#include <cmath>

struct X87State {
  long double st[8] = {};
  u16 cw = 0x037F;
  u16 sw = 0x0000;
  u16 tw = 0xFFFF;

  int top() const { return (sw >> 11) & 7; }
  void set_top(int t) { sw = (sw & ~0x3800) | ((t & 7) << 11); }
  int physical(int i) const { return (top() + i) & 7; }
};

struct MXCSRState {
  u32 mxcsr = 0x1F80;
};

class X86PlatformBase {
public:
  EmulatorMemory memory;
  X87State x87;
  MXCSRState mxcsr_state;

  bool should_exit = false;
  int exit_code = 0;
};

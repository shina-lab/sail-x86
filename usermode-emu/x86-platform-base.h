#pragma once

#include "../emu-shared/integers.h"
#include <cmath>

struct MXCSRState {
  u32 mxcsr = 0x1F80;
};

class X86PlatformBase {
public:
  MXCSRState mxcsr_state;

  bool should_exit = false;
  int exit_code = 0;

  // Guest brk (heap) state, managed by the emulated brk syscall.
  u64 brk_base = 0;
  u64 brk_current = 0;
  u64 brk_limit = 0;  // end of pre-allocated brk region
};

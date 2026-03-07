#pragma once

#include "x86_memory.h"
#include <cmath>

struct MXCSRState {
  u32 mxcsr = 0x1F80;
};

class X86PlatformBase {
public:
  EmulatorMemory memory;
  MXCSRState mxcsr_state;

  bool should_exit = false;
  int exit_code = 0;
};

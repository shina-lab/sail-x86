#pragma once

#include "sail_x86_model.h"
#include "x86-helpers.h"

// Initialize CPU in real mode.
inline void init_cpu_state(x86::Model &model) {
  model.model_init();
  model.zinitializze_registers(UNIT);
  enable_all_features(model);

  model.zsystem_mode = true;
  model.zcur_mode = x86::zRealMode;
  model.zcur_cpl = 0;

  // CR0: no PE, no PG (real mode). ET + NE set.
  model.zCR0 = (1UL << 4) | (1UL << 5);
  model.zCR4 = 0;
  model.zEFER = 0;
  model.zCR2 = 0;
  model.zCR3 = 0;

  // Real mode segment setup: all bases = 0, limits = 0xFFFF
  for (int i = 0; i < 6; i++) {
    model.zSegReg.data[i] = 0;
    model.zSegCache.data[i].zseg_base = 0;
    model.zSegCache.data[i].zseg_limit = 0xFFFF;
    model.zSegCache.data[i].zseg_present = 1;
    model.zSegCache.data[i].zseg_s = 1;
    model.zSegCache.data[i].zseg_type = 0x3;  // data R/W
    model.zSegCache.data[i].zseg_dpl = 0;
    model.zSegCache.data[i].zseg_db = 0;  // 16-bit default
    model.zSegCache.data[i].zseg_l = 0;
    model.zSegCache.data[i].zseg_g = 0;
  }
  // CS type should be code
  model.zSegCache.data[x86::SEG_CS].zseg_type = 0xB;  // code, R, accessed

  model.zGDTR_base = 0;
  model.zGDTR_limit = 0;
  model.zIDTR_base = 0;
  model.zIDTR_limit = 0x3FF;  // Real mode IVT spans 0x0000-0x03FF
  model.zLDTR = 0;
  model.zTR = 0;
  model.zTR_base = 0;
  model.zTR_limit = 0;
  model.zKERNEL_GS_BASE = 0;


  // Disable interrupts
  model.zIF_flag = 0;
  model.zNT = 0;
  model.zRF = 0;

  // Zero GPRs
  for (int i = 0; i < 16; i++)
    model.zGPR.data[i] = 0;

  // Wire keyboard controller A20 gate to Sail register (disabled by default)
  model.kbd.a20_gate = &model.za20_enabled;
}

// Initialize CPU in real mode at the x86 reset vector.
// CS.base = 0xFFFF0000 so that CS:IP = 0xF000:FFF0 → linear 0xFFFFFFF0.
// SeaBIOS's first ljmpw $0xF000, $entry sets CS.base = 0xF0000 (normal real-mode).
inline void init_cpu_state_bios(x86::Model &model) {
  init_cpu_state(model);

  // The platform must leave A20 unmasked for the BIOS reset-vector fetch
  // at FFFFFFF0h (SDM Vol.3A 12.1.4). Resetting the Sail registers masks
  // it by default; without this, a reboot fetches unmapped FFEFFFF0h and
  // enters the previous guest's IVT instead of the firmware. Firmware can
  // subsequently control the gate through port 92h or the keyboard.
  model.za20_enabled = true;

  // CS selector = 0xF000, but base = 0xFFFF0000 (not sel<<4)
  model.zSegReg.data[x86::SEG_CS] = 0xF000;
  model.zSegCache.data[x86::SEG_CS].zseg_base = 0xFFFF0000;
  model.zSegCache.data[x86::SEG_CS].zseg_limit = 0xFFFF;

  // RIP = 0xFFF0 → first fetch at linear 0xFFFF0000 + 0xFFF0 = 0xFFFFFFF0
  model.zRIP = 0xFFF0;
}

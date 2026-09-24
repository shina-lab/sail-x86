#pragma once
#include "integers.h"

// The PIIX4 PM blocks used by SeaBIOS's built-in FADT/DSDT. The PM timer
// uses the platform's virtual nanosecond clock, not host wall time.
class ACPIPM {
public:
  u16 control = 0, enable = 0;
  u32 timer(u64 ns) const {
    return ((ns / 1000000000) * 3579545 +
            (ns % 1000000000) * 3579545 / 1000000000) & 0xFFFFFF;
  }
  u8 read(unsigned offset, u64 ns) const {
    if (offset == 2 || offset == 3) return enable >> ((offset - 2) * 8);
    if (offset == 4 || offset == 5) return control >> ((offset - 4) * 8);
    if (offset >= 8 && offset < 12) return timer(ns) >> ((offset - 8) * 8);
    return 0;
  }
  bool write(unsigned offset, u8 val) {
    if (offset == 2 || offset == 3) set_byte(enable, offset - 2, val);
    if (offset == 4 || offset == 5) set_byte(control, offset - 4, val);
    return (control & 0x3C00) == 0x2000; // SeaBIOS S5: SLP_TYP=0, SLP_EN=1
  }
private:
  static void set_byte(u16 &reg, unsigned byte, u8 val) {
    reg = (reg & ~(0xFF << (byte * 8))) | (u16(val) << (byte * 8));
  }
};

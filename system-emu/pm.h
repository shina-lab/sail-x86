#pragma once
#include "integers.h"

// The PIIX4 PM blocks used by SeaBIOS's built-in FADT/DSDT. The PM timer
// uses the platform's virtual nanosecond clock, not host wall time.
class ACPIPM {
public:
  u16 control = 0, enable = 0;
  u8 apmc = 0;
  u8 global_control = 0;
  // QEMU/SeaBIOS's fixed GPE0 and PCI hotplug I/O blocks. This platform
  // has no removable devices or event producers, so status/notification
  // bits stay clear; GPE enable bits still have normal read/write storage.
  // https://www.qemu.org/docs/master/specs/acpi_pci_hotplug.html
  bool handles_hotplug(u16 port) const {
    return (port >= 0xAE00 && port < 0xAE10) ||
           (port >= 0xAFE0 && port < 0xAFE4);
  }
  u8 read_hotplug(u16 port) const {
    if (port == 0xAFE2 || port == 0xAFE3)
      return gpe_enable >> ((port - 0xAFE2) * 8);
    // GPE_STS, PCI_UP, PCI_DOWN, feature set, and removability bitmap.
    return 0;
  }
  void write_hotplug(u16 port, u8 val) {
    if (port == 0xAFE2 || port == 0xAFE3)
      set_byte(gpe_enable, port - 0xAFE2, val);
    // GPE_STS is write-one-clear, with no pending events to acknowledge.
    // Notification/feature/removability registers are read-only; eject
    // requests have no effect because no slot is removable.
  }
  void apm_write(u8 value) {
    apmc = value;
    // PIIX4's QEMU-compatible ACPI mode commands from the built-in FADT.
    if (value == 0xF1) control |= 1;
    if (value == 0xF0) control &= ~1;
  }
  u32 timer(u64 ns) const {
    return ((ns / 1000000000) * 3579545 +
            (ns % 1000000000) * 3579545 / 1000000000) & 0xFFFFFF;
  }
  u8 read(unsigned offset, u64 ns) const {
    if (offset == 0x28) return global_control;
    if (offset == 2 || offset == 3) return enable >> ((offset - 2) * 8);
    if (offset == 4 || offset == 5) return control >> ((offset - 4) * 8);
    if (offset >= 8 && offset < 12) return timer(ns) >> ((offset - 8) * 8);
    return 0;
  }
  bool write(unsigned offset, u8 val) {
    if (offset == 0x28) global_control = val;
    if (offset == 2 || offset == 3) set_byte(enable, offset - 2, val);
    if (offset == 4 || offset == 5) set_byte(control, offset - 4, val);
    return (control & 0x3C00) == 0x2000; // SeaBIOS S5: SLP_TYP=0, SLP_EN=1
  }
private:
  u16 gpe_enable = 0;
  static void set_byte(u16 &reg, unsigned byte, u8 val) {
    reg = (reg & ~(0xFF << (byte * 8))) | (u16(val) << (byte * 8));
  }
};

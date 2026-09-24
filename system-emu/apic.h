#pragma once

#include "integers.h"
#include <algorithm>
#include <array>
#include <functional>

// Uniprocessor xAPIC. The bus clock is 100 MHz; time is supplied in ns
// from the same virtual clock as the PIT and TSC, including during HLT.
class LocalAPIC {
public:
  u64 base_msr = 0xFEE00900;
  const u64 *clock = nullptr;
  std::function<void(u8)> broadcast_eoi;

  LocalAPIC() { for (auto &v : lvt) v = MASK; }
  bool maps(u64 addr) const {
    return (base_msr & 0x800) && (addr >> 12) == (base_msr >> 12);
  }
  bool enabled() const { return (base_msr & 0x800) && (svr & 0x100); }
  bool accepts_pic() const { return (lvt[3] & 0x10700) == 0x700; }
  bool destination(u8 dest, bool logical) const {
    if (!logical) return dest == id || dest == 0xFF;
    if ((dfr >> 28) == 15) return (dest & (ldr >> 24)) != 0;
    return (dest & 0xF0) == ((ldr >> 24) & 0xF0) && (dest & (ldr >> 24) & 15);
  }
  bool request(u8 vector, bool level = false) {
    if (!enabled()) return false;
    if (vector < 16) { error_pending |= 1 << 6; return false; }
    irr[vector / 32] |= 1u << (vector % 32);
    if (level) tmr[vector / 32] |= 1u << (vector % 32);
    else tmr[vector / 32] &= ~(1u << (vector % 32));
    return true;
  }
  u32 priority() const {
    int v = highest(isr);
    return (tpr & 0xF0) >= (v & 0xF0) ? tpr : (v & 0xF0);
  }
  int pending() {
    update();
    int v = highest(irr);
    return enabled() && v >= 16 && (v & 0xF0) > (priority() & 0xF0) ? v : -1;
  }
  int acknowledge() {
    int v = pending();
    if (v >= 0) {
      irr[v / 32] &= ~(1u << (v % 32));
      isr[v / 32] |= 1u << (v % 32);
    }
    return v;
  }
  u32 read(u32 reg) {
    update();
    if (reg >= 0x100 && reg < 0x180 && !(reg & 15)) return isr[(reg - 0x100) / 16];
    if (reg >= 0x180 && reg < 0x200 && !(reg & 15)) return tmr[(reg - 0x180) / 16];
    if (reg >= 0x200 && reg < 0x280 && !(reg & 15)) return irr[(reg - 0x200) / 16];
    if (reg >= 0x320 && reg <= 0x370 && !(reg & 15)) return lvt[(reg - 0x320) / 16];
    switch (reg) {
    case 0x20: return u32(id) << 24;
    case 0x30: return 0x00050014; // integrated APIC, six LVT entries
    case 0x80: return tpr;
    case 0xA0: return priority();
    case 0xD0: return ldr;
    case 0xE0: return dfr;
    case 0xF0: return svr;
    case 0x280: return esr;
    case 0x300: return icr_low;
    case 0x310: return icr_high;
    case 0x380: return initial;
    case 0x390: return current;
    case 0x3E0: return divide;
    default: return 0;
    }
  }
  void write(u32 reg, u32 val) {
    update();
    if (reg >= 0x320 && reg <= 0x370 && !(reg & 15)) {
      u32 mask = reg == 0x320 ? 0x300FF : (reg == 0x370 ? 0x100FF : 0x1A7FF);
      lvt[(reg - 0x320) / 16] = (val & mask) | (enabled() ? 0 : MASK);
      return;
    }
    switch (reg) {
    case 0x20: id = val >> 24; break;
    case 0x80: tpr = val & 0xFF; break;
    case 0xB0: {
      int v = highest(isr);
      if (v >= 16) {
        isr[v / 32] &= ~(1u << (v % 32));
        bool level = tmr[v / 32] & (1u << (v % 32));
        tmr[v / 32] &= ~(1u << (v % 32));
        if (level && broadcast_eoi) broadcast_eoi(v);
      }
      break;
    }
    case 0xD0: ldr = val & 0xFF000000; break;
    case 0xE0: dfr = val | 0x0FFFFFFF; break;
    case 0xF0:
      svr = val & 0x3FF;
      if (!enabled()) for (auto &v : lvt) v |= MASK;
      break;
    case 0x280: esr = error_pending; error_pending = 0; break;
    case 0x310: icr_high = val & 0xFF000000; break;
    case 0x300: {
      icr_low = val & 0xCCFFF; // delivery is synchronous: no delivery-status bit
      unsigned shorthand = (val >> 18) & 3;
      bool target = shorthand == 1 || shorthand == 2 ||
                    (shorthand == 0 && destination(icr_high >> 24, val & 0x800));
      unsigned mode = (val >> 8) & 7;
      if (target && (mode == 0 || mode == 1)) {
        if ((val & 0xFF) < 16) error_pending |= 1 << 5;
        else request(val & 0xFF);
      }
      // INIT-deassert has no effect on an integrated xAPIC. There are no APs.
      break;
    }
    case 0x380: initial = current = val; remainder = 0; break;
    case 0x3E0: divide = val & 0xB; remainder = 0; break;
    default: break; // read-only and reserved registers
    }
  }
  void advance(u64 now) {
    u64 elapsed = now >= last_time ? now - last_time : 0;
    last_time = now;
    if (!current) return;
    unsigned shift = ((divide & 3) | ((divide & 8) >> 1)) + 1;
    unsigned divisor = 1u << (shift & 7);
    u64 ticks = (elapsed + remainder) / (10 * divisor);
    remainder = (elapsed + remainder) % (10 * divisor);
    if (ticks < current) { current -= ticks; return; }
    if (!(lvt[0] & MASK)) request(lvt[0] & 0xFF);
    if ((lvt[0] & 0x60000) == 0x20000 && initial)
      current = initial - (ticks - current) % initial;
    else current = 0;
  }

private:
  static constexpr u32 MASK = 1 << 16;
  u8 id = 0;
  u32 tpr = 0, svr = 0xFF, ldr = 0, dfr = 0xFFFFFFFF;
  u32 esr = 0, error_pending = 0, icr_low = 0, icr_high = 0;
  std::array<u32, 8> irr{}, isr{}, tmr{};
  std::array<u32, 6> lvt{};
  u32 initial = 0, current = 0, divide = 0;
  u64 last_time = 0, remainder = 0;
  void update() { if (clock) advance(*clock); }
  static int highest(const std::array<u32, 8> &bits) {
    for (int i = 7; i >= 0; --i)
      if (bits[i]) return i * 32 + 31 - __builtin_clz(bits[i]);
    return 0;
  }
};

class IOAPIC {
public:
  static constexpr u64 BASE = 0xFEC00000;
  LocalAPIC *lapic = nullptr;
  IOAPIC() { redir.fill(1ULL << 16); }
  bool maps(u64 addr) const { return (addr >> 12) == (BASE >> 12); }
  u32 read(u32 offset) const {
    if (offset == 0) return select;
    if (offset != 0x10) return 0;
    if (select == 0) return u32(id) << 24;
    if (select == 1) return (23 << 16) | 0x11;
    if (select == 2) return u32(id) << 24;
    if (select >= 0x10 && select < 0x40)
      return redir[(select - 0x10) / 2] >> ((select & 1) * 32);
    return 0;
  }
  void write(u32 offset, u32 val) {
    if (offset == 0) { select = val & 0xFF; return; }
    if (offset != 0x10) return;
    if (select == 0) id = (val >> 24) & 15;
    if (select < 0x10 || select >= 0x40) return;
    unsigned pin = (select - 0x10) / 2;
    if (select & 1) redir[pin] = (redir[pin] & 0xFFFFFFFF) | (u64(val & 0xFF000000) << 32);
    else redir[pin] = (redir[pin] & 0xFFFFFFFF00004000ULL) | (val & 0x1AFFF);
    service(pin, false);
  }
  // Input is the device's asserted state, independent of electrical polarity.
  void set_irq(unsigned pin, bool asserted) {
    if (pin >= redir.size()) return;
    bool edge = asserted && !lines[pin];
    lines[pin] = asserted;
    service(pin, edge);
  }
  void eoi(u8 vector) {
    for (unsigned pin = 0; pin < redir.size(); ++pin)
      if ((redir[pin] & 0x40FF) == (0x4000u | vector)) {
        redir[pin] &= ~0x4000ULL;
        service(pin, false);
      }
  }

private:
  u8 id = 0, select = 0; // SeaBIOS BUILD_IOAPIC_ID
  std::array<u64, 24> redir;
  std::array<bool, 24> lines{};
  void service(unsigned pin, bool edge) {
    u64 &entry = redir[pin];
    bool level = entry & 0x8000;
    if ((entry & 0x10000) || (level ? (!lines[pin] || (entry & 0x4000)) : !edge)) return;
    unsigned mode = (entry >> 8) & 7;
    if (!lapic || !lapic->destination(entry >> 56, entry & 0x800)) return;
    if (mode > 1) return; // fixed / lowest-priority delivery on this single CPU
    if (lapic->request(entry & 0xFF, level) && level) entry |= 0x4000;
  }
};

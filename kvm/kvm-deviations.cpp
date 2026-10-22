// Known deviations of the test hosts from the manuals.
//
// The model follows the Intel SDM, and the AMD APM where the two manuals
// define different behaviour for AMD processors; a case expects what the
// manuals give, the same on every host.  The hardware is only the test
// environment: where a host does something else, the case keeps its
// expectation and is listed here with the reason, so that the difference
// stays on record rather than being copied into the model or hidden by a
// host-specific expectation.  A listed case that mismatches is reported as
// a known deviation, not a failure; one that matches passes as usual.
//
// Each entry names the host vendor, the case (a trailing '*' also matches
// the case's variants, whose names extend the base name), and what the
// hardware does against what the manuals say, with section and page.

#include "kvm-harness.h"
#include <cpuid.h>

namespace {

const std::vector<KnownDeviation> DEVIATIONS = {
    // {amd, "case name", "reason"},

    // CR0.EM and CR0.TS (kvm-tests-cr0.cpp)
    {true, "vpaddd zmm0,zmm1,zmm2 [EM]*",
     "Zen 4 executes an EVEX instruction with CR0.EM = 1; APM Vol.4 §3.2.1 (p. 1878), the "
     "control register exceptions of the AVX512 instructions, lists \"CR0.EM = 1\" under "
     "\"Invalid opcode, #UD\", as Vol.2 §8.2.7 (p. 252) does for \"any SSE instruction (uses "
     "ZMM/YMM/XMM registers)\""},
    {true, "vpaddd zmm0,zmm1,zmm2 [EM MP]*",
     "Zen 4 executes an EVEX instruction with CR0.EM = 1; APM Vol.4 §3.2.1 (p. 1878) lists "
     "\"CR0.EM = 1\" under \"Invalid opcode, #UD\" for the AVX512 instructions"},
    {true, "kmovw k1,k2 [EM]*",
     "Zen 4 executes VEX KMOVW with CR0.EM = 1; the APM's KMOVW page (Vol.4 p. 212) says "
     "\"Exceptions for AVX512 instructions are enumerated in Section 3.2\", and §3.2.1 "
     "(p. 1878) lists \"CR0.EM = 1\" under \"Invalid opcode, #UD\""},
    {true, "kmovw k1,k2 [EM MP]*",
     "Zen 4 executes VEX KMOVW with CR0.EM = 1; the APM's KMOVW page (Vol.4 p. 212) refers to "
     "§3.2, whose §3.2.1 (p. 1878) lists \"CR0.EM = 1\" under \"Invalid opcode, #UD\""},

    // x87 stack faults and condition codes (kvm-tests-x87-cc.cpp)
    {false, "fsincos 2^63, ST(7) full (out of range*",
     "An Emerald Rapids treats a source of 2^63 (out of range) with ST(7) full as a stack "
     "overflow: masked it pushes the indefinite as both results with C2 = 0, unmasked it sets "
     "IE, SF and ES.  The SDM pushes only in range (FSINCOS Operation, Vol.2A p.3-383: \"IF "
     "ST(0) < 2^63 THEN ... TOP := TOP - 1; ... ELSE (* Source operand out of range *) C2 := "
     "1;\"), and \"The instruction does not raise an exception when the source operand is out "
     "of range\" (Description, p.3-382)."},
    {false, "fptan 2^63, ST(7) full (out of range*",
     "An Emerald Rapids treats a source of 2^63 (out of range) with ST(7) full as a stack "
     "overflow: masked it pushes the indefinite as both results with C2 = 0, unmasked it sets "
     "IE, SF and ES.  The SDM pushes only in range (FPTAN Operation, Vol.2A p.3-371: \"IF "
     "ST(0) < 2^63 THEN ... TOP := TOP - 1; ST(0) := 1.0; ELSE (* Source operand is "
     "out-of-range *) C2 := 1;\"), and \"The instruction does not raise an exception when the "
     "source operand is out of range\" (Description, p.3-370)."},
    {true, "fsincos 2^63, ST(7) full (out of range*",
     "A Zen 4 treats a source of 2^63 (out of range) with ST(7) full as a stack overflow: "
     "masked it pushes the indefinite as both results with C2 = 0, unmasked it sets IE, SF and "
     "ES.  The APM: \"If the source operand is outside this range, the instruction sets the C2 "
     "bit in the x87 status word to 1 and does not change the value in ST(0)\" (Vol.5 FSINCOS, "
     "p.298), so it loads no register and cannot overflow the stack."},
    {true, "fptan 2^63, ST(7) full (out of range*",
     "A Zen 4 treats a source of 2^63 (out of range) with ST(7) full as a stack overflow: "
     "masked it pushes the indefinite as both results with C2 = 0, unmasked it sets IE, SF and "
     "ES.  The APM: \"If the source value lies outside the specified range, the instruction "
     "sets the C2 bit of the x87 status word to 1 and does not change the value in ST(0)\" "
     "(Vol.5 FPTAN, p.286), so it loads no register and cannot overflow the stack."},
};

bool host_is_amd() {
  u32 a, b, c, d;
  __get_cpuid(0, &a, &b, &c, &d);
  return b == 0x68747541;  // "Auth" of AuthenticAMD
}

bool matches(const char *pattern, const std::string &name) {
  std::string p = pattern;
  if (!p.empty() && p.back() == '*')
    return name.compare(0, p.size() - 1, p, 0, p.size() - 1) == 0;
  return name == p;
}

}  // namespace

const KnownDeviation *known_deviation(const std::string &case_name) {
  static const bool amd = host_is_amd();
  for (const KnownDeviation &d : DEVIATIONS)
    if (d.amd == amd && matches(d.name, case_name))
      return &d;
  return nullptr;
}

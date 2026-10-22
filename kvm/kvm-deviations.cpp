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

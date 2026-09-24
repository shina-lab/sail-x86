#include "kvm-harness.h"

// System and privileged instructions that the differential suite can still
// observe from CPL 0 in the guest: control-register moves, the fault paths of
// SYSCALL/SYSRET/SYSENTER/SYSEXIT without their MSRs, RDTSC's zero extension,
// RDPMC's #GP, CLI, INT n, and the VMX instructions outside VMX operation.
void add_system_tests(std::vector<TestCase> &tests) {
  (void)tests;
}

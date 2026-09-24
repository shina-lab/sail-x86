#include "kvm-harness.h"
#include <limits>

static void expect(bool result, const char *name) {
  if (!result) {
    fprintf(stderr, "State comparison regression failed: %s\n", name);
    exit(1);
  }
}

int main() {
  expect(TestCase{}.flags_mask == FL_ALL, "default flag comparison");
  for (u64 fill : {u64(0), ~u64(0)}) {
    initial_register_fill = fill;
    ArchState background;
    ArchState inputs = {.rax = 0, .rbx = 42};
    inputs.xmm[1] = xmm_from_u64(0, 42);
    inputs.kregs[1] = 0;
    expect(inputs.rax == 0 && inputs.rbx == 42, "explicit GPR inputs survive fill");
    expect(inputs.rcx == fill && inputs.r15 == fill, "default GPR inputs use fill");
    expect(inputs.rsp == 0 && (inputs.rflags & ~FL_ARITH) == 0x2,
           "stack and control state stay fixed");
    expect((inputs.rflags & FL_ARITH) == (fill & FL_ARITH),
           "arithmetic flags use the register background");
    ArchState carry = {.rflags = initial_flags(FL_CF, 0)};
    expect(!(carry.rflags & FL_CF) &&
           (carry.rflags & (FL_ARITH & ~FL_CF)) == (fill & (FL_ARITH & ~FL_CF)),
           "an explicit zero carry leaves other arithmetic flags at the background");
    carry.rflags = initial_flags(FL_CF, FL_CF);
    expect((carry.rflags & FL_CF) != 0, "an explicit carry survives either fill");
    ArchState selected_flags = with_flag_inputs(carry, FL_OF);
    expect(selected_flags.rflags == background.rflags,
           "unused flag inputs do not leak from a shared operand pool");
    for (int reg = 0; reg < 32; reg++)
      for (int q = 0; q < 8; q++)
        expect(background.xmm[reg].q[q] == fill, "every default SIMD bit uses fill");
    for (u64 reg : background.kregs)
      expect(reg == fill, "every default mask bit uses fill");
    expect(inputs.xmm[1].q[0] == 0 && inputs.xmm[1].q[1] == 42 &&
           inputs.xmm[1].q[7] == 0 && inputs.kregs[1] == 0,
           "explicit vector and mask inputs survive fill");

    ArchState pool = inputs;
    pool.rbx = 123;
    pool.xmm[2] = xmm_from_u64(123, 456);
    ArchState selected = with_vector_inputs(
        with_gpr_inputs(pool, {&ArchState::rax}), 1U << 1);
    expect(selected.rax == 0 && selected.rbx == fill,
           "only declared general-purpose inputs override the background");
    expect(selected.xmm[1] == inputs.xmm[1] &&
           selected.xmm[2] == background.xmm[2],
           "memory forms do not inherit an unused vector operand");

    // A missing write of zero is invisible in the zero run and must fail in
    // the ones run, even when the register was not explicitly initialized.
    ArchState correct = background;
    correct.rax = 0;
    correct.xmm[31] = {};
    correct.kregs[7] = 0;
    expect(correct.compare(background) == (fill == 0), "detect omitted zero writes");
    ArchState cleared_flags = background;
    cleared_flags.rflags &= ~FL_ARITH;
    expect(cleared_flags.compare(background) == (fill == 0),
           "detect omitted arithmetic flag clears");
  }
  initial_register_fill = 0;
  for (const auto &v : {xmm_from_u64(1, 2), xmm_from_u32(1, 2, 3, 4),
                        xmm_from_f32(1, 2, 3, 4), xmm_from_f64(1, 2)})
    for (int q = 2; q < 8; q++)
      expect(v.q[q] == 0, "initialized upper SIMD bits");

  ArchState original;
  original.rflags = 0x2 | FL_ALL;
  expect(original.compare(original), "identical states");

  // An instruction's nominal outputs must not restrict the comparison.
  for (int reg = 0; reg < 32; reg++) {
    for (int q : {0, 7}) {
      ArchState changed = original;
      changed.xmm[reg].q[q] ^= 1;
      expect(!original.compare(changed), "unrelated or upper SIMD bits");
    }
  }
  for (int reg = 0; reg < 8; reg++) {
    ArchState changed = original;
    changed.kregs[reg] ^= 1ULL << 63;
    expect(!original.compare(changed), "unrelated mask register");
  }
  for (int bit : {0, 2, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 18, 21}) {
    ArchState changed = original;
    changed.rflags ^= 1ULL << bit;
    expect(!original.compare(changed), "changed or preserved RFLAGS bit");
  }
  ArchState changed = original;
  changed.rflags ^= FL_ARITH;
  expect(original.compare(changed, FL_NONE), "undefined arithmetic flags");
  changed.rflags ^= FL_DF;
  expect(!original.compare(changed, FL_NONE), "DIV still preserves DF");

  // A scalar approximate result may differ within tolerance. Everything
  // outside that result, including copied lanes and other registers, is exact.
  original.xmm[0] = xmm_from_f32(1, 2, 3, 4);
  changed = original;
  changed.xmm[0] = xmm_from_f32(1.0001f, 2, 3, 4);
  auto approximate = [&](const ArchState &other) {
    return original.compare(other, FL_ALL, false, 1e-3, 32, 32, 0);
  };
  expect(approximate(changed), "approximate result within tolerance");
  changed.xmm[0].q[0] ^= 1ULL << 32;
  expect(!approximate(changed), "copied scalar lane must match exactly");
  changed = original;
  changed.xmm[0].q[7] = 1;
  expect(!approximate(changed), "upper bits outside approximate result");
  changed = original;
  changed.xmm[31].q[0] = 1;
  expect(!approximate(changed), "unrelated register during approximate test");
  changed = original;
  changed.xmm[0] = xmm_from_f32(std::numeric_limits<float>::quiet_NaN(), 2, 3, 4);
  expect(!approximate(changed), "NaN must not hide a mismatch");
  original.xmm[0] = xmm_from_f32(0.0f, 2, 3, 4);
  changed = original;
  changed.xmm[0] = xmm_from_f32(-0.0f, 2, 3, 4);
  expect(!approximate(changed), "signed zero must match");

  expect(shift_flags_mask(4, 8, 0) == FL_ALL, "zero shift preserves all flags");
  expect(shift_flags_mask(4, 32, 32) == FL_ALL, "masked zero shift count");
  expect(shift_flags_mask(4, 8, 1) == FL_NO_AF, "one-bit shift defines OF");
  expect(shift_flags_mask(4, 8, 8) == (FL_NO_AF_OF & ~FL_CF), "large SHL leaves CF undefined");
  expect(shift_flags_mask(7, 8, 8) == FL_NO_AF_OF, "large SAR defines CF");
  expect(shift_flags_mask(0, 8, 1) == FL_ALL, "one-bit rotate preserves other flags");
  expect(shift_flags_mask(0, 8, 8) == (FL_ALL & ~FL_OF), "full rotate has nonzero masked count");
  expect(shift_flags_mask(2, 8, 9) == FL_ALL, "zero effective rotate-through-carry count");
  expect(shift_flags_mask(2, 8, 10) == (FL_ALL & ~FL_OF), "OF uses masked count, not effective count");
  puts("State comparison regressions passed");
}

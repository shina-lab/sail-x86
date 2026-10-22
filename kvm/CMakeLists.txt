add_executable(kvm_harness
  kvm-harness.cpp
  kvm-tests-alu.cpp
  kvm-tests-baseline.cpp
  kvm-tests-sse.cpp
  kvm-tests-misc.cpp
  kvm-tests-x87-avx.cpp
  kvm-tests-x87-compat.cpp
  kvm-tests-x87-cc.cpp
  kvm-tests-fp-edge.cpp
  kvm-tests-encoding.cpp
  kvm-tests-exception.cpp
  kvm-tests-mmx.cpp
  kvm-tests-features.cpp
  kvm-tests-compat.cpp
  kvm-tests-compat-avx.cpp
  kvm-tests-xsave.cpp
  kvm-tests-avx-fp.cpp
  kvm-tests-avx-int.cpp
  kvm-tests-avx-shift.cpp
  kvm-tests-avx-fma.cpp
  kvm-tests-avx-scalar.cpp
  kvm-tests-avx-narrow.cpp
  kvm-tests-avx-cmp.cpp
  kvm-tests-avx-perm.cpp
  kvm-tests-avx-conv.cpp
  kvm-tests-avx-special.cpp
  kvm-tests-avx-mov.cpp
  kvm-tests-avx-vex.cpp
  kvm-tests-avx-hi16.cpp
  kvm-tests-avx-fp16.cpp
  kvm-tests-system.cpp
  kvm-tests-hints.cpp
  kvm-tests-waitpkg.cpp
  kvm-tests-cr0.cpp
  kvm-tests-amx.cpp
  kvm-variants.cpp
  kvm-deviations.cpp
)
target_link_libraries(kvm_harness PRIVATE x86_model)
target_compile_options(kvm_harness PRIVATE -Wno-missing-field-initializers -Wno-unused-parameter)
add_dependencies(kvm_harness generated_sail_x86_model)

# The harness writes its ctest entries after each link (write_ctest_file in
# kvm-harness.cpp): one per category, in slices short enough for ctest -j.
# ctest reads them through kvm-tests.cmake.
set(KVM_TESTS_GENERATED ${CMAKE_CURRENT_BINARY_DIR}/kvm-tests-generated.cmake)
add_custom_command(TARGET kvm_harness POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E env KVM_CTEST=${KVM_TESTS_GENERATED} $<TARGET_FILE:kvm_harness>
  VERBATIM)
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/kvm-tests.cmake
  "if(EXISTS \"${KVM_TESTS_GENERATED}\")\n"
  "  include(\"${KVM_TESTS_GENERATED}\")\n"
  "else()\n"
  "  add_test(kvm_harness_NOT_BUILT kvm_harness_NOT_BUILT)\n"
  "endif()\n")
set_property(DIRECTORY APPEND PROPERTY TEST_INCLUDE_FILES
  ${CMAKE_CURRENT_BINARY_DIR}/kvm-tests.cmake)

add_executable(kvm_state_compare test-state-compare.cpp)
target_link_libraries(kvm_state_compare PRIVATE x86_model)
add_dependencies(kvm_state_compare generated_sail_x86_model)
add_test(NAME kvm_state_compare COMMAND kvm_state_compare)

add_executable(kvm_vm86 test-vm86.cpp)
target_link_libraries(kvm_vm86 PRIVATE x86_system_model)
target_compile_options(kvm_vm86 PRIVATE -Wno-missing-field-initializers)
add_dependencies(kvm_vm86 generated_sail_x86_model)
# A run of all the cases takes tens of seconds; ctest runs them in slices.
foreach(slice RANGE 7)
  math(EXPR n "${slice} + 1")
  add_test(NAME system_vm86_${n}of8 COMMAND kvm_vm86 --model-only --slice=${slice}/8)
  add_test(NAME kvm_vm86_${n}of8 COMMAND kvm_vm86 --slice=${slice}/8)
  set_tests_properties(kvm_vm86_${n}of8 PROPERTIES SKIP_RETURN_CODE 77 TIMEOUT 120)
endforeach()

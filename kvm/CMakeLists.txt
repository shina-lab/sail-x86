add_executable(kvm_harness kvm_harness.cpp)
target_link_libraries(kvm_harness PRIVATE x86_model)
add_dependencies(kvm_harness generated_sail_x86_model)

# Each test runs a category filter. Use ctest -j to run in parallel.
set(KVM_CATEGORIES
  Baseline
  "ALU reg,reg 8"
  "ALU reg,reg 16"
  "ALU reg,reg 32"
  "ALU reg,reg 64"
  "ADC/SBB CF=1"
  "TEST reg,reg"
  Shifts
  "Unary ops"
  MUL/IMUL
  DIV/IDIV
  "Register variation"
  Random
  SSE
  SSSE3
  SSE4.1
  SSE4.2
  AES
  SETcc
  CMOVcc
  POP
  LEAVE
  LOOP
  CMPXCHG8B
  MOVNTI
  LDMXCSR
  Fences
  SSE3
  SSE4.1v
  MOVxPS
  String
  EMMS
  AVX
)

foreach(cat ${KVM_CATEGORIES})
  string(REPLACE " " "_" test_name "kvm_${cat}")
  string(REPLACE "/" "_" test_name "${test_name}")
  add_test(NAME ${test_name} COMMAND kvm_harness "${cat}")
endforeach()

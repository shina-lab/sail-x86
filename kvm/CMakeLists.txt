add_executable(kvm_harness
  kvm-harness.cpp
  kvm-tests-alu.cpp
  kvm-tests-baseline.cpp
  kvm-tests-sse.cpp
  kvm-tests-misc.cpp
  kvm-tests-x87-avx.cpp
  kvm-tests-fp-edge.cpp
  kvm-tests-encoding.cpp
  kvm-tests-exception.cpp
  kvm-tests-mmx.cpp
  kvm-tests-features.cpp
  kvm-tests-compat.cpp
  kvm-tests-xsave.cpp
  kvm-tests-avx-fp.cpp
  kvm-tests-avx-int.cpp
  kvm-tests-avx-shift.cpp
  kvm-tests-avx-fma.cpp
  kvm-tests-avx-scalar.cpp
  kvm-tests-avx-narrow.cpp
  kvm-tests-avx-cmp.cpp
)
target_link_libraries(kvm_harness PRIVATE x86_model)
target_compile_options(kvm_harness PRIVATE -Wno-missing-field-initializers -Wno-unused-parameter)
add_dependencies(kvm_harness generated_sail_x86_model)

# Each test runs a category filter. Use ctest -j to run in parallel.
set(KVM_CATEGORIES
  Baseline
  "ALU add 8"
  "ALU add 16"
  "ALU add 32"
  "ALU add 64"
  "ALU or 8"
  "ALU or 16"
  "ALU or 32"
  "ALU or 64"
  "ALU adc 8"
  "ALU adc 16"
  "ALU adc 32"
  "ALU adc 64"
  "ALU sbb 8"
  "ALU sbb 16"
  "ALU sbb 32"
  "ALU sbb 64"
  "ALU and 8"
  "ALU and 16"
  "ALU and 32"
  "ALU and 64"
  "ALU sub 8"
  "ALU sub 16"
  "ALU sub 32"
  "ALU sub 64"
  "ALU xor 8"
  "ALU xor 16"
  "ALU xor 32"
  "ALU xor 64"
  "ALU cmp 8"
  "ALU cmp 16"
  "ALU cmp 32"
  "ALU cmp 64"
  "ADC/SBB CF=1 adc 8"
  "ADC/SBB CF=1 adc 16"
  "ADC/SBB CF=1 adc 32"
  "ADC/SBB CF=1 adc 64"
  "ADC/SBB CF=1 sbb 8"
  "ADC/SBB CF=1 sbb 16"
  "ADC/SBB CF=1 sbb 32"
  "ADC/SBB CF=1 sbb 64"
  "TEST 8"
  "TEST 16"
  "TEST 32"
  "TEST 64"
  "Shift shl 8"
  "Shift shl 16"
  "Shift shl 32"
  "Shift shl 64"
  "Shift shr 8"
  "Shift shr 16"
  "Shift shr 32"
  "Shift shr 64"
  "Shift sar 8"
  "Shift sar 16"
  "Shift sar 32"
  "Shift sar 64"
  "Shift rol 8"
  "Shift rol 16"
  "Shift rol 32"
  "Shift rol 64"
  "Shift ror 8"
  "Shift ror 16"
  "Shift ror 32"
  "Shift ror 64"
  "Shift rcl 8"
  "Shift rcl 16"
  "Shift rcl 32"
  "Shift rcl 64"
  "Shift rcl CF=1 8"
  "Shift rcl CF=1 16"
  "Shift rcl CF=1 32"
  "Shift rcl CF=1 64"
  "Shift rcr 8"
  "Shift rcr 16"
  "Shift rcr 32"
  "Shift rcr 64"
  "Shift rcr CF=1 8"
  "Shift rcr CF=1 16"
  "Shift rcr CF=1 32"
  "Shift rcr CF=1 64"
  "Unary ops"
  MUL
  IMUL
  DIV
  IDIV
  "Register variation"
  Random
  SSE
  SSSE3
  SSE4.1
  "SSE Legacy Upper"
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
  x87
  ENTER
  CMPXCHG16B
  "AVX Edge"
  "FP Edge"
  ADCX/ADOX
  DAZ/FTZ
  "OpSize Edge"
  "REX R/B/X"
  NOP
  Prefix
  LZCNT/TZCNT
  POPCNT
  BSF/BSR
  BSWAP
  XCHG
  MOVSX/MOVSXD
  BT/BTC
  MOVBE
  "String ops"
  "SSE4.2 str"
  "XSAVE/XRSTOR"
  "Exception #DE"
  "Exception #UD"
  "Exception #GP"
  "x87 mem"
  "LOCK mem"
  "Indirect JMP"
  "PUSH/POP mem"
  "FP conv edge"
  BMI2
  RETF
  CRC32
  GFNI
  SHA
  "MMX arith"
  "MMX saturate"
  "MMX logical"
  "MMX compare"
  "MMX shift"
  "MMX pack"
  "MMX minmax"
  "MMX move"
  "MMX mem"
  "Feature gating"
  "Compat"
  "RETF compat"
  BCD
  "XSAVEC roundtrip"
  XGETBV
  IA32_XSS
  "CPUID XSAVE"
  "AVX FP packed"
  "AVX int"
  "AVX shift"
  "AVX FMA"
  "AVX scalar"
  "AVX narrow"
  "AVX cmp"
  "MOVQ store"
  "K-register ops"
  "Vec stores"
)

foreach(cat ${KVM_CATEGORIES})
  string(REPLACE " " "_" test_name "kvm_${cat}")
  string(REPLACE "/" "_" test_name "${test_name}")
  add_test(NAME ${test_name} COMMAND kvm_harness "${cat}")
endforeach()

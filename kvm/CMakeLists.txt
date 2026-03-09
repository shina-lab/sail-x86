add_executable(kvm_harness
  kvm-harness.cpp
  kvm-tests-alu.cpp
  kvm-tests-baseline.cpp
  kvm-tests-sse.cpp
  kvm-tests-misc.cpp
  kvm-tests-x87-avx.cpp
  kvm-tests-fp-edge.cpp
  kvm-tests-extended.cpp
  kvm-tests-exception.cpp
  kvm-tests-vex.cpp
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
  AVX
  EVEX
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
  "Exception #DE"
  "Exception #UD"
  "Exception #GP"
  "VEX horiz FP"
  VPTEST
  VPCMPGTQ
  VPERMIL
  VMOVNTDQ
  VPERM2F128
  "VEX insert/extract i128"
  VPMASKMOVD
  "x87 mem"
  "EVEX mask"
  "K-register ops"
  "Vec stores"
  "LOCK mem"
  "Indirect JMP"
  "PUSH/POP mem"
  "FP conv edge"
  "MOVQ store"
  "VEX 0F3A"
  BMI2
  "VEX AES-NI"
  "VEX SSSE3"
  "VEX SSE4.1"
  "VEX pack/unpack"
  "VEX multiply"
  "VEX saturating arith"
  "VEX shifts"
  "VEX imm shifts"
  "AVX2 var shifts"
  "VEX test"
  "VEX 0F misc"
  "VEX gather"
  "EVEX blend"
  VLDDQU
  CRC32
  GFNI
  SHA
  "VEX GFNI"
  "EVEX rotate imm"
  "EVEX FP conv"
  "EVEX rounding"
  "EVEX scalar FP"
  "EVEX VMOVSS/SD"
  "EVEX FMA rounding"
  VPTERNLOGD
  F16C
  "FP conv prec"
  "EVEX bcast mem"
  "EVEX VPCMP D/Q"
  "EVEX VPMINUQ"
  "EVEX VPTESTM W1"
  "EVEX VPCMPEQQ/GTQQ xmm"
  "EVEX VPMINUW"
  "EVEX VPMULLD/Q"
  "EVEX VPTERNLOGQ"
  "EVEX VPABSQ"
  "EVEX variable rotate"
  "EVEX VPMADD52"
  "EVEX VPOPCNTD/Q"
  "EVEX VPLZCNTD/Q"
  "EVEX VPCONFLICTD/Q"
  "EVEX VPSHLD"
  "EVEX VPSHRD"
  "EVEX VDBPSADBW"
  "EVEX VPSHLDV"
  "EVEX VPSHRDV"
  "EVEX VPMULTISHIFTQB"
  "EVEX VPMOV narrow"
  "EVEX VNNI"
)

foreach(cat ${KVM_CATEGORIES})
  string(REPLACE " " "_" test_name "kvm_${cat}")
  string(REPLACE "/" "_" test_name "${test_name}")
  add_test(NAME ${test_name} COMMAND kvm_harness "${cat}")
endforeach()

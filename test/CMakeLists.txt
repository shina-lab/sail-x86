set(SIM $<TARGET_FILE:sail-x86-user>)

# Build test binaries from source.
add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/hello
  COMMAND gcc -static -nostdlib -o ${CMAKE_CURRENT_BINARY_DIR}/hello
    ${CMAKE_CURRENT_SOURCE_DIR}/hello.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/hello.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/hello-libc
  COMMAND gcc -static -o ${CMAKE_CURRENT_BINARY_DIR}/hello-libc
    ${CMAKE_CURRENT_SOURCE_DIR}/hello-libc.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/hello-libc.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/syscall-test
  COMMAND gcc -static -nostdlib -o ${CMAKE_CURRENT_BINARY_DIR}/syscall-test
    ${CMAKE_CURRENT_SOURCE_DIR}/syscall-test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/syscall-test.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/avx-test
  COMMAND gcc -static -nostdlib -mavx -mf16c -o ${CMAKE_CURRENT_BINARY_DIR}/avx-test
    ${CMAKE_CURRENT_SOURCE_DIR}/avx-test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/avx-test.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/auxv-test
  COMMAND gcc -static -nostdlib -o ${CMAKE_CURRENT_BINARY_DIR}/auxv-test
    ${CMAKE_CURRENT_SOURCE_DIR}/auxv-test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/auxv-test.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/x87-test
  COMMAND gcc -static -nostdlib -mno-sse -mfpmath=387 -o ${CMAKE_CURRENT_BINARY_DIR}/x87-test
    ${CMAKE_CURRENT_SOURCE_DIR}/x87-test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/x87-test.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/avx512-test
  COMMAND gcc -static -nostdlib -mavx512f -o ${CMAKE_CURRENT_BINARY_DIR}/avx512-test
    ${CMAKE_CURRENT_SOURCE_DIR}/avx512-test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/avx512-test.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/cpuid-test
  COMMAND gcc -static -nostdlib -o ${CMAKE_CURRENT_BINARY_DIR}/cpuid-test
    ${CMAKE_CURRENT_SOURCE_DIR}/cpuid-test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/cpuid-test.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test
  COMMAND gcc -static -nostdlib -o ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test
    ${CMAKE_CURRENT_SOURCE_DIR}/insn-ud-test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/insn-ud-test.c
)

add_custom_target(test-binaries ALL
  DEPENDS
    ${CMAKE_CURRENT_BINARY_DIR}/hello
    ${CMAKE_CURRENT_BINARY_DIR}/hello-libc
    ${CMAKE_CURRENT_BINARY_DIR}/syscall-test
    ${CMAKE_CURRENT_BINARY_DIR}/avx-test
    ${CMAKE_CURRENT_BINARY_DIR}/auxv-test
    ${CMAKE_CURRENT_BINARY_DIR}/x87-test
    ${CMAKE_CURRENT_BINARY_DIR}/avx512-test
    ${CMAKE_CURRENT_BINARY_DIR}/cpuid-test
    ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test
)

# Test: hello (raw syscall, no libc)
add_test(
  NAME hello
  COMMAND sh -c "${SIM} ${CMAKE_CURRENT_BINARY_DIR}/hello | grep -q 'Hello, world!'"
)

# Test: hello-libc (static libc)
add_test(
  NAME hello-libc
  COMMAND sh -c "${SIM} ${CMAKE_CURRENT_BINARY_DIR}/hello-libc | grep -q 'Hello from libc!'"
)

# Test: /bin/echo (dynamic binary)
add_test(
  NAME echo
  COMMAND sh -c "${SIM} /bin/echo hello | grep -q hello"
)

# Test: /bin/ls (dynamic binary, runs to completion)
add_test(
  NAME ls
  COMMAND ${SIM} /bin/ls /
)

# Test: syscall layer
add_test(
  NAME syscall-test
  COMMAND ${SIM} ${CMAKE_CURRENT_BINARY_DIR}/syscall-test
)

# Test: AVX instructions
add_test(
  NAME avx-test
  COMMAND ${SIM} ${CMAKE_CURRENT_BINARY_DIR}/avx-test
)

# Test: auxiliary vector
add_test(
  NAME auxv-test
  COMMAND ${SIM} ${CMAKE_CURRENT_BINARY_DIR}/auxv-test
)

# Test: x87 FPU
add_test(
  NAME x87-test
  COMMAND ${SIM} ${CMAKE_CURRENT_BINARY_DIR}/x87-test
)

# Test: AVX-512 instructions
add_test(
  NAME avx512-test
  COMMAND ${SIM} ${CMAKE_CURRENT_BINARY_DIR}/avx512-test
)

# Test: CPUID feature flags for each level
add_test(NAME cpuid-v1 COMMAND ${SIM} -cpu 1 ${CMAKE_CURRENT_BINARY_DIR}/cpuid-test 1)
add_test(NAME cpuid-v2 COMMAND ${SIM} -cpu 2 ${CMAKE_CURRENT_BINARY_DIR}/cpuid-test 2)
add_test(NAME cpuid-v3 COMMAND ${SIM} -cpu 3 ${CMAKE_CURRENT_BINARY_DIR}/cpuid-test 3)
add_test(NAME cpuid-v4 COMMAND ${SIM} -cpu 4 ${CMAKE_CURRENT_BINARY_DIR}/cpuid-test 4)

# Test: Instructions #UD on v1 (no SSE3/SSSE3/SSE4)
# Exit code 134 = 128 + 6 (#UD fault vector)
add_test(NAME ud-v1-addsubps COMMAND sh -c "${SIM} -cpu 1 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test addsubps 2>/dev/null; test $? -eq 134")
add_test(NAME ud-v1-pshufb   COMMAND sh -c "${SIM} -cpu 1 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test pshufb   2>/dev/null; test $? -eq 134")
add_test(NAME ud-v1-roundps  COMMAND sh -c "${SIM} -cpu 1 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test roundps  2>/dev/null; test $? -eq 134")
add_test(NAME ud-v1-blendvps COMMAND sh -c "${SIM} -cpu 1 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test blendvps 2>/dev/null; test $? -eq 134")
add_test(NAME ud-v1-pblendw  COMMAND sh -c "${SIM} -cpu 1 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test pblendw  2>/dev/null; test $? -eq 134")
add_test(NAME ud-v1-popcnt   COMMAND sh -c "${SIM} -cpu 1 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test popcnt   2>/dev/null; test $? -eq 134")

# Test: Same instructions succeed on v2+
add_test(NAME ok-v2-addsubps COMMAND ${SIM} -cpu 2 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test addsubps)
add_test(NAME ok-v2-pshufb   COMMAND ${SIM} -cpu 2 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test pshufb)
add_test(NAME ok-v2-roundps  COMMAND ${SIM} -cpu 2 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test roundps)
add_test(NAME ok-v2-blendvps COMMAND ${SIM} -cpu 2 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test blendvps)
add_test(NAME ok-v2-pblendw  COMMAND ${SIM} -cpu 2 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test pblendw)
add_test(NAME ok-v2-popcnt   COMMAND ${SIM} -cpu 2 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test popcnt)

# Test: /usr/bin/wc (dynamic binary)
add_test(
  NAME wc
  COMMAND sh -c "echo 'one two three' | ${SIM} /usr/bin/wc -w | grep -q 3"
)

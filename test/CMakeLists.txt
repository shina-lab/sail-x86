set(SIM $<TARGET_FILE:sail_x86_sim>)

# Build test binaries from source.
add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/hello
  COMMAND gcc -static -nostdlib -o ${CMAKE_CURRENT_BINARY_DIR}/hello
    ${CMAKE_CURRENT_SOURCE_DIR}/hello.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/hello.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/hello_libc
  COMMAND gcc -static -o ${CMAKE_CURRENT_BINARY_DIR}/hello_libc
    ${CMAKE_CURRENT_SOURCE_DIR}/hello_libc.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/hello_libc.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/syscall_test
  COMMAND gcc -static -nostdlib -o ${CMAKE_CURRENT_BINARY_DIR}/syscall_test
    ${CMAKE_CURRENT_SOURCE_DIR}/syscall_test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/syscall_test.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/avx_test
  COMMAND gcc -static -nostdlib -mavx -o ${CMAKE_CURRENT_BINARY_DIR}/avx_test
    ${CMAKE_CURRENT_SOURCE_DIR}/avx_test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/avx_test.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/auxv_test
  COMMAND gcc -static -nostdlib -o ${CMAKE_CURRENT_BINARY_DIR}/auxv_test
    ${CMAKE_CURRENT_SOURCE_DIR}/auxv_test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/auxv_test.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/x87_test
  COMMAND gcc -static -nostdlib -mno-sse -mfpmath=387 -o ${CMAKE_CURRENT_BINARY_DIR}/x87_test
    ${CMAKE_CURRENT_SOURCE_DIR}/x87_test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/x87_test.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/avx512_test
  COMMAND gcc -static -nostdlib -mavx512f -o ${CMAKE_CURRENT_BINARY_DIR}/avx512_test
    ${CMAKE_CURRENT_SOURCE_DIR}/avx512_test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/avx512_test.c
)

add_custom_target(test_binaries ALL
  DEPENDS
    ${CMAKE_CURRENT_BINARY_DIR}/hello
    ${CMAKE_CURRENT_BINARY_DIR}/hello_libc
    ${CMAKE_CURRENT_BINARY_DIR}/syscall_test
    ${CMAKE_CURRENT_BINARY_DIR}/avx_test
    ${CMAKE_CURRENT_BINARY_DIR}/auxv_test
    ${CMAKE_CURRENT_BINARY_DIR}/x87_test
    ${CMAKE_CURRENT_BINARY_DIR}/avx512_test
)

# Test: hello (raw syscall, no libc)
add_test(
  NAME hello
  COMMAND sh -c "${SIM} ${CMAKE_CURRENT_BINARY_DIR}/hello | grep -q 'Hello, world!'"
)

# Test: hello_libc (static libc)
add_test(
  NAME hello_libc
  COMMAND sh -c "${SIM} ${CMAKE_CURRENT_BINARY_DIR}/hello_libc | grep -q 'Hello from libc!'"
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
  NAME syscall_test
  COMMAND ${SIM} ${CMAKE_CURRENT_BINARY_DIR}/syscall_test
)

# Test: AVX instructions
add_test(
  NAME avx_test
  COMMAND ${SIM} ${CMAKE_CURRENT_BINARY_DIR}/avx_test
)

# Test: auxiliary vector
add_test(
  NAME auxv_test
  COMMAND ${SIM} ${CMAKE_CURRENT_BINARY_DIR}/auxv_test
)

# Test: x87 FPU
add_test(
  NAME x87_test
  COMMAND ${SIM} ${CMAKE_CURRENT_BINARY_DIR}/x87_test
)

# Test: AVX-512 instructions
add_test(
  NAME avx512_test
  COMMAND ${SIM} ${CMAKE_CURRENT_BINARY_DIR}/avx512_test
)

# Test: /usr/bin/wc (dynamic binary)
add_test(
  NAME wc
  COMMAND sh -c "echo 'one two three' | ${SIM} /usr/bin/wc -w | grep -q 3"
)

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

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/sse-fp-test
  COMMAND gcc -static -nostdlib -msse4.2 -mno-avx -o ${CMAKE_CURRENT_BINARY_DIR}/sse-fp-test
    ${CMAKE_CURRENT_SOURCE_DIR}/sse-fp-test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/sse-fp-test.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/sse-cvt-test
  COMMAND gcc -static -nostdlib -msse4.2 -mno-avx -o ${CMAKE_CURRENT_BINARY_DIR}/sse-cvt-test
    ${CMAKE_CURRENT_SOURCE_DIR}/sse-cvt-test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/sse-cvt-test.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/sse-int-test
  COMMAND gcc -static -nostdlib -msse4.2 -mno-avx -o ${CMAKE_CURRENT_BINARY_DIR}/sse-int-test
    ${CMAKE_CURRENT_SOURCE_DIR}/sse-int-test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/sse-int-test.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/sse-shuf-test
  COMMAND gcc -static -nostdlib -msse4.2 -mno-avx -o ${CMAKE_CURRENT_BINARY_DIR}/sse-shuf-test
    ${CMAKE_CURRENT_SOURCE_DIR}/sse-shuf-test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/sse-shuf-test.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/sse3-test
  COMMAND gcc -static -nostdlib -msse4.2 -mno-avx -o ${CMAKE_CURRENT_BINARY_DIR}/sse3-test
    ${CMAKE_CURRENT_SOURCE_DIR}/sse3-test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/sse3-test.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/sse4-test
  COMMAND gcc -static -nostdlib -msse4.2 -mno-avx -o ${CMAKE_CURRENT_BINARY_DIR}/sse4-test
    ${CMAKE_CURRENT_SOURCE_DIR}/sse4-test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/sse4-test.c
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/sse-crypto-test
  COMMAND gcc -static -nostdlib -msse4.2 -maes -mpclmul -mgfni -mno-avx -o ${CMAKE_CURRENT_BINARY_DIR}/sse-crypto-test
    ${CMAKE_CURRENT_SOURCE_DIR}/sse-crypto-test.c
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/sse-crypto-test.c
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
    ${CMAKE_CURRENT_BINARY_DIR}/sse-fp-test
    ${CMAKE_CURRENT_BINARY_DIR}/sse-cvt-test
    ${CMAKE_CURRENT_BINARY_DIR}/sse-int-test
    ${CMAKE_CURRENT_BINARY_DIR}/sse-shuf-test
    ${CMAKE_CURRENT_BINARY_DIR}/sse3-test
    ${CMAKE_CURRENT_BINARY_DIR}/sse4-test
    ${CMAKE_CURRENT_BINARY_DIR}/sse-crypto-test
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

# Test: VPCLMULQDQ gating.  The VEX.128 form comes with PCLMULQDQ + AVX (v3),
# the VEX.256 and EVEX forms with the VPCLMULQDQ extension (v4); the EVEX form
# has no opmask, so EVEX.aaa != 0 is #UD even on v4.
add_test(NAME ok-v3-vpclmulqdq-xmm    COMMAND ${SIM} -cpu 3 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test vpclmulqdq-xmm)
add_test(NAME ud-v3-vpclmulqdq-ymm    COMMAND sh -c "${SIM} -cpu 3 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test vpclmulqdq-ymm 2>/dev/null; test $? -eq 134")
add_test(NAME ok-v4-vpclmulqdq-ymm    COMMAND ${SIM} -cpu 4 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test vpclmulqdq-ymm)
add_test(NAME ok-v4-vpclmulqdq-zmm    COMMAND ${SIM} -cpu 4 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test vpclmulqdq-zmm)
add_test(NAME ud-v4-vpclmulqdq-zmm-k1 COMMAND sh -c "${SIM} -cpu 4 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test vpclmulqdq-zmm-k1 2>/dev/null; test $? -eq 134")

# Test: VAES gating, same shape: VEX.128 with AES + AVX (v3), VEX.256 and EVEX
# with the VAES extension (v4), no opmask on the EVEX form.
add_test(NAME ok-v3-vaesenc-xmm    COMMAND ${SIM} -cpu 3 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test vaesenc-xmm)
add_test(NAME ud-v3-vaesenc-ymm    COMMAND sh -c "${SIM} -cpu 3 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test vaesenc-ymm 2>/dev/null; test $? -eq 134")
add_test(NAME ok-v4-vaesenc-ymm    COMMAND ${SIM} -cpu 4 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test vaesenc-ymm)
add_test(NAME ok-v4-vaesenc-zmm    COMMAND ${SIM} -cpu 4 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test vaesenc-zmm)
add_test(NAME ud-v4-vaesenc-zmm-k1 COMMAND sh -c "${SIM} -cpu 4 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test vaesenc-zmm-k1 2>/dev/null; test $? -eq 134")

# Test: GFNI gating.  All three instructions, in every encoding, come with the
# GFNI flag (v4); below it the legacy and VEX forms are #UD.
add_test(NAME ud-v3-gf2p8mulb          COMMAND sh -c "${SIM} -cpu 3 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test gf2p8mulb 2>/dev/null; test $? -eq 134")
add_test(NAME ok-v4-gf2p8mulb          COMMAND ${SIM} -cpu 4 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test gf2p8mulb)
add_test(NAME ud-v3-vgf2p8affineqb-ymm COMMAND sh -c "${SIM} -cpu 3 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test vgf2p8affineqb-ymm 2>/dev/null; test $? -eq 134")
add_test(NAME ok-v4-vgf2p8affineqb-ymm COMMAND ${SIM} -cpu 4 ${CMAKE_CURRENT_BINARY_DIR}/insn-ud-test vgf2p8affineqb-ymm)

# Test: Legacy SSE instructions
add_test(NAME sse-fp-test    COMMAND ${SIM} ${CMAKE_CURRENT_BINARY_DIR}/sse-fp-test)
add_test(NAME sse-cvt-test   COMMAND ${SIM} ${CMAKE_CURRENT_BINARY_DIR}/sse-cvt-test)
add_test(NAME sse-int-test   COMMAND ${SIM} ${CMAKE_CURRENT_BINARY_DIR}/sse-int-test)
add_test(NAME sse-shuf-test  COMMAND ${SIM} ${CMAKE_CURRENT_BINARY_DIR}/sse-shuf-test)
add_test(NAME sse3-test      COMMAND ${SIM} ${CMAKE_CURRENT_BINARY_DIR}/sse3-test)
add_test(NAME sse4-test      COMMAND ${SIM} ${CMAKE_CURRENT_BINARY_DIR}/sse4-test)
add_test(NAME sse-crypto-test COMMAND ${SIM} ${CMAKE_CURRENT_BINARY_DIR}/sse-crypto-test)

# Test: /usr/bin/wc (dynamic binary)
add_test(
  NAME wc
  COMMAND sh -c "echo 'one two three' | ${SIM} /usr/bin/wc -w | grep -q 3"
)

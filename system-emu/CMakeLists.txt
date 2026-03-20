# System-level emulator: uses same generated Sail model with different
# platform base (PhysicalMemory instead of raw host memory).

add_library(x86_system_model
    x86-externals.cpp
    ../emu-shared/x86-externals-common.cpp
    x86-phys-mem.cpp
    "${CMAKE_BINARY_DIR}/sail_x86_model.cpp"
    "${CMAKE_BINARY_DIR}/sail_x86_model.h"
)

target_include_directories(x86_system_model
    PUBLIC
        "${CMAKE_CURRENT_SOURCE_DIR}"
        "${CMAKE_CURRENT_SOURCE_DIR}/../emu-shared"
        "${CMAKE_BINARY_DIR}"
)

target_link_libraries(x86_system_model
    PUBLIC sail_runtime
)

target_compile_options(x86_system_model PRIVATE -maes -mpclmul -msha -mgfni -msse4.2 -mrdrnd -mrdseed -Wno-unused-parameter)

# Silence warnings from generated code.
set_source_files_properties(
    "${CMAKE_BINARY_DIR}/sail_x86_model.cpp"
    PROPERTIES COMPILE_OPTIONS "-Wno-extra;-Wno-unused;-Wno-uninitialized"
)

add_dependencies(x86_system_model generated_sail_x86_model)

# System emulator binary.
add_executable(sail-x86-system x86-system-sim.cpp)
target_link_libraries(sail-x86-system PRIVATE x86_system_model)
add_dependencies(sail-x86-system generated_sail_x86_model)

# =========================================================================
# "make linux" — download + build kernel, build initramfs, print boot command.
# =========================================================================
#
# Requires: curl, busybox-static, fakeroot, standard build tools.
# Downloads Linux kernel source automatically if not already present.

set(BZIMAGE "${CMAKE_BINARY_DIR}/bzImage")
set(INITRAMFS "${CMAKE_BINARY_DIR}/initramfs.cpio")

add_custom_command(
    OUTPUT "${INITRAMFS}"
    COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/mk-initramfs.sh" "${INITRAMFS}"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/mk-initramfs.sh"
    COMMENT "Building initramfs"
)

add_custom_command(
    OUTPUT "${BZIMAGE}"
    COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/mk-linux.sh" "${CMAKE_BINARY_DIR}"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/mk-linux.sh"
    COMMENT "Building Linux kernel"
)

add_custom_target(linux
    DEPENDS sail-x86-system "${INITRAMFS}" "${BZIMAGE}"
    COMMAND ${CMAKE_COMMAND} -E echo ""
    COMMAND ${CMAKE_COMMAND} -E echo "Run:"
    COMMAND ${CMAKE_COMMAND} -E echo "  ./system-emu/sail-x86-system -i initramfs.cpio bzImage"
    COMMAND ${CMAKE_COMMAND} -E echo ""
)

# Tests.
add_executable(system_test_basic tests/test-basic.cpp)
target_link_libraries(system_test_basic PRIVATE x86_system_model)
add_dependencies(system_test_basic generated_sail_x86_model)
add_test(NAME system_basic COMMAND system_test_basic)

add_executable(system_test_paging tests/test-paging.cpp)
target_link_libraries(system_test_paging PRIVATE x86_system_model)
add_dependencies(system_test_paging generated_sail_x86_model)
add_test(NAME system_paging COMMAND system_test_paging)

add_executable(system_test_exceptions tests/test-exceptions.cpp)
target_link_libraries(system_test_exceptions PRIVATE x86_system_model)
add_dependencies(system_test_exceptions generated_sail_x86_model)
add_test(NAME system_exceptions COMMAND system_test_exceptions)

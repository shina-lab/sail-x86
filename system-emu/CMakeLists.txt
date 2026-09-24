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
find_package(PkgConfig REQUIRED)
pkg_check_modules(NCURSESW REQUIRED ncursesw)
add_executable(sail-x86-system x86-system-sim.cpp)
target_include_directories(sail-x86-system PRIVATE ${NCURSESW_INCLUDE_DIRS})
target_link_libraries(sail-x86-system PRIVATE x86_system_model ${NCURSESW_LIBRARIES})
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
            "${CMAKE_CURRENT_SOURCE_DIR}/hello32.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/kvm-test.c"
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
    COMMAND ${CMAKE_COMMAND} -E echo "For VGA text mode display:"
    COMMAND ${CMAKE_COMMAND} -E echo "  ./system-emu/sail-x86-system -vga -i initramfs.cpio bzImage"
    COMMAND ${CMAKE_COMMAND} -E echo ""
)

# =========================================================================
# "make dos" — download + build SeaBIOS, create FreeDOS disk image.
# =========================================================================

add_custom_target(dos
    DEPENDS sail-x86-system
    COMMAND ${CMAKE_COMMAND} -E chdir "${CMAKE_BINARY_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}/mk-freedos.sh" .
    COMMENT "Building SeaBIOS + FreeDOS disk image"
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

# Automated boot smoke test: undriven Linux boot to the console banner,
# the machine-checkable criterion the timing measurements use.  Skips
# when the boot images have not been built (make linux).  Excluded from
# a quick run with: ctest -LE boot
add_test(NAME boot_linux_banner
         COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/boot-smoke.sh ${CMAKE_BINARY_DIR})
set_tests_properties(boot_linux_banner PROPERTIES
  TIMEOUT 600
  LABELS "boot"
  SKIP_RETURN_CODE 127)

add_executable(system_test_a20 tests/test-a20.cpp)
target_link_libraries(system_test_a20 PRIVATE x86_system_model)
add_dependencies(system_test_a20 generated_sail_x86_model)
add_test(NAME system_a20 COMMAND system_test_a20)

add_executable(system_test_vmx tests/test-vmx.cpp)
target_link_libraries(system_test_vmx PRIVATE x86_system_model)
add_dependencies(system_test_vmx generated_sail_x86_model)
add_test(NAME system_vmx COMMAND system_test_vmx)

# IDE channel device model (ATA disk and ATAPI CD-ROM), driven through its
# ports without a CPU.
add_executable(system_test_ide tests/test-ide.cpp)
target_include_directories(system_test_ide PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}/../emu-shared")
add_test(NAME system_ide COMMAND system_test_ide)

# Emulator library: generated model + external implementations.

add_library(x86_model
    x86-externals.cpp
    ../emu-shared/x86-externals-common.cpp
    x86-syscall.cpp
    x86-elf.cpp
    "${CMAKE_BINARY_DIR}/sail_x86_model.cpp"
    "${CMAKE_BINARY_DIR}/sail_x86_model.h"
)

target_include_directories(x86_model
    PUBLIC
        "${CMAKE_CURRENT_SOURCE_DIR}"
        "${CMAKE_CURRENT_SOURCE_DIR}/../emu-shared"
        "${CMAKE_BINARY_DIR}"
)

target_link_libraries(x86_model
    PUBLIC sail_runtime
)

target_compile_options(x86_model PRIVATE -maes -mpclmul -msha -msse4.2 -mrdrnd -mrdseed -Wno-unused-parameter)

# Silence warnings from generated code.
set_source_files_properties(
    "${CMAKE_BINARY_DIR}/sail_x86_model.cpp"
    PROPERTIES COMPILE_OPTIONS "-Wno-extra;-Wno-unused;-Wno-uninitialized"
)

add_dependencies(x86_model generated_sail_x86_model)

# Emulator binary.
add_executable(sail-x86-user x86-sim.cpp)
target_link_libraries(sail-x86-user PRIVATE x86_model)
add_dependencies(sail-x86-user generated_sail_x86_model)

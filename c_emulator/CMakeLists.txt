# Emulator library: generated model + external implementations.

add_library(x86_model
    x86_externals.cpp
    x86_syscall.cpp
    x86_elf.cpp
    "${CMAKE_BINARY_DIR}/sail_x86_model.cpp"
    "${CMAKE_BINARY_DIR}/sail_x86_model.h"
)

target_include_directories(x86_model
    PUBLIC
        "${CMAKE_CURRENT_SOURCE_DIR}"
        "${CMAKE_BINARY_DIR}"
)

target_link_libraries(x86_model
    PUBLIC sail_runtime
)

target_compile_options(x86_model PRIVATE -maes -mpclmul -msse4.2 -Wno-unused-parameter)

# Silence warnings from generated code.
set_source_files_properties(
    "${CMAKE_BINARY_DIR}/sail_x86_model.cpp"
    PROPERTIES COMPILE_OPTIONS "-Wno-extra;-Wno-unused;-Wno-uninitialized"
)

add_dependencies(x86_model generated_sail_x86_model)

# Emulator binary.
add_executable(sail_x86_sim x86_sim.cpp)
target_link_libraries(sail_x86_sim PRIVATE x86_model)
add_dependencies(sail_x86_sim generated_sail_x86_model)

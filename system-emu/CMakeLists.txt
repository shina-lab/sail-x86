# System-level emulator: uses same generated Sail model with different
# platform base (PhysicalMemory instead of raw host memory).

add_library(x86_system_model
    x86_externals.cpp
    x86_phys_mem.cpp
    "${CMAKE_BINARY_DIR}/sail_x86_model.cpp"
    "${CMAKE_BINARY_DIR}/sail_x86_model.h"
)

target_include_directories(x86_system_model
    PUBLIC
        "${CMAKE_CURRENT_SOURCE_DIR}"
        "${CMAKE_BINARY_DIR}"
)

target_link_libraries(x86_system_model
    PUBLIC sail_runtime
)

target_compile_options(x86_system_model PRIVATE -maes -mpclmul -msse4.2 -Wno-unused-parameter)

# Silence warnings from generated code.
set_source_files_properties(
    "${CMAKE_BINARY_DIR}/sail_x86_model.cpp"
    PROPERTIES COMPILE_OPTIONS "-Wno-extra;-Wno-unused;-Wno-uninitialized"
)

add_dependencies(x86_system_model generated_sail_x86_model)

# System emulator binary.
add_executable(sail_x86_system x86_system_sim.cpp)
target_link_libraries(sail_x86_system PRIVATE x86_system_model)
add_dependencies(sail_x86_system generated_sail_x86_model)

# Tests.
add_executable(system_test_basic tests/test_basic.cpp)
target_link_libraries(system_test_basic PRIVATE x86_system_model)
add_dependencies(system_test_basic generated_sail_x86_model)
add_test(NAME system_basic COMMAND system_test_basic)

add_executable(system_test_paging tests/test_paging.cpp)
target_link_libraries(system_test_paging PRIVATE x86_system_model)
add_dependencies(system_test_paging generated_sail_x86_model)
add_test(NAME system_paging COMMAND system_test_paging)

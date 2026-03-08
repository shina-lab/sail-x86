cmake_minimum_required(VERSION 3.20)
cmake_policy(VERSION 3.20...3.31)

project(sail-x86
  VERSION 0.1.0
  HOMEPAGE_URL "https://github.com/rui314/sail-x86"
)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED TRUE)
set(SAIL_REQUIRED_VER 0.20)

if (NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "" FORCE)
endif()

set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)
set(CMAKE_POSITION_INDEPENDENT_CODE TRUE)

add_compile_options(-Wall -Wextra -Wno-sign-compare)

# Ensure assertions are enabled even in Release.
string(TOUPPER "${CMAKE_BUILD_TYPE}" uppercase_CMAKE_BUILD_TYPE)
if(NOT uppercase_CMAKE_BUILD_TYPE STREQUAL "DEBUG")
    add_compile_options($<$<OR:$<COMPILE_LANGUAGE:C>,$<COMPILE_LANGUAGE:CXX>>:-UNDEBUG>)
endif()

# Find GMP.
find_library(GMP_LIBRARY gmp)
find_path(GMP_INCLUDE_DIR gmp.h)
if (NOT GMP_LIBRARY OR NOT GMP_INCLUDE_DIR)
    message(FATAL_ERROR "GMP not found. Try 'sudo apt install libgmp-dev'.")
endif()
add_library(GMP::GMP UNKNOWN IMPORTED)
set_target_properties(GMP::GMP PROPERTIES
    IMPORTED_LOCATION "${GMP_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${GMP_INCLUDE_DIR}")
message(STATUS "Found GMP: ${GMP_LIBRARY}")

# Find Sail compiler.
find_program(SAIL_BIN "sail")
if (NOT SAIL_BIN)
    message(FATAL_ERROR "Sail not found.")
endif()
message(STATUS "Found sail: ${SAIL_BIN}")

execute_process(
    COMMAND ${SAIL_BIN} --dir
    OUTPUT_VARIABLE sail_dir
    OUTPUT_STRIP_TRAILING_WHITESPACE
    COMMAND_ERROR_IS_FATAL ANY
)
message(STATUS "Sail library directory: ${sail_dir}")

# Sail C runtime.
add_library(sail_runtime
    "${sail_dir}/lib/elf.c"
    "${sail_dir}/lib/elf.h"
    "${sail_dir}/lib/rts.c"
    "${sail_dir}/lib/rts.h"
    "${sail_dir}/lib/sail.c"
    "${sail_dir}/lib/sail.h"
    "${sail_dir}/lib/sail_failure.c"
    "${sail_dir}/lib/sail_failure.h"
    "${sail_dir}/lib/sail_coverage.h"
    "${sail_dir}/lib/cJSON.c"
    "${sail_dir}/lib/cJSON.h"
    "${sail_dir}/lib/sail_config.c"
    "${sail_dir}/lib/sail_config.h"
)
target_include_directories(sail_runtime PUBLIC "${sail_dir}/lib")
target_compile_options(sail_runtime PRIVATE -Wno-extra -Wno-unused)
target_link_libraries(sail_runtime PUBLIC GMP::GMP)

# Sail model generated C++ code.
add_subdirectory("model")

# User-mode emulator binary.
add_subdirectory("usermode-emu")

# System-level emulator binary.
add_subdirectory("system-emu")

# Tests.
enable_testing()
add_subdirectory("test")

# KVM differential test harness.
add_subdirectory("kvm")

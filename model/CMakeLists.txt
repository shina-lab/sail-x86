set(project_file "x86.sail_project")

# Reconfigure if the project file changes.
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${project_file})

# Get list of Sail source files for dependency tracking.
execute_process(
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMAND
        ${SAIL_BIN}
        ${project_file}
        --require-version ${SAIL_REQUIRED_VER}
        --all-modules
        --list-files
    OUTPUT_VARIABLE sail_list_files
    OUTPUT_STRIP_TRAILING_WHITESPACE
    COMMAND_ERROR_IS_FATAL ANY
)

separate_arguments(sail_srcs UNIX_COMMAND "${sail_list_files}")

# Generate C++ code from Sail model.
set(c_model_no_ext "${CMAKE_BINARY_DIR}/sail_x86_model")
set(c_model "${c_model_no_ext}.cpp")
set(c_model_header "${c_model_no_ext}.h")

add_custom_command(
    DEPENDS ${sail_srcs} ${project_file}
    OUTPUT ${c_model} ${c_model_header}
    VERBATIM
    COMMENT "Building C++ code from Sail model"
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMAND
        ${SAIL_BIN}
        --require-version ${SAIL_REQUIRED_VER}
        --memo-z3-path "${CMAKE_CURRENT_BINARY_DIR}/sail_smt_cache"
        -o ${c_model_no_ext}
        -O --Oconstant-fold
        --memo-z3
        --cpp
        --cpp-namespace x86
        --cpp-derive-from "public X86PlatformBase"
        --c-no-main
        --c-header-include x86_platform_base.h
        --c-include x86_platform_impl.h
        --c-preserve step
        --c-preserve run
        --all-modules
        ${project_file}
)

add_custom_target(generated_sail_x86_model DEPENDS ${c_model} ${c_model_header})

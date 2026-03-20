file(REMOVE_RECURSE
  "CMakeFiles/test_binaries"
  "auxv_test"
  "avx512_test"
  "avx_test"
  "hello"
  "hello_libc"
  "syscall_test"
  "x87_test"
)

# Per-language clean rules from dependency scanning.
foreach(lang )
  include(CMakeFiles/test_binaries.dir/cmake_clean_${lang}.cmake OPTIONAL)
endforeach()

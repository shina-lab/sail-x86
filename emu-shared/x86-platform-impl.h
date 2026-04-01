#pragma once

// This header is #included into the generated Sail C++ model via --c-include.
// It provides declarations needed by the external function implementations.

#include <cstdint>
#include <cstdio>

// Debug trace to stderr (defined in x86-externals-common.cpp)
int trace_stderr(const char *s);
#include <cstring>
#include <cmath>
#include <cfenv>

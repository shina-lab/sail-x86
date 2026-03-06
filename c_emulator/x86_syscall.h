#pragma once

#include "sail_x86_model.h"

// Emulate a Linux x86-64 syscall.
// Reads syscall number from RAX, args from RDI/RSI/RDX/R10/R8/R9.
// Returns result in RAX.
void emulate_syscall(x86::Model &model);

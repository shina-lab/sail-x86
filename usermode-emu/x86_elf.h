#pragma once

#include "integers.h"
#include "sail_x86_model.h"
#include <string>

struct ElfLoadResult {
  u64 entry_point;
  u64 phdr_addr;
  u64 phdr_num;
  u64 phdr_size;
  u64 prog_entry;
  u64 interp_base;
  bool success;
  std::string error;
};

ElfLoadResult load_elf(x86::Model &model, const std::string &filename);

u64 setup_stack(x86::Model &model, const ElfLoadResult &elf,
                int argc, char **argv, char **envp, char **auxv);

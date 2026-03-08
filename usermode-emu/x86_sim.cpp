#include "sail_x86_model.h"
#include "x86_elf.h"
#include "x86_syscall.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>

static void usage(const char *prog) {
  fprintf(stderr, "Usage: %s [options] <elf-binary> [args...]\n", prog);
  fprintf(stderr, "Options:\n");
  fprintf(stderr, "  -d    Enable debug trace\n");
  fprintf(stderr, "  -h    Show this help\n");
}

int main(int argc, char *argv[], char *envp[]) {
  bool debug = false;
  int first_arg = 1;

  while (first_arg < argc && argv[first_arg][0] == '-') {
    if (strcmp(argv[first_arg], "-d") == 0) {
      debug = true;
      first_arg++;
    } else if (strcmp(argv[first_arg], "-h") == 0 ||
               strcmp(argv[first_arg], "--help") == 0) {
      usage(argv[0]);
      return 0;
    } else {
      fprintf(stderr, "Unknown option: %s\n", argv[first_arg]);
      usage(argv[0]);
      return 1;
    }
  }

  if (first_arg >= argc) {
    usage(argv[0]);
    return 1;
  }

  const char *elf_path = argv[first_arg];

  x86::Model model;
  model.model_init();
  model.zinitializze_registers(UNIT);
  model.zcur_mode = x86::zLongMode;
  model.zcur_cpl = 3;

  ElfLoadResult elf = load_elf(model, elf_path);
  if (!elf.success) {
    fprintf(stderr, "Error: %s\n", elf.error.c_str());
    return 1;
  }

  int guest_argc = argc - first_arg;
  char **guest_argv = &argv[first_arg];

  // Find the host auxiliary vector (follows the null-terminated envp array)
  char **auxv_ptr = envp;
  while (*auxv_ptr) auxv_ptr++;
  auxv_ptr++;

  u64 initial_rsp = setup_stack(model, elf, guest_argc, guest_argv, envp,
                                auxv_ptr);

  model.zRIP = elf.entry_point;
  model.zGPR.data[4] = initial_rsp;
  for (int i = 0; i < 16; i++)
    if (i != 4) model.zGPR.data[i] = 0;

  if (debug) {
    fprintf(stderr, "sail-x86: loaded %s\n", elf_path);
    fprintf(stderr, "sail-x86: entry=0x%lx rsp=0x%lx brk=0x%lx interp_base=0x%lx\n",
            elf.entry_point, initial_rsp, model.brk_current, elf.interp_base);
  }

  u64 insn_count = 0;
  x86::zExecutionResult result = {};
  result.kind = x86::Kind_zOk;
  result.variants.zOk = UNIT;

  while (!model.should_exit) {
    if (debug) {
      fprintf(stderr, "[%lu] RIP=0x%lx RAX=0x%lx RCX=0x%lx RDX=0x%lx RSP=0x%lx\n",
              insn_count, model.zRIP,
              model.zGPR.data[0], model.zGPR.data[1],
              model.zGPR.data[2], model.zGPR.data[4]);
    }

    model.zstep(&result, UNIT);

    switch (result.kind) {
    case x86::Kind_zOk:
      insn_count++;
      break;

    case x86::Kind_zHalt:
      if (debug) {
        u64 nr = model.zGPR.data[0];
        fprintf(stderr, "[%lu] SYSCALL nr=%lu arg1=0x%lx arg2=0x%lx arg3=0x%lx\n",
                insn_count, nr, model.zGPR.data[7], model.zGPR.data[6], model.zGPR.data[2]);
      }
      emulate_syscall(model);
      insn_count++;
      break;

    case x86::Kind_zFault: {
      i64 vec = result.variants.zFault.ztup0;
      u32 err = result.variants.zFault.ztup1;
      fprintf(stderr, "sail-x86: fault #%ld (error code 0x%x) at RIP=0x%lx after %lu instructions\n",
              vec, err, model.zRIP, insn_count);
      // Dump instruction bytes at fault address for debugging
      if (debug) {
        fprintf(stderr, "  bytes:");
        u8 insn_bytes[16];
        memcpy(insn_bytes, (void *)model.zRIP, 16);
        for (int i = 0; i < 16; i++)
          fprintf(stderr, " %02x", insn_bytes[i]);
        fprintf(stderr, "\n");
      }
      model.model_fini();
      return 128 + (int)vec;
    }
    }
  }

  if (debug) {
    fprintf(stderr, "sail-x86: exited with code %d after %lu instructions\n",
            model.exit_code, insn_count);
  }

  model.model_fini();
  _exit(model.exit_code);
}

// System-level x86-64 emulator.
// Loads a Linux kernel via the 64-bit boot protocol and executes it
// using the Sail x86 model with paging and exception delivery.

#include "sail_x86_model.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>

static void usage(const char *prog) {
  fprintf(stderr, "Usage: %s [options]\n", prog);
  fprintf(stderr, "Options:\n");
  fprintf(stderr, "  -d          Enable debug trace\n");
  fprintf(stderr, "  -m <MB>     RAM size in MB (default 512)\n");
  fprintf(stderr, "  -h          Show this help\n");
}

// Set up initial CPU state for system-level emulation.
// This puts the CPU into 64-bit long mode with identity-mapped page tables.
static void init_cpu_state(x86::Model &model) {
  model.model_init();
  model.zinitializze_registers(UNIT);

  // System mode: faults delivered via IDT
  model.zsystem_mode = true;

  // Start in long mode, ring 0
  model.zcur_mode = x86::zLongMode;
  model.zcur_cpl = 0;

  // CR0: PE=1 (protected mode), ET=1 (387 present), NE=1, WP=1, PG=1
  model.zCR0 = (1UL << 0)   // PE
             | (1UL << 4)   // ET
             | (1UL << 5)   // NE
             | (1UL << 16)  // WP
             | (1UL << 31); // PG

  // CR4: PAE=1 (required for long mode), OSFXSR=1
  model.zCR4 = (1UL << 5)   // PAE
             | (1UL << 9);  // OSFXSR

  // EFER: LME=1, LMA=1, SCE=1, NXE=1
  model.zEFER = (1UL << 0)   // SCE
              | (1UL << 8)   // LME
              | (1UL << 10)  // LMA
              | (1UL << 11); // NXE

  // Initialize descriptor table registers to zero
  model.zGDTR_base = 0;
  model.zGDTR_limit = 0;
  model.zIDTR_base = 0;
  model.zIDTR_limit = 0;
  model.zLDTR = 0;
  model.zTR = 0;
  model.zTR_base = 0;
  model.zTR_limit = 0;

  // Zero out segment bases
  model.zFS_BASE = 0;
  model.zGS_BASE = 0;
  model.zKERNEL_GS_BASE = 0;

  // Zero out CR2, CR3
  model.zCR2 = 0;
  model.zCR3 = 0;
}

// Build identity-mapped page tables in guest physical memory.
// Maps the first `ram_size` bytes 1:1 using 2MB pages.
// Returns the physical address of PML4 (to be loaded into CR3).
static u64 setup_identity_page_tables(PhysicalMemory &mem, u64 ram_size) {
  // Layout:
  //   0x1000: PML4 (one entry pointing to PDPT)
  //   0x2000: PDPT (up to 512 entries pointing to PDs)
  //   0x3000+: PD tables (each covers 1GB with 512 × 2MB entries)

  const u64 pml4_addr = 0x1000;
  const u64 pdpt_addr = 0x2000;
  const u64 pd_base   = 0x3000;

  // Number of 1GB regions to map
  u64 num_gb = (ram_size + (1ULL << 30) - 1) >> 30;
  if (num_gb > 512) num_gb = 512;

  // PML4[0] -> PDPT
  mem.write64(pml4_addr, pdpt_addr | 0x03); // Present + R/W

  for (u64 i = 0; i < num_gb; i++) {
    u64 pd_addr = pd_base + i * 0x1000;

    // PDPT[i] -> PD[i]
    mem.write64(pdpt_addr + i * 8, pd_addr | 0x03); // Present + R/W

    // Fill PD with 512 × 2MB pages
    for (u64 j = 0; j < 512; j++) {
      u64 phys = (i << 30) | (j << 21);
      if (phys >= ram_size) break;
      // PS=1 (bit 7) for 2MB page, Present + R/W
      mem.write64(pd_addr + j * 8, phys | 0x83);
    }
  }

  return pml4_addr;
}

int main(int argc, char *argv[]) {
  bool debug = false;
  u64 ram_mb = 512;
  int first_arg = 1;

  while (first_arg < argc && argv[first_arg][0] == '-') {
    if (strcmp(argv[first_arg], "-d") == 0) {
      debug = true;
      first_arg++;
    } else if (strcmp(argv[first_arg], "-m") == 0 && first_arg + 1 < argc) {
      ram_mb = atoi(argv[first_arg + 1]);
      first_arg += 2;
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

  u64 ram_size = ram_mb * 1024 * 1024;

  x86::Model model;
  init_cpu_state(model);

  if (!model.phys_mem.init(ram_size)) {
    fprintf(stderr, "Failed to allocate %lu MB guest RAM\n", ram_mb);
    return 1;
  }

  // Set up identity-mapped page tables
  u64 cr3 = setup_identity_page_tables(model.phys_mem, ram_size);
  model.zCR3 = cr3;

  if (debug) {
    fprintf(stderr, "sail-x86-system: RAM=%luMB CR3=0x%lx\n", ram_mb, cr3);
    fprintf(stderr, "sail-x86-system: CPU in long mode, ring 0\n");
  }

  // For now, write a simple test program at 0x100000:
  // mov eax, 0x42    ; B8 42 00 00 00
  // hlt              ; F4
  u8 test_code[] = { 0xB8, 0x42, 0x00, 0x00, 0x00, 0xF4 };
  model.phys_mem.write_bytes(0x100000, test_code, sizeof(test_code));
  model.zRIP = 0x100000;

  // Zero GPRs
  for (int i = 0; i < 16; i++)
    model.zGPR.data[i] = 0;
  model.zGPR.data[4] = 0x80000; // RSP = some stack area

  if (debug)
    fprintf(stderr, "sail-x86-system: starting execution at RIP=0x%lx\n", (u64)model.zRIP);

  u64 insn_count = 0;
  x86::zExecutionResult result = {};
  result.kind = x86::Kind_zOk;
  result.variants.zOk = UNIT;

  while (!model.should_exit) {
    if (debug) {
      fprintf(stderr, "[%lu] RIP=0x%lx RAX=0x%lx RCX=0x%lx RDX=0x%lx RSP=0x%lx\n",
              insn_count, (u64)model.zRIP,
              (u64)model.zGPR.data[0], (u64)model.zGPR.data[1],
              (u64)model.zGPR.data[2], (u64)model.zGPR.data[4]);
    }

    model.zstep(&result, UNIT);

    switch (result.kind) {
    case x86::Kind_zOk:
      insn_count++;
      break;

    case x86::Kind_zHalt:
      if (debug) {
        fprintf(stderr, "[%lu] HLT at RIP=0x%lx RAX=0x%lx\n",
                insn_count, (u64)model.zRIP, (u64)model.zGPR.data[0]);
      }
      fprintf(stderr, "sail-x86-system: HLT after %lu instructions, RAX=0x%lx\n",
              insn_count, (u64)model.zGPR.data[0]);
      model.model_fini();
      return 0;

    case x86::Kind_zFault: {
      i64 vec = result.variants.zFault.ztup0;
      u32 err = result.variants.zFault.ztup1;
      fprintf(stderr, "sail-x86-system: fault #%ld (error code 0x%x) at RIP=0x%lx after %lu instructions\n",
              vec, err, (u64)model.zRIP, insn_count);
      model.model_fini();
      return 128 + (int)vec;
    }
    }
  }

  if (debug) {
    fprintf(stderr, "sail-x86-system: exited with code %d after %lu instructions\n",
            model.exit_code, insn_count);
  }

  model.model_fini();
  return model.exit_code;
}

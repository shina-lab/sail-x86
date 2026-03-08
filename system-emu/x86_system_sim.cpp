// System-level x86-64 emulator.
// Loads a Linux kernel via the 64-bit boot protocol and executes it
// using the Sail x86 model with paging and exception delivery.

#include "sail_x86_model.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

static void usage(const char *prog) {
  fprintf(stderr, "Usage: %s [options] <bzImage>\n", prog);
  fprintf(stderr, "Options:\n");
  fprintf(stderr, "  -d          Enable debug trace\n");
  fprintf(stderr, "  -m <MB>     RAM size in MB (default 256)\n");
  fprintf(stderr, "  -a <args>   Kernel command line\n");
  fprintf(stderr, "  -i <file>   Initramfs image\n");
  fprintf(stderr, "  -h          Show this help\n");
}

// Read a file into a malloc'd buffer. Returns size, or 0 on error.
static u8 *read_file(const char *path, size_t *out_size) {
  int fd = open(path, O_RDONLY);
  if (fd < 0) { perror(path); return nullptr; }

  struct stat st;
  if (fstat(fd, &st) < 0) { perror("fstat"); close(fd); return nullptr; }

  u8 *buf = (u8 *)malloc(st.st_size);
  if (!buf) { close(fd); return nullptr; }

  size_t total = 0;
  while (total < (size_t)st.st_size) {
    ssize_t n = read(fd, buf + total, st.st_size - total);
    if (n <= 0) break;
    total += n;
  }
  close(fd);
  *out_size = total;
  return buf;
}

// =========================================================================
// CPU and memory initialization
// =========================================================================

static void init_cpu_state(x86::Model &model) {
  model.model_init();
  model.zinitializze_registers(UNIT);

  model.zsystem_mode = true;
  model.zcur_mode = x86::zLongMode;
  model.zcur_cpl = 0;

  // CR0: PE + ET + NE + WP + PG
  model.zCR0 = (1UL << 0) | (1UL << 4) | (1UL << 5) | (1UL << 16) | (1UL << 31);
  // CR4: PAE + OSFXSR + OSXSAVE
  model.zCR4 = (1UL << 5) | (1UL << 9) | (1UL << 18);
  // EFER: SCE + LME + LMA + NXE
  model.zEFER = (1UL << 0) | (1UL << 8) | (1UL << 10) | (1UL << 11);

  model.zGDTR_base = 0;
  model.zGDTR_limit = 0;
  model.zIDTR_base = 0;
  model.zIDTR_limit = 0;
  model.zLDTR = 0;
  model.zTR = 0;
  model.zTR_base = 0;
  model.zTR_limit = 0;
  model.zFS_BASE = 0;
  model.zGS_BASE = 0;
  model.zKERNEL_GS_BASE = 0;
  model.zCR2 = 0;
  model.zCR3 = 0;

  // Disable interrupts initially
  model.zIF_flag = 0;
  model.zNT = 0;
  model.zRF = 0;
}

// Build identity-mapped page tables using 2MB pages.
static u64 setup_identity_page_tables(PhysicalMemory &mem, u64 ram_size) {
  const u64 pml4_addr = 0x70000;  // Use high area to avoid conflicts
  const u64 pdpt_addr = 0x71000;
  const u64 pd_base   = 0x72000;

  u64 num_gb = (ram_size + (1ULL << 30) - 1) >> 30;
  if (num_gb > 512) num_gb = 512;

  // PML4[0] -> PDPT
  mem.write64(pml4_addr, pdpt_addr | 0x03);

  for (u64 i = 0; i < num_gb; i++) {
    u64 pd_addr = pd_base + i * 0x1000;
    mem.write64(pdpt_addr + i * 8, pd_addr | 0x03);
    for (u64 j = 0; j < 512; j++) {
      u64 phys = (i << 30) | (j << 21);
      if (phys >= ram_size) break;
      mem.write64(pd_addr + j * 8, phys | 0x83); // PS=1, Present, R/W
    }
  }

  return pml4_addr;
}

// Set up a minimal GDT for the 64-bit boot protocol.
// Linux expects: CS at selector 0x10 (code64), DS/ES/SS at 0x18 (data).
static u64 setup_gdt(PhysicalMemory &mem) {
  const u64 gdt_addr = 0x60000;

  // GDT[0] = null descriptor
  mem.write64(gdt_addr + 0x00, 0);
  mem.write64(gdt_addr + 0x08, 0);

  // GDT[2] (selector 0x10) = 64-bit code segment
  // Base=0, Limit=0xFFFFF, G=1, L=1 (long mode), P=1, DPL=0, Type=Execute/Read
  // Bytes: 00 00 | 00 00 | 00 | 9A | AF | 00
  // As u64 little-endian:
  mem.write64(gdt_addr + 0x10, 0x00AF9A000000FFFFULL);

  // GDT[3] (selector 0x18) = 64-bit data segment
  // Base=0, Limit=0xFFFFF, G=1, DB=1, P=1, DPL=0, Type=Read/Write
  // Bytes: 00 00 | 00 00 | 00 | 92 | CF | 00
  mem.write64(gdt_addr + 0x18, 0x00CF92000000FFFFULL);

  return gdt_addr;
}

// =========================================================================
// Linux 64-bit boot protocol
// =========================================================================

// setup_header offsets within boot_params (boot_params starts at offset 0,
// setup_header starts at offset 0x1F1 within boot_params).
struct SetupHeader {
  u8 setup_sects;      // 0x1F1
  u16 root_flags;      // 0x1F2
  u32 syssize;         // 0x1F4
  u16 ram_size;        // 0x1F8 (obsolete)
  u16 vid_mode;        // 0x1FA
  u16 root_dev;        // 0x1FC
  u16 boot_flag;       // 0x1FE
  // ... at 0x202: "HdrS" magic
  u16 header;          // 0x202
  u16 version;         // 0x206
  // ... many more fields
};

static bool load_bzimage(x86::Model &model, const char *path,
                         const char *cmdline, const char *initrd_path,
                         bool debug) {
  size_t bzimage_size;
  u8 *bzimage = read_file(path, &bzimage_size);
  if (!bzimage) return false;

  if (bzimage_size < 0x300) {
    fprintf(stderr, "bzImage too small\n");
    free(bzimage);
    return false;
  }

  // Verify magic "HdrS" at offset 0x202
  if (memcmp(bzimage + 0x202, "HdrS", 4) != 0) {
    fprintf(stderr, "Not a valid bzImage (missing HdrS magic)\n");
    free(bzimage);
    return false;
  }

  u16 protocol_version = *(u16 *)(bzimage + 0x206);
  if (debug)
    fprintf(stderr, "Boot protocol version: %d.%d\n",
            protocol_version >> 8, protocol_version & 0xFF);

  if (protocol_version < 0x020C) {
    fprintf(stderr, "Boot protocol version %d.%d too old (need >= 2.12)\n",
            protocol_version >> 8, protocol_version & 0xFF);
    free(bzimage);
    return false;
  }

  // Read setup_sects
  u8 setup_sects = bzimage[0x1F1];
  if (setup_sects == 0) setup_sects = 4;
  u64 setup_size = (setup_sects + 1) * 512;
  u64 kernel_offset = setup_size;
  u64 kernel_size = bzimage_size - kernel_offset;

  // Read preferred load address and init_size
  u64 pref_address = *(u64 *)(bzimage + 0x258);
  u32 init_size = *(u32 *)(bzimage + 0x260);

  // Check xloadflags for 64-bit support
  u16 xloadflags = *(u16 *)(bzimage + 0x236);
  if (!(xloadflags & 0x01)) {
    fprintf(stderr, "Kernel does not support 64-bit handoff\n");
    free(bzimage);
    return false;
  }

  if (debug) {
    fprintf(stderr, "  setup_sects=%d, kernel at offset 0x%lx (%lu bytes)\n",
            setup_sects, kernel_offset, kernel_size);
    fprintf(stderr, "  pref_address=0x%lx, init_size=0x%x\n", pref_address, init_size);
  }

  // Load protected-mode kernel at preferred address
  u64 kernel_addr = pref_address;
  if (kernel_addr + kernel_size > model.phys_mem.ram_size()) {
    fprintf(stderr, "Kernel doesn't fit in RAM (need 0x%lx, have 0x%lx)\n",
            kernel_addr + kernel_size, model.phys_mem.ram_size());
    free(bzimage);
    return false;
  }
  model.phys_mem.write_bytes(kernel_addr, bzimage + kernel_offset, kernel_size);

  // Set up boot_params at 0x10000 (the "zero page")
  const u64 boot_params_addr = 0x10000;
  // Zero it first
  u8 zeros[4096] = {};
  model.phys_mem.write_bytes(boot_params_addr, zeros, 4096);

  // Copy setup_header from bzImage into boot_params
  // setup_header starts at bzImage offset 0x1F1, length from 0x1F1 to end of header
  u8 hdr_len = bzimage[0x201];  // setup header length byte at 0x201
  if (hdr_len == 0) hdr_len = 0x28; // Fallback for old kernels
  // The header at 0x0202 has sentinel byte at 0x0201
  // Copy from 0x1F1 to 0x1F1 + min(hdr_len + 0x11, available)
  u64 copy_start = 0x1F1;
  u64 copy_len = hdr_len + 0x11;  // sentinel + rest of header
  if (copy_start + copy_len > setup_size) copy_len = setup_size - copy_start;
  if (copy_len > 0x100) copy_len = 0x100; // Safety limit
  model.phys_mem.write_bytes(boot_params_addr + 0x1F1,
                             bzimage + 0x1F1, copy_len);

  // Set type_of_loader (0xFF = unknown bootloader)
  model.phys_mem.write8(boot_params_addr + 0x210, 0xFF);

  // Set loadflags: CAN_USE_HEAP (bit 7) + LOADED_HIGH (bit 0, already set)
  u8 loadflags = model.phys_mem.read8(boot_params_addr + 0x211);
  loadflags |= 0x80; // CAN_USE_HEAP
  model.phys_mem.write8(boot_params_addr + 0x211, loadflags);

  // Set up command line
  const u64 cmdline_addr = 0x20000;
  if (cmdline && strlen(cmdline) > 0) {
    model.phys_mem.write_bytes(cmdline_addr, cmdline, strlen(cmdline) + 1);
  } else {
    // Default: earlycon for serial output, no quiet
    const char *default_cmdline = "earlyprintk=serial,0x3f8 console=ttyS0 nokaslr norandmaps";
    model.phys_mem.write_bytes(cmdline_addr, default_cmdline, strlen(default_cmdline) + 1);
  }
  model.phys_mem.write32(boot_params_addr + 0x228, (u32)cmdline_addr);

  // Load initramfs if provided
  if (initrd_path) {
    size_t initrd_size;
    u8 *initrd = read_file(initrd_path, &initrd_size);
    if (!initrd) {
      fprintf(stderr, "Failed to load initramfs: %s\n", initrd_path);
      free(bzimage);
      return false;
    }
    // Place initrd high in memory
    u64 initrd_addr = (model.phys_mem.ram_size() - initrd_size) & ~0xFFFULL;
    model.phys_mem.write_bytes(initrd_addr, initrd, initrd_size);
    model.phys_mem.write32(boot_params_addr + 0x218, (u32)initrd_addr);
    model.phys_mem.write32(boot_params_addr + 0x21C, (u32)initrd_size);
    if (debug)
      fprintf(stderr, "  initrd at 0x%lx (%zu bytes)\n", initrd_addr, initrd_size);
    free(initrd);
  }

  // Set up E820 memory map
  // E820 entries at boot_params + 0x2D0, count at boot_params + 0x1E8
  struct E820Entry {
    u64 addr;
    u64 size;
    u32 type;
  } __attribute__((packed));

  u64 ram_size = model.phys_mem.ram_size();
  E820Entry entries[] = {
    { 0x00000000, 0x0009FC00, 1 }, // Usable (below 640K)
    { 0x0009FC00, 0x00000400, 2 }, // Reserved (EBDA)
    { 0x000E0000, 0x00020000, 2 }, // Reserved (BIOS ROM)
    { 0x00100000, ram_size - 0x100000, 1 }, // Usable (above 1MB)
    { 0xFEC00000, 0x00010000, 2 }, // Reserved (I/O APIC)
    { 0xFEE00000, 0x00010000, 2 }, // Reserved (Local APIC)
  };
  int num_entries = sizeof(entries) / sizeof(entries[0]);
  for (int i = 0; i < num_entries; i++) {
    u64 off = boot_params_addr + 0x2D0 + i * 20;
    model.phys_mem.write64(off, entries[i].addr);
    model.phys_mem.write64(off + 8, entries[i].size);
    model.phys_mem.write32(off + 16, entries[i].type);
  }
  model.phys_mem.write8(boot_params_addr + 0x1E8, num_entries);

  // Set up GDT
  u64 gdt_addr = setup_gdt(model.phys_mem);
  model.zGDTR_base = gdt_addr;
  model.zGDTR_limit = 0x1F; // 4 entries

  // Set segment registers as boot protocol requires
  // CS = 0x10 (__BOOT_CS), DS = ES = SS = 0x18 (__BOOT_DS)
  model.zSegReg.data[1] = 0x10;  // CS
  model.zSegReg.data[0] = 0x18;  // ES
  model.zSegReg.data[2] = 0x18;  // SS
  model.zSegReg.data[3] = 0x18;  // DS
  model.zSegReg.data[4] = 0;     // FS
  model.zSegReg.data[5] = 0;     // GS

  // Set entry point: kernel_addr + 0x200 (startup_64)
  model.zRIP = kernel_addr + 0x200;

  // RSI = physical address of boot_params
  for (int i = 0; i < 16; i++) model.zGPR.data[i] = 0;
  model.zGPR.data[6] = boot_params_addr;  // RSI

  if (debug) {
    fprintf(stderr, "  entry_point=0x%lx, boot_params=0x%lx\n",
            (u64)model.zRIP, boot_params_addr);
  }

  free(bzimage);
  return true;
}

// =========================================================================
// Main emulation loop
// =========================================================================

int main(int argc, char *argv[]) {
  bool debug = false;
  u64 ram_mb = 256;
  const char *cmdline = nullptr;
  const char *initrd_path = nullptr;
  const char *bzimage_path = nullptr;
  int first_arg = 1;

  while (first_arg < argc && argv[first_arg][0] == '-') {
    if (strcmp(argv[first_arg], "-d") == 0) {
      debug = true;
      first_arg++;
    } else if (strcmp(argv[first_arg], "-m") == 0 && first_arg + 1 < argc) {
      ram_mb = atoi(argv[first_arg + 1]);
      first_arg += 2;
    } else if (strcmp(argv[first_arg], "-a") == 0 && first_arg + 1 < argc) {
      cmdline = argv[first_arg + 1];
      first_arg += 2;
    } else if (strcmp(argv[first_arg], "-i") == 0 && first_arg + 1 < argc) {
      initrd_path = argv[first_arg + 1];
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

  if (first_arg >= argc) {
    usage(argv[0]);
    return 1;
  }
  bzimage_path = argv[first_arg];

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

  fprintf(stderr, "sail-x86-system: loading %s\n", bzimage_path);

  if (!load_bzimage(model, bzimage_path, cmdline, initrd_path, debug)) {
    fprintf(stderr, "Failed to load kernel image\n");
    return 1;
  }

  fprintf(stderr, "sail-x86-system: RAM=%luMB, entry=0x%lx\n",
          ram_mb, (u64)model.zRIP);

  bool trampoline_dumped = false;

  u64 insn_count = 0;
  x86::zExecutionResult result = {};
  result.kind = x86::Kind_zOk;
  result.variants.zOk = UNIT;

  // PIT timer: tick every N instructions to generate periodic interrupts
  const u64 PIT_TICK_INTERVAL = 100000; // Tick PIT every 100K instructions
  u64 next_pit_tick = PIT_TICK_INTERVAL;

  while (!model.should_exit) {
    if (debug && !trampoline_dumped && (u64)model.zRIP < 0x100000 && (u64)model.zRIP >= 0x9e000) {
      trampoline_dumped = true;
      fprintf(stderr, "Trampoline bytes at 0x9e000 (dumped at insn %lu):\n", insn_count);
      for (int i = 0; i < 128; i += 16) {
        fprintf(stderr, "  %05x:", 0x9e000 + i);
        for (int j = 0; j < 16; j++)
          fprintf(stderr, " %02x", model.phys_mem.read8(0x9e000 + i + j));
        fprintf(stderr, "\n");
      }
    }
    if (debug && (insn_count < 50 || insn_count > 820)) {
      const char *mode_str = (model.zcur_mode == x86::zLongMode) ? "L" :
                             (model.zcur_mode == x86::zProtectedMode) ? "P" : "?";
      fprintf(stderr, "[%lu] RIP=0x%lx RSP=0x%lx mode=%s CR0=0x%lx CR3=0x%lx\n",
              insn_count, (u64)model.zRIP,
              (u64)model.zGPR.data[4], mode_str,
              (u64)model.zCR0, (u64)model.zCR3);
    }

    model.zstep(&result, UNIT);

    switch (result.kind) {
    case x86::Kind_zOk:
      insn_count++;
      break;

    case x86::Kind_zHalt:
      // HLT: in system mode, wait for interrupt then continue
      if (model.zsystem_mode) {
        // Tick the PIT to generate a timer interrupt
        if (model.pit.tick(1000)) {
          model.pic_master.raise_irq(0); // IRQ 0 = timer
        }
        insn_count++;
        result.kind = x86::Kind_zOk; // Continue execution
        continue;
      }
      fprintf(stderr, "sail-x86-system: HLT after %lu instructions\n", insn_count);
      model.model_fini();
      return 0;

    case x86::Kind_zFault: {
      i64 vec = result.variants.zFault.ztup0;
      u32 err = result.variants.zFault.ztup1;
      fprintf(stderr, "\nsail-x86-system: FATAL fault #%ld (err=0x%x) at RIP=0x%lx after %lu insns\n",
              vec, err, (u64)model.zRIP, insn_count);
      fprintf(stderr, "  RAX=0x%lx RBX=0x%lx RCX=0x%lx RDX=0x%lx\n",
              (u64)model.zGPR.data[0], (u64)model.zGPR.data[3],
              (u64)model.zGPR.data[1], (u64)model.zGPR.data[2]);
      fprintf(stderr, "  RSP=0x%lx RBP=0x%lx RSI=0x%lx RDI=0x%lx\n",
              (u64)model.zGPR.data[4], (u64)model.zGPR.data[5],
              (u64)model.zGPR.data[6], (u64)model.zGPR.data[7]);
      fprintf(stderr, "  CR0=0x%lx CR3=0x%lx CR4=0x%lx EFER=0x%lx\n",
              (u64)model.zCR0, (u64)model.zCR3,
              (u64)model.zCR4, (u64)model.zEFER);
      model.model_fini();
      return 128 + (int)vec;
    }
    }

    // Periodic PIT tick
    if (insn_count >= next_pit_tick) {
      if (model.pit.tick(100)) {
        model.pic_master.raise_irq(0);
      }
      next_pit_tick = insn_count + PIT_TICK_INTERVAL;
    }
  }

  fprintf(stderr, "sail-x86-system: exited after %lu instructions\n", insn_count);
  model.model_fini();
  return model.exit_code;
}

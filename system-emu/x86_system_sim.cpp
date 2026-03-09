// System-level x86-64 emulator.
// Loads a Linux kernel via the 64-bit boot protocol and executes it
// using the Sail x86 model with paging and exception delivery.

#include "sail_x86_model.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>
#include <sys/stat.h>
#include <termios.h>

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
// Terminal raw mode for interactive console
// =========================================================================

static struct termios orig_termios;
static bool termios_saved = false;

static void restore_terminal() {
  if (termios_saved)
    tcsetattr(STDIN_FILENO, TCSANOW, &orig_termios);
}

// Put terminal in raw mode: disable echo, line buffering, and signal chars.
// Returns true if stdin is a terminal and was configured.
static bool setup_raw_terminal() {
  if (!isatty(STDIN_FILENO)) return false;

  if (tcgetattr(STDIN_FILENO, &orig_termios) < 0) return false;
  termios_saved = true;
  atexit(restore_terminal);

  struct termios raw = orig_termios;
  raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
  raw.c_oflag &= ~(OPOST);
  raw.c_cflag |= CS8;
  raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
  raw.c_cc[VMIN] = 0;   // Non-blocking
  raw.c_cc[VTIME] = 0;
  tcsetattr(STDIN_FILENO, TCSANOW, &raw);

  // Also set stdin non-blocking for poll()
  int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
  fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);

  return true;
}

// UART output callback: write TX characters to stdout (not stderr)
// so that the guest console works as an interactive terminal.
static void uart_output_stdout(u8 ch) {
  (void)!write(STDOUT_FILENO, &ch, 1);
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

  // Debug registers: DR0-DR3 = 0, DR6 = 0xFFFF0FF0 (SDM reset), DR7 = 0x400
  model.zDR0 = 0;
  model.zDR1 = 0;
  model.zDR2 = 0;
  model.zDR3 = 0;
  model.zDR6 = 0xFFFF0FF0;
  model.zDR7 = 0x00000400;

  // Disable interrupts initially
  model.zIF_flag = 0;
  model.zNT = 0;
  model.zRF = 0;
}

// Build identity-mapped page tables using 2MB pages.
// If map_kernel_virt is true, also map 0xFFFFFFFF80000000+ to physical 0+
// (the kernel direct mapping used by vmlinux).
static u64 setup_identity_page_tables(PhysicalMemory &mem, u64 ram_size,
                                       bool map_kernel_virt = false) {
  const u64 pml4_addr = 0x70000;
  const u64 pdpt_addr = 0x71000;
  const u64 pd_base   = 0x72000;

  u64 num_gb = (ram_size + (1ULL << 30) - 1) >> 30;
  if (num_gb > 512) num_gb = 512;

  // Zero the PML4
  for (int i = 0; i < 512; i++)
    mem.write64(pml4_addr + i * 8, 0);

  // PML4[0] -> PDPT (identity map low memory)
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

  if (map_kernel_virt) {
    // Map 0xFFFFFFFF80000000 - 0xFFFFFFFFFFFFFFFF (top 2GB) to physical 0+
    // PML4[511] -> kernel PDPT
    const u64 kpdpt_addr = 0x7A000;
    mem.write64(pml4_addr + 511 * 8, kpdpt_addr | 0x03);

    // Zero the kernel PDPT
    for (int i = 0; i < 512; i++)
      mem.write64(kpdpt_addr + i * 8, 0);

    // PDPT[510] and PDPT[511] map the top 2GB (0xFFFFFFFF80000000+)
    // PDPT[510] -> 2MB pages for 0xFFFFFFFF80000000 (phys 0x00000000)
    // PDPT[511] -> 2MB pages for 0xFFFFFFFFC0000000 (phys 0x40000000)
    const u64 kpd_510 = 0x7B000;
    const u64 kpd_511 = 0x7C000;
    mem.write64(kpdpt_addr + 510 * 8, kpd_510 | 0x03);
    mem.write64(kpdpt_addr + 511 * 8, kpd_511 | 0x03);

    for (u64 j = 0; j < 512; j++) {
      u64 phys = j << 21; // 0x00000000 + j*2MB
      if (phys < ram_size)
        mem.write64(kpd_510 + j * 8, phys | 0x83);
      phys = (1ULL << 30) + (j << 21); // 0x40000000 + j*2MB
      if (phys < ram_size)
        mem.write64(kpd_511 + j * 8, phys | 0x83);
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
// ELF vmlinux loader — load uncompressed kernel directly
// =========================================================================

// Minimal ELF64 structures (avoiding <elf.h> which may conflict with project types)
struct Elf64Hdr {
  u8  e_ident[16];
  u16 e_type, e_machine;
  u32 e_version;
  u64 e_entry, e_phoff, e_shoff;
  u32 e_flags;
  u16 e_ehsize, e_phentsize, e_phnum, e_shentsize, e_shnum, e_shstrndx;
};

struct Elf64Phdr {
  u32 p_type, p_flags;
  u64 p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align;
};

static bool is_elf64(const u8 *data, size_t size) {
  if (size < sizeof(Elf64Hdr)) return false;
  return data[0] == 0x7F && data[1] == 'E' && data[2] == 'L' && data[3] == 'F'
    && data[4] == 2; // ELFCLASS64
}

static bool load_elf_kernel(x86::Model &model, const char *path,
                            const char *cmdline, const char *initrd_path,
                            bool debug) {
  size_t file_size;
  u8 *file_data = read_file(path, &file_size);
  if (!file_data) return false;

  if (!is_elf64(file_data, file_size)) {
    free(file_data);
    return false;
  }

  auto *ehdr = (Elf64Hdr *)file_data;
  u64 entry = ehdr->e_entry;

  if (debug)
    fprintf(stderr, "ELF: entry=0x%lx, %d program headers\n",
            entry, ehdr->e_phnum);

  // Load LOAD segments at their physical addresses
  for (int i = 0; i < ehdr->e_phnum; i++) {
    auto *phdr = (Elf64Phdr *)(file_data + ehdr->e_phoff + i * ehdr->e_phentsize);
    if (phdr->p_type != 1 /*PT_LOAD*/) continue;

    u64 paddr = phdr->p_paddr;
    u64 filesz = phdr->p_filesz;
    u64 memsz = phdr->p_memsz;

    if (debug)
      fprintf(stderr, "  LOAD: vaddr=0x%lx paddr=0x%lx filesz=0x%lx memsz=0x%lx\n",
              (u64)phdr->p_vaddr, paddr, filesz, memsz);

    if (paddr + memsz > model.phys_mem.ram_size()) {
      fprintf(stderr, "ELF segment doesn't fit in RAM (paddr=0x%lx, memsz=0x%lx)\n",
              paddr, memsz);
      free(file_data);
      return false;
    }

    // Copy file data
    if (filesz > 0)
      model.phys_mem.write_bytes(paddr, file_data + phdr->p_offset, filesz);
    // Zero BSS (memsz > filesz)
    if (memsz > filesz) {
      u64 bss_size = memsz - filesz;
      u8 *zeros = (u8 *)calloc(1, bss_size);
      model.phys_mem.write_bytes(paddr + filesz, zeros, bss_size);
      free(zeros);
    }
  }

  // Set up boot_params at 0x10000
  const u64 boot_params_addr = 0x10000;
  u8 zeros[4096] = {};
  model.phys_mem.write_bytes(boot_params_addr, zeros, 4096);

  // Command line
  const u64 cmdline_addr = 0x20000;
  if (cmdline && strlen(cmdline) > 0) {
    model.phys_mem.write_bytes(cmdline_addr, cmdline, strlen(cmdline) + 1);
  } else {
    const char *default_cmdline = "earlyprintk=serial,0x3f8 console=ttyS0 nokaslr norandmaps";
    model.phys_mem.write_bytes(cmdline_addr, default_cmdline, strlen(default_cmdline) + 1);
  }
  model.phys_mem.write32(boot_params_addr + 0x228, (u32)cmdline_addr);

  // E820 memory map
  u64 ram_size = model.phys_mem.ram_size();
  struct E820Entry {
    u64 addr; u64 size; u32 type;
  } __attribute__((packed));

  E820Entry entries[] = {
    { 0x00000000, 0x0009FC00, 1 },
    { 0x0009FC00, 0x00000400, 2 },
    { 0x000E0000, 0x00020000, 2 },
    { 0x00100000, ram_size - 0x100000, 1 },
    { 0xFEC00000, 0x00010000, 2 },
    { 0xFEE00000, 0x00010000, 2 },
  };
  int num_entries = sizeof(entries) / sizeof(entries[0]);
  for (int i = 0; i < num_entries; i++) {
    u64 off = boot_params_addr + 0x2D0 + i * 20;
    model.phys_mem.write64(off, entries[i].addr);
    model.phys_mem.write64(off + 8, entries[i].size);
    model.phys_mem.write32(off + 16, entries[i].type);
  }
  model.phys_mem.write8(boot_params_addr + 0x1E8, num_entries);

  // Minimal setup_header so the kernel knows it's being booted properly
  // Set type_of_loader
  model.phys_mem.write8(boot_params_addr + 0x210, 0xFF);
  // Set loadflags: LOADED_HIGH | CAN_USE_HEAP
  model.phys_mem.write8(boot_params_addr + 0x211, 0x81);

  // Load initramfs if provided
  if (initrd_path) {
    size_t initrd_size;
    u8 *initrd = read_file(initrd_path, &initrd_size);
    if (!initrd) {
      fprintf(stderr, "Failed to load initramfs: %s\n", initrd_path);
      free(file_data);
      return false;
    }
    // Place initrd high in memory (page-aligned)
    u64 initrd_addr = (model.phys_mem.ram_size() - initrd_size) & ~0xFFFULL;
    model.phys_mem.write_bytes(initrd_addr, initrd, initrd_size);
    model.phys_mem.write32(boot_params_addr + 0x218, (u32)initrd_addr);
    model.phys_mem.write32(boot_params_addr + 0x21C, (u32)initrd_size);
    if (debug)
      fprintf(stderr, "  initrd at 0x%lx (%zu bytes)\n", initrd_addr, initrd_size);
    free(initrd);
  }

  // GDT
  u64 gdt_addr = setup_gdt(model.phys_mem);
  model.zGDTR_base = gdt_addr;
  model.zGDTR_limit = 0x1F;

  // Segments
  model.zSegReg.data[1] = 0x10;  // CS
  model.zSegReg.data[0] = 0x18;  // ES
  model.zSegReg.data[2] = 0x18;  // SS
  model.zSegReg.data[3] = 0x18;  // DS
  model.zSegReg.data[4] = 0;     // FS
  model.zSegReg.data[5] = 0;     // GS

  // The ELF entry point is a physical address (phys_startup_64).
  // startup_64 runs at physical addresses initially, then switches to virtual.
  model.zRIP = entry;

  // RSI = boot_params
  for (int i = 0; i < 16; i++) model.zGPR.data[i] = 0;
  model.zGPR.data[6] = boot_params_addr;  // RSI

  if (debug)
    fprintf(stderr, "  entry_point=0x%lx, boot_params=0x%lx\n",
            entry, boot_params_addr);

  free(file_data);
  return true;
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

  // Auto-detect ELF vs bzImage
  bool is_elf = false;
  {
    int fd = open(bzimage_path, O_RDONLY);
    if (fd >= 0) {
      u8 magic[5];
      if (read(fd, magic, 5) == 5)
        is_elf = (magic[0] == 0x7F && magic[1] == 'E' && magic[2] == 'L'
                  && magic[3] == 'F' && magic[4] == 2 /*ELFCLASS64*/);
      close(fd);
    }
  }

  if (is_elf) {
    // Re-create page tables with kernel virtual mapping
    cr3 = setup_identity_page_tables(model.phys_mem, ram_size, true);
    model.zCR3 = cr3;

    if (!load_elf_kernel(model, bzimage_path, cmdline, initrd_path, debug)) {
      fprintf(stderr, "Failed to load ELF kernel image\n");
      return 1;
    }
  } else {
    if (!load_bzimage(model, bzimage_path, cmdline, initrd_path, debug)) {
      fprintf(stderr, "Failed to load kernel image\n");
      return 1;
    }
  }

  fprintf(stderr, "sail-x86-system: RAM=%luMB, entry=0x%lx\n",
          ram_mb, (u64)model.zRIP);

  // Set up interactive console: raw terminal + UART output to stdout.
  bool interactive = setup_raw_terminal();
  if (interactive) {
    model.uart.output_fn = uart_output_stdout;
    fprintf(stderr, "sail-x86-system: interactive console on stdin/stdout\n");
  } else {
    // Non-tty stdin: set non-blocking so we can still feed piped input to UART
    int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);
  }
  bool poll_stdin = true;  // Always poll stdin for UART RX data

  bool trampoline_dumped = false;

  u64 insn_count = 0;
  x86::zExecutionResult result = {};
  result.kind = x86::Kind_zOk;
  result.variants.zOk = UNIT;

  // PIT timer: tick every N instructions to generate periodic interrupts.
  // The PIT runs at 1.193182 MHz. At ~1M interpreted instructions/sec,
  // 10K instructions ≈ 10ms ≈ 11932 PIT cycles. We tick aggressively
  // so timer-dependent code (calibrate_delay, jiffies) doesn't stall.
  const u64 PIT_TICK_INTERVAL = 10000;  // Tick PIT every 10K instructions
  const u64 PIT_CYCLES_PER_TICK = 11932; // ~10ms worth of PIT cycles
  u64 next_pit_tick = PIT_TICK_INTERVAL;

  // Ctrl+A escape state: when Ctrl+A is pressed, the next key decides the action.
  // Ctrl+A X = quit. Ctrl+A Ctrl+A = send literal Ctrl+A.
  bool ctrl_a_pending = false;

  // Spin loop detector: if RIP stays within a tiny range for too long,
  // the kernel is stuck (e.g., panic delay_loop alternating 2 addresses).
  // Disabled in interactive mode where the idle loop is expected.
  u64 spin_base = 0;
  u64 spin_count = 0;
  u64 spin_total = 0;  // cumulative count across re-entries
  const u64 SPIN_THRESHOLD = interactive ? UINT64_MAX : 10000000;

  while (!model.should_exit) {
    // Print progress every 5M instructions
    if (insn_count % 5000000 == 0 && insn_count > 0) {
      fprintf(stderr, "[progress] %luM insns, RIP=0x%lx\n",
              insn_count / 1000000, (u64)model.zRIP);
    }

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

    // Spin loop detection: if RIP stays within 16 bytes for 10M insns, exit.
    // PIT interrupts briefly leave the range; spin_total accumulates.
    {
      u64 rip = model.zRIP;
      if (rip >= spin_base && rip < spin_base + 16) {
        spin_count++;
        spin_total++;
        if (spin_total >= SPIN_THRESHOLD) {
          fprintf(stderr, "sail-x86-system: spin loop detected at RIP=0x%lx after %lu insns\n",
                  rip, insn_count);
          model.model_fini();
          return 1;
        }
      } else if (spin_count > 1000 && rip != spin_base) {
        // Brief excursion (e.g., interrupt handler) — don't reset total
        spin_count = 0;
      } else {
        spin_base = rip;
        spin_count = 0;
        spin_total = 0;
      }
    }

    switch (result.kind) {
    case x86::Kind_zOk:
      insn_count++;
      break;

    case x86::Kind_zHalt:
      // HLT: in system mode, wait for interrupt then continue
      if (model.zsystem_mode) {
        // If IF=0, this is a panic halt loop — exit
        if (model.zIF_flag == 0) {
          fprintf(stderr, "sail-x86-system: HLT with IF=0 (panic halt) after %lu insns at RIP=0x%lx\n",
                  insn_count, (u64)model.zRIP);
          model.model_fini();
          return 1;
        }
        // Wait for an interrupt: poll stdin + tick PIT until something fires
        while (!model.pic_master.has_pending()) {
          // Poll stdin for input (block briefly with poll())
          if (poll_stdin) {
            struct pollfd pfd = { STDIN_FILENO, POLLIN, 0 };
            if (poll(&pfd, 1, 10 /*ms*/) > 0) {
              u8 buf[64];
              ssize_t n = read(STDIN_FILENO, buf, sizeof(buf));
              for (ssize_t i = 0; n > 0 && i < n; i++) {
                if (ctrl_a_pending) {
                  ctrl_a_pending = false;
                  if (buf[i] == 'x' || buf[i] == 'X') {
                    fprintf(stderr, "\nsail-x86-system: Ctrl+A X — exiting\n");
                    model.model_fini();
                    return 0;
                  }
                  if (buf[i] == 0x01) model.uart.rx_push(0x01);
                  continue;
                }
                if (buf[i] == 0x01) { ctrl_a_pending = true; continue; }
                model.uart.rx_push(buf[i]);
              }
              if (model.uart.has_irq())
                model.pic_master.raise_irq(4);
            }
          }
          // Tick PIT
          if (model.pit.tick(PIT_CYCLES_PER_TICK))
            model.pic_master.raise_irq(0);
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
      fprintf(stderr, "  R8=0x%lx R9=0x%lx R10=0x%lx R11=0x%lx\n",
              (u64)model.zGPR.data[8], (u64)model.zGPR.data[9],
              (u64)model.zGPR.data[10], (u64)model.zGPR.data[11]);
      fprintf(stderr, "  R12=0x%lx R13=0x%lx R14=0x%lx R15=0x%lx\n",
              (u64)model.zGPR.data[12], (u64)model.zGPR.data[13],
              (u64)model.zGPR.data[14], (u64)model.zGPR.data[15]);
      fprintf(stderr, "  CR0=0x%lx CR2=0x%lx CR3=0x%lx CR4=0x%lx EFER=0x%lx\n",
              (u64)model.zCR0, (u64)model.zCR2, (u64)model.zCR3,
              (u64)model.zCR4, (u64)model.zEFER);
      fprintf(stderr, "  IDTR: base=0x%lx limit=0x%x\n",
              (u64)model.zIDTR_base, (u32)model.zIDTR_limit);
      // Dump bytes at RIP
      u64 rip = model.zRIP;
      fprintf(stderr, "  bytes at RIP:");
      for (int b = 0; b < 16; b++) {
        u64 pa = rip + b; // Approximate; should translate
        if (model.phys_mem.in_ram(pa))
          fprintf(stderr, " %02x", model.phys_mem.read8(pa));
      }
      fprintf(stderr, "\n");
      model.model_fini();
      return 128 + (int)vec;
    }
    }

    // Poll stdin for input and feed into UART RX FIFO.
    // Check every 1K instructions to avoid syscall overhead.
    if (poll_stdin && (insn_count & 0x3FF) == 0) {
      u8 buf[64];
      ssize_t n = read(STDIN_FILENO, buf, sizeof(buf));
      if (n == 0) poll_stdin = false;  // EOF on stdin
      for (ssize_t i = 0; n > 0 && i < n; i++) {
        if (ctrl_a_pending) {
          ctrl_a_pending = false;
          if (buf[i] == 'x' || buf[i] == 'X') {
            fprintf(stderr, "\nsail-x86-system: Ctrl+A X — exiting\n");
            model.should_exit = true;
            break;
          }
          if (buf[i] == 0x01) { // Ctrl+A Ctrl+A = literal Ctrl+A
            model.uart.rx_push(0x01);
          }
          // Other Ctrl+A sequences: ignore
          continue;
        }
        if (buf[i] == 0x01) {
          ctrl_a_pending = true;
          continue;
        }
        model.uart.rx_push(buf[i]);
      }
    }

    // Periodic PIT tick
    if (insn_count >= next_pit_tick) {
      if (model.pit.tick(PIT_CYCLES_PER_TICK)) {
        model.pic_master.raise_irq(0);
      }
      next_pit_tick = insn_count + PIT_TICK_INTERVAL;
    }

    // UART interrupt (IRQ 4): RDA or THRE
    if (model.uart.has_irq()) {
      model.pic_master.raise_irq(4);
    }
  }

  fprintf(stderr, "sail-x86-system: exited after %lu instructions\n", insn_count);
  model.model_fini();
  return model.exit_code;
}

/// System-level x86-64 emulator.
// Loads a Linux bzImage and boots from real mode, letting the kernel's
// own 16-bit setup code handle the real → protected → long mode transition.

#include "sail_x86_model.h"
#include "x86-helpers.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>
#include <sys/stat.h>
#include <termios.h>
#include <csignal>
#include <locale.h>
#include <wchar.h>
#include <curses.h>
#include <term.h>

enum DisplayMode { DISPLAY_SERIAL, DISPLAY_VGA };

static u64 parse_env_u64(const char *name, u64 default_value) {
  const char *s = getenv(name);
  if (!s || !*s) return default_value;
  char *end = nullptr;
  unsigned long long v = strtoull(s, &end, 0);
  if (!end || *end != '\0') {
    fprintf(stderr, "sail-x86-system: ignoring invalid %s=%s\n", name, s);
    return default_value;
  }
  return (u64)v;
}

template <typename Bits>
static void dump_bits_hex(FILE *out, const Bits &bits, int n_words) {
  const size_t nbytes = (size_t)n_words * 8;
  uint8_t bytes[64] = {};
  if (nbytes > sizeof(bytes)) {
    fprintf(out, "<bits-too-wide>");
    return;
  }
  x86::bits_to_bytes(bits, bytes, nbytes);
  for (size_t i = nbytes; i > 0; i--) {
    fprintf(out, "%02x", bytes[i - 1]);
  }
}

static void dump_registers(FILE *out, u64 insn_count, const x86::Model &model) {
  const char *mode_str = (model.zcur_mode == x86::zLongMode) ? "L" :
                         (model.zcur_mode == x86::zProtectedMode) ? "P" :
                         (model.zcur_mode == x86::zRealMode) ? "R" : "C";
  if (model.zcur_mode == x86::zLongMode) {
    fprintf(out, "[%lu] RIP=%016lx mode=%s\n",
            insn_count, (u64)model.zRIP, mode_str);
  } else {
    fprintf(out, "[%lu] CS:RIP=%04x:%08lx mode=%s\n",
            insn_count,
            (u16)model.zSegReg.data[x86::SEG_CS],
            (u64)model.zRIP,
            mode_str);
  }

  fprintf(out, "  RAX=%016lx RBX=%016lx RCX=%016lx RDX=%016lx\n",
          (u64)model.zGPR.data[0], (u64)model.zGPR.data[3],
          (u64)model.zGPR.data[1], (u64)model.zGPR.data[2]);
  fprintf(out, "  RSP=%016lx RBP=%016lx RSI=%016lx RDI=%016lx\n",
          (u64)model.zGPR.data[4], (u64)model.zGPR.data[5],
          (u64)model.zGPR.data[6], (u64)model.zGPR.data[7]);
  fprintf(out, "  R8 =%016lx R9 =%016lx R10=%016lx R11=%016lx\n",
          (u64)model.zGPR.data[8], (u64)model.zGPR.data[9],
          (u64)model.zGPR.data[10], (u64)model.zGPR.data[11]);
  fprintf(out, "  R12=%016lx R13=%016lx R14=%016lx R15=%016lx\n",
          (u64)model.zGPR.data[12], (u64)model.zGPR.data[13],
          (u64)model.zGPR.data[14], (u64)model.zGPR.data[15]);
  fprintf(out, "  K0 =%016lx K1 =%016lx K2 =%016lx K3 =%016lx\n",
          (u64)model.zKREG.data[0], (u64)model.zKREG.data[1],
          (u64)model.zKREG.data[2], (u64)model.zKREG.data[3]);
  fprintf(out, "  K4 =%016lx K5 =%016lx K6 =%016lx K7 =%016lx\n",
          (u64)model.zKREG.data[4], (u64)model.zKREG.data[5],
          (u64)model.zKREG.data[6], (u64)model.zKREG.data[7]);
  fprintf(out, "  YMM16=");
  dump_bits_hex(out, model.zZMM.data[16], 4);
  fprintf(out, "\n");
  fprintf(out, "  CS=%04x DS=%04x ES=%04x SS=%04x FS=%04x GS=%04x\n",
          (u16)model.zSegReg.data[x86::SEG_CS],
          (u16)model.zSegReg.data[x86::SEG_DS],
          (u16)model.zSegReg.data[x86::SEG_ES],
          (u16)model.zSegReg.data[x86::SEG_SS],
          (u16)model.zSegReg.data[x86::SEG_FS],
          (u16)model.zSegReg.data[x86::SEG_GS]);
  fprintf(out,
          "  FLAGS CF=%u PF=%u AF=%u ZF=%u SF=%u OF=%u DF=%u IF=%u\n",
          (unsigned)model.zCF, (unsigned)model.zPF, (unsigned)model.zAF,
          (unsigned)model.zZF, (unsigned)model.zSF, (unsigned)model.zOF,
          (unsigned)model.zDF, (unsigned)model.zIF_flag);
  fprintf(out, "  CR0=%016lx CR2=%016lx CR3=%016lx CR4=%016lx EFER=%016lx\n",
          (u64)model.zCR0, (u64)model.zCR2, (u64)model.zCR3,
          (u64)model.zCR4, (u64)model.zEFER);
}

static void usage(const char *prog) {
  fprintf(stderr, "Usage: %s [options] <bzImage>\n", prog);
  fprintf(stderr, "       %s [options] -b <bios.bin> [-hda <disk.img>] [-cdrom <image.iso>]\n", prog);
  fprintf(stderr, "Options:\n");
  fprintf(stderr, "  -d              Enable debug trace\n");
  fprintf(stderr, "  -m <MB>         RAM size in MB (default 256)\n");
  fprintf(stderr, "  -ips <N>        Virtual CPU speed, million instructions per emulated second\n");
  fprintf(stderr, "                  (default 1; a kernel with HZ=1000 needs 20 or more)\n");
  fprintf(stderr, "  -a <args>       Kernel command line\n");
  fprintf(stderr, "  -i <file>       Initramfs image\n");
  fprintf(stderr, "  -vga            Use VGA text mode display (default: serial)\n");
  fprintf(stderr, "  -b <file>       BIOS ROM image (e.g., SeaBIOS bios.bin)\n");
  fprintf(stderr, "  -hdb <file>     Hard disk image (primary IDE slave)\n");
  fprintf(stderr, "  Ctrl-a s / Ctrl-a k           Route subsequent stdin to serial / keyboard\n");
  fprintf(stderr, "  Ctrl-a u/d/l/r, Ctrl-a 1..0   Keyboard arrows and F1..F10\n");
  fprintf(stderr, "  -kbd            Route stdin to the PS/2 keyboard (headless BIOS interaction)\n");
  fprintf(stderr, "  -hda <file>     Hard disk image (primary IDE master)\n");
  fprintf(stderr, "  -cdrom <file>   CD-ROM ISO image (secondary IDE master)\n");
  fprintf(stderr, "  -boot <order>   BIOS boot order: a floppy, c hard disk, d CD-ROM\n");
  fprintf(stderr, "                  (default: d when a CD-ROM is attached, else the BIOS order)\n");
  fprintf(stderr, "  -fda <file>     Floppy disk image (drive A:)\n");
  fprintf(stderr, "  -h              Show this help\n");
  fprintf(stderr, "Env:\n");
  fprintf(stderr, "  SAIL_X86_TRACE_START          Start instruction count for register dumps\n");
  fprintf(stderr, "  SAIL_X86_TRACE_END            End instruction count; emulator exits at this count\n");
  fprintf(stderr, "  SAIL_X86_TRACE_STEP           Dump every N instructions within the trace window\n");
  fprintf(stderr, "  SAIL_X86_PROBE_INSN           One-shot diagnostic probe at an instruction count\n");
  fprintf(stderr, "  SAIL_X86_TRACE_PHYS_WRITE     Log phys writes overlapping this address (hex/dec)\n");
  fprintf(stderr, "  SAIL_X86_DETERMINISTIC_RDRAND Replace RDRAND/RDSEED with splitmix64(seed)\n");
  fprintf(stderr, "  SAIL_X86_BIOS_DEBUG           Echo the firmware debug port (0x402) to stderr\n");
  fprintf(stderr, "Signals:\n");
  fprintf(stderr, "  SIGUSR2                       Save graphics to framebuffer.png (SAIL_X86_FRAMEBUFFER overrides)\n");
  fprintf(stderr, "  SIGUSR1                       Dump CPU and interrupt-controller state to stderr, continue\n");
  fprintf(stderr, "  SAIL_X86_TRACE_REAL_UD=1       Dump recent execution on real-mode vector-6 handler entry\n");
  fprintf(stderr, "  SAIL_X86_TRACE_ADDRESS        Dump recent execution once at this linear code address\n");
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
  // Keep OPOST enabled so \n→\r\n translation works for stderr messages.
  // The kernel's serial output already sends \r\n through the UART.
  raw.c_cflag |= CS8;
  raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
  raw.c_cc[VMIN] = 0;   // Return immediately even if no data
  raw.c_cc[VTIME] = 0;
  tcsetattr(STDIN_FILENO, TCSANOW, &raw);

  // Don't set O_NONBLOCK on TTYs — VMIN=0/VTIME=0 already provides
  // non-blocking behavior, and O_NONBLOCK causes read() to return 0
  // (indistinguishable from EOF) when no data is available.

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

// Initialize CPU in real mode.
static void init_cpu_state(x86::Model &model) {
  model.model_init();
  model.zinitializze_registers(UNIT);
  enable_all_features(model);

  model.zsystem_mode = true;
  model.zcur_mode = x86::zRealMode;
  model.zcur_cpl = 0;

  // CR0: no PE, no PG (real mode). ET + NE set.
  model.zCR0 = (1UL << 4) | (1UL << 5);
  model.zCR4 = 0;
  model.zEFER = 0;
  model.zCR2 = 0;
  model.zCR3 = 0;

  // Real mode segment setup: all bases = 0, limits = 0xFFFF
  for (int i = 0; i < 6; i++) {
    model.zSegReg.data[i] = 0;
    model.zSegCache.data[i].zseg_base = 0;
    model.zSegCache.data[i].zseg_limit = 0xFFFF;
    model.zSegCache.data[i].zseg_present = 1;
    model.zSegCache.data[i].zseg_s = 1;
    model.zSegCache.data[i].zseg_type = 0x3;  // data R/W
    model.zSegCache.data[i].zseg_dpl = 0;
    model.zSegCache.data[i].zseg_db = 0;  // 16-bit default
    model.zSegCache.data[i].zseg_l = 0;
    model.zSegCache.data[i].zseg_g = 0;
  }
  // CS type should be code
  model.zSegCache.data[x86::SEG_CS].zseg_type = 0xB;  // code, R, accessed

  model.zGDTR_base = 0;
  model.zGDTR_limit = 0;
  model.zIDTR_base = 0;
  model.zIDTR_limit = 0x3FF;  // Real mode IVT spans 0x0000-0x03FF
  model.zLDTR = 0;
  model.zTR = 0;
  model.zTR_base = 0;
  model.zTR_limit = 0;
  model.zKERNEL_GS_BASE = 0;


  // Disable interrupts
  model.zIF_flag = 0;
  model.zNT = 0;
  model.zRF = 0;

  // Zero GPRs
  for (int i = 0; i < 16; i++)
    model.zGPR.data[i] = 0;

  // Wire keyboard controller A20 gate to Sail register (disabled by default)
  model.kbd.a20_gate = &model.za20_enabled;
}

// Initialize CPU in real mode at the x86 reset vector.
// CS.base = 0xFFFF0000 so that CS:IP = 0xF000:FFF0 → linear 0xFFFFFFF0.
// SeaBIOS's first ljmpw $0xF000, $entry sets CS.base = 0xF0000 (normal real-mode).
static void init_cpu_state_bios(x86::Model &model) {
  init_cpu_state(model);

  // CS selector = 0xF000, but base = 0xFFFF0000 (not sel<<4)
  model.zSegReg.data[x86::SEG_CS] = 0xF000;
  model.zSegCache.data[x86::SEG_CS].zseg_base = 0xFFFF0000;
  model.zSegCache.data[x86::SEG_CS].zseg_limit = 0xFFFF;

  // RIP = 0xFFF0 → first fetch at linear 0xFFFF0000 + 0xFFF0 = 0xFFFFFFF0
  model.zRIP = 0xFFF0;
}

// Load bzImage and set up real-mode boot.
// Per Linux boot protocol (Documentation/arch/x86/boot.rst):
//   1. Load setup code (first setup_sects+1 sectors) to a real-mode segment
//   2. Load protected-mode kernel to 0x100000 (LOAD_HIGH)
//   3. Fill in boot_params fields within the loaded setup image
//   4. Set DS=ES=SS=FS=GS=setup_seg, SP=heap_end
//   5. Jump to setup_seg+0x20:0x0000 (entry is at offset 0x200)
static bool load_bzimage(x86::Model &model, const char *path,
                                   const char *cmdline, const char *initrd_path,
                                   DisplayMode display_mode, bool debug) {
  size_t bzimage_size;
  u8 *bzimage = read_file(path, &bzimage_size);
  if (!bzimage) return false;

  if (bzimage_size < 0x300) {
    fprintf(stderr, "bzImage too small\n");
    free(bzimage);
    return false;
  }

  if (memcmp(bzimage + 0x202, "HdrS", 4) != 0) {
    fprintf(stderr, "Not a valid bzImage (missing HdrS magic)\n");
    free(bzimage);
    return false;
  }

  u16 protocol_version = *(u16 *)(bzimage + 0x206);
  if (debug)
    fprintf(stderr, "Boot protocol version: %d.%d\n",
            protocol_version >> 8, protocol_version & 0xFF);

  if (protocol_version < 0x0202) {
    fprintf(stderr, "Boot protocol version %d.%d too old (need >= 2.02 for real-mode boot)\n",
            protocol_version >> 8, protocol_version & 0xFF);
    free(bzimage);
    return false;
  }

  u8 setup_sects = bzimage[0x1F1];
  if (setup_sects == 0) setup_sects = 4;
  u64 setup_size = (setup_sects + 1) * 512;
  u64 kernel_offset = setup_size;
  u64 kernel_size = bzimage_size - kernel_offset;

  u8 loadflags = bzimage[0x211];
  bool is_bzImage = (loadflags & 0x01);  // LOAD_HIGH
  u64 kernel_addr = is_bzImage ? 0x100000 : 0x10000;

  if (debug) {
    fprintf(stderr, "  setup_sects=%d, setup_size=0x%lx\n", setup_sects, setup_size);
    fprintf(stderr, "  kernel at offset 0x%lx (%lu bytes), load at 0x%lx\n",
            kernel_offset, kernel_size, kernel_addr);
  }

  // Load protected-mode kernel
  if (kernel_addr + kernel_size > model.phys_mem.ram_size()) {
    fprintf(stderr, "Kernel doesn't fit in RAM\n");
    free(bzimage);
    return false;
  }
  model.phys_mem.write_bytes(kernel_addr, bzimage + kernel_offset, kernel_size);

  // Load real-mode setup code at segment 0x1000 (linear 0x10000).
  // Per boot protocol, for version >= 2.02 with LOAD_HIGH, we can
  // load below 0x90000.
  const u64 setup_base = 0x10000;
  const u16 setup_seg = 0x1000;
  model.phys_mem.write_bytes(setup_base, bzimage, setup_size);

  // Fill in boot_params fields in the loaded image.
  // The setup header lives at offset 0x1F1 within the setup code,
  // which is at physical address setup_base + 0x1F1.

  // type_of_loader
  model.phys_mem.write8(setup_base + 0x210, 0xFF);

  // loadflags: set CAN_USE_HEAP
  u8 lf = model.phys_mem.read8(setup_base + 0x211);
  lf |= 0x80;
  model.phys_mem.write8(setup_base + 0x211, lf);

  // heap_end_ptr (relative to setup start): 0xDE00 - 0x200
  model.phys_mem.write16(setup_base + 0x224, 0xDE00 - 0x0200);

  // Command line at setup_base + 0xE000 (within the same 64K segment)
  u64 cmdline_off = 0xE000;
  u64 cmdline_addr = setup_base + cmdline_off;
  const char *default_serial_cmdline =
      "earlyprintk=serial,0x3f8 console=ttyS0 "
      "tsc=reliable nokaslr norandmaps "
      "randomize_kstack_offset=off";
  const char *default_vga_cmdline =
      "console=tty0 tsc=reliable nokaslr norandmaps "
      "randomize_kstack_offset=off";
  const char *default_cmdline = (display_mode == DISPLAY_VGA) ?
                                 default_vga_cmdline : default_serial_cmdline;
  const char *use_cmdline = (cmdline && strlen(cmdline) > 0) ? cmdline : default_cmdline;
  model.phys_mem.write_bytes(cmdline_addr, use_cmdline, strlen(use_cmdline) + 1);
  // cmd_line_ptr: physical address of command line
  model.phys_mem.write32(setup_base + 0x228, (u32)cmdline_addr);

  if (display_mode == DISPLAY_VGA) {
    // vid_mode: NORMAL (0xFFFF) — use whatever mode SeaVGABIOS set up.
    // SeaVGABIOS initializes standard 80x25 text mode with 16-pixel font.
    // Using VIDEO_8POINT (0x0F01) would ask Linux to switch to 80x50 via
    // INT 10h AX=1112h, but that conflicts with what SeaVGABIOS configured.
    model.phys_mem.write16(setup_base + 0x1FA, 0xFFFF);

    // Pre-populate BIOS Data Area (BDA) at 0x400-0x4FF so the setup code's
    // store_mode_params() reads correct VGA 80x25 values into screen_info.
    // SeaVGABIOS will overwrite these during its init, but we set them here
    // as fallback in case the option ROM doesn't load.
    model.phys_mem.write8(0x449, 3);        // Current video mode: 80-col color text
    model.phys_mem.write16(0x44A, 80);      // Number of screen columns
    model.phys_mem.write16(0x44C, 0x1000);  // Video page size (4096 bytes = 80*25*2 + padding)
    model.phys_mem.write16(0x44E, 0);       // Current video page start address
    model.phys_mem.write16(0x450, 0);       // Cursor position for page 0
    model.phys_mem.write16(0x460, 0x0D0E);  // Cursor shape: start=13, end=14 (16px font)
    model.phys_mem.write8(0x462, 0);        // Current video page number
    model.phys_mem.write16(0x463, 0x3D4);   // CRTC port address (color)
    model.phys_mem.write8(0x484, 24);       // Number of rows - 1 (25 rows)
    model.phys_mem.write16(0x485, 16);      // Character height: 16 pixels
  } else {
    // vid_mode: normal (0xFFFF)
    model.phys_mem.write16(setup_base + 0x1FA, 0xFFFF);
  }

  // Load initramfs if provided
  if (initrd_path) {
    size_t initrd_size;
    u8 *initrd = read_file(initrd_path, &initrd_size);
    if (!initrd) {
      fprintf(stderr, "Failed to load initramfs: %s\n", initrd_path);
      free(bzimage);
      return false;
    }
    u64 initrd_addr = (model.phys_mem.ram_size() - initrd_size) & ~0xFFFULL;
    model.phys_mem.write_bytes(initrd_addr, initrd, initrd_size);
    model.phys_mem.write32(setup_base + 0x218, (u32)initrd_addr);
    model.phys_mem.write32(setup_base + 0x21C, (u32)initrd_size);
    if (debug)
      fprintf(stderr, "  initrd at 0x%lx (%zu bytes)\n", initrd_addr, initrd_size);
    free(initrd);
  }

  // E820 memory map: NOT written into the setup image for real-mode boot.
  // The setup code's boot_params overlaps the first sector (0x000-0x1FF),
  // but the E820 table at offset 0x2D0 falls in the CODE section (past
  // offset 0x200). Writing there would corrupt the setup code.
  // Instead, detect_memory() in the setup code will query BIOS (INT 15h).
  // Our IVT stub returns failure, so detect_memory gets 0 entries.
  // The kernel handles this: compressed/misc.c uses mem_avoid_init()
  // and the decompressor can read the E820 table populated later.

  // Set up IVT (Interrupt Vector Table) at 0x0000-0x03FF.
  // All 256 entries point to a single IRET at 0x0400.
  // This makes BIOS INT calls (which the setup code uses for hardware
  // detection) return immediately with no effect.
  model.phys_mem.write8(0x0400, 0xCF);  // IRET at linear 0x0400
  for (int i = 0; i < 256; i++) {
    model.phys_mem.write16(i * 4, 0x0400);      // offset = 0x0400
    model.phys_mem.write16(i * 4 + 2, 0x0000);  // segment = 0x0000
  }

  if (display_mode == DISPLAY_VGA) {
    // INT 10h handler at 0x0500 — provides enough BIOS video services
    // for the Linux setup code's vga_probe() to detect VGA hardware.
    //
    // Functions implemented:
    //   AH=00h: Set Video Mode (no-op, return success)
    //   AH=03h: Get Cursor Position → DH:DL=0:0, CX=0x0E0F
    //   AH=0Fh: Get Video Mode → AL=3 (80x25 color), AH=80, BH=0
    //   AH=12h,BL=10h: Get EGA Info → BL=3 (256K), BH=0 (color)
    //   AH=1Ah: Get Display Combo → AL=0x1A (supported), BL=8 (VGA color)
    static const u8 int10h[] = {
      0x80, 0xFC, 0x0F,             // cmp ah, 0x0F
      0x74, 0x10,                   // je get_mode      (+0x10 → offset 0x15)
      0x80, 0xFC, 0x03,             // cmp ah, 0x03
      0x74, 0x12,                   // je get_cursor    (+0x12 → offset 0x1C)
      0x80, 0xFC, 0x12,             // cmp ah, 0x12
      0x74, 0x13,                   // je ega_info      (+0x13 → offset 0x22)
      0x80, 0xFC, 0x1A,             // cmp ah, 0x1A
      0x74, 0x1A,                   // je display_combo (+0x1A → offset 0x2E)
      0xCF,                         // iret (unhandled functions)
      // get_mode (0x15): AH=0Fh — Get Current Video Mode
      0xB0, 0x03,                   // mov al, 3    (mode 3: 80x25 color)
      0xB4, 0x50,                   // mov ah, 80   (columns)
      0xB7, 0x00,                   // mov bh, 0    (active page)
      0xCF,                         // iret
      // get_cursor (0x1C): AH=03h — Get Cursor Position
      0xB9, 0x0F, 0x0E,             // mov cx, 0x0E0F (cursor shape)
      0x31, 0xD2,                   // xor dx, dx  (row=0, col=0)
      0xCF,                         // iret
      // ega_info (0x22): AH=12h — Alternate Select (EGA/VGA info)
      0x80, 0xFB, 0x10,             // cmp bl, 0x10
      0x75, 0x06,                   // jne other (+6 → 0x2D)
      0xBB, 0x03, 0x00,             // mov bx, 0x0003 (256K, color mode)
      0xB1, 0x09,                   // mov cl, 9  (feature bits)
      0xCF,                         // iret
      0xCF,                         // other: iret
      // display_combo (0x2E): AH=1Ah — Get Display Combination Code
      0xB0, 0x1A,                   // mov al, 0x1A (function supported)
      0xB3, 0x08,                   // mov bl, 8 (VGA + color analog)
      0xB7, 0x00,                   // mov bh, 0 (no alternate display)
      0xCF,                         // iret
    };
    model.phys_mem.write_bytes(0x0500, int10h, sizeof(int10h));
    // Override IVT entry for INT 10h → 0x0000:0x0500
    model.phys_mem.write16(0x10 * 4, 0x0500);
    model.phys_mem.write16(0x10 * 4 + 2, 0x0000);
  }

  // Set up CPU state for real-mode entry.
  // Per boot protocol: DS=ES=SS=FS=GS=setup_seg, SP=heap_end,
  // interrupts disabled, jump to setup_seg+0x20:0x0000.
  u16 entry_seg = setup_seg + 0x20;  // 0x1020
  for (int i = 0; i < 6; i++) {
    model.zSegReg.data[i] = setup_seg;
    model.zSegCache.data[i].zseg_base = (u64)setup_seg << 4;
  }
  // CS points to entry segment
  model.zSegReg.data[x86::SEG_CS] = entry_seg;
  model.zSegCache.data[x86::SEG_CS].zseg_base = (u64)entry_seg << 4;

  model.zGPR.data[4] = 0xDE00;  // SP = heap_end
  model.zRIP = 0x0000;          // IP = 0 (relative to CS base)

  if (debug) {
    fprintf(stderr, "  real-mode entry: %04x:%04x (linear 0x%lx)\n",
            entry_seg, 0, (u64)entry_seg * 16);
    fprintf(stderr, "  SS:SP = %04x:%04x\n", setup_seg, 0xDE00);
  }

  free(bzimage);
  return true;
}

// =========================================================================
// Keyboard input — convert ASCII/curses keys to AT scan code set 1
// =========================================================================

// ASCII → AT scan code set 1 (make code).  Index is ASCII code.
// 0 = no mapping.  The break code is make | 0x80.
static const u8 ascii_to_scancode[128] = {
  // 0x00-0x0F: control chars
  0,    0x1E, 0x30, 0x2E, 0x20, 0x12, 0x21, 0x22, // NUL ^A ^B ^C ^D ^E ^F ^G
  0x0E, 0x0F, 0x1C, 0x25, 0x26, 0x1C, 0x31, 0x18, // BS  TAB LF  ^K ^L CR  ^N ^O
  // 0x10-0x1F
  0x19, 0x10, 0x13, 0x1F, 0x14, 0x16, 0x2F, 0x11, // ^P ^Q ^R ^S ^T ^U ^V ^W
  0x2D, 0x15, 0x2C, 0x01, 0x2B, 0x1B, 0x07, 0x0C, // ^X ^Y ^Z ESC ^\ ^] ^^ ^_
  // 0x20-0x2F: space ! " # $ % & ' ( ) * + , - . /
  0x39, 0x02, 0x28, 0x04, 0x05, 0x06, 0x08, 0x28, // ' and " share key 0x28
  0x0A, 0x0B, 0x09, 0x0D, 0x33, 0x0C, 0x34, 0x35,
  // 0x30-0x39: 0-9
  0x0B, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
  0x09, 0x0A,
  // 0x3A-0x3F: : ; < = > ?
  0x27, 0x27, 0x33, 0x0D, 0x34, 0x35,
  // 0x40: @
  0x03,
  // 0x41-0x5A: A-Z (shifted)
  0x1E, 0x30, 0x2E, 0x20, 0x12, 0x21, 0x22, 0x23,
  0x17, 0x24, 0x25, 0x26, 0x32, 0x31, 0x18, 0x19,
  0x10, 0x13, 0x1F, 0x14, 0x16, 0x2F, 0x11, 0x2D,
  0x15, 0x2C,
  // 0x5B-0x5F: [ \ ] ^ _
  0x1A, 0x2B, 0x1B, 0x07, 0x0C,
  // 0x60: `
  0x29,
  // 0x61-0x7A: a-z
  0x1E, 0x30, 0x2E, 0x20, 0x12, 0x21, 0x22, 0x23,
  0x17, 0x24, 0x25, 0x26, 0x32, 0x31, 0x18, 0x19,
  0x10, 0x13, 0x1F, 0x14, 0x16, 0x2F, 0x11, 0x2D,
  0x15, 0x2C,
  // 0x7B-0x7F: { | } ~ DEL
  0x1A, 0x2B, 0x1B, 0x29, 0x0E,
};

// Characters that require Shift to be held
static bool needs_shift(int ch) {
  if (ch >= 'A' && ch <= 'Z') return true;
  return ch == '!' || ch == '@' || ch == '#' || ch == '$' || ch == '%' ||
         ch == '^' || ch == '&' || ch == '*' || ch == '(' || ch == ')' ||
         ch == '_' || ch == '+' || ch == '{' || ch == '}' || ch == '|' ||
         ch == ':' || ch == '"' || ch == '<' || ch == '>' || ch == '?' ||
         ch == '~';
}

// Push scancodes for a character into the keyboard controller.
// Generates make+break for the key, with Shift/Ctrl if needed.
static void push_key(KeyboardController &kbd, int ch) {
  u8 special = 0;
  bool extended = false;
  if (ch >= KEY_F(1) && ch <= KEY_F(10)) special = 0x3B + ch - KEY_F(1);
  else if (ch == KEY_F(11) || ch == KEY_F(12)) special = 0x57 + ch - KEY_F(11);
  else {
    switch (ch) {
    case KEY_UP: special = 0x48; break;
    case KEY_DOWN: special = 0x50; break;
    case KEY_LEFT: special = 0x4B; break;
    case KEY_RIGHT: special = 0x4D; break;
    }
    extended = special != 0;
  }
  if (special) {
    if (extended) kbd.push_scancode(0xE0);
    kbd.push_scancode(special);
    if (extended) kbd.push_scancode(0xE0);
    kbd.push_scancode(special | 0x80);
    return;
  }
  // Handle ncurses special keys (KEY_xxx constants >= 256)
  if (ch == KEY_ENTER) ch = '\r';
  else if (ch == KEY_BACKSPACE) ch = 0x08;
  if (ch < 0 || ch >= 128) return;
  u8 sc = ascii_to_scancode[ch];
  if (sc == 0) return;

  bool shift = needs_shift(ch);
  // Ctrl+letter: ASCII 1-26 EXCEPT keys that have their own scancodes
  // (BS=0x08, TAB=0x09, LF=0x0A, CR=0x0D, ESC=0x1B)
  bool ctrl = (ch >= 1 && ch <= 26) &&
              ch != 0x08 && ch != 0x09 && ch != 0x0A && ch != 0x0D && ch != 0x1B;

  if (ctrl)  kbd.push_scancode(0x1D);       // Ctrl make
  if (shift) kbd.push_scancode(0x2A);       // LShift make
  kbd.push_scancode(sc);                     // key make
  kbd.push_scancode(sc | 0x80);              // key break
  if (shift) kbd.push_scancode(0x2A | 0x80); // LShift break
  if (ctrl)  kbd.push_scancode(0x1D | 0x80); // Ctrl break
}

// =========================================================================
// VGA text mode renderer — draws the framebuffer using ncurses.
// Row count is dynamic (25 or 50 depending on font height).
// =========================================================================

static constexpr int VGA_COLS = 80;
static constexpr int VGA_ROWS = 25;

// CP437 to Unicode mapping table.  The VGA text framebuffer stores CP437
// character codes; the terminal expects Unicode.  Characters 0x20-0x7E are
// identical to ASCII.  Everything else needs translation.
static const wchar_t cp437_to_unicode[256] = {
  // 0x00-0x1F: control-code region, but in CP437 these are graphical glyphs
  L' ',      0x263A, 0x263B, 0x2665, 0x2666, 0x2663, 0x2660, 0x2022,
  0x25D8, 0x25CB, 0x25D9, 0x2642, 0x2640, 0x266A, 0x266B, 0x263C,
  0x25BA, 0x25C4, 0x2195, 0x203C, 0x00B6, 0x00A7, 0x25AC, 0x21A8,
  0x2191, 0x2193, 0x2192, 0x2190, 0x221F, 0x2194, 0x25B2, 0x25BC,
  // 0x20-0x7E: standard ASCII (identity mapping)
  L' ', L'!', L'"', L'#', L'$', L'%', L'&', L'\'',
  L'(', L')', L'*', L'+', L',', L'-', L'.', L'/',
  L'0', L'1', L'2', L'3', L'4', L'5', L'6', L'7',
  L'8', L'9', L':', L';', L'<', L'=', L'>', L'?',
  L'@', L'A', L'B', L'C', L'D', L'E', L'F', L'G',
  L'H', L'I', L'J', L'K', L'L', L'M', L'N', L'O',
  L'P', L'Q', L'R', L'S', L'T', L'U', L'V', L'W',
  L'X', L'Y', L'Z', L'[', L'\\', L']', L'^', L'_',
  L'`', L'a', L'b', L'c', L'd', L'e', L'f', L'g',
  L'h', L'i', L'j', L'k', L'l', L'm', L'n', L'o',
  L'p', L'q', L'r', L's', L't', L'u', L'v', L'w',
  L'x', L'y', L'z', L'{', L'|', L'}', L'~', 0x2302,
  // 0x80-0xFF: extended characters
  0x00C7, 0x00FC, 0x00E9, 0x00E2, 0x00E4, 0x00E0, 0x00E5, 0x00E7,
  0x00EA, 0x00EB, 0x00E8, 0x00EF, 0x00EE, 0x00EC, 0x00C4, 0x00C5,
  0x00C9, 0x00E6, 0x00C6, 0x00F4, 0x00F6, 0x00F2, 0x00FB, 0x00F9,
  0x00FF, 0x00D6, 0x00DC, 0x00A2, 0x00A3, 0x00A5, 0x20A7, 0x0192,
  0x00E1, 0x00ED, 0x00F3, 0x00FA, 0x00F1, 0x00D1, 0x00AA, 0x00BA,
  0x00BF, 0x2310, 0x00AC, 0x00BD, 0x00BC, 0x00A1, 0x00AB, 0x00BB,
  0x2591, 0x2592, 0x2593, 0x2502, 0x2524, 0x2561, 0x2562, 0x2556,
  0x2555, 0x2563, 0x2551, 0x2557, 0x255D, 0x255C, 0x255B, 0x2510,
  0x2514, 0x2534, 0x252C, 0x251C, 0x2500, 0x253C, 0x255E, 0x255F,
  0x255A, 0x2554, 0x2569, 0x2566, 0x2560, 0x2550, 0x256C, 0x2567,
  0x2568, 0x2564, 0x2565, 0x2559, 0x2558, 0x2552, 0x2553, 0x256B,
  0x256A, 0x2518, 0x250C, 0x2588, 0x2584, 0x258C, 0x2590, 0x2580,
  0x03B1, 0x00DF, 0x0393, 0x03C0, 0x03A3, 0x03C3, 0x00B5, 0x03C4,
  0x03A6, 0x0398, 0x03A9, 0x03B4, 0x221E, 0x03C6, 0x03B5, 0x2229,
  0x2261, 0x00B1, 0x2265, 0x2264, 0x2320, 0x2321, 0x00F7, 0x2248,
  0x00B0, 0x2219, 0x00B7, 0x221A, 0x207F, 0x00B2, 0x25A0, 0x00A0,
};

// Map VGA color index (BIOS order) → curses color constant.
// VGA: 0=black 1=blue 2=green 3=cyan 4=red 5=magenta 6=brown 7=lgray
static const short vga_to_curses_color[8] = {
  COLOR_BLACK, COLOR_BLUE, COLOR_GREEN, COLOR_CYAN,
  COLOR_RED, COLOR_MAGENTA, COLOR_YELLOW, COLOR_WHITE
};

static bool curses_active = false;

// Color pair number for a (fg, bg) combination.
// We use pair = bg * 8 + fg + 1 (pair 0 is reserved by curses).
static int vga_color_pair(int fg, int bg) {
  return bg * 8 + fg + 1;
}

// Color pair for the status line (white on blue)
static constexpr int STATUS_PAIR = 65;

static void curses_cleanup() {
  if (curses_active) {
    endwin();
    curses_active = false;
  }
}

static void init_curses() {
  setlocale(LC_ALL, "");
  initscr();
  curses_active = true;
  atexit(curses_cleanup);

  // Disable the REP escape sequence (ESC[Nb). Some terminals —
  // especially macOS Terminal/iTerm2 over SSH — don't handle it,
  // causing repeated characters (like the zeros in RIP) to vanish.
  repeat_char = nullptr;

  raw();
  noecho();
  nodelay(stdscr, TRUE);  // non-blocking getch()
  keypad(stdscr, TRUE);
  scrollok(stdscr, FALSE);  // prevent scrolling past the bottom
  curs_set(1);

  if (has_colors()) {
    start_color();
    // Initialize all 64 color pairs (8 fg × 8 bg)
    for (int bg = 0; bg < 8; bg++)
      for (int fg = 0; fg < 8; fg++)
        init_pair(vga_color_pair(fg, bg),
                  vga_to_curses_color[fg], vga_to_curses_color[bg]);
    // Status line: white on blue
    init_pair(STATUS_PAIR, COLOR_WHITE, COLOR_BLUE);
  }
}

static void update_status_line(const char *fmt, ...) {
  if (!curses_active) return;
  // Status line is at the row just below the VGA area, or the last
  // terminal row — whichever is smaller.
  int status_row = std::min(VGA_ROWS, LINES - 1);
  int width = std::min(VGA_COLS, COLS);

  char right[256];
  va_list ap;
  va_start(ap, fmt);
  vsnprintf(right, sizeof(right), fmt, ap);
  va_end(ap);

  const char *left = "sail-x86 | Ctrl-a x to exit";
  int rlen = strlen(right);

  attron(COLOR_PAIR(STATUS_PAIR) | A_BOLD);
  mvhline(status_row, 0, ' ', width);  // clear the line
  mvaddnstr(status_row, 0, left, width);
  if (width > rlen)
    mvaddstr(status_row, width - rlen, right);
  attroff(COLOR_PAIR(STATUS_PAIR) | A_BOLD);
  refresh();
}

static u8 vga_shadow[VGA_COLS * VGA_ROWS * 2];
static u16 vga_shadow_cursor = 0xFFFF;
static bool vga_shadow_valid = false;

static void render_vga_text(x86::Model &model) {
  static constexpr u64 FB_BASE = 0xB8000;

  // Get hardware scroll offset from CRTC start address registers
  u16 start_off = model.vga.start_addr();

  // Read visible framebuffer from physical memory, handling wrap-around
  u8 current[VGA_COLS * VGA_ROWS * 2];
  u32 byte_off = (u32)start_off * 2;
  u32 fb_size = VGA_COLS * VGA_ROWS * 2;

  if (byte_off + fb_size <= 0x8000) {
    model.phys_mem.read_bytes(FB_BASE + byte_off, current, fb_size);
  } else {
    u32 first = 0x8000 - byte_off;
    model.phys_mem.read_bytes(FB_BASE + byte_off, current, first);
    model.phys_mem.read_bytes(FB_BASE, current + first, fb_size - first);
  }

  u16 cursor = model.vga.cursor_pos() - start_off;

  // Skip if nothing changed
  if (vga_shadow_valid &&
      cursor == vga_shadow_cursor &&
      memcmp(current, vga_shadow, fb_size) == 0)
    return;

  // Clip to terminal size, leaving one row for status line
  int max_row = std::min(VGA_ROWS, LINES - 1);
  int max_col = std::min(VGA_COLS, COLS);

  // If the cursor is below the visible area, shift the viewport down
  // so the cursor row is the last visible row.  This ensures the prompt
  // is never hidden behind the status bar in 80x25 mode on a 25-line
  // terminal.
  int crow = cursor / VGA_COLS;
  int vga_skip = 0;
  if (crow >= max_row)
    vga_skip = crow - max_row + 1;

  for (int row = 0; row < max_row; row++) {
    for (int col = 0; col < max_col; col++) {
      int idx = ((row + vga_skip) * VGA_COLS + col) * 2;
      u8 ch = current[idx];
      u8 attr = current[idx + 1];
      int fg = attr & 0x07;       // base fg color (0-7)
      bool bright = attr & 0x08;  // bright/bold bit
      int bg = (attr >> 4) & 0x07;

      wchar_t wch = cp437_to_unicode[ch];
      int pair = vga_color_pair(fg, bg);
      attr_t a = COLOR_PAIR(pair);
      if (bright) a |= A_BOLD;

      cchar_t cc;
      wchar_t wstr[2] = { wch, L'\0' };
      setcchar(&cc, wstr, a, (short)pair, nullptr);
      mvadd_wch(row, col, &cc);
    }
  }

  // Position cursor (adjusted for viewport shift)
  int ccol = cursor % VGA_COLS;
  int adj_crow = crow - vga_skip;
  if (adj_crow >= 0 && adj_crow < max_row && ccol >= 0 && ccol < max_col)
    move(adj_crow, ccol);

  refresh();

  memcpy(vga_shadow, current, fb_size);
  vga_shadow_cursor = cursor;
  vga_shadow_valid = true;
}

// =========================================================================
// Main emulation loop
// =========================================================================

int main(int argc, char *argv[]) {
  bool debug = false;
  bool keyboard_input = false;
  u64 ram_mb = 256;
  u64 ips = 1;  // virtual CPU speed, million instructions per emulated second
  const char *cmdline = nullptr;
  const char *initrd_path = nullptr;
  const char *bzimage_path = nullptr;
  DisplayMode display_mode = DISPLAY_SERIAL;
  const char *bios_path = nullptr;
  const char *hda_path = nullptr;
  const char *hdb_path = nullptr;
  const char *fda_path = nullptr;
  const char *cdrom_path = nullptr;
  const char *boot_order = nullptr;
  int first_arg = 1;

  while (first_arg < argc && argv[first_arg][0] == '-') {
    if (strcmp(argv[first_arg], "-d") == 0) {
      debug = true;
      first_arg++;
    } else if (strcmp(argv[first_arg], "-kbd") == 0) {
      keyboard_input = true;
      first_arg++;
    } else if (strcmp(argv[first_arg], "-m") == 0 && first_arg + 1 < argc) {
      ram_mb = atoi(argv[first_arg + 1]);
      first_arg += 2;
    } else if (strcmp(argv[first_arg], "-ips") == 0 && first_arg + 1 < argc) {
      ips = atoi(argv[first_arg + 1]);
      if (ips == 0) { fprintf(stderr, "-ips needs a positive number\n"); return 1; }
      first_arg += 2;
    } else if (strcmp(argv[first_arg], "-a") == 0 && first_arg + 1 < argc) {
      cmdline = argv[first_arg + 1];
      first_arg += 2;
    } else if (strcmp(argv[first_arg], "-i") == 0 && first_arg + 1 < argc) {
      initrd_path = argv[first_arg + 1];
      first_arg += 2;
    } else if (strcmp(argv[first_arg], "-vga") == 0) {
      display_mode = DISPLAY_VGA;
      first_arg++;
    } else if (strcmp(argv[first_arg], "-b") == 0 && first_arg + 1 < argc) {
      bios_path = argv[first_arg + 1];
      first_arg += 2;
    } else if (strcmp(argv[first_arg], "-hda") == 0 && first_arg + 1 < argc) {
      hda_path = argv[first_arg + 1];
      first_arg += 2;
    } else if (strcmp(argv[first_arg], "-hdb") == 0 && first_arg + 1 < argc) {
      hdb_path = argv[first_arg + 1];
      first_arg += 2;
    } else if (strcmp(argv[first_arg], "-fda") == 0 && first_arg + 1 < argc) {
      fda_path = argv[first_arg + 1];
      first_arg += 2;
    } else if (strcmp(argv[first_arg], "-cdrom") == 0 && first_arg + 1 < argc) {
      cdrom_path = argv[first_arg + 1];
      first_arg += 2;
    } else if (strcmp(argv[first_arg], "-boot") == 0 && first_arg + 1 < argc) {
      boot_order = argv[first_arg + 1];
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

  if (!bios_path && first_arg >= argc) {
    usage(argv[0]);
    return 1;
  }
  if (!bios_path)
    bzimage_path = argv[first_arg];

  u64 ram_size = ram_mb * 1024 * 1024;

  x86::Model model;

  if (!model.phys_mem.init(ram_size)) {
    fprintf(stderr, "Failed to allocate %lu MB guest RAM\n", ram_mb);
    return 1;
  }

  // Set CMOS memory size registers
  model.cmos.set_ram_size(ram_size);
  model.bios_debug = getenv("SAIL_X86_BIOS_DEBUG") != nullptr;

  if (bios_path) {
    // BIOS boot path: load ROM, start at reset vector
    size_t rom_size;
    u8 *rom = read_file(bios_path, &rom_size);
    if (!rom) {
      fprintf(stderr, "Failed to load BIOS ROM: %s\n", bios_path);
      return 1;
    }
    init_cpu_state_bios(model);
    model.phys_mem.load_rom(rom, rom_size);
    free(rom);

    // Install a minimal IVT stub so that BIOS INT calls made before
    // SeaBIOS installs its own handlers don't crash (e.g., INT 10h
    // video calls before a VGA option ROM is loaded).
    // Place a single IRET at 0x0400 and point all 256 IVT entries to it.
    model.phys_mem.write8(0x0400, 0xCF);  // IRET
    for (int i = 0; i < 256; i++) {
      model.phys_mem.write16(i * 4, 0x0400);      // offset
      model.phys_mem.write16(i * 4 + 2, 0x0000);  // segment
    }

    // Load VGA BIOS option ROM at C000:0000 (standard VGA BIOS address).
    // SeaBIOS with CONFIG_OPTIONROMS=y scans for ROMs starting at C0000
    // during POST. It checks for the 55 AA signature, verifies the
    // checksum, and calls the ROM's init entry (offset 3) via far CALL.
    // The init code installs the INT 10h handler and initializes BDA.
    {
      size_t vga_size;
      std::string vga_path = bios_path;
      auto slash = vga_path.find_last_of('/');
      vga_path = (slash == std::string::npos ? "" : vga_path.substr(0, slash + 1)) + "vgabios.bin";
      u8 *vga = read_file(vga_path.c_str(), &vga_size);
      if (vga) {
        // Fix ROM checksum: sum of all bytes must be 0 (mod 256).
        u8 sum = 0;
        for (size_t i = 0; i < vga_size; i++) sum += vga[i];
        vga[vga_size - 1] -= sum;
        // Expose this PCI device's ROM once. A second copy under fw_cfg's
        // vgaroms/ is initialized without a PCI BDF and overwrites the VBE
        // framebuffer address with the default E0000000 instead of BAR0.
        model.phys_mem.load_vga_rom(vga, vga_size, 0xFEB00000ULL);
        model.pci.vga_rom_size = (u32)vga_size;
        fprintf(stderr, "sail-x86-system: VGA BIOS loaded (%zu bytes, checksum OK)\n", vga_size);
        free(vga);
      }
    }

    // Populate fw_cfg E820 table so SeaBIOS can discover RAM size
    model.fw_cfg.set_ram_size(ram_size);
    fprintf(stderr, "sail-x86-system: BIOS=%s (%zu bytes), RAM=%luMB\n",
            bios_path, rom_size, ram_mb);
    fprintf(stderr, "sail-x86-system: reset vector CS:IP=%04x:%04lx (linear 0x%lx)\n",
            (u16)model.zSegReg.data[x86::SEG_CS], (u64)model.zRIP,
            (u64)model.zSegCache.data[x86::SEG_CS].zseg_base + (u64)model.zRIP);

    if (hda_path) {
      if (!model.ide0.open_disk(hda_path)) {
        fprintf(stderr, "Failed to open disk image: %s\n", hda_path);
        return 1;
      }
      fprintf(stderr, "sail-x86-system: HDA=%s\n", hda_path);
    }

    if (hdb_path) {
      if (!model.ide0.open_slave_disk(hdb_path)) {
        fprintf(stderr, "Failed to open disk image: %s\n", hdb_path);
        return 1;
      }
      fprintf(stderr, "sail-x86-system: HDB=%s\n", hdb_path);
    }

    if (cdrom_path) {
      if (!model.ide1.open_cdrom(cdrom_path)) {
        fprintf(stderr, "Failed to open CD-ROM image: %s\n", cdrom_path);
        return 1;
      }
      fprintf(stderr, "sail-x86-system: CDROM=%s\n", cdrom_path);
    }

    // SeaBIOS tries the drives in the CMOS boot order; without one it takes
    // them as it found them (floppy, hard disk, CD-ROM).  A CD-ROM, when
    // attached, goes first unless -boot says otherwise.
    if (boot_order || cdrom_path)
      model.cmos.set_boot_order(boot_order ? boot_order : "d");

    if (fda_path) {
      if (!model.floppy.open(fda_path)) {
        fprintf(stderr, "Failed to open floppy image: %s\n", fda_path);
        return 1;
      }
      // CMOS 0x10: floppy type. High nibble = drive A, low = drive B.
      // 0x40 = 1.44MB 3.5" in drive A, no drive B.
      // CMOS 0x14 bit 0: set = floppy drive present.
      model.cmos.set_floppy(true);
      fprintf(stderr, "sail-x86-system: FDA=%s\n", fda_path);
    }

  } else {
    // Linux bzImage boot path
    init_cpu_state(model);
    fprintf(stderr, "sail-x86-system: loading %s\n", bzimage_path);
    if (!load_bzimage(model, bzimage_path, cmdline, initrd_path, display_mode, debug)) {
      fprintf(stderr, "Failed to load kernel image\n");
      return 1;
    }
    fprintf(stderr, "sail-x86-system: RAM=%luMB, entry=0x%lx\n",
            ram_mb, (u64)model.zRIP);
  }

  // Set up interactive console.
  bool interactive;
  if (display_mode == DISPLAY_VGA) {
    // VGA mode: ncurses handles the terminal.
    fprintf(stderr, "sail-x86-system: VGA text mode display\n");
    init_curses();
    interactive = true;
    model.uart.output_fn = nullptr;
  } else {
    // Serial mode: UART output to stdout.
    interactive = setup_raw_terminal();
    model.uart.output_fn = uart_output_stdout;
    if (interactive) {
      fprintf(stderr, "sail-x86-system: interactive console on stdin/stdout\n");
      fprintf(stderr, "Press Ctrl-a x to exit the emulator.\n\n");
    } else {
      // Non-tty stdin: set non-blocking so we can still feed piped input to UART
      int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
      fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);
    }
  }
  bool poll_stdin = true;  // Always poll stdin for UART RX data
  auto input_byte = [&](u8 ch) {
    if (keyboard_input) push_key(model.kbd, ch == '\r' || ch == '\n' ? '\n' : ch);
    else model.uart.rx_push(ch);
  };
  auto input_special = [&](int ch) {
    int key = 0;
    if (ch >= '1' && ch <= '9') key = KEY_F(ch - '0');
    else if (ch == '0') key = KEY_F(10);
    else if (ch == 'u') key = KEY_UP;
    else if (ch == 'd') key = KEY_DOWN;
    else if (ch == 'l') key = KEY_LEFT;
    else if (ch == 'r') key = KEY_RIGHT;
    if (key) push_key(model.kbd, key);
    return key != 0;
  };

  u64 insn_count = 0;
  const char *trace_start_env = getenv("SAIL_X86_TRACE_START");
  const char *trace_end_env = getenv("SAIL_X86_TRACE_END");
  const char *trace_step_env = getenv("SAIL_X86_TRACE_STEP");
  bool has_trace_start = trace_start_env && *trace_start_env;
  bool has_trace_end = trace_end_env && *trace_end_env;
  bool has_trace_step = trace_step_env && *trace_step_env;
  u64 trace_start = parse_env_u64("SAIL_X86_TRACE_START", 0);
  u64 trace_end = parse_env_u64("SAIL_X86_TRACE_END", 0);
  u64 trace_step = parse_env_u64("SAIL_X86_TRACE_STEP", 1);
  bool trace_window_enabled = has_trace_start || has_trace_end || has_trace_step;
  bool trace_real_ud = getenv("SAIL_X86_TRACE_REAL_UD") != nullptr;
  bool trace_address_enabled = getenv("SAIL_X86_TRACE_ADDRESS") != nullptr;
  u64 trace_address = parse_env_u64("SAIL_X86_TRACE_ADDRESS", 0);
  bool trace_address_seen = false;
  const char *event_address_env = getenv("SAIL_X86_TRACE_EVENT_ADDRESS");
  bool event_address_seen = false;
  u64 event_address = parse_env_u64("SAIL_X86_TRACE_EVENT_ADDRESS", 0);
  struct TraceLocation { u64 count, ip, address; u16 cs; bool physical; };
  TraceLocation recent[64] = {};
  unsigned recent_count = 0, recent_next = 0;
  const char *probe_insn_env = getenv("SAIL_X86_PROBE_INSN");
  bool has_probe_insn = probe_insn_env && *probe_insn_env;
  u64 probe_insn = parse_env_u64("SAIL_X86_PROBE_INSN", 0);
  if (trace_step == 0) {
    fprintf(stderr, "sail-x86-system: SAIL_X86_TRACE_STEP=0 is invalid; using 1\n");
    trace_step = 1;
  }
  if (trace_window_enabled) {
    fprintf(stderr,
            "sail-x86-system: trace window start=%lu end=%s step=%lu\n",
            trace_start,
            has_trace_end ? trace_end_env : "none",
            trace_step);
  }

  // Virtual time.  The PIT (1.193182 MHz) advances 1193 cycles, one
  // millisecond, every 1000*ips instructions, and the TSC counts a 1 GHz
  // clock over the same instructions, so the guest sees a consistent
  // ips-MIPS CPU whatever the host speed and its timer calibrations agree.
  // 1 MIPS is the historical default.  A kernel with HZ=1000 then gets
  // 1000 instructions per tick, less than its tick handler costs, and never
  // leaves the timer interrupt; -ips 20 or more for such a kernel.
  const u64 PIT_TICK_INTERVAL = 1000 * ips;
  const u64 PIT_CYCLES_PER_TICK = 1193;
  u64 tsc_frac = 0;
  // While halted no instruction runs, so the TSC must follow the PIT by
  // hand: one tick is 1193 PIT cycles of the 1 GHz TSC.  A kernel that keeps
  // time on the TSC (clocksource tsc) otherwise sees time stand still whenever
  // it idles, and no timer of its ever expires.
  const u64 TSC_PER_PIT_TICK = PIT_CYCLES_PER_TICK * 1000000000ULL / 1193182;
  u64 next_pit_tick = PIT_TICK_INTERVAL;

  // VGA refresh: render framebuffer every 50K instructions (~20 fps at 1M ips)
  const u64 VGA_REFRESH_INTERVAL = 50000;
  u64 next_vga_refresh = VGA_REFRESH_INTERVAL;

  // Ctrl-a escape state: when Ctrl-a is pressed, the next key decides the action.
  // Ctrl-a x = quit. Ctrl-a Ctrl-a = send literal Ctrl-a.
  bool ctrl_a_pending = false;

  // Handle SIGTERM/SIGINT gracefully so the VGA dump runs on timeout
  static volatile bool got_signal = false;
  signal(SIGTERM, [](int) { got_signal = true; });

  // SIGUSR1 dumps the CPU state and the interrupt controllers to stderr and
  // continues: a look inside a run that has gone quiet on the console.
  static volatile bool dump_requested = false;
  signal(SIGUSR1, [](int) { dump_requested = true; });
  static volatile sig_atomic_t framebuffer_requested = 0;
  signal(SIGUSR2, [](int) { framebuffer_requested = 1; });
  auto dump_framebuffer = [&]() {
    framebuffer_requested = 0;
    const char *path = getenv("SAIL_X86_FRAMEBUFFER");
    if (!path) path = "framebuffer.png";
    bool text = !model.vbe.enabled() && !model.vga.graphics();
    unsigned width = model.vbe.enabled() ? model.vbe.width() :
                     text ? model.vga.text_width() : model.vga.pixel_width();
    unsigned height = model.vbe.enabled() ? model.vbe.height() :
                      text ? model.vga.text_height() : model.vga.pixel_height();
    auto rgb = model.vbe.enabled() ? model.vbe.rgb(model.vga.dac_palette, model.vga.dac_mask) :
               text ? model.vga.text_rgb(model.phys_mem.ram_ptr() + ((model.vga.misc_output & 1) ? 0xB8000 : 0xB0000)) :
               model.vga.graphics_rgb();
    if (write_png(path, width, height, rgb))
      fprintf(stderr, "sail-x86-system: framebuffer %ux%ux%u saved to %s\n",
              width, height, model.vbe.enabled() ? model.vbe.depth() : ((model.vga.gc_regs[5] & 0x40) ? 8 : 4), path);
  };
  auto dump_state = [&]() {
    dump_requested = false;
    dump_framebuffer();
    dump_registers(stderr, insn_count, model);
    fprintf(stderr, "  APIC SVR=%08x TPR=%02x PPR=%02x TIMER=%08x COUNT=%u pending=%d\n",
            model.lapic.read(0xF0), model.lapic.read(0x80), model.lapic.read(0xA0),
            model.lapic.read(0x320), model.lapic.read(0x390), model.lapic.pending());
    fprintf(stderr, "    initial=%u divide=%x LINT0=%08x LINT1=%08x clock=%lu ns\n",
            model.lapic.read(0x380), model.lapic.read(0x3E0), model.lapic.read(0x350), model.lapic.read(0x360), model.tsc);
    for (unsigned group = 0; group < 8; ++group)
      fprintf(stderr, "    vectors %3u-%3u IRR=%08x ISR=%08x TMR=%08x\n", group * 32, group * 32 + 31,
              model.lapic.read(0x200 + group * 16), model.lapic.read(0x100 + group * 16), model.lapic.read(0x180 + group * 16));
    fprintf(stderr, "  PIC master IRR=%02x IMR=%02x ISR=%02x  slave IRR=%02x IMR=%02x ISR=%02x  %s\n",
            model.pic_master.get_irr(), model.pic_master.get_imr(), model.pic_master.get_isr(),
            model.pic_slave.get_irr(), model.pic_slave.get_imr(), model.pic_slave.get_isr(),
            model.zsystem_state == x86::zSysHalted ? "halted" : "running");
    model.ioapic.dump(stderr);
    model.pit.dump(stderr);
    model.cmos.dump(stderr);
    model.ide0.dump(stderr);
    model.ide1.dump(stderr);
    fprintf(stderr, "  VGA text screen:\n");
    unsigned start = model.vga.start_addr() * 2;
    for (unsigned y = 0; y < model.vga.text_rows(); ++y) {
      for (unsigned x = 0; x < model.vga.text_cols(); ++x) {
        u8 ch = model.phys_mem.read8(((model.vga.misc_output & 1) ? 0xB8000 : 0xB0000) +
                    ((start + y * model.vga.crtc_regs[0x13] * 4 + x * 2) & 0x7FFF));
        fputc(ch >= 32 && ch < 127 ? ch : ' ', stderr);
      }
      fputc('\n', stderr);
    }
    if (const char *path = getenv("SAIL_X86_DUMP_RAM")) {
      if (FILE *f = fopen(path, "wb")) {
        fwrite(model.phys_mem.ram_ptr(), 1, model.phys_mem.ram_size(), f);
        fclose(f);
      }
    }
  };

  auto dump_recent = [&]() {
    for (unsigned i = 0; i < recent_count; ++i) {
      const auto &r = recent[(recent_next + 64 - recent_count + i) % 64];
      fprintf(stderr, "  [%lu] %04x:%08lx:", r.count, r.cs, r.ip);
      if (r.physical)
        for (unsigned b = 0; b < 16; ++b) fprintf(stderr, " %02x", model.phys_mem.read8(r.address + b));
      else fprintf(stderr, " <paged code; bytes omitted>");
      fputc('\n', stderr);
    }
  };

  while (!model.should_exit && !got_signal) {
    if (dump_requested) dump_state();
    if (framebuffer_requested) dump_framebuffer();
    if (trace_window_enabled && has_trace_end && insn_count >= trace_end) {
      dump_state();
      fprintf(stderr, "sail-x86-system: stopping at trace end %lu instructions\n", insn_count);
      break;
    }

    // Print progress periodically
    if (curses_active && insn_count % 1000000 == 0) {
      if (model.zcur_mode == x86::zLongMode)
        update_status_line("%luM insns  RIP=%016lx",
                           insn_count / 1000000, (u64)model.zRIP);
      else
        update_status_line("%luM insns  RIP=%04x:%08lx",
                           insn_count / 1000000,
                           (u16)model.zSegReg.data[x86::SEG_CS], (u64)model.zRIP);
    }

    bool in_trace_window = trace_window_enabled &&
                           insn_count >= trace_start &&
                           (!has_trace_end || insn_count <= trace_end);
    bool trace_sample = in_trace_window && ((insn_count - trace_start) % trace_step == 0);
    if (debug || trace_sample)
      dump_registers(stderr, insn_count, model);

    if (has_probe_insn && insn_count == probe_insn) {
      u64 vaddr = (u64)model.zGPR.data[7];
      u64 paddr = model.ztranslate_addr(vaddr, x86::zPT_Read);
      u64 mem64 = model.phys_mem.read64(paddr);
      fprintf(stderr,
              "sail-x86-system: probe insn=%lu RIP=%016lx RDI=%016lx -> PA=%016lx MEM64=%016lx\n",
              insn_count, (u64)model.zRIP, vaddr, paddr, mem64);
    }

    bool was_real = model.zcur_mode == x86::zRealMode;
    u64 previous_ip = model.zRIP;
    u16 previous_cs = model.zSegReg.data[x86::SEG_CS];
    if (trace_real_ud || trace_address_enabled || event_address_env) {
      u64 address = model.zSegCache.data[x86::SEG_CS].zseg_base + previous_ip;
      if (!model.za20_enabled) address &= ~0x100000ULL;
      recent[recent_next] = {insn_count, previous_ip,
                            address, previous_cs, !(model.zCR0 & (1ULL << 31))};
      recent_next = (recent_next + 1) % 64;
      recent_count = std::min(recent_count + 1, 64u);
      if (trace_address_enabled && !trace_address_seen &&
          model.zSegCache.data[x86::SEG_CS].zseg_base + previous_ip == trace_address) {
        trace_address_seen = true;
        fprintf(stderr, "sail-x86-system: trace address 0x%lx at instruction %lu; recent locations:\n",
                trace_address, insn_count);
        dump_recent();
        dump_state();
      }
    }
    model.zstep(UNIT);
    if (event_address_env && !event_address_seen && previous_ip == event_address && model.zevent_delivered) {
      event_address_seen = true;
      fprintf(stderr, "sail-x86-system: event at %04x:%08lx before instruction %lu; FS=%04x base=%016lx\n",
              previous_cs, previous_ip, insn_count, (u16)model.zSegReg.data[x86::SEG_FS],
              (u64)model.zSegCache.data[x86::SEG_FS].zseg_base);
      dump_recent();
      dump_state();
    }
    if (trace_real_ud && model.zcur_mode == x86::zRealMode &&
        (model.zRIP || model.zSegReg.data[x86::SEG_CS]) &&
        model.zRIP == model.phys_mem.read16(model.zIDTR_base + 6 * 4) &&
        model.zSegReg.data[x86::SEG_CS] == model.phys_mem.read16(model.zIDTR_base + 6 * 4 + 2)) {
      u64 stack = model.zSegCache.data[x86::SEG_SS].zseg_base + (model.zGPR.data[4] & 0xFFFF);
      // Also retain software interrupts, chained handlers and mode transitions:
      // requiring a matching fault frame hides precisely those useful cases.
      // IVT entries can share a handler, so do not infer the delivered vector.
      bool fault_frame = was_real && model.phys_mem.read16(stack) == previous_ip &&
                         model.phys_mem.read16(stack + 2) == previous_cs;
      u32 handler = model.phys_mem.read32(model.zIDTR_base + 6 * 4);
      bool shared = false;
      for (unsigned v = 0; v < 256; ++v)
        if (v != 6 && model.phys_mem.read32(model.zIDTR_base + v * 4) == handler)
          shared = true;
      // Firmware shares one IRET stub among many vectors. Do not dump RAM on
      // each timer tick, while still retaining matching fault frames there.
      if ((fault_frame || !shared) &&
          (model.zRIP != previous_ip || model.zSegReg.data[x86::SEG_CS] != previous_cs || !was_real)) {
        fprintf(stderr, "sail-x86-system: real-mode IVT[6] entry from %04x:%04lx at instruction %lu; recent locations (current physical bytes when paging was disabled):\n",
                previous_cs, previous_ip, insn_count);
        fprintf(stderr, "  previous mode=%s, stack frame=%04x:%04x flags=%04x\n",
                was_real ? "real" : "protected/long",
                model.phys_mem.read16(stack + 2), model.phys_mem.read16(stack),
                model.phys_mem.read16(stack + 4));
        dump_recent();
        dump_state();
      }
    }
    tsc_frac += 1000;  // 1 GHz TSC: 1000 cycles per instruction at 1 MIPS
    model.tsc += tsc_frac / ips;
    tsc_frac %= ips;




    if (model.zfault_pending) {
      dump_state();
      i64 vec = model.zfault_vector;
      u32 err = model.zfault_error_code;
      curses_cleanup();
      fprintf(stderr, "sail-x86-system: FATAL fault #%ld (err=0x%x) at RIP=0x%lx after %lu insns\n",
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
      u64 rip = model.zRIP;
      fprintf(stderr, "  bytes at RIP:");
      for (int b = 0; b < 16; b++) {
        u64 pa = rip + b;
        if (model.phys_mem.in_ram(pa))
          fprintf(stderr, " %02x", model.phys_mem.read8(pa));
      }
      fprintf(stderr, "\n");
      model.model_fini();
      return 128 + (int)vec;
    } else if (model.zsystem_state == x86::zSysHalted) {
      // HLT: in system mode, wait for interrupt then continue
      if (model.zsystem_mode) {
        // If IF=0, this is a panic halt loop — exit
        if (model.zIF_flag == 0) {
          dump_state();
          curses_cleanup();
          fprintf(stderr, "sail-x86-system: HLT with IF=0 (panic halt) after %lu insns at RIP=0x%lx\n",
                  insn_count, (u64)model.zRIP);
          model.model_fini();
          return 1;
        }
        // Wait for an interrupt: poll stdin + tick PIT until something fires.
        // One PIT tick (1 ms of guest time) per millisecond of wall time.
        // (or the user quits; leaving through the main loop prints the
        // instruction count like every other exit).
        while (!model.interrupt_pending() && !model.should_exit && !got_signal) {
          if (dump_requested) dump_state();
          if (framebuffer_requested) dump_framebuffer();
          if (poll_stdin) {
            if (curses_active) {
              // In curses mode, use getch() and push scancodes to i8042
              int ch;
              while ((ch = getch()) != ERR) {
                if (ctrl_a_pending) {
                  ctrl_a_pending = false;
                  if (input_special(ch)) continue;
                  if (ch == 'x' || ch == 'X') {
                    model.should_exit = true;
                    break;
                  }
                  if (ch == 0x01) push_key(model.kbd, 0x01);
                  continue;
                }
                if (ch == 0x01) { ctrl_a_pending = true; continue; }
                push_key(model.kbd, ch);
              }
              if (model.kbd.has_data())
                model.set_irq(1, model.kbd.has_data());
              // Render VGA while waiting
              render_vga_text(model);
              napms(1);
            } else {
              struct pollfd pfd = { STDIN_FILENO, POLLIN, 0 };
              if (poll(&pfd, 1, 1 /*ms*/) > 0) {
                u8 buf[64];
                ssize_t n = read(STDIN_FILENO, buf, sizeof(buf));
                for (ssize_t i = 0; n > 0 && i < n; i++) {
                  if (ctrl_a_pending) {
                    ctrl_a_pending = false;
                    if (input_special(buf[i])) continue;
                    if (buf[i] == 's') { keyboard_input = false; continue; }
                    if (buf[i] == 'k') { keyboard_input = true; continue; }
                    if (buf[i] == 'x' || buf[i] == 'X') {
                      fprintf(stderr, "\nsail-x86-system: Ctrl-a x — exiting\n");
                      model.should_exit = true;
                      break;
                    }
                    if (buf[i] == 0x01) input_byte(0x01);
                    continue;
                  }
                  if (buf[i] == 0x01) { ctrl_a_pending = true; continue; }
                  input_byte(buf[i]);
                }
              }
            }
            if (model.uart.has_irq())
              model.set_irq(4, model.uart.has_irq());
          }
          model.tsc += TSC_PER_PIT_TICK;
          model.kbd.tick();
          model.set_irq(1, model.kbd.has_data());
          if (model.pit.tick(PIT_CYCLES_PER_TICK))
            model.pulse_irq(0);
        }
        // On real x86, when an interrupt wakes the CPU from HLT, execution
        // resumes at the instruction AFTER HLT. The model commits the
        // post-HLT RIP when it executes HLT, so just leave the halt state.
        model.zsystem_state = x86::zSysRunning;
        insn_count++;
        continue;
      }
      curses_cleanup();
      fprintf(stderr, "sail-x86-system: HLT after %lu instructions\n", insn_count);
      model.model_fini();
      return 0;
    } else {
      insn_count++;
    }

    // Poll stdin for input and feed into UART RX FIFO.
    // Check every 1K instructions to avoid syscall overhead.
    if (poll_stdin && (insn_count & 0x3FF) == 0) {
      if (curses_active) {
        int ch;
        while ((ch = getch()) != ERR) {
          if (ctrl_a_pending) {
            ctrl_a_pending = false;
            if (input_special(ch)) continue;
            if (ch == 'x' || ch == 'X') {
              model.should_exit = true;
              break;
            }
            if (ch == 0x01) push_key(model.kbd, 0x01);
            continue;
          }
          if (ch == 0x01) { ctrl_a_pending = true; continue; }
          push_key(model.kbd, ch);
        }
        if (model.kbd.has_data())
          model.set_irq(1, model.kbd.has_data());
      } else {
        u8 buf[64];
        ssize_t n = read(STDIN_FILENO, buf, sizeof(buf));
        // For pipes, n==0 means EOF. For TTYs with VMIN=0, n==0 means no data.
        if (n == 0 && !interactive) poll_stdin = false;
        for (ssize_t i = 0; n > 0 && i < n; i++) {
          if (ctrl_a_pending) {
            ctrl_a_pending = false;
            if (input_special(buf[i])) continue;
            if (buf[i] == 's') { keyboard_input = false; continue; }
            if (buf[i] == 'k') { keyboard_input = true; continue; }
            if (buf[i] == 'x' || buf[i] == 'X') {
              fprintf(stderr, "\nsail-x86-system: Ctrl-a x — exiting\n");
              model.should_exit = true;
              break;
            }
            if (buf[i] == 0x01) { // Ctrl-a Ctrl-a = literal Ctrl-a
              input_byte(0x01);
            }
            continue;
          }
          if (buf[i] == 0x01) { ctrl_a_pending = true; continue; }
          input_byte(buf[i]);
        }
      }
    }

    // Periodic PIT tick
    if (insn_count >= next_pit_tick) {
      model.kbd.tick();
      if (model.pit.tick(PIT_CYCLES_PER_TICK)) {
        model.pulse_irq(0);
      }
      next_pit_tick = insn_count + PIT_TICK_INTERVAL;
    }

    // Floppy delayed IRQ tick
    model.floppy.tick();

    // UART interrupt (IRQ 4): RDA or THRE
    model.set_irq(4, model.uart.has_irq());

    // Keyboard interrupt (IRQ 1): scancode available
    model.set_irq(1, model.kbd.has_data());

    // System reboot: keyboard 0xFE, PCI 0xCF9, or JMP FFFF:0000 (reset vector)
    if ((u16)model.zSegReg.data[x86::SEG_CS] == 0xFFFF && (u64)model.zRIP == 0x0000)
      model.reboot_pending = true;
    if (model.kbd.reboot_requested || model.reboot_pending) {
      model.kbd.reboot_requested = false;
      model.reboot_pending = false;
      init_cpu_state_bios(model);
      vga_shadow_valid = false;
      insn_count = 0;
      next_pit_tick = PIT_TICK_INTERVAL;
      if (display_mode == DISPLAY_VGA)
        next_vga_refresh = VGA_REFRESH_INTERVAL;
    }

    // Periodic VGA refresh
    if (display_mode == DISPLAY_VGA && insn_count >= next_vga_refresh) {
      render_vga_text(model);
      next_vga_refresh = insn_count + VGA_REFRESH_INTERVAL;
    }
  }

  curses_cleanup();
  fprintf(stderr, "sail-x86-system: exited after %lu instructions\n", insn_count);


  model.model_fini();
  return model.exit_code;
}

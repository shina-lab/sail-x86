/// System-level x86-64 emulator.
// Loads a Linux bzImage and boots from real mode, letting the kernel's
// own 16-bit setup code handle the real → protected → long mode transition.

#include "sail_x86_model.h"
#include "x86-helpers.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>
#include <sys/stat.h>
#include <termios.h>
#include <csignal>
#include <curses.h>
#include <term.h>

enum DisplayMode { DISPLAY_SERIAL, DISPLAY_VGA };

static void usage(const char *prog) {
  fprintf(stderr, "Usage: %s [options] <bzImage>\n", prog);
  fprintf(stderr, "       %s [options] -b <bios.bin> [-hda <disk.img>]\n", prog);
  fprintf(stderr, "Options:\n");
  fprintf(stderr, "  -d              Enable debug trace\n");
  fprintf(stderr, "  -m <MB>         RAM size in MB (default 256)\n");
  fprintf(stderr, "  -a <args>       Kernel command line\n");
  fprintf(stderr, "  -i <file>       Initramfs image\n");
  fprintf(stderr, "  -vga            Use VGA text mode display (default: serial)\n");
  fprintf(stderr, "  -b <file>       BIOS ROM image (e.g., SeaBIOS bios.bin)\n");
  fprintf(stderr, "  -hda <file>     Hard disk image\n");
  fprintf(stderr, "  -h              Show this help\n");
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

  // Debug registers
  model.zDR0 = 0;
  model.zDR1 = 0;
  model.zDR2 = 0;
  model.zDR3 = 0;
  model.zDR6 = 0xFFFF0FF0;
  model.zDR7 = 0x00000400;

  // Disable interrupts
  model.zIF_flag = 0;
  model.zNT = 0;
  model.zRF = 0;

  // Zero GPRs
  for (int i = 0; i < 16; i++)
    model.zGPR.data[i] = 0;
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
  const char *default_serial_cmdline = "earlyprintk=serial,0x3f8 console=ttyS0 noapic nolapic";
  const char *default_vga_cmdline = "console=tty0 noapic nolapic";
  const char *default_cmdline = (display_mode == DISPLAY_VGA) ?
                                 default_vga_cmdline : default_serial_cmdline;
  const char *use_cmdline = (cmdline && strlen(cmdline) > 0) ? cmdline : default_cmdline;
  model.phys_mem.write_bytes(cmdline_addr, use_cmdline, strlen(use_cmdline) + 1);
  // cmd_line_ptr: physical address of command line
  model.phys_mem.write32(setup_base + 0x228, (u32)cmdline_addr);

  if (display_mode == DISPLAY_VGA) {
    // vid_mode: VIDEO_8POINT (0x0F01) → 80x50 text with 8-pixel font.
    // The setup code calls vga_set_8font() (INT 10h no-ops for us) and
    // sets force_x=80, force_y=50 so store_mode_params() uses those.
    model.phys_mem.write16(setup_base + 0x1FA, 0x0F01);

    // Pre-populate BIOS Data Area (BDA) at 0x400-0x4FF so the setup code's
    // store_mode_params() reads correct VGA 80x50 values into screen_info.
    model.phys_mem.write8(0x449, 3);        // Current video mode: 80-col color text
    model.phys_mem.write16(0x44A, 80);      // Number of screen columns
    model.phys_mem.write16(0x44C, 0x2000);  // Video page size (8192 bytes)
    model.phys_mem.write16(0x44E, 0);       // Current video page start address
    model.phys_mem.write16(0x450, 0);       // Cursor position for page 0
    model.phys_mem.write16(0x460, 0x0607);  // Cursor shape: start=6, end=7 (8px font)
    model.phys_mem.write8(0x462, 0);        // Current video page number
    model.phys_mem.write16(0x463, 0x3D4);   // CRTC port address (color)
    model.phys_mem.write8(0x484, 49);       // Number of rows - 1 (50 rows)
    model.phys_mem.write16(0x485, 8);       // Character height: 8 pixels
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
// Generates make+break for the key, with Shift if needed.
static void push_key(KeyboardController &kbd, int ch) {
  if (ch < 0 || ch >= 128) return;
  u8 sc = ascii_to_scancode[ch];
  if (sc == 0) return;

  bool shift = needs_shift(ch);
  // Ctrl+letter: the ASCII code is 1-26, scancode is for the letter,
  // and we need to send Ctrl (scancode 0x1D) make/break around it.
  bool ctrl = (ch >= 1 && ch <= 26);

  if (ctrl)  kbd.push_scancode(0x1D);       // Ctrl make
  if (shift) kbd.push_scancode(0x2A);       // LShift make
  kbd.push_scancode(sc);                     // key make
  kbd.push_scancode(sc | 0x80);              // key break
  if (shift) kbd.push_scancode(0x2A | 0x80); // LShift break
  if (ctrl)  kbd.push_scancode(0x1D | 0x80); // Ctrl break
}

// =========================================================================
// VGA text mode renderer — draws the 80×50 framebuffer using ncurses.
// Row 50 (below the VGA area) is used as a status line.
// =========================================================================

static constexpr int VGA_COLS = 80;
static constexpr int VGA_ROWS = 50;

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
      memcmp(current, vga_shadow, sizeof(current)) == 0)
    return;

  // Clip to terminal size, leaving one row for status line
  int max_row = std::min(VGA_ROWS, LINES - 1);
  int max_col = std::min(VGA_COLS, COLS);

  for (int row = 0; row < max_row; row++) {
    for (int col = 0; col < max_col; col++) {
      int idx = (row * VGA_COLS + col) * 2;
      u8 ch = current[idx];
      u8 attr = current[idx + 1];
      int fg = attr & 0x07;       // base fg color (0-7)
      bool bright = attr & 0x08;  // bright/bold bit
      int bg = (attr >> 4) & 0x07;

      // Replace non-printable characters with space
      if (ch < 0x20 || ch == 0x7F) ch = ' ';

      int pair = vga_color_pair(fg, bg);
      attr_t a = COLOR_PAIR(pair);
      if (bright) a |= A_BOLD;

      mvaddch(row, col, ch | a);
    }
  }

  // Position cursor
  int crow = cursor / VGA_COLS;
  int ccol = cursor % VGA_COLS;
  if (crow >= 0 && crow < max_row && ccol >= 0 && ccol < max_col)
    move(crow, ccol);

  refresh();

  memcpy(vga_shadow, current, sizeof(current));
  vga_shadow_cursor = cursor;
  vga_shadow_valid = true;
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
  DisplayMode display_mode = DISPLAY_SERIAL;
  const char *bios_path = nullptr;
  const char *hda_path = nullptr;
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
    } else if (strcmp(argv[first_arg], "-vga") == 0) {
      display_mode = DISPLAY_VGA;
      first_arg++;
    } else if (strcmp(argv[first_arg], "-b") == 0 && first_arg + 1 < argc) {
      bios_path = argv[first_arg + 1];
      first_arg += 2;
    } else if (strcmp(argv[first_arg], "-hda") == 0 && first_arg + 1 < argc) {
      hda_path = argv[first_arg + 1];
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
      u8 *vga = read_file("vgabios.bin", &vga_size);
      if (vga) {
        // Fix ROM checksum: sum of all bytes must be 0 (mod 256).
        u8 sum = 0;
        for (size_t i = 0; i < vga_size; i++) sum += vga[i];
        vga[vga_size - 1] -= sum;
        // Store the ROM so it can be read at both C0000 (legacy) and
        // the PCI ROM BAR address (0xFEB00000). The rom_read intercept
        // serves this data for reads, surviving SeaBIOS's memset(C0000,0).
        model.phys_mem.load_vga_rom(vga, vga_size, 0xFEB00000ULL);
        fprintf(stderr, "sail-x86-system: VGA BIOS at 0xC0000 (%zu bytes, checksum OK)\n", vga_size);
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
      if (!model.ata.open(hda_path)) {
        fprintf(stderr, "Failed to open disk image: %s\n", hda_path);
        return 1;
      }
      fprintf(stderr, "sail-x86-system: HDA=%s\n", hda_path);
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

  u64 insn_count = 0;

  // PIT timer: tick every N instructions to generate periodic interrupts.
  // The PIT runs at 1.193182 MHz. With a simulated TSC incrementing by
  // 1000 per instruction (~1GHz virtual CPU), 1193 PIT cycles per 1000
  // instructions matches the real PIT/CPU ratio, so SeaBIOS's timer
  // calibration produces consistent results (~1GHz).
  const u64 PIT_TICK_INTERVAL = 1000;   // Tick PIT every 1K instructions
  const u64 PIT_CYCLES_PER_TICK = 1193; // ~1ms worth of PIT cycles
  u64 next_pit_tick = PIT_TICK_INTERVAL;

  // VGA refresh: render framebuffer every 50K instructions (~20 fps at 1M ips)
  const u64 VGA_REFRESH_INTERVAL = 50000;
  u64 next_vga_refresh = VGA_REFRESH_INTERVAL;

  // Ctrl-a escape state: when Ctrl-a is pressed, the next key decides the action.
  // Ctrl-a x = quit. Ctrl-a Ctrl-a = send literal Ctrl-a.
  bool ctrl_a_pending = false;

  // Spin loop detector: if RIP stays within a tiny range for too long,
  // the kernel is stuck (e.g., panic delay_loop alternating 2 addresses).
  // Disabled in interactive mode where the idle loop is expected.
  u64 spin_base = 0;
  u64 spin_count = 0;
  u64 spin_total = 0;  // cumulative count across re-entries
  const u64 SPIN_THRESHOLD = interactive ? UINT64_MAX : 50000000;

  // Handle SIGTERM/SIGINT gracefully so the VGA dump runs on timeout
  static volatile bool got_signal = false;
  signal(SIGTERM, [](int) { got_signal = true; });

  while (!model.should_exit && !got_signal) {
    // Print progress periodically
    if (curses_active) {
      if (insn_count % 1000000 == 0)
        update_status_line("%luM insns  RIP=%04x:%016lx",
                           insn_count / 1000000,
                           (u16)model.zSegReg.data[x86::SEG_CS], (u64)model.zRIP);
    } else {
      if (insn_count % 5000000 == 0 && insn_count > 0)
        fprintf(stderr, "[progress] %luM insns, RIP=%04x:%016lx\n",
                insn_count / 1000000,
                (u16)model.zSegReg.data[x86::SEG_CS], (u64)model.zRIP);
    }

    if (debug) {
      const char *mode_str = (model.zcur_mode == x86::zLongMode) ? "L" :
                             (model.zcur_mode == x86::zProtectedMode) ? "P" :
                             (model.zcur_mode == x86::zRealMode) ? "R" : "C";
      fprintf(stderr, "[%lu] %04x:%04lx RSP=0x%lx mode=%s CR0=0x%lx\n",
              insn_count, (u16)model.zSegReg.data[x86::SEG_CS],
              (u64)model.zRIP,
              (u64)model.zGPR.data[4], mode_str,
              (u64)model.zCR0);
    }

    model.zstep(UNIT);
    model.tsc += 1000;  // ~1GHz virtual CPU


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
          u64 cs_base = model.zSegCache.data[x86::SEG_CS].zseg_base;
          u64 linear = cs_base + rip;
          fprintf(stderr, "  CS.base=0x%lx linear=0x%lx\n", cs_base, linear);
          fprintf(stderr, "  bytes at linear:");
          for (int b = 0; b < 16; b++)
            fprintf(stderr, " %02x", model.phys_mem.read8(linear + b));
          fprintf(stderr, "\n");
          fprintf(stderr, "  RAX=0x%lx RCX=0x%lx RDX=0x%lx RBX=0x%lx\n",
                  (u64)model.zGPR.data[0], (u64)model.zGPR.data[1],
                  (u64)model.zGPR.data[2], (u64)model.zGPR.data[3]);
          fprintf(stderr, "  RSI=0x%lx RDI=0x%lx\n",
                  (u64)model.zGPR.data[6], (u64)model.zGPR.data[7]);
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

    if (model.zfault_pending) {
      i64 vec = model.zfault_vector;
      u32 err = model.zfault_error_code;
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
          fprintf(stderr, "sail-x86-system: HLT with IF=0 (panic halt) after %lu insns at RIP=0x%lx\n",
                  insn_count, (u64)model.zRIP);
          model.model_fini();
          return 1;
        }
        // Wait for an interrupt: poll stdin + tick PIT until something fires
        while (!model.pic_master.has_pending()) {
          if (poll_stdin) {
            if (curses_active) {
              // In curses mode, use getch() and push scancodes to i8042
              int ch;
              while ((ch = getch()) != ERR) {
                if (ctrl_a_pending) {
                  ctrl_a_pending = false;
                  if (ch == 'x' || ch == 'X') {
                    model.model_fini();
                    return 0;
                  }
                  if (ch == 0x01) push_key(model.kbd, 0x01);
                  continue;
                }
                if (ch == 0x01) { ctrl_a_pending = true; continue; }
                push_key(model.kbd, ch);
              }
              if (model.kbd.has_data())
                model.pic_master.raise_irq(1);
              // Render VGA while waiting
              render_vga_text(model);
              napms(10);
            } else {
              struct pollfd pfd = { STDIN_FILENO, POLLIN, 0 };
              if (poll(&pfd, 1, 10 /*ms*/) > 0) {
                u8 buf[64];
                ssize_t n = read(STDIN_FILENO, buf, sizeof(buf));
                for (ssize_t i = 0; n > 0 && i < n; i++) {
                  if (ctrl_a_pending) {
                    ctrl_a_pending = false;
                    if (buf[i] == 'x' || buf[i] == 'X') {
                      fprintf(stderr, "\nsail-x86-system: Ctrl-a x — exiting\n");
                      model.model_fini();
                      return 0;
                    }
                    if (buf[i] == 0x01) model.uart.rx_push(0x01);
                    continue;
                  }
                  if (buf[i] == 0x01) { ctrl_a_pending = true; continue; }
                  model.uart.rx_push(buf[i]);
                }
              }
            }
            if (model.uart.has_irq())
              model.pic_master.raise_irq(4);
          }
          if (model.pit.tick(PIT_CYCLES_PER_TICK))
            model.pic_master.raise_irq(0);
        }
        // Advance RIP past the HLT instruction (1 byte, opcode 0xF4).
        // On real x86, when an interrupt wakes the CPU from HLT, execution
        // resumes at the instruction AFTER HLT. Our Sail model sets SysHalted
        // without advancing RIP, so we must do it here.
        model.zRIP = model.zRIP + 1;
        model.zsystem_state = x86::zSysRunning;
        insn_count++;
        continue;
      }
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
          model.pic_master.raise_irq(1);
      } else {
        u8 buf[64];
        ssize_t n = read(STDIN_FILENO, buf, sizeof(buf));
        // For pipes, n==0 means EOF. For TTYs with VMIN=0, n==0 means no data.
        if (n == 0 && !interactive) poll_stdin = false;
        for (ssize_t i = 0; n > 0 && i < n; i++) {
          if (ctrl_a_pending) {
            ctrl_a_pending = false;
            if (buf[i] == 'x' || buf[i] == 'X') {
              fprintf(stderr, "\nsail-x86-system: Ctrl-a x — exiting\n");
              model.should_exit = true;
              break;
            }
            if (buf[i] == 0x01) { // Ctrl-a Ctrl-a = literal Ctrl-a
              model.uart.rx_push(0x01);
            }
            continue;
          }
          if (buf[i] == 0x01) { ctrl_a_pending = true; continue; }
          model.uart.rx_push(buf[i]);
        }
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

    // Keyboard interrupt (IRQ 1): scancode available
    if (model.kbd.has_data()) {
      model.pic_master.raise_irq(1);
    }

    // Periodic VGA refresh
    if (display_mode == DISPLAY_VGA && insn_count >= next_vga_refresh) {
      render_vga_text(model);
      next_vga_refresh = insn_count + VGA_REFRESH_INTERVAL;
    }
  }

  fprintf(stderr, "sail-x86-system: exited after %lu instructions\n", insn_count);

  // Dump VGA framebuffer text content at exit
  if (!curses_active) {
    fprintf(stderr, "=== VGA text ===\n");
    for (int row = 0; row < 25; row++) {
      // Find last non-space character on this line
      int last = -1;
      for (int col = 79; col >= 0; col--) {
        u8 ch = model.phys_mem.read8(0xB8000 + (row * 80 + col) * 2);
        if (ch != 0x20 && ch != 0x00) { last = col; break; }
      }
      if (last < 0) continue;  // skip blank lines
      for (int col = 0; col <= last; col++) {
        u8 ch = model.phys_mem.read8(0xB8000 + (row * 80 + col) * 2);
        fprintf(stderr, "%c", (ch >= 0x20 && ch < 0x7F) ? ch : ' ');
      }
      fprintf(stderr, "\n");
    }
  }

  model.model_fini();
  return model.exit_code;
}

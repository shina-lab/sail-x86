// Test that instructions from higher feature levels raise #UD.
// Usage: insn-ud-test <insn-name>
// Each instruction is encoded as raw bytes to avoid compiler dependencies.
// Expected result: #UD (fault #6, exit code 134).

static _Noreturn void sys_exit(int code) {
    __asm__ volatile("syscall" : : "a"(60), "D"(code) : "rcx", "r11");
    __builtin_unreachable();
}

static void sys_write(int fd, const char *buf, unsigned long len) {
    __asm__ volatile("syscall" : : "a"(1), "D"(fd), "S"(buf), "d"(len)
                     : "rcx", "r11", "memory");
}

static void print(const char *s) {
    unsigned long len = 0;
    while (s[len]) len++;
    sys_write(1, s, len);
}

static int streq(const char *a, const char *b) {
    while (*a && *b && *a == *b) { a++; b++; }
    return *a == *b;
}

static int g_argc;
static char **g_argv;

__attribute__((naked)) void _start(void) {
    __asm__ volatile(
        "mov (%%rsp), %%rdi\n"
        "lea 8(%%rsp), %%rsi\n"
        "mov %%rdi, g_argc(%%rip)\n"
        "mov %%rsi, g_argv(%%rip)\n"
        "call _main\n"
        : : : "memory"
    );
}

void _main(void) {
    int ac = g_argc;
    char **av = g_argv;

    if (ac != 2) {
        print("Usage: insn-ud-test <insn-name>\n");
        sys_exit(1);
    }

    const char *insn = av[1];

    // SSE3: ADDSUBPS xmm0, xmm0  (F2 0F D0 C0)
    if (streq(insn, "addsubps")) {
        __asm__ volatile(".byte 0xf2, 0x0f, 0xd0, 0xc0");
        goto no_ud;
    }

    // SSSE3: PSHUFB xmm0, xmm0  (66 0F 38 00 C0)
    if (streq(insn, "pshufb")) {
        __asm__ volatile(".byte 0x66, 0x0f, 0x38, 0x00, 0xc0");
        goto no_ud;
    }

    // SSE4.1: ROUNDPS xmm0, xmm0, 0  (66 0F 3A 08 C0 00)
    if (streq(insn, "roundps")) {
        __asm__ volatile(".byte 0x66, 0x0f, 0x3a, 0x08, 0xc0, 0x00");
        goto no_ud;
    }

    // SSE4.1: BLENDVPS xmm0, xmm0, <xmm0>  (66 0F 38 14 C0)
    if (streq(insn, "blendvps")) {
        __asm__ volatile(".byte 0x66, 0x0f, 0x38, 0x14, 0xc0");
        goto no_ud;
    }

    // SSE4.1: PBLENDW xmm0, xmm0, 0  (66 0F 3A 0E C0 00)
    if (streq(insn, "pblendw")) {
        __asm__ volatile(".byte 0x66, 0x0f, 0x3a, 0x0e, 0xc0, 0x00");
        goto no_ud;
    }

    // POPCNT r64, r64  (F3 48 0F B8 C0)
    if (streq(insn, "popcnt")) {
        __asm__ volatile(".byte 0xf3, 0x48, 0x0f, 0xb8, 0xc0");
        goto no_ud;
    }

    print("Unknown instruction: ");
    print(insn);
    print("\n");
    sys_exit(2);

no_ud:
    // Instruction executed without #UD — success
    print("ok - ");
    print(insn);
    print(" executed\n");
    sys_exit(0);
}

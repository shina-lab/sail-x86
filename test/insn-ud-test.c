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

    // VPCLMULQDQ xmm0, xmm1, xmm2, 0  (VEX.128.66.0F3A 44: C4 E3 71 44 C2 00)
    // PCLMULQDQ + AVX
    if (streq(insn, "vpclmulqdq-xmm")) {
        __asm__ volatile(".byte 0xc4, 0xe3, 0x71, 0x44, 0xc2, 0x00");
        goto no_ud;
    }

    // VPCLMULQDQ ymm0, ymm1, ymm2, 0  (VEX.256.66.0F3A 44: C4 E3 75 44 C2 00)
    // VPCLMULQDQ extension (CPUID.7.0:ECX[10])
    if (streq(insn, "vpclmulqdq-ymm")) {
        __asm__ volatile(".byte 0xc4, 0xe3, 0x75, 0x44, 0xc2, 0x00");
        goto no_ud;
    }

    // VPCLMULQDQ zmm0, zmm1, zmm2, 0  (EVEX.512.66.0F3A 44: 62 F3 75 48 44 C2 00)
    if (streq(insn, "vpclmulqdq-zmm")) {
        __asm__ volatile(".byte 0x62, 0xf3, 0x75, 0x48, 0x44, 0xc2, 0x00");
        goto no_ud;
    }

    // Same with EVEX.aaa = 001b: the instruction has no opmask, so #UD
    if (streq(insn, "vpclmulqdq-zmm-k1")) {
        __asm__ volatile(".byte 0x62, 0xf3, 0x75, 0x49, 0x44, 0xc2, 0x00");
        goto no_ud;
    }

    // VAESENC xmm0, xmm1, xmm2  (VEX.128.66.0F38 DC: C4 E2 71 DC C2) — AES + AVX
    if (streq(insn, "vaesenc-xmm")) {
        __asm__ volatile(".byte 0xc4, 0xe2, 0x71, 0xdc, 0xc2");
        goto no_ud;
    }

    // VAESENC ymm0, ymm1, ymm2  (VEX.256.66.0F38 DC: C4 E2 75 DC C2)
    // VAES extension (CPUID.7.0:ECX[9])
    if (streq(insn, "vaesenc-ymm")) {
        __asm__ volatile(".byte 0xc4, 0xe2, 0x75, 0xdc, 0xc2");
        goto no_ud;
    }

    // VAESENC zmm0, zmm1, zmm2  (EVEX.512.66.0F38 DC: 62 F2 75 48 DC C2)
    if (streq(insn, "vaesenc-zmm")) {
        __asm__ volatile(".byte 0x62, 0xf2, 0x75, 0x48, 0xdc, 0xc2");
        goto no_ud;
    }

    // Same with EVEX.aaa = 001b: no opmask, so #UD
    if (streq(insn, "vaesenc-zmm-k1")) {
        __asm__ volatile(".byte 0x62, 0xf2, 0x75, 0x49, 0xdc, 0xc2");
        goto no_ud;
    }

    // GFNI: GF2P8MULB xmm0, xmm1  (66 0F 38 CF C1)
    if (streq(insn, "gf2p8mulb")) {
        __asm__ volatile(".byte 0x66, 0x0f, 0x38, 0xcf, 0xc1");
        goto no_ud;
    }

    // GFNI: VGF2P8AFFINEQB ymm0, ymm1, ymm2, 0  (VEX.256.66.0F3A.W1 CE: C4 E3 F5 CE C2 00)
    if (streq(insn, "vgf2p8affineqb-ymm")) {
        __asm__ volatile(".byte 0xc4, 0xe3, 0xf5, 0xce, 0xc2, 0x00");
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

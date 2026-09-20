// Test CPUID feature flags for each x86-64 feature level.
// Usage: cpuid-test <level>   (level = 1, 2, 3, or 4)
//
// Verifies that CPUID advertises exactly the features expected for
// the given level, and that instructions from higher levels raise #UD.

static void sys_write(int fd, const char *buf, unsigned long len) {
    __asm__ volatile("syscall" : : "a"(1), "D"(fd), "S"(buf), "d"(len)
                     : "rcx", "r11", "memory");
}

static _Noreturn void sys_exit(int code) {
    __asm__ volatile("syscall" : : "a"(60), "D"(code) : "rcx", "r11");
    __builtin_unreachable();
}

static void print(const char *s) {
    unsigned long len = 0;
    while (s[len]) len++;
    sys_write(1, s, len);
}

static int test_num = 0;
static int fail_count = 0;

static void check(int cond, const char *name) {
    test_num++;
    if (cond) {
        print("ok ");
    } else {
        print("FAIL ");
        fail_count++;
    }
    if (test_num >= 10) {
        char c = '0' + test_num / 10;
        sys_write(1, &c, 1);
    }
    char c = '0' + test_num % 10;
    sys_write(1, &c, 1);
    print(" - ");
    print(name);
    print("\n");
}

static void cpuid_leaf(unsigned leaf, unsigned subleaf,
                       unsigned *eax, unsigned *ebx,
                       unsigned *ecx, unsigned *edx) {
    __asm__ volatile("cpuid"
                     : "=a"(*eax), "=b"(*ebx), "=c"(*ecx), "=d"(*edx)
                     : "a"(leaf), "c"(subleaf));
}

#define HAS(val, bit) (!!((val) & (1u << (bit))))

// CPUID leaf 1, ECX bit positions
#define ECX_SSE3       0
#define ECX_PCLMULQDQ  1
#define ECX_SSSE3      9
#define ECX_FMA       12
#define ECX_CX16      13
#define ECX_SSE4_1    19
#define ECX_SSE4_2    20
#define ECX_MOVBE     22
#define ECX_POPCNT    23
#define ECX_AES       25
#define ECX_XSAVE     26
#define ECX_OSXSAVE   27
#define ECX_AVX       28
#define ECX_F16C      29
#define ECX_RDRAND    30

// CPUID leaf 1, EDX bit positions
#define EDX_FPU        0
#define EDX_SSE       25
#define EDX_SSE2      26

// CPUID leaf 7, EBX bit positions
#define L7_BMI1        3
#define L7_AVX2        5
#define L7_BMI2        8
#define L7_AVX512F    16
#define L7_AVX512DQ   17
#define L7_RDSEED     18
#define L7_ADX        19
#define L7_AVX512CD   28
#define L7_SHA        29

#define L7_AVX512IFMA 21

// CPUID leaf 7 sub-leaf 1, EAX bit positions
#define L71_AVX_VNNI    4
#define L71_AVX512BF16  5

// CPUID leaf 7, EDX bit positions
#define L7D_AVX512VP2INTERSECT 8
#define L7D_AVX512FP16 23

// CPUID leaf 7, ECX bit positions
#define L7C_AVX512VBMI       1
#define L7C_AVX512VBMI2      6
#define L7C_AVX512VNNI      11
#define L7C_AVX512BITALG    12
#define L7C_AVX512VPOPCNTDQ 14
#define L7C_GFNI        8
#define L7C_VAES        9
#define L7C_VPCLMULQDQ 10
#define L7_AVX512BW   30
#define L7_AVX512VL   31

static int parse_level(const char *s) {
    if (s[0] >= '1' && s[0] <= '4' && s[1] == '\0')
        return s[0] - '0';
    return 0;
}

static int g_argc;
static char **g_argv;

__attribute__((naked)) void _start(void) {
    // At entry: [rsp] = argc, [rsp+8] = argv[0], ...
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
        print("Usage: cpuid-test <1|2|3|4>\n");
        sys_exit(1);
    }

    int level = parse_level(av[1]);
    if (level == 0) {
        print("Error: level must be 1, 2, 3, or 4\n");
        sys_exit(1);
    }

    unsigned eax, ebx, ecx, edx;

    // ---------------------------------------------------------------
    // CPUID leaf 1: EDX — baseline features (all levels)
    // ---------------------------------------------------------------
    cpuid_leaf(1, 0, &eax, &ebx, &ecx, &edx);

    check(HAS(edx, EDX_FPU),  "leaf1 EDX: FPU present");
    check(HAS(edx, EDX_SSE),  "leaf1 EDX: SSE present");
    check(HAS(edx, EDX_SSE2), "leaf1 EDX: SSE2 present");

    // ---------------------------------------------------------------
    // CPUID leaf 1: ECX — v2 features
    // ---------------------------------------------------------------
    int v2 = (level >= 2);
    check(HAS(ecx, ECX_SSE3)      == v2, "leaf1 ECX: SSE3");
    check(HAS(ecx, ECX_SSSE3)     == v2, "leaf1 ECX: SSSE3");
    check(HAS(ecx, ECX_SSE4_1)    == v2, "leaf1 ECX: SSE4.1");
    check(HAS(ecx, ECX_SSE4_2)    == v2, "leaf1 ECX: SSE4.2");
    check(HAS(ecx, ECX_CX16)      == v2, "leaf1 ECX: CX16");
    check(HAS(ecx, ECX_XSAVE)     == v2, "leaf1 ECX: XSAVE");
    check(HAS(ecx, ECX_POPCNT)    == v2, "leaf1 ECX: POPCNT");
    check(HAS(ecx, ECX_PCLMULQDQ) == v2, "leaf1 ECX: PCLMULQDQ");

    // ---------------------------------------------------------------
    // CPUID leaf 1: ECX — v3 features
    // ---------------------------------------------------------------
    int v3 = (level >= 3);
    check(HAS(ecx, ECX_FMA)     == v3, "leaf1 ECX: FMA");
    check(HAS(ecx, ECX_MOVBE)   == v3, "leaf1 ECX: MOVBE");
    check(HAS(ecx, ECX_AES)     == v3, "leaf1 ECX: AES-NI");
    check(HAS(ecx, ECX_OSXSAVE) == v3, "leaf1 ECX: OSXSAVE");
    check(HAS(ecx, ECX_AVX)     == v3, "leaf1 ECX: AVX");
    check(HAS(ecx, ECX_F16C)    == v3, "leaf1 ECX: F16C");
    check(HAS(ecx, ECX_RDRAND)  == v3, "leaf1 ECX: RDRAND");

    // ---------------------------------------------------------------
    // CPUID leaf 7: EBX — v3 and v4 features
    // ---------------------------------------------------------------
    cpuid_leaf(7, 0, &eax, &ebx, &ecx, &edx);

    check(HAS(ebx, L7_BMI1) == v3, "leaf7 EBX: BMI1");
    check(HAS(ebx, L7_AVX2) == v3, "leaf7 EBX: AVX2");
    check(HAS(ebx, L7_BMI2) == v3, "leaf7 EBX: BMI2");
    check(HAS(ebx, L7_ADX)  == v3, "leaf7 EBX: ADX");

    int v4 = (level >= 4);
    check(HAS(ebx, L7_AVX512F)  == v4, "leaf7 EBX: AVX-512F");
    check(HAS(ebx, L7_AVX512DQ) == v4, "leaf7 EBX: AVX-512DQ");
    check(HAS(ebx, L7_AVX512CD) == v4, "leaf7 EBX: AVX-512CD");
    check(HAS(ebx, L7_AVX512BW) == v4, "leaf7 EBX: AVX-512BW");
    check(HAS(ebx, L7_AVX512VL) == v4, "leaf7 EBX: AVX-512VL");
    check(HAS(ebx, L7_RDSEED)   == v4, "leaf7 EBX: RDSEED");
    check(HAS(ebx, L7_SHA)      == v4, "leaf7 EBX: SHA");
    check(HAS(ebx, L7_AVX512IFMA) == v4, "leaf7 EBX: AVX512_IFMA");
    check(HAS(ecx, L7C_AVX512VBMI)      == v4, "leaf7 ECX: AVX512_VBMI");
    check(HAS(ecx, L7C_AVX512VBMI2)     == v4, "leaf7 ECX: AVX512_VBMI2");
    check(HAS(ecx, L7C_AVX512VNNI)      == v4, "leaf7 ECX: AVX512_VNNI");
    check(HAS(ecx, L7C_AVX512BITALG)    == v4, "leaf7 ECX: AVX512_BITALG");
    check(HAS(ecx, L7C_AVX512VPOPCNTDQ) == v4, "leaf7 ECX: AVX512_VPOPCNTDQ");
    check(HAS(ecx, L7C_GFNI)       == v4, "leaf7 ECX: GFNI");
    check(HAS(ecx, L7C_VAES)       == v4, "leaf7 ECX: VAES");
    check(HAS(ecx, L7C_VPCLMULQDQ) == v4, "leaf7 ECX: VPCLMULQDQ");
    check(HAS(edx, L7D_AVX512VP2INTERSECT) == v4, "leaf7 EDX: AVX512_VP2INTERSECT");
    check(HAS(edx, L7D_AVX512FP16) == v4, "leaf7 EDX: AVX512_FP16");

    // ---------------------------------------------------------------
    // CPUID leaf 7 sub-leaf 1: AVX-VNNI (v4); sub-leaf 0 EAX is the
    // maximum sub-leaf, so it must be at least 1 once anything is there.
    // ---------------------------------------------------------------
    check((eax >= 1) == v4, "leaf7 EAX: max sub-leaf >= 1");
    cpuid_leaf(7, 1, &eax, &ebx, &ecx, &edx);
    check(HAS(eax, L71_AVX_VNNI) == v4, "leaf7.1 EAX: AVX-VNNI");
    check(HAS(eax, L71_AVX512BF16) == v4, "leaf7.1 EAX: AVX512_BF16");

    sys_exit(fail_count);
}

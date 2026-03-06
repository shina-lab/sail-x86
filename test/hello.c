// Minimal hello world using raw syscalls (no libc).

static void sys_write(int fd, const char *buf, unsigned long len) {
    __asm__ volatile(
        "syscall"
        :
        : "a" (1),        // syscall number: write
          "D" (fd),        // rdi: fd
          "S" (buf),       // rsi: buf
          "d" (len)        // rdx: len
        : "rcx", "r11", "memory"
    );
}

static void sys_exit(int code) {
    __asm__ volatile(
        "syscall"
        :
        : "a" (60),       // syscall number: exit
          "D" (code)       // rdi: exit code
        : "rcx", "r11"
    );
    __builtin_unreachable();
}

void _start(void) {
    sys_write(1, "Hello, world!\n", 14);
    sys_exit(0);
}

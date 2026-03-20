// Minimal 32-bit static binary for testing compat mode.
// Uses int 0x80 directly — no glibc, no C runtime.
// Build: gcc -m32 -nostdlib -static -o hello32 hello32.S

.section .text
.globl _start
_start:
    // write(1, msg, len)
    movl $4, %eax          // syscall number: __NR_write (32-bit)
    movl $1, %ebx          // fd: stdout
    leal msg, %ecx         // buf: message
    movl $(msg_end - msg), %edx  // count
    int  $0x80

    // exit(0)
    movl $1, %eax          // syscall number: __NR_exit (32-bit)
    xorl %ebx, %ebx        // status: 0
    int  $0x80

.section .rodata
msg:
    .ascii "Hello from 32-bit compatibility mode!\n"
msg_end:

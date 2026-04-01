// Minimal 32-bit static binary for testing compat mode.
// Build: gcc -m32 -static -O2 -o hello32 hello32.c

#include <stdio.h>

int main(void) {
    printf("Hello from 32-bit compatibility mode!\n");
    return 0;
}

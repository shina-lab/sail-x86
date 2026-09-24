bits 16
org 0x7c00
cli
xor ax, ax
mov ds, ax
mov ss, ax
mov sp, 0x7c00
mov word [6*4], handler
mov word [6*4+2], 0
int 6
after_int:
nop
ud2
handler:
mov bp, sp
cmp word [ss:bp], after_int
jne fault
iret
fault:
cli
hlt
times 510-($-$$) db 0
dw 0xaa55

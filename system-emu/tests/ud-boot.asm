bits 16
org 0x7c00
cli
xor ax, ax
mov ds, ax
mov ss, ax
mov sp, 0x7c00
mov word [6*4], handler
mov word [6*4+2], 0
ud2
handler:
cli
hlt
times 510-($-$$) db 0
dw 0xaa55

bits 16
org 0x7c00
cli
xor ax, ax
mov ds, ax
mov ss, ax
mov sp, 0x7c00
sti
xor ax, ax
int 0x16
cmp ax, 0x4200                 ; F8
jne fail
xor ax, ax
int 0x16
cmp ax, 0x4800                 ; Up arrow
jne fail
xor ax, ax
int 0x16
cmp ax, 0x5000                 ; Down arrow
jne fail
mov si, message
next:
lodsb
test al, al
jz done
mov dx, 0x3f8
out dx, al
jmp next
fail:
mov al, '!'
mov dx, 0x3f8
out dx, al
done:
cli
hlt
message: db 'KEYBOARD PASS', 13, 10, 0
times 510-($-$$) db 0
dw 0xaa55

; Verify firmware allocation and CPU I/O routing of the PIIX IDE BAR.
bits 16
org 0x7c00
    cli
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7c00
    mov dx, 0xcf8
    mov eax, 0x80000920
    out dx, eax
    mov dx, 0xcfc
    in eax, dx
    test eax, 1
    jz failed
    and eax, 0xfffffff0
    jz failed
    cmp eax, 0xfff0
    ja failed
    mov bx, ax
    lea dx, [bx+2]
    mov al, 0x64
    out dx, al                 ; primary: W1C interrupt, capability bits
    in al, dx
    cmp al, 0x60
    jne failed
    lea dx, [bx+10]
    mov al, 0x24
    out dx, al                 ; secondary independent status
    in al, dx
    cmp al, 0x20
    jne failed
    lea dx, [bx+4]
    mov eax, 0x1234567f
    out dx, eax                ; PRDT uses all four byte lanes
    in eax, dx
    cmp eax, 0x1234567c
    jne failed
    lea dx, [bx+2]
    in al, dx
    cmp al, 0x60
    jne failed
    mov si, ok
    jmp print
failed:
    mov si, bad
print:
    mov dx, 0x3f8
.next:
    lodsb
    test al, al
    jz .done
    out dx, al
    jmp .next
.done:
    hlt
ok: db 'IDE PCI BAR READY', 10, 0
bad: db 'IDE PCI BAR FAILED', 10, 0
times 510-($-$$) db 0
dw 0xaa55

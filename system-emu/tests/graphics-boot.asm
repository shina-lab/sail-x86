; SeaVGABIOS integration fixture. Assemble with -DTEST_MODE=0x12/0x13/0x101.
bits 16
org 0x7c00
start:
    cli
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7c00
%if TEST_MODE == 0x101
    mov es, ax
    mov di, 0x500
    mov cx, TEST_MODE
    mov ax, 0x4f01
    int 0x10
    cmp ax, 0x004f
    jne failed
    mov eax, [0x528]             ; VBE mode-info PhysBasePtr
    mov [lfb], eax
    mov bx, TEST_MODE | 0x4000
    mov ax, 0x4f02
    int 0x10
    cmp ax, 0x004f
    jne failed
    cli
    lgdt [gdtr]
    mov eax, cr0
    or al, 1
    mov cr0, eax
    jmp 8:protected
failed:
    cli
    hlt
align 8
gdt: dq 0, 0x00cf9a000000ffff, 0x00cf92000000ffff
gdtr: dw 23
      dd gdt
lfb: dd 0
bits 32
protected:
    mov ax, 16
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov edi, [lfb]
    mov eax, 0x01020304
    mov ecx, 640 * 480 / 4
    rep stosd
    mov esi, message
%else
    mov ax, TEST_MODE
    int 0x10
    mov ax, 0xa000
    mov es, ax
%if TEST_MODE == 0x13
    xor di, di
    mov cx, 320 * 200 / 2
    mov ax, 0x0201
    rep stosw
%else
    mov dx, 0x3c4
    mov ax, 0x0102
    out dx, ax
    mov ax, 0xaaaa
    call plane
    mov ax, 0x0202
    out dx, ax
    mov ax, 0xcccc
    call plane
    mov ax, 0x0402
    out dx, ax
    mov ax, 0xf0f0
    call plane
    mov ax, 0x0802
    out dx, ax
    mov ax, 0xffff
    call plane
%endif
    mov si, message
%endif
    mov dx, 0x3f8
serial:
    lodsb
    test al, al
    jz done
    out dx, al
    jmp serial
done:
    cli                         ; simulator captures framebuffer on this halt
    hlt
%if TEST_MODE == 0x12
plane:
    xor di, di
    mov cx, 640 * 480 / 16
    rep stosw
    ret
%endif
message: db 'GRAPHICS READY', 10, 0
times 510 - ($-$$) db 0
dw 0xaa55

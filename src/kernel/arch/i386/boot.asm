[bits 16]
section .entry
global _start
extern kmain

%define KERNEL_PHYS_BASE 0x20000

_start:
    cli
    mov ax, 0x2000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFF0

    ;enabling A20 line , to be able to access more than 1mb

    in al, 0x92
    or al, 2                        ; setting port 0x92 bit 1
    out 0x92, al

    mov eax, KERNEL_PHYS_BASE       ;absolute physical base address to store in GDT
    add eax, (gdt_start - _start)
    
    mov bx, (gdt_descriptor - _start) ;offset of GDT from start of kernel
    mov [bx + 2], eax

    lgdt [bx]                       ; loads gdt descriptor into GDTR register

    mov eax, cr0                    
    or eax, 1
    mov cr0, eax                    ; the actual conversion to protected mode ()


    db 0x66, 0xEA
    dd (KERNEL_PHYS_BASE + (init_pm_32 - _start))
    dw 0x08

[bits 32]
init_pm_32:
    mov ax, 0x10
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov word [0xB8000], 0x1F50 

    mov esp, 0x90000
    mov ebp, esp
    
    call kmain
    
    cli
.halt:
    hlt
    jmp .halt

align 16
gdt_start:
    dq 0x0000000000000000
    dq 0x00CF9A000000FFFF
    dq 0x00CF92000000FFFF
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd 0
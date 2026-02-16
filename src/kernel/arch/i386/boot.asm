[bits 16]
section .entry
global _start
extern kmain

_start:
    cli
    ; Standardize segments for 0x2000:0000
    mov ax, 0x2000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFF0

    ; Enable A20 (Fast A20)
    in al, 0x92
    or al, 2
    out 0x92, al

    ; --- THE FIX FOR THE RELOCATION ERROR ---
    ; We manually calculate the offset relative to the start of the section.
    ; This bypasses the Linker's 32-bit relocation records.
    
    mov eax, 0x20000            ; Base physical address (0x2000 << 4)
    mov ebx, gdt_start          ; Get the offset of gdt_start
    sub ebx, _start             ; Subtract start of section to get local offset
    add eax, ebx                ; Physical address = Base + Local Offset
    
    ; We do the same for the descriptor pointer
    mov edi, gdt_descriptor
    sub edi, _start             ; Local offset of the descriptor
    
    mov [ds:edi + 2], eax       ; Plug the physical address into the GDT descriptor

    ; Load GDT using the local offset
    lgdt [ds:edi]

    ; Switch to Protected Mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Far Jump to 32-bit code
    ; 0x08 is the Code Selector
    jmp 0x08:init_pm

[bits 32]
init_pm:
    mov ax, 0x10
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; Blue 'P' for Success
    mov word [0xB8000], 0x1F50 

    mov ebp, 0x90000
    mov esp, ebp
    call kmain
    
    cli
    hlt

; --- DATA MUST BE INSIDE THE SAME SECTION ---
align 4
gdt_start:
    dq 0x0000000000000000   ; Null
    dq 0x00CF9A000000FFFF   ; Code (0x08)
    dq 0x00CF92000000FFFF   ; Data (0x10)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd 0
[bits 16]
section .entry
global _start
extern kmain

_start:
    cli
    mov ax, 0x2000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFF0          ; Proper stack for 16-bit mode

    ; Calculate GDT physical address manually to be 100% sure
    ; We are at 0x20000. We add the offset of gdt_start relative to _start.
    mov eax, 0x20000
    add eax, gdt_start - _start
    mov [gdt_descriptor + 2 - _start], eax

    ; Load GDT
    mov si, gdt_descriptor - _start
    lgdt [ds:si]

    ; Switch to Protected Mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Jump to 32-bit code
    push word 0x08
    push dword init_pm
    retf

[bits 32]
init_pm:
    ; Setup segments
    mov ax, 0x10
    mov ds, ax
    mov ss, ax
    mov es, ax
    
    ; DEBUG: Paint the top left of the screen 'P' on Blue
    ; If you see a blue 'P', protected mode is WORKING.
    mov word [0xB8000], 0x1F50 

    mov ebp, 0x90000
    mov esp, ebp
    
    call kmain
    
    cli
    hlt

; --- DATA ---
align 4
gdt_start:
    dq 0x0000000000000000   ; Null
    dq 0x00CF9A000000FFFF   ; Code (Base 0, Limit 4GB)
    dq 0x00CF92000000FFFF   ; Data (Base 0, Limit 4GB)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd 0                    ; Will be filled at runtime by the 'mov [gdt_descriptor+2], eax'
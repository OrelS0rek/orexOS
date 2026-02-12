org 0x0000
bits 16

%define ENDL 0x0D, 0x0A

start:
    ; Update segments
    mov ax, 0x2000
    mov ds, ax
    mov es, ax
    
    ; Print kernel message
    mov si, msg_kernel
    call puts
    
    ; Halt
    cli
    hlt

puts:
    push si
    push ax
    push bx

.loop:
    lodsb
    or al, al
    jz .done
    
    mov ah, 0x0e
    mov bh, 0
    int 0x10
    
    jmp .loop

.done:
    pop bx
    pop ax
    pop si
    ret

msg_kernel: db 'Kernel started successfully!', ENDL, 0
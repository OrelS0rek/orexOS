/* linker.ld - Linker script for kernel */

OUTPUT_FORMAT(elf32-i386)
ENTRY(_start)

SECTIONS
{
    /* Kernel loaded at 0x20000 (physical address) */
    . = 0x20000;
    .entry : { *(.entry) }
    .text  : { *(.text) }
    .rodata : ALIGN(4096)
    {
        *(.rodata)
    }
    
    .data : ALIGN(4096)
    {
        *(.data)
    }
    
    .bss : ALIGN(4096)
    {
        *(COMMON)
        *(.bss)
    }
    
    /* End of kernel */
    _kernel_end = .;
}

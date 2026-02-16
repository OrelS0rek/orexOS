SECTIONS
{
    . = 0x20000;
    .text : {
        *(.entry)
        *(.text)
    }
    .data : { *(.data) }
    .bss  : { *(.bss)  }
}
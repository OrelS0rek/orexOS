#include "idt.h"
#include "util.h"
#include <stdint.h>
#include "vga.h"

void keyboard_handler(struct InterruptRegisters* regs);
char scancode_to_ascii(uint8_t scancode);

void keyboard_init(){
    irq_install_handler(1, keyboard_handler);
}

// acsii decode with gemini, to save time (full table lookup later when needed)
unsigned char kbd_us[128] =
{
    0,  27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b',   /* 0x00 - 0x0E */
  '\t', /* Tab */
  'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',           /* 0x0F - 0x1C */
    0, /* 0x1D - Control */
  'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`',                /* 0x1E - 0x29 */
    0, /* 0x2A - Left Shift */
 '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/',                     /* 0x2B - 0x35 */
    0, /* 0x36 - Right Shift */
  '*',
    0, /* 0x38 - Alt */
  ' ', /* Space bar */
    0, /* 0x3A - Caps lock */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, /* 0x3B - 0x44: F1 to F10 */
    0, /* 0x45 - Num lock */
    0, /* 0x46 - Scroll lock */
    0, /* 0x47 - Home key */
    0, /* 0x48 - Up Arrow */
    0, /* 0x49 - Page Up */
  '-',
    0, /* 0x4B - Left Arrow */
    0,
    0, /* 0x4D - Right Arrow */
  '+',
    0, /* 0x4F - End key */
    0, /* 0x50 - Down Arrow */
    0, /* 0x51 - Page Down */
    0, /* 0x52 - Insert Key */
    0, /* 0x53 - Delete Key */
    0, 0, 0,
    0, /* 0x57 - F11 Key */
    0, /* 0x58 - F12 Key */
    0, /* All others undefined */
};


void keyboard_handler(struct InterruptRegisters* regs){
    (void)regs;
    uint8_t scancode = inPortB(0x60);

    //release press
    if (scancode & 0x80){
        return;
    }

    if (scancode < 128){
        char letter = scancode_to_ascii(scancode);
        if (letter != 0){
            char str[2] = {letter, '\0'};
            vga_print(str, COLOR_WHITE);
        }
    }

}

char scancode_to_ascii(uint8_t scancode){
    return kbd_us[scancode];
}


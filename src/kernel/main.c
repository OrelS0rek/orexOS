// src/kernel/main.c
#include <stdint.h>
#include "vga.h"
#include "idt.h"
#include "keyboard.h"

void keyboard_init();

void kmain(void) {
    keyboard_init();
    initIdt();
    uint8_t bg_color = vga_color(COLOR_BLUE, COLOR_WHITE);
    vga_clear(bg_color);
    
    uint8_t banner_color = vga_color(COLOR_BLUE, COLOR_YELLOW);
    vga_print_at("=====================================", 20, 5, banner_color);
    vga_print_at("      Welcome to OrexOS!            ", 20, 6, banner_color);
    vga_print_at("      32-bit Protected Mode         ", 20, 7, banner_color);
    vga_print_at("      16/2/2026                     ", 20, 8, banner_color);
    vga_print_at("=====================================", 20, 9, banner_color);

    uint8_t text_color = vga_color(COLOR_BLUE, COLOR_WHITE);
    vga_print_at("Version: orexOS v1.0",          20, 12, text_color);
    vga_print_at("Mode:    32-bit Protected Mode", 20, 13, text_color);
    vga_print_at("Emulator: QEMU i386",           20, 14, text_color);
    vga_print_at("Lang:    C + Assembly",         20, 15, text_color);

    uint8_t success_color = vga_color(COLOR_BLUE, COLOR_LIGHT_GREEN);
    vga_print_at("Kernel complete!", 20, 20, success_color);
    __asm__ volatile("sti");
    while (1) { __asm__ volatile("hlt"); }
}
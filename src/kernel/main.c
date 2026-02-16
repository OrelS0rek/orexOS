// src/kernel/main.c
// Main kernel entry point

#include <stdint.h>
#include <stddef.h>

// VGA text mode buffer
#define VGA_MEMORY 0xB8000
#define VGA_WIDTH 80
#define VGA_HEIGHT 25

// color : (background << 4 | letter color)
#define COLOR_BLACK 0
#define COLOR_BLUE 1
#define COLOR_GREEN 2
#define COLOR_CYAN 3
#define COLOR_RED 4
#define COLOR_MAGENTA 5
#define COLOR_BROWN 6
#define COLOR_LIGHT_GREY 7
#define COLOR_DARK_GREY 8
#define COLOR_LIGHT_BLUE 9
#define COLOR_LIGHT_GREEN 10
#define COLOR_LIGHT_CYAN 11
#define COLOR_LIGHT_RED 12
#define COLOR_LIGHT_MAGENTA 13
#define COLOR_YELLOW 14
#define COLOR_WHITE 15

// VGA entry: character + color attribute
static inline uint16_t vga_entry(char c, uint8_t color) {
    return (uint16_t)c | ((uint16_t)color << 8);
}

// clear the screen
void clear_screen(uint8_t color) {
    uint16_t *vga = (uint16_t*)VGA_MEMORY;
    uint16_t blank = vga_entry(' ', color);
    
    for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++) {
        vga[i] = blank;
    }
}

// print a string at (x,y)
void print_at(const char *str, int x, int y, uint8_t color) {
    uint16_t *vga = (uint16_t*)VGA_MEMORY;
    int index = y * VGA_WIDTH + x;
    
    for (int i = 0; str[i] != '\0'; i++) {
        vga[index + i] = vga_entry(str[i], color);
    }
}

// Print a string at the current cursor position 
void print(const char *str, uint8_t color) {
    static int cursor_x = 0;
    static int cursor_y = 0;
    uint16_t *vga = (uint16_t*)VGA_MEMORY;
    
    for (int i = 0; str[i] != '\0'; i++) {
        if (str[i] == '\n') {
            cursor_x = 0;
            cursor_y++;
            if (cursor_y >= VGA_HEIGHT) {
                cursor_y = VGA_HEIGHT - 1;
            }
            continue;
        }
        
        int index = cursor_y * VGA_WIDTH + cursor_x;
        vga[index] = vga_entry(str[i], color);
        
        cursor_x++;
        if (cursor_x >= VGA_WIDTH) {
            cursor_x = 0;
            cursor_y++;
            if (cursor_y >= VGA_HEIGHT) {
                cursor_y = VGA_HEIGHT - 1;
            }
        }
    }
}

// main kernel function - called from boot.asm
void kmain(void) {
    // clear screen with white on blue background
    uint8_t bg_color = (COLOR_BLUE << 4) | COLOR_WHITE; // high 4 bits - background color | low 4 bits letter color
    clear_screen(bg_color);
    
    //welcome message
    uint8_t banner_color = (COLOR_BLUE << 4) | COLOR_YELLOW;
    print_at("=====================================", 20, 5, banner_color);
    print_at("      Welcome to OrexOS!            ", 20, 6, banner_color);
    print_at("      32-bit Protected Mode         ", 20, 7, banner_color);
    print_at("      16/2/2026                     ", 20, 8, banner_color);
    print_at("=====================================", 20, 9, banner_color);
    

    uint8_t text_color = (COLOR_BLUE << 4) | COLOR_WHITE;
    print_at("Version: orexOS v1.0", 20, 12, text_color);
    print_at("Mode:   32-bit Protected Mode", 20, 13, text_color);
    print_at("Emulator:   Qemu-system-i386", 20, 14, text_color);
    print_at("Lang:   C Language + Assembly", 20, 14, text_color);
    
    // success message
    uint8_t success_color = (COLOR_BLUE << 4) | COLOR_LIGHT_GREEN;
    print_at("Kernel complete!", 20, 20, success_color);
    
    // halt cpu to save power
    while (1) {
        __asm__ volatile("hlt");
    }
}
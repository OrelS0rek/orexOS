// src/kernel/main.c
// Main kernel entry point

#include <stdint.h>
#include <stddef.h>

// VGA text mode buffer
#define VGA_MEMORY 0xB8000
#define VGA_WIDTH 80
#define VGA_HEIGHT 25

// Color attributes (background << 4 | foreground)
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

// VGA entry: character + attribute byte
static inline uint16_t vga_entry(char c, uint8_t color) {
    return (uint16_t)c | ((uint16_t)color << 8);
}

// Clear the screen
void clear_screen(uint8_t color) {
    uint16_t *vga = (uint16_t*)VGA_MEMORY;
    uint16_t blank = vga_entry(' ', color);
    
    for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++) {
        vga[i] = blank;
    }
}

// Print a string at a specific position
void print_at(const char *str, int x, int y, uint8_t color) {
    uint16_t *vga = (uint16_t*)VGA_MEMORY;
    int index = y * VGA_WIDTH + x;
    
    for (int i = 0; str[i] != '\0'; i++) {
        vga[index + i] = vga_entry(str[i], color);
    }
}

// Print a string at the current cursor position (simple version)
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

// Main kernel function - called from boot.asm
void kmain(void) {
    // Clear screen with white on blue background
    uint8_t bg_color = (COLOR_BLUE << 4) | COLOR_WHITE;
    clear_screen(bg_color);
    
    // Print banner
    uint8_t banner_color = (COLOR_BLUE << 4) | COLOR_YELLOW;
    print_at("=====================================", 20, 5, banner_color);
    print_at("      Welcome to OrexOS!            ", 20, 6, banner_color);
    print_at("      32-bit Protected Mode         ", 20, 7, banner_color);
    print_at("      Written in C!                 ", 20, 8, banner_color);
    print_at("=====================================", 20, 9, banner_color);
    
    // Print some info
    uint8_t text_color = (COLOR_BLUE << 4) | COLOR_WHITE;
    print_at("Status: Running", 20, 12, text_color);
    print_at("Mode:   32-bit Protected Mode", 20, 13, text_color);
    print_at("Lang:   C Language", 20, 14, text_color);
    
    // Success message at bottom
    uint8_t success_color = (COLOR_BLUE << 4) | COLOR_LIGHT_GREEN;
    print_at("Kernel initialization complete!", 20, 20, success_color);
    
    // Infinite loop - halt CPU
    while (1) {
        // HLT instruction - saves power
        __asm__ volatile("hlt");
    }
}
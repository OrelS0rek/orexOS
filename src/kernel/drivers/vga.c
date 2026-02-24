#include "vga.h"   

#define VGA_MEMORY  0xB8000
#define VGA_WIDTH   80
#define VGA_HEIGHT  25

static inline uint16_t vga_entry(char c, uint8_t color) {
    return (uint16_t)c | ((uint16_t)color << 8);
}

uint8_t vga_color(uint8_t bg, uint8_t fg) {
    return (bg << 4) | fg;
}

void vga_clear(uint8_t color) {
    uint16_t *vga = (uint16_t*)VGA_MEMORY;
    uint16_t blank = vga_entry(' ', color);
    for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++) {
        vga[i] = blank;
    }
}

void vga_print_at(const char *str, int x, int y, uint8_t color) {
    uint16_t *vga = (uint16_t*)VGA_MEMORY;
    int index = y * VGA_WIDTH + x;
    for (int i = 0; str[i] != '\0'; i++) {
        vga[index + i] = vga_entry(str[i], color);
    }
}

void vga_print(const char *str, uint8_t color) {
    static int cursor_x = 0;
    static int cursor_y = 0;
    uint16_t *vga = (uint16_t*)VGA_MEMORY;

    for (int i = 0; str[i] != '\0'; i++) {
        if (str[i] == '\n') {
            cursor_x = 0;
            cursor_y++;
            continue;
        }
        int index = cursor_y * VGA_WIDTH + cursor_x;
        vga[index] = vga_entry(str[i], color);
        cursor_x++;
        if (cursor_x >= VGA_WIDTH) {
            cursor_x = 0;
            cursor_y++;
        }
    }
}
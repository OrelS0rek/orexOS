#include <stdint.h>
#include "util.h"

void keyboard_init();
char scancode_to_ascii(uint8_t scancode);
void keyboard_handler(struct InterruptRegisters* regs);
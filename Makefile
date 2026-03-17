# Tools
ASM    = nasm
CC     = i686-elf-gcc
LD     = i686-elf-ld
OBJCOPY = i686-elf-objcopy

MKFS = /usr/local/sbin/mkfs.fat
MCOPY = /usr/local/bin/mcopy

# Directories
SRC_DIR   = src
BUILD_DIR = build
KERNEL_DIR = $(SRC_DIR)/kernel

# find .c files
C_SOURCES = $(shell find $(KERNEL_DIR) -name '*.c')

# make c file o files
# src/kernel/drivers/vga.c -> build/drivers/vga.o
C_OBJECTS = $(patsubst $(KERNEL_DIR)/%.c, $(BUILD_DIR)/%.o, $(C_SOURCES))

# Output files
BOOTLOADER_BIN = $(BUILD_DIR)/bootloader.bin
KERNEL_BIN     = $(BUILD_DIR)/kernel.bin
FLOPPY_IMG     = $(BUILD_DIR)/main_floppy.img

KERNEL_ENTRY_OBJ = $(BUILD_DIR)/kernel_entry.o
KERNEL_ASM_OBJECTS = $(BUILD_DIR)/cpu/idt_asm.o

GCC_INTERNAL_INC := $(shell $(CC) -print-file-name=include)

CFLAGS = -m32 -ffreestanding -fno-pie -nostdlib -nostdinc \
         -isystem $(GCC_INTERNAL_INC) \
         -fno-builtin -fno-stack-protector \
         -I$(KERNEL_DIR)/include \
         -Wall -Wextra -Werror -O2

LDFLAGS = -m elf_i386 -T linker.ld

# Default target
.PHONY: all
all: floppy_image

# Floppy image
floppy_image: $(FLOPPY_IMG)

$(FLOPPY_IMG): $(BOOTLOADER_BIN) $(KERNEL_BIN)
	@echo "Creating floppy image..."
	dd if=/dev/zero of=$@ bs=512 count=2880 2>/dev/null
	$(MKFS) -F 12 -n "OREXOS" $@
	dd if=$(BOOTLOADER_BIN) of=$@ conv=notrunc bs=1 count=3 2>/dev/null
	dd if=$(BOOTLOADER_BIN) of=$@ conv=notrunc bs=1 count=448 skip=62 seek=62 2>/dev/null
	$(MCOPY) -i $@ $(KERNEL_BIN) "::kernel.bin"
	@echo " Floppy image: $@"

# Bootloader
$(BOOTLOADER_BIN): $(SRC_DIR)/bootloader/boot.asm | always
	$(ASM) $< -f bin -o $@

# Kernel entry
$(KERNEL_ENTRY_OBJ): $(KERNEL_DIR)/arch/i386/boot.asm | always
	$(ASM) $< -f elf32 -o $@

# Kernel ASM objects
$(BUILD_DIR)/cpu/idt_asm.o: $(KERNEL_DIR)/cpu/idt.asm | always
	@mkdir -p $(dir $@)
	$(ASM) $< -f elf32 -o $@

# Kernel binary
$(KERNEL_BIN): $(KERNEL_ENTRY_OBJ) $(KERNEL_ASM_OBJECTS) $(C_OBJECTS) linker.ld
	@echo "Linking kernel.."
	$(LD) $(LDFLAGS) $(KERNEL_ENTRY_OBJ) $(KERNEL_ASM_OBJECTS) $(C_OBJECTS) -o $(BUILD_DIR)/kernel.elf
	$(OBJCOPY) -O binary $(BUILD_DIR)/kernel.elf $@

# Compile ANY .c file found under src/kernel/
# This rule handles all subdirectories automatically
$(BUILD_DIR)/%.o: $(KERNEL_DIR)/%.c | always
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

.PHONY: always
always:
	@mkdir -p $(BUILD_DIR)

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)/*

.PHONY: run
run: floppy_image
	qemu-system-i386 -fda $(FLOPPY_IMG) -boot a -no-reboot

.PHONY: debug
debug: floppy_image
	qemu-system-i386 -fda $(FLOPPY_IMG) -boot a -s -S

.PHONY: inspect
inspect: floppy_image
	mdir -i $(FLOPPY_IMG) ::
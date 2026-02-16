# Makefile for OrexOS with C kernel

# Tools
ASM = nasm
CC = i686-elf-gcc
LD = i686-elf-ld
OBJCOPY = i686-elf-objcopy

MKFS = $(shell which mkfs.fat || \
               ls /usr/local/sbin/mkfs.fat 2>/dev/null || \
               ls /opt/homebrew/sbin/mkfs.fat 2>/dev/null || \
               echo "mkfs.fat_not_found")

MCOPY = /usr/local/bin/mcopy

# dirs
SRC_DIR = src
BUILD_DIR = build
BOOT_DIR = $(SRC_DIR)/bootloader
KERNEL_DIR = $(SRC_DIR)/kernel
KERNEL_ARCH_DIR = $(KERNEL_DIR)/arch/i386

# output files
BOOTLOADER_BIN = $(BUILD_DIR)/bootloader.bin
KERNEL_BIN = $(BUILD_DIR)/kernel.bin
FLOPPY_IMG = $(BUILD_DIR)/main_floppy.img

# code files
BOOT_ASM = $(BOOT_DIR)/boot.asm
KERNEL_ENTRY_ASM = $(KERNEL_ARCH_DIR)/boot.asm
KERNEL_MAIN_C = $(KERNEL_DIR)/main.c

# object files
KERNEL_ENTRY_OBJ = $(BUILD_DIR)/kernel_entry.o
KERNEL_MAIN_OBJ = $(BUILD_DIR)/kernel_main.o

GCC_INTERNAL_INC := $(shell $(CC) -print-file-name=include)

# Compiler flags for kernel
CFLAGS = -m32 -ffreestanding -fno-pie -nostdlib -nostdinc \
		 -isystem $(GCC_INTERNAL_INC) \
         -fno-builtin -fno-stack-protector -Wall -Wextra \
         -Werror -O2

# Linker flags
LDFLAGS = -m elf_i386 -T linker.ld

# target
.PHONY: all
all: floppy_image

# create floppy image
.PHONY: floppy_image
floppy_image: $(FLOPPY_IMG)

$(FLOPPY_IMG): $(BOOTLOADER_BIN) $(KERNEL_BIN)
	@echo "Creating floppy image..."
	# Create a blank 1.44MB file
	dd if=/dev/zero of=$@ bs=512 count=2880 2>/dev/null
	# Format it as FAT12. Use -I to treat it as a fixed file if needed.
	$(MKFS) -F 12 -n "OREXOS" $@
	# Write the bootloader (first 3 bytes, then skip the BPB area)
	dd if=$(BOOTLOADER_BIN) of=$@ conv=notrunc bs=1 count=3 2>/dev/null
	dd if=$(BOOTLOADER_BIN) of=$@ conv=notrunc bs=1 count=448 skip=62 seek=62 2>/dev/null
	# Copy the kernel onto the disk
	$(MCOPY) -i $@ $(KERNEL_BIN) "::kernel.bin"
	@echo "+ Floppy image created: $@"

# Build bootloader (assembly)
$(BOOTLOADER_BIN): $(BOOT_ASM) always
	@echo "Assembling bootloader..."
	$(ASM) $< -f bin -o $@
	@echo "+ Bootloader built: $@"

# Build kernel
$(KERNEL_BIN): $(KERNEL_ENTRY_OBJ) $(KERNEL_MAIN_OBJ) linker.ld
	@echo "Linking kernel..."
	$(LD) $(LDFLAGS) $(KERNEL_ENTRY_OBJ) $(KERNEL_MAIN_OBJ) -o $(BUILD_DIR)/kernel.elf
	$(OBJCOPY) -O binary $(BUILD_DIR)/kernel.elf $@
	@echo "+ Kernel linked: $@"

# Compile kernel entry 
$(KERNEL_ENTRY_OBJ): $(KERNEL_ENTRY_ASM) always
	@echo "Assembling kernel entry..."
	$(ASM) $< -f elf32 -o $@
	@echo "+ Kernel entry assembled"

# Compile kernel main 
$(KERNEL_MAIN_OBJ): $(KERNEL_MAIN_C) always
	@echo "Compiling kernel main (C)..."
	$(CC) $(CFLAGS) -c $< -o $@
	@echo "+ Kernel main compiled"

# Create build directory
.PHONY: always
always:
	@mkdir -p $(BUILD_DIR)

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build directory..."
	rm -rf $(BUILD_DIR)/*
	@echo "+ Clean complete"

# Run in QEMU
.PHONY: run
run: floppy_image
	@echo "Starting QEMU..."
	qemu-system-i386 -fda $(FLOPPY_IMG) -boot a -d cpu_reset,int -D qemu.log -no-reboot

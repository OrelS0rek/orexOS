#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== OrexOS Debug Session ===${NC}\n"

# Build the OS
echo -e "${YELLOW}Building...${NC}"
make clean > /dev/null 2>&1
make floppy_image

if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Build successful!${NC}\n"

# Show what's on the disk
echo -e "${BLUE}Files on disk:${NC}"
mdir -i build/main_floppy.img ::

echo -e "\n${BLUE}Starting QEMU with serial output...${NC}"
echo -e "${YELLOW}Press Ctrl+C to exit${NC}\n"

# Run QEMU with serial output redirected to terminal
qemu-system-x86_64 \
    -fda build/main_floppy.img \
    -boot a \
    -serial stdio \
    -no-reboot \
    -s -S \
    -d cpu_reset \
    -D qemu.log

echo -e "\n${GREEN}Debug session ended${NC}"
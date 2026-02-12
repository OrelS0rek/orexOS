#!/bin/bash

echo "Starting QEMU in debug mode..."
echo "In another terminal, run: gdb -ex 'target remote localhost:1234' -ex 'set architecture i8086'"

qemu-system-x86_64 \
    -fda build/main_floppy.img \
    -boot a \
    -s -S \
    -serial stdio \
    -display none
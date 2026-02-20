# OrexOS

<p align="center">
  <img width="723" height="486" alt="OrexOS Boot Screen" src="https://github.com/user-attachments/assets/2192b086-f248-4cfe-bf1e-27221d7c0548" />
</p>

> A custom x86 operating system built from scratch ,mainly as a project to learn and understand low-level systems programming

## Project Goal

This is a learning project focused on understanding operating systems at the hardware level by building one. 

##  Current Features

### Bootloader
- **FAT12 Filesystem Parsing** — reads root directory and follows cluster chains to locate the kernel
- **BIOS Disk I/O** — converts Logical Block addressing to Cylinder/Head/Sector addressing and handles disk reads using INT 13h
- **Kernel Loading** — loads the kernel binary from disk to memory address 0x20000

### Kernel
- **Real Mode -> Protected Mode Transition**
  - A20 line enabling for full 32-bit addressing
  - Global Descriptor Table (GDT) setup with code and data segments
  - Far jump to flush instruction pipeline and enter protected mode
- **VGA Text Mode Driver** — direct memory-mapped I/O  for display output
- **C Kernel** — kernel changes from assembly to C at `kmain()`

## Details

**Architecture:** x86 (32-bit)  
**Boot Method:** Legacy BIOS  
**Filesystem:** FAT12  
**Memory Model:** Flat segmentation (sements overlapped in memory, but change base on flags and permissions)  
**Emulator:** QEMU i386 (1.44MB floppy disk image)  

##  Build Requirements

- `nasm` — assembler for bootloader and kernel entry
- `i686-elf-gcc` — cross-compiler for freestanding C code
- `i686-elf-ld` — linker with custom linker script
- `dosfstools` — FAT filesystem utilities (mkfs.fat, mcopy)
- `qemu-system-i386` — emulator for testing

##  Building & Running

```bash
# Build the OS
make

# Run in QEMU
make run

# Clean build artifacts
make clean
```

##  Roadmap

- [ ] Interrupt Descriptor Table (IDT) for exception handling
- [ ] Keyboard driver 
- [ ] Physical memory manager (page frame allocator)
- [ ] Heap allocator (malloc/free)
- [ ] Virtual memory (paging)
- [ ] Multitasking and process scheduling
- [ ] System calls and user mode
- [ ] Simple filesystem
- [ ] Network stack (long-term goal)

## Resources

- [OSDev Wiki](https://wiki.osdev.org/) — main OS development community 
- [NanoByte OS from scratch Guide]([https://beej.us/guide/bgnet/](https://youtu.be/9t-SPC7Tczc?si=ESjwVt1U8iqbxq2v)) — mosly used for the Bootloader

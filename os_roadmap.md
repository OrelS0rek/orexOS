# OrexOS Development Roadmap
## From Bare Kernel to Network Stack + Development Environment

---

## Your End Goals

1. **Working Network Stack** - TCP/IP implementation, network card driver, send/receive packets
2. **Development Environment** - Ability to write and run code from within your OS

This is an ambitious but achievable multi-year project. Let's break it down into phases.

---

## Phase 1: Essential Foundations (3-6 months)

### Why These First?
Before networking, you need:
- **Interrupts** - Network cards use interrupts to signal data arrival
- **Memory management** - Network buffers need dynamic allocation
- **Drivers** - Network cards are hardware devices
- **Multitasking** - Network stack runs alongside your programs

### 1.1 Interrupts (2-3 weeks)

**What are interrupts?**
Hardware devices (keyboard, timer, network card) send electrical signals to the CPU saying "I need attention!". The CPU stops what it's doing, runs your handler code, then resumes.

**Components to implement:**

#### Interrupt Descriptor Table (IDT)
```c
// Each IDT entry describes how to handle an interrupt
typedef struct {
    uint16_t offset_low;   // Handler function address (bits 0-15)
    uint16_t selector;     // Code segment selector
    uint8_t  zero;         // Always zero
    uint8_t  type_attr;    // Type and attributes
    uint16_t offset_high;  // Handler function address (bits 16-31)
} __attribute__((packed)) idt_entry_t;

idt_entry_t idt[256];  // 256 possible interrupts

void idt_set_gate(int num, uint32_t handler) {
    idt[num].offset_low = handler & 0xFFFF;
    idt[num].offset_high = (handler >> 16) & 0xFFFF;
    idt[num].selector = 0x08;  // Code segment
    idt[num].type_attr = 0x8E; // Present, ring 0, 32-bit interrupt gate
    idt[num].zero = 0;
}

void idt_install() {
    // Set up IDT entries for all interrupts
    for (int i = 0; i < 256; i++) {
        idt_set_gate(i, (uint32_t)default_handler);
    }
    
    // Load IDT into CPU
    idt_ptr_t idt_ptr;
    idt_ptr.limit = sizeof(idt) - 1;
    idt_ptr.base = (uint32_t)&idt;
    
    __asm__ volatile("lidt %0" : : "m"(idt_ptr));
}
```

#### Exception Handlers
CPU exceptions (division by zero, page fault, etc.) are interrupts 0-31:

```c
// Example: Division by zero handler
void divide_by_zero_handler() {
    print("ERROR: Division by zero!\n", COLOR_RED);
    while(1) { __asm__ volatile("hlt"); }
}

// You need handlers for all 32 exceptions
```

#### Programmable Interrupt Controller (PIC)
The PIC routes hardware interrupts to the CPU. You need to configure it:

```c
void pic_remap(uint8_t offset1, uint8_t offset2) {
    // Remap PIC interrupts to 32-47 (after CPU exceptions)
    outb(0x20, 0x11);  // Initialize PIC1
    outb(0xA0, 0x11);  // Initialize PIC2
    outb(0x21, offset1);  // PIC1 vector offset
    outb(0xA1, offset2);  // PIC2 vector offset
    outb(0x21, 0x04);  // Tell PIC1 about PIC2
    outb(0xA1, 0x02);  // Tell PIC2 its cascade identity
    outb(0x21, 0x01);  // 8086 mode
    outb(0xA1, 0x01);  // 8086 mode
    outb(0x21, 0x0);   // Unmask all interrupts
    outb(0xA1, 0x0);
}
```

**Why this matters for networking:**
Network cards use **IRQ 11** (Interrupt Request 11). When a packet arrives, the card triggers this interrupt, and your handler processes it.

**Learning resources:**
- OSDev Wiki: "Interrupts"
- Tutorial: James Molloy's kernel development tutorial

---

### 1.2 Timer (1 week)

**Why?** Multitasking needs a scheduler that runs periodically. The timer interrupt is your heartbeat.

```c
// Programmable Interval Timer (PIT) - triggers IRQ 0
void timer_init(uint32_t frequency) {
    uint32_t divisor = 1193180 / frequency;  // PIT base frequency
    
    outb(0x43, 0x36);  // Command byte
    outb(0x40, divisor & 0xFF);  // Low byte
    outb(0x40, (divisor >> 8) & 0xFF);  // High byte
}

volatile uint32_t timer_ticks = 0;

void timer_handler() {
    timer_ticks++;
    // Later: call scheduler here
}
```

**What you get:**
- Ability to sleep: `sleep(1000)` waits 1000 ticks
- Periodic execution: run code every N milliseconds
- Foundation for preemptive multitasking

---

### 1.3 Keyboard Driver (1 week)

**Why?** You need input to interact with your OS.

```c
// Keyboard uses IRQ 1 (PS/2 keyboard)
void keyboard_handler() {
    uint8_t scancode = inb(0x60);  // Read from keyboard controller
    
    // Translate scancode to ASCII
    char c = scancode_to_ascii(scancode);
    
    // Add to keyboard buffer
    keyboard_buffer[buffer_write_pos++] = c;
}

char getchar() {
    // Wait for key press
    while (keyboard_buffer[buffer_read_pos] == 0) {
        __asm__ volatile("hlt");  // Wait for interrupt
    }
    return keyboard_buffer[buffer_read_pos++];
}
```

**What you get:**
- Interactive shell
- Text editor (essential for writing code in your OS!)

---

### 1.4 Physical Memory Manager (2-3 weeks)

**Why?** Network buffers, driver memory, process memory all need dynamic allocation.

**Concepts:**

#### Page Frame Allocator
Memory is divided into 4KB pages. Track which pages are free/used:

```c
#define PAGE_SIZE 4096
#define MAX_PAGES (128 * 1024 * 1024 / PAGE_SIZE)  // 128MB

uint32_t *page_bitmap;  // Bitmap of free/used pages

void pmm_init(uint32_t mem_size) {
    uint32_t num_pages = mem_size / PAGE_SIZE;
    
    // Set all pages as used initially
    memset(page_bitmap, 0xFF, num_pages / 8);
    
    // Mark available memory as free
    // (skip reserved areas: 0-1MB, kernel, etc.)
}

void *pmm_alloc_page() {
    // Find first free page in bitmap
    for (uint32_t i = 0; i < MAX_PAGES; i++) {
        if (!test_bit(page_bitmap, i)) {
            set_bit(page_bitmap, i);
            return (void*)(i * PAGE_SIZE);
        }
    }
    return NULL;  // Out of memory
}

void pmm_free_page(void *page) {
    uint32_t page_num = (uint32_t)page / PAGE_SIZE;
    clear_bit(page_bitmap, page_num);
}
```

**What you get:**
- Ability to allocate/free memory
- Foundation for virtual memory (paging)

---

### 1.5 Heap Allocator (malloc/free) (2 weeks)

**Why?** Programs need `malloc()` to allocate arbitrary sizes, not just 4KB pages.

**Simple implementation - First Fit allocator:**

```c
typedef struct block {
    size_t size;
    struct block *next;
    int free;  // 1 if free, 0 if allocated
} block_t;

block_t *heap_start = NULL;

void heap_init(void *start, size_t size) {
    heap_start = (block_t*)start;
    heap_start->size = size - sizeof(block_t);
    heap_start->next = NULL;
    heap_start->free = 1;
}

void *malloc(size_t size) {
    block_t *current = heap_start;
    
    // Find first free block big enough
    while (current != NULL) {
        if (current->free && current->size >= size) {
            current->free = 0;
            return (void*)(current + 1);  // Return pointer after header
        }
        current = current->next;
    }
    
    return NULL;  // No suitable block found
}

void free(void *ptr) {
    if (ptr == NULL) return;
    
    block_t *block = (block_t*)ptr - 1;  // Get header
    block->free = 1;
    
    // TODO: Coalesce adjacent free blocks
}
```

**Later improvements:**
- Better algorithms (buddy allocator, slab allocator)
- Garbage collection
- Memory leak detection

**What you get:**
- Dynamic data structures (linked lists, trees, hash tables)
- String manipulation
- Network packet buffers

---

### 1.6 Virtual Memory (Paging) (3-4 weeks)

**Why?** 
- Each program gets its own isolated address space
- Security: programs can't access each other's memory
- Can use more memory than physically available (swap to disk)

**Concepts:**

#### Page Directory and Page Tables
```c
typedef uint32_t page_directory_t[1024];
typedef uint32_t page_table_t[1024];

page_directory_t *kernel_directory;

void paging_init() {
    // Create kernel page directory
    kernel_directory = (page_directory_t*)pmm_alloc_page();
    memset(kernel_directory, 0, PAGE_SIZE);
    
    // Identity map first 4MB (kernel space)
    page_table_t *kernel_table = (page_table_t*)pmm_alloc_page();
    
    for (int i = 0; i < 1024; i++) {
        kernel_table[i] = (i * PAGE_SIZE) | 0x03;  // Present, R/W
    }
    
    kernel_directory[0] = (uint32_t)kernel_table | 0x03;
    
    // Load page directory into CR3
    __asm__ volatile("mov %0, %%cr3" : : "r"(kernel_directory));
    
    // Enable paging (set bit 31 of CR0)
    uint32_t cr0;
    __asm__ volatile("mov %%cr0, %0" : "=r"(cr0));
    cr0 |= 0x80000000;
    __asm__ volatile("mov %0, %%cr0" : : "r"(cr0));
}
```

**Page fault handler:**
```c
void page_fault_handler(registers_t *regs) {
    uint32_t faulting_address;
    __asm__ volatile("mov %%cr2, %0" : "=r"(faulting_address));
    
    print("Page fault at 0x%x\n", faulting_address);
    
    // Allocate page on demand
    map_page(faulting_address);
}
```

**What you get:**
- Process isolation
- Demand paging (allocate memory only when accessed)
- Memory protection

---

## Phase 2: Process Management (2-4 months)

### 2.1 Basic Multitasking (3-4 weeks)

**Why?** Your network stack needs to run alongside other programs.

**Concepts:**

#### Task Structure
```c
typedef struct task {
    uint32_t id;
    uint32_t esp;  // Stack pointer
    uint32_t ebp;  // Base pointer
    uint32_t eip;  // Instruction pointer
    page_directory_t *page_directory;
    struct task *next;
} task_t;

task_t *current_task;
task_t *ready_queue;
```

#### Context Switch
Save current task state, load next task state:

```c
void switch_task() {
    // Get next task
    task_t *next = current_task->next;
    if (next == NULL) next = ready_queue;
    
    // Save current state
    __asm__ volatile("mov %%esp, %0" : "=r"(current_task->esp));
    __asm__ volatile("mov %%ebp, %0" : "=r"(current_task->ebp));
    
    // Switch page directory
    __asm__ volatile("mov %0, %%cr3" : : "r"(next->page_directory));
    
    // Load next state
    current_task = next;
    __asm__ volatile("mov %0, %%esp" : : "r"(next->esp));
    __asm__ volatile("mov %0, %%ebp" : : "r"(next->ebp));
}
```

#### Scheduler
Called from timer interrupt:

```c
void scheduler() {
    switch_task();
}

void timer_handler() {
    timer_ticks++;
    scheduler();  // Switch tasks every tick
}
```

**What you get:**
- Multiple programs running "simultaneously"
- Background processes (network daemon)

---

### 2.2 System Calls (2 weeks)

**Why?** Programs need to request OS services (write to screen, allocate memory, open network connection).

```c
// User programs call this
int syscall(int num, int arg1, int arg2, int arg3) {
    int ret;
    __asm__ volatile("int $0x80" 
        : "=a"(ret) 
        : "a"(num), "b"(arg1), "c"(arg2), "d"(arg3));
    return ret;
}

// In kernel
void syscall_handler(registers_t *regs) {
    int syscall_num = regs->eax;
    
    switch (syscall_num) {
        case SYS_WRITE:
            sys_write(regs->ebx, (char*)regs->ecx, regs->edx);
            break;
        case SYS_MALLOC:
            regs->eax = (uint32_t)malloc(regs->ebx);
            break;
        case SYS_OPEN_SOCKET:
            regs->eax = socket_open(regs->ebx, regs->ecx);
            break;
        // ... more syscalls
    }
}
```

**System calls you'll need:**
- File operations: `open()`, `read()`, `write()`, `close()`
- Process operations: `fork()`, `exec()`, `exit()`, `wait()`
- Network operations: `socket()`, `bind()`, `listen()`, `accept()`, `send()`, `recv()`
- Memory operations: `malloc()`, `free()`, `mmap()`

---

### 2.3 User Mode vs Kernel Mode (2 weeks)

**Why?** Security. User programs shouldn't be able to crash the kernel or access hardware directly.

**Privilege levels (rings):**
- Ring 0: Kernel (full access)
- Ring 3: User programs (restricted access)

**Set up user mode:**
```c
void enter_user_mode() {
    // Set up user mode segments in GDT
    gdt_set_gate(4, 0, 0xFFFFFFFF, 0xFA, 0xCF);  // User code
    gdt_set_gate(5, 0, 0xFFFFFFFF, 0xF2, 0xCF);  // User data
    
    // Jump to user mode
    __asm__ volatile(
        "cli\n"
        "mov $0x23, %%ax\n"  // User data segment (ring 3)
        "mov %%ax, %%ds\n"
        "mov %%ax, %%es\n"
        "mov %%ax, %%fs\n"
        "mov %%ax, %%gs\n"
        "mov %%esp, %%eax\n"
        "push $0x23\n"  // User data segment
        "push %%eax\n"  // Stack pointer
        "pushf\n"       // EFLAGS
        "push $0x1B\n"  // User code segment (ring 3)
        "push $1f\n"    // Return address
        "iret\n"
        "1:\n"
        : : : "eax"
    );
}
```

**What you get:**
- Protected kernel
- User programs can't crash the OS
- Foundation for security

---

## Phase 3: Storage & Filesystem (2-3 months)

### 3.1 ATA/IDE Disk Driver (2-3 weeks)

**Why?** Need persistent storage for programs, files, network configuration.

```c
void ata_read_sector(uint32_t lba, uint8_t *buffer) {
    // Wait for drive ready
    while (inb(0x1F7) & 0x80) {}
    
    // Send read command
    outb(0x1F6, 0xE0 | ((lba >> 24) & 0x0F));  // Drive + LBA high
    outb(0x1F2, 1);  // Sector count
    outb(0x1F3, lba & 0xFF);
    outb(0x1F4, (lba >> 8) & 0xFF);
    outb(0x1F5, (lba >> 16) & 0xFF);
    outb(0x1F7, 0x20);  // Read command
    
    // Wait for data ready
    while (!(inb(0x1F7) & 0x08)) {}
    
    // Read 512 bytes
    for (int i = 0; i < 256; i++) {
        ((uint16_t*)buffer)[i] = inw(0x1F0);
    }
}
```

---

### 3.2 Filesystem (3-4 weeks)

**Simple filesystem structure:**

```c
// Inode - describes a file
typedef struct {
    uint32_t size;
    uint32_t blocks[12];  // Direct block pointers
    uint32_t indirect;    // Indirect block pointer
    uint32_t type;        // File, directory, etc.
} inode_t;

// Directory entry
typedef struct {
    char name[256];
    uint32_t inode_num;
} dirent_t;

// Filesystem operations
int fs_open(const char *path);
int fs_read(int fd, void *buffer, size_t size);
int fs_write(int fd, const void *buffer, size_t size);
void fs_close(int fd);
```

**What you get:**
- Persistent file storage
- Ability to save programs you write
- Store network configuration

---

## Phase 4: PCI and Device Drivers (2-3 months)

### 4.1 PCI Bus Enumeration (2 weeks)

**Why?** Modern devices (network cards, graphics cards, USB controllers) connect via PCI.

```c
// PCI Configuration Space Access
uint32_t pci_read_config(uint8_t bus, uint8_t slot, uint8_t func, uint8_t offset) {
    uint32_t address = (1 << 31) | (bus << 16) | (slot << 11) | 
                       (func << 8) | (offset & 0xFC);
    outl(0xCF8, address);
    return inl(0xCFC);
}

void pci_scan() {
    for (int bus = 0; bus < 256; bus++) {
        for (int slot = 0; slot < 32; slot++) {
            uint16_t vendor = pci_read_config(bus, slot, 0, 0) & 0xFFFF;
            
            if (vendor != 0xFFFF) {
                uint16_t device = pci_read_config(bus, slot, 0, 0) >> 16;
                uint8_t class = pci_read_config(bus, slot, 0, 8) >> 24;
                
                print("PCI Device: %x:%x class %x\n", vendor, device, class);
                
                // Check if it's a network card
                if (class == 0x02) {  // Network controller
                    init_network_card(bus, slot);
                }
            }
        }
    }
}
```

---

### 4.2 Network Card Driver (4-6 weeks)

**Popular choice: RTL8139** (simple, well-documented, supported by QEMU)

```c
typedef struct {
    uint32_t tx_buffer[4];  // 4 transmit buffers
    uint32_t rx_buffer;     // Receive buffer
    uint16_t io_base;       // I/O port base address
    uint8_t current_tx;     // Current TX buffer
} rtl8139_dev_t;

void rtl8139_init(uint8_t bus, uint8_t slot) {
    // Get I/O base address from PCI config space
    uint32_t bar0 = pci_read_config(bus, slot, 0, 0x10);
    dev.io_base = bar0 & ~0x3;
    
    // Power on the device
    outb(dev.io_base + 0x52, 0x0);
    
    // Software reset
    outb(dev.io_base + 0x37, 0x10);
    while (inb(dev.io_base + 0x37) & 0x10) {}
    
    // Allocate receive buffer (8KB + 16 bytes + 1500 bytes)
    dev.rx_buffer = (uint32_t)kmalloc(8192 + 16 + 1500);
    outl(dev.io_base + 0x30, dev.rx_buffer);
    
    // Enable receive and transmit
    outb(dev.io_base + 0x37, 0x0C);
    
    // Configure receive buffer
    outl(dev.io_base + 0x44, 0xF | (1 << 7));  // Accept all packets
    
    // Enable interrupts
    outw(dev.io_base + 0x3C, 0x0005);  // RX OK, TX OK
}

void rtl8139_send_packet(void *data, uint32_t length) {
    // Copy packet to TX buffer
    memcpy((void*)dev.tx_buffer[dev.current_tx], data, length);
    
    // Send packet
    outl(dev.io_base + 0x20 + (dev.current_tx * 4), length);
    
    dev.current_tx = (dev.current_tx + 1) % 4;
}

void rtl8139_handle_interrupt() {
    uint16_t status = inw(dev.io_base + 0x3E);
    
    if (status & 0x01) {  // RX OK
        // Process received packet
        uint8_t *rx_buf = (uint8_t*)dev.rx_buffer;
        uint32_t packet_length = *(uint16_t*)(rx_buf + 2);
        
        // Pass to network stack
        handle_ethernet_frame(rx_buf + 4, packet_length);
        
        // Acknowledge interrupt
        outw(dev.io_base + 0x3E, 0x01);
    }
}
```

**What you get:**
- Ability to send/receive raw Ethernet frames
- Foundation for network stack

---

## Phase 5: Network Stack (6-12 months)

This is the big one! Networking is complex because of multiple layers.

### 5.1 Ethernet Layer (2-3 weeks)

**Ethernet frame structure:**
```c
typedef struct {
    uint8_t dest_mac[6];
    uint8_t src_mac[6];
    uint16_t ethertype;  // 0x0800 = IPv4, 0x0806 = ARP
    uint8_t payload[];
} __attribute__((packed)) ethernet_frame_t;

void send_ethernet_frame(uint8_t *dest_mac, uint16_t ethertype, 
                         void *payload, uint32_t length) {
    ethernet_frame_t *frame = malloc(sizeof(ethernet_frame_t) + length);
    
    memcpy(frame->dest_mac, dest_mac, 6);
    memcpy(frame->src_mac, my_mac, 6);
    frame->ethertype = htons(ethertype);  // Convert to network byte order
    memcpy(frame->payload, payload, length);
    
    rtl8139_send_packet(frame, sizeof(ethernet_frame_t) + length);
    free(frame);
}
```

---

### 5.2 ARP (Address Resolution Protocol) (1-2 weeks)

**Why?** Maps IP addresses to MAC addresses on local network.

```c
typedef struct {
    uint8_t ip[4];
    uint8_t mac[6];
    uint32_t timestamp;
} arp_entry_t;

arp_entry_t arp_cache[256];

void arp_request(uint8_t *target_ip) {
    arp_packet_t arp;
    arp.hw_type = htons(1);  // Ethernet
    arp.proto_type = htons(0x0800);  // IPv4
    arp.hw_size = 6;
    arp.proto_size = 4;
    arp.opcode = htons(1);  // Request
    
    memcpy(arp.sender_mac, my_mac, 6);
    memcpy(arp.sender_ip, my_ip, 4);
    memset(arp.target_mac, 0, 6);
    memcpy(arp.target_ip, target_ip, 4);
    
    uint8_t broadcast[6] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
    send_ethernet_frame(broadcast, 0x0806, &arp, sizeof(arp));
}
```

---

### 5.3 IP Layer (IPv4) (3-4 weeks)

**IP packet structure:**
```c
typedef struct {
    uint8_t version_ihl;  // Version (4 bits) + Header length (4 bits)
    uint8_t tos;          // Type of service
    uint16_t length;      // Total length
    uint16_t id;          // Identification
    uint16_t flags_offset; // Flags + fragment offset
    uint8_t ttl;          // Time to live
    uint8_t protocol;     // Protocol (TCP=6, UDP=17, ICMP=1)
    uint16_t checksum;    // Header checksum
    uint8_t src_ip[4];
    uint8_t dest_ip[4];
} __attribute__((packed)) ip_header_t;

void send_ip_packet(uint8_t *dest_ip, uint8_t protocol, 
                    void *payload, uint32_t length) {
    ip_header_t *ip = malloc(sizeof(ip_header_t) + length);
    
    ip->version_ihl = 0x45;  // IPv4, 20-byte header
    ip->tos = 0;
    ip->length = htons(sizeof(ip_header_t) + length);
    ip->id = htons(next_ip_id++);
    ip->flags_offset = 0;
    ip->ttl = 64;
    ip->protocol = protocol;
    memcpy(ip->src_ip, my_ip, 4);
    memcpy(ip->dest_ip, dest_ip, 4);
    ip->checksum = 0;
    ip->checksum = ip_checksum((uint16_t*)ip, sizeof(ip_header_t));
    
    memcpy(ip + 1, payload, length);
    
    // Get destination MAC via ARP
    uint8_t *dest_mac = arp_lookup(dest_ip);
    send_ethernet_frame(dest_mac, 0x0800, ip, sizeof(ip_header_t) + length);
    
    free(ip);
}
```

---

### 5.4 ICMP (Ping) (1 week)

**Good first test of your network stack:**

```c
void send_ping(uint8_t *dest_ip) {
    icmp_echo_t ping;
    ping.type = 8;  // Echo request
    ping.code = 0;
    ping.checksum = 0;
    ping.id = htons(1);
    ping.sequence = htons(ping_sequence++);
    ping.checksum = ip_checksum((uint16_t*)&ping, sizeof(ping));
    
    send_ip_packet(dest_ip, 1, &ping, sizeof(ping));
}

void handle_icmp(icmp_header_t *icmp, uint32_t length) {
    if (icmp->type == 8) {  // Echo request
        // Send echo reply
        icmp->type = 0;
        icmp->checksum = 0;
        icmp->checksum = ip_checksum((uint16_t*)icmp, length);
        
        // Send back
        send_ip_packet(src_ip, 1, icmp, length);
    }
}
```

---

### 5.5 UDP (2-3 weeks)

**Simpler than TCP, good starting point:**

```c
typedef struct {
    uint16_t src_port;
    uint16_t dest_port;
    uint16_t length;
    uint16_t checksum;
} __attribute__((packed)) udp_header_t;

void send_udp(uint8_t *dest_ip, uint16_t dest_port, 
              void *data, uint32_t length) {
    udp_header_t *udp = malloc(sizeof(udp_header_t) + length);
    
    udp->src_port = htons(local_port);
    udp->dest_port = htons(dest_port);
    udp->length = htons(sizeof(udp_header_t) + length);
    udp->checksum = 0;  // Optional in IPv4
    
    memcpy(udp + 1, data, length);
    
    send_ip_packet(dest_ip, 17, udp, sizeof(udp_header_t) + length);
    free(udp);
}
```

---

### 5.6 TCP (3-6 months)

**This is the hardest part. TCP is complex:**

- Connection establishment (3-way handshake)
- Reliable delivery (acknowledgments, retransmission)
- Flow control (sliding window)
- Congestion control
- Connection termination (4-way handshake)

**TCP State Machine:**
```c
typedef enum {
    TCP_CLOSED,
    TCP_LISTEN,
    TCP_SYN_SENT,
    TCP_SYN_RECEIVED,
    TCP_ESTABLISHED,
    TCP_FIN_WAIT_1,
    TCP_FIN_WAIT_2,
    TCP_CLOSE_WAIT,
    TCP_CLOSING,
    TCP_LAST_ACK,
    TCP_TIME_WAIT
} tcp_state_t;

typedef struct {
    tcp_state_t state;
    uint32_t local_ip;
    uint16_t local_port;
    uint32_t remote_ip;
    uint16_t remote_port;
    uint32_t send_seq;      // Next sequence number to send
    uint32_t recv_seq;      // Next sequence number expected
    uint32_t send_window;   // Send window size
    uint32_t recv_window;   // Receive window size
    uint8_t *send_buffer;
    uint8_t *recv_buffer;
} tcp_socket_t;
```

**Connection establishment:**
```c
void tcp_connect(tcp_socket_t *sock, uint8_t *ip, uint16_t port) {
    sock->state = TCP_SYN_SENT;
    sock->remote_ip = *(uint32_t*)ip;
    sock->remote_port = port;
    sock->send_seq = random_seq();
    
    // Send SYN packet
    tcp_header_t syn;
    syn.src_port = htons(sock->local_port);
    syn.dest_port = htons(port);
    syn.seq = htonl(sock->send_seq);
    syn.ack = 0;
    syn.flags = TCP_SYN;
    syn.window = htons(sock->recv_window);
    
    send_tcp_packet(sock, &syn);
    
    // Wait for SYN-ACK (with timeout)
    while (sock->state != TCP_ESTABLISHED) {
        // Handle retransmission, timeout, etc.
    }
}
```

**Data transmission:**
```c
void tcp_send(tcp_socket_t *sock, void *data, uint32_t length) {
    // Add to send buffer
    memcpy(sock->send_buffer + sock->send_buffer_used, data, length);
    sock->send_buffer_used += length;
    
    // Send packets (respecting window size)
    while (sock->send_buffer_used > 0 && 
           (sock->send_seq - sock->last_ack) < sock->send_window) {
        uint32_t chunk_size = MIN(MSS, sock->send_buffer_used);
        
        tcp_header_t tcp;
        tcp.src_port = htons(sock->local_port);
        tcp.dest_port = htons(sock->remote_port);
        tcp.seq = htonl(sock->send_seq);
        tcp.ack = htonl(sock->recv_seq);
        tcp.flags = TCP_ACK | TCP_PSH;
        tcp.window = htons(sock->recv_window);
        
        send_tcp_packet_with_data(sock, &tcp, sock->send_buffer, chunk_size);
        
        sock->send_seq += chunk_size;
        sock->send_buffer_used -= chunk_size;
    }
}
```

**What you get:**
- Ability to make HTTP requests
- Download files from the internet
- Host web servers

---

### 5.7 DNS (1-2 weeks)

**Resolve domain names to IP addresses:**

```c
uint32_t dns_resolve(const char *hostname) {
    // Build DNS query
    dns_query_t query;
    query.transaction_id = htons(1234);
    query.flags = htons(0x0100);  // Standard query
    query.questions = htons(1);
    query.answers = 0;
    query.authority = 0;
    query.additional = 0;
    
    // Encode hostname (e.g., "google.com" → "\x06google\x03com\x00")
    uint8_t *qname = encode_dns_name(hostname);
    
    // Send UDP packet to DNS server (8.8.8.8)
    uint8_t dns_server[4] = {8, 8, 8, 8};
    send_udp(dns_server, 53, &query, query_length);
    
    // Wait for response
    // Parse response to get IP address
}
```

---

### 5.8 Application Protocols (Optional)

- **HTTP client** - Download web pages
- **HTTP server** - Host your own website from your OS!
- **SSH client** - Remote login to other systems
- **FTP** - File transfer

---

## Phase 6: Development Environment (3-6 months)

### 6.1 Text Editor (3-4 weeks)

**Essential for writing code in your OS:**

```c
typedef struct {
    char **lines;        // Array of line pointers
    uint32_t num_lines;
    uint32_t cursor_x;
    uint32_t cursor_y;
    uint32_t scroll_offset;
    char filename[256];
} editor_t;

void editor_insert_char(editor_t *ed, char c) {
    char *line = ed->lines[ed->cursor_y];
    
    // Reallocate line to fit new character
    uint32_t len = strlen(line);
    line = realloc(line, len + 2);
    
    // Shift characters right
    memmove(line + ed->cursor_x + 1, line + ed->cursor_x, 
            len - ed->cursor_x + 1);
    
    line[ed->cursor_x] = c;
    ed->cursor_x++;
}

void editor_save(editor_t *ed) {
    int fd = fs_open(ed->filename, O_WRONLY | O_CREAT);
    
    for (uint32_t i = 0; i < ed->num_lines; i++) {
        fs_write(fd, ed->lines[i], strlen(ed->lines[i]));
        fs_write(fd, "\n", 1);
    }
    
    fs_close(fd);
}
```

**Features to add:**
- Syntax highlighting
- Search and replace
- Undo/redo
- Multiple files
- Split view

---

### 6.2 Shell/Command Interpreter (2-3 weeks)

**Your interface to the OS:**

```c
void shell() {
    char command[256];
    
    while (1) {
        print("OrexOS> ", COLOR_GREEN);
        read_line(command, sizeof(command));
        
        if (strcmp(command, "ls") == 0) {
            list_directory("/");
        } else if (strncmp(command, "cd ", 3) == 0) {
            change_directory(command + 3);
        } else if (strncmp(command, "cat ", 4) == 0) {
            cat_file(command + 4);
        } else if (strncmp(command, "ping ", 5) == 0) {
            ping_host(command + 5);
        } else if (strcmp(command, "ifconfig") == 0) {
            show_network_config();
        } else {
            // Try to execute as program
            int pid = fork();
            if (pid == 0) {
                exec(command);
            } else {
                wait(pid);
            }
        }
    }
}
```

---

### 6.3 C Compiler Port (3-6 months)

**To write and compile code IN your OS, you need a compiler.**

**Options:**

1. **Port TCC (Tiny C Compiler)**
   - Small, simple C compiler
   - ~100KB binary
   - Relatively easy to port
   - Good enough for most code

2. **Port GCC**
   - Much harder (GCC is huge)
   - Requires more infrastructure
   - Better optimization

**TCC porting steps:**
```c
// Implement system calls TCC needs
int tcc_open(const char *path, int flags) {
    return fs_open(path, flags);
}

int tcc_read(int fd, void *buf, size_t count) {
    return fs_read(fd, buf, count);
}

// ... more syscalls ...

// Link TCC against your kernel
```

**What you get:**
- Write C programs in your OS
- Compile them without leaving your OS
- Full development environment!

---

### 6.4 Assembler (2-3 weeks)

**If you want to compile assembly in your OS:**

```c
typedef struct {
    char mnemonic[16];
    uint8_t opcode;
    int operands;
} instruction_t;

uint8_t *assemble(const char *source) {
    // Parse assembly source
    // Convert mnemonics to opcodes
    // Resolve labels
    // Generate machine code
}
```

---

### 6.5 Linker (2-3 weeks)

**Combine object files into executables:**

```c
void link_objects(const char **inputs, const char *output) {
    // Read all object files
    // Resolve symbols
    // Relocate addresses
    // Write executable
}
```

---

### 6.6 Standard Library (2-4 weeks)

**Implement common functions programs expect:**

```c
// String functions
size_t strlen(const char *s);
char *strcpy(char *dest, const char *src);
int strcmp(const char *s1, const char *s2);
char *strcat(char *dest, const char *src);

// Memory functions
void *memcpy(void *dest, const void *src, size_t n);
void *memset(void *s, int c, size_t n);
int memcmp(const void *s1, const void *s2, size_t n);

// I/O functions
int printf(const char *format, ...);
int sprintf(char *str, const char *format, ...);

// Math functions
double sqrt(double x);
double sin(double x);
// ...
```

---

## Phase 7: Advanced Features (Ongoing)

### 7.1 Graphics (GUI)

- VGA/VESA graphics modes
- Window manager
- GUI toolkit

### 7.2 USB Support

- USB host controller driver
- USB mass storage (flash drives)
- USB keyboard/mouse

### 7.3 Sound

- Sound Blaster driver
- AC'97 audio
- WAV playback

### 7.4 Advanced Networking

- IPv6 support
- Network encryption (TLS/SSL)
- Firewall
- Packet filtering

### 7.5 Performance

- SMP (multiprocessor) support
- Scheduler improvements
- Better memory allocator
- Disk caching

---

## Realistic Timeline

**Total: 2-3 years working part-time (10-20 hours/week)**

### Year 1: Foundation
- Months 1-3: Interrupts, timers, keyboard, memory management
- Months 4-6: Multitasking, system calls, user mode
- Months 7-9: Filesystem and disk driver
- Months 10-12: PCI and basic network card driver

### Year 2: Networking
- Months 13-15: Ethernet, ARP, IP, ICMP (ping works!)
- Months 16-18: UDP and simple TCP implementation
- Months 19-21: Full TCP with retransmission, flow control
- Months 22-24: DNS, basic HTTP client

### Year 3: Development Environment
- Months 25-27: Text editor and improved shell
- Months 28-30: Port TCC compiler
- Months 31-33: Standard library implementation
- Months 34-36: Polish, debugging, documentation

---

## Learning Resources

### Essential Reading

**Books:**
1. **"Operating Systems: Three Easy Pieces"** - Free online, excellent intro
2. **"The TCP/IP Guide"** - Comprehensive networking reference
3. **"Understanding the Linux Kernel"** - See how professionals do it
4. **"Crafting Interpreters"** - If you want to add a scripting language

**Online:**
1. **OSDev Wiki** (wiki.osdev.org) - Your bible
2. **Beej's Guide to Network Programming** - Networking concepts
3. **Intel Software Developer Manuals** - CPU reference

### Community

- **OSDev Forums** - Ask questions, get help
- **Reddit: r/osdev** - Community and inspiration
- **Discord: OSDev** - Real-time help

---

## Key Success Factors

### 1. Work Incrementally
Don't try to implement everything at once. Get one thing working before moving to the next.

### 2. Test Constantly
After each feature, test thoroughly. Bugs compound quickly.

### 3. Document Your Code
Future you will thank present you:
```c
// BAD:
x = (y << 4) | z;

// GOOD:
// Combine background color (high nibble) with foreground (low nibble)
// to create VGA color attribute byte
x = (background_color << 4) | foreground_color;
```

### 4. Use Version Control
Git is your friend. Commit often.

### 5. Take Breaks
OS development is marathon, not sprint. Burnout is real.

### 6. Celebrate Milestones
When you get ping working, celebrate! When you compile your first program in your OS, celebrate big!

---

## Minimum Viable Network OS

If you want to reach "network stack working" faster, here's the absolute minimum:

**6-12 months intensive work:**

1. Interrupts + Timer (1 month)
2. Basic memory management (1 month)
3. Simple multitasking (1 month)
4. ATA disk driver + simple filesystem (1 month)
5. PCI + RTL8139 driver (1 month)
6. Ethernet + ARP + IP + ICMP (2 months)
7. UDP (1 month)
8. Basic TCP (2-3 months)

**Skip for now:**
- User mode (run everything in kernel)
- Full process management (just simple task switching)
- Advanced filesystem (just enough to load programs)
- GUI (text mode is fine)

---

## Final Thoughts

This is an **amazing** project. Very few people build an OS with networking from scratch. When you finish, you'll understand:

- How computers really work at the lowest level
- How operating systems manage resources
- How the internet works (not just HTTP, but TCP/IP internals)
- How to write robust systems code

**Most importantly:** You'll have an incredible portfolio project. Employers value this kind of deep technical knowledge.

You've already done the hardest part (booting). Everything from here is C code, which you can debug, modify, and understand much easier than assembly.

Good luck! Feel free to ask questions as you progress. The OSDev community is supportive and helpful.

---

**Remember:** This is YOUR OS. Customize it, make it unique, have fun with it!

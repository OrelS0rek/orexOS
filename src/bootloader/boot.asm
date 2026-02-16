org 0x7c00 ;tellin nasm , to treat every address as an offset from 0x7c00 (where BIOS reads)
bits 16 ;BIOS only works in 16 bit real mode

%define ENDL 0x0D, 0x0A

jmp short start
nop
;FAT12 headers
bdb_oem:					db 'MSWIN4.1'
bdb_bytes:					dw 512
bdb_sectors_per_cluster:	db 1
bdb_reserved_sectors:		dw 1
bdb_fat_count: 				db 2
bdb_dir_entries_count:		dw 0E0h
bdb_total_sectors:			dw 2880
bdb_media_descriptor_type:	db 0F0h
bdb_sectors_per_fat:		dw 9
bdb_sectors_per_track:		dw 18
bdb_heads:					dw 2
bdb_hidden_sectors:			dd 0
bdb_large_sector_count:		dd 0

ebr_drive_number:			db 0
							db 0
ebr_signature:				db 29h
ebr_volume_id:				db 12h,	34h, 56h, 78h
ebr_volume_label:			db 'OREX OS    '
ebr_system_id:				db 'FAT12   '

start:
	jmp main

;prints the string loaded to si
puts:
	push si
	push ax
.loop:
	lodsb ;load from si to al
	or al,al ;check if th byte loaded is 0
	jz .done
	mov ah, 0x0e ;specific code to print out
	int 0x10 ;video media interrupts
	jmp .loop
.done:
	pop ax
	pop si
	ret

main:
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 0x7c00  ;setup stack at start of bootloader (grows down)
	
	; set drive 0 for floppy
	xor dl, dl
	mov [ebr_drive_number], dl

	mov si, msg_load
	call puts

	; read root directory to 0x8000
	mov ax, 19
	mov cl, 14
	mov bx, 0x8000
	call disk_read

	; search for KERNEL  BIN
	mov cx, 224             
	mov di, 0x8000
    
.search:
	push di
	push cx
	
	mov si, fname
	mov cx, 11
	repe cmpsb
	
	pop cx
	pop di
	
	je .found
	
	add di, 32
	loop .search
	
	mov si, msg_nf
	call puts
	jmp .halt

.found:
	mov si, msg_ok
	call puts
	
	; get first cluster (di points to start of entry)
	mov ax, [di + 26]
	mov [clust], ax
	
	; load FAT right after the bootloader (0x7c00+512)
	mov ax, 1
	mov cl, 9
	mov bx, 0x7E00
	call disk_read
	
	; load kernel to 0x2000:0
	mov ax, 0x2000
	mov es, ax
	mov bx, 0
	
.load:
	mov ax, [clust]
	add ax, 31
	mov cl, 1
	call disk_read
	add bx, 512
	
	; get next cluster from FAT 
	mov ax, [clust]
	mov dx, ax				;DX = AX
	shr dx, 1				;DX /= 2
	add ax, dx              ; AX =AX+AX/2= cluster * 1.5
	mov si, 0x7E00
	add si, ax
	mov ax, [si]
	
	; Check if cluster is odd or even
	test byte [clust], 1
	jz .even
	shr ax, 4				;handle odd cluster number
	jmp .ck
.even:
	and ax, 0xFFF			;handle even
.ck:
	cmp ax, 0xFF8			;handle EOF
	jae .go
	mov [clust], ax
	jmp .load

.go:
	; Jump to kernel
	mov ax, 0x2000
	mov ds, ax
	mov es, ax
	jmp 0x2000:0			;far jump to kernel

.halt:
	cli
	hlt
	jmp .halt

lba_to_chs:
	push ax
	push dx
	xor dx, dx								;set dx=0 to be ready for div
	div word [bdb_sectors_per_track]		; ax = lba / sectors
	inc dx									; dx = lba % sectors + 1 (1 indexed)
	mov cx, dx								; cx = sector
	xor dx, dx								;set dx=0 to be ready for div
	div word [bdb_heads]					; ax = cylinder, dx = head
	mov dh, dl								; dh = head
	mov ch, al								; ch = cylinder low 8 bits
	shl ah, 6
	or cl, ah								; cl = sector + cylinder high 2 bits
	
	pop ax
	pop ax
	ret

disk_read:
	push ax
	push bx
	push cx
	push dx
	push di
	push cx
	call lba_to_chs
	pop ax
	mov ah, 02h
	mov dl, [ebr_drive_number]
	mov di, 3
.retry:
	pusha
	stc
	int 13h
	jnc .ok
	popa
	xor ah, ah
	int 13h 		;bios interrupt call to read sectors from drive
	dec di
	jnz .retry
	jmp $
.ok:
	popa
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret

fname:		db 'KERNEL  BIN'
clust:		dw 0
msg_load:	db 'Load', ENDL, 0
msg_ok:		db 'OK', ENDL, 0
msg_nf:		db 'NF', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
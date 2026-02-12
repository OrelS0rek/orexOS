org 0x7c00
bits 16

%define ENDL 0x0D, 0x0A

jmp short start
nop

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

puts:
	push si
	push ax
.loop:
	lodsb
	or al,al
	jz .done
	mov ah, 0x0e
	int 0x10
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
	mov sp, 0x7c00
	
	; Force drive 0 for floppy (ignore what BIOS passed in DL)
	xor dl, dl
	mov [ebr_drive_number], dl

	mov si, msg_load
	call puts

	; Read root directory
	; Standard 1.44MB floppy: root dir starts at LBA 19, size 14 sectors
	mov ax, 19
	mov cl, 14
	mov bx, 0x8000			; Load to 0x8000 to avoid conflicts
	call disk_read

	; Search for KERNEL  BIN
	mov cx, 224             
	mov di, 0x8000          ; Point DI to the start of the loaded Root Dir
    
.search:
	; Save the entry pointer before comparison
	push di
	push cx
	
	; Compare: DS:SI with ES:DI
	mov si, fname           ; DS:SI = "KERNEL  BIN"
	mov cx, 11
	repe cmpsb              ; Compare 11 bytes (DI and SI get incremented)
	
	pop cx
	pop di                  ; Restore DI to point to start of entry
	
	je .found               ; Match! DI points to the start of the entry
	
	add di, 32              ; Move to next 32-byte entry
	loop .search
	
	mov si, msg_nf
	call puts
	jmp .halt

.found:
	pop cx                  ; Clean up the stack (we pushed cx before loop)
	mov si, msg_ok
	call puts
	
	; Get first cluster (DI still points to start of entry)
	mov ax, [di + 26]
	mov [clust], ax
	
	; Load FAT to 0x7E00
	mov ax, 1
	mov cl, 9
	mov bx, 0x7E00
	call disk_read
	
	; Load kernel to 0x2000:0
	mov ax, 0x2000
	mov es, ax
	mov bx, 0
	
.load:
	mov ax, [clust]
	add ax, 31
	mov cl, 1
	call disk_read
	add bx, 512
	
	; Get next cluster from FAT
	mov ax, [clust]
	mov dx, ax
	shr dx, 1
	add ax, dx              ; AX = cluster * 1.5
	mov si, 0x7E00
	add si, ax
	mov ax, [si]
	
	; Check if cluster is odd or even
	test byte [clust], 1
	jz .even
	shr ax, 4
	jmp .ck
.even:
	and ax, 0xFFF
.ck:
	cmp ax, 0xFF8
	jae .go
	mov [clust], ax
	jmp .load

.go:
	mov ax, 0x2000
	mov ds, ax
	mov es, ax
	jmp 0x2000:0

.halt:
	cli
	hlt
	jmp .halt

lba_to_chs:
	push ax
	push dx
	xor dx, dx
	div word [bdb_sectors_per_track]
	inc dx
	mov cx, dx
	xor dx, dx
	div word [bdb_heads]
	mov dh, dl              ; DH = head
	mov ch, al              ; CH = cylinder low 8 bits
	shl ah, 6
	or cl, ah               ; CL = sector + cylinder high 2 bits
	
	; Don't pop DX! It has our head value in DH
	pop ax                  ; Discard saved DX
	pop ax                  ; Restore original AX
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
	int 13h
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

fname:		db 'KERNEL  BIN'    ; FIX: Exactly 11 bytes, no trailing space!
clust:		dw 0
msg_load:	db 'Load', ENDL, 0
msg_ok:		db 'OK', ENDL, 0
msg_nf:		db 'NF', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
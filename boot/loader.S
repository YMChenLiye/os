	%include "boot.inc"
	section loader vstart=LOADER_BASE_ADDR
	LOADER_STACK_TOP equ LOADER_BASE_ADDR

;构建gdt及其内部的描述符
	GDT_BASE:			dd		0x00000000
						dd		0x00000000
	CODE_DESC:			dd		0x0000FFFF
						dd		DESC_CODE_HIGH4
	DATA_STACK_DESC:	dd		0x0000FFFF
						dd		DESC_DATA_HIGH4
	VIDEO_DESC:			dd		0x80000007			;limit=(0xbffff-0xb8000)/4k=0x7
						dd		DESC_VIDEO_HIGH4	;此时dpl已经改为0
	
	GDT_SIZE	equ		$ - GDT_BASE
	GDT_LIMIT	equ		GDT_SIZE - 1
	times 60 dq 0					;在此处预留60个描述符的位置
	SELECTOR_CODE 	equ	(0x0001<<3) + TI_GDT + RPL0		;相当于(CODE_DESC - GDT_BASE)/8 + TI_GDT + RPL0
	SELECTOR_DATA	equ	(0x0002<<3) + TI_GDT + RPL0		;同上
	SELECTOR_VIDEO	equ	(0x0003<<3) + TI_GDT + RPL0		;同上

	; total_mem_bytes用于保存内存容量，以字节为单位，此位置比较好记。
	; 当前偏移laoder_bin文件头0x200字节，loader.bin的加载地址是0x900，
	; 所以total_mem_bytes内存中的地址是0xb00。将来在内核中我们会引用此地址
	total_mem_bytes dd 0
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;以下是定义gdt的指针，前2字节是gdt界限，后4字节是gdt起始地址

	gdt_ptr	dw	GDT_LIMIT
			dd	GDT_BASE

	;人工对齐：total_mem_bytes4 +gdt_ptr6 +ards_buf244 +ards_nr2 = 256字节
	ards_buf times 244 db 0
	ards_nr	dw 0		;用于记录ards结构体的数量

	loader_start:


;===================获取内存容量的第一种方法====================
;----------- int 15h ,eax=0000E820h,edx=534D4150h('SMAP') 获取内存布局 ---------

	xor ebx,ebx				;第一次使用时，将ebx置0
	mov edx,0x534d4150		;edx只赋值一次，循环体中不会改变
	mov di,ards_buf			;di指向ards结构体缓冲区
.e820_mem_get_loop:			;循环获取每个ARDS内存范围描述结构
	mov eax,0x0000e820		;执行int 0x15后，eax变为0x534d4150('SMAP'),所以每次执行int前都要更新为子功能号。
	mov ecx,20				;ARDS地址范围描述符结构大小是20字节
	int 0x15
	jc .e820_failed_so_try_e801		;若cf位为1则有错误发生，尝试0xe801子功能
	add di,cx				;成功的话，di增加20字节，使之指向新的ARDS结构位置
	inc word [ards_nr]		;记录ARDS数量
	cmp ebx,0				;若ebx为0且cf不为1，这说明ards全部返回，当前以是最后一个
	jnz	.e820_mem_get_loop

;在所有ards结构中，找出(base_add_low + length_low)的最大值，即内存的容量。
	mov cx,[ards_nr]		;便利每一个ARDS结构体，循环次数是ARDS的数量
	mov ebx,ards_buf		;ebx指向缓冲区中的ARDS结构
	xor	edx,edx				;edx为最大的内存容量，在此先清0
.find_max_mem_area:			;无须判断type是否为1，最大的内存块一定是可被使用
	mov eax,[ebx]			;base_add_low
	add eax,[ebx+8]			;length_low
	add ebx,20				;指向缓冲区中下一个ARDS结构
	cmp edx,eax				;冒泡排序，找出最大，edx寄存器始终是最大的内存容量
	jge	.next_ards
	mov edx,eax				;edx为总内存大小
.next_ards:
	loop .find_max_mem_area
	jmp .mem_get_ok


;===================获取内存容量的第二种方法====================
;-------- int 15h,ax=E801h,获取内存大小，最大支持4G -------------
; 返回后，ax cx 值一样，以KB为单位，bx dx值一样，以64KB为单位
; 在ax和cx寄存器中为低16M，在bx和dx寄存器中为16M到4G。

.e820_failed_so_try_e801:
	mov ax,0xe801
	int 0x15
	jc .e801_failed_so_try88		;若当前e801方法失败，就尝试0x88方法

;1 先算出低15M的内存，ax和cx中是以KB为单位的内存数量，将其转换为以byte为单位
	mov cx,0x400		;cx和ax值一样，cx用作乘数 0x400=1k
	mul cx				;ax*cx     高16为在dx中，低16位在ax中
	shr edx,16
	and eax,0x0000FFFF
	or edx,eax			;edx左移16位，再与eax中的ax部分做 与 运算，相当于将原来ax*1K的答案放在了edx中
	add edx,0x100000	;ax只是15M，所以要加上1MB
	mov esi,edx			;先将低15M的内存容量存入esi寄存器中备份，下面的代码要改变edx的值

;2 再将16MB以上的内存转换成byte为单位，寄存器bx和dx中是以64KB为单位的内存数量
	xor eax,eax
	mov ax,bx
	mov ecx,0x10000		;0x10000=64K
	mul ecx				;32位乘法，默认的被乘数是eax，积为64位，高32位存入edx，低32位存入eax
	add esi,eax			;由于此方法只能测出4G以内的内存，所以32位eax已经足够了，edx肯定为0，只加eax就行了
	mov edx,esi			;edx为总内存大小
	jmp .mem_get_ok



;===================获取内存容量的第三种方法====================
;-------------- int 15h ah=0x88 获取内存大小，只能获取64M以内的内存 --------
.e801_failed_so_try88:
	;int 15后，ax存入的是以kb为单位的内存容量
	mov ah,0x88
	int 0x15
	jc .error_hlt		;cf为1表示出错，3种办法都失败了，只能挂起系统了
	and eax,0x0000FFFF

	;16位乘法，被乘数是ax，积为32位，积的高16为在dx中，低16位在ax中
	mov cx,0x400		;0x400=1K
	mul cx
	shl edx,16
	or edx,eax
	add edx,0x100000	;0x88子功能只会返回1MB以上的内存，所以实际内存大小要加上1MB

.mem_get_ok:
	mov [total_mem_bytes] ,edx		;将内存换位byte单位后存入total_mem_bytes处



;------------------------- 准备进入保护模式 ------------------------------
			;1 打开A20
			;2 加载gdt
			;3 将cr0的pe位置1

	;-------------- 打开A20 ---------
	in al,0x92
	or al,0000_0010B
	out 0x92,al

	;--------------	加载GDT ---------
	lgdt [gdt_ptr]


	;-------------- cr0第0位置1 -----
	mov eax,cr0
	or eax,0x00000001
	mov cr0,eax

	jmp dword SELECTOR_CODE:p_mode_start		;刷新流水线

.error_hlt:				;出错则挂起
	jmp $			

[bits 32]
p_mode_start:
	mov ax,SELECTOR_DATA
	mov ds,ax
	mov es,ax
	mov ss,ax
	mov esp,LOADER_STACK_TOP
	mov ax,SELECTOR_VIDEO
	mov gs,ax

	;创建页目录及页表并初始化页内存位图
	call setup_page

	;要将描述符表地址及偏移量写入内存gdt_ptr，一会用新地址重新加载
	sgdt [gdt_ptr]			;存储到原来gdt所有的位置

	;将gdt描述符中视频段描述符中的段基址 +0xc0000000  (3G)
	mov ebx,[gdt_ptr + 2]
	or dword [ebx + 0x18 + 4],0xc0000000		;视频段是第三个段描述符，每个描述符8字节，故0x18
												;段描述符的高4字节的最高位是段基址的31~24位
	
	;将gdt的基址加上0xc0000000 使其成为内核所在的高地址
	add dword [gdt_ptr + 2] , 0xc0000000

	add esp,0xc0000000			;将栈指针同样映射到内核地址

	; 把页目录地址复制到cr3
	mov eax,PAGE_DIR_TABLE_POS
	mov cr3,eax

	; 打开cr0的pg位(第31位)
	mov eax,cr0
	or eax,0x80000000
	mov cr0,eax

	; 在开启分页后，用gdt新的地址重新加载
	lgdt [gdt_ptr]				; 重新加载

	mov byte [gs:160],'V'		;视频段段基址已经被更新，打印一个字符V表示virtual addr
	

	jmp $



; ----------------  创建页目录及页表  ------------------
setup_page:
;先把页目录占用的空间逐字节清0
	mov ecx,4096		;页目录表占用4KB空间，每次清空一个字节，所以清4K次
	mov esi,0
.clean_page_dir:
	mov byte [PAGE_DIR_TABLE_POS + esi],0
	inc esi
	loop .clean_page_dir

;开始创建页目录项(PDE)
.creat_pde:							; 创建Page Directory Entry
	mov eax,PAGE_DIR_TABLE_POS
	add eax,0x1000					; 0x1000(4K) ,此时eax为第一个页表的位置及属性
	mov ebx,eax						; 此处为ebx赋值，是为.creat_pte做准备,ebx为基址

;  下面将页目录项0和0xc00都存为第一个页表的地址，
;  一个页表可表示4MB内存，这样0xc03fffff(3G+4M)以下的地址和0x003fffff(4M) 以下的地址都指向形同的页表
;  这是为将地址映射为内核地址做准备
	or eax,PG_US_U | PG_RW_W | PG_P			;页目录项的属性RW和p位为1，US为1，表示用户属性，所有特权级别都可以访问。
	mov [PAGE_DIR_TABLE_POS + 0x0],eax		;
	mov [PAGE_DIR_TABLE_POS + 0x0],eax	   	;
	mov [PAGE_DIR_TABLE_POS + 0xc00],eax	;一个页表项占用4字节，0xc00表示第768个页表占用的目录项，0xc00以上的目录项用于内核空间(3G以上)
	sub eax,0x1000
	mov [PAGE_DIR_TABLE_POS + 4092],eax		; 使最后一个目录项指向目录表自己的地址(1023*4)=4092

;下面创建页表项(PTE)
	mov ecx,256							; 1M低端内存 / 每页大小4K = 256
	mov esi,0
	mov edx,PG_US_U | PG_RW_W | PG_P	;属性为7，US=1,RW=1,P=1   (因为是从0地址开始的，所以edx只是赋值了属性，地址都是0，不用赋值)
.creat_pte:								; 创建Page Table Entry	
	mov [ebx + esi*4],edx				; 此时的ebx已经在上面通过eax赋值为0x101000，也就是第一个页表的地址
	add edx,4096						;每页大小是4KB
	inc esi
	loop .creat_pte

;创建内核其他页表的PDE
	mov eax,PAGE_DIR_TABLE_POS
	add eax,0x2000						; 此时eax为第二个页表的位置
	or eax, PG_US_U | PG_RW_W | PG_P	;页目录项的属性US，RW和P位都为1
	mov ebx,PAGE_DIR_TABLE_POS
	mov ecx,254							; 范围为第769~1022的所有的目录项数量
	mov esi,769
.creat_kernel_pde:
	mov [ebx+esi*4],eax
	inc esi
	add eax,0x1000
	loop .creat_kernel_pde
	ret

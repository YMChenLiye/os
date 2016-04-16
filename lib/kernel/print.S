TI_GDT	equ 	0
RPL0	equ		0
SELECTOR_VIDEO	equ		(0x0003<<3) + TI_GDT + RPL0

[bits 32]
section .text
;--------------- put_str --------------------
;put_str 通过put_str来打印以0字符结尾的字符串
;-------------------------------------------
;输入：栈中参数为打印的字符串
;输出：无

global put_str
put_str:
;由于本函数只用到了ebx和ecx，只备份这两个
	push ebx
	push ecx
	xor ecx,ecx					;准备用ecx存储参数
	mov ebx,[esp + 12]			;从栈中得到待打印的字符串地址(2*4字节寄存器+4字节返回地址)
.goon:
	mov cl,[ebx]
	cmp cl,0
	jz .str_over
	push ecx					;为put_char函数传递参数
	call put_char
	add esp,4					;回收栈空间
	inc ebx
	jmp .goon
.str_over:
	pop ecx
	pop ebx
	ret






;---------------  put_char --------------------
;功能描述：把栈中的1个字符写入到光标所在处
;-----------------------------------------------
global put_char
put_char:
	pushad							;备份32位寄存器环境(push all double)
	;需要保证gs中为正确的视频段选择子，为保险起见，每次打印时都为gs赋值
	mov ax,SELECTOR_VIDEO			;不能直接把立即数送入段寄存器
	mov gs,ax

;;;;;	获取当前光标位置 ;;;;;;;;;;;;;
	;先获得高8位
	mov dx,0x03d4		;索引寄存器
	mov al,0x0e			;用于提供光标位置的高8位
	out dx,al			;向端口0x03d4写入0x0e，可以使我们操作0x3d5时就像操作光标的高八位端口
	mov dx,0x03d5
	in al,dx			;得到了光标的高8位
	mov ah,al			;光标的高8位先存储到ah中

	;在获取低8位
	mov dx,0x03d4
	mov al,0x0f			;光标位置的低8位
	out dx,al
	mov dx,0x03d5
	in al,dx			;现在ax就是光标的数值

	;将光标存入bx
	mov bx,ax
	;下面这行是在栈中获取待打印的字符
	mov ecx,[esp + 36]	;pushad压入4*8=32字节，加上主调函数的返回地址4字节，所以esp+36
	cmp cl,0xd			;CR回车是0x0d,LF换行是0x0a
	jz .is_carriage_return 
	cmp cl,0xa
	jz .is_line_feed

	cmp cl,0x8			;BS(bacespace)的asc码是0x8
	jz .is_backspace

	jmp .put_other		;是正常可见字符
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.is_backspace:
;;;;;;;;;;;;	backspace的一点说明			;;;;;;;;;;;;;;;;;;;;
;当为backspace时，本质上只要将光标移向前一个显存的位置即可。后面在输入的字符自然会覆盖此处的字符
;但有可能在键入backspace后并不再键入新的字符，这时在光标已经向前移动到待删除的字符位置，但字符还在原处，这就显得很奇怪了，所以在这个地方添加空格或空字符0
	dec bx
	shl bx,1					;左移bx一位，相当于乘2
	mov byte [gs:bx],0x20		;空格0x20	
	inc bx
	mov byte [gs:bx],0x07		;黑底白字是0x07
	shr bx,1					;右移1位，相当于除2
	jmp .set_cursor				;光标的值已经改变，我们要在显存中设置新的光标，让光标闪在正确的地方
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.put_other:
	shl bx,1					;光标位置是用2字节表示，将光标值乘2，表示对应显存中的偏移字节
	mov [gs:bx],cl				;ascii字符本身
	inc bx
	mov byte [gs:bx],0x07		;字符属性，黑底白字
	shr bx,1					;恢复光标的值
	inc bx						;下一个光标值
	cmp bx,2000
	jl .set_cursor				;若光标值小于2000，表示未写到显存的最后，则去设置新的光标值
								;若超出屏幕字符数大小2000，则换行处理

.is_line_feed:					;是换行符:LF(\n)
.is_carriage_return: 			;是回车符:CR(\r)
								;如果是CR，只要把光标移到行首就行了
	xor dx,dx					;dx是被除数的高16位，清0
	mov ax,bx					;ax是被除数的低16位
	mov si,80					;一行80个字符
	div si						;dx为余数
	sub bx,dx					;bx变为行首

.is_carriage_return_end:		;回车符CR处理结束
	add bx,80
	cmp bx,2000
.is_line_feed_end:				;若是LF(\n)，将光标移+80便可
	jl .set_cursor


;屏幕行范围是0~24，滚屏的原理是将屏幕的1~24行搬运到0~23行，在将23行用空格填充
.roll_screen:					;若超出屏幕大小，开始滚屏
	cld
	mov ecx,960					;一共有2000-80=1920个字符要搬运，共1920*2=3840字节，一次搬运4字节，需要3840/4=960次
	mov esi,0xc00b80a0			;第1行行首
	mov edi,0xc00b8000			;第0行行首
	rep movsd

;;;;;;;;将最后一行填充为空白
	mov ebx,3840				;最后一行首字符的第一个字符偏移=1920*2
	mov ecx,80					;一行是80字符，每次清空一个字符，要移动80次
.cls:
	mov word [gs:ebx],0x0720	;黑底白字的空格符
	add ebx,2
	loop .cls
	mov bx,1920					;将光标在设为1920，表示最后一行的行首

.set_cursor:					;将光标设为bx值

;;;;;;;;1  先设置高8位  ;;;;;;;;;;;;;
	mov dx,0x03d4
	mov al,0x0e
	out dx,al
	mov dx,0x03d5
	mov al,bh
	out dx,al

;;;;;;;;2  再设置低8位  ;;;;;;;;;;;;;
	mov dx,0x03d4
	mov al,0x0f
	out dx,al
	mov dx,0x03d5
	mov al,bl
	out dx,al

.put_char_done:
	popad
	ret

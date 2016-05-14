TI_GDT	equ 	0
RPL0	equ		0
SELECTOR_VIDEO	equ		(0x0003<<3) + TI_GDT + RPL0

section .data
put_int_buffer	dq	0				;定义8字节缓冲区用于数字到字符的转换

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

global cls_screen
cls_screen:
	pushad
	;;;;;;;;;;;;;;;;;;;;
	;由于用户程序的cpl为3，显存段的dpl为0，故用于显存段的选择子gs在低于自己特权的环境中为0
	;导致用户程序再次进入中断后，gs为0，故直接在put_str中每次都为gs赋值
	mov ax,SELECTOR_VIDEO			;不能直接把立即数送入gs，须由ax中转
	mov gs,ax

	mov ebx,0
	mov ecx,80*25
.cls:
	mov word [gs:ebx],0x0720			;0x0720是黑底白字的空格键
	add ebx,2
	loop .cls
	mov ebx,0

 .set_cursor:				  ;直接把set_cursor搬过来用,省事
 ;;;;;;; 1 先设置高8位 ;;;;;;;;
    mov dx, 0x03d4			  ;索引寄存器
	mov al, 0x0e				  ;用于提供光标位置的高8位
	out dx, al
	mov dx, 0x03d5			  ;通过读写数据端口0x3d5来获得或设置光标位置 
	mov al, bh
	out dx, al
;;;;;;; 2 再设置低8位 ;;;;;;;;;
    mov dx, 0x03d4
    mov al, 0x0f
    out dx, al
    mov dx, 0x03d5 
    mov al, bl
    out dx, al
    popad
    ret




;-------------------- 将小端字节序的数字变成对应的ascii后，倒置 -------------
;输出：栈中参数为待打印的数字
;输入：在屏幕上打印16进制数字，并不会打印0x，如打印10进制15时，只会直接打印f
;------------------------------------------------------------------------------
global put_int
put_int:
	pushad
	mov ebp,esp
	mov eax,[ebp+4*9]			;call的返回地址4字节加上pushad的8个4字节
	mov edx,eax
	mov edi,7					;指定在put_int_buffer中初始的偏移量
	mov ecx,8					;32位数字中，16进制数字的位数是8个
	mov ebx,put_int_buffer

;将32位数字按照16进制的形式从低到高逐个处理，共处理8个16进制数字
.16based_4bits:					;每4位二进制是16进制数字的1位，遍历每一位16进制数字
	and edx,0x0000000f			;and操作后，edx只有低4位有效
	cmp edx,9					;数字0~9和a～f需要分别处理成对应的字符
	jg .is_A2F
	add edx,'0'
	jmp .store
.is_A2F:
	sub edx,10
	add edx,'A'

;将每一位数字转换成对应的字符后，按照类似"大端"的顺序存储到缓冲区put_int_buffer
;高位字符放在低地址，低位字符放在高地址，这样和大端字节序类似
.store:
;此时dl中应该是数字对应的字符的ascii码
	mov [ebx+edi],dl
	dec edi
	shr eax,4					;eax每次处理4位，处理完就右移
	mov edx,eax
	loop .16based_4bits

;现在put_int_buffer中已全是字符，打印之前把高位连续的字符去掉，比如把字符000123变成123
.ready_to_print:
	inc edi						;edi已经被减为-1了，加1使它变成0
.skip_prefix_0:
	cmp edi,8					;如果已经比较第9个字符了，表示待打印的字符串全为0
	je .full0
;找到连续的0，edi作为非0的最高为字符的偏移
.go_on_skip:
	mov cl,[put_int_buffer + edi]
	inc edi
	cmp cl,'0'
	je .skip_prefix_0			;继续判断下一位字符是否为字符0
	dec edi						;如果不是'0'的话，要把之前减去的再加回来
	jmp .put_each_num

.full0:
	mov cl,'0'					;输入全0时，打印一个0
.put_each_num:
	push ecx					;此时ecx中为待打印的字符
	call put_char
	add esp,4
	inc edi						;edi指向下一个字符
	mov cl,[put_int_buffer+edi]
	cmp edi,8
	jl .put_each_num

	popad
	ret


global set_cursor
set_cursor:
	pushad
	mov bx,[esp + 36]
;;;;;; 1 先设置高8位 ;;;;;;;;;
	mov dx,0x03d4			;索引寄存器
	mov al,0x0e				;用于提供光标位置的高8位
	out dx,al
	mov dx,0x03d5			;通过读写数据端口0x3d5来获得或设置光标位置
	mov al,bh
	out dx,al

;;;;;; 2 再设置低8位 ;;;;;;;;;
	mov dx,0x03d4
	mov al,0x0f
	out dx,al
	mov dx,0x03d5
	mov al,bl
	out dx,al
	popad
	ret

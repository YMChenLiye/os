	.file	"prog_arg.c"
	.section	.rodata
.LC0:
	.string	"argv[%d] is %s\n"
	.align 4
.LC1:
	.string	"\n      I`m father prog, my pid:%d, I will show process list\n"
	.align 4
.LC2:
	.string	"\n      I`m child prog, my pid:%d, I will exec %s right now\n"
.LC3:
	.string	"/"
	.text
	.globl	main
	.type	main, @function
main:
.LFB0:
	.cfi_startproc
	pushl	%ebp
	.cfi_def_cfa_offset 8
	.cfi_offset 5, -8
	movl	%esp, %ebp
	.cfi_def_cfa_register 5
	pushl	%edi
	pushl	%ebx
	andl	$-16, %esp
	subl	$544, %esp
	.cfi_offset 7, -12
	.cfi_offset 3, -16
	movl	12(%ebp), %eax
	movl	%eax, 12(%esp)
	
	movl	%eax, 540(%esp)
	xorl	%eax, %eax
	movl	$0, 16(%esp)
	jmp	.L2
.L3:
	movl	16(%esp), %eax
	leal	0(,%eax,4), %edx
	movl	12(%esp), %eax
	addl	%edx, %eax
	movl	(%eax), %eax
	movl	%eax, 8(%esp)
	movl	16(%esp), %eax
	movl	%eax, 4(%esp)
	movl	$.LC0, (%esp)
	call	printf
	addl	$1, 16(%esp)
.L2:
	movl	16(%esp), %eax
	cmpl	8(%ebp), %eax
	jl	.L3
	call	fork
	cwtl
	movl	%eax, 24(%esp)
	cmpl	$0, 24(%esp)
	je	.L4
	movl	$900000, 20(%esp)
	nop
.L5:
	movl	20(%esp), %eax
	leal	-1(%eax), %edx
	movl	%edx, 20(%esp)
	testl	%eax, %eax
	jne	.L5
	call	getpid
	movl	%eax, 4(%esp)
	movl	$.LC1, (%esp)
	call	printf
	call	ps
	jmp	.L6
.L4:
	leal	28(%esp), %ebx
	movl	$0, %eax
	movl	$128, %edx
	movl	%ebx, %edi
	movl	%edx, %ecx
	rep stosl
	movl	12(%esp), %eax
	addl	$4, %eax
	movl	(%eax), %ebx
	call	getpid
	movl	%ebx, 8(%esp)
	movl	%eax, 4(%esp)
	movl	$.LC2, (%esp)
	call	printf
	movl	12(%esp), %eax
	addl	$4, %eax
	movl	(%eax), %eax
	movzbl	(%eax), %eax
	cmpb	$47, %al
	je	.L7
	movl	$512, 4(%esp)
	leal	28(%esp), %eax
	movl	%eax, (%esp)
	call	getcwd
	movl	$.LC3, 4(%esp)
	leal	28(%esp), %eax
	movl	%eax, (%esp)
	call	strcat
	movl	12(%esp), %eax
	addl	$4, %eax
	movl	(%eax), %eax
	movl	%eax, 4(%esp)
	leal	28(%esp), %eax
	movl	%eax, (%esp)
	call	strcat
	movl	12(%esp), %eax
	movl	%eax, 4(%esp)
	leal	28(%esp), %eax
	movl	%eax, (%esp)
	call	execv
	jmp	.L8
.L7:
	movl	12(%esp), %eax
	addl	$4, %eax
	movl	(%eax), %eax
	movl	12(%esp), %edx
	movl	%edx, 4(%esp)
	movl	%eax, (%esp)
	call	execv
.L8:
.L6:
	jmp	.L6
	.cfi_endproc
.LFE0:
	.size	main, .-main
	.ident	"GCC: (Ubuntu 4.8.4-2ubuntu1~14.04.1) 4.8.4"
	.section	.note.GNU-stack,"",@progbits

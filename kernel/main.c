#include "print.h"
#include "init.h"
#include "thread.h"
#include "interrupt.h"
#include "console.h"
#include "process.h"
#include "syscall-init.h"
#include "syscall.h"
#include "stdio.h"
#include "memory.h"
#include "fs.h"
#include "string.h"

void k_thread_a(void*);
void k_thread_b(void*);
void u_prog_a(void);
void u_prog_b(void);

int main(void) {
	put_str("I am kernel\n");
	init_all();
	intr_enable();
	process_execute(u_prog_a, "u_prog_a");
//	process_execute(u_prog_b, "u_prog_b");
//	thread_start("k_thread_a", 31, k_thread_a, "argA ");
//	thread_start("k_thread_b", 31, k_thread_b, "argB ");
/*	uint32_t fd = sys_open("/file1",O_RDWR | O_CREAT);
	printf("open /file1,fd:%d\n",fd);
	char buf[64] = {0};
	int read_bytes = sys_read(fd,buf,18);
	printf("1_ read %d bytes:\n%s\n",read_bytes,buf);

	memset(buf,0,64);
	read_bytes = sys_read(fd,buf,6);
	printf("2_ read %d bytes:\n%s",read_bytes,buf);

	memset(buf,0,64);
	read_bytes = sys_read(fd,buf,6);
	printf("3_ read %d bytes:\n%s",read_bytes,buf);
	
	printf("_________________ SEEK_SET 0  __________\n");
	sys_lseek(fd,0,SEEK_SET);
	memset(buf,0,64);
	read_bytes = sys_read(fd,buf,24);
	printf("4_ read %d bytes:\n%s",read_bytes,buf);

	sys_close(fd);
*/
//	printf("/file1 delete %s!\n",sys_unlink("/file1") == 0 ? "done" : "fail");

//	int fd1 = sys_open("/file1",O_RDWR | O_CREAT);
//	sys_write(fd1,"hello,world\n",12);
	
	printf("/dir1/subdir1 create %s!\n",sys_mkdir("/dir1/subdir1") == 0 ? "done" : "fail");
	printf("/dir1 create %s!\n",sys_mkdir("/dir1") == 0 ? "done" : "fail");
	printf("now, /dir1/subdir1 create %s!\n",sys_mkdir("/dir1/subdir1") == 0 ? "done" : "fail");
	int fd = sys_open("/dir1/subdir1/file2",O_CREAT|O_RDWR);
	if(fd != -1){
		printf("dir1/subdir1/file2 create done!\n");
		sys_write(fd,"Catch me if you can!\n",21);
		sys_lseek(fd,0,SEEK_SET);
		char buf[32] = {0};
		sys_read(fd,buf,21);
		printf("/dir1/subdir1/file2 says:\n%s",buf);
		sys_close(fd);
	}


	while(1);
	return 0;
}

/* 在线程中运行的函数 */
void k_thread_a(void* arg) {     
	void* addr1 = sys_malloc(256);
	void* addr2 = sys_malloc(255);
	void* addr3 = sys_malloc(254);
	console_put_str(" thread_a malloc addr:0x");
	console_put_int((int)addr1);
	console_put_char(',');
	console_put_int((int)addr2);
	console_put_char(',');
	console_put_int((int)addr3);
	console_put_char('\n');

	int cpu_delay = 100000;
	while(cpu_delay-- > 0);
	sys_free(addr1);
	sys_free(addr2);
	sys_free(addr3);
	while(1);
}

/* 在线程中运行的函数 */
void k_thread_b(void* arg) {     
	void* addr1 = sys_malloc(256);
	void* addr2 = sys_malloc(255);
	void* addr3 = sys_malloc(254);
	console_put_str(" thread_b malloc addr:0x");
	console_put_int((int)addr1);
	console_put_char(',');
	console_put_int((int)addr2);
	console_put_char(',');
	console_put_int((int)addr3);
	console_put_char('\n');

	int cpu_delay = 100000;
	while(cpu_delay-- > 0);
	sys_free(addr1);
	sys_free(addr2);
	sys_free(addr3);
	while(1);
}

/* 测试用户进程 */
void u_prog_a(void) {
	void* addr1 = malloc(256);
	void* addr2 = malloc(255);
	void* addr3 = malloc(254);
	printf(" prog_a malloc addr:0x%x,0x%x,0x%x\n", (int)addr1, (int)addr2, (int)addr3);

	int cpu_delay = 100000;
	while(cpu_delay-- > 0);
	free(addr1);
	free(addr2);
	free(addr3);
	while(1);
}

/* 测试用户进程 */
void u_prog_b(void) {
	void* addr1 = malloc(256);
	void* addr2 = malloc(255);
	void* addr3 = malloc(254);
	printf(" prog_b malloc addr:0x%x,0x%x,0x%x\n", (int)addr1, (int)addr2, (int)addr3);

	int cpu_delay = 100000;
	while(cpu_delay-- > 0);
	free(addr1);
	free(addr2);
	free(addr3);
	while(1);
}



#include "print.h"

int main(void){
	put_str("i am a kernel!\n");
	put_int(0);
	put_char('\n');
	put_int(9);
	put_char('\n');
	put_int(0x12345678);
	put_char('\n');
	put_int(12345678);
	put_char('\n');
	put_int(0x00000000);
	put_char('\n');
	put_char(65);
	put_char('\n');
	put_int(41);
	while(1) ;
}


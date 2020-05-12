#ifndef CLK_SYS_MHZ
#define CLK_SYS_MHZ 50
#endif

#include "delay.h"
#include "tbman.h"
#include "uart.h"

#ifndef UART_BAUD
#define UART_BAUD (1 * 1000 * 1000)
#endif

const char *splash_text = 
"______ _____  ________  ___ _____       _____\n"
"|  _  \\  _  ||  _  |  \\/  |/  ___|     /  __ \\\n"
"| | | | | | || | | | .  . |\\ `--.  ___ | /  \\/\n"
"| | | | | | || | | | |\\/| | `--. \\/ _ \\| |\n"
"| |/ /\\ \\_/ /\\ \\_/ / |  | |/\\__/ / (_) | \\__/\\\n"
"|___/  \\___/  \\___/\\_|  |_/\\____/ \\___/ \\____/\n";

int main()
{
	uart_init();
	uart_clkdiv_baud(CLK_SYS_MHZ, UART_BAUD);
	delay_ms(5000);
	uart_puts(splash_text);

	while (1)
	{
		uart_puts("Hello, world!\n");
		delay_ms(1000);
	}
	return 0;
}

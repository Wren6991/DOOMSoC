#include "console.h"
#include "tbman.h"

void msg_uint(const char *s, uint32_t x) {
	console_puts(s);
	console_putint(x);
	console_puts("\n");
}

int main() {
	console_init();
	console_puts("Hello, world from SDRAM + caches!\n");
	uint32_t pc, sp;
	asm volatile (
		"auipc %0, 0\n"
		"mv %0, sp"
		: "=r" (pc), "=r" (sp)
	);
	msg_uint("The program counter is: ", pc);
	msg_uint("The stack pointer is:   ", sp);
	msg_uint("Boot SRAM is at:        ", SRAM_BASE);
	msg_uint("SDRAM is at:            ", SDRAM_BASE);
	tbman_exit(123);
}

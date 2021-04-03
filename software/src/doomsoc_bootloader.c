#ifndef CLK_SYS_MHZ
#define CLK_SYS_MHZ 80
#endif

#include "console.h"
#include "delay.h"
#include "sdram.h"

#define BOOT2_LOAD_SIZE (16 * 1024)


// This application is built with -nostartfiles as it must fit into a (as small
// as) 1kB cache. However its runtime requirements are pretty minimal. This
// function is the only contents of the .vectors section (at start of text),
// so is linked at the start of bootRAM, and entered directly by the processor
// at reset.

int main(void);
extern uint32_t __bss_start, __bss_end, __stack_top, __global_pointer;

void __attribute__ ((naked, section(".vectors"))) reset_handler() {
	asm volatile (".option push\n.option norelax");
	uintptr_t sp_init = (uintptr_t)&__stack_top;
	uintptr_t gp_init = (uintptr_t)&__global_pointer;
	asm volatile (
		"mv sp, %0\n"
		"mv gp, %1\n"
		: "+r" (sp_init), "+r" (gp_init) : : "memory"
	);
	asm volatile (".option pop");
	for (uint32_t *p = &__bss_start; p < &__bss_end; ++p)
		*p = 0;
	main();
}

const char *splash_text = 
"______ _____  ________  ___ _____       _____\n"
"|  _  \\  _  ||  _  |  \\/  |/  ___|     /  __ \\\n"
"| | | | | | || | | | .  . |\\ `--.  ___ | /  \\/\n"
"| | | | | | || | | | |\\/| | `--. \\/ _ \\| |\n"
"| |/ /\\ \\_/ /\\ \\_/ / |  | |/\\__/ / (_) | \\__/\\\n"
"|___/  \\___/  \\___/\\_|  |_/\\____/ \\___/ \\____/\n";


int main() {
	console_init();
	console_puts(splash_text);
	console_puts("SDRAM init...\n");
	sdram_init_seq();
	console_puts("OK.\n");
	if (tbman_running_in_sim()) {
		console_puts("Skipping SDRAM load in simulation.\n");
	}
	else {
		console_puts("Loading ");
		console_putint(BOOT2_LOAD_SIZE);
		console_puts(" bytes to SDRAM.\n");
		for (int i = 0; i < BOOT2_LOAD_SIZE; ++i) {
			((volatile uint8_t*)SDRAM_BASE)[i] = (uint8_t)console_getc();
		}
	}
	uintptr_t boot2_entry = SDRAM_BASE + VECTOR_TABLE_SIZE;
	console_puts("Entering SDRAM at\n");
	console_putint(boot2_entry);
	((void(*)())boot2_entry)();
	__builtin_unreachable();
}

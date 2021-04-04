#ifndef CLK_SYS_MHZ
#define CLK_SYS_MHZ 80
#endif

#include <stdint.h>
#include <stdbool.h>

#include "console.h"
#include "delay.h"
#include "sdram.h"

#define BOOT2_LOAD_SIZE 65536
#define CACHE_SIZE_WORDS 512
#define CACHE_LINE_SIZE_WORDS 4

#define xstr(s) str(s)
#define str(s) #s

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

static void __attribute__((noreturn)) _exit(int status) {
	// Spin on hardware, terminate sim in simulation.
	while (1) {
		tbman_exit(status);
	}
}

const char *splash_text = "\n"
"______ _____  ________  ___ _____       _____\n"
"|  _  \\  _  ||  _  |  \\/  |/  ___|     /  __ \\\n"
"| | | | | | || | | | .  . |\\ `--.  ___ | /  \\/\n"
"| | | | | | || | | | |\\/| | `--. \\/ _ \\| |\n"
"| |/ /\\ \\_/ /\\ \\_/ / |  | |/\\__/ / (_) | \\__/\\\n"
"|___/  \\___/  \\___/\\_|  |_/\\____/ \\___/ \\____/\n";

volatile uint8_t *sdram_bytes = (volatile uint8_t*)SDRAM_BASE;
volatile uint32_t *sdram_words = (volatile uint32_t*)SDRAM_BASE;

static inline uint32_t urand(uint32_t *state) {
	*state = *state * 1103515245u + 12345u;
	return *state;
}

bool test_mem_range(uint32_t start, uint32_t stop, uint32_t stride, uint32_t rand_seed) {
	console_puts("Write random u32 ");
	console_putint(start);
	console_puts(" -> ");
	console_putint(stop);
	console_puts(", stride ");
	console_putint(stride);
	console_puts("... ");
	start = (start - SDRAM_BASE) / sizeof(uint32_t);
	stop = (stop - SDRAM_BASE) / sizeof(uint32_t);
	stride /= sizeof(uint32_t);

	uint32_t urand_state = rand_seed;
	for (uint32_t addr = start; addr < stop; addr += stride)
		sdram_words[addr] = urand(&urand_state);

	console_puts("Done. Reading back...");

	urand_state = rand_seed;
	bool mismatch = false;
	for (uint32_t addr = start; addr < stop; addr += stride) {
		uint32_t expect = urand(&urand_state);
		if (sdram_words[addr] != expect) {
			mismatch = true;
			console_puts("\nMismatch @ ");
			console_putint(addr * sizeof(uint32_t) + SDRAM_BASE);
			console_puts("\nReceived: ");
			console_putint(sdram_words[addr]);
			console_puts(".\nExpected: ");
			console_putint(expect);
			console_puts("\n");
			break;
		}
	}
	if (!mismatch)
		console_puts(" OK.\n");
	return !mismatch;
}

int main() {
	console_init();
	console_puts(splash_text);
	console_puts("SDRAM init...\n");
	sdram_init_seq();

	bool mem_test_failed = false;
	if (tbman_running_in_sim()) {
		console_puts("Skipping mem test in simulation.\n");
	}
	else {
		mem_test_failed = mem_test_failed || !test_mem_range(
			SDRAM_BASE,
			SDRAM_BASE + 2 * 4 * CACHE_SIZE_WORDS,
			4,
			0xdeadbeef
		);
		mem_test_failed = mem_test_failed || !test_mem_range(
			SDRAM_BASE,
			SDRAM_BASE + SDRAM_SIZE,
			1024,
			0xcafef00d
		);
	}
	if (mem_test_failed) {
		console_puts("Memory test failed. Giving up.\n");
		_exit(-1);
	}

	if (tbman_running_in_sim()) {
		console_puts("Skipping SDRAM load in simulation.\n");
	}
	else {
		console_puts("Loading " xstr(BOOT2_LOAD_SIZE) " bytes to SDRAM.\n<<<IMG<<<");
		for (int i = 0; i < BOOT2_LOAD_SIZE; ++i)
			((volatile uint8_t*)SDRAM_BASE)[i] = (uint8_t)console_getc();
		console_puts("\nLoad OK. Cache flush...\n");
		for (int i = 0; i < CACHE_SIZE_WORDS * 2; ++i)
			(void)((volatile uint32_t*)SDRAM_BASE)[i];
#if 0
		console_puts("Dumping first kB:\n");
		for (int i = 0; i < 256; ++i) {
			console_putint(((volatile uint32_t*)SDRAM_BASE)[i]);
			console_puts(i % 8 == 7 ? "\n" : " ");
		}
#endif
	}

	console_puts("Jumping to SDRAM\n");
	((void(*)())SDRAM_BASE + VECTOR_TABLE_SIZE)();
	__builtin_unreachable();
}

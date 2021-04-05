#include "platform_defs.h"
#include "tbman.h"
#include "sdram.h"

volatile uint32_t *test_region = (volatile uint32_t*)SDRAM_BASE;

#define TEST_SIZE_WORDS (2 * CACHE_SIZE_WORDS)

int main() {
	tbman_puts("Initialising SDRAM\n");
	sdram_init_seq();
	tbman_puts("Starting write\n");
	for (int i = 0; i < TEST_SIZE_WORDS; ++i)
		test_region[i] = i;
	tbman_puts("Done, reading back\n");
	for (int i = 0; i < TEST_SIZE_WORDS; ++i)
		tbman_putint(test_region[i]);
	tbman_exit(0);
}

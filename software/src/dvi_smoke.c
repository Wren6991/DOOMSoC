#include "dvi.h"
#include "tbman.h"

#define FRAME_W 320
#define FRAME_H 200
uint8_t __attribute__((aligned(16), section(".noload"))) framebuf[FRAME_W * FRAME_H];

void cache_flush() {
	for (int i = 0; i < CACHE_SIZE_WORDS * 2; ++i)
		(void)((volatile uint32_t*)SRAM_BASE)[i];
}

int main() {
	for (int i = 0; i < FRAME_W * FRAME_H; ++i)
		framebuf[i] = i;
	cache_flush();

	for (int i = 0; i < 256; ++i)
		dvi_write_palette(i, i << 16 | (~i & 0xff));

	// Quadruple pixels horizontally and vertically.
	dvi_set_log_pix_repeat(2);
	dvi_set_framebuf_ptr((uintptr_t)framebuf);
	dvi_enable(true);

	for (int i = 0; i < 2; ++i) {
		while (!dvi_check_irq())
			;
		dvi_clear_irq();
	}

	tbman_exit(0);
}

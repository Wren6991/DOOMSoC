#include "dvi.h"
#include "irq.h"

#define WIDTH 640
#define HEIGHT 400
#define FIXPOINT 8
#define ESCAPE (3 << FIXPOINT)

void cache_flush() {
	for (int i = 0; i < CACHE_SIZE_WORDS * 2; ++i)
		(void)((volatile uint32_t*)SRAM_BASE)[i];
}

uint32_t palette[256];
uint8_t __attribute__((aligned(16))) framebuf[WIDTH * HEIGHT];

void init_palette() {
	palette[0] = 0;
	for (int i = 1; i < 256; ++i) {
		uint8_t c = i;
		if (c < 0x20) palette[i] = c << 3;
		else if (c < 0x40) palette[i] = (c - 0x20) << 11;
		else if (c < 0x60) palette[i] = (c - 0x40) << 19;
		else if (c < 0x80) palette[i] = ((c - 0x60) & 0x1f) * (0x010100 << 3);//0x0840;
		else if (c < 0xa0) palette[i] = ((c - 0x80) & 0x1f) * (0x000101 << 3);//0x0041;
		else if (c < 0xc0) palette[i] = ((c - 0xa0) & 0x1f) * (0x010001 << 3);//0x0801;
		else if (c < 0xe0) palette[i] = ((c - 0xc0) & 0x1f) * (0x010101 << 3);//0x0841;
		else palette[i] = 0;
	}
}

ISR_VSYNC() {
	// Framebuffer DMA is paused until we acknowledge the IRQ, so we can safely
	// change framebuffer pointer and/or palette data in the interrupt handler
	static int palette_cycle = 0;
	palette_cycle = (palette_cycle + 1) % 256;
	dvi_load_palette_rgb888(palette_cycle, palette, 256);
	dvi_clear_irq();
}

int main() {
	// Set up DVI for a 640x400 framebuffer
	dvi_set_log_pix_repeat(1);
	dvi_set_framebuf_ptr((uintptr_t)framebuf);
	init_palette();
	dvi_load_palette_rgb888(0, palette, 256);

	// Set up IRQ. Pause DMA whilst IRQ is asserted.
	dvi_enable_irq(true);
	dvi_set_pause_on_irq(true);
	global_irq_enable();
	external_irq_enable(IRQ_VSYNC);

	// Start DVI. VSYNC IRQ will run periodically whilst we render mandelbrot
	dvi_enable(true);

	// Draw mandelbrot...
	for (int y = 0; y < HEIGHT; ++y) {
		for (int x = 0; x < WIDTH; ++x) {
			int32_t cr = (x - WIDTH / 2 - 20) * 3 / 2;
			int32_t ci = (y - HEIGHT / 2) * 3 / 2;
			int32_t zr = cr;
			int32_t zi = ci;
			int i = 0;
			for (; i < 255; ++i)
			{
				int32_t zr_tmp = (((zr * zr) - (zi * zi)) >> FIXPOINT) + cr;
				zi = 2 * ((zr * zi) >> FIXPOINT) + ci;
				zr = zr_tmp;
				if (zi * zi + zr * zr > ESCAPE * ESCAPE)
					break;
			}
			framebuf[y * WIDTH + x] = i;
		}
	}

	cache_flush();
	while (true)
		;
}

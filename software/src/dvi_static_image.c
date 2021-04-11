#include "dvi.h"
#include "tbman.h"

#include "assets/doom_boxart_160x100.h"
#include "assets/doom_boxart_160x100.h.pal"


int main() {
	const uint16_t *doom_boxart_160x100_pal_u16 = (const uint16_t*)doom_boxart_160x100_pal;
	for (int i = 0; i < 256; ++i) {
		dvi_write_palette(i,
			(doom_boxart_160x100_pal_u16[i] & 0x001f) << ( 0 + 3 -  0) |
			(doom_boxart_160x100_pal_u16[i] & 0x03e0) << ( 8 + 3 -  5) |
			(doom_boxart_160x100_pal_u16[i] & 0x7c00) << (16 + 3 - 10)
		);
	}

	dvi_set_log_pix_repeat(3);
	dvi_set_framebuf_ptr((uintptr_t)doom_boxart_160x100);
	dvi_enable(true);

	for (int i = 0; i < 2; ++i) {
		while (!dvi_check_irq())
			;
		dvi_clear_irq();
	}

	tbman_exit(0);
}

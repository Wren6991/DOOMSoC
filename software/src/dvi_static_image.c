#include "dvi.h"

#include "assets/doom_boxart_160x100.h"
#include "assets/doom_boxart_160x100.h.pal"

int main() {
	dvi_set_log_pix_repeat(3); // 160x100 -> 1280x800
	dvi_set_framebuf_ptr((uintptr_t)doom_boxart_160x100);
	dvi_load_palette_rgb555(0, (const uint16_t*)doom_boxart_160x100_pal, 256);
	dvi_enable(true);

	while (true)
		;

}


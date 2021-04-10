#ifndef _AUDIO_OUT_H
#define _AUDIO_OUT_H

#include <stdint.h>
#include <stdbool.h>

#include "platform_defs.h"
#include "hw/audio_out_regs.h"

#define AUDIO_OUT_OVERSAMPLE_RATE 16

struct audio_out_hw {
	io_rw_32 csr;
	io_rw_32 div;
	io_rw_32 fifo;
};

#define mm_audio_out ((struct audio_out_hw *const)AUDIO_OUT_BASE)

static inline void audio_out_format(bool sample_signed, bool sample_16, bool stereo) {
	mm_audio_out->csr = mm_audio_out->csr & ~(
		AUDIO_OUT_CSR_FMT_SIGNED_MASK |
		AUDIO_OUT_CSR_FMT_16_MASK |
		AUDIO_OUT_CSR_FMT_MONO_MASK
	) | (
		!!sample_signed << AUDIO_OUT_CSR_FMT_SIGNED_LSB |
		!!sample_16 << AUDIO_OUT_CSR_FMT_16_LSB |
		! stereo << AUDIO_OUT_CSR_FMT_MONO_LSB
	);
}

static inline void audio_out_enable(bool en) {
	mm_audio_out->csr = mm_audio_out->csr
		& ~AUDIO_OUT_CSR_EN_MASK
		| !!en << AUDIO_OUT_CSR_EN_LSB;
}

static inline void audio_out_put(uint32_t samples_packed) {
	mm_audio_out->fifo = samples_packed;
}

static inline void audio_out_put_blocking(uint32_t samples_packed) {
	while (mm_audio_out->csr & AUDIO_OUT_CSR_FULL_MASK)
		;
	mm_audio_out->fifo = samples_packed;
}

static inline void audio_out_set_clkdiv(uint32_t div) {
	mm_audio_out->div = div;
}

// Use a constant argument.
// Fractional bits masked off because they add an audible hiss.
#define audio_out_set_sample_freq(freq) audio_out_set_clkdiv((uint32_t)((CLK_SYS_MHZ * 1e6 * (1 << AUDIO_OUT_DIV_INT_LSB)) / \
	(AUDIO_OUT_OVERSAMPLE_RATE * freq)) & AUDIO_OUT_DIV_INT_MASK)

#endif

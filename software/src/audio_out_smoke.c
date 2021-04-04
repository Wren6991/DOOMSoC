#include "audio_out.h"

#define SAMPLE_FREQ 48000

int main() {
	audio_out_format(
		false, // signed=
		true,  // sample_16=
		true   // stereo=
	);
	// audio_out_set_sample_freq(48000);
	audio_out_set_clkdiv(104 << 8);
	audio_out_enable(true);
	uint32_t accum_l = 0;
	uint32_t accum_r = 0;
	const uint32_t freq_l = (1ull << 32) * (440 * 1.0   / (double)SAMPLE_FREQ);
	const uint32_t freq_r = (1ull << 32) * (440 * 1.333 / (double)SAMPLE_FREQ);
	while (1) {
		accum_l += freq_l;
		accum_r += freq_r;
		audio_out_put_blocking(accum_l >> 16 | (accum_r & 0xffff0000u));
	}
}

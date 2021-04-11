#ifndef _DVI_H
#define _DVI_H

#include "platform_defs.h"
#include "hw/dvi_framebuf_regs.h"

#include <stdint.h>
#include <stdbool.h>

struct dvi_ctrl_hw {
	io_rw_32 csr;
	io_rw_32 framebuf;
	io_ro_32 dispsize;
	io_wo_32 palette;
};

#define mm_dvi_ctrl ((struct dvi_ctrl_hw *const)DVI_CTRL_BASE)

static inline void dvi_enable(bool en) {
	mm_dvi_ctrl->csr = mm_dvi_ctrl->csr & ~DVI_FRAMEBUF_CSR_EN_MASK |
		(!!en << DVI_FRAMEBUF_CSR_EN_LSB);
}

static inline bool dvi_check_irq() {
	return !!(mm_dvi_ctrl->csr & DVI_FRAMEBUF_CSR_VIRQ_MASK);
}

static inline void dvi_enable_irq(bool en) {
	mm_dvi_ctrl->csr = mm_dvi_ctrl->csr & ~DVI_FRAMEBUF_CSR_VIRQE_MASK |
		(!!en << DVI_FRAMEBUF_CSR_VIRQE_LSB);
}

static inline void dvi_clear_irq() {
	mm_dvi_ctrl->csr |= DVI_FRAMEBUF_CSR_VIRQ_MASK;
}

static inline void dvi_set_pause_on_irq(bool en) {
	mm_dvi_ctrl->csr = mm_dvi_ctrl->csr & ~DVI_FRAMEBUF_CSR_VIRQ_PAUSES_DMA_MASK |
		(!!en << DVI_FRAMEBUF_CSR_VIRQ_PAUSES_DMA_LSB);
}

static inline void dvi_set_log_pix_repeat(int repeat) {
	mm_dvi_ctrl->csr = mm_dvi_ctrl->csr & ~DVI_FRAMEBUF_CSR_LOG_PIX_REPEAT_MASK |
		repeat << DVI_FRAMEBUF_CSR_LOG_PIX_REPEAT_LSB;
}

static inline void dvi_set_framebuf_ptr(intptr_t framebuf) {
	mm_dvi_ctrl->framebuf = framebuf;
}

static inline int dvi_get_dispsize_w() {
	return (mm_dvi_ctrl->dispsize & DVI_FRAMEBUF_DISPSIZE_W_MASK) >> DVI_FRAMEBUF_DISPSIZE_W_LSB;
}

static inline int dvi_get_dispsize_h() {
	return (mm_dvi_ctrl->dispsize & DVI_FRAMEBUF_DISPSIZE_H_MASK) >> DVI_FRAMEBUF_DISPSIZE_H_LSB;
}

static inline void dvi_write_palette_rgb888(uint8_t addr, uint32_t rgb) {
	mm_dvi_ctrl->palette = (addr << DVI_FRAMEBUF_PALETTE_ADDR_LSB & DVI_FRAMEBUF_PALETTE_ADDR_MASK) |
		(rgb << DVI_FRAMEBUF_PALETTE_COLOUR_LSB & DVI_FRAMEBUF_PALETTE_COLOUR_MASK);
}

static inline void dvi_write_palette_rgb555(uint8_t addr, uint16_t rgb) {
	uint32_t rgb32 = rgb;
	dvi_write_palette_rgb888(addr,
		(rgb32 & 0x001f) << ( 0 + 3 -  0) |
		(rgb32 & 0x03e0) << ( 8 + 3 -  5) |
		(rgb32 & 0x7c00) << (16 + 3 - 10)
	);
}

static inline void dvi_load_palette_rgb888(uint8_t dst, const uint32_t *src, unsigned int len) {
	for (unsigned int i = 0; i < len; ++i)
		dvi_write_palette_rgb888(dst + i, src[i]);
}

static inline void dvi_load_palette_rgb555(uint8_t dst, const uint16_t *src, unsigned int len) {
	for (unsigned int i = 0; i < len; ++i)
		dvi_write_palette_rgb555(dst + i, src[i]);
}

#endif

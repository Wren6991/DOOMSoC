#ifndef _ADDRESSMAP_H_
#define _ADDRESSMAP_H_

#define SRAM_BASE (0x0ul << 28)
#define SRAM_SIZE (8 * 1024)

#define SDRAM_BASE (0x2ul << 28)
#define SDRAM_SIZE (64 * 1024 * 1024)

#define APB_BASE        (0x4ul << 28)
#define UART_BASE       (APB_BASE + 0x0000)
#define SDRAM_CTRL_BASE (APB_BASE + 0x1000)
#define DVI_CTRL_BASE   (APB_BASE + 0x2000)
#define AUDIO_OUT_BASE  (APB_BASE + 0x3000)
#define TBMAN_BASE      (APB_BASE + 0xf000)

#ifndef __ASSEMBLER__

#include <stdint.h>

#define DECL_REG(addr, name) volatile uint32_t * const (name) = (volatile uint32_t*)(addr)

typedef volatile uint32_t io_rw_32;
typedef volatile uint32_t io_wo_32;
typedef volatile const uint32_t io_ro_32;

#endif

#endif // _ADDRESSMAP_H_

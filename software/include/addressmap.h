#ifndef _ADDRESSMAP_H_
#define _ADDRESSMAP_H_

// Temporary SRAM
#define SRAM_BASE (0x2ul << 28)
#define SRAM_SIZE (8 * 1024)

#define APB_BASE   (0x4ul << 28)
#define UART_BASE  (APB_BASE + 0x0000)
#define TBMAN_BASE (APB_BASE + 0xf000)

#ifndef __ASSEMBLER__

#define DECL_REG(addr, name) volatile uint32_t * const (name) = (volatile uint32_t*)(addr)

typedef volatile uint32_t io_rw_32;
typedef volatile const uint32_t io_ro_32;

#endif

#endif // _ADDRESSMAP_H_

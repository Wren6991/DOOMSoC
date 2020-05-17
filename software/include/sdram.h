#include "hw/sdram_ctrl_regs.h"
#include "addressmap.h"
#include "delay.h"

struct sdram_ctrl_hw {
	io_rw_32 csr;
	io_rw_32 time;
	io_rw_32 refresh;
	io_rw_32 row_cooldown;
	io_rw_32 cmd_direct;
};

#define mm_sdram_ctrl ((struct sdram_ctrl_hw *const)SDRAM_CTRL_BASE)

#define SDRAM_CMD_REFRESH       0x1u
#define SDRAM_CMD_PRECHARGE     0x2u
#define SDRAM_CMD_LOAD_MODE_REG 0x0u

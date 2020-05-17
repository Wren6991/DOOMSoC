
#define CLK_SYS_MHZ 50

#include "sdram.h"
#include "tbman.h"
#include "hw/apb_burst_regs.h"

#include <stdint.h>

struct bgen_hw {
	io_rw_32 csr;
	io_rw_32 addr;
	io_rw_32 data[4];
};

#define mm_bgen ((struct bgen_hw *const)BGEN_BASE)

uint32_t urand()
{
	static uint32_t state = 0xf005ba11;
	state = state * 1103515245u + 12345u;
	return state;
}

void sdram_init_seq()
{
	// Power up (start transmitting clock) but don't enable automatic operations
	mm_sdram_ctrl->csr = SDRAM_CSR_PU_MASK;
	delay_us(10);
	// PrechargeAll, 3 refreshes
	mm_sdram_ctrl->cmd_direct = SDRAM_CMD_PRECHARGE | 1u << SDRAM_CMD_DIRECT_ADDR_LSB + 10;
	delay_us(10);
	for (int i = 0; i < 3; ++i)
	{
		mm_sdram_ctrl->cmd_direct = SDRAM_CMD_REFRESH;
		delay_us(10);
	}

	const uint32_t modereg =
		(0x3u << 0) | // 8 beat bursts
		(0x0u << 3) | // Sequential (wrapped) bursts
		(0x2u << 4) | // CAS latency 2
		(0x0u << 9);  // Write bursts same length as reads
	mm_sdram_ctrl->cmd_direct = SDRAM_CMD_LOAD_MODE_REG | modereg << SDRAM_CMD_DIRECT_ADDR_LSB;
	delay_us(10);

	// Timings are for MT48LC32M16A2 @ 50 MHz
	mm_sdram_ctrl->time =
		(1u << SDRAM_TIME_CAS_LSB) | // tCAS - 1    2 clk
		(0u << SDRAM_TIME_WR_LSB)  | // tWR - 1     15 ns 1 clk
		(2u << SDRAM_TIME_RAS_LSB) | // tRAS - 1    44 ns 3 clk
		(0u << SDRAM_TIME_RRD_LSB) | // tRRD - 1    15 ns 1 clk
		(0u << SDRAM_TIME_RP_LSB)  | // tRP - 1     20 ns 1 clk
		(0u << SDRAM_TIME_RCD_LSB) | // tRCD - 1    20 ns 1 clk
		(3u << SDRAM_TIME_RC_LSB);   // tRC - 1     66 ns 4 clk (also tRFC)

	mm_sdram_ctrl->refresh = 389;
	mm_sdram_ctrl->row_cooldown = 30;
	// Now that we don't need the direct cmd interface, and safe timings are
	// configured, we can enable the controller
	mm_sdram_ctrl->csr |= SDRAM_CSR_EN_MASK;
}

int main()
{
	tbman_puts("Initialising SDRAM\n");

	sdram_init_seq();

	tbman_puts("Write data:\n");
	uint32_t tmp[4];
	for (int i = 0; i < 4; ++i)
	{
		tmp[i] = urand();
		mm_bgen->data[i] = tmp[i];
		tbman_putint(tmp[i]);
	}
	mm_bgen->addr = 0;

	mm_bgen->csr = APB_BURST_CSR_WRITE_MASK;
	while (!(mm_bgen->csr & APB_BURST_CSR_READY_MASK))
		;

	// Zero the data regs to make sure that the readback is genuine
	for (int i = 0; i < 4; ++i)
		mm_bgen->data[i] = 0;

	mm_bgen->csr = APB_BURST_CSR_READ_MASK;
	while (!(mm_bgen->csr & APB_BURST_CSR_READY_MASK))
		;

	tbman_puts("Read data:\n");
	for (int i = 0; i < 4; ++i)
		tbman_putint(mm_bgen->data[i]);

	tbman_exit(0);
}

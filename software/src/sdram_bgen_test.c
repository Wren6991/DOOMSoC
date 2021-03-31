
#define CLK_SYS_MHZ 80

#ifndef UART_BAUD
#define UART_BAUD (1 * 1000 * 1000)
#endif

#include "sdram.h"
#include "tbman.h"
#include "hw/apb_burst_regs.h"
#include "uart.h"

#include <stdint.h>
#include <stdbool.h>

#define BURST_LEN_WORDS 4
struct bgen_hw {
	io_rw_32 csr;
	io_rw_32 addr;
	io_rw_32 data[BURST_LEN_WORDS];
};

#define mm_bgen ((struct bgen_hw *const)BGEN_BASE)

static uint32_t urand_state = 0xf005ba11;
static inline uint32_t urand() {
	urand_state = urand_state * 1103515245u + 12345u;
	return urand_state;
}

void sdram_init_seq() {
	// Power up (start transmitting clock) but don't enable automatic operations
	mm_sdram_ctrl->csr = SDRAM_CSR_PU_MASK;
	delay_us(10);
	// PrechargeAll, 3 refreshes
	mm_sdram_ctrl->cmd_direct = SDRAM_CMD_PRECHARGE | 1u << SDRAM_CMD_DIRECT_ADDR_LSB + 10;
	delay_us(10);
	for (int i = 0; i < 3; ++i)	{
		mm_sdram_ctrl->cmd_direct = SDRAM_CMD_REFRESH;
		delay_us(10);
	}

	// Our ULX3S has a AS4C32M16SB-7TCN (-7 speed grade), which we clock at 80
	// MHz. This grade supports up to 100 MHz with CL2, 144 MHz CL3.
	const uint32_t modereg =
		(0x3u << 0) | // 8 beat bursts
		(0x0u << 3) | // Sequential (wrapped) bursts
		(0x2u << 4) | // CAS latency 2
		(0x0u << 9);  // Write bursts same length as reads

	mm_sdram_ctrl->cmd_direct = SDRAM_CMD_LOAD_MODE_REG | modereg << SDRAM_CMD_DIRECT_ADDR_LSB;
	delay_us(10);

	mm_sdram_ctrl->time =
		(1u << SDRAM_TIME_CAS_LSB) | // tCAS - 1    2 clk
		(1u << SDRAM_TIME_WR_LSB)  | // tWR - 1     14 ns 2 clk
		(3u << SDRAM_TIME_RAS_LSB) | // tRAS - 1    42 ns 4 clk
		(1u << SDRAM_TIME_RRD_LSB) | // tRRD - 1    14 ns 2 clk
		(1u << SDRAM_TIME_RP_LSB)  | // tRP - 1     21 ns 2 clk
		(1u << SDRAM_TIME_RCD_LSB) | // tRCD - 1    21 ns 2 clk
		(4u << SDRAM_TIME_RC_LSB);   // tRC - 1     63 ns 5 clk (also tRFC)

	mm_sdram_ctrl->refresh = 623; // 7.8 us

	// Now that we don't need the direct cmd interface, and safe timings are
	// configured, we can enable the controller
	mm_sdram_ctrl->csr |= SDRAM_CSR_EN_MASK;
}

void sdram_write(uint32_t addr, const uint32_t data[BURST_LEN_WORDS]) {
	mm_bgen->addr = addr;
	for (int i = 0; i < BURST_LEN_WORDS; ++i)
		mm_bgen->data[i] = data[i];
	mm_bgen->csr = APB_BURST_CSR_WRITE_MASK;
	while (!(mm_bgen->csr & APB_BURST_CSR_READY_MASK))
		;
}

void sdram_read(uint32_t addr, uint32_t data[BURST_LEN_WORDS]) {
	mm_bgen->addr = addr;
	mm_bgen->csr = APB_BURST_CSR_READ_MASK;
	while (!(mm_bgen->csr & APB_BURST_CSR_READY_MASK))
		;
	for (int i = 0; i < BURST_LEN_WORDS; ++i)
		data[i] = mm_bgen->data[i];
}

bool test_range(uint32_t start, uint32_t stop, uint32_t rand_seed) {
	uart_puts("Writing pseudorandom data from ");
	uart_putint(start);
	uart_puts(" to ");
	uart_putint(stop);
	uart_puts("... ");

	urand_state = rand_seed;
	for (uint32_t addr = start; addr < stop; addr += sizeof(uint32_t) * BURST_LEN_WORDS) {
		uint32_t tmp[BURST_LEN_WORDS];
		for (int i = 0; i < BURST_LEN_WORDS; ++i)
			tmp[i] = urand();
		sdram_write(addr, tmp);
	}
	uart_puts("Done. Reading back...");

	urand_state = rand_seed;
	bool mismatch = false;
	for (uint32_t addr = start; addr < stop; addr += sizeof(uint32_t) * BURST_LEN_WORDS) {
		uint32_t expected[BURST_LEN_WORDS];
		uint32_t received[BURST_LEN_WORDS];
		sdram_read(addr, received);
		for (int i = 0; i < BURST_LEN_WORDS; ++i)
			expected[i] = urand();
		for (int i = 0; i < BURST_LEN_WORDS; ++i) {
			if (expected[i] != received[i])
				mismatch = true;
		}
		if (mismatch) {
			uart_puts("\nMismatch @ ");
			uart_putint(addr);
			uart_puts(".\n Expected: ");
			for (int i = 0; i < BURST_LEN_WORDS; ++i)
				uart_putint(expected[i]);
			uart_puts("\nReceived: ");
			for (int i = 0; i < BURST_LEN_WORDS; ++i)
				uart_putint(received[i]);
			uart_puts("\n");
			break;
		}
	}
	if (!mismatch)
		uart_puts(" OK.\n");
	return !mismatch;
}


int main() {
	uart_init();
	uart_clkdiv_baud(CLK_SYS_MHZ, UART_BAUD);
	delay_ms(5000);

	uart_puts("Initialising SDRAM\n");

	sdram_init_seq();

	uart_puts("Some IO on the first line...\n");

	for (int i = 0; i < 5; ++i) {
		uart_puts("Write data: ");
		uint32_t tmp[BURST_LEN_WORDS];
		for (int i = 0; i < BURST_LEN_WORDS; ++i) {
			tmp[i] = urand();
			uart_putint(tmp[i]);
		}
		uart_puts("\n");

		sdram_write(0, tmp);
		sdram_read(0, tmp);

		uart_puts("Read data:  ");
		for (int i = 0; i < 4; ++i)
			uart_putint(tmp[i]);
		uart_puts("\n");

		delay_ms(1000);
	}

	// Test regions starting at 0, ranging in size from 16 bytes to 128 megabytes
	// (double size of actual memory, so we make sure that one fails.)
	for (int log_size = 4; log_size <= 27; ++log_size) {
		test_range(0, 1u << log_size, 0xabcdef12 + log_size);
	}
	uart_puts("All tests completed.\n");
}

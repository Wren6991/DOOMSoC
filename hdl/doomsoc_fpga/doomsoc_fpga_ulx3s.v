/**********************************************************************
 * DO WHAT THE FUCK YOU WANT TO AND DON'T BLAME US PUBLIC LICENSE     *
 *                    Version 3, April 2008                           *
 *                                                                    *
 * Copyright (C) 2020 Luke Wren                                       *
 *                                                                    *
 * Everyone is permitted to copy and distribute verbatim or modified  *
 * copies of this license document and accompanying software, and     *
 * changing either is allowed.                                        *
 *                                                                    *
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION  *
 *                                                                    *
 * 0. You just DO WHAT THE FUCK YOU WANT TO.                          *
 * 1. We're NOT RESPONSIBLE WHEN IT DOESN'T FUCKING WORK.             *
 *                                                                    *
 *********************************************************************/

module doomsoc_fpga (
	input wire         clk_osc,

	output wire [7:0]  led,

	inout  wire [27:0] gp,
	inout  wire [27:0] gn,

	// Differential display interface. 3 LSBs are TMDS 0, 1, 2. MSB is clock channel.
	output wire [3:0]  gpdi_dp,
	output wire [3:0]  gpdi_dn,

	// SDRAM
	output wire        sdram_clk,
	output wire [12:0] sdram_a,
	inout  wire [15:0] sdram_dq,
	output wire [1:0]  sdram_ba,
	output wire [1:0]  sdram_dqm,
	output wire        sdram_clke,
	output wire        sdram_cs_n,
	output wire        sdram_ras_n,
	output wire        sdram_cas_n,
	output wire        sdram_we_n,

	output wire [3:0]  audio_l,
	output wire [3:0]  audio_r,

	// Reset button loopback
	input  wire        btn_pwr_n,
	output wire        user_programn,

	// GPIO and serial peripherals
	output wire        uart_tx,
	input  wire        uart_rx
);

// System clock and DVI bit clock are derived from board oscillator using
// PLLs. DVI pixel clock is then divided directly from the bit clock using
// in-fabric ring counter (and then hopefully promoted automatically to global
// distribution)

wire clk_sys;
wire clk_dvi_pix;
wire clk_dvi_bit;

wire pll_sys_locked;
wire pll_bit_locked;
wire rst_n_por;

pll_25_80 pll_sys (
	.clkin   (clk_osc),
	.clkout0 (clk_sys),
	.locked  (pll_sys_locked)
);

pll_25_228p75 pll_bit (
	.clkin   (clk_osc),
	.clkout0 (clk_dvi_bit),
	.locked  (pll_bit_locked)
);

fpga_reset #(
	.SHIFT (5),
	.COUNT (100)
) por_u (
	.clk         (clk_sys),
	.force_rst_n (pll_sys_locked && pll_bit_locked),
	.rst_n       (rst_n_por)
);

wire rst_n_dvi_pix_div;

reset_sync sync_pix_div_rst (
	.clk       (clk_dvi_bit),
	.rst_n_in  (rst_n_por),
	.rst_n_out (rst_n_dvi_pix_div)
);

reg [4:0] clk_dvi_pix_div;

always @ (posedge clk_dvi_bit or negedge rst_n_dvi_pix_div)
	if (!rst_n_dvi_pix_div)
		clk_dvi_pix_div <= 5'b11100;
	else
		clk_dvi_pix_div <= {clk_dvi_pix_div[3:0], clk_dvi_pix_div[4]};

assign clk_dvi_pix = clk_dvi_pix_div[4];



doomsoc_core #(
	.W_SDRAM_BANKSEL (2),
	.W_SDRAM_ADDR    (13),
	.W_SDRAM_DATA    (16),
	.BOOTRAM_PRELOAD ("bootram_init32.hex")
) inst_doomsoc_core (
	.clk_sys     (clk_sys),
	.clk_dvi_pix (clk_dvi_pix),
	.clk_dvi_bit (clk_dvi_bit),
	.rst_n_por   (rst_n_por),

	.sdram_clk   (sdram_clk),
	.sdram_a     (sdram_a),
	.sdram_dq    (sdram_dq),
	.sdram_ba    (sdram_ba),
	.sdram_dqm   (sdram_dqm),
	.sdram_clke  (sdram_clke),
	.sdram_cs_n  (sdram_cs_n),
	.sdram_ras_n (sdram_ras_n),
	.sdram_cas_n (sdram_cas_n),
	.sdram_we_n  (sdram_we_n),

	.dvip        (gpdi_dp),
	.dvin        (gpdi_dn),

	.audio_out_l (audio_l),
	.audio_out_r (audio_r),

	.uart_tx     (uart_tx),
	.uart_rx     (uart_rx)
);

wire blink;

blinky #(
	.CLK_HZ(80 * 1000 * 1000),
	.BLINK_HZ(1)
) blinky_u (
	.clk   (clk_sys),
	.blink (blink)
);

assign led = {
	!uart_tx,
	!uart_rx,
	4'h0,
	blink,
	1'b0
};

assign gp[27:0] = 28'h0;
assign gn[27:0] = 28'h0;



// Reset button loopback, slightly scary
localparam RST_DELAY = 10;
reg [RST_DELAY-1:0] rst_button_shift = {RST_DELAY{1'b0}};
always @ (posedge clk_osc)
	if (btn_pwr_n)
		rst_button_shift <= {RST_DELAY{1'b0}};
	else
		rst_button_shift <= (rst_button_shift << 1) | 1'b1;

assign user_programn = !rst_button_shift[RST_DELAY-1];

endmodule

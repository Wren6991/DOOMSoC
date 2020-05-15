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

// This controller is written to support the AS4C32M16SB SDRAM on my ULX3S
// board. It should be possible to adapt to other SDR SDRAMS.
//
// The SDRAM CLK is the same frequency as the system clock input.
//
// There is an APB slave port for configuration and initialisation, and an
// AHB-lite port for SDRAM access.
//
// The AHBL port *only* supports wrapped bursts of a fixed size, and the SDRAM
// mode register must be programmed to the same total size. Bulk transfers
// such as video out should be happy to do large naturally-aligned bursts, and
// caches can use wrapped bursts for critical-word-first fills. The AHBL burst
// size of this controller should therefore be the same as the cache line size
// for best results.
//
// AHBL BUSY transfers are *not supported*. HTRANS may only be IDLE, NSEQ or
// SEQ. If you ask for data you will damn well take it. If you ignore this
// advice, the behaviour is undefined -- it *may* cause your FPGA to turn
// inside out.

module ahbl_sdram #(
	// parameter DECODE_COLUMN_MASK = 32'h0000_07fe,
	// parameter DECODE_BANK_MASK   = 32'h0000_1800,
	// parameter DECODE_ROW_MASK    = 32'h03ff_e000,
	parameter COLUMN_BITS        = 10,
	parameter ROW_BITS           = 13, // Fixed row:bank:column, for now
	parameter W_SDRAM_BANKSEL    = 2,
	parameter W_SDRAM_ADDR       = 13,
	parameter W_SDRAM_DATA       = 16,
	parameter LEN_AHBL_BURST     = 4,
	parameter W_HADDR            = 32,
	parameter W_HDATA            = 32  // Do not modify
) (
	// Clock and reset
	input  wire                       clk,
	input  wire                       rst_n,

	// SDRAM
	output wire                       sdram_clk,
	output wire [W_SDRAM_ADDR-1:0]    sdram_a,
	inout  wire [W_SDRAM_DATA-1:0]    sdram_dq,
	output wire [W_SDRAM_BANKSEL-1:0] sdram_ba,
	output wire [W_SDRAM_DATA/8-1:0]  sdram_dqm,
	output wire                       sdram_clke,
	output wire                       sdram_cs_n,
	output wire                       sdram_ras_n,
	output wire                       sdram_cas_n,
	output wire                       sdram_we_n,

	// APB configuration slave
	input  wire                       apbs_psel,
	input  wire                       apbs_penable,
	input  wire                       apbs_pwrite,
	input  wire [15:0]                apbs_paddr,
	input  wire [31:0]                apbs_pwdata,
	output wire [31:0]                apbs_prdata,
	output wire                       apbs_pready,
	output wire                       apbs_pslverr,

	// AHBL bus interface
	output wire                       ahbls_hready_resp,
	input  wire                       ahbls_hready,
	output wire                       ahbls_hresp,
	input  wire [W_HADDR-1:0]         ahbls_haddr,
	input  wire                       ahbls_hwrite,
	input  wire [1:0]                 ahbls_htrans,
	input  wire [2:0]                 ahbls_hsize,
	input  wire [2:0]                 ahbls_hburst,
	input  wire [3:0]                 ahbls_hprot,
	input  wire                       ahbls_hmastlock,
	input  wire [W_HDATA-1:0]         ahbls_hwdata,
	output wire [W_HDATA-1:0]         ahbls_hrdata
);

// Control registers

wire        csr_en;
wire        csr_pu;

wire [2:0]  time_rc;
wire [2:0]  time_rcd;
wire [2:0]  time_rp;
wire [2:0]  time_rrd;
wire [2:0]  time_ras;
wire [1:0]  time_cas;

wire [11:0] cfg_refresh_interval;
wire [7:0]  cfg_row_cooldown;

// TODO register this interface
wire        cmd_direct_we_n;
wire        cmd_direct_we_n_push;
wire        cmd_direct_cas_n;
wire        cmd_direct_cas_n_push;
wire        cmd_direct_ras_n;
wire        cmd_direct_ras_n_push;
wire [12:0] cmd_direct_addr;
wire        cmd_direct_addr_push;
wire [1:0]  cmd_direct_ba;
wire        cmd_direct_ba_push;

wire cmd_direct_push =
	cmd_direct_we_n_push ||
	cmd_direct_cas_n_push ||
	cmd_direct_ras_n_push ||
	cmd_direct_addr_push ||
	cmd_direct_ba_push;

sdram_regs regblock (
	.clk                  (clk),
	.rst_n                (rst_n),

	.apbs_psel            (apbs_psel),
	.apbs_penable         (apbs_penable),
	.apbs_pwrite          (apbs_pwrite),
	.apbs_paddr           (apbs_paddr),
	.apbs_pwdata          (apbs_pwdata),
	.apbs_prdata          (apbs_prdata),
	.apbs_pready          (apbs_pready),
	.apbs_pslverr         (apbs_pslverr),

	.csr_en_o             (csr_en),
	.csr_pu_o             (csr_pu),

	.time_rc_o            (time_rc),
	.time_rcd_o           (time_rcd),
	.time_rp_o            (time_rp),
	.time_rrd_o           (time_rrd),
	.time_ras_o           (time_ras),
	.time_cas_o           (time_cas),

	.refresh_o            (cfg_refresh_interval),
	.row_cooldown_o       (cfg_row_cooldown),

	.cmd_direct_we_n_o    (cmd_direct_we_n),
	.cmd_direct_we_n_wen  (cmd_direct_we_n_push),
	.cmd_direct_cas_n_o   (cmd_direct_cas_n),
	.cmd_direct_cas_n_wen (cmd_direct_cas_n_push),
	.cmd_direct_ras_n_o   (cmd_direct_ras_n),
	.cmd_direct_ras_n_wen (cmd_direct_ras_n_push),
	.cmd_direct_addr_o    (cmd_direct_addr),
	.cmd_direct_addr_wen  (cmd_direct_addr_push),
	.cmd_direct_ba_o      (cmd_direct_ba),
	.cmd_direct_ba_wen    (cmd_direct_ba_push)
);

// IO interface

wire [W_SDRAM_DATA-1:0]    sdram_dq_o_next;
wire                       sdram_dq_oe_next;
wire [W_SDRAM_DATA-1:0]    sdram_dq_i;

wire                       sdram_clk_enable = csr_pu; // This enables the toggling of sdram_clk, NOT the same as sdram_clke

wire [W_SDRAM_ADDR-1:0]    sdram_a_next;
wire [W_SDRAM_BANKSEL-1:0] sdram_ba_next;
wire [W_SDRAM_DATA/8-1:0]  sdram_dqm_next;
wire                       sdram_clke_next;
wire                       sdram_cs_n_next;
wire                       sdram_ras_n_next;
wire                       sdram_cas_n_next;
wire                       sdram_we_n_next;

sdram_dq_buf dq_buf [W_SDRAM_DATA-1:0] (
	.clk    (clk),
	.rst_n  (rst_n),
	.o      (sdram_dq_o_next),
	.oe     (sdram_dq_oe_next),
	.i      (sdram_dq_i),
	.dq     (sdram_dq)
);

sdram_clk_buf clk_buf (
	.clk    (clk),
	.rst_n  (rst_n),
	.e      (sdram_clk_enable),
	.clkout (sdram_clk)
);

sdram_addr_buf addr_buf [W_SDRAM_ADDR-1:0] (
	.clk   (clk),
	.rst_n (rst_n),
	.d     (sdram_a_next),
	.q     (sdram_a)
);

sdram_addr_buf ctrl_buf [W_SDRAM_BANKSEL + W_SDRAM_DATA / 8 + 5 - 1 : 0] (
	.clk   (clk),
	.rst_n (rst_n),
	.d     ({sdram_ba_next, sdram_dqm_next, sdram_clke_next, sdram_cs_n_next, sdram_ras_n_next, sdram_cas_n_next, sdram_we_n_next}),
	.q     ({sdram_ba,      sdram_dqm,      sdram_clke,      sdram_cs_n,      sdram_ras_n,      sdram_cas_n,      sdram_we_n     })
);

// "Scheduling"

assign sdram_dq_oe_next = 1'b0;
assign sdram_dq_o_next = 16'h0;

assign sdram_cs_n_next  = !cmd_direct_push;
assign sdram_a_next     = cmd_direct_push ? cmd_direct_addr : {W_SDRAM_ADDR{1'b0}};
assign sdram_ba_next    = cmd_direct_push ? cmd_direct_ba : {W_SDRAM_BANKSEL{1'b0}};
assign sdram_dqm_next   = {W_SDRAM_DATA/8{1'b0}}; // Always asserted!
assign sdram_clke_next  = csr_pu;
assign sdram_ras_n_next = cmd_direct_push ? cmd_direct_ras_n : 1'b1;
assign sdram_cas_n_next = cmd_direct_push ? cmd_direct_cas_n : 1'b1;
assign sdram_we_n_next  = cmd_direct_push ? cmd_direct_we_n : 1'b1;

endmodule
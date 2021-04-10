/**********************************************************************
 * DO WHAT THE FUCK YOU WANT TO AND DON'T BLAME US PUBLIC LICENSE     *
 *                    Version 3, April 2008                           *
 *                                                                    *
 * Copyright (C) 2021 Luke Wren                                       *
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

// Stream 16/8 bit stereo/mono PCM samples to a pair of parallel DACs, as
// narrow as 1 bit. The samples are oversampled (by fixed power of 2) with
// linear interpolation, then fed through first-order sigma-delta modulators.
// 
// The oversampling clock is derived from the system clock using an
// integer:fractional divider (with simple first-order modulation on the
// fractional division, so setting fractional to zero is preferable). The
// sample clock is then calculated as the oversampling clock divided by (1 <<
// LOG_OVERSAMPLE).

module pcm_audio_out #(
	parameter W_OUT          = 4,
	parameter LOG_OVERSAMPLE = 5,
	parameter LOG_FIFO_DEPTH = 6
) (
	input  wire             clk,
	input  wire             rst_n,

	// APB Port
	input  wire             apbs_psel,
	input  wire             apbs_penable,
	input  wire             apbs_pwrite,
	input  wire [15:0]      apbs_paddr,
	input  wire [31:0]      apbs_pwdata,
	output wire [31:0]      apbs_prdata,
	output wire             apbs_pready,
	output wire             apbs_pslverr,

	output wire [W_OUT-1:0] out_l,
	output wire [W_OUT-1:0] out_r,

	output reg              irq
);

localparam W_DIV_INT = 10;
localparam W_DIV_FRAC = 8;

wire                   csr_en;
wire                   csr_fmt_signed;
wire                   csr_fmt_16;
wire                   csr_fmt_mono;
wire                   csr_ie;
wire                   csr_empty;
wire                   csr_full;
wire                   csr_half_full;
wire [W_DIV_INT-1:0]   div_int;
wire [W_DIV_FRAC-1:0]  div_frac;
wire [31:0]            fifo_wdata;
wire                   fifo_wen;

audio_out_regs regs (
	.clk              (clk),
	.rst_n            (rst_n),

	.apbs_psel        (apbs_psel),
	.apbs_penable     (apbs_penable),
	.apbs_pwrite      (apbs_pwrite),
	.apbs_paddr       (apbs_paddr),
	.apbs_pwdata      (apbs_pwdata),
	.apbs_prdata      (apbs_prdata),
	.apbs_pready      (apbs_pready),
	.apbs_pslverr     (apbs_pslverr),

	.csr_en_o         (csr_en),
	.csr_fmt_signed_o (csr_fmt_signed),
	.csr_fmt_16_o     (csr_fmt_16),
	.csr_fmt_mono_o   (csr_fmt_mono),
	.csr_ie_o         (csr_ie),
	.csr_empty_i      (csr_empty),
	.csr_full_i       (csr_full),
	.csr_half_full_i  (csr_half_full),
	.div_int_o        (div_int),
	.div_frac_o       (div_frac),
	.fifo_o           (fifo_wdata),
	.fifo_wen         (fifo_wen)
);

// ----------------------------------------------------------------------------
// FIFO and flags

wire [31:0]             fifo_rdata;
wire                    fifo_ren;
wire                    fifo_wfull;
wire                    fifo_wempty;
wire [LOG_FIFO_DEPTH:0] fifo_wlevel;

// Using async FIFO instead of sync because it supports block mem inference,
// sync FIFO is optimised for low area at low depth. Will probably need to
// move to async audio clock at some point anyway.
async_fifo #(
	.W_DATA (32),
	.W_ADDR (LOG_FIFO_DEPTH)
) sample_fifo (
	.wclk   (clk),
	.wrst_n (rst_n),
	.wdata  (fifo_wdata),
	.wpush  (fifo_wen),
	.wfull  (fifo_wfull),
	.wempty (fifo_wempty),
	.wlevel (fifo_wlevel),

	.rclk   (clk),
	.rrst_n (rst_n),
	.rdata  (fifo_rdata),
	.rpop   (fifo_ren),
	.rempty (/* unused */),
	.rfull  (/* unused */),
	.rlevel (/* unused */)
);

assign csr_full = fifo_wfull;
assign csr_empty = fifo_wempty;
assign csr_half_full = fifo_wlevel <= (1 << LOG_FIFO_DEPTH) / 2;

always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		irq <= 1'b0;
	else
		irq <= csr_ie && csr_half_full;

// ----------------------------------------------------------------------------
// Format conversion

// We support the cross of: signed/unsigned, 16/8-bit, stereo/mono

// Read strobe from the DACs
wire        sample_rdy;

reg  [2:0]  sample_ctr;
reg  [31:0] sample_shift;

wire [2:0]  bytes_per_sample = 3'd1 << ({1'b0, csr_fmt_16} + !csr_fmt_mono);
wire [2:0]  sample_ctr_next = sample_ctr + bytes_per_sample;
wire        last_of_sample_shift = sample_ctr_next >= 3'd4;

assign fifo_ren = sample_rdy && last_of_sample_shift;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		sample_ctr <= 3'd0;
		sample_shift <= 32'h0;
	end else if (!csr_en) begin
		sample_ctr <= 3'd0;
	end else if (sample_rdy) begin
		sample_shift <= last_of_sample_shift ? fifo_rdata : sample_shift >> 8 * bytes_per_sample;
		sample_ctr <= last_of_sample_shift ? 3'd0 : sample_ctr_next;
	end
end

wire [15:0] sample_in_l = {csr_fmt_signed, 15'd0} ^ (
	csr_fmt_16 ? sample_shift[15:0] : {sample_shift[7:0], 8'd0}
);

wire [15:0] sample_in_r = csr_fmt_mono ? sample_in_l : (
	{csr_fmt_signed, 15'd0} ^ (
		csr_fmt_16 ? sample_shift[31:16] : {sample_shift[15:8], 8'd0}
	)
);

// ----------------------------------------------------------------------------
// Clock divider and sigma-delta DACs

wire clk_en;

clkdiv_frac #(
	.W_DIV_INT(W_DIV_INT),
	.W_DIV_FRAC(W_DIV_FRAC)
) inst_clkdiv_frac (
	.clk      (clk),
	.rst_n    (rst_n),
	.en       (csr_en),
	.div_int  (div_int),
	.div_frac (div_frac),
	.clk_en   (clk_en)
);

wire sample_in_rdy_l;
wire sample_in_rdy_r;
// These two should be equivalent
assign sample_rdy = sample_in_rdy_l && sample_in_rdy_r;

audio_interp_sigma_delta #(
	.W_IN           (16),
	.W_OUT          (W_OUT),
	.LOG_OVERSAMPLE (LOG_OVERSAMPLE)
) dac_l (
	.clk            (clk),
	.rst_n          (rst_n),
	.clk_en         (clk_en),
	.sample_in      (sample_in_l),
	.sample_in_rdy  (sample_in_rdy_l),
	.sample_out     (out_l)
);

audio_interp_sigma_delta #(
	.W_IN           (16),
	.W_OUT          (W_OUT),
	.LOG_OVERSAMPLE (LOG_OVERSAMPLE)
) dac_r (
	.clk            (clk),
	.rst_n          (rst_n),
	.clk_en         (clk_en),
	.sample_in      (sample_in_r),
	.sample_in_rdy  (sample_in_rdy_r),
	.sample_out     (out_r)
);

endmodule

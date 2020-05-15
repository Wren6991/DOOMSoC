module sdram_dq_buf (
	input  wire clk,
	input  wire rst_n,

	input  wire o,  // output from core to pad
	input  wire oe, // active-high output enable
	output wire i,  // input from pad to core
	inout  wire dq  // pad connection
);

`ifdef FPGA_ECP5

// FIXME workaround for lack of OREG primitive in (if this even exists, I only
// saw it in TN1265)

wire o_pad;

ODDRX1F oddr (
	.D0   (o),
	.D1   (o),
	.SCLK (clk),
	.RST  (1'b0),
	.Q    (o_pad)
);

// Likewise we are doing something pretty messed up for the input register here

wire i_pad;

IDDRX1F iddr (
	.D    (i_pad),
	.SCLK (clk),
	.RST  (1'b0),
	.Q0   (i),
	.Q1   (/* unused */)
);

// ECP5 datasheet mentions a PIO primitive for synchronous tristating ("TSFF")
// and refers you to TN1265. TN1265 does not mention this primitive. TSHX2
// does exist but it has some clock and gearing stuff going on

reg oe_pad;
always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		oe_pad <= 1'b1; // Active-low OE
	else
		oe_pad <= !oe;

// Actual tristate buffer, IDDR and ODDR are folded into this as they're all
// part of the PIO

TRELLIS_IO #(
	.DIR("BIDIR")
) sdram_dq_buf_0 (
	.B (dq),
	.I (o_pad), // Yes I->o and O->i, Lattice use I for core->pad for some fuckawful reason
	.O (i_pad),
	.T (oe_pad)
);

`else

reg o_reg;
reg oe_reg;
reg i_reg;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		o_reg <= 1'b0;
		oe_reg <= 1'b0;
		i_reg <= 1'b0;
	end else begin
		o_reg <= o;
		oe_reg <= oe;
		i_reg <= dq;
	end
end

assign dq = oe_reg ? o_reg : 1'bz;
assign i = i_reg;

`endif

endmodule

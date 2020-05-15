module sdram_addr_buf (
	input  wire clk,
	input  wire rst_n,
	input  wire d,
	output wire q
);

// FIXME this is a workaround for apparent lack of SDR output buffers in
// Trellis at the moment

ddr_out ckbuf (
	.clk (clk),
	.rst_n (rst_n),

	.d_rise (d),
	.d_fall (d),
	.e      (1'b1),
	.q      (q)
);

endmodule

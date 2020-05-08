module doomsoc_fpga (
	input wire clk_osc,

	output wire [7:0] led
);

blinky #(
	.CLK_HZ(25 * 1000 * 1000),
	.BLINK_HZ(1)
) blinky_u (
	.clk   (clk_osc),
	.blink (led[0])
);

assign led[7:1] = 7'd0;

endmodule

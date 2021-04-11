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

module dvi_palette_mem #(
	parameter W_ADDR = 8,
	parameter W_DATA = 24
) (
	input  wire              wclk,
	input  wire              wen,
	input  wire [W_ADDR-1:0] waddr,
	input  wire [W_DATA-1:0] wdata,

	input  wire              rclk,
	input  wire              ren,
	input  wire [W_ADDR-1:0] raddr,
	output reg  [W_DATA-1:0] rdata
);

reg [W_DATA-1:0] mem [0:(1 << W_ADDR) - 1];

always @ (posedge wclk)
	if (wen)
		mem[waddr] <= wdata;

always @ (posedge rclk)
	if (ren)
		rdata <= mem[raddr];

endmodule

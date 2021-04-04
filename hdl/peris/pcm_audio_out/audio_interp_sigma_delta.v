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

// Linear-interpolated oversampling followed by first-order sigma-delta.
// Output width can be >1, e.g. for the 4-bit resistor DACs on ULX3S. Can also
// be ==1 if you just want to wire a GPIO to your headphones.

module audio_interp_sigma_delta #(
	parameter W_IN = 16,
	parameter W_OUT = 4,
	parameter LOG_OVERSAMPLE = 5
) (
	input  wire             clk,
	input  wire             rst_n,
	input  wire             clk_en,

	input  wire [W_IN-1:0]  sample_in,
	output wire             sample_in_rdy,
	output reg  [W_OUT-1:0] sample_out
);

reg [LOG_OVERSAMPLE-1:0] oversample_ctr;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		oversample_ctr <= {LOG_OVERSAMPLE{1'b0}};
	end else if (clk_en) begin
		oversample_ctr <= oversample_ctr + 1'b1;
	end
end

assign sample_in_rdy = clk_en && &oversample_ctr;

wire [W_IN+W_OUT-1:0] sample_in_scaled = (sample_in << W_OUT) - sample_in;

reg [W_IN+W_OUT-1:0] sample_in_prev_scaled;
reg [W_IN+W_OUT+LOG_OVERSAMPLE-1:0] interp_sample;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		sample_in_prev_scaled <= {W_IN + W_OUT{1'b0}};
		interp_sample <= {W_IN + W_OUT + LOG_OVERSAMPLE{1'b0}};
	end else if (clk_en) begin
		interp_sample <= interp_sample + sample_in_scaled - sample_in_prev_scaled;
		if (sample_in_rdy)
			sample_in_prev_scaled <= sample_in_scaled;
	end
end

reg [W_IN+LOG_OVERSAMPLE-1:0] accum;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		accum <= {W_IN + LOG_OVERSAMPLE{1'b0}};
		sample_out <= {W_OUT{1'b0}};
	end else if (clk_en) begin
		{sample_out, accum} <= {{W_OUT{1'b0}}, accum} + interp_sample;
	end
end

endmodule

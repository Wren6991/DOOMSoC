module tb;

// ----------------------------------------------------------------------------
// DUT

reg        clk;
reg        rst_n;

reg  [1:0] c;
reg  [7:0] d;
reg        den;

wire [9:0] q;

tmds_encode dut (
	.clk   (clk),
	.rst_n (rst_n),
	.c     (c),
	.d     (d),
	.den   (den),
	.q     (q)
);

// ----------------------------------------------------------------------------
// Stimulus

localparam CLK_PERIOD = 100;

localparam TEST_LEN = 1000;
localparam ENCODE_LATENCY = 3;

always #(0.5 * CLK_PERIOD) clk = !clk;

reg [12:0] vec_input_d_c_de [0:TEST_LEN-1];
reg [9:0] vec_output [0:TEST_LEN-1];

initial begin
`include "testvec.v"
	clk = 0;
	rst_n = 0;
	c = 0;
	d = 0;
	den = 0;

	#(5 * CLK_PERIOD);
	@(posedge clk);
	rst_n <= 1;

	fork
		begin: input_proc
			integer i;
			for (i = 0; i < TEST_LEN; i = i + 1) begin
				{d, c, den} <= vec_input_d_c_de[i];
				@ (posedge clk);
			end
			$display("Input complete");
		end
		begin: check_proc
			integer i;
			for (i = 0; i <= ENCODE_LATENCY; i = i + 1)
				@ (posedge clk);
			for (i = 0; i < TEST_LEN; i = i + 1) begin
				if (q != vec_output[i]) begin
					$display("Mismatch for output %d: expected %010b, got %010b", i, vec_output[i], q);
					$finish;
				end
				@ (posedge clk);
			end
			$display("Checking complete");
		end
	join
	$display("Test PASSED.");
	$finish;
end

endmodule

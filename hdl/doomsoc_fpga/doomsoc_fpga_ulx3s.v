module doomsoc_fpga (
	input wire         clk_osc,

	output wire [7:0]  led,

	inout  wire [27:0] gp,
	inout  wire [27:0] gn,

	// Differential display interface. 3 LSBs are TMDS 0, 1, 2. MSB is clock channel.
	output wire [3:0] gpdi_dp,
	output wire [3:0] gpdi_dn

);

// reg [9:0] clkdiv10 = 10'b1100011000; // 10'b0000011111;

// always @ (posedge clk_osc)
// 	clkdiv10 <= {clkdiv10[0], clkdiv10[9:1]};

wire clk_pix = clk_osc;
wire clk_bit;
wire pll_locked;

wire rst_n_por;

wire rst_n_bit;
wire rst_n_pix;

pll_25_125 inst_pll_25_125 (
	.clkin   (clk_pix),
	.clkout0 (clk_bit),
	.locked  (pll_locked)
);


fpga_reset por_u (
	.clk         (clk_pix),
	.force_rst_n (pll_locked),
	.rst_n       (rst_n_por)
);

reset_sync reset_sync_bit (
	.clk          (clk_bit),
	.rst_n_in     (rst_n_por),
	.rst_n_out    (rst_n_bit)
);

reset_sync reset_sync_pix (
	.clk          (clk_pix),
	.rst_n_in     (rst_n_por),
	.rst_n_out    (rst_n_pix)
);

blinky #(
	.CLK_HZ(25 * 1000 * 1000),
	.BLINK_HZ(1)
) blinky_u (
	.clk   (clk_bit),
	.blink (led[0])
);


blinky #(
	.CLK_HZ(2500 * 1000),
	.BLINK_HZ(2)
) blinky2_u (
	.clk   (clk_pix),
	.blink (led[1])
);

assign led[7:2] = 7'd0;

assign gp[27:4] = 28'h0;
assign gn[27:4] = 28'h0;

wire [9:0] tmds0;
wire [9:0] tmds1;
wire [9:0] tmds2;

wire rgb_rdy;


reg [10:0] hctr;
reg [10:0] vctr;
reg [10:0] framectr;

always @ (posedge clk_pix or negedge rst_n_pix) begin
	if (!rst_n_pix) begin
		hctr <= 0;
		vctr <= 0;
		framectr <= 0;
	end else if (rgb_rdy) begin
		hctr <= hctr + 1;
		if (hctr == 639) begin
			hctr <= 0;
			if (vctr == 479) begin
				vctr <= 0;
				framectr <= framectr + 1;
			end else begin
				vctr <= vctr + 1;
			end
		end
	end
end

reg [31:0] ctr = 0;
always @ (posedge clk_pix) ctr <= ctr + 1;

dvi_tx_parallel #(
	// 640x480p 60 Hz timings from CEA-861D
	.H_SYNC_POLARITY (1'b0),
	.H_FRONT_PORCH   (16),
	.H_SYNC_WIDTH    (96),
	.H_BACK_PORCH    (48),
	.H_ACTIVE_PIXELS (640),

	.V_SYNC_POLARITY (1'b0),
	.V_FRONT_PORCH   (10),
	.V_SYNC_WIDTH    (2),
	.V_BACK_PORCH    (33),
	.V_ACTIVE_LINES  (480)
) dvi_tx_ctrl (
	.clk     (clk_pix),
	.rst_n   (rst_n_pix),
	.en      (1),

	.r       ((hctr + framectr) << 2),
	.g       ((vctr + framectr) << 2),
	.b       (framectr),
	.rgb_rdy (rgb_rdy),

	.tmds2   (tmds2),
	.tmds1   (tmds1),
	.tmds0   (tmds0)
);

dvi_serialiser ser0 (
	.clk_pix   (clk_pix),
	.rst_n_pix (rst_n_pix),
	.clk_x5    (clk_bit),
	.rst_n_x5  (rst_n_bit),

	.d         (tmds0),
	.qp        (gpdi_dp[0]),
	.qn        (gpdi_dn[0])
);

dvi_serialiser ser1 (
	.clk_pix   (clk_pix),
	.rst_n_pix (rst_n_pix),
	.clk_x5    (clk_bit),
	.rst_n_x5  (rst_n_bit),

	.d         (tmds1),
	.qp        (gpdi_dp[1]),
	.qn        (gpdi_dn[1])
);


dvi_serialiser ser2 (
	.clk_pix   (clk_pix),
	.rst_n_pix (rst_n_pix),
	.clk_x5    (clk_bit),
	.rst_n_x5  (rst_n_bit),

	.d         (tmds2),
	.qp        (gpdi_dp[2]),
	.qn        (gpdi_dn[2])
);

dvi_serialiser serclk (
	.clk_pix   (clk_pix),
	.rst_n_pix (rst_n_pix),
	.clk_x5    (clk_bit),
	.rst_n_x5  (rst_n_bit),

	.d         (10'b0000011111),
	.qp        (gpdi_dp[3]),
	.qn        (gpdi_dn[3])
);

ddr_out ddr0p (
	.clk    (clk_pix),
	.rst_n  (rst_n_pix),

	.d_rise (1),
	.d_fall (0),
	.e      (1),
	.q      (gp[0])
);

endmodule

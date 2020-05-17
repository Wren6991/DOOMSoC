module tb;

localparam W_SDRAM_BANKSEL = 2;
localparam W_SDRAM_ADDR = 13;
localparam W_SDRAM_DATA = 16;

localparam CLK_SYS_PERIOD = 20;
localparam CLK_DVI_PIX_PERIOD = 40;
localparam CLK_DVI_BIT_PERIOD = 8;

reg                        clk_sys;
reg                        clk_dvi_pix;
reg                        clk_dvi_bit;
reg                        rst_n_por;

wire                       sdram_clk;
wire [W_SDRAM_ADDR-1:0]    sdram_a;
wire [W_SDRAM_DATA-1:0]    sdram_dq;
wire [W_SDRAM_BANKSEL-1:0] sdram_ba;
wire [W_SDRAM_DATA/8-1:0]  sdram_dqm;
wire                       sdram_clke;
wire                       sdram_cs_n;
wire                       sdram_ras_n;
wire                       sdram_cas_n;
wire                       sdram_we_n;

wire [3:0]                 dvip;
wire [3:0]                 dvin;

wire                       uart_tx;
wire                       uart_rx;

doomsoc_core #(
	.BOOTRAM_PRELOAD("../ram_init32.hex"),
	.W_SDRAM_BANKSEL(2),
	.W_SDRAM_ADDR(13),
	.W_SDRAM_DATA(W_SDRAM_DATA)
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

	.dvip        (dvip),
	.dvin        (dvin),

	.uart_tx     (uart_tx),
	.uart_rx     (uart_rx)
);

mt48lc32m16a2 sdram_model (
	.Dq    (sdram_dq),
	.Addr  (sdram_a),
	.Ba    (sdram_ba),
	.Clk   (sdram_clk),
	.Cke   (sdram_clke),
	.Cs_n  (sdram_cs_n),
	.Ras_n (sdram_ras_n),
	.Cas_n (sdram_cas_n),
	.We_n  (sdram_we_n),
	.Dqm   (sdram_dqm)
);

always #(0.5 * CLK_SYS_PERIOD) clk_sys = !clk_sys;
always #(0.5 * CLK_DVI_BIT_PERIOD) clk_dvi_bit = !clk_dvi_bit;
always #(0.5 * CLK_DVI_PIX_PERIOD) clk_dvi_pix = !clk_dvi_pix;

initial begin
	clk_sys = 1'b0;
	clk_dvi_pix = 1'b0;
	clk_dvi_bit = 1'b0;
	rst_n_por = 1'b0;

	#(10 * CLK_SYS_PERIOD);
	rst_n_por = 1'b1;
end

endmodule

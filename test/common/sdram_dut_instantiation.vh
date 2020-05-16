// Clock and reset
reg                          clk;
reg                          rst_n;

// SDRAM
wire                         sdram_clk;
wire [W_SDRAM_ADDR-1:0]      sdram_a;
wire [W_SDRAM_DATA-1:0]      sdram_dq;
wire [W_SDRAM_BANKSEL-1:0]   sdram_ba;
wire [W_SDRAM_DATA/8-1:0]    sdram_dqm;
wire                         sdram_clke;
wire                         sdram_cs_n;
wire                         sdram_ras_n;
wire                         sdram_cas_n;
wire                         sdram_we_n;

// APB configuration slave
reg                          apbs_psel;
reg                          apbs_penable;
reg                          apbs_pwrite;
reg  [15:0]                  apbs_paddr;
reg  [31:0]                  apbs_pwdata;
wire [31:0]                  apbs_prdata;
wire                         apbs_pready;
wire                         apbs_pslverr;

// AHBL bus interface

wire                         ahbls_hready      [0:N_MASTERS-1];
wire                         ahbls_hresp       [0:N_MASTERS-1];
reg  [W_HADDR-1:0]           ahbls_haddr       [0:N_MASTERS-1];
reg                          ahbls_hwrite      [0:N_MASTERS-1];
reg  [1:0]                   ahbls_htrans      [0:N_MASTERS-1];
reg  [2:0]                   ahbls_hsize       [0:N_MASTERS-1];
reg  [2:0]                   ahbls_hburst      [0:N_MASTERS-1];
reg  [3:0]                   ahbls_hprot       [0:N_MASTERS-1];
reg                          ahbls_hmastlock   [0:N_MASTERS-1];
reg  [W_HDATA-1:0]           ahbls_hwdata      [0:N_MASTERS-1];
wire [W_HDATA-1:0]           ahbls_hrdata      [0:N_MASTERS-1];

wire [N_MASTERS-1:0]         ahbls_hready_packed;
wire [N_MASTERS-1:0]         ahbls_hresp_packed;
wire [N_MASTERS*W_HADDR-1:0] ahbls_haddr_packed;
wire [N_MASTERS-1:0]         ahbls_hwrite_packed;
wire [N_MASTERS*2-1:0]       ahbls_htrans_packed;
wire [N_MASTERS*3-1:0]       ahbls_hsize_packed;
wire [N_MASTERS*3-1:0]       ahbls_hburst_packed;
wire [N_MASTERS*4-1:0]       ahbls_hprot_packed;
wire [N_MASTERS-1:0]         ahbls_hmastlock_packed;
wire [N_MASTERS*W_HDATA-1:0] ahbls_hwdata_packed;
wire [N_MASTERS*W_HDATA-1:0] ahbls_hrdata_packed;

genvar gmast;
generate
for (gmast = 0; gmast < N_MASTERS; gmast = gmast + 1) begin: ahbls_pack_unpack
	// Slave in
	assign ahbls_haddr_packed    [gmast * W_HADDR +: W_HADDR] = ahbls_haddr        [gmast];
	assign ahbls_hwrite_packed   [gmast]                      = ahbls_hwrite       [gmast];
	assign ahbls_htrans_packed   [gmast * 2 +: 2]             = ahbls_htrans       [gmast];
	assign ahbls_hsize_packed    [gmast * 3 +: 3]             = ahbls_hsize        [gmast];
	assign ahbls_hburst_packed   [gmast * 3 +: 3]             = ahbls_hburst       [gmast];
	assign ahbls_hprot_packed    [gmast * 4 +: 4]             = ahbls_hprot        [gmast];
	assign ahbls_hmastlock_packed[gmast]                      = ahbls_hmastlock    [gmast];
	assign ahbls_hwdata_packed   [gmast * W_HDATA +: W_HDATA] = ahbls_hwdata       [gmast];
	// Slave out
	assign ahbls_hready          [gmast]                      = ahbls_hready_packed[gmast];
	assign ahbls_hresp           [gmast]                      = ahbls_hresp_packed [gmast];
	assign ahbls_hrdata          [gmast]                      = ahbls_hrdata_packed[gmast * W_HDATA +: W_HDATA];
end
endgenerate

ahbl_sdram #(
	.COLUMN_BITS(COLUMN_BITS),
	.ROW_BITS(ROW_BITS),
	.W_SDRAM_BANKSEL(W_SDRAM_BANKSEL),
	.W_SDRAM_ADDR(W_SDRAM_ADDR),
	.W_SDRAM_DATA(W_SDRAM_DATA),
	.N_MASTERS(N_MASTERS),
	.LEN_AHBL_BURST(LEN_AHBL_BURST),
	.W_HADDR(W_HADDR),
	.W_HDATA(W_HDATA)
) inst_ahbl_sdram (
	.clk               (clk),
	.rst_n             (rst_n),

	.sdram_clk         (sdram_clk),
	.sdram_a           (sdram_a),
	.sdram_dq          (sdram_dq),
	.sdram_ba          (sdram_ba),
	.sdram_dqm         (sdram_dqm),
	.sdram_clke        (sdram_clke),
	.sdram_cs_n        (sdram_cs_n),
	.sdram_ras_n       (sdram_ras_n),
	.sdram_cas_n       (sdram_cas_n),
	.sdram_we_n        (sdram_we_n),

	.apbs_psel         (apbs_psel),
	.apbs_penable      (apbs_penable),
	.apbs_pwrite       (apbs_pwrite),
	.apbs_paddr        (apbs_paddr),
	.apbs_pwdata       (apbs_pwdata),
	.apbs_prdata       (apbs_prdata),
	.apbs_pready       (apbs_pready),
	.apbs_pslverr      (apbs_pslverr),

	.ahbls_hready      (ahbls_hready_packed),
	.ahbls_hready_resp (ahbls_hready_packed),
	.ahbls_hresp       (ahbls_hresp_packed),
	.ahbls_haddr       (ahbls_haddr_packed),
	.ahbls_hwrite      (ahbls_hwrite_packed),
	.ahbls_htrans      (ahbls_htrans_packed),
	.ahbls_hsize       (ahbls_hsize_packed),
	.ahbls_hburst      (ahbls_hburst_packed),
	.ahbls_hprot       (ahbls_hprot_packed),
	.ahbls_hmastlock   (ahbls_hmastlock_packed),
	.ahbls_hwdata      (ahbls_hwdata_packed),
	.ahbls_hrdata      (ahbls_hrdata_packed)
);

// SDRAM model

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

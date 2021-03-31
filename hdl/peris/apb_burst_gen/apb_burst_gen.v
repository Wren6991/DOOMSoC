/**********************************************************************
 * DO WHAT THE FUCK YOU WANT TO AND DON'T BLAME US PUBLIC LICENSE     *
 *                    Version 3, April 2008                           *
 *                                                                    *
 * Copyright (C) 2020 Luke Wren                                       *
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

 // This is an APB slave which can be programmed to produce WRAP4 bursts on an
 // AHB-lite master interface. Written to smoke test the SDRAM controller on
 // FPGA before adding caches to the processor, as the processor natively only
 // produces SINGLEs.

 module apb_burst_gen #(
 	parameter W_ADDR = 32, // Do not modify
 	parameter W_DATA = 32  // Do not modify
 ) (
 	input  wire              clk,
 	input  wire              rst_n,

	input  wire              apbs_psel,
	input  wire              apbs_penable,
	input  wire              apbs_pwrite,
	input  wire [15:0]       apbs_paddr,
	input  wire [31:0]       apbs_pwdata,
	output wire [31:0]       apbs_prdata,
	output wire              apbs_pready,
	output wire              apbs_pslverr,

	output reg  [W_ADDR-1:0] ahblm_haddr,
	output reg               ahblm_hwrite,
	output reg  [1:0]        ahblm_htrans,
	output wire [2:0]        ahblm_hsize,
	output reg  [2:0]        ahblm_hburst,
	output wire [3:0]        ahblm_hprot,
	output wire              ahblm_hmastlock,
	input  wire              ahblm_hready,
	input  wire              ahblm_hresp,
	output reg  [W_DATA-1:0] ahblm_hwdata,
	input  wire [W_DATA-1:0] ahblm_hrdata

 );

localparam BURST_LEN = 4;
localparam W_BURST_CTR = 2;

wire              csr_ready;
wire              csr_read;
wire              csr_write;
wire [W_ADDR-1:0] start_addr;

reg  [W_DATA-1:0] dreg           [0:BURST_LEN-1];
wire [W_DATA-1:0] dreg_apb_wdata [0:BURST_LEN-1];
wire              dreg_apb_wen   [0:BURST_LEN-1];
reg               dreg_read_wen  [0:BURST_LEN-1];

apb_burst_regs regs (
	.clk          (clk),
	.rst_n        (rst_n),

	.apbs_psel    (apbs_psel),
	.apbs_penable (apbs_penable),
	.apbs_pwrite  (apbs_pwrite),
	.apbs_paddr   (apbs_paddr),
	.apbs_pwdata  (apbs_pwdata),
	.apbs_prdata  (apbs_prdata),
	.apbs_pready  (apbs_pready),
	.apbs_pslverr (apbs_pslverr),

	.csr_ready_i  (csr_ready),
	.csr_read_o   (csr_read),
	.csr_write_o  (csr_write),

	.addr_o       (start_addr),

	.data0_i      (dreg          [0]),
	.data0_o      (dreg_apb_wdata[0]),
	.data0_wen    (dreg_apb_wen  [0]),
	.data0_ren    (/* unused */     ),
	.data1_i      (dreg          [1]),
	.data1_o      (dreg_apb_wdata[1]),
	.data1_wen    (dreg_apb_wen  [1]),
	.data1_ren    (/* unused */     ),
	.data2_i      (dreg          [2]),
	.data2_o      (dreg_apb_wdata[2]),
	.data2_wen    (dreg_apb_wen  [2]),
	.data2_ren    (/* unused */     ),
	.data3_i      (dreg          [3]),
	.data3_o      (dreg_apb_wdata[3]),
	.data3_wen    (dreg_apb_wen  [3]),
	.data3_ren    (/* unused */     )
);

always @ (posedge clk or negedge rst_n) begin: dreg_update
	integer i;
	if (!rst_n) begin
		for (i = 0; i < BURST_LEN; i = i + 1) begin
			dreg[i] <= {W_DATA{1'b0}};
		end
	end else begin
		for (i = 0; i < BURST_LEN; i = i + 1) begin
			if (dreg_apb_wen[i])
				dreg[i] <= dreg_apb_wdata[i];
			else if (dreg_read_wen[i])
				dreg[i] <= ahblm_hrdata;
		end
	end
end


localparam HTRANS_IDLE   = 2'b00;
localparam HTRANS_NSEQ   = 2'b10;
localparam HTRANS_SEQ    = 2'b11;

localparam HBURST_SINGLE = 3'b000;
localparam HBURST_WRAP4  = 3'b010;

reg [W_BURST_CTR-1:0] burst_ctr;
reg                   in_aphase;
reg                   in_dphase;
reg                   in_write;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		ahblm_htrans <= HTRANS_IDLE;
		ahblm_hwrite <= 1'b0;
		ahblm_haddr <= {W_ADDR{1'b0}};
		ahblm_hwdata <= {W_DATA{1'b0}};
		ahblm_hburst <= HBURST_SINGLE;
		burst_ctr <= {W_BURST_CTR{1'b0}};
		in_aphase <= 1'b0;
		in_dphase <= 1'b0;
		in_write <= 1'b0;
	end else if (!(in_aphase || in_dphase)) begin
		if (csr_write || csr_read) begin
			in_aphase <= 1'b1;
			in_write <= csr_write;
			ahblm_htrans <= HTRANS_NSEQ;
			ahblm_hwrite <= csr_write;
			ahblm_haddr <= start_addr;
			ahblm_hburst <= HBURST_WRAP4;
			burst_ctr <= {W_BURST_CTR{1'b0}};
		end
	end else if (ahblm_hready && in_aphase) begin
		in_aphase <= 1'b0;
		in_dphase <= 1'b1;
		ahblm_htrans <= HTRANS_SEQ;
		ahblm_haddr <= {ahblm_haddr[W_ADDR-1:4], {ahblm_haddr[3:0] + 4'h4}};
		if (in_write)
			ahblm_hwdata <= dreg[0];
	end else if (ahblm_hready && in_dphase) begin
		burst_ctr <= burst_ctr + 1;
		ahblm_haddr <= {ahblm_haddr[W_ADDR-1:4], {ahblm_haddr[3:0] + 4'h4}};
		in_dphase <= ~&burst_ctr;
		if (&{burst_ctr | 1'b1})
			ahblm_htrans <= HTRANS_IDLE;
		if (in_write)
			ahblm_hwdata <= &burst_ctr ? {W_DATA{1'b0}} : dreg[burst_ctr + 1'b1];
	end
end

always @ (*) begin: read_strobe_gen
	integer i;
	for (i = 0; i < BURST_LEN; i = i + 1)
		dreg_read_wen[i] = in_dphase && !in_write && ahblm_hready && burst_ctr == i;	
end

assign csr_ready = !(in_dphase || in_aphase);


// Tie off unused transfer attributes

assign ahblm_hsize = 3'b010;
assign ahblm_hmastlock = 1'b0;
assign ahblm_hprot = 4'b0011;

endmodule

/*******************************************************************************
*                          AUTOGENERATED BY REGBLOCK                           *
*                            Do not edit manually.                             *
*          Edit the source file (or regblock utility) and regenerate.          *
*******************************************************************************/

// Block name           : sdram
// Bus type             : apb
// Bus data width       : 32
// Bus address width    : 16

module sdram_regs (
	input wire clk,
	input wire rst_n,
	
	// APB Port
	input wire apbs_psel,
	input wire apbs_penable,
	input wire apbs_pwrite,
	input wire [15:0] apbs_paddr,
	input wire [31:0] apbs_pwdata,
	output wire [31:0] apbs_prdata,
	output wire apbs_pready,
	output wire apbs_pslverr,
	
	// Register interfaces
	output reg  csr_en_o,
	output reg  csr_pu_o,
	output reg [2:0] time_rc_o,
	output reg [2:0] time_rcd_o,
	output reg [2:0] time_rp_o,
	output reg [2:0] time_rrd_o,
	output reg [2:0] time_ras_o,
	output reg [2:0] time_wr_o,
	output reg [1:0] time_cas_o,
	output reg [11:0] refresh_o,
	output reg [7:0] row_cooldown_o,
	output reg  cmd_direct_we_n_o,
	output reg cmd_direct_we_n_wen,
	output reg  cmd_direct_cas_n_o,
	output reg cmd_direct_cas_n_wen,
	output reg  cmd_direct_ras_n_o,
	output reg cmd_direct_ras_n_wen,
	output reg [12:0] cmd_direct_addr_o,
	output reg cmd_direct_addr_wen,
	output reg [1:0] cmd_direct_ba_o,
	output reg cmd_direct_ba_wen
);

// APB adapter
wire [31:0] wdata = apbs_pwdata;
reg [31:0] rdata;
wire wen = apbs_psel && apbs_penable && apbs_pwrite;
wire ren = apbs_psel && apbs_penable && !apbs_pwrite;
wire [15:0] addr = apbs_paddr & 16'h1c;
assign apbs_prdata = rdata;
assign apbs_pready = 1'b1;
assign apbs_pslverr = 1'b0;

localparam ADDR_CSR = 0;
localparam ADDR_TIME = 4;
localparam ADDR_REFRESH = 8;
localparam ADDR_ROW_COOLDOWN = 12;
localparam ADDR_CMD_DIRECT = 16;

wire __csr_wen = wen && addr == ADDR_CSR;
wire __csr_ren = ren && addr == ADDR_CSR;
wire __time_wen = wen && addr == ADDR_TIME;
wire __time_ren = ren && addr == ADDR_TIME;
wire __refresh_wen = wen && addr == ADDR_REFRESH;
wire __refresh_ren = ren && addr == ADDR_REFRESH;
wire __row_cooldown_wen = wen && addr == ADDR_ROW_COOLDOWN;
wire __row_cooldown_ren = ren && addr == ADDR_ROW_COOLDOWN;
wire __cmd_direct_wen = wen && addr == ADDR_CMD_DIRECT;
wire __cmd_direct_ren = ren && addr == ADDR_CMD_DIRECT;

wire  csr_en_wdata = wdata[0];
wire  csr_en_rdata;
wire  csr_pu_wdata = wdata[1];
wire  csr_pu_rdata;
wire [31:0] __csr_rdata = {30'h0, csr_pu_rdata, csr_en_rdata};
assign csr_en_rdata = csr_en_o;
assign csr_pu_rdata = csr_pu_o;

wire [2:0] time_rc_wdata = wdata[2:0];
wire [2:0] time_rc_rdata;
wire [2:0] time_rcd_wdata = wdata[6:4];
wire [2:0] time_rcd_rdata;
wire [2:0] time_rp_wdata = wdata[10:8];
wire [2:0] time_rp_rdata;
wire [2:0] time_rrd_wdata = wdata[14:12];
wire [2:0] time_rrd_rdata;
wire [2:0] time_ras_wdata = wdata[18:16];
wire [2:0] time_ras_rdata;
wire [2:0] time_wr_wdata = wdata[22:20];
wire [2:0] time_wr_rdata;
wire [1:0] time_cas_wdata = wdata[25:24];
wire [1:0] time_cas_rdata;
wire [31:0] __time_rdata = {6'h0, time_cas_rdata, 1'h0, time_wr_rdata, 1'h0, time_ras_rdata, 1'h0, time_rrd_rdata, 1'h0, time_rp_rdata, 1'h0, time_rcd_rdata, 1'h0, time_rc_rdata};
assign time_rc_rdata = time_rc_o;
assign time_rcd_rdata = time_rcd_o;
assign time_rp_rdata = time_rp_o;
assign time_rrd_rdata = time_rrd_o;
assign time_ras_rdata = time_ras_o;
assign time_wr_rdata = time_wr_o;
assign time_cas_rdata = time_cas_o;

wire [11:0] refresh_wdata = wdata[11:0];
wire [11:0] refresh_rdata;
wire [31:0] __refresh_rdata = {20'h0, refresh_rdata};
assign refresh_rdata = refresh_o;

wire [7:0] row_cooldown_wdata = wdata[7:0];
wire [7:0] row_cooldown_rdata;
wire [31:0] __row_cooldown_rdata = {24'h0, row_cooldown_rdata};
assign row_cooldown_rdata = row_cooldown_o;

wire  cmd_direct_we_n_wdata = wdata[0];
wire  cmd_direct_we_n_rdata;
wire  cmd_direct_cas_n_wdata = wdata[1];
wire  cmd_direct_cas_n_rdata;
wire  cmd_direct_ras_n_wdata = wdata[2];
wire  cmd_direct_ras_n_rdata;
wire [12:0] cmd_direct_addr_wdata = wdata[15:3];
wire [12:0] cmd_direct_addr_rdata;
wire [1:0] cmd_direct_ba_wdata = wdata[29:28];
wire [1:0] cmd_direct_ba_rdata;
wire [31:0] __cmd_direct_rdata = {2'h0, cmd_direct_ba_rdata, 12'h0, cmd_direct_addr_rdata, cmd_direct_ras_n_rdata, cmd_direct_cas_n_rdata, cmd_direct_we_n_rdata};
assign cmd_direct_we_n_rdata = 1'h0;
assign cmd_direct_cas_n_rdata = 1'h0;
assign cmd_direct_ras_n_rdata = 1'h0;
assign cmd_direct_addr_rdata = 13'h0;
assign cmd_direct_ba_rdata = 2'h0;

always @ (*) begin
	case (addr)
		ADDR_CSR: rdata = __csr_rdata;
		ADDR_TIME: rdata = __time_rdata;
		ADDR_REFRESH: rdata = __refresh_rdata;
		ADDR_ROW_COOLDOWN: rdata = __row_cooldown_rdata;
		ADDR_CMD_DIRECT: rdata = __cmd_direct_rdata;
		default: rdata = 32'h0;
	endcase
	cmd_direct_we_n_wen = __cmd_direct_wen;
	cmd_direct_we_n_o = cmd_direct_we_n_wdata;
	cmd_direct_cas_n_wen = __cmd_direct_wen;
	cmd_direct_cas_n_o = cmd_direct_cas_n_wdata;
	cmd_direct_ras_n_wen = __cmd_direct_wen;
	cmd_direct_ras_n_o = cmd_direct_ras_n_wdata;
	cmd_direct_addr_wen = __cmd_direct_wen;
	cmd_direct_addr_o = cmd_direct_addr_wdata;
	cmd_direct_ba_wen = __cmd_direct_wen;
	cmd_direct_ba_o = cmd_direct_ba_wdata;
end

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		csr_en_o <= 1'h0;
		csr_pu_o <= 1'h0;
		time_rc_o <= 3'h0;
		time_rcd_o <= 3'h0;
		time_rp_o <= 3'h0;
		time_rrd_o <= 3'h0;
		time_ras_o <= 3'h0;
		time_wr_o <= 3'h0;
		time_cas_o <= 2'h0;
		refresh_o <= 12'h0;
		row_cooldown_o <= 8'h0;
	end else begin
		if (__csr_wen)
			csr_en_o <= csr_en_wdata;
		if (__csr_wen)
			csr_pu_o <= csr_pu_wdata;
		if (__time_wen)
			time_rc_o <= time_rc_wdata;
		if (__time_wen)
			time_rcd_o <= time_rcd_wdata;
		if (__time_wen)
			time_rp_o <= time_rp_wdata;
		if (__time_wen)
			time_rrd_o <= time_rrd_wdata;
		if (__time_wen)
			time_ras_o <= time_ras_wdata;
		if (__time_wen)
			time_wr_o <= time_wr_wdata;
		if (__time_wen)
			time_cas_o <= time_cas_wdata;
		if (__refresh_wen)
			refresh_o <= refresh_wdata;
		if (__row_cooldown_wen)
			row_cooldown_o <= row_cooldown_wdata;
	end
end

endmodule

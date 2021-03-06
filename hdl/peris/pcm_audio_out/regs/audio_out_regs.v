/*******************************************************************************
*                          AUTOGENERATED BY REGBLOCK                           *
*                            Do not edit manually.                             *
*          Edit the source file (or regblock utility) and regenerate.          *
*******************************************************************************/

// Block name           : audio_out
// Bus type             : apb
// Bus data width       : 32
// Bus address width    : 16

module audio_out_regs (
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
	output reg  csr_fmt_signed_o,
	output reg  csr_fmt_16_o,
	output reg  csr_fmt_mono_o,
	output reg  csr_ie_o,
	input wire  csr_empty_i,
	input wire  csr_full_i,
	input wire  csr_half_full_i,
	output reg [7:0] div_frac_o,
	output reg [9:0] div_int_o,
	output reg [31:0] fifo_o,
	output reg fifo_wen
);

// APB adapter
wire [31:0] wdata = apbs_pwdata;
reg [31:0] rdata;
wire wen = apbs_psel && apbs_penable && apbs_pwrite;
wire ren = apbs_psel && apbs_penable && !apbs_pwrite;
wire [15:0] addr = apbs_paddr & 16'hc;
assign apbs_prdata = rdata;
assign apbs_pready = 1'b1;
assign apbs_pslverr = 1'b0;

localparam ADDR_CSR = 0;
localparam ADDR_DIV = 4;
localparam ADDR_FIFO = 8;

wire __csr_wen = wen && addr == ADDR_CSR;
wire __csr_ren = ren && addr == ADDR_CSR;
wire __div_wen = wen && addr == ADDR_DIV;
wire __div_ren = ren && addr == ADDR_DIV;
wire __fifo_wen = wen && addr == ADDR_FIFO;
wire __fifo_ren = ren && addr == ADDR_FIFO;

wire  csr_en_wdata = wdata[0];
wire  csr_en_rdata;
wire  csr_fmt_signed_wdata = wdata[1];
wire  csr_fmt_signed_rdata;
wire  csr_fmt_16_wdata = wdata[2];
wire  csr_fmt_16_rdata;
wire  csr_fmt_mono_wdata = wdata[3];
wire  csr_fmt_mono_rdata;
wire  csr_ie_wdata = wdata[8];
wire  csr_ie_rdata;
wire  csr_empty_wdata = wdata[29];
wire  csr_empty_rdata;
wire  csr_full_wdata = wdata[30];
wire  csr_full_rdata;
wire  csr_half_full_wdata = wdata[31];
wire  csr_half_full_rdata;
wire [31:0] __csr_rdata = {csr_half_full_rdata, csr_full_rdata, csr_empty_rdata, 20'h0, csr_ie_rdata, 4'h0, csr_fmt_mono_rdata, csr_fmt_16_rdata, csr_fmt_signed_rdata, csr_en_rdata};
assign csr_en_rdata = csr_en_o;
assign csr_fmt_signed_rdata = csr_fmt_signed_o;
assign csr_fmt_16_rdata = csr_fmt_16_o;
assign csr_fmt_mono_rdata = csr_fmt_mono_o;
assign csr_ie_rdata = csr_ie_o;
assign csr_empty_rdata = csr_empty_i;
assign csr_full_rdata = csr_full_i;
assign csr_half_full_rdata = csr_half_full_i;

wire [7:0] div_frac_wdata = wdata[7:0];
wire [7:0] div_frac_rdata;
wire [9:0] div_int_wdata = wdata[17:8];
wire [9:0] div_int_rdata;
wire [31:0] __div_rdata = {14'h0, div_int_rdata, div_frac_rdata};
assign div_frac_rdata = div_frac_o;
assign div_int_rdata = div_int_o;

wire [31:0] fifo_wdata = wdata[31:0];
wire [31:0] fifo_rdata;
wire [31:0] __fifo_rdata = {fifo_rdata};
assign fifo_rdata = 32'h0;

always @ (*) begin
	case (addr)
		ADDR_CSR: rdata = __csr_rdata;
		ADDR_DIV: rdata = __div_rdata;
		ADDR_FIFO: rdata = __fifo_rdata;
		default: rdata = 32'h0;
	endcase
	fifo_wen = __fifo_wen;
	fifo_o = fifo_wdata;
end

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		csr_en_o <= 1'h0;
		csr_fmt_signed_o <= 1'h0;
		csr_fmt_16_o <= 1'h0;
		csr_fmt_mono_o <= 1'h0;
		csr_ie_o <= 1'h0;
		div_frac_o <= 8'h0;
		div_int_o <= 10'h0;
	end else begin
		if (__csr_wen)
			csr_en_o <= csr_en_wdata;
		if (__csr_wen)
			csr_fmt_signed_o <= csr_fmt_signed_wdata;
		if (__csr_wen)
			csr_fmt_16_o <= csr_fmt_16_wdata;
		if (__csr_wen)
			csr_fmt_mono_o <= csr_fmt_mono_wdata;
		if (__csr_wen)
			csr_ie_o <= csr_ie_wdata;
		if (__div_wen)
			div_frac_o <= div_frac_wdata;
		if (__div_wen)
			div_int_o <= div_int_wdata;
	end
end

endmodule

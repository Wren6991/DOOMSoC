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

module dvi_framebuf_ahbl #(
	parameter W_ADDR          = 32,
	parameter W_DATA          = 32,
	parameter LEN_AHBL_BURST  = 4,

	// Timing parameters for 1280x800 35 Hz video mode from cvt utility (45.75
	// MHz pixel clock)
	parameter H_SYNC_POLARITY = 1'b0,
	parameter H_FRONT_PORCH   = 40,
	parameter H_SYNC_WIDTH    = 120,
	parameter H_BACK_PORCH    = 160,
	parameter H_ACTIVE_PIXELS = 1280,

	parameter V_SYNC_POLARITY = 1'b1,
	parameter V_FRONT_PORCH   = 3,
	parameter V_SYNC_WIDTH    = 6,
	parameter V_BACK_PORCH    = 10,
	parameter V_ACTIVE_LINES  = 800,

	parameter W_BURST_CTR = $clog2(LEN_AHBL_BURST), // do not modify
	parameter HSIZE_MAX = $clog2(W_DATA / 8)        // do not modify
) (
	input wire               clk_sys,
	input wire               clk_pix,
	input wire               clk_bit,
	input wire               rst_n_sys,
	input wire               rst_n_pix,
	input wire               rst_n_bit,

	// Configuration/control interface
	input  wire              apbs_psel,
	input  wire              apbs_penable,
	input  wire              apbs_pwrite,
	input  wire [15:0]       apbs_paddr,
	input  wire [31:0]       apbs_pwdata,
	output wire [31:0]       apbs_prdata,
	output wire              apbs_pready,
	output wire              apbs_pslverr,

	// SDRAM burst interface
	output wire [W_ADDR-1:0] ahblm_haddr,
	output wire [1:0]        ahblm_htrans,
	output wire              ahblm_hwrite,
	output wire [2:0]        ahblm_hsize,
	output wire [2:0]        ahblm_hburst,
	output wire [3:0]        ahblm_hprot,
	output wire              ahblm_hmastlock,
	input  wire              ahblm_hready,
	input  wire              ahblm_hresp,
	output wire [W_DATA-1:0] ahblm_hwdata,
	input  wire [W_DATA-1:0] ahblm_hrdata,

	// Vertical blanking interrupt
	output wire              irq,

	// Serial video out
	output wire [3:0]        dvip,
	output wire [3:0]        dvin
);

localparam DISPSIZE_W = H_ACTIVE_PIXELS;
localparam DISPSIZE_H = V_ACTIVE_LINES;
localparam W_VCTR     = 11;
localparam W_HCTR     = 10;

localparam LOG_FIFO_DEPTH = 4;

wire              vsync;
wire              pixfifo_runderflow;

wire              csr_en;
wire              csr_virq;
wire              csr_virqe;
wire              csr_virq_pauses_dma;
wire [1:0]        csr_log_pix_repeat;
wire [W_ADDR-1:0] framebuf_start;

wire [23:0]       palette_wdata;
wire              palette_colour_wen;
wire [7:0]        palette_waddr;
wire              palette_addr_wen;

dvi_framebuf_regs regs (
	.clk                   (clk_sys),
	.rst_n                 (rst_n_sys),

	.apbs_psel             (apbs_psel),
	.apbs_penable          (apbs_penable),
	.apbs_pwrite           (apbs_pwrite),
	.apbs_paddr            (apbs_paddr),
	.apbs_pwdata           (apbs_pwdata),
	.apbs_prdata           (apbs_prdata),
	.apbs_pready           (apbs_pready),
	.apbs_pslverr          (apbs_pslverr),

	.csr_en_o              (csr_en),
	.csr_virq_i            (vsync),
	.csr_virq_o            (csr_virq),
	.csr_virqe_o           (csr_virqe),
	.csr_virq_pauses_dma_o (csr_virq_pauses_dma),
	.csr_underflow_i       (pixfifo_runderflow),
	.csr_underflow_o       (/* unused */),
	.csr_log_pix_repeat_o  (csr_log_pix_repeat),

	.framebuf_o            (framebuf_start[31:4]),

	.dispsize_w_i          (DISPSIZE_W[15:0]),
	.dispsize_h_i          (DISPSIZE_H[15:0]),

	.palette_colour_o      (palette_wdata),
	.palette_colour_wen    (palette_colour_wen),
	.palette_addr_o        (palette_waddr),
	.palette_addr_wen      (palette_addr_wen)
);

assign framebuf_start[3:0] = 4'h0;

assign irq = csr_virq && csr_virqe;
wire pause_dma = csr_virq && csr_virq_pauses_dma;

// ----------------------------------------------------------------------------
// Framebuffer DMA

localparam W_REPEAT_CTR = 3;

// Generate addresses and horizontal/vertical timing events, based on watching
// for when addresses are issued, and counting address issues against
// horizontal/vertical display dimensions. Scanlines are concatenated directly
// against one another in the framebuffer, which makes the increment logic
// simpler, but we may repeat the same scanline multiple times, so need to
// remember the address of the first pixel in the current scanline.

reg [W_ADDR-1:0]       addr_ctr;
reg [W_ADDR-1:0]       addr_line_start;
reg [W_VCTR-1:0]       v_ctr;
reg [W_HCTR-1:0]       h_ctr;
reg [W_REPEAT_CTR-1:0] v_repeat_ctr;


wire address_issued = ahblm_htrans[1] && ahblm_hready;
wire hsync = address_issued && ~|h_ctr;
assign vsync = hsync && ~|v_ctr;

wire [W_REPEAT_CTR-1:0] v_repeat_ctr_reload = ~({W_REPEAT_CTR{1'b1}} << csr_log_pix_repeat);

// Subtraction should really happen afterward, but this is fine if DISPSIZE_W
// is a multiple of a reasonably large power of 2
wire [W_HCTR-1:0] hctr_reload = (DISPSIZE_W / (W_DATA / 8) - 1) >> csr_log_pix_repeat;

always @ (posedge clk_sys or negedge rst_n_sys) begin
	if (!rst_n_sys) begin
		addr_ctr <= {W_ADDR{1'b0}};
		addr_line_start <= {W_ADDR{1'b0}};
		v_ctr <= {W_VCTR{1'b0}};
		h_ctr <= {W_HCTR{1'b0}};
		v_repeat_ctr <= {W_REPEAT_CTR{1'b0}};
	end else if (!csr_en || pause_dma) begin
		addr_ctr <= framebuf_start;
		addr_line_start <= framebuf_start;
		v_ctr <= DISPSIZE_H - 1;
		h_ctr <= hctr_reload;
		v_repeat_ctr <= v_repeat_ctr_reload;
	end else if (address_issued) begin
		if (vsync) begin
			addr_ctr <= framebuf_start;
			addr_line_start <= framebuf_start;
			v_ctr <= DISPSIZE_H - 1;
			h_ctr <= hctr_reload;
			v_repeat_ctr <= v_repeat_ctr_reload;
		end else if (hsync) begin
			h_ctr <= hctr_reload;
			v_ctr <= v_ctr - 1'b1;
			if (|v_repeat_ctr) begin
				v_repeat_ctr <= v_repeat_ctr - 1'b1;
				addr_ctr <= addr_line_start;
			end else begin
				v_repeat_ctr <= v_repeat_ctr_reload;
				addr_ctr <= addr_ctr + W_DATA / 8;
				addr_line_start <= addr_ctr + W_DATA / 8;
			end
		end else begin
			h_ctr <= h_ctr - 1'b1;
			addr_ctr <= addr_ctr + W_DATA / 8;
		end
	end
end

// Generate request. Possible state transitions:
//
//   IDLE -+-> NSEQ -> SEQ -+
//    ^ ^__|    ^       ^   |
//    |_________|_______|___|

wire [W_DATA-1:0]       pixfifo_wdata;
wire                    pixfifo_wpush;
wire [LOG_FIFO_DEPTH:0] pixfifo_wlevel;

reg dphase_active;

wire burst_needed = csr_en && !pause_dma &&
	pixfifo_wlevel + dphase_active <= (1 << LOG_FIFO_DEPTH) - LEN_AHBL_BURST;

reg [W_BURST_CTR-1:0] burst_ctr;
reg                   burst_active;

always @ (posedge clk_sys or negedge rst_n_sys) begin
	if (!rst_n_sys) begin
		burst_ctr <= {W_BURST_CTR{1'b0}};
		burst_active <= 1'b0;
	end else if (ahblm_hready) begin
		if (!burst_active) begin
			burst_active <= burst_needed;
		end else begin
			burst_ctr <= burst_ctr + 1'b1;
			if (burst_ctr == LEN_AHBL_BURST - 1) begin
				burst_active <= burst_needed;
				burst_ctr <= {W_BURST_CTR{1'b0}};
			end
		end
	end
end

assign ahblm_htrans = {burst_active, burst_active && |burst_ctr};
assign ahblm_haddr = addr_ctr;

// Tie off unused or fixed controls
assign ahblm_hwrite = 1'b0;
assign ahblm_hsize = HSIZE_MAX;
assign ahblm_hmastlock = 1'b0;
assign ahblm_hprot = 4'b0011;
assign ahblm_hwdata = {W_DATA{1'b0}};
assign ahblm_hburst = LEN_AHBL_BURST == 1  ? 3'b000 : // SINGLE
                      LEN_AHBL_BURST == 4  ? 3'b011 : // INCR4
                      LEN_AHBL_BURST == 8  ? 3'b101 : // INCR8
                      LEN_AHBL_BURST == 16 ? 3'b111 : // INCR16
                                             3'b001 ; // INCR

// Route response to pixel FIFO. TODO ignoring errors because we know the
// SDRAM controller doesn't generate them, and there is no fabric between us
// and the controller.

always @ (posedge clk_sys or negedge rst_n_sys)
	if (!rst_n_sys)
		dphase_active <= 1'b0;
	else if (ahblm_hready)
		dphase_active <= ahblm_htrans[1];

assign pixfifo_wpush = dphase_active && ahblm_hready;
assign pixfifo_wdata = ahblm_hrdata;

// ----------------------------------------------------------------------------
// Clock domain crossing sys -> pix

wire [W_DATA-1:0]       pixfifo_rdata;
wire                    pixfifo_rpop;
wire                    pixfifo_rempty;

assign pixfifo_runderflow = pixfifo_rpop && pixfifo_rempty;

async_fifo #(
	.W_DATA (W_DATA),
	.W_ADDR (LOG_FIFO_DEPTH)
) inst_async_fifo (
	.wrst_n (rst_n_sys),
	.wclk   (clk_sys),
	.wdata  (pixfifo_wdata),
	.wpush  (pixfifo_wpush),
	.wfull  (/* unused */),
	.wempty (/* unused */),
	.wlevel (pixfifo_wlevel),

	.rrst_n (rst_n_pix),
	.rclk   (clk_pix),
	.rdata  (pixfifo_rdata),
	.rpop   (pixfifo_rpop),
	.rfull  (/* unused */),
	.rempty (pixfifo_rempty),
	.rlevel (/* unused */)
);

// CSR controls just go through 2FF synchronisers to avoid metastabilities.
// Skew safety is provided by the staging of the writes by software (controls
// are only changed whilst CSR_EN is 0, during which time the pixel-domain
// logic continuously resamples them, then CSR_EN is set after the controls
// are programmed).

wire [1:0] csr_log_pix_repeat_clk_pix;
wire       csr_en_clk_pix;

sync_1bit pix_ctrl_sync [2:0] (
	.clk   (clk_pix),
	.rst_n (rst_n_pix),
	.i     ({csr_log_pix_repeat,         csr_en        }),
	.o     ({csr_log_pix_repeat_clk_pix, csr_en_clk_pix})
);

// ----------------------------------------------------------------------------
// Horizontal pixel shift/repeat

reg [W_DATA-1:0]       pix_shift_buf;
reg [W_DATA/8-1:0]     pix_shift_vld;
reg [W_REPEAT_CTR-1:0] h_repeat_ctr;

wire       pix_rdy;

// FIXME need to avoid popping first word of next frame at end of frame (problem introduced by palette RAM delay cycle)
assign pixfifo_rpop = csr_en_clk_pix && (
	(!pix_shift_vld[0] && !pixfifo_rempty) ||
	(pix_rdy && !pix_shift_vld[1] && ~|h_repeat_ctr)
);

wire [W_REPEAT_CTR-1:0] h_repeat_ctr_reload = ~({W_REPEAT_CTR{1'b1}} << csr_log_pix_repeat_clk_pix);

always @ (posedge clk_pix or negedge rst_n_pix) begin
	if (!rst_n_pix) begin
		pix_shift_buf <= {W_DATA{1'b0}};
		pix_shift_vld <= {W_DATA/8{1'b0}};
		h_repeat_ctr <= {W_REPEAT_CTR{1'b0}};
	end else if (!csr_en_clk_pix) begin
		pix_shift_vld <= {W_DATA/8{1'b0}};
	end else if (pixfifo_rpop) begin
		pix_shift_buf <= pixfifo_rdata;
		pix_shift_vld <= {W_DATA/8{1'b1}};
		h_repeat_ctr <= h_repeat_ctr_reload;
	end else if (pix_rdy) begin
		if (|h_repeat_ctr) begin
			h_repeat_ctr <= h_repeat_ctr - 1'b1;
		end else begin
			h_repeat_ctr <= h_repeat_ctr_reload;
			pix_shift_buf <= pix_shift_buf >> 8;
			pix_shift_vld <= pix_shift_vld >> 1;
		end
	end
end

wire [7:0] pix_next = pix_shift_buf[7:0];

// ----------------------------------------------------------------------------
// Palette mapping

wire [7:0]  palette_raddr = pix_next;
wire        palette_ren = pix_rdy;
wire [23:0] palette_rdata;

dvi_palette_mem #(
	.W_ADDR (8),
	.W_DATA (24)
) pmem (
	.wclk  (clk_sys),
	.wen   (palette_addr_wen || palette_colour_wen),
	.waddr (palette_waddr),
	.wdata (palette_wdata),

	.rclk  (clk_pix),
	.ren   (palette_ren),
	.raddr (palette_raddr),
	.rdata (palette_rdata)
);

reg first_pixel_was_read;
always @ (posedge clk_pix or negedge rst_n_pix) begin
	if (!rst_n_pix) begin
		first_pixel_was_read <= 1'b0;
	end else if (!csr_en_clk_pix) begin
		first_pixel_was_read <= 1'b0;
	end else begin
		// First pmem read is on the first cycle where pixel shifter is valid, the
		// "was_read" flag becomes true on the next cycle.
		first_pixel_was_read <= first_pixel_was_read || |pix_shift_vld;
	end
end

wire rgb_rdy;
assign pix_rdy = rgb_rdy || (|pix_shift_vld && !first_pixel_was_read);

// ----------------------------------------------------------------------------
// DVI timing/encode/serialise

wire [9:0] tmds0;
wire [9:0] tmds1;
wire [9:0] tmds2;

dvi_tx_parallel #(
	.H_SYNC_POLARITY (H_SYNC_POLARITY),
	.H_FRONT_PORCH   (H_FRONT_PORCH),
	.H_SYNC_WIDTH    (H_SYNC_WIDTH),
	.H_BACK_PORCH    (H_BACK_PORCH),
	.H_ACTIVE_PIXELS (DISPSIZE_W),

	.V_SYNC_POLARITY (V_SYNC_POLARITY),
	.V_FRONT_PORCH   (V_FRONT_PORCH),
	.V_SYNC_WIDTH    (V_SYNC_WIDTH),
	.V_BACK_PORCH    (V_BACK_PORCH),
	.V_ACTIVE_LINES  (DISPSIZE_H)
) dvi_tx_ctrl (
	.clk     (clk_pix),
	.rst_n   (rst_n_pix),
	.en      (csr_en_clk_pix),

	.r       (palette_rdata[23:16]),
	.g       (palette_rdata[15:8]),
	.b       (palette_rdata[7:0]),
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
	.qp        (dvip[0]),
	.qn        (dvin[0])
);

dvi_serialiser ser1 (
	.clk_pix   (clk_pix),
	.rst_n_pix (rst_n_pix),
	.clk_x5    (clk_bit),
	.rst_n_x5  (rst_n_bit),

	.d         (tmds1),
	.qp        (dvip[1]),
	.qn        (dvin[1])
);


dvi_serialiser ser2 (
	.clk_pix   (clk_pix),
	.rst_n_pix (rst_n_pix),
	.clk_x5    (clk_bit),
	.rst_n_x5  (rst_n_bit),

	.d         (tmds2),
	.qp        (dvip[2]),
	.qn        (dvin[2])
);

dvi_clock_driver serclk (
	.clk_x5    (clk_bit),
	.rst_n_x5  (rst_n_bit),

	.qp        (dvip[3]),
	.qn        (dvin[3])
);

endmodule

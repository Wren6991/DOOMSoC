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

// Core: the top level of the logical design.
// The only thing above this is FPGA-specific hardware e.g. PLLs, reset generator.

`default_nettype none

module doomsoc_core #(
	parameter BOOTRAM_PRELOAD = "",
	parameter W_SDRAM_BANKSEL = 2,
	parameter W_SDRAM_ADDR = 13,
	parameter W_SDRAM_DATA = 16
) (
	// Clock and reset
	input  wire                       clk_sys,
	input  wire                       clk_dvi_pix,
	input  wire                       clk_dvi_bit,
	input  wire                       rst_n_por,

	// SDRAM
	output wire                       sdram_clk,
	output wire [W_SDRAM_ADDR-1:0]    sdram_a,
	inout  wire [W_SDRAM_DATA-1:0]    sdram_dq,
	output wire [W_SDRAM_BANKSEL-1:0] sdram_ba,
	output wire [W_SDRAM_DATA/8-1:0]  sdram_dqm,
	output wire                       sdram_clke,
	output wire                       sdram_cs_n,
	output wire                       sdram_ras_n,
	output wire                       sdram_cas_n,
	output wire                       sdram_we_n,

	// DVI video out
	output wire [3:0]                 dvip,
	output wire [3:0]                 dvin,

	// GPIO and serial peripherals
	output wire                       uart_tx,
	input  wire                       uart_rx
);

localparam W_HADDR = 32;
localparam W_HDATA = 32;
localparam W_PADDR = 16;

localparam SDRAM_BASE = 32'h2000_0000;
localparam APB_BASE   = 32'h4000_0000;

// ----------------------------------------------------------------------------
// Resets

wire rst_n_sys;
wire rst_n_dvi_pix;
wire rst_n_dvi_bit;

reset_sync reset_sync_sys (
	.clk       (clk_sys),
	.rst_n_in  (rst_n_por),
	.rst_n_out (rst_n_sys)
);

reset_sync reset_sync_bit (
	.clk       (clk_dvi_bit),
	.rst_n_in  (rst_n_por),
	.rst_n_out (rst_n_dvi_bit)
);

reset_sync reset_sync_pix (
	.clk       (clk_dvi_pix),
	.rst_n_in  (rst_n_por),
	.rst_n_out (rst_n_dvi_pix)
);


// ----------------------------------------------------------------------------
// Instance wiring

wire                proc_hready;
wire                proc_hresp;
wire [W_HADDR-1:0]  proc_haddr;
wire                proc_hwrite;
wire [1:0]          proc_htrans;
wire [2:0]          proc_hsize;
wire [2:0]          proc_hburst;
wire [3:0]          proc_hprot;
wire                proc_hmastlock;
wire [W_HDATA-1:0]  proc_hwdata;
wire [W_HDATA-1:0]  proc_hrdata;

// Temporary SRAM for running some test code
wire                sram_hready;
wire                sram_hready_resp;
wire                sram_hresp;
wire [W_HADDR-1:0]  sram_haddr;
wire                sram_hwrite;
wire [1:0]          sram_htrans;
wire [2:0]          sram_hsize;
wire [2:0]          sram_hburst;
wire [3:0]          sram_hprot;
wire                sram_hmastlock;
wire [W_HDATA-1:0]  sram_hwdata;
wire [W_HDATA-1:0]  sram_hrdata;

wire                bridge_hready;
wire                bridge_hready_resp;
wire                bridge_hresp;
wire [W_HADDR-1:0]  bridge_haddr;
wire                bridge_hwrite;
wire [1:0]          bridge_htrans;
wire [2:0]          bridge_hsize;
wire [2:0]          bridge_hburst;
wire [3:0]          bridge_hprot;
wire                bridge_hmastlock;
wire [W_HDATA-1:0]  bridge_hwdata;
wire [W_HDATA-1:0]  bridge_hrdata;

wire [W_PADDR-1:0]  bridge_paddr;
wire                bridge_psel;
wire                bridge_penable;
wire                bridge_pwrite;
wire [W_HDATA-1:0]  bridge_pwdata;
wire                bridge_pready;
wire [W_HDATA-1:0]  bridge_prdata;
wire                bridge_pslverr;

wire [W_PADDR-1:0]  uart_paddr;
wire                uart_psel;
wire                uart_penable;
wire                uart_pwrite;
wire [W_HDATA-1:0]  uart_pwdata;
wire                uart_pready;
wire [W_HDATA-1:0]  uart_prdata;
wire                uart_pslverr;

wire                uart_irq;

wire [W_PADDR-1:0]  tbman_paddr;
wire                tbman_psel;
wire                tbman_penable;
wire                tbman_pwrite;
wire [W_HDATA-1:0]  tbman_pwdata;
wire                tbman_pready;
wire [W_HDATA-1:0]  tbman_prdata;
wire                tbman_pslverr;

// ----------------------------------------------------------------------------
// Processor instantiation + integration

hazard5_cpu #(
	.RESET_VECTOR    (SDRAM_BASE + 32'hc0),
	.EXTENSION_C     (1),
	.EXTENSION_M     (1),
	.MULDIV_UNROLL   (1),
	.CSR_M_MANDATORY (1),
	.CSR_M_TRAP      (1),
	.CSR_COUNTER     (0),
	.MTVEC_INIT      (SDRAM_BASE)
) inst_hazard5_cpu (
	.clk             (clk_sys),
	.rst_n           (rst_n_sys),

	.ahblm_haddr     (proc_haddr),
	.ahblm_hwrite    (proc_hwrite),
	.ahblm_htrans    (proc_htrans),
	.ahblm_hsize     (proc_hsize),
	.ahblm_hburst    (proc_hburst),
	.ahblm_hprot     (proc_hprot),
	.ahblm_hmastlock (proc_hmastlock),
	.ahblm_hready    (proc_hready),
	.ahblm_hresp     (proc_hresp),
	.ahblm_hwdata    (proc_hwdata),
	.ahblm_hrdata    (proc_hrdata),

	.irq             ({
		15'h0,
		uart_irq
	})
);

// ----------------------------------------------------------------------------
// DVI Out

wire [9:0] tmds0;
wire [9:0] tmds1;
wire [9:0] tmds2;

// FIXME just outputting a test pattern, and probably shouldn't all be at this
// hierarchy level

wire rgb_rdy;

reg [10:0] hctr;
reg [10:0] vctr;
reg [10:0] framectr;

always @ (posedge clk_dvi_pix or negedge rst_n_dvi_pix) begin
	if (!rst_n_dvi_pix) begin
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
	.clk     (clk_dvi_pix),
	.rst_n   (rst_n_dvi_pix),
	.en      (1'b1),

	.r       ((hctr + framectr) << 2),
	.g       ((vctr + framectr) << 2),
	.b       (framectr),
	.rgb_rdy (rgb_rdy),

	.tmds2   (tmds2),
	.tmds1   (tmds1),
	.tmds0   (tmds0)
);

dvi_serialiser ser0 (
	.clk_pix   (clk_dvi_pix),
	.rst_n_pix (rst_n_dvi_pix),
	.clk_x5    (clk_dvi_bit),
	.rst_n_x5  (rst_n_dvi_bit),

	.d         (tmds0),
	.qp        (dvip[0]),
	.qn        (dvin[0])
);

dvi_serialiser ser1 (
	.clk_pix   (clk_dvi_pix),
	.rst_n_pix (rst_n_dvi_pix),
	.clk_x5    (clk_dvi_bit),
	.rst_n_x5  (rst_n_dvi_bit),

	.d         (tmds1),
	.qp        (dvip[1]),
	.qn        (dvin[1])
);


dvi_serialiser ser2 (
	.clk_pix   (clk_dvi_pix),
	.rst_n_pix (rst_n_dvi_pix),
	.clk_x5    (clk_dvi_bit),
	.rst_n_x5  (rst_n_dvi_bit),

	.d         (tmds2),
	.qp        (dvip[2]),
	.qn        (dvin[2])
);

dvi_serialiser serclk (
	.clk_pix   (clk_dvi_pix),
	.rst_n_pix (rst_n_dvi_pix),
	.clk_x5    (clk_dvi_bit),
	.rst_n_x5  (rst_n_dvi_bit),

	.d         (10'b0000011111),
	.qp        (dvip[3]),
	.qn        (dvin[3])
);


// ----------------------------------------------------------------------------
// Busfabric

ahbl_splitter #(
	.N_PORTS   (2),
	.W_ADDR    (W_HADDR),
	.W_DATA    (W_HDATA),
	.ADDR_MAP  ({     APB_BASE,    SDRAM_BASE}),
	.ADDR_MASK ({32'hf000_0000, 32'hf000_0000})
) proc_ahbl_split (
	.clk             (clk_sys),
	.rst_n           (rst_n_sys),

	.src_hready      (proc_hready),
	.src_hready_resp (proc_hready), // Tie HREADYOUT -> HREADY as this is top of fabric
	.src_hresp       (proc_hresp),
	.src_haddr       (proc_haddr),
	.src_hwrite      (proc_hwrite),
	.src_htrans      (proc_htrans),
	.src_hsize       (proc_hsize),
	.src_hburst      (proc_hburst),
	.src_hprot       (proc_hprot),
	.src_hmastlock   (proc_hmastlock),
	.src_hwdata      (proc_hwdata),
	.src_hrdata      (proc_hrdata),

	.dst_hready      ({bridge_hready      , sram_hready     }),
	.dst_hready_resp ({bridge_hready_resp , sram_hready_resp}),
	.dst_hresp       ({bridge_hresp       , sram_hresp      }),
	.dst_haddr       ({bridge_haddr       , sram_haddr      }),
	.dst_hwrite      ({bridge_hwrite      , sram_hwrite     }),
	.dst_htrans      ({bridge_htrans      , sram_htrans     }),
	.dst_hsize       ({bridge_hsize       , sram_hsize      }),
	.dst_hburst      ({bridge_hburst      , sram_hburst     }),
	.dst_hprot       ({bridge_hprot       , sram_hprot      }),
	.dst_hmastlock   ({bridge_hmastlock   , sram_hmastlock  }),
	.dst_hwdata      ({bridge_hwdata      , sram_hwdata     }),
	.dst_hrdata      ({bridge_hrdata      , sram_hrdata     })
);


ahbl_to_apb #(
	.W_HADDR (W_HADDR),
	.W_PADDR (W_PADDR),
	.W_DATA  (W_HDATA)
) inst_ahbl_to_apb (
	.clk               (clk_sys),
	.rst_n             (rst_n_sys),

	.ahbls_hready      (bridge_hready),
	.ahbls_hready_resp (bridge_hready_resp),
	.ahbls_hresp       (bridge_hresp),
	.ahbls_haddr       (bridge_haddr),
	.ahbls_hwrite      (bridge_hwrite),
	.ahbls_htrans      (bridge_htrans),
	.ahbls_hsize       (bridge_hsize),
	.ahbls_hburst      (bridge_hburst),
	.ahbls_hprot       (bridge_hprot),
	.ahbls_hmastlock   (bridge_hmastlock),
	.ahbls_hwdata      (bridge_hwdata),
	.ahbls_hrdata      (bridge_hrdata),

	.apbm_paddr        (bridge_paddr),
	.apbm_psel         (bridge_psel),
	.apbm_penable      (bridge_penable),
	.apbm_pwrite       (bridge_pwrite),
	.apbm_pwdata       (bridge_pwdata),
	.apbm_pready       (bridge_pready),
	.apbm_prdata       (bridge_prdata),
	.apbm_pslverr      (bridge_pslverr)
);

apb_splitter #(
	.W_ADDR    (W_PADDR),
	.W_DATA    (W_HDATA),
	.N_SLAVES  (2),
	.ADDR_MAP  ({16'hf000 , 16'h0000}),
	.ADDR_MASK ({16'hf000 , 16'hf000})
) inst_apb_splitter (
	.apbs_paddr   (bridge_paddr),
	.apbs_psel    (bridge_psel),
	.apbs_penable (bridge_penable),
	.apbs_pwrite  (bridge_pwrite),
	.apbs_pwdata  (bridge_pwdata),
	.apbs_pready  (bridge_pready),
	.apbs_prdata  (bridge_prdata),
	.apbs_pslverr (bridge_pslverr),

	.apbm_paddr   ({tbman_paddr   , uart_paddr  }),
	.apbm_psel    ({tbman_psel    , uart_psel   }),
	.apbm_penable ({tbman_penable , uart_penable}),
	.apbm_pwrite  ({tbman_pwrite  , uart_pwrite }),
	.apbm_pwdata  ({tbman_pwdata  , uart_pwdata }),
	.apbm_pready  ({tbman_pready  , uart_pready }),
	.apbm_prdata  ({tbman_prdata  , uart_prdata }),
	.apbm_pslverr ({tbman_pslverr , uart_pslverr})
);


// ----------------------------------------------------------------------------
// Memory

ahb_sync_sram #(
	.W_DATA       (W_HDATA),
	.W_ADDR       (W_HADDR),
	.DEPTH        (1 << 11), // 2**11 words = 8 kiB
	.PRELOAD_FILE (BOOTRAM_PRELOAD)
) sram1 (
	.clk               (clk_sys),
	.rst_n             (rst_n_sys),
	.ahbls_hready_resp (sram_hready_resp),
	.ahbls_hready      (sram_hready),
	.ahbls_hresp       (sram_hresp),
	.ahbls_haddr       (sram_haddr),
	.ahbls_hwrite      (sram_hwrite),
	.ahbls_htrans      (sram_htrans),
	.ahbls_hsize       (sram_hsize),
	.ahbls_hburst      (sram_hburst),
	.ahbls_hprot       (sram_hprot),
	.ahbls_hmastlock   (sram_hmastlock),
	.ahbls_hwdata      (sram_hwdata),
	.ahbls_hrdata      (sram_hrdata)
);

// ----------------------------------------------------------------------------
// Peripherals

uart_mini #(
	.FIFO_DEPTH (4)
) uart0 (
	.clk          (clk_sys),
	.rst_n        (rst_n_sys),
	.apbs_psel    (uart_psel),
	.apbs_penable (uart_penable),
	.apbs_pwrite  (uart_pwrite),
	.apbs_paddr   (uart_paddr),
	.apbs_pwdata  (uart_pwdata),
	.apbs_prdata  (uart_prdata),
	.apbs_pready  (uart_pready),
	.apbs_pslverr (uart_pslverr),
	.rx           (uart_rx),
	.tx           (uart_tx),
	.cts          (1'b0),
	.rts          (/* unused */),
	.irq          (uart_irq),
	.dreq         (/* unused */)
);

tbman inst_tbman (
	.clk          (clk_sys),
	.rst_n        (rst_n_sys),

	.apbs_psel    (tbman_psel),
	.apbs_penable (tbman_penable),
	.apbs_pwrite  (tbman_pwrite),
	.apbs_paddr   (tbman_paddr),
	.apbs_pwdata  (tbman_pwdata),
	.apbs_prdata  (tbman_prdata),
	.apbs_pready  (tbman_pready),
	.apbs_pslverr (tbman_pslverr)
);

endmodule

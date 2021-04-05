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
	parameter W_SDRAM_DATA = 16,
	parameter W_AUDIO_OUT = 4
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

	// Parallel audio out (e.g. resistor DAC or 1-bit RC)
	output wire [W_AUDIO_OUT-1:0]     audio_out_l,
	output wire [W_AUDIO_OUT-1:0]     audio_out_r,

	// GPIO and serial peripherals
	output wire                       uart_tx,
	input  wire                       uart_rx
);

localparam W_HADDR = 32;
localparam W_HDATA = 32;
localparam W_PADDR = 16;

localparam BOOTRAM_BASE = 32'h0000_0000;
localparam SDRAM_BASE   = 32'h2000_0000;
localparam APB_BASE     = 32'h4000_0000;

localparam ICACHE_SIZE_BYTES = 4 * 1024;
localparam DCACHE_SIZE_BYTES = 4 * 1024;
localparam W_CACHE_LINE = 4 * W_HDATA;

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

// Proc + cache bus signals
wire               icache_hready;
wire               icache_hresp;
wire [W_HADDR-1:0] icache_haddr;
wire               icache_hwrite;
wire [1:0]         icache_htrans;
wire [2:0]         icache_hsize;
wire [2:0]         icache_hburst;
wire [3:0]         icache_hprot;
wire               icache_hmastlock;
wire [W_HDATA-1:0] icache_hwdata;
wire [W_HDATA-1:0] icache_hrdata;

wire               dcache_hready;
wire               dcache_hresp;
wire [W_HADDR-1:0] dcache_haddr;
wire               dcache_hwrite;
wire [1:0]         dcache_htrans;
wire [2:0]         dcache_hsize;
wire [2:0]         dcache_hburst;
wire [3:0]         dcache_hprot;
wire               dcache_hmastlock;
wire [W_HDATA-1:0] dcache_hwdata;
wire [W_HDATA-1:0] dcache_hrdata;

wire               proc_i_hready;
wire               proc_i_hresp;
wire [W_HADDR-1:0] proc_i_haddr;
wire               proc_i_hwrite;
wire [1:0]         proc_i_htrans;
wire [2:0]         proc_i_hsize;
wire [2:0]         proc_i_hburst;
wire [3:0]         proc_i_hprot;
wire               proc_i_hmastlock;
wire [W_HDATA-1:0] proc_i_hwdata;
wire [W_HDATA-1:0] proc_i_hrdata;

wire               proc_d_hready;
wire               proc_d_hresp;
wire [W_HADDR-1:0] proc_d_haddr;
wire               proc_d_hwrite;
wire [1:0]         proc_d_htrans;
wire [2:0]         proc_d_hsize;
wire [2:0]         proc_d_hburst;
wire [3:0]         proc_d_hprot;
wire [3:0]         proc_d_hprot_raw;
wire               proc_d_hmastlock;
wire [W_HDATA-1:0] proc_d_hwdata;
wire [W_HDATA-1:0] proc_d_hrdata;

// SDRAM burst port signals

wire               sdram_dcache_hready;
wire               sdram_dcache_hready_resp;
wire               sdram_dcache_hresp;
wire [W_HADDR-1:0] sdram_dcache_haddr;
wire               sdram_dcache_hwrite;
wire [1:0]         sdram_dcache_htrans;
wire [2:0]         sdram_dcache_hsize;
wire [2:0]         sdram_dcache_hburst;
wire [3:0]         sdram_dcache_hprot;
wire [3:0]         sdram_dcache_hprot_raw;
wire               sdram_dcache_hmastlock;
wire [W_HDATA-1:0] sdram_dcache_hwdata;
wire [W_HDATA-1:0] sdram_dcache_hrdata;

wire               sdram_icache_hready;
wire               sdram_icache_hready_resp;
wire               sdram_icache_hresp;
wire [W_HADDR-1:0] sdram_icache_haddr;
wire               sdram_icache_hwrite;
wire [1:0]         sdram_icache_htrans;
wire [2:0]         sdram_icache_hsize;
wire [2:0]         sdram_icache_hburst;
wire [3:0]         sdram_icache_hprot;
wire [3:0]         sdram_icache_hprot_raw;
wire               sdram_icache_hmastlock;
wire [W_HDATA-1:0] sdram_icache_hwdata;
wire [W_HDATA-1:0] sdram_icache_hrdata;

// video port currently hooked up to a burstgen for testing purposes
wire               sdram_video_hready;
wire               sdram_video_hready_resp;
wire               sdram_video_hresp;
wire [W_HADDR-1:0] sdram_video_haddr;
wire               sdram_video_hwrite;
wire [1:0]         sdram_video_htrans;
wire [2:0]         sdram_video_hsize;
wire [2:0]         sdram_video_hburst;
wire [3:0]         sdram_video_hprot;
wire [3:0]         sdram_video_hprot_raw;
wire               sdram_video_hmastlock;
wire [W_HDATA-1:0] sdram_video_hwdata;
wire [W_HDATA-1:0] sdram_video_hrdata;

// Boot RAM + bus arbiter

wire               sram_dcache_hready;
wire               sram_dcache_hready_resp;
wire               sram_dcache_hresp;
wire [W_HADDR-1:0] sram_dcache_haddr;
wire               sram_dcache_hwrite;
wire [1:0]         sram_dcache_htrans;
wire [2:0]         sram_dcache_hsize;
wire [2:0]         sram_dcache_hburst;
wire [3:0]         sram_dcache_hprot;
wire [3:0]         sram_dcache_hprot_raw;
wire               sram_dcache_hmastlock;
wire [W_HDATA-1:0] sram_dcache_hwdata;
wire [W_HDATA-1:0] sram_dcache_hrdata;

wire               sram_icache_hready;
wire               sram_icache_hready_resp;
wire               sram_icache_hresp;
wire [W_HADDR-1:0] sram_icache_haddr;
wire               sram_icache_hwrite;
wire [1:0]         sram_icache_htrans;
wire [2:0]         sram_icache_hsize;
wire [2:0]         sram_icache_hburst;
wire [3:0]         sram_icache_hprot;
wire [3:0]         sram_icache_hprot_raw;
wire               sram_icache_hmastlock;
wire [W_HDATA-1:0] sram_icache_hwdata;
wire [W_HDATA-1:0] sram_icache_hrdata;

wire               sram_hready;
wire               sram_hready_resp;
wire               sram_hresp;
wire [W_HADDR-1:0] sram_haddr;
wire               sram_hwrite;
wire [1:0]         sram_htrans;
wire [2:0]         sram_hsize;
wire [2:0]         sram_hburst;
wire [3:0]         sram_hprot;
wire               sram_hmastlock;
wire [W_HDATA-1:0] sram_hwdata;
wire [W_HDATA-1:0] sram_hrdata;

// APB bridge and APB fabric

wire               bridge_hready;
wire               bridge_hready_resp;
wire               bridge_hresp;
wire [W_HADDR-1:0] bridge_haddr;
wire               bridge_hwrite;
wire [1:0]         bridge_htrans;
wire [2:0]         bridge_hsize;
wire [2:0]         bridge_hburst;
wire [3:0]         bridge_hprot;
wire               bridge_hmastlock;
wire [W_HDATA-1:0] bridge_hwdata;
wire [W_HDATA-1:0] bridge_hrdata;

wire [W_PADDR-1:0] bridge_paddr;
wire               bridge_psel;
wire               bridge_penable;
wire               bridge_pwrite;
wire [W_HDATA-1:0] bridge_pwdata;
wire               bridge_pready;
wire [W_HDATA-1:0] bridge_prdata;
wire               bridge_pslverr;

wire [W_PADDR-1:0] uart_paddr;
wire               uart_psel;
wire               uart_penable;
wire               uart_pwrite;
wire [W_HDATA-1:0] uart_pwdata;
wire               uart_pready;
wire [W_HDATA-1:0] uart_prdata;
wire               uart_pslverr;

wire               uart_irq;

wire [W_PADDR-1:0] audio_paddr;
wire               audio_psel;
wire               audio_penable;
wire               audio_pwrite;
wire [W_HDATA-1:0] audio_pwdata;
wire               audio_pready;
wire [W_HDATA-1:0] audio_prdata;
wire               audio_pslverr;

wire               audio_irq;

wire [W_PADDR-1:0] sdram_paddr;
wire               sdram_psel;
wire               sdram_penable;
wire               sdram_pwrite;
wire [W_HDATA-1:0] sdram_pwdata;
wire               sdram_pready;
wire [W_HDATA-1:0] sdram_prdata;
wire               sdram_pslverr;

wire [W_PADDR-1:0] tbman_paddr;
wire               tbman_psel;
wire               tbman_penable;
wire               tbman_pwrite;
wire [W_HDATA-1:0] tbman_pwdata;
wire               tbman_pready;
wire [W_HDATA-1:0] tbman_prdata;
wire               tbman_pslverr;

wire [W_PADDR-1:0] bgen0_paddr;
wire               bgen0_psel;
wire               bgen0_penable;
wire               bgen0_pwrite;
wire [W_HDATA-1:0] bgen0_pwdata;
wire               bgen0_pready;
wire [W_HDATA-1:0] bgen0_prdata;
wire               bgen0_pslverr;


// ----------------------------------------------------------------------------
// Processor and caches

hazard5_cpu_2port #(
	.RESET_VECTOR    (BOOTRAM_BASE + 32'h00),
	.MTVEC_INIT      (SDRAM_BASE),
	.MTVEC_WMASK     (32'h0000_0000),      // Not modifiable

	.EXTENSION_C     (0),
	.EXTENSION_M     (1),
	.CSR_M_MANDATORY (0),
	.CSR_M_TRAP      (1),
	.CSR_COUNTER     (0),

	.MULDIV_UNROLL   (1),
	.MUL_FAST        (1),
	.REDUCED_BYPASS  (0)
) cpu (
	.clk         (clk_sys),
	.rst_n       (rst_n_sys),

	.i_haddr     (proc_i_haddr),
	.i_hwrite    (proc_i_hwrite),
	.i_htrans    (proc_i_htrans),
	.i_hsize     (proc_i_hsize),
	.i_hburst    (proc_i_hburst),
	.i_hprot     (proc_i_hprot),
	.i_hmastlock (proc_i_hmastlock),
	.i_hready    (proc_i_hready),
	.i_hresp     (proc_i_hresp),
	.i_hwdata    (proc_i_hwdata),
	.i_hrdata    (proc_i_hrdata),

	.d_haddr     (proc_d_haddr),
	.d_hwrite    (proc_d_hwrite),
	.d_htrans    (proc_d_htrans),
	.d_hsize     (proc_d_hsize),
	.d_hburst    (proc_d_hburst),
	.d_hprot     (proc_d_hprot_raw),
	.d_hmastlock (proc_d_hmastlock),
	.d_hready    (proc_d_hready),
	.d_hresp     (proc_d_hresp),
	.d_hwdata    (proc_d_hwdata),
	.d_hrdata    (proc_d_hrdata),

	.irq             ({
		14'h0,
		audio_irq,
		uart_irq
	})
);

// Cacheable and bufferable iff below 0x4000_0000
assign proc_d_hprot = {{2{proc_d_haddr[31:30] == 2'b00}}, proc_d_hprot_raw[1:0]};

ahb_cache_writeback #(
	.W_ADDR (W_HADDR),
	.W_DATA (W_HDATA),
	.W_LINE (W_CACHE_LINE),
	.DEPTH  (DCACHE_SIZE_BYTES / (W_CACHE_LINE / 8))
) dcache (
	.clk             (clk_sys),
	.rst_n           (rst_n_sys),

	.src_hready_resp (proc_d_hready),
	.src_hready      (proc_d_hready),
	.src_hresp       (proc_d_hresp),
	.src_haddr       (proc_d_haddr),
	.src_hwrite      (proc_d_hwrite),
	.src_htrans      (proc_d_htrans),
	.src_hsize       (proc_d_hsize),
	.src_hburst      (proc_d_hburst),
	.src_hprot       (proc_d_hprot),
	.src_hmastlock   (proc_d_hmastlock),
	.src_hwdata      (proc_d_hwdata),
	.src_hrdata      (proc_d_hrdata),

	.dst_hready_resp (dcache_hready),
	.dst_hready      (/* unused */),
	.dst_hresp       (dcache_hresp),
	.dst_haddr       (dcache_haddr),
	.dst_hwrite      (dcache_hwrite),
	.dst_htrans      (dcache_htrans),
	.dst_hsize       (dcache_hsize),
	.dst_hburst      (dcache_hburst),
	.dst_hprot       (dcache_hprot),
	.dst_hmastlock   (dcache_hmastlock),
	.dst_hwdata      (dcache_hwdata),
	.dst_hrdata      (dcache_hrdata)
);

ahb_cache_readonly #(
	.W_ADDR       (W_HADDR),
	.W_DATA       (W_HDATA),
	.W_LINE       (W_CACHE_LINE),
	.DEPTH        (ICACHE_SIZE_BYTES / (W_CACHE_LINE / 8))
) icache (
	.clk             (clk_sys),
	.rst_n           (rst_n_sys),

	.src_hready_resp (proc_i_hready),
	.src_hready      (proc_i_hready),
	.src_hresp       (proc_i_hresp),
	.src_haddr       (proc_i_haddr),
	.src_hwrite      (proc_i_hwrite),
	.src_htrans      (proc_i_htrans),
	.src_hsize       (proc_i_hsize),
	.src_hburst      (proc_i_hburst),
	.src_hprot       (proc_i_hprot),
	.src_hmastlock   (proc_i_hmastlock),
	.src_hwdata      (proc_i_hwdata),
	.src_hrdata      (proc_i_hrdata),

	.dst_hready_resp (icache_hready),
	.dst_hready      (/* unused */),
	.dst_hresp       (icache_hresp),
	.dst_haddr       (icache_haddr),
	.dst_hwrite      (icache_hwrite),
	.dst_htrans      (icache_htrans),
	.dst_hsize       (icache_hsize),
	.dst_hburst      (icache_hburst),
	.dst_hprot       (icache_hprot),
	.dst_hmastlock   (icache_hmastlock),
	.dst_hwdata      (icache_hwdata),
	.dst_hrdata      (icache_hrdata)
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
	.ADDR_MAP  ({   SDRAM_BASE,  BOOTRAM_BASE}),
	.ADDR_MASK ({32'hf000_0000, 32'hf000_0000})
) icache_bus_splitter (
	.clk             (clk_sys),
	.rst_n           (rst_n_sys),

	.src_hready      (icache_hready   ),
	.src_hready_resp (icache_hready   ), // Tie HREADYOUT -> HREADY as this is top of fabric
	.src_hresp       (icache_hresp    ),
	.src_haddr       (icache_haddr    ),
	.src_hwrite      (icache_hwrite   ),
	.src_htrans      (icache_htrans   ),
	.src_hsize       (icache_hsize    ),
	.src_hburst      (icache_hburst   ),
	.src_hprot       (icache_hprot    ),
	.src_hmastlock   (icache_hmastlock),
	.src_hwdata      (icache_hwdata   ),
	.src_hrdata      (icache_hrdata   ),

	.dst_hready      ({sdram_icache_hready      , sram_icache_hready     }),
	.dst_hready_resp ({sdram_icache_hready_resp , sram_icache_hready_resp}),
	.dst_hresp       ({sdram_icache_hresp       , sram_icache_hresp      }),
	.dst_haddr       ({sdram_icache_haddr       , sram_icache_haddr      }),
	.dst_hwrite      ({sdram_icache_hwrite      , sram_icache_hwrite     }),
	.dst_htrans      ({sdram_icache_htrans      , sram_icache_htrans     }),
	.dst_hsize       ({sdram_icache_hsize       , sram_icache_hsize      }),
	.dst_hburst      ({sdram_icache_hburst      , sram_icache_hburst     }),
	.dst_hprot       ({sdram_icache_hprot       , sram_icache_hprot      }),
	.dst_hmastlock   ({sdram_icache_hmastlock   , sram_icache_hmastlock  }),
	.dst_hwdata      ({sdram_icache_hwdata      , sram_icache_hwdata     }),
	.dst_hrdata      ({sdram_icache_hrdata      , sram_icache_hrdata     })
);

ahbl_splitter #(
	.N_PORTS   (3),
	.W_ADDR    (W_HADDR),
	.W_DATA    (W_HDATA),
	.ADDR_MAP  ({     APB_BASE,    SDRAM_BASE,  BOOTRAM_BASE}),
	.ADDR_MASK ({32'hf000_0000, 32'hf000_0000, 32'hf000_0000})
) dcache_bus_splitter (
	.clk             (clk_sys),
	.rst_n           (rst_n_sys),

	.src_hready      (dcache_hready    ),
	.src_hready_resp (dcache_hready    ), // Tie HREADYOUT -> HREADY as this is top of fabric
	.src_hresp       (dcache_hresp     ),
	.src_haddr       (dcache_haddr     ),
	.src_hwrite      (dcache_hwrite    ),
	.src_htrans      (dcache_htrans    ),
	.src_hsize       (dcache_hsize     ),
	.src_hburst      (dcache_hburst    ),
	.src_hprot       (dcache_hprot     ),
	.src_hmastlock   (dcache_hmastlock ),
	.src_hwdata      (dcache_hwdata    ),
	.src_hrdata      (dcache_hrdata    ),

	.dst_hready      ({bridge_hready      , sdram_dcache_hready      , sram_dcache_hready     }),
	.dst_hready_resp ({bridge_hready_resp , sdram_dcache_hready_resp , sram_dcache_hready_resp}),
	.dst_hresp       ({bridge_hresp       , sdram_dcache_hresp       , sram_dcache_hresp      }),
	.dst_haddr       ({bridge_haddr       , sdram_dcache_haddr       , sram_dcache_haddr      }),
	.dst_hwrite      ({bridge_hwrite      , sdram_dcache_hwrite      , sram_dcache_hwrite     }),
	.dst_htrans      ({bridge_htrans      , sdram_dcache_htrans      , sram_dcache_htrans     }),
	.dst_hsize       ({bridge_hsize       , sdram_dcache_hsize       , sram_dcache_hsize      }),
	.dst_hburst      ({bridge_hburst      , sdram_dcache_hburst      , sram_dcache_hburst     }),
	.dst_hprot       ({bridge_hprot       , sdram_dcache_hprot       , sram_dcache_hprot      }),
	.dst_hmastlock   ({bridge_hmastlock   , sdram_dcache_hmastlock   , sram_dcache_hmastlock  }),
	.dst_hwdata      ({bridge_hwdata      , sdram_dcache_hwdata      , sram_dcache_hwdata     }),
	.dst_hrdata      ({bridge_hrdata      , sdram_dcache_hrdata      , sram_dcache_hrdata     })
);

ahbl_arbiter #(
	.N_PORTS   (2),
	.W_ADDR    (W_HADDR),
	.W_DATA    (W_HDATA)
) bootram_bus_arbiter (
	.clk             (clk_sys),
	.rst_n           (rst_n_sys),

	.src_hready_resp ({sram_icache_hready_resp , sram_dcache_hready_resp }),
	.src_hready      ({sram_icache_hready      , sram_dcache_hready      }),
	.src_hresp       ({sram_icache_hresp       , sram_dcache_hresp       }),
	.src_haddr       ({sram_icache_haddr       , sram_dcache_haddr       }),
	.src_hwrite      ({sram_icache_hwrite      , sram_dcache_hwrite      }),
	.src_htrans      ({sram_icache_htrans      , sram_dcache_htrans      }),
	.src_hsize       ({sram_icache_hsize       , sram_dcache_hsize       }),
	.src_hburst      ({sram_icache_hburst      , sram_dcache_hburst      }),
	.src_hprot       ({sram_icache_hprot       , sram_dcache_hprot       }),
	.src_hmastlock   ({sram_icache_hmastlock   , sram_dcache_hmastlock   }),
	.src_hwdata      ({sram_icache_hwdata      , sram_dcache_hwdata      }),
	.src_hrdata      ({sram_icache_hrdata      , sram_dcache_hrdata      }),

	.dst_hready_resp (sram_hready_resp),
	.dst_hready      (sram_hready     ),
	.dst_hresp       (sram_hresp      ),
	.dst_haddr       (sram_haddr      ),
	.dst_hwrite      (sram_hwrite     ),
	.dst_htrans      (sram_htrans     ),
	.dst_hsize       (sram_hsize      ),
	.dst_hburst      (sram_hburst     ),
	.dst_hprot       (sram_hprot      ),
	.dst_hmastlock   (sram_hmastlock  ),
	.dst_hwdata      (sram_hwdata     ),
	.dst_hrdata      (sram_hrdata     )
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
	.N_SLAVES  (5),
	.ADDR_MAP  ({16'hf000 , 16'h3000 , 16'h2000 , 16'h1000 , 16'h0000}),
	.ADDR_MASK ({16'hf000 , 16'hf000 , 16'hf000 , 16'hf000 , 16'hf000})
) inst_apb_splitter (
	.apbs_paddr   (bridge_paddr),
	.apbs_psel    (bridge_psel),
	.apbs_penable (bridge_penable),
	.apbs_pwrite  (bridge_pwrite),
	.apbs_pwdata  (bridge_pwdata),
	.apbs_pready  (bridge_pready),
	.apbs_prdata  (bridge_prdata),
	.apbs_pslverr (bridge_pslverr),

	.apbm_paddr   ({tbman_paddr   , audio_paddr   , bgen0_paddr   , sdram_paddr   , uart_paddr  }),
	.apbm_psel    ({tbman_psel    , audio_psel    , bgen0_psel    , sdram_psel    , uart_psel   }),
	.apbm_penable ({tbman_penable , audio_penable , bgen0_penable , sdram_penable , uart_penable}),
	.apbm_pwrite  ({tbman_pwrite  , audio_pwrite  , bgen0_pwrite  , sdram_pwrite  , uart_pwrite }),
	.apbm_pwdata  ({tbman_pwdata  , audio_pwdata  , bgen0_pwdata  , sdram_pwdata  , uart_pwdata }),
	.apbm_pready  ({tbman_pready  , audio_pready  , bgen0_pready  , sdram_pready  , uart_pready }),
	.apbm_prdata  ({tbman_prdata  , audio_prdata  , bgen0_prdata  , sdram_prdata  , uart_prdata }),
	.apbm_pslverr ({tbman_pslverr , audio_pslverr , bgen0_pslverr , sdram_pslverr , uart_pslverr})
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

ahbl_sdram #(
	.COLUMN_BITS        (10),
	.ROW_BITS           (13),
	.W_SDRAM_BANKSEL    (2),
	.W_SDRAM_ADDR       (13),
	.W_SDRAM_DATA       (16),
	.N_MASTERS          (3),
	.LEN_AHBL_BURST     (4),

	.FIXED_TIMINGS      (1), // 1: use fixed values, 0: allow programming via APB.
	// Following are for AS4C32M16SB-7 at (aspirational) 80 MHz
	.FIXED_TIME_RC      (3'd5   ), // 63 ns 6 clk (just!)
	.FIXED_TIME_RCD     (3'd1   ), // 21 ns 2 clk
	.FIXED_TIME_RP      (3'd1   ), // 21 ns 2 clk
	.FIXED_TIME_RRD     (3'd1   ), // 14 ns 2 clk
	.FIXED_TIME_RAS     (3'd3   ), // 42 ns 4 clk
	.FIXED_TIME_WR      (3'd1   ), // 14 ns 2 clk
	.FIXED_TIME_CAS     (3'd1   ), // 2 clk up to 100 MHz, 3 clk above. Must match modereg.
	.FIXED_TIME_REFRESH (12'd623)  // 7.8 us 624 clk
) inst_ahbl_sdram (
	.clk               (clk_sys),
	.rst_n             (rst_n_sys),

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

	.apbs_psel         (sdram_psel),
	.apbs_penable      (sdram_penable),
	.apbs_pwrite       (sdram_pwrite),
	.apbs_paddr        (sdram_paddr),
	.apbs_pwdata       (sdram_pwdata),
	.apbs_prdata       (sdram_prdata),
	.apbs_pready       (sdram_pready),
	.apbs_pslverr      (sdram_pslverr),
	                   // -> ascending priority
	.ahbls_hready      ({ sdram_icache_hready      ,  sdram_dcache_hready      ,  sdram_video_hready                 }),
	.ahbls_hready_resp ({ sdram_icache_hready_resp ,  sdram_dcache_hready_resp ,  sdram_video_hready_resp            }),
	.ahbls_hresp       ({ sdram_icache_hresp       ,  sdram_dcache_hresp       ,  sdram_video_hresp                  }),
	.ahbls_haddr       ({ sdram_icache_haddr       ,  sdram_dcache_haddr       ,  sdram_video_haddr                  }),
	.ahbls_hwrite      ({ sdram_icache_hwrite      ,  sdram_dcache_hwrite      ,  sdram_video_hwrite                 }),
	.ahbls_htrans      ({ sdram_icache_htrans      ,  sdram_dcache_htrans      ,  sdram_video_htrans                 }),
	.ahbls_hsize       ({ sdram_icache_hsize       ,  sdram_dcache_hsize       ,  sdram_video_hsize                  }),
	.ahbls_hburst      ({ sdram_icache_hburst      ,  sdram_dcache_hburst      ,  sdram_video_hburst                 }),
	.ahbls_hprot       ({ sdram_icache_hprot       ,  sdram_dcache_hprot       ,  sdram_video_hprot                  }),
	.ahbls_hmastlock   ({ sdram_icache_hmastlock   ,  sdram_dcache_hmastlock   ,  sdram_video_hmastlock              }),
	.ahbls_hwdata      ({ sdram_icache_hwdata      ,  sdram_dcache_hwdata      ,  sdram_video_hwdata                 }),
	.ahbls_hrdata      ({ sdram_icache_hrdata      ,  sdram_dcache_hrdata      ,  sdram_video_hrdata                 })
);


// ----------------------------------------------------------------------------
// Peripherals

uart_mini #(
	.FIFO_DEPTH (8)
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

pcm_audio_out #(
	.W_OUT          (W_AUDIO_OUT),
	.LOG_OVERSAMPLE (4),
	.FIFO_DEPTH     (64)
) pcm0 (
	.clk          (clk_sys),
	.rst_n        (rst_n_sys),

	.apbs_psel    (audio_psel),
	.apbs_penable (audio_penable),
	.apbs_pwrite  (audio_pwrite),
	.apbs_paddr   (audio_paddr),
	.apbs_pwdata  (audio_pwdata),
	.apbs_prdata  (audio_prdata),
	.apbs_pready  (audio_pready),
	.apbs_pslverr (audio_pslverr),

	.out_l        (audio_out_l),
	.out_r        (audio_out_r),

	.irq          (audio_irq)
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

apb_burst_gen #(
	.W_ADDR(W_HADDR),
	.W_DATA(W_HDATA)
) bgen0 (
	.clk             (clk_sys),
	.rst_n           (rst_n_sys),

	.apbs_psel       (bgen0_psel),
	.apbs_penable    (bgen0_penable),
	.apbs_pwrite     (bgen0_pwrite),
	.apbs_paddr      (bgen0_paddr),
	.apbs_pwdata     (bgen0_pwdata),
	.apbs_prdata     (bgen0_prdata),
	.apbs_pready     (bgen0_pready),
	.apbs_pslverr    (bgen0_pslverr),

	.ahblm_haddr     (sdram_video_haddr),
	.ahblm_hwrite    (sdram_video_hwrite),
	.ahblm_htrans    (sdram_video_htrans),
	.ahblm_hsize     (sdram_video_hsize),
	.ahblm_hburst    (sdram_video_hburst),
	.ahblm_hprot     (sdram_video_hprot),
	.ahblm_hmastlock (sdram_video_hmastlock),
	.ahblm_hready    (sdram_video_hready),
	.ahblm_hresp     (sdram_video_hresp),
	.ahblm_hwdata    (sdram_video_hwdata),
	.ahblm_hrdata    (sdram_video_hrdata)
);
assign sdram_video_hready = sdram_video_hready_resp;

endmodule

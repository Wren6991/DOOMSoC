`default_nettype none

module tb;

// ----------------------------------------------------------------------------
// DUT

localparam COLUMN_BITS        = 10;
localparam ROW_BITS           = 13;
localparam W_SDRAM_BANKSEL    = 2;
localparam W_SDRAM_ADDR       = 13;
localparam W_SDRAM_DATA       = 16;
localparam N_MASTERS          = 2;
localparam LEN_AHBL_BURST     = 4;
localparam W_HADDR            = 32;
localparam W_HDATA            = 32;

`include "sdram_dut_instantiation.vh"

// ----------------------------------------------------------------------------
// Stimulus

localparam CLK_PERIOD = 10;
always #(0.5 * CLK_PERIOD) clk = !clk;

`include "sdram_task.vh"

localparam W_ADDR_RANGE = 2 + 2 + COLUMN_BITS + 1;
localparam N_DATA_LINES = 1 << (W_ADDR_RANGE - 4); // size of tested memory range, measured in bursts
localparam TEST_LEN = N_DATA_LINES * 20;

integer i;


reg [127:0] shadow_mem [0:N_DATA_LINES*N_MASTERS-1];

initial begin
	clk = 0;
	rst_n = 0;
	apbs_psel = 0;
	apbs_penable = 0;
	apbs_pwrite = 0;
	apbs_paddr = 0;
	apbs_pwdata = 0;
	for (i = 0; i < N_MASTERS; i = i + 1) begin
		ahbls_haddr[i] = 0;
		ahbls_hwrite[i] = 0;
		ahbls_htrans[i] = 0;
		ahbls_hsize[i] = 0;
		ahbls_hburst[i] = 0;
		ahbls_hprot[i] = 0;
		ahbls_hmastlock[i] = 0;
		ahbls_hwdata[i] = 0;
	end

	#(10 * CLK_PERIOD);
	rst_n = 1;

	sdram_initseq();

	$display(">>> Zeroing memory");
	
	@ (negedge clk);
	for (i = 1; i < N_DATA_LINES * N_MASTERS; i = i + 1) begin
		ahbl_wrap4_write(0, i * 16, 0);		
		shadow_mem[i] = 0;
	end

	$display(">>> Starting random read/write");

	fork
		begin: master0
			reg [31:0] tmp_addr;
			reg [127:0] tmp_data;
			for (i = 0; i < TEST_LEN; i = i + 1) begin
				tmp_addr = $random & ((1 << W_ADDR_RANGE) - 1) & 32'hffff_fff0;
				if ($random & 1 << 24) begin
					tmp_data = {$random, $random, $random, $random};
					ahbl_wrap4_write(0, tmp_addr, tmp_data);
					shadow_mem[tmp_addr >> 4] = tmp_data;
				end else begin
					ahbl_wrap4_read(0, tmp_addr, tmp_data);
					if (tmp_data != shadow_mem[tmp_addr >> 4]) begin
						$display("Master 0 mismatch at address %h: expected %h, got %h", tmp_addr, shadow_mem[tmp_addr >> 4], tmp_data);
						$finish;
					end
				end
				while ($random & (3 << 24))
					@ (negedge clk);
			end
		end	
		begin: master1
			reg [31:0] tmp_addr;
			reg [127:0] tmp_data;
			for (i = 0; i < TEST_LEN; i = i + 1) begin
				tmp_addr = ($random & ((1 << W_ADDR_RANGE) - 1) & 32'hffff_fff0) + (1 << W_ADDR_RANGE);
				if ($random & 1 << 24) begin
					tmp_data = {$random, $random, $random, $random};
					ahbl_wrap4_write(1, tmp_addr, tmp_data);
					shadow_mem[tmp_addr >> 4] = tmp_data;
				end else begin
					ahbl_wrap4_read(1, tmp_addr, tmp_data);
					if (tmp_data != shadow_mem[tmp_addr >> 4]) begin
						$display("Master 1 mismatch at address %h: expected %h, got %h", tmp_addr, shadow_mem[tmp_addr >> 4], tmp_data);
						$finish;
					end
				end
				while ($random & (3 << 24))
					@ (negedge clk);
			end
		end
	join

	#(10 * CLK_PERIOD);
	$display("Test PASSED.");
	$finish;
end


endmodule

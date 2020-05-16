`default_nettype none

module tb;

// ----------------------------------------------------------------------------
// DUT

localparam COLUMN_BITS        = 10;
localparam ROW_BITS           = 13;
localparam W_SDRAM_BANKSEL    = 2;
localparam W_SDRAM_ADDR       = 13;
localparam W_SDRAM_DATA       = 16;
localparam N_MASTERS          = 1;
localparam LEN_AHBL_BURST     = 4;
localparam W_HADDR            = 32;
localparam W_HDATA            = 32;

`include "sdram_dut_instantiation.vh"

// ----------------------------------------------------------------------------
// Stimulus

localparam CLK_PERIOD = 10;
always #(0.5 * CLK_PERIOD) clk = !clk;

`include "sdram_task.vh"

integer i;

reg [127:0] wdata;
reg [127:0] rdata;

localparam N_BURSTS = 10;

reg [127:0] data_history [0:N_BURSTS-1];

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

	wdata = 128'h5aa5f00f3cc3e11e_fedcba9876543210;
	@ (negedge clk);
	ahbl_wrap4_write(0, 0, wdata);
	ahbl_wrap4_read(0, 0, rdata);

	@ (negedge clk);
	@ (negedge clk);
	@ (negedge clk);
	@ (negedge clk);

	$display("Smoke test");
	if (rdata != wdata) begin
		$display("Data mismatch");
		$finish;
	end

	$display("Write to read to write, same bank");

	for (i = 0; i < N_BURSTS; i = i + 1) begin
		wdata = {$random, $random, $random, $random};
		ahbl_wrap4_write(0, i * 16, wdata);
		ahbl_wrap4_read(0, i * 16, rdata);
		if (rdata != wdata) begin
			$display("Data mismatch: expected %h, got %h", wdata, rdata);
			$finish;
		end
	end

	@ (negedge clk);
	@ (negedge clk);
	@ (negedge clk);
	@ (negedge clk);

	$display("Write to write, read to read, same bank");

	for (i = 0; i < N_BURSTS; i = i + 1) begin
		wdata = {$random, $random, $random, $random};
		ahbl_wrap4_write(0, i * 16, wdata);
		data_history[i] = wdata;
	end

	for (i = 0; i < N_BURSTS; i = i + 1) begin
		ahbl_wrap4_read(0, i * 16, rdata);
		if (rdata != data_history[i]) begin
			$display("Data mismatch: expected %h, got %h", data_history[i], rdata);
			$finish;
		end
	end

	@ (negedge clk);
	@ (negedge clk);
	@ (negedge clk);
	@ (negedge clk);

	$display("Write to read to write, different banks");

	for (i = 0; i < N_BURSTS; i = i + 1) begin
		wdata = {$random, $random, $random, $random};
		ahbl_wrap4_write(0, i * (32 + (1 << COLUMN_BITS + 1)), wdata);
		ahbl_wrap4_read(0, i * (32 + (1 << COLUMN_BITS + 1)), rdata);
		if (rdata != wdata) begin
			$display("Data mismatch: expected %h, got %h", wdata, rdata);
			$finish;
		end
	end

	@ (negedge clk);
	@ (negedge clk);
	@ (negedge clk);
	@ (negedge clk);

	$display("Write to write, read to read, different banks");

	for (i = 0; i < N_BURSTS; i = i + 1) begin
		wdata = {$random, $random, $random, $random};
		ahbl_wrap4_write(0, i * (32 + (1 << COLUMN_BITS + 1)), wdata);
		data_history[i] = wdata;
	end

	for (i = 0; i < N_BURSTS; i = i + 1) begin
		ahbl_wrap4_read(0, i * (32 + (1 << COLUMN_BITS + 1)), rdata);
		if (rdata != data_history[i]) begin
			$display("Data mismatch: expected %h, got %h", data_history[i], rdata);
			$finish;
		end
	end

	#(10 * CLK_PERIOD);
	$display("Test PASSED.");
	$finish;
end


endmodule

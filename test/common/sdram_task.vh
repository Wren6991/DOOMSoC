task apb_write;
	input [15:0] addr;
	input [31:0] data;
begin
	apbs_paddr <= addr;
	apbs_psel <= 1'b1;
	apbs_pwrite <= 1'b1;
	apbs_pwdata <= data;
	@ (posedge clk);
	apbs_penable <= 1'b1;
	@ (posedge clk);
	apbs_psel <= 1'b0;
	apbs_penable <= 1'b0;
	apbs_pwrite <= 1'b0;
end
endtask

localparam CTLREG_CSR = 0;
localparam CTLREG_TIME = 4;
localparam CTLREG_REFRESH = 8;
localparam CTLREG_CMD_DIRECT = 12;

task sdram_initseq;
begin
	#(10 * CLK_PERIOD);
	@ (posedge clk);

	apb_write(CTLREG_CSR, 2); // set CSR.PU
	@ (posedge clk);
	@ (posedge clk);
	apb_write(CTLREG_CMD_DIRECT, 32'h0000_2002); // PrechargeAll
	#60;
	@ (posedge clk);
	for (i = 0; i < 3; i = i + 1) begin
		apb_write(CTLREG_CMD_DIRECT, 32'h0000_0001); // AutoRefresh
		#60;
		@ (posedge clk);
	end
	//                               /---------------------- Write burst mode
	//                               |  /------------------- Reserved
	//                               |  |   /--------------- CAS latency 3
	//                               |  |   | /------------- Sequential (wrapped) bursts
	//                               |  |   | |   /--------- 8 beat bursts
	apb_write(CTLREG_CMD_DIRECT, 13'b0_00_010_0_011 << 3); // ModeRegisterSet

    // Timings below are for MT48LC32M16A2 @ 100 MHz
	//                          /------------------------------- tCAS - 1    2 clk
	//                          |    /-------------------------- tWR - 1     15 ns 2 clk
	//                          |    |    /--------------------- tRAS - 1    44 ns 5 clk
	//                          |    |    |    /---------------- tRRD - 1    15 ns 2 clk
	//                          |    |    |    |    /----------- tRP - 1     20 ns 2 clk
	//                          |    |    |    |    |    /------ tRCD - 1    20 ns 2 clk
	//                          |    |    |    |    |    |    /- tRC - 1     66 ns 7 clk (also tRFC)
	apb_write(CTLREG_TIME, 32'b01_0001_0100_0001_0001_0001_0110);

	apb_write(CTLREG_REFRESH, 623);

	apb_write(CTLREG_CSR, 3); // set CSR.EN as well as CSR.PU (start issuing refresh commands)
end
endtask


// Must start on a clock negedge with hready high
task automatic ahbl_wrap4_write;
	input integer master;
	input [31:0] addr;
	input [127:0] data;
	integer i;
begin
	ahbls_htrans[master] = 2'b10;
	ahbls_haddr[master]  = addr;
	ahbls_hburst[master] = 2'b010;
	ahbls_hwrite[master] = 1'b1;
	ahbls_hsize[master]  = 3'b010;
	for (i = 0; i < 4; i = i + 1) begin
		while (!ahbls_hready[master])
			@ (negedge clk);
		@ (negedge clk);
		ahbls_haddr[master] = {ahbls_haddr[master][31:4], ahbls_haddr[master][3:0] + 4'h4};
		ahbls_htrans[master] = i == 3 ? 2'b00 : 2'b11;
		ahbls_hwdata[master] = data[31:0];
		data = data >> 32;
	end
end
endtask

task automatic ahbl_wrap4_read;
	input integer master;
	input [31:0] addr;
	output [127:0] data;
	integer i;
begin
	ahbls_htrans[master] = 2'b10;
	ahbls_haddr[master]  = addr;
	ahbls_hburst[master] = 2'b010;
	ahbls_hwrite[master] = 1'b0;
	ahbls_hsize[master]  = 3'b010;
	while (!ahbls_hready[master])
		@ (negedge clk);
	@ (negedge clk);
	for (i = 0; i < 4; i = i + 1) begin
		while (!ahbls_hready[master])
			@ (negedge clk);
		ahbls_haddr[master] = {ahbls_haddr[master][31:4], ahbls_haddr[master][3:0] + 4'h4};
		ahbls_htrans[master] = i == 3 ? 2'b00 : 2'b11;
		data = (data >> 32) | (ahbls_hrdata[master] << 96);
		if (i < 3)
			@ (negedge clk);
	end
end
endtask

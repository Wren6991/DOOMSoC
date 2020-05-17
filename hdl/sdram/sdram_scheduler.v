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

`default_nettype none

// - Tracks bank state
// - Generates AutoRefresh commands at regular intervals
// - Generates SDRAM commands to satisfy read/write burst requests coming in
//   from the system bus
// - Generates enable signals for DQ launch and capture
//
// A bank is either idle or active.
//
// There are a number of counters that inhibit its transition between these
// states (e.g. waiting for tRAS to expire before a RowActivate), or inhibit
// the issue of read/write bursts once it is in the active state (waiting for
// tRCD to expire).
//
// Row precharging may also be inhibited by an imminent or in-progress burst
// on that row.
//
// We can issue up to one command per cycle. Apply a simple priority rule to
// decide what this command is:
// - A refresh is highest priority. It's possible to add leeway to this, but
//   currently an unconvincing performance/complexity trade
// - A read/write burst on an open row
// - A Precharge due to row miss
// - A RowActivate
// - A Precharge due to row cooldown expiry
//
// In case we later add multiple request sources, we would still assess each
// of these stages in the same order, but each stage would consider each
// requestor in their own priority order.

// STRAWMAN 1
//
// Say there are b banks and m masters (including dummy master for row timeout
// precharge). There are 3 operations a master may perform on a bank, in
// descending priority order:
//
// - Burst (on page hit)
// - Precharge (on page miss)
// - Activate (on page empty)
//
// and these form a onehot0 vector for each master.
//
// 1. Form (b * m * 3) 3D mask of requests by decoding master read/write requests
//    against bank states (IDLE/ACTIVE + row address, for each bank) and demuxing
//    based on master bank select
//
// 2. For each bank, OR together all master operation vectors (collapse along
//    master axis), perform priority select, then AND each operation vector for
//    the bank with this mask (this avoids self-sabotage by e.g. precharging a
//    row we will want to burst on once DQs are free)
//
// 3. Use timing constraint counters and DQ schedule to generate a 2D mask of
//    what operations are *possible* for each bank on this cycle, and apply this
//    mask to all masters for each operation/bank combination.
//
// 4. Collapse the request matrix along the bank axis using reduction OR
//
// 5. Reduce the new matrix along the master axis to produce a mask of
//    (desired && possible) operations. Priority-select this, and use it to mask,
//    then crosswise reduce the matrix. We now have a vector of masters who want
//    to perform the highest-priority (desired && possible) operation on this cycle.
//
// 6. Priority select this to choose the winning master, and look back to our
//    bank decode to figure out which command to issue to which bank.
//
// We update the bank states, constraint counters and DQ schedule based on the
// chosen operation. The master request is left unacknowledged for
// Activate/Precharge operations, and acknowledged for Read/Write operations.
//
// Problems with this:
//
// - Holy complexity batman (tho the logic should pack down quite nicely)
//
// - If we precharge on page miss, and then the (higher priority) master who
//   had the page open returns, we will end up reactivating the original row.
//   This thrashes the bank and causes the low priority master to make no
//   progress at all.
//
// - Bursts should preferentially be followed by bursts of the same type to
//   minimise turnaround periods
//
// Second can be fixed by adding a new operation type: Activate (miss), which
// is higher priority than Activate (empty), and asserted by a per-master flag
// we set when precharging. This means we COMMIT to a miss dammit
//
// Another refinement: there is no need to distinguish between Precharge
// (Miss) and Activate (Empty) -- these can be the same bit in the decision
// rule. However, Activate (Miss) should be separate from (and higher priority
// than) Activate (Empty).

module sdram_scheduler #(
	parameter N_REQ          = 4,
	parameter W_REFRESH_CTR  = 12,
	parameter W_COOLDOWN_CTR = 8,
	parameter W_RADDR        = 13,
	parameter W_BANKSEL      = 2,
	parameter W_CADDR        = 10,
	parameter BURST_LEN      = 8,  // We ONLY support fixed size bursts. Not runtime configurable
	                               // because it is a function of busfabric.
	parameter W_TIME_CTR     = 3   // Counter size for SDRAM timing restrictions
) (
	input  wire                       clk,
	input  wire                       rst_n,

	input  wire [W_REFRESH_CTR-1:0]   cfg_refresh_interval,
	input  wire [W_COOLDOWN_CTR-1:0]  cfg_row_cooldown,

	//
	input wire [W_TIME_CTR-1:0]       time_rc,  // tRC: Row cycle time, RowActivate to RowActivate, same bank.
	input wire [W_TIME_CTR-1:0]       time_rcd, // tRCD: RAS to CAS delay.
	input wire [W_TIME_CTR-1:0]       time_rp,  // tRP: Precharge to RowActivate delay (same bank)
	input wire [W_TIME_CTR-1:0]       time_rrd, // tRRD: RowActivate to RowActivate, different banks
	input wire [W_TIME_CTR-1:0]       time_ras, // tRAS: RowActivate to Precharge, same bank
	input wire [W_TIME_CTR-1:0]       time_wr,  // tWR: Write to Precharge, same bank
	input wire [1:0]                  time_cas, // tCAS: CAS-to-data latency

	input  wire [N_REQ-1:0]           req_vld,
	output wire [N_REQ-1:0]           req_rdy,
	input  wire [N_REQ*W_RADDR-1:0]   req_raddr,
	input  wire [N_REQ*W_BANKSEL-1:0] req_banksel,
	input  wire [N_REQ*W_CADDR-1:0]   req_caddr,
	input  wire [N_REQ-1:0]           req_write,

	output wire                       cmd_vld,
	output wire                       cmd_ras_n,
	output wire                       cmd_cas_n,
	output wire                       cmd_we_n,
	output wire [W_RADDR-1:0]         cmd_addr,
	output wire [W_BANKSEL-1:0]       cmd_banksel,

	output wire [N_REQ-1:0]           dq_write,
	output wire [N_REQ-1:0]           dq_read
);

localparam N_BANKS = 1 << W_BANKSEL;

// ras_n, cas_n, we_n
localparam CMD_REFRESH   = 3'b001;
localparam CMD_PRECHARGE = 3'b010;
localparam CMD_ACTIVATE  = 3'b011;
localparam CMD_WRITE     = 3'b100;
localparam CMD_READ      = 3'b101;

// ----------------------------------------------------------------------------
// Timing constraint scoreboard

reg [W_TIME_CTR-1:0] ctr_ras_to_ras_same [0:N_BANKS-1]; // tRC
reg [W_TIME_CTR-1:0] ctr_ras_to_cas      [0:N_BANKS-1]; // tRCD
reg [W_TIME_CTR-1:0] ctr_pre_to_ras      [0:N_BANKS-1]; // tRP
reg [W_TIME_CTR-1:0] ctr_ras_to_ras_any;                // tRRD, global across all banks
reg [W_TIME_CTR-1:0] ctr_ras_to_pre      [0:N_BANKS-1]; // tRAS
reg [3:0]            ctr_cas_to_pre      [0:N_BANKS-1]; // tWR, and blocking precharge during read bursts

wire precharge_is_all = cmd_addr[10];

wire [2:0] cmd = {cmd_ras_n, cmd_cas_n, cmd_we_n};

always @ (posedge clk or negedge rst_n) begin: timing_scoreboard_update
	integer i;
	if (!rst_n) begin
		for (i = 0; i < N_BANKS; i = i + 1) begin
			ctr_ras_to_ras_same[i] <= {W_TIME_CTR{1'b0}};
			ctr_ras_to_cas     [i] <= {W_TIME_CTR{1'b0}};
			ctr_pre_to_ras     [i] <= {W_TIME_CTR{1'b0}};
			ctr_ras_to_pre     [i] <= {W_TIME_CTR{1'b0}};
			ctr_cas_to_pre     [i] <= {W_TIME_CTR{1'b0}};
		end
		ctr_ras_to_ras_any <= {W_TIME_CTR{1'b0}};
	end else begin
		// By default, saturating down count
		for (i = 0; i < N_BANKS; i = i + 1) begin
			ctr_ras_to_ras_same[i] <= ctr_ras_to_ras_same[i] - |ctr_ras_to_ras_same[i];
			ctr_ras_to_cas[i] <= ctr_ras_to_cas[i] - |ctr_ras_to_cas[i];
			ctr_pre_to_ras[i] <= ctr_pre_to_ras[i] - |ctr_pre_to_ras[i];
			ctr_ras_to_pre[i] <= ctr_ras_to_pre[i] - |ctr_ras_to_pre[i];
			ctr_cas_to_pre[i] <= ctr_cas_to_pre[i] - |ctr_cas_to_pre[i];
		end
		ctr_ras_to_ras_any <= ctr_ras_to_ras_any - |ctr_ras_to_ras_any;

		// Reload each counter with user-supplied value if a relevant command is
		// issued (note that the given values are expressed as cycles - 1)
		if (cmd_vld) begin
			for (i = 0; i < N_BANKS; i = i + 1) begin
				if (cmd == CMD_ACTIVATE && cmd_banksel == i || cmd == CMD_REFRESH) begin
					ctr_ras_to_ras_same[i] <= time_rc;
					ctr_ras_to_cas[i] <= time_rcd;
					ctr_ras_to_pre[i] <= time_ras;
				end
				if (cmd == CMD_PRECHARGE && (precharge_is_all || cmd_banksel == i)) begin
					ctr_pre_to_ras[i] <= time_rp;
				end
				if (cmd == CMD_WRITE && cmd_banksel == i) begin
					ctr_cas_to_pre[i] <= BURST_LEN - 1 + time_wr;
				end else if (cmd == CMD_READ && cmd_banksel == i) begin
					ctr_cas_to_pre[i] <= BURST_LEN - 1;
				end
			end
			if (cmd == CMD_ACTIVATE) begin
				ctr_ras_to_ras_any <= time_rrd;
			end
		end
	end
end

// ----------------------------------------------------------------------------
// Bank state scoreboard

reg [N_BANKS-1:0] bank_active;
reg [W_RADDR-1:0] bank_active_row [0:N_BANKS-1];

always @ (posedge clk or negedge rst_n) begin: bank_scoreboard_update
	integer i;
	if (!rst_n) begin
		for (i = 0; i < N_BANKS; i = i + 1) begin
			bank_active_row[i] <= {W_RADDR{1'b0}};
			bank_active[i] <= 1'b0;
		end
	end else if (cmd_vld) begin
		for (i = 0; i < N_BANKS; i = i + 1) begin
			if (cmd == CMD_PRECHARGE && (precharge_is_all || cmd_banksel == i)) begin
				bank_active[i] <= 1'b0;
			end else if (cmd == CMD_ACTIVATE && cmd_banksel == i) begin
				bank_active[i] <= 1'b1;
				bank_active_row[i] <= cmd_addr;
			end
		end
	end
end

// ----------------------------------------------------------------------------
// DQ scoreboard

// We maintain a shift register of what operation the DQs are performing for n
// cycles into the future (read for some master, write for some master, or
// no operation) and also 1 cycle into the past so we can check turnarounds.
//
// We schedule the DQs in time with our issue of addresses and commands. The
// actual read timing may need to be adjusted later to match the delay of the
// launch and capture registers, but this is someone else's problem.


// burst len + max CAS + 1 extra for previous cycle
localparam DQ_SCHEDULE_LEN = BURST_LEN + 4 + 1;
// Record is: valid, read_nwrite, master ID
parameter W_REQSEL = $clog2(N_REQ);
localparam W_DQ_RECORD = 2 + W_REQSEL;

wire [W_DQ_RECORD-1:0] write_record;
wire [W_DQ_RECORD-1:0] read_record;

// Avoid 0-width signal when encoding master ID
generate
if (N_REQ == 1) begin: small_record
	assign write_record = 2'b10;
	assign read_record = 2'b11;
end else begin: big_record
	wire [W_REQSEL-1:0] reqsel;
	onehot_encoder #(
		.W_INPUT (N_REQ)
	) req_encode (
		.in  (highest_master_with_highest_op),
		.out (reqsel)
	);
	assign write_record = {2'b10, reqsel};
	assign read_record = {2'b11, reqsel};
end
endgenerate


wire [DQ_SCHEDULE_LEN-1:0] write_cycle_mask = {{DQ_SCHEDULE_LEN-BURST_LEN{1'b0}}, {BURST_LEN{1'b1}}};
wire [DQ_SCHEDULE_LEN-1:0] read_cycle_mask =  {{DQ_SCHEDULE_LEN-BURST_LEN-1{1'b0}}, {BURST_LEN{1'b1}}, 1'b0} << time_cas;

reg [W_DQ_RECORD-1:0] dq_schedule [0:DQ_SCHEDULE_LEN-1];

wire write_cmd_issued = cmd_vld && cmd == CMD_WRITE;
wire read_cmd_issued = cmd_vld && cmd == CMD_READ;

always @ (posedge clk or negedge rst_n) begin: dq_schedule_update
	integer i;
	if (!rst_n) begin
		for (i = 0; i < DQ_SCHEDULE_LEN; i = i + 1) begin
			dq_schedule[i] <= {W_DQ_RECORD{1'b0}};
		end
	end else begin
		for (i = 0; i < DQ_SCHEDULE_LEN; i = i + 1) begin
			dq_schedule[i] <= (i < DQ_SCHEDULE_LEN - 1 ? dq_schedule[i + 1] : {W_DQ_RECORD{1'b0}})
				| write_record & {W_DQ_RECORD{write_cmd_issued && write_cycle_mask[i]}}
				| read_record & {W_DQ_RECORD{read_cmd_issued && read_cycle_mask[i]}};
		end
	end
end

// Can issue write if DQs are free for the next BURST_LEN cycles (including
// this cycle), and there was no read on the previous cycle.
reg can_issue_write;
always @ (*) begin: check_can_issue_write
	integer i;
	can_issue_write = 1'b1;
	for (i = 1; i < BURST_LEN + 1; i = i + 1) begin
		can_issue_write = can_issue_write && !dq_schedule[i][W_DQ_RECORD-1];
	end
	can_issue_write = can_issue_write && dq_schedule[0][W_DQ_RECORD-1:W_DQ_RECORD-2] != 2'b11;
end

// Can issue read if DQs are free from tCAS to tCAS + BURST_LEN - 1, and there
// was no write on tCAS - 1. (turnaround/contention)
//
// Additionally make sure that there is no *write* cycle specifcally on the
// current cycle, as issuing a Read at any point during a Write burst seems to
// terminate the Write (not clear from documentation but this is how the
// MT48LC32M16 vendor model behaves)
reg can_issue_read;
always @ (*) begin: check_can_issue_read
	integer i;
	can_issue_read = 1'b1;
	for (i = 0; i < DQ_SCHEDULE_LEN; i = i + 1) begin
		can_issue_read = can_issue_read && !(read_cycle_mask[i] && dq_schedule[i][W_DQ_RECORD-1]);
	end	
	can_issue_read = can_issue_read && dq_schedule[time_cas][W_DQ_RECORD-1:W_DQ_RECORD-2] != 2'b10;
	can_issue_read = can_issue_read && dq_schedule[1][W_DQ_RECORD-1:W_DQ_RECORD-2] != 2'b10;
end

// ----------------------------------------------------------------------------
// Decision rules

// This is what we are trying to figure out:
wire [N_REQ-1:0] highest_master_with_highest_op;

// Remember if a master caused a Precharge on page miss, so we follow up with
// an Activate from the *same* master in preference to others on that bank.
reg [N_REQ-1:0] master_has_precharged;
wire [N_REQ-1:0] master_precharge = highest_master_with_highest_op & {N_REQ{cmd_vld && cmd == CMD_PRECHARGE}};
wire [N_REQ-1:0] master_activate = highest_master_with_highest_op & {N_REQ{cmd_vld && cmd == CMD_ACTIVATE}};

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		master_has_precharged <= {N_REQ{1'b0}};
	end else begin
		master_has_precharged <= (master_has_precharged | master_precharge) & ~master_activate;
	end
end

localparam N_OPS = 3;
// Group operations into 3 classes. These are in descending priority order: if
// a class is desired for any given bank, any lesser operation class will *not* be
// considered. The classes are:
//
// 0. Read/write burst (page hit)
// 1. Activate following page miss
// 2. Precharge on page miss, or Activate on page empty

// Form a matrix of things we *want* to do on this cycle, based on master
// requests and bank state

reg [N_OPS-1:0] desired [0:N_BANKS-1] [0:N_REQ-1];

always @ (*) begin: decode_desired
	integer bank, master;
	for (bank = 0; bank < N_BANKS; bank = bank + 1) begin
		for (master = 0; master < N_REQ; master = master + 1) begin
			desired[bank][master] = {
				// 2. Precharge on page miss, or Activate on page empty
				req_vld[master] && (bank_active[bank] ? bank_active_row[bank] != req_raddr[master * W_RADDR +: W_RADDR] : 1'b1),
				// 1. Activate following page miss
				master_has_precharged[master],
				// 0. Read/write burst
				req_vld[master] && bank_active[bank] && bank_active_row[bank] == req_raddr[master * W_RADDR +: W_RADDR]
			} & {N_OPS{req_banksel[master * W_BANKSEL +: W_BANKSEL] == bank}};
		end
	end
end

// Form a matrix of operations which are *possible* for each bank, based on
// bank state and timing constraints

reg [N_OPS-1:0] bank_possible [0:N_BANKS-1];

always @ (*) begin: decode_bank_possible
	integer bank;
	for (bank = 0; bank < N_BANKS; bank = bank + 1) begin
		bank_possible[bank] = {
			// 2. Precharge must respect tRAS, tWR. Activate must respect tRC, tRP, tRRD
			bank_active[bank] ?
				~|{ctr_ras_to_pre[bank], ctr_cas_to_pre[bank]}:
				~|{ctr_ras_to_ras_any, ctr_ras_to_ras_same[bank], ctr_pre_to_ras[bank]},
			// 1. Activate must respect tRC, tRP, tRRD
			~|{ctr_ras_to_ras_any, ctr_ras_to_ras_same[bank], ctr_pre_to_ras[bank]},
			// 0. Bursts must respect tRCD. Must also respect bus turnaround and
			// contention, but that is not bank-specific.
			~|ctr_ras_to_cas[bank]
		};
	end
end

// Filter based on bank possibilities and bus state to find which ops are
// desired AND possible for each master

reg [N_OPS-1:0] desired_and_possible [0:N_REQ-1];

always @ (*) begin: filter_desired
	integer bank, master;
	for (master = 0; master < N_REQ; master = master + 1) begin
		desired_and_possible[master] = {N_OPS{1'b0}};
		for (bank = 0; bank < N_BANKS; bank = bank + 1) begin
			desired_and_possible[master] = desired_and_possible[master] | (
				desired[bank][master] & bank_possible[bank]
			);
		end
		// Apply bus contention and turnaround constraints
		desired_and_possible[master] = desired_and_possible[master] & {2'b11,
			req_write[master] ? can_issue_write : can_issue_read
		};
	end
end

// Find the highest-tiered operation class which *some* master wishes to perform

reg [N_OPS-1:0] op_has_active_master;
wire [N_OPS-1:0] highest_active_op;

always @ (*) begin: find_active_ops
	integer i;
	op_has_active_master = {N_OPS{1'b0}};
	for (i = 0; i < N_REQ; i = i + 1) begin
		op_has_active_master = op_has_active_master | desired_and_possible[i];
	end
end

onehot_priority #(
	.W_INPUT (N_OPS)
) highest_op_sel (
	.in  (op_has_active_master),
	.out (highest_active_op)
);

// Find the highest-priority master requesting this op

reg [N_REQ-1:0] masters_with_highest_op;

always @ (*) begin: find_masters_with_highest_op
	integer i;
	for (i = 0; i < N_REQ; i = i + 1) begin
		masters_with_highest_op[i] = |(desired_and_possible[i] & highest_active_op);
	end
end

onehot_priority #(
	.W_INPUT (N_REQ)
) highest_master_sel (
	.in  (masters_with_highest_op),
	.out (highest_master_with_highest_op)
);

// ----------------------------------------------------------------------------
// Command generation

wire [W_RADDR-1:0]   muxed_raddr;
wire [W_BANKSEL-1:0] muxed_banksel;
wire [W_CADDR-1:0]   muxed_caddr;
wire                 muxed_write;

onehot_mux #(
	.N_INPUTS (N_REQ),
	.W_INPUT  (W_RADDR)
) raddr_mux (
	.in  (req_raddr),
	.sel (highest_master_with_highest_op),
	.out (muxed_raddr)
);

onehot_mux #(
	.N_INPUTS (N_REQ),
	.W_INPUT  (W_BANKSEL)
) banksel_mux (
	.in  (req_banksel),
	.sel (highest_master_with_highest_op),
	.out (muxed_banksel)
);

onehot_mux #(
	.N_INPUTS (N_REQ),
	.W_INPUT  (W_CADDR)
) caddr_mux (
	.in  (req_caddr),
	.sel (highest_master_with_highest_op),
	.out (muxed_caddr)
);

onehot_mux #(
	.N_INPUTS (N_REQ),
	.W_INPUT  (1)
) write_mux (
	.in  (req_write),
	.sel (highest_master_with_highest_op),
	.out (muxed_write)
);

assign cmd_vld = |highest_master_with_highest_op;
assign {cmd_ras_n, cmd_cas_n, cmd_we_n} =
	!bank_active[muxed_banksel]                   ? CMD_ACTIVATE  :
	bank_active_row[muxed_banksel] != muxed_raddr ? CMD_PRECHARGE :
	muxed_write                                   ? CMD_WRITE     : CMD_READ;

assign cmd_addr = bank_active[muxed_banksel] ? muxed_caddr : muxed_raddr;
assign cmd_banksel = muxed_banksel;

assign req_rdy = highest_master_with_highest_op & {N_REQ{cmd == CMD_WRITE || cmd == CMD_READ}};

// Onehot0 read/write data strobes to control bus interface
wire [N_REQ-1:0] dq_master_sel;

generate
if (N_REQ == 1) begin: one_master_sel
	assign dq_master_sel = 1'b1;
end else begin: n_master_sel
	assign dq_master_sel = {{N_REQ-1{1'b0}}, 1'b1} << dq_schedule[1][W_REQSEL-1:0];
end
endgenerate

wire [1:0] scheduled_dq_op = dq_schedule[1][W_DQ_RECORD-1:W_DQ_RECORD-2];

assign dq_write = cmd_vld && cmd == CMD_WRITE ? highest_master_with_highest_op :
	dq_master_sel & {N_REQ{scheduled_dq_op == 2'b10}};

assign dq_read = dq_master_sel & {N_REQ{scheduled_dq_op == 2'b11}};


endmodule

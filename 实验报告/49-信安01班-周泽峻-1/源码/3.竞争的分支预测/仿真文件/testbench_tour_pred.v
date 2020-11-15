`timescale 1ns / 1ps

module testbench_tour_pred();
	reg clk;
	reg rst;

	wire [31:0] instr, pc, resultW;
	wire [4:0] rs, rt, rd;
	wire [31:0] writedata,dataadr;
	wire pred_takeD, pred_takeM;
	wire pred_takeD_loc, pred_takeD_glo;
	wire pred_wrongM;
	wire [31:0] pcPlus4M;
	wire [31:0] r2, r4, r5, r7;
	wire [31:0] pcBranchE, pcBranchM;
	wire jumpD;
	wire branchM;
	wire memwrite;
	wire stallF, stallD, flushD, flushE, flushM;

	top_tour_pred dut(
		.clk(clk),
		.rst(rst),
		.instr(instr),
		.pc(pc),
		.resultW(resultW),
		.rs(rs),
		.rt(rt),
		.rd(rd),
		.writedata(writedata),
		.dataadr(dataadr),
		.memwrite(memwrite),
		.stallF(stallF),
		.stallD(stallD),
		.flushD(flushD),
		.flushE(flushE),
		.flushM(flushM),
		.pcPlus4M(pcPlus4M),
		.pred_takeD(pred_takeD),
		.pred_takeM(pred_takeM),
		.pred_takeD_loc(pred_takeD_loc),
		.pred_takeD_glo(pred_takeD_glo),
		.pred_wrongM(pred_wrongM),
		.pcBranchE(pcBranchE),
		.pcBranchM(pcBranchM),
		.branchM(branchM),
		.r2(r2),
		.r4(r4),
		.r5(r5),
		.r7(r7),
		.jumpD(jumpD)
	);

	initial begin 
		rst <= 1;
		#200;
		rst <= 0;
	end

	always begin
		clk <= 1;
		#10;
		clk <= 0;
		#10;
	
	end

	always @(negedge clk) begin
		if(memwrite) begin
			/* code */
			if(dataadr === 84 & writedata === 7) begin
				/* code */
				$display("Simulation succeeded");
				$stop;
			end else if(dataadr !== 80) begin
				/* code */
				$display("Simulation Failed");
				$stop;
			end
		end
	end
endmodule

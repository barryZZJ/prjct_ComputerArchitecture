`timescale 1ns / 1ps

module testbench_tour_pred();
	reg clk;
	reg rst;

	wire [31:0] instr, pc, resultW;
	wire [4:0] rs, rt, rd;
	wire [31:0] writedata,dataadr;
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
		.flushM(flushM)
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

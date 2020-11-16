`timescale 1ns / 1ps

module mips_local_pred(
	input wire clk,rst,
	input wire[31:0] instr,
	input wire[31:0] readdata,

	output wire memwriteM,
	output wire[31:0] pc, resultW,
	output wire[31:0] aluoutM, writedata,
	output [4:0] rs, rt, rd,
	output stallF, stallD, flushD, flushE, flushM
);

// Decode phase
wire [31:0] instrD;
wire regwriteD, memtoregD, memwriteD, branchD, alusrcD, regdstD, jumpD, pcsrcD;
wire [2:0] alucontrolD;

// Execution phase
wire regwriteE, memtoregE, memwriteE, alusrcE, regdstE;
wire [2:0] alucontrolE;

// Mem phase
wire regwriteM, memtoregM; 
//memwriteM;

// WB phase
wire regwriteW, memtoregW;

// hazard
// wire stallF, stallD, flushE;

assign rs = instrD[25:21];
assign rt = instrD[20:16];
assign rd = instrD[15:11];

// fetch to decode flop for instr
flopenrc #(32) FD_instr (
    .clk(clk),
    .rst(rst),
    .en(~stallD),
	.clear(flushD),
    .d(instr),
    .q(instrD)
);

// Decode to Exe flop for signals
floprc #(8) DE_signals (
    .clk(clk),
    .rst(rst),
    .clear(flushE),
    .d({regwriteD, memtoregD, memwriteD, alucontrolD, alusrcD, regdstD}),
    .q({regwriteE, memtoregE, memwriteE, alucontrolE, alusrcE, regdstE})
);

// exe to Mem flop for signals
flopenr #(3) EM_signals (
    .clk(clk),
    .rst(rst),
    .en(1'b1),
    .d({regwriteE, memtoregE, memwriteE}),
    .q({regwriteM, memtoregM, memwriteM})
);

// mem to wb flop for signals
flopenr #(2) MW_signals (
    .clk(clk),
    .rst(rst),
    .en(1'b1),
    .d({regwriteM, memtoregM}),
    .q({regwriteW, memtoregW})
);

controller c(
	.op(instrD[31:26]),
	.funct(instrD[5:0]),

	.memtoregD(memtoregD),
	.memwriteD(memwriteD),
	.alusrcD(alusrcD),
	.regdstD(regdstD),
	.regwriteD(regwriteD),
	.branchD(branchD),
	.jumpD(jumpD),
	.alucontrolD(alucontrolD)
);

datapath_local_pred dpl(
	.clk(clk),
	.rst(rst),
	.instrD(instrD),
	.readdata(readdata),
	.regwriteE(regwriteE),
	.regwriteM(regwriteM),
	.regwriteW(regwriteW),
	.memtoregW(memtoregW),
	.memtoregE(memtoregE),
	.memtoregM(memtoregM),
	.alucontrolE(alucontrolE),
	.alusrcE(alusrcE),
	.regdstE(regdstE),
	.jumpD(jumpD),
	.branchD(branchD),

	.pc(pc),
	.aluoutM(aluoutM),
	.mem_WriteData(writedata),
	.resultW(resultW),
	.stallF(stallF),
	.stallD(stallD),
	.flushD(flushD),
	.flushE(flushE),
	.flushM(flushM)
);

	
endmodule

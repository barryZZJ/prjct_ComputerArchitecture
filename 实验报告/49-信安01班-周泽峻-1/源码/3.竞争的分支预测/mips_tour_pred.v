`timescale 1ns / 1ps

module mips_tour_pred(
	input wire clk,rst,
	input wire[31:0] instr,
	input wire[31:0] readdata,

	output wire memwriteM,
	output wire[31:0] pc, resultW,
	output wire[31:0] aluoutM, writedata,
	output [4:0] rs, rt, rd,
	output stallF, stallD, flushD, flushE, flushM,
	//! for debug
    output wire [31:0] pcPlus4M,
	output [31:0] pcBranchE,
	output [31:0] pcBranchM,
	output branchM,
    output wire pred_takeD, pred_takeM,
	output wire pred_takeD_loc,
    output wire pred_takeD_glo,
    output wire pred_wrongM,
	output wire[31:0] r2,
	output wire[31:0] r4,
	output wire[31:0] r5,
	output wire[31:0] r7,
	output jumpD
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

datapath_tour_pred dpt(
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
    .r7(r7)
);

	
endmodule

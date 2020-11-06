`timescale 1ns / 1ps


module datapath_global_pred(
    input clk,rst,
    input [31:0]instrD, readdata, // 数据存储器读出的数据
    input regwriteE,
    input regwriteM,
    input regwriteW,
    input memtoregW,
    input memtoregE,
    input memtoregM,
    input [2:0]alucontrolE,
    input alusrcE,
    input regdstE,
    input jumpD,
    input branchD,
    
    output wire [31:0] pc, aluoutM, mem_WriteData, resultW,
    output wire stallF, stallD, flushD, flushE, flushM,
	//! for debug
    output wire pred_takeD, pred_takeM,
    output wire pred_wrongM,
    output wire [31:0] pcPlus4M,
	output wire [31:0] pcBranchE,
    output wire [31:0] pcBranchM,
    output wire branchM,
	output wire[31:0] r2,
	output wire[31:0] r4,
	output wire[31:0] r5,
	output wire[31:0] r7
);


// pc_branched: 多路选择分支之后的pc,用来跟jump地址再选一次; pc_realnext: 下一条真正要执行的指令的pc
wire [31:0] pc_branched, pc_realnext;

//ALU数据来源A、B; 寄存器堆写入数据，sl2_imm: signImmD<<2; sl2_j_addr: jump指令参数左移2位; jump_addr: 实际跳转地址。
wire [31:0] ALUsrcA, ALUsrcB1, ALUsrcB2, sl2_imm, sl2_j_addr, jump_addr;
    // resultW, 

// Fetch phase
wire [31:0] pcF, pcPlus4F;

// Decode phase
// pc_4: pcPlus4; extend_imm: {16'b0, instr[15:0]}
// pcBranchD: signImmD << 2 + pcPlus4D
wire [31:0] pcPlus4D, pcBranchD, rd1D, rd2D, signImmD;
wire [ 4:0] rsD, rtD, rdD;

// Execute phase
wire [31:0] pcPlus4E, pcBranchE, rd1E, rd2E, signImmE, aluoutE, writedataE;
wire [ 4:0] rsE, rtE, rdE, writeregE; // 写入寄存器堆的地址
// zeroE: alu output,
wire branchE, zeroE, actual_takeE;

// Mem phase 
wire [31:0] pcPlus4M, pcBranchM, writedataM;
    // aluoutM;
wire [ 4:0] writeregM;
// actual_takeM = branchE && zeroE
wire branchM, zeroM, actual_takeM;
 
// WB phase 
wire [31:0] aluoutW, readdataW;
wire [ 4:0] writeregW;

// hazard
wire [1:0] forwardAE, forwardBE;

// branch prediction
wire pred_takeD, pred_wrongM;
wire pred_takeM; // 记录上次预测的结果

// ----------------------------------------
// Fetch 

// PC指向选择
// pc_branched: 用来跟jump地址再选一次

assign pc_branched = {pred_wrongM, pred_takeD} == 2'b00 ? pcPlus4F :
                     {pred_wrongM, pred_takeD} == 2'b01 ? pcBranchD : 
                     {pred_wrongM, pred_takeM} == 2'b10 ? pcBranchM : 
                     pcPlus4M;

//mux, 选择分支之后的pc与jump_addr
mux2 #(32) mux_pcnext(
	.a(jump_addr),
	.b(pc_branched),
	.s(jumpD),
	.y(pc_realnext)
);

//pc
flopenr #(32) pc_module(
	.clk(clk),
	.rst(rst),
    .en(~stallF),
    .d(pc_realnext),
    .q(pc)
);

assign pcF = pc;

//PC+4加法器
adder pc_4_adder (
    .a(pcF),
    .b(32'h4),
    .y(pcPlus4F)
);

// ----------------------------------------
// fetech to decode memory flops 

// pc_4
flopenrc #(32) FD_pc_4 (
    .clk(clk),
    .rst(rst),
    .en(~stallD),
    .clear(flushD),
    .d(pcPlus4F),
    .q(pcPlus4D)
);

// ----------------------------------------
// Decode 

//jump指令的左移2位
sl2 sl2_2(
    .a({6'b0, instrD[25:0]}),
    .y(sl2_j_addr)
);

assign jump_addr = {pcPlus4D[31:28], sl2_j_addr[27:0]};

assign rsD = instrD[25:21];
assign rtD = instrD[20:16];
assign rdD = instrD[15:11];

//寄存器堆
regfile regfile(
	.clk(~clk),
	.rst(rst),
	.we3(regwriteW),
	.ra1(instrD[25:21]),
	.ra2(instrD[20:16]),
	.wa3(writeregW),
	.wd3(resultW),

	.rd1(rd1D),
	.rd2(rd2D),
    .r2(r2),
    .r4(r4),
    .r5(r5),
    .r7(r7)
);

//符号拓展
signext sign_extend(
    .a(instrD[15:0]),
    .y(signImmD)
);

//立即数的左移2位
sl2 sl2_1(
    .a(signImmD),
    .y(sl2_imm)
);

//pcBranchD = sl2_imm(signImmD << 2) + pcPlus4D
adder pcbranch_adder (
    .a(sl2_imm),
    .b(pcPlus4D),
    .y(pcBranchD)
);

// ----------------------------------------
// decode to execution flops

// rd1
floprc #(32) DE_rd1 (
    .clk(clk),
    .rst(rst),
    .clear(flushE),
    .d(rd1D),
    .q(rd1E)
);

// rd2
floprc #(32) DE_rd2 (
    .clk(clk),
    .rst(rst),
    .clear(flushE),
    .d(rd2D),
    .q(rd2E)
);

// rs, rt, rd
floprc #(15) DE_rt_rd (
    .clk(clk),
    .rst(rst),
    .clear(flushE),
    .d({rsD, rtD, rdD}),
    .q({rsE, rtE, rdE})
);

// extend_imm
floprc #(32) DE_imm (
    .clk(clk),
    .rst(rst),
    .clear(flushE),
    .d(signImmD),
    .q(signImmE)
);

// 传递branch信号
floprc #(1) DE_branch (
    .clk(clk),
    .rst(rst),
    .clear(flushE),
    .d(branchD),
    .q(branchE)
);

// 传递pcbranch
floprc #(32) DE_pcbranch (
    .clk(clk),
    .rst(rst),
    .clear(flushE),
    .d(pcBranchD),
    .q(pcBranchE)
);

// pc_4
floprc #(32) DE_pc_4 (
    .clk(clk),
    .rst(rst),
    .clear(flushE),
    .d(pcPlus4D),
    .q(pcPlus4E)
);

// 传递pred_take信号
floprc #(1) DE_pred_take (
    .clk(clk),
    .rst(rst),
    .clear(flushE),
    .d(pred_takeD),
    .q(pred_takeE)
);

// ----------------------------------------
// Exe 

// ALU,A端输入值，rd1E(00),resultW(01)，aluoutM(10)
mux3 #(32) mux_ALUAsrc(
    .a(rd1E),
    .b(resultW),
    .c(aluoutM),
    .s(forwardAE),
    .y(ALUsrcA)
);
// ALU, B端输入值，rd1E(00),resultW(01)，aluoutM(10)
mux3 #(32) mux_ALUBsrc1(
    .a(rd2E),
    .b(resultW),
    .c(aluoutM),
    .s(forwardBE),
    .y(ALUsrcB1)
);

mux2 #(32) mux_ALUBsrc2(
    .a(signImmE),
    .b(ALUsrcB1),
    .s(alusrcE),
    .y(ALUsrcB2) // B输入第二个选择器之后的结果
);

//ALU
alu alu(
    .a(ALUsrcA),
    .b(ALUsrcB2),
    .op(alucontrolE),
    
    .res(aluoutE),
    .zero(zeroE)
);

assign actual_takeE = branchE && zeroE;

assign writedataE = ALUsrcB1; // B输入第一个选择器之后的结果

// 寄存器堆写入地址 writereg

mux2 #(5) mux_WA3(
	.a(rdE), //instr[15:11]
	.b(rtE), //instr[20:16]
	.s(regdstE),
	.y(writeregE)
); 

// ----------------------------------------
// execution to Mem flops

// aluout
flopenrc #(32) EM_aluout (
    .clk(clk),
    .rst(rst),
    .en(1'b1),
    .clear(flushM),
    .d(aluoutE),
    .q(aluoutM)
);

// writedata
flopenrc #(32) EM_writedata (
    .clk(clk),
    .rst(rst),
    .en(1'b1),
    .clear(flushM),
    .d(writedataE),
    .q(writedataM)
);

// writereg
flopenrc #(5) EM_writereg (
    .clk(clk),
    .rst(rst),
    .en(1'b1),
    .clear(flushM),
    .d(writeregE),
    .q(writeregM)
);

// branch
flopenrc #(1) EM_branch (
    .clk(clk),
    .rst(rst),
    .en(1'b1),
    .clear(flushM),
    .d(branchE),
    .q(branchM)
);

// zero
flopenrc #(1) EM_zero (
    .clk(clk),
    .rst(rst),
    .en(1'b1),
    .clear(flushM),
    .d(zeroE),
    .q(zeroM)
);

// pcbranch
flopenrc #(32) EM_pcbranch (
    .clk(clk),
    .rst(rst),
    .en(1'b1),
    .clear(flushM),
    .d(pcBranchE),
    .q(pcBranchM)
);

// pc_4
flopenrc #(32) EM_pc_4 (
    .clk(clk),
    .rst(rst),
    .en(1'b1),
    .clear(flushM),
    .d(pcPlus4E),
    .q(pcPlus4M)
);

// 传递pred_take信号
flopenrc #(1) EM_pred_take (
    .clk(clk),
    .rst(rst),
    .en(1'b1),
    .clear(flushM),
    .d(pred_takeE),
    .q(pred_takeM)
);

// ----------------------------------------
// Mem 
assign actual_takeM = branchM && zeroM;

assign mem_WriteData = writedataM;

// ----------------------------------------
// Mem to wb flops

// aluout
flopenr #(32) MF_aluout (
    .clk(clk),
    .rst(rst),
    .en(1'b1),
    .d(aluoutM),
    .q(aluoutW)
);

// readdata from data memory
flopenr #(32) MF_readdata (
    .clk(clk),
    .rst(rst),
    .en(1'b1),
    .d(readdata),
    .q(readdataW)
);

// writereg
flopenr #(5) MW_writereg (
    .clk(clk),
    .rst(rst),
    .en(1'b1),
    .d(writeregM),
    .q(writeregW)
);

// ----------------------------------------
// Write Back 

//mux, 寄存器堆写入数据来自存储器 or ALU ，memtoReg
mux2 #(32) mux_WD3(
	.a(readdataW),//来自数据存储器
	.b(aluoutW),//来自ALU计算结果
	.s(memtoregW),
	.y(resultW)
);

// ----------------------------------------
// hazard

hazard hazard(
    .rsD(rsD),
    .rtD(rtD),
    .rsE(rsE),
    .rtE(rtE),
    .writeregE(writeregE),
    .writeregM(writeregM),
    .writeregW(writeregW),
    .regwriteE(regwriteE),
    .regwriteM(regwriteM),
    .regwriteW(regwriteW),
    .memtoregE(memtoregE),
    .memtoregM(memtoregM),
    .pred_wrongM(pred_wrongM),
    
    .forwardAE(forwardAE),
    .forwardBE(forwardBE),
    .stallF(stallF),
    .stallD(stallD),
    .flushD(flushD),
    .flushE(flushE),
    .flushM(flushM)
);

// --------------------------------
// 基于局部历史预测的分支预测模块
branch_predict_global bpg(
	.clk(clk),
	.rst(rst),
	.flushD(flushD),
	.stallD(stallD),
	.flushE(flushE),
	.flushM(flushM),
    .branchD(branchD),
	.branchE(branchE),
    .branchM(branchM),
    .actual_takeE(actual_takeE),
    .actual_takeM(actual_takeM),

    .pred_takeD(pred_takeD),
    .pred_wrongM(pred_wrongM)
);


endmodule

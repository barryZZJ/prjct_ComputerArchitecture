`timescale 1ns / 1ps

module hazard(input [4:0] rsD,
              input [4:0] rtD,
              input [4:0] rsE,
              input [4:0] rtE,
              input [4:0] writeregE,
              input [4:0] writeregM,
              input [4:0] writeregW,
              input regwriteE,
              input regwriteM,
              input regwriteW,
              input memtoregE,
              input memtoregM,
              input pred_takeD,
              input pred_wrongM, //* 分支预测是否出错
              
              output [1:0] forwardAE,
              output [1:0] forwardBE,
              output wire stallF, stallD, flushD, flushE, flushM
              );

// --------------------------------
// 数据冒险

// forward
assign forwardAE = ((rsE != 0) && (rsE == writeregM) && regwriteM) ? 2'b10 :
                   ((rsE != 0) && (rsE == writeregW) && regwriteW) ? 2'b01 :
                   2'b00;
assign forwardBE = ((rtE != 0) && (rtE == writeregM) && regwriteM) ? 2'b10 :
                   ((rtE != 0) && (rtE == writeregW) && regwriteW) ? 2'b01 :
                   2'b00;

// --------------------------------
// stall
wire lwstall;
assign lwstall = ((rsD == rtE) || (rtD == rtE)) && memtoregE; // 判断 decode 阶段 rs 或 rt 的地址是否是 lw 指令要写入的地址；

assign stallF = lwstall;
assign stallD = lwstall;
//* 因为无论如何都会加载BEQ的下一条指令，所以如果预测跳转，需要把flushD置1，防止译码BEQ的下一条指令
//* 同时分支预测失败时(在MEM阶段发现)，需要flush MEM之前的各级流水线
assign flushD = pred_takeD | pred_wrongM;
assign flushM = pred_wrongM;
assign flushE = lwstall || pred_wrongM; 

endmodule

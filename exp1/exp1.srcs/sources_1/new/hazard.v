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
              input pred_wrongM, //* ��֧Ԥ���Ƿ����
              
              output [1:0] forwardAE,
              output [1:0] forwardBE,
              output wire stallF, stallD, flushD, flushE, flushM
              );

// --------------------------------
// ����ð��

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
assign lwstall = ((rsD == rtE) || (rtD == rtE)) && memtoregE; // �ж� decode �׶� rs �� rt �ĵ�ַ�Ƿ��� lw ָ��Ҫд��ĵ�ַ��

assign stallF = lwstall;
assign stallD = lwstall;
//* ��֧Ԥ��ʧ��ʱflush��ˮ��
assign flushD = pred_wrongM;
assign flushM = pred_wrongM;
assign flushE = lwstall || pred_wrongM; 

endmodule

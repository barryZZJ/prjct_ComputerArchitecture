module branch_predict_global(
    input wire clk, rst,

    input wire flushD, stallD, flushE, flushM,
    input wire branchD, branchE, branchM,
    input wire actual_takeE, actual_takeM,

    output wire pred_takeD,
    output wire pred_wrongM
);
//* 只使用一个PHT

wire pred_takeF;
reg pred_takeF_r;

// 定义参数
parameter Strongly_not_taken = 2'b00, Weakly_not_taken = 2'b01, Weakly_taken = 2'b11, Strongly_taken = 2'b10;
parameter GHR_LENGTH = 8;

reg [GHR_LENGTH-1:0] GHR_value;
reg [GHR_LENGTH-1:0] GHR_value_prev; //* GHR 更新之前的值，用于训练PHT
reg [1:0] PHT [(1<<GHR_LENGTH)-1 : 0]; //* 2^k个两位饱和计数器

integer i;

// ----------------------预测逻辑 start----------------------

assign pred_takeF = PHT[GHR_value][1]; //* 在取指阶段预测是否会跳转，并经过流水线传递给译码阶段。

// --------------pipeline------------------
    always @(posedge clk) begin
        if(rst | flushD) begin
            pred_takeF_r <= 0;
        end
        else if(~stallD) begin
            pred_takeF_r <= pred_takeF;
        end
    end
// --------------pipeline------------------

// ---------------------预测逻辑 end ---------------------

//* 为了便于实验的进行，基于现有的五级流水，从教学意义的角度出发，综合考虑，我们要求在实现在预测实现更新。
//* 由于计组实验4还未实现异常模块，并且五级流水流水级数较短，因此暂不考虑解决造成更新错误的第二种情况。

//* 在执行EX阶段判断预测结果是否正确；
reg pred_wrongE;
always @(posedge clk ) begin
    if(rst | flushE)
        pred_wrongE <= 1'b0;
    else if (branchE && pred_takeF_r != actual_takeE)
        pred_wrongE <= 1'b1;
    else
        pred_wrongE <= 1'b0;
end

// ---------------------GHR初始化以及更新start---------------------
//* 在预测时根据预测的结果更新GHR，将预测的分支指令的跳转方向左移进得到的GHR中
always @(posedge clk) begin
    if (rst) begin
        GHR_value <= 0;
        GHR_value_prev <= 0;
    end else if (~stallD && branchD) begin
        GHR_value_prev <= GHR_value;
        GHR_value <= {GHR_value[GHR_LENGTH-2:0], pred_takeF};
    end
end
// ---------------------GHR初始化以及更新end---------------------

//* MEM阶段判断，如果预测错误，则清空流水线（在hazard模块中）和将指令计数器置为正确的值（在datapath模块中），由pred_wrongM信号控制。
//* EX结束、MEM刚开始时输出预测是否错误：
assign pred_wrongM = pred_wrongE;

// ---------------------PHT初始化以及更新start---------------------
//* MEM阶段根据实际的结果训练PHT
always @(posedge clk) begin
    if(rst) begin
        for(i = 0; i < (1<<GHR_LENGTH); i=i+1) begin
            PHT[i] <= Weakly_taken;
        end
    end
    else if (branchM) begin
        case(PHT[GHR_value_prev])
        //* 此处应该添加你的更新逻辑的代码
        //* 如果当前指令是branch指令，则根据更新了的GHR训练PHT
            Strongly_not_taken: begin
                if (actual_takeM) 
                    PHT[GHR_value_prev] <= Weakly_not_taken;
                else
                    PHT[GHR_value_prev] <= Strongly_not_taken;
            end
            Weakly_not_taken: begin
                if (actual_takeM) 
                    PHT[GHR_value_prev] <= Weakly_taken;
                else
                    PHT[GHR_value_prev] <= Strongly_not_taken;
            end
            Weakly_taken: begin
                if (actual_takeM) 
                    PHT[GHR_value_prev] <= Strongly_taken;
                else
                    PHT[GHR_value_prev] <= Weakly_not_taken;
            end
            Strongly_taken: begin
                if (actual_takeM) 
                    PHT[GHR_value_prev] <= Strongly_taken;
                else
                    PHT[GHR_value_prev] <= Weakly_taken;
            end
        endcase 
    end
end
// ---------------------PHT初始化以及更新end---------------------


//* 在译码ID阶段判断当前指令是否是分支指令，结合IF阶段得到的预测方向，判断是否跳转；
// 译码阶段输出最终的预测结果
assign pred_takeD = branchD & pred_takeF_r;  
endmodule
module branch_predict_tour(
    input wire clk, rst,
    
    input wire flushD, stallD, flushE, flushM,

    input wire [31:0] pcF, pcD, pcE, pcM,
    input wire branchD, branchE, branchM,
    input wire actual_takeE, actual_takeM,

    output wire pred_takeD,
    output wire pred_wrongM
);

parameter Strongly_not_taken = 2'b00, Weakly_not_taken = 2'b01, Weakly_taken = 2'b11, Strongly_taken = 2'b10;

// ================== 基于局部历史预测相关 start===================
wire pred_takeF_loc;
reg pred_takeF_r_loc;
parameter PHTl_DEPTH = 6;  //* BHR_LENGTH，BHR要存的位数
parameter BHT_DEPTH = 10; //* k BHT表项的个数
reg [5:0] BHT [(1<<BHT_DEPTH)-1 : 0];
reg [1:0] PHTl [(1<<PHTl_DEPTH)-1 : 0]; //* 2^k个两位饱和计数器

integer i,j;
wire [(PHTl_DEPTH-1):0] PHTl_index;
wire [(BHT_DEPTH-1):0] BHT_index;
wire [(PHTl_DEPTH-1):0] BHR_value;

// ----------------------预测逻辑 start----------------------
assign BHT_index = pcF[11:2];     
assign BHR_value = BHT[BHT_index];  
assign PHTl_index = BHR_value ^ pcF[7:2]; //* 所有分支指令只使用一个PHTl。不同指令可能对应到相同BHR值，对应PHTl的同一个计数器。为解决冲突，使用pc[7:2] ^ BHR来索引PHT。

assign pred_takeF_loc = PHTl[PHTl_index][1];      // 在取指阶段预测是否会跳转，并经过流水线传递给译码阶段。

    // --------------------------pipeline------------------------------
        always @(posedge clk) begin
            if(rst | flushD) begin
                pred_takeF_r_loc <= 0;
            end
            else if(~stallD) begin
                pred_takeF_r_loc <= pred_takeF_loc;
            end
        end
    // --------------------------pipeline------------------------------
// ---------------------预测逻辑 end ---------------------

//* 在执行EX阶段判断预测结果是否正确；
reg pred_wrongE_loc;
always @(posedge clk ) begin
    if(rst | flushE)
        pred_wrongE_loc <= 1'b0;
    else if (branchE && PHTl[BHT[pcE[11:2]] ^ pcE[7:2]][1] != actual_takeE)
        pred_wrongE_loc <= 1'b1;
    else
        pred_wrongE_loc <= 1'b0;
end

// ----------------BHT初始化以及更新 start----------------
wire [(PHTl_DEPTH-1):0] update_PHTl_index;
wire [(BHT_DEPTH-1):0] update_BHT_index;
wire [(PHTl_DEPTH-1):0] update_BHR_value;

assign update_BHT_index = pcM[11:2];     
assign update_BHR_value = BHT[update_BHT_index];  
assign update_PHTl_index = update_BHR_value ^ pcM[7:2];

always@(posedge clk) begin
    if(rst) begin
        for(j = 0; j < (1<<BHT_DEPTH); j=j+1) begin
            BHT[j] <= 0;
        end
    end
    else if(branchM) begin
        // 此处应该添加你的更新逻辑的代码
        //* 在访存Mem阶段，如果预测正确，则根据访存mem阶段的指令地址索引到对应的BHR，将分支指令的跳转方向左移进得到的BHR中；
        //* 如果预测错误，则清空流水线和将指令计数器置为正确的值，除此之外还要将分支指令正确的跳转方向左移进得到的BHR中。
        BHT[update_BHT_index] <= {BHT[update_BHT_index][4:0], actual_takeM};
    end
end

//* 如果预测错误，则清空流水线（在hazard模块中）和将指令计数器置为正确的值（在datapath模块中），由pred_wrongM信号控制。
//* EX结束、MEM刚开始时输出预测是否错误：
wire pred_wrongM_loc;
assign pred_wrongM_loc = pred_wrongE_loc;
// -------------------BHT初始化以及更新 end-------------------



// ------------------PHTl初始化以及更新 start------------------
always @(posedge clk) begin
    if(rst) begin
        for(i = 0; i < (1<<PHTl_DEPTH); i=i+1) begin
            PHTl[i] <= Weakly_taken;
        end
    end
    else if (branchM) begin
        case(PHTl[update_PHTl_index])
        //* 此处应该添加你的更新逻辑的代码
        //* 如果当前指令是branch指令，则根据更新了的BHR训练PHTl
            Strongly_not_taken: begin
                if (actual_takeM) 
                    PHTl[update_PHTl_index] <= Weakly_not_taken;
                else
                    PHTl[update_PHTl_index] <= Strongly_not_taken;
            end
            Weakly_not_taken: begin
                if (actual_takeM) 
                    PHTl[update_PHTl_index] <= Weakly_taken;
                else
                    PHTl[update_PHTl_index] <= Strongly_not_taken;
            end
            Weakly_taken: begin
                if (actual_takeM) 
                    PHTl[update_PHTl_index] <= Strongly_taken;
                else
                    PHTl[update_PHTl_index] <= Weakly_not_taken;
            end
            Strongly_taken: begin
                if (actual_takeM) 
                    PHTl[update_PHTl_index] <= Strongly_taken;
                else
                    PHTl[update_PHTl_index] <= Weakly_taken;
            end
        endcase 
    end
end
// ----------------PHTl初始化以及更新 end----------------

//* 在译码ID阶段判断当前指令是否是分支指令，结合IF阶段得到的预测方向，判断是否跳转；
// 译码阶段输出local的预测结果
wire pred_takeD_loc;
assign pred_takeD_loc = branchD & pred_takeF_r_loc;  

// ================== 基于局部历史预测相关 end===================





// ================== 基于全局历史预测相关 start===================
// 基于全局历史预测相关
wire pred_takeF_glo;
reg pred_takeF_r_glo;

parameter GHR_LENGTH = 8;
reg [GHR_LENGTH-1:0] GHR_value;
reg [GHR_LENGTH-1:0] GHR_value_prev; //* GHR 更新之前的值，用于训练PHTg
reg [1:0] PHTg [(1<<GHR_LENGTH)-1 : 0]; //* 2^k个两位饱和计数器
integer t;

wire [(GHR_LENGTH-1):0] PHTg_index;
// ----------------------预测逻辑 start----------------------

assign PHTg_index = GHR_value ^ pcF[9:2]; //* GHR有8位，故取pc[9:2]
assign pred_takeF_glo = PHTg[PHTg_index][1]; //* 在取指阶段预测是否会跳转，并经过流水线传递给译码阶段。

// --------------pipeline------------------
    always @(posedge clk) begin
        if(rst | flushD) begin
            pred_takeF_r_glo <= 0;
        end
        else if(~stallD) begin
            pred_takeF_r_glo <= pred_takeF_glo;
        end
    end
// --------------pipeline------------------

// ---------------------预测逻辑 end ---------------------

//* 为了便于实验的进行，基于现有的五级流水，从教学意义的角度出发，综合考虑，我们要求在实现在预测实现更新。
//* 由于计组实验4还未实现异常模块，并且五级流水流水级数较短，因此暂不考虑解决造成更新错误的第二种情况。

//* 在执行EX阶段判断预测结果是否正确；
reg pred_wrongE_glo;
always @(posedge clk ) begin
    if(rst | flushE)
        pred_wrongE_glo <= 1'b0;
    else if (branchE && pred_takeF_r_glo != actual_takeE)
        pred_wrongE_glo <= 1'b1;
    else
        pred_wrongE_glo <= 1'b0;
end

// ---------------------GHR初始化以及更新start---------------------
//* 在预测时根据预测的结果更新GHR，将预测的分支指令的跳转方向左移进得到的GHR中
always @(posedge clk) begin
    if (rst) begin
        GHR_value <= 0;
        GHR_value_prev <= 0;
    end else if (~stallD && branchD) begin
        GHR_value_prev <= GHR_value;
        GHR_value <= {GHR_value[GHR_LENGTH-2:0], pred_takeF_glo};
    end
end
// ---------------------GHR初始化以及更新end---------------------

//* MEM阶段判断，如果预测错误，则清空流水线（在hazard模块中）和将指令计数器置为正确的值（在datapath模块中），由pred_wrongM信号控制。
//* EX结束、MEM刚开始时输出预测是否错误：
wire pred_wrongM_glo;
assign pred_wrongM_glo = pred_wrongE_glo;

// ---------------------PHTg初始化以及更新start---------------------
wire [(GHR_LENGTH-1):0] update_PHTg_index;
assign update_PHTg_index = GHR_value_prev ^ pcM[9:2]; //* GHR有8位，故取pc[9:2]
//* MEM阶段根据实际的结果训练PHTg
always @(posedge clk) begin
    if(rst) begin
        for(t = 0; t < (1<<GHR_LENGTH); t=t+1) begin
            PHTg[t] <= Weakly_taken;
        end
    end
    else if (branchM) begin
        case(PHTg[update_PHTg_index])
        //* 此处应该添加你的更新逻辑的代码
        //* 如果当前指令是branch指令，则根据更新了的GHR训练PHTg
            Strongly_not_taken: begin
                if (actual_takeM) 
                    PHTg[update_PHTg_index] <= Weakly_not_taken;
                else
                    PHTg[update_PHTg_index] <= Strongly_not_taken;
            end
            Weakly_not_taken: begin
                if (actual_takeM) 
                    PHTg[update_PHTg_index] <= Weakly_taken;
                else
                    PHTg[update_PHTg_index] <= Strongly_not_taken;
            end
            Weakly_taken: begin
                if (actual_takeM) 
                    PHTg[update_PHTg_index] <= Strongly_taken;
                else
                    PHTg[update_PHTg_index] <= Weakly_not_taken;
            end
            Strongly_taken: begin
                if (actual_takeM) 
                    PHTg[update_PHTg_index] <= Strongly_taken;
                else
                    PHTg[update_PHTg_index] <= Weakly_taken;
            end
        endcase 
    end
end
// ---------------------PHTg初始化以及更新end---------------------

//* 在译码ID阶段判断当前指令是否是分支指令，结合IF阶段得到的预测方向，判断是否跳转；
// 译码阶段输出global的预测结果
wire pred_takeD_glo;
assign pred_takeD_glo = branchD & pred_takeF_r_glo;  

// ================== 基于全局历史预测相关 end===================


// ================= 竞争 ====================
reg [1:0] CPHT [(1<<GHR_LENGTH)-1:0];

parameter Strongly_global = 2'b00, Weakly_global = 2'b01, Weakly_local = 2'b10, Strongly_local = 2'b11;
integer l;

// ---------------- CPHT初始化以及更新 start-----------------
// 当P1预测正确，P2预测错误时(1/0)，计数器减1
// 当P1预测错误，P2预测正确时(1/0)，计数器加1
// 当P1和P2预测的结果一样时(1/1或0/0)，不管预测正确与否，计数器都保持不变
always @(posedge clk) begin
if(rst) begin
    for(l = 0; l < (1<<GHR_LENGTH); l=l+1) begin
        CPHT[l] <= Weakly_local;
    end
end else if (branchM) begin
// * 根据GHR和pc异或的结果索引CPHT
    case ({pred_wrongM_glo, pred_wrongM_loc})
        2'b10:
            CPHT[GHR_value_prev ^ pcM[9:2]] <= CPHT[GHR_value_prev ^ pcM[9:2]] - 1'b1;
        2'b01:
            CPHT[GHR_value_prev ^ pcM[9:2]] <= CPHT[GHR_value_prev ^ pcM[9:2]] + 1'b1;
        default:
            CPHT[GHR_value_prev ^ pcM[9:2]] <= CPHT[GHR_value_prev ^ pcM[9:2]];
    endcase
end
end
// ---------------- CPHT初始化以及更新 end-----------------
//* EX结束、MEM刚开始时输出预测是否错误：
assign pred_wrongM = CPHT[GHR_value_prev ^ pcM[9:2]][1] == 1'b0 ? pred_wrongM_glo :
                                                        pred_wrongM_loc;

//* ID阶段输出最终的预测结果
assign pred_takeD = CPHT[GHR_value ^ pcD[9:2]][1] == 1'b0 ? pred_takeD_glo :
                                                    pred_takeD_loc;
// ================= 竞争 ====================

endmodule
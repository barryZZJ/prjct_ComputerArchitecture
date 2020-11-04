module branch_predict_local (
    input wire clk, rst,
    
    input wire flushD, stallD, flushE, flushM,

    input wire [31:0] pcF, pcE, pcM,

    input wire branchD,        // ID阶段是否是跳转指令  
    input wire branchE,
    input wire branchM,        // Mem阶段是否是分支指令
    input wire actual_takeE,   // 实际是否跳转
    input wire actual_takeM,   // 实际是否跳转

    output wire pred_takeD,    // 预测是否跳转
    output wire pred_wrongM      // 预测是否错误，用于hazard flush
);

//* 所有分支指令只使用一个PHT。不同指令可能对应到相同BHR值，对应PHT的同一个计数器。

wire pred_takeF;
reg pred_takeF_r;

// 定义参数
parameter Strongly_not_taken = 2'b00, Weakly_not_taken = 2'b01, Weakly_taken = 2'b11, Strongly_taken = 2'b10;
parameter PHT_DEPTH = 6;  //* BHR_LENGTH，BHR要存的位数
parameter BHT_DEPTH = 10; //* k BHT表项的个数

reg [5:0] BHT [(1<<BHT_DEPTH)-1 : 0];
reg [1:0] PHT [(1<<PHT_DEPTH)-1 : 0]; //* 2^k个两位饱和计数器

integer i,j;
wire [(PHT_DEPTH-1):0] PHT_index;
wire [(BHT_DEPTH-1):0] BHT_index;
wire [(PHT_DEPTH-1):0] BHR_value;

// ----------------------预测逻辑 start----------------------
assign BHT_index = pcF[11:2];     
assign BHR_value = BHT[BHT_index];  
assign PHT_index = BHR_value; //* 所有分支指令只使用一个PHT。不同指令可能对应到相同BHR值，对应PHT的同一个计数器。

assign pred_takeF = PHT[PHT_index][1];      // 在取指阶段预测是否会跳转，并经过流水线传递给译码阶段。

    // --------------------------pipeline------------------------------
        always @(posedge clk) begin
            if(rst | flushD) begin
                pred_takeF_r <= 0;
            end
            else if(~stallD) begin
                pred_takeF_r <= pred_takeF;
            end
        end
    // --------------------------pipeline------------------------------

// ---------------------预测逻辑 end ---------------------

//* 在执行EX阶段判断预测结果是否正确；
reg pred_wrongE;
always @(posedge clk ) begin
    if(rst | flushE)
        pred_wrongE <= 1'b0;
    else if (branchE && PHT[BHT[pcE[11:2]]][1] != actual_takeE)
        pred_wrongE <= 1'b1;
    else
        pred_wrongE <= 1'b0;
end

// ----------------BHT初始化以及更新 start----------------
wire [(PHT_DEPTH-1):0] update_PHT_index;
wire [(BHT_DEPTH-1):0] update_BHT_index;
wire [(PHT_DEPTH-1):0] update_BHR_value;

assign update_BHT_index = pcM[11:2];     
assign update_BHR_value = BHT[update_BHT_index];  
assign update_PHT_index = update_BHR_value;

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
assign pred_wrongM = pred_wrongE;
// -------------------BHT初始化以及更新 end-------------------


// ------------------PHT初始化以及更新 start------------------
always @(posedge clk) begin
    if(rst) begin
        for(i = 0; i < (1<<PHT_DEPTH); i=i+1) begin
            PHT[i] <= Weakly_taken;
        end
    end
    else if (branchM) begin
        case(PHT[update_PHT_index])
        //* 此处应该添加你的更新逻辑的代码
        //* 如果当前指令是branch指令，则根据更新了的BHR训练PHT
            Strongly_not_taken: begin
                if (actual_takeM) 
                    PHT[update_PHT_index] <= Weakly_not_taken;
                else
                    PHT[update_PHT_index] <= Strongly_not_taken;
            end
            Weakly_not_taken: begin
                if (actual_takeM) 
                    PHT[update_PHT_index] <= Weakly_taken;
                else
                    PHT[update_PHT_index] <= Strongly_not_taken;
            end
            Weakly_taken: begin
                if (actual_takeM) 
                    PHT[update_PHT_index] <= Strongly_taken;
                else
                    PHT[update_PHT_index] <= Weakly_not_taken;
            end
            Strongly_taken: begin
                if (actual_takeM) 
                    PHT[update_PHT_index] <= Strongly_taken;
                else
                    PHT[update_PHT_index] <= Weakly_taken;
            end
        endcase 
    end
end
// ----------------PHT初始化以及更新 end----------------

//* 在译码ID阶段判断当前指令是否是分支指令，结合IF阶段得到的预测方向，判断是否跳转；
// 译码阶段输出最终的预测结果
assign pred_takeD = branchD & pred_takeF_r;  
endmodule
module branch_predict_global(
    input wire clk, rst,

    input wire flushD, stallD, flushE, flushM,
    input wire branchD, branchE, branchM,
    input wire actual_takeE, actual_takeM,

    output wire pred_takeD,
    output wire pred_wrongM
);
//* ֻʹ��һ��PHT

wire pred_takeF;
reg pred_takeF_r;

// �������
parameter Strongly_not_taken = 2'b00, Weakly_not_taken = 2'b01, Weakly_taken = 2'b11, Strongly_taken = 2'b10;
parameter GHR_LENGTH = 8;

reg [GHR_LENGTH-1:0] GHR_value;
reg [GHR_LENGTH-1:0] GHR_value_prev; //* GHR ����֮ǰ��ֵ������ѵ��PHT
reg [1:0] PHT [(1<<GHR_LENGTH)-1 : 0]; //* 2^k����λ���ͼ�����

integer i;

// ----------------------Ԥ���߼� start----------------------

assign pred_takeF = PHT[GHR_value][1]; //* ��ȡָ�׶�Ԥ���Ƿ����ת����������ˮ�ߴ��ݸ�����׶Ρ�

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

// ---------------------Ԥ���߼� end ---------------------

//* Ϊ�˱���ʵ��Ľ��У��������е��弶��ˮ���ӽ�ѧ����ĽǶȳ������ۺϿ��ǣ�����Ҫ����ʵ����Ԥ��ʵ�ָ��¡�
//* ���ڼ���ʵ��4��δʵ���쳣ģ�飬�����弶��ˮ��ˮ�����϶̣�����ݲ����ǽ����ɸ��´���ĵڶ��������

//* ��ִ��EX�׶��ж�Ԥ�����Ƿ���ȷ��
reg pred_wrongE;
always @(posedge clk ) begin
    if(rst | flushE)
        pred_wrongE <= 1'b0;
    else if (branchE && pred_takeF_r != actual_takeE)
        pred_wrongE <= 1'b1;
    else
        pred_wrongE <= 1'b0;
end

// ---------------------GHR��ʼ���Լ�����start---------------------
//* ��Ԥ��ʱ����Ԥ��Ľ������GHR����Ԥ��ķ�ָ֧�����ת�������ƽ��õ���GHR��
always @(posedge clk) begin
    if (rst) begin
        GHR_value <= 0;
        GHR_value_prev <= 0;
    end else if (~stallD && branchD) begin
        GHR_value_prev <= GHR_value;
        GHR_value <= {GHR_value[GHR_LENGTH-2:0], pred_takeF};
    end
end
// ---------------------GHR��ʼ���Լ�����end---------------------

//* MEM�׶��жϣ����Ԥ������������ˮ�ߣ���hazardģ���У��ͽ�ָ���������Ϊ��ȷ��ֵ����datapathģ���У�����pred_wrongM�źſ��ơ�
//* EX������MEM�տ�ʼʱ���Ԥ���Ƿ����
assign pred_wrongM = pred_wrongE;

// ---------------------PHT��ʼ���Լ�����start---------------------
//* MEM�׶θ���ʵ�ʵĽ��ѵ��PHT
always @(posedge clk) begin
    if(rst) begin
        for(i = 0; i < (1<<GHR_LENGTH); i=i+1) begin
            PHT[i] <= Weakly_taken;
        end
    end
    else if (branchM) begin
        case(PHT[GHR_value_prev])
        //* �˴�Ӧ�������ĸ����߼��Ĵ���
        //* �����ǰָ����branchָ�����ݸ����˵�GHRѵ��PHT
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
// ---------------------PHT��ʼ���Լ�����end---------------------


//* ������ID�׶��жϵ�ǰָ���Ƿ��Ƿ�ָ֧����IF�׶εõ���Ԥ�ⷽ���ж��Ƿ���ת��
// ����׶�������յ�Ԥ����
assign pred_takeD = branchD & pred_takeF_r;  
endmodule
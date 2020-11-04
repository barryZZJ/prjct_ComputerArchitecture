module branch_predict_tour(
    input wire clk, rst,
    
    input wire flushD, stallD, flushE, flushM,

    input wire [31:0] pcF, pcE, pcM,
    input wire branchD, branchE, branchM,
    input wire actual_takeE, actual_takeM,

    output wire pred_takeD,
    output wire pred_wrongM,
    //! for debug
    output wire pred_takeD_loc,
    output wire pred_takeD_glo
);

parameter Strongly_not_taken = 2'b00, Weakly_not_taken = 2'b01, Weakly_taken = 2'b11, Strongly_taken = 2'b10;

// ================== ���ھֲ���ʷԤ����� start===================
wire pred_takeF_loc;
reg pred_takeF_r_loc;
parameter PHTl_DEPTH = 6;  //* BHR_LENGTH��BHRҪ���λ��
parameter BHT_DEPTH = 10; //* k BHT����ĸ���
reg [5:0] BHT [(1<<BHT_DEPTH)-1 : 0];
reg [1:0] PHTl [(1<<PHTl_DEPTH)-1 : 0]; //* 2^k����λ���ͼ�����

integer i,j;
wire [(PHTl_DEPTH-1):0] PHTl_index;
wire [(BHT_DEPTH-1):0] BHT_index;
wire [(PHTl_DEPTH-1):0] BHR_value;

// ----------------------Ԥ���߼� start----------------------
assign BHT_index = pcF[11:2];     
assign BHR_value = BHT[BHT_index];  
assign PHTl_index = BHR_value; //* ���з�ָ֧��ֻʹ��һ��PHTl����ָͬ����ܶ�Ӧ����ͬBHRֵ����ӦPHTl��ͬһ����������

assign pred_takeF_loc = PHTl[PHTl_index][1];      // ��ȡָ�׶�Ԥ���Ƿ����ת����������ˮ�ߴ��ݸ�����׶Ρ�

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
// ---------------------Ԥ���߼� end ---------------------

//* ��ִ��EX�׶��ж�Ԥ�����Ƿ���ȷ��
reg pred_wrongE_loc;
always @(posedge clk ) begin
    if(rst | flushE)
        pred_wrongE_loc <= 1'b0;
    else if (branchE && PHTl[BHT[pcE[11:2]]][1] != actual_takeE)
        pred_wrongE_loc <= 1'b1;
    else
        pred_wrongE_loc <= 1'b0;
end

// ----------------BHT��ʼ���Լ����� start----------------
wire [(PHTl_DEPTH-1):0] update_PHTl_index;
wire [(BHT_DEPTH-1):0] update_BHT_index;
wire [(PHTl_DEPTH-1):0] update_BHR_value;

assign update_BHT_index = pcM[11:2];     
assign update_BHR_value = BHT[update_BHT_index];  
assign update_PHTl_index = update_BHR_value;

always@(posedge clk) begin
    if(rst) begin
        for(j = 0; j < (1<<BHT_DEPTH); j=j+1) begin
            BHT[j] <= 0;
        end
    end
    else if(branchM) begin
        // �˴�Ӧ�������ĸ����߼��Ĵ���
        //* �ڷô�Mem�׶Σ����Ԥ����ȷ������ݷô�mem�׶ε�ָ���ַ��������Ӧ��BHR������ָ֧�����ת�������ƽ��õ���BHR�У�
        //* ���Ԥ������������ˮ�ߺͽ�ָ���������Ϊ��ȷ��ֵ������֮�⻹Ҫ����ָ֧����ȷ����ת�������ƽ��õ���BHR�С�
        BHT[update_BHT_index] <= {BHT[update_BHT_index][4:0], actual_takeM};
    end
end

//* ���Ԥ������������ˮ�ߣ���hazardģ���У��ͽ�ָ���������Ϊ��ȷ��ֵ����datapathģ���У�����pred_wrongM�źſ��ơ�
//* EX������MEM�տ�ʼʱ���Ԥ���Ƿ����
wire pred_wrongM_loc;
assign pred_wrongM_loc = pred_wrongE_loc;
// -------------------BHT��ʼ���Լ����� end-------------------



// ------------------PHTl��ʼ���Լ����� start------------------
always @(posedge clk) begin
    if(rst) begin
        for(i = 0; i < (1<<PHTl_DEPTH); i=i+1) begin
            PHTl[i] <= Weakly_taken;
        end
    end
    else if (branchM) begin
        case(PHTl[update_PHTl_index])
        //* �˴�Ӧ�������ĸ����߼��Ĵ���
        //* �����ǰָ����branchָ�����ݸ����˵�BHRѵ��PHTl
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
// ----------------PHTl��ʼ���Լ����� end----------------

//* ������ID�׶��жϵ�ǰָ���Ƿ��Ƿ�ָ֧����IF�׶εõ���Ԥ�ⷽ���ж��Ƿ���ת��
// ����׶����local��Ԥ����
wire pred_takeD_loc;
assign pred_takeD_loc = branchD & pred_takeF_r_loc;  

// ================== ���ھֲ���ʷԤ����� end===================





// ================== ����ȫ����ʷԤ����� start===================
// ����ȫ����ʷԤ�����
wire pred_takeF_glo;
reg pred_takeF_r_glo;

parameter GHR_LENGTH = 8;
reg [GHR_LENGTH-1:0] GHR_value;
reg [GHR_LENGTH-1:0] GHR_value_prev; //* GHR ����֮ǰ��ֵ������ѵ��PHTg
reg [1:0] PHTg [(1<<GHR_LENGTH)-1 : 0]; //* 2^k����λ���ͼ�����
integer t;

// ----------------------Ԥ���߼� start----------------------

assign pred_takeF_glo = PHTg[GHR_value][1]; //* ��ȡָ�׶�Ԥ���Ƿ����ת����������ˮ�ߴ��ݸ�����׶Ρ�

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

// ---------------------Ԥ���߼� end ---------------------

//* Ϊ�˱���ʵ��Ľ��У��������е��弶��ˮ���ӽ�ѧ����ĽǶȳ������ۺϿ��ǣ�����Ҫ����ʵ����Ԥ��ʵ�ָ��¡�
//* ���ڼ���ʵ��4��δʵ���쳣ģ�飬�����弶��ˮ��ˮ�����϶̣�����ݲ����ǽ����ɸ��´���ĵڶ��������

//* ��ִ��EX�׶��ж�Ԥ�����Ƿ���ȷ��
reg pred_wrongE_glo;
always @(posedge clk ) begin
    if(rst | flushE)
        pred_wrongE_glo <= 1'b0;
    else if (branchE && pred_takeF_r_glo != actual_takeE)
        pred_wrongE_glo <= 1'b1;
    else
        pred_wrongE_glo <= 1'b0;
end

// ---------------------GHR��ʼ���Լ�����start---------------------
//* ��Ԥ��ʱ����Ԥ��Ľ������GHR����Ԥ��ķ�ָ֧�����ת�������ƽ��õ���GHR��
always @(posedge clk) begin
    if (rst) begin
        GHR_value <= 0;
        GHR_value_prev <= 0;
    end else if (~stallD && branchD) begin
        GHR_value_prev <= GHR_value;
        GHR_value <= {GHR_value[GHR_LENGTH-2:0], pred_takeF_glo};
    end
end
// ---------------------GHR��ʼ���Լ�����end---------------------

//* MEM�׶��жϣ����Ԥ������������ˮ�ߣ���hazardģ���У��ͽ�ָ���������Ϊ��ȷ��ֵ����datapathģ���У�����pred_wrongM�źſ��ơ�
//* EX������MEM�տ�ʼʱ���Ԥ���Ƿ����
wire pred_wrongM_glo;
assign pred_wrongM_glo = pred_wrongE_glo;

// ---------------------PHTg��ʼ���Լ�����start---------------------
//* MEM�׶θ���ʵ�ʵĽ��ѵ��PHTg
always @(posedge clk) begin
    if(rst) begin
        for(t = 0; t < (1<<GHR_LENGTH); t=t+1) begin
            PHTg[t] <= Weakly_taken;
        end
    end
    else if (branchM) begin
        case(PHTg[GHR_value_prev])
        //* �˴�Ӧ�������ĸ����߼��Ĵ���
        //* �����ǰָ����branchָ�����ݸ����˵�GHRѵ��PHTg
            Strongly_not_taken: begin
                if (actual_takeM) 
                    PHTg[GHR_value_prev] <= Weakly_not_taken;
                else
                    PHTg[GHR_value_prev] <= Strongly_not_taken;
            end
            Weakly_not_taken: begin
                if (actual_takeM) 
                    PHTg[GHR_value_prev] <= Weakly_taken;
                else
                    PHTg[GHR_value_prev] <= Strongly_not_taken;
            end
            Weakly_taken: begin
                if (actual_takeM) 
                    PHTg[GHR_value_prev] <= Strongly_taken;
                else
                    PHTg[GHR_value_prev] <= Weakly_not_taken;
            end
            Strongly_taken: begin
                if (actual_takeM) 
                    PHTg[GHR_value_prev] <= Strongly_taken;
                else
                    PHTg[GHR_value_prev] <= Weakly_taken;
            end
        endcase 
    end
end
// ---------------------PHTg��ʼ���Լ�����end---------------------

//* ������ID�׶��жϵ�ǰָ���Ƿ��Ƿ�ָ֧����IF�׶εõ���Ԥ�ⷽ���ж��Ƿ���ת��
// ����׶����global��Ԥ����
wire pred_takeD_glo;
assign pred_takeD_glo = branchD & pred_takeF_r_glo;  

// ================== ����ȫ����ʷԤ����� end===================


// ================= ���� ====================
reg [1:0] CPHT [(1<<GHR_LENGTH)-1:0];

parameter Strongly_global = 2'b00, Weakly_global = 2'b01, Weakly_local = 2'b10, Strongly_local = 2'b11;
integer l;

// ---------------- CPHT��ʼ���Լ����� start-----------------
// ��P1Ԥ����ȷ��P2Ԥ�����ʱ(1/0)����������1
// ��P1Ԥ�����P2Ԥ����ȷʱ(1/0)����������1
// ��P1��P2Ԥ��Ľ��һ��ʱ(1/1��0/0)������Ԥ����ȷ��񣬼����������ֲ���
always @(posedge clk) begin
if(rst) begin
    for(l = 0; l < (1<<GHR_LENGTH); l=l+1) begin
        CPHT[l] <= Weakly_local;
    end
end else if (branchM) begin
    case ({pred_wrongM_glo, pred_wrongM_loc})
        2'b10:
            CPHT[GHR_value_prev] <= CPHT[GHR_value_prev] - 1'b1;
        2'b01:
            CPHT[GHR_value_prev] <= CPHT[GHR_value_prev] + 1'b1;
        default:
            CPHT[GHR_value_prev] <= CPHT[GHR_value_prev];
    endcase
end
end
// ---------------- CPHT��ʼ���Լ����� end-----------------
//* EX������MEM�տ�ʼʱ���Ԥ���Ƿ����
assign pred_wrongM = CPHT[GHR_value_prev][1] == 1'b0 ? pred_wrongM_glo :
                                                        pred_wrongM_loc;

//* ID�׶�������յ�Ԥ����
assign pred_takeD = CPHT[GHR_value][1] == 1'b0 ? pred_takeD_glo :
                                                    pred_takeD_loc;
// ================= ���� ====================

endmodule
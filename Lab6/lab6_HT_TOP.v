//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2023/10
//		Version		: v1.0
//   	File Name   : HT_TOP.v
//   	Module Name : HT_TOP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

//synopsys translate_off
`include "SORT_IP.v"
//synopsys translate_on

module HT_TOP(
    // Input signals
    clk,
	rst_n,
	in_valid,
    in_weight, 
	out_mode,
    // Output signals
    out_valid, 
	out_code
);

// ===============================================================
// Input & Output Declaration
// ===============================================================
input clk, rst_n, in_valid, out_mode;
input [2:0] in_weight;

output reg out_valid, out_code;
// ===============================================================
// PARAMETER
// ===============================================================
parameter IDLE = 2'd0;
parameter INPUT = 2'd1;
parameter ENCODE = 2'd2;
parameter OUTPUT = 2'd3;
integer i;
// ===============================================================
// Reg & Wire Declaration
// ===============================================================
reg [4:0] Weight [0:15]; 
reg [1:0] c_state, n_state;
reg [2:0] cnt_tree; // count to tree
reg [4:0] cnt_8;
reg [31:0] sort_in_tmp;
reg mode;
wire [39:0] sort_weight_in;
wire [31:0] sort_out_tmp;
wire [7:0] character;
reg [6:0] huffman [0:7];
reg [2:0] tree [0:7];
reg [7:0] subtree_char [0:15];
reg [3:0] subtree_num;
reg [2:0] out_char; // which character 
reg [2:0] out_count; // 0 1 2 3 4

assign sort_weight_in = {Weight[sort_in_tmp[31:28]],Weight[sort_in_tmp[27:24]],Weight[sort_in_tmp[23:20]],Weight[sort_in_tmp[19:16]]
                        ,Weight[sort_in_tmp[15:12]],Weight[sort_in_tmp[11:8]],Weight[sort_in_tmp[7:4]],Weight[sort_in_tmp[3:0]]};

assign character = subtree_char[sort_out_tmp[7:4]] | subtree_char[sort_out_tmp[3:0]];                        
// ===============================================================
// Design
// ===============================================================
SORT_IP #(.IP_WIDTH(8)) sort_8 (.IN_character(sort_in_tmp),.IN_weight(sort_weight_in),.OUT_character(sort_out_tmp));



// ===============================================================
// FSM
// ===============================================================
always @(posedge clk or negedge rst_n) begin //c_state
    if (!rst_n) begin
        c_state <= IDLE;
    end else begin
        c_state <= n_state;
    end
end

always @(*) begin //n_state
    case (c_state)
        IDLE: begin
            if (in_valid) begin
                n_state = INPUT;
            end else begin
                n_state = c_state;
            end
        end 
        INPUT: begin
            if (cnt_8 == 5'd7) begin
                n_state = ENCODE;
            end else begin
                n_state = c_state;
            end
        end 
        ENCODE:begin
            if (cnt_8 == 5'd6) begin
                n_state = OUTPUT;
            end else begin
                n_state = c_state;
            end
        end
        OUTPUT:begin
            if (cnt_tree == tree[out_char] -1'b1 && out_count == 3'd4) begin
                n_state = IDLE;
            end else begin
                n_state = c_state;
            end
        end
        default: n_state = c_state;
    endcase
end

// ===============================================================
// registers
// ===============================================================
always @(posedge clk or negedge rst_n) begin // Weight
    if (!rst_n) begin
        Weight[15] <= 5'd31;
        for (i = 0;i < 15 ;i = i+1 ) begin
            Weight[i] <= 5'd0;
        end
    end else begin
        case (c_state)
            IDLE: begin
                if (in_valid)
                    Weight[14]  <=  in_weight;
            end
            INPUT: begin
                case (cnt_8)
                    0:begin Weight[14]   <=  in_weight; end 
                    1:begin Weight[13]   <=  in_weight; end 
                    2:begin Weight[12]   <=  in_weight; end 
                    3:begin Weight[11]   <=  in_weight; end 
                    4:begin Weight[10]   <=  in_weight; end 
                    5:begin Weight[9]    <=  in_weight; end 
                    6:begin Weight[8]    <=  in_weight; end  
                    7:begin Weight[7]    <=  in_weight; end 
                    default: Weight[0] <= Weight[0];
                endcase
            end
            ENCODE:begin
                case (cnt_8)
                    0,1,2,3,4,5,6: begin Weight[subtree_num] <= Weight[sort_out_tmp[7:4]] + Weight[sort_out_tmp[3:0]]; end 
                    default: begin end
                endcase
            end
            default: Weight[0] <= Weight[0];
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin // sort_in_tmp
    if (!rst_n) begin
        sort_in_tmp <= 32'b0;
    end else begin
        case (c_state)
            IDLE: begin
                sort_in_tmp <= {4'd14,4'd13,4'd12,4'd11,4'd10,4'd9,4'd8,4'd7};
            end
            ENCODE:begin
                case (cnt_8)
                    0,1,2,3,4,5,6: begin
                        sort_in_tmp <= {4'd15,sort_out_tmp[31:8],subtree_num};
                    end
                    default: sort_in_tmp <= sort_in_tmp;
                endcase
            end
            default: sort_in_tmp <= sort_in_tmp;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin // mode
    if (!rst_n) begin
        mode <= 1'b0;
    end else begin
        if (c_state == IDLE && c_state != n_state)
            mode <= out_mode;
        else
            mode <= mode;    
    end
end

always @(*) begin // out_char
    case ({mode,out_count})
        4'b0000: begin out_char = 3'd3;  end
        4'b0001: begin out_char = 3'd2;  end
        4'b0010: begin out_char = 3'd1;  end
        4'b0011: begin out_char = 3'd0;  end
        4'b0100: begin out_char = 3'd4;  end
        4'b1000: begin out_char = 3'd3;  end
        4'b1001: begin out_char = 3'd5;  end
        4'b1010: begin out_char = 3'd2;  end
        4'b1011: begin out_char = 3'd7;  end
        4'b1100: begin out_char = 3'd6;  end
        default: begin out_char = 3'd0;  end
    endcase
end

// ===============================================================
// count
// ===============================================================
always @(posedge clk or negedge rst_n) begin //cnt_8
    if (!rst_n) begin
        cnt_8 <= 3'd0;
    end else begin
        case (c_state)
            IDLE: begin
                if (in_valid)
                    cnt_8 <= cnt_8 + 1'b1;
                else 
                    cnt_8 <= 3'd0;    
            end
            INPUT: begin 
                if (c_state != n_state)
                    cnt_8 <= 3'd0;
                else
                    cnt_8 <= cnt_8 + 1'b1;    
            end
            ENCODE: begin
               if (cnt_8 == 5'd7) begin
                    cnt_8 <= 5'd0;
               end else begin
                    cnt_8 <= cnt_8 + 1'b1; 
               end      
            end
            OUTPUT: begin 
                cnt_8 <= cnt_8 + 1'b1; 
            end    
            default: cnt_8 <= 3'd0;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin //cnt_tree
    if (!rst_n) begin
        cnt_tree <= 3'd0;
    end else begin
        case (c_state)
            OUTPUT: begin 
                if (cnt_tree == tree[out_char] -1'b1) begin
                    cnt_tree <= 3'd0;
                end else begin
                    cnt_tree <= cnt_tree + 1'b1;
                end 
            end    
            default: cnt_tree <= 3'd0;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin //out_count
    if (!rst_n) begin
        out_count <= 3'd0;
    end else begin
        case (c_state)
            OUTPUT: begin 
                if(cnt_tree == tree[out_char] -1'b1)
                    out_count <= out_count + 1'b1; 
                else 
                    out_count <= out_count;    
            end    
            default: out_count <= 3'd0;
        endcase
    end
end

// ===============================================================
// control
// ===============================================================
always @(posedge clk or negedge rst_n) begin // huffman
    if (!rst_n) begin
        for (i = 0;i < 8 ;i = i + 1 ) begin
            huffman[i] <= 7'b0;
        end
    end else begin
        case (c_state)
            IDLE:begin
                for (i = 0;i < 8 ;i = i + 1 ) begin
                    huffman[i] <= 7'b0;
                end
            end
            ENCODE: begin
                case (cnt_8)
                    0,1,2,3,4,5,6: begin
                        if (subtree_char[sort_out_tmp[7:4]][7] == 1'b1)      begin  huffman[7] <= {huffman[7][5:0],1'b0}; end 
                        else if (subtree_char[sort_out_tmp[3:0]][7] == 1'b1) begin  huffman[7] <= {huffman[7][5:0],1'b1}; end
                        else begin huffman[7] <= huffman[7];end

                        if (subtree_char[sort_out_tmp[7:4]][6] == 1'b1)      begin  huffman[6] <= {huffman[6][5:0],1'b0}; end 
                        else if (subtree_char[sort_out_tmp[3:0]][6] == 1'b1) begin  huffman[6] <= {huffman[6][5:0],1'b1}; end
                        else begin huffman[6] <= huffman[6];end

                        if (subtree_char[sort_out_tmp[7:4]][5] == 1'b1)      begin  huffman[5] <= {huffman[5][5:0],1'b0}; end 
                        else if (subtree_char[sort_out_tmp[3:0]][5] == 1'b1) begin  huffman[5] <= {huffman[5][5:0],1'b1}; end
                        else begin huffman[5] <= huffman[5];end

                        if (subtree_char[sort_out_tmp[7:4]][4] == 1'b1)      begin  huffman[4] <= {huffman[4][5:0],1'b0}; end 
                        else if (subtree_char[sort_out_tmp[3:0]][4] == 1'b1) begin  huffman[4] <= {huffman[4][5:0],1'b1}; end
                        else begin huffman[4] <= huffman[4];end

                        if (subtree_char[sort_out_tmp[7:4]][3] == 1'b1)      begin  huffman[3] <= {huffman[3][5:0],1'b0}; end 
                        else if (subtree_char[sort_out_tmp[3:0]][3] == 1'b1) begin  huffman[3] <= {huffman[3][5:0],1'b1}; end
                        else begin huffman[3] <= huffman[3];end

                        if (subtree_char[sort_out_tmp[7:4]][2] == 1'b1)      begin  huffman[2] <= {huffman[2][5:0],1'b0}; end 
                        else if (subtree_char[sort_out_tmp[3:0]][2] == 1'b1) begin  huffman[2] <= {huffman[2][5:0],1'b1}; end
                        else begin huffman[2] <= huffman[2];end

                        if (subtree_char[sort_out_tmp[7:4]][1] == 1'b1)      begin  huffman[1] <= {huffman[1][5:0],1'b0}; end 
                        else if (subtree_char[sort_out_tmp[3:0]][1] == 1'b1) begin  huffman[1] <= {huffman[1][5:0],1'b1}; end
                        else begin huffman[1] <= huffman[1];end

                        if (subtree_char[sort_out_tmp[7:4]][0] == 1'b1)      begin  huffman[0] <= {huffman[0][5:0],1'b0}; end 
                        else if (subtree_char[sort_out_tmp[3:0]][0] == 1'b1) begin  huffman[0] <= {huffman[0][5:0],1'b1}; end
                        else begin huffman[0] <= huffman[0];end
                    end
                    default: begin end
                endcase
            end
            default: begin end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin // tree
    if (!rst_n) begin
        for (i = 0;i < 8 ;i = i + 1 ) begin
            tree[i] <= 3'b0;
        end
    end else begin
        case (c_state)
            IDLE:begin
                for (i = 0;i < 8 ;i = i + 1 ) begin
                    tree[i] <= 3'b0;
                end 
            end
            ENCODE: begin
                case (cnt_8)
                    0,1,2,3,4,5,6: begin
                        if (subtree_char[sort_out_tmp[7:4]][7] == 1'b1)      begin  tree[7] <= tree[7] + 1'b1; end 
                        else if (subtree_char[sort_out_tmp[3:0]][7] == 1'b1) begin  tree[7] <= tree[7] + 1'b1; end
                        else begin tree[7] <= tree[7];end

                        if (subtree_char[sort_out_tmp[7:4]][6] == 1'b1)      begin  tree[6] <= tree[6] + 1'b1; end 
                        else if (subtree_char[sort_out_tmp[3:0]][6] == 1'b1) begin  tree[6] <= tree[6] + 1'b1; end
                        else begin tree[6] <= tree[6];end

                        if (subtree_char[sort_out_tmp[7:4]][5] == 1'b1)      begin  tree[5] <= tree[5] + 1'b1; end 
                        else if (subtree_char[sort_out_tmp[3:0]][5] == 1'b1) begin  tree[5] <= tree[5] + 1'b1; end
                        else begin tree[5] <= tree[5];end

                        if (subtree_char[sort_out_tmp[7:4]][4] == 1'b1)      begin  tree[4] <= tree[4] + 1'b1; end 
                        else if (subtree_char[sort_out_tmp[3:0]][4] == 1'b1) begin  tree[4] <= tree[4] + 1'b1; end
                        else begin tree[4] <= tree[4];end

                        if (subtree_char[sort_out_tmp[7:4]][3] == 1'b1)      begin  tree[3] <= tree[3] + 1'b1; end 
                        else if (subtree_char[sort_out_tmp[3:0]][3] == 1'b1) begin  tree[3] <= tree[3] + 1'b1; end
                        else begin tree[3] <= tree[3];end

                        if (subtree_char[sort_out_tmp[7:4]][2] == 1'b1)      begin  tree[2] <= tree[2] + 1'b1; end 
                        else if (subtree_char[sort_out_tmp[3:0]][2] == 1'b1) begin  tree[2] <= tree[2] + 1'b1; end
                        else begin tree[2] <= tree[2];end

                        if (subtree_char[sort_out_tmp[7:4]][1] == 1'b1)      begin  tree[1] <= tree[1] + 1'b1; end 
                        else if (subtree_char[sort_out_tmp[3:0]][1] == 1'b1) begin  tree[1] <= tree[1] + 1'b1; end
                        else begin tree[1] <= tree[1];end

                        if (subtree_char[sort_out_tmp[7:4]][0] == 1'b1)      begin  tree[0] <= tree[0] + 1'b1; end 
                        else if (subtree_char[sort_out_tmp[3:0]][0] == 1'b1) begin  tree[0] <= tree[0] + 1'b1; end
                        else begin tree[0] <= tree[0];end
                    end
                    default: begin end
                endcase
            end
            default: begin end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin // subtree_char
    if (!rst_n) begin
        subtree_char[15] <= 8'b0;
        subtree_char[14] <= 8'b1000_0000;
        subtree_char[13] <= 8'b0100_0000;
        subtree_char[12] <= 8'b0010_0000;
        subtree_char[11] <= 8'b0001_0000;
        subtree_char[10] <= 8'b0000_1000;
        subtree_char[9]  <= 8'b0000_0100;
        subtree_char[8]  <= 8'b0000_0010;
        subtree_char[7]  <= 8'b0000_0001;
        for (i = 0;i < 7 ;i = i + 1 ) begin
            subtree_char[i] <= 8'b0;
        end
    end else begin
        case (c_state)
            IDLE:begin
                subtree_char[15] <= 8'b0;
                subtree_char[14] <= 8'b1000_0000;
                subtree_char[13] <= 8'b0100_0000;
                subtree_char[12] <= 8'b0010_0000;
                subtree_char[11] <= 8'b0001_0000;
                subtree_char[10] <= 8'b0000_1000;
                subtree_char[9]  <= 8'b0000_0100;
                subtree_char[8]  <= 8'b0000_0010;
                subtree_char[7]  <= 8'b0000_0001;
                for (i = 0;i < 7 ;i = i + 1 ) begin
                    subtree_char[i] <= 8'b0;
                end
            end
            ENCODE: begin
                case (cnt_8)
                    0: begin subtree_char[6] <= character; end
                    1: begin subtree_char[5] <= character; end
                    2: begin subtree_char[4] <= character; end
                    3: begin subtree_char[3] <= character; end
                    4: begin subtree_char[2] <= character; end
                    5: begin subtree_char[1] <= character; end
                    6: begin subtree_char[0] <= character; end
                    default: begin end
                endcase
            end
            default: begin end
        endcase
    end
end


always @(*) begin //subtree_num
    case (c_state)
        ENCODE: begin
            case (cnt_8)
                0: subtree_num = 3'd6;
                1: subtree_num = 3'd5;
                2: subtree_num = 3'd4;
                3: subtree_num = 3'd3;
                4: subtree_num = 3'd2;
                5: subtree_num = 3'd1;
                6: subtree_num = 3'd0;
                default: subtree_num = 3'd0;
            endcase
        end
        default: subtree_num = 3'd0;
    endcase
end
// ===============================================================
// Output
// ===============================================================
always @(*) begin // out_valid
    if (!rst_n) begin
        out_valid = 1'b0;
    end else begin
        if (c_state == OUTPUT) begin
            out_valid = 1'b1;
        end else begin
            out_valid = 1'b0;
        end
        
    end
end

always @(*) begin // out_code
    if (!rst_n) begin
        out_code = 1'b0;
    end else begin
        if (c_state == OUTPUT) begin
            out_code = huffman[out_char][cnt_tree];
        end else begin
            out_code = 1'b0;
        end
    end
end


endmodule
//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2023/10
//		Version		: v1.0
//   	File Name   : SORT_IP.v
//   	Module Name : SORT_IP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
module SORT_IP #(parameter IP_WIDTH = 8) (
    // Input signals
    IN_character, IN_weight,
    // Output signals
    OUT_character
);

// ===============================================================
// Input & Output
// ===============================================================
input [IP_WIDTH*4-1:0]  IN_character;
input [IP_WIDTH*5-1:0]  IN_weight;

output reg [IP_WIDTH*4-1:0] OUT_character;

reg [8:0] ch_wei [0:7];

//integer i,j,k;
// ===============================================================
// Design
// ===============================================================
integer i,j,k;
generate
    always @(*) begin
        for (k = IP_WIDTH - 1;k >= 0;k = k - 1 ) begin 
                ch_wei[IP_WIDTH - 1 - k] = {IN_character[4*k+:4],IN_weight[5*k+:5]};
        end

        for (i = 0 ; i < IP_WIDTH - 1 ; i = i + 1 ) begin 
            for (j = i ; j >= 0 ; j = j - 1 ) begin 
                if (ch_wei[j][4:0] < ch_wei[j+1][4:0]) begin
                    {ch_wei[j],ch_wei[j+1]} = {ch_wei[j+1],ch_wei[j]};
                end
                // else if (ch_wei[j][4:0] == ch_wei[j+1][4:0])begin
                //     if (ch_wei[j][8:5] < ch_wei[j+1][8:5]) begin
                //         {ch_wei[j],ch_wei[j+1]} = {ch_wei[j+1],ch_wei[j]};
                //     end
                // end
            end
        end
    end
endgenerate

always @(*) begin
    case (IP_WIDTH)
        3: OUT_character = {ch_wei[0][8:5],ch_wei[1][8:5],ch_wei[2][8:5]};
        4: OUT_character = {ch_wei[0][8:5],ch_wei[1][8:5],ch_wei[2][8:5],ch_wei[3][8:5]};
        5: OUT_character = {ch_wei[0][8:5],ch_wei[1][8:5],ch_wei[2][8:5],ch_wei[3][8:5],ch_wei[4][8:5]};
        6: OUT_character = {ch_wei[0][8:5],ch_wei[1][8:5],ch_wei[2][8:5],ch_wei[3][8:5],ch_wei[4][8:5],ch_wei[5][8:5]};
        7: OUT_character = {ch_wei[0][8:5],ch_wei[1][8:5],ch_wei[2][8:5],ch_wei[3][8:5],ch_wei[4][8:5],ch_wei[5][8:5],ch_wei[6][8:5]};
        8: OUT_character = {ch_wei[0][8:5],ch_wei[1][8:5],ch_wei[2][8:5],ch_wei[3][8:5],ch_wei[4][8:5],ch_wei[5][8:5],ch_wei[6][8:5],ch_wei[7][8:5]};
        default: OUT_character = 'b0;
    endcase
end





endmodule


//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2023 Fall
//   Lab04 Exercise		: Siamese Neural Network
//   Author     		: Jia-Yu Lee (maggie8905121@gmail.com)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : SNN.v
//   Module Name : SNN
//   Release version : V1.0 (Release Date: 2023-09)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

// synopsys translate_off
`ifdef RTL
	`include "GATED_OR.v"
`else
	`include "Netlist/GATED_OR_SYN.v"
`endif
// synopsys translate_on


module SNN(
         //Input Port
         clk,
         rst_n,
         cg_en,
         in_valid,
         Img,
         Kernel,
         Weight,
         Opt,


         //Output Port
         out_valid,
         out
       );


//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------

// FSM parameter
parameter STATE_BIT = 3;
parameter IDLE = 3'd0;
parameter CONVOLUTION = 3'd1;
parameter EQUALIZATION = 3'd2;
parameter POOLING = 3'd3;
parameter MATRIXMULT = 3'd4;
parameter NORMAL_ACTI = 3'd5;
parameter OUT = 3'd6;
// IEEE floating point parameter
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;
parameter inst_arch = 0;
parameter inst_faithful_round = 0;
integer i,j,k;
genvar a,b,c;

input rst_n, clk, in_valid, cg_en;
input [inst_sig_width+inst_exp_width:0] Img, Kernel, Weight;
input [1:0] Opt;

output reg	out_valid;
output reg [inst_sig_width+inst_exp_width:0] out;


//---------------------------------------------------------------------
//   reg or wire declaration
//---------------------------------------------------------------------
reg [STATE_BIT-1:0] c_state,n_state;
reg [31:0] img [0:5][0:5];
reg [31:0] kernel[0:2][0:2][0:2];
reg [31:0] weight[0:1][0:1];
reg [31:0] map[0:1][0:3][0:3];
reg [31:0] equal_map[0:1][0:3][0:3];
reg [31:0] max[0:3];
reg [31:0] max_pool[0:1][0:3];
reg [31:0] exp_up [0:7];
reg [31:0] exp_tmp2 [0:1][0:7];
reg [31:0] add_tmp[0:9];
reg [1:0] opt;
reg [31:0] dot_3_1_tmp,dot_3_2_tmp,dot_3_3_tmp;

reg [31:0] map_comb[0:1][0:3][0:3];

reg [31:0] add_1,add_2,add_3;
reg [5:0] x_y;
reg [3:0] x_y_map;
reg [3:0] x_y_in;
reg [1:0] ker_channel;
reg map_channel;
reg first;
reg [31:0] dot_a_in1,dot_b_in1,dot_c_in1,dot_d_in1,dot_e_in1,dot_f_in1;
reg [31:0] dot_a_in2,dot_b_in2,dot_c_in2,dot_d_in2,dot_e_in2,dot_f_in2;
reg [31:0] dot_a_in3,dot_b_in3,dot_c_in3,dot_d_in3,dot_e_in3,dot_f_in3;
reg [31:0] add_in1,add_in2,add_in3,add_in4,add_in5,add_in6;
reg [31:0] cmp_in1,cmp_in2,cmp_in3,cmp_in4,cmp_in5,cmp_in6,cmp_in7,cmp_in8;
reg [31:0] exp_in1,exp_in2,exp_out1,exp_out2;
reg [31:0] div_in1,div_in2,div_out1;


wire [31:0] cmp_out1,cmp_out2,cmp_out3,cmp_out4,cmp_out5,cmp_out6,cmp_out7,cmp_out8;
wire [31:0] dot_3_1_out,dot_3_2_out,dot_3_3_out;

wire [2:0] rnd;
assign rnd = 3'b0;

//---------------------------------------------------------------------
//   count declaration
//---------------------------------------------------------------------
reg [6:0] cnt_input;
reg [3:0] cnt_16;
reg [6:0] cnt_state;
reg [9:0] cnt_long;

//---------------------------------------------------------------------
//   IP module Output
//---------------------------------------------------------------------

DW_fp_dp3_inst dot1(.inst_a(dot_a_in1),.inst_b(dot_b_in1),
.inst_c(dot_c_in1),.inst_d(dot_d_in1),
.inst_e(dot_e_in1),.inst_f(dot_f_in1),.inst_rnd(rnd),
.z_inst(dot_3_1_out));

DW_fp_dp3_inst dot2(.inst_a(dot_a_in2),.inst_b(dot_b_in2),
.inst_c(dot_c_in2),.inst_d(dot_d_in2),
.inst_e(dot_e_in2),.inst_f(dot_f_in2),.inst_rnd(rnd),
.z_inst(dot_3_2_out));

DW_fp_dp3_inst dot3(.inst_a(dot_a_in3),.inst_b(dot_b_in3),
.inst_c(dot_c_in3),.inst_d(dot_d_in3),
.inst_e(dot_e_in3),.inst_f(dot_f_in3),.inst_rnd(rnd),
.z_inst(dot_3_3_out));


DW_fp_add_inst add1 ( .inst_a(add_in1), .inst_b(add_in2), .inst_rnd(rnd), .z_inst(add_1));
DW_fp_add_inst add2 ( .inst_a(add_in3), .inst_b(add_in4), .inst_rnd(rnd), .z_inst(add_2));
DW_fp_add_inst add3 ( .inst_a(add_in5), .inst_b(add_in6), .inst_rnd(rnd), .z_inst(add_3));

DW_fp_cmp_inst cmp1 ( .inst_a(cmp_in1), .inst_b(cmp_in2), .inst_zctr(1'b1), .z0_inst(cmp_out1), .z1_inst(cmp_out2));
DW_fp_cmp_inst cmp2 ( .inst_a(cmp_in3), .inst_b(cmp_in4), .inst_zctr(1'b1), .z0_inst(cmp_out3), .z1_inst(cmp_out4));
DW_fp_cmp_inst cmp3 ( .inst_a(cmp_in5), .inst_b(cmp_in6), .inst_zctr(1'b1), .z0_inst(cmp_out5), .z1_inst(cmp_out6));
DW_fp_cmp_inst cmp4 ( .inst_a(cmp_in7), .inst_b(cmp_in8), .inst_zctr(1'b1), .z0_inst(cmp_out7), .z1_inst(cmp_out8));

DW_fp_exp_inst exp1( .inst_a(exp_in1), .z_inst(exp_out1));
DW_fp_exp_inst exp2( .inst_a(exp_in2), .z_inst(exp_out2));

DW_fp_div_inst div1( .inst_a(div_in1), .inst_b(div_in2), .inst_rnd(rnd), .z_inst(div_out1));

//---------------------------------------------------------------------
//   Clock Gating
//---------------------------------------------------------------------
wire ctrl1, ctrl2, ctrl3, ctrl4, ctrl5, ctrl6;
assign ctrl1 = (c_state == IDLE) ? 1'b1 : 1'b0;
assign ctrl2 = (c_state == CONVOLUTION) ? 1'b1 : 1'b0;
assign ctrl3 = (c_state == EQUALIZATION) ? 1'b1 : 1'b0;
assign ctrl4 = (c_state == POOLING) ? 1'b1 : 1'b0;
assign ctrl5 = (c_state == MATRIXMULT) ? 1'b1 : 1'b0;
assign ctrl6 = (c_state == NORMAL_ACTI) ? 1'b1 : 1'b0;

 // Only in IDLE
wire G_clock_out;
wire G_sleep_input1 = cg_en && ~(ctrl1);
GATED_OR GATED_IDLE (
    .CLOCK( clk ),
    .RST_N(rst_n),
    .SLEEP_CTRL(G_sleep_input1), // gated clock
    .CLOCK_GATED( G_clock_out)
);

// In IDLE/CONVOLUTION
// wire G_clock_map_out;
// wire G_sleep_map = cg_en & ~(ctrl1 || ctrl2);
// GATED_OR GATED_MAP (
//     .CLOCK( clk ),
//     .RST_N(rst_n),
//     .SLEEP_CTRL(G_sleep_map), // gated clock
//     .CLOCK_GATED( G_clock_map_out)
// );

// In EQUALIZATION
// wire G_clock_equal_out;
// wire G_sleep_equal = cg_en & ~(ctrl3);
// GATED_OR GATED_EQUAL (
//     .CLOCK( clk ),
//     .RST_N(rst_n),
//     .SLEEP_CTRL(G_sleep_equal), // gated clock
//     .CLOCK_GATED( G_clock_equal_out)
// );

// In EQUALIZATION/POOLING/MAXTRIXMULT/NORMALIZE_ACTI
// wire G_clock_max_out;
// wire G_sleep_max = cg_en & ~(ctrl3 || ctrl4 || ctrl5 || ctrl6);
// GATED_OR GATED_MAX (
//     .CLOCK( clk ),
//     .RST_N(rst_n),
//     .SLEEP_CTRL(G_sleep_max), // gated clock
//     .CLOCK_GATED( G_clock_max_out)
// );

// In NORMALIZE_ACTI
// wire G_clock_cal_out;
// wire G_sleep_cal = cg_en & ~(ctrl6);
// GATED_OR GATED_CAL (
//     .CLOCK( clk ),
//     .RST_N(rst_n),
//     .SLEEP_CTRL(G_sleep_cal), // gated clock
//     .CLOCK_GATED( G_clock_cal_out)
// );

// In IDLE/CONVOLUTION/EQUALIZATION
wire G_clock_dot_out;
wire G_sleep_dot = cg_en && ~(ctrl1 || ctrl2 || ctrl3);
GATED_OR GATED_DOT (
    .CLOCK( clk ),
    .RST_N(rst_n),
    .SLEEP_CTRL(G_sleep_dot), // gated clock
    .CLOCK_GATED( G_clock_dot_out)
);



//---------------------------------------------------------------------
//   FSM
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    c_state <= IDLE;
  end else begin
    c_state <= n_state;
  end
end

always @(*) begin
    case (c_state)
      IDLE:begin
        if (cnt_input == 7'd95) begin
          n_state = CONVOLUTION;
        end
        else begin
          n_state = c_state;
        end
      end 
      CONVOLUTION:begin
        if (cnt_input == 7'd105) begin
          n_state = EQUALIZATION;
        end
        else begin
          n_state = c_state;
        end
      end
      EQUALIZATION:begin
        if (cnt_state == 7'd32) begin
          n_state = POOLING;
        end else begin
          n_state = c_state;
        end
      end
      POOLING:begin
        if (cnt_state == 7'd0) begin
          n_state = MATRIXMULT;
        end else begin
          n_state = c_state;
        end
      end
      MATRIXMULT:begin
        if (cnt_state == 7'd2) begin
          n_state = NORMAL_ACTI;
        end else begin
          n_state = c_state;
        end  
      end
      NORMAL_ACTI:begin
        if (cnt_state == 7'd17) begin
          n_state = OUT;
        end else begin
          n_state = c_state;
        end
      end
      OUT:begin
        if (cnt_long == 10'd934) begin
          n_state = IDLE;
        end else begin
          n_state = c_state;
        end
      end
      default: begin
        n_state = c_state;
      end
    endcase
end



//---------------------------------------------------------------------
//   img / kernel / weight / opt / feature map / max / max_pool / upside / exp_up
//---------------------------------------------------------------------

// Only in IDLE
wire G_clock_input_out[0:11];
reg G_sleep_input[0:11];
wire G_clock_ker_out[0:2][0:2][0:2];
wire G_clock_wei_out[0:1][0:1];
wire G_clock_map_out[0:1][0:3][0:3];
wire G_clock_equal_out[0:1][0:3][0:3];
wire G_clock_max_out[0:1];
wire G_clock_maxpool_out[0:3];
wire G_clock_expup_out[0:7];
wire G_clock_exptmp_out[0:7];
wire G_clock_add_out[0:9];

always @(*) begin // G_clock_input_out
     for (j = 0; j<12 ;j = j +1) begin
        G_sleep_input[j] = cg_en && ~(ctrl1);
     end
end

generate 
    for (a = 0;a<12;a = a + 1) begin 
        GATED_OR IMGG (.CLOCK(clk), .SLEEP_CTRL(G_sleep_input[a]), .RST_N(rst_n), .CLOCK_GATED(G_clock_input_out[a]));
    end
endgenerate


always @(posedge G_clock_input_out[0] or negedge rst_n) // img[0][0] ~ img[0][2]
  begin
    if (!rst_n)
      begin
        img[0][0] <= 32'b0;
        img[0][1] <= 32'b0;
        img[0][2] <= 32'b0;
      end
    else if (ctrl1)
      begin
            if (in_valid) begin
              case (cnt_input)
                0:                 begin img[0][0] <= (Opt[0]) ? 32'b0 : Img ; img[0][1] <= (Opt[0]) ? 32'b0 : Img ; end
                16,32,48,64,80:    begin img[0][0] <= (opt[0]) ? 32'b0 : Img ; img[0][1] <= (opt[0]) ? 32'b0 : Img ; end 
                1,17,33,49,65,81:  begin img[0][2] <= (opt[0]) ? 32'b0 : Img ; end 
                default: begin end
              endcase
            end
      end
  end

always @(posedge G_clock_input_out[1] or negedge rst_n) // img[0][3] ~ img[0][5]
  begin
    if (!rst_n)
      begin
        img[0][3] <= 32'b0;
        img[0][4] <= 32'b0;
        img[0][5] <= 32'b0;
      end
    else if (ctrl1)
      begin
            if (in_valid) begin
              case (cnt_input)
               2,18,34,50,66,82:  begin img[0][3] <= (opt[0]) ? 32'b0 : Img ; end 
               3,19,35,51,67,83:  begin img[0][4] <= (opt[0]) ? 32'b0 : Img ; img[0][5] <= (opt[0]) ? 32'b0 : Img ; end  
               default: begin end
              endcase
            end
      end
  end

always @(posedge G_clock_input_out[2] or negedge rst_n) // img[1][0] ~ img[1][2]
  begin
    if (!rst_n)
      begin
        img[1][0] <= 32'b0;
        img[1][1] <= 32'b0;
        img[1][2] <= 32'b0;
      end
    else if (ctrl1)
      begin
            if (in_valid) begin
              case (cnt_input)
                0: begin img[1][1] <= Img;  img[1][0] <= (Opt[0]) ? 32'b0 : Img ; end
                16,32,48,64,80:    begin img[1][1] <= Img;  img[1][0] <= (opt[0]) ? 32'b0 : Img ;end //
                1,17,33,49,65,81:  begin img[1][2] <= Img;  end 
                default: begin end
              endcase  
            end
      end
  end

always @(posedge G_clock_input_out[3] or negedge rst_n) // img[1][3] ~ img[1][5]
  begin
    if (!rst_n)
      begin
        img[1][3] <= 32'b0;
        img[1][4] <= 32'b0;
        img[1][5] <= 32'b0;
      end
    else if (ctrl1)
      begin
            if (in_valid) begin
              case (cnt_input)
                2,18,34,50,66,82:  begin img[1][3] <= Img; end 
                3,19,35,51,67,83:  begin img[1][4] <= Img; img[1][5] <= (opt[0]) ? 32'b0 : Img ;end 
                default: begin end
              endcase
            end
      end
  end

always @(posedge G_clock_input_out[4] or negedge rst_n) // img[2][0] ~ img[2][2]
  begin
    if (!rst_n)
      begin
        img[2][0] <= 32'b0;
        img[2][1] <= 32'b0;
        img[2][2] <= 32'b0;
      end
    else if (ctrl1)
      begin
            if (in_valid) begin
              case (cnt_input)
                4,20,36,52,68,84:  begin img[2][1] <= Img; img[2][0] <= (opt[0]) ? 32'b0 : Img ; end 
                5,21,37,53,69,85:  begin img[2][2] <= Img; end
                default: begin end
              endcase
            end
      end
  end

always @(posedge G_clock_input_out[5] or negedge rst_n) // img[2][3] ~ img[2][5]
  begin
    if (!rst_n)
      begin
        img[2][3] <= 32'b0;
        img[2][4] <= 32'b0;
        img[2][5] <= 32'b0;
      end
    else if (ctrl1)
      begin
            if (in_valid) begin
            case (cnt_input)
                6,22,38,54,70,86:  begin img[2][3] <= Img; end
                7,23,39,55,71,87:  begin img[2][4] <= Img; img[2][5] <= (opt[0]) ? 32'b0 : Img ; end 
                default: begin end
              endcase
            end
      end
  end

always @(posedge G_clock_input_out[6] or negedge rst_n) // img[3][0] ~ img[3][2]
  begin
    if (!rst_n)
      begin
        img[3][0] <= 32'b0;
        img[3][1] <= 32'b0;
        img[3][2] <= 32'b0;
      end
    else if (ctrl1)
      begin
            if (in_valid) begin
            case (cnt_input)
                8,24,40,56,72,88:  begin img[3][1] <= Img; img[3][0] <= (opt[0]) ? 32'b0 : Img ; end 
                9,25,41,57,73,89:  begin img[3][2] <= Img; end
                default: begin end
            endcase
            end
      end
  end  

always @(posedge G_clock_input_out[7] or negedge rst_n) // img[3][3] ~ img[3][5]
  begin
    if (!rst_n)
      begin
        img[3][3] <= 32'b0;
        img[3][4] <= 32'b0;
        img[3][5] <= 32'b0;
      end
    else if (ctrl1)
      begin
            if (in_valid) begin
              case (cnt_input)
                10,26,42,58,74,90: begin img[3][3] <= Img; end
                11,27,43,59,75,91: begin img[3][4] <= Img; img[3][5] <= (opt[0]) ? 32'b0 : Img ; end 
                default: begin end
              endcase
            end
      end
  end    

always @(posedge G_clock_input_out[8] or negedge rst_n) // img[4][0] ~ img[4][2]
  begin
    if (!rst_n)
      begin
        img[4][0] <= 32'b0;
        img[4][1] <= 32'b0;
        img[4][2] <= 32'b0;
      end
    else if (ctrl1)
      begin
            if (in_valid) begin
              case (cnt_input)
                12,28,44,60,76,92: begin img[4][1] <= Img; img[4][0] <= (opt[0]) ? 32'b0 : Img ; end 
                13,29,45,61,77,93: begin img[4][2] <= Img; end 
                default: begin end
              endcase
            end
      end
  end    

always @(posedge G_clock_input_out[9] or negedge rst_n) // img[4][3] ~ img[4][5]
  begin
    if (!rst_n)
      begin
        img[4][3] <= 32'b0;
        img[4][4] <= 32'b0;
        img[4][5] <= 32'b0;
      end
    else if (ctrl1)
      begin
            if (in_valid) begin
              case (cnt_input)
                14,30,46,62,78,94: begin img[4][3] <= Img; end 
                15,31,47,63,79,95: begin img[4][4] <= Img; img[4][5] <= (opt[0]) ? 32'b0 : Img ;end //
                default: begin end
              endcase
            end
      end
  end    

always @(posedge G_clock_input_out[10] or negedge rst_n) // img[5][0] ~ img[5][2]
  begin
    if (!rst_n)
      begin
        img[5][0] <= 32'b0;
        img[5][1] <= 32'b0;
        img[5][2] <= 32'b0;
      end
    else if (ctrl1)
      begin
            if (in_valid) begin
              case (cnt_input)
                12,28,44,60,76,92: begin img[5][0] <= (opt[0]) ? 32'b0 : Img ; img[5][1] <= (opt[0]) ? 32'b0 : Img ;end //
                13,29,45,61,77,93: begin img[5][2] <= (opt[0]) ? 32'b0 : Img ; end 
                default: begin end
              endcase
            end
      end
  end    

always @(posedge G_clock_input_out[11] or negedge rst_n) // img[5][3] ~ img[5][5]
  begin
    if (!rst_n)
      begin
        img[5][3] <= 32'b0;
        img[5][4] <= 32'b0;
        img[5][5] <= 32'b0;
      end
    else if (ctrl1)
      begin
            if (in_valid) begin
              case (cnt_input)
                14,30,46,62,78,94: begin img[5][3] <= (opt[0]) ? 32'b0 : Img ; end 
                15,31,47,63,79,95: begin img[5][4] <= (opt[0]) ? 32'b0 : Img ; img[5][5] <= (opt[0]) ? 32'b0 : Img ; end 
                default: begin end
              endcase
            end
      end
  end      


generate // kernel
    for (a = 0;a < 3;a = a +1) begin
        for (b = 0;b < 3;b = b +1) begin
            for (c = 0;c < 3;c = c +1) begin
                GATED_OR KER (.CLOCK(clk), .SLEEP_CTRL(cg_en & ~(ctrl1)), .RST_N(rst_n), .CLOCK_GATED(G_clock_ker_out[a][b][c]));
                always @(posedge G_clock_ker_out[a][b][c] or negedge rst_n) begin
                    if (!rst_n)  kernel[a][b][c] <= 32'b0;
                    else if (ctrl1) begin
                        if (cnt_input == (9*a + 3*b + c))
                            kernel[a][b][c] <= Kernel;
                    end
                end
            end
        end
    end
endgenerate



// always @(posedge G_clock_out or negedge rst_n) // kernel
//   begin
//     if (!rst_n)
//       begin
//         for (i = 0;i<3 ;i = i+1 ) begin
//           for (j = 0;j<3 ;j = j+1 ) begin
//             for (k = 0;k<3 ;k = k+1 ) begin
//               kernel[i][j][k] <= 32'b0;
//             end
//           end
//         end
//       end
//     else if (ctrl1)
//       begin
//         if (in_valid) begin
//           case (cnt_input)
//             5'd0: kernel[0][0][0] <= Kernel;
//             5'd1: kernel[0][0][1] <= Kernel;
//             5'd2: kernel[0][0][2] <= Kernel;
//             5'd3: kernel[0][1][0] <= Kernel;
//             5'd4: kernel[0][1][1] <= Kernel;
//             5'd5: kernel[0][1][2] <= Kernel;
//             5'd6: kernel[0][2][0] <= Kernel;
//             5'd7: kernel[0][2][1] <= Kernel;
//             5'd8: kernel[0][2][2] <= Kernel;
//             5'd9: kernel[1][0][0] <= Kernel;
//             5'd10: kernel[1][0][1] <= Kernel;
//             5'd11: kernel[1][0][2] <= Kernel;
//             5'd12: kernel[1][1][0] <= Kernel;
//             5'd13: kernel[1][1][1] <= Kernel;
//             5'd14: kernel[1][1][2] <= Kernel;
//             5'd15: kernel[1][2][0] <= Kernel;
//             5'd16: kernel[1][2][1] <= Kernel;
//             5'd17: kernel[1][2][2] <= Kernel;
//             5'd18: kernel[2][0][0] <= Kernel;
//             5'd19: kernel[2][0][1] <= Kernel;
//             5'd20: kernel[2][0][2] <= Kernel;
//             5'd21: kernel[2][1][0] <= Kernel;
//             5'd22: kernel[2][1][1] <= Kernel;
//             5'd23: kernel[2][1][2] <= Kernel;
//             5'd24: kernel[2][2][0] <= Kernel;
//             5'd25: kernel[2][2][1] <= Kernel;
//             5'd26: kernel[2][2][2] <= Kernel;
//             default: begin  end
//           endcase
//         end
//       end
//   end

generate // weight
    for (a = 0;a < 2;a = a +1) begin
        for (b = 0;b < 2;b = b +1) begin
            GATED_OR WEI (.CLOCK(clk), .SLEEP_CTRL(cg_en && ~(ctrl1)), .RST_N(rst_n), .CLOCK_GATED(G_clock_wei_out[a][b]));
            always @(posedge G_clock_wei_out[a][b] or negedge rst_n) begin
                if (!rst_n)  weight[a][b] <= 32'b0;
                else if (ctrl1) begin
                    if (cnt_input == (2*a + b))
                        weight[a][b] <= Weight;
                end
            end
        end
    end
endgenerate


// always @(posedge G_clock_out or negedge rst_n) // weight
//   begin
//     if (!rst_n)
//       begin
//         weight[0][0] <= 32'b0;
//         weight[0][1] <= 32'b0;
//         weight[1][0] <= 32'b0;
//         weight[1][1] <= 32'b0;
//       end
//     else if (ctrl1)
//       begin
//         if (in_valid) begin
//           case (cnt_input)
//             2'd0: weight[0][0] <= Weight;
//             2'd1: weight[0][1] <= Weight;
//             2'd2: weight[1][0] <= Weight;
//             2'd3: weight[1][1] <= Weight;
//             default: begin end
//           endcase
//         end 
//       end
//   end

always @(posedge G_clock_out or negedge rst_n) // opt
  begin
    if (!rst_n)
      begin
        opt <= 2'd0;
      end
    else if (ctrl1)
      begin
        if (cnt_input == 0) begin
          opt <= Opt;
        end 
      end 
  end  


// generate //map
//         for (b = 0;b < 4;b = b +1) begin
//             for (c = 0;c < 4;c = c +1) begin
//                 GATED_OR MAP_0 (.CLOCK(clk), .SLEEP_CTRL(cg_en && ~(ctrl1 || ctrl2)), .RST_N(rst_n), .CLOCK_GATED(G_clock_map_out[0][b][c]));
//                 always @(posedge G_clock_map_out[0][b][c] or negedge rst_n) begin
//                     if (!rst_n)  map[0][b][c] <= 32'b0;
//                     else if (ctrl1 || ctrl2) begin
//                         if (cnt_input > 9) begin
//                             if (cnt_input == (4*b + c + 10) || cnt_input == (4*b + c + 26) || cnt_input == (4*b + c + 42))
//                                 map[0][b][c] <= add_3;
//                         end        
//                         else begin
//                             map[0][b][c] <= 32'b0;
//                         end
//                     end
//                 end
//             end
//         end
// endgenerate

// generate //map
//         for (b = 0;b < 4;b = b +1) begin
//             for (c = 0;c < 4;c = c +1) begin
//                 GATED_OR MAP_1 (.CLOCK(clk), .SLEEP_CTRL(cg_en && ~(ctrl1 || ctrl2)), .RST_N(rst_n), .CLOCK_GATED(G_clock_map_out[1][b][c]));
//                 always @(posedge G_clock_map_out[1][b][c] or negedge rst_n) begin
//                     if (!rst_n)  map[1][b][c] <= 32'b0;
//                     else if (ctrl1 || ctrl2) begin
//                         if (cnt_input > 9) begin
//                             if (cnt_input == (4*b + c + 58) || cnt_input == (4*b + c + 74) || cnt_input == (4*b + c + 90))
//                                 map[1][b][c] <= add_3;
//                         end
//                         else begin
//                             map[1][b][c] <= 32'b0;
//                         end        

//                     end
//                 end
//             end
//         end
// endgenerate

generate //map
    for (a = 0;a < 2;a = a +1) begin
        for (b = 0;b < 4;b = b +1) begin
            for (c = 0;c < 4;c = c +1) begin
                GATED_OR MAP_1 (.CLOCK(clk), .SLEEP_CTRL(cg_en && ~(ctrl1 || ctrl2)), .RST_N(rst_n), .CLOCK_GATED(G_clock_map_out[a][b][c]));
                always @(posedge G_clock_map_out[a][b][c] or negedge rst_n) begin
                    if (!rst_n)  map[a][b][c] <= 32'b0;
                    else if (ctrl1 || ctrl2) begin
                        map[a][b][c] <= map_comb[a][b][c];
                    end

                end
            end
        end
    end
endgenerate


always @(*) begin //map_comb
    begin
        if (ctrl1 || ctrl2) begin
          if (cnt_input > 7'd9) begin
                for (i = 0; i<4 ; i = i+1 ) begin
                    for (j = 0; j<4 ; j = j+1 ) begin
                        map_comb[0][i][j] = map[0][i][j];
                        map_comb[1][i][j] = map[1][i][j];
                    end
                end
                map_comb[map_channel][x_y_map[3:2]][x_y_map[1:0]] = add_3;
          end      
          else begin
            for (i = 0; i<4 ; i = i+1 ) begin
                for (j = 0; j<4 ; j = j+1 ) begin
                    map_comb[0][i][j] = 32'b0;
                    map_comb[1][i][j] = 32'b0;
                end
            end
          end  
        end  
        else begin
            for (i = 0; i<4 ; i = i+1 ) begin
                for (j = 0; j<4 ; j = j+1 ) begin
                    map_comb[0][i][j] = map[0][i][j];
                    map_comb[1][i][j] = map[1][i][j];
                end
            end
        end
    end
end


// always @(posedge G_clock_map_out or negedge rst_n) begin //map
//   if (!rst_n) begin
//     for (i = 0; i<4 ; i = i+1 ) begin
//       for (j = 0; j<4 ; j = j+1 ) begin
//           map[0][i][j] <= 32'b0;
//           map[1][i][j] <= 32'b0;
//       end
//     end
//   end 
//   else if (ctrl1 || ctrl2)
//     begin
//       if (cnt_input > 7'd9)
//         map[map_channel][x_y_map[3:2]][x_y_map[1:0]] <= add_3;
//       else begin
//         for (i = 0; i<4 ; i = i+1 ) begin
//             for (j = 0; j<4 ; j = j+1 ) begin
//                 map[0][i][j] <= 32'b0;
//                 map[1][i][j] <= 32'b0;
//             end
//         end
//       end  
//     end  
// end



generate //equal_map
    for (a = 0;a < 2;a = a +1) begin
        for (b = 0;b < 4;b = b +1) begin
            for (c = 0;c < 4;c = c +1) begin
                GATED_OR EQUAL (.CLOCK(clk), .SLEEP_CTRL(cg_en && ~(ctrl3)), .RST_N(rst_n), .CLOCK_GATED(G_clock_equal_out[a][b][c]));
                always @(posedge G_clock_equal_out[a][b][c] or negedge rst_n) begin
                    if (!rst_n)  equal_map[a][b][c] <= 32'b0;
                    else if (ctrl3) begin
                        if (cnt_state == (16*a + 4*b + c + 1'b1))
                            equal_map[a][b][c] <= div_out1;
                    end
                end
            end
        end
    end
endgenerate

// always @(posedge G_clock_equal_out or negedge rst_n) begin // equal_map
//   if (!rst_n) begin
//     for (i = 0; i<4 ; i = i+1 ) begin
//       for (j = 0; j<4 ; j = j+1 ) begin
//           equal_map[0][i][j] <= 32'b0;
//           equal_map[1][i][j] <= 32'b0;
//       end
//     end
//   end 
//   else if (ctrl3)
//     begin
//           case (cnt_state)
//             1: begin   equal_map[0][0][0] <= div_out1; end
//             2: begin   equal_map[0][0][1] <= div_out1; end
//             3: begin   equal_map[0][0][2] <= div_out1; end
//             4: begin   equal_map[0][0][3] <= div_out1; end
//             5: begin   equal_map[0][1][0] <= div_out1; end
//             6: begin   equal_map[0][1][1] <= div_out1; end
//             7: begin   equal_map[0][1][2] <= div_out1; end
//             8: begin   equal_map[0][1][3] <= div_out1; end
//             9: begin   equal_map[0][2][0] <= div_out1; end
//             10: begin  equal_map[0][2][1] <= div_out1; end
//             11: begin  equal_map[0][2][2] <= div_out1; end
//             12: begin  equal_map[0][2][3] <= div_out1; end
//             13: begin  equal_map[0][3][0] <= div_out1; end
//             14: begin  equal_map[0][3][1] <= div_out1; end
//             15: begin  equal_map[0][3][2] <= div_out1; end
//             16: begin  equal_map[0][3][3] <= div_out1; end
//             17: begin  equal_map[1][0][0] <= div_out1; end
//             18: begin  equal_map[1][0][1] <= div_out1; end
//             19: begin  equal_map[1][0][2] <= div_out1; end
//             20: begin  equal_map[1][0][3] <= div_out1; end
//             21: begin  equal_map[1][1][0] <= div_out1; end
//             22: begin  equal_map[1][1][1] <= div_out1; end
//             23: begin  equal_map[1][1][2] <= div_out1; end
//             24: begin  equal_map[1][1][3] <= div_out1; end
//             25: begin  equal_map[1][2][0] <= div_out1; end
//             26: begin  equal_map[1][2][1] <= div_out1; end
//             27: begin  equal_map[1][2][2] <= div_out1; end
//             28: begin  equal_map[1][2][3] <= div_out1; end
//             29: begin  equal_map[1][3][0] <= div_out1; end
//             30: begin  equal_map[1][3][1] <= div_out1; end
//             31: begin  equal_map[1][3][2] <= div_out1; end
//             32: begin  equal_map[1][3][3] <= div_out1; end
//           endcase
//   end
// end

// always @(posedge clk or negedge rst_n) begin // equal_map
//   if (!rst_n) begin
//     for (i = 0; i<4 ; i = i+1 ) begin
//       for (j = 0; j<4 ; j = j+1 ) begin
//           equal_map[0][i][j] <= 32'b0;
//           equal_map[1][i][j] <= 32'b0;
//       end
//     end
//   end 
//   else begin
//     case (c_state)
//       EQUALIZATION:begin
//           case (cnt_state)
//             1: begin   equal_map[0][0][0] <= div_out1; end
//             2: begin   equal_map[0][0][1] <= div_out1; end
//             3: begin   equal_map[0][0][2] <= div_out1; end
//             4: begin   equal_map[0][0][3] <= div_out1; end
//             5: begin   equal_map[0][1][0] <= div_out1; end
//             6: begin   equal_map[0][1][1] <= div_out1; end
//             7: begin   equal_map[0][1][2] <= div_out1; end
//             8: begin   equal_map[0][1][3] <= div_out1; end
//             9: begin   equal_map[0][2][0] <= div_out1; end
//             10: begin  equal_map[0][2][1] <= div_out1; end
//             11: begin  equal_map[0][2][2] <= div_out1; end
//             12: begin  equal_map[0][2][3] <= div_out1; end
//             13: begin  equal_map[0][3][0] <= div_out1; end
//             14: begin  equal_map[0][3][1] <= div_out1; end
//             15: begin  equal_map[0][3][2] <= div_out1; end
//             16: begin  equal_map[0][3][3] <= div_out1; end
//             17: begin  equal_map[1][0][0] <= div_out1; end
//             18: begin  equal_map[1][0][1] <= div_out1; end
//             19: begin  equal_map[1][0][2] <= div_out1; end
//             20: begin  equal_map[1][0][3] <= div_out1; end
//             21: begin  equal_map[1][1][0] <= div_out1; end
//             22: begin  equal_map[1][1][1] <= div_out1; end
//             23: begin  equal_map[1][1][2] <= div_out1; end
//             24: begin  equal_map[1][1][3] <= div_out1; end
//             25: begin  equal_map[1][2][0] <= div_out1; end
//             26: begin  equal_map[1][2][1] <= div_out1; end
//             27: begin  equal_map[1][2][2] <= div_out1; end
//             28: begin  equal_map[1][2][3] <= div_out1; end
//             29: begin  equal_map[1][3][0] <= div_out1; end
//             30: begin  equal_map[1][3][1] <= div_out1; end
//             31: begin  equal_map[1][3][2] <= div_out1; end
//             32: begin  equal_map[1][3][3] <= div_out1; end
//             default: begin
//               for (i = 0; i<4 ; i = i+1 ) begin
//                 for (j = 0; j<4 ; j = j+1 ) begin
//                     equal_map[0][i][j] <= equal_map[0][i][j];
//                     equal_map[1][i][j] <= equal_map[1][i][j];
//                 end
//               end 
//             end
//           endcase
//       end
//       default: begin
//           for (i = 0; i<4 ; i = i+1 ) begin
//             for (j = 0; j<4 ; j = j+1 ) begin
//                 equal_map[0][i][j] <= equal_map[0][i][j];
//                 equal_map[1][i][j] <= equal_map[1][i][j];
//             end
//           end 
//         end  
//     endcase
//   end
// end

//wire G_clock_max_out;
//wire G_sleep_max = cg_en && ~(ctrl3 || ctrl4 || ctrl5 || ctrl6);
GATED_OR MAX_1 (.CLOCK( clk ), .RST_N(rst_n),.SLEEP_CTRL(cg_en && ~(ctrl3 || ctrl4 || ctrl5 || ctrl6)), .CLOCK_GATED( G_clock_max_out[0]));
GATED_OR MAX_2 (.CLOCK( clk ), .RST_N(rst_n),.SLEEP_CTRL(cg_en && ~(ctrl3 || ctrl4 || ctrl5 || ctrl6)), .CLOCK_GATED( G_clock_max_out[1]));

always @(posedge G_clock_max_out[0] or negedge rst_n) begin //max[0] max[1]
  if (!rst_n) begin
      max[0] <= 32'b0;
      max[1] <= 32'b0;
    end
  else if (ctrl3)  begin
    case (cnt_state)
        7,9,15,17,23,25,31: begin max[0] <= cmp_out5; max[1] <= cmp_out6; end 
        default: begin end
    endcase
  end
  else if (ctrl4) begin
    case (cnt_state)
        7'd0: begin max[0] <= cmp_out5; max[1] <= cmp_out6; end 
        default: begin end
    endcase
  end
  else if (ctrl5) begin
    if (cnt_state == 7'd0) begin
      max[1] <= dot_3_3_out;
    end 
  end
  else if (ctrl6) begin
    case (cnt_state)
      7'd0: begin max[0] <= cmp_out5; max[1] <= cmp_out8; end
      7'd14: begin max[0] <= {1'b0,add_1[30:0]}; end 
      7'd15: begin max[0] <= add_2; end
      7'd16: begin max[0] <= add_2; end
      7'd17: begin max[0] <= add_2; end
      default: begin end
    endcase
  end
end

always @(posedge G_clock_max_out[1] or negedge rst_n) begin //max[2] max[3]
  if (!rst_n) begin
      max[2] <= 32'b0;
      max[3] <= 32'b0;
    end
  else if (ctrl3)  begin
    case (cnt_state)
        7,9,15,17,23,25,31: begin max[2] <= cmp_out7; max[3] <= cmp_out8;end 
        default: begin end
    endcase
  end
  else if (ctrl4) begin
    case (cnt_state)
        7'd0: begin max[2] <= cmp_out7; max[3] <= cmp_out8;end 
        default: begin end
    endcase
  end
  else if (ctrl5) begin
    max[2] <= max[2]; 
    max[3] <= max[3];
  end
  else if (ctrl6) begin
    case (cnt_state)
      7'd1: begin max[2] <= cmp_out5; max[3] <= cmp_out8; end
      default: begin end
    endcase
  end
end


// always @(posedge G_clock_max_out or negedge rst_n) begin //max
//   if (!rst_n) begin
//       for (i = 0; i<4 ; i = i+1 ) begin
//         max[i] <= 32'b0;
//       end
//     end
//   else if (ctrl3)  begin
//     case (cnt_state)
//         7,9,15,17,23,25,31: begin max[0] <= cmp_out5; max[1] <= cmp_out6; max[2] <= cmp_out7; max[3] <= cmp_out8;end 
//         default: begin end
//     endcase
//   end
//   else if (ctrl4) begin
//     case (cnt_state)
//         7'd0: begin max[0] <= cmp_out5; max[1] <= cmp_out6; max[2] <= cmp_out7; max[3] <= cmp_out8;end 
//         default: begin end
//     endcase
//   end
//   else if (ctrl5) begin
//     if (cnt_state == 7'd0) begin
//       max[1] <= dot_3_3_out;
//     end 
//   end
//   else if (ctrl6) begin
//     case (cnt_state)
//       7'd0: begin max[0] <= cmp_out5; max[1] <= cmp_out8; end
//       7'd1: begin max[2] <= cmp_out5; max[3] <= cmp_out8; end
//       7'd14: begin max[0] <= {1'b0,add_1[30:0]}; end 
//       7'd15: begin max[0] <= add_2; end
//       7'd16: begin max[0] <= add_2; end
//       7'd17: begin max[0] <= add_2; end
//       default: begin end
//     endcase
//   end
// end

GATED_OR MAXPOOL_1 (.CLOCK( clk ), .RST_N(rst_n),.SLEEP_CTRL(cg_en && ~(ctrl3 || ctrl4 || ctrl5 || ctrl6)), .CLOCK_GATED( G_clock_maxpool_out[0]));
GATED_OR MAXPOOL_2 (.CLOCK( clk ), .RST_N(rst_n),.SLEEP_CTRL(cg_en && ~(ctrl3 || ctrl4 || ctrl5 || ctrl6)), .CLOCK_GATED( G_clock_maxpool_out[1]));
GATED_OR MAXPOOL_3 (.CLOCK( clk ), .RST_N(rst_n),.SLEEP_CTRL(cg_en && ~(ctrl3 || ctrl4 || ctrl5 || ctrl6)), .CLOCK_GATED( G_clock_maxpool_out[2]));
GATED_OR MAXPOOL_4 (.CLOCK( clk ), .RST_N(rst_n),.SLEEP_CTRL(cg_en && ~(ctrl3 || ctrl4 || ctrl5 || ctrl6)), .CLOCK_GATED( G_clock_maxpool_out[3]));


always @(posedge G_clock_maxpool_out[0] or negedge rst_n) begin //max_pool[0][0] max_pool[0][1]
  if (!rst_n) begin
      max_pool[0][0] <= 32'b0;
      max_pool[0][1] <= 32'b0;
    end
  else if (ctrl3) begin
    case (cnt_state)
      7 : begin max_pool[0][0] <= cmp_out5;end 
      9 : begin max_pool[0][1] <= cmp_out5;end 
      default: begin end
    endcase
  end
  else if (ctrl4) begin
      max_pool[0][0] <= max_pool[0][0];
      max_pool[0][1] <= max_pool[0][1];
  end
  else if (ctrl5) begin
    case (cnt_state)
      7'd0: begin max_pool[0][0] <= dot_3_1_out; max_pool[0][1] <= dot_3_2_out; end
      default: begin end
    endcase
  end
  else if (ctrl6) begin
    case (cnt_state)
      7'd0:  begin max_pool[0][0] <= add_2;                             end
      7'd1:  begin max_pool[0][1] <= add_2; max_pool[0][0] <= div_out1; end
      7'd2:  begin max_pool[0][1] <= div_out1; end
      7'd9:  begin max_pool[0][0] <= div_out1;                          end
      7'd10: begin max_pool[0][1] <= div_out1;                          end
      default: begin end
    endcase
  end
end

always @(posedge G_clock_maxpool_out[1] or negedge rst_n) begin //max_pool[0][2] max_pool[0][3]
  if (!rst_n) begin
      max_pool[0][2] <= 32'b0;
      max_pool[0][3] <= 32'b0;
    end
  else if (ctrl3) begin
    case (cnt_state)
      15: begin max_pool[0][2] <= cmp_out5;end 
      17: begin max_pool[0][3] <= cmp_out5;end 
      default: begin end
    endcase
  end
  else if (ctrl4) begin
    max_pool[0][2] <= max_pool[0][2];
    max_pool[0][3] <= max_pool[0][3];
  end
  else if (ctrl5) begin
    case (cnt_state)
      7'd1: begin max_pool[0][2] <= max[1]; max_pool[0][3] <= dot_3_1_out;end
      default: begin end
    endcase
  end
  else if (ctrl6) begin
    case (cnt_state)
      7'd2:  begin max_pool[0][2] <= add_2;  end
      7'd3:  begin max_pool[0][3] <= add_2; max_pool[0][2] <= div_out1; end
      7'd4:  begin max_pool[0][3] <= div_out1; end
      7'd11: begin max_pool[0][2] <= div_out1;                          end
      7'd12: begin max_pool[0][3] <= div_out1;                          end
      default: begin end
    endcase
  end
end

always @(posedge G_clock_maxpool_out[2] or negedge rst_n) begin //max_pool[1][0] max_pool[1][1]
  if (!rst_n) begin
      max_pool[1][0] <= 32'b0;
      max_pool[1][1] <= 32'b0;
    end
  else if (ctrl3) begin
    case (cnt_state)
      23: begin max_pool[1][0] <= cmp_out5;end 
      25: begin max_pool[1][1] <= cmp_out5;end 
      default: begin end
    endcase
  end
  else if (ctrl4) begin
    max_pool[1][0] <= max_pool[1][0];
    max_pool[1][1] <= max_pool[1][1];
  end
  else if (ctrl5) begin
    case (cnt_state)
      7'd1: begin max_pool[1][0] <= dot_3_2_out; max_pool[1][1] <= dot_3_3_out;end
      default: begin end
    endcase
  end
  else if (ctrl6) begin
    case (cnt_state)
      7'd4:  begin max_pool[1][0] <= add_2;  end
      7'd5:  begin max_pool[1][1] <= add_2; max_pool[1][0] <= div_out1; end
      7'd6:  begin max_pool[1][1] <= div_out1; end
      7'd13: begin max_pool[1][0] <= div_out1;                          end
      7'd14: begin max_pool[1][1] <= div_out1;                          end
      default: begin end
    endcase
  end
end

always @(posedge G_clock_maxpool_out[3] or negedge rst_n) begin //max_pool[1][2] max_pool[1][3]
  if (!rst_n) begin
      max_pool[1][2] <= 32'b0;
      max_pool[1][3] <= 32'b0;
    end
  else if (ctrl3) begin
    case (cnt_state)
      31: begin max_pool[1][2] <= cmp_out5;end 
      default: begin end
    endcase
  end
  else if (ctrl4) begin
    max_pool[1][3] <= cmp_out5;
  end
  else if (ctrl5) begin
    case (cnt_state)
      7'd2: begin max_pool[1][2] <= dot_3_1_out; max_pool[1][3] <= dot_3_2_out; end
      default: begin end
    endcase
  end
  else if (ctrl6) begin
    case (cnt_state)
      7'd6:  begin max_pool[1][2] <= add_2; end
      7'd7:  begin max_pool[1][3] <= add_2; max_pool[1][2] <= div_out1; end
      7'd8:  begin                          max_pool[1][3] <= div_out1; end
      7'd15: begin max_pool[1][2] <= div_out1;                          end
      7'd16: begin max_pool[1][3] <= div_out1;                          end
      default: begin end
    endcase
  end
end




// always @(posedge G_clock_max_out or negedge rst_n) begin //max_pool
//   if (!rst_n) begin
//       for (i = 0; i<4 ; i = i+1 ) begin
//         max_pool[0][i] <= 32'b0;
//         max_pool[1][i] <= 32'b0;
//       end
//     end
//   else if (ctrl3) begin
//     case (cnt_state)
//       7 : begin max_pool[0][0] <= cmp_out5;end 
//       9 : begin max_pool[0][1] <= cmp_out5;end 
//       15: begin max_pool[0][2] <= cmp_out5;end 
//       17: begin max_pool[0][3] <= cmp_out5;end 
//       23: begin max_pool[1][0] <= cmp_out5;end 
//       25: begin max_pool[1][1] <= cmp_out5;end 
//       31: begin max_pool[1][2] <= cmp_out5;end 
//       default: begin end
//     endcase
//   end
//   else if (ctrl4) begin
//     max_pool[1][3] <= cmp_out5;
//   end
//   else if (ctrl5) begin
//     case (cnt_state)
//       7'd0: begin max_pool[0][0] <= dot_3_1_out; max_pool[0][1] <= dot_3_2_out; end
//       7'd1: begin max_pool[0][2] <= max[1]; max_pool[0][3] <= dot_3_1_out;
//                   max_pool[1][0] <= dot_3_2_out; max_pool[1][1] <= dot_3_3_out;end
//       7'd2: begin max_pool[1][2] <= dot_3_1_out; max_pool[1][3] <= dot_3_2_out; end
//       default: begin end
//     endcase
//   end
//   else if (ctrl6) begin
//     case (cnt_state)
//       7'd0:  begin max_pool[0][0] <= add_2;                             end
//       7'd1:  begin max_pool[0][1] <= add_2; max_pool[0][0] <= div_out1; end
//       7'd2:  begin max_pool[0][2] <= add_2; max_pool[0][1] <= div_out1; end
//       7'd3:  begin max_pool[0][3] <= add_2; max_pool[0][2] <= div_out1; end
//       7'd4:  begin max_pool[1][0] <= add_2; max_pool[0][3] <= div_out1; end
//       7'd5:  begin max_pool[1][1] <= add_2; max_pool[1][0] <= div_out1; end
//       7'd6:  begin max_pool[1][2] <= add_2; max_pool[1][1] <= div_out1; end
//       7'd7:  begin max_pool[1][3] <= add_2; max_pool[1][2] <= div_out1; end
//       7'd8:  begin                          max_pool[1][3] <= div_out1; end
//       7'd9:  begin max_pool[0][0] <= div_out1;                          end
//       7'd10: begin max_pool[0][1] <= div_out1;                          end
//       7'd11: begin max_pool[0][2] <= div_out1;                          end
//       7'd12: begin max_pool[0][3] <= div_out1;                          end
//       7'd13: begin max_pool[1][0] <= div_out1;                          end
//       7'd14: begin max_pool[1][1] <= div_out1;                          end
//       7'd15: begin max_pool[1][2] <= div_out1;                          end
//       7'd16: begin max_pool[1][3] <= div_out1;                          end
//       default: begin end
//     endcase
//   end
// end


// always @(posedge clk or negedge rst_n) begin //max_pool
//   if (!rst_n) begin
//       for (i = 0; i<4 ; i = i+1 ) begin
//         max_pool[0][i] <= 32'b0;
//         max_pool[1][i] <= 32'b0;
//       end
//     end
//   else begin
//     case (c_state)
//       IDLE,CONVOLUTION:begin
//         case (cnt_input)
//           7'd0: begin  
//             for (i = 0; i<4 ; i = i+1) begin
//               max_pool[0][i] <= 32'b0;
//               max_pool[1][i] <= 32'b0;
//             end  
//           end
//           // 7'd49: begin max_pool[0][0] <= cmp_out1; end
//           // 7'd51: begin max_pool[0][1] <= cmp_out1; end
//           // 7'd57: begin max_pool[0][2] <= cmp_out1; end 
//           // 7'd59: begin max_pool[0][3] <= cmp_out1; end
//           // 7'd97: begin max_pool[1][0] <= cmp_out1; end
//           // 7'd99: begin max_pool[1][1] <= cmp_out1; end
//           // 7'd105: begin max_pool[1][2] <= cmp_out1; end 
//           default: begin end
//         endcase
//       end
//       EQUALIZATION:begin
//         case (cnt_state)
//           7 : begin max_pool[0][0] <= cmp_out5;end 
//           9 : begin max_pool[0][1] <= cmp_out5;end 
//           15: begin max_pool[0][2] <= cmp_out5;end 
//           17: begin max_pool[0][3] <= cmp_out5;end 
//           23: begin max_pool[1][0] <= cmp_out5;end 
//           25: begin max_pool[1][1] <= cmp_out5;end 
//           31: begin max_pool[1][2] <= cmp_out5;end 
//           default: begin end
//         endcase
//       end
//       POOLING:begin
//         case (cnt_state)
//           7'd0: begin max_pool[1][3] <= cmp_out5;end 
//           default: begin end
//         endcase
//       end
//       MATRIXMULT:begin
//         case (cnt_state)
//           7'd0: begin max_pool[0][0] <= dot_3_1_out; max_pool[0][1] <= dot_3_2_out; end
//           7'd1: begin max_pool[0][2] <= max[1]; max_pool[0][3] <= dot_3_1_out;
//                       max_pool[1][0] <= dot_3_2_out; max_pool[1][1] <= dot_3_3_out;end
//           7'd2: begin max_pool[1][2] <= dot_3_1_out; max_pool[1][3] <= dot_3_2_out; end
//           default: begin end
//         endcase
//       end
//       NORMAL_ACTI:begin
//         case (cnt_state)
//           7'd0:  begin max_pool[0][0] <= add_2;                             end
//           7'd1:  begin max_pool[0][1] <= add_2; max_pool[0][0] <= div_out1; end
//           7'd2:  begin max_pool[0][2] <= add_2; max_pool[0][1] <= div_out1; end
//           7'd3:  begin max_pool[0][3] <= add_2; max_pool[0][2] <= div_out1; end
//           7'd4:  begin max_pool[1][0] <= add_2; max_pool[0][3] <= div_out1; end
//           7'd5:  begin max_pool[1][1] <= add_2; max_pool[1][0] <= div_out1; end
//           7'd6:  begin max_pool[1][2] <= add_2; max_pool[1][1] <= div_out1; end
//           7'd7:  begin max_pool[1][3] <= add_2; max_pool[1][2] <= div_out1; end
//           7'd8:  begin                          max_pool[1][3] <= div_out1; end
//           7'd9:  begin max_pool[0][0] <= div_out1;                          end
//           7'd10: begin max_pool[0][1] <= div_out1;                          end
//           7'd11: begin max_pool[0][2] <= div_out1;                          end
//           7'd12: begin max_pool[0][3] <= div_out1;                          end
//           7'd13: begin max_pool[1][0] <= div_out1;                          end
//           7'd14: begin max_pool[1][1] <= div_out1;                          end
//           7'd15: begin max_pool[1][2] <= div_out1;                          end
//           7'd16: begin max_pool[1][3] <= div_out1;                          end
//           default: begin end
//         endcase
//       end
//       default: begin end
//     endcase
//   end
// end

// wire G_clock_cal_out;
// wire G_sleep_cal = cg_en && ~(ctrl6);
// GATED_OR GATED_CAL (
//     .CLOCK( clk ),
//     .RST_N(rst_n),
//     .SLEEP_CTRL(G_sleep_cal), // gated clock
//     .CLOCK_GATED( G_clock_cal_out)
// );



generate // exp_up
    for (a = 0;a < 8;a = a +1) begin
        GATED_OR EXPUP (.CLOCK(clk), .SLEEP_CTRL(cg_en && ~(ctrl6)), .RST_N(rst_n), .CLOCK_GATED(G_clock_expup_out[a]));
        always @(posedge G_clock_expup_out[a] or negedge rst_n) begin
            if (!rst_n)  exp_up[a] <= 32'b0;
            else if (ctrl6) begin
                if (cnt_state == (a + 3))
                    exp_up[a] <= add_1;
            end
        end
    end
endgenerate


// always @(posedge G_clock_cal_out or negedge rst_n) begin //exp_up
//   if (!rst_n) begin
//       for (i = 0; i<8 ; i = i+1 ) begin
//         exp_up[i] <= 32'b0;
//       end
//     end
//   else if (ctrl6) begin
//     case (cnt_state)
//       7'd3: begin exp_up[0] <= add_1; end
//       7'd4: begin exp_up[1] <= add_1; end
//       7'd5: begin exp_up[2] <= add_1; end
//       7'd6: begin exp_up[3] <= add_1; end
//       7'd7: begin exp_up[4] <= add_1; end
//       7'd8: begin exp_up[5] <= add_1; end
//       7'd9: begin exp_up[6] <= add_1; end
//       7'd10: begin exp_up[7] <= add_1; end
//       default: begin end
//     endcase
//   end
// end


// always @(posedge clk or negedge rst_n) begin //exp_up
//   if (!rst_n) begin
//       for (i = 0; i<8 ; i = i+1 ) begin
//         exp_up[i] <= 32'b0;
//       end
//     end
//   else begin
//     case (c_state)
//       NORMAL_ACTI:begin
//         case (cnt_state)
//           7'd3: begin exp_up[0] <= add_1; end
//           7'd4: begin exp_up[1] <= add_1; end
//           7'd5: begin exp_up[2] <= add_1; end
//           7'd6: begin exp_up[3] <= add_1; end
//           7'd7: begin exp_up[4] <= add_1; end
//           7'd8: begin exp_up[5] <= add_1; end
//           7'd9: begin exp_up[6] <= add_1; end
//           7'd10: begin exp_up[7] <= add_1; end
//           default: exp_up <= exp_up;
//         endcase
//       end
//       default: exp_up <= exp_up;
//     endcase
//   end
// end

generate // exp_tmp2   
        for (b = 0;b < 8;b = b +1) begin
            GATED_OR EXPUP (.CLOCK(clk), .SLEEP_CTRL(cg_en && ~(ctrl6)), .RST_N(rst_n), .CLOCK_GATED(G_clock_exptmp_out[b]));
            always @(posedge G_clock_exptmp_out[b] or negedge rst_n) begin
                if (!rst_n)  begin 
                    exp_tmp2[0][b] <= 32'b0; 
                    exp_tmp2[1][b] <= 32'b0;
                end
                else if (ctrl6) begin
                    if (cnt_state == (b + 2))
                        exp_tmp2[0][b] <= exp_out1;
                        exp_tmp2[1][b] <= exp_out2;
                end
            end
        end
endgenerate

// generate // exp_tmp2[1]
//         for (b = 0;b < 8;b = b +1) begin
//             GATED_OR EXPUP (.CLOCK(clk), .SLEEP_CTRL(cg_en && ~(ctrl6)), .RST_N(rst_n), .CLOCK_GATED(G_clock_exptmp_out[1][b]));
//             always @(posedge G_clock_exptmp_out[1][b] or negedge rst_n) begin
//                 if (!rst_n)  exp_tmp2[1][b] <= 32'b0;
//                 else if (ctrl6) begin
//                     if (cnt_state == (b + 2))
//                         exp_tmp2[1][b] <= exp_out1;
//                 end
//             end
//         end
// endgenerate



// always @(posedge G_clock_cal_out or negedge rst_n) begin //exp_tmp2
//   if (!rst_n) begin
//       for (i = 0; i<8 ; i = i+1 ) begin
//         exp_tmp2[0][i] <= 32'b0;
//         exp_tmp2[1][i] <= 32'b0;
//       end
//     end
//   else if (ctrl6) begin
//     case (cnt_state)
//       7'd2: begin exp_tmp2[0][0] <= exp_out1; exp_tmp2[1][0] <= exp_out2;end
//       7'd3: begin exp_tmp2[0][1] <= exp_out1; exp_tmp2[1][1] <= exp_out2;end
//       7'd4: begin exp_tmp2[0][2] <= exp_out1; exp_tmp2[1][2] <= exp_out2;end
//       7'd5: begin exp_tmp2[0][3] <= exp_out1; exp_tmp2[1][3] <= exp_out2;end
//       7'd6: begin exp_tmp2[0][4] <= exp_out1; exp_tmp2[1][4] <= exp_out2;end
//       7'd7: begin exp_tmp2[0][5] <= exp_out1; exp_tmp2[1][5] <= exp_out2;end
//       7'd8: begin exp_tmp2[0][6] <= exp_out1; exp_tmp2[1][6] <= exp_out2;end
//       7'd9: begin exp_tmp2[0][7] <= exp_out1; exp_tmp2[1][7] <= exp_out2;end
//       default: begin exp_tmp2 <= exp_tmp2; end
//     endcase
//   end

// end

// always @(posedge clk or negedge rst_n) begin //exp_tmp2
//   if (!rst_n) begin
//       for (i = 0; i<8 ; i = i+1 ) begin
//         exp_tmp2[0][i] <= 32'b0;
//         exp_tmp2[1][i] <= 32'b0;
//       end
//     end
//   else begin
//     case (c_state)
//       NORMAL_ACTI:begin
//         case (cnt_state)
//           7'd2: begin exp_tmp2[0][0] <= exp_out1; exp_tmp2[1][0] <= exp_out2;end
//           7'd3: begin exp_tmp2[0][1] <= exp_out1; exp_tmp2[1][1] <= exp_out2;end
//           7'd4: begin exp_tmp2[0][2] <= exp_out1; exp_tmp2[1][2] <= exp_out2;end
//           7'd5: begin exp_tmp2[0][3] <= exp_out1; exp_tmp2[1][3] <= exp_out2;end
//           7'd6: begin exp_tmp2[0][4] <= exp_out1; exp_tmp2[1][4] <= exp_out2;end
//           7'd7: begin exp_tmp2[0][5] <= exp_out1; exp_tmp2[1][5] <= exp_out2;end
//           7'd8: begin exp_tmp2[0][6] <= exp_out1; exp_tmp2[1][6] <= exp_out2;end
//           7'd9: begin exp_tmp2[0][7] <= exp_out1; exp_tmp2[1][7] <= exp_out2;end
//           default: begin exp_tmp2 <= exp_tmp2; end
//         endcase
//       end
//       default: begin exp_tmp2 <= exp_tmp2;end
//     endcase
//   end
// end

generate // add_tmp   
    for (b = 2;b < 10;b = b +1) begin
        GATED_OR EXPUP (.CLOCK(clk), .SLEEP_CTRL(cg_en && ~(ctrl6)), .RST_N(rst_n), .CLOCK_GATED(G_clock_add_out[b]));
        always @(posedge G_clock_add_out[b] or negedge rst_n) begin
            if (!rst_n)  begin 
                add_tmp[b] <= 32'b0;
            end
            else if (ctrl6) begin
                if (cnt_state == (b + 1))
                   add_tmp[b] <= add_3;
            end
        end
    end
endgenerate

generate // add_tmp   
    for (b = 0;b < 2;b = b +1) begin
        GATED_OR EXPUP (.CLOCK(clk), .SLEEP_CTRL(cg_en && ~(ctrl6)), .RST_N(rst_n), .CLOCK_GATED(G_clock_add_out[b]));
        always @(posedge G_clock_add_out[b] or negedge rst_n) begin
            if (!rst_n)  begin 
                add_tmp[b] <= 32'b0;
            end
            else if (ctrl6) begin
                if (cnt_state == b)
                   add_tmp[b] <= add_1;
            end
        end
    end
endgenerate


// always @(posedge G_clock_cal_out or negedge rst_n) begin //add_tmp
//   if (!rst_n) begin
//       for (i = 0; i<10 ; i = i+1 ) begin
//         add_tmp[0][i] <= 32'b0;
//       end
//     end
//   else if (ctrl6) begin
//     case (cnt_state)
//       7'd0: begin add_tmp[0] <= add_1;end
//       7'd1: begin add_tmp[1] <= add_1;end
//       7'd3: begin add_tmp[2] <= add_3;end
//       7'd4: begin add_tmp[3] <= add_3;end
//       7'd5: begin add_tmp[4] <= add_3;end
//       7'd6: begin add_tmp[5] <= add_3;end
//       7'd7: begin add_tmp[6] <= add_3;end
//       7'd8: begin add_tmp[7] <= add_3;end
//       7'd9: begin add_tmp[8] <= add_3;end
//       7'd10: begin add_tmp[9] <= add_3;end
//       default: begin  end
//     endcase
//   end
// end

// always @(posedge clk or negedge rst_n) begin //add_tmp
//   if (!rst_n) begin
//       for (i = 0; i<10 ; i = i+1 ) begin
//         add_tmp[0][i] <= 32'b0;
//       end
//     end
//   else begin
//     case (c_state)
//       NORMAL_ACTI:begin
//         case (cnt_state)
//           7'd0: begin add_tmp[0] <= add_1;end
//           7'd1: begin add_tmp[1] <= add_1;end
//           7'd3: begin add_tmp[2] <= add_3;end
//           7'd4: begin add_tmp[3] <= add_3;end
//           7'd5: begin add_tmp[4] <= add_3;end
//           7'd6: begin add_tmp[5] <= add_3;end
//           7'd7: begin add_tmp[6] <= add_3;end
//           7'd8: begin add_tmp[7] <= add_3;end
//           7'd9: begin add_tmp[8] <= add_3;end
//           7'd10: begin add_tmp[9] <= add_3;end
//           default: begin add_tmp <= add_tmp; end
//         endcase
//       end
//       default: begin add_tmp <= add_tmp;end
//     endcase
//   end
// end
//---------------------------------------------------------------------
//   Output
//---------------------------------------------------------------------
always @(*) // out_valid
  begin
    out_valid = 1'b0;
    // if (c_state == NORMAL_ACTI && cnt_state == 7'd17) begin
    if (c_state == OUT && cnt_long == 10'd934) begin  
        out_valid = 1'b1;
    end        
  end

always @(*) // out
  begin
    out = 32'b0;
    //if (c_state == NORMAL_ACTI && cnt_state == 7'd17) begin
    if (c_state == OUT && cnt_long == 10'd934) begin  
        out = max[0];
    end
  end

//---------------------------------------------------------------------
//   Count
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin // cnt_input
  if (!rst_n) begin
    cnt_input <= 7'b0;
  end else begin
    if (c_state == IDLE && in_valid)begin
      cnt_input <= cnt_input + 1'b1;
    end
    else if (c_state == CONVOLUTION) begin
      cnt_input <= cnt_input + 1'b1;
    end 
    else begin
      cnt_input <= 7'b0;
    end
  end
end

always @(posedge clk or negedge rst_n) begin // cnt_16
  if (!rst_n) begin
    cnt_16 <= 7'b0;
  end else begin
    case (c_state)
      IDLE: begin
        if (in_valid) begin
          cnt_16 <= cnt_16 + 1'b1;
        end
      end
      CONVOLUTION,EQUALIZATION:begin
        cnt_16 <= cnt_16 + 1'b1;
      end  
      default: cnt_16 <= 7'b0;
    endcase
  end
end

always @(posedge clk or negedge rst_n) begin // cnt_state
  if (!rst_n) begin
    cnt_state <= 7'b0;
  end else begin
    if (c_state != n_state)begin
      cnt_state <= 7'b0;
    end  
    else begin
      cnt_state <= cnt_state + 1'b1;
    end
  end
end

always @(posedge clk or negedge rst_n) begin // cnt_long
  if (!rst_n) begin
    cnt_long <= 10'b0;
  end else begin
    if (c_state == OUT)begin
      cnt_long <= cnt_long + 1'b1;
    end  
    else begin
      cnt_long <= 10'b0;
    end
  end
end

//---------------------------------------------------------------------
//   Some control
//---------------------------------------------------------------------
always @(*) begin // x_y
      case (cnt_16)
        4'd0: begin x_y = 6'b010_100; end
        4'd1: begin x_y = 6'b011_001; end
        4'd2: begin x_y = 6'b011_010; end
        4'd3: begin x_y = 6'b011_011; end
        4'd4: begin x_y = 6'b011_100; end
        4'd5: begin x_y = 6'b100_001; end
        4'd6: begin x_y = 6'b100_010; end
        4'd7: begin x_y = 6'b100_011; end
        4'd8: begin x_y = 6'b100_100; end
        4'd9: begin x_y = 6'b001_001; end
        4'd10: begin x_y = 6'b001_010; end
        4'd11: begin x_y = 6'b001_011; end
        4'd12: begin x_y = 6'b001_100; end
        4'd13: begin x_y = 6'b010_001; end
        4'd14: begin x_y = 6'b010_010; end
        4'd15: begin x_y = 6'b010_011; end
        default: begin x_y = 6'b0; end
      endcase
end

always @(*) begin // x_y_map
      case (cnt_16)
        4'd0: begin x_y_map = 4'b01_10; end
        4'd1: begin x_y_map = 4'b01_11; end
        4'd2: begin x_y_map = 4'b10_00; end
        4'd3: begin x_y_map = 4'b10_01; end
        4'd4: begin x_y_map = 4'b10_10; end
        4'd5: begin x_y_map = 4'b10_11; end
        4'd6: begin x_y_map = 4'b11_00; end
        4'd7: begin x_y_map = 4'b11_01; end
        4'd8: begin x_y_map = 4'b11_10; end
        4'd9: begin x_y_map = 4'b11_11; end
        4'd10: begin x_y_map = 4'b00_00; end
        4'd11: begin x_y_map = 4'b00_01; end
        4'd12: begin x_y_map = 4'b00_10; end
        4'd13: begin x_y_map = 4'b00_11; end
        4'd14: begin x_y_map = 4'b01_00; end
        4'd15: begin x_y_map = 4'b01_01; end
        default: begin x_y_map = 4'b0; end
      endcase
end

always @(*) begin // ker_channel
    if (c_state == IDLE || c_state == CONVOLUTION) begin
      if ((cnt_input >= 7'd9 && cnt_input <= 7'd24) || (cnt_input >= 7'd57 && cnt_input <= 7'd72)) begin
        ker_channel = 2'd0;
      end
      else if ((cnt_input >= 7'd25 && cnt_input <= 7'd40) || (cnt_input >= 7'd73 && cnt_input <= 7'd88)) begin
        ker_channel = 2'd1;
      end 
      else if ((cnt_input >= 7'd41 && cnt_input <= 7'd56) || (cnt_input >= 7'd89 && cnt_input <= 7'd104)) begin
        ker_channel = 2'd2;
      end else begin
        ker_channel = 2'd3;
      end
    end 
    else 
      begin 
        ker_channel = 2'b0; 
      end
end

always @(*) begin // map_channel
    if (c_state == IDLE || c_state == CONVOLUTION) begin
      if (cnt_input >= 7'd9 && cnt_input <= 7'd57) begin
        map_channel = 1'd0;
      end
      else if (cnt_input >= 7'd57 && cnt_input <= 7'd105)begin
        map_channel = 1'd1;
      end 
      else begin
        map_channel = 1'd0;
      end
    end 
    else 
      begin 
        map_channel = 1'd0; 
      end
end

always @(*) begin //first
  if (c_state == IDLE && cnt_input == 7'd1) begin
    first = 1'b1;
  end
  else begin
    first = 1'b0;
  end
end


//---------------------------------------------------------------------
//   IP input select
//---------------------------------------------------------------------
always @(*) begin //cmp_in1~4
    case (c_state)
      //IDLE,CONVOLUTION: begin
      //  case (cnt_input)
      //    7'd48: begin
      //      cmp_in1 = map[0][0][0];
      //      cmp_in2 = map[0][0][1];
      //      cmp_in3 = map[0][1][0];
      //      cmp_in4 = map[0][1][1];
      //    end
      //    7'd50: begin
      //      cmp_in1 = map[0][0][2];
      //      cmp_in2 = map[0][0][3];
      //      cmp_in3 = map[0][1][2];
      //      cmp_in4 = map[0][1][3];
      //    end
      //    7'd56: begin
      //      cmp_in1 = map[0][2][0];
      //      cmp_in2 = map[0][2][1];
      //      cmp_in3 = map[0][3][0];
      //      cmp_in4 = map[0][3][1];
      //    end 
      //    7'd58: begin
      //      cmp_in1 = map[0][2][2];
      //      cmp_in2 = map[0][2][3];
      //      cmp_in3 = map[0][3][2];
      //      cmp_in4 = map[0][3][3];
      //    end 
      //    7'd96: begin
      //      cmp_in1 = map[1][0][0];
      //      cmp_in2 = map[1][0][1];
      //      cmp_in3 = map[1][1][0];
      //      cmp_in4 = map[1][1][1];
      //    end
      //    7'd98: begin
      //      cmp_in1 = map[1][0][2];
      //      cmp_in2 = map[1][0][3];
      //      cmp_in3 = map[1][1][2];
      //      cmp_in4 = map[1][1][3];
      //    end
      //    7'd104: begin
      //      cmp_in1 = map[1][2][0];
      //      cmp_in2 = map[1][2][1];
      //      cmp_in3 = map[1][3][0];
      //      cmp_in4 = map[1][3][1];
      //    end
      //    7'd49,7'd51,7'd57,7'd59,7'd97,7'd99,7'd105: begin
      //      cmp_in1 = max[0];
      //      cmp_in2 = max[2];
      //      cmp_in3 = max[1];
      //      cmp_in4 = max[3];
      //    end
      //    default: begin
      //      cmp_in1 = 32'b0;
      //      cmp_in2 = 32'b0;
      //      cmp_in3 = 32'b0;
      //      cmp_in4 = 32'b0;
      //    end
      //  endcase
      //end
      EQUALIZATION:begin
        case (cnt_state)
          7: begin
            cmp_in1 = equal_map[0][0][0];
            cmp_in2 = equal_map[0][0][1];
            cmp_in3 = equal_map[0][1][0];
            cmp_in4 = equal_map[0][1][1];
          end
          9: begin
            cmp_in1 = equal_map[0][0][2];
            cmp_in2 = equal_map[0][0][3];
            cmp_in3 = equal_map[0][1][2];
            cmp_in4 = equal_map[0][1][3];
          end
          15: begin
            cmp_in1 = equal_map[0][2][0];
            cmp_in2 = equal_map[0][2][1];
            cmp_in3 = equal_map[0][3][0];
            cmp_in4 = equal_map[0][3][1];
          end 
          17: begin
            cmp_in1 = equal_map[0][2][2];
            cmp_in2 = equal_map[0][2][3];
            cmp_in3 = equal_map[0][3][2];
            cmp_in4 = equal_map[0][3][3];
          end 
          23: begin
            cmp_in1 = equal_map[1][0][0];
            cmp_in2 = equal_map[1][0][1];
            cmp_in3 = equal_map[1][1][0];
            cmp_in4 = equal_map[1][1][1];
          end
          25: begin
            cmp_in1 = equal_map[1][0][2];
            cmp_in2 = equal_map[1][0][3];
            cmp_in3 = equal_map[1][1][2];
            cmp_in4 = equal_map[1][1][3];
          end
          31: begin
            cmp_in1 = equal_map[1][2][0];
            cmp_in2 = equal_map[1][2][1];
            cmp_in3 = equal_map[1][3][0];
            cmp_in4 = equal_map[1][3][1];
          end
          // 33: begin
          //   cmp_in1 = equal_map[1][2][2];
          //   cmp_in2 = equal_map[1][2][3];
          //   cmp_in3 = equal_map[1][3][2];
          //   cmp_in4 = equal_map[1][3][3];
          // end 
          default: begin
            cmp_in1 = 32'b0;
            cmp_in2 = 32'b0;
            cmp_in3 = 32'b0;
            cmp_in4 = 32'b0;
          end
        endcase
      end
      POOLING:begin
        case (cnt_state)
          7'd0: begin 
            cmp_in1 = equal_map[1][2][2];
            cmp_in2 = equal_map[1][2][3];
            cmp_in3 = equal_map[1][3][2];
            cmp_in4 = equal_map[1][3][3];
           end 
          default: begin
            cmp_in1 = 32'b0;
            cmp_in2 = 32'b0;
            cmp_in3 = 32'b0;
            cmp_in4 = 32'b0;
          end
        endcase
      end
      NORMAL_ACTI: begin
        case (cnt_state)
          7'd0: begin
            cmp_in1 = max_pool[0][0];
            cmp_in2 = max_pool[0][1];
            cmp_in3 = max_pool[0][2];
            cmp_in4 = max_pool[0][3];
          end
          7'd1: begin
            cmp_in1 = max_pool[1][0];
            cmp_in2 = max_pool[1][1];
            cmp_in3 = max_pool[1][2];
            cmp_in4 = max_pool[1][3];
          end 
          default: begin
            cmp_in1 = 32'b0;
            cmp_in2 = 32'b0;
            cmp_in3 = 32'b0;
            cmp_in4 = 32'b0;
          end 
        endcase
      end
      default: begin
        cmp_in1 = 32'b0;
        cmp_in2 = 32'b0;
        cmp_in3 = 32'b0;
        cmp_in4 = 32'b0;
      end
    endcase
  //end
end

always @(*) begin //cmp_in5~8
    case (c_state)
      /////// pooling - 1 CYCLE
      EQUALIZATION:begin
        case (cnt_state)
          7,9,15,17,23,25,31: begin 
            cmp_in5 = cmp_out1;
            cmp_in6 = cmp_out3;
            cmp_in7 = cmp_out2;
            cmp_in8 = cmp_out4;
           end 
          default: begin
            cmp_in5 = 32'b0;
            cmp_in6 = 32'b0;
            cmp_in7 = 32'b0;
            cmp_in8 = 32'b0;
          end
        endcase
      end
      POOLING:begin
        case (cnt_state)
          7'd0: begin 
            cmp_in5 = cmp_out1;
            cmp_in6 = cmp_out3;
            cmp_in7 = cmp_out2;
            cmp_in8 = cmp_out4;
           end 
          default: begin
            cmp_in5 = 32'b0;
            cmp_in6 = 32'b0;
            cmp_in7 = 32'b0;
            cmp_in8 = 32'b0;
          end
        endcase
      end
      NORMAL_ACTI: begin
        case (cnt_state)
          7'd0,7'd1: begin
            cmp_in5 = cmp_out1;
            cmp_in6 = cmp_out3;
            cmp_in7 = cmp_out2;
            cmp_in8 = cmp_out4;
          end
          default: begin
            cmp_in5 = 32'b0;
            cmp_in6 = 32'b0;
            cmp_in7 = 32'b0;
            cmp_in8 = 32'b0;
          end 
        endcase
      end
      default: begin
        cmp_in5 = 32'b0;
        cmp_in6 = 32'b0;
        cmp_in7 = 32'b0;
        cmp_in8 = 32'b0;
      end
    endcase
end

always @(*) begin //dot_in
    case (c_state)
      IDLE,CONVOLUTION: begin
        dot_a_in1 = img[x_y[5:3]-1][x_y[2:0]-1]; dot_b_in1 = kernel[ker_channel][0][0]; dot_c_in1 = img[x_y[5:3]-1][x_y[2:0]]; 
        dot_d_in1 = kernel[ker_channel][0][1]; dot_e_in1 = img[x_y[5:3]-1][x_y[2:0]+1]; dot_f_in1 = kernel[ker_channel][0][2];
        dot_a_in2 = img[x_y[5:3]][x_y[2:0]-1]; dot_b_in2 = kernel[ker_channel][1][0]; dot_c_in2 = img[x_y[5:3]][x_y[2:0]]; 
        dot_d_in2 = kernel[ker_channel][1][1]; dot_e_in2 = img[x_y[5:3]][x_y[2:0]+1]; dot_f_in2 = kernel[ker_channel][1][2];
        dot_a_in3 = img[x_y[5:3]+1][x_y[2:0]-1]; dot_b_in3 = kernel[ker_channel][2][0]; dot_c_in3 = img[x_y[5:3]+1][x_y[2:0]]; 
        dot_d_in3 = kernel[ker_channel][2][1]; dot_e_in3 = img[x_y[5:3]+1][x_y[2:0]+1]; dot_f_in3 = kernel[ker_channel][2][2];
      end
      EQUALIZATION:begin
        dot_b_in1 = 32'h3f800000; dot_d_in1 = 32'h3f800000; dot_f_in1 = 32'h3f800000; 
        dot_b_in2 = 32'h3f800000; dot_d_in2 = 32'h3f800000; dot_f_in2 = 32'h3f800000;
        dot_b_in3 = 32'h3f800000; dot_d_in3 = 32'h3f800000; dot_f_in3 = 32'h3f800000;
        case (cnt_state)
          0: begin
            dot_a_in1 = (opt[0]) ? 32'b0 : map[0][0][0];
            dot_c_in1 = (opt[0]) ? 32'b0 : map[0][0][0]; 
            dot_e_in1 = (opt[0]) ? 32'b0 : map[0][0][1];

            dot_a_in2 = (opt[0]) ? 32'b0 : map[0][0][0]; 
            dot_c_in2 = map[0][0][0]; 
            dot_e_in2 = map[0][0][1];

            dot_a_in3 = (opt[0]) ? 32'b0 : map[0][1][0]; 
            dot_c_in3 = map[0][1][0]; 
            dot_e_in3 = map[0][1][1]; 
          end
          1: begin
            dot_a_in1 = (opt[0]) ? 32'b0 : map[0][0][0]; 
            dot_c_in1 = (opt[0]) ? 32'b0 : map[0][0][1]; 
            dot_e_in1 = (opt[0]) ? 32'b0 : map[0][0][2];

            dot_a_in2 = map[0][0][0]; 
            dot_c_in2 = map[0][0][1]; 
            dot_e_in2 = map[0][0][2];

            dot_a_in3 = map[0][1][0]; 
            dot_c_in3 = map[0][1][1]; 
            dot_e_in3 = map[0][1][2];  
          end
          2: begin
            dot_a_in1 = (opt[0]) ? 32'b0 : map[0][0][1];
            dot_c_in1 = (opt[0]) ? 32'b0 : map[0][0][2];
            dot_e_in1 = (opt[0]) ? 32'b0 : map[0][0][3];

            dot_a_in2 = map[0][0][1]; 
            dot_c_in2 = map[0][0][2]; 
            dot_e_in2 = map[0][0][3];

            dot_a_in3 = map[0][1][1]; 
            dot_c_in3 = map[0][1][2]; 
            dot_e_in3 = map[0][1][3];  
          end
          3: begin
            dot_a_in1 = (opt[0]) ? 32'b0 : map[0][0][2]; 
            dot_c_in1 = (opt[0]) ? 32'b0 : map[0][0][3]; 
            dot_e_in1 = (opt[0]) ? 32'b0 : map[0][0][3];

            dot_a_in2 = map[0][0][2]; 
            dot_c_in2 = map[0][0][3]; 
            dot_e_in2 = (opt[0]) ? 32'b0 : map[0][0][3]; 

            dot_a_in3 = map[0][1][2]; 
            dot_c_in3 = map[0][1][3]; 
            dot_e_in3 = (opt[0]) ? 32'b0 : map[0][1][3];  
          end
          4: begin
            dot_a_in1 = (opt[0]) ? 32'b0 : map[0][0][0]; 
            dot_c_in1 = map[0][0][0]; 
            dot_e_in1 = map[0][0][1];

            dot_a_in2 = (opt[0]) ? 32'b0 : map[0][1][0];  
            dot_c_in2 = map[0][1][0]; 
            dot_e_in2 = map[0][1][1];

            dot_a_in3 = (opt[0]) ? 32'b0 : map[0][2][0];  
            dot_c_in3 = map[0][2][0]; 
            dot_e_in3 = map[0][2][1]; 
          end
          5: begin
            dot_a_in1 = map[0][0][0]; 
            dot_c_in1 = map[0][0][1]; 
            dot_e_in1 = map[0][0][2];

            dot_a_in2 = map[0][1][0]; 
            dot_c_in2 = map[0][1][1]; 
            dot_e_in2 = map[0][1][2];

            dot_a_in3 = map[0][2][0]; 
            dot_c_in3 = map[0][2][1]; 
            dot_e_in3 = map[0][2][2]; 
          end
          6: begin
            dot_a_in1 = map[0][0][1]; 
            dot_c_in1 = map[0][0][2]; 
            dot_e_in1 = map[0][0][3];

            dot_a_in2 = map[0][1][1]; 
            dot_c_in2 = map[0][1][2]; 
            dot_e_in2 = map[0][1][3];

            dot_a_in3 = map[0][2][1]; 
            dot_c_in3 = map[0][2][2]; 
            dot_e_in3 = map[0][2][3];
          end
          7: begin
            dot_a_in1 = map[0][0][2]; 
            dot_c_in1 = map[0][0][3]; 
            dot_e_in1 = (opt[0]) ? 32'b0 : map[0][0][3]; 

            dot_a_in2 = map[0][1][2]; 
            dot_c_in2 = map[0][1][3]; 
            dot_e_in2 = (opt[0]) ? 32'b0 : map[0][1][3];

            dot_a_in3 = map[0][2][2]; 
            dot_c_in3 = map[0][2][3]; 
            dot_e_in3 = (opt[0]) ? 32'b0 : map[0][2][3];  
          end
          8: begin
            dot_a_in1 = (opt[0]) ? 32'b0 : map[0][1][0]; 
            dot_c_in1 = map[0][1][0]; 
            dot_e_in1 = map[0][1][1];

            dot_a_in2 = (opt[0]) ? 32'b0 : map[0][2][0];  
            dot_c_in2 = map[0][2][0]; 
            dot_e_in2 = map[0][2][1];

            dot_a_in3 = (opt[0]) ? 32'b0 : map[0][3][0];  
            dot_c_in3 = map[0][3][0]; 
            dot_e_in3 = map[0][3][1]; 
          end
          9: begin
            dot_a_in1 = map[0][1][0]; 
            dot_c_in1 = map[0][1][1]; 
            dot_e_in1 = map[0][1][2];

            dot_a_in2 = map[0][2][0]; 
            dot_c_in2 = map[0][2][1]; 
            dot_e_in2 = map[0][2][2];

            dot_a_in3 = map[0][3][0]; 
            dot_c_in3 = map[0][3][1]; 
            dot_e_in3 = map[0][3][2]; 
          end
          10: begin
            dot_a_in1 = map[0][1][1]; 
            dot_c_in1 = map[0][1][2]; 
            dot_e_in1 = map[0][1][3];

            dot_a_in2 = map[0][2][1]; 
            dot_c_in2 = map[0][2][2]; 
            dot_e_in2 = map[0][2][3];

            dot_a_in3 = map[0][3][1]; 
            dot_c_in3 = map[0][3][2]; 
            dot_e_in3 = map[0][3][3];
          end
          11: begin
            dot_a_in1 = map[0][1][2]; 
            dot_c_in1 = map[0][1][3]; 
            dot_e_in1 = (opt[0]) ? 32'b0 : map[0][1][3]; 

            dot_a_in2 = map[0][2][2]; 
            dot_c_in2 = map[0][2][3]; 
            dot_e_in2 = (opt[0]) ? 32'b0 : map[0][2][3]; 

            dot_a_in3 = map[0][3][2]; 
            dot_c_in3 = map[0][3][3]; 
            dot_e_in3 = (opt[0]) ? 32'b0 : map[0][3][3];   
          end
          12: begin
            dot_a_in1 = (opt[0]) ? 32'b0 : map[0][2][0];  
            dot_c_in1 = map[0][2][0]; 
            dot_e_in1 = map[0][2][1];

            dot_a_in2 = (opt[0]) ? 32'b0 : map[0][3][0];  
            dot_c_in2 = map[0][3][0]; 
            dot_e_in2 = map[0][3][1];

            dot_a_in3 = (opt[0]) ? 32'b0 : map[0][3][0]; 
            dot_c_in3 = (opt[0]) ? 32'b0 : map[0][3][0]; 
            dot_e_in3 = (opt[0]) ? 32'b0 : map[0][3][1]; 
          end
          13: begin
            dot_a_in1 = map[0][2][0]; 
            dot_c_in1 = map[0][2][1]; 
            dot_e_in1 = map[0][2][2];

            dot_a_in2 = map[0][3][0]; 
            dot_c_in2 = map[0][3][1]; 
            dot_e_in2 = map[0][3][2];

            dot_a_in3 = (opt[0]) ? 32'b0 : map[0][3][0]; 
            dot_c_in3 = (opt[0]) ? 32'b0 : map[0][3][1]; 
            dot_e_in3 = (opt[0]) ? 32'b0 : map[0][3][2]; 
          end
          14: begin
            dot_a_in1 = map[0][2][1]; 
            dot_c_in1 = map[0][2][2]; 
            dot_e_in1 = map[0][2][3];
            
            dot_a_in2 = map[0][3][1]; 
            dot_c_in2 = map[0][3][2]; 
            dot_e_in2 = map[0][3][3];

            dot_a_in3 = (opt[0]) ? 32'b0 : map[0][3][1]; 
            dot_c_in3 = (opt[0]) ? 32'b0 : map[0][3][2]; 
            dot_e_in3 = (opt[0]) ? 32'b0 : map[0][3][3];
          end
          15: begin
            dot_a_in1 = map[0][2][2]; 
            dot_c_in1 = map[0][2][3]; 
            dot_e_in1 = (opt[0]) ? 32'b0 : map[0][2][3];

            dot_a_in2 = map[0][3][2]; 
            dot_c_in2 = map[0][3][3]; 
            dot_e_in2 = (opt[0]) ? 32'b0 : map[0][3][3];

            dot_a_in3 = (opt[0]) ? 32'b0 : map[0][3][2]; 
            dot_c_in3 = (opt[0]) ? 32'b0 : map[0][3][3]; 
            dot_e_in3 = (opt[0]) ? 32'b0 : map[0][3][3];  
          end
          16: begin
            dot_a_in1 = (opt[0]) ? 32'b0 : map[1][0][0];
            dot_c_in1 = (opt[0]) ? 32'b0 : map[1][0][0]; 
            dot_e_in1 = (opt[0]) ? 32'b0 : map[1][0][1];

            dot_a_in2 = (opt[0]) ? 32'b0 : map[1][0][0]; 
            dot_c_in2 = map[1][0][0]; 
            dot_e_in2 = map[1][0][1];

            dot_a_in3 = (opt[0]) ? 32'b0 : map[1][1][0]; 
            dot_c_in3 = map[1][1][0]; 
            dot_e_in3 = map[1][1][1]; 
          end
          17: begin
            dot_a_in1 = (opt[0]) ? 32'b0 : map[1][0][0]; 
            dot_c_in1 = (opt[0]) ? 32'b0 : map[1][0][1]; 
            dot_e_in1 = (opt[0]) ? 32'b0 : map[1][0][2];

            dot_a_in2 = map[1][0][0]; 
            dot_c_in2 = map[1][0][1]; 
            dot_e_in2 = map[1][0][2];

            dot_a_in3 = map[1][1][0]; 
            dot_c_in3 = map[1][1][1]; 
            dot_e_in3 = map[1][1][2];  
          end
          18: begin
            dot_a_in1 = (opt[0]) ? 32'b0 : map[1][0][1];
            dot_c_in1 = (opt[0]) ? 32'b0 : map[1][0][2];
            dot_e_in1 = (opt[0]) ? 32'b0 : map[1][0][3];

            dot_a_in2 = map[1][0][1]; 
            dot_c_in2 = map[1][0][2]; 
            dot_e_in2 = map[1][0][3];

            dot_a_in3 = map[1][1][1]; 
            dot_c_in3 = map[1][1][2]; 
            dot_e_in3 = map[1][1][3];  
          end
          19: begin
            dot_a_in1 = (opt[0]) ? 32'b0 : map[1][0][2]; 
            dot_c_in1 = (opt[0]) ? 32'b0 : map[1][0][3]; 
            dot_e_in1 = (opt[0]) ? 32'b0 : map[1][0][3];

            dot_a_in2 = map[1][0][2]; 
            dot_c_in2 = map[1][0][3]; 
            dot_e_in2 = (opt[0]) ? 32'b0 : map[1][0][3]; 

            dot_a_in3 = map[1][1][2]; 
            dot_c_in3 = map[1][1][3]; 
            dot_e_in3 = (opt[0]) ? 32'b0 : map[1][1][3];  
          end
          20: begin
            dot_a_in1 = (opt[0]) ? 32'b0 : map[1][0][0]; 
            dot_c_in1 = map[1][0][0]; 
            dot_e_in1 = map[1][0][1];

            dot_a_in2 = (opt[0]) ? 32'b0 : map[1][1][0];  
            dot_c_in2 = map[1][1][0]; 
            dot_e_in2 = map[1][1][1];

            dot_a_in3 = (opt[0]) ? 32'b0 : map[1][2][0];  
            dot_c_in3 = map[1][2][0]; 
            dot_e_in3 = map[1][2][1]; 
          end
          21: begin
            dot_a_in1 = map[1][0][0]; 
            dot_c_in1 = map[1][0][1]; 
            dot_e_in1 = map[1][0][2];

            dot_a_in2 = map[1][1][0]; 
            dot_c_in2 = map[1][1][1]; 
            dot_e_in2 = map[1][1][2];

            dot_a_in3 = map[1][2][0]; 
            dot_c_in3 = map[1][2][1]; 
            dot_e_in3 = map[1][2][2]; 
          end
          22: begin
            dot_a_in1 = map[1][0][1]; 
            dot_c_in1 = map[1][0][2]; 
            dot_e_in1 = map[1][0][3];

            dot_a_in2 = map[1][1][1]; 
            dot_c_in2 = map[1][1][2]; 
            dot_e_in2 = map[1][1][3];

            dot_a_in3 = map[1][2][1]; 
            dot_c_in3 = map[1][2][2]; 
            dot_e_in3 = map[1][2][3];
          end
          23: begin
            dot_a_in1 = map[1][0][2]; 
            dot_c_in1 = map[1][0][3]; 
            dot_e_in1 = (opt[0]) ? 32'b0 : map[1][0][3]; 

            dot_a_in2 = map[1][1][2]; 
            dot_c_in2 = map[1][1][3]; 
            dot_e_in2 = (opt[0]) ? 32'b0 : map[1][1][3];

            dot_a_in3 = map[1][2][2]; 
            dot_c_in3 = map[1][2][3]; 
            dot_e_in3 = (opt[0]) ? 32'b0 : map[1][2][3];  
          end
          24: begin
            dot_a_in1 = (opt[0]) ? 32'b0 : map[1][1][0]; 
            dot_c_in1 = map[1][1][0]; 
            dot_e_in1 = map[1][1][1];

            dot_a_in2 = (opt[0]) ? 32'b0 : map[1][2][0];  
            dot_c_in2 = map[1][2][0]; 
            dot_e_in2 = map[1][2][1];

            dot_a_in3 = (opt[0]) ? 32'b0 : map[1][3][0];  
            dot_c_in3 = map[1][3][0]; 
            dot_e_in3 = map[1][3][1]; 
          end
          25: begin
            dot_a_in1 = map[1][1][0]; 
            dot_c_in1 = map[1][1][1]; 
            dot_e_in1 = map[1][1][2];

            dot_a_in2 = map[1][2][0]; 
            dot_c_in2 = map[1][2][1]; 
            dot_e_in2 = map[1][2][2];

            dot_a_in3 = map[1][3][0]; 
            dot_c_in3 = map[1][3][1]; 
            dot_e_in3 = map[1][3][2]; 
          end
          26: begin
            dot_a_in1 = map[1][1][1]; 
            dot_c_in1 = map[1][1][2]; 
            dot_e_in1 = map[1][1][3];

            dot_a_in2 = map[1][2][1]; 
            dot_c_in2 = map[1][2][2]; 
            dot_e_in2 = map[1][2][3];

            dot_a_in3 = map[1][3][1]; 
            dot_c_in3 = map[1][3][2]; 
            dot_e_in3 = map[1][3][3];
          end
          27: begin
            dot_a_in1 = map[1][1][2]; 
            dot_c_in1 = map[1][1][3]; 
            dot_e_in1 = (opt[0]) ? 32'b0 : map[1][1][3]; 

            dot_a_in2 = map[1][2][2]; 
            dot_c_in2 = map[1][2][3]; 
            dot_e_in2 = (opt[0]) ? 32'b0 : map[1][2][3]; 

            dot_a_in3 = map[1][3][2]; 
            dot_c_in3 = map[1][3][3]; 
            dot_e_in3 = (opt[0]) ? 32'b0 : map[1][3][3];   
          end
          28: begin
            dot_a_in1 = (opt[0]) ? 32'b0 : map[1][2][0];  
            dot_c_in1 = map[1][2][0]; 
            dot_e_in1 = map[1][2][1];

            dot_a_in2 = (opt[0]) ? 32'b0 : map[1][3][0];  
            dot_c_in2 = map[1][3][0]; 
            dot_e_in2 = map[1][3][1];

            dot_a_in3 = (opt[0]) ? 32'b0 : map[1][3][0]; 
            dot_c_in3 = (opt[0]) ? 32'b0 : map[1][3][0]; 
            dot_e_in3 = (opt[0]) ? 32'b0 : map[1][3][1]; 
          end
          29: begin
            dot_a_in1 = map[1][2][0]; 
            dot_c_in1 = map[1][2][1]; 
            dot_e_in1 = map[1][2][2];

            dot_a_in2 = map[1][3][0]; 
            dot_c_in2 = map[1][3][1]; 
            dot_e_in2 = map[1][3][2];

            dot_a_in3 = (opt[0]) ? 32'b0 : map[1][3][0]; 
            dot_c_in3 = (opt[0]) ? 32'b0 : map[1][3][1]; 
            dot_e_in3 = (opt[0]) ? 32'b0 : map[1][3][2]; 
          end
          30: begin
            dot_a_in1 = map[1][2][1]; 
            dot_c_in1 = map[1][2][2]; 
            dot_e_in1 = map[1][2][3];
            
            dot_a_in2 = map[1][3][1]; 
            dot_c_in2 = map[1][3][2]; 
            dot_e_in2 = map[1][3][3];

            dot_a_in3 = (opt[0]) ? 32'b0 : map[1][3][1]; 
            dot_c_in3 = (opt[0]) ? 32'b0 : map[1][3][2]; 
            dot_e_in3 = (opt[0]) ? 32'b0 : map[1][3][3];
          end
          31: begin
            dot_a_in1 = map[1][2][2]; 
            dot_c_in1 = map[1][2][3]; 
            dot_e_in1 = (opt[0]) ? 32'b0 : map[1][2][3];

            dot_a_in2 = map[1][3][2]; 
            dot_c_in2 = map[1][3][3]; 
            dot_e_in2 = (opt[0]) ? 32'b0 : map[1][3][3];

            dot_a_in3 = (opt[0]) ? 32'b0 : map[1][3][2]; 
            dot_c_in3 = (opt[0]) ? 32'b0 : map[1][3][3]; 
            dot_e_in3 = (opt[0]) ? 32'b0 : map[1][3][3];  
          end
          // 16: begin
          //   dot_a_in1 = 32'b0; 
          //   dot_c_in1 = 32'b0; 
          //   dot_e_in1 = 32'b0;

          //   dot_a_in2 = 32'b0; 
          //   dot_c_in2 = map[1][0][0]; 
          //   dot_e_in2 = map[1][0][1];

          //   dot_a_in3 = 32'b0; 
          //   dot_c_in3 = map[1][1][0]; 
          //   dot_e_in3 = map[1][1][1]; 
          // end
          // 17: begin
          //   dot_a_in1 = 32'b0; 
          //   dot_c_in1 = 32'b0; 
          //   dot_e_in1 = 32'b0;

          //   dot_a_in2 = map[1][0][0]; 
          //   dot_c_in2 = map[1][0][1]; 
          //   dot_e_in2 = map[1][0][2];

          //   dot_a_in3 = map[1][1][0]; 
          //   dot_c_in3 = map[1][1][1]; 
          //   dot_e_in3 = map[1][1][2];  
          // end
          // 18: begin
          //   dot_a_in1 = 32'b0; 
          //   dot_c_in1 = 32'b0; 
          //   dot_e_in1 = 32'b0;

          //   dot_a_in2 = map[1][0][1]; 
          //   dot_c_in2 = map[1][0][2]; 
          //   dot_e_in2 = map[1][0][3];

          //   dot_a_in3 = map[1][1][1]; 
          //   dot_c_in3 = map[1][1][2]; 
          //   dot_e_in3 = map[1][1][3];  
          // end
          // 19: begin
          //   dot_a_in1 = 32'b0; 
          //   dot_c_in1 = 32'b0; 
          //   dot_e_in1 = 32'b0;

          //   dot_a_in2 = map[1][0][2]; 
          //   dot_c_in2 = map[1][0][3]; 
          //   dot_e_in2 = 32'b0;

          //   dot_a_in3 = map[1][1][2]; 
          //   dot_c_in3 = map[1][1][3]; 
          //   dot_e_in3 = 32'b0;  
          // end
          // 20: begin
          //   dot_a_in1 = 32'b0; 
          //   dot_c_in1 = map[1][0][0]; 
          //   dot_e_in1 = map[1][0][1];

          //   dot_a_in2 = 32'b0; 
          //   dot_c_in2 = map[1][1][0]; 
          //   dot_e_in2 = map[1][1][1];

          //   dot_a_in3 = 32'b0; 
          //   dot_c_in3 = map[1][2][0]; 
          //   dot_e_in3 = map[1][2][1]; 
          // end
          // 21: begin
          //   dot_a_in1 = map[1][0][0]; 
          //   dot_c_in1 = map[1][0][1]; 
          //   dot_e_in1 = map[1][0][2];

          //   dot_a_in2 = map[1][1][0]; 
          //   dot_c_in2 = map[1][1][1]; 
          //   dot_e_in2 = map[1][1][2];

          //   dot_a_in3 = map[1][2][0];
          //   dot_c_in3 = map[1][2][1]; 
          //   dot_e_in3 = map[1][2][2]; 
          // end
          // 22: begin
          //   dot_a_in1 = map[1][0][1]; 
          //   dot_c_in1 = map[1][0][2]; 
          //   dot_e_in1 = map[1][0][3];

          //   dot_a_in2 = map[1][1][1]; 
          //   dot_c_in2 = map[1][1][2]; 
          //   dot_e_in2 = map[1][1][3];

          //   dot_a_in3 = map[1][2][1]; 
          //   dot_c_in3 = map[1][2][2]; 
          //   dot_e_in3 = map[1][2][3];
          // end
          // 23: begin
          //   dot_a_in1 = map[1][0][2]; 
          //   dot_c_in1 = map[1][0][3]; 
          //   dot_e_in1 = 32'b0;

          //   dot_a_in2 = map[1][1][2]; 
          //   dot_c_in2 = map[1][1][3]; 
          //   dot_e_in2 = 32'b0;

          //   dot_a_in3 = map[1][2][2]; 
          //   dot_c_in3 = map[1][2][3]; 
          //   dot_e_in3 = 32'b0;  
          // end
          // 24: begin
          //   dot_a_in1 = 32'b0; 
          //   dot_c_in1 = map[1][1][0];
          //   dot_e_in1 = map[1][1][1];

          //   dot_a_in2 = 32'b0; 
          //   dot_c_in2 = map[1][2][0]; 
          //   dot_e_in2 = map[1][2][1];

          //   dot_a_in3 = 32'b0; 
          //   dot_c_in3 = map[1][3][0]; 
          //   dot_e_in3 = map[1][3][1]; 
          // end
          // 25: begin
          //   dot_a_in1 = map[1][1][0]; 
          //   dot_c_in1 = map[1][1][1]; 
          //   dot_e_in1 = map[1][1][2];

          //   dot_a_in2 = map[1][2][0]; 
          //   dot_c_in2 = map[1][2][1]; 
          //   dot_e_in2 = map[1][2][2];

          //   dot_a_in3 = map[1][3][0]; 
          //   dot_c_in3 = map[1][3][1]; 
          //   dot_e_in3 = map[1][3][2]; 
          // end
          // 26: begin
          //   dot_a_in1 = map[1][1][1]; 
          //   dot_c_in1 = map[1][1][2]; 
          //   dot_e_in1 = map[1][1][3];

          //   dot_a_in2 = map[1][2][1]; 
          //   dot_c_in2 = map[1][2][2]; 
          //   dot_e_in2 = map[1][2][3];

          //   dot_a_in3 = map[1][3][1]; 
          //   dot_c_in3 = map[1][3][2]; 
          //   dot_e_in3 = map[1][3][3];
          // end
          // 27: begin
          //   dot_a_in1 = map[1][1][2]; 
          //   dot_c_in1 = map[1][1][3]; 
          //   dot_e_in1 = 32'b0;

          //   dot_a_in2 = map[1][2][2]; 
          //   dot_c_in2 = map[1][2][3]; 
          //   dot_e_in2 = 32'b0;

          //   dot_a_in3 = map[1][3][2]; 
          //   dot_c_in3 = map[1][3][3]; 
          //   dot_e_in3 = 32'b0;  
          // end
          // 28: begin
          //   dot_a_in1 = 32'b0; 
          //   dot_c_in1 = map[1][2][0]; 
          //   dot_e_in1 = map[1][2][1];

          //   dot_a_in2 = 32'b0; 
          //   dot_c_in2 = map[1][3][0]; 
          //   dot_e_in2 = map[1][3][1];

          //   dot_a_in3 = 32'b0; 
          //   dot_c_in3 = 32'b0; 
          //   dot_e_in3 = 32'b0; 
          // end
          // 29: begin
          //   dot_a_in1 = map[1][2][0]; 
          //   dot_c_in1 = map[1][2][1]; 
          //   dot_e_in1 = map[1][2][2];

          //   dot_a_in2 = map[1][3][0]; 
          //   dot_c_in2 = map[1][3][1]; 
          //   dot_e_in2 = map[1][3][2];

          //   dot_a_in3 = 32'b0; 
          //   dot_c_in3 = 32'b0; 
          //   dot_e_in3 = 32'b0; 
          // end
          // 30: begin
          //   dot_a_in1 = map[1][2][1]; 
          //   dot_c_in1 = map[1][2][2]; 
          //   dot_e_in1 = map[1][2][3];

          //   dot_a_in2 = map[1][3][1]; 
          //   dot_c_in2 = map[1][3][2]; 
          //   dot_e_in2 = map[1][3][3];

          //   dot_a_in3 = 32'b0; 
          //   dot_c_in3 = 32'b0; 
          //   dot_e_in3 = 32'b0;
          // end
          // 31: begin
          //   dot_a_in1 = map[1][2][2]; 
          //   dot_c_in1 = map[1][2][3]; 
          //   dot_e_in1 = 32'b0;

          //   dot_a_in2 = map[1][3][2]; 
          //   dot_c_in2 = map[1][3][3]; 
          //   dot_e_in2 = 32'b0;

          //   dot_a_in3 = 32'b0; 
          //   dot_c_in3 = 32'b0;
          //   dot_e_in3 = 32'b0;  
          // end


          default: begin  
            dot_a_in1 = 32'b0; dot_c_in1 = 32'b0; dot_e_in1 = 32'b0;
            dot_a_in2 = 32'b0; dot_c_in2 = 32'b0; dot_e_in2 = 32'b0;
            dot_a_in3 = 32'b0; dot_c_in3 = 32'b0; dot_e_in3 = 32'b0; 
          end
        endcase
      end
      MATRIXMULT:begin
        case (cnt_state)
          7'd0:begin
            dot_a_in1 = max_pool[0][0]; dot_b_in1 = weight[0][0]; dot_c_in1 = max_pool[0][1]; // map0 : row1 * col1
            dot_d_in1 = weight[1][0]; dot_e_in1 = 32'b0; dot_f_in1 = 32'b0;
            dot_a_in2 = max_pool[0][0]; dot_b_in2 = weight[0][1]; dot_c_in2 = max_pool[0][1]; // map0 : row1 * col2
            dot_d_in2 = weight[1][1]; dot_e_in2 = 32'b0; dot_f_in2 = 32'b0;
            dot_a_in3 = max_pool[0][2]; dot_b_in3 = weight[0][0]; dot_c_in3 = max_pool[0][3]; // map0 : row2 * col1
            dot_d_in3 = weight[1][0]; dot_e_in3 = 32'b0; dot_f_in3 = 32'b0;
          end 
          7'd1:begin
            dot_a_in1 = max_pool[0][2]; dot_b_in1 = weight[0][1]; dot_c_in1 = max_pool[0][3]; // map0 : row2 * col2
            dot_d_in1 = weight[1][1]; dot_e_in1 = 32'b0; dot_f_in1 = 32'b0;
            dot_a_in2 = max_pool[1][0]; dot_b_in2 = weight[0][0]; dot_c_in2 = max_pool[1][1]; // map1 : row1 * col1
            dot_d_in2 = weight[1][0]; dot_e_in2 = 32'b0; dot_f_in2 = 32'b0;
            dot_a_in3 = max_pool[1][0]; dot_b_in3 = weight[0][1]; dot_c_in3 = max_pool[1][1]; // map1 : row1 * col2
            dot_d_in3 = weight[1][1]; dot_e_in3 = 32'b0; dot_f_in3 = 32'b0;
          end 
          7'd2:begin
            dot_a_in1 = max_pool[1][2]; dot_b_in1 = weight[0][0]; dot_c_in1 = max_pool[1][3]; // map1 : row2 * col1
            dot_d_in1 = weight[1][0]; dot_e_in1 = 32'b0; dot_f_in1 = 32'b0;
            dot_a_in2 = max_pool[1][2]; dot_b_in2 = weight[0][1]; dot_c_in2 = max_pool[1][3]; // map1 : row2 * col2
            dot_d_in2 = weight[1][1]; dot_e_in2 = 32'b0; dot_f_in2 = 32'b0;
            dot_a_in3 = 32'b0; dot_b_in3 = 32'b0; dot_c_in3 = 32'b0; 
            dot_d_in3 = 32'b0; dot_e_in3 = 32'b0; dot_f_in3 = 32'b0;
          end 
          default: begin
            dot_a_in1 = 32'b0; dot_b_in1 = 32'b0; dot_c_in1 = 32'b0; dot_d_in1 = 32'b0; dot_e_in1 = 32'b0; dot_f_in1= 32'b0;
            dot_a_in2 = 32'b0; dot_b_in2 = 32'b0; dot_c_in2 = 32'b0; dot_d_in2 = 32'b0; dot_e_in2 = 32'b0; dot_f_in2= 32'b0;
            dot_a_in3 = 32'b0; dot_b_in3 = 32'b0; dot_c_in3 = 32'b0; dot_d_in3 = 32'b0; dot_e_in3 = 32'b0; dot_f_in3= 32'b0;
          end
        endcase
      end
      default: begin
        dot_a_in1 = 32'b0; dot_b_in1 = 32'b0; dot_c_in1 = 32'b0; dot_d_in1 = 32'b0; dot_e_in1 = 32'b0; dot_f_in1= 32'b0;
        dot_a_in2 = 32'b0; dot_b_in2 = 32'b0; dot_c_in2 = 32'b0; dot_d_in2 = 32'b0; dot_e_in2 = 32'b0; dot_f_in2= 32'b0;
        dot_a_in3 = 32'b0; dot_b_in3 = 32'b0; dot_c_in3 = 32'b0; dot_d_in3 = 32'b0; dot_e_in3 = 32'b0; dot_f_in3= 32'b0;
      end
    endcase
end

always @(*) begin //add_in1~6
    case (c_state)
      IDLE,CONVOLUTION: begin
        add_in1 = dot_3_1_tmp; 
        add_in2 = dot_3_2_tmp; 
        add_in3 = dot_3_3_tmp; 
        add_in4 = map[map_channel][x_y_map[3:2]][x_y_map[1:0]]; 
        add_in5 = add_1; 
        add_in6 = add_2;
      end
      EQUALIZATION:begin
        if (cnt_state != 0) begin
           add_in1 = dot_3_1_tmp; 
           add_in2 = dot_3_2_tmp; 
           add_in3 = dot_3_3_tmp; 
           add_in4 = add_1; 
           add_in5 = 32'b0; 
           add_in6 = 32'b0;
        end
        else begin
           add_in1 = 32'b0;
           add_in2 = 32'b0;
           add_in3 = 32'b0;
           add_in4 = 32'b0;
           add_in5 = 32'b0;
           add_in6 = 32'b0;
        end
      end
      NORMAL_ACTI:begin
        case (cnt_state)
          7'd0: begin // add1:max1 - min1  add2:x10 - min1
            add_in1 = cmp_out5; add_in2 = {1'b1-cmp_out8[31],cmp_out8[30:0]}; 
            add_in3 = max_pool[0][0]; add_in4 = {1'b1-cmp_out8[31],cmp_out8[30:0]}; 
            add_in5 = 32'b0; add_in6 = 32'b0;
          end
          7'd1: begin // add1:max2 - min2  add2:x11 - min1
            add_in1 = cmp_out5; add_in2 = {1'b1-cmp_out8[31],cmp_out8[30:0]}; 
            add_in3 = max_pool[0][1]; add_in4 = {1'b1-max[1][31],max[1][30:0]}; 
            add_in5 = 32'b0; add_in6 = 32'b0;
          end
          7'd2: begin // add1:exp10_up  add2:x12 - min1  add3:exp10_down
            add_in1 = 32'b0; 
            add_in2 = 32'b0; 
            add_in3 = max_pool[0][2]; add_in4 = {1'b1-max[1][31],max[1][30:0]}; 
            add_in5 = 32'b0;  
            add_in6 = 32'b0;
          end
          7'd3: begin // add1:exp11_up  add2:x13 - min1  add3:exp11_down
            add_in1 = (!opt[1]) ? 32'h3f80_0000 : exp_tmp2[0][0]; 
            add_in2 = (!opt[1]) ? 32'b0 : {~exp_tmp2[1][0][31],exp_tmp2[1][0][30:0]};  
            add_in3 = max_pool[0][3]; add_in4 = {1'b1-max[1][31],max[1][30:0]}; 
            add_in5 = (!opt[1]) ? 32'h3f80_0000 : exp_tmp2[0][0];  
            add_in6 = (!opt[1]) ? exp_tmp2[1][0] : exp_tmp2[1][0];
          end
          7'd4: begin // add1:exp12_up  add2:x20 - min1  add3:exp12_down
            add_in1 = (!opt[1]) ? 32'h3f80_0000 : exp_tmp2[0][1]; 
            add_in2 = (!opt[1]) ? 32'b0 : {~exp_tmp2[1][1][31],exp_tmp2[1][1][30:0]};   
            add_in3 = max_pool[1][0]; add_in4 = {1'b1-max[3][31],max[3][30:0]}; 
            add_in5 = (!opt[1]) ? 32'h3f80_0000 : exp_tmp2[0][1];  
            add_in6 = (!opt[1]) ? exp_tmp2[1][1] : exp_tmp2[1][1];
          end
          7'd5: begin // add1:exp13_up  add2:x21 - min1  add3:exp13_down
            add_in1 = (!opt[1]) ? 32'h3f80_0000 : exp_tmp2[0][2]; 
            add_in2 = (!opt[1]) ? 32'b0 : {~exp_tmp2[1][2][31],exp_tmp2[1][2][30:0]};   
            add_in3 = max_pool[1][1]; add_in4 = {1'b1-max[3][31],max[3][30:0]}; 
            add_in5 = (!opt[1]) ? 32'h3f80_0000 : exp_tmp2[0][2];  
            add_in6 = (!opt[1]) ? exp_tmp2[1][2] : exp_tmp2[1][2];
          end
          7'd6: begin // add1:exp20_up  add2:x22 - min1  add3:exp20_down
            add_in1 = (!opt[1]) ? 32'h3f80_0000 : exp_tmp2[0][3]; 
            add_in2 = (!opt[1]) ? 32'b0 : {~exp_tmp2[1][3][31],exp_tmp2[1][3][30:0]};  
            add_in3 = max_pool[1][2]; add_in4 = {1'b1-max[3][31],max[3][30:0]}; 
            add_in5 = (!opt[1]) ? 32'h3f80_0000 : exp_tmp2[0][3];  
            add_in6 = (!opt[1]) ? exp_tmp2[1][3] : exp_tmp2[1][3];
          end
          7'd7: begin // add1:exp21_up  add2:x23 - min1  add3:exp21_down
            add_in1 = (!opt[1]) ? 32'h3f80_0000 : exp_tmp2[0][4]; 
            add_in2 = (!opt[1]) ? 32'b0 : {~exp_tmp2[1][4][31],exp_tmp2[1][4][30:0]};   
            add_in3 = max_pool[1][3]; add_in4 = {1'b1-max[3][31],max[3][30:0]}; 
            add_in5 = (!opt[1]) ? 32'h3f80_0000 : exp_tmp2[0][4];  
            add_in6 = (!opt[1]) ? exp_tmp2[1][4] : exp_tmp2[1][4];
          end
          7'd8: begin // add1:exp22_up  add2:0  add3:exp22_down
            add_in1 = (!opt[1]) ? 32'h3f80_0000 : exp_tmp2[0][5]; 
            add_in2 = (!opt[1]) ? 32'b0 : {~exp_tmp2[1][5][31],exp_tmp2[1][5][30:0]};   
            add_in3 = 32'b0; add_in4 = 32'b0; 
            add_in5 = (!opt[1]) ? 32'h3f80_0000 : exp_tmp2[0][5];  
            add_in6 = (!opt[1]) ? exp_tmp2[1][5] : exp_tmp2[1][5];
          end
          7'd9: begin // add1:exp23_up  add2:0  add3:exp23_down
            add_in1 = (!opt[1]) ? 32'h3f80_0000 : exp_tmp2[0][6]; 
            add_in2 = (!opt[1]) ? 32'b0 : {~exp_tmp2[1][6][31],exp_tmp2[1][6][30:0]};   
            add_in3 = 32'b0; add_in4 = 32'b0; 
            add_in5 = (!opt[1]) ? 32'h3f80_0000 : exp_tmp2[0][6];  
            add_in6 = (!opt[1]) ? exp_tmp2[1][6] : exp_tmp2[1][6];
          end
          7'd10: begin // add1:exp23_up  add2:distance12  add3:exp23_down
            add_in1 = (!opt[1]) ? 32'h3f80_0000 : exp_tmp2[0][7]; 
            add_in2 = (!opt[1]) ? 32'b0 : {~exp_tmp2[1][7][31],exp_tmp2[1][7][30:0]};  
            add_in3 = 32'b0; add_in4 = 32'b0; 
            add_in5 = (!opt[1]) ? 32'h3f80_0000 : exp_tmp2[0][7];  
            add_in6 = (!opt[1]) ? exp_tmp2[1][7] : exp_tmp2[1][7];
          end
          7'd14: begin // add1:dis1  add2:0  add3:0
            add_in1 = max_pool[0][0]; 
            add_in2 = {~max_pool[1][0][31],max_pool[1][0][30:0]};  
            add_in3 = 32'b0; 
            add_in4 = 32'b0; 
            add_in5 = 32'b0;  
            add_in6 = 32'b0;
          end
          7'd15: begin // add1:dis2  add2:dis1 + dis2  add3:0
            add_in1 = max_pool[0][1]; 
            add_in2 = {~max_pool[1][1][31],max_pool[1][1][30:0]};  
            add_in3 = {1'b0,add_1[30:0]}; 
            add_in4 = max[0]; 
            add_in5 = 32'b0;  
            add_in6 = 32'b0;
          end
          7'd16: begin // add1:dis2  add2:dis1 + dis2  add3:0
            add_in1 = max_pool[0][2]; 
            add_in2 = {~max_pool[1][2][31],max_pool[1][2][30:0]};  
            add_in3 = {1'b0,add_1[30:0]}; 
            add_in4 = max[0]; 
            add_in5 = 32'b0;  
            add_in6 = 32'b0;
          end
          7'd17: begin // add1:dis2  add2:dis1 + dis2  add3:0
            add_in1 = max_pool[0][3]; 
            add_in2 = {~max_pool[1][3][31],max_pool[1][3][30:0]};  
            add_in3 = {1'b0,add_1[30:0]}; 
            add_in4 = max[0]; 
            add_in5 = 32'b0;  
            add_in6 = 32'b0;
          end
          default: begin
            add_in1 = 32'b0; add_in2 = 32'b0; add_in3 = 32'b0; add_in4 = 32'b0; add_in5 = 32'b0; add_in6 = 32'b0;
          end
        endcase
      end
      default: begin
        add_in1 = 32'b0; add_in2 = 32'b0; add_in3 = 32'b0; add_in4 = 32'b0; add_in5 = 32'b0; add_in6 = 32'b0;
      end
    endcase
end


always @(*) begin //div_in1~2
    case (c_state)
      EQUALIZATION:begin
          div_in1 = add_2; div_in2 = 32'h41100000;
      end
      NORMAL_ACTI:begin
        case (cnt_state)
          7'd1: begin div_in1 = max_pool[0][0]; div_in2 = add_tmp[0]; end
          7'd2: begin div_in1 = max_pool[0][1]; div_in2 = add_tmp[0]; end
          7'd3: begin div_in1 = max_pool[0][2]; div_in2 = add_tmp[0]; end
          7'd4: begin div_in1 = max_pool[0][3]; div_in2 = add_tmp[0]; end
          7'd5: begin div_in1 = max_pool[1][0]; div_in2 = add_tmp[1]; end
          7'd6: begin div_in1 = max_pool[1][1]; div_in2 = add_tmp[1]; end
          7'd7: begin div_in1 = max_pool[1][2]; div_in2 = add_tmp[1]; end
          7'd8: begin div_in1 = max_pool[1][3]; div_in2 = add_tmp[1]; end
          7'd9:  begin div_in1 = exp_up[0]; div_in2 = add_tmp[2]; end
          7'd10: begin div_in1 = exp_up[1]; div_in2 = add_tmp[3]; end
          7'd11: begin div_in1 = exp_up[2]; div_in2 = add_tmp[4]; end
          7'd12: begin div_in1 = exp_up[3]; div_in2 = add_tmp[5]; end
          7'd13: begin div_in1 = exp_up[4]; div_in2 = add_tmp[6]; end
          7'd14: begin div_in1 = exp_up[5]; div_in2 = add_tmp[7]; end
          7'd15: begin div_in1 = exp_up[6]; div_in2 = add_tmp[8]; end
          7'd16: begin div_in1 = exp_up[7]; div_in2 = add_tmp[9]; end
          default: begin div_in1 = 32'b0; div_in2 = 32'b0; end
        endcase
      end
      default: begin
        div_in1 = 32'b0; div_in2 = 32'b0;
      end
    endcase
end


always @(*) begin // exp_in1~2
    case (c_state)
      NORMAL_ACTI:begin
        case (cnt_state)
          7'd2: begin exp_in1 = max_pool[0][0]; exp_in2 = {1'b1 - max_pool[0][0][31],max_pool[0][0][30:0]};end
          7'd3: begin exp_in1 = max_pool[0][1]; exp_in2 = {1'b1 - max_pool[0][1][31],max_pool[0][1][30:0]};end
          7'd4: begin exp_in1 = max_pool[0][2]; exp_in2 = {1'b1 - max_pool[0][2][31],max_pool[0][2][30:0]};end
          7'd5: begin exp_in1 = max_pool[0][3]; exp_in2 = {1'b1 - max_pool[0][3][31],max_pool[0][3][30:0]};end
          7'd6: begin exp_in1 = max_pool[1][0]; exp_in2 = {1'b1 - max_pool[1][0][31],max_pool[1][0][30:0]};end
          7'd7: begin exp_in1 = max_pool[1][1]; exp_in2 = {1'b1 - max_pool[1][1][31],max_pool[1][1][30:0]};end
          7'd8: begin exp_in1 = max_pool[1][2]; exp_in2 = {1'b1 - max_pool[1][2][31],max_pool[1][2][30:0]};end
          7'd9: begin exp_in1 = max_pool[1][3]; exp_in2 = {1'b1 - max_pool[1][3][31],max_pool[1][3][30:0]};end
          default: begin exp_in1 = 32'b0; exp_in2 = 32'b0;end
        endcase
      end
      default: begin exp_in1 = 32'b0; exp_in2 = 32'b0;end
    endcase
end
//---------------------------------------------------------------------
//   Registers
//---------------------------------------------------------------------

always @(posedge G_clock_dot_out or negedge rst_n) begin
  if (!rst_n) begin
    dot_3_1_tmp <= 32'b0;
    dot_3_2_tmp <= 32'b0;
    dot_3_3_tmp <= 32'b0;
  end 
  else if (ctrl1 || ctrl2) begin
    if (cnt_input > 7'd8) begin
      dot_3_1_tmp <= dot_3_1_out;
      dot_3_2_tmp <= dot_3_2_out;
      dot_3_3_tmp <= dot_3_3_out;
    end
  end
  else if (ctrl3) begin
    dot_3_1_tmp <= dot_3_1_out;
    dot_3_2_tmp <= dot_3_2_out;
    dot_3_3_tmp <= dot_3_3_out;
  end
end


// always @(posedge clk or negedge rst_n) begin
//   if (!rst_n) begin
//     dot_3_1_tmp <= 32'b0;
//     dot_3_2_tmp <= 32'b0;
//     dot_3_3_tmp <= 32'b0;
//   end else begin
//     case (c_state)
//       IDLE,CONVOLUTION:begin
//         if (cnt_input > 7'd8) begin
//           dot_3_1_tmp <= dot_3_1_out;
//           dot_3_2_tmp <= dot_3_2_out;
//           dot_3_3_tmp <= dot_3_3_out;
//         end
//         else  begin
//           dot_3_1_tmp <= dot_3_1_tmp;
//           dot_3_2_tmp <= dot_3_2_tmp;
//           dot_3_3_tmp <= dot_3_3_tmp;
//         end 
//       end
//       EQUALIZATION:begin
//           dot_3_1_tmp <= dot_3_1_out;
//           dot_3_2_tmp <= dot_3_2_out;
//           dot_3_3_tmp <= dot_3_3_out;
//       end
//       default:begin
//         dot_3_1_tmp <= dot_3_1_tmp;
//         dot_3_2_tmp <= dot_3_2_tmp;
//         dot_3_3_tmp <= dot_3_3_tmp;
//       end
//     endcase
//   end
// end



endmodule

//---------------------------------------------------------------------
//   IP module
//---------------------------------------------------------------------

module DW_fp_dp3_inst( inst_a, inst_b, inst_c, inst_d, inst_e,
      inst_f, inst_rnd, z_inst, status_inst );
  parameter inst_sig_width = 23;
  parameter inst_exp_width = 8;
  parameter inst_ieee_compliance = 0;
  parameter inst_arch_type = 0;
  input [inst_sig_width+inst_exp_width : 0] inst_a;
  input [inst_sig_width+inst_exp_width : 0] inst_b;
  input [inst_sig_width+inst_exp_width : 0] inst_c;
  input [inst_sig_width+inst_exp_width : 0] inst_d;
  input [inst_sig_width+inst_exp_width : 0] inst_e;
  input [inst_sig_width+inst_exp_width : 0] inst_f;
  input [2 : 0] inst_rnd;
  output [inst_sig_width+inst_exp_width : 0] z_inst;
  output [7 : 0] status_inst;
  // Instance of DW_fp_dp3
  DW_fp_dp3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type)
  U1 (
  .a(inst_a),
  .b(inst_b),
  .c(inst_c),
  .d(inst_d),
  .e(inst_e),
  .f(inst_f),
  .rnd(inst_rnd),
  .z(z_inst),
  .status(status_inst) );
endmodule

module DW_fp_add_inst( inst_a, inst_b, inst_rnd, z_inst, status_inst );
  parameter sig_width = 23;
  parameter exp_width = 8;
  parameter ieee_compliance = 0;
  input [sig_width+exp_width : 0] inst_a;
  input [sig_width+exp_width : 0] inst_b;
  input [2 : 0] inst_rnd;
  output [sig_width+exp_width : 0] z_inst;
  output [7 : 0] status_inst;
  // Instance of DW_fp_add
  DW_fp_add #(sig_width, exp_width, ieee_compliance)
  U1 ( .a(inst_a), .b(inst_b), .rnd(inst_rnd), .z(z_inst), .status(status_inst) );
endmodule

module DW_fp_cmp_inst( inst_a, inst_b, inst_zctr, aeqb_inst, altb_inst,
agtb_inst, unordered_inst, z0_inst, z1_inst, status0_inst,
status1_inst );
  parameter sig_width = 23;
  parameter exp_width = 8;
  parameter ieee_compliance = 0;
  input [sig_width+exp_width : 0] inst_a;
  input [sig_width+exp_width : 0] inst_b;
  input inst_zctr;
  output aeqb_inst;
  output altb_inst;
  output agtb_inst;
  output unordered_inst;
  output [sig_width+exp_width : 0] z0_inst;
  output [sig_width+exp_width : 0] z1_inst;
  output [7 : 0] status0_inst;
  output [7 : 0] status1_inst;
  // Instance of DW_fp_cmp
  DW_fp_cmp #(sig_width, exp_width, ieee_compliance)
  U1 ( .a(inst_a), .b(inst_b), .zctr(inst_zctr), .aeqb(aeqb_inst), 
  .altb(altb_inst), .agtb(agtb_inst), .unordered(unordered_inst), 
  .z0(z0_inst), .z1(z1_inst), .status0(status0_inst), 
  .status1(status1_inst) );
endmodule

module DW_fp_recip_inst( inst_a, inst_rnd, z_inst, status_inst );
  parameter inst_sig_width = 23;
  parameter inst_exp_width = 8;
  parameter inst_ieee_compliance = 0;
  parameter inst_faithful_round = 0;
  input [inst_sig_width+inst_exp_width : 0] inst_a;
  input [2 : 0] inst_rnd;
  output [inst_sig_width+inst_exp_width : 0] z_inst;
  output [7 : 0] status_inst;
  // Instance of DW_fp_recip
  DW_fp_recip #(inst_sig_width, inst_exp_width, inst_ieee_compliance,
  inst_faithful_round) U1 (
  .a(inst_a),
  .rnd(inst_rnd),
  .z(z_inst),
  .status(status_inst) );
endmodule

module DW_fp_mult_inst( inst_a, inst_b, inst_rnd, z_inst, status_inst );
  parameter sig_width = 23;
  parameter exp_width = 8;
  parameter ieee_compliance = 0;
  input [sig_width+exp_width : 0] inst_a;
  input [sig_width+exp_width : 0] inst_b;
  input [2 : 0] inst_rnd;
  output [sig_width+exp_width : 0] z_inst;
  output [7 : 0] status_inst;
  // Instance of DW_fp_mult
  DW_fp_mult #(sig_width, exp_width, ieee_compliance)
  U1 ( .a(inst_a), .b(inst_b), .rnd(inst_rnd), .z(z_inst), .status(status_inst) );
endmodule

module DW_fp_exp_inst( inst_a, z_inst, status_inst );
  parameter inst_sig_width = 23;
  parameter inst_exp_width = 8;
  parameter inst_ieee_compliance = 0;
  parameter inst_arch = 0;
  input [inst_sig_width+inst_exp_width : 0] inst_a;
  output [inst_sig_width+inst_exp_width : 0] z_inst;
  output [7 : 0] status_inst;
  // Instance of DW_fp_exp
  DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch) U1 (
  .a(inst_a),
  .z(z_inst),
  .status(status_inst) );
endmodule

module DW_fp_div_inst( inst_a, inst_b, inst_rnd, z_inst, status_inst );
  parameter sig_width = 23;
  parameter exp_width = 8;
  parameter ieee_compliance = 0;
  parameter faithful_round = 0;
  input [sig_width+exp_width : 0] inst_a;
  input [sig_width+exp_width : 0] inst_b;
  input [2 : 0] inst_rnd;
  output [sig_width+exp_width : 0] z_inst;
  output [7 : 0] status_inst;
  // Instance of DW_fp_div
  DW_fp_div #(sig_width, exp_width, ieee_compliance, faithful_round) U1
  ( .a(inst_a), .b(inst_b), .rnd(inst_rnd), .z(z_inst), .status(status_inst)
  );
endmodule
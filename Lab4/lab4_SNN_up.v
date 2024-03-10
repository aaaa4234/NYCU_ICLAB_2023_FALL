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

module SNN(
         //Input Port
         clk,
         rst_n,
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
parameter POOLING = 3'd2;
parameter MATRIXMULT = 3'd3;
parameter NORMAL_ACTI = 3'd4;
parameter OUT = 3'd5;
// IEEE floating point parameter
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;
parameter inst_arch = 0;
parameter inst_faithful_round = 0;
integer i,j,k;

input rst_n, clk, in_valid;
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
reg [31:0] max[0:3];
reg [31:0] max_pool[0:1][0:3];
reg [31:0] upside [0:9];
reg [31:0] exp_up [0:7];
reg [31:0] exp_tmp2 [0:1][0:7];
reg [31:0] add_tmp[0:7];
reg [1:0] opt,opt_next;
reg [31:0] dot_3_1_tmp,dot_3_2_tmp,dot_3_3_tmp;
reg [31:0] add_1_tmp;

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
reg [31:0] recip_in,recip_out;
reg [31:0] mult_in1,mult_in2;
reg [31:0] exp_in1,exp_in2,exp_out1,exp_out2;


wire [31:0] cmp_out1,cmp_out2,cmp_out3,cmp_out4,cmp_out5,cmp_out6,cmp_out7,cmp_out8;
wire [31:0] dot_3_1_out,dot_3_2_out,dot_3_3_out;
wire [31:0] mult_out1;

wire [2:0] rnd;
assign rnd = 3'b0;

//---------------------------------------------------------------------
//   count declaration
//---------------------------------------------------------------------
reg [6:0] cnt_input;
reg [3:0] cnt_16;
reg [6:0] cnt_state;

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

DW_fp_recip_inst recip1( .inst_a(recip_in), .inst_rnd(rnd), .z_inst(recip_out));

DW_fp_mult_inst mult1( .inst_a(mult_in1), .inst_b(mult_in2), .inst_rnd(rnd), .z_inst(mult_out1));

DW_fp_exp_inst exp1( .inst_a(exp_in1), .z_inst(exp_out1));
DW_fp_exp_inst exp2( .inst_a(exp_in2), .z_inst(exp_out2));
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
  // if (!rst_n) begin
  //   n_state = IDLE;
  // end else begin
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
          n_state = POOLING;
        end
        else begin
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
        n_state = IDLE;
      end
      default: begin
        n_state = c_state;
      end
    endcase
  //end
end



//---------------------------------------------------------------------
//   img / kernel / weight / opt / feature map / max / max_pool / upside / exp_up
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) // img_mid
  begin
    if (!rst_n)
      begin
        for (i = 0;i<6 ;i = i +1) begin
          for (j = 0;j < 6;j = j + 1) begin
            img[i][j] <= 32'b0;
          end
        end
      end
    else
      begin
        case (c_state)
          IDLE: begin
            if (in_valid) begin
              case (cnt_input)
                0: begin img[1][1] <= Img; img[0][0] <= (Opt[0]) ? 32'b0 : Img ; img[0][1] <= (Opt[0]) ? 32'b0 : Img ; img[1][0] <= (Opt[0]) ? 32'b0 : Img ; end
                16,32,48,64,80:    begin img[1][1] <= Img; img[0][0] <= (opt[0]) ? 32'b0 : Img ; img[0][1] <= (opt[0]) ? 32'b0 : Img ; img[1][0] <= (opt[0]) ? 32'b0 : Img ;end //
                1,17,33,49,65,81:  begin img[1][2] <= Img; img[0][2] <= (opt[0]) ? 32'b0 : Img ; end //
                2,18,34,50,66,82:  begin img[1][3] <= Img; img[0][3] <= (opt[0]) ? 32'b0 : Img ; end //
                3,19,35,51,67,83:  begin img[1][4] <= Img; img[0][4] <= (opt[0]) ? 32'b0 : Img ; img[0][5] <= (opt[0]) ? 32'b0 : Img ; img[1][5] <= (opt[0]) ? 32'b0 : Img ;end //
                4,20,36,52,68,84:  begin img[2][1] <= Img; img[2][0] <= (opt[0]) ? 32'b0 : Img ; end //
                5,21,37,53,69,85:  begin img[2][2] <= Img; end
                6,22,38,54,70,86:  begin img[2][3] <= Img; end
                7,23,39,55,71,87:  begin img[2][4] <= Img; img[2][5] <= (opt[0]) ? 32'b0 : Img ; end //
                8,24,40,56,72,88:  begin img[3][1] <= Img; img[3][0] <= (opt[0]) ? 32'b0 : Img ; end //
                9,25,41,57,73,89:  begin img[3][2] <= Img; end
                10,26,42,58,74,90: begin img[3][3] <= Img; end
                11,27,43,59,75,91: begin img[3][4] <= Img; img[3][5] <= (opt[0]) ? 32'b0 : Img ; end //
                12,28,44,60,76,92: begin img[4][1] <= Img; img[4][0] <= (opt[0]) ? 32'b0 : Img ; img[5][0] <= (opt[0]) ? 32'b0 : Img ; img[5][1] <= (opt[0]) ? 32'b0 : Img ;end //
                13,29,45,61,77,93: begin img[4][2] <= Img; img[5][2] <= (opt[0]) ? 32'b0 : Img ; end //
                14,30,46,62,78,94: begin img[4][3] <= Img; img[5][3] <= (opt[0]) ? 32'b0 : Img ; end //
                15,31,47,63,79,95: begin img[4][4] <= Img; img[5][4] <= (opt[0]) ? 32'b0 : Img ; img[5][5] <= (opt[0]) ? 32'b0 : Img ; img[4][5] <= (opt[0]) ? 32'b0 : Img ;end //
                default: begin 
                  for (i = 0;i<6 ;i = i +1) begin
                    for (j = 0;j < 6;j = j + 1) begin
                      img[i][j] <= img[i][j];
                    end
                  end
                end
              endcase
            end
            else begin
              for (i = 0;i<6 ;i = i +1) begin
                for (j = 0;j < 6;j = j + 1) begin
                  img[i][j] <= img[i][j];
                end
              end
            end  
          end  
              
          default: begin
              for (i = 0;i<6 ;i = i +1) begin
                for (j = 0;j < 6;j = j + 1) begin
                  img[i][j] <= img[i][j];
                end
              end
          end
        endcase
      end
  end

always @(posedge clk or negedge rst_n) // kernel
  begin
    if (!rst_n)
      begin
        for (i = 0;i<3 ;i = i+1 ) begin
          for (j = 0;j<3 ;j = j+1 ) begin
            for (k = 0;k<3 ;k = k+1 ) begin
              kernel[i][j][k] <= 32'b0;
            end
          end
        end
      end
    else
      begin
        if (in_valid) begin
          case (cnt_input)
            5'd0: kernel[0][0][0] <= Kernel;
            5'd1: kernel[0][0][1] <= Kernel;
            5'd2: kernel[0][0][2] <= Kernel;
            5'd3: kernel[0][1][0] <= Kernel;
            5'd4: kernel[0][1][1] <= Kernel;
            5'd5: kernel[0][1][2] <= Kernel;
            5'd6: kernel[0][2][0] <= Kernel;
            5'd7: kernel[0][2][1] <= Kernel;
            5'd8: kernel[0][2][2] <= Kernel;
            5'd9: kernel[1][0][0] <= Kernel;
            5'd10: kernel[1][0][1] <= Kernel;
            5'd11: kernel[1][0][2] <= Kernel;
            5'd12: kernel[1][1][0] <= Kernel;
            5'd13: kernel[1][1][1] <= Kernel;
            5'd14: kernel[1][1][2] <= Kernel;
            5'd15: kernel[1][2][0] <= Kernel;
            5'd16: kernel[1][2][1] <= Kernel;
            5'd17: kernel[1][2][2] <= Kernel;
            5'd18: kernel[2][0][0] <= Kernel;
            5'd19: kernel[2][0][1] <= Kernel;
            5'd20: kernel[2][0][2] <= Kernel;
            5'd21: kernel[2][1][0] <= Kernel;
            5'd22: kernel[2][1][1] <= Kernel;
            5'd23: kernel[2][1][2] <= Kernel;
            5'd24: kernel[2][2][0] <= Kernel;
            5'd25: kernel[2][2][1] <= Kernel;
            5'd26: kernel[2][2][2] <= Kernel;
            default: begin
              for (i = 0;i<3 ;i = i+1 ) begin
                for (j = 0;j<3 ;j = j+1 ) begin
                  for (k = 0;k<3 ;k = k+1 ) begin
                    kernel[i][j][k] <= kernel[i][j][k];
                  end
                end
              end
            end
          endcase
        end else begin
          for (i = 0;i<3 ;i = i+1 ) begin
            for (j = 0;j<3 ;j = j+1 ) begin
              for (k = 0;k<3 ;k = k+1 ) begin
                kernel[i][j][k] <= kernel[i][j][k];
              end
            end
          end
        end
      end
  end

always @(posedge clk or negedge rst_n) // weight
  begin
    if (!rst_n)
      begin
        weight[0][0] <= 32'b0;
        weight[0][1] <= 32'b0;
        weight[1][0] <= 32'b0;
        weight[1][1] <= 32'b0;
      end
    else
      begin
        if (in_valid) begin
          case (cnt_input)
            2'd0: weight[0][0] <= Weight;
            2'd1: weight[0][1] <= Weight;
            2'd2: weight[1][0] <= Weight;
            2'd3: weight[1][1] <= Weight;
            default: 
              begin
                weight[0][0] <= weight[0][0];
                weight[0][1] <= weight[0][1];
                weight[1][0] <= weight[1][0];
                weight[1][1] <= weight[1][1];
              end
          endcase
        end else begin
          weight[0][0] <= weight[0][0];
          weight[0][1] <= weight[0][1];
          weight[1][0] <= weight[1][0];
          weight[1][1] <= weight[1][1];
        end
      end
  end

always @(posedge clk or negedge rst_n) // opt
  begin
    if (!rst_n)
      begin
        opt <= 2'd0;
      end
    else
      begin
        case (c_state)
          IDLE: begin
            if (cnt_input == 0) begin
              opt <= Opt;
            end else begin
              opt <= opt;
            end
          end 
          default: opt <= opt;
        endcase
      end
  end  

always @(posedge clk or negedge rst_n) begin //map
  if (!rst_n) begin
    for (i = 0; i<4 ; i = i+1 ) begin
      for (j = 0; j<4 ; j = j+1 ) begin
          map[0][i][j] <= 32'b0;
          map[1][i][j] <= 32'b0;
      end
    end
  end 
  else begin

    case (c_state)
      IDLE,CONVOLUTION:begin
        if (cnt_input > 7'd9)
          map[map_channel][x_y_map[3:2]][x_y_map[1:0]] <= add_3;
        else  begin
          for (i = 0; i<4 ; i = i+1 ) begin
            for (j = 0; j<4 ; j = j+1 ) begin
                map[0][i][j] <= 32'b0;
                map[1][i][j] <= 32'b0;
            end
          end  
        end  
      end
      NORMAL_ACTI:begin
        if (cnt_state == 7'd17) begin
          for (i = 0; i<4 ; i = i+1 ) begin
                for (j = 0; j<4 ; j = j+1 ) begin
                    map[0][i][j] <= 32'b0;
                    map[1][i][j] <= 32'b0;
                end
          end
        end
      end
      default: begin
          for (i = 0; i<4 ; i = i+1 ) begin
            for (j = 0; j<4 ; j = j+1 ) begin
                map[0][i][j] <= 32'b0;
                map[1][i][j] <= 32'b0;
            end
          end  
        end  
    endcase
  end
end

always @(posedge clk or negedge rst_n) begin //max
  if (!rst_n) begin
      for (i = 0; i<4 ; i = i+1 ) begin
        max[i] <= 32'b0;
      end
    end
  else begin
    case (c_state)
      IDLE,CONVOLUTION:begin
        case (cnt_input)
          7'd0:begin
            for (i = 0; i<4 ; i = i+1 ) begin
              max[i] <= 32'b0;
            end
          end
          7'd48,7'd49,7'd50,7'd51,7'd56,7'd57,7'd58,7'd59,7'd96,7'd97,7'd98,7'd99,7'd104,7'd105: 
          begin max[0] <= cmp_out1; max[1] <= cmp_out2; max[2] <= cmp_out3; max[3] <= cmp_out4;end 
          default: max <= max;
        endcase
      end
      POOLING:begin
        case (cnt_state)
          7'd0: begin max[0] <= cmp_out5; max[1] <= cmp_out6; max[2] <= cmp_out7; max[3] <= cmp_out8;end 
          default: max <= max;
        endcase
      end
      MATRIXMULT: begin
        if (cnt_state == 7'd0) begin
          max[1] <= dot_3_3_out;
        end 
      end 
      NORMAL_ACTI:begin
        case (cnt_state)
          7'd0: begin max[0] <= cmp_out5; max[1] <= cmp_out8; end
          7'd1: begin max[2] <= cmp_out5; max[3] <= cmp_out8; end
          7'd14: begin max[0] <= {1'b0,add_1[30:0]}; end 
          7'd15: begin max[0] <= add_2; end
          7'd16: begin max[0] <= add_2; end
          7'd17: begin max[0] <= add_2; end
          default: max <= max;
        endcase
      end

      default: max <= max;
    endcase
  end
end

always @(posedge clk or negedge rst_n) begin //max_pool
  if (!rst_n) begin
      for (i = 0; i<4 ; i = i+1 ) begin
        max_pool[0][i] <= 32'b0;
        max_pool[1][i] <= 32'b0;
      end
    end
  else begin
    case (c_state)
      IDLE,CONVOLUTION:begin
        case (cnt_input)
          7'd0: begin  
            for (i = 0; i<4 ; i = i+1) begin
              max_pool[0][i] <= 32'b0;
              max_pool[1][i] <= 32'b0;
            end  
          end
          7'd49: begin max_pool[0][0] <= cmp_out1; end
          7'd51: begin max_pool[0][1] <= cmp_out1; end
          7'd57: begin max_pool[0][2] <= cmp_out1; end 
          7'd59: begin max_pool[0][3] <= cmp_out1; end
          7'd97: begin max_pool[1][0] <= cmp_out1; end
          7'd99: begin max_pool[1][1] <= cmp_out1; end
          7'd105: begin max_pool[1][2] <= cmp_out1; end 
          default: max_pool <= max_pool;
        endcase
      end
      POOLING:begin
        case (cnt_state)
          7'd0: begin max_pool[1][3] <= cmp_out5;end 
          default: max_pool <= max_pool;
        endcase
      end
      MATRIXMULT:begin
        case (cnt_state)
          7'd0: begin max_pool[0][0] <= dot_3_1_out; max_pool[0][1] <= dot_3_2_out; end
          7'd1: begin max_pool[0][2] <= max[1]; max_pool[0][3] <= dot_3_1_out;
                      max_pool[1][0] <= dot_3_2_out; max_pool[1][1] <= dot_3_3_out;end
          7'd2: begin max_pool[1][2] <= dot_3_1_out; max_pool[1][3] <= dot_3_2_out; end
          default: max_pool <= max_pool;
        endcase
      end
      NORMAL_ACTI:begin
        case (cnt_state)
          7'd0:  begin max_pool[0][0] <= add_2;                             end
          7'd1:  begin max_pool[0][1] <= add_2; max_pool[0][0] <= mult_out1;end
          7'd2:  begin max_pool[0][2] <= add_2; max_pool[0][1] <= mult_out1;end
          7'd3:  begin max_pool[0][3] <= add_2; max_pool[0][2] <= mult_out1;end
          7'd4:  begin max_pool[1][0] <= add_2; max_pool[0][3] <= mult_out1;end
          7'd5:  begin max_pool[1][1] <= add_2; max_pool[1][0] <= mult_out1;end
          7'd6:  begin max_pool[1][2] <= add_2; max_pool[1][1] <= mult_out1;end
          7'd7:  begin max_pool[1][3] <= add_2; max_pool[1][2] <= mult_out1;end
          7'd8:  begin                          max_pool[1][3] <= mult_out1;end
          7'd9:  begin max_pool[0][0] <= mult_out1;                         end
          7'd10: begin max_pool[0][1] <= mult_out1;                         end
          7'd11: begin max_pool[0][2] <= mult_out1;                         end
          7'd12: begin max_pool[0][3] <= mult_out1;                         end
          7'd13: begin max_pool[1][0] <= mult_out1;                         end
          7'd14: begin max_pool[1][1] <= mult_out1;                         end
          7'd15: begin max_pool[1][2] <= mult_out1;                         end
          7'd16: begin max_pool[1][3] <= mult_out1;                         end
          default: max_pool <= max_pool;
        endcase
      end
      default: max_pool <= max_pool;
    endcase
  end
end

always @(posedge clk or negedge rst_n) begin //upside
  if (!rst_n) begin
      for (i = 0; i<10 ; i = i+1 ) begin
        upside[i] <= 32'b0;
      end
    end
  else begin
    case (c_state)
      NORMAL_ACTI:begin
        case (cnt_state)
          7'd0: begin upside[0] <= recip_out; end
          7'd1: begin upside[1] <= recip_out; end
          7'd4: begin upside[2] <= recip_out; end
          7'd5: begin upside[3] <= recip_out; end
          7'd6: begin upside[4] <= recip_out; end
          7'd7: begin upside[5] <= recip_out; end
          7'd8: begin upside[6] <= recip_out; end
          7'd9: begin upside[7] <= recip_out; end
          7'd10: begin upside[8] <= recip_out; end
          7'd11: begin upside[9] <= recip_out; end
          default: upside <= upside;
        endcase
      end
      default: upside <= upside;
    endcase
  end
end

always @(posedge clk or negedge rst_n) begin //exp_up
  if (!rst_n) begin
      for (i = 0; i<8 ; i = i+1 ) begin
        exp_up[i] <= 32'b0;
      end
    end
  else begin
    case (c_state)
      NORMAL_ACTI:begin
        case (cnt_state)
          7'd3: begin exp_up[0] <= add_1; end
          7'd4: begin exp_up[1] <= add_1; end
          7'd5: begin exp_up[2] <= add_1; end
          7'd6: begin exp_up[3] <= add_1; end
          7'd7: begin exp_up[4] <= add_1; end
          7'd8: begin exp_up[5] <= add_1; end
          7'd9: begin exp_up[6] <= add_1; end
          7'd10: begin exp_up[7] <= add_1; end
          default: exp_up <= exp_up;
        endcase
      end
      default: exp_up <= exp_up;
    endcase
  end
end

always @(posedge clk or negedge rst_n) begin //exp_tmp2
  if (!rst_n) begin
      for (i = 0; i<8 ; i = i+1 ) begin
        exp_tmp2[0][i] <= 32'b0;
        exp_tmp2[1][i] <= 32'b0;
      end
    end
  else begin
    case (c_state)
      NORMAL_ACTI:begin
        case (cnt_state)
          7'd2: begin exp_tmp2[0][0] <= exp_out1; exp_tmp2[1][0] <= exp_out2;end
          7'd3: begin exp_tmp2[0][1] <= exp_out1; exp_tmp2[1][1] <= exp_out2;end
          7'd4: begin exp_tmp2[0][2] <= exp_out1; exp_tmp2[1][2] <= exp_out2;end
          7'd5: begin exp_tmp2[0][3] <= exp_out1; exp_tmp2[1][3] <= exp_out2;end
          7'd6: begin exp_tmp2[0][4] <= exp_out1; exp_tmp2[1][4] <= exp_out2;end
          7'd7: begin exp_tmp2[0][5] <= exp_out1; exp_tmp2[1][5] <= exp_out2;end
          7'd8: begin exp_tmp2[0][6] <= exp_out1; exp_tmp2[1][6] <= exp_out2;end
          7'd9: begin exp_tmp2[0][7] <= exp_out1; exp_tmp2[1][7] <= exp_out2;end
          default: begin exp_tmp2 <= exp_tmp2; end
        endcase
      end
      default: begin exp_tmp2 <= exp_tmp2;end
    endcase
  end
end

always @(posedge clk or negedge rst_n) begin //add_tmp
  if (!rst_n) begin
      for (i = 0; i<8 ; i = i+1 ) begin
        add_tmp[0][i] <= 32'b0;
      end
    end
  else begin
    case (c_state)
      NORMAL_ACTI:begin
        case (cnt_state)
          7'd3: begin add_tmp[0] <= add_3;end
          7'd4: begin add_tmp[1] <= add_3;end
          7'd5: begin add_tmp[2] <= add_3;end
          7'd6: begin add_tmp[3] <= add_3;end
          7'd7: begin add_tmp[4] <= add_3;end
          7'd8: begin add_tmp[5] <= add_3;end
          7'd9: begin add_tmp[6] <= add_3;end
          7'd10: begin add_tmp[7] <= add_3;end
          default: begin add_tmp <= add_tmp; end
        endcase
      end
      default: begin add_tmp <= add_tmp;end
    endcase
  end
end
//---------------------------------------------------------------------
//   Output
//---------------------------------------------------------------------
always @(*) // out_valid
  begin
    out_valid = 1'b0;
    // if (c_state == NORMAL_ACTI && cnt_state == 7'd17) begin
    if (c_state == OUT) begin  
        out_valid = 1'b1;
    end        
  end

always @(*) // out
  begin
    out = 32'b0;
    //if (c_state == NORMAL_ACTI && cnt_state == 7'd17) begin
    if (c_state == OUT) begin  
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
    if (c_state == IDLE && in_valid)begin
      cnt_16 <= cnt_16 + 1'b1;
    end  
    else if (c_state == CONVOLUTION) begin
      cnt_16 <= cnt_16 + 1'b1;
    end 
    else begin
      cnt_16 <= 7'b0;
    end
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
  // if (!rst_n) begin
  //   x_y_map = 6'b0;
  // end 
  // else begin
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
    //end 
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
  // if (!rst_n) begin
  //   cmp_in1 = 32'b0;
  //   cmp_in2 = 32'b0;
  //   cmp_in3 = 32'b0;
  //   cmp_in4 = 32'b0;
  // end 
  // else begin
    case (c_state)
      IDLE,CONVOLUTION: begin
        case (cnt_input)
          7'd48: begin
            cmp_in1 = map[0][0][0];
            cmp_in2 = map[0][0][1];
            cmp_in3 = map[0][1][0];
            cmp_in4 = map[0][1][1];
          end
          7'd50: begin
            cmp_in1 = map[0][0][2];
            cmp_in2 = map[0][0][3];
            cmp_in3 = map[0][1][2];
            cmp_in4 = map[0][1][3];
          end
          7'd56: begin
            cmp_in1 = map[0][2][0];
            cmp_in2 = map[0][2][1];
            cmp_in3 = map[0][3][0];
            cmp_in4 = map[0][3][1];
          end 
          7'd58: begin
            cmp_in1 = map[0][2][2];
            cmp_in2 = map[0][2][3];
            cmp_in3 = map[0][3][2];
            cmp_in4 = map[0][3][3];
          end 
          7'd96: begin
            cmp_in1 = map[1][0][0];
            cmp_in2 = map[1][0][1];
            cmp_in3 = map[1][1][0];
            cmp_in4 = map[1][1][1];
          end
          7'd98: begin
            cmp_in1 = map[1][0][2];
            cmp_in2 = map[1][0][3];
            cmp_in3 = map[1][1][2];
            cmp_in4 = map[1][1][3];
          end
          7'd104: begin
            cmp_in1 = map[1][2][0];
            cmp_in2 = map[1][2][1];
            cmp_in3 = map[1][3][0];
            cmp_in4 = map[1][3][1];
          end
          7'd49,7'd51,7'd57,7'd59,7'd97,7'd99,7'd105: begin
            cmp_in1 = max[0];
            cmp_in2 = max[2];
            cmp_in3 = max[1];
            cmp_in4 = max[3];
          end
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
            cmp_in1 = map[1][2][2];
            cmp_in2 = map[1][2][3];
            cmp_in3 = map[1][3][2];
            cmp_in4 = map[1][3][3];
           end 
          //'d1: begin 
          // cmp_in1 = max[0];
          // cmp_in2 = max[2];
          // cmp_in3 = max[1];
          // cmp_in4 = max[3]; 
          //nd 
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
  // if (!rst_n) begin
  //   dot_a_in1 = 32'b0; dot_b_in1 = 32'b0; dot_c_in1 = 32'b0; dot_d_in1 = 32'b0; dot_e_in1 = 32'b0; dot_f_in1= 32'b0;
  //   dot_a_in2 = 32'b0; dot_b_in2 = 32'b0; dot_c_in2 = 32'b0; dot_d_in2 = 32'b0; dot_e_in2 = 32'b0; dot_f_in2= 32'b0;
  //   dot_a_in3 = 32'b0; dot_b_in3 = 32'b0; dot_c_in3 = 32'b0; dot_d_in3 = 32'b0; dot_e_in3 = 32'b0; dot_f_in3= 32'b0;
  // end 
  // else begin
    case (c_state)
      IDLE,CONVOLUTION: begin
        dot_a_in1 = img[x_y[5:3]-1][x_y[2:0]-1]; dot_b_in1 = kernel[ker_channel][0][0]; dot_c_in1 = img[x_y[5:3]-1][x_y[2:0]]; 
        dot_d_in1 = kernel[ker_channel][0][1]; dot_e_in1 = img[x_y[5:3]-1][x_y[2:0]+1]; dot_f_in1 = kernel[ker_channel][0][2];
        dot_a_in2 = img[x_y[5:3]][x_y[2:0]-1]; dot_b_in2 = kernel[ker_channel][1][0]; dot_c_in2 = img[x_y[5:3]][x_y[2:0]]; 
        dot_d_in2 = kernel[ker_channel][1][1]; dot_e_in2 = img[x_y[5:3]][x_y[2:0]+1]; dot_f_in2 = kernel[ker_channel][1][2];
        dot_a_in3 = img[x_y[5:3]+1][x_y[2:0]-1]; dot_b_in3 = kernel[ker_channel][2][0]; dot_c_in3 = img[x_y[5:3]+1][x_y[2:0]]; 
        dot_d_in3 = kernel[ker_channel][2][1]; dot_e_in3 = img[x_y[5:3]+1][x_y[2:0]+1]; dot_f_in3 = kernel[ker_channel][2][2];
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
  //end
end

always @(*) begin //add_in1~6
  // if (!rst_n) begin
  //   add_in1 = 32'b0; add_in2 = 32'b0; add_in3 = 32'b0; add_in4 = 32'b0; add_in5 = 32'b0; add_in6 = 32'b0;
  // end 
  // else begin
    case (c_state)
      IDLE,CONVOLUTION: begin
        add_in1 = dot_3_1_tmp; 
        add_in2 = dot_3_2_tmp; 
        add_in3 = dot_3_3_tmp; 
        add_in4 = map[map_channel][x_y_map[3:2]][x_y_map[1:0]]; 
        add_in5 = add_1; 
        add_in6 = add_2;
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
  //end
end

always @(*) begin //mult_in1~2
  // if (!rst_n) begin
  //   mult_in1 = 32'b0; mult_in2 = 32'b0;
  // end 
  // else begin
    case (c_state)
      NORMAL_ACTI:begin
        case (cnt_state)
          7'd1: begin 
            mult_in1 = max_pool[0][0]; mult_in2 = upside[0];
          end
          7'd2: begin 
            mult_in1 = max_pool[0][1]; mult_in2 = upside[0];
          end
          7'd3: begin 
            mult_in1 = max_pool[0][2]; mult_in2 = upside[0];
          end
          7'd4: begin 
            mult_in1 = max_pool[0][3]; mult_in2 = upside[0];
          end
          7'd5: begin 
            mult_in1 = max_pool[1][0]; mult_in2 = upside[1];
          end
          7'd6: begin 
            mult_in1 = max_pool[1][1]; mult_in2 = upside[1];
          end
          7'd7: begin 
            mult_in1 = max_pool[1][2]; mult_in2 = upside[1];
          end
          7'd8: begin 
            mult_in1 = max_pool[1][3]; mult_in2 = upside[1];
          end
          7'd9: begin 
            mult_in1 = exp_up[0]; mult_in2 = upside[2];
          end
          7'd10: begin 
            mult_in1 = exp_up[1]; mult_in2 = upside[3];
          end
          7'd11: begin 
            mult_in1 = exp_up[2]; mult_in2 = upside[4];
          end
          7'd12: begin 
            mult_in1 = exp_up[3]; mult_in2 = upside[5];
          end
          7'd13: begin 
            mult_in1 = exp_up[4]; mult_in2 = upside[6];
          end
          7'd14: begin 
            mult_in1 = exp_up[5]; mult_in2 = upside[7];
          end
          7'd15: begin 
            mult_in1 = exp_up[6]; mult_in2 = upside[8];
          end
          7'd16: begin 
            mult_in1 = exp_up[7]; mult_in2 = upside[9];
          end
          default: begin
            mult_in1 = 32'b0; mult_in2 = 32'b0;
          end
        endcase
      end
      default: begin
        mult_in1 = 32'b0; mult_in2 = 32'b0;
      end
    endcase
  //end
end

always @(*) begin // recip_in
  // if (!rst_n) begin
  //   recip_in = 32'b0;
  // end else begin
    case (c_state)
      NORMAL_ACTI:begin
        case (cnt_state)
          7'd0: begin recip_in = add_1;end
          7'd1: begin recip_in = add_1;end
          7'd4: begin recip_in = add_tmp[0]; end
          7'd5: begin recip_in = add_tmp[1]; end
          7'd6: begin recip_in = add_tmp[2]; end
          7'd7: begin recip_in = add_tmp[3]; end
          7'd8: begin recip_in = add_tmp[4]; end
          7'd9: begin recip_in = add_tmp[5]; end
          7'd10:begin recip_in = add_tmp[6]; end
          7'd11:begin recip_in = add_tmp[7]; end
          default:begin recip_in = 32'b0;end
        endcase
      end
      default: begin recip_in = 32'b0;end
    endcase
  //end
end

always @(*) begin // exp_in1~2
  // if (!rst_n) begin
  //   exp_in1 = 32'b0;
  //   exp_in2 = 32'b0;
  // end else begin
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
  //end
end
//---------------------------------------------------------------------
//   Registers
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    dot_3_1_tmp <= 32'b0;
    dot_3_2_tmp <= 32'b0;
    dot_3_3_tmp <= 32'b0;
  end else begin
    case (c_state)
      IDLE,CONVOLUTION:begin
        if (cnt_input > 7'd8) begin
          dot_3_1_tmp <= dot_3_1_out;
          dot_3_2_tmp <= dot_3_2_out;
          dot_3_3_tmp <= dot_3_3_out;
        end
        else  begin
          dot_3_1_tmp <= dot_3_1_tmp;
          dot_3_2_tmp <= dot_3_2_tmp;
          dot_3_3_tmp <= dot_3_3_tmp;
        end 
      end
      default:begin
        dot_3_1_tmp <= dot_3_1_tmp;
        dot_3_2_tmp <= dot_3_2_tmp;
        dot_3_3_tmp <= dot_3_3_tmp;
      end
    endcase
  end
end

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    add_1_tmp <= 32'b0;
  end else begin
    case (c_state)
      IDLE,CONVOLUTION:begin
        if (cnt_input > 7'd8) begin
          add_1_tmp <= add_3;
        end
        else  begin
          add_1_tmp <= add_1_tmp;
        end 
      end
      default:begin
          add_1_tmp <= add_1_tmp;
      end
    endcase
  end
end




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
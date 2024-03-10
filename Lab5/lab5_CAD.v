module CAD(
         //Input Port
         clk,
         rst_n,
         in_valid,
         in_valid2,
         matrix_size,
         matrix,
         matrix_idx,
         mode,

         //Output Port
         out_valid,
         out_value
       );

//---------------------------------------------------------------------
//   input / output
//---------------------------------------------------------------------

input rst_n, clk, in_valid, in_valid2;
input [1:0] matrix_size;
input [7:0] matrix;
input [3:0] matrix_idx;
input mode;

output reg	out_valid;
output reg  out_value;

//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------
parameter STATE_BIT = 3'd4;
parameter IDLE = 4'd0;
parameter INPUT_IMG = 4'd1;
parameter INPUT_KERNEL = 4'd2;
parameter WAIT_MATRIX = 4'd3;
parameter CHOOSE_MATRIX = 4'd4;
parameter CONVOLUTION = 4'd5;
parameter OUT_CONVOLUTION = 4'd6;
parameter TRANSPOSED_CONV = 4'd7;
parameter OUT_TRANSPOSED_CONV = 4'd8;

integer i,j;

//---------------------------------------------------------------------
//   reg or wire declaration
//---------------------------------------------------------------------
// FSM
reg [STATE_BIT-1:0] c_state,n_state; 

//SRAM input(IMG)
reg [10:0] addr_i;
reg signed [63:0] d_in;
wire signed [63:0] d_out;
reg r_or_w;
//SRAM input(kernel)
reg [6:0] addr_k;
reg signed [39:0] k_in,k_out;
reg r_or_w_k; 
//register
reg signed [63:0] img_temp;
reg signed [39:0] ker_temp;
reg [10:0] img_start_addr_cs;
reg [1:0] Msize_ns,Msize_cs;
reg [3:0] M_num_ns,M_num_cs,K_num_ns,K_num_cs;
reg Mode_ns,Mode_cs;
reg signed [7:0] pixel      [0:5][0:7];
reg signed [7:0] pixel_next [0:5][0:7];
reg signed [7:0] kernel     [0:4][0:4];
reg signed [19:0] map_tmp   [0:1][0:1];
reg signed [19:0] out_tmp;
reg signed [19:0] add_tmp;


//count
reg [13:0] cnt_16384;
reg [2:0]  cnt_8;
reg [2:0]  cnt_5;
reg [8:0]  cnt_400;
reg [4:0]  cnt_20;
reg [3:0]  cnt_data_runout;
reg [1:0]  cnt_change_next;
reg [4:0]  cnt_mode;
reg [5:0]  cnt_column;


//control
reg [13:0] input_img_time; 
reg [10:0] img_start_addr;
reg [6:0]  kernel_start_addr;
reg [2:0]  next_row_offset;
reg [4:0]  next_8_pixel_offset;
reg [10:0] output_stop_cycle;
reg [5:0]  row_end;
reg [5:0] shift_num;
reg [4:0] next_pool_row_offset;
reg [1:0] shift_next_limit;
reg row_zero_select;
reg [7:0] img_5_tmp [0:4][0:39];
reg [5:0] take_next_bit;
reg [19:0] add_out_tmp;


// mult add input select
reg signed [7:0] mult_in1_1,mult_in2_1,mult_in1_2,mult_in2_2,mult_in1_3,mult_in2_3,mult_in1_4,mult_in2_4,mult_in1_5,mult_in2_5;
reg signed [19:0] add_in1_1,add_in2_1,add_in1_2,add_in2_2,add_in1_3,add_in2_3,add_in1_4,add_in2_4,add_in1_5,add_in2_5;

// mult add output
wire signed [15:0] mult_out1,mult_out2,mult_out3,mult_out4,mult_out5;
assign mult_out1 = mult_in1_1 * mult_in2_1;
assign mult_out2 = mult_in1_2 * mult_in2_2;
assign mult_out3 = mult_in1_3 * mult_in2_3;
assign mult_out4 = mult_in1_4 * mult_in2_4;
assign mult_out5 = mult_in1_5 * mult_in2_5;

wire signed [19:0] add_out1,add_out2,add_out3,add_out4,add_out5;
assign add_out1 = add_in1_1 + add_in2_1;
assign add_out2 = add_in1_2 + add_in2_2;
assign add_out3 = add_in1_3 + add_in2_3;
assign add_out4 = add_in1_4 + add_in2_4;
assign add_out5 = add_in1_5 + add_in2_5;

// mult add register
reg signed [15:0] mult_tmp1,mult_tmp2,mult_tmp3,mult_tmp4,mult_tmp5;

// compare 
wire signed [19:0] cmp1,cmp2,cmp3;
assign cmp1 = (map_tmp[0][0] > map_tmp[0][1]) ? map_tmp[0][0] : map_tmp[0][1];
assign cmp2 = (map_tmp[1][0] > add_out5) ? map_tmp[1][0] : add_out5;
assign cmp3 = (cmp1 > cmp2) ? cmp1 : cmp2;

//---------------------------------------------------------------------
//   SRAM
//---------------------------------------------------------------------
IMAGE_ALL img_all(.A0  (addr_i[0]),.A1  (addr_i[1]),.A2  (addr_i[2]),.A3  (addr_i[3]),.A4  (addr_i[4]),
                  .A5  (addr_i[5]),.A6  (addr_i[6]),.A7  (addr_i[7]),.A8  (addr_i[8]),.A9  (addr_i[9]),.A10(addr_i[10]),
                  .DO0 (d_out[0]),.DO1 (d_out[1]),.DO2 (d_out[2]),.DO3 (d_out[3]),.DO4 (d_out[4]),.DO5 (d_out[5]),.DO6 (d_out[6]),.DO7 (d_out[7]),.DO8 (d_out[8]),.DO9 (d_out[9]),
                  .DO10(d_out[10]),.DO11(d_out[11]),.DO12(d_out[12]),.DO13(d_out[13]),.DO14(d_out[14]),.DO15(d_out[15]),.DO16(d_out[16]),.DO17(d_out[17]),.DO18(d_out[18]),.DO19(d_out[19]),
                  .DO20(d_out[20]),.DO21(d_out[21]),.DO22(d_out[22]),.DO23(d_out[23]),.DO24(d_out[24]),.DO25(d_out[25]),.DO26(d_out[26]),.DO27(d_out[27]),.DO28(d_out[28]),.DO29(d_out[29]),
                  .DO30(d_out[30]),.DO31(d_out[31]),.DO32(d_out[32]),.DO33(d_out[33]),.DO34(d_out[34]),.DO35(d_out[35]),.DO36(d_out[36]),.DO37(d_out[37]),.DO38(d_out[38]),.DO39(d_out[39]),
                  .DO40(d_out[40]),.DO41(d_out[41]),.DO42(d_out[42]),.DO43(d_out[43]),.DO44(d_out[44]),.DO45(d_out[45]),.DO46(d_out[46]),.DO47(d_out[47]),.DO48(d_out[48]),.DO49(d_out[49]),
                  .DO50(d_out[50]),.DO51(d_out[51]),.DO52(d_out[52]),.DO53(d_out[53]),.DO54(d_out[54]),.DO55(d_out[55]),.DO56(d_out[56]),.DO57(d_out[57]),.DO58(d_out[58]),.DO59(d_out[59]),
                  .DO60(d_out[60]),.DO61(d_out[61]),.DO62(d_out[62]),.DO63(d_out[63]),
                  .DI0 (d_in[0]),.DI1 (d_in[1]),.DI2 (d_in[2]),.DI3 (d_in[3]),.DI4 (d_in[4]),.DI5 (d_in[5]),.DI6 (d_in[6]),.DI7 (d_in[7]),.DI8 (d_in[8]),.DI9 (d_in[9]),
                  .DI10(d_in[10]),.DI11(d_in[11]),.DI12(d_in[12]),.DI13(d_in[13]),.DI14(d_in[14]),.DI15(d_in[15]),.DI16(d_in[16]),.DI17(d_in[17]),.DI18(d_in[18]),.DI19(d_in[19]),
                  .DI20(d_in[20]),.DI21(d_in[21]),.DI22(d_in[22]),.DI23(d_in[23]),.DI24(d_in[24]),.DI25(d_in[25]),.DI26(d_in[26]),.DI27(d_in[27]),.DI28(d_in[28]),.DI29(d_in[29]),
                  .DI30(d_in[30]),.DI31(d_in[31]),.DI32(d_in[32]),.DI33(d_in[33]),.DI34(d_in[34]),.DI35(d_in[35]),.DI36(d_in[36]),.DI37(d_in[37]),.DI38(d_in[38]),.DI39(d_in[39]),
                  .DI40(d_in[40]),.DI41(d_in[41]),.DI42(d_in[42]),.DI43(d_in[43]),.DI44(d_in[44]),.DI45(d_in[45]),.DI46(d_in[46]),.DI47(d_in[47]),.DI48(d_in[48]),.DI49(d_in[49]),
                  .DI50(d_in[50]),.DI51(d_in[51]),.DI52(d_in[52]),.DI53(d_in[53]),.DI54(d_in[54]),.DI55(d_in[55]),.DI56(d_in[56]),.DI57(d_in[57]),.DI58(d_in[58]),.DI59(d_in[59]),
                  .DI60(d_in[60]),.DI61(d_in[61]),.DI62(d_in[62]),.DI63(d_in[63]),
                  .CK  (clk),.WEB (r_or_w),.OE  (1'b1),.CS(1'b1));

KER_ALL kernel_all(.A0  (addr_k[0]),.A1  (addr_k[1]),.A2  (addr_k[2]),.A3  (addr_k[3]),.A4  (addr_k[4]),.A5  (addr_k[5]),.A6  (addr_k[6]),
                   .DO0 (k_out[0]),.DO1 (k_out[1]),.DO2 (k_out[2]),.DO3 (k_out[3]),.DO4 (k_out[4]),.DO5 (k_out[5]),.DO6 (k_out[6]),.DO7 (k_out[7]),.DO8 (k_out[8]),.DO9 (k_out[9]),
                   .DO10(k_out[10]),.DO11(k_out[11]),.DO12(k_out[12]),.DO13(k_out[13]),.DO14(k_out[14]),.DO15(k_out[15]),.DO16(k_out[16]),.DO17(k_out[17]),.DO18(k_out[18]),.DO19(k_out[19]),
                   .DO20(k_out[20]),.DO21(k_out[21]),.DO22(k_out[22]),.DO23(k_out[23]),.DO24(k_out[24]),.DO25(k_out[25]),.DO26(k_out[26]),.DO27(k_out[27]),.DO28(k_out[28]),.DO29(k_out[29]),
                   .DO30(k_out[30]),.DO31(k_out[31]),.DO32(k_out[32]),.DO33(k_out[33]),.DO34(k_out[34]),.DO35(k_out[35]),.DO36(k_out[36]),.DO37(k_out[37]),.DO38(k_out[38]),.DO39(k_out[39]),
                   .DI0 (k_in[0]),.DI1 (k_in[1]),.DI2 (k_in[2]),.DI3 (k_in[3]),.DI4 (k_in[4]),.DI5 (k_in[5]),.DI6 (k_in[6]),.DI7 (k_in[7]),.DI8 (k_in[8]),.DI9 (k_in[9]),
                   .DI10(k_in[10]),.DI11(k_in[11]),.DI12(k_in[12]),.DI13(k_in[13]),.DI14(k_in[14]),.DI15(k_in[15]),.DI16(k_in[16]),.DI17(k_in[17]),.DI18(k_in[18]),.DI19(k_in[19]),
                   .DI20(k_in[20]),.DI21(k_in[21]),.DI22(k_in[22]),.DI23(k_in[23]),.DI24(k_in[24]),.DI25(k_in[25]),.DI26(k_in[26]),.DI27(k_in[27]),.DI28(k_in[28]),.DI29(k_in[29]),
                   .DI30(k_in[30]),.DI31(k_in[31]),.DI32(k_in[32]),.DI33(k_in[33]),.DI34(k_in[34]),.DI35(k_in[35]),.DI36(k_in[36]),.DI37(k_in[37]),.DI38(k_in[38]),.DI39(k_in[39]),
                   .CK  (clk),.WEB (r_or_w_k),.OE  (1'b1),.CS(1'b1));

//---------------------------------------------------------------------
//   FSM
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin // current state
    if (!rst_n) begin
        c_state <= IDLE;
    end
    else begin
        c_state <= n_state;
    end
end

always @(*) begin // next state
    case (c_state)
        IDLE: begin
            if (in_valid)
                n_state = INPUT_IMG;   
            else 
                n_state = c_state;    
        end
        INPUT_IMG:begin
            if (cnt_16384 == input_img_time)
                n_state = INPUT_KERNEL;
            else 
                n_state = c_state;  
        end
        INPUT_KERNEL:begin
            if (cnt_400 == 9'd399) // 5*5*16 = 400
                n_state = WAIT_MATRIX;
            else 
                n_state = c_state;
        end
        WAIT_MATRIX: begin
            if (in_valid2)
                n_state = CHOOSE_MATRIX;
            else 
                n_state = c_state;    
        end
        CHOOSE_MATRIX: begin
            if (cnt_400 == 9'd1)
               n_state = (!Mode_cs) ? CONVOLUTION : TRANSPOSED_CONV; 
            else 
               n_state = c_state;     
        end
        CONVOLUTION:begin
            if (cnt_400 == 9'd23)
               n_state = OUT_CONVOLUTION; 
            else 
               n_state = c_state; 
        end
        OUT_CONVOLUTION: begin
            if (cnt_16384 == output_stop_cycle && cnt_20 == 19)
                if (cnt_mode == 1'b0) begin
                    n_state = IDLE;
                end else begin
                    n_state = WAIT_MATRIX;
                end
            else
              n_state = c_state;  
        end
        TRANSPOSED_CONV:begin
            if (cnt_400 == 9'd6)
               n_state = OUT_TRANSPOSED_CONV; 
            else 
               n_state = c_state; 
        end
        OUT_TRANSPOSED_CONV:begin
            if (cnt_16384 == output_stop_cycle && cnt_20 == 19)
                if (cnt_mode == 1'b0) begin
                    n_state = IDLE;
                end else begin
                    n_state = WAIT_MATRIX;
                end
            else
              n_state = c_state;
        end
        default: n_state = c_state;
    endcase
end

//---------------------------------------------------------------------
//   SRAM control
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin // addr_i
    if (!rst_n) begin
        addr_i <= 11'd0;
    end else begin
        case (c_state)
            INPUT_IMG: begin 
                case (cnt_8)
                    3'd0: addr_i <= addr_i + 1'b1; 
                    default: addr_i <= addr_i;
                endcase
            end 
            CONVOLUTION: begin
                case (cnt_400)
                    9'd0: addr_i <= img_start_addr_cs;
                    9'd1,9'd2,9'd3,9'd4,9'd5: addr_i <= addr_i + next_row_offset;
                    9'd6: addr_i <= (Msize_cs == 0) ? addr_i + next_row_offset :addr_i - next_8_pixel_offset;
                    9'd7,9'd8,9'd9,9'd10,9'd11: addr_i <= addr_i + next_row_offset;
                    default: addr_i <= addr_i;
                endcase
            end
            OUT_CONVOLUTION:begin
                if (shift_num == row_end - 1'b1) begin 
                    case (cnt_20)
                        7: addr_i <= addr_i - next_pool_row_offset;
                        default: addr_i <= addr_i; 
                    endcase
                end    
                else if (shift_num == row_end) begin
                    case (cnt_20)
                        13,14,15,16,17: addr_i <= addr_i + next_row_offset;
                        18: addr_i <= addr_i - next_8_pixel_offset;
                        19: addr_i <= addr_i + next_row_offset;
                        default: addr_i <= addr_i; 
                    endcase
                end  
                else if (shift_num == 6'd0) begin
                    case (cnt_20)
                        0,1,2,3: addr_i <= addr_i + next_row_offset;
                        default: addr_i <= addr_i; 
                    endcase
                end
                else if (cnt_data_runout == 3'd7 && shift_next_limit != cnt_change_next) begin
                    case (cnt_20)
                        10: addr_i <= addr_i - next_8_pixel_offset;
                        13,14,15,16,17: addr_i <= addr_i + next_row_offset;
                        default: addr_i <= addr_i; 
                    endcase
                end
                else    
                    addr_i <= addr_i;    
            end
            TRANSPOSED_CONV: begin
                case (cnt_400)
                    9'd0: addr_i <= img_start_addr_cs;
                    9'd1: addr_i <= (Msize_cs == 2'd0) ? addr_i : addr_i + 1'b1;
                    9'd2: addr_i <= (Msize_cs == 2'd2) ? addr_i + 1'b1 : addr_i;
                    9'd3: addr_i <= (Msize_cs == 2'd2) ? addr_i + 1'b1 : addr_i;
                    default: addr_i <= addr_i;
                endcase
            end
            OUT_TRANSPOSED_CONV:begin
                if (shift_num == row_end) begin
                    case (cnt_20)
                        9'd1: addr_i <= addr_i + 1'b1;
                        9'd2: addr_i <= (Msize_cs == 2'd0) ? addr_i : addr_i + 1'b1;
                        9'd3: addr_i <= (Msize_cs == 2'd2) ? addr_i + 1'b1 : addr_i;
                        9'd4: addr_i <= (Msize_cs == 2'd2) ? addr_i + 1'b1 : addr_i;
                        default: addr_i <= addr_i; 
                    endcase
                end else begin
                    addr_i <= addr_i;
                end
            end
            default: begin addr_i <= 11'd0; end 
        endcase
    end   
end

always @(*) begin // r_or_w
    case (c_state)
        INPUT_IMG: begin 
            if (cnt_8 == 3'd0)
                r_or_w = 1'b0;
            else 
                r_or_w = 1'b1;     
        end
        INPUT_KERNEL: begin 
            if (addr_i > 11'd0)
                r_or_w = 1'b0;
            else 
                r_or_w = 1'b1;     
        end
        default: begin r_or_w = 1'b1; end
    endcase
end

always @(*) begin // d_in
    case (c_state)
        INPUT_IMG: begin 
            if (cnt_8 == 3'd0)
                d_in = img_temp; 
            else    
                d_in = 7'b0;    
        end 
        INPUT_KERNEL: begin 
                d_in = img_temp; 
        end
        default: begin d_in = 7'b0; end
    endcase
end


always @(posedge clk or negedge rst_n) begin // addr_k
    if (!rst_n) begin
        addr_k <= 9'd0;
    end else begin
        case (c_state) 
            INPUT_KERNEL: begin 
                case (cnt_5)
                    3'd5: addr_k <= addr_k + 1'b1; 
                    default: addr_k <= addr_k;
                endcase 
            end 
            CONVOLUTION,TRANSPOSED_CONV: begin
                case (cnt_400)
                    9'd0: addr_k <= kernel_start_addr;
                    9'd1,9'd2,9'd3,9'd4: addr_k <= addr_k + 1'b1;
                    default: addr_k <= addr_k;
                endcase
            end
            default: begin addr_k <= 9'd0; end 
        endcase
    end
end

always @(*) begin // r_or_w_k
    case (c_state)
        //INPUT_IMG: begin r_or_w_k = (n_state != c_state) ? 1'b0 : 1'b1 ; end
        INPUT_KERNEL: begin 
            if (cnt_5 == 3'd5)
                r_or_w_k = 1'b0;
            else 
                r_or_w_k = 1'b1;
        end        
        WAIT_MATRIX: begin 
            if (cnt_5 > 3'd0)
                r_or_w_k = 1'b0;
            else 
                r_or_w_k = 1'b1;     
        end        
        default: begin r_or_w_k = 1'b1; end
    endcase
end

always @(*) begin // k_in
    case (c_state)
        INPUT_KERNEL: begin k_in = ker_temp; end 
        WAIT_MATRIX: begin k_in = ker_temp; end
        default: begin k_in = 7'b0; end
    endcase
end

always @(*) begin // row_zero_select
    case (c_state)
        OUT_TRANSPOSED_CONV: begin 
            case (cnt_column)
                7,8,9,10,11: row_zero_select = (Msize_cs == 2'd0) ? 1'b1 : 1'b0;
                15,16,17,18,19: row_zero_select = (Msize_cs == 2'd1) ? 1'b1 : 1'b0;
                31,32,33,34,35: row_zero_select = (Msize_cs == 2'd2) ? 1'b1 : 1'b0;
                default: row_zero_select = 1'b0;
            endcase 
        end
        default: begin row_zero_select = 1'b0; end
    endcase
end

//---------------------------------------------------------------------
//   Output
//---------------------------------------------------------------------
always@(*)begin // out_valid
    if (!rst_n)begin
        out_valid = 1'b0;
    end
    else begin
        case (c_state)
            OUT_CONVOLUTION,OUT_TRANSPOSED_CONV: out_valid = 1'b1;
            default: out_valid = 1'b0;
        endcase
    end
end

always@(*)begin // out_value
    if (!rst_n)begin
        out_value = 1'b0;
    end
    else begin
        case (c_state)
            OUT_CONVOLUTION,OUT_TRANSPOSED_CONV:begin
                case (cnt_20)
                    0:  out_value = out_tmp[0];
                    1:  out_value = out_tmp[1]; 
                    2:  out_value = out_tmp[2];
                    3:  out_value = out_tmp[3];
                    4:  out_value = out_tmp[4];
                    5:  out_value = out_tmp[5];
                    6:  out_value = out_tmp[6];
                    7:  out_value = out_tmp[7];
                    8:  out_value = out_tmp[8];
                    9:  out_value = out_tmp[9];
                    10: out_value = out_tmp[10];
                    11: out_value = out_tmp[11];
                    12: out_value = out_tmp[12];
                    13: out_value = out_tmp[13];
                    14: out_value = out_tmp[14];
                    15: out_value = out_tmp[15];
                    16: out_value = out_tmp[16];
                    17: out_value = out_tmp[17];
                    18: out_value = out_tmp[18];
                    19: out_value = out_tmp[19];
                    default: out_value = 1'b0;
                endcase
            end 
            default: out_value = 1'b0;
        endcase
    end
end
//---------------------------------------------------------------------
//   Count
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin // cnt_16384
    if (!rst_n) begin
        cnt_16384 <= 14'b0;
    end else begin
        case (c_state)
            IDLE: begin 
                if (c_state != n_state)
                    cnt_16384 <= cnt_16384 + 1'b1; 
                else
                    cnt_16384 <= 14'b0;     
            end 
            INPUT_IMG: begin cnt_16384 <= cnt_16384 + 1'b1; end
            OUT_CONVOLUTION,OUT_TRANSPOSED_CONV: begin
                if (cnt_20 == 19)
                   cnt_16384 <= cnt_16384 + 1'b1; 
             end
            default: begin cnt_16384 <= 14'b0; end
        endcase
    end  
end

always @(posedge clk or negedge rst_n) begin // cnt_8
    if (!rst_n) begin
        cnt_8 <= 3'b0;
    end else begin
        case (c_state)
            IDLE: begin 
                if (c_state != n_state)
                    cnt_8 <= cnt_8 + 1'b1; 
                else
                    cnt_8 <= 3'b0;     
            end 
            INPUT_IMG: begin 
                if (c_state != n_state)
                    cnt_8 <= 1'b1; 
                else
                    cnt_8 <= cnt_8 + 1'b1; 
            end
            default: begin cnt_8 <= 3'b0; end
        endcase
    end  
end

always @(posedge clk or negedge rst_n) begin // cnt_5
    if (!rst_n) begin
        cnt_5 <= 3'b0;
    end else begin
        case (c_state)
            INPUT_KERNEL: begin 
                    if (cnt_5 == 3'd5) begin
                        cnt_5 <= 1'b1;
                    end else begin
                        cnt_5 <= cnt_5 + 1'b1;
                    end
            end
            default: begin cnt_5 <= 3'b0; end
        endcase
    end  
end

always @(posedge clk or negedge rst_n) begin // cnt_20
    if (!rst_n) begin
        cnt_20 <= 5'b0;
    end else begin
        case (c_state)
            OUT_CONVOLUTION,OUT_TRANSPOSED_CONV: begin 
                if (cnt_20 == 5'd19) begin
                    cnt_20 <= 5'b0;
                end
                else
                    cnt_20 <= cnt_20 + 1'b1;
            end
            default: begin cnt_20 <= 5'b0; end
        endcase
    end  
end

always @(posedge clk or negedge rst_n) begin // cnt_400
    if (!rst_n) begin
        cnt_400 <= 9'b0;
    end else begin
        case (c_state)
            INPUT_KERNEL,CONVOLUTION,TRANSPOSED_CONV: begin cnt_400 <= cnt_400 + 1'b1; end
            CHOOSE_MATRIX: begin 
                if (c_state != n_state)
                    cnt_400 <= 9'b0;
                else
                    cnt_400 <= cnt_400 + 1'b1; 
            end
            default: begin cnt_400 <= 9'b0; end
        endcase
    end  
end


always @(posedge clk or negedge rst_n) begin // cnt_column
    if (!rst_n) begin
        cnt_column <= 6'b0;
    end else begin
        case (c_state)
            OUT_TRANSPOSED_CONV: begin 
                if (shift_num == row_end) begin
                    case (cnt_20)
                        19: cnt_column <= cnt_column + 1'b1;
                        default: cnt_column <= cnt_column;
                    endcase
                end else begin
                    cnt_column <= cnt_column;
                end  
            end
            default: begin cnt_column <= 6'b0; end
        endcase
    end  
end

always @(posedge clk or negedge rst_n) begin // cnt_data_runout
    if (!rst_n) begin
        cnt_data_runout <= 3'b0;

    end else begin
        case (c_state)
            CONVOLUTION:begin
                cnt_data_runout <= 3'd2;
            end
            OUT_CONVOLUTION: begin 
                case (cnt_20)
                  9,19: begin 
                    if (cnt_data_runout == 3'd7 || shift_num == row_end) begin
                        cnt_data_runout <= 3'b0;
                    end else begin
                        cnt_data_runout <= cnt_data_runout + 1'b1;
                    end
                  end
                  default: begin cnt_data_runout <= cnt_data_runout;end
                endcase   
            end
            TRANSPOSED_CONV:begin
                cnt_data_runout <= 3'd4;
            end
            OUT_TRANSPOSED_CONV: begin 
                case (cnt_20)
                  0: begin 
                    if (cnt_data_runout == 3'd7 || shift_num == row_end) begin
                        cnt_data_runout <= 3'd4;
                    end 
                    else begin
                        cnt_data_runout <= cnt_data_runout + 1'b1;
                    end
                  end
                  default: begin cnt_data_runout <= cnt_data_runout; end
                endcase   
            end
            default: begin cnt_data_runout <= 3'd0;end
        endcase
    end  
end

always @(posedge clk or negedge rst_n) begin // shift_num
    if (!rst_n) begin
        shift_num <= 6'd0;
    end else begin
        case (c_state)
            CONVOLUTION:begin
                shift_num <= 6'd2;
            end
            OUT_CONVOLUTION: begin 
                case (cnt_20)
                  9,19: begin 
                    if (shift_num == row_end) begin
                        shift_num <= 6'd0;
                    end else begin
                        shift_num <= shift_num + 1'b1;
                    end
                  end
                  default: begin shift_num <= shift_num; end
                endcase   
            end
            TRANSPOSED_CONV:begin
                shift_num <= 6'd0;
            end
            OUT_TRANSPOSED_CONV: begin 
                case (cnt_20)
                  0: begin 
                    if (shift_num == row_end) begin
                        shift_num <= 6'd0;
                    end else begin
                        shift_num <= shift_num + 1'b1;
                    end
                  end
                  default: begin shift_num <= shift_num; end
                endcase   
            end
            default: begin shift_num <= 6'd0; end
        endcase
    end  
end

always @(posedge clk or negedge rst_n) begin // cnt_change_next
    if (!rst_n) begin
        cnt_change_next <= 2'b0;
    end else begin
        case (c_state)
            CONVOLUTION:begin
                cnt_change_next <= 2'd1;
            end
            OUT_CONVOLUTION: begin 
                if (cnt_data_runout == 3'd7 && cnt_20 == 19) begin
                    if (cnt_change_next == shift_next_limit)
                        cnt_change_next <= 2'd1;
                    else
                        cnt_change_next <= cnt_change_next + 2'd1;    
                end
            end
            default: begin cnt_change_next <= 6'b0; end
        endcase
    end  
end

always @(posedge clk or negedge rst_n) begin // cnt_mode
    if (!rst_n) begin
        cnt_mode <= 4'b0;
    end else begin
        case (c_state)
            IDLE: cnt_mode <= 4'd0;
            CHOOSE_MATRIX: begin
                cnt_mode <= cnt_mode + 1'b1;
            end
            default: begin cnt_mode <= cnt_mode; end
        endcase
    end  
end

//---------------------------------------------------------------------
//   Mult Add input select
//---------------------------------------------------------------------
always @(*) begin // mult_in1_1~5 
        case (c_state)
            CONVOLUTION: begin
                case (cnt_400)
                    3,13,23: begin 
                        mult_in1_1 = pixel[0][0]; 
                        mult_in1_2 = pixel[0][1];  
                        mult_in1_3 = pixel[0][2];  
                        mult_in1_4 = pixel[0][3];  
                        mult_in1_5 = pixel[0][4];                          
                    end
                    4,8,14,18: begin 
                        mult_in1_1 = pixel[1][0]; 
                        mult_in1_2 = pixel[1][1];  
                        mult_in1_3 = pixel[1][2];  
                        mult_in1_4 = pixel[1][3];  
                        mult_in1_5 = pixel[1][4];                          
                    end
                    5,9,15,19: begin 
                        mult_in1_1 = pixel[2][0]; 
                        mult_in1_2 = pixel[2][1];  
                        mult_in1_3 = pixel[2][2];  
                        mult_in1_4 = pixel[2][3];  
                        mult_in1_5 = pixel[2][4];                          
                    end
                    6,10,16,20: begin 
                        mult_in1_1 = pixel[3][0]; 
                        mult_in1_2 = pixel[3][1];  
                        mult_in1_3 = pixel[3][2];  
                        mult_in1_4 = pixel[3][3];  
                        mult_in1_5 = pixel[3][4];                          
                    end
                    7,11,17,21: begin 
                        mult_in1_1 = pixel[4][0]; 
                        mult_in1_2 = pixel[4][1];  
                        mult_in1_3 = pixel[4][2];  
                        mult_in1_4 = pixel[4][3];  
                        mult_in1_5 = pixel[4][4];                          
                    end
                    12,22: begin 
                        mult_in1_1 = pixel[5][0]; 
                        mult_in1_2 = pixel[5][1];  
                        mult_in1_3 = pixel[5][2];  
                        mult_in1_4 = pixel[5][3];  
                        mult_in1_5 = pixel[5][4];                          
                    end
                    default: begin
                        mult_in1_1 = 8'b0; mult_in1_2 = 8'b0; mult_in1_3 = 8'b0; mult_in1_4 = 8'b0; mult_in1_5 = 8'b0;
                    end 
                endcase
            end
            OUT_CONVOLUTION: begin
                case (cnt_20)
                    9,19: begin 
                        mult_in1_1 = pixel[0][0]; 
                        mult_in1_2 = pixel[0][1];  
                        mult_in1_3 = pixel[0][2];  
                        mult_in1_4 = pixel[0][3];  
                        mult_in1_5 = pixel[0][4];                          
                    end
                    0,4,10,14: begin 
                        mult_in1_1 = pixel[1][0]; 
                        mult_in1_2 = pixel[1][1];  
                        mult_in1_3 = pixel[1][2];  
                        mult_in1_4 = pixel[1][3];  
                        mult_in1_5 = pixel[1][4];                          
                    end
                    1,5,11,15: begin 
                        mult_in1_1 = pixel[2][0]; 
                        mult_in1_2 = pixel[2][1];  
                        mult_in1_3 = pixel[2][2];  
                        mult_in1_4 = pixel[2][3];  
                        mult_in1_5 = pixel[2][4];                          
                    end
                    2,6,12,16: begin 
                        mult_in1_1 = pixel[3][0]; 
                        mult_in1_2 = pixel[3][1];  
                        mult_in1_3 = pixel[3][2];  
                        mult_in1_4 = pixel[3][3];  
                        mult_in1_5 = pixel[3][4];                          
                    end
                    3,7,13,17: begin 
                        mult_in1_1 = pixel[4][0]; 
                        mult_in1_2 = pixel[4][1];  
                        mult_in1_3 = pixel[4][2];  
                        mult_in1_4 = pixel[4][3];  
                        mult_in1_5 = pixel[4][4];                          
                    end
                    8,18: begin 
                        mult_in1_1 = pixel[5][0]; 
                        mult_in1_2 = pixel[5][1];  
                        mult_in1_3 = pixel[5][2];  
                        mult_in1_4 = pixel[5][3];  
                        mult_in1_5 = pixel[5][4];                          
                    end
                    default: begin
                        mult_in1_1 = 8'b0; mult_in1_2 = 8'b0; mult_in1_3 = 8'b0; mult_in1_4 = 8'b0; mult_in1_5 = 8'b0;
                    end 
                endcase
            end
            TRANSPOSED_CONV:begin
                case (cnt_400)
                    3: begin mult_in1_1 = pixel[4][4]; mult_in1_2 = 8'b0; mult_in1_3 = 8'b0; mult_in1_4 = 8'b0; mult_in1_5 = 8'b0; end
                    default: begin mult_in1_1 = 8'b0; mult_in1_2 = 8'b0; mult_in1_3 = 8'b0; mult_in1_4 = 8'b0; mult_in1_5 = 8'b0; end
                endcase
            end
            OUT_TRANSPOSED_CONV: begin
                case (cnt_20)
                    14: begin 
                        mult_in1_1 = pixel[0][0]; 
                        mult_in1_2 = pixel[0][1];  
                        mult_in1_3 = pixel[0][2];  
                        mult_in1_4 = pixel[0][3];  
                        mult_in1_5 = pixel[0][4];                          
                    end
                    15: begin 
                        mult_in1_1 = pixel[1][0]; 
                        mult_in1_2 = pixel[1][1];  
                        mult_in1_3 = pixel[1][2];  
                        mult_in1_4 = pixel[1][3];  
                        mult_in1_5 = pixel[1][4];                          
                    end
                    16: begin 
                        mult_in1_1 = pixel[2][0]; 
                        mult_in1_2 = pixel[2][1];  
                        mult_in1_3 = pixel[2][2];  
                        mult_in1_4 = pixel[2][3];  
                        mult_in1_5 = pixel[2][4];                          
                    end
                    17: begin 
                        mult_in1_1 = pixel[3][0]; 
                        mult_in1_2 = pixel[3][1];  
                        mult_in1_3 = pixel[3][2];  
                        mult_in1_4 = pixel[3][3];  
                        mult_in1_5 = pixel[3][4];                          
                    end
                    18: begin 
                        mult_in1_1 = pixel[4][0]; 
                        mult_in1_2 = pixel[4][1];  
                        mult_in1_3 = pixel[4][2];  
                        mult_in1_4 = pixel[4][3];  
                        mult_in1_5 = pixel[4][4];                          
                    end
                    default: begin
                        mult_in1_1 = 8'b0; mult_in1_2 = 8'b0; mult_in1_3 = 8'b0; mult_in1_4 = 8'b0; mult_in1_5 = 8'b0;
                    end 
                endcase
            end
            default: begin
                mult_in1_1 = 8'b0; mult_in1_2 = 8'b0; mult_in1_3 = 8'b0; mult_in1_4 = 8'b0; mult_in1_5 = 8'b0;
            end 
        endcase
end

always @(*) begin // mult_in2_1~5 
    case (c_state)
            CONVOLUTION: begin
                case (cnt_400)
                    3,8,13,18,23: begin 
                        mult_in2_1 = kernel[0][0]; 
                        mult_in2_2 = kernel[0][1];  
                        mult_in2_3 = kernel[0][2];  
                        mult_in2_4 = kernel[0][3];  
                        mult_in2_5 = kernel[0][4];                          
                    end
                    4,9,14,19: begin 
                        mult_in2_1 = kernel[1][0]; 
                        mult_in2_2 = kernel[1][1];  
                        mult_in2_3 = kernel[1][2];  
                        mult_in2_4 = kernel[1][3];  
                        mult_in2_5 = kernel[1][4];                          
                    end
                    5,10,15,20: begin 
                        mult_in2_1 = kernel[2][0]; 
                        mult_in2_2 = kernel[2][1];  
                        mult_in2_3 = kernel[2][2];  
                        mult_in2_4 = kernel[2][3];  
                        mult_in2_5 = kernel[2][4];                          
                    end
                    6,11,16,21: begin 
                        mult_in2_1 = kernel[3][0]; 
                        mult_in2_2 = kernel[3][1];  
                        mult_in2_3 = kernel[3][2];  
                        mult_in2_4 = kernel[3][3];  
                        mult_in2_5 = kernel[3][4];                          
                    end
                    7,12,17,22: begin 
                        mult_in2_1 = kernel[4][0]; 
                        mult_in2_2 = kernel[4][1];  
                        mult_in2_3 = kernel[4][2];  
                        mult_in2_4 = kernel[4][3];  
                        mult_in2_5 = kernel[4][4];                          
                    end
                    default: begin
                        mult_in2_1 = 8'b0; mult_in2_2 = 8'b0; mult_in2_3 = 8'b0; mult_in2_4 = 8'b0; mult_in2_5 = 8'b0;
                    end 
                endcase
            end
            OUT_CONVOLUTION: begin
                case (cnt_20)
                    4,9,14,19: begin 
                        mult_in2_1 = kernel[0][0]; 
                        mult_in2_2 = kernel[0][1];  
                        mult_in2_3 = kernel[0][2];  
                        mult_in2_4 = kernel[0][3];  
                        mult_in2_5 = kernel[0][4];                          
                    end
                    0,5,10,15: begin 
                        mult_in2_1 = kernel[1][0]; 
                        mult_in2_2 = kernel[1][1];  
                        mult_in2_3 = kernel[1][2];  
                        mult_in2_4 = kernel[1][3];  
                        mult_in2_5 = kernel[1][4];                          
                    end
                    1,6,11,16: begin 
                        mult_in2_1 = kernel[2][0]; 
                        mult_in2_2 = kernel[2][1];  
                        mult_in2_3 = kernel[2][2];  
                        mult_in2_4 = kernel[2][3];  
                        mult_in2_5 = kernel[2][4];                          
                    end
                    2,7,12,17: begin 
                        mult_in2_1 = kernel[3][0]; 
                        mult_in2_2 = kernel[3][1];  
                        mult_in2_3 = kernel[3][2];  
                        mult_in2_4 = kernel[3][3];  
                        mult_in2_5 = kernel[3][4];                          
                    end
                    3,8,13,18: begin 
                        mult_in2_1 = kernel[4][0]; 
                        mult_in2_2 = kernel[4][1];  
                        mult_in2_3 = kernel[4][2];  
                        mult_in2_4 = kernel[4][3];  
                        mult_in2_5 = kernel[4][4];                          
                    end
                    default: begin
                        mult_in2_1 = 8'b0; mult_in2_2 = 8'b0; mult_in2_3 = 8'b0; mult_in2_4 = 8'b0; mult_in2_5 = 8'b0;
                    end 
                endcase
            end
            TRANSPOSED_CONV:begin
                case (cnt_400)
                    3: begin mult_in2_1 = kernel[4][4]; mult_in2_2 = 8'b0; mult_in2_3 = 8'b0; mult_in2_4 = 8'b0; mult_in2_5 = 8'b0; end
                    default: begin mult_in2_1 = 8'b0; mult_in2_2 = 8'b0; mult_in2_3 = 8'b0; mult_in2_4 = 8'b0; mult_in2_5 = 8'b0; end
                endcase
            end
            OUT_TRANSPOSED_CONV:begin
                case (cnt_20)
                    14: begin 
                        mult_in2_1 = kernel[0][0]; 
                        mult_in2_2 = kernel[0][1];  
                        mult_in2_3 = kernel[0][2];  
                        mult_in2_4 = kernel[0][3];  
                        mult_in2_5 = kernel[0][4];                          
                    end
                    15: begin 
                        mult_in2_1 = kernel[1][0]; 
                        mult_in2_2 = kernel[1][1];  
                        mult_in2_3 = kernel[1][2];  
                        mult_in2_4 = kernel[1][3];  
                        mult_in2_5 = kernel[1][4];                          
                    end
                    16: begin 
                        mult_in2_1 = kernel[2][0]; 
                        mult_in2_2 = kernel[2][1];  
                        mult_in2_3 = kernel[2][2];  
                        mult_in2_4 = kernel[2][3];  
                        mult_in2_5 = kernel[2][4];                          
                    end
                    17: begin 
                        mult_in2_1 = kernel[3][0]; 
                        mult_in2_2 = kernel[3][1];  
                        mult_in2_3 = kernel[3][2];  
                        mult_in2_4 = kernel[3][3];  
                        mult_in2_5 = kernel[3][4];                          
                    end
                    18: begin 
                        mult_in2_1 = kernel[4][0]; 
                        mult_in2_2 = kernel[4][1];  
                        mult_in2_3 = kernel[4][2];  
                        mult_in2_4 = kernel[4][3];  
                        mult_in2_5 = kernel[4][4];                          
                    end
                    default: begin
                        mult_in2_1 = 8'b0; mult_in2_2 = 8'b0; mult_in2_3 = 8'b0; mult_in2_4 = 8'b0; mult_in2_5 = 8'b0;
                    end 
                endcase
            end
            default: begin
                mult_in2_1 = 8'b0; mult_in2_2 = 8'b0; mult_in2_3 = 8'b0; mult_in2_4 = 8'b0; mult_in2_5 = 8'b0;
            end 
        endcase                                    
end

always @(posedge clk or negedge rst_n) begin // mult_tmp1~5
    if (!rst_n) begin
        mult_tmp1 <= 16'b0;
        mult_tmp2 <= 16'b0;
        mult_tmp3 <= 16'b0;
        mult_tmp4 <= 16'b0;
        mult_tmp5 <= 16'b0;
    end else begin
        mult_tmp1 <= mult_out1;
        mult_tmp2 <= mult_out2;
        mult_tmp3 <= mult_out3;
        mult_tmp4 <= mult_out4;
        mult_tmp5 <= mult_out5;
    end
end

always @(*) begin // add_in1_1~5 、 add_in2_1~5
        case (c_state)
            CONVOLUTION: begin
                case (cnt_400)
                    4,5,6,7,8: begin 
                        add_in1_1 = mult_tmp1;    add_in2_1 = mult_tmp2;
                        add_in1_2 = mult_tmp3;    add_in2_2 = mult_tmp4; 
                        add_in1_3 = mult_tmp5;    add_in2_3 = map_tmp[0][0]; 
                        add_in1_4 = add_out1;     add_in2_4 = add_out2; 
                        add_in1_5 = add_out4;     add_in2_5 = add_out3;                         
                    end
                    9,10,11,12,13: begin 
                        add_in1_1 = mult_tmp1;    add_in2_1 = mult_tmp2;
                        add_in1_2 = mult_tmp3;    add_in2_2 = mult_tmp4; 
                        add_in1_3 = mult_tmp5;    add_in2_3 = map_tmp[1][0]; 
                        add_in1_4 = add_out1;     add_in2_4 = add_out2; 
                        add_in1_5 = add_out4;     add_in2_5 = add_out3;                         
                    end
                    14,15,16,17,18: begin 
                        add_in1_1 = mult_tmp1;    add_in2_1 = mult_tmp2;
                        add_in1_2 = mult_tmp3;    add_in2_2 = mult_tmp4; 
                        add_in1_3 = mult_tmp5;    add_in2_3 = map_tmp[0][1]; 
                        add_in1_4 = add_out1;     add_in2_4 = add_out2; 
                        add_in1_5 = add_out4;     add_in2_5 = add_out3;                         
                    end
                    19,20,21,22,23: begin 
                        add_in1_1 = mult_tmp1;    add_in2_1 = mult_tmp2;
                        add_in1_2 = mult_tmp3;    add_in2_2 = mult_tmp4; 
                        add_in1_3 = mult_tmp5;    add_in2_3 = map_tmp[1][1]; 
                        add_in1_4 = add_out1;     add_in2_4 = add_out2; 
                        add_in1_5 = add_out4;     add_in2_5 = add_out3;                         
                    end
                    default: begin
                        add_in1_1 = 20'b0; add_in1_2 = 20'b0; add_in1_3 = 20'b0; add_in1_4 = 20'b0; add_in1_5 = 20'b0;
                        add_in2_1 = 20'b0; add_in2_2 = 20'b0; add_in2_3 = 20'b0; add_in2_4 = 20'b0; add_in2_5 = 20'b0;
                    end 
                endcase
            end
            OUT_CONVOLUTION: begin
                case (cnt_20)
                    1,2,3,4: begin 
                        add_in1_1 = mult_tmp1;    add_in2_1 = mult_tmp2;
                        add_in1_2 = mult_tmp3;    add_in2_2 = mult_tmp4; 
                        add_in1_3 = mult_tmp5;    add_in2_3 = map_tmp[0][0]; 
                        add_in1_4 = add_out1;     add_in2_4 = add_out2; 
                        add_in1_5 = add_out4;     add_in2_5 = add_out3;                         
                    end

                    0,5,10,15:begin 
                        add_in1_1 = mult_tmp1;    add_in2_1 = mult_tmp2;
                        add_in1_2 = mult_tmp3;    add_in2_2 = mult_tmp4; 
                        add_in1_3 = mult_tmp5;    add_in2_3 = 16'd0; 
                        add_in1_4 = add_out1;     add_in2_4 = add_out2; 
                        add_in1_5 = add_out4;     add_in2_5 = add_out3;                         
                    end

                    6,7,8,9: begin 
                        add_in1_1 = mult_tmp1;    add_in2_1 = mult_tmp2;
                        add_in1_2 = mult_tmp3;    add_in2_2 = mult_tmp4; 
                        add_in1_3 = mult_tmp5;    add_in2_3 = map_tmp[1][0]; 
                        add_in1_4 = add_out1;     add_in2_4 = add_out2; 
                        add_in1_5 = add_out4;     add_in2_5 = add_out3;                         
                    end
                    11,12,13,14: begin 
                        add_in1_1 = mult_tmp1;    add_in2_1 = mult_tmp2;
                        add_in1_2 = mult_tmp3;    add_in2_2 = mult_tmp4; 
                        add_in1_3 = mult_tmp5;    add_in2_3 = map_tmp[0][1]; 
                        add_in1_4 = add_out1;     add_in2_4 = add_out2; 
                        add_in1_5 = add_out4;     add_in2_5 = add_out3;                         
                    end
                    16,17,18,19: begin 
                        add_in1_1 = mult_tmp1;    add_in2_1 = mult_tmp2;
                        add_in1_2 = mult_tmp3;    add_in2_2 = mult_tmp4; 
                        add_in1_3 = mult_tmp5;    add_in2_3 = map_tmp[1][1]; 
                        add_in1_4 = add_out1;     add_in2_4 = add_out2; 
                        add_in1_5 = add_out4;     add_in2_5 = add_out3;                         
                    end
                    default: begin
                        add_in1_1 = 20'b0; add_in1_2 = 20'b0; add_in1_3 = 20'b0; add_in1_4 = 20'b0; add_in1_5 = 20'b0;
                        add_in2_1 = 20'b0; add_in2_2 = 20'b0; add_in2_3 = 20'b0; add_in2_4 = 20'b0; add_in2_5 = 20'b0;
                    end 
                endcase
            end
            TRANSPOSED_CONV:begin
                case (cnt_400)
                    4: begin 
                        add_in1_1 = 20'b0; add_in1_2 = 20'b0; add_in1_3 = 20'b0; add_in1_4 = 20'b0; add_in1_5 = mult_tmp1;
                        add_in2_1 = 20'b0; add_in2_2 = 20'b0; add_in2_3 = 20'b0; add_in2_4 = 20'b0; add_in2_5 = 20'b0;                      
                    end
                    default: begin
                        add_in1_1 = 20'b0; add_in1_2 = 20'b0; add_in1_3 = 20'b0; add_in1_4 = 20'b0; add_in1_5 = 20'b0;
                        add_in2_1 = 20'b0; add_in2_2 = 20'b0; add_in2_3 = 20'b0; add_in2_4 = 20'b0; add_in2_5 = 20'b0;
                    end 
                endcase
            end
            OUT_TRANSPOSED_CONV: begin
                case (cnt_20)
                    15: begin 
                        add_in1_1 = mult_tmp1;    add_in2_1 = mult_tmp2;
                        add_in1_2 = mult_tmp3;    add_in2_2 = mult_tmp4; 
                        add_in1_3 = mult_tmp5;    add_in2_3 = 16'd0; 
                        add_in1_4 = add_out1;     add_in2_4 = add_out2; 
                        add_in1_5 = add_out4;     add_in2_5 = add_out3;                         
                    end
                    16,17,18,19: begin 
                        add_in1_1 = mult_tmp1;    add_in2_1 = mult_tmp2;
                        add_in1_2 = mult_tmp3;    add_in2_2 = mult_tmp4; 
                        add_in1_3 = mult_tmp5;    add_in2_3 = add_tmp; 
                        add_in1_4 = add_out1;     add_in2_4 = add_out2; 
                        add_in1_5 = add_out4;     add_in2_5 = add_out3;                         
                    end
                    default: begin
                        add_in1_1 = 20'b0; add_in1_2 = 20'b0; add_in1_3 = 20'b0; add_in1_4 = 20'b0; add_in1_5 = 20'b0;
                        add_in2_1 = 20'b0; add_in2_2 = 20'b0; add_in2_3 = 20'b0; add_in2_4 = 20'b0; add_in2_5 = 20'b0;
                    end 
                endcase
            end
            default: begin
                add_in1_1 = 20'b0; add_in1_2 = 20'b0; add_in1_3 = 20'b0; add_in1_4 = 20'b0; add_in1_5 = 20'b0;
                add_in2_1 = 20'b0; add_in2_2 = 20'b0; add_in2_3 = 20'b0; add_in2_4 = 20'b0; add_in2_5 = 20'b0;
            end 
        endcase
end


//---------------------------------------------------------------------
//   Registers
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin // pixel
    if (!rst_n) begin
        for (i = 0; i < 6 ; i = i + 1) begin
            for (j = 0 ; j < 8 ; j = j + 1) begin
                pixel[i][j] <= 8'b0;
            end
        end
    end 
    else begin
        case (c_state)
            CONVOLUTION: begin
                case (cnt_400)
                    9'd2:  begin {pixel[0][0],pixel[0][1],pixel[0][2],pixel[0][3],pixel[0][4],pixel[0][5],pixel[0][6],pixel[0][7]} <= d_out; end
                    9'd3:  begin {pixel[1][0],pixel[1][1],pixel[1][2],pixel[1][3],pixel[1][4],pixel[1][5],pixel[1][6],pixel[1][7]} <= d_out; end
                    9'd4:  begin {pixel[2][0],pixel[2][1],pixel[2][2],pixel[2][3],pixel[2][4],pixel[2][5],pixel[2][6],pixel[2][7]} <= d_out; end
                    9'd5:  begin {pixel[3][0],pixel[3][1],pixel[3][2],pixel[3][3],pixel[3][4],pixel[3][5],pixel[3][6],pixel[3][7]} <= d_out; end
                    9'd6:  begin {pixel[4][0],pixel[4][1],pixel[4][2],pixel[4][3],pixel[4][4],pixel[4][5],pixel[4][6],pixel[4][7]} <= d_out; end
                    9'd7:  begin {pixel[5][0],pixel[5][1],pixel[5][2],pixel[5][3],pixel[5][4],pixel[5][5],pixel[5][6],pixel[5][7]} <= d_out; end
                    
                    9'd8:  begin {pixel[0][0],pixel[0][1],pixel[0][2],pixel[0][3],pixel[0][4],pixel[0][5],pixel[0][6],pixel[0][7]} <= {pixel[0][1],pixel[0][2],pixel[0][3],pixel[0][4],pixel[0][5],pixel[0][6],pixel[0][7],d_out[63:56]}; end
                    9'd9:  begin {pixel[1][0],pixel[1][1],pixel[1][2],pixel[1][3],pixel[1][4],pixel[1][5],pixel[1][6],pixel[1][7]} <= {pixel[1][1],pixel[1][2],pixel[1][3],pixel[1][4],pixel[1][5],pixel[1][6],pixel[1][7],d_out[63:56]}; end
                    9'd10: begin {pixel[2][0],pixel[2][1],pixel[2][2],pixel[2][3],pixel[2][4],pixel[2][5],pixel[2][6],pixel[2][7]} <= {pixel[2][1],pixel[2][2],pixel[2][3],pixel[2][4],pixel[2][5],pixel[2][6],pixel[2][7],d_out[63:56]}; end
                    9'd11: begin {pixel[3][0],pixel[3][1],pixel[3][2],pixel[3][3],pixel[3][4],pixel[3][5],pixel[3][6],pixel[3][7]} <= {pixel[3][1],pixel[3][2],pixel[3][3],pixel[3][4],pixel[3][5],pixel[3][6],pixel[3][7],d_out[63:56]}; end
                    9'd12: begin {pixel[4][0],pixel[4][1],pixel[4][2],pixel[4][3],pixel[4][4],pixel[4][5],pixel[4][6],pixel[4][7]} <= {pixel[4][1],pixel[4][2],pixel[4][3],pixel[4][4],pixel[4][5],pixel[4][6],pixel[4][7],d_out[63:56]}; end
                    9'd13: begin {pixel[5][0],pixel[5][1],pixel[5][2],pixel[5][3],pixel[5][4],pixel[5][5],pixel[5][6],pixel[5][7]} <= {pixel[5][1],pixel[5][2],pixel[5][3],pixel[5][4],pixel[5][5],pixel[5][6],pixel[5][7],d_out[63:56]}; end
                    
                    9'd14: begin {pixel[0][0],pixel[0][1],pixel[0][2],pixel[0][3],pixel[0][4],pixel[0][5],pixel[0][6],pixel[0][7]} <= {pixel[0][1],pixel[0][2],pixel[0][3],pixel[0][4],pixel[0][5],pixel[0][6],pixel[0][7],pixel_next[0][1]}; end
                    
                    9'd19: begin {pixel[1][0],pixel[1][1],pixel[1][2],pixel[1][3],pixel[1][4],pixel[1][5],pixel[1][6],pixel[1][7]} <= {pixel[1][1],pixel[1][2],pixel[1][3],pixel[1][4],pixel[1][5],pixel[1][6],pixel[1][7],pixel_next[1][1]}; end
                    9'd20: begin {pixel[2][0],pixel[2][1],pixel[2][2],pixel[2][3],pixel[2][4],pixel[2][5],pixel[2][6],pixel[2][7]} <= {pixel[2][1],pixel[2][2],pixel[2][3],pixel[2][4],pixel[2][5],pixel[2][6],pixel[2][7],pixel_next[2][1]}; end
                    9'd21: begin {pixel[3][0],pixel[3][1],pixel[3][2],pixel[3][3],pixel[3][4],pixel[3][5],pixel[3][6],pixel[3][7]} <= {pixel[3][1],pixel[3][2],pixel[3][3],pixel[3][4],pixel[3][5],pixel[3][6],pixel[3][7],pixel_next[3][1]}; end
                    9'd22: begin {pixel[4][0],pixel[4][1],pixel[4][2],pixel[4][3],pixel[4][4],pixel[4][5],pixel[4][6],pixel[4][7]} <= {pixel[4][1],pixel[4][2],pixel[4][3],pixel[4][4],pixel[4][5],pixel[4][6],pixel[4][7],pixel_next[4][1]}; end
                    9'd23: begin {pixel[5][0],pixel[5][1],pixel[5][2],pixel[5][3],pixel[5][4],pixel[5][5],pixel[5][6],pixel[5][7]} <= {pixel[5][1],pixel[5][2],pixel[5][3],pixel[5][4],pixel[5][5],pixel[5][6],pixel[5][7],pixel_next[5][1]}; end
                    default: pixel[0][0] <= pixel[0][0];
                endcase
            end
            OUT_CONVOLUTION:begin
                    case (cnt_20)
                        9'd0:  begin 
                            if (shift_num == 6'd0) begin
                                {pixel[0][0],pixel[0][1],pixel[0][2],pixel[0][3],pixel[0][4],pixel[0][5],pixel[0][6],pixel[0][7]} <= {pixel[0][1],pixel[0][2],pixel[0][3],pixel[0][4],pixel[0][5],pixel[0][6],pixel[0][7],d_out[63:56]}; 
                            end 
                            else begin
                                {pixel[0][0],pixel[0][1],pixel[0][2],pixel[0][3],pixel[0][4],pixel[0][5],pixel[0][6],pixel[0][7]} <= {pixel[0][1],pixel[0][2],pixel[0][3],pixel[0][4],pixel[0][5],pixel[0][6],pixel[0][7],pixel_next[0][cnt_data_runout]};
                            end
                        end 
                        9'd5:  begin {pixel[1][0],pixel[1][1],pixel[1][2],pixel[1][3],pixel[1][4],pixel[1][5],pixel[1][6],pixel[1][7]} <= {pixel[1][1],pixel[1][2],pixel[1][3],pixel[1][4],pixel[1][5],pixel[1][6],pixel[1][7],pixel_next[1][cnt_data_runout]}; end
                        9'd6:  begin {pixel[2][0],pixel[2][1],pixel[2][2],pixel[2][3],pixel[2][4],pixel[2][5],pixel[2][6],pixel[2][7]} <= {pixel[2][1],pixel[2][2],pixel[2][3],pixel[2][4],pixel[2][5],pixel[2][6],pixel[2][7],pixel_next[2][cnt_data_runout]}; end
                        9'd7:  begin {pixel[3][0],pixel[3][1],pixel[3][2],pixel[3][3],pixel[3][4],pixel[3][5],pixel[3][6],pixel[3][7]} <= {pixel[3][1],pixel[3][2],pixel[3][3],pixel[3][4],pixel[3][5],pixel[3][6],pixel[3][7],pixel_next[3][cnt_data_runout]}; end
                        9'd8:  begin {pixel[4][0],pixel[4][1],pixel[4][2],pixel[4][3],pixel[4][4],pixel[4][5],pixel[4][6],pixel[4][7]} <= {pixel[4][1],pixel[4][2],pixel[4][3],pixel[4][4],pixel[4][5],pixel[4][6],pixel[4][7],pixel_next[4][cnt_data_runout]}; end
                        9'd9:  begin {pixel[5][0],pixel[5][1],pixel[5][2],pixel[5][3],pixel[5][4],pixel[5][5],pixel[5][6],pixel[5][7]} <= {pixel[5][1],pixel[5][2],pixel[5][3],pixel[5][4],pixel[5][5],pixel[5][6],pixel[5][7],pixel_next[5][cnt_data_runout]}; end
                        
                        9'd10: begin
                            if (shift_num == row_end) begin
                                if (Msize_cs == 2'd0) begin
                                    {pixel[0][0],pixel[0][1],pixel[0][2],pixel[0][3],pixel[0][4],pixel[0][5],pixel[0][6],pixel[0][7]} <= {pixel_next[0][0],pixel_next[0][1],pixel_next[0][2],pixel_next[0][3],pixel_next[0][4],pixel_next[0][5],pixel_next[0][6],pixel_next[0][7]} ;
                                end else begin
                                    {pixel[0][0],pixel[0][1],pixel[0][2],pixel[0][3],pixel[0][4],pixel[0][5],pixel[0][6],pixel[0][7]} <= d_out;
                                end
                            end 
                            else begin
                                {pixel[0][0],pixel[0][1],pixel[0][2],pixel[0][3],pixel[0][4],pixel[0][5],pixel[0][6],pixel[0][7]} <= {pixel[0][1],pixel[0][2],pixel[0][3],pixel[0][4],pixel[0][5],pixel[0][6],pixel[0][7],pixel_next[0][cnt_data_runout]}; 
                            end
                        end
                        
                        9'd15:  begin 
                            if (shift_num == row_end) begin
                                if (Msize_cs == 2'd0) begin
                                    {pixel[1][0],pixel[1][1],pixel[1][2],pixel[1][3],pixel[1][4],pixel[1][5],pixel[1][6],pixel[1][7]} <= {pixel_next[1][0],pixel_next[1][1],pixel_next[1][2],pixel_next[1][3],pixel_next[1][4],pixel_next[1][5],pixel_next[1][6],pixel_next[1][7]} ;
                                end else begin
                                    {pixel[1][0],pixel[1][1],pixel[1][2],pixel[1][3],pixel[1][4],pixel[1][5],pixel[1][6],pixel[1][7]} <= d_out;
                                end
                            end 
                            else begin
                                {pixel[1][0],pixel[1][1],pixel[1][2],pixel[1][3],pixel[1][4],pixel[1][5],pixel[1][6],pixel[1][7]} <= {pixel[1][1],pixel[1][2],pixel[1][3],pixel[1][4],pixel[1][5],pixel[1][6],pixel[1][7],pixel_next[1][cnt_data_runout]}; 
                            end
                        end
                        9'd16:  begin 
                            if (shift_num == row_end) begin
                                if (Msize_cs == 2'd0) begin
                                    {pixel[2][0],pixel[2][1],pixel[2][2],pixel[2][3],pixel[2][4],pixel[2][5],pixel[2][6],pixel[2][7]} <= {pixel_next[2][0],pixel_next[2][1],pixel_next[2][2],pixel_next[2][3],pixel_next[2][4],pixel_next[2][5],pixel_next[2][6],pixel_next[2][7]} ;
                                end else begin
                                    {pixel[2][0],pixel[2][1],pixel[2][2],pixel[2][3],pixel[2][4],pixel[2][5],pixel[2][6],pixel[2][7]} <= d_out;
                                end
                            end 
                            else begin
                                {pixel[2][0],pixel[2][1],pixel[2][2],pixel[2][3],pixel[2][4],pixel[2][5],pixel[2][6],pixel[2][7]} <= {pixel[2][1],pixel[2][2],pixel[2][3],pixel[2][4],pixel[2][5],pixel[2][6],pixel[2][7],pixel_next[2][cnt_data_runout]}; 
                            end
                        end
                        9'd17:  begin 
                            if (shift_num == row_end) begin
                                if (Msize_cs == 2'd0) begin
                                    {pixel[3][0],pixel[3][1],pixel[3][2],pixel[3][3],pixel[3][4],pixel[3][5],pixel[3][6],pixel[3][7]} <= {pixel_next[3][0],pixel_next[3][1],pixel_next[3][2],pixel_next[3][3],pixel_next[3][4],pixel_next[3][5],pixel_next[3][6],pixel_next[3][7]} ;
                                end else begin
                                    {pixel[3][0],pixel[3][1],pixel[3][2],pixel[3][3],pixel[3][4],pixel[3][5],pixel[3][6],pixel[3][7]} <= d_out;
                                end
                            end 
                            else begin
                                {pixel[3][0],pixel[3][1],pixel[3][2],pixel[3][3],pixel[3][4],pixel[3][5],pixel[3][6],pixel[3][7]} <= {pixel[3][1],pixel[3][2],pixel[3][3],pixel[3][4],pixel[3][5],pixel[3][6],pixel[3][7],pixel_next[3][cnt_data_runout]}; 
                            end
                        end
                        9'd18:  begin 
                            if (shift_num == row_end) begin
                                if (Msize_cs == 2'd0) begin
                                    {pixel[4][0],pixel[4][1],pixel[4][2],pixel[4][3],pixel[4][4],pixel[4][5],pixel[4][6],pixel[4][7]} <= {pixel_next[4][0],pixel_next[4][1],pixel_next[4][2],pixel_next[4][3],pixel_next[4][4],pixel_next[4][5],pixel_next[4][6],pixel_next[4][7]} ;
                                end else begin
                                    {pixel[4][0],pixel[4][1],pixel[4][2],pixel[4][3],pixel[4][4],pixel[4][5],pixel[4][6],pixel[4][7]} <= d_out;
                                end
                            end 
                            else begin
                                {pixel[4][0],pixel[4][1],pixel[4][2],pixel[4][3],pixel[4][4],pixel[4][5],pixel[4][6],pixel[4][7]} <= {pixel[4][1],pixel[4][2],pixel[4][3],pixel[4][4],pixel[4][5],pixel[4][6],pixel[4][7],pixel_next[4][cnt_data_runout]}; 
                            end
                        end
                        9'd19:  begin 
                            if (shift_num == row_end) begin
                                if (Msize_cs == 2'd0) begin
                                    {pixel[5][0],pixel[5][1],pixel[5][2],pixel[5][3],pixel[5][4],pixel[5][5],pixel[5][6],pixel[5][7]} <= {pixel_next[5][0],pixel_next[5][1],pixel_next[5][2],pixel_next[5][3],pixel_next[5][4],pixel_next[5][5],pixel_next[5][6],pixel_next[5][7]} ;
                                end else begin
                                    {pixel[5][0],pixel[5][1],pixel[5][2],pixel[5][3],pixel[5][4],pixel[5][5],pixel[5][6],pixel[5][7]} <= d_out;
                                end
                            end 
                            else begin
                                {pixel[5][0],pixel[5][1],pixel[5][2],pixel[5][3],pixel[5][4],pixel[5][5],pixel[5][6],pixel[5][7]} <= {pixel[5][1],pixel[5][2],pixel[5][3],pixel[5][4],pixel[5][5],pixel[5][6],pixel[5][7],pixel_next[5][cnt_data_runout]}; 
                            end
                        end
                        default: pixel[0][0] <= pixel[0][0];
                    endcase   
            end
            TRANSPOSED_CONV:begin
                case (cnt_400)
                    9'd0: begin  {pixel[0][0],pixel[0][1],pixel[0][2],pixel[0][3],pixel[0][4],pixel[0][5],pixel[0][6],pixel[0][7]} <= 8'd0;
                                 {pixel[1][0],pixel[1][1],pixel[1][2],pixel[1][3],pixel[1][4],pixel[1][5],pixel[1][6],pixel[1][7]} <= 8'd0; 
                                 {pixel[2][0],pixel[2][1],pixel[2][2],pixel[2][3],pixel[2][4],pixel[2][5],pixel[2][6],pixel[2][7]} <= 8'd0; 
                                 {pixel[3][0],pixel[3][1],pixel[3][2],pixel[3][3],pixel[3][4],pixel[3][5],pixel[3][6],pixel[3][7]} <= 8'd0; 
                                 {pixel[4][0],pixel[4][1],pixel[4][2],pixel[4][3],pixel[4][4],pixel[4][5],pixel[4][6],pixel[4][7]} <= 8'd0; 
                    end
                    9'd2: begin
                        {pixel[4][4],pixel[4][5],pixel[4][6],pixel[4][7]} <= d_out[63:32];
                    end 

                    
                    default: pixel[0][0] <= pixel[0][0];
                endcase
            end
            OUT_TRANSPOSED_CONV:begin
                case (cnt_20)
                    2: begin
                        if (shift_num == 6'd0) begin
                            {pixel[0][0],pixel[0][1],pixel[0][2],pixel[0][3],pixel[0][4],pixel[0][5],pixel[0][6],pixel[0][7]} <= {img_5_tmp[0][0],img_5_tmp[0][1],img_5_tmp[0][2],img_5_tmp[0][3],img_5_tmp[0][4],img_5_tmp[0][5],img_5_tmp[0][6],img_5_tmp[0][7]};
                            {pixel[1][0],pixel[1][1],pixel[1][2],pixel[1][3],pixel[1][4],pixel[1][5],pixel[1][6],pixel[1][7]} <= {img_5_tmp[1][0],img_5_tmp[1][1],img_5_tmp[1][2],img_5_tmp[1][3],img_5_tmp[1][4],img_5_tmp[1][5],img_5_tmp[1][6],img_5_tmp[1][7]};
                            {pixel[2][0],pixel[2][1],pixel[2][2],pixel[2][3],pixel[2][4],pixel[2][5],pixel[2][6],pixel[2][7]} <= {img_5_tmp[2][0],img_5_tmp[2][1],img_5_tmp[2][2],img_5_tmp[2][3],img_5_tmp[2][4],img_5_tmp[2][5],img_5_tmp[2][6],img_5_tmp[2][7]};
                            {pixel[3][0],pixel[3][1],pixel[3][2],pixel[3][3],pixel[3][4],pixel[3][5],pixel[3][6],pixel[3][7]} <= {img_5_tmp[3][0],img_5_tmp[3][1],img_5_tmp[3][2],img_5_tmp[3][3],img_5_tmp[3][4],img_5_tmp[3][5],img_5_tmp[3][6],img_5_tmp[3][7]};
                            {pixel[4][0],pixel[4][1],pixel[4][2],pixel[4][3],pixel[4][4],pixel[4][5],pixel[4][6],pixel[4][7]} <= {img_5_tmp[4][0],img_5_tmp[4][1],img_5_tmp[4][2],img_5_tmp[4][3],img_5_tmp[4][4],img_5_tmp[4][5],img_5_tmp[4][6],img_5_tmp[4][7]};
                        end 
                        else begin
                            {pixel[0][0],pixel[0][1],pixel[0][2],pixel[0][3],pixel[0][4],pixel[0][5],pixel[0][6],pixel[0][7]} <= {pixel[0][1],pixel[0][2],pixel[0][3],pixel[0][4],pixel[0][5],pixel[0][6],pixel[0][7],img_5_tmp[0][take_next_bit]};
                            {pixel[1][0],pixel[1][1],pixel[1][2],pixel[1][3],pixel[1][4],pixel[1][5],pixel[1][6],pixel[1][7]} <= {pixel[1][1],pixel[1][2],pixel[1][3],pixel[1][4],pixel[1][5],pixel[1][6],pixel[1][7],img_5_tmp[1][take_next_bit]};
                            {pixel[2][0],pixel[2][1],pixel[2][2],pixel[2][3],pixel[2][4],pixel[2][5],pixel[2][6],pixel[2][7]} <= {pixel[2][1],pixel[2][2],pixel[2][3],pixel[2][4],pixel[2][5],pixel[2][6],pixel[2][7],img_5_tmp[2][take_next_bit]};   
                            {pixel[3][0],pixel[3][1],pixel[3][2],pixel[3][3],pixel[3][4],pixel[3][5],pixel[3][6],pixel[3][7]} <= {pixel[3][1],pixel[3][2],pixel[3][3],pixel[3][4],pixel[3][5],pixel[3][6],pixel[3][7],img_5_tmp[3][take_next_bit]};
                            {pixel[4][0],pixel[4][1],pixel[4][2],pixel[4][3],pixel[4][4],pixel[4][5],pixel[4][6],pixel[4][7]} <= {pixel[4][1],pixel[4][2],pixel[4][3],pixel[4][4],pixel[4][5],pixel[4][6],pixel[4][7],img_5_tmp[4][take_next_bit]};
                        end
                    end
                    
                    default: pixel[0][0] <= pixel[0][0];
                endcase
            end
            default: pixel[0][0] <= pixel[0][0];

        endcase
    end
end

always @(posedge clk or negedge rst_n) begin // pixel_next
    if (!rst_n) begin
        for (i = 0; i < 6 ; i = i + 1) begin
            for (j = 0 ; j < 8 ; j = j + 1) begin
                pixel_next[i][j] <= 8'b0;
            end
        end
    end 
    else begin
        case (c_state)
            CONVOLUTION: begin
                if (Msize_cs == 0) begin // for 8*8
                    case (cnt_400)
                        9'd4:  begin {pixel_next[0][0],pixel_next[0][1],pixel_next[0][2],pixel_next[0][3],pixel_next[0][4],pixel_next[0][5],pixel_next[0][6],pixel_next[0][7]} <= d_out; end
                        9'd5:  begin {pixel_next[1][0],pixel_next[1][1],pixel_next[1][2],pixel_next[1][3],pixel_next[1][4],pixel_next[1][5],pixel_next[1][6],pixel_next[1][7]} <= d_out; end
                        9'd6:  begin {pixel_next[2][0],pixel_next[2][1],pixel_next[2][2],pixel_next[2][3],pixel_next[2][4],pixel_next[2][5],pixel_next[2][6],pixel_next[2][7]} <= d_out; end
                        9'd7:  begin {pixel_next[3][0],pixel_next[3][1],pixel_next[3][2],pixel_next[3][3],pixel_next[3][4],pixel_next[3][5],pixel_next[3][6],pixel_next[3][7]} <= d_out; end
                        9'd8:  begin {pixel_next[4][0],pixel_next[4][1],pixel_next[4][2],pixel_next[4][3],pixel_next[4][4],pixel_next[4][5],pixel_next[4][6],pixel_next[4][7]} <= d_out; end
                        9'd9:  begin {pixel_next[5][0],pixel_next[5][1],pixel_next[5][2],pixel_next[5][3],pixel_next[5][4],pixel_next[5][5],pixel_next[5][6],pixel_next[5][7]} <= d_out; end
                        default: pixel_next[0][0] <= pixel_next[0][0];
                    endcase
                end
                else begin // for 16*16  32*32
                    case (cnt_400)
                        9'd8:  begin {pixel_next[0][0],pixel_next[0][1],pixel_next[0][2],pixel_next[0][3],pixel_next[0][4],pixel_next[0][5],pixel_next[0][6],pixel_next[0][7]} <= d_out; end
                        9'd9:  begin {pixel_next[1][0],pixel_next[1][1],pixel_next[1][2],pixel_next[1][3],pixel_next[1][4],pixel_next[1][5],pixel_next[1][6],pixel_next[1][7]} <= d_out; end
                        9'd10: begin {pixel_next[2][0],pixel_next[2][1],pixel_next[2][2],pixel_next[2][3],pixel_next[2][4],pixel_next[2][5],pixel_next[2][6],pixel_next[2][7]} <= d_out; end
                        9'd11: begin {pixel_next[3][0],pixel_next[3][1],pixel_next[3][2],pixel_next[3][3],pixel_next[3][4],pixel_next[3][5],pixel_next[3][6],pixel_next[3][7]} <= d_out; end
                        9'd12: begin {pixel_next[4][0],pixel_next[4][1],pixel_next[4][2],pixel_next[4][3],pixel_next[4][4],pixel_next[4][5],pixel_next[4][6],pixel_next[4][7]} <= d_out; end
                        9'd13: begin {pixel_next[5][0],pixel_next[5][1],pixel_next[5][2],pixel_next[5][3],pixel_next[5][4],pixel_next[5][5],pixel_next[5][6],pixel_next[5][7]} <= d_out; end
                        default: pixel_next[0][0] <= pixel_next[0][0];
                    endcase
                end
            end
            OUT_CONVOLUTION: begin
                if (shift_num == 6'd0) begin
                    case (cnt_20)
                      9'd0: begin {pixel_next[0][0],pixel_next[0][1],pixel_next[0][2],pixel_next[0][3],pixel_next[0][4],pixel_next[0][5],pixel_next[0][6],pixel_next[0][7]} <= d_out; end
                      9'd1: begin {pixel_next[1][0],pixel_next[1][1],pixel_next[1][2],pixel_next[1][3],pixel_next[1][4],pixel_next[1][5],pixel_next[1][6],pixel_next[1][7]} <= d_out; end
                      9'd2: begin {pixel_next[2][0],pixel_next[2][1],pixel_next[2][2],pixel_next[2][3],pixel_next[2][4],pixel_next[2][5],pixel_next[2][6],pixel_next[2][7]} <= d_out; end
                      9'd3: begin {pixel_next[3][0],pixel_next[3][1],pixel_next[3][2],pixel_next[3][3],pixel_next[3][4],pixel_next[3][5],pixel_next[3][6],pixel_next[3][7]} <= d_out; end
                      9'd4: begin {pixel_next[4][0],pixel_next[4][1],pixel_next[4][2],pixel_next[4][3],pixel_next[4][4],pixel_next[4][5],pixel_next[4][6],pixel_next[4][7]} <= d_out; end
                      9'd5: begin {pixel_next[5][0],pixel_next[5][1],pixel_next[5][2],pixel_next[5][3],pixel_next[5][4],pixel_next[5][5],pixel_next[5][6],pixel_next[5][7]} <= d_out; end
                      default: pixel_next[0][0] <= pixel_next[0][0];  
                    endcase
                end
                else if (cnt_data_runout == 3'd7) begin
                    case (cnt_20)
                      9'd12: begin {pixel_next[0][0],pixel_next[0][1],pixel_next[0][2],pixel_next[0][3],pixel_next[0][4],pixel_next[0][5],pixel_next[0][6],pixel_next[0][7]} <= d_out; end
                      9'd15: begin {pixel_next[1][0],pixel_next[1][1],pixel_next[1][2],pixel_next[1][3],pixel_next[1][4],pixel_next[1][5],pixel_next[1][6],pixel_next[1][7]} <= d_out; end
                      9'd16: begin {pixel_next[2][0],pixel_next[2][1],pixel_next[2][2],pixel_next[2][3],pixel_next[2][4],pixel_next[2][5],pixel_next[2][6],pixel_next[2][7]} <= d_out; end
                      9'd17: begin {pixel_next[3][0],pixel_next[3][1],pixel_next[3][2],pixel_next[3][3],pixel_next[3][4],pixel_next[3][5],pixel_next[3][6],pixel_next[3][7]} <= d_out; end
                      9'd18: begin {pixel_next[4][0],pixel_next[4][1],pixel_next[4][2],pixel_next[4][3],pixel_next[4][4],pixel_next[4][5],pixel_next[4][6],pixel_next[4][7]} <= d_out; end
                      9'd19: begin {pixel_next[5][0],pixel_next[5][1],pixel_next[5][2],pixel_next[5][3],pixel_next[5][4],pixel_next[5][5],pixel_next[5][6],pixel_next[5][7]} <= d_out; end
                      default: pixel_next[0][0] <= pixel_next[0][0];  
                    endcase
                end
                else begin
                    pixel_next[0][0] <= pixel_next[0][0];
                end
            end
            default: pixel_next[0][0] <= pixel_next[0][0];
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin // img_5_tmp
    if (!rst_n) begin
        for (i = 0; i < 5 ; i = i + 1) begin
            for (j = 0 ; j < 40 ; j = j + 1) begin
                img_5_tmp[i][j] <= 8'b0;
            end
        end
    end 
    else begin
        case (c_state)
            TRANSPOSED_CONV: begin
                case (cnt_400)
                    5'd2: begin
                        for (i = 0; i < 4 ; i = i + 1) begin
                            for (j = 0 ; j < 40 ; j = j + 1) begin
                                img_5_tmp[i][j] <= 8'b0;
                            end
                        end
                        for (i = 0;i < 4;i = i +1 ) begin
                            img_5_tmp[4][i] <= 8'b0;
                        end
                        for (i = 12;i < 40;i = i +1 ) begin
                            img_5_tmp[4][i] <= 8'b0;
                        end
                        {img_5_tmp[4][4],img_5_tmp[4][5],img_5_tmp[4][6],img_5_tmp[4][7],img_5_tmp[4][8],img_5_tmp[4][9],img_5_tmp[4][10],img_5_tmp[4][11]} <= d_out;
                    end

                    5'd3: begin
                        {img_5_tmp[4][12],img_5_tmp[4][13],img_5_tmp[4][14],img_5_tmp[4][15],img_5_tmp[4][16],img_5_tmp[4][17],img_5_tmp[4][18],img_5_tmp[4][19]} <= (Msize_cs == 2'd0) ? 64'b0: d_out;
                    end
                    4:begin
                        {img_5_tmp[4][20],img_5_tmp[4][21],img_5_tmp[4][22],img_5_tmp[4][23],img_5_tmp[4][24],img_5_tmp[4][25],img_5_tmp[4][26],img_5_tmp[4][27]} <= (Msize_cs == 2'd2) ? d_out: 64'b0;
                    end
                    5:begin
                        {img_5_tmp[4][28],img_5_tmp[4][29],img_5_tmp[4][30],img_5_tmp[4][31],img_5_tmp[4][32],img_5_tmp[4][33],img_5_tmp[4][34],img_5_tmp[4][35]} <= (Msize_cs == 2'd2) ? d_out: 64'b0;
                    end
                    default: img_5_tmp[0][0] <= img_5_tmp[0][0];
                endcase
            end
            OUT_TRANSPOSED_CONV: begin
                if (shift_num == row_end) begin
                    case (cnt_20)
                        2: begin
                            for (i = 0; i < 4 ; i = i + 1) begin
                                for (j = 0 ; j < 36 ; j = j + 1) begin
                                    img_5_tmp[i][j] <= img_5_tmp[i+1][j];
                                end
                            end
                             for (i = 0;i < 4;i = i +1 ) begin
                                img_5_tmp[4][i] <= 8'b0;
                            end
                            for (i = 12;i < 40;i = i +1 ) begin
                                img_5_tmp[4][i] <= 8'b0;
                            end
                        end
                        3: begin
                            if (row_zero_select)
                                {img_5_tmp[4][4],img_5_tmp[4][5],img_5_tmp[4][6],img_5_tmp[4][7],img_5_tmp[4][8],img_5_tmp[4][9],img_5_tmp[4][10],img_5_tmp[4][11]} <= 64'b0;
                            else
                                {img_5_tmp[4][4],img_5_tmp[4][5],img_5_tmp[4][6],img_5_tmp[4][7],img_5_tmp[4][8],img_5_tmp[4][9],img_5_tmp[4][10],img_5_tmp[4][11]} <= d_out;
                        
                        end
                        4: begin
                            if (row_zero_select)
                                {img_5_tmp[4][12],img_5_tmp[4][13],img_5_tmp[4][14],img_5_tmp[4][15],img_5_tmp[4][16],img_5_tmp[4][17],img_5_tmp[4][18],img_5_tmp[4][19]} <= 64'b0;
                            else
                                {img_5_tmp[4][12],img_5_tmp[4][13],img_5_tmp[4][14],img_5_tmp[4][15],img_5_tmp[4][16],img_5_tmp[4][17],img_5_tmp[4][18],img_5_tmp[4][19]} <= (Msize_cs == 2'd0) ? 64'b0: d_out;
                        end
                        5:begin
                            if (row_zero_select)
                                {img_5_tmp[4][20],img_5_tmp[4][21],img_5_tmp[4][22],img_5_tmp[4][23],img_5_tmp[4][24],img_5_tmp[4][25],img_5_tmp[4][26],img_5_tmp[4][27]} <= 64'b0;
                            else
                                {img_5_tmp[4][20],img_5_tmp[4][21],img_5_tmp[4][22],img_5_tmp[4][23],img_5_tmp[4][24],img_5_tmp[4][25],img_5_tmp[4][26],img_5_tmp[4][27]} <= (Msize_cs == 2'd2) ? d_out: 64'b0;
                        end
                        6:begin
                            if (row_zero_select)
                                {img_5_tmp[4][28],img_5_tmp[4][29],img_5_tmp[4][30],img_5_tmp[4][31],img_5_tmp[4][32],img_5_tmp[4][33],img_5_tmp[4][34],img_5_tmp[4][35]} <= 64'b0;
                            else                    
                                {img_5_tmp[4][28],img_5_tmp[4][29],img_5_tmp[4][30],img_5_tmp[4][31],img_5_tmp[4][32],img_5_tmp[4][33],img_5_tmp[4][34],img_5_tmp[4][35]} <= (Msize_cs == 2'd2) ? d_out: 64'b0;
                        end
                        default: img_5_tmp[0][0] <= img_5_tmp[0][0];
                    endcase
                end else begin
                    img_5_tmp[0][0] <= img_5_tmp[0][0];
                end
            end
            default: img_5_tmp[0][0] <= img_5_tmp[0][0];
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin // kernel
    if (!rst_n) begin
        for (i = 0; i < 5 ; i = i + 1) begin
            for (j = 0 ; j < 5 ; j = j + 1) begin
                kernel[i][j] <= 8'b0;
            end
        end
    end 
    else begin
        case (c_state)
            CONVOLUTION: begin
                case (cnt_400)
                    9'd2: begin {kernel[0][0],kernel[0][1],kernel[0][2],kernel[0][3],kernel[0][4]} <= k_out; end
                    9'd3: begin {kernel[1][0],kernel[1][1],kernel[1][2],kernel[1][3],kernel[1][4]} <= k_out; end
                    9'd4: begin {kernel[2][0],kernel[2][1],kernel[2][2],kernel[2][3],kernel[2][4]} <= k_out; end
                    9'd5: begin {kernel[3][0],kernel[3][1],kernel[3][2],kernel[3][3],kernel[3][4]} <= k_out; end
                    9'd6: begin {kernel[4][0],kernel[4][1],kernel[4][2],kernel[4][3],kernel[4][4]} <= k_out; end
                    default: kernel[0][0] <= kernel[0][0];
                endcase
            end
            TRANSPOSED_CONV: begin
                case (cnt_400)
                    9'd2: begin {kernel[4][4],kernel[4][3],kernel[4][2],kernel[4][1],kernel[4][0]} <= k_out; end
                    9'd3: begin {kernel[3][4],kernel[3][3],kernel[3][2],kernel[3][1],kernel[3][0]} <= k_out; end
                    9'd4: begin {kernel[2][4],kernel[2][3],kernel[2][2],kernel[2][1],kernel[2][0]} <= k_out; end
                    9'd5: begin {kernel[1][4],kernel[1][3],kernel[1][2],kernel[1][1],kernel[1][0]} <= k_out; end
                    9'd6: begin {kernel[0][4],kernel[0][3],kernel[0][2],kernel[0][1],kernel[0][0]} <= k_out; end
                    default: kernel[0][0] <= kernel[0][0];
                endcase
            end
            default: kernel[0][0] <= kernel[0][0];
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin // map_tmp
    if (!rst_n) begin
        map_tmp[0][0] <= 20'b0; map_tmp[0][1] <= 20'b0; map_tmp[1][0] <= 20'b0; map_tmp[1][1] <= 20'b0;
    end 
    else begin
        case (c_state)
            WAIT_MATRIX: begin
                map_tmp[0][0] <= 20'b0; map_tmp[0][1] <= 20'b0; map_tmp[1][0] <= 20'b0; map_tmp[1][1] <= 20'b0;
            end
            CONVOLUTION: begin
                case (cnt_400)
                    4,5,6,7,8: begin map_tmp[0][0] <= add_out5; end
                    9,10,11,12,13: begin map_tmp[1][0] <= add_out5; end
                    14,15,16,17,18: begin map_tmp[0][1] <= add_out5; end
                    19,20,21,22,23: begin map_tmp[1][1] <= add_out5; end
                    default: map_tmp[0][0] <= map_tmp[0][0];
                endcase
            end
            OUT_CONVOLUTION: begin
                case (cnt_20)
                    0,1,2,3,4: begin map_tmp[0][0] <= add_out5; end
                    5,6,7,8,9: begin map_tmp[1][0] <= add_out5; end
                    10,11,12,13,14: begin map_tmp[0][1] <= add_out5; end
                    15,16,17,18,19: begin map_tmp[1][1] <= add_out5; end
                    default: map_tmp[0][0] <= map_tmp[0][0];
                endcase
            end
            default: map_tmp[0][0] <= map_tmp[0][0];
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin // add_tmp
    if (!rst_n) begin
        add_tmp <= 20'b0; 
    end 
    else begin
        case (c_state)
            OUT_TRANSPOSED_CONV: begin
                case (cnt_20)
                    15,16,17,18,19: begin add_tmp <= add_out5; end
                    default: add_tmp <= add_tmp;
                endcase
            end
            default: add_tmp <= add_tmp;
        endcase
    end
end


always @(posedge clk or negedge rst_n) begin // out_tmp
    if (!rst_n) begin
        out_tmp <= 20'b0; 
    end 
    else begin
        case (c_state)
            CONVOLUTION: begin
                case (cnt_400)
                    23: begin out_tmp <= cmp3; end
                    default: out_tmp <= out_tmp;
                endcase
            end
            OUT_CONVOLUTION: begin
                case (cnt_20)
                    19: begin out_tmp <= cmp3; end
                    default: out_tmp <= out_tmp;
                endcase
            end
            TRANSPOSED_CONV:begin
                case (cnt_400)
                    4: out_tmp <= add_out5; 
                    default: out_tmp <= out_tmp;
                endcase
            end
            OUT_TRANSPOSED_CONV:begin
                case (cnt_20)
                    19: begin out_tmp <= add_out5; end
                    default: out_tmp <= out_tmp;
                endcase
            end
            default: out_tmp <= out_tmp;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin // img_temp  //move to pixel
    if (!rst_n) begin
        img_temp <= 64'd0;
    end else begin
        case (c_state)
            IDLE: begin
                if (c_state != n_state)
                   img_temp <= {img_temp[55:0],matrix}; 
            end
            INPUT_IMG: begin
                img_temp <= {img_temp[55:0],matrix};
            end 
            CONVOLUTION: begin
                
            end
            default: begin img_temp <= 64'd0; end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin // ker_temp //move to kernel
    if (!rst_n) begin
        ker_temp <= 40'd0;
    end else begin
        case (c_state)
            INPUT_KERNEL: begin
                ker_temp <= {ker_temp[31:0],matrix};
            end 
            default: begin ker_temp <= 40'd0; end
        endcase
    end
end


always @(posedge clk or negedge rst_n) begin // Msize_cs
    if (!rst_n) begin
        Msize_cs <= 2'd3;
    end else begin
        Msize_cs <= Msize_ns;
    end
end

always @(*) begin // Msize_ns
    case (c_state)
        IDLE: begin 
            if (cnt_16384 == 14'd0)
                Msize_ns = matrix_size;
            else
                Msize_ns = Msize_cs;    
         end 
        default: Msize_ns = Msize_cs;
    endcase
end

always @(posedge clk or negedge rst_n) begin // M_num_cs K_num_cs
    if (!rst_n) begin
        M_num_cs <= 2'd0;
        K_num_cs <= 2'd0;
    end else begin
        M_num_cs <= M_num_ns;
        K_num_cs <= K_num_ns;
    end
end

always @(*) begin // M_num_ns  K_num_ns
    case (c_state)
        WAIT_MATRIX: begin
            if (c_state != n_state) begin
                M_num_ns = matrix_idx; 
                K_num_ns = K_num_cs; 
            end 
            else begin
                M_num_ns = M_num_cs; 
                K_num_ns = K_num_cs;
            end  
        end
        CHOOSE_MATRIX: begin 
                if (cnt_400 == 9'd0) begin
                    M_num_ns = M_num_cs;
                    K_num_ns = matrix_idx;
                end 
                else begin
                    M_num_ns = M_num_cs; 
                    K_num_ns = K_num_cs;
                end 

        end 
        default: begin 
            M_num_ns = M_num_cs; 
            K_num_ns = K_num_cs;
        end
    endcase
end

always @(posedge clk or negedge rst_n) begin // Mode_cs 
    if (!rst_n) begin
        Mode_cs <= 1'd0;
    end else begin
        Mode_cs <= Mode_ns;
    end
end

always @(*) begin // Mode_ns  
    case (c_state)
        WAIT_MATRIX: begin
            if (c_state != n_state) begin
                Mode_ns = mode;
            end 
            else 
                Mode_ns = Mode_cs;
        end
        default: begin 
            Mode_ns = Mode_cs;
        end
    endcase
end

always @(posedge clk or negedge rst_n) begin // img_start_addr_cs 
    if (!rst_n) begin
        img_start_addr_cs <= 11'd0;
    end else begin
        if (c_state == CHOOSE_MATRIX)
            img_start_addr_cs <= img_start_addr;
        else 
            img_start_addr_cs <= img_start_addr_cs;    
    end
end  

//---------------------------------------------------------------------
//   Some control
//---------------------------------------------------------------------
always @(*) begin // input_img_time
    case (Msize_cs)
        2'd0: input_img_time = 14'd1023;  // 8*8*16
        2'd1: input_img_time = 14'd4095;  // 16*16*16
        2'd2: input_img_time = 14'd16383; // 32*32*16
        default: input_img_time = 14'd0;
    endcase
end

always @(*) begin // img_start_addr
    case (M_num_cs)
        4'd0: begin
            case (Msize_cs)
                2'd0: img_start_addr = 11'd0;
                2'd1: img_start_addr = 11'd0;
                2'd2: img_start_addr = 11'd0;
                default: img_start_addr = 11'd0;
            endcase
        end 
        4'd1: begin
            case (Msize_cs)
                2'd0: img_start_addr = 11'd8;
                2'd1: img_start_addr = 11'd32;
                2'd2: img_start_addr = 11'd128;
                default: img_start_addr = 11'd0;
            endcase
        end
        4'd2: begin
            case (Msize_cs)
                2'd0: img_start_addr = 11'd16;
                2'd1: img_start_addr = 11'd64;
                2'd2: img_start_addr = 11'd256;
                default: img_start_addr = 11'd0;
            endcase
        end
        4'd3: begin
            case (Msize_cs)
                2'd0: img_start_addr = 11'd24;
                2'd1: img_start_addr = 11'd96;
                2'd2: img_start_addr = 11'd384;
                default: img_start_addr = 11'd0;
            endcase
        end
        4'd4: begin
            case (Msize_cs)
                2'd0: img_start_addr = 11'd32;
                2'd1: img_start_addr = 11'd128;
                2'd2: img_start_addr = 11'd512;
                default: img_start_addr = 11'd0;
            endcase
        end
        4'd5: begin
            case (Msize_cs)
                2'd0: img_start_addr = 11'd40;
                2'd1: img_start_addr = 11'd160;
                2'd2: img_start_addr = 11'd640;
                default: img_start_addr = 11'd0;
            endcase
        end
        4'd6: begin
            case (Msize_cs)
                2'd0: img_start_addr = 11'd48;
                2'd1: img_start_addr = 11'd192;
                2'd2: img_start_addr = 11'd768;
                default: img_start_addr = 11'd0;
            endcase
        end
        4'd7: begin
            case (Msize_cs)
                2'd0: img_start_addr = 11'd56;
                2'd1: img_start_addr = 11'd224;
                2'd2: img_start_addr = 11'd896;
                default: img_start_addr = 11'd0;
            endcase
        end
        4'd8: begin
            case (Msize_cs)
                2'd0: img_start_addr = 11'd64;
                2'd1: img_start_addr = 11'd256;
                2'd2: img_start_addr = 11'd1024;
                default: img_start_addr = 11'd0;
            endcase
        end
        4'd9: begin
            case (Msize_cs)
                2'd0: img_start_addr = 11'd72;
                2'd1: img_start_addr = 11'd288;
                2'd2: img_start_addr = 11'd1152;
                default: img_start_addr = 11'd0;
            endcase
        end
        4'd10: begin
            case (Msize_cs)
                2'd0: img_start_addr = 11'd80;
                2'd1: img_start_addr = 11'd320;
                2'd2: img_start_addr = 11'd1280;
                default: img_start_addr = 11'd0;
            endcase
        end
        4'd11: begin
            case (Msize_cs)
                2'd0: img_start_addr = 11'd88;
                2'd1: img_start_addr = 11'd352;
                2'd2: img_start_addr = 11'd1408;
                default: img_start_addr = 11'd0;
            endcase
        end
        4'd12: begin
            case (Msize_cs)
                2'd0: img_start_addr = 11'd96;
                2'd1: img_start_addr = 11'd384;
                2'd2: img_start_addr = 11'd1536;
                default: img_start_addr = 11'd0;
            endcase
        end
        4'd13: begin
            case (Msize_cs)
                2'd0: img_start_addr = 11'd104;
                2'd1: img_start_addr = 11'd416;
                2'd2: img_start_addr = 11'd1664;
                default: img_start_addr = 11'd0;
            endcase
        end
        4'd14: begin
            case (Msize_cs)
                2'd0: img_start_addr = 11'd112;
                2'd1: img_start_addr = 11'd448;
                2'd2: img_start_addr = 11'd1792;
                default: img_start_addr = 11'd0;
            endcase
        end
        4'd15: begin
            case (Msize_cs)
                2'd0: img_start_addr = 11'd120;
                2'd1: img_start_addr = 11'd480;
                2'd2: img_start_addr = 11'd1920;
                default: img_start_addr = 11'd0;
            endcase
        end
        default: img_start_addr = 11'd0;
    endcase
end

always @(*) begin // kernel_start_addr 
    case (K_num_cs)
        4'd0:  kernel_start_addr = 7'd0;
        4'd1:  kernel_start_addr = 7'd5;
        4'd2:  kernel_start_addr = 7'd10;
        4'd3:  kernel_start_addr = 7'd15;
        4'd4:  kernel_start_addr = 7'd20;
        4'd5:  kernel_start_addr = 7'd25;
        4'd6:  kernel_start_addr = 7'd30;
        4'd7:  kernel_start_addr = 7'd35;
        4'd8:  kernel_start_addr = 7'd40;
        4'd9:  kernel_start_addr = 7'd45;
        4'd10: kernel_start_addr = 7'd50;
        4'd11: kernel_start_addr = 7'd55;
        4'd12: kernel_start_addr = 7'd60;
        4'd13: kernel_start_addr = 7'd65;
        4'd14: kernel_start_addr = 7'd70;
        4'd15: kernel_start_addr = 7'd75;
        default: kernel_start_addr = 7'd0;
    endcase
end

always @(posedge clk or negedge rst_n) begin // next_8_pixel_offset 
    if (!rst_n) begin
        next_8_pixel_offset <= 1'd0;
    end else begin
        if (c_state == INPUT_IMG)
            case (Msize_cs)
                2'd0: next_8_pixel_offset <= 5'd0;
                2'd1: next_8_pixel_offset <= 5'd9;
                2'd2: next_8_pixel_offset <= 5'd19;
                default: next_8_pixel_offset <= next_8_pixel_offset;
            endcase
        else    
            next_8_pixel_offset <= next_8_pixel_offset;    
    end
end

always @(posedge clk or negedge rst_n) begin // next_row_offset 
    if (!rst_n) begin
        next_row_offset <= 1'd0;
    end else begin
        if (c_state == INPUT_IMG)
            case (Msize_cs)
                2'd0: next_row_offset <= 3'd1;
                2'd1: next_row_offset <= 3'd2;
                2'd2: next_row_offset <= 3'd4;
                default: next_row_offset <= next_row_offset;
            endcase
        else    
            next_row_offset <= next_row_offset;    
    end
end

always @(posedge clk or negedge rst_n) begin // next_pool_row_offset 
    if (!rst_n) begin
        next_pool_row_offset <= 1'd0;
    end else begin
        if (c_state == INPUT_IMG)
            case (Msize_cs)
                2'd0: next_pool_row_offset <= 4'd0;
                2'd1: next_pool_row_offset <= 4'd7;
                2'd2: next_pool_row_offset <= 4'd15;
                default: next_pool_row_offset <= next_pool_row_offset;
            endcase
        else    
            next_pool_row_offset <= next_pool_row_offset;    
    end
end

always @(posedge clk or negedge rst_n) begin // shift_next_limit
    if (!rst_n) begin
        shift_next_limit <= 2'd0;
    end else begin
        if (c_state == INPUT_IMG)
            case (Msize_cs)
                2'd0: shift_next_limit <= 2'd0;
                2'd1: shift_next_limit <= 2'd1;
                2'd2: shift_next_limit <= 2'd3;
                default: shift_next_limit <=shift_next_limit;
            endcase
        else    
            shift_next_limit <= shift_next_limit;    
    end
end

always @(posedge clk or negedge rst_n) begin // output_stop_cycle 
    if (!rst_n) begin 
        output_stop_cycle <= 11'd0;
    end else begin
        if (c_state == CHOOSE_MATRIX)
            case ({Msize_cs,Mode_cs})
                {2'd0,1'd0}: output_stop_cycle <= 11'd3;
                {2'd1,1'd0}: output_stop_cycle <= 11'd35;
                {2'd2,1'd0}: output_stop_cycle <= 11'd195;
                {2'd0,1'd1}: output_stop_cycle <= 11'd143;
                {2'd1,1'd1}: output_stop_cycle <= 11'd399;
                {2'd2,1'd1}: output_stop_cycle <= 11'd1295;
                default: output_stop_cycle <= output_stop_cycle;
            endcase
        else    
            output_stop_cycle <= output_stop_cycle;    
    end
end

always @(posedge clk or negedge rst_n) begin // row_end 
    if (!rst_n) begin 
        row_end <= 6'd0;
    end else begin
        if (c_state == CHOOSE_MATRIX)
            case ({Msize_cs,Mode_cs})
                {2'd0,1'd0}: row_end <= 6'd3;
                {2'd1,1'd0}: row_end <= 6'd11;
                {2'd2,1'd0}: row_end <= 6'd27;
                {2'd0,1'd1}: row_end <= 6'd11;
                {2'd1,1'd1}: row_end <= 6'd19;
                {2'd2,1'd1}: row_end <= 6'd35;
                default: row_end <= row_end;
            endcase
        else    
            row_end <= row_end;    
    end
end


always @(posedge clk or negedge rst_n) begin // take_next_bit
    if (!rst_n) begin
        take_next_bit <= 6'd0;
    end else begin
        case (c_state)
            TRANSPOSED_CONV:  take_next_bit <= 6'd8;
            OUT_TRANSPOSED_CONV :begin
                case (cnt_20)
                    19: begin
                        if (shift_num == row_end) begin
                            take_next_bit <= 6'd7;
                        end else begin
                            if (take_next_bit >= 39)
                                take_next_bit <= 6'd0;
                            else
                                take_next_bit <= take_next_bit + 1'b1;
                        end
                    end
                    default: take_next_bit <= take_next_bit;
                endcase
            end
            default: take_next_bit <= 6'd0;
        endcase
    end
end


endmodule  // end CAD 

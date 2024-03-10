module CLK_1_MODULE (
    clk,
    rst_n,
    in_valid,
    seed_in,
    out_idle,
    out_valid,
    seed_out,

    clk1_handshake_flag1,
    clk1_handshake_flag2,
    clk1_handshake_flag3,
    clk1_handshake_flag4
);
// ===============================================================
// In/Out 
// ===============================================================
input clk;
input rst_n;
input in_valid;
input [31:0] seed_in;
input out_idle;
output reg out_valid;
output reg [31:0] seed_out;

// You can change the input / output of the custom flag ports
input clk1_handshake_flag1;
input clk1_handshake_flag2;
output clk1_handshake_flag3;
output clk1_handshake_flag4;

// ===============================================================
// Reg/wire 
// ===============================================================
reg [31:0] seed_tmp;


always @(posedge clk or negedge rst_n) begin //seed_tmp
    if (!rst_n) begin
        seed_tmp <= 32'd0;
    end else begin
        if (in_valid && !out_idle) begin
            seed_tmp <= seed_in;
        end
    end
end

always @(*) begin
    seed_out = seed_tmp;
end

always @(posedge clk or negedge rst_n) begin //out_valid
    if (!rst_n) begin
        out_valid <= 1'b0;
    end else begin
        if (in_valid) begin
            out_valid <= 1'b1;
        end else begin
            out_valid <= 1'b0;
        end
    end
end
endmodule

module CLK_2_MODULE (
    clk,
    rst_n,
    in_valid,
    fifo_full,
    seed,
    out_valid,
    rand_num,
    busy,

    handshake_clk2_flag1,
    handshake_clk2_flag2,
    handshake_clk2_flag3,
    handshake_clk2_flag4,

    clk2_fifo_flag1,
    clk2_fifo_flag2,
    clk2_fifo_flag3,
    clk2_fifo_flag4
);

input clk;
input rst_n;
input in_valid;
input fifo_full;
input [31:0] seed;
output reg out_valid;
output reg [31:0] rand_num;
output reg busy;

// You can change the input / output of the custom flag ports
input handshake_clk2_flag1;
input handshake_clk2_flag2;
output handshake_clk2_flag3;
output handshake_clk2_flag4;

input clk2_fifo_flag1;
input clk2_fifo_flag2;
output clk2_fifo_flag3;
output clk2_fifo_flag4;



reg  [31:0] seed_tmp;
reg  [31:0] rand_1,rand_2,rand_3;
//reg  [1:0]  cnt_3;
reg  [8:0]  cnt_256;
wire [8:0]  cnt_256_conv;
reg  start;
reg  start_2;


//////new
reg in_buff1, in_buff2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        in_buff1 <= 1'b0;
    end else begin
        in_buff1 <= (in_valid) ? 1'b1 :1'b0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        in_buff2 <= 1'b0;
    end else begin
        in_buff2 <= in_buff1;
    end
end
//////new

wire  flag_256 , flag_conv;
wire [31:0] r1,r2,r3;
assign r2 = rand_1 ^ (rand_1 >> 17);
assign r3 = r2 ^ (r2 << 5);
assign flag_256 = (cnt_256_conv == 9'd256) ? 1'b1 : 1'b0 ;

NDFF_BUS_syn  #(9) sync_w2r(.D(cnt_256), .Q(cnt_256_conv), .clk(clk), .rst_n(rst_n));


always @(posedge clk or negedge rst_n) begin // cnt_256
    if (!rst_n) begin
        cnt_256 <= 9'b0;
    end else begin 
        if (flag_256)
            cnt_256 <= 9'd0;
        else if (start && !fifo_full)
        //else if (!fifo_full)
            cnt_256 <= cnt_256 + 1'b1;
    end
end

always @(posedge clk or negedge rst_n) begin // seed_tmp
    if (!rst_n) begin
        seed_tmp <= 32'b0;
    end else begin
        if (in_valid)
            seed_tmp <= seed;
    end
end


always @(posedge clk or negedge rst_n) begin // start 
    if (!rst_n) begin
        start <= 1'b0;
    end else begin
        if (in_valid)
            start <= 1'b1;
        else if (flag_256)
            start <= 1'b0;
    end
end


always @(posedge clk or negedge rst_n) begin // rand_1
    if (!rst_n) begin
        rand_1 <= 32'b0;
    end else begin
        if (in_valid)
            rand_1 <= seed ^ (seed << 13);
        else if (start)
            rand_1 <= (!fifo_full) ? r3 ^ (r3 << 13) : rand_1; 
    end
end



always @(posedge clk or negedge rst_n) begin // rand_3
    if (!rst_n) begin
        rand_3 <= 32'b0;
    end else begin
        rand_3 <= (!fifo_full) ? r2 ^ (r2 << 5) : rand_3;
    end
end

always @(*) begin // out_valid
    if (!rst_n) begin
        out_valid = 1'b0;
    end else begin
        if (start && !fifo_full && !flag_256)
            out_valid = 1'b1;
        else
            out_valid = 1'b0;    
    end
end

always @(*) begin // rand_num
    rand_num = r3;
end

endmodule

module CLK_3_MODULE (
    clk,
    rst_n,
    fifo_empty,
    fifo_rdata,
    fifo_rinc,
    out_valid,
    rand_num,

    fifo_clk3_flag1,
    fifo_clk3_flag2,
    fifo_clk3_flag3,
    fifo_clk3_flag4
);

input clk;
input rst_n;
input fifo_empty;
input [31:0] fifo_rdata;
output reg fifo_rinc;
output reg out_valid;
output reg [31:0] rand_num;

// You can change the input / output of the custom flag ports
input fifo_clk3_flag1;
input fifo_clk3_flag2;
output fifo_clk3_flag3;
output fifo_clk3_flag4;
reg buff_1;
reg empty_buff;
reg [8:0] cnt_out;

// ===============================================================
// Out 
// ===============================================================


always @(*) begin
        fifo_rinc = !fifo_empty;
end

always @(posedge clk or negedge rst_n) begin //buff_1
    if (!rst_n) begin
        buff_1 <= 1'b0;
    end else begin
        buff_1 <= fifo_rinc;
    end
end

// always @(posedge clk or negedge rst_n) begin // cnt_out 
//     if (!rst_n) begin
//         cnt_out <= 9'b0;
//     end else begin
//         if (out_valid)
//             out_valid <= buff_1;
//     end   
// end

always @(posedge clk or negedge rst_n) begin // out_valid 
    if (!rst_n) begin
        out_valid <= 1'b0;
    end else begin
        out_valid <= buff_1;
    end   
end

always @(*) begin // rand_num 
    if (!rst_n) begin
        rand_num = 32'b0;
    end else begin
        if(out_valid)
            rand_num = fifo_rdata;
        else
            rand_num = 32'b0;
    end
end


endmodule
//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2021 Final Project: Customized ISA Processor 
//   Author              : Hsi-Hao Huang
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : CPU.v
//   Module Name : CPU.v
//   Release version : V1.0 (Release Date: 2021-May)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module CPU(

				clk,
			  rst_n,
  
		   IO_stall,

         awid_m_inf,
       awaddr_m_inf,
       awsize_m_inf,
      awburst_m_inf,
        awlen_m_inf,
      awvalid_m_inf,
      awready_m_inf,
                    
        wdata_m_inf,
        wlast_m_inf,
       wvalid_m_inf,
       wready_m_inf,
                    
          bid_m_inf,
        bresp_m_inf,
       bvalid_m_inf,
       bready_m_inf,
                    
         arid_m_inf,
       araddr_m_inf,
        arlen_m_inf,
       arsize_m_inf,
      arburst_m_inf,
      arvalid_m_inf,
                    
      arready_m_inf, 
          rid_m_inf,
        rdata_m_inf,
        rresp_m_inf,
        rlast_m_inf,
       rvalid_m_inf,
       rready_m_inf 

);

//####################################################
//           input & output & parameter
//####################################################

// Input port
input  wire clk, rst_n;
// Output port
output reg  IO_stall;

parameter ID_WIDTH = 4 , ADDR_WIDTH = 32, DATA_WIDTH = 16, DRAM_NUMBER=2, WRIT_NUMBER=1;
parameter IDLE = 3'd0, IF = 3'd1, ID = 3'd2, EXE = 3'd3, WB = 3'd4, DL = 3'd5, DS = 3'd6;
parameter OFFSET = 16'h1000;


// SRAM FSM
parameter S_IDLE       = 3'd0 ;
parameter S_HIT        = 3'd1 ;
parameter S_BUF1       = 3'd2 ;
parameter S_WAITDRAM   = 3'd3 ;
parameter S_WAITDATA   = 3'd4 ;
parameter S_OUT        = 3'd5 ;
parameter S_WRITE      = 3'd6 ;

// Write data FSM
parameter W_IDLE           = 3'd0 ;
parameter WRITE_ADDRESS    = 3'd1 ;
parameter WRITE_DATA       = 3'd2 ;
parameter WRITE_RESPONSE   = 3'd3 ;


// AXI Interface wire connecttion for pseudo DRAM read/write
/* Hint:
  your AXI-4 interface could be designed as convertor in submodule(which used reg for output signal),
  therefore I declared output of AXI as wire in CPU
*/


// axi write address channel 
output  wire [WRIT_NUMBER * ID_WIDTH-1:0]        awid_m_inf; // 4
output  reg  [WRIT_NUMBER * ADDR_WIDTH-1:0]    awaddr_m_inf; // 32
output  wire [WRIT_NUMBER * 3 -1:0]            awsize_m_inf; // 3
output  wire [WRIT_NUMBER * 2 -1:0]           awburst_m_inf; // 2
output  wire [WRIT_NUMBER * 7 -1:0]             awlen_m_inf; // 7
output  reg  [WRIT_NUMBER-1:0]                awvalid_m_inf; // 1
input   wire [WRIT_NUMBER-1:0]                awready_m_inf; // 1
// axi write data channel 
output  reg  [WRIT_NUMBER * DATA_WIDTH-1:0]     wdata_m_inf; // 16
output  reg  [WRIT_NUMBER-1:0]                  wlast_m_inf; // 1
output  reg  [WRIT_NUMBER-1:0]                 wvalid_m_inf; // 1
input   wire [WRIT_NUMBER-1:0]                 wready_m_inf; // 1
// axi write response channel
input   wire [WRIT_NUMBER * ID_WIDTH-1:0]         bid_m_inf; // 4
input   wire [WRIT_NUMBER * 2 -1:0]             bresp_m_inf; // 2
input   wire [WRIT_NUMBER-1:0]             	   bvalid_m_inf; // 1
output  reg  [WRIT_NUMBER-1:0]                 bready_m_inf; // 1
// -----------------------------
// axi read address channel 
output  wire [DRAM_NUMBER * ID_WIDTH-1:0]       arid_m_inf; // 8
output  reg  [DRAM_NUMBER * ADDR_WIDTH-1:0]   araddr_m_inf; // 64
output  wire [DRAM_NUMBER * 7 -1:0]            arlen_m_inf; // 14
output  wire [DRAM_NUMBER * 3 -1:0]           arsize_m_inf; // 6
output  wire [DRAM_NUMBER * 2 -1:0]          arburst_m_inf; // 4
output  reg  [DRAM_NUMBER-1:0]               arvalid_m_inf; // 2
input   wire [DRAM_NUMBER-1:0]               arready_m_inf; // 2
// -----------------------------
// axi read data channel 
input   wire [DRAM_NUMBER * ID_WIDTH-1:0]         rid_m_inf; // 8
input   wire [DRAM_NUMBER * DATA_WIDTH-1:0]     rdata_m_inf; // 32
input   wire [DRAM_NUMBER * 2 -1:0]             rresp_m_inf; // 4
input   wire [DRAM_NUMBER-1:0]                  rlast_m_inf; // 2
input   wire [DRAM_NUMBER-1:0]                 rvalid_m_inf; // 2
output  reg  [DRAM_NUMBER-1:0]                 rready_m_inf; // 2
// -----------------------------

//####################################################
//               reg & wire
//####################################################

/* Register in each core:
  There are sixteen registers in your CPU. You should not change the name of those registers.
  TA will check the value in each register when your core is not busy.
  If you change the name of registers below, you must get the fail in this lab.
*/
reg signed [15:0] core_r0 , core_r1 , core_r2 , core_r3 ;
reg signed [15:0] core_r4 , core_r5 , core_r6 , core_r7 ;
reg signed [15:0] core_r8 , core_r9 , core_r10, core_r11;
reg signed [15:0] core_r12, core_r13, core_r14, core_r15;


reg [2:0] c_state, n_state;
reg get_inst_valid, get_data_valid, store_data_valid;
reg signed [15:0] c_pc, n_pc;
reg signed [15:0] ALUin1, ALUin2;
reg [1:0] ALUop;
reg signed [15:0] rs_data, rt_data, rd_data;
reg [15:0] instruction;
reg signed [15:0] data;
reg [3:0] tag_inst, tag_data; 
reg [1:0] D_c_state, D_n_state;


// for SRAM
reg [6:0] addr_inst, addr_data;
reg [15:0] din_inst, dout_inst, din_data, dout_data;
reg r_or_w_inst, r_or_w_data;
reg [2:0] S_inst_c_state, S_inst_n_state;
reg [2:0] S_data_c_state, S_data_n_state;
reg first_time_cannot_hit_inst, first_time_cannot_hit_data;
reg start_data_valid, start_write_valid;
reg [15:0] dummy_mux1, dummy_mux2, dummy_mux3;


wire [2:0]  opcode;
wire [3:0]  rs, rt, rd;
wire        func;
wire signed [4:0]  immediate;
wire [12:0] jump_address;
wire signed [14:0] c_pc_add2;
wire signed [15:0] ALUoutput;
reg  signed [15:0] data_addr; 
wire signed [15:0] load_store_addr;
wire signed [15:0] rs_imm_add;
wire dummy_ctrl0, dummy_ctrl1;

assign opcode       = instruction[15:13]; 
assign rs           = instruction[12:9 ]; 
assign rt           = instruction[ 8:5 ]; 
assign rd           = instruction[ 4:1 ]; 
assign func         = instruction[  0  ];  
assign immediate    = instruction[ 4:0 ]; 
assign jump_address = instruction[12:0 ]; 
assign c_pc_add2    = c_pc[15:1] + 1'b1;
assign rs_imm_add   = rs_data+immediate;
assign load_store_addr = (rs_imm_add)*2 + OFFSET ;
assign dummy_ctrl0 = (c_state != IDLE) ? 1'b0 : 1'b1 ;
assign dummy_ctrl1 = (c_state != IDLE) ? 1'b1 : 1'b0 ;

// AXI constant
reg [2:0] data_c_state, data_n_state;

assign arid_m_inf = 8'd0;
assign arburst_m_inf = 4'b0101;
assign arsize_m_inf = 6'b001001;
assign arlen_m_inf = 14'b11111111111111;

assign awid_m_inf = 4'd0;
assign awburst_m_inf = 2'd1;
assign awsize_m_inf = 3'b001;
assign awlen_m_inf = 7'd0; 

//####################################################
//                   dummy mux
//####################################################
always @(*) begin
  case (rvalid_m_inf[0])
    1: dummy_mux1 = rdata_m_inf[15:0];
    0: dummy_mux1 = 16'b0;
    default: dummy_mux1 = 16'b0;
  endcase
end

always @(*) begin
  case (dummy_ctrl1)
    1: dummy_mux2 = dummy_mux1;
    0: dummy_mux2 = 16'b0;
    default: dummy_mux2 = 16'b0;
  endcase
end

always @(*) begin
  case (dummy_ctrl0)
    0: dummy_mux3 = dummy_mux2;
    1: dummy_mux3 = 16'b0;
    default: dummy_mux3 = 16'b0;
  endcase
end

//####################################################
//                   FSM
//####################################################
always @(posedge clk or negedge rst_n) begin // current state
  if (!rst_n) c_state <= IDLE;
  else c_state <= n_state;
end

always @(*) begin // next state
  case (c_state)
    IDLE: begin n_state = IF;  end
    IF:   begin n_state = (get_inst_valid) ? ID : c_state; end
    ID:   begin $display("%h",instruction);
      n_state = EXE; end
    EXE:  begin 
            if (opcode == 3'b000 || opcode == 3'b001)
              n_state = WB;
            else if (opcode[1] == 1'b1) 
              begin n_state = (opcode[0]) ? DS : DL ; end
            else 
              n_state = IF;
          end
    WB:   begin 
            n_state = IF;
          end
    DL:   begin n_state = (get_data_valid) ? IF : c_state; end
    DS:   begin n_state = (store_data_valid) ? IF : c_state; end
    default: n_state = c_state;
  endcase
end

//####################################################
//                  Program Counter
//####################################################
always @(posedge clk or negedge rst_n) begin // current pc
  if (!rst_n) c_pc <= OFFSET;
  //else begin if (n_state == IF && c_state != IF && c_state != IDLE && c_state != n_state) c_pc <= n_pc; end
  else begin if (n_state == EXE) c_pc <= n_pc; end
end

always @(*) begin // next pc
  n_pc = {c_pc_add2, 1'b0};
  if ({opcode[2], opcode[0]} == 2'b10 && rs_data == rt_data) begin n_pc = data_addr; end
  else if ({opcode[2], opcode[0]} == 2'b11) begin n_pc = jump_address; end
end

//####################################################
//        rs rt rd data & instruction & data
//####################################################
always @(posedge clk or negedge rst_n) begin // rs_data
  if (!rst_n) begin
      rs_data <= 16'b0;
  end else begin
    if (n_state == ID) begin
      case (rs)
        0 : rs_data <= core_r0 ;
        1 : rs_data <= core_r1 ;
        2 : rs_data <= core_r2 ;
        3 : rs_data <= core_r3 ;
        4 : rs_data <= core_r4 ;
        5 : rs_data <= core_r5 ;
        6 : rs_data <= core_r6 ;
        7 : rs_data <= core_r7 ;
        8 : rs_data <= core_r8 ;
        9 : rs_data <= core_r9 ;
        10: rs_data <= core_r10;
        11: rs_data <= core_r11;
        12: rs_data <= core_r12;
        13: rs_data <= core_r13;
        14: rs_data <= core_r14;
        15: rs_data <= core_r15;
        default: rs_data <= 16'b0;
      endcase
    end  
  end
  
end

always @(posedge clk or negedge rst_n) begin // rt_data
  if (!rst_n) begin
      rt_data <= 16'b0;
  end else begin
    if (n_state == ID) begin
      case (rt)
        0 : rt_data <= core_r0 ;
        1 : rt_data <= core_r1 ;
        2 : rt_data <= core_r2 ;
        3 : rt_data <= core_r3 ;
        4 : rt_data <= core_r4 ;
        5 : rt_data <= core_r5 ;
        6 : rt_data <= core_r6 ;
        7 : rt_data <= core_r7 ;
        8 : rt_data <= core_r8 ;
        9 : rt_data <= core_r9 ;
        10: rt_data <= core_r10;
        11: rt_data <= core_r11;
        12: rt_data <= core_r12;
        13: rt_data <= core_r13;
        14: rt_data <= core_r14;
        15: rt_data <= core_r15;
        default: rt_data <= 16'b0;
      endcase
    end
  end
end

always @(posedge clk or negedge rst_n) begin // rd_data
  if (!rst_n) begin
      rd_data <= 16'b0;
  end else begin
    if (c_state == EXE) begin
      if (opcode == 3'b001 && func == 1'b0) rd_data <= (rs_data < rt_data) ? 1'b1 : 1'b0 ;
      else rd_data <= ALUoutput;
    end
  end
end

always @(posedge clk or negedge rst_n) begin // instruction
  if (!rst_n) begin
      instruction <= 16'b0;
  end else begin
    if (S_inst_c_state == S_BUF1) instruction <= dout_inst;
    else if (rvalid_m_inf[1] && c_pc[7:1] == addr_inst) instruction <= rdata_m_inf[31:16];
  end
end

always @(posedge clk or negedge rst_n) begin // data
  if (!rst_n) begin
      data <= 16'b0;
  end else begin
      /////////TODO
      if (S_data_c_state == S_WAITDATA && rvalid_m_inf[0] && load_store_addr[7:1] == addr_data) data <= rdata_m_inf[15:0];
      else if (S_data_c_state == S_BUF1) data <= dout_data;
  end
end

//####################################################
//                 ALU PIN
//####################################################
ALU calculate(.num1(ALUin1), .num2(ALUin2) , .ALUOP(ALUop) , .ALUout(ALUoutput));

always @(*) begin // ALUin1
  ALUin1 = rs_data;
end

always @(*) begin // ALUin2
  if (opcode[1]) ALUin2 = immediate;
  else           ALUin2 = rt_data;
end

always @(*) begin // ALUop
  case (opcode)
    3'b000: ALUop = (func) ? 2'd1 : 2'd0;
    3'b001: ALUop = (func) ? 2'd2 : 2'd1;
    3'b010: ALUop = 2'd0;
    3'b011: ALUop = 2'd0;
    3'b100: ALUop = 2'd1;
    default: ALUop = 2'd3;
  endcase

end

//####################################################
//                 Core Register
//####################################################
always @(posedge clk or negedge rst_n) begin // core_r0
  if (!rst_n) core_r0 <= 16'd0;
  else begin
    if (c_state == WB && rd == 4'd0) core_r0 <= rd_data;
    else if (get_data_valid && rt == 4'd0) core_r0 <= data;
  end
end

always @(posedge clk or negedge rst_n) begin // core_r1
  if (!rst_n) core_r1 <= 16'd0;
  else begin
    if (c_state == WB && rd == 4'd1) core_r1 <= rd_data;
    else if (get_data_valid && rt == 4'd1) core_r1 <= data;
  end
end

always @(posedge clk or negedge rst_n) begin // core_r2
  if (!rst_n) core_r2 <= 16'd0;
  else begin
    if (c_state == WB && rd == 4'd2) core_r2 <= rd_data;
    else if (get_data_valid && rt == 4'd2) core_r2 <= data;
  end
end

always @(posedge clk or negedge rst_n) begin // core_r3
  if (!rst_n) core_r3 <= 16'd0;
  else begin
    if (c_state == WB && rd == 4'd3) core_r3 <= rd_data;
    else if (get_data_valid && rt == 4'd3) core_r3 <= data;
  end
end

always @(posedge clk or negedge rst_n) begin // core_r4
  if (!rst_n) core_r4 <= 16'd0;
  else begin
    if (c_state == WB && rd == 4'd4) core_r4 <= rd_data;
    else if (get_data_valid && rt == 4'd4) core_r4 <= data;
  end
end

always @(posedge clk or negedge rst_n) begin // core_r5
  if (!rst_n) core_r5 <= 16'd0;
  else begin
    if (c_state == WB && rd == 4'd5) core_r5 <= rd_data;
    else if (get_data_valid && rt == 4'd5) core_r5 <= data;
  end
end

always @(posedge clk or negedge rst_n) begin // core_r6
  if (!rst_n) core_r6 <= 16'd0;
  else begin
    if (c_state == WB && rd == 4'd6) core_r6 <= rd_data;
    else if (get_data_valid && rt == 4'd6) core_r6 <= data;
  end
end

always @(posedge clk or negedge rst_n) begin // core_r7
  if (!rst_n) core_r7 <= 16'd0;
  else begin
    if (c_state == WB && rd == 4'd7) core_r7 <= rd_data;
    else if (get_data_valid && rt == 4'd7) core_r7 <= data;
  end
end

always @(posedge clk or negedge rst_n) begin // core_r8
  if (!rst_n) core_r8 <= 16'd0;
  else begin
    if (c_state == WB && rd == 4'd8) core_r8 <= rd_data;
    else if (get_data_valid && rt == 4'd8) core_r8 <= data;
  end
end

always @(posedge clk or negedge rst_n) begin // core_r9
  if (!rst_n) core_r9 <= 16'd0;
  else begin
    if (c_state == WB && rd == 4'd9) core_r9 <= rd_data;
    else if (get_data_valid && rt == 4'd9) core_r9 <= data;
  end
end

always @(posedge clk or negedge rst_n) begin // core_r10
  if (!rst_n) core_r10 <= 16'd0;
  else begin
    if (c_state == WB && rd == 4'd10) core_r10 <= rd_data;
    else if (get_data_valid && rt == 4'd10) core_r10 <= data;
  end
end

always @(posedge clk or negedge rst_n) begin // core_r11
  if (!rst_n) core_r11 <= 16'd0;
  else begin
    if (c_state == WB && rd == 4'd11) core_r11 <= rd_data;
    else if (get_data_valid && rt == 4'd11) core_r11 <= data;
  end
end

always @(posedge clk or negedge rst_n) begin // core_r12
  if (!rst_n) core_r12 <= 16'd0;
  else begin
    if (c_state == WB && rd == 4'd12) core_r12 <= rd_data;
    else if (get_data_valid && rt == 4'd12) core_r12 <= data;
  end
end

always @(posedge clk or negedge rst_n) begin // core_r13
  if (!rst_n) core_r13 <= 16'd0;
  else begin
    if (c_state == WB && rd == 4'd13) core_r13 <= rd_data;
    else if (get_data_valid && rt == 4'd13) core_r13 <= data;
  end
end

always @(posedge clk or negedge rst_n) begin // core_r14
  if (!rst_n) core_r14 <= 16'd0;
  else begin
    if (c_state == WB && rd == 4'd14) core_r14 <= rd_data;
    else if (get_data_valid && rt == 4'd14) core_r14 <= data;
  end
end

always @(posedge clk or negedge rst_n) begin // core_r15
  if (!rst_n) core_r15 <= 16'd0;
  else begin
    if (c_state == WB && rd == 4'd15) core_r15 <= rd_data;
    else if (get_data_valid && rt == 4'd15) core_r15 <= data;
  end
end

//####################################################
//                 Control signal
//####################################################
always @(posedge clk or negedge rst_n) begin // get_inst_valid
  if (!rst_n) begin
    get_inst_valid <= 1'b0;
  end else begin
    get_inst_valid <= (S_inst_n_state == S_OUT) ? 1'b1 : 1'b0 ;
  end
end


always @(posedge clk or negedge rst_n) begin // get_data_valid
  if (!rst_n) begin
    get_data_valid <= 1'b0;
  end else begin
    get_data_valid <= (S_data_n_state == S_OUT) ? 1'b1 : 1'b0 ;
  end
end



//####################################################
//                 SRAM
//####################################################


always @(posedge clk or negedge rst_n) begin // first_time_cannot_hit_inst
  if (!rst_n) begin
    first_time_cannot_hit_inst <= 1'b0;
  end else begin
    if (S_inst_c_state == S_WAITDRAM) first_time_cannot_hit_inst <= 1'b1;
  end
end

always @(posedge clk or negedge rst_n) begin // S_inst_c_state
    if (!rst_n)     S_inst_c_state <= S_IDLE ;
    else            S_inst_c_state <= S_inst_n_state;
end
always @(*) begin // S_inst_n_state
    S_inst_n_state = S_inst_c_state ;   
    case(S_inst_c_state)
        S_IDLE: begin
            if (n_state == IF && c_state != n_state) begin
                if (first_time_cannot_hit_inst  && tag_inst == c_pc[11:8])
                    S_inst_n_state = S_HIT ;
                else
                    S_inst_n_state = S_WAITDRAM ;
            end 
        end
        S_HIT:  S_inst_n_state = S_BUF1 ;
        S_BUF1:  S_inst_n_state = S_OUT ;
        S_WAITDRAM: if (arready_m_inf[1])   S_inst_n_state = S_WAITDATA ;
        S_WAITDATA: if (rlast_m_inf[1])     S_inst_n_state = S_OUT ;
        S_OUT:  S_inst_n_state = S_IDLE ;
    endcase
end


SRAM_128X16 SRAM_inst(.A0  (addr_inst[0]),.A1  (addr_inst[1]),.A2  (addr_inst[2]),.A3  (addr_inst[3]),.A4  (addr_inst[4]),.A5  (addr_inst[5]),.A6  (addr_inst[6]),
                      .DO0 (dout_inst[0]),.DO1 (dout_inst[1]),.DO2 (dout_inst[2]),.DO3 (dout_inst[3]),.DO4 (dout_inst[4]),.DO5 (dout_inst[5]),.DO6 (dout_inst[6]),.DO7 (dout_inst[7]),
                      .DO8 (dout_inst[8]),.DO9 (dout_inst[9]),.DO10(dout_inst[10]),.DO11(dout_inst[11]),.DO12(dout_inst[12]),.DO13(dout_inst[13]),.DO14(dout_inst[14]),.DO15(dout_inst[15]),
                      .DI0 (din_inst[0] ),.DI1 (din_inst[1] ),.DI2 (din_inst[2] ),.DI3 (din_inst[3] ),.DI4 (din_inst[4] ),.DI5 (din_inst[5] ),.DI6 (din_inst[6] ),.DI7 (din_inst[7] ),
                      .DI8 (din_inst[8] ),.DI9 (din_inst[9] ),.DI10(din_inst[10] ),.DI11(din_inst[11] ),.DI12(din_inst[12] ),.DI13(din_inst[13] ),.DI14(din_inst[14] ),.DI15(din_inst[15] ),
                      .CK  (clk),.WEB (r_or_w_inst),.OE  (1'b1),.CS  (1'b1));


always @(*) begin// r_or_w_inst
    case (S_inst_c_state)
      S_WAITDATA: r_or_w_inst = (rvalid_m_inf[1]) ? 1'b0 : 1'b1; 
      default: r_or_w_inst = 1'b1;
    endcase
end

always @(posedge clk or negedge rst_n) begin// addr_inst
    if (!rst_n) begin
      addr_inst <= 7'd0;
    end else begin
      if (rvalid_m_inf[1]) addr_inst <= addr_inst + 1'b1;
      else if (S_inst_n_state == S_HIT) addr_inst <= c_pc[7:1];
      else addr_inst <= 7'd0;
    end
end

always @(*) begin // din_inst
    din_inst = (rvalid_m_inf[1]) ? rdata_m_inf[31:16] : 16'b0;
end

always @(posedge clk or negedge rst_n) begin// tag_inst
    if (!rst_n) begin
      tag_inst <= 4'd1;
    end else begin
      if (S_inst_c_state == S_WAITDRAM) tag_inst <= c_pc[11:8];
    end
end

always @(posedge clk or negedge rst_n) begin// tag_data
    if (!rst_n) begin
      tag_data <= 4'd1;
    end else begin
      if (S_data_c_state == S_WAITDRAM) tag_data <= load_store_addr[11:8];
    end
end

always @(posedge clk or negedge rst_n) begin // start_data_valid
  if (!rst_n) begin
    start_data_valid <= 1'b0;
  end else begin
    if ((n_state == DL || n_state == DS) && c_state == EXE) start_data_valid <= 1'b1;
    else                                                    start_data_valid <= 1'b0;
  end
end


always @(posedge clk or negedge rst_n) begin // first_time_cannot_hit_data
  if (!rst_n) begin
    first_time_cannot_hit_data <= 1'b0;
  end else begin
    if (S_data_c_state == S_WAITDRAM) first_time_cannot_hit_data <= 1'b1;
  end
end

always @(posedge clk or negedge rst_n) begin //S_data_c_state
    if (!rst_n)     S_data_c_state <= S_IDLE ;
    else            S_data_c_state <= S_data_n_state ;
end


always @(*) begin //S_data_n_state
    case(S_data_c_state)
        S_IDLE: begin
            if (start_data_valid) begin
                if (c_state == DS && tag_data==load_store_addr[11:8]) // store and hit(change SRAM and DRAM)
                    S_data_n_state = S_WRITE ;
                else if (first_time_cannot_hit_data && tag_data==load_store_addr[11:8])  
                    S_data_n_state = S_HIT ;
                else if (c_state != DS)
                    S_data_n_state = S_WAITDRAM ;
                else 
                    S_data_n_state = S_data_c_state ;  
            end 
            else S_data_n_state = S_data_c_state ;
        end
        S_HIT:                              S_data_n_state = S_BUF1 ;
        S_BUF1:                             S_data_n_state = S_OUT ;
        S_WAITDRAM: if (arready_m_inf==1)   S_data_n_state = S_WAITDATA ; else S_data_n_state = S_data_c_state ;
        S_WAITDATA: if (rlast_m_inf==1)     S_data_n_state = S_OUT ; else S_data_n_state = S_data_c_state ;
        S_OUT:                              S_data_n_state = S_IDLE ;
        S_WRITE:                            S_data_n_state = S_IDLE ;
        default:                            S_data_n_state = S_data_c_state ;
    endcase
end

SRAM_128X16 SRAM_data(.A0  (addr_data[0]),.A1  (addr_data[1]),.A2  (addr_data[2]),.A3  (addr_data[3]),.A4  (addr_data[4]),.A5  (addr_data[5]),.A6  (addr_data[6]),
                      .DO0 (dout_data[0]),.DO1 (dout_data[1]),.DO2 (dout_data[2]),.DO3 (dout_data[3]),.DO4 (dout_data[4]),.DO5 (dout_data[5]),.DO6 (dout_data[6]),.DO7 (dout_data[7]),
                      .DO8 (dout_data[8]),.DO9 (dout_data[9]),.DO10(dout_data[10]),.DO11(dout_data[11]),.DO12(dout_data[12]),.DO13(dout_data[13]),.DO14(dout_data[14]),.DO15(dout_data[15]),
                      .DI0 (din_data[0] ),.DI1 (din_data[1] ),.DI2 (din_data[2] ),.DI3 (din_data[3] ),.DI4 (din_data[4] ),.DI5 (din_data[5] ),.DI6 (din_data[6] ),.DI7 (din_data[7] ),
                      .DI8 (din_data[8] ),.DI9 (din_data[9] ),.DI10(din_data[10] ),.DI11(din_data[11] ),.DI12(din_data[12] ),.DI13(din_data[13] ),.DI14(din_data[14] ),.DI15(din_data[15] ),
                      .CK  (clk),.WEB (r_or_w_data),.OE  (1'b1),.CS  (1'b1));

always @(*) begin// r_or_w_data
    case (S_data_c_state)
      S_WAITDATA: r_or_w_data = (rvalid_m_inf[0]) ? 1'b0 : 1'b1; 
      S_WRITE: r_or_w_data = 1'b0; 
      default: r_or_w_data = 1'b1;
    endcase
end

always @(posedge clk or negedge rst_n) begin// addr_data
    if (!rst_n) begin
      addr_data <= 7'd0;
    end else begin
      case (S_data_n_state)
        S_WAITDATA:  if (rvalid_m_inf[0]) addr_data <= addr_data + 1'b1;
        S_HIT, S_WRITE:  addr_data <= load_store_addr[7:1];
        default: addr_data <= 7'd0;
      endcase
    end
end

always @(*) begin // din_data
    //din_data = (S_data_c_state == S_WRITE) ? rt_data : rdata_m_inf[15:0];
    din_data = (S_data_c_state == S_WRITE) ? rt_data :dummy_mux3;
end




//####################################################
//                 AXI
//####################################################

////////  DRAM_inst 

always @(*) begin // inst_read_address 
  araddr_m_inf[63:32] = {16'b0,4'b0001,c_pc[11:8] ,8'b0};
end



always @(*) begin // inst_read_address_valid
	case (S_inst_c_state)
		S_WAITDRAM: arvalid_m_inf[1] = 1'b1;
		default: arvalid_m_inf[1] = 1'b0;
	endcase
end

always @(*) begin // inst_read_data_ready
	case (S_inst_c_state)
		S_WAITDATA: rready_m_inf[1] = 1'b1;
		default: rready_m_inf[1] = 1'b0;
	endcase
end


////////  DRAM_data


//////////////////////////////////
// always @(posedge clk or negedge rst_n) begin // data_addr
//   if (!rst_n) begin
//     data_addr <= 16'd0;
//   end else begin
//     if (c_state == EXE) data_addr <= {(c_pc_add2 + immediate), 1'b0};
//   end
// end

always @(*) begin
  data_addr = {(c_pc_add2 + immediate), 1'b0};
end


always @(*) begin // data_read_address
  araddr_m_inf[31:0] = {16'b0,4'b0001,load_store_addr[11:8],8'd0};
end

always @(*) begin // data_read_address_valid
	case (S_data_c_state)
		S_WAITDRAM: arvalid_m_inf[0] = 1'b1;
		default: arvalid_m_inf[0] = 1'b0;
	endcase
end

always @(*) begin // data_read_data_ready
	case (S_data_c_state)
		S_WAITDATA: rready_m_inf[0] = 1'b1;
		default: rready_m_inf[0] = 1'b0;
	endcase
end

////  write dram
always @(posedge clk or negedge rst_n) begin // start_write_valid
  if (!rst_n) begin
    start_write_valid <= 1'b0;
  end else begin
    if (n_state == DS && c_state == EXE) start_write_valid <= 1'b1;
    else                                 start_write_valid <= 1'b0;
  end
end

always @(posedge clk or negedge rst_n) begin //D_c_state
  if (!rst_n) begin
    D_c_state <= W_IDLE;
  end else begin
    D_c_state <= D_n_state;
  end
end

always @(*) begin //D_n_state
  case (D_c_state)
    W_IDLE:         D_n_state = (start_write_valid) ? WRITE_ADDRESS : D_c_state;
    WRITE_ADDRESS:  D_n_state = (awready_m_inf) ? WRITE_DATA : D_c_state;
    WRITE_DATA:     D_n_state = (wready_m_inf && wlast_m_inf) ? WRITE_RESPONSE : D_c_state;
    WRITE_RESPONSE: D_n_state = (bvalid_m_inf) ? W_IDLE : D_c_state;
    default: D_n_state = D_c_state;
  endcase
end

always @(*) begin // data_write_address
    awaddr_m_inf = {16'd0, 4'b0001,load_store_addr[11:1],1'b0};
end

always @(*) begin // write address valid
	case (D_c_state)
		WRITE_ADDRESS: awvalid_m_inf = 1'b1;
		default: awvalid_m_inf = 1'b0;
	endcase
end

always @(*) begin // write data valid
	case (D_c_state)
		WRITE_DATA: begin wvalid_m_inf = 1'b1;end
		default: wvalid_m_inf = 1'b0;
	endcase
end

always @(posedge clk or negedge rst_n) begin // write data 
    if (!rst_n) begin   
      wdata_m_inf <= 16'b0 ;
    end
    else begin
        if (start_write_valid)    wdata_m_inf <= rt_data ;
    end
end

always @(posedge clk or negedge rst_n) begin // write last 
    if (!rst_n) begin 
      wlast_m_inf <= 1'b0 ;
    end
    else begin
        if (D_n_state==WRITE_DATA)     wlast_m_inf <= 1'b1 ;
        else                           wlast_m_inf <= 1'b0 ;
    end
end

always @(*) begin // bready 
	case (D_c_state)
		WRITE_DATA,WRITE_RESPONSE: bready_m_inf = 1'b1;
		default: bready_m_inf = 1'b0;
	endcase
end

always @(posedge clk or negedge rst_n) begin //store_data_valid
    if (!rst_n) begin
      store_data_valid <= 1'b0;
    end else begin
      if (D_n_state == W_IDLE && D_c_state == WRITE_RESPONSE) store_data_valid <= 1'b1;
      else store_data_valid <= 1'b0;
    end
end

//####################################################
//                 Output
//####################################################
always @(posedge clk or negedge rst_n) begin // IO_stall
  if (!rst_n) IO_stall <= 1'b1;
  else begin
    if (c_state != IDLE && n_state == IF && c_state != IF) IO_stall <= 1'b0;
    else                                                   IO_stall <= 1'b1;
  end
end

endmodule




//####################################################
//               Submodule
//####################################################

module ALU (num1,num2,ALUOP,ALUout);
  
  input signed [15:0] num1;
  input signed [15:0] num2;
  input [1:0] ALUOP;
  output reg signed [15:0] ALUout;


  always @(*) begin
    case (ALUOP)
      0: ALUout = num1 + num2;
      1: ALUout = num1 - num2;
      2: ALUout = num1 * num2;
      default: ALUout = 16'd0;
    endcase
  end

endmodule


















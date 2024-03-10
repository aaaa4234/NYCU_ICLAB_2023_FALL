//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   2023 ICLAB Fall Course
//   Lab03      : BRIDGE
//   Author     : Ting-Yu Chang
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : BRIDGE_encrypted.v
//   Module Name : BRIDGE
//   Release version : v1.0 (Release Date: Sep-2023)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module BRIDGE(
         // Input Signals
         clk,
         rst_n,
         in_valid,
         direction,
         addr_dram,
         addr_sd,
         // Output Signals
         out_valid,
         out_data,
         // DRAM Signals
         AR_VALID, AR_ADDR, R_READY, AW_VALID, AW_ADDR, W_VALID, W_DATA, B_READY,
         AR_READY, R_VALID, R_RESP, R_DATA, AW_READY, W_READY, B_VALID, B_RESP,
         // SD Signals
         MISO,
         MOSI
       );

// Input Signals
input clk, rst_n;
input in_valid;
input direction;
input [12:0] addr_dram;
input [15:0] addr_sd;

// Output Signals
output reg out_valid;
output reg [7:0] out_data;

// DRAM Signals
// write address channel
output reg [31:0] AW_ADDR;
output reg AW_VALID;
input AW_READY;
// write data channel
output reg W_VALID;
output reg [63:0] W_DATA;
input W_READY;
// write response channel
input B_VALID;
input [1:0] B_RESP;
output reg B_READY;
// read address channel
output reg [31:0] AR_ADDR;
output reg AR_VALID;
input AR_READY;
// read data channel
input [63:0] R_DATA;
input R_VALID;
input [1:0] R_RESP;
output reg R_READY;

// SD Signals
input MISO;
output reg MOSI;

//==============================================//
//       parameter & integer declaration        //
//==============================================//
parameter STATE_BIT = 4;
parameter IDLE = 4'd0;
parameter D_READ = 4'd1;
//parameter S_READ = 4'd2;
parameter READY_D = 4'd2;
parameter COMMAND = 4'd3;
parameter WAIT_RESPONSE = 4'd4;
parameter AFTER_RESPONSE = 4'd5;
parameter S_WRITE_DATA = 4'd6;
parameter DATA_RESPONSE = 4'd7;
parameter OUTPUT = 4'd8;
parameter S_READ_DATA = 4'd9;
parameter D_WRITE = 4'd10;
parameter W_DATA_READY = 4'd11;
parameter B_RESPONSE = 4'd12;
parameter LONGER_BUSY = 4'd13;


//==============================================//
//           reg & wire declaration             //
//==============================================//
reg [STATE_BIT-1:0] c_state,n_state;
reg direct;
reg [12:0] add_ram;
reg [15:0] add_sd;
reg [63:0] data_dram,data_sdread;
reg [6:0] cnt_DRAM_read,cnt_command,cnt_swrite;
reg [6:0] cnt_busy,cnt_out,cnt_sread,cnt_DRAM_w;
reg [8:0] cnt_response;
reg [6:0] crc7;
reg [15:0] crc16;


wire [5:0] instruction;
assign instruction = (direct) ? 6'd17: 6'd24;
wire [47:0] comm;
assign comm = {2'b01,instruction,16'b0,add_sd,crc7,1'b1};
wire [87:0] data_SD;
assign data_SD = {8'hfe,data_dram,crc16};
//==============================================//
//                    FSM                       //
//==============================================//
always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
      begin
        c_state <= IDLE;
      end
    else
      begin
        c_state <= n_state;
      end
  end

always @(*)
  begin
    if (!rst_n)
      begin
        n_state = IDLE;
      end
    else
      begin
        case (c_state)
          IDLE:
            begin
              if (in_valid)
                begin
                  if (!direction)
                    begin
                      n_state = D_READ;
                    end
                  else
                    begin
                      n_state = COMMAND;
                    end
                end
              else
                begin
                  n_state = c_state;
                end
            end
          D_READ:
            begin
              if (AR_READY && AR_VALID)
                n_state = READY_D;
              else
                n_state = c_state;
            end
          READY_D:
            begin
              if (R_VALID && R_READY)
                n_state = COMMAND;
              else
                n_state = c_state;
            end
          COMMAND:
            begin
              if (cnt_command == 7'd47)
                n_state = WAIT_RESPONSE;
              else
                n_state = c_state;
            end
          WAIT_RESPONSE:
            begin
              if (!MISO)
                n_state = AFTER_RESPONSE;
              else
                n_state = c_state;
            end
          AFTER_RESPONSE:
            begin
              if (cnt_response == 14 && instruction == 6'd24)
                n_state = S_WRITE_DATA;
              else if (cnt_response > 14 && !MISO && instruction == 6'd17)
                n_state = S_READ_DATA;
              else
                n_state = c_state;
              /*if (cnt_response == 14 && instruction == 6'd24)
                n_state = S_WRITE_DATA;
              else if (cnt_response == 14 && instruction == 6'd17)
                n_state = S_READ_DATA;
              else
                n_state = c_state;*/
            end
          S_WRITE_DATA:
            begin
              if (cnt_swrite == 7'd87)
                n_state = DATA_RESPONSE;
              else
                n_state = c_state;
            end
          DATA_RESPONSE:
            begin
              if (cnt_busy == 4'd7)
                n_state = LONGER_BUSY;
              else
                n_state = c_state;
            end
          OUTPUT:
            begin
              if (cnt_out == 4'd8)
                n_state = IDLE;
              else
                n_state = c_state;
            end
          S_READ_DATA:
            begin
              if (cnt_sread == 7'd79)
                n_state = D_WRITE;
              else
                n_state = c_state;
            end
          D_WRITE:
            begin
              if (AW_READY && AW_VALID)
                n_state = W_DATA_READY;
              else
                n_state = c_state;
            end
          W_DATA_READY:
            begin
              if (W_READY && W_VALID)
                n_state = B_RESPONSE;
              else
                n_state = c_state;
            end
          B_RESPONSE:
            begin
              if (B_VALID && B_READY)
                begin
                  n_state = OUTPUT;
                end
              else
                begin
                  n_state = c_state;
                end
            end
          LONGER_BUSY:
            begin
              if (MISO == 1)
                n_state = OUTPUT;
              else
                n_state = c_state;
            end
          default:
            n_state = IDLE;


        endcase
      end
  end


//==============================================//
//                    out                       //
//==============================================//
always @(*)
  begin // out_valid
    if (!rst_n)
      begin
        out_valid = 1'b0;
      end
    else
      begin
        if (c_state == OUTPUT && cnt_out >= 1'b1)
          out_valid = 1'b1;
        else
          out_valid = 1'b0;
      end
  end // end out_valid

always @(*)
  begin // out_data
    if (!rst_n)
      begin
        out_data = 8'b0;
      end
    else
      begin
        if (c_state == OUTPUT && cnt_out >= 1'b1)
          begin
            if (instruction == 6'd24)
              begin
                case (cnt_out)
                  7'd1:
                    out_data = data_dram[63:56];
                  7'd2:
                    out_data = data_dram[55:48];
                  7'd3:
                    out_data = data_dram[47:40];
                  7'd4:
                    out_data = data_dram[39:32];
                  7'd5:
                    out_data = data_dram[31:24];
                  7'd6:
                    out_data = data_dram[23:16];
                  7'd7:
                    out_data = data_dram[15:8];
                  7'd8:
                    out_data = data_dram[7:0];
                  default:
                    out_data = 8'b0;
                endcase
              end
            else
              begin
                case (cnt_out)
                  7'd1:
                    out_data = data_sdread[63:56];
                  7'd2:
                    out_data = data_sdread[55:48];
                  7'd3:
                    out_data = data_sdread[47:40];
                  7'd4:
                    out_data = data_sdread[39:32];
                  7'd5:
                    out_data = data_sdread[31:24];
                  7'd6:
                    out_data = data_sdread[23:16];
                  7'd7:
                    out_data = data_sdread[15:8];
                  7'd8:
                    out_data = data_sdread[7:0];
                  default:
                    out_data = 8'b0;
                endcase
              end
          end
        else
          out_data = 8'b0;
      end
  end // end out_data


//==============================================//
//                 Write DRAM                   //
//==============================================//
always @(*) // AW_ADDR
  begin
    if (!rst_n)
      begin
        AW_ADDR = 32'b0;
      end
    else
      begin
        if (c_state == D_WRITE)
          AW_ADDR = add_ram;
        else
          AW_ADDR = 32'b0;
      end
  end // end AW_ADDR

always @(*) // AW_VALID
  begin
    if (!rst_n)
      begin
        AW_VALID = 1'b0;
      end
    else
      begin
        if (c_state == D_WRITE)
          AW_VALID = 1'b1;
        else
          AW_VALID = 1'b0;
      end
  end // end AW_VALID

always @(*) // W_DATA
  begin
    if (!rst_n)
      begin
        W_DATA = 64'b0;
      end
    else
      begin
        if (c_state == W_DATA_READY && cnt_DRAM_w > 1'b0)
          W_DATA = data_sdread;
        else
          W_DATA = 64'b0;
      end
  end // end W_DATA

always @(*) // W_VALID
  begin
    if (!rst_n)
      begin
        W_VALID = 1'b0;
      end
    else
      begin
        if (c_state == W_DATA_READY && cnt_DRAM_w > 1'b0)
          W_VALID = 1'b1;
        else
          W_VALID = 1'b0;
      end
  end // end W_VALID

always @(*) // B_READY
  begin
    if (!rst_n)
      begin
        B_READY = 1'b0;
      end
    else
      begin
        if (c_state == B_RESPONSE)
          begin
            B_READY = 1'b1;
          end
        else
          begin
            B_READY = 1'b0;
          end
      end
  end // end B_READY

//==============================================//
//                 Read DRAM                    //
//==============================================//
always @(*) // AR_ADDR
  begin
    if (!rst_n)
      begin
        AR_ADDR = 32'b0;
      end
    else
      begin
        case (c_state)
          D_READ:
            begin
              AR_ADDR = add_ram;
            end
          default:
            AR_ADDR = 32'b0;
        endcase
      end
  end // end AR_ADDR

always @(*) // AR_VALID
  begin
    if (!rst_n)
      begin
        AR_VALID = 1'b0;
      end
    else
      begin
        case (c_state)
          D_READ:
            begin
              AR_VALID = 1'b1;
            end
          default:
            AR_VALID = 1'b0;
        endcase
      end
  end // end AR_VALID

always @(*) // R_READY
  begin
    if (!rst_n)
      begin
        R_READY = 1'b0;
      end
    else
      begin
        case (c_state)
          READY_D:
            begin
              if (cnt_DRAM_read > 1'b0)
                R_READY = 1'b1;
              else
                R_READY = 1'b0;
            end
          default:
            R_READY = 1'b0;
        endcase
      end
  end // end R_READY

//==============================================//
//                  SD CARD                     //
//==============================================//
always @(*)
  begin
    if (!rst_n)
      begin
        MOSI = 1'b1;
      end
    else
      begin
        case (c_state)
          COMMAND:
            begin
              //$display("cnt_command is %d, COMmand is %b, comm is %b",47-cnt_command,comm[47-cnt_command],comm);
              MOSI = comm[47-cnt_command];
            end
          S_WRITE_DATA:
            begin
              MOSI = data_SD[87-cnt_swrite];
            end
          default:
            MOSI = 1'b1;
        endcase
      end
  end // end MOSI

//==============================================//
//                  OTHERS                      //
//==============================================//
always @(posedge clk or negedge rst_n) //direct
  begin
    if (!rst_n)
      begin
        direct <= 1'b0;
      end
    else
      begin
        if (c_state == IDLE)
          begin
            if (direction)
              begin
                direct <= 1'b1;
              end
            else
              begin
                direct <= 1'b0;
              end
          end
        else
          begin
            direct <= direct;
          end
      end
  end // end direct

always @(posedge clk or negedge rst_n) //add_ram
  begin
    if (!rst_n)
      begin
        add_ram <= 13'b0;
      end
    else
      begin
        if (c_state == IDLE)
          begin
            if (in_valid)
              add_ram <= addr_dram;
          end
        else
          begin
            add_ram <= add_ram;
          end
      end
  end // end add_ram

always @(posedge clk or negedge rst_n) //add_sd
  begin
    if (!rst_n)
      begin
        add_sd <= 16'b0;
      end
    else
      begin
        if (c_state == IDLE)
          begin
            if (in_valid)
              add_sd <= addr_sd;
          end
        else
          begin
            add_sd <= add_sd;
          end
      end
  end // end add_sd

always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
      begin
        data_dram <= 64'b0;
      end
    else
      begin
        if (c_state == READY_D && R_VALID == 1)
          data_dram <= R_DATA;
        else
          data_dram <= data_dram;
      end
  end

always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
      begin
        data_sdread <= 64'b0;
      end
    else
      begin
        if (c_state == S_READ_DATA && cnt_sread<=7'd63)
          data_sdread <= {data_sdread[62:0],MISO};
        else
          data_sdread <= data_sdread;
      end
  end

always @(*)
  begin
    if (!rst_n)
      begin
        crc7 = 7'b0;
      end
    else
      begin
        if (c_state == COMMAND)
          crc7 = CRC7(comm[47:8]);
        else
          crc7 = 7'b0;
      end
  end

always @(*)
  begin
    if (!rst_n)
      begin
        crc16 = 7'b0;
      end
    else
      begin
        if (c_state == S_WRITE_DATA)
          crc16 = CRC16_CCITT(data_dram);
        else
          crc16 = 7'b0;
      end
  end

//==============================================//
//                   counts                     //
//==============================================//
always @(posedge clk or negedge rst_n) //cnt_DRAM_read
  begin
    if (!rst_n)
      begin
        cnt_DRAM_read <= 7'b0;
      end
    else
      begin
        if (c_state == READY_D)
          begin
            cnt_DRAM_read <= cnt_DRAM_read + 1'b1;
          end
        else
          begin
            cnt_DRAM_read <= 7'b0;
          end
      end
  end // end cnt_DRAM_read

always @(posedge clk or negedge rst_n) //cnt_command
  begin
    if (!rst_n)
      begin
        cnt_command <= 7'b0;
      end
    else
      begin
        if (c_state == COMMAND)
          begin
            cnt_command <= cnt_command + 1'b1;
          end
        else
          begin
            cnt_command <= 7'b0;
          end
      end
  end // end cnt_command

always @(posedge clk or negedge rst_n) //cnt_response
  begin
    if (!rst_n)
      begin
        cnt_response <= 7'b0;
      end
    else
      begin
        if (c_state == AFTER_RESPONSE)
          begin
            cnt_response <= cnt_response + 1'b1;
          end
        else
          begin
            cnt_response <= 7'b0;
          end
      end
  end // end cnt_response

always @(posedge clk or negedge rst_n) //cnt_swrite
  begin
    if (!rst_n)
      begin
        cnt_swrite <= 7'b0;
      end
    else
      begin
        if (c_state == S_WRITE_DATA)
          begin
            cnt_swrite <= cnt_swrite + 1'b1;
          end
        else
          begin
            cnt_swrite <= 7'b0;
          end
      end
  end // end cnt_swrite

always @(posedge clk or negedge rst_n) //cnt_busy
  begin
    if (!rst_n)
      begin
        cnt_busy <= 7'b0;
      end
    else
      begin
        if (c_state == DATA_RESPONSE)
          begin
            cnt_busy <= cnt_busy + 1'b1;
          end
        else
          begin
            cnt_busy <= 7'b0;
          end
      end
  end // end cnt_busy

always @(posedge clk or negedge rst_n) //cnt_out
  begin
    if (!rst_n)
      begin
        cnt_out <= 7'b0;
      end
    else
      begin
        if (c_state == OUTPUT)
          begin
            cnt_out <= cnt_out + 1'b1;
          end
        else
          begin
            cnt_out <= 7'b0;
          end
      end
  end // end cnt_out

always @(posedge clk or negedge rst_n) //cnt_sread
  begin
    if (!rst_n)
      begin
        cnt_sread <= 7'b0;
      end
    else
      begin
        if (c_state == S_READ_DATA)
          begin
            cnt_sread <= cnt_sread + 1'b1;
          end
        else
          begin
            cnt_sread <= 7'b0;
          end
      end
  end // end cnt_sread

always @(posedge clk or negedge rst_n) //cnt_DRAM_w
  begin
    if (!rst_n)
      begin
        cnt_DRAM_w <= 7'b0;
      end
    else
      begin
        if (c_state == W_DATA_READY)
          begin
            cnt_DRAM_w <= cnt_DRAM_w + 1'b1;
          end
        else
          begin
            cnt_DRAM_w <= 7'b0;
          end
      end
  end // end cnt_DRAM_w
//==============================================//
//                 CRC function                 //
//==============================================//
function automatic [6:0] CRC7;  // Return 7-bit result
  input [39:0] data;  // 40-bit data input
  reg [6:0] crc;
  integer i;
  reg data_in, data_out;
  parameter polynomial = 7'h9;  // x^7 + x^3 + 1

  begin
    crc = 7'd0;
    for (i = 0; i < 40; i = i + 1)
      begin
        data_in = data[39-i];
        data_out = crc[6];
        crc = crc << 1;  // Shift the CRC
        if (data_in ^ data_out)
          begin
            crc = crc ^ polynomial;
          end
      end
    CRC7 = crc;
  end
endfunction

function automatic [15:0] CRC16_CCITT;
  // Try to implement CRC-16-CCITT function by yourself.
  input [63:0] data;  // 64-bit data input
  reg [15:0] crc;
  integer i;
  reg data_in, data_out;
  parameter polynomial = 16'b0001_0000_0010_0001;  // x^16 + x^12 + x^5 + 1

  begin
    crc = 16'd0;
    for (i = 0; i < 64; i = i + 1)
      begin
        data_in = data[63-i];
        data_out = crc[15];
        crc = crc << 1;  // Shift the CRC
        if (data_in ^ data_out)
          begin
            crc = crc ^ polynomial;
          end
      end
    CRC16_CCITT = crc;
  end
endfunction
endmodule


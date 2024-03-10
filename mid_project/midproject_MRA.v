//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Si2 LAB @NYCU ED430
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2023 Fall
//   Midterm Proejct            : MRA  
//   Author                     : Lin-Hung, Lai
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : MRA.v
//   Module Name : MRA
//   Release version : V2.0 (Release Date: 2023-10)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module MRA(
	// CHIP IO
	clk            	,	
	rst_n          	,	
	in_valid       	,	
	frame_id        ,	
	net_id         	,	  
	loc_x          	,	  
    loc_y         	,
	cost	 		,		
	busy         	,

    // AXI4 IO
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
	   rready_m_inf,
	
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
	   bready_m_inf 
);

// ===============================================================
//  					Parameter && Integer
// ===============================================================

// AXI parameter
parameter ID_WIDTH=4, DATA_WIDTH=128, ADDR_WIDTH=32;  

// FSM
parameter IDLE = 3'd0;
parameter INPUT = 3'd1;
parameter WAIT_READ_DATA_PATH = 3'd2;
parameter FILL_MAP = 3'd3;
parameter WAIT_WEIGHT = 3'd4;
parameter RETRACE = 3'd5;
parameter WRITE_DRAM = 3'd6;

// AXI FSM
parameter START = 4'd0;
parameter READ_ADDRESS_PATH = 4'd1;
parameter READ_DATA_PATH = 4'd2;
parameter READ_ADDRESS_WEIGHT = 4'd3;
parameter READ_DATA_WEIGHT = 4'd4;
parameter WAIT_WRITE_DATA = 4'd5;
parameter WRITE_ADDRESS = 4'd6;
parameter WRITE_DATA = 4'd7;
parameter WRITE_RESPONSE = 4'd8;

//Integer
integer i,j;

// ===============================================================
//  					Input / Output 
// ===============================================================

// << CHIP io port with system >>
input 			  	clk,rst_n;
input 			   	in_valid;
input  [4:0] 		frame_id;
input  [3:0]       	net_id;     
input  [5:0]       	loc_x; 
input  [5:0]       	loc_y; 
output reg [13:0] 	cost;
output reg          busy;       
  
// AXI Interface wire connecttion for pseudo DRAM read/write
/* Hint:
       Your AXI-4 interface could be designed as a bridge in submodule,
	   therefore I declared output of AXI as wire.  
	   Ex: AXI4_interface AXI4_INF(...);
*/

// ------------------------
// <<<<< AXI READ >>>>>
// ------------------------
// (1)	axi read address channel 
output wire [ID_WIDTH-1:0]      arid_m_inf;
output wire [1:0]            arburst_m_inf;
output wire [2:0]             arsize_m_inf;
output wire [7:0]              arlen_m_inf;
output reg                   arvalid_m_inf;
input  wire                  arready_m_inf;
output reg [ADDR_WIDTH-1:0]   araddr_m_inf;
// ------------------------
// (2)	axi read data channel 
input  wire [ID_WIDTH-1:0]       rid_m_inf;
input  wire                   rvalid_m_inf;
output reg                    rready_m_inf;
input  wire [DATA_WIDTH-1:0]   rdata_m_inf;
input  wire                    rlast_m_inf;
input  wire [1:0]              rresp_m_inf;
// ------------------------
// <<<<< AXI WRITE >>>>>
// ------------------------
// (1) 	axi write address channel 
output wire [ID_WIDTH-1:0]      awid_m_inf;
output wire [1:0]            awburst_m_inf;
output wire [2:0]             awsize_m_inf;
output wire [7:0]              awlen_m_inf;
output reg                  awvalid_m_inf;
input  wire                  awready_m_inf;
output reg [ADDR_WIDTH-1:0]  awaddr_m_inf;
// -------------------------
// (2)	axi write data channel 
output reg                   wvalid_m_inf;
input  wire                   wready_m_inf;
output reg [DATA_WIDTH-1:0]   wdata_m_inf;
output reg                    wlast_m_inf;
// -------------------------
// (3)	axi write response channel 
input  wire  [ID_WIDTH-1:0]      bid_m_inf;
input  wire                   bvalid_m_inf;
output reg                    bready_m_inf;
input  wire  [1:0]             bresp_m_inf;
// -----------------------------


// ===============================================================
// Register and Wire declaration 
// ===============================================================

// FSM
reg [2:0] c_state, n_state;

// AXI FSM
reg [3:0] AXI_c_state, AXI_n_state;

// input registers
reg [4:0] frame_id_tmp;
reg [3:0] net [0:14];
reg [5:0] x_start [1:15];
reg [5:0] x_end [1:15];
reg [5:0] y_start [1:15];
reg [5:0] y_end [1:15];

// Path map
reg [6:0] addr_path;
reg [127:0] path_map_in;
reg w_r_path;
wire [127:0] path_map_out;

reg [3:0] ini_addr_1;
reg ini_addr_2;

// Weight map
reg [6:0] addr_wei;
reg [127:0] wei_map_in;
reg w_r_wei;
wire [127:0] wei_map_out;

// Ripple Map 
reg [1:0] ripple_map [0:63][0:63];

// Count
reg [3:0] cnt_input;
reg [6:0] cnt_128;
reg cnt_write_sram;
reg [1:0] cnt_ripple;
reg [3:0] cnt_netid;

// Retrace variables
reg [5:0] x_now,y_now;

// Control
reg is_terminal;
wire can_read;
assign can_read = (rvalid_m_inf && rready_m_inf) ? 1'd1 :1'd0;

wire can_write;
assign can_write = (wvalid_m_inf && wready_m_inf) ? 1'd1 :1'd0;

wire touch_terminal;
assign touch_terminal = (ripple_map[y_end[net[cnt_netid]]][x_end[net[cnt_netid]]][1]) ? 1'd1 :1'd0;

wire weight_valid;
assign weight_valid = (AXI_n_state == READ_DATA_WEIGHT) ? 1'b1: 1'b0;

wire back_to_start;
assign back_to_start = (!ripple_map[y_start[net[cnt_netid]]][x_start[net[cnt_netid]]][1]) ? 1'd1 :1'd0;

wire upload_sram;
assign upload_sram = (c_state == RETRACE) ? 1'b1: 1'b0;

wire [6:0] choose_sram_addr;
assign choose_sram_addr = (x_now[5]) ? {y_now,1'd1}:{y_now,1'd0};

wire finish_routing;
assign finish_routing = (cnt_netid == cnt_input - 1'b1) ? 1'b1 : 1'b0 ;

wire near_top,near_left,near_right,near_down;
assign near_top   = (!(y_now[0] | y_now[1] | y_now[2] | y_now[3] | y_now[4] | y_now[5])) ? 1'b1 :1'b0;
assign near_down  = (  y_now[0] & y_now[1] & y_now[2] & y_now[3] & y_now[4] & y_now[5] ) ? 1'b1 :1'b0;
assign near_left  = (!(x_now[0] | x_now[1] | x_now[2] | x_now[3] | x_now[4] | x_now[5])) ? 1'b1 :1'b0;
assign near_right = (  x_now[0] & x_now[1] & x_now[2] & x_now[3] & x_now[4] & x_now[5] ) ? 1'b1 :1'b0;


reg [1:0] before_num;
wire [6:0] cnt_128_1;
assign cnt_128_1 = cnt_128 + 1'b1;

reg reset_start_end;


// ===============================================================
// FSM 
// ===============================================================
always @(posedge clk or negedge rst_n) begin // c_state
	if (!rst_n) begin
		c_state <= IDLE;
	end else begin
		c_state <= n_state;
	end
end

always @(*) begin // n_state
	case (c_state)
		IDLE : begin
			if (in_valid)
				n_state = INPUT;
			else
				n_state = c_state;	
		end 
		INPUT : begin
			if (!in_valid)
				n_state = WAIT_READ_DATA_PATH;
			else 
				n_state = c_state;	
		end
		WAIT_READ_DATA_PATH: begin
			if (rlast_m_inf)
				n_state = FILL_MAP;
			else 
				n_state = c_state;	
		end
		FILL_MAP:begin
			if (touch_terminal)
				if (weight_valid) begin
					n_state = WAIT_WEIGHT;
				end else begin
					n_state = RETRACE;
				end	
			else 
				n_state = c_state;
		end
		WAIT_WEIGHT:begin
			if (weight_valid) begin
				n_state = c_state;
			end else begin
				n_state = RETRACE;
			end	
		end
		RETRACE:begin
			if (back_to_start) begin
				if (finish_routing) begin
					n_state = WRITE_DRAM;
				end else begin
					n_state = FILL_MAP;
				end
			end else begin
				n_state = c_state;
			end
		end
		WRITE_DRAM:begin
			if (bready_m_inf && bvalid_m_inf)
				n_state = IDLE;
			else 
				n_state = c_state;
		end
		
		default: n_state = c_state;
	endcase
end

// ===============================================================
// AXI FSM
// ===============================================================
always @(posedge clk or negedge rst_n) begin // AXI_c_state
	if (!rst_n) begin
		AXI_c_state <= START;
	end else begin
		AXI_c_state <= AXI_n_state;
	end
end

always @(*) begin // AXI_n_state
	case (AXI_c_state)
		START: begin
			if (in_valid)
				AXI_n_state = READ_ADDRESS_PATH;
			else
				AXI_n_state = AXI_c_state;
		end 
		READ_ADDRESS_PATH: begin
			if (arready_m_inf && arvalid_m_inf)
				AXI_n_state = READ_DATA_PATH;
			else
				AXI_n_state = AXI_c_state;
		end
		READ_DATA_PATH: begin
			if (rlast_m_inf)
				AXI_n_state = READ_ADDRESS_WEIGHT;
			else
				AXI_n_state = AXI_c_state;

		end
		READ_ADDRESS_WEIGHT: begin
			if (arvalid_m_inf && arready_m_inf)
				AXI_n_state = READ_DATA_WEIGHT;
			else
				AXI_n_state = AXI_c_state;
		end
		READ_DATA_WEIGHT: begin
			if (rlast_m_inf)
				AXI_n_state = WAIT_WRITE_DATA;
			else
				AXI_n_state = AXI_c_state;
				
		end
		WAIT_WRITE_DATA:begin
			if (back_to_start && finish_routing && c_state == RETRACE) 
				AXI_n_state = WRITE_ADDRESS;
			else
				AXI_n_state = AXI_c_state;
		end
		WRITE_ADDRESS:begin
			if (awready_m_inf && awvalid_m_inf) begin
				AXI_n_state = WRITE_DATA;
			end else begin
				AXI_n_state = AXI_c_state;
			end
		end
		WRITE_DATA:begin
			if (wlast_m_inf)
				AXI_n_state = WRITE_RESPONSE;
			else 
				AXI_n_state = AXI_c_state;
		end
		WRITE_RESPONSE:begin
			if (bready_m_inf && bvalid_m_inf) begin
				AXI_n_state = START;
			end else begin
				AXI_n_state = AXI_c_state;
			end
		end
		default: AXI_n_state = AXI_c_state;
	endcase
end



// ===============================================================
// Input Register 
// ===============================================================
always @(posedge clk or negedge rst_n) begin // frame_id_tmp
	if (!rst_n) begin
		frame_id_tmp <= 5'd0;
	end else begin
		case (n_state)
			INPUT: begin frame_id_tmp <= frame_id; end
			default: begin frame_id_tmp <= frame_id_tmp; end
		endcase
	end
end

always @(posedge clk or negedge rst_n) begin // x_start、x_end、y_start、y_end
	if (!rst_n) begin
		for (i = 1;i < 16;i = i + 1) begin
			x_start[i] <= 6'd0;
			x_end[i]   <= 6'd0;
			y_start[i] <= 6'd0;
			y_end[i]   <= 6'd0;
		end
	end else begin
		case (n_state)
			INPUT: begin
				if (!is_terminal) begin
					x_start[net_id] <= loc_x;
					y_start[net_id] <= loc_y;
				end
				else begin
					x_end[net_id]   <= loc_x;
					y_end[net_id]   <= loc_y;
				end
			end
			default: begin end
		endcase
	end
end

always @(posedge clk or negedge rst_n) begin // net
	if (!rst_n) begin
		for (i = 0;i < 15;i = i + 1) begin
			net[i] <= 4'd0;
		end
	end else begin
		case (n_state)
			INPUT: begin net[cnt_input] <= net_id; end
			default: begin end
		endcase
	end
end

// ===============================================================
// Ripple Map 
// ===============================================================

always @(posedge clk or negedge rst_n) begin // ripple_map
	if (!rst_n) begin
		for (i = 0;i < 64;i = i + 1) begin
			for (j = 0;j < 64;j = j + 1) begin
				ripple_map[i][j] <= 2'd0;
			end
		end
	end else begin
		case (c_state)
		    IDLE: begin
				for (i = 0;i < 64;i = i + 1) begin
					for (j = 0;j < 64;j = j + 1) begin
						ripple_map[i][j] <= 2'd0;
					end
				end
			end
			INPUT: begin
				if (can_read) begin
					if (!cnt_128[0]) begin
						for (i = 0;i < 32;i = i + 1) begin
							ripple_map[cnt_128[6:1]][i] <= rdata_m_inf[4*i] | rdata_m_inf[4*i+1] | rdata_m_inf[4*i+2] | rdata_m_inf[4*i+3];
						end
					end else begin
						for (i = 0;i < 32;i = i + 1) begin
							ripple_map[cnt_128[6:1]][32+i] <= rdata_m_inf[4*i] | rdata_m_inf[4*i+1] | rdata_m_inf[4*i+2] | rdata_m_inf[4*i+3];
						end
					end
				end
			end 

			WAIT_READ_DATA_PATH: begin
				if (can_read) begin
					if (!cnt_128[0]) begin
						for (i = 0;i < 32;i = i + 1) begin
							ripple_map[cnt_128[6:1]][i] <= rdata_m_inf[4*i] | rdata_m_inf[4*i+1] | rdata_m_inf[4*i+2] | rdata_m_inf[4*i+3];
						end
					end else begin
						for (i = 0;i < 32;i = i + 1) begin
							ripple_map[cnt_128[6:1]][32+i] <= rdata_m_inf[4*i] | rdata_m_inf[4*i+1] | rdata_m_inf[4*i+2] | rdata_m_inf[4*i+3];
						end
					end
				end
			end 
			FILL_MAP:begin 
				if (!reset_start_end) begin
					ripple_map[y_start[net[cnt_netid]]][x_start[net[cnt_netid]]] <= 2'd2; // start
				 	ripple_map[y_end[net[cnt_netid]]][x_end[net[cnt_netid]]] <= 2'd0; // end
				end else begin
					// near 4 
					for (i = 1 ;i < 63; i = i + 1) begin
						for (j = 1; j < 63; j = j + 1) begin
							if (ripple_map[i][j] == 2'd0) begin
								if (ripple_map[i+1][j][1] | ripple_map[i-1][j][1] | ripple_map[i][j+1][1] | ripple_map[i][j-1][1]) begin
									ripple_map[i][j] <= {1'b1,cnt_ripple[1]};
								end
							end
						end
					end

					// no top
					for (i = 1 ;i < 63; i = i + 1) begin
						if (ripple_map[i][0] == 2'd0) begin
							if (ripple_map[i+1][0][1] | ripple_map[i-1][0][1] | ripple_map[i][1][1]) begin
								ripple_map[i][0] <= {1'b1,cnt_ripple[1]};
							end
						end
					end
					// no left
					for (j = 1 ;j < 63; j = j + 1) begin
						if (ripple_map[0][j] == 2'd0) begin
							if (ripple_map[0][j+1][1] | ripple_map[0][j-1][1] | ripple_map[1][j][1]) begin
								ripple_map[0][j] <= {1'b1,cnt_ripple[1]};
							end
						end
					end
					// no right
					for (j = 1 ;j < 63; j = j + 1) begin
						if (ripple_map[63][j] == 2'd0) begin
							if (ripple_map[63][j+1][1] | ripple_map[63][j-1][1] | ripple_map[62][j][1]) begin
								ripple_map[63][j] <= {1'b1,cnt_ripple[1]};
							end
						end
					end
					// no down
					for (i = 1 ;i < 63; i = i + 1) begin
						if (ripple_map[i][63] == 2'd0) begin
							if (ripple_map[i+1][63][1] | ripple_map[i-1][63][1] | ripple_map[i][62][1]) begin
								ripple_map[i][63] <= {1'b1,cnt_ripple[1]};
							end
						end
					end
					// 4 corner
					if (ripple_map[0][0] == 2'd0) begin
						if (ripple_map[0][1][1] | ripple_map[1][0][1]) begin
							ripple_map[0][0] <= {1'b1,cnt_ripple[1]};
						end
					end

					if (ripple_map[0][63] == 2'd0) begin
						if (ripple_map[0][62][1] | ripple_map[1][63][1]) begin
							ripple_map[0][63] <= {1'b1,cnt_ripple[1]};
						end
					end

					if (ripple_map[63][0] == 2'd0) begin
						if (ripple_map[62][0][1] | ripple_map[63][1][1]) begin
							ripple_map[63][0] <= {1'b1,cnt_ripple[1]};
						end
					end

					if (ripple_map[63][63] == 2'd0) begin
						if (ripple_map[62][63][1] | ripple_map[63][62][1]) begin
							ripple_map[63][63] <= {1'b1,cnt_ripple[1]};
						end
					end
				end	
			end
			RETRACE:begin
				if (!back_to_start) begin
					ripple_map[y_now][x_now] <= 2'd1;
				end 
				else begin
					for (i = 0;i < 64;i = i + 1) begin
						for (j = 0;j < 64;j = j + 1) begin
							if (ripple_map[i][j][1])
								ripple_map[i][j] <= 2'd0;
						end
					end
				end
			end
			default: begin end
		endcase
	end	
end


// ===============================================================
// Count
// ===============================================================
always @(posedge clk or negedge rst_n) begin //cnt_input
	if (!rst_n) begin
		cnt_input <= 4'd0;
	end else begin
		case (n_state)
			IDLE: cnt_input <= 4'd0;
			INPUT: begin 
				if (is_terminal) begin
					cnt_input <= cnt_input + 1'b1; 
				end else begin
					cnt_input <= cnt_input;
				end
			end
			default: cnt_input <= cnt_input;
		endcase
	end
end

always @(posedge clk or negedge rst_n) begin //cnt_128
	if (!rst_n) begin
		cnt_128 <= 7'd0;
	end else begin
		case (AXI_c_state)
			READ_DATA_PATH,READ_DATA_WEIGHT: begin 
				if (can_read) 
					cnt_128 <= cnt_128 + 1'b1;
				else
					cnt_128 <= cnt_128;
			end
			WRITE_DATA:begin
				if (can_write) 
					cnt_128 <= cnt_128 + 1'b1;
				else
					cnt_128 <= cnt_128;
			end
			default: cnt_128 <= 7'd0;
		endcase
	end
end


always @(posedge clk or negedge rst_n) begin //cnt_write_sram
	if (!rst_n) begin
		cnt_write_sram <= 1'd0;
	end else begin
		case (c_state)
			RETRACE: begin 
				cnt_write_sram <= ~cnt_write_sram;
			end
			default: cnt_write_sram <= 1'd0;
		endcase
	end
end

always @(posedge clk or negedge rst_n) begin //cnt_ripple
	if (!rst_n) begin
		cnt_ripple <= 2'd0;
	end else begin
		case (c_state)
			FILL_MAP: begin 
				if (n_state != c_state) begin
					cnt_ripple <= cnt_ripple - 1'b1;
				end else begin
					cnt_ripple <= cnt_ripple + 1'b1;
				end
			end
			WAIT_WEIGHT:begin
				cnt_ripple <= cnt_ripple;
			end
			RETRACE:begin
				if (c_state != n_state) begin
					cnt_ripple <= 2'd0;
				end
				else begin
					if (cnt_write_sram) begin
						cnt_ripple <= cnt_ripple - 1'b1;
					end	
				end	
			end
			default: cnt_ripple <= 2'd0;
		endcase
	end
end

always @(posedge clk or negedge rst_n) begin //cnt_netid
	if (!rst_n) begin
		cnt_netid <= 4'd0;
	end else begin
		case (c_state)
			IDLE:begin
				cnt_netid <= 4'd0;
			end
			RETRACE:begin
				if (c_state != n_state && !finish_routing) begin
					cnt_netid <= cnt_netid + 1'b1;
				end
			end
			default: cnt_netid <= cnt_netid;
		endcase
	end
end

// ===============================================================
// Control
// ===============================================================
always @(posedge clk or negedge rst_n) begin // is_terminal
	if (!rst_n) begin
		is_terminal <= 1'd0;
	end else begin
		case (n_state)
			INPUT: begin 
				is_terminal <= is_terminal + 1'b1;
			end
			default: is_terminal <= 1'd0;
		endcase
	end
end

always @(posedge clk or negedge rst_n) begin // reset_start_end
	if (!rst_n) begin
		reset_start_end <= 1'b0;
	end else begin
		case (c_state)
			FILL_MAP: begin
				if (!reset_start_end)
					reset_start_end <= 1'b1;
				else
					reset_start_end <= reset_start_end;	
			end
			default: reset_start_end <= 1'b0;
		endcase
	end
end

// ===============================================================
// Retrace variables
// ===============================================================
always @(*) begin // before_num
	case (cnt_ripple)
		2'd0: before_num = 2'd3;
		2'd1: before_num = 2'd2;
		2'd2: before_num = 2'd2;
		2'd3: before_num = 2'd3;
		default: before_num = 2'd0;
	endcase
end


always @(posedge clk or negedge rst_n) begin // x_now  y_now
	if (!rst_n) begin
		x_now <= 6'd0;
		y_now <= 6'd0;
	end else begin
		case (c_state)
			FILL_MAP: begin
				x_now <= x_end[net[cnt_netid]];
				y_now <= y_end[net[cnt_netid]]; 
			end
			RETRACE: begin
				if (cnt_write_sram) begin
					if (ripple_map[y_now+1][x_now] == before_num && !near_down) begin //down
						y_now <= y_now + 1'b1;
					end
					else if (ripple_map[y_now-1][x_now] == before_num && !near_top) begin //up
						y_now <= y_now - 1'b1;
					end
					else if (ripple_map[y_now][x_now+1] == before_num && !near_right) begin // right
						x_now <= x_now + 1'b1;
					end
					else if (ripple_map[y_now][x_now-1] == before_num && !near_left) begin //left
						x_now <= x_now - 1'b1;
					end
				end

			end
			default: begin end
		endcase
	end
end


// ===============================================================
// SRAM 
// ===============================================================
Mapping PATH(
	.A0  (addr_path[0]),   .A1  (addr_path[1]),   .A2  (addr_path[2]),   .A3  (addr_path[3]),   .A4  (addr_path[4]),   .A5  (addr_path[5]),   .A6  (addr_path[6]),

	.DO0 (path_map_out[0]),   .DO1 (path_map_out[1]),   .DO2 (path_map_out[2]),   .DO3 (path_map_out[3]),   .DO4 (path_map_out[4]),   .DO5 (path_map_out[5]),   .DO6 (path_map_out[6]),   .DO7 (path_map_out[7]),
	.DO8 (path_map_out[8]),   .DO9 (path_map_out[9]),   .DO10(path_map_out[10]),  .DO11(path_map_out[11]),  .DO12(path_map_out[12]),  .DO13(path_map_out[13]),  .DO14(path_map_out[14]),  .DO15(path_map_out[15]),
	.DO16(path_map_out[16]),  .DO17(path_map_out[17]),  .DO18(path_map_out[18]),  .DO19(path_map_out[19]),  .DO20(path_map_out[20]),  .DO21(path_map_out[21]),  .DO22(path_map_out[22]),  .DO23(path_map_out[23]),
	.DO24(path_map_out[24]),  .DO25(path_map_out[25]),  .DO26(path_map_out[26]),  .DO27(path_map_out[27]),  .DO28(path_map_out[28]),  .DO29(path_map_out[29]),  .DO30(path_map_out[30]),  .DO31(path_map_out[31]),
	.DO32(path_map_out[32]),  .DO33(path_map_out[33]),  .DO34(path_map_out[34]),  .DO35(path_map_out[35]),  .DO36(path_map_out[36]),  .DO37(path_map_out[37]),  .DO38(path_map_out[38]),  .DO39(path_map_out[39]),
	.DO40(path_map_out[40]),  .DO41(path_map_out[41]),  .DO42(path_map_out[42]),  .DO43(path_map_out[43]),  .DO44(path_map_out[44]),  .DO45(path_map_out[45]),  .DO46(path_map_out[46]),  .DO47(path_map_out[47]),
	.DO48(path_map_out[48]),  .DO49(path_map_out[49]),  .DO50(path_map_out[50]),  .DO51(path_map_out[51]),  .DO52(path_map_out[52]),  .DO53(path_map_out[53]),  .DO54(path_map_out[54]),  .DO55(path_map_out[55]),
	.DO56(path_map_out[56]),  .DO57(path_map_out[57]),  .DO58(path_map_out[58]),  .DO59(path_map_out[59]),  .DO60(path_map_out[60]),  .DO61(path_map_out[61]),  .DO62(path_map_out[62]),  .DO63(path_map_out[63]),
	.DO64(path_map_out[64]),  .DO65(path_map_out[65]),  .DO66(path_map_out[66]),  .DO67(path_map_out[67]),  .DO68(path_map_out[68]),  .DO69(path_map_out[69]),  .DO70(path_map_out[70]),  .DO71(path_map_out[71]),
	.DO72(path_map_out[72]),  .DO73(path_map_out[73]),  .DO74(path_map_out[74]),  .DO75(path_map_out[75]),  .DO76(path_map_out[76]),  .DO77(path_map_out[77]),  .DO78(path_map_out[78]),  .DO79(path_map_out[79]),
	.DO80(path_map_out[80]),  .DO81(path_map_out[81]),  .DO82(path_map_out[82]),  .DO83(path_map_out[83]),  .DO84(path_map_out[84]),  .DO85(path_map_out[85]),  .DO86(path_map_out[86]),  .DO87(path_map_out[87]),
	.DO88(path_map_out[88]),  .DO89(path_map_out[89]),  .DO90(path_map_out[90]),  .DO91(path_map_out[91]),  .DO92(path_map_out[92]),  .DO93(path_map_out[93]),  .DO94(path_map_out[94]),  .DO95(path_map_out[95]),
	.DO96(path_map_out[96]),  .DO97(path_map_out[97]),  .DO98(path_map_out[98]),  .DO99(path_map_out[99]),  .DO100(path_map_out[100]),.DO101(path_map_out[101]),.DO102(path_map_out[102]),.DO103(path_map_out[103]),
	.DO104(path_map_out[104]),.DO105(path_map_out[105]),.DO106(path_map_out[106]),.DO107(path_map_out[107]),.DO108(path_map_out[108]),.DO109(path_map_out[109]),.DO110(path_map_out[110]),.DO111(path_map_out[111]),
	.DO112(path_map_out[112]),.DO113(path_map_out[113]),.DO114(path_map_out[114]),.DO115(path_map_out[115]),.DO116(path_map_out[116]),.DO117(path_map_out[117]),.DO118(path_map_out[118]),.DO119(path_map_out[119]),
	.DO120(path_map_out[120]),.DO121(path_map_out[121]),.DO122(path_map_out[122]),.DO123(path_map_out[123]),.DO124(path_map_out[124]),.DO125(path_map_out[125]),.DO126(path_map_out[126]),.DO127(path_map_out[127]),

	.DI0 (path_map_in[0]),   .DI1 (path_map_in[1]),   .DI2 (path_map_in[2]),   .DI3 (path_map_in[3]),   .DI4 (path_map_in[4]),   .DI5 (path_map_in[5]),   .DI6 (path_map_in[6]),   .DI7 (path_map_in[7]),
	.DI8 (path_map_in[8]),   .DI9 (path_map_in[9]),   .DI10(path_map_in[10]),  .DI11(path_map_in[11]),  .DI12(path_map_in[12]),  .DI13(path_map_in[13]),  .DI14(path_map_in[14]),  .DI15(path_map_in[15]),
	.DI16(path_map_in[16]),  .DI17(path_map_in[17]),  .DI18(path_map_in[18]),  .DI19(path_map_in[19]),  .DI20(path_map_in[20]),  .DI21(path_map_in[21]),  .DI22(path_map_in[22]),  .DI23(path_map_in[23]),
	.DI24(path_map_in[24]),  .DI25(path_map_in[25]),  .DI26(path_map_in[26]),  .DI27(path_map_in[27]),  .DI28(path_map_in[28]),  .DI29(path_map_in[29]),  .DI30(path_map_in[30]),  .DI31(path_map_in[31]),
	.DI32(path_map_in[32]),  .DI33(path_map_in[33]),  .DI34(path_map_in[34]),  .DI35(path_map_in[35]),  .DI36(path_map_in[36]),  .DI37(path_map_in[37]),  .DI38(path_map_in[38]),  .DI39(path_map_in[39]),
	.DI40(path_map_in[40]),  .DI41(path_map_in[41]),  .DI42(path_map_in[42]),  .DI43(path_map_in[43]),  .DI44(path_map_in[44]),  .DI45(path_map_in[45]),  .DI46(path_map_in[46]),  .DI47(path_map_in[47]),
	.DI48(path_map_in[48]),  .DI49(path_map_in[49]),  .DI50(path_map_in[50]),  .DI51(path_map_in[51]),  .DI52(path_map_in[52]),  .DI53(path_map_in[53]),  .DI54(path_map_in[54]),  .DI55(path_map_in[55]),
	.DI56(path_map_in[56]),  .DI57(path_map_in[57]),  .DI58(path_map_in[58]),  .DI59(path_map_in[59]),  .DI60(path_map_in[60]),  .DI61(path_map_in[61]),  .DI62(path_map_in[62]),  .DI63(path_map_in[63]),
	.DI64(path_map_in[64]),  .DI65(path_map_in[65]),  .DI66(path_map_in[66]),  .DI67(path_map_in[67]),  .DI68(path_map_in[68]),  .DI69(path_map_in[69]),  .DI70(path_map_in[70]),  .DI71(path_map_in[71]),
	.DI72(path_map_in[72]),  .DI73(path_map_in[73]),  .DI74(path_map_in[74]),  .DI75(path_map_in[75]),  .DI76(path_map_in[76]),  .DI77(path_map_in[77]),  .DI78(path_map_in[78]),  .DI79(path_map_in[79]),
	.DI80(path_map_in[80]),  .DI81(path_map_in[81]),  .DI82(path_map_in[82]),  .DI83(path_map_in[83]),  .DI84(path_map_in[84]),  .DI85(path_map_in[85]),  .DI86(path_map_in[86]),  .DI87(path_map_in[87]),
	.DI88(path_map_in[88]),  .DI89(path_map_in[89]),  .DI90(path_map_in[90]),  .DI91(path_map_in[91]),  .DI92(path_map_in[92]),  .DI93(path_map_in[93]),  .DI94(path_map_in[94]),  .DI95(path_map_in[95]),
	.DI96(path_map_in[96]),  .DI97(path_map_in[97]),  .DI98(path_map_in[98]),  .DI99(path_map_in[99]),  .DI100(path_map_in[100]),.DI101(path_map_in[101]),.DI102(path_map_in[102]),.DI103(path_map_in[103]),
	.DI104(path_map_in[104]),.DI105(path_map_in[105]),.DI106(path_map_in[106]),.DI107(path_map_in[107]),.DI108(path_map_in[108]),.DI109(path_map_in[109]),.DI110(path_map_in[110]),.DI111(path_map_in[111]),
	.DI112(path_map_in[112]),.DI113(path_map_in[113]),.DI114(path_map_in[114]),.DI115(path_map_in[115]),.DI116(path_map_in[116]),.DI117(path_map_in[117]),.DI118(path_map_in[118]),.DI119(path_map_in[119]),
	.DI120(path_map_in[120]),.DI121(path_map_in[121]),.DI122(path_map_in[122]),.DI123(path_map_in[123]),.DI124(path_map_in[124]),.DI125(path_map_in[125]),.DI126(path_map_in[126]),.DI127(path_map_in[127]),

	.CK(clk), .WEB(w_r_path), .OE(1'b1), .CS(1'b1));

Mapping WEIGHT(
	.A0  (addr_wei[0]),   .A1  (addr_wei[1]),   .A2  (addr_wei[2]),   .A3  (addr_wei[3]),   .A4  (addr_wei[4]),   .A5  (addr_wei[5]),   .A6  (addr_wei[6]),
	
	.DO0 (wei_map_out[0]),     .DO1 (wei_map_out[1]),     .DO2 (wei_map_out[2]),     .DO3 (wei_map_out[3]),     .DO4 (wei_map_out[4]),     .DO5 (wei_map_out[5]),     .DO6 (wei_map_out[6]),     .DO7 (wei_map_out[7]),
	.DO8 (wei_map_out[8]),     .DO9 (wei_map_out[9]),     .DO10(wei_map_out[10]),    .DO11(wei_map_out[11]),    .DO12(wei_map_out[12]),    .DO13(wei_map_out[13]),    .DO14(wei_map_out[14]),    .DO15(wei_map_out[15]),
	.DO16(wei_map_out[16]),    .DO17(wei_map_out[17]),    .DO18(wei_map_out[18]),    .DO19(wei_map_out[19]),    .DO20(wei_map_out[20]),    .DO21(wei_map_out[21]),    .DO22(wei_map_out[22]),    .DO23(wei_map_out[23]),
	.DO24(wei_map_out[24]),    .DO25(wei_map_out[25]),    .DO26(wei_map_out[26]),    .DO27(wei_map_out[27]),    .DO28(wei_map_out[28]),    .DO29(wei_map_out[29]),    .DO30(wei_map_out[30]),    .DO31(wei_map_out[31]),
	.DO32(wei_map_out[32]),    .DO33(wei_map_out[33]),    .DO34(wei_map_out[34]),    .DO35(wei_map_out[35]),    .DO36(wei_map_out[36]),    .DO37(wei_map_out[37]),    .DO38(wei_map_out[38]),    .DO39(wei_map_out[39]),
	.DO40(wei_map_out[40]),    .DO41(wei_map_out[41]),    .DO42(wei_map_out[42]),    .DO43(wei_map_out[43]),    .DO44(wei_map_out[44]),    .DO45(wei_map_out[45]),    .DO46(wei_map_out[46]),    .DO47(wei_map_out[47]),
	.DO48(wei_map_out[48]),    .DO49(wei_map_out[49]),    .DO50(wei_map_out[50]),    .DO51(wei_map_out[51]),    .DO52(wei_map_out[52]),    .DO53(wei_map_out[53]),    .DO54(wei_map_out[54]),    .DO55(wei_map_out[55]),
	.DO56(wei_map_out[56]),    .DO57(wei_map_out[57]),    .DO58(wei_map_out[58]),    .DO59(wei_map_out[59]),    .DO60(wei_map_out[60]),    .DO61(wei_map_out[61]),    .DO62(wei_map_out[62]),    .DO63(wei_map_out[63]),
	.DO64(wei_map_out[64]),    .DO65(wei_map_out[65]),    .DO66(wei_map_out[66]),    .DO67(wei_map_out[67]),    .DO68(wei_map_out[68]),    .DO69(wei_map_out[69]),    .DO70(wei_map_out[70]),    .DO71(wei_map_out[71]),
	.DO72(wei_map_out[72]),    .DO73(wei_map_out[73]),    .DO74(wei_map_out[74]),    .DO75(wei_map_out[75]),    .DO76(wei_map_out[76]),    .DO77(wei_map_out[77]),    .DO78(wei_map_out[78]),    .DO79(wei_map_out[79]),
	.DO80(wei_map_out[80]),    .DO81(wei_map_out[81]),    .DO82(wei_map_out[82]),    .DO83(wei_map_out[83]),    .DO84(wei_map_out[84]),    .DO85(wei_map_out[85]),    .DO86(wei_map_out[86]),    .DO87(wei_map_out[87]),
	.DO88(wei_map_out[88]),    .DO89(wei_map_out[89]),    .DO90(wei_map_out[90]),    .DO91(wei_map_out[91]),    .DO92(wei_map_out[92]),    .DO93(wei_map_out[93]),    .DO94(wei_map_out[94]),    .DO95(wei_map_out[95]),
	.DO96(wei_map_out[96]),    .DO97(wei_map_out[97]),    .DO98(wei_map_out[98]),    .DO99(wei_map_out[99]),    .DO100(wei_map_out[100]),  .DO101(wei_map_out[101]),  .DO102(wei_map_out[102]),  .DO103(wei_map_out[103]),
	.DO104(wei_map_out[104]),  .DO105(wei_map_out[105]),  .DO106(wei_map_out[106]),  .DO107(wei_map_out[107]),  .DO108(wei_map_out[108]),  .DO109(wei_map_out[109]),  .DO110(wei_map_out[110]),  .DO111(wei_map_out[111]),
	.DO112(wei_map_out[112]),  .DO113(wei_map_out[113]),  .DO114(wei_map_out[114]),  .DO115(wei_map_out[115]),  .DO116(wei_map_out[116]),  .DO117(wei_map_out[117]),  .DO118(wei_map_out[118]),  .DO119(wei_map_out[119]),
	.DO120(wei_map_out[120]),  .DO121(wei_map_out[121]),  .DO122(wei_map_out[122]),  .DO123(wei_map_out[123]),  .DO124(wei_map_out[124]),  .DO125(wei_map_out[125]),  .DO126(wei_map_out[126]),  .DO127(wei_map_out[127]),
	  
	.DI0 (wei_map_in[0]),      .DI1 (wei_map_in[1]),      .DI2 (wei_map_in[2]),      .DI3 (wei_map_in[3]),      .DI4 (wei_map_in[4]),      .DI5 (wei_map_in[5]),      .DI6 (wei_map_in[6]),      .DI7 (wei_map_in[7]),
	.DI8 (wei_map_in[8]),      .DI9 (wei_map_in[9]),      .DI10(wei_map_in[10]),     .DI11(wei_map_in[11]),     .DI12(wei_map_in[12]),     .DI13(wei_map_in[13]),     .DI14(wei_map_in[14]),     .DI15(wei_map_in[15]),
	.DI16(wei_map_in[16]),     .DI17(wei_map_in[17]),     .DI18(wei_map_in[18]),     .DI19(wei_map_in[19]),     .DI20(wei_map_in[20]),     .DI21(wei_map_in[21]),     .DI22(wei_map_in[22]),     .DI23(wei_map_in[23]),
	.DI24(wei_map_in[24]),     .DI25(wei_map_in[25]),     .DI26(wei_map_in[26]),     .DI27(wei_map_in[27]),     .DI28(wei_map_in[28]),     .DI29(wei_map_in[29]),     .DI30(wei_map_in[30]),     .DI31(wei_map_in[31]),
	.DI32(wei_map_in[32]),     .DI33(wei_map_in[33]),     .DI34(wei_map_in[34]),     .DI35(wei_map_in[35]),     .DI36(wei_map_in[36]),     .DI37(wei_map_in[37]),     .DI38(wei_map_in[38]),     .DI39(wei_map_in[39]),
	.DI40(wei_map_in[40]),     .DI41(wei_map_in[41]),     .DI42(wei_map_in[42]),     .DI43(wei_map_in[43]),     .DI44(wei_map_in[44]),     .DI45(wei_map_in[45]),     .DI46(wei_map_in[46]),     .DI47(wei_map_in[47]),
	.DI48(wei_map_in[48]),     .DI49(wei_map_in[49]),     .DI50(wei_map_in[50]),     .DI51(wei_map_in[51]),     .DI52(wei_map_in[52]),     .DI53(wei_map_in[53]),     .DI54(wei_map_in[54]),     .DI55(wei_map_in[55]),
	.DI56(wei_map_in[56]),     .DI57(wei_map_in[57]),     .DI58(wei_map_in[58]),     .DI59(wei_map_in[59]),     .DI60(wei_map_in[60]),     .DI61(wei_map_in[61]),     .DI62(wei_map_in[62]),     .DI63(wei_map_in[63]),
	.DI64(wei_map_in[64]),     .DI65(wei_map_in[65]),     .DI66(wei_map_in[66]),     .DI67(wei_map_in[67]),     .DI68(wei_map_in[68]),     .DI69(wei_map_in[69]),     .DI70(wei_map_in[70]),     .DI71(wei_map_in[71]),
	.DI72(wei_map_in[72]),     .DI73(wei_map_in[73]),     .DI74(wei_map_in[74]),     .DI75(wei_map_in[75]),     .DI76(wei_map_in[76]),     .DI77(wei_map_in[77]),     .DI78(wei_map_in[78]),     .DI79(wei_map_in[79]),
	.DI80(wei_map_in[80]),     .DI81(wei_map_in[81]),     .DI82(wei_map_in[82]),     .DI83(wei_map_in[83]),     .DI84(wei_map_in[84]),     .DI85(wei_map_in[85]),     .DI86(wei_map_in[86]),     .DI87(wei_map_in[87]),
	.DI88(wei_map_in[88]),     .DI89(wei_map_in[89]),     .DI90(wei_map_in[90]),     .DI91(wei_map_in[91]),     .DI92(wei_map_in[92]),     .DI93(wei_map_in[93]),     .DI94(wei_map_in[94]),     .DI95(wei_map_in[95]),
	.DI96(wei_map_in[96]),     .DI97(wei_map_in[97]),     .DI98(wei_map_in[98]),     .DI99(wei_map_in[99]),     .DI100(wei_map_in[100]),   .DI101(wei_map_in[101]),   .DI102(wei_map_in[102]),   .DI103(wei_map_in[103]),
	.DI104(wei_map_in[104]),   .DI105(wei_map_in[105]),   .DI106(wei_map_in[106]),   .DI107(wei_map_in[107]),   .DI108(wei_map_in[108]),   .DI109(wei_map_in[109]),   .DI110(wei_map_in[110]),   .DI111(wei_map_in[111]),
	.DI112(wei_map_in[112]),   .DI113(wei_map_in[113]),   .DI114(wei_map_in[114]),   .DI115(wei_map_in[115]),   .DI116(wei_map_in[116]),   .DI117(wei_map_in[117]),   .DI118(wei_map_in[118]),   .DI119(wei_map_in[119]),
	.DI120(wei_map_in[120]),   .DI121(wei_map_in[121]),   .DI122(wei_map_in[122]),   .DI123(wei_map_in[123]),   .DI124(wei_map_in[124]),   .DI125(wei_map_in[125]),   .DI126(wei_map_in[126]),   .DI127(wei_map_in[127]),
	      
	.CK(clk), .WEB(w_r_wei), .OE(1'b1), .CS(1'b1));

always @(*) begin // w_r_path
	case (AXI_c_state)
		READ_DATA_PATH: w_r_path = 1'b0; 
		WAIT_WRITE_DATA: begin
			if (upload_sram)
				w_r_path = (!cnt_write_sram) ? 1'b1 : 1'b0;
			else	
				w_r_path = 1'b1;
		end
		default: w_r_path = 1'b1;
	endcase
end

always @(*) begin // addr_path
	case (AXI_c_state)
		READ_DATA_PATH: addr_path = cnt_128; 
		WAIT_WRITE_DATA: begin
			if (upload_sram)
				addr_path = choose_sram_addr;
			else	
				addr_path = 7'd0;
		end
		WRITE_DATA:begin
			addr_path = (!can_write) ? 7'd0: cnt_128_1;
		end
		default: addr_path = 7'd0;
	endcase
end



always @(*) begin // path_map_in
	case (AXI_c_state)
		READ_DATA_PATH: path_map_in = rdata_m_inf; 
		WAIT_WRITE_DATA: begin
			if (upload_sram) begin
				path_map_in = path_map_out;
				path_map_in[{x_now[4:0],2'b0}+:4] = net[cnt_netid];
			end else begin
				path_map_in = 128'd0;
			end
		end
		default: path_map_in = 128'd0;
	endcase
end




always @(*) begin // w_r_wei
	case (AXI_c_state)
		READ_DATA_WEIGHT: w_r_wei = 1'b0; 
		default: w_r_wei = 1'b1;
	endcase
end

always @(*) begin // addr_wei
	case (AXI_c_state)
		READ_DATA_WEIGHT: addr_wei = cnt_128; 
		WAIT_WRITE_DATA: begin
			if (upload_sram)
				addr_wei = choose_sram_addr;
			else	
				addr_wei = 7'd0;
		end
		default: addr_wei = 7'd0;
	endcase
end

always @(*) begin // wei_map_in
	case (AXI_c_state)
		READ_DATA_WEIGHT: wei_map_in = rdata_m_inf; 
		default: wei_map_in = 128'd0;
	endcase
end



// ===============================================================
// AXI
// ===============================================================
assign arid_m_inf = 4'd0;
assign arburst_m_inf = 2'd1;
assign arsize_m_inf = 3'd4;
assign arlen_m_inf = 8'd127;

assign awid_m_inf = 4'd0;
assign awburst_m_inf = 2'd1;
assign awsize_m_inf = 3'd4;
assign awlen_m_inf = 8'd127; 



always @(*) begin // ini_addr_1
	case (frame_id_tmp)
		0,1:   ini_addr_1 = 4'd0;
  		2,3:   ini_addr_1 = 4'd1;
  		4,5:   ini_addr_1 = 4'd2;
  		6,7:   ini_addr_1 = 4'd3;
  		8,9:   ini_addr_1 = 4'd4;
  		10,11: ini_addr_1 = 4'd5;
  		12,13: ini_addr_1 = 4'd6;
  		14,15: ini_addr_1 = 4'd7;
  		16,17: ini_addr_1 = 4'd8;
  		18,19: ini_addr_1 = 4'd9;
		20,21: ini_addr_1 = 4'd10;
		22,23: ini_addr_1 = 4'd11;
		24,25: ini_addr_1 = 4'd12;
		26,27: ini_addr_1 = 4'd13;
		28,29: ini_addr_1 = 4'd14;
		30,31: ini_addr_1 = 4'd15;
		default: ini_addr_1 = 4'd0;
	endcase
end

always @(*) begin // ini_addr_2
	if (frame_id_tmp[0])
		ini_addr_2 = 1'd1;
	else
		ini_addr_2 = 1'd0;	
end

always @(*) begin // read address
    case (AXI_c_state)
		READ_ADDRESS_PATH: begin araddr_m_inf = (arvalid_m_inf) ? {16'd1,ini_addr_1,ini_addr_2,11'b0}: {16'd1,16'b0}; end
		READ_ADDRESS_WEIGHT: begin araddr_m_inf = (arvalid_m_inf) ? {16'd2,ini_addr_1,ini_addr_2,11'b0}: {16'd1,16'b0}; end
		default: begin araddr_m_inf = {16'd1,16'b0}; end
	endcase
	
end

always @(*) begin // read address valid
	case (AXI_c_state)
		READ_ADDRESS_PATH,READ_ADDRESS_WEIGHT: arvalid_m_inf = 1'b1;
		default: arvalid_m_inf = 1'b0;
	endcase
end

always @(*) begin // read data ready
	case (AXI_c_state)
		READ_DATA_PATH,READ_DATA_WEIGHT: rready_m_inf = 1'b1;
		default: rready_m_inf = 1'b0;
	endcase
end

always @(*) begin // write address
    case (AXI_c_state)
		WRITE_ADDRESS: begin awaddr_m_inf = (awvalid_m_inf) ? {16'd1,ini_addr_1,ini_addr_2,11'b0}: {16'd1,16'b0}; end
		default: begin awaddr_m_inf = 32'd0; end
	endcase
end

always @(*) begin // write address valid
	case (AXI_c_state)
		WRITE_ADDRESS: awvalid_m_inf = 1'b1;
		default: awvalid_m_inf = 1'b0;
	endcase
end

always @(*) begin // write data valid
	case (AXI_c_state)
		WRITE_DATA: begin
				wvalid_m_inf = 1'b1;
		end
		default: wvalid_m_inf = 1'b0;
	endcase
end

always @(*) begin // write data 
	case (AXI_c_state)
		WRITE_DATA: wdata_m_inf = path_map_out;
		default: wdata_m_inf = 127'd1;
	endcase
end

always @(*) begin // write last 
	case (AXI_c_state)
		WRITE_DATA: wlast_m_inf = (cnt_128 == 7'd127) ? 1'b1 : 1'b0;
		default: wlast_m_inf = 1'b0;
	endcase
end

always @(*) begin // bready 
	case (AXI_c_state)
		WRITE_DATA,WRITE_RESPONSE: bready_m_inf = 1'b1;
		default: bready_m_inf = 1'b0;
	endcase
end

// ===============================================================
// Output
// ===============================================================
always @(posedge clk or negedge rst_n) begin // cost
	if (!rst_n) begin
		cost <= 14'd0;
	end else begin
		case (c_state)
			IDLE: cost <= 14'b0;
			RETRACE: begin
				if (upload_sram && cnt_write_sram) begin
					if ({x_now,y_now} != {x_start[net[cnt_netid]],y_start[net[cnt_netid]]} && {x_now,y_now} != {x_end[net[cnt_netid]],y_end[net[cnt_netid]]}) begin
						cost <= cost + wei_map_out[{x_now[4:0],2'b0}+:4];
					end
				end
			end
			default: cost <= cost;
		endcase
	end
end

always @(posedge clk or negedge rst_n) begin // busy
	if (!rst_n) begin
		busy <= 1'd0;
	end else begin
		case (n_state)
			IDLE,INPUT: busy <= 1'd0;
			default: busy <= 1'd1;
		endcase
	end
end
endmodule

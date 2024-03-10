module bridge(input clk, INF.bridge_inf inf);

//================================================================
// typedef 
//================================================================
typedef enum logic [2:0]{
    IDLE_D, // 0 
    READ_ADDR,  // 1
    READ_DATA, // 2
    WRITE_ADDR, // 3
    WRITE_DATA, //4
    RESPONSE, // 5
    OUT // 6
} state_dram;

//================================================================
// declaration 
//================================================================
state_dram n_state, c_state;
logic [63:0] data_tmp;
logic [7:0] addr_tmp;



//================================================================
// state 
//================================================================
    
always_ff@(posedge clk or negedge inf.rst_n) begin : STATE_SEQ
    if (!inf.rst_n) c_state <= IDLE_D;
    else            c_state <= n_state;
end

always_comb begin : STATE_COMB
    case (c_state)
        IDLE_D:begin
            if (inf.C_in_valid) begin
                n_state = (inf.C_r_wb) ? READ_ADDR : WRITE_ADDR;
            end else begin
                n_state = c_state;
            end
        end 
        READ_ADDR: begin
            if (inf.AR_READY) begin
                n_state = READ_DATA;
            end else begin
                n_state = c_state;
            end
        end
        READ_DATA: begin
            if (inf.R_VALID) begin
                n_state = OUT;
            end else begin
                n_state = c_state;
            end
        end
        WRITE_ADDR: begin
            if (inf.AW_READY) begin
                n_state = WRITE_DATA;
            end else begin
                n_state = c_state;
            end
        end
        WRITE_DATA:begin
            if (inf.W_READY) begin
                n_state = RESPONSE;
            end else begin
                n_state = c_state;
            end
        end
        RESPONSE: begin
            if (inf.B_VALID) begin
                n_state = OUT;
            end else begin
                n_state = c_state;
            end
        end
        OUT: begin
            n_state = IDLE_D;
        end
        default: begin n_state = c_state; end
    endcase
end

//================================================================
// logic 
//================================================================
always_ff @( posedge clk or negedge inf.rst_n) begin // data_tmp
    if (!inf.rst_n) begin
        data_tmp <= 64'd0;
    end
    else begin
        case (c_state)
            WRITE_ADDR: data_tmp <= inf.C_data_w;
            default: data_tmp <= data_tmp;
        endcase
    end
end

always_ff @( posedge clk or negedge inf.rst_n) begin // addr_tmp
    if (!inf.rst_n) begin
        addr_tmp <= 8'd0;
    end
    else begin
        case (c_state)
            IDLE_D: addr_tmp <= inf.C_addr;
            default: addr_tmp <= addr_tmp;
        endcase
    end
end


always_comb begin // AR_VALID
    case (c_state)
        READ_ADDR: inf.AR_VALID = 1'b1 ;
        default: inf.AR_VALID = 1'b0 ;
    endcase
end

always_comb begin // AR_ADDR
    case (c_state)
        READ_ADDR: inf.AR_ADDR = {1'b1,5'd0,addr_tmp,3'd0} ;
        default: inf.AR_ADDR = 8'b0 ;
    endcase
end

always_comb begin // R_READY
    case (c_state)
        READ_DATA: inf.R_READY = 1'b1 ;
        default: inf.R_READY = 1'b0 ;
    endcase
end

always_comb begin // AW_VALID
    case (c_state)
        WRITE_ADDR: inf.AW_VALID = 1'b1 ;
        default: inf.AW_VALID = 1'b0 ;
    endcase
end

always_comb begin // AW_ADDR
    case (c_state)
        WRITE_ADDR: inf.AW_ADDR = {1'b1,5'd0,addr_tmp,3'd0} ;
        default: inf.AW_ADDR = 8'b0 ;
    endcase
end

always_comb begin // W_VALID
    case (c_state)
        WRITE_DATA: inf.W_VALID = 1'b1 ;
        default: inf.W_VALID = 1'b0 ;
    endcase
end


always_comb begin // W_DATA
    case (c_state)
        WRITE_DATA: inf.W_DATA = data_tmp;
        default: inf.W_DATA = 64'b0 ;
    endcase
end

always_comb begin // B_READY
    case (c_state)
        WRITE_DATA,RESPONSE: inf.B_READY = 1'b1 ;
        default: inf.B_READY = 1'b0 ;
    endcase
end

always_comb begin // C_out_valid
    case (c_state)
        OUT: inf.C_out_valid = 1'b1 ;
        default: inf.C_out_valid = 1'b0 ;
    endcase
end


always_ff @(posedge clk or negedge inf.rst_n ) begin  // C_data_r
    if (!inf.rst_n) inf.C_data_r <= 64'b0;
    else  begin
        if (inf.R_VALID && inf.R_READY)  inf.C_data_r <= inf.R_DATA;
        else if (inf.B_VALID && inf.B_READY) inf.C_data_r <= 64'b0;
        else inf.C_data_r <= inf.C_data_r;
    end     
end

endmodule
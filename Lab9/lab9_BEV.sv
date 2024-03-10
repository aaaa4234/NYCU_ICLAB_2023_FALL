module BEV(input clk, INF.BEV_inf inf);
import usertype::*;
// This file contains the definition of several state machines used in the BEV (Beverage) System RTL design.
// The state machines are defined using SystemVerilog enumerated types.
// The state machines are:
// - state_t: used to represent the overall state of the BEV system
//
// Each enumerated type defines a set of named states that the corresponding process can be in.
typedef enum logic [1:0]{
    IDLE,
    MAKE_DRINK,
    SUPPLY,
    CHECK_DATE
} state_t;

typedef enum logic [1:0]{
    DONT_OUTPUT,
    CAN_OUTPUT
} state_out;


// REGISTERS
state_t state, nstate;
state_out STATE_out, next_STATE_out;
Date date_today;
Bev_Bal barr;
Bev_Bal barr_dram;
Bev_Type beverage;
Bev_Size size;
Barrel_No box;
logic [1:0] count_tea;
logic start;
logic [4:0] count_ran;
logic out_next, drink_end, first;
logic [12:0] big_black_tea, big_green_tea, big_milk, big_pineapple_juice;
assign big_black_tea = barr.black_tea + barr_dram.black_tea;
assign big_green_tea = barr.green_tea + barr_dram.green_tea;
assign big_milk = barr.milk + barr_dram.milk;
assign big_pineapple_juice = barr.pineapple_juice + barr_dram.pineapple_juice;

logic [9:0] black_tea_ml, green_tea_ml, milk_ml, pineapple_juice_ml;
logic [63:0] w_data_tmp;

logic [12:0] black_tea_minus, green_tea_minus, milk_minus, pineapple_juice_minus;
assign black_tea_minus = barr_dram.black_tea - black_tea_ml;
assign green_tea_minus = barr_dram.green_tea - green_tea_ml;
assign milk_minus = barr_dram.milk - milk_ml;
assign pineapple_juice_minus = barr_dram.pineapple_juice - pineapple_juice_ml;

logic expire;
assign expire = (date_today.M > barr_dram.M || (date_today.M == barr_dram.M && date_today.D > barr_dram.D)) ? 1'b1 : 1'b0;

logic overflow;
assign overflow = big_black_tea[12] | big_green_tea[12] | big_milk[12] | big_pineapple_juice[12];

logic not_enough;
assign not_enough = black_tea_minus[12] | green_tea_minus[12] | milk_minus[12] | pineapple_juice_minus[12];

logic expire_1, overflow_1, not_enough_1;
state_t state_1;

always_ff @( posedge clk or negedge inf.rst_n) begin // expire_1, overflow_1, not_enough_1
    if (!inf.rst_n) begin expire_1 <= 1'd0; overflow_1 <= 1'd0; not_enough_1 <= 1'd0; state_1 <= IDLE; end
    else begin expire_1 <= expire; overflow_1 <= overflow; not_enough_1 <= not_enough; state_1 <= state; end
end



always_ff @( posedge clk or negedge inf.rst_n) begin : OUT_FSM_SEQ
    if (!inf.rst_n) STATE_out <= DONT_OUTPUT;
    else STATE_out <= next_STATE_out;
end

always_comb begin
    case (STATE_out)
        DONT_OUTPUT:begin
            next_STATE_out = DONT_OUTPUT;
            case (state)
                MAKE_DRINK:begin
                    if ((out_next && inf.C_out_valid) || (out_next && !first && (expire || not_enough)))
                        next_STATE_out = CAN_OUTPUT;
                end
                SUPPLY: begin
                    if (out_next && inf.C_out_valid)
                        next_STATE_out = CAN_OUTPUT;
                end
                CHECK_DATE: begin
                    next_STATE_out = (out_next) ? CAN_OUTPUT : STATE_out;
                end 
                default: next_STATE_out = STATE_out;
            endcase
        end
        CAN_OUTPUT:begin
            next_STATE_out = DONT_OUTPUT;
        end 
        default: begin
            next_STATE_out = STATE_out;
        end
    endcase
end

// STATE MACHINE
always_ff @( posedge clk or negedge inf.rst_n) begin : TOP_FSM_SEQ
    if (!inf.rst_n) state <= IDLE;
    else state <= nstate;
end

always_comb begin : TOP_FSM_COMB
    case(state)
        IDLE: begin
            if (inf.sel_action_valid)
            begin
                case(inf.D.d_act[0])
                    Make_drink: nstate = MAKE_DRINK;
                    Supply: nstate = SUPPLY;
                    Check_Valid_Date: nstate = CHECK_DATE;
                    default: nstate = IDLE;
                endcase
            end
            else begin nstate = IDLE; end
        end
        MAKE_DRINK:begin
            if ((out_next && inf.C_out_valid) || (out_next && !first && (expire || not_enough)))
                nstate = IDLE;
            else
                nstate = state;
        end
        SUPPLY:begin
            if (out_next && inf.C_out_valid)
                nstate = IDLE;
            else
                nstate = state;
        end
        MAKE_DRINK,CHECK_DATE:begin
            if (inf.out_valid)
                nstate = IDLE;
            else
                nstate = state;
        end

        default: nstate = IDLE;
    endcase
end



always_comb begin  // 3 size to 4 tea ml  
    case (beverage)
        Black_Tea: begin 
            case (size)
                L: begin black_tea_ml = 10'd960; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd0; end 
                M: begin black_tea_ml = 10'd720; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd0; end
                S: begin black_tea_ml = 10'd480; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd0; end
                default: begin black_tea_ml = 10'd0; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd0; end
            endcase
        end    

        Milk_Tea: begin 
            case (size)
                L: begin black_tea_ml = 10'd720; green_tea_ml = 10'd0; milk_ml = 10'd240; pineapple_juice_ml = 10'd0; end 
                M: begin black_tea_ml = 10'd540; green_tea_ml = 10'd0; milk_ml = 10'd180; pineapple_juice_ml = 10'd0; end
                S: begin black_tea_ml = 10'd360; green_tea_ml = 10'd0; milk_ml = 10'd120; pineapple_juice_ml = 10'd0; end
                default: begin black_tea_ml = 10'd0; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd0; end
            endcase
        end  

        Extra_Milk_Tea: begin 
            case (size)
                L: begin black_tea_ml = 10'd480; green_tea_ml = 10'd0; milk_ml = 10'd480; pineapple_juice_ml = 10'd0; end 
                M: begin black_tea_ml = 10'd360; green_tea_ml = 10'd0; milk_ml = 10'd360; pineapple_juice_ml = 10'd0; end
                S: begin black_tea_ml = 10'd240; green_tea_ml = 10'd0; milk_ml = 10'd240; pineapple_juice_ml = 10'd0; end
                default: begin black_tea_ml = 10'd0; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd0; end
            endcase
        end  

        Green_Tea: begin 
            case (size)
                L: begin black_tea_ml = 10'd0; green_tea_ml = 10'd960; milk_ml = 10'd0; pineapple_juice_ml = 10'd0; end 
                M: begin black_tea_ml = 10'd0; green_tea_ml = 10'd720; milk_ml = 10'd0; pineapple_juice_ml = 10'd0; end
                S: begin black_tea_ml = 10'd0; green_tea_ml = 10'd480; milk_ml = 10'd0; pineapple_juice_ml = 10'd0; end
                default: begin black_tea_ml = 10'd0; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd0; end
            endcase
        end

        Green_Milk_Tea: begin 
            case (size)
                L: begin black_tea_ml = 10'd0; green_tea_ml = 10'd480; milk_ml = 10'd480; pineapple_juice_ml = 10'd0; end 
                M: begin black_tea_ml = 10'd0; green_tea_ml = 10'd360; milk_ml = 10'd360; pineapple_juice_ml = 10'd0; end
                S: begin black_tea_ml = 10'd0; green_tea_ml = 10'd240; milk_ml = 10'd240; pineapple_juice_ml = 10'd0; end
                default: begin black_tea_ml = 10'd0; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd0; end
            endcase
        end

        Pineapple_Juice: begin 
            case (size)
                L: begin black_tea_ml = 10'd0; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd960; end 
                M: begin black_tea_ml = 10'd0; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd720; end
                S: begin black_tea_ml = 10'd0; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd480; end
                default: begin black_tea_ml = 10'd0; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd0; end
            endcase
        end

        Super_Pineapple_Tea: begin 
            case (size)
                L: begin black_tea_ml = 10'd480; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd480; end 
                M: begin black_tea_ml = 10'd360; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd360; end
                S: begin black_tea_ml = 10'd240; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd240; end
                default: begin black_tea_ml = 10'd0; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd0; end
            endcase
        end

        Super_Pineapple_Milk_Tea: begin 
            case (size)
                L: begin black_tea_ml = 10'd480; green_tea_ml = 10'd0; milk_ml = 10'd240; pineapple_juice_ml = 10'd240; end 
                M: begin black_tea_ml = 10'd360; green_tea_ml = 10'd0; milk_ml = 10'd180; pineapple_juice_ml = 10'd180; end
                S: begin black_tea_ml = 10'd240; green_tea_ml = 10'd0; milk_ml = 10'd120; pineapple_juice_ml = 10'd120; end
                default: begin black_tea_ml = 10'd0; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd0; end
            endcase
        end  
        default: begin black_tea_ml = 10'd0; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd0; end
    endcase
end





//================================================================
// Register 
//================================================================

//                0           1              2              3              4            5         6
// make drink:  action |   bev type  |    bev size    | today date | no.ing in dram |   x   |     x     |
//     supply:  action | expire date | no.ing in dram | black tea  |    green tea   |  milk | pineapple |
// check date:  action |  today date | no.ing in dram |     x      |       x        |   x   |     x     |

always_ff @( posedge clk or negedge inf.rst_n) begin  // count_ran 
    if (!inf.rst_n) count_ran <= 5'd0;
    else begin
        case (state)
            MAKE_DRINK: count_ran <= count_ran + 1'b1;
            default: count_ran <= 5'd0;
        endcase
    end  
end

always_ff @( posedge clk or negedge inf.rst_n) begin  // out_next
    if (!inf.rst_n) out_next <= 1'd0;
    else begin
        case (state)
            MAKE_DRINK,SUPPLY,CHECK_DATE: begin
                if (inf.C_out_valid)
                    out_next <= 1'd1;
            end 
            default: out_next <= 1'd0;
        endcase
    end  
end

always_ff @( posedge clk or negedge inf.rst_n) begin  // drink_end
    if (!inf.rst_n) drink_end <= 1'd0;
    else begin
        case (state)
            SUPPLY:  begin
                if (count_tea == 2'd3 && inf.box_sup_valid)
                    drink_end <= 1'd1;  
            end 
            default: drink_end <= 1'd0;
        endcase
    end  
end

always_ff @( posedge clk or negedge inf.rst_n) begin  // first
    if (!inf.rst_n) first <= 1'd0;
    else begin
        case (state)
            MAKE_DRINK: begin
                if (out_next)
                    first <= 1'd1;
            end
            SUPPLY:  begin
                if (drink_end && out_next)
                    first <= 1'd1;  
            end 
            default: first <= 1'd0;
        endcase
    end  
end

always_ff @( posedge clk or negedge inf.rst_n) begin  // count_tea 
    if (!inf.rst_n) count_tea <= 2'd0;
    else begin
        if (inf.box_sup_valid) begin
            count_tea <= count_tea + 1'b1;
        end 
        else if (inf.out_valid) begin
            count_tea <= 2'd0;
        end
        else begin
            count_tea <= count_tea;
        end
    end  
end


always_ff @( posedge clk or negedge inf.rst_n) begin  // date_today
    if (!inf.rst_n) begin 
        date_today.M <= 4'd0;  date_today.D <= 5'd0; 
    end
    else begin
        case (state)
            MAKE_DRINK,CHECK_DATE: begin
                if (inf.date_valid) begin
                    date_today.M <= inf.D.d_date[0].M;
                    date_today.D <= inf.D.d_date[0].D;
                end
            end 
            default: begin date_today.M <= 4'd0;  date_today.D <= 5'd0; end
        endcase
    end
end


always_ff @( posedge clk or negedge inf.rst_n) begin  // beverage type
    if (!inf.rst_n) begin 
        beverage <= Black_Tea; 
    end
    else begin
        case (state)
            MAKE_DRINK: begin
                if (inf.type_valid) begin
                     beverage <= inf.D.d_type[0];
                end
            end 
            default: begin beverage <= Black_Tea; end
        endcase
    end
end

always_ff @( posedge clk or negedge inf.rst_n) begin  // size
    if (!inf.rst_n) begin 
        size <= L; 
    end
    else begin
        case (state)
            MAKE_DRINK: begin
                if (inf.size_valid) begin
                     size <= inf.D.d_size[0];
                end
            end 
            default: begin size <= L; end
        endcase
    end
end



always_ff @( posedge clk or negedge inf.rst_n) begin  // box
    if (!inf.rst_n) begin 
        box <= 8'd0; 
    end
    else begin
        case (state)
            MAKE_DRINK,SUPPLY,CHECK_DATE: begin
                if (inf.box_no_valid) begin
                    box <= inf.D.d_box_no[0];
                end
            end 
            default: begin box <= 8'd0;  end
        endcase
    end
end


always_ff @( posedge clk or negedge inf.rst_n) begin  // barrel
    if (!inf.rst_n) begin 
        barr.black_tea <= 12'd0; 
        barr.green_tea <= 12'd0;
        barr.milk <= 12'd0;
        barr.pineapple_juice <= 12'd0;
        barr.M <= 4'd0;
        barr.D <= 5'd0;
    end
    else begin
        case (state)
            SUPPLY: begin
                if (inf.date_valid) begin
                    barr.M <= inf.D.d_date[0].M;
                    barr.D <= inf.D.d_date[0].D;
                end

                if (inf.box_sup_valid) begin
                    case (count_tea)
                        0:  barr.black_tea <= inf.D.d_ing;
                        1:  barr.green_tea <= inf.D.d_ing;
                        2:  barr.milk <= inf.D.d_ing;
                        3:  barr.pineapple_juice <= inf.D.d_ing;
                        default: begin end
                    endcase
                end
            end 
            default: begin 
                barr.black_tea <= 12'd0; 
                barr.green_tea <= 12'd0;
                barr.milk <= 12'd0;
                barr.pineapple_juice <= 12'd0;
                barr.M <= 4'd0;
                barr.D <= 5'd0;
            end
        endcase
    end
end

always_ff @( posedge clk or negedge inf.rst_n) begin  // barr_dram
    if (!inf.rst_n) begin 
        barr_dram.black_tea <= 12'd0; 
        barr_dram.green_tea <= 12'd0;
        barr_dram.milk <= 12'd0;
        barr_dram.pineapple_juice <= 12'd0;
        barr_dram.M <= 4'd0;
        barr_dram.D <= 5'd0;
    end
    else begin
        case (state)
            MAKE_DRINK,SUPPLY,CHECK_DATE: begin
                if (inf.C_out_valid) begin
                    barr_dram.black_tea <= inf.C_data_r[63:52]; 
                    barr_dram.green_tea <= inf.C_data_r[51:40];
                    barr_dram.M <= inf.C_data_r[39:32];
                    barr_dram.milk <= inf.C_data_r[31:20];
                    barr_dram.pineapple_juice <= inf.C_data_r[19:8];
                    barr_dram.D <= inf.C_data_r[7:0];
                end
            end 
            default: begin 
                barr_dram.black_tea <= 12'd0; 
                barr_dram.green_tea <= 12'd0;
                barr_dram.milk <= 12'd0;
                barr_dram.pineapple_juice <= 12'd0;
                barr_dram.M <= 4'd0;
                barr_dram.D <= 5'd0;
            end
        endcase
    end
end


//================================================================
// AXI 
//================================================================

always_ff @( posedge clk or negedge inf.rst_n)  begin // C_in_valid
    if (!inf.rst_n) inf.C_in_valid <= 1'd0;
    else begin
        case (state)
            MAKE_DRINK:begin
                if (inf.box_no_valid || (out_next && !first && !expire && !not_enough))
                    inf.C_in_valid <= 1'b1;  
                else 
                    inf.C_in_valid <= 1'b0;
            end
            SUPPLY:begin
                if (inf.box_no_valid || (out_next && drink_end && !first))
                    inf.C_in_valid <= 1'b1;  
                else 
                    inf.C_in_valid <= 1'b0;        
            end
            SUPPLY,CHECK_DATE: begin
                inf.C_in_valid <= (inf.box_no_valid) ? 1'b1 : 1'd0;
            end
            default: begin
                inf.C_in_valid <= 1'd0;
            end
        endcase
    end
end

always_comb  begin // C_r_wb
    case (state)
        MAKE_DRINK: begin
            if (inf.C_in_valid) begin
                inf.C_r_wb = (out_next) ? 1'b0 : 1'b1;
            end
            else begin
                inf.C_r_wb = 1'b1;
            end
        end 
        SUPPLY: begin
            if (inf.C_in_valid) begin
                inf.C_r_wb = (out_next) ? 1'b0 : 1'b1;
            end
            else begin
                inf.C_r_wb = 1'b1;
            end
        end 
        CHECK_DATE: begin
            inf.C_r_wb = 1'b1;
        end
        default: begin
            inf.C_r_wb = 1'd1;
        end
    endcase
end


always_comb  begin // C_addr
    case (state)
        MAKE_DRINK,SUPPLY,CHECK_DATE: begin inf.C_addr = box; end
        default: begin inf.C_addr = 8'd0; end
    endcase
end


always_comb  begin // C_data_w
    case (state)
        MAKE_DRINK:begin
            if (out_next) begin
                inf.C_data_w[63:52] = black_tea_minus[11:0];
                inf.C_data_w[51:40] = green_tea_minus[11:0];
                inf.C_data_w[39:32] = barr_dram.M;
                inf.C_data_w[31:20] = milk_minus[11:0];
                inf.C_data_w[19:8] = pineapple_juice_minus[11:0];
                inf.C_data_w[7:0] = barr_dram.D;
            end 
            else begin
                inf.C_data_w = 64'd0;
            end
        end
        SUPPLY: begin 
            if (out_next && drink_end) begin
                inf.C_data_w[63:52] = (big_black_tea[12]) ? 12'hfff : big_black_tea[11:0];
                inf.C_data_w[51:40] = (big_green_tea[12]) ? 12'hfff : big_green_tea[11:0];
                inf.C_data_w[39:32] = barr.M;
                inf.C_data_w[31:20] = (big_milk[12]) ? 12'hfff : big_milk[11:0];
                inf.C_data_w[19:8] = (big_pineapple_juice[12]) ? 12'hfff : big_pineapple_juice[11:0];
                inf.C_data_w[7:0] = barr.D;
            end 
            else begin
                inf.C_data_w = 64'd0;
            end
        end
        default: begin inf.C_data_w = 64'd0; end
    endcase
end



//================================================================
// Out 
//================================================================

always_comb begin // out_valid
    case (STATE_out)
        CAN_OUTPUT: begin inf.out_valid = 1'd1; end 
        default: begin inf.out_valid = 1'd0; end
    endcase
end



// always_ff @( posedge clk or negedge inf.rst_n) begin // out_valid
//     if (!inf.rst_n) begin
//         inf.out_valid <= 1'd0;
//     end
//     else begin
//         case (STATE_out)
//             CAN_OUTPUT: begin inf.out_valid <= 1'd0; end 
//             default: 
//         endcase

//         case (state)
//             MAKE_DRINK:begin
//                 if ((out_next && inf.C_out_valid) || (out_next && !first && (expire || not_enough)))
//                     inf.out_valid <= 1'b1;
//                 else
//                     inf.out_valid <= 1'b0;
//             end
//             SUPPLY: begin
//                 if (out_next && inf.C_out_valid) begin
//                     inf.out_valid <= 1'b1;
//                 end
//                 else begin
//                     inf.out_valid <= 1'b0;
//                 end
//             end
//             CHECK_DATE: inf.out_valid <= out_next;
//             default: inf.out_valid <= 1'd0;
//         endcase
//     end
// end

always_comb begin // complete
    if (!inf.rst_n) inf.complete = 1'd0;
    else begin 
        if (inf.out_valid && inf.err_msg == No_Err)
            inf.complete = 1'd1;
        else 
            inf.complete = 1'd0;    
    end
end

always_comb begin // err_msg
    if (!inf.rst_n) inf.err_msg = No_Err;
    else begin
        if (inf.out_valid) begin
            case (state_1)
                MAKE_DRINK: begin
                    // if (date_today.M > barr_dram.M) begin
                    if (expire_1) begin     
                        inf.err_msg = No_Exp;
                    end
                    // else if (date_today.M == barr_dram.M && date_today.D > barr_dram.D) begin
                        // inf.err_msg = No_Exp;
                    // end
                    else if (not_enough_1) begin
                        inf.err_msg = No_Ing;
                    end
                    else begin
                        inf.err_msg =  No_Err;
                    end
                end
                SUPPLY:begin
                    //if (big_black_tea[12] || big_green_tea[12] || big_milk[12] || big_pineapple_juice[12])
                    if (overflow_1)
                        inf.err_msg =  Ing_OF;
                    else 
                        inf.err_msg =  No_Err;
                end
                CHECK_DATE:begin
                    // if (date_today.M > barr_dram.M) begin
                    if (expire_1) begin    
                        inf.err_msg = No_Exp;
                    end
                    // else if (date_today.M == barr_dram.M && date_today.D > barr_dram.D) begin
                        // inf.err_msg = No_Exp;
                    // end
                    else begin
                        inf.err_msg =  No_Err;
                    end
                end
                default: inf.err_msg = No_Err;
            endcase
        end
        else begin
            inf.err_msg = No_Err;
        end

    end    
end

endmodule
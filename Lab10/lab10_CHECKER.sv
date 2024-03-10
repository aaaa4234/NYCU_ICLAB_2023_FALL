/*
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
NYCU Institute of Electronic
2023 Autumn IC Design Laboratory 
Lab10: SystemVerilog Coverage & Assertion
File Name   : CHECKER.sv
Module Name : CHECKER
Release version : v1.0 (Release Date: Nov-2023)
Author : Jui-Huang Tsai (erictsai.10@nycu.edu.tw)
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
*/

`include "Usertype_BEV.sv"
module Checker(input clk, INF.CHECKER inf);
import usertype::*;

integer latency, total_latency;


/*
    Coverage Part
*/


class BEV;
    Bev_Type bev_type;
    Bev_Size bev_size;
endclass

BEV bev_info = new();
Action act;
logic [1:0] count_supply;



always_ff @(posedge clk) begin
    if (inf.type_valid) begin
        bev_info.bev_type = inf.D.d_type[0];
    end
end

always_ff @(posedge clk) begin
    if (inf.size_valid) begin
        bev_info.bev_size = inf.D.d_size[0];
    end
end

always_ff@(posedge clk)begin
    if(inf.sel_action_valid) begin
        act = inf.D.d_act[0];
    end
end

always_ff@(posedge clk, negedge inf.rst_n)begin
    if (!inf.rst_n)
        count_supply <= 1'd0;
    else if(inf.box_sup_valid) begin
        count_supply <= count_supply + 1'b1;
    end
end

/*
1. Each case of Beverage_Type should be select at least 100 times.
*/

covergroup Spec1 @(posedge clk iff(inf.type_valid));
    option.per_instance = 1;
    option.at_least = 100;
    btype:coverpoint bev_info.bev_type{
        bins b_bev_type [] = {[Black_Tea:Super_Pineapple_Milk_Tea]};
    }
endgroup


/*
2.	Each case of Bererage_Size should be select at least 100 times.
*/

covergroup Spec2 @(posedge clk iff(inf.size_valid));
    option.per_instance = 1;
    option.at_least = 100;
    btype:coverpoint bev_info.bev_size{
        bins b_bev_size [] = {[L:S]};
    }
endgroup

/*
3.	Create a cross bin for the SPEC1 and SPEC2. Each combination should be selected at least 100 times. 
(Black Tea, Milk Tea, Extra Milk Tea, Green Tea, Green Milk Tea, Pineapple Juice, Super Pineapple Tea, Super Pineapple Tea) x (L, M, S)
*/

covergroup Spec3 @(posedge clk   iff(inf.size_valid));
    option.per_instance = 1;
    option.at_least = 100;
    coverpoint bev_info.bev_type;
    coverpoint bev_info.bev_size;
    cross bev_info.bev_type, bev_info.bev_size;
endgroup

/*
4.	Output signal inf.err_msg should be No_Err, No_Exp, No_Ing and Ing_OF, each at least 20 times. (Sample the value when inf.out_valid is high)
*/

covergroup Spec4 @(posedge clk   iff(inf.out_valid));
    option.per_instance = 1;
    option.at_least = 20;
    berrmsg: coverpoint inf.err_msg{
        bins b_errmsg [] = {[No_Err:Ing_OF]};
    }
endgroup

/*
5.	Create the transitions bin for the inf.D.act[0] signal from [0:2] to [0:2]. Each transition should be hit at least 200 times. (sample the value at posedge clk iff inf.sel_action_valid)
*/

covergroup Spec5 @(posedge clk   iff(inf.sel_action_valid));
    option.per_instance = 1;
    option.at_least = 200;
    baction: coverpoint inf.D.d_act[0]{
        bins b_action [] = ([Make_drink:Check_Valid_Date] => [Make_drink:Check_Valid_Date]);
    }
endgroup

/*
6.	Create a covergroup for material of supply action with auto_bin_max = 32, and each bin have to hit at least one time.
*/

covergroup Spec6 @(posedge clk   iff(inf.box_sup_valid));
    option.per_instance = 1;
    option.at_least = 1;
    bsupply: coverpoint inf.D.d_ing[0]{
        option.auto_bin_max = 32;
    }
endgroup

/*
    Create instances of Spec1, Spec2, Spec3, Spec4, Spec5, and Spec6
*/
Spec1 cov_1 = new();
Spec2 cov_2 = new();
Spec3 cov_3 = new();
Spec4 cov_4 = new();
Spec5 cov_5 = new();
Spec6 cov_6 = new();


/*
    Asseration
*/

/*
    If you need, you can declare some FSM, logic, flag, and etc. here.
*/

/*
    1. All outputs signals (including BEV.sv and bridge.sv) should be zero after reset.
*/
wire #(0.5) rst_reg = inf.rst_n;
reset_up: assert property (@(negedge rst_reg)
        ///// C_controll
        inf.C_addr === 'd0 && 
        inf.C_r_wb === 'd0 && 
        inf.C_in_valid === 'd0 && 
        inf.C_data_w === 'd0 && 
        inf.C_out_valid === 'd0 && 
        inf.C_data_r === 'd0 && 

        ///// output signal
        inf.out_valid === 'd0 && 
        inf.complete === 'd0 && 
        inf.err_msg === No_Err && 

        ///// Read address
        inf.AR_VALID === 'd0 && 
        inf.AR_ADDR === 'd0 && 
        inf.R_READY === 'd0 && 

        ///// Write address
        inf.AW_VALID === 'd0 && 
        inf.AW_ADDR === 'd0 && 
        inf.W_VALID === 'd0 && 
        inf.W_DATA === 'd0 && 
        inf.B_READY === 'd0)
else begin
    $display(" Assertion 1 is violated ");
    $fatal; 
end

/*
    2.	Latency should be less than 1000 cycles for each operation.
*/

latency_so_long : assert property(long_lat)
else begin
    $display(" Assertion 2 is violated ");
    $fatal; 
end

property long_lat;
    @(negedge clk) (make_lat or supply_lat or check_lat);
endproperty

property make_lat;
    @(negedge clk) (inf.box_no_valid && (act === Make_drink)) |-> (##[1:1000] inf.out_valid);
endproperty

property supply_lat;
    @(negedge clk) (count_supply === 3 && inf.box_sup_valid && act === Supply) |-> (##[1:1000] inf.out_valid);
endproperty

property check_lat;
    @(negedge clk) (inf.box_no_valid && act === Check_Valid_Date) |-> (##[1:1000] inf.out_valid);
endproperty

/*
    3. If out_valid does not pull up, complete should be 0.
*/

check_complete : assert property(check_complete_noerr) 
else begin
    $display("Assertion 3 is violated");
    $fatal;
end


property check_complete_noerr;
       @(negedge clk)  (inf.out_valid === 1 && inf.complete === 1) |-> inf.err_msg === No_Err;
endproperty



/*
    4. Next input valid will be valid 1-4 cycles after previous input valid fall.
*/

///Make drink
act_to_type: assert property  
    (@(posedge clk) (inf.D.d_act[0] == Make_drink && inf.sel_action_valid)  |=> ##[0:3] inf.type_valid === 1)
else begin
    $display(" Assertion 4 is violated ");
    $fatal; 
end

type_to_size: assert property  
    (@(posedge clk) (act == Make_drink && inf.type_valid)  |=> ##[0:3] inf.size_valid === 1)
else begin
    $display(" Assertion 4 is violated ");
    $fatal; 
end

size_to_date: assert property  
    (@(posedge clk) (act == Make_drink && inf.size_valid)  |=> ##[0:3] inf.date_valid === 1)
else begin
    $display(" Assertion 4 is violated ");
    $fatal; 
end

date_to_box: assert property  
    (@(posedge clk) (act == Make_drink && inf.date_valid)  |=> ##[0:3] inf.box_no_valid === 1)
else begin
    $display(" Assertion 4 is violated ");
    $fatal; 
end

////Supply
act_to_date: assert property  
    (@(posedge clk) (inf.D.d_act[0] == Supply && inf.sel_action_valid)  |=> ##[0:3] inf.date_valid === 1)
else begin
    $display(" Assertion 4 is violated ");
    $fatal; 
end

date_to_box_s: assert property  
    (@(posedge clk) (act == Supply && inf.date_valid)  |=> ##[0:3] inf.box_no_valid === 1)
else begin
    $display(" Assertion 4 is violated ");
    $fatal; 
end

box_to_ing_first: assert property  
    (@(posedge clk) (act == Supply && inf.box_no_valid)  |=> ##[0:3] (inf.box_sup_valid === 1))
else begin
    $display(" Assertion 4 is violated ");
    $fatal; 
end

ing_to_ing_1_2: assert property  
    (@(posedge clk) (act == Supply && inf.box_sup_valid && count_supply != 3)  |=> ##[0:3] (inf.box_sup_valid === 1))
else begin
    $display(" Assertion 4 is violated ");
    $fatal; 
end

//////Check 
act_to_date_check: assert property  
    (@(posedge clk) (inf.D.d_act[0] == Check_Valid_Date && inf.sel_action_valid)  |=> ##[0:3] inf.date_valid === 1)
else begin
    $display(" Assertion 4 is violated ");
    $fatal; 
end

date_to_box_check: assert property  
    (@(posedge clk) (act == Check_Valid_Date && inf.date_valid)  |=> ##[0:3] inf.box_no_valid === 1)
else begin
    $display(" Assertion 4 is violated ");
    $fatal; 
end


/*
    5. All input valid signals won't overlap with each other. 
*/

logic [2:0] sum_valid;
assign sum_valid = inf.sel_action_valid + inf.date_valid + inf.box_no_valid + inf.box_sup_valid + inf.type_valid + inf.size_valid;
valid_overlap_check: assert property  
    (@(posedge clk) (sum_valid === 0 || sum_valid === 1))
else begin
    $display(" Assertion 5 is violated ");
    $fatal; 
end


/*
    6. Out_valid can only be high for exactly one cycle.
*/

outvalid_for_1: assert property  
    (@(posedge clk) (inf.out_valid === 1)  |=> (inf.out_valid === 0))
else begin
    $display(" Assertion 6 is violated ");
    $fatal; 
end

/*
    7. Next operation will be valid 1-4 cycles after out_valid fall.
*/

next_operation: assert property  
    (@(posedge clk) (inf.out_valid === 1)  |=> ##[0:3] inf.sel_action_valid === 1)
else begin
    $display(" Assertion 7 is violated ");
    $fatal; 
end

/*
    8. The input date from pattern should adhere to the real calendar. (ex: 2/29, 3/0, 4/31, 13/1 are illegal cases)
*/

check_date: assert property  
    (@(posedge clk) (inf.date_valid == 1)  |-> is_a_date)
else begin
    $display(" Assertion 8 is violated ");
    $fatal; 
end


property is_a_date;
    @(posedge clk) (mon_in_1_12 and (mon1 or mon2 or mon3 or mon4 or mon5 or mon6 or mon7 or mon8 or mon9 or mon10 or mon11 or mon12));
endproperty

property mon_in_1_12;
    @(posedge clk) ((inf.D.d_date[0].M >= 1 && inf.D.d_date[0].M <= 12));
endproperty

property mon1;
    @(posedge clk) (inf.D.d_date[0].M == 1 && (inf.D.d_date[0].D >= 1 && inf.D.d_date[0].D <= 31));
endproperty

property mon2;
    @(posedge clk) (inf.D.d_date[0].M == 2 && (inf.D.d_date[0].D >= 1 && inf.D.d_date[0].D <= 28));
endproperty

property mon3;
    @(posedge clk) (inf.D.d_date[0].M == 3 && (inf.D.d_date[0].D >= 1 && inf.D.d_date[0].D <= 31));
endproperty

property mon4;
    @(posedge clk) (inf.D.d_date[0].M == 4 && (inf.D.d_date[0].D >= 1 && inf.D.d_date[0].D <= 30));
endproperty

property mon5;
    @(posedge clk) (inf.D.d_date[0].M == 5 && (inf.D.d_date[0].D >= 1 && inf.D.d_date[0].D <= 31));
endproperty

property mon6;
    @(posedge clk) (inf.D.d_date[0].M == 6 && (inf.D.d_date[0].D >= 1 && inf.D.d_date[0].D <= 30));
endproperty

property mon7;
    @(posedge clk) (inf.D.d_date[0].M == 7 && (inf.D.d_date[0].D >= 1 && inf.D.d_date[0].D <= 31));
endproperty

property mon8;
    @(posedge clk) (inf.D.d_date[0].M == 8 && (inf.D.d_date[0].D >= 1 && inf.D.d_date[0].D <= 31));
endproperty

property mon9;
    @(posedge clk) (inf.D.d_date[0].M == 9 && (inf.D.d_date[0].D >= 1 && inf.D.d_date[0].D <= 30));
endproperty

property mon10;
    @(posedge clk) (inf.D.d_date[0].M == 10 && (inf.D.d_date[0].D >= 1 && inf.D.d_date[0].D <= 31));
endproperty

property mon11;
    @(posedge clk) (inf.D.d_date[0].M == 11 && (inf.D.d_date[0].D >= 1 && inf.D.d_date[0].D <= 30));
endproperty

property mon12;
    @(posedge clk) (inf.D.d_date[0].M == 12 && (inf.D.d_date[0].D >= 1 && inf.D.d_date[0].D <= 31));
endproperty


/*
    9. C_in_valid can only be high for one cycle and can't be pulled high again before C_out_valid
*/

logic wait_c_out_valid;
always_ff @(posedge clk, negedge inf.rst_n)begin
    if (!inf.rst_n)
        wait_c_out_valid <= 0;
    else if (inf.C_in_valid)    
        wait_c_out_valid <= 1;
    else if (inf.C_out_valid)    
        wait_c_out_valid <= 0;
end

property c_in_valid_1;
    @(posedge clk) (inf.C_in_valid === 1) |=> inf.C_in_valid === 0;
endproperty

property cant_pull_C_in_valid;
    @(posedge clk) wait_c_out_valid === 1 |-> inf.C_in_valid === 0;
endproperty

property good_c_in_valid;
    @(posedge clk) (c_in_valid_1 or cant_pull_C_in_valid);
endproperty

check_C_in_valid: assert property  (good_c_in_valid)
else begin
    $display(" Assertion 9 is violated ");
    $fatal; 
end

endmodule

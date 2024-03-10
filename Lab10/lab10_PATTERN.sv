/*
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
NYCU Institute of Electronic
2023 Autumn IC Design Laboratory 
Lab09: SystemVerilog Design and Verification 
File Name   : PATTERN.sv
Module Name : PATTERN
Release version : v1.0 (Release Date: Nov-2023)
Author : Jui-Huang Tsai (erictsai.10@nycu.edu.tw)
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
*/

`include "Usertype_BEV.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;

//================================================================
// parameters & integer
//================================================================
parameter DRAM_p_r = "../00_TESTBED/DRAM/dram.dat";
parameter PATNUM = 10000;
parameter seed = 587;

integer pat, out_cycle;
integer latency, total_latency;
integer i, t;



//================================================================
// wire & registers 
//================================================================

//logic [15:0] aaa [1:5]; // a[1] ~ a[5] : 16bit

logic [7:0] golden_DRAM [((65536+8*256)-1):(65536+0)];  // 256 box
logic golden_complete;
Error_Msg golden_message;
logic [7:0] box_number;
logic [9:0] total_bev_mole;
logic [9:0] black_tea_ml, green_tea_ml, milk_ml, pineapple_juice_ml;
ING supply_mole[0:3];
Bev_Bal ingredient_box;
Action accc;
Date today_date;
logic expire, not_enough, too_many;

// assign expire = today_date.M > ingredient_box.M || (today_date.M == ingredient_box.M && today_date.D > ingredient_box.D);
// assign not_enough = black_tea_ml > ingredient_box.black_tea || green_tea_ml > ingredient_box.green_tea || milk_ml > ingredient_box.milk || pineapple_juice_ml > ingredient_box.pineapple_juice;
// assign too_many = supply_mole[0] + ingredient_box.black_tea > 4095 || supply_mole[1] + ingredient_box.green_tea > 4095 || supply_mole[2] + ingredient_box.milk > 4095 || supply_mole[3] + ingredient_box.pineapple_juice > 4095;

// assign ingredient_box.black_tea       = {golden_DRAM[(65536 + 8*box_number + 7)] , golden_DRAM[(65536 + 8*box_number + 6)][7:4]};
// assign ingredient_box.green_tea       = {golden_DRAM[(65536 + 8*box_number + 6)][3:0] , golden_DRAM[(65536 + 8*box_number + 5)]};
// assign ingredient_box.M               =  golden_DRAM[(65536 + 8*box_number + 4)];
// assign ingredient_box.milk            = {golden_DRAM[(65536 + 8*box_number + 3)] , golden_DRAM[(65536 + 8*box_number + 2)][7:4]};
// assign ingredient_box.pineapple_juice = {golden_DRAM[(65536 + 8*box_number + 2)][3:0] , golden_DRAM[(65536 + 8*box_number + 1)]};
// assign ingredient_box.D               =  golden_DRAM[(65536 + 8*box_number + 0)];



//================================================================
// class random
//================================================================
class random_act;
    function new (int seed);
      this.srandom(seed);
    endfunction
    rand Action act;

    constraint limit {
      act inside {Make_drink,Supply,Check_Valid_Date};
    }
endclass

class random_type;
    function new (int seed);
      this.srandom(seed);
    endfunction
    rand Bev_Type type1;

    constraint limit {
      type1 inside {Black_Tea,Milk_Tea,Extra_Milk_Tea,Green_Tea,Green_Milk_Tea,Pineapple_Juice,Super_Pineapple_Tea,Super_Pineapple_Milk_Tea};
    }
endclass

class random_size;
    function new (int seed);
      this.srandom(seed);
    endfunction
    randc Bev_Size size;

    constraint limit {
      size inside {L,M,S};
    }
endclass

class random_date;
    function new (int seed);
      this.srandom(seed);
    endfunction
    rand Date date;

    constraint limit {
      date.M inside {[1:12]};
      (date.M == 1)  -> date.D inside {[1:31]};
      (date.M == 2)  -> date.D inside {[1:28]};
      (date.M == 3)  -> date.D inside {[1:31]};
      (date.M == 4)  -> date.D inside {[1:30]};
      (date.M == 5)  -> date.D inside {[1:31]};
      (date.M == 6)  -> date.D inside {[1:30]};
      (date.M == 7)  -> date.D inside {[1:31]};
      (date.M == 8)  -> date.D inside {[1:31]};
      (date.M == 9)  -> date.D inside {[1:30]};
      (date.M == 10) -> date.D inside {[1:31]};
      (date.M == 11) -> date.D inside {[1:30]};
      (date.M == 12) -> date.D inside {[1:31]};
    }
endclass

class random_barrel_no;
    function new (int seed);
      this.srandom(seed);
    endfunction
    rand Barrel_No num;

    constraint limit {
      num inside {[0:255]};
    }
endclass

class random_ing_ml;
    function new (int seed);
      this.srandom(seed);
    endfunction
    rand ING howmuch;

    constraint limit {
      howmuch inside {[0:4095]};
    }
endclass


//================================================================
// class declare
//================================================================
random_act        rand_act    = new(seed);
random_type       rand_type   = new(seed);
random_size       rand_size   = new(seed);
random_date       rand_date   = new(seed);
random_barrel_no  rand_no     = new(seed);
random_ing_ml     rand_ml     = new(seed);


//================================================================
// initial
//================================================================
initial
  begin
    reset_signal_task;
    $readmemh (DRAM_p_r, golden_DRAM);

    for (pat=0 ; pat<PATNUM ; pat=pat+1) begin
        input_task;
        //calculate_ans;
        give_ingredient;
        wait_out_valid_task;
        check_ans;
        update_dram;
    end
    YOU_PASS_task;
  end



//================================================================
// task
//================================================================

task  reset_signal_task;
  inf.rst_n            = 1;
  inf.sel_action_valid = 0;
  inf.type_valid       = 0;
  inf.size_valid       = 0;
  inf.date_valid       = 0;
  inf.box_no_valid     = 0;
  inf.box_sup_valid    = 0;
  inf.D                = 'dx;
  total_latency        = 0;

  #(10) inf.rst_n = 0;
  #(10) inf.rst_n = 1;

   if (inf.out_valid !== 0 || inf.complete !== 0 || inf.err_msg !== No_Err)
      begin 
        FAIL_task_1;
        repeat(3) #(10);
        $finish;
      end
endtask 

task input_task;
  begin
    rand_act.randomize();
    rand_type.randomize();
    rand_size.randomize();
    rand_date.randomize();
    rand_no.randomize();
    rand_ml.randomize();

    @(negedge clk);
    inf.sel_action_valid = 1'b1;
    inf.D.d_act[0] = rand_act.act;
    accc = rand_act.act;


    if (rand_act.act == Make_drink) begin
      @(negedge clk);
      inf.sel_action_valid = 1'b0;
      inf.D = 'dx;
      t = $urandom_range(0, 3);
      repeat(t) @(negedge clk);
      inf.type_valid = 1'b1;
      inf.D.d_type[0] = rand_type.type1;

      @(negedge clk);
      inf.type_valid = 1'b0;
      inf.D = 'dx;
      t = $urandom_range(0, 3);
      repeat(t) @(negedge clk);
      inf.size_valid = 1'b1;
      inf.D.d_size[0] = rand_size.size;

      @(negedge clk);
      inf.size_valid = 1'b0;
      inf.D = 'dx;
      t = $urandom_range(0, 3);
      repeat(t) @(negedge clk);
      inf.date_valid = 1'b1;
      inf.D.d_date[0].M = rand_date.date.M;
      inf.D.d_date[0].D = rand_date.date.D;
      today_date.M = rand_date.date.M;
      today_date.D = rand_date.date.D;

      @(negedge clk);
      inf.date_valid = 1'b0;
      inf.D = 'dx;
      t = $urandom_range(0, 3);
      repeat(t) @(negedge clk);
      inf.box_no_valid = 1'b1;
      box_number = rand_no.num;
      inf.D.d_box_no[0] = rand_no.num;

      @(negedge clk);
      inf.box_no_valid = 1'b0;
      inf.D = 'dx;
    end

    else if (rand_act.act == Supply) begin
      @(negedge clk);
      inf.sel_action_valid = 1'b0;
      inf.D = 'dx;
      t = $urandom_range(0, 3);
      repeat(t) @(negedge clk);
      inf.date_valid = 1'b1;
      inf.D.d_date[0].M = rand_date.date.M;
      inf.D.d_date[0].D = rand_date.date.D;
      today_date.M = rand_date.date.M;
      today_date.D = rand_date.date.D;

      @(negedge clk);
      inf.date_valid = 1'b0;
      inf.D = 'dx;
      t = $urandom_range(0, 3);
      repeat(t) @(negedge clk);
      inf.box_no_valid = 1'b1;
      box_number = rand_no.num;
      inf.D.d_box_no[0] = rand_no.num;

      for (i = 0;i<4;i++) begin
        @(negedge clk);
        inf.box_no_valid = 1'b0;
        inf.D = 'dx;
        inf.box_sup_valid = 1'b0;
        inf.D = 'dx;
        t = $urandom_range(0, 3);
        repeat(t) @(negedge clk);
        inf.box_sup_valid = 1'b1;
        rand_ml.randomize();
        inf.D.d_ing[0] = rand_ml.howmuch;
        supply_mole[i] = rand_ml.howmuch;
      end
     
      @(negedge clk);
      inf.box_sup_valid = 1'b0;
      inf.D = 'dx;

    end
    else if (rand_act.act == Check_Valid_Date) begin
      @(negedge clk);
      inf.sel_action_valid = 1'b0;
      inf.D = 'dx;
      t = $urandom_range(0, 3);
      repeat(t) @(negedge clk);
      inf.date_valid = 1'b1;
      inf.D.d_date[0].M = rand_date.date.M;
      inf.D.d_date[0].D = rand_date.date.D;
      today_date.M = rand_date.date.M;
      today_date.D = rand_date.date.D;

      @(negedge clk);
      inf.date_valid = 1'b0;
      inf.D = 'dx;
      t = $urandom_range(0, 3);
      repeat(t) @(negedge clk);
      inf.box_no_valid = 1'b1;
      box_number = rand_no.num;
      inf.D.d_box_no[0] = rand_no.num;

      @(negedge clk);
      inf.box_no_valid = 1'b0;
      inf.D = 'dx;
    end
  end
endtask

task give_ingredient;
  ingredient_box.black_tea       = {golden_DRAM[(65536 + 8*box_number + 7)] , golden_DRAM[(65536 + 8*box_number + 6)][7:4]};
  ingredient_box.green_tea       = {golden_DRAM[(65536 + 8*box_number + 6)][3:0] , golden_DRAM[(65536 + 8*box_number + 5)]};
  ingredient_box.M               =  golden_DRAM[(65536 + 8*box_number + 4)];
  ingredient_box.milk            = {golden_DRAM[(65536 + 8*box_number + 3)] , golden_DRAM[(65536 + 8*box_number + 2)][7:4]};
  ingredient_box.pineapple_juice = {golden_DRAM[(65536 + 8*box_number + 2)][3:0] , golden_DRAM[(65536 + 8*box_number + 1)]};
  ingredient_box.D               =  golden_DRAM[(65536 + 8*box_number + 0)];
endtask


task wait_out_valid_task;
  begin
    latency = 0;
    while(inf.out_valid !== 1'b1)
      begin
        //$display("in wait");
        latency = latency + 1;
        if( latency == 1000)
          begin
            FAIL_task_3;
            repeat(2)@(negedge clk);
            $finish;
          end
        @(negedge clk);
      end
    total_latency = total_latency + latency;
  end
endtask

task calculate_ans;
  begin
    GET_TOTAL_MOLE;
    GET_FOUR_MOLE;  
    expire = today_date.M > ingredient_box.M || (today_date.M == ingredient_box.M && today_date.D > ingredient_box.D);
    not_enough = black_tea_ml > ingredient_box.black_tea || green_tea_ml > ingredient_box.green_tea || milk_ml > ingredient_box.milk || pineapple_juice_ml > ingredient_box.pineapple_juice;
    too_many = supply_mole[0] + ingredient_box.black_tea > 4095 || supply_mole[1] + ingredient_box.green_tea > 4095 || supply_mole[2] + ingredient_box.milk > 4095 || supply_mole[3] + ingredient_box.pineapple_juice > 4095;
    
    if (accc == Make_drink) 
    begin
      if (expire) begin
        //$display("MONTH : %d  Date : %d", rand_date.date.M, rand_date.date.D);
        golden_complete = 'd0;
        golden_message = No_Exp;
      end 
      else if (not_enough) begin
        golden_complete = 'd0;
        golden_message = No_Ing;
      end
      else begin
        golden_complete = 'd1;
        golden_message = No_Err;
      end


    end
    else if (accc == Supply) 
    begin
      if (too_many) begin
        golden_complete = 'd0;
        golden_message = Ing_OF;
      end
      else begin
        golden_complete = 'd1;
        golden_message = No_Err;
      end
    end 
    else if (accc == Check_Valid_Date) 
    begin
      if (expire) begin
        golden_complete = 'd0;
        golden_message = No_Exp;
      end 
      else begin
        golden_complete = 'd1;
        golden_message = No_Err;
      end
    end
  end
endtask

task check_ans; begin
    calculate_ans;
    if(inf.complete !== golden_complete || inf.err_msg !== golden_message) begin
      $display("==========================================================================");
      $display("   Wrong Answer                                                           ");
      $display("==========================================================================");
      repeat(5) @(negedge clk);
      $finish;
    end
        
end endtask

task update_dram;

if (accc == Make_drink && !expire && !not_enough) begin
    {golden_DRAM[(65536 + box_number*8 + 7)], golden_DRAM[(65536 + box_number*8 + 6)][7:4]} = ingredient_box.black_tea - black_tea_ml;
    {golden_DRAM[(65536 + box_number*8 + 6)][3:0], golden_DRAM[(65536 + box_number*8 + 5)]} = ingredient_box.green_tea - green_tea_ml;
    {golden_DRAM[(65536 + box_number*8 + 4)][3:0]}                                          = ingredient_box.M;
    {golden_DRAM[(65536 + box_number*8 + 3)], golden_DRAM[(65536 + box_number*8 + 2)][7:4]} = ingredient_box.milk - milk_ml;
    {golden_DRAM[(65536 + box_number*8 + 2)][3:0], golden_DRAM[(65536 + box_number*8 + 1)]} = ingredient_box.pineapple_juice - pineapple_juice_ml;
    {golden_DRAM[(65536 + box_number*8 + 0)][4:0]}                                          = ingredient_box.D;
end
else if (accc == Supply) begin
    {golden_DRAM[(65536 + box_number*8 + 7)], golden_DRAM[(65536 + box_number*8 + 6)][7:4]} = (ingredient_box.black_tea + supply_mole[0] > 4095) ? 4095 : ingredient_box.black_tea + supply_mole[0];
    {golden_DRAM[(65536 + box_number*8 + 6)][3:0], golden_DRAM[(65536 + box_number*8 + 5)]} = (ingredient_box.green_tea + supply_mole[1] > 4095) ? 4095 : ingredient_box.green_tea + supply_mole[1];
    {golden_DRAM[(65536 + box_number*8 + 4)][3:0]}                                          = today_date.M;
    {golden_DRAM[(65536 + box_number*8 + 3)], golden_DRAM[(65536 + box_number*8 + 2)][7:4]} = (ingredient_box.milk + supply_mole[2] > 4095) ? 4095 : ingredient_box.milk + supply_mole[2];
    {golden_DRAM[(65536 + box_number*8 + 2)][3:0], golden_DRAM[(65536 + box_number*8 + 1)]} = (ingredient_box.pineapple_juice + supply_mole[3] > 4095) ? 4095 : ingredient_box.pineapple_juice + supply_mole[3];
    {golden_DRAM[(65536 + box_number*8 + 0)][4:0]}                                          = today_date.D;
end

t = $urandom_range(0, 3);
repeat(t) @(negedge clk);
endtask



task GET_TOTAL_MOLE;
  if (rand_size.size == L) begin
    total_bev_mole = 960;
  end
  else if (rand_size.size == M) begin
    total_bev_mole = 720;
  end
  else if (rand_size.size == S) begin
    total_bev_mole = 480;
  end
endtask

task GET_FOUR_MOLE;
  if (rand_type.type1 == Black_Tea) begin
    black_tea_ml = total_bev_mole; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = 10'd0;
  end
  else if (rand_type.type1 == Milk_Tea) begin
    black_tea_ml = (total_bev_mole/4)*3; green_tea_ml = 10'd0; milk_ml = (total_bev_mole/4); pineapple_juice_ml = 10'd0;
  end
  else if (rand_type.type1 == Extra_Milk_Tea) begin
    black_tea_ml = (total_bev_mole/2); green_tea_ml = 10'd0; milk_ml = (total_bev_mole/2); pineapple_juice_ml = 10'd0;
  end
  else if (rand_type.type1 == Green_Tea) begin
    black_tea_ml = 10'd0; green_tea_ml = total_bev_mole; milk_ml = 10'd0; pineapple_juice_ml = 10'd0;
  end
  else if (rand_type.type1 == Green_Milk_Tea) begin
    black_tea_ml = 10'd0; green_tea_ml = (total_bev_mole/2); milk_ml = (total_bev_mole/2); pineapple_juice_ml = 10'd0;
  end
  else if (rand_type.type1 == Pineapple_Juice) begin
    black_tea_ml = 10'd0; green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = total_bev_mole;
  end
  else if (rand_type.type1 == Super_Pineapple_Tea) begin
    black_tea_ml = (total_bev_mole/2); green_tea_ml = 10'd0; milk_ml = 10'd0; pineapple_juice_ml = (total_bev_mole/2);
  end
  else if (rand_type.type1 == Super_Pineapple_Milk_Tea) begin
    black_tea_ml = (total_bev_mole/2); green_tea_ml = 10'd0; milk_ml = (total_bev_mole/4); pineapple_juice_ml = (total_bev_mole/4);
  end
endtask


task YOU_PASS_task;
  begin
    $display("*************************************************************************");
    $display("*                         Congratulations!                              *");
    $display("*                Your execution cycles = %5d cycles          *", total_latency);
    $display("*************************************************************************");
    $finish;
  end
endtask

task FAIL_task_1;
  begin
        $display("==========================================================================");
        $display("   Wrong Answer                                                           ");
        $display("    Output signal should be 0 at %-12d ps  ", $time*1000);
        $display("==========================================================================");
  end
endtask

task FAIL_task_3;
  begin
            $display("==========================================================================");
            $display("   Wrong Answer                                                           ");
            $display("    The execution latency at %-12d ps is over %5d cycles  ", $time*1000, total_latency);
            $display("==========================================================================");
            repeat(5) @(negedge clk);
            $finish;
  end
endtask




endprogram

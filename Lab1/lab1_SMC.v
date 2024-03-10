//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2023 Fall
//   Lab01 Exercise		: Supper MOSFET Calculator
//   Author     		: Lin-Hung Lai (lhlai@ieee.org)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : SMC.v
//   Module Name : SMC
//   Release version : V1.0 (Release Date: 2023-09)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################


module SMC(
         // Input signals
         mode,
         W_0, V_GS_0, V_DS_0,
         W_1, V_GS_1, V_DS_1,
         W_2, V_GS_2, V_DS_2,
         W_3, V_GS_3, V_DS_3,
         W_4, V_GS_4, V_DS_4,
         W_5, V_GS_5, V_DS_5,
         // Output signals
         out_n
       );

//================================================================
//   INPUT AND OUTPUT DECLARATION
//================================================================
input [2:0] W_0, V_GS_0, V_DS_0;
input [2:0] W_1, V_GS_1, V_DS_1;
input [2:0] W_2, V_GS_2, V_DS_2;
input [2:0] W_3, V_GS_3, V_DS_3;
input [2:0] W_4, V_GS_4, V_DS_4;
input [2:0] W_5, V_GS_5, V_DS_5;
input [1:0] mode;
output [7:0] out_n;         					// use this if using continuous assignment for out_n  // Ex: assign out_n = XXX;
//output reg [7:0] out_n; 								// use this if using procedure assignment for out_n   // Ex: always@(*) begin out_n = XXX; end

//================================================================
//    Wire & Registers
//================================================================
wire [6:0] I_g0, I_g1, I_g2, I_g3, I_g4, I_g5;
wire [6:0] n0, n1, n2, n3, n4, n5;


//================================================================
//    DESIGN
//================================================================

Calculate cal0(.w(W_0), .v_gs(V_GS_0), .v_ds(V_DS_0), .mode(mode[0]), .i_g(I_g0));
Calculate cal1(.w(W_1), .v_gs(V_GS_1), .v_ds(V_DS_1), .mode(mode[0]), .i_g(I_g1));
Calculate cal2(.w(W_2), .v_gs(V_GS_2), .v_ds(V_DS_2), .mode(mode[0]), .i_g(I_g2));
Calculate cal3(.w(W_3), .v_gs(V_GS_3), .v_ds(V_DS_3), .mode(mode[0]), .i_g(I_g3));
Calculate cal4(.w(W_4), .v_gs(V_GS_4), .v_ds(V_DS_4), .mode(mode[0]), .i_g(I_g4));
Calculate cal5(.w(W_5), .v_gs(V_GS_5), .v_ds(V_DS_5), .mode(mode[0]), .i_g(I_g5));

Sort sorting(.i_g0(I_g0), .i_g1(I_g1), .i_g2(I_g2), .i_g3(I_g3), .i_g4(I_g4), .i_g5(I_g5),
             .n0(n0), .n1(n1), .n2(n2), .n3(n3), .n4(n4), .n5(n5));

Output out(.n0(n0), .n1(n1), .n2(n2), .n3(n3), .n4(n4), .n5(n5), .mode(mode), .out(out_n));

endmodule


  //================================================================
  //   SUB MODULE
  //================================================================

  module Calculate (w, v_gs, v_ds, mode, i_g);
input [2:0] w;
input [2:0] v_gs;
input [2:0] v_ds;
input mode; // 1 for I and 0 for gm
output [6:0] i_g;


reg [5:0] tri_sat;
reg [3:0] mult1;
reg [2:0] mult2;
reg [3:0] gm;


wire [2:0] v_ov;
wire [3:0] v_ov_2;
wire [7:0] w_b4;
assign v_ov = v_gs - 1'b1;
assign v_ov_2 = v_ov << 1;
assign w_b4 = tri_sat * w;
assign i_g = w_b4 / 2'd3;

always @(*)
  begin
    if (mode == 1'b0)
      begin
        tri_sat = gm;
      end
    else
      begin
        tri_sat = mult1 * mult2;
      end
  end

always@(*)
  begin
    if (v_ov > v_ds)
      begin // triode region
        mult1 = v_ov_2 - v_ds;
        mult2 = v_ds;
        gm = v_ds << 1;
      end
    else
      begin // saturation region
        mult1 = v_ov;
        mult2 = v_ov;
        gm = v_ov << 1;
      end
  end

endmodule

module Com3(in1,in2,in3,out1,out2,out3);
  input [6:0] in1,in2,in3;
  output [6:0] out1,out2,out3;
  reg [6:0] i1,i2,i3;
  assign {out1,out2,out3} = {i1,i2,i3};

  always @(*) begin
    {i1 , i2 , i3} = {in1,in2,in3};
    if (i1 < i2) 
        begin
          {i1 , i2} = {i2 , i1};
        end

    if (i2 < i3)
        begin
          {i2 , i3} = {i3 , i2};
        end

    if (i1 < i2)
        begin
          {i1 , i2} = {i2 , i1};
        end 
  end
endmodule

module Com2(in1,in2,out1,out2);
  input [6:0] in1,in2;
  output [6:0] out1,out2;
  reg [6:0] i1,i2;

  assign {out1,out2} = {i1,i2};

  always @(*) begin
      {i1 , i2} = {in1,in2};
      if (i1 < i2) 
        begin
          {i1 , i2} = {i2 , i1};
        end
  end
endmodule



  module Sort(i_g0, i_g1, i_g2, i_g3, i_g4, i_g5, n0, n1, n2, n3, n4, n5);
input [6:0] i_g0, i_g1, i_g2, i_g3, i_g4, i_g5;
output [6:0] n0, n1, n2, n3, n4, n5;

wire [6:0] top1,top2,top3,under1,under2,under3;
wire [6:0] w1,w2,w3,w4,w5,w6;
wire [6:0] ww2,ww3,ww4,ww5;
wire [6:0] www3,www4;
assign {n0,n1,n2,n3,n4,n5} = {w1,ww2,www3,www4,ww5,w6};

Com3 up1(.in1(i_g0),.in2(i_g1),.in3(i_g2),.out1(top1),.out2(top2),.out3(top3));
Com3 down1(.in1(i_g3),.in2(i_g4),.in3(i_g5),.out1(under1),.out2(under2),.out3(under3));
Com2 up2(.in1(top1),.in2(under1),.out1(w1),.out2(w2));
Com2 mid2(.in1(top2),.in2(under2),.out1(w3),.out2(w4));
Com2 down2(.in1(top3),.in2(under3),.out1(w5),.out2(w6));
Com2 up3(.in1(w2),.in2(w3),.out1(ww2),.out2(ww3));
Com2 down3(.in1(w4),.in2(w5),.out1(ww4),.out2(ww5));
Com2 mid4(.in1(ww3),.in2(ww4),.out1(www3),.out2(www4));
endmodule


  module Output (n0, n1, n2, n3, n4, n5, mode, out);
input [6:0] n0, n1, n2, n3, n4, n5;
input [1:0] mode;
output [7:0] out;

reg [11:0] sum;
reg [6:0] substract;
reg [11:0] w1;
reg [6:0] add1,add2,add3;

assign out = (w1 >> 2) / 2'd3;

always@(*)
  begin
    case (mode[1])
      1'b0:
        begin
          add1 = n3;
          add2 = n4;
          add3 = n5;
        end
      default:
        begin
          add1 = n0;
          add2 = n1;
          add3 = n2;
        end
    endcase
  end

always@(*)
  begin
    sum =( add1 + add2 + add3 ) << 2;
    substract = add1 - add3;
  end
  

/*
  always@(*)
  begin
    if (mode[1] == 1'b0)
        begin
          sum = (n3 + n4 + n5) << 2;
          substract = n3 - n5;
        end
    else  
        begin
          sum = (n0 + n1 + n2) << 2;
          substract = n0 - n2;
        end
  end*/

  always@(*)
  begin
    if (mode[0] == 1'b0)
        w1 = sum;
    else
        w1 = sum - substract;
  end
/*
always@(*)
  begin
    case (mode[0])
      1'b0:
        w1 = sum;
      default:
        w1 = sum - substract;
    endcase
  end*/


endmodule


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:             Wissance (https://wissance.com)
// Engineer:            EvilLord666 (Ushakov MV - https://github.com/EvilLord666)
// 
// Create Date:         09.10.2016
// Design Name:    
// Module Name:         fifo_tb
// Project Name:        QuickRS232
// Target Devices:      Any
// Tool Versions:       Quartus Prime Lite 18.1
// Description:         Fifo module testbench
// 
// Dependencies:        No
// 
// Revision:            1.0 
// Additional Comments: 
// 
//////////////////////////////////////////////////////////////////////////////////


module fifo_tb();

wire enable;
reg clear;
reg push_clock;
reg pop_clock;
reg  [7:0] in_data;
wire [7:0] out_data;
wire popped_last;
wire pushed_last;
supply1 vcc;
reg clk;

assign enable = vcc;

fifo #(.FIFO_SIZE(3), .DATA_WIDTH(8)) simple_fifo (.enable(enable), .clear(clear), 
                                                   .push_clock(push_clock), .pop_clock(pop_clock), 
                                                   .in_data(in_data), .out_data(out_data),
                                                   .popped_last(popped_last), .pushed_last(pushed_last));

endmodule

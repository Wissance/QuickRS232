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
reg [31:0] counter;


fifo #(.FIFO_SIZE(3), .DATA_WIDTH(8)) simple_fifo (.enable(enable), .clear(clear), 
                                                   .push_clock(push_clock), .pop_clock(pop_clock), 
                                                   .in_data(in_data), .out_data(out_data),
                                                   .popped_last(popped_last), .pushed_last(pushed_last));



initial
begin
    counter <= 0;
    push_clock <= 0;
    pop_clock <= 0;
    clk <= 0;
    clear <= 0;
    #100
    clear <= 1;
    #100
    clear <= 0;
end

always
begin
    #20 clk <= ~clk;
    counter <= counter + 1;
    // 1. push first
    // 1.1 setting data first
    if (counter == 20)
    begin
        in_data <= 8'b10101100;
    end
    // 1.2 push clock is up
    if (counter == 22)
    begin
        push_clock <= 1;
    end
    // 1.3 push clock is down
    if (counter == 23)
    begin
        push_clock <= 0;
    end
    // 2. push first
    // 2.1 setting data first
    if (counter == 30)
    begin
        in_data <= 8'b01100001;
    end
    // 2.2 push clock is up
    if (counter == 32)
    begin
        push_clock <= 1;
    end
    // 2.3 push clock is down
    if (counter == 33)
    begin
        push_clock <= 0;
    end
    // 3. pop first byte
    if (counter == 40)
    begin
        pop_clock <= 1;
    end
    if (counter == 42)
    begin
        pop_clock <= 0;
    end
    // 4. pop second byte
    if (counter == 50)
    begin
        pop_clock <= 1;
    end
    if (counter == 52)
    begin
        pop_clock <= 0;
    end
end

endmodule

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

`define ASSERT(signal, value) \
        if (signal !== value) begin \
            $display("ASSERTION FAILED in %m: expected: %b, actual is : %b", value, signal); \
            $finish; \
        end \
        else \
        begin \
            $display("ASSERTION SUCCEDED"); \
        end \


module fifo_tb();

wire enable;
reg clear;
reg push;
reg pop;
reg  [7:0] in_data;
wire [7:0] out_data;
wire popped_last;
wire pushed_last;
supply1 vcc;
reg clk;

assign enable = vcc;
reg [31:0] counter;


fifo #(.FIFO_SIZE(3), .DATA_WIDTH(8)) simple_fifo (.clk(clk), .clear(clear),  .push(push), .pop(pop), 
                                                   .in_data(in_data), .out_data(out_data),
                                                   .popped_last(popped_last), .pushed_last(pushed_last));



initial
begin
    in_data <= 0;
    counter <= 0;
    push <= 0;
    pop <= 0;
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
        push <= 1;
    end
    // 1.3 push clock is down
    if (counter == 23)
    begin
        push <= 0;
        `ASSERT(pushed_last, 1'b0)
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
        push <= 1;
    end
    // 2.3 push clock is down
    if (counter == 33)
    begin
        push <= 0;
        `ASSERT(pushed_last, 1'b0)
    end
    // 3. pop first byte
    if (counter == 40)
    begin
        pop <= 1;
    end
    if (counter == 42)
    begin
        pop <= 0;
    end
    if (counter == 44)
    begin
        `ASSERT(out_data, 8'b10101100)
        `ASSERT(popped_last, 1'b0)
    end
    // 4. pop second byte
    if (counter == 50)
    begin
        pop <= 1;
    end
    if (counter == 52)
    begin
        pop <= 0;
    end
    if (counter == 56)
    begin
        `ASSERT(out_data, 8'b01100001)
        //`ASSERT(popped_last, 1'b1)
    end
    // 5. push again (b0)
    if (counter == 60)
    begin
        in_data <= 8'b00010001;
    end
    // push clock is up
    if (counter == 62)
    begin
        push <= 1;
    end
    // push clock is down
    if (counter == 63)
    begin
        push <= 0;
    end
    if (counter == 65)
    begin
        `ASSERT(pushed_last, 1'b0)
    end
    // 6. push again (b1)
    if (counter == 70)
    begin
        in_data <= 8'b00111001;
    end
    // push clock is up
    if (counter == 72)
    begin
        push <= 1;
    end
    // push clock is down
    if (counter == 73)
    begin
        push <= 0;
    end
    if (counter == 75)
    begin
        `ASSERT(pushed_last, 1'b0)
    end
    // 7. push again (b0)
    if (counter == 80)
    begin
        in_data <= 8'b01111101;
    end
    // push clock is up
    if (counter == 82)
    begin
        push <= 1;
    end
    // push clock is down
    if (counter == 83)
    begin
        push <= 0;
    end
    if (counter == 85)
    begin
        //`ASSERT(pushed_last, 1'b1)
    end
    // 8. pop b0
    if (counter == 90)
    begin
        pop <= 1;
    end
    if (counter == 92)
    begin
        pop <= 0;
    end
    if (counter == 95)
    begin
        `ASSERT(pushed_last, 1'b0)
    end
end

endmodule

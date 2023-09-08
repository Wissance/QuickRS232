`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:             Wissance (https://wissance.com)
// Engineer:            EvilLord666 (Ushakov MV - https://github.com/EvilLord666)
// 
// Create Date:         05.09.2023
// Design Name:    
// Module Name:         fifo
// Project Name:        QuickRS232
// Target Devices:      Any
// Tool Versions:       Quartus Prime Lite 18.1
// Description:         A module that store and manages multiple bytes store
// 
// Dependencies:        No
// 
// Revision:            1.0 
// Additional Comments: 
// 
//////////////////////////////////////////////////////////////////////////////////

module fifo #
(
    parameter FIFO_SIZE = 8,
    parameter DATA_WIDTH = 32
)
(
    input wire  clk,
    // input wire  enable,
    input wire  clear,
    // output wire fifo_ready,
    input wire  push,
    input wire  pop,
    input wire  [DATA_WIDTH - 1:0] in_data,
    output wire [DATA_WIDTH - 1:0] out_data,
    output wire popped_last,
    output wire pushed_last
);
    reg [DATA_WIDTH - 1:0] fifo_data [FIFO_SIZE - 1 : 0];   
    reg [DATA_WIDTH - 1:0] buffer;
    reg pushed_last_value;
    reg popped_last_value;
    reg [15:0] data_count;
    reg [15:0] position;
    reg [15:0] counter;
    reg [2:0] fifo_state;
 
    localparam reg [2:0] INITIAL_STATE = 1;
    localparam reg [2:0] PUSH_STARTED = 2;
    localparam reg [2:0] PUSH_FINISHED = 3;
    localparam reg [2:0] POP_STARTED = 4;
    localparam reg [2:0] POP_FINISHED = 5;
    localparam reg [2:0] OPERATION_AWAITING = 6;
    
    assign out_data = buffer;
    assign pushed_last = pushed_last_value;
    assign popped_last = popped_last_value;

    always@ (posedge clk)
    begin
        if (clear == 1'b1)
        begin
            fifo_state = INITIAL_STATE;
            for(counter = 0; counter < FIFO_SIZE; counter = counter + 16'h01)
                fifo_data[counter] <= 0;
            position <= 0;
            data_count <= 0;    
            popped_last_value <= 1'b1;
            pushed_last_value <= 1'b0;
            buffer <= 0;
        end
        else
        begin
            case (fifo_state)
                INITIAL_STATE:
                begin
                    fifo_state = OPERATION_AWAITING;
                end
                OPERATION_AWAITING:
                begin
                    // if position == 0, nothing to pop
                    if (position == 0)
                    begin
                        popped_last_value <= 1'b1;
                    end
                    else
                    begin
                        popped_last_value <= 1'b0;
                    end
                    // if buffer is full, nothing to push
                    if(data_count == FIFO_SIZE)
                    begin
                        pushed_last_value <= 1'b1;
                    end
                    else
                    begin
                        pushed_last_value <= 1'b0;
                    end

                    // push have a priority over pop
                    if (push == 1'b1)
                    begin
                        fifo_state <= PUSH_STARTED;
                    end
                    if (pop == 1'b1)
                    begin
                       fifo_state <= POP_STARTED;
                    end
                end
                PUSH_STARTED:
                begin
                    if (data_count < FIFO_SIZE)
                    begin
                        fifo_data[position] <= in_data;
                        position <= position + 16'h01;    // position is an index of next item ...
                        data_count <= data_count + 16'h01;
                        fifo_state <= PUSH_FINISHED;
                        popped_last_value <= 1'b0;
                        if (position == FIFO_SIZE - 1)
                        begin
                            pushed_last_value <= 1'b1;
                        end
                    end
                    else
                    begin
                        fifo_state <= OPERATION_AWAITING;
                    end
                end
                PUSH_FINISHED:
                begin
                    if (push == 1'b0)
                    begin
                        fifo_state <= OPERATION_AWAITING;
                    end
                end
                POP_STARTED:
                begin
                    if (data_count > 0)
                    begin
                        buffer <= fifo_data[0];
                        data_count <= data_count - 16'h01;
                        pushed_last_value <= 0;
                        for(counter = 0; counter < FIFO_SIZE - 1; counter = counter + 16'h01)
                            fifo_data[counter] <= fifo_data[counter + 1];
                        fifo_data[FIFO_SIZE - 1] <= 0;
                        position <= position - 16'h01;
                        fifo_state <= POP_FINISHED;
                        pushed_last_value <= 1'b0;
                        if(position == 1)
                            popped_last_value <= 1'b1;
                    end
                    else
                    begin
                        fifo_state <= OPERATION_AWAITING;
                    end
                    
                end
                POP_FINISHED:
                begin
                    if (pop == 1'b0)
                    begin
                        fifo_state <= OPERATION_AWAITING;
                    end
                end
            endcase
        end
    end
endmodule

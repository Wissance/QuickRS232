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
    //input wire  enable,
    input wire  clear,
    output wire fifo_ready,
    input wire  push,
    input wire  pop,
    input wire  [DATA_WIDTH - 1 : 0] in_data,
    output wire [DATA_WIDTH - 1 : 0] out_data,
    output wire popped_last,
    output wire pushed_last
);
    reg [DATA_WIDTH - 1 : 0] fifo_data [FIFO_SIZE - 1 : 0];   
    reg [DATA_WIDTH - 1 : 0] buffer;
    reg pushed_last_value;
    reg popped_last_value;
    reg [15: 0] data_count;
    reg [15: 0] position;
    reg [15: 0] counter;
    reg [2:0] fifo_state;
 
    localparam reg [2:0] INITIAL_STATE = 1;
    localparam reg [2:0] PUSH_STARTED = 2;
    localparam reg [2:0] PUSH_FINISHED = 3;
    localparam reg [2:0] POP_STARTED = 4;
    localparam reg [2:0] POP_FINISHED = 5;
    localparam reg [2:0] OPERATION_AWAITING = 6;
    
    //assign fifo_ready = enable && ~clear;   // candidate 4 remove in a synchronous FIFO
    assign out_data = buffer;
    assign pushed_last = pushed_last_value;
    assign popped_last = popped_last_value;

    always@ (posedge clk)
    begin
        if (clear == 1'b1)
        begin
            fifo_state <= INITIAL_STATE;
            for(counter = 0; counter < FIFO_SIZE; counter = counter + 1)
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
                    fifo_state <= OPERATION_AWAITING;
                end
                OPERATION_AWAITING:
                begin
                    popped_last_value <= position == 0;
                    if(data_count == FIFO_SIZE)
                    begin
                        pushed_last_value <= 1;
                    end
                    else
                    begin
                        pushed_last_value <= 0;
                    end
                    // push have more priority
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
                    if(data_count <= FIFO_SIZE)
                    begin
                        popped_last_value <= 0;
                        fifo_data[position] <= in_data;
                        position <= position + 1;    // position is an index of next item ...
                        data_count <= data_count + 1;
                    end
                    if (push == 1'b0)
                    begin
                        fifo_state <= PUSH_FINISHED;
                    end
                end
                PUSH_FINISHED:
                begin
                    fifo_state <= OPERATION_AWAITING;
                end
                POP_STARTED:
                begin
                    if (data_count >= 1)
                    begin
                        buffer <= fifo_data[0];
                        data_count <= data_count - 1;
                        pushed_last_value <= 0;
                        for(counter = 0; counter < FIFO_SIZE - 1; counter = counter + 1)
                            fifo_data[counter] <= fifo_data[counter + 1];
                        fifo_data[FIFO_SIZE - 1] <= 0;
                        position <= position - 1;
                    end
                    else
                    begin
                        popped_last_value <= 1;
                        buffer <= 0;
                    end
                    if (pop == 1'b0)
                    begin
                        fifo_state <= POP_FINISHED;
                    end
                end
                POP_FINISHED:
                begin
                    fifo_state <= OPERATION_AWAITING;
                end
            endcase
        end
    end
    
    /*always@ (posedge push_clock, posedge pop_clock, posedge clear)
    begin
        if(clear)
        begin
            for(counter = 0; counter < FIFO_SIZE; counter = counter + 1)
                fifo_data[counter] = 0;
            position = 0;
            data_count = 0;    
            popped_last_value = 1;
            pushed_last_value = 0;
            buffer = 0;
        end
        else
        begin
            //todo: umv: think about smart event separation for push and pop
            if(push_clock)
            begin
                if(data_count <= FIFO_SIZE)
                begin
                    popped_last_value = 0;
                    fifo_data[position] = in_data;
                    position = position + 1;    // position is an index of next item ...
                    data_count = data_count + 1;
                    if(data_count == FIFO_SIZE)
                    begin
                        pushed_last_value = 1;
                    end
                    else
                    begin
                        pushed_last_value = 0;
                    end
                end
            end
            else
            begin
                if (data_count >= 1)
                begin
                    buffer = fifo_data[0];
                    data_count = data_count - 1;
                    pushed_last_value = 0;
                    for(counter = 0; counter < FIFO_SIZE - 1; counter = counter + 1)
                        fifo_data[counter] = fifo_data[counter + 1];
                    fifo_data[FIFO_SIZE - 1] = 0;
                    position = position - 1;
                    popped_last_value = position == 0;
                end
                else
                begin
                    popped_last_value = 1;
                    buffer = 0;
                end
            end
        end
    end*/
endmodule

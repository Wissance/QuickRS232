//////////////////////////////////////////////////////////////////////////////////
// Company:             Wissance (https://wissance.com)
// Engineer:            EvilLord666 (Ushakov MV - https://github.com/EvilLord666)
// 
// Create Date:         22.12.2022 
// Design Name: 
// Module Name:         quick_rs232
// Project Name:        QuickRS232
// Target Devices:      Any
// Tool versions:       Quartus Prime Lite 18.1
// Description:         RS-232 interface with Hardware Flow Control Support
//
// Dependencies:        Depends on Fifo.h (taken from https://github.com/IzyaSoft/EasyHDLLib)
//
// Revision:            1.0   
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
// Parity bits
`define NO_PARITY              0
`define EVEN_PARITY            1
`define ODD_PARITY             2
`define MARK_PARITY            3
`define SPACE_PARITY           4
// Stop bits
`define ONE_STOP_BIT           0
`define ONE_AND_HALF_STOP_BITS 1
`define TWO_STOP_BITS          2
// Flow controls
`define NO_FLOW_CONTROL        0
`define CTS_RTS_FLOW_CONTROL   1
// Baud Rate
// todo(UMV) add consts ...


module quick_rs232 #(
    CLK_FREQ = 50000000,                       // clk input Frequency (Hz)
    DEFAULT_BYTE_LEN = 8,                      // RS232 byte length, available values are - 5, 6, 7, 8, 9
    DEFAULT_PARITY = `EVEN_PARITY,             // Parity: No, Even, Odd, Mark or Space
    DEFAULT_STOP_BITS = `ONE_STOP_BIT,         // Stop bits number: 0, 1.5 or 2
    DEFAULT_BAUD_RATE = 9600,                  // Baud = Bit/s, supported values: 2400, 4800, 9600, 19200, 38400, 57600, or 115200
    DEFAULT_RECV_BUFFER_LEN = 16,              // Input (Rx) buffer size
    DEFAULT_FLOW_CONTROL = `NO_FLOW_CONTROL    // Flow control type: NO, HARDWARE
)
(
    // Global Signals
    input wire clk,                            // clk is a clock 
    input wire rst,                            // rst is a global reset system
    // External RS232 Interface
    input wire rx,                             // rx  - receive  (1 bit line for receive data)
    output reg tx,                             // tx  - transmit (1 bit line for transmit data)
    input wire rts,                            // rts - request to send PC sets rts == 1'b1 that indicates that there is a data for receive
    output reg cts,                            // cts - clear to send (devices sets cts to 1
    // Interaction with inner module
    input wire rx_read,                        // read next data portion __---______---_____
    output wire [DEFAULT_BYTE_LEN-1:0] rx_data,// data portion
    output reg rx_byte_received,               // generate short pulse when byre received __--___--___--___
    //
    input wire tx_transaction,                 // transaction if while tx_transaction == 1 we send data to PC
    input wire [DEFAULT_BYTE_LEN-1:0] tx_data, // data that should be send trough RS232
    input wire tx_data_ready,                  // required: setting to 1 when new data is ready to send
    output reg tx_data_copied,                 // short pulse means that data was copied _--_____--______--___
    output reg tx_busy                         // tx notes that data is sending via RS232 or RS232 module awaiting flow-control synch
);

localparam reg [3:0] IDLE_EXCHANGE_STATE = 1;
localparam reg [3:0] SYNCH_WAIT_EXCHANGE_STATE = 2;
localparam reg [3:0] SYNCH_START_EXCHANGE_STATE = 3;
localparam reg [3:0] START_BIT_EXCHANGE_STATE = 4;
localparam reg [3:0] DATA_BITS_EXCHANGE_STATE = 5;
localparam reg [3:0] PARITY_BIT_EXCHANGE_STATE = 6;
localparam reg [3:0] STOP_BITS_EXCHANGE_STATE = 7;
localparam reg [3:0] SYNCH_STOP_EXCHANGE_STATE = 8;

localparam reg [31:0] TICKS_PER_UART_BIT = CLK_FREQ / DEFAULT_BAUD_RATE;
localparam reg [31:0] HALF_TICKS_PER_UART_BIT = TICKS_PER_UART_BIT / 2;

reg [3:0] tx_state;
reg [3:0] rx_state;
reg [DEFAULT_BYTE_LEN-1:0] tx_buffer;
reg [31:0] tx_bit_counter;
reg [31:0] tx_stop_bit_counter_limit;
reg [3:0]  tx_data_bit_counter;
reg tx_data_parity;
reg [DEFAULT_BYTE_LEN-1:0] rx_buffer;
wire rx_data_buffer_full;
integer i;

supply1 vcc;
supply0 gnd;

fifo #(.FIFO_SIZE(DEFAULT_RECV_BUFFER_LEN), .DATA_WIDTH(DEFAULT_BYTE_LEN)) 
rx_data_buffer (.enable(vcc), .clear(rst), .push_clock(rx_byte_received), .pop_clock(rx_read), 
                .in_data(rx_buffer), .out_data(rx_data), .pushed_last(rx_data_buffer_full));


/*********************************************************************************
 * Block for reading data from external buffer
 **********************************************************************************/

/**********************************************************************************
 * Block for reading (rx) data from RS232 and store in a internal buffer
 **********************************************************************************/
always @(posedge clk)
begin
    if (rst == 1'b1)
    begin
        // clear all data
        rx_state <= IDLE_EXCHANGE_STATE;
        rx_byte_received <= 1'b0;
        rx_buffer <= 0;
    end
    else
    begin
        case (rx_state)
            IDLE_EXCHANGE_STATE:
            begin
                rx_state <= SYNCH_WAIT_EXCHANGE_STATE;
                cts <= 1'b0;
            end
            SYNCH_WAIT_EXCHANGE_STATE:
            begin
                if (DEFAULT_FLOW_CONTROL == `NO_FLOW_CONTROL)
                begin
                    rx_state <= SYNCH_START_EXCHANGE_STATE;
                end
                else
                begin
                    // expecting here hardware RTS+CTS synch, others are temporarily not supported
                    if (rts == 1'b1)
                    begin
                        if(rx_data_buffer_full == 1'b0)
                        begin
                            cts <= 1'b1;
                        end
                        else
                        begin
                            cts <= 1'b0;
                        end
                    end
                end
            
            end
            SYNCH_START_EXCHANGE_STATE:
            begin
                rx_state <= START_BIT_EXCHANGE_STATE;
            end
            START_BIT_EXCHANGE_STATE:
            begin
                rx_state <= DATA_BITS_EXCHANGE_STATE;
            end
            DATA_BITS_EXCHANGE_STATE:
            begin
                rx_state <= PARITY_BIT_EXCHANGE_STATE;
            end
            PARITY_BIT_EXCHANGE_STATE:
            begin
                rx_state <= STOP_BITS_EXCHANGE_STATE;
                // if parity is bad generate error, don't store byte ...
            end
            STOP_BITS_EXCHANGE_STATE:
            begin
                rx_state <= SYNCH_STOP_EXCHANGE_STATE;
                rx_byte_received <= 1'b1;
            end
            SYNCH_STOP_EXCHANGE_STATE:
            begin
                rx_state <= SYNCH_WAIT_EXCHANGE_STATE;
                rx_byte_received <= 1'b0;
            end
        endcase
    end
end

/**********************************************************************************
 * Block for writing (tx) data to RS232
 **********************************************************************************/
always @(posedge clk)
begin
    if (rst == 1'b1)
    begin
        // clear all data
        tx_state <= IDLE_EXCHANGE_STATE;
        tx_data_copied <= 1'b0;
        tx_busy <= 1'b0;
        // tx_rts <= 1'b0;
        tx_buffer <= 0;
        tx_bit_counter <= 0;
        tx <= 1'b1;                       // IDLE state
        tx_data_bit_counter <= 1'b0;      // Data bit counter = 0
        tx_data_parity <= 1'b0;
        tx_stop_bit_counter_limit <= 0;
    end
    else
    begin
        case (tx_state)
            IDLE_EXCHANGE_STATE:
            begin
                if (tx_transaction == 1'b1)
                begin
                    tx_state <= SYNCH_WAIT_EXCHANGE_STATE;
                    tx_buffer <= 0;
                    tx_data_copied <= 1'b0;
                    tx_busy <= 1'b0;
                    tx_bit_counter <= 0;
                    tx <= 1'b1;   // IDLE state
                    tx_data_parity <= 1'b0;
                    case (DEFAULT_STOP_BITS)
                        default:
                        begin
                            tx_stop_bit_counter_limit <= TICKS_PER_UART_BIT;
                        end
                        `ONE_AND_HALF_STOP_BITS:
                        begin
                            tx_stop_bit_counter_limit <= TICKS_PER_UART_BIT + HALF_TICKS_PER_UART_BIT;
                        end
                        `TWO_STOP_BITS:
                        begin
                            tx_stop_bit_counter_limit <= TICKS_PER_UART_BIT + TICKS_PER_UART_BIT;
                        end
                    endcase
                    
                end
                else
                begin
                    // todo(umv): add cleanup here if no transaction ...
                end
            end
            SYNCH_WAIT_EXCHANGE_STATE:
            begin
                // FLOW control synchronization
                if (DEFAULT_FLOW_CONTROL == `NO_FLOW_CONTROL)
                begin
                   tx_state <= SYNCH_START_EXCHANGE_STATE;
                end
                else
                begin
                   if (DEFAULT_FLOW_CONTROL == `CTS_RTS_FLOW_CONTROL)
                   begin
                       // RTS + CTS
                       // Here we assume that RTS wired with RTS, CTS with CTS, no crossing RTS->CTS, CTS->RTS
                       // therefore is nothing to do in TX here
                       tx_state <= SYNCH_START_EXCHANGE_STATE;
                   end
                end
            end
            SYNCH_START_EXCHANGE_STATE:
            begin
                // wait for data here and move to real tx when we have data
                if (tx_data_ready == 1'b1)
                begin
                   tx_state <= START_BIT_EXCHANGE_STATE;
                   tx_buffer <= tx_data;
                   tx_data_copied <= 1'b1;
                   tx_busy <= 1'b1;
                   tx_data_bit_counter <= 1'b0;      // Data bit counter = 0
                end
                if (tx_transaction == 1'b0)
                begin
                   tx_state <= IDLE_EXCHANGE_STATE;
                end
            end
            START_BIT_EXCHANGE_STATE:
            begin
                tx <= 1'b0;
                tx_bit_counter <= tx_bit_counter + 1;
                if (tx_bit_counter == TICKS_PER_UART_BIT)
                begin
                   tx_bit_counter <= 0;
                   tx_state <= DATA_BITS_EXCHANGE_STATE;
                end
            end
            DATA_BITS_EXCHANGE_STATE:
            begin
                tx <= tx_buffer[tx_data_bit_counter];
                tx_bit_counter <= tx_bit_counter + 1;
                if (tx_bit_counter == TICKS_PER_UART_BIT)
                begin
                   tx_bit_counter <= 0;
                   tx_data_bit_counter <= tx_data_bit_counter + 1;
                   if (tx_data_bit_counter == DEFAULT_BYTE_LEN)
                   begin
                       tx_state <= PARITY_BIT_EXCHANGE_STATE;
                       tx_data_copied <= 1'b0;
                   end
                end
            end
            PARITY_BIT_EXCHANGE_STATE:
            begin
                case (DEFAULT_PARITY)
                    `NO_PARITY:
                    begin
                        tx_state <= STOP_BITS_EXCHANGE_STATE;
                    end
                    `MARK_PARITY:
                    begin
                        tx <= 1'b1;
                    end
                    `SPACE_PARITY:
                    begin
                        tx <= 1'b0;
                    end
                    `EVEN_PARITY:
                    begin
                        tx_data_parity <= tx_buffer[0];
                        for (i = 1; i < DEFAULT_BYTE_LEN; i = i + 1)
                        begin
                            tx_data_parity <= tx_data_parity | tx_buffer[i];
                        end
                        tx <= tx_data_parity == 1'b0 ? 1'b0: 1'b1;
                    end
                    `ODD_PARITY:
                    begin
                        tx_data_parity <= tx_buffer[0];
                        for (i = 1; i < DEFAULT_BYTE_LEN; i = i + 1)
                        begin
                            tx_data_parity <= tx_data_parity | tx_buffer[i];
                        end
                        tx <= tx_data_parity == 1'b0 ? 1'b1: 1'b0;
                    end
                endcase
                
                if (DEFAULT_PARITY != `NO_PARITY)
                begin
                    tx_bit_counter <= tx_bit_counter + 1;
                    if (tx_bit_counter == TICKS_PER_UART_BIT)
                    begin
                        tx_bit_counter <= 0;
                        tx_state <= STOP_BITS_EXCHANGE_STATE;
                    end
                end
            end
            STOP_BITS_EXCHANGE_STATE:
            begin
                tx <= 1'b1;
                tx_bit_counter <= tx_bit_counter + 1;
                if (tx_bit_counter == tx_stop_bit_counter_limit)
                begin
                    tx_bit_counter <= 0;
                    tx_state <= SYNCH_STOP_EXCHANGE_STATE;
                end
            end
            SYNCH_STOP_EXCHANGE_STATE:
            begin
                tx_busy <= 1'b0;
                tx_state <= IDLE_EXCHANGE_STATE;
            end
        endcase
    end
end

endmodule

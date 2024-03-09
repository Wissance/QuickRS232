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
// Dependencies:        Depends on modified Fifo.h (original was taken from https://github.com/IzyaSoft/EasyHDLLib)
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


// Baud = Bit/s, supported values: 2400, 4800, 9600, 19200, 38400, 57600, or 115200 (RS232 )
module quick_rs232 #(
    parameter CLK_TICKS_PER_RS232_BIT = 434,             // ticks of clock per rs232 bit (i.e 434 is a value for 50MHz at clk && 115200 bit/s RS232 speed), = clk freq / rs232 speed 
    parameter DEFAULT_BYTE_LEN = 8,                      // RS232 byte length, available values are - 5, 6, 7, 8, 9
    parameter DEFAULT_PARITY = `EVEN_PARITY,             // Parity: No, Even, Odd, Mark or Space
    parameter DEFAULT_STOP_BITS = `ONE_STOP_BIT,         // Stop bits number: 0, 1.5 or 2              
    parameter DEFAULT_RECV_BUFFER_LEN = 16,              // Input (Rx) buffer size
    parameter DEFAULT_FLOW_CONTROL = `NO_FLOW_CONTROL    // Flow control type: NO, HARDWARE
)
(
    // Global Signals
    input wire clk,                                      // clk is a clock 
    input wire rst,                                      // rst is a global reset system
    // External RS232 Interface
    input wire rx,                                       // rx  - receive  (1 bit line for receive data)
    output reg tx,                                       // tx  - transmit (1 bit line for transmit data)
    input wire rts,                                      // rts - request to send PC sets rts == 1'b1 that indicates that there is a data for receive
    output reg cts,                                      // cts - clear to send (devices sets cts to 1
    // Interaction with inner module
    input wire rx_read,                                  // read next data portion __---______---_____
    output reg rx_err,
    output wire [DEFAULT_BYTE_LEN-1:0] rx_data,          // data portion
    output reg rx_byte_received,                         // generate short pulse when byre received __--___--___--___
    //
    input wire tx_transaction,                           // transaction if while tx_transaction == 1 we send data to PC
    input wire [DEFAULT_BYTE_LEN-1:0] tx_data,           // data that should be send trough RS232
    input wire tx_data_ready,                            // required: setting to 1 when new data is ready to send
    output reg tx_data_copied,                           // short pulse means that data was copied _--_____--______--___
    output reg tx_busy                                   // tx notes that data is sending via RS232 or RS232 module awaiting flow-control synch
);

localparam reg [3:0] IDLE_EXCHANGE_STATE = 1;
localparam reg [3:0] SYNCH_WAIT_EXCHANGE_STATE = 2;
localparam reg [3:0] SYNCH_START_EXCHANGE_STATE = 3;
localparam reg [3:0] START_BIT_EXCHANGE_STATE = 4;
localparam reg [3:0] DATA_BITS_EXCHANGE_STATE = 5;
localparam reg [3:0] PARITY_BIT_EXCHANGE_STATE = 6;
localparam reg [3:0] PARITY_BIT_ANALYZE_STATE = 7;
localparam reg [3:0] PARITY_REMANENCE_TIMEOUT_WAIT_STATE = 8;
localparam reg [3:0] STOP_BITS_EXCHANGE_STATE = 9;
localparam reg [3:0] SYNCH_STOP_EXCHANGE_STATE = 10;

localparam reg [31:0] PARITY_ANALYZE_OFFSET = 64;

reg [31:0] TICKS_PER_UART_BIT;                           // = CLK_FREQ / DEFAULT_BAUD_RATE;
reg [31:0] HALF_TICKS_PER_UART_BIT;                      // = TICKS_PER_UART_BIT / 2;
reg [31:0] TOTAL_RX_TIMEOUT;

reg [3:0] tx_state;
reg [3:0] rx_state;
reg [DEFAULT_BYTE_LEN-1:0] tx_buffer;
reg [31:0] tx_bit_counter;
reg [31:0] tx_stop_bit_counter_limit;
reg [3:0]  tx_data_bit_counter;
reg tx_data_parity;
reg [DEFAULT_BYTE_LEN-1:0] rx_buffer;
wire rx_data_buffer_full;
reg [31:0] rx_bit_counter;
// reg [31:0] rx_stop_bit_counter_limit;
reg [31:0] rx_timeout;
reg [3:0]  rx_data_bit_counter;
reg [3:0] rx_parity_counter;
integer i;
integer j;

supply1 vcc;
supply0 gnd;


fifo #(.FIFO_SIZE(DEFAULT_RECV_BUFFER_LEN), .DATA_WIDTH(DEFAULT_BYTE_LEN)) 
rx_data_buffer (.clk(clk), .clear(rst), .push(rx_byte_received), .pop(rx_read), 
                .in_data(rx_buffer), .out_data(rx_data), .pushed_last(rx_data_buffer_full));


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
        rx_bit_counter <= 0;
        // rx_stop_bit_counter_limit <= 0;
        rx_data_bit_counter <= 0;
        rx_err <= 1'b0;
        TICKS_PER_UART_BIT <= CLK_TICKS_PER_RS232_BIT;
        HALF_TICKS_PER_UART_BIT <= CLK_TICKS_PER_RS232_BIT / 2;
        j <= 0;
        TOTAL_RX_TIMEOUT <= 6400; // ~ 9600 bit/s
        rx_timeout <= 0;
        rx_parity_counter <= 4'b0000;
    end
    else
    begin
        if (rx_state > SYNCH_START_EXCHANGE_STATE)
        begin
            rx_timeout <= rx_timeout + 1;
        end
        if (rx_timeout == TOTAL_RX_TIMEOUT)
        begin
            rx_state <= SYNCH_WAIT_EXCHANGE_STATE;
        end

        case (rx_state)
            IDLE_EXCHANGE_STATE:
            begin
                rx_state <= SYNCH_WAIT_EXCHANGE_STATE;
                cts <= 1'b0;
                rx_parity_counter <= 4'b0000;
            end
            SYNCH_WAIT_EXCHANGE_STATE:
            begin
                rx_err <= 1'b0;
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
                            rx_state <= SYNCH_START_EXCHANGE_STATE;
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
                // catch start from 1 to 0
                if (rx == 1'b0)
                begin
                    rx_timeout <= 0;
                    rx_state <= START_BIT_EXCHANGE_STATE;
                    rx_bit_counter <= 0;
                end
            end
            START_BIT_EXCHANGE_STATE:
            begin
                // wait until start is active
                rx_bit_counter <= rx_bit_counter + 1;
                if (rx_bit_counter == TICKS_PER_UART_BIT)
                begin
                   rx_state <= DATA_BITS_EXCHANGE_STATE;
                   rx_bit_counter <= 0;
                   rx_data_bit_counter <= 0;
                   rx_parity_counter <= 4'b0000;
                end
            end
            DATA_BITS_EXCHANGE_STATE:
            begin
                // wait all bytes ....
                // RX sends as LSB from 0 to 7 bit
                rx_bit_counter <= rx_bit_counter + 1;

                if (rx_data_bit_counter == DEFAULT_BYTE_LEN)
                begin
                    rx_bit_counter <= 0;
                    rx_data_bit_counter <= 0;
                    rx_state <= PARITY_BIT_EXCHANGE_STATE;
                end
                else
                begin
                    if (rx_bit_counter == TICKS_PER_UART_BIT - 64)  // ensure that we read corrected bit value quite away from boards
                    begin
                        rx_buffer[rx_data_bit_counter] <= rx;
                        if (rx == 1'b1)
                            rx_parity_counter <= rx_parity_counter + 4'b0001;
                    end
                
                    if (rx_bit_counter == TICKS_PER_UART_BIT)
                    begin
                        rx_bit_counter <= 0;
                        rx_data_bit_counter <= rx_data_bit_counter + 4'b0001;
                    end
                end
            end
            PARITY_BIT_EXCHANGE_STATE:
            begin
                rx_bit_counter <= rx_bit_counter + 1;
                if (rx_bit_counter == TICKS_PER_UART_BIT - PARITY_ANALYZE_OFFSET)
                begin
                    // check parity, if parity is bad generate error, don't store byte
                    case (DEFAULT_PARITY)
                        `NO_PARITY:
                        begin
                            rx_state <= PARITY_REMANENCE_TIMEOUT_WAIT_STATE;
                        end
                        `MARK_PARITY:
                        begin
                            if (rx != 1'b1)
                            begin
                                rx_err <= 1'b1;
                                rx_state <= PARITY_REMANENCE_TIMEOUT_WAIT_STATE;
                            end
                        end
                        `SPACE_PARITY:
                        begin
                            if (rx != 1'b0)
                            begin
                                rx_err <= 1'b1;
                                rx_state <= PARITY_REMANENCE_TIMEOUT_WAIT_STATE;
                            end
                        end
                        default:
                        begin
                            // using XOR in we have even value of 1, rx_data_parity is 1, otherwise - 0.
                            rx_state <= PARITY_BIT_ANALYZE_STATE;
                        end
                    endcase
                end
            end
            PARITY_BIT_ANALYZE_STATE:
            begin
                if (DEFAULT_PARITY == `EVEN_PARITY)
                begin
                    if (rx_parity_counter[0] == 1'b1)  // odd 1 counter
                    begin
                        if (rx == 1'b1)
                            rx_err <= 1'b0;
                        else
                            rx_err <= 1'b1;
                    end
                    else                            // even 1 counter
                    begin
                        if (rx == 1'b0) 
                            rx_err <= 1'b0;
                        else
                            rx_err <= 1'b1;
                    end
                end
                else
                begin
                    if (rx_parity_counter[0] == 1'b1)  // odd 1 counter
                    begin
                        if (rx == 1'b0)
                            rx_err <= 1'b0;
                        else
                            rx_err <= 1'b1;
                    end
                    else                            // even 1 counter
                    begin
                        if (rx == 1'b1) 
                            rx_err <= 1'b0;
                        else
                            rx_err <= 1'b1;
                    end
                end
                rx_state <= PARITY_REMANENCE_TIMEOUT_WAIT_STATE;
            end
            PARITY_REMANENCE_TIMEOUT_WAIT_STATE:
            begin
                rx_bit_counter <= rx_bit_counter + 1;
                if (rx_bit_counter == TICKS_PER_UART_BIT + 1)
                begin
                    rx_bit_counter <= 0;
                    rx_state <= STOP_BITS_EXCHANGE_STATE;
                end

                if (rx_err == 1'b0)
                begin
                    rx_byte_received <= 1'b1;
                end
            end
            STOP_BITS_EXCHANGE_STATE:
            begin
                if (rx == 1'b1)
                begin
                    rx_state <= SYNCH_STOP_EXCHANGE_STATE;
                end
            end
            SYNCH_STOP_EXCHANGE_STATE:
            begin
                rx_state <= SYNCH_WAIT_EXCHANGE_STATE;
                rx_byte_received <= 1'b0;
                rx_err <= 1'b0;
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
        tx_data_bit_counter <= 4'b0000;   // Data bit counter = 0
        tx_data_parity <= 1'b0;
        tx_stop_bit_counter_limit <= 0;
        i <= 0;
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
                    tx_data_bit_counter <=4'b0000;      // Data bit counter = 0
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
                if (tx_bit_counter >= TICKS_PER_UART_BIT)
                begin
                    tx_bit_counter <= 0;
                    tx_data_bit_counter <= 0;
                    tx_state <= DATA_BITS_EXCHANGE_STATE;
                end
            end
            DATA_BITS_EXCHANGE_STATE:
            begin
                if (tx_data_bit_counter == DEFAULT_BYTE_LEN)
                begin
                    tx_state <= PARITY_BIT_EXCHANGE_STATE;
                    tx_data_copied <= 1'b0;
                end
                else
                begin
                    tx <= tx_buffer[tx_data_bit_counter];
                    tx_bit_counter <= tx_bit_counter + 1;
                    if (tx_bit_counter >= TICKS_PER_UART_BIT)
                    begin
                        tx_bit_counter <= 0;
                        tx_data_bit_counter <= tx_data_bit_counter + 4'b0001;
                        if (tx_data_bit_counter == 0)
                        begin
                           tx_data_parity <= tx_buffer[0];
                        end
                        else
                        begin
                            tx_data_parity <= tx_data_parity ^ tx_buffer[tx_data_bit_counter];
                        end
                    end
                end
            end
            PARITY_BIT_EXCHANGE_STATE:
            begin
                if (tx_bit_counter == 0)
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
                            if (tx_data_parity == 1'b1)
                            begin
                                tx <= 1'b1;
                            end
                            else
                            begin
                                tx <= 1'b0;
                            end
                        end
                        `ODD_PARITY:
                        begin
                            if (tx_data_parity == 1'b1)
                            begin
                                tx <= 1'b0;
                            end
                            else
                            begin
                                tx <= 1'b1;
                            end
                        end
                    endcase
                end
                
                if (DEFAULT_PARITY != `NO_PARITY)
                begin
                    tx_bit_counter <= tx_bit_counter + 1;
                    if (tx_bit_counter == 1)
                    begin
                        if (DEFAULT_PARITY == `EVEN_PARITY)
                            tx <= tx_data_parity == 1'b0 ? 1'b0: 1'b1;
                        if (DEFAULT_PARITY == `ODD_PARITY)
                            tx <= tx_data_parity == 1'b0 ? 1'b1: 1'b0;
                    end
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
                if (tx_bit_counter >= tx_stop_bit_counter_limit)
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

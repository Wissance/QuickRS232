//////////////////////////////////////////////////////////////////////////////////
// Company:        Wissance (https://wissance.com)
// Engineer:       EvilLord666 (Ushakov MV)
// 
// Create Date:    22/12/2022 
// Design Name: 
// Module Name:    quick_rs232
// Project Name:   QuickRS232
// Target Devices: Any
// Tool versions:  Quartus Prime Lite 18.1
// Description:    RS-232 interface with Hardware Flow Control Support
//
// Dependencies:   
//
// Revision:      1.0   
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
// Parity bits
`define NO_PARITY    0
`define EVEN_PARITY  1
`define ODD_PARITY   2
`define MARK_PARITY  3
`define SPACE_PARITY 4
// Stop bits
`define ONE_STOP_BIT           0
`define ONE_AND_HALF_STOP_BITS 1
`define TWO_STOP_BITS          2
// Flow controls
`define NO_FLOW_CONTROL        0
`define CTS_RTS_FLOW_CONTROL   1
// Baud Rate


module quick_rs232 #(
    CLK_FREQ = 50000000,                    // clk input Frequency (Hz)
    DEFAULT_BYTE_LEN = 8,                   // RS232 byte length, available values are - 5, 6, 7, 8, 9
    DEFAULT_PARITY = `EVEN_PARITY,          // Parity: No, Even, Odd, Mark or Space
    DEFAULT_STOP_BITS = `ONE_STOP_BIT,      // Stop bits number: 0, 1.5 or 2
    DEFAULT_BAUD_RATE = 9600,               // Baud = Bit/s, supported values: 2400, 4800, 9600, 19200, 38400, 57600, or 115200
    DEFAULT_RECV_BUFFER_LEN = 16,           // Input (Rx) buffer size
    DEFAULT_FLOW_CONTROL = `NO_FLOW_CONTROL // Flow control type: NO, HARDWARE
)
(
    // Global Signals
    input wire clk,
    input wire rst,
    // External RS232 Interface
    input wire rx,
    output reg tx,
    output wire rts,
    input wire cts,
    // Interaction with inner module
    output reg [DEFAULT_BYTE_LEN-1:0] rx_data,
    output reg rx_hshake_byte_received,
    input wire rx_hshake_next_byte_ready,
    //
    input wire tx_transaction,                 //
    input wire [DEFAULT_BYTE_LEN-1:0] tx_data, // data that should be send trough RS232
    input wire tx_data_ready,                  // required: setting to 1 when new data is ready to send
    output reg tx_data_copied,                 // short pulse means that data was copied _--_____--______
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
reg tx_rts;
reg rx_rts;
reg [DEFAULT_BYTE_LEN-1:0] tx_buffer;
reg [31:0] tx_bit_counter;
reg [3:0]  tx_data_bit_counter;
reg tx_data_parity;
integer i;

assign rts = tx_rts || rx_rts; // Hardware Flow Controll

/*
 * Блок для чтения (rx) данных из RS232
 */
always @(posedge clk)
begin
    if (rst == 1'b1)
    begin
        // clear all data
        rx_state <= IDLE_EXCHANGE_STATE;
        rx_rts <= 1'b0;
    end
    else
    begin
        case (tx_state)
            IDLE_EXCHANGE_STATE:
            begin
            end
            SYNCH_WAIT_EXCHANGE_STATE:
            begin
            end
            SYNCH_START_EXCHANGE_STATE:
            begin
            end
            START_BIT_EXCHANGE_STATE:
            begin
            end
            DATA_BITS_EXCHANGE_STATE:
            begin
            end
            PARITY_BIT_EXCHANGE_STATE:
            begin
            end
            STOP_BITS_EXCHANGE_STATE:
            begin
            end
            SYNCH_STOP_EXCHANGE_STATE:
            begin
            end
        endcase
    end
end

/*
 * Блок для записи (tx) данных в RS232
 */
always @(posedge clk)
begin
    if (rst == 1'b1)
    begin
        // clear all data
        tx_state <= IDLE_EXCHANGE_STATE;
        tx_data_copied <= 1'b0;
        tx_busy <= 1'b0;
        tx_rts <= 1'b0;
        tx_buffer <= 0;
        tx_bit_counter <= 0;
        tx <= 1'b1;                       // IDLE state
        tx_data_bit_counter <= 1'b0;      // Data bit counter = 0
        tx_data_parity <= 1'b0;
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
                tx_state <= SYNCH_STOP_EXCHANGE_STATE;
                //todo(umv): implement stop bits send
            end
            SYNCH_STOP_EXCHANGE_STATE:
            begin
                tx_state <= IDLE_EXCHANGE_STATE;
                //todo(umv): implement byte transaction end ...
            end
        endcase
    end
end

endmodule

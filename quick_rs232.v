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
// Description:    RS-232 интерфейс с поддержкой аппаратного управления потоком
//
// Dependencies: 
//
// Revision: 
// Revision 1.0
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
// Parity bits
`define NO_PARITY   0
`define EVEN_PARITY 1
`define ODD_PARITY  2
// Stop bits
`define ONE_STOP_BIT           0
`define ONE_AND_HALF_STOP_BITS 1
`define TWO_STOP_BITS          2

module quick_rs232 #(
    DEFAULT_BYTE_LEN = 8,              // Возможные значения: - 5, 6, 7, 8, 9
    DEFAULT_PARITY = `EVEN_PARITY,     // Дополнение до четн
    DEFAULT_STOP_BITS = `ONE_STOP_BIT, // Число стоп-бит
    DEFAULT_BAUD_RATE = 9600,          // Скороть обмена бод = бит/с
    DEFAULT_RECV_BUFFER_LEN = 16       // Размер приемного буфера в байтах
)
(
    // Global Signals
    input wire clk,
    input wire rst,
    // External RS232 Interface
    input wire rx,
    output wire tx,
    output wire rts,
    input wire cts,
    // Interaction with inner module
    output reg [DEFAULT_BYTE_LEN-1:0] rx_data,
    output reg rx_hshake_byte_received,
    input wire rx_hshake_next_byte_ready,
    //
    input wire [DEFAULT_BYTE_LEN-1:0] tx_data,
    input wire tx_hshake_next_byte_ready, // setting to 1 when we have something in tx_data
    output reg tx_hshake_next_byte_send        // module set here 1 when tx_data was sent
);

localparam reg [3:0] IDLE_EXCHANGE_STATE = 1;
localparam reg [3:0] SYNCH_WAIT_EXCHANGE_STATE = 2;
localparam reg [3:0] SYNCH_START_EXCHANGE_STATE = 3;
localparam reg [3:0] START_BIT_EXCHANGE_STATE = 4;
localparam reg [3:0] DATA_BITS_EXCHANGE_STATE = 5;
localparam reg [3:0] PARITY_BIT_EXCHANGE_STATE = 6;
localparam reg [3:0] STOP_BITS_EXCHANGE_STATE = 7;
localparam reg [3:0] SYNCH_STOP_EXCHANGE_STATE = 8;

reg [3:0] tx_state;
reg [3:0] rx_state;


/*
 * Блок для чтения (rx) данных из RS232
 */
always @(posedge clk)
begin
    if (rst == 1'b1)
    begin
        // clear all data
        rx_state <= IDLE_EXCHANGE_STATE;
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

endmodule

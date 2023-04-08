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
    BYTE_LEN = 8,             // Возможные значения: - 5, 6, 7, 8, 9
    PARITY = `EVEN_PARITY,
    STOP_BITS = `ONE_STOP_BIT,
    RECV_BUFFER_LEN = 16      // 
)
(
    // Global Signals
    input wire clk,
    input wire rst,
    // RS232  Signals
    input wire rx,
    output wire tx,
    output wire rts,
    input wire cts
);

always @(posedge clk)
begin
    if (rst == 1'b1)
    begin
        // clear all data
    end
end

endmodule

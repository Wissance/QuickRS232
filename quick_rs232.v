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
module quick_rs232 #(
    INPUT_BUFFER_LEN = 16  // 
)
(
   // Global Signals
   input wire clk,
   input wire rst,
   // RS232  Signals
   input wire rx,
   output wire tx,
   output wire rts,
   input wire cts,
);

endmodule

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
// Dependencies:        
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


module quick_rs232_tb();

reg  clk;                                     // clk is a clock 
reg  rst;                                     // rst is a global reset system
reg  rx;                                      // rx  - receive  (1 bit line for receive data)
wire tx;                                      // tx  - transmit (1 bit line for transmit data)
reg  rts;                                     // rts - request to send PC sets rts == 1'b1 that indicates that there is a data for receive
wire cts;                                     // cts - clear to send (devices sets cts to 1
reg  rx_read;                                 // read next data portion __---______---_____
wire rx_err;
wire [7:0] rx_data;          // data portion
wire rx_byte_received;                        // generate short pulse when byre received __--___--___--___
reg  tx_transaction;                          // transaction if while tx_transaction == 1 we send data to PC
reg  [7:0] tx_data;          // data that should be send trough RS232
reg  tx_data_ready;                           // required: setting to 1 when new data is ready to send
wire tx_data_copied;                          // short pulse means that data was copied _--_____--______--___
wire tx_busy;

reg [31:0] counter;

quick_rs232 #(CLK_FREQ(50000000), DEFAULT_BYTE_LEN(8), DEFAULT_PARITY(1), DEFAULT_STOP_BITS(0),
              DEFAULT_BAUD_RATE(115200), DEFAULT_RECV_BUFFER_LEN(16), DEFAULT_FLOW_CONTROL(0)) 
serial_dev (.clk(clk), .rst(rst), .rx(rx), .tx(tx), .rts(rts), .cts(cts),
            .rx_read(rx_read), .rx_err(rx_err), .rx_data(rx_data), .rx_byte_received(rx_byte_received),
            .tx_transaction(tx_transaction), .tx_data_copied(tx_data_copied), .tx_busy(tx_busy));

initial
begin
    clk <= 0;
    counter <= 0;
    rst <= 0;
    #200
    rst <= 1;
    #200
    rst <= 0;
end

always
begin
    #20 clk <= ~clk;
    counter <= counter + 1;
    // 1. Full cycle: RX + TX ...
end

endmodule

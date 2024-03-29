`timescale 1ns / 1ps
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
wire [7:0] rx_data;                           // data portion
wire rx_byte_received;                        // generate short pulse when byre received __--___--___--___
reg  tx_transaction;                          // transaction if while tx_transaction == 1 we send data to PC
reg  [7:0] tx_data;                           // data that should be send trough RS232
reg  tx_data_ready;                           // required: setting to 1 when new data is ready to send
wire tx_data_copied;                          // short pulse means that data was copied _--_____--______--___
wire tx_busy;

reg [31:0] counter;

localparam reg[31:0] RS232_BIT_TICKS = 434; // 115200 bit/s at 50 MHz

quick_rs232 #(.CLK_TICKS_PER_RS232_BIT(RS232_BIT_TICKS), .DEFAULT_BYTE_LEN(8), .DEFAULT_PARITY(1), .DEFAULT_STOP_BITS(0),
              .DEFAULT_RECV_BUFFER_LEN(16), .DEFAULT_FLOW_CONTROL(0)) 
serial_dev (.clk(clk), .rst(rst), .rx(rx), .tx(tx), .rts(rts), .cts(cts),
            .rx_read(rx_read), .rx_err(rx_err), .rx_data(rx_data), .rx_byte_received(rx_byte_received),
            .tx_transaction(tx_transaction), .tx_data(tx_data), .tx_data_ready(tx_data_ready), 
            .tx_data_copied(tx_data_copied), .tx_busy(tx_busy));

initial
begin
    tx_transaction <= 0;
    tx_data_ready <= 0;
    tx_data <= 0;
    rx_read <= 0;
    clk <= 0;
    counter <= 0;
    rst <= 0;
    rx <= 1;
    rts <= 0;
    #200
    rst <= 1;
    #200
    rst <= 0;
end

always
begin
    #10 clk <= ~clk; // 50 MHz
    counter <= counter + 1;
    // 1. RX (reading byte without an error)
    // 1.1 Sending Start bit
    if (counter == 100)
    begin
        rx <= 1'b0;
    end
    // 1.2 Sending Data bits 8'b01010011
    // b0
    if (counter == 2 * RS232_BIT_TICKS + 100)  // we multiply on 2 because counter changes twice a period
    begin
       rx <= 1'b1;
    end
    // b1
    if (counter == 2 * 2 * RS232_BIT_TICKS + 100)
    begin
       rx <= 1'b1;
    end
    // b2
    if (counter == 2 * 3 * RS232_BIT_TICKS + 100)
    begin
       rx <= 1'b0;
    end
    // b3
    if (counter == 2 * 4 * RS232_BIT_TICKS + 100)
    begin
       rx <= 1'b0;
    end
    // b4
    if (counter == 2 * 5 * RS232_BIT_TICKS + 100)
    begin
       rx <= 1'b1;
    end
    // b5
    if (counter == 2 * 6 * RS232_BIT_TICKS + 100)
    begin
       rx <= 1'b0;
    end
    // b6
    if (counter == 2 * 7 * RS232_BIT_TICKS + 100)
    begin
       rx <= 1'b1;
    end
    // b7
    if (counter == 2 * 8 * RS232_BIT_TICKS + 100)
    begin
       rx <= 1'b0;
    end
    // 1.3 Sending Parity (even)
    if (counter == 2 * 9 * RS232_BIT_TICKS + 100)
    begin
       rx <= 1'b0;
    end
    // 1.4 Sending Stop bit
    if (counter == 2 * 10 * RS232_BIT_TICKS + 100)
    begin
       rx <= 1'b1;
    end
    // 1.5 ASSERT on first byte
    if (counter > 2 * 8 * RS232_BIT_TICKS + 100 && counter < 2 * 10 * RS232_BIT_TICKS + 100)
    begin
        `ASSERT(rx_err, 1'b0)
    end
    if (counter == 2 * 10 * RS232_BIT_TICKS + 200)
    begin
        rx_read <= 1;
    end
    if (counter == 2 * 10 * RS232_BIT_TICKS + 200 + 2)
    begin
        rx_read <= 0;
    end
    if (counter == 2 * 10 * RS232_BIT_TICKS + 200 + 10)
    begin
        `ASSERT(rx_data, 8'b01010011)
    end
    if (counter == 2 * 10 * RS232_BIT_TICKS + 300)
    begin
        rx_read <= 0;
    end
    // 2. Reading next byte
    // 2.1 Sending Start
    if (counter == 2 * 15* RS232_BIT_TICKS)
    begin
        rx <= 1'b0;
    end
    // 2.2 Sending Data bits 8'b10010100
    // b0
    if (counter == 2 * 16* RS232_BIT_TICKS)  // we multiply on 2 because counter changes twice a period
    begin
       rx <= 1'b0;
    end
    // b1
    if (counter == 2 * 17 * RS232_BIT_TICKS)
    begin
       rx <= 1'b0;
    end
    // b2
    if (counter == 2 * 18 * RS232_BIT_TICKS)
    begin
       rx <= 1'b1;
    end
    // b3
    if (counter == 2 * 19 * RS232_BIT_TICKS)
    begin
       rx <= 1'b0;
    end
    // b4
    if (counter == 2 * 20 * RS232_BIT_TICKS)
    begin
       rx <= 1'b1;
    end
    // b5
    if (counter == 2 * 21 * RS232_BIT_TICKS)
    begin
       rx <= 1'b0;
    end
    // b6
    if (counter == 2 * 22 * RS232_BIT_TICKS)
    begin
       rx <= 1'b0;
    end
    // b7
    if (counter == 2 * 23 * RS232_BIT_TICKS)
    begin
       rx <= 1'b1;
    end
    // 2.3 Sending Parity (even)
    if (counter == 2 * 24 * RS232_BIT_TICKS)
    begin
       rx <= 1'b1;
    end
    // 2.4 Sending Stop bit
    if (counter == 2 * 25 * RS232_BIT_TICKS)
    begin
       rx <= 1'b1;
    end
    // 2.5 ASSERT on first byte
    if (counter > 2 * 23 * RS232_BIT_TICKS&& counter < 2 * 25 * RS232_BIT_TICKS)
    begin
        //`ASSERT(rx_err, 1'b0)
    end
    if (counter == 2 * 26 * RS232_BIT_TICKS)
    begin
        rx_read <= 1;
    end
    if (counter == 2 * 26 * RS232_BIT_TICKS + 2)
    begin
        //`ASSERT(rx_data, 8'b10010100)
    end
    if (counter == 2 * 26 * RS232_BIT_TICKS + 52)
    begin
        rx_read <= 0;
    end
    // 3. TX (transmit data in a Full-Duplex mode (parallel to RX)
    if (counter == 2 * 8 * RS232_BIT_TICKS)
    begin
        tx_transaction <= 1;
        tx_data_ready <= 1;
        tx_data <= 8'b10001100;
    end
    if (counter == 2 * 9 * RS232_BIT_TICKS)
    begin
        tx_data_ready <= 0;
        tx_data <= 8'b00000000;
    end
    if (counter == 2 * 23 * RS232_BIT_TICKS)
    begin
        tx_transaction <= 0;
    end
end

endmodule

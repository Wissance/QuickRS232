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
localparam reg[31:0] EXCHANGE_OFFSET = 100;

quick_rs232 #(.CLK_TICKS_PER_RS232_BIT(RS232_BIT_TICKS), .DEFAULT_BYTE_LEN(8), .DEFAULT_PARITY(1), .DEFAULT_STOP_BITS(0),
              .DEFAULT_RECV_BUFFER_LEN(32), .DEFAULT_FLOW_CONTROL(0)) 
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
    if (counter == EXCHANGE_OFFSET)
    begin
        rx <= 1'b0;
    end
    // 1.2 Sending Data bits 8'b01010011
    // b0
    if (counter == 2 * 1 * RS232_BIT_TICKS + EXCHANGE_OFFSET)  // we multiply on 2 because counter changes twice a period
    begin
       rx <= 1'b1;
    end
    // b1
    if (counter == 2 * 2 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b2
    if (counter == 2 * 3 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b3
    if (counter == 2 * 4 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b4
    if (counter == 2 * 5 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b5
    if (counter == 2 * 6 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b6
    if (counter == 2 * 7 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b7
    if (counter == 2 * 8 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // 1.3 Sending Parity (even)
    if (counter == 2 * 9 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // 1.4 Sending Stop bit
    if (counter == 2 * 10 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // 1.5 ASSERT on first byte
    if (counter > 2 * 8 * RS232_BIT_TICKS + EXCHANGE_OFFSET && 
        counter < 2 * 10 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
        `ASSERT(rx_err, 1'b0)
    end 
    if (counter == 2 * 10 * RS232_BIT_TICKS + 2 * EXCHANGE_OFFSET)
    begin
        rx_read <= 1;
    end
    if (counter == 2 * 10 * RS232_BIT_TICKS + 2 * EXCHANGE_OFFSET + 2)
    begin
        rx_read <= 0;
    end
    if (counter == 2 * 10 * RS232_BIT_TICKS + 2 * EXCHANGE_OFFSET + 10)
    begin
        `ASSERT(rx_data, 8'b01010011)
    end
    if (counter == 2 * 10 * RS232_BIT_TICKS + 3 * EXCHANGE_OFFSET)
    begin
        rx_read <= 0;
    end
    // 2. Reading next byte
    // 2.1 Sending Start
    if (counter == 2 * 15 * RS232_BIT_TICKS)
    begin
        rx <= 1'b0;
    end
    // 2.2 Sending Data bits 8'b10010100
    // b0
    if (counter == 2 * 16 * RS232_BIT_TICKS)  // we multiply on 2 because counter changes twice a period
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
        `ASSERT(rx_err, 1'b0)
    end
    if (counter == 2 * 26 * RS232_BIT_TICKS)
    begin
        rx_read <= 1;
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

    // 4 Sending all zeroes 0x00
    // 4.1 Sending Start bit
    if (counter == 2 * 40 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
        rx <= 1'b0;
    end
    // 4.2 Sending Data bits 8'b01010011
    // b0
    if (counter == 2 * 41 * RS232_BIT_TICKS + EXCHANGE_OFFSET)  // we multiply on 2 because counter changes twice a period
    begin
       rx <= 1'b0;
    end
    // b1
    if (counter == 2 * 42 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b2
    if (counter == 2 * 43 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b3
    if (counter == 2 * 44 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b4
    if (counter == 2 * 45 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b5
    if (counter == 2 * 46 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b6
    if (counter == 2 * 47 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b7
    if (counter == 2 * 48 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // 4.3 Sending Parity (even)
    if (counter == 2 * 49 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // 4.4 Sending Stop bit
    if (counter == 2 * 50 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // 4.5 Asserting
    if (counter > 2 * 49 * RS232_BIT_TICKS&& counter < 2 * 53 * RS232_BIT_TICKS)
    begin
        `ASSERT(rx_err, 1'b0)
    end
    // 4.6 Read 0x00 and ASSERT
    if (counter == 2 * 52 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
        rx_read <= 1;
    end
    if (counter == 2 * 52 * RS232_BIT_TICKS + EXCHANGE_OFFSET + 50)
    begin
        rx_read <= 0;
        `ASSERT(rx_data, 8'b00000000)
    end
    // 5. Send series of bytes, command 0xFF 0xFF 0x00 0x02 0x02 0x03 0xEE 0xEE (Read Reg 3)
    // 5.1 First  SOF byte - 0xFF
    // start bit
    if (counter == 2 * 100 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
        rx <= 1'b0; 
    end
    // b0
    if (counter == 2 * 101 * RS232_BIT_TICKS + EXCHANGE_OFFSET)  // we multiply on 2 because counter changes twice a period
    begin
       rx <= 1'b1;
    end
    // b1
    if (counter == 2 * 102 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b2
    if (counter == 2 * 103 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b3
    if (counter == 2 * 104 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b4
    if (counter == 2 * 105 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b5
    if (counter == 2 * 106 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b6
    if (counter == 2 * 107 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b7
    if (counter == 2 * 108 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // parity (even)
    if (counter == 2 * 109 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // stop bit
    if (counter == 2 * 110 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // 5.2 Second SOF byte - 0xFF
    // start bit
    if (counter == 2 * 111 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
        rx <= 1'b0; 
    end
    // b0
    if (counter == 2 * 112 * RS232_BIT_TICKS + EXCHANGE_OFFSET)  // we multiply on 2 because counter changes twice a period
    begin
       rx <= 1'b1;
    end
    // b1
    if (counter == 2 * 113 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b2
    if (counter == 2 * 114 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b3
    if (counter == 2 * 115 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b4
    if (counter == 2 * 116 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b5
    if (counter == 2 * 117 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b6
    if (counter == 2 * 118 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b7
    if (counter == 2 * 119 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // parity (even)
    if (counter == 2 * 120 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // stop bit
    if (counter == 2 * 121 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // 5.3 Space byte - 0x00
    // start bit
    if (counter == 2 * 122 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
        rx <= 1'b0; 
    end
    // b0
    if (counter == 2 * 123 * RS232_BIT_TICKS + EXCHANGE_OFFSET)  // we multiply on 2 because counter changes twice a period
    begin
       rx <= 1'b0;
    end
    // b1
    if (counter == 2 * 124 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b2
    if (counter == 2 * 125 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b3
    if (counter == 2 * 126 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b4
    if (counter == 2 * 127 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b5
    if (counter == 2 * 128 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b6
    if (counter == 2 * 129 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b7
    if (counter == 2 * 130 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // parity (even)
    if (counter == 2 * 131 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // stop bit
    if (counter == 2 * 132 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // 5.4 Payload len byte - 0x02
    // start bit
    if (counter == 2 * 133 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
        rx <= 1'b0; 
    end
    // b0
    if (counter == 2 * 134 * RS232_BIT_TICKS + EXCHANGE_OFFSET)  // we multiply on 2 because counter changes twice a period
    begin
       rx <= 1'b0;
    end
    // b1
    if (counter == 2 * 135 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b2
    if (counter == 2 * 136 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b3
    if (counter == 2 * 137 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b4
    if (counter == 2 * 138 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b5
    if (counter == 2 * 139 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b6
    if (counter == 2 * 140 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b7
    if (counter == 2 * 141 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // parity (even)
    if (counter == 2 * 142 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // stop bit
    if (counter == 2 * 143 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // 5.5 Payload bytes - 0x02 0x03
    // 0x02
    // start bit
    if (counter == 2 * 144 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
        rx <= 1'b0; 
    end
    // b0
    if (counter == 2 * 145 * RS232_BIT_TICKS + EXCHANGE_OFFSET)  // we multiply on 2 because counter changes twice a period
    begin
       rx <= 1'b0;
    end
    // b1
    if (counter == 2 * 146 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b2
    if (counter == 2 * 147 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b3
    if (counter == 2 * 148 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b4
    if (counter == 2 * 149 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b5
    if (counter == 2 * 150 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b6
    if (counter == 2 * 151 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b7
    if (counter == 2 * 152 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // parity (even)
    if (counter == 2 * 153 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // stop bit
    if (counter == 2 * 154 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end

    // 0x03
    // start bit
    if (counter == 2 * 155 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
        rx <= 1'b0; 
    end
    // b0
    if (counter == 2 * 156 * RS232_BIT_TICKS + EXCHANGE_OFFSET)  // we multiply on 2 because counter changes twice a period
    begin
       rx <= 1'b1;
    end
    // b1
    if (counter == 2 * 157 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b2
    if (counter == 2 * 158 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b3
    if (counter == 2 * 159 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b4
    if (counter == 2 * 160 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b5
    if (counter == 2 * 161 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b6
    if (counter == 2 * 162 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b7
    if (counter == 2 * 163 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // parity (even)
    if (counter == 2 * 164 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // stop bit
    if (counter == 2 * 165 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // 5.6 First  EOF byte - 0xEE
    // start bit
    if (counter == 2 * 166 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
        rx <= 1'b0; 
    end
    // b0
    if (counter == 2 * 167 * RS232_BIT_TICKS + EXCHANGE_OFFSET)  // we multiply on 2 because counter changes twice a period
    begin
       rx <= 1'b0;
    end
    // b1
    if (counter == 2 * 168 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b2
    if (counter == 2 * 169 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b3
    if (counter == 2 * 170 * RS232_BIT_TICKS +EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b4
    if (counter == 2 * 171 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b5
    if (counter == 2 * 172 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b6
    if (counter == 2 * 173 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b7
    if (counter == 2 * 174 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // parity (even)
    if (counter == 2 * 175 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // stop bit
    if (counter == 2 * 176 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // 5.7 Second EOF byte - 0xEE
    // start bit
    if (counter == 2 * 177 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
        rx <= 1'b0; 
    end
    // b0
    if (counter == 2 * 178 * RS232_BIT_TICKS + EXCHANGE_OFFSET)  // we multiply on 2 because counter changes twice a period
    begin
       rx <= 1'b0;
    end
    // b1
    if (counter == 2 * 179 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b2
    if (counter == 2 * 180 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b3
    if (counter == 2 * 181 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b4
    if (counter == 2 * 182 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // b5
    if (counter == 2 * 183 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b6
    if (counter == 2 * 184 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // b7
    if (counter == 2 * 185 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
    // parity (even)
    if (counter == 2 * 186 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b0;
    end
    // stop bit
    if (counter == 2 * 187 * RS232_BIT_TICKS + EXCHANGE_OFFSET)
    begin
       rx <= 1'b1;
    end
end

endmodule

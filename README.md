## QuickRS232
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/wissance/QuickRS232?style=plastic) 
![GitHub issues](https://img.shields.io/github/issues/wissance/QuickRS232?style=plastic)
![GitHub Release Date](https://img.shields.io/github/release-date/wissance/QuickRS232?style=plastic)
![GitHub release (latest by date)](https://img.shields.io/github/downloads/wissance/QuickRS232/v0.9/total?style=plastic)

`QuickRS232` is a versatile `RS232` `FPGA` `Verilog` module with following features:
* ***Internal data buffering*** with `FIFO` builtin in `RS232` with parametric `FIFO` depth;
* ***Full-duplex mode*** (as `RS232` standard supports) with parallel Receive (`Rx`) and Transmit (`Tx`);
* Supports ***either `No Flow Control` mode or Hardware Flow Control*** mode (`RTS + CTS`);

`RS232` timing diagrams (`115200 bod/s`, `even parity`, `no flow control`):

![RS232 Timing diagrams](/img/rs232_full_duplex_mode.png)

`FIFO` timing diagrams

![FIFO Timing diagrams](/img/fifo_diagrams.png)


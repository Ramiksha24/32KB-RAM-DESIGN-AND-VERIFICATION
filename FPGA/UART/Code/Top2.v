`timescale 1ns / 1ps
// =============================================================================
// Module  : top
// Version : v4 - UART interface
// Target  : Artix-7 XC7A50T FTG256 (Arty A7) @ 100 MHz
//
// Connections:
//   uart_rx  ? ram_controller (rx_data, rx_valid)
//   ram_controller ? uart_tx  (tx_data, tx_start)
//   ram_controller ? ram_32kb (we, addr, din, dout)
// =============================================================================
module top2 (
    input  wire clk_100mhz,     // 100 MHz onboard oscillator - pin E3
    input  wire rst_btn,        // Active-HIGH reset - BTNC pin D9

    // UART pins (routed to FT2232H USB-UART on Arty A7)
    input  wire uart_rxd_out,   // PC ? FPGA  (FPGA receives)
    output wire uart_txd_in,    // FPGA ? PC  (FPGA transmits)

    // LEDs
    output wire led_pass,       // LD0 - solid ON = PASS
    output wire led_fail,       // LD1 - blinking = FAIL
    output wire [3:0] led_state // LD3:LD0 on RGB or spare LEDs - FSM phase debug
);

    // =========================================================================
    // Internal wires
    // =========================================================================

    // UART RX ? Controller
    wire [7:0] rx_data;
    wire       rx_valid;

    // Controller ? UART TX
    wire [7:0] tx_data;
    wire       tx_start;
    wire       tx_busy;

    // Controller ? RAM
    wire        we;
    wire [14:0] addr;
    wire [7:0]  din;
    wire [7:0]  dout;

    // =========================================================================
    // UART RX
    // =========================================================================
    uart_rx u_rx (
        .clk      (clk_100mhz),
        .rst      (rst_btn),
        .rx       (uart_rxd_out),
        .rx_data  (rx_data),
        .rx_valid (rx_valid)
    );

    // =========================================================================
    // UART TX
    // =========================================================================
    uart_tx u_tx (
        .clk      (clk_100mhz),
        .rst      (rst_btn),
        .tx_data  (tx_data),
        .tx_start (tx_start),
        .tx       (uart_txd_in),
        .tx_busy  (tx_busy)
    );

    // =========================================================================
    // 32KB RAM
    // =========================================================================
    ram_32kb u_ram (
        .clk  (clk_100mhz),
        .we   (we),
        .addr (addr),
        .din  (din),
        .dout (dout)
    );

    // =========================================================================
    // FSM Controller
    // =========================================================================
    ram2_controller u_ctrl (
        .clk       (clk_100mhz),
        .rst       (rst_btn),
        .rx_data   (rx_data),
        .rx_valid  (rx_valid),
        .tx_data   (tx_data),
        .tx_start  (tx_start),
        .tx_busy   (tx_busy),
        .we        (we),
        .addr      (addr),
        .din       (din),
        .dout      (dout),
        .led_pass  (led_pass),
        .led_fail  (led_fail),
        .led_state (led_state)
    );

endmodule
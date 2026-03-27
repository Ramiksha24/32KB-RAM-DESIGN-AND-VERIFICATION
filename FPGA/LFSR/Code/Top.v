`timescale 1ns/1ps

module top (
    input  wire clk_100mhz,     // 100 MHz onboard oscillator (pin E3, Arty A7)
    input  wire rst_btn,        // Active-HIGH reset button (e.g. BTNC)

    output wire led_pass,       // LED0: Solid ON  = PASS
    output wire led_fail        // LED1: Blinking  = FAIL
);

    wire        we;
    wire [14:0] addr;
    wire [7:0]  din;
    wire [7:0]  dout;

    ram_32kb u_ram (
        .clk  (clk_100mhz),
        .we   (we),
        .addr (addr),
        .din  (din),
        .dout (dout)
    );

    ram_controller u_ctrl (
        .clk      (clk_100mhz),
        .rst      (rst_btn),        // Active-HIGH
        .we       (we),
        .addr     (addr),
        .din      (din),
        .dout     (dout),
        .led_pass (led_pass),
        .led_fail (led_fail)
    );

endmodule

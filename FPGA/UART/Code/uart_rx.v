`timescale 1ns / 1ps

module uart_rx (
    input  wire       clk,
    input  wire       rst,          // Active-HIGH synchronous reset
    input  wire       rx,           // UART RX pin (from USB-UART chip)
    output reg  [7:0] rx_data,      // Received byte
    output reg        rx_valid      // 1-cycle pulse when rx_data is valid
);

    localparam CLK_FREQ    = 100_000_000;
    localparam BAUD_RATE   = 115_200;
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;    // 868
    localparam HALF_BIT    = CLKS_PER_BIT / 2;         // 434 - sample mid-bit

    localparam [1:0]
        RX_IDLE  = 2'd0,
        RX_START = 2'd1,
        RX_DATA  = 2'd2,
        RX_STOP  = 2'd3;

    reg [1:0]  state;
    reg [9:0]  clk_cnt;     // Counts up to CLKS_PER_BIT
    reg [2:0]  bit_idx;     // Which data bit we're receiving (0-7)
    reg [7:0]  rx_shift;    // Shift register

    reg rx_sync0, rx_sync1;
    always @(posedge clk) begin
        rx_sync0 <= rx;
        rx_sync1 <= rx_sync0;
    end
    wire rx_in = rx_sync1;

    always @(posedge clk) begin
        if (rst) begin
            state    <= RX_IDLE;
            clk_cnt  <= 10'd0;
            bit_idx  <= 3'd0;
            rx_shift <= 8'd0;
            rx_data  <= 8'd0;
            rx_valid <= 1'b0;

        end else begin
            rx_valid <= 1'b0;       // Default: not valid

            case (state)

                // Wait for start bit (falling edge on RX)
                RX_IDLE: begin
                    clk_cnt <= 10'd0;
                    bit_idx <= 3'd0;
                    if (rx_in == 1'b0)          // Start bit detected
                        state <= RX_START;
                end

                // Wait to middle of start bit to confirm it's real
                RX_START: begin
                    if (clk_cnt == HALF_BIT - 1) begin
                        if (rx_in == 1'b0) begin    // Still low - valid start
                            clk_cnt <= 10'd0;
                            state   <= RX_DATA;
                        end else begin              // Glitch - back to idle
                            state <= RX_IDLE;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // Sample each data bit at the middle of its bit period
                RX_DATA: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt            <= 10'd0;
                        rx_shift[bit_idx]  <= rx_in;   // LSB first (UART standard)

                        if (bit_idx == 3'd7) begin
                            bit_idx <= 3'd0;
                            state   <= RX_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // Wait through stop bit, then output the byte
                RX_STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        rx_valid <= 1'b1;
                        rx_data  <= rx_shift;
                        clk_cnt  <= 10'd0;
                        state    <= RX_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                default: state <= RX_IDLE;
            endcase
        end
    end

endmodule

`timescale 1ns / 1ps
// =============================================================================
// Module  : uart_tx
// Baud    : 115200
// Clock   : 100 MHz  ? clks_per_bit = 868
// Format  : 8N1
//
// Input   : tx_data   - byte to send
//           tx_start  - pulse HIGH for 1 clock to begin transmission
// Output  : tx        - UART TX pin (to USB-UART chip)
//           tx_busy   - HIGH while transmitting (do not assert tx_start)
// =============================================================================
module uart_tx (
    input  wire       clk,
    input  wire       rst,          // Active-HIGH synchronous reset
    input  wire [7:0] tx_data,      // Byte to transmit
    input  wire       tx_start,     // 1-cycle pulse to begin
    output reg        tx,           // UART TX pin
    output reg        tx_busy       // HIGH while transmitting
);

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam CLK_FREQ     = 100_000_000;
    localparam BAUD_RATE    = 115_200;
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;    // 868

    // =========================================================================
    // FSM states
    // =========================================================================
    localparam [1:0]
        TX_IDLE  = 2'd0,
        TX_START = 2'd1,
        TX_DATA  = 2'd2,
        TX_STOP  = 2'd3;

    reg [1:0]  state;
    reg [9:0]  clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  tx_shift;    // Holds byte being shifted out

    // =========================================================================
    // FSM
    // =========================================================================
    always @(posedge clk) begin
        if (rst) begin
            state    <= TX_IDLE;
            tx       <= 1'b1;       // Line idle = HIGH
            tx_busy  <= 1'b0;
            clk_cnt  <= 10'd0;
            bit_idx  <= 3'd0;
            tx_shift <= 8'd0;

        end else begin
            case (state)

                TX_IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    clk_cnt <= 10'd0;
                    bit_idx <= 3'd0;

                    if (tx_start) begin
                        tx_shift <= tx_data;
                        tx_busy  <= 1'b1;
                        state    <= TX_START;
                    end
                end

                // Drive start bit (LOW) for one full bit period
                TX_START: begin
                    tx <= 1'b0;
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 10'd0;
                        state   <= TX_DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // Shift out 8 data bits, LSB first
                TX_DATA: begin
                    tx <= tx_shift[bit_idx];
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 10'd0;
                        if (bit_idx == 3'd7) begin
                            bit_idx <= 3'd0;
                            state   <= TX_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // Drive stop bit (HIGH) for one full bit period
                TX_STOP: begin
                    tx <= 1'b1;
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 10'd0;
                        tx_busy <= 1'b0;
                        state   <= TX_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                default: begin
                    tx    <= 1'b1;
                    state <= TX_IDLE;
                end
            endcase
        end
    end

endmodule

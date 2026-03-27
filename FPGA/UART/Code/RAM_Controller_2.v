`timescale 1ns / 1ps

//   PHASE 1 - RECEIVE  : Accept 32768 raw bytes from PC over UART
//                         Write each byte to RAM as it arrives
//   PHASE 2 - READ     : Read all 32768 bytes back from RAM
//   PHASE 3 - COMPARE  : Compare read data vs shadow BRAM (written during RX)
//   PHASE 4 - SEND     : Stream all 32768 read-back bytes back to PC over UART
//                         Then send 1 result byte: 0x50='P' (PASS) or 0x46='F' (FAIL)
//   - Two READ wait states (S_READ_W1, S_READ_W2) for correct BRAM output timing
//   - Shadow BRAM stores exact bytes written - no LFSR drift possible
//   - Active-HIGH synchronous reset
//   - 100 MHz clock
// =============================================================================
module ram2_controller (
    input  wire        clk,
    input  wire        rst,             // Active-HIGH synchronous reset


    input  wire [7:0]  rx_data,         // Received byte
    input  wire        rx_valid,        // 1-cycle pulse when rx_data is valid

    output reg  [7:0]  tx_data,         // Byte to transmit
    output reg         tx_start,        // 1-cycle pulse to start TX
    input  wire        tx_busy,         // HIGH while TX in progress

    output reg         we,
    output reg  [14:0] addr,
    output reg  [7:0]  din,
    input  wire [7:0]  dout,


    output reg         led_pass,        // Solid ON  = PASS
    output reg         led_fail,        // Blinking  = FAIL
    output reg  [3:0]  led_state        // Shows current FSM phase (debug)
);


    localparam [3:0]
        S_IDLE      = 4'd0,
        S_RX_WRITE  = 4'd1,    // Receive byte from UART, write to RAM + shadow
        S_WRITE_W   = 4'd2,    // 1-cycle write settle
        S_READ      = 4'd3,    // Present addr to both BRAMs
        S_READ_W1   = 4'd4,    // Wait: BRAMs latch addr internally
        S_READ_W2   = 4'd5,    // Wait: dout valid - latch here
        S_COMPARE   = 4'd6,    // Compare main vs shadow, check mismatch
        S_TX_WAIT   = 4'd7,    // Wait for TX to be free
        S_TX_SEND   = 4'd8,    // Send one read-back byte over UART
        S_TX_RESULT = 4'd9,    // Send final result byte: 'P' or 'F'
        S_DONE      = 4'd10;

    reg [3:0] state;

    reg [14:0] addr_cnt;

    reg [7:0]  shadow_mem [0:32767];
    reg        shadow_we;
    reg [14:0] shadow_waddr;
    reg [7:0]  shadow_wdata;
    reg [14:0] shadow_raddr;
    reg [7:0]  shadow_dout;

    always @(posedge clk) begin
        if (shadow_we)
            shadow_mem[shadow_waddr] <= shadow_wdata;
        shadow_dout <= shadow_mem[shadow_raddr];
    end

    reg [7:0] main_dout_lat;
    reg [7:0] shad_dout_lat;

    reg        mismatch;
    reg [14:0] mismatch_cnt;


    reg [7:0] tx_buf;


    reg [24:0] blink_cnt;
    reg        blink_tog;

    always @(posedge clk) begin
        if (rst) begin
            state         <= S_IDLE;
            addr_cnt      <= 15'd0;
            mismatch      <= 1'b0;
            mismatch_cnt  <= 15'd0;
            we            <= 1'b0;
            addr          <= 15'd0;
            din           <= 8'd0;
            shadow_we     <= 1'b0;
            shadow_waddr  <= 15'd0;
            shadow_wdata  <= 8'd0;
            shadow_raddr  <= 15'd0;
            main_dout_lat <= 8'd0;
            shad_dout_lat <= 8'd0;
            tx_data       <= 8'd0;
            tx_start      <= 1'b0;
            tx_buf        <= 8'd0;
            led_pass      <= 1'b0;
            led_fail      <= 1'b0;
            led_state     <= 4'd0;
            blink_cnt     <= 25'd0;
            blink_tog     <= 1'b0;

        end else begin

  
            blink_cnt <= blink_cnt + 1'b1;
            if (blink_cnt == 25'd0)
                blink_tog <= ~blink_tog;

            // Defaults (deassert strobes)
            tx_start  <= 1'b0;
            shadow_we <= 1'b0;
            we        <= 1'b0;

            case (state)

         
                S_IDLE: begin
                    addr_cnt     <= 15'd0;
                    mismatch     <= 1'b0;
                    mismatch_cnt <= 15'd0;
                    led_state    <= 4'd0;
                    state        <= S_RX_WRITE;
                end

                // =============================================================
                // PHASE 1 - RECEIVE + WRITE
                // Wait for rx_valid pulse, write byte to RAM and shadow BRAM
                // =============================================================
                S_RX_WRITE: begin
                    led_state <= 4'd1;

                    if (rx_valid) begin
                        // Write received byte to main RAM
                        we    <= 1'b1;
                        addr  <= addr_cnt;
                        din   <= rx_data;

                        // Write same byte to shadow BRAM
                        shadow_we    <= 1'b1;
                        shadow_waddr <= addr_cnt;
                        shadow_wdata <= rx_data;

                        state <= S_WRITE_W;
                    end
                end

                S_WRITE_W: begin
                    we        <= 1'b0;
                    shadow_we <= 1'b0;

                    if (addr_cnt == 15'd32767) begin
                        addr_cnt <= 15'd0;
                        state    <= S_READ;         // All bytes received ? READ phase
                    end else begin
                        addr_cnt <= addr_cnt + 1'b1;
                        state    <= S_RX_WRITE;     // Wait for next byte
                    end
                end

                // =============================================================
                // PHASE 2 - READ (with correct 2-wait-state timing)
                // =============================================================
                S_READ: begin
                    led_state    <= 4'd2;
                    we           <= 1'b0;
                    addr         <= addr_cnt;
                    shadow_raddr <= addr_cnt;
                    state        <= S_READ_W1;
                end

                // BRAM registers addr on this posedge - just wait
                S_READ_W1: begin
                    state <= S_READ_W2;
                end

                // dout is NOW valid for addr_cnt - latch before addr changes
                S_READ_W2: begin
                    main_dout_lat <= dout;
                    shad_dout_lat <= shadow_dout;
                    state         <= S_COMPARE;
                end

                // =============================================================
                // PHASE 3 - COMPARE
                // =============================================================
                S_COMPARE: begin
                    led_state <= 4'd3;

                    if (main_dout_lat != shad_dout_lat) begin
                        mismatch     <= 1'b1;
                        mismatch_cnt <= mismatch_cnt + 1'b1;
                    end

                    // Store read-back byte for TX phase
                    tx_buf <= main_dout_lat;

                    // Move to TX - send this read-back byte to PC
                    state <= S_TX_WAIT;
                end

                // =============================================================
                // PHASE 4 - SEND read-back bytes to PC
                // =============================================================
                S_TX_WAIT: begin
                    led_state <= 4'd4;
                    if (!tx_busy)
                        state <= S_TX_SEND;
                end

                S_TX_SEND: begin
                    tx_data  <= tx_buf;
                    tx_start <= 1'b1;

                    if (addr_cnt == 15'd32767) begin
                        addr_cnt <= 15'd0;
                        state    <= S_TX_RESULT;    // All bytes sent ? send result
                    end else begin
                        addr_cnt <= addr_cnt + 1'b1;
                        state    <= S_READ;          // Read + send next byte
                    end
                end

                // =============================================================
                // Send final result byte: 0x50 = 'P' (PASS), 0x46 = 'F' (FAIL)
                // =============================================================
                S_TX_RESULT: begin
                    led_state <= 4'd5;
                    if (!tx_busy) begin
                        tx_data  <= mismatch ? 8'h46 : 8'h50;  // 'F' or 'P'
                        tx_start <= 1'b1;
                        state    <= S_DONE;
                    end
                end

                S_DONE: begin
                    led_state <= 4'd6;
                    if (!mismatch) begin
                        led_pass <= 1'b1;
                        led_fail <= 1'b0;
                    end else begin
                        led_pass <= 1'b0;
                        led_fail <= blink_tog;
                    end
                    state <= S_DONE;
                end

                default: state <= S_IDLE;

            endcase
        end
    end

endmodule

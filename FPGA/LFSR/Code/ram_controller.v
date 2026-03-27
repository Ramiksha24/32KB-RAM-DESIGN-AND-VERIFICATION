`timescale 1ns/1ps

module ram_controller (
    input  wire        clk,
    input  wire        rst,         // Active-HIGH synchronous reset

    // Main RAM
    output reg         we,
    output reg  [14:0] addr,
    output reg  [7:0]  din,
    input  wire [7:0]  dout,

    // LEDs
    output reg         led_pass,   // Solid ON  = PASS
    output reg         led_fail    // Blinking  = FAIL (~3 Hz at 100 MHz)
);
    localparam [2:0]
        S_IDLE    = 3'd0,
        S_WRITE   = 3'd1,
        S_WRITE_W = 3'd2,
        S_READ    = 3'd3,
        S_READ_W1 = 3'd4,   // Wait: BRAM registers addr internally
        S_READ_W2 = 3'd5,   // Wait: dout is now valid - latch it here
        S_COMPARE = 3'd6,
        S_DONE    = 3'd7;

    reg [2:0] state;

    reg [14:0] addr_cnt;

    // LFSR-16 (Galois poly 0xB400) - write data generator
 
    reg [15:0] lfsr;

    function [15:0] lfsr_next;
        input [15:0] d;
        begin
            lfsr_next = {1'b0, d[15:1]} ^ (d[0] ? 16'hB400 : 16'h0000);
        end
    endfunction

    wire [7:0] lfsr_byte = lfsr[7:0];
    reg [7:0]  shadow_mem [0:32767];
    reg        shadow_we;
    reg [14:0] shadow_waddr;
    reg [7:0]  shadow_wdata;
    reg [14:0] shadow_raddr;
    reg [7:0]  shadow_dout;         // Registered output - same 1-cycle latency as main BRAM

    always @(posedge clk) begin
        if (shadow_we)
            shadow_mem[shadow_waddr] <= shadow_wdata;
        shadow_dout <= shadow_mem[shadow_raddr];
    end

    reg [7:0] main_dout_lat;
    reg [7:0] shad_dout_lat;

    reg mismatch;

    reg [24:0] blink_cnt;
    reg        blink_tog;

    always @(posedge clk) begin
        if (rst) begin
            state          <= S_IDLE;
            addr_cnt       <= 15'd0;
            lfsr           <= 16'hACE1;
            mismatch       <= 1'b0;
            we             <= 1'b0;
            addr           <= 15'd0;
            din            <= 8'd0;
            shadow_we      <= 1'b0;
            shadow_waddr   <= 15'd0;
            shadow_wdata   <= 8'd0;
            shadow_raddr   <= 15'd0;
            main_dout_lat  <= 8'd0;
            shad_dout_lat  <= 8'd0;
            led_pass       <= 1'b0;
            led_fail       <= 1'b0;
            blink_cnt      <= 25'd0;
            blink_tog      <= 1'b0;

        end else begin

            blink_cnt <= blink_cnt + 1'b1;
            if (blink_cnt == 25'd0)
                blink_tog <= ~blink_tog;

            shadow_we <= 1'b0;  // Default deasserted

            case (state)

                S_IDLE: begin
                    addr_cnt <= 15'd0;
                    lfsr     <= 16'hACE1;
                    mismatch <= 1'b0;
                    we       <= 1'b0;
                    state    <= S_WRITE;
                end

                S_WRITE: begin
                    we            <= 1'b1;
                    addr          <= addr_cnt;
                    din           <= lfsr_byte;
                    shadow_we     <= 1'b1;
                    shadow_waddr  <= addr_cnt;
                    shadow_wdata  <= lfsr_byte;
                    state         <= S_WRITE_W;
                end

                S_WRITE_W: begin
                    we        <= 1'b0;
                    shadow_we <= 1'b0;
                    lfsr      <= lfsr_next(lfsr);

                    if (addr_cnt == 15'd32767) begin
                        addr_cnt <= 15'd0;
                        state    <= S_READ;
                    end else begin
                        addr_cnt <= addr_cnt + 1'b1;
                        state    <= S_WRITE;
                    end
                end

                S_READ: begin
                    we           <= 1'b0;
                    addr         <= addr_cnt;       // Main BRAM address
                    shadow_raddr <= addr_cnt;       // Shadow BRAM address
                    state        <= S_READ_W1;
                end

   
                S_READ_W1: begin
                    state <= S_READ_W2;
                end

                S_READ_W2: begin
                    main_dout_lat <= dout;          // Valid: mem[addr_cnt]
                    shad_dout_lat <= shadow_dout;   // Valid: shadow[addr_cnt]
                    state         <= S_COMPARE;
                end

                S_COMPARE: begin
                    if (main_dout_lat != shad_dout_lat)
                        mismatch <= 1'b1;

                    if (addr_cnt == 15'd32767) begin
                        state <= S_DONE;
                    end else begin
                        addr_cnt <= addr_cnt + 1'b1;
                        state    <= S_READ;
                    end
                end

                S_DONE: begin
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
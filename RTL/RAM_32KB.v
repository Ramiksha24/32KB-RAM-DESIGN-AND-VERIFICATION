`timescale 1ns/1ps

module ram_32kb (
    input  wire        clk,
    input  wire        we,          // Write enable (active high)
    input  wire [14:0] addr,        // 15-bit address (0 to 32767)
    input  wire [7:0]  din,         // 8-bit data input
    output reg  [7:0]  dout         // 8-bit data output (registered, 1 cycle latency)
);

    reg [7:0] mem [0:32767];

    always @(posedge clk) begin
        if (we) begin
            mem[addr] <= din;       // Write operation
        end
        dout <= mem[addr];          // Read operation (read-first, 1-cycle latency)
    end

endmodule


// Module  : tb_ram_system
// Design  : 32KB RAM Write ? Read ? Compare  (Simulation Only)
// Clock   : 200 MHz (5 ns period)

// Flow:
//   1. Load write_data.txt  ? write_mem[32768]
//   2. WRITE: drive we/addr/din directly into ram_32kb for all 32768 bytes
//   3. READ : drive addr, wait 1 registered-output cycle, capture dout
//   4. Dump read_mem[] ? read.txt
//   5. Compare write_mem[] vs read_mem[] byte-by-byte ? PASS / FAIL

`timescale 1ns / 1ps

module tb_ram_system;


    localparam CLK_PERIOD = 5;          // 5 ns ? 200 MHz
    localparam MEM_DEPTH  = 32768;      // 32 KB = 32768 bytes

    reg         clk;
    reg         we;
    reg  [14:0] addr;
    reg  [7:0]  din;
    wire [7:0]  dout;

    reg [7:0] write_mem [0:MEM_DEPTH-1];
    reg [7:0] read_mem  [0:MEM_DEPTH-1];

    integer write_fd, read_fd;
    integer i;
    integer mismatch_count;
    reg [7:0] tmp_byte;

    ram_32kb u_ram (
        .clk  (clk),
        .we   (we),
        .addr (addr),
        .din  (din),
        .dout (dout)
    );


    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin

        we   = 1'b0;
        addr = 15'd0;
        din  = 8'd0;

        $display("============================================================");
        $display("  32KB RAM Self-Test - Simulation Only");
        $display("  Clock : 200 MHz  |  Depth : %0d bytes", MEM_DEPTH);
        $display("============================================================");

        repeat(5) @(posedge clk);

   
        // STEP 1: Load write_data.txt
        $display("[TB] Step 1: Loading write_data.txt ...");

        write_fd = $fopen("write_data.txt", "r");
        if (write_fd == 0) begin
            $display("[TB ERROR] write_data.txt not found!");
            $display("           Copy it to: <project>.sim/sim_1/behav/xsim/");
            $finish;
        end

        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            if ($fscanf(write_fd, "%b\n", tmp_byte) != 1) begin
                $display("[TB ERROR] File read error at line %0d", i);
                $fclose(write_fd);
                $finish;
            end
            write_mem[i] = tmp_byte;
        end
        $fclose(write_fd);

        $display("[TB] Loaded %0d bytes from write_data.txt", MEM_DEPTH);
        $display("[TB] First 4 bytes: %08b %08b %08b %08b",
                  write_mem[0], write_mem[1], write_mem[2], write_mem[3]);

 
        // STEP 2: WRITE PHASE
        //   Drive we=1, addr, din on NEGEDGE  ? stable at next POSEDGE
        //   BRAM writes mem[addr] <= din on POSEDGE when we=1
        //   1 byte per clock cycle

        $display("[TB] Step 2: WRITE phase starting ...");

        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            @(negedge clk);         // Drive on falling edge
            we   = 1'b1;
            addr = i[14:0];
            din  = write_mem[i];
        end

        @(negedge clk);             // Deassert after last byte
        we  = 1'b0;
        din = 8'd0;

        repeat(4) @(posedge clk);   // Allow final write to commit

        $display("[TB] WRITE phase done. %0d bytes written.", MEM_DEPTH);


        // STEP 3: READ PHASE
        //   ram_32kb has REGISTERED output ? 1-cycle latency:
        //     Posedge N   : addr registered into BRAM
        //     Posedge N+1 : dout is valid
        //   We drive addr on NEGEDGE, then wait 2 posedges before sampling
   
        $display("[TB] Step 3: READ phase starting ...");
        we = 1'b0;

        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            @(negedge clk);
            addr = i[14:0];         // Present address on falling edge
            @(posedge clk);         // Posedge N   : BRAM latches addr
            @(posedge clk);         // Posedge N+1 : dout now valid
            read_mem[i] = dout;     // Capture read data
        end

        $display("[TB] READ phase done. %0d bytes read back.", MEM_DEPTH);
        $display("[TB] First 4 bytes read: %08b %08b %08b %08b",
                  read_mem[0], read_mem[1], read_mem[2], read_mem[3]);

 
        // STEP 4: Dump read.txt
     
        $display("[TB] Step 4: Writing read.txt ...");

        read_fd = $fopen("read.txt", "w");
        if (read_fd == 0) begin
            $display("[TB ERROR] Cannot create read.txt");
            $finish;
        end
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            $fwrite(read_fd, "%08b\n", read_mem[i]);
        end
        $fclose(read_fd);

        $display("[TB] Wrote %0d bytes to read.txt", MEM_DEPTH);

        // STEP 5: Compare
      
        $display("[TB] Step 5: Comparing ...");
        mismatch_count = 0;

        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            if (write_mem[i] !== read_mem[i]) begin
                $display("[MISMATCH] Addr 0x%04X | Written: %08b | Read: %08b",
                          i, write_mem[i], read_mem[i]);
                mismatch_count = mismatch_count + 1;
                if (mismatch_count >= 20) begin
                    $display("[TB] ... too many mismatches, stopping display.");
                    i = MEM_DEPTH;
                end
            end
        end

        // STEP 6: Final Result
       
        $display("============================================================");
        if (mismatch_count == 0) begin
            $display("  RESULT : ** PASS ** -- All %0d bytes matched!", MEM_DEPTH);
            $display("  Total bits verified : %0d", MEM_DEPTH * 8);
        end else begin
            $display("  RESULT : ** FAIL ** -- %0d byte mismatches!", mismatch_count);
        end
        $display("============================================================");

        #50;
        $finish;
    end

 
    // Waveform Dump (open in Vivado Wave window or GTKWave)

    initial begin
        $dumpfile("tb_ram_system.vcd");
        $dumpvars(0, tb_ram_system);
    end

endmodule
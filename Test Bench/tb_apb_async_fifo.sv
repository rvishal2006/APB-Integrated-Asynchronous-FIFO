`timescale 1ns/1ps

module tb_apb_async_fifo;

    // ------------------------------------------------
    // Clock and reset signals
    // ------------------------------------------------
    logic PCLK = 0;
    logic rd_clk = 0;

    logic PRESETn = 0;
    logic rd_rst_n = 0;

    // ------------------------------------------------
    // APB interface signals
    // ------------------------------------------------
    logic [7:0]  PADDR;
    logic        PSEL;
    logic        PENABLE;
    logic        PWRITE;
    logic [31:0] PWDATA;

    logic [31:0] PRDATA;
    logic        PREADY;
    logic        PSLVERR;

    logic [31:0] received;

    // ------------------------------------------------
    // DUT: APB + Asynchronous FIFO
    // ------------------------------------------------
    apb_async_fifo #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(4)
    ) dut (
        .PCLK    (PCLK),
        .PRESETn (PRESETn),

        .PADDR   (PADDR),
        .PSEL    (PSEL),
        .PENABLE (PENABLE),
        .PWRITE  (PWRITE),
        .PWDATA  (PWDATA),

        .PRDATA  (PRDATA),
        .PREADY  (PREADY),
        .PSLVERR (PSLVERR),

        .rd_clk  (rd_clk),
        .rd_rst_n(rd_rst_n)
    );

    // ------------------------------------------------
    // Independent clocks
    // PCLK period = 10 ns
    // rd_clk period = 14 ns
    // ------------------------------------------------
    always #5 PCLK = ~PCLK;
    always #7 rd_clk = ~rd_clk;

    // ------------------------------------------------
    // APB WRITE TASK
    // ------------------------------------------------
    task automatic apb_write(
        input logic [7:0]  addr,
        input logic [31:0] data
    );
        logic done;
        begin
            @(negedge PCLK);

            PSEL    = 1'b1;
            PENABLE = 1'b0;
            PWRITE  = 1'b1;
            PADDR   = addr;
            PWDATA  = data;

            // APB access phase
            @(negedge PCLK);
            PENABLE = 1'b1;

            done = 1'b0;

            // Wait for a completed APB transfer
            while (!done) begin
                @(posedge PCLK);
                #1;

                if (PREADY) begin
                    if (PSLVERR)
                        $fatal(1,
                            "APB write error: addr=%h data=%h",
                            addr, data);

                    $display(
                        "[%0t ns] APB WRITE addr=%h data=%h",
                        $time, addr, data
                    );

                    done = 1'b1;
                end
            end

            @(negedge PCLK);

            PSEL    = 1'b0;
            PENABLE = 1'b0;
            PWRITE  = 1'b0;
            PWDATA  = '0;
        end
    endtask

    // ------------------------------------------------
    // APB READ TASK
    // Samples after the rising-edge updates settle.
    // ------------------------------------------------
    task automatic apb_read(
        input  logic [7:0]  addr,
        output logic [31:0] data
    );
        logic done;
        begin
            @(negedge PCLK);

            PSEL    = 1'b1;
            PENABLE = 1'b0;
            PWRITE  = 1'b0;
            PADDR   = addr;

            // APB access phase
            @(negedge PCLK);
            PENABLE = 1'b1;

            done = 1'b0;
            data = '0;

            // Wait until the slave completes the transfer
            while (!done) begin
                @(posedge PCLK);
                #1;

                if (PREADY) begin
                    data = PRDATA;

                    if (PSLVERR)
                        $fatal(1,
                            "APB read error at address %h",
                            addr);

                    $display(
                        "[%0t ns] APB READ addr=%h data=%h",
                        $time, addr, data
                    );

                    done = 1'b1;
                end
            end

            @(negedge PCLK);

            PSEL    = 1'b0;
            PENABLE = 1'b0;
        end
    endtask

    // ------------------------------------------------
    // MAIN TEST
    // ------------------------------------------------
    initial begin

        // Initialize APB signals
        PADDR   = '0;
        PSEL    = 1'b0;
        PENABLE = 1'b0;
        PWRITE  = 1'b0;
        PWDATA  = '0;
        received = '0;

        // Reset
        $display("Starting APB asynchronous FIFO test...");

        repeat (5) @(negedge PCLK);

        PRESETn = 1'b1;
        rd_rst_n = 1'b1;

        repeat (5) @(negedge PCLK);

        // ============================================
        // TEST 1: Write three words
        // ============================================
        $display("\nTEST 1: FIFO writes");

        apb_write(8'h00, 32'h12345678);
        apb_write(8'h00, 32'hAABBCCDD);
        apb_write(8'h00, 32'hDEADBEEF);

        // Allow synchronized write pointer to reach
        // the read-clock domain.
        repeat (5) @(negedge rd_clk);
        repeat (3) @(negedge PCLK);

        // ============================================
        // TEST 2: FIFO must not be empty
        // ============================================
        $display("\nTEST 2: Check non-empty status");

        apb_read(8'h04, received);

        if (received[0] !== 1'b0)
            $fatal(1,
                "FAIL: FIFO unexpectedly empty; status=%h",
                received);

        $display("PASS: FIFO is not empty.");

        // ============================================
        // TEST 3: Read first word
        // ============================================
        $display("\nTEST 3: Read first word");

        apb_read(8'h00, received);

        if (received !== 32'h12345678)
            $fatal(1,
                "FAIL: First read expected 12345678, got %h",
                received);

        $display("PASS: First FIFO word.");

        // ============================================
        // TEST 4: Read second word
        // ============================================
        $display("\nTEST 4: Read second word");

        apb_read(8'h00, received);

        if (received !== 32'hAABBCCDD)
            $fatal(1,
                "FAIL: Second read expected AABBCCDD, got %h",
                received);

        $display("PASS: Second FIFO word.");

        // ============================================
        // TEST 5: Read third word
        // ============================================
        $display("\nTEST 5: Read third word");

        apb_read(8'h00, received);

        if (received !== 32'hDEADBEEF)
            $fatal(1,
                "FAIL: Third read expected DEADBEEF, got %h",
                received);

        $display("PASS: Third FIFO word.");

        // ============================================
        // TEST 6: FIFO must now be empty
        // ============================================
        $display("\nTEST 6: Check empty status");

        apb_read(8'h04, received);

        if (received[0] !== 1'b1)
            $fatal(1,
                "FAIL: FIFO should be empty; status=%h",
                received);

        $display("PASS: FIFO is empty.");

        // ============================================
        // Final result
        // ============================================
        $display("\n======================================");
        $display("PASS: APB FIFO write/read ordering verified.");
        $display("All data and status checks passed.");
        $display("======================================");

        #20;
        $finish;
    end

    // ------------------------------------------------
    // Watchdog timeout
    // ------------------------------------------------
    initial begin
        #100000;
        $fatal(1,
            "TIMEOUT: APB FIFO test did not complete.");
    end

endmodule

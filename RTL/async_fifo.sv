`timescale 1ns / 1ps


module async_fifo #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4
)(
    input  logic                  wr_clk,
    input  logic                  wr_rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  full,

    input  logic                  rd_clk,
    input  logic                  rd_rst_n,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  empty
);

    localparam DEPTH = (1 << ADDR_WIDTH);
    localparam PTR_WIDTH = ADDR_WIDTH + 1;

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic [PTR_WIDTH-1:0] wr_bin, wr_gray;
    logic [PTR_WIDTH-1:0] rd_bin, rd_gray;

    logic [PTR_WIDTH-1:0] rd_gray_sync1, rd_gray_sync2;
    logic [PTR_WIDTH-1:0] wr_gray_sync1, wr_gray_sync2;

    logic [PTR_WIDTH-1:0] wr_bin_next, wr_gray_next;
    logic [PTR_WIDTH-1:0] rd_bin_next, rd_gray_next;

    logic wr_full_next, rd_empty_next;

    function automatic [PTR_WIDTH-1:0] bin_to_gray(
        input [PTR_WIDTH-1:0] bin
    );
        bin_to_gray = (bin >> 1) ^ bin;
    endfunction

    // Synchronize read pointer into write clock domain
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_gray_sync1 <= '0;
            rd_gray_sync2 <= '0;
        end else begin
            rd_gray_sync1 <= rd_gray;
            rd_gray_sync2 <= rd_gray_sync1;
        end
    end

    // Synchronize write pointer into read clock domain
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_gray_sync1 <= '0;
            wr_gray_sync2 <= '0;
        end else begin
            wr_gray_sync1 <= wr_gray;
            wr_gray_sync2 <= wr_gray_sync1;
        end
    end

    // Write pointer and memory
    always_comb begin
        wr_bin_next  = wr_bin + ((wr_en && !full) ? 1'b1 : 1'b0);
        wr_gray_next = bin_to_gray(wr_bin_next);

        wr_full_next =
            (wr_gray_next ==
             {~rd_gray_sync2[PTR_WIDTH-1:PTR_WIDTH-2],
                rd_gray_sync2[PTR_WIDTH-3:0]});
    end

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_bin <= '0;
            wr_gray <= '0;
            full <= 1'b0;
        end else begin
            if (wr_en && !full)
                mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data;

            wr_bin  <= wr_bin_next;
            wr_gray <= wr_gray_next;
            full    <= wr_full_next;
        end
    end

    // Read pointer
    always_comb begin
        rd_bin_next  = rd_bin + ((rd_en && !empty) ? 1'b1 : 1'b0);
        rd_gray_next = bin_to_gray(rd_bin_next);
        rd_empty_next = (rd_gray_next == wr_gray_sync2);
    end

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_bin <= '0;
            rd_gray <= '0;
            empty <= 1'b1;
            rd_data <= '0;
        end else begin
            if (rd_en && !empty)
                rd_data <= mem[rd_bin[ADDR_WIDTH-1:0]];

            rd_bin  <= rd_bin_next;
            rd_gray <= rd_gray_next;
            empty   <= rd_empty_next;
        end
    end

endmodule


module apb_async_fifo #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4
)(
    input  logic        PCLK,
    input  logic        PRESETn,

    input  logic [7:0]  PADDR,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [31:0] PWDATA,

    output logic [31:0] PRDATA,
    output logic        PREADY,
    output logic        PSLVERR,

    input  logic        rd_clk,
    input  logic        rd_rst_n
);

    // FIFO interface
    logic                  fifo_wr_en;
    logic                  fifo_rd_en;
    logic [DATA_WIDTH-1:0] fifo_wr_data;
    logic [DATA_WIDTH-1:0] fifo_rd_data;
    logic                  fifo_full;
    logic                  fifo_empty;

    // APB read-request toggle handshake
    logic rd_req_toggle;
    logic rd_req_sync1, rd_req_sync2, rd_req_seen;
    logic rd_ack_toggle;
    logic rd_ack_sync1, rd_ack_sync2;

    // FIFO read sequencing
    logic rd_pop_pending;
    logic rd_error_hold;
    logic [DATA_WIDTH-1:0] rd_data_hold;

    // APB response state
    logic rd_pending;
    logic rd_response_valid;
    logic [DATA_WIDTH-1:0] rd_response_data;
    logic rd_response_error;

    logic rd_capture_pending;
    
    wire apb_access = PSEL && PENABLE;
    wire fifo_data_addr = (PADDR == 8'h00);
    wire fifo_status_addr = (PADDR == 8'h04);

    // --------------------------------------------------
    // Asynchronous FIFO
    // --------------------------------------------------
    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_fifo (
        .wr_clk   (PCLK),
        .wr_rst_n (PRESETn),
        .wr_en    (fifo_wr_en),
        .wr_data  (fifo_wr_data),
        .full     (fifo_full),

        .rd_clk   (rd_clk),
        .rd_rst_n (rd_rst_n),
        .rd_en    (fifo_rd_en),
        .rd_data  (fifo_rd_data),
        .empty    (fifo_empty)
    );

    // --------------------------------------------------
    // FIFO read clock domain
    // Request is synchronized, then FIFO pop and data
    // capture occur on separate read-clock edges.
    // --------------------------------------------------
    
always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
        rd_req_sync1 <= 1'b0;
        rd_req_sync2 <= 1'b0;
        rd_req_seen <= 1'b0;
        rd_ack_toggle <= 1'b0;
        fifo_rd_en <= 1'b0;
        rd_pop_pending <= 1'b0;
        rd_capture_pending <= 1'b0;
        rd_data_hold <= '0;
        rd_error_hold <= 1'b0;
    end else begin
        rd_req_sync1 <= rd_req_toggle;
        rd_req_sync2 <= rd_req_sync1;
        fifo_rd_en <= 1'b0;

        if (rd_capture_pending) begin
            // FIFO output is now stable with the popped word.
            rd_data_hold <= fifo_rd_data;
            rd_error_hold <= 1'b0;
            rd_ack_toggle <= rd_req_seen;
            rd_capture_pending <= 1'b0;

        end else if (rd_pop_pending) begin
            // FIFO consumes the previous cycle's rd_en.
            rd_pop_pending <= 1'b0;
            rd_capture_pending <= 1'b1;

        end else if (rd_req_sync2 != rd_req_seen) begin
            rd_req_seen <= rd_req_sync2;

            if (!fifo_empty) begin
                fifo_rd_en <= 1'b1;
                rd_pop_pending <= 1'b1;
            end else begin
                rd_data_hold <= '0;
                rd_error_hold <= 1'b1;
                rd_ack_toggle <= rd_req_sync2;
            end
        end
    end
end

    // --------------------------------------------------
    // Synchronize acknowledgement into APB clock domain
    // --------------------------------------------------
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            rd_ack_sync1 <= 1'b0;
            rd_ack_sync2 <= 1'b0;
        end else begin
            rd_ack_sync1 <= rd_ack_toggle;
            rd_ack_sync2 <= rd_ack_sync1;
        end
    end

    // --------------------------------------------------
    // APB write and read control
    // --------------------------------------------------
    always_comb begin
        fifo_wr_en   = 1'b0;
        fifo_wr_data = PWDATA;

        PREADY = 1'b0;
        PRDATA = 32'b0;
        PSLVERR = 1'b0;

        if (apb_access) begin
            if (PWRITE) begin
                if (fifo_data_addr) begin
                    PREADY = !fifo_full;
                    fifo_wr_en = PREADY;
                end else begin
                    PREADY = 1'b1;
                    PSLVERR = !fifo_status_addr;
                end
            end else begin
                if (fifo_status_addr) begin
                    PREADY = 1'b1;
                    PRDATA[0] = fifo_empty;
                    PRDATA[1] = fifo_full;
                end else if (fifo_data_addr) begin
                    PREADY = rd_response_valid;
                    PRDATA = rd_response_data;
                    PSLVERR = rd_response_valid &&
                              rd_response_error;
                end else begin
                    PREADY = 1'b1;
                    PSLVERR = 1'b1;
                end
            end
        end
    end

    // --------------------------------------------------
    // APB read request and response control
    // --------------------------------------------------
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            rd_req_toggle <= 1'b0;
            rd_pending <= 1'b0;
            rd_response_valid <= 1'b0;
            rd_response_data <= '0;
            rd_response_error <= 1'b0;
        end else begin

            // Start a read only once during an APB access.
            if (apb_access && !PWRITE && fifo_data_addr &&
                !rd_pending && !rd_response_valid) begin
                rd_req_toggle <= ~rd_req_toggle;
                rd_pending <= 1'b1;
            end

            // Wait for the synchronized FIFO acknowledgement.
            if (rd_pending &&
                (rd_ack_sync2 == rd_req_toggle)) begin
                rd_response_data <= rd_error_hold
                                  ? '0 : rd_data_hold;
                rd_response_error <= rd_error_hold;
                rd_response_valid <= 1'b1;
                rd_pending <= 1'b0;
            end

            // Clear response after APB access ends.
            if (!apb_access) begin
                rd_response_valid <= 1'b0;
            end
        end
    end

endmodule


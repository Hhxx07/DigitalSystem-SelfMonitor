`timescale 1ns / 1ps

module uart_rx #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115_200
) (
    input  wire       clk,
    input  wire       reset,
    input  wire       rx,
    output reg  [7:0] rx_data,
    output reg        rx_valid
);

    localparam integer CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;
    localparam integer HALF_BIT     = CLKS_PER_BIT / 2;

    localparam [2:0] S_IDLE  = 3'd0;
    localparam [2:0] S_START = 3'd1;
    localparam [2:0] S_DATA  = 3'd2;
    localparam [2:0] S_STOP  = 3'd3;

    reg [2:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  data_latch;
    reg        rx_meta;
    reg        rx_sync;

    always @(posedge clk) begin
        if (reset) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
            clk_count <= 16'd0;
            bit_index <= 3'd0;
            data_latch <= 8'd0;
            rx_data <= 8'd0;
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    clk_count <= 16'd0;
                    bit_index <= 3'd0;
                    if (!rx_sync) begin
                        state <= S_START;
                    end
                end

                S_START: begin
                    if (clk_count == HALF_BIT - 1) begin
                        clk_count <= 16'd0;
                        if (!rx_sync) begin
                            state <= S_DATA;
                        end else begin
                            state <= S_IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                S_DATA: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 16'd0;
                        data_latch[bit_index] <= rx_sync;
                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            state <= S_STOP;
                        end else begin
                            bit_index <= bit_index + 3'd1;
                        end
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                S_STOP: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 16'd0;
                        if (rx_sync) begin
                            rx_data <= data_latch;
                            rx_valid <= 1'b1;
                        end
                        state <= S_IDLE;
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

`timescale 1ns / 1ps

module uart_tx #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115_200
) (
    input  wire       clk,
    input  wire       reset,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx,
    output reg        busy,
    output reg        done
);

    localparam integer CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;

    localparam [2:0] S_IDLE  = 3'd0;
    localparam [2:0] S_START = 3'd1;
    localparam [2:0] S_DATA  = 3'd2;
    localparam [2:0] S_STOP  = 3'd3;
    localparam [2:0] S_DONE  = 3'd4;

    reg [2:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  data_latch;

    always @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
            tx <= 1'b1;
            busy <= 1'b0;
            done <= 1'b0;
            clk_count <= 16'd0;
            bit_index <= 3'd0;
            data_latch <= 8'd0;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    tx <= 1'b1;
                    busy <= 1'b0;
                    clk_count <= 16'd0;
                    bit_index <= 3'd0;
                    if (tx_start) begin
                        data_latch <= tx_data;
                        busy <= 1'b1;
                        state <= S_START;
                    end
                end

                S_START: begin
                    tx <= 1'b0;
                    busy <= 1'b1;
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 16'd0;
                        state <= S_DATA;
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                S_DATA: begin
                    tx <= data_latch[bit_index];
                    busy <= 1'b1;
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 16'd0;
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
                    tx <= 1'b1;
                    busy <= 1'b1;
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 16'd0;
                        state <= S_DONE;
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                S_DONE: begin
                    tx <= 1'b1;
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

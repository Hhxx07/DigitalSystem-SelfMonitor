`timescale 1ns / 1ps

module uart_tx #(
    parameter CLK_FREQ_HZ = 100_000_000,
    parameter BAUD_RATE   = 115_200
)(
    input  wire       clk,
    input  wire       rst_n,

    input  wire [7:0] tx_data,
    input  wire       tx_start,

    output reg        tx,
    output reg        busy,
    output reg        done
);

    function integer clog2;
        input [63:0] value;
        reg [63:0] v;
        integer r;
        begin
            v = value - 64'd1;
            for (r = 0; v > 0; r = r + 1)
                v = v >> 1;

            if (r < 1)
                clog2 = 1;
            else
                clog2 = r;
        end
    endfunction

    localparam integer CLKS_PER_BIT_RAW = CLK_FREQ_HZ / BAUD_RATE;
    localparam integer CLKS_PER_BIT = (CLKS_PER_BIT_RAW < 1) ? 1 : CLKS_PER_BIT_RAW;
    localparam integer BAUD_CNT_W = clog2(CLKS_PER_BIT);

    localparam [1:0] ST_IDLE  = 2'd0;
    localparam [1:0] ST_START = 2'd1;
    localparam [1:0] ST_DATA  = 2'd2;
    localparam [1:0] ST_STOP  = 2'd3;

    reg [1:0] state;
    reg [BAUD_CNT_W-1:0] baud_cnt;
    reg [2:0] bit_index;
    reg [7:0] data_buf;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_IDLE;
            baud_cnt  <= {BAUD_CNT_W{1'b0}};
            bit_index <= 3'd0;
            data_buf  <= 8'd0;
            tx        <= 1'b1;
            busy      <= 1'b0;
            done      <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    tx        <= 1'b1;
                    busy      <= 1'b0;
                    baud_cnt  <= {BAUD_CNT_W{1'b0}};
                    bit_index <= 3'd0;

                    if (tx_start) begin
                        data_buf <= tx_data;
                        tx       <= 1'b0;
                        busy     <= 1'b1;
                        state    <= ST_START;
                    end
                end

                ST_START: begin
                    busy <= 1'b1;
                    tx   <= 1'b0;

                    if (baud_cnt == CLKS_PER_BIT - 1) begin
                        baud_cnt <= {BAUD_CNT_W{1'b0}};
                        tx       <= data_buf[0];
                        state    <= ST_DATA;
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                ST_DATA: begin
                    busy <= 1'b1;

                    if (baud_cnt == CLKS_PER_BIT - 1) begin
                        baud_cnt <= {BAUD_CNT_W{1'b0}};

                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            tx        <= 1'b1;
                            state     <= ST_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                            tx        <= data_buf[bit_index + 1'b1];
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                ST_STOP: begin
                    busy <= 1'b1;
                    tx   <= 1'b1;

                    if (baud_cnt == CLKS_PER_BIT - 1) begin
                        baud_cnt <= {BAUD_CNT_W{1'b0}};
                        busy     <= 1'b0;
                        done     <= 1'b1;
                        state    <= ST_IDLE;
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                    tx    <= 1'b1;
                    busy  <= 1'b0;
                end
            endcase
        end
    end

endmodule

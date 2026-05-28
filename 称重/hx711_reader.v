`timescale 1ns / 1ps

module hx711_reader #(
    parameter CLK_FREQ_HZ = 100_000_000,
    parameter SCK_FREQ_HZ = 50_000,
    parameter GAIN_PULSES = 1
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        hx711_dout,
    output reg         hx711_sck,

    output reg  [23:0] raw_data,
    output reg         raw_data_valid,
    output wire        hx711_ready,
    output reg         busy
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

    localparam integer HALF_PERIOD_RAW = CLK_FREQ_HZ / (SCK_FREQ_HZ * 2);
    localparam integer HALF_PERIOD = (HALF_PERIOD_RAW < 1) ? 1 : HALF_PERIOD_RAW;
    localparam integer TOTAL_PULSES = 24 + GAIN_PULSES;
    localparam integer HALF_CNT_W = clog2(HALF_PERIOD);
    localparam integer PULSE_CNT_W = clog2(TOTAL_PULSES + 1);

    localparam [1:0] ST_WAIT = 2'd0;
    localparam [1:0] ST_HIGH = 2'd1;
    localparam [1:0] ST_LOW  = 2'd2;

    reg [1:0] state;
    reg [HALF_CNT_W-1:0] half_cnt;
    reg [PULSE_CNT_W-1:0] pulse_cnt;
    reg [23:0] shift_reg;
    reg dout_meta;
    reg dout_sync;

    assign hx711_ready = !dout_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout_meta <= 1'b1;
            dout_sync <= 1'b1;
        end else begin
            dout_meta <= hx711_dout;
            dout_sync <= dout_meta;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= ST_WAIT;
            half_cnt       <= {HALF_CNT_W{1'b0}};
            pulse_cnt      <= {PULSE_CNT_W{1'b0}};
            shift_reg      <= 24'd0;
            raw_data       <= 24'd0;
            raw_data_valid <= 1'b0;
            hx711_sck      <= 1'b0;
            busy           <= 1'b0;
        end else begin
            raw_data_valid <= 1'b0;

            case (state)
                ST_WAIT: begin
                    hx711_sck <= 1'b0;
                    busy      <= 1'b0;
                    half_cnt  <= {HALF_CNT_W{1'b0}};
                    pulse_cnt <= {PULSE_CNT_W{1'b0}};

                    if (!dout_sync) begin
                        busy      <= 1'b1;
                        shift_reg <= 24'd0;
                        hx711_sck <= 1'b1;
                        state     <= ST_HIGH;
                    end
                end

                ST_HIGH: begin
                    busy <= 1'b1;

                    if (half_cnt == HALF_PERIOD - 1) begin
                        half_cnt  <= {HALF_CNT_W{1'b0}};
                        hx711_sck <= 1'b0;

                        if (pulse_cnt < 24)
                            shift_reg <= {shift_reg[22:0], dout_sync};

                        state <= ST_LOW;
                    end else begin
                        half_cnt <= half_cnt + 1'b1;
                    end
                end

                ST_LOW: begin
                    busy <= 1'b1;

                    if (half_cnt == HALF_PERIOD - 1) begin
                        half_cnt <= {HALF_CNT_W{1'b0}};

                        if (pulse_cnt == TOTAL_PULSES - 1) begin
                            raw_data       <= shift_reg;
                            raw_data_valid <= 1'b1;
                            pulse_cnt      <= {PULSE_CNT_W{1'b0}};
                            busy           <= 1'b0;
                            state          <= ST_WAIT;
                        end else begin
                            pulse_cnt  <= pulse_cnt + 1'b1;
                            hx711_sck  <= 1'b1;
                            state      <= ST_HIGH;
                        end
                    end else begin
                        half_cnt <= half_cnt + 1'b1;
                    end
                end

                default: begin
                    state     <= ST_WAIT;
                    hx711_sck <= 1'b0;
                    busy      <= 1'b0;
                end
            endcase
        end
    end

endmodule

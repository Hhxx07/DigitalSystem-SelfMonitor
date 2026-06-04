`timescale 1ns / 1ps

module pir_motion_hold_detector #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer HOLD_SEC    = 60
)(
    input  wire clk,
    input  wire rst_n,
    input  wire pir_in,

    output wire pir_raw_sync,
    output reg  motion_event,
    output reg  human_present
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

    localparam [63:0] SECOND_CYCLES_RAW = 64'd1 * CLK_FREQ_HZ;
    localparam [63:0] SECOND_CYCLES = (SECOND_CYCLES_RAW < 64'd1) ? 64'd1 : SECOND_CYCLES_RAW;
    localparam integer SECOND_CNT_W = clog2(SECOND_CYCLES);
    localparam integer HOLD_CNT_W = clog2(HOLD_SEC + 1);
    localparam [SECOND_CNT_W-1:0] SECOND_LAST = SECOND_CYCLES - 64'd1;
    localparam [HOLD_CNT_W-1:0] HOLD_SEC_VALUE = HOLD_SEC;

    reg pir_meta;
    reg pir_sync;
    reg pir_sync_d;
    reg [SECOND_CNT_W-1:0] second_cnt;
    reg [HOLD_CNT_W-1:0] hold_sec_left;

    wire second_tick;
    wire pir_active;

    assign pir_raw_sync = pir_sync;
    assign second_tick = (second_cnt == SECOND_LAST);
    assign pir_active = pir_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pir_meta <= 1'b0;
            pir_sync <= 1'b0;
            pir_sync_d <= 1'b0;
        end else begin
            pir_meta <= pir_in;
            pir_sync <= pir_meta;
            pir_sync_d <= pir_sync;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            second_cnt <= {SECOND_CNT_W{1'b0}};
        end else if (second_tick) begin
            second_cnt <= {SECOND_CNT_W{1'b0}};
        end else begin
            second_cnt <= second_cnt + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hold_sec_left <= {HOLD_CNT_W{1'b0}};
            human_present <= 1'b0;
            motion_event  <= 1'b0;
        end else begin
            motion_event <= 1'b0;

            if (pir_active) begin
                hold_sec_left <= HOLD_SEC_VALUE;
                human_present <= 1'b1;
                motion_event  <= !pir_sync_d;
            end else if (second_tick && (hold_sec_left != {HOLD_CNT_W{1'b0}})) begin
                hold_sec_left <= hold_sec_left - 1'b1;
                human_present <= (hold_sec_left > {{(HOLD_CNT_W-1){1'b0}}, 1'b1});
            end
        end
    end

endmodule

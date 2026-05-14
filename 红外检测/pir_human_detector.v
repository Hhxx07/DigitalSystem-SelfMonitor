`timescale 1ns / 1ps

module pir_human_detector #(
    parameter CLK_FREQ_HZ = 100_000_000,
    parameter WARMUP_SEC  = 60,
    parameter STABLE_MS   = 100,
    parameter SIM_FAST    = 0
)(
    input  wire clk,
    input  wire rst_n,
    input  wire pir_in,

    output wire pir_raw_sync,
    output reg  pir_valid,
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

    localparam [63:0] WARMUP_CYCLES_RAW =
        (SIM_FAST != 0) ? 64'd20 : (64'd1 * CLK_FREQ_HZ * WARMUP_SEC);
    localparam [63:0] STABLE_CYCLES_RAW =
        (SIM_FAST != 0) ? 64'd5 : (64'd1 * (CLK_FREQ_HZ / 1000) * STABLE_MS);

    localparam [63:0] WARMUP_CYCLES =
        (WARMUP_CYCLES_RAW < 64'd1) ? 64'd1 : WARMUP_CYCLES_RAW;
    localparam [63:0] STABLE_CYCLES =
        (STABLE_CYCLES_RAW < 64'd1) ? 64'd1 : STABLE_CYCLES_RAW;

    localparam integer WARMUP_CNT_W = clog2(WARMUP_CYCLES);
    localparam integer STABLE_CNT_W = clog2(STABLE_CYCLES + 64'd1);

    reg pir_meta;
    reg pir_sync;

    reg [WARMUP_CNT_W-1:0] warmup_cnt;
    reg [STABLE_CNT_W-1:0] stable_cnt;
    reg stable_level;

    assign pir_raw_sync = pir_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pir_meta <= 1'b0;
            pir_sync <= 1'b0;
        end else begin
            pir_meta <= pir_in;
            pir_sync <= pir_meta;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            warmup_cnt   <= {WARMUP_CNT_W{1'b0}};
            stable_cnt   <= {STABLE_CNT_W{1'b0}};
            stable_level <= 1'b0;
            pir_valid    <= 1'b0;
            human_present <= 1'b0;
        end else begin
            if (!pir_valid) begin
                human_present <= 1'b0;
                stable_level  <= pir_sync;
                stable_cnt    <= {STABLE_CNT_W{1'b0}};

                if (warmup_cnt == WARMUP_CYCLES - 64'd1) begin
                    warmup_cnt <= {WARMUP_CNT_W{1'b0}};
                    pir_valid  <= 1'b1;
                end else begin
                    warmup_cnt <= warmup_cnt + 1'b1;
                end
            end else begin
                if (pir_sync != stable_level) begin
                    stable_level <= pir_sync;

                    if (STABLE_CYCLES == 64'd1) begin
                        stable_cnt    <= STABLE_CYCLES;
                        human_present <= pir_sync;
                    end else begin
                        stable_cnt <= 1'b1;
                    end
                end else if (stable_cnt < STABLE_CYCLES) begin
                    stable_cnt <= stable_cnt + 1'b1;

                    if (stable_cnt == STABLE_CYCLES - 64'd1)
                        human_present <= stable_level;
                end
            end
        end
    end

endmodule

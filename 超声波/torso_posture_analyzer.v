`timescale 1ns / 1ps

module torso_posture_analyzer #(
    parameter integer CLK_HZ    = 100000000,
    parameter integer STABLE_MS = 500,
    parameter [9:0] DIFF_BAD_CM        = 10'd5,
    parameter [9:0] SIDE_TOO_CLOSE_CM  = 10'd19,
    parameter [9:0] SIDE_NORMAL_MIN_CM = 10'd24,
    parameter [9:0] SIDE_NORMAL_MAX_CM = 10'd30
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       seated,
    input  wire [9:0] front_distance_cm,
    input  wire [9:0] left45_distance_cm,
    input  wire [9:0] right45_distance_cm,
    output reg  [9:0] shoulder_diff_cm,
    output reg  [1:0] torso_state,
    output reg  [2:0] torso_hp_penalty
);

    localparam [1:0] TORSO_OK    = 2'd0;
    localparam [1:0] TORSO_LEAN  = 2'd1;
    localparam [1:0] TORSO_SIDE  = 2'd2;
    localparam [1:0] TORSO_TWIST = 2'd3;

    localparam integer RAW_STABLE_CYCLES = (CLK_HZ / 1000) * STABLE_MS;
    localparam integer STABLE_CYCLES = (RAW_STABLE_CYCLES < 1) ? 1 : RAW_STABLE_CYCLES;

    reg [31:0] diff_bad_cnt;
    reg [31:0] side_close_cnt;
    reg [31:0] lean_cnt;

    wire [9:0] diff_now;
    wire       diff_bad_now;
    wire       side_close_now;
    wire       lean_now;
    wire       diff_bad_stable;
    wire       side_close_stable;
    wire       lean_stable;

    // front_distance_cm is dHead. Its SAFE/WARN/DANGER threshold is applied
    // in hp_engine, so this module only adds side-sensor torso penalties.
    assign diff_now = (left45_distance_cm >= right45_distance_cm) ?
                      (left45_distance_cm - right45_distance_cm) :
                      (right45_distance_cm - left45_distance_cm);

    // Mounting rule:
    // left/right sensors face inward about 8 degrees and measure dL/dR.
    // A condition must stay stable for STABLE_MS before changing state.
    assign diff_bad_now =
        (diff_now >= DIFF_BAD_CM);

    assign side_close_now =
        (left45_distance_cm < SIDE_TOO_CLOSE_CM) ||
        (right45_distance_cm < SIDE_TOO_CLOSE_CM);

    assign lean_now =
        (left45_distance_cm < SIDE_NORMAL_MIN_CM) ||
        (right45_distance_cm < SIDE_NORMAL_MIN_CM) ||
        (left45_distance_cm > SIDE_NORMAL_MAX_CM) ||
        (right45_distance_cm > SIDE_NORMAL_MAX_CM);

    assign diff_bad_stable   = (diff_bad_cnt >= STABLE_CYCLES);
    assign side_close_stable = (side_close_cnt >= STABLE_CYCLES);
    assign lean_stable       = (lean_cnt >= STABLE_CYCLES);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shoulder_diff_cm  <= 10'd0;
            torso_state       <= TORSO_OK;
            torso_hp_penalty  <= 3'd0;
            diff_bad_cnt      <= 32'd0;
            side_close_cnt    <= 32'd0;
            lean_cnt          <= 32'd0;
        end else if (!seated) begin
            shoulder_diff_cm  <= diff_now;
            torso_state       <= TORSO_OK;
            torso_hp_penalty  <= 3'd0;
            diff_bad_cnt      <= 32'd0;
            side_close_cnt    <= 32'd0;
            lean_cnt          <= 32'd0;
        end else begin
            shoulder_diff_cm <= diff_now;

            if (diff_bad_now) begin
                if (diff_bad_cnt < STABLE_CYCLES)
                    diff_bad_cnt <= diff_bad_cnt + 32'd1;
            end else begin
                diff_bad_cnt <= 32'd0;
            end

            if (side_close_now) begin
                if (side_close_cnt < STABLE_CYCLES)
                    side_close_cnt <= side_close_cnt + 32'd1;
            end else begin
                side_close_cnt <= 32'd0;
            end

            if (lean_now) begin
                if (lean_cnt < STABLE_CYCLES)
                    lean_cnt <= lean_cnt + 32'd1;
            end else begin
                lean_cnt <= 32'd0;
            end

            // Priority: too close to one side is side bend; otherwise
            // persistent left/right distance imbalance is treated as twist.
            if (side_close_stable) begin
                torso_state      <= TORSO_SIDE;
                torso_hp_penalty <= 3'd2;
            end else if (diff_bad_stable) begin
                torso_state      <= TORSO_TWIST;
                torso_hp_penalty <= 3'd3;
            end else if (lean_stable) begin
                torso_state      <= TORSO_LEAN;
                torso_hp_penalty <= 3'd1;
            end else begin
                torso_state      <= TORSO_OK;
                torso_hp_penalty <= 3'd0;
            end
        end
    end

endmodule

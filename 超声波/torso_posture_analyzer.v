`timescale 1ns / 1ps

module torso_posture_analyzer #(
    parameter [9:0] LEAN_DIFF_CM  = 10'd5,
    parameter [9:0] SIDE_DIFF_CM  = 10'd12,
    parameter [9:0] TWIST_DIFF_CM = 10'd22
)(
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

    always @(*) begin
        if (left45_distance_cm >= right45_distance_cm)
            shoulder_diff_cm = left45_distance_cm - right45_distance_cm;
        else
            shoulder_diff_cm = right45_distance_cm - left45_distance_cm;

        if (!seated) begin
            torso_state = TORSO_OK;
            torso_hp_penalty = 3'd0;
        end else if (shoulder_diff_cm >= TWIST_DIFF_CM) begin
            torso_state = TORSO_TWIST;
            torso_hp_penalty = 3'd3;
        end else if (shoulder_diff_cm >= SIDE_DIFF_CM) begin
            torso_state = TORSO_SIDE;
            torso_hp_penalty = 3'd2;
        end else if (shoulder_diff_cm >= LEAN_DIFF_CM) begin
            torso_state = TORSO_LEAN;
            torso_hp_penalty = 3'd1;
        end else begin
            torso_state = TORSO_OK;
            torso_hp_penalty = 3'd0;
        end
    end

endmodule

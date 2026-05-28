`timescale 1ns / 1ps

module hp_engine #(
    parameter integer INIT_HP  = 100
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick_1hz,
    input  wire       seated,
    input  wire [2:0] seat_state,
    input  wire [9:0] distance_cm,
    input  wire [2:0] torso_hp_penalty,
    input  wire       sim_fast,
    output reg  [7:0] hp,
    output wire       hp_zero_alarm,
    output reg  [1:0] posture_level
);

    localparam [1:0] POSTURE_SAFE   = 2'd0;
    localparam [1:0] POSTURE_WARN   = 2'd1;
    localparam [1:0] POSTURE_DANGER = 2'd2;
    localparam [2:0] ST_IDLE         = 3'd0;
    localparam [9:0] HEAD_WARN_CM    = 10'd26;
    localparam [9:0] HEAD_DANGER_CM  = 10'd20;

    reg [5:0] sec_cnt;
    reg       minute_tick;
    reg signed [5:0] hp_delta;
    reg [7:0] hp_delta_abs;

    assign hp_zero_alarm = (hp == 8'd0);

    always @(*) begin
        if (distance_cm >= HEAD_WARN_CM)
            hp_delta = 6'sd1 - {3'd0, torso_hp_penalty};
        else if (distance_cm >= HEAD_DANGER_CM)
            hp_delta = -6'sd1 - {3'd0, torso_hp_penalty};
        else
            hp_delta = -6'sd3 - {3'd0, torso_hp_penalty};

        if (hp_delta < 0)
            hp_delta_abs = -hp_delta;
        else
            hp_delta_abs = hp_delta;
    end

    always @(*) begin
        if (distance_cm >= HEAD_WARN_CM)
            posture_level = POSTURE_SAFE;
        else if (distance_cm >= HEAD_DANGER_CM)
            posture_level = POSTURE_WARN;
        else
            posture_level = POSTURE_DANGER;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sec_cnt     <= 6'd0;
            minute_tick <= 1'b0;
        end else begin
            minute_tick <= 1'b0;
            if (tick_1hz) begin
                if (sim_fast != 0) begin
                    minute_tick <= 1'b1;
                end else if (sec_cnt == 6'd59) begin
                    sec_cnt     <= 6'd0;
                    minute_tick <= 1'b1;
                end else begin
                    sec_cnt <= sec_cnt + 6'd1;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hp <= INIT_HP;
        end else if (seat_state == ST_IDLE) begin
            hp <= 8'd100;
        end else if (minute_tick && seated) begin
            if (hp_delta >= 0) begin
                if ((hp + hp_delta_abs) >= 8'd100)
                    hp <= 8'd100;
                else
                    hp <= hp + hp_delta_abs;
            end else begin
                if (hp > hp_delta_abs)
                    hp <= hp - hp_delta_abs;
                else
                    hp <= 8'd0;
            end
        end
    end

endmodule

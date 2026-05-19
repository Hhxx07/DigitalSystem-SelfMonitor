`timescale 1ns / 1ps

module hp_engine #(
    parameter integer INIT_HP  = 100
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick_1hz,
    input  wire       seated,
    input  wire [9:0] distance_cm,
    input  wire       sim_fast,
    output reg  [7:0] hp,
    output wire       hp_zero_alarm,
    output reg  [1:0] posture_level
);

    localparam [1:0] POSTURE_SAFE   = 2'd0;
    localparam [1:0] POSTURE_WARN   = 2'd1;
    localparam [1:0] POSTURE_DANGER = 2'd2;

    reg [5:0] sec_cnt;
    reg       minute_tick;

    assign hp_zero_alarm = (hp == 8'd0);

    always @(*) begin
        if (distance_cm > 10'd50)
            posture_level = POSTURE_SAFE;
        else if (distance_cm >= 10'd30)
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
        end else if (minute_tick && seated) begin
            if (distance_cm > 10'd50) begin
                if (hp < 8'd100)
                    hp <= hp + 8'd1;
                else
                    hp <= 8'd100;
            end else if (distance_cm >= 10'd30) begin
                if (hp > 8'd0)
                    hp <= hp - 8'd1;
                else
                    hp <= 8'd0;
            end else begin
                if (hp > 8'd3)
                    hp <= hp - 8'd3;
                else
                    hp <= 8'd0;
            end
        end
    end

endmodule

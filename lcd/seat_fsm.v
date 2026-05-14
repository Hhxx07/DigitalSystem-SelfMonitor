`timescale 1ns / 1ps

module seat_fsm #(
    parameter integer SIM_FAST = 0
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick_1hz,
    input  wire       seated,
    output reg [2:0]  state,
    output reg [15:0] sit_time_min,
    output reg [15:0] away_time_min
);

    localparam [2:0] ST_IDLE           = 3'd0;
    localparam [2:0] ST_STUDY          = 3'd1;
    localparam [2:0] ST_SEDENTARY      = 3'd2;
    localparam [2:0] ST_OVER_SEDENTARY = 3'd3;
    localparam [2:0] ST_REST           = 3'd4;
    localparam [2:0] ST_AWAY_LONG      = 3'd5;

    reg [5:0] sec_cnt;
    reg       minute_tick;
    reg       prev_seated;
    reg       has_sat_once;

    reg [15:0] next_sit;
    reg [15:0] next_away;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sec_cnt     <= 6'd0;
            minute_tick <= 1'b0;
        end else begin
            minute_tick <= 1'b0;
            if (tick_1hz) begin
                if (SIM_FAST != 0) begin
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
            state        <= ST_IDLE;
            sit_time_min <= 16'd0;
            away_time_min <= 16'd0;
            prev_seated  <= 1'b0;
            has_sat_once <= 1'b0;
        end else begin
            prev_seated <= seated;

            /*
             * State policy:
             * - While seated, sit_time_min is continuous seated time.
             * - Leaving after any valid seated period enters REST/AWAY_LONG by away time.
             * - Returning within 3 minutes clears the sitting timer and restarts STUDY.
             * - Away for 30 minutes returns to IDLE and clears the sitting timer.
             */
            if (seated && !prev_seated) begin
                has_sat_once  <= 1'b1;
                away_time_min <= 16'd0;
                if (away_time_min <= 16'd3)
                    sit_time_min <= 16'd0;
                if (sit_time_min >= 16'd60)
                    state <= ST_OVER_SEDENTARY;
                else if (sit_time_min >= 16'd45)
                    state <= ST_SEDENTARY;
                else
                    state <= ST_STUDY;
            end

            if (minute_tick) begin
                if (seated) begin
                    has_sat_once  <= 1'b1;
                    away_time_min <= 16'd0;

                    if (sit_time_min != 16'hffff)
                        next_sit = sit_time_min + 16'd1;
                    else
                        next_sit = sit_time_min;

                    sit_time_min <= next_sit;

                    if (next_sit >= 16'd60)
                        state <= ST_OVER_SEDENTARY;
                    else if (next_sit >= 16'd45)
                        state <= ST_SEDENTARY;
                    else
                        state <= ST_STUDY;
                end else begin
                    if (has_sat_once) begin
                        if (away_time_min != 16'hffff)
                            next_away = away_time_min + 16'd1;
                        else
                            next_away = away_time_min;

                        if (next_away >= 16'd30) begin
                            away_time_min <= 16'd0;
                            sit_time_min  <= 16'd0;
                            has_sat_once  <= 1'b0;
                            state         <= ST_IDLE;
                        end else begin
                            away_time_min <= next_away;
                            if (next_away >= 16'd20)
                                state <= ST_AWAY_LONG;
                            else
                                state <= ST_REST;
                        end
                    end else begin
                        away_time_min <= 16'd0;
                        sit_time_min  <= 16'd0;
                        state         <= ST_IDLE;
                    end
                end
            end
        end
    end

endmodule

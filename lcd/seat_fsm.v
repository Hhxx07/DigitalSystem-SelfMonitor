`timescale 1ns / 1ps

module seat_fsm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick_1hz,
    input  wire       seated,
    input  wire       sim_fast,
    output reg [2:0]  state,
    output reg [15:0] sit_time_min,
    output reg [5:0]  sit_time_sec,
    output reg [15:0] away_time_min,
    output reg [5:0]  away_time_sec
);

    localparam [2:0] ST_IDLE           = 3'd0;
    localparam [2:0] ST_STUDY          = 3'd1;
    localparam [2:0] ST_SEDENTARY      = 3'd2;
    localparam [2:0] ST_OVER_SEDENTARY = 3'd3;
    localparam [2:0] ST_REST           = 3'd4;
    localparam [2:0] ST_AWAY_LONG      = 3'd5;

    reg       prev_seated;
    reg       has_sat_once;

    reg [15:0] next_sit;
    reg [15:0] next_away;
    reg [5:0]  next_sit_sec;
    reg [5:0]  next_away_sec;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= ST_IDLE;
            sit_time_min <= 16'd0;
            sit_time_sec <= 6'd0;
            away_time_min <= 16'd0;
            away_time_sec <= 6'd0;
            prev_seated  <= 1'b0;
            has_sat_once <= 1'b0;
        end else begin
            prev_seated <= seated;

            /*
             * State policy:
             * - While seated, sit_time_min is continuous seated time.
             * - Leaving after any valid seated period enters REST/AWAY_LONG by away time.
             * - Returning after more than 3 away minutes clears the sitting timer
             *   and restarts STUDY; returning within 3 minutes keeps the old timer.
             * - Away for 30 minutes returns to IDLE and clears the sitting timer.
             */
            if (seated && !prev_seated) begin
                has_sat_once  <= 1'b1;
                away_time_min <= 16'd0;
                away_time_sec <= 6'd0;
                if ((away_time_min > 16'd3) ||
                    ((away_time_min == 16'd3) && (away_time_sec != 6'd0))) begin
                    sit_time_min <= 16'd0;
                    sit_time_sec <= 6'd0;
                    state        <= ST_STUDY;
                end else if (sit_time_min >= 16'd60) begin
                    state <= ST_OVER_SEDENTARY;
                end else if (sit_time_min >= 16'd45) begin
                    state <= ST_SEDENTARY;
                end else begin
                    state <= ST_STUDY;
                end
            end else if (!seated && prev_seated && has_sat_once) begin
                state <= ST_REST;
            end

            if (tick_1hz) begin
                if (seated) begin
                    has_sat_once  <= 1'b1;
                    away_time_min <= 16'd0;
                    away_time_sec <= 6'd0;

                    next_sit     = sit_time_min;
                    next_sit_sec = sit_time_sec;

                    if (sim_fast != 0) begin
                        next_sit_sec = 6'd0;
                        if (sit_time_min != 16'hffff)
                            next_sit = sit_time_min + 16'd1;
                    end else if (sit_time_sec == 6'd59) begin
                        next_sit_sec = 6'd0;
                        if (sit_time_min != 16'hffff)
                            next_sit = sit_time_min + 16'd1;
                    end else begin
                        next_sit_sec = sit_time_sec + 6'd1;
                    end

                    sit_time_min <= next_sit;
                    sit_time_sec <= next_sit_sec;

                    if (next_sit >= 16'd60)
                        state <= ST_OVER_SEDENTARY;
                    else if (next_sit >= 16'd45)
                        state <= ST_SEDENTARY;
                    else
                        state <= ST_STUDY;
                end else begin
                    if (has_sat_once) begin
                        next_away     = away_time_min;
                        next_away_sec = away_time_sec;

                        if (sim_fast != 0) begin
                            next_away_sec = 6'd0;
                            if (away_time_min != 16'hffff)
                                next_away = away_time_min + 16'd1;
                        end else if (away_time_sec == 6'd59) begin
                            next_away_sec = 6'd0;
                            if (away_time_min != 16'hffff)
                                next_away = away_time_min + 16'd1;
                        end else begin
                            next_away_sec = away_time_sec + 6'd1;
                        end

                        if (next_away >= 16'd30) begin
                            away_time_min <= 16'd0;
                            away_time_sec <= 6'd0;
                            sit_time_min  <= 16'd0;
                            sit_time_sec  <= 6'd0;
                            has_sat_once  <= 1'b0;
                            state         <= ST_IDLE;
                        end else begin
                            away_time_min <= next_away;
                            away_time_sec <= next_away_sec;
                            if (next_away >= 16'd20)
                                state <= ST_AWAY_LONG;
                            else
                                state <= ST_REST;
                        end
                    end else begin
                        away_time_min <= 16'd0;
                        away_time_sec <= 6'd0;
                        sit_time_min  <= 16'd0;
                        sit_time_sec  <= 6'd0;
                        state         <= ST_IDLE;
                    end
                end
            end
        end
    end

endmodule

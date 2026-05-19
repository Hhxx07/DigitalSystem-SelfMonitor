`timescale 1ns / 1ps

module rtc_clock #(
    parameter integer CLK_HZ     = 1000000,
    parameter integer INIT_YEAR  = 2026,
    parameter integer INIT_MONTH = 1,
    parameter integer INIT_DAY   = 1,
    parameter integer INIT_HOUR  = 0,
    parameter integer INIT_MIN   = 0,
    parameter integer INIT_SEC   = 0
)(
    input  wire        clk,
    input  wire        rst_n,
    output reg         tick_1hz,
    output reg  [15:0] year,
    output reg  [7:0]  month,
    output reg  [7:0]  day,
    output reg  [7:0]  hour,
    output reg  [7:0]  minute,
    output reg  [7:0]  second
);

    reg [31:0] div_cnt;

    function is_leap_year;
        input [15:0] y;
        begin
            if ((y % 400) == 0)
                is_leap_year = 1'b1;
            else if ((y % 100) == 0)
                is_leap_year = 1'b0;
            else if ((y % 4) == 0)
                is_leap_year = 1'b1;
            else
                is_leap_year = 1'b0;
        end
    endfunction

    function [7:0] days_in_month;
        input [15:0] y;
        input [7:0]  m;
        begin
            case (m)
                8'd1, 8'd3, 8'd5, 8'd7, 8'd8, 8'd10, 8'd12: days_in_month = 8'd31;
                8'd4, 8'd6, 8'd9, 8'd11: days_in_month = 8'd30;
                8'd2: days_in_month = is_leap_year(y) ? 8'd29 : 8'd28;
                default: days_in_month = 8'd31;
            endcase
        end
    endfunction

    task step_one_second;
        begin
            if (second < 8'd59) begin
                second <= second + 8'd1;
            end else begin
                second <= 8'd0;
                if (minute < 8'd59) begin
                    minute <= minute + 8'd1;
                end else begin
                    minute <= 8'd0;
                    if (hour < 8'd23) begin
                        hour <= hour + 8'd1;
                    end else begin
                        hour <= 8'd0;
                        if (day < days_in_month(year, month)) begin
                            day <= day + 8'd1;
                        end else begin
                            day <= 8'd1;
                            if (month < 8'd12) begin
                                month <= month + 8'd1;
                            end else begin
                                month <= 8'd1;
                                year <= year + 16'd1;
                            end
                        end
                    end
                end
            end
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt  <= 32'd0;
            tick_1hz <= 1'b0;
            year     <= INIT_YEAR;
            month    <= INIT_MONTH;
            day      <= INIT_DAY;
            hour     <= INIT_HOUR;
            minute   <= INIT_MIN;
            second   <= INIT_SEC;
        end else begin
            tick_1hz <= 1'b0;
            if (div_cnt >= (CLK_HZ - 1)) begin
                div_cnt  <= 32'd0;
                tick_1hz <= 1'b1;
                step_one_second;
            end else begin
                div_cnt <= div_cnt + 32'd1;
            end
        end
    end

endmodule

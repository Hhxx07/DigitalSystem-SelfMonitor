`timescale 1ns / 1ps

module health_lcd_top #(
    parameter integer CLK_HZ     = 100000000,
    parameter integer SPI_CLK_DIV = 5,
    parameter integer FRAME_HZ   = 2,
    parameter integer INIT_YEAR  = 2026,
    parameter integer INIT_MONTH = 1,
    parameter integer INIT_DAY   = 1,
    parameter integer INIT_HOUR  = 0,
    parameter integer INIT_MIN   = 0,
    parameter integer INIT_SEC   = 0,
    parameter [7:0]   MADCTL_PARAM = 8'h00,
    parameter [15:0]  LCD_X_OFFSET = 16'd2,
    parameter [15:0]  LCD_Y_OFFSET = 16'd1
)(
    input  wire clk,
    input  wire rst_n,

    input  wire pressure_ok,
    input  wire ir_ok,
    input  wire ultrasonic_front_echo,
    input  wire ultrasonic_left45_echo,
    input  wire ultrasonic_right45_echo,

    input  wire [15:0] weight_left_front,
    input  wire [15:0] weight_left_rear,
    input  wire [15:0] weight_right_front,
    input  wire [15:0] weight_right_rear,

    input  wire sim_fast,

    output wire ultrasonic_front_trig,
    output wire ultrasonic_left45_trig,
    output wire ultrasonic_right45_trig,

    output wire [16:0] weight_front_back_diff,
    output wire [16:0] weight_left_right_diff,
    output wire [1:0]  weight_front_back_balance,
    output wire [1:0]  weight_left_right_balance,

    output wire lcd_cs_n,
    output wire lcd_rst_n,
    output wire lcd_dc,
    output wire lcd_scl,
    output wire lcd_mosi,
    output wire lcd_blk
);

    wire seated;
    wire tick_1hz;
    wire [15:0] year;
    wire [7:0]  month;
    wire [7:0]  day;
    wire [7:0]  hour;
    wire [7:0]  minute;
    wire [7:0]  second;

    wire [2:0]  seat_state;
    wire [15:0] sit_time_min;
    wire [5:0]  sit_time_sec;
    wire [15:0] away_time_min;
    wire [5:0]  away_time_sec;
    wire [7:0]  hp_value;
    wire        hp_zero_alarm;
    wire [1:0]  posture_level;
    wire [15:0] ultrasonic_front_distance_cm;
    wire [15:0] ultrasonic_left45_distance_cm;
    wire [15:0] ultrasonic_right45_distance_cm;
    wire [9:0]  posture_distance_cm;
    wire [9:0]  shoulder_left45_distance_cm;
    wire [9:0]  shoulder_right45_distance_cm;
    wire [9:0]  shoulder_diff_cm;
    wire [1:0]  torso_state;
    wire [2:0]  torso_hp_penalty;
    wire [16:0] weight_front_sum;
    wire [16:0] weight_rear_sum;
    wire [16:0] weight_left_sum;
    wire [16:0] weight_right_sum;

    wire init_done;
    wire spi_busy;
    wire spi_done;

    wire       init_spi_start;
    wire       init_spi_dc;
    wire [7:0] init_spi_data;
    wire       render_spi_start;
    wire       render_spi_dc;
    wire [7:0] render_spi_data;

    wire       spi_start_mux;
    wire       spi_dc_mux;
    wire [7:0] spi_data_mux;

    assign seated = pressure_ok & ir_ok;
    assign lcd_blk = 1'b1;
    assign posture_distance_cm = (ultrasonic_front_distance_cm > 16'd1023) ? 10'd1023 : ultrasonic_front_distance_cm[9:0];
    assign shoulder_left45_distance_cm = (ultrasonic_left45_distance_cm > 16'd1023) ? 10'd1023 : ultrasonic_left45_distance_cm[9:0];
    assign shoulder_right45_distance_cm = (ultrasonic_right45_distance_cm > 16'd1023) ? 10'd1023 : ultrasonic_right45_distance_cm[9:0];

    assign spi_start_mux = init_done ? render_spi_start : init_spi_start;
    assign spi_dc_mux    = init_done ? render_spi_dc    : init_spi_dc;
    assign spi_data_mux  = init_done ? render_spi_data  : init_spi_data;

    rtc_clock #(
        .CLK_HZ(CLK_HZ),
        .INIT_YEAR(INIT_YEAR),
        .INIT_MONTH(INIT_MONTH),
        .INIT_DAY(INIT_DAY),
        .INIT_HOUR(INIT_HOUR),
        .INIT_MIN(INIT_MIN),
        .INIT_SEC(INIT_SEC)
    ) u_rtc (
        .clk(clk),
        .rst_n(rst_n),
        .tick_1hz(tick_1hz),
        .year(year),
        .month(month),
        .day(day),
        .hour(hour),
        .minute(minute),
        .second(second)
    );

    seat_fsm u_seat (
        .clk(clk),
        .rst_n(rst_n),
        .tick_1hz(tick_1hz),
        .seated(seated),
        .state(seat_state),
        .sit_time_min(sit_time_min),
        .sit_time_sec(sit_time_sec),
        .away_time_min(away_time_min),
        .away_time_sec(away_time_sec),
        .sim_fast(sim_fast)
    );

    top_Ranging u_ultrasonic_front (
        .clk(clk),
        .rst_n(rst_n),
        .ultrasonic_echo(ultrasonic_front_echo),
        .ultrasonic_trig(ultrasonic_front_trig),
        .distance_cm(ultrasonic_front_distance_cm)
    );

    top_Ranging u_ultrasonic_left45 (
        .clk(clk),
        .rst_n(rst_n),
        .ultrasonic_echo(ultrasonic_left45_echo),
        .ultrasonic_trig(ultrasonic_left45_trig),
        .distance_cm(ultrasonic_left45_distance_cm)
    );

    top_Ranging u_ultrasonic_right45 (
        .clk(clk),
        .rst_n(rst_n),
        .ultrasonic_echo(ultrasonic_right45_echo),
        .ultrasonic_trig(ultrasonic_right45_trig),
        .distance_cm(ultrasonic_right45_distance_cm)
    );

    torso_posture_analyzer u_torso (
        .seated(seated),
        .front_distance_cm(posture_distance_cm),
        .left45_distance_cm(shoulder_left45_distance_cm),
        .right45_distance_cm(shoulder_right45_distance_cm),
        .shoulder_diff_cm(shoulder_diff_cm),
        .torso_state(torso_state),
        .torso_hp_penalty(torso_hp_penalty)
    );

    weight_balance_analyzer u_weight_balance (
        .weight_left_front(weight_left_front),
        .weight_left_rear(weight_left_rear),
        .weight_right_front(weight_right_front),
        .weight_right_rear(weight_right_rear),
        .front_weight_sum(weight_front_sum),
        .rear_weight_sum(weight_rear_sum),
        .left_weight_sum(weight_left_sum),
        .right_weight_sum(weight_right_sum),
        .front_back_diff(weight_front_back_diff),
        .left_right_diff(weight_left_right_diff),
        .front_back_balance(weight_front_back_balance),
        .left_right_balance(weight_left_right_balance)
    );

    hp_engine #(
        .INIT_HP(100)
    ) u_hp (
        .clk(clk),
        .rst_n(rst_n),
        .tick_1hz(tick_1hz),
        .seated(seated),
        .seat_state(seat_state),
        .distance_cm(posture_distance_cm),
        .torso_hp_penalty(torso_hp_penalty),
        .hp(hp_value),
        .hp_zero_alarm(hp_zero_alarm),
        .posture_level(posture_level),
        .sim_fast(sim_fast)
    );

    st7735_init #(
        .CLK_HZ(CLK_HZ),
        .MADCTL_PARAM(MADCTL_PARAM),
        .LCD_X_OFFSET(LCD_X_OFFSET),
        .LCD_Y_OFFSET(LCD_Y_OFFSET)
    ) u_lcd_init (
        .clk(clk),
        .rst_n(rst_n),
        .spi_busy(spi_busy),
        .spi_done(spi_done),
        .spi_start(init_spi_start),
        .spi_dc(init_spi_dc),
        .spi_data(init_spi_data),
        .lcd_rst_n(lcd_rst_n),
        .init_done(init_done)
    );

    display_renderer #(
        .CLK_HZ(CLK_HZ),
        .FRAME_HZ(FRAME_HZ),
        .LCD_X_OFFSET(LCD_X_OFFSET),
        .LCD_Y_OFFSET(LCD_Y_OFFSET)
    ) u_renderer (
        .clk(clk),
        .rst_n(rst_n),
        .init_done(init_done),
        .spi_busy(spi_busy),
        .spi_done(spi_done),
        .year(year),
        .month(month),
        .day(day),
        .hour(hour),
        .minute(minute),
        .second(second),
        .seated(seated),
        .seat_state(seat_state),
        .sit_time_min(sit_time_min),
        .sit_time_sec(sit_time_sec),
        .away_time_min(away_time_min),
        .away_time_sec(away_time_sec),
        .distance_cm(posture_distance_cm),
        .shoulder_diff_cm(shoulder_diff_cm),
        .torso_state(torso_state),
        .posture_level(posture_level),
        .hp(hp_value),
        .hp_zero_alarm(hp_zero_alarm),
        .spi_start(render_spi_start),
        .spi_dc(render_spi_dc),
        .spi_data(render_spi_data)
    );

    st7735_spi #(
        .CLK_DIV(SPI_CLK_DIV)
    ) u_spi (
        .clk(clk),
        .rst_n(rst_n),
        .start(spi_start_mux),
        .dc(spi_dc_mux),
        .data(spi_data_mux),
        .busy(spi_busy),
        .done(spi_done),
        .lcd_cs_n(lcd_cs_n),
        .lcd_dc(lcd_dc),
        .lcd_scl(lcd_scl),
        .lcd_mosi(lcd_mosi)
    );

endmodule

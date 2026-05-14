`timescale 1ns / 1ps

// ============================================================
// 模块: health_lcd_top
// 功能: 顶层模块，连接所有子模块，实现健康监测 LCD 显示系统
//       传感器信号 -> 状态逻辑 -> 渲染 -> SPI -> ST7735 LCD
// 输入: clk, rst_n
//       pressure_ok(压力传感器就座), ir_ok(红外传感器就座)
//       distance_cm[9:0](超声波测距，单位 cm)
// 输出: lcd_cs_n/rst_n/dc/scl/mosi/blk — LCD SPI 接口引脚
// 参数: CLK_HZ, SPI_CLK_DIV, FRAME_HZ, SIM_FAST, INIT_* — 时间初值, MADCTL_PARAM
// ============================================================
module health_lcd_top #(
    parameter integer CLK_HZ     = 100000000,
    parameter integer SPI_CLK_DIV = 5,
    parameter integer FRAME_HZ   = 2,
    parameter integer SIM_FAST   = 0,
    parameter integer INIT_YEAR  = 2026,
    parameter integer INIT_MONTH = 1,
    parameter integer INIT_DAY   = 1,
    parameter integer INIT_HOUR  = 0,
    parameter integer INIT_MIN   = 0,
    parameter integer INIT_SEC   = 0,
    parameter [7:0]   MADCTL_PARAM = 8'h00
)(
    input  wire clk,
    input  wire rst_n,

    input  wire pressure_ok,   // 压力传感器：1=有人就座
    input  wire ir_ok,         // 红外传感器：1=有人就座
    input  wire [9:0] distance_cm, // 超声波距离（cm）

    output wire lcd_cs_n,
    output wire lcd_rst_n,
    output wire lcd_dc,
    output wire lcd_scl,
    output wire lcd_mosi,
    output wire lcd_blk        // 背光控制，固定拉高
);

    // 内部信号
    wire seated;       // 两路传感器同时有效才判定为就座
    wire tick_1hz;     // 1Hz 时钟脉冲（来自 rtc_clock）
    wire [15:0] year;
    wire [7:0]  month, day, hour, minute, second;

    wire [2:0]  seat_state;
    wire [15:0] sit_time_min, away_time_min;
    wire [7:0]  hp_value;
    wire        hp_zero_alarm;
    wire [1:0]  posture_level;

    wire init_done;    // LCD 初始化完成标志
    wire spi_busy, spi_done;

    // 初始化阶段和渲染阶段各自的 SPI 信号
    wire       init_spi_start, render_spi_start;
    wire       init_spi_dc,    render_spi_dc;
    wire [7:0] init_spi_data,  render_spi_data;

    // init_done 前由初始化模块驱动 SPI，之后由渲染模块驱动
    wire       spi_start_mux;
    wire       spi_dc_mux;
    wire [7:0] spi_data_mux;

    assign seated = pressure_ok & ir_ok;
    assign lcd_blk = 1'b1;

    assign spi_start_mux = init_done ? render_spi_start : init_spi_start;
    assign spi_dc_mux    = init_done ? render_spi_dc    : init_spi_dc;
    assign spi_data_mux  = init_done ? render_spi_data  : init_spi_data;

    // RTC：产生 tick_1hz 和完整日历时间
    rtc_clock #(
        .CLK_HZ(CLK_HZ),
        .INIT_YEAR(INIT_YEAR), .INIT_MONTH(INIT_MONTH), .INIT_DAY(INIT_DAY),
        .INIT_HOUR(INIT_HOUR), .INIT_MIN(INIT_MIN),     .INIT_SEC(INIT_SEC)
    ) u_rtc (
        .clk(clk), .rst_n(rst_n),
        .tick_1hz(tick_1hz),
        .year(year), .month(month), .day(day),
        .hour(hour), .minute(minute), .second(second)
    );

    // 就座状态机：统计就座/离座时间，输出健康状态
    seat_fsm #(.SIM_FAST(SIM_FAST)) u_seat (
        .clk(clk), .rst_n(rst_n),
        .tick_1hz(tick_1hz), .seated(seated),
        .state(seat_state),
        .sit_time_min(sit_time_min), .away_time_min(away_time_min)
    );

    // HP 引擎：根据坐姿距离每分钟增减健康值
    hp_engine #(.SIM_FAST(SIM_FAST), .INIT_HP(100)) u_hp (
        .clk(clk), .rst_n(rst_n),
        .tick_1hz(tick_1hz), .seated(seated), .distance_cm(distance_cm),
        .hp(hp_value), .hp_zero_alarm(hp_zero_alarm), .posture_level(posture_level)
    );

    // LCD 初始化控制器：上电后发送 ST7735 初始化序列
    st7735_init #(.CLK_HZ(CLK_HZ), .MADCTL_PARAM(MADCTL_PARAM)) u_lcd_init (
        .clk(clk), .rst_n(rst_n),
        .spi_busy(spi_busy), .spi_done(spi_done),
        .spi_start(init_spi_start), .spi_dc(init_spi_dc), .spi_data(init_spi_data),
        .lcd_rst_n(lcd_rst_n), .init_done(init_done)
    );

    // 帧渲染器：将健康数据按帧率绘制到 128x128 屏幕
    display_renderer #(.CLK_HZ(CLK_HZ), .FRAME_HZ(FRAME_HZ)) u_renderer (
        .clk(clk), .rst_n(rst_n),
        .init_done(init_done), .spi_busy(spi_busy), .spi_done(spi_done),
        .year(year), .month(month), .day(day),
        .hour(hour), .minute(minute), .second(second),
        .seat_state(seat_state), .sit_time_min(sit_time_min), .away_time_min(away_time_min),
        .hp(hp_value), .hp_zero_alarm(hp_zero_alarm),
        .spi_start(render_spi_start), .spi_dc(render_spi_dc), .spi_data(render_spi_data)
    );

    // SPI 主机：将字节串行发送给 ST7735
    st7735_spi #(.CLK_DIV(SPI_CLK_DIV)) u_spi (
        .clk(clk), .rst_n(rst_n),
        .start(spi_start_mux), .dc(spi_dc_mux), .data(spi_data_mux),
        .busy(spi_busy), .done(spi_done),
        .lcd_cs_n(lcd_cs_n), .lcd_dc(lcd_dc), .lcd_scl(lcd_scl), .lcd_mosi(lcd_mosi)
    );

endmodule

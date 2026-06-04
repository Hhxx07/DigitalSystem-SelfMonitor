`timescale 1ns / 1ps

// 健康坐姿 LCD 系统顶层。
// 汇总压力、红外、三路超声波和时间信息，计算座椅状态、姿态、HP，
// 并通过 ST7735 SPI 接口刷新 128x128 LCD。
//
// 入座（seated）判断由三个条件共同决定：
//   seated = ir_active && ultrasonic_seated && pressure_ok
//
//   ir_active:          PIR 红外时间窗口活动标志（3 分钟内有人体运动触发则为 1）
//   ultrasonic_seated:  三路超声波距离均 < ULTRASONIC_SEATED_THRESHOLD_CM
//   pressure_ok:        压力传感器判断结果（接口不变）
//
// 其中红外具有否决权：ir_active=0 时直接判无人入座。
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
    parameter [15:0]  LCD_Y_OFFSET = 16'd1,
    parameter [11:0]  ULTRASONIC_SEATED_THRESHOLD_CM = 12'd120,
    parameter integer PIR_WINDOW_CYCLES_FAST = 200,
    parameter integer PIR_INACTIVE_WINDOW_SEC = 180,
    parameter integer PIR_SIM_FAST = 0
)(
    input  wire clk,
    input  wire rst_n,

    input  wire pressure_ok,
    input  wire pir_in,      // PIR 红外传感器原始信号（替代原来的 ir_ok）
    input  wire ultrasonic_front_echo,
    input  wire ultrasonic_left45_echo,
    input  wire ultrasonic_right45_echo,

    input  wire [15:0] weight_left_front,
    input  wire [15:0] weight_left_rear,
    input  wire [15:0] weight_right_front,
    input  wire [15:0] weight_right_rear,
    input  wire [1:0]  weight_left_right_state,
    input  wire [1:0]  weight_front_back_state,
    input  wire        lean_left,
    input  wire        lean_right,
    input  wire        lean_front,
    input  wire        lean_back,

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

    // 系统内部状态与传感器中间量。
    // seated 由红外活动标志、超声波距离和压力三条件共同确认。
    // RTC/座椅 FSM/HP/超声波结果都在此顶层汇合。
    wire seated;
    wire ir_active;         // PIR 时间窗口活动标志（3分钟内有人体运动触发则为1）
    wire ultrasonic_seated; // 超声波入座判定（三路距离均低于阈值）
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

    // LCD 初始化、渲染器和 SPI 发送器之间的握手信号。
    // 初始化完成前 SPI 数据来自 st7735_init，完成后切换到 display_renderer。
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

    // 入座判断 = 红外活动标志 AND 超声波入座 AND 压力正常。
    // ir_active 为 PIR 时间窗口活动标志（3 分钟内人体运动触发则为 1）。
    // ir_active=0 时直接否决入座（红外长时间无触发，判定无人）。
    // ultrasonic_seated 为三路超声波距离均低于 ULTRASONIC_SEATED_THRESHOLD_CM。
    // 三者同时满足才判定为入座。
    assign seated = ir_active && ultrasonic_seated && pressure_ok;
    assign lcd_blk = 1'b1;

    // 超声波入座判定：正前方、左45度、右45度距离均低于阈值，认为座椅前方
    // 有物体（人在座）。阈值默认为 120 cm，可滤除“无回波”的超大读数。
    assign ultrasonic_seated = (ultrasonic_front_distance_cm != 16'd0)
                            && (ultrasonic_left45_distance_cm != 16'd0)
                            && (ultrasonic_right45_distance_cm != 16'd0)
                            && (ultrasonic_front_distance_cm < {4'd0, ULTRASONIC_SEATED_THRESHOLD_CM})
                            && (ultrasonic_left45_distance_cm < {4'd0, ULTRASONIC_SEATED_THRESHOLD_CM})
                            && (ultrasonic_right45_distance_cm < {4'd0, ULTRASONIC_SEATED_THRESHOLD_CM});
    assign posture_distance_cm = (ultrasonic_front_distance_cm > 16'd1023) ? 10'd1023 : ultrasonic_front_distance_cm[9:0];
    assign shoulder_left45_distance_cm = (ultrasonic_left45_distance_cm > 16'd1023) ? 10'd1023 : ultrasonic_left45_distance_cm[9:0];
    assign shoulder_right45_distance_cm = (ultrasonic_right45_distance_cm > 16'd1023) ? 10'd1023 : ultrasonic_right45_distance_cm[9:0];

    // SPI 总线复用：初始化阶段发送控制命令，正常运行阶段发送画面刷新数据。
    assign spi_start_mux = init_done ? render_spi_start : init_spi_start;
    assign spi_dc_mux    = init_done ? render_spi_dc    : init_spi_dc;
    assign spi_data_mux  = init_done ? render_spi_data  : init_spi_data;

    // 软件 RTC，提供当前日期时间和 1 Hz 节拍。
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

    // PIR 红外人体检测模块。
    // 将 PIR 原始信号处理为 ir_active 时间窗口活动标志。
    // 预热完成前 ir_active=0（不干扰开机流程）；
    // 预热后统计 human_present 上升沿，窗口内无触发则 ir_active=0。
    // PIR_INACTIVE_WINDOW_SEC 为无触发窗口秒数（仿真中可覆盖为较小值加速测试）。
    pir_human_detector #(
        .CLK_FREQ_HZ(CLK_HZ),
        .WARMUP_SEC(60),
        .STABLE_MS(100),
        .SIM_FAST(PIR_SIM_FAST),
        .INACTIVE_WINDOW_SEC(PIR_INACTIVE_WINDOW_SEC),
        .INACTIVE_WINDOW_CYCLES_FAST(PIR_WINDOW_CYCLES_FAST)
    ) u_pir (
        .clk(clk),
        .rst_n(rst_n),
        .pir_in(pir_in),
        .pir_raw_sync(),
        .pir_valid(),
        .human_present(),
        .ir_active(ir_active)
    );

    // 座椅状态机，统计连续入座时间和离座休息时间。
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

    // 三路超声波分别测量头部正前方、左 45 度和右 45 度距离。
    top_Ranging #(
        .CLK_FREQ_HZ(CLK_HZ),
        .TRIG_START_DELAY_CYCLES(0)
    ) u_ultrasonic_front (
        .clk(clk),
        .rst_n(rst_n),
        .ultrasonic_echo(ultrasonic_front_echo),
        .ultrasonic_trig(ultrasonic_front_trig),
        .distance_cm(ultrasonic_front_distance_cm)
    );

    top_Ranging #(
        .CLK_FREQ_HZ(CLK_HZ),
        .TRIG_START_DELAY_CYCLES((CLK_HZ / 1000) * 22)
    ) u_ultrasonic_left45 (
        .clk(clk),
        .rst_n(rst_n),
        .ultrasonic_echo(ultrasonic_left45_echo),
        .ultrasonic_trig(ultrasonic_left45_trig),
        .distance_cm(ultrasonic_left45_distance_cm)
    );

    top_Ranging #(
        .CLK_FREQ_HZ(CLK_HZ),
        .TRIG_START_DELAY_CYCLES((CLK_HZ / 1000) * 44)
    ) u_ultrasonic_right45 (
        .clk(clk),
        .rst_n(rst_n),
        .ultrasonic_echo(ultrasonic_right45_echo),
        .ultrasonic_trig(ultrasonic_right45_trig),
        .distance_cm(ultrasonic_right45_distance_cm)
    );

    // 躯干姿态分析器，用左右 45 度距离差和阈值输出姿态状态与扣分。
    torso_posture_analyzer #(
        .CLK_HZ(CLK_HZ)
    ) u_torso (
        .clk(clk),
        .rst_n(rst_n),
        .seated(seated),
        .front_distance_cm(posture_distance_cm),
        .left45_distance_cm(shoulder_left45_distance_cm),
        .right45_distance_cm(shoulder_right45_distance_cm),
        .shoulder_diff_cm(shoulder_diff_cm),
        .torso_state(torso_state),
        .torso_hp_penalty(torso_hp_penalty)
    );

    // 压力分布分析器，计算前后/左右重量差及平衡状态，供外部观察或后续扩展使用。
    assign weight_front_sum = {1'b0, weight_left_front} + {1'b0, weight_right_front};
    assign weight_rear_sum  = {1'b0, weight_left_rear} + {1'b0, weight_right_rear};
    assign weight_left_sum  = {1'b0, weight_left_front} + {1'b0, weight_left_rear};
    assign weight_right_sum = {1'b0, weight_right_front} + {1'b0, weight_right_rear};

    assign weight_front_back_diff = (weight_front_sum >= weight_rear_sum) ?
                                    (weight_front_sum - weight_rear_sum) :
                                    (weight_rear_sum - weight_front_sum);
    assign weight_left_right_diff = (weight_left_sum >= weight_right_sum) ?
                                    (weight_left_sum - weight_right_sum) :
                                    (weight_right_sum - weight_left_sum);

    assign weight_front_back_balance = weight_front_back_state;
    assign weight_left_right_balance = weight_left_right_state;

    // HP 引擎，根据坐姿距离和躯干姿态按分钟更新健康值。
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

    // ST7735 初始化序列发生器，上电后完成 LCD 复位和基本显示参数配置。
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

    // LCD 画面渲染器，按帧率输出窗口设置命令和 RGB565 像素流。
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
        .weight_left_right_state(weight_left_right_state),
        .weight_front_back_state(weight_front_back_state),
        .lean_left(lean_left),
        .lean_right(lean_right),
        .lean_front(lean_front),
        .lean_back(lean_back),
        .hp(hp_value),
        .hp_zero_alarm(hp_zero_alarm),
        .spi_start(render_spi_start),
        .spi_dc(render_spi_dc),
        .spi_data(render_spi_data)
    );

    // SPI 物理发送器，将初始化/渲染数据串行输出到 LCD 引脚。
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

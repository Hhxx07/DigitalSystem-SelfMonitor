`timescale 1ns / 1ps

// ============================================================
// 模块: seat_fsm
// 功能: 久坐健康状态机，根据就座信号和时间统计判断用户状态
// 输入: clk, rst_n, tick_1hz(1Hz 脉冲), seated(就座检测)
// 输出: state[2:0](当前状态), sit_time_min(连续就座分钟), away_time_min(离座分钟)
// 参数: SIM_FAST — 非零时每秒计为一分钟（仿真加速）
// 状态: IDLE(0) STUDY(1) SEDENTARY(2) OVER_SEDENTARY(3) REST(4) AWAY_LONG(5)
// ============================================================
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

    localparam [2:0] ST_IDLE           = 3'd0; // 未就座且无历史记录
    localparam [2:0] ST_STUDY          = 3'd1; // 正常就座学习（<45 分钟）
    localparam [2:0] ST_SEDENTARY      = 3'd2; // 久坐警告（45~59 分钟）
    localparam [2:0] ST_OVER_SEDENTARY = 3'd3; // 严重久坐（>=60 分钟）
    localparam [2:0] ST_REST           = 3'd4; // 短暂离座休息（<20 分钟）
    localparam [2:0] ST_AWAY_LONG      = 3'd5; // 长时间离座（>=20 分钟）

    reg [5:0] sec_cnt;    // 秒计数，用于产生分钟 tick
    reg       minute_tick;
    reg       prev_seated;
    reg       has_sat_once; // 是否曾经就座过（用于区分初始 IDLE 和离座后 IDLE）

    reg [15:0] next_sit;
    reg [15:0] next_away;

    // 分频：每 60 个 tick_1hz 产生一次 minute_tick（SIM_FAST 模式下每秒即一分钟）
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

    // 状态转移逻辑
    // 策略：
    //   - 就座时 sit_time_min 持续累加，离座时清零 away_time_min
    //   - 离座后 3 分钟内回座：sit_time_min 清零重新计时
    //   - 离座超 30 分钟：回到 IDLE，所有计时器清零
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= ST_IDLE;
            sit_time_min <= 16'd0;
            away_time_min <= 16'd0;
            prev_seated  <= 1'b0;
            has_sat_once <= 1'b0;
        end else begin
            prev_seated <= seated;

            // 检测就座上升沿（离座->就座）
            if (seated && !prev_seated) begin
                has_sat_once  <= 1'b1;
                away_time_min <= 16'd0;
                // 短暂离座（<=3 分钟）回座时清零就座计时
                if (away_time_min <= 16'd3)
                    sit_time_min <= 16'd0;
                // 根据当前就座时长决定初始状态
                if (sit_time_min >= 16'd60)
                    state <= ST_OVER_SEDENTARY;
                else if (sit_time_min >= 16'd45)
                    state <= ST_SEDENTARY;
                else
                    state <= ST_STUDY;
            end

            // 每分钟更新计时器和状态
            if (minute_tick) begin
                if (seated) begin
                    has_sat_once  <= 1'b1;
                    away_time_min <= 16'd0;

                    // 就座时间累加（防溢出）
                    if (sit_time_min != 16'hffff)
                        next_sit = sit_time_min + 16'd1;
                    else
                        next_sit = sit_time_min;

                    sit_time_min <= next_sit;

                    // 根据就座时长更新状态
                    if (next_sit >= 16'd60)
                        state <= ST_OVER_SEDENTARY;
                    else if (next_sit >= 16'd45)
                        state <= ST_SEDENTARY;
                    else
                        state <= ST_STUDY;
                end else begin
                    if (has_sat_once) begin
                        // 离座时间累加（防溢出）
                        if (away_time_min != 16'hffff)
                            next_away = away_time_min + 16'd1;
                        else
                            next_away = away_time_min;

                        if (next_away >= 16'd30) begin
                            // 离座超 30 分钟：完全重置
                            away_time_min <= 16'd0;
                            sit_time_min  <= 16'd0;
                            has_sat_once  <= 1'b0;
                            state         <= ST_IDLE;
                        end else begin
                            away_time_min <= next_away;
                            // 离座 20 分钟以上为长时间离座
                            if (next_away >= 16'd20)
                                state <= ST_AWAY_LONG;
                            else
                                state <= ST_REST;
                        end
                    end else begin
                        // 从未就座过，保持 IDLE
                        away_time_min <= 16'd0;
                        sit_time_min  <= 16'd0;
                        state         <= ST_IDLE;
                    end
                end
            end
        end
    end

endmodule

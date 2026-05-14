`timescale 1ns / 1ps

// ============================================================
// 模块: hp_engine
// 功能: 健康值（HP）计算引擎，根据坐姿距离每分钟增减 HP
// 输入: clk, rst_n, tick_1hz, seated(就座), distance_cm[9:0](超声波距离)
// 输出: hp[7:0](0~100), hp_zero_alarm(HP 归零报警), posture_level[1:0](坐姿等级)
// 参数: SIM_FAST — 仿真加速; INIT_HP — 初始 HP 值
// 坐姿等级: SAFE(>50cm,+1/min) WARN(30~50cm,-1/min) DANGER(<30cm,-3/min)
// ============================================================
module hp_engine #(
    parameter integer SIM_FAST = 0,
    parameter integer INIT_HP  = 100
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick_1hz,
    input  wire       seated,
    input  wire [9:0] distance_cm,
    output reg  [7:0] hp,
    output wire       hp_zero_alarm,
    output reg  [1:0] posture_level
);

    localparam [1:0] POSTURE_SAFE   = 2'd0; // 距离 >50cm，坐姿良好
    localparam [1:0] POSTURE_WARN   = 2'd1; // 距离 30~50cm，坐姿偏近
    localparam [1:0] POSTURE_DANGER = 2'd2; // 距离 <30cm，坐姿危险

    reg [5:0] sec_cnt;
    reg       minute_tick;

    // HP 归零时触发报警
    assign hp_zero_alarm = (hp == 8'd0);

    // 组合逻辑：根据距离实时更新坐姿等级
    always @(*) begin
        if (distance_cm > 10'd50)
            posture_level = POSTURE_SAFE;
        else if (distance_cm >= 10'd30)
            posture_level = POSTURE_WARN;
        else
            posture_level = POSTURE_DANGER;
    end

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

    // HP 更新：每分钟且就座时，按坐姿等级增减 HP（含边界保护）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hp <= INIT_HP;
        end else if (minute_tick && seated) begin
            if (distance_cm > 10'd50) begin
                // 坐姿良好：HP +1，上限 100
                if (hp < 8'd100)
                    hp <= hp + 8'd1;
                else
                    hp <= 8'd100;
            end else if (distance_cm >= 10'd30) begin
                // 坐姿偏近：HP -1，下限 0
                if (hp > 8'd0)
                    hp <= hp - 8'd1;
                else
                    hp <= 8'd0;
            end else begin
                // 坐姿危险：HP -3，下限 0
                if (hp > 8'd3)
                    hp <= hp - 8'd3;
                else
                    hp <= 8'd0;
            end
        end
    end

endmodule

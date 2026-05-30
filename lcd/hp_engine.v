`timescale 1ns / 1ps

// 健康值计算引擎。
// 根据头部距离、躯干姿态扣分和入座状态，每分钟更新一次 HP；
// 坐姿好时恢复，坐姿差时扣减，离座空闲时恢复到满值。
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

    // 姿态等级和座椅空闲状态编码。
    // 距离阈值只处理头部前向距离，躯干附加扣分由 torso_hp_penalty 输入。
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

    // 组合计算本分钟 HP 变化量。
    // 安全距离基础 +1，警告距离基础 -1，危险距离基础 -3，
    // 再叠加躯干姿态扣分；同时取绝对值用于后续饱和加减。
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

    // 将头部距离映射为显示用姿态等级：安全、警告、危险。
    always @(*) begin
        if (distance_cm >= HEAD_WARN_CM)
            posture_level = POSTURE_SAFE;
        else if (distance_cm >= HEAD_DANGER_CM)
            posture_level = POSTURE_WARN;
        else
            posture_level = POSTURE_DANGER;
    end

    // 将 1 Hz tick 聚合成分钟 tick。
    // 仿真快速模式下每个 tick 都当作一分钟，便于测试 HP 变化。
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

    // HP 饱和更新。
    // 空闲状态直接恢复 100；入座且到达分钟 tick 时按 hp_delta 加减，
    // 上限钳制到 100，下限钳制到 0。
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

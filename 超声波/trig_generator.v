`timescale 1ns / 1ps

// 超声波测距触发脉冲发生器。
// 该模块按固定周期向 HC-SR04 一类超声波模块的 Trig 引脚输出高电平脉冲，
// 用于启动一次测距；后级模块再根据 Echo 脉宽计算距离。
module trig_generator #(
    parameter integer CLK_FREQ_HZ        = 100_000_000,
    parameter integer PERIOD_US          = 65_000,
    parameter integer PULSE_US           = 25,
    parameter integer START_DELAY_CYCLES = 0
)(
    input clk_100m,
    input RST,
    output reg Trig
);

    localparam [63:0] PERIOD_CYCLES_RAW = (64'd1 * CLK_FREQ_HZ * PERIOD_US) / 1_000_000;
    localparam [63:0] PULSE_CYCLES_RAW  = (64'd1 * CLK_FREQ_HZ * PULSE_US) / 1_000_000;
    localparam [31:0] PERIOD_CYCLES = (PERIOD_CYCLES_RAW < 1) ? 32'd1 : PERIOD_CYCLES_RAW[31:0];
    localparam [31:0] PULSE_CYCLES  = (PULSE_CYCLES_RAW < 1) ? 32'd1 : PULSE_CYCLES_RAW[31:0];

    reg [31:0] cnt_trig;

    // 周期计数与 Trig 输出控制。
    // 复位时清空计数器并拉低 Trig；正常运行时先按测距周期循环计数，
    // 再在每个周期起始阶段输出一段高电平触发脉冲。
    always @ (posedge clk_100m or negedge RST) begin
        if(!RST) begin
            cnt_trig <= 32'd0;
            Trig <= 1'b0;
        end else begin
            if (cnt_trig < PERIOD_CYCLES - 1) begin
                cnt_trig <= cnt_trig + 32'd1;
            end else begin
                cnt_trig <= 32'd0;
            end

            // 多路传感器可通过 START_DELAY_CYCLES 错峰触发，减少声波串扰。
            if ((cnt_trig >= START_DELAY_CYCLES) &&
                (cnt_trig < (START_DELAY_CYCLES + PULSE_CYCLES))) begin
                Trig <= 1'b1;
            end else begin
                Trig <= 1'b0;
            end
        end
    end
endmodule

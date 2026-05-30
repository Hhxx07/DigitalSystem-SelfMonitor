`timescale 1ns / 1ps

// 单路超声波测距顶层封装。
// 将触发脉冲生成、Echo 同步边沿检测、距离换算三个模块串接起来，
// 对外只暴露传感器 Echo/Trig 和厘米距离输出。
module top_Ranging(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        ultrasonic_echo,
    output wire        ultrasonic_trig,

    output wire [15:0] distance_cm
);

    wire echo_sync_out;
    wire echo_pos;
    wire echo_neg;
    wire distance_valid;

    // 周期性产生超声波 Trig 脉冲，启动传感器测距。
    trig_generator u_trig (
        .clk_100m(clk),
        .RST(rst_n),
        .Trig(ultrasonic_trig)
    );

    // 将异步 Echo 输入同步到 clk 时钟域，并提取高电平脉宽的起止边沿。
    signal_sync u_sync_echo (
        .clk_100m(clk),
        .RST(rst_n),
        .async_in(ultrasonic_echo),
        .sync_out(echo_sync_out),
        .pos_edge(echo_pos),
        .neg_edge(echo_neg)
    );

    // 根据 Echo 高电平持续时间计算距离，输出单位为厘米。
    distance_calc u_calc (
        .clk_100m(clk),
        .RST(rst_n),
        .pos_Echo(echo_pos),
        .neg_Echo(echo_neg),
        .data(distance_cm),
        .data_valid(distance_valid)
    );

endmodule

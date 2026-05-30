`timescale 1ns / 1ps

// 超声波测距触发脉冲发生器。
// 该模块按固定周期向 HC-SR04 一类超声波模块的 Trig 引脚输出高电平脉冲，
// 用于启动一次测距；后级模块再根据 Echo 脉宽计算距离。
module trig_generator(
    input clk_100m,
    input RST,
    output reg Trig
);

    reg [23:0] cnt_trig;

    // 周期计数与 Trig 输出控制。
    // 复位时清空计数器并拉低 Trig；正常运行时先按测距周期循环计数，
    // 再在每个周期起始阶段输出一段高电平触发脉冲。
    always @ (posedge clk_100m or negedge RST) begin
        if(!RST) begin
            cnt_trig <= 24'd0;
            Trig <= 1'b0;
        end else begin
            // 20ms 的周期，即 2,000,000 个时钟
            if(cnt_trig < 24'd6_500_000- 1) begin 
                cnt_trig <= cnt_trig + 1'b1;
            end else begin
                cnt_trig <= 24'd0; // 到 20ms 清零重数
            end
            
            // 在周期的最开始产生 20us 的高电平触发脉冲 (100MHz下是 2000个周期)
            if(cnt_trig < 24'd2500) begin
                Trig <= 1'b1; // 前 20us 为高
            end else begin
                Trig <= 1'b0; // 剩下的时间全为低
            end
        end
    end
endmodule

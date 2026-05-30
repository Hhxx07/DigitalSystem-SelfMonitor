`timescale 1ns / 1ps

// 异步输入同步与边沿检测模块。
// 外部传感器信号不一定与 FPGA 时钟同域，先经过两级触发器降低亚稳态风险，
// 再由相邻两拍的差异产生单周期上升沿/下降沿标志。
module signal_sync(
    input clk_100m,
    input RST,
    input async_in,       // 外部物理引脚输入 (比如 Echo, 或者红外、压力)
    output sync_out,      // 同步后的安全信号
    output pos_edge,      // 脉冲上升沿标志 (1个时钟周期的高电平)
    output neg_edge       // 脉冲下降沿标志 (1个时钟周期的高电平)
);

    reg in_1, in_2;       // 两级寄存器

    // 两拍同步链。
    // 第一拍采样外部输入，第二拍输出到系统时钟域，供后续同步逻辑使用。
    always @(posedge clk_100m or negedge RST) begin
        if (!RST) begin
            in_1 <= 1'b0;
            in_2 <= 1'b0;
        end else begin
            in_1 <= async_in; // 第一拍
            in_2 <= in_1;     // 第二拍
        end
    end

    // 同步电平与边沿脉冲生成。
    // sync_out 是稳定后的电平；pos_edge/neg_edge 只在变化发生的那个时钟周期为高。
    assign sync_out = in_2;
    assign pos_edge = (~in_2) && in_1; 
    assign neg_edge = in_2 && (~in_1); 

endmodule

`timescale 1ns / 1ps
module signal_sync(
    input clk_100m,
    input RST,
    input async_in,       // 外部物理引脚输入 (比如 Echo, 或者红外、压力)
    output sync_out,      // 同步后的安全信号
    output pos_edge,      // 脉冲上升沿标志 (1个时钟周期的高电平)
    output neg_edge       // 脉冲下降沿标志 (1个时钟周期的高电平)
);

    reg in_1, in_2;       // 两级寄存器

    always @(posedge clk_100m or negedge RST) begin
        if (!RST) begin
            in_1 <= 1'b0;
            in_2 <= 1'b0;
        end else begin
            in_1 <= async_in; // 第一拍
            in_2 <= in_1;     // 第二拍
        end
    end

    assign sync_out = in_2;
    assign pos_edge = (~in_2) && in_1; 
    assign neg_edge = in_2 && (~in_1); 

endmodule
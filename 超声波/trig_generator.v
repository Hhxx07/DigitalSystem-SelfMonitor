`timescale 1ns / 1ps
module trig_generator(
    input clk_100m,
    input RST,
    output reg Trig
);

    reg [23:0] cnt_trig;

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
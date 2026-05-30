`timescale 1ns / 1ps

// Echo 脉宽到距离的换算模块。
// 输入为已经同步并提取边沿的 Echo 上升沿/下降沿信号；模块在 Echo 高电平期间计数，
// 按 100 MHz 时钟下约 5600 个周期对应 1 cm 的比例输出厘米距离。
module distance_calc(
    input  wire        clk_100m,
    input  wire        RST,
    input  wire        pos_Echo,
    input  wire        neg_Echo,
    output wire [15:0] data,
    output reg         data_valid
);

    // 三段式测量状态：S0 等待 Echo 上升沿，S1 统计 Echo 高电平持续时间，
    // S2 锁存本次距离并给出 data_valid 单周期有效脉冲。
    parameter S0 = 2'b00;
    parameter S1 = 2'b01;
    parameter S2 = 2'b10;

    reg [1:0]  curr_state;
    reg [15:0] cnt;
    reg [15:0] dis_reg;
    reg [15:0] cnt_17k;

    // 主测距状态机。
    // cnt_17k 用来把高速时钟周期换算成厘米刻度，cnt 保存厘米计数；
    // 下降沿到来后进入 S2，将本次计数写入距离寄存器。
    always @(posedge clk_100m or negedge RST) begin
        if (!RST) begin
            cnt_17k <= 16'd0;
            dis_reg <= 16'd0;
            cnt <= 16'd0;
            curr_state <= S0;
            data_valid <= 1'b0;
        end else begin
            data_valid <= 1'b0;
            case (curr_state)
                S0: begin
                    cnt <= 16'd0;
                    cnt_17k <= 16'd0;
                    if (pos_Echo)
                        curr_state <= S1;
                end

                S1: begin
                    if (neg_Echo) begin
                        curr_state <= S2;
                    end else begin
                        // About 5600 cycles at 100 MHz are treated as 1 cm.
                        if (cnt_17k < 16'd5600) begin
                            cnt_17k <= cnt_17k + 16'd1;
                        end else begin
                            cnt_17k <= 16'd0;
                            cnt <= cnt + 16'd1;
                        end
                    end
                end

                S2: begin
                    dis_reg <= cnt;
                    data_valid <= 1'b1;
                    curr_state <= S0;
                end

                default: curr_state <= S0;
            endcase
        end
    end

    // 在锁存状态直接输出最新计数，其余时间保持上一次稳定距离。
    assign data = (curr_state == S2) ? cnt : dis_reg;

endmodule

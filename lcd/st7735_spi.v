`timescale 1ns / 1ps

// ============================================================
// 模块: st7735_spi
// 功能: SPI 主机驱动，将单字节数据以 Mode 0 串行发送给 ST7735 LCD
// 输入: clk, rst_n, start(发送触发), dc(命令/数据选择), data[7:0]
// 输出: busy(发送中), done(发送完成脉冲), lcd_cs_n/dc/scl/mosi(SPI 引脚)
// 参数: CLK_DIV — 时钟分频比，SPI 速率 = clk / (CLK_DIV * 2)
// ============================================================
module st7735_spi #(
    parameter integer CLK_DIV = 5
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire       dc,
    input  wire [7:0] data,
    output reg        busy,
    output reg        done,
    output reg        lcd_cs_n,
    output reg        lcd_dc,
    output reg        lcd_scl,
    output reg        lcd_mosi
);

    // 移位寄存器、位计数器、分频计数器
    reg [7:0] shift_reg;
    reg [2:0] bit_cnt;
    reg [15:0] div_cnt;

    // SPI Mode 0 发送状态机。
    // 空闲时片选拉高；start 后锁存 D/C 和数据并拉低片选；
    // SCL 上升沿供 LCD 采样，下降沿准备下一位，8 位发完后产生 done。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy      <= 1'b0;
            done      <= 1'b0;
            lcd_cs_n  <= 1'b1;
            lcd_dc    <= 1'b0;
            lcd_scl   <= 1'b0;
            lcd_mosi  <= 1'b0;
            shift_reg <= 8'd0;
            bit_cnt   <= 3'd0;
            div_cnt   <= 16'd0;
        end else begin
            done <= 1'b0;

            if (!busy) begin
                // 空闲：CS 拉高，等待 start 脉冲
                lcd_scl  <= 1'b0;
                lcd_cs_n <= 1'b1;
                div_cnt  <= 16'd0;
                if (start) begin
                    // 收到 start：拉低 CS，锁存 dc/data，准备发送 MSB
                    busy      <= 1'b1;
                    lcd_cs_n  <= 1'b0;
                    lcd_dc    <= dc;
                    shift_reg <= data;
                    bit_cnt   <= 3'd7;
                    lcd_mosi  <= data[7];
                end
            end else begin
                // 发送中：按 CLK_DIV 分频翻转 SCL，每个下降沿移出下一位
                if (div_cnt >= (CLK_DIV - 1)) begin
                    div_cnt <= 16'd0;

                    if (lcd_scl == 1'b0) begin
                        lcd_scl <= 1'b1;          // 上升沿：LCD 采样
                    end else begin
                        lcd_scl <= 1'b0;
                        if (bit_cnt == 3'd0) begin
                            // 8 位全部发完，拉高 CS，产生 done 脉冲
                            busy     <= 1'b0;
                            done     <= 1'b1;
                            lcd_cs_n <= 1'b1;
                        end else begin
                            // 下降沿：更新 MOSI 为下一位
                            bit_cnt  <= bit_cnt - 3'd1;
                            lcd_mosi <= shift_reg[bit_cnt - 3'd1];
                        end
                    end
                end else begin
                    div_cnt <= div_cnt + 16'd1;
                end
            end
        end
    end

endmodule

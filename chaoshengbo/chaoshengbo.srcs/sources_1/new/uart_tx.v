`timescale 1ns / 1ps

module uart_tx(
    input clk_100m,       // 100MHz系统时钟
    input RST,            // 复位信号(低电平有效)
    input [7:0] tx_data,  // 要发送的8位字符数据
    input tx_en,          // 发送使能信号(给高电平脉冲开始发送)
    output reg tx_pin,    // 物理TX引脚
    output reg tx_done    // 单个字节发送完成标志 (单周期脉冲)
);

    parameter BAUD_CNT_MAX = 14'd10416; // 9600波特率分频
    
    reg [13:0] baud_cnt;
    reg [3:0]  bit_cnt;
    reg [7:0]  tx_data_reg;
    reg tx_flag;

    // 标志位与数据锁存
    always @(posedge clk_100m or negedge RST) begin
        if (!RST) begin
            tx_flag <= 1'b0;
            tx_data_reg <= 8'd0;
        // 增加 !tx_flag 条件，防止发送过程中被新的使能信号干扰打断
        end else if (tx_en && !tx_flag) begin 
            tx_flag <= 1'b1;
            tx_data_reg <= tx_data;
        end else if (tx_done) begin
            tx_flag <= 1'b0;
        end
    end

    // 波特率计数与发送控制
    always @(posedge clk_100m or negedge RST) begin
        if (!RST) begin
            baud_cnt <= 14'd0;
            bit_cnt <= 4'd0;
            tx_pin <= 1'b1;
            tx_done <= 1'b0;
        end else begin
            tx_done <= 1'b0; // 默认拉低，确保 tx_done 只是一个时钟周期的脉冲
            
            if (tx_flag) begin
                // 1. 数据位状态判断与输出
                case (bit_cnt)
                    4'd0: tx_pin <= 1'b0;              // 【起始位】一进 tx_flag 立刻拉低
                    4'd1: tx_pin <= tx_data_reg[0];    // 【8个数据位】
                    4'd2: tx_pin <= tx_data_reg[1];
                    4'd3: tx_pin <= tx_data_reg[2];
                    4'd4: tx_pin <= tx_data_reg[3];
                    4'd5: tx_pin <= tx_data_reg[4];
                    4'd6: tx_pin <= tx_data_reg[5];
                    4'd7: tx_pin <= tx_data_reg[6];
                    4'd8: tx_pin <= tx_data_reg[7];
                    4'd9: tx_pin <= 1'b1;              // 【停止位】
                    default: tx_pin <= 1'b1;
                endcase
                
                // 2. 波特率分频计数
                if (baud_cnt < BAUD_CNT_MAX - 1) begin
                    baud_cnt <= baud_cnt + 1'b1;
                end else begin
                    baud_cnt <= 14'd0;
                    // 3. 位计数切换
                    if (bit_cnt == 4'd9) begin  // 如果停止位发送完了
                        bit_cnt <= 4'd0;
                        tx_done <= 1'b1;        // 拉高完成标志（仅维持1个周期）
                    end else begin
                        bit_cnt <= bit_cnt + 1'b1;
                    end
                end
                
            end else begin
                // 空闲状态保持
                baud_cnt <= 14'd0;
                bit_cnt <= 4'd0;
                tx_pin <= 1'b1; 
            end
        end
    end
endmodule
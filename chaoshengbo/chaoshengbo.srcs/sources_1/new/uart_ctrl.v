`timescale 1ns / 1ps

module uart_ctrl(
    input clk_100m,
    input RST,
    input [15:0] distance_data, // 输入纯二进制距离数据 (单位: cm)
    input tx_done,              // 接收tx的完成反馈
    output reg [7:0] tx_data,   // 交给tx的数据
    output reg tx_en            // 命令tx发送
);

    // 每 0.5 秒触发一次发送 (防止电脑屏幕刷字太快看不清)
    reg [25:0] delay_cnt;
    reg send_start;
    always @(posedge clk_100m or negedge RST) begin
        if(!RST) begin
            delay_cnt <= 26'd0;
            send_start <= 1'b0;
        end else if(delay_cnt == 26'd50_000_000) begin
            delay_cnt <= 26'd0;
            send_start <= 1'b1;
        end else begin
            delay_cnt <= delay_cnt + 1'b1;
            send_start <= 1'b0;
        end
    end

    // 用于锁存二进制转换后的各个十进制位 (BCD)
    reg [3:0] bcd_thou;
    reg [3:0] bcd_hund;
    reg [3:0] bcd_tens;
    reg [3:0] bcd_ones;

    // 状态机：按顺序发送 千,百,十,个, 'c', 'm', 回车, 换行
    reg [4:0] state;
    always @(posedge clk_100m or negedge RST) begin
        if (!RST) begin
            state <= 5'd0;
            tx_en <= 1'b0;
            tx_data <= 8'd0;
            bcd_thou <= 4'd0;
            bcd_hund <= 4'd0;
            bcd_tens <= 4'd0;
            bcd_ones <= 4'd0;
        end else begin
            case(state)
                5'd0: begin
                    tx_en <= 1'b0;
                    if(send_start) begin
                        // 在发送开启时，将二进制距离解算为十进制数字并锁存
                        // 综合工具会自动将常数除法/取模优化为乘法+移位网络
                        bcd_thou <= (distance_data / 1000) % 10;
                        bcd_hund <= (distance_data / 100)  % 10;
                        bcd_tens <= (distance_data / 10)   % 10;
                        bcd_ones <= distance_data % 10;
                        state <= 5'd1;
                    end
                end
                
                // 发送数字 (计算出的各位数字 + 8'h30 转成 ASCII)
                5'd1: begin tx_data <= {4'd0, bcd_thou} + 8'h30; tx_en <= 1'b1; state <= 5'd2; end
                5'd2: begin tx_en <= 1'b0; if(tx_done) state <= 5'd3; end
                
                5'd3: begin tx_data <= {4'd0, bcd_hund} + 8'h30; tx_en <= 1'b1; state <= 5'd4; end
                5'd4: begin tx_en <= 1'b0; if(tx_done) state <= 5'd5; end
                
                5'd5: begin tx_data <= {4'd0, bcd_tens} + 8'h30; tx_en <= 1'b1; state <= 5'd6; end
                5'd6: begin tx_en <= 1'b0; if(tx_done) state <= 5'd7; end
                
                5'd7: begin tx_data <= {4'd0, bcd_ones} + 8'h30; tx_en <= 1'b1; state <= 5'd8; end
                5'd8: begin tx_en <= 1'b0; if(tx_done) state <= 5'd9; end
                
                // 发送字母 'c' (ASCII: 0x63)
                5'd9: begin tx_data <= 8'h63; tx_en <= 1'b1; state <= 5'd10; end
                5'd10: begin tx_en <= 1'b0; if(tx_done) state <= 5'd11; end
                
                // 发送字母 'm' (ASCII: 0x6D)
                5'd11: begin tx_data <= 8'h6D; tx_en <= 1'b1; state <= 5'd12; end
                5'd12: begin tx_en <= 1'b0; if(tx_done) state <= 5'd13; end
                
                // 发送回车 '\r' (ASCII: 0x0D)
                5'd13: begin tx_data <= 8'h0D; tx_en <= 1'b1; state <= 5'd14; end
                5'd14: begin tx_en <= 1'b0; if(tx_done) state <= 5'd15; end
                
                // 发送换行 '\n' (ASCII: 0x0A)
                5'd15: begin tx_data <= 8'h0A; tx_en <= 1'b1; state <= 5'd16; end
                5'd16: begin tx_en <= 1'b0; if(tx_done) state <= 5'd0; end
                
                default: state <= 5'd0;
            endcase
        end
    end
endmodule
`timescale 1ns / 1ps
module display(
    input  clk_100m,       // 【输入】100MHz 时钟
    input  RST,            // 【输入】复位信号
    input  [15:0] data,    // 【输入】从测量模块传来的距离数据
    output reg [6:0] seg_duan, // 【输出】段选信号（高电平亮）
    output reg [2:0] seg_sel   // 【输出】位选信号（高电平选通）
);

// ---------------------------------------------------------
// 1. 时钟分频逻辑 (100MHz -> 约 5MHz 驱动时钟)
// ---------------------------------------------------------
reg [3:0] clk_cnt; // 分频计数器
reg dri_clk;       // 数码管驱动时钟

always @ (posedge clk_100m or negedge RST) begin
    if(!RST) begin
        clk_cnt <= 4'd0;
        dri_clk <= 1'b1;
    end else if(clk_cnt == 4'd9) begin // 100MHz 每数10次翻转一次，产生 5MHz
        clk_cnt <= 4'd0;
        dri_clk <= ~dri_clk;
    end else begin
        clk_cnt <= clk_cnt + 1'b1;
    end
end

// ---------------------------------------------------------
// 2. 数据缓冲与 1ms 扫描标志生成
// ---------------------------------------------------------
reg [15:0] num;   // 数据缓冲器
always @ (posedge dri_clk or negedge RST) begin
    if (!RST) num <= 16'd0;
    else num <= data; // 将外部传来的距离数据存入内部
end

reg [12:0] cnt0;  // 1ms 计数器
reg flag;         // 1ms 标志位

always @ (posedge dri_clk or negedge RST) begin
    if (!RST) begin
        cnt0 <= 13'b0; flag <= 1'b0;
    end else if (cnt0 < 13'd4999) begin // 5MHz 下数 5000 次就是 1ms
        cnt0 <= cnt0 + 1'b1; flag <= 1'b0;
    end else begin
        cnt0 <= 13'b0; flag <= 1'b1; // 到了 1ms，产生一个脉冲
    end
end

// ---------------------------------------------------------
// 3. 数码管动态扫描 (位选) -> 改为高电平有效
// ---------------------------------------------------------
reg [2:0] cnt_sel; // 记录当前扫描到哪一位数码管
always @ (posedge dri_clk or negedge RST) begin
    if (!RST) cnt_sel <= 3'b0;
    else if(flag) begin // 每 1ms 切换一次数码管
        if(cnt_sel < 3'd2) // 只有3位有效显示 (个、十、百)
            cnt_sel <= cnt_sel + 1'b1;
        else
            cnt_sel <= 3'b0;
    end
end

reg [3:0] seg_data; // 准备发送给译码器的当前位数据
always@(posedge dri_clk or negedge RST) begin
    if(!RST) begin
        seg_sel <= 3'b000; // 复位时全灭 (高电平有效，0全灭)
        seg_data <= 4'd0;
    end else begin
        case(cnt_sel)
            3'd0: begin seg_sel <= 3'b001; seg_data <= num[3:0];  end // 选通第1位(个)，高电平有效
            3'd1: begin seg_sel <= 3'b010; seg_data <= num[7:4];  end // 选通第2位(十)
            3'd2: begin seg_sel <= 3'b100; seg_data <= num[11:8]; end // 选通第3位(百)
            default: begin seg_sel <= 3'b000; seg_data <= 4'd0; end
        endcase
    end
end

// ---------------------------------------------------------
// 4. 七段译码器 (段选) -> 共阴极，高电平有效
// ---------------------------------------------------------
always@(*) begin
    case(seg_data) // (0亮，1灭 -> 变成 1亮，0灭)
        4'd0: seg_duan = 7'b0111111; 
        4'd1: seg_duan = 7'b0000110; 
        4'd2: seg_duan = 7'b1011011; 
        4'd3: seg_duan = 7'b1001111; 
        4'd4: seg_duan = 7'b1100110; 
        4'd5: seg_duan = 7'b1101101; 
        4'd6: seg_duan = 7'b1111101; 
        4'd7: seg_duan = 7'b0000111; 
        4'd8: seg_duan = 7'b1111111; 
        4'd9: seg_duan = 7'b1101111; 
        default: seg_duan = 7'b0000000; // 默认全灭
    endcase 
end
endmodule
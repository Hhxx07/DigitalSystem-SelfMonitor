`timescale 1ns / 1ps
module distance_calc(
    input clk_100m,
    input RST,
    input pos_Echo,       
    input neg_Echo,       
    output [15:0] data    
);
//这个模块输入时钟信号，和echo的高低电平决定的控制信号。计算距离。
    parameter S0 = 2'b00, S1 = 2'b01, S2 = 2'b10;
    reg [1:0] curr_state;
    reg [15:0] cnt;       // 用于存储二进制距离值 (单位: cm)
    reg [15:0] dis_reg;
    reg [15:0] cnt_17k;   // 分频计数器

    always @ (posedge clk_100m or negedge RST) begin
        if(!RST) begin
            cnt_17k <= 16'd0; 
            dis_reg <= 16'd0;
            cnt <= 16'd0;
            curr_state <= S0;
        end else begin
            case(curr_state)
                S0: begin
                    cnt <= 16'd0;
                    cnt_17k <= 16'd0; // 复位分频器，保证测量从0开始
                    if (pos_Echo) curr_state <= S1;
                end
                
                S1: begin
                    if(neg_Echo) begin
                        curr_state <= S2;
                    end else begin
                        // 100MHz 下，5882 个周期约等于 1cm (声速 340m/s)[由于实际测量时候偏短，所以减少周期数来尝试]
                        if(cnt_17k < 16'd5600) begin
                            cnt_17k <= cnt_17k + 1'b1;
                        end else begin
                            cnt_17k <= 16'd0;
                            // 进行二进制累加
                            cnt <= cnt + 1'b1; 
                        end
                    end             
                end
                
                S2: begin
                    dis_reg <= cnt; // 保存二进制结果
                    curr_state <= S0;
                end
                default: curr_state <= S0;
            endcase 
        end
    end

    assign data = dis_reg;

endmodule
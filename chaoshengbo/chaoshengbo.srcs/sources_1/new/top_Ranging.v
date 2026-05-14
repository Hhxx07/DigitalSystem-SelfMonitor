`timescale 1ns / 1ps
module top_Ranging(
    input  clk_100m,
    input  RST,
    
    input  wire Echo,
    output Trig,
    output wire UART_TX
);

// --- 内部导线连线 ---
wire [15:0] distance_data;
wire echo_sync_out, echo_pos, echo_neg;

// 翻转复位信号 (开关拨上去是1系统休眠，拨下来是0系统工作)
wire rst_n;
assign rst_n = RST; 


// 1. 实例化：生成触发脉冲
trig_generator u_trig (
    .clk_100m (clk_100m),
    .RST      (rst_n),   
    .Trig     (Trig)  // 
);



// 2. 实例化：Echo信号同步与边沿检测
signal_sync u_sync_echo (
    .clk_100m (clk_100m),
    .RST      (rst_n),   
    .async_in (Echo), // 【修改2 致命点修正】不要听 Echo引脚的，去听那根内部专线！
    .sync_out (echo_sync_out), 
    .pos_edge (echo_pos),    
    .neg_edge (echo_neg)     
);

// 3. 实例化：距离计算状态机 (确保这里没有被注释掉！)
distance_calc u_calc (
    .clk_100m (clk_100m),
    .RST      (rst_n),   
    .pos_Echo (echo_pos),    
    .neg_Echo (echo_neg),    
    .data     (distance_data)
);

// --- 串口相关的内部连线 ---
wire [7:0] tx_data_bus;
wire tx_en_wire;
wire tx_done_wire;

// 4. 实例化控制模块
uart_ctrl u_uart_ctrl(
    .clk_100m(clk_100m), 
    .RST(rst_n),         
    .distance_data(distance_data), 
    .tx_done(tx_done_wire), 
    .tx_data(tx_data_bus), 
    .tx_en(tx_en_wire)
);

// 5. 实例化发送模块
uart_tx u_uart_tx(
    .clk_100m(clk_100m), 
    .RST(rst_n),         
    .tx_data(tx_data_bus), 
    .tx_en(tx_en_wire),
    .tx_pin(UART_TX), 
    .tx_done(tx_done_wire)
);

endmodule
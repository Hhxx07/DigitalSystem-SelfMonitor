`timescale 1ns / 1ps

// ST7735 LCD 初始化控制器。
// 上电后先控制 LCD 复位脚，再按顺序通过 SPI 发送软件复位、退出睡眠、
// 像素格式、扫描方向、显示窗口和开显示等命令。
module st7735_init #(
    parameter integer CLK_HZ = 100000000,
    parameter [7:0]   MADCTL_PARAM = 8'h00,
    parameter [15:0]  LCD_X_OFFSET = 16'd2,
    parameter [15:0]  LCD_Y_OFFSET = 16'd1
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       spi_busy,
    input  wire       spi_done,
    output reg        spi_start,
    output reg        spi_dc,
    output reg [7:0]  spi_data,
    output reg        lcd_rst_n,
    output reg        init_done
);

    // 初始化状态机：硬复位低/高电平延时、发送命令、等待 SPI 完成、命令后延时、完成。
    localparam [2:0] S_RESET_LOW  = 3'd0;
    localparam [2:0] S_RESET_HIGH = 3'd1;
    localparam [2:0] S_SEND       = 3'd2;
    localparam [2:0] S_WAIT       = 3'd3;
    localparam [2:0] S_DELAY      = 3'd4;
    localparam [2:0] S_DONE       = 3'd5;

    localparam [4:0] LAST_INDEX = 5'd17;
    localparam [15:0] COL_START = LCD_X_OFFSET;
    localparam [15:0] COL_END   = LCD_X_OFFSET + 16'd127;
    localparam [15:0] ROW_START = LCD_Y_OFFSET;
    localparam [15:0] ROW_END   = LCD_Y_OFFSET + 16'd127;

    reg [2:0]  state;
    reg [4:0]  seq_idx;
    reg [31:0] delay_cnt;
    reg [31:0] delay_target;

    // 毫秒延时转换为时钟周期数，保证低频仿真参数下也至少等待一个周期。
    function integer ms_to_cycles;
        input integer ms;
        integer tmp;
        begin
            tmp = (CLK_HZ / 1000) * ms;
            if (tmp < 1)
                ms_to_cycles = 1;
            else
                ms_to_cycles = tmp;
        end
    endfunction

    // 初始化命令/参数序列。
    // 序列中既包含命令字，也包含紧跟命令的数据参数。
    function [7:0] seq_data;
        input [4:0] idx;
        begin
            case (idx)
                5'd0:  seq_data = 8'h01; // SWRESET
                5'd1:  seq_data = 8'h11; // SLPOUT
                5'd2:  seq_data = 8'h3A; // COLMOD
                5'd3:  seq_data = 8'h05; // RGB565
                5'd4:  seq_data = 8'h36; // MADCTL
                5'd5:  seq_data = MADCTL_PARAM;
                5'd6:  seq_data = 8'h2A; // CASET
                5'd7:  seq_data = COL_START[15:8];
                5'd8:  seq_data = COL_START[7:0];
                5'd9:  seq_data = COL_END[15:8];
                5'd10: seq_data = COL_END[7:0];
                5'd11: seq_data = 8'h2B; // RASET
                5'd12: seq_data = ROW_START[15:8];
                5'd13: seq_data = ROW_START[7:0];
                5'd14: seq_data = ROW_END[15:8];
                5'd15: seq_data = ROW_END[7:0];
                5'd16: seq_data = 8'h13; // NORON
                5'd17: seq_data = 8'h29; // DISPON
                default: seq_data = 8'h00;
            endcase
        end
    endfunction

    // 当前序列项的 D/C 标志。
    // 复位、睡眠退出、颜色格式、地址窗口和显示开关为命令，其余为参数。
    function seq_dc;
        input [4:0] idx;
        begin
            case (idx)
                5'd0, 5'd1, 5'd2, 5'd4, 5'd6, 5'd11, 5'd16, 5'd17:
                    seq_dc = 1'b0;
                default:
                    seq_dc = 1'b1;
            endcase
        end
    endfunction

    // 某些 ST7735 命令要求发送后等待一段时间，这里给出对应延时。
    function [31:0] delay_after;
        input [4:0] idx;
        begin
            case (idx)
                5'd0:  delay_after = ms_to_cycles(150);
                5'd1:  delay_after = ms_to_cycles(120);
                5'd17: delay_after = ms_to_cycles(20);
                default: delay_after = 32'd0;
            endcase
        end
    endfunction

    // 初始化主状态机。
    // 通过 spi_start/spi_data/spi_dc 驱动共用 SPI 发送器，所有序列完成后拉高 init_done。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_RESET_LOW;
            seq_idx      <= 5'd0;
            delay_cnt    <= 32'd0;
            delay_target <= ms_to_cycles(20);
            spi_start    <= 1'b0;
            spi_dc       <= 1'b0;
            spi_data     <= 8'd0;
            lcd_rst_n    <= 1'b0;
            init_done    <= 1'b0;
        end else begin
            spi_start <= 1'b0;

            case (state)
                S_RESET_LOW: begin
                    lcd_rst_n <= 1'b0;
                    if (delay_cnt >= delay_target) begin
                        delay_cnt    <= 32'd0;
                        delay_target <= ms_to_cycles(120);
                        state        <= S_RESET_HIGH;
                    end else begin
                        delay_cnt <= delay_cnt + 32'd1;
                    end
                end

                S_RESET_HIGH: begin
                    lcd_rst_n <= 1'b1;
                    if (delay_cnt >= delay_target) begin
                        delay_cnt <= 32'd0;
                        seq_idx   <= 5'd0;
                        state     <= S_SEND;
                    end else begin
                        delay_cnt <= delay_cnt + 32'd1;
                    end
                end

                S_SEND: begin
                    if (!spi_busy) begin
                        spi_data  <= seq_data(seq_idx);
                        spi_dc    <= seq_dc(seq_idx);
                        spi_start <= 1'b1;
                        state     <= S_WAIT;
                    end
                end

                S_WAIT: begin
                    if (spi_done) begin
                        if (delay_after(seq_idx) != 32'd0) begin
                            delay_cnt    <= 32'd0;
                            delay_target <= delay_after(seq_idx);
                            state        <= S_DELAY;
                        end else if (seq_idx == LAST_INDEX) begin
                            state <= S_DONE;
                        end else begin
                            seq_idx <= seq_idx + 5'd1;
                            state   <= S_SEND;
                        end
                    end
                end

                S_DELAY: begin
                    if (delay_cnt >= delay_target) begin
                        delay_cnt <= 32'd0;
                        if (seq_idx == LAST_INDEX) begin
                            state <= S_DONE;
                        end else begin
                            seq_idx <= seq_idx + 5'd1;
                            state   <= S_SEND;
                        end
                    end else begin
                        delay_cnt <= delay_cnt + 32'd1;
                    end
                end

                S_DONE: begin
                    init_done <= 1'b1;
                    state     <= S_DONE;
                end

                default: state <= S_RESET_LOW;
            endcase
        end
    end

endmodule

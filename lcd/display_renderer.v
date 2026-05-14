`timescale 1ns / 1ps

// ============================================================
// 模块: display_renderer
// 功能: LCD 帧渲染器，按 FRAME_HZ 帧率将健康数据绘制到 128x128 屏幕
//       先发送 CASET/RASET/RAMWR 定位命令，再逐像素输出 RGB565 数据
// 输入: clk, rst_n, init_done, spi_busy/done
//       year/month/day/hour/minute/second — 时间
//       seat_state[2:0], sit_time_min, away_time_min — 就座状态
//       hp[7:0], hp_zero_alarm — 健康值
// 输出: spi_start, spi_dc, spi_data[7:0] — 驱动 SPI 层
// 参数: CLK_HZ — 系统时钟; FRAME_HZ — 刷新帧率
// ============================================================
module display_renderer #(
    parameter integer CLK_HZ   = 100000000,
    parameter integer FRAME_HZ = 2
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        init_done,
    input  wire        spi_busy,
    input  wire        spi_done,
    input  wire [15:0] year,
    input  wire [7:0]  month,
    input  wire [7:0]  day,
    input  wire [7:0]  hour,
    input  wire [7:0]  minute,
    input  wire [7:0]  second,
    input  wire [2:0]  seat_state,
    input  wire [15:0] sit_time_min,
    input  wire [15:0] away_time_min,
    input  wire [7:0]  hp,
    input  wire        hp_zero_alarm,
    output reg         spi_start,
    output reg         spi_dc,
    output reg  [7:0]  spi_data
);

    // 渲染状态机
    localparam [2:0] R_IDLE     = 3'd0; // 等待帧周期到来
    localparam [2:0] R_SEQ_SEND = 3'd1; // 发送定位命令序列
    localparam [2:0] R_SEQ_WAIT = 3'd2; // 等待命令 SPI 完成
    localparam [2:0] R_PIX_SEND = 3'd3; // 发送像素高/低字节
    localparam [2:0] R_PIX_WAIT = 3'd4; // 等待像素 SPI 完成

    // RGB565 颜色常量
    localparam [15:0] C_BLACK    = 16'h0000;
    localparam [15:0] C_WHITE    = 16'hFFFF;
    localparam [15:0] C_RED      = 16'hF800;
    localparam [15:0] C_GREEN    = 16'h07E0;
    localparam [15:0] C_YELLOW   = 16'hFFE0;
    localparam [15:0] C_GRAY     = 16'h4208;
    localparam [15:0] C_DARK_RED = 16'h6000;

    localparam [31:0] FRAME_PERIOD = (CLK_HZ / FRAME_HZ);

    reg [2:0]  state;
    reg [3:0]  seq_idx;    // 定位命令序列索引（0~10）
    reg [6:0]  pix_x;      // 当前像素列（0~127）
    reg [6:0]  pix_y;      // 当前像素行（0~127）
    reg        byte_phase; // 0=高字节, 1=低字节
    reg [31:0] frame_cnt;
    reg [15:0] pixel_rgb;

    // 将像素坐标映射到字符网格（每格 8x8 像素）
    wire [3:0] cell_col = pix_x[6:3];
    wire [3:0] cell_row = pix_y[6:3];
    wire [2:0] font_row = pix_y[2:0];
    wire [2:0] font_col = pix_x[2:0];
    wire [7:0] char_code;
    wire [7:0] font_bits;
    wire       text_on;    // 当前像素是否为文字前景
    wire       status_area; // 是否在状态行区域（y=30~47，用于闪烁）
    wire       blink_on;
    wire [15:0] hp_bar_width; // HP 进度条宽度（像素）

    // 时间各位拆分（BCD 分解）
    wire [3:0] year_th = (year / 16'd1000) % 16'd10;
    wire [3:0] year_h  = (year / 16'd100)  % 16'd10;
    wire [3:0] year_t  = (year / 16'd10)   % 16'd10;
    wire [3:0] year_o  = year % 16'd10;
    wire [3:0] mon_t   = month / 8'd10;
    wire [3:0] mon_o   = month % 8'd10;
    wire [3:0] day_t   = day / 8'd10;
    wire [3:0] day_o   = day % 8'd10;
    wire [3:0] hour_t  = hour / 8'd10;
    wire [3:0] hour_o  = hour % 8'd10;
    wire [3:0] min_t   = minute / 8'd10;
    wire [3:0] min_o   = minute % 8'd10;
    wire [3:0] sec_t   = second / 8'd10;
    wire [3:0] sec_o   = second % 8'd10;

    // 就座时间和离座时间各位拆分
    wire [3:0] sit_th  = (sit_time_min / 16'd1000) % 16'd10;
    wire [3:0] sit_h   = (sit_time_min / 16'd100)  % 16'd10;
    wire [3:0] sit_t   = (sit_time_min / 16'd10)   % 16'd10;
    wire [3:0] sit_o   = sit_time_min % 16'd10;
    wire [3:0] away_th = (away_time_min / 16'd1000) % 16'd10;
    wire [3:0] away_h  = (away_time_min / 16'd100)  % 16'd10;
    wire [3:0] away_t  = (away_time_min / 16'd10)   % 16'd10;
    wire [3:0] away_o  = away_time_min % 16'd10;
    wire [3:0] hp_h    = hp / 8'd100;
    wire [3:0] hp_t    = (hp / 8'd10) % 8'd10;
    wire [3:0] hp_o    = hp % 8'd10;

    // 状态行区域（行 3~5，y=24~47）用于报警闪烁
    assign status_area  = (pix_y >= 7'd30) && (pix_y < 7'd48);
    // HP 归零或严重久坐时，以秒为周期闪烁
    assign blink_on     = (hp_zero_alarm || (seat_state == 3'd3)) && second[0];
    // HP 进度条宽度：110 像素对应 100%
    assign hp_bar_width = (hp * 16'd110) / 16'd100;
    // 字体位图中当前列是否点亮
    assign text_on      = font_bits[3'd7 - font_col];

    // 实例化字体 ROM
    font_rom u_font_rom (
        .ascii(char_code),
        .row(font_row),
        .bits(font_bits)
    );

    // 根据字符网格坐标查询当前像素对应的 ASCII 码
    assign char_code = char_at(cell_col, cell_row);

    // 数字转 ASCII
    function [7:0] ascii_digit;
        input [3:0] digit;
        begin
            ascii_digit = 8'h30 + {4'd0, digit};
        end
    endfunction

    // 根据状态编码和位置返回状态字符串中的字符
    function [7:0] state_char;
        input [2:0] st;
        input [3:0] pos;
        begin
            state_char = 8'h20;
            case (st)
                3'd0: begin // IDLE
                    case (pos) 4'd0: state_char = "I"; 4'd1: state_char = "D"; 4'd2: state_char = "L"; 4'd3: state_char = "E"; default: state_char = " "; endcase
                end
                3'd1: begin // STUDY
                    case (pos) 4'd0: state_char = "S"; 4'd1: state_char = "T"; 4'd2: state_char = "U"; 4'd3: state_char = "D"; 4'd4: state_char = "Y"; default: state_char = " "; endcase
                end
                3'd2: begin // LONG
                    case (pos) 4'd0: state_char = "L"; 4'd1: state_char = "O"; 4'd2: state_char = "N"; 4'd3: state_char = "G"; default: state_char = " "; endcase
                end
                3'd3: begin // OVER
                    case (pos) 4'd0: state_char = "O"; 4'd1: state_char = "V"; 4'd2: state_char = "E"; 4'd3: state_char = "R"; default: state_char = " "; endcase
                end
                3'd4: begin // REST
                    case (pos) 4'd0: state_char = "R"; 4'd1: state_char = "E"; 4'd2: state_char = "S"; 4'd3: state_char = "T"; default: state_char = " "; endcase
                end
                3'd5: begin // AWAY
                    case (pos) 4'd0: state_char = "A"; 4'd1: state_char = "W"; 4'd2: state_char = "A"; 4'd3: state_char = "Y"; default: state_char = " "; endcase
                end
                default: state_char = " ";
            endcase
        end
    endfunction

    // 屏幕字符布局（每行 16 列，每列 8 像素）：
    //   行 0: YYYY-MM-DD
    //   行 2: HH:MM:SS
    //   行 4: STAT <state>
    //   行 6: SIT  xxxxM
    //   行 8: AWAY xxxxM
    //   行 10: HP  xxx
    //   行 12~15: HP 进度条（像素绘制）
    function [7:0] char_at;
        input [3:0] col;
        input [3:0] row;
        begin
            char_at = 8'h20;
            case (row)
                4'd0: begin
                    case (col)
                        4'd0: char_at = ascii_digit(year_th);
                        4'd1: char_at = ascii_digit(year_h);
                        4'd2: char_at = ascii_digit(year_t);
                        4'd3: char_at = ascii_digit(year_o);
                        4'd4: char_at = "-";
                        4'd5: char_at = ascii_digit(mon_t);
                        4'd6: char_at = ascii_digit(mon_o);
                        4'd7: char_at = "-";
                        4'd8: char_at = ascii_digit(day_t);
                        4'd9: char_at = ascii_digit(day_o);
                        default: char_at = " ";
                    endcase
                end
                4'd2: begin
                    case (col)
                        4'd0: char_at = ascii_digit(hour_t);
                        4'd1: char_at = ascii_digit(hour_o);
                        4'd2: char_at = ":";
                        4'd3: char_at = ascii_digit(min_t);
                        4'd4: char_at = ascii_digit(min_o);
                        4'd5: char_at = ":";
                        4'd6: char_at = ascii_digit(sec_t);
                        4'd7: char_at = ascii_digit(sec_o);
                        default: char_at = " ";
                    endcase
                end
                4'd4: begin
                    case (col)
                        4'd0: char_at = "S";
                        4'd1: char_at = "T";
                        4'd2: char_at = "A";
                        4'd3: char_at = "T";
                        4'd4: char_at = " ";
                        default: char_at = state_char(seat_state, col - 4'd5);
                    endcase
                end
                4'd6: begin
                    case (col)
                        4'd0: char_at = "S";
                        4'd1: char_at = "I";
                        4'd2: char_at = "T";
                        4'd3: char_at = " ";
                        4'd4: char_at = ascii_digit(sit_th);
                        4'd5: char_at = ascii_digit(sit_h);
                        4'd6: char_at = ascii_digit(sit_t);
                        4'd7: char_at = ascii_digit(sit_o);
                        4'd8: char_at = "M";
                        default: char_at = " ";
                    endcase
                end
                4'd8: begin
                    case (col)
                        4'd0: char_at = "A";
                        4'd1: char_at = "W";
                        4'd2: char_at = "A";
                        4'd3: char_at = "Y";
                        4'd4: char_at = " ";
                        4'd5: char_at = ascii_digit(away_th);
                        4'd6: char_at = ascii_digit(away_h);
                        4'd7: char_at = ascii_digit(away_t);
                        4'd8: char_at = ascii_digit(away_o);
                        4'd9: char_at = "M";
                        default: char_at = " ";
                    endcase
                end
                4'd10: begin
                    case (col)
                        4'd0: char_at = "H";
                        4'd1: char_at = "P";
                        4'd2: char_at = " ";
                        4'd3: char_at = ascii_digit(hp_h);
                        4'd4: char_at = ascii_digit(hp_t);
                        4'd5: char_at = ascii_digit(hp_o);
                        default: char_at = " ";
                    endcase
                end
                default: char_at = " ";
            endcase
        end
    endfunction

    // 定位命令序列：CASET(0x00~0x7F) + RASET(0x00~0x7F) + RAMWR
    function [7:0] seq_data;
        input [3:0] idx;
        begin
            case (idx)
                4'd0:  seq_data = 8'h2A; // CASET 命令
                4'd1:  seq_data = 8'h00;
                4'd2:  seq_data = 8'h00;
                4'd3:  seq_data = 8'h00;
                4'd4:  seq_data = 8'h7F;
                4'd5:  seq_data = 8'h2B; // RASET 命令
                4'd6:  seq_data = 8'h00;
                4'd7:  seq_data = 8'h00;
                4'd8:  seq_data = 8'h00;
                4'd9:  seq_data = 8'h7F;
                4'd10: seq_data = 8'h2C; // RAMWR 命令，之后连续写像素
                default: seq_data = 8'h00;
            endcase
        end
    endfunction

    // 定位序列中 DC 信号：命令字节为 0，参数字节为 1
    function seq_dc;
        input [3:0] idx;
        begin
            case (idx)
                4'd0, 4'd5, 4'd10: seq_dc = 1'b0;
                default: seq_dc = 1'b1;
            endcase
        end
    endfunction

    // 像素颜色计算（组合逻辑）：
    //   y=96~107 区域绘制 HP 进度条（带边框）
    //   其余区域根据字体位图和闪烁状态决定颜色
    always @(*) begin
        pixel_rgb = C_BLACK;

        if ((pix_x >= 7'd8) && (pix_x < 7'd120) && (pix_y >= 7'd96) && (pix_y < 7'd108)) begin
            // HP 进度条区域
            if ((pix_x == 7'd8) || (pix_x == 7'd119) || (pix_y == 7'd96) || (pix_y == 7'd107)) begin
                pixel_rgb = C_WHITE; // 边框
            end else if ((pix_x - 7'd9) < hp_bar_width[6:0]) begin
                // 填充部分：按 HP 值变色
                if (hp >= 8'd70)
                    pixel_rgb = C_GREEN;
                else if (hp >= 8'd30)
                    pixel_rgb = C_YELLOW;
                else
                    pixel_rgb = C_RED;
            end else begin
                pixel_rgb = C_GRAY; // 未填充部分
            end
        end else if (text_on) begin
            // 文字像素：状态行报警时闪烁黄色，否则白色
            if (status_area && blink_on)
                pixel_rgb = C_YELLOW;
            else
                pixel_rgb = C_WHITE;
        end else if (status_area && blink_on) begin
            // 状态行背景报警闪烁：深红色
            pixel_rgb = C_DARK_RED;
        end else begin
            pixel_rgb = C_BLACK;
        end
    end

    // 主状态机：帧计时 -> 发送定位序列 -> 逐像素发送 RGB565（高字节+低字节）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= R_IDLE;
            seq_idx    <= 4'd0;
            pix_x      <= 7'd0;
            pix_y      <= 7'd0;
            byte_phase <= 1'b0;
            frame_cnt  <= 32'd0;
            spi_start  <= 1'b0;
            spi_dc     <= 1'b0;
            spi_data   <= 8'd0;
        end else begin
            spi_start <= 1'b0;

            case (state)
                // 等待帧周期，init_done 前不计时
                R_IDLE: begin
                    if (!init_done) begin
                        frame_cnt <= 32'd0;
                    end else if (frame_cnt >= (FRAME_PERIOD - 1)) begin
                        frame_cnt <= 32'd0;
                        seq_idx   <= 4'd0;
                        state     <= R_SEQ_SEND;
                    end else begin
                        frame_cnt <= frame_cnt + 32'd1;
                    end
                end

                // 发送定位命令序列（CASET/RASET/RAMWR）
                R_SEQ_SEND: begin
                    if (!spi_busy) begin
                        spi_data  <= seq_data(seq_idx);
                        spi_dc    <= seq_dc(seq_idx);
                        spi_start <= 1'b1;
                        state     <= R_SEQ_WAIT;
                    end
                end

                R_SEQ_WAIT: begin
                    if (spi_done) begin
                        if (seq_idx == 4'd10) begin
                            // RAMWR 发完，开始逐像素写入
                            pix_x      <= 7'd0;
                            pix_y      <= 7'd0;
                            byte_phase <= 1'b0;
                            state      <= R_PIX_SEND;
                        end else begin
                            seq_idx <= seq_idx + 4'd1;
                            state   <= R_SEQ_SEND;
                        end
                    end
                end

                // 发送像素字节（byte_phase=0 高字节，=1 低字节）
                R_PIX_SEND: begin
                    if (!spi_busy) begin
                        spi_dc    <= 1'b1;
                        spi_data  <= byte_phase ? pixel_rgb[7:0] : pixel_rgb[15:8];
                        spi_start <= 1'b1;
                        state     <= R_PIX_WAIT;
                    end
                end

                R_PIX_WAIT: begin
                    if (spi_done) begin
                        if (!byte_phase) begin
                            // 高字节发完，发低字节
                            byte_phase <= 1'b1;
                            state      <= R_PIX_SEND;
                        end else begin
                            // 低字节发完，移动到下一像素
                            byte_phase <= 1'b0;
                            if ((pix_x == 7'd127) && (pix_y == 7'd127)) begin
                                state <= R_IDLE; // 整帧完成
                            end else begin
                                if (pix_x == 7'd127) begin
                                    pix_x <= 7'd0;
                                    pix_y <= pix_y + 7'd1;
                                end else begin
                                    pix_x <= pix_x + 7'd1;
                                end
                                state <= R_PIX_SEND;
                            end
                        end
                    end
                end

                default: state <= R_IDLE;
            endcase
        end
    end

endmodule

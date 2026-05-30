`timescale 1ns / 1ps

// ============================================================
// 模块: font_rom
// 功能: 5x7 点阵字体 ROM，支持数字 0-9、大写字母及常用符号
// 输入: ascii[7:0] — ASCII 码; row[2:0] — 字符行索引 (0=顶行)
// 输出: bits[7:0]  — 该行的像素位图，bit7 对应最左列
// 说明: 不支持的字符输出带边框的占位方块
// ============================================================
module font_rom(
    input  wire [7:0] ascii,
    input  wire [2:0] row,
    output reg  [7:0] bits
);

    // 字符点阵查表逻辑。
    // display_renderer 提供 ASCII 和 0~6 的行号，本组合逻辑返回该字符该行的像素掩码；
    // 每个 case 分支就是一个字符的 5x7 字形定义，未定义字符走默认占位图案。
    always @(*) begin
        case (ascii)
            8'h20: case (row) // space — 全空
                default: bits = 8'h00;
            endcase
            8'h2D: case (row) // '-'
                3'd3: bits = 8'h7E;
                default: bits = 8'h00;
            endcase
            8'h3A: case (row) // ':'
                3'd2: bits = 8'h18;
                3'd5: bits = 8'h18;
                default: bits = 8'h00;
            endcase
            // 数字 0-9
            8'h30: case (row) // 0
                3'd0: bits = 8'h3C; 3'd1: bits = 8'h66; 3'd2: bits = 8'h6E; 3'd3: bits = 8'h76;
                3'd4: bits = 8'h66; 3'd5: bits = 8'h66; 3'd6: bits = 8'h3C; default: bits = 8'h00;
            endcase
            8'h31: case (row) // 1
                3'd0: bits = 8'h18; 3'd1: bits = 8'h38; 3'd2: bits = 8'h18; 3'd3: bits = 8'h18;
                3'd4: bits = 8'h18; 3'd5: bits = 8'h18; 3'd6: bits = 8'h7E; default: bits = 8'h00;
            endcase
            8'h32: case (row) // 2
                3'd0: bits = 8'h3C; 3'd1: bits = 8'h66; 3'd2: bits = 8'h06; 3'd3: bits = 8'h1C;
                3'd4: bits = 8'h30; 3'd5: bits = 8'h60; 3'd6: bits = 8'h7E; default: bits = 8'h00;
            endcase
            8'h33: case (row) // 3
                3'd0: bits = 8'h3C; 3'd1: bits = 8'h66; 3'd2: bits = 8'h06; 3'd3: bits = 8'h1C;
                3'd4: bits = 8'h06; 3'd5: bits = 8'h66; 3'd6: bits = 8'h3C; default: bits = 8'h00;
            endcase
            8'h34: case (row) // 4
                3'd0: bits = 8'h0C; 3'd1: bits = 8'h1C; 3'd2: bits = 8'h3C; 3'd3: bits = 8'h6C;
                3'd4: bits = 8'h7E; 3'd5: bits = 8'h0C; 3'd6: bits = 8'h0C; default: bits = 8'h00;
            endcase
            8'h35: case (row) // 5
                3'd0: bits = 8'h7E; 3'd1: bits = 8'h60; 3'd2: bits = 8'h7C; 3'd3: bits = 8'h06;
                3'd4: bits = 8'h06; 3'd5: bits = 8'h66; 3'd6: bits = 8'h3C; default: bits = 8'h00;
            endcase
            8'h36: case (row) // 6
                3'd0: bits = 8'h1C; 3'd1: bits = 8'h30; 3'd2: bits = 8'h60; 3'd3: bits = 8'h7C;
                3'd4: bits = 8'h66; 3'd5: bits = 8'h66; 3'd6: bits = 8'h3C; default: bits = 8'h00;
            endcase
            8'h37: case (row) // 7
                3'd0: bits = 8'h7E; 3'd1: bits = 8'h06; 3'd2: bits = 8'h0C; 3'd3: bits = 8'h18;
                3'd4: bits = 8'h30; 3'd5: bits = 8'h30; 3'd6: bits = 8'h30; default: bits = 8'h00;
            endcase
            8'h38: case (row) // 8
                3'd0: bits = 8'h3C; 3'd1: bits = 8'h66; 3'd2: bits = 8'h66; 3'd3: bits = 8'h3C;
                3'd4: bits = 8'h66; 3'd5: bits = 8'h66; 3'd6: bits = 8'h3C; default: bits = 8'h00;
            endcase
            8'h39: case (row) // 9
                3'd0: bits = 8'h3C; 3'd1: bits = 8'h66; 3'd2: bits = 8'h66; 3'd3: bits = 8'h3E;
                3'd4: bits = 8'h06; 3'd5: bits = 8'h0C; 3'd6: bits = 8'h38; default: bits = 8'h00;
            endcase
            // 大写字母 A-Y（仅显示所需字符）
            8'h41: case (row) // A
                3'd0: bits = 8'h18; 3'd1: bits = 8'h24; 3'd2: bits = 8'h42; 3'd3: bits = 8'h7E;
                3'd4: bits = 8'h42; 3'd5: bits = 8'h42; 3'd6: bits = 8'h42; default: bits = 8'h00;
            endcase
            8'h43: case (row) // C
                3'd0: bits = 8'h3C; 3'd1: bits = 8'h66; 3'd2: bits = 8'h60; 3'd3: bits = 8'h60;
                3'd4: bits = 8'h60; 3'd5: bits = 8'h66; 3'd6: bits = 8'h3C; default: bits = 8'h00;
            endcase
            8'h44: case (row) // D
                3'd0: bits = 8'h78; 3'd1: bits = 8'h44; 3'd2: bits = 8'h42; 3'd3: bits = 8'h42;
                3'd4: bits = 8'h42; 3'd5: bits = 8'h44; 3'd6: bits = 8'h78; default: bits = 8'h00;
            endcase
            8'h45: case (row) // E
                3'd0: bits = 8'h7E; 3'd1: bits = 8'h60; 3'd2: bits = 8'h60; 3'd3: bits = 8'h7C;
                3'd4: bits = 8'h60; 3'd5: bits = 8'h60; 3'd6: bits = 8'h7E; default: bits = 8'h00;
            endcase
            8'h46: case (row) // F
                3'd0: bits = 8'h7E; 3'd1: bits = 8'h60; 3'd2: bits = 8'h60; 3'd3: bits = 8'h7C;
                3'd4: bits = 8'h60; 3'd5: bits = 8'h60; 3'd6: bits = 8'h60; default: bits = 8'h00;
            endcase
            8'h47: case (row) // G
                3'd0: bits = 8'h3C; 3'd1: bits = 8'h66; 3'd2: bits = 8'h60; 3'd3: bits = 8'h6E;
                3'd4: bits = 8'h66; 3'd5: bits = 8'h66; 3'd6: bits = 8'h3E; default: bits = 8'h00;
            endcase
            8'h48: case (row) // H
                3'd0: bits = 8'h42; 3'd1: bits = 8'h42; 3'd2: bits = 8'h42; 3'd3: bits = 8'h7E;
                3'd4: bits = 8'h42; 3'd5: bits = 8'h42; 3'd6: bits = 8'h42; default: bits = 8'h00;
            endcase
            8'h49: case (row) // I
                3'd0: bits = 8'h7E; 3'd1: bits = 8'h18; 3'd2: bits = 8'h18; 3'd3: bits = 8'h18;
                3'd4: bits = 8'h18; 3'd5: bits = 8'h18; 3'd6: bits = 8'h7E; default: bits = 8'h00;
            endcase
            8'h4C: case (row) // L
                3'd0: bits = 8'h60; 3'd1: bits = 8'h60; 3'd2: bits = 8'h60; 3'd3: bits = 8'h60;
                3'd4: bits = 8'h60; 3'd5: bits = 8'h60; 3'd6: bits = 8'h7E; default: bits = 8'h00;
            endcase
            8'h4D: case (row) // M
                3'd0: bits = 8'h42; 3'd1: bits = 8'h66; 3'd2: bits = 8'h5A; 3'd3: bits = 8'h5A;
                3'd4: bits = 8'h42; 3'd5: bits = 8'h42; 3'd6: bits = 8'h42; default: bits = 8'h00;
            endcase
            8'h4E: case (row) // N
                3'd0: bits = 8'h42; 3'd1: bits = 8'h62; 3'd2: bits = 8'h52; 3'd3: bits = 8'h4A;
                3'd4: bits = 8'h46; 3'd5: bits = 8'h42; 3'd6: bits = 8'h42; default: bits = 8'h00;
            endcase
            8'h4F: case (row) // O
                3'd0: bits = 8'h3C; 3'd1: bits = 8'h66; 3'd2: bits = 8'h66; 3'd3: bits = 8'h66;
                3'd4: bits = 8'h66; 3'd5: bits = 8'h66; 3'd6: bits = 8'h3C; default: bits = 8'h00;
            endcase
            8'h50: case (row) // P
                3'd0: bits = 8'h7C; 3'd1: bits = 8'h66; 3'd2: bits = 8'h66; 3'd3: bits = 8'h7C;
                3'd4: bits = 8'h60; 3'd5: bits = 8'h60; 3'd6: bits = 8'h60; default: bits = 8'h00;
            endcase
            8'h52: case (row) // R
                3'd0: bits = 8'h7C; 3'd1: bits = 8'h66; 3'd2: bits = 8'h66; 3'd3: bits = 8'h7C;
                3'd4: bits = 8'h6C; 3'd5: bits = 8'h66; 3'd6: bits = 8'h62; default: bits = 8'h00;
            endcase
            8'h53: case (row) // S
                3'd0: bits = 8'h3C; 3'd1: bits = 8'h66; 3'd2: bits = 8'h60; 3'd3: bits = 8'h3C;
                3'd4: bits = 8'h06; 3'd5: bits = 8'h66; 3'd6: bits = 8'h3C; default: bits = 8'h00;
            endcase
            8'h54: case (row) // T
                3'd0: bits = 8'h7E; 3'd1: bits = 8'h18; 3'd2: bits = 8'h18; 3'd3: bits = 8'h18;
                3'd4: bits = 8'h18; 3'd5: bits = 8'h18; 3'd6: bits = 8'h18; default: bits = 8'h00;
            endcase
            8'h55: case (row) // U
                3'd0: bits = 8'h42; 3'd1: bits = 8'h42; 3'd2: bits = 8'h42; 3'd3: bits = 8'h42;
                3'd4: bits = 8'h42; 3'd5: bits = 8'h42; 3'd6: bits = 8'h3C; default: bits = 8'h00;
            endcase
            8'h56: case (row) // V
                3'd0: bits = 8'h42; 3'd1: bits = 8'h42; 3'd2: bits = 8'h42; 3'd3: bits = 8'h42;
                3'd4: bits = 8'h42; 3'd5: bits = 8'h24; 3'd6: bits = 8'h18; default: bits = 8'h00;
            endcase
            8'h57: case (row) // W
                3'd0: bits = 8'h42; 3'd1: bits = 8'h42; 3'd2: bits = 8'h42; 3'd3: bits = 8'h5A;
                3'd4: bits = 8'h5A; 3'd5: bits = 8'h66; 3'd6: bits = 8'h42; default: bits = 8'h00;
            endcase
            8'h59: case (row) // Y
                3'd0: bits = 8'h42; 3'd1: bits = 8'h42; 3'd2: bits = 8'h24; 3'd3: bits = 8'h18;
                3'd4: bits = 8'h18; 3'd5: bits = 8'h18; 3'd6: bits = 8'h18; default: bits = 8'h00;
            endcase
            // 不支持的字符：输出带边框占位方块
            default: case (row)
                3'd0: bits = 8'h7E; 3'd1: bits = 8'h42; 3'd2: bits = 8'h5A; 3'd3: bits = 8'h42;
                3'd4: bits = 8'h5A; 3'd5: bits = 8'h42; 3'd6: bits = 8'h7E; default: bits = 8'h00;
            endcase
        endcase
    end

endmodule

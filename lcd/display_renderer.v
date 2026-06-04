`timescale 1ns / 1ps

module display_renderer #(
    parameter integer CLK_HZ   = 100000000,
    parameter integer FRAME_HZ = 2,
    parameter [15:0]  LCD_X_OFFSET = 16'd2,
    parameter [15:0]  LCD_Y_OFFSET = 16'd1
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
    input  wire        seated,
    input  wire [2:0]  seat_state,
    input  wire [15:0] sit_time_min,
    input  wire [5:0]  sit_time_sec,
    input  wire [15:0] away_time_min,
    input  wire [5:0]  away_time_sec,
    input  wire [9:0]  distance_cm,
    input  wire [9:0]  shoulder_diff_cm,
    input  wire [1:0]  torso_state,
    input  wire [1:0]  posture_level,
    input  wire [1:0]  weight_left_right_state,
    input  wire [1:0]  weight_front_back_state,
    input  wire        lean_left,
    input  wire        lean_right,
    input  wire        lean_front,
    input  wire        lean_back,
    input  wire [7:0]  hp,
    input  wire        hp_zero_alarm,
    output reg         spi_start,
    output reg         spi_dc,
    output reg  [7:0]  spi_data
);

    localparam [2:0] R_IDLE     = 3'd0;
    localparam [2:0] R_SEQ_SEND = 3'd1;
    localparam [2:0] R_SEQ_WAIT = 3'd2;
    localparam [2:0] R_PIX_SEND = 3'd3;
    localparam [2:0] R_PIX_WAIT = 3'd4;

    localparam [15:0] C_BLACK    = 16'h0000;
    localparam [15:0] C_WHITE    = 16'hFFFF;
    localparam [15:0] C_RED      = 16'hF800;
    localparam [15:0] C_GREEN    = 16'h07E0;
    localparam [15:0] C_YELLOW   = 16'hFFE0;
    localparam [15:0] C_GRAY     = 16'h4208;
    localparam [15:0] C_DARK_RED = 16'h6000;

    localparam [31:0] FRAME_PERIOD = (CLK_HZ / FRAME_HZ);
    localparam [15:0] COL_START = LCD_X_OFFSET;
    localparam [15:0] COL_END   = LCD_X_OFFSET + 16'd127;
    localparam [15:0] ROW_START = LCD_Y_OFFSET;
    localparam [15:0] ROW_END   = LCD_Y_OFFSET + 16'd127;

    reg [2:0]  state;
    reg [3:0]  seq_idx;
    reg [6:0]  pix_x;
    reg [6:0]  pix_y;
    reg        byte_phase;
    reg [31:0] frame_cnt;
    reg [15:0] pixel_rgb;

    wire [3:0] cell_col = pix_x[6:3];
    wire [3:0] cell_row = pix_y[6:3];
    wire [2:0] font_row = pix_y[2:0];
    wire [2:0] font_col = pix_x[2:0];
    wire [7:0] char_code;
    wire [7:0] font_bits;
    wire       text_on;
    wire       blink_on;
    wire       display_distance;
    wire [15:0] hp_bar_width;

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

    wire [3:0] sit_th  = (sit_time_min / 16'd1000) % 16'd10;
    wire [3:0] sit_h   = (sit_time_min / 16'd100)  % 16'd10;
    wire [3:0] sit_t   = (sit_time_min / 16'd10)   % 16'd10;
    wire [3:0] sit_o   = sit_time_min % 16'd10;
    wire [3:0] sit_sec_t = sit_time_sec / 6'd10;
    wire [3:0] sit_sec_o = sit_time_sec % 6'd10;
    wire [3:0] away_th = (away_time_min / 16'd1000) % 16'd10;
    wire [3:0] away_h  = (away_time_min / 16'd100)  % 16'd10;
    wire [3:0] away_t  = (away_time_min / 16'd10)   % 16'd10;
    wire [3:0] away_o  = away_time_min % 16'd10;
    wire [3:0] away_sec_t = away_time_sec / 6'd10;
    wire [3:0] away_sec_o = away_time_sec % 6'd10;
    wire [15:0] active_time_min = ((seat_state == 3'd4) || (seat_state == 3'd5)) ? away_time_min :
                                  ((seat_state == 3'd0) ? 16'd0 : sit_time_min);
    wire [5:0] active_time_sec = ((seat_state == 3'd4) || (seat_state == 3'd5)) ? away_time_sec :
                                 ((seat_state == 3'd0) ? 6'd0 : sit_time_sec);
    wire [3:0] active_th = (active_time_min / 16'd1000) % 16'd10;
    wire [3:0] active_h  = (active_time_min / 16'd100)  % 16'd10;
    wire [3:0] active_t  = (active_time_min / 16'd10)   % 16'd10;
    wire [3:0] active_o  = active_time_min % 16'd10;
    wire [3:0] active_sec_t = active_time_sec / 6'd10;
    wire [3:0] active_sec_o = active_time_sec % 6'd10;
    wire [3:0] dist_th = distance_cm / 10'd1000;
    wire [3:0] dist_h  = (distance_cm / 10'd100) % 10'd10;
    wire [3:0] dist_t  = (distance_cm / 10'd10)  % 10'd10;
    wire [3:0] dist_o  = distance_cm % 10'd10;
    wire [3:0] torso_diff_th = shoulder_diff_cm / 10'd1000;
    wire [3:0] torso_diff_h  = (shoulder_diff_cm / 10'd100) % 10'd10;
    wire [3:0] torso_diff_t  = (shoulder_diff_cm / 10'd10)  % 10'd10;
    wire [3:0] torso_diff_o  = shoulder_diff_cm % 10'd10;
    wire [3:0] hp_h    = hp / 8'd100;
    wire [3:0] hp_t    = (hp / 8'd10) % 8'd10;
    wire [3:0] hp_o    = hp % 8'd10;

    assign blink_on     = (hp_zero_alarm || (seat_state == 3'd3)) && second[0];
    assign display_distance = seated;
    assign hp_bar_width = (hp * 16'd110) / 16'd100;
    assign text_on      = font_bits[3'd7 - font_col];

    font_rom u_font_rom (
        .ascii(char_code),
        .row(font_row),
        .bits(font_bits)
    );

    assign char_code = char_at(cell_col, cell_row);

    function [7:0] ascii_digit;
        input [3:0] digit;
        begin
            ascii_digit = 8'h30 + {4'd0, digit};
        end
    endfunction

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

    function [7:0] posture_char;
        input [1:0] level;
        input [3:0] pos;
        begin
            posture_char = 8'h20;
            case (level)
                2'd0: begin // SAFE
                    case (pos) 4'd0: posture_char = "S"; 4'd1: posture_char = "A"; 4'd2: posture_char = "F"; 4'd3: posture_char = "E"; default: posture_char = " "; endcase
                end
                2'd1: begin // WARN
                    case (pos) 4'd0: posture_char = "W"; 4'd1: posture_char = "A"; 4'd2: posture_char = "R"; 4'd3: posture_char = "N"; default: posture_char = " "; endcase
                end
                2'd2: begin // DANGER
                    case (pos) 4'd0: posture_char = "D"; 4'd1: posture_char = "A"; 4'd2: posture_char = "N"; 4'd3: posture_char = "G"; 4'd4: posture_char = "E"; 4'd5: posture_char = "R"; default: posture_char = " "; endcase
                end
                default: posture_char = " ";
            endcase
        end
    endfunction

    function [7:0] torso_char;
        input [1:0] st;
        input [3:0] pos;
        begin
            torso_char = 8'h20;
            case (st)
                2'd0: begin // GOOD
                    case (pos) 4'd0: torso_char = "G"; 4'd1: torso_char = "O"; 4'd2: torso_char = "O"; 4'd3: torso_char = "D"; default: torso_char = " "; endcase
                end
                2'd1: begin // LEAN
                    case (pos) 4'd0: torso_char = "L"; 4'd1: torso_char = "E"; 4'd2: torso_char = "A"; 4'd3: torso_char = "N"; default: torso_char = " "; endcase
                end
                2'd2: begin // SIDE
                    case (pos) 4'd0: torso_char = "S"; 4'd1: torso_char = "I"; 4'd2: torso_char = "D"; 4'd3: torso_char = "E"; default: torso_char = " "; endcase
                end
                2'd3: begin // TWIST
                    case (pos) 4'd0: torso_char = "T"; 4'd1: torso_char = "W"; 4'd2: torso_char = "I"; 4'd3: torso_char = "S"; 4'd4: torso_char = "T"; default: torso_char = " "; endcase
                end
                default: torso_char = " ";
            endcase
        end
    endfunction

    function [7:0] weight_state_char;
        input [1:0] st;
        input [3:0] pos;
        begin
            weight_state_char = 8'h20;
            case (st)
                2'd0: begin // GOOD
                    case (pos) 4'd0: weight_state_char = "G"; 4'd1: weight_state_char = "O"; 4'd2: weight_state_char = "O"; 4'd3: weight_state_char = "D"; default: weight_state_char = " "; endcase
                end
                2'd1: begin // WARN
                    case (pos) 4'd0: weight_state_char = "W"; 4'd1: weight_state_char = "A"; 4'd2: weight_state_char = "R"; 4'd3: weight_state_char = "N"; default: weight_state_char = " "; endcase
                end
                2'd2: begin // DANGER
                    case (pos) 4'd0: weight_state_char = "D"; 4'd1: weight_state_char = "A"; 4'd2: weight_state_char = "N"; 4'd3: weight_state_char = "G"; 4'd4: weight_state_char = "E"; 4'd5: weight_state_char = "R"; default: weight_state_char = " "; endcase
                end
                default: weight_state_char = " ";
            endcase
        end
    endfunction

    function [7:0] weight_lr_dir_char;
        input lean_l;
        input lean_r;
        input [3:0] pos;
        begin
            weight_lr_dir_char = 8'h20;
            if (lean_l) begin
                case (pos) 4'd0: weight_lr_dir_char = "L"; 4'd1: weight_lr_dir_char = "E"; 4'd2: weight_lr_dir_char = "F"; 4'd3: weight_lr_dir_char = "T"; default: weight_lr_dir_char = " "; endcase
            end else if (lean_r) begin
                case (pos) 4'd0: weight_lr_dir_char = "R"; 4'd1: weight_lr_dir_char = "I"; 4'd2: weight_lr_dir_char = "G"; 4'd3: weight_lr_dir_char = "H"; 4'd4: weight_lr_dir_char = "T"; default: weight_lr_dir_char = " "; endcase
            end else begin
                case (pos) 4'd0: weight_lr_dir_char = "G"; 4'd1: weight_lr_dir_char = "O"; 4'd2: weight_lr_dir_char = "O"; 4'd3: weight_lr_dir_char = "D"; default: weight_lr_dir_char = " "; endcase
            end
        end
    endfunction

    function [7:0] weight_fb_dir_char;
        input lean_f;
        input lean_b;
        input [3:0] pos;
        begin
            weight_fb_dir_char = 8'h20;
            if (lean_f) begin
                case (pos) 4'd0: weight_fb_dir_char = "F"; 4'd1: weight_fb_dir_char = "R"; 4'd2: weight_fb_dir_char = "O"; 4'd3: weight_fb_dir_char = "N"; 4'd4: weight_fb_dir_char = "T"; default: weight_fb_dir_char = " "; endcase
            end else if (lean_b) begin
                case (pos) 4'd0: weight_fb_dir_char = "R"; 4'd1: weight_fb_dir_char = "E"; 4'd2: weight_fb_dir_char = "A"; 4'd3: weight_fb_dir_char = "R"; default: weight_fb_dir_char = " "; endcase
            end else begin
                case (pos) 4'd0: weight_fb_dir_char = "G"; 4'd1: weight_fb_dir_char = "O"; 4'd2: weight_fb_dir_char = "O"; 4'd3: weight_fb_dir_char = "D"; default: weight_fb_dir_char = " "; endcase
            end
        end
    endfunction

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
                4'd1: begin
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
                4'd3: begin
                    case (col)
                        4'd0: char_at = "S";
                        4'd1: char_at = "T";
                        4'd2: char_at = "A";
                        4'd3: char_at = "T";
                        4'd4: char_at = " ";
                        default: char_at = state_char(seat_state, col - 4'd5);
                    endcase
                end
                4'd4: begin
                    case (col)
                        4'd0: char_at = "P";
                        4'd1: char_at = "O";
                        4'd2: char_at = "S";
                        4'd3: char_at = "T";
                        4'd4: char_at = " ";
                        default: char_at = posture_char(posture_level, col - 4'd5);
                    endcase
                end
                4'd5: begin
                    case (col)
                        4'd0: char_at = "S";
                        4'd1: char_at = "I";
                        4'd2: char_at = "T";
                        4'd3: char_at = " ";
                        4'd4: char_at = ascii_digit(sit_th);
                        4'd5: char_at = ascii_digit(sit_h);
                        4'd6: char_at = ascii_digit(sit_t);
                        4'd7: char_at = ascii_digit(sit_o);
                        4'd8: char_at = ":";
                        4'd9: char_at = ascii_digit(sit_sec_t);
                        4'd10: char_at = ascii_digit(sit_sec_o);
                        default: char_at = " ";
                    endcase
                end
                4'd6: begin
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
                        4'd9: char_at = ":";
                        4'd10: char_at = ascii_digit(away_sec_t);
                        4'd11: char_at = ascii_digit(away_sec_o);
                        default: char_at = " ";
                    endcase
                end
                4'd7: begin
                    case (col)
                        4'd0: char_at = "W";
                        4'd1: char_at = "L";
                        4'd2: char_at = "R";
                        4'd3: char_at = " ";
                        4'd4: char_at = weight_lr_dir_char(lean_left, lean_right, 4'd0);
                        4'd5: char_at = weight_lr_dir_char(lean_left, lean_right, 4'd1);
                        4'd6: char_at = weight_lr_dir_char(lean_left, lean_right, 4'd2);
                        4'd7: char_at = weight_lr_dir_char(lean_left, lean_right, 4'd3);
                        4'd8: char_at = weight_lr_dir_char(lean_left, lean_right, 4'd4);
                        4'd9: char_at = " ";
                        default: char_at = weight_state_char(weight_left_right_state, col - 4'd10);
                    endcase
                end
                4'd8: begin
                    case (col)
                        4'd0: char_at = "N";
                        4'd1: char_at = "O";
                        4'd2: char_at = "W";
                        4'd3: char_at = " ";
                        4'd4: char_at = ascii_digit(active_th);
                        4'd5: char_at = ascii_digit(active_h);
                        4'd6: char_at = ascii_digit(active_t);
                        4'd7: char_at = ascii_digit(active_o);
                        4'd8: char_at = ":";
                        4'd9: char_at = ascii_digit(active_sec_t);
                        4'd10: char_at = ascii_digit(active_sec_o);
                        default: char_at = " ";
                    endcase
                end
                4'd9: begin
                    case (col)
                        4'd0: char_at = "W";
                        4'd1: char_at = "F";
                        4'd2: char_at = "R";
                        4'd3: char_at = " ";
                        4'd4: char_at = weight_fb_dir_char(lean_front, lean_back, 4'd0);
                        4'd5: char_at = weight_fb_dir_char(lean_front, lean_back, 4'd1);
                        4'd6: char_at = weight_fb_dir_char(lean_front, lean_back, 4'd2);
                        4'd7: char_at = weight_fb_dir_char(lean_front, lean_back, 4'd3);
                        4'd8: char_at = weight_fb_dir_char(lean_front, lean_back, 4'd4);
                        4'd9: char_at = " ";
                        default: char_at = weight_state_char(weight_front_back_state, col - 4'd10);
                    endcase
                end
                4'd10: begin
                    if (display_distance) begin
                        case (col)
                            4'd0: char_at = "T";
                            4'd1: char_at = "D";
                            4'd2: char_at = "I";
                            4'd3: char_at = "F";
                            4'd4: char_at = " ";
                            4'd5: char_at = ascii_digit(torso_diff_th);
                            4'd6: char_at = ascii_digit(torso_diff_h);
                            4'd7: char_at = ascii_digit(torso_diff_t);
                            4'd8: char_at = ascii_digit(torso_diff_o);
                            4'd9: char_at = "C";
                            4'd10: char_at = "M";
                            default: char_at = " ";
                        endcase
                    end else begin
                        char_at = " ";
                    end
                end
                4'd11: begin
                    if (display_distance) begin
                        case (col)
                            4'd0: char_at = "T";
                            4'd1: char_at = "O";
                            4'd2: char_at = "R";
                            4'd3: char_at = "S";
                            4'd4: char_at = " ";
                            default: char_at = torso_char(torso_state, col - 4'd5);
                        endcase
                    end else begin
                        char_at = " ";
                    end
                end
                4'd12: begin
                    if (display_distance) begin
                        case (col)
                            4'd0: char_at = "H";
                            4'd1: char_at = "E";
                            4'd2: char_at = "A";
                            4'd3: char_at = "D";
                            4'd4: char_at = " ";
                            4'd5: char_at = ascii_digit(dist_th);
                            4'd6: char_at = ascii_digit(dist_h);
                            4'd7: char_at = ascii_digit(dist_t);
                            4'd8: char_at = ascii_digit(dist_o);
                            4'd9: char_at = "C";
                            4'd10: char_at = "M";
                            default: char_at = " ";
                        endcase
                    end else begin
                        char_at = " ";
                    end
                end
                4'd13: begin
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

    function [7:0] seq_data;
        input [3:0] idx;
        begin
            case (idx)
                4'd0:  seq_data = 8'h2A; // CASET
                4'd1:  seq_data = COL_START[15:8];
                4'd2:  seq_data = COL_START[7:0];
                4'd3:  seq_data = COL_END[15:8];
                4'd4:  seq_data = COL_END[7:0];
                4'd5:  seq_data = 8'h2B; // RASET
                4'd6:  seq_data = ROW_START[15:8];
                4'd7:  seq_data = ROW_START[7:0];
                4'd8:  seq_data = ROW_END[15:8];
                4'd9:  seq_data = ROW_END[7:0];
                4'd10: seq_data = 8'h2C; // RAMWR
                default: seq_data = 8'h00;
            endcase
        end
    endfunction

    function seq_dc;
        input [3:0] idx;
        begin
            case (idx)
                4'd0, 4'd5, 4'd10: seq_dc = 1'b0;
                default: seq_dc = 1'b1;
            endcase
        end
    endfunction

    always @(*) begin
        pixel_rgb = C_BLACK;

        if (blink_on) begin
            if (text_on)
                pixel_rgb = C_YELLOW;
            else
                pixel_rgb = C_DARK_RED;
        end else if ((pix_x >= 7'd8) && (pix_x < 7'd120) && (pix_y >= 7'd112) && (pix_y < 7'd124)) begin
            if ((pix_x == 7'd8) || (pix_x == 7'd119) || (pix_y == 7'd112) || (pix_y == 7'd123)) begin
                pixel_rgb = C_WHITE;
            end else if ((pix_x - 7'd9) < hp_bar_width[6:0]) begin
                if (hp >= 8'd70)
                    pixel_rgb = C_GREEN;
                else if (hp >= 8'd30)
                    pixel_rgb = C_YELLOW;
                else
                    pixel_rgb = C_RED;
            end else begin
                pixel_rgb = C_GRAY;
            end
        end else if (text_on) begin
            pixel_rgb = C_WHITE;
        end else begin
            pixel_rgb = C_BLACK;
        end
    end

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
                            byte_phase <= 1'b1;
                            state      <= R_PIX_SEND;
                        end else begin
                            byte_phase <= 1'b0;
                            if ((pix_x == 7'd127) && (pix_y == 7'd127)) begin
                                state <= R_IDLE;
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

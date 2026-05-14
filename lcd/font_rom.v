`timescale 1ns / 1ps

module font_rom(
    input  wire [7:0] ascii,
    input  wire [2:0] row,
    output reg  [7:0] bits
);

    always @(*) begin
        case (ascii)
            8'h20: case (row) // space
                default: bits = 8'h00;
            endcase
            8'h2D: case (row) // -
                3'd3: bits = 8'h7E;
                default: bits = 8'h00;
            endcase
            8'h3A: case (row) // :
                3'd2: bits = 8'h18;
                3'd5: bits = 8'h18;
                default: bits = 8'h00;
            endcase
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
            8'h41: case (row) // A
                3'd0: bits = 8'h18; 3'd1: bits = 8'h24; 3'd2: bits = 8'h42; 3'd3: bits = 8'h7E;
                3'd4: bits = 8'h42; 3'd5: bits = 8'h42; 3'd6: bits = 8'h42; default: bits = 8'h00;
            endcase
            8'h44: case (row) // D
                3'd0: bits = 8'h78; 3'd1: bits = 8'h44; 3'd2: bits = 8'h42; 3'd3: bits = 8'h42;
                3'd4: bits = 8'h42; 3'd5: bits = 8'h44; 3'd6: bits = 8'h78; default: bits = 8'h00;
            endcase
            8'h45: case (row) // E
                3'd0: bits = 8'h7E; 3'd1: bits = 8'h60; 3'd2: bits = 8'h60; 3'd3: bits = 8'h7C;
                3'd4: bits = 8'h60; 3'd5: bits = 8'h60; 3'd6: bits = 8'h7E; default: bits = 8'h00;
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
            default: case (row) // unsupported character box
                3'd0: bits = 8'h7E; 3'd1: bits = 8'h42; 3'd2: bits = 8'h5A; 3'd3: bits = 8'h42;
                3'd4: bits = 8'h5A; 3'd5: bits = 8'h42; 3'd6: bits = 8'h7E; default: bits = 8'h00;
            endcase
        endcase
    end

endmodule

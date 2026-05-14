`timescale 1ns / 1ps

module st7735_spi #(
    parameter integer CLK_DIV = 5
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire       dc,
    input  wire [7:0] data,
    output reg        busy,
    output reg        done,
    output reg        lcd_cs_n,
    output reg        lcd_dc,
    output reg        lcd_scl,
    output reg        lcd_mosi
);

    reg [7:0] shift_reg;
    reg [2:0] bit_cnt;
    reg [15:0] div_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy      <= 1'b0;
            done      <= 1'b0;
            lcd_cs_n  <= 1'b1;
            lcd_dc    <= 1'b0;
            lcd_scl   <= 1'b0;
            lcd_mosi  <= 1'b0;
            shift_reg <= 8'd0;
            bit_cnt   <= 3'd0;
            div_cnt   <= 16'd0;
        end else begin
            done <= 1'b0;

            if (!busy) begin
                lcd_scl  <= 1'b0;
                lcd_cs_n <= 1'b1;
                div_cnt  <= 16'd0;
                if (start) begin
                    busy      <= 1'b1;
                    lcd_cs_n  <= 1'b0;
                    lcd_dc    <= dc;
                    shift_reg <= data;
                    bit_cnt   <= 3'd7;
                    lcd_mosi  <= data[7];
                end
            end else begin
                if (div_cnt >= (CLK_DIV - 1)) begin
                    div_cnt <= 16'd0;

                    if (lcd_scl == 1'b0) begin
                        lcd_scl <= 1'b1;
                    end else begin
                        lcd_scl <= 1'b0;
                        if (bit_cnt == 3'd0) begin
                            busy     <= 1'b0;
                            done     <= 1'b1;
                            lcd_cs_n <= 1'b1;
                        end else begin
                            bit_cnt  <= bit_cnt - 3'd1;
                            lcd_mosi <= shift_reg[bit_cnt - 3'd1];
                        end
                    end
                end else begin
                    div_cnt <= div_cnt + 16'd1;
                end
            end
        end
    end

endmodule

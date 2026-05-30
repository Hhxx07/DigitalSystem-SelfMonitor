`timescale 1ns / 1ps

module distance_calc(
    input  wire        clk_100m,
    input  wire        RST,
    input  wire        pos_Echo,
    input  wire        neg_Echo,
    output wire [15:0] data,
    output reg         data_valid
);

    parameter S0 = 2'b00;
    parameter S1 = 2'b01;
    parameter S2 = 2'b10;

    reg [1:0]  curr_state;
    reg [15:0] cnt;
    reg [15:0] dis_reg;
    reg [15:0] cnt_17k;

    always @(posedge clk_100m or negedge RST) begin
        if (!RST) begin
            cnt_17k <= 16'd0;
            dis_reg <= 16'd0;
            cnt <= 16'd0;
            curr_state <= S0;
            data_valid <= 1'b0;
        end else begin
            data_valid <= 1'b0;
            case (curr_state)
                S0: begin
                    cnt <= 16'd0;
                    cnt_17k <= 16'd0;
                    if (pos_Echo)
                        curr_state <= S1;
                end

                S1: begin
                    if (neg_Echo) begin
                        curr_state <= S2;
                    end else begin
                        // About 5600 cycles at 100 MHz are treated as 1 cm.
                        if (cnt_17k < 16'd5600) begin
                            cnt_17k <= cnt_17k + 16'd1;
                        end else begin
                            cnt_17k <= 16'd0;
                            cnt <= cnt + 16'd1;
                        end
                    end
                end

                S2: begin
                    dis_reg <= cnt;
                    data_valid <= 1'b1;
                    curr_state <= S0;
                end

                default: curr_state <= S0;
            endcase
        end
    end

    assign data = (curr_state == S2) ? cnt : dis_reg;

endmodule

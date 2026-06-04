`timescale 1ns / 1ps

module weight_packet_rx #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115_200
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        uart_rx_pin,
    output reg         packet_valid,
    output reg  [7:0]  packet_seq,
    output reg         pressure_ok,
    output reg  [15:0] weight_left_front,
    output reg  [15:0] weight_right_front,
    output reg  [15:0] weight_left_rear,
    output reg  [15:0] weight_right_rear,
    output reg  [1:0]  left_right_state,
    output reg  [1:0]  front_back_state,
    output reg         lean_left,
    output reg         lean_right,
    output reg         lean_front,
    output reg         lean_back,
    output reg         checksum_error
);

    localparam [4:0] S_WAIT_A5 = 5'd0;
    localparam [4:0] S_WAIT_5A = 5'd1;
    localparam [4:0] S_SEQ     = 5'd2;
    localparam [4:0] S_FLAGS   = 5'd3;
    localparam [4:0] S_LF_H    = 5'd4;
    localparam [4:0] S_LF_L    = 5'd5;
    localparam [4:0] S_RF_H    = 5'd6;
    localparam [4:0] S_RF_L    = 5'd7;
    localparam [4:0] S_LR_H    = 5'd8;
    localparam [4:0] S_LR_L    = 5'd9;
    localparam [4:0] S_RR_H    = 5'd10;
    localparam [4:0] S_RR_L    = 5'd11;
    localparam [4:0] S_LR_ST   = 5'd12;
    localparam [4:0] S_FB_ST   = 5'd13;
    localparam [4:0] S_CSUM    = 5'd14;
    localparam [4:0] S_LF      = 5'd15;

    wire [7:0] rx_data;
    wire       rx_valid;

    reg [4:0]  state;
    reg [7:0]  checksum_calc;
    reg [7:0]  flags_tmp;
    reg [7:0]  seq_tmp;
    reg [15:0] lf_tmp;
    reg [15:0] rf_tmp;
    reg [15:0] lr_tmp;
    reg [15:0] rr_tmp;
    reg [1:0]  lr_state_tmp;
    reg [1:0]  fb_state_tmp;

    uart_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_rx (
        .clk(clk),
        .reset(reset),
        .rx(uart_rx_pin),
        .rx_data(rx_data),
        .rx_valid(rx_valid)
    );

    always @(posedge clk) begin
        if (reset) begin
            state <= S_WAIT_A5;
            checksum_calc <= 8'd0;
            flags_tmp <= 8'd0;
            seq_tmp <= 8'd0;
            lf_tmp <= 16'd0;
            rf_tmp <= 16'd0;
            lr_tmp <= 16'd0;
            rr_tmp <= 16'd0;
            lr_state_tmp <= 2'd0;
            fb_state_tmp <= 2'd0;
            packet_valid <= 1'b0;
            packet_seq <= 8'd0;
            pressure_ok <= 1'b0;
            weight_left_front <= 16'd0;
            weight_right_front <= 16'd0;
            weight_left_rear <= 16'd0;
            weight_right_rear <= 16'd0;
            left_right_state <= 2'd0;
            front_back_state <= 2'd0;
            lean_left <= 1'b0;
            lean_right <= 1'b0;
            lean_front <= 1'b0;
            lean_back <= 1'b0;
            checksum_error <= 1'b0;
        end else begin
            packet_valid <= 1'b0;

            if (rx_valid) begin
                case (state)
                    S_WAIT_A5: begin
                        checksum_error <= 1'b0;
                        if (rx_data == 8'hA5) begin
                            checksum_calc <= 8'hA5;
                            state <= S_WAIT_5A;
                        end
                    end

                    S_WAIT_5A: begin
                        if (rx_data == 8'h5A) begin
                            checksum_calc <= checksum_calc ^ rx_data;
                            state <= S_SEQ;
                        end else if (rx_data == 8'hA5) begin
                            checksum_calc <= 8'hA5;
                            state <= S_WAIT_5A;
                        end else begin
                            state <= S_WAIT_A5;
                        end
                    end

                    S_SEQ: begin
                        seq_tmp <= rx_data;
                        checksum_calc <= checksum_calc ^ rx_data;
                        state <= S_FLAGS;
                    end

                    S_FLAGS: begin
                        flags_tmp <= rx_data;
                        checksum_calc <= checksum_calc ^ rx_data;
                        state <= S_LF_H;
                    end

                    S_LF_H: begin
                        lf_tmp[15:8] <= rx_data;
                        checksum_calc <= checksum_calc ^ rx_data;
                        state <= S_LF_L;
                    end

                    S_LF_L: begin
                        lf_tmp[7:0] <= rx_data;
                        checksum_calc <= checksum_calc ^ rx_data;
                        state <= S_RF_H;
                    end

                    S_RF_H: begin
                        rf_tmp[15:8] <= rx_data;
                        checksum_calc <= checksum_calc ^ rx_data;
                        state <= S_RF_L;
                    end

                    S_RF_L: begin
                        rf_tmp[7:0] <= rx_data;
                        checksum_calc <= checksum_calc ^ rx_data;
                        state <= S_LR_H;
                    end

                    S_LR_H: begin
                        lr_tmp[15:8] <= rx_data;
                        checksum_calc <= checksum_calc ^ rx_data;
                        state <= S_LR_L;
                    end

                    S_LR_L: begin
                        lr_tmp[7:0] <= rx_data;
                        checksum_calc <= checksum_calc ^ rx_data;
                        state <= S_RR_H;
                    end

                    S_RR_H: begin
                        rr_tmp[15:8] <= rx_data;
                        checksum_calc <= checksum_calc ^ rx_data;
                        state <= S_RR_L;
                    end

                    S_RR_L: begin
                        rr_tmp[7:0] <= rx_data;
                        checksum_calc <= checksum_calc ^ rx_data;
                        state <= S_LR_ST;
                    end

                    S_LR_ST: begin
                        lr_state_tmp <= rx_data[1:0];
                        checksum_calc <= checksum_calc ^ rx_data;
                        state <= S_FB_ST;
                    end

                    S_FB_ST: begin
                        fb_state_tmp <= rx_data[1:0];
                        checksum_calc <= checksum_calc ^ rx_data;
                        state <= S_CSUM;
                    end

                    S_CSUM: begin
                        if (rx_data == checksum_calc) begin
                            state <= S_LF;
                        end else begin
                            checksum_error <= 1'b1;
                            state <= S_WAIT_A5;
                        end
                    end

                    S_LF: begin
                        if (rx_data == 8'h0A) begin
                            packet_seq <= seq_tmp;
                            pressure_ok <= flags_tmp[0];
                            lean_left <= flags_tmp[1];
                            lean_right <= flags_tmp[2];
                            lean_front <= flags_tmp[3];
                            lean_back <= flags_tmp[4];
                            weight_left_front <= lf_tmp;
                            weight_right_front <= rf_tmp;
                            weight_left_rear <= lr_tmp;
                            weight_right_rear <= rr_tmp;
                            left_right_state <= lr_state_tmp;
                            front_back_state <= fb_state_tmp;
                            packet_valid <= 1'b1;
                        end
                        state <= S_WAIT_A5;
                    end

                    default: begin
                        state <= S_WAIT_A5;
                    end
                endcase
            end
        end
    end

endmodule

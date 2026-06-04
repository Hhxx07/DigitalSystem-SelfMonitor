`timescale 1ns / 1ps

module weight_packet_tx #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115_200,
    parameter integer SEND_HZ     = 10
) (
    input  wire        clk,
    input  wire        reset,
    input  wire [15:0] weight_left_front,
    input  wire [15:0] weight_right_front,
    input  wire [15:0] weight_left_rear,
    input  wire [15:0] weight_right_rear,
    input  wire        seat_present,
    input  wire [1:0]  left_right_state,
    input  wire [1:0]  front_back_state,
    input  wire        lean_left,
    input  wire        lean_right,
    input  wire        lean_front,
    input  wire        lean_back,
    output wire        uart_tx
);

    localparam integer SEND_DIV = CLK_FREQ_HZ / SEND_HZ;
    localparam integer FRAME_LEN = 16;

    localparam [1:0] S_IDLE = 2'd0;
    localparam [1:0] S_SEND = 2'd1;
    localparam [1:0] S_WAIT = 2'd2;

    reg [31:0] send_count;
    reg [1:0]  state;
    reg [4:0]  byte_index;
    reg [7:0]  seq;
    reg [7:0]  tx_data;
    reg        tx_start;
    wire       tx_busy;
    wire       tx_done;

    reg [15:0] lf_latch;
    reg [15:0] rf_latch;
    reg [15:0] lr_latch;
    reg [15:0] rr_latch;
    reg [7:0]  flags_latch;
    reg [1:0]  lr_state_latch;
    reg [1:0]  fb_state_latch;

    wire [7:0] checksum;

    assign checksum = 8'hA5 ^ 8'h5A ^ seq ^ flags_latch ^
                      lf_latch[15:8] ^ lf_latch[7:0] ^
                      rf_latch[15:8] ^ rf_latch[7:0] ^
                      lr_latch[15:8] ^ lr_latch[7:0] ^
                      rr_latch[15:8] ^ rr_latch[7:0] ^
                      {6'd0, lr_state_latch} ^ {6'd0, fb_state_latch};

    function [7:0] frame_byte;
        input [4:0] index;
        begin
            case (index)
                5'd0:  frame_byte = 8'hA5;
                5'd1:  frame_byte = 8'h5A;
                5'd2:  frame_byte = seq;
                5'd3:  frame_byte = flags_latch;
                5'd4:  frame_byte = lf_latch[15:8];
                5'd5:  frame_byte = lf_latch[7:0];
                5'd6:  frame_byte = rf_latch[15:8];
                5'd7:  frame_byte = rf_latch[7:0];
                5'd8:  frame_byte = lr_latch[15:8];
                5'd9:  frame_byte = lr_latch[7:0];
                5'd10: frame_byte = rr_latch[15:8];
                5'd11: frame_byte = rr_latch[7:0];
                5'd12: frame_byte = {6'd0, lr_state_latch};
                5'd13: frame_byte = {6'd0, fb_state_latch};
                5'd14: frame_byte = checksum;
                5'd15: frame_byte = 8'h0A;
                default: frame_byte = 8'h00;
            endcase
        end
    endfunction

    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_tx (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(uart_tx),
        .busy(tx_busy),
        .done(tx_done)
    );

    always @(posedge clk) begin
        if (reset) begin
            send_count <= 32'd0;
            state <= S_IDLE;
            byte_index <= 5'd0;
            seq <= 8'd0;
            tx_data <= 8'd0;
            tx_start <= 1'b0;
            lf_latch <= 16'd0;
            rf_latch <= 16'd0;
            lr_latch <= 16'd0;
            rr_latch <= 16'd0;
            flags_latch <= 8'd0;
            lr_state_latch <= 2'd0;
            fb_state_latch <= 2'd0;
        end else begin
            tx_start <= 1'b0;

            if (send_count == SEND_DIV - 1) begin
                send_count <= 32'd0;
            end else begin
                send_count <= send_count + 32'd1;
            end

            case (state)
                S_IDLE: begin
                    if (send_count == SEND_DIV - 1) begin
                        lf_latch <= weight_left_front;
                        rf_latch <= weight_right_front;
                        lr_latch <= weight_left_rear;
                        rr_latch <= weight_right_rear;
                        flags_latch <= {3'd0, lean_back, lean_front, lean_right, lean_left, seat_present};
                        lr_state_latch <= left_right_state;
                        fb_state_latch <= front_back_state;
                        byte_index <= 5'd0;
                        state <= S_SEND;
                    end
                end

                S_SEND: begin
                    if (!tx_busy) begin
                        tx_data <= frame_byte(byte_index);
                        tx_start <= 1'b1;
                        state <= S_WAIT;
                    end
                end

                S_WAIT: begin
                    if (tx_done) begin
                        if (byte_index == FRAME_LEN - 1) begin
                            seq <= seq + 8'd1;
                            state <= S_IDLE;
                        end else begin
                            byte_index <= byte_index + 5'd1;
                            state <= S_SEND;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

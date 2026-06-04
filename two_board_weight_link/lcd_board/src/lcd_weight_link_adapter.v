`timescale 1ns / 1ps

module lcd_weight_link_adapter #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115_200,
    parameter integer TIMEOUT_MS  = 500
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        link_uart_rx,
    output wire        packet_valid,
    output wire        pressure_ok,
    output wire [15:0] weight_left_front,
    output wire [15:0] weight_left_rear,
    output wire [15:0] weight_right_front,
    output wire [15:0] weight_right_rear,
    output wire [1:0]  left_right_state,
    output wire [1:0]  front_back_state,
    output wire        lean_left,
    output wire        lean_right,
    output wire        lean_front,
    output wire        lean_back,
    output wire        link_alive,
    output wire        checksum_error
);

    localparam integer TIMEOUT_CYCLES = (CLK_FREQ_HZ / 1000) * TIMEOUT_MS;

    wire [7:0] packet_seq;
    wire raw_pressure_ok;
    reg [31:0] timeout_count;
    reg alive_reg;

    assign pressure_ok = raw_pressure_ok & alive_reg;
    assign link_alive = alive_reg;

    weight_packet_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) u_packet_rx (
        .clk(clk),
        .reset(reset),
        .uart_rx_pin(link_uart_rx),
        .packet_valid(packet_valid),
        .packet_seq(packet_seq),
        .pressure_ok(raw_pressure_ok),
        .weight_left_front(weight_left_front),
        .weight_right_front(weight_right_front),
        .weight_left_rear(weight_left_rear),
        .weight_right_rear(weight_right_rear),
        .left_right_state(left_right_state),
        .front_back_state(front_back_state),
        .lean_left(lean_left),
        .lean_right(lean_right),
        .lean_front(lean_front),
        .lean_back(lean_back),
        .checksum_error(checksum_error)
    );

    always @(posedge clk) begin
        if (reset) begin
            timeout_count <= 32'd0;
            alive_reg <= 1'b0;
        end else begin
            if (packet_valid) begin
                timeout_count <= 32'd0;
                alive_reg <= 1'b1;
            end else if (timeout_count >= TIMEOUT_CYCLES - 1) begin
                timeout_count <= timeout_count;
                alive_reg <= 1'b0;
            end else begin
                timeout_count <= timeout_count + 32'd1;
            end
        end
    end

endmodule

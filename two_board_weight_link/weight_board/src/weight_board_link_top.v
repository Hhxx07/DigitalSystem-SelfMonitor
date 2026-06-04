`timescale 1ns / 1ps

module weight_board_link_top #(
    parameter integer CLK_FREQ_HZ    = 100_000_000,
    parameter integer BAUD_RATE      = 115_200,
    parameter integer SEND_HZ        = 10,
    parameter [15:0]  SEAT_ON_TH     = 16'd800,
    parameter [15:0]  SEAT_OFF_TH    = 16'd300,
    parameter [7:0]   WARN_PERCENT   = 8'd15,
    parameter [7:0]   DANGER_PERCENT = 8'd30
) (
    input  wire clk100,

    input  wire vauxp0,
    input  wire vauxn0,
    input  wire vauxp2,
    input  wire vauxn2,
    input  wire vauxp3,
    input  wire vauxn3,
    input  wire vauxp8,
    input  wire vauxn8,

    output wire link_uart_tx,
    output reg  led0,
    output wire led_seat
);

    reg [19:0] reset_count = 20'd0;
    reg reset = 1'b1;
    reg [26:0] led_count = 27'd0;

    wire [11:0] pressure_fl_12;
    wire [11:0] pressure_fr_12;
    wire [11:0] pressure_bl_12;
    wire [11:0] pressure_br_12;
    wire [15:0] weight_left_front;
    wire [15:0] weight_right_front;
    wire [15:0] weight_left_rear;
    wire [15:0] weight_right_rear;
    wire sample_update;
    wire seat_present;
    wire [16:0] left_sum;
    wire [16:0] right_sum;
    wire [16:0] front_sum;
    wire [16:0] rear_sum;
    wire [16:0] left_right_diff;
    wire [16:0] front_back_diff;
    wire [1:0] left_right_state;
    wire [1:0] front_back_state;
    wire lean_left;
    wire lean_right;
    wire lean_front;
    wire lean_back;

    assign weight_left_front  = {4'd0, pressure_fl_12};
    assign weight_right_front = {4'd0, pressure_fr_12};
    assign weight_left_rear   = {4'd0, pressure_bl_12};
    assign weight_right_rear  = {4'd0, pressure_br_12};
    assign led_seat = seat_present;

    always @(posedge clk100) begin
        if (reset_count == 20'd999999) begin
            reset <= 1'b0;
        end else begin
            reset_count <= reset_count + 20'd1;
            reset <= 1'b1;
        end
    end

    always @(posedge clk100) begin
        if (reset) begin
            led_count <= 27'd0;
            led0 <= 1'b0;
        end else begin
            led_count <= led_count + 27'd1;
            if (led_count == 27'd99_999_999) begin
                led_count <= 27'd0;
                led0 <= ~led0;
            end
        end
    end

    xadc_4ch_reader u_xadc_reader (
        .clk(clk100),
        .reset(reset),
        .vauxp0(vauxp0),
        .vauxn0(vauxn0),
        .vauxp2(vauxp2),
        .vauxn2(vauxn2),
        .vauxp3(vauxp3),
        .vauxn3(vauxn3),
        .vauxp8(vauxp8),
        .vauxn8(vauxn8),
        .pressure0(pressure_fl_12),
        .pressure2(pressure_fr_12),
        .pressure3(pressure_bl_12),
        .pressure8(pressure_br_12),
        .sample_update(sample_update)
    );

    seat_weight_analyzer #(
        .SEAT_ON_TH(SEAT_ON_TH),
        .SEAT_OFF_TH(SEAT_OFF_TH),
        .WARN_PERCENT(WARN_PERCENT),
        .DANGER_PERCENT(DANGER_PERCENT)
    ) u_weight_analyzer (
        .clk(clk100),
        .reset(reset),
        .weight_left_front(weight_left_front),
        .weight_right_front(weight_right_front),
        .weight_left_rear(weight_left_rear),
        .weight_right_rear(weight_right_rear),
        .seat_present(seat_present),
        .left_sum(left_sum),
        .right_sum(right_sum),
        .front_sum(front_sum),
        .rear_sum(rear_sum),
        .left_right_diff(left_right_diff),
        .front_back_diff(front_back_diff),
        .left_right_state(left_right_state),
        .front_back_state(front_back_state),
        .lean_left(lean_left),
        .lean_right(lean_right),
        .lean_front(lean_front),
        .lean_back(lean_back)
    );

    weight_packet_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE),
        .SEND_HZ(SEND_HZ)
    ) u_packet_tx (
        .clk(clk100),
        .reset(reset),
        .weight_left_front(weight_left_front),
        .weight_right_front(weight_right_front),
        .weight_left_rear(weight_left_rear),
        .weight_right_rear(weight_right_rear),
        .seat_present(seat_present),
        .left_right_state(left_right_state),
        .front_back_state(front_back_state),
        .lean_left(lean_left),
        .lean_right(lean_right),
        .lean_front(lean_front),
        .lean_back(lean_back),
        .uart_tx(link_uart_tx)
    );

endmodule

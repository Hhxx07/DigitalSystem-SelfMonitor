`timescale 1ns / 1ps

module top_Ranging(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        ultrasonic_echo,
    output wire        ultrasonic_trig,

    output wire [15:0] distance_cm
);

    wire echo_sync_out;
    wire echo_pos;
    wire echo_neg;
    wire distance_valid;

    trig_generator u_trig (
        .clk_100m(clk),
        .RST(rst_n),
        .Trig(ultrasonic_trig)
    );

    signal_sync u_sync_echo (
        .clk_100m(clk),
        .RST(rst_n),
        .async_in(ultrasonic_echo),
        .sync_out(echo_sync_out),
        .pos_edge(echo_pos),
        .neg_edge(echo_neg)
    );

    distance_calc u_calc (
        .clk_100m(clk),
        .RST(rst_n),
        .pos_Echo(echo_pos),
        .neg_Echo(echo_neg),
        .data(distance_cm),
        .data_valid(distance_valid)
    );

endmodule

`timescale 1ns / 1ps

module hx711_weight_uart_top #(
    parameter CLK_FREQ_HZ = 100_000_000,
    parameter BAUD_RATE   = 115_200,
    parameter SCK_FREQ_HZ = 50_000,
    parameter GAIN_PULSES = 1
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        hx711_dout,
    output wire        hx711_sck,

    output wire        uart_tx,

    output wire        raw_data_valid,
    output wire        link_busy
);

    wire [23:0] raw_data;

    hx711_uart_link #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE),
        .SCK_FREQ_HZ(SCK_FREQ_HZ),
        .GAIN_PULSES(GAIN_PULSES)
    ) u_hx711_uart_link (
        .clk(clk),
        .rst_n(rst_n),
        .hx711_dout(hx711_dout),
        .hx711_sck(hx711_sck),
        .uart_tx(uart_tx),
        .raw_data(raw_data),
        .raw_data_valid(raw_data_valid),
        .link_busy(link_busy)
    );

endmodule

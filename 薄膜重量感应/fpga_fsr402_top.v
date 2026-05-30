module fpga_fsr402_top (
    input  wire clk100,

    input  wire vauxp0,
    input  wire vauxn0,
    input  wire vauxp2,
    input  wire vauxn2,
    input  wire vauxp3,
    input  wire vauxn3,
    input  wire vauxp8,
    input  wire vauxn8,

    output wire uart_tx,
    output reg  led0
);

    reg [19:0] reset_count = 20'd0;
    reg reset = 1'b1;

    wire [11:0] pressure_fl;
    wire [11:0] pressure_fr;
    wire [11:0] pressure_bl;
    wire [11:0] pressure_br;
    wire sample_update;

    reg [26:0] led_count = 27'd0;

    always @(posedge clk100) begin
        if (reset_count == 20'd999999) begin
            reset <= 1'b0;
        end else begin
            reset_count <= reset_count + 20'd1;
            reset <= 1'b1;
        end
    end

    always @(posedge clk100) begin
        led_count <= led_count + 27'd1;
        if (led_count == 27'd99_999_999) begin
            led_count <= 27'd0;
            led0 <= ~led0;
        end
    end

    xadc_4ch_reader xadc_reader_inst (
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
        .pressure0(pressure_fl),
        .pressure2(pressure_fr),
        .pressure3(pressure_bl),
        .pressure8(pressure_br),
        .sample_update(sample_update)
    );

    uart_fsr402_streamer #(
        .CLK_FREQ_HZ(100_000_000),
        .BAUD_RATE(115_200),
        .REPORT_HZ(5)
    ) streamer_inst (
        .clk(clk100),
        .reset(reset),
        .pressure_fl(pressure_fl),
        .pressure_fr(pressure_fr),
        .pressure_bl(pressure_bl),
        .pressure_br(pressure_br),
        .uart_tx(uart_tx)
    );

endmodule

module lcd_board_link_rx_top #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115_200
) (
    input  wire clk,
    input  wire rst_n,
    input  wire link_uart_rx,
    output reg  led0,
    output wire led_link_alive,
    output wire led_packet,
    output wire led_seat,
    output wire led_checksum_error
);

    wire reset;
    wire packet_valid;
    wire pressure_ok;
    wire [15:0] weight_left_front;
    wire [15:0] weight_left_rear;
    wire [15:0] weight_right_front;
    wire [15:0] weight_right_rear;
    wire [1:0]  left_right_state;
    wire [1:0]  front_back_state;
    wire lean_left;
    wire lean_right;
    wire lean_front;
    wire lean_back;
    wire link_alive;
    wire checksum_error;

    reg [26:0] led_count = 27'd0;
    reg [23:0] packet_led_count = 24'd0;
    reg packet_pulse_led = 1'b0;

    assign reset = ~rst_n;
    assign led_link_alive = link_alive;
    assign led_packet = packet_pulse_led;
    assign led_seat = pressure_ok;
    assign led_checksum_error = checksum_error;

    lcd_weight_link_adapter #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE),
        .TIMEOUT_MS(500)
    ) u_link_adapter (
        .clk(clk),
        .reset(reset),
        .link_uart_rx(link_uart_rx),
        .packet_valid(packet_valid),
        .pressure_ok(pressure_ok),
        .weight_left_front(weight_left_front),
        .weight_left_rear(weight_left_rear),
        .weight_right_front(weight_right_front),
        .weight_right_rear(weight_right_rear),
        .left_right_state(left_right_state),
        .front_back_state(front_back_state),
        .lean_left(lean_left),
        .lean_right(lean_right),
        .lean_front(lean_front),
        .lean_back(lean_back),
        .link_alive(link_alive),
        .checksum_error(checksum_error)
    );

    always @(posedge clk) begin
        if (reset) begin
            led0 <= 1'b0;
            led_count <= 27'd0;
        end else begin
            led_count <= led_count + 27'd1;
            if (led_count == 27'd99_999_999) begin
                led_count <= 27'd0;
                led0 <= ~led0;
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            packet_led_count <= 24'd0;
            packet_pulse_led <= 1'b0;
        end else begin
            if (packet_valid) begin
                packet_led_count <= 24'd5_000_000;
                packet_pulse_led <= 1'b1;
            end else if (packet_led_count != 24'd0) begin
                packet_led_count <= packet_led_count - 24'd1;
                packet_pulse_led <= 1'b1;
            end else begin
                packet_pulse_led <= 1'b0;
            end
        end
    end

endmodule

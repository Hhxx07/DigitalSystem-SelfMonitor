module lcd_board_weight_lcd_top #(
    parameter integer CLK_HZ     = 100_000_000,
    parameter integer SPI_CLK_DIV = 5,
    parameter integer FRAME_HZ   = 2,
    parameter integer INIT_YEAR  = 2026,
    parameter integer INIT_MONTH = 1,
    parameter integer INIT_DAY   = 1,
    parameter integer INIT_HOUR  = 0,
    parameter integer INIT_MIN   = 0,
    parameter integer INIT_SEC   = 0,
    parameter [7:0]   MADCTL_PARAM = 8'h00,
    parameter [15:0]  LCD_X_OFFSET = 16'd2,
    parameter [15:0]  LCD_Y_OFFSET = 16'd1
) (
    input  wire clk,
    input  wire rst_n,
    input  wire link_uart_rx,
    input  wire ir_ok,
    input  wire ultrasonic_front_echo,
    input  wire ultrasonic_left45_echo,
    input  wire ultrasonic_right45_echo,

    output wire ultrasonic_front_trig,
    output wire ultrasonic_left45_trig,
    output wire ultrasonic_right45_trig,
    output wire lcd_cs_n,
    output wire lcd_rst_n,
    output wire lcd_dc,
    output wire lcd_scl,
    output wire lcd_mosi,
    output wire lcd_blk,
    output wire link_alive,
    output wire packet_valid,
    output wire seat_present,
    output wire checksum_error
);

    wire reset;
    wire packet_valid_pulse;
    wire pressure_ok;
    wire ir_raw_sync;
    wire ir_motion_event;
    wire ir_human_ok;
    wire [15:0] weight_left_front;
    wire [15:0] weight_left_rear;
    wire [15:0] weight_right_front;
    wire [15:0] weight_right_rear;
    wire [16:0] weight_front_back_diff;
    wire [16:0] weight_left_right_diff;
    wire [1:0]  weight_front_back_balance;
    wire [1:0]  weight_left_right_balance;
    wire [1:0]  link_left_right_state;
    wire [1:0]  link_front_back_state;
    wire lean_left;
    wire lean_right;
    wire lean_front;
    wire lean_back;

    reg [23:0] packet_led_count;
    reg packet_led_reg;

    assign reset = ~rst_n;
    assign packet_valid = packet_led_reg;
    assign seat_present = pressure_ok & ir_human_ok;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            packet_led_count <= 24'd0;
            packet_led_reg   <= 1'b0;
        end else begin
            if (packet_valid_pulse) begin
                packet_led_count <= 24'd5_000_000;
                packet_led_reg   <= 1'b1;
            end else if (packet_led_count != 24'd0) begin
                packet_led_count <= packet_led_count - 1'b1;
                packet_led_reg   <= 1'b1;
            end else begin
                packet_led_reg <= 1'b0;
            end
        end
    end

    lcd_weight_link_adapter #(
        .CLK_FREQ_HZ(CLK_HZ),
        .BAUD_RATE(115_200),
        .TIMEOUT_MS(500)
    ) u_weight_link (
        .clk(clk),
        .reset(reset),
        .link_uart_rx(link_uart_rx),
        .packet_valid(packet_valid_pulse),
        .pressure_ok(pressure_ok),
        .weight_left_front(weight_left_front),
        .weight_left_rear(weight_left_rear),
        .weight_right_front(weight_right_front),
        .weight_right_rear(weight_right_rear),
        .left_right_state(link_left_right_state),
        .front_back_state(link_front_back_state),
        .lean_left(lean_left),
        .lean_right(lean_right),
        .lean_front(lean_front),
        .lean_back(lean_back),
        .link_alive(link_alive),
        .checksum_error(checksum_error)
    );

    pir_motion_hold_detector #(
        .CLK_FREQ_HZ(CLK_HZ),
        .HOLD_SEC(60)
    ) u_ir_hold (
        .clk(clk),
        .rst_n(rst_n),
        .pir_in(ir_ok),
        .pir_raw_sync(ir_raw_sync),
        .motion_event(ir_motion_event),
        .human_present(ir_human_ok)
    );

    health_lcd_top #(
        .CLK_HZ(CLK_HZ),
        .SPI_CLK_DIV(SPI_CLK_DIV),
        .FRAME_HZ(FRAME_HZ),
        .INIT_YEAR(INIT_YEAR),
        .INIT_MONTH(INIT_MONTH),
        .INIT_DAY(INIT_DAY),
        .INIT_HOUR(INIT_HOUR),
        .INIT_MIN(INIT_MIN),
        .INIT_SEC(INIT_SEC),
        .MADCTL_PARAM(MADCTL_PARAM),
        .LCD_X_OFFSET(LCD_X_OFFSET),
        .LCD_Y_OFFSET(LCD_Y_OFFSET)
    ) u_health_lcd (
        .clk(clk),
        .rst_n(rst_n),
        .pressure_ok(pressure_ok),
        .ir_ok(ir_human_ok),
        .ultrasonic_front_echo(ultrasonic_front_echo),
        .ultrasonic_left45_echo(ultrasonic_left45_echo),
        .ultrasonic_right45_echo(ultrasonic_right45_echo),
        .weight_left_front(weight_left_front),
        .weight_left_rear(weight_left_rear),
        .weight_right_front(weight_right_front),
        .weight_right_rear(weight_right_rear),
        .weight_left_right_state(link_left_right_state),
        .weight_front_back_state(link_front_back_state),
        .lean_left(lean_left),
        .lean_right(lean_right),
        .lean_front(lean_front),
        .lean_back(lean_back),
        .sim_fast(1'b1),
        .ultrasonic_front_trig(ultrasonic_front_trig),
        .ultrasonic_left45_trig(ultrasonic_left45_trig),
        .ultrasonic_right45_trig(ultrasonic_right45_trig),
        .weight_front_back_diff(weight_front_back_diff),
        .weight_left_right_diff(weight_left_right_diff),
        .weight_front_back_balance(weight_front_back_balance),
        .weight_left_right_balance(weight_left_right_balance),
        .lcd_cs_n(lcd_cs_n),
        .lcd_rst_n(lcd_rst_n),
        .lcd_dc(lcd_dc),
        .lcd_scl(lcd_scl),
        .lcd_mosi(lcd_mosi),
        .lcd_blk(lcd_blk)
    );

endmodule

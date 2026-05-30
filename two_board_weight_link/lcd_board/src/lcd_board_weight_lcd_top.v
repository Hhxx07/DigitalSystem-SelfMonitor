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
    input  wire sim_fast,

    output wire ultrasonic_front_trig,
    output wire ultrasonic_left45_trig,
    output wire ultrasonic_right45_trig,
    output wire [16:0] weight_front_back_diff,
    output wire [16:0] weight_left_right_diff,
    output wire [1:0]  weight_front_back_balance,
    output wire [1:0]  weight_left_right_balance,
    output wire lcd_cs_n,
    output wire lcd_rst_n,
    output wire lcd_dc,
    output wire lcd_scl,
    output wire lcd_mosi,
    output wire lcd_blk,
    output wire link_alive,
    output wire packet_valid,
    output wire checksum_error
);

    wire reset;
    wire pressure_ok;
    wire [15:0] weight_left_front;
    wire [15:0] weight_left_rear;
    wire [15:0] weight_right_front;
    wire [15:0] weight_right_rear;
    wire [1:0]  link_left_right_state;
    wire [1:0]  link_front_back_state;
    wire lean_left;
    wire lean_right;
    wire lean_front;
    wire lean_back;

    assign reset = ~rst_n;

    lcd_weight_link_adapter #(
        .CLK_FREQ_HZ(CLK_HZ),
        .BAUD_RATE(115_200),
        .TIMEOUT_MS(500)
    ) u_weight_link (
        .clk(clk),
        .reset(reset),
        .link_uart_rx(link_uart_rx),
        .packet_valid(packet_valid),
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
        .ir_ok(ir_ok),
        .ultrasonic_front_echo(ultrasonic_front_echo),
        .ultrasonic_left45_echo(ultrasonic_left45_echo),
        .ultrasonic_right45_echo(ultrasonic_right45_echo),
        .weight_left_front(weight_left_front),
        .weight_left_rear(weight_left_rear),
        .weight_right_front(weight_right_front),
        .weight_right_rear(weight_right_rear),
        .sim_fast(sim_fast),
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

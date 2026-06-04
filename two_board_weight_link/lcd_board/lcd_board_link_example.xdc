set_property PACKAGE_PIN P17 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name clk100 [get_ports clk]

set_property PACKAGE_PIN P15 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# Board-to-board UART input on EGO1 J5-25 / IO_L15P.
# Connect this pin to the weighing board link_uart_tx pin.
# Match the weighing board J5 bank-compatible 1.8V IO standard.
set_property PACKAGE_PIN H14 [get_ports link_uart_rx]
set_property IOSTANDARD LVCMOS18 [get_ports link_uart_rx]

# PIR input on EGO1 J5-27 / IO_L16P. If the PIR module outputs 3.3V,
# level-shift or divide it before connecting to this 1.8V IO pin.
set_property PACKAGE_PIN E17 [get_ports ir_ok]
set_property IOSTANDARD LVCMOS18 [get_ports ir_ok]

# Debug LEDs D1-D4.
set_property PACKAGE_PIN G4 [get_ports link_alive]
set_property IOSTANDARD LVCMOS33 [get_ports link_alive]
set_property PACKAGE_PIN G3 [get_ports packet_valid]
set_property IOSTANDARD LVCMOS33 [get_ports packet_valid]
set_property PACKAGE_PIN J4 [get_ports seat_present]
set_property IOSTANDARD LVCMOS33 [get_ports seat_present]
set_property PACKAGE_PIN H4 [get_ports checksum_error]
set_property IOSTANDARD LVCMOS33 [get_ports checksum_error]

# The remaining LCD and ultrasonic pins depend on your wiring.
# Keep these port names aligned with lcd/health_lcd_top.v and lcd/ego1_st7735_example.xdc.
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_front_echo]
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_left45_echo]
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_right45_echo]
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_front_trig]
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_left45_trig]
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_right45_trig]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_cs_n]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_dc]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_scl]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_blk]

## Fill in these PACKAGE_PIN values from your existing LCD/ultrasonic wiring:
## set_property PACKAGE_PIN <PIN_US_FRONT_ECHO> [get_ports ultrasonic_front_echo]
## set_property PACKAGE_PIN <PIN_US_FRONT_TRIG> [get_ports ultrasonic_front_trig]
## set_property PACKAGE_PIN <PIN_US_LEFT45_ECHO> [get_ports ultrasonic_left45_echo]
## set_property PACKAGE_PIN <PIN_US_LEFT45_TRIG> [get_ports ultrasonic_left45_trig]
## set_property PACKAGE_PIN <PIN_US_RIGHT45_ECHO> [get_ports ultrasonic_right45_echo]
## set_property PACKAGE_PIN <PIN_US_RIGHT45_TRIG> [get_ports ultrasonic_right45_trig]
## set_property PACKAGE_PIN <PIN_LCD_CS> [get_ports lcd_cs_n]
## set_property PACKAGE_PIN <PIN_LCD_RST> [get_ports lcd_rst_n]
## set_property PACKAGE_PIN <PIN_LCD_DC> [get_ports lcd_dc]
## set_property PACKAGE_PIN <PIN_LCD_SCL> [get_ports lcd_scl]
## set_property PACKAGE_PIN <PIN_LCD_MOSI> [get_ports lcd_mosi]
## set_property PACKAGE_PIN <PIN_LCD_BLK> [get_ports lcd_blk]

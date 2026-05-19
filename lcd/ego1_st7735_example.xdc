## Example XDC for EGO1 / Artix-7.
## Replace PACKAGE_PIN values with the actual pins used by your board wiring.

create_clock -period 10.000 -name clk100 [get_ports clk]

set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports pressure_ok]
set_property IOSTANDARD LVCMOS33 [get_ports ir_ok]
set_property IOSTANDARD LVCMOS33 [get_ports sim_fast]
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_echo]
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_trig]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_cs_n]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_dc]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_scl]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_blk]

## Uncomment and edit these package pins for your EGO1 board:
## set_property PACKAGE_PIN <PIN_CLK> [get_ports clk]
## set_property PACKAGE_PIN <PIN_RST> [get_ports rst_n]
## set_property PACKAGE_PIN <PIN_PRESSURE> [get_ports pressure_ok]
## set_property PACKAGE_PIN <PIN_IR> [get_ports ir_ok]
## set_property PACKAGE_PIN <PIN_SIM_FAST> [get_ports sim_fast]
## set_property PACKAGE_PIN <PIN_US_ECHO> [get_ports ultrasonic_echo]
## set_property PACKAGE_PIN <PIN_US_TRIG> [get_ports ultrasonic_trig]
## set_property PACKAGE_PIN <PIN_LCD_CS> [get_ports lcd_cs_n]
## set_property PACKAGE_PIN <PIN_LCD_RST> [get_ports lcd_rst_n]
## set_property PACKAGE_PIN <PIN_LCD_DC> [get_ports lcd_dc]
## set_property PACKAGE_PIN <PIN_LCD_SCL> [get_ports lcd_scl]
## set_property PACKAGE_PIN <PIN_LCD_MOSI> [get_ports lcd_mosi]
## set_property PACKAGE_PIN <PIN_LCD_BLK> [get_ports lcd_blk]

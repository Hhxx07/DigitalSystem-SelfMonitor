set_property PACKAGE_PIN P17 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name clk100 [get_ports clk]

# Board-to-board UART input on EGO1 J5-25 / IO_L15P.
# Connect this pin to the weighing board link_uart_tx pin.
# Match the weighing board J5 bank-compatible 1.8V IO standard.
set_property PACKAGE_PIN H14 [get_ports link_uart_rx]
set_property IOSTANDARD LVCMOS18 [get_ports link_uart_rx]

# The remaining LCD board pins depend on your LCD/ultrasonic/IR wiring.
# Add or merge the corresponding constraints from lcd/ego1_st7735_example.xdc.
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports ir_ok]
set_property IOSTANDARD LVCMOS33 [get_ports sim_fast]
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
set_property IOSTANDARD LVCMOS33 [get_ports link_alive]
set_property IOSTANDARD LVCMOS33 [get_ports packet_valid]
set_property IOSTANDARD LVCMOS33 [get_ports checksum_error]

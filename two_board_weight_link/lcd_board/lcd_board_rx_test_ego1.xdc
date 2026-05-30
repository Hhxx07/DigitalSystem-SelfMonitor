set_property PACKAGE_PIN P17 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name clk100 [get_ports clk]

# Use a button or tie rst_n high in your top-level test wiring as needed.
# EGO1 reset key from the manual is P15.
set_property PACKAGE_PIN P15 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# Board-to-board UART input on EGO1 J5-25 / IO_L15P.
# Match the weighing board J5 bank-compatible 1.8V IO standard.
set_property PACKAGE_PIN H14 [get_ports link_uart_rx]
set_property IOSTANDARD LVCMOS18 [get_ports link_uart_rx]

# Debug LEDs D0-D4.
set_property PACKAGE_PIN F6 [get_ports led0]
set_property IOSTANDARD LVCMOS33 [get_ports led0]

set_property PACKAGE_PIN G4 [get_ports led_link_alive]
set_property IOSTANDARD LVCMOS33 [get_ports led_link_alive]

set_property PACKAGE_PIN G3 [get_ports led_packet]
set_property IOSTANDARD LVCMOS33 [get_ports led_packet]

set_property PACKAGE_PIN J4 [get_ports led_seat]
set_property IOSTANDARD LVCMOS33 [get_ports led_seat]

set_property PACKAGE_PIN H4 [get_ports led_checksum_error]
set_property IOSTANDARD LVCMOS33 [get_ports led_checksum_error]

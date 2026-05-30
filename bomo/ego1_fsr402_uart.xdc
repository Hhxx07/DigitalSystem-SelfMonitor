set_property PACKAGE_PIN P17 [get_ports clk100]
set_property IOSTANDARD LVCMOS33 [get_ports clk100]
create_clock -period 10.000 -name clk100 [get_ports clk100]

# FPGA UART TX to the EGO1 USB-UART bridge. Verified on this board: use T4 for output to PC.
set_property PACKAGE_PIN T4 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

set_property PACKAGE_PIN F6 [get_ports led0]
set_property IOSTANDARD LVCMOS33 [get_ports led0]

# EGO1 J5 XADC auxiliary analog inputs.
# FSR402 AO must be divided from 0-3.3V down to 0-1.0V before ADxP.
# Tie each ADxN pin to the same analog ground used by that sensor divider.
set_property PACKAGE_PIN D14 [get_ports vauxp0]
set_property PACKAGE_PIN C14 [get_ports vauxn0]
set_property PACKAGE_PIN B16 [get_ports vauxp2]
set_property PACKAGE_PIN B17 [get_ports vauxn2]
set_property PACKAGE_PIN A13 [get_ports vauxp3]
set_property PACKAGE_PIN A14 [get_ports vauxn3]
set_property PACKAGE_PIN B13 [get_ports vauxp8]
set_property PACKAGE_PIN B14 [get_ports vauxn8]


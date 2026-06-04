## Example XDC for EGO1 / Artix-7.
## Replace PACKAGE_PIN values with the actual pins used by your board wiring.

## 时钟约束：clk 按 100 MHz 输入时钟处理，周期 10 ns。
create_clock -period 10.000 -name clk100 [get_ports clk]

## 基础数字输入信号电平标准。
## rst_n、pressure_ok、pir_in 和 sim_fast 都按 3.3 V LVCMOS 连接。
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports pressure_ok]
set_property IOSTANDARD LVCMOS33 [get_ports pir_in]
set_property IOSTANDARD LVCMOS33 [get_ports sim_fast]

## 三路超声波模块的 Echo 输入和 Trig 输出电平标准。
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_front_echo]
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_front_trig]
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_left45_echo]
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_left45_trig]
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_right45_echo]
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_right45_trig]

## 压力传感器输入总线和重量平衡分析输出总线的电平标准。
set_property IOSTANDARD LVCMOS33 [get_ports {weight_left_front[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {weight_left_rear[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {weight_right_front[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {weight_right_rear[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {weight_front_back_diff[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {weight_left_right_diff[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {weight_front_back_balance[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {weight_left_right_balance[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {weight_left_right_state[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {weight_front_back_state[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports lean_left]
set_property IOSTANDARD LVCMOS33 [get_ports lean_right]
set_property IOSTANDARD LVCMOS33 [get_ports lean_front]
set_property IOSTANDARD LVCMOS33 [get_ports lean_back]

## ST7735 LCD SPI/控制引脚的电平标准。
set_property IOSTANDARD LVCMOS33 [get_ports lcd_cs_n]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_dc]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_scl]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_blk]

## 引脚位置模板。
## 实际上板前需要取消注释并把 <PIN_*> 替换成 EGO1 原理图对应的 PACKAGE_PIN。
## Uncomment and edit these package pins for your EGO1 board:
## set_property PACKAGE_PIN <PIN_CLK> [get_ports clk]
## set_property PACKAGE_PIN <PIN_RST> [get_ports rst_n]
## set_property PACKAGE_PIN <PIN_PRESSURE> [get_ports pressure_ok]
## set_property PACKAGE_PIN <PIN_PIR> [get_ports pir_in]
## set_property PACKAGE_PIN <PIN_SIM_FAST> [get_ports sim_fast]
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

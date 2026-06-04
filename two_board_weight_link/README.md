# 双 EGO1 称重数据链路

本目录是当前推荐的实际集成方案：

- 称重板读取四路 FSR402，判断入座和重心偏移。
- LCD 状态板通过 UART 接收结果，再结合 PIR、三路超声波和 LCD 系统。

## 系统结构

```text
weight_board_link_top
  XADC x4
  -> seat_weight_analyzer
  -> weight_packet_tx
  -> UART TX
       |
       v
lcd_board_weight_lcd_top
  UART RX
  -> lcd_weight_link_adapter
  -> health_lcd_top
  -> ST7735S LCD
```

## 板间连接

使用普通数字 I/O，不使用 XADC 模拟引脚传输 UART：

| 称重板 | LCD 状态板 | 功能 |
|---|---|---|
| `link_uart_tx` | `link_uart_rx` | 115200 baud，8N1 |
| GND | GND | 必须共地 |

示例约束使用 EGO1 J5-25 / H14，并按该 Bank 使用 `LVCMOS18`。连接前必须确认两块板的 I/O 电压兼容。

不要在没有明确供电设计的情况下直接连接两块板的 3.3 V 电源轨。

## 称重板

顶层：

```text
weight_board/src/weight_board_link_top.v
```

工程文件：

```text
weight_board/src/weight_board_link_top.v
weight_board/src/xadc_4ch_reader.v
weight_board/src/seat_weight_analyzer.v
weight_board/src/weight_packet_tx.v
weight_board/src/uart_tx.v
weight_board/weight_board_ego1.xdc
```

### FSR402 与 XADC

每路调理电路输出必须限制在 XADC 允许范围内。示例分压：

```text
FSR402 AO -- 24k --+-- ADxP
                   |
                  10k
                   |
                  GND

ADxN ------------- GND
```

当前通道映射：

| 座垫位置 | XADC | EGO1 J5 | FPGA |
|---|---|---|---|
| 左前 LF | AD0 | J5-13 / J5-14 | D14 / C14 |
| 右前 RF | AD2 | J5-1 / J5-2 | B16 / B17 |
| 左后 LR | AD3 | J5-5 / J5-6 | A13 / A14 |
| 右后 RR | AD8 | J5-11 / J5-12 | B13 / B14 |

### 重量分析

`seat_weight_analyzer.v`：

- 使用 `SEAT_ON_TH` 和 `SEAT_OFF_TH` 实现入座滞回。
- 计算左右、前后重量和及绝对差值。
- 使用差值占总重量百分比判断重心等级。
- 输出 `lean_left/right/front/back`。

默认参数：

```verilog
SEAT_ON_TH     = 800
SEAT_OFF_TH    = 300
WARN_PERCENT   = 15
DANGER_PERCENT = 30
```

这些只是初始值，必须结合座垫结构和传感器标定。

## UART 数据包

称重板默认以 10 Hz 发送 16 字节二进制帧：

```text
A5 5A seq flags
LF_H LF_L RF_H RF_L LR_H LR_L RR_H RR_L
LR_STATE FB_STATE checksum 0A
```

字段：

```text
flags[0] = seat_present
flags[1] = lean_left
flags[2] = lean_right
flags[3] = lean_front
flags[4] = lean_back

LR_STATE = 0 正常，1 警告，2 危险
FB_STATE = 0 正常，1 警告，2 危险
checksum = 从 A5 到 FB_STATE 所有字节异或
```

## LCD 状态板链路测试

首次接线时先使用：

```text
lcd_board/src/lcd_board_link_rx_top.v
lcd_board/lcd_board_rx_test_ego1.xdc
```

所需文件：

```text
lcd_board/src/lcd_board_link_rx_top.v
lcd_board/src/lcd_weight_link_adapter.v
lcd_board/src/weight_packet_rx.v
lcd_board/src/uart_rx.v
```

LED：

```text
D0 心跳
D1 link_alive
D2 收到有效包后的短暂亮灯
D3 称重板 seat_present
D4 checksum_error
```

`lcd_weight_link_adapter` 在 500 ms 内收不到有效包时清除 `link_alive`，并使输出给健康系统的 `pressure_ok=0`。

## LCD 状态板完整顶层

顶层：

```text
lcd_board/src/lcd_board_weight_lcd_top.v
```

该模块：

1. 接收并校验称重板数据包。
2. 把 `pressure_ok`、四角重量、重心等级和方向传给 `health_lcd_top`。
3. 把包装顶层的 `pir_in` 原始信号传给 `health_lcd_top.pir_in`。
4. 将 `sim_fast` 固定为 0，保证上板计时正常。
5. 输出 LCD、超声波和链路调试信号。

所需 LCD 板链路文件：

```text
lcd_board/src/lcd_board_weight_lcd_top.v
lcd_board/src/lcd_weight_link_adapter.v
lcd_board/src/weight_packet_rx.v
lcd_board/src/uart_rx.v
lcd_board/lcd_board_link_example.xdc
```

还需加入：

```text
../lcd/health_lcd_top.v
../lcd/st7735_spi.v
../lcd/st7735_init.v
../lcd/display_renderer.v
../lcd/font_rom.v
../lcd/rtc_clock.v
../lcd/seat_fsm.v
../lcd/hp_engine.v
../红外检测/pir_human_detector.v
../超声波/top_Ranging.v
../超声波/trig_generator.v
../超声波/signal_sync.v
../超声波/distance_calc.v
../超声波/torso_posture_analyzer.v
```

不需要加入 `pir_motion_hold_detector.v` 或 `lcd_board/src/weight_balance_analyzer.v` 才能编译当前完整顶层；重量等级已经由称重板发送。

`lcd_board_link_example.xdc` 只约束时钟、复位、UART、PIR 和调试 LED。LCD 与超声波 `PACKAGE_PIN` 仍需按实际接线补充。

## 编译检查

仅检查 LCD 链路测试顶层：

```powershell
cd two_board_weight_link\lcd_board
iverilog -g2001 -Wall -s lcd_board_link_rx_top -tnull src\lcd_board_link_rx_top.v src\lcd_weight_link_adapter.v src\weight_packet_rx.v src\uart_rx.v
```

称重板包含 Xilinx `XADC` 原语，完整仿真和综合应使用 Vivado。Icarus 只做语法检查时可使用 `-i` 忽略未解析原语。

UART 数据包环回测试：

```powershell
cd two_board_weight_link
iverilog -g2001 -Wall -o tb_weight_packet_link.vvp tb_weight_packet_link.v weight_board\src\weight_packet_tx.v weight_board\src\uart_tx.v lcd_board\src\weight_packet_rx.v lcd_board\src\uart_rx.v
vvp tb_weight_packet_link.vvp
```

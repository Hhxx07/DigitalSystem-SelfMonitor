# 健康坐姿监测 FPGA 项目

本仓库面向 Xilinx Artix-7 / EGO1，使用 Verilog-2001 实现健康坐姿监测系统。系统综合使用三路超声波、PIR 红外、四路 FSR402 薄膜压力传感器和 ST7735S 128x128 LCD。

## 当前推荐架构

实际硬件建议使用两块 EGO1：

```text
称重板
  FSR402 x4 -> XADC -> 重量/重心分析 -> 二进制 UART
                                      |
                                      v
LCD 状态板
  UART 接收 + PIR + 超声波 x3 -> 健康状态机/HP -> ST7735S LCD
```

推荐顶层：

| 用途 | 顶层模块 |
|---|---|
| 称重板 | `two_board_weight_link/weight_board/src/weight_board_link_top.v` |
| LCD 状态板 | `two_board_weight_link/lcd_board/src/lcd_board_weight_lcd_top.v` |
| 不使用双板包装、直接集成 | `lcd/health_lcd_top.v` |
| 仅测试板间 UART 接收 | `two_board_weight_link/lcd_board/src/lcd_board_link_rx_top.v` |

## 目录结构

```text
src/
├── lcd/                    LCD、RTC、座位状态机、HP 和直接集成顶层
├── 超声波/                三路测距和躯干状态分析
├── 红外检测/              PIR 同步、滤波和活动保持
├── 薄膜重量感应/          单板 XADC + ASCII 串口调试方案
├── 称重/                  简单四角重量差值分析器
└── two_board_weight_link/  推荐的双 EGO1 二进制 UART 称重链路
```

## 核心数据流

```text
PIR 原始信号
  -> pir_human_detector
  -> ir_active

三路超声波
  -> top_Ranging x3
  -> dHead / dL / dR
  -> ultrasonic_seated + torso_posture_analyzer

称重板 UART 数据
  -> pressure_ok + 四角重量 + 重心状态/方向

ir_active && ultrasonic_seated && pressure_ok
  -> seated
  -> seat_fsm + hp_engine + display_renderer
  -> ST7735S LCD
```

超声波零距离表示尚未获得有效回波，不参与入座判定。三路 Trig 在一个 65 ms 周期内分别延迟约 0、22、44 ms，减少同时触发造成的串扰。

## 状态和 HP

座位状态：

```text
IDLE -> STUDY -> SEDENTARY(45min) -> OVER_SEDENTARY(60min)
          |
          +-> REST -> AWAY_LONG(20min) -> IDLE(30min)
```

- 离座超过 3 分钟后返回，重新开始学习计时。
- 离座 3 分钟内返回，保留原学习计时。
- 进入 `IDLE` 后 HP 恢复为 100。

头部离桌距离 `dHead`：

| 距离 | 状态 | HP 基础变化 |
|---|---|---:|
| `>= 26cm` | SAFE | `+1/min` |
| `20..25cm` | WARN | `-1/min` |
| `< 20cm` | DANGER | `-3/min` |

左右斜距 `dL/dR` 还会产生 `LEAN/SIDE/TWIST` 额外扣分，详见 `超声波/README.md`。

## LCD 显示

当前画面包括：

- 日期和时间
- 座位状态、头部姿势状态
- 学习、离座和当前状态计时
- 左右、前后重心方向及等级
- 左右斜距差、躯干状态、头部距离
- HP 数值和血条
- HP 为 0 或过度久坐时全屏闪烁

## 文档索引

- `lcd/README.md`：直接集成顶层、LCD 渲染、状态机和仿真。
- `超声波/README.md`：三路超声波安装、错峰触发和姿态阈值。
- `红外检测/README.md`：PIR 预热、滤波和活动窗口。
- `薄膜重量感应/README.md`：单板 XADC 与 ASCII UART 调试方案。
- `称重/README.md`：简单重量差值分析模块。
- `two_board_weight_link/README.md`：推荐双板方案、数据包和工程文件清单。

## 回归验证

主系统：

```powershell
cd lcd
iverilog -g2001 -Wall -o tb_health_lcd_top.vvp tb_health_lcd_top.v health_lcd_top.v st7735_spi.v st7735_init.v display_renderer.v font_rom.v rtc_clock.v seat_fsm.v hp_engine.v ..\红外检测\pir_human_detector.v ..\超声波\top_Ranging.v ..\超声波\trig_generator.v ..\超声波\signal_sync.v ..\超声波\distance_calc.v ..\超声波\torso_posture_analyzer.v
vvp tb_health_lcd_top.vvp
```

PIR：

```powershell
cd 红外检测
iverilog -g2001 -Wall -o tb_pir_human_detector.vvp tb_pir_human_detector.v pir_human_detector.v
vvp tb_pir_human_detector.vvp
```

XADC 模块使用 Xilinx `XADC` 原语，Icarus Verilog 编译时需要 Vivado 仿真库或使用 `-i` 忽略未解析原语；最终上板综合应使用 Vivado。

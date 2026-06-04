# LCD 健康状态系统

本目录实现 `health_lcd_top` 直接集成顶层，以及 ST7735S LCD、RTC、座位状态机和 HP 引擎。目标器件为 EGO1 / Artix-7，系统时钟默认 100 MHz。

双板称重方案实际使用的 LCD 板顶层是：

```text
../two_board_weight_link/lcd_board/src/lcd_board_weight_lcd_top.v
```

该包装顶层先接收称重板 UART 数据，再实例化本目录的 `health_lcd_top`。

## 文件关系

```text
health_lcd_top.v
├── rtc_clock.v
├── ../红外检测/pir_human_detector.v
├── seat_fsm.v
├── ../超声波/top_Ranging.v x3
│   ├── trig_generator.v
│   ├── signal_sync.v
│   └── distance_calc.v
├── ../超声波/torso_posture_analyzer.v
├── hp_engine.v
├── st7735_init.v
├── display_renderer.v
│   └── font_rom.v
└── st7735_spi.v
```

当前 `health_lcd_top` 不在内部重新计算重量状态。四角重量用于输出绝对差值；左右/前后等级和偏移方向由外部称重模块输入，直接交给 LCD 显示。推荐数据来源是双板链路中的 `seat_weight_analyzer`。

## 顶层接口

```verilog
module health_lcd_top (
    input  wire clk,
    input  wire rst_n,
    input  wire pressure_ok,
    input  wire pir_in,
    input  wire ultrasonic_front_echo,
    input  wire ultrasonic_left45_echo,
    input  wire ultrasonic_right45_echo,
    input  wire [15:0] weight_left_front,
    input  wire [15:0] weight_left_rear,
    input  wire [15:0] weight_right_front,
    input  wire [15:0] weight_right_rear,
    input  wire [1:0]  weight_left_right_state,
    input  wire [1:0]  weight_front_back_state,
    input  wire lean_left,
    input  wire lean_right,
    input  wire lean_front,
    input  wire lean_back,
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
    output wire lcd_blk
);
```

### 控制和传感器输入

| 端口 | 说明 |
|---|---|
| `clk` | 系统时钟，默认 100 MHz。 |
| `rst_n` | 全局低有效复位。 |
| `pressure_ok` | 称重模块给出的有效入座标志。 |
| `pir_in` | PIR 原始数字信号，内部经过预热、滤波和活动窗口处理。 |
| `ultrasonic_*_echo` | 正前、左 45 度、右 45 度超声波 Echo。 |
| `weight_*` | 左前、左后、右前、右后四角重量值。 |
| `weight_left_right_state` | 左右重心等级：0 正常、1 警告、2 危险。 |
| `weight_front_back_state` | 前后重心等级：0 正常、1 警告、2 危险。 |
| `lean_left/right/front/back` | 重心偏移方向。 |
| `sim_fast` | 仅用于仿真。上板必须接 0；为 1 时每秒按一分钟处理。 |

### 输出

| 端口 | 说明 |
|---|---|
| `ultrasonic_*_trig` | 三路超声波触发信号。 |
| `weight_front_back_diff` | 前后重量和绝对差值。 |
| `weight_left_right_diff` | 左右重量和绝对差值。 |
| `weight_*_balance` | 直接转发外部输入的重心等级。 |
| `lcd_cs_n` | LCD SPI 低有效片选。 |
| `lcd_rst_n` | LCD 低有效硬复位。 |
| `lcd_dc` | 0 为命令，1 为数据。 |
| `lcd_scl` | SPI 时钟。默认约 10 MHz。 |
| `lcd_mosi` | SPI 写数据。 |
| `lcd_blk` | 背光，当前固定为 1。 |

## 关键参数

| 参数 | 默认值 | 说明 |
|---|---:|---|
| `CLK_HZ` | `100000000` | 系统时钟频率。 |
| `SPI_CLK_DIV` | `5` | SPI 半周期分频，100 MHz 下约 10 MHz。 |
| `FRAME_HZ` | `2` | 整屏刷新目标频率。 |
| `INIT_YEAR..INIT_SEC` | 见源码 | RTC 复位初值。 |
| `MADCTL_PARAM` | `8'h00` | LCD 扫描方向。 |
| `LCD_X_OFFSET` | `2` | 修正画面向左偏 2 像素。 |
| `LCD_Y_OFFSET` | `1` | 修正画面向上偏 1 像素。 |
| `ULTRASONIC_SEATED_THRESHOLD_CM` | `120` | 三路距离的入座上限。 |
| `PIR_INACTIVE_WINDOW_SEC` | `180` | PIR 无活动后保留时间。 |
| `PIR_SIM_FAST` | `0` | PIR 模块快速仿真参数，上板保持 0。 |

## 入座判断

```verilog
seated = ir_active && ultrasonic_seated && pressure_ok;
```

其中：

- `ir_active`：PIR 预热和滤波完成后，只要近期有活动就保持为 1。
- `ultrasonic_seated`：三路距离都非零且都小于默认 120 cm。
- `pressure_ok`：称重板确认座垫承重。

距离为 0 表示还没有得到有效回波，不能判定入座。

## 三路超声波

三路 `top_Ranging` 使用相同的 65 ms 周期，但触发时刻错开：

| 通道 | 周期内触发延迟 |
|---|---:|
| 正前方 | 0 ms |
| 左 45 度 | 约 22 ms |
| 右 45 度 | 约 44 ms |

这样可以减少三个模块同时发射造成的串扰。正前方距离作为 `dHead`；左右距离作为 `dL/dR`。

## 座位状态机

`seat_fsm.v` 输出：

```text
0 IDLE
1 STUDY
2 SEDENTARY
3 OVER_SEDENTARY
4 REST
5 AWAY_LONG
```

规则：

- 入座后进入 `STUDY`。
- 连续入座达到 45 分钟进入 `SEDENTARY`。
- 连续入座达到 60 分钟进入 `OVER_SEDENTARY`。
- 离座后进入 `REST`。
- 离座超过 3 分钟后返回，会清空原学习计时。
- 离座 3 分钟内返回，保留原学习计时。
- 离座达到 20 分钟进入 `AWAY_LONG`。
- 离座达到 30 分钟进入 `IDLE` 并清空学习计时。

`sit_time_min/sec`、`away_time_min/sec` 提供秒级显示。

## HP 引擎

`hp_engine.v` 只在 `seated=1` 时按分钟更新 HP，范围饱和在 0 到 100。

| dHead | 基础变化 | POST |
|---|---:|---|
| `>=26cm` | `+1/min` | SAFE |
| `20..25cm` | `-1/min` | WARN |
| `<20cm` | `-3/min` | DANGER |

躯干额外扣分：

```text
GOOD  0
LEAN -1/min
SIDE -2/min
TWIST -3/min
```

进入 `ST_IDLE` 后 HP 恢复为 100。HP 为 0 时输出 `hp_zero_alarm`。

## LCD 初始化和刷新

`st7735_init.v` 发送：

```text
SWRESET, SLPOUT, COLMOD=RGB565, MADCTL,
CASET, RASET, NORON, DISPON
```

初始化结束前 SPI 数据来自 `st7735_init`；之后由 `display_renderer` 接管。`display_renderer` 不使用帧缓存，而是按像素实时生成整屏 RGB565 数据。

当前 16 行字符布局：

```text
0  YYYY-MM-DD
1  HH:MM:SS
3  STAT ...
4  POST ...
5  SIT mmmm:ss
6  AWAY mmmm:ss
7  WLR direction level
8  NOW mmmm:ss
9  WFR direction level
10 TDIF xxxxCM
11 TORS GOOD/LEAN/SIDE/TWIST
12 HEAD xxxxCM
13 HP xxx
14-15 HP 血条区域
```

`TDIF/TORS/HEAD` 只在入座时显示。HP 为 0 或状态为 `OVER_SEDENTARY` 时全屏闪烁。

## 约束

`ego1_st7735_example.xdc` 是直接使用 `health_lcd_top` 时的接口模板。它只给出 I/O 标准和部分占位引脚；上板前必须根据实际接线补全 `PACKAGE_PIN`。

注意：

- `pir_in` 是当前端口名，不再使用旧名 `ir_ok`。
- `sim_fast` 上板必须固定为 0。
- 超声波 Echo 如果是 5 V，必须电平转换后再接 FPGA。

## 仿真

```powershell
cd lcd
iverilog -g2001 -Wall -o tb_health_lcd_top.vvp tb_health_lcd_top.v health_lcd_top.v st7735_spi.v st7735_init.v display_renderer.v font_rom.v rtc_clock.v seat_fsm.v hp_engine.v ..\红外检测\pir_human_detector.v ..\超声波\top_Ranging.v ..\超声波\trig_generator.v ..\超声波\signal_sync.v ..\超声波\distance_calc.v ..\超声波\torso_posture_analyzer.v
vvp tb_health_lcd_top.vvp
```

测试覆盖 LCD 初始化、三条件入座、零距离拒绝、PIR 否决、HP 饱和、45/60 分钟状态、20/30 分钟离座状态和有效休息逻辑。

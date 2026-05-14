# ST7735S 健康坐姿 LCD 显示系统说明

本目录是一套面向 Xilinx Artix-7 / EGO1 FPGA 的 Verilog-2001 工程代码，用 4-wire SPI 驱动 1.44 inch 128x128 ST7735S TFT LCD，并显示日期、时间、久坐状态、学习/离座计时、HP 数值和 HP 血条。

默认输入时钟按 100 MHz 设计，LCD SPI 写时钟默认约 10 MHz，像素格式为 RGB565。

## 文件关系

顶层模块是 `health_lcd_top.v`，它负责把业务逻辑、LCD 初始化、显示渲染和 SPI 发送模块连接起来。

```text
health_lcd_top.v
├── rtc_clock.v          100 MHz 分频生成 1 Hz tick，并维护年月日时分秒
├── seat_fsm.v           根据 pressure_ok/ir_ok 计算 seated、状态、学习/离座分钟数
├── hp_engine.v          根据 seated 和 distance_cm 每分钟更新 HP
├── st7735_init.v        上电复位 LCD，并发送 ST7735S 初始化命令序列
├── display_renderer.v   init_done 后周期性整屏刷新 128x128 RGB565 图像
│   └── font_rom.v       8x8 ASCII 字模，用于日期、时间、状态等文本绘制
└── st7735_spi.v         低层 SPI 字节发送器，只写 MOSI，不读 MISO
```

`st7735_init.v` 和 `display_renderer.v` 都会产生 SPI 发送请求。顶层通过 `init_done` 做简单仲裁：

```verilog
assign spi_start_mux = init_done ? render_spi_start : init_spi_start;
assign spi_dc_mux    = init_done ? render_spi_dc    : init_spi_dc;
assign spi_data_mux  = init_done ? render_spi_data  : init_spi_data;
```

也就是说：

1. 上电后先由 `st7735_init.v` 独占 SPI，完成 LCD 复位和初始化。
2. `init_done=1` 后，切换到 `display_renderer.v`，开始周期性刷新整屏。
3. 真正驱动 `lcd_cs_n/lcd_dc/lcd_scl/lcd_mosi` 的只有 `st7735_spi.v`。

## 顶层：health_lcd_top.v

顶层接口按题目要求实现：

```verilog
module health_lcd_top(
    input  wire clk,
    input  wire rst_n,
    input  wire pressure_ok,
    input  wire ir_ok,
    input  wire [9:0] distance_cm,
    output wire lcd_cs_n,
    output wire lcd_rst_n,
    output wire lcd_dc,
    output wire lcd_scl,
    output wire lcd_mosi,
    output wire lcd_blk
);
```

实现内容：

- `seated = pressure_ok & ir_ok`，作为入座判断。
- 实例化 RTC、座位状态机、HP 引擎、LCD 初始化器、显示渲染器和 SPI 字节发送器。
- `lcd_blk` 固定输出高电平，默认打开背光。
- 用参数控制工程行为：
  - `CLK_HZ`：输入时钟频率，默认 `100000000`。
  - `SPI_CLK_DIV`：SPI 半周期分频，默认 `5`，100 MHz 下 SCL 约 10 MHz。
  - `FRAME_HZ`：显示刷新目标帧率，默认 `2`。
  - `SIM_FAST`：仿真加速，`1` 时 1 秒当 1 分钟。
  - `INIT_YEAR/MONTH/DAY/HOUR/MIN/SEC`：RTC 初始时间。
  - `MADCTL_PARAM`：ST7735S 屏幕方向参数。

## RTC：rtc_clock.v

`rtc_clock.v` 做两件事：

1. 从输入时钟分频得到 `tick_1hz`。
2. 用这个 1 Hz tick 推进年月日时分秒。

核心机制：

- `div_cnt` 从 0 计数到 `CLK_HZ-1`。
- 到达终点时：
  - `tick_1hz` 拉高一个 `clk` 周期。
  - 调用 `step_one_second` 任务，让秒数加 1。

日历进位：

- 秒满 59 进分钟。
- 分钟满 59 进小时。
- 小时满 23 进日期。
- 日期根据 `days_in_month(year, month)` 判断每月天数。
- 2 月通过 `is_leap_year` 支持闰年：
  - 能被 400 整除是闰年。
  - 能被 100 整除不是闰年。
  - 能被 4 整除是闰年。

注意：RTC 没有外部校时接口，时间只在复位后从参数指定的初始时间开始走。

## 座位状态机：seat_fsm.v

`seat_fsm.v` 根据 `seated` 和分钟 tick 维护：

- `state`
- `sit_time_min`
- `away_time_min`

状态编码：

```text
0 = IDLE / 空闲
1 = STUDY / 学习中
2 = SEDENTARY / 久坐
3 = OVER_SEDENTARY / 过度久坐
4 = REST / 休息
5 = AWAY_LONG / 离开较久
```

分钟 tick 生成方式：

- 正常模式：累计 60 个 `tick_1hz` 得到 1 个分钟 tick。
- `SIM_FAST=1`：每个 `tick_1hz` 都当作 1 分钟，用于快速仿真。

状态规则：

- `seated=1` 时：
  - `away_time_min` 清零。
  - `sit_time_min` 每分钟加 1。
  - 小于 45 分钟：`STUDY`。
  - 达到 45 分钟：`SEDENTARY`。
  - 达到 60 分钟：`OVER_SEDENTARY`。

- 曾经入座后离开：
  - `away_time_min < 20`：`REST`。
  - `20 <= away_time_min < 30`：`AWAY_LONG`。
  - `away_time_min >= 30`：回到 `IDLE`，清空 `sit_time_min` 和离座记录。

- 离座 3 分钟内返回：
  - 清空 `sit_time_min`，重新从 `STUDY` 开始计时。

实现上使用 `has_sat_once` 区分“从未入座的 IDLE”和“曾经入座后离开”的情况。

## HP 引擎：hp_engine.v

`hp_engine.v` 根据坐姿距离每分钟更新 HP。

输出：

- `hp`：0 到 100，饱和加减。
- `hp_zero_alarm`：`hp==0` 时为 1。
- `posture_level`：
  - `0 = SAFE`
  - `1 = WARN`
  - `2 = DANGER`

规则：

- 只有 `seated=1` 时才更新 HP。
- `distance_cm > 50`：每分钟 `+1`，最大 100。
- `30 <= distance_cm <= 50`：每分钟 `-1`，最小 0。
- `distance_cm < 30`：每分钟 `-3`，最小 0。

和 `seat_fsm.v` 一样，`SIM_FAST=1` 时 1 秒当 1 分钟。

## SPI 字节发送器：st7735_spi.v

`st7735_spi.v` 是底层 LCD SPI 写模块，只负责发送 8-bit byte。

接口含义：

- `start`：发送请求，空闲时拉高 1 个周期即可。
- `dc`：本字节类型，`0` 表示 command，`1` 表示 data。
- `data`：待发送字节。
- `busy`：正在发送。
- `done`：一个字节发送完成后拉高 1 个周期。
- `lcd_cs_n`：片选，发送期间为低。
- `lcd_scl`：SPI 时钟。
- `lcd_mosi`：SPI 数据，MSB first。

时序实现：

- 空闲时 `lcd_cs_n=1`，`lcd_scl=0`。
- 收到 `start` 后：
  - 锁存 `data` 和 `dc`。
  - `lcd_cs_n` 拉低。
  - 先输出最高位 `data[7]`。
- 每 `CLK_DIV` 个系统时钟翻转一次 `lcd_scl`。
- 在 SCL 上升沿期间 LCD 采样当前 MOSI。
- 在 SCL 下降沿后准备下一位。
- 8 位发送完毕后释放 `CS`，产生 `done`。

默认 `CLK_DIV=5` 时，100 MHz 输入下：

```text
SCL 半周期 = 5 * 10 ns = 50 ns
SCL 周期   = 100 ns
SPI 频率   = 10 MHz
```

## LCD 初始化：st7735_init.v

`st7735_init.v` 完成 LCD 上电复位和 ST7735S 初始化序列。

复位流程：

1. `lcd_rst_n=0` 保持约 20 ms。
2. `lcd_rst_n=1` 后等待约 120 ms。
3. 开始发送初始化命令。

初始化命令序列：

```text
SWRESET 0x01
SLPOUT  0x11
COLMOD  0x3A, 0x05
MADCTL  0x36, MADCTL_PARAM
CASET   0x2A, 0, 0, 0, 127
RASET   0x2B, 0, 0, 0, 127
NORON   0x13
DISPON  0x29
```

实现方式：

- 用 `seq_idx` 遍历命令/数据表。
- `seq_data(seq_idx)` 返回当前字节。
- `seq_dc(seq_idx)` 返回当前字节是命令还是数据。
- `delay_after(seq_idx)` 为 `SWRESET`、`SLPOUT`、`DISPON` 后插入必要延时。
- 每个字节通过 `spi_start/spi_dc/spi_data` 请求 `st7735_spi.v` 发送。
- 等到 `spi_done` 后进入下一个字节。
- 全部完成后 `init_done=1`。

## 显示渲染：display_renderer.v

`display_renderer.v` 在 `init_done=1` 后周期性刷新整屏。

刷新流程：

1. 等待 `FRAME_PERIOD = CLK_HZ / FRAME_HZ`。
2. 发送窗口设置：
   - `CASET 0..127`
   - `RASET 0..127`
   - `RAMWR`
3. 从 `(0,0)` 到 `(127,127)` 逐像素生成 RGB565 颜色。
4. 每个像素发送高 8 位和低 8 位，共 32768 个数据字节。
5. 一帧结束后回到等待状态。

显示内容：

- 第 0 行字符：日期 `YYYY-MM-DD`
- 第 2 行字符：时间 `HH:MM:SS`
- 第 4 行字符：状态 `IDLE/STUDY/LONG/OVER/REST/AWAY`
- 第 6 行字符：学习时间 `SIT xxxxM`
- 第 8 行字符：离座时间 `AWAY xxxxM`
- 第 10 行字符：HP 数值 `HP xxx`
- 屏幕下方：HP 横向血条

颜色规则：

- 背景：黑色。
- 文本：白色。
- HP 血条：
  - `HP >= 70`：绿色。
  - `30 <= HP < 70`：黄色。
  - `HP < 30`：红色。
- `hp_zero_alarm=1` 或状态为 `OVER_SEDENTARY` 时：
  - 状态区域按 `second[0]` 闪烁。
  - 闪烁时状态文字变黄，区域背景变暗红。

文字实现：

- 屏幕按 8x8 字符网格处理。
- `pix_x[6:3]` 是字符列。
- `pix_y[6:3]` 是字符行。
- `pix_x[2:0]` 和 `pix_y[2:0]` 是字符内部像素坐标。
- `char_at(col,row)` 根据当前字符格返回 ASCII。
- `font_rom.v` 根据 ASCII 和字体行返回 8 位点阵。
- 如果当前字体 bit 为 1，则输出文字颜色。

这是一种“边扫描边生成像素”的实现，没有使用帧缓存 RAM，资源占用较低。

## 字库：font_rom.v

`font_rom.v` 是组合逻辑 ROM，输入：

- `ascii`：ASCII 字符。
- `row`：字符内部第几行，0 到 7。

输出：

- `bits`：该行 8 个像素点。

当前字库覆盖了本工程显示需要的字符：

- 数字 `0` 到 `9`
- `-`
- `:`
- 空格
- 状态和标签用到的大写字母，例如 `A/D/E/G/H/I/L/M/N/O/P/R/S/T/U/V/W/Y`

未支持的字符会显示为一个简单方框，便于发现字库缺字。

## Testbench：tb_health_lcd_top.v

testbench 用于快速验证主要行为，不直接验证 LCD 图像内容。

仿真参数：

```verilog
.CLK_HZ(1000),
.SPI_CLK_DIV(1),
.FRAME_HZ(2),
.SIM_FAST(1)
```

这样做的原因：

- `CLK_HZ=1000`：让 1 Hz tick 在仿真中更快产生。
- `SPI_CLK_DIV=1`：加快 LCD 初始化字节发送。
- `SIM_FAST=1`：1 秒当 1 分钟，可以快速跑到 45/60 分钟阈值。

验证项：

- LCD 初始化完成，`init_done=1`。
- `lcd_blk=1`。
- HP 在安全区保持 100 饱和。
- HP 在警戒区每分钟 -1。
- HP 在危险区每分钟 -3。
- HP 下降到 0 后饱和，并触发 `hp_zero_alarm`。
- 入座 45 分钟进入 `SEDENTARY`。
- 入座 60 分钟进入 `OVER_SEDENTARY`。
- 离座 20 分钟进入 `AWAY_LONG`。
- 离座 30 分钟回到 `IDLE`，并清空 `sit_time_min`。

运行方式：

```powershell
cd D:\UserDate\DeskTop\数字系统Project\src\lcd
iverilog -g2001 -Wall -o tb_health_lcd_top.vvp tb_health_lcd_top.v health_lcd_top.v st7735_spi.v st7735_init.v display_renderer.v font_rom.v rtc_clock.v seat_fsm.v hp_engine.v
vvp tb_health_lcd_top.vvp
```

期望输出包含：

```text
PASS LCD init_done
PASS hp safe saturates at 100
PASS hp warn minus one
PASS hp danger minus three
PASS hp danger saturates at zero
PASS state 45min sedentary
PASS state 60min over sedentary
PASS state away 20min
PASS state away 30min idle
ALL TESTS PASSED
```

## XDC 约束：ego1_st7735_example.xdc

该文件是示例约束，不包含真实 EGO1 引脚号。

已包含：

- 100 MHz 时钟约束：

```tcl
create_clock -period 10.000 -name clk100 [get_ports clk]
```

- 所有输入/输出的 `LVCMOS33` I/O 标准。
- LCD 和传感器引脚的 `PACKAGE_PIN` 占位模板。

上板前必须根据你的 EGO1 原理图或实际接线，把 `<PIN_...>` 替换成真实封装管脚。

## 上板使用建议

1. 在 Vivado 中把 `health_lcd_top.v` 设为顶层。
2. 添加本目录全部 `.v` 文件。
3. 添加并修改 `ego1_st7735_example.xdc` 中的实际管脚。
4. 确认顶层参数：
   - 正常上板：`CLK_HZ=100000000`，`SIM_FAST=0`。
   - SPI 初始建议：`SPI_CLK_DIV=5`，约 10 MHz。
   - 如果屏幕不稳定，可把 `SPI_CLK_DIV` 改大，例如 8 或 10。
5. 如果屏幕方向或颜色顺序不符合预期，优先调整 `MADCTL_PARAM`。

## 当前实现边界

- SPI 只写，不支持读 LCD ID 或状态。
- 没有帧缓存，图像是实时逐像素生成。
- 字库是简化 8x8 ASCII 字库，只覆盖当前界面需要的字符。
- 日期时间来自内部计数器，没有外部 RTC 芯片校时。
- LCD 初始化序列是 ST7735S 常用最小序列，不同屏幕模组如果有偏移或颜色顺序差异，可能需要调整 `MADCTL_PARAM`、窗口范围或增加厂商推荐初始化命令。
